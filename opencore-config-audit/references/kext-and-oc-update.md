# Pembaruan kext dan OpenCore —— kapan harus diperbarui, kapan **sangat jangan disentuh**

> Dasar: satu kali **pengalaman jatuh dan rollback lengkap** di mesin ini pada 10-16 (mengira build Dortania sebagai "rebuild pihak ketiga" → menggantinya dengan release upstream → setelah dibandingkan byte demi byte ternyata itu **penurunan versi** → rollback semuanya) + dokumentasi resmi OpenCore + pemeriksaan baris demi baris skrip instalasi driver upstream.
> ★★ **Satu kalimat**: **"pembaruan" bukan hal baik di Hackintosh** —— buktikan dulu bahwa "seharusnya diperbarui", baru mulai;
> **langkah terakhir untuk menilai "apakah file ini produk resmi" adalah me-grep skrip instalasi milik vendor itu sendiri, bukan mengecek tag upstream.**

## 0. ★★★ Ingat ini dulu (mesin ini sudah bayar mahal)

**Tag upstream tidak ditemukan ≠ asalnya tidak jelas.**

Di EFI mesin ini ada 8 kext dengan nomor versi **satu nomor patch lebih tinggi dari release upstream**, dan upstream **balas 404 satu per satu**:

| kext | Versi di EFI | Release terbaru upstream | Apakah upstream punya tag tersebut? |
|---|---|---|---|
| `Lilu` | **1.7.3** | 1.7.2 | ❌ 404 |
| `VirtualSMC` / `SMCProcessor` / `SMCSuperIO` | **1.3.9** | 1.3.8 | ❌ 404 |
| `WhateverGreen` | **1.7.2** | 1.7.1 | ❌ 404 |
| `RestrictEvents` | **1.1.7** | 1.1.6 | ❌ |
| `NVMeFix` | **1.1.4** | 1.1.3 | ❌ |
| `BlueToolFixup` | **2.7.3** | 2.7.2 | ❌ |

**Semuanya adalah hasil build dari Dortania `build-repo`** —— repositori itu **membangun berdasarkan commit tertentu**,
dan ketika upstream punya commit baru setelah release terakhir, ia **menambah nomor patch sendiri +1**.

⇒ **"Memperbarui" mereka ke release upstream = menurunkan versi** (sudah pernah dicoba di mesin ini dan sudah di-rollback).

### 0.1 Siapa yang "sumber resmi"? —— **Installer milik vendor yang menentukan**

Skrip instalasi (driver NVIDIA NullMoth) `app/Resources/nullmoth-setup.sh` baris 100–105 memuat tabel `kurl()`
yang **menetapkan kext yang dibutuhkan driver ke file tertentu dan memverifikasi SHA-256**:

| kext | Sumber yang dipin installer | Versi di dalam paket |
|---|---|---|
| `Lilu.kext` | `dortania/build-repo/releases/download/**Lilu-0515f40**/` | **1.7.3** |
| `RestrictEvents.kext` | `dortania/build-repo/releases/download/**RestrictEvents-9265e78**/` | **1.1.7** |
| `AMFIPass.kext` | `dortania/OpenCore-Legacy-Patcher/raw/main/payloads/Kexts/Acidanthera/` | 1.4.1 |
| `USBToolBox.kext` | `USBToolBox/kext/releases/download/1.2.0/` | 1.2.0 |

Komentar aslinya:

> *"Kexts the driver's OpenCore setup needs, **pinned to the same files 1401 builds with** (p1401/mirror.json)."*

**Pemetaan lainnya (sudah diunduh dan dibandingkan satu per satu, identik byte demi byte)**:

| Versi di EFI | Tag Dortania |
|---|---|
| `VirtualSMC` / `SMCProcessor` / `SMCSuperIO` **1.3.9** | `VirtualSMC-b5c62c2` |
| `WhateverGreen` **1.7.2** | `WhateverGreen-093e76f` |
| `BlueToolFixup` **2.7.3** | `BrcmPatchRAM-6538902` |
| `NVMeFix` **1.1.4** | (build satu keluarga) |

SHA zip untuk cabang Lilu = `261aebb9dc83adb6515c96405653f53c3c50b09c89babdb91fb41f7b33a1cd2a`,
**identik persis dengan nilai yang dipin di installer**.

⇒ ★★ **Disiplin**: sebelum memutuskan "apakah sebuah kext seharusnya diperbarui", **pertama grep skrip instalasi / dokumentasi / `mirror.json` milik vendor**:
itulah yang mendefinisikan "sumber resmi". **Semua yang dipin vendor tidak boleh disentuh.**

## 1. Empat kriteria untuk menilai "apakah kext ini produk resmi" (**harus dilihat bersama-sama**)

| # | Kriteria | Apa yang bisa dibuktikan | Bagaimana bisa salah menilai |
|---|---|---|---|
| 1 | **Apakah upstream punya tag ini** (`git/ref/tags/<v>`) | Apakah berasal dari release upstream | ★ **bisa salah menilai** —— tag Dortania build-repo tidak ditemukan di upstream |
| 2 | **Metadata build** (`DTXcode` / `DTSDKName` / `BuildMachineOSBuild`) | Apakah dari batch dan toolchain yang sama | ★ **bisa salah menilai** —— mesin build Dortania memang memakai **toolchain lama** (batch di mesin ini `DTXcode 1420 / macosx13.1 / 21G320`, tahun 2022) |
| 3 | **sha256 biner** | Apakah sama dengan yang resmi | Hanya bisa membuktikan "berbeda", **tidak bisa membuktikan "tidak tepercaya"** |
| 4 | ★★★ **Apakah installer / dokumentasi / `mirror.json` milik vendor meng-pin-nya** | **Jawaban otoritatif** | —— |

**Kesimpulan**: 1–3 hanya bisa menghasilkan "mencurigakan", **hanya butir 4 yang bisa menentukan sifat**.
★ Sebaliknya: **jika butir 4 meng-pin-nya, bahkan kalau 1–3 semuanya "abnormal", jangan disentuh**.

> ★ **`DTXcode` lama ≠ mencurigakan**; **nomor versi lebih tinggi dari resmi ≠ mencurigakan**.
> Ingat contoh kebalikannya: seluruh "berkas mencurigakan" di mesin ini adalah **build Dortania yang ditentukan vendor**, dan berkorespondensi dengan **commit yang lebih baru dari release resmi**.

## 2. Menentukan DEBUG / RELEASE —— pakai **perbandingan ukuran**, jangan cari string

Unduh paket resmi RELEASE + DEBUG **dengan versi yang sama**, bandingkan ukuran satu per satu (**DEBUG biasanya 1.2–1.9×**):

| kext | Mesin ini | REL resmi | DBG resmi | Putusan |
|---|---|---|---|---|
| `Lilu` | 543,840 | 527,456 | **978,324** | REL |
| `WhateverGreen` | 531,800 | 527,896 | 752,368 | REL |
| `RestrictEvents` | 52,848 | 52,768 | 62,408 | REL |
| `NVMeFix` | 51,312 | **51,312** | 91,320 | REL |
| `BlueToolFixup` | 41,336 | 41,296 | 42,592 | REL |

★ Jauh lebih andal daripada "mencari string `DEBUG` di dalam biner" (kalimat ini bisa saja tertinggal pada build Release).
★ DEBUG/RELEASE pada **bodi OpenCore** adalah **hal yang berbeda** (lihat awalan `DBG-` / `REL-` pada `opencore-version`, lihat §4).

## 3. ★ Kapan **baru** seharusnya diperbarui

| Situasi | Harus diperbarui? |
|---|---|
| Upstream menerbitkan release baru, **dan installer vendor tidak meng-pin kext ini** | ✅ Boleh (ikuti alur §5) |
| Menaikkan versi besar macOS, butuh build baru dengan pemisahan versi `MinKernel` / `MaxKernel` | ✅ **Wajib** (lihat `os-upgrade-15-to-26.md`) |
| Ada bug fix / CVE yang **tepat cocok dengan gejala Anda** | ✅ Boleh |
| **Installer vendor meng-pin-nya** | ❌ **Jangan disentuh** (§0.1) |
| Hanya "nomor versinya kelihatan lama" / "kebiasaan memperbarui semuanya" | ❌ **Jangan disentuh** |
| Bodi driver (seperti NullMoth) versinya dikelola App itu sendiri | ❌ Serahkan ke App (`/Library/NullMoth/driver-version`), **jangan mengganti kext secara manual** |

> ★ Pelajaran dari mesin ini: **pikir "memperbarui semuanya sekaligus" itu memang salah** ——
> Di ekosistem kext Hackintosh, "kombinasi yang dipin vendor" jauh lebih penting daripada "versi terbaru".

## 4. Pembaruan bodi OpenCore

### 4.1 Lihat dulu kondisi sekarang

```bash
nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version
# contoh: DBG-108-2026-09-27  ⇒ build 1.0.8 DEBUG
```

`DBG-` = DEBUG / `REL-` = RELEASE; angkanya adalah versi (`108` = 1.0.8); bagian berikutnya adalah tanggal build.

### 4.2 ★★ Mengganti build **wajib mengganti Drivers resmi dengan nama yang sama** (aturan besi 14)

Pada versi yang sama, **seluruh isi Drivers RELEASE dan DEBUG berbeda** (contoh 1.0.8: `OpenRuntime.efi` 24,576 → 36,864).
Hanya mengganti `OpenCore.efi` = **bootloader dengan build campuran**.
★ **Driver pihak ketiga** (seperti `NullMothLogo.efi`) **dibiarkan apa adanya**.

Gunakan `scripts/oc-swap-build.sh` (skrip ini mengganti Drivers sekaligus, mempertahankan driver pihak ketiga, serta melakukan backup/verifikasi/penulisan otomatis).

### 4.3 Saat menaikkan ke **versi baru** OpenCore, ada langkah tambahan

1. **Ambil dulu paket resmi versi yang sama**: `scripts/fetch-opencore-docs.sh` (mengambil `ocvalidate` / `Configuration.tex` / `Sample.plist` / `AcpiSamples`)
2. ★ **`ocvalidate` harus versi sama dengan OpenCore di mesin** —— jika tidak, hasil validasi tidak sah (aturan besi 10)
3. **Baca `Differences.pdf` / Release notes resmi** untuk melihat apakah ada breaking change (diff semantik pada `Sample.plist` adalah pemeriksaan tercepat)
4. Setelah selesai, jalankan `scripts/oc-verify.sh` (`plutil` + `ocvalidate` + integritas referensi + sha)
5. ★ **Jangan lupa sisi BIOS**: versi baru mungkin punya requirement berbeda untuk `ResizeGpuBars` / `ResizeAppleGpuBars` / `Kernel>Block`

## 5. Alur pembaruan (versi aman, satu jenis per satu kali)

1. **Backup**: seluruh EFI (`tgz`) + direktori kext (**termasuk salinan daftar versi `VERSIONS-before.txt`**)
2. **Catat kondisi saat ini**: `scripts/kext-inventory.sh` mengekspor `CFBundleVersion` / `DTXcode` / sha256 tiap kext
3. **Putuskan apakah perlu disentuh**: 4 kriteria di §1 + tabel pembaruan di §3
4. ★ **Satu jenis per satu kali**: **kext dulu atau bodi OpenCore dulu, jangan bersamaan**
5. **Ubah**: sinkronkan direktori kext dengan `rsync -a --delete` (★ perhatikan, ini menghapus file di tujuan yang tidak ada di sumber)
6. **Tiga pemeriksaan mandiri**:
   - `ocvalidate` = No issues found
   - **semua `BundlePath` di dalam config dapat ditemukan di `Kexts/`** (0 referensi hilang)
   - **hanya kext yang diubah** yang berubah pada `Info.plist` + binernya
7. **Tulis ke disk**: `sync` → **unmount** → **mount ulang** → verifikasi ulang versi/sha konsisten (FAT punya write cache)
8. **Verifikasi setelah restart**: bandingkan versi dengan `kmutil showloaded --list-only`; jalankan `scripts/oc-verify.sh`
9. **Tuliskan jalur rollback dengan jelas** (di mana cadangannya, bagaimana cara memulihkannya)

## 6. Pemeriksaan mandiri dan jebakan

| Item | Cara |
|---|---|
| **Daftar versi kext** | `scripts/kext-inventory.sh <titik mount EFI atau direktori Kexts>` — versi / `DTXcode` / ukuran / sha256 / pencocokan referensi config |
| ★ **`PATH` shell bisa rusak oleh sandbox** | di dalam skrip, jalankan dulu `export PATH=/usr/bin:/bin:/usr/sbin:/sbin` (jika tidak, `stat` / `strings` / `grep` akan muncul `command not found` secara inexplicable) |
| ★ **Nomor disk bisa bergeser** | selalu kenali disk dengan `diskutil list \| grep "EFI EFI"` (aturan besi 1) |
| ★ **Unmount lalu mount ulang baru berarti tertulis ke disk** | write cache FAT (aturan besi 4) |
| ★ **`rsync --delete` adalah pedang bermata dua** | ia membuat target **identik penuh** dengan sumber —— jangan dipakai untuk menyinkronkan skenario "hanya seharusnya ada beberapa file tambahan" |
| ★ **Jangan mencoba tanpa cadangan** | terutama bodi OC: build campuran = mungkin tidak bisa masuk ke picker |

## 7. Sumber rujukan

- Dortania `build-repo` (<https://github.com/dortania/build-repo>) —— mekanisme build berdasarkan commit dengan nomor patch +1.
- Tabel `kurl()` pada skrip instalasi vendor `nullmoth-setup.sh` + `p1401/mirror.json` —— **definisi sebenarnya dari "sumber resmi"**.
- OpenCore `Configuration.pdf` (semantik nomor versi `Misc>Debug`) + `Differences.pdf` resmi.
- Terkait: `official-docs-method.md` (perbandingan per kunci) · `os-upgrade-15-to-26.md` (pemisahan versi) ·
  `nvidia-driver.md` (versi bodi driver dikelola App) · `disks-and-kexts.md` (pemangkasan kext dan daftar "tidak boleh dihapus").
