# HiDPI: resolusi ekuivalen yang membuat monitor non-Retina "lebih tajam"

> Alat: **`xzhih/one-key-hidpi`** (skrip, satu klik untuk menyimulasikan HiDPI macOS pada monitor non-Retina).
> Dasar: README repositori tersebut + implementasi `hidpi.sh` (path penulisan / opsi / cara pemulihan).
> ★ **Perhatian khusus untuk mesin ini**: driver NVIDIA yang dipakai adalah driver NullMoth (**mengaku sendiri belum sempurna**),
> dan HiDPI justru berada di jalur "mode tampilan / penskalaan / metadata" yang paling rawan baginya ⇒ lihat risiko dan persiapan pada §5.

## 1. Kapan dibutuhkan

- Monitor bukan Retina, tetapi resolusinya cukup tinggi (misalnya layar 4K/2K), macOS secara default menampilkan 1:1 ⇒ **huruf terlalu kecil, elemen antarmuka terlihat kabur**
- Ingin efek "seolah berukuran 1080p, tapi dirender dengan piksel 4K" (muncul tingkat penskalaan "Native" di System Settings)

**Prinsip**: HiDPI = membuat macOS merender dengan **resolusi logis 2×**, lalu menskalakan ke piksel asli panel.
Ini **tidak mengubah resolusi asli panel**, melainkan memasang **Display Override** (berisi `scale-resolutions`) di monitor untuk "menciptakan" tingkat di antaranya.
⇒ README resmi juga mengingatkan: **masalah penskalaan logo boot mungkin tidak bisa diperbaiki** (karena resolusi tinggi itu "palsu").

## 2. Di mana ditulisnya (menentukan besarnya risiko)

Skrip menulis ke **`/Library/Displays/Contents/Resources/Overrides/`** (perhatikan **bukan** `/System/Library/...`):

```
/Library/Displays/Contents/Resources/Overrides/
└── DisplayVendorID-<VID>/
    └── DisplayProductID-<PID>            ← override yang diinjeksi (berisi scale-resolutions, mode EDID juga berisi IODisplayEDID)
        DisplayProductID-<PID>.icns/.tiff ← opsional: mengganti ikon "Monitor" dengan tampilan Mac
```

- **Tidak menyentuh system volume tersegel**, tidak perlu root patch — jauh lebih repot daripada jalur OCLP
- VID/PID diturunkan dari EDID: skrip memakai `ioreg -lw0 | grep -i "IODisplayEDID"` untuk mengambil EDID monitor saat ini lalu menguraikannya
- Uninstall = **hapus direktori `DisplayVendorID-<VID>`** tersebut

## 3. Cara pakai

```bash
# Mode jarak jauh (jalankan skrip di master secara langsung)
bash -c "$(curl -fsSL https://raw.githubusercontent.com/xzhih/one-key-hidpi/master/hidpi.sh)"

# Atau mode lokal: unduh ZIP, ekstrak → klik dua kali hidpi.command
```

Alur menu (ikuti petunjuknya): **pilih monitor → pilih ikon monitor (iMac / MacBook / MBP / ProDisplayXDR / kustom) → pilih konfigurasi resolusi**
(ada daftar preset, dan juga bisa mengetik beberapa resolusi secara manual). Dua mode:

| Mode | Penjelasan |
|---|---|
| `Enable HIDPI` | Hanya menyuntikkan override `scale-resolutions` |
| `Enable HIDPI (with EDID)` | **Sekaligus menyuntikkan EDID yang sudah dipatch** — README resmi: *"Some device have wake-up issue, script's second option may help, it inject a patched EDID, but another problem may exists here."* (**mungkin menyelesaikan masalah wake-up, tapi juga bisa menimbulkan masalah baru**) |

⇒ **Coba yang pertama dulu**; opsi kedua hanya dipertimbangkan bila menghadapi masalah wake-up/mode yang tidak normal.

## 4. Pemulihan (**wajib diketahui sebelum melakukan**)

| Situasi | Cara |
|---|---|
| Bisa masuk sistem | Jalankan skrip sekali lagi, pilih item **restore/disable** (di README tertulis "opsi 3", sesuaikan dengan tampilan menu skrip sebenarnya) |
| Skrip pintasan yang dihasilkan | Skrip membuat **`.hidpi-disable`** di direktori user Anda, cukup jalankan `./.hidpi-disable` |
| **Tidak bisa masuk sistem** | Masuk ke **Terminal** di **macOS Recovery**: <br>`ls /Volumes/` → `cd /Volumes/<disk sistem>/Users/<nama pengguna>` → `./.hidpi-disable` |
| Pembersihan manual di Recovery | `rm -rf "/Volumes/<disk sistem>/Library/Displays/Contents/Resources/Overrides"` (hapus seluruh Overrides, atau hapus hanya `DisplayVendorID-<VID>` yang diinjeksi) |

## 5. ★★ Risiko dengan driver NVIDIA (NullMoth) — ekstra berhati-hati pada mesin ini

HiDPI menuntut driver menangani dengan benar **"mode non-asli panel + penskalaan + metadata mode"**, dan justru di situlah driver ini diketahui lemah:

| Fakta yang diketahui | Mengapa relevan dengan HiDPI |
|---|---|
| Di mesin ini pernah muncul **monitor terdeteksi 30,5 inci** | Penyebab sebenarnya = driver tidak mengisi `IODisplayModeInformation.imageWidth/imageHeight` (sudah diperbaiki, PR #199). **Ini menunjukkan driver ini pernah punya bug nyata pada "metadata mode tampilan"** |
| `TROUBLESHOOTING` resmi memuat "**layar hitam/berkedip pada 100–240 Hz**" dan "**layar hitam pada mode DSC**" | HiDPI memperkenalkan kombinasi mode/timing baru, sehingga mudah terjebak di jalur yang sama |
| `Known issues` resmi memuat "**window tumpang tindih dengan bayangan/kotak hitam saat BAR ≥ 4 GB** (#127)" | Jalur kompositor penskalaan lebih mudah membongkar masalah kompositor semacam ini |
| Klaim resmi "Most testing is done on an RTX 5060" dan di `CARD-SUPPORT` kolom Ampere tertulis **Pending** | Mesin ini memakai RTX 3080 ⇒ termasuk kombinasi "bisa jalan tapi belum terverifikasi sistematis" |

### Empat hal yang wajib dilakukan sebelum/sesudah mengaktifkan HiDPI

1. **Catat baseline** (supaya ada pembanding saat ada masalah):
   ```bash
   system_profiler SPDisplaysDataType > ~/before-hidpi-displays.txt
   ioreg -l -w0 | grep -iE "IODisplayMode|IODisplayEDID|IOFBCurrentPixel" | head -50 > ~/before-hidpi-ioreg.txt
   ```
2. **Ubah satu hal saja**: nyalakan HiDPI dulu (jangan sekaligus mengubah boot-args / mengganti driver / menyentuh `ResizeGpuBars`)
3. **Siapkan jalur pemulihan**: pastikan `.hidpi-disable` sudah terbentuk, dan tahu cara menghapusnya di Recovery (§4)
4. **Gejala khas kalau ada masalah** (berdasarkan kemungkinan): daftar mode tidak normal / layar hitam atau bergambar setelah dipilih / berkedip / tidak normal setelah wake-up / logo boot tidak berskala
   ⇒ **Saat layar hitam atau tidak bisa masuk sistem, 우선 pemulihan lewat §4**, baru pikirkan apakah masalahnya di sisi driver (periksa pesan NVRM/NVRMFB di `log show`)

> Bila HiDPI terus bermasalah di sisi driver, pertimbangkan: coba dulu pada **resolusi target yang lebih rendah** (lebih mendekati native, timing lebih sederhana),
> atau sementara tinggalkan HiDPI sampai driver selesai disempurnakan — **jangan mengubah baseline driver demi HiDPI** (`ResizeGpuBars` dan sejenisnya).

## 6. Jangan campurkan dengan "HiDPI di selector"

| | HiDPI di dalam sistem (dokumen ini) | HiDPI masa boot |
|---|---|---|
| Mengatur apa | Tingkat penskalaan desktop macOS | Teks dan ikon di selector OpenCore / antarmuka FileVault / logo boot |
| Cara menyetel | Display Override (alat ini) | `UEFI>Output>UIScale` (`1` normal / `2` HiDPI / `0` otomatis / `-1` tidak berubah) + `Resolution=Max` |
| Kebutuhan sumber daya | — | Ikon/label harus punya @2x (`.l2x`); lihat skill `opencore-picker-theme` |

Keduanya **saling independen**, boleh menyalakan hanya satu.

## 7. Catatan singkat mesin ini

- Jalur tampilan: RTX 3080 (`10de:2206`) → NVRMFB; paket driver 1.15.0; `ResizeGpuBars=13` + `ResizeAppleGpuBars=-1`
- Riwayat sisi tampilan yang diketahui: kesalahan ukuran monitor (sudah diperbaiki), tidak ada audio HDMI/DP, eGPU Thunderbolt tanpa output
- Bila layar dikenali sebagai TV (`kDisplayModeTelevisionFlag`) atau ukurannya tidak normal, **periksa dulu apakah itu masalah metadata mode di sisi driver**, baru pertimbangkan HiDPI
- Setelah selesai diubah, ingat: Display Override ada di `/Library/Displays/...` (**bukan di ESP**) ⇒ tidak berkaitan dengan perubahan EFI, tapi tetap **backup sebelum mengubah dan verifikasi setelahnya**
