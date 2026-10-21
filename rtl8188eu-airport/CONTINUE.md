# LANJUTKAN PROYEK INI — panduan cepat

**Status (22 Okt 2026, 04:20):** M1 **SELESAI** — chip 8188EUS hidup
(power-on + LLT/DMA + upload firmware 8051 + bulk pipe). Tanpa panic.
Sisa M1: MAC/xtal dari EFUSE masih `ff:ff:ff:ff:ff:ff` / `0xff`
( hopes: urutan baru "firmware → EFUSE" akan memperbaikinya).

**Commit:** `63d161a` — semua kode, docs, dan skrip tersimpan.

---

## 1. Peta folder

```
rtl8188eu-airport/
├── docs/
│   ├── HANDOVER.md            ← rujukan tunggal (baca ini dulu)
│   ├── audit-hardening.md     ← 40 temuan keamanan + perbaikannya
│   ├── init-sequence-8188e.md ← 42 langkah init vendor (dari RE)
│   ├── m3-m4-integration.md   ← peta net80211 yang harus ditulis
│   └── vendor-reverse.md      ← hasil decompilation Ghidra
├── src/
│   ├── urtwn/                 ← kode portabel (OpenBSD urtwn, ISC)
│   │   ├── rtwn_seq.c         ← init sequence + firmware loader
│   │   ├── rtwn_seq_efuse.c   ← jalur offload EFUSE
│   │   ├── rtwn_efuse_8188e.c ← jalur direct EFUSE (0x031/32/33/30)
│   │   ├── rtwn_flow.c        ← tabel flow power-on vendor
│   │   ├── rtwn_usb.c         ← descriptor TX/RX + ring TX
│   │   └── rtwn_platform*.c/h ← lapisan delay (kernel vs user space)
│   ├── usb/usb_compat.{h,cpp} ← shim USB (control transfer + bulk pipe)
│   └── driver/
│       ├── RTL8188EUM1.cpp    ← driver IOKit (M1 bring-up)
│       ├── UsbBackend.cpp     ← scaffolding M4
│       ├── ItlRtl8188E.cpp    ← scaffolding HAL service M4
│       ├── m1_mode.h          ← mode compile-time (M1_TEST_MODE)
│       └── Info.plist         ← personality 2357:010c
├── scripts/                   ← 28 skrip (lihat §4)
├── tools/                     ← probe & test offline
├── upstream/openbsd/          ← sumber urtwn asli (referensi)
├── upstream/itlwm/            ← net80211 + AirportItlwm (referensi)
└── vendor/MacKernelSDK/       ← header kernel macOS
```

---

## 2. Status mesin saat ini

| Item | Status |
|---|---|
| ESP kext | **TERPASANG** (varian UJI, mode `poweron`) |
| `Kernel→Add` | 12 entri (+1 = kext kita) |
| boot-args | `... -rtl8188eum1_mode=poweron` (mode sebenarnya = compile-time) |
| Driver vendor Realtek | **DIMATIKAN** → `/Library/Extensions.disabled-m1/` |
| Wi-Fi via dongle | **MATI** (sampai M1 selesai) |
| Internet | USB tethering (bridge0) — OK |
| LaunchDaemon | `com.zekri.rtwn-watch` aktif (capture marker 15 mnt) |

### ⛔ Kalau mau berhenti sekarang & kembali ke normal
```bash
sudo ./scripts/restore-test-esp.sh && reboot
```
→ kext keluar dari ESP, vendor Realtek kembali, Wi-Fi normal.

---

## 3. Ronde uji berikutnya (kalau lanjut)

```bash
# 1. build varian UJI dengan mode yang diinginkan
MODE=poweron ./scripts/build-m1.sh     # readonly(0) / poweron(1) / full(2)

# 2. test offline (WAJIB — build script tidak lagi menimpa varian UJI)
./scripts/run-tests.sh

# 3. pasang + matikan vendor
sudo env ALLOW_BOOT_INJECTION=1 MODE=poweron ./scripts/install-test-esp.sh

# 4. reboot → tunggu 60 dtk → colok-cabut dongle

# 5. baca hasil (LaunchDaemon tangkap otomatis)
cat logs/watch-*.log | tail -1
```

**PENTING:** `build-m1.sh` **hanya** membangun varian UJI kalau `MODE` diisi.
`run-tests.sh` memanggil `build-m1.sh` tanpa MODE → tidak boleh menimpa
varian UJI (bug yang sudah diperbaiki 22 Okt).

---

## 4. Skrip penting

| Skrip | Fungsi |
|---|---|
| `safe-test-window.sh` | jendela uji 1 perintah + rollback otomatis (tapi macOS 15 butuh reboot) |
| `install-test-esp.sh` | pasang kext UJI + mode + matikan vendor |
| `restore-test-esp.sh` | kembalikan ESP + vendor (perlu reboot) |
| `collect-m1.sh` | rangkum marker registry + Unified Log |
| `watch-m1.sh` | poll marker tiap 100 ms (dipakai LaunchDaemon) |
| `lint-locks.py` | cek keseimbangan lock/unlock (cegah PANIC #4) |
| `run-tests.sh` | test suite offline (4 kelompok test) |
| `vendor-off.sh` / `vendor-on.sh` | matikan/nyalakan driver vendor |

---

## 5. Peta pekerjaan yang tersisa

| Milestone | Isi | Status |
|---|---|---|
| **M1** | power-on + DMA + firmware + bulk pipe | ✅ (MAC dari EFUSE belum) |
| **M1c** | MAC + xtal dari EFUSE | ⏳ (offload harus jalan setelah firmware) |
| **M1d** | HAL init lengkap vendor (langkah #11–#42: RDG, InitHalDm, FW_InitializeHALVars, PHY_MACConfig, PHY_BBConfig, PHY_RFConfig8188E, InitQueueReservedPage, _InitTxBufferBoundary, …) | ⬜ **TERBESAR** |
| **M2** | bulk TX/RX: kirim probe request, terima beacon, baca SSID | ⬜ kode ada, belum tervalidasi |
| **M3a** | net80211 scan | ⬜ |
| **M3b** | net80211 join + WPA2 | ⬜ |
| **M4** | IO80211 interface → menu Wi-Fi native | ⬜ |

**Peta net80211** ada di `docs/m3-m4-integration.md`.

---

## 6. Aturan kernel (WAJIB dipatuhi)

| # | Aturan |
|---|---|
| A1 | Jangan pernah free buffer/context transfer USB — biarkan bocor (±100 B ≪ panic) |
| A2 | Jangan baca-balik property untuk menyusun log (release objek katalog = jalur crash) |
| A3 | Driver eksperimental tidak boleh melakukan traffic USB saat boot |
| A7 | Selalu pakai `IOMemoryDescriptor` untuk buffer I/O USB — jangan raw pointer |
| A11 | Objek dari `getNextObject()` milik collection — jangan `release()`, `retain()` dulu |
| A12 | Validasi panjang dari descriptor USB terhadap ukuran buffer nyata, di setiap lapisan |
| A13 | Di kernel "menunggu" = `IOSleep` (memblok thread), bukan `IODelay` (busy-wait) |
| A14 | Timeout harus bisa dibedakan dari data yang sah (0xff bukan penanda error) |
| A15 | Guard pembagian dengan nol di setiap modulo |
| A17 | Penanda "masih hidup" harus di heap, bukan di dalam objek yang dilindungi |
| A18 | `removeEventSource()` dari work loop SEBELUM `release()` |
| A19 | Jalur `start()` gagal harus melepas sendiri resource-nya |
| A20 | Jangan `kalloc` di bawah lock |
| A21 | Timebase Mach harus dibaca dari kernel |
| A22 | Setiap `IOLockUnlock` wajib didahului `IOLockLock` (lihat `lint-locks.py`) |
| A23 | Simpan pointer lock di variabel lokal saat mutex dibuat secara lazy |
| A24 | Setiap perubahan dari audit wajib_DIRECTOReview ulang terhadap diff-nya sendiri |

---

## 7. Kalau ada panic lagi

```bash
# 1. JANGAN sentuh device sebelum reboot (kext buggy tetap tinggal di kernel)
# 2. Setelah reboot:
sudo ./scripts/restore-test-esp.sh     # bersihkan ESP
ls -t /Library/Logs/DiagnosticReports/*.panic | head -1   # baca panic log
```
`kmutil unload` kext experimental hampir selalu ditolak
(*"kext is in use or retained"*) → **reboot satu-satunya cara**.
