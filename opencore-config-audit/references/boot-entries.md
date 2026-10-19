# Entri boot firmware (`Boot####` / `BootOrder`) dan `Misc>Boot>LauncherOption`

> **Berorientasi gejala**: entri **OpenCore sendiri menghilang dari menu boot BIOS, hanya tersisa Windows**;
> atau "**boot sekali lewat U disk, entri OpenCore di hard drive langsung hilang**" ⇒ langsung lihat §1–§3.
>
> ★ **Jangan campur dengan dua hal berikut**: `ScanPolicy` / `HideAuxiliary` mengatur **apa yang ditampilkan selector OpenCore itu sendiri**;
> yang dibahas di sini adalah entri boot di **menu boot firmware (BIOS/UEFI)** (variabel `Boot####`).

## 0. Kesimpulan satu kalimat

`Misc>Boot>LauncherOption` menentukan apakah OpenCore perlu **memelihara satu entri boot "yang menunjuk ke dirinya sendiri" di NVRAM firmware**.

**Cara ia mengenali "entri miliknya sendiri" adalah: hanya membandingkan sufiks jalur file di dalam entri boot** (`OpenCore.efi` ketika `LauncherPath=Default`),
**tidak melihat disk mana pun** (kutipan langsung dari komentar source: *"Using OpenCore.efi … will overwrite any option with this path (e.g. `OC\OpenCore.efi` and `OC2\OpenCore.efi`)"*).

⇒ Maka **saat di-boot dari U disk (atau disk lain apa pun), ia akan "mengalihkan di tempat" entri di hard drive dengan sufiks yang sama ke media boot**;
begitu media dicabut, entri itu menunjuk ke perangkat yang tidak ada ⇒ **firmware membersihkannya** ⇒ di menu boot hanya tersisa Windows.

## 1. Gejala dan akar masalah (rekaman aktual mesin ini 2026-10-15)

### 1.1 Gejala

> Begitu **di-boot sekali dari U disk**, **entri boot OpenCore di hard drive (yang ditambahkan EasyUEFI) langsung hilang dari menu boot BIOS, hanya tersisa Windows Boot Manager**.

### 1.2 Rantai akar masalah (dokumen resmi + source OpenCore)

1. `LauncherOption=Full` ⇒ **setiap kali menyala**, OpenCore akan "membuat atau memperbarui entri boot dengan prioritas tertinggi di firmware" (kutipan asli resmi).
2. Ia **mencari "entri miliknya sendiri"** dengan `OcDevicePathHasFilePathSuffix (CurrDevicePath, MatchSuffix, …)`,
   `MatchSuffix` ketika `LauncherPath=Default` = **`OpenCore.efi`** ⇒ **hanya mencocokkan sufiks jalur, bukan perangkat**.
3. Setelah ditemukan, ia memeriksa `CurrOptionValid = IsDevicePathEqual (ReferencePath, CurrDevicePath)`:
   - **sama** ⇒ dianggap miliknya sendiri, dipertahankan;
   - **tidak sama** (perangkat berbeda, yaitu "disk lain sekarang yang melakukan boot") ⇒ masuk ke cabang `!CurrOptionValid`:
     **membangun ulang `Boot####` yang sama dengan "jalur perangkat saat ini"**, lalu **memindahkannya ke paling depan `BootOrder`**.
4. Sementara itu, config EFI di U disk itu **juga** `Full` + `LauncherPath=Default` (= `\EFI\OC\OpenCore.efi`)
   ⇒ ketika booting dari U disk, OpenCore **mengalihkan entri bersufiks sama di hard drive ke U disk**.
5. Mematikan lalu mencabut U disk ⇒ entri itu menunjuk ke perangkat yang tidak ada ⇒ **firmware membersihkannya** ⇒ hanya tersisa Windows.

> ★ **Pemahaman kunci**: ini bukan "U disk merebut entri hard drive", melainkan **OpenCore sendiri menganggap kedua entri sebagai entri yang sama berdasarkan "sufiks jalur"**.
> Selama keduanya `Full` + `LauncherPath` yang sama, **boot dari disk lain sekali saja sudah cukup untuk menimpa**.

### 1.3 Kutipan asli resmi (`Docs/Configuration.tex`, 1.0.8)

```
LauncherOption
  Type: plist string
  Failsafe: Disabled                     ← ★ nilai default resmi adalah Disabled
  Description: Register the launcher option in the firmware preferences for persistence.
    Disabled --- do nothing.
    Full     --- create or update the top priority boot option in UEFI variable storage at
                bootloader startup.
                · For this option to work, RequestBootVarRouting is required to be enabled.
    Short    --- create a short boot option instead of a complete one.
    System   --- create no boot option but assume specified custom option is blessed.
```

Ada dua penjelasan resmi yang **langsung relevan**:

- *"This option allows integration with third-party operating system installation and upgrades
  (which may overwrite the `\EFI\BOOT\BOOTx64.efi` file). **The BOOTx64.efi file is no longer used
  for bootstrapping OpenCore if a custom option is created.**"*
  ⇒ **setelah `Full`, `BOOTx64.efi` tidak lagi ikut serta dalam boot**; hanya kembali menjadi cadangan jika diubah ke `Disabled`.
- *"When `LauncherOption` is not enabled, other operating systems may overwrite OpenCore settings
  and this property should therefore be enabled when planning to use other operating systems."*
  ⇒ inilah **biaya dari `Disabled`** (lihat §5).

### 1.4 Dasar dari source code

| Lokasi | Kode / komentar kunci |
|---|---|
| `Library/OcMainLib/OpenCoreMisc.c` · `BuildLauncherPath()` | *"MatchSuffix allows us to reduce option duplication … Using OpenCore.efi (OPEN_CORE_APP_PATH) will overwrite any option with this path (e.g. `OC\OpenCore.efi` and `OC2\OpenCore.efi`)."* ⇒ `MatchSuffix = "OpenCore.efi"` ketika `LauncherPath=Default` |
| `Library/OcBootManagementLib/DefaultEntryChoice.c` · `InternalGetBoostrapOptionData()` | `IsBooptstrap = OcDevicePathHasFilePathSuffix (CurrDevicePath, MatchSuffix, MatchSuffixLen);` ⇒ **mencari entri berdasarkan sufiks, mengabaikan perangkat** |
| Sama · `InternalRegisterBootstrapBootOption()` | `CurrOptionValid = IsDevicePathEqual (ReferencePath, CurrDevicePath);`, `if (!CurrOptionValid) { … }` ⇒ **membangun ulang `Boot####` yang sama dengan jalur perangkat saat ini**, lalu memindahkan indeks tersebut ke urutan pertama `BootOrder` |

### 1.5 Kriteria log saat boot

Log DEBUG OpenCore akan memuat ( `opencore-*.txt`, lihat `logs-and-debug.md`):

```
OCB: Have existing option at Boot0001, invalid     ← "entri miliknya sendiri" ditemukan, tetapi perangkat salah ⇒ akan ditimpa
OCB: Creating boot option OpenCore of NNN bytes
OCB: Moving boot option to the front from N position
```

★ Melihat `Have existing option at Boot####, invalid` sama dengan **boot kali ini menimpa entri tersebut**.

## 2. Tabel nilai `LauncherOption` (4 tingkat resmi)

| Nilai | Perilaku | Catatan |
|---|---|---|
| **`Disabled`** | do nothing (tidak melakukan apa pun) | ★ **Failsafe resmi**; saat ini cadangan berasal dari `\EFI\BOOT\BOOTx64.efi` |
| `Full` | Setiap kali menyala **membuat/memperbarui** entri boot prioritas tertinggi | Membutuhkan `UEFI>Quirks>RequestBootVarRouting=true` (berpasangan) |
| `Short` | Membangun entri boot "pendek" (hanya berisi node hard drive) | Untuk firmware lama seperti Insyde yang **tidak mampu menangani jalur perangkat lengkap** |
| `System` | **Tidak membuat entri**, dengan asumsi entri kustom sudah di-`bless` | Berpasangan dengan `ForceBooterSignature`; jalur dikelola oleh alat `bless` |

> ★ **`Disabled` adalah nilai default resmi** — artinya `Full` yang sebelumnya dipakai di mesin ini memang **menyimpang dari Failsafe**.
> ★ `LauncherPath` hanya bermakna di bawah `Full`/`Short`/`System`; pada `Disabled`, source memaksa mengembalikannya ke `Default`.

## 3. Solusi

### 3.0 Tentukan strategi dulu: trade-off tiga kombinasi

| Kombinasi | Hasil | Penilaian |
|---|---|---|
| **Hard drive `Full` + U disk `Disabled`** | Saat boot dari hard drive, OpenCore membangun/meletakkan entri di depan dan **menyembuhkan dirinya sendiri**; U disk hanya membaca tanpa menulis NVRAM | ★ **Putusan final mesin ini 10-15 02:41** |
| **Keduanya `Disabled`** | OpenCore tidak lagi menyentuh NVRAM — **tetapi berarti tidak ada yang membangun entri boot** | Hanya cocok jika "sudah ada entri yang bisa dipakai, dan kamu memang tidak bermaksud membiarkan OpenCore mengelolanya" |
| Keduanya `Full` | Saling menimpa (lihat §1) | ✗ Inilah penyebab jebakan ini |

> ★★ **Pemahaman kunci: `Disabled` bukan "lebih aman", itu hanya "tidak peduli".**
> Agar entri **ada dan berada di posisi pertama**, harus ada yang menulisnya — biarkan OpenCore menulisnya (`Full`, lihat §3.1),
> atau tulis manual (§7). **"Cukup set semua Disabled" itu salah.**

### 3.1 Putusan final mesin ini: hard drive `Full` / U disk `Disabled`

```text
config ESP hard drive: Misc > Boot > LauncherOption = Full        (LauncherPath = Default)
config ESP U disk: Misc > Boot > LauncherOption = Disabled
```

**Alasannya**: hanya ketika **di-boot dari hard drive** OpenCore akan membangun/meletakkan entri hard drive di depan (dan sejak itu menyembuhkan dirinya sendiri di setiap boot);
setelah bagian di U disk di-set `Disabled`, ia **tidak lagi menimpa NVRAM** ⇒ tidak akan memindahkan entri hard drive lagi. Inilah kombinasi yang konvergen.

- **Catatan eksekusi (10-15 02:41)**: hard drive `disk2s1` → `Full`, sha persis kembali ke **`a08dfed3…`** (bolak-balik tanpa kehilangan);
  U disk `disk9s1` → `Disabled`, sha `50889560…` → **`d01b859a…`**.
  Keduanya lolos `plutil -lint` OK, `ocvalidate` resmi (1.0.8) *No issues found*, `sync` → unmount → mount ulang dengan hak akses → verifikasi ulang konsisten.
- Cadangan: `_oc-backup-before-launcheropt-back-to-full-20261015-024132.plist`,
  `_usbefi-backup-before-launcheropt-disabled-20261015-023959.plist`.

### 3.2 Cadangan: `\EFI\BOOT\BOOTx64.efi`

**Kedua ESP tetap mempertahankan `\EFI\BOOT\BOOTx64.efi`** (53.248 B di mesin ini, ada pula `bootx64.efi.win` sebagai cadangan).
Ketika `LauncherOption=Disabled`, file itu **kembali ikut serta dalam boot** (kutipan asli resmi: *"The BOOTx64.efi file is no longer used for
bootstrapping OpenCore **if a custom option is created**."*)
⇒ meskipun entri boot benar-benar hilang, tetap bisa boot dengan **memilih hard drive itu langsung dari menu boot BIOS**, lalu setelah masuk menambahkan kembali entri (§7).

### 3.3 Kalau entri benar-benar hilang, cara memulihkan

1. **Paling praktis**: saat menyala tekan `F8` (ASUS memunculkan menu boot) → pilih langsung hard drive itu → setelah masuk sistem, tambahkan kembali sesuai §7.
2. **Sisi Windows**: `bcdedit /enum firmware` bisa melihat entri firmware; menambahkan ulang lewat GUI EasyUEFI paling intuitif.
3. ★★ **Untuk `bcfg boot add/rm` manual, proteksi NVRAM harus dilepas lebih dulu** (kutipan asli resmi):
   *"if OpenCore has `RequestBootVarRouting` enabled, it will be necessary to run the command
   `\EFI\OC\Tools\OpenControl.efi disable` before using `bcfg`."*
   (setelah `OpenControl disable`, **reboot atau `OpenControl restore` wajib dilakukan agar OS bisa boot**.)
4. **Atau** biarkan OpenCore memperbaiki sendiri: set `LauncherOption` untuk ESP tersebut ke `Full`, lalu boot sekali dari sana (§3.1).

## 4. Perintah pengumpulan bukti

### 4.1 Membaca entri boot firmware (sisi macOS)

```bash
G=8BE4DF61-93CA-11D2-AA0D-00E098032B8C          # EFI_GLOBAL_VARIABLE_GUID

# Urutan boot (larutan UINT16 little-endian, tiap satu = nomor dari satu Boot####)
nvram $G:BootOrder

# Lihat isi satu per satu (nama + jalur perangkat + jalur file semuanya ada di dalamnya)
nvram $G:Boot0000
nvram $G:Boot0080
```

> ⚠️ **`nvram -p` tidak akan mencantumkan `Boot####`** (diuji langsung di mesin ini, hanya keluar 19 variabel, semuanya variabel sisi Apple dan alat).
> **Harus dibaca satu per satu dengan `GUID:nama`**. Nomor yang tidak terbaca akan menampilkan `(iokit/common) data was not found`.
> ★ Supaya output mudah dibaca, pakai `scripts/oc-nvram-bootentry.sh dump` (mengurai nama / jalur perangkat / jalur file).

### 4.2 Snapshot hasil uji di mesin ini

**(a) Selama `LauncherOption=Disabled` (10-15 02:20–02:41)**

| Variabel | Isi | Penjelasan |
|---|---|---|
| `BootOrder` | `80 00` (= hanya ada `Boot0080`) | Di urutan boot firmware **hanya ada entri macOS** |
| `Boot0080` | nama `Mac OS X`, jalur `\System\Library\CoreServices\boot.efi` | ★ **entri hasil `bless` milik macOS sendiri**, **bukan milik OpenCore** |
| `Boot0000` | nama `Windows Boot Manager`, jalur `\EFI\MICROSOFT\BOOT\BOOTMGFW.EFI` | ★ lihat jebakan ASUS di §5 |
| `Boot0001` | `data was not found` | Entri OpenCore yang sudah dihapus |

⇒ **Tidak ada entri milik OpenCore sendiri** — konsisten dengan `Disabled`: boot mengandalkan `\EFI\BOOT\BOOTx64.efi` sebagai cadangan.

**(b) Setelah dibangun ulang secara manual (mulai 10-15 02:38, saat ini)**

```
BootOrder = %01%00%80%00          → urutan = [Boot0001, Boot0080]

Boot0001  nama OpenCore           154 byte  ACTIVE
  PciRoot(0x0) / Pci(0x6,0x0) / Pci(0x0,0x0) / NVMe(0x1,⟨EUI64⟩)
  HD(1, GPT, ⟨ESP partisi GUID⟩, 0x1000, 0x39000) / \EFI\OC\OpenCore.efi
```

⇒ Entri OpenCore itu **ada di posisi pertama `BootOrder`**.

### 4.3 Log saat boot

```bash
grep -E "OCB: (Have existing option|Creating boot option|Moving boot option)" \
     /Volumes/EFI/opencore-*.txt
```

★ Ketiga baris itu bersama-sama bisa **merekonstruksi jalur perangkat sepenuhnya** (termasuk ukuran byte-nya):
`OCB: Creating boot option OpenCore of 154 bytes` + `OCB: 1 -> Boot0001 = HD(...)` +
`OCB: Expanded DP remainder - \EFI\OC\OpenCore.efi`.

## 5. Biaya dan trade-off (wajib diketahui sebelum mengubah)

| Poin | Isi |
|---|---|
| ★ **Peringatan resmi** | *"When `LauncherOption` is not enabled, **other operating systems may overwrite OpenCore settings**"* ⇒ saat multi-sistem, **resmi menyarankan untuk mengaktifkannya**. Mitigasi di mesin ini = cadangan `\EFI\BOOT\BOOTx64.efi` + bisa ditambahkan kembali kapan saja |
| **Note resmi** | **NVRAM reset yang dijalankan sebelum OpenCore akan menghapus entri ini** (reset yang dijalankan di dalam OpenCore biasanya tidak) ⇒ setelah update BIOS / membersihkan NVRAM, entri harus ditambahkan ulang |
| **Note resmi 3 (Intel Visual BIOS)** | bug firmware seperti Intel NUC: **begitu ada satu entri boot yang menunjuk ke perangkat USB, setelahnya U disk apa pun yang dicolokkan hanya menampilkan entri itu saja**. Rekomendasi resmi: **OpenCore mana pun yang akan di-boot dari U disk harus di-set `Disabled` atau `System`**. Mesin ini ASUS, bukan Intel NUC, **hanya fenomena sejenis** |
| ★★ **Jebakan khusus ASUS / AMI (ada dasar dari source)** | Komentar di `Platform/OpenRuntime/UefiRuntimeServices.c`: *"Many modern AMI BIOSes (e.g. **ASUS ROG STRIX Z370-F GAMING**) have bugs in AMI Post Manager protocol … `GetNextVariableName` … matches every `Boot####` variable as a potential boot option **regardless of the GUID namespace** … the boot option list on most ASUS firmware … is **corrupted (e.g. duplicated options) if `Boot####` variables are present outside `gEfiGlobalVariableGuid`**."* ⇒ **inilah alasan OpenCore mengarahkan ulang `Boot*` ke `OC_VENDOR`** (prefix diubah menjadi `OCBt`) |
| ★★ **Satu hal lain dalam komentar yang sama** | *"**`Boot0000` is reserved on ASUS boards** and is treated like a deleted entry. Setting `Boot0000` will essentially cause entries to **duplicate and eventual BIOS brick**."* ⇒ **di ASUS jangan pernah membuat `Boot0000` secara manual** |
| **Kompatibilitas firmware** | Note resmi 1: sebagian implementasi NVRAM firmware punya cacat (Haswell dan sejenisnya) ⇒ `LauncherOption` **hanya boleh dipakai pada papan yang kompatibilitasnya sudah diketahui** (`acidanthera/bugtracker#1222`) |

## 6. Disiplin kriteria

- **Pisahkan dulu "entri mana yang hilang"**: milik OpenCore? Milik Windows? Atau `Boot0080` hasil `bless` milik macOS?
  Ketiganya dibuat oleh pihak berbeda, penanganannya sama sekali berbeda.
- **Ini masalah lapisan NVRAM / firmware** ⇒ **tidak ada hubungannya** dengan kext, driver, `SecureBootModel`; "menunggu lebih lama" tidak akan membuatnya membaik.
- **Jangan campur dengan "ada sistem yang tidak terlihat di selector"** — itu urusan `ScanPolicy` / `HideAuxiliary` / `Misc>Entries` (lihat `pitfalls.md` §A).
- **Setelah mengubah `LauncherOption`**: saat berikutnya boot dari ESP "sisi yang lain", **periksa ulang** apakah `BootOrder` berubah lagi.
- **Mesin multi-sistem**: `Full` dan `Disabled` sama-sama punya biaya, **tidak ada pilihan gratis** — catat pilihanmu di laporan, dan simpan cadangan dari §3.2.
- ★★ **Entri boot yang ditulis dari macOS, verifikasi hanya melihat BIOS, bukan pembacaan balik** (alasannya lihat §7.0).

## 7. ★★ Metode resmi: cara menambahkan kembali entri boot yang hilang

> **Dasar resmi**: `Docs/Configuration.pdf` (ambil sesuai versi OpenCore di mesinmu) —
> `Misc>Boot>LauncherOption` (termasuk **Note 3**), `UEFI>Quirks>RequestBootVarRouting`,
> `Misc>Tools` (`FullNvramAccess` / `OpenControl` / `OpenShell` / `BootKicker`),
> `Misc>Boot>PickerMode` Note 3, Troubleshooting → Tips and Tricks.
> Semua kutipan di bawah ini adalah **teks asli resmi**.

### 7.0 Pahami dulu dua kunci ini (menentukan "bisa atau tidak menulis dari dalam sistem")

| Kunci | Definisi resmi | Artinya |
|---|---|---|
| `Misc>Boot>LauncherOption=Full` | *"create or update the top priority boot option in UEFI variable storage at bootloader startup"* | OpenCore **memelihara sendiri** entri di setiap kali menyala (self-healing) |
| `UEFI>Quirks>RequestBootVarRouting=true` | *"Request redirect of all `Boot` prefixed variables from `EFI_GLOBAL_VARIABLE_GUID` to `OC_VENDOR_VARIABLE_GUID`."* | ★ **akses baca/tulis `Boot*` dari OS dialihkan ke namespace milik OpenCore** |

★★ **Inferensi terpenting**: ketika `RequestBootVarRouting=true`, menulis entri boot dari dalam macOS / Linux
"terlihat berhasil, dan pembacaan balik juga konsisten", tapi **tidak sampai ke firmware**. Penjelasan resmi untuk Linux `efibootmgr` sangat terus terang:

> *"Linux must be started either **not via OpenCore**, or **via OpenCore with
> `RequestBootVarRouting` disabled** for this to work."*

⇒ **Jika ingin menulis entri boot dari dalam sistem operasi, `RequestBootVarRouting` pada config "yang dipakai saat boot" harus di-set `false`.**

### 7.1 Empat metode (dari resmi, diurutkan dari keandalan)

| Metode | Dilakukan di mana | Keandalan | Prasyarat |
|---|---|---|---|
| **A** `LauncherOption=Full`, biarkan OpenCore membangun sendiri | Boot sekali dari ESP tersebut | ★★★ langsung menulis ke firmware | Membutuhkan `RequestBootVarRouting=true` |
| **B** **OpenShell + `bcfg` (rekomendasi resmi)** | Selector OpenCore → Tools → OpenShell | ★★★ level firmware | Cukup U disk saja |
| **C** `OpenControl.efi disable` dulu, lalu `bcfg` | Sama seperti di atas | ★★★ | Dipakai saat metode B gagal "tidak bisa menulis" |
| **D** Menulis dari dalam sistem operasi | macOS / Linux / Windows | ★ wajib `RequestBootVarRouting=false` | Lihat §7.0 |

> ★ **A tidak menyelesaikan masalah "ayam dan telur"**: saat firmware memang belum punya entri OpenCore, kamu **tidak bisa menjalankan OpenCore di hard drive**,
> sehingga tidak bisa membuatnya membangun sendiri. ⇒ dalam kasus ini gunakan **B / C / D sekali dulu**, lalu serahkan ke A untuk self-healing.

### 7.2 Metode B (rekomendasi resmi): `bcfg boot add` di OpenShell

**Operasi murni U disk, tidak butuh Windows, dan tidak perlu masuk ke sistem operasi apa pun.** Inilah yang resmi diberikan di Note 3 `LauncherOption`.

```text
① Colokkan U disk, nyalakan lalu tekan F8 (atau masuk BIOS) dan boot dari U disk
② Selector OpenCore → Tools → OpenShell
③ Jalankan berurutan:

   map -r                                  ← daftar semua sistem berkas
   dir FS0:\EFI\OC\                        ← konfirmasi satu per satu: yang bisa menampilkan OpenCore.efi adalah ESP target
   bcfg boot dump                          ← lihat dulu entri boot yang ada, supaya tahu posisinya
   bcfg boot add 0 FS0:\EFI\OC\OpenCore.efi "OpenCore"
                  ↑ parameter pertama = posisi penyisipan, 0 = diletakkan di urutan pertama
                    FS0 diganti dengan yang sudah dipastikan pada langkah sebelumnya

④ exit untuk keluar dari OpenShell → restart
```

- **Kunci mengenali ESP target**: di dalamnya **sekaligus** ada `\EFI\OC\OpenCore.efi` (OpenCore) dan `\EFI\Microsoft\Boot\bootmgfw.efi` (Windows)
- **Kriteria**: setelah restart, di menu boot BIOS muncul "OpenCore" dan **berada di posisi pertama**

### 7.3 Metode C: saat `bcfg` melapor "tidak bisa menulis", buka dulu proteksi NVRAM

Kutipan asli resmi:

> *"if OpenCore has `RequestBootVarRouting` enabled, it will be necessary to run
> `\EFI\OC\Tools\OpenControl.efi disable` before using `bcfg`."*
> *"(After `OpenControl disable`, it is necessary to either reboot or run `OpenControl restore`,
> before booting an operating system.)"*

1. Masukkan `X64/EFI/OC/Tools/OpenControl.efi` dari paket rilis resmi ke `EFI/OC/Tools/` pada **U disk**
2. Tambahkan satu entri di `Misc>Tools` yang menunjuk ke file itu, dan **set `FullNvramAccess` ke `true`**
   (resmi: *"Disable `OpenRuntime` NVRAM protection during usage of a tool."*)
3. Dari selector **jalankan tool ini sekali**, lalu masuk ke OpenShell dan jalankan `bcfg boot add` seperti di §7.2
4. ★★ **Setelah itu wajib restart (atau jalankan `OpenControl restore` di dalam OpenShell dulu), kalau tidak sistem tidak bisa boot**

### 7.4 Metode D: menulis dari dalam sistem operasi (**prasyarat `RequestBootVarRouting=false`**)

| Sistem | Cara | Catatan |
|---|---|---|
| Linux | `efibootmgr` | Inilah yang disebut secara eksplisit di teks resmi |
| macOS | `nvram <GUID>:<nama>` | Bisa membaca dan menulis entri boot firmware; **`nvram -p` tidak akan mencantumkannya** |
| Windows | EasyUEFI / Boot Camp Control Panel | Paling intuitif |

Bagian Troubleshooting resmi juga mencantumkan semua pintu masuk resmi untuk "mengubah entri boot default":

> *"This choice can be altered from UEFI Setup, with the macOS Startup Disk preference,
> or the Windows Boot Camp Control Panel."*

**Alat bantu**: `scripts/oc-nvram-bootentry.sh` (`dump` / `backup` / `restore` / `add` / `del`)
— ★ **`add` / `del` / `restore` butuh hak akses elevasi; dan hanya bermakna saat `RequestBootVarRouting=false`.**

### 7.5 Lampiran: `BootKicker` — metode resmi yang ditulis untuk "berpindah dari U disk kembali ke hard drive" (biasanya tidak tersedia di hackintosh)

Skenario yang dideskripsikan resmi di Note 3 `PickerMode` identik dengan "OpenCore di U disk → OpenCore di hard drive":

> *"…it can be used to switch which OpenCore installation is blessed, with `CTRL+Enter`,
> e.g. from a recovery OpenCore installation on USB/CD back to the main installation of OpenCore
> on the hard drive, if this is lost after an NVRAM reset."*

Namun definisinya di tabel Tools adalah *"Display Apple BootPicker menu (**for Macs with compatible firmware**)"*.
⇒ **ia bergantung pada protokol BootPicker dari Apple, jadi di firmware non-Apple (hackintosh) umumnya tidak bisa dipakai.**
Ditempatkan di sini hanya agar kamu tahu bahwa opsi resmi ini ada, **jangan habiskan waktu di sini**.

### 7.6 Bagaimana konfigurasi sehari-hari (disarankan)

| | `LauncherOption` | `RequestBootVarRouting` | Fungsi |
|---|---|---|---|
| **Yang di hard drive** | `Full` | `true` | Entri **self-healing**; dan tidak akan direbut Windows |
| **Yang di U disk** | `Disabled` | `false` (kalau mau dipakai sebagai rescue disk) atau `true` | Tidak akan pernah merebut entri hard drive; saat `false` juga bisa jadi rescue disk untuk "menulis entri boot dari dalam sistem" |

> ★ **Mengapa hard drive harus tetap `Full` + `true`**: kutipan resmi *"When `LauncherOption` is not enabled,
> other operating systems may overwrite OpenCore settings"* — begitu dimatikan,
> **update besar Windows bisa menimpa entri boot OpenCore**. `Full` justru untuk mencegah itu.
> ★ Dan **OpenCore mana pun yang akan di-boot dari U disk, `LauncherOption`-nya harus `Disabled`** (Note resmi 3) — lihat akar masalah di §1.

### 7.7 Sumber resmi (bisa kamu verifikasi sendiri)

- `Misc > Boot > LauncherOption` — empat nilai, `LauncherPath`, **Note 3** (peringatan skenario USB + langkah pemulihan `bcfg`)
- `UEFI > Quirks > RequestBootVarRouting` — definisi dan tujuan pengarah ulang
- `Misc > Tools` — `FullNvramAccess`, `OpenControl`, `OpenShell`, `BootKicker`
- `Misc > Boot > PickerMode` — Note 3 (`BootKicker` / `CTRL+Enter`)
- Troubleshooting → Tips and Tricks → *How do I choose the default boot entry?*

★ Semua di atas berasal dari `Configuration.pdf` resmi OpenCore (disertakan di setiap paket rilis, ada di `Docs/`).
**Selalu rujuk dokumen yang sesuai dengan versi OpenCore di mesinmu** — nama kunci dan nilai bisa berubah antar versi.

## 8. ★ Dari "boot dari U disk" menjadi "boot dari hard drive"

> **Kondisi aktual mesin ini** (`nvram 4D1FDA02-…:boot-path`):
> 10-15 02:55 = `…/USB(0x18,0x0)/…/\EFI\OC\OpenCore.efi` ⇒ saat itu **di-boot dari U disk** (`REL-108`);
> **10-15 03:40 = `PciRoot(0x0)/Pci(0x6,0x0)/Pci(0x0,0x0)/NVMe(0x1,…)/HD(1,GPT,…)/\EFI\OC\OPENCORE.EFI`**
> ⇒ ★★ **sudah diubah menjadi boot dari hard drive internal** (OC = `DBG-108`) — artinya **langkah-langkah di bawah ini sudah berhasil diuji di mesin ini**,
> disimpan sebagai referensi alur.

### 8.1 Mengapa harus diganti

- Tanpa U disk, **tidak bisa masuk ke sistem** (U disk menjadi titik ketergantungan tunggal)
- Yang di U disk mungkin **konfigurasi rescue** (U disk di mesin ini adalah konfigurasi FALLBACK untuk `iMacPro1,1`), bukan set yang sama dengan hard drive
- Saat `LauncherOption` di kedua sisi sama-sama `Full`, keduanya saling menimpa (§1)

### 8.2 Langkah-langkah

1. **Pastikan di ESP hard drive ada EFI yang lengkap dan bisa dipakai**
   ```bash
   diskutil list | grep "EFI EFI"                  # kenali disknya (★ nomor disk bisa bergeser, jangan hardcode)
   diskutil mount diskXs1 && ls /Volumes/EFI/EFI/OC/
   ```
   Minimal ada: `EFI/OC/OpenCore.efi`, `config.plist`, `Kexts/`, `Drivers/`, `ACPI/`, `Tools/`, `Resources/`,
   serta **`EFI/BOOT/BOOTx64.efi`** (entri cadangan).
   ★ Yang di hard drive **tidak boleh** disalin apa adanya dari U disk: `PlatformInfo` (model/tiga kode), `ACPI`, `Kernel` bisa berbeda.
2. **config hard drive**: `Misc>Boot>LauncherOption=Full` (agar ia membangun sendiri dan menempatkan di depan), `LauncherPath=Default`,
   `UEFI>Quirks>RequestBootVarRouting=true`
3. **config U disk**: `Misc>Boot>LauncherOption=Disabled` (tidak lagi menimpa NVRAM)
4. Kedua sisi mengikuti alur aman: `plutil -lint` → `ocvalidate` resmi (**wajib versi sama**) → hitung sha → `sync` →
   **unmount → mount ulang → verifikasi sha**
5. **Restart, dan pilih "hard drive itu" di menu boot firmware** (jangan pilih U disk)
6. Setelah masuk, OpenCore (hard drive, `Full`) akan membangun `Boot####` dan meletakkannya di depan saat menyala
7. ★★ **Verifikasi (ketiga langkah wajib dilakukan)**
   - Restart ke **menu boot BIOS**: ada "OpenCore" dan berada di **posisi pertama**
   - `nvram 4D1FDA02-…:boot-path`: menunjuk ke ESP **hard drive** (bukan `USB(...)`)
   - **Cabut U disk lalu restart sekali lagi**, pastikan tetap bisa masuk sistem ← **langkah inilah yang benar-benar menjadi verifikasi**
8. Opsional: simpan U disk sebagai **rescue disk** (tetap `Disabled`), atau hapus entri boot lamanya

### 8.3 Perhatikan

- ★ **Yang diganti bukan hanya media boot, tapi juga "config yang mana"** — yang di hard drive mungkin berstatus **debug**
  (di mesin ini hard drive = `DBG-108`, U disk = `REL-108`). **Apakah sekalian dikembalikan ke RELEASE / dimatikan debug log, adalah keputusan terpisah, tanyakan dulu ke pengguna.**
- ★ **Jangan pakai `ScanPolicy` untuk "menampilkan lebih sedikit"** (itu kebijakan keamanan, lihat `pitfalls.md` §A).
- ★ Setelah berganti, **periksa ulang kepemilikan `en0`** (ganti media boot tidak memengaruhi NIC, tetapi kalau ada hal lain yang ikut diubah, lihat `network-en0-order.md`).
- ★ Setiap kali selesai mengubah ESP, **sinkronkan mirror workspace + arsip versi**, kalau tidak lain kali tidak bisa dibedakan mana yang mana.
