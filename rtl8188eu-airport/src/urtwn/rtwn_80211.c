/*
 * rtwn_80211.c — pembangun & parser frame 802.11 (bagian M2).
 *
 * Untuk scan, kita butuh:
 *   - membangun Probe Request (management frame, type 0x40) berisi SSID
 *   - mem-parsing Beacon/Probe Response untuk ambil SSID & BSSID
 *
 * Format frame 802.11 (header MAC):
 *   offset 0 : frame control (2 byte, little endian)
 *   offset 2 : duration (2 byte)
 *   offset 4 : address 1 (dest)      6 byte
 *   offset 10: address 2 (source)     6 byte
 *   offset 16: address 3 (BSSID)      6 byte
 *   offset 22: sequence control (2 byte)
 *   offset 24: [frame body]
 *
 * BIT DI BODY:
 *   +0  : element id
 *   +1  : length
 *   +2..: data
 *
 * Frame control untuk Probe Request:
 *   type 0b10 (management), subtype 0b0000 (probe request)
 *   → FC = 0x0040  (little endian: 0x40, 0x00)
 */

#include "rtwn_80211.h"

#include <string.h>

/*
 * Bangun Probe Request.
 *
 * @dst, @src : alamat MAC 6 byte
 * @ssid      : nama jaringan (maks 32 byte)
 * @ssid_len  : panjang SSID
 * @out       : buffer keluaran (min 40 byte)
 * @out_len   : panjang frame yang dihasilkan
 *
 * Body yang ditambahkan:
 *   - SSID element (id 0x00)
 *   - Supported rates (id 0x01): 1, 2, 5.5, 11, 18, 24, 36, 54 Mb/s
 *   - DS parameter set (id 0x03): channel 1
 *
 * Return true kalau berhasil.
 */
bool
rtwn_build_probe_request(const uint8_t dst[6], const uint8_t src[6],
    const char *ssid, uint8_t ssid_len, uint8_t chan, uint8_t *out,
    size_t out_cap, size_t *out_len)
{
	size_t n = 0;
	size_t body_start;

	if (!dst || !src || !ssid || !out || !out_len) {
		return false;
	}
	if (ssid_len > 32) {
		return false;
	}
	/* header 24 + SSID(2+32) + rates(2+8) + DS(2+1) = 71 */
	if (out_cap < 72) {
		return false;
	}

	memset(out, 0, out_cap);

	/* ── header MAC ── */
	out[n++] = 0x40;		/* frame control: mgmt / probe request */
	out[n++] = 0x00;
	out[n++] = 0x00;		/* duration */
	out[n++] = 0x00;
	memcpy(out + n, dst, 6);	n += 6;	/* addr 1 = broadcast */
	memcpy(out + n, src, 6);	n += 6;	/* addr 2 = source */
	memset(out + n, 0xff, 6);	n += 6;	/* addr 3 = broadcast */
	out[n++] = 0x00;		/* seq control hi */
	out[n++] = 0x00;		/* seq control lo */

	body_start = n;

	/* ── SSID element ── */
	out[n++] = 0x00;		/* element id: SSID */
	out[n++] = ssid_len;
	if (ssid_len) {
		memcpy(out + n, ssid, ssid_len);
		n += ssid_len;
	}

	/* ── Supported rates ── */
	out[n++] = 0x01;		/* element id: supported rates */
	out[n++] = 0x08;
	{
		static const uint8_t rates[8] = {
			0x82,	/* 1 Mb/s  (basic)   */
			0x84,	/* 2 Mb/s             */
			0x8b,	/* 5.5 Mb/s           */
			0x96,	/* 11 Mb/s            */
			0x24,	/* 18 Mb/s            */
			0x30,	/* 24 Mb/s            */
			0x48,	/* 36 Mb/s            */
			0x6c	/* 54 Mb/s            */
		};
		memcpy(out + n, rates, sizeof(rates));
		n += sizeof(rates);
	}

	/* ── DS parameter set (channel) ── */
	out[n++] = 0x03;		/* element id: DS parameter set */
	out[n++] = 0x01;
	out[n++] = chan;

	/* isi sisa body dengan 0 (padding) */
	(void)body_start;

	*out_len = n;
	return true;
}

/*
 * Ambil SSID dari frame beacon / probe response.
 *
 * @frame     : pointer ke frame 802.11 (header MAC mulai dari byte 0)
 * @frame_len : panjang frame
 * @ssid_out  : buffer keluaran (min 33 byte)
 * @ssid_len  : panjang SSID yang ditemukan
 *
 * Return true kalau SSID ditemukan.
 */
bool
rtwn_parse_ssid(const uint8_t *frame, size_t frame_len, char *ssid_out,
    uint8_t *ssid_len)
{
	size_t n;
	size_t end;

	if (!frame || !ssid_out || !ssid_len) {
		return false;
	}
	if (frame_len < 24) {
		return false;
	}

	/* Frame control: type = management (bits 2..3 == 0) */
	if (((frame[0] >> 2) & 0x03) != 0) {
		return false;
	}

	n = 24;
	end = frame_len;

	while (n + 2 <= end) {
		uint8_t id = frame[n];
		uint8_t len = frame[n + 1];

		if (n + 2 + len > end) {
			break;		/* element terpotong → berhenti */
		}
		if (id == 0x00) {		/* SSID */
			if (len > 32) {
				return false;
			}
			memcpy(ssid_out, frame + n + 2, len);
			ssid_out[len] = 0;
			*ssid_len = len;
			return true;
		}
		n += 2 + len;
	}
	return false;
}

/*
 * Ambil BSSID (address 3) dari frame beacon/probe response.
 */
bool
rtwn_parse_bssid(const uint8_t *frame, size_t frame_len, uint8_t bssid[6])
{
	if (!frame || !bssid) {
		return false;
	}
	if (frame_len < 24) {
		return false;
	}
	memcpy(bssid, frame + 16, 6);
	return true;
}
