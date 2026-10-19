# Dukungan dan Proses MediaTek Kartu Jaringan Nirkabel (MT7921 / MT7922 / RZ608) di macOS

> ★★★ **Pembaruan besar 2026-10: macOS 26 (Tahoe) sudah menyertakan driver MediaTek milik Apple sendiri secara native**
> (`com.apple.AppleSunriseWLAN.dext` + `com.apple.AppleSunriseBluetooth.dext`, **firmware bawaan**) —
> **prioritaskan rute native**, lihat §0.3 / §1.5; repositori pihak ketiga di bawah ini adalah **jalan mundur**.
>
> Tiga repositori `laobamac` (author yang sama, juga author fork Intel nirkabel yang dipakai di skill ini) dari upstream (rute pihak ketiga):
> - **Wi-Fi (PCIe)**: `laobamac/SimpleMtkWlan` — *"An experimental macOS kernel extension for MediaTek MT792x PCIe wireless adapters."*
> - **Bluetooth (USB)**: `laobamac/SimpleMtkBtFw` — *"a MediaTek USB Bluetooth driver for macOS"*
> - **Klien Wi-Fi**: `laobamac/SimpleMTKClient` — App menu bar (`SimpleMTK`)
>
> ★★ **Perkembangan praktis sejak 2026-10-13: untuk Wi-Fi pihak ketiga gunakan fork `flxxxxddd/SimpleMtkWlan`**
> (fork dari repositori upstream laobamac, cabang **`mt7921-fixes`**, **memiliki release yang dibangun CI**) — ia memperbaiki masalah "MT7921 / RZ608 bisa attach tapi lalu lintas data gagal",
> serta menambahkan **802.11n (HT20/40) + 802.11ac (VHT80)**. Lihat §4.
>
> ★★★ **2026-10-16: rute native sudah ada paketnya — `GeekAudio/mediatek-sunrise-hackintosh` (MT7922 Sunrise Pack)**
> Ini mengumpulkan semua yang sebelumnya tersebar di lampiran thread tonymacx86: **firmware Wi-Fi MT7922**
> (linux-firmware resmi + SHA256SUMS) · **dua versi `AppleSunrise.kext` yang diekstrak apa adanya dari KDK**
> (26.7.1/25G241 dan 26.3/25D5087f) · **`SSDT-ARPT_RP04_Mediatek.aml`** · **fragmen penyamaran `DeviceProperties` tanpa kompilasi** · fragmen `Kernel>Add` · daftar boot-args · set lengkap kext pihak ketiga untuk macOS 15 (termasuk **SimpleMTK.app yang sudah dikompilasi**).
> ⇒ **Untuk memakai rute native Sunrise, ambil paket ini dulu**, tidak perlu menggali thread 69 halaman untuk lampiran. Lihat §1.5.

## 0. ★★★ Kesimpulan lebih dulu (bagian ini bisa menghemat banyak waktu)

### 0.1 macOS 26 sudah menyertakan driver MediaTek bawaan — ini rute pilihan utama

**macOS 26 (Tahoe) membawa driver MediaTek milik Apple sendiri**, tanpa perlu kext pihak ketiga apa pun:

```
/System/Library/DriverExtensions/
├── com.apple.AppleSunriseWLAN.dext        ← Wi-Fi (kode Sunrise)
└── com.apple.AppleSunriseBluetooth.dext   ← Bluetooth (★ firmware bawaan)
```

Kondisi pencocokan `Info.plist` keduanya (**terbaca nyata di macOS 26.7.1 mesin ini**):

| dext | `IOProviderClass` | `IOPCIMatch` | Chip yang sesuai |
|---|---|---|---|
| `AppleSunriseWLAN` | `IOPCIDevice` | `0x792214c3` `0x792314c3` `0x793214c3` | **MT7922** / MT7923 / MT7932 (Wi-Fi) |
| `AppleSunriseBluetooth` | `IOPCIDevice` | `0x792a14c3` `0x792b14c3` `0x793b14c3` | Bluetooth **MT7922** / MT7923 / MT793b |

★★ **Pemahaman penting: `AppleSunriseBluetooth` mencocokkan `IOPCIDevice` (PCIe), bukan USB!**
Artinya **pada modul MediaTek yang lebih baru, Bluetooth terpasang di PCIe** (`14c3:792a`) —
ini **berbeda dua generasi bentuk perangkat keras** dari asumsi rute pihak ketiga di bawah yang menganggap "Bluetooth = perangkat USB", jangan campur.

**Firmware bawaan di dalam dext** (ada di dalam direktori dext, **tidak ada** direktori MediaTek di bawah `/usr/share/firmware/`):

```
com.apple.AppleSunriseBluetooth.dext/
├── BT_RAM_CODE_MT7922_1_1_hdr.bin        576 KB  ← firmware Bluetooth MT7922
└── BT_RAM_CODE_MT7923_1_1_hdr_ipc.bin    437 KB

com.apple.AppleSunriseWLAN.dext/IZUBA/            ← satu set lengkap firmware Wi-Fi MT7932
├── IZUBA_WIFI_MT7932_patch_mcu_1_2_hdr.bin
├── IZUBA_WIFI_RAM_CODE_MT7932_1_2_idxlog.bin
├── IZUBA_EEPROM_MT7932_1.bin · IZUBA_WIFI_MFG_MT7932_2.bin
└── IZUBA_TxPwrLimit_*.dat · IZUBA_wifi.cfg · IZUBA_db.dat …
```

**`bluetoothd` juga memuat string MediaTek** (menandakan stack Bluetooth itu sendiri mengenali chip-chip ini):

```
BT_RAM_CODE_MT7922 · MT7923 · MT7923A0 · SRS_7922
```

> **`SRS` = SunRise** — `SRS_7922` adalah kode MT7922 di Sunrise.

★★ **Hasil uji nyata tambahan 2026-10-16 (mesin ini 26.7.1/25G241)**: "di 26.7.1+ tidak perlu memasang apa pun" hanya benar setengah:
- **dext Bluetooth sudah memuat** `BT_RAM_CODE_MT7922_1_1_hdr.bin` (+MT7923) → Bluetooth di 26.7.1 tanpa tindakan tambahan ✅
- **`IZUBA/` pada dext WLAN hanya punya satu set firmware Wi-Fi MT7932**, `find … -iname '*7922*'` kosong ⇒
  **firmware Wi-Fi MT7922 masih hilang di 26.7.1**, "upgrade tanpa menulis firmware" tidak berlaku untuk Wi-Fi MT7922, tetapi berlaku untuk MT7932
- `AppleSunrise.kext` di 26.7.1 masih **tidak ada** di `/System/Library/Extensions`, hanya ada di KDK;
  KDK bisa diambil dari mirror GitHub Dortania (`dortania/KdkSupportPkg/releases`, pilih sesuai build number),
  cara ekstraksi: `hdiutil attach` KDK.dmg → `pkgutil --expand-full KernelDebugKit.pkg` →
  `KDK.pkg/Payload/System/Library/Extensions/AppleSunrise.kext` (x86_64+arm64e, LSMinimumSystemVersion 26.7)

### 0.2 Cara memilih di antara tiga rute

| Rute | Bluetooth | Wi-Fi | Prasyarat |
|---|---|---|---|
| **① Native (Sunrise)** | ✅ **bawaan Apple** | ✅ **bawaan Apple** | **macOS 26+** (Sequoia tidak punya kedua dext ini) |
| ② pihak ketiga `SimpleMtkBtFw` | ✅ ada release | — | modul lama dengan Bluetooth melalui **USB** |
| ③ pihak ketiga `flxxxxddd/SimpleMtkWlan` | — | ⚠️ **bisa dipakai tapi tidak native** (**ada release v1.2.0**) | menerima "interface bergaya Ethernet + klien menu bar" |

> ★★ **Coba dulu rute ①** — sudah ada di sistem, **tidak perlu memasang kext apa pun**.
> Turun ke ②/③ hanya jika "modul Anda Bluetooth-nya melalui USB (tipe lama)" atau "sistemnya Sequoia".
>
> Tingkat kematangan rute pihak ketiga (sebagai perbandingan):

| Komponen | Status rute pihak ketiga | Dasar |
|---|---|---|
| Bluetooth (USB) | Bisa dipakai | `SimpleMtkBtFw` punya release **`1.0.0`**; judul issue #1 persis *"MT7922 bluetooth is working"* (fork: `flxxxxddd/SimpleMtkBtFw`, audio AirPods berfungsi) |
| Wi-Fi (PCIe) | ★ **bisa dipakai, tapi ada batasan keras** (sejak 2026-10) | fork `flxxxxddd` punya **release v1.1.0 / v1.2.0**; **MT7921 / RZ608 terbukti bisa terhubung ke internet**; tetapi **802.11ax tidak didukung**, **tidak ada menu Wi-Fi native**, **AirDrop / Handoff / Continuity mustahil** ⇒ §4 |

> **Jalur cadangan untuk "Wi-Fi yang bisa dipakai harian" tetaplah mengganti kartu** (Broadcom native / Intel `AirportItlwm` sudah matang).

### 0.3 Gunakan tiga perintah berikut untuk menentukan rute Anda

```bash
# ① Apakah sistem punya driver Sunrise native? (kalau ada ⇒ prioritaskan rute native)
ls /System/Library/DriverExtensions/ | grep -i sunrise

# ② Bluetooth modul Anda melalui PCIe atau USB?
system_profiler SPUSBDataType    | grep -i -E "MediaTek|0x0e8d"   # sisi USB (tipe lama)
ioreg -l -p IODeviceTree | grep -i "14c3"                          # sisi PCIe (termasuk fungsi Bluetooth 792a)

# ③ Versi besar sistemnya apa? (Sequoia tidak punya Sunrise ⇒ hanya bisa lewat pihak ketiga)
sw_vers -productVersion && uname -r

# ④ Tidak ada yang kurang dari semua di atas ⇒ rute native hanya kurang "paket firmware/kext/fragmen siap pakai" ⇒ pakai
#    GeekAudio/mediatek-sunrise-hackintosh (MT7922 Sunrise Pack, lihat §1.5)
```

## 1. Kenali chipnya dulu (jangan salah mengira model)

| Chip | Alias umum | PCI ID (Wi-Fi) | Bluetooth: **PCIe** (baru, Sunrise) | Bluetooth: **USB** (lama, pihak ketiga) |
|---|---|---|---|---|
| MT7921 | — | `14c3:7961` | — | `0x7961` |
| MT7921K | **AMD RZ608** | `14c3:0608` | — | `0x0608` / `0x7961` |
| **MT7922** | **AMD RZ616**, MT7922A | **`14c3:7922`** | ★ **`14c3:792a`** | **`0x7922`** |
| MT7923 | — | `14c3:7923` | `14c3:792b` | — |
| MT7932 / MT7925 | AMD RZ717 | `14c3:7932` / `14c3:7925` | `14c3:793b` | — (Wi-Fi 6E/7, lihat §5 jalur samping) |

★ **Satu modul MT7922 bisa punya dua bentuk**: yang baru **Bluetooth-nya melalui PCIe** (`14c3:792a`, ditangani driver native Apple),
yang lama **Bluetooth-nya melalui USB** (`0x0e8d` + class `0xE0/1/1`, perlu `SimpleMtkBtFw` pihak ketiga).
**Tentukan dulu mana yang Anda gunakan lewat perintah ② di §0.3.**

- `SimpleMtkWlan` hanya mendeklarasikan dukungan untuk **MT7921 / MT7921K(RZ608) / MT7922**; README menyebutkan *"Other MediaTek devices are not currently supported."*
- Di sisi Bluetooth, `Info.plist` `SimpleMtkBtFw` mencakup **MT7921 / MT7922 / MT7922A + satu pencocokan class USB umum MediaTek**
  (`idVendor = 3725 (0x0E8D)` + `bDeviceClass 0xE0 / SubClass 1 / Protocol 1`);
  **tetapi alur firmware saat runtime hanya menerima ID perangkat internal `0x7961` / `0x7922`** — salah mengira model = firmware tidak dimuat.

**Cek dulu apakah kartu ini benar-benar ada di mesin Anda:**

```bash
# Sisi PCIe (Wi-Fi)
ioreg -l -p IODeviceTree | grep -i "14c3"          # seharusnya melihat 14c3:7922 dan sejenisnya
system_profiler SPNetworkDataType | grep -i -B2 -A4 media
# Sisi USB (Bluetooth)
system_profiler SPUSBDataType | grep -i -B3 -A8 -E "MediaTek|0x0e8d"
```

## 1.5 ★ Cara memakai rute native (Sunrise) — macOS 26+

### Prasyarat

- Sistemnya **macOS 26 (Tahoe) atau lebih baru** (`ls /System/Library/DriverExtensions/ | grep -i sunrise` menghasilkan output)
- Bluetooth modul Anda **melalui PCIe** (`ioreg` bisa melihat `14c3:792a`)

### Langkah (jangan pasang kext apa pun dulu)

1. **Pastikan dext ada**: `ls /System/Library/DriverExtensions/ | grep -i sunrise` → harus ada `AppleSunriseWLAN.dext` + `AppleSunriseBluetooth.dext`
2. **Pasang modul → restart**
3. **Lihat apakah terdeteksi otomatis**:

```bash
# apakah dext dimuat
kmutil showloaded --list-only | grep -i sunrise
# apakah controller Bluetooth hidup (Chipset akan menampilkan yang terkait MediaTek)
system_profiler SPBluetoothDataType | head -20
# apakah interface Wi-Fi muncul
networksetup -listallhardwareports | grep -A2 -i wi-fi
ioreg -l -p IODeviceTree | grep -i "14c3"
```

4. **Terdeteksi ⇒ selesai di sini**, tidak perlu memasang kext pihak ketiga, tidak perlu mengubah config.

### Praktik komunitas (seluruh proses debugging 2026-01, dipulihkan dari isi thread; belum direproduksi di mesin ini)

Thread tonymacx86 *"Wifi 6(E) & Bluetooth 5.x MEDIATEK chipset on **native** Sequoia & Tahoe"*
(penulis thread **Elias64Fr**, CaseySJ / Sn0wMan / f10 dll ikut menguji; **seluruh thread 69+ halaman**, ID thread 332855)
— **Pengembangnya tidak punya GitHub**: Elias64Fr / CaseySJ sama-sama tanpa repositori publik, modifikasi BlueToolFixup,
paket firmware, `SSDT-ARPT_RP04_Mediatek.aml`, dan log semuanya dibagikan sebagai **lampiran forum** (§9).

**Linimasa debugging**:

| Waktu | Kejadian |
|---|---|
| 2025-12-07 | Elias64Fr mereverse `bluetoothd`, menemukan dukungan BT MediaTek (Sequoia 1 / Tahoe 7 perangkat USB), firmware ditaruh di `/etc/bluetool` |
| 2026-01-07 | Ditemukan `AppleSunriseWLAN.dext`; Ghidra membongkar `_wlanDebugInit` (default log level `0x2F`); setelah **menyuntikkan `AppleSunrise.kext` dari KDK** hasilnya `start ok`, tetapi muncul error `Failed to open wifi.cfg` / `WIFI_MT7922_patch_mcu_1_1_hdr.bin` |
| 2026-01-19~20 | CaseySJ / Elias64Fr / Sn0wMan menguji nyata (lihat langkah di bawah); memastikan firmware yang hilang adalah akar masalah |
| 2026-01-23 | Menunggu Apple menambahkan firmware di acara peluncuran Januari |
| 2026-10 (sekarang) | Halaman 69 thread: **di macOS 26.7.1 sudah ada yang melaporkan "It works!"**; di mesin ini 26.7.1 terbukti dext sudah membawa firmware BT + firmware Wi-Fi IZUBA(MT7932) |

> ★★★ **Berhenti menggali lampiran thread secara manual — pakai `GeekAudio/mediatek-sunrise-hackintosh` (MT7922 Sunrise Pack, MIT)**:
>
> | Direktori | Isi |
> |---|---|
> | `firmware/` | `WIFI_MT7922_patch_mcu_1_1_hdr.bin`(134 KB) · `WIFI_RAM_CODE_MT7922_1.bin`(1.1 MB, saat ditulis diberi nama **`W7922_1.bin`**) · `BT_RAM_CODE_MT7922_1_1_hdr.bin`(505 KB, untuk Bluetooth USB) + `SHA256SUMS` (diambil dari `mediatek/` resmi **linux-firmware**) |
> | `kexts/macos26/` | **`AppleSunrise.kext` (26.7.1/25G241)** dan **`AppleSunrise-26.3.kext` (26.3/25D5087f, sama dengan thread asli)** — diekstrak apa adanya dari KDK resmi, x86_64+arm64e |
> | `patches/` | `Kernel-Add-AppleSunrise.xml` · **`DeviceProperties-Add.xml` (penyamaran device-id tanpa kompilasi)** · `boot-args.txt` |
> | `ssdt/` | `SSDT-ARPT_RP04_Mediatek.aml` (versi koreksi dari thread asli, ubah 4 baris sesuai root port) |
> | `kexts/macos15/` | Set lengkap rute pihak ketiga untuk Sequoia: Lilu 1.7.3 + `SimpleMtkBtFw` + `SimpleMtkBtPatcher` + `SimpleMtkWlan` + **`SimpleMTK-1.0.0.zip` yang sudah dikompilasi** |
> | `research/notes/docs/` | Seluruh catatan debugging (termasuk tabel pembacaan log) |
>
> ★ **`wifi.cfg` tidak ada di dalam paket** (konfigurasi privat Apple; jika hilang, `wlanCfgSet` akan membanjiri layar dengan error tetapi **tidak fatal**, hanya menambahkan firmware saja tetap bisa berakhir dengan `wlanRemove`).

**Langkah debugging/pengujian lengkap (CaseySJ & Elias64Fr, 2026-01-19)**:

1. Pasang modul M.2 MT7922 (adapter M.2→PCIe)
2. **OpenCore menyuntikkan `AppleSunrise.kext`** (diambil dari KDK, misalnya `KDK_26.3_25D5087f`) ⇒ Tahoe bisa boot
   ★★ **Apa itu**: **HAL (hardware abstraction layer) di ruang kernel**, **hanya ada di dalam KDK, tidak ada di system volume**.
   DEXT berada di **ruang pengguna**, **tanpa menyuntik HAL ini DEXT sama sekali tidak bisa mengregister** ⇒ ini adalah **item wajib untuk rute native**, bukan optimasi opsional.
3. Tambahkan boot-arg **`wlan.debug.enable=0x1`** (NVRAM) ⇒ membuka log detail DEXT
4. **Device tree/device-id**: Info.plist DEXT hanya mencocokkan `0x7922` ⇒ native `0x616` (RZ616) perlu
   **SSDT untuk menyamar device-id sebagai `0x7922`** (`SSDT-ARPT_RP04_Mediatek.aml`, ubah 4 baris sesuai root port sebenarnya;
   MT7925 disamarkan sebagai `22790000`). Pada saat yang sama harus menambahkan properti terkait DEXT pada PXSX, kalau tidak tahap info.plist sudah gagal cocok
5. Kumpulkan log: `log show --style compact --debug --last boot --predicate 'drv.'`
   (`--info` baru menghasilkan level info; predikat `drv.` saja bisa kosong)
6. **File firmware yang diminta driver**: `wifi.cfg`, `WIFI_MT7922_patch_mcu_1_1_hdr.bin`
   (selain itu butuh `WIFI_RAM_CODE_MT7922_1.bin`, ganti nama sesuai permintaan driver menjadi `W7922_1.bin`)
7. **boot-args mitigasi crash saat boot** (0x7922 membuat DEXT restart berulang dan menjatuhkan sistem):
   `mtk.wlan.startdelay=30` (Fenvi AX5400) / `=45` (ASUS PCE-AXE59BT); upaya terakhir `mtk.wlan.hangonstart=1`
8. **Menyisipkan firmware ke system volume** (Elias64Fr, terbukti bisa): di Recovery `csrutil disable` +
   `csrutil authenticated-root disable` → mount volume Tahoe utama (bukan data) → salin firmware ke dalamnya
   (`root:wheel`, `644`) → `sudo bless --folder .../CoreServices --bootefi --create-snapshot`

**Kesimpulan debugging**:
- Akar masalah = **firmware Wi-Fi + `wifi.cfg` tidak ada di dalam DEXT**; menyisipkan firmware saja tidak cukup (kurang wifi.cfg ⇒ layar penuh
  error `wlanCfgSet`, kata Elias64Fr tabel konfigurasinya hanya 256 item dan itu tidak fatal, tetapi setelah itu driver berakhir dengan
  `wlanRemove` + `Disabling PCI device`)
- Native `0x616` tetap tidak dapat mengembang device tree, bahkan jika disamarkan sebagai `0x7922` (disassembly menunjukkan 0x616 dikonfigurasi secara setara)
- f10 melihat **dukungan AWDL lengkap** di macOS 26.3 beta + kext KDK_26.3 (satu-satunya laporan yang mendekati berhasil)
- Sisi BT dapat dipakai secara mandiri: modifikasi `BlueToolFixup` (3 set VID/PID) langsung bisa dipakai; AirPods tanpa suara perlu
  "lupakan perangkat → pairing ulang dengan iPhone/iPad → sambung ulang di sisi Mac" (perbaikan dari CaseySJ untuk Sn0wMan)

### Penyamaran device-id: pilih antara SSDT dan "DeviceProperties tanpa kompilasi"

Info.plist DEXT **hanya mencocokkan `0x7922`** (plus 7923 / 7932), sedangkan **RZ616 native adalah `0x616`** ⇒ harus dipalsukan.

| Cara | Langkah | Catatan |
|---|---|---|
| **A. SSDT (skema thread asli)** | salin `SSDT-ARPT_RP04_Mediatek.aml` ke `EFI/OC/ACPI/` + aktifkan lewat `ACPI>Add` | secara default ditulis untuk **RP04**; **root port lain harus mengubah 4 baris di dalamnya lalu dikompilasi ulang** |
| **B. DeviceProperties (tanpa kompilasi)** | tambahkan `device-id` pada jalur kartu jaringan di `DeviceProperties>Add` | ★ tidak perlu kompilasi SSDT, cukup ubah plist |

**`device-id` pada B adalah 4 byte little-endian dalam base64**:

| Target | byte device-id | nilai `<data>` |
|---|---|---|
| **MT7922 (disarankan)** | `22 79 00 00` | **`InkAAA==`** |
| MT7925 | `25 79 00 00` | **`JXkAAA==`** |

Perintah pembuatan: `printf '\x22\x79\x00\x00' | base64` (`0x22`=22, `0x79`=79).
★ **Jangan pernah mengubah `vendor-id` (pertahankan `0x14c3`)**; path-nya cari dengan
`ioreg -l | grep -B30 'device-id' | grep -E 'acpi-path|pcidebug'` (atau daftar PCIe Hackintool / Linux `lspci`).
★★ **Kalau kartu disembunyikan oleh `SSDT-Disable_Network_*.aml`** (`ioreg -l | grep -A40 'pci14c3'` menampilkan `ffffffff`),
**nonaktifkan dulu** — aturan ini juga berlaku untuk rute pihak ketiga (§4.4).

### boot-args terkait

| boot-arg | Fungsi |
|---|---|
| **`wlan.debug.enable=0x1`** | membuka log detail `drv.I` dari `AppleSunriseWLAN.dext` (untuk troubleshooting, hapus setelah stabil).★ Hanya **sakelar debugging, bukan sakelaraktifkan** |
| **`mtk.wlan.startdelay=30`** | DEXT start tertunda 30 s — **setelah penyamaran 0x7922, crash ulang DEXT tiap ~10 s bisa menjatuhkan sistem**; pada Fenvi AX5400 30 sudah cukup, **ASUS PCE-AXE59BT butuh `=45`** |
| **`mtk.wlan.hangonstart=1`** | driver menggantung dan mengunci diri sendiri, **menjamin sistem tetap bisa masuk** (Wi-Fi tidak berfungsi, **upaya terakhir**) |

### ★ Tabel pembacaan log (inti dari proses debugging)

Kumpulkan: `log show --style compact --debug --last boot --predicate 'drv.'`
(**level info perlu tambahan `--info`**; predikat `drv.` saja bisa kosong, coba `--info` lagi, ini normal).

| Baris log | Arti | Tindakan |
|---|---|---|
| `DK: AppleSunriseWLAN::start ok` | DEXT sudah attach, **injeksi HAL berhasil** | — |
| `Failed to open .../wifi.cfg` | file konfigurasi hilang | masukkan ke dalam Dext |
| `Failed to open .../WIFI_MT7922_patch_mcu_1_1_hdr.bin` | firmware patch MCU hilang | injeksi ke snapshot system volume |
| `request_firmware: Failed to find firmware file` | sama (jalur kode lain) | sama |
| `wlanCfgSet:(INIT ERROR) wifi config there is no empty entry` (**membanjiri layar**, kunci seperti `LlwLatencyDbg`/`NanWarmUpTime`/`AwdlGenCap`) | `wifi.cfg` hilang, tabel konfigurasi hanya 256 item | Elias64Fr: **tidak fatal** (tetapi setelah firmware ditambahkan akan muncul error yang lebih serius) |
| `wlanDownloadPatch:(INIT WARN) FW[2] load error!` | gagal memuat firmware | tambahkan firmware |
| `wifiFirmwareLoader: Waiting for firmware to load` (tidak ada kelanjutan) | firmware loader macet | ini membuktikan firmware yang hilang adalah akar masalah |
| `wlanRemove` + `Disabling PCI device` | **driver menyerah dan melepas perangkat** | ★ **sinyal akhir kegagalan debugging** |
| `IOUserServer(com.apple.AppleSunriseWLAN) has crashed too many times` panic | siklus crash DEXT | mitigasi dengan `startdelay` / `hangonstart` |
| `corecapture: Missing ivars in CCLogPipe` | masalah pipeline log CoreCapture | cukup dipantau, tidak memblokir |

### Sebenarnya apa saja yang "bawaan" di 26.7.1 (**per chip, jangan percaya rumor**)

> Rumor bahwa "upgrade ke 26.7.1 sudah membawa semua firmware" **tidak akurat**. Uji nyata di 26.7.1(25G241):

| Komponen | Status di 26.7.1 |
|---|---|
| **Firmware Bluetooth** (MT7922 / MT7923) | ✅ **sudah ada di dalam `AppleSunriseBluetooth.dext`** (`BT_RAM_CODE_MT7922_1_1_hdr.bin`) ⇒ untuk yang melalui PCIe **tidak perlu memasang apa pun** |
| **Firmware Wi-Fi MT7932 / RZ717** | ✅ sudah ada di dalam `AppleSunriseWLAN.dext` (satu set IZUBA) ⇒ **mengganti kartu ini barulah solusi tanpa tindakan sama sekali** |
| **Firmware Wi-Fi MT7922 / RZ616** | ❌ **masih hilang** (tidak ada file `*7922*` di dalam dext, log masih melaporkan `Failed to open WIFI_MT7922_patch_mcu_1_1_hdr.bin`) ⇒ **masih perlu ditambahkan sesuai paket ini** |

### Tidak ingin menyentuh system volume? Pilih sesuai prioritas ini

| Skema | Langkah | Biaya |
|---|---|---|
| **① Ganti kartu MT7932 (RZ717)** | 26.7.1 sudah menyertakan seluruh firmware Wi-Fi-nya | ganti perangkat keras |
| **② Rute kext pihak ketiga** | `SimpleMtkWlan` + `SimpleMtkBtFw` (firmware dikemas di dalam kext, **hanya menyentuh EFI, sama sekali tidak menyentuh system volume**) | interface bergaya Ethernet, tanpa menu Wi-Fi native, tanpa AirDrop/Handoff/Continuity, tanpa 802.11ax |
| **③ Hanya Bluetooth** | `/etc/bluetool/` + `BT_RAM_CODE_MT7922_1_1_hdr.bin` (di 26.7.1+ sudah bawaan, tanpa tindakan) | — |
| **④ Tetap pakai driver native** | "tulis firmware + bless snapshot" di atas | perlu sekali bless; **caranya sendiri bisa dikembalikan**, `wifi.cfg` boleh tidak ditulis |

★ **Metode bless snapshot lebih aman daripada "menonaktifkan SIP jangka panjang"**: macOS memang bekerja di atas snapshot, setelah membuat snapshot baru lalu boot dari snapshot baru;
**mengaktifkan kembali SIP + authenticated-root dan restart akan membersihkannya otomatis**, tanpa perlu pemulihan manual.

### Bagaimana dengan AirDrop / Handoff / Continuity?

- **Rute native secara teoritis mendukung AWDL** — f10 adalah konfigurasi **yang satu-satunya melihat dukungan AWDL lengkap** di macOS 26.3 beta + kext KDK_26.3;
- **tetapi tingkat keberhasilan nyata pada MT7922 terbatas, tidak dijamin** ⇒ **jangan ambil jalur ini demi AirDrop**;
- Butuh AirDrop / Continuity / Wi-Fi 6 ⇒ **ganti ke kartu Broadcom atau Intel** (rute pihak-third bahkan **secara desain mustahil**, §4.1).

### Rollback

1. Kembalikan OpenCore ke versi **RELEASE**, hapus boot-arg seperti `wlan.debug.enable=0x1`, nonaktifkan entri SSDT / `Kernel>Add` ⇒ kembali seperti semula
2. Perubahan system volume: **mengaktifkan SIP + authenticated-root lalu restart akan membersihkannya otomatis**, tanpa perlu pemulihan manual

> ⚠️ **Catatan**: **mesin ini (Z690) tidak punya kartu MediaTek, semua di atas belum direproduksi**.
> `wlan.debug.enable=0x1` adalah **sakelar debugging, bukan sakelar aktifkan**; proses injeksi manual versi 26.0–26.2 ini
> **sudah digantikan pembaruan Apple berikutnya** (sekarang coba "tidak pasang apa pun" dulu, §1.5 langkah 1–4).

### Bagaimana dengan Sequoia (macOS 15)

Sequoia **tidak punya** kedua dext ini ⇒ rute native tidak bisa dipakai, hanya rute pihak ketiga di bawah (§3 / §4).

## 2. Pembagian peran proyek (upstream vs fork — jangan salah repo)

| Proyek | Apa yang diurus | Bentuk | Ada Release? | Status |
|---|---|---|---|---|
| ★ **`flxxxxddd/SimpleMtkWlan`** (**fork**, cabang `mt7921-fixes`) | **Wi-Fi (PCIe)** | kext | ✅ **v1.1.0 / v1.2.0** (dibangun CI) | **★ Ini yang dipakai untuk rute pihak ketiga** — MT7921/RZ608 terbukti bisa online |
| `laobamac/SimpleMtkWlan` (**upstream**) | Wi-Fi (PCIe) | kext (+ lapisan kompatibilitas `mtk80211`) | ❌ **tidak ada** (harus dikompilasi sendiri) | trunk utama upstream, sedang bring-up; perbaikan fork **belum kembali ke trunk** |
| `laobamac/SimpleMtkBtFw` / fork `flxxxxddd/SimpleMtkBtFw` | **Pemuatan firmware Bluetooth** (firmware loader + patcher) | **dua** kext | ✅ **`1.0.0`** | bisa dipakai (catatan fork: audio AirPods berfungsi) |
| `laobamac/SimpleMTKClient` | Klien Wi-Fi menu bar | App (`SimpleMTK`) | ❌ **upstream memang tidak ada release** (2026-10-16 dicek via API + web) | **wajib ada** — lihat §4.1. Pada 2026-10-16 `SimpleMTK-1.0.0.zip` sudah dikompilasi dari sumbernya di mesin ini (build Sparkle 2.10.0 dari sumber yang di-embed; karena `sandbox-exec` dinonaktifkan oleh sistem di mesin ini, dua dependensi SPM yang tidak terpakai harus dilepas dulu sebelum mengompilasi KeychainAccess/Sparkle) |
| ★ **`GeekAudio/mediatek-sunrise-hackintosh`** (**MT7922 Sunrise Pack**, baru dibuat 2026-10-16) | **Paket sekali jadi untuk rute native**: firmware Wi-Fi (linux-firmware + SHA) · dua versi `AppleSunrise.kext` · SSDT · penyamaran `DeviceProperties` · fragmen `Kernel>Add` · daftar boot-args · set lengkap kext pihak ketiga macOS 15 (termasuk **SimpleMTK.app yang sudah dikompilasi**) | kumpulan berkas | tidak ada release (langsung clone) | **Untuk memakai Sunrise native, ambil ini dulu**, tidak perlu menggali thread 69 halaman mencari lampiran |

> **Hubungan fork dengan upstream**: `flxxxxddd/SimpleMtkWlan` adalah fork dari `laobamac/SimpleMtkWlan`,
> lalu memperbaiki banyak masalah lagi di atas **upstream + PR #5** (perbaikan asosiasi/TX MT7922 oleh `mavizao`) (daftarnya lihat §4.6).
> ★ **Issue di repo fork ditutup** (`has_issues=false`) ⇒ **untuk melaporkan masalah balik ke upstream (`laobamac/SimpleMtkWlan`)**.
> ★ **Cabang default adalah `mt7921-fixes`, bukan `main`** — ingat untuk beralih ke sana setelah clone manual.

> Perhatikan pembagian peran: **`SimpleMtkBtFw` bukan driver Wi-Fi, dan bukan stack protokol Bluetooth mandiri** —
> tugasnya hanya "memasukkan firmware ke controller Bluetooth MediaTek", **setelah itu diserahkan ke stack Bluetooth milik macOS sendiri** (pola yang sama dengan `IntelBluetoothFirmware`, dan di bagian acknowledgements-nya juga disebut `zxystd` dan IntelBluetoothFirmware).

## 3. Rute A: Bluetooth (disarankan dikerjakan lebih dulu, tingkat keberhasilan tinggi)

### 3.1 Pemasangan

1. Ambil **`1.0.0`** dari **Releases `SimpleMtkBtFw`** (`-RELEASE.zip`; saat troubleshooting bisa pakai `-DEBUG.zip`)
2. Dua kext dimasukkan ke `EFI/OC/Kexts/`, di `Kernel → Add` **dengan urutan ini**:

```
[1] Lilu.kext                  ← host, harus paling depan
[2] SimpleMtkBtFw.kext         ← pemuatan firmware
[3] SimpleMtkBtPatcher.kext    ← patch kompatibilitas berbasis Lilu
```

3. ★ **Gunakan hanya injeksi OpenCore** (rekomendasi eksplisit penulis); **jangan** sekaligus menyuntikkan firmware loader lain yang akan mengikat **perangkat Bluetooth USB yang sama**
   (misalnya menyisakan `IntelBluetoothFirmware` / `BrcmPatchRAM*` akan saling berebut perangkat)

### 3.2 ★★ Dua jebakan fatal (dari verifikasi nyata pada issue #3 `SimpleMtkBtFw`)

**Jebakan 1: jangan mengubah nama produk USB menjadi `Bluetooth USB Host Controller`.**
Kalau diubah, `bluetoothd` akan mengambil jalur controller "**internal**" — dan jalur itu **mengasumsikan chip-nya Broadcom**,
sehingga abort di `_BCM_ReadVerboseConfigVersionInfoParser` (`bcm_vsc.c:1125`) —
karena format balasan MediaTek untuk VSC `0xFC79` berbeda dari Broadcom. **Biarkan nama produk apa adanya.**

**Jebakan 2: agar macOS memakai jalur "donggle pihak ketiga", harus menyuntikkan dua data NVRAM.**
Kriteria penentunya adalah kedua kunci ini **ada**:

```
7C436110-AB2A-4BBB-A880-FE41995C9F82   (tipe data)
  bluetoothExternalDongleFailed    = 00
  bluetoothInternalControllerInfo  = <14 byte>
```

- Tulis di OC pada `NVRAM > Add`, **dan `NVRAM > Delete` juga harus memuatnya** (aturan resmi: kunci yang ada di Add harus ada di Delete agar berlaku)
- ★ **Gejala kalau tidak benar**: `bluetoothd` dibunuh watchdog tiap ~30 s, menu Bluetooth berputar terus,
  proses shutdown menggantung di BlueTool, log berulang kali berisi `Can't obtain vendorID and productID`
- Dua kunci ini **pasangan yang sama** dengan yang dipakai rute Broadcom (lihat `broadcom-wifi.md` §2.3), hanya saja di sisi Broadcom diisi informasi controller yang konkret

**Jebakan tambahan: AirPods terhubung tapi tidak bersuara** = masalah "Read Clock" pada A2DP (issue #3 punya solusinya).

### 3.3 Verifikasi

```bash
# 1. apakah kext dimuat
kmutil showloaded --list-only | grep -i -E "SimpleMtk"
# 2. log kernel (cari jejak pemuatan firmware)
log show --last 5m --style compact --predicate 'process == "kernel"' 2>/dev/null | grep -i -E "SimpleMtk|fw_name"
# 3. IORegistry untuk melihat apakah firmware benar-benar dimuat
ioreg -l -p IOService | grep -i -E "FirmwareLoaded|fw_name"
```

- Kriteria dari penulis: **ID perangkat internal di log harus `0x7961` atau `0x7922`**; di IORegistry periksa `FirmwareLoaded` dan `fw_name`
- Konfirmasi di level sistem: di `system_profiler SPBluetoothDataType` controller bisa hidup

## 4. Rute B: Wi-Fi ( pihak ketiga: `flxxxxddd/SimpleMtkWlan`)

### 4.1 ★★ Terima dulu tiga batasan keras ini (menentukan apakah cukup untuk Anda)

1. **Ini interface "bergaya Ethernet" (`enX`), bukan Wi-Fi native (`IO80211Family`)**
   ⇒ **tidak ada menu Wi-Fi native macOS**, pemindaian / koneksi jaringan sepenuhnya bergantung pada **SimpleMTK** di menu bar.
2. **❌ AirDrop / Handoff / Continuity** — kalimat asli README *"not possible with this design"*
   ⇒ **ini keputusan desain, bukan bug, jangan di troubleshoot**.
3. **❌ 802.11ax (HE / Wi-Fi 6) belum didukung**; **sleep / wake belum diuji**.

### 4.2 Seberapa jauh kemampuan nyata (tabel Tested hardware asli README)

| Kartu | PCI ID | Sistem | Hasil |
|---|---|---|---|
| **MT7921K (AMD RZ608)** | `14c3:0608` | 15.8.1 Sequoia, desktop Intel | 5 GHz VHT80 **30–50 Mbit/s** (2SS, sinyal lemah, broadband 100 M; MacBook di lokasi sama ≈85); 2.4 GHz bisa dipakai; **otomatis bergabung saat boot** |
| **MT7922** | `14c3:7922` | Tahoe (upstream PR #5) | di 5 GHz hanya legacy 20 MHz |
| MT7921 | `14c3:7961` | — | satu keluarga chip dengan RZ608, **diperkirakan bisa dipakai** |

### 4.3 Matriks kemampuan (ringkasan Status README)

| Kemampuan | Status |
|---|---|
| probe / pemuatan firmware / interupsi MSI | ✅ |
| pemindaian (2.4 GHz + 5 GHz) | ✅ |
| asosiasi WPA2-PSK (CCMP), four-way handshake | ✅ |
| dekripsi RX hardware (chip yang lolos ditangani perangkat lunak) | ✅ |
| pergantian jaringan / pita frekuensi | ✅ |
| **802.11n** (HT20/40, MCS 0–15, SGI, RX STBC, WMM) | ✅ |
| **802.11ac** (VHT20/40/80, 2×2 MCS 0–9, RX STBC) | ✅ |
| A-MPDU (RX Block Ack + agregasi TX) | ✅ |
| otomatis bergabung saat boot, **mprioritaskan 5 GHz** pada router yang sama | ✅ |
| transmisi ulang AUTH / ASSOC (kehilangan satu frame tidak lagi memindai ulang seluruhnya) | ✅ |
| pemulihan otomatis dari hang (watchdog DMA stall, PCIe FLR saat attach) | ✅ |
| **802.11ax (HE)** | ❌ belum |
| **menu Wi-Fi native macOS** | ❌ pakai SimpleMTK |
| **sleep / wake** | ⚠️ belum diuji |
| **AirDrop / Handoff / Continuity** | ❌ mustahil dengan desain ini |

### 4.4 Pemasangan (**ada release, tidak perlu kompilasi sendiri**)

1. Ambil **`SimpleMtkWlan-x.y.z-RELEASE.zip` terbaru** dari **Releases `flxxxxddd/SimpleMtkWlan`**
   (selama troubleshooting pakai `-DEBUG.zip`; sertakan juga `-RELEASE-dSYM.zip`, `SHA256SUMS.txt`, `mtklog.sh`)
2. `SimpleMtkWlan.kext` → `EFI/OC/Kexts/`, tambahkan satu entri di `config.plist → Kernel → Add`:

```xml
<dict>
    <key>Arch</key>           <string>x86_64</string>
    <key>BundlePath</key>     <string>SimpleMtkWlan.kext</string>
    <key>Comment</key>        <string>MediaTek Wi-Fi</string>
    <key>Enabled</key>        <true/>
    <key>ExecutablePath</key> <string>Contents/MacOS/SimpleMtkWlan</string>
    <key>MaxKernel</key>      <string></string>
    <key>MinKernel</key>      <string></string>
    <key>PlistPath</key>      <string>Contents/Info.plist</string>
</dict>
```

3. ★★ **Pastikan kartu ini tidak disembunyikan SSDT** — banyak EFI siap pakai menyertakan `SSDT-Disable_Network_*.aml`,
   yang mengubah `vendor-id` / `device-id` kartu jaringan menjadi `0xFFFF` supaya macOS mengabaikannya
   ⇒ **jika tidak dinonaktifkan, driver tidak akan pernah cocok**:

```bash
ioreg -l | grep -A40 'pci14c3'   # seharusnya melihat vendor-id = <c3140000>, bukan ffffffff
```

4. Pasang **SimpleMTK** (`laobamac/SimpleMTKClient`, **tidak ada release, perlu dikompilasi dengan Xcode**) → restart → bergabung dengan jaringan dari menu bar

**boot-arg opsional**: `-novht` (menonaktifkan 802.11ac), `-noht40` (menonaktifkan HT40).

### 4.5 ★ Troubleshooting (dari README, semuanya praktis)

- **Lihat log driver** — driver membawa **ring buffer yang menetap**, masih ada setelah gagal boot, **bisa dibaca tanpa root**:

  ```sh
  ./tools/mtklog.sh > mtk.txt
  ```

  Baris `stats` berkala memberikan hitungan RX, **dekripsi hardware vs perangkat lunak (`rx_hwdec` / `rx_swdec`)** dan alasan packet loss.
- **Setelah restart muncul "SimpleMtkWlan is not running"** — **restart hangat tidak memutus daya kartu M.2**;
  driver sekarang pulih sendiri secara otomatis (WFSYS reset → PCIe FLR), kalau masih gagal **mati total lalu nyalakan lagi**.
- **Kecepatan lambat** — lihat `rx_swdec` di `stats`, harus **jauh lebih kecil** dari `rx_hwdec`.
  ★ **Uji kecepatan harus menutup menu SimpleMTK** (klien memicu pemindaian; saat terhubung dibatasi 2 menit sekali).
- **Mouse/keyboard nirkabel 2.4 GHz tersendat saat Wi-Fi juga jalan di 2.4 GHz** — **koeksistensi radio pada pita yang sama, bukan bug driver**:
  biarkan kartu hanya di 5 GHz (di SimpleMTK simpan hanya jaringan 5 GHz), atau pakai kabel ekstensi USB untuk menjauhkan receiver dari antena.
- **Koneksi lambat setelah boot** — pemilihan jaringan dilakukan oleh App SimpleMTK, **baru berjalan setelah login**, sebelum itu driver terus memindai.
- **Throughput tidak menyamai Mac asli** — **firmware Block Ack Request yang dikirim AP belum diteruskan ke atas** ⇒ urutan yang kacau harus dilengkapi dengan timeout 100 ms,
  ini adalah **bottleneck utama** throughput saat ini.
- **Panic `element modified after free` sekitar 2 s setelah boot** — pada mesin uji disebabkan **`NVMeFix.kext`**,
  **bukan driver ini** (★ sangat berharga: jangan langsung menyalahkan Wi-Fi saat melihat panic).

### 4.6 Apa yang diubah fork dibanding upstream (berguna untuk menilai apakah layak diikuti / saat ingin kompilasi sendiri)

> Prasyarat: di atas **upstream + PR #5** (`mavizao`: association context, serialisasi TX, packet ownership).

- **Pemuatan firmware**: tidak lagi butuh 16 KB jumbo mbuf cluster (saat boot tidak diperoleh ⇒ `ENOMEM`, tidak ada MAC, tidak ada interface)
- **Interupsi**: mendaftarkan vektor **MSI** sungguhan, bukan INTx, tidak lagi menyetel bit enable MSI secara manual; sebelum mengaktifkan kembali, kosongkan pending
- **Hang TX DMA**: linierisasi frame multi-mbuf ke dalam satu cluster (**frame DHCP pertama saja sudah membuat WFDMA hang**)
- **Lalu lintas multicast**: chip **tidak mendekripsi frame multicast** ⇒ broadcast ARP/DHCP semuanya dibuang; sekarang kunci CCMP perangkat lunak juga dikonfigurasi untuk `net80211`
- **Pergantian jaringan**: kirim deauth lebih dulu ke kanal AP lama, abaikan disassoc kedaluwarsa saat autentikasi, hapus peer station saat keluar
  dan matikan BSS di firmware (jika tidak **setelah satu kali pergantian dekripsi hardware menjadi tidak berfungsi**)
- **Roaming**: matikan roaming latar belakang yang dipicu RSSI (ia loncat antara 2.4 / 5 GHz pada router yang sama dalam hitungan detik)
- **802.11n / 802.11ac**: HT/VHT caps, WMM, peer STA record lengkap, RX Block Ack + TX A-MPDU diserahkan ke firmware,
  **wajib mengklaim HT20/40** (AP hanya mengirim 80 MHz ke klien yang mengklaim 40 MHz), STA_REC_VHT, lebar diambil dari hasil negosiasi asosiasi
- **Bergabung**: 5 GHz diprioritaskan dalam radius 15 RSSI, bersihkan peer / hasil pindaian kedaluwarsa, kirim deauth sebelum AUTH pertama,
  **AUTH/ASSOC melakukan transmisi ulang maksimal 3 kali** (sebelumnya kehilangan satu balasan asosiasi harus menunggu ~20 s)
- **Ketahanan**: watchdog DMA stall (hard reset + muat ulang firmware), pemulihan chip saat attach (WFSYS reset → PCIe FLR), perbaikan kebocoran TXWI
- **Kemampuan debug**: ring buffer `MtkDebugLog` yang menetap (dipublikasikan di perangkat PCI), dump hardware/stats berkala, jalur data senyap
- **Build**: bisa dikompilasi dari clone bersih (MacKernelSDK sebagai submodule, tanpa path absolut), host test diperbaiki, CI + release

### 4.7 Kompilasi sendiri (hanya perlu jika ingin mengikuti kode terbaru)

```bash
git clone --recurse-submodules https://github.com/flxxxxddd/SimpleMtkWlan.git
cd SimpleMtkWlan                     # ★ cabang default adalah mt7921-fixes, bukan main
xcodebuild -project SimpleMtkWlan.xcodeproj -scheme SimpleMtkWlan \
  -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
# -> build/Build/Products/Release/SimpleMtkWlan.kext
./tests/run-all.sh                   # host test (mengambil fungsi driver asli dijalankan terhadap stub, dengan ASan/UBSan)
```

- Persyaratan: **Xcode lengkap** (command line tools tidak cukup); header kernel dari `acidanthera/MacKernelSDK`
  (**git submodule**; sudah di-clone tapi submodule tidak ikut, jalankan `git submodule update --init`)
- ★ **Kalau mengubah header di `mtk80211/` atau `include/` wajib `rm -rf build` lalu kompilasi ulang** —
  keduanya ada di jalur pencarian header sistem, Xcode **tidak melacak dependensi**, kalau tidak akan tertautkan objek lama
- Lisensi **GPLv2**; firmware didistribusikan ulang dengan lisensi firmware MediaTek (sama seperti linux-firmware)

### 4.8 Risiko dan prasyarat

- Cadangkan EFI, siapkan USB bootable; **menonaktifkan kext ini akan kembali ke kondisi "tanpa driver"**
- **Ini rute pihak ketiga**: tidak ada menu Wi-Fi native, tidak ada AirDrop / Continuity, tidak mendukung 802.11ax
  ⇒ **kalau butuh fitur tersebut, ganti kartu** (Broadcom / Intel), lihat pohon keputusan §6
- ★ Setelah dipasang **`en0` bisa berpindah kepemilikannya** (karena ini interface bergaya Ethernet) ⇒ lihat **`network-en0-order.md`**

## 5. Jalur samping: kartu jaringan USB ≠ kartu PCIe di motherboard

`Network-Weather/mt76-usb-macos` — driver USB mt76 di ruang pengguna, mencakup **kartu jaringan USB** seperti **MT7921U (AWUS036AXML) / MT7925U (Nighthawk A9000)**.
**Ini beda hal dengan MT7922 (PCIe) di motherboard/laptop**, jangan campur: kartu PCIe memakai `SimpleMtkWlan`, kartu jaringan USB memakai yang ini.
(Referensi nyata lain: `thanhnndev/ga403wm-hackintosh`, ASUS ROG Zephyrus G14 + MT7925.)

## 6. Pohon keputusan

```
Apakah chipnya MediaTek MT792x (14c3:7922 / 7923 / 7932 / 7961 / 0608)?
│
├─ Sistemnya macOS 26+, dan Bluetooth melalui PCIe (14c3:792a)
│   └─► ★★★ Rute ①: Sunrise native — tidak perlu memasang apa pun, pasang lalu restart dan lihat apakah terdeteksi (§1.5)
│           └─ tidak terdeteksi ⇒ **ambil dulu `GeekAudio/mediatek-sunrise-hackintosh`** (firmware/kext HAL/fragmen penyamaran semuanya ada di dalamnya),
│              lalu lengkapi sesuai "Praktik komunitas" di §1.5: suntik AppleSunrise.kext (HAL) + penyamaran device-id + firmware (perhatikan chipnya!)
│
├─ Sistemnya Sequoia, atau Bluetooth melalui USB (0x0e8d)
│   └─► Rute ②: SimpleMtkBtFw (ada release, tingkat keberhasilan tinggi)
│           ingat dua jebakan di §3.2: jangan diubah nama produknya + suntik dua data NVRAM
│
└─ Butuh Wi-Fi
   ├─ macOS 26+ dan chipnya termasuk 7922 / 7923 / 7932 ─► ★ Coba native dulu (rute ①)
   │
   ├─ Butuh "menu Wi-Fi native / AirDrop / Continuity / Wi-Fi 6(HE)"
   │   └─► ✗ Rute pihak ketiga tidak bisa memberi itu (§4.1) ⇒ ganti kartu:
   │        Broadcom (native, broadcom-wifi.md) atau Intel + AirportItlwm (intel-wifi.md)
   │
   └─ Menerima "interface bergaya Ethernet + klien menu bar", yang penting bisa online
       ├─ MT7921 / MT7921K(RZ608) ─► ★ Rute ③: release flxxxxddd/SimpleMtkWlan (§4)
       │                               terbukti 5 GHz VHT80 30–50 Mbit/s, otomatis bergabung saat boot
       └─ MT7922 ─► Coba native dulu; kalau native gagal baru pakai ③ (di Tahoe fork hanya legacy 20 MHz)
                    ★ Pastikan dulu kartu tidak disembunyikan SSDT-Disable_Network (langkah 3 §4.4)
                    ★ Wajib pasang klien SimpleMTK; saat uji kecepatan matikan menunya
```
## 7. Troubleshooting

| Gejala | Yang perlu diperiksa |
|---|---|
| **Rute native**: dext Sunrise ada tapi tidak dimuat | ① apakah chip ada di daftar `IOPCIMatch` (`0x792214c3`/`792a14c3` dll, lihat §0.1); ② apakah Bluetooth-nya bentuk PCIe (bentuk USB tidak cocok dengan driver ini); ③ `kmutil showloaded \| grep -i sunrise` untuk melihat apakah dimuat |
| **Rute native**: Wi-Fi terdeteksi tapi tidak bisa konek | cek dulu apakah dipengaruhi **kepemilikan `en0`** / urutan layanan jaringan (⇒ **`network-en0-order.md`**); lalu lihat baris terkait Sunrise di log sistem |
| kext Bluetooth dimuat tapi controller tidak hidup | apakah dua data NVRAM **sekaligus ada di `Add` dan `Delete`** (§3.2 jebakan 2) |
| `bluetoothd` restart terus / menu Bluetooth berputar / shutdown menggantung di BlueTool | sama; dan pastikan **tidak** mengubah nama produk menjadi `Bluetooth USB Host Controller` |
| firmware tidak termuat di log | apakah ID perangkat internal `0x7961` / `0x7922`; apakah USB cocok dengan `Info.plist` (`idVendor 0x0E8D` + class `0xE0/1/1`) |
| AirPods terhubung tanpa suara | masalah A2DP Read Clock (issue #3) |
| kext Wi-Fi dimuat tapi tidak ada interface | ★★ **kartu disembunyikan SSDT** (`vendor-id` diubah menjadi `0xFFFF`) ⇒ `ioreg -l \| grep -A40 'pci14c3'`; apakah ID perangkat ada di daftar dukungan |
| Wi-Fi bisa memindai tapi langsung hang/panic saat konek | ★ pakai **release dari fork** (trunk upstream masih menunjukkan gejala ini; fork sudah memperbaiki asosiasi/TX, lihat §4.6); kalau masih terjadi jalankan `mtklog.sh` untuk melihat log |
| setelah restart driver not running | **restart hangat tidak memutus daya kartu M.2** ⇒ driver pulih otomatis (WFSYS reset → PCIe FLR); kalau tidak berhasil **mati total lalu nyalakan lagi** (§4.5) |
| Wi-Fi lambat / tidak secepat Mac asli | ① `rx_swdec` di `stats` harus jauh lebih kecil dari `rx_hwdec`; ② **tutup menu SimpleMTK saat uji kecepatan**; ③ bottleneck sisanya = firmware Block Ack Request dari AP yang belum diteruskan (timeout urutan 100 ms) |
| keyboard/mouse nirkabel 2.4 GHz tersendat saat online | **koeksistensi radio pada pita yang sama, bukan bug driver** ⇒ biarkan kartu di 5 GHz, atau pindahkan receiver dengan kabel ekstensi |
| panic `element modified after free` sekitar 2 s setelah boot | pada mesin uji **`NVMeFix.kext`**, **bukan driver ini** — jangan salah menyalahkan |
| **Rute native**: panic `IOUserServer(com.apple.AppleSunriseWLAN) has crashed too many times` / DEXT restart terus menjatuhkan sistem | gejala yang dikenal setelah penyamaran 0x7922 ⇒ tambahkan **`mtk.wlan.startdelay=30`** (beberapa kartu butuh **45**); upaya terakhir **`mtk.wlan.hangonstart=1`** (§1.5) |
| **Rute native**: log berhenti di `wlanRemove` + `Disabling PCI device` | ★ **driver sudah menyerah pada perangkat** — **sinyal akhir kegagalan debugging**: biasanya kurang `wifi.cfg` / firmware tidak ditulis di lokasi atau nama yang benar (`WIFI_RAM_CODE_MT7922_1.bin` harus diganti namanya menjadi **`W7922_1.bin`**) ⇒ cocokkan satu per satu dengan tabel pembacaan log `§1.5` |
| **Rute native**: layar penuh `wlanCfgSet ... no empty entry` | kurang `wifi.cfg` — **tidak fatal** (hanya perlu dipantau), tetapi hanya menambahkan firmware tanpa file ini tetap bisa berakhir tanpa berhasil |
| **Rute native**: setelah penyamaran device-id tetap tidak cocok | ★ ketiganya harus diperiksa: ① apakah disembunyikan `SSDT-Disable_Network` (`vendor-id` jadi `ffffffff`) ② nilai `device-id` adalah base64 little-endian (`0x7922 → InkAAA==`) ③ **di bawah PXSX juga perlu ditambahkan properti terkait DEXT** (§1.5) |
| Bluetooth sudah terpasang tapi ada firmware loader BT lain yang juga aktif | hapus komponen yang bertentangan (disiplin yang sama ada di `intel-wifi.md` §5 "setelah mengganti kartu jaringan harus dibersihkan") |

## 8. Peringatan keamanan dan batasan

- Ketiga kext **tidak ditandatangani Apple** ⇒ butuh `SecureBootModel=Disabled`, SIP bisa dilonggarkan sesuai kebutuhan; **lakukan ini hanya jika benar-benar perlu memakai kartu ini**
- `SimpleMtkWlan` adalah **proyek eksperimental berlisensi GPLv2**; fork `flxxxxddd` **memiliki release yang dibangun CI** (v1.1.0 / v1.2.0),
  tetapi **trunk utama upstream masih berstatus bring-up dan tidak ada release** ⇒ **untuk rute pihak ketiga pastikan memakai release fork** (§2 / §4).
  Sebelum membangun dari sumber, baca dulu `CREDITS.md` dan ketentuan distribusi ulang firmware (firmware memakai lisensi firmware MediaTek, sama seperti linux-firmware)
- ★ **Issue di fork ditutup** ⇒ untuk umpan balik/bantuan kirim ke upstream `laobamac/SimpleMtkWlan`; cabang default fork adalah **`mt7921-fixes`**
- Hubungan dengan `broadcom-wifi.md` / `intel-wifi.md`: **jangan menyuntikkan tiga set driver kartu jaringan sekaligus di satu mesin**;
  setelah mengganti kartu, mengikuti disiplin `intel-wifi.md` §5 untuk **menonaktifkan atau menghapus** set lama, dan perhatikan bahwa **kepemilikan `en0`** berubah mengikuti urutan pemuatan driver (⇒ **`network-en0-order.md`**)
- ★ **Lisensi MT7922 Sunrise Pack berlapis**: teks repo dan patch **MIT**; `firmware/*.bin` mengikuti **ketentuan distribusi ulang linux-firmware**;
  `SSDT-ARPT_RP04_Mediatek.aml` karya asli **Elias64Fr** dipublikasikan di thread, **sebutkan atribusinya saat memakai**.
- **Dokumen reference ini adalah proses umum**; mesin ini (Z690) memakai Broadcom `BCM943602CDP`, **tidak punya MT7922**.
  - **Fakta rute native di §0.1 (dua dext, `IOPCIMatch`, firmware bawaan, string `bluetoothd`) terbaca nyata di macOS 26.7.1 mesin ini** — bagian ini adalah bukti keras
  - **"Praktik komunitas" di §1.5 serta rute pihak ketiga di §3/§4 belum direproduksi di mesin ini** (tidak ada perangkat keras yang cocok) — ikuti §0.3 / §1 untuk memastikan chip dan bentuknya dulu, lalu verifikasi bertahap
  - **Kemampuan/batasan/troubleshooting di §4 semuanya berasal dari README fork dan catatan release** (v1.2.0 tanggal 2026-10-13), **bukan hasil uji mesin ini** ⇒ sebelum dipakai, periksa dulu apakah repo sudah ada pembaruan
