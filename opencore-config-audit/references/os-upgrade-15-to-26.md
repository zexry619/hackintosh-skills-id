# Peningkatan versi sistem: macOS 15 (Sequoia) → 26 (Tahoe) — perubahan konfigurasi

> ★ **Alternatif lain dari OCLP**: `laobamac/OCLP-Mod` (versi mod dari OCLP: antarmuka bahasa Mandarin, nirkabel Intel untuk Sequoia,
> unduhan akselerasi KDK/MetalLib). ⚠️ **Proyek ini diarsipkan sejak 2026-06-13**, versi yang sudah ada masih dapat digunakan, tetapi **node API akan ditutup secara bertahap**
> ⇒ ★ **Matikan `SimpleHacAPI` di pengaturan OCLP-Mod**. Indeksnya ada di `laobamac-toolkit.md`.

> Artikel ini adalah **alur khusus untuk peningkatan versi besar** (bukan alur instalasi; untuk instalasi lihat `lifecycle.md`).
> Inti persoalan: **konfigurasi OpenCore yang sama harus melayani dua versi besar Darwin sekaligus ⇒ harus menggunakan `MinKernel` / `MaxKernel` untuk melakukan pembagian versi kext**.
> Baseline hasil pengukuran di mesin ini: macOS **26.7.1 (25G241)** / Darwin **25.6.0**, model `MacPro7,1`, kartu jaringan BCM943602CDP.

## ★★ Dua batasan mutlak (baca dua ini dulu, baru lanjut)

1. **Jangan ubah model saat upgrade** —— setiap `SystemProductName` / `BoardProduct` / tiga kode di dalam `PlatformInfo` tidak boleh disentuh.
   **Jika model tidak ada di whitelist versi baru ⇒ tambahkan boot-arg untuk bypass** (`-no_compat_check` + `revpatch=sbvmm`), **bukan mengganti model**. Lihat §5.
2. **Kext yang dibangun per versi harus melakukan pembagian versi** —— gunakan `MinKernel` / `MaxKernel`. Lihat §1, §2.

## 0. Kesimpulan lebih dulu: apa yang pasti akan terputus saat upgrade

| Yang akan terputus | Mengapa | Apakah ini "konfigurasi rusak" |
|---|---|---|
| **Wi-Fi langsung hilang** | Entri kext nirkabel yang dibangun untuk Sequoia tertulis `MaxKernel=24.99.99` ⇒ setelah naik ke Darwin 25 **dilewati oleh OpenCore** | **Bukan**. Ini pasti terjadi |
| **Semua OCLP root patch gagal** | Upgrade sistem mengembalikan volume sistem ke kondisi native (`IO80211.framework` menjadi kerangka kosong, catatan patch hilang) | **Bukan**. Setiap peningkatan versi besar begitu |
| **FileVault menghalangi OCLP** | Post-Install OCLP menolak melakukan patch ketika FileVault diaktifkan | Bukan |
| **kext pihak ketiga di `/Library/Extensions` dipindahkan** | Sebelum melakukan patch, OCLP membersihkan kext dengan **mtime < 2021-10-01** dan memindahkannya ke `/Library/Relocated Extensions` (NVIDIA punya timestamp `1970-01-01`) | Bukan |

> ★★ **Ingat kalimat ini lebih dulu**: **Setelah upgrade Wi-Fi pasti mati, root patch pasti hilang — ini memang disengaja, bukan karena Anda merusak konfigurasi.**
> Karena itu fokus alur upgrade bukan "mencari masalah", melainkan **melakukan hal-hal yang wajib dilakukan secara berurutan** (§3).

---

## 1. ★★ Mekanisme inti: `MinKernel` / `MaxKernel` dan versi Darwin

### 1.1 Perbandingan Darwin ↔ macOS

"Versi besar" macOS pada kernel adalah **nomor utama Darwin**, dan itulah yang ditulis pada `MinKernel` / `MaxKernel` di `Kernel > Add/Block/Patch`
(format `MAJOR.MINOR.PATCH`, **kosong = tanpa batasan**):

| macOS | Darwin | Penulisan `MinKernel` yang umum |
|---|---|---|
| 14 Sonoma | 23.x | `23.0.0` |
| **15 Sequoia** | **24.x** | `24.0.0` / batas atas `24.99.99` |
| **26 Tahoe** | **25.x** | **`25.0.0`** |
| (periksa mesin ini) | — | `uname -r` |

### 1.2 ★ Apa arti penulisan `24.99.99` ini

Ini adalah cara umum untuk **"menancapkan batas atas di seluruh Darwin 24, tanpa melukai Darwin 25"**:

```
MaxKernel = 24.99.99   ⇒ hanya berlaku di Darwin 23 / 24, otomatis dilewati mulai Darwin 25
MinKernel = 25.0.0     ⇒ hanya berlaku mulai Darwin 25
```

**Jangan** menulis `MaxKernel = 25.0.0` (itu juga akan memagari Darwin 25 itu sendiri) atau `MaxKernel = 24.0.0` (itu akan mengeluarkan seluruh 24.1–24.99).
`24.99.99` adalah penulisan yang dipakai dalam konfigurasi resmi OCLP, ikuti saja.

### 1.3 Field entri (bentuk lengkap satu entri di `Kernel > Add`)

| Field | Nilai | Keterangan |
|---|---|---|
| `Arch` | `x86_64` | |
| `BundlePath` | `Xxx.kext` | **plugin harus ditulis dengan path lengkap**, lihat di bawah |
| `Comment` | teks bebas | **disarankan** menuliskan dengan jelas "untuk sistem mana, berasal dari mana" |
| `Enabled` | `True` / `False` | |
| `ExecutablePath` | `Contents/MacOS/<nama-executable>` | plugin juga perlu path awalan |
| `PlistPath` | `Contents/Info.plist` | |
| **`MinKernel`** | **`25.0.0`** | ★ pembagian versi |
| **`MaxKernel`** | **`24.99.99`** | ★ pembagian versi |

**★ Penulisan untuk plugin** (contoh dari mesin ini: driver kartu Broadcom adalah sebuah plugin di dalam `IO80211FamilyLegacy.kext`):

```
BundlePath     = IO80211FamilyLegacy.kext/Contents/PlugIns/AirPortBrcmNIC.kext
ExecutablePath = Contents/MacOS/AirPortBrcmNIC
PlistPath      = Contents/Info.plist
MinKernel      = 23.0.0
MaxKernel      = 24.99.99
```

### 1.4 Tiga aturan

1. **Jika satu fitur yang sama menyediakan "produk yang dibangun terpisah per versi kernel" di hulu ⇒ harus menulis dua entri, dipisahkan dengan `MinKernel`/`MaxKernel`**.
   **Tidak boleh** menyisakan hanya satu entri (sebuah sistem tidak akan bisa memakainya), dan **tidak boleh** juga membiarkan keduanya tanpa batasan (kedua sistem akan memuatnya ⇒ konflik/panic).
2. **Batas atas selalu gunakan `24.99.99`** untuk mengunci ke Darwin 24.
3. **kext universal (Lilu / VirtualSMC / WhateverGreen / RestrictEvents / USBToolBox …) tidak perlu ditulis** ——
  Mereka lintas versi, biarkan kosong saja. **Hanya tulis untuk yang "dibangun per sistem".**

---

## 2. ★ Checklist batasan versi per komponen

### 2.1 Kartu jaringan (paling sering menjadi jebakan, dan fokus artikel ini)

| Kartu jaringan | Entri Sequoia (Darwin 24) | Entri Tahoe (Darwin 25) | Sumber |
|---|---|---|---|
| **Broadcom BCM43602 / BCM943602CDP** | `IO80211FamilyLegacy.kext` (`Min 23.0.0`)<br>+ **plugin** `…/PlugIns/AirPortBrcmNIC.kext` (`Min 23.0.0` / **`Max 24.99.99`**) | **`AirPortBrcmNIC-Tahoe.kext`**<br>(`Min 25.0.0`, **baru tersedia sejak OCLP 3.0.0-rc.3**) | `broadcom-wifi.md` |
| **Intel** | `AirportItlwm-Sequoia` (`Min 24.2.0` / `Max 24.99.99`) | `AirportItlwm-Tahoe` (`Min 25.0.0`) | `intel-wifi.md` |
| **MediaTek MT792x** | tanpa pembagian versi (memang semuanya eksperimental) | sama seperti di sebelah kiri | `mediatek-wifi.md` |

> ★★ **Kasus Broadcom ini adalah jebakan yang pernah dialami di mesin ini**: `MaxKernel=24.99.99` pada `AirPortBrcmNIC.kext` **ditulis mati oleh OCLP 2.5.1**,
> dan **OCLP 2.5.1 sama sekali tidak mendukung Tahoe** ⇒ setelah naik ke 26, Wi-Fi langsung hilang.
> **Wajib ganti ke OCLP 3.0.0-rc.3+** (di dalam `payloads/Config/config.plist`-nya barulah ada entri `AirPortBrcmNIC-Tahoe.kext`).
> Bentuk yang benar dari ketiga entri tersebut (dibandingkan dengan konfigurasi resmi OCLP):
>
> ```
> [1] IOSkywalkFamily.kext                      Min 23.0.0  Max —
> [2] IO80211FamilyLegacy.kext                  Min 23.0.0  Max —
> [3] …/AirPortBrcmNIC.kext                     Min 23.0.0  Max 24.99.99   ← Darwin 23–24
> [4] AirPortBrcmNIC-Tahoe.kext                 Min 25.0.0  Max —          ← Darwin 25+ (baru di 3.0.0)
> ```

### 2.2 Pendukung kartu jaringan (tidak dibedakan versi, tetapi statusnya berubah saat upgrade)

| Item | Perbedaan Sequoia / Tahoe |
|---|---|
| `Kernel > Block > com.apple.iokit.IOSkywalkFamily` | dibutuhkan di kedua versi (`Min 23.0.0`), agar driver pihak ketiga mengambil alih |
| Dua data NVRAM Bluetooth (`bluetoothExternalDongleFailed` / `bluetoothInternalControllerInfo`) | dibutuhkan di kedua versi, dan `NVRAM > Add` maupun `Delete` harus ada |
| Pemetaan port `USB` (port Bluetooth `UsbConnector=255` Internal) | dibutuhkan di kedua versi |
| `built-in` / `IONameMatch` | dibutuhkan di kedua versi |

### 2.3 Kartu grafis / lainnya

| Komponen | Cara menangani batasan versi |
|---|---|
| **NVIDIA (driver NullMoth)** | **Tidak perlu `MinKernel`** — ia terpasang di `/Library/Extensions` dan dimuat dari AuxKC, **bukan ada di dalam EFI**.<br>Peningkatan dilakukan dengan **mengganti file**: `/Library/NullMoth/kexts/26/NVAccel.kext` menimpa versi `26`, lalu `kmutil create` membangun ulang AuxKC |
| Lilu / VirtualSMC / WhateverGreen / RestrictEvents / NVMeFix / USBToolBox / XHCI-unsupported / UTBMap / AMFIPass | biarkan kosong (universal). **Namun harus memakai versi baru "yang mendukung sistem baru"** — perbarui ke versi terbaru saat upgrade |
| `BlueToolFixup` | di mesin ini ditulis `Min 21.0.0` (lintas versi, tidak perlu pembagian versi) |

---

## 3. ★★ Urutan upgrade (Ikuti sesuai urutan)

### Tahap A: **sebelum** upgrade (dilakukan di macOS 15)

1. **Matikan FileVault terlebih dahulu** — jika tidak, Post-Install OCLP akan menolak melakukan patch (`Cannot patch due to the following reasons: FileVault is enabled`).
   - `fdesetup status` untuk melihat status; **jika menampilkan `in progress` (sedang mengenkripsi) ⇒ Anda harus menunggu sampai selesai**, migrasi enkripsi/dekripsi **tidak dapat berjalan bersamaan**
   - ⚠️ `fdesetup disable` **tetap mengembalikan exit code 0 ketika gagal**, jangan hanya melihat `$?`
   - ⚠️ `fdesetup` mencocokkan berdasarkan **nama pendek** (RecordName), tidak mengenali RealName
2. **Jalankan skrip proteksi pra-OCLP** (★ **wajib, tidak boleh dilewati**) — mencegah OCLP memindahkan kext NVIDIA dengan timestamp `1970-01-01` ke `Relocated Extensions` saat melakukan patch:
   ```bash
   sudo bash prep-oclp-rootpatch.sh     # hanya memperbaiki mtime, tidak mengubah isi, dan mencadangkan seluruh direktori
   ```
3. **Cadangkan EFI** (seluruh folder `EFI`, bukan hanya config) + catat `opencore-version` dan `uname -r` saat ini.
4. **Siapkan kext khusus Tahoe**: ambil `AirPortBrcmNIC-Tahoe.kext` dari **OCLP 3.0.0-rc.3+** (atau `AirportItlwm-Tahoe` untuk Intel).
5. **★ Saat model dipastikan tidak ada di whitelist, tambahkan parameter bypass (tanpa mengubah model)**: `-no_compat_check` + `revpatch=sbvmm` (§5.3).
   > Langkah ini **hanya mengubah boot-args**. **Jangan** sekalian mengganti model dengan model yang ada di whitelist — itu adalah hal lain (§5.2).
6. **★ Periksa sekali lagi checklist "dilarang diubah"**: tiga tempat `SystemProductName` di `PlatformInfo`, `BoardProduct`, tiga kode — semuanya tidak berubah.

### Tahap B: **saat** upgrade

5. Upgrade dari "Pengaturan Sistem → Umum → Pembaruan Software".
   - **Jangan** gunakan "Build and Install OpenCore" dari OCLP — perintah itu menulis ulang seluruh EFI dan menghapus boot-args / SMBIOS / DeviceProperties Anda. **Yang kita perlukan hanya root patch.**

### Tahap C: **setelah** upgrade (dilakukan di macOS 26)

6. **Lengkapi entri kext dengan pembagian versi** (§2.1) — pasang `AirPortBrcmNIC-Tahoe.kext` + tambahkan entri `MinKernel=25.0.0` di `Kernel > Add`. Restart, pastikan dulu stack kernel berfungsi.
7. **Terapkan ulang OCLP root patch**: `OpenCore-Patcher.app` → **Post-Install Root Patch** → Start Root Patching.
   Seharusnya terlihat **"Networking: Modern Wireless"**.
8. **Restart**, lalu verifikasi sesuai §6.

> **Pengecualian FileVault**: jika volume sistem `Sealed: Broken` dan FileVault harus diaktifkan,
> Anda perlu menambahkan patch kernel OCLP **`Force FileVault on Broken Seal`** (lihat §4.5).

---

## 4. Item config yang wajib diubah saat upgrade

### 4.1 `Kernel > Add` — lengkapi entri pembagian versi

Lihat §2.1. **Ini adalah perubahan paling inti dari "upgrade 15→26".**

### 4.2 `Kernel > Block > com.apple.iokit.IONDRVSupport`

**Desktop + driver kartu grafis pihak ketiga**: **`Enabled = true`** (blokir yang bawaan sistem, biarkan driver mengambil display index 0).

Namun untuk **installer / masa upgrade harus dibalik**: **`Enabled = false`** (izinkan firmware framebuffer bertahan melewati PCI setup).
Setelah driver terpasang, kembalikan lagi ke `true`.

> Kriteria: **jika layar internal terpasang pada "Intel iGPU tanpa driver"** ⇒ wajib `false` (jika tidak layar internal jadi hitam); selain itu untuk desktop gunakan `true`.

### 4.3 Yang terkait BAR (ramah installer ↔ pemakaian harian)

| Kunci | Masa upgrade / instalasi | Setelah upgrade (harian) |
|---|---|---|
| `UEFI > Quirks > ResizeGpuBars` | **`-1`** (serahkan ke firmware, tanpa resize) | sesuai kebutuhan (di mesin ini `13` = 8 GB) |
| `Booter > Quirks > ResizeAppleGpuBars` | **`0`** (installer memakai BAR kecil) | **`-1`** (harian) |

**Mengapa**: installer berjalan di atas firmware framebuffer, BAR besar membuatnya tersangkut di PCI configuration.

### 4.4 Keamanan dan SIP

| Kunci | Nilai | Keterangan |
|---|---|---|
| `Misc > Security > SecureBootModel` | **`Disabled`** | kext pihak ketiga tidak bertanda tangan Apple, wajib |
| `csr-active-config` | longgarkan sesuai kebutuhan | hasil pengukuran di mesin ini `430A0000` (≈ `0x0A43`: UNTRUSTED_KEXTS + UNRESTRICTED_FS + KERNEL_DEBUGGER + UNRESTRICTED_NVRAM + UNAPPROVED_KEXTS + UNAUTHENTICATED_ROOT). **OCLP dan driver pihak ketiga sama-sama mensyaratkan nilainya bukan 0** |

### 4.5 `Kernel > Patch` — patch FileVault dari OCLP (sesuai kebutuhan)

Wajib jika Seal volume sistem sudah di-break oleh OCLP dan FileVault menyala:

```
Identifier = com.apple.filesystems.apfs
Base       = _apfs_filevault_allowed     ← gunakan simbol untuk penentuan, Find dikosongkan
Replace    = b801000000c3                ← mov eax,1; ret
MinKernel  = 20.4.0
Count / Skip / Limit = 0
```

### 4.6 boot-args

| token | Kapan dibutuhkan |
|---|---|
| **`-no_compat_check`** | ★ **wajib saat model tidak ada di whitelist versi baru** (lihat §5) — menyelesaikan "apakah bisa boot" |
| **`revpatch=sbvmm`** | ★ **sama seperti di atas, menyelesaikan "apakah bisa menerima/memasang pembaruan sistem"** (lihat §5.3) — ini yang mudah terlewat |
| `revpatch=cpuname` + `revcpu=1` + `revcpuname=<nama>` | Menampilkan nama CPU (di mesin ini `revcpu=1`) |
| `-wegnoigpu` | menyembunyikan iGPU tanpa driver (jika tidak, bring-up `IOGraphicsFamily` akan menunggunya, hasil pengukuran lambat ~60 s) |
| `-v` | **pilihan, wajib ditanyakan ke klien** (lihat `lifecycle.md` §6.3) |

> Menggunakan `revpatch=` / `revcpu=` memerlukan **`RestrictEvents.kext`** (plugin Lilu).

---

## 5. ★★ Batasan mutlak: jangan mengubah model saat upgrade, gunakan parameter bypass

### 5.1 Batasan

> **Saat meningkatkan versi sistem, tidak satu pun field terkait model di `PlatformInfo` boleh disentuh.**
> **Jika model tidak ada di whitelist versi baru ⇒ tambahkan boot-arg untuk bypass, bukan mengganti model.**

Secara spesifik yang "dilarang diubah":

- `PlatformInfo > Generic > SystemProductName`
- `PlatformInfo > SMBIOS > SystemProductName`
- `PlatformInfo > DataHub > SystemProductName`
- `PlatformInfo > SMBIOS > BoardProduct` (board-id)
- Nomor seri / MLB / UUID (tiga kode)

### 5.2 Mengapa ini batasan mutlak, bukan "dua jalur yang boleh dipilih"

Mengganti model **bukan perubahan yang terisolasi, melainkan perubahan yang berkoupling**:

| Dampak turunan | Akibat |
|---|---|
| **board-id berubah ⇒ tabel ACPI diurai ulang** | ★ sebab sebenarnya pada mesin ini: SSDT dengan **`OEM Table ID = xh_adls3`** di dalam BIOS gagal diurai (**`HS06 AE_NOT_FOUND`**) ⇒ restart berulang. **Bukan gambar USB** (lihat `smbios-and-serials.md` §2) |
| **board-id berubah** | memicu **pembangunan ulang / verifikasi volume sistem** ⇒ jika OCLP sudah break seal, proses ini **bisa macet** (pernah dialami di mesin ini pada 10-12) |
| Profil XCPM ikut berganti | perilaku frekuensi CPU berubah (`MacPro7,1` memaksa `hwp=on` ⇒ data CPUFriend harus dibuat ulang) |
| Path AGDC, preferensi ByHost | perilaku tampilan/layanan bergeser, area troubleshooting jadi lebih luas |

⇒ **Peningkatan versi itu sendiri sudah merupakan operasi berisiko tinggi, jangan menumpuk perubahan berkoupling kedua dalam putaran yang sama.**
Apakah model sebaiknya diganti adalah **keputusan terpisah** (lihat **`smbios-and-serials.md`**), terpisah dari upgrade.

### 5.3 Parameter bypass apa yang dipakai (dua-duanya, jangan hanya satu)

| Parameter | Apa yang diselesaikan | Akibat jika tidak ditambahkan |
|---|---|---|
| **`-no_compat_check`** | **apakah bisa boot** — mematikan pemeriksaan kompatibilitas model | langsung menolak boot |
| **`revpatch=sbvmm`** | **apakah bisa pembaruan** — memaksa model VMM SB, *"allowing OTA updates for unsupported models on macOS 11.3 or newer"* (kutipan asli RestrictEvents) | bisa boot, tetapi **tidak menerima / tidak bisa memasang pembaruan sistem** |
| `revpatch=cpuname` + `revcpu=1` + `revcpuname=<nama>` | Menampilkan nama CPU | nama CPU salah di "Tentang Mac Ini" |
| `revpatch=pci` / `revblock=pci` | memblokir peringatan konfigurasi PCI / RAM untuk model `MacPro7,1` | muncul peringatan konfigurasi (saat modelnya MacPro7,1 tetapi hardware tidak cocok) |

**★ Yang paling mudah terlewat adalah `revpatch=sbvmm`** — banyak orang hanya menambahkan `-no_compat_check`, lalu begitu bisa boot menganggap sudah selesai,
padahal baru saat pembaruan sistem berikutnya mereka menemukan "tidak menerima pembaruan". **Keduanya adalah masalah pada tingkat yang berbeda.**

### 5.4 Whitelist (**hanya dipakai untuk menilai "perlu bypass atau tidak"**)

macOS 26 sangat memangkas dukungan model Intel. Berdasarkan penilaian pada skrip hulu, whitelist-nya adalah:

```
iMac20,1   iMac20,2   MacPro7,1   MacBookPro16,1   MacBookPro16,2   MacBookPro16,4
```

**`iMacPro1,1` telah dikeluarkan** — justru model Intel yang paling sering dipakai pada era Sequoia.

| Model ada di whitelist? | Apa yang harus dilakukan |
|---|---|
| **Ada** | tidak perlu menambahkan apa pun |
| **Tidak ada** | **tambahkan `-no_compat_check` + `revpatch=sbvmm`**, model tetap dipertahankan |

### 5.5 ★ Yang jelas-jelas tidak boleh dilakukan

| Jangan lakukan | Mengapa |
|---|---|
| Mengubah salah satu `SystemProductName` | melanggar batasan; dan perubahan board-id memicu **urai ulang ACPI** (di mesin ini `xh_adls3` meledak) + pembangunan ulang volume sistem (§5.2) |
| Mengubah `BoardProduct` (board-id) | memicu pembangunan ulang volume sistem, berkonflik dengan OCLP |
| **Menjalankan `nullmoth-setup.sh --update prepare --pkg <paket>`** | ★ **jebakan paling tersembunyi**: perintah ini **otomatis** mengubah model menjadi `MacPro7,1`, board-id menjadi `Mac-27AD2F918AE68F61`, dan menambahkan `RestrictEvents.kext`. **Jalur ini bertabrakan langsung dengan batasan, wajib dihindari.**<br>(menekan tombol secara normal / memperbarui driver secara normal **tidak** memicu ini — tombol tersebut sudah dihapus dari UI App sejak 1.0.15, hanya tersisa kemampuan lewat skrip; hasil pengukuran di mesin ini menunjukkan `PlatformInfo` masih model asli) |
| Menggunakan "Build and Install OpenCore" dari OCLP | menulis ulang seluruh EFI, menghapus boot-args / SMBIOS / DeviceProperties yang sudah disetel |

### 5.6 Biaya dari batasan ini (harus disampaikan apa adanya)

Mempertahankan model asli = **menyerah pada UI khusus model versi baru**. Misalnya array `Devices` pada `PlatformInfo > Memory`
hanya **pada model MacPro** yang akan menggambar diagram memori 12 slot tersebut (lihat `memory-injection.md`) —
bila modelnya bukan MacPro hal itu tidak bisa dilakukan, **tidak ada boot-arg yang bisa menggantikannya**.

Jadi pertimbangannya adalah:

| | Pertahankan model asli + bypass parameter (**bawaan sesuai batasan**) | Ganti model |
|---|---|---|
| Bisa boot / bisa pembaruan | ✅ (lewat `-no_compat_check` + `revpatch=sbvmm`) | ✅ |
| Risiko upgrade | **rendah** (hanya boot-args yang berubah) | tinggi (ACPI/SSDT + board-id + CPUFriend + tiga kode semuanya berubah) |
| UI khusus model | ❌ tidak didapat | ✅ |
| Terpisah dari upgrade? | ✅ **terpisah** | ❌ berkoupling |

⇒ **Gunakan jalur kiri secara bawaan.** Ketika benar-benar membutuhkan fitur khusus model, lakukan **secara terpisah dalam satu kali** switch model (ikuti alur lengkap **`smbios-and-serials.md`**),
**jangan** dicampur ke dalam upgrade yang sedang dilakukan.

---

## 6. Kriteria verifikasi

```bash
# ① Versi Darwin — pastikan benar-benar sudah naik
uname -r                              # diharapkan 25.x

# ② Stack kernel nirkabel — keempatnya harus ada (jalur Broadcom)
kmutil showloaded --list-only | grep -E "IOSkywalkFamily|IO80211FamilyLegacy|AirPort.BrcmNIC|corecapture"

# ③ ★ kelangsungan hidup Wi-Fi ditentukan oleh en1, jangan hanya melihat system_profiler
#    ★★ dan pastikan "nirkabel = en0" (patch/penggantian kartu dapat mengubah urutan mount driver) ⇒ network-en0-order.md
networksetup -listallhardwareports
ifconfig en1                          # diharapkan ada inet + status: active
ifconfig awdl0                        # ada = AirDrop / Handoff tersedia

# ④ Apakah root patch sudah terpasang
ls /System/Library/CoreServices/OpenCore-Legacy-Patcher.plist
ls -l /System/Library/Frameworks/IO80211.framework/Versions/A/   # harus ada biner, tidak boleh hanya Resources

# ⑤ Apakah kext pihak ketiga dipindahkan
ls /Library/Relocated\ Extensions 2>/dev/null || echo "OK: tidak ada"

# ⑥ Hasil injeksi OC
ls -lt /Volumes/EFI/opencore-*.txt | head
```

| Kriteria | Diharapkan |
|---|---|
| `uname -r` | `25.x` |
| Empat komponen nirkabel | semuanya ✅ |
| `en1` | ada `inet` + `active` |
| `awdl0` | ada |
| `OpenCore-Legacy-Patcher.plist` | ada |
| `/Library/Relocated Extensions` | **tidak ada** |

---

## 7. Jebakan lingkungan baru di macOS 26

| Jebakan | Gejala | Cara yang benar |
|---|---|---|
| **Mount EFI wajib dengan hak admin** | `diskutil mount disk1s1` melaporkan `Volume on disk1s1 failed to mount` | **bukan sistem file yang rusak**: hak akses `/Volumes` di macOS 26 menjadi `drwxr-xr-x root wheel`, pengguna biasa **tidak bisa membuat titik mount**. Gunakan `osascript -e 'do shell script "mkdir -p /Volumes/EFI; diskutil mount disk1s1" with administrator privileges'` |
| **FAT diganti ke implementasi FSKit** | opsi mount memunculkan `fskit` | perilakunya berbeda dari `msdosfs` lama, jangan menilai dengan pengalaman lama |
| **Menghapus file di EFI menyisakan `.Trashes`** | mount gagal, `..' entry in /.Trashes/501/OC has incorrect start cluster` | `rm -rf` di atas FAT akan diubah safe-delete menjadi "pindahkan ke Sampah" ⇒ entri direktori rusak. **Perbaikan: `diskutil repairVolume diskXsY`** |
| **Filter waktu pada `log show` tidak berfungsi** | `--start/--end` melaporkan `Wall Clock adjustment detected` dan mengembalikan seluruh basis data log | gunakan **filter streaming**, lihat `boot-timeline.md` |

---

## 8. Bagaimana memilih antara dua jalur Wi-Fi

| | **OCLP 3.0.0-rc.3+ (jalur legacy)** | AppleBCMWLANCompanion (BCMC) |
|---|---|---|
| root patch | **diperlukan** | tidak diperlukan |
| **AWDL / AirDrop / Handoff** | **dipertahankan** ✅ | **tidak didukung** ❌ (kutipan asli proyek `Documentation/Issues.md`: *"AWDL is not currently available"*) |
| SIP | dapat dilonggarkan | **wajib menyalakan SIP** (bertabrakan langsung dengan **driver kartu grafis pihak ketiga**) |
| VT-d / AppleVTD | tidak diperlukan | **diperlukan** |
| Upgrade OTA | normal | **akan kernel panic** (harus dimatikan sebelum upgrade) |
| Kematangan | prerelease, tetapi **hanya satu yang mendukung Tahoe** | "Beta Testing — Not Recommended for Daily Use" |

> ⇒ **Tujuan mengganti kartu Broadcom justru adalah AirDrop / Handoff ⇒ pilih OCLP.** Hanya jika OCLP gagal barulah turun ke BCMC (pada saat itu AirDrop akan hilang).

---

## 9. Rollback

| Apa yang di-rollback | Bagaimana caranya |
|---|---|
| Perubahan EFI | timpa seluruhnya dengan cadangan EFI sebelum upgrade; atau skrip khusus seperti `add-tahoe-wifi-kext.sh --revert` |
| OCLP root patch | **Revert Root Patches** dari OCLP (atau Uninstaller) |
| Kext yang dipindahkan | `prep-oclp-rootpatch.sh --restore` |
| Seluruh sistem | cadangan Time Machine sebelum upgrade (**wajib dilakukan sebelum peningkatan versi besar**) |

---

## 10. Troubleshooting

| Gejala | Yang perlu diperiksa |
|---|---|
| Wi-Fi sepenuhnya hilang setelah upgrade | **Normal**. Periksa apakah entri `MinKernel=25.0.0` di §2.1 ada; `kmutil showloaded` untuk melihat apakah `AirPort.BrcmNIC` ada |
| `IOSkywalkFamily` ada, tetapi `IO80211FamilyLegacy` tidak | Lihat hasil injeksi kext tersebut di log OC (`opencore-*.txt`); pastikan `Kernel > Block` tidak memblokirnya sendiri |
| Root patch tidak bisa dipasang | Apakah FileVault benar-benar dimatikan (`fdesetup status`); apakah memakai 2.5.1 (**tidak mendukung Tahoe**) |
| Kext NVIDIA hilang saat patch | Skrip proteksi pra-OCLP di §3 belum dijalankan. Ambil kembali dari `/Library/Relocated Extensions` |
| **Model tidak didukung, tidak bisa boot** | tambahkan `-no_compat_check` (**jangan mengganti model**, §5.3) |
| **Bisa boot tetapi tidak menerima pembaruan sistem** | Terlewat **`revpatch=sbvmm`** (§5.3) — `-no_compat_check` tidak menyelesaikan masalah ini |
| Tidak bisa boot (**jika** Anda mengganti model) | **OEM SSDT motherboard gagal diurai** (di mesin ini `xh_adls3` ⇒ `HS06 AE_NOT_FOUND`, lihat `smbios-and-serials.md` §2); boot dengan EFI USB drive lalu kembalikan. **Inilah alasan batasan "jangan ubah model saat upgrade" ada** |
| Menemukan model sudah berubah | Kemungkinan besar pernah menjalankan `nullmoth-setup.sh --update prepare --pkg` (§5.5). Pulihkan `PlatformInfo` dengan cadangan EFI sebelum upgrade |
| EFI tidak bisa mount | Lihat §7: perlu hak admin; atau jalankan `diskutil repairVolume` dulu |
| Boot sangat lambat setelah upgrade | Lihat `boot-timeline.md` (dua jenis penundaan tetap yang diketahui: `nvrmsettle` / `-wegnoigpu`) |

---

## 11. Hubungannya dengan reference lain

- **Detail kartu jaringan** → `broadcom-wifi.md` (Broadcom, jalur terpisah per sistem), `intel-wifi.md` (Intel, dua set ABI Sequoia/Tahoe), `mediatek-wifi.md` (MediaTek)
- **Model dan tiga kode** (**keputusan terpisah, jangan dicampur dengan upgrade**) → **`smbios-and-serials.md`** (OEM SSDT motherboard, aturan urutan, **ganti model wajib ganti kode**, CPUFriend dibuat ulang, checklist item turunan)
- **Alur aman mengubah ESP** → aturan wajib 1–16 di `SKILL.md` + `scripts/oc-edit-safe.sh`
- **Pembacaan log** → `logs-and-debug.md`; **analisis durasi** → `boot-timeline.md`
- **Enam tahap instalasi** → `lifecycle.md` (artikel ini adalah pelengkap "peningkatan versi besar"-nya)
