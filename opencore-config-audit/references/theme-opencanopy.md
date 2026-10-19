# OpenCanopy Tema Pemilih (Tampilan Layar Boot)

> **Dasar**: bagian **OpenCanopy** pada dokumentasi `OpenCorePkg` + **`Docs/Flavours.md`** + tabel properti `Misc → Boot` / `UEFI → Output`.
> **Versi harus sama dengan OpenCore di mesin Anda**. Repositori sumber daya: **`acidanthera/OcBinaryData`** (font + tiga set ikon resmi).
>
> Dokumen ini menggabungkan dua dokumen tema terpisah sebelumnya: **Sakelar & properti** · **Daftar sumber daya & ikon** · **Flavour** · **Troubleshooting**.

## ★ Aturan besi (baca dulu)

1. **Satu ikon wajib hilang, OpenCanopy tidak akan mulai sama sekali** — jalankan `scripts/oc-theme-check.sh` dulu sebelum bicara soal keindahan
2. **Set ikon adalah "direktori", bukan "file"**: diletakkan di `EFI/OC/Resources/Image/<vendor>/<set-ikon>/`,
   ditunjuk oleh `Misc>Boot>PickerVariant` (**backslash**, misalnya `Acidanthera\GoldenGate`)
3. **`PickerMode` harus `External`**, kalau tidak OpenCanopy memang tidak dimuat (`Builtin` = antarmuka teks biasa)
4. **Mengubah `Resources/` juga berarti mengubah ESP** ⇒ tetap harus lewat prosedur aman (backup → ubah → validasi → `sync` → unmount/remount → verifikasi ulang sha)
5. **`OCUI: Failed to load image … - Not Found` sebagian besar normal** — OpenCanopy memeriksa sekumpulan ikon **opsional**,
   sedangkan set ikon resmi **tidak menyediakan** ikon tersebut (lihat §3.3). **Jangan buru-buru "melengkapi"**
6. **Jangan ikut mengubah tema** — ketika pengguna tidak meminta penggantian tampilan, `PickerMode`/`PickerVariant`/`PickerAttributes`/`Resources` tidak boleh disentuh
7. **Nama file ikon bersifat case-sensitive** (OpenCore membaca nama persis), dan jangan menaruh karakter aneh di FAT
8. **Ukuran 1x adalah nilai baku**, @2x diperbesar kelipatan tertentu; ukuran yang salah akan ditolak atau tampil dengan berubah bentuk

---

## 1. Tabel lengkap sakelar

### 1.1 `Misc > Boot > PickerMode`

| Nilai | Keterangan |
|---|---|
| `Builtin` | Antarmuka **teks biasa** bawaan OpenCore (default) |
| **`External`** | **Menggunakan protokol manajemen boot eksternal** (= OpenCanopy); bila tidak tersedia, **diam-diam kembali ke Builtin** |
| `Apple` | Menggunakan manajemen boot Apple (bila tersedia), mungkin melewati pemeriksaan kebijakan |

⇒ **OpenCanopy menuntut `External`**; sekaligus di `UEFI → Drivers` harus mengaktifkan **`OpenCanopy.efi`** (urutannya setelah `OpenRuntime.efi`).

### 1.2 `Misc > Boot > PickerVariant`

Nama direktori set ikon (relatif terhadap `Resources/Image`). Alias:

| Nilai | Efek |
|---|---|
| `Auto` | Dipilih otomatis mengikuti `DefaultBackgroundColor`: `Syrah Black` → `Acidanthera\GoldenGate`, `Light Gray` → `Acidanthera\Chardonnay` |
| `Default` | Setara dengan `Acidanthera\GoldenGate` |
| `Acidanthera\GoldenGate` / `Acidanthera\Syrah` / `Acidanthera\Chardonnay` | Ditentukan eksplisit (gaya macOS 11 / OS X 10.10 / Mac OS X 10.4) |

> Yang ditulis adalah **path relatif**, jadi pemisahannya memakai **backslash**.

### 1.3 `Misc > Boot > PickerAttributes` (bitmask, boleh dijumlahkan)

| Bit | Nama | Fungsi | Ketergantungan / Perhatian |
|---|---|---|---|
| `0x0001` | `OC_ATTR_USE_VOLUME_ICON` | Pakai ikon milik volume itu sendiri: cari `.VolumeIcon.icns` secara berurutan (per-volume di Preboot → root Preboot → root volume) | Menimpa pilihan ikon default "internal/eksternal" untuk disk tersebut |
| `0x0002` | `OC_ATTR_USE_DISK_LABEL_FILE` | Pakai judul pra-render di dalam `.disk_label` (`.disk_label_2x`) | Dihasilkan dengan `disklabel`; **path dan kapitalisasinya harus sama persis dengan config** |
| `0x0004` | `OC_ATTR_USE_GENERIC_LABEL_IMAGE` | Pakai **gambar label predefined** untuk entri tanpa item kustom | Seragam tetapi informasinya lebih sedikit |
| `0x0008` | `OC_ATTR_HIDE_THEMED_ICONS` | Untuk kategori tertentu **mengutamakan ikon bawaan** agar sesuai gaya tema (misalnya memaksa ikon Time Machine bawaan) | **Mensyaratkan `0x0001`** |
| `0x0010` | `OC_ATTR_USE_POINTER_CONTROL` | Mengizinkan pengoperasian pemilih dengan mouse/trackpad | Membutuhkan perangkat pointer (kelompok `UEFI>AppleInput`) |
| `0x0020` | `OC_ATTR_SHOW_DEBUG_DISPLAY` | Menampilkan informasi waktu tambahan/debug | **Hanya berlaku pada pemilih Builtin + build DEBUG/NOOPT** |
| `0x0040` | `OC_ATTR_USE_MINIMAL_UI` | Antarmuka minimal: **tidak menampilkan tombol shutdown/restart** | Berlaku untuk OpenCanopy maupun pemilih bawaan |
| `0x0080` | `OC_ATTR_USE_FLAVOUR_ICON` | Memilih ikon berdasarkan **content flavour** (bersama efek suara bantu) | Aturan Flavour lihat §4 |
| `0x0100` | `OC_ATTR_USE_REVERSED_UI` | Membalik posisi tombol shutdown/restart (mengikuti macOS lama) | Membutuhkan `0x0040` **tidak** disetel |

**Kombinasi umum**: `0` (default resmi) / `0x01` (ikon volume) / `0x81` (ikon volume + Flavour) / `0x90` (Flavour + kontrol pointer)

### 1.4 Sakelar lain yang memengaruhi tampilan

| Lokasi | Kunci | Keterangan |
|---|---|---|
| `Misc>Boot` | `ShowPicker` | Memaksa menampilkan pemilih (kalau tidak, boot langsung ke item default) |
| `Misc>Boot` | `Timeout` | Jumlah detik menunggu sebelum boot otomatis (`0` = tidak boot otomatis) |
| `Misc>Boot` | `TakeoffDelay` | Delay sebelum memproses pemilih/tombol pintasan (mikrodetik); sebagian keyboard butuh 5000–10000 |
| `Misc>Boot` | `HideAuxiliary` | Menyembunyikan recovery / Time Machine / item sistem (tekan **spasi** di Extended Mode untuk-expand) |
| `Misc>Boot` | `PickerAudioAssist` | Bantuan suara (membaca nama entri) |
| `Misc>Boot` | `ConsoleAttributes` | Bit warna foreground/background pemilih bawaan |
| `Misc>Security` | `AllowSetDefault` | Mengizinkan CTRL+Enter menetapkan item default (hanya bermakna bila ada `SetDefault.icns`) |
| `Misc>Security` | `ExposeSensitiveData` | `0x04` = menampilkan versi OpenCore di judul pemilih |
| `UEFI>Output` | `TextRenderer` | `SystemGraphics` / `BuiltinGraphics` / … (lihat §6.6) |
| `UEFI>Output` | `Resolution` | `Max` membuat renderer bawaan memakai resolusi penuh (prasyarat HiDPI) |
| `UEFI>Output` | `UIScale` | `1` normal / `2` HiDPI / `0` otomatis menurut luas piksel / `-1` tidak berubah |
| `UEFI>Output` | `ConsoleFont` | File font bitmap (`Resources/Font/*.bin`) |
| `UEFI>Output` | `ClearScreenOnModeSwitch`, `IgnoreTextInGraphics` | **Hanya berlaku untuk renderer `System*`** |
| `UEFI>Audio` | `AudioSupport`, `AudioDevice`, `AudioOutMask`, `MinimumAudibleGain` … | Pengaturan dasar untuk suara boot/bantuan suara |

### 1.5 ★ Tiga hubungan kombinasi yang mudah terjebak

1. **`0x0008` harus dipasangkan dengan `0x0001`** — `0x0008` sendirian tidak berlaku
2. **`ClearScreenOnModeSwitch` / `IgnoreTextInGraphics` hanya berlaku untuk renderer System** —
   bila `TextRenderer` diubah menjadi `BuiltinGraphics`, kedua sakelar ini akan **diam-diam tidak berlaku**
3. **HiDPI (`UIScale=2`) harus memakai sumber daya @2x**: blok @2x di dalam ikon `.icns`, label `.l2x`; kalau tidak, hasilnya kabur karena diperbesar

---

## 2. Struktur direktori sumber daya

```
EFI/OC/Resources/
├── Image/                      # set ikon (PickerVariant menunjuk ke sini)
│   └── Acidanthera/
│       ├── GoldenGate/         # setiap direktori = satu set ikon
│       ├── Syrah/
│       └── Chardonnay/
├── Font/                       # font bitmap (AngelCode binary BMF, .bin)
├── Label/                      # label pra-render (*.lbl = 1x, *.l2x = 2x)
└── Audio/                      # bantuan audio (*.mp3)
```

- Ikon predefined disimpan di **subdirektori turunan `PickerVariant`** (`EFI\OC\Resources\Image\<...>`)
- Set ikon bisa memakai **format vendor pihak ketiga** (`<vendor>\<set-ikon>`)

---

## 3. Daftar ikon (`.icns`)

Dokumentasi menyatakan: **semua ukuran adalah nilai baku pada skala 1x**, level skala lain diperbesar secara proporsional.
"Jika ikon opsional tidak ada, ikon yang paling mendekati akan dipakai"; untuk disk eksternal, versi berawalan `Ext` diutamakan (contoh: `OldExtHardDrive.icns`).

### 3.1 Ikon wajib (tanpanya OpenCanopy tidak bisa boot)

Diambil dari tanda **mandatory** pada bagian OpenCanopy + "System Icons / Required" di `Flavours.md`:

| Ikon | Ukuran (1x) | Kegunaan |
|---|---|---|
| `HardDrive.icns` | 128×128 | Sistem generik yang dapat di-boot (**Required, tanpanya OpenCanopy tidak start**) |
| `ExtHardDrive.icns` | 128×128 | Sistem yang dapat di-boot di disk eksternal (**Required**) |
| `Cursor.icns` | maksimal 144×144 | Pointer mouse |
| `Selected.icns` | 144×144 | Latar belakang item terpilih |
| `Selector.icns` | maksimal 144×40 | Kotak seleksi |
| `SetDefault.icns` | maksimal 144×40 | Penanda "jadikan default" (**lebarnya harus sama dengan `Selector`**) |
| `Left.icns` | 40×40 | Gulir ke kiri |
| `Right.icns` | 40×40 | Gulir ke kanan |
| `BtnFocus.icns` | — | Bingkai fokus tombol shutdown/restart |
| `Dot.icns` | — | Titik bulat kecil untuk input kata sandi |
| `Enter.icns` | — | Simbol konfirmasi input kata sandi |
| `Lock.icns` | — | Gembok kata sandi |
| `Password.icns` | — | Area input kata sandi |
| `Restart.icns` / `ShutDown.icns` | — | Tombol restart/shutdown tambahan |

### 3.2 Ikon opsional yang **disediakan** set ikon resmi (ada di OcBinaryData)

| Ikon | Ukuran | Fallback |
|---|---|---|
| `AppleRecv.icns` | 128×128 | → `HardDrive` |
| `AppleTM.icns` | 128×128 | → `HardDrive` |
| `ExtAppleRecv.icns` / `ExtAppleTM.icns` | 128×128 | → `ExtHardDrive` |
| `Windows.icns` | 128×128 | → `HardDrive` |
| `OpticalDrive.icns` | 128×128 | → `HardDrive` |
| `Other.icns` (entri kustom) | 128×128 | → `HardDrive` |
| `Shell.icns` (misalnya OpenShell) | 128×128 | → `Tool` |
| `Tool.icns` (tool lainnya) | 128×128 | → `HardDrive` |
| `NetworkBoot.icns` / `FirmwareSettings.icns` | 128×128 | — |

### 3.3 ★ Ikon opsional yang **tidak disediakan** set ikon resmi (pelaporan `Not Found` di log itu normal)

`Docs/Flavours.md` memiliki bagian tersendiri, yaitu **"Additional Optional — NOT provided by OcBinaryData"**:

| Ikon | Fallback |
|---|---|
| `Apple.icns` (macOS) | → `HardDrive` |
| `ExtApple.icns` | → `ExtHardDrive` |
| `ExtWindows.icns` | → `ExtHardDrive` |
| `ExtOpticalDrive.icns` | → `ExtHardDrive` |
| `ResetNVRAM.icns` | → `Tool` |
| `Background.icns` (gambar latar pemilih) | tidak ada (dipakai hanya jika disediakan) |

⇒ **`OCUI: Failed to load image … Apple.icns / ExtWindows.icns / ResetNVRAM.icns / Background.icns … - Not Found`
adalah fallback normal setelah OpenCanopy memeriksa ikon-ikon opsional tersebut**, bukan kerusakan sumber daya.
(Tiga set resmi **masing-masing hanya memiliki 25 `.icns`** — untuk menghilangkan baris-baris ini Anda harus menambahkan ikon sendiri.)

### 3.4 ★ Satu ketidaksesuaian antara dokumentasi dan paket sumber daya

`Docs/Flavours.md` mencantumkan **`Other`** di dalam "Optional — **Provided by OcBinaryData**",
tetapi **ketiga set resmi saat ini tidak punya `Other.icns`** (unduhan menghasilkan 404, dan log OC juga melaporkan `…\Other.icns - Not Found`).
⇒ Untuk mendapat ikon "entri kustom" Anda harus menyediakannya sendiri; **jangan diperbaiki seolah-olah sumber dayanya rusak**.
(`scripts/oc-theme-check.sh` akan langsung menampilkan perbedaan ini.)

---

## 4. Flavour: aturan pemilihan ikon dan suara

### 4.1 Kapan digunakan

Setelah mengaktifkan **`0x0080` (`OC_ATTR_USE_FLAVOUR_ICON`)** pada `PickerAttributes`:
ikon entri (OpenCanopy) dan suara entri (OpenCanopy + pemilih bawaan) ditentukan oleh **content flavour**.

**Tanpa `0x0080`**, yang berlaku adalah logika lama "cari ikon langsung sesuai tipe entri" (seperti `AppleRecv.icns`, `Windows.icns`).

### 4.2 Dari mana Flavour berasal

| Tipe entri | Sumber Flavour |
|---|---|
| **Tool** | Field `Flavour` milik entri di `Misc>Tools` |
| **Entri yang ditemukan otomatis** (termasuk entri yang dihasilkan protokol seperti `OpenLinuxBoot`) | Bila ada file `.contentFlavour` di samping bootloader, bacalah |
| **Entri kustom di `Misc>Entries`** | Saat `Flavour` = `Auto`, baca `.contentFlavour`; selain itu pakai nilai yang ditentukan field `Flavour` |
| Flavour yang terbaca adalah `Auto` atau tidak ada `.contentFlavour` | Pakai flavour default sesuai tipe entri |

- Sintaks nilai Flavour: **urutan nama yang dipisahkan `:` , total panjang ≤ 64 karakter**
- **Disk eksternal**: mendukung `Ext<Flavour>.icns` sekaligus `<Flavour>.icns`;
  **`Ext<Flavour>.icns` hanya dipakai bila disknya eksternal**; bila `Ext<Flavour>.icns` tidak ditemukan di disk eksternal,
  **demi keamanan OpenCore mundur ke `ExtHardDrive.icns`, bukan memakai `<Flavour>.icns`**
- **Prioritas**: bila keduanya ada, **`.VolumeIcon.icns` lebih diutamakan daripada `.contentFlavour`**

### 4.3 Rantai fallback

```
UEFIShell:Shell  →  UEFIShell.icns  →  Shell.icns  →  Tool.icns  →  HardDrive.icns
```

Artinya: **cari ikon menurut urutan flavour dari kiri ke kanan, jika tidak ditemukan teruskan turun**, akhirnya mundur ke tipe bawaan (tipe OS mundur ke `HardDrive.icns`).

### 4.4 Penamaan yang disarankan (pokok dari `Docs/Flavours.md`)

**macOS — dipilih otomatis menurut versi, biasanya tidak perlu menentukan manual**

- `Apple12:Apple` (Monterey) … `Apple11:Apple` (Big Sur) … `Apple10_15:Apple` (Catalina) … sampai `Apple10_4`
- **Recovery**: `AppleRecv11:AppleRecv:Apple11:Apple` (otomatis membawa nomor versi)
- **Time Machine**: `AppleTM11:AppleTM:Apple11:Apple` (**tidak** membawa nomor versi secara otomatis, harus ditentukan manual agar ditemukan)
- Dari sudut pandang pembuat ikon: **`Apple` disarankan untuk disediakan**, `AppleRecv` / `AppleTM` disarankan disediakan, sisanya opsional

**Windows — flavour dasar otomatis, versi harus manual**

- `Windows` (deteksi otomatis; fallback `HardDrive`)
- `Windows11:Windows`, `Windows10:Windows`, `Windows8_1:Windows` … perlu ditentukan manual (ditulis di dalam `.contentFlavour`)

**Linux / OS lain / bootloader — semuanya opsional**

- Linux: `Linux` (dasar) + tiap distro `Arch:Linux`, `Debian:Linux`, `Ubuntu:Linux`, `Lubuntu:Ubuntu:Linux` …
- Lainnya: `Android`, `BSD`, `FreeBSD:BSD`, `ReactOS`
- Bootloader: `Bootloader`, `Grub:Bootloader`, `OpenCore:Bootloader`

**Tool**

- **`Tool`** (ikon tool generik, disarankan disediakan; jika hilang fallback `HardDrive`)
- Tipe Shell: `Shell` / `UEFIShell:Shell` — bila hanya menyediakan satu, gunakan penamaan gaya umum `Shell.icns`,
  dan penamaan dengan teks tertentu `OpenShell.icns` / `UEFIShell.icns`

> `Docs/Flavours.md` menyatakan secara tegas: **daftar itu untuk konsistensi penamaan, bukan demanding set ikon menyediakan semuanya**.
> Secara resmi disarankan agar pembuat ikon "hanya menyediakan yang benar-benar dibutuhkan", dan yang tidak disediakan pada akhirnya akan fallback ke default OC.

### 4.5 Praktik praktis

1. **Hanya ingin mengganti ikon satu entri**: jangan sentuh `0x0080` secara global, tuliskan `Flavour` untuk entri itu di `Misc>Entries`
2. **Ingin sebuah disk selalu memakai ikon tertentu**: letakkan `.VolumeIcon.icns` di root volume (atau direktori per-volume Preboot), aktifkan `0x0001`
   — file ini **lebih diutamakan** daripada `.contentFlavour`, dan tidak memerlukan `0x0080`
3. **Ingin Windows menampilkan ikon Win11**: letakkan `.contentFlavour` di samping bootloader disk tersebut, isinya `Windows11:Windows` (memerlukan `0x0080`)
4. **Perubahan baru berlaku setelah restart**, verifikasi lewat baris `OCUI:` pada log OC (percobaan mencari ikon dan fallback akan tercetak)

---

## 5. Label / Font / Audio / Latar Belakang

### 5.1 Label (`Resources/Label`)

- Akhiran nama file `.lbl` (1x) / `.l2x` (2x); **semua label wajib ada**
- Kutipan langsung dari dokumentasi: **tinggi semua label harus tepat 12 px**, lebar tidak dibatasi; font adalah Helvetica 12 pt × faktor skala
- Alat pembuat: **`disklabel`** bawaan resmi (label pra-render) dan **`icnspack`** (mengemas `.icns`)
- Daftar label: `EFIBoot` (sistem generik), `Apple`, `AppleRecv`, `AppleTM`, `Windows`, `Other`, `ResetNVRAM`,
  `SIPDisabled`, `SIPEnabled`, `Shell`, `FirmwareSettings`, `Tool`
- Urutan fallback saat label pra-render tidak ada: teks di dalam `.contentDetails` (atau `.disk_label.contentDetails`) → nama entri itu sendiri

### 5.2 Font (`Resources/Font`)

- Format = **AngelCode binary BMF** (`.bin`)
- Rantai pembuatan yang disarankan secara resmi: **dpFontBaker** (hasil terbaik dengan CoreText) → ekspor biner dengan **fonverter**
- Tentukan file font lewat `UEFI>Output>ConsoleFont`; perender teks dan skalanya lihat §1.4 / §6.6

### 5.3 Bantuan audio (`Resources/Audio`)

- Letakkan `.mp3`; `Misc>Boot>PickerAudioAssist` mengaktifkan "bantuan suara" (membaca nama entri)
-bersama kelompok pengaturan kelompok pengaturan `UEFI>Audio` (§1.4)
- **Suara entri** ditentukan oleh **Flavour** (§4) — itulah salah satu fungsi `0x0080`
- "Suara boot" termasuk dalam lingkup `AudioBeep`/`AudioTone` milik `UEFI>Audio`, **dan bukan hal yang sama dengan tema**

### 5.4 Latar belakang dan palet warna

- `Background.icns` yang diletakkan di direktori set ikon = gambar latar yang terpusat (**tidak disediakan set resmi**)
- Warna latar ditentukan oleh NVRAM `4D1EDE05-38C7-4A6A-9CC6-4BCCA8B38C14:DefaultBackgroundColor`;
  `PickerVariant=Auto` akan memilih set ikon berdasarkan nilai itu

---

## 6. Troubleshooting

### 6.1 Lakukan dua hal lebih dulu

```bash
scripts/oc-theme-check.sh /Volumes/EFI/EFI/OC/Resources     # apakah sumber daya lengkap/patuh
grep -a "OCUI:" /Volumes/EFI/opencore-*.txt | tail -40      # proses sebenarnya saat OC memuat ikon
```

Baris `OCUI:` akan menyebutkan secara jelas "file mana yang dicari, percobaan ke berapa, berhasil atau Not Found" — **inilah satu-satunya dasar yang otoritatif**, jangan menebak.
(Bila `Misc>Debug>Target` mengandung `0x40`, log OC ditulis di `opencore-*.txt` pada ESP, lihat `logs-and-debug.md`.)

### 6.2 Sama sekali tidak melihat antarmuka grafis (masih antarmuka teks)

| Yang diperiksa | Harapan |
|---|---|
| `Misc>Boot>PickerMode` | Harus **`External`** |
| `UEFI>Drivers` | **`OpenCanopy.efi` sudah diaktifkan** (urutannya setelah `OpenRuntime.efi`) |
| `Resources/Image/<set-ikon>/` | Direktori ada dan **ikon wajib lengkap** (lihat §3.1) |
| `PickerVariant` | Direktori yang ditunjuk **benar-benar ada**; yang ditulis adalah path relatif (backslash) |
| Log OC | Ada `OCUI: Failed to load image …` yang menunjuk ikon **wajib** (itulah akar masalahnya) |

> Perilaku fallback: saat `External` tidak tersedia, sistem **diam-diam mundur ke antarmuka teks Builtin** — jadi "melihat antarmuka teks" itu sendiri sudah menjadi petunjuk.

### 6.3 Antarmuka sudah muncul, tapi ikon salah / generik

| Gejala | Penyebab | Penanganan |
|---|---|---|
| Sebuah sistem tampil sebagai ikon hard drive generik | Ikon tersebut **tidak disediakan** (atau flavour tidak kena) | Tambahkan ikon, atau letakkan `.contentFlavour` / `.VolumeIcon.icns` di disk tersebut |
| Ikon disk eksternal sama dengan disk internal | Tidak ada `Ext<Flavour>.icns` **di disk eksternal**, OC mundur ke `ExtHardDrive.icns` sesuai aturan keamanan | Tambahkan ikon versi `Ext*` |
| `0x0080` sudah disetel tapi tidak ada perubahan | `.contentFlavour` tidak **di samping bootloader**; atau field `Flavour` di `Misc>Entries` salah tulis | Lihat §4.2 |
| Ikon volume tidak berlaku | `0x0001` belum diaktifkan; atau `.VolumeIcon.icns` diletakkan di tempat yang salah | Letakkan di root volume / direktori per-volume Preboot; aktifkan `0x0001` |
| Ingin Time Machine memakai ikon bawaan | — | Aktifkan `0x0008` (**harus bersama `0x0001`**) |

### 6.4 Log penuh `Not Found` — jangan buru-buru memperbaikinya

Dua jenis umum dari `OCUI: Failed to load image … <nama>.icns prefix:<set-ikon> icon:N - Not Found`:

1. **`(1/2)` / `(2/2)`**: OpenCanopy pertama-tama mencoba direktori set ikon, lalu mencoba direktori dasar — baru dilaporkan bila keduanya gagal
2. **Namanya termasuk "Additional Optional"** (§3.3): **OcBinaryData resmi memang tidak menyediakan file-file tersebut** ⇒ baris-baris ini **adalah normal**

⇒ **Hanya ikon wajib yang melaporkan `Not Found` yang merupakan kegagalan.**

### 6.5 Ikon tampil berubah bentuk / terpotong / sangat buram

| Gejala | Penyebab |
|---|---|
| Terpotong | Ukuran 1x di dalam `.icns` tidak sesuai baku (lihat kolom ukuran di §3.1) |
| Lebar `Selector` / `SetDefault` tidak konsisten | Dokumentasi mensyaratkan `SetDefault` **harus selebar `Selector`** |
| Buram | HiDPI (`UIScale=2`) tetapi tidak ada sumber daya @2x |
| Label terentang | **Tinggi label harus tepat 12 px** (lebar tidak dibatasi) |

### 6.6 Teks terlalu besar / terlalu kecil / posisinya aneh

- `UEFI>Output>UIScale`: `1` normal / `2` HiDPI / `0` otomatis menurut luas piksel / `-1` tidak berubah
- `UEFI>Output>Resolution=Max` (renderer Builtin harus memakai resolusi penuh)
- `UEFI>Output>TextRenderer`: `SystemGraphics` memakai rendering firmware (`ClearScreenOnModeSwitch`/`IgnoreTextInGraphics` hanya berlaku padanya);
  `BuiltinGraphics` merender sendiri (mendukung HiDPI)
- Font: `UEFI>Output>ConsoleFont` menunjuk `Resources/Font/*.bin`

### 6.7 Tidak ada suara / bantuan suara tidak bekerja

| Yang diperiksa | Keterangan |
|---|---|
| `Resources/Audio/` | Ada `.mp3` |
| `UEFI>Audio>AudioSupport` | Aktif |
| `UEFI>Audio>AudioDevice` | Path perangkat benar (bisa disalin dari baris `OCAU: 1/3 …` di log OC) |
| `UEFI>Audio>AudioOutMask` | Bitmask kanal output; `-1` = semua kanal (bisa dicek di log lewat `HDA: | Port widget @ … (bitmask N)`) |
| `UEFI>Audio>MinimumAudibleGain` | Volume sistem yang lebih rendah darinya akan **tidak diputar** (`-128` = tanpa batas) |
| `Misc>Boot>PickerAudioAssist` | Sakelar utama bantuan suara |
| Suara entri | Ditentukan oleh **Flavour** (butuh `0x0080`) |

### 6.8 Perubahan tidak berlaku

- **Harus restart** (pemilih adalah komponen fase boot)
- Pastikan yang diubah adalah **config yang benar-benar dipakai saat boot**: `nvram 4D1FDA02-…:boot-path` menunjuk partisi mana
- Setelah mengubah ESP lakukan `sync` → unmount → remount (FAT punya write cache), lalu verifikasi ulang sha
- Direktori/nama file **sensitif terhadap kapitalisasi** (volume FAT tidak sensitif di macOS, tetapi OpenCore membaca nama persis)

### 6.9 ★ Peringatan keamanan

`Resources/` juga berada di ESP ⇒ perubahannya tetap lewat prosedur "backup → ubah → validasi → `sync`/unmount/remount → verifikasi ulang sha".
**Tema yang rusak dapat membuat pemilih tidak terlihat sama sekali** (kasus terburuk tidak bisa masuk sistem), jadi:

- Sebelum menyentuh apa pun, backup seluruh direktori `Resources/`
- Simpan satu set ikon yang **berfungsi** tanpa diubah (misalnya biarkan `Acidanthera\GoldenGate` apa adanya, buat direktori baru untuk tema baru)
- Jalan keluar: bila pemilih tidak bisa dimasuki, ubah `PickerMode=Builtin` (atau arahkan `PickerVariant` kembali ke set ikon semula)

---

## 7. Tool resmi terkait

| Tool | Kegunaan |
|---|---|
| `disklabel` | Menghasilkan `.disk_label` / `.l2x` (bekerja sama dengan `OC_ATTR_USE_DISK_LABEL_FILE`) |
| `icnspack` | Mengemas PNG menjadi `.icns` |
| Repositori `OcBinaryData` | Sumber daya siap pakai: set ikon / font / label / audio resmi |
| `scripts/oc-theme-check.sh` | Pemeriksaan kepatuhan pohon Resources (ikon wajib / blok ukuran aktual / label / font / audio) |
| `scripts/oc-fetch-iconset.sh` | Mengambil set ikon, font, label, audio dari OcBinaryData resmi |
