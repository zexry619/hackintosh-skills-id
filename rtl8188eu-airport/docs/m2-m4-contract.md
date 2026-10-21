# Kontrak M2 (USB frame) & M4 (frontend IO80211) — hasil riset statis

Tanggal: 22 Okt 2026 · Semua dari binary vendor `RtWlanU.kext` (Ghidra/REA) dan
sumber `laobamac/itlwm` (sudah terunduh di `upstream/itlwm/`).

---

# BAGIAN M2 — Format frame USB 8188E

## 2.1 Fungsi kunci (alamat di binary vendor)

| Fungsi | Alamat | Peran |
|---|---|---|
| `TxFillDescriptor8188EUsb(adapter, tcb, idx, ...)` | 0x14ccb8 | Susun descriptor TX USB |
| `RxCommandPacketHandle8188EUsb(adapter, rfd)` | 0x14cbc0 | Tangani paket RX dari chip |
| `GetRxPacketShiftBytes8188EUsb(rfd)` | 0x14cca0 | **Ukuran header paket RX** |
| `InterruptRecognized8188EUsb(adapter, buf, len)` | 0xb2e07 | Kenali interupsi (RX/TX/error) |
| `HalUsbInComplete8188EUsb(adapter, ctx, len)` | 0x14c0ed | Selesai transfer IN |
| `HalUsbEnableRx8188EUsb` / `...EnableTx...` | 0x14cc4c / 0x14cc76 | Nyalakan pipe |
| `MxUsbAsynIOWrite(usb, size, offset, buf)` | 0x80cac | Tulis bulk OUT (asinkron) |
| `HalUsbOutComplete(adapter, ctx, len)` | 0x75f25 | Selesai transfer OUT |

## 2.2 Ukuran header RX (terbukti)

```c
int GetRxPacketShiftBytes8188EUsb(_RT_RFD *rfd)
{
    return rfd[0x2F2] + 0x18 + rfd[0x2F3];
}
```

→ Header paket RX = **24 byte (0x18) + 2 byte konfigurabel** (di `rfd[0x2F2]`
dan `rfd[0x2F3]`).

## 2.3 ✅ KOREKSI: format TX/RX 8188E OpenBSD SUDAH BENAR

Dulu saya kira format TX 8188E berbeda dari OpenBSD. **Salah** — OpenBSD punya
format yang tepat, dan sudah terbukti jalan di chip ini:

```c
/* if_urtwn.c:1677 */
if (sc->sc_sc.chip & (RTWN_CHIP_88F | RTWN_CHIP_92E))
        urtwn_tx_fill_desc_gen2(sc, &txdp, m, wh, k, ni);
else
        urtwn_tx_fill_desc(sc, &txdp, m, wh, k, ni);   /* ← 8188E pakai ini */
```

`urtwn_tx_fill_desc` memakai `struct r92c_tx_desc_usb` (**32 byte**) dengan
field khusus 88E:

```c
txd->txdw1 |= htole32(SM(R88E_TXDW1_MACID, R92C_MACID_BSS) |
    SM(R92C_TXDW1_QSEL, R92C_TXDW1_QSEL_BE) |
    SM(R92C_TXDW1_RAID, raid));
txd->txdw2 |= htole32(R88E_TXDW2_AGGBK);
txd->txdw2 |= htole32(R92C_TXDW2_CCX_RPT);   /* TX report untuk AMRR */
```

Vendor menulis struktur yang sama (4 × uint32 + queue priority di bit 26–30
`txdw1`), konsisten dengan `r92c_tx_desc_usb`.

**RX**: `struct r92c_rx_desc_usb` = **24 byte** (0x18) + 2 byte →
**persis** sama dengan `GetRxPacketShiftBytes8188EUsb` vendor
(`rfd[0x2F2] + 0x18 + rfd[0x2F3]`).

### Kesimpulan M2

> **M2 = implementasi transport USB (bulk pipe + descriptor ring),
> BUKAN membuat format frame baru.**
> Format TX (32 B) & RX (24+2 B) sudah ada di OpenBSD dan terbukti di chip ini.

Implikasi: `src/urtwn/rtwn_m1.cpp` (turunan `urtwn_tx_fill_desc`) bisa langsung
dipakai. Yang perlu ditulis: pemetaan `usbd_setup_xfer`/`usbd_xfer` →
`IOUSBHostPipe` + `IOBufferMemoryDescriptor` (antrean buffer TX/RX).

## 2.3b Peta field descriptor TX vendor (untuk referensi)

`TxFillDescriptor8188EUsb` (0x14ccb8) menulis ke `puVar5[0..3]` (= 4 × uint32)
dengan `puVar20` = `puVar5` atau `puVar5 + 2` (kasus agregat, header 8 byte
ditambahkan di depan, panjang dikurangi 8):

| Vendor | Offset (bila puVar20 = puVar5) | Arti |
|---|---|---|
| `puVar20[1]` bit 8–12 | byte 1 | rate (`MRateToHwRate8188E`) |
| `puVar20[1]` bit 22 / 23 | byte 1 | flag (0x400000 / 0x800000) |
| `puVar20[2]` = 0x20 / 0x28 | byte 2 | tipe paket |
| `puVar20[4]` bit 0–7 | byte 4 | QSEL/ACK/CTS-untuk-self |
| `puVar20[4]` bit 21–22 | byte 4 | `*(adapter+0x20531) & 3` (antrean) |
| `puVar20[5]` bit 0–5 | byte 5 | rate hardware |
| `puVar20[6]` = 0x6666f800 | byte 6 | nilai tetap (agregat) |
| `puVar5[1]` bit 26–30 | byte 1 (32-bit) | prioritas antrean `(adapter+0x3D75 & 0x1F) << 26` |
| `puVar5[3]` bit 26–30 | byte 12 (32-bit) | prioritas (jalur agregat) |

**Kesimpulan praktis:** vendor memakai format deskriptor yang **lebih baru & lebih
kompleks** (agregasi, TX report, multi-antrean). Format **OpenBSD
(`r92c_tx_desc_usb`, 32 B) lebih sederhana dan sudah terbukti jalan di chip ini**
→ pakai yang OpenBSD dulu. Format vendor hanya dibutuhkan kalau operasi
agregasi/AMRR Lime.

## 2.4 Yang sudah jelas

* Endpoint: bulk IN (RX) + bulk OUT (TX) pada interface 0.
  Dari USB descriptor adapter (terbaca saat M0): `bNumEndpoints = 3`.
* Flow RX: `InterruptRecognized8188EUsb` → `HalUsbInComplete8188EUsb` →
  `RxCommandPacketHandle8188EUsb` → masuk ke RX descriptor ring.
* Flow TX: `TxFillDescriptor8188EUsb` → `MxUsbAsynIOWrite` → `HalUsbOutComplete`.

---

# BAGIAN M4 — Kontrak frontend IO80211 (ini yang bikin "native")

## 4.1 Arsitektur AirportItlwm

```
CoreWLAN (milik Apple)
    │  IO80211 KPI (API privat Apple)
    ▼
AirportItlwm : public IO80211Controller        ← 7.221 baris, tinggal diadaptasi
    │  (+ AirportItlwmInterface : public IO80211Interface  → override inputPacket)
    │  (+ AirportItlwmSkywalkInterface          → jalur data modern)
    │  (+ AirportSTAIOCTL / AirportVirtualIOCTL)
    │  (+ AirportAWDL — tidak kita pakai)
    ▼
ItlHalService (abstract)  ← KONTRAK UTAMA
    ├── ItlDriverInfo        (kapabilitas: tx queue size, firmware name, features, country)
    └── ItlDriverController  (scan, join, TX/RX, keys, multicast)
    ▼
driver chip (kita: 8188E USB)
```

## 4.2 `ItlHalService` — 7 method yang WAJIB diimplementasikan

Dari `upstream/itlwm/include/HAL/ItlHalService.hpp`:

```cpp
virtual bool attach(IOPCIDevice *device) = 0;            // ← PCI! harus digeneralisasi ke USB
virtual void detach(IOPCIDevice *device) = 0;
virtual IOReturn enable(IONetworkInterface *interface) = 0;
virtual IOReturn disable(IONetworkInterface *interface) = 0;
virtual struct ieee80211com *get80211Controller() = 0;  // instance net80211
virtual ItlDriverInfo *getDriverInfo() = 0;
virtual ItlDriverController *getDriverController() = 0;
// opsional: setScanHomeAwayTime(), prepareDma() (PCI-specific)
```

## 4.3 `ItlDriverInfo` — yang dibutuhkan frontend

Dipakai di `AirportItlwm.cpp`:
* `getTxQueueSize()` → `configureOutputPullModel(...)` (line 122)
* `getFirmwareName()` → `fFirmwareName` (line 458)
* `supportedFeatures()` → `IO80211Controller::supportedFeatures` (line 731)
* country code / regulatory

## 4.4 `ItlDriverController` — kontrol chip

```cpp
virtual void clearScanningFlags() = 0;
virtual IOReturn setMulticastList(IOEthernetAddress *addr, int count) = 0;
```
Implementasi referensi: `ItlIwx` (13.871 baris) & `ItlIwn` (7.714 baris) — itulah
**ukuran pekerjaan** untuk driver chip kita (versi 8188E USB akan di chiffre ~4–6k baris
kalau hardware layer urtwn dipakai).

## 4.5 Yang SUDAH SIAP dipakai (tidak perlu ditulis)

| Komponen | Ukuran | Status |
|---|---|---|
| `itl80211/openbsd/net80211/` (34 file) | 27.905 baris | ✅ sudah diport ke macOS, siap pakai |
| `itl80211/compat.cpp` (shim BSD→kernel) | 385 baris | ✅ |
| `AirportItlwm/*` (frontend IO80211) | 7.221 baris | ✅ ada, perlu adaptasi PCI→USB |
| `include/Airport/*` (header IO80211 privat Apple) | 28 header | ✅ ada |

## 4.6 Yang harus ditulis (4–6k baris)

| Komponen | Isi |
|---|---|
| `ItlRtl8188E` : ItlHalService+Info+Controller | attach/detach USB, enable/disable, scan, join, TX/RX, keys, multicast, country |
| `UsbBackend` | pembungkus `IOUSBHostInterface` + `IOUSBHostPipe` (menggantikan `IOPCIEDeviceWrapper`) |
| Adapter net80211 | `struct ieee80211com` + ops (`rtwn_softc` dari OpenBSD, sudah ada di `rtwn_m1.cpp`) |
| Adaptasi frontend | `IOPCIEDeviceWrapper` → `UsbBackend`; `AirportItlwmEthernetInterface` bisa dipakai dulu (mode Ethernet, bukan native) |

---

# BACKLOG RISET STATIS (tanpa reboot)

| # | Item | Status |
|---|---|---|
| 1 | Encoding vendor request | ✅ selesai |
| 2 | Layout register EFUSE 8188E (akar masalah M1) | ✅ selesai |
| 3 | Parser EFUSE identik vendor | ✅ selesai (differential test 20k) |
| 4 | Tabel power-flow 9 tabel + decoder | ✅ selesai |
| 5 | Urutan init 42 langkah | ✅ selesai |
| 6 | Kontrak M4 (`ItlHalService`/`Info`/`Controller`) | ✅ selesai (dokumen ini) |
| 7 | Ukuran header RX USB | ✅ selesai (24 + 2 byte) |
| 8 | Format descriptor TX 8188E | 🟡 sebagian (perlu decompile penuh) |
| 9 | Jalur upload firmware (H2C) | ⬜ (`FW_FirmwareDownload`, `FillH2CCommand8188E_MP`) |
| 10 | Register MAC/BB/RF init | ⬜ (`PHY_MACConfig`, `PHY_BBConfig`, `PHY_RFConfig8188E`) |
| 11 | Batas halaman/buffer TX | ⬜ (`_InitTxBufferBoundary_8188E`, `GetInitialRQPValue88EU` → 0x900000/0xDA0000) |
| 12 | Pipe USB: enable RX/TX, timing | ⬜ (`PlatformUsbEnableInPipes`) |
| 13 | Set MAC ke chip | ⬜ (`MgntActSet_802_3_MAC_ADDRESS`) |
| 14 | Kalibrasi RF (IQ/LK) | ⬜ (`halrf_iqk_trigger`, `halrf_lck_trigger`) |

Item 8–14 semuanya **murni statis** (decompile vendor binary + adaptasi).
