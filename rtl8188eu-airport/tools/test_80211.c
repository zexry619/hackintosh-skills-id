/*
 * test_80211.c — uji offline pembangun & parser frame 802.11.
 *
 * Menguji:
 *  1. Probe request: header MAC, element SSID, supported rates, DS param
 *  2. Beacon buatan → parser SSID & BSSID
 *  3. Kasus batas: SSID panjang, buffer kecil, frame terpotong
 */

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

#include "rtwn_80211.h"

static int fails = 0;

#define CHECK(cond, msg) do { \
	if (cond) { printf("  ✅ %s\n", msg); } \
	else { printf("  ❌ %s\n", msg); fails++; } \
} while (0)

static const uint8_t bcast[6] = { 0xff, 0xff, 0xff, 0xff, 0xff, 0xff };
static const uint8_t src_mac[6] = { 0x98, 0x03, 0x8e, 0x9e, 0xbc, 0x24 };

static void test_probe_request(void)
{
	uint8_t buf[128];
	size_t len = 0;
	char ssid[] = "MyWiFi";

	printf("\n── Probe request ──\n");

	CHECK(rtwn_build_probe_request(bcast, src_mac, ssid, 6, 6, buf,
	    sizeof(buf), &len), "frame terbangun");

	CHECK(len == 24 + 2 + 6 + 2 + 8 + 2 + 1,
	    "panjang frame = 45 (header 24 + SSID 8 + rates 10 + DS 3)");
	CHECK(buf[0] == 0x40 && buf[1] == 0x00, "frame control = 0x0040 (probe request)");
	CHECK(memcmp(buf + 4, bcast, 6) == 0, "addr1 = broadcast");
	CHECK(memcmp(buf + 10, src_mac, 6) == 0, "addr2 = source MAC");
	CHECK(buf[16] == 0xff && buf[21] == 0xff, "addr3 = broadcast");
	CHECK(buf[24] == 0x00 && buf[25] == 0x06, "element id SSID (0x00) + len 6");
	CHECK(memcmp(buf + 26, "MyWiFi", 6) == 0, "isi SSID benar");
	CHECK(buf[32] == 0x01 && buf[33] == 0x08, "element id Supported Rates (0x01) + len 8");
	CHECK(buf[42] == 0x03 && buf[43] == 0x01 && buf[44] == 6,
	    "element DS Parameter Set: channel 6");
}

static void test_probe_request_bounds(void)
{
	uint8_t buf[128];
	size_t len = 0;
	char ssid[33];

	printf("\n── Probe request: kasus batas ──\n");

	/* SSID 32 byte (maks) */
	memset(ssid, 'A', 32);
	CHECK(rtwn_build_probe_request(bcast, src_mac, ssid, 32, 1, buf,
	    sizeof(buf), &len), "SSID 32 byte diterima");
	CHECK(len == 24 + 2 + 32 + 2 + 8 + 2 + 1, "panjang = 71");

	/* SSID 33 byte → harus ditolak */
	CHECK(!rtwn_build_probe_request(bcast, src_mac, ssid, 33, 1, buf,
	    sizeof(buf), &len), "SSID 33 byte DITOLAK");

	/* SSID 0 byte (wildcard probe) */
	CHECK(rtwn_build_probe_request(bcast, src_mac, ssid, 0, 1, buf,
	    sizeof(buf), &len), "SSID kosong (wildcard) diterima");
	CHECK(len == 24 + 2 + 0 + 2 + 8 + 2 + 1, "panjang wildcard = 39");

	/* buffer terlalu kecil → ditolak */
	CHECK(!rtwn_build_probe_request(bcast, src_mac, ssid, 6, 1, buf,
	    40, &len), "buffer kecil DITOLAK");
}

static void test_beacon_parse(void)
{
	uint8_t beacon[128];
	size_t blen = 0;
	char ssid[33];
	uint8_t slen = 0;
	uint8_t bssid[6];
	const char *net = "TokoWiFi";
	size_t el;

	printf("\n── Beacon: parser SSID & BSSID ──\n");

	/*
	 * Beacon nyata: header 24 byte + field tetap 12 byte
	 * (timestamp 8, interval 2, capability 2) + elemen.
	 * Offset 36 inilah yang salah sebelumnya (dulu 24).
	 */
	memset(beacon, 0, sizeof(beacon));
	beacon[0] = 0x80;		/* mgmt / beacon */
	beacon[1] = 0x00;
	memcpy(beacon + 4, bcast, 6);
	memcpy(beacon + 10, src_mac, 6);
	memcpy(beacon + 16, src_mac, 6);	/* BSSID = src */
	beacon[32] = 0x64;		/* beacon interval 100 */
	beacon[34] = 0x31;		/* capability: ESS */
	beacon[35] = 0x04;
	el = 36;
	beacon[el++] = 0x00;		/* SSID element */
	beacon[el++] = (uint8_t)strlen(net);
	memcpy(beacon + el, net, strlen(net));
	el += strlen(net);
	beacon[el++] = 0x01;		/* Supported rates */
	beacon[el++] = 0x04;
	beacon[el++] = 0x82; beacon[el++] = 0x84;
	beacon[el++] = 0x8b; beacon[el++] = 0x96;
	blen = el;

	CHECK(rtwn_parse_ssid(beacon, blen, ssid, &slen), "SSID ditemukan");
	CHECK(slen == strlen(net) && strcmp(ssid, net) == 0, "isi SSID benar");
	CHECK(rtwn_parse_bssid(beacon, blen, bssid), "BSSID diambil");
	CHECK(memcmp(bssid, src_mac, 6) == 0, "BSSID benar");

	/* Probe response: layout fixed 12 byte sama seperti beacon. */
	beacon[0] = 0x50;
	CHECK(rtwn_parse_ssid(beacon, blen, ssid, &slen), "probe response: SSID ditemukan");
	CHECK(slen == strlen(net) && strcmp(ssid, net) == 0,
	    "probe response: isi SSID benar");
}

static void test_probe_request_parse(void)
{
	uint8_t buf[128];
	size_t len = 0;
	char ssid[33];
	uint8_t slen = 0;

	printf("\n── Probe request: parser (tanpa field tetap) ──\n");

	CHECK(rtwn_build_probe_request(bcast, src_mac, "ScanMe", 6, 1, buf,
	    sizeof(buf), &len), "frame terbangun");
	CHECK(rtwn_parse_ssid(buf, len, ssid, &slen),
	    "SSID dibaca dari probe request (body mulai offset 24)");
	CHECK(slen == 6 && strcmp(ssid, "ScanMe") == 0, "isi SSID benar");
}

static void test_parse_edges(void)
{
	uint8_t beacon[96];
	char ssid[33];
	uint8_t slen = 0;

	printf("\n── Beacon: kasus batas ──\n");

	memset(beacon, 0, sizeof(beacon));
	beacon[0] = 0x80;

	/* frame terlalu pendek */
	CHECK(!rtwn_parse_ssid(beacon, 10, ssid, &slen), "frame pendek DITOLAK");

	/* element terpotong: SSID klaim 32 byte, frame cuma 40 */
	beacon[36] = 0x00;
	beacon[37] = 0x20;
	CHECK(!rtwn_parse_ssid(beacon, 40, ssid, &slen),
	    "element terpotong DITOLAK");

	/* bukan frame management → ditolak */
	beacon[0] = 0x08;		/* type = data */
	CHECK(!rtwn_parse_ssid(beacon, 60, ssid, &slen), "frame non-management DITOLAK");

	/* tanpa SSID → ditolak (tidak ada elemen 0x00) */
	beacon[0] = 0x80;
	beacon[36] = 0x01;		/* supported rates, bukan SSID */
	beacon[37] = 0x02;
	beacon[38] = 0x82;
	beacon[39] = 0x84;
	CHECK(!rtwn_parse_ssid(beacon, 40, ssid, &slen), "tanpa SSID → tidak ditemukan");

	/* SSID tersembunyi (length 0) → dianggap valid, panjang 0 */
	beacon[36] = 0x00;
	beacon[37] = 0x00;
	CHECK(rtwn_parse_ssid(beacon, 40, ssid, &slen), "SSID hidden diterima");
	CHECK(slen == 0, "SSID hidden panjang 0");
}

int main(void)
{
	printf("══ Test frame 802.11 (M2) ══\n");

	test_probe_request();
	test_probe_request_bounds();
	test_beacon_parse();
	test_probe_request_parse();
	test_parse_edges();

	printf("\n%s\n", fails == 0 ? "✅ semua uji lulus" : "❌ ada kegagalan");
	return fails == 0 ? 0 : 1;
}
