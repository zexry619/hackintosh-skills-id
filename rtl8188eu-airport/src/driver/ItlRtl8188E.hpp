/*
 * ItlRtl8188E.hpp — HAL service untuk chip RTL8188E USB.
 *
 * Mengimplementasikan ItlHalService + ItlDriverInfo + ItlDriverController
 * (dari itlwm: include/HAL/*.hpp) — interface yang dipakai frontend
 * AirportItlwm (IO80211Controller).
 *
 * Lisensi: GPL-2.0-or-later
 */

#ifndef RTL8188EU_ITL_RTL8188E_HPP
#define RTL8188EU_ITL_RTL8188E_HPP

#include <IOKit/IOService.h>
#include <IOKit/network/IOEthernetController.h>
#include <IOKit/network/IONetworkInterface.h>
#include <IOKit/network/IONetworkController.h>
#include <IOKit/pci/IOPCIDevice.h>

#include "HAL/ItlHalService.hpp"
#include "HAL/ItlDriverInfo.hpp"
#include "HAL/ItlDriverController.hpp"

#include "rtwn_m1.h"

/* net80211 (dari itl80211 / OpenBSD) */
extern "C" {
#include "ieee80211_var.h"
}

class ItlRtl8188E : public ItlHalService, public ItlDriverInfo,
    public ItlDriverController {
public:
	/* OSDeclareDefaultStructors → constructor dari OSObject (sama seperti
	 * ItlIwx di itlwm). */
	OSDeclareDefaultStructors(ItlRtl8188E);
	bool init() override;

	/* --- ItlHalService --- */
	bool attach(IOPCIDevice *device) override;
	void detach(IOPCIDevice *device) override;
	IOReturn enable(IONetworkInterface *interface) override;
	IOReturn disable(IONetworkInterface *interface) override;
	struct ieee80211com *get80211Controller() override;

	/* --- ItlDriverInfo --- */
	const char *getFirmwareVersion() override;
	int16_t getBSSNoise() override;
	bool is5GBandSupport() override;
	int getTxNSS() override;
	const char *getFirmwareName() override;
	UInt32 supportedFeatures() override;
	const char *getFirmwareCountryCode() override;
	uint32_t getTxQueueSize() override;

	/* --- ItlDriverController --- */
	void clearScanningFlags() override;
	IOReturn setMulticastList(IOEthernetAddress *addr, int count) override;

	/* --- internal --- */
	void setMacAddress(const uint8_t *mac);
	void setFirmwareVersion(const char *ver);
	void setCountryCode(const char *cc);

	rtwn_m1_t   fChip;
	bool         fAttached;
	bool         fEnabled;
	bool         fScanning;
	uint32_t     fTxQueueSize;
	char         fFirmwareVersion[32];
	char         fCountryCode[8];

	/* Instance net80211 (dicetak oleh helper di rtwn_net80211.cpp). */
	struct {
		struct ieee80211com ic;
	} fNet80211;
};

#endif /* RTL8188EU_ITL_RTL8188E_HPP */
