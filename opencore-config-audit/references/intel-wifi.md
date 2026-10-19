# Cara memasang driver kartu jaringan nirkabel Intel (AirportItlwm / itlwm)

> Upstream: `OpenIntelWireless/itlwm` (zxystd dan lainnya).
> Fork yang dirujuk di sini: **`laobamac/itlwm`** (<https://github.com/laobamac/itlwm>) —
> fork tersebut menyediakan build `AirportItlwm` terpisah untuk **macOS Sequoia 15.2+** dan **macOS 26 Tahoe**.
> Di bawah ini, "pendapat resmi" = kalimat asli README fork tersebut, "cara umum" = langkah injeksi yang biasa di OpenCore.

## 0. Bedakan dulu dua bentuk ini

| Bentuk | Perilaku | Persyaratan versi |
|---|---|---|
| **`AirportItlwm`** | Wi-Fi **asli**: muncul di menu Wi-Fi sistem, tidak memerlukan klien tambahan | **Harus memakai build yang cocok dengan versi macOS** (ABI tiap macOS berbeda) |
| `itlwm` | Lewat ioctl, memerlukan klien user-space (HeliPort) untuk memindai/terhubung | Kompatibilitas lintas versi cukup baik |

Fork ini menyediakan **`AirportItlwm`** (target Sequoia + target Tahoe), tidak ada penjelasan mengenai bentuk `itlwm` di README.

## 1. Pendapat resmi (poin utama README laobamac/itlwm)

**Garis versi (★ paling penting)**

- Target `AirportItlwm-Sequoia`: **macOS Sequoia 15.2 dan setelahnya**, x86_64; teruji pada macOS 15.8 (24H23)
- Target `AirportItlwm-Tahoe`: **macOS 26.x (Darwin 25.x)**
- ★ Kalimat asli: *"Sequoia and Tahoe use separate ABI headers and build products."*
  → *"Use this kext only on Darwin 24.2.0–24.99.99. Keep the Tahoe kext restricted to Darwin 25.x when both systems share an OpenCore configuration."*
  ⇒ **Saat dua sistem berbagi satu konfigurasi OpenCore, wajib menggunakan `MinKernel`/`MaxKernel` untuk membatasi masing-masing kext pada versi Darwin-nya masing-masing**, jika tidak yang termuat adalah yang salah

**Kemampuan dan batasan di macOS 26**

- Wi-Fi 6 (802.11ax / HE) **nonaktif secara default**; tambahkan boot-arg **`itlwm_he=1`** untuk mengaktifkannya pada kartu jaringan yang mendukung
- Didukung: WPA2-Personal, jaringan transisi WPA2/WPA3 (termasuk PMF opsional), pemindaian / penyambungan / pergantian jaringan / alamat Wi-Fi privat
- **Tidak didukung**: WPA3-only, PMF paksa, **AWDL / AirDrop**, MLO
- Perangkat mengikuti tabel hardware upstream; **kompatibilitas Tahoe masih perlu diverifikasi per kartu jaringan**

**Unduhan dan build**

- Ambil build **Release** dan **Debug** untuk Sequoia / Tahoe dari **Releases milik fork itu sendiri**
- Build sendiri: pasang Xcode + Python 3, check out `MacKernelSDK` ke `MacKernelSDK/` (README menetapkan commit `3f750085caa17ec3a7880f11c11bf4f48cd6a164`)

```bash
# Tahoe (macOS 26)
xcodebuild -project itlwm.xcodeproj -scheme AirportItlwm-Tahoe \
  -configuration Release ARCHS=x86_64 CODE_SIGNING_ALLOWED=NO build
# Sequoia (macOS 15.2+)
xcodebuild -project itlwm.xcodeproj -scheme AirportItlwm-Sequoia \
  -configuration Release ARCHS=x86_64 CODE_SIGNING_ALLOWED=NO build
```

- Dokumen upstream (Intro / Compatibility / FAQ): <https://OpenIntelWireless.github.io/itlwm>

## 2. Memasang ke dalam OpenCore (cara umum)

1. Letakkan `AirportItlwm.kext` di `EFI/OC/Kexts/`
2. Tambahkan entri di `Kernel → Add`, **wajib berada setelah `Lilu.kext`** (Lilu adalah host)
3. **Batasi versi Darwin dengan `MinKernel` / `MaxKernel`** (lihat §1): untuk versi Sequoia isi `MinKernel=24.2.0` / `MaxKernel=24.99.99`; untuk versi Tahoe isi `MinKernel=25.0.0`. Gunakan `uname -r` untuk mengecek versi Darwin saat ini
4. Saat membutuhkan Wi-Fi 6, tambahkan boot-args `itlwm_he=1`
5. `Misc → Security → SecureBootModel = Disabled` (kext pihak ketiga tidak ditandatangani Apple); longgarkan SIP sesuai kebutuhan
6. Verifikasi setelah restart:

```bash
kmutil showloaded --list-only | grep -i itlwm          # apakah kext termuat
system_profiler SPAirPortDataType | head -30           # apakah interface Wi-Fi muncul
networksetup -listallhardwareports                    # apakah ada port Wi-Fi (en0/en1)
```

## 3. Bluetooth Intel harus dipasang terpisah (jangan dicampur)

**Bluetooth** pada kartu jaringan nirkabel Intel **tidak ditangani** oleh itlwm, dibutuhkan:

| kext | Fungsi |
|---|---|
| `IntelBluetoothFirmware` | Memuat firmware ke controller Bluetooth Intel |
| `IntelBTPatcher` | Patch (umum pada macOS versi baru) |
| `BlueToolFixup` | Memperbaiki Bluetooth stack (pada macOS versi baru sering dipakai bersama kedua kext di atas) |

> Bandingkan: kartu Broadcom memakai rangkaian lain (`BrcmPatchRAM*` / `BlueToolFixup` + stack `IO80211` bawaan sistem).

## 4. Troubleshooting

| Gejala | Yang diperiksa |
|---|---|
| Wi-Fi sama sekali tidak muncul di sistem | Apakah `Lilu` termuat, urutan `Kernel → Add` apakah Lilu di depan, apakah kext **cocok dengan ABI** macOS saat ini (jangan salah pasang Sequoia/Tahoe) |
| kext termuat tapi tidak ada interface | Apakah `MinKernel`/`MaxKernel` mengecualikan Darwin saat ini (`uname -r`); apakah ada interface di `system_profiler SPAirPortDataType` |
| Bisa connect 2.4G tetapi tidak ke 5G / connect sangat lambat | Apakah HE sudah dinyalakan (`itlwm_he=1`), apakah kanal/enkripsi berada dalam daftar yang didukung (WPA3-only dan PMF paksa **tidak didukung**) |
| AirDrop / Handoff tidak tersedia | **Diketahui tidak didukung, jangan dianggap kegagalan**. Kalimat asli FAQ resmi: *"Only **Handoff** and **Universal Clipboard** works with AirportItlwm, **other features are not supported**"*; `itlwm.kext` bahkan lebih parah — memakai `IOEthernetController` dan bukan `IO80211Family` ⇒ **tidak ada `awdl0`**. Dasar lengkapnya ada di `airdrop-handoff.md` §1.2 |
| Bluetooth rusak setelah pemasangan | Bluetooth adalah rangkaian kext lain (§3), pastikan dulu status ketiga kext tersebut |

## 5. Hubungannya dengan "ganti kartu jaringan" (penting)

Setelah mengganti kartu jaringan Intel (misalnya ke Broadcom BCM943602CDP):

- **Wajib** menonaktifkan atau menghapus ketiga kext nirkabel/Bluetooth Intel dari `Kernel → Add`, dan menghapus file di `EFI/OC/Kexts/` — jika tidak, mereka tetap mencoba mencocokkan perangkat yang tidak ada (muat sia-sia, log jadi bising, pada versi tertentu juga bisa mengganggu Bluetooth stack)
- Sebelum menghapus, backup aslinya dulu; cara menilai "apakah memang tidak dipakai" ada di kriteria penghapusan di `disks-and-kexts.md`
- ★★ **Setelah ganti kartu, pastikan kepemilikan `en0`** — kernel memberi nomor `en` berdasarkan **urutan pemuatan driver** (tidak terkait urutan PCI),
  ganti kartu / menambah atau menghapus driver bisa membuat `en0` berganti ⇒ **lihat `network-en0-order.md`** (termasuk "cara memaku nirkabel ke `en0`" dan dampaknya)

> **Jangan menyuntikkan beberapa set driver kartu jaringan sekaligus pada mesin yang sama**. Selain Intel / Broadcom, untuk MediaTek (MT7921 / MT7922 / RZ608) lihat
> `mediatek-wifi.md` — kesimpulannya di sana adalah "**Bluetooth bisa dipakai, Wi-Fi masih eksperimental, mau stabil maka ganti kartu**".

## 6. Peringatan keamanan

- Kext pihak ketiga (tidak ditandatangani Apple) ⇒ butuh `SecureBootModel=Disabled`, SIP dilonggarkan bila perlu. **Lakukan ini hanya bila Anda memang akan memakai kartu jaringan tersebut**
- Saat mengunduh dari Releases fork, perhatikan sumber repositori dan hash file; upstream adalah `OpenIntelWireless/itlwm`, sedangkan fork ini adalah cabang yang dipelihara secara pribadi, **dukungan Tahoe masih berstatus "perlu diverifikasi per kartu jaringan"**
