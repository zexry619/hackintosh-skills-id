# AMFI ↔ TCC Konflik: Setelah Menonaktifkan AMFI, App Tidak Mendapat Izin, Apa yang Harus Dilakukan

> Berdasarkan: **README resmi `GeekAudio/tcc-helper`** (penggunaan GUI/CLI, ide otorisasi otomatis, lima jebakan engineering, dikutip satu per satu)
> + dokumentasi OCLP / `tccplus` (AMFI dinonaktifkan ⇒ tidak ada popup + tidak ada entri yang dibuat) + pengecekan baris per baris ke repositori driver NVIDIA upstream.
> ★ **Dalam satu kalimat**: **"AMFI nonaktif" dan "popup TCC" tidak bisa sama-sama didapat** ——
> solusinya adalah **menggunakan `tcc-helper` untuk menulis entri "sudah diotorisasi" langsung ke database TCC**, dengan harga **tidak persisten**
> (pembaruan versi besar sistem / `tccutil reset` / alat pembersih akan menghapusnya).

## 0. Tiga gejala beruntun (cocokkan dengan tabel di bawah, inilah masalahnya)

1. App suara / kamera melaporkan **"tidak ada izin"**;
2. **Popup izin tidak muncul** (seberapa kali pun diklik, tetap tidak muncul);
3. **Di "System Settings → Privacy & Security" sama sekali tidak ada sakelar untuk App tersebut** (bukan dalam keadaan abu-abu, tapi **tidak ada**).

★ **Butir ketiga itulah kriteria** —— bedanya dengan "pengguna menekan Tolak" ada di sini:
App yang ditolak **memiliki entri di daftar** (hanya sakelarnya nonaktif); masalah ini adalah **entri tidak pernah dibuat sama sekali**.

## 1. Akar masalah: AMFI dinonaktifkan

Ada dua entri ini di dalam boot-args (salah satu saja sudah cukup) ⇒ **AMFI dinonaktifkan**:

```
amfi_get_out_of_my_way=0x1
amfi=0x80
```

Konsekuensinya (**kutipan asli dari dokumentasi OCLP / `tccplus`**):

> *"macOS will fail to prompt users for special permissions upon application start
> as well as omit the entries in System Preferences"*

⇒ **Tidak ada popup, dan entri juga tidak dibuat di daftar privasi** ⇒ App tidak akan pernah mendapat izin,
**bukan berarti App rusak, dan bukan berarti perangkat mikrofon/kamera rusak**.

> ★ **Kriteria**: apakah ada `amfi` di dalam `sysctl -n kern.bootargs` / `nvram boot-args`;
> lalu lihat jumlah entri mikrofon di database TCC pengguna (§6 butir 1) — **jumlah entri 0 atau sangat sedikit = popup ditahan**.

## 2. Siapa yang menuntut AMFI dinonaktifkan (dan posisi AMFIPass)

**Bukan Anda yang ingin menonaktifkannya, melainkan driver yang menyyaratkannya**. Contoh:

| Sumber | Persyaratan |
|---|---|
| **Driver NullMoth NVIDIA** (`nvidia-driver.md`) | **Daftar resmi wajibnya dua komponen**: boot-args berisi `amfi_get_out_of_my_way=0x1 amfi=0x80` **dan** `Lilu.kext` / `AMFIPass.kext` harus diaktifkan; installer `nullmoth-setup.sh` secara aktif menuliskan dan otomatis melengkapi kedua kext tersebut |
| **Root patch OCLP / sisi Wi-Fi Broadcom** | Menggunakan **`AMFIPass.kext`** (pendekatan **mempertahankan AMFI**), bukan menonaktifkan AMFI |
| Kext pihak ketiga lainnya | Tergantung pada driver; **periksa dulu README driver apakah ada persyaratan eksplisit**, janganlah memakai asumsi default "hackintosh harus nonaktifkan AMFI" |

★★ **Jangan tertukar antara kext dan boot-arg**: `AMFIPass.kext` adalah **item wajib driver**;
yang masuk daftar "override tidak aman" di `NDSecurityState.m` adalah **boot-arg `-amfipass*` ini**.

⇒ **Mesin lain**: prioritaskan memakai `AMFIPass.kext` sebagai pengganti parameter AMFI (**mempertahankan AMFI** ⇒ popup TCC normal, **masalah dalam dokumen ini sama sekali tidak akan muncul**).
⇒ **Mesin ini**: upstream mencantumkan "parameter AMFI **+** AMFIPass" **secara berjejak sebagai dua hal wajib** ⇒ **hanya bisa pilih salah satu**, lihat §3.

## 3. Kesimpulan: hanya bisa pilih salah satu

| Pilihan | Cara | Harga |
|---|---|---|
| **Jaga driver** (sekarang) | Biarkan parameter AMFI, gunakan **`tcc-helper` untuk inject entri TCC secara manual** (§4) | **Tidak persisten** — pembaruan versi besar sistem / `tccutil reset` / alat pembersih akan menghapusnya, perlu dijalankan ulang |
| **Jaga popup** | Hapus parameter AMFI | ★★ Upstream tidak mendukung kombinasi ini + belum diverifikasi; **kegagalan = WindowServer gagal memuat bundle NVIDIA ⇒ layar hitam hanya tersisa kursor** ⇒ **jangan dilakukan** |

## 4. ★★ Solusi: `GeekAudio/tcc-helper`

<https://github.com/GeekAudio/tcc-helper> — **GUI (SwiftUI) + CLI** yang ditulis dengan Swift, lisensi MIT.

> **Ini menggantikan skrip shell sekali pakai di masa awal**: hal "memindai siapa membutuhkan izin apa" **diturunkan dari sistem**,
> bukan dengan mencantumkan daftar App secara manual.

### 4.1 Pemasangan

- **Release**: **`TCC.Helper-1.0.dmg`** dari `v1.0.0` ⇒ setelah di-mount, seret App ke `Applications`
- **Build sendiri**: `./build.sh` (menghasilkan App) / `./make-dmg.sh` (menghasilkan DMG) — hanya bergantung pada **Xcode command line tools** (`swiftc`), **tidak butuh file proyek Xcode**
- ★ **Tandatangan bersifat ad-hoc** (penulis tidak punya Developer ID) ⇒ **saat pertama dibuka harus "klik kanan → Open"** (atau dicegat Gatekeeper sekali)

### 4.2 Penggunaan GUI (lima langkah)

1. **Database target** — pilih **database pengguna** (mikrofon / kamera / perekaman audio / bluetooth…) atau **database sistem** (aksesibilitas / perekaman layar…).
   Panel akan menampilkan hasil pemeriksaan mandiri; **database sistem dimiliki oleh root, jadi saat menuliskannya akan diminta kata sandi administrator**.
2. **Otorisasi otomatis (disarankan)** — begitu App dibuka, langsung memindai sekali, menampilkan "siapa yang menyatakan butuh izin apa, dan yang masih kurang berapa",
   setelah dicentang tekan "Authorize Selected", **semuanya ditulis dalam satu transaksi** (§4.3).
3. **App target (manual)** — seret `.app` ke kotak putus-putus, atau gunakan "Choose Target…".
   ★★ **Yang perlu diotorisasi adalah "komponen yang benar-benar mengajukan izin", belum tentu App utama**
   (contoh: izin mikrofon/system audio milik Loopback ada pada `Audio Routing Kit (ARK).app` di dalam paketnya (`com.rogueamoeba.arkaudiod`),
   **memberi otorisasi ke `Loopback.app` tidak berguna**) ⇒ saat memilih target Anda bisa **masuk ke dalam `.app`** untuk memilih sub-komponen;
   "Select From Running Apps…" bisa langsung menampilkan **helper latar belakang** yang sedang berjalan.
4. **Layanan izin (manual)** — **109 layanan**, **diekstrak saat runtime dari binary `tccd` sistem**, bisa difilter dalam bahasa Mandarin maupun Inggris.
5. **Tindakan** — dry-run (tidak menulis ke database) / otorisasi / pencabutan / refresh entri.
   **Sebelum menulis, `TCC.db` dicadangkan otomatis, setelah selesai otomatis `killall tccd`**, lalu diverifikasi dengan membaca kembali.

### 4.3 ★★ Otorisasi otomatis: tidak menebak, dan tidak mengandalkan pemilihan manual, diturunkan dari sistem

**Petunjuk ①: App itu sendiri sudah menyatakannya** — usage description di dalam `Info.plist` adalah daftar permintaan izinnya:

| Kunci Info.plist | Layanan TCC yang sesuai |
|---|---|
| `NSMicrophoneUsageDescription` | `kTCCServiceMicrophone` |
| `NSCameraUsageDescription` | `kTCCServiceCamera` |
| `NSAudioCaptureUsageDescription` | `kTCCServiceAudioCapture` (perekaman audio sistem) |
| `NSAppleEventsUsageDescription` | `kTCCServiceAppleEvents` |
| `NSDesktopFolderUsageDescription` … | Desktop / Documents / Downloads / volume jaringan / volume yang dapat dilepas |
| `NSBluetoothAlwaysUsageDescription` | `kTCCServiceBluetoothAlways` |

(Petakan lengkapnya ada di `usageMap` pada source `Sources/TCCAuto.swift`; **disaring berdasarkan daftar layanan sistem yang sebenarnya**, kunci yang tidak dikenali sistem tidak akan ditulis.)

**Petunjuk ②: yang benar-benar mengajukan izin sering kali komponen latar belakang** — karena itu pemindaian juga menelusuri:

- **Setiap job yang terdaftar di launchd** → ditelusuri kembali ke `.app` induknya (naik dari `Program` / `ProgramArguments[0]` untuk mencari `.app`)
- **Sub-komponen dalam paket**: `Contents/{Library/LoginItems, Library/LaunchServices, XPCServices, PlugIns, Helpers, Resources, MacOS}`
- **Direktori komponen**: `/Library/Audio/Plug-Ins/HAL` (driver audio, **ARK ada di sini**), `/Library/PrivilegedHelperTools` dll
- **App yang sedang berjalan**

**Hasilnya**: jebakan Loopback itu, dalam mode otomatis **sistem menemukan `com.rogueamoeba.arkaudiod` sendiri**,
dan mengenali bahwa ia membutuhkan `kTCCServiceMicrophone` + `kTCCServiceAudioCapture` — **tanpa perlu unpack paket secara manual**.

### 4.4 Penggunaan CLI (logika yang sama dengan GUI, sudah disertakan di dalam DMG)

```sh
bin/tcchelper-cli auto                                  # dry-run (hanya daftar, tidak menulis)
bin/tcchelper-cli auto --apply                          # benar-benar menulis
bin/tcchelper-cli auto --root /Applications --no-running # membatasi cakupan pemindaian
bin/tcchelper-cli auto --service kTCCServiceAudioCapture # hanya menangani satu layanan

bin/tcchelper-cli services                              # daftar semua layanan
bin/tcchelper-cli inspect  <App>                        # melihat bundle id / tanda tangan / DR
bin/tcchelper-cli list     <App> [--db user|system]     # daftar entri App tersebut
bin/tcchelper-cli dry      <App> <service> [--db ...]   # dry-run
bin/tcchelper-cli grant    <App> <service> [--db ...] [--path]
bin/tcchelper-cli revoke   <App> <service> [--db ...] [--path]
```

★ **`--path` = otorisasi berdasarkan jalur absolut** (`client_type=1`), dipakai untuk **file executable telanjang tanpa bundle**.

### 4.5 Prinsipnya: yang ditulis adalah tabel `access`

| Kolom | Nilai |
|---|---|
| `service` | `kTCCService…` |
| `client` | bundle id (`client_type=0`) atau jalur absolut (`client_type=1`) |
| **`auth_value`** | **`2` = diizinkan** (0 ditolak / 3 belum diputuskan) |
| `auth_reason` | `4` = kebijakan layanan (**entri yang dibuat sistem sendiri memakai nilai ini**) |
| `auth_version` | `1` |
| **`csreq`** | blob DER, dihasilkan dari **designated requirement** App target |
| `indirect_object_identifier` | literal **`'UNUSED'`** (bukan string kosong) |

**Pembuatan `csreq`**: `codesign -d -r- <App>` mengambil teks **sesudah** `designated =>` → `csreq -r- -b out.bin`.
★ **Nilai magic harus `fade0c00`**; jika prefiks `designated =>` ikut dimasukkan, hasilnya **`fade0c01` (format himpunan) ⇒ TCC tidak mengenali**.

## 5. ★ Lima jebakan engineering (sudah ditangani di dalam kodenya, kalau menulis skrip sendiri akan mengalaminya semua)

1. **`codesign -dvvv -r-` mencetak DR ke stdout, sedangkan informasi detail ke stderr** ⇒
   **hanya melihat satu aliran akan salah menilai App bertanda tangan sebagai "tanpa tanda tangan"**, kedua aliran harus diparse.
2. **App dengan tanda tangan ad-hoc tidak memiliki DR eksplisit** — codesign mencetaknya sebagai `# designated => cdhash H"…"` (dengan `#`, itu komentar).
   Dalam kasus seperti ini **`csreq` dikosongkan**, pencocokan mengandalkan Bundle ID (**entri yang ditulis sistem untuk daemon Apple juga begitu**).
3. **Jangan pakai tabel sementara untuk menguji hak tulis** — `create temp table` **hanya menulis ke database temp** dan selalu "berhasil", tidak bisa mendeteksi database utama yang hanya-baca;
   gunakan **DDL pada database utama + `rollback`**.
4. ★ **Pada tahap pemindaian tidak boleh menjalankan `codesign` untuk setiap App** — setiap pemanggilan adalah satu subprocess,
   36 App secara serial butuh **17–21 detik**, antarmuka langsung macet ⇒ ubah menjadi **lazy + paralel** (`DispatchQueue.concurrentPerform`), hasilnya:
   pemindaian **0,9 s** + pemeriksaan tanda tangan **2,1 s**.
5. ★ **`systemServices()` wajib di-cache** — fungsi ini harus membaca beberapa MB `tccd` lalu menjalankan regex, sementara pemindaian memanggilnya **untuk setiap App**;
   tanpa cache = puluhan kali pemindaian penuh.

## 6. Kriteria troubleshooting (tinggal ikuti lain kali)

1. **Periksa entri di database TCC pengguna**:

   ```bash
   sqlite3 "$HOME/Library/Application Support/com.apple.TCC/TCC.db" \
     "select service,client,auth_value from access where service like '%Microphone%';"
   ```

   - **Jumlah entri 0 atau sangat sedikit** ⇒ **popup ditahan** (AMFI nonaktif) ⇒ dokumen ini;
   - Entri ada tetapi `auth_value=0` ⇒ itu **ditolak** (coba ulang setelah `tccutil reset`, atau langsung ubah `auth_value=2`).
2. **Periksa apakah ada `amfi` di boot-args**: `sysctl -n kern.bootargs` / `nvram boot-args`.
3. **Periksa `csr-active-config` dan perhatikan byte-nya**: baca dengan `plistlib`;
   ⚠️ **`PlistBuddy -c Print` mencetak base64** — yang tampil `C` di mesin ini sebenarnya `430a0000` (= `0x0A43`).
4. ★★ **Disiplin diagnosis (klasifikasikan dulu tiga kategori, jangan buru-buru menulis ke database)**:
   ① **Entri tidak ada** ⇒ dokumen ini (AMFI menahan)
   ② **Entri ada tapi ditolak** ⇒ tindakan pengguna, coba ulang setelah `tccutil reset`
   ③ **Entri ada dan sudah diizinkan tapi tetap gagal** ⇒ **masalah pada App itu sendiri / perangkatnya, jangan lagi repot-repot dengan TCC**
   ★ Ada satu kategori lain yang paling mudah terlewat: **objek yang diotorisasi salah pilih** — yang perlu diotorisasi adalah **helper / sub-komponen yang benar-benar mengajukan izin** (§4.2 langkah 3).

## 7. Perhatikan dan Batasannya

- **Entri tidak persisten** — pembaruan versi besar sistem / `tccutil reset` / alat pembersih akan menghapusnya, **perlu dijalankan ulang**
- **Jika database pengguna tidak bisa dibaca** ⇒ beri App ini centang "**Full Disk Access**";
  Anda juga bisa menekan "Grant Full Disk Access to Yourself" di panel (**menulis ke database sistem, butuh kata sandi administrator**)
- **Pencabutan**: gunakan tombol "Revoke", atau `tccutil reset <service> <bundle-id>`
- ★ Ini adalah tindakan yang **sengaja menurunkan batas keamanan sistem** ⇒ **hanya beri otorisasi pada App yang benar-benar membutuhkannya**
- ★ Mekanisme yang sama berlaku untuk **semua** layanan TCC (cukup ganti `service`);
  tetapi **perekaman layar / aksesibilitas** pada sebagian sistem masih memerlukan penanganan tambahan ⇒ **gunakan §6 butir 1 untuk memastikan apakah masalahnya "tidak ada entri" atau "ditolak"**

## 8. Sumber

- `GeekAudio/tcc-helper` → `README.md` (penggunaan GUI/CLI, ide otorisasi otomatis, lima jebakan) + `Sources/TCCAuto.swift` (`usageMap`) + Release `v1.0.0`.
- Dokumentasi OCLP / `tccplus`: AMFI dinonaktifkan ⇒ tidak ada popup + tidak ada entri privasi (teks asli ada di §1).
- Terkait: `nvidia-driver.md` §8 (batas keamanan driver) · `broadcom-wifi.md` (sisi root patch OCLP).

---

## Lampiran: Gatekeeper /"Any Source"/"Developer Cannot Be Verified" (**tidak terkait TCC, tapi sering ditelusuri bersama**)

### A.1 Pertama-tama bedakan: ini dua masalah

| Gejala | Akar masalah | Ke mana |
|---|---|---|
| Klik ganda App memunculkan "**cannot be opened because the developer cannot be verified**" / "**is damaged and should be moved to the Trash**" / "from an unidentified developer" | **Gatekeeper** (evaluasi kebijakan sistem, `spctl`) | Lampiran ini |
| App **bisa dibuka**, tapi tidak mendapat izin mikrofon / kamera / perekaman layar, dan tidak ada popup | **AMFI dinonaktifkan ⇒ TCC tidak mencatat** | §0–§7 |

★ Keduanya bermanifestasi sebagai "App tidak bisa dipakai", tapi **perbaikannya sama sekali tidak sama** — lihat dulu apakah App benar-benar berjalan.

### A.2 Perintah

```bash
spctl --status                  # assessments enabled / disabled (hanya baca, tidak perlu sudo)
sudo spctl --global-disable     # menonaktifkan penilaian global Gatekeeper = "Any Source" versi lama
sudo spctl --global-enable      # pulihkan
```

| Item | Penjelasan |
|---|---|
| **`--master-disable`** | ★ **Pada macOS 15+ (Sequoia/Tahoe) ini sudah bukan cara yang terdokumentasi**, sakelar yang sesuai adalah **`--global-disable`**.<br>Binary masih menyimpan `master-disable` untuk kompatibilitas dengan skrip lama, **tetapi jangan menulisnya ke alur baru** (banyak tutorial di internet masih memakainya) |
| **Jalur GUI** | System Settings → Privacy & Security → Security → "**Allow from any source**".<br>Pada sebagian versi opsi ini **tidak ditampilkan secara default**, harus menjalankan `--global-disable` sekali dulu agar muncul (gejala klasik era Ventura) |
| `spctl --disable-status` | 26.7.1 mengembalikan: *"The option to globally disable the assessment system is currently available in **System Settings**."*<br>⇒ **Apple sedang menarik entry point ini ke GUI**, CLI masih bisa dipakai tetapi sudah bukan jalur yang direkomendasikan secara resmi |

### A.3 Hasil pengukuran di mesin ini (macOS 26.7.1 / Tahoe)

```bash
spctl --status          # → assessments disabled
spctl --help            # sakelar yang tercantum: --assess / --status / --global-disable / --disable-status
strings /usr/sbin/spctl | grep global-   # → global-disable, global-enable ada keduanya
```

- ★ **`--global-enable` hanya ada di dalam binary, `--help` tidak mencantumkannya** ⇒ saat memulihkan tetap pakai saja, jangan mengira itu sudah dihapus
- Di mesin ini `assessments disabled`, sesuai dengan kondisi sekarang yaitu "setelah memasang driver pihak ketiga / alat, semuanya normal"

### A.4 Kriteria dan Batasannya

- ★ **"is damaged and should be moved to the Trash" ≠ benar-benar rusak**: kemungkinan besar Gatekeeper mencegat + atribut `quarantine`.
  Pertama sekali cabut atributnya: `xattr -d com.apple.quarantine /Applications/xxx.app`, **jika tidak berhasil baru sentuh `spctl`**
- ★ **Menonaktifkan Gatekeeper tidak akan membuat kext berhasil dimuat** — kext melihat **`SecureBootModel` / SIP / tanda tangan** (lihat §1,
  `nvidia-driver.md` §8), jangan campur dua mekanisme ini
- ★ Setelah dinonaktifkan, sistem **tidak lagi memvalidasi App hasil unduhan apa pun** ⇒ disiplin yang sama dengan §7: **haktifkan hanya saat Anda benar-benar tahu apa yang akan dipasang, dan setelah selesai pertimbangkan `--global-enable` untuk memulihkannya**
