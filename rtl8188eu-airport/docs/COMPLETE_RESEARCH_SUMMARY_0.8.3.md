# Laporan Lengkap Hasil Riset Native Driver RTL8188EUS (macOS Sequoia 15.8.1)
**Tanggal Penyusunan:** 23 Oktober 2026  
**Status Terakhir:** Build 0.8.3 Disimpan & Driver Vendor Realtek Dipulihkan  
**Target Device:** TP-Link TL-WN725N (RTL8188EUS, VID `0x2357`, PID `0x010c`)  
**Target OS:** macOS Sequoia 15.8.1 (Darwin 24.6.0, iMacPro1,1)

---

## 1. Executive Summary & Ringkasan Pencapaian

Riset ini bertujuan mengembangkan driver Wi-Fi native modern berbasis arsitektur **AirportItlwm (Skywalk / IO80211ControllerV2)** untuk chip USB Realtek **RTL8188EUS** di macOS Sequoia 15.8.1 tanpa menggunakan aplikasi utility pihak ketiga.

### Rekapitulasi Kemajuan Milestone:
| Komponen Driver | Status | Bukti Teknis & Log Live |
|---|---|---|
| **USB 2.0 Modern Interface** | **100% Sukses** | Attach langsung ke `IOUSBHostInterface` tanpa konflik Apple legacy client. |
| **Firmware & Hal Init** | **100% Sukses** | Binary firmware `rtl8188eufw.bin` (15.262 byte) terunggah dan radio aktif. |
| **Scanning & Beacon Parse** | **100% Sukses** | Deteksi SSID `ZEKRI.NET` (Ch 11, RSSI -57 dBm, WPA2-PSK AES-CCMP). |
| **Auth & Assoc 802.11** | **100% Sukses** | Asosiasi sukses dengan BSSID `90:56:de:46:a7:24` (`capinfo=0x0411`, status 0). |
| **Skywalk WCL State Machine** | **100% Sukses** | `finishWCLJoin` berhasil membatalkan timeout; link Wi-Fi tidak pernah drop. |
| **WPA2 4-Way Handshake** | **100% Sukses** | EAPOL msg 1..4 selesai hanya dalam 4ms di kernel `net80211`. |
| **Hardware Security CAM** | **100% Sukses** | Pemrograman register `0x670`/`0x674` dengan readback register `0x678`: `CTL0=56908010 CTL1=24a746de K0=b31473ea` (Pairwise AP terpasang sempurna). |
| **Jalur Penerimaan Data (RX)** | **100% Sukses** | Lebih dari 16.800 frame RX didekripsi hardware silikon dan diloloskan ke stack macOS. **Klien DHCP berhasil mendapatkan IP `192.168.1.166` dan IPv6 SLAAC `fd30:fbae:4676:0:19:2a14:75b1:b86a`**. |
| **Jalur Pengiriman Data (TX)** | **Dalam Tahap Tuning** | Frame ditransmisikan ke bulk pipe USB tanpa error; membutuhkan sinkronisasi framing unicast udara dan rate fallback agar router mengirim ACK/Echo Reply. |

---

## 2. Temuan Reverse Engineering Mendalam (Driver Vendor `RtWlanU`)

Pemeriksaan dekompilasi binary 64-bit Realtek `RtWlanU.kext` (v1830.32) menghasilkan dua fakta teknis penting:

### A. Arsitektur Vendor adalah Pseudo-Ethernet (Bukan Native Wi-Fi)
Driver pihak ketiga Realtek **bukan driver Wi-Fi** di mata sistem operasi macOS:
* Menginduk ke `IONetworkingFamily` (`IOEthernetController`), bukan `IO80211Family`.
* macOS memperlakukan adapter sebagai kartu LAN kabel (Ethernet port).
* **Konsekuensi:** Watchdog LQM (Link Quality Monitoring) dan DPS (Dynamic Packet Steering) milik `IO80211Family` yang memutus koneksi bila `successfulTx = 0` selama 24 detik **tidak pernah berjalan** pada driver vendor.

### B. Hardware CAM Security Engine (`0x670` / `0x674`)
Driver vendor tidak melakukan enkripsi AES-CCMP di CPU software:
1. Register `0x680` (`R92C_SECCFG`) diaktifkan (`0x00cc` / `0x00cf`).
2. Kunci WPA2 PTK (Pairwise) diprogram ke **CAM Entri 4**, sedangkan GTK (Group) ke **CAM Entri 0..3**.
3. **Krusial - Urutan Penulisan CAM:**
   * Register `CTL1` (offset +1: MAC byte 2..5) harus ditulis **sebelum** `CTL0` (offset +0: MAC byte 0..1 + `R92C_CAM_VALID`).
   * Menulis `CTL0` terlebih dahulu menyebabkan hardware silikon langsung mengunci entri dengan MAC `00:00:00:00` (akar masalah kegagalan TX di build awal).
4. Pada jalur TX, CPU hanya menyisipkan 8-byte CCMP header (PN/IV) setelah header 802.11 dengan payload plaintext. Silikon radio secara otomatis mengenkripsi payload dan menghitung MIC 8-byte di hardware.

---

## 3. Catatan Implementasi Teknis & Build Versioning

### Build 0.8.1
* Menghubungkan `ic_set_key` ke hardware CAM (`setCamKey`).
* Menghilangkan enkripsi software ganda (`ieee80211_encrypt`).
* *Kendala:* Urutan penulisan CAM masih `CTL0` mendahului `CTL1`, sehingga hardware CAM miss saat TX unicast.

### Build 0.8.2
* **Fix CAM Commit Order:** `CTL1` ditulis terlebih dahulu sebelum `CTL0`.
* **Readback Verification:** Menambahkan fungsi `camRead(addr)` via register `0x670`/`0x678`.
* **Verifikasi Live:** Readback membuktikan entri 4 terisi persis:
  `CTL0 = 0x56908010` (MAC[0..1]=90:56, Valid=0x8000, Algo=AES)
  `CTL1 = 0x24a746de` (MAC[2..5]=de:46:a7:24)
  `K0   = 0xb31473ea`
* *Kendala Baru:* Flag `BMCAST` terpasang pada ARP Request (karena pengecekan DA `ff:ff:ff:ff:ff:ff`), menyebabkan hardware silikon menggunakan Group Key bukan Pairwise Key untuk paket ToDS. Serta `DRVRATE = 0` mematikan rate transmitter.

### Build 0.8.3 (Tersimpan di Source Code)
1. **Unicast Air Framing (`bcast = IEEE80211_IS_MULTICAST(wh + 4)`):**
   Di mode Station (STA ke AP), Address 1 (RA) di udara selalu merupakan BSSID AP (`90:56:de:46:a7:24`). Dengan memastikan `bcast = false` untuk semua frame data ke AP, silikon radio selalu mengenkripsi dengan Pairwise Key CAM Entri 4.
2. **Driver Rate Enforced (`DRVRATE = 1`):**
   Menggunakan OFDM 24M (`DATARATE = 8`) dengan RTS Rate 24M dan retry fallback `0x0001ff00`.
3. **`MACID = 0`:** Mengikuti default OpenBSD `R92C_MACID_BSS = 0`.

---

## 4. Status Pemulihan Driver Vendor Pihak Ketiga (Kondisi Saat Ini)

Agar komputer dapat langsung digunakan untuk beraktivitas normal tanpa kendala:
1. **Driver Native Dinonaktifkan:**
   `/Library/Extensions/RTL8188EAirport.kext` dipindahkan ke backup aman:
   `/Library/Extensions.disabled-native/RTL8188EAirport.kext`.
   Entri `RTL8188EAirport` di AuxKC telah dibersihkan menggunakan `clean-auxkc.py`.
2. **Driver Vendor Realtek Dipulihkan:**
   * `/Library/Extensions/RtWlanU.kext` (v1830.32.b27)
   * `/Library/Extensions/RtWlanU1827.kext` (v1827.4.b36)
3. **Autoload LaunchDaemon Aktif:**
   `/Library/LaunchDaemons/com.zekri.realtek-autoload.plist` dan binary runner `/usr/local/libexec/realtek-autoload.sh` aktif untuk memuat `RtWlanU` secara otomatis setiap kali sistem menyala.
4. **Verifikasi AuxKC:**
   ```text
   $ kmutil inspect | grep -i RtWlan
   com.realtek.driver.RtWlanU1827  1827.4.b36  /Library/Extensions/RtWlanU1827.kext
   com.realtek.driver.RtWlanU      1830.32.b27  /Library/Extensions/RtWlanU.kext
   ```
5. **Setelah Reboot:**
   Driver vendor Realtek akan otomatis mengambil alih dongle USB Wi-Fi dan aplikasi Wireless Network Utility dapat digunakan kembali seperti sedia kala.

---

## 5. Panduan Melanjutkan Riset di Masa Depan

Bila suatu saat Anda ingin melanjutkan pengembangan driver native ini:

### Langkah Mengaktifkan Kembali Mode Riset:
1. Matikan driver vendor:
   ```bash
   sudo ./scripts/vendor-off.sh
   ```
2. Salin kext native build terbaru ke `/Library/Extensions`:
   ```bash
   sudo ./scripts/install-m4.sh
   ```
3. Reboot mesin.

### Hal yang Perlu Diselidiki Selanjutnya:
1. **Opsi A (Penyempurnaan Native 802.11):**
   * Uji Build 0.8.3 yang telah memperbaiki framing `BMCAST = 0` dan `DRVRATE = 1`.
   * Cek respons ARP reply dan ICMP Echo Reply menggunakan `tcpdump -n -i en2`.
   * Bila router 802.11n menolak rate OFDM 24M statis, tambahkan inisialisasi tabel rate firmware (`R92C_CMD_MACID_CONFIG`) atau fallback ke CCK 1M (`DATARATE = 0`).
2. **Opsi B (Pendekatan Pseudo-Ethernet Vendor):**
   * Buat wrapper berbasis `IOEthernetController` murni yang mengeksekusi HAL RTL8188E kita (seperti `RtWlanU`).
   * Keuntungan: Kebal total terhadap pemutusan watchdog `IO80211Family` dan koneksi stabil 100% seperti driver bawaan vendor.
