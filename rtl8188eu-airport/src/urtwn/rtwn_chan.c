/*
 * rtwn_chan.c — pengaturan kanal & akses register RF/BB untuk 8188E.
 *
 * Port dari OpenBSD rtwn.c (lisensi ISC):
 *   rtwn_set_chan()        rtwn.c:2408
 *   rtwn_rf_write()        rtwn.c:438
 *   rtwn_rf_read()         rtwn.c:463
 *
 * Diporting ke lapisan portabel kita (src/urtwn) memakai callback
 * read/write yang sudah ada (rtwn_seq_raw_read1/write1/read4/write4).
 *
 * CATATAN PENTING untuk 8188E (USB, 1 chain):
 *   - rtwn_bb_write = rtwn_write_4  (tulis 32-bit!)
 *   - rtwn_bb_read  = rtwn_read_4
 *   - param_addr pakai R88E_LSSI_PARAM_ADDR (bit 20..27), bukan
 *     R92C_LSSI_PARAM_ADDR (bit 20..25)
 *   - pada rtwn_rf_read, blok "restore READ_EDGE" DIHILANGKAN untuk 88E
 *     (hanya dilakukan untuk chip non-88E)
 */

#include "rtwn_chan.h"

#include <string.h>

/* ── register (dari OpenBSD r92creg.h) ─────────────────────────────── */
#define R92C_BWOPMODE			0x603
#define R92C_BWOPMODE_20MHZ		0x04

#define R92C_FPGA0_RFMOD		0x800
#define R92C_FPGA1_RFMOD		0x900
#define R92C_RFMOD_40MHZ		0x00000001

#define R92C_HSSI_PARAM1(chain)		(0x820 + (chain) * 8)
#define R92C_HSSI_PARAM2(chain)		(0x824 + (chain) * 8)
#define R92C_HSSI_PARAM1_PI		0x00000100
#define R92C_HSSI_PARAM2_READ_ADDR_M	0x7f800000
#define R92C_HSSI_PARAM2_READ_ADDR_S	23
#define R92C_HSSI_PARAM2_READ_EDGE	0x80000000

#define R92C_LSSI_PARAM(chain)		(0x840 + (chain) * 4)
#define R92C_LSSI_PARAM_DATA_M		0x000fffff
#define R92C_LSSI_PARAM_DATA_S		0
#define R88E_LSSI_PARAM_ADDR_M		0x0ff00000
#define R88E_LSSI_PARAM_ADDR_S		20

#define R92C_LSSI_READBACK(chain)	(0x8a0 + (chain) * 4)
#define R92C_HSPI_READBACK(chain)	(0x8b8 + (chain) * 4)
#define R92C_LSSI_READBACK_DATA_M	0x000fffff
#define R92C_LSSI_READBACK_DATA_S	0

#define R92C_RF_CHNLBW			0x18
#define R88E_RF_CHNLBW_BW20		0x00c00

/* BSD-style SM(field, val) = ((val << S) & M) */
#define RTWN_SM(mask, shift, val)	(((uint32_t)(val) << (shift)) & (mask))

/* ── helper baca/tulis 32-bit (bb) ─────────────────────────────────── */

static uint32_t
rtwn_bb_read(rtwn_read_fn rd, rtwn_write_fn wr, void *ctx, uint16_t reg)
{
	uint32_t v = 0;

	if (rd(ctx, reg, &v, 4) != 0) {
		return 0xffffffffu;
	}
	return v;
}

static int
rtwn_bb_write(rtwn_read_fn rd, rtwn_write_fn wr, void *ctx, uint16_t reg,
    uint32_t val)
{
	return wr(ctx, reg, &val, 4);
}

/*
 * Baca register RF (jalur readback 8188E).
 *
 * Mirip rtwn_rf_read() OpenBSD, minus blok restore READ_EDGE yang
 * hanya dipakai chip non-88E.
 */
uint32_t
rtwn_rf_read_8188e(rtwn_read_fn rd, rtwn_write_fn wr, void *ctx, int chain,
    uint8_t addr)
{
	uint32_t reg0, regc, val;

	if (chain < 0 || chain > 1) {
		return 0;
	}

	reg0 = rtwn_bb_read(rd, wr, ctx, (uint16_t)R92C_HSSI_PARAM2(0));
	regc = (chain != 0) ?
	    rtwn_bb_read(rd, wr, ctx, (uint16_t)R92C_HSSI_PARAM2(chain)) : reg0;

	/* matikan READ_EDGE di chain 0 */
	rtwn_bb_write(rd, wr, ctx, (uint16_t)R92C_HSSI_PARAM2(0),
	    reg0 & ~((uint32_t)R92C_HSSI_PARAM2_READ_EDGE));
	RTWN_DELAY_MS(1);

	/* set alamat baca + picu READ_EDGE */
	{
		uint32_t v = (regc & ~((uint32_t)R92C_HSSI_PARAM2_READ_ADDR_M)) |
		    RTWN_SM(R92C_HSSI_PARAM2_READ_ADDR_M,
			R92C_HSSI_PARAM2_READ_ADDR_S, addr) |
		    (uint32_t)R92C_HSSI_PARAM2_READ_EDGE;
		rtwn_bb_write(rd, wr, ctx,
		    (uint16_t)R92C_HSSI_PARAM2(chain), v);
	}
	RTWN_DELAY_MS(1);

	/* baca back */
	if (rtwn_bb_read(rd, wr, ctx,
	    (uint16_t)R92C_HSSI_PARAM1(chain)) & (uint32_t)R92C_HSSI_PARAM1_PI) {
		val = rtwn_bb_read(rd, wr, ctx,
		    (uint16_t)R92C_HSPI_READBACK(chain));
	} else {
		val = rtwn_bb_read(rd, wr, ctx,
		    (uint16_t)R92C_LSSI_READBACK(chain));
	}
	return (val >> R92C_LSSI_READBACK_DATA_S) & R92C_LSSI_READBACK_DATA_M;
}

/*
 * Tulis register RF (jalur LSSI parameter 8188E).
 */
int
rtwn_rf_write_8188e(rtwn_read_fn rd, rtwn_write_fn wr, void *ctx, int chain,
    uint16_t addr, uint32_t val)
{
	uint32_t param_addr;

	if (chain < 0 || chain > 1) {
		return -1;
	}

	/* 8188E pakai field addr 8 bit di bit 20..27 */
	param_addr = RTWN_SM(R88E_LSSI_PARAM_ADDR_M, R88E_LSSI_PARAM_ADDR_S,
	    addr & 0xff);

	rtwn_bb_write(rd, wr, ctx, (uint16_t)R92C_LSSI_PARAM(chain),
	    param_addr | RTWN_SM(R92C_LSSI_PARAM_DATA_M,
		R92C_LSSI_PARAM_DATA_S, val & 0xfffff));

	RTWN_DELAY_MS(1);
	return 0;
}

/*
 * Set kanal (mode 20 MHz — 8188E 1x1 2,4 GHz).
 *
 * Port dari rtwn_set_chan() OpenBSD, cabang "else" (bukan 40 MHz)
 * dengan penyesuaian chip 88E:
 *   - lewati blok ANAPARAM2 (khusus non-88E/88F/92E)
 *   - lewati blok 88F/92E (OFDM0/PSDO noise weight, RXAFE, DFIR)
 *   - pakai R88E_RF_CHNLBW_BW20 (0xc00), bukan R92C_RF_CHNLBW_BW20
 *
 * @chan : nomor kanal 1..14
 */
int
rtwn_set_chan_8188e(rtwn_read_fn rd, rtwn_write_fn wr, void *ctx, uint8_t chan)
{
	uint32_t v;

	if (chan < 1 || chan > 14) {
		return -1;
	}

	/* 1. mode bandwidth 20 MHz */
	v = rtwn_seq_raw_read1(rd, wr, ctx, R92C_BWOPMODE);
	rtwn_seq_raw_write1(rd, wr, ctx, R92C_BWOPMODE,
	    (uint8_t)(v | R92C_BWOPMODE_20MHZ));

	/* 2. matikan flag 40 MHz di FPGA RFMOD */
	v = rtwn_bb_read(rd, wr, ctx, R92C_FPGA0_RFMOD);
	rtwn_bb_write(rd, wr, ctx, R92C_FPGA0_RFMOD,
	    v & ~((uint32_t)R92C_RFMOD_40MHZ));

	v = rtwn_bb_read(rd, wr, ctx, R92C_FPGA1_RFMOD);
	rtwn_bb_write(rd, wr, ctx, R92C_FPGA1_RFMOD,
	    v & ~((uint32_t)R92C_RFMOD_40MHZ));

	/* 3. RF CHNLBW — chain 0 saja (8188E 1x1) */
	v = rtwn_rf_read_8188e(rd, wr, ctx, 0, R92C_RF_CHNLBW);
	v = (v & ~0xfffu) | (uint32_t)chan | (uint32_t)R88E_RF_CHNLBW_BW20;
	rtwn_rf_write_8188e(rd, wr, ctx, 0, R92C_RF_CHNLBW, v);

	return 0;
}
