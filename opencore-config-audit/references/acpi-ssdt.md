# Inspeksi ACPI / SSDT

> ★★★ **Referensi utama pustaka contoh hot patch: `5T33Z0/OC-Little-Translated`** (<https://github.com/5T33Z0/OC-Little-Translated>,
> **★745** · BSD-3-Clause · **masih diperbarui**)—— berawal dari **terjemahan Inggris** karya Daliansky `OC-little`, tapi **jauh melampaui karya aslinya**:
> menambah bab 7–20 + **appendix lengkap A–Z**, menulis ulang bab ACPI / pemetaan port USB, dll.
> ★★ **Posisi yang dinyatakan penulis**: **ini bukan panduan instalasi**, melainkan **tuning dan aktivasi hardware setelah instalasi**;
> **hanya memakai hot patch ACPI, tanpa DSDT patch** (jalur hackintosh yang bersih)⇒ **kriterianya benar-benar seakar dengan dokumen ini, jadi aman dipakai sebagai pustaka contoh**.
> ★ **Catatan jujur**: terjemahan Inggris dibuat dengan tool AI + dikoreksi manual, **penterjemah tidak memahami bahasa Tionghoa** ⇒ terjemahan mungkin ada deviasi kecil; **kesimpulan penting tetap harus diverifikasi ke dokumen resmi**.
>
> ★ **Referensi bahasa Tionghoa**: `laobamac/OC-little-zh` (versi bahasa Tionghoa dari karya asli, indeksnya ada di `laobamac-toolkit.md`).
>
> ★ **Sebelum menulis SSDT, lihat-lihat dulu pustaka contoh**, lalu bandingkan dengan kriteria resmi `AcpiSamples` di dokumen ini untuk menilai "apakah perlu ditambah".

## 0. ★★ Bab mana yang perlu dibaca sesuai kebutuhan (termasuk **titik singgah untuk Z690 / Alder Lake / iMac20,1 di mesin ini**)

| Yang ingin kamu lakukan | Bab mana |
|---|---|
| Dasar ACPI · **menghapus tabel firmware** · **mengganti nama perangkat** · ACPI Patch di OC | `Content/00_ACPI/` (`ACPI_Basics` · **`ACPI_Dropping_Tables`** · **`ACPI_Rename_Devices`** · `ACPI_Patches_OpenCore` · `ACPI_Debugging`) |
| ★ **menggabungkan banyak SSDT menjadi satu tabel** | `Content/00_ACPI/SSDT-ALL` |
| Menambahkan perangkat yang hilang / mengaktifkan fitur | `Content/01_Adding_missing_Devices_and_enabling_Features/` |
| **Menonaktifkan perangkat** (metode ACPI + metode `Block_Kexts`) | `Content/02_Disabling_Devices/Disabling_PCI_Devices/` |
| ★ **pemetaan port USB dengan ACPI** (dua metode: `XHUB` / `XUPC`) | `Content/03_USB_Fixes/ACPI_Mapping_USB_Ports/` |
| **Memperbaiki sleep / wake** (`060D` detik bangun · `PTSWAK` · AOAC · ASPM) | `Content/04_Fixing_Sleep_and_Wake_Issues/` |
| Laptop (baterai / tombol FN / touchpad I2C / khusus merek) | `Content/05_Laptop-specific_Patches/` |
| Terkait CMOS | `Content/06_CMOS-related_Fixes/` |
| **Penjelasan item per item untuk Quirks** · Trik Config | `Content/08_Quirks/` · `Content/A_Config_Tips_and_Tricks/` |
| **Contoh urutan pemuatan kext** | `Content/10_Kexts_Loading_Sequence_Examples/` |
| Kartu grafis (iGPU/dGPU/APU) · **ukuran GPU-BAR** · menonaktifkan GPU yang tidak didukung · Metal 3 | `Content/11_Graphics/` |
| **Whitelist MMIO** · AppleVTD | `Content/12_MMIO_Whitelist/` · `Content/20_AppleVTD/` |
| Thunderbolt / periferal / jaringan / kecepatan RAM | `Content/19_Thunderbolt/` · `13_Peripherals/` · `N_Networking/` · `15_RAM/` |
| **Penjelasan item per item untuk boot-args** | `Content/H_Boot-args/` |
| OCLP on Wintel · pembaruan OTA · spoof Board-ID VMM | `Content/14_OCLP_Wintel/` · `S_System_Updates/OTA_Updates.md` · `09_Board-ID_VMM-Spoof/` |
| ★ **membuat sendiri ALC Layout-ID** | `Content/L_ALC_Layout-ID/` (ada juga yang lebih rinci di `5T33Z0/AppleALC-Guides` ⇒ `applealc-custom.md`) |
| **Troubleshooting**: SysReport · Preboot macet · mengubah spindump menjadi teks · membiarkan AI menganalisis bootlog | `Content/K_Debugging/` · `18_Troubleshooting/` (`Fixing_Preboot` · `Converting_Spindumps.md` · `Config_Tweaks_AI.md`) |
| Sekumpulan perintah terminal yang umum dipakai | `Terminal_Commands.md` |
| **Daftar periksa mandiri sebelum mengunggah EFI** | `Content/M_EFI_Upload_Chklst/` |

### 0.1 ★ Hal di repo ini yang "tidak ada di resmi / Dortania" (bagian yang paling layak dibaca)

- ★ **`SSDT-ALL`: menggabungkan banyak SSDT menjadi satu tabel** —— mengurangi entri `ACPI>Add`, memudahkan pengelolaan;
- ★★ **`ACPI_Mapping_USB_Ports`: pemetaan port USB dengan ACPI alih-alih kext** (dua metode: `XHUB` / `XUPC`)——
  untuk masalah seperti "batas 15 port USB" ini adalah **jalur yang berbeda dari `UTBMap`**;
- ★ **`Intel_I225-V_Fix_(SSDT-I225V)`** —— **kartu bawaan mesin ini memang Intel I225-V**, layak dijadikan pembanding (sekarang memakai `AppleIGC.kext`, lihat `ethernet-drivers.md`);
- ★ **`PMCR_Support_(SSDT-PMCR)`** —— hitungan `PMCR` di mesin ini **0**, termasuk kategori "mungkin perlu ditambahkan";
- ★ **`ACPI_Dropping_Tables` + `ACPI_Rename_Devices`** —— saat menghapus `xh_adls3` di mesin ini, mekanismenya persis milik yang pertama;
- ★ **`GPU-BAR_Size` / `Disabling_unsupported_GPUs`** —— terkait ReBAR / kartu grafis yang tidak didukung;
- ★ **`ACPI_Debugging` (termasuk `ACPIDebug.kext`)** —— alat pengumpulan bukti di tingkat ACPI;
- ★ **`18_Troubleshooting/Fixing_Preboot`** —— troubleshooting khusus untuk macet di Preboot (melengkapi `boot-failure-debug.md`).

## 1. Dasar resmi hanya ini

Dalam paket rilis resmi, `Docs/AcpiSamples/` (Source/*.dsl + Binaries/) **adalah daftar otoritatif** untuk menentukan "apakah SSDT perlu ditambahkan".
Ketentuan resmi untuk `OC/ACPI`:

- berkas diletakkan di `EFI/OC/ACPI`, ekstensi `.aml`; nama contoh `DSDT.aml`, `SSDT-1.aml`, `MYTABLE.aml`
- **subdirektori diizinkan**: pada contoh nilai `ACPI>Add>Path` secara eksplisit dituliskan `SubDir/SSDT-8.aml`
- batas panjang path `OC_STORAGE_SAFE_PATH_MAX` = **192 karakter** (termasuk `\0` di akhir)
- ★ **identitas tabel ditentukan oleh parsing isi, bukan oleh nama berkas** (teks asli entri `Path`: *"determined by parsing data, not by filename"*)
  ⇒ **mengubah nama aman**, asalkan `ACPI>Add>Path` ikut diubah; yang dicocokkan oleh `ACPI>Delete` juga isi (`TableSignature`/`OemTableId`)
- urutan pemrosesan (ACPI Introduction): **`Patch` → `Delete` → `Add`**; `RebaseRegions`/`SyncTableIds` baru diproses **setelah** semua perubahan

## 2. Lakukan konfirmasi "nol error" lebih dulu

```bash
# 0 hit di kernel log ⇒ tidak ada ACPI yang rusak (kriteria pertama)
grep -aiE "acpi error|ae_not_found|ae_already|namespace lookup|Error evaluating" <kernel log>
```

## 3. Pemeriksaan keberadaan perangkat (menentukan apakah suatu SSDT berlaku)

```bash
for n in SBUS BUS0 MCHC PMCR AWAC RTC RTC0 HPET GPRW XHCI GFX0 PEG0 PEG1 SAT0 HDAS; do
  printf "  %-6s %s\n" "$n" "$(ioreg -p IOACPIPlane -w0 | grep -c "$n")"
done
# apakah driver benar-benar terpasang (contoh: SMBus)
kmutil showloaded --list-only | grep -iE "smbus|AppleSMBus"
ioreg -r -c AppleSMBusController -w0 | wc -l     # 0 = termuat tapi tanpa instans ⇒ SSDT-SBUS-MCHC belum aktif
```

★ Perhatikan nama perangkat ACPI berbeda menurut vendor: di ASUS akar perangkat biasanya bernama **`PC00`** (bukan `PCI0`), perangkat audio bernama **`HDAS`** (bukan `HDEF`),
nama ACPI iGPU bisa **`GFX0`** (bukan `IGPU`). **SSDT harus ditulis memakai nama asli mesin ini**, jika tidak tabelnya tidak bisa dimuat.

## 4. Kondisi penerapan item per item dari AcpiSamples resmi

| Contoh | Kondisi penerapan menurut komentar resmi | Poin penilaian |
|---|---|---|
| `SSDT-EC` / `SSDT-EC-USBX` | Desktop butuh EC palsu (`_HID = ACID0001`); resmi secara eksplisit **tidak boleh menamai ulang EC0/H_EC menjadi EC, AppleACPIEC tidak boleh dimuat di desktop** | `ioreg -r -c AppleACPIEC` harus kosong |
| `SSDT-USBX` | properti daya USB (empat properti seperti `kUSBSleepPowerSupply`) | cukup keempat properti ada di tabel |
| `SSDT-PLUG` / `SSDT-PLUG-ALT` | platform Alder Lake dan CPU yang mendeklarasikan diri sebagai **Device, bukan Processor**; resmi mencatat "Alder Lake masih butuh CPU profile CPUFriend yang dikustomisasi" | dikombinasikan dengan `Kernel>Quirks>ProvideCurrentCpuInfo` |
| `SSDT-AWAC-DISABLE` | **For 300-series only**, dan membutuhkan variabel `STAS` ada | jumlah `AWAC` di `ioreg` = 0 ⇒ tidak berlaku |
| `SSDT-RTC0` / `SSDT-RTC0-RANGE` | **For 300-series only**, dipakai saat `SSDT-AWAC` tidak berlaku (perlu `STAS` ada) | sama seperti di atas |
| `SSDT-PMC` | Intel 300-series PMC (`APP9876`); **di APTIO V, PMC yang belum diinit akan macet di SMM ⇒ NVRAM tidak bisa ditulis** | bila baca/tulis NVRAM normal ⇒ tidak ada bukti perlu |
| `SSDT-BRG0` | GPU berada di balik satu lapisan PCI bridge tambahan (`PCI0.PEG0.PEGP.BRG0.GFX0`), dibutuhkan macOS 11+ | dGPU terhubung langsung dan driver normal ⇒ tidak perlu |
| `SSDT-UNC` | uncore fake bridge X99/X299 (IOPCIFamily akan crash sejak macOS 11) | platform tidak cocok ⇒ tidak berlaku |
| `SSDT-IMEI` | iGPU Sandy/Ivy Bridge | platform tidak cocok |
| `SSDT-EHCx-DISABLE` | EHCI platform lama | platform tidak cocok |
| `SSDT-ALS0` / `SSDT-PNLF` | Laptop (sensor cahaya ambient / backlight) | tidak berlaku untuk desktop |
| `SSDT-HV-DEV` / `HV-PLUG` / `HV-VMBUS` | mesin virtual Hyper-V | tidak berlaku untuk mesin fisik |
| `SSDT-SBUS-MCHC` | tabel kompatibilitas SMBus: menambahkan `BUS0`(`_CID="smbus"`) dan `MCHC` ke `SBUS`, agar `AppleSMBusController` terpasang | `BUS0`=0 dan `AppleSMBusController` tanpa instans ⇒ **aktifkan ini** |

**Yang umum ada di Dortania tapi tidak ada di contoh resmi OpenCore**: `SSDT-RHUB` (reset hub saat USB controller tidak ter-enumerasi),
`SSDT-DMAR` (menonaktifkan DMAR), `SSDT-GPRW` (detik untuk bangun). Penilaiannya juga bergantung pada "apakah mesin ini punya gejala/metode yang sesuai":
metode `GPRW` tidak ada ⇒ patch itu tidak berlaku; semua port USB ter-enumerasi normal ⇒ RHUB tidak perlu; tidak ada DMAR di tabel firmware ⇒ patch DMAR tidak perlu.

## 5. Normalisasi penamaan

**Standar**: `SSDT-<fungsi>[-<platform>].aml`, seluruhnya ASCII huruf besar, hanya berisi huruf/angka/`-`, tanpa `_`, spasi, atau non-ASCII; panjangnya jauh di bawah batas 192.

- Pertahankan nama asli Dortania (`SSDT-EC` / `SSDT-USBX` / `SSDT-RTCAWAC` / `SSDT-PLUG-ALT`) supaya mudah dibandingkan dengan panduan
- Untuk tabel pengganti tabel BIOS, **pertahankan OEM Table ID yang sama dengan tabel yang diganti** (contoh: mengganti `xh_adls3` memakai `xh_adls3`), supaya mudah dicocokkan di log
- Tabel yang belum aktif **dipindahkan ke subdirektori** (misalnya `ACPI/disabled/`), `Path` ditulis `disabled/SSDT-X.aml`; dengan begitu direktori aktif bisa dibaca sekilas
  —— setelah diaktifkan, **pindahkan kembali ke `ACPI/` dan ubah `Path` secara sinkron** (jangan biarkan entri aktif tergeletak di `disabled/`)

## 6. Urutan troubleshooting (disarankan)

1. 0 error di kernel log?→ tidak ada "ACPI rusak"
2. Cocokkan contoh resmi satu per satu dengan keberadaan perangkat di mesin ini → dapatkan daftar "perlu / tidak perlu ditambahkan"
3. Periksa apakah setiap `Path` di `ACPI>Add` **benar-benar ada**, dan apakah ada **berkas yatim** di direktorinya
4. Periksa apakah `ACPI>Delete` berhasil mencocokkan (lihat log OC `OCA: Deleting table …`)
5. Terakhir baru pertimbangkan "apakah perlu ditambahkan"; saat menambahkan, tambah satu tabel saja per kali, restart, lalu lihat apakah kernel log masih 0 error
6. ★ Kalau macet di posisi seperti **Preboot** ⇒ `5T33Z0/OC-Little-Translated` `Content/18_Troubleshooting/Fixing_Preboot` (ada juga `boot-failure-debug.md`)
