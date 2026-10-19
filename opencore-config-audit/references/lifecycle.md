# Alur lengkap: dari membuat EFI di Windows sampai patching selesai

Hackintosh bukan "sekali konfigurasi", melainkan **enam tahap**. Ikuti urutan ini, setiap langkah punya hasil yang jelas dan kriteria penilaian.

```
① Membuat EFI dasar di Windows ──► ② Memasang macOS dengannya ──► ③ Setelah masuk sistem, ganti ke DEBUG OpenCore
                                                          │
                                          ⑤ Patch item per item sesuai dokumentasi resmi ◄── ④ Mengumpulkan log saat boot
                                                          │
                                          ⑥ Operasional harian: ganti kembali ke RELEASE + matikan log debug
```

| Tahap | Dilakukan di | Hasil | Skill terkait |
|---|---|---|---|
| ① Membuat EFI dasar | Windows | EFI yang bisa boot installer | `rapidefi-first-efi.md` |
| ② Memasang macOS | Mesin target | Sistem yang bisa sampai ke desktop | — (pemasangan itu sendiri di luar cakupan skill ini) |
| ③ Ganti ke DEBUG OpenCore | Di dalam macOS (ubah ESP) | Bootloader yang bisa menghasilkan log lengkap | `scripts/oc-swap-build.sh` + §3 artikel ini |
| ④ Mengumpulkan log | Di dalam macOS | Log boot OC + log kernel | `scripts/grab-logs.sh` + `logs-and-debug.md` |
| ⑤ Patching | Di dalam macOS (ubah ESP) | config/SSDT/kext yang sudah dikoreksi item per item | Tahap 1–8 di SKILL.md |
| ⑥ Operasional harian | Di dalam macOS (ubah ESP) | Hasil akhir dengan boot cepat dan layar tenang | §6 artikel ini + `scripts/oc-swap-build.sh release` |

---

## ① Membuat EFI dasar di Windows

Lihat `rapidefi-first-efi.md`. Ringkasan poin-poinnya:

- Gunakan **RapidEFI-Tool**: "Segarkan info hardware → konfigurasi EFI otomatis → hasilkan EFI", dapatkan **konfigurasi dasar**
- ★ Batas yang diakui resmi: **"cocok sebagai konfigurasi dasar, tidak sama dengan konfigurasi final bebas debug"**, **"ujilah boot dengan U disk cadangan dulu, jangan langsung menimpa EFI yang sedang dipakai stabil"**
- Pada tahap ① **jangan** mengejar kesempurnaan: yang penting bisa masuk installer dan bisa masuk desktop. Sisanya ditunda ke tahap ⑤

## ② Memasang macOS dengannya

- Saat memasang gunakan **pengaturan aman installer**: `ResizeAppleGpuBars = 0`, `ResizeGpuBars = -1`, **tidak** memblokir `com.apple.iokit.IONDRVSupport`
  (installer berjalan di atas framebuffer firmware, large BAR akan membuatnya macet di PCI configuration)
- Setelah terpasang dan bisa masuk desktop, baru beralih ke setelan "driver/operasional" (large BAR, memblokir IONDRVSupport, dll)

## ③ Ganti ke DEBUG OpenCore (tindakan kunci pada tahap ini)

### Mengapa wajib diganti

| | RELEASE | DEBUG |
|---|---|---|
| Ukuran `OpenCore.efi` (terukur pada 1.0.8) | 626,688 B | **868,352 B** |
| `BOOTx64.efi` | 24,576 B | **53,248 B** |
| `Drivers/*.efi` (versi sama, terukur) | kecil | **semua lebih besar** (contoh: `OpenRuntime.efi` 24,576 → 36,864; `OpenCanopy.efi` 114,688 → 151,552) |
| Jumlah log | sedikit | **jauh lebih banyak** (satu boot bisa memenuhi `opencore-*.txt` 256 KB di ESP) |
| `Misc>Debug>SysReport` | **tidak tersedia** (dokumen menyatakan jelas: build RELEASE tidak menyediakannya) | **tersedia** — akan membuat `SysReport/` di ESP, berisi dump ACPI / SMBIOS / audio codec |
| Kecepatan boot | cepat | sedikit lebih lambat (biaya pembuatan log) |

⇒ **Untuk "mengumpulkan log lalu patch", Anda harus mengganti ke DEBUG**; `SysReport` bahkan menjadi satu-satunya cara praktis untuk mendapatkan DSDT/SSDT asli di tahap ⑤.

### Cara menggantinya (sudah dibungkus `scripts/oc-swap-build.sh`)

1. **Konfirmasi versi saat ini**: `nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version`
   - `DBG-108-2026-09-27` → versi **1.0.8**, build **DEBUG** (prefix `DBG-`)
   - `1.0.8-2026-09-27` → versi 1.0.8, build RELEASE
2. **Unduh** `OpenCore-<ver>-DEBUG.zip` resmi versi sama (atau `-RELEASE.zip`)
3. **Cadangkan** `EFI/OC/OpenCore.efi`, `EFI/BOOT/BOOTx64.efi`, `EFI/OC/Drivers/` yang ada
4. **Ganti tiga bagian**:
   - `EFI/OC/OpenCore.efi`
   - `EFI/BOOT/BOOTx64.efi`
   - **yang bernama sama dengan yang resmi** di dalam `EFI/OC/Drivers/` (★ **pertahankan driver pihak ketiga**, misalnya `NullMothLogo.efi` yang dipasang oleh App pemasangan driver)
   - ⚠️ **Isi driver di kedua sisi berbeda** (sudah terukur pada tabel di atas), jadi mengganti build **harus** mengganti driver juga, jika tidak akan tercampur versi/build
5. **Verifikasi**: sha file baru harus identik dengan file bernama sama di paket resmi
6. **Restart** (mengganti bootloader baru berlaku setelah restart)
7. **Verifikasi setelah restart**:
   ```bash
   nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version   # harus berubah menjadi DBG-<ver>-<tanggal>
   shasum -a 256 /Volumes/EFI/EFI/OC/OpenCore.efi                 # harus sama dengan paket DEBUG resmi
   ```

### Dua hal yang sebaiknya dikerjakan sekaligus setelah diganti

- **Aktifkan `Misc>Debug>SysReport` (sekali saja)**: setelah restart akan muncul `SysReport/` di ESP, di dalamnya ada dump **tabel ACPI (DSDT/SSDT), SMBIOS, audio codec** — di tahap ⑤ ketika harus menentukan "SSDT mana yang perlu ditambahkan", inilah bahan pertamanya. **Matikan setelah diambil** (hanya tersedia di DEBUG, dan memakan ruang)
- **Atur tujuan log**: `Misc>Debug>Target` disarankan `69 (0x45)` = log + DataHub + **file** (tidak ditampilkan di layar, lihat `logs-and-debug.md`)
  — jika ingin melihat di layar, kembalikan `0x02` (`71`), tapi itu **hal lain** dan tidak berkaitan dengan kelengkapan log

### Kapan harus ganti kembali ke RELEASE

**Setelah patching selesai dan mesin sudah stabil** (inilah tahap ⑥): boot lebih cepat, log lebih sedikit.
Sebelum mengganti, pastikan: `Misc>Debug>SysReport` sudah dimatikan (memang tidak berlaku di RELEASE), dan log lengkap tiap boot tidak lagi dibutuhkan.
(Pengukuran lokal: `OpenCore.efi` DEBUG **identik byte per byte** dengan paket DEBUG resmi, jadi penggantian ini bersih dan bisa di-rollback.)

## ④ Mengumpulkan log

Jalankan `scripts/grab-logs.sh` (`--oc-only` untuk melihat bagian OC saja dulu). Hasil:

- `oc-boot-log-summary.txt` — baris-baris penting yang disaring dari `opencore-*.txt` di root ESP (kriteria `OCABC:`, daftar tabel ACPI, registrasi entri boot, ambang `OCJS: APFS`, error `OC:`)
- `kernel-log-acpi.txt` — error ACPI di log kernel boot ini, tabel yang terdeteksi macOS, mount perangkat platform, keberadaan perangkat flat ACPI

**Cara interpretasinya ada di `logs-and-debug.md`**. Tiga kriteria tercepat:

1. **Error ACPI 0 hit** ⇒ tidak ada "ACPI rusak", tidak perlu buru-buru menambahkan SSDT
2. `OCB: Registering entry <nama>` ⇒ entri boot mana yang **sesungguhnya** ada di selector (satu-satunya dasar yang andal untuk melihat efek "pemblokiran")
3. `OCABC: MAT support is 1` / `Only N/M slide values are usable!` ⇒ langsung menentukan cara menyetel `EnableWriteUnprotector` dan `ProvideCustomSlide`

## ⑤ Patching

Kembali ke **Tahap 1–8** di SKILL.md, dengan urutan berikut:

1. **Tahap 1–2**: ambil dokumen resmi versi sama + validasi `ocvalidate` + perbandingan per kunci (cari item yang "bertentangan dengan dokumen")
2. **Tahap 3**: pengumpulan bukti dari log (hasil ④ di atas)
3. **Tahap 5**: pemeriksaan ACPI/SSDT (bandingkan DSDT/SSDT di `SysReport/` dengan `AcpiSamples` resmi)
4. **Tahap 4**: untuk setiap perubahan, jalankan `oc-edit-safe.sh begin/finish`
5. **Tahap 6–7**: pemblokiran disk, perampingan kext (pembersihan akhir)
6. **Tahap 8**: pasang/setel driver (NVIDIA, Intel nirkabel)

### Ritme patching (penting)

- **Ubah satu item saja per waktu**, ubah lalu restart untuk verifikasi, baru ubah yang berikutnya — kalau tidak, masalah tidak bisa diatribusikan
- Tulis jelas di laporan untuk setiap item: **apa yang diubah / dasar dokumen / cara rollback**
- Simpan daftar "**pasti tidak diubah**" (beserta alasannya), agar tidak ada yang merusak dengan "mengembalikan ke default" di kemudian hari
- Masalah saat boot (`EXITBS:START` macet, selector tidak muncul) **lihat dulu `opencore-*.txt` di root ESP**, jangan menebak

---

## ⑥ Operasional harian: ganti kembali ke RELEASE + matikan log debug

Setelah patching selesai, pindahkan mesin dari "mode troubleshoot" ke "mode operasional": **ganti build bootloader** + **matikan log** + **konfirmasi preferensi `-v`**.

### 6.1 Ganti kembali ke RELEASE

```bash
scripts/oc-swap-build.sh release     # otomatis menebak versi dari NVRAM; cadangan + ganti OpenCore.efi/BOOTx64.efi/Drivers resmi bernama sama + verifikasi sha
# Setelah restart pastikan:
nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version    # diharapkan 1.0.8-2026-09-27 (tanpa prefix DBG-)
```

### 6.2 Matikan log debug (sisi konfigurasi)

Kembalikan `Misc>Debug` ke **nilai default `Sample.plist` resmi** — inilah "mode operasional":

| Kunci | Nilai harian | Penjelasan |
|---|---|---|
| `Target` | **`3`** = `0x01`+`0x02` | hanya "log + konsol" ⇒ **tidak lagi menulis `opencore-*.txt` ke ESP** (penting: hilangkan `0x40`) |
| `DisplayLevel` | `2147483650` = `0x80000002` | ERROR + WARN (hilangkan INFO) |
| `AppleDebug` | `false` | tidak lagi menggabungkan log debug boot.efi ke dalam log OC |
| `ApplePanic` | `false` | tidak menulis file panic; **jika ingin menyimpan bukti panic, setel `true`** (akan menulis file ke ESP) |
| `DisableWatchDog` | `false` | hanya diperlukan bila build DEBUG lambat boot |
| `SysReport` | `false` | memang tidak berlaku di RELEASE |
| `LogModules` | `*` | default resmi |

> Untuk **benar-benar senyap**, `Target` bisa disetel `0` (dokumen: tidak menyetel `0x01` = semua log dibuang);
> tetapi dengan begitu layar bahkan tidak menampilkan pesan error OC, troubleshoot menjadi sangat melumpuhkan ⇒ secara harian disarankan tetap `3`.

### 6.3 `-v`: **harus bertanya ke pelanggan, jangan memutuskan sendiri**

`-v` (verbose macOS) adalah **item preferensi**, bukan default teknis. Saat beralih ke mode operasional, **tanyakan eksplisit ke pengguna** yang mana yang diinginkan, dan jelaskan perbedaannya:

| | `-v` aktif | `-v` nonaktif |
|---|---|---|
| Layar | kernel/kext menggulir penuh, logo Apple tidak terlihat | logo Apple + progress bar |
| Kecepatan boot | sedikit lebih lambat (setiap baris harus dirender lewat konsol) | sedikit lebih cepat |
| Troubleshoot di tempat | langsung terlihat macet di mana | perlu tekan **CMD+V** untuk buka sementara (tersedia saat `PollAppleHotKeys=true`) |
| Kelengkapan log | **tidak terpengaruh** | **tidak terpengaruh** (`log show` / Send logs / log OC semuanya masih ada) |

- Mematikannya = hapus `-v` dari boot-args (setara "Turn verbose off" di App pemasangan driver)
- Saat mengganti, **hanya ubah token ini saja**, dan tulis di laporan "pelanggan memilih yang mana"

### 6.4 Checklist penutup mode operasional

- [ ] `oc-swap-build.sh release` sudah dijalankan, dan setelah restart `opencore-version` tidak berawalan `DBG-`
- [ ] `Misc>Debug` sudah dikembalikan ke nilai §6.2 (atau menyimpan panic ke disk sesuai keinginan pelanggan)
- [ ] `-v` sudah **ditanyakan ke pelanggan** dan disetel sesuai pilihan
- [ ] `opencore-*.txt` yang menumpuk selama periode troubleshoot di ESP dibersihkan seperlunya (boleh menyisakan beberapa yang terbaru untuk referensi)
- [ ] Jalankan lagi `scripts/oc-verify.sh` untuk memastikan tetap `No issues found`
- [ ] Catat di laporan: apa saja yang dikerjakan pada tiap tahap siklus hidup ini, sha akhir, serta daftar "pasti tidak diubah"

---

## ⑦ Setelah itu: upgrade versi mayor macOS (bukan tahap ketujuh pemasangan, ini hal lain)

Setelah terpasang dan berjalan stabil, jika ingin menaikkan dari **macOS 15 (Sequoia)** ke **26 (Tahoe)**,
itu **alur yang lain** (upgrade pasti memutus Wi-Fi dan OCLP root patch) ⇒ lihat **`os-upgrade-15-to-26.md`**.

Singkatnya: **tindakan utamanya adalah menambahkan `MinKernel`/`MaxKernel` pada kext yang build-nya per versi** (batas versi lama `24.99.99`, versi baru `MinKernel 25.0.0`),
nonaktifkan FileVault + lindungi kext pihak ketiga sebelum upgrade, lalu tambahkan entri + bangun ulang root patch setelah upgrade.
