# Rencana Perbaikan — dari "bisa konek" ke "seperti native"

> Status awal: 23 Okt 2026, 06:30 WIB. Berdasarkan audit langsung ke mesin
> (bukan hanya dokumen): kext `RTL8188EAirport 0.4.0` loaded, `en2` terdaftar
> sebagai Wi-Fi, scan + beacon + asosiasi WPA2 sempat jalan, tetapi DHCP gagal
> (`no server`) dan `airportd` menganggap link tidak terasosiasi.

---

## 0. Jawaban singkat: bisa, tapi dengan batas yang jelas

**Bisa** untuk: menu Wi-Fi native, scan, join WPA2-PSK, DHCP, internet,
reconnect otomatis, sleep/wake, unload bersih.

**Tidak bisa** (batas chipset + stack, bukan kurang kerja):
- **AirDrop / Handoff / Continuity / AWDL** — butuh `awdl0` dari stack Broadcom
  native. `urtwn`/net80211 tidak punya AWDL. Project AirportItlwm (Intel) pun
  tidak punya.
- **5 GHz, 802.11ac, >150 Mbps** — RTL8188EU hanya 2,4 GHz 1×1 802.11n.
- **WPA3-SAE** — bisa ditambah nanti, tapi bukan target "native normal".

Target realistis throughput: **40–70 Mbps** (2,4 GHz, 20 MHz, 1 stream).

---

## 1. Prinsip: keluarkan reboot dari loop

Sumber masalah "reboot terus" bukan driver-nya, tapi **cara memasangnya**:
kext eksperimental diinjeksi dari ESP, jadi setiap binary baru butuh boot baru.

Tiga lapis, dipakai berurutan. Naik ke lapis berikutnya hanya kalau lapis
sebelumnya lulus.

### Lapis 1 — userspace lab (0 reboot, 0 risiko panic)

`tools/rtwn_probe` sudah memakai **kode yang sama** dengan kernel
(`rtwn_seq.c`, `rtwn_init_8188e.c`, `rtwn_usb.c`) dan sudah terbukti bisa
power-on, baca EFUSE, set kanal, kirim probe request, terima beacon.

Yang perlu ditambah supaya bisa memvalidasi **jalur data** (inti masalah sekarang):

| Perintah baru | Fungsi | Membuktikan |
|---|---|---|
| `--auth <bssid>` | kirim auth open | TX mgmt ke AP nyata |
| `--assoc <bssid> <ssid>` | assoc open | state machine + rate |
| `--txraw <hex>` | kirim 1 frame data mentah | descriptor data benar |
| `--join <ssid> [--psk <pass>]` | auth+assoc+4-way (WPA2) | jalur CCMP |
| `--dhcp` | DHCPDISCOVER → tunggu OFFER | **TX data tembus** |

Kalau `--dhcp` dapat OFFER di userspace, jalur data sudah benar secara
protokol; sisanya hanya memindahkan kode yang sama ke kernel. Kalau belum,
tidak ada gunanya hot-load.

### Lapis 2 — hot-load kext (0 reboot, risiko panic kecil)

```bash
./scripts/build-m4.sh
# cabut dongle → tidak ada instance yang menahan kext
sudo kmutil load -z -p src/driver/build-m4/RTL8188EAirport.kext
# colok dongle → attach → interface muncul
./scripts/check-m4.sh
# selesai: cabut dongle, lalu
sudo kmutil unload -b io.github.zekri.RTL8188EAirport
```

Syarat: **kext TIDAK boleh ada di ESP** selama iterasi. Kalau masih diinjeksi
OpenCore, binary terkunci di kernel sejak boot dan satu-satunya cara mengganti
adalah reboot.

Karena itu langkah pertama yang harus dilakukan:

```bash
sudo ./scripts/restore-test-esp.sh    # ESP kembali aman (vendor Realtek aktif)
```

Setelah itu mesin tidak pernah lagi bergantung pada build eksperimental saat
boot. Kalau kext panic, cukup reboot sekali — bukan setiap iterasi.

### Lapis 3 — satu reboot = satu laporan lengkap

Kalau memang harus uji jalur boot (mis. perilaku saat init), satu boot harus
menghasilkan **semua** data. Tambahkan `scripts/collect-m4.sh`:

```bash
kextstat | grep RTL8188E
ioreg -l -w0 | grep RTL8188E-
netstat -I en2 -b
ifconfig en2
ipconfig getsummary en2
networksetup -listallhardwareports
networksetup -getairportnetwork en2
ls -t /Library/Logs/DiagnosticReports/*.panic | head -3
```

Output ke `logs/m4-<timestamp>.txt`. Satu reboot, satu file, tidak ada
"kurang data → reboot lagi".

---

## 2. Daftar perbaikan

Prioritas: **P0 = memblokir fungsi dasar**, **P1 = bikin tidak nyaman**,
**P2 = polish**.

### F0 — Infrastruktur (kerjakan dulu, tanpa reboot)

| # | Item | Kenapa | Status | Verifikasi |
|---|---|---|---|---|
| F0.1 | `scripts/dev-loop-m4.sh` (build → hot-load → replug → test → unload) | menghapus reboot dari loop | ❌ **TIDAK BERLAKU** — lihat catatan di bawah | — |
| F0.2 | `rtwn_probe --join/--txnull` (auth + assoc + uji TX data) | validasi TX data tanpa kernel | ✅ dibuat, uji frame lulus | `--join <ssid> --txnull` → ada TX report |
| F0.3 | `scripts/collect-m4.sh` | satu boot = semua bukti | ✅ dibuat | `logs/m4-<ts>.txt` lengkap |
| F0.4 | Keluarkan build eksperimental dari ESP | boot selalu aman | ✅ ESP bersih (11 kext standar, `Kernel->Add` 12 → 11) | reboot → `kextstat` tidak ada RTL8188E |
| F0.5 | Boot loader tanpa ESP (LaunchDaemon) | kext otomatis saat boot tanpa mengunci ESP | ❌ **TIDAK BERLAKU** — sudah dicabut | — |

> **⚠️ Koreksi 23 Okt 07:00 — hot-load tidak mungkin untuk kext ini.**
> `kmutil load -z -p` untuk `RTL8188EAirport.kext` **selalu** gagal dengan
> `KMErrorDomain Code=28 "requires a reboot"` — sudah dicoba setelah
> `kmutil clear-staging`, setelah entri AuxKC dihapus, dan dengan binary
> yang berbeda. Kext yang bergantung pada `IO80211Family` hanya bisa masuk
> lewat **BootKC (injeksi OpenCore)** atau **AuxKC (dibangun saat boot)**.
> Artinya: **setiap perubahan binary tetap butuh satu reboot.**
>
> LaunchDaemon F0.5 sudah dicabut (`/Library/LaunchDaemons/com.zekri.rtl8188e-start.plist`
> dihapus) karena hanya menghasilkan kegagalan saat boot dan, pada kasus
> terburuk, meninggalkan mesin tanpa driver sama sekali.
>
> Konsekuensi untuk rencana: F1–F4 tetap berlaku, tapi verifikasinya
> **selalu lewat satu reboot**, bukan hot-load. Karena itu setiap batch
> perubahan harus digabung sebanyak mungkin sebelum reboot.

**Cara pakai F0:**

```bash
# 1) uji jalur data TANPA kernel (dongle harus bebas dari driver lain)
sudo ./tools/rtwn_probe --join ZEKRI.NET --txnull

# 2) kalau perlu: hot-load kext tanpa reboot
./scripts/dev-loop-m4.sh

# 3) kalau memang harus reboot: satu perintah, satu laporan
sudo ./scripts/collect-m4.sh
```

Catatan penting: `kmutil unload` **ditolak** kalau kext masih dipegang
interface (`kext is in use or retained`). Karena itu F0.4 wajib lebih dulu —
selama kext masih di ESP, binary terkunci sejak boot dan setiap perubahan
butuh reboot.

**Diagnostik baru (23 Okt):** dua properti ioreg menjawab pertanyaan inti
tanpa `log show` (yang di mesin ini kosong):

```bash
ioreg -l -w0 | grep -E "RTL8188E-(stat|wcl)"
```

| Properti | Arti |
|---|---|
| `RTL8188E-stat` | `txm` tx mgmt · `txd` tx data · `txe` tx EAPOL · `txf` gagal kirim · `rxm` rx mgmt · `rxd` rx data · `rxe` rx EAPOL · `encf` enkripsi gagal · `pipe` jumlah bulk-out |
| `RTL8188E-wcl` | `assoc` event assoc · `link` LinkStatus diposting · `conn` ConnectComplete · `deauth` · `bcn` beacon |

Cara baca:
- `txd` naik tapi `rxe` 0 → frame data keluar, AP tidak menjawab (rate/queue).
- `txd` 0 → frame data tidak pernah sampai ke `sendFrame` (jalur stack/WCL).
- `txe` naik, `rxe` 0 → EAPOL keluar tapi msg1 tidak masuk (RX atau AP menolak).
- `rxe` naik, `txe` naik, `conn` 0 → handshake jalan tapi WCL tidak menutup join.
- `assoc` 0 → event assoc tidak sampai ke WCL (rantai net80211→WCL putus).

### F1 — Jalur data (P0, ini penyebab DHCP "no server")

Bukti: mgmt TX terbukti (M2: probe request → beacon masuk), tapi data TX tidak.
`Opkts` selalu 0 walau `Obytes` naik. DHCP DISCOVER tidak pernah dijawab.

| # | Dugaan akar masalah | Bukti pendukung | Perbaikan | Verifikasi tanpa reboot |
|---|---|---|---|---|
| F1.0 | **Frame data dikirim lewat bulk-out pipe yang salah.** 8188EU memetakan endpoint USB → queue TX (0 = VO/mgmt, 1 = VI, 2 = BE/BK). Driver hanya membuka satu pipe (yang pertama) dan memakai QSEL=BE untuk semua frame data | mgmt TX terbukti (probe request → beacon), data TX tidak; DHCP "no server" | ✅ **diperbaiki**: `bulkOpen` membuka sampai 3 bulk-out, `sendFrame` memilih pipe + QSEL sesuai AC/TID (BE→2, VI→1, VO→0) | `--txnull` di userspace (pipe 2) → TX report |
| F1.1 | **Queue data belum aktif.** `R92C_TXPAUSE=0` saja tidak cukup kalau QSEL dan pipe tidak cocok | — | tercakup F1.0 (QSEL kini sama dengan pipe) | idem |
| F1.2 | **RAID/rate hardcode.** `raid = 6`, `txdw5 = 0` tanpa batas retry | `ItlRtl8188E.cpp` | ✅ **diperbaiki**: `txdw5 = 0x0001ff00` (batas retry seperti urtwn) + DATARATE CCK1 | TX report / retry counter |
| F1.3 | **QoS/TID tidak dipetakan.** QSEL selalu 0 | — | ✅ **diperbaiki**: TID→AC→QSEL→pipe | assoc + kirim UDP |
| F1.4 | **Panjang frame setelah enkripsi** | `sendFrame` | belum diubah — `ieee80211_ccmp_encrypt` sudah menambah `pkthdr.len` (+8), jadi panjang sudah benar | `--join` WPA2 |
| F1.5 | **TX report dimatikan** | `buf[10] &= ~0x08` | belum — sengaja, sampai parser C2H benar | counter |
| F1.6 | **Tanpa backpressure TX** | `bulkSend` async | belum | flood test |

### F2 — Sinkronisasi state ke airportd (P0, ini penyebab "not associated")

Bukti: `ipconfig getsummary en2` punya SSID/BSSID/`WPA2_PSK`, tapi
`networksetup -getairportnetwork en2` → *not associated*; DHCP `State: INIT`.

| # | Dugaan | Perbaikan | Verifikasi |
|---|---|---|---|
| F2.1 | Event `STA_ASSOC_DONE` / `LinkStatus` tidak sampai ke WCL | pastikan `IEEE80211_EVT_STA_ASSOC_DONE` diposting saat masuk RUN; bandingkan dengan alur `AirportItlwm` | `networksetup -getairportnetwork` = SSID |
| F2.2 | Deauth/timeout tidak menurunkan link state | watchdog → deauth → post `STA_DEAUTH` → `setLinkState(down)` | matikan AP, menu berubah "not connected" |
| F2.3 | Beacon AP tidak sampai ke WCL (LQM butuh beacon terbaru) | pastikan `publishWCLBeacon` menerima beacon dengan `ni_bssid` cocok | RSSI muncul di menu |

### F3 — RX dan akurasi (P1)

| # | Gejala | Dugaan | Perbaikan |
|---|---|---|---|
| F3.1 | **Ierrs 33%** (103 dari 308 paket) | (a) CRC nyata, (b) stride 128 vs 4 salah saat `npkts > 1`, (c) agregasi RX `RXDMA_AGG_PG_TH` menggabungkan paket tapi parser menganggap 1 | tambah counter per-jenis error di ioreg; **matikan agregasi RX dulu**; uji `npkts=1` vs `>1` di userspace |
| F3.2 | RSSI belum terkalibrasi | formula CCK/OFDM belum dibandingkan hardware | bandingkan dengan `--scan` userspace |
| F3.3 | Scan dwell 30 ms | terlalu pendek untuk passive scan; `scan=ch-1` | naikkan dwell, pastikan urutan kanal 1–13, uji off-channel saat associated |

### F4 — "Seperti native" (P1/P2)

| # | Item | Catatan |
|---|---|---|
| F4.1 | Reconnect otomatis | deauth → scan → join ulang, tanpa campur tangan user |
| F4.2 | 802.11n HT + rate control (MiRA/AMRR) | sekarang HT dimatikan, TX 1 Mb/s |
| F4.3 | Sleep/wake (`setPowerState`) | sekarang tidak ada; sleep = link mati/panic |
| F4.4 | `kextunload` bersih | timer, workloop, USB pipe dilepas berurutan |
| F4.5 | Urutan `en0` + DHCP retry + IPv6 | Wi-Fi harus jadi `en0` kalau tidak ada Ethernet |
| F4.6 | Packaging | `MinKernel`/`MaxKernel`, uninstall bersih, dokumentasi |

---

## 3. Urutan eksekusi

```
F0.4  keluarkan kext dari ESP            (1 perintah, 1 reboot)   ← putus loop reboot
F0.1  dev-loop-m4.sh (hot-load)          (tanpa reboot)
F0.2  rtwn_probe --join/--dhcp           (tanpa reboot)
  ↓
F1.1  queue data                         (uji userspace dulu, lalu hot-load)
F1.2  rate/RAID
F1.4  panjang frame CCMP
  ↓  checkpoint: DHCP OFFER diterima
F2.1  event assoc ke WCL
F2.2  deauth → link down
  ↓  checkpoint: menu Wi-Fi menunjukkan "Connected", dapat IP
F3.x  RX error + scan
  ↓  checkpoint: scan 13 kanal, error < 5%
F4.x  reconnect, HT, sleep/wake, unload
  ↓  checkpoint: 24 jam uptime, reconnect otomatis, sleep/wake
```

Setiap item diverifikasi di lapis userspace lebih dulu kalau menyentuh
descriptor/register. Hot-load hanya untuk hal yang memang butuh kernel
(IO80211, WCL, interrupt, workloop).

---

## 4. Definisi "selesai" (normal seperti native)

1. Menu Wi-Fi menampilkan SSID sekitar, bisa join WPA2 dengan password.
2. Dapat IP via DHCP, browsing jalan.
3. Reconnect otomatis setelah AP restart atau keluar-masuk jangkauan.
4. Sleep/wake tidak panic; link kembali < 10 detik.
5. `kextunload` bersih tanpa panic.
6. Uptime 24 jam tanpa panic.
7. Throughput ≥ 40 Mbps.

Di luar itu (AirDrop, 5 GHz, 11ac) **bukan** bagian dari definisi selesai —
batas hardware.

---

## 5. Risiko

| Risiko | Mitigasi |
|---|---|
| Kext panic saat hot-load | ESP bersih (F0.4) → reboot sekali, bukan tiap iterasi |
| Dongle lepas dari bus saat TX terus-menerus | batasi TX power, jeda antar uji, quiesce sebelum uji ulang |
| IO80211 API privat berubah antar macOS | pinning `MinKernel`/`MaxKernel`, uji per versi |
| `kmutil unload` ditolak ("in use or retained") | cabut dongle dulu → instance lepas → unload |
