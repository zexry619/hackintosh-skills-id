# `src/net80211/` — Layer 3: state machine 802.11

Port **OpenBSD net80211** ke Darwin, diambil dari `itlwm`:

```
upstream/itlwm/itl80211/openbsd/net80211/   → 34 file
upstream/itlwm/itl80211/compat.{h,cpp}      → shim BSD→kernel
```

## Kenapa tidak port dari nol

`net80211` adalah bagian paling rumit dari driver Wi-Fi: state machine
AUTH/ASSOC/REASSOC, roaming, 4-way handoff, key management, rate control, dan
regulatory domain. Port yang sudah jadi (itlwm) Behavior-nya sudah diverifikasi
bertahun-tahun di AirportItlwm.

## Yang harus dicek saat integrasi

`urtwn` memanggil API net80211 berikut — pastikan **semua** tersedia di
`itl80211` versi yang dipakai:

```
ieee80211_node            ieee80211_frame           ieee80211_key
ieee80211_state           ieee80211_release_node    ieee80211_inputm
ieee80211_has_qos         ieee80211_get_qos         ieee80211_get_hdrlen
ieee80211_up_to_ac        ieee80211_set_link_state  ieee80211_set_key
ieee80211_delete_key      ieee80211_new_state       ieee80211_get_txkey
ieee80211_get_rxkey       ieee80211_find_rxnode     ieee80211_encrypt
ieee80211_rxinfo          ieee80211_radiotap_header ieee80211_amrr*
```

Kalau ada yang hilang, tambahkan dari `openbsd/src/sys/net80211/` (ISC) — beware
perbedaan versi net80211 OpenBSD vs yang dipakai itlwm.

## Titik integrasi utama

| Kontrak | Side | File |
|---|---|---|
| `ieee80211_ioctl()` | driver → stack | `ieee80211_ioctl.c` |
| `struct ieee80211com` | driver ↔ stack | `ieee80211_var.h` |
| Radiotap RX/TX | driver ↔ stack | `ieee80211_radiotap.h` |
| AMRR (rate control) | driver ↔ stack | `ieee80211_amrr.{c,h}` |

## Lisensi

ISC (asal OpenBSD). Modifikasi itlwm sendiri GPL-2.0 → hasil akhir proyek GPL-2.0.
