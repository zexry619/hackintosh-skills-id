# Nama tampilan CPU (nama processor di "Tentang Mac ini") —— cara mengubahnya

> Dasar: **`README.md` resmi RestrictEvents** (dikutip per butir, lihat §9) + rantai tertutup lengkap mesin ini 10-13
> (gejala → lokalisasi → perbaikan → verifikasi setelah restart).
> ★ **Tentukan dulu**: ini **murni masalah tampilan**, tidak memengaruhi performa / fungsi / set instruksi.
> ⇒ **Pikirkan dulu apakah layak diubah sebelum mengubah**: nama yang biasanya salah hanya berarti "nama hasil pemetaan model ≠ model sebenarnya".

## 0. Satu kalimat

Nama yang ditampilkan di "Tentang Mac ini → Processor" dan "System Information → Hardware → Processor Name"
**bukan dibaca langsung dari CPUID, melainkan dipetakan oleh macOS berdasarkan model (SMBIOS)**
⇒ pilihan model yang salah akan memunculkan nama salah seperti "i7-12700K tampil sebagai Intel Xeon W".

**Cara ubah = tiga komponen RestrictEvents: `revpatch=cpuname` + `revcpu=1` + `revcpuname=<nama kustom>`.**

## 1. Lihat kondisi sekarang (tiga perintah)

```bash
system_profiler SPHardwareDataType | grep -E "Processor Name|Chip|Total Number of Cores"
sysctl -n machdep.cpu.brand_string      # string merek yang dilaporkan CPU asli (dari CPUID)
sysctl -n hw.model                      # model saat ini
```

**Kriteria**: `Processor Name` dan `machdep.cpu.brand_string` **tidak cocok** ⇒ inilah masalah yang dibahas dokumen ini.

> Contoh pada mesin ini: `Processor Name: 8-Core Intel Xeon W` (pemetaan `MacPro7,1`),
> sedangkan CPU sebenarnya adalah `12th Gen Intel(R) Core(TM) i7-12700K`;
> item lainnya (3.6 GHz / 8 core / L2 1.3 MB / L3 25 MB) **semuanya benar** ⇒ hanya nama tampilannya yang salah.

## 2. Peran masing-masing kunci (kutipan asli README resmi)

| Kunci | Deskripsi resmi | Penjelasan |
|---|---|---|
| **`revpatch=cpuname`** | *"`cpuname` - custom CPU name in System Information"* | **Saklar utama** —— tanpa ini, dua kunci di bawah tidak berlaku |
| **`revcpu=1`** | *"`revcpu=value` to enable (`1`, non-Intel default)/disable (`0`, Intel default) CPU brand string patching"* | ★★ **pada CPU Intel nilai default-nya `0` (mati)** ⇒ **harus ditulis eksplisit `revcpu=1`** |
| **`revcpuname=value`** | *"custom CPU brand string (max **48 characters**, **20 or less recommended**, taken from CPUID otherwise)"* | Nama kustom; **batas 48 karakter, disarankan ≤20** |

★ `revpatch` adalah opsi **dipisahkan koma**:
`memtab` · `pci` · `cpuname` · `diskread` · `asset` · `sbvmm` · `f16c` · `none` · `auto`
(`auto` = `memtab,pci,cpuname`, dan **pada Mac asli tidak menerapkan `memtab` / `pci`**).

## 3. ★★ Jebakan terbesar: prioritas NVRAM **lebih rendah** daripada boot-args

Kutipan asli Note dari README resmi:

> *"`4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:revpatch`, `…:revcpu`, `…:revcpuname` and `…:revblock`
> NVRAM variables work the same as the boot arguments, **but have lower priority**."*

⇒ **Menulis `cpuname` hanya di NVRAM tidak berguna** —— selama boot-args juga berisi `revpatch=...`, **boot-args yang berlaku**.

**Pengalaman langsung di mesin ini**: NVRAM berisi `revpatch='sbvmm,cpuname'`, boot-args berisi `revpatch=sbvmm`
⇒ yang berlaku adalah boot-args (**tanpa `cpuname`**) ⇒ **namanya tidak pernah berubah**.
**Perbaikannya = `revpatch=` di dalam boot-args juga harus memuat `cpuname`** (misalnya `revpatch=sbvmm,cpuname`).

### 3.1 ★ `revcpuname` hanya boleh di NVRAM (karena mengandung spasi)

boot-args **dipisah berdasarkan spasi** ⇒ `revcpuname=8-Core Intel Core i7-12700K` akan terpecah menjadi beberapa parameter dan **terpotong**.

⇒ **Pembagian tugas**: **`revcpuname` ditulis di NVRAM** (`NVRAM > Add > 4D1FDA02-…`), **`revpatch` / `revcpu` ditulis di boot-args**.

## 4. Cara ubah lengkap (terverifikasi pada mesin ini)

1. **`NVRAM > Add > 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102`**
   - `revcpuname` = string, misalnya `8-Core Intel Core i7-12700K`
   - (opsional, untuk pengaman) `revcpu` = `1`, `revpatch` = `cpuname`
2. Pastikan **`NVRAM > Add > 7C436110-…:boot-args`** memuat **`revpatch=cpuname`** dan **`revcpu=1`**
   (★ semula `revpatch=sbvmm`, ubah menjadi **`revpatch=sbvmm,cpuname`**)
3. ★ **Kunci-kunci ini juga harus muncul di `NVRAM > Delete`** —— aturan OpenCore: kunci yang ada di `Add` **harus sekaligus ada di `Delete`** agar berlaku
4. Pastikan **`RestrictEvents.kext` sudah dimuat** (plugin Lilu ⇒ **harus berada setelah Lilu**)
5. `ocvalidate` → **restart** → periksa ulang tiga perintah di §1

## 5. ★ `ProcessorType` harus dipasangkan dengan jumlah core

Kutipan asli Note dari README resmi:

> *"Apple CPU identifier must be `0x0F01` for 8 core CPUs or higher and `0x0601` for 1, 2, 4, or 6 cores.
> This is the default in OpenCore for non-natively supported CPUs."*

- **Lokasi: `PlatformInfo > Generic > ProcessorType`** (★ ada di dalam `Generic`, **bukan** di level atas `PlatformInfo`)
- Nilai pada mesin ini = **`3841` = `0x0F01`** (8 core ke atas) ✓ **jangan diubah**
- Gejala kalau ditulis salah: **ikon CPU salah / jumlah core yang ditampilkan aneh** (bukan masalah nama)

## 6. Cara menyusun nama (berdasarkan pengalaman)

- **Gaya Apple**: `<N>-Core Intel Core i7-12700K` (dipakai pada mesin ini, 27 karakter)
- Batas **48**, disarankan **≤20** ⇒ nama yang terlalu panjang bisa terpotong
- ★ **Jangan** menulis `revcpuname` yang mengandung spasi ke dalam boot-args (§3.1)
- Kalau ingin lebih aman: `revcpuname` hanya berisi model (`Intel Core i7-12700K`), biarkan sistem sendiri yang merangkai jumlah core

## 7. Salah paham yang umum (jangan ambil jalur yang keliru)

| Pikiran | Fakta |
|---|---|
| "Mengubah `Kernel > Emulate > Cpuid1Data` sudah cukup untuk mengganti nama" | **Tidak bisa**. String merek CPU berada di daun **CPUID `0x80000002–0x80000004`**, sedangkan `Cpuid1Data` mengubah **leaf 1** (model / stepping / bit fitur) ⇒ **tidak memengaruhi string merek**. `Cpuid1Data = 0x000A0655` pada mesin ini (ADL→Comet Lake) ditujukan untuk **kernel**, tidak terkait nama tampilan |
| "Ubah saja `AppleSystemInfo.strings` / string lokalisasi" | **Metode lama, jangan dipakai**. macOS modern memakai **sealed system volume (SSV)** ⇒ harus mematikan SIP + merusak tanda tangan system volume; **RestrictEvents justru lahir untuk menggantikannya** |
| "Ganti nama model sudah pasti benar" | Kadang efektif (pemetaan benar maka namanya benar), tapi **mengganti model adalah perubahan berantai** (tiga kode / SSDT / CPUFriend / slot memori, lihat `smbios-and-serials.md`) ⇒ **tidak layak mengganti model hanya untuk mengganti nama**; `revcpuname` adalah cara tanpa efek samping |
| "Nama salah berarti CPU salah dikenali" | Belum tentu —— frekuensi, jumlah core, L2/L3, set instruksi **semuanya benar**, hanya **nama tampilan** yang mengikuti pemetaan model |
| "`revpatch=auto` sudah cukup" | `auto` **memang memuat `cpuname`**, tetapi ① `revpatch` lama kamu bisa saja ditulis `sbvmm` dan menimpanya (§3); ② `revcpu=1` **masih harus ditambahkan eksplisit** di Intel |

## 8. Pencarian masalah

| Gejala | Pemeriksaan |
|---|---|
| `revcpuname` sudah ditambahkan tapi nama tidak berubah | ① **Apakah `cpuname` ada di boot-args** (§3 jebakan prioritas —— **paling umum**); ② Apakah ada **`revcpu=1`** (default Intel 0); ③ Apakah `RestrictEvents.kext` sudah dimuat; ④ **Apakah sudah direstart** |
| Nama berantakan / terpotong | `revcpuname` melebihi 48 karakter, atau **ditulis ke boot-args sehingga terpecah oleh spasi** (§3.1) |
| "Tentang Mac ini" berubah tapi "System Information" tidak (atau sebaliknya) | Keduanya diambil dari jalur berbeda; patch `cpuname` terutama bekerja pada **System Information** ⇒ **yang jadi acuan adalah "System Information → Hardware"** |
| Ikon CPU / jumlah core salah | `ProcessorType` tidak dipasangkan dengan jumlah core (§5) |
| Ingin membatalkan | Hapus `cpuname` dan `revcpuname` (atau tambahkan `revpatch=none`) → restart |

## 9. Sumber

- `acidanthera/RestrictEvents` → `README.md`:
  tabel opsi `revpatch` · `revcpu` · `revcpuname` (batas 48 karakter) · **Note prioritas NVRAM** · **Note CPU identifier**.
- Terkait: `smbios-and-serials.md` (nama model ditentukan oleh kode produk nomor seri —— **itu hal lain**, jangan dicampur) ·
  `intel-turbo.md` (frekuensi CPU / profil model) · `bios-settings.md` (sisi BIOS).
- Alat pemeriksaan mandiri: `scripts/cpu-name-check.sh`.
