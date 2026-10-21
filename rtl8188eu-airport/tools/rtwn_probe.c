/*
 * rtwn-probe — uji protokol & urutan M1 untuk RTL8188EUS (2357:010c)
 *              dari USER SPACE (tanpa kernel, tanpa risiko freeze).
 *
 * Pakai modul portabel src/urtwn/rtwn_seq.c — kode yang PERSIS sama dengan
 * yang akan dipakai driver kernel nanti. Jadi apa pun yang berhasil di sini
 * sudah terbukti benar sebelum masuk ke kernel.
 *
 * Build:
 *   clang -O2 -o tools/rtwn_probe tools/rtwn_probe.c src/urtwn/rtwn_seq.c \
 *         src/urtwn/firmware_rtl8188eufw.cpp -Isrc/urtwn \
 *         -framework IOKit -framework CoreFoundation
 *
 * Pakai:
 *   sudo ./tools/rtwn_probe                 # baca register saja (aman)
 *   sudo ./tools/rtwn_probe --efuse         # + baca EFUSE (MAC)
 *   sudo ./tools/rtwn_probe --full          # + power-on + LLT + upload firmware
 *   sudo ./tools/rtwn_probe --write-test    # uji tulis (baca→ubah→baca)
 *
 * CATATAN: device harus TIDAK dipegang driver kernel (RtWlanU).
 *          Matikan dulu: sudo ./scripts/vendor-off.sh  (+ reboot)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <IOKit/IOKitLib.h>
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

/* --- callback I/O untuk rtwn_seq --- */
static int probe_read(void *ctx, uint16_t addr, void *buf, uint16_t len)
{
	IOUSBDevRequest req;

	memset(&req, 0, sizeof(req));
	req.bmRequestType = 0xC0;	/* IN | VENDOR | DEVICE */
	req.bRequest = REQ_REGS;
	req.wValue = addr;
	req.wIndex = 0;
	req.wLength = len;
	req.pData = buf;
	req.wLenDone = 0;

	if (gDev == NULL) {
		return -1;
	}
	if (gDev[0]->DeviceRequest(gDev[0], &req) != kIOReturnSuccess) {
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

	memset(&req, 0, sizeof(req));
	req.bmRequestType = 0x40;	/* OUT | VENDOR | DEVICE */
	req.bRequest = REQ_REGS;
	req.wValue = addr;
	req.wIndex = 0;
	req.wLength = len;
	req.pData = (void *)buf;
	req.wLenDone = 0;

	if (gDev == NULL) {
		return -1;
	}
	if (gDev[0]->DeviceRequest(gDev[0], &req) != kIOReturnSuccess) {
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

int main(int argc, char **argv)
{
	CFMutableDictionaryRef match;
	io_iterator_t iter;
	io_service_t svc;
	int doEfuse = 0, doFull = 0, doWrite = 0, doOffload = 0, doDirect = 0;
	rtwn_seq_result_t res;
	int i;

	for (i = 1; i < argc; i++) {
		if (strcmp(argv[i], "--efuse") == 0) doEfuse = 1;
		else if (strcmp(argv[i], "--full") == 0) { doEfuse = 1; doFull = 1; }
		else if (strcmp(argv[i], "--efuse-offload") == 0) { doOffload = 1; }
		else if (strcmp(argv[i], "--efuse-direct") == 0) { doDirect = 1; }
		else if (strcmp(argv[i], "--write-test") == 0) doWrite = 1;
	}

	printf("=== rtwn-probe: RTL8188EUS (2357:010c) dari user space ===\n\n");

	/* 1. Cari device. */
	match = IOServiceMatching("IOUSBDevice");
	{
		int vidVal = VID, pidVal = PID;
		CFNumberRef vid = CFNumberCreate(kCFAllocatorDefault,
		    kCFNumberSInt32Type, &vidVal);
		CFNumberRef pid = CFNumberCreate(kCFAllocatorDefault,
		    kCFNumberSInt32Type, &pidVal);
		CFDictionarySetValue(match, CFSTR("idVendor"), vid);
		CFDictionarySetValue(match, CFSTR("idProduct"), pid);
		CFRelease(vid);
		CFRelease(pid);
	}

	IOServiceGetMatchingServices(kIOMainPortDefault, match, &iter);
	svc = IOIteratorNext(iter);
	if (!svc) {
		printf("!! Device 2357:010c tidak ditemukan.\n");
		IOObjectRelease(iter);
		return 2;
	}

	/* 2. Buka user client. */
	{
		io_connect_t conn = 0;
		IOReturn r = IOServiceOpen(svc, mach_task_self(), 0, &conn);
		if (r != kIOReturnSuccess) {
			printf("!! IOServiceOpen gagal: 0x%08x\n", r);
			if (r == kIOReturnExclusiveAccess) {
				printf("   → device sedang dipegang driver kernel.\n");
				printf("     Matikan RtWlanU dulu "
				    "(sudo ./scripts/vendor-off.sh + reboot).\n");
			}
			IOObjectRelease(svc);
			IOObjectRelease(iter);
			return 3;
		}
		gDev = (IOUSBDeviceInterface **)&conn;
	}
	printf("  device dibuka ✓\n\n");

	memset(&res, 0, sizeof(res));

	/* 3. Tahap 1: baca register. */
	printf("── Tahap 1: baca register ──\n");
	if (rtwn_seq_read_regs(&res, probe_read, probe_write, NULL) != 0) {
		printf("  GAGAL: chip tidak menjawab vendor request.\n");
		printf("  → encoding bmRequestType/bRequest/wValue perlu diperiksa.\n");
		goto out;
	}
	printf("  CR      = 0x%08x\n", res.cr);
	printf("  MCUFWDL = 0x%08x\n", res.mcuwdl);
	printf("  SYS_CFG = 0x%08x\n", res.syscfg);
	printf("  chip menjawab ✓\n\n");

	/*
	 * 4. Deteksi "base" alamat register.
	 *
	 * Driver vendor (RtWlanU) menghitung:
	 *     address = HAL_GetAddressOffset(adapter, offset) + (offset & 0xFFFF)
	 * dengan base taken dari device object bila offset < 0x100, else 0.
	 * Register >= 0x100 (CR 0x100, MACID 0x610) → base pasti 0.
	 * Register < 0x100 (MCUFWDL 0x080, SYS_CFG 0x0F0) → base bisa != 0.
	 *
	 * Kita baca beberapa kandidat; nilai yang "waras" (MCUFWDL punya bit
	 * EN/RDY/CHKSUM_RPT) menunjukkan base yang benar.
	 */
	printf("\n── Deteksi base alamat register (< 0x100) ──\n");
	{
		static const uint32_t bases[] = { 0, 0x100, 0x200, 0x400, 0x1000, 0x2000, 0x3000 };
		for (size_t bi = 0; bi < sizeof(bases) / sizeof(bases[0]); bi++) {
			uint32_t mcu = 0xffffffff, cfg = 0xffffffff;
			uint16_t mcuAddr = (uint16_t)(0x080 + bases[bi]);
			uint16_t cfgAddr = (uint16_t)(0x0f0 + bases[bi]);
			int okM = (probe_read(NULL, mcuAddr, &mcu, 4) == 0);
			int okC = (probe_read(NULL, cfgAddr, &cfg, 4) == 0);
			if (!okM && !okC) {
				continue;
			}
			printf("  base=0x%-5x MCUFWDL@0x%03x=0x%08x  SYS_CFG@0x%03x=0x%08x%s\n",
			    bases[bi], mcuAddr, mcu, cfgAddr, cfg,
			    ((mcu & 0x47) != 0xffffffff && (mcu & 0x47) != 0) ? "  <-- SANE ✓" : "");
		}
	}

	/* 5. Uji tulis opsional. */
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

	/* 5. Tahap 2: EFUSE. */
	if (doEfuse) {
		printf("── Tahap 2: baca EFUSE (MAC) ──\n");
		if (rtwn_seq_read_efuse(&res, probe_read, probe_write, NULL) != 0) {
			printf("  GAGAL baca EFUSE\n");
		} else {
			printf("  MAC      = %02x:%02x:%02x:%02x:%02x:%02x\n",
			    res.mac[0], res.mac[1], res.mac[2], res.mac[3],
			    res.mac[4], res.mac[5]);
			printf("  xtal=0x%02x regulatory=%u channel_plan=%u\n",
			    res.xtal, res.regulatory, res.channel_plan);
		}
		printf("\n");
	}

	/* 5a. Jalur DIRECT dengan layout register 8188E (0x31/0x32/0x33/0x30). */
	if (doDirect) {
		printf("── Tahap 2a: baca EFUSE langsung (layout register 8188E) ──\n");
		if (rtwn_seq_read_efuse_direct_8188e(&res, probe_read, probe_write, NULL) != 0) {
			printf("  GAGAL: timeout baca EFUSE\n");
		} else {
			printf("  MAC      = %02x:%02x:%02x:%02x:%02x:%02x\n",
			    res.mac[0], res.mac[1], res.mac[2], res.mac[3],
			    res.mac[4], res.mac[5]);
			printf("  xtal=0x%02x regulatory=%u channel_plan=%u\n",
			    res.xtal, res.regulatory, res.channel_plan);
		}
		printf("\n");
	}

	/* 5b. Jalur OFFLOAD (gaya driver vendor) — untuk 8188E USB. */
	if (doOffload) {
		printf("── Tahap 2b: baca EFUSE via jalur OFFLOAD (vendor) ──\n");
		if (rtwn_seq_read_efuse_offload(&res, probe_read, probe_write, NULL) != 0) {
			printf("  GAGAL: offload EFUSE timeout\n");
		} else {
			printf("  MAC      = %02x:%02x:%02x:%02x:%02x:%02x\n",
			    res.mac[0], res.mac[1], res.mac[2], res.mac[3],
			    res.mac[4], res.mac[5]);
			printf("  xtal=0x%02x regulatory=%u channel_plan=%u\n",
			    res.xtal, res.regulatory, res.channel_plan);
		}
		printf("\n");
	}

	/* 6. Tahap 3-5: power-on, LLT, firmware. */
	if (doFull) {
		printf("── Tahap 3: power-on ──\n");
		if (rtwn_seq_power_on(&res, probe_read, probe_write, NULL) != 0) {
			printf("  GAGAL: timeout menunggu chip power up\n");
		} else {
			printf("  power on OK\n");
		}

		printf("── Tahap 4: LLT/DMA init ──\n");
		if (rtwn_seq_dma_init(&res, probe_read, probe_write, NULL, 3) != 0) {
			printf("  GAGAL: LLT init\n");
		} else {
			printf("  LLT/DMA OK\n");
		}

		printf("── Tahap 5: upload firmware 8051 ──\n");
		if (rtwn_seq_load_firmware(&res, probe_read, probe_write, NULL,
		    rtl8188eufw_bin, rtl8188eufw_bin_len) != 0) {
			printf("  GAGAL: upload firmware (timeout checksum?)\n");
		} else {
			printf("  firmware %u byte terupload ✓\n", res.fwlen);
		}
	}

	printf("=== RINGKASAN ===\n");
	print_result(&res);
	printf("\n");

out:
	if (gDev) {
		(*gDev)->USBDeviceClose(gDev);
		gDev = NULL;
	}
	IOObjectRelease(svc);
	IOObjectRelease(iter);
	return 0;
}
