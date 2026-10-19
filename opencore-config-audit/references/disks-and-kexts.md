# Blokir disk dan penyederhanaan kext

> ★ Saat **memasang kext ke direktori sistem / menggabungkan KDK / membangun ulang cache**, bisa memakai `laobamac/SimpleLoader` (antarmuka grafis SwiftUI,
> **dengan proteksi snapshot APFS bawaan**, lebih aman daripada `kmutil` manual).
> **KDK image** ada di `laobamac/KdkSupportPkg`; **alat patch MetalLib** ada di `laobamac/MetallibSupportPkg`.
> Indeks ada di `laobamac-toolkit.md` §4.

## I. Pemblokiran disk: bedakan dulu antara "selector" atau "di dalam macOS"

| Tujuan | Cara yang benar | Jangan pernah |
|---|---|---|
| Tampilkan lebih sedikit di boot selector | `Misc>Boot>HideAuxiliary=true` (menyembunyikan recovery / Time Machine / entri sistem); untuk menyembunyikan item tertentu, tambahkan entri untuk volume tersebut di `Misc>Entries` dan tandai `Auxiliary` | ❌ Menggunakan `Misc>Security>ScanPolicy` — itu adalah **kebijakan keamanan**, setelah diblokir OpenCore **tidak melihat OS lain**, Windows tidak bisa boot |
| Volume lain tidak muncul di dalam macOS | `/etc/fstab` + `noauto` (lihat di bawah) | ❌ Menghapus partisi / mengubah tabel partisi |

**Untuk menentukan apa yang benar-benar ditampilkan di selector**, lihat hanya baris `OCB: Registering entry <nama>` di log OC — itu satu-satunya dasar yang dapat diandalkan.

### 1.1 Pemblokiran di sisi macOS (`/etc/fstab` + `noauto`)

Prinsip: menuliskan `noauto` untuk volume target ⇒ sistem **tidak memount otomatis** saat boot ⇒ Desktop / Finder / Spotlight tidak menampilkannya.

```
# Blokir volume non-macOS — hanya mount otomatis Macintosh HD
# ★★ Partisi EFI tidak termasuk daftar ini! Boot berada di atasnya, pemasangan App bergantung pada baca-tulis config.plist ⇒ jangan pernah diblokir
UUID=<volume UUID> none ntfs noauto   # nama volume
```

Poin penting:

- **Selalu gunakan UUID volume**, jangan `/dev/diskXsY` (nomor disk bisa bergeser). Ambil UUID: `diskutil info <dev> | awk -F': *' '/Volume UUID/{print $2}'`
- vfstype pada field ke-4 `fstab` harus sesuai dengan sistem file sebenarnya (NTFS tulis `ntfs`, exFAT tulis `exfat`); karena memakai `noauto`, file tersebut tidak benar-benar di-mount, jadi salah tulis tidak berakibat fatal
- **Partisi lain pada disk yang sama tidak saling memengaruhi** (fstab mencocokkan berdasarkan UUID volume) ⇒ memblokir volume Windows pada disk yang sama tidak memengaruhi partisi EFI di disk tersebut
- Pembatalan: `sudo rm /etc/fstab` lalu restart; akses sementara: `sudo diskutil mount /dev/diskXsY` (atau beri komentar pada baris tersebut lalu restart)
- **Langsung berlaku setelah ditulis**: cari perangkat berdasarkan UUID lalu `diskutil unmount` satu per satu; pastikan `/Volumes` hanya berisi `Macintosh HD`
- ★ Setelah menulis **wajib verifikasi bahwa EFI masih bisa di-mount**: cari ESP berdasarkan UUID → `diskutil unmount` → `diskutil mount` → pastikan bisa membaca `config.plist`

Skrip: `scripts/mask-other-disks.sh` (otomatis mengecualikan EFI, bisa dijalankan berulang).

### 1.2 Troubleshooting pertanyaan terkait fstab

```bash
cat /etc/fstab
diskutil info <dev> | grep -E "Volume Name|Volume UUID|File System"
ls -1 /Volumes            # Setelah pemblokiran berhasil, hanya Macintosh HD yang tersisa (+ EFI bila diperlukan)
```

## II. Penyederhanaan kext

### 2.1 Buat tiga tabel terlebih dahulu

1. Seluruh entri `Kernel>Add` (`BundlePath` / `Enabled` / `Comment`)
2. File yang benar-benar ada di direktori `EFI/OC/Kexts/`
3. Selisih antara keduanya:
   - **File yatim** (ada di direktori, tidak ada di `Add`) ⇒ pasti tidak terpakai, bisa dihapus
   - **Dirujuk tapi filenya tidak ada** ⇒ entri mati, tambahkan filenya atau hapus entri
   - **Entri dengan `Enabled=false`** ⇒ kandidat penghapusan, nilai satu per satu

### 2.2 Kriteria penghapusan (hapus hanya bila salah satu terpenuhi)

- **Hardware untuk driver tersebut sudah diganti** (contoh: driver Intel nirkabel/Bluetooth, tetapi mesinnya sudah diganti ke kartu jaringan Broadcom)
- **Fungsinya sudah tercakup oleh sakelar lain** (contoh: `CpuTopologyRebuild` vs `Kernel>Quirks>ProvideCurrentCpuInfo=true`)
- **Fitur terkait tidak dipakai di mesin ini** (contoh: `AppleALC` padahal memakai sound card eksternal, dan tidak ada injeksi layout-id)
- Item sementara dengan `Enabled=false` dalam jangka panjang dan komentarnya menuliskan "for isolation / for comparison"

### 2.3 Daftar "tidak boleh dihapus" (bandingkan saat menilai)

| kext | Alasan tidak boleh dihapus |
|---|---|
| `Lilu` | Host untuk semua plugin |
| `VirtualSMC` + `SMCProcessor`/`SMCSuperIO` | Emulasi SMC dan sensor |
| `WhateverGreen` | Koreksi kartu grafis; `-wegnoigpu` juga bergantung padanya |
| `USBToolBox` + `UTBMap` | Pemetaan port USB (pengganti `XhciPortLimit`) |
| `RestrictEvents` | Bekerja sama dengan `revpatch=` untuk mengubah tampilan model/CPU |
| `NVMeFix` | Manajemen daya / kompatibilitas NVMe |
| `AMFIPass` | Bekerja sama dengan boot-args AMFI |
| Tiga set nirkabel (`IOSkywalkFamily` + `IO80211FamilyLegacy` + `AirPortBrcmNIC*` yang sesuai) | Kombinasi wajib untuk kartu Broadcom di macOS versi baru (rute OCLP), **tanpa itu tidak ada WiFi** |
| `XHCI-unsupported` | Kontroler USB non-asli (ASMedia dan sejenisnya) |
| `BlueToolFixup` | Untuk sebagian Bluetooth Broadcom |
| `CPUFriend` + DataProvider | Data daya CPU kustom |

> ★ **Tiga set nirkabel/Bluetooth Intel** (`itlwm` atau `AirportItlwm` + `IntelBluetoothFirmware` / `IntelBTPatcher`, sistem baru juga butuh `BlueToolFixup`)
> hanya dibutuhkan bila **mesinnya memang memakai kartu jaringan Intel**:
> setelah diganti ke kartu asli seperti Broadcom, item tersebut termasuk "driver untuk hardware yang sudah diganti" dan boleh dihapus (langkah pembersihan ada di `intel-wifi.md` §5);
> sebaliknya, pada mesin yang memakai kartu jaringan Intel item-item ini **wajib** ada, jangan dianggap "tidak dipakai" lalu dihapus.

### 2.4 Alur penghapusan

1. **Backup aslinya terlebih dahulu** ke workspace (`cp -pR <Kexts>/X.kext <direktori backup>/`), dan catat ukurannya
2. Hapus entri config: `plutil -remove 'Kernel.Add.<idx>' <config>`, jika banyak **hapus dari indeks tinggi ke rendah**
3. Hapus file: `rm -rf <Kexts>/X.kext`
4. Verifikasi: `scripts/oc-verify.sh` (setiap file yang dirujuk di `Add` harus ada)
5. Hitung pemakaian sebelum dan sesudah: `du -sh <Kexts>`

## III. Tema (OpenCanopy) jangan diubah ikut-ikutan

Semua sakelar terkait tema dipertahankan: `Misc>Boot>PickerMode=External`, `PickerAttributes`, `PickerVariant`,
serta `EFI/OC/Resources/Image/<set ikon>/`.

- Set ikon resmi (yang `GoldenGate` / `Syrah` / `Chardonnay` dari OcBinaryData) **masing-masing hanya punya 25 file `.icns`**
- Baris `OCUI: Failed to load image … Background.icns / Apple.icns / Other.icns / ExtTool.icns / ResetNVRAM.icns … - Not Found` di log
  adalah fallback normal setelah OpenCanopy mendeteksi **ikon opsional** — nama-nama tersebut **tidak ada di set ikon resmi mana pun**, **tidak ada yang bisa ditambahkan**, jangan "diperbaiki"
- Bit `PickerAttributes`: `0x01` ikon volume, `0x02` `.disk_label`, `0x04` gambar label generik, `0x10` kontrol pointer, `0x40` UI minimal, `0x80` ikon Flavour, `0x100` UI terbalik
