# LAB USER SPACE — akses chip tanpa reboot, tanpa kernel

**Tanggal**: 22 Oktober 2026
**Status**: ✅ BERHASIL — ini mengubah cara kita mengembangkan driver.

---

## 1. Mengapa ini penting

Sebelumnya setiap perubahan kode = **1 reboot** (macOS 15 tidak bisa
hot-load kext). Satu siklus uji ≈ 5–10 menit, dan setiap kegagalan
berisiko panic.

Ternyata **seluruh komunikasi dengan chip adalah USB control transfer
vendor (`bRequest=0x05`)**, dan itu bisa dilakukan dari **user space**
dengan `IOKit` biasa. Tidak perlu kext, tidak perlu reboot, tidak ada
risiko kernel panic.

Siklus uji menjadi **hitungan detik**.

---

## 2. Bug yang menghalangi (dan perbaikannya)

`tools/rtwn_probe.c` versi lama memakai:

```c
IOServiceOpen(svc, mach_task_self(), 0, &conn);
gDev = (IOUSBDeviceInterface **)&conn;      /* ← SALAH */
```

Hasilnya selalu `kIOReturnNotOpen` (`0xe00002c7`).
`IOServiceOpen` bukan cara membuka `IOUSBDevice` — yang benar:

```c
IOCreatePlugInInterfaceForService(svc,
    kIOUSBDeviceUserClientTypeID,
    kIOCFPlugInInterfaceID, &plug, &score);

(*plug)->QueryInterface(plug,
    CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID *)&dev);
(*plug)->Release(plug);

kr = (*dev)->USBDeviceOpen(dev);
if (kr != kIOReturnSuccess)
        kr = (*dev)->USBDeviceOpenSeize(dev);   /* kalau eksklusif */
```

Setelah itu `DeviceRequest()` bekerja normal.

---

## 3. Pemakaian

```bash
# build (dari root repo)
clang -O2 -o tools/rtwn_probe tools/rtwn_probe.c \
      src/urtwn/rtwn_seq.c src/urtwn/rtwn_seq_efuse.c \
      src/urtwn/rtwn_efuse_8188e.c src/urtwn/rtwn_flow.c \
      src/urtwn/firmware_rtl8188eufw.cpp -Isrc/urtwn \
      -framework IOKit -framework CoreFoundation

sudo ./tools/rtwn_probe                  # info + dump register kunci
sudo ./tools/rtwn_probe --efuse-all      # semua jalur EFUSE + diagnostik
sudo ./tools/rtwn_probe --full           # power-on + LLT + firmware + EFUSE
sudo ./tools/rtwn_probe --peek 0x610 6   # baca register mentah
sudo ./tools/rtwn_probe --poke 0x100 0xdeadbeef
sudo ./tools/rtwn_probe --dump 0x000 0x40
```

**Syarat**: tidak ada driver kernel yang memegang device.
Kext kita melakukan **self-detach** setelah init, jadi tunggu ±10 detik
setelah dongle tercolok. Kalau masih `kIOReturnExclusiveAccess`:

```bash
sudo kextunload -b io.github.zekri.RTL8188EUM1
```

---

## 4. Hasil pertama (22 Okt 2026)

```
device dibuka ✓ (config=1)
CR=0x0000063f  MCUFWDL=0x000300c6  SYS_CFG=0x244037b7

0x033 EFUSE_STATUS = 0x80      ← bit7 SET = siap
0x106 EFUSE_106    = 0x69      ← akses EFUSE ON
0x209 EFUSE_MODE   = 0xf4
0x610 MACID        = 0x00
```

Lalu `--efuse-all`:

```
── Tahap 2b: EFUSE OFFLOAD ──
  [diag] efuse-offload-hdr   aa290e00910091
  [diag] efuse-offload-raw   0e29816f33ff0000
  ✓ MAC = 98:03:8e:9e:bc:24

── Tahap 2a: EFUSE DIRECT ──
  [diag] efuse-direct-dump   0e29816f33ff0000 00cf4081...
  (kadang gagal 1 byte → jalur direct kurang andal)
```

**Kesimpulan**: jalur **offload** yang dipakai sebagai primer.

---

## 5. Yang bisa diuji berikutnya (tanpa reboot)

| Komponen | Fungsi | Bisa dari user space? |
|---|---|---|
| EFUSE | `rtwn_seq_read_efuse_offload` | ✅ sudah |
| HAL tables | `rtwn_hal_apply_table` | ✅ (register write) |
| Set kanal | `rtwn_set_chan_8188e` | ✅ (RF write) |
| TX/RX 802.11 | `rtwn_build_probe_request` | ⚠️ butuh bulk pipe |
| Scan | beacon RX | ⚠️ butuh bulk pipe + DMA |

Untuk TX/RX perlu menambah dukungan **bulk transfer** di probe
(`IOUSBInterfaceInterface` → `ReadPipe`/`WritePipe`), ditambah init
queue/DMA. Itu langkah berikutnya — tapi sekarang bisa diiterasi tanpa
reboot.

---

## 6. Catatan keamanan

- Semua fungsi yang dipanggil adalah **kode yang sama** dengan kext
  (`src/urtwn/*.c`), jadi hasil di user space valid untuk kernel.
- Register write dari user space **tidak** dilindungi guard boot seperti
  di kext — jangan jalankan saat driver vendor (`RtWlanU`) aktif.
- Kalau chip di-reset ke state aneh, jalankan `--full` (power-on + LLT +
  firmware) untuk memulihkan, atau cabut-colok dongle.
