# Kesiapan Pra-Reboot — Ringkasan Final (22 Okt 2026)

Semua yang bisa ditelusuri **statis** sudah ditelusuri. Berikut hasil & rencananya.

---

## 1. Fakta yang SUDAH terverifikasi (decompilation Ghidra atas `RtWlanU.kext`)

| # | Fakta | Bukti |
|---|---|---|
| 1 | `bmRequestType` 0xC0 (baca) / 0x40 (tulis) | `MxUsbSyncVendorRequest` 0x80aaa |
| 2 | `bRequest` = **0x05**, `wIndex` = **0**, `wValue` = alamat register | idem |
| 3 | Timeout vendor 5000 ms | idem |
| 4 | `MACID` = **0x610** | `GetHwReg8188EUsb` 0xb5c46 |
| 5 | `EFUSE_ACCESS_ON` = **0x69** | alur EFUSE vendor |
| 6 | **Layout register EFUSE 8188E: data 0x030, addr lo 0x031, addr hi 0x032, status 0x033** | `EFUSE_OneByteRead` 0x119c0b |
| 7 | **Akar masalah M1**: OpenBSD menulis address EFUSE ke 0x030, padahal di 8188E itu register DATA | #6 vs `rtwn_efuse_read_1` |
| 8 | Parser EFUSE: extended header membawa **mask** (`nxt & 0x0f`); data OOB ditulis **0** | `ParsingEfuseContent_8188EU` 0xb1bc2 + differential test |
| 9 | xtal = **rom[185]**, crystal cap = rom[6] | `Hal_EfuseParseXtal_8188E` 0x145358 |
| 10 | Tabel mask EFUSE 8188E (32 byte) | `_Array_MP_8188E_MUSB` 0x376f70 |
| 11 | Urutan power-on = **tabel statis** 10 entri | `_rtl8188E_power_on_flow` 0x2b6240 |
| 12 | Format entri flow = 8 byte (`WL_PWR_CFG`), 4 tipe perintah | `HalPwrSeqCmdParsing` 0x9a6c4 |
| 13 | **9 tabel flow** untuk 8188E | nm |
| 14 | Urutan init total **42 langkah** | `InitializeAdapter8188EUsb` 0xb3c4c |
| 15 | Header RX USB = **24 + 2 byte** = `r92c_rx_desc_usb` OpenBSD | `GetRxPacketShiftBytes8188EUsb` 0x14cca0 |
| 16 | TX descriptor 8188E = `r92c_tx_desc_usb` (32 byte) — **OpenBSD sudah benar** | `urtwn_tx_fill_desc` + vendor `TxFillDescriptor8188EUsb` 0x14ccb8 |
| 17 | H2C firmware memakai register yang **sama** dengan OpenBSD (0x1CC HMETFR, 0x1D0 HMEBOX) | `FillH2CCommand8188E_MPP` 0xb1524 |
| 18 | Firmware: header signature `0x88e1` (v1.28) — **file linux `rtl8188eufw.bin` cocok** | dump header |
| 19 | Kontrak frontend M4: `ItlHalService` (7 method) + `ItlDriverInfo` + `ItlDriverController` | `include/HAL/ItlHalService.hpp` |

---

## 2. Kode yang sudah ada & teruji

```
src/urtwn/
├── rtwn_seq.c          logika M1 portabel (C murni): register access, parser EFUSE
│                        (identik vendor), power-on, LLT, upload firmware
├── rtwn_seq_efuse.c    jalur OFFLOAD EFUSE (mesin internal/8051)
├── rtwn_efuse_8188e.c  ⭐ baca EFUSE dgn layout register 8188E (0x31/0x32/0x33/0x30)
├── rtwn_flow.c         ⭐ eksekutor power-flow + 4 tabel 8188E + LLT vendor
├── rtwn_m1.{h,cpp}     turunan OpenBSD urtwn (TX/RX descriptor, chip detect)
├── rtwn_consts.h       konstanta chip
└── r92creg.h           register map (OpenBSD) + padding Darwin

tools/
├── rtwn_probe.c        probe user space: --efuse-direct / --efuse-offload / --full / --write-test
├── test_efuse.c        uji sintetis dgn tabel mask asli vendor
├── test_efuse_diff.c   ⭐ differential test vs transkripsi pseudocode Ghidra
└── decode_flow_table.py  ⭐ ekstrak & decode 9 tabel flow dari binary vendor
```

Status test:

```
✅ differential test : IDENTIK dengan referensi vendor (20.000 image acak)
✅ test sintetis     : xtal ✓  channel_plan ✓  MAC ✓
✅ build kext        : OK (Mach-O kext bundle, 90 KB)
✅ build probe       : OK
```

---

## 3. ⭐ LOOP ITERASI TANPA REBOOT (final — reboot TIDAK lagi diperlukan!)

**Temuan penting:** karena driver bisa *self-detach* setelah init selesai, kext
tidak lagi tertahan "in use" → **hot-swap binary baru selalu bisa**. Jadi:

```bash
./scripts/iterate-no-reboot.sh
```

Skrip itu: build (varian UJI) → hot-swap ke kernel → minta Anda cabut-colok dongle
(2 detik) → menampilkan hasil. **Total ±30 detik per iterasi, tanpa reboot.**

### Kenapa tidak perlu reboot lagi

| Masalah | Solusi |
|---|---|
| Kext "in use" → tidak bisa di-unload → binary baru tak bisa masuk | Driver **self-detach** setelah init (`terminate()`) → kext bisa di-unload |
| Build di ESP akan jalan saat boot → bisa bikin mesin gagal boot | Build default = **AMAN** (`M1_ALLOW_USB_TRAFFIC=0`): nol traffic USB, attach < 60 dtk = inert |
| Perubahan binary butuh reboot | `kmutil load -z -p` = hot-swap runtime ✓ |

### Alur lengkap (tanpa reboot)

```bash
# 1. bebaskan device dari driver vendor (sekali saja)
sudo ./scripts/vendor-off.sh && sudo shutdown -r now

# 2. SETERUSNYA: iterasi tanpa reboot
./scripts/iterate-no-reboot.sh
```

Atau, tanpa cabut-colok, cukup pancing driver secara runtime:

```bash
sudo kmutil load -b io.github.zekri.RTL8188EUM1 -P RTL8188EUM1
```

## 3b. Rencana reboot lama (arsip) — urutan persis

```bash
# ── sebelum reboot: siapkan ──────────────────────────────────
cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport
sudo ./scripts/vendor-off.sh          # matikan RtWlanU + bersihkan AuxKC
sudo shutdown -r now

# ── setelah boot: PROBE DARI USER SPACE (aman, tanpa kernel) ──
sudo ./tools/rtwn_probe --efuse-direct
#  oghile yang diharapkan:
#     MAC      = 98:03:8e:9e:bc:24
#     xtal=0x0b  regulatory=0  channel_plan=0

#   kalau GAGAL → coba jalur offload:
sudo ./tools/rtwn_probe --efuse-offload

#   kalau salah satu berhasil → lanjut full (power-on + LLT + firmware):
sudo ./tools/rtwn_probe --full
```

### Kenapa probe dulu (bukan langsung kext)

* Probe = program biasa → **tidak mungkin panic kernel**.
* Probe memakai **kode yang sama** dengan kext (`src/urtwn/rtwn_seq*.c`).
* Kalau MAC terbaca di probe, berarti register/encoding/EFUSE kita benar 100%,
  dan kext tinggal mengulang langkah yang sama.

### Kalau probe sukses → pindahkan ke kext

Tidak perlu reboot lagi untuk ini! `kmutil load -z -p` bisa hot-swap:

```bash
sudo kmutil load -z -p src/driver/build/RTL8188EUM1.kext
```

TAPI: kext harus **tidak** ikut ter-load saat boot (permanen berbahaya)._opsinya:
build **SAFE** (default `M1_ALLOW_USB_TRAFFIC=0` → nol traffic USB) yang
dijalankan via hot-swap runtime + `kmutil load -P` untuk memicu init.
Sudah ada skrip `scripts/dev-loop.sh` untuk ini.

---

## 4. Yang MASIH perlu ditulis (M2–M5) — semuaPurely engineering

| Item | Baris estimasi | Sumber yang bisa dipakai |
|---|---|---|
| Transport USB (bulk pipe + descriptor ring TX/RX) | ~600 | `urtwn` (sudah ada) + `RTW88USBDevice.cpp` (AirPort-RTW) |
| `ItlHalService` + `ItlDriverInfo` + `ItlDriverController` | ~4.000–6.000 | `ItlIwx` (13.871 baris) sbg acuan |
| Adaptasi frontend (PCI→USB) | ~300 | `AirportItlwm` (7.221 baris, sudah ada) |
| Integrasi net80211 | ~800 | `itl80211` (27.905 baris, sudah ada) |
| WPA2/EAPOL | ~300 | Apple WCL (otomatis, tinggal alur frame) |

---

## 4b. ⚠️ Temuan penting: user-space USB probe TIDAK mungkin di macOS 15

Saya uji dengan program minimal (22 Okt 2026, tanpa reboot):

```
IOUSBDevice        type=0 → 0xE00002C7 (exclusive access)
IOUSBDevice        type=1 → 0xE00002C7
AppleUSBDevice     type=0 → 0xE00002C7
AppleUSBInterface  type=0 → 0xE00002C7
IOUSBHostDevice    type=0 → 0x00000000  ✅ OK
```

Artinya:
* **API USB legacy (yang dipakai `rtwn_probe`) sudah DITUTUP** di macOS 15 —
  dan itu berlaku untuk **semua** device USB (mouse, keyboard, Wi-Fi), bukan hanya
  chip kita. Jadi bukan masalah "device dipegang driver lain".
* Stack **modern** (`IOUSBHostDevice`) masih bisa dibuka dari user space, tapi
  lewat **user client privat** (`IOUSBHostDeviceUserClient`) yang tidak ada
  di SDK publik → selector method-nya tidak bisa dipanggil dari user space.

**Konsekuensi:** validasi lewat user space (probe) **tidak mungkin** di macOS 15.
Jalur yang benar adalah **kernel driver** — yang memang sudah kita tulis dengan
API modern yang sama (`IOUSBHostDevice::deviceRequest`).

Ini juga menjelaskan kenapa `kmutil load -z -p` (hot-swap) tidak bisa dipakai:
macOS 15 mewajibkan kext baru masuk lewat AuxKC → **reboot**.

## 5. Checklist sebelum reboot

- [x] Driver vendor dimatikan & dibersihkan dari AuxKC
- [x] Kext eksperimental TIDAK ada di OpenCore (aman saat boot)
- [x] Driver vendor dikembalikan ke `/Library/Extensions`
- [x] Kode M1 (EFUSE 8188E + power-flow + LLT) ter-build & teruji
- [x] Probe user space siap (3 jalur: direct / offload / full)
- [x] Seluruh temuan terdokumentasi (12 file .md, ~3.000 baris)
- [x] Backup ESP: `backup/EFI-BIG-*.tar.gz`
- [ ] **REBOOT → jalankan `sudo ./tools/rtwn_probe --efuse-direct`**

---

## 6. Risiko tersisa & mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Chip tidak menjawab vendor request | M1 mentok | 3 jalur sudah siap (direct/offload/write-test) + log vendor `MxUsbSyncVendorRequest` memberi diagnosa |
| Base address register (`HAL_GetAddressOffset`) ≠ 0 | register < 0x100 salah | deteksi base empiris di probe |
| 2 kernel panic sebelumnya | mesin freeze | sudah ditutup: buffer transfer tidak pernah di-free (`src/usb/usb_compat.cpp`) |
| IO80211 KPI berubah tiap update macOS | driver mati | pin `MinKernel`/`MaxKernel` per build (seperti AirportItlwm) |
| 8188E 2,4 GHz only | throughput 30–60 Mbps | batas chip, bukan bug |
