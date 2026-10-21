# RTL8188EU Airport — Driver Wi-Fi native (IO80211) untuk macOS

Membuat **Wi-Fi native (menu Wi-Fi macOS, tanpa aplikasi tambahan)** untuk adapter USB
**TP-Link RTL8188EUS** (`2357:010c`) yang terpasang di Hackintosh ini.

Target akhir: adapter USB Realtek 2,4 GHz tampil sebagai interface `IO80211` biasa,
sehingga `CoreWLAN` / `airportd` yang menangani scan, association, WPA2, dan DHCP —
tanpa `StatusBarApp`, tanpa `RtWlanHelper`, tanpa `wpa_supplicant` Realtek.

> **Status: DIJEDA (21 Okt 2026).** Driver eksperimental sudah **dihapus** dari
> OpenCore dan mesin dikembalikan ke kondisi semula (driver vendor Realtek +
> aplikasinya aktif kembali).
> Semua temuan, kronologi, dan aturan yang lahir darinya ada di
> **[`docs/HANDOVER.md`](docs/HANDOVER.md)** — baca itu dulu.
> Rincian M1: [`docs/milestone-m1.md`](docs/milestone-m1.md).

---

## 1. Kenapa proyek ini mungkin

Temuan kunci dari riset awal:

| Fakta | Sumber | Implikasi |
|---|---|---|
| `product TPLINK RTL8188EUS 0x010c` | `openbsd/src` → `sys/dev/usb/usbdevs` (baris 4551) | USB ID kita **persis** dikenal OpenBSD |
| `URTWN_DEV_8188EU(TPLINK, RTL8188EUS)` | `openbsd/src` → `sys/dev/usb/if_urtwn.c` (baris 332) | Chip kita **sudah didukung** driver `urtwn` |
| Lisensi `urtwn` + `net80211` = **ISC** | OpenBSD | Boleh dipakai, bahkan untuk penggunaan komersial |
| `net80211` OpenBSD sudah diport ke macOS | `itlwm` → `itl80211/openbsd/net80211` (34 file) | Kita **tidak** perlu port stack 802.11 dari nol |
| Frontend IO80211 sudah ada | `laobamac/itlwm` → `AirportItlwm/` (GPL-2.0) | Pola "AirportItlwm" bisa langsung ditiru |

Jadi bahan bakunya: **OpenBSD `urtwn` (USB+RF+firmware+EFUSE)** +
**`net80211` (state machine 802.11)** + **frontend IO80211 (Bridge ke CoreWLAN)**.
Yang belum ada dan harus kita tulis sendiri: **lapisan transport USB** (OpenBSD `usbd_*`
→ macOS `IOUSBHostPipe`) dan **adaptasi frontend**.

---

## 2. Peta repositori

```
rtl8188eu-airport/
├── docs/
│   ├── references.md        # katalog referensi + tautan (60+ entri)
│   ├── architecture.md      # desain lapisan & alur data
│   ├── roadmap.md           # milestone M0–M7, kriteria selesai, go/no-go
│   ├── porting-notes.md     # daftar API OpenBSD → yang perlu di-replace
│   ├── testing.md           # setup debug kernel, kdp, konflik kext
│   ├── vendor-driver-notes.md  # hasil reverse engineering stack Realtek bawaan
│   └── legal.md             # lisensi & implikasi distribusi
├── firmware/                # rtl8188eufw.bin + checksum
├── scripts/                 # fetch upstream, build, load, log, cek device
└── src/
    ├── m0-hello/            # kext minimal (M0): binding + dump properti USB
    ├── urtwn/               # placeholder: port OpenBSD if_urtwn.c + rtwn.c
    ├── net80211/            # placeholder: itl80211 dari itlwm
    ├── airport/             # placeholder: frontend IO80211
    └── usb/                 # placeholder: shim usbd_* → IOUSBHostPipe
```

---

## 3. Arsitektur (ringkas)

```
        CoreWLAN / menu Wi-Fi / airportd  (BUILT-IN macOS)
                        │
                        │  IO80211 KPI (API privat Apple)
                        ▼
┌───────────────────────────────────────────────────────────┐
│ src/airport/  — frontend IO80211                          │
│   IO80211Controller / IO80211Interface / Skywalk / STA IOCTL│
│   (adaptasi dari laobamac/itlwm — GPL-2.0)                 │
├───────────────────────────────────────────────────────────┤
│ src/net80211/ — state machine 802.11 (OpenBSD net80211)   │
│   scan / auth / assoc / key / ratectl / radiotap  (ISC)   │
├───────────────────────────────────────────────────────────┤
│ src/urtwn/   — hardware Realtek (OpenBSD urtwn + rtwn)    │
│   USB attach, firmware, EFUSE, RF, TX/RX ring, AMRR      │
├───────────────────────────────────────────────────────────┤
│ src/usb/     — shim transport:  usbd_* → IOUSBHostPipe    │
└───────────────────────────────────────────────────────────┘
   firmware/rtl8188eufw.bin   (15.262 byte, sha256 2ff74315…0c4)
   Info.plist: IOProviderClass = IOUSBHostInterface,
               idVendor 9047 (0x2357), idProduct 268 (0x010C)
```

Detail lengkap: [`docs/architecture.md`](docs/architecture.md).

---

## 4. Mulai cepat

```bash
cd rtl8188eu-airport

# 1) unduh sumber upstream (itlwm, OpenBSD urtwn, AirPort-RTW, MacKernelSDK, firmware)
./scripts/fetch-upstream.sh

# 2) build kext minimal M0 (binding USB + log properti)
./scripts/build-m0.sh

# 3) cek device & konflik dengan kext vendor Realtek
./scripts/check-device.sh

# 4) (opsional) load M0 — PERINGATAN: matikan RtWlanU lebih dulu
./scripts/load-m0.sh

# 5) lihat log
./scripts/log-m0.sh
```

Kebutuhan toolchain (sudah terverifikasi di mesin ini):

* `clang` 17.0.0 (Command Line Tools) — **sudah ada**
* `MacKernelSDK` (acidanthera) — diunduh oleh `fetch-upstream.sh`
* Xcode lengkap **tidak wajib** untuk build berbasis Makefile; disarankan untuk
  debugging simbol & pembongkaran pbxproj proyek utama.

---

## 5. Batasan yang sudah diketahui (dITERIMA di awal)

* **2,4 GHz, 1×1, 802.11n, ~150 Mbps.** Tidak akan lebih.
* **Tanpa AWDL / AirDrop / Handoff.** Bukan karena driver kurang berkembang, tapi karena
  chipset & stack `urtwn` tidak mengimplementasikan AWDL. Project AirportItlwm
  (Intel) juga tidak mendukungnya — ini batasan chipset.
* **IO80211 = API privat Apple.** Rilis macOS baru bisa merusak; wajib pinning
  `MinKernel` / `MaxKernel` per build.
* **Tidak bisa jalan bersamaan dengan `RtWlanU`** pada device yang sama — harus
  disable kext vendor saat pengujian (lihat `docs/testing.md`).
* **Tidak ada native macOS driver USB Wi-Fi pun** yang ada di dunia; "native menu"
  selalu berarti menulis kext sendiri.
* **Ukuran ESP bukan lagi kendala** — ESP sekarang 512 MB (`EFI-BIG`, sisa 477 MB),
  lihat [`docs/efi-layout.md`](docs/efi-layout.md).

---

## 6. Peta dokumen

| Dokumen | Isi |
|---|---|
| **[`docs/HANDOVER.md`](docs/HANDOVER.md)** | **Rujukan tunggal: ringkasan, semua temuan, kronologi panic, cara lanjut** |
| [`docs/efi-layout.md`](docs/efi-layout.md) | Peta partisi & OpenCore (ESP 512 MB, sudah di-backup) |
| [`docs/milestone-m1.md`](docs/milestone-m1.md) | Detail M1: protocol USB vendor request, urutan init, diagnostik |
| [`docs/references.md`](docs/references.md) | Katalog referensi lengkap: driver, header, tool, dokumen, firmware |
| [`docs/architecture.md`](docs/architecture.md) | Desain lapisan, alur data, kontrak antarmuka, keputusan teknis |
| [`docs/roadmap.md`](docs/roadmap.md) | Milestone, kriteria selesai, estimasi, gerbang go/no-go |
| [`docs/porting-notes.md`](docs/porting-notes.md) | Rincian API OpenBSD yang harus di-replace (53 `usbd_*`, dst.) |
| [`docs/testing.md`](docs/testing.md) | Setup debug kernel, kdp, log, rescue plan |
| [`docs/vendor-driver-notes.md`](docs/vendor-driver-notes.md) | Hasil RE stack Realtek bawaan (sebagai *oracle*, bukan sumber kode) |
| [`docs/legal.md`](docs/legal.md) | Lisensi ISC/GPL/Realtek & implikasi distribusi |
