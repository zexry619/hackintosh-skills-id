# SIMPANAN LENGKAP — proyek driver Wi-Fi native RTL8188EUS untuk macOS

**Dibuat:** 22 Okt 2026, 04:40 (sebelum power off)
**Commit:** lihat `git log` — semua sudah ter-commit
**Rujukan utama:** [`docs/HANDOVER.md`](HANDOVER.md) · [`docs/research-digest.md`](research-digest.md) · [`docs/re-8188e-efuse.md`](re-8188e-efuse.md) · [`CONTINUE.md`](../CONTINUE.md)

---

## 1. RINGKASAN EKSEKUTIF

| | |
|---|---|
| **Tujuan** | Adapter TP-Link RTL8188EUS (`2357:010c`) muncul di **menu Wi-Fi macOS** (interface IO80211 native), tanpa aplikasi pihak ketiga |
| **Strategi** | Port bersih OpenBSD `urtwn` (ISC) + `net80211` dari itlwm (GPL-2.0) + frontend AirportItlwm |
| **Status M1** | ✅ **SELESAI** — power-on + LLT/DMA + **upload firmware 8051 (15 KB)** + bulk pipe. Tidak ada panic |
| **Status M1c** | ⏳ MAC/xtal dari EFUSE — **4 bug ditemukan & diperbaiki** (lewat RE vendor), tinggal 1 reboot untuk verifikasi |
| **Status M1d** | 📐 HAL init (PHY/RF/MAC/DM) — **~450 baris C**, sudah diukur via RE |
| **Status M3/M4** | ⬜ net80211 + IO80211 — peta ada di `docs/m3-m4-integration.md` |
| **Kernel panic** | 4 buah, **semua sudah di-root-cause & diperbaiki** (lihat §5) |
| **Audit keamanan** | 40 temuan (2 agen audit paralel), CRITICAL & HIGH semua diperbaiki |

### Batasan yang diterima
Chip 8188E = 2,4 GHz 1×1 → tanpa AWDL/AirDrop (batasan chip, bukan bug).

---

## 2. APA YANG SUDAH KITA PELAJARI (rekap-acuan)

### 2.1 Dari reverse engineering vendor (`RtWlanU.kext`, Ghidra 12.1.4 via MCP REA)

**Peta fungsi (alamat → simbol):**

| Alamat | Simbol | Status |
|---|---|---|
| `0x119c0b` | `EFUSE_OneByteRead` | ✅ decompile penuh |
| `0x119e0e` / `0x11a8ac` | `efuse_GetEfuseDefinition` / `EFUSE_GetEfuseDefinition` | ✅ |
| `0xb1ea5` | `InitOffload_ReadEfuse_8188EU` | ✅ decompile penuh |
| `0xb1bc2` | `ParsingEfuseContent_8188EU` | ✅ decompile penuh |
| `0xb2f7a` | `GetInitialTxBufferBoundary88E` | ✅ |
| `0xb23a9` | `_InitPowerOn88EU` | ✅ (tabel flow 11 entri) |
| `0xaeebc` | `InitCrystalFrequency_8188E` | ✅ **STUB (kosong!)** |
| `0xbba8` | `PlatformEFIORead1Byte` | ✅ = `PlatformIORead1Byte` |
| `0x71887` | `HAL_8051Reset` | ✅ pause + stall + enable |
| `0x996ae` / `0x981cf` | `InitHalDm` / `dm_ODMStructureInit` | ✅ ukuran |
| `0x99db8` | `FW_InitializeHALVars` | ✅ wrapper |
| `0x107481` / `0x107aa8` | `PHY_MACConfig` / `PHY_BBConfig` | ✅ ukuran |
| `0x145d18` / `0x14593c` | `PHY_RFConfig8188E` / `phy_BB8188E_Config_` | ✅ ukuran |
| `0xb2f3d` / `0xb2faf` | `_InitQueueReservedPage_8188E` / `_InitTxBufferBoundary_8188E` | ✅ ukuran |

**Register EFUSE 8188E:**

| Reg | Fungsi |
|---|---|
| `0x030` | DATA |
| `0x031` | alamat bawah |
| `0x032` | alamat atas (2 bit) |
| `0x033` | status — **bit7 = "siap"** (bukan "busy"!) |

Protokol: clear bit7 → mulai baca → tunggu bit7 **menyala** → baca DATA.

**Register offload 8188E:**

`0x209` mode · `0x0F0` flag · `0x088` trigger · `0x106` akses EFUSE (`0x69`) ·
`0x140` window · `0x143` status · `0x144` header · `0x148` data.
Mode `0xaa` (default) atau `0xf4` → base window = `mode << 4`.

**Layout raw stream offload:**

```
raw[0..1]          = header stream (0x144 >> 16 / >> 24)
raw[2..5]          = LE(read4(0x148)) blok pertama
raw[k*8+6 .. +9]   = LE(read4(0x144))  ← header blok k
raw[k*8+10.. +13]  = LE(read4(0x148))  ← data blok k
panjang stream     = hdr & 0xffff
```

**Validasi sukses:** byte pertama image ROM harus `0x29` (`')'`).
**Validasi tambahan (baru):** image harus berisi USB VID/PID di `0xD0`/`0xD2`
= `2357:010c`.

**Layout image ROM 8188E** (`struct r88e_rom`, FreeBSD — konfirmasi independen):

```
0xB8=184 channel_plan   0xB9=185 crystalcap(xtal)   0xBA=186 thermal_meter
0xC1=193 rf_board_opt   0xD0=208 vid  0xD2=210 pid  0xD4=212 usb_opt
0xD7=215 macaddr[6]  ← 215..220 ✓ (persis yang kita pakai)
```

Fisik 256 byte → logis 512 byte.

### 2.2 Dari riset web paralel (agten, snapshot di `docs/web-research-progress.md`)

| Temuan | Arti |
|---|---|
| **FreeBSD punya pembaca EFUSE 8188E** (`sys/dev/rtwn/if_rtwn_efuse.h`) | Reader 92C-style **berfungsi** untuk chip ini |
| **Rekonsiliasi penting**: `0x030` 32-bit == byte-wise `0x031/32/33` | Register **sama**, cara akses berbeda → dugaan lama kita ("OpenBSD tidak pernah bisa baca EFUSE") **belum tentu benar** |
| **Reader EFUSE yang benar = header-driven** | `0xff` hanya berarti "akhir map" kalau yang dibaca adalah **header**; byte `0xff` boleh muncul di tengah blok data → **bug reader kita** (sudah diperbaiki) |
| `R92C_EFUSE_ACCESS = 0x0cf` / `ON = 0x69` | Sama persis dengan Linux `REG_EFUSE_ACCESS` ✓ |
| OpenBSD commit `rtwn: add rtwn_efuse_preread` (23 Agu 2026) | Per-chip preread EFUSE untuk 88E, sangat baru |
| `struct r88e_rom` FreeBSD | Konfirmasi independen semua offset kita |
| Skema H2C firmware | OpenBSD `urtwn_fw_loadpage`: MCUFWDL PAGE, blok 196 → 4 → 1 byte; sama dengan `_BlockWrite` Linux (196/8/1) |
| itlwm: `getFeatures()` = mekanisme `IO80211SupportedFeatures` | Acuan untuk M4 |

### 2.3 Dari OpenBSD (sumber driver asli, lisensi ISC)

* `urtwn` mendukung chip kita **persis**: `URTWN_DEV_8188EU(TPLINK, RTL8188EUS)` (`usbdevs:4551`).
* Firmware: `rtl8188eufw.bin` (linux) header `0x88e1` v1.28, 15.262 B,
  sha256 `2ff74315…0c4`.
* TX descriptor 8188E = `r92c_tx_desc_usb` (32 B) — OpenBSD sudah benar.
* RX descriptor = `r92c_rx_desc_usb` (24 B) + 2 B.
* 9 tabel power-flow vendor untuk 8188E (sudah di-decode ke `rtwn_flow.c`).
* 42 langkah init vendor (daftar di `docs/init-sequence-8188e.md`).

### 2.4 Temuan operasional (field)

* **Driver vendor Realtek mendukung RTL8188EUS** → Wi-Fi sudah jalan lewat
  dongle: interface `en2`, MAC `98:03:8e:9e:bc:24`, ~12–16 Mbps.
  Tapi **bukan** IO80211 native → tidak muncul di menu Wi-Fi.
* **itlwm tidak mendukung RTL8188E** → tidak ada pintasan.
* macOS 15 **tidak bisa hot-load kext** (`kmutil load` → *"requires a reboot"*).
  → 1 reboot per pergantian binary; iterasi lain cukup **colok-cabut dongle**.
* `kmutil unload` kext eksperimental hampir selalu ditolak
  (*"kext is in use or retained"*) → **reboot satu-satunya cara** melepas.
* USB tethering (HoRNDIS) = jalur internet cadangan saat Wi-Fi dimatikan.

---

## 3. FILE & STRUKTUR (detail)

```
rtl8188eu-airport/
├── CONTINUE.md                    ← panduan lanjut (baca pertama)
├── docs/
│   ├── HANDOVER.md                ← rujukan tunggal
│   ├── research-digest.md         ← ringkasan riset
│   ├── re-8188e-efuse.md          ← decompilation vendor (EFUSE + HAL)
│   ├── audit-hardening.md         ← 40 temuan keamanan
│   ├── init-sequence-8188e.md     ← 42 langkah init vendor
│   ├── m3-m4-integration.md       ← peta net80211 yang harus ditulis
│   ├── vendor-reverse.md          ← metodologi RE
│   ├── web-research-progress.md   ← transkrip agen riset (snapshot)
│   └── … (10 file lain: architecture, legal, testing, roadmap, …)
├── src/
│   ├── urtwn/                     ← C portabel (OpenBSD urtwn, ISC)
│   │   ├── rtwn_seq.c             ← init sequence + firmware loader
│   │   ├── rtwn_seq_efuse.c       ← jalur offload EFUSE (vendor-exact)
│   │   ├── rtwn_efuse_8188e.c     ← jalur direct EFUSE (0x031/32/33)
│   │   ├── rtwn_flow.c             ← tabel flow power-on vendor
│   │   ├── rtwn_usb.c             ← descriptor TX/RX + ring TX
│   │   ├── rtwn_platform*.{c,h}   ← lapisan delay (kernel vs user space)
│   │   └── rtwn_m1.{c,h}, rtwn_consts.h, r92creg.h
│   ├── usb/usb_compat.{h,cpp}     ← shim USB (control + bulk)
│   └── driver/
│       ├── RTL8188EUM1.cpp        ← driver IOKit (M1 bring-up)
│       ├── UsbBackend.cpp / ItlRtl8188E.cpp  ← scaffolding M3/M4
│       ├── m1_mode.h              ← mode compile-time (M1_TEST_MODE)
│       ├── kmod_info.c            ← _kmod_info buatan sendiri
│       └── Info.plist             ← personality 2357:010c
├── scripts/  (28 skrip)            ← install/restore/test/watch/lint
├── tools/    (4 test + probe)
├── upstream/openbsd/              ← sumber urtwn asli
├── upstream/itlwm/                ← net80211 + AirportItlwm
└── vendor/MacKernelSDK/           ← header kernel macOS
```

---

## 4. TOOLING (siap pakai)

```bash
# build varian UJI dengan mode yang diinginkan (readonly/poweron/full)
MODE=poweron ./scripts/build-m1.sh

# test offline (4 kelompok: parser EFUSE, differential vendor, descriptor USB,
# keamanan F1/F4/F5) + linter lock
./scripts/run-tests.sh

# pasang ke ESP + matikan driver vendor
sudo env ALLOW_BOOT_INJECTION=1 MODE=poweron ./scripts/install-test-esp.sh

# reboot → tunggu 60 dtk → colok-cabut dongle

# LaunchDaemon menangkap marker otomatis (15 mnt setelah boot)
cat logs/watch-*.log | tail -1
sudo ./scripts/collect-m1.sh

# kembalikan semuanya
sudo ./scripts/restore-test-esp.sh && reboot
```

---

## 5. 4 KERNEL PANIC — AKAR & PERBAIKAN

| # | Gejala | Akar | Perbaikan | Aturan |
|---|---|---|---|---|
| 1 | `corrupted the registry` (0x329) | Buffer + context transfer USB **di stack** → use-after-free | Pindah ke heap, jangan pernah di-free | A1 |
| 2 | `corrupted the registry` (0x329) | Buffer di-`IOFree` saat stack USB masih menyentuh | Buffer tidak pernah di-free (biarkan bocor) | A1 |
| 3 | `corrupted the registry` (0x278) | `deviceRequest()` dengan **raw pointer** → stack menimpa header objek heap | Selalu pakai `IOMemoryDescriptor` | A7 |
| 4 | `preemption_level -1, unlocking an unlocked mutex` | **`IOLockUnlock()` tanpa `IOLockLock()`** — bug yang saya **tambahkan sendiri** di hardening | Tambah `IOLockLock` + linter otomatis | A22 |

**Pelajaran #4 (paling penting):** hardening bisa **menambahkan** bug.
Karena itu ada `scripts/lint-locks.py` (terintegrasi di test suite) yang
menangkap kelas bug ini secara otomatis.

### Akar yang sebenarnya (benar-benar ketemu)

```c
while ((obj = it->getNextObject())) {
    IOUSBHostInterface *i = OSDynamicCast(IOUSBHostInterface, obj);
    if (i) { found = i; obj->release(); break; }   // ❌ over-release
    obj->release();                               // ❌ over-release
}
```

Kontrak IOKit: objek dari `getNextObject()` **milik collection** →
`release()` = decrement refcount milik orang lain → **double free**.
Dan `found` tanpa `retain()` → **dangling pointer**.
Offset panic berbeda-beda karena korupsinya terdeteksi di release
*berikutnya* yang kebetulan menyentuh objek rusak.

---

## 6. 40 TEMUAN AUDIT KERNEL (ringkas)

| Severity | Jumlah | Contoh |
|---|---|---|
| 🔴 CRITICAL | 7 | over-release iterator, dangling pointer, OOB write (`rtwn_seq_efuse.c`), completion USB menulis ke driver yang sudah di-free, `IOLockUnlock` tanpa lock |
| 🟠 HIGH | 12 | `PKTLEN` chip tanpa validasi (OOB read 14 KB), `RTWN_DELAY_MS` no-op di kernel, loop EFUSE terpotong `(uint16_t)256`, timeout disamar jadi data, firmware 196 B ditolak |
| 🟡 MEDIUM | 12 | divide-by-zero di kernel, flow table tanpa batas, indeks wraparound, alokasi di bawah lock, timebase Mach |
| 🔵 LOW | 9 | slot TX tak terinisialisasi, helper mati & salah, delay 18 jam |

Semua CRITICAL/HIGH diperbaiki + regression test.

---

## 7. 4 BUG EFUSE (baru, dari RE vendor — diperbaiki 22 Okt 04:30)

| # | Vendor | Kita (sebelum) | Akibat |
|---|---|---|---|
| 1 | Trigger 8051 sekali per attempt | Diulang per blok | raw[] kosong → MAC `ff:…` |
| 2 | `raw[k*8+6] = 0x144`, `raw[k*8+10] = 0x148` | Tertukar | Parser desinkron |
| 3 | Panjang stream = `hdr & 0xffff` | Dipaksa 256 | Batas parse salah |
| 4 | `0x033` bit7 = "siap" | Tunggu "busy" | Baca data sebelum selesai |

Plus: reader 92C **berhenti di byte `0xff` pertama** → map terpotong
(EFUSE `0xff` sah di tengah blok data) → **sudah diperbaiki**.

---

## 8. ATURAN KERNEL (WAJIB — 24 aturan)

Lihat `CONTINUE.md` §6 untuk daftar lengkap. Yang paling sering TERLUKA:

| # | Aturan |
|---|---|
| A1 | Jangan pernah free buffer/context transfer USB — biarkan bocor (±100 B ≪ panic) |
| A2 | Jangan baca-balik property untuk menyusun log |
| A3 | Driver eksperimental tidak boleh melakukan traffic USB saat boot |
| A7 | Selalu `IOMemoryDescriptor` untuk buffer I/O USB |
| A11 | Objek dari `getNextObject()` milik collection — `retain()` dulu |
| A12 | Validasi panjang dari descriptor USB terhadap ukuran buffer nyata |
| A13 | Di kernel "menunggu" = `IOSleep`, bukan `IODelay` |
| A14 | Timeout harus bisa dibedakan dari data sah (0xff) |
| A17 | Penanda "masih hidup" harus di **heap** |
| A18 | `removeEventSource()` **sebelum** `release()` |
| A19 | Jalur `start()` gagal harus melepas resource-nya sendiri |
| A20 | Jangan `kalloc` di bawah lock |
| A21 | Timebase Mach dibaca dari kernel |
| **A22** | Setiap `IOLockUnlock` **wajib** didahului `IOLockLock` → jalankan `lint-locks.py` |
| A23 | Simpan pointer lock di variabel lokal saat mutex dibuat lazy |
| **A24** | Setiap perubahan dari audit wajib **di-review ulang terhadap diff-nya sendiri** |

---

## 9. PROGNOSIS & JALUR TERCEPAT

| Langkah | Isi | Perkiraan | Risiko |
|---|---|---|---|
| **Ronde M1c** | Reboot → colok-cabut → cek MAC (`98:03:8e:9e:bc:24`) + xtal | 10 menit | rendah (4 bug sudah diperbaiki) |
| **M1d** | Port HAL init (4 fungsi, ~450 baris) | 1–2 hari | sedang (register write, perlu validasi bertahap) |
| **M2** | Bulk TX/RX: probe request → beacon → SSID | 2–3 hari | sedang |
| **M3a** | net80211 scan (port dari `itlwm`) | 3–5 hari | tinggi (banyak kode kernel) |
| **M3b** | net80211 join + WPA2 | 2–3 hari | tinggi |
| **M4** | IO80211 interface → menu Wi-Fi | 3–5 hari | tinggi |

**Saran:** jangan tulis M3/M4 sebelum M1c **dan** M2 benar-benar tervalidasi
di hardware. 4 kernel panic sudah membuktikan bahwa "kode yang terlihat benar"
bisa meledakkan kernel.

---

## 10. MESIN — KONDISI SAAT POWER OFF

```
ESP kext        : RTL8188EUM1.kext (varian UJI, mode poweron, build terbaru)
Kernel->Add     : 12 entri
boot-args       : ... -rtl8188eum1_mode=poweron   (mode sebenarnya compile-time)
Driver vendor   : DIMATIKAN → /Library/Extensions.disabled-m1/
Wi-Fi dongle    : MATI (vendor off, driver kita belum jadi interface)
Internet        : USB tethering (bridge0) — OK
LaunchDaemon    : com.zekri.rtwn-watch (capture marker, berhenti sendiri)
Backup          : backup/EFI-pre-test.*.tar.gz + config.plist.pre-test.*.bak
```

**Kalau mau Wi-Fi normal lagi:**
```bash
sudo ./scripts/restore-test-esp.sh && reboot
```

**Kalau mau lanjut tes:**
```bash
sudo env ALLOW_BOOT_INJECTION=1 MODE=poweron ./scripts/install-test-esp.sh
# reboot → 60 dtk → colok-cabut → cat logs/watch-*.log | tail -1
```

---

## 11. CARA REPRODUKSI RE (tanpa risiko hardware)

```bash
# Binary vendor (read-only)
sudo mv /Library/Extensions/RtWlanU.kext /Library/Extensions/RtWlanU.kext.off
# buka via MCP REA:
open_binary({path: "<path>/RtWlanU", provider_id: "ghidra"})
search_procedures({pattern: "InitOffload_ReadEfuse"})
procedure_pseudo_code({procedure: "0xb1ea5"})
close_binary()
```

**RE adalah jalur termurah dan teraman** — semua bug EFUSE ditemukan di sini
dengan **0 kernel panic**.

---

## 12. GIT

```
f9e2816  docs: research digest — ringkasan RE, 4 bug EFUSE, ukuran ulang sisa pekerjaan
98a8012  feat: validasi image EFUSE (byte pertama harus 0x29)
775213b  docs: ukur ulang ukuran kerja M1d via RE
92489d4  feat: RE EFUSE 8188E — 4 bug ditemukan & diperbaiki
63d161a  feat: M1 bring-up — driver net80211 native untuk RTL8188EUS
```

166 file terlacak, 0 perubahan pending.

---

**Selamat tidur. Kext eksperimental di ESP adalah INERT saat boot
(uptime < 60 dtk → nol traffic USB) → tidak akan membekukan mesin.**
