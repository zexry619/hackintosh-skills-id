# Penggunaan dokumen resmi dan metode penilaian per kunci

> ★★ **Indeks utama "siapa yang harus dipercaya"** ⇒ **`ecosystem-sources.md`** (sumber otoritatif Acidanthera / Dortania ·
> rantai alat corpnewt · penulis driver · sumber daya Mandarin · forum).
> **Urutan otoritivitas: dokumen resmi > README penulis driver > posting forum.**

## 1. Tentukan dulu "versi dokumen mana yang dipakai"

```bash
nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version
# DBG-108-2026-09-27 → build DEBUG OpenCore 1.0.8 (prefiks DBG- = DEBUG)
# Bentuk seperti 1.0.8-2026-09-27 → RELEASE
```

**Wajib memakai versi yang sama**: `ocvalidate` menolak memvalidasi config versi berbeda; Failsafe kunci di dalam dokumen juga bisa berubah antar versi.

Cara memastikan OpenCore.efi di mesin ini DEBUG atau RELEASE (byte per byte):

```bash
shasum -a 256 /Volumes/EFI/EFI/OC/OpenCore.efi
# Bandingkan dengan berkas bernama sama di paket resmi: perbedaan ukuran RELEASE dan DEBUG jelas (1.0.8: 626,688 B vs 868,352 B)
```

## 2. Ambil paket dan bangun pustaka kunci

Jalankan `scripts/fetch-opencore-docs.sh`, yang melakukan tiga hal:

1. Mengunduh paket **RELEASE** resmi `<ver>` dan mengekstraknya (berisi `Utilities/ocvalidate/`, `Docs/`, `X64/`)
2. Mengambil `Docs/Configuration.tex` versi tersebut (sumber LaTeX, lebih mudah ditelusuri daripada PDF)
3. Mengekstrak `Type / Failsafe / Description` dari **setiap kunci** pada `Configuration.tex` → `oc-doc-keys.json`

Tiap kunci di dalam `Configuration.tex` berbentuk seperti ini, dan ekstraksi cukup memotong blok mengikuti pola tersebut:

```latex
\item
  \texttt{ResetLogoStatus}\\
  \textbf{Type}: \texttt{plist\ boolean}\\
  \textbf{Failsafe}: \texttt{false}\\
  \textbf{Description}: Reset \texttt{BGRT} table \texttt{Displayed} status field ...
```

Gunakan `\section{}/\subsection{}` untuk melacak bagian milik tiap kunci (ACPI / Booter / Kernel / Misc / NVRAM / PlatformInfo / UEFI).

## 3. Tiga input untuk perbandingan silang

| Input | Peran |
|---|---|
| `Sample.plist` resmi | Nilai default resmi (contoh Failsafe); buat **diff semantik** dengan config live |
| `oc-doc-keys.json` | **Penjelasan resmi** tiap kunci, dipakai untuk menilai "apakah penyimpangan ini disengaja atau salah" |
| `config.plist` live | Konfigurasi sebenarnya pada mesin |

Diff semantik harus dilakukan secara rekursif mengikuti struktur plist (dict dibandingkan per key, list dibandingkan panjang/elemennya), bukan diff teks — `plutil`/pengeditan manual akan menata ulang format.

## 4. Kategori penilaian (bagi penyimpangan menjadi tiga jenis)

1. **Penyimpangan yang benar dan berdasar** — di dalam dokumen ada kondisi berlaku yang jelas, dan mesin ini kebetulan memenuhi. Contoh:
   - `Kernel>Emulate>Cpuid1Data = 55 06 0A 00…`: nilai yang direkomendasikan dalam kalimat asli dokumen "Alder Lake (0x090672) → Comet Lake (0x0A0655)"
   - `FixupAppleEfiImages=true`: dokumen menyatakan bahwa nilai ini **wajib** untuk macOS yang lebih baru saat `SecureBootModel=Disabled`
   - `ProvideCustomSlide=true`: dokumen menyatakan necessity-nya ditentukan oleh log `OCABC: Only N/256 slide values are usable!`
2. **Bertentangan dengan panduan eksplisit dokumen** — dokumen memakai kata-kata seperti "strongly discouraged" / "Please use X instead" / "required". Contoh:
   - `UEFI>APFS>MinDate/MinVersion = -1` (dokumen: strongly discouraged)
   - `Booter>Quirks>EnableWriteUnprotector=true` sementara `OCABC: MAT support is 1` (dokumen: saat MAT didukung, gunakan `RebuildAppleMemoryMap`)
   - `Kernel>Quirks>PanicNoKextDump=true` (dokumen: menyembunyikan informasi kext di dalam panic)
3. **Sisa yang redundant/tidak berlaku lagi** — tidak berbahaya tapi tidak efektif. Contoh:
   - `UEFI>Input>PointerSupportMode='ASUS'` padahal `PointerSupport=false` (dokumen: nilai ini hanya berlaku untuk papan ASUS Z87/Z97)
   - `PointerPollMin/Max` yang ditulis eksplisit justru sama dengan nilai default implementasi (menulis `0` setara)
   - Mengaktifkan `DisableLinkeditJettison` dan `keepsyms=1` bersamaan (dokumen menyatakan yang pertama justru ada untuk menghindari yang kedua)

## 5. ★ "Hubungan berpasangan" dalam dokumen — jangan dipisah

| Pasangan | Dasar dokumen |
|---|---|
| `PlatformInfo>UpdateSMBIOSMode=Custom` ↔ `Kernel>Quirks>CustomSMBIOSGuid=true` | Custom "Requires patching AppleSmbios.kext and AppleACPIPlatform.kext… done automatically by CustomSMBIOSGuid quirk" |
| `Misc>Boot>LauncherOption=Full` ↔ `UEFI>Quirks>RequestBootVarRouting=true` | "For this option to work, RequestBootVarRouting is required to be enabled" |
| `Misc>Security>SecureBootModel=Disabled` ↔ `Booter>Quirks>FixupAppleEfiImages=true` | "required for all newer macOS when SecureBootModel is set to Disabled" |
| `UEFI>Output>TextRenderer=System*` ↔ `ClearScreenOnModeSwitch` / `IgnoreTextInGraphics` | Kedua sakelar ini "only applies to System renderer" — begitu diganti ke Builtin menjadi tidak berlaku |
| `UEFI>Output>ProvideConsoleGop=true` ↔ `Resolution=Max` | Renderer Builtin "necessary to enable ProvideConsoleGop and set Resolution to Max" |
| `com.apple.iokit.IONDRVSupport` pada `Kernel>Block` | Jika tidak, framebuffer firmware akan merebut display index 0 |
| Tiap kunci pada `NVRAM>Add` ↔ entri `NVRAM>Delete` dengan nama sama | "Variables will only be set if not present or deleted" |

> ★ **Perhatikan**: **Failsafe resmi `LauncherOption` adalah `Disabled`**, bukan `Full` — artinya `Full` termasuk "penyimpangan dari default".
> Bukan berarti makin banyak makin baik: `Full` membuat OpenCore menulis ulang entri boot firmware setiap kali boot, **saat boot dari flash disk entri hard disk akan diarahkan ke sana**
> ⇒ lihat `boot-entries.md`.

## 6. Format laporan yang disarankan

- Di bagian awal berikan "**kesimpulan ocvalidate**" + "**jumlah/klasifikasi simpangan terhadap Failsafe**"
- Tabel per kunci: `kunci | nilai di mesin ini | Failsafe dokumen | penilaian | kalimat asli dokumen (dipotong)`
- "Usulan perubahan" diurutkan berdasarkan risiko, setiap butir mencantumkan **dasar + cara rollback**
- Sertakan seksi "**tidak diubah secara sengaja**" beserta alasannya — agar lain kali tidak ada yang rusak karena "mengembalikan ke default"
