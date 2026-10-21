# M3 & M4 — Integrasi net80211 & Frontend IO80211

Tanggal: 22 Okt 2026 · Sumber: `laobamac/itlwm` (AirportItlwm) + `openbsd/src` (urtwn/rtwn)

---

## 1. Arsitektur itlwm (yang kita tiru)

```
┌──────────────────────────────────────────────────────────────┐
│ AirportItlwm : public IO80211Controller     ← frontend M4    │
│   AirportItlwmInterface  : public IO80211Interface            │
│   AirportItlwmSkywalkInterface (jalur data modern)            │
│   AirportSTAIOCTL / AirportVirtualIOCTL / AirportAWDL        │
│        ▲                                                        │
│        │  HANYA lewat 3 interface:                             │
│        │   ItlHalService / ItlDriverInfo / ItlDriverController │
├──────────────────────────────────────────────────────────────┤
│ itlwm : public IOEthernetController         ← driver M3      │
│   net80211 (itl80211) → struct ieee80211com                   │
│   ieee80211_ifattach(&ic.ic_if, this)                        │
├──────────────────────────────────────────────────────────────┤
│ ItlIwx / ItlIwn                            ← driver chip     │
│   ItlHalService + ItlDriverInfo + ItlDriverController         │
│   + hardware (PCI, Intel)                                     │
└──────────────────────────────────────────────────────────────┘
```

**Kunci:** frontend AirportItlwm **tidak** tahu-menahu soal chip. Ia hanya
bicara ke `ItlHalService`. Jadi M4 = "ganti driver chip Intel dengan driver chip
Realtek USB", dan frontendnya nyaris utuh.

---

## 2. Yang sudah ada di repo kita

| File | Isi | Status |
|---|---|---|
| `src/driver/UsbBackend.{hpp,cpp}` | Pembungkus USB modern: claim interface, pipe bulk IN/OUT, transfer asinkron, Xfer TX/RX | ✅ **kompilasi & linked** |
| `src/driver/ItlRtl8188E.{hpp,cpp}` | Implementasi `ItlHalService` + `ItlDriverInfo` + `ItlDriverController` untuk 8188E; memuat instance `struct ieee80211com` | ✅ **kompilasi & linked** |
| `src/urtwn/rtwn_seq*.c` | Logika M1 portabel (EFUSE/power-on/LLT/firmware) | ✅ + unit test |
| `src/urtwn/rtwn_usb.{h,c}` | Descriptor TX/RX + ring TX (portabel) | ✅ + unit test |
| `src/usb/usb_compat.{h,cpp}` | Transport USB kernel + bulk pipe | ✅ |

Link build sudah mencakup include path itlwm:
`-I upstream/itlwm/include`, `.../include/HAL`, `.../itl80211`,
`.../itl80211/linux`, `.../itl80211/openbsd`, `.../itl80211/openbsd/net80211`.

---

## 3. Yang MASIH perlu ditulis (M3/M4 bagian inti)

### 3.1 M3 — glue net80211 ( estimasi 1.500–2.500 baris)

Butuh instantiate `struct ieee80211com` & mengisi ops-nya, Persis seperti
OpenBSD `rtwn.c` tapi untuk itl80211 (Darwin):

| net80211 op | Sumber OpenBSD | Implementasi 8188E |
|---|---|---|
| `ic_newstate` | `rtwn_newstate` (rtwn.c:1059) | power on/off sesuai state |
| `ic_send_mgmt` | — | kirim frame mgmt via bulk TX |
| `ic_recv_mgmt` | — | terima frame mgmt dari bulk RX |
| `ic_updateslot` | `rtwn_updateslot` (rtwn.c:1270) | slot time (BE/11b) |
| `ic_updateedca` | `rtwn_updatededca` (rtwn.c:1284) | parameter EDCA |
| `ic_set_key` | `rtwn_set_key` (rtwn.c:1336) | set key WEP/WPA/TKIP/CCMP |
| `ic_delete_key` | `rtwn_delete_key` (rtwn.c:1395) | hapus key |
| `ic_ra_init` | `rtwn_ra_init` (rtwn.c:785) | inisialisasi rate control (AMRR) |
| `ic_node_alloc` | `rtwn_node_alloc` | alokasi node |
| `ic_scan` / `ic_bgscan` | `rtwn_next_scan` | scan + probe request |
| `ic_tx` (start/stop) | `rtwn_start` (rtwn.c:1548) | TX queue & descriptor |
| `ic_ampdu_*` | — | opsional (agregasi) |
| `ic_set_txpower` | `rtwn_write_txpower` | set TX power |

Semua fungsi hardware di atas **sudah ada** di turunan OpenBSD kita
(`src/urtwn/rtwn_m1.cpp`) dalam bentuk BSD (`struct ifnet`, `mbuf`,
`timeout_add`). Yang perlu dilakukan: adaptasi ke API itl80211
(`struct _ifnet`, `mbuf_t`, `ieee80211_ifattach`).

### 3.2 M4 — adaptasi frontend

| Yang diubah | Detail |
|---|---|
| `AirportItlwm.cpp` | `IOPCIEDeviceWrapper` → `UsbBackend` (kita sudah punya) |
| `AirportItlwmInterface.cpp` | `inputPacket()` → teruskan frame dari bulk RX ke CoreWLAN |
| `AirportItlwmSkywalkInterface.cpp` | jalur data modern (opsional, bisa dilewati dulu) |
| Pencarian HAL service | `itlwm.cpp` mencari `ItlIwx::iwx_match(device)` → jadi "cari device USB 2357:010c" |

---

## 4. Urutan pengerjaan yang aman

> Penting: **jangan tulis 2.000 baris net80211 glue sebelum M1/M2 tervalidasi.**
>(net80211 bergantung pada perilaku chip nyata: apakah firmware upload
> berhasil, apakah DMA ring jalan, apakah frame RX masuk dengan format yang
> diharapkan.)

Urutan:

1. **M1** — chip hidup, MAC terbaca, firmware terupload  ← reboot + probe/kext
2. **M2** — bulk TX/RX: kirim probe request, terima beacon, baca SSID
3. **M3a** — `ieee80211com` dengan `ic_scan` minimal (scan via net80211)
4. **M3b** — join/assoc + key (WPA2)
5. **M4** — sambungkan frontend AirportItlwm → interface IO80211 → **menu Wi-Fi native**

---

## 5. Detail penting yang sudah terverifikasi

* `ieee80211_ifattach(struct _ifnet *, IOEthernetController *)` — driver M3 harus
  turunan **IOEthernetController** (bukan IOService).
* `ieee80211_media_init(struct _ifnet *)`.
* Frontend menanyakan ke HAL service: `attach`, `detach`, `enable`, `disable`,
  `getDriverInfo()->getTxQueueSize()/getFirmwareName()/getFirmwareVersion()/
  getBSSNoise()/getFirmwareCountryCode()/getTxNSS()/supportedFeatures()`,
  `getDriverController()->setMulticastList()`.
* `ItlHalService` turun dari `OSObject` → harus pakai `OSDeclareDefaultStructors`
  + `init()` (pola `ItlIwx`).
* Header net80211 itlwm butuh include path: `itl80211`, `itl80211/linux`,
  `itl80211/openbsd`, `itl80211/openbsd/net80211`.
* Kernel tidak punya `<vector>` → memakai array statis.
* Ekspor simbol wajib: `ld -kext -exported_symbols_list` (daftar dari
  `nm -g <*.o>`, kolom `T`) — tanpa itu KC builder gagal bind.
* Header C yang dipakai C++ **wajib** dibungkus `extern "C"`.
