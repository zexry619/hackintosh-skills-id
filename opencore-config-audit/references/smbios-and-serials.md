# SMBIOS Ganti Model + Tiga Kode (serial / MLB / UUID / ROM)

> Dasar: pengalaman praktis pada 10-12 dan 10-13 di mesin ini (`SMBIOS-huanji-zhixing-jilu-20261012.md`, `DECISION-jixing-SMBIOS-20261012.md`,
> `SMBIOS-sanma-genghuan-20261013/`, `SMBIOS-Tahoe-qiehuan-20261013/`, `try-smbios-macpro71.sh`) + Dortania
> "Choosing the right SMBIOS" dan README resmi USBToolBox.
>
> ★★ Satu kalimat: **ganti model bukan "mengubah 4 kunci", itu merupakan perubahan yang saling terkait** — juga melibatkan prasyarat ACPI/SSDT, data `CPUFriend`,
> **jumlah slot pada injeksi memori**, serta nama tampilan di "Tentang Mac Ini".
> ★★★ **Dan ganti model harus sekaligus mengganti tiga kode**: nama model **terpisahkan** dari SMBIOS, itu merupakan **fungsi dari kode produk nomor seri** (lihat §1.3).
> Tiga kode (terutama ROM) juga secara langsung menentukan apakah iMessage/FaceTime bisa digunakan. **Ikuti urutan di bawah ini, lakukan satu set lengkap sekaligus.**

---

## 1. Keputusan lebih dulu: kapan sebaiknya ganti model

| Dimensi | Kesimpulan |
|---|---|
| Manfaat fungsional (di bawah macOS 15 Sequoia) | **Nol** — Dortania: `iMacPro1,1` dan `MacPro7,1` adalah **hanya** dua model "yang menyerahkan seluruh beban ke dGPU" ⇒ keduanya setara |
| Biaya | Butuh serial / MLB / UUID baru; **board-id berubah ⇒ seluruh jalur terkait AGDP/AGDC berubah**; iMessage / FaceTime perlu login ulang |
| Risiko | ★ **Mengotori baseline A/B yang sedang berjalan** (misalnya eksperimen BAR1 / ghosting) — melanggar "hanya ubah satu hal" dan "selama ada perubahan, gejala lama dan baru tidak bisa dibedakan" |
| **Saat naik ke macOS 26 Tahoe** | Model Intel yang didukung Apple untuk Tahoe hanya tersisa 4: iMac 27″ 2020, MBP 16″ 2019, MBP 13″ 2020, **Mac Pro 2019 = `MacPro7,1`**; **`iMacPro1,1` sudah dikeluarkan**. **Namun ini bukan alasan untuk "ganti model sambil upgrade"** — lihat di bawah |

### 1.1 ★★ Dua jalur, **default-nya pakai yang pertama**

| | **A. Pertahankan model lama + bypass lewat boot-arg** (**default**) | B. Ganti ke model dalam daftar putih |
|---|---|---|
| Cara | Tambahkan `-no_compat_check` (bisa boot) + `revpatch=sbvmm` (bisa menerima update OTA), tidak satu pun field model yang diubah | Ganti ke `MacPro7,1` |
| Risiko upgrade | **Rendah** (hanya boot-args yang disentuh) | Tinggi (**prasyarat ACPI/SSDT** + board-id + CPUFriend + **tiga kode** berubah bersamaan) |
| Apakah terkait dengan upgrade | ✅ **Terpisah** — saat upgrade hanya boot-args yang disentuh | ❌ Terikat |

> ★★ **"Tidak boleh mengubah model saat upgrade sistem" adalah batasan keras** (`SKILL.md` aturan besi 16).
> Alasan: ganti model **bukan "mengubah 4 kunci", melainkan perubahan yang saling terkait** (lihat §2, §3) —
> hal ini melibatkan **perubahan board-id yang memicu parsing ulang ACPI** (§2), pembangunan ulang volume sistem, perubahan XCPM profile, **tiga kode dan nama komputer** (§1.3 / §3.2).
> **Upgrade itu sendiri sudah merupakan operasi berisiko tinggi, jangan menumpuk perubahan terkait kedua dalam putaran yang sama.**
>
> ⇒ **Ganti model adalah keputusan tersendiri, lakukan secara terpisah**; **jangan pernah** menyisipkannya ke dalam upgrade tersebut.

### 1.2 Bagaimana prosesnya pada mesin referensi (dijelaskan agar tidak salah paham)

Mesin referensi **mengalami dua pergantian model secara independen**, keduanya bukan "diubah sambil upgrade":

| Waktu | Model | Yang dilakukan |
|---|---|---|
| 10-13 | `iMacPro1,1` → **`MacPro7,1`** | Ikuti alur lengkap §2: tangani dulu SSDT `xh_adls3` → ganti SMBIOS → buat ulang `CPUFriendDataProvider` |
| 10-15 | `MacPro7,1` → **`iMac20,1`** | ★ **Tiga kode diganti bersamaan** (baru dilengkapi kali ini; lihat pelajaran di §1.3) + buat ulang CPUFriend + injeksi memori diubah ke 4 slot + ubah nama komputer |

⇒ Jadi kemunculan "mesin referensi pernah ganti model" dan "saat upgrade tidak boleh ganti model" di dokumen **tidak saling bertentangan**:
**yang pertama adalah hasil keputusan mandiri, yang kedua adalah disiplin saat upgrade.**

> ★ Urutan kedua pergantian tersebut selalu: **bersihkan dulu lapisan ACPI/SSDT → baru ganti model → baru lengkapi item turunan** (§2.7).
> Yang 10-15 punya satu aturan tambahan: **ganti model harus mengganti tiga kode sekaligus** (lihat di bawah).

### 1.3 ★★★ Ganti model **wajib** ganti kode — nama model di "Tentang Mac Ini" adalah **fungsi dari nomor seri**

**Hasil uji nyata (10-15)**: model sudah diubah menjadi `iMac20,1`, tetapi "Tentang Mac Ini" **masih menampilkan `Mac Pro (2019)`**.
Setelah menelusuri ke mana-mana, akhirnya ditemukan sumbernya — hal itu **tidak berkaitan dengan `SystemProductName`**:

| Bukti | Kesimpulan |
|---|---|
| Setelah mengosongkan `~/Library/Preferences/com.apple.SystemProfiler.plist` lalu membuka ulang "Tentang Mac Ini", dan diturunkan kembali dengan **nomor seri yang sama**, **`P7QM-… = "Mac Pro (2019)"` tetap ditulis kembali** | Nama ditentukan oleh **nomor seri**, terpisah dari model |
| `macserial -i <serial>` langsung memberikan `SystemModel` (nama pemasaran) | Kode produk → nama pemasaran adalah **pemetaan satu-ke-satu** |
| Kunci cache adalah `ModelNames["<4 digit terakhir nomor seri>-<locale>"]`, field validasinya adalah `cachedSerial` | **Ganti model tidak membuat cache menjadi tidak valid** |

**Tabel kode produk (hasil uji nyata)**:

| Kode produk nomor seri | Model yang sesuai | Tampilan "Tentang Mac Ini" |
|---|---|---|
| `P7QM` | MacPro7,1 | Mac Pro (2019) |
| `PN5T` | iMac20,1 | iMac (Retina 5K, 27-inch, 2020) |

⇒ **Ganti model tanpa mengganti kode, "Tentang Mac Ini" akan selalu tertahan di nama model lama.** Ganti model dan ganti tiga kode adalah **dua bagian dari satu tindakan yang sama**, lakukan bersama.

- ★ **Sebelum mengganti kode, konfirmasi dulu kode produknya dengan `macserial -i <serial>`** (jauh lebih cepat daripada membuka "Tentang Mac Ini" belakangan)
- ★ Plist itu hanya **cache**: **menghapusnya tidak akan "memperbaiki" nama tampilan** — nama tetap akan diturunkan kembali dari nomor seri yang sama
- ★ Urutan penelusuran: **nama tampilan salah ⇒ lihat dulu kode produk nomor seri, lalu cache, baru terakhir mencurigai config**

## 2. ★★ Apa sebenarnya yang membuat mesin ini "tidak bisa masuk sistem": BIOS SSDT khas motherboard

### 2.1 Gejala

Setelah diganti ke `MacPro7,1`, proses boot berjalan sangat jauh, **lalu loop restart** (**bukan hang** ⇒ "tunggu saja lebih lama" tidak berguna).

### 2.2 Akar masalah (terkunci lewat pengujian)

**Pada mesin ini (ASUS Z690) ada satu OEM SSDT di dalam BIOS, `OEM Table ID = xh_adls3`.**
Ganti model (board-id berubah) memicu macOS **mengurai ulang/memvalidasi tabel ACPI**,
dan tabel ini gagal diurai pada `MacPro7,1` — melaporkan **`HS06 AE_NOT_FOUND`** (objek yang dirujuk dalam tabel tidak bisa diurai)
⇒ **Manajemen daya / lapisan ACPI bermasalah ⇒ tidak bisa masuk sistem.**

> ★★ **Ini gejala "khas motherboard", bukan aturan umum dari "ganti model".**
> Jadi **jangan** menghafalnya sebagai kesimpulan generik — perlakukan sebagai satu **butir pemeriksaan**:
> sebelum ganti model, periksa dulu apakah mesin ini punya "SSDT OEM dari vendor" seperti itu.

### 2.3 Perbaikan (terbukti efektif, dua langkah)

| Langkah | Lokasi | Isi |
|---|---|---|
| ① **Hapus tabel asli dari BIOS** | `ACPI > Delete` | `TableSignature = SSDT` · `OemTableId = xh_adls3` · `All = false` |
| ② **Muat tabel pengganti yang sudah dipatch** | `ACPI > Add` | `SSDT-XHADLS3.aml` (**Enabled**) |

> Komentar di dalam config menjelaskan alasannya dengan jelas:
> *"Remove BIOS INTEL `xh_adls3` table; load patched replacement to avoid **HS06 AE_NOT_FOUND** on ASUS Z690"*

### 2.4 Bukti kronologi (untuk memastikan "apakah itu penyebabnya")

| Waktu | Kejadian |
|---|---|
| 10-12 | Ganti model **gagal 6 kali** (loop restart) — **belum ada tabel patch ini** |
| 10-13 05:51 | Membuat `SSDT-XH_ADLS3.aml` |
| 10-13 05:54 | Menambah `ACPI>Delete` (tabel asli) + `ACPI>Add` (tabel patch) ⇒ **bisa masuk sistem** |
| 10-13 11:15 | Arsip `config.plist.GOOD-MacPro71-WORKING-20261013` ⇒ terkonfirmasi berfungsi |

### 2.5 Faktor yang sudah disingkirkan (jangan lagi menduga ke arah ini)

| Faktor | Status |
|---|---|
| **Peta port USB** | ❌ **Bukan** (peta T3 sudah terverifikasi berfungsi; log driver USB normal sepanjang proses) |
| **Root patch OCLP** | ❌ Bukan satu-satunya penyebab (setelah snapshot patch di-`restore`/rollback **tetap gagal**) |
| **Model itu sendiri tidak didukung** | ❌ Bukan (`MacPro7,1` adalah model yang didukung resmi) |
| **Batas 15 port** | ❌ Tidak berkaitan dengan kegagalan ini |
| **Sisaan NVRAM** | ❌ Bukan (setelah Reset NVRAM tetap gagal) |

### 2.6 ★ Sekalian jelaskan satu "mekanisme umum di dalam dokumen" (cukup tahu, jangan langsung menduga)

Dortania dan README USBToolBox memang menyebutkan: **macOS akan menambahkan peta port USB bawaan berdasarkan "SMBIOS model + nama controller"**,
keberadaan USBToolBox justru untuk menimpanya ⇒ secara teori **ganti model bisa memicu konflik penggabungan peta USB**
(`AppleUSBHostMergeProperties`).

**Tapi pengujian nyata pada mesin ini menunjukkan itu bukan penyebabnya** (lihat §2.5). ⇒ Kesimpulan:

- **Tahu hal ini ada**, simpan sebagai salah satu arah penelusuran
- **Tapi jangan** menjadikannya penyebab utama "ganti model pasti gagal", dan **jangan** karena itu terburu-buru membuat ulang seluruh peta USB (itu proyek besar, dan bukan masalah di sini)

### 2.7 ★★★ Aturan besi urutan: **rapikan SSDT dulu, baru ganti model**

**Mesin ini adalah kasus khusus** — tanpa menangani `xh_adls3` di BIOS terlebih dahulu, **ganti model pasti gagal**. Jadi urutannya tidak boleh dibalik:

```
① Rapikan SSDT / ACPI lebih dulu (selesai dan diverifikasi pada (model lama))
        ↓
② Baru ganti SMBIOS / PlatformInfo (board-id)
        ↓
③ Baru buat ulang CPUFriendDataProvider
```

★ **Mengapa harus diselesaikan lebih dulu pada model lama**: ganti model memicu parsing ulang tabel ACPI;
jika pada saat itu lapisan ACPI memang sudah bermasalah (OEM SSDT vendor gagal diurai), **anda tidak bisa membedakan "ini masalah ACPI" atau "ini masalah ganti model"** —
kalah 6 kali berturut-turut pada 10-12 di mesin ini habis karena itu. **Pastikan dulu lapisan ACPI bersih, baru langkah ganti model hanya punya satu variabel.**

### 2.8 Daftar pemeriksaan sebelum ganti model (disusun dari pelajaran mesin ini)

- [ ] **Cek apakah mesin ini punya OEM SSDT vendor**: dari `SysReport/` (build DEBUG) atau daftar tabel ACPI di ioreg,
      cari SSDT **non-Apple** (`OEM Table ID` yang punya ciri vendor, misalnya `xh_adls3`)
- [ ] **Cek apakah log punya `AE_NOT_FOUND`** (parsing objek ACPI gagal)
- [ ] Jika kena ⇒ **siapkan pasangan perubahan "hapus tabel asli + tambah tabel patch"** (**inilah biasanya kunci apakah bisa masuk sistem**)
- [ ] Siapkan **U disk EFI yang bisa di-boot** (mengubah tabel ACPI juga bisa membuat sistem tidak mau boot)
- [ ] Peta USB **hanya disentuh bila log dengan jelas mengarah ke sana** (lihat §2.6)
## 3. Model memengaruhi apa saja (ketahui dulu apa yang Anda sentuh sebelum mengubah)

Daftar dari Dortania: **manajemen daya CPU** (XCPM profile), **konfigurasi GPU** (AGPM / AGDP / **AGDC**),
**pemetaan USB**, DRM / akselerasi decode, rentang dukungan OS, **iMessage** (serial+MLB+UUID), **preferensi `ByHost`** (dinamai berdasarkan UUID).

★ **Satu hal yang terbukti sangat terkait pada mesin ini**: **model ↔ data CPUFriend**
`MacPro7,1` memaksa `hwp=on` ⇒ CPU terkunci di 2.3 GHz; `iMacPro1,1` tidak memakai HWP ⇒ lancar
⇒ **Ganti model wajib disertai membuat ulang data `CPUFriendDataProvider`** (lihat detail di `intel-turbo.md`).

### 3.1 ★★ Daftar "item turunan" dari ganti model / ganti kode (kalau satu hilang, tidak lengkap)

| # | Item turunan | Alasan | Bukti pada mesin ini |
|---|---|---|---|
| ① | **Tiga kode (serial / MLB / UUID)** | Nama di "Tentang Mac Ini" dan identitas iMessage sama-sama terikat pada **kode** | §1.3 — kode milik `MacPro7,1` dipasangkan dengan `iMac20,1` ⇒ menampilkan `Mac Pro (2019)` |
| ② | **Prasyarat `ACPI` / SSDT** | board-id berubah ⇒ ACPI diurai ulang | §2 (mesin ini `xh_adls3` ⇒ `HS06 AE_NOT_FOUND`) |
| ③ | **`CPUFriendDataProvider`** | Profile model menentukan HWP / `FrequencyVectors` | `MacPro7,1` memaksa `hwp=on` ⇒ tertahan 2.3 GHz (`intel-turbo.md`) |
| ④ | **Injeksi memori (`PlatformInfo>Memory>Devices`)** | ★ **Jumlah slot berubah mengikuti model** | `MacPro7,1` = **12 slot**; `iMac20,1` = **4 slot** ⇒ `memory-injection.md` |
| ⑤ | **`ROM`** | Harus = MAC asli dari **`en0` saat ini**; dan `en0` bisa bergeser | §5.3 + `network-en0-order.md` |
| ⑥ | **Nama komputer / hostname / nama SMB** | **Tidak berkaitan** dengan SMBIOS, **tidak berubah otomatis** | §3.2 |
| ⑦ | Cache nama tampilan "Tentang Mac Ini" | `com.apple.SystemProfiler.plist` | §1.3 |

★ Urutannya tetap seperti §2.7: **bersihkan dulu lapisan ACPI → baru ganti model/ganti kode → baru lengkapi satu per satu ③④⑤⑥**.

### 3.2 ★ Setelah ganti model masih harus ubah "nama komputer" — ia tersimpan di **dua tempat**, bukan satu

`ComputerName` / `LocalHostName` **sama sekali tidak berkaitan** dengan SMBIOS, itu adalah pengaturan sistem yang berdiri sendiri; ganti model **tidak akan menyentuhnya**,
sehingga muncul "modelnya iMac, tapi nama komputernya masih xxx iMac Pro".

| Lokasi | Kunci |
|---|---|
| `/Library/Preferences/SystemConfiguration/preferences.plist` | `System.System.ComputerName`, `System.Network.HostNames.LocalHostName` |
| `/Library/Preferences/SystemConfiguration/com.apple.smb.server.plist` | **`NetBIOSName`**, **`ServerDescription`** ← nama yang tampil di Windows / file sharing SMB, **paling mudah terlewat** |

```bash
sudo scutil --set ComputerName  "Geek's iMac"
sudo scutil --set LocalHostName "Geeks-iMac"
# ★ hanya menjalankan scutil akan melewatkan dua tempat SMB itu — di "Jaringan" Windows masih akan terlihat nama lama
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName       -string "Geeks-iMac"
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server ServerDescription -string "Geek's iMac"
```

- **Jangan** menulis mati `HostName` (biarkan tidak disetel, serahkan ke DHCP / router)
- `hostname` yang sedang berjalan perlu **restart** agar diperbarui; **nama perangkat iCloud** ada di sisi server, perlu **login ulang** agar diperbarui
- macOS akan meninggalkan **cadangan malas** seperti `preferences-<model lama>.plist` (tidak dipakai saat boot), untuk membersihkannya gunakan `sudo rm`

## 4. Bentuk yang benar untuk skrip pergantian (tiga mode + jalur pemulihan)

Desain `try-smbios-macpro71.sh` layak ditiru:

| Mode | Perilaku |
|---|---|
| `plan` (default) | Hanya memeriksa, **tidak mengubah apa pun**: mencetak model/sha saat ini, model kandidat/sha/boot-args |
| `apply` | ★ **Meletakkan salinan baseline di ESP terlebih dahulu** `config.plist.BASELINE-<timestamp>`, lalu menulis konfigurasi kandidat |
| `rollback` | Memulihkan dari salinan baseline di ESP |

Poin penting:

- **Jangan pernah mencari EFI berdasarkan nomor disk tetap** (nomor disk berubah tiap boot) ⇒ cari berdasarkan **tipe partisi**:
  ```bash
  for d in $(diskutil list | sed -n 's/.*[[:space:]]\(disk[0-9]*s[0-9]*\)$/\1/p'); do
    [ "$(diskutil info "$d" | awk -F': *' '/Partition Type/{print $2;exit}')" = EFI ] && echo "$d"
  done
  ```
- ★ **Salinan baseline harus diletakkan di ESP**, sehingga bahkan kalau macOS gagal boot Anda tetap bisa memulihkan lewat **UEFI Shell** di menu OpenCore:
  ```
  OpenShell → map fs0: → cp fs0:\EFI\OC\config.plist.BASELINE-… fs0:\EFI\OC\config.plist
  ```
- Setelah menulis **`sync` → unmount → remount → verifikasi ulang sha** (jangan percaya cache pada titik mount yang sama)
- File kandidat diverifikasi sha dulu sebelum ditulis (di dalam skrip `[ "$(shasum -a 256 "$CAND")" = "$CAND_SHA" ] || tolak tulis`)

## 5. Tiga kode: pembuatan, kriteria, ROM

### 5.1 Pembuatan

- Gunakan **resmi `macserial`** (bawaan OpenCore, misalnya `macserial -m MacPro7,1`) atau algoritma corpnewt/GenSMBIOS
- Cara pada mesin ini: `gen-smibios.py` = algoritma macserial resmi + tabel Apple OUI (`prefix.json`), **pemeriksaan checksum tahun/minggu/MLB lolos**
- Buat beberapa set cadangan sekaligus (mesin ini pernah membuat **22 set** kandidat sekaligus)
- ★★ **Setelah pembuatan, decode dulu untuk mencocokkan** (jauh lebih cepat daripada membuka "Tentang Mac Ini" belakangan):
  ```bash
  macserial -i <serial>      # → Model: PN5T - iMac20,1 / SystemModel: iMac (Retina 5K, 27-inch, 2020)
  macserial --verify <MLB>   # → Valid MLB checksum.
  ```
  ⇒ **Kode produk harus sesuai dengan model target**, jika tidak "Tentang Mac Ini" menampilkan model lama (§1.3)

### 5.2 ★ Kriteria "kelas" nomor seri (bawa nomor seri ke situs resmi Apple untuk dicek)

| Kelas | Yang ditampilkan situs | Putusan |
|---|---|---|
| ① | "Nomor seri yang Anda masukkan tidak valid. Silakan coba lagi." | **Bisa dipakai** (tidak terdaftar; cocok untuk Apple ID dengan riwayat baik) |
| ② | Menampilkan informasi **garansi / dukungan telepon** | **Wajib diganti** (sudah diaktifkan oleh pemilik sebenarnya) |
| ③ | "Harap verifikasi tanggal pembelian" | **Paling ideal** |

### 5.3 ★ ROM harus berupa MAC asli dari `en0`

- Dortania menyarankan: isi `PlatformInfo/Generic/ROM` dengan **MAC asli `en0`**
- Jebakan yang pernah terjadi: **jangan pakai tabel Apple OUI dari GenSMBIOS untuk "membuat" sebuah MAC** — itu **MAC palsu**, akan dianggap identifier tidak valid
  ⇒ ganti dengan **MAC asli dari kartu jaringan `en0` mesin ini**
- **Biaya (perlu diketahui sebelum mengubah)**: ganti ROM ⇒ **membangun ulang preferensi `ByHost`** + mungkin menuntut **autentikasi ulang sekali**
- ★ **Trik mengganti ROM**: `ROM` di dalam XML berbentuk **base64** (6 byte MAC → 8 karakter base64)
  ⇒ bisa **mengganti base64 sebagai teks murni**, **panjang sama ⇒ format tidak berubah sama sekali**, diff semantik hanya 1 bagian, jauh lebih aman daripada menulis ulang seluruh file

### 5.4 Disiplin ganti kode (jangan sampai merusak sendiri)

- ★ **Peringatan pengendalian risiko dari komunitas: tiga kode kotor + sering ganti nomor adalah kombinasi pemicu paling tipikal** ⇒ **hati-hati saat mengganti kode** (mesin ini pernah ganti dua set dalam satu hari, itu contoh kontra)
- Setelah diganti dianggap **perangkat keras baru** ⇒ perlu autentikasi ulang, **urutannya: FaceTime dulu → lalu Pesan**
- Setelah mengubah ROM / UUID, preferensi `ByHost` akan dibangun ulang (tidak berbahaya), tapi bersiaplah: sebagian pengaturan aplikasi mungkin tampak sudah direset.

## 6. Template catatan (**isi sendiri, jangan tulis nilai asli ke dalam repo**)

★ Tiga kode (serial / MLB / UUID) dan ROM **setara dengan identitas mesin ini** (iMessage / FaceTime memang mengenal mereka)
⇒ **dilarang keras menulisnya di tempat mana pun yang bisa dilihat publik** (repo, issue, screenshot, log).

| | Model | serial | MLB | UUID | ROM |
|---|---|---|---|---|---|
| ① | `iMacPro1,1` | `⟨sudah diganti⟩` | `⟨sudah diganti⟩` | `⟨sudah diganti⟩` | `⟨sudah diganti⟩` |
| ② | `MacPro7,1` | `⟨sudah diganti⟩` | `⟨sudah diganti⟩` | `⟨sudah diganti⟩` | `⟨sudah diganti⟩` |
| **③ Aktif (sejak 10-15)** | **`iMac20,1`** | **`⟨serial aktif, kode produk harus sesuai iMac20,1⟩`** | **`⟨MLB aktif⟩`** | **`⟨UUID aktif⟩`** | **`⟨MAC asli en0 saat ini⟩`** |

★ **Kolom model wajib dicatat**: agar saat rollback Anda tahu "kode set ini dipasangkan dengan model mana" (pasangan salah ⇒ "Tentang Mac Ini" menampilkan model lama, §1.3).

- ★ **Disiplin catatan**: **catat nilai lama setiap kali mengganti** (secara lokal, jangan masuk repo), jika tidak Anda tidak tahu harus rollback ke set mana
- Disarankan mencatat **waktu pembuatan dan kegunaan tiap set** sekaligus, agar saat rollback bisa menilai set mana yang tepat

### 6.1 ★ Satu pertanyaan terbuka yang nyata: setelah kepemilikan `en0` berubah, bagaimana dengan ROM

Pendapat Dortania adalah "ROM = MAC asli `en0`". Tapi kepemilikan `en0` **berubah mengikuti urutan pemasangan driver**:
setelah memasang driver kartu jaringan / menonaktifkan salah satu kartu jaringan, `en0` bisa berubah dari kabel ke nirkabel ⇒ **apakah ROM harus ikut diubah?**

- **Ubah** ⇒ lagi-lagi harus membayar biaya "bangun ulang `ByHost` + autentikasi ulang"
- **Tidak diubah** ⇒ ROM tidak konsisten dengan `en0` saat ini (biasanya masih bisa dipakai, tapi tidak sesuai aturan)

⇒ **Ini adalah trade-off yang harus Anda putuskan sendiri**, tidak ada satu jawaban yang benar. Sebelum mengubah, catat MAC kedua sisi.

> ★★ **Mengapa kepemilikan `en0` berubah, dan cara memakuinya** ⇒ lihat **`network-en0-order.md`**
> (urutan pemasangan driver, `NetworkInterfaces.plist`, serta dampaknya ke iMessage / FaceTime / App Store).
> ★ **`ROM` / tiga kode / `SystemUUID` tidak berkaitan dengan AirDrop dan handoff**, jangan mengubahnya demi keduanya — lihat `airdrop-handoff.md` §3.

## 7. Dua pelajaran operasional (keduanya pernah menyakitkan)

| Pelajaran | Fakta |
|---|---|
| **Jika isi EFI tidak sesuai harapan, curigai dulu "ada perubahan dari luar", jangan curigai dulu "penulisan hilang"** | Ditemukan di mesin ini bahwa EFI berisi nilai lama ⇒ disimpulkan penulisan hilang ⇒ ditulis ulang ⇒ **kenyataan itu adalah isi setelah pengguna baru saja memulihkannya** (bukti: sistem memang sempat boot dengan model lama pada 03:31:37) ⇒ **menimpa pemulihan pengguna** |
| Untuk memeriksa persistensi selalu pakai **"unmount → remount → baca ulang"** | Jangan percaya cache pada titik mount yang sama; `diskutil mount` kadang **gagal dulu lalu berhasil**, penentuan akhir memakai `Mounted` dari `diskutil info` |
| **Model diganti tetapi nama "Tentang Mac Ini" tidak berubah ⇒ curigai nomor seri dulu, bukan config** | Nama model ditentukan oleh **kode produk nomor seri** (§1.3). Di mesin ini pernah terlihat `Mac Pro (2019)` padahal "config sudah dipastikan benar, 5 bukti semuanya menunjuk iMac20,1" — karena **kodenya tidak diganti**. Menghapus `com.apple.SystemProfiler.plist` juga tidak membantu (nama akan diturunkan kembali dari kode yang sama) |
| Menentukan "config mana yang dipakai pada boot ini" | Lebih langsung dibandingkan sha: **bandingkan ukuran file config dengan `OC: Loaded configuration of N bytes` pada log boot** (mesin ini `32449` cocok persis) |
