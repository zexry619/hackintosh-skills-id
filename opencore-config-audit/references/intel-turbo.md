# Intel Turbo (Turbo Boost)—— dari "tertekan di frekuensi rendah" sampai konfigurasi terbaik

> Dasar: loop praktis lengkap di mesin ini sejak 10-13 (**diagnosis → eliminasi → perbaikan CPUFriend → perbandingan penuh 76 profile model →
> rollback percobaan gagal iMac19,1 → konfigurasi final**) + `Instructions.md` resmi CPUFriend / `Tools/ResourceConverter.sh`
> + hasil dekode seluruh 76 `Mac-*.plist` di `X86PlatformPlugin`.
> ★ **Alat verifikasi pakai CPU-S** (ditentukan pengguna), dikuatkan silang dengan Intel Power Gadget dan probe buatan sendiri.

## 0. ★★★ Metode terbaik (sudah final di mesin ini — baca ini dulu)

**Jangan coba "ganti profile model untuk menaikkan batas frekuensi"** — jalur ini **sudah terbukti tidak berhasil** di mesin ini.
**Cara yang benar = inject "profile milik mesin ini sendiri, hanya hapus `hwp`"**, paksa macOS memakai XCPM P-state tradisional.

| Item | Nilai final |
|---|---|
| Data yang di-inject | **profile model mesin ini sendiri** (`iMac20,1` ⇒ `Mac-CFF7D910A743CAAF.plist`), **hapus hanya item `hwp`** |
| Jumlah segmen `FrequencyVectors` | **1 segmen** (tiap segmen konstan 7668 B) |
| Batas atas `Frequencies` | `4500` (**plafon keluarga 1 segmen**) |
| `CPUFloor` | `1300` (cocok dengan CPU mesin ini) |
| **`hwp`** | **sudah dihapus** ← ★★ **item paling penting** |
| Frekuensi terukur | 1 thread **4.28–4.35 GHz**; 8 thread **4.29–4.35 GHz**, delapan core konsisten, tanpa osilasi |

⇒ **Keempatnya harus kena semua agar disebut "terbaik", kurang satu saja berarti mundur atau gagal** (kriteria di §5).

### 0.1 ★★ Kesimpulan negatif (sudah dicoba, sudah bayar mahal)

**Inject profile model lain apa pun akan menekan turbo sampai rusak**:

| Yang dicoba | Hasil |
|---|---|
| `iMac19,1` (batas atas 5000, terlihat menggoda) | **1.97 GHz** (turun ~54%, bahkan lebih rendah dari rekor terendah) ⇒ sudah di-rollback |
| `MacPro7,1` (native `hwp='on'`) | **2.3 GHz** (sekitar separuh performa) |

⇒ **Semua perubahan yang menyangkut profile manajemen daya di mesin ini, secara default tidak boleh disentuh.**

Peringatan resmi di `Instructions.md` memang benar (**kutipan asli**):

> *"most likely NOT required"*
> *"Do not use CPUFriend for data customization until one knows clearly what power management data really is"*
> *"If possible, changing SMBIOS … can be more reasonable"*

## 1. Pastikan gejalanya dulu (tiga alat saling menguatkan)

| Alat | Yang dilihat | Hasil di mesin ini (sebelum diperbaiki) |
|---|---|---|
| **★ CPU-S** (alat komunitas, di sini pakai v4.3.2) | `Device Model` / `Processor Model` / **`Current Turbo State`** / jumlah step frekuensi / daftar frekuensi terukur | `MacPro7,1` / `12thGen i7-12700K` / **`No Turbo`** / 10 step / hanya terukur `100 / 700–1500 MHz` |
| Intel Power Gadget | CORE `MAX/AVG/MIN/REQ`, daya PKG, suhu | `MAX 3.9 / AVG 2.25 / MIN 0.7 / REQ 2.97 GHz`; PKG 58 W; 50 ℃ |
| Probe buatan sendiri (`scripts/cpu-freq-probe.sh`) | Frekuensi terukur 1 thread / 8 thread | 1 thread 2.24–2.54, 8 thread 2.2–2.3 GHz |

**Cara baca CPU-S**: yang paling penting adalah **"Current Turbo State"** — menampilkan **No Turbo** dan daftar frekuensi hanya sampai 1.5 GHz berarti frekuensi dibatasi;
setelah diperbaiki harus menampilkan **Turbo**, dan daftar frekuensi mencakup step multiplier tinggi.

**Baseline acuan (i7-12700K)**: turbo 1 core **5.0 GHz** / semua core sekitar **4.7 GHz** / frekuensi dasar **3.6 GHz**
⇒ 2.3 GHz terukur berarti **bahkan frekuensi dasar pun tidak tercapai**, hanya sekitar separuh performa.

> ★ **Jebakan pada benchmark buatan sendiri**: clang `-O2` akan **meng-fold** hukum dependensi yang sudah di-unroll (pernah menghasilkan nilai absurd 8.34 / 11.03 GHz).
> Untuk mengukur frekuensi harus memakai **inline assembly yang mem-pin** (`cpu-freq-probe.sh` memakai rantai dependensi dengan `mulsd` dan delay 4 siklus tetap).

## 2. Eliminasi dulu, jangan buru-buru menyentuh profile

| Item | Kriteria |
|---|---|
| Thermal throttling | `sysctl machdep.xcpm.cpu_thermal_level` harus **0** (di mesin ini cpu/gpu/io semua 0, suhu 39–55 ℃ sangat dingin) |
| Batas atas XCPM dikunci | `machdep.xcpm.hard_plimit_max_100mhz_ratio` / `soft_...` / `bootpst` (di mesin ini = **49** ⇒ 4.9 GHz, normal) |
| Badai log / beban latar belakang | `uptime`, `iostat`, `vm_stat` (★ `ps` / `top` di mesin ini diblokir kebijakan, jadi pakai ini) |
| Baru saja dinyalakan | Cek dulu apakah hanya terjadi di 10–15 menit pertama |
| ★★ **Profile diubah tapi tidak reboot** | Lihat §7 — **penyebab "sudah diperbaiki tapi kok begitu" yang paling umum** |

## 3. Cari akar masalah: `FrequencyVectors` + `hwp` pada profile model

Profile berasal dari **`X86PlatformPlugin.kext/Contents/Resources/Mac-<board-id>.plist`** (di mesin ini total **76**,
setelah dedup **62 data berbeda**).

**★ Semua perbedaan hanya ada di 5 dimensi**:

| Dimensi | Penjelasan |
|---|---|
| `pmspFile` | 1–16, indeks internal plugin |
| `CPUFloor` | 1300 / 1200 / 1000 / 800 / tidak ada |
| `Frequencies` | tabel step, **nilai = indeks segmen** (bukan tabel MHz itu sendiri) |
| `FrequencyVectors` | **tiap segmen konstan 7668 B**; **jumlah segmen = kompleksitas** |
| **`hwp`** | ★★ **dikemas di dalam biner vektor**, **bukan kunci plist** ⇒ `plutil` / `PlistBuddy` tidak menemukannya (lihat §4) |

Format: `FrequencyVectors` adalah serialisasi **packed (rapat)** dari `xcpmio_vectors_t`
⇒ bisa dipakai untuk **memeriksa apakah data yang di-inject terpotong** lewat "hasil dekode harus **7668 B/segmen**".

> ⚠️ **Dua jebakan parsing** (keduanya pernah dilewati):
> ① Nilai `FrequencyVectors` adalah **list dari objek bytes** (`[b'\x02\x00…']`), **bukan satu bytes tunggal**
> ⇒ Kesimpulan "tidak ada FrequencyVectors" biasanya berarti skripnya salah tulis;
> ② `hwp` **bukan kunci plist**, di 76 plist tersebut `grep hwp` **nol hit** — jangan karena itu mengira `hwp` tidak ada.

## 4. ★★★ Posisi asli `hwp` dan cara menghapusnya (langkah paling penting)

`hwp` **tidak ada di plist**, melainkan ada di dalam **tabel nama variabel pada biner vektor 7668 B di offset ~7128**, berbentuk

```
… io_core_cst_lim … hwp "on" …
```

- **Cara menonaktifkan = hapus item ini** (bukan diganti nama! mengganti nama akan meninggalkan string dan panjang pun berubah); setelah dihapus **semua item berikutnya maju satu posisi**.
- Yang terpasang di mesin ini sekarang: **165 byte lebih pendek** dari segmen native, yaitu **7128–7544**, jumlah kemunculan `hwp` di dalam segmen **1 → 0**,
  segmen native mulai dari `hwp` sedangkan yang terpasang sekarang langsung mulai dari `io_core_cst_lim`.
- **Ini adalah penggunaan CPUFriend standar**: inject "profile mesin ini dengan `hwp` dihapus" untuk menimpa yang bawaan sistem,
  **memaksa macOS memakai XCPM P-state tradisional, bukan HWP** ⇒ 4.33 GHz di mesin ini adalah hasil dari sana.

> ★★ **Menilai "apakah DataProvider ini berguna" wajib dengan membandingkan biner vektor byte per byte** —
> hanya membandingkan `pmspFile` / `Frequencies` / jumlah segmen / kunci plist lalu menyimpulkan akan **salah penilaian**
> (di mesin ini sempat salah menilai sebagai "no-op", baru dikoreksi setelah perbandingan byte per byte).

## 5. ★ Keputusan pemilihan: lima keluarga dari 76 profile (pakai panduan ini saat ganti mesin)

**Pembatas utama = jumlah segmen**:

| Keluarga | Ciri | Jumlah | Hasil terukur |
|---|---|---|---|
| **A** | tanpa step + **1 segmen** + tanpa `hwp` | 25 (`iMacPro1,1`) | **4.28–4.35 GHz ✓** |
| **B** | tanpa step + **1 segmen** + **ada `hwp`** | 2 (`MacPro7,1`) | **2.3 GHz ✗** |
| **C** | ada step + **1 segmen** | 5 (`iMac20,1` / `20,2`, batas atas 4500) | **4.33 GHz ✓ sedang dipakai mesin ini** |
| **D** | ada step + **multi segmen (2–5)** | 32 (`iMac19,1` 4 segmen, semua MBP) | **1.97 GHz ✗ gagal saat diuji** |
| **E** | **0 segmen** | 12 | tanpa vektor, tidak usable |

**★ Dua kausalitas yang berasal dari perbandingan alami** (bukan dugaan):

- **`iMacPro1,1` vs `MacPro7,1` hanya berbeda satu item `hwp`** (kunci lain / jumlah segmen / `pmspFile` / `CPUFloor` identik)
  ⇒ tanpa `hwp` = 4.3 GHz, ada `hwp` = 2.3 GHz — **efek `hwp` terisolasi satu per satu**.
- **`iMac19,1` vs `iMac20,1` hanya berbeda "4 segmen vs 1 segmen"** (himpunan kunci / `CPUFloor` / `hwp` identik)
  ⇒ **akar masalah crash = tabel vektor CFL multi segmen, bukan `hwp`** (koreksi: sebelumnya menyalahkan `hwp` adalah keliru).

**★★ Jalan buntu struktural**: **semua profile dengan batas atas 5000 punya 3–5 segmen, tidak ada yang 1 segmen**
⇒ **"menaikkan batas atas ke 5000" dan "kompatibel secara struktural" saling bertentangan pada mesin seperti ini**.
⇒ **Plafon keluarga 1 segmen adalah 4500**, yang terpasang di mesin ini sudah puncak; **mau lebih optimal lagi, tidak ada profile yang bisa dipakai**.

## 6. Cara memperbaiki: CPUFriend + CPUFriendDataProvider (mekanisme resmi)

1. **Ambil plist profile**: secara default ambil **milik model mesin ini sendiri** (`Mac-<board-id mesin ini>.plist`),
   lalu gunakan `Tools/ResourceConverter.sh` resmi untuk membuat `CPUFriendDataProvider.kext`:
   - Masukkan **seluruh plist model sebagai base64** ke `IOKitPersonalities/CPUFriendDataProvider/cf-frequency-data`
   - Selain itu perlu: `IOClass=AppleACPICPU`, `IONameMatch=processor`, `IOProbeScore=1100`, `OSBundleRequired=Root`
   - ★ **`ExecutablePath` harus kosong**
   - ★ `Instructions.md` resmi: yang diletakkan di `cf-frequency-data` adalah **complete plist** (bukan `FrequencyVectors` telanjang)
2. **★ Hapus `hwp`** (§4) — inilah langkah pembeda antara mesin ini dan "tidak melakukan apa-apa"
3. Tambahkan dua entri di `Kernel → Add`, **urutan: Lilu → CPUFriend → CPUFriendDataProvider → VirtualSMC**
   - ★ **`CPUFriend.kext` harus berada setelah `Lilu.kext`** (ini plugin Lilu)
4. ★ **`ocvalidate` memberi batasan karakter pada `Kernel>Add>Comment`**:
   `iMacPro1,1 ... (no HWP) ~2.3GHz` akan dianggap `illegal character` (koma / kurung / tanda tilde, minimal salah satu)
   ⇒ Komentar hanya boleh berisi **huruf dan angka, spasi, tanda hubung, titik**
5. Validasi: hasil dekode `FrequencyVectors` harus **7668 B/segmen**; `ocvalidate` = No issues found; sha identik setelah unload lalu mount ulang

> **Teknik perubahan minimum**: saat ingin mencoba profile lain, **salin `Info.plist` yang sedang dipakai, ganti hanya `cf-frequency-data`**
> ⇒ diff hanya satu bagian, rollback cukup menyalin kembali filenya.

## 7. ★★ Harus reboot setelah perubahan (penyebab nomor satu "sudah diperbaiki tapi kok begitu")

- Profile dibaca ke memori **saat boot** ⇒ **tanpa reboot, yang jalan di memori masih versi lama**.
- Pengalaman di mesin ini: setelah rollback ke nilai yang benar, pengguna tidak pernah reboot, hasil uji 1 thread masih **2.22 GHz** (harusnya 4.28–4.33)
  ⇒ **Di ESP nilainya sudah benar sejak awal, perbaikannya hanya "reboot"**.
- **Kriteria**: `sysctl -n kern.boottime` — **lebih awal dari waktu perubahanmu ⇒ belum reboot**.
- ★ Bukti tambahan: **bahkan kalau "unload lalu mount ulang untuk verifikasi sha" gagal, penulisan ke ESP tetap tersimpan**
  (saat profile berbahaya, sha memang bernilai kandidat, membuktikan bahwa tulisannya masuk) ⇒ **jangan menyamakan "verifikasi ulang gagal" dengan "tidak tertulis"**.

## 8. Verifikasi (setelah reboot)

- **★ CPU-S**: `Current Turbo State` harus berubah dari "No Turbo" menjadi **Turbo**, daftar frekuensi mencakup step multiplier tinggi
- **Probe**: `scripts/cpu-freq-probe.sh` — baseline mesin ini **1 thread 4.28 / 8 thread 4.29–4.35 GHz**,
  dan **delapan core sangat konsisten, tanpa osilasi**
- **Perbaikan yang lebih penting dari angkanya**: sebelum diperbaiki, frekuensi 8 core **naik-turun tidak stabil (step frekuensi rendah ↔ osilasi frekuensi penuh)**;
  setelah diperbaiki **8 core konsisten**, osilasi hilang — **inilah sumber langsung dari "lag / frame drop"**
- Periksa juga: model tidak berubah, `Processor Name` benar, `CPUFriend (1.3.0)` sudah dimuat dan berada setelah Lilu, **tidak ada panic baru**,
  `machdep.xcpm.mode=1`, `hard_plimit_max=49`
- **Ganti model ⇒ wajib ulang DataProvider** (`Frequencies` / jumlah segmen / `CPUFloor` berubah mengikuti model)

## 9. Masih ingin mengejar frekuensi penuh (4.3 → 5.0 GHz)?

**Jalan ini buntu, jangan habiskan waktu lagi** (§0.1 + §5):

- Sisa selisih tidak bisa dijelaskan oleh batas atas profile — `hard_plimit_max = 49` (4.9 GHz) memang tidak dikunci,
  artinya **`Frequencies` belum tentu menjadi plafon frekuensi yang sebenarnya**; keuntungan ganti profile **belum terbukti** dan **risikonya sudah terukur**.
- Alasan sebenarnya kemungkinan besar adalah **power wall PL1/PL2** atau **perbedaan sisi OS**:
  CPU yang sama di macOS umumnya sekitar **2.4× lebih rendah** dari Windows / Linux (acuan daftar peringkat Geekbench 7 resmi untuk `Family 6 Model 151`)
  ⇒ **Selisihnya ada di sisi OS, bukan di silikon, juga bukan di CPUFriend**.
- ★ Sikap resmi jelas: **"kalau tidak yakin, jangan pakai CPUFriend"**, di mesin ini sudah tidak ada lag ⇒ **tidak disarankan menambah risiko lagi**.

## 10. ★ Prasyarat mutlak: Speed Shift di BIOS harus aktif

`Intel(R) Speed Shift Technology` **harus `Enabled`** (**`Auto` juga bisa berarti nonaktif secara efektif**):

```
HWP tidak tersedia ⇒ wrmsr(0x770,1) memicu #GP ⇒ xcpm_hwp_enable crash (panic type 13)
```

Di mesin ini sudah dua kali terjadi panic akibat "SpeedShift dinonaktifkan lagi" sejak 10-13
⇒ **Saat menemukan panic terkait `X86PlatformShim` / `xcpm_hwp_enable`, hal pertama yang dicek adalah item BIOS ini**.

> ★ **Jangan tertukar**: HWP (Speed Shift) di BIOS **harus dinyalakan** (kalau tidak, panic),
> sedangkan sisi macOS **sengaja tidak memakai HWP** (memakai XCPM P-state tradisional)
> ⇒ Kombinasi = **firmware menyalakan HWP + macOS memakai XCPM tradisional**, ini solusi benar yang sudah diverifikasi, **jangan di"perbaiki"**.

## 11. Status mesin ini dan cara mundur

- **Sekarang (terbaik, jangan diganti)**: `CPUFriend 1.3.0` + `CPUFriendDataProvider`
  (data = **profile milik `iMac20,1` itu sendiri dan `hwp` sudah dihapus**), **sha `5952ea56…`**;
  backup yang dipakai `_CPUFriendDataProvider-terbaik-iMac20,1-hwp-dihapus-20261015-172126/`
- **Cadangan (tanpa edit manual)**: `iMacPro1,1` **native tanpa `hwp`** (keluarga A), hasil uji juga 4.28–4.35 GHz,
  bisa langsung menggantikan (`_CPUFriendDataProvider-iMacPro11-cadangan/`)
- **Rollback** = salin `Info.plist` backup ke `EFI/OC/Kexts/CPUFriendDataProvider.kext/Contents/` (atau pakai EFI rescue dari flashdisk)
- **Skrip probe**: `scripts/cpu-freq-probe.sh` (4.28–4.35 GHz di mesin ini normal)
- Step E core adalah **hal lain** ⇒ `e-cores.md`
- ★ Singkirkan dulu konflik yang diketahui antara `CpuTopologyRebuild` dan `-v`, baru nilai "apakah profile-nya yang rusak" (`e-cores.md` §4.3)
