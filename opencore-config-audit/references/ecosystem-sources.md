# Ekosistem Hackintosh: Sumber Otoritatif dan Indeks Alat

> File ini menjawab satu pertanyaan: **"Untuk mengerjakan sesuatu, siapa yang harus dipercaya dan alat mana yang dipakai"**.
> Hanya collects sumber yang memiliki "upstream jelas / rawatan jangka panjang / diakui komunitas".
> Fork pribadi oleh seorang penulis dan proyek yang diarsipkan lihat `laobamac-toolkit.md`.

## 0. ★★ Peringkat otoritas (ingat ini dulu)

1. **Repositori resmi Acidanthera + dokumentasi resmi** —— **otoritas tertinggi**. **Satu-satunya otoritas** untuk konfigurasi adalah `Docs/Configuration.pdf` di dalam paket `OpenCorePkg`
2. **Panduan Dortania** —— standar faktual komunitas (Panduan Instalasi / Post-Install / ACPI)
3. **README milik penulis driver itu sendiri** —— satu-satunya otoritas untuk perilaku driver
4. **Postingan forum / blog** —— hanya sebagai **petunjuk**, kesimpulan harus diverifikasi kembali ke 1–3

> ★★ **Disiplin: dokumentasi resmi > README penulis driver > postingan forum.**
> Setiap kesimpulan "yang disebut forum" harus diverifikasi kembali ke `Configuration.pdf` atau source code driver.

## 1. Sumber otoritatif —— Acidanthera (48 repositori)

| Repositori | ★ | Apa itu |
|---|---|---|
| **`OpenCorePkg`** | 15.5k | **Bodi boot OpenCore**. ★ `Docs/Configuration.pdf` adalah **satunya otoritas** konfigurasi; `Docs/AcpiSamples/` adalah sampel resmi SSDT (18) |
| **`Lilu`** | 3.9k | **Host untuk semua plugin** (AppleALC / WhateverGreen / CPUFriend / RestrictEvents… semuanya bergantung padanya) |
| `AppleALC` | 3.6k | Audio onboard → `applealc-custom.md` |
| `WhateverGreen` | 3.4k | Patch GPU (ATI/AMD/Intel/NVIDIA) |
| `VirtualSMC` | 1.8k | Lapisan emulasi SMC (termasuk plugin seperti `SMCProcessor` / `SMCSuperIO`) |
| `BrcmPatchRAM` | 1.2k | Unggah firmware Bluetooth Broadcom → `broadcom-wifi.md` |
| **`OcBinaryData`** | 814 | **Set ikon / font / label / audio resmi** → `theme-opencanopy.md` |

> ★ Ada juga `RestrictEvents` (`revpatch=` / `revcpu=`), `CPUFriend`, `NVMeFix`, `AirportBrcmFixup`, `IntelMausi`,
> > `AppleMCEReporterDisabler`, `CryptexFixup`, dan lain-lain —— **cari di halaman organisasi sesuai kebutuhan**.

## 2. Sumber otoritatif —— Dortania (33 repositori)

| Repositori | ★ | Apa itu |
|---|---|---|
| **`OpenCore-Legacy-Patcher`** | 18.6k | **OCLP** —— memberikan root patch untuk Mac lama / Hackintosh → `broadcom-wifi.md` / `os-upgrade-15-to-26.md` |
| **`OpenCore-Install-Guide`** | 4.3k | **Panduan Instalasi OpenCore** (standar faktual komunitas: `dortania.github.io/OpenCore-Install-Guide`) |
| **`Getting-Started-With-ACPI`** | 672 | **Pengantar ACPI** —— bacaan pertama untuk menulis SSDT |
| `OpenCore-Post-Install` | 630 | Penyelesaian setelah instalasi (`dortania.github.io/OpenCore-Post-Install`) |
| `KdkSupportPkg` | 248 | **Cermin KDK** (Ventura+) |

## 3. Alat —— koleksi corpnewt (99 repositori)

| Alat | ★ | Kegunaan |
|---|---|---|
| **`gibMacOS`** | 7.3k | Mengunduh komponen macOS secara langsung (membuat media instalasi) |
| **`ProperTree`** | 3.2k | **Editor plist lintas platform** —— alat utama untuk mengubah `config.plist` (dengan snapshot / pembersihan OC) |
| **`GenSMBIOS`** | 2.0k | Menggunakan `macserial` resmi untuk membuat tiga kode SMBIOS → `smbios-and-serials.md` |
| **`SSDTTime`** | 1.3k | **Membuat SSDT yang umum secara otomatis** (hot patch DSDT) |
| **`USBMap`** | 1.3k | **Memetakan port USB** di macOS dan menghasilkan kext |
| **`MountEFI`** | 1.2k | Memount partisi EFI (★ macOS 26 di mesin ini butuh privilege elevasi, lihat `pitfalls.md`) |

### Alat lainnya

| Alat | Penulis | Kegunaan |
|---|---|---|
| **`USBToolBox/tool`** ★1.5k | USBToolBox | **Pemetaan port USB** (mode ganda Windows / macOS); `USBToolBox/kext` ★455 adalah injector |
| **`blacktop/ipsw`** ★3.8k · **`ipsw-diffs`** ★899 | blacktop | **Alat riset iOS / macOS**; `ipsw-diffs` dapat melihat **perbedaan versi kernel dan kext** —— ★ **kita menemukan `AppleSunriseWLAN.dext` di macOS 26 berkat alat ini** |
| `NullMoth/1401` ★469 · `1401-probe` ★30 | NullMoth | **Memasang macOS dari Windows**; `1401-probe` adalah **USB pemindai perangkat keras offline** |

## 4. Penulis driver (dikelompokkan menurut perangkat keras)

| Perangkat keras | Penulis / Repositori | Detail |
|---|---|---|
| **Nirkabel Intel** | **`OpenIntelWireless`** —— `itlwm` ★7.1k · `IntelBluetoothFirmware` ★2.5k · `HeliPort` ★1.3k (penulis asli **`zxystd`**) | `intel-wifi.md` |
| **Nirkabel / Bluetooth MediaTek** | **`GeekAudio/mediatek-sunrise-hackintosh` (MT7922 Sunrise Pack)** —— paket sekali jalan untuk Sunrise native di macOS 26 (firmware + `AppleSunrise.kext` + SSDT + fragmen spoofing + seluruh kext pihak ketiga macOS 15) · `flxxxxddd/SimpleMtkWlan` (fork) + `laobamac/SimpleMtkBtFw` (jalur pihak ketiga) | `mediatek-wifi.md` |
| **Nirkabel / Bluetooth Broadcom** | **Acidanthera** —— `AirportBrcmFixup` / `BrcmPatchRAM` | `broadcom-wifi.md` |
| **MediaTek** | **`laobamac`** —— `SimpleMtkWlan` / `SimpleMtkBtFw` | `mediatek-wifi.md` |
| **NIC kabel** | **`Mieze`** —— `LucyRTL8125Ethernet` ★296 · `IntelMausiEthernet` ★413 · `RTL8111_driver_for_OS_X` ★717 · `IntelLucy` ★76 · `RTL812xLucy` ★22<br>**`Shaneee`** —— `AppleIGB` ★30<br>**`laobamac`** —— `SimpleVGBE` dan lain-lain | `ethernet-drivers.md` |
| **Kartu suara** | **Acidanthera** (`AppleALC`) · ★★ **`5T33Z0`** (`AppleALC-Guides` —— **referensi utama praktis untuk layout kustom**, 17 dump siap pakai, `alc-verb`; ditambah `Audio_Tahoe.md` dari `OCLP4Hackintosh`) · **`perez987`** (panduan `AppleHDA-gone-on-macOS-26-Tahoe`) · **`Mirone`** (`MyKextInstaller`) · **`laobamac`** (`SimpleLoader` / `SimpleHDA` (alternatif) / `SimpleVoodooHDA`) · **`chris1111`** (skrip VoodooHDA upstream) | `applealc-custom.md` |
| **NVIDIA** | **`NullMoth`** —— `nvidia-macos-driver` ★3.0k | `nvidia-driver.md` |
| **iGPU / CPU AMD** | `NootedRed` (Vega) · `AMD_Vanilla` · `SMCAMDProcessor` | `laobamac-toolkit.md` §8 |
| **Wi-Fi USB (eksternal)** | **`chris1111`** —— seri `Wireless-USB-*` ★1k+ | — |
| **Patch GPU lama** | **`chris1111`** —— `Geforce-Kepler-patcher` ★378 · `Legacy-Video-patch` ★197; `non-metal-frameworks` | `nvidia-driver.md` |

## 5. Sumber berbahasa Mandarin

| Sumber | Konten |
|---|---|
| ★ **`daliansky/OC-little`** ★1.6k | **Contoh hot patch ACPI —— karya asli berbahasa Mandarin** (Prajurit Hitam Daliansky) ⇒ versi terorganisasi berbahasa Mandarin = **`laobamac/OC-little-zh`** (lihat `laobamac-toolkit.md` §6) · **versi perluasan bahasa Inggris = `5T33Z0/OC-Little-Translated`** (lihat di bawah) |
| ★ **`daliansky/Hackintosh`** ★10.0k | **Kumpulan EFI yang dirawat jangka panjang + tutorial instalasi** (Prajurit Hitam) |
| `daliansky/daliansky.github.io` | Blog "Tribu" milik Prajurit Hitam |
| ★★★ **`5T33Z0/OC-Little-Translated`** ★745 | **Referensi utama pustaka contoh hot patch ACPI** —— bermula dari terjemahan Inggris OC-Little, tetapi **jauh melampaui karya asli** (bab 7–20 baru + lampiran lengkap A–Z); **hanya memakai hot patch ACPI, tidak melakukan DSDT patch**; mencakup dasar ACPI/penghapusan tabel/penamaan ulang · tambah/nonaktifkan perangkat · daya CPU · GPU (termasuk **GPU-BAR**) · USB (termasuk **memetakan port dengan ACPI**) · sleep/wake · laptop · CMOS · **whitelist MMIO / AppleVTD** · Thunderbolt · penjelasan boot-args / Quirks · urutan kext · **OCLP on Wintel** · multi-sistem · virtual machine · **membuat ALC Layout-ID sendiri** · troubleshooting (SysReport / Preboot / spindump) ⇒ indeks lihat `acpi-ssdt.md` §0 |
| `5T33Z0/OCLP4Hackintosh` ★79 | Panduan ringkas penggunaan OCLP di Hackintosh (★ `Enable_Features/Audio_Tahoe.md` = **memulihkan AppleALC dengan root patch di macOS 26**) |
| **Forum Yuanjing `bbs.pcbeta.com`** | Komunitas berbahasa Mandarin —— ★ **bisa diakses langsung** (kita memperoleh informasi primer tentang `SimpleHDA` dari sana) |
| `tonymacx86.com` | Forum lama berbahasa Inggris —— ⚠️ **ada captcha Cloudflare, program tidak bisa mengambilnya** |
| `InsanelyMac` / `AppleLife` | **Saluran diskusi resmi yang ditentukan AppleALC** (lihat `applealc-custom.md` §6) |

## 6. Referensi khusus (GPU / pemilihan / bukti)

| Repositori | Penulis | Konten |
|---|---|---|
| `khronokernel/Anti-Hackintosh-Buyers-Guide` ★165 | khronokernel | **Panduan pembeli anti-Hackintosh** (= sumber asli bahasa Inggris dari `laobamac/SimpleBuyersGuide`) |
| `khronokernel/IO80211-Patches` ★68 | khronokernel | Kext `IO80211Family` yang sudah dipatch |
| `khronokernel/SmallTree-I211-AT-patch` ★83 | khronokernel | Dukungan Intel I211-AT |
| ★ `khronokernel/IORegistryClone` ★80 | khronokernel | **Mengkloning IOReg mesin Apple** (★ sangat berguna untuk membandingkan dengan mesin asli) |
| `khronokernel/Getting-Started-With-OpenCore` ★142 | khronokernel | Pengantar ringkas OpenCore |
| `5T33Z0/AppleALC-Guides` ★66 | 5T33Z0 | ★★★ **Referensi utama praktis untuk layout kustom AppleALC** (14 bab: dump → topologi → PathMap → PinConfig → kompilasi → uji → PR) · **17 dump codec siap pakai** · **`alc-verb` untuk penyetelan audio saat runtime** · tabel `MuteGPIO` · **diperkecil ke 90 KB** · pengelolaan file/rollback |
| `5T33Z0/OCLP4Hackintosh` | 5T33Z0 | Praktik OCLP di Hackintosh (★ `Enable_Features/Audio_Tahoe.md` = **memulihkan semua fungsi AppleALC dengan root patch di macOS 26**) |
| `perez987/AppleHDA-gone-on-macOS-26-Tahoe` | perez987 | ★★ **Kartu suara onboard di macOS 26: memasang kembali `AppleHDA.kext`** (KDK + `MyKextInstaller` / `SimpleLoader`) —— referensi utama pemulihan kartu suara |
| `perez987/Fenvi-wifi-back-on-Sonoma-Sequoia-Tahoe` ★132 | perez987 | Memulihkan Wi-Fi pada **kartu Broadcom** seperti Fenvi T919 di sistem baru |
| `perez987/Intel-AX210-on-Sonoma-Sequoia-Tahoe` ★120 | perez987 | **Intel AX210S** berhasil berjalan di sistem baru |
| `perez987/OpenCore-and-UEFI-Secure-Boot` ★116 | perez987 | **UEFI Secure Boot + OpenCore** |
| `perez987/RX6600XT-on-macOS-with-softPowerPlayTable` ★110 | perez987 | `softPowerPlayTable` untuk AMD RX 6600 XT (mematikan Zero RPM) |

**`GeekAudio` (karya penulis proyek ini)**:

| Repositori | Konten |
|---|---|
| `GeekAudio/mediatek-sunrise-hackintosh` | ★★ **MT7922 Sunrise Pack**: mengumpulkan seluruh lampiran postingan tonymacx86 332855 menjadi satu paket (firmware + `AppleSunrise.kext` yang diekstrak dari dua versi KDK + SSDT + spoof `DeviceProperties` tanpa kompilasi + boot-args + seluruh kext pihak ketiga macOS 15 termasuk SimpleMTK yang sudah dikompilasi) —— **referensi utama** untuk jalur Sunrise native |
| `GeekAudio/tcc-helper` | ★★ **Alat izin macOS (TCC)**: menulis entri "sudah diizinkan" langsung ke database TCC, melewati dialog; **secara otomatis menyimpulkan siapa membutuhkan izin apa dari `Info.plist` + komponen background launchd**; GUI + CLI |
| `GeekAudio/hackintosh-skills` | Repositori publik skill ini (opencore-config-audit) |
| `GeekAudio/i7-12700K-RTX3080-OpenCore-Hackintosh` | Repositori rilis EFI mesin ini yang datanya sudah disanitasi |

## 7. Cara memakai indeks ini

| Yang ingin dilakukan | Percaya / Pakai yang mana |
|---|---|
| **Mengubah satu saja kunci config** | ★★ **`Docs/Configuration.pdf` milik `OpenCorePkg`** + `ocvalidate` resmi |
| **Memasang / menaikkan versi sistem** | ★★ **`OpenCore-Install-Guide` Dortania** + `lifecycle.md` / `os-upgrade-15-to-26.md` dari skill ini |
| **Menulis SSDT** | `Getting-Started-With-ACPI` + `daliansky/OC-little` + `5T33Z0/OC-Little-Translated` + `acpi-ssdt.md` |
| **Mengubah plist** | `corpnewt/ProperTree` |
| **Membuat tiga kode** | `corpnewt/GenSMBIOS` (dasarnya `macserial` resmi) |
| **Pemetaan port USB** | `corpnewt/USBMap` (sisi macOS) · `USBToolBox/tool` (mode ganda Windows/macOS) |
| **Membuat SSDT otomatis** | `corpnewt/SSDTTime` |
| **Mengunduh macOS / membuat media instalasi** | `corpnewt/gibMacOS` · `NullMoth/1401` (sisi Windows) |
| **Melihat perbedaan versi kernel / kext** | `blacktop/ipsw-diffs` (★ penemuan `AppleSunriseWLAN` bergantung padanya) |
| **Menghindari jebakan sebelum merakit mesin** | `khronokernel/Anti-Hackintosh-Buyers-Guide` (sumber bahasa Inggris) · `laobamac/SimpleBuyersGuide` (bahasa Mandarin) |
| **Membandingkan dengan IOReg mesin asli** | `khronokernel/IORegistryClone` |
| **Meminta bantuan di forum** | Yuanjing (bahasa Mandarin, bisa diakses langsung) · InsanelyMac / AppleLife (resmi untuk AppleALC) · tonymacx86 (perlu captcha manual) |

> ★★ **Catatan terakhir**: jumlah ★ di file ini adalah **snapshot saat itu**, hanya sebagai acuan; **untuk melihat apakah sebuah proyek masih hidup, gunakan waktu push terakhir sebagai acuan**.
