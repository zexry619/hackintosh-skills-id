# BIOS / UEFI pengaturan audit

> ★ **Satu langkah lebih awal**: **sebelum merakit / mengganti komponen**, lihat dulu `laobamac/SimpleBuyersGuide` "Panduan Hardware untuk Hindari Jebakan Hackintosh"
> —— daftar lengkap komponen **yang tidak boleh dibeli**: CPU / GPU / chipset motherboard / SSD / kartu jaringan / kartu nirkabel, dll. Indeks ada di `laobamac-toolkit.md` §3.

> **Tiga sumber, dari prioritas tertinggi ke terendah:**
> 1. **Dokumentasi resmi OpenCore** (checklist troubleshooting di `Docs/Configuration.pdf`) — otoritatif, hanya mencantumkan item yang **menghambat boot**
> 2. **Dortania OpenCore Install Guide** (de facto standar komunitas) — menuliskan yang tidak ditulis dokumen resmi, dipisahkan Intel / AMD
> 3. **Tambahan dari pengalaman lapangan komunitas** (VMD, Speed Shift, dll.) — **sama sekali tidak disebut** dokumen resmi, tapi kalau kena, sistem tidak bisa diinstal
>
> ⚠️ Ketiganya tidak lengkap, **harus dibaca digabung**. Bagian 3 dokumen ini menggabungkannya menjadi tiga kategori: "wajib dimatikan / wajib diaktifkan / tergantung kondisi".

---

## 0. Awalnya: cara melakukan audit BIOS

**Jangan** langsung membalik-balik semua opsi BIOS (ratusan, dan tiap vendor memakai nama berbeda). Ikuti urutan ini:

1. **Jalankan dulu skrip audit di Windows** (`scripts/bios-audit.ps1`) — skrip ini bisa **memastikan secara langsung** sekumpulan item di dalam Windows,
   ambil dulu yang "pasti bermasalah", sisanya baru perlu diperiksa manual di BIOS
2. **Masuk BIOS dan periksa dua kategori "wajib dimatikan/wajib diaktifkan"** (§3) — centang satu per satu memakai checklist di §7
3. Kalau **suatu item tidak ditemukan di BIOS**, lihat tabel pemetaan nama vendor di §8 (setiap vendor punya nama berbeda untuk pengaturan yang sama)
4. Kalau **tidak ditemukan padahal memang dibutuhkan** → gunakan jalur opsi tersembunyi di §5 (UEFITool + IFR-Extractor),
   atau lewati lewat kolom "OpenCore sebagai cadangan" di tabel §3

> ★ **Prioritas kriteria**: **apa pun yang bisa diselesaikan di level BIOS, selesaikan di level BIOS**, jangan pakai quirk OpenCore sebagai cadangan.
> Kutipan resmi (tentang CFG Lock): *"this option should be avoided whenever possible"* (merujuk `AppleXcpmCfgLock`).

---

## 1. Checklist resmi (teks asli OpenCorePkg `Configuration.pdf`)

Secara resmi, ini diletakkan di checklist troubleshooting, **9 item**:

| # | Poin utama teks resmi | Arah |
|---|---|---|
| 1 | Most up-to-date UEFI firmware | **Upgrade firmware** |
| 2 | `Fast Boot` and `Hardware Fast Boot` disabled | **Matikan** |
| 3 | `Above 4G Decoding` or similar enabled —— ★ tapi di **ASUS WS-X299-PRO** opsi ini **berdampak buruk, wajib dimatikan**; motherboard lain tidak menunjukkan masalah ini, saat muncul "kegagalan boot yang tidak masuk akal" maka **periksa ini pertama** | **Aktifkan** (kecuali: matikan) |
| 4 | `DisableIoMapper` quirk enabled, **or** `VT-d` disabled in firmware, **or** ACPI DMAR deleted (pilih salah satu) | **Matikan** (atau pakai quirk sebagai cadangan) |
| 5 | No `slide` boot argument present | **Jangan tambahkan** |
| 6 | `CFG Lock` (MSR `0xE2` write protection) disabled —— lihat detail di `ControlMsrE2` | **Matikan** |
| 7 | `CSM` (Compatibility Support Module) disabled —— NVIDIA 6xx / AMD 2xx dan yang lebih tua perlu flash GOP ROM dulu | **Matikan** |
| 8 | `EHCI/XHCI Hand-off` enabled —— **hanya perlu** jika boot macet saat perangkat USB dicabut | **Aktifkan** (bersyarat) |
| 9 | `VT-x`, `Hyper Threading`, `Execute Disable Bit` enabled | **Aktifkan** |
| Lampiran | Kadang `Thunderbolt`, `Intel SGX`, `Intel Platform Trust` mungkin perlu dinonaktifkan | **Matikan** (sesuai kebutuhan) |

> Secara resmi juga disebutkan: saat menelusuri masalah **sleep**, Power Nap dan auto-power-off bisa dimatikan sementara (`pmset` tiga paket),
> tapi itu di sisi macOS, bukan BIOS.

---

## 2. Checklist Dortania (de facto standar komunitas, per platform)

### 2.1 Intel (desktop / laptop / HEDT serbaguna)

> Catatan pendahuluan teks asli: *"Most of these options may not be present in your firmware, we recommend matching up as closely as possible but don't be too concerned if many of these options are not available in your BIOS"*

**Disable**

| Pengaturan | Catatan (teks asli Dortania) |
|---|---|
| Fast Boot | |
| Secure Boot | |
| Serial/COM Port | |
| Parallel Port | |
| VT-d | *"can be enabled if you set `DisableIoMapper` to YES"* |
| Compatibility Support Module (CSM) | ★ **"Must be off in most cases, GPU errors/stalls like `gIO` are common when this option is enabled"** |
| Thunderbolt | Saat instalasi (TB bermasalah bila belum dikonfigurasi benar) |
| Intel SGX | |
| Intel Platform Trust | |
| **CFG Lock (MSR 0xE2 write protection)** | ★★ **"This must be off, if you can't find the option then enable `AppleXcpmCfgLock` under Kernel → Quirks. Your hack will not boot with CFG-Lock enabled"** |

**Enable**

| Pengaturan | Catatan |
|---|---|
| VT-x | |
| **Above 4G Decoding** | ★ *"2020+ BIOS Notes: When enabling Above4G, Resizable BAR Support may become available on some Z490 and newer motherboards. Please ensure that `Booter → Quirks → ResizeAppleGpuBars` is set to `0` if this is enabled."* |
| Hyper-Threading | |
| Execute Disable Bit | |
| EHCI/XHCI Hand-off | |
| OS type: **Windows 8.1/10 UEFI Mode** (sebagian motherboard harus memilih **Other OS**) | |
| DVMT Pre-Allocated (iGPU Memory): **64MB atau lebih** | Saat ada iGPU |
| SATA Mode: **AHCI** | |

### 2.2 AMD (Zen)

**Disable**: Fast Boot, Secure Boot, Serial/COM Port, Parallel Port, **CSM**, **IOMMU**
> ★ Khusus: **3990X** punya 128 thread, kernel macOS hanya mendukung 64 ⇒ **wajib mematikan hyper-threading** (Dortania secara eksplisit menyarankan).

**Enable**:
- **Above 4G Decoding** —— ★ **"This must be on, if you can't find the option then add `npci=0x3000` to boot-args. Do not have both this option and npci enabled at the same time."**
  - ★ **Motherboard Gigabyte/Aorus atau ASRock**: mengaktifkannya bisa **merusak sebagian driver (misalnya kartu jaringan)** atau membuat **sistem lain gagal boot** ⇒ matikan saja dan pakai `npci`
  - Catatan 2020+ sama dengan Intel (setelah ReBAR muncul, `ResizeAppleGpuBars=0`)
- EHCI/XHCI Hand-off
- OS type: Windows 8.1/10 UEFI Mode (atau Other OS)
- SATA Mode: AHCI

---

## 3. ★★ Tiga daftar gabungan (**tabel ini adalah inti**)

### 3.1 Wajib dimatikan

| Pengaturan | Mengapa wajib dimatikan | Akibat jika tidak dimatikan | OpenCore sebagai cadangan |
|---|---|---|---|
| **Fast Boot / Ultra Fast Boot / MSI Fast Boot** | Melewati inisialisasi perangkat | **Tidak bisa masuk ke picker**, keyboard/mouse USB tidak merespons | ❌ Tidak ada |
| **Secure Boot** | macOS tidak menerima tanda tangan non-Apple | Kext pihak ketiga gagal dimuat | ⚠️ Sebagian bergantung pada `SecureBootModel=Disabled`, tapi tetap disarankan dimatikan di sisi BIOS |
| **CSM (Compatibility Support Module)** | Memasukkan legacy option ROM, GOP tidak berjalan | **GPU error / macet di `gIO` / resolusi tidak normal** | ❌ Tidak ada |
| **CFG Lock (MSR 0xE2 write protection)** | Native power management macOS harus menulis MSR `0xE2` | ★★ **"Your hack will not boot"** (teks asli Dortania) | ⚠️ `Kernel → Quirks → AppleXcpmCfgLock = true` (**resmi menyatakan sebisa mungkin jangan dipakai**) |
| **★ Intel VMD / Volume Management Device** | **macOS tidak punya driver VMD** | ★★ **Saat instalasi "tidak menemukan disk/drive apa pun"**; sistem yang sudah terpasang tidak melihat disk | ❌ Tidak ada (**resmi maupun Dortania tidak menyebut, murni pengalaman komunitas**) |
| **Intel RST / SATA RAID Mode** | macOS hanya mengenali AHCI / NVMe native, tidak(fake) RAID RST | Tidak melihat disk | ❌ Tidak ada |
| **Serial / COM Port** | Mengambil I/O, platform lama bisa konflik | Sedikit kasus macet saat boot | ❌ Tidak ada |
| **Parallel Port** | Sama seperti di atas | | ❌ Tidak ada |
| **Intel SGX** | macOS tidak punya driver | Umumnya tidak berbahaya, resmi tetap menyarankan dimatikan | ❌ Tidak ada |
| **Intel Platform Trust / PTT / fTPM** | macOS tidak butuh TPM | Umumnya tidak berbahaya | ❌ Tidak ada |
| **VT-d / IOMMU** (**boleh diaktifkan, tapi tahu konsekuensinya**) | Berkonflik dengan IOMapper XNU | Kartu jaringan/nirkabel berulang `link up/link down`, jaringan tidak terdeteksi | ✅ ★ **Pilihan resmi adalah mengaktifkan `DisableIoMapper=true`** (*"a preferred alternative to … disabling VT-d in firmware preferences, which does not obstruct VT-d support in other systems"*) |
| **Thunderbolt** (**hanya saat instalasi**) | Bisa bermasalah bila belum dikonfigurasi | Abnormal saat instalasi | — Nyalakan sesuai kebutuhan setelah terpasang |
| **ErP / EuP Ready** | Memotong daya siaga setelah shutdown | Mematikan daya tidak terputus, USB wake tidak normal (**tergantung kondisi**, bukan wajib) | ❌ Tidak ada |
| **Wake on LAN / bangun via jaringan** | Tidur terbangun oleh peristiwa jaringan | Sleep tidak stabil | ❌ Tidak ada |
| **Network Stack / PXE Boot** | Jaringan harus diinisialisasi pada tahap POST | Boot jadi lebih lambat | ❌ Tidak ada |

### 3.2 Wajib diaktifkan

| Pengaturan | Mengapa wajib diaktifkan | Akibat jika tidak diaktifkan | Catatan |
|---|---|---|---|
| **VT-x** (Intel) / **SVM Mode** (AMD) | Virtualisasi | Docker/VM tidak bisa dipakai | |
| **Above 4G Decoding** | Membuat BAR besar bisa dipetakan di atas 4G | Driver GPU dengan BAR besar tidak bisa berjalan | ★ pengecualian yang disebut resmi: **ASUS WS-X299-PRO wajib dimatikan** |
| **Hyper-Threading** | Performa | Jumlah thread berkurang separuh | ★ pengecualian: **3990X wajib dimatikan** (kernel macOS dibatasi 64 thread) |
| **Execute Disable Bit** (XD / NX) | Diperlukan macOS | Mungkin tidak bisa boot | |
| **EHCI/XHCI Hand-off** | Kendali USB diserahkan ke OS | Keyboard/mouse USB dan media instalasi tidak merespons saat instalasi | Resmi: **hanya perlu jika boot macet saat perangkat USB tidak dicabut** |
| **OS Type = Windows 8.1/10 UEFI Mode** (atau **Other OS**) | Membuat firmware melakukan inisialisasi dengan cara UEFI | Mungkin mundur ke jalur legacy | Sebagian motherboard wajib memilih "Other OS" |
| **SATA Mode = AHCI** | macOS hanya mengenali AHCI | Tidak melihat disk SATA | |
| **DVMT Pre-Allocated ≥ 64MB** | Memberi iGPU memori yang cukup | Artefak iGPU / layar hitam | **Hanya perlu saat ada iGPU** |
| **★ Intel Speed Shift Technology** | macOS memakai scheduling HWP | ★★ **`wrmsr(0x770,1)` #GP panic** (prasyarat keras hasil uji di mesin ini) | **Resmi maupun Dortania tidak menyebut**, pengalaman komunitas |
| **Resizable BAR / Re-Size BAR Support** | Diperlukan untuk jalur driver BAR besar | Driver BAR besar tidak mendapatkan BAR | **Tergantung kondisi**, lihat §3.3 |

### 3.3 Tergantung kondisi (Conditional) —— **tidak perlu semuanya dimatikan/diaktifkan**

| Pengaturan | Kapan diaktifkan | Kapan dimatikan |
|---|---|---|
| **Re-Size BAR Support** | Driver/kartu Anda butuh BAR besar (driver NVIDIA di mesin ini begitu), dan `ResizeGpuBars` sudah dikonfigurasi | Saat versi driver atau kartu tidak mendukung BAR besar; saat muncul layar hitam/tidak bisa boot, coba matikan dulu |
| **XMP / DOCP / EXPO** | Profil overclock memori, **kalau stabil biarkan aktif** | Saat muncul ketidakstabilan terkait memori atau sleep tidak normal, matikan dan kembali ke JEDEC |
| **Internal Graphics / iGPU** | iGPU punya driver dan mau dipakai (misalnya `WhateverGreen` + hard decode iGPU) | iGPU tanpa driver ⇒ **mematikannya lebih bersih** (atau biarkan aktif tapi sembunyikan dengan `-wegnoigpu`) |
| **Thunderbolt** | Setelah sistem terpasang dan perangkat TB dikonfigurasi | Saat instalasi (lihat §3.1) |
| **Legacy USB Support** | **Selama instalasi** (U disk / keyboard/mouse USB) | Setelah terpasang boleh dimatikan, menghemat sedikit waktu POST |
| **Above 4G Decoding** | Hampir semua motherboard | **ASUS WS-X299-PRO** (resmi menyebutnya); pada Gigabyte/Aorus/ASRock AMD, jika driver rusak ⇒ matikan dan ganti `npci=0x3000` |
| **CSM** | Hanya saat "NVIDIA 6xx / AMD 2xx dan yang lebih tua, serta GOP ROM belum di-flash" | **Semua kondisi lain dimatikan** (jawaban defaultnya adalah dimatikan) |
| **Global C-state Control** (AMD) | Umumnya aktif | Saat standby tidak stabil, coba matikan |
| **Power Supply Idle Control** (AMD) | Umumnya `Auto` | Beberapa Ryzen restart saat standby ⇒ coba `Typical Current Idle` |
| **★ Jumlah E core (Efficient Core)** (Intel gen 12+) | **Ingin macOS memakai 4 core kecil** ⇒ `All` (**wajib** sekaligus `ProvideCurrentCpuInfo=true` + `CpuTopologyRebuild.kext`) | **Ingin aman** ⇒ set **`0`** (matikan core kecil, macOS hanya melihat P core) ⇒ lihat detail di `e-cores.md`. ★ Baik dinyalakan maupun dimatikan, **`Active Performance Cores` biarkan `All`, HT biarkan `Enabled`** |
| **Multi-Monitor / Primary Display** | Bergantung pada GPU mana yang dipakai untuk output | — |
| **DMA Protection / Kernel DMA Protection** | Dibutuhkan Win11 | Tidak terkait macOS, tapi **bisa mengganggu** driver pihak ketiga, kalau ada masalah coba matikan dulu |

---

## 4. Item yang **tidak ditulis** resmi maupun Dortania, tapi sebenarnya sangat penting

| Item | Mengapa penting | Cara tahu apakah perlu diubah |
|---|---|---|
| **★ VMD (Intel Volume Management Device)** | Mulai Intel gen 11 banyak motherboard **aktif secara default**. Ini memasang NVMe di belakang pengendali virtual, **macOS tidak punya driver yang sesuai** ⇒ saat instalasi "tidak menemukan drive", di dalam sistem tidak melihat disk | Cari `VMD` / `Volume Management Device` / `VMD Setup Menu` di BIOS; di sisi Windows lihat pemeriksaan storage controller di skrip §6 |
| **★ Intel Speed Shift Technology** | macOS membutuhkan ini untuk memakai HWP. **Mematikannya memicu `wrmsr(0x770,1)` #GP panic** (teruji di mesin ini) | Cari `Speed Shift` di BIOS; di sisi Windows lihat `CPUID.06H:EAX` bit6–11 (perlu alat) |
| **Kombinasi Re-Size BAR + Above 4G** | ReBAR bergantung pada Above 4G. Hanya menyalakan ReBAR tanpa Above 4G menimbulkan masalah aneh | Periksa keduanya sekaligus; konfigurasi `ResizeGpuBars` / `ResizeAppleGpuBars` |
| **XMP dan kestabilan memori** | Profil XMP belum tentu stabil di macOS (terutama 4 slot terisi penuh) | Bandingkan `Speed` vs `ConfiguredClockSpeed` di Windows (skrip §6) |
| **ErP / EuP** | Perilaku shutdown, daya USB | Ubah hanya bila Anda peduli pada perilaku shutdown/wake |
| **TPM / PTT / fTPM** | Tidak dipakai macOS; sebagian motherboard dengan PTT aktif menambah perangkat | Di Windows, `Get-Tpm` untuk melihat `TpmPresent` (skrip §6) |
| **Versi firmware** | Item pertama checklist resmi adalah "gunakan UEFI terbaru" | Catat versi saat ini, bandingkan di situs resmi motherboard |

---

## 5. Topik CFG Lock (item yang paling detail di-expand secara resmi)

**CFG Lock = write protection pada MSR `PKG_CST_CONFIG_CONTROL (0xE2)`.** Jika aktif ⇒ native power management macOS tidak bisa menulis ke MSR ⇒ **tidak bisa boot**.

### 5.1 Tiga cara untuk memeriksanya

| Lingkungan | Cara | Kriteria |
|---|---|---|
| **Layar boot OpenCore** | OpenCore menyediakan **`ControlMsrE2.efi`** (di `EFI/OC/Tools/`, tekan spasi di picker untuk menampilkan tools). Bisa juga memakai `VerifyMsrE2` / `CFGLOCK` versi komunitas | Keluaran `MSR 0xE2 is LOCKED` / `This firmware has UNLOCKED MSR` |
| **macOS** | `sudo wrmsr 0xE2 0x0` (perlu `msr-tools`) | Muncul `cannot set MSR 0x000000e2` ⇒ **terkunci** |
| **Windows** | ⚠️ Pembacaan MSR butuh alat dengan hak istimewa (RWEverything / HWiNFO, dll.), **PowerShell tidak bisa membacanya** | Lihat bagian "tidak bisa dibaca langsung" di §6 |

> ★ Pengingat resmi: **sebagian firmware hanya mengunci register ini pada core tertentu** —— jadi hasil dari satu core saja bisa tidak akurat.

### 5.2 Tidak menemukan CFG Lock di BIOS? Gunakan opsi tersembunyi (metode dari resmi)

Berlaku untuk firmware **APTIO** (AMI):

1. Unduh **UEFITool** (`LongSoft/UEFITool`) dan **IFR-Extractor** (`LongSoft/Universal-IFR-Extractor`)
2. Buka citra firmware dengan UEFITool, cari string unicode **`CFG Lock`**.
   **Tidak ditemukan ⇒ firmware ini mungkin tidak punya opsi tersebut, proses berhenti di sini**
3. Pakai **Extract Body** milik UEFITool untuk mengekspor `Setup.bin` tempat ia berada (PE32 Image Section)
4. Jalankan IFR-Extractor pada file hasil ekspor: `./ifrextract Setup.bin Setup.txt`
5. Cari di dalam `Setup.txt` **`CFG Lock, VarStoreInfo (VarOffset/VarName)`** — dapatkan **VarStore GUID** dan **offset**
6. Ubah UEFI variable tersebut langsung memakai GUID + offset itu (atau tulis lewat `NVRAM > Add` di OpenCore), lalu restart untuk verifikasi

### 5.3 Cadangan (tidak disarankan, tapi bisa dipakai)

`Kernel → Quirks → AppleXcpmCfgLock = true` (sistem baru) / `AppleCpuPmCfgLock = true` (sistem lama, `AppleIntelCPUPowerManagement` sudah dihapus sejak macOS 13).

> Kutipan resmi: *"As modern firmware provide a CFG Lock setting … this option should be avoided whenever possible."*
> Artinya **kalau bisa dimatikan di BIOS, matikan di BIOS, jangan pakai quirk**.

---

## 6. Alat audit di sisi Windows: `scripts/bios-audit.ps1`

**Mengapa perlu skrip**: di antarmuka BIOS ada ratusan opsi, nama tiap vendor juga berbeda, sehingga pemeriksaan manual gampang terlewat.
Skrip ini hanya **membaca** data di dalam Windows, langsung memastikan yang bisa dipastikan, dan menandai yang tidak bisa dipastikan agar Anda periksa sendiri di BIOS.

### 6.1 Cara menjalankannya

```powershell
# Buka PowerShell sebagai [Administrator] (sebagian item butuh elevasi), lalu:
powershell -ExecutionPolicy Bypass -File .\bios-audit.ps1

# Ingin sekaligus menyimpan laporan:
powershell -ExecutionPolicy Bypass -File .\bios-audit.ps1 -OutFile C:\bios-audit.txt
```

> Skrip menghasilkan output **murni ASCII** (menghindari masalah encoding PowerShell 5.1), di laporan berisi nama key bahasa Inggris + hasil penilaian, cukup dibandingkan dengan dokumen ini.

### 6.2 Apa yang **bisa** dipastikan (kelas A)

| Item pemeriksaan | Metode | Kriteria |
|---|---|---|
| Tipe firmware (UEFI / Legacy) | `$env:firmware_type` | Harus **UEFI** |
| Mode boot | `winload.efi` dari `bcdedit` | Harus `.efi` |
| Gaya partisi disk sistem | `Get-Disk.PartitionStyle` | **GPT** (sesuai UEFI) |
| **Secure Boot** | `Confirm-SecureBootUEFI` | Diharapkan **False** (= sudah dimatikan) |
| **TPM / PTT / fTPM** | `Get-Tpm.TpmPresent` | Diharapkan **False** (= sudah dimatikan di BIOS) |
| **VT-x / SVM** | `Win32_Processor.VirtualizationFirmwareEnabled` | Diharapkan **True** (jika Hyper-V aktif akan salah deteksi, skrip juga melaporkan `HypervisorPresent`) |
| **Hyper-threading** | `Cores` vs `LogicalProcessors` | Logical = 2× fisikal ⇒ HT sudah aktif |
| **XMP / DOCP** | `Speed` vs `ConfiguredClockSpeed` | Configured > default JEDEC ⇒ profil overclock aktif |
| **★ VMD / RST** | `Get-Disk.BusType` + nama device storage controller | Muncul tipe bus **`RAID`**, atau nama controller mengandung `VMD` / `Volume Management Device` / `RST` ⇒ **VMD aktif, wajib dimatikan** |
| Daftar storage controller | `Get-PnpDevice` + PCI hardware ID | Mendaftarkan semua SCSIAdapter/HDC, memudahkan identifikasi manual |
| Port Serial/COM | `Get-CimInstance Win32_SerialPort` | Ada port COM ⇒ port serial di BIOS mungkin belum dimatikan |
| Versi / tanggal BIOS / motherboard | `Win32_BIOS` / `Win32_BaseBoard` | Ambil ke situs resmi untuk perbandingan apakah terbaru |
| Modul memori dan slot | `Win32_PhysicalMemory` | Sekalian verifikasi slot yang dipakai injeksi memori (lihat `memory-injection.md`) |

### 6.3 Yang **hanya memberi petunjuk** dan perlu konfirmasi manual (kelas B)

| Item | Yang bisa diberikan skrip | Yang perlu dilihat lagi |
|---|---|---|
| Above 4G Decoding | Hardware ID PCI GPU + petunjuk resource memori besar yang dialokasikan | Pakai **GPU-Z** untuk melihat "Above 4G Decoding" / "Resizable BAR"; atau NVIDIA control panel → system information |
| Re-Size BAR | Sama seperti di atas | Sama seperti di atas; di mesin ini jadi acuan `nvrm-bars` / log driver |
| Execute Disable Bit | `DataExecutionPrevention_Available` | Bernilai True umumnya berarti XD aktif (inferensi, bukan pembacaan langsung) |
| CSM | Hanya bisa melihat "saat ini boot lewat UEFI atau tidak" | Status CSM **tidak bisa dibaca langsung dari Windows** ⇒ masuk BIOS |
| Fast Boot | Tidak ada | Masuk BIOS (Fast Boot / Ultra Fast Boot) |
| iGPU / DVMT | `Get-PnpDevice -Class Display` untuk melihat apakah iGPU ada | Nilai DVMT tidak terbaca ⇒ masuk BIOS |

### 6.4 Yang **tidak bisa dibaca**, wajib cari alat lain (kelas C)

| Item | Mengapa tidak bisa dibaca | Alat yang benar |
|---|---|---|
| **CFG Lock / MSR 0xE2** | Pembacaan MSR butuh hak istimewa mode kernel | **`ControlMsrE2.efi` OpenCore** (paling akurat) · di Windows pakai RWEverything · di macOS uji `wrmsr` |
| Tabel ACPI (DSDT / DMAR …) | Windows tidak mengekspos tabel ACPI ke user mode | RWEverything / `acpidump`; atau `SysReport` OpenCore (build DEBUG) |
| Nilai sebenarnya SATA Mode | Hanya terlihat hasilnya, bukan pengaturannya | Masuk BIOS |
| Opsi tersembunyi BIOS | Tidak ada di antarmuka | UEFITool + IFR-Extractor (§5.2) |

---

## 7. Checklist (centang satu per satu saat masuk BIOS)

```
[WAJIB DIMATIKAN]
[ ] Fast Boot / Ultra Fast Boot / MSI Fast Boot
[ ] Secure Boot
[ ] CSM (Compatibility Support Module)
[ ] CFG Lock (MSR 0xE2)
[ ] VMD / Intel Volume Management Device        ← ★ tidak ditulis resmi, tapi wajib dimatikan
[ ] Intel RST / SATA RAID Mode  → ubah ke AHCI
[ ] Serial / COM Port
[ ] Parallel Port
[ ] Intel SGX
[ ] Intel Platform Trust / PTT / fTPM
[ ] Network Stack / PXE (opsional, untuk lebih cepat)
[ ] Wake on LAN (opsional)
[ ] VT-d / IOMMU (★ boleh diubah menjadi aktif + pakai DisableIoMapper=true sebagai cadangan)

[WAJIB DIKANJANKAN]
[ ] VT-x (Intel) / SVM Mode (AMD)
[ ] Above 4G Decoding
[ ] Hyper-Threading (kecuali 3990X: matikan)
[ ] Execute Disable Bit (XD / NX)
[ ] EHCI/XHCI Hand-off
[ ] OS Type = Windows 8.1/10 UEFI Mode (atau Other OS)
[ ] SATA Mode = AHCI
[ ] DVMT Pre-Allocated ≥ 64MB (bila ada iGPU)
[ ] Intel Speed Shift Technology                ← ★ tidak ditulis resmi, tapi prasyarat keras di mesin ini
[ ] Resizable BAR (sesuai kebutuhan driver, konfigurasi ResizeGpuBars)

[TERGANTUNG KONDISI, JANGAN DIUBAH SEMUA]
[ ] XMP / DOCP          → aktifkan kalau stabil
[ ] Internal Graphics   → aktifkan hanya bila iGPU punya driver
[ ] Legacy USB Support  → aktifkan saat instalasi, setelah itu boleh dimatikan
[ ] Thunderbolt         → setelah terpasang, sesuai kebutuhan
[ ] ErP / EuP           → ubah hanya bila peduli shutdown/wake
[ ] Jumlah E core (gen 12+)  → aktif=All / mati=0 (lihat e-cores.md)
```

---

## 8. Pemetaan nama antar vendor (pengaturan sama, nama berbeda tiap vendor)

| Nama umum | ASUS | MSI | Gigabyte / AORUS | ASRock |
|---|---|---|---|---|
| CSM | `Boot → CSM (Compatibility Support Module)` | `Settings → Advanced → Windows OS Configuration → CSM` | `BIOS → CSM Support` | `Boot → CSM` |
| Secure Boot | `Boot → Secure Boot → OS Type = Other OS` | `Security → Secure Boot` | `BIOS → Secure Boot` | `Security → Secure Boot` |
| Fast Boot | `Boot → Fast Boot` | `Settings → Advanced → Boot → MSI Fast Boot` | `BIOS → Fast Boot` | `Boot → Fast Boot` |
| Above 4G | `Advanced → PCI Subsystem Settings → Above 4G Decoding` | `Settings → Advanced → PCI Subsystem Settings` | `Settings → IO Ports → Above 4G Decoding` | `Advanced → PCI Configuration → Above 4G Decoding` |
| Re-Size BAR | `Advanced → PCI Subsystem → Re-Size BAR Support` | `Settings → Advanced → PCI Subsystem → Re-Size BAR` | `Settings → IO Ports → Re-Size BAR Support` | `Advanced → PCI Configuration → Re-Size BAR` |
| CFG Lock | `Advanced → CPU Configuration → CPU Power Management → CFG Lock` | `OC → CPU Features → CFG Lock` | `Settings → Miscellaneous → CFG Lock` | `Advanced → CPU Configuration → CFG Lock` |
| VT-d / IOMMU | `Advanced → System Agent → VT-d` | `OC → CPU Features → VT-d` | `Settings → Miscellaneous → VT-d` | `Advanced → Chipset → VT-d` |
| VMD | `Advanced → VMD Setup Menu → Enable VMD controller = Disabled` | `Settings → Advanced → VMD Setup Menu` | `Settings → IO Ports → VMD Configuration` | `Advanced → VMD Configuration` |
| Speed Shift | `Advanced → CPU Configuration → Intel Speed Shift Technology` | `OC → CPU Features → Intel Speed Shift` | `Settings → Advanced CPU Settings` | `Advanced → CPU Configuration` |
| **Jumlah E core** (gen 12+) | `Advanced → CPU Configuration → Active Efficient Cores` | `OC → Advanced CPU Configuration → E-Core Count` | `Settings → Advanced CPU Settings → E-Core Count` | `Advanced → CPU Configuration → Active E Cores` |
| SATA Mode | `Advanced → SATA Configuration → SATA Mode = AHCI` | `Settings → Advanced → SATA Mode = AHCI` | `Settings → SATA Mode = AHCI` | `Advanced → Storage Configuration → SATA Mode = AHCI` |

> Nama menu tiap vendor berubah sesuai versi, **paling cepat pakai fitur "cari pengaturan"** (BIOS modern hampir semua punya kotak pencarian):
> Cari langsung `VMD` / `CFG` / `CSM` / `Above 4G` / `Speed Shift` / `Efficient Core`.

---

## 9. Hubungan BIOS ↔ quirk OpenCore

| Yang tidak bisa / tidak mau diubah di BIOS | Pasangan di sisi OpenCore | Penjelasan |
|---|---|---|
| VT-d tidak bisa dimatikan | `Booter → Quirks → DisableIoMapper = true` | ★ **Pilihan resmi** (tidak mengganggu VT-d di sistem lain) |
| CFG Lock tidak bisa dimatikan | `Kernel → Quirks → AppleXcpmCfgLock = true` | ⚠️ Resmi menyatakan sebisa mungkin dihindari |
| CSM tidak bisa dimatikan (kartu tua) | Tidak ada —— perlu flash GOP ROM dulu | |
| Above 4G dimatikan (ASUS WS-X299-PRO / sebagian papan AMD) | Tambahkan `npci=0x3000` ke boot-args | ★ **Keduanya tidak boleh aktif bersamaan** |
| ReBAR aktif tapi driver tidak mengenali | `Booter → ResizeAppleGpuBars` / `UEFI → ResizeGpuBars` | Lihat `nvidia-driver.md` |
| iGPU tidak punya driver | boot-args `-wegnoigpu` (atau matikan iGPU langsung di BIOS) | Terbukti di mesin ini menghemat ~60 s waktu boot |
| BIOS punya Fast Boot tapi tidak mau dimatikan | ❌ Tidak ada pengganti | Wajib dimatikan |

---

## 10. Hubungan dengan reference lain

- **Kegagalan boot / macet** → `logs-and-debug.md` (lihat log OC dulu); **waktu lama** → `boot-timeline.md`
- **BAR besar dan ReBAR pada NVIDIA** → `nvidia-driver.md`
- **iGPU** → lihat §3.3 dan `-wegnoigpu` di `boot-timeline.md`
- **Verifikasi modul memori dan slot** → `memory-injection.md` (skrip §6.2 sekaligus mengeluarkan slot)
- **Prosedur aman mengubah ESP** → aturan 1–16 di `SKILL.md` + `scripts/oc-edit-safe.sh`
