# Kustomisasi memori model MacPro

> ★★ **Pastikan modelnya dulu sebelum mulai —— jumlah slot berbeda per model**:
> **`MacPro7,1` = 12 slot** ("tabel pemetaan 12 slot" di dokumen ini hanya berlaku untuk model ini);
> **Model konsumen seperti `iMac20,1` = 4 slot**, cukup diisi seperti SMBIOS Type 17 biasa (Slot 1–4).
> Saat mengganti model, **`PlatformInfo>Memory>Devices` harus ikut dibuat ulang**, jika tidak diagram memori di "Tentang Mac ini" akan salah posisi
> ⇒ Lihat `smbios-and-serials.md` §3.1 item terkait ④. (`PlatformInfo > Memory`)

> Dasar: **rantai penyelesaian lengkap mesin ini 10-13 (v19 → v38)** + bukti dari mesin asli
> (output dmidecode Type 17 / system_profiler untuk MacPro7,1 dari `khronokernel/DarwinDumped` + peta slot dan peta konfigurasi resmi Apple,
> semuanya tersimpan di workspace `popup-memori-referensi-resmi-20261013/`).
>
> ★★ **Proses ini punya dua lapisan, jangan dicampur**:
> - **Lapisan A | System Information (System Report → Memory)** —— **semua model**: itu field SMBIOS Type 17 standar, macOS menyalin apa adanya
> - **Lapisan B | diagram memori di "Tentang Mac ini"** —— **khusus model MacPro**: penempatan pada diagram 12 slot itu (gambar kiri) ditentukan oleh **urutan array `Devices`**,
>   dan tabel pemetaan di bawah dengan `f` adalah inti lapisan ini

---

## 1. Tabel pemetaan 12 slot MacPro7,1 mesin asli (★ dasar Lapisan B, layak disimpan)

| Nomor slot | DeviceLocator mesin asli | Channel/DIMM |
|---|---|---|
| **1** | `Slot 1 (Channel F / DIMM 1)` | F1 |
| **2** | `Slot 2 (Channel F / DIMM 2)` | F2 |
| **3** | `Slot 3 (Channel E / DIMM 1)` | E1 |
| **4** | `Slot 4 (Channel E / DIMM 2)` | E2 |
| **5** | `Slot 5 (Channel D / DIMM 1)` | D1 |
| **6** | `Slot 6 (Channel D / DIMM 2)` | D2 |
| **7** | `Slot 7 (Channel A / DIMM 2)` | **A2** |
| **8** | `Slot 8 (Channel A / DIMM 1)` | A1 |
| **9** | `Slot 9 (Channel B / DIMM 2)` | **B2** |
| **10** | `Slot 10 (Channel B / DIMM 1)` | B1 |
| **11** | `Slot 11 (Channel C / DIMM 2)` | C2 |
| **12** | `Slot 12 (Channel C / DIMM 1)` | C1 |

- 12 slot = **6 channel × 2 DIMM**; kelompok atas 1–6 = channel F/E/D, kelompok bawah 7–12 = channel A/B/C
- ★ Pada setiap pasangan kelompok bawah, **DIMM2 di depan, DIMM1 di belakang** (7=A2, 8=A1), inilah bagian yang paling mudah terbalik
- Mesin asli (tipe 8 core) Type 16: `Number Of Devices = 12`, `Maximum Capacity 4606 GB`, ECC Single-bit
- **Apple resmi hanya mendukung 4 / 6 / 8 / 10 / 12 keping**; **4 keping = slot 3, 5, 8, 10** (satu per channel, slot gelap di gambar resmi x4)
  ⇒ **2 keping termasuk konfigurasi non-resmi**, macOS akan menampilkan "disarankan dipasang berpasangan, minimal empat" + tanda `!` dari konsultan —— **ini perilaku mesin asli, tidak bisa dihilangkan dengan menukar posisi** (agar benar-benar bersih, harus memakai konfigurasi resmi 4 keping)

## 2. ★★ Aturan Lapisan B: penempatan = nomor array → posisi gambar tetap

Diagram "Tentang Mac ini → Memory" menggambar **entri ke-j dari `PlatformInfo/Memory/Devices` ke posisi gambar ke-f(j) yang tetap**:

```
f = [8, 7, 10, 9, 12, 11, 5, 6, 3, 4, 1, 2]      ← sama persis dengan urutan tabel SMBIOS Type 17 mesin asli
```

| Entri ke-j | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Digambar ke posisi** | 8 | 7 | 10 | 9 | 12 | 11 | 5 | 6 | 3 | 4 | 1 | 2 |

- **Kenapa mesin asli benar**: tabel Type 17 pada firmware mesin asli **memang sudah berurutan f** ⇒ posisi gambar v menampilkan `Slot v` ⇒ diagram dan daftar "System Information" **konsisten secara alami**
- **Kenapa diurutkan 1..12 jadi salah posisi**: posisi gambar v menampilkan entri ke-`f⁻¹(v)` pada array ⇒ diagram dan daftar tidak cocok
  (pengukuran di mesin ini: terpasang di entri ke-2/8, di diagram muncul di 6/7)
- **Cara yang benar (tiga langkah)**:
  1. Nomor slot memakai **nomor mesin asli** (1=F1 2=F2 3=E1 4=E2 5=D1 6=D2 7=A2 8=A1 9=B2 10=B1 11=C2 12=C1), **bukan** nomor urut 1..12
  2. **Array `Devices` diurutkan sesuai f** (entri ke-1 = `Slot 8`, entri ke-2 = `Slot 7`, …, entri ke-12 = `Slot 2`)
  3. Dengan begitu "posisi gambar v = `Slot v` = baris ke-v pada daftar", **keduanya selalu konsisten**, dan posisi instalasi apa pun tetap konsisten
- **Bukti tambahan**: tangkapan layar resmi Apple untuk 6-DIMM (slot 1,3,5,8,10,12 terisi memori) dalam urutan f menempati entri ke-11,9,7,1,3,5 pada array → posisi gambar 1,3,5,8,10,12, **cocok persis dengan tangkapan layar resmi per posisi**
- **Satu kontra-contoh (hemat waktu)**: **pada layout motherboard konsumen 4 slot, gambar kiri di "Tentang Mac ini" tidak menggambar nomor dan tidak menandai pemakaian** (tiga putaran verifikasi v24/v26/v27 pada mesin ini)
  ⇒ **agar gambar kiri menunjukkan "keping mana yang terisi memori", struktur 12 slot Mac Pro wajib dipakai**

> Alat validasi: `scripts/mem-check.sh <config.plist>` —— membaca array `Devices`, menghitung dengan f **ke posisi gambar mana setiap entri akan digambar**,
> lalu langsung memberi tahu "apakah urutan array sudah benar" (nomor slot tidak cocok dengan posisi prediksi = akan salah posisi).

## 3. Lapisan A: field "System Information" (semua model)

Field pada `PlatformInfo > Memory` persis SMBIOS Type 16/17 standar, **tidak bergantung pada model**:

| Tingkat | Field | Perhatikan |
|---|---|---|
| Top-level | `Devices[]` | Satu memori = satu dict; **slot kosong juga harus dicantumkan** (struktur Sample resmi) |
| Top-level | `MaxCapacity` | ★ **satuan adalah bytes** |
| Top-level | `Type` / `FormFactor` / `DataWidth` / `TotalWidth` / `ErrorCorrection` | Lihat dokumentasi OpenCore `PlatformInfo → Memory Properties` |
| Per entri | `DeviceLocator` | ★ **string inilah yang ditampilkan di System Report** |
| Per entri | `BankLocator` | Kosong ⇒ tanpa prefix; **tidak kosong** ⇒ ditampilkan sebagai `BankLocator/DeviceLocator` |
| Per entri | `Size` / `Speed` / `Manufacturer` / `SerialNumber` / `PartNumber` / `AssetTag` | ★ nama kuncinya adalah **`SerialNumber`** (bukan `Serial`) |

**Aturan penamaan (hasil pengukuran mesin asli)**: nama yang ditampilkan di System Report = **`DeviceLocator` itu sendiri** (misalnya `Slot 7 (Channel A / DIMM 2)`);
empat item slot kosong pada mesin asli adalah `Size: Empty / Type: Empty / Speed: Empty / Status: Empty`,
sementara `Manufacturer / Serial Number / Part Number` semuanya **`NO DIMM`**.

> ★ **Dua lapisan bisa diatur terpisah**: Lapisan B (penempatan) hanya memengaruhi diagram di "Tentang Mac ini"; daftar Lapisan A **menampilkan apa pun yang ditulis pada array**.

## 4. Kondisi nyata mesin ini dan konfigurasi final

- Fisik mesin ini: ASUS TUF Z690-PLUS D4, **4 slot (A1/A2/B1/B2)**, SPD terbaca **dua keping 16GB Kingston KHX2666C16/16G di A2 / B2**
  (slot ke-2 channel A, slot ke-2 channel B)
- **Pemetaan paling setia secara fisik** = **Slot 7 (Channel A / DIMM 2) + Slot 9 (Channel B / DIMM 2)** (yaitu A2 + B2)
- **Pilihan akhir pengguna** = **Slot 8 + Slot 2** (keping ke-2 kelompok atas + keping ke-2 kelompok bawah, satu per compartment memori, simetris secara visual)
- **Berlaku sekarang = v38**: 12 entri `Devices`, **array diurutkan sesuai f**; terpasang `Slot 8` + `Slot 2` (masing-masing diisi **nomor seri asli keping memorinya**),
  10 slot sisanya `NO DIMM`; `MaxCapacity = 68719476736` (64 GB, satuan bytes)
- **Kembalikan** = `config.plist.v16-MacPro71-CPUFriend` (**tanpa** bagian `PlatformInfo/Memory`)

## 5. Jebakan yang pernah dialami (semua ditulis di sini, jangan coba lagi)

| Jebakan | Fakta |
|---|---|
| Mengira "nomor slot = nomor urut array" | **Nomor urut array menentukan posisi gambar** (lihat §2), nomor slot harus memakai nomor mesin asli |
| v32 membuat `SPMemoryReporter` crash (menampilkan "terjadi kesalahan saat mengumpulkan informasi ini") | Saat itu masih "**`BankLocator` kosong + penamaan `Slot N` polos**"; kombinasi yang berhasil pada mesin asli adalah "**`BankLocator` kosong + string Locator lengkap**" (terverifikasi OK sejak v34) |
| Ingin menghilangkan peringatan "minimal empat" dengan menukar posisi | **Tidak bisa dihilangkan** —— itu perilaku tetap macOS untuk konfigurasi non-resmi seperti "2 keping", mesin asli juga sama |
| Pengguna melihat "kedua posisi tidak konsisten" | Kenyataannya **animasi konsultan** (bukan masalah konfigurasi); dalam keadaan stabil keduanya konsisten |
| Menggunakan layout motherboard konsumen 4 slot | Gambar kiri **tidak menggambar nomor, tidak menandai pemakaian** ⇒ visualisasi "keping mana yang terisi memori" tidak didapat |
| `MaxCapacity` ditulis dalam GB | **satuan adalah bytes** |
| Nama kunci ditulis `Serial` | Yang benar adalah **`SerialNumber`** |

## 6. Metode verifikasi

```bash
# Lapisan A: daftar System Information (harus 12 baris, dua keping terpasang punya kapasitas, sisanya Empty)
system_profiler SPMemoryDataType | head -60

# Lapisan B: hitung dari array di config posisi gambar yang akan dipakai, lalu bandingkan dengan nomor slot
scripts/mem-check.sh /Volumes/EFI/EFI/OC/config.plist
```

Lalu **bandingkan secara visual**: slot mana saja yang terisi memori pada gambar kiri "Tentang Mac ini → Memory" harus cocok dengan `Slot v`, dan juga cocok baris per baris dengan daftar System Information.
