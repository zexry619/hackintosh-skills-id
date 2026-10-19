# Indeks toolkit dan patch laobamac (Hackintosh)

> `laobamac` memelihara **48 repositori**, dan sebagian besar di antaranya adalah toolkit dan driver terkait hackintosh yang "**memakai kext asli / mekanisme resmi, tanpa patch**".
> File ini adalah **indeks lengkap** —— untuk cara penggunaan yang lebih rinci, lihat README masing-masing repositori.
>
> **Pembagian**: kartu jaringan kabel lihat `ethernet-drivers.md` · Wi-Fi nirkabel lihat `mediatek-wifi.md` / `intel-wifi.md` ·
> kartu suara lihat `applealc-custom.md` · NVIDIA lihat `nvidia-driver.md` · ACPI lihat `acpi-ssdt.md`.

## ★★ Baca ini dulu: proyek mana yang sudah diarsipkan (2026-06)

**Pada Juni 2026, sejumlah proyek sekaligus masuk status arsip** —— kutipan asli penulis:
*"non-kondisi ekstrem khusus (misalnya kiamat) tidak lagi menerbitkan pembaruan apa pun"*.

| Repositori | Tanggal arsip | Dampak |
|---|---|---|
| **`OCLP-Mod`** | **2026-06-13** | Versi yang sudah ada **masih bisa dipakai**, tapi **node API akan ditutup bertahap** ⇒ ★ **matikan `SimpleHacAPI` di pengaturan OCLP-Mod** |
| **`SimpleKaruzi`** | **2026-06-18** | Tidak lagi diperbarui (★ tapi **OCLP(-Mod) 3.0.0 yang mendukung awal macOS Tahoe 26** yang disebutkannya masih berlaku) |
| `SimpleGBE` | 2026-06-18 | Tidak lagi diperbarui |
| `SimpleLaunchPadRestore` | 2026-06-18 | Tidak lagi diperbarui |

> ★★ **Tapi pada 2026-10 penulis kembali aktif** —— `SimpleHDA` (dibuat 10-13), `SimpleMtkWlan` / `SimpleMtkBtFw`,
> fork `itlwm` semuanya hal baru.
> ⇒ **Disiplin: sebelum memakai suatu repositori, cek dulu kapan push terakhirnya**, jangan menganggap "sudah diarsipkan" sama dengan "masih dirawat".

---

## 1. Driver hardware

| Repositori | Untuk apa | Rincian |
|---|---|---|
| **`SimpleHDA`** | **Memulihkan `AppleHDA` asli di macOS 26** (disuntik OpenCore, tanpa patch / tanpa mematikan SIP / tanpa KDK); ★ **sekarang turun menjadi opsi cadangan** (penulis tidak mengizinkan pengembangan lanjutan + hanya alpha + ada masalah yang diketahui)⇒ pilih utama lihat `applealc-custom.md` §0.5 | `applealc-custom.md` §0.5.6 |
| `SimpleMtkWlan` / `SimpleMtkBtFw` / `SimpleMTKClient` | MediaTek Wi-Fi / Bluetooth | `mediatek-wifi.md` |
| `itlwm` (fork) | Intel Wi-Fi | `intel-wifi.md` |
| **`SimpleVGBE`** | Intel **I225 / I226** 2.5G | `ethernet-drivers.md` |
| **`SimpleGBE`** | Intel I210/I211/82575·76·80/I350 Gigabit | `ethernet-drivers.md` |
| **`SimpleHacPlugins`** (dulang `SakuraPlugins`) | **`SimpleEthernet`** (plugin Lilu, i225/226/210/211) · `SakuraLegacyFix` (I350/X540, sedang diuji) · `SimpleLexa` (AMD RX5300/RX550, dalam pengembangan) | `ethernet-drivers.md` |
| **`SimpleRTK5`** | Realtek **RTL8125 / 8126** 2.5/5GbE | `ethernet-drivers.md` |
| ~~`SimpleRTLHV`~~ | ★ **sudah digabung ke `SimpleRTK5`, jangan dipakai terpisah lagi** | — |
| `nvidia-macos-driver` (fork) | Driver NVIDIA Metal (upstream adalah `nullmoth`) | `nvidia-driver.md` |

## 2. Instalasi / pembuatan EFI

| Repositori | Kegunaan | Catatan |
|---|---|---|
| **`SimpleKaruzi`** | **Membuat EFI OpenCore lebih sederhana** —— mengotomasi alur pengaturan dasar + menyediakan konfigurasi terstandar, mengurangi kerja manual | **AGPL-3.0**; ★ **sudah diarsipkan pada 2026-06-18**; README menyebut **OCLP(-Mod) 3.0.0 sudah mendukung awal macOS Tahoe 26** |
| `PVE-OpenCore` | **Memasang macOS di PVE** (bootloader berbasis OpenCore) | **GPL-3.0**; penulis menyebut lebih **kecil dan lebih sedikit bug** dibanding `KVM-OpenCore` (memuat basesystem macOS); sejak V20240224 tidak lagi menyertakan recovery |

> Saling menggantikan dengan `rapidefi-first-efi.md` (membuat EFI dasar dengan RapidEFI di Windows).

## 3. ★★ Wajib dibaca sebelum merakit: jebakan hardware

| Repositori | Isi |
|---|---|
| ★★ **`SimpleBuyersGuide`** | **"Panduan jebakan hardware hackintosh"** —— mencantumkan secara eksplisit perangkat yang **seharusnya tidak dibeli**: <br>**CPU** · **GPU** (tidak didukung sama sekali / harus dihindari) · **motherboard** (chipset dan merek yang harus dihindari) · **penyimpanan** (SSD yang tidak didukung sama sekali / harus dihindari) · **RAM** (masalah XMP dan sleep) · pendingin · **perangkat jaringan** (kartu jaringan yang harus dihindari) · **perangkat nirkabel** (Wi-Fi yang tidak didukung sama sekali / harus dihindari) · power supply · casing · thermal paste |

> ★ **Baca ini dulu sebelum merakit / mengganti komponen**, jauh lebih hemat dibanding troubleshooting setelah kejadian. Pasangan dengan `bios-settings.md` (audit BIOS).

## 4. Toolkit perawatan sistem / pemasangan kext

| Repositori | Kegunaan | Catatan |
|---|---|---|
| ★★ **`SimpleLoader`** | **Penggabungan KDK + pemasangan kext + pembuatan ulang kernel cache + perlindungan snapshot APFS** (antarmuka grafis SwiftUI) | macOS 11+;**GPLv3**; ★ **lebih aman daripada `kmutil` manual / operasi snapshot** (memiliki rollback snapshot bawaan) |
| `SimpleBoxi` | *"macOS all-in-one toolbox"* | **GPL-2.0** |
| `KdkSupportPkg` (fork) | **Citra Kernel Debug Kit** (Ventura dan yang lebih baru) | — |
| `MetallibSupportPkg` (fork) | **Tool patch Metal Library** | — |
| `PatcherSupportPkg` (fork) | **Paket sumber daya patch OCLP** | — |

## 5. Memulihkan fitur yang hilang di macOS 26

| Repositori | Kegunaan | Catatan |
|---|---|---|
| **`SimpleLaunchPadRestore`** | **Memulihkan LaunchPad lama dengan satu klik** (macOS 26 mengganti LaunchPad dengan gaya Spotlight) | Membutuhkan **Tahoe 26.0 B4+** + **SIP sudah dimatikan** (`03080000` atau lebih tinggi); mengganti `Apps.app` / `Dock.app` / `Spotlight.app`; ★ **sudah diarsipkan** |
| **`SimpleLaunchpad`** | **App pengganti LaunchPad yang mandiri** (tampilan grid / pencarian / klasifikasi otomatis / dipanggil dengan `⌘⇧L` / efek frosted glass) | **AGPL-3.0**; ★ penulis menandai **masih dalam pengembangan dan tidak stabil** |

> ★ Tidak terkait hackintosh, tapi banyak pengguna macOS 26 yang mengalaminya (LaunchPad dihapus).

## 6. Referensi / repositori patch

| Repositori | Isi |
|---|---|
| ★ **`OC-little-zh`** | **Panduan hot patch ACPI bahasa Tionghoa** —— dasar ACPI · mengaktifkan/menambahkan perangkat lewat SSDT · menonaktifkan perangkat · memperbaiki kartu grafis (iGPU/dGPU)· memperbaiki USB · memperbaiki restart/sleep/wake · masalah periferal · patch khusus laptop · CMOS · folder EFI · **urutan pemuatan kernel extension** · **Whitelist MMIO** · kecepatan memori ⇒ **referensi bahasa Tionghoa saat menulis SSDT / memperbaiki ACPI** (bersama `acpi-ssdt.md`); ★ **versi perluasan bahasa Inggrisnya ada di `5T33Z0/OC-Little-Translated`** (jauh melampaui karya asli, plus bab 7–20 dan appendix A–Z) |
| `non-metal-frameworks` | **Repositori patch framework non-Metal** (berdasarkan repositori Moraea yang sudah dihapus)⇒ patch untuk kartu grafis lama pada sistem yang sudah berbasis Metal (bersama `nvidia-driver.md`) |
| `misc-patches` | **Patch miscellan** — *"Patches not covered in non-metal-frameworks or elsewhere"* |
| `SimpleBuyersGuide` | Lihat §3 |

## 7. Virtualisasi

| Repositori | Kegunaan |
|---|---|
| `PVE-OpenCore` | Lihat §2 |

## 8. Platform AMD

| Repositori | Isi |
|---|---|
| `AMD_Vanilla` (fork) | Patch OpenCore untuk **menjalankan macOS native di platform AMD** |
| `NootedRed` (fork) | **Patch dukungan iGPU AMD Vega** (★ penulis menandai **No commercial use**) |
| `SMCAMDProcessor` (fork) | **Manajemen daya / monitoring processor AMD** (plugin VirtualSMC) |

> Mesin ini memakai Intel, jadi beberapa item ini **hanya sebagai referensi**; hanya dibutuhkan pada mesin AMD.

## 9. Fork dari repositori upstream (versi yang sudah diubah penulis)

| Repositori | Upstream |
|---|---|
| `Lilu` · `OpenCorePkg` · `AppleALC` · `WhateverGreenPR` · `Hackintool` · `OpenCore-Legacy-Patcher` · `USBToolBox` · `UTBKext` · `SMCAMDProcessor` | masing-masing upstream-nya |

> ★ **Ini adalah fork**, biasanya dipakai untuk "mengubah satu versi untuk mencoba PR / membuat patch sendiri".
> **Untuk pemakaian sehari-hari, ambil dulu versi upstream resmi**; pakai fork hanya bila **perubahanannya disebut eksplisit** di README/commit fork tersebut.
> Dari namanya, `WhateverGreenPR` terlihat seperti **versi eksperimen untuk mengirim PR ke upstream**, jangan dipakai sebagai versi stabil.

## 10. Referensi EFI pribadi

| Repositori | Konfigurasi |
|---|---|
| `Hackintosh-i7-8700K-ASUS-PRIME-Z370-A-Z370-F` | i7-8700K + ASUS PRIME Z370-A |
| `Hackintosh-I3-9100F-B365M-RX580` | i3-9100F + B365M + RX580 |

> ★ **EFI orang lain hanya boleh jadi referensi, tidak bisa langsung dipakai** —— terutama **peta port USB** mengodekan "bagaimana board itu dikabelkan",
> **memakai silang antar merek / antar model pasti bermasalah** (lihat `intel-wifi.md` §5 dan disiplin terkait `usb`).

---

## Cara memakai indeks ini

| Yang ingin kamu lakukan | Pakai yang mana |
|---|---|
| **Sebelum merakit / mengganti hardware** | ★ `SimpleBuyersGuide` (panduan jebakan) |
| **Membuat EFI dari nol** | `SimpleKaruzi` (sudah diarsipkan) atau RapidEFI dari `rapidefi-first-efi.md` |
| **Memperbaiki ACPI / menulis SSDT** | ★ `OC-little-zh` (Tionghoa) + ★★ `5T33Z0/OC-Little-Translated` (versi perluasan bahasa Inggris, contoh paling lengkap) + `acpi-ssdt.md` |
| **Memasang kext ke direktori sistem / menggabungkan KDK / membangun ulang cache** | ★ `SimpleLoader` (punya perlindungan snapshot) |
| **Kartu suara** | lebih dulu kartu suara USB / `MyKextInstaller`+KDK (`applealc-custom.md` §0.5)· cadangan `SimpleVoodooHDA` (kualitas suara berkurang); `SimpleHDA` sudah turun menjadi opsi cadangan |
| **Kartu jaringan kabel** | `ethernet-drivers.md` |
| **Kartu grafis lama** | `non-metal-frameworks` + `misc-patches` |
| **Ingin LaunchPad lagi di macOS 26** | `SimpleLaunchPadRestore` / `SimpleLaunchpad` |
| **Memasang macOS di PVE** | `PVE-OpenCore` |

> ★ **Semua kext pihak ketiga ini tidak ditandatangani Apple** ⇒ butuh `SecureBootModel=Disabled`, SIP dilonggarkan sesuai kebutuhan.
> ★ Saat mengunduh **verifikasi sumber repositori dan hash berkas**; **proyek yang sudah diarsipkan tidak akan memperbaiki bug lagi**.
