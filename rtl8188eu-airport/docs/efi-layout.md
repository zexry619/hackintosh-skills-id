# Layout Disk & OpenCore (verified 21 Okt 2026)

## Peta partisi

```
/dev/disk0  (SSD internal, 256 GB)
  s1  (hilang)  ← EFI lama 16,8 MB "EFINVME" — SUDAH DIHAPUS/ digabung
  s2  Apple_APFS Container disk2  → macOS 15.8.1
  s3  EFI "EFI-BIG"  512 MB   ← ESP AKTIF (OpenCore)   Volume UUID DDA2169E-423F-3A6D-8C3A-F8371F48D184
                                            Partition UUID 1FD87A68-9CDF-403D-884C-58E84ADE5634
  free: 477 MB (dari 487 MiB)

/dev/disk1  (disk lain, 480 GB — milik Linux/host lain)
  s1  EFI "NO NAME"  629 MB   (tidak terkait dengan macOS ini)
  s2  1,1 GB
  s3  Linux Filesystem
```

## Isi ESP (`/Volumes/EFI-BIG`)

```
EFI/
├── BOOT/BOOTx64.efi          24.576 B  (bootstrap OpenCore)
└── OC/
    ├── OpenCore.efi         626.688 B  (OpenCore 1.0.8 RELEASE)
    ├── config.plist          27.315 B  (valid: plutil -lint OK)
    ├── ACPI/  Drivers/  Kexts/  Resources/  Tools/OpenShell.efi
```

Kext yang di-inject OpenCore (`Kernel → Add`, 12 buah, semuanya ada di folder):
Lilu, VirtualSMC, AppleALC, XHCI-unsupported, BlueToolFixup, CpuTscSync,
RealtekRTL8111, NVMeFix, RestrictEvents, SMCProcessor, SMCSuperIO, WhateverGreen.

## Pengaturan penting

| Setting | Nilai | Catatan |
|---|---|---|
| `Misc/Security/BootProtect` | tidak ada | boleh tulis ke ESP |
| `Misc/BlessOverride` | kosong | firmware pakai ESP di disk0 |
| `Misc/Boot/LauncherOption` | Full | picker OpenCore tampil |
| `Misc/Boot/Timeout` | 5 | |
| `Misc/Boot/ShowPicker` | true | |
| `NVRAM/Add/4D1FDA02…` (disable kext) | kosong | tidak ada kext yang di-disable |
| NVRAM `efi-boot-device` | tidak ada | tidak ada referensi ke ESP lama → aman |

## Forensic setelah perubahan partisi

* `diskutil verifyVolume /dev/disk0s3` → **exit code 0** (filesystem sehat).
* Tidak ada variabel NVRAM yang menunjuk ESP lama, jadi boot berikutnya aman.
* Backup dibuat: `backup/EFI-BIG-20261021-030831.tar.gz` (5,3 MB,
  sha256 `da3810c51bbd72e91bb4dabf5f9253474d04fea3783756ed3940aca4ef6bd4d5`).

## Dampak ke proyek driver

1. **Keterbatasan ukuran ESP hilang.** Driver custom (±2–4 MB) muat tanpa masalah;
   `AirportItlwm` (15 MB) juga akan muat.
2. **Jalur injeksi OpenCore kini tersedia** sebagai alternatif AuxiliaryKernelExtensions:
   salin `RTL8188EUM1.kext` ke `EFI/OC/Kexts/` + tambah entri `Kernel → Add`.
   Lebih sederhana & tidak butuh AuxKC/approval.
3. Jalur M1 yang sedang berjalan (AuxKC) **tidak terpengaruh** sama sekali —
   AuxKC disimpan di `/Library/KernelCollections` + `/var/db`, bukan di ESP.
