# M4 — Integrasi IO80211/AirPort native macOS (22 Okt 2026)

Rujukan ini dikumpulkan dari **source driver nyata** yang sudah terbukti bekerja
di macOS Sequoia (15.x = target kita).

---

## 1. Driver referensi yang ditemukan

| Driver | Repo | Chip | macOS | Status |
|---|---|---|---|---|
| **AirPort_RTW88** 2.0.1 | `xnoah222/Airport_RTW88` | RTL88xx **PCIe** (8822BE/8822CE/8821CE) | Ventura 13.7.7 → Tahoe 26 | ✅ **native AirPort** |
| **AirPort_RTW89** | `FranciumOS-org/Airport_RTW89` | RTL89xx PCIe (8852AE/BE/CE, 8922AE…) | Ventura 13 → Tahoe 26 | ✅ native AirPort |
| **Realtek88LegacyAirport** 1.0.1 | `xnoah222/Realtek-AirPort-Family` | RTL88xx PCIe | Mojave–Big Sur (HS80211Family) | ✅ legacy AirPort |
| **AirportItlwm** | `OpenIntelWireless/itlwm` | Intel | Sonoma/Sequoia | ✅ native AirPort (udah di-vendor di proyek) |

**Sudah diunduh ke proyek ini:**
```
upstream/Airport_RTW88/AirPort_RTW88/
├── rtw88-stable/      ← Linux rtw88 (GPL-2.0), termasuk USB transport
└── Feixiao/           ← driver macOS native-AirPort (GPL-2.0 / BSD-3)
    ├── src/kext/      ← AirPortRTW88Kext.cpp, AirportRTW88Interface.hpp,
    │                     RTW88IEEE80211.cpp, RTW88HwOps.cpp, AWDL, dll
    ├── src/compat/    ← shim Linux→macOS ( termasuk linux/usb.h)
    └── MacKernelSDK/  ← header kernel macOS
```
Total **515.143 baris** C/H — referensi M4 terlengkap yang bisa kita dapat.

> ⚠️ `Feixiao` **PCIe only** — USB sengaja dikecualikan dari build-nya.
> Tapi **integrasi IO80211-nya persis yang kita butuh**, dan `rtw88-stable`
> memuat kode transport USB.

---

## 2. Struktur kext yang dipakai Airport_RTW88

Dari `Feixiao/AirPort_RTW88.kext/Contents/Info.plist`:

```xml
<key>CFBundleIdentifier</key>  <string>com.rtw88.airport</string>
<key>LSMinimumSystemVersion</key> <string>13.0</string>
<key>OSBundleLibraries</key>
<dict>
    <key>com.apple.iokit.IO80211FamilyLegacy</key> <string>12.0</string>
    <key>com.apple.iokit.IONetworkingFamily</key>  <string>3.4</string>
    <key>com.apple.iokit.IOPCIFamily</key>          <string>2.9</string>
    <key>com.apple.iokit.IOSkywalkFamily</key>       <string>1.0</string>
    <key>com.apple.kpi.bsd|iokit|libkern|mach|unsupported</key> <string>20.0.0</string>
</dict>
<key>IOKitPersonalities</key>
<dict>
  <key>AirPort_RTW88_8822BE</key>
  <dict>
    <key>CFBundleIdentifier</key> <string>com.rtw88.airport</string>
    <key>IOClass</key>            <string>AirportRTW88</string>
    <key>IOMatchCategory</key>    <string>IODefaultMatchCategory</string>
    <key>IOPCIMatch</key>         <string>0xB82210EC</string>   ← device|vendor
    <key>IOProbeScore</key>       <integer>5000</integer>
    <key>IOProviderClass</key>    <string>IOPCIDevice</string>
  </dict>
  ...
</dict>
```

**Untuk USB (chip kita)**, personality-nya jadi:

```xml
<key>RTL8188E_USB</key>
<dict>
  <key>CFBundleIdentifier</key> <string>io.github.zekri.RTL8188EUM1</string>
  <key>IOClass</key>            <string>AirportRTW8188E</string>
  <key>IOMatchCategory</key>    <string>IODefaultMatchCategory</string>
  <key>IOProviderClass</key>    <string>IOUSBHostInterface</string>
  <key>idVendor</key>           <integer>9047</integer>   <!-- 0x2357 -->
  <key>idProduct</key>          <integer>268</integer>    <!-- 0x010c -->
  <key>IOProbeScore</key>       <integer>5000</integer>
</dict>
```

---

## 3. Dua jalur M4 yang mungkin

### Jalur A — **stack modern** (seperti AirportItlwm) ⭐ REKOMENDASI

- Pakai `IO80211Family` (modern) — **sudah ada di macOS 15**, tidak perlu
  mengganti kext sistem.
- Template: `upstream/itlwm/AirportItlwm` (sudah di-vendor).
- Kerangka kerja kita sekarang persis ke arah ini.
- **Tidak perlu** `AMFIPass` / `IO80211FamilyLegacy` / blok `IOSkywalkFamily`.
- Risiko: lebih banyak kode net80211 yang harus ditulis/port.

### Jalur B — **stack legacy** (seperti AirPort_RTW88)

- Perlu: `IO80211FamilyLegacy.kext` (dari `Edwardwich/BCM-WIFI-Sequoia`),
  `AMFIPass.kext` (dari `kaoskinkae/AMFIPass`), `IOSkywalkFamily` **legacy**,
  dan **blok** `IOSkywalkFamily` native di OpenCore.
- Lebih sedikit kode yang ditulis (pakai framework Apple yang sudah jadi).
- Risiko: mengganti kext sistem jaringan → bisaefek samping ke seluruh sistem (AirPort
  internal, iCloud, Continuity) dan sering bikin boot bermasalah.

> **Rekomendasi: Jalur A.** Alasannya: tidak menyentuh kext sistem → risiko
> rendah, dan cocok dengan `itlwm` yang sudah terbukti jalan di Sequoia.

---

## 4. Peta file driver yang perlu diadaptasi (dari Feixiao/src/kext/)

| File | Peran | Yang perlu diubah |
|---|---|---|
| `AirportRTW88Kext.cpp` | loader **IO80211Family bundle** | ganti nama kelas & chip |
| `AirportRTW88.hpp` | kelas inti | port ke 8188E |
| `AirportRTW88Interface.hpp` | subclass **IO80211Interface** | ganti hw-ops |
| `RTW88IEEE80211.cpp` | lapisan IEEE 802.11 (scan/join/keys) | **paling besar**; ganti backend |
| `RTW88HwOps.cpp` | abstraksi hw (tx/rx/reg) | ganti ke `usb_compat` + `urtwn` |
| `RTW88PCIDevice.hpp` | device + power management | ganti ke USB |
| `RTW88AWDL*` | AWDL/P2P (eksperimental) | tidak diperlukan (chip 8188E tidak punya AWDL) |

**Perkiraan:** M4 ≈ **1.500–2.500 baris** (bukan 2.000+ dari nol — kita punya
temple siap).

---

## 5. Prasyarat untuk M4 (kalau nanti)

```
upstream/itlwm/AirportItlwm/            ← sudah ada (frontend IO80211 modern)
upstream/Airport_RTW88/.../Feixiao/     ← sudah ada (referensi Realtek + IO80211)
upstream/AirPort-RTW/                    ← sudah ada (referensi IO80211 lain)
```

Yang BELUM ada:
- `IO80211FamilyLegacy` & `AMFIPass` (hanya kalau pilih Jalur B)
-FW 8051 untuk chip (sudah ada: `firmware/rtl8188eufw.bin` + varian vendor)

---

## 6. Keterkaitan dengan rencana awal

Rencana awal kita: "port net80211 dari itlwm + AirportItlwm frontend".
**Tetap valid** — dan sekarang punya dua template tambahan yang sangat baik:

| Yang mau | Template terbaik |
|---|---|
| Integrasi IO80211 modern | `upstream/itlwm/AirportItlwm` |
| Integrasi IO80211 + hw-ops Realtek | `upstream/Airport_RTW88/.../Feixiao/src/kext/` |
| Lapisan IEEE 802.11 lengkap (scan/join/keys/RSN) | `Feixiao/src/kext/RTW88IEEE80211.cpp` |
| Transport USB | `src/usb/usb_compat.{h,cpp}` (kita sudah tulis!) |
| HAL chip 8188E | `src/urtwn/rtwn_seq.c` + `rtwn_mp_8188e.c` (baru!) |

**Temuan positif lain:** `Feixiao/src/compat/linux/usb.h` — ada shim USB Linux
di tree yang bisa jadi acuan untuk transport kita.

---

## 7. Lisensi

| Komponen | Lisensi | Cocok dengan GPL-2.0 kita? |
|---|---|---|
| Linux `rtw88` | GPL-2.0 | ✅ |
| `Feixiao` (AirPort_RTW88) | GPL-2.0 OR BSD-3-Clause | ✅ |
| OpenBSD `urtwn` (kita) | ISC | ✅ (boleh di dalam GPL) |
| `itlwm` / `AirportItlwm` | GPL-2.0 | ✅ |
| `MacKernelSDK` | Apple (headers) | ✅ (headers saja) |

Lihat `docs/legal.md`.
