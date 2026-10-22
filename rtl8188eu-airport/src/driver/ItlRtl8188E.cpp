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

	if (fChip.usb.attach(getController(), fDevice, fInterface) != 0) {
		IOLog(LOGP "usb attach gagal\n");
		return false;
	}
	fAttached = true;

	if (initChip() != 0) {
		IOLog(LOGP "init chip gagal\n");
		stopChip();
		return false;
	}

	if (!fChip.usb.bulkOpen(fInterface)) {
		IOLog(LOGP "bulkOpen gagal\n");
		stopChip();
		return false;
	}

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
	for (uint32_t ch = 1; ch <= 13; ch++) {
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
	fEnabled = false;
}

IOReturn ItlRtl8188E::enable(IONetworkInterface *interface)
{
	(void)interface;
	struct _ifnet *ifp = &fIc.ic_if;

	if (ifp->if_flags & IFF_UP)
		return kIOReturnSuccess;

	ifp->if_flags |= IFF_UP | IFF_RUNNING;
	fEnabled = true;
	fRxRunning = true;
	if (fIc.ic_state == IEEE80211_S_INIT)
		ieee80211_new_state(&fIc, IEEE80211_S_SCAN, -1);
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
	if (fScanTo)
		timeout_del(&fScanTo);
	if (fIc.ic_state != IEEE80211_S_INIT)
		ieee80211_new_state(&fIc, IEEE80211_S_INIT, -1);
	return kIOReturnSuccess;
}

struct ieee80211com *ItlRtl8188E::get80211Controller()
{
	return &fIc;
}

/* ------------------------------------------------------------------ */
/*  net80211 state machine                                             */
/* ------------------------------------------------------------------ */

void ItlRtl8188E::setChannel(struct ieee80211_channel *chan)
{
	if (!chan)
		return;
	uint8_t ch = (uint8_t)ieee80211_chan2ieee(&fIc, chan);
	if (ch >= 1 && ch <= 14) {
		if (rtwn_set_chan_8188e(halRead, halWrite, this, ch) != 0)
			IOLog(LOGP "set kanal %u gagal\n", ch);
	}
}

int ItlRtl8188E::newstateCb(struct ieee80211com *ic,
    enum ieee80211_state nstate, int arg)
{
	ItlRtl8188E *me = (ItlRtl8188E *)ic->ic_softc;
	int error;

	if (!me)
		return EINVAL;

	switch (nstate) {
	case IEEE80211_S_SCAN: {
		uint8_t ch;
		int dwell = 120;

		me->fScanning = true;
		me->setChannel(ic->ic_bss->ni_chan);
		ch = (uint8_t)ieee80211_chan2ieee(ic, ic->ic_bss->ni_chan);
		if (ch >= 1 && ch <= 14) {
			/*
			 * Siklus scan tanpa asosiasi berputar terus. Beri
			 * jeda 800 ms di kanal 1 pada siklus kedua dst. agar
			 * TX probe tidak terus-menerus membebani bus USB
			 * (dongle ini pernah drop dari bus saat scan intens).
			 */
			if (ch == 1 && me->fScanSeen)
				dwell = 800;
			if (ch > 1)
				me->fScanSeen = true;
		}
		timeout_add_msec(&me->fScanTo, dwell);
		break;
	}
	case IEEE80211_S_AUTH:
		me->fScanning = false;
		if (me->fScanTo)
			timeout_del(&me->fScanTo);
		me->setChannel(ic->ic_bss->ni_chan);
		break;
	case IEEE80211_S_INIT:
		me->fScanning = false;
		if (me->fScanTo)
			timeout_del(&me->fScanTo);
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
	if (ifp)
		ifp->if_timer = 0;
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
		if (mbuf_pullup(&m, len) != 0) {
			mbuf_freem(m);
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
		if (k) {
			mbuf_t enc = ieee80211_encrypt(&fIc, m, k);
			if (!enc) {
				mbuf_freem(m);
				if (ni)
					ieee80211_release_node(&fIc, ni);
				return;
			}
			m = enc;
			wh = (uint8_t *)mbuf_data(m);
			len = mbuf_pkthdr_len(m);
		}
	}

	bcast = IEEE80211_IS_MULTICAST(wh + 4);
	raid = 6;	/* RAID 11B — terbukti di M2 */

	total = RTWN_USB_TX_DESC_SIZE + len;
	buf = (uint8_t *)IOMalloc(total);
	if (!buf) {
		mbuf_freem(m);
		if (ni)
			ieee80211_release_node(&fIc, ni);
		return;
	}

	if (isMgmt) {
		rtwn_usb_build_mgmt_tx_desc(buf, RTWN_USB_TX_DESC_SIZE, (uint16_t)len,
		    bcast);
	} else {
		bool qos = (wh[0] & IEEE80211_FC0_SUBTYPE_QOS) != 0;

		rtwn_usb_build_tx_desc(buf, RTWN_USB_TX_DESC_SIZE, (uint16_t)len,
		    RTWN_USB_TX_DESC_SIZE, bcast, true, raid, false, false, 0);
		/* txdw3: paksa laju (DRVRATE), CCK 1 Mb/s. */
		buf[12] = 0x00;
		buf[13] = 0x01;
		if (qos) {
			/* QoS: seq/frag sudah diberikan net80211. */
			buf[14] = wh[22];
			buf[15] = wh[23];
		} else {
			/* Non-QoS: chip yang memberi nomor urut. */
			buf[14] = 0x00;
			buf[15] = 0x80;
		}
		/*
		 * CCX_RPT dimatikan: kita belum memproses laporan TX (C2H),
		 * dan laporan itu bisa disalahartikan sebagai frame 802.11.
		 * AGGBK tetap. */
		buf[10] &= (uint8_t)~0x08;
		/* txdw4: DATARATE=0 (1M), fallback 0x1f. */
		buf[16] = 0x00;
		buf[17] = 0x1f;
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

	if (!fChip.usb.bulkSend(buf, (uint32_t)total, nullptr, nullptr))
		IOLog(LOGP "bulkSend gagal (%u byte)\n", (unsigned)total);

	IOFree(buf, total);
	mbuf_freem(m);

	/* net80211 menyerahkan referensi node ke driver. */
	if (ni)
		ieee80211_release_node(&fIc, ni);
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

	if (ic->ic_state != IEEE80211_S_RUN)
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

void ItlRtl8188E::handleRx(const uint8_t *buf, uint32_t len)
{
	struct _ifnet *ifp = &fIc.ic_if;
	uint32_t off = 0;

	while (off + RTWN_USB_RX_DESC_SIZE + RTWN_USB_RX_EXTRA_SIZE <= len) {
		rtwn_usb_rxinfo_t info;
		uint32_t flen, foff;
		struct ieee80211_frame *wh;
		struct ieee80211_node *ni;
		struct ieee80211_rxinfo rxi;
		mbuf_t m;
		int8_t rssi = -95;

		uint32_t doff = off;

		if (!rtwn_usb_parse_rx_desc(buf + off, len - off, &info))
			break;

		/*
		 * dw2 bit 28 = R92E_RXDW2_RPT_C2H. Ini laporan/event firmware,
		 * bukan frame 802.11. Tanpa filter, isinya bisa masuk net80211
		 * sebagai frame sampah.
		 */
		{
			uint32_t dw2 = (uint32_t)buf[doff + 8] |
			    ((uint32_t)buf[doff + 9] << 8) |
			    ((uint32_t)buf[doff + 10] << 16) |
			    ((uint32_t)buf[doff + 11] << 24);
			if (dw2 & 0x10000000u) {
				uint32_t adv = RTWN_USB_RX_DESC_SIZE + info.infosz +
				    info.pktlen;
				off = (doff + adv + 3) & ~3u;
				if (adv == 0 || off <= doff)
					break;
				continue;
			}
		}

		flen = info.pktlen;
		if (flen == 0 || flen > 2048)
			break;

		/*
		 * Format 8188E (OpenBSD urtwn): descriptor 24 B + PHY status
		 * (infosz) + frame. Tidak ada padding +2 sebelum frame; M2
		 * memakai +2 hanya sebagai kandidat fallback.
		 */
		foff = off + RTWN_USB_RX_DESC_SIZE + info.infosz;
		if (foff + flen > len)
			break;

		/* Majukan offset lebih dulu untuk semua jalur di bawah. */
		off = (foff + flen + 3) & ~3u;

		if (info.crcError || info.icvError)
			continue;
		if (flen < sizeof(struct ieee80211_frame))
			continue;

		wh = (struct ieee80211_frame *)(buf + foff);
		if ((wh->i_fc[0] & IEEE80211_FC0_VERSION_MASK) !=
		    IEEE80211_FC0_VERSION_0)
			continue;

		/*
		 * RSSI dari PHY status, rumus rtwn_r88e_get_rssi().
		 * phy[4..7] = sq_rpt (LE32); phy[5] = agc_rpt.
		 */
		if (info.infosz > 0 && info.hasPhyStatus) {
			const uint8_t *phy = buf + foff - info.infosz;
			if (info.rate <= 3) {
				static const int8_t cckoff[] =
				    { 20, 14, 10, -4, -16, -22, -38, -40 };
				uint8_t agc = phy[5];
				uint8_t rpt = (agc >> 5) & 0x7;
				rssi = ((agc & 0x1f) > 27) ? -94 :
				    (int8_t)(cckoff[rpt] - ((agc & 0x1f) << 1));
			} else {
				uint32_t sq = (uint32_t)phy[4] |
				    ((uint32_t)phy[5] << 8) |
				    ((uint32_t)phy[6] << 16) |
				    ((uint32_t)phy[7] << 24);
				rssi = (int8_t)(((sq >> 1) & 0x7f) - 110);
			}
		}

		m = getController() ? getController()->allocatePacket(flen) : nullptr;
		if (!m)
			continue;

		if (mbuf_copyback(m, 0, flen, buf + foff, MBUF_WAITOK) != 0) {
			mbuf_freem(m);
			continue;
		}

		ni = ieee80211_find_rxnode(&fIc, wh);
		memset(&rxi, 0, sizeof(rxi));
		rxi.rxi_rssi = rssi;
		ieee80211_inputm(ifp, m, ni, &rxi, nullptr);
		ieee80211_release_node(&fIc, ni);
	}
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
