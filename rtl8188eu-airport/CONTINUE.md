# LANJUTKAN PROYEK INI — panduan cepat

**Status (22 Okt 2026, malam):** **M4 KERANGKA KEXT SELESAI DI-BUILD.**
`RTL8188EAirport.kext` (IO80211 V2/Skywalk + net80211 + HAL 8188E) berhasil
kompilasi, link, dan sign. `kextutil -t` membuktikan semua simbol bind ke
IO80211Family/IOSkywalkFamily/IOUSBHostFamily — hanya kebijakan
*"not approved to load"* yang tersisa (diatasi injeksi OpenCore, seperti M1).
**Uji hardware belum dilakukan** (dongle tidak tercolok).

M1 (chip hidup) ✅ · M1c (MAC/xtal dari EFUSE) ✅ · M2 (scan) ✅ ·
**M4 (kext IO80211 utuh) ✅ build** · uji menu Wi-Fi ⏳ satu reboot.

> **Update 23 Okt 06:30 — M4 sudah terbukti di hardware.** `en2` terdaftar
> sebagai Wi-Fi (fw `rtl8188eufw 1.28`, kanal 1–14), scan + beacon + asosiasi
> WPA2 jalan (`RTL8188E-stage=state-run`, `mac=98:03:8e:9e:bc:24`).
> **Yang belum: DHCP** (`State: INIT`, `no server`) dan sinkronisasi status ke
> `airportd` (*not associated*). Daftar perbaikan + cara iterasi **tanpa
> reboot**: **[`docs/fix-plan.md`](docs/fix-plan.md)**.
>
> **Update 23 Okt 06:40 — F0 selesai, menunggu 1 reboot.** ESP sudah bersih:
> `RTL8188EAirport.kext` dihapus, `Kernel->Add` 12 → 11, `plutil -lint` OK,
> backup di `backup/EFI-pre-restore.20261023-062756.tar.gz`.
> `kmutil unload` ditolak (`kext is in use or retained`) selama kext masih
> dipegang interface — jadi reboot ini yang terakhir untuk urusan pasang-copot.
> Setelah reboot: dongle bebas →
> `sudo ./tools/rtwn_probe --join ZEKRI.NET --txnull`.
> Iterasi berikutnya: `./scripts/dev-loop-m4.sh` (hot-load, tanpa reboot).
> ⚠️ Driver vendor Realtek **tidak** kembali otomatis: `mkdir` di
> `/Library/Extensions` ditolak TCC. Wi-Fi harian sementara lewat USB
> tethering; kalau perlu vendor lagi, jalankan dari Terminal yang punya
> izin App Management.
>
> **Update 23 Okt 07:00 — koreksi penting: hot-load TIDAK mungkin.**
> LaunchDaemon sudah dicabut. `kmutil load -z -p` untuk kext ini selalu
> `Code=28 "requires a reboot"` (sudah dicoba: clear-staging, hapus entri
> AuxKC, binary beda). Kext yang bergantung `IO80211Family` hanya bisa
> masuk lewat **BootKC (injeksi OpenCore)** atau **AuxKC (saat boot)** —
> jadi **setiap perubahan binary tetap butuh satu reboot**.
> Kondisi mesin sekarang: ESP bersih, driver vendor Realtek dikembalikan ke
> `/Library/Extensions`, tidak ada kext zekri di AuxKC. Reboot → Wi-Fi
> vendor normal kembali.
> Untuk menguji driver native lagi: `ALLOW_BOOT_INJECTION=1 sudo
> ./scripts/install-m4-esp.sh` lalu reboot (satu paket perubahan per reboot).
>
> **Update 23 Okt 06:45 — perbaikan presisi.** Akar masalah yang diperbaiki:
> 8188EU memetakan endpoint USB → queue TX (0 VO/mgmt, 1 VI, 2 BE/BK), tapi
> driver hanya membuka satu bulk-out dan memakai QSEL=BE untuk data → frame
> data masuk queue mgmt dan tidak pernah keluar. Sekarang `bulkOpen()`
> membuka 3 pipe dan `sendFrame()` memilih pipe+QSEL per AC/TID; `txdw5`
> juga mengisi batas retry `0x0001ff00`. Diagnostik baru: `RTL8188E-stat`
> dan `RTL8188E-wcl` di ioreg (dibaca setelah reboot).

**Terobosan metode:** `tools/rtwn_probe` sekarang bisa membuka device dari
**user space** (API IOKit yang benar). Iterasi jadi hitungan detik —
**tanpa reboot, tanpa kernel, tanpa risiko panic**.

```bash
sudo ./tools/rtwn_probe --efuse-all     # MAC + diagnostik lengkap
sudo ./tools/rtwn_probe --full          # power-on + LLT + firmware
sudo ./tools/rtwn_probe --scan 1 13     # scan 2,4 GHz (M2)
sudo ./tools/rtwn_probe --peek 0x610 6  # baca register mentah
```

**Dua akar masalah yang diperbaiki hari ini:**
1. Reset 8051 memakai register chip lain (`0x093` = cabang `cardType 0x32`);
   8188E (`0x0e`) memakai `0x1c/0x1d/0x03`.
2. Parser EFUSE: `ri++` ganda + bit mask SET berarti **ABSENT (0 byte)**,
   bukan 1 byte.

**Audit pra-reboot selesai (tanpa hardware).** Bug kritis yang sudah
diperbaiki: `if_watchdog` NULL (panic 1 detik setelah Wi-Fi ON), tabel kanal
2,4 GHz kosong (scan tidak jalan), RX dimulai sebelum net80211 (`ic_bss`
NULL), RX di workloop USB (race/deadlock), `free()` tanpa `ifdetach`, offset
RX +2, RSSI palsu, scan tanpa jeda, dan rollback install script. Detail di
`docs/m4-airport-integration.md` §10.

**Langkah berikutnya:** **colok dongle 2357:010c dulu** (tanpa itu kext
tidak match), lalu uji satu reboot:
`ALLOW_BOOT_INJECTION=1 sudo ./scripts/install-m4-esp.sh` (otomatis membuang
M1 dari ESP), reboot, cek `kextstat | grep RTL8188EAirport` dan menu Wi-Fi.
Jalur scan sudah lengkap; asosiasi/WPA2 masih minimal (TX 1 Mb/s, HT mati,
belum rate control).

Risiko terbuka: dongle pernah lepas dari bus (`hardware connection lost`)
→ perlu batas TX power + quiesce sebelum uji berulang (lihat `docs/m2-scan.md` §5).

**Rujukan:** `docs/HANDOVER.md` §17 (M2) dan §18 (M4),
`docs/m4-airport-integration.md`, `docs/userspace-lab.md`,
`docs/re-8188e-efuse.md` §4b/§4c.

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
│   ├── airport/               ← frontend IO80211 V2 (salinan AirportItlwm)
│   │   ├── AirportItlwm.cpp   ← dipatch: PCI opsional, probe non-PCI
│   │   ├── IOPCIEDeviceWrapper.{hpp,cpp} ← wrapper IOUSBHostInterface
│   │   └── Info.plist         ← 2 personality (wrapper + frontend)
│   └── driver/
│       ├── RTL8188EUM1.cpp    ← driver IOKit (M1 bring-up)
│       ├── ItlRtl8188E.{hpp,cpp} ← HAL M4 (net80211, scan, TX/RX)
│       ├── m1_mode.h          ← mode compile-time (M1_TEST_MODE)
│       └── Info.plist         ← personality 2357:010c (M1)
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
| **M1c** | MAC + xtal dari EFUSE | ✅ (MAC `98:03:8e:9e:bc:24`) |
| **M1d** | HAL init lengkap vendor (langkah #11–#42: RDG, InitHalDm, FW_InitializeHALVars, PHY_MACConfig, PHY_BBConfig, PHY_RFConfig8188E, InitQueueReservedPage, _InitTxBufferBoundary, …) | ⬜ **TERBESAR** |
| **M2** | bulk TX/RX: kirim probe request, terima beacon, baca SSID | ✅ **terbukti 22 Okt 2026** |
| **M3a** | net80211 scan (di kernel) | ✅ terpasang di HAL M4 (belum uji HW) |
| **M3b** | net80211 join + WPA2 | ⏳ jalur ada, software CCMP; belum uji HW |
| **M4** | IO80211 interface → menu Wi-Fi native | ✅ build+sign+bind; ⏳ uji 1 reboot |

Skrip M4: `./scripts/build-m4.sh`, `ALLOW_BOOT_INJECTION=1 sudo ./scripts/install-m4-esp.sh`.

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
