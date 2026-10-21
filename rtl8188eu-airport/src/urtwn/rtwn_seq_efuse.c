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

	/*
	 * ‑‑‑ DIREKONSTRUKSI LANGSUNG DARI DECOMPILATION VENDOR ‑‑‑
	 *
	 * Sumber: RtWlanU :: InitOffload_ReadEfuse_8188EU (0xb1ea5), Ghidra
	 * 12.1.4, 22 Okt 2026. Perbedaan KRITIS dengan implementasi lama:
	 *
	 *  (1) TRIGGER 8051 dilakukan SEKALI per attempt — bukan per blok!
	 *      Versi lama trigger ulang tiap blok → tiap blok dapat hasil
	 *      kosong → raw[] berisi 0xff → MAC = ff:ff:ff:ff:ff:ff.
	 *
	 *  (2) LAYOUT raw per blok (ini yang tertukar di versi lama):
	 *        raw[k*8 + 6  .. k*8 + 9]  = LE(read4(0x144))   ← header
	 *        raw[k*8 + 10 .. k*8 + 13] = LE(read4(0x148))   ← data
	 *      Versi lama menulis data (0x148) di offset +6.
	 *
	 *  (3) raw[2..5] = LE(read4(0x148)) dari blok PERTAMA.
	 *
	 *  (4) Panjang stream untuk parser = (hdr & 0xffff), bukan 256.
	 *
	 *  (5) Mode 0xaa ATAU 0xf4 (GetInitialTxBufferBoundary88E, 0xb2f7a).
	 *      Kita coba keduanya bergantian.
	 *
	 *  (6) _InitPowerOn88EU dipanggil DI DALAM fungsi ini vendor.
	 *      Ours: power-on dilakukan terpisah sebelum memanggil ini
	 *      (pakai tabel flow yang identik) → setara.
	 */
	for (attempt = 0; attempt < 6; attempt++) {
		uint32_t hdr = 0, d1 = 0, hdr2 = 0, data = 0;
		int nblocks, extra, total, k;
		uint16_t i;
		uint8_t v;
		uint16_t rawlen;

		memset(raw, 0xff, sizeof(raw));

		/* Mode: 0xaa default; 0xf4 dicoba pada attempt kedua. */
		mode = (attempt % 2 == 0) ? 0xaa : 0xf4;
		rtwn_seq_raw_write1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_MODE, mode);
		base = (uint16_t)(mode * 0x10);

		/* ── TRIGGER (sekali per attempt) ─────────────────────────── */
		v = rtwn_seq_raw_read1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_CTRL);
		rtwn_seq_raw_write1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_CTRL,
		    (uint8_t)(v | 0x80));
		efuse_8051_reset(rd, wr, ctx);
		v = rtwn_seq_raw_read1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_TRIG);
		rtwn_seq_raw_write1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_TRIG,
		    (uint8_t)(v | 0x02));

		for (i = 0; i < 200; i++) {
			v = rtwn_seq_raw_read1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_TRIG);
			if ((v & 0x02) == 0) {
				break;
			}
			RTWN_DELAY_MS(1);
		}
		if (i >= 200) {
			/* Timeout: kembalikan flag & reset 8051, coba lagi. */
			v = rtwn_seq_raw_read1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_CTRL);
			rtwn_seq_raw_write1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_CTRL,
			    (uint8_t)(v & 0x7f));
			efuse_8051_reset(rd, wr, ctx);
			continue;
		}

		/* ── Akses EFUSE + window pertama ────────────────────────── */
		rtwn_seq_raw_write1(rd, wr, ctx, R92C_EFUSE_ACCESS, 0x69);
		rtwn_seq_raw_write2(rd, wr, ctx, R92C_EFUSE_OFFLOAD_ADDR, base);
		rtwn_seq_raw_write1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_STAT, 0);

		for (i = 0; i < 30; i++) {
			v = rtwn_seq_raw_read1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_STAT);
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

		if ((hdr & 0xffff) >= 0x101) {
			/* Header tidak masuk akal → coba mode berikutnya. */
			continue;
		}

		/* ── Susun raw stream (LANGKA vendor) ───────────────────── */
		raw[0] = (uint8_t)(hdr >> 16);
		raw[1] = (uint8_t)(hdr >> 24);
		raw[2] = (uint8_t)(d1 & 0xff);
		raw[3] = (uint8_t)((d1 >> 8) & 0xff);
		raw[4] = (uint8_t)((d1 >> 16) & 0xff);
		raw[5] = (uint8_t)((d1 >> 24) & 0xff);

		rawlen = (uint16_t)(hdr & 0xffff);
		nblocks = (int)((rawlen - 8) >> 3);
		extra = (hdr & 7) != 0;
		total = nblocks + extra;

		for (k = 0; k < total; k++) {
			uint16_t window = (uint16_t)(base + 1 + k);

			rtwn_seq_raw_write2(rd, wr, ctx, R92C_EFUSE_OFFLOAD_ADDR,
			    window);
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
				break;
			}

			rtwn_seq_raw_read4(rd, wr, ctx, R92C_EFUSE_OFFLOAD_HDR,
			    &hdr2);
			rtwn_seq_raw_read4(rd, wr, ctx, R92C_EFUSE_OFFLOAD_DATA,
			    &data);

			/*
			 * ★ LAYOUT VENDOR:
			 *   +6  = header blok (0x144)
			 *   +10 = data blok  (0x148)
			 */
			{
				size_t o = (size_t)k * 8 + 6;
				if (o + 8 > sizeof(raw)) {
					break;
				}
				raw[o + 0] = (uint8_t)(hdr2 & 0xff);
				raw[o + 1] = (uint8_t)((hdr2 >> 8) & 0xff);
				raw[o + 2] = (uint8_t)((hdr2 >> 16) & 0xff);
				raw[o + 3] = (uint8_t)((hdr2 >> 24) & 0xff);
				raw[o + 4] = (uint8_t)(data & 0xff);
				raw[o + 5] = (uint8_t)((data >> 8) & 0xff);
				raw[o + 6] = (uint8_t)((data >> 16) & 0xff);
				raw[o + 7] = (uint8_t)((data >> 24) & 0xff);
			}
		}

		/* Ekor 0xff: dari (rawlen-1) s/d rawlen + (hdr&7) + 5. */
		{
			uint32_t tail = (uint32_t)rawlen + (hdr & 7) + 5;
			uint32_t j;
			for (j = (rawlen > 1) ? (rawlen - 1) : 0; j < tail && j < sizeof(raw); j++) {
				raw[j] = 0xff;
			}
		}

		/* ── Parse (panjang stream = hdr & 0xffff, bukan 256) ───── */
		memset(rom, 0xff, sizeof(rom));
		rtwn_seq_efuse_parse(raw, rawlen, rom);

		memcpy(r->mac, rom + 215, 6);
		r->xtal = rom[185];
		r->channel_plan = rom[184];
		r->regulatory = (uint8_t)(rom[193] & 0x07);
		r->efuse_ok = 1;
		r->step = 2;

		/* Bersihkan: kembalikan flag & reset 8051. */
		v = rtwn_seq_raw_read1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_CTRL);
		rtwn_seq_raw_write1(rd, wr, ctx, R92C_EFUSE_OFFLOAD_CTRL,
		    (uint8_t)(v & 0x7f));
		efuse_8051_reset(rd, wr, ctx);

		/*
		 * Validasi hasil (dari decompilation vendor):
		 *   if (*out_rom == ')')            → byte pertama image = 0x29
		 *   dan sc[199] == 0x81
		 * Kalau byte pertama bukan 0x29 → image EFUSE tidak valid
		 * → coba mode berikutnya (0xaa / 0xf4).
		 *
		 * Ini MUCH lebih kuat daripada mengecek MAC != 0xff:
		 * MAC bisa saja valid-looking walau segmentnya salah.
		 */
		if (rom[0] == 0x29 && r->mac[0] != 0xff && r->mac[0] != 0x00) {
			return 0;
		}
		memset(r->mac, 0, sizeof(r->mac));
		r->efuse_ok = 0;
	}

	return -1;
}
