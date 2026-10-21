/*
 * rtwn_seq_efuse.c — jalur baca EFUSE 8188E USB gaya driver vendor.
 *
 * PENTING: untuk 8188E USB, EFUSE TIDAK bisa dibaca langsung lewat
 * EFUSE_CTRL seperti di OpenBSD. Chip ini memakai jalur "offload": mesin
 * internal/8051 melakukan pembacaan dan mengembalikan (header, data)
 * lewat register 0x144/0x148.
 *
 * Sumber: decompilation Ghidra atas RtWlanU.kext
 *   - InitOffload_ReadEfuse_8188EU   (0xb1ea5)  → urutan offload
 *   - ParsingEfuseContent_8188EU      (0xb1bc2)  → parser (sudah di rtwn_seq.c)
 *   - Hal_EfuseParseXtal_8188E        (0x145358) → xtal dari rom[185]
 *   - HAL_8051Reset                   (0x71887)
 *   - HAL_8051PauseIOWrapper          (0x7169e)
 *   - HAL_8051EnableIOWrapper         (0x71799)
 *
 * Register yang dipakai (dari vendor):
 *   0x209  mode EFUSE (0xaa / 0xf4)      0x140  alamat window (16 bit)
 *   0x0F0  enable/p-flag                 0x143  status (bit0 = siap)
 *   0x088  trigger (bit1)                0x144  header (32 bit)
 *   0x088/0x106  reset 8051 / akses EFUSE (0x69)
 */

#include "rtwn_seq.h"
#include "rtwn_platform.h"
#include <string.h>

/* Register vendor (lihat header di atas). */
#define R92C_EFUSE_OFFLOAD_MODE   0x209
#define R92C_EFUSE_OFFLOAD_CTRL   0x0f0
#define R92C_EFUSE_OFFLOAD_TRIG   0x088
#define R92C_EFUSE_OFFLOAD_ADDR   0x140
#define R92C_EFUSE_OFFLOAD_STAT   0x143
#define R92C_EFUSE_OFFLOAD_HDR    0x144
#define R92C_EFUSE_OFFLOAD_DATA   0x148
#define R92C_EFUSE_ACCESS         0x106
#define R92C_SYS_FUNC_EN2         0x01c
#define R92C_AFE_XTAL_CTRL2       0x01d
#define R92C_CR2                  0x003

/* Helper: delay dalam ms. Di user space (probe) memakai usleep; di kernel
 * RTWN_DELAY_MS di-override ke IODelay/thread delay. */

/* --- internal helpers (menggunakan callback rtwn_seq.c) --- */

/* 8051 reset: pause IO wrapper → delay 50 ms → enable IO wrapper.
 * Untuk 8188EUSB (tipe 0x32) vendor memakai register 0x093 & 0xFE/0x01
 * dan reg 0x003 & 0xFB/0x04. */
static void efuse_8051_pause(rtwn_read_fn rd, rtwn_write_fn wr, void *ctx)
{
	uint8_t v;

	v = rtwn_seq_raw_read1(rd, wr, ctx, 0x093);
	rtwn_seq_raw_write1(rd, wr, ctx, 0x093, (uint8_t)(v & 0xfe));

	v = rtwn_seq_raw_read1(rd, wr, ctx, 0x003);
	rtwn_seq_raw_write1(rd, wr, ctx, 0x003, (uint8_t)(v & 0xfb));
}

static void efuse_8051_enable(rtwn_read_fn rd, rtwn_write_fn wr, void *ctx)
{
	uint8_t v;

	v = rtwn_seq_raw_read1(rd, wr, ctx, 0x093);
	rtwn_seq_raw_write1(rd, wr, ctx, 0x093, (uint8_t)(v | 0x01));

	v = rtwn_seq_raw_read1(rd, wr, ctx, 0x003);
	rtwn_seq_raw_write1(rd, wr, ctx, 0x003, (uint8_t)(v | 0x04));
}

static void efuse_8051_reset(rtwn_read_fn rd, rtwn_write_fn wr, void *ctx)
{
	efuse_8051_pause(rd, wr, ctx);
	RTWN_DELAY_MS(1);
	efuse_8051_enable(rd, wr, ctx);
}

/*
 * Baca satu blok EFUSE lewat offload.
 *
 * Mengembalikan:
 *   0  sukses
 *   -1  timeout / gagal
 *
 * Output: hdr (32 bit) + 8 byte data.
 */
static int efuse_offload_block(rtwn_read_fn rd, rtwn_write_fn wr, void *ctx,
    uint16_t window, uint32_t *hdr, uint8_t *data8)
{
	uint8_t v;
	uint16_t i;
	uint32_t d1, d2;

	/* Mulai: set flag di 0x0F0, reset 8051, trigger (bit1 di 0x088). */
	v = rtwn_seq_raw_read1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_CTRL);
	rtwn_seq_raw_write1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_CTRL,
	    (uint8_t)(v | 0x80));

	efuse_8051_reset(rd, wr, ctx);

	v = rtwn_seq_raw_read1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_TRIG);
	rtwn_seq_raw_write1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_TRIG,
	    (uint8_t)(v | 0x02));

	/* Tunggu sampai bit1 hilang (maks 1000 × 50 ms). */
	for (i = 0; i < 200; i++) {
		v = rtwn_seq_raw_read1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_TRIG);
		if ((v & 0x02) == 0) {
			break;
		}
		RTWN_DELAY_MS(1);
	}
	if (i >= 200) {
		/* Timeout: kembalikan flag & reset 8051. */
		v = rtwn_seq_raw_read1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_CTRL);
		rtwn_seq_raw_write1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_CTRL,
		    (uint8_t)(v & 0x7f));
		efuse_8051_reset(rd, wr, ctx);
		return -1;
	}

	/* Aktifkan akses EFUSE, set window, mulai. */
	rtwn_seq_raw_write1(rd, wr, ctx, R92C_EFUSE_ACCESS, 0x69);
	rtwn_seq_raw_write2(rd, wr, ctx, R92C_EFUSE_OFFLOAD_ADDR, window);
	rtwn_seq_raw_write1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_STAT, 0);

	/* Tunggu bit0 = siap (maks 50 × 50 ms). */
	for (i = 0; i < 30; i++) {
		v = rtwn_seq_raw_read1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_STAT);
		if (v & 0x01) {
			break;
		}
		RTWN_DELAY_MS(1);
	}
	if (i >= 30) {
		return -1;
	}

	*hdr = 0;
	rtwn_seq_raw_read4(rd, wr, ctx, R92C_EFUSE_OFFLOAD_HDR, hdr);
	rtwn_seq_raw_read4(rd, wr, ctx, R92C_EFUSE_OFFLOAD_DATA, &d1);
	d2 = 0;
	rtwn_seq_raw_read4(rd, wr, ctx, R92C_EFUSE_OFFLOAD_DATA, &d2);

	/* Susun 8 byte data (little-endian, 2 x 32 bit). */
	data8[0] = (uint8_t)(d1 & 0xff);
	data8[1] = (uint8_t)((d1 >> 8) & 0xff);
	data8[2] = (uint8_t)((d1 >> 16) & 0xff);
	data8[3] = (uint8_t)((d1 >> 24) & 0xff);
	data8[4] = (uint8_t)(d2 & 0xff);
	data8[5] = (uint8_t)((d2 >> 8) & 0xff);
	data8[6] = (uint8_t)((d2 >> 16) & 0xff);
	data8[7] = (uint8_t)((d2 >> 24) & 0xff);
	return 0;
}

/*
 * Baca seluruh EFUSE 8188E USB lewat jalur offload vendor.
 *
 * Mengisi result->mac / xtal / regulatory / channel_plan.
 * Return 0 = sukses.
 */
int rtwn_seq_read_efuse_offload(rtwn_seq_result_t *r, rtwn_read_fn rd,
    rtwn_write_fn wr, void *ctx)
{
	uint8_t raw[256];
	uint8_t rom[512];
	uint8_t mode;
	uint16_t base;
	int attempt;

	for (attempt = 0; attempt < 3; attempt++) {
		uint32_t hdr = 0, d1 = 0, d2 = 0;
		int nblocks, k, ok = 0;

		memset(raw, 0xff, sizeof(raw));

		/* Mode: 0xaa default, 0xf4 untuk chip 8814b-class. 8188E → 0xaa. */
		mode = 0xaa;
		rtwn_seq_raw_write1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_MODE, mode);
		base = (uint16_t)(mode * 0x10);

		/* Blok pertama: header + 4 byte data. */
		{
			uint8_t v = rtwn_seq_raw_read1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_CTRL);
			uint16_t i;

			rtwn_seq_raw_write1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_CTRL,
			    (uint8_t)(v | 0x80));
			efuse_8051_reset(rd, wr, ctx);

			v = rtwn_seq_raw_read1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_TRIG);
			rtwn_seq_raw_write1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_TRIG,
			    (uint8_t)(v | 0x02));

			for (i = 0; i < 200; i++) {
				v = rtwn_seq_raw_read1(rd, wr, ctx,
				    R92C_EFUSE_OFFLOAD_TRIG);
				if ((v & 0x02) == 0) {
					break;
				}
				RTWN_DELAY_MS(1);
			}
			if (i >= 200) {
				v = rtwn_seq_raw_read1(rd, wr, ctx,
				    R92C_EFUSE_OFFLOAD_CTRL);
				rtwn_seq_raw_write1(rd, wr, ctx,
				    R92C_EFUSE_OFFLOAD_CTRL, (uint8_t)(v & 0x7f));
				efuse_8051_reset(rd, wr, ctx);
				continue;
			}

			rtwn_seq_raw_write1(rd, wr, ctx, R92C_EFUSE_ACCESS, 0x69);
			rtwn_seq_raw_write2(rd, wr, ctx, R92C_EFUSE_OFFLOAD_ADDR, base);
			rtwn_seq_raw_write1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_STAT, 0);

			for (i = 0; i < 30; i++) {
				v = rtwn_seq_raw_read1(rd, wr, ctx,
				    R92C_EFUSE_OFFLOAD_STAT);
				if (v & 0x01) {
					break;
				}
				RTWN_DELAY_MS(1);
			}
			if (i >= 30) {
				continue;
			}

			rtwn_seq_raw_read4(rd, wr, ctx, R92C_EFUSE_OFFLOAD_HDR, &hdr);
			rtwn_seq_raw_read4(rd, wr, ctx, R92C_EFUSE_OFFLOAD_DATA, &d1);
			rtwn_seq_raw_read4(rd, wr, ctx, R92C_EFUSE_OFFLOAD_DATA, &d2);
		}

		if ((hdr & 0xffff) < 0x101) {
			/*
			 * ‑‑‑ PERBAIKAN KEAMANAN (audit 22 Okt 2026) ‑‑‑
			 *
			 * `hdr` berasal dari chip (register offload header).
			 * Aritmetika sebelumnya:
			 *     int n = (int)(((hdr & 0xffff) - 8) >> 3);
			 * `(hdr & 0xffff)` bertipe unsigned → kalau nilainya
			 * < 8 (mis. 0, saat 8051 belum mengisi header),
			 * hasilnya underflow jadi 0x1FFFFFFF → n = 536jt.
			 *
			 * Akibatnya:
			 *   1. loop 536 juta iterasi (kernel hang),
			 *   2. `8 * k + 6` overflow int → off jadi NEGATIF,
			 *   3. guard `off + 8 <= sizeof(raw)` jadi TRUE untuk
			 *      off negatif → memcpy menulis 8 byte DI LUAR
			 *      array raw → STACK SMASH di kernel.
			 *
			 * Perbaikan: validasi header SEBELUM aritmetika,
			 * gunakan indeks unsigned, dan batas keras jumlah blok.
			 */
			uint32_t h = hdr & 0xffff;
			int n, ex, nblocks;

			if (h < 8 || h > 0x100) {
				/* Header tidak masuk akal → jangan proses. */
				return -1;
			}
			n = (int)((h - 8) >> 3);
			ex = (hdr & 7) != 0;	/* blok tambahan */
			nblocks = n + ex;

			/* Batas keras: raw[256] menampung maksimal 32 blok. */
			if (nblocks < 0 || nblocks > (int)(sizeof(raw) / 8)) {
				nblocks = (int)(sizeof(raw) / 8);
			}

			raw[0] = (uint8_t)(hdr >> 16);
			raw[1] = (uint8_t)(hdr >> 24);
			raw[2] = (uint8_t)(d1 & 0xff);
			raw[3] = (uint8_t)((d1 >> 8) & 0xff);
			raw[4] = (uint8_t)((d1 >> 16) & 0xff);
			raw[5] = (uint8_t)((d1 >> 24) & 0xff);

			for (k = 0; k < nblocks; k++) {
				uint8_t d8[8];
				size_t off = (size_t)k * 8 + 6;	/* unsigned */

				if (efuse_offload_block(rd, wr, ctx,
				    (uint16_t)(base + 1 + k), &hdr, d8) != 0) {
					break;
				}
				if (off + 8 <= sizeof(raw)) {
					memcpy(raw + off, d8, 8);
				}
			}
			ok = 1;
		}

		if (ok) {
			/* Kembalikan flag & reset 8051. */
			{
				uint8_t v = rtwn_seq_raw_read1(rd, wr, ctx,
				    R92C_EFUSE_OFFLOAD_CTRL);
				rtwn_seq_raw_write1(rd, wr, ctx,
				    R92C_EFUSE_OFFLOAD_CTRL, (uint8_t)(v & 0x7f));
			}
			efuse_8051_reset(rd, wr, ctx);

			/* Parse dengan parser yang sudah diverifikasi identik vendor. */
			memset(rom, 0xff, sizeof(rom));
			rtwn_seq_efuse_parse(raw, (uint16_t)sizeof(raw), rom);

			memcpy(r->mac, rom + 215, 6);
			r->xtal = rom[185];
			r->channel_plan = rom[184];
			r->regulatory = (uint8_t)(rom[193] & 0x07);
			r->efuse_ok = 1;
			r->step = 2;
			return 0;
		}
	}

	return -1;
}
