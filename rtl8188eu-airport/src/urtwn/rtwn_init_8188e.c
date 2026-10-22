/*
 * rtwn_init_8188e.c — inisialisasi MAC/BB/RF RTL8188E (M2).
 *
 * Sumber: OpenBSD urtwn (ISC). Semua nilai tabel berasal dari
 * src/urtwn/r92creg.h (rtl8188eu_mac, rtl8188eu_bb_prog,
 * rtl8188eu_rf_prog) — tabel yang sama yang dipakai OpenBSD untuk
 * RTL8188EU.
 *
 * Urutan (mengikuti rtwn_init() OpenBSD):
 *   1. MAC table
 *   2. BB table + AGC + crystal cap
 *   3. RF table (chain 0)
 *   4. Konfigurasi inti (Rx filter, EDCA, TX/RX enable, agregasi USB)
 */

#include "rtwn_init_8188e.h"

#include <string.h>

#include "rtwn_platform.h"
#include "rtwn_chan.h"

/*
 * Tabel init OpenBSD. Header ini mendefinisikan banyak tabel chip lain
 * yang tidak dipakai di sini — matikan peringatan "unused".
 */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-const-variable"
#pragma clang diagnostic ignored "-Wunused-variable"
#include "r92creg.h"
#pragma clang diagnostic pop

/* ── helper ─────────────────────────────────────────────────────────── */

static uint8_t
wr8(rtwn_read_fn rd, rtwn_write_fn wr, void *ctx, uint16_t reg, uint8_t v)
{
	(void)rd;
	return (uint8_t)wr(ctx, reg, &v, 1);
}

static int
rd16(rtwn_read_fn rd, void *ctx, uint16_t reg, uint16_t *out)
{
	return rd(ctx, reg, out, 2);
}

static int
wr16(rtwn_read_fn rd, rtwn_write_fn wr, void *ctx, uint16_t reg, uint16_t v)
{
	(void)rd;
	return wr(ctx, reg, &v, 2);
}

static int
rd32(rtwn_read_fn rd, void *ctx, uint16_t reg, uint32_t *out)
{
	return rd(ctx, reg, out, 4);
}

static int
wr32(rtwn_read_fn rd, rtwn_write_fn wr, void *ctx, uint16_t reg, uint32_t v)
{
	(void)rd;
	return wr(ctx, reg, &v, 4);
}

/* ── 1. MAC ─────────────────────────────────────────────────────────── */

int
rtwn_init_mac_8188e(rtwn_read_fn rd, rtwn_write_fn wr, void *ctx)
{
	size_t i;
	int n = 0;

	for (i = 0; i < nitems(rtl8188eu_mac); i++) {
		if (wr8(rd, wr, ctx, rtl8188eu_mac[i].reg,
		    rtl8188eu_mac[i].val) == 0) {
			n++;
		}
	}

	/* 8188E: batas agregasi (OpenBSD urtwn_mac_init). */
	wr8(rd, wr, ctx, R92C_MAX_AGGR_NUM, 0x07);

	return n;
}

/* ── 2. BB + AGC + xtal ─────────────────────────────────────────────── */

int
rtwn_init_bb_8188e(rtwn_read_fn rd, rtwn_write_fn wr, void *ctx, uint8_t xtal)
{
	const struct r92c_bb_prog *prog = &rtl8188eu_bb_prog;
	uint16_t v16;
	uint32_t reg;
	size_t i;
	int n = 0;

	/* Enable BB dan RF (OpenBSD urtwn_bb_init). */
	if (rd16(rd, ctx, R92C_SYS_FUNC_EN, &v16) == 0) {
		wr16(rd, wr, ctx, R92C_SYS_FUNC_EN,
		    (uint16_t)(v16 | R92C_SYS_FUNC_EN_BBRSTB |
		    R92C_SYS_FUNC_EN_BB_GLB_RST | R92C_SYS_FUNC_EN_DIO_RF));
	}

	wr8(rd, wr, ctx, R92C_RF_CTRL,
	    (uint8_t)(R92C_RF_CTRL_EN | R92C_RF_CTRL_RSTB |
	    R92C_RF_CTRL_SDMRSTB));

	wr8(rd, wr, ctx, R92C_SYS_FUNC_EN,
	    (uint8_t)(R92C_SYS_FUNC_EN_USBA | R92C_SYS_FUNC_EN_USBD |
	    R92C_SYS_FUNC_EN_BB_GLB_RST | R92C_SYS_FUNC_EN_BBRSTB));

	/* Tabel BB (4 byte per register). */
	for (i = 0; i < (size_t)prog->count; i++) {
		if (wr32(rd, wr, ctx, prog->regs[i], prog->vals[i]) == 0) {
			n++;
		}
		RTWN_DELAY_MS(1);
	}

	/* Tabel AGC (ditulis berulang ke R92C_OFDM0_AGCRSSITABLE). */
	for (i = 0; i < (size_t)prog->agccount; i++) {
		if (wr32(rd, wr, ctx, R92C_OFDM0_AGCRSSITABLE,
		    prog->agcvals[i]) == 0) {
			n++;
		}
		RTWN_DELAY_MS(1);
	}

	/* AGC core 1: 0x69553422 lalu 0x69553420 (OpenBSD). */
	wr32(rd, wr, ctx, R92C_OFDM0_AGCCORE1(0), 0x69553422u);
	RTWN_DELAY_MS(1);
	wr32(rd, wr, ctx, R92C_OFDM0_AGCCORE1(0), 0x69553420u);
	RTWN_DELAY_MS(1);

	/* Crystal cap: 6 bit, digandakan ke dua field. */
	xtal &= 0x3f;
	if (rd32(rd, ctx, R92C_AFE_XTAL_CTRL, &reg) == 0) {
		reg &= ~(uint32_t)R92C_AFE_XTAL_CTRL_ADDR_M;
		reg |= ((uint32_t)(xtal | (uint32_t)(xtal << 6)) <<
		    R92C_AFE_XTAL_CTRL_ADDR_S) &
		    (uint32_t)R92C_AFE_XTAL_CTRL_ADDR_M;
		wr32(rd, wr, ctx, R92C_AFE_XTAL_CTRL, reg);
	}

	return n;
}

/* ── 3. RF (chain 0) ────────────────────────────────────────────────── */

int
rtwn_init_rf_8188e(rtwn_read_fn rd, rtwn_write_fn wr, void *ctx)
{
	const struct r92c_rf_prog *prog = &rtl8188eu_rf_prog[0];
	uint32_t reg, type;
	uint16_t addr;
	size_t j;
	int n = 0;

	/* Simpan tipe RF_ENV. */
	if (rd32(rd, ctx, R92C_FPGA0_RFIFACESW(0), &reg) != 0) {
		return -1;
	}
	type = reg & 0x10;

	/* RF_ENV enable. */
	if (rd32(rd, ctx, R92C_FPGA0_RFIFACEOE(0), &reg) != 0) {
		return -1;
	}
	wr32(rd, wr, ctx, R92C_FPGA0_RFIFACEOE(0), reg | 0x100000u);
	RTWN_DELAY_MS(1);

	/* RF_ENV output high. */
	rd32(rd, ctx, R92C_FPGA0_RFIFACEOE(0), &reg);
	wr32(rd, wr, ctx, R92C_FPGA0_RFIFACEOE(0), reg | 0x10u);
	RTWN_DELAY_MS(1);

	/* Panjang alamat & data RF. */
	rd32(rd, ctx, R92C_HSSI_PARAM2(0), &reg);
	wr32(rd, wr, ctx, R92C_HSSI_PARAM2(0),
	    reg & ~(uint32_t)R92C_HSSI_PARAM2_ADDR_LENGTH);
	RTWN_DELAY_MS(1);
	rd32(rd, ctx, R92C_HSSI_PARAM2(0), &reg);
	wr32(rd, wr, ctx, R92C_HSSI_PARAM2(0),
	    reg & ~(uint32_t)R92C_HSSI_PARAM2_DATA_LENGTH);
	RTWN_DELAY_MS(1);

	/* Tabel RF chain 0. */
	for (j = 0; j < (size_t)prog->count; j++) {
		addr = prog->regs[j];
		switch (addr) {
		case 0xfe:
		case 0xffe:
			RTWN_DELAY_MS(50);
			continue;
		case 0xfd:
			RTWN_DELAY_MS(5);
			continue;
		case 0xfc:
			RTWN_DELAY_MS(1);
			continue;
		case 0xfb:
			RTWN_DELAY_US(50);
			continue;
		case 0xfa:
			RTWN_DELAY_US(5);
			continue;
		case 0xf9:
			RTWN_DELAY_US(1);
			continue;
		default:
			break;
		}

		if (rtwn_rf_write_8188e(rd, wr, ctx, 0, addr,
		    prog->vals[j]) == 0) {
			n++;
		}
		RTWN_DELAY_US(5);
	}

	/* Kembalikan tipe RF_ENV. */
	rd32(rd, ctx, R92C_FPGA0_RFIFACESW(0), &reg);
	reg &= ~0x10u;
	reg |= type;
	wr32(rd, wr, ctx, R92C_FPGA0_RFIFACESW(0), reg);

	return n;
}

/* ── 4. Konfigurasi inti ────────────────────────────────────────────── */

/*
 * Agregasi RX USB (urtwn_aggr_init).
 *
 * Tanpa ini chip tidak mengirim paket RX lewat bulk IN secara utuh
 * (beberapa paket digabung, dan tanpa RXDMA_AGG_EN ambangnya salah).
 */
static void
rtwn_aggr_init_8188e(rtwn_read_fn rd, rtwn_write_fn wr, void *ctx)
{
	uint32_t reg = 0;

	/* 8188E: ndesc=1, dmasize=48 halaman, timing=4. */
	if (rd32(rd, ctx, R92C_TDECTRL, &reg) == 0) {
		reg &= ~(uint32_t)R92C_TDECTRL_BLK_DESC_NUM_M;
		reg |= ((uint32_t)1 << R92C_TDECTRL_BLK_DESC_NUM_S) &
		    (uint32_t)R92C_TDECTRL_BLK_DESC_NUM_M;
		wr32(rd, wr, ctx, R92C_TDECTRL, reg);
	}

	/* Rx aggregation. */
	{
		uint8_t v = 0;
		if (rd(ctx, R92C_TRXDMA_CTRL, &v, 1) == 0) {
			wr8(rd, wr, ctx, R92C_TRXDMA_CTRL,
			    (uint8_t)(v | R92C_TRXDMA_CTRL_RXDMA_AGG_EN));
		}
	}

	wr8(rd, wr, ctx, R92C_RXDMA_AGG_PG_TH, 48);
	wr8(rd, wr, ctx, (uint16_t)(R92C_RXDMA_AGG_PG_TH + 1), 4);

	/* Drop bulk-out yang tidak benar. */
	if (rd32(rd, ctx, R92C_TXDMA_OFFSET_CHK, &reg) == 0) {
		wr32(rd, wr, ctx, R92C_TXDMA_OFFSET_CHK,
		    reg | R92C_TXDMA_OFFSET_CHK_DROP_DATA_EN);
	}
}

int
rtwn_core_config_8188e(rtwn_read_fn rd, rtwn_write_fn wr, void *ctx,
    const uint8_t mac[6])
{
	uint16_t v16;
	uint32_t reg;
	uint8_t m;
	int i;

	/* Ukuran "driver info" RX (4 * 8 = 32 byte PHY status). */
	wr8(rd, wr, ctx, R92C_RX_DRVINFO_SZ, 4);

	/* Alamat MAC. */
	if (mac != NULL) {
		for (i = 0; i < 6; i++) {
			wr8(rd, wr, ctx, (uint16_t)(R92C_MACID + i), mac[i]);
		}
	}

	/* Mode station (infra). */
	wr8(rd, wr, ctx, R92C_MSR, R92C_MSR_NETTYPE_INFRA);

	/* Rx filter: terima semua yang relevan (mgmt, data, control). */
	wr32(rd, wr, ctx, R92C_RCR,
	    R92C_RCR_AAP | R92C_RCR_APM | R92C_RCR_AM | R92C_RCR_AB |
	    R92C_RCR_ADF | R92C_RCR_ACF | R92C_RCR_AMF |
	    R92C_RCR_APP_ICV | R92C_RCR_HTC_LOC_CTRL |
	    R92C_RCR_APP_MIC | R92C_RCR_APP_PHYSTS);
	wr32(rd, wr, ctx, R92C_MAR + 0, 0xffffffffu);
	wr32(rd, wr, ctx, R92C_MAR + 4, 0xffffffffu);
	wr16(rd, wr, ctx, R92C_RXFLTMAP0, 0xffff);
	wr16(rd, wr, ctx, R92C_RXFLTMAP1, 0xffff);
	wr16(rd, wr, ctx, R92C_RXFLTMAP2, 0xffff);

	/* Semua rate untuk respons/ACK. */
	if (rd32(rd, ctx, R92C_RRSR, &reg) == 0) {
		reg &= ~(uint32_t)R92C_RRSR_RATE_BITMAP_M;
		reg |= (uint32_t)R92C_RRSR_RATE_ALL;
		wr32(rd, wr, ctx, R92C_RRSR, reg);
	}

	/* Retry limit (USB memakai 0x30). */
	wr16(rd, wr, ctx, R92C_RL,
	    (uint16_t)((0x30 << R92C_RL_SRL_S) | (0x30 << R92C_RL_LRL_S)));

	/* EDCA / SIFS minimal (rtwn_edca_init). */
	wr16(rd, wr, ctx, R92C_SPEC_SIFS, 0x100a);
	wr16(rd, wr, ctx, R92C_MAC_SPEC_SIFS, 0x100a);
	wr16(rd, wr, ctx, R92C_SIFS_CCK, 0x100a);
	wr16(rd, wr, ctx, R92C_SIFS_OFDM, 0x100a);
	wr16(rd, wr, ctx, R92C_RESP_SIFS_CCK, 0x100a);
	wr16(rd, wr, ctx, R92C_RESP_SIFS_OFDM, 0x100a);
	wr32(rd, wr, ctx, R92C_EDCA_RANDOM_GEN, 0x12345678u);

	/* AMPDU retry baru + ACK timeout. */
	if (rd(ctx, R92C_FWHW_TXQ_CTRL, &m, 1) == 0) {
		wr8(rd, wr, ctx, R92C_FWHW_TXQ_CTRL,
		    (uint8_t)(m | R92C_FWHW_TXQ_CTRL_AMPDU_RTY_NEW));
	}
	wr8(rd, wr, ctx, R92C_ACKTO, 0x40);

	/* Beacon parameters (wajib walau mode STA). */
	wr16(rd, wr, ctx, R92C_BCN_CTRL,
	    (uint16_t)((R92C_BCN_CTRL_DIS_TSF_UDT0 << 8) |
	    R92C_BCN_CTRL_DIS_TSF_UDT0));
	wr16(rd, wr, ctx, R92C_TBTT_PROHIBIT, 0x6404);
	wr8(rd, wr, ctx, R92C_DRVERLYINT, R92C_DRVERLYINT_INIT_TIME);
	wr8(rd, wr, ctx, R92C_BCNDMATIM, R92C_BCNDMATIM_INIT_TIME);
	wr16(rd, wr, ctx, R92C_BCNTCFG, 0x660f);

	/* Agregasi USB. */
	rtwn_aggr_init_8188e(rd, wr, ctx);

	/* TX/RX enable. */
	if (rd16(rd, ctx, R92C_CR, &v16) == 0) {
		wr16(rd, wr, ctx, R92C_CR,
		    (uint16_t)(v16 | R92C_CR_MACTXEN | R92C_CR_MACRXEN));
	}

	/* CCK + OFDM aktif. */
	if (rd32(rd, ctx, R92C_FPGA0_RFMOD, &reg) == 0) {
		reg |= R92C_RFMOD_CCK_EN;
		wr32(rd, wr, ctx, R92C_FPGA0_RFMOD, reg);
		reg |= R92C_RFMOD_OFDM_EN;
		wr32(rd, wr, ctx, R92C_FPGA0_RFMOD, reg);
	}

	/*
	 * Enkripsi: untuk software crypto (net80211 CCMP), matikan
	 * engine HW (SECCFG=0) agar tidak mencoba enkripsi ganda atau
	 * merusak mbuf karena tabel CAM hardware belum diprogram.
	 */
	wr16(rd, wr, ctx, R92C_SECCFG, 0x0000);

	/* Hardware sequence numbering. */
	wr8(rd, wr, ctx, R92C_HWSEQ_CTRL, 0xff);

	/* Buka semua antrean TX. */
	wr8(rd, wr, ctx, R92C_TXPAUSE, 0x00);

	/* TX report (AMRR / diagnostik). */
	if (rd(ctx, R88E_TX_RPT_CTRL, &m, 1) == 0) {
		wr8(rd, wr, ctx, R88E_TX_RPT_CTRL,
		    (uint8_t)(m | R88E_TX_RPT_CTRL_EN));
	}

	return 0;
}
