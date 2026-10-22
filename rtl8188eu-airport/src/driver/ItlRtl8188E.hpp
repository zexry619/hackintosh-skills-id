/*
 * ItlRtl8188E.hpp — HAL service untuk chip RTL8188E USB.
 *
 * Menghubungkan net80211 (port itlwm/OpenBSD) dengan chip RTL8188EUS:
 *   - init chip: power-on → DMA/LLT → firmware → EFUSE → MAC/BB/RF
 *   - ic_newstate: scan (ganti kanal + dwell) dan transisi state
 *   - TX: mgmt queue + data queue → descriptor USB 32 byte → bulk OUT
 *   - RX: bulk IN → ieee80211_inputm()
 *
 * Lisensi: GPL-2.0-or-later
 */

#ifndef RTL8188EU_ITL_RTL8188E_HPP
#define RTL8188EU_ITL_RTL8188E_HPP

#include <IOKit/IOService.h>
#include <IOKit/IOLocks.h>
#include <IOKit/network/IOEthernetController.h>
#include <IOKit/network/IONetworkInterface.h>
#include <IOKit/network/IONetworkController.h>
#include <IOKit/pci/IOPCIDevice.h>
#include <IOKit/usb/IOUSBHostInterface.h>
#include <IOKit/usb/IOUSBHostDevice.h>
#include <IOKit/IOTimerEventSource.h>

#include "HAL/ItlHalService.hpp"
#include "HAL/ItlDriverInfo.hpp"
#include "HAL/ItlDriverController.hpp"

#include "rtwn_m1.h"

class ItlRtl8188E : public ItlHalService, public ItlDriverInfo,
    public ItlDriverController {
public:
	OSDeclareDefaultStructors(ItlRtl8188E)

public:
	bool init() override;
	void free() override;

	/* Dipanggil wrapper sebelum attach(); menyimpan interface USB. */
	bool prepare(IOUSBHostInterface *interface);

	/* --- ItlHalService --- */
	bool attach(IOPCIDevice *device) override;
	void detach(IOPCIDevice *device) override;
	IOReturn enable(IONetworkInterface *interface) override;
	IOReturn disable(IONetworkInterface *interface) override;
	struct ieee80211com *get80211Controller() override;
	ItlDriverInfo *getDriverInfo() override { return this; }
	ItlDriverController *getDriverController() override { return this; }

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
	IOUSBHostInterface *fInterface;
	IOUSBHostDevice    *fDevice;

	bool         fAttached;
	bool         fEnabled;
	bool         fScanning;
	bool         fScanSeen;
	bool         fChipReady;
	bool         fBulkReady;
	bool         fIfAttached;
	bool         fSawRx;
	uint32_t     fTxQueueSize;
	uint8_t      fMac[6];
	char         fFirmwareVersion[32];
	char         fCountryCode[8];

	/* net80211 */
	struct ieee80211com fIc;
	CTimeout           *fScanTo;
	int (*fOrigNewstate)(struct ieee80211com *, enum ieee80211_state, int);

	/*
	 * RX diserialisasi ke workloop IO80211 lewat timer 0 ms.
	 * Callback USB hanya menyalin buffer (tidak boleh memblokir
	 * workloop USB — bisa deadlock dengan control transfer).
	 */
	static const uint32_t kRxQueueDepth = 64;
	IOTimerEventSource *fRxTimer;
	IOLock             *fRxLock;
	uint8_t            *fRxBuf[kRxQueueDepth];
	uint32_t            fRxLen[kRxQueueDepth];
	uint32_t            fRxHead;
	uint32_t            fRxCount;
	volatile bool       fRxRunning;

	/* ------------------------------------------------------------------ */
	/* Callback statis (dipanggil net80211 / USB)                          */
	/* ------------------------------------------------------------------ */
	static int  halRead(void *ctx, uint16_t addr, void *buf, uint16_t len);
	static int  halWrite(void *ctx, uint16_t addr, const void *buf, uint16_t len);
	static void rxCb(void *ctx, const uint8_t *data, uint32_t len);
	static void txStartCb(struct _ifnet *ifp);
	static int  newstateCb(struct ieee80211com *ic,
	    enum ieee80211_state nstate, int arg);
	static void scanTimeoutCb(void *arg);
	static void watchdogCb(struct _ifnet *ifp);
	void rxTimerAction(IOTimerEventSource *timer);
	void rxQueueFree(void);

	void handleRx(const uint8_t *buf, uint32_t len);
	void txStart(struct _ifnet *ifp);
	void sendFrame(mbuf_t m, struct ieee80211_node *ni, bool isMgmt);
	void setChannel(struct ieee80211_channel *chan);
	void setDiag(const char *key, const char *value);
	int  initChip(void);
	void stopChip(void);
};

#endif /* RTL8188EU_ITL_RTL8188E_HPP */
