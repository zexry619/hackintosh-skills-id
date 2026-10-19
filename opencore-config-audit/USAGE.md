# opencore-config-audit —— Panduan penggunaan

> Referensi ringkas untuk **pengguna**. Detail teknisnya ada di `SKILL.md` dan `references/`, tidak perlu dipusingkan.

## Cara pakai

**Cukup nyatakan kebutuhannya dengan bahasa alami**, tanpa perlu mengingat nama skill maupun perintahnya. Sistem akan memilihnya sendiri.

Bisa juga ditentukan manual: ketik **`/`** di kolom input → pilih `opencore-config-audit`; atau klik **`+` → Skill** di pojok kiri bawah kolom input.

## Kalimat yang memicu skill ini

| Yang ingin kamu lakukan | Ucapkan begini |
|---|---|
| **Periksa BIOS** | "Audit pengaturan BIOS saya", "Saat instalasi sistem disk tidak ditemukan", "Apakah CFG Lock perlu dimatikan" |
| Audit konfigurasi | "Audit konfigurasi OpenCore saya", "Validasi config.plist" |
| Tambahkan SSDT | "Cek log, masih ada SSDT yang perlu ditambah?", "Bagaimana cara membuat hot patch ACPI", "Di mana contoh SSDT" |
| **Gagal instalasi / tidak bisa masuk sistem** | "Saat instalasi sistem disk tidak ditemukan", "Macet di logo Apple tidak bisa masuk", "Boot loop restart", "Layar hitam hanya kursor", "Setelah instalasi, boot pertama tidak bisa masuk" |
| Periksa boot lambat | "Boot sangat lambat, analisis timeline-nya", "Macet di logo Apple" |
| **Entri boot hilang** | "OpenCore tidak terlihat di BIOS", "Hanya tersisa Windows", "Entri boot hilang setelah boot dari U disk", "Bagaimana cara menambah entri boot dengan bcfg" |
| **Ganti media boot** | "Ubah boot dari U disk menjadi boot dari disk", "Bagaimana cara menambah entri boot di macOS", "Entri boot di posisi pertama" |
| Rampingkan | "Rampingkan kext, hapus yang tidak dipakai", "Blokir disk yang lain" |
| **Perbarui kext / OC** | "Perbarui semua kext ke versi terbaru", "Apakah OpenCore perlu di-upgrade", "Apakah kext ini yang resmi" |
| Pasang driver | "Pasang driver NVIDIA", "Bagaimana konfigurasi Wi-Fi Intel", "Apakah MT7922 saya bisa dipakai", "Apakah MT7921 bisa terhubung ke internet", "Bagaimana cara memasang MT7922 Reno/RZ616", "Apa yang perlu dipasang untuk Sunrise native", "Bagaimana konfigurasi kartu Broadcom", "Bagaimana cara mendriver Ethernet/2.5G" |
| **AirDrop / Handoff** | "AirDrop tidak menemukan perangkat", "AirDrop tidak bisa dipakai", "Handoff tidak berfungsi", "Handoff tidak bereaksi", "Apakah ROM diisi dengan benar", "`awdl0` tidak ada" |
| Atur CPU | "Frekuensi CPU tertahan", "Bagaimana cara mengaktifkan turbo boost", "Setelah ganti data CPUFriend malah jadi lebih lambat", "Setelah ubah turbo boost tidak ada efek" |
| **Nama CPU salah** | "Tentang Mac ini menampilkan Xeon W padahal punya i7", "Bagaimana cara mengubah nama processor", "Model CPU yang ditampilkan salah" |
| **App tidak mendapat izin** | "Mikrofon tidak diizinkan", "Jendela izin tidak muncul", "Tidak ada sakelar aplikasi ini di pengaturan privasi", "Aplikasi suara tidak bisa dipakai setelah memasang driver GPU" |
| **App tidak bisa dibuka / sumber apa saja** | "Tidak bisa memverifikasi developer", "Sudah rusak, harus dipindahkan ke Sampah", "Bagaimana cara mengaktifkan sumber apa saja", "Tidak bisa memasang dari sumber tak dikenal", "Bagaimana cara mematikan `spctl`" |
| **Aktif/nonaktifkan E core** | "Bagaimana cara mengaktifkan E core", "Matikan E core", "CPU jelas 12 core tapi hanya terlihat 8 core", "E core tidak terpakai" |
| **Ganti model / tiga kode** | "Ganti model SMBIOS", "Bagaimana konfigurasi tiga kode", "Bagaimana cara membuat serial number", "Isi ROM dengan apa", "Ganti model lalu tidak bisa boot" |
| Upgrade sistem | "Dari 15 ke 26 apa yang perlu diubah", "Setelah upgrade Wi-Fi hilang", "Setelah upgrade onboard sound card tidak ada suara" |
| **Kartu suara** | "Onboard sound card tidak ada suara", "Hanya HDMI yang bersuara", "Bagaimana cara memasang AppleHDA kembali", "Berapa nilai layout-id", "Buat layout-id sendiri", "Bagaimana cara mengambil codec dump", "Mikrofon depan tidak ada suara", "Tidak beralih output saat headset dipasang", "Port mana untuk apa" |
| Ganti build | "Ganti OpenCore release ke versi debug dan nyalakan log" |
| **Ganti tema** | "Ganti tema OpenCore", "Bagaimana cara memasang icon set", "Tampilan selector tidak muncul", "Ikon tampil salah/berubah bentuk", "Tidak ada suara saat boot", "Bagaimana konfigurasi PickerAttributes" |
| Instalasi pertama | "Pertama kali pasang Hackintosh, bagaimana cara membuat EFI" |

## Yang kamu dapatkan

- **Laporan audit**: setiap kesimpulan mengacu pada dokumentasi resmi / validator resmi, bukan "pengalaman" belaka
- **Perubahan yang bisa dikembalikan**: cadangan sebelum mengubah, hitung sha setelah mengubah, unload lalu mount ulang untuk verifikasi — kalau ada masalah bisa dikembalikan
- **Checklist yang sudah tervalidasi**: SSDT mana yang perlu ditambah, kext mana yang perlu dihapus, disertai alasan untuk tiap butir
- **Dokumen analisis**: durasi boot, pengumpulan bukti dari log, dan sejenisnya ditulis ke file

## Skrip pendukung (18 buah)

| Skrip | Fungsi |
|---|---|
| `oc-nvram-bootentry.sh` | **Baca/tulis entri boot firmware dari sistem** (`dump` / `backup` / `restore` / `add` / `del`) ★ operasi tulis butuh hak admin, dan memerlukan `RequestBootVarRouting=false` |
| `bios-audit.ps1` | **Audit BIOS sisi Windows (hanya baca)** —— jalankan ini lebih dulu di Windows |
| `fetch-opencore-docs.sh` | Ambil paket resmi versi yang sama + bangun pustaka kunci konfigurasi |
| `oc-verify.sh` | Validasi sekali klik (`plutil` + `ocvalidate` + integritas referensi + sha) |
| `oc-swap-build.sh` | Ganti build RELEASE ↔ DEBUG |
| `oc-edit-safe.sh` | Ubah config dengan aman (cadangan / validasi / arsip / mount ulang + verifikasi) |
| `grab-logs.sh` | Ambil log boot dan log kernel |
| `boot-timeline.sh` | Ringkasan durasi boot |
| `find-boot-gap.sh` | Pemeriksaan detail jeda saat boot |
| `mask-other-disks.sh` | Blokir volume non-sistem berdasarkan UUID |
| `cpu-freq-probe.sh` | Probe frekuensi CPU aktual |
| `e-cores-check.sh` | **Pemeriksaan E core** (topologi / frekuensi / pemuatan `CpuTopologyRebuild` + interpretasi) |
| `kext-inventory.sh` | **Pemeriksaan inventaris kext** (versi / `DTXcode` / sha256 / pencocokan referensi config / versi inti OC) |
| `cpu-name-check.sh` | **Pemeriksaan nama tampilan CPU** (perbandingan nama / parameter `rev*` / `RestrictEvents` / `ProcessorType`) |
| `mem-check.sh` | Validasi penempatan injeksi memori |
| `redact-check.sh` | **Pemeriksaan sanitasi sebelum publikasi** (pindai tiga kode / MAC / kunci, dll.) |
| `oc-theme-check.sh` | **Pemeriksaan kepatuhan pohon Resources** (ikon wajib / ukuran piksel asli / label / font / audio) |
| `oc-fetch-iconset.sh` | Ambil icon set / font / label / audio dari OcBinaryData resmi |

## Dokumen referensi (32 buah)

Pilih sesuai tema: `bios-settings.md` (BIOS) · `lifecycle.md` (alur lengkap) · `os-upgrade-15-to-26.md` (upgrade sistem) ·
`nvidia-driver.md` · `amfi-and-tcc.md` (**App tidak mendapat izin → tcc-helper**) · `intel-wifi.md` · `mediatek-wifi.md` (**memuat skema paket Sunrise native**) · `broadcom-wifi.md` (empat jenis kartu Wi-Fi/GPU) · `airdrop-handoff.md` (**AirDrop / Handoff: hanya melihat `awdl0`, tidak terkait `ROM`/`en0`/UUID**) ·
`applealc-custom.md` (**kartu suara / memulihkan AppleHDA di macOS 26 / sebelum membuat layout kustom, ambil dulu data sisi Windows: skrip HDAU atau HDAudDev.dll**) · `hidpi.md` (tampilan) · `intel-turbo.md` (turbo boost) · `e-cores.md` (**aktif/nonaktifkan E core**) · `cpu-name.md` (**nama tampilan CPU**) · `memory-injection.md` (memori) · `boot-failure-debug.md` (**gagal instalasi / tidak bisa masuk sistem**) · `boot-timeline.md` / `logs-and-debug.md` (log) · `boot-entries.md` (entri boot) ·
`acpi-ssdt.md` (**indeks pustaka contoh hot patch ACPI**) · `disks-and-kexts.md` · `kext-and-oc-update.md` (**perbarui kext / OC**) · `official-docs-method.md` · `rapidefi-first-efi.md` ·
`smbios-and-serials.md` (ganti model + tiga kode) · `network-en0-order.md` (kepemilikan `en0`) · `ethernet-drivers.md` (kartu Ethernet) · `ecosystem-sources.md` (**indeks sumber otoritatif dan alat**) · `laobamac-toolkit.md` (indeks alat) · `pitfalls.md` (jebakan yang pernah dialami) · `theme-opencanopy.md` (tema selector) · `machine-facts.md` (fakta mesin referensi)

## Perhatian

- Skill ini akan **mengubah EFI kamu**. Semua perubahan lewat alur aman (cadangan → validasi → verifikasi ulang), tapi **simpan sendiri satu salinan cadangan EFI**.
- Perubahan yang menyentuh batas keamanan (melonggarkan SIP, `SecureBootModel=Disabled`, parameter AMFI) akan ditulis secara eksplisit di dalam laporan.
- Hal-hal seperti apakah `-v` perlu dinyalakan dan tema selector adalah **preferensi yang bisa kamu lihat sendiri**, jadi skill akan bertanya lebih dulu, tidak memutuskan untukmu.
