# Analisis waktu boot / linimasa

## 0. Kegunaan dan prasyarat

Masalah seperti "boot sangat lambat" "macet di suatu tempat" "berapa lama layar hitam" **tidak bisa diselesaikan hanya dengan perkiraan**. Waktu boot adalah satu linimasa yang **terdiri atas tiga tahap terpisah**, dan bukti tiap tahap berada di **tempat berbeda**; mencampur semuanya tidak akan pernah menemukan akar masalahnya:

| Tahap | Rentang waktu | Di mana buktinya | Siapa bertanggung jawab |
|---|---|---|---|
| **A. Tahap OC** | POST firmware → diserahkan ke macOS | `opencore-*.txt` di akar ESP (`Misc>Debug>Target` memuat `0x40`) | Konfigurasi OpenCore (jumlah kext, ACPI, quirk, timeout) |
| **B. Tahap kernel / driver** | kernel hidup → arm / desktop tampil | `dmesg` + `log show` (`process == "kernel"`) | Driver (NVIDIA NVRM/NVRMFB, NIC, iGPU, dan lain-lain) |
| **C. Tahap userspace** | launchd → Finder / desktop siap pakai | `/var/log/com.apple.xpc.launchd/launchd.log` (**tidak perlu sudo**) | Ketergantungan service, blocking `IOKitWaitQuiet`, Spotlight |

**★ Aturan besi**: saat melaporkan "boot lambat", **tanyakan dulu tahap yang mana**.
"Teks bergulir lambat antara picker dan logo Apple" adalah **tahap A** (lihat bit `Target` di `logs-and-debug.md`);
"Logo Apple berputar lama sekali baru masuk ke desktop" adalah **tahap B/C** (biasanya driver sedang menunggu).

## 1. Pengumpulan data: dua skrip, satu prinsip

Prinsip: **ambil dulu data yang cepat dan penting (`dmesg` / `launchd.log`), letakkan `log show` yang paling lambat di akhir dan beri batas waktu**. Jika tidak, satu kali pengumpulan bisa macet belasan menit (basis log mesin ini ~3 GB / 20 juta baris).

```bash
# ① Ringkasan (disarankan dijalankan lebih dulu) — info dasar + properti NVRM + dmesg + linimasa launchd + log kernel
sudo bash scripts/boot-timeline.sh          # menghasilkan ~/boot-timeline-<waktu>.txt

# ② Selidiki satu "jendela jeda" tertentu — cari celah terbesar secara otomatis, lalu ambil log jendela itu secara streaming
sudo bash scripts/find-boot-gap.sh          # penuh, 2–5 menit; bisa di-Ctrl-C
sudo bash scripts/find-boot-gap.sh --kernel # hanya kernel, jauh lebih cepat
```

Kedua skrip itu **hanya membaca**, tidak mengubah apa pun. Output ditulis ke direktori home `$SUDO_USER` (cari dengan `dscl`, jangan menulis path secara hard-code).

### 1.1 ★★ Di mesin ini (dan banyak mesin lain) filter waktu `log show` sama sekali tidak bekerja

Ini adalah jebakan terdalam yang pernah terjadi di mesin ini, **verifikasi juga ketika berganti mesin**:

| Penulisan yang Anda kira bisa dipakai | Perilaku sebenarnya (hasil ukur di mesin ini) |
|---|---|
| `log show --start "<t>" --end "<t>"` | melaporkan `Wall Clock adjustment detected` (jam sistem dikoreksi saat boot), mengembalikan **seluruh basis log** (≈3 GB / 20 juta baris) |
| `log show --last 30m` | **juga mengembalikan seluruh basis log** (tidak dipotong berdasarkan waktu) |
| `log show --boot` | **opsi tersebut tidak ada** |

**Cara yang benar = filter streaming**: output `log show` adalah **stream terurut waktu**, jadi tidak perlu menulis file sementara; gunakan `awk` untuk hanya mencetak baris di dalam jendela:

```bash
log show --style compact --predicate "$PRED" 2>/dev/null \
  | awk -v s="$S" -v e="$E" '{ t=substr($0,1,19); if (t >= s && t <= e) print }' \
  > "$FILTERED"
```

Sebesar apa pun basis lognya, **hanya puluhan KB di dalam jendela itu yang tertulis ke disk**.

**Hemat predikat**: `process == "kernel"` adalah field terindeks, sangat cepat; **jangan** memakai `eventMessage CONTAINS` untuk filtering
(butuh pemindaian penuh, sangat lambat) — filter kata kunci dilakukan dengan `grep` lokal. Untuk menyaring pesan yang membanjiri layar, gunakan `NOT (eventMessage CONTAINS "...")`.

### 1.2 Mencari "jendela jeda" dari `launchd.log` (tercepat, tidak perlu sudo)

Celah userspace tersembunyi di dalam **lompatan timestamp** pada `launchd.log`. Skrip memakai python untuk menghitung selisih antar timestamp yang berurutan:

```python
# batasi 0..180 detik, cari celah terbesar, keluarkan "durasi offset awal offset akhir"
for a, b in zip(ts, ts[1:]):
    if b - a > best[0]: best = (b - a, a, b)
```

Setelah mendapat "celah terbesar D detik (+A s → +B s)", perluas kedua ujung jendela beberapa detik (`A-4` → `B+8`) lalu selidiki di `log show`.

## 2. Kriteria: baris log → makna → detik

### 2.1 Tahap OC (`opencore-*.txt`)

Format baris `mm:sss interval OCmodul: pesan`, **kolom pertama adalah detik relatif terhadap boot**, langsung dipakai sebagai durasi tiap tahap.
Baris kriteria penting ada di `logs-and-debug.md` §5 (masing-masing quirk pada `OCABC:`, tabel ACPI di `OCA:`, ambang APFS di `OCJS:`, entri boot di `OCB:`).
**Untuk melihat durasi tahap OC, cari segmen dengan lompatan detik terbesar di antara dua baris `OCB:`/`OCA:` yang berdekatan.**

### 2.2 Tahap kernel / driver (`dmesg` + `log show`)

| Baris log | Makna |
|---|---|
| `auto-go: go(2) in <N> ms (BAR1 placed outside the console \| not placed)` | **★ baris paling berharga** —— `N` adalah jumlah milidetik yang **dihidupkan driver secara aktif** sebelum arm display; bagian dalam kurung adalah hasil penempatan BAR1 |
| `nv_get_firmware ... gsp_ga10x.bin` | Pemuatan firmware GSP dimulai (setelah `go(2)`) |
| `boot hold RELEASED (display armed) — WindowServer's IOKitWaitQuiet may return` | Driver melepas registry; **tunggu sebelum baris ini akan langsung menunda desktop** |
| `boot raster: head 0 … 60.000 Hz MEASURED` / `armed raster <WxH> pclk <f>` | Pengukuran raster selesai (`pclk 148500000` = 60 Hz) |
| `head N not running` | Head lainnya tidak sedang dipindai (`nvfbheads=4` tidak berarti keempat head berjalan) |
| `setDetailedTimings: … that is the current mode now (NO MODESET)` | Pengambil alih **tidak mengubah mode** ⇒ layar hitam bukan akibat pergantian mode |
| `Previous shutdown cause:` | Apakah shutdown sebelumnya normal (panic / mati listrik) |

### 2.3 Tahap userspace (`launchd.log`)

Perhatikan **waktu kemunculan pertama service kunci** (detik relatif terhadap boot) dan **jumlah event per detik** (jumlah baris rendah = menganggur):

```bash
for s in WindowServer loginwindow Dock Finder coreservicesd; do
  t=$(grep -m1 "$s" /var/log/com.apple.xpc.launchd/launchd.log | cut -c1-23)
  echo "  $s: ${t:-?}"
done
```

## 3. ★ Kasus hasil ukur di mesin ini (bisa langsung dipakai sebagai template)

### 3.1 "Setiap boot selalu menunggu ekstra ~102 detik" (bug driver, tahap B)

**Gejala**: dari boot sampai Finder siap ≈ **3 menit 17 detik**; linimasa userspace `launchd +5s`, `WindowServer +8s`, **`+34s→+71s macet 37 detik (log kosong total)`**, sesi pengguna `+72s`, **Finder `+197s`**.

**Bukti**: pasangkan "start driver" dengan "pelepasan hold", **kelima putaran boot semuanya 101–103 detik, tanpa selisih satu detik pun ⇒ biaya tetap, bukan kejadian acak**:

| Start driver (memegang hold) | Memuat firmware GSP | Melepas hold | start→firmware | firmware→lepas |
|---|---|---|---|---|
| 21:24:38.360 | 21:26:20.104 | 21:26:24.023 | **+102.0 s** | +4.0 s |
| 22:06:37.182 | 22:08:19.083 | 22:08:22.992 | **+102.0 s** | +3.0 s |
| 23:05:30.485 | 23:07:13.889 | 23:07:17.785 | **+103.0 s** | +4.0 s |

**Baris akar masalah** (`NVRM.cpp:328`, pada era 1.0.9 adalah 324):
```c
fAutoGoSettleMs = bar1Placed ? 500 : 100000;   // BAR1 tidak ditempatkan ⇒ tidur buta 100 detik
// baris berikutnya adalah titik override: PE_parse_boot_argn("nvrmsettle", ...)
```

Rantai sebab-akibat: BAR1 tidak ditempatkan → `fAutoGoSettleMs=100000` → `autoGo` lebih dulu melakukan `IOSleep(100s)` **baru** memuat firmware GSP dan arm display
→ registry busy selama boot hold → `IOKitWaitQuiet` milik WindowServer terhalang ~106 s → desktop tertunda ke `+197s`.

**Solusi**: tambahkan **`nvrmsettle=<ms>`** ke boot-args. Hasil ukur sebelum/sesudah di mesin yang sama **`+197 s → +94 s`, hemat 103 detik**; `5000` sudah cukup (mesin ini memakai `1500`). Upstream issue **#23** (closed/DONE).

> ★ **Sejak 1.14 installer otomatis menambahkan `nvrmsettle=10000`, tetapi hanya untuk kartu Turing** (`case "$NVDEV" in 1[eEfF]??|21[89a-fA-F]?)`) —
> **Ampere (seperti `10de:2206` di mesin ini) tidak termasuk ⇒ harus dipertahankan secara manual**. Dan nilai default `100000` itu **tidak berubah sama sekali** di 1.15.0.

### 3.2 "Sisa ~60 detik" (iGPU tanpa driver membebani `IOGraphicsFamily`, tahap B)

**Gejala**: setelah menambahkan `nvrmsettle` masih lambat.

**Akar masalah**: **Intel UHD 770 tanpa driver** yang ter-enumerate di motherboard membuat bring-up `IOGraphicsFamily` menunggunya.
**Solusi**: tambahkan **`-wegnoigpu`** ke boot-args (sembunyikan iGPU) ⇒ **91 s → 27 s**. Akhirnya **137 s → 28 s**. Upstream issue **#35** (closed/DONE).

> Perhatikan perbedaannya: pada 10-09 di mesin ini teramati "**boot dengan iGPU mencapai WindowServer dalam 15 s, tanpa regresi 91 s**" —
> yaitu status `GPUCDetect` **bukan** syarat yang cukup untuk "celah". **Lihat angka detiknya, jangan hanya satu flag status.**

### 3.3 "Teks bergulir lama sekali antara masuk picker hingga boot" (tahap A)

Lihat `logs-and-debug.md` §1: layar yang dibanjiri teks pada tahap OC dikendalikan oleh bit **`0x02` (konsol)** pada `Misc>Debug>Target`.
Hasil ukur di mesin ini: log OC **712 baris / 262 KB, tahap OC 33 s**; setelah `Target` diubah dari `71 (0x47)` → `69 (0x45)`, layar tidak lagi bergulir.
**Ini sepenuhnya independen dari `-v` pada boot-args** (`-v` mengatur tahap macOS).

## 4. Sumber durasi yang umum dan penanganannya

| Gejala | Tahap yang paling mungkin | Baris bukti | Penanganan |
|---|---|---|---|
| Setiap boot selalu menunggu ekstra ~100 s | B | `auto-go: go(2) in 100000 ms (BAR1 not placed)` | `nvrmsettle=<ms>` (#23) |
| Setelah ditambah settle masih lambat ~60 s | B | `IOGraphicsFamily` menunggu / iGPU tanpa driver | `-wegnoigpu` (#35) |
| Teks bergulir di layar pada tahap picker, lama | A | jumlah baris log OC / `Target` | hapus `0x02` dari `Target` |
| Berputar lama setelah logo Apple, ada celah di log | B/C | celah launchd + jendela `log show` | lihat §1.2 untuk selidiki |
| Sebuah kext memperlambat | A | log OC `OCB: Registering entry` | pemangkasan kext (`disks-and-kexts.md`) |
| Menunggu `Misc>Boot>Timeout` | A | picker tertahan | ubah `Timeout` (**preferensi yang terlihat pengguna, tanyakan dulu**) |

## 5. Poin metodologi

1. **Ukur ketiga tahap secara terpisah**, jangan menyimpulkan dari satu angka "total boot berapa lama".
2. **Tetap vs acak**: selaraskan pasangan baris log yang sama di beberapa putaran boot; detik yang konsisten ⇒ biaya tetap (perubahan konfigurasi/driver); besarnya berfluktuasi ⇒ ketergantungan/race.
3. **Celah = bukti**: "pada periode tertentu log kosong total" itu sendiri sudah merupakan kesimpulan (berarti macet di tempat **yang tidak menghasilkan keluaran log**, biasanya bring-up perangkat keras atau tunggu sinkronisasi).
4. **Tanyakan dulu "macet di tahap mana", baru putuskan log mana yang dicek**; bila filter waktu `log show` tidak bisa dipercaya, selalu gunakan **filter streaming**.
5. **Durasi di sisi driver harus dibandingkan dengan upstream issue** (#23 / #35 dari `nullmoth/nvidia-macos-driver`) —— "keterlambatan misterius" di mesin ini kemungkinan besar adalah **nilai default upstream yang sudah dikenal**, bukan konfigurasi Anda yang salah.
