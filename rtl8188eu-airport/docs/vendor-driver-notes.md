# Catatan Driver Vendor (Realtek) — sebagai *Oracle*, bukan sumber kode

Dokumen ini merangkum hasil inspeksi **read-only** terhadap stack Realtek yang terpasang
di mesin ini. Tujuannya: memahami perilaku yang harus kita tiru (dan memverifikasi
hasil porting kita) — **bukan** menyalin kode.

> ⚠️ Binary vendor bersifat **closed source** (lisensi tidak mengizinkan distribusi
> turunan). Lihat `docs/legal.md`. Yang boleh: membedah untuk memahami perilaku
> (interoperability), membandingkan hasil, dan menulis spesifikasi sendiri.

---

## 1. Komponen yang terpasang

| Komponen | Lokasi | Ukuran | Peran |
|---|---|---|---|
| `RtWlanU.kext` | `/Library/Extensions/RtWlanU.kext` | 11,7 MB (Mach-O, **tidak stripped**) | Driver kernel: USB, MAC, RF, firmware, EFUSE |
| `RtWlanU1827.kext` | `/Library/Extensions/` | — | Versi lama (v1827), salah satu yang aktif |
| `StatusBarApp.app` | `/Library/Application Support/WLAN/` | — | **Control plane**: menu bar, scan, join, EAPOL, profile |
| `com.realtek.utility.wifi/RtWlanHelper` | idem | — | Daemon pendukung (profile/socket) |
| `wpa_supplicant` | di dalam `StatusBarApp.app/Contents/MacOS/` | — | Supplicant 802.1X (corporate/WPA2-EAP) |
| Versi | `1830.32.b27`, build 19 Nov 2020, SDK macOS 10.9, Xcode 7.1.1 | | 6 tahun lalu |

## 2. Bentuk driver vendor

* Personality: `IOProviderClass = IOUSBInterface` (**stack USB legacy**), dengan
  `idVendor`/`idProduct` + `bConfigurationValue` + `bInterfaceNumber` per chipset.
  Ribuan entri personality (mencakup puluhan chipset Realtek).
* Class: `RtWlanU` (mencetak versi), `RtWlanDeviceU` (device), `RtWlanUserClientU`
  (user client untuk OID).
* Antarmuka jaringan: **`IOEthernetInterface`** (bukan `IO80211Interface`).
  → inilah alasan menu Wi-Fi macOS **tidak** muncul; Wi-Fi native Apple
  menyediakan `en0` dengan service order berbeda.
* **11.958 symbol** (tidak stripped) → RE statis jauh lebih mudah.

### Bukti simbol yang berguna (hasil `nm`)

```
_Array_MP_8188E_MUSB        → firmware 8188E (MUSB) tertanam sebagai array C di dalam binary
_ArrayLength_MP_8821C_FW_SPIC
__Z10_ReadEFuseP8_ADAPTERttPhh      → ReadEFuse(ADAPTER*, ...)
__Z13EFUSE_LoadMapP8_ADAPTERhPhh    → EFUSE_LoadMap(...)
__Z14_WriteFW_8188EP8_ADAPTERPvj    → WriteFW_8188E(...)
__Z13FW_FillH2CCmdP8_ADAPTERhjPh
```

Implikasi:
1. Firmware 8188E **tertanam di dalam kext**, bukan dibaca dari disk → pendekatan
   `urtwn` (upload `rtl8188eufw.bin`) berbeda, dan justru lebih bersih.
2. Fungsi EFUSE/firmware sudah jelas terbaca namanya → bagus untuk membandingkan
   dengan `rtwn_efuse_read()` & `urtwn_load_firmware()` hasil porting kita.

## 3. Pembagian tanggung jawab (penting!)

```
StatusBarApp (user space)          RtWlanU.kext (kernel)
─────────────────────────           ─────────────────────────
• scan & daftar SSID                • USB enumeration, bulk pipe
• join & profile Wi-Fi              • MAC/BB/RF init, firmware, EFUSE
• OID_* control plane                • frame TX/RX, encrypt/decap
• 4-way handshake (EAPOL)  ←→        • menerima/mengirim frame EAPOL
• wpa_supplicant (802.1X)
```

**Konsekuensi arsitektural untuk proyek kita:**
* WPA2-PSK di macOS **tidak** dikerjakan oleh driver — dikerjakan Apple (WCL/CoreWLAN).
  Driver hanya meneruskan frame EAPOL. Ini persis pola yang akan kita pakai
  (dibanding `AirportItlwm` yang juga tanpa supplicant).
* OID vendor (`OID_RT_SET_REG_BY_INF`, `OID_RT_SET_CHANNELPLAN`, `OID_RT_GET_RX_STATUS`,
  `OID_RT_NETWORK_STATUS`, `OID_ReceiveEAPOL`, `OID_SendtoProtPacket`, …) adalah ABI
  *user-space* milik vendor — **tidak** ada artinya bagi CoreWLAN.
  → Setiap OID harus dipetakan ke operation IO80211 yang standar.

## 4. Peta OID → operasi IO80211 (rencana)

| OID vendor (terlihat di `strings`) | Operasi IO80211 yang setara |
|---|---|
| `OID_RT_GET_CHANNEL_LIST` | `IO80211Interface::getChannelList` / scan |
| `OID_RT_SET_CHANNELPLAN` | `setChannel` (regdomain) |
| `OID_RT_NETWORK_STATUS` | `getLinkStatus` / `getPower` |
| `OID_RT_GET_RX_STATUS` (RSSI/noise) | `getRSSI` / `getNoise` |
| `OID_ReceiveEAPOL` | (internal) frame EAPOL masuk ke WCL |
| `OID_SendtoProtPacket` | frame keluar dari WCL |
| `OID_RT_SET_REG_BY_INF` | `setPower`/`setTxPower` |

## 5. Strategi verifikasi (driver vendor sebagai oracle)

| Yang diuji | Cara membandingkan |
|---|---|
| MAC address | Bandingkan MAC dari EFUSE kita vs MAC di router (DHCP lease) & label adapter |
| Chip ID | Log `rtwn_read_chipid()` kita vs ID yang ditampilkan `StatusBarApp` |
| RSSI | Scan dari driver kita vs nilai di UI aplikasi vendor |
| Channel plan | Bandingkan daftar channel |
| Stabilitas | 24 jam throughput di kedua driver |

## 6. Apa yang **tidak** kita ambil dari vendor

* ❌ Kode binary (tidak ada yang disalin)
* ❌ Firmware dari dalam binary vendor → ambil dari `linux-firmware`
* ❌ Mekanisme OID sebagai ABI → kita pakai IO80211 standar
* ❌ Struktur class `RtWlanU` → kita buat sendiri

## 7. Kalau nanti opting untuk "shim" (Opsi 3)

Paling tidak, shim berarti:
1. Menempel di atas `RtWlanU` (menjadi user client), **tetap** butuh `StatusBarApp`
   atau daemon pengganti untuk WPA2.
2. Mengimplementasikan `IO80211Controller` yang mem-proxy ke OID vendor.
3. Tetap memakai USB legacy stack & firmware tertanam di binary vendor.

Kesimpulan: shim **tidak** memberi hasil "native penuh" (tetap ada proses=user-space),
sulit dirawat, dan tidak kompatibel dengan update macOS.
→ Dipakai hanya bila proyek open-source mentok di M2/M3.
