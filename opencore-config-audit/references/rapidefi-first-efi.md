# Mulai dari nol: membuat EFI dasar di Windows (RapidEFI)

> ★ **Pilihan lain untuk membuat EFI dari nol**: `laobamac/SimpleKaruzi` — *"sebuah alat yang dikhususkan untuk menyederhanakan proses pembuatan OpenCore EFI,
> dengan mengotomatiskan alur pengaturan dasar dan menyediakan konfigurasi terstandarisasi"* (**AGPL-3.0**).
> ⚠️ **Sudah diarsipkan pada 2026-06-18**, tidak lagi diperbarui. Indeks ada di `laobamac-toolkit.md` §2.

> Alat: **`JeoJay127/RapidEFI-Tool`** — "sebuah alat konfigurasi, pembuatan otomatis, dan pemeliharaan OpenCore EFI yang ditujukan untuk pengguna umum".
> Pernyataan resmi: logika konfigurasinya **mengikuti dokumen resmi OpenCore dan panduan instalasi OpenCore Dortania**.
> Bagian yang diapit tanda kutip di bawah adalah kalimat asli README, sisanya adalah cara untuk memasukkannya ke dalam alur kerja skill ini.

## 0. Kapan memakai dokumen ini

- Belum punya **satu pun** OpenCore EFI yang bisa boot, dan ingin memasang Hackintosh dari nol
- Yang ada hanya Windows (atau Linux/macOS), dan ingin membuat **EFI dasar yang bisa boot media instalasi** sebelum merakit mesin
- Sudah punya EFI dan hanya ingin membuat ulang versi pembanding ⇒ boleh, tapi **jangan langsung menimpa EFI yang sedang dipakai**

## 1. Posisi resmi dan batasannya (wajib dibaca dulu)

- "Konfigurasi EFI otomatis bergantung pada informasi perangkat keras, tabel ACPI, dan penilaian aturan bawaan, **hasil yang dihasilkan cocok sebagai konfigurasi dasar, belum tentu konfigurasi final tanpa perlu debugging**."
- "Setelah menghasilkan EFI, disarankan untuk **terlebih dahulu menguji boot dengan flash disk cadangan, jangan langsung menimpa EFI yang sedang dipakai dan stabil**."
- "Instalasi dan debugging Hackintosh memiliki perbedaan perangkat keras, mohon **backup data penting sejak awal**."
- Alat ini **sepenuhnya gratis, offline, tanpa iklan**; kemampuan inti sudah menyatu di dalamnya, tidak bergantung pada jaringan (tetap bisa dijalankan walau tidak bisa terhubung ke GitHub)
- ⇒ Kesimpulan: **yang dihasilkannya adalah "titik awal yang bisa dipakai", bukan titik akhir**. Penyelesaian tetap dilakukan dengan memverifikasi per kunci mengikuti dokumen resmi pada tahap 1–2 dari skill ini

## 2. Persyaratan platform dan versi

| Lingkungan slain | Dukungan (poin utama README asli) |
|---|---|
| **Windows** | **Hanya Windows 10 ke atas** (termasuk virtual machine); direkomendasikan, karena "pengumpulan informasi perangkat keras dan alur konfigurasi otomatis paling lengkap" |
| macOS | Catalina 10.15 ke atas; **kartu grafis perangkat runny harus mendukung Metal**, tidak disarankan menjalankannya di virtual machine macOS |
| Linux | Debian 10+, Ubuntu 20.04 LTS ~ 24.04 LTS; kemampuan pengumpulan hardware berbeda dari Windows |

- macOS target mencakup **High Sierra 10.13 ~ Tahoe 26**
- Templat platform: Intel desktop generasi 0–15; laptop generasi 0–10 (**inti grafis generasi 11 ke atas tidak bisa didorong**); NUC; HEDT (X58/X79/X99/X299/X599); AMD (Bulldozer/Jaguar, Ryzen, Threadripper)
- ⚠️ README secara eksplisit menyarankan: **matikan dulu 360, Tencent PC Manager, Huorong, dan software keamanan lain sebelum menjalankannya di Windows**, jika tidak proses pembuatan/penyalinan file bisa diblokir
  — ini sama dengan **menurunkan sementara proteksi sistem**, merupakan tindakan "tahu apa yang sedang dilakukan": matikan hanya selama alat berjalan, aktifkan kembali segera setelah selesai

## 3. Alur untuk pemula (6 langkah asli README)

1. Buka **Konfigurasi EFI → Konfigurasi EFI otomatis**
2. Di bawah Windows klik **Refresh hardware info**, tunggu informasi perangkat keras selesai dimuat; juga bisa mengimpor data hardware yang diekspor dari komputer lain
3. Lihat **peringatan kompatibilitas hardware**, bila perlu masuk ke **Pengaturan EFI** untuk menyesuaikan versi macOS, tata letak sound card, skema SSDT, dan lainnya
4. Klik **Output EFI**, tunggu alat menghasilkan EFI
5. **Uji boot dengan flash disk cadangan**
6. Bila perlu penyesuaian lanjutan, gunakan **Proses EFI** untuk mengimpor `configModel` dari direktori hasil generate (**tidak perlu mengedit `config.plist` secara manual**)

> Saat menghasilkan EFI, `configModel` akan disimpan, dan "Proses EFI" memakainya untuk penyesuaian lebih lanjut; setiap generate yang berhasil juga meninggalkan **riwayat** untuk dibandingkan dan diekspor ulang.

**Membuat EFI untuk komputer lain**: ekspor **laporan hardware + tabel ACPI** dulu di mesin target, lalu gunakan **Impor data hardware** di alat ini untuk mengimpornya.
"Ketika tabel ACPI tidak tersedia, konfigurasi dasar masih bisa dibuat, tetapi **kemampuan SSDT kustom menjadi terbatas**" — jadi sebaiknya tabel ACPI dibawa serta.

## 4. Persiapan sisi perangkat keras sebelum menjalankan (di luar alat, tetapi menentukan keberhasilan)

- **BIOS**: Above 4G Decoding **ON**, CSM **OFF**; mode SATA AHCI; matikan Secure Boot;
  sesuaikan CFG Lock / VT-d sesuai platform (catat nilai saat ini, nanti tentukan apakah perlu `AppleXcpmCfgLock` / `DisableIoMapper` mengikuti dokumentasi)
- **Informasi perangkat keras mesin target harus akurat**: model CPU, kartu grafis (termasuk PCI ID), model kartu jaringan kabel/nirkabel, codec sound card, antarmuka disk
- **Siapkan satu flash disk cadangan** (khusus untuk uji boot), serta backup lengkap dari sistem yang sedang dipakai
- Tiga kode (Serial / MLB / UUID / ROM) **harus dibuat sendiri** (misalnya dengan `macserial`), jangan menyalin milik orang lain

## 5. Empat hal yang wajib dilakukan setelah generate

Alat ini memberi konfigurasi dasar, jadi hal-hal berikut **wajib Anda periksa sendiri** (skrip dalam skill ini memang untuk itu):

1. **Validasi resmi + verifikasi per kunci** (tahap 1–2)
   ```bash
   scripts/fetch-opencore-docs.sh <versi OpenCore di mesin>   # ambil dokumen resmi versi yang sama dan ocvalidate
   scripts/oc-verify.sh <EFI/OC/config.plist> ./_oc-docs-audit
   ```
   Fokuskan pengecekan pada: `Kernel>Block IOPCIFamily/IONDRVSupport`, `SecureBootModel`, `csr-active-config`,
   `ResizeGpuBars`/`ResizeAppleGpuBars`, apakah kunci-kunci di `NVRAM>Add` semuanya ada di `Delete`
2. **Pemetaan port USB**: jangan mengandalkan `Kernel>Quirks>XhciPortLimit` (dokumen dengan tegas menyatakan "should be avoided") —
   gunakan peta port USB (misalnya USBToolBox + `UTBMap.kext`) untuk membatasi port maksimal 15
3. **SSDT terkait platform**: bandingkan satu per satu dengan perangkat di mesin ini mengikuti `Docs/AcpiSamples/` resmi, baru putuskan perlu ditambah atau tidak (lihat `acpi-ssdt.md`)
4. **Kartu grafis**:
   - NVIDIA **Turing dan yang lebih baru** ⇒ tambahkan pengaturan yang disyaratkan sesuai `nvidia-driver.md` (boot-args `nvfb/nvaccel`, pemblokiran `IONDRVSupport`, dan sebagainya)
   - AMD/Intel integrated graphics ⇒ tangani sesuai halaman Dortania yang relevan (di luar cakupan skill ini)
   - Ingin memblokir integrated graphics ⇒ `-wegnoigpu` (WhateverGreen)

## 6. Menyambungkannya ke alur aman dalam skill ini

```
Di Windows menghasilkan EFI dasar (dokumen ini)
      ↓ salin ke flash disk, coba boot dulu di flash disk cadangan (jangan timpa EFI yang sedang dipakai)
      ↓ bisa masuk installer / bisa masuk sistem
Pasang ESP → scripts/oc-verify.sh untuk validasi → tahap 2 bandingkan per kunci dengan dokumen resmi
      ↓ setiap perubahan: scripts/oc-edit-safe.sh begin / finish (backup + semantic diff + sha + remount verifikasi)
      ↓ log bukti (scripts/grab-logs.sh): 0 error ACPI, entri selector benar, tidak ada OC WARN/ERROR
Selesai
```

## 7. Penafian dan batas kepercayaan

- RapidEFI **bukan bagian dari proyek resmi OpenCore**, melainkan alat pihak ketiga (pribadi) ⇒ hasil generate **wajib** diverifikasi ulang mengikuti dokumen resmi, jangan melewatkan `ocvalidate` dan perbandingan per kunci hanya karena "alatnya bilang OK"
- Alat itu sendiri menyatakan "hanya untuk pembelajaran, riset, dan pemeliharaan pribadi", serta memperingatkan bahwa membuat/mengubah EFI dapat menyebabkan kegagalan boot, fungsi yang tidak normal, atau risiko data
- Seperti semua alat EFI pihak ketiga: **flash disk dulu, disk internal belakangan; backup dulu, timpa belakangan**
