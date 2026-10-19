# AirDrop / Handoff (Continuity) —— kenapa tidak bisa dipakai, dan bagaimana cara memeriksanya

> ★ **Posisi dokumen ini**: AirDrop / Handoff adalah **garis masalah yang terpisah dari `en0` / `ROM` / tiga kode**.
> Di skill sebelumnya hal ini dicampur ke dalam daftar "bergantung pada `en0`" di `network-en0-order.md`, **itu salah**,
> karena membuat arah troubleshooting mengarah ke `ROM`. Dokumen ini adalah **satu-satunya pintu keluar resmi untuk garis masalah itu**.
>
> Grading sumber (dokumen ini hanya memakai dua kelas pertama sebagai dasar, hasil uji mesin ini dipisah):
>
> | Kelas | Sumber |
> |---|---|
> | **Resmi Apple** | Continuity / persyaratan sistem AirDrop |
> | **Resmi driver** | FAQ itlwm (OpenIntelWireless), Dortania |
> | Uji mesin ini | output perintah, perbandingan `config.plist` dua EFI |

## 0. Satu kalimat

**Apakah AirDrop / Handoff bisa dipakai hanya bergantung pada satu hal: apakah kartu Wi-Fi berjalan di stack `IO80211Family` asli Broadcom sehingga menghasilkan `awdl0`.**

- **`itlwm.kext` (driver bergaya Ethernet untuk kartu Intel) ⇒ tidak pernah ada `awdl0` ⇒ AirDrop pasti tidak bisa dipakai**
  —— ini adalah keterbatasan pada level desain driver, bukan masalah konfigurasi, **tidak bisa diselamatkan dengan mengubah config apa pun**.
- **`ROM` / kepemilikan `en0` / model mesin / nomor seri / `SystemUUID` tidak ada hubungannya dengan AirDrop**, jangan telusuri ke sana.

## 1. Dasar otoritatif

### 1.1 Apple resmi: Continuity hanya butuh tiga hal

Dukungan Apple, "Memakai Continuity di antara perangkat Apple":

> Untuk memakai fitur "Continuity", silakan **masuk dengan Apple ID yang sama di semua perangkat**.
> Selain itu, perangkat Anda juga harus **mengaktifkan Wi-Fi dan Bluetooth** serta **memenuhi persyaratan sistem**.

—— **tidak perlu** `en0`, **tidak perlu** `ROM`, **tidak perlu** nomor seri / UUID.

Penemuan perangkat dan transfer peer-to-peer AirDrop berjalan lewat **Wi-Fi + Bluetooth**, dan kanal peer-to-peer di macOS adalah:

| Antarmuka | Nama lengkap | Peran |
|---|---|---|
| **`awdl0`** | Apple Wireless Direct Interface | kanal utama untuk AirDrop / Handoff / Sidecar |
| **`llw0`** | Low-Latency WLAN | kanal low-latency, tanpa itu Handoff tidak berjalan baik |

**AWDL adalah protokol privat Apple yang berjalan di dalam stack `IO80211Family`** ⇒ kalau driver tidak ada di stack ini, `awdl0` **mustahil** ada.

### 1.2 FAQ resmi itlwm: AirDrop jelas tidak didukung

`https://openintelwireless.github.io/itlwm/FAQ.html`

> **Limitation of `AirportItlwm.kext`**
> - **Handoff and Universal Clipboard are the only supported Continuity features.**

> **Does it support Apple's Continuity Framework (Airdrop, HandOff)**
> **Only *Handoff* and *Universal Clipboard* works with AirportItlwm, other features are not supported.**

> **Is it a replacement of natively supported Broadcom Cards**
> **No.**

Dan untuk `itlwm.kext` yang lebih dasar (bukan `AirportItlwm`):

> `itlwm.kext` uses Apple's public **IOEthernetController instead of the private IO80211Family**.
> `AirportItlwm` enables the native Wi-Fi selection menu with limited continuity features.

⇒ `itlwm.kext` **menyamarikan kartu Wi-Fi sebagai kartu Ethernet**, sama sekali tidak masuk ke `IO80211Family`, jadi **tidak menghasilkan `awdl0`**.
⇒ Bahkan dengan `AirportItlwm`, yang tersedia hanya "Handoff + clipboard universal", **AirDrop tetap tidak didukung**.

### 1.3 Dortania: `en0` / `ROM` hanya untuk iServices, dan **tidak terkait jenis antarmuka**

`https://dortania.github.io/OpenCore-Post-Install/universal/iservices.html`

Seluruh judul dokumennya adalah **"Fixing iMessage and other services"**, pembicaraannya iMessage / FaceTime / iCloud / App Store seluruhnya,
**tidak ada satu pun menyebut AirDrop atau Handoff**. Untuk jenis `en0`, kutipan aslinya:

> **Note**: `en0` can be either Wifi, ethernet or even Thunderbolt. **The type doesn't matter**,
> just that it's present and marked as built-in.

⇒ **`en0` yang berupa Ethernet sepenuhnya sah** (di mesin ini `en0` = Intel I225-V, Wi-Fi adalah `en1`)⇒ **tidak memengaruhi AirDrop**.

## 2. Urutan troubleshooting (menurut rantai ketergantungan otoritatif, dari murah ke mahal)

| Urutan | Yang diperiksa | Perintah | Harapan / penjelasan |
|---|---|---|---|
| 1 | **`awdl0` ada dan RUNNING** | `ifconfig awdl0` | `flags=8843<UP,BROADCAST,RUNNING,…>`; **kalau tidak ada ⇒ langsung lihat langkah 2** (akar masalah paling sering) |
| 2 | **driver mana yang dipakai Wi-Fi** | `kmutil showloaded --list-only \| grep -i 80211`<br>`ioreg -l \| grep -i IO80211`<br>lihat `Kernel > Add` | harus **stack asli Broadcom** (`IOSkywalkFamily` + `IO80211FamilyLegacy` + `AirPortBrcmNIC`); **`itlwm.kext` jelas tidak bisa** |
| 3 | apakah `llw0` ada | `ifconfig llw0` | `flags=8863<…SMART,RUNNING…>`; tanpa itu Handoff tidak berjalan baik |
| 4 | apakah AirDrop didukung | `system_profiler SPAirPortDataType \| grep AirDrop` | `AirDrop: Supported`; kalau tidak, periksa kode negara / apakah kartu terdeteksi |
| 5 | layanan Bluetooth BLE | `system_profiler SPBluetoothDataType \| grep "Supported services"` | harus ada **`LEA` / `AACP` / `GATT`** (dibutuhkan Continuity); kalau tidak ada ⇒ masalah driver Bluetooth |
| 6 | apakah ada dua Bluetooth controller | `ioreg -p IOUSB -w0 -l \| grep -i bluetooth` | kartu Intel asli tidak dicabut / tidak dinonaktifkan ⇒ macOS menjadi bingung |
| 7 | sakelar sistem | Pengaturan Sistem → Umum → AirDrop & Handoff | sakelar Handoff, visibilitas AirDrop |
| 8 | Apple ID | apakah kedua perangkat memakai akun yang sama | persyaratan pertama dari Apple resmi |

> ★★ **Disiplin kriteria**: `system_profiler SPAirPortDataType` baru akurat **belasan detik setelah restart**,
> **jangan memakainya untuk menilai apakah Wi-Fi hidup atau mati**; `ifconfig awdl0` / `ifconfig enX` baru kriteria keras
> (lihat `broadcom-wifi.md` §4).

## 3. Empat salah paham yang umum (sudah diverifikasi semuanya salah)

| Salah paham | Kenapa salah |
|---|---|
| **"`ROM` harus berupa MAC Wi-Fi asli, kalau tidak AirDrop rusak"** | `ROM` adalah syarat **iServices** Dortania (iMessage / FaceTime / App Store), sementara **Apple resmi hanya mensyaratkan Apple ID + Wi-Fi + Bluetooth untuk Continuity**. Teruji: saat `ROM` dan `en0` tidak konsisten, AirDrop **tetap bisa dipakai** |
| **"Continuity / AirDrop bergantung pada `en0`"** | Sama seperti di atas. Teks asli Dortania *"The type doesn't matter"*, dan tidak menyebut AirDrop sama sekali |
| **"`SystemUUID` / `IOPlatformUUID` tidak konsisten membuat AirDrop rusak"** | Buktinya sangat langsung: `config SystemUUID` dan `IOPlatformUUID` di mesin ini **sampai sekarang masih tidak konsisten** (dan berubah antar boot), sementara AirDrop **teruji bisa dipakai** ⇒ bukan faktor, **jangan mengubah UUID demi AirDrop** |
| **"Model mesin / nomor seri salah membuat AirDrop rusak"** | Tidak ada dasar. Yang dipengaruhi nomor seri adalah iServices dan "Tentang Mac Ini" |

> ★ **Jangan mengubah `ROM` demi "sesuai kaidah"** —— itu menuntut harga "membangun ulang `ByHost` + autentikasi ulang",
> dan mungkin merusak iServices yang tadinya normal. Lihat `smbios-and-serials.md` §6.1.

## 4. Prinsip pemilihan kartu (satu kalimat)

> **Mau AirDrop / Handoff ⇒ harus memakai kartu yang didukung asli oleh Broadcom** (seperti BCM43602 / BCM94360CDP).
> **Kartu Intel, baik `itlwm` maupun `AirportItlwm`, tidak akan pernah mendapat AirDrop**;
> **jalur pihak ketiga MediaTek (`SimpleMtkWlan`) secara desain tidak mungkin** (lihat `mediatek-wifi.md` §4.1).

| Kartu | AirDrop | Dasar |
|---|---|---|
| Broadcom (stack asli + OCLP root patch) | ✅ | ada `awdl0` / `llw0` |
| Intel + `AirportItlwm` | ❌ (hanya Handoff / clipboard universal) | FAQ resmi itlwm |
| Intel + `itlwm.kext` | ❌ (tidak sampai masuk `IO80211Family`) | sama seperti di atas |
| Kext pihak ketiga MediaTek | ❌ ("not possible with this design") | `mediatek-wifi.md` §4.1 |

## 5. Uji mesin ini (Z690 / i7-12700K / macOS 26.7.1 / BCM43602 + BCM20703)

| Item | Nilai |
|---|---|
| `awdl0` | `flags=8843<UP,BROADCAST,RUNNING,…>` ✅ |
| `llw0` | `flags=8863<UP,BROADCAST,SMART,RUNNING,…>` ✅ |
| AirDrop | `Supported` ✅ |
| Layanan Bluetooth | `HFP AVRCP A2DP HID Braille LEA AACP GATT SerialPort` ✅ |
| `en0` | **Ethernet** `Intel I225-V` (built-in ✅)—— nirkabel adalah `en1` |
| Driver nirkabel | `AirPortBrcmNIC-Tahoe.kext` (`MinKernel 25.0.0`) |
| Driver yang dimuat | `com.apple.driver.AirPort.BrcmNIC (1400.1.1)` —— **hanya dari EFI**, di system volume tidak ada satupun |

### 5.1 Satu kasus pembalik: kenapa AirDrop rusak saat memakai USB EFI

| | USB EFI | EFI disk internal |
|---|---|---|
| Driver nirkabel | **`itlwm.kext`** (Intel, lewat `IOEthernetController`) | **`AirPortBrcmNIC-Tahoe.kext`** (Broadcom, lewat `IO80211Family`) |
| `DeviceProperties:Add` | **0 entri** (bahkan `built-in` pun tidak ada) | 3 entri (termasuk node Wi-Fi `built-in=<01>`) |
| Bluetooth | `IntelBluetoothFirmware` + `BlueToolFixup` | `BlueToolFixup` |
| Hasil | tidak ada `awdl0` ⇒ **AirDrop / Handoff tidak bisa dipakai** | `awdl0` + `llw0` RUNNING ⇒ **bisa dipakai** |

★ Detail penting: saat boot dari USB, **koneksinya lewat kabel (`AppleIGC.kext` + I225-V)**, sehingga kesan penggunanya adalah
"bisa accessing internet, tapi AirDrop / Handoff tidak bisa dipakai"——**sangat cocok dengan "Wi-Fi-nya praktis tidak ada"**, sehingga mudah disalahartikan sebagai "Wi-Fi normal tapi AirDrop rusak".

★ Item lain yang mudah tertukar: `brcmfx-country=#a` **hanya memengaruhi kanal yang bisa dipakai**, tidak memengaruhi apakah `awdl0` ada.

## 6. Dokumen terkait

- `broadcom-wifi.md` —— konfigurasi lengkap kartu Broadcom (prasyarat `awdl0` adalah stack ini aktif)
- `intel-wifi.md` —— batas kemampuan kartu Intel (teks asli FAQ)
- `mediatek-wifi.md` —— batas keras jalur pihak ketiga MediaTek
- `network-en0-order.md` —— **hanya gestionar kepemilikan `en0` dan iServices**, tidak ada hubungannya dengan AirDrop
