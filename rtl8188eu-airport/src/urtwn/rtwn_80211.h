/*
 * rtwn_80211.h — pembangun & parser frame 802.11 (M2).
 */

#ifndef RTL8188EU_RTWN_80211_H
#define RTL8188EU_RTWN_80211_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

/* Frame control: mgmt / probe request */
#define RTWN_FC_PROBE_REQ	0x0040
/* Frame control: mgmt / beacon */
#define RTWN_FC_BEACON		0x0080
/* Frame control: mgmt / probe response */
#define RTWN_FC_PROBE_RESP	0x0050

#define RTWN_80211_HDR_LEN	24
#define RTWN_80211_MAX_SSID	32

bool rtwn_build_probe_request(const uint8_t dst[6], const uint8_t src[6],
    const char *ssid, uint8_t ssid_len, uint8_t chan, uint8_t *out,
    size_t out_cap, size_t *out_len);

bool rtwn_parse_ssid(const uint8_t *frame, size_t frame_len, char *ssid_out,
    uint8_t *ssid_len);

bool rtwn_parse_bssid(const uint8_t *frame, size_t frame_len, uint8_t bssid[6]);

#endif /* RTL8188EU_RTWN_80211_H */
