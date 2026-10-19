# Fakta mesin referensi (Z690 / Alder Lake / macOS 26)

> Ini adalah hasil pengukuran nyata dari **mesin referensi** (mesin yang dipakai saat materi skill ini diambil), boleh langsung dikutip sebagai pembanding;
> **saat berganti mesin, verifikasi ulang mengikuti tahap 0 di `SKILL.md`**, jangan dianggap sebagai konfigurasi universal.
> Istilah "mesin ini" di bawah = mesin referensi ini.

## Perangkat keras / Model

- Motherboard ASUS TUF GAMING Z690-PLUS WIFI D4; CPU i7-12700K (Alder Lake-S, `0x90672`)
- GPU diskret RTX 3080 10GB (`10de:2206`, PEG1 0:1:0); iGPU UHD 770 (`8086:4680`, 0:2:0)
- NIC I225-V (direspons `AppleIGC.kext`) + Broadcom BCM943602CDP (nirkabel/BT)
- Model **`iMac20,1`** (sejak 10-15 01:54; sebelumnya 10-13–10-15 adalah `MacPro7,1`, lebih awal lagi `iMacPro1,1`); board-id `Mac-CFF7D910A743CAAF`
  - ★★ **Pada 10-15 03:33 sudah diganti bersama tiga kodenya** (tiga tempat: `serial` / `MLB` / `UUID`; `ROM` tidak diubah)
    ⇒ Dasar: **nama model di "Tentang Mac Ini" = fungsi dari kode produk nomor seri**, mengganti model tanpa mengganti kode akan terus menampilkan model lama
    (`smbios-and-serials.md` §1.3)
  - ★ **Nilai asli tiga kode tidak dimasukkan ke repositori**: catatan ledger mesin ini ada di area kerja `SMBIOS-iMac201-tiga-kode-20261015.md` (memuat kredensial identitas, jangan disebarkan);
    artikel ini hanya mencatat strukturnya: kode produk `serial` harus sesuai `iMac20,1`, digit cek `MLB` harus lolos, `UUID` acak v4
  - Nama komputer `Geek’s iMac` / `LocalHostName` `Geeks-iMac` (diubah 10-15 03:37; **`NetBIOSName`/`ServerDescription` pada SMB ikut diubah**)
- Disk (**kenali lewat kapasitas, nomor disk bisa bergeser**):
  | Volume | Kapasitas | Disk fisik | Antarmuka |
  |---|---|---|---|
  | Aplikasi | 256 GB | SAMSUNG MZVLW256HEHP | NVMe |
  | Proyek | 205 GB | KINGSTON SA400S37480G (**disk yang sama dengan macOS**) | SATA · AHCI Port 4 |
  | macOS (Macintosh HD, APFS 274.9 GB) | — | KINGSTON SA400S37480G | SATA · AHCI Port 4 |
  | Volume Windows (tanpa nama) | 512 GB | ZHITAI PC005 Active 512 GB | NVMe |
  | Cadangan | 1 TB | WDC WD10SPZX-00Z10T0 | SATA · AHCI Port 5 |

## EFI / OpenCore

- **ESP berada di disk 512 G** (ZHITAI): `disk1s1`, nama volume `EFI`, UUID volume **⟨UUID volume ESP Anda, ambil dengan `diskutil info diskXs1 | grep UUID`⟩**, FAT16, 119.5 MB
- OpenCore = **`DBG-108-2026-09-27`** (= **build 1.0.8 DEBUG**, `OpenCore.efi` 868,352 B, sha `11ba0b76…`; RELEASE resmi adalah 626,688 B / `9ef21f9d…`)
- Arsip versi config: `xh_adls3perbaikan-20261013/config.plist.vNN-<keterangan>`; cermin di area kerja `_oc-current.plist`
- **Yang berlaku (sejak 10-15 03:33)**: config pada ESP internal punya sha **`d1f6990295f5b49b0e62509bdbfba7b44e4f1d6bd56772a2153717208b309d44`**,
  `SystemProductName=iMac20,1` + tiga kode baru + `LauncherOption=Full`; arsip **`config.plist.v52-imac201-serials`**.
  Cadangan: `_oc-backup-before-imac201-serials-20261015-033352.plist` (area kerja) + `config.plist.BASELINE-20261015-033349` di ESP.
  Config pada ESP USB punya sha **`d01b859a…`**, `LauncherOption=Disabled`.
  (lebih awal: `a08dfed3…` = versi iMac20,1 tetapi dengan **tiga kode lama**; `b06951b2…` = versi dengan `Disabled` di kedua sisi; v45–v51 ada di `xh_adls3perbaikan-20261013/`)
- **Dua ESP (★ nomor disk bisa bergeser, kenali lewat kapasitas/peran)**:
  | ESP | Disk | Kapasitas | config | Peran |
  |---|---|---|---|---|
  | ESP internal (**pernah terlihat `disk1s1` / `disk2s1`, nomor disk bergeser**) | ZHITAI PC005 NVMe 512 GB | 119.5 MB | `DBG-108` (DEBUG, 868,352 B) | **Disk boot target** |
  | ESP USB `disk9s1` | disk eksternal 32 GB | 1.1 GB | `REL-108` (RELEASE, 626,688 B), konfigurasi FALLBACK untuk model `iMacPro1,1` | Disk rescue |
- **★ Dari mana sistem di-boot sekarang** (`nvram 4D1FDA02-…:boot-path`):
  - hasil ukur 10-15 02:55 = `…/USB(0x18,0x0)/…/HD(1,GPT,…)/EFI\OC\OpenCore.efi` ⇒ saat itu **di-boot dari USB** (`REL-108`)
  - **hasil ukur 10-15 03:40 = `PciRoot(0x0)/Pci(0x6,0x0)/Pci(0x0,0x0)/NVMe(0x1,…)/HD(1,GPT,⟨ESP internal⟩)/\EFI\OC\OPENCORE.EFI`**
    ⇒ ★★ **sudah diubah untuk boot dari disk internal** (OC = `DBG-108`, yaitu yang ada di disk) ⇒ migrasi `boot-entries.md` §8 **sudah selesai**
- ★★ **Tiga kode baru belum berlaku** (hasil ukur 10-15 03:40): config sudah berisi kode baru, tetapi **`IOPlatformSerialNumber` saat runtime masih kode lama**
  ⇒ **berarti sejak ditulis pada 03:33 belum ada restart**. Baru setelah restart akan beralih ke kode baru dan memicu autentikasi ulang iCloud / Pesan / FaceTime.
  Cache nama tampilan "Tentang Mac Ini" (`~/Library/Preferences/com.apple.SystemProfiler.plist`) **saat ini juga masih nilai lama**
  (`cachedSerial` = kode lama, `P7QM-…` = `Mac Pro (2019)`) —— baru setelah restart akan diturunkan ulang berdasarkan kode baru.

## Status sakelar penting (v52)

| Kunci | Nilai | Catatan |
|---|---|---|
| `Misc>Debug>Target` | `69 (0x45)` | logging + DataHub + file; **bit konsol 0x02 sudah dimatikan** (layar tidak lagi bergulir) |
| `Misc>Debug>DisplayLevel` | `0x80000042` | ERROR + INFO (VERBOSE belum dinyalakan) |
| `Misc>Security>ScanPolicy` | `0` | tetap 0 (picker harus bisa melihat Windows) |
| `Misc>Security>SecureBootModel` | `Disabled` | berpasangan dengan `FixupAppleEfiImages=true` |
| `Misc>Security>Vault` | `Optional` | tidak ada vault.plist |
| `Misc>Security>ExposeSensitiveData` | `7` | `0x01` adalah `boot-path` yang dipakai App 1401 untuk menemukan OpenCore, **jangan diturunkan ke 6** |
| `Misc>Boot>LauncherOption` / `RequestBootVarRouting` | **`Full`** / `true` | ★ **Keputusan final 10-15 02:41: yang di disk `Full` (bikin sendiri + self-heal) / yang di USB `Disabled` (tidak menulis ulang NVRAM)** —— sempat keduanya diubah ke `Disabled`, tapi begitu begitu **tidak ada yang membuat entri boot**, sudah dikembalikan. Lihat `boot-entries.md` §3 |
| `Misc>Boot>PickerMode/Variant/Attributes` | `External` / `Acidanthera\GoldenGate` / `144` | tema, dipertahankan |
| `Misc>Boot>HideAuxiliary` | `true` | menyembunyikan entri recovery / alat (tekan spasi untuk membuka) |
| `Booter>Quirks>EnableWriteUnprotector` | `false` | berdasarkan `OCABC: MAT support is 1` |
| `Booter>Quirks>ResizeAppleGpuBars` | `-1` | baseline driver |
| `UEFI>Quirks>ResizeGpuBars` | `13` (8 GB) | baseline driver; konsekuensinya = layar hitam saat boot ~21 s |
| `UEFI>APFS>MinDate/MinVersion` | `0` / `0` | sebelumnya `-1` (dokumentasi strongly discouraged) |
| `Kernel>Quirks>PanicNoKextDump` | `false` | untuk memperoleh informasi kext di dalam log panic |
| `Kernel>Quirks>ProvideCurrentCpuInfo` | `true` | SMP asimetris Alder Lake |
| `Kernel>Emulate>Cpuid1Data/Mask` | `55 06 0A 00…` / `FF FF FF FF…` | nilai rekomendasi ADL→Comet Lake dari dokumentasi |
| `PlatformInfo>UpdateSMBIOSMode` + `CustomSMBIOSGuid` | `Custom` + `true` | berpasangan |
| `PlatformInfo>CustomMemory` + `Memory>Devices` | `true` / **4 entri** | ★ **Jumlah slot berubah menurut model**: `MacPro7,1`=12 slot, **`iMac20,1`=4 slot**; `Devices` harus memuat seluruh slot (termasuk slot kosong). `MaxCapacity` = 68719476736 (64 GB) |

**boot-args**:
```
-v amfi_get_out_of_my_way=0x1 amfi=0x80 -wegnoigpu nvrmsettle=1500 nvfbsample=1
ipc_control_port_options=0 nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth
-no_compat_check revpatch=sbvmm,cpuname keepsyms=1 debug=0x144 revcpu=1 nmxintel=1
```

## Status ACPI / SSDT

- 6 yang diaktifkan: `SSDT-EC.aml`, `SSDT-RTC-AWAC.aml`, `SSDT-USBX.aml`, `SSDT-SBUS-MCHC.aml`, `SSDT-PLUG-ADL.aml`, `SSDT-XHADLS3.aml`
- 2 yang dinonaktifkan (di `ACPI/disabled/`): `SSDT-PLUG-MADT.aml`, `SSDT-PLUG-DRTNIA.aml`
- `ACPI>Delete` menghapus `SSDT` dari firmware (OEM ID `xh_adls3`, 7586 B) dan menyuntik tabel pengganti (7393 B, dengan OEM ID yang sama)
- Log kernel ACPI **0 error**; firmware 26 tabel; **tidak ada DMAR**; `FACP` 276 B rev6, `FACS` di `0x5871E000`
- ★ Penamaan ACPI mesin ini: perangkat root **`PC00`** (bukan `PCI0`), audio **`HDAS`** (bukan `HDEF`), iGPU **`GFX0`** (tanpa `IGPU`)
- Keberadaan perangkat: `SBUS`=1 / `BUS0`=0→ (seharusnya 1 setelah SSDT SMBus diaktifkan) / `PMCR`=0 / `AWAC`=0 / `RTC`=1 / `GPRET`=0 / `HPET`=1 / `GPRW`=0

## Status kext (`Kernel>Add` 22 entri)

Diaktifkan: Lilu, **AppleALC**, **CpuTopologyRebuild**, CPUFriend, CPUFriendDataProvider, VirtualSMC, SMCProcessor,
SMCSuperIO, WhateverGreen, AppleIGC, BlueToolFixup, NVMeFix, RestrictEvents, USBToolBox, XHCI-unsupported, UTBMap,
AMFIPass, IOSkywalkFamily, IO80211FamilyLegacy, AirPortBrcmNIC-Tahoe, **NvidiaSensor**
(salah satunya `IO80211FamilyLegacy…/AirPortBrcmNIC.kext` bernilai `Enabled=False`, sebagai fallback untuk Sequoia:
Broadcom memakai **MinKernel 23 / MaxKernel 24.99.99 dengan `AirPortBrcmNIC`, ≥25 dengan `AirPortBrcmNIC-Tahoe`**)

2 entri `Kernel>Block`: `IONDRVFramebuffer` (merebut index 0 NVRMFB), `Allow IOSkywalk Downgrade` (OCLP Modern Wireless)

Yang sudah dihapus (cadangan di area kerja `_kexts-removed-20261014/`): `itlwm`, `IntelBluetoothFirmware`, `IntelBTPatcher`

**Status audio onboard**: `AppleHDA.kext` 600.2 terpasang di **`/System/Library/Extensions`** (dari KDK 15.8.1 build 24H32, wajib dipasang kembali di macOS 26);
`AppleALC` 1.9.9 dikompilasi sendiri, DeviceProperties disuntik ke `PciRoot(0x0)/Pci(0x1F,0x3)`: `layout-id=<0e000000>` (layout 14 buatan mesin ini)
+ `alc-verbs=<01000000>`. Metode lengkap dan jebakan lihat `applealc-custom.md`.

## Pemblokiran sisi macOS (`/etc/fstab`)

4 entri `noauto` (`Proyek` / `Windows Vol` / `Perangkat Lunak` / `Cadangan`, **sesuai UUID volume**), **tidak termasuk EFI**.
Skrip: `_mask-other-disks.sh` di area kerja.

## Alat

- GitHub API: bungkus pemanggilan `curl` ke `https://api.github.com` dengan skrip (`<GET|POST|PATCH> <path> [berkas json]`),
  kredensial dibaca dari **file lokal** (siapkan sendiri, jangan dimasukkan ke repositori)
  - path **harus diawali `/`**
- Privilege elevasi: `osascript -e 'do shell script "…" with administrator privileges'` (bisa menjalankan `log show`, `diskutil mount`)
- Mesin ini tidak punya `/opt/homebrew`; Python terkelola = `~/.workbuddy-ai/binaries/python/versions/3.13.12/bin/python3`
