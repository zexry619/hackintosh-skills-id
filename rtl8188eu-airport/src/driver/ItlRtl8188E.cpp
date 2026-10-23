/*
 * ItlRtl8188E.cpp — HAL service RTL8188EUS untuk frontend AirportItlwm (M4).
 *
 * Jalur data:
 *   net80211 (port itlwm)  ──►  ic_newstate / if_start  ──►  bulk OUT
 *   bulk IN                ──►  ieee80211_inputm()      ──►  scan result / data
 *
 * Semua inisialisasi chip memakai modul portabel yang sama dengan
 * tools/rtwn_probe (sudah terbukti di hardware pada M1/M2).
 *
 * Lisensi: GPL-2.0-or-later
 */

#include "ItlRtl8188E.hpp"

#include <string.h>

#include <net80211/ieee80211_var.h>
#include <net80211/ieee80211_proto.h>
#include <net80211/ieee80211_node.h>

#include <sys/timeout.h>

extern "C" {
#include "r92creg.h"
#include "rtwn_seq.h"
#include "rtwn_init_8188e.h"
#include "rtwn_chan.h"
#include "rtwn_usb.h"
}

#define super ItlHalService
OSDefineMetaClassAndStructors(ItlRtl8188E, ItlHalService);

#define LOGP "rtl8188e: "

/* ------------------------------------------------------------------ */
/*  register access                                                    */
/* ------------------------------------------------------------------ */

int ItlRtl8188E::halRead(void *ctx, uint16_t addr, void *buf, uint16_t len)
{
	ItlRtl8188E *me = (ItlRtl8188E *)ctx;
	if (!me)
		return -1;
	return rtwn_m1_read_region(&me->fChip, addr, (uint8_t *)buf, len);
}

int ItlRtl8188E::halWrite(void *ctx, uint16_t addr, const void *buf,
    uint16_t len)
{
	ItlRtl8188E *me = (ItlRtl8188E *)ctx;
	if (!me)
		return -1;
	return rtwn_m1_write_region(&me->fChip, addr, (const uint8_t *)buf, len);
}

/* ------------------------------------------------------------------ */
/*  hidup/mati                                                         */
/* ------------------------------------------------------------------ */

bool ItlRtl8188E::init()
{
	if (!super::init())
		return false;
	memset(&fChip, 0, sizeof(fChip));
	memset(&fIc, 0, sizeof(fIc));
	fInterface = nullptr;
	fDevice = nullptr;
	fScanTo = nullptr;
	fOrigNewstate = nullptr;
	fAttached = false;
	fEnabled = false;
	fScanning = false;
	fScanSeen = false;
	fChipReady = false;
	fBulkReady = false;
	fIfAttached = false;
	fSawRx = false;
	fTxQueueSize = 64;
	fRxTimer = nullptr;
	fRxLock = nullptr;
	fRxHead = 0;
	fRxCount = 0;
	fRxRunning = false;
	memset(fRxBuf, 0, sizeof(fRxBuf));
	memset(fRxLen, 0, sizeof(fRxLen));
	fFirmwareVersion[0] = 0;
	fCountryCode[0] = 0;
	memset(fMac, 0, sizeof(fMac));
	fTxMgmt = fTxData = fTxEapol = fTxFail = 0;
	fRxMgmt = fRxData = fRxEapol = fEncryptFail = 0;
	fTxReport = fTxOk = fTxRetry = 0;
	fTxAuthReq = fTxAssocReq = fRxAuth = fRxAssocResp = 0;
	fJoinTry = 0;
	fRsnVariant = 0;
	fRxDelivered = 0;
	fRxDataLogged = 0;
	return true;
}

void ItlRtl8188E::free()
{
	/*
	 * Jaring pengaman: kalau start() gagal setelah attach net80211,
	 * frontend memanggil releaseAll() TANPA detach(). Timer net80211
	 * (slowtimo) akan menembak ifp yang sudah dibebaskan kalau ifdetach
	 * tidak dipanggil.
	 */
	fRxRunning = false;
	if (fAttached)
		fChip.usb.setRxCallback(nullptr, nullptr);
	if (fBulkReady) {
		fChip.usb.bulkClose();
		fBulkReady = false;
	}
	if (fScanTo) {
		timeout_del(&fScanTo);
		timeout_free(&fScanTo);
		fScanTo = nullptr;
	}
	if (fRxTimer) {
		fRxTimer->cancelTimeout();
		if (getMainWorkLoop())
			getMainWorkLoop()->removeEventSource(fRxTimer);
		fRxTimer->release();
		fRxTimer = nullptr;
	}
	rxQueueFree();
	if (fRxLock) {
		IOLockFree(fRxLock);
		fRxLock = nullptr;
	}
	if (fIfAttached && fIc.ic_if.if_snd.queue) {
		fIc.ic_newstate = fOrigNewstate;
		fOrigNewstate = nullptr;
		ieee80211_ifdetach(&fIc.ic_if);
		fIfAttached = false;
	}
	stopChip();
	if (fInterface) {
		fInterface->release();
		fInterface = nullptr;
	}
	if (fDevice) {
		fDevice->release();
		fDevice = nullptr;
	}
	super::free();
}

bool ItlRtl8188E::prepare(IOUSBHostInterface *interface)
{
	if (!interface)
		return false;
	fInterface = interface;
	fInterface->retain();
	fDevice = interface->getDevice();
	if (fDevice)
		fDevice->retain();
	return fDevice != nullptr;
}

/* ------------------------------------------------------------------ */
/*  init chip (urutan M1/M2 yang sudah terbukti)                       */
/* ------------------------------------------------------------------ */

int ItlRtl8188E::initChip(void)
{
	rtwn_seq_result_t res;
	rtwn_seq_result_t ef;
	int rc = 0;

	memset(&res, 0, sizeof(res));
	memset(&ef, 0, sizeof(ef));

	fChip.ntx = 3;

	if (rtwn_seq_power_on(&res, halRead, halWrite, this) != 0) {
		IOLog(LOGP "power-on gagal\n");
		return -1;
	}
	if (rtwn_seq_dma_init(&res, halRead, halWrite, this, 3) != 0) {
		IOLog(LOGP "DMA/LLT gagal\n");
		return -1;
	}
	if (rtwn_seq_load_firmware(&res, halRead, halWrite, this,
	    rtl8188eufw_bin, rtl8188eufw_bin_len) != 0) {
		IOLog(LOGP "firmware gagal (%u byte)\n", res.fwlen);
		return -1;
	}
	IOLog(LOGP "firmware OK (%u byte)\n", res.fwlen);

	if (rtwn_seq_read_efuse_offload(&ef, halRead, halWrite, this) == 0 &&
	    ef.efuse_ok) {
		memcpy(res.mac, ef.mac, 6);
		res.xtal = ef.xtal;
	} else if (rtwn_seq_read_efuse_direct_8188e(&ef, halRead, halWrite,
	    this) == 0 && ef.efuse_ok) {
		memcpy(res.mac, ef.mac, 6);
		res.xtal = ef.xtal;
	} else {
		IOLog(LOGP "EFUSE gagal, pakai MAC default\n");
		res.mac[0] = 0x02;
		res.mac[5] = 0x01;
		res.xtal = 0x20;
	}

	memcpy(fMac, res.mac, 6);
	memcpy(fChip.macaddr, res.mac, 6);
	fChip.xtal = res.xtal ? res.xtal : 0x20;

	IOLog(LOGP "MAC %02x:%02x:%02x:%02x:%02x:%02x xtal=0x%02x\n",
	    fMac[0], fMac[1], fMac[2], fMac[3], fMac[4], fMac[5], fChip.xtal);

	rc += rtwn_init_mac_8188e(halRead, halWrite, this);
	rc += rtwn_init_bb_8188e(halRead, halWrite, this, fChip.xtal);
	rc += rtwn_init_rf_8188e(halRead, halWrite, this);
	rc += rtwn_core_config_8188e(halRead, halWrite, this, fMac);

	IOSleep(20);
	fChipReady = true;
	IOLog(LOGP "init selesai (%d register)\n", rc);
	return 0;
}

void ItlRtl8188E::stopChip(void)
{
	if (fBulkReady) {
		fChip.usb.setRxCallback(nullptr, nullptr);
		fChip.usb.bulkClose();
		fBulkReady = false;
	}
	if (fChipReady) {
		/* Radio off supaya chip tidak memancar saat unload. */
		rtwn_flow_radio_off_8188e(halRead, halWrite, this);
		fChipReady = false;
	}
	if (fAttached) {
		fChip.usb.detach();
		fAttached = false;
	}
}

/* ------------------------------------------------------------------ */
/*  ItlHalService                                                      */
/* ------------------------------------------------------------------ */

bool ItlRtl8188E::attach(IOPCIDevice *device)
{
	(void)device;

	if (fAttached)
		return true;
	if (!fInterface)
		return false;

	setDiag("RTL8188E-stage", "usb-attach");
	if (fChip.usb.attach(getController(), fDevice, fInterface) != 0) {
		IOLog(LOGP "usb attach gagal\n");
		setDiag("RTL8188E-stage", "fail-usb-attach");
		return false;
	}
	fAttached = true;

	setDiag("RTL8188E-stage", "chip-init");
	if (initChip() != 0) {
		IOLog(LOGP "init chip gagal\n");
		setDiag("RTL8188E-stage", "fail-chip-init");
		stopChip();
		return false;
	}

	if (!fChip.usb.bulkOpen(fInterface)) {
		IOLog(LOGP "bulkOpen gagal\n");
		setDiag("RTL8188E-stage", "fail-bulk-open");
		stopChip();
		return false;
	}
	setDiag("RTL8188E-stage", "net80211-attach");

	/* ---------------- net80211 ---------------- */
	struct _ifnet *ifp = &fIc.ic_if;

	IEEE80211_ADDR_COPY(fIc.ic_myaddr, fMac);
	fIc.ic_phytype = IEEE80211_T_OFDM;
	fIc.ic_opmode = IEEE80211_M_STA;
	fIc.ic_state = IEEE80211_S_INIT;
	fIc.ic_curmode = IEEE80211_MODE_11G;
	fIc.ic_caps = IEEE80211_C_WEP | IEEE80211_C_RSN |
	    IEEE80211_C_SHSLOT | IEEE80211_C_SHPREAMBLE;
	/*
	 * Uji hardware pertama: 802.11g saja. HT/AMPDU dimatikan karena
	 * jalur TX kita masih laju tetap 1 Mb/s dan belum menangani
	 * agregasi; menyalakannya hanya menambah jalur yang belum diuji.
	 * Aktifkan kembali setelah asosiasi/WPA2 terbukti.
	 */
	fIc.ic_htcaps = 0;
	fIc.ic_sup_rates[IEEE80211_MODE_11B] = ieee80211_std_rateset_11b;
	fIc.ic_sup_rates[IEEE80211_MODE_11G] = ieee80211_std_rateset_11g;
	fIc.ic_sup_mcs[0] = 0;
	fIc.ic_htxcaps = 0;
	fIc.ic_txbfcaps = 0;
	fIc.ic_aselcaps = 0;
	fIc.ic_ampdu_params = 0;
	fIc.ic_max_rssi = 100;

	/*
	 * Tabel kanal 2.4 GHz WAJIB diisi SEBELUM ieee80211_ifattach.
	 * ieee80211_channel_init() hanya memvalidasi kanal yang sudah
	 * bertanda; tanpa ini ic_chan_avail kosong dan scan tidak pernah
	 * mengunjungi satu kanal pun.
	 */
	for (uint32_t ch = 1; ch <= 14; ch++) {
		struct ieee80211_channel *c = &fIc.ic_channels[ch];
		c->ic_freq = ieee80211_ieee2mhz(ch, IEEE80211_CHAN_2GHZ);
		c->ic_flags = IEEE80211_CHAN_2GHZ |
		    IEEE80211_CHAN_CCK | IEEE80211_CHAN_OFDM;
	}
	fIc.ic_ibss_chan = &fIc.ic_channels[1];

	ifp->if_softc = this;
	ifp->if_flags = IFF_BROADCAST | IFF_SIMPLEX | IFF_MULTICAST;
	ifp->if_start = txStartCb;
	ifp->if_ioctl = ieee80211_ioctl;
	ifp->if_watchdog = watchdogCb;
	strlcpy(ifp->if_xname, "wlan0", IFNAMSIZ);

	if_attach(ifp);
	ieee80211_ifattach(ifp, getController());
	ieee80211_media_init(ifp);

	fOrigNewstate = fIc.ic_newstate;
	fIc.ic_newstate = newstateCb;

	timeout_set(&fScanTo, scanTimeoutCb, this);
	fIfAttached = true;

	/*
	 * RX baru dimulai SETELAH net80211 siap. Kalau tidak, frame yang
	 * datang lebih awal akan memanggil ieee80211_inputm pada ic_bss
	 * yang masih NULL → panic.
	 */
	fRxLock = IOLockAlloc();
	fRxTimer = IOTimerEventSource::timerEventSource(this,
	    OSMemberFunctionCast(IOTimerEventSource::Action, this,
	    &ItlRtl8188E::rxTimerAction));
	if (!fRxLock || !fRxTimer || !getMainWorkLoop() ||
	    getMainWorkLoop()->addEventSource(fRxTimer) != kIOReturnSuccess) {
		IOLog(LOGP "gagal membuat RX event source\n");
		if (fRxTimer) {
			fRxTimer->release();
			fRxTimer = nullptr;
		}
		if (fRxLock) {
			IOLockFree(fRxLock);
			fRxLock = nullptr;
		}
		ieee80211_ifdetach(&fIc.ic_if);
		fIfAttached = false;
		stopChip();
		return false;
	}
	fRxTimer->enable();
	fRxRunning = true;
	fChip.usb.setRxCallback(rxCb, this);
	if (!fChip.usb.bulkQueueRx(8)) {
		IOLog(LOGP "gagal antre RX\n");
		fRxRunning = false;
		fChip.usb.setRxCallback(nullptr, nullptr);
		getMainWorkLoop()->removeEventSource(fRxTimer);
		fRxTimer->release();
		fRxTimer = nullptr;
		ieee80211_ifdetach(&fIc.ic_if);
		fIfAttached = false;
		stopChip();
		return false;
	}
	fBulkReady = true;
	setDiag("RTL8188E-stage", "net80211-ready");
	if (getController()) {
		OSData *mac = OSData::withBytes(fMac, IEEE80211_ADDR_LEN);

		if (mac) {
			getController()->setProperty("RTL8188E-mac", mac);
			mac->release();
		}
	}
	IOLog(LOGP "net80211 attach OK (state INIT)\n");
	return true;
}

void ItlRtl8188E::detach(IOPCIDevice *device)
{
	(void)device;

	/* 1. Hentikan sumber RX — jangan ada frame baru saat ifdetach. */
	fRxRunning = false;
	if (fAttached)
		fChip.usb.setRxCallback(nullptr, nullptr);
	/*
	 * Tutup pipe RX lebih dulu: bulkClose() melakukan abort sinkron,
	 * jadi setelah ini tidak ada completion yang boleh menyentuh
	 * fRxLock/fRxTimer yang akan dibebaskan di bawah.
	 */
	if (fBulkReady) {
		fChip.usb.bulkClose();
		fBulkReady = false;
	}
	if (fRxTimer) {
		fRxTimer->cancelTimeout();
		if (getMainWorkLoop())
			getMainWorkLoop()->removeEventSource(fRxTimer);
		fRxTimer->release();
		fRxTimer = nullptr;
	}
	rxQueueFree();
	if (fRxLock) {
		IOLockFree(fRxLock);
		fRxLock = nullptr;
	}

	/* 2. Timer scan + state machine. */
	if (fScanTo) {
		timeout_del(&fScanTo);
		timeout_free(&fScanTo);
		fScanTo = nullptr;
	}
	if (fOrigNewstate) {
		fIc.ic_newstate = fOrigNewstate;
		fOrigNewstate = nullptr;
	}
	if (fIfAttached && fIc.ic_if.if_snd.queue) {
		ieee80211_ifdetach(&fIc.ic_if);
		fIfAttached = false;
	}
	fBulkReady = false;
	stopChip();
	if (fIc.ic_event_handler)
		fIc.ic_event_handler(&fIc, IEEE80211_EVT_DRIVER_STOPPED, NULL);
	fEnabled = false;
}

void ItlRtl8188E::updateMACAddress(const uint8_t *mac)
{
	if (!mac)
		return;
	for (int i = 0; i < IEEE80211_ADDR_LEN; i++) {
		fMac[i] = mac[i];
		fChip.macaddr[i] = mac[i];
		halWrite(this, R92C_MACID + i, &mac[i], 1);
	}
	IOLog(LOGP "MAC address hardware disinkronkan ke %02x:%02x:%02x:%02x:%02x:%02x\n",
	    mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
}

IOReturn ItlRtl8188E::enable(IONetworkInterface *interface)
{
	(void)interface;
	struct _ifnet *ifp = &fIc.ic_if;

	/* Pastikan register MAC chip cocok dengan ic_myaddr */
	for (int i = 0; i < IEEE80211_ADDR_LEN; i++) {
		uint8_t b = fIc.ic_myaddr[i];
		halWrite(this, R92C_MACID + i, &b, 1);
		fMac[i] = b;
		fChip.macaddr[i] = b;
	}

	if (ifp->if_flags & IFF_UP)
		return kIOReturnSuccess;

	ifp->if_flags |= IFF_UP | IFF_RUNNING;
	fEnabled = true;
	fRxRunning = true;
	setDiag("RTL8188E-stage", "enabled");

	if (fIc.ic_event_handler)
		fIc.ic_event_handler(&fIc, IEEE80211_EVT_DRIVER_RESET_BEGIN, NULL);

	if (fIc.ic_state == IEEE80211_S_INIT)
		ieee80211_new_state(&fIc, IEEE80211_S_SCAN, -1);

	if (fIc.ic_event_handler)
		fIc.ic_event_handler(&fIc, IEEE80211_EVT_DRIVER_READY, NULL);

	return kIOReturnSuccess;
}

IOReturn ItlRtl8188E::disable(IONetworkInterface *interface)
{
	(void)interface;
	struct _ifnet *ifp = &fIc.ic_if;

	if (!(ifp->if_flags & IFF_UP))
		return kIOReturnSuccess;

	ifp->if_flags &= ~(IFF_UP | IFF_RUNNING);
	fEnabled = false;
	fRxRunning = false;
	setDiag("RTL8188E-stage", "disabled");
	if (fScanTo)
		timeout_del(&fScanTo);
	if (fIc.ic_state != IEEE80211_S_INIT)
		ieee80211_new_state(&fIc, IEEE80211_S_INIT, -1);

	if (fIc.ic_event_handler)
		fIc.ic_event_handler(&fIc, IEEE80211_EVT_DRIVER_STOPPED, NULL);

	return kIOReturnSuccess;
}

struct ieee80211com *ItlRtl8188E::get80211Controller()
{
	return &fIc;
}

/* ------------------------------------------------------------------ */
/*  net80211 state machine                                             */
/* ------------------------------------------------------------------ */

/*
 * Diagnostik lewat ioreg (log show rusak di mesin ini):
 *   ioreg -r -c AirportItlwm -l | grep RTL8188E
 *   ioreg -r -c IOPCIEDeviceWrapper -l | grep RTL8188E
 * Nilai dipasang pada controller DAN provider (wrapper) supaya tetap
 * terlihat walau start() frontend gagal.
 */
void ItlRtl8188E::setDiag(const char *key, const char *value)
{
	IOService *svc = getController();

	if (!svc || !key || !value)
		return;
	svc->setProperty(key, value);
	IOService *provider = svc->getProvider();

	if (provider)
		provider->setProperty(key, value);
}

void ItlRtl8188E::publishStats(void)
{
	char s[192];

	snprintf(s, sizeof(s),
	    "txm=%u txd=%u txe=%u txf=%u rpt=%u txok=%u rty=%u "
	    "rxm=%u rxd=%u rxe=%u encf=%u pipe=%d "
	    "auth=%u/%u assoc=%u/%u try=%u rsnv=%u dlv=%u",
	    (unsigned)fTxMgmt, (unsigned)fTxData, (unsigned)fTxEapol,
	    (unsigned)fTxFail, (unsigned)fTxReport, (unsigned)fTxOk,
	    (unsigned)fTxRetry, (unsigned)fRxMgmt, (unsigned)fRxData,
	    (unsigned)fRxEapol, (unsigned)fEncryptFail,
	    fChip.usb.txPipeCount(),
	    (unsigned)fTxAuthReq, (unsigned)fRxAuth,
	    (unsigned)fTxAssocReq, (unsigned)fRxAssocResp,
	    (unsigned)fJoinTry, (unsigned)fRsnVariant,
	    (unsigned)fRxDelivered);
	setDiag("RTL8188E-stat", s);
}

void ItlRtl8188E::setChannel(struct ieee80211_channel *chan)
{
	if (!chan)
		return;
	uint8_t ch = (uint8_t)ieee80211_chan2ieee(&fIc, chan);
	if (ch >= 1 && ch <= 14) {
		char stage[24];

		snprintf(stage, sizeof(stage), "ch-%u", ch);
		setDiag("RTL8188E-scan", stage);
		if (rtwn_set_chan_8188e(halRead, halWrite, this, ch) != 0)
			IOLog(LOGP "set kanal %u gagal\n", ch);
	}
}

/*
 * Varian RSN per percobaan join.
 *
 * AP ZEKRI.NET mengiklankan WPA2-PSK-CCMP tetapi juga WPA3-transition
 * (RSN caps MFPC+MFPR). Driver tidak membalas assoc request apa pun
 * varian RSN yang dipakai net80211 dari macOS — AP diam, bukan menolak.
 *
 * Karena kext IO80211 hanya bisa dimuat saat boot, mencoba satu varian
 * per reboot terlalu mahal. Fungsi ini mengganti parameter RSN pada
 * setiap siklus join, jadi SATU boot mencoba beberapa kombinasi sampai
 * ada yang diterima AP.
 *
 *   1  apa adanya dari macOS (baseline)
 *   2  CCMP saja (buang TKIP)
 *   3  WPA1+WPA2, CCMP+TKIP (kompatibilitas maksimum)
 *   4  WPA1 saja, TKIP+CCMP (AP lama)
 *   5  tanpa RSN (open assoc) — diagnostik: membuktikan apakah RSN IE
 *      yang membuat AP diam
 */
void ItlRtl8188E::applyRsnVariant(uint32_t attempt)
{
	struct ieee80211com *ic = &fIc;
	uint8_t v;

	if (!(ic->ic_flags & IEEE80211_F_RSNON) && attempt <= 1)
		return;		/* tidak ada RSN aktif, tidak perlu varian */

	/* 1..5 lalu ulang 2..5 (baseline tidak diulang) */
	v = (uint8_t)(attempt <= 1 ? 1 : ((attempt - 2) % 4) + 2);
	fRsnVariant = v;

	switch (v) {
	case 1:
		IOLog(LOGP "rsn-varian 1: baseline macOS\n");
		break;
	case 2:
		ic->ic_flags |= IEEE80211_F_RSNON;
		ic->ic_rsnciphers = IEEE80211_CIPHER_CCMP;
		ic->ic_rsngroupcipher = IEEE80211_CIPHER_CCMP;
		ic->ic_rsnakms = IEEE80211_AKM_PSK;
		IOLog(LOGP "rsn-varian 2: CCMP saja\n");
		break;
	case 3:
		ic->ic_flags |= IEEE80211_F_RSNON;
		ic->ic_rsnprotos = IEEE80211_PROTO_WPA | IEEE80211_PROTO_RSN;
		ic->ic_rsnciphers = IEEE80211_CIPHER_CCMP |
		    IEEE80211_CIPHER_TKIP;
		ic->ic_rsngroupcipher = IEEE80211_CIPHER_CCMP;
		ic->ic_rsnakms = IEEE80211_AKM_PSK;
		IOLog(LOGP "rsn-varian 3: WPA1+WPA2 CCMP+TKIP\n");
		break;
	case 4:
		ic->ic_flags |= IEEE80211_F_RSNON;
		ic->ic_rsnprotos = IEEE80211_PROTO_WPA;
		ic->ic_rsnciphers = IEEE80211_CIPHER_TKIP |
		    IEEE80211_CIPHER_CCMP;
		ic->ic_rsngroupcipher = IEEE80211_CIPHER_TKIP;
		ic->ic_rsnakms = IEEE80211_AKM_PSK;
		IOLog(LOGP "rsn-varian 4: WPA1 saja\n");
		break;
	case 5:
	default:
		/*
		 * WPA2 + CCMP + PSK + SHA256-PSK (AKM 6). Sebagian AP
		 * WPA3-transition hanya menerima AKM ini.
		 * Sengaja TIDAK memakai assoc tanpa RSN: itu bisa membuat
		 * macOS tampak terhubung tanpa enkripsi dan menyesatkan.
		 */
		ic->ic_flags |= IEEE80211_F_RSNON;
		ic->ic_rsnprotos = IEEE80211_PROTO_RSN;
		ic->ic_rsnciphers = IEEE80211_CIPHER_CCMP;
		ic->ic_rsngroupcipher = IEEE80211_CIPHER_CCMP;
		ic->ic_rsnakms = IEEE80211_AKM_PSK |
		    IEEE80211_AKM_SHA256_PSK;
		IOLog(LOGP "rsn-varian 5: WPA2 CCMP PSK+SHA256\n");
		break;
	}
}

/*
 * Setara rtwn_updateslot() + bagian INIRTS_RATE_SEL di rtwn_newstate()
 * (OpenBSD sys/dev/ic/rtwn.c).
 *
 * R92C_SLOT tidak pernah ditulis di port ini. Nilai bawaan chip belum
 * tentu cocok dengan AP: AP yang mengiklankan short slot (capability
 * bit 10, seperti ZEKRI.NET dengan cap=0x0431) memakai 9 us, sedangkan
 * long slot 20 us. Slot time menentukan DIFS dan backoff — kalau client
 * dan AP berbeda, frame dikirim pada jendela yang salah dan bertabrakan,
 * sehingga assoc request bisa hilang tanpa pernah sampai ke AP.
 */
void ItlRtl8188E::updateSlot(struct ieee80211com *ic)
{
	uint8_t slot = (ic->ic_flags & IEEE80211_F_SHSLOT) ?
	    IEEE80211_DUR_DS_SHSLOT : IEEE80211_DUR_DS_SLOT;
	uint8_t irts = (ic->ic_curmode == IEEE80211_MODE_11B) ? 0 : 3;

	halWrite(this, R92C_SLOT, &slot, 1);
	halWrite(this, R92C_INIRTS_RATE_SEL, &irts, 1);
	IOLog(LOGP "slot=%u us shslot=%d irts=%u\n", slot,
	    (ic->ic_flags & IEEE80211_F_SHSLOT) ? 1 : 0, irts);
}

int ItlRtl8188E::newstateCb(struct ieee80211com *ic,
    enum ieee80211_state nstate, int arg)
{
	ItlRtl8188E *me = (ItlRtl8188E *)ic->ic_softc;
	int error;

	if (!me)
		return EINVAL;

	switch (nstate) {
	case IEEE80211_S_INIT:
		me->setDiag("RTL8188E-stage", "state-init");
		break;
	case IEEE80211_S_AUTH:
		me->setDiag("RTL8188E-stage", "state-auth");
		break;
	case IEEE80211_S_ASSOC:
		me->setDiag("RTL8188E-stage", "state-assoc");
		break;
	case IEEE80211_S_RUN:
		me->setDiag("RTL8188E-stage", "state-run");
		break;
	default:
		break;
	}

	switch (nstate) {
	case IEEE80211_S_SCAN: {
		int dwell = 30;

		me->fScanning = true;
		if (ic->ic_bss && ic->ic_bss->ni_chan)
			me->setChannel(ic->ic_bss->ni_chan);
		if (ic->ic_flags & IEEE80211_F_ASCAN) {
			dwell = 30;
		} else {
			dwell = 50;
		}
		timeout_add_msec(&me->fScanTo, dwell);
		break;
	}
	case IEEE80211_S_AUTH:
	case IEEE80211_S_ASSOC:
	case IEEE80211_S_RUN: {
		me->fScanning = false;
		me->fScanSeen = false;
		if (me->fScanTo)
			timeout_del(&me->fScanTo);
		/*
		 * Setiap kali masuk AUTH adalah percobaan join baru
		 * (net80211 kembali ke SCAN dulu setelah gagal). Pakai
		 * kesempatan itu untuk mengganti varian RSN — satu boot
		 * mencoba beberapa kombinasi tanpa reboot.
		 */
		if (nstate == IEEE80211_S_AUTH) {
			/*
			 * Percobaan ulang: beritahu AP dulu bahwa sesi
			 * lama berakhir. Tanpa deauth, AP menyimpan
			 * state "authenticated" untuk MAC kita dan
			 * mengabaikan assoc request berikutnya (AP hanya
			 * membalas deauth reason 2, assoc response tidak
			 * pernah datang).
			 */
			if (me->fJoinTry > 0 && ic->ic_bss &&
			    ic->ic_bss->ni_bssid[0] != 0) {
				IEEE80211_SEND_MGMT(ic, ic->ic_bss,
				    IEEE80211_FC0_SUBTYPE_DEAUTH,
				    IEEE80211_REASON_AUTH_LEAVE);
				IOLog(LOGP "deauth sebelum retry #%u\n",
				    (unsigned)me->fJoinTry);
			}
			me->fJoinTry++;
			me->updateSlot(ic);
			me->applyRsnVariant(me->fJoinTry);
			me->publishStats();
		}
		if (ic->ic_bss) {
			struct ieee80211_node *ni = ic->ic_bss;
			if (ni->ni_chan)
				me->setChannel(ni->ni_chan);
			uint32_t b0 = (uint32_t)ni->ni_bssid[0] |
			    ((uint32_t)ni->ni_bssid[1] << 8) |
			    ((uint32_t)ni->ni_bssid[2] << 16) |
			    ((uint32_t)ni->ni_bssid[3] << 24);
			uint16_t b4 = (uint16_t)ni->ni_bssid[4] |
			    ((uint16_t)ni->ni_bssid[5] << 8);
			halWrite(me, R92C_BSSID + 0, &b0, 4);
			halWrite(me, R92C_BSSID + 4, &b4, 2);
		}
		for (int i = 0; i < IEEE80211_ADDR_LEN; i++) {
			uint8_t b = ic->ic_myaddr[i];
			halWrite(me, R92C_MACID + i, &b, 1);
		}
		if (nstate == IEEE80211_S_RUN) {
			uint8_t msr = R92C_MSR_NETTYPE_INFRA;
			me->updateSlot(ic);
			halWrite(me, R92C_MSR, &msr, 1);
			uint16_t flt2 = 0xffff;
			halWrite(me, R92C_RXFLTMAP2, &flt2, 2);
			uint8_t txpause = 0x00;
			halWrite(me, R92C_TXPAUSE, &txpause, 1);
			if (ic->ic_bss) {
				uint16_t bcn_int = ic->ic_bss->ni_intval ? ic->ic_bss->ni_intval : 100;
				halWrite(me, R92C_BCN_INTERVAL, &bcn_int, 2);
			}
		}
		break;
	}
	case IEEE80211_S_INIT:
		me->fScanning = false;
		me->fScanSeen = false;
		if (me->fScanTo)
			timeout_del(&me->fScanTo);
		/*
		 * Tinggalkan AP dengan rapi. Tanpa ini AP tetap
		 * menganggap kita terasosiasi; join berikutnya (bahkan
		 * setelah reboot) bisa diabaikan AP.
		 */
		if (ic->ic_bss && ic->ic_bss->ni_bssid[0] != 0)
			IEEE80211_SEND_MGMT(ic, ic->ic_bss,
			    IEEE80211_FC0_SUBTYPE_DEAUTH,
			    IEEE80211_REASON_AUTH_LEAVE);
		break;
	default:
		break;
	}

	error = me->fOrigNewstate ? me->fOrigNewstate(ic, nstate, arg) : 0;
	return error;
}

void ItlRtl8188E::scanTimeoutCb(void *arg)
{
	ItlRtl8188E *me = (ItlRtl8188E *)arg;

	if (me->fIc.ic_state == IEEE80211_S_SCAN)
		ieee80211_next_scan(&me->fIc.ic_if);
}

/*
 * Frontend memanggil (*ifp->if_watchdog)(ifp) tiap 1 detik. Tanpa
 * pointer ini, watchdogAction() langsung memanggil NULL → panic.
 * TX kita tidak punya antrean yang bisa macet, jadi cukup bersihkan
 * if_timer.
 */
void ItlRtl8188E::watchdogCb(struct _ifnet *ifp)
{
	ItlRtl8188E *me = ifp ? (ItlRtl8188E *)ifp->if_softc : nullptr;

	/*
	 * Bukan sekadar membersihkan if_timer: net80211 memakai watchdog
	 * ini untuk retry auth/assoc dan memaksa scan ulang kalau AP diam.
	 * Tanpa ini state machine bisa tertahan di AUTH/ASSOC selamanya.
	 */
	if (ifp)
		ieee80211_watchdog(ifp);

	/* Satu kali per detik: publikasikan penghitung ke ioreg. */
	if (me)
		me->publishStats();
}

/* ------------------------------------------------------------------ */
/*  TX                                                                 */
/* ------------------------------------------------------------------ */

void ItlRtl8188E::txStartCb(struct _ifnet *ifp)
{
	ItlRtl8188E *me = (ItlRtl8188E *)ifp->if_softc;
	if (me)
		me->txStart(ifp);
}

void ItlRtl8188E::sendFrame(mbuf_t m, struct ieee80211_node *ni, bool isMgmt)
{
	uint8_t *wh;
	uint32_t len, pktlen;
	bool bcast;
	uint8_t raid;
	uint8_t *buf;
	size_t total;

	if (!m)
		return;

	/*
	 * Semua frame (mgmt maupun data) datang dengan referensi node
	 * yang harus dilepas driver. Jangan bocorkan saat bulk belum siap.
	 */
	if (!fBulkReady) {
		mbuf_freem(m);
		if (ni)
			ieee80211_release_node(&fIc, ni);
		return;
	}

	wh = (uint8_t *)mbuf_data(m);
	if (!wh) {
		mbuf_freem(m);
		if (ni)
			ieee80211_release_node(&fIc, ni);
		return;
	}

	/* Frame panjang (mis. CCMP) → pastikan kontigu. */
	len = mbuf_pkthdr_len(m);
	if (mbuf_len(m) < len) {
		/*
		 * mbuf_pullup() MEMBEBASKAN seluruh chain kalau gagal —
		 * jangan panggil mbuf_freem() lagi di sini (double free).
		 */
		if (mbuf_pullup(&m, len) != 0) {
			if (ni)
				ieee80211_release_node(&fIc, ni);
			return;
		}
		wh = (uint8_t *)mbuf_data(m);
	}

	if (len < sizeof(struct ieee80211_frame)) {
		mbuf_freem(m);
		if (ni)
			ieee80211_release_node(&fIc, ni);
		return;
	}

	/*
	 * Kripto software: 8188E tidak memakai offload CCMP di jalur ini.
	 * net80211 yang menambah header CCMP + MIC.
	 */
	if (!isMgmt && (wh[1] & IEEE80211_FC1_PROTECTED)) {
		struct ieee80211_key *k = ieee80211_get_txkey(&fIc,
		    (struct ieee80211_frame *)wh, ni);
		if (!k) {
			/* Frame terproteksi tanpa key jangan dikirim polos. */
			mbuf_freem(m);
			if (ni)
				ieee80211_release_node(&fIc, ni);
			return;
		}
		if (k) {
			mbuf_t enc = ieee80211_encrypt(&fIc, m, k);
			if (!enc) {
				/*
				 * ieee80211_encrypt() sudah membebaskan m
				 * (baik sukses maupun gagal). Jangan free lagi.
				 */
				fEncryptFail++;
				if (ni)
					ieee80211_release_node(&fIc, ni);
				return;
			}
			m = enc;
			wh = (uint8_t *)mbuf_data(m);
			len = mbuf_pkthdr_len(m);
		}
	}

	if (!isMgmt) {
		size_t llcOff = (wh[0] & IEEE80211_FC0_SUBTYPE_QOS) ? 26 : 24;
		if (len >= llcOff + 8) {
			uint16_t et = ((uint16_t)wh[llcOff + 6] << 8) | wh[llcOff + 7];
			if (et == 0x888e) {
				fTxEapol++;
				IOLog(LOGP "TX EAPOL handshake frame (len %u)\n", (unsigned)len);
			}
		}
	}

	bcast = IEEE80211_IS_MULTICAST(wh + 4);
	raid = 6;	/* RAID 11B — terbukti di M2 */

	/*
	 * Hitung per-subtype. Tanpa ini "auth tidak dikirim" dan
	 * "auth dikirim tapi AP diam" terlihat sama di statistik.
	 */
	if (isMgmt) {
		uint8_t sub = wh[0] & IEEE80211_FC0_SUBTYPE_MASK;

		if (sub == IEEE80211_FC0_SUBTYPE_AUTH) {
			fTxAuthReq++;
		} else if (sub == IEEE80211_FC0_SUBTYPE_ASSOC_REQ ||
		    sub == IEEE80211_FC0_SUBTYPE_REASSOC_REQ) {
			fTxAssocReq++;
			/*
			 * Ringkas: header + capability + awal SSID/RSN.
			 * snprintf per-byte di kernel tidak andal untuk
			 * buffer panjang, jadi pakai dword.
			 */
			if (len >= 24) {
				const uint32_t *dw = (const uint32_t *)wh;

				IOLog(LOGP "TX assoc len=%u fc=%02x%02x "
				    "dw1=%08x dw2=%08x dw3=%08x "
				    "dw4=%08x dw5=%08x\n",
				    (unsigned)len, wh[0], wh[1],
				    dw[1], dw[2], dw[3], dw[4], dw[5]);
			}
			/*
			 * Body: dw6 = capability+listen, dw7.. = IE.
			 * AP diam tanpa assoc response berarti body yang
			 * dibuang — capability atau RSN IE salah.
			 */
			if (len >= 56) {
				const uint32_t *dw = (const uint32_t *)wh;

				IOLog(LOGP "TX assoc body cap=%04x li=%u "
				    "dw7=%08x dw8=%08x dw9=%08x "
				    "dw10=%08x dw11=%08x dw12=%08x\n",
				    (unsigned)(wh[24] | (wh[25] << 8)),
				    (unsigned)(wh[26] | (wh[27] << 8)),
				    dw[7], dw[8], dw[9], dw[10], dw[11],
				    dw[12]);
			}
		}
	}

	/*
	 * Pilih queue TX (dan bulk-out pipe) sesuai access category.
	 *
	 * 8188EU memetakan endpoint USB ke queue hardware: 0 = VO/mgmt,
	 * 1 = VI, 2 = BE/BK. Sebelumnya semua frame — termasuk data —
	 * dikirim lewat pipe 0 dengan QSEL=BE. Chip memasukkannya ke queue
	 * mgmt, sehingga frame data tidak pernah keluar dan DHCP selalu
	 * "no server". Ini yang diperbaiki di sini.
	 */
	{
		uint8_t qsel = 0x00;	/* BE */
		int pipe = 2;

		if (isMgmt) {
			qsel = 0x12;	/* MGNT */
			pipe = 0;
		} else if (wh[0] & IEEE80211_FC0_SUBTYPE_QOS) {
			uint8_t tid = wh[24] & 0x0f;

			if (tid >= 1 && tid <= 2) {
				qsel = 0x02;	/* BK */
				pipe = 2;
			} else if (tid >= 4 && tid <= 5) {
				qsel = 0x05;	/* VI */
				pipe = 1;
			} else if (tid >= 6) {
				qsel = 0x07;	/* VO */
				pipe = 0;
			}
		}

		total = RTWN_USB_TX_DESC_SIZE + len;
		buf = (uint8_t *)IOMalloc(total);
		if (!buf) {
			mbuf_freem(m);
			if (ni)
				ieee80211_release_node(&fIc, ni);
			return;
		}

		if (isMgmt) {
			rtwn_usb_build_mgmt_tx_desc(buf, RTWN_USB_TX_DESC_SIZE,
			    (uint16_t)len, bcast);
		} else {
			bool qos = (wh[0] & IEEE80211_FC0_SUBTYPE_QOS) != 0;
			uint16_t seq = ((uint16_t)wh[22] |
			    ((uint16_t)wh[23] << 8)) >> IEEE80211_SEQ_SEQ_SHIFT;

			rtwn_usb_build_tx_desc(buf, RTWN_USB_TX_DESC_SIZE,
			    (uint16_t)len, RTWN_USB_TX_DESC_SIZE, bcast, true,
			    raid, false, false, 0);
			/* QSEL (txdw1 bit 8-12) harus sama dengan queue pipe. */
			buf[5] = (uint8_t)((buf[5] & 0xe0) | (qsel & 0x1f));
			/*
			 * Layout r92c_tx_desc_usb:
			 *   12 txdw3 (16 bit)  14 txdseq  16 txdw4  20 txdw5
			 * DRVRATE/HWSEQ ada di txdw4, BUKAN txdw3.
			 */
			if (qos) {
				buf[14] = (uint8_t)(seq & 0xff);
				buf[15] = (uint8_t)((seq >> 8) & 0xff);
				buf[16] = 0x40;	/* QOS */
				buf[17] = 0x01;	/* DRVRATE */
			} else {
				buf[14] = 0x00;
				buf[15] = 0x80;	/* txdseq: HWSEQEN */
				buf[16] = 0x80;	/* HWSEQ */
				buf[17] = 0x01;	/* DRVRATE */
			}
			buf[18] = 0x00;
			buf[19] = 0x00;
			/*
			 * txdw5: DATARATE=0 (CCK 1 Mb/s) + batas retry.
			 * Tanpa batas retry (0x0001ff00 seperti urtwn), frame
			 * yang sekali bertabrakan langsung dibuang — cukup
			 * untuk membuat handshake WPA2 gagal di band 2,4 GHz.
			 */
			buf[20] = 0x00;
			buf[21] = 0xff;
			buf[22] = 0x01;
			buf[23] = 0x00;
			/*
			 * CCX_RPT AKTIF: laporan TX (C2H) memberi tahu apakah
			 * frame benar-benar di-ACK AP (R88E_RPTB1_PKT_OK) dan
			 * berapa kali retry. Tanpa ini kita buta: "sudah kirim"
			 * dan "sampai ke AP" tidak bisa dibedakan.
			 */
			/* (bit CCX_RPT dibiarkan menyala dari builder) */
			rtwn_usb_tx_checksum(buf, RTWN_USB_TX_DESC_SIZE);
		}

		pktlen = len;
		if (mbuf_copydata(m, 0, pktlen, buf + RTWN_USB_TX_DESC_SIZE) != 0) {
			IOFree(buf, total);
			mbuf_freem(m);
			if (ni)
				ieee80211_release_node(&fIc, ni);
			return;
		}

		if (!fChip.usb.bulkSend(buf, (uint32_t)total, nullptr, nullptr,
		    pipe)) {
			IOLog(LOGP "bulkSend gagal (%u byte, pipe %d)\n",
			    (unsigned)total, pipe);
			fTxFail++;
		} else if (isMgmt) {
			fTxMgmt++;
		} else {
			fTxData++;
		}

		IOFree(buf, total);
		mbuf_freem(m);

		/* net80211 menyerahkan referensi node ke driver. */
		if (ni)
			ieee80211_release_node(&fIc, ni);
		return;
	}
}

void ItlRtl8188E::txStart(struct _ifnet *ifp)
{
	struct ieee80211com *ic = &fIc;
	struct ieee80211_node *ni;
	mbuf_t m;

	while ((m = mq_dequeue(&ic->ic_mgtq)) != nullptr) {
		ni = (struct ieee80211_node *)mbuf_pkthdr_rcvif(m);
		sendFrame(m, ni, true);
	}

	if ((ic->ic_state != IEEE80211_S_RUN && ic->ic_state != IEEE80211_S_ASSOC) ||
	    (ic->ic_xflags & IEEE80211_F_TX_MGMT_ONLY))
		return;

	while ((m = ifq_dequeue(&ifp->if_snd)) != nullptr) {
		ni = nullptr;
		m = ieee80211_encap(ifp, m, &ni);
		if (!m) {
			if (ifp->netStat)
				ifp->netStat->outputErrors++;
			continue;
		}
		sendFrame(m, ni, false);
	}
}

/* ------------------------------------------------------------------ */
/*  RX                                                                 */
/* ------------------------------------------------------------------ */

void ItlRtl8188E::rxCb(void *ctx, const uint8_t *data, uint32_t len)
{
	ItlRtl8188E *me = (ItlRtl8188E *)ctx;
	uint8_t *copy;
	uint32_t idx;

	if (!me || !me->fRxRunning || !me->fRxTimer || !me->fRxLock ||
	    !data || len == 0)
		return;

	/*
	 * Salin sekarang: buffer transfer akan segera di-queue ulang oleh
	 * usb_compat. Jangan memproses net80211 di thread completion USB —
	 * workloop USB bisa deadlock dengan control transfer di workloop
	 * IO80211. Cukup titip ke antrean lalu bangunkan timer 0 ms.
	 */
	copy = (uint8_t *)IOMalloc(len);
	if (!copy)
		return;
	memcpy(copy, data, len);

	IOLockLock(me->fRxLock);
	if (me->fRxCount >= kRxQueueDepth) {
		IOLockUnlock(me->fRxLock);
		IOFree(copy, len);
		return;
	}
	idx = (me->fRxHead + me->fRxCount) % kRxQueueDepth;
	me->fRxBuf[idx] = copy;
	me->fRxLen[idx] = len;
	me->fRxCount++;
	IOLockUnlock(me->fRxLock);

	me->fRxTimer->setTimeoutMS(0);
}

void ItlRtl8188E::rxTimerAction(IOTimerEventSource *timer)
{
	uint8_t *bufs[8];
	uint32_t lens[8];

	(void)timer;

	for (;;) {
		uint32_t n = 0, i;

		IOLockLock(fRxLock);
		while (fRxCount > 0 && n < 8) {
			bufs[n] = fRxBuf[fRxHead];
			lens[n] = fRxLen[fRxHead];
			fRxBuf[fRxHead] = nullptr;
			fRxLen[fRxHead] = 0;
			fRxHead = (fRxHead + 1) % kRxQueueDepth;
			fRxCount--;
			n++;
		}
		IOLockUnlock(fRxLock);

		if (n == 0)
			break;

		for (i = 0; i < n; i++) {
			if (fRxRunning)
				handleRx(bufs[i], lens[i]);
			IOFree(bufs[i], lens[i]);
		}
	}
}

void ItlRtl8188E::rxQueueFree(void)
{
	uint8_t *bufs[kRxQueueDepth];
	uint32_t lens[kRxQueueDepth];
	uint32_t n = 0, i;

	if (!fRxLock)
		return;

	IOLockLock(fRxLock);
	while (fRxCount > 0) {
		bufs[n] = fRxBuf[fRxHead];
		lens[n] = fRxLen[fRxHead];
		fRxBuf[fRxHead] = nullptr;
		fRxLen[fRxHead] = 0;
		fRxHead = (fRxHead + 1) % kRxQueueDepth;
		fRxCount--;
		n++;
	}
	IOLockUnlock(fRxLock);

	for (i = 0; i < n; i++)
		IOFree(bufs[i], lens[i]);
}

static inline uint32_t
rxDescDw(const uint8_t *buf, uint32_t off, int dw)
{
	const uint8_t *p = buf + off + dw * 4;
	return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
	    ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

/*
 * Validasi satu slot RX: descriptor masuk akal + frame 802.11 di posisi
 * canonical (24 + infosz). Dipakai untuk memilih stride 128 vs 4 byte.
 */
static bool
rxSlotOk(const uint8_t *buf, uint32_t len, uint32_t off)
{
	rtwn_usb_rxinfo_t info;
	const struct ieee80211_frame *wh;
	uint32_t foff;
	uint8_t type;

	if (off + RTWN_USB_RX_DESC_SIZE + RTWN_USB_RX_EXTRA_SIZE > len)
		return false;
	if (!rtwn_usb_parse_rx_desc(buf + off, len - off, &info))
		return false;
	if (info.pktlen == 0 || info.pktlen > 2048)
		return false;
	foff = off + RTWN_USB_RX_DESC_SIZE + info.infosz + info.shift;
	if (foff + info.pktlen > len ||
	    info.pktlen < sizeof(struct ieee80211_frame))
		return false;
	wh = (const struct ieee80211_frame *)(buf + foff);
	if ((wh->i_fc[0] & IEEE80211_FC0_VERSION_MASK) !=
	    IEEE80211_FC0_VERSION_0)
		return false;
	type = wh->i_fc[0] & IEEE80211_FC0_TYPE_MASK;
	return type == IEEE80211_FC0_TYPE_MGT ||
	    type == IEEE80211_FC0_TYPE_DATA ||
	    type == IEEE80211_FC0_TYPE_CTL;
}

void ItlRtl8188E::handleRx(const uint8_t *buf, uint32_t len)
{
	struct _ifnet *ifp = &fIc.ic_if;
	struct mbuf_list ml = MBUF_LIST_INITIALIZER();
	uint32_t off = 0;
	uint32_t npkts = 0;
	uint32_t slot = 0;

	while (off + RTWN_USB_RX_DESC_SIZE + RTWN_USB_RX_EXTRA_SIZE <= len &&
	    (npkts == 0 || slot < npkts)) {
		rtwn_usb_rxinfo_t info;
		uint32_t flen, foff, dw2, dw3, s4, s128, next;
		struct ieee80211_frame *wh;
		struct ieee80211_node *ni;
		struct ieee80211_rxinfo rxi;
		mbuf_t m;
		int8_t rssi = -95;
		bool txReport;

		if (!rtwn_usb_parse_rx_desc(buf + off, len - off, &info))
			break;

		flen = info.pktlen;
		if (flen == 0 || flen > 2048)
			break;

		dw2 = rxDescDw(buf, off, 2);
		dw3 = rxDescDw(buf, off, 3);

		if (npkts == 0) {
			/* Jumlah frame dalam satu transfer USB (RXDW2 bit 16-23). */
			npkts = (dw2 >> 16) & 0xff;
			if (npkts == 0)
				npkts = 1;
			if (npkts > 64)
				npkts = 64;
		}
		slot++;

		foff = off + RTWN_USB_RX_DESC_SIZE + info.infosz + info.shift;
		if (foff + flen > len)
			break;

		/*
		 * RTL8188E memakai RXDW3 bit 14-15 untuk jenis report.
		 * TX report bukan frame 802.11. Jangan memakai RXDW2 bit 28:
		 * itu field C2H milik 92E, tidak dipakai 88E (OpenBSD hanya
		 * memeriksa RXDW3 untuk chip ini).
		 */
		txReport = ((dw3 >> 14) & 0x3) != 0;

		if (info.crcError || info.icvError) {
			/*
			 * Frame korup dibuang (sama seperti OpenBSD). Tapi
			 * kalau yang dibuang justru assoc response, kita
			 * buta. Catat fc + panjang supaya kelihatan.
			 */
			if (foff + 2 <= len) {
				IOLog(LOGP "RX crc-err fc=%02x%02x len=%u\n",
				    buf[foff], buf[foff + 1],
				    (unsigned)flen);
			}
			txReport = true;
		}

		/*
		 * Laporan TX (r88e_tx_rpt_ccx) menempel langsung setelah
		 * descriptor 24 byte — tanpa PHY status.
		 *   rptb1 bit6   = PKT_OK (frame di-ACK AP)
		 *   rptb2 bit0-5 = jumlah retry, bit7 = retry habis
		 */
		if (txReport && off + RTWN_USB_RX_DESC_SIZE + 4 <= len) {
			const uint8_t *rpt = buf + off + RTWN_USB_RX_DESC_SIZE;

			fTxReport++;
			if (rpt[1] & 0x40) {
				fTxOk++;
			}
			if (rpt[2] & 0x3f) {
				fTxRetry++;
			}
		}

		/*
		 * Stride: OpenBSD memakai 128-byte alignment untuk 88E,
		 * sedangkan pengamatan M2 (npkts=1) tidak membedakan.
		 * Pilih kandidat yang benar-benar berisi descriptor +
		 * frame valid supaya tidak salah saat npkts > 1.
		 */
		s4 = (RTWN_USB_RX_DESC_SIZE + info.infosz + info.shift + flen + 3) & ~3u;
		s128 = (RTWN_USB_RX_DESC_SIZE + info.infosz + info.shift + flen + 127) &
		    ~127u;
		next = off + s4;
		if (slot < npkts) {
			if (rxSlotOk(buf, len, off + s128))
				next = off + s128;
			else if (!rxSlotOk(buf, len, off + s4))
				next = 0;
		}

		if (!txReport) {
			if (flen < sizeof(struct ieee80211_frame))
				goto advance;
			wh = (struct ieee80211_frame *)(buf + foff);
			if (!fSawRx) {
				const char *kind = "data";

				fSawRx = true;
				switch (wh->i_fc[0] & IEEE80211_FC0_TYPE_MASK) {
				case IEEE80211_FC0_TYPE_MGT:
					kind = ((wh->i_fc[0] & IEEE80211_FC0_SUBTYPE_MASK) ==
					    IEEE80211_FC0_SUBTYPE_BEACON) ?
					    "beacon" : "mgmt";
					break;
				case IEEE80211_FC0_TYPE_CTL:
					kind = "ctrl";
					break;
				default:
					break;
				}
				setDiag("RTL8188E-first-rx", kind);
			}
			if ((wh->i_fc[0] & IEEE80211_FC0_VERSION_MASK) !=
			    IEEE80211_FC0_VERSION_0)
				goto advance;

			if ((wh->i_fc[0] & IEEE80211_FC0_TYPE_MASK) == IEEE80211_FC0_TYPE_DATA) {
				size_t llcOff = (wh->i_fc[0] & IEEE80211_FC0_SUBTYPE_QOS) ? 26 : 24;

				fRxData++;
				/*
				 * Sampel 3 frame data pertama: apakah bit
				 * Protected menyala (frame terenkripsi dari
				 * udara) dan berapa panjangnya. Kalau bit
				 * ini tidak menyala padahal RSN aktif,
				 * net80211 akan membuang frame.
				 */
				if (fRxDataLogged < 3) {
					fRxDataLogged++;
					IOLog(LOGP "RX data fc=%02x%02x len=%u "
					    "prot=%d qos=%d\n",
					    wh->i_fc[0], wh->i_fc[1],
					    (unsigned)flen,
					    (wh->i_fc[1] &
					    IEEE80211_FC1_PROTECTED) ? 1 : 0,
					    (wh->i_fc[0] &
					    IEEE80211_FC0_SUBTYPE_QOS) ? 1 : 0);
				}
				if (flen >= llcOff + 8) {
					const uint8_t *p = buf + foff + llcOff;
					uint16_t et = ((uint16_t)p[6] << 8) | p[7];
					if (et == 0x888e) {
						fRxEapol++;
						IOLog(LOGP "RX EAPOL handshake frame (len %u)\n", (unsigned)flen);
					}
				}
			} else if ((wh->i_fc[0] & IEEE80211_FC0_TYPE_MASK) ==
			    IEEE80211_FC0_TYPE_MGT) {
				uint8_t sub = wh->i_fc[0] &
				    IEEE80211_FC0_SUBTYPE_MASK;

				fRxMgmt++;
				if (sub == IEEE80211_FC0_SUBTYPE_AUTH) {
					fRxAuth++;
					IOLog(LOGP "RX auth resp (len %u, seq %u)\n",
					    (unsigned)flen,
					    (unsigned)(((uint16_t)wh->i_seq[0] |
					    ((uint16_t)wh->i_seq[1] << 8)) >>
					    IEEE80211_SEQ_SEQ_SHIFT));
				} else if (sub ==
				    IEEE80211_FC0_SUBTYPE_ASSOC_RESP) {
					fRxAssocResp++;
					IOLog(LOGP "RX assoc resp (len %u)\n",
					    (unsigned)flen);
				} else if (sub != IEEE80211_FC0_SUBTYPE_BEACON &&
				    sub != IEEE80211_FC0_SUBTYPE_PROBE_RESP) {
					/*
					 * Selain beacon/probe-resp: deauth,
					 * disassoc, action. Berguna untuk
					 * melihat AP bereaksi atau tidak.
					 */
					IOLog(LOGP "RX mgmt sub=%02x len=%u\n",
					    sub, (unsigned)flen);
				}
			}

			/* RSSI dari PHY status (rtwn_r88e_get_rssi). */
			if (info.infosz > 0 && info.hasPhyStatus) {
				const uint8_t *phy = buf + foff - info.infosz;

				if (info.rate <= 3) {
					static const int8_t cckoff[] =
					    { 20, 14, 10, -4, -16, -22, -38, -40 };
					uint8_t agc = phy[5];
					uint8_t rpt = (agc >> 5) & 0x7;

					rssi = ((agc & 0x1f) > 27) ? -94 :
					    (int8_t)(cckoff[rpt] -
					    ((agc & 0x1f) << 1));
				} else {
					uint32_t sq = (uint32_t)phy[4] |
					    ((uint32_t)phy[5] << 8) |
					    ((uint32_t)phy[6] << 16) |
					    ((uint32_t)phy[7] << 24);

					rssi = (int8_t)(((sq >> 1) & 0x7f) - 110);
				}
			}

			m = getController() ?
			    getController()->allocatePacket(flen) : nullptr;
			if (m) {
				if (mbuf_copyback(m, 0, flen, buf + foff,
				    MBUF_WAITOK) == 0) {
					/*
					 * Dalam STA mode semua frame data
					 * datang dari/via AP, jadi node-nya
					 * ic_bss — satu-satunya node yang
					 * memegang PTK/GTK hasil handshake.
					 * find_rxnode() bisa mengembalikan
					 * node lain tanpa key, dan net80211
					 * lalu membuang frame karena gagal
					 * dekripsi.
					 */
					if (fIc.ic_state ==
					    IEEE80211_S_RUN && fIc.ic_bss) {
						ni = ieee80211_ref_node(
						    fIc.ic_bss);
					} else {
						ni = ieee80211_find_rxnode(
						    &fIc, wh);
					}
					memset(&rxi, 0, sizeof(rxi));
					/*
					 * Port net80211 ini memakai RSSI ternormalisasi
					 * 0..ic_max_rssi (bukan dBm), sama seperti iwm:
					 * frontend menghitung asr_rssi = rssi - 100.
					 * rxi/ni_rssi bertipe u8; dBm negatif akan wrap.
					 */
					{
						int norm = (int)rssi + 100;

						if (norm < 0)
							norm = 0;
						if (norm > fIc.ic_max_rssi)
							norm = fIc.ic_max_rssi;
						rxi.rxi_rssi = norm;
					}
					ieee80211_inputm(ifp, m, ni, &rxi,
					    &ml);
					ieee80211_release_node(&fIc, ni);
				} else {
					mbuf_freem(m);
				}
			}
		}

advance:
		if (next == 0 || next <= off)
			break;
		off = next;
	}

	if (ml.ml_len > 0)
		fRxDelivered += ml.ml_len;
	if_input(ifp, &ml);
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
	return -95;
}

bool ItlRtl8188E::is5GBandSupport(void)
{
	return false;
}

int ItlRtl8188E::getTxNSS(void)
{
	return 1;
}

const char *ItlRtl8188E::getFirmwareName(void)
{
	return "rtl8188eufw.bin";
}

UInt32 ItlRtl8188E::supportedFeatures(void)
{
	return 0;
}

const char *ItlRtl8188E::getFirmwareCountryCode(void)
{
	return fCountryCode[0] ? fCountryCode : "ID";
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
	(void)addr;
	(void)count;
	return kIOReturnSuccess;
}

/* ------------------------------------------------------------------ */
/*  internal                                                           */
/* ------------------------------------------------------------------ */

void ItlRtl8188E::setMacAddress(const uint8_t *mac)
{
	if (mac)
		memcpy(fChip.macaddr, mac, 6);
}

void ItlRtl8188E::setFirmwareVersion(const char *ver)
{
	if (ver)
		strlcpy(fFirmwareVersion, ver, sizeof(fFirmwareVersion));
}

void ItlRtl8188E::setCountryCode(const char *cc)
{
	if (cc)
		strlcpy(fCountryCode, cc, sizeof(fCountryCode));
}
