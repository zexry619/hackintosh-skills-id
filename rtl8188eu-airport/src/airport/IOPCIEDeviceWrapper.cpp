//
//  IOPCIEDeviceWrapper.cpp — versi USB untuk RTL8188EUS (2357:010c).
//
//  Alur:
//    IOUSBHostInterface (match personality)
//        → IOPCIEDeviceWrapper (kelas ini) membuat ItlRtl8188E
//        → registerService() → AirportItlwm match & menjadi IO80211Controller
//
//  pciNub sengaja nullptr. Frontend sudah dipatch agar melewati blok PCI.
//

#include "IOPCIEDeviceWrapper.hpp"
#include "Apple80211.h"

#include "ItlRtl8188E.hpp"

#define super IOService
OSDefineMetaClassAndStructors(IOPCIEDeviceWrapper, IOService);

#define RTL8188EUS_VID 0x2357
#define RTL8188EUS_PID 0x010c

extern IO80211WorkQueue *_fWorkloop;

bool IOPCIEDeviceWrapper::init()
{
    if (!super::init())
        return false;
    fHalService = NULL;
    pciNub = NULL;
    fInterface = NULL;
    return true;
}

void IOPCIEDeviceWrapper::free()
{
    if (fInterface) {
        fInterface->release();
        fInterface = NULL;
    }
    /* fHalService dimiliki (dan di-release) oleh AirportItlwm. */
    super::free();
}

IOWorkLoop *IOPCIEDeviceWrapper::getWorkLoop() const
{
    return _fWorkloop;
}

IOService* IOPCIEDeviceWrapper::
probe(IOService *provider, SInt32 *score)
{
    XYLog("%s\n", __PRETTY_FUNCTION__);
    if (!super::probe(provider, score))
        return NULL;

    IOUSBHostInterface *interface = OSDynamicCast(IOUSBHostInterface, provider);
    if (!interface) {
        XYLog("%s: provider bukan IOUSBHostInterface\n", __FUNCTION__);
        return NULL;
    }

    OSNumber *vid = OSDynamicCast(OSNumber, interface->getProperty("idVendor"));
    OSNumber *pid = OSDynamicCast(OSNumber, interface->getProperty("idProduct"));
    if (!vid || !pid) {
        IOUSBHostDevice *dev = interface->getDevice();
        if (!dev)
            return NULL;
        vid = OSDynamicCast(OSNumber, dev->getProperty("idVendor"));
        pid = OSDynamicCast(OSNumber, dev->getProperty("idProduct"));
    }
    if (!vid || !pid ||
        vid->unsigned32BitValue() != RTL8188EUS_VID ||
        pid->unsigned32BitValue() != RTL8188EUS_PID) {
        XYLog("%s: bukan RTL8188EUS (vid/pid tidak cocok)\n", __FUNCTION__);
        return NULL;
    }

    fInterface = interface;
    fInterface->retain();
    pciNub = NULL;

    ItlRtl8188E *hal = new ItlRtl8188E;
    if (!hal || !hal->init()) {
        XYLog("%s: gagal membuat HAL\n", __FUNCTION__);
        if (hal) hal->release();
        fInterface->release();
        fInterface = NULL;
        return NULL;
    }
    if (!hal->prepare(interface)) {
        XYLog("%s: HAL prepare gagal\n", __FUNCTION__);
        hal->release();
        fInterface->release();
        fInterface = NULL;
        return NULL;
    }
    fHalService = hal;
    return this;
}

bool IOPCIEDeviceWrapper::
start(IOService *provider)
{
    XYLog("%s\n", __PRETTY_FUNCTION__);
    _fWorkloop = IO80211WorkQueue::workQueue();
    if (!super::start(provider))
        return false;
    if (!_fWorkloop) {
        XYLog("%s: workloop gagal\n", __FUNCTION__);
        return false;
    }
    UInt8 builtIn = 0;
    setProperty("built-in", OSData::withBytes(&builtIn, sizeof(builtIn)));
    static IOPMPowerState powerStateArray[2] = {
        {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {1, kIOPMDeviceUsable, kIOPMPowerOn, kIOPMPowerOn, 0, 0, 0, 0, 0, 0, 0, 0}
    };
    PMinit();
    registerPowerDriver(this, powerStateArray, 2);
    provider->joinPMtree(this);
    registerService();
    return true;
}

void IOPCIEDeviceWrapper::
stop(IOService *provider)
{
    XYLog("%s\n", __PRETTY_FUNCTION__);
    PMstop();
    super::stop(provider);
}

IOReturn IOPCIEDeviceWrapper::
setPowerState(unsigned long powerStateOrdinal, IOService *whatDevice)
{
    return IOPMAckImplied;
}
