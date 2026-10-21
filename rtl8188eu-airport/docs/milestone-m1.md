# Milestone 1 — Bring-up: Firmware + EFUSE + Chip ID

Status: **kode selesai & ter-build** (belum diuji di mesin — butuh sudo).

## Apa yang dikerjakan M1

M1 menjawab satu pertanyaan: *bisakah kita benar-benar Talks to chip 8188EUS dari
kernel macOS, seperti yang dilakukan OpenBSD?*

Langkah yang diimplementasikan (diurut persis seperti OpenBSD):

| # | Langkah | Sumber OpenBSD (ISC) | Port kita |
|---|---|---|---|
| 1 | Ambil alih device USB, configure | `urtwn_attach` | `src/usb/usb_compat.cpp` |
| 2 | Deteksi chip 88E | `rtwn_read_chipid` (rtwn.c:614) | `rtwn_m1_read_chipid` |
| 3 | Baca EFUSE → MAC, xtal, regulatory | `rtwn_efuse_read` (rtwn.c:526)<br>`rtwn_r88e_read_rom` (rtwn.c:715) | `rtwn_m1_read_rom` |
| 4 | Power-on chip | `urtwn_r88e_power_on` (if_urtwn.c:1912) | `rtwn_m1_power_on` |
| 5 | Inisialisasi DMA + LLT | `urtwn_dma_init` (if_urtwn.c:2137)<br>`urtwn_llt_init` (if_urtwn.c:2035) | `rtwn_m1_dma_init` |
| 6 | Upload firmware 8051 | `rtwn_load_firmware` (rtwn.c:1751)<br>`urtwn_fw_loadpage` (if_urtwn.c:2080)<br>`rtwn_r88e_fw_reset` (rtwn.c:1717) | `rtwn_m1_load_firmware` |

## Protokol USB yang dipakai

Semua register Realtek diakses lewat **vendor request**, bukan bulk pipe:

```
bmRequestType = 0x40 (write) / 0xC0 (read)
bRequest      = 0x05   (R92C_REQ_REGS)
wValue        = alamat register (LE)
wIndex        = 0
wLength       = panjang data (1/2/4 byte)
```

Ini persis yang dilakukan `urtwn_read_region_1()` / `urtwn_write_region_1()`
di OpenBSD (`if_urtwn.c` baris 785 & 825). Pembacaannya:`usbd_do_request()`
→ `IOUSBHostDevice::deviceRequest()`.

## Berkas

```
src/usb/usb_compat.{h,cpp}      Layer 1 — shim USB (kita tulis)
src/urtwn/rtwn_m1.{h,cpp}       Layer 2 — port rtwn/urtwn (OpenBSD, ISC)
src/urtwn/rtwn_consts.h         konstanta chip (OpenBSD, ISC)
src/urtwn/r92creg.h             salinan r92creg.h + padding Darwin
src/urtwn/firmware_rtl8188eufw.cpp   firmware 8188E (dari linux-firmware)
src/driver/RTL8188EUM1.cpp       driver IOKit (kita tulis)
src/driver/Info.plist           personality IOUSBHostDevice 9047:268
```

## Cara menjalankan

```bash
./scripts/build-m1.sh        # generate firmware array → compile → link → sign
```

### Cara memuat kext di macOS 15 tanpa Xcode

Tiga hal wajib yang **tidak** ada di tutorial lama:

1. **Simbol `_kmod_info`** — kernel mencari simbol ini di setiap kext
   (`libkern/kxld/kxld_kext.c`). Xcode membuatnya otomatis; tanpa Xcode kita
   generate sendiri di `src/driver/kmod_info.c` (layout dari XNU
   `osfmk/mach/kmod.h`, `KMOD_MAX_NAME = 64`).
2. **Milik `root:wheel`** — `kmutil` menolak kext dengan ownership lain:
   `sudo chown -R root:wheel <kext>` (sudah otomatis di `build-m1.sh`).
3. **Kext harus ber-KC** — `OSBundleLibraries` harus menunjuk bundle yang benar:
   `com.apple.iokit.IOUSBHostFamily` (bukan `com.apple.iokit.IOKit`, yang tidak
   ada sebagai bundle terpisah di macOS modern).

### Alur uji (butuh reboot) — jalur OpenCore ⭐

Jalur **AuxiliaryKernelExtensions** (`kmutil load`) sudah dicoba dan **gagal**:
kext bertanda tangan ad-hoc tidak masuk daftar `SignedKernelExtensions`, sehingga
tidak pernah dievaluasi `syspolicyd` → tidak pernah masuk ke KC. Lognya:

```
syspolicyd: Kernel Extension ALLOWED: ... EnergyDriver, HighPointIOP, HighPointRR
             (tidak ada baris untuk io.github.zekri.RTL8188EUM1)
```

Jalur **OpenCore** (injeksi langsung ke BootKC) tidak butuh approval sama sekali:

```bash
sudo ./scripts/install-opencore.sh    # backup → salin kext → tambah Kernel->Add
sudo shutdown -r now

# setelah boot:
./scripts/collect-m1-log.sh

# rollback:
sudo ./scripts/uninstall-opencore.sh
```

`install-opencore.sh` melakukan:
* backup `config.plist` + tarball seluruh `EFI/` ke `backup/`;
* menyalin kext ke `EFI/OC/Kexts/RTL8188EUM1.kext` (root:wheel);
* menambah entri `Kernel → Add` (Arch Any, MinKernel 24.0.0, MaxKernel 24.99.99);
* **membersihkan kext dari AuxKC** (instructions + uakl + StashedExtensions) supaya
  tidak ter-load dua kali (BootKC *dan* AuxKC) — itu penyebab kernel panic
  potensial pada driver USB.

### Mode driver: readonly vs full

| Mode | Pemicu | Yang dilakukan | Butuh vendor mati? |
|---|---|---|---|
| **readonly** (default) | (tidak ada boot-arg) | Hanya BACA register: MACID, CR, APS_FSMCO, SYS_FUNC_EN, MCUFWDL, SYS_CFG. **Nol penulisan.** | ❌ tidak — Wi-Fi vendor tetap jalan |
| **full** | boot-args `-rtl8188eum1_mode full` | power-on + DMA init + upload firmware (menulis register) | ✅ ya |

> **Format boot-arg harus `nama=nilai`** (bukan `nama nilai`) — `PE_parse_boot_argn`
> mencari tanda `=` untuk memisahkan nilai. Salah format → mode diam-diam kembali
> ke `readonly`.

Kontrol mode:

```bash
sudo ./scripts/set-mode.sh readonly   # default
sudo ./scripts/set-mode.sh full
```

Mengapa pakai boot-arg? Kernel XNU tidak punya POSIX file I/O (`open()`/`read()`
tidak ada), jadi file penanda tidak bisa dibaca dari dalam kext.

### Jalur AuxKC (alternatif, tidak dipakai)

```bash
sudo ./scripts/prepare-m1-boot.sh   # stage ke AuxKC + matikan RtWlanU
sudo shutdown -r now
./scripts/collect-m1-log.sh
sudo ./scripts/restore-vendor-wifi.sh   # kembalikan Wi-Fi vendor
```

---

### Temuan: control transfer sinkron bisa menggantung selamanya

Varian sinkron `IOUSBHostDevice::deviceRequest(..., uint32_t& bytesTransferred)`
dokumentasinya:

> "This method will acquire the service's workloop lock, and will call commandSleep
> to send the control request."

Kalau perangkat tidak merespons (chip belum power-on / belum ada firmware), thread
kita **gantung tanpa batas** — persis yang terjadi: 0 request selesai, counter
`M1InOk = 0`, driver membeku di `usb-ok`.

Perbaikan: pakai varian **asinkron** (`IOUSBHostCompletion`) + **timeout sendiri**
(1 detik) + `abortDeviceRequests()` kalau lewat. Driver tidak pernah bisa membeku,
dan counter `M1InFail`/`M1OutFail` memberi tahu transfer mana yang menggantung.

Bonus: control transfer sekarang diprioritaskan lewat **interface**
(`IOUSBHostInterface::deviceRequest`) — workloop-nya berbeda dari device, dan itulah
jalur yang dipakai driver USB modern (HoRNDIS dkk). Kalau driver attach ke node
device, interface nomor 0 dicari dari anak-anaknya.

### ⚠️ Pelajaran penting #2: jangan pernah membebaskan buffer transfer

Panic kedua (21 Okt 2026, 10:33) **offset identik** (+0x329) meski buffer sudah
dipindah ke heap:

```
panic(cpu 0): A kext releasing a(n) RTL8188EUM1 has corrupted the registry.
  __ZNK8OSObject13taggedReleaseEPKvi
  io.github.zekri.RTL8188EUM1: __ZN11RTL8188EUM115runInitSequenceEv + 0x329
```

Disassembly offset +0x329 = `release()` atas objek yang diperoleh dari
`copyProperty("M1Mode")` — jadi itu **tempat korupsinya terdeteksi**, bukan
penyebabnya.

Penyebab sebenarnya: **stack USB masih menyentuh `dataBuffer` setelah completion
dipanggil**, sehingga buffer yang kita `IOFree()` = use-after-free → heap rusak →
objek registry ikut rusak → panic saat release berikutnya.

Perbaikan final:

| # | Aturan |
|---|---|
| 1 | Buffer + context transfer **tidak pernah dibebaskan** (sengaja bocor ±100 B per transfer). Kebocoran jauh lebih murah daripada kernel panic |
| 2 | Akumulasi log di **buffer statis**, bukan `copyProperty` (membaca property balik & melepaskannya bisa menyentuh objek katalog) |
| 3 | Mode driver ditentukan **saat build** (`M1_ALLOW_USB_TRAFFIC`), bukan runtime |
| 4 | **Build default = inert** (nol traffic USB) → aman di ESP. Varian uji dibangun terpisah untuk hot-swap runtime |

### ⚠️ Pelajaran penting: kext eksperimental jangan jalan saat boot

Kronologi 21 Okt 2026: kext yang di-inject ke BootKC **membuat mesin gagal boot**.
Panic log:

```
panic(cpu 8): A kext releasing a(n) RTL8188EUM1 has corrupted the registry. @OSObject.cpp:224
  __ZNK8OSObject13taggedReleaseEPKvi
  io.github.zekri.RTL8188EUM1: __ZN11RTL8188EUM115runInitSequenceEv + 0x329
```

Akar masalah: control transfer asinkron memakai **buffer & context di stack**.
Completion bisa dipanggil setelah pemanggil kembali → use-after-free → kernel memory
corruption → panic saat boot.

Perbaikan yang dibuat:

| # | Perbaikan |
|---|---|
| 1 | Buffer + context transfer dipindah ke **heap** (`IOMalloc`/`IOFree`), dimiliki completion callback |
| 2 | Kalau completion tidak pernah datang, context **sengaja dibocorkan** (bukan di-free) — membebaskan bisa jadi use-after-free |
| 3 | **Driver jadi inert saat boot**: `start()` pertama hanya attach, TIDAK ada traffic USB. Init hanya jalan saat personality dikirim ulang dari user space |
| 4 | Watchdog 15 detik membatalkan request yang menggantung |

Aturan ke depan: **driver eksperimental tidak boleh melakukan apa pun saat boot.**

### ⭐ LOOP ITERASI TANPA REBOOT

Temuan penting (21 Okt 2026): **`kmutil load -z -p <bundle>` bisa HOT-SWAP kext yang
sedang termuat** — kext lama di-unload dari kernel, build baru langsung dimuat
(terbukti: UUID & ukuran kext berubah setelah load). Contoh:

```bash
sudo kmutil load -z -p src/driver/build/RTL8188EUM1.kext
```

Masalahnya: driver instance yang lama masih "nempel" ke device USB (request-nya
menggantung), jadi node USB tetap diklaim dan kext baru tidak bisa match.

**Solusinya: cabut-colok dongle USB.** Node USB dibuat ulang → driver lama ikut
mati → kext baru (binary baru) langsung match & menjalankan init.

```bash
./scripts/dev-loop.sh      # build → hot-swap → trigger init → cek hasil
```

Semua lewat runtime: **tidak ada reboot, tidak ada cabut-colok**. Driver inert
saat boot, jadi kext boleh ada di BootKC tanpa risiko boot gagal.

Trigger init = personality dikirim ulang:

```bash
sudo kmutil load -b io.github.zekri.RTL8188EUM1 -P RTL8188EUM1
```

Kext di BootKC (hasil injeksi OpenCore) → `kmutil load -z -p` bisa hot-swap
binary tanpa reboot.

### Cara memicu match tanpa reboot

Personality dari KC dipublikasikan **sebelum** node USB ada, jadi IOKit tidak
otomatis match. Solusinya: kirim personality ke katalog secara manual.

```bash
sudo ./scripts/trigger-match.sh
```

Perintah intinya:

```bash
sudo kmutil load -b io.github.zekri.RTL8188EUM1 -P RTL8188EUM1
```

Efeknya terlihat di log kernel:

```
(IOUSBHostFamily) 802.11n NIC@14800000: IOUSBHostDevice::setConfigurationGated:
                    RTL8188EUM1 selected configuration 1
```

### Tracing via registry (bukan log)

Pesan `IOLog` dari kext yang di-inject OpenCore **tidak** selalu muncul di unified
log. Karena itu driver menulis progres ke properti registry, yang langsung terlihat
di `ioreg`:

```bash
ioreg -r -c RTL8188EUM1 -w0 | grep M1State
```

| M1State | Arti |
|---|---|
| (kosong) | `start()` belum dipanggil |
| `start-called` | driver match, start() masuk |
| `started` | driver aktif, timer akan jalankan init |
| `usb-attach` / `usb-ok` | claim device / device+interface OK |
| `chipid` / `efuse` | deteksi chip / baca EFUSE (MAC) |
| `power-on` / `dma-init` | power-on chip / inisialisasi DMA+LLT |
| `firmware` | upload firmware |
| `SELESAI` | M1 berhasil |

### Temuan penting: OpenCore menulis ulang IOProbeScore

Setelah di-inject ke BootKC, personality kext ditulis ulang OpenCore dengan
`IOProbeScore = 99000` (nilai kita 92000/91000/90000/89000). Tidak masalah —
memang想让 kext kita menang atas driver internal Apple.

### Temuan penting: keharusan attach ke node INTERFACE

Percobaan pertama (personality `IOUSBHostDevice`) **tidak pernah match**, dan
`ioreg`+logrus membuktikannya:

```
802.11n NIC  <class IOUSBHostDevice, id 0x100000369, registered, matched, active>
  +-o AppleUSBHostLegacyClient  (!registered, !matched)   ← driver internal Apple
  +-o RTL8188EUM1               (!registered, !matched)   ← driver kita: GAGAL
  +-o IOUSBHostInterface@0      (registered, matched, active)
```

Penyebabnya: di stack USB modern, **node device sudah diklaim driver internal
Apple** dan hanya bisa punya satu driver. Driver pihak ketiga harus attach ke
node **interface** (`IOUSBHostInterface`), yang fortunately tetap membawa properti
`idVendor` / `idProduct` / `bInterfaceNumber`:

```
IOUSBHostInterface@0: idVendor=9047 idProduct=268 bInterfaceNumber=0 bInterfaceClass=255
```

Personality final (urutan prioritas):

| # | IOProviderClass | Keys | Probe score |
|---|---|---|---|
| 1 | `IOUSBHostInterface` | idVendor, idProduct, bInterfaceNumber=0 | 92000 |
| 2 | `IOUSBInterface` (legacy) | idVendor, idProduct, bConfigurationValue=1, bInterfaceNumber=0 | 91000 |
| 3 | `IOUSBHostDevice` | idVendor, idProduct | 90000 |
| 4 | `AppleUSBDevice` (legacy) | idVendor, idProduct | 89000 |

Konsekuensi tambahan: selama `RtWlanU` aktif, node interface (legacy
`AppleUSBInterface`) ikut diklaim → **driver kita dan driver vendor tidak bisa
berdampingan**. Keduanya harus bergantian (scripts `vendor-off.sh` /
`vendor-on.sh`).

## Output yang diharapkan

```
RTL8188EUM1: === M1 init started ===
RTL8188EU: usb: device sudah terkonfigurasi (cfg=1, iface=1)
RTL8188EUM1: chip flags=0x80000020, bulk OUT endpoint=3
RTL8188EU: chip: 88E/88F/92E detected (extended header)
RTL8188EU: rom: xtal=0x0b regulatory=0 channel_plan=0
RTL8188EU: rom: MAC = xx:xx:xx:xx:xx:xx
RTL8188EU: power on: OK
RTL8188EU: dma init: OK (ntx=3, pagecnt=168)
RTL8188EU: firmware: signature=0x88e v1.x ... header 32 byte dilewati
RTL8188EU: firmware: checksum report OK
RTL8188EU: firmware: upload OK (15262 byte)
RTL8188EUM1: === M1 init SELESAI ===
```

## Cara membaca hasil (diagnostik)

| Gejala | Arti | Tindakan |
|---|---|---|
| `usb: gagal open device` | Device dipakai driver lain | Matikan `RtWlanU` |
| `control IN … gagal: 0x…` | Vendor request ditolak | Device belum configured / salah bmRequestType |
| `efuse: gagal baca byte` | Chip tidak merespons register | Coba `chip flags` 88E; cek power-on urutan |
| `rom: MAC = 00:00:00:00:00:00` | Offset MAC salah | Offset harus 215 (`offsetof(r88e_rom, u.r88eu.macaddr)`) |
| `power on: timeout` | Bit `SUS_HOST` tidak pernah set | Chip belum wake; cek urutan reset BB |
| `firmware: timeout checksum report` | Upload gagal | Cek `maxblksz` (196 untuk 88E) & signature firmware |
| Log sama sekali tidak muncul | Driver tidak match | `ioreg -r -c RTL8188EUM1`; cek Info.plist personality |

## Catatan penting

* **MAC address yang terbaca harus sama dengan MAC di router** (DHCP lease) dan
  di label adapter. Ini validasi terkuat bahwa baca EFUSE benar.
* `rtwn_m1_dma_init` memakai `sc->ntx` = jumlah bulk OUT endpoint yang dibaca dari
  deskriptor USB. Kalau nilainya 0, cek `countBulkOutEndpoints()`.
* M1 **tidak** memakai bulk pipe sama sekali — hanya control transfer.
  Itu sebabnya M1 relatif aman dan cepat.
* Setelah M1 sukses, langkah berikutnya M2: buka bulk IN/OUT, queue transfer,
  dan menerima frame 802.11 mentah (masuk ke `net80211`).
