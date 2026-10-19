# Tidak bisa terpasang / tidak bisa boot ke sistem —— alur debug berlapis

> Dasar: **seluruh rekap kegagalan** pada mesin ini antara 10-08 ~ 10-16 (ganti model mesin loop restart ×6, macet di USB/HID ×3, `decmpfs` panic ×2,
> `X86PlatformShim` panic, kegagalan sangat dini `no kext summary`, layar hitam ReBAR, VMD tidak menemukan disk…)+ dokumen resmi OpenCore.
> ★★ **Inti satu kalimat**: **tentukan dulu secara berlapis "di bagian mana macetnya", baru periksa log bagian itu** ——
> **jangan langsung mengubah konfigurasi** (kalau diubah, kasusnya tidak bisa direkap ulang, sudah pernah dialami mesin ini).

## 0. ★★ Langkah pertama selalu berlapis

Pecah boot menjadi empat bagian, **tentukan dulu di bagian mana macetnya**:

| Bagian | Gejala | Di mana mencari |
|---|---|---|
| **① Firmware / OpenCore itu sendiri** | **Selector pun tidak muncul**; atau setelah muncul langsung kembali ke BIOS / layar hitam | §2 |
| **② Periode boot OpenCore** | Selector sudah muncul, setelah memilih macOS **macet di output milik OpenCore sendiri** | §3 (log OC) |
| **③ Awal kernel** (< 1–2 s) | Logo Apple / `-v` baru mulai langsung berhenti; atau **langsung restart** | §4 |
| **④ Kernel menengah akhir / user space** | **Baru macet jauh di akhir** (semua driver sudah termuat) / panic | §5, §6 |

### 0.1 ★★ Bedakan dulu "hang" atau "loop restart"

- **Loop restart = boot watchdog timeout otomatis restart ⇒ "tunggu lebih lama" tidak berguna** (di mesin ini 10-12 ganti model 6 kali semuanya bentuk ini).
- **Yang layak ditunggu hanya hang** — mesin ini juga pernah punya kasus sebaliknya: terlihat seperti hang, padahal sedang **rollback snapshot system volume 11 GB, lambat tapi bukan mati**.
- ★ Kriteria: layar **berkedip sekali indicating restart**; apakah POST/BIOS berjalan ulang dari awal.

## 1. Tiga aturan besi (ingat dulu, menghemat separuh kerumitan)

1. ★ **Tanpa `-v` tidak ada informasi** — saat troubleshooting **harus nyalakan `-v`** (matikan hanya di pemakaian harian).
   Kelengkapan log sama saja, tapi **informasi di layar hanya diberikan oleh `-v`** (`-v` adalah **preferensi, harus bertanya ke klien**, aturan besi 13).
2. ★★ **Tidak bisa boot ≠ harus instal ulang** — pertama ikuti §7 untuk **mengembalikan konfigurasi yang terakhir masih bisa dipakai**, lalu telusuri perlahan.
3. ★★ **Siapkan satu USB EFI yang masih bisa dipakai** (yang itu memakai `Misc>Boot>LauncherOption=Disabled`, **tidak menulis ulang NVRAM**)——
   ini adalah **prasyarat semua jalur pemulihan** (`boot-entries.md`).

## 2. ① Firmware / OpenCore itu sendiri (selector bahkan tidak bisa dimasuki)

| Gejala | Yang perlu dicek |
|---|---|
| **Layar hitam, logo pun tidak ada** | ★ Diketahui di mesin ini: `UEFI>Quirks>ResizeGpuBars=13` (8 GB) menyebabkan **layar hitam saat boot ~21 s** ⇒ **tunggu cukup 2 menit dulu**; kalau benar-benar timeout, ubah ke `12` atau matikan BIOS ReBAR (`nvidia-driver.md`) |
| **Selector tidak muncul** | ★ Logo boot pihak ketiga (misalnya `NullMothLogo.efi`) **bisa membuat firmware gagal mencapai selector** ⇒ matikan dari sistem lain. ★ **boot-args tidak bisa menolong kondisi macet "sebelum selector"** |
| **Setelah tema diubah, selector jadi layar hitam semua / tidak mau start** | ★ **Ikon wajib yang kurang satu membuat OpenCanopy tidak mau start** ⇒ jalankan `scripts/oc-theme-check.sh`; jalan keluar `PickerMode=Builtin` (`theme-opencanopy.md`) |
| **Curiga build tercampur** | ★ **Ganti `OpenCore.efi` saja tapi tidak mengganti Drivers** = bootloader build tercampur ⇒ **ganti juga Drivers resmi dengan nama sama** (aturan besi 14) |
| **OpenCore tidak terlihat di BIOS** | Itu masalah entri boot, bukan masalah boot ⇒ `boot-entries.md` (`LauncherOption` / `bcfg` / `OpenControl`) |

## 3. ② Periode boot OpenCore

**Ambil log** (tiga jalur, lihat `logs-and-debug.md` §4):

- ① **Berkas**: `opencore-*.txt` di root ESP (perlu `Misc>Debug>Target` berisi **`0x40`**; **batas atas 256 KB**)
- ② **DataHub** (`Target` berisi **`0x04`**; tetap bisa dibaca walau konsol dimatikan)
- ③ **Variabel UEFI** (`Target` berisi **`0x10`**, batas log 32 KB)

**Daftar kriteria**: `OCABC: MAT support` / `slide` / ambang driver APFS / daftar tabel ACPI / registrasi entri boot ⇒ `logs-and-debug.md` §5.

> ★★ **Cara membaca log saat tidak bisa boot ke sistem**: boot dengan **USB EFI atau Recovery** → mount EFI **internal** → baca `opencore-*.txt`.

## 4. ③ Awal kernel (< 1–2 s)

| Gejala | Arti / yang perlu dicek |
|---|---|
| **`can't perform kext scan: no kext summary`** | ★★ **Kegagalan lapisan cache boot yang sangat dini (< 1 s)** —— **tidak terkait GPU, tidak terkait "kext tertentu"**, jangan telusuri ke driver kartu grafis (sudah pernah dialami mesin ini) |
| **Langsung restart, tidak ada yang terlihat** | ★ boot watchdog ⇒ kembali ke §0.1 untuk memastikan bentuknya |
| **`X86PlatformShim` / `xcpm_hwp_enable` panic (type 13)** | ★★ **Hal pertama: cek apakah `Intel(R) Speed Shift Technology` di BIOS `Enabled`** (**`Auto` pun bisa berarti mati**) —— `wrmsr(0x770,1)` #GP (`intel-turbo.md` §10) |
| **Baru saja mengubah kext lalu macet** | Bandingkan dengan `scripts/kext-inventory.sh` terhadap daftar sebelum perubahan; ★ cek `Kernel>Add` **referensi hilang** / **urutan** (`Lilu` harus paling depan) |

## 5. ④ Kernel menengah akhir / user space

| Gejala | Yang perlu dicek |
|---|---|
| **Baru macet jauh di akhir (semua driver sudah termuat)** | Kemungkinan besar **layanan user space tidak jalan**. Contoh di mesin ini: `AppleUSBHostHIDDevice` sudah dibuat, tapi menunggu **DriverKit dext `com.apple.AppleUSBHostHIDDrivers`** ⇒ **tidak ada input keyboard/mouse** (terlihat seperti hang, padahal menunggu layanan yang tidak datang) |
| **Macet di Preboot** | ★ Troubleshooting khusus ada di `5T33Z0/OC-Little-Translated` `Content/18_Troubleshooting/Fixing_Preboot` (ada juga metode SysReport di `K_Debugging/`) |
| **Panic** | ★ **Bukti utama ada di `/Library/Logs/DiagnosticReports/`**; panic backtrace dengan `keepsyms=1` **langsung memberi nama frame** (karena itu saat troubleshooting layak menyalakan `keepsyms=1`) |
| **`decmpfs_pagein_compressed: couldn't ubc_upl_map a single page`** (`apfs_vnops.c`) | ★ **Keluarga yang sudah diketahui di mesin ini**: kernel assertion pada **jalur dekompresi transparan APFS**, **tidak terkait GPU / model mesin / tekanan memori** (di panic `Compressor Info: 0% … 0 swapfiles` sudah menyingkirkan kekurangan memori); cirinya **beberapa puluhan menit setelah boot, saat proses baru dijalankan**, **baris kode yang sama pada model dan proses yang berbeda** |
| **`element modified after free` sekitar ~2 s setelah boot** | ★ Teruji di mesin ini penyebabnya **`NVMeFix.kext`** (**bukan GPU, bukan driver jaringan**) ⇒ **nonaktifkan `NVMeFix` untuk A/B dulu** |
| **`SIGABRT` di `MPSLibrary::MPSKey_Compile`** (**aplikasi** crash, bukan kegagalan boot) | ★ Driver NVIDIA Metal tidak bisa membuat jalur komputasi MPS ⇒ **masalah tingkat sistem, tidak terkait EFI / tiga kode / injeksi memori** (`nvidia-driver.md`, `pitfalls.md`) |

## 6. Khusus masa instalasi: tidak bisa terpasang / tidak menemukan disk

| Gejala | Yang perlu dicek |
|---|---|
| ★★ **Installer "tidak menemukan drive sama sekali"** | Sembilan dari sepuluh kasus karena **VMD / Intel RST di BIOS tidak dimatikan** (macOS tidak punya driver VMD) ⇒ `bios-settings.md` |
| **Saat instalasi keyboard/mouse tidak merespons / macet di USB** | `XHCI Hand-off` / `Legacy USB Support`; ★ **apakah `UTBMap` memetakan keluar disk instalasi atau keyboard/mouse** |
| **Restart di tengah instalasi** | Dulu tentukan bentuknya lewat §0.1; **loop restart** ⇒ cek ACPI (§8) |
| **Setelah instalasi selesai, boot pertama tidak bisa masuk** | Sering kali **`MinKernel`/`MaxKernel` pembagian salah** (`os-upgrade-15-to-26.md`) atau **urutan kext** |
| **Baru selesai instalasi lalu panic di power management** | Cek BIOS `Speed Shift` (§4) |

## 7. ★★ Urutan pemulihan (ikuti ini saat tidak bisa boot ke sistem)

1. **Kembali dulu ke "konfigurasi yang terakhir masih bisa dipakai"** —— setiap kali mengubah ESP harus ada backup (aturan besi 2/3);
   arsip versi dari `scripts/oc-edit-safe.sh` memang untuk ini
2. **Boot dengan USB EFI** (prasyaratnya file itu ada dan `LauncherOption=Disabled`, sehingga tidak menulis ulang NVRAM)
3. Boot **Recovery / mode single-user**, mount EFI **internal**, kembalikan konfigurasi
4. **Bsearch**: cabut perangkat yang mencurigakan / matikan sakelar yang mencurigakan
   - Contoh: iGPU terkait (`-wegnoigpu`), ReBAR, sebuah kext yang mencurigakan
   - ★ **Ubah satu hal saja per kali** (aturan besi 5)—— kalau tidak, rekap berikutnya tidak bisa melacak
5. **Ubah ESP langsung dari sistem lain** (Windows / macOS lain sama-sama bisa mount FAT)
6. ★ **Jangan** "mengubah beberapa hal sekalian" saat sedang tidak bisa boot —— itu membuat rekap berikutnya kehilangan semua petunjuk

## 8. Terkait ACPI (kasus khusus mesin ini, wajib dilihat saat ganti model)

★★★ **Di mesin ini (ASUS Z690) ganti model ⇒ loop restart**, penyebab sebenarnya adalah **SSDT OEM motherboard `xh_adls3`**:
board-id berubah ⇒ macOS **mengurai ulang tabel ACPI** ⇒ tabel itu gagal diurai (**`HS06 AE_NOT_FOUND`**)
⇒ lapisan power management / ACPI bermasalah ⇒ **loop restart** (bukan hang).

- **Perbaikan = `ACPI>Delete` tabel asli (`SSDT` + `OemTableId=xh_adls3`) + `ACPI>Add` `SSDT-XHADLS3.aml`**
- **Urutan: perfectingkan SSDT dulu (diverifikasi lolos di [model lama]) → ganti SMBIOS → lalu buat ulang CPUFriend** (aturan besi 19)
- Arah yang sudah disingkirkan (jangan coba sia-sia): peta port USB · root patch OCLP · model mesin itu sendiri · batas 15 port · sisa NVRAM
- Lihat detail di `smbios-and-serials.md` §2

## 9. Daftar pengumpulan bukti (tinggal salin)

```bash
# ① Log OC dari boot ini (saat tidak bisa boot ke sistem: boot via USB EFI / Recovery, mount EFI internal, baru baca)
ls -l /Volumes/EFI/opencore-*.txt

# ② Laporan panic (bukti utama)
ls -lt /Library/Logs/DiagnosticReports/*.panic 2>/dev/null | head

# ③ Kernel log dari boot ini (perlu hak akses root)
scripts/grab-logs.sh

# ④ Bagian mana yang macet (pemecahan timeline tiga bagian + jendela jeda)
scripts/boot-timeline.sh
scripts/find-boot-gap.sh

# ⑤ Snapshot kondisi saat ini: versi OC / daftar kext (termasuk verifikasi referensi config)
nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version
scripts/kext-inventory.sh /Volumes/EFI

# ⑥ Validasi keseluruhan konfigurasi
scripts/oc-verify.sh
```

## 10. Sumber

- OpenCore `Configuration.pdf` / `Differences.pdf` (definisi bit `Misc>Debug>Target`, semantik versi).
- Rekap keluarga kegagalan di mesin ini: loop restart ganti model (`smbios-and-serials.md` §2)· `decmpfs` panic (dekompresi transparan APFS)·
  `no kext summary` (lapisan cache sangat dini)· `X86PlatformShim` panic (BIOS Speed Shift)·
  `element modified after free` (`NVMeFix`)· `MPSKey_Compile` (NVIDIA Metal).
- Terkait: `logs-and-debug.md` · `boot-timeline.md` · `boot-entries.md` · `bios-settings.md` ·
  `pitfalls.md` · `kext-and-oc-update.md` · `lifecycle.md`.
