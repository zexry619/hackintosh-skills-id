# Kartu jaringan Broadcom (BCM943602CDP / BCM43602) alur konfigurasi

> Dasar: catatan praktis dari mesin ini (ASUS Z690 / macOS 15.8.1 → 26.7.1) +
> penulisan yang selaras kata per kata dengan `efi_builder/networking/wireless.py` OCLP (cabang Modern Wireless).
> **★ Alur ini wajib dipisah per versi macOS** — Apple menghapus driver Wi-Fi Broadcom mulai Sequoia,
> dan cara tambal Sequoia dan Tahoe **bukan satu paket yang sama**.

## 0. Kenali dulu kartunya

| Komponen | Chip | Lokasi | Keterangan |
|---|---|---|---|
| Wi-Fi | **BCM43602** | **PCIe**, `14e4:43ba` | FullMAC, 3×3 802.11ac; subsystem `0x14E4,0x16D` (= Apple) |
| Bluetooth | **BCM20703** | **USB** (pin header internal 9-pin di motherboard) | Chip fabrikasi asli Apple, didukung native oleh macOS |

> ★ **Saat naik dari 15 ke 26, driver kartu ini harus diganti** (`AirPortBrcmNIC-Tahoe.kext`, `MinKernel 25.0.0`)
> ⇒ Alur upgrade lengkap lihat `os-upgrade-15-to-26.md`.

- ★ **Bluetooth tidak lewat PCIe**: kalau kabel USB internal 9-pin di kartu tidak dicolokkan, hanya ada Wi-Fi, tanpa Bluetooth
- ★ **Firmware BCM20703 ada di dalam kartu** ⇒ umumnya **tidak perlu** `BrcmPatchRAM3` / `BrcmFirmwareData` (itu untuk kartu Broadcom non-orisinil)
- ★ Cabut/blokir **kartu jaringan Intel asli** (di mesin ini AX201, Bluetooth `8087:0026`): dua Bluetooth controller membuat macOS bingung

## 1. ★★ Pilih jalur sesuai sistem (inti)

| | **macOS 15 Sequoia (Darwin 24)** | **macOS 26 Tahoe (Darwin 25)** |
|---|---|---|
| Driver kernel Wi-Fi | `IO80211FamilyLegacy.kext` + plugin **`AirPortBrcmNIC.kext`** di dalamnya | **kext mandiri `AirPortBrcmNIC-Tahoe.kext`** |
| Batas versi entri kernel | plugin: `MinKernel 23.0.0` / **`MaxKernel 24.99.99`** | kext mandiri: **`MinKernel 25.0.0`** / `MaxKernel` kosong |
| Sumber driver | Kext set OCLP 2.5.1 | Versi Tahoe baru yang ditambahkan **OCLP 3.0.0-rc.3+** (`payloads/Kexts/Wifi/AirPortBrcmNIC-Tahoe-v1.0.0.zip`) |
| Kenapa berbeda | — | `AirPortBrcmNIC.kext` dari OCLP 2.5.1 punya `MaxKernel=24.99.99` ⇒ **setelah naik ke Tahoe entri dilewati ⇒ Wi-Fi langsung hilang** |
| User space (root patch) | **Wajib** melakukan root patch OCLP | **Juga dibutuhkan** (gunakan OCLP 3.0.0+) |
| Dua OS berbagi satu config | Dua-duanya disimpan, **masing-masing diatur oleh `MinKernel`/`MaxKernel`**: entri Sequoia `MaxKernel 24.99.99`, entri Tahoe `MinKernel 25.0.0` | Sama seperti di sebelah |

> Kondisi mesin ini sekarang persis "keduanya berdampingan": versi plugin `AirPortBrcmNIC.kext` = **dinonaktifkan** (komentar Sequoia only),
> `AirPortBrcmNIC-Tahoe.kext` = **diaktifkan** (komentar Tahoe / Darwin 25+).

## 2. Bagian yang wajib dilakukan di kedua versi

### 2.1 `Kernel → Block` (prasyarat jalur OCLP)

- **Hapus** (kalau sebelumnya diblokir untuk hemat daya/penelusuran masalah): `IOBluetoothFamily`, `IOBluetoothHIDDriver`, `AppleBluetoothModule`,
  `AppleBluetoothMultitouch`, `IO80211Family`
- **Tambahkan**:
  ```
  Identifier : com.apple.iokit.IOSkywalkFamily
  Strategy   : Exclude
  MinKernel  : 23.0.0
  Enabled    : true
  ```
  (Jalur OCLP harus **mengganti** IOSkywalkFamily, jadi sistemnya diblokir dulu)

### 2.2 `Kernel → Add` (urutannya tidak boleh dibalik)

```
[1] IOSkywalkFamily.kext          MinKernel 23.0.0
[2] IO80211FamilyLegacy.kext      MinKernel 23.0.0
[3] AirPortBrcmNIC.kext (plugin)  MinKernel 23.0.0 / MaxKernel 24.99.99   ← Sequoia
[4] AirPortBrcmNIC-Tahoe.kext     MinKernel 25.0.0                        ← Tahoe
[5] BlueToolFixup.kext            (Bluetooth wajib, macOS 12+)
```

- **Dasar urutan (dari `OSBundleLibraries` milik kext itu sendiri)**: `IO80211FamilyLegacy` bergantung pada
  `com.apple.iokit.IOSkywalkFamily 1.0`; `AirPortBrcmNIC` bergantung pada `com.apple.iokit.IO80211FamilyLegacy 600.0`
  ⇒ **IOSkywalkFamily harus paling depan**, urutan salah akan menyebabkan "ada ikon tapi tidak bisa konek/tidak bisa dibuka"
- `IONameMatch` pada `AirPortBrcmNIC.kext` sudah memuat **`pci14e4,43ba`** — persis kartu ini
- Field untuk entri Tahoe (mengikuti penulisan OCLP 3.0.0):
  `BundlePath=AirPortBrcmNIC-Tahoe.kext` / `ExecutablePath=Contents/MacOS/AirPortBrcmNIC` /
  `PlistPath=Contents/Info.plist` / `MinKernel=25.0.0` / `Arch=x86_64`
- ★ **`itlwm.kext` wajib dinonaktifkan** (driver kartu Intel, akan bentrok dengan Broadcom)

### 2.3 NVRAM (`7C436110-…-FE41995C9F82`, **tipe data `data`**)

```
bluetoothExternalDongleFailed   = 00
bluetoothInternalControllerInfo = 000000000000000089653a552efd
```

(Inject "informasi controller" yang wajib ada untuk Bluetooth sejak Sonoma/Sequoia; tanpa itu Bluetooth tidak bisa dibuka)

### 2.4 Pemetaan port USB (langkah yang paling gampang gagal)

Kalau memakai `USBToolBox.kext` + `UTBMap.kext`, **port yang tidak ditulis di tabel pemetaan akan langsung dinonaktifkan**:

- `UsbConnector` untuk port tempat Bluetooth berada (di mesin ini **HS11**) disetel ke **`255` (Internal)**
- **Hapus port Bluetooth Intel asli** (di mesin ini HS14); `port-count` dikurangi 1
- Verifikasi (yang dibaca adalah **nilai sebenarnya pada objek port**, bukan hanya melihat file konfigurasi):
  ```bash
  ioreg -p IOUSB -w0 -l | grep -i -A3 "bluetooth"     # harus melihat Bluetooth USB Host Controller / BCM20703
  ```

### 2.5 Inject `built-in` (persyaratan `en0` / iServices dari Dortania)

```
DeviceProperties → Add →
  PciRoot(0x0)/Pci(0x1C,0x1)/Pci(0x0,0x0)
    built-in = <01>          ← tipe Data, nilai 1 byte 01
```

- Dari mana path-nya: menelusuri rantai ancestor di IODeviceTree `Root / PC00@0 / RP02@1C,1 / PXSX@0` ⇒
  `PciRoot(0x0)/Pci(0x1C,0x1)/Pci(0x0,0x0)` (aturan sama dengan `PciRoot(0x0)/Pci(0x2,0x0)` untuk iGPU)
- **Kenapa `01`**: kutipan asli Dortania, "OpenCore Post-Install · iServices" — `built-in` memakai tipe `Data` dengan nilai `01`;
  hasil uji: perangkat PCIe secara default semuanya `<00>` (= bukan built-in)
- Verifikasi: `ioreg -p IOService -l -w0 | grep -B30 '"IOName" = "pci14e4,43ba"' | grep built-in`

## 3. User space: OCLP root patch (kedua versi)

**Kenapa wajib ditambal**: hasil uji di sistem menunjukkan `/System/Library/Extensions/IO80211Family.kext` **adalah cangkang kosong**
(`IOKitPersonalities` dict kosong, bahkan `Contents/MacOS` tidak ada), dan `find -iname "*AirPortBrcm*"` di seluruh disk kosong
⇒ Apple menghapus driver Wi-Fi Broadcom seluruhnya di Sequoia. **Lapisan kernel** dipulihkan oleh kext yang di-inject di atas,
**framework user space** (`IO80211.framework` / `wifip2pd` / `WiFiPeerToPeer.framework`) wajib mengandalkan **root patch**.

```
1) ★ Jalankan skrip proteksi dulu (lihat §3.1)
2) Pasang OCLP (Sequoia pakai 2.5.1+; Tahoe pakai 3.0.0-rc.3+) — harus dipasang lewat .pkg
   (privileged-helper-nya mengandalkan SUID untuk elevasi, root patch bergantung pada ini)
3) Buka OpenCore-Patcher.app → Post-Install Root Patch → Start Root Patching
   Harus melihat "Networking: Modern Wireless" (OCLP mengenali lewat PCI 0x43BA, ada di daftar dukungan resmi)
4) Rebuild dyld shared cache bisa memakan 10–30 menit, jangan dihentikan → reboot
5) ★★ Setelah reboot pastikan **Wi-Fi adalah `en0`** (patch mengubah urutan mount driver, wireless bisa terdorong ke `en1`)
   ⇒ lihat `network-en0-order.md`
```

> ★★ **Kenapa langkah ini tidak boleh dilewati**: `en0` adalah "kartu jaringan utama" yang diakui Apple **iServices** —
> `ROM`, iMessage / FaceTime / App Store semuanya bergantung padanya.
> Setelah patch / ganti kartu, `en0` berpindah pemilik ⇒ semuanya bisa **gagal diam-diam**. Cara mengecek dan cara "mem-pin" lihat **`network-en0-order.md`**.
>
> ★ **AirDrop / Handoff / Continuity tidak termasuk dalam daftar ini** — syaratnya hanya "ada `awdl0` (stack native Broadcom) + Bluetooth BLE",
> sama sekali **tidak terkait** dengan `en0` / `ROM` / nomor seri / UUID. Jangan mengubah `ROM` demi AirDrop.
> Urutan pemeriksaan dan acuan otoritatif lihat **`airdrop-handoff.md`**.

### 3.1 ★★ Skrip proteksi wajib dijalankan sebelum menambal (kalau tidak, driver NVIDIA jadi tidak berfungsi)

OCLP sebelum menambal akan menjalankan `clean_auxiliary_kc()` (`sys_patch/kernelcache/kernel_collection/support.py`):

```python
for file in Path("/Library/Extensions").glob("*.kext"):
    if datetime.fromtimestamp(file.stat().st_mtime) < datetime(2021, 10, 1):
        # → dipindahkan ke /Library/Relocated Extensions
```

Sementara 4 kext NVIDIA NullMoth itu (`NVRM` / `NVAccel` / `NVRMFB` / `NVRMAGDC`) **mtime-nya epoch 0**
⇒ **akan dipindahkan ⇒ driver NVIDIA tidak berfungsi**.

**Penanganan**: jalankan skrip proteksi dulu, karena ia melakukan dua hal —
① mencadangkan seluruh `/Library/Extensions`; ② **`touch` direktori kext yang mtime-nya lebih tua dari 2021-10-01** dengan waktu sekarang
(**hanya mengubah timestamp, bukan isi**, tidak memengaruhi pemuatan). Setelah selesai, hasil pemeriksaan dicetak, lanjutkan hanya jika semuanya ✅.

Setelah patch selesai **wajib diperiksa ulang**:

```bash
ls -1 /Library/Extensions/*.kext                  # 4 kext NVIDIA masih ada
ls -1 "/Library/Relocated Extensions" 2>/dev/null # seharusnya kosong/tidak ada
```

## 4. Kriteria verifikasi

| Yang diperiksa | Harapan |
|---|---|
| `kmutil showloaded --list-only \| grep 80211` | 4 baris: `IOSkywalkFamily`, `corecapture`, `IO80211FamilyLegacy`, `AirPort.BrcmNIC` |
| Apakah driver terikat ke kartu di `ioreg` | `"IONameMatched" = "pci14e4,43ba"`, `"IOClass" = "AirPort_BrcmNIC"` |
| ★ Apakah Wi-Fi benar-benar hidup | **Lihat `ifconfig en1` (harus ada `inet` + `status: active`)**, atau `ioreg -n en1 -r -l -w0 \| grep -E "IO80211SSID\|IO80211BSSID\|IOControllerEnabled"` |
| AWDL (AirDrop/Handoff) | Ada **`awdl0`** (AirLink) dan **`llw0`** (LowLatency) di `ifconfig`, status UP/RUNNING |
| Bluetooth | `system_profiler SPBluetoothDataType` **langsung balas**; `Chipset: BCM_20703A2`, `Transport: USB` |
| Apakah deadlock Bluetooth sudah hilang | `log show --last 3m --predicate 'process == "bluetoothd"' \| grep -c "Couldn't find IOBluetoothHCIController"` = **0** |

> ★★ **Jangan hanya menilai hidup/matinya Wi-Fi dari `system_profiler SPAirPortDataType`**: setelah reboot driver harus membaca kartu, berasosiasi, DHCP,
> jadi butuh belasan detik untuk siap. Di mesin ini pernah muncul alarm palsu "saat verifikasi mengembalikan kosong ⇒ dikira gagal, padahal hanya belum inisialisasi".
> **`ifconfig en1` itulah kriteria kerasnya.**

## 5. Kode negara / laju: kapan `AirportBrcmFixup` baru dibutuhkan

| Situasi | Cara menangani |
|---|---|
| Sistem sudah otomatis menegosiasikan `IO80211CountryCode` yang benar (di mesin ini = `CN`, tabel kanal 1–13 / 36–64 / 149–165 persis sama dengan pembagian di Tiongkok) | **Jangan diubah** (interaksi manual hanya akan merugikan) |
| AP memakai kanal **100–140 (DFS)**, atau ingin menembus daya transmisi | Baru perlu `AirportBrcmFixup.kext` + `brcmfx-country=US` (atau HK/KR) |
| Laju tidak mencapai nilai teoretis | Cek dulu jumlah spatial stream milik AP: BCM43602 itu **3×3**, kalau AP cuma 2×2 maka hanya 2 stream (867 Mbps di mesin ini normal) |

## 6. Biaya dan rollback

| Item | Biaya |
|---|---|
| OCLP menggantikan `IOSkywalkFamily` | **Semua driver kartu jaringan DriverKit jadi tidak berfungsi** ⇒ Intel i225/i226 wajib memakai `AppleIGC.kext` (driver IOKit) |
| OCLP root patch | **Tidak bisa memakai OTA inkremental**; **setiap update sistem harus ditambal ulang** (dan tiap kali harus jalankan skrip proteksi di §3.1 dulu) |
| Menambahkan kembali kext Bluetooth/Wi-Fi | Boot jadi sedikit lebih lambat (dulu memblokir Bluetooth/Wi-Fi menghasilkan 137 s→91 s, sekarang sebagian harus dikembalikan) |
| Rollback | Cadangkan sebelum mengubah config + mengganti kext; cara di mesin ini adalah "skrip + `--revert`" + cadangan ganda di ESP/workspace |

## 7. Fakta terukur di mesin ini (bisa langsung dikutip)

| Item | Nilai |
|---|---|
| Kartu Wi-Fi | `(0x14E4, 0x16D)`, firmware `Broadcom BCM43xx 1.0 (7.77.111.1 AirPortDriverBrcmNIC-1772.1)` |
| Interface | `en1` (Infrastructure) + **`awdl0`** (AirLink) + **`llw0`** (LowLatency) |
| Laju/sinyal | 802.11ac / Ch36 (5 GHz, 80 MHz) / WPA2 / **867 Mbps** / MCS 9 / -36 dBm |
| Bluetooth | `BCM_20703A2`, Vendor `0x004C (Apple)`, FW `v76 c4290`, port USB **HS11** (`UsbConnector=255`) |
| Layanan Bluetooth yang didukung | HFP AVRCP A2DP HID Braille **LEA AACP GATT** SerialPort (tiga yang terakhir dibutuhkan Continuity) |
| `built-in` | `PciRoot(0x0)/Pci(0x1C,0x1)/Pci(0x0,0x0)` = `<01>` |
| Kode negara | `IO80211CountryCode = CN` (negosiasi otomatis benar, **tidak perlu** `AirportBrcmFixup`) |

### Jebakan lingkungan yang pernah dilewati

1. **zsh di mesin ini tidak punya `timeout`** (coreutils tidak terpasang) ⇒ `timeout N cmd` di dalam skrip akan **gagal diam-diam**,
   yang membuat "probe Bluetooth balas dalam 0 detik" berubah menjadi **hasil palsu**. Saat menulis skrip verifikasi, sertakan lapisan kompatibilitas timeout versi bash.
2. **`log show` tidak akan pernah jalan di dalam sandbox** (`log: Cannot run while sandboxed`) ⇒ diagnostik berbasis log harus lewat AppleScript dengan elevasi hak akses atau meminta pengguna menjalankannya manual.
3. **Nama node perangkat Wi-Fi bukan `ARPT`**, melainkan `AirPort_BrcmNIC` / `en1`; `ioreg -l -w0` tanpa filter mengeluarkan ratusan KB.
4. **Saat mengubah config, perhatikan jangan menabrak task lain**: di mesin ini pernah terjadi "sesi lain mengubah config yang sama" (inject iGPU + menghapus `-wegnoigpu`)
   ⇒ **wajib baca file live dan bandingkan diff**; kalau `NVRAM>Delete` memuat `boot-args`, nilai di file konfigurasi **akan menimpa nilai yang benar-benar berlaku pada reboot berikutnya**.
5. **Nomor disk EFI bisa bergeser**: dalam satu sesi yang sama, `diskutil list` sempat memberi dua nomor partisi EFI yang berbeda ⇒ selalu pakai UUID volume / cek ulang saat itu juga.
