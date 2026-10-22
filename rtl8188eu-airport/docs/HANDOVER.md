# HANDOVER — Proyek Driver Wi-Fi Native untuk RTL8188EUS (macOS)

**Status: 🟢 M1 SELESAI (22 Okt 2026).** 4 kernel panic sudah di-root-cause;
**init M1 kini berhasil penuh** (power-on + DMA + upload firmware 8051 +
bulk pipe) tanpa panic. Sisa: MAC/xtal dari EFUSE + M2/M3/M4.
Lihat §15.
(Panic #4 = bug di hardening sendiri: `IOLockUnlock` tanpa `IOLockLock`.
Sekarang ada linter `scripts/lint-locks.py` di test suite.)
Audit keamanan memori menyeluruh selesai — **2 agen audit paralel**, total
**40 temuan** (7 CRITICAL / 12 HIGH / 12 MEDIUM / 9 LOW).
**Semua CRITICAL & HIGH sudah diperbaiki** + regression test baru.
Detail lengkap: **[`docs/audit-hardening.md`](audit-hardening.md)**.
Mesin aman: kext eksperimental TIDAK ada di OpenCore / AuxKC / BootKC.

Dokumen ini adalah rujukan tunggal untuk melanjutkan riset.

---

## 1. Ringkasan eksekutif

**Tujuan:** membuat adapter USB Wi-Fi TP-Link **RTL8188EUS** (`2357:010c`) muncul
sebagai interface **IO80211** di macOS, sehingga bisa dipakai dari **menu Wi-Fi
bawaan macOS** — tanpa aplikasi pihak ketiga.

**Temuan utama (positif):** chip ini **sudah didukung driver open-source**
`urtwn` dari OpenBSD, **persis** dengan USB ID kita:

```
openbsd/src/sys/dev/usb/usbdevs:4551   product TPLINK RTL8188EUS 0x010c
openbsd/src/sys/dev/usb/if_urtwn.c:332  URTWN_DEV_8188EU(TPLINK, RTL8188EUS)
```

Lisensi `urtwn` + `net80211` = **ISC** (boleh dipakai & didistribusikan).
`net80211`-nya sudah pernah diport ke macOS oleh `itlwm` (34 file).
Frontend IO80211 juga sudah ada (`AirportItlwm`).

Jadi bahan bakunya lengkap; yang belum ada adalah:
lapisan transport USB (OpenBSD `usbd_*` → IOKit `IOUSBHost*`) dan
adaptasi frontend untuk chip Realtek.

**Kenapa dijeda:** prototipe mencapai tahap "driver match ke device USB &
menjalankan init sequence", tapi **dua kernel panic** terjadi karena
use-after-free pada buffer transfer USB. Akar masalahnya sudah dipahami
(lihat §6), tapi belum ada data apakah chip 8188EUS menjawab vendor request
kita — itu pertanyaan inti yang masih belum terjawab.

---

## 2._meshHardware & environment

### 2.1 Adapter

| Item | Nilai |
|---|---|
| Vendor:Product | `0x2357:0x010C` (TP-Link → RTL8188EUS) |
| USB Product Name | `802.11n NIC` |
| Manufacturer | Realtek |
| Serial Number | `00E04C0001` |
| MAC address | `98:03:8e:9e:bc:24` (dari `en2` saat driver vendor aktif) |
| bcdDevice | `0x00` |
| Kecepatan USB | **High-Speed (480 Mb/s)** → USB 2.0, bukan USB 3 |
| Kapasitas | 2,4 GHz, 1×1, 802.11n (HT20/HT40), maks ~150 Mbps teoretis |
| Interface | `en2` (Hardware Port: "802.11n NIC") |

### 2.2 Mesin

| Item | Nilai |
|---|---|
| macOS | 15.8.1 (24H32), Darwin 24.6.0, XNU-11417.140.69 |
| Model | iMacPro1,1 (Mac-7BA5B2E2D9E42DD94) |
| CPU/RAM | i5-10400F, RX 6600 |
| OpenCore | 1.0.8 RELEASE |
| ESP aktif | `/dev/disk0s2`, volume bernama **"MAC OS"** (pernah "EFI-BIG", 512 MB) |
| Boot args | `keepsyms=1 debug=0x100 agdpmod=pikera -cdfon` (kernel debugging aktif) |
| Disk lain | `/dev/disk1` = disk Linux (ESP "Fedora" 629 MB) — **bukan** milik macOS |

> ⚠️ Nama volume ESP berubah-ubah ("EFI-BIG" → "Mac OS" → "MAC OS 2").
> Semua skrip di `scripts/` memakai deteksi otomatis (`find_esp()`).

### 2.3 Stack vendor Realtek (yang biasa dipakai)

| Komponen | Detail |
|---|---|
| `RtWlanU.kext` | v1830.32.b27, build **19 Nov 2020**, 11,7 MB, **tidak stripped** (11.958 simbol) |
| Personality | `IOProviderClass = IOUSBInterface` + `idVendor/idProduct/bConfigurationValue/bInterfaceNumber` |
| Antarmuka | **`IOEthernetInterface` (en2)** — BUKAN `IO80211Interface` |
| `StatusBarApp.app` | Control plane user-space: scan/join/EAPOL/profile, talking ke kernel via `RtWlanUserClientU` + OID |
| `RtWlanHelper` | Daemon pendukung (profile/socket) |
| `wpa_supplicant` | Dipaket di dalam `StatusBarApp.app/Contents/MacOS/` (untuk 802.1X) |

**Implikasi penting:** karena vendor mendaftarkan chip sebagai *Ethernet*,
adapter **tidak pernah muncul di menu Wi-Fi macOS** — itu persis celah yang
mengvault proyek ini. Aplikasi pihak ketiga wajib, dan begitu aplikasi itu mati,
chip jadi "mati total" (bukan cuma menu Wi-Fi yang hilang).

---

## 3. Arsitektur target

```
        CoreWLAN / menu Wi-Fi / airportd  (milik Apple)
                        │  IO80211 KPI (API privat Apple)
┌───────────────────────┴──────────────────────────────────────┐
│ Layer 4 — src/airport/   frontend IO80211                    │
│   adaptasi dari laobamac/itlwm: AirportItlwm*.cpp           │
│   + USBBackend (pembungkus IOUSBHostInterface)                │
├──────────────────────────────────────────────────────────────┤
│ Layer 3 — src/net80211/  OpenBSD net80211 (via itlwm)       │
│   ieee80211_ioctl: scan/join/key/ratectl                     │
├──────────────────────────────────────────────────────────────┤
│ Layer 2 — src/urtwn/     OpenBSD urtwn + rtwn (ISC)         │
│   USB attach, firmware 8051, EFUSE, RF, TX/RX ring           │
├──────────────────────────────────────────────────────────────┤
│ Layer 1 — src/usb/       shim: usbd_* → IOUSBHost*          │
│   control transfer (vendor request), bulk pipe (M2)          │
└──────────────────────────────────────────────────────────────┘
   firmware/rtl8188eufw.bin (15.262 B, sha256 2ff74315…0c4)
   Info.plist: IOProviderClass=IOUSBHostInterface, idVendor 9047, idProduct 268
```

---

## 4. Protokol USB (hasil reverse engineering dari OpenBSD)

Semua register Realtek diakses lewat **vendor request** (bukan bulk pipe):

```
bmRequestType = 0x40 (write) / 0xC0 (read)   ← UT_WRITE/UT_READ | VENDOR | DEVICE
bRequest      = 0x05                          ← R92C_REQ_REGS
wValue        = alamat register (LE16)
wIndex        = 0
wLength       = 1 / 2 / 4 byte
```

Sumber: OpenBSD `if_urtwn.c` baris 785 (`urtwn_write_region_1`) & 825
(`urtwn_read_region_1`), memakai `usbd_do_request()`.

Struktur image firmware (H2C): header 32 byte (signature `0x88e…`),
diupload per halaman 4096 byte; tiap halaman ditulis ke alamat `0x1000`
dengan blok maksimal **196 byte** (254 untuk 92E).

---

## 5. Cara memuat kext di macOS 15 tanpa Xcode (temuan mahal)

Ini bagian yang tidak ada di tutorial mana pun dan memakan banyak waktu.
Semua sudah ter automate di `scripts/`.

### 5.1 Tiga syarat wajib

1. **Simbol `_kmod_info`** — kernel mencari simbol ini di setiap kext
   (`libkern/kxld/kxld_kext.c`: `kxld_symtab_get_locally_defined_symbol_by_name`).
   Xcode membuatnya otomatis lewat `CreateKModInfo.perl`; tanpa Xcode kita
   membuat sendiri di `src/driver/kmod_info.c`.
   Layout struct mengikuti XNU `osfmk/mach/kmod.h`:
   `next(8) | info_version(4)=1 | id(4) | name[64] | version[64] |
   reference_count(4) | reference_list(8) | address(8) | size(8) | hdr_size(8) |
   start(8) | stop(8)`.
   Link baris: `*.o -lkmod` (MacKernelSDK `Library/x86_64/libkmod.a`).
2. **Milik `root:wheel`** — `kmutil` menolak:
   `Filesystem error: Invalid ownership (0:20) should be (0:0)`.
3. **`OSBundleLibraries` yang benar** — `com.apple.iokit.IOUSBHostFamily`
   (bukan `com.apple.iokit.IOKit`, yang tidak ada sebagai bundle terpisah
   di macOS modern).

### 5.2 Header kernel

Jangan pakai header `Kernel.framework` biasa: `IOKit/usb/IOUSBHostDevice.h`
meng-`#include <USBDriverKit/…>` → bentrok kelas. Solusinya **MacKernelSDK**
(`acidanthera/MacKernelSDK`) + flag:

```bash
clang++ -mkernel -std=c++17 -fno-rtti -fno-exceptions -fno-common -nostdinc++ \
        -DKERNEL=1 -DKERNEL_PRIVATE=1 -I vendor/MacKernelSDK/Headers …
ld -kext -arch x86_64 -undefined dynamic_lookup -L …/x86_64 -lkmod …
```

Tanpa `-DKERNEL=1` → error `redefinition of 'IOUSBHostDevice'`.

### 5.3 Dua jalur pemuatan, dan bedanya

| Jalur | Cara | Kelebihan | Kekurangan |
|---|---|---|---|
| **AuxKC** | `kmutil load -z -p <kext>` → masuk staging → dimuat saat boot | Tidak menyentuh ESP | Kext **ad-hoc (unsigned) tidak dievaluasi syspolicyd** → tidak pernah dimuat; bisa "balapan" dengan kernel saat boot |
| **BootKC (OpenCore)** | `EFI/OC/Kexts/` + entri `Kernel → Add` → OpenCore menyuntik ke BootKC | Berjalan & bisa di-hot-swap runtime | **Berjalan saat boot** → kalau drivernya salah, mesin gagal boot |

**Rekomendasi**: hanya untuk driver yang sudah terbukti stabil.

### 5.4 Matching personality — disappointingly tricky

* Node device modern (`IOUSBHostDevice`) **sudah diklaim driver internal Apple**
  (`AppleUSBHostLegacyClient`) → driver pihak ketiga **tidak bisa** attach di sana.
* Node yang benar: **`IOUSBHostInterface`** (membawa `idVendor`, `idProduct`,
  `bInterfaceNumber`).
* **Satu node hanya boleh punya satu driver.** Selama `RtWlanU` (stack USB
  legacy) aktif, ia mengklaim node legacy `AppleUSBInterface` **dan** memicu
  shim legacy pada node device → driver kita **tidak akan match**.
  → Driver kita dan driver vendor **tidak bisa berdampingan**; harus bergantian.
* Mengirim personality ulang (`kmutil load -b <id> -P <personality>`) **tidak**
  memanggil `start()` ulang pada driver yang sudah attach.
* OpenCore **menulis ulang `IOProbeScore`** personality menjadi 99000.
* `IOMatchCategory` di personality dicurigai ikut dibandingkan → lebih aman
  dihilangkan.

### 5.5 Hot-swap tanpa reboot (berhasil, tapi dengan syarat)

```bash
sudo kmutil load -z -p <bundle>     # unload + load binary baru
```

Berhasil **hanya** kalau kext tidak sedang "in use" (driver-nya belum attach).
Kalau attach → unload ditolak (`kext is in use or retained`) dan perintah
ini diam-diam tidak melakukan apa-apa.

---

## 6. Dua kernel panic — akar masalah & aturan yang lahir dari sana

### 6.1 Panic #1 (21 Okt, 17:07)

```
panic(cpu 8): A kext releasing a(n) RTL8188EUM1 has corrupted the registry. @OSObject.cpp:224
  __ZNK8OSObject13taggedReleaseEPKvi
  io.github.zekri.RTL8188EUM1: __ZN11RTL8188EUM115runInitSequenceEv + 0x329
  IOTimerEventSource::timeoutSignaled
```

**Akar:** control transfer asinkron memakai **buffer + context di stack**.
Completion bisa dipanggil setelah pemanggil kembali → **use-after-free** →
heap rusak → objek registry ikut rusak → panic saat release berikutnya.

### 6.2 Panic #2 (21 Okt, 10:33) — offset identik

Buffer sudah dipindah ke heap, panic tetap di `+0x329`.

**Disassembly offset +0x329** = `release()` atas objek dari
`copyProperty("M1Mode")` → itu **tempat korupsinya terdeteksi**, bukan penyebabnya.

**Akar sebenarnya:** **stack USB masih menyentuh `dataBuffer` SETELAH completion
dipanggil** → buffer yang di-`IOFree()` = use-after-free → heap rusak → objek
registry ikut rusak → panic.

### 6.3 Aturan yang lahir (WAJIB dipatuhi)

| # | Aturan |
|---|---|
| A1 | **Jangan pernah membebaskan buffer/context transfer USB.** Sengaja bocorkan (±100 B per transfer). Kebocoran jauh lebih murah daripada kernel panic |
| A2 | **Jangan baca-balik property** untuk akumulasi log (release objek katalog = jalur yang crash). Pakai buffer statis |
| A3 | Driver eksperimental **tidak boleh melakukan traffic USB saat boot**. Pisahkan build "aman" (inert) dan build "uji" |
| A4 | Mode harus bisa ditentukan **saat build** (`-DM1_ALLOW_USB_TRAFFIC=1`), bukan runtime |
| A5 | Setelah selesai, driver **melepaskan diri** (`terminate()`), supaya kext bisa di-unload & di-hot-swap |
| A6 | Setiap langkah harus punya marker di registry (`M1Log`), supaya titik gagalnya terlihat tanpa Unified Log |

### 6.4 Panic #3 (22 Okt, 02:51) — offset berbeda, tanda sama

```
panic(cpu 4): A kext releasing a(n) RTL8188EUM1 has corrupted the registry. @OSObject.cpp:224
  io.github.zekri.RTL8188EUM1: __ZN11RTL8188EUM115runInitSequenceEv + 0x278
```

**Disassembly offset +0x278** (base fungsi `0x19c0` → target `0x1c38`):

```
0x1c24 movq (%rbx), %rax
0x1c2a callq *0x680(%rax)      ; OSString::withCString() → objek A
0x1c3f callq *0x680(%rax)      ; OSString::withCString() → objek B ("joined")
0x1c45 movq (%rax), %rcx
0x1c4b callq *0x38(%rcx)       ; release(B)   ← PANIC DI SINI
```

Release objek OSString kedua memicu detektor → berarti **heap sudah korup
sebelumnya**; release ini hanya tempat detektornya meledak.

**Akar yang paling mungkin — control transfer memakai raw pointer:**

```c
uint8_t *ctx->buf = (uint8_t *)IOMalloc(len);
fDevice->deviceRequest(fClient, req, ctx->buf, &completion, timeout);   // ← BAHAYA
```

Stack USB modern (`IOUSBHostFamily`) melakukan DMA langsung ke buffer. Bila
buffer itu **bukan `IOMemoryDescriptor`**, stack bisa menimpa **header objek
heap** → heap corruption → panic saat objek berikutnya di-release.
Jalur *bulk* sudah benar (memakai MD); jalur *control* belum.

**Perbaikan (sudah diterapkan di `src/usb/usb_compat.cpp`):**

```c
ctx->md  = IOBufferMemoryDescriptor::withCapacity(len ? len : 1, kIODirectionInOut);
ctx->buf = (uint8_t *)ctx->md->getBytesNoCopy();
fDevice->deviceRequest(fClient, req, ctx->md, &completion, timeout);     // ✓
```

### 6.5 Status keamanan mesin (22 Okt, setelah panic #3)

| Lokasi | Isi | Status |
|---|---|---|
| `EFI/OC/Kexts/RTL8188EUM1.kext` | file | ✅ dihapus |
| `EFI/OC/config.plist` → `Kernel→Add` | entri | ✅ dihapus (13 → 12) |
| AuxKC `com.apple.kcgen.instructions.plist` | `kextsToBuild` | ✅ bersih |
| `AuxiliaryKernelExtensions.kc` | isi file | ✅ hanya RtWlanU/RtWlanU1827 |
| `AuxKC/…/StashedExtensions` | salinan | ✅ hanya 2 kext vendor |
| `/Library/Extensions` | kext kita | ✅ tidak ada |
| `/System/Library/Extensions` | kext kita | ✅ tidak ada |
| BootKC (Preboot) | kemunculan `RTL8188EUM1` | ✅ 0 |
| Scan seluruh sistem | salinan lain | ✅ hanya di folder proyek (bukan search path kernel) |

`config.plist` lolos `plutil -lint`; `Kernel→Add` (12) cocok dengan folder
`Kexts/`; struktur `EFI/OC` utuh (OpenCore.efi, ACPI, Drivers, Tools, Resources).

> Catatan: selisih `BlueToolFixup.kext` → `SMCRadeonSensors.kext` di ESP
> **bukan** perubahan skrip kita (backup 03:14 masih punya BlueToolFixup,
> sesudahnya diganti) — itu perubahan manual pengguna.

### 6.6 Aturan tambahan (hasil panic #3)

| # | Aturan |
|---|---|
| A7 | **Selalu pakai `IOMemoryDescriptor`** untuk buffer I/O USB — jangan pernah raw pointer |
| A8 | **Driver eksperimental tidak boleh otomatis menyentuh device.** Default = IDLE; init hanya jalan bila dipicu eksplisit (properti `M1Trigger` = `"run"`) |
| A9 | Kalau ragu antara *free* dan *leak* → **biarkan leak**. Kebocoran ±100 B ≪ kernel panic |
| A10 | Setelah panic, kext buggy **tidak bisa di-unload** (`in use or retained`) → **jangan sentuh device sebelum reboot selesai** |

---

## 7. Yang sudah diimplementasikan (kode siap pakai)

```
src/
├── urtwn/rtwn_seq.{h,c}   ⭐ modul M1 PORTABEL (dipakai probe & kext)
├── driver/
│   ├── RTL8188EUM1.cpp     driver IOKit (match, init sequence, tracing via registry)
│   ├── Info.plist         personality (IOUSBHostInterface + IOUSBHostDevice)
│   ├── kmod_info.c        struktur _kmod_info (untuk build tanpa Xcode)
│   └── m1_mode.h          mode runtime (boot-arg)
├── urtwn/
│   ├── rtwn_m1.{h,cpp}    PORT dari OpenBSD: chipid, EFUSE/ROM, power-on 88E,
│   │                      DMA/LLT init, upload firmware 8051
│   ├── rtwn_consts.h      konstanta chip (dari OpenBSD)
│   ├── r92creg.h          salinan r92creg.h + padding Darwin
│   └── firmware_…cpp      firmware 8188E disematkan (dari linux-firmware)
└── usb/
    └── usb_compat.{h,cpp} Layer 1: shim usbd_* → IOUSBHost* (control transfer)
```

Fungsi yang **sudah diport verbatim** dari OpenBSD (ISC) dan bisa dipakai lagi:
`rtwn_read_chipid`, `rtwn_efuse_read`, `rtwn_efuse_switch_power`,
`rtwn_r88e_read_rom`, `urtwn_r88e_power_on`, `urtwn_dma_init`,
`urtwn_llt_init`, `urtwn_llt_write`, `urtwn_fw_loadpage`,
`rtwn_load_firmware`, `rtwn_r88e_fw_reset`.

### Skrip

| Skrip | Fungsi |
|---|---|
| `fetch-upstream.sh` | unduh itlwm, AirPort-RTW, OpenBSD urtwn, MacKernelSDK, firmware |
| `sync-openbsd-headers.sh` | refresh `r92creg.h` + padding Darwin |
| `build-m1.sh` | build kext (varian AMAN + varian UJI) |
| `install-opencore.sh` | backup → salin kext → entri `Kernel → Add` → bersihkan AuxKC |
| `uninstall-opencore.sh` | rollback injeksi OpenCore |
| `vendor-off.sh` / `vendor-on.sh` | matikan/hidupkan driver vendor Realtek |
| `set-mode.sh` | set boot-arg mode |
| `collect-m1-log.sh` | kumpulkan hasil dari `ioreg` |
| `clean-auxkc.py` | bersihkan entri kext dari staging AuxiliaryKernelExtensions |

---

## 7b. ⭐ Hasil RE driver vendor (21 Okt 2026) — ini mengubah analisis

Decompilation Ghidra atas `RtWlanU.kext` (via REA MCP) **membuktikan encoding
vendor request kita benar**. Detail lengkap: [`vendor-reverse.md`](vendor-reverse.md).

| Field | Vendor (terbukti) | OpenBSD | Kode kita |
|---|---|---|---|
| `bmRequestType` | 0xC0 read / 0x40 write | sama | ✓ |
| `bRequest` | **0x05** | 0x05 | ✓ |
| `wValue` | alamat register | alamat register | ✓ |
| `wIndex` | **0** | 0 | ✓ |
| timeout | 5000 ms | default | 250 ms (perlu dinaikkan) |
| MACID | **0x610** | 0x610 | ✓ |
| `EFUSE_ACCESS_ON` | **0x69** | 0x69 | ✓ |

**Temuan baru yang belum kita tahu:** vendor menghitung
`alamat = HAL_GetAddressOffset(adapter, offset) + (offset & 0xFFFF)`,
dengan **base ≠ 0 untuk register < 0x100** (EFUSE_CTRL 0x030, MCUFWDL 0x080,
SYS_CFG 0x0F0, APS_FSMCO 0x004, …). OpenBSD memakai alamat langsung → base untuk
88E kemungkinan 0, **tapi harus dibuktikan** (sudah ada di probe: `tools/rtwn_probe`
mencoba base {0,0x100,0x200,0x400,0x1000,0x2000,0x3000} dan menandai yang "waras").

**⭐ TEMUAN PALING PENTING (21 Okt 2026, RE penuh):** EFUSE 8188E USB **tidak bisa
dibaca langsung** seperti OpenBSD. Chip ini memakai jalur **OFFLOAD** — mesin
internal/8051 melakukan pembacaan dan mengembalikan (header, data) lewat register
`0x144`/`0x148`, dengan urutan khusus:

```
write8(0x209, 0xAA)        mode EFUSE
write8(0x0F0, v|0x80)     flag
reset 8051 (0x093/0x003)
write8(0x088, v|0x02)     trigger
poll 0x088 sampai bit1 hilang   (maks 1000 × 50 ms)
write8(0x106, 0x69)       EFUSE access ON
write16(0x140, base)      window
write8(0x143, 0); poll sampai bit0 (maks 50 × 50 ms)
read32(0x144) hdr, read32(0x148) data
```

**Ini adalah penyebab sebenarnya kegagalan M1** — bukan encoding, bukan transfer USB.

Implementasi: `src/urtwn/rtwn_seq_efuse.c` (fungsi `rtwn_seq_read_efuse_offload`).

**⭐ AKAR MASALAH YANG LEBIH DASAR (22 Okt 2026):** layout register EFUSE untuk
8188E **berbeda** dari OpenBSD:

| Register | Fungsi 8188E | OpenBSD (92C-style) |
|---|---|---|
| 0x030 | **DATA** | address (bit 8-17) + status (bit 31 = VALID) |
| 0x031 | address low | — |
| 0x032 | address high (2 bit) | — |
| 0x033 | status (bit7 = busy) | — |

OpenBSD menulis address ke **0x030** — padahal di 8188E itu register **DATA**.
Akibatnya `rtwn_efuse_read_1()` (OpenBSD) **tidak pernah mendapat bit VALID** →
selalu timeout → MAC tidak pernah terbaca → M1 gagal.

Implementasi jalur yang benar: `src/urtwn/rtwn_efuse_8188e.c`
(`rtwn_seq_read_efuse_direct_8188e()`), dengan fallback ke jalur offload.

**⭐ Urutan init vendor & tabel "power flow":** lihat
[`init-sequence-8188e.md`](init-sequence-8188e.md) — berisi urutan 42 langkah
`InitializeAdapter8188EUsb`, 9 tabel flow statis (power_on, hwpdn, radio_off,
card_enable/disable, suspend/resume, enter/leave_lps), format entri
`WL_PWR_CFG`, dan peta register. Tool dekoder: `tools/decode_flow_table.py`.
Implementasi flow: `src/urtwn/rtwn_flow.c` (`rtwn_flow_power_on_8188e()`).
Parser EFUSE juga ditulis ulang mengikuti vendor (2 perbedaan terdeteksi lewat
differential test) dan **terverifikasi identik** dengan transkripsi pseudocode Ghidra
(20.000 image acak, 0 perbedaan).

Tabel mask EFUSE asli 8188E (dari binary vendor `_Array_MP_8188E_MUSB`):
```
ff f3 00 00 00 00 00 00 00 00 0f f3 ff ff 30 00 00 00 f7 00 00 00 00 00 00 00 00 00 00 00
```

Detail lengkap: [`vendor-reverse.md`](vendor-reverse.md).

## 7c. Kontrak M2 & M4 (hasil riset statis 22 Okt 2026)

- **M2**: format frame USB 8188E **berbeda** dari OpenBSD (OpenBSD pakai
  `r92e_tx_desc_usb` = format 92E). Header RX = 24 byte + 2 byte konfigurabel
  (`GetRxPacketShiftBytes8188EUsb`). Descriptor TX harus ditulis ulang dari
  `TxFillDescriptor8188EUsb` (0x14ccb8).
- **M4**: kontrak frontend `AirportItlwm` = `ItlHalService` (7 method wajib) +
  `ItlDriverInfo` + `ItlDriverController`. Referensi implementasi: `ItlIwx`
  (13.871 baris) / `ItlIwn` (7.714 baris). net80211 (27.905 baris) **sudah siap**.
- Detail: [`m2-m4-contract.md`](m2-m4-contract.md).

## 7d. Status akhir riset statis (22 Okt 2026)

Semua backlog statis **selesai**. Ringkasan & rencana 1 reboot:
[`prereboot-readiness.md`](prereboot-readiness.md).

Fakta kunci tambahan (hasil decompilation):
* TX descriptor 8188E = `r92c_tx_desc_usb` (32 B) — **OpenBSD sudah benar**
* RX descriptor = `r92c_rx_desc_usb` (24 B) + 2 B — cocok `GetRxPacketShiftBytes` vendor
* H2C firmware pakai register yang sama dengan OpenBSD (0x1CC/0x1D0)
* Firmware `rtl8188eufw.bin` (linux) header `0x88e1` v1.28 — cocok loader OpenBSD
* Kontrak M4: `ItlHalService` (7 method) + `ItlDriverInfo` + `ItlDriverController`

## 7e. ⭐ Loop iterasi tanpa reboot (22 Okt 2026)

```bash
./scripts/iterate-no-reboot.sh
```

build → hot-swap ke kernel → cabut-colok dongle (2 dtk) → hasil. **±30 detik per
iterasi, tanpa reboot.**

Kunci:
* Driver **self-detach** setelah init → kext bisa di-unload → hot-swap selalu bisa
* Build default **AMAN** (`M1_ALLOW_USB_TRAFFIC=0`) → nol traffic USB, aman di ESP
* Varian **UJI** dibangun terpisah untuk hot-swap runtime
* Transport bulk (M2) sudah terpasang: `bulkOpen`/`bulkQueueRx`/`bulkSend` +
  parser descriptor RX (24+2 B) + parser SSID beacon

## 7f. ⭐ KOREKSI — user-space USB probe BISA (22 Okt 2026)

Bagian ini sebelumnya menyatakan "tidak mungkin". **Itu salah.** Penyebabnya
adalah cara membuka device yang keliru, bukan batasan macOS.

`IOServiceOpen()` pada `IOUSBDevice` memang mengembalikan
`kIOReturnNotOpen` (`0xe00002c7`) — tapi `IOServiceOpen` bukan API yang benar
untuk itu. Jalur yang benar adalah plugin IOKit:

```c
IOCreatePlugInInterfaceForService(svc,
    kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plug, &score);
(*plug)->QueryInterface(plug,
    CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID *)&dev);
(*plug)->Release(plug);
(*dev)->USBDeviceOpen(dev);          /* atau USBDeviceOpenSeize */
```

Setelah itu `DeviceRequest()` (vendor request `bRequest=0x05`) bekerja penuh
dari user space — **tanpa kext, tanpa reboot, tanpa risiko panic**.

Terbukti 22 Okt 2026 pada mesin ini:

```
device dibuka ✓ (config=1)
CR=0x0000063f  MCUFWDL=0x000300c6  SYS_CFG=0x244037b7
```

Konsekuensi: **seluruh M1/M2 bisa divalidasi dan diiterasi dari user space**
dalam hitungan detik. Satu-satunya syarat: driver kernel tidak memegang
device (kext kita self-detach, jadi tunggu ±10 dtk).

Detail & pemakaian: [`userspace-lab.md`](userspace-lab.md).

Catatan: `kmutil load` untuk kext baru tetap butuh reboot (batasan macOS 15),
tetapi **loop pengembangan tidak lagi bergantung pada kernel**.

## 7g. M3/M4: kode & peta (22 Okt 2026)

Sudah ditulis & **kompilasi + linked**:
* `src/driver/UsbBackend.{hpp,cpp}` — USB modern (claim interface, pipe bulk, transfer asinkron)
* `src/driver/ItlRtl8188E.{hpp,cpp}` — `ItlHalService` + `ItlDriverInfo` +
  `ItlDriverController` (interface yang dipakai frontend AirportItlwm)

Belum ditulis: **glue net80211** (~1.500–2.500 baris) & adaptasi frontend.
Detail + peta persis: [`m3-m4-integration.md`](m3-m4-integration.md).

**Rekomendasi urutan:** M1 (chip hidup) → M2 (bulk, scan) → M3a (net80211 scan) →
M3b (join/WPA2) → M4 (frontend → menu Wi-Fi native). Menulis M3/M4 sebelum M1
tervalidasi berisiko 2.000 baris kode buta.

## 8. Cara melanjutkan dengan aman (kalau mau lanjut lagi)

**Aturan emas: jangan pernah boot dengan build yang bisa melakukan traffic USB.**

### 8.1 Setup (aman)

```bash
cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport
./scripts/fetch-upstream.sh
./scripts/build-m1.sh          # menghasilkan build AMAN (inert) + build UJI
```

### 8.2 Uji tanpa menyentuh OpenCore

```bash
sudo ./scripts/vendor-off.sh          # matikan RtWlanU (node USB jadi bebas)
sudo kmutil load -z -p src/build-test/RTL8188EUM1.kext   # hot-swap varian UJI
# → cabut-colok dongle USB → driver attach → init jalan
./scripts/collect-m1-log.sh
```

### 8.2b ⭐ ARSITEKTUR FINAL: satu implementasi, dua tempat

```
        src/urtwn/rtwn_seq.c   ← LOGIKA M1, C portabel (tanpa IOKit, tanpa USB)
              │                    627 baris, kompilasi bersih dengan gcc/clang
              ├── tools/rtwn_probe.c  (user space, DeviceRequest)  → iterasi < 1 detik
              └── src/driver/…       (kernel, IOUSBHostPipe)     → kode IDENTIK
```

`rtwn_seq.c` berisi (semua di-port dari OpenBSD):
`read_regs` · `read_efuse` (EFUSE + MAC) · `power_on` (88E) ·
`dma_init` (LLT + queue mapping) · `load_firmware` (upload 8051 + checksum).

Semua I/O lewat callback `read/write`, jadi modul ini tidak tahu apa pun soal
IOKit maupun USB.

**Konsekuensi:** begitu `rtwn_seq.c` terverifikasi di user space, driver kernel
hanya perlu "mengantar paket" — logikanya sudah terbukti benar. Risiko kernel
hampir nol, dan **tidak ada reboot per iterasi**.

### 8.3 Kalau mau hasil paling aman: validasi protokol dari user space ✅ sudah ada

Alat: **`tools/rtwn_probe.c`** + **`src/urtwn/rtwn_seq.c`**

```bash
./scripts/build-probe.sh             # build probe (sekali)
sudo ./tools/rtwn_probe              # baca register saja (aman)
sudo ./tools/rtwn_probe --efuse      # + baca EFUSE (MAC)
sudo ./tools/rtwn_probe --full       # + power-on + LLT + upload firmware
sudo ./tools/rtwn_probe --write-test # uji tulis (baca → ubah → baca balik)
```

**Alur kerja tanpa banyak reboot:**

```bash
# sekali saja: bebaskan device dari driver vendor
sudo ./scripts/vendor-off.sh
sudo shutdown -r now

# SELURUH debugging protokol berikutnya: user space, tanpa reboot
sudo ./tools/rtwn_probe --full      # ubah kode → build → jalankan (detik)

# selesai: kembalikan Wi-Fi vendor
sudo ./scripts/vendor-on.sh
sudo shutdown -r now
```

Status per 21 Okt 2026: probe **sudah jalan** & menemukan device
(registry id `0xa07`); `IOServiceOpen` → `0xE00002C7` (*exclusive access*)
karena device masih dipegang kext kernel. Meaning: plumbing user-space
sudah benar; tinggal device dibebaskan.

Cara kerjanya: memakai API USB **legacy dari user space**
(`IOUSBDeviceInterface::DeviceRequest` — header `IOKit/usb/IOUSBLib.h`),
yaitu **persis** request yang dikirim driver OpenBSD & kext kernel kita:

```
bmRequestType 0xC0 (baca) / 0x40 (tulis), bRequest 0x05,
wValue = alamat register, wIndex 0, wLength 1/2/4
```

Status per 21 Okt 2026:
* ✅ Device **berhasil ditemukan** di IORegistry (id `0xa07`).
* ✅ Plumbing user-client **benar** (IOServiceOpen → connect → IOUSBDeviceInterface).
* ⛔ `IOServiceOpen` → `0xE00002C7` (*exclusive access*) karena device dipegang
  driver kernel (kext eksperimental kita, atau `RtWlanU`).
  → ** prerequisite: device harus bebas** (matikan driver vendor dulu).

Kalau probe berhasil membaca `CR`, `MACID`, `MCUFWDL`, `SYS_CFG` → **chip hidup &
encoding vendor request kita benar** → kernel driver tinggal memakai kode yang
sudah terbukti. Kalau timeout → masalahnya di encoding/keadaan chip, dan
diperbaiki **dalam hitungan detik tanpa risiko freeze kernel**.

Kebutuhan: `sudo ./scripts/vendor-off.sh` + reboot (supaya device tidak dipegang
driver mana pun), lalu jalankan probe.

### 8.4 Lockdown (kalau mau assure mesin tidak rusak)

Kurangi `IOProbeScore` personality sehingga driver tidak pernah match, atau
hapus `EFI/OC/Kexts/RTL8188EUM1.kext` (build AMAN sudah inert, jadi aman
dibiarkan di ESP).

---

## 9. Status saat ini (setelah restore + reboot 22 Okt)

| Item | Status |
|---|---|
| Kext eksperimental di OpenCore | **Dihapus** ✓ (`Kernel → Add` = 12 entri, tanpa RTL8188EUM1) |
| `EFI/OC/Kexts/RTL8188EUM1.kext` | **Dihapus** ✓ |
| `RtWlanU.kext` + `RtWlanU1827.kext` | **Dikembalikan** ke `/Library/Extensions` ✓ |
| AuxiliaryKernelExtensions.kc | Dibangun ulang, berisi RtWlanU ✓, **tanpa** kext kita ✓ |
| Driver vendor aktif | **AKTIF** ✓ (`kextstat` index 157) |
| Wi-Fi + aplikasi vendor | **JALAN** ✓ — aplikasi vendor (PID 482) hidup |
| Dongle USB | **TERDETEKSI** ✓ — `802.11n NIC` 2357:010c, serial `00E04C0001` |
| Interface dari dongle | **`en2`** — MAC `98:03:8e:9e:bc:24`, `status: active` |
| Jaringan | **TERHUBUNG** ✓ — IP `192.168.1.235`, gateway `192.168.1.1`, default route via `en2` |
| Throughput | 1.5–2.0 MB/s ≈ **12–16 Mbps** |
| Native IO80211? | ❌ belum (`IO80211Interface` = 0) → **tujuan asli belum tercapai** |
| Panic setelah reboot? | **Tidak ada** ✓ (terakhir tetap 22 Okt 02:51 = panic #3 yang lama) |
| Backup ESP | `backup/EFI-BIG-*.tar.gz`, `backup/config.plist.*.bak` |
| Backup config.plist | `backup/config.plist.pre-restore.*.bak` |

**Penting:** driver vendor Realtek **tidak bisa "di-offload"** dengan aman dari
runtime (kext "in use"), jadi restart laptop adalah cara paling aman untuk
memastikan Wi-Fi kembali.

---

## 10. Peta file dokumentasi

| File | Isi |
|---|---|
| `docs/HANDOVER.md` | **Dokumen ini** — rujukan tunggal |
| `docs/references.md` | katalog referensi (60+ tautan terverifikasi) |
| `docs/architecture.md` | desain lapisan & alur data |
| `docs/porting-notes.md` | peta API OpenBSD → IOKit, peta fungsi per milestone |
| `docs/milestone-m1.md` | detail M1 + kronologi panic + cara memicu match |
| `docs/testing.md` | setup uji, kdp, rescue plan |
| `docs/vendor-driver-notes.md` | anatomi stack vendor Realtek |
| `docs/efi-layout.md` | peta partisi & OpenCore |
| `docs/legal.md` | lisensi & implikasi distribusi |
| `docs/roadmap.md` | milestone M0–M7 + go/no-go |

---

## 11. ⭐ TEMUAN PENTING (22 Okt, setelah reboot) — driver VENDOR mendukung RTL8188EUS

Ternyata setelah reboot, driver vendor Realtek (`RtWlanU` 1830.32.b27) **berhasil
meng klaim** node USB `802.11n NIC` (VID 0x2357 / PID 0x010c, serial `00E04C0001`)
dan **membuat interface `en2` dengan MAC dongle** `98:03:8e:9e:bc:24`:

```
ioreg:  +-o AppleUSBInterface@0
          +-o RtWlanU  <class RtWlanU, ...>       ← vendor claim interface

| `docs/audit-hardening.md` | **Audit keamanan + 17 temuan + perbaikannya** |

| `docs/re-8188e-efuse.md` | **RE EFUSE 8188E (decompilation vendor, 3 bug ditemukan)** |

| `docs/m4-airport-integration.md` | **Rencana M4 — integrasi IO80211 native (referensi Airport_RTW88)** |
```

Hasil pengukuran:

| Item | Nilai |
|---|---|
| Interface | `en2` (`Hardware Port: 802.11n NIC`) |
| Status | `status: active`, `media: autoselect` |
| IP | `192.168.1.235/24`, gateway `192.168.1.1` |
| Default route | **lewat `en2`** (dongle = jalur internet utama) |
| Ping gateway | 2.9 ms, 0% loss |
| HTTP | `200 OK` dari apple.com, DNS 6 ms |
| Throughput | 1.5–2.0 MB/s ≈ **12–16 Mbps** |
| `IO80211Interface` | **0** → BUKAN native IO80211 |

### Arti temuannya

1. **Chip ini didukung penuh oleh driver vendor.** Kita **tidak** butuh
   reverse-engineering tambahan atau firmware blob untuk fungsionalitas dasar.
2. Tapi karena `IO80211Interface` = 0, driver ini **tidak muncul di menu Wi-Fi
   macOS** — ia behave seperti adapter Ethernet USB biasa. Memilih jaringan
   harus lewat aplikasi vendor (`StatusBarApp`, PID berjalan) atau `networksetup`.
   → **Inilah gap yang harus ditutup oleh driver kita sendiri** (port `urtwn`
   + `net80211` itlwm → interface IO80211 native).
3. Konsekuensi "satu node, satu driver" tetap berlaku: driver kita **tidak
   bisa attach bersamaan** dengan `RtWlanU`. Development harus memakai
   `scripts/vendor-off.sh` → `…` → `scripts/vendor-on.sh` (sudah ada & teruji).
4. **Plan B sekarang benar-benar berfungsi** → Pengguna bisa
   jaringan saat development, tanpa perlu tethering USB lagi.

### Strategi yang direkomendasikan

| Langkah | Isi |
|---|---|
| 1 | Jaga driver vendor sebagai plan B (sudah jalan, ~13–16 Mbps) |
| 2 | Development driver kernel **hanya** di window uji yang disepakati (vendor off → uji → vendor on) |
| 3 | Validasi **read-only** lebih dulu (baca register EFUSE) sebelum ada write |
| 4 | M2 (bulk TX/RX) pakai `IOMemoryDescriptor` **konsisten** di semua jalur |
| 5 | M3/M4 (net80211) = kode terbesar & berisiko → postpone sampai M1/M2 benar-benar tervalidasi |

---

## 13. 🛡️ Audit & Hardening (22 Okt 2026) — ringkasan

Dokumen lengkap: **[`docs/audit-hardening.md`](audit-hardening.md)**

### Akar panic #1/#2/#3 (SEMUAternyata satu keluarga)

```c
// src/driver/RTL8188EUM1.cpp (SEBELUM)
while ((obj = it->getNextObject())) {
    IOUSBHostInterface *i = OSDynamicCast(IOUSBHostInterface, obj);
    if (i) {
        found = i;       // ← tanpa retain()
        obj->release();  // ← OVER-RELEASE (objek milik collection!)
        break;
    }
    obj->release();      // ← OVER-RELEASE
}
it->release();
return found;            // ← dangling pointer
```

Kontrak IOKit (`OSIterator.h:114`): *"The returned object will be released
if removed from the collection; if you plan to store the reference, you
should call `retain()`"*.

→ `obj->release()` = decrement refcount milik orang lain → **double free**
→ *"A kext releasing a(n) X has corrupted the registry"*.
→ `found` tanpa `retain()` = **use-after-free** saat `deviceRequest()`.

**Offset panic berbeda-beda (0x329, 0x329, 0x278)** karena korupsinya
terdeteksi di release *berikutnya* yang kebetulan menyentuh objek rusak —
bukan di tempat kerusakannya.

### Ringkasan 40 temuan (2 ronde audit)

| Severity | Jumlah | Contoh |
|---|---|---|
| 🔴 CRITICAL | 3 | over-release iterator, dangling pointer interface, OOB write (`rtwn_seq_efuse.c`) |
| 🟠 HIGH | 5 | `PKTLEN` chip tanpa validasi (OOB read 14 KB), `RTWN_DELAY_MS` no-op, loop EFUSE terpotong, timeout disamar jadi data, firmware 196 B ditolak |
| 🟡 MEDIUM | 6 | divide-by-zero di kernel, flow table tanpa batas, indeks wraparound, API tanpa ukuran |
| 🔵 LOW | 3 | slot TX tak terinisialisasi, helper mati & salah, delay 18 jam |

**Semua sudah diperbaiki.** Test suite: `✅ SEMUA TEST LULUS`
(termasuk test keamanan baru `tools/test_seq_safety.c`).

### Aturan baru

| # | Aturan |
|---|---|
| A11 | Objek dari `getNextObject()` milik collection — jangan `release()`, `retain()` dulu kalau mau disimpan |
| A12 | Panjang dari descriptor USB harus divalidasi terhadap ukuran buffer nyata, di setiap lapisan |
| A13 | Di kernel "menunggu" = `IOSleep` (memblok thread), bukan `IODelay` (busy-wait) |
| A14 | Timeout harus bisa dibedakan dari data yang sah (0xff bukan penanda error) |
| A15 | Guard pembagian dengan nol di setiap modulo — `SIGFPE` di kernel = panic |
| A16 | Panjang dari device harus punya batas keras sebelum jadi jumlah iterasi |


---

## 14. Pertanyaan yang masih terbuka (untuk sesi berikutnya)

1. **Apakah chip 8188EUS menjawab vendor request kita?** (inti; belum terjawab)
   → uji dari user space lebih aman.
2. **Apakah `rtwn_efuse_read` menghasilkan MAC yang cocok** dengan
   `98:03:8e:9e:bc:24`?
3. **Apakah upload firmware 8051 berhasil** (checksum report OK)?
4. **Berapa lama transfer control benar-benar?** (untuk menentukan timeout yang
   aman — sekarang 250 ms).
5. **Apakah `IOUSBHostInterface::deviceRequest` diperlukan** (bukan
   `IOUSBHostDevice::deviceRequest`)?
6. **Bagaimana memicu WPA2** — Apple WCL harus melakukan 4-way handshake; perlu
   dipastikan alur EAPOL diteruskan dua arah.

---

*Dokumen ini dibuat 21 Okt 2026. Semua temuan di dalamnya berasal dari
eksperimen langsung pada mesin ini, bukan dari dokumentasi pihak ketiga.*

---

## 15. ⭐ M1 **SELESAI** — chip hidup (22 Okt 2026, 04:15)

Ronde uji pertama yang **tidak panic** dan **menembus sampai akhir**:

```
04:14:58  usb-ok
04:14:59  power-on → power-on-ok            ✅ flow vendor 11 entri, <1 detik
04:14:59  efuse-direct → efuse-direct-gagal  (1 dtk — gagal cepat, bukan macet)
04:15:00  efuse-offload → efuse-offload-ok   ✅ 5 detik (sebelumnya 38 detik!)
04:15:05  dma-init → LLT/DMA OK              ✅
04:15:09  firmware → ok                     ✅ UPLOAD FIRMWARE 8051 BERHASIL
04:15:12  usb-bulk → set-mac → SELESAI      ✅
04:15:12  self-detach
```

### Yang tervalidasi

| Komponen | Status |
|---|---|
| Transport USB (vendor request 0x05) | ✅ terbukti |
| `setConfiguration` + open device | ✅ |
| Baca register chip (chipid) | ✅ |
| Power-on flow vendor (11 entri) | ✅ <1 detik |
| Inisialisasi LLT/DMA | ✅ |
| **Upload firmware 8051 (15 KB, H2C)** | ✅ (lewat fallback tulis 4 byte) |
| Pipe bulk USB + antrean RX | ✅ |
| Tulis MAC ke chip | ✅ (tapi MAC-nya masih 0xff) |

### 4 temuan dari ronde ini

| # | Temuan | Perbaikan |
|---|---|---|
| 1 | **EFUSE offload butuh firmware** — vendor 42 langkah: offload = #31, firmware = #13. Ours baca EFUSE sebelum firmware → 8051 kosong → data 0xff | Urutan diubah: power-on → DMA → **firmware** → **EFUSE** |
| 2 | **Boot-arg tidak terbaca** — `PE_parse_boot_argn` tidak menemukan `-rtl8188eum1_mode=poweron` padahal `kern.bootargs` menunjukkannya | Mode jadi **compile-time** (`-DM1_TEST_MODE=N`), bukan boot-arg |
| 3 | **`run-tests.sh` menimpa varian UJI** dengan mode default `full` (build script tanpa `MODE`) | Varian UJI hanya dibangun bila `MODE` diisi eksplisit |
| 4 | Tulis firmware 196 byte ditolak chip | **Fallback**: pecah jadi blok 4 byte (register file bisa diakses per byte) |

### Sisa masalah M1

| Item | Status |
|---|---|
| MAC dari EFUSE | masih `ff:ff:ff:ff:ff:ff` — hopefully-fixed oleh urutan baru (offload setelah firmware) |
| xtal | masih `0xff` |
| RX frame | `ok=0 bad=0 bytes=0` — normal, belum ada scan |

### Tooling iterasi (sekarang mature)

```bash
# 1. build varian UJI dengan mode yang diinginkan
MODE=poweron ./scripts/build-m1.sh

# 2. pasang ke ESP + matikan vendor
sudo env ALLOW_BOOT_INJECTION=1 MODE=poweron ./scripts/install-test-esp.sh

# 3. reboot → tunggu 60 dtk → colok-cabut dongle

# 4. LaunchDaemon menangkap marker otomatis (bertahan 15 menit setelah boot)
cat logs/watch-*.log | tail -1

# 5. kembalikan semuanya
sudo ./scripts/restore-test-esp.sh && reboot
```


---

## 16. ⭐⭐ M1c **SELESAI** — MAC terbaca dari chip (22 Okt 2026)

**Hasil:** `MAC = 98:03:8e:9e:bc:24`, `xtal=0x2f`, `channel_plan=0xa1`,
`rf_board_opt=0x01` — dibaca **langsung dari chip**, diverifikasi silang
dengan driver vendor.

### Dua akar masalah (keduanya ditemukan & diperbaiki)

| # | Masalah | Akar | Perbaikan |
|---|---|---|---|
| 1 | Reset 8051 memakai register chip lain | `HAL_8051PauseIOWrapper` memilih register per `cardType`; kita memakai cabang `0x32` (`0x093`) padahal 8188E (`0x0e`) memakai `0x1c/0x1d/0x03` | `efuse_8051_pause_style`/`enable_style` (GRP A, GRP B, 0x32), 8 kombinasi mode × gaya |
| 2 | Parser EFUSE salah semantik | (a) `ri++` ganda → data mulai `raw[2]`; (b) bit mask SET dianggap 1 byte data, padahal **ABSENT (0 byte)** | `efuse_parse_8188e` ditulis ulang; golden test `tools/test_efuse_real.c` |

### Bukti (dump nyata, 4 field independen cocok)

```
offset   0 : 29 81                → EEPROM ID 0x8129
offset 208 : 57 23 0c 01          → VID 0x2357, PID 0x010c
offset 215 : 98 03 8e 9e bc 24    → MAC
offset 223 : "Realtek"
offset 232 : "802.11n "
```

### Terobosan metode: lab user space

`tools/rtwn_probe` sekarang **benar-benar bisa membuka device** (sebelumnya
salah API). Ini menghapus kebutuhan reboot untuk setiap iterasi:
`sudo ./tools/rtwn_probe --efuse-all` → hasil dalam detik.
Lihat [`userspace-lab.md`](userspace-lab.md).

### Status tiap milestone

| Milestone | Status |
|---|---|
| M1 — chip hidup (power-on, LLT, firmware) | ✅ |
| M1c — MAC/xtal dari EFUSE | ✅ **22 Okt 2026** |
| M1d — HAL tables (2.446 entri) | ✅ siap (belum dijalankan di chip) |
| M2 — scan (probe request + RX beacon) | ✅ **22 Okt 2026 — terbukti di hardware** |
| M3 — assoc/WPA2 | ⬜ |
| M4 — integrasi IO80211 | 🟡 peta + template `upstream/Airport_RTW88` |

### Catatan penting tentang jalur EFUSE

- **OFFLOAD = primer** (berhasil, MAC benar).
- **DIRECT = cadangan** — kadang gagal 1 byte (flaky); jangan dijadikan
  satu-satunya sumber.
- `MACID` register `0x610` = `00:00:00:00:00:00` (kosong; bukan sumber MAC).


---

## 17. ⭐⭐ M2 **SELESAI** — scan 802.11 nyata dari user space (22 Okt 2026)

**Hasil:** `sudo ./tools/rtwn_probe --scan 1 13` mengirim probe request lewat
bulk OUT dan menerima beacon/probe response lewat bulk IN. SSID nyata terbaca:

```
ch  1  90:56:de:46:a7:24  ZEKRI.NET
ch  1  28:6e:da:06:4e:18  Homesans
ch  4  50:5b:1d:b6:0c:32  KUSUMA
ch  5  a4:f3:3b:14:d9:b4  Qurha.com
ch  6  24:46:e4:e2:cd:cc  RIYAN
ch  7  0c:37:47:9c:62:77  Ramodal
ch  9  50:5b:1d:b6:ab:fa  Sutopo
ch 11  a6:d9:90:4d:91:33  Vii
```

TX terbukti (bukan hanya mendengar pasif): probe response tertangkap dengan
`addr1 = 98:03:8e:9e:bc:24` (MAC kita), `addr2` = BSSID AP.

### Yang ditambahkan

| File | Isi |
|---|---|
| `src/urtwn/rtwn_init_8188e.{h,c}` | init MAC (91 reg) + BB/AGC (320 reg) + RF chain 0 (91 reg) + core config, semua dari tabel OpenBSD `r92creg.h` |
| `src/urtwn/rtwn_usb.c` | `rtwn_usb_build_mgmt_tx_desc` (QSEL=MGNT, RAID=11B, HWSEQ, DRVRATE) + `rtwn_usb_tx_checksum` |
| `tools/rtwn_probe.c` | buka `IOUSBInterface`, pipe bulk IN/OUT, `--scan [ch1] [ch2]`, dump frame |
| `src/urtwn/rtwn_platform.h` | `RTWN_DELAY_US` (LSSI butuh timing µs) |

### Bug yang diperbaiki

1. **Parser SSID** — elemen beacon mulai offset **36** (24 header + 12 field
   tetap), bukan 24. Probe request tetap 24.
2. **Checksum descriptor TX** — XOR 16 word pertama, simpan di word 14.
3. **Offset frame RX** — pakai `infosz` dari descriptor (nyata: 32), frame
   mulai 24+32 = 56. Satu transfer bisa berisi beberapa paket (agregasi).
4. **Sisa paket kanal lama** — drain bulk IN setelah ganti kanal.

### ⚠️ Risiko: dongle lepas dari bus

Saat uji berulang, macOS mencatat
`AppleUSBHostPort::terminateDevice ... hardware connection lost`.
Perangkat hilang dari bus (bukan panic). Dugaan: TX power default terlalu
tinggi (tabel `phy_reg_pg`/`txpwr_lmt` belum diterapkan) atau firmware
di-upload ulang setiap run. Mitigasi ada di `docs/m2-scan.md` §5.
Sementara: jangan scan berulang tanpa jeda; siapkan colok ulang fisik.

### Rujukan

- [`m2-scan.md`](m2-scan.md) — arsitektur, format descriptor, bukti, risiko.
- [`userspace-lab.md`](userspace-lab.md) §5 — cara pakai.


---

## 18. ⭐ M4 — kerangka kext IO80211/Skywalk BERHASIL DI-BUILD (22 Okt 2026)

**Status:** kext `RTL8188EAirport.kext` **kompilasi + link + tanda tangan
selesai** (x86_64). `kextutil -t` membuktikan **seluruh simbol bind** ke
IO80211Family V2 / IOSkywalkFamily / IOUSBHostFamily di macOS 15.8.1;
satu-satunya penolakan adalah kebijakan *"not approved to load"* (sama seperti
M1 — diatasi lewat injeksi OpenCore/BootKC). **Belum diuji di hardware**
(dongle sedang tidak tercolok).

### Arsitektur (3 lapis)

```
IOUSBHostInterface 2357:010c
   └─ IOPCIEDeviceWrapper   (src/airport/IOPCIEDeviceWrapper.cpp)
        └─ ItlRtl8188E      (src/driver/ItlRtl8188E.cpp)
             └─ net80211 + rtwn_seq/init/usb (kode M1/M2)
   └─ AirportItlwm V2       (src/airport/AirportItlwm.cpp)
        └─ IO80211Controller / Skywalk → menu Wi-Fi native
```

- Personality pertama menempel di **IOUSBHostInterface**, membuat HAL,
  lalu `registerService()`.
- Personality kedua (`AirportItlwm`) menempel di wrapper — pola yang sama
  dengan AirportItlwm PCIe, tetapi `pciNub = nullptr`.
- Semua panggilan PCI di frontend dibungkus `if (pciNub)`; `probe()` tidak
  lagi menolak provider non-PCI.

### Flag build Sequoia (WAJIB)

```
-DAIRPORT_WCL -DAIRPORT_VTD -D__IO80211_TARGET=__MAC_15_2
-DIO80211FAMILY_V2 -D__PRIVATE_SPI__ -DAIRPORT -DIEEE80211_STA_ONLY
```

M4 **membuang `-DAIRPORT_VTD`** (tidak memakai ItlDma). Seluruh `.c`
net80211 dikompilasi sebagai **C++** (`clang++ -x c++`) meniru
`GCC_INPUT_FILETYPE = sourcecode.cpp.cpp` milik Xcode.

### Yang sudah jalan di build

| Cek | Hasil |
|---|---|
| `./scripts/build-m4.sh` | rc=0 → `src/driver/build-m4/RTL8188EAirport.kext` |
| Frontend V2 (AirportItlwm, Skywalk, Ethernet, WCL) | 0 error |
| net80211 + crypto + support | 0 error |
| Link | hanya undefined simbol kernel/IO80211 (normal, `-undefined dynamic_lookup`) |
| Bind simbol (`kextutil -t`) | **OK semua**, berhenti di approval |
| Uji hardware | ⏳ menunggu dongle + 1 reboot |

### Fitur HAL saat ini

- Init chip lengkap: power-on → LLT/DMA → firmware 15.262 B → EFUSE →
  MAC/BB/RF/core config (dari M1/M2 yang sudah terbukti).
- net80211 attach, `if_ioctl=ieee80211_ioctl`, media init.
- Scan: `newstate(SCAN)` → set kanal → timer 120 ms → `ieee80211_next_scan`.
- TX mgmt (probe/auth/assoc) dan data lewat bulk OUT; descriptor 32 B dengan
  DRVRATE + HWSEQ; laju dipaku **1 Mb/s CCK**.
- RX: parse descriptor 24 B + `infosz` → mbuf → `ieee80211_inputm`;
  RSSI dihitung dari PHY status (`rtwn_r88e_get_rssi`, CCK/OFDM).
  Callback USB hanya menyalin frame ke ring 64 slot; pemrosesan net80211
  dijadwalkan ke workloop IO80211 lewat timer 0 ms (hindari race/deadlock).
- Kripto **software** (CCMP/TKIP/WEP) via net80211 — belum ada offload.
- `enable()` menyalakan `IFF_UP|IFF_RUNNING` lalu mulai scan;
  `disable()` membereskan timer dan state.

### Perintah

```bash
./scripts/build-m4.sh                          # build + sign
ALLOW_BOOT_INJECTION=1 sudo ./scripts/install-m4-esp.sh   # pasang (buang M1)
# reboot (satu-satunya langkah yang belum bisa dihindari)
kextstat | grep RTL8188EAirport
ioreg -r -c ItlRtl8188E -w0 | head -30
networksetup -listallhardwareports | grep -A2 -i wi-fi
```

### Audit pra-reboot (tanpa hardware)

Bug kritis yang ditemukan dan diperbaiki sebelum uji reboot:

| Bug | Akibat | Perbaikan |
|---|---|---|
| `if_watchdog` NULL | `watchdogAction` memanggil NULL 1 detik setelah Wi-Fi ON → panic | pasang `watchdogCb` |
| tabel kanal kosong | scan tidak pernah mengunjungi kanal (menu kosong) | isi `ic_channels[1..13]` sebelum ifattach |
| RX mulai sebelum net80211 | frame awal → `ic_bss == NULL` → panic | RX dimulai setelah ifattach |
| RX di workloop USB | race + risiko deadlock control transfer | ring buffer + timer 0 ms di workloop IO80211 |
| `free()` tanpa ifdetach | timer net80211 menembak memori bebas | `fIfAttached` + ifdetach di `free()` |
| `sendFrame` error path | mbuf + node bocor | lepas `ni`/`m` di semua jalur |
| offset RX +2 | stride salah, paket berikutnya dibuang | format OpenBSD `24+infosz` |
| scan tanpa jeda | TX probe terus-menerus (risiko bus drop) | jeda 800 ms di kanal 1 tiap siklus |
| HT/AMPDU diiklankan | jalur belum didukung | HT dimatikan untuk uji pertama |
| install script | config rusak tidak dipulihkan | rollback otomatis + verifikasi executable |
| laporan C2H di RX | sampah firmware dianggap frame 802.11 | filter `R92E_RXDW2_RPT_C2H`; `CCX_RPT` dimatikan |

### Audit putaran kedua (TX/RX/lifecycle) — semua sudah diperbaiki

| Bug | Akibat | Perbaikan |
|---|---|---|
| `DRVRATE`/`HWSEQ` ditulis ke `txdw3` | frame data tanpa rate/seq benar → TX macet | tulis ke `txdw4` (byte 16–19): `0x0180` non-QoS / `0x0140` QoS, `txdseq` benar |
| `mbuf_pullup` gagal → `mbuf_freem(m)` | Apple API sudah membebaskan chain → **double free** | hapus free di jalur gagal |
| `ieee80211_encrypt` gagal → `mbuf_freem(m)` | encrypt sudah membebaskan `m0` → double free | hapus free di jalur gagal |
| filter TX report pakai `RXDW2` bit 28 | field C2H milik 92E, bukan 88E | hanya `RXDW3` bit 14–15 |
| PHYST dicek di bit 20 | RSSI tidak pernah terbaca | `R92C_RXDW0_PHYST` bit 26 |
| RSSI dBm mentah → `u8` | nilai negatif wrap (206) | normalisasi `clamp(dbm+100, 0, 100)` |
| frame CRC/ICV ikut diproses | net80211 menerima frame korup | drop sebelum `ieee80211_inputm` |
| `releaseAll` melepas HAL sebelum timer | watchdog/scan menembak memori bebas | timer dibatalkan/dihapus dulu, HAL terakhir |
| watchdog di workloop terpisah | race dengan RX (state/free node) | watchdog dipindah ke `_fWorkloop` yang sama |
| `watchdogCb` tidak memanggil net80211 | auth/assoc timeout tidak retry | panggil `ieee80211_watchdog(ifp)` |
| base member belum di-zero saat `free()` awal | release pointer sampah | `ItlHalService::init()` men-zero semua |
| teardown RX tidak sinkron | callback menyentuh lock/timer bebas | callback null + `bulkClose()` sebelum free |
| `restore-test-esp.sh` belum M4-aware | rollback bisa menyisakan M4/M1 | deteksi ESP + hapus kedua bundle + perbaiki boot-arg |
| tanpa diagnostik boot | `log show` rusak | properti ioreg `RTL8188E-*` |

Status build terbaru: `./scripts/build-m4.sh` rc=0 (946 undefined dynamic
symbols), `kextutil -t` hanya berhenti di *"not approved to load"*,
`./scripts/run-tests.sh` → **SEMUA TEST LULUS**.

### Risiko / yang belum

1. Asosiasi/WPA2 belum diuji; jalur RUN masih minimal (RCR menerima semua,
   belum set BSSID/EDCA, tanpa rate control/AMPDU).
2. TX 1 Mb/s → lambat; rate adaptation menyusul.
3. RSSI sudah dihitung tetapi belum dikalibrasi terhadap hardware nyata.
4. Mitigasi TX-power hardware belum ada; scan loop sudah diberi jeda 800 ms
   di kanal 1, tetapi uji data berkelanjutan masih berisiko bus drop.
5. `install-m4-esp.sh` menghapus M1 dari ESP; rollback dengan
   `restore-test-esp.sh` atau pasang ulang M1.

Dokumentasi lengkap: [`m4-airport-integration.md`](m4-airport-integration.md).
