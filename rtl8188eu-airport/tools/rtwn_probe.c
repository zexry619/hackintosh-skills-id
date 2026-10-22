/*
 * rtwn-probe — lab RTL8188EUS (2357:010c) dari USER SPACE.
 *
 * Tanpa kernel, tanpa reboot, tanpa risiko panic. Memakai modul portabel
 * src/urtwn/rtwn_seq.c — kode yang PERSIS sama dengan driver kernel.
 *
 * Keuntungan: setiap eksperimen (EFUSE, power-on, firmware, HAL, kanal,
 * scan) bisa diulang dalam hitungan DETIK, bukan menit/reboot.
 *
 * Build:
 *   make probe          (atau lihat scripts/build-probe.sh)
 *
 * Pakai:
 *   sudo ./tools/rtwn_probe                     # info + baca register
 *   sudo ./tools/rtwn_probe --efuse-all         # semua jalur EFUSE + diag
 *   sudo ./tools/rtwn_probe --full              # power-on + LLT + firmware
 *   sudo ./tools/rtwn_probe --peek 0x610 6      # baca mentah
 *   sudo ./tools/rtwn_probe --poke 0x100 0xdeadbeef
 *   sudo ./tools/rtwn_probe --dump 0x000 0x40
 *
 * CATATAN: device harus TIDAK dipegang driver kernel. Kext kita self-detach
 * setelah init, jadi tunggu beberapa detik setelah dongle dicabut-colok.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#include <IOKit/usb/USB.h>
#include <CoreFoundation/CoreFoundation.h>

#include "rtwn_seq.h"

/* Firmware 8188E (dari linux-firmware), disematkan. */
extern const unsigned char rtl8188eufw_bin[];
extern const unsigned int rtl8188eufw_bin_len;

#define VID 0x2357
#define PID 0x010C
#define REQ_REGS 0x05

static IOUSBDeviceInterface **gDev = NULL;

static void diag_cb(void *ctx, const char *key, const char *val)
{
	(void)ctx;
	printf("      [diag] %-22s %s\n", key, val);
}

/* --- callback I/O untuk rtwn_seq --- */
static int probe_read(void *ctx, uint16_t addr, void *buf, uint16_t len)
{
	IOUSBDevRequest req;

	(void)ctx;
	if (gDev == NULL) {
		return -1;
	}
	memset(&req, 0, sizeof(req));
	req.bmRequestType = 0xC0;	/* IN | VENDOR | DEVICE */
	req.bRequest = REQ_REGS;
	req.wValue = addr;
	req.wIndex = 0;
	req.wLength = len;
	req.pData = buf;
	req.wLenDone = 0;

	if ((*gDev)->DeviceRequest(gDev, &req) != kIOReturnSuccess) {
		return -1;
	}
	if (req.wLenDone != len) {
		return -1;
	}
	return 0;
}

static int probe_write(void *ctx, uint16_t addr, const void *buf, uint16_t len)
{
	IOUSBDevRequest req;

	(void)ctx;
	if (gDev == NULL) {
		return -1;
	}
	memset(&req, 0, sizeof(req));
	req.bmRequestType = 0x40;	/* OUT | VENDOR | DEVICE */
	req.bRequest = REQ_REGS;
	req.wValue = addr;
	req.wIndex = 0;
	req.wLength = len;
	req.pData = (void *)buf;
	req.wLenDone = 0;

	if ((*gDev)->DeviceRequest(gDev, &req) != kIOReturnSuccess) {
		return -1;
	}
	return 0;
}

static void print_result(const rtwn_seq_result_t *r)
{
	printf("  step=%d chip=%d efuse=%d power=%d dma=%d fw=%d\n",
	    r->step, r->chip_ok, r->efuse_ok, r->power_ok, r->dma_ok, r->fw_ok);
	printf("  MAC      = %02x:%02x:%02x:%02x:%02x:%02x\n",
	    r->mac[0], r->mac[1], r->mac[2], r->mac[3], r->mac[4], r->mac[5]);
	printf("  xtal=0x%02x regulatory=%u channel_plan=%u\n",
	    r->xtal, r->regulatory, r->channel_plan);
	printf("  CR=0x%08x MCUFWDL=0x%08x SYS_CFG=0x%08x fwlen=%u\n",
	    r->cr, r->mcuwdl, r->syscfg, r->fwlen);
}

/* ── buka device dengan API yang BENAR ─────────────────────────────────
 *
 * Kode lama memakai IOServiceOpen() lalu me-cast koneksi menjadi
 * IOUSBDeviceInterface** — itu salah; hasilnya kIOReturnNotOpen (0xe00002c7).
 *
 * Yang benar: IOCreatePlugInInterfaceForService(kIOUSBDeviceUserClientTypeID)
 *   → QueryInterface(kIOUSBDeviceInterfaceID)
 *   → USBDeviceOpen()
 */
static int open_device(void)
{
	CFMutableDictionaryRef match;
	io_iterator_t iter = 0;
	io_service_t svc = 0;
	IOCFPlugInInterface **plug = NULL;
	SInt32 score = 0;
	IOReturn kr;
	int vidVal = VID, pidVal = PID;
	CFNumberRef vid, pid;
	UInt8 cfg = 0;

	match = IOServiceMatching("IOUSBDevice");
	vid = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &vidVal);
	pid = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &pidVal);
	CFDictionarySetValue(match, CFSTR("idVendor"), vid);
	CFDictionarySetValue(match, CFSTR("idProduct"), pid);
	CFRelease(vid);
	CFRelease(pid);

	if (IOServiceGetMatchingServices(kIOMainPortDefault, match, &iter) !=
	    KERN_SUCCESS) {
		printf("!! IOServiceGetMatchingServices gagal\n");
		return -1;
	}
	svc = IOIteratorNext(iter);
	IOObjectRelease(iter);
	if (!svc) {
		printf("!! Device 2357:010c tidak ditemukan (dongle tercabut?)\n");
		return -2;
	}

	kr = IOCreatePlugInInterfaceForService(svc, kIOUSBDeviceUserClientTypeID,
	    kIOCFPlugInInterfaceID, &plug, &score);
	if (kr != KERN_SUCCESS || plug == NULL) {
		printf("!! IOCreatePlugInInterfaceForService gagal: 0x%08x\n", kr);
		IOObjectRelease(svc);
		return -3;
	}

	kr = (*plug)->QueryInterface(plug,
	    CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID *)&gDev);
	(*plug)->Release(plug);
	IOObjectRelease(svc);
	if (kr != KERN_SUCCESS || gDev == NULL) {
		printf("!! QueryInterface(kIOUSBDeviceInterfaceID) gagal: 0x%08x\n",
		    kr);
		return -4;
	}

	kr = (*gDev)->USBDeviceOpen(gDev);
	if (kr != kIOReturnSuccess) {
		printf("  USBDeviceOpen: 0x%08x → coba USBDeviceOpenSeize...\n", kr);
		kr = (*gDev)->USBDeviceOpenSeize(gDev);
	}
	if (kr != kIOReturnSuccess) {
		printf("!! tidak bisa membuka device: 0x%08x\n", kr);
		if (kr == kIOReturnExclusiveAccess) {
			printf("   → masih dipegang driver kernel.\n");
			printf("     Kext kita self-detach; tunggu ~10 dtk lalu ulangi.\n");
			printf("     Jika tetap: sudo kextunload -b "
			    "io.github.zekri.RTL8188EUM1\n");
		}
		(*gDev)->Release(gDev);
		gDev = NULL;
		return -5;
	}
	(*gDev)->GetConfiguration(gDev, &cfg);
	printf("  device dibuka ✓ (config=%u)\n", cfg);
	if (cfg == 0) {
		kr = (*gDev)->SetConfiguration(gDev, 1);
		printf("  SetConfiguration(1) → 0x%08x\n", kr);
	}
	return 0;
}

static void close_device(void)
{
	if (gDev) {
		(*gDev)->USBDeviceClose(gDev);
		(*gDev)->Release(gDev);
		gDev = NULL;
	}
}

static uint32_t hexarg(const char *s)
{
	return (uint32_t)strtoul(s, NULL, 0);
}

int main(int argc, char **argv)
{
	rtwn_seq_result_t res;
	int doEfuseAll = 0, doFull = 0, doWrite = 0;
	int doPeek = 0, doPoke = 0, doDump = 0;
	uint32_t a1 = 0, a2 = 0;
	int i, ret = 0;

	for (i = 1; i < argc; i++) {
		if (strcmp(argv[i], "--efuse") == 0 || strcmp(argv[i], "--efuse-all") == 0)
			doEfuseAll = 1;
		else if (strcmp(argv[i], "--full") == 0) { doEfuseAll = 1; doFull = 1; }
		else if (strcmp(argv[i], "--write-test") == 0) doWrite = 1;
		else if (strcmp(argv[i], "--peek") == 0 && i + 1 < argc) {
			doPeek = 1; a1 = hexarg(argv[++i]);
			if (i + 1 < argc && argv[i + 1][0] != '-') a2 = hexarg(argv[++i]);
			else a2 = 1;
		} else if (strcmp(argv[i], "--poke") == 0 && i + 2 < argc) {
			doPoke = 1; a1 = hexarg(argv[++i]); a2 = hexarg(argv[++i]);
		} else if (strcmp(argv[i], "--dump") == 0 && i + 2 < argc) {
			doDump = 1; a1 = hexarg(argv[++i]); a2 = hexarg(argv[++i]);
		}
	}

	printf("=== rtwn-probe: RTL8188EUS (2357:010c) dari user space ===\n\n");
	rtwn_seq_diag_register(diag_cb);

	if (open_device() != 0) {
		return 2;
	}

	memset(&res, 0, sizeof(res));

	/* ── mode mentah ────────────────────────────────────────────── */
	if (doPeek) {
		uint8_t buf[256];
		uint32_t n = a2 ? a2 : 1;
		if (n > sizeof(buf)) n = sizeof(buf);
		printf("── peek 0x%03x (%u byte) ──\n", a1, n);
		if (probe_read(NULL, (uint16_t)a1, buf, (uint16_t)n) == 0) {
			for (uint32_t k = 0; k < n; k++) {
				if (k % 16 == 0) printf("  %03x:", a1 + k);
				printf(" %02x", buf[k]);
				if (k % 16 == 15) printf("\n");
			}
			if (n % 16) printf("\n");
		} else {
			printf("  GAGAL\n");
			ret = 1;
		}
		goto done;
	}

	if (doPoke) {
		uint32_t v = a2;
		printf("── poke 0x%03x <= 0x%08x ──\n", a1, v);
		if (probe_write(NULL, (uint16_t)a1, &v, 4) == 0) {
			uint32_t rb = 0;
			if (probe_read(NULL, (uint16_t)a1, &rb, 4) == 0)
				printf("  baca balik = 0x%08x %s\n", rb,
				    rb == v ? "✓" : "✗");
		} else {
			printf("  GAGAL\n");
			ret = 1;
		}
		goto done;
	}

	if (doDump) {
		uint32_t n = a2, off;
		printf("── dump 0x%03x..0x%03x ──\n", a1, a1 + n - 1);
		for (off = 0; off < n; off += 16) {
			uint32_t v[4] = {0, 0, 0, 0};
			uint32_t chunk = (n - off < 16) ? (n - off) : 16;
			if (probe_read(NULL, (uint16_t)(a1 + off), v, (uint16_t)chunk) != 0) {
				printf("  %03x: <gagal>\n", a1 + off);
				continue;
			}
			printf("  %03x:", a1 + off);
			for (uint32_t k = 0; k < chunk; k++)
				printf(" %02x", ((uint8_t *)v)[k]);
			printf("\n");
		}
		goto done;
	}

	/* ── info dasar ─────────────────────────────────────────────── */
	printf("── Tahap 1: baca register ──\n");
	if (rtwn_seq_read_regs(&res, probe_read, probe_write, NULL) != 0) {
		printf("  GAGAL: chip tidak menjawab vendor request.\n");
		ret = 1;
		goto done;
	}
	printf("  CR      = 0x%08x\n", res.cr);
	printf("  MCUFWDL = 0x%08x\n", res.mcuwdl);
	printf("  SYS_CFG = 0x%08x\n", res.syscfg);
	printf("  chip menjawab ✓\n\n");

	printf("── Register kunci ──\n");
	{
		static const struct { uint16_t a; const char *n; } regs[] = {
			{ 0x000, "SYS_FUNC_EN" }, { 0x002, "SYS_FUNC_EN+2" },
			{ 0x004, "APS_FSMCO" },   { 0x005, "APS_FSMCO+1" },
			{ 0x008, "RSV_CTRL" },    { 0x01c, "AFE_XTAL_CTRL" },
			{ 0x01d, "AFE_XTAL_CTRL2" }, { 0x003, "CR2" },
			{ 0x030, "EFUSE_CTRL/data" }, { 0x031, "EFUSE_ADDR_LO" },
			{ 0x032, "EFUSE_ADDR_HI" },   { 0x033, "EFUSE_STATUS" },
			{ 0x080, "MCUFWDL" },     { 0x088, "FWDL/trigger" },
			{ 0x093, "MCUFWDL_93" },  { 0x0cf, "EFUSE_ACCESS" },
			{ 0x0f0, "SYS_CFG" },     { 0x100, "CR" },
			{ 0x106, "EFUSE_106" },   { 0x140, "EFUSE_WIN" },
			{ 0x143, "EFUSE_STAT" },  { 0x144, "EFUSE_HDR" },
			{ 0x148, "EFUSE_DATA" },  { 0x209, "EFUSE_MODE" },
			{ 0x610, "MACID" },
		};
		for (size_t k = 0; k < sizeof(regs) / sizeof(regs[0]); k++) {
			uint8_t v = 0;
			if (probe_read(NULL, regs[k].a, &v, 1) == 0)
				printf("  0x%03x %-16s = 0x%02x\n", regs[k].a,
				    regs[k].n, v);
			else
				printf("  0x%03x %-16s = <gagal>\n", regs[k].a,
				    regs[k].n);
		}
	}
	printf("\n");

	if (doWrite) {
		uint32_t before = 0, after = 0;
		printf("── Uji tulis ──\n");
		if (probe_read(NULL, RTWN_REG_CR, &before, 4) == 0) {
			uint32_t want = before ^ 0x5a5a5a5a;
			printf("  CR 0x%08x → tulis 0x%08x ... ", before, want);
			if (probe_write(NULL, RTWN_REG_CR, &want, 4) == 0 &&
			    probe_read(NULL, RTWN_REG_CR, &after, 4) == 0) {
				printf("baca 0x%08x %s\n", after,
				    (after == want) ? "✓ cocok" : "✗ tidak cocok");
			} else {
				printf("GAGAL\n");
			}
		} else {
			printf("  GAGAL baca\n");
		}
		printf("\n");
	}

	if (doFull) {
		printf("── Tahap 3: power-on ──\n");
		if (rtwn_seq_power_on(&res, probe_read, probe_write, NULL) != 0)
			printf("  GAGAL: timeout menunggu chip power up\n");
		else
			printf("  power on OK\n");

		printf("── Tahap 4: LLT/DMA init ──\n");
		if (rtwn_seq_dma_init(&res, probe_read, probe_write, NULL, 3) != 0)
			printf("  GAGAL: LLT init\n");
		else
			printf("  LLT/DMA OK\n");

		printf("── Tahap 5: upload firmware 8051 ──\n");
		if (rtwn_seq_load_firmware(&res, probe_read, probe_write, NULL,
		    rtl8188eufw_bin, rtl8188eufw_bin_len) != 0)
			printf("  GAGAL: upload firmware (timeout checksum?)\n");
		else
			printf("  firmware %u byte terupload ✓\n", res.fwlen);
		printf("\n");
	}

	/* ── EFUSE: SEMUA jalur + diagnostik ─────────────────────────── */
	if (doEfuseAll) {
		rtwn_seq_result_t r2;

		printf("── Tahap 2b: EFUSE OFFLOAD (jalur HAL vendor) ──\n");
		memset(&r2, 0, sizeof(r2));
		if (rtwn_seq_read_efuse_offload(&r2, probe_read, probe_write, NULL) != 0)
			printf("  ✗ GAGAL\n");
		else {
			printf("  ✓ MAC = %02x:%02x:%02x:%02x:%02x:%02x\n",
			    r2.mac[0], r2.mac[1], r2.mac[2], r2.mac[3], r2.mac[4],
			    r2.mac[5]);
			res = r2;
		}
		printf("\n");

		printf("── Tahap 2a: EFUSE DIRECT (register 0x031/32/33/30) ──\n");
		memset(&r2, 0, sizeof(r2));
		if (rtwn_seq_read_efuse_direct_8188e(&r2, probe_read, probe_write,
		    NULL) != 0)
			printf("  ✗ GAGAL\n");
		else {
			printf("  ✓ MAC = %02x:%02x:%02x:%02x:%02x:%02x\n",
			    r2.mac[0], r2.mac[1], r2.mac[2], r2.mac[3], r2.mac[4],
			    r2.mac[5]);
			if (!res.efuse_ok) res = r2;
		}
		printf("\n");

		printf("── Tahap 2c: MACID register 0x610 ──\n");
		{
			uint8_t m[6];
			int ok = 1;
			for (int k = 0; k < 6; k++)
				if (probe_read(NULL, (uint16_t)(0x610 + k), &m[k], 1) != 0)
					ok = 0;
			if (ok)
				printf("  MACID = %02x:%02x:%02x:%02x:%02x:%02x%s\n",
				    m[0], m[1], m[2], m[3], m[4], m[5],
				    (m[0] == 0xff && m[1] == 0xff) ? "  (kosong)" : "");
			else
				printf("  GAGAL baca\n");
		}
		printf("\n");
	}

	printf("=== RINGKASAN ===\n");
	print_result(&res);
	printf("\n");

done:
	close_device();
	return ret;
}
