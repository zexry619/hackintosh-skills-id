/*
 * RTL8188EUHello — Milestone 0 smoke-test kext untuk RTL8188EUS (2357:010c).
 *
 * TUJUAN:
 *   Membuktikan toolchain build kext di mesin ini, memastikan personality IOKit
 *   cocok dengan adapter USB, dan mengumpulkan informasi deskriptor USB yang
 *   dibutuhkan untuk menulis driver sungguhan (Layer 1 & 2).
 *
 * KEAMANAN:
 *   Kext ini READ-ONLY. Tidak ada pipe USB yang dibuka, tidak ada transfer,
 *   tidak ada perubahan konfigurasi perangkat. Hanya membaca deskriptor &
 *   properti registry. Aman dijalankanippun dengan RtWlanU masih aktif.
 *
 * Lisensi: GPL-2.0-or-later (lihat ../../LICENSES.md)
 */

#include <IOKit/IOService.h>
#include <IOKit/IOLib.h>
#include <IOKit/IORegistryEntry.h>
#include <IOKit/usb/IOUSBHostDevice.h>
#include <IOKit/usb/IOUSBHostInterface.h>
#include <IOKit/usb/StandardUSB.h>

#define LOGP "RTL8188EUHello: "

static const char *speedName(uint8_t speed)
{
	switch (speed) {
	case kUSBHostConnectionSpeedLow:   return "low (1.5 Mb/s)";
	case kUSBHostConnectionSpeedFull:  return "full (12 Mb/s)";
	case kUSBHostConnectionSpeedHigh:  return "high (480 Mb/s)";
	case kUSBHostConnectionSpeedSuper: return "super (5 Gb/s)";
	default:                           return "unknown";
	}
}

static void logProperty(IOService *provider, const char *key)
{
	OSObject *obj = provider->getProperty(key);
	if (!obj) {
		IOLog(LOGP "%-26s = <tidak ada>\n", key);
		return;
	}

	if (OSString *s = OSDynamicCast(OSString, obj)) {
		IOLog(LOGP "%-26s = \"%s\"\n", key, s->getCStringNoCopy());
	} else if (OSNumber *n = OSDynamicCast(OSNumber, obj)) {
		IOLog(LOGP "%-26s = %u (0x%04x)\n", key,
		      n->unsigned32BitValue(), n->unsigned32BitValue());
	} else {
		IOLog(LOGP "%-26s = <%s>\n", key, obj->getMetaClass()->getClassName());
	}
}

/* Cari class driver yang sudah attach ke node tertentu (mis. "RtWlanU"). */
static bool hasDriverClass(IORegistryEntry *entry, const char *className)
{
	OSIterator *it = entry->getChildIterator(gIOServicePlane);
	if (!it) {
		return false;
	}

	bool found = false;
	OSObject *child = nullptr;
	while ((child = it->getNextObject())) {
		IORegistryEntry *childEntry = OSDynamicCast(IORegistryEntry, child);
		if (childEntry) {
			OSObject *cls = childEntry->getProperty("IOClass");
			OSString *clsStr = OSDynamicCast(OSString, cls);
			if (clsStr && clsStr->isEqualTo(className)) {
				found = true;
			}
		}
		child->release();
	}
	it->release();
	return found;
}

class RTL8188EUHello : public IOService {
	OSDeclareDefaultStructors(RTL8188EUHello);
public:
	bool start(IOService *provider) override;
	void stop(IOService *provider) override;
};

OSDefineMetaClassAndStructors(RTL8188EUHello, IOService);

bool RTL8188EUHello::start(IOService *provider)
{
	IOLog(LOGP "start() — provider: %s\n", provider ? provider->getName() : "<null>");
	if (!provider) {
		return false;
	}

	IOUSBHostDevice *device = OSDynamicCast(IOUSBHostDevice, provider);
	if (!device) {
		IOLog(LOGP "provider bukan IOUSBHostDevice — abort\n");
		return false;
	}

	/* --- Properti registry --- */
	static const char *props[] = {
		"idVendor", "idProduct", "bcdDevice",
		"USB Product Name", "USB Vendor Name", "USB Serial Number",
		"locationID", "USB Address", "kUSBHostDevicePropertySpeed",
	};
	for (size_t i = 0; i < sizeof(props) / sizeof(props[0]); i++) {
		logProperty(provider, props[i]);
	}

	/* --- Device descriptor --- */
	const StandardUSB::DeviceDescriptor *dd = device->getDeviceDescriptor();
	if (dd) {
		IOLog(LOGP "device descriptor: bLength=%u bDescriptorType=%u "
		      "bcdUSB=%04x bDeviceClass=%u bDeviceSubClass=%u "
		      "bDeviceProtocol=%u bMaxPacketSize0=%u\n",
		      dd->bLength, dd->bDescriptorType, dd->bcdUSB,
		      dd->bDeviceClass, dd->bDeviceSubClass, dd->bDeviceProtocol,
		      dd->bMaxPacketSize0);
		IOLog(LOGP "idVendor=0x%04x idProduct=0x%04x bcdDevice=0x%04x\n",
		      dd->idVendor, dd->idProduct, dd->bcdDevice);
	} else {
		IOLog(LOGP "device descriptor: <tidak tersedia>\n");
	}

	IOLog(LOGP "speed: %s\n", speedName(device->getSpeed()));

	/* --- Configuration descriptor --- */
	const StandardUSB::ConfigurationDescriptor *cd = device->getConfigurationDescriptor();
	if (cd) {
		IOLog(LOGP "configuration: bConfigurationValue=%u bNumInterfaces=%u "
		      "bmAttributes=0x%02x MaxPower=%u mA\n",
		      cd->bConfigurationValue, cd->bNumInterfaces,
		      cd->bmAttributes, cd->bMaxPower);
	} else {
		IOLog(LOGP "configuration: <tidak tersedia>\n");
	}

	/* --- Interface & endpoint --- */
	OSIterator *it = provider->getChildIterator(gIOServicePlane);
	if (it) {
		OSObject *child = nullptr;
		while ((child = it->getNextObject())) {
			IOUSBHostInterface *iface = OSDynamicCast(IOUSBHostInterface, child);
			if (!iface) {
				child->release();
				continue;
			}

			const StandardUSB::InterfaceDescriptor *id = iface->getInterfaceDescriptor();
			if (id) {
				IOLog(LOGP "interface %u: class=%u subclass=%u protocol=%u "
				      "endpoints=%u altSetting=%u\n",
				      id->bInterfaceNumber, id->bInterfaceClass,
				      id->bInterfaceSubClass, id->bInterfaceProtocol,
				      id->bNumEndpoints, id->bAlternateSetting);
			}

			if (cd && id) {
				const StandardUSB::EndpointDescriptor *ep = nullptr;
				while ((ep = StandardUSB::getNextEndpointDescriptor(
				            cd, id, ep)) != nullptr) {
					IOLog(LOGP "  endpoint addr=0x%02x attrs=0x%02x "
					      "maxPacket=%u interval=%u\n",
					      ep->bEndpointAddress, ep->bmAttributes,
					      ep->wMaxPacketSize, ep->bInterval);
				}
			}

			if (hasDriverClass(iface, "RtWlanU")) {
				IOLog(LOGP "  ⚠️  driver vendor 'RtWlanU' SUDAH bind di "
				      "interface ini — matikan sebelum menguji driver kita\n");
			} else {
				IOLog(LOGP "  (tidak ada driver vendor yang bind di interface ini)\n");
			}

			child->release();
		}
		it->release();
	}

	IOLog(LOGP "start() selesai. Data di atas dipakai untuk Layer 1/2.\n");
	return IOService::start(provider);
}

void RTL8188EUHello::stop(IOService *provider)
{
	IOLog(LOGP "stop()\n");
	IOService::stop(provider);
}
