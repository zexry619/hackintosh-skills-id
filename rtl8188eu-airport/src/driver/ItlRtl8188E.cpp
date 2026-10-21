/*
 * ItlRtl8188E — HAL service untuk chip RTL8188E USB.
 *
 * Mengimplementasikan 3 interface yang dibutuhkan frontend AirportItlwm:
 *   - ItlHalService      : attach/detach/enable/disable/get80211Controller
 *   - ItlDriverInfo      : kapabilitas chip (firmware, tx queue, features, country)
 *   - ItlDriverController: kontrol chip (scan flag, multicast)
 *
 * Frontend AirportItlwm (IO80211Controller)wbr不容 talks ke driver chip
 * HANYA lewat interface-interface ini — jadi adaptasi M4 cukup mengganti
 * `IOPCIEDeviceWrapper` → `UsbBackend` di AirportItlwm.cpp.
 *
 * Lisensi: GPL-2.0-or-later
 */

#include "ItlRtl8188E.hpp"
#include "rtwn_seq.h"
#include "rtwn_usb.h"

#include <string.h>

/*
 * Init dari OSObject::init() (OSDeclareDefaultStructors).
 * Dipanggil itlwm lewat 'new ItlRtl8188E'.
 */
bool ItlRtl8188E::init()
{
	memset(&fChip, 0, sizeof(fChip));
	fAttached = false;
	fEnabled = false;
	fScanning = false;
	fTxQueueSize = 64;
	fFirmwareVersion[0] = 0;
	fCountryCode[0] = 0;
	return true;
}

/* ------------------------------------------------------------------ */
/*  ItlHalService                                                      */
/* ------------------------------------------------------------------ */

/*
 * attach() — dipanggil frontend saat menemukan device.
 * Di implementasi USB (bukan PCI), attach menerima nullptr dan device
 * sudah disiapkan lewat prepare().
 */
bool ItlRtl8188E::attach(IOPCIDevice *device)
{
	(void)device;
	fAttached = true;
	return true;
}

void ItlRtl8188E::detach(IOPCIDevice *device)
{
	(void)device;
	fAttached = false;
	fEnabled = false;
}

IOReturn ItlRtl8188E::enable(IONetworkInterface *interface)
{
	(void)interface;
	fEnabled = true;
	return kIOReturnSuccess;
}

IOReturn ItlRtl8188E::disable(IONetworkInterface *interface)
{
	(void)interface;
	fEnabled = false;
	return kIOReturnSuccess;
}

struct ieee80211com *ItlRtl8188E::get80211Controller()
{
	return &fNet80211.ic;
}

/* ------------------------------------------------------------------ */
/*  ItlDriverInfo                                                      */
/* ------------------------------------------------------------------ */

const char *ItlRtl8188E::getFirmwareVersion(void)
{
	return fFirmwareVersion[0] ? fFirmwareVersion : "rtl8188eufw (1.28)";
}

int16_t ItlRtl8188E::getBSSNoise(void)
{
	/* Noise floor belum diukur → nilai konservatif. */
	return -95;
}

bool ItlRtl8188E::is5GBandSupport(void)
{
	return false;	/* 8188E = 2,4 GHz only */
}

int ItlRtl8188E::getTxNSS(void)
{
	return 1;	/* 1x1 */
}

const char *ItlRtl8188E::getFirmwareName(void)
{
	return "rtl8188eufw.bin";
}

UInt32 ItlRtl8188E::supportedFeatures(void)
{
	/* 8188E: 2,4 GHz, 11n, tanpa 5 GHz, tanpa AWDL. */
	return 0;
}

const char *ItlRtl8188E::getFirmwareCountryCode(void)
{
	return fCountryCode[0] ? fCountryCode : "US";
}

uint32_t ItlRtl8188E::getTxQueueSize(void)
{
	return fTxQueueSize;
}

/* ------------------------------------------------------------------ */
/*  ItlDriverController                                                */
/* ------------------------------------------------------------------ */

void ItlRtl8188E::clearScanningFlags(void)
{
	fScanning = false;
}

IOReturn ItlRtl8188E::setMulticastList(IOEthernetAddress *addr, int count)
{
	/*
	 * TODO(M2): tulis filter multicast ke hardware.
	 * Untuk 8188E, filter居住位 di register 0x0E (CAM) — perlu
	 * implementasi setelah M1/M2 tervalidasi.
	 */
	(void)addr;
	(void)count;
	return kIOReturnSuccess;
}

/* ------------------------------------------------------------------ */
/*  Kontrol internal                                                   */
/* ------------------------------------------------------------------ */

void ItlRtl8188E::setMacAddress(const uint8_t *mac)
{
	if (mac) {
		memcpy(fChip.macaddr, mac, 6);
	}
}

void ItlRtl8188E::setFirmwareVersion(const char *ver)
{
	if (ver) {
		strlcpy(fFirmwareVersion, ver, sizeof(fFirmwareVersion));
	}
}

void ItlRtl8188E::setCountryCode(const char *cc)
{
	if (cc) {
		strlcpy(fCountryCode, cc, sizeof(fCountryCode));
	}
}
