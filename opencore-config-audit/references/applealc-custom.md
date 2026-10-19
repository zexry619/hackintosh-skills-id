# Kustomisasi kartu suara onboard motherboard (AppleALC)

> Dasar: **README** dan **wiki resmi** dari `acidanthera/AppleALC`
> (`Installation-and-usage` / `Adding-codec-support` / `Supported-codecs`) + `.github/workflows/main.yml` dari CI resmi
> + ★★ **`5T33Z0/AppleALC-Guides`** (14 bab panduan praktis: dump → diagram topologi → PathMap → PinConfig → kompilasi → pengujian → PR;
> berisi **17 codec dump siap pakai** · **penetapan audio runtime `alc-verb`** · **dioptimalkan hingga 90 KB** · **manajemen file/rollback**).
> Semua bagian yang diapit tanda kutip di bawah adalah teks asli resmi; yang ditandai "panduan" berasal dari `5T33Z0`.
> ★ **Pembagian tugas**: **wiki resmi menjelaskan "aturan"** (bisa atau tidak, cara memberi nomor, cara mengajukan PR) · **`5T33Z0` menjelaskan "cara mengerjakan"** (langkah demi langkah) ⇒ baca keduanya berdampingan.
>
> ★★★ **macOS 26 (Tahoe) baca dulu §0.5** —— Apple menghapus `AppleHDA.kext` di DP2,
> **tanpa memulihkannya lebih dulu, semua layout-id di bawah ini sia-sia**;
> referensi utama `perez987/AppleHDA-gone-on-macOS-26-Tahoe` (KDK + MyKextInstaller / SimpleLoader).
>
> **Cara membaca dokumen ini**: isi utama adalah **metode dan kriteria yang dapat dipakai ulang**, tidak bergantung pada codec tertentu;
> bagian bertanda **"contoh"** adalah nilai terukur dari satu penerapan lengkap (ALC897), **wajib diganti seluruhnya saat ganti mesin**——
> apa yang perlu diganti dan dari mana memperolehnya, lihat tabel pada §0.6.

## 0. Dua jalur (kerjakan A dulu, jika A mentok baru B)

```
Tentukan model codec dan revision
   ├─ A. Cari dulu "apakah ada orang sebelumnya yang memakai model sama" ← disarankan, cukup untuk kebanyakan kasus
   │      ketemu ⇒ salin layout-id, coba satu per satu, verifikasi setelah restart
   └─ B. tidak ada ⇒ ★ tanyakan dulu ke pengguna apakah bisa menyediakan data dari sisi Windows (checklist 1–4 di §3.0.1)
                ├─ bisa ⇒ langsung ke alur kustomisasi §3, pakai data yang ia berikan
                └─ tidak  ⇒ jelaskan batasan keras: ambil semua data di Windows sesuai §3.0.1 lalu kembali, jangan mulai menulis tanpa data
```

**Mengapa harus mencari dulu**: mekanisme AppleALC adalah pemetaan "nama codec + layout-id" ke sekumpulan data platform/layout,
**motherboard berbeda dengan codec yang sama biasanya bisa memakai layout yang sama**, dan mencoba satu per satu sering langsung berhasil —— itu menghemat waktu beberapa orde besaran dibanding membuat layout dari nol.

> ★★★ **Batasan keras jalur B: sebelum mulai kerja, data dari Windows harus sudah diambil semua.**
> **Jangan mulai menulis layout tanpa data ini** —— lebih murah melengkapi yang kurang satu per satu daripada dikerjakan ulang.
> Apa yang diambil, caranya, dan format penyimpanannya, lihat **§3.0.1**; jalur cadangan serta biayanya saat tidak ada Windows juga ada di sana.
> ★ **Namun jika pengguna sudah punya data ini (diekspor sendiri, atau bisa dilampirkan), jangan suruh dia jalankan Windows lagi ——
> langsung masuk ke alur kustomisasi §3 dengan memakai data yang ia berikan.**

## 0.5 ★★★ Prasyarat macOS 26 (Tahoe): kembalikan dulu `AppleHDA`

> README resmi menyebutkan *"**macOS 26 dropped AppleHDA.kext in DP2.** AppleALC functioning on macOS 26 may
> require additional actions if AppleHDA.kext is necessary."*
> ⇒ **Di 26, prasyarat AppleALC berfungsi adalah mengembalikan `AppleHDA` terlebih dahulu.**
>
> ★★ **Referensi utama: `perez987/AppleHDA-gone-on-macOS-26-Tahoe`** —— panduan lengkap khusus untuk topik ini
> (MIT; penulis `perez987` adalah veteran Hackintosh, dengan beberapa panduan sejenis untuk Fenvi Broadcom / Intel AX210 / UEFI Secure Boot).

### 0.5.1 Pahami dulu latar belakang (mengapa onboard tidak bersuara, HDMI justru ada)

- **Peran `AppleHDA.kext`**: membuat macOS ① mengenali perangkat kartu suara onboard (speaker / headphone) ② membaca **`Layout-ID`** dari firmware
  ③ memuat pemetaan suara model yang sesuai dengan Layout-ID tersebut.
- **`AppleALC` "bekerja di samping `AppleHDA`"** (melalui injeksi kernel, **tidak mengubah sistem file**)
  ⇒ ★ **Begitu `AppleHDA` tidak ada, seluruh audio onboard hilang**, dan AppleALC tidak punya tempat melekat.
- **Mengapa Apple berani menghapus**: **Intel Mac generasi terakhir yang bisa naik ke Tahoe semuanya punya T2**, audio ditangani T2 sehingga `AppleHDA` tidak diperlukan.
  ⇒ Apple menghapus komponen "yang tidak dibutuhkan model yang didukung" mengikuti kebiasaan lama.
- ★★ **Kriteria**: **tanpa `AppleHDA` / `AppleALC`, audio digital dari kartu grafis (HDMI / DisplayPort) tetap bisa dipakai**
  (karena memakai kext lain) ⇒ **"hanya HDMI bersuara, kartu suara onboard tidak bersuara" memang adalah gejala ini**, bukan kartu suara rusak.

### 0.5.2 Perbandingan solusi

| Solusi | Cara | Biaya |
|---|---|---|
| **Kartu suara USB** | Banyak perangkat audio USB **didukung secara native oleh macOS** (panduan menguji Sound Blaster Play! 3, sekitar €15) | ★ **Paling praktis, sama sekali tidak menyentuh sistem**; biaya = CPU sedikit lebih tinggi dari onboard, biasanya hanya dua kanal "speaker + mikrofon" |
| **★★ KDK + `MyKextInstaller`** | Pasang kembali `AppleHDA.kext` dari **KDK** ke `/System/Library/Extensions` dan bangun ulang kernel collection | **Butuh KDK**; harus melonggarkan SIP (**`csr-active-config=03080000`**); ★ **Setiap kali sistem di-upgrade harus dipasang ulang** |
| `SimpleLoader` (laobamac) | Sama seperti di atas, antarmuka SwiftUI, sudah ada **proteksi rollback lewat snapshot APFS** | ★ **Pengarang sudah lama tidak memperbarui, tampak usang**; dependensi KDK sama seperti di atas |
| **OCLP root patch** | Menerapkan `AppleHDA` kembali seperti root patch | ★ **Tim OCLP masih di tahap awal, saat ini belum cocok untuk pengguna umum**; ★ repositori praktis khusus: **`5T33Z0/OCLP4Hackintosh` berkas `Enable_Features/Audio_Tahoe.md`** (disarankan oleh panduan `5T33Z0`) |
| **Keluarga VoodooHDA** (misalnya `SimpleVoodooHDA`) | **Mengganti seluruh** stack audio | ★ **Kualitas suara berkurang** (cakupan kompatibilitas luas) |
| ~~`SimpleHDA`~~ (Lilu plugin yang meng-inject AppleHDA asli) | Cara yang sebelumnya direkomendasikan di bagian ini | ★ Lihat §0.5.6 —— **turunkan menjadi pilihan cadangan** |

### 0.5.3 Dua App (tepat dua ini yang direkomendasikan panduan)

| App | Pengarang | Penilaian (maksud panduan) |
|---|---|---|
| **★★ `MyKextInstaller`** | **Mirone** | **Pilihan utama**: antarmuka sederhana dan mudah dipakai, **bisa langsung mengunduh `AppleHDA.kext` dari dalam App**; **pembaruannya sering dan lebih mengikuti sistem**. ★ Sudah di GitHub, tetapi **kode sumbernya belum dipublikasikan** |
| `SimpleLoader` | laobamac | SwiftUI; **bahasa dasarnya adalah Tionghoa** (**terjemahan yang lebih baru ada di fork `perez987`**, yang di upstream belum menyusul); ★ **sudah lama tidak diperbarui, tampak usang** |

**Keduanya bisa melakukan dua hal**: ① memasang kembali `AppleHDA.kext` (diambil dari Sequoia / beta awal Tahoe) untuk memulihkan audio onboard;
② **mengembalikan sistem ke snapshot tersegel terakhir yang belum dimodifikasi** (= undo).

**Apa sebenarnya dilakukan `MyKextInstaller` di dalamnya** (bisa langsung dilihat dari string di binernya, yang menunjukkan jalur ini dapat dipercaya):
deteksi versi KDK dan permintaan konfirmasi (`Do you want to install this compatible KDK now?`) → mengambil
`AppleHDA.kext` dari `/Library/Developer/KDKs/CurrentKDK/System` lalu memasangnya ke `/System/Library/Extensions`
(atau `/Library/Extensions`) → membuat backup lebih dulu (`Backup failed for … / Continue without backup?`) →
membangun ulang kernel collection (`Failed to rebuild caches:`) → meminta restart. Peningkatan hak akses dilakukan oleh **helper yang diinstal lewat SMJobBless**
(`com.mirone.MyKextInstaller.Helper`) ⇒ **tidak perlu `sudo` manual**.

### 0.5.4 Persyaratan (berlaku untuk kedua App)

| Item | Persyaratan |
|---|---|
| **KDK** (wajib) | ★★ **Di KDK untuk macOS 26 sama sekali tidak ada `AppleHDA`** —— di KDK 26.7.1 (build 25G241) tidak ditemukan file AppleHDA apa pun di seluruh disk ⇒ **jangan buang waktu dengan KDK versi yang sama**. **Kembali ke `Kernel Debug Kit 15.8.1 build 24H32` (Sequoia), versi terakhir yang masih membawa `AppleHDA.kext` (nomor versi 600.2)**. ★ **Habiskan 30 detik untuk memastikan sebelum mulai**: `ls /Library/Developer/KDKs/*.kdk/System/Library/Extensions/AppleHDA.kext`, jika file ini ada lanjutkan |
| **`AppleALC`** | **`≥ 1.9.5`**, diletakkan di `EFI/OC/Kexts/` **dan** ditulis di `config.plist` (seperti biasa) |
| **`csr-active-config`** | **`03080000`** (SIP **sebagian** dinonaktifkan) |
| **Sumber `AppleHDA.kext`** | Diambil dari **KDK**, path default `/Library/Developer/KDKs/<KDK versi-build>.kdk/System/Library/Extensions/AppleHDA.kext`; ★ berkas yang menyertai instalasi macOS 15 Sequoia juga bisa dipakai |
| **Lokasi pemasangan** | **`/System/Library/Extensions`** (lokasi yang terbukti berfungsi pada mesin contoh); `/Library/Extensions` juga bisa dimuat, tetapi **pilih salah satu, jangan dicampur**; setelah memasang, bandingkan byte per byte dengan sha256 berkas dari KDK (lihat §0.5.5) |

> ★ **Cermin KDK** tersedia di `laobamac/KdkSupportPkg` (lihat `laobamac-toolkit.md`).

### 0.5.5 Langkah dan verifikasi

1. Pasang / gabungkan **KDK** (pilih versi yang tepat, lihat §0.5.4)
2. Pastikan **`AppleALC ≥ 1.9.5`** sudah ada, **`csr-active-config = 03080000`**
3. Buka **MyKextInstaller** → pilih KDK → pilih `AppleHDA.kext` → pasang (akan **membangun ulang kernel collection**)
   - Padanan manual tanpa App: `hdiutil attach <KDK dmg>` → `cp -R AppleHDA.kext /System/Library/Extensions/`
     → `chown -R root:wheel` / `chmod -R 755` → `kmutil install --volume-root / --update-all` → restart
4. **Restart** —— tanpa restart tidak berlaku
5. **Verifikasi** (tiga, baru dianggap berhasil bila semuanya lolos):

```bash
# ① tiga entri kextstat ada, versinya konsisten
kextstat | grep "AppleHDA"
#   com.apple.driver.AppleHDAController            (600.2)
#   com.apple.driver.AppleHDA                      (600.2)
#   com.apple.driver.AppleHDAHardwareConfigDriver  (600.2)

# ② berkas yang berjalan di sistem identik byte per byte dengan yang di KDK (mencegah versi salah / pasang separuh)
shasum -a 256 /System/Library/Extensions/AppleHDA.kext/Contents/MacOS/AppleHDA
shasum -a 256 <KDK diekstrak dari>/AppleHDA.kext/Contents/MacOS/AppleHDA
# kedua sha harus sama

# ③ setelah restart masih tertahan di kernel collection (sistem mungkin membangun ulang collection dan membersihkannya)
strings -a /System/Volumes/Data/Library/KernelCollections/AuxiliaryKernelExtensions.kc \
  | grep -c "com.apple.driver.AppleHDA"     # >0 berarti ada di dalam collection
```

6. Audio onboard seharusnya pulih seperti di Sequoia dan sebelumnya ⇒ **baru setelah itu membahas `layout-id`** (mulai §1)

### 0.5.6 ★★ Batas dan peringatan (wajib dibaca)

- ★★ **Semua hilang begitu sistem di-upgrade / diinstal ulang** ⇒ **setiap kali harus memasang `AppleHDA.kext` lagi** (kalimat asli panduan di bagian Reminder).
  Ini **berbeda sama sekali** dari solusi sejenis "injeksi OpenCore" (`SimpleHDA` / `SimpleMtkWlan`) —— yang terakhir tidak perlu diterapkan ulang setelah pembaruan sistem.
- ★ **Ini adalah pelonggaran batas keamanan sistem yang disengaja** (SIP sebagian dinonaktifkan + menulis ke `/System/Library/Extensions`) ⇒ **tuliskan hal ini di laporan**,
  dan pertahankan jalur "undo lewat rollback snapshot di dalam App" sebagai pilihan.
- ★ **Jalur `SimpleHDA` (sebelumnya direkomendasikan di bagian ini) diturunkan menjadi pilihan cadangan** —— ini Lilu plugin "injeksi AppleHDA asli",
  keuntungannya **tidak perlu patch / tidak perlu matikan SIP / tidak menyentuh system volume / tidak butuh KDK**; tetapi hambatan nyatanya adalah:
  **pengarang menyatakan tidak mengikuti protokol open source apa pun dan melarang pengembangan lanjutan apa pun**, **sampai sekarang hanya ada `v1.0.0-alpha` tanpa versi resmi**
  (nama lampiran masih membawa short hash commit), dan ada masalah yang diketahui (login Books yang tidak normal, launch ulang di status bar).
  ⇒ **Kalau mau praktis, utamakan kartu suara USB; kalau mau memulihkan di dalam sistem, ikuti KDK + MyKextInstaller di bagian ini.**
- ★ **`SimpleVoodooHDA`** masih merupakan jalur cadangan (satu klik, cakupan kompatibilitas luas), tetapi **kualitas suara berkurang**; dan **pilih salah satu dari opsi lain, jangan dipasang bersamaan**.
  Indeks alat ada di `laobamac-toolkit.md`.

### 0.6 Menerapkan ke motherboard Anda: tabel penggantian

Semua nilai yang ditandai **"contoh"** di dalam dokumen berasal dari satu penerapan ALC897, ganti seluruhnya sesuai tabel berikut saat ganti mesin:

| Yang tertulis di dokumen (nilai contoh) | Ganti dengan milik Anda | Cara memperolehnya |
|---|---|---|
| Model codec / `CodecID` (`ALC897` / `0x0897`) | codec Anda | ID perangkat Windows, atau Linux `/proc/asound/card*/codec#0` |
| Path controller (`PciRoot(0x0)/Pci(0x1F,0x3)`) | path controller Anda | Device Manager Windows / `gfxutil -f HDAS` (atau `-f HDEF`) |
| Nama ACPI controller (`HDAS`) | nama Anda | Konfirmasi dari sisi Windows; **jangan diubah**, biarkan AppleALC yang menyesuaikan |
| `layout-id` (14) | ID bebas yang belum terpakai | Lihat daftar ID yang ada di `Resources/<codec>/Info.plist` (custom hanya boleh 11–99) |
| Nomor node (`0x14` / `0x18` / …) | nomor node codec Anda | codec dump (§3.0) |
| Path di dalam `PathMap` | hubungan koneksi codec Anda | Tabel koneksi + kemampuan Amp (§3.0) |
| Nilai pin config | nilai motherboard Anda | **Ekspor HDAU Windows + verifikasi baca-balik register** (batasan keras, §3.0.1) |
| Urutan perangkat / pemetaan nama di App | Buat ulang mengikuti nomor seri engine UID Anda | §3.9 |

**Coba yang siap pakai lebih dulu, jangan langsung menulis sendiri** (kalimat asli panduan §0.4, dan juga langkah yang paling menghemat waktu):

1. Periksa apakah di `AppleALC/Resources/` ada direktori codec Anda (cari berdasarkan `CodecID`);
2. Jika ada ⇒ coba layout siap pakai satu per satu: `alcid=N`, setelah setiap restart verifikasi dengan cara di §5;
3. Baru jika semuanya tidak cocok, tulis yang baru sendiri mengikuti §3.

> Layout siap pakai sering ditulis untuk motherboard lain, jadi definisi jack yang tidak cocok adalah hal wajar; tetapi satu putaran percobaan jauh lebih cepat dan jauh lebih mudah daripada menulis dari nol.
> **Kecualikan jalur ini dulu sebelum mulai bekerja.**

## 1. Tentukan model codec, revision, dan status saat ini

| Lingkungan | Cara memperoleh informasi codec |
|---|---|
| Linux | `cat /proc/asound/card0/codec#0` (**sumber dump paling lengkap**) |
| Windows | Device Manager → Kontroler suara → ID perangkat; atau halaman perangkat audio AIDA64 |
| macOS | `ioreg -l \| grep -i IOHDACodecVendorID`, `ioreg -r -c IOHDACodecDevice` |
| Mencari path perangkat | `gfxutil -f HDEF` (**perhatikan perangkat audio lokal mungkin bernama `HDAS`**, lalu gunakan `gfxutil -f HDAS`) |

Empat hal yang perlu dicatat: **nama codec** (misalnya `ALC897`), **`IOHDACodecRevisionID`**, **model motherboard**, **versi macOS target**.

## 2. Jalur A: cari pengalaman orang sebelumnya (disarankan)

Cari sesuai urutan, berhenti begitu ketemu:

1. **Tabel dukungan resmi**: `Supported-codecs` di wiki AppleALC
   —— kolom tabelnya `Vendor | Codec | Revisions and layouts | MinKernel | MaxKernel`,
   setiap codec tertaut ke `Resources/<CODEC>/Info.plist`, sehingga **layout-id yang sudah ada** langsung terlihat.
   Tabel dibuat oleh `Tools/wiki_table.command` resmi (versi saat ini terlihat di judul halaman, misalnya `v1.9.8 2026-09-30`).
2. **Cari issue / PR di repositori AppleALC**:
   ```
   repo:acidanthera/AppleALC ALC897
   repo:acidanthera/AppleALC ALC897 Z690
   ```
   Banyak layout baru mula-mula ada dalam bentuk **PR**, jangan hanya melihat yang sudah di-merge.
3. **Cari "model motherboard + layout-id"**: seluruh situs GitHub (code / issues), bugtracker Dortania, forum hackintosh.
   Postingan untuk motherboard yang sama biasanya langsung memberikan "model + versi macOS + `alcid=N` + port mana yang berfungsi".
4. **"Fixing Audio with AppleALC" dari Dortania**: dokumen pengantar yang diakui resmi, menjelaskan urutan injeksi `layout-id` dan troubleshooting.
5. ★ **`Codec_Dumps/` milik `5T33Z0/AppleALC-Guides`**: **17 dump siap pakai** (ALC1220/215/255/257/265/269/292/295/3246/671/887/892/ALCS1200A ·
   Conexant CX20751-2/CX8050 · IDT 92HD99BXX · VIA VT2020), masing-masing membawa **`verbs.txt` + versi desimal + diagram topologi `.svg`**
   ⇒ **Jika codec Anda kebetulan ada di sana, mulailah langsung dari diagram node/routenya**, sekaligus menghilangkan langkah memasang Linux.

Setelah ketemu: **ubah hanya satu hal, yaitu `alcid=<N>`**, restart lalu dengarkan/lihat hasilnya, baru coba N berikutnya. Jangan mengubah banyak variabel sekaligus.

**Contoh · Menjalankan ALC897 dengan alur ini** (memperagakan "cara menilai apakah yang siap pakai cukup"):
di upstream `Resources/ALC897/Info.plist` ada 13 layout, tapi tidak satu pun untuk motherboard target (ASUS TUF Z690-PLUS WIFI D4):

| layout | Papan target | layout | Papan target |
|---|---|---|---|
| 11 / 12 | GIGABYTE Z590M / Z590 Gaming X | 22 | Asus VivoBook 15 OLED M513UA |
| 13 | MSI-Z590-A-PRO | 23 | Chuwi CoreBookX14 |
| 21 | OPS all-in-one | 31 | MSI X670E GAMING WIFI |
| 66 | Asus PRIME B460M-K | 69 | MSI Z490-A-PRO |
| 77 | ONDA H510D4 IPC | 97 | B560M TUF Gaming Plus |
| 98 | MSI PRO B760M-P DDR4 | 99 | HUANANZHI QD4 |

Papan yang paling baru (97 = B560M TUF, 66 = PRIME B460M-K, 69 = Z490-A-PRO) semuanya layak dicoba lebih dulu;
**baru bila semuanya sudah dicoba dan definisi jack tetap tidak cocok, lanjut ke jalur B** (mesin contoh akhirnya membuat layout baru nomor 14).

## 3. Jalur B: kustomisasi per codec ("Adding codec support" di wiki resmi)

Kalimat asli resmi: *"This task is fairly simple and requires no programming skills. In short you are meant to edit a few plists, copy the necessary files, and rebuild the kernel extension using Xcode."*

### 3.0 ★★ Referensi praktis utama: `5T33Z0/AppleALC-Guides` (wiki resmi menjelaskan **aturan**, dokumen ini menjelaskan **cara**)

> <https://github.com/5T33Z0/AppleALC-Guides> (★66, **BSD-3-Clause**, dibuat 2022-07, masih diperbarui).
> **Wiki resmi adalah spesifikasi, sedangkan ini adalah panduan praktis lengkap 14 bab** (dari dump → diagram topologi → PathMap → PinConfig → kompilasi → pengujian → mengajukan PR).
> ⇒ **Saat memakai jalur kustomisasi, baca berdampingan dengan wiki resmi**: gunakan aturan resmi untuk menilai "bisa atau tidak", lalu gunakan langkah-langkahnya untuk mengerjakan.

**Peta 14 babnya** (korespondensi dengan 6 langkah resmi):

| Bab | Isi | Korespondensi resmi |
|---|---|---|
| I | Summary (**pertanyakan dulu "yakin mau dikerjakan?"**) | — |
| II | Preparations: **ambil codec dump** · alat · siapkan sumber kode · **konfigurasi Xcode** | Prasyarat 6 langkah resmi |
| III | **Ambil data dari dump** (`Relevant Codec data`: model Codec / Address / Vendor Id(= `CodecID`) / node Pin Complex / kemampuan routing) | Langkah 1 |
| IV | **Memahami diagram topologi dan aliran sinyal** (cara mencari jalur yang mungkin) | Langkah 2 |
| V | **Membuat PathMap** · struktur `PlatformsXX.xml` (★ lihat §3.7) | Langkah 2–3 |
| VI–VII | Menghasilkan `PlatformsXX.xml` · **memindahkan PathMap ke dalamnya** · **kemampuan Amp (sisi Input/Output)** · pengaturan Amp yang umum dipakai | Langkah 3 |
| VIII | **Mengubah/membuat `layoutXX.xml`** · **perhitungan `MuteGPIO` (lihat §3.6)** | Langkah 4 |
| IX | **Membuat PinConfig** (metode bawaan PinConfigurator / cara mengubah / dua cara menambah node / penjelasan jendela Edit Node item per item) | Langkah 5 |
| X | **Menggabungkan PinConfig ke dalam sumber kode** · **mencari nomor Layout-ID yang belum dipakai siapa pun** | Langkah 6 |
| XI–XII | Menulis `Platforms.xml`/`layout.xml` ke dalam `info.plist` · **mengompilasi kext** | — |
| XIII | **Pengujian dan troubleshooting** | — |
| XIV | **Mengirim Layout Anda ke repositori AppleALC** | §6 |

**★ Aset siap pakai di repositori (bagian yang paling menghemat waktu)**:

| Direktori | Isi |
|---|---|
| **`Codec_Dumps/`** | ★★ **17 dump siap pakai**: ALC1220 · ALC215 · ALC255(3234) · ALC257 · ALC265 · ALC269 · ALC292(ThinkPad X250) · ALC295(Dell G15 5515 / ThinkPad X1 Tablet) · ALC3246 · ALC671 · ALC887 · ALC892 · ALCS1200A · **Conexant CX20751-2 / CX8050** · **IDT 92HD99BXX** · **VIA VT2020**; masing-masing berisi `codec_dump.txt` + **versi desimal** + **`verbs.txt`** + **diagram topologi `.svg`** |
| `AppleALC_Layout-ID/alc-verb_explained.md` | ★★ **Penetapan audio runtime `alc-verb`** (tanpa kompilasi ulang, tanpa restart) ⇒ §3.5 |
| `AppleALC_Layout-ID/Tools/` | `Codec-Graph.zip` · `Codec-Info.zip` · `GetDumpXML.zip` · `graphviz-2.40.1.pkg` |
| `Slimming_AppleALC/` | ★ **Mengoptimalkan AppleALC dari 3.8 MB menjadi ~90 KB (-97%)** ⇒ §4.5 |
| `File_Management/` | Alur kerja backup multi-versi / rollback ⇒ §4.5 |
| `AppleALC_Layout-ID/Testing_Notes.md` | **Template catatan pengujian** (PinConfig / EAPD / Routing / hasil tiap jack dicatat satu per satu) |
| `AppleALC_Layout-ID/Dumping_Audio_Codec_OpenCore.md` | **Cara dump tanpa memasang Linux** ⇒ di bawah |

**★ Tiga cara mengambil codec dump / pin config (diagram topologi hanya bisa dari versi Linux)**:

| Cara | Langkah | Batasan |
|---|---|---|
| **① Linux (disarankan)** | Ventoy untuk membuat media boot → boot distro apa pun dalam mode "Try" → kumpulkan dengan satu perintah:<br>`cd ~/Desktop && mkdir CodecDump && for c in /proc/asound/card*/codec#*; do f="${c/\/*card/card}"; cat "$c" > CodecDump/${f//\//-}.txt; done && zip -r CodecDump.zip CodecDump` | ★ **Hanya dump dari Linux yang bisa menghasilkan diagram topologi** (Clover / OpenCore tidak bisa) |
| **② OpenCore** | Ganti ke OpenCore versi **DEBUG** (termasuk Drivers namesake) → `Misc>Debug>SysReport=true` · `UEFI>ConnectDrivers=true` · `UEFI>Drivers` tambahkan **`AudioDXE.efi`** → restart (sedikit lebih lambat) → di root ESP muncul `SysReport/Audio/` → **kembalikan ke RELEASE dan matikan kedua sakelar itu** | Tidak mendapat diagram topologi, **hanya untuk keadaan darurat** |
| **③ Windows (dua sub-jalur)** | Lihat §3.0.1 —— **batasan keras jalur B, wajib dilalui sebelum kustomisasi**: jalur GUI memakai `HDAU.exe`; jalur skrip memakai **`HDAudDev.dll` koneksi langsung** (tanpa admin, bisa dipakai dalam skrip, menghasilkan `codec_dump.txt/.json` bergaya Linux) | Tidak ada diagram topologi (`codec_dump.txt` dari jalur skrip bisa langsung dimasukkan ke Codec-Graph, lihat di bawah) |

### 3.0.1 ★★★ Batasan keras: sebelum mulai jalur B, harus sudah ada data lengkap dari Windows

**Urutan pengerjaan (tanyakan dulu, baru bekerja)**:

```
Masuk ke jalur kustomisasi
  ├─ ① Tanyakan dulu ke pengguna: apakah bisa menyediakan data dari sisi Windows (checklist 1–4 di bawah)
  │     ├─ bisa ⇒ langsung masuk §3 untuk menulis layout, pakai data yang ia berikan (jangan suruh dia jalankan Windows lagi)
  │     └─ tidak   ⇒ jelaskan batasan keras + berikan langkah HDAU, ambil semua lalu kembali
  └─ ② Setelah data diperoleh, cocokkan field sesuai §3.10, baru mulai menulis
```

**Mengapa ini batasan keras**: `PlatformsXX.xml` / `layoutXX.xml` / pin config yang akan ditulis semuanya dibangun berdasarkan **data ini**,
dan kalau satu bagian hilang harus dikerjakan ulang. Dari tiga jenis data, yang paling merepotkan adalah **semantik jack** (jack mana yang headphone, mana yang mikrofon, mana yang punya deteksi 삽입)
yang paling mudah dikonfirmasi di Windows —— hal itu diturunkan dari empat fakta hardware di bawah ini, sisi macOS tidak bisa melihat "label silkscreen".

**Sebelum mulai bekerja, Anda harus punya checklist ini (jangan mulai kalau ada satu yang kurang)**:

| # | Data | Sifat | Apa yang diperoleh |
|---|---|---|---|
| 1 | **Pohon node codec lengkap** (tipe tiap node / tabel koneksi / kemampuan Amp) | Fakta hardware | Dasar penulisan PathMap: node mana yang membentuk satu jalur |
| 2 | **Pin Config Default 32-bit untuk tiap pin** | Fakta hardware (BIOS menulis ke register) | Dasar penulisan `PinConfigs.kext`: mana output, mana mikrofon, mana yang punya deteksi |
| 3 | **EAPD** | Fakta hardware | Akar sebagian codec yang tidak mengeluarkan suara |
| 4 | **Tabel semantik jack**: mana headphone / mikrofon / line, warna + label panel | Diturunkan dari 1–3 | Urutan pengelompokan dan checklist penerimaan |
| 5 | `CodecID` / `Revision` codec serta path controller dan nama ACPI | Informasi identitas | `Info.plist` dan DeviceProperties |

**Langkah prasyarat: pastikan codec sudah diaktifkan** —— ketika codec dinonaktifkan tidak ada antarmuka yang ter-enumerasi, dan skrip akan langsung memberi tahu "tidak ada antarmuka yang ter-enumerasi":

```bat
:: ProblemCode 22 = dinonaktifkan (ganti InstanceId dengan nilai lokal sebenarnya)
pnputil /enum-devices /instanceid "HDAUDIO\FUNC_01&VEN_10EC&DEV_0897&SUBSYS_…&REV_…\4&…&0&0001"
:: Jika dinonaktifkan, aktifkan (tindakan ini bisa dibatalkan)
pnputil /enable-device "<InstanceId di atas>"      :: butuh admin, atau klik kanan "aktifkan perangkat" di Device Manager
```

**Jalur ① GUI (HDAU / Intel HD Audio tool)**:

1. Device Manager → Sound, video and game controllers → cari perangkat yang ID perangkatnya memuat codec target (contoh: `VEN_10EC&DEV_0897`)
2. Buka `HDAU.exe` (di dalam paket `HdauSetup.msi`) → `File → Local Machine Codecs` → pilih codec onboard ⇒ muncul pohon node lengkap
3. Ekspor (langkah ini adalah 1–3 dari checklist di atas):
   - `File → Save Working Codec As...` → pohon node codec lengkap (XML)—— **node, tabel koneksi, kemampuan Amp**
   - `File → Export PinConfig Settings As...` → pin config (tiga format: registry / BIOS / inf, ambil **Pin Config Default 32-bit**)
   - `File → Export PinConfig Settings with system specific name` → langsung menghasilkan `.reg` di direktori kerja saat ini, sekali jadi

**Jalur ② skrip (`HDAudDev.dll` koneksi langsung, tanpa admin, bisa dipakai dalam skrip, menghasilkan dump bergaya Linux)** ★ gunakan jalur ini bila perlu ekspor berulang / ingin masuk CI:

HDAU 3.3 resmi Microsoft sudah membawa pustaka native **`HDAudDev.dll`**, dan beberapa fungsi yang diekspornya bisa langsung mengirim HDA verb ke codec.
Dengan melewati GUI dan hanya memanggil DLL ini, Anda memperoleh data topologi yang **setara** dengan `/proc/asound/card*/codec#*` di Linux.
Dependensinya hanya **Python 3 standard library + `HDAudDev.dll`**, **tidak perlu hak administrator**.

```bat
:: Ambil DLL (paket alat resmi Microsoft): ambil hdausetup_x64.msi → keluarkan cab yang tertanam dari tabel _Streams MSI → ekstrak
C:\Windows\System32\expand.exe -F:* hdau.cab out\
:: di out\ diperoleh HDAU.exe / HDAudDev.dll / Topo.dll / Config.xml
:: letakkan HDAudDev.dll dan skrip dump di direktori yang sama, skrip memuatnya otomatis saat dijalankan

python hda_codec_dump.py --probe                :: probe verifikasi koneksi: daftar antarmuka privat→buka→baca VendorId
python hda_codec_dump.py --out <nama dasar path>        :: dump lengkap: tulis <base>.txt + <base>.json
python hda_codec_dump.py --only 10EC0897        :: dump hanya codec dengan VendorId tertentu
python hda_codec_dump.py --nvidia               :: dump sekalian dengan codec HDMI (tidak dipakai AppleALC)
```

- **`codec_dump.txt` bergaya Linux codec_dump** ⇒ bisa **langsung dimasukkan ke `Codec-Graph.py`** untuk menghasilkan diagram topologi;
  `codec_dump.json` adalah versi yang dapat dibaca mesin (mengandung nilai mentah 32-bit tiap field);
- **Di akhir skrip akan tercetak otomatis tabel ringkasan Pin Complex** (NID / Pin Default / tipe perangkat / posisi / warna / grup asosiasi / nomor)⇒ saat membuat layout, cukup consult tabel ini;
- **Tampilan probe yang berhasil**: `GrabDeviceHandle=True` dan VendorId yang terbaca adalah codec target (misalnya `0x10EC0897`).

**Urutan pemanggilan inti** (ikuti ini bila menulis skrip sendiri, tiga langkah):

```python
import ctypes
from ctypes import wintypes as wt

dll = ctypes.WinDLL("HDAudDev.dll")
dll.GrabDeviceHandle.argtypes = [ctypes.c_wchar_p];  dll.GrabDeviceHandle.restype = ctypes.c_bool
dll.SendVerbLong.argtypes     = [ctypes.c_uint32];   dll.SendVerbLong.restype  = ctypes.c_int64
dll.ReleaseDeviceHandle.argtypes = [];               dll.ReleaseDeviceHandle.restype = None

GUID_PRIVATE = "{A17579F0-4FEC-4936-9364-249460863BE5}"   # kelas antarmuka privat HD Audio (konstanta publik Microsoft)
GUID_KS      = "{6994AD04-93EF-11D0-A3CC-00A0C9223196}"   # kelas media KS (topologi endpoint, konstanta publik Microsoft)

# ① SetupAPI mengenumerate path antarmuka perangkat lengkap (DIGCF_PRESENT|DIGCF_DEVICEINTERFACE = 0x02|0x10)
#    di x64 cbSize pada SetupDiGetDeviceInterfaceDetailW harus diisi 8; string dimulai dari buf+4
# ② GrabDeviceHandle(path) → True; verb(0x00, 0xF00, 0x00) → 0x10EC0897
# ③ node root → function group → iterasi widget:

def verb(nid, verb12, payload=0, codec=0):
    v = ((codec & 0xF) << 28) | ((nid & 0xFF) << 20) | ((verb12 & 0xFFF) << 8) | (payload & 0xFF)
    return int(dll.SendVerbLong(ctypes.c_uint32(v))) & 0xFFFFFFFF

fg_type   = verb(nid,   0xF00, 0x05)          # 0x01 = Audio Function Group
w_start, w_count = verb(fg_nid, 0xF00, 0x04)  # 16-bit atas=NID awal, 16-bit bawah=jumlah
wcaps     = verb(wid,   0xF00, 0x09)          # type = (wcaps >> 20) & 0xF

if (wcaps >> 20) & 0xF == 4:                  # Pin Complex
    pin_default = verb(wid, 0xF1C, 0x00)      # Pin Config Default 32-bit
    pin_caps    = verb(wid, 0xF00, 0x0C)
    eapd        = verb(wid, 0xF0C, 0x00)      # 0x2 = EAPD aktif

n = verb(wid, 0xF00, 0x0E) & 0x7F             # Connection List: dibaca per 4 tegak
for base in range(0, n, 4):
    word = verb(wid, 0xF02, base)
    conns += [(word >> (8*k)) & 0xFF for k in range(4)]
```

> ★★ **Saat mengekspor, wajib kecualikan codec HDMI dari kartu grafis** (pada mesin contoh `10DE:009A`)—— codec ini juga muncul di daftar codec,
> **mengambil yang salah akan menghasilkan pohon node yang sama sekali tidak relevan.**
>
> ★ **Yang diekspor Windows adalah nilai dari sudut pandang driver/BIOS, disarankan melakukan verifikasi baca-balik register sekali** (minimal periksa ulang pin yang diubah):
>
> ```bash
> # Linux Live USB: lihat konfigurasi bawaan pin secara langsung
> grep -A2 "Node 0x14" /proc/asound/card0/codec#0
> #   Pin Default 0x01014010: [Jack] Line Out at Ext Rear
> #   Conn = 1/8, Color = Green
> # macOS (AppleALC sudah dimuat, alc-verbs sudah aktif): baca empat byte Pin Config Default
> alc-verb 0x14 0xF1C 0x00 | tail -1     # F1Dh/F1Eh/F1Fh mengambil sisa tiga byte
> ```
>
> ★★ **Jalur cadangan saat Windows tidak tersedia (ingat biayanya)**: `/proc/asound/card0/codec#0` pada Linux Live USB
> juga memuat Pin Default dan tabel koneksi, **dan itulah satu-satunya sumber yang bisa menghasilkan diagram topologi** (toolchain diagram topologi hanya mengenali itu);
> `SysReport` OpenCore hanya bisa dipakai untuk keadaan darurat, tidak bisa mendapat diagram topologi.
> ⇒ **Setelah mengambil data secara cadangan, "jack mana cocok dengan label silkscreen mana" tetap harus dikonfirmasi dengan satu mesin Windows (atau lihat manual motherboard + pengukuran nyata)**, jangan lewati item 4 pada checklist.

### 3.0.2 Validasi silang: biarkan Windows sendiri membuktikan "pin mana untuk lubang mana di panel"

Setelah dump keluar dan Anda masih belum tahu "pin mana cocok dengan lubang mana", **jangan menebak**——antarmuka topologi KS yang dibangun Windows sendiri akan menuliskan jawabannya.
Gunakan fungsi enumerasi yang sama untuk mengenumerate GUID **kelas media KS**, lalu ambil refstring di ujung path antarmuka:

```python
paths = enum_interfaces(GUID_KS)                  # fungsi enumerasi yang sama, ganti GUID
refs  = [p.rsplit("\\", 1)[-1] for p in paths if "0897" in p.lower()]
# -> eheadphonetopo / elineouttopo / emicintopo / emixedcapturetopo / espdifouttopo / espdifoutwave
```

| Endpoint Windows | pin yang sesuai | Arti |
|---|---|---|
| `elineouttopo` | 0x14 | endpoint output line utama |
| `eheadphonetopo` | 0x1b | headphone |
| `espdifouttopo` / `espdifoutwave` | 0x1e | output optik S/PDIF |
| `emicintopo` + `emixedcapturetopo` | 0x18 / 0x19 / 0x1a | mikrofon + rekaman campuran (**input digabung menjadi satu kelompok**) |

**Tiga aturan pembacaan yang bisa langsung disalin**:

1. **Jika di sisi playback muncul beberapa `e*outtopo`, berarti ada beberapa endpoint output mandiri** —— banyak pin dalam grup DefAssociation yang sama
   (misalnya L/R, surround belakang, center subwoofer pada 5.1) **hanya membuat satu endpoint**, dan ini langsung memvalidasi pengelompokan grup asosiasi;
2. **Di sisi recording umumnya ada satu `emicintopo` + satu `emixedcapturetopo`** ⇒ driver menggabungkan beberapa input
   ⇒ **di `PlatformsXX.xml` AppleALC pun input sebaiknya hanya memilih satu kelompok** (bersumber dari kesimpulan §3.8 juga);
3. Endpoint `NOTPRESENT` = **tidak ada perangkat yang terpasang di jack** (presence detect kosong), **bukan kerusakan**;
   output S/PDIF tidak memiliki presence detect, selalu `ACTIVE`.

★ **Dua jebakan yang wajib diketahui**:
1. **Nama file harus diubah menjadi `codec_dump.txt`**, jika tidak skrip konversi akan gagal;
2. Saat sistem memiliki audio digital HDMI/DP akan ada **beberapa dump** —— **`Codec0.txt` itulah kartu suara**, sisanya milik kartu grafis (jika di awal tertulis AMD/NVIDIA/Intel berarti bukan kartu suara).

**★ Menghasilkan diagram topologi (Codec-Graph)**: pasang graphviz (`sudo port install graphviz` atau `brew install graphviz`) →
gunakan `Codec-Graph` **versi Python3 dengan GUI milik Core-i99** (`python3 Codec-Graph.py`) → pilih `codec_dump.txt` →
menghasilkan **versi desimal + diagram topologi `.svg`** (★ **selalu pakai versi desimal setelah ini**, karena yang diisi di `.xml` AppleALC adalah desimal).

### 3.1 File yang perlu diubah (semua di dalam `Resources/`)

| File | Peran | Perlu diubah biasanya? |
|---|---|---|
| `Vendors.plist` | Array asosiasi nama vendor + id | Umumnya tidak |
| `Kexts.plist` | kext yang akan di-patch (`Id` = CFBundleIdentifier, `Paths` = kemungkinan lokasi) | Ditambahkan bila perlu |
| `CodecLookup.plist` | **Mendeteksi codec lewat path IORegistry**: `Tree` (mulai dari `IOService:/PCI/AppleACPIPlatformExpert`, **item terakhir** memuat `IOHDACodecVendorID` / `IOHDACodecRevisionID`), `controllerNum` (indeks path yang memuat properti controller seperti `layout-id`), `Detect` (apakah codec dicari di item terakhir; ** simulator controller seperti Realtek diisi YES**) | Ditambahkan hanya bila path tidak cocok |
| `Controllers.plist` | Mengubah controller audio secara global (termasuk HDMI): `Vendor` / `Device` / `Name` / `Platform` / `Revisions` / `Patches[]` | Ditambahkan bila perlu |
| `Resources/<CODEC>/` | **Satu direktori per codec**, berisi `Info.plist` + berkas layout/platform | ★ Pekerjaan utama ada di sini |

> ★★ **pin config tidak berada di `Resources/<CODEC>/Info.plist`** —— berkas itu hanya punya
> `Author` / `CodecID` / `Files` / `Patches` / `Revisions` / `Vendor`, **tidak ada data pin config sama sekali**.
> Data yang sebenarnya berada di dalam **`Resources/PinConfigs.kext/Contents/Info.plist`**, pada
> array `IOKitPersonalities['as.vit9696.AppleALC'].HDAConfigDefault`, **diindeks berdasarkan `CodecID` + `LayoutID`**.
> ⇒ Mengubah berkas yang salah = satu putaran kerja sia-sia, dan ini jebakan yang sering terjadi kedua pada jalur kustomisasi.

**Struktur direktori `Resources/<CODEC>/` (contoh)**:

```
Resources/
├── PinConfigs.kext/Contents/Info.plist   ★ pin config ada di sini (diindeks CodecID+LayoutID)
└── ALC897/
    ├── Info.plist                        hanya mendaftarkan "layout/platform apa saja yang ada" dan path kedua berkas
    ├── layout14.xml                      deklarasi tipe perangkat (Inputs/Outputs, MuteGPIO…)
    ├── Platforms14.xml                   PathMap (node mana yang membentuk satu jalur, bagaimana pengelompokannya)
    ├── layout14.xml.zlib                 dihasilkan saat build (di-gitignore)
    └── layout14.xml.md5                  dihasilkan saat build (di-gitignore)
```

### 3.2 Field `Info.plist` di direktori codec (checklist resmi)

- `Vendor` (diambil dari `Vendors.plist`)
- `CodecID` —— **2 byte bawah dari `IOHDACodecVendorID`**
- `CodecName` —— nama untuk dibaca manusia (dipakai di log)
- `Revisions` —— array `IOHDACodecRevisionID` yang didukung (opsional; dikosongkan = revision tidak diverifikasi)
- `Author` —— Whoever mengubah (opsional)
- `Files`
  - `Platforms[]`: `Id` (= layout-id), `Path`, `MinKernel` / `MaxKernel` (opsional)
  - `Layouts[]`: sama seperti di atas
- `Patches[]`: `Count` / `Find` / `Replace` / `Name` (diambil dari `Kexts.plist`) / `MinKernel` / `MaxKernel`

### 3.3 Algoritma 6 langkah resmi (memerlukan Xcode)

1. Lihat apakah `Vendors.plist` punya vendor Anda, kalau tidak tambahkan
2. Lihat apakah kext yang akan di-patch ada di `Kexts.plist`, kalau tidak tambahkan
3. **Verifikasi path `IOHDACodecVendorID` / `IOHDACodecRevisionID` / `layout-id` di IORegistry**, tambahkan ke `CodecLookup.plist` bila perlu
4. Buat direktori codec di dalam `Resources/`, salin berkas layout/platform ke sana
5. Tulis `Info.plist` sesuai §3.2
6. **Bangun ulang kext** (lihat §4)

### 3.4 ★ Aturan penomoran dan komentar sumber daya (aturan keras resmi, PR akan ditinjau berdasarkan ini)

- **Layout 1–10 dicadangkan untuk patch dasar Mirone / Toleda**, jangan dipakai:
  - codec desktop: Layout **1, 2, 3** = Toleda; Layout **5, 7** = Mirone
  - codec laptop: Layout **1–8** = Mirone
- **Layout custom pengguna = 11–99**
- **Jangan memasukkan sumber daya Toleda/Mirone sebagai sumber daya custom di rentang 11–99** (alasan resmi: menghindari duplikasi, memperkecil ukuran kext)
- **Setiap platform / layout baru harus diberi komentar** (di `Info.plist` codec dan di `PinConfigs`):
  nama codec yang terbaca manusia + nama penulis (Mirone / Toleda / Custom); **untuk Custom wajib menyebut model (laptop atau motherboard) dan nama Anda**

### 3.5 ★★ `alc-verb`: penyetelan audio runtime (**tanpa kompilasi ulang, tanpa restart**)

> Sumber: `AppleALC_Layout-ID/alc-verb_explained.md`. **Ini alat paling menghemat waktu di seluruh panduan** ——
> siklus "ubah XML → kompilasi ulang kext → restart → dengarkan" dipadatkan menjadi "ketik satu baris perintah → langsung dengarkan".

**Prasyarat**:

1. `AppleALC.kext` + `Lilu.kext` **benar-benar dimuat**: keduanya harus terlihat di `kextstat | grep -v com.apple`;
2. ★ **Hapus komponen yang konflik** —— **`VoodooHDA` membuat AppleALC sama sekali tidak berfungsi** (begitu pula `CodecCommander` lama);
3. **Aktifkan dukungan verb** (pilih salah satu):
   - **boot-arg**: `alcverbs=1` (tulis bersama `alcid=XX`)
   - **DeviceProperties** (lebih bersih): tambahkan **`alc-verbs = 1`** pada path HDEF (misalnya `PciRoot(0x0)/Pci(0x1f,0x3)`)
4. **Punya codec dump** (perlu tahu NID node target, kemampuan Amp-In/Out, nilai `Pin-ctls` saat ini)

**Sintaks dan verb yang umum dipakai**:

```bash
alc-verb <NID> <verb> <parameter>      # contoh: alc-verb 0x19 0x707 0x40
```

| verb | Fungsi |
|---|---|
| **`0x707`** | **Set Pin Widget Control** (mengaktifkan pin / mengatur arah) |
| **`0xF07`** | **Get Pin Widget Control** (membaca status saat ini, termasuk bias VREF, lihat §3.10) |
| `0x709` / **`0xF09`** | **Set / Get Pin Sense** (deteksi keberadaan; `0xF09` semua 0 = deteksinya mati, §5.6) |
| `0x708` | Set Unsolicited Response (deteksi jack) |
| `0x500` | Set Coefficient Index (mengalamatkan koefisien pemrosesan) |
| `0x4XX` | Set Processing Coefficient (menulis nilai koefisien) |
| `0xF06` | Get Converter Stream/Channel (**saat sampling, lihat apakah DAC ini punya aliran**, §5.7) |
| `0xF1C–0xF1F` | Get empat byte Pin Config Default (baca balik per byte, §3.0) |
| **`0xF00` + payload** | **Get Parameter** (jalur skrip Windows bergantung pada ini untuk menelusuri seluruh pohon, §3.0.1): `0x00` VendorID (misalnya `0x10EC0897`) · `0x02` RevisionID · `0x04` NodeCount (16-bit atas=NID awal / 16-bit bawah=jumlah) · `0x05` FunctionGroupType · `0x08` AFG Caps · `0x09` Widget Caps (**type = `caps>>20 & 0xF`, 4 = Pin Complex**) · `0x0C` Pin Caps · `0x0D` / `0x12` Amp-In / Amp-Out Caps · `0x0E` Conn List Length (7 bit bawah) |
| **`0xF02` + basis grup** | Get Connection List Entry (**mengembalikan 4 entry sekaligus**) |
| **`0xF0C`** | Get EAPD/BTL (`0x2` = EAPD aktif) |

Opsi: `-d <int>` memilih nomor codec (default 0, dipakai saat ada beberapa codec) · `-l` / `-L` menampilkan daftar verb · `-q` senyap.

**Alur kerja empat langkah**:

1. **Baca kondisi sekarang**: `alc-verb 0x19 0xF07 0x00`
2. **Coba**: `alc-verb 0x19 0x707 0x40` ⇒ **langsung** dengarkan di "Pengaturan Suara" atau app pemutar suara (**tanpa restart**)
3. **Iterasi**: catat **kata demi kata** setiap perintah yang "efektif" (akan dipakai nanti)
4. **Kunci** (pilih salah satu):
   - ★ **Disarankan**: tulis urutan verb ke dalam **`WakeConfigData`** pada entri yang sesuai di `PinConfigs.kext` —— inilah cara resmi AppleALC, **secara alami tahan terhadap restart**
   - **Khusus jack gabungan** (ALC255/256/295/298): `WakeConfigData` **tidak bisa menangani event plug/unplug** ⇒ pakai **`ALCPlugFix-Swift`** untuk memasang daemon yang mengirim ulang verb saat event deteksi jack terjadi

**★ Contoh nyata: ALC255 (Layout 66) headphone tersambung tapi tidak bersuara**

```bash
alc-verb 0x20 0x500 0x45   # pilih indeks koefisien 0x45
alc-verb 0x20 0x4d4 0x89   # tulis koefisien: aktifkan mode headphone
alc-verb 0x20 0x500 0x1b   # pilih indeks koefisien 0x1b
alc-verb 0x20 0x40c 0x2b   # tulis koefisien: konfigurasi mic bias
alc-verb 0x57 0x500 0x03   # node 0x57 pilih indeks koefisien 0x03
alc-verb 0x57 0x48e 0xa6   # tulis koefisien: aktifkan deteksi headphone
```

Konfirmasi ada sinyal di "Pengaturan Suara → Input" ⇒ lalu kunci sesuai langkah 4 di atas.

**★ Metode pembanding yang lebih keras: `dump_coeff.sh`** (bawaan di sumber kode AppleALC, folder `Scripts/`)

```bash
./dump_coeff.sh 0 0x20 80      # codec 0, node 0x20, baca 80 koefisien
```

**Jalankan sekali di sistem yang bekerja (Linux / Windows), jalankan sekali lagi di macOS yang bermasalah, lalu diff** ——
**koefisien apa yang berbeda itulah verb yang perlu Anda kirim**. Jauh lebih cepat daripada menebak.

**★ Tiga jebakan**:
1. **`alc-verb` tidak ada di release zip** —— ia dikompilasi bersama kext, produknya ada di `AppleALC/build/Release/`;
2. ★★ **`-alcdbg` / `-liludbg` hanya berlaku pada build DEBUG**, **biner release sama sekali mengabaikan parameter ini** (untuk mendapat output debug Anda harus mengompilasi versi Debug sendiri);
3. Perintah tidak merespons ⇒ periksa dulu apakah `alcverbs=1` berlaku, apakah kext benar-benar dimuat, dan apakah ada komponen konflik seperti VoodooHDA.

### 3.6 ★ Tabel cepat `MuteGPIO` (salin langsung nilai desimal)

`MuteGPIO` di `layoutXX.xml` harus dipilih sesuai cara **IN VREF** codec (50% / 80%):

| NodeID | VREF=50%(Dec) | VREF=80%(Dec) | VREF=?%(Dec) |
|---|---|---|---|
| 20 | **838926356** | **1342242836** | **1677787156** |
| 21 | **838926357** | **1342242837** | **1677787157** |
| 22 | **838926358** | **1342242838** | **1677787158** |
| 23 | **838926359** | **1342242839** | **1677787159** |
| 24 | **838926360** | **1342242840** | **1677787160** |
| 25 | **838926361** | **1342242841** | **1677787161** |
| 26 | **838926362** | **1342242842** | **1677787162** |
| 27 | **838926363** | **1342242843** | **1677787163** |
| 28 | **838926364** | **1342242844** | **1677787164** |
| 29 | **838926365** | **1342242845** | **1677787165** |
| 30 | **838926366** | **1342242846** | **1677787166** |
| 31 | **838926367** | **1342242847** | **1677787167** |

Pola: `50% = 0x32010000 + NID` · `80% = 0x50010000 + NID` · kolom ketiga = `0x64010000 + NID` (hexadecimal lihat tabel asli).

### 3.7 ★ Poin penting pengalihan otomatis di `PlatformsXX.xml` (★★ baca §3.8 dulu sebelum mengubah sini)

**Cara pengelompokan input / output di tingkat PathMap menentukan "otomatis berganti begitu jack tersambung" atau "harus diganti manual di pengaturan sistem"**:

- ★★ **Agar otomatis berganti, keduanya harus berada dalam group / array yang sama**;
- Praktik umum: **buat satu kelompok untuk input, satu kelompok untuk output**;
- Selain itu akan seperti VoodooHDA —— **harus dipilih manual**.

**Namun "banyak jalur dalam satu kelompok" punya satu prasyarat fatal: deteksi jack harus benar-benar bekerja**.
Saat deteksi tidak dilaporkan, AppleHDA tidak memperoleh sinyal, dan banyak jalur dalam satu kelompok akan **mdegenerasi menjadi hanya mempertahankan jalur terakhir, sisanya menghilang dengan diam** (kesimpulan 1 §3.8)
⇒ **Pertama konfirmasi lewat §5.6 bahwa pin sense motherboard ini hidup, baru tentukan susunan mana yang dipakai**, kalau tidak berarti tergantung keberuntungan.

### 3.8 ★★ Tiga akar penyebab terukur pada AppleHDA (berlaku untuk semua codec, prioritas di atas pin config)

> Ketiganya tereskplorasi satu per satu dalam satu penerapan lengkap (model contoh ALC897), **tidak bergantung pada model codec, dan merupakan perilaku AppleHDA itu sendiri**.
> Diurutkan berdasarkan prioritas: cara pengelompokan > Port Connectivity pin > deteksi jack.

**Kesimpulan 1 · Menaruh banyak jalur dalam satu kelompok perangkat ⇒ hanya jalur terakhir yang dipertahankan.**
Menaruh output line belakang dan headphone depan dalam kelompok yang sama (susunan auto-switch yang umum di komunitas) ⇒ jack hijau belakang langsung hilang.
Setelah dipecah menjadi kelompok terpisah, keduanya muncul. **Ini penyebab kegagalan paling umum pada audio onboard.**

| Sebelum diubah (banyak jalur dalam satu kelompok) | Setelah diubah (satu jalur per kelompok) |
|---|---|
| `[0] 0x09→0x22→0x18` / `0x09→0x22→0x19` | `[0] 0x09→0x22→0x18` |
| `[2] 0x14→0x0c→0x02` ← dalam kelompok yang sama dengan `0x1b`, **dibuang** | `[3] 0x14→0x0c→0x02` ← menjadi perangkat tersendiri |
| `[2] 0x1b→0x26→0x25` | `[4] 0x1b→0x26→0x25` ← menjadi perangkat tersendiri |

> Di komunitas, susunan auto-switch "banyak jalur dalam satu kelompok masih bisa jalan" karena mereka memilih sumber lewat deteksi keberadaan (§3.7);
> tanpa deteksi, susunan itu mdegenerasi menjadi mengambil jalur terakhir. **Komentar pada layout 52/53 ALC887 secara eksplisit menuliskan non auto-switch**,
> dan justru layout itulah yang dibuat untuk Asus PRIME Z270-P —— **pada motherboard ASUS deteksi tidak dilaporkan adalah hal wajar**.

**Kesimpulan 2 · AppleHDA menolak membuat perangkat input untuk pin Mic In dengan `PortConnectivity = 0b00` (jack).**
Baik Declare sebagai `Mic` maupun `ExtMic` sama sekali tidak berhasil (keempat konfigurasi gagal saat diuji). Setelah pin ditandai **`0b10` (perangkat internal tetap)** barulah muncul;
ALC897 layout 31 sudah melakukan hal yang sama.

| Versi | Nama tipe layout | ADC | PortConn pin | Hasil |
|---|---|---|---|---|
| v1 / v3 | `Mic` | 0x09 | 0 (jack) | ❌ tidak ada perangkat |
| layout 97 | `Mic` | 0x08 | 0 (jack) | ❌ 0 perangkat input |
| v4 | `ExtMic` | 0x09 | 0 (jack) | ❌ tidak ada perangkat |
| v6 | `Mic` | 0x09 / 0x08 | **2 (internal tetap)** | ✅ dua mikrofon muncul |

**Kesimpulan 3 · Deteksi jack bisa mati secara keseluruhan.** `Get Pin Sense` selalu 0 pada semua pin ——
**termasuk jack yang tersambung speaker dan sedang bersuara** (setelah memaksa D0 + memicu `SET_PIN_SENSE` tetap 0).
Codec punya GPIO dan mendukung input, tetapi **AppleHDA tidak pernah mengonfigurasi GPIO tersebut** ⇒ tidak ada event plug/unplug, **tidak ada skema auto-switch pun yang bisa dipicu**.
⇒ Jika tertemu "jack bersuara tapi tidak berganti saat dicabut/dimasukkan", uji dulu pin sense sesuai §5.6, jangan buru-buru mengubah PathMap.

### 3.9 Nama perangkat tidak bisa dikustomisasi, hanya dibedakan lewat urutan

- `PathMapRef` pada layout asli hanya punya `CodecID` / `Inputs` / `Outputs` / `PathMapID` / kamus per tipe, **tidak ada field name sama sekali**;
  nama perangkat ditentukan AppleHDA dengan mencari `Localizable.strings` berdasarkan tipe perangkat: `DeviceNameMic → "Built-in Microphone"`,
  `DeviceNameExtMic → "External Microphone"`, `DeviceNameLineIn → "Built-in Line Input"`.
- ⇒ Dua mikrofon **sama-sama bernama** `Built-in Microphone`, **dibedakan lewat urutan**; cara memastikan urutannya (tanpa menebak):

```bash
# UID perangkat berbentuk AppleHDAEngineInput:1F,3,0,1,:n
# n setelah titik dua terakhir adalah urutan kelompok input di dalam PathMap
./audio-tool listin
# atau langsung gunakan CoreAudio untuk membaca kAudioDevicePropertyDeviceUID
```

### 3.10 ★ Cara membaca field Pin Config Default / PinCntl (Intel HDA spec Rev 1.0a)

> Teks asli spesifikasi: **Intel High Definition Audio Specification Rev. 1.0a**
> (<https://www.intel.com/content/dam/www/public/us/en/documents/product-specifications/high-definition-audio-specification.pdf>)——
> **Pin Config Default §180–183, Pin Widget Control §163**.

**Figure 74 · Configuration Data Structure (32-bit)**:

```
31:30   29:24   23:20   19:16   15:12   11:8    7:4     3:0
Port Connectivity | Location | Default Device | Connection Type | Color | Misc | Association | Sequence
```

| Field | Arti | Nilai yang umum |
|---|---|---|
| **Port Connectivity**(bits31:30) | Tipe koneksi eksternal | `00b`=jack · `01b`=tanpa koneksi fisik · **`10b`=perangkat internal tetap** · `11b`=keduanya |
| Location | Posisi fisik | `[5:4]`: 00=eksternal / 01=internal; `[3:0]`: 1h=belakang / 2h=depan |
| Default Device | Kegunaan | `0h`=LineOut · `1h`=Speaker · `2h`=HP Out · `4h`=SPDIF Out · `8h`=LineIn · `Ah`=Mic In |
| Connection Type | Tipe antarmuka | `1h`=1/8" · `5h`=serat optik |
| Color | Warna jack | 1h hitam · 3h biru · 4h hijau · 6h oranye · 9h merah muda |
| Misc | Lain-lain | bit0 = **Jack Detect Override** (nilai 1 berarti jack itu **tidak punya deteksi keberadaan**, saling mengonfirmasi dengan kesimpulan 3 §3.8) |

**Figure 67 · Format PinCntl**(`0x707` Set / `0xF07` Get):

```
bit7      bit6     bit5     bit4:3   bit2      bit1:0
H-Phn En  Out En   In En    Rsvd     VRefEn[2] VRefEn[1:0] / EPT
```

**VREF (tegangan bias mikrofon)**: `0`=mati · `1`=50% · `2`=ground · `4`=80% · `5`=100%.
Saat mikrofon membutuhkan bias, lihat nilai ini: **`0x24` = IN enable + VREF 80%**; sedangkan hanya `0x20` = ada IN enable tapi tanpa bias.

**Dua field yang paling sering keliru**:

1. **"Internal atau jack" ditentukan oleh Port Connectivity bits31:30, bukan Connection Type**;
2. **Association berada di bits7:4, Sequence di bits3:0, Misc di bits11:8** —— menganggap Misc sebagai Association membuat seluruh pembacaan field meleset.

## 4. Build lokal (meniru cara CI resmi)

```bash
git clone https://github.com/acidanthera/AppleALC && cd AppleALC
git clone https://github.com/acidanthera/MacKernelSDK MacKernelSDK      # harus ditaruh di MacKernelSDK/

# dua bootstrap dari CI resmi (mengambil toolchain build)
src=$(curl -Lfs https://raw.githubusercontent.com/acidanthera/ocbuild/master/ci-bootstrap.sh) && eval "$src"
src=$(curl -Lfs https://raw.githubusercontent.com/acidanthera/Lilu/master/Lilu/Scripts/bootstrap.sh) && eval "$src"

xcodebuild -jobs 1 -configuration Release -arch x86_64
# produk: build/Release/*.zip (memuat AppleALC.kext)
```

> CI resmi juga mengompilasi `-arch ACID32` (32-bit), mesin modern tidak memerlukannya;
> dua perintah resmi adalah `-configuration Debug` dan `-configuration Release`, masing-masing dikompilasi sekali.

## 4.5 ★ Mengoptimalkan AppleALC (3.8 MB → ~90 KB) dan manajemen file

> Sumber: `Slimming_AppleALC/` dan `File_Management/`. **Paket hasil kompilasi CI resmi memuat seluruh 640+ layout dan seluruh codec**,
> sedangkan mesin milik Anda sendiri hanya butuh **satu codec + layout Anda sendiri**.

### 4.5.1 Optimasi (-97%)

1. **Hapus direktori codec yang tidak dipakai** (di bawah `Resources/` cukup simpan milik Anda, misalnya hanya `ALC269`)
2. **Hapus layout / Platforms yang tidak dipakai** (di direktori codec simpan hanya yang Anda pakai, misalnya hanya 18 dan 39)
3. Ubah `Info.plist` di direktori yang sama, **hapus entri Layout / Platforms yang tidak dipakai** (lihat di dalam entri, atau gunakan pencarian untuk menemukan milik Anda)
4. ★★ **Ubah juga `PinConfig.kext`**: `Contents/Info.plist` →
   `IOKitPersonalities/as.vit9696.AppleALC/HDAConfigDefault` adalah **sebuah array, 640+ entri** ⇒
   **sisakan hanya entri yang memuat Layout-ID milik Anda**
5. `xcodebuild` ⇒ produknya ada di `AppleALC/build/Release` ⇒ ganti `EFI/OC/Kexts/`

> ★★ **Peringatan wajib (kalimat asli panduan)**: **hanya layout yang Anda pertahankan yang bisa dipakai** ——
> bila Anda hanya menyisakan 17 dan `alcid` di `config.plist` diisi bukan 17, **maka tidak ada suara**.

> ★ Tambahan: `Slimming_Xcode_for_Kexts.md` mengajarkan **menghapus Xcode hingga hanya tersisa 1/5 ukuran** (menghapus platform SDK yang tidak dipakai).

### 4.5.2 Manajemen file: agar setiap eksperimen bisa di-rollback

Saat mengatur layout sendiri banyak kombinasi akan dicoba dan mudah ketuker. **Alur kerja yang diberikan panduan** (simpan satu arsip setiap kali mengompilasi):

1. Masuk ke `AppleALC/build/Release`, ekstrak `AppleALC-x.y.z-RELEASE.zip`
2. **Beri nomor pada direktori**: `AppleALC-1.7.2-RELEASE 1`
3. Salin **empat berkas sumber yang dikompilasi ke dalam kext** ke dalamnya sebagai arsip:
   `PinConfigs.kext` (di `Resources/`) · `PlatformsXX.xml` · `layoutXX.xml` (keduanya di `Resources/ALCXXX/`) · `Info.plist` di direktori yang sama
4. Ubah sumber kode → kompilasi ulang → uji; kalau tidak berhasil **nomor +1 dan ulangi**
5. **Rollback** = salin keempat berkas dari direktori bernomor itu kembali ke posisi semula ⇒ langsung kembali ke versi tersebut

★ Keuntungannya bukan hanya rollback: **saat mengajukan PR Anda juga tidak perlu menebak** (versi mana yang berhasil, parameternya apa, semuanya ada di direktori).
★ Gunakan bersama **template catatan pengujian** dari `AppleALC_Layout-ID/Testing_Notes.md` (PinConfig / EAPD / Routing / hasil tiap jack dicatat satu per satu).

### 4.5.3 ★★ Tiga kriteria saat build (bagaimana memastikan perubahannya benar-benar terkompilasi)

| Yang Anda kira | Kenyataannya | Kriteria yang benar |
|---|---|---|
| "saya mengubah pin config, tapi sha biner kext tidak berubah ⇒ tidak berlaku" | **pin config adalah data di dalam `Info.plist`, tidak masuk ke Mach-O** ⇒ sha memang tidak akan berubah | Lihat **`Info.plist` di dalam kext** (`PinConfigs.kext/Contents/Info.plist`), bukan sha |
| "saya mengubah `layoutXX.xml` / `PlatformsXX.xml`" | `kern_resources.cpp` akan dibuat ulang ⇒ **sha biner akan berubah**; sekaligus `*.xml.zlib` dibuat ulang dari `.xml` saat build | Setelah mengubah XML, ekstrak `.zlib` lalu cari kata kuncinya untuk memastikan perubahannya benar-benar ada di dalamnya:<br>`python3 -c "import zlib;d=zlib.decompress(open('Resources/ALC897/layout14.xml.zlib','rb').read());print(d.count(b'ExtMic'), d.count(b'<string>Mic</string>'))"` |
| "apakah `.zlib` / `.md5` perlu dikomit" | keduanya adalah produk build dan **di-gitignore** | **PR hanya butuh `.xml` + dua `Info.plist` + `Changelog`** (§6) |

## 5. Pasang di mesin lokal untuk pengujian

1. Masukkan `AppleALC.kext` hasil kompilasi ke `EFI/OC/Kexts/`, tambahkan entri di `Kernel → Add`
2. ★ **AppleALC harus dimuat lebih dulu daripada AppleHDA** (kalimat asli resmi: *"remember to load AppleALC earlier than AppleHDA"*);
   urutan injeksi: **Lilu → AppleALC**; `sudo kextstat` dapat dipakai untuk melihat urutan sebenarnya
3. ★ **Lilu wajib ada** (AppleALC adalah plugin Lilu)
4. **`layout-id` harus Anda tetapkan sendiri**: boot-arg `alcid=<N>`, atau injeksi `DeviceProperties` ke path perangkat audio
   (lokasi dicek dengan `gfxutil -f HDEF` / `-f HDAS`)
5. ★ **Resmi melarang penggantian nama secara eksplisit**: *"Do not use renaming HDAS to HDEF, B0D3 to HDAU, etc."* —— gunakan path perangkat langsung, jangan mengganti nama ACPI
6. Coba layout satu per satu: ubah `alcid=N` → restart → lihat hasilnya. **Coba satu per satu**
7. Log debug:
   ```bash
   # paling praktis: simpan log Lilu/AppleALC ke /var/log/Lilu_<versi>_<versi kernel utama>.<urutan>.txt setelah 60 detik
   # boot-args: -alcdbg -liludbg liludump=60
   log show --predicate 'process == "kernel" AND (eventMessage CONTAINS "AppleALC" OR eventMessage CONTAINS "Lilu")' --style syslog --source
   ```
8. Kontrol lain memakai boot-arg: `-alcoff` (nonaktifkan), `-alcbeta` (aktifkan pada sistem yang belum didukung), `alcverbs=1` (mengaktifkan `alc-verb`, atau properti perangkat `alc-verbs`);
   `-x` / `-s` juga akan menonaktifkan AppleALC

> ★★ **Perhatian khusus macOS 26**: README resmi menyebutkan *"macOS 26 dropped AppleHDA.kext in DP2."*
> ⇒ **Saat berkutat dengan audio onboard di 26, kembalikan dulu `AppleHDA` sesuai §0.5** (lihat §0.5: `perez987/AppleHDA-gone-on-macOS-26-Tahoe`).

### 5.6 ★ Uji dulu apakah deteksi jack hidup atau mati (menentukan susunan PathMap)

**Langkah ini harus mendahului penulisan PathMap**, karena menentukan Anda harus memakai "banyak jalur dalam satu kelompok (auto-switch)" atau "satu jalur per kelompok":

```bash
A=AppleALC/build/Release/alc-verb
# Get Pin Sense: baca status keberadaan tiap pin
for n in 0x14 0x18 0x19 0x1a 0x1b; do echo "$n sense = $($A $n 0xF09 0x00 | tail -1)"; done
# Jika tidak terbaca, paksa pin ke D0 lalu memicu Set Pin Sense sekali lagi (0x709)
```

Pembacaan: **jack yang tersambung speaker / yang sedang bersuara, sense-nya juga harus terbaca bukan 0**; jika semuanya 0 (setelah dipaksa D0 + `SET_PIN_SENSE` tetap 0),
artinya **deteksi jack motherboard ini secara keseluruhan tidak dilaporkan** (saling mengonfirmasi dengan bit0 `Misc` = Jack Detect Override pada pin config, §3.10)
⇒ **Tinggalkan susunan auto-switch**, tulis dengan "satu jalur per kelompok" sesuai kesimpulan 1 §3.8, jangan berputar-putar di sini.

### 5.7 ★★ Verifikasi tanpa telinga: sampling register codec saat playback

Jebakan terbesar dalam debug audio adalah **menggunakan "apakah terdengar" sebagai kriteria** —— ketika mesin tidak di dekat tangan, atau tidak ada speaker maupun mikrofon, seluruh kemajuan menjadi buntu.
Cara yang benar: **baca register codec bersamaan dengan playback**. Audio baru mengonfigurasi jalannya ketika alirannya benar-benar berjalan.

```bash
A=AppleALC/build/Release/alc-verb

# putar 6 kali suara notification di latar belakang, pastikan benar-benar bersuara saat sampling
( for i in 1 2 3 4 5 6; do afplay /System/Library/Sounds/Glass.aiff; done ) &
PLAY=$!
sleep 2

# sampling tiga jenis register: enable pin / aliran konverter / pilihan koneksi
for n in 0x14 0x1b; do echo "$n pin ctl = $($A $n 0xF07 0x00 | tail -1)"; done
for n in 0x02 0x25; do echo "$n conv(0xF06) = $($A $n 0xF06 0x00 | tail -1)"; done
wait $PLAY
```

Pembacaan dari satu pembacaan nyata (layout 97, perangkat default disetel sebagai headphone):

```
0x14 pin ctl = 0x00000000  ← jack hijau belakang tidak diaktifkan
0x1b pin ctl = 0x000000c0  ← jack headphone OUT enable + HP amp
0x02 conv   = 0x00000000  ← DAC tidak punya aliran
0x25 conv   = 0x00000010  ← DAC punya aliran
0x26 connsel= 0x00000000  ← mixer memilih 0x25
```

⇒ Jalannya sebenarnya lancar, hanya keluar ke jack headphone depan. **Kesimpulan seperti ini mustahil diperoleh dengan telinga.**

**Tiga kriteria "tanpa telinga", pilih sesuai kebutuhan**:

| Yang ingin dinilai | Cara |
|---|---|
| **Perangkat output mana yang berkorespondensi dengan jack fisik mana** | Telusuri seluruh perangkat output sistem: ganti default → playback → sampling `pin ctl` tiap pin dan `conv` DAC, **pembacaan pin siapa yang memuat NID tertentu, itulah jacknya** (toolkit `04-alat-skrip/map-outputs.sh` memakai ide yang sama) |
| **Apakah rantai input hidup (boleh tanpa mikrofon)** | Aktifkan perangkat input dan lihat puncaknya: **puncak = level noise dasar berarti ADC sedang merekam** (`mic-probe`) |
| **Apakah mikrofon punya tegangan bias** | Baca pin `0xF07`: `0x24`=IN+VREF80% ada bias; `0x20`=hanya IN enable tanpa bias (§3.10) |

**Empat detail operasional yang wajib diketahui**:

1. **VREF berubah-ubah mengikuti kondisi runtime** (terukur `0x22 ↔ 0x24`) ⇒ **jangan menyimpulkan dari satu pembacaan**, baca beberapa kali berturut-turut, atau baca sambil mengambil sampel suara;
2. Saat bias hanya diberikan pada satu pin (`MuteGPIO` hanya bisa menunjuk satu NID), **mikrofon yang lain bisa dilengkapi saat runtime**:
   `alc-verb 0x19 0x707 0x24` (tidak perlu root) ⇒ agar otomatis saat boot, pasangkan LaunchAgent yang menjalankannya terjadwal;
3. **Baru login langsung menjalankan tool CoreAudio akan menghasilkan 0 perangkat** —— ini ilusi karena `coreaudiod` belum siap, **bukan kegagalan, tunggu 5 detik lalu jalankan lagi**;
4. Aturan lama saat deploy ke ESP: `sync` lalu tunggu 2 detik, bandingkan dua sha, `find -size 0` untuk memindai file 0 byte yang tertinggal karena FAT penuh.

**Pemeriksaan menyeluruh dengan satu perintah** (toolkit `04-alat-skrip/verify-applealc.sh`, Anda bisa menulis sendiri mengikuti delapan bagian ini):
versi sistem → apakah `AppleHDA` dimuat (prasyarat macOS 26) → apakah Lilu/AppleALC dimuat → `layout-id` yang berlaku di HDAS
→ identifikasi codec (`IOHDACodecVendorID` seharusnya `0x10ec0897`) → instans `AppleHDAController`
→ perangkat audio sistem → jumlah kemunculan `com.apple.driver.AppleHDA` di AuxKC (>0 baru tahan terhadap restart).

## 6. Mengajukan PR

Kalimat asli README resmi: *"To support more audio codecs in the binary packages you are asked to submit your configurations. Please read the wiki for more details."*

PR sebaiknya memuat:

- Direktori `Resources/<CODEC>/` yang baru/diubah (`Info.plist` + berkas layout / platform)
- **codec dump asli** (memudahkan pemeriksa, `/proc/asound/card0/codec#0` versi Linux paling standar)
- **Model yang sudah diuji (motherboard/laptop) + versi macOS + hasil** (port/fungsi mana yang bisa dipakai, mana yang tidak)
- Nomor layout sesuai **11–99**, dan komentar menyebut **model serta penulis** (lihat §3.4)
- Bila `Vendors.plist` / `Kexts.plist` / `CodecLookup.plist` / `Controllers.plist` diubah, jelaskan **mengapa**
- Tabel dukungan dibuat oleh `Tools/wiki_table.command` resmi ⇒ sebelum commit, pastikan entri codec Anda dapat dibuat dengan benar

**Disiplin commit** (konsisten dengan upstream lain):
- **Satu PR satu perubahan**; deskripsi singkat; tulis dengan kalimat Anda sendiri
- Jangan menempelkan konten panjang hasil generate otomatis; jangan menulis basa-basi gaya "bilang ya nanti saya ubah"
- Kanal diskusi: thread InsaneMac dari README (bahasa Inggris) / thread AppleLife (bahasa Rusia)

## 7. Troubleshooting: `alc-verb` dan jebakan umum

| Gejala | Yang diperiksa |
|---|---|
| **Perintah `alc-verb` tidak merespons** | ① apakah `alcverbs=1` berlaku (atau `alc-verbs=1` pada DeviceProperties); ② apakah AppleALC / Lilu ada di `kextstat \| grep -v com.apple`; ③ **apakah ada `VoodooHDA` (membuat AppleALC sama sekali tidak berfungsi)**; ④ apakah `alc-verb` yang dipakai dikompilasi bersama versi AppleALC yang sedang berjalan |
| **Menambahkan `-alcdbg` / `-liludbg` tapi tidak ada output debug sama sekali** | ★★ **Kedua parameter ini hanya berlaku pada build DEBUG**, biner release **sama sekali mengabaikannya** ⇒ Anda harus mengompilasi sendiri versi Debug AppleALC / Lilu |
| **Setelah layout diubah, sebagian jack membaik dan sebagian jack rusak** | Proses normal ⇒ simpan satu arsip tiap ronde mengikuti **alur kerja manajemen file §4.5.2** (empat berkas sumber), **Anda bisa kembali ke versi sebelumnya kapan saja**; catat satu per satu dengan template `Testing_Notes.md` |
| **Setelah dioptimasi, tidak ada suara lagi** | ★★ **Hanya layout yang Anda pertahankan yang bisa dipakai** —— periksa apakah `alcid` di `config.plist` memang nomor yang Anda sisakan |
| **Sebuah output port hilang tanpa sebab / tersisa satu port** | ★★ **PathMap dengan banyak jalur dalam satu kelompok hanya mempertahankan jalur terakhir** ⇒ taruh satu jalur per kelompok perangkat (kesimpulan 1 §3.8) |
| **Tidak ada satu pun perangkat input muncul (terutama pin Mic In)** | ★★ **AppleHDA menolak membuat perangkat untuk pin Mic dengan `PortConnectivity=0b00`** ⇒ tandai pin sebagai `0b10` internal tetap (kesimpulan 2 §3.8) |
| **Port bersuara, tapi headphone/mikrofon tidak berganti saat dicabut/dimasukkan** | Uji pin sense dulu (§5.6)—— **deteksi jack bisa mati**, saat itu auto-switch apa pun tidak bisa dipicu, jangan mengubah PathMap |
| **Saya mengubah pin config, sha kext tidak berubah, дума tidak berlaku** | pin config berada di `Info.plist`, **tidak masuk Mach-O** ⇒ lihat plist, bukan sha (§4.5.3) |
| **Codec sama, tapi tidak berganti otomatis saat jack tersambung** | Di PathMap, **input/output tidak diletakkan dalam group/array yang sama** ⇒ §3.7 (prasyarat: pin sense hidup) |
| **Jack gabungan (headphone+mic) tidak bersuara setelah dicabut/dimasukkan / mikrofon tidak bersuara** | `WakeConfigData` **tidak bisa menangani event plug/unplug** ⇒ pakai **`ALCPlugFix-Swift`**; gunakan `alc-verb` lebih dulu untuk mencari urutan yang benar (§3.5) |
| **`AppleHDA` hilang setelah restart / tidak terlihat di kextstat** | ① versi terpasang salah (KDK macOS 26 tidak punya AppleHDA, harus 15.8.1/24H32); ② AuxKC dibersihkan saat sistem membangun ulang ⇒ pemeriksaan ③ di §0.5.5 |
| **Menulis layout di tengah jalan, tidak tahu port mana yang mikrofon / port mana yang bisa deteksi** | ★★ **Batasan keras tidak dijalankan** (§3.0.1)—— berhenti, kembali ke Windows dan ambil semuanya dengan HDAU lalu lanjutkan; sisi macOS tidak melihat label panel, menebak pasti berantakan |

## 8. Contoh: nilai machine-side dari satu penerapan lengkap (ASUS TUF Z690-PLUS WIFI D4 / ALC897)

> Berikut ini **hanya nilai contoh**, untuk menunjukkan "bentuknya setelah tabel §0.6 terisi penuh". Ganti item demi item saat memakai mesin Anda.

| Item | Nilai |
|---|---|
| Controller | `8086:7AD0`, subsys `1043:8841`, nama ACPI **`HDAS`** ⇒ `PciRoot(0x0)/Pci(0x1F,0x3)` |
| codec | `10EC:0897` = ALC897, `CodecID 0x0897`, REV_1004 |
| Layout akhir | **14** (13 layout siap pakai di upstream sudah dicoba semua, tidak ada untuk motherboard ini ⇒ dibuat baru, lihat contoh §2) |
| DeviceProperties | `PciRoot(0x0)/Pci(0x1F,0x3)` → `layout-id=<0e000000>` (14 little-endian) + `alc-verbs=<01000000>` |
| AppleHDA | 600.2, dipasang di `/System/Library/Extensions` (dari KDK 15.8.1 build 24H32) |
| AppleALC | 1.9.9 (dikompilasi sendiri, dengan layout di tabel), **Lilu berada di depannya** |
| Patch runtime | Bias mikrofon depan: `alc-verb 0x19 0x707 0x24`, dipasang LaunchAgent untuk melengkapi saat boot |

**Contoh · Hasil pengambilan data (dump sisi Windows, `evidence/06-alc897-codec-dump.txt`)**
—— codec total 37 widget (`0x02–0x26`, AFG `0x01`), Pin Complex 14 buah, **hanya 8 yang punya jack fisik**:

| NID | Pin Config Default | Tipe perangkat | Posisi / warna | Grup asosiasi / nomor | EAPD |
|---|---|---|---|---|---|
| `0x14` | `0x01014010` | Line Out | belakang / hijau | 1 / 0 | `0x2` |
| `0x15` | `0x01011012` | Line Out | belakang / hitam | 1 / 2 | — |
| `0x16` | `0x01016011` | Line Out | belakang / oranye | 1 / 1 | — |
| `0x18` | `0x01A19030` | Mic In | belakang / merah muda | 3 / 0 | — |
| `0x19` | `0x02A19040` | Mic In | depan / merah muda | 4 / 0 | — |
| `0x1a` | `0x0181303F` | Line In | belakang / biru | 3 / 15 | — |
| `0x1b` | `0x02214020` | HP Out | depan / hijau | 2 / 0 | `0x2` |
| `0x1e` | `0x01456150` | SPDIF Out | belakang / oranye (serat optik) | 5 / 0 | — |

> `0x11 / 0x12 / 0x17 / 0x1c / 0x1d / 0x1f` semuanya N/A (tanpa koneksi fisik), merupakan placeholder template codec, **tidak perlu dikonfigurasi untuk layout**.
> Perhatikan `0x14/0x15/0x16` berada dalam grup asosiasi 1 yang sama ⇒ Windows hanya membuat **satu** endpoint output untuk ketiganya ( pembacaan 1 §3.0.2);
> `0x18` dan `0x1a` berada bersama dalam grup asosiasi 3, sedangkan `0x19` berada di grup sendiri —— cara pengelompokan ini langsung memengaruhi susunan pada kesimpulan 1 §3.8.

**Contoh · Routing dan kemampuan Amp** (bahan mentah saat menulis PathMap):

```
[Putar] 0x02[DAC]→0x0c[Mixer]→0x14(hijau utama)/0x1b(headphone, EAPD 0x2 berganti lewat presence) ; 0x06[DAC]→0x1e(S/PDIF)
        (0x03→0x0d→0x15, 0x04→0x0e→0x16 adalah ekstensi analog 5.1)
[Rekam] 0x18/0x19/0x1a/0x1b → 0x22[Mixer 12 in] → 0x09[ADC] ; 0x18/0x19/0x1a/0x1b → 0x23[Mixer 11 in] → 0x08[ADC]
Amp: 0x02–0x05 DAC out=0x00025757 · 0x07–0x09 ADC in=0x80023F17 · 0x0b Mixer in=0x80051F17 ·
     0x0c–0x0f/0x22/0x23/0x26 mute=1 · 0x18–0x1b Pin in=0x00270300(nsteps=3 ⇒ boost mikrofon 0–3 tingkat)
```

**Tiga hal yang harus dijaga setiap saat**: ① perangkat audio lokal bernama **`HDAS`** —— untuk mencari path gunakan `gfxutil -f HDAS`,
**resmi melarang mengubahnya menjadi `HDEF`** (*"Do not use renaming HDAS to HDEF, B0D3 to HDAU, etc."*);
② menambah/menghapus kext audio berarti mengubah ESP ⇒ ikuti prosedur aman (backup → ubah → verifikasi → `sync`/unmount-remount → verifikasi ulang sha);
③ ubah satu variabel saja setiap kali (`alcid` / satu pin / satu pengelompokan), kalau tidak atribusi penyebabnya mustahil.
