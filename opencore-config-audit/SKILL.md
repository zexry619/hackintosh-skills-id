---
name: opencore-config-audit
description: 'Tinjau, modifikasi, dan rawat EFI OpenCore (OpenCorePkg) untuk Hackintosh - audit setelan BIOS/UEFI, verifikasi config.plist per kunci terhadap dokumen resmi plus validasi dengan ocvalidate, inspeksi ACPI/SSDT, pengoptimalan kext dan keputusan pembaruan, forensik log boot dan kernel, debug berlapis untuk sistem yang gagal dipasang atau tidak pernah masuk ke desktop, analisis waktu boot, peningkatan versi besar sistem (15 → 26 dengan routing versi), pemblokiran disk, pembuatan EFI dasar dari nol, pergantian model dan tiga kode. Cakupan perangkat keras - GPU NVIDIA, Wi-Fi Intel / MediaTek / Broadcom, Ethernet, audio onboard lewat AppleALC, HiDPI, Intel Turbo dan E-core, kustomisasi memori, perbaikan izin AMFI/TCC, Gatekeeper, AirDrop / Handoff, tema OpenCanopy. Situasi pemicu - macet saat boot EB, macet di ExitBootServices, macet di kode, loop restart, layar hitam, entri boot hilang, selector tidak tampil, suara hanya keluar lewat HDMI, audio onboard tidak berbunyi, AppleHDA tidak bisa dipasang, nilai layout-id yang benar, mikrofon tanpa izin, aplikasi tidak ada di daftar privasi, klik ganda App tidak membuka, AirDrop tidak berfungsi, Handoff tidak menemukan perangkat, Handoff tidak bekerja, Wi-Fi tidak terhubung, driver kartu jaringan, Bluetooth tidak tersedia, Turbo tidak naik, frekuensi CPU dibatasi, perlu menonaktifkan E-core, nama CPU di About This Mac salah, tampilan memori salah, tampilan tidak tajam, ganti model, tiga kode, nomor seri, ROM, iMessage tidak bisa login. Termasuk "alur aman untuk mengubah ESP" (backup → diff semantik → lint → verifikasi sha → mirror/arsip → lepas-pasang, pasang ulang, verifikasi ulang). Berlaku juga ketika pengguna bertanya "bagaimana memakai skill ini / panduan penggunaan / apa saja kemampuannya / apa yang bisa dilakukan" (dalam kasus itu keluarkan USAGE.md dari direktori skill, jangan keluarkan alur internal).'
description_en: Audit, edit and maintain a hackintosh OpenCore (OpenCorePkg) EFI configuration — BIOS/UEFI firmware settings, per-key verification of config.plist against the official docs plus ocvalidate, ACPI/SSDT inspection, kext trimming and update decisions, boot and kernel log forensics, layered debug for installs that fail or never reach the desktop, boot-time analysis, major OS upgrades (15 → 26 with MinKernel/MaxKernel routing), disk masking, generating a first EFI from Windows, SMBIOS model change and serials. Hardware coverage — NVIDIA GPUs, Intel / MediaTek / Broadcom WiFi, Ethernet, onboard audio via AppleALC, HiDPI, Intel Turbo and E-cores, memory injection, AMFI/TCC permission repair, Gatekeeper, AirDrop / Handoff, OpenCanopy themes. Triggers — stuck at EB, stuck at ExitBootServices, boot loop, black screen, lost boot entry, picker not showing, audio only over HDMI, no onboard audio, AppleHDA missing on macOS 26, which layout-id to use, app has no microphone permission, app missing from Privacy list, app won't open on double-click, AirDrop not working, Handoff not working, WiFi not connecting, network driver, Bluetooth unavailable, Turbo stuck low, CPU frequency capped, should I disable E-cores, wrong CPU name in About This Mac, wrong memory display, blurry display, change SMBIOS model, serials, ROM, iMessage sign-in fails. Includes the safe ESP editing flow (backup → semantic diff → lint → sha check → mirror/archive → remount and re-verify). Also applies when the user asks how to use this skill, what it can do, or for usage instructions — in that case output USAGE.md from the skill directory instead of internal workflow details.
version: 0.36.0
agent_created: true
---

# Audit dan Pemeliharaan Konfigurasi OpenCore

## Kegunaan

Ubah "mengubah konfigurasi OpenCore Hackintosh" dari "bercoba berdasarkan pengalaman" menjadi alur "berdasar dokumen, dapat di-rollback, dan dapat diverifikasi ulang":
Pertama gunakan**dokumen resmi + ocvalidate resmi** untuk menilai konfigurasi benar atau tidak, lalu pakai**contoh dari paket rilis resmi** untuk menilai apakah SSDT perlu ditambahkan,
gunakan**log fase boot** (`opencore-*.txt` milik OpenCore sendiri + log kernel macOS) untuk menilai kondisi saat ini, terakhir simpan ke disk mengikuti alur aman.

Berlaku untuk mesin OpenCore mana pun; fakta spesifik mesin ini (ASUS Z690 / Alder Lake / macOS 26) ada di
`references/machine-facts.md` dan bisa langsung dikutip.

> ★★ **Saat pengguna bertanya "bagaimana memakai skill ini / panduan penggunaan / apa saja kemampuannya / apa yang bisa dilakukan"**:
> **Keluarkan langsung `USAGE.md` dari direktori yang sama** (itu adalah ringkasan singkat untuk pengguna),
> **Jangan** mencurahkan alur internal file ini (nomor tahap, aturan besi, daftar skrip) apa adanya ke pengguna.
> Demikian pula, ketika pengguna hanya bertanya "apa yang bisa dilakukan" tanpa tugas konkret, gunakan juga `USAGE.md`.

## Ikhtisar Alur (siklus hidup enam tahap)

**Alur lengkap ada di `references/lifecycle.md`.** Versi satu kalimat:

```
① Di Windows gunakan RapidEFI untuk membuat EFI dasar → ② Pasang macOS dengan EFI tersebut → ③ Setelah masuk ke sistem, ganti ke OpenCore DEBUG
        → ④ Kumpulkan log fase boot (log OC + log kernel) → ⑤ Perbaiki item demi item sesuai dokumen resmi
        → ⑥ Rutinitas: kembali ke RELEASE + matikan log debug (-v tanya ke klien)
```

| Tahap | Aksi kunci | Alat/dokumen |
|---|---|---|
| ① Buat EFI dasar (Windows) | RapidEFI "segarkan info perangkat keras → konfigurasi otomatis → keluarkan EFI" | `references/rapidefi-first-efi.md` |
| ② Pasang macOS | Saat instalasi pakai pengaturan aman installer (`ResizeAppleGpuBars=0`, `ResizeGpuBars=-1`, jangan blokir IONDRVSupport) | `references/lifecycle.md` §2 |
| ③ Ganti ke OpenCore DEBUG | Ganti build wajib **ganti bersama Drivers resmi dengan nama sama** (isi driver di kedua sisi berbeda total) | `scripts/oc-swap-build.sh` |
| ④ Kumpulkan log | Log boot OC + log kernel dari boot ini | `scripts/grab-logs.sh` |
| ⑤ Perbaikan | Cocokkan per kunci dengan dokumen resmi → ubah satu item saja → sertakan daftar "yang sengaja tidak diubah" di laporan | Tahap 1–8 di file ini |
| ⑥ Rutinitas | Kembali ke RELEASE + `Misc>Debug` ke nilai default Sample + `-v` tanya ke klien | `scripts/oc-swap-build.sh release` |

> Tahap ③④ adalah kunci alur ini: **tanpa build DEBUG Anda tidak mendapat log lengkap, dan tanpa log Anda hanya bisa menebak**.

## ★ Aturan Besi (wajib dibaca sebelum mengubah ESP)

1. **Jangan pernah hardcode nomor disk**. Nomor disk bisa bergeser (dalam satu sesi, `disk0`/`disk2` pada dua kali `diskutil list` sudah tertukar). Selalu pakai **UUID volume**, atau cari ESP saat itu juga: `diskutil list | grep "EFI EFI"`.
2. **Backup sebelum mengubah + baca yang live dulu lalu bandingkan diff**. Ada kemungkinan sesi/skrip lain yang berjalan bersamaan juga menulis ke ESP.
3. **Verifikasi sha segera setelah mengubah**, lalu sinkronkan mirror workspace dan arsip versi (lihat `scripts/oc-edit-safe.sh`).
4. **Setelah menulis wajib `sync` → lepas → pasang ulang → verifikasi ulang sha**. FAT punya cache tulis, baru setelah dilepas-pasang ulang isinya benar-benar tersimpan ke disk.
5. **Ubah satu item saja setiap kali** (kecuali pengguna jelas meminta perubahan massal, tetapi laporan tetap harus mencantumkan tiap item satu per satu beserta alasannya).
6. **Memindahkan kext wajib sekaligus `Enabled=false` atau menghapus entri terkait**, jika tidak akan muncul error karena file tidak ditemukan.
7. **Sesi yang terputus oleh pengguna (turn aborted) akan me-rollback perubahan file di workspace** ⇒ setelah terputus, periksa dulu apakah file masih ada (laporan, skrip, backup).
8. **Untuk mencari string multibahasa/berbahasa Mandarin gunakan alat Grep (ripgrep), jangan pakai Bash `grep`**. Bash `grep` di mesin ini pernah memberi **false negative** untuk alternasi `\|` dan teks Mandarin ("tidak ada di dalam file" padahal ada).
9. **Untuk mengubah plist utamakan `plutil`** (mempertahankan XML, perubahan minimal): `plutil -replace '<keypath>' -bool|-integer|-string|-json <v> <file>`; menghapus elemen array dengan `plutil -remove 'Kernel.Add.15' <file>` berfungsi, dan untuk banyak elemen **hapus dari indeks tertinggi ke terendah**.
10. **Setelah setiap perubahan jalankan `ocvalidate` resmi**, dan harus **versi sama** dengan OpenCore di mesin (jika tidak, hasil validasi tidak berlaku).
11. **Partisi ESP tidak pernah diblokir** (boot berjalan di atasnya, dan aplikasi installer driver membutuhkannya untuk membaca/menulis config.plist).
12. **Jangan pakai `ScanPolicy` untuk "filter tampilan"** — itu kebijakan keamanan, memblokir dengan situ membuat OpenCore tidak melihat OS lain (misalnya Windows tidak bisa boot). Untuk mengurangi yang tampil pakai `HideAuxiliary` / `Misc>Entries`; untuk tidak menampilkannya di macOS pakai `/etc/fstab`.
13. **Apakah `-v` diaktifkan, wajib ditanyakan ke klien** — ini adalah **preferensi** (teks penuh di layar vs logo Apple, kecepatan boot), bukan default teknis; kelengkapan log tetap sama di kedua sisi. Sama pula, setiap **preferensi perilaku yang terlihat oleh pengguna** (detik timeout selector, tema, apakah verbose) harus ditanyakan dulu sebelum diubah.
14. **Ganti build OpenCore (RELEASE ↔ DEBUG) wajib ganti bersama Drivers resmi dengan nama sama** — pada versi yang sama isi **semua** Drivers di kedua sisi berbeda (contoh 1.0.8: `OpenRuntime.efi` 24,576 → 36,864); hanya mengganti `OpenCore.efi` menghasilkan bootloader dengan build campuran; driver pihak ketiga (seperti `NullMothLogo.efi`) tetap tidak disentuh.
15. **Saat satu konfigurasi melayani dua versi besar macOS, kext yang build-nya dibedakan per versi wajib diarahkan lewat `MinKernel`/`MaxKernel`** — batas atas ditulis `24.99.99` (dibatasi ke Darwin 24), versi baru ditulis `MinKernel 25.0.0`; **fungsi yang sama tidak boleh hanya menyisakan satu entri, dan juga tidak boleh dua-duanya tanpa batas**. Sebelum meningkatkan versi sistem, telusuri dulu `references/os-upgrade-15-to-26.md`.
16. **Saat meningkatkan versi sistem, model tidak boleh diganti** — semua `SystemProductName` / `BoardProduct` / tiga kode di `PlatformInfo` tetap. **Jika model tidak ada di whitelist versi baru, tambahkan boot-arg untuk melewati** (`-no_compat_check` menyelesaikan "bisa boot" + `revpatch=sbvmm` menyelesaikan "bisa menerima pembaruan", keduanya diperlukan), **bukan mengganti model**. Kalau memang harus mengganti model ⇒ ikuti bagian "ganti model / tiga kode" di **Tahap 8** (`references/smbios-and-serials.md`); itu adalah **operasi terpisah**, jangan dicampur ke dalam operasi peningkatan versi.
17. **Sakelar yang bisa dimatikan di level BIOS, jangan dicadangkan dengan quirk di dalam OpenCore** — prioritas: **pengaturan BIOS > OpenCore quirk**. Tipikal: `AppleXcpmCfgLock` hanya dipakai kalau CFG Lock tidak bisa dimatikan (kata resmi *"should be avoided whenever possible"*); untuk VT-d boleh **dinyalakan + `DisableIoMapper=true`** (resmi menyebut ini pilihan utama karena tidak mengganggu OS lain yang memakai VT-d). ★ Dua hal yang **tidak ditulis** baik oleh pihak resmi maupun Dortania wajib Anda periksa sendiri: **VMD wajib dimatikan** (kalau tidak, disk tidak terlihat saat memasang sistem), **Intel Speed Shift wajib dinyalakan** (kalau tidak `wrmsr(0x770,1)` #GP). Lihat detail di `references/bios-settings.md`.
18. **Jangan mengganti tema seenaknya** — bila pengguna tidak meminta perubahan tampilan, `PickerMode` / `PickerVariant` / `PickerAttributes` / `Resources` **tidak boleh disentuh sama sekali**. Kalau memang perlu diubah, jalankan dulu `scripts/oc-theme-check.sh` (**OpenCanopy tidak akan boot kalau satu saja ikon wajib hilang**), dan simpan satu set ikon **yang benar-benar berfungsi** + jalan keluar (`PickerMode=Builtin`) — **tema yang rusak membuat selector tidak terlihat, worst case sistem tidak bisa dimasuki**.
19. ★★★ **Sebelum mengganti model, SSDT harus disempurnakan terlebih dahulu** (**mesin ini adalah kasus khusus**) — BIOS mesin ini (ASUS Z690) punya SSDT dengan
`OEM Table ID = xh_adls3`; **jika itu tidak dibereskan dulu, mengganti model pasti gagal** (10-12 gagal 6 kali berturut-turut, loop restart).
⇒ Urutannya adalah "**bersihkan dulu layer ACPI/SSDT (terverifikasi lolos pada model lama) → baru ganti SMBIOS → baru buat ulang data CPUFriend**",
bukan "ganti dulu lalu tambahkan belakangan". ★ **Generalisasi**: sebelum mengganti model, audit dulu ACPI (apakah ada SSDT OEM dari vendor, apakah ada `AE_NOT_FOUND`). Lihat `references/smbios-and-serials.md` §2.
20. ★★★ **Mengganti model wajib mengganti tiga kode sekaligus** — **nama model di About This Mac bukan ditentukan oleh SMBIOS, melainkan oleh kode produk pada nomor seri**
(pengukuran di mesin ini: model sudah diubah ke `iMac20,1`, tetapi nomor seri masih memakai kode `MacPro7,1` ⇒ tetap menampilkan `Mac Pro (2019)`;
membersihkan `com.apple.SystemProfiler.plist` juga tidak berguna karena nilainya diturunkan kembali dari kode yang sama). **Ganti model tanpa mengganti kode = nama tampilan selamanya tertahan di model lama.**
⇒ Sebelum mengganti kode, konfirmasi dulu dengan **`macserial -i <serial>`** bahwa kode produknya sesuai dengan model target.
★ **Item turunan kerjakan sekaligus** (kurang satu berarti belum lengkap): **tiga kode · prasyarat ACPI/SSDT · `CPUFriendDataProvider` · jumlah slot injeksi memori · `ROM` (= `en0` saat ini) · nama komputer/hostname/nama SMB**. Daftar lengkap ada di `references/smbios-and-serials.md` §3.1.

21. ★★★ **Sebelum "memperbarui kext / OpenCore", buktikan dulu bahwa pembaruan itu memang perlu — langkah terakhir untuk menilai "apakah ini barang resmi" adalah grep skrip installer milik vendor, bukan mencari tag upstream.**
**Tag upstream tidak ditemukan ≠ asal-usulnya tidak jelas**: `dortania/build-repo` **membangun per commit**, sehingga begitu ada commit baru setelah release terakhir, **nomor patch dinaikkan +1**
(di mesin ini `Lilu 1.7.3` / `VirtualSMC·SMCProcessor·SMCSuperIO 1.3.9` / `WhateverGreen 1.7.2` / `RestrictEvents 1.1.7` / `NVMeFix 1.1.4` / `BlueToolFixup 2.7.3`
**semuanya 404 di upstream**, tetapi semuanya build Dortania, dan dikunci + diverifikasi SHA-256 oleh tabel `kurl()` di installer vendor `nullmoth-setup.sh`)
⇒ **"memperbarui" mereka ke release upstream sama dengan menurunkan versi** (sudah pernah dicoba di mesin ini dan di-rollback). ★ Empat kriteria harus dilihat bersama (tag upstream / metadata build / hash biner / **installer vendor**),
**hanya yang keempat yang bisa menentukan**; ★ **yang dikunci vendor tidak boleh disentuh**; ★ **ide "perbarui semuanya sekaligus" itu sendiri sudah salah**. Lihat `references/kext-and-oc-update.md`.

## Alur Kerja

> ★★ **Jika situasi saat ini adalah "tidak bisa memasang / tidak bisa masuk ke sistem", langsung lompat ke [Tahap 3.5](#tahap-35--tidak-bisa-memasang--tidak-bisa-masuk-ke-sistem--alur-debug-berlapis)** —
> alur berlapis itu justru ditulis untuk situasi seperti ini; **jangan** mulai lagi dari 0 → 1 → 2.

### Tahap 0 · Petakan baseline

> ★★ **Lihat dulu urutan otoritivitas** — `references/ecosystem-sources.md`:
> **dokumen resmi > README penulis driver > kiriman forum**. Setiap kesimpulan dari forum harus diverifikasi kembali ke `Configuration.pdf` atau source code driver.

```bash
# Versi OpenCore (menentukan versi dokumen resmi/ocvalidate yang dipakai)
nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version   # contoh: DBG-108-2026-09-27 = 1.0.8 DEBUG
# Lokasi ESP dan sha config
diskutil list | grep "EFI EFI"
shasum -a 256 /Volumes/EFI/EFI/OC/config.plist
```

Sekaligus pastikan: apakah ESP sudah ter-mount (jika belum, `PlistBuddy` akan mencetak `File Doesn't Exist, Will Create`, yang terlihat seperti file rusak padahal memang belum ter-mount);
apakah mtime `config.plist` sama dengan mirror di workspace.

### Tahap 0.4 · Audit BIOS / UEFI (**lakukan sebelum memasang sistem, lebih awal daripada mengubah config**)

> ★ **Satu langkah lebih awal: sebelum merakit mesin / mengganti komponen, lihat panduan jebakan hardware** — `laobamac/SimpleBuyersGuide` "Panduan Jebakan Hardware Hackintosh"
> (secara eksplisit mencantumkan CPU / GPU / chipset motherboard / SSD / kartu jaringan / kartu Wi-Fi dan lain-lain yang **sebaiknya tidak dibeli**). Indeksnya ada di `laobamac-toolkit.md` §3.

Kalau setelan BIOS salah, semua config sesudahnya sia-sia. **Tiga daftar harus dilihat bersama**:
dokumen resmi OpenCore (9 daftar periksa) + Dortania (Intel / AMD dipisah) + tambahan pengalaman komunitas (**VMD, Speed Shift dan lain-lain yang sama sekali tidak disebut resmi**).

- **Jalankan dulu di sisi Windows** `scripts/bios-audit.ps1` (hanya baca): item yang bisa **dinilai langsung** di Windows langsung diberi kesimpulan
  (tipe firmware / Secure Boot / TPM / VT-x / hyper-threading / XMP / **VMD dan RST** / port serial / jumlah slot memori …),
  yang tidak bisa dinilai ditandai jelas sebagai "perlu diperiksa manual", **jadi Anda tidak mengira sudah diperiksa**
- **Tiga kategori daftar** ada di `references/bios-settings.md` §3: **wajib dimatikan** (Fast Boot / Secure Boot / CSM / CFG Lock /
  **VMD** / RST / SGX / PTT / port serial) · **wajib dinyalakan** (VT-x·SVM / Above 4G / HT / XD / XHCI Hand-off /
  OS Type=Windows UEFI / AHCI / DVMT≥64MB / **Speed Shift**) · **tergantung situasi** (ReBAR / XMP / iGPU / TB / ErP)
- **★ Kriteria**: **yang bisa diselesaikan di level BIOS, selesaikan di level BIOS**, jangan pakai quirk OpenCore sebagai cadangan
- **Jika suatu item tidak ditemukan di BIOS** ⇒ cek **tabel padanan nama vendor** di §8 (ASUS/MSI/Gigabyte/ASRock berbeda penamaan),
  atau pakai jalur opsi tersembunyi di §5 (UEFITool + IFR-Extractor, metode yang diberikan resmi)

### Tahap 0.5 · Belum punya EFI? Buat dulu sebuah EFI dasar di Windows (opsional)

Lihat `references/rapidefi-first-efi.md`: pakai **RapidEFI-Tool** (`JeoJay127/RapidEFI-Tool`, gratis dan offline, logika konfigurasi mengikuti
dokumen resmi OpenCore + Dortania) di Windows untuk "segarkan info perangkat keras → konfigurasi EFI otomatis → keluarkan EFI",
sehingga Anda mendapat **titik awal yang bisa dipakai**.

- ★ Batas yang diakui resmi sendiri: **"hasil yang dihasilkan cocok sebagai konfigurasi dasar, tidak sama dengan konfigurasi final tanpa debugging"**,
  **"ujilah boot dulu dengan U disk cadangan, jangan langsung menimpa EFI yang sedang stabil dipakai"**
- ★ Setelah pembuatan **wajib** kembali ke Tahap 1–2 skill ini untuk mencocokkan per kunci dengan dokumen resmi; lengkapi juga pemetaan port USB, SSDT platform, setelan GPU, dan tiga kode
- Itu adalah alat pihak ketiga ⇒ **jangan melewati `ocvalidate` hanya karena "katanya alat sudah OK"**

### Tahap 1 · Ambil dokumen resmi + validator, dan bangun "pustaka kunci"

Jalankan `scripts/fetch-opencore-docs.sh`: unduh paket RELEASE resmi **dengan versi sama** seperti mesin,
dapatkan `Utilities/ocvalidate/ocvalidate`, `Docs/Configuration.tex`, `Docs/Sample.plist`, `Docs/AcpiSamples/`,
lalu ekstrak `Type / Failsafe / Description` dari **seluruh kunci konfigurasi** di `Configuration.tex` untuk membangun pustaka kunci JSON.

Detail dan cara membacanya ada di `references/official-docs-method.md`.

### Tahap 2 · Cocokkan per kunci

1. `ocvalidate <config>` — masalah schema/tipe/wajib/urutan (**error harus bersih total**).
2. Ekspor seluruh kunci dan nilai dari config live; lakukan **diff semantik** dengan `Sample.plist`, hasilnya daftar "sakelar yang berbeda dari Failsafe resmi".
3. Untuk tiap item yang menyimpang, cek deskripsi resmi di pustaka kunci, lalu kelompokkan jadi tiga:
   - **simpangan yang benar dan berdasar** (pertahankan, jangan "kembalikan ke default")
   - **bertentangan dengan arahan eksplisit dokumentasi** (disarankan diubah)
   - **sisa yang redundant/tidak berlaku lagi** (opsional untuk dibersihkan)
4. Perhatikan **hubungan berpasangan** dalam dokumentasi, jangan memisahkannya (lihat tabel pasangan di `references/official-docs-method.md`).

### Tahap 3 · Forensik log (lihat log dulu, baru menyimpulkan)

Jalankan `scripts/grab-logs.sh`: ambil log boot OpenCore + log kernel dari boot ini (perlu elevasi).
Arti sakelar dan daftar kriteria (dukungan MAT, slide, ambang driver APFS, daftar tabel ACPI, dll.) ada di `references/logs-and-debug.md`.

> Rumus: **banyak baris di segmen OC = bit `0x02` dari `Misc>Debug>Target`; banyak baris di segmen macOS = `-v` di boot-args**. Keduanya berdiri sendiri.

**"Boot sangat lambat" harus dianalisis lewat linimasa tersendiri** ⇒ `references/boot-timeline.md`:
pecah boot menjadi **segmen OC / segmen driver kernel / segmen user space** lalu ukur terpisah (`scripts/boot-timeline.sh` untuk ikhtisar,
`scripts/find-boot-gap.sh` untuk memeriksa jendela jeda secara rinci), tentukan dulu "macet di segmen mana" baru pilih log mana yang dicek.
★ Di mesin ini penyaringan waktu pada `log show` gagal total (`--start/--end` melaporkan koreksi jam, `--last` mengembalikan seluruh basis log) ⇒ selalu pakai **filter streaming**.

### Tahap 3.5 · Tidak bisa memasang / tidak bisa masuk ke sistem — **alur debug berlapis**

> ★★ **Saat tidak bisa boot, lihat ini dulu** ⇒ `references/boot-failure-debug.md`.
> **Jangan buru-buru mengubah konfigurasi** — begitu diubah, Anda tidak bisa mengaudit ulang (sudah pernah kejadian di mesin ini).

- **Langkah pertama selalu berlapis**: ① firmware/OpenCore itu sendiri (selector pun tidak muncul) · ② fase boot OC · ③ kernel awal (< 1–2 s) · ④ kernel tengah-late/user space
- ★★ **Bedakan dulu "hang" atau "loop restart"** — **loop restart = timeout watchdog boot, "tunggu lebih lama" tidak berguna**;
  **hanya hang yang layak ditunggu** (sudah pernah ada contoh sebaliknya di mesin ini: sebenarnya sedang me-rollback snapshot volume sistem 11 GB, lambat bukan macet)
- **Empat pintasan cepat**:
  **① Layar hitam tanpa logo** ⇒ tunggu cukup 2 menit (`ResizeGpuBars=13` memang hitam ~21 s); selector tidak muncul ⇒ matikan logo boot pihak ketiga;
  setelah mengganti tema tidak mau boot ⇒ satu ikon wajib hilang (`oc-theme-check.sh`)
  **③ `can't perform kext scan: no kext summary`** ⇒ **kerusakan lapisan cache paling awal (< 1 s), sama sekali tidak ada hubungannya dengan GPU/kext tertentu**, jangan mengarah ke GPU;
  `X86PlatformShim` panic ⇒ **periksa dulu `Speed Shift` di BIOS**
  **④ Macet sangat jauh di akhir** ⇒ kemungkinan besar **layanan user space tidak naik** (contoh di mesin ini: `AppleUSBHostHIDDevice` menunggu DriverKit dext ⇒ tidak ada input keyboard/mouse)
- **Bukti pilihan utama untuk panic** = `/Library/Logs/DiagnosticReports/` (dengan `keepsyms=1` nama frame langsung terlihat)
- ★★ **Urutan penyelamatan**: ① kembali ke konfigurasi yang terakhir bisa dipakai → ② **EFI dari U disk** (`LauncherOption=Disabled`) → ③ boot Recovery, mount EFI internal, ganti kembali →
  ④ pencarian biner (**ubah satu item saja**) → ⑤ ubah ESP langsung dari sistem lain; ★ **jangan mengubah banyak item sekaligus saat sedang tidak bisa masuk**
- ★ **Saat tidak bisa masuk ke sistem, baca log OC**: boot lewat U disk / Recovery → mount EFI internal → baca `opencore-*.txt`

### Tahap 4 · Ubah config dengan aman

Gunakan `scripts/oc-edit-safe.sh` sebagai pembungkus setiap perubahan: backup → ubah → `plutil -lint` → `ocvalidate` → hitung sha →
sinkronkan mirror workspace + arsip versi → `sync`/lepas/pasang/verifikasi ulang. Setelah selesai catat di laporan tiap perubahan "apa yang diubah, dengan dasar apa".

### Tahap 5 · Inspeksi ACPI / SSDT

Pakai `Docs/AcpiSamples/` resmi yang diunduh pada Tahap 1 untuk **mencocokkan tiap item** dengan perangkat nyata di mesin ini, lalu putuskan "SSDT mana yang masih perlu ditambahkan".
Tabel pencocokan, perintah untuk mengecek keberadaan perangkat, dan konvensi penamaan SSDT ada di `references/acpi-ssdt.md`.

> ★★★ **Pustaka contoh hot patch ACPI utama: `5T33Z0/OC-Little-Translated`** (★745, **masih diperbarui**) —
> berawal dari terjemahan Inggris `daliansky/OC-little`, **sudah jauh melampaui karya aslinya** (bab 7–20 baru + lampiran lengkap A–Z);
> **hanya memakai hot patch ACPI, tidak melakukan DSDT patch** (bersumber dari kriteria yang sama dengan skill ini).
> Cakupan: dasar ACPI/**hapus tabel/ubah nama** · tambah/nonaktifkan perangkat · daya CPU · GPU (termasuk **GPU-BAR**) · USB (termasuk **port mapping dengan ACPI**) ·
> sleep/wake · laptop · CMOS · **whitelist MMIO / AppleVTD** · Thunderbolt · **penjelasan boot-args / Quirks per item** · urutan kext ·
> **OCLP on Wintel** · multi-sistem · mesin virtual · **membuat ALC Layout-ID sendiri** · pemecahan masalah (SysReport / **Preboot** / spindump).
> ⇒ **Cari indeks bab mana yang Anda butuhkan** (termasuk **titik landed untuk Z690 milik mesin ini**) di `references/acpi-ssdt.md` §0.
> ★ Pengingat jujur: terjemahan Inggrisnya adalah AI + proofreading manusia, **penerjemahnya tidak memahami Mandarin** ⇒ kesimpulan penting tetap harus diverifikasi ke dokumen resmi.

### Tahap 6 · Pemblokiran disk (sisi macOS)

Untuk "hanya melihat Macintosh HD di macOS", pakai `scripts/mask-other-disks.sh` untuk menulis `/etc/fstab` + `noauto`
(**berdasarkan UUID volume**, dan mengecualikan EFI secara eksplisit). Untuk "kurang yang tampil di selector", pakai `Misc>Boot>HideAuxiliary` / `Misc>Entries`,
**jangan pakai `ScanPolicy`**. Lihat detail di `references/disks-and-kexts.md`.

### Tahap 6.5 · Entri boot firmware (`Boot####`) — hilang / perlu ditambah / perlu ganti disk boot

> Gejala: "entri OpenCore hilang dari BIOS, hanya Windows tersisa" "boot dari U disk sekali, entri disk keras langsung hilang" "ingin ganti boot dari U disk ke boot dari disk keras"
> ⇒ Lihat `references/boot-entries.md`. **Tiga poin penting**:

- **Akar masalah**: saat `Misc>Boot>LauncherOption=Full`, OpenCore setiap bootesan melhora "entri miliknya sendiri",
  padahal itu **mengenali entri hanya dari sufiks path .efi, mengabaikan perangkat** ⇒ boot sekali dari U disk akan mengarahkan ulang entri disk keras ke sana ⇒ setelah U disk dicabut, firmware membersihkannya
- **Kombinasi final**: **supaya entri ada dan berada di atas ⇒ disk target `Full` (dibuat sendiri + mandiri pulih) / salinan lain `Disabled` (tidak menulis ulang NVRAM)**;
  ★ **dua-duanya `Disabled` itu salah** — dengan begitu tidak ada yang membuat entri boot
- **Menambahkan kembali (metode resmi, diurut dari keandalan)**:
  **B** selector → Tools → di OpenShell jalankan `bcfg boot add 0 FSx:\EFI\OC\OpenCore.efi "OpenCore"` (★ **rekomendasi resmi**, murni U disk, tanpa Windows) ·
  **C** `bcfg` melaporkan "tidak bisa ditulis" ⇒ jalankan dulu `\EFI\OC\Tools\OpenControl.efi disable` (dan beri alat itu `FullNvramAccess=true`) lalu ulangi, **setelah itu wajib restart** ·
  **A** `LauncherOption=Full` biarkan OpenCore membuatnya sendiri (★ **tidak menyelesaikan masalah "telur ayam"**) ·
  **D** tulis dari dalam sistem (macOS `nvram` / Linux `efibootmgr` / Windows EasyUEFI) — ★★ **syarat: `RequestBootVarRouting=false` pada boot tersebut**, kalau tidak "tulis sukses, baca balik konsisten" semuanya false positive
- **Kriteria**: setelah restart **di menu boot BIOS** ada "OpenCore" dan berada di urutan pertama — **jangan memakai pembacaan balik `nvram` sebagai bukti berhasil**
- **Alat**: `scripts/oc-nvram-bootentry.sh` (**pendamping metode D**: `dump` / `backup` / `restore` / `add` / `del`; operasi tulis perlu elevasi dan butuh `RequestBootVarRouting=false`)

### Tahap 7 · Pengoptimalan kext

Cocokkan `Kernel>Add` dengan `EFI/OC/Kexts/`: cari **item yang dinonaktifkan** dan **file yatim**, lalu nilai satu per satu apakah benar-benar tidak dipakai
(driver untuk hardware yang sudah diganti, patch yang fungsinya sudah tertutup sakelar lain). Sebelum menghapus, backup dulu aslinya ke workspace, baru hapus file + hapus entri.
Kriteria dan daftar "tidak boleh dihapus" ada di `references/disks-and-kexts.md`.

### Tahap 7.5 · Pembaruan kext dan OpenCore (**buktikan dulu perlu diperbarui, baru eksekusi**)

> Pengembangan dari aturan besi 21 ⇒ `references/kext-and-oc-update.md`. **Di Hackintosh, "memperbarui" bukan hal baik.**

- ★★★ **Periksa dulu installer / dokumentasi / `mirror.json` milik vendor sendiri** (misalnya tabel `kurl()` di `nullmoth-setup.sh`) —
  **mereka itulah yang menentukan "sumber resmi"**; yang dikunci vendor tidak boleh disentuh
- **Nilai "apakah ini barang resmi" dengan empat hal sekaligus**: tag upstream · metadata build (`DTXcode`/`DTSDKName`) · sha256 biner · **installer vendor**.
  ★ **`DTXcode` yang lama ≠ mencurigakan**, **nomor versi yang lebih tinggi dari resmi ≠ mencurigakan**
- **Nilai DEBUG / RELEASE memakai perbandingan ukuran** (dibandingkan dengan REL / DBG resmi, DEBUG biasanya 1.2–1.9×), lebih andal daripada mencari string
- **Hanya dalam kasus inilah pembaruan layak dilakukan**: upstream benar-benar rilis versi baru **dan vendor tidak mengunci** · peningkatan versi sistem butuh routing `MinKernel`/`MaxKernel` ·
  ada bug fix yang persis cocok dengan gejala Anda. ★ "Nomor versi terlihat lama" dan "kebiasaan memperbarui semuanya" **bukan alasan**
- **Inti OpenCore**: `nvram 4D1FDA02-…:opencore-version` (`DBG-`/`REL-`) → ★★ **ganti build wajib ganti bersama Drivers resmi dengan nama sama** (aturan besi 14)
  → pakai `scripts/oc-swap-build.sh`; saat menaikkan versi, jalankan dulu `scripts/fetch-opencore-docs.sh` untuk mengambil paket resmi versi sama (`ocvalidate` harus versi sama)
- **Alur**: backup (EFI + direktori kext + **daftar versi**) → `scripts/kext-inventory.sh` catat kondisi sekarang → nilai perlu atau tidak →
  ★ **satu jenis saja per kali** → ubah → tiga pemeriksaan mandiri (`ocvalidate` / **referensi config 0 hilang** / **hanya kext yang diubah yang berubah**) →
  `sync` + lepas-pasang + verifikasi ulang → setelah restart bandingkan dengan `kmutil showloaded` → **tulis jalur rollback dengan jelas**
- ★ **Jebakan**: di sandbox `PATH` bisa rusak (`stat`/`strings`/`grep` mendadak command not found) ⇒ di skrip tambahkan `export PATH=/usr/bin:/bin:/usr/sbin:/sbin`;
  ★ `rsync -a --delete` membuat target **identik sepenuhnya** dengan sumber (jangan dipakai untuk skenario "hanya boleh menambah beberapa file")

### Tahap 8 · Driver dan fitur perangkat keras

> Bagian ini **hanya untuk routing**: gejala → file mana yang dibaca. Perintah, nilai parameter, dan analisis akar masalah semuanya ada di references, jangan diulang di sini.
> ★ Yang ditandai "★★★" adalah **syarat urutan** (kalau tidak dikerjakan, semua yang berikutnya sia-sia).

- **GPU NVIDIA** ⇒ `references/nvidia-driver.md`: cakupan kartu yang berlaku (Turing+), dua jalur paket resmi / app 1401,
  ★"kext dipasang di `/Library/Extensions` dimuat dari AuxKC ⇒ **jangan** lagi inject dari `EFI/OC/Kexts`",
  tabel setelan OC wajib, jalur pemulihan, disiplin mengunggah log
- **AMFI ↔ TCC (App tidak mendapat izin mikrofon / kamera / perekaman layar)** ⇒ `references/amfi-and-tcc.md`:
  ★★ Kriteria = ada laporan tanpa izin + tidak muncul dialog + **entri App ini memang tidak ada di daftar privasi** (baris ketiga itulah kriterianya);
  akar masalah = boot-args `amfi=0x80`; ★ di mesin lain pilihan pertama `AMFIPass.kext`, **di mesin ini tidak bisa** (NullMoth mensyaratkan AMFI dimatikan)
  ⇒ hanya bisa memilih salah satu, dan harus menginject entri TCC; ★★ solusi `GeekAudio/tcc-helper`;
  **paling mudah salah: yang perlu diotorisasi adalah helper / subkomponen yang benar-benar mengajukan izin, bukan App utama**;
  ★ ini beda dengan Gatekeeper (klik ganda tidak membuka = Gatekeeper, lihat lampiran dokumen tersebut)
- **Wi-Fi Intel** ⇒ `references/intel-wifi.md`: dua bentuk `AirportItlwm` vs `itlwm`,
  ★"Sequoia dan Tahoe punya dua set ABI dan hasil build yang berbeda ⇒ konfigurasi yang dipakai dua sistem wajib dipisahkan dengan `MinKernel`/`MaxKernel`",
  batas kemampuan macOS 26 (**tanpa AWDL ⇒ tanpa AirDrop**), Bluetooth Intel perlu dipasang tiga paket terpisah, daftar pembersihan setelah ganti kartu
- **Wi-Fi MediaTek (MT7921 / MT7922 / RZ608 / RZ717)** ⇒ `references/mediatek-wifi.md`:
  ★★★ **macOS 26 sudah menyertakan driver MediaTek bawaan Apple** (`AppleSunriseWLAN/Bluetooth.dext`) ⇒ **pilihan pertama: coba "tidak memasang apa pun"**;
  ★★ **Apa yang "bawaan" di 26.7.1 berbeda per chip** (jangan percaya "upgrade otomatis membawa semua firmware"): Bluetooth MT7922/7923 sudah bawaan ·
  Wi-Fi MT7932/RZ717 sudah bawaan · **Wi-Fi MT7922/RZ616 masih kurang**;
  ★★ jalur native memang perlu kerja manual ⇒ pakai `GeekAudio/mediatek-sunrise-hackintosh` (memuat `AppleSunrise.kext` — **HAL di kernel, wajib ada**);
  ★★★ **Tiga batasan keras**: interface gaya Ethernet tidak punya menu native · **❌ AirDrop / Handoff / Continuity (secara desain mustahil)** · ❌ 802.11ax
  ⇒ **kalau butuh menu native / AirDrop / Wi-Fi 6, ganti kartu, jangan dipaksa**;
  ★★ Jebakan yang paling sering terjadi = kartu disembunyikan oleh `SSDT-Disable_Network_*.aml` (`vendor-id=0xFFFF` ⇒ driver tidak akan pernah cocok)
- **Kartu Broadcom (BCM943602CDP / BCM43602)** ⇒ `references/broadcom-wifi.md`:
  ★★ **Wajib memakai jalur terpisah per sistem** — Sequoia memakai `IO80211FamilyLegacy` (`MaxKernel 24.99.99`),
  Tahoe memakai `AirPortBrcmNIC-Tahoe.kext` tersendiri (`MinKernel 25.0.0`) ⇒ **naik ke 26 tanpa mengganti = Wi-Fi langsung hilang**;
  ★ **Sebelum melakukan OCLP root patch wajib jalankan skrip proteksi** (kalau tidak, kext NVIDIA dengan mtime=epoch akan dipindahkan);
  ★ Untuk menilai hidup atau mati **lihat `ifconfig en1`, jangan hanya `system_profiler`**;
  ★★ Setelah patch selesai pastikan "nirkabel = `en0`" ⇒ `references/network-en0-order.md`
- **AirDrop / Handoff / Continuity (AirDrop tidak berfungsi)** ⇒ `references/airdrop-handoff.md`:
  ★★★ **Semuanya hanya bergantung pada satu hal: apakah nirkabel berjalan di atas stack native `IO80211Family` Broadcom sehingga menghasilkan `awdl0`**;
  `itlwm.kext` ⇒ tidak pernah ada `awdl0` ⇒ pasti tidak bisa dipakai (**ini batasan di tingkat desain driver, konfigurasi tidak bisa menolong**);
  ★★★ **`ROM` / kepemilikan `en0` / model / nomor seri / `SystemUUID` tidak ada hubungannya dengan AirDrop** — itu persyaratan iServices (iMessage)
- **Ethernet (I225/I226 · I210/I211/I350 · RTL8125/8126)** ⇒ `references/ethernet-drivers.md`:
  ★★ `I225-V` onboard di mesin ini tidak dikenali secara native (sekarang pakai `AppleIGC`) — alternatif `SimpleVGBE` / `SimpleEthernet` / `SimpleRTK5`;
  ★ **satu paket saja per penggantian** (beberapa paket akan saling berebut perangkat); ★★ setelah ganti wajib periksa ulang kepemilikan `en0`
- **Ganti model / tiga kode** ⇒ `references/smbios-and-serials.md`:
  ★★★ **Aturan besi urutan: pertama perfecting SSDT/ACPI (terverifikasi lolos pada [model lama]) → baru ganti SMBIOS → baru buat ulang CPUFriend**
  — tanpa menangani SSDT OEM `xh_adls3` milik ASUS, mengganti model **pasti menyebabkan loop restart** (bukan hang ⇒ "tunggu lebih lama" tidak berguna);
  ★★★ **Wajib mengganti tiga kode sekaligus** (kalau tidak "About This Mac" menampilkan model lama) + **wajib membuat ulang `CPUFriendDataProvider`**
  (`MacPro7,1` memaksa `hwp=on`) + **injeksi memori ikut diubah** (jumlah slot berubah menurut model);
  ★ Nama komputer / hostname / nama SMB adalah pengaturan terpisah dan tidak berubah otomatis;
  ★ Penyelamatan: backup seluruh EFI + **siapkan satu U disk EFI yang berfungsi**; ★★ tiga kode + ROM **jangan ditulis di tempat mana pun yang publik**
- **Kustomisasi memori (`PlatformInfo > Memory`)** ⇒ `references/memory-injection.md`:
  ★★ Pastikan model dulu (**jumlah slot berubah menurut model**: `MacPro7,1`=12 / `iMac20,1`=4);
  ★★ **Dua lapisan jangan dicampur** — "System Information → Memory" berlaku untuk semua model (field Type 17 standar);
  gambar 12 slot di "About This Mac" adalah **khusus MacPro**, penempatannya ditentukan oleh urutan array `Devices`
  ⇒ validasi dengan `scripts/mem-check.sh`
- **CPU tertahan di frekuensi rendah (lag / frame drop) ⇒ Intel Turbo** ⇒ `references/intel-turbo.md`:
  ★★★ **Metode terbaik (sudah final): inject "profile milik mesin ini sendiri, hanya hapus `hwp`"** — empat kriteria ada di dokumen;
  ★★ **`hwp` tidak ada di plist** (namanya ada di tabel variabel di dalam biner vektor), menonaktifkannya = **menghapus item itu**, untuk menilai efeknya harus membandingkan vektor byte per byte;
  ★★★ **Kesimpulan negatif: inject profile model lain apa pun akan menabrak Turbo** (terukur 1,97 / 2,3 GHz) ⇒ **jangan пыта menaikkan batas dengan ganti profile**;
  ★★ **Setelah diubah wajib restart** (`kern.boottime` lebih awal dari waktu perubahan = belum restart ⇒ yang berjalan masih profile lama), ini alasan nomor satu "sudah diperbaiki tapi belum ada hasil";
  ★ Syarat mutlak: `Intel Speed Shift Technology` di BIOS harus Enabled; validasi dengan CPU-S + `scripts/cpu-freq-probe.sh`
- **E-core (core efisien) nyala / mati ⇒ arsitektur hibrida Intel** ⇒ `references/e-cores.md`:
  ★ **Mematikan paling stabil, hampir tanpa biaya** (scheduler macOS untuk E core memang area rawan);
  menyalakan = BIOS `All` + `ProvideCurrentCpuInfo=true` + `CpuTopologyRebuild`;
  ★ **Kriteria `hw.nperflevels`** (1 = E core tidak diekspos / 2 = keduanya dikenali);
  ★★ `CPUID.1FH` melaporkan 20 logical processor sedangkan macOS hanya melaporkan 8 core 16 thread itu **normal**;
  ★★ **Sintaks boot-arg berbeda per versi** (v2.x `ctrsmt=off`; `-ctrsmt` versi v1.x tidak berlaku di v2.x); pemeriksaan mandiri `scripts/e-cores-check.sh`
- **Nama CPU di "About This Mac" salah ⇒ ganti nama CPU** ⇒ `references/cpu-name.md`:
  ★ **Tentukan dulu: murni soal tampilan**, kalau tidak penting jangan diubah; cara = trio RestrictEvents (`revpatch=cpuname` + `revcpu=1` + `revcpuname`);
  ★★ **Jebakan terbesar: prioritas variabel NVRAM `rev*` lebih rendah dari boot-args** ⇒ menulis `cpuname` hanya di NVRAM **tidak berefek**;
  ★ `revcpuname` mengandung spasi sehingga hanya bisa ditaruh di NVRAM; `ProcessorType` wajib disesuaikan dengan jumlah core (8 core ke atas = `0x0F01`);
  pemeriksaan mandiri `scripts/cpu-name-check.sh`
- **Tampilan tidak tajam ⇒ HiDPI** ⇒ `references/hidpi.md`: pakai `xzhih/one-key-hidpi` (**tidak menyentuh volume sistem tersegel**),
  dua mode **coba dulu hanya inject `scale-resolutions`**; ★ jangan campur dengan HiDPI **fase boot** (`UEFI>Output>UIScale`)
- **Audio onboard (AppleALC)** ⇒ `references/applealc-custom.md`:
  ★★★ **Prasyarat macOS 26 (kalau langkah ini tidak dilakukan, semua sesudahnya sia-sia)**: Apple menghapus `AppleHDA.kext` di DP2
  ⇒ kriterianya "**hanya HDMI yang berbunyi, onboard tidak**"; ★★ **Di KDK 26 memang tidak ada AppleHDA sama sekali** ⇒ langsung kembali ke `KDK 15.8.1 build 24H32`;
  ★★ **Konsekuensi: begitu sistem di-upgrade / di-install ulang, semuanya hilang**;
  ★★ **Sebelum kustomisasi tanyakan dulu kepada pengguna apakah bisa menyediakan pengambilan data dari sisi Windows** (bisa disediakan, langsung masuk alur; kalau tidak, baru jelaskan batasan keras dan berikan
  dua jalur pengambilan data HDAU / `HDAudDev.dll`);
  ★★ **Tiga akar masalah terukur pada AppleHDA** (PathMap dengan beberapa path dalam satu grup hanya menyisakan yang terakhir / pin Mic tipe jack tidak bisa membuat perangkat /
  deteksi jack mungkin mati seluruhnya); ★ **jangan verifikasi dengan telinga** (baca `0xF07`/`0xF06` saat pemutaran)
- **Tampilan layar boot (OpenCanopy)** ⇒ `references/theme-opencanopy.md`:
  ★ **Tidak akan boot kalau satu saja ikon wajib hilang** — jalankan dulu `scripts/oc-theme-check.sh` baru bicara soal mempercantik tampilan;
  ★★ **`OCUI: … Not Found` sebagian besar normal** (set ikon resmi tidak menyediakan batch ikon opsional itu, jangan buru-buru "melengkapinya");
  ★ **Jangan mengganti tema seenaknya** (kalau pengguna tidak meminta perubahan tampilan, jangan disentuh); **kalau rusak selector tidak terlihat** (sisakan `PickerMode=Builtin` sebagai jalan keluar)

> Memasang driver pihak ketiga pasti menyentuh batas keamanan (`SecureBootModel=Disabled`, melonggarkan SIP, parameter AMFI) —
> **tuliskan dengan jelas di laporan**, dan berikan "bagaimana memulihkannya kalau tidak dipasang".

### Tahap 9 · Peningkatan versi besar sistem (mis. macOS 15 → 26) ⇒ `references/os-upgrade-15-to-26.md`

**Peningkatan versi bukan "klik sekali Software Update"**, ada tiga hal yang pasti terjadi: **Wi-Fi menghilang, OCLP root patch hilang semua, kext pihak ketiga bisa dipindahkan**.

- ★★ **Aksi inti = memberi routing `MinKernel`/`MaxKernel` pada kext yang build-nya dibedakan per versi**:
  entri versi lama batas atasnya dipatok `24.99.99`, entri versi baru ditulis `MinKernel 25.0.0`
  (Broadcom `AirPortBrcmNIC-Tahoe.kext`, Intel `AirportItlwm-Tahoe` dibedakan seperti itu; `BundlePath` untuk plugin harus ditulis path lengkap)
- ★★ **Batasan keras: saat peningkatan versi model tidak boleh diganti** (semua `SystemProductName` / `BoardProduct` / tiga kode di `PlatformInfo` tetap).
  **Kalau model tidak ada di whitelist versi baru ⇒ tambahkan boot-arg untuk melewati**: `-no_compat_check` (bisa boot) + `revpatch=sbvmm` (bisa menerima pembaruan), **keduanya diperlukan**.
  **Jangan pernah** memakai `nullmoth-setup.sh --update prepare --pkg` dari upstream (itu otomatis mengubah model + board-id, bentrok langsung dengan batasan ini)
- **Sebelum peningkatan**: matikan FileVault → jalankan skrip proteksi prasyarat OCLP (agar kext NVIDIA bertimestamp 1970 tidak dipindahkan) → backup seluruh EFI
- **Setelah peningkatan**: lengkapi entri kext → patch ulang OCLP root patch → restart dan validasi (`uname -r` / `kmutil showloaded` / **`ifconfig en1`** / `awdl0`)
- **Whitelist model** (di Tahoe Intel hanya tersisa `iMac20,1` `iMac20,2` `MacPro7,1` `MacBookPro16,x`, **`iMacPro1,1` dikeluarkan**) —
  whitelist **hanya dipakai untuk menilai "perlu dilewati atau tidak"**, bukan dasar untuk "ganti model atau tidak"
- **Jebakan lingkungan baru di macOS 26**: EFI wajib di-mount dengan elevasi (`/Volumes` menjadi `root:wheel`), FAT memakai implementasi FSKit, menghapus file di EFI meninggalkan `.Trashes` sehingga perlu `diskutil repairVolume`

## Ringkasan Jebakan Umum

Daftar lengkap ada di `references/pitfalls.md`, beberapa yang paling mudah terkena:

| Jebakan | Cara yang benar |
|---|---|
| Memblokir entri boot dengan `ScanPolicy` → Windows tidak mau boot | Jaga `ScanPolicy=0`; kurangi tampilan dengan `HideAuxiliary`/`Misc>Entries` |
| Mengenali disk lewat `disk0/disk1` | Pakai UUID volume; cari ESP saat itu juga |
| Setelah menulis ESP tidak dilepas-pasang ulang | `sync` → unmount → mount → verifikasi ulang sha |
| Menulis `Delete.0.<GUID>` seolah `NVRAM>Delete` itu array | Itu **dict (GUID→array)**, path kuncinya `NVRAM.Delete.<GUID>` |
| Kunci hanya ditulis di `NVRAM>Add` | Aturan dokumen: **kunci di Add harus sekaligus ada di `Delete`** supaya ditulis |
| Mencari teks Mandarin dengan Bash `grep` | Pakai alat Grep (ripgrep), Bash grep pernah memberi false negative |
| `log show --start/--end` untuk log boot | Koreksi jam saat boot membuatnya mengembalikan **seluruh basis log** ⇒ ganti **filter streaming** (`boot-timeline.md`) |
| Saat memasang sistem "tidak menemukan drive apa pun" | Sembilan dari sepuluh kasus karena **VMD / Intel RST di BIOS belum dimatikan** (macOS tidak punya driver VMD) ⇒ `bios-settings.md` |
| Pakai quirk sebagai cadangan saat CFG Lock tak bisa dimatikan | Resmi menyatakan `AppleXcpmCfgLock` *"should be avoided whenever possible"* ⇒ cari opsi tersembunyi dengan UEFITool dulu |
| Mengira daftar Dortania sudah segalanya | Itu **tidak menyebut VMD maupun Speed Shift** ⇒ tiga daftar (resmi / Dortania / komunitas) harus dilihat bersama |
| Mengganti nama file SSDT lalu mengira identitas tabel berubah | Identitas tabel **ditentukan oleh isi hasil parsing, bukan nama file**; mengganti nama aman asal `ACPI>Add>Path` ikut diubah |
| Mengira `ocvalidate` lolos berarti semua beres | Itu hanya memeriksa schema; kecocokan nilai dengan dokumen harus dibandingkan manual per kunci |
| **Setelah boot sekali dari U disk, entri OpenCore pada disk keras hilang dari BIOS, hanya Windows tersisa** | `Misc>Boot>LauncherOption=Full` mengenali entrinya lewat "akhiran path file" (**tidak melihat disk**) ⇒ boot dari disk lain maka diarahkan ulang ke sana; setelah U disk dicabut firmware membersihkannya ⇒ **ubah kedua ESP ke `Disabled`** + sisakan `\EFI\BOOT\BOOTx64.efi` sebagai cadangan (`boot-entries.md`) |
| macOS hanya melihat 8 core 16 thread (`hw.nperflevels=1`), padahal CPU 12 core 20 thread | **Bukan core hilang, dan bukan driver gagal dimuat** ⇒ E core tidak diberi ke macOS (BIOS-nya dimatikan, atau `ProvideCurrentCpuInfo=false`) ⇒ lihat `e-cores.md`; **jika mematikan E core memang pilihan sadar, jangan "memperbaiki"** |
| boot-arg `-ctrsmt` yang disalin tidak berefek | `-ctrsmt` versi v1.x **tidak berlaku di v2.x** ⇒ tulis ulang menjadi **`ctrsmt=full`** (periksa `CFBundleVersion` dulu) ⇒ `e-cores.md` §4.2 |
| Boot gagal sesekali setelah E core diaktifkan (terutama dengan `-v`) | Masalah resmi `CpuTopologyRebuild`: **konflik dengan boot verbose** ⇒ saat menelusuri, matikan E core dulu atau hapus sementara `-v` (`e-cores.md` §4.3) |
| Ingin menaikkan Turbo dengan "ganti ke profile model dengan batas 5000" | **Terukur justru anjlok ke ~1,97 GHz** ⇒ semua profile dengan batas 5000 punya **3–5 tahap**, multi tahap pasti gagal ⇒ **hanya inject profile milik mesin sendiri (hapus `hwp`)** (`intel-turbo.md` §0.1 / §5) |
| Setelah mengubah CPUFriendDataProvider tidak ada efek / malah lebih lambat | Cek dulu **`kern.boottime`** apakah lebih awal dari waktu perubahan ⇒ **belum restart** (memori masih memakai profile lama) ⇒ `intel-turbo.md` §7 |
| Menambahkan `revcpuname` tapi nama CPU tetap tidak berubah | **Variabel NVRAM `rev*` berprioritas lebih rendah dari boot-args** ⇒ **boot-args `revpatch=` juga harus memuat `cpuname`**; di Intel juga perlu `revcpu=1` eksplisit (`cpu-name.md` §3) |
| App suara/kamera "tidak punya izin", **tidak ada dialog, dan App tidak ada di daftar privasi** | Bukan App rusak ⇒ **boot-args mematikan AMFI** (`amfi=0x80` / `amfi_get_out_of_my_way=0x1`) membuat macOS **tidak menampilkan dialog dan tidak membuat entri** ⇒ driver lain bisa memakai `AMFIPass.kext`; di mesin ini tidak bisa ⇒ pakai `GeekAudio/tcc-helper` untuk injeksi (`amfi-and-tcc.md`) |
| Izin sudah diberikan ke App utama tapi tetap tidak berlaku | ★★ **Yang perlu diotorisasi adalah "helper / subkomponen yang benar-benar mengajukan izin"** — contoh: izin mikrofon Loopback milik `Audio Routing Kit (ARK).app` di dalam paketnya, **memberi izin ke `Loopback.app` tidak berguna** (`amfi-and-tcc.md` §4.2) |
| Entri TCC ditulis manual tapi App tetap tanpa izin | Biasanya **`csreq` salah** (magic berubah jadi `fade0c01`) atau **`tccd` belum direstart** ⇒ harus dihasilkan dari teks **sesudah** `designated =>` (`amfi-and-tcc.md` §4.5) |
| Mengira "Hackintosh memang harus mematikan AMFI" | **Mematikan AMFI ada harganya** (semua dialog TCC mati + keamanan turun) ⇒ periksa dulu README driver apakah **secara eksplisit menuntutnya**; kalau bisa memakai `AMFIPass`, jangan dimatikan (`amfi-and-tcc.md` §2) |
| Versi kext di EFI ternyata **satu tingkat lebih tinggi** dari release upstream, dan tag itu tidak ditemukan di upstream | **Bukan asal-usulnya tidak jelas** — `dortania/build-repo` **membangun per commit**, nomor patch dinaikkan sendiri, dan sering dikunci installer vendor ⇒ **ganti ke release upstream sama dengan menurunkan versi** (`kext-and-oc-update.md` §0) |
| Ingin "memperbarui semua kext sekaligus" | ★ **Ideanya sendiri salah** — grep dulu **installer milik vendor / `mirror.json`**; **yang dikunci vendor tidak boleh disentuh** (aturan besi 21) |
| Menganggap hanya mengganti `OpenCore.efi` sudah sama dengan meningkatkan OpenCore | Pada versi yang sama isi **semua** Drivers pada RELEASE / DEBUG berbeda ⇒ **wajib ganti bersama Drivers resmi dengan nama sama** (aturan besi 14, pakai `oc-swap-build.sh`) |
| Tidak bisa boot, ingin "menunggu lebih lama" | **Bedakan dulu hang vs loop restart** — **loop restart = timeout watchdog boot, "menunggu lebih lama" tidak berguna** (6 kali ganti model di mesin ini semuanya bentuk ini); hang baru layak ditunggu (`boot-failure-debug.md` §0.1) |
| Melihat `can't perform kext scan: no kext summary` lalu langsung memeriksa driver GPU | ★ **Ini kerusakan lapisan cache paling awal (< 1 s), sama sekali tidak ada hubungannya dengan GPU / kext tertentu** ⇒ jangan salah arah (`boot-failure-debug.md` §4) |
| Saat tidak bisa masuk ke sistem, "mengubah beberapa item sekaligus sambil lalu" | ★ Itu membuat audit berikutnya **kehilangan semua jejak** ⇒ **ubah satu item saja**, dan kembali dulu ke "konfigurasi yang terakhir bisa dipakai" (`boot-failure-debug.md` §7) |
| Ingin mengubah nama tampilan CPU lewat `Cpuid1Data` | **Tidak bisa** — string merek berada di CPUID `0x80000002-4`, `Cpuid1Data` hanya menyentuh leaf 1 ⇒ pakai `revcpuname` (`cpu-name.md` §7) |

## Sumber Daya

> Semua skrip memakai `set -euo pipefail` yang sama (**berhenti saat gagal**, tidak akan melanjutkan dengan hasil setengah jadi).
> ★ Tiga skrip yang mengubah ESP / volume sistem (`oc-edit-safe.sh` · `oc-swap-build.sh` · `mask-other-disks.sh`) jalankan dry-run dulu sebelum dieksekusi.

- `scripts/fetch-opencore-docs.sh` — unduh paket resmi versi sama, ekstrak validator dan dokumen, bangun pustaka kunci
- `scripts/oc-verify.sh` — validasi sekali klik (ocvalidate + apakah file yang dirujuk ada + perbandingan sha)
- `scripts/oc-swap-build.sh` — tukar build RELEASE ↔ DEBUG (ganti bersama Drivers resmi nama sama, pertahankan driver pihak ketiga, backup/validasi/simpan otomatis)
- `scripts/oc-edit-safe.sh` — pembungkus mengubah config dengan aman (backup/ubah/lint/sha/mirror/arsip/verifikasi ulang setelah pasang ulang)
- `scripts/grab-logs.sh` — ambil log boot OC dan log kernel dari boot ini (perlu elevasi)
- `scripts/boot-timeline.sh` — ikhtisar waktu boot (atribut NVRM + dmesg + linimasa launchd + log kernel, dengan proteksi timeout)
- `scripts/find-boot-gap.sh` — pemeriksaan rinci jendela jeda boot (cari celah terbesar di launchd.log → **filter streaming** log show)
- `scripts/mask-other-disks.sh` — tulis fstab berdasarkan UUID untuk memblokir volume non-macOS (kecualikan EFI secara eksplisit)
- `scripts/cpu-freq-probe.sh` — probe frekuensi CPU sebenarnya (inline assembly, mencegah optimizer folding) — verifikasi Turbo / bandingkan model
- `scripts/e-cores-check.sh` — **pemeriksaan E core**: topologi (`hw.nperflevels` / `perflevel1` / `CPUID`) + frekuensi + status muat `CpuTopologyRebuild` + interpretasi; `--topo` / `--freq` bisa dijalankan sendiri
- `scripts/kext-inventory.sh` — **pemeriksaan daftar kext**: versi / `DTXcode` / `DTSDKName` / ukuran / sha256 (termasuk PlugIns di dalam paket) + **pemeriksaan referensi config (0 hilang)** + versi inti OpenCore; `--tsv` memudahkan diff, `--save` menyimpan bukti sebelum perubahan
- `scripts/cpu-name-check.sh` — **pemeriksaan nama tampilan CPU**: perbandingan nama tampilan vs `machdep.cpu.brand_string` · parameter `rev*` (boot-args + NVRAM) · status muat `RestrictEvents` · pemeriksaan `ProcessorType` / `revcpuname` / `NVRAM>Delete` di config + interpretasi
- `scripts/mem-check.sh` — validasi penempatan injeksi memori (nomor array → prediksi slot gambar, menentukan apakah meleset dari "System Information")
- `scripts/oc-nvram-bootentry.sh` — **baca/tulis entri boot firmware dari dalam sistem** (pendamping metode resmi D): `dump` (mengurai nama/path perangkat) · `backup` / `restore` · `add` (termasuk `--dry-run`) · `del`. ★ **Operasi tulis perlu elevasi**; ★★ **dan hanya bermakna saat `RequestBootVarRouting=false`** (selain itu false positive)
- `scripts/redact-check.sh` — **pemeriksaan anonimisasi sebelum publikasi (hanya baca)**: pindai tiga kode / MAC / kunci / UUID volume / email / IP jaringan internal
- `scripts/oc-theme-check.sh` — **pemeriksaan kepatuhan pohon Resources** (ikon wajib / ukuran piksel sebenarnya / label / font / audio)
- `scripts/oc-fetch-iconset.sh` — ambil set ikon / font / label / audio dari OcBinaryData resmi
- `scripts/bios-audit.ps1` — **audit BIOS sisi Windows (hanya baca)**: nilai tipe firmware/Secure Boot/TPM/VT-x/HT/XMP/**VMD·RST**/port serial/jumlah slot memori, dan yang tidak bisa dinilai ditandai jelas
- `references/official-docs-method.md` — cara memakai dokumen, metode penilaian per kunci, tabel hubungan berpasangan
- `references/logs-and-debug.md` — definisi bit `Target`/`DisplayLevel`, kriteria log, atribusi layar penuh
- `references/boot-entries.md` — **entri boot firmware (`Boot####` / `BootOrder`) dan `Misc>Boot>LauncherOption`**: ★ **akar masalah "entri boot hilang setelah boot dari U disk"**, empat nilai, perintah forensik, **jebakan `Boot0000` di ASUS**; ★★ **§7 metode perbaikan resmi (`bcfg` / `OpenControl` / `LauncherOption=Full` / tulis dari dalam sistem + `BootKicker`)**, **§8 dari boot U disk ke boot disk keras**
- `references/boot-timeline.md` — **analisis waktu boot/linimasa**: pemecahan tiga tahap, filter streaming, penentuan jendela jeda, sumber waktu lama dan penanganannya
- `references/acpi-ssdt.md` — inspeksi ACPI/SSDT: syarat berlaku tiap item AcpiSamples resmi · pemeriksaan keberadaan perangkat · konvensi penamaan · ★★ **tabel indeks `5T33Z0/OC-Little-Translated` sesuai kebutuhan** (termasuk titik landed mesin ini) · **yang tidak ada di resmi/Dortania** (`SSDT-ALL` tabel gabungan · **port mapping USB dengan ACPI** · `SSDT-I225V` · `SSDT-PMCR` · `ACPIDebug` · `Fixing_Preboot`)
- `references/bios-settings.md` — **audit BIOS/UEFI**: 9 poin resmi + Dortania (Intel/AMD) + tambahan komunitas (**VMD**/Speed Shift), tiga kategori **wajib dimatikan/wajib dinyalakan/tergantung situasi**, topik CFG Lock, **tabel padanan nama vendor**, cara memakai skrip audit Windows
- `references/disks-and-kexts.md` — kriteria pemblokiran disk dan pengoptimalan kext serta daftar "tidak boleh dihapus"
- `references/nvidia-driver.md` — driver NVIDIA NullMoth: cakupan berlaku, pemasangan, setelan OC wajib, pemulihan, tabel kegagalan
- `references/amfi-and-tcc.md` — **konflik AMFI ↔ TCC (App tidak mendapat izin)**: ★ tiga gejala beruntun (**baris ketiga = entri tidak ada di daftar privasi** itulah kriterianya) · akar masalah (`amfi=0x80`) · **`AMFIPass` pilihan pertama di mesin lain** (di mesin ini tidak bisa, hanya bisa pilih salah satu) · ★★ **solusi `GeekAudio/tcc-helper`** (GUI + CLI, **otorisasi otomatis diturunkan dari sistem**, 109 layanan, target apa pun termasuk executable telanjang) · **yang diotorisasi adalah helper yang benar-benar mengajukan, bukan App utama** · field tabel `access` dan magic `csreq` `fade0c00` · **lima jebakan rekayasa** · tiga klasifikasi diagnosis · tidak persisten · **lampiran: Gatekeeper / "sumber mana pun" / "pengembang tidak bisa diverifikasi" (`sudo spctl --global-disable`, `--master-disable` sudah usang di macOS 15+; ini beda dengan TCC)**
- `references/intel-wifi.md` — driver Wi-Fi Intel (AirportItlwm / itlwm): jalur versi, injeksi, pasangan Bluetooth, pemecahan masalah
- `references/mediatek-wifi.md` — kartu Wi-Fi MediaTek (MT7921 / MT7922 / RZ608 / RZ717): ★★★ **driver Sunrise native di macOS 26** (`AppleSunriseWLAN/Bluetooth` dext + firmware bawaan + PCIe Bluetooth `14c3:792a`) · ★★★ **jalur native memakai `GeekAudio/mediatek-sunrise-hackintosh` (MT7922 Sunrise Pack, berisi firmware/kext HAL/device-id spoofing tanpa kompilasi)** · **status firmware per chip di 26.7.1** · **`AppleSunrise.kext` = HAL di kernel (wajib)** · **tabel pembacaan log / tabel boot-args** · ★★ **Wi-Fi pihak ketiga memakai fork `flxxxxddd/SimpleMtkWlan` (ada release, 802.11n/ac bisa dipakai)** · **tiga batasan keras (tanpa menu native / tanpa AirDrop / tanpa HE)** · **jebakan kartu disembunyikan SSDT** · `mtklog.sh` untuk pemecahan masalah · pohon keputusan tiga jalur, pengenalan chip, dua jebakan NVRAM Bluetooth pihak ketiga
- `references/applealc-custom.md` — audio onboard (AppleALC): ★★★ **pemulihan `AppleHDA` di macOS 26 (panduan `perez987`: kartu suara USB / **KDK + `MyKextInstaller`** / OCLP / perbandingan solusi VoodooHDA + syarat dan validasi)** · ★★ **kustomisasi lewat `5T33Z0/AppleALC-Guides`** (alur 14 bab · 17 dump siap pakai · **`alc-verb` untuk menyetel audio saat runtime** · tabel `MuteGPIO` · **dioptimalkan hingga 90 KB** · alur rollback) · ★★★ **batasan keras: harus ada pengambilan data dari sisi Windows sebelum menulis layout** (kalau pengguna bisa menyediakan, langsung masuk alur kustomisasi; kalau tidak, suruh dia mengambil; **GUI lewat HDAU, skrip lewat koneksi langsung `HDAudDev.dll`** — tanpa administrator, bisa diskrip, menghasilkan `codec_dump.txt/.json` bergaya Linux; setelah dump pakai **bukti balik dari sisi Windows untuk memetakan jack**) · **tiga akar masalah terukur pada AppleHDA** (PathMap dengan beberapa path dalam satu grup hanya menyisakan yang terakhir / pin Mic tipe jack tidak bisa membuat perangkat / deteksi jack mungkin mati seluruhnya) · **jangan verifikasi dengan telinga** (baca register `0xF07`/`0xF06` saat pemutaran) · cara membaca field Pin Config Default · cari dulu pengalaman orang lain, kustomisasi per codec, build lokal, uji, kirim PR
- `references/broadcom-wifi.md` — kartu Broadcom (BCM43602/BCM20703): **jalur terpisah per Sequoia/Tahoe**, OCLP root patch, kriteria validasi
- `references/ethernet-drivers.md` — **driver pihak ketiga untuk Ethernet** (Intel I225/I226 · I210/I211/I350 · Realtek RTL8125/8126): perbandingan solusi, cara memasang, kriteria
- `references/ecosystem-sources.md` — ★★ **Ekosistem Hackintosh: sumber otoritatif dan indeks alat**: repo resmi Acidanthera / Dortania · **toolchain corpnewt** (ProperTree / GenSMBIOS / SSDTTime / USBMap / gibMacOS / MountEFI) · `USBToolBox` · `blacktop/ipsw-diffs` · penulis driver tiap perangkat keras · sumber daya berbahasa Mandarin (Yuanjing / Heiguo Xiaobing / terjemahan OC-Little) · ★ **tabel "untuk urusan apa percaya siapa"**
- `references/laobamac-toolkit.md` — **indeks alat dan patch laobamac (tabel lengkap 48 repo)**: driver · pemasangan (`SimpleKaruzi`/`PVE-OpenCore`) · ★ **jebakan hardware (`SimpleBuyersGuide`)** · alat pemeliharaan (`SimpleLoader`) · launchpad macOS 26 · patch referensi (`OC-little-zh`/`non-metal-frameworks`) · platform AMD · penjelasan fork · ★ **mana yang sudah diarsipkan**
- `references/network-en0-order.md` — **kepemilikan `en0` dan urutan interface jaringan (umum)**: siapa yang bergantung pada `en0` (ROM / iMessage / FaceTime / App Store), **setelah menambal Wi-Fi wajib memastikan nirkabel adalah `en0`**, cara mengunci, dampak turunan, disiplin kriteria. ★ **AirDrop / Handoff tidak bergantung pada `en0`** (lihat `airdrop-handoff.md`)
- `references/airdrop-handoff.md` — **AirDrop / Handoff / Continuity**: ★★★ **akar masalah hanya `awdl0` (= stack native `IO80211Family` Broadcom)** · **`itlwm.kext` pasti tidak bisa dipakai (kutipan FAQ resmi)** · **empat salah paham (`ROM` / `en0` / `SystemUUID` / nomor seri)** · **urutan penelusuran 8 langkah** · prinsip pemilihan kartu · pengukuran di mesin ini (termasuk contoh balik "kenapa U disk EFI rusak")
- `references/hidpi.md` — membuka HiDPI di layar non Retina (one-key-hidpi): lokasi penulisan, dua mode, jalur pemulihan, **risiko terhadap driver NVIDIA**
- `references/intel-turbo.md` — Intel Turbo/pembatasan frekuensi CPU: ★★★ **metode terbaik yang sudah final (inject "profile milik mesin ini dengan `hwp` dihapus", empat kriteria)** · **posisi asli `hwp` dan cara menghapusnya** · **tabel pilihan dari 76 profil dalam lima keluarga** · validasi CPU-S · **setelah diubah wajib restart** · perbaikan CPUFriend · prasyarat BIOS
- `references/e-cores.md` — **nyalakan / matikan E core (arsitektur hibrida Intel P/E core)**: ★ dua trade-off · BIOS `Active Efficient Cores` (empat penamaan vendor) · `ProvideCurrentCpuInfo` · **empat nilai `CpuTopologyRebuild` (`ctrsmt=off` / `ctrsmt=full` / `-ctrfixcnt`)** · kriteria `hw.nperflevels` · **konflik `-v` yang sudah dikenal resmi** · rollback
- `references/kext-and-oc-update.md` — **pembaruan kext dan OpenCore**: ★★★ **tag upstream tidak ditemukan ≠ asal-usul tidak jelas** (Dortania `build-repo` membangun per commit, nomor patch +1) · **empat kriteria "barang resmi"** (hanya "apakah installer vendor mengunci" yang bisa menentukan) · **nilai DEBUG/RELEASE dengan perbandingan ukuran** · tabel perlu/tidak perlu diperbarui · **pembaruan inti OC (ganti bersama Drivers)** · alur aman 9 langkah · jebakan
- `references/boot-failure-debug.md` — **alur debug berlapis untuk sistem yang gagal dipasang / tidak bisa dimasuki**: ★ **pengelompokan empat tahap** (firmware/OC itu sendiri · fase boot OC · kernel awal · kernel tengah-late) · ★★ **hang vs loop restart** · tabel pintasan tiap tahap (termasuk `no kext summary` / `X86PlatformShim` / `decmpfs` / `element modified after free` dan sejenisnya yang **sudah dikualifikasi di mesin ini**) · khusus fase instalasi (VMD tidak menemukan disk dll.) · **urutan penyelamatan 6 langkah** · ACPI (`xh_adls3`) · **daftar bukti forensik**


- `references/cpu-name.md` — **nama tampilan CPU (ganti nama)**: ★ murni tampilan · trio RestrictEvents (`revpatch=cpuname` / `revcpu=1` / `revcpuname`) · ★★ **prioritas NVRAM lebih rendah dari boot-args** · `revcpuname` hanya bisa ditaruh di NVRAM · `ProcessorType` harus berpasangan dengan jumlah core · **dua jalan buntu `Cpuid1Data` / `AppleSystemInfo.strings`** · pemecahan masalah
- `references/smbios-and-serials.md` — **ganti model + tiga kode**: ★★★ **SSDT OEM motherboard (`xh_adls3`) dan akar masalah ACPI**, **aturan besi urutan (sempurnakan SSDT dulu)**, daftar periksa, dasar keputusan, kriteria nomor seri, ROM, tiga status skrip pergantian, pelajaran dari kesalahan
- `references/memory-injection.md` — kustomisasi memori model MacPro: **tabel pemetaan 12 slot**, **aturan penempatan f**, field umum layer A, jebakan
- `references/rapidefi-first-efi.md` — mulai dari nol: membuat EFI dasar dengan RapidEFI di Windows, dan pekerjaan penutup yang wajib setelahnya
- `references/lifecycle.md` — **alur lengkap enam tahap**: buat di Win → pasang → ganti DEBUG → kumpulkan log → perbaiki → rutinitas
- `references/os-upgrade-15-to-26.md` — **peningkatan versi besar sistem** (15 Sequoia → 26 Tahoe): **routing versi `MinKernel`/`MaxKernel`**, daftar per komponen, urutan peningkatan, whitelist model, jebakan baru macOS 26, OCLP vs BCMC
- `references/pitfalls.md` — seluruh jebakan yang pernah dilalui
- `references/theme-opencanopy.md` — **tema selector (OpenCanopy)**: tabel sakelar lengkap, direktori sumber daya, **daftar ikon (wajib/opsional/tidak disediakan resmi)**, aturan Flavour, label/font/audio/latar belakang, pemecahan masalah
- `references/machine-facts.md` — fakta spesifik mesin ini (Z690/Alder Lake/macOS 26)
- `USAGE.md` — **ringkasan singkat untuk pengguna** (keluarkan ini ketika pengguna bertanya "bagaimana memakai/petunjuk penggunaan/apa yang bisa dilakukan")
