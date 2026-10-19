# Metode pemasangan driver NVIDIA (NullMoth nvidia-macos-driver)

> ★ **Repositori patch terkait**: `laobamac/non-metal-frameworks` — **patch framework non-Metal** (berbasis pada repositori Moraea yang sudah dihapus)
> ⇒ patch untuk GPU lama pada sistem yang sudah berbasis Metal. Indeksnya ada di `laobamac-toolkit.md`.

> Dasar: repositori resmi `nullmoth/nvidia-macos-driver`, `README.md` / `docs/HOW-IT-WORKS.md` /
> `docs/TROUBLESHOOTING.md` / `docs/CARD-SUPPORT.md` / `gpu-port/README.md` (kutipan per butir),
> ditambah pengukuran lokal (ASUS Z690 + RTX 3080 + macOS 26.7.1), bagian hasil pengukuran ditandai.

## 0. Pastikan dulu apakah "kartu ini + sistem ini" berada dalam cakupan

| Item | Ketentuan resmi |
|---|---|
| Kartu | **Turing dan lebih baru**: GTX 16, RTX 20/30/40/50, TITAN RTX, Quadro RTX, seri T (T400/T600/T1000, T500/T550/T600/T1200 laptop). Pascal / Maxwell / Kepler dan yang lebih lama **tidak didukung** (butuh implementasi kernel/firmware lain) |
| Sistem | macOS **15 Sequoia** (diuji 15.7.x dan 15.8.1) dan **macOS 26 Tahoe** (mulai 2.0.0), x86_64 |
| Laptop | Model yang layarnya tersambung ke GPU terintegrasi, layar internal tidak akan terakselerasi; terima PCI ID ≠ implementasi display mux Optimus |
| macOS 26 | ★ **dukungan resmi Tahoe mulai 2.0.0** (changelog: "Tahoe: ship the macOS 26 accelerator built from this release"; di dalam paket `kexts/26` dan `kexts/15` dibangun terpisah). Pada era 1.15.0 ini termasuk penggunaan di luar cakupan (saat itu resmi hanya menyatakan macOS 15). **Pengukuran lokal**: **2.0.1** di macOS 26.7.1 memuat 4 kext dengan normal, desktop bisa dipakai |

## 1. Dua jalur pemasangan

### A. Paket praprakompilasi resmi (direkomendasikan)

```bash
tar -xzf nullmoth-nvidia-*.tar.gz && cd pkgroot
shasum -a 256 -c SHA256SUMS          # setiap baris harus OK
sudo ./install.sh                    # salin file + bangun ulang Auxiliary Kernel Collection
sudo shutdown -r now                 # wajib restart: logout tidak akan memuat driver
```

Setelah muat pertama, di System Settings → Privacy & Security **izinkan ekstensi ini**, lalu restart sekali lagi.

### B. 1401 Mac App (paling praktis, sekalian mengubah OpenCore)

Unduh `1401-Mac-<version>.dmg` → buka jalankan 1401 (paket driver ada di dalam image). App akan:

1. Menggunakan NVRAM `boot-path` untuk menemukan **OpenCore yang dipakai booting mesin ini** (kalau tidak ditemukan, telusuri per partisi, hanya yang cocok SMBIOS agar tidak keliru mengubah disk rescue)
2. **Mencoba membangun AuxKC dulu**, kalau gagal tidak ada yang diubah sama sekali
3. Mencadangkan `config.plist`, hanya melengkapi entri yang kurang di bagian 2, validasi dengan `plutil` (kalau gagal, kembalikan cadangan)
4. Menambahkan **`1401: Remove NVIDIA driver`** ke selector (`Misc>Tools` + `NullMothSafe.efi`)
5. Menjalankan `install.sh` dari paket, menulis catatan pemasangan ke `/Library/NullMoth/state`

**Selama App berjalan, disk OpenCore yang dipakai untuk booting macOS harus tetap tertancap** (yang diubah adalah config tersebut).
App punya tombol "Turn verbose on/off" (= menambah/menghapus `-v` pada boot-args).

## 2. ★ Konsep inti: kext dipasang di mana, dimuat dari mana

- Empat kext (`NVRM` / `NVAccel` / `NVRMFB` / `NVRMAGDC`) dipasang ke **`/Library/Extensions`**, dimuat dari **Auxiliary Kernel Collection**
- ⇒ **Jangan pernah** menyuntikkannya sekaligus dari `EFI/OC/Kexts` (akan bentrok). OpenCore hanya perlu mengatur SIP dan boot-args
- Mereka menautkan `IOGraphicsFamily` / `IOAcceleratorFamily2` milik Apple, yang hanya ada di kernel collection milik macOS sendiri, jadi tidak bisa disuntik lewat OpenCore

## 3. Pengaturan wajib OpenCore (tabel resmi)

**`NVRAM → Add → 7C436110-AB2A-4BBB-A880-FE41995C9F82`**

| Kunci | Nilai | Alasan |
|---|---|---|
| `csr-active-config` | `<430A0000>` | nilai SIP untuk pengujian driver (kext bertanda tangan non-Apple) |
| `boot-args` | `nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0` | mengaktifkan framebuffer + akselerator, 4 display head; parameter AMFI membuat WindowServer dapat memuat driver bundle |

**Pengaturan lain**

| Lokasi | Nilai | Alasan |
|---|---|---|
| `UEFI → Quirks → ResizeGpuBars` | pertahankan nilai saat ini (HOW-IT-WORKS resmi memakai `13` = 8 GB) | mengubah ukuran paksa bisa membuat firmware macet sebelum masuk selector |
| `Booter → Quirks → ResizeAppleGpuBars` | pertahankan nilai saat ini (HOW-IT-WORKS memakai `-1`) | large BAR bisa macet di PCI configuration |
| `Kernel → Add` | `Lilu.kext` dan `AMFIPass.kext` **wajib diaktifkan** (Lilu di depan, AMFIPass di belakang) | ★★ **AMFIPass itulah yang membuat WindowServer (platform binary) memuat driver bertanda tangan ad-hoc**; tanpanya = tidak ada perangkat Metal + layar hitam hanya dengan kursor (ada log pengukuran pada skrip instalasi upstream). Installer otomatis mengunduh dan memverifikasi SHA |
| `Kernel → Block` | `com.apple.iokit.IONDRVSupport`, `Exclude` | kalau tidak, firmware framebuffer akan merebut display index 0 |
| `Misc → Security → SecureBootModel` | `Disabled` | Apple secure boot menolak kext bertanda tangan non-Apple |
| BIOS | Above 4G Decoding **ON**, CSM **OFF** | kartu perlu memetakan memori di atas 4 GB |
| SMBIOS | model yang bisa menjalankan macOS 15 dan punya GPU dedicated (1401 memakai `MacPro7,1`; pernah diuji `iMacPro1,1`) | macOS 26 menolak `iMacPro1,1`, `MacPro7,1` bisa jalan di kedua versi |

**Wajib dihapus**: `nv_disable=1` dan `-wegnoegpu` apa pun (keduanya menyembunyikan GPU N), patch NVIDIA dari WhateverGreen, `agdpmod=pikera`.
**GPU tidak memerlukan `DeviceProperties` sama sekali**.

**boot-args opsional (untuk troubleshoot)**

| boot-arg | Fungsi |
|---|---|
| `-nvrmnoflip` | membuat NVRM tidak mengaktifkan zero-copy direct scan, monitor membaca hasil salinan yang sudah selesai. **Coba ini yang pertama saat desktop berkedip/ter tearing** |
| `-nvrmnogo` | driver standby, menunggu `nvrmctl go <pass>` sebelum mengaktifkan GPU |
| `-nvrmnobootscreen` | tidak mengambil tangkapan layar boot |
| `-nvoff` | membuat NVRM sama sekali tidak menyentuh kartu ini (inilah yang dipakai "Start once without NVIDIA driver" di selector) |
| `nvrmsettle=<ms>` | menimpa waktu tunggu setelah GPU menyala (resmi pernah memakai `10000` pada Turing) |

**Verifikasi setelah pemasangan**

```bash
kmutil showloaded --list-only | grep nullmoth     # harus 4 baris
system_profiler SPDisplaysDataType | head -20     # harus menampilkan GeForce Anda, Metal: supported
```

## 4. Jalur pemulihan (bila tidak bisa masuk sistem)

1. Di selector pilih **`1401: Remove NVIDIA driver`** (konfirmasi dengan Y, lalu pilih macOS) — ini menambahkan `-nvoff` + menulis flag NVRAM `nullmoth-remove=1`, setelah macOS hidup, LaunchDaemon `com.nullmoth.recover` menjalankan `--remove` dan restart otomatis
2. Atau di selector pilih **`1401: Start once without NVIDIA driver`** (`-nvoff`, hanya berlaku untuk boot kali ini)
3. Atau dari sistem lain, tambahkan `-nvoff` ke boot-args pada `EFI/OC/config.plist`, dan blokir `com.apple.NVRM*` di `Kernel>Block`
4. Logo boot (`NullMothLogo.efi`) nonaktif secara default; **mungkin membuat firmware tidak sampai ke selector**, kalau selector tidak muncul, matikan `NullMothLogo.efi` dari sistem lain (boot-args tidak bisa menolong kasus "macet sebelum selector")

## 5. Perbandingan masalah umum (ringkasan resmi TROUBLESHOOTING)

| Gejala | Penyebab | Penanganan |
|---|---|---|
| Desktop menyala sekitar satu menit, lalu layar hitam hanya dengan kursor | pada menit tersebut driver beralih ke "output langsung dari pemindaian VRAM", sedangkan desktop tergambar di GPU terintegrasi atau window BAR kecil | sudah diperbaiki di 1.14; versi lebih lama tambahkan `-nvrmnoflip` |
| Layar hitam/berkedip pada 100–240 Hz, atau muncul setelah mengubah resolusi/refresh rate | bandwidth DisplayPort 1.4 tidak cukup untuk DSC, dan macOS tidak diberi tahu | 1.14 sudah mengirim setelan kompresi; masih muncul kirim Send logs |
| Desktop hitam di macOS 26 | akselerator versi 26 di dalam paket sudah usang | sudah diperbaiki di 1.14 |
| Ganti input monitor lalu kembali, tidak ada gambar | driver hanya menyalakan monitor yang belum pernah "dilihat" | sudah diperbaiki di 1.14; versi lebih lama lepas-sambungkan kabel |
| Papan Intel lama (tanpa ReBAR) layar hitam sekitar 100 detik, log berisi `cannot hold … not placing` | firmware tidak mencantumkan range PCI 64-bit | sudah diperbaiki di 1.14 |
| Setelah memasang driver, macet sekitar 19 menit (Ryzen 7000/8000/9000) | papan ini macet saat installer menulis setelan firmware | `Booter → Quirks → DisableVariableWrite = true` |
| Kartu Turing setelah dipasang boot berputar di `AppleKeyStore` | firmware butuh waktu lebih lama | sejak 1.13 Setup otomatis menambahkan `nvrmsettle=10000` |
| Saat boot muncul `This version of Mac OS X is not supported on this platform!` + `Mac-…` | model tidak diterima oleh versi macOS tersebut | gunakan `MacPro7,1` (jalan di macOS 15/26); untuk EFI buatan sendiri gunakan "Check your EFI" dari 1401 |
| `Quadro T1200 / T series … is older than the driver supports` | whitelist installer belum mencakup | sudah diperbaiki di 1.14 (Turing dan lebih baru semuanya diterima) |
| Desktop berkedip, jendela menunjukkan blok hitam, Preview menampilkan blok | konten gambar ditandai sebagai terbaru sebelum selesai digambar di GPU / dilepas dua kali | sudah diperbaiki di 1.14; masih muncul kirim Send logs |
| Halaman web menampilkan WebGL tidak didukung | sebagian shader gagal diterjemahkan | sudah diperbaiki di 1.14 |

## 6. Tambahan hasil pengukuran lokal (ASUS Z690 + RTX 3080 + macOS 26.7.1)

- Versi paket **1.15.0**; `/Library/NullMoth/os-major` = 26, tetapi driver memakai build **`kexts/15`** (komentar penulis: rangkaian NV di 15/26 adalah biner yang sama)
- boot-args yang dipakai: `nvrmsettle=1500 nvfbsample=1 nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth -no_compat_check revpatch=sbvmm,cpuname revcpu=1`
- `ResizeGpuBars=13` + `ResizeAppleGpuBars=-1`; biayanya = **layar hitam saat boot ~21 s** (dengan `-1` sekitar 10 s)
- Boot sampai WindowServer **15 s** (tanpa regresi); `NVAccel: configureDevice 10de:2206 — RM owns the card (NVRM.kext)` adalah baris normal
- GPU terintegrasi harus diblokir dengan `-wegnoigpu` (WhateverGreen), jika tidak GPU terintegrasi tetap ada di pohon PCI dan ikut menentukan AGDC
- Masalah tampilan yang pernah ditemui: monitor dilaporkan sebagai **30,5"** — penyebab sebenarnya driver tidak mengisi `IODisplayModeInformation.imageWidth/imageHeight` (sudah diperbaiki, PR #199)
- Belum diketahui dan belum selesai: tidak ada audio HDMI/DP, eGPU Thunderbolt tanpa output, layar internal laptop tidak terakselerasi

## 7. Disiplin pelaporan (Send logs)

- **Kirim Send logs dulu untuk mendapatkan report ID, baru buka issue** (templat bug resmi menandai report ID sebagai wajib, dan menutup issue kosong)
- Sebelum melapor **baca dulu resi lokal** (misal `~/Library/Logs/NullMoth/Reports/report-*/upload-receipt.json`), cocokkan jumlah entri `confirmed[]` dengan sha — daftar ID datar dari App bisa memuat **entri lama**
- **Jika ID duplikat, curigai "isi yang sama"**: server bersifat content-addressed, isi identik mengembalikan ID yang sama, itu deduplikasi yang bekerja normal
- Pengumpul bisa melaporkan `System log collection did not complete (status 124)` — biasanya hanya memengaruhi jalur **log sistem**, `driver-kernel-log.txt` tetap terkirim
- Isi issue: **satu issue satu masalah**, tulis beberapa kalimat dengan kalimat sendiri, **jangan menempelkan log panjang** (biarkan log tetap berada di report ID)

## 8. Peringatan keamanan

Memasang driver ini mengharuskan pelonggaran batas keamanan sistem: `SecureBootModel=Disabled` + `csr-active-config` yang melonggarkan SIP + parameter AMFI (`amfi_get_out_of_my_way`),
dan `Lilu.kext` / `AMFIPass.kext` harus diaktifkan.
Ini **menurunkan keamanan sistem secara sengaja** demi akselerasi grafis, lakukan hanya bila memang dibutuhkan; ketika driver tidak dipasang, kembalikan semua item ini ke nilai semula.

> ★★ **Ada biaya tersembunyi dari mematikan AMFI**: **semua dialog izin TCC akan gagal** ——
> App berguna suara / kamera akan "melapor tidak punya izin + tidak memunculkan dialog + tidak ada di daftar privasi".
> Ini bukan bug driver, melainkan sifat dari "AMFI dimatikan"; **pikirkan dulu apakah mesin ini akan memakai mikrofon/kamera** sebelum memakainya.
> ★ Jika perlu, pakai **`GeekAudio/tcc-helper`** untuk menulis entri "sudah diizinkan" langsung ke database TCC
> (GUI + CLI, otomatis menyimpulkan siapa butuh izin apa dari `Info.plist` dan komponen launchd) ⇒ lihat **`amfi-and-tcc.md`**.
