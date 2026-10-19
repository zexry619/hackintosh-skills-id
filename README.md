# hackintosh-skills

Kumpulan **Skill** terkait Hackintosh (OpenCore), berlaku untuk WorkBuddy / CodeBuddy.

Ubah "mengubah konfigurasi Hackintosh" dari **berasal dari coba-coba** menjadi **proses berbasis dokumen, yang dapat di-rollback dan diverifikasi ulang**.

Direktori `opencore-config-audit/` adalah skill itu sendiri: cukup salin seluruhnya ke direktori skills Anda (atau pasang lewat plugin marketplace seperti dijelaskan di bawah).

> **Tidak tahu cara menggunakannya?**
> ① Tanyakan langsung di percakapan **"bagaimana cara memakai opencore-config-audit"** — skill akan mengeluarkan panduan penggunaan dirinya sendiri;
> ② Atau lihat [`opencore-config-audit/USAGE.md`](opencore-config-audit/USAGE.md);
> ③ Untuk mekanisme pemanggilan dan "cara mengubah skill", lihat [`USAGE.md`](USAGE.md).

**Daftar isi**

- [Skill yang Termasuk](#skill-yang-termasuk)
- [Pemasangan](#pemasangan)
- [Struktur Direktori](#struktur-direktori)
- [`opencore-config-audit` — Tinjau dan Pemeliharaan Konfigurasi](#opencore-config-audit--opencore-tinjau-dan-pemeliharaan-konfigurasi)
- [Kesesuaian dan Batasan](#kesesuaian-dan-batasan)

---

## Skill yang Termasuk

| Skill | Satu kalimat | Skala |
|---|---|---|
| **`opencore-config-audit`** | Meninjau / mengubah / memelihara konfigurasi OpenCore EFI — mencakup seluruh siklus hidup dari pemasangan sampai penggunaan harian, hingga peningkatan versi besar sistem, dan berisi **tema pemilih boot (OpenCanopy)** serta **ganti model / tiga kode** | 21 aturan wajib · 32 referensi · 18 skrip |

Di dalam direktori skill terdapat `USAGE.md` (**disalin bersama saat pemasangan**), yang bisa diperoleh dengan bertanya "panduan penggunaan" di percakapan.

---

## Pemasangan

**Cara satu: pasang sebagai plugin marketplace (disarankan)**

Marketplace manifest sudah disiapkan di repo ini, cukup tambahkan:

```bash
# ① Tambahkan marketplace
/plugin marketplace add GeekAudio/hackintosh-skills

# ② Pasang plugin (<nama plugin>@<nama marketplace>)
/plugin install opencore-config-audit@hackintosh-skills
```

**Cara dua: salin manual (offline / hanya satu)**

```bash
# Tingkat pengguna (bisa dipakai di semua proyek)
cp -R opencore-config-audit ~/.workbuddy-ai/skills/

# Atau tingkat proyek (hanya tersedia di proyek tersebut)
cp -R <skill> <direktori proyek>/.workbuddy-ai/skills/
```

Setelah terpasang, buat percakapan baru dan ucapkan satu permintaan dengan bahasa alami (misalnya "tinjau konfigurasi OpenCore saya") untuk memverifikasi apakah sudah berjalan.
Jika tidak tahu cara menggunakannya atau skill tidak terpicu, lihat **[`USAGE.md`](USAGE.md)**.

---

## Struktur Direktori

```
hackintosh-skills/
├── README.md
├── USAGE.md                     # cara memanggil + indeks (untuk dibaca manusia)
├── PUBLISHING.md                # alur penerbitan (marketplace sendiri / SkillHub)
├── .codebuddy-plugin/
│   └── marketplace.json         # ← daftar marketplace plugin (dibaca saat menambah marketplace)
├── tools/                       # alat pemelihara (tidak ikut terpasang bersama skill)
│   └── doc-lint.sh              #   pemeriksaan mandiri konsistensi dokumen: mencegah "satu kesimpulan salah lalu menular sepanjang rantai referensi"
└── opencore-config-audit/
    ├── .codebuddy-plugin/
    │   └── plugin.json          # ← metadata plugin
    ├── SKILL.md                 # alur utama + 21 aturan wajib + tabel sumber daya
    ├── USAGE.md                 # ← panduan penggunaan (disalin bersama saat pemasangan)
    ├── references/              # 32 dokumen tematik (lihat tabel di bawah)
    └── scripts/                 # 18 skrip (lihat tabel di bawah)
```

> **Setelah selesai mengubah dokumen, jalankan lebih dulu** `bash tools/doc-lint.sh`: periksa apakah indeks references/scripts selaras dua arah,
> apakah ada tautan mati, apakah tiga nomor versi konsisten, serta **apakah pernyataan kesalahan yang sudah diketahui dituliskan kembali**
> (misalnya "AirDrop bergantung pada `en0`" — skill ini pernah salah menulis semuanya sekali).

---

## `opencore-config-audit` — OpenCore Tinjau dan Pemeliharaan Konfigurasi

### Apa yang diselesaikan

Pertama gunakan **dokumen resmi + `ocvalidate` resmi** untuk menilai apakah konfigurasi sudah benar, lalu gunakan **contoh dari paket rilis resmi** untuk menilai apakah SSDT perlu ditambahkan,
terakhir gunakan **log saat boot** untuk menilai kondisi saat ini, lalu simpan mengikuti alur aman — setiap langkah punya dasar dan dapat di-rollback.

### Kemampuan

**⓪ Hindari jebakan hardware + tinjau BIOS / UEFI (lakukan sebelum memasang)**

- ★ **Satu langkah lebih awal**: `laobamac/SimpleBuyersGuide` "Panduan Hardware Hackintosh Tanpa Jebakan" — menyebutkan secara jelas CPU / GPU / chipset motherboard / SSD / kartu jaringan / kartu nirkabel yang **sebaiknya tidak dibeli**

- **Lihat tiga daftar secara bersamaan**: dokumen resmi OpenCore (9 daftar pemeriksaan) + Dortania (Intel / AMD terpisah) + tambahan dari pengalaman komunitas
- ★ **Dua hal yang tidak ditulis di dokumen resmi maupun Dortania, tetapi akan menggagalkan pemasangan jikamengalaminya**: **VMD harus dimatikan** (jika tidak, saat memasang sistem "tidak menemukan disk drive" sama sekali),
  **Intel Speed Shift harus dinyalakan** (jika tidak, `wrmsr(0x770,1)` #GP)
- ★ **Bedakan tiga kategori**: **harus dimatikan** (Fast Boot / Secure Boot / CSM / CFG Lock / VMD / RST / SGX / PTT / port serial) ·
  **harus dinyalakan** (VT-x·SVM / Above 4G / HT / XD / XHCI Hand-off / OS Type=Windows UEFI / AHCI / DVMT≥64MB) ·
  **tergantung kondisi** (Re-BAR / XMP / iGPU / Thunderbolt / ErP / **jumlah E-core**) — **bukan semuanya dimatikan atau semuanya dinyalakan**
- **Tabel padanan nama tiap vendor** (ASUS / MSI / Gigabyte / ASRock memakai nama berbeda untuk pengaturan yang sama) + **topik khusus CFG Lock** (tiga cara mencari + jalur opsi tersembunyi)
- **Skrip tinjauan Windows hanya-baca**: langsung menentukan tipe firmware / Secure Boot / TPM / VT-x / HT / XMP / VMD·RST / port serial / jumlah slot memori,
  dan yang tidak bisa dipastikan ditandai jelas sebagai "perlu diperiksa manual"

**① Siklus hidup penuh**

```
① Di Windows gunakan RapidEFI untuk membuat EFI dasar → ② Gunakan untuk memasang macOS → ③ Setelah masuk sistem, ganti ke OpenCore DEBUG
        → ④ Kumpulkan log saat boot → ⑤ Perbaiki item demi item sesuai dokumen resmi → ⑥ Kembalikan ke penggunaan harian (ganti kembali ke RELEASE + matikan log debug)
```

> Tahap ③④ adalah kunci: **tanpa build DEBUG Anda tidak mendapatkan log lengkap, dan tanpa log Anda hanya bisa menebak.**

**② Tinjauan konfigurasi**

- ★★★ **Apakah perlu memperbarui kext / OpenCore — buktikan dulu bahwa pembaruan memang perlu**: **tag upstream tidak ditemukan ≠ asal-usul tidak jelas** — `dortania/build-repo` **dibangun berdasarkan commit**, sehingga begitu upstream punya commit setelah release terakhir, **nomor patch naik +1**, dan biasanya **dipatok oleh skrip instalasi vendor + diverifikasi SHA-256** (pada mesin ini `Lilu 1.7.3` / `VirtualSMC 1.3.9` / `WhateverGreen 1.7.2` … upstream 404 satu per satu, semuanya build Dortania) ⇒ **mengganti ke release upstream = downgrade**; empat kriteria (tag upstream · metadata build · hash biner · **installer vendor**), **hanya yang terakhir yang bisa memastikan**; ★ **`DTXcode` lama ≠ mencurigakan**; ★ DEBUG/RELEASE dinilai dengan **perbandingan ukuran**; ★★ **mengganti build OpenCore harus mengganti Drivers resmi bernama sama sekaligus**


- **Bandingkan tiap kunci dengan dokumen resmi**: ambil paket rilis resmi sesuai versi OpenCore di mesin, validasi dengan `ocvalidate` resmi, dan ekstrak
  `Type / Failsafe / Description` dari **seluruh entri konfigurasi** di `Configuration.tex` (**420 entri**, di antaranya **401 entri** punya `Type`) menjadi pustaka kunci,
  lalu nilai tiap kunci "nilai Anda vs default resmi" dan bagi tiga kelas: **deviasi benar yang berdasar / bertentangan dengan dokumen / sisa yang tidak perlu**
- **Pemeriksaan ACPI / SSDT**: bandingkan satu per satu dengan perangkat nyata Anda memakai `Docs/AcpiSamples/` resmi (18 contoh); ★★ **rujukan utama pustaka contoh hot-patch adalah `5T33Z0/OC-Little-Translated`** (★745, **masih diperbarui**) — berawal dari terjemahan ke bahasa Inggris `daliansky/OC-little` tetapi **jauh melampaui aslinya** (bab 7–20 + lampiran lengkap A–Z), **hanya memakai hot-patch ACPI, tanpa DSDT patch**; memuat **tabel indeks untuk mencari bab mana sesuai kebutuhan (termasuk penerapannya pada mesin ini)** serta **hal-hal yang tidak ada di dokumen resmi/Dortania**: tabel gabungan `SSDT-ALL` · **pemetaan port USB dengan ACPI** · `SSDT-I225V` · `SSDT-PMCR` · `ACPIDebug` · `Fixing_Preboot`
- **Penyederhanaan kext**: cari item yang dinonaktifkan dan berkas yatim, termasuk daftar "tidak boleh dihapus"
- **Penyembunyian disk**: `/etc/fstab` + `noauto` (berdasarkan UUID volume), **secara eksplisit mengecualikan partisi EFI** dan melakukan verifikasi mount

**③ Log dan pengumpulan bukti waktu**

- ★★ **Tidak bisa memasang / tidak bisa masuk sistem ⇒ jalankan dulu "alur debug berlapis"**: **jangan langsung mengubah konfigurasi** (begitu diubah, Anda tidak bisa mereview); pecah proses boot menjadi **① firmware/OpenCore itu sendiri ② masa boot OC ③ tahap awal kernel (< 1–2 d) ④ tahap akhir kernel/user space** empat bagian, dan tentukan dulu di bagian mana macet; ★★ **bedakan dulu antara "macet total" atau "restart berulang"** — **restart berulang = boot watchdog timeout, "tunggu lebih lama" tidak berguna**; memuat **kelompok kegagalan yang sudah terklasifikasi pada mesin ini** (`no kext summary` = kegagalan lapisan cache paling awal **terkait GPU** · `X86PlatformShim` ⇒ periksa BIOS `Speed Shift` · assert dekompresi `decmpfs` · `element modified after free` ⇒ `NVMeFix`) · **urutan rescue 6 langkah** (kembali ke konfigurasi yang terakhir bisa dipakai → EFI dari U disk → Recovery mount EFI internal → bagi dua dengan "ubah satu hal saja per waktu") · daftar pengumpulan bukti


- **Pengumpulan bukti saat boot**: baca `opencore-*.txt` milik OpenCore sendiri (definisi bit `Target`, kriteria `OCABC:`, daftar tabel ACPI, registrasi entri boot, ambang driver APFS) dan log kernel macOS (error ACPI, mount perangkat platform)
- **Analisis waktu boot / linimasa**: ukur secara terpisah dalam **segmen OC / segmen driver kernel / segmen user space**, gunakan "jendela macet" untuk menemukan penundaan (cari celah terbesar di `launchd.log` → **filter streaming** `log show`, melewati filter waktu yang tidak berfungsi), dan berikan tabel penanganan sumber waktu (termasuk dua jenis latensi tetap yang dikenal dari sisi driver, `nvrmsettle` / `-wegnoigpu`)
- ★ **Entri boot firmware (`Boot####`)**: akar penyebab dan cara memperbaiki **"setelah boot sekali dari U disk, entri boot OpenCore di hard disk hilang dari BIOS dan hanya tersisa Windows"** — `LauncherOption=Full` **mengenali entrinya sendiri berdasarkan akhiran path file (tidak melihat disk)**, sehingga ketika di-boot dari disk lain ia akan mengarahkan ulang ke sana; ⇒ **kombinasi final = disk target `Full` (membuat sendiri + self-heal) / salinan lain `Disabled`** (★ jika keduanya `Disabled`, tidak ada yang membuat entri)
- ★★ **Menambahkan kembali: metode resmi** (`Configuration.pdf`) — **B** di OpenShell `bcfg boot add 0 FSx:\EFI\OC\OpenCore.efi "OpenCore"` (★ **disarankan resmi**, murni U disk, tanpa Windows) · **C** `bcfg` gagal menulis ⇒ jalankan dulu `\EFI\OC\Tools\OpenControl.efi disable` (+ `FullNvramAccess=true`) lalu ulangi, **setelah itu wajib restart** · **A** `LauncherOption=Full` membiarkan OpenCore membuatnya sendiri (**tidak menyelesaikan masalah "telur dan ayam"**) · **D** menulis dari dalam sistem (macOS `nvram` / Linux `efibootmgr` / Windows EasyUEFI) — ★★ **prasyarat: `RequestBootVarRouting=false` pada boot tersebut**, jika tidak, "berhasil ditulis, dibaca kembali sama" semuanya false positive ⇒ **kriteria hanya melihat BIOS setelah restart**; lampiran `BootKicker` (biasanya tidak tersedia di Hackintosh)
- ★ **Berubah dari boot U disk ke boot hard disk**: langkah migrasi lengkap + verifikasi tiga langkah (ada di BIOS dan menjadi yang pertama / `boot-path` menunjuk hard disk / **lepas U disk lalu restart**)

**④ Peningkatan versi besar sistem (misalnya macOS 15 → 26)**

- ★★ **Batasan keras ①: tambahkan `MinKernel` / `MaxKernel` ke kext yang build-nya dipisah per versi** — entri versi lama dikunci batasnya di `24.99.99`, entri versi baru ditulis `MinKernel 25.0.0` (Broadcom `AirPortBrcmNIC-Tahoe.kext`, Intel `AirportItlwm-Tahoe` memang dipisahkan begitu)
- **Peningkatan pasti memotong**: Wi-Fi hilang, OCLP root patch hilang semua, kext pihak ketiga mungkin terpindahkan — ini memang perilaku desain, bukan konfigurasi rusak
- **Urutan**: sebelum peningkatan **backup seluruh EFI** + matikan FileVault + lindungi kext pihak ketiga → peningkatan → lengkapi entri kext → terapkan ulang OCLP root patch → verifikasi setelah restart
- ★★ **Batasan keras ②: jangan mengganti model saat peningkatan** — `SystemProductName` / `BoardProduct` / tiga kode pada `PlatformInfo` tidak boleh disentuh sama sekali. Daftar putih **hanya dipakai untuk menilai "perlu atau tidaknya bypass"**, bukan dasar untuk "perlu atau tidaknya mengganti model": pada Intel Tahoe hanya tersisa `iMac20,1` `iMac20,2` `MacPro7,1` `MacBookPro16,x` (`iMacPro1,1` dihapus); **tidak ada di daftar ⇒ tambahkan boot-arg untuk bypass**: `-no_compat_check` (bisa boot) + `revpatch=sbvmm` (bisa menerima update), **keduanya perlu**
- **Ganti model adalah hal terpisah, jangan digabung ke dalam peningkatan versi** — hal ini turut memicu **perubahan board-id yang menyebabkan ACPI diurai ulang** (penyebab sebenarnya pada mesin ini adalah **SSDT OEM motherboard**, lihat §⑤), pembangunan ulang system volume, perubahan XCPM profile (`smbios-and-serials.md` §2)
- **Jebakan lingkungan baru di macOS 26**: mount EFI wajib dengan hak akses, FAT diubah ke FSKit, menghapus berkas di EFI menyisakan `.Trashes`

**⑤ Driver dan karakteristik hardware**

| Tema | Poin utama |
|---|---|
| **GPU NVIDIA diskret** (NullMoth) | Ruang lingkup GPU yang cocok, dua jalur instalasi, ★ "pasang di `/Library/Extensions` agar dimuat dari AuxKC ⇒ jangan lagi menyuntik dari `EFI/OC/Kexts`", pengaturan OC yang wajib, jalur pemulihan, disiplin pelaporan |
| **App tidak mendapat izin** (AMFI ↔ TCC) | Mematikan AMFI ⇒ **tidak muncul dialog izin, dan tidak ada entri di daftar privasi** ⇒ app suara/kamera tidak akan pernah mendapat izin; ★ **di mesin lain pilihan pertama adalah `AMFIPass.kext`** (AMFI tetap ada, masalah hilang dengan sendirinya), tetapi driver NullMoth mencantumkannya **sebagai syarat bersama** dengan parameter AMFI ⇒ hanya bisa pilih salah satu; ★★ **solusinya = [`GeekAudio/tcc-helper`](https://github.com/GeekAudio/tcc-helper)** (Swift GUI + CLI, Release v1.0.0 ada DMG): **otomatis menyimpulkan siapa butuh izin apa dari usage description di `Info.plist` + komponen launchd latar belakang**, 109 layanan, target apa pun (termasuk executable telanjang), backup otomatis sebelum menulis + `killall tccd` setelah menulis; ★★ **yang perlu diotorisasi adalah "helper yang benar-benar mengajukan izin"**, bukan selalu app utamanya; ★ entri tidak persisten |
| **Nirkabel Intel** (AirportItlwm / itlwm) | Dua varian, ★ "Sequoia dan Tahoe memakai ABI serta artefak yang berbeda ⇒ konfigurasi yang dipakai bersama dua sistem wajib dipisahkan dengan `MinKernel`/`MaxKernel`", pasangan Bluetooth, kemampuan dan batasan di macOS 26 |
| **Nirkabel MediaTek** (MT7921 / MT7922 / RZ608 / RZ717) | ★★★ **driver Sunrise native di macOS 26** ⇒ coba dulu dengan "tidak memasang apa pun"; ★★ **apa yang sudah "bawaan" di 26.7.1 bergantung pada chip** (firmware Bluetooth MT7922/7923 sudah tertanam · **firmware Wi-Fi MT7932/RZ717 sudah tertanam** (mengganti ke RZ717 baru benar-benar tanpa langkah tambahan) · **❌ firmware Wi-Fi MT7922/RZ616 masih hilang**); ★★★ **kalau mau bertindak, pakai dulu `GeekAudio/mediatek-sunrise-hackintosh` (MT7922 Sunrise Pack)** — kumpulkan 69 halaman lampiran thread asli menjadi satu paket: firmware (linux-firmware + SHA256) · **`AppleSunrise.kext` yang diekstrak dari dua versi KDK** · SSDT · **penyamaran device-id `DeviceProperties` tanpa kompilasi** (`0x7922 → InkAAA==`) · daftar boot-args · kumpulan lengkap kext pihak ketiga untuk macOS 15 (termasuk SimpleMTK.app yang sudah dikompilasi); ★ **`AppleSunrise.kext` = HAL mode kernel (hanya ada di KDK) ⇒ tanpa menyuntiknya, DEXT tidak bisa mengoperasikan register**; memuat **tabel interpretasi log** dan tabel boot-args `wlan.debug.enable` / `mtk.wlan.startdelay` / `mtk.wlan.hangonstart`; **Wi-Fi pihak ketiga memakai fork `flxxxxddd/SimpleMtkWlan` (ada release, 802.11n/ac bisa dipakai)** tetapi punya **batasan keras**: interface bergaya Ethernet, tidak ada menu Wi-Fi native, **AirDrop/Continuity mustahil secara desain**, tanpa HE; ★ jebakan paling sering = **kartu disembunyikan oleh `SSDT-Disable_Network`** |
| **Kabel jaringan** (Intel / Realtek) | ★★ **pada mesin ini yang dipakai adalah Intel `I225-V`**; `SimpleVGBE` (I225/I226) · `SimpleEthernet` (plugin Lilu, i225/226/210/211) · `SimpleRTK5` (RTL8125/8126); ★ **ganti satu set saja per waktu**, **setelah mengganti periksa ulang kepemilikan `en0`** |
| **Kabel Broadcom** (BCM943602CDP / BCM43602) | ★ **pisah jalur per sistem**: Sequoia memakai `IO80211FamilyLegacy`, Tahoe memakai `AirPortBrcmNIC-Tahoe.kext` terpisah; perlindungan awal untuk OCLP root patch; ★ untuk mengecek hidup/mati lihat `ifconfig en1` |
| **AirDrop / Handoff** (transfer nirkabel) | ★★★ **hanya bergantung pada `awdl0`** (= nirkabel menjalankan stack `IO80211Family` native Broadcom) ⇒ **`itlwm.kext` pasti tidak bisa dipakai** (FAQ resmi: memakai `IOEthernetController`, bukan `IO80211Family`; `AirportItlwm` juga hanya mendukung Handoff + clipboard universal); ★★★ **tidak ada hubungannya dengan `ROM` / `en0` / model / nomor seri / `SystemUUID`** — itu adalah syarat **iServices** (iMessage) dari Dortania yang keliru digeneralisasi ke AirDrop; memuat **urutan 8 langkah pemecahan masalah** dan empat kesalahan penilaian |
| **Sound card onboard** (AppleALC) | ★★★ **prasyarat di macOS 26: kembalikan dulu `AppleHDA`** (Apple menghapusnya di DP2; **tanpa langkah ini, semua layout-id berikutnya sia-sia**); ★ kriteria: **audio digital HDMI/DP masih berfungsi** ⇒ "hanya HDMI yang berbunyi, onboard tidak berbunyi" persis gejala ini; ★★ rujukan utama **`perez987/AppleHDA-gone-on-macOS-26-Tahoe`**, opsi diurutkan dari yang paling praktis: **sound card USB** · **KDK + `MyKextInstaller`** (pilihan utama) / `SimpleLoader` — mensyaratkan **KDK + `AppleALC ≥ 1.9.5` + `csr-active-config=03080000`**, setelah dipasang restart lalu verifikasi `kextstat | grep AppleHDA` · OCLP root patch (`Audio_Tahoe.md` dari `5T33Z0/OCLP4Hackintosh`) · `SimpleVoodooHDA` (kualitas suara berkurang); ★★ **versi KDK adalah jebakan terbesar: di KDK macOS 26 sama sekali tidak ada `AppleHDA`** ⇒ langsung turunkan ke **`KDK 15.8.1 build 24H32` (versi terakhir yang membawa AppleHDA, 600.2)**; pasang ke **`/System/Library/Extensions`**, `kmutil install --volume-root / --update-all`, setelah dipasang **bandingkan sha256 dengan yang dari KDK** + periksa AuxKC; ★★ **biayanya: begitu sistem di-upgrade/diinstal ulang semuanya hilang, setiap kali harus dipasang ulang**; ★ `SimpleHDA` sudah turun menjadi pilihan cadangan; ★★ **untuk layout buatan sendiri ikuti `5T33Z0/AppleALC-Guides`** (wiki resmi menjelaskan aturan, panduan ini menjelaskan cara): alur 14 bab · **17 codec dump siap pakai** (dengan `verbs.txt` + versi desimal + diagram topologi `.svg`) · **`alc-verb` untuk menyetel audio saat runtime** (`alcverbs=1`, **tanpa kompilasi ulang tanpa restart**; untuk pemengapan gunakan `WakeConfigData`, untuk port gabungan gunakan `ALCPlugFix-Swift`) · **tabel ringkas desimal `MuteGPIO`** · **AppleALC diperkecil dari 3.8 MB → ~90 KB** · **alur pengelolaan berkas/rollback**; ★★★ **batasan keras untuk layout custom: data dari sisi Windows harus sudah ada sebelum mulai** (kalau pengguna bisa menyediakan, langsung masuk alur custom); **dua sub-jalur di Windows**: HDAU GUI, atau **skrip Python yang terhubung langsung ke `HDAudDev.dll` (tanpa hak admin, bisa di-script, menghasilkan `codec_dump.txt/.json` bergaya Linux)**; ★★ **setelah dump, buktikan pemetaan jack lewat endpoint Windows** (refstring interface topologi KS `elineouttopo`/`eheadphonetopo`/`emicintopo` langsung menunjukkan pin mana termasuk jack mana; satu grup asosiasi hanya dibuat satu endpoint ⇒ verifikasi pengelompokan); ★ ringkasan cara memperoleh data: Windows HDAU/DLL / Linux (**satu-satunya yang bisa menghasilkan diagram topologi**) / OpenCore (darurat); ★★ **`-alcdbg`/`-liludbg` hanya berlaku pada build DEBUG**; ★★★ **tiga akar causa AppleHDA hasil pengukuran**: PathMap dengan beberapa jalur dalam satu grup **hanya menyimpan yang terakhir** · pin Mic bertipe jack **tidak bisa membuat perangkat input** (`PortConnectivity 0b00` ⇒ tandai `0b10`) · deteksi jack **mungkin mati secara keseluruhan** (pin sense selalu 0 ⇒ jangan melakukan auto-switch); ★★ **verifikasi bukan dengan telinga**: saat pemutaran baca register `0xF07`/`0xF06` untuk menentukan "perangkat mana menyalakan port mana"; ★ layout custom hanya boleh memakai 11–99 |
| **HiDPI** (one-key-hidpi) | Kejelasan layar non-Retina; ★ driver NVIDIA belum sempurna, termasuk risiko dan jalur pemulihan; ★ jangan dicampur dengan `UIScale` saat boot |
| **Turbo boost Intel** | ★★★ **metode terbaik yang sudah final: injeks "profile milik mesin ini sendiri, hanya menghapus `hwp`"** — empat kriteria (**1 segmen** / batas atas setinggi mungkin / **`hwp` sudah dihapus** / `CPUFloor` cocok); ★ `hwp` **tidak ada di dalam plist** (ada di dalam tabel nama variabel pada biner vektor 7668 B di offset ~7128) ⇒ untuk menilai "berpengaruh atau tidak" harus **membandingkan byte per byte**; ★★ **kesimpulan negatif: menyuntik profile model lain akan men-downgrade turbo boost** (terukur `iMac19,1` ⇒ 1.97 GHz, `MacPro7,1` ⇒ 2.3 GHz); memuat **tabel pemilihan dari 76 profile dalam lima keluarga** (pembatas = jumlah segmen, **semua yang batasnya 5000 adalah 3–5 segmen** ⇒ kompatibilitas struktur tidak bisa dimiliki keduanya); ★ verifikasi CPU-S · **wajib restart setelah diubah** · BIOS `Speed Shift` harus Enabled |
| **Aktifkan / nonaktifkan E-core** | Dua pilihan trade-off pada arsitektur hybrid Intel gen 12+: **nonaktif = stabil** (BIOS `Active Efficient Cores = 0`, **tidak perlu mengubah satu baris pun di konfigurasi**) · **aktif = cepat** (`= All` + `ProvideCurrentCpuInfo=true` + `CpuTopologyRebuild.kext`); ★ kriteria `hw.nperflevels` (**1 = E-core tidak diekspos / 2 = P+E keduanya dikenali**); ★★ "hanya melihat 8 core 16 thread" **bukan berarti core hilang**; ★ sintaks **v2 milik `ctrsmt=off` / `ctrsmt=full` tidak kompatibel dengan `-ctrsmt` milik v1**; ★ resmi diketahui **mengaktifkan E-core + `-v` bisa gagal boot secara acak** |
| **Nama tampilan CPU salah** | "Tentang Mac Ini menampilkan Xeon W padahal saya i7" — **masalah murni tampilan** (frekuensi/jumlah core semuanya benar, hanya nama yang dipetakan sesuai model); **tiga setelan RestrictEvents**: `revpatch=cpuname` (boot-args) + `revcpu=1` (boot-args) + `revcpuname=<nama>` (NVRAM); ★★ **jebakan terbesar: `rev*` pada NVRAM berprioritas lebih rendah daripada boot-args** ⇒ boot-args juga harus memuat `cpuname`; ★ `revcpuname` yang mengandung spasi **hanya boleh diletakkan di NVRAM**; ★ pada Intel, `revcpu` **default 0**; ★ `ProcessorType` harus disesuaikan dengan jumlah core (8 core+ = `0x0F01`); ★ **`Cpuid1Data` tidak bisa mengubah nama**, **jangan mengubah `AppleSystemInfo.strings`** |
| **Kustomisasi memori** | ★★ **jumlah slot berubah sesuai model** (`MacPro7,1`=**12 slot** / `iMac20,1`=**4 slot**) ⇒ mengganti model harus diulang bersamaan; ★ **dibagi dua lapisan**: "Informasi Sistem" = seragam untuk semua model (SMBIOS Type 17); diagram memori "Tentang Mac Ini" = **khusus MacPro** (**aturan penempatan + tabel pemetaan 12 slot**) |
| **Pergantian model SMBIOS + tiga kode** | ★★★ **mengganti model harus mengganti tiga kode sekaligus** — nama model di "Tentang Mac Ini" adalah **fungsi dari kode produk nomor seri**, tanpa mengganti kode nama model lama akan terus tampil (`macserial -i` bisa dipakai untuk mendekode dan mencocokkan lebih dulu); **kerangka terkait dikerjakan lengkap sekaligus**: tiga kode · prasyarat ACPI/SSDT · `CPUFriend` · **jumlah slot injeksi memori** (MacPro7,1=12 / iMac20,1=4) · `ROM` · **nama komputer/nama host/nama SMB**; ★★★ **urutannya: lengkapi SSDT/ACPI dulu (verifikasi di model lama) → baru ganti SMBIOS → baru kerjakan ulang CPUFriend**; ★ yang benar-benar membuat mesin ini tidak bisa masuk sistem adalah **SSDT OEM motherboard** (`xh_adls3` pada ASUS Z690 ⇒ `HS06 AE_NOT_FOUND`), cara memperbaikinya = hapus tabel asli dengan `ACPI>Delete` + tambahkan `SSDT-XHADLS3.aml`; USB map/OCLP/model itu sendiri/15 port/NVRAM sudah disingkirkan; tiga kriteria nomor seri, ROM memakai MAC en0 asli, disiplin risiko saat mengganti kode. ★ **terpisah dari peningkatan sistem** (model tidak disentuh saat upgrade) |
| **Pembuatan EFI pertama** (RapidEFI) | Membuat EFI dasar di Windows, dan langkah penyelesaian yang wajib dilakukan setelahnya |
| **Tema pemilih** (OpenCanopy) | Kumpulan ikon, tabel bit `PickerAttributes`, aturan Flavour, label/font/audio/latar belakang, HiDPI; ★ **kekurangan satu ikon wajib membuat sistem tidak mau boot**, **ikonset resmi tidak menyediakan ikon opsional apa saja** (menjelaskan mengapa `Not Found` di log itu normal) |

### Alur aman bawaan (bagian terpenting)

Backup sebelum mengubah ESP → baca yang live dulu lalu bandingkan diff → ubah dengan `plutil` → `plutil -lint` → `ocvalidate` resmi → hitung sha → sinkronkan mirror workspace + arsip versi → `sync` → lepas mount → mount ulang → **verifikasi ulang sha konsisten**.

### Skrip

| Skrip | Fungsi |
|---|---|
| `fetch-opencore-docs.sh` | Mengambil paket resmi versi yang sama (`ocvalidate` + `Sample.plist` + `AcpiSamples`) dan membangun pustaka kunci (420 entri / 401 entri dengan `Type`) |
| `oc-verify.sh` | Validasi sekali klik: `plutil` + `ocvalidate` + integritas referensi ACPI/Kexts + berkas yatim + sha |
| `oc-swap-build.sh` | Berganti build RELEASE ↔ DEBUG (ganti Drivers resmi bernama sama sekaligus, pertahankan driver pihak ketiga) |
| `oc-edit-safe.sh` | Pembungkus untuk mengubah config dengan aman (`begin` backup / `finish` validasi, arsip, simpan, verifikasi ulang) |
| `grab-logs.sh` | Mengambil log boot OC dan log kernel dari boot ini (perlu hak akses, bisa `--oc-only`) |
| `boot-timeline.sh` | Ringkasan waktu boot (atribut NVRM + `dmesg` + linimasa launchd + log kernel, dengan proteksi timeout) |
| `find-boot-gap.sh` | Pencarian detail jendela macet saat boot (cari celah terbesar di `launchd.log` → **filter streaming** `log show`, tanpa menulis berkas besar) |
| `mask-other-disks.sh` | Menulis fstab berdasarkan UUID untuk menyembunyikan volume non-sistem (dry-run secara bawaan, tidak pernah menyentuh EFI) |
| `cpu-freq-probe.sh` | Probe frekuensi CPU sebenarnya (assembly inline, mencegah optimizer memb-fold) — verifikasi turbo boost / bandingkan model |
| `e-cores-check.sh` | **Pemeriksaan E-core**: topologi (`hw.nperflevels` / `perflevel1` / `CPUID`) + frekuensi + status pemuatan `CpuTopologyRebuild` + interpretasi |
| `kext-inventory.sh` | **Pemeriksaan daftar kext**: versi / `DTXcode` / `DTSDKName` / ukuran / sha256 (termasuk PlugIns di dalam paket) + **pemeriksaan referensi config (0 hilang)** + versi OpenCore itu sendiri; `--tsv` memudahkan diff, `--save` mengarsipkan bukti sebelum perubahan |
| `cpu-name-check.sh` | **Pemeriksaan nama tampilan CPU**: nama tampilan vs `machdep.cpu.brand_string` · parameter `rev*` (boot-args + NVRAM) · pemuatan `RestrictEvents` · pemeriksaan `ProcessorType` / `revcpuname` / `NVRAM>Delete` di config |
| `mem-check.sh` | Memvalidasi penempatan injeksi memori (nomor indeks array → posisi diagram prediksi, menentukan apakah meleset dari "Informasi Sistem") |
| `bios-audit.ps1` | **Tinjauan BIOS sisi Windows (hanya baca)**: menentukan tipe firmware/Secure Boot/TPM/VT-x/HT/XMP/**VMD·RST**/port serial/jumlah slot memori |
| `oc-nvram-bootentry.sh` | **Membaca/menulis entri boot firmware dari dalam sistem** (bantu untuk metode resmi D): `dump` (mengurai nama/path perangkat) · `backup` / `restore` · `add` (termasuk `--dry-run`) · `del`. ★ operasi tulis perlu hak akses; ★★ **dan hanya bermakna saat `RequestBootVarRouting=false`** |
| `redact-check.sh` | **Pemeriksaan mandiri sanitasi data sebelum terbit (hanya baca)**: memindai tiga kode / MAC / kunci / UUID volume / email / IP jaringan internal |
| `oc-theme-check.sh` | **Pemeriksaan kepatuhan pohon Resources** (ikon wajib / ukuran piksel asli / label / font / audio) |
| `oc-fetch-iconset.sh` | Mengambil ikonset / font / label / audio dari OcBinaryData resmi |

### Dokumentasi referensi

| Dokumen | Isi |
|---|---|
| `lifecycle.md` | **Alur penuh enam tahap**: membuat di Win → memasang → ganti DEBUG → kumpulkan log → perbaiki → jadikan penggunaan harian (ada ⑦ yang menunjuk peningkatan versi besar sistem) |
| `os-upgrade-15-to-26.md` | **Peningkatan versi besar sistem** (15 Sequoia → 26 Tahoe): ★★ **dua batasan keras** (pemisah versi kext · **tidak mengganti model**), daftar per komponen, urutan peningkatan, jebakan baru macOS 26, OCLP vs BCMC |
| `official-docs-method.md` | Cara memanfaatkan dokumen resmi, metode penilaian per kunci, **tabel hubungan berpasangan** |
| `logs-and-debug.md` | Definisi bit `Target` / `DisplayLevel`, kriteria log, atribusi spam layar |
| `boot-timeline.md` | **Analisis waktu boot / linimasa**: pemecahan tiga segmen, filter streaming, penentuan jendela macet |
| `boot-failure-debug.md` | **Alur debug berlapis untuk gagal memasang / gagal masuk sistem**: ★ **empat lapisan** · ★★ **macet total vs restart berulang** · tabel rujukan cepat tiap segmen (termasuk `no kext summary` / `X86PlatformShim` / `decmpfs` / `element modified after free` dan kelompok kegagalan lain yang sudah terklasifikasi pada mesin ini) · khusus masa pemasangan (VMD tidak menemukan disk) · **urutan rescue 6 langkah** · ACPI (`xh_adls3`) · daftar pengumpulan bukti |
| `boot-entries.md` | **Entri boot firmware (`Boot####` / `BootOrder`) dan `LauncherOption`**: ★ **akar penyebab "entri boot hilang setelah boot dari U disk"**, empat nilai, perintah pengumpulan bukti, **jebakan `Boot0000` di ASUS**; ★★ **§7 perbaikan resmi** (`bcfg` / `OpenControl` untuk membuka kunci NVRAM / self-heal `LauncherOption=Full` / menulis dari dalam sistem / `BootKicker`), **§8 berubah dari boot U disk ke boot hard disk (termasuk verifikasi tiga langkah)** |
| `acpi-ssdt.md` | Pemeriksaan ACPI/SSDT: syarat berlaku tiap item AcpiSamples resmi · pemeriksaan keberadaan perangkat · konvensi penamaan · ★★ **tabel indeks `5T33Z0/OC-Little-Translated` sesuai kebutuhan** (termasuk penerapannya pada mesin ini) · **hal-hal yang tidak ada di dokumen resmi/Dortania** (tabel gabungan `SSDT-ALL` · **pemetaan port USB dengan ACPI** · `SSDT-I225V` · `SSDT-PMCR` · `ACPIDebug` · `Fixing_Preboot`) |
| `bios-settings.md` | **Tinjauan BIOS/UEFI**: 9 item resmi + Dortania + tambahan komunitas (**VMD**/Speed Shift), **tiga kategori harus dimatikan/harus dinyalakan/tergantung kondisi**, topik khusus CFG Lock, **tabel padanan nama tiap vendor** |
| `disks-and-kexts.md` | Kriteria penyembunyian disk dan penyederhanaan kext, serta daftar "tidak boleh dihapus" |
| `kext-and-oc-update.md` | **Memperbarui kext dan OpenCore**: ★★★ **tag upstream tidak ditemukan ≠ asal-usul tidak jelas** (Dortania `build-repo` dibangun berdasarkan commit, nomor patch +1) · **empat kriteria untuk menilai "bawaan resmi"** (hanya "apakah sudah dipatok installer vendor" yang bisa memastikan) · **DEBUG/RELEASE dinilai dengan perbandingan ukuran** · tabel yang perlu dan tidak perlu diperbarui · **pembaruan OpenCore itu sendiri (ganti Drivers sekaligus)** · alur aman 9 langkah · jebakan |
| `rapidefi-first-efi.md` | Dari nol: membuat EFI dasar dengan RapidEFI di Windows beserta langkah penyelesaiannya |
| `nvidia-driver.md` | Driver NVIDIA NullMoth: ruang lingkup, instalasi, pengaturan OC yang wajib, pemulihan, tabel gejala dan koreksi |
| `amfi-and-tcc.md` | **Konflik AMFI ↔ TCC (app tidak mendapat izin)**: ★ tiga gejala berpasangan (**yang ketiga = tidak ada entri di daftar privasi** baru menjadi kriteria) · akar penyebab (`amfi=0x80`) · **di mesin lain pilihan pertama `AMFIPass`** (pada mesin ini tidak bisa, hanya pilih salah satu) · ★★ **solusinya `GeekAudio/tcc-helper`** (GUI + CLI, **otorisasi otomatis yang disimpulkan dari sistem**, 109 layanan, target apa pun) · **yang perlu diotorisasi adalah helper yang benar-benar mengajukan, bukan app utama** · kolom tabel `access` dan magic `csreq` `fade0c00` · **lima jebakan rekayasa** · tiga klasifikasi diagnosis · tidak persisten |
| `intel-wifi.md` | Kartu nirkabel Intel: jalur versi, injeksi, pasangan Bluetooth, pemecahan masalah |
| `mediatek-wifi.md` | Kartu nirkabel MediaTek: ★★★ **driver Sunrise native di macOS 26** · ★★★ **jalur native memakai `GeekAudio/mediatek-sunrise-hackintosh` (MT7922 Sunrise Pack, berisi firmware/kext HAL/penyamaran device-id tanpa kompilasi)** · **status firmware 26.7.1 per chip** · **`AppleSunrise.kext` = HAL mode kernel (wajib)** · **tabel interpretasi log / tabel boot-args** · ★★ **Wi-Fi pihak ketiga memakai fork `flxxxxddd/SimpleMtkWlan` (ada release, 802.11n/ac bisa dipakai)** · **tiga batasan keras** · **jebakan kartu tersembunyi oleh SSDT** · pemecahan masalah `mtklog.sh` · pohon keputusan tiga jalur, pengenalan chip, dua jebakan NVRAM Bluetooth pihak ketiga |
| `broadcom-wifi.md` | Kartu Broadcom: **jalur terpisah untuk Sequoia / Tahoe**, OCLP root patch, kriteria verifikasi |
| `network-en0-order.md` | **Kepemilikan `en0` dan urutan antarmuka jaringan**: siapa yang bergantung pada `en0`, **setelah memperbaiki Wi-Fi wajib memastikan nirkabel adalah `en0`**, cara mengunci, dampak berantai. ★ **AirDrop / Handoff tidak bergantung pada `en0`** |
| `airdrop-handoff.md` | **AirDrop / Handoff / Continuity**: ★★★ **akar penyebab hanya pada `awdl0` (= nirkabel menjalankan stack `IO80211Family` native Broadcom)** · **`itlwm.kext` pasti tidak bisa dipakai (kutipan FAQ resmi)** · **empat kesalahan penilaian (`ROM` / `en0` / `SystemUUID` / nomor seri)** · **urutan 8 langkah pemecahan masalah** · prinsip pemilihan kartu · contoh pembuktian di mesin ini |
| `ethernet-drivers.md` | **Driver pihak ketiga untuk kabel jaringan**: Intel I225/I226 · I210/I211/I350 · perbandingan solusi dan kriteria untuk Realtek RTL8125/8126 |
| `ecosystem-sources.md` | ★★ **Indeks sumber otoritatif ekosistem Hackintosh**: resmi Acidanthera / Dortania · **toolchain corpnewt** (ProperTree / GenSMBIOS / SSDTTime / USBMap) · `USBToolBox` · `blacktop/ipsw-diffs` · penulis driver · sumber daya berbahasa Mandarin · ★ **tabel "untuk hal apa, percaya siapa"** |
| `laobamac-toolkit.md` | **Indeks alat dan patch laobamac (tabel lengkap 48 repo)**: driver · pemasangan · ★ **hardware tanpa jebakan (`SimpleBuyersGuide`)** · alat pemeliharaan (`SimpleLoader`) · launchpad macOS 26 · patch referensi (`OC-little-zh`) · AMD · penjelasan fork · ★ **mana yang sudah diarsipkan** |
| `applealc-custom.md` | Sound card onboard (AppleALC): ★★★ **pemulihan `AppleHDA` di macOS 26 (panduan `perez987`: perbandingan solusi USB sound card / **KDK + `MyKextInstaller`** / OCLP / VoodooHDA + syarat dan verifikasi; jebakan versi KDK + lokasi instalasi + validasi sha)** · ★★ **kustomisasi lewat `5T33Z0/AppleALC-Guides`** (alur 14 bab · 17 dump siap pakai · **`alc-verb` untuk menyetel audio saat runtime** · tabel `MuteGPIO` · **diperkecil ke 90 KB** · alur rollback) · ★★★ **batasan keras kustomisasi: data dari sisi Windows** (kalau pengguna bisa menyediakan, langsung masuk alur; **jalur HDAU GUI atau skrip `HDAudDev.dll`**, setelah dump buktikan pemetaan jack lewat endpoint Windows) · **tiga akar penyebab AppleHDA hasil pengukuran** · **verifikasi bukan dengan telinga** (sampel register saat pemutaran) · cara membaca field Pin Config Default (spesifikasi Intel HDA) · cari pengalaman orang lebih dulu, kustomisasi per codec, build lokal, uji, ajukan PR |
| `hidpi.md` | Mengaktifkan HiDPI di layar non-Retina: lokasi penulisan, dua mode, jalur pemulihan, risiko dengan driver NVIDIA |
| `intel-turbo.md` | Turbo / limit frekuensi Intel: ★★★ **metode terbaik yang final (injeks "profile mesin ini sendiri dengan `hwp` dihapus" — empat kriteria)** · **lokasi asli `hwp` dan cara menghapusnya** · **tabel pemilihan dari 76 profile dalam lima keluarga** · verifikasi CPU-S · **wajib restart setelah diubah** · perbaikan lewat CPUFriend · prasyarat keras BIOS |
| `e-cores.md` | **Aktifkan / nonaktifkan E-core (P/E core pada arsitektur hybrid Intel)**: ★ dua pilihan trade-off · BIOS `Active Efficient Cores` (nama pada empat vendor) · `ProvideCurrentCpuInfo` · **empat nilai `CpuTopologyRebuild`** (`ctrsmt=off` / `ctrsmt=full` / `-ctrfixcnt`) · kriteria `hw.nperflevels` · **konflik `-v` yang sudah diketahui resmi** · rollback |
| `cpu-name.md` | **Nama tampilan CPU (mengubah nama)**: ★ murni tampilan · tiga setelan RestrictEvents (`revpatch=cpuname` / `revcpu=1` / `revcpuname`) · ★★ **NVRAM berprioritas lebih rendah daripada boot-args** · `revcpuname` hanya boleh di NVRAM · `ProcessorType` dipasangkan dengan jumlah core · **dua jalan buntu `Cpuid1Data` / `AppleSystemInfo.strings`** · pemecahan masalah |
| `memory-injection.md` | Kustomisasi memori: ★★ **jumlah slot berbeda sesuai model** (`MacPro7,1`=12 / `iMac20,1`=4), **tabel pemetaan 12 slot MacPro**, **aturan penempatan f**, field umum lapisan A |
| `smbios-and-serials.md` | **Ganti model + tiga kode**: ★★★ **mengganti model harus mengganti tiga kode sekaligus** (nama model = fungsi dari kode produk nomor seri), **daftar 7 item terkait** (tiga kode · prasyarat SSDT · CPUFriend · jumlah slot memori · ROM · **nama komputer/nama host/nama SMB** · cache nama tampilan), ★★★ akar penyebab SSDT OEM motherboard (`xh_adls3`) dan ACPI, **aturan keras urutan (lengkapi SSDT dulu)**, checklist, kriteria nomor seri, ROM, tiga status skrip pergantian, pelajaran dari pengalaman |
| `theme-opencanopy.md` | **Tema pemilih (OpenCanopy)**: tabel tombol, direktori sumber daya, **daftar ikon (wajib/opsional/tidak disediakan resmi)**, aturan Flavour, label/font/audio/latar belakang, pemecahan masalah |
| `pitfalls.md` | Semua jebakan yang pernah ditemukan |
| `machine-facts.md` | Fakta spesifik dari mesin referensi (Z690 / Alder Lake / macOS 26) |

---

## Kesesuaian dan Batasan

- **Alur bersifat umum**: dokumen, validator, contoh, dan sumber daya semuanya berasal dari paket rilis resmi / repo resmi, berlaku untuk mesin OpenCore mana pun.
- **Fakta mesin referensi diisolasi**: yang tercatat di `opencore-config-audit/references/machine-facts.md` adalah fakta dari **satu mesin tertentu**
  (Z690 / Alder Lake / RTX 3080 / macOS 26). Saat berganti mesin, cukup verifikasi ulang mengikuti **tahap 0** di `SKILL.md`,
  jangan memperlakukan fakta itu sebagai konfigurasi umum.
- **Alat pihak ketiga bukan otoritas**: hasil yang dihasilkan alat seperti RapidEFI cocok dipakai sebagai **titik awal**, dan tetap harus ditinjau ulang dengan dokumen resmi + `ocvalidate`.

## Penjelasan

Isi repo ini ditulis oleh penulis dan bebas digunakan untuk keperluan pribadi maupun penelitian.
