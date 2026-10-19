# Mengaktifkan / Menonaktifkan E-core (Arsitektur hybrid Intel: P-core / E-core)

> Dasar: **`CpuTopologyRebuild` README resmi** (`b00t0x/CpuTopologyRebuild`, dikutip per butir, lihat §8)
> + **Pengukuran lokal 10-15** (perilaku `ProvideCurrentCpuInfo`, nama item BIOS, perbandingan papan Geekbench 7 resmi untuk CPU yang sama).
> ★ **Kesimpulan terlebih dahulu**: **"Menonaktifkan E-core" dan "mengaktifkan E-core" adalah dua pilihan yang berbeda, bukan salah satu lebih benar** ——
> **Mematikan adalah yang paling stabil** (macOS memang tidak mampu menjadwalkan E-core dengan baik, mematikannya hampir tidak menimbulkan kerugian); **membiarkannya menambah 4 core 4 thread** (tapi harus bergantung pada `CpuTopologyRebuild`
> untuk merapikan topologi, dan README resmi secara eksplisit menyatakan **konflik dengan `-v`**, lihat §4.3).

## 0. Terminologi dan mekanisme

- **E-core = E-core (Efficient Core)**, P-core = **P-core (Performance Core)**. Diperkenalkan sejak Intel generasi ke-12 (Alder Lake).
- Lokal **i7-12700K = 8 P + 4 E**, P-core punya hyper-threading ⇒ konfigurasi penuh **12 core 20 thread**.
- **macOS tidak mendukung arsitektur hybrid secara lengkap**, tiga langkah:
  1. Harus mengandalkan **`Kernel > Quirks > ProvideCurrentCpuInfo = true`** agar E-core bisa "diberi makan" ke kernel
     (kalimat asli README resmi: *"OpenCore's `ProvideCurrentCpuInfo` quirk enables Alder Lake's both P-Cores and E-Cores,
     but all cores and threads are recognized as equivalent"*);
  2. Namun setelah masuk, **P-core dan E-core dianggap setara** ⇒ bisa menghambat single-thread / performa aktual;
  3. Jika ingin membedakan ⇒ tambahkan **`CpuTopologyRebuild.kext`** untuk membangun ulang topologi (§4).
- Tidak diberi makan (`ProvideCurrentCpuInfo=false`) **atau** E-core dimatikan di BIOS ⇒ macOS hanya melihat **8 core 16 thread**.

> ★ **Jangan salah tafsir sebagai "CPU kekurangan core"**: `CPUID.1FH` (topologi hybrid) melaporkan **20 logical processor** saat **E-core diaktifkan**,
> sedangkan sisi macOS hanya melaporkan 8 core 16 thread itu **normal**, bukan hardware kekurangan core, dan bukan juga driver gagal dimuat.

## 1. Tentukan kondisi saat ini (ukur dulu, baru ubah)

```bash
sysctl -n hw.ncpu hw.physicalcpu hw.logicalcpu        # 16 = hanya P-core; 20 = P+E sama-sama diekspos
sysctl -n hw.nperflevels                              # 1 = hanya satu jenis core; 2 = dua tingkat P/E dikenali
sysctl -n hw.perflevel0.physicalcpu                   # jumlah P-core (lokal 8)
sysctl -n hw.perflevel1.physicalcpu                   # jumlah E-core (lokal 4; kunci ini tidak ada saat E-core dimatikan)
sysctl -n machdep.cpu.core_count                      # lihat -ctrfixcnt di §4.2
```

`scripts/e-cores-check.sh` menjalankan semuanya sekaligus dan memberikan interpretasi.

| `hw.nperflevels` | `hw.ncpu` | Arti |
|---|---|---|
| **1** | 16 | macOS hanya melihat satu jenis core ⇒ **E-core tidak diekspos** (BIOS dalam keadaan mati, atau `ProvideCurrentCpuInfo=false`) |
| 2 | 20 | Dua tingkat P / E dikenali ⇒ **E-core sudah aktif** (lihat ke bawah untuk hasil pembangunan ulang topologi) |

★ **Jangan "memperbaiki" saat `hw.nperflevels=1`** —— lihat §7, itu mungkin kondisi stabil yang memang sengaja dipilih pada mesin ini.

## 2. Menonaktifkan E-core (direkomendasikan untuk "mencari stabilitas / tidak mau repot")

**Satu-satunya cara yang andal adalahعله di level BIOS** (tidak ada sakelar "menyembunyikan E-core" di sisi macOS):

| Produsen | Lokasi / Nama |
|---|---|
| **ASUS** (lokal) | `Advanced > CPU Configuration > **Active Efficient Cores**` → setel **`0`** |
| MSI | `OC → Advanced CPU Configuration → **E-Core Count**` (atau `Active E-Cores`) → `0` |
| Gigabyte | `Settings > Advanced CPU Settings → **E-Core Count**` → `0` |
| ASRock | `Advanced → CPU Configuration → **Active E Cores**` → `0` |

- **Sisi konfigurasi tidak perlu diubah**: `ProvideCurrentCpuInfo` biarkan apa adanya; `CpuTopologyRebuild` tetapkan `Enabled=false` (atau hapus entri).
- **Manfaat**: di macOS, scheduling E-core pada Alder Lake memang merupakan wilayah berbahaya (§7.2), mematikannya **hampir tidak menimbulkan kerugian performa** (macOS memang tidak bisa memanfaatkannya sepenuhnya).
- **Biaya**: berkurangnya 4 core / 4 thread —— tetapi **jika memang tidak pernah terpakai, mematikan sama sekali tanpa biaya**.
- ★ **Prasyarat wajib tidak boleh diubah**: `Active Performance Cores` = `All`, `Hyper-Threading` = `Enabled`,
  **`Intel Speed Shift Technology` tetap `Enabled`** (mematikannya memicu `wrmsr(0x770,1)` #GP panic, lihat `intel-turbo.md` §7).

## 3. Mengaktifkan E-core (mencari performa / siap merapikan topologi)

Tiga hal, berurutan:

1. **BIOS**: `Active Efficient Cores` → **`All`** (nama per produsen ada di tabel §2).
2. **config**: `Kernel > Quirks > **ProvideCurrentCpuInfo = true**` (**wajib** — README resmi secara eksplisit menyatakan
   Alder Lake / Raptor Lake membutuhkan quirk ini; hanya Arrow Lake yang tidak).
3. **Opsional tetapi direkomendasikan**: tambahkan **`CpuTopologyRebuild.kext`** di `Kernel > Add`, **tepat setelah `Lilu`**
   (ini plugin Lilu, `OSBundleLibraries` mensyaratkan `as.vit9696.Lilu ≥ 1.2.0`) ⇒ urutan `Lilu → CpuTopologyRebuild → …`.

Setelah restart seharusnya terlihat `hw.nperflevels=2`, `hw.ncpu=20`, `perflevel1.physicalcpu=4` (§1).

★ **`ProvideCurrentCpuInfo` dan pengecualian `-ctrfixcnt`**: jika memakai `-ctrfixcnt`, **wajib** memasang
`AppleMCEReporterDisabler.kext` juga, jika tidak **tidak bisa boot** (§4.2).

## 4. `CpuTopologyRebuild` —— membangun ulang "20 core setara" menjadi "8P + 4E"

### 4.1 Apa yang dilakukannya

- Mendukung **Alder Lake / Raptor Lake / Arrow Lake (eksperimental)**.
- Perilaku default = **menyamar E-core sebagai "logical thread SMT jalur ke-N" dari P-core**, menghasilkan scheduling yang lebih baik;
  **"System Information" menampilkan jumlah core sebenarnya (P+E)**.
- ★ Batas yang diakui resmi: *"The effect of this kext is not yet clear"* —— ada manfaat terukur, tetapi **resmi tidak menjamin**.

### 4.2 Empat nilai (boot-arg atau NVRAM, pilih salah satu)

Domain NVRAM = **`4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102`** (`NVRAM > Add` OpenCore).

| Kunci NVRAM | boot-arg | Efek |
|---|---|---|
| (tidak diisi) | (tidak diisi) | **Default**: topologi disamarkan sebagai SMT, E-core dikenali sebagai logical thread jalur-N dari P-core; System Information menampilkan jumlah core sebenarnya (P+E) |
| `ctrsmt` = `"off"` | **`ctrsmt=off`** | Tidak menyamar, topologi = struktur sebenarnya, **performa menurun**; hanya efektif untuk Alder/Raptor **dengan HT aktif**; setara perilaku default v1.x.x |
| `ctrsmt` = `"full"` | **`ctrsmt=full`** | System Information hanya menampilkan **jumlah P-core**; dampak performa tidak pasti; setara perilaku v1.x.x dengan **`-ctrsmt`** |
| `ctrfixcnt` = `true` | **`-ctrfixcnt`** | Mengaktifkan koreksi `machdep.cpu.core_count`; ★ **wajib memasang `AppleMCEReporterDisabler.kext` juga, jika tidak tidak bisa boot** |

> ★★ **Jebakan sintaks**: **v2.x memakai `ctrsmt=off` / `ctrsmt=full` (bentuk dengan tanda sama dengan)**,
> sedangkan **`-ctrsmt` pada v1.x adalah hal lain** (setara `ctrsmt=full` pada v2.x). Menyalin `-ctrsmt` dari posting lama ke v2.x tidak akan error, tetapi **tidak berlaku**.
> ⇒ **Lihat dulu nomor versi kext yang Anda pasang** (`CFBundleVersion`, lokal = **2.0.2**).

### 4.3 ★★ Konflik yang diketahui: konflik dengan `-v`

Bagian *Current problems* di README resmi menyatakan:

> *"May cause random boot failure with verbose (`-v`) boot"*

⇒ **E-core aktif + `-v` berpotensi menyebabkan boot gagal secara acak**. Alur debug pada mesin ini **mewajibkan `-v`** (aturan besi 13)
⇒ **Saat troubleshoot, matikan E-core dulu, atau hapus sementara `-v`**, jangan salah tafsir kegagalan acak sebagai konfigurasi rusak.
(Catatan tambahan: `ProvideCurrentCpuInfo` sendiri tidak berlaku di High Sierra dan sebelumnya; saat itu gunakan `patches_legacy.plist` resmi.)

### 4.4 Perbandingan topologi (tabel asli README resmi, cuplikan 12700K)

| CPU | Konfigurasi | Asli | `ctrsmt=off` | **Default (tidak diisi)** |
|---|---|---|---|---|
| **i7-12700K** | **8P+4E+HT** | 20c20t | 12c20t | **8c20t** |
| i7-12700K | 8P+4E (HT mati) | 12c12t | 8c12t | 8c12t |
| i9-12900K | 8P+8E+HT | 24c24t | 16c24t | 8c24t |
| i9-13900K | 8P+16E+HT | 32c32t | 24c32t | 8c32t |

★ **Cara membaca**: kolom default menggabungkan seluruh 20 thread **pada 8 P-core** ("8c20t"), E-core tidak muncul sendiri ——
inilah arti "disamarkan sebagai SMT"; `ctrsmt=off` itulah struktur sebenarnya "12 core 20 thread".

## 5. Verifikasi (setelah diubah dan restart)

1. `scripts/e-cores-check.sh` —— topologi + frekuensi + interpretasi (**fokus pada apakah `hw.nperflevels` berubah jadi 2**).
2. **`kextstat` / `kmutil showloaded`** harus memuat `org.b00t0x.CpuTopologyRebuild`, dan **setelah Lilu**.
3. **`ocvalidate` = No issues found** (wajib dijalankan setelah mengubah `Kernel>Add`).
4. **Perbandingan benchmark**: Geekbench single-core / multi-core, **perbandingan pada mesin yang sama** dengan baseline "E-core dimatikan" (jangan membandingkan antar mesin, lihat §7.3).
5. ★ **Jangan sampai frekuensi turun**: `scripts/cpu-freq-probe.sh` —— baseline single-thread ≈ 4,28, 8 thread ≈ 4,29–4,35 GHz;
   bila frekuensi turun setelah E-core diaktifkan, artinya pembangunan ulang topologi bentrok dengan XCPM, lakukan rollback.

## 6. Rollback (tiga pilihan, cukup pilih salah satu)

1. **Tercepat**: setel `Active Efficient Cores` kembali ke **`0`** di BIOS —— **konfigurasi tidak perlu diubah satu baris pun**.
2. **Hanya ingin melepas kext**: setel entri `CpuTopologyRebuild` ke **`Enabled=false`** (atau hapus entri + pindahkan kext, lihat aturan besi 6).
3. **Tidak bisa boot**: kembalikan config dari cadangan (`scripts/oc-edit-safe.sh`) + rescue EFI lewat U disk.

## 7. Pengukuran lokal dan trade-off (10-15)

### 7.1 Kondisi saat E-core dimatikan (terukur)

- macOS hanya melihat **8 core 16 thread**: `hw.ncpu=16`, `hw.nperflevels=1`, `hw.perflevel0.physicalcpu=8`;
  sedangkan `CPUID.1FH` melaporkan **20 logical processor** (sub0 SMT=2 / level Core sub1=20, tanpa level Module/Tile) ⇒ **E-core ada secara fisik, hanya tidak diberi makan ke macOS**.
- `CpuTopologyRebuild` saat itu ada di `Kernel>Add` tetapi **`Enabled=false`** ⇒ manfaat yang disebut resmi, yaitu "bekerja sama dengan `ProvideCurrentCpuInfo`", tidak bisa diperoleh.

### 7.2 ★ Mengapa "mematikan" juga bisa jadi pilihan yang benar

- Scheduling E-core di macOS pada Alder Lake **memang wilayah berbahaya** (kernel tidak punya dukungan scheduling hybrid yang lengkap);
- "Menambah 4 core" tidak sama dengan "lebih cepat 4 core" — jika kernel menganggap E-core sebagai P-core saat memberikan tugas, tugas single-thread / sensitif latensi justru melambat;
- ⇒ **Mematikan adalah "default berisiko rendah"**; jika ingin mengaktifkan, `CpuTopologyRebuild` harus ikut digunakan, dan Anda harus menerima konflik `-v` di §4.3.

### 7.3 Perbandingan dengan papan (**ada keterbatasan, jangan dipakai sebagai bukti kuat**)

Papan Geekbench 7 resmi untuk CPU yang sama (i7-12700K, `Family 6 Model 151 Stepping 2`):

| Platform | Thread | Single-core | Multi-core |
|---|---|---|---|
| macOS (**E-core dimatikan**) 4 entri | 16 | 941–980 | 5132–5714 |
| macOS (**E-core aktif**) 1 entri | 20 | **1393** | **7672** |
| Windows 12 entri | — | 2007–2351 | 7761–17781 |
| Linux 4 entri | — | 2162–2540 | 10330–19535 |

- Entri dengan E-core aktif **+47% single-core / +37% multi-core** dibanding E-core dimatikan; pada perbandingan per item, **`HTML5 Browser` dan `PDF Viewer` persis 2,0x**
  — kedua item ini memang framework-intensive dan menurunkan thread pembantu, **konsisten dengan "4 E-core tambahan tersedia"**.
- ★ **Keterbatasan**: hanya **1** sampel dengan E-core aktif, dan **bukan mesin ini**; membandingkan "skor" lintas platform terkontaminasi memori / OS / versi
  (entri Windows memakai DDR5 quad-channel, mesin ini DDR4 dual-channel) ⇒ **hanya sebagai acuan arah, akhirnya A/B pada mesin ini yang menentukan**.
- ★ Data ini **membantah kesimpulan lama** bahwa "E-core dimatikan ⇒ `CpuTopologyRebuild` adalah no-op" (belum ada pengukuran saat itu).

### 7.4 Status penerapan "E-core aktif" pada mesin ini (10-15 05:06)

- Sudah dilakukan: salin kembali `CpuTopologyRebuild.kext` (v2.0.2) dari `_kexts-removed-20261014/` ke `EFI/OC/Kexts/`;
  sisipkan entri `Enabled=true` di `Kernel>Add`, **tepat setelah Lilu** (index 1); `ProvideCurrentCpuInfo` tetap `true`.
  Verifikasi: `plutil` OK · **`ocvalidate` 1.0.8 = No issues found** · diff semantik hanya 1 tempat (Add 19→20) · sha unload/remount konsisten.
- **Belum dilakukan (BIOS, hanya manual)**: `Active Efficient Cores = All` → F10.
- **Langkah berikutnya yang opsional**: tambah **`ctrsmt=full`** bila topologi default tidak ideal (**hanya satu variabel per waktu**, lihat aturan besi 5).

## 8. Sumber resmi

- `b00t0x/CpuTopologyRebuild` → `README.md` (Usage / tabel Options / Internal topology examples / Current problems).
- OpenCore `Configuration.pdf` → `Kernel > Quirks > ProvideCurrentCpuInfo`.
- ★ Indeks ekosistem dan alat lain ada di `ecosystem-sources.md`; pembatas frekuensi CPU / turbo ada di `intel-turbo.md`;
  perbandingan nama item BIOS ada di `bios-settings.md` §8.
