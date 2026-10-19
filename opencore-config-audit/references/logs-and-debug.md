# Pengumpulan bukti log dan sakelar debugging

## 1. Dua sumber "banjir layar" yang saling independen

| Bancaran terjadi | Apa yang mengendalikannya | Cara mematikannya |
|---|---|---|
| **Antara masuk selector → diserahkan ke macOS** | Bit **`0x02` (Enable basic console logging)** dari `Misc>Debug>Target` | Hapus `0x02` dari `Target` (contoh: `71 (0x47)` → `69 (0x45)`) |
| **Setelah diserahkan ke macOS** | **`-v`** pada boot-args | Hapus `-v` (= "Turn verbose off" di app 1401); bila perlu melihatnya sementara, tekan **CMD+V** saat boot (butuh `PollAppleHotKeys=true`) |

Kalimat asli dokumen: *"Unless Target enables console (onscreen) printing, onscreen debug output will not be visible."*

## 2. Definisi bit `Misc>Debug>Target` (dokumen)

| Bit | Arti |
|---|---|
| `0x01` | Merekam (selain itu semua dibuang) |
| `0x02` | Log **konsol (layar)** |
| `0x04` | Data Hub |
| `0x08` | Port serial |
| `0x10` | Variabel UEFI |
| `0x20` | Variabel UEFI **non-volatil** (dokumen menyebut Warning: bisa bermasalah saat firmware memiliki cacat daur ulang NVRAM) |
| `0x40` | Menulis ke file (di root ESP `opencore-YYYY-MM-DD-HHMMSS.txt`) |
| `0x80` | Bersama `0x40`, log file yang lebih cepat tetapi tidak aman |

## 3. Definisi bit `Misc>Debug>DisplayLevel` (dokumen)

| Bit | Arti |
|---|---|
| `0x02` | DEBUG_WARN |
| `0x40` | DEBUG_INFO |
| `0x00400000` | DEBUG_VERBOSE |
| `0x80000000` | DEBUG_ERROR |

**Nilai wajar untuk "debug biasa"**: `Target = 0x45 (69)` (rekam + DataHub + file, tanpa tampil di layar),
`DisplayLevel = 0x80000042` (ERROR + INFO), `AppleDebug=true`, `ApplePanic=true`, `DisableWatchDog=true`.
**"Debug lengkap" = tambahkan `0x08/0x10/0x20` ke Target dan `0x00400000` ke DisplayLevel** — kecuali sedang menelusuri masalah boot, ini tidak diperlukan.

## 4. Tiga cara membaca log OpenCore

```bash
# ① File (hanya bila Target mengandung 0x40; di root ESP, batas 256 KB)
ls -lt /Volumes/EFI/opencore-*.txt | head
# ② DataHub (Target mengandung 0x04; tetap bisa dibaca walau konsol dimatikan, metode dari dokumen)
ioreg -lw0 -p IODeviceTree | grep boot-log | sort | sed 's/.*<\(.*\)>.*/\1/' | xxd -r -p
# ③ Variabel UEFI (Target mengandung 0x10, batas log 32 KB)
nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:boot-log | awk '{gsub(/%0d%0a%00/,"");gsub(/%0d%0a/,"")1}'
```

Format baris log: `mm:sss interval OCmodule: message`. Kolom pertama adalah **detik relatif sejak boot**, pakai itu untuk menganalisis durasi tiap tahap.

> **Untuk "boot sangat lambat", gunakan bersama `references/boot-timeline.md`** — di sana boot dipecah menjadi tiga bagian: **segmen OC / segmen driver kernel / segmen user-space**,
> disertai metode melokalisasi jendela jeda dan tabel penanganan sumber waktu tempuh (termasuk cara memakai **filter streaming** bila filter waktu `log show` gagal).

## 5. Kriteria kunci di dalam log OC

| Baris log | Kegunaan |
|---|---|
| `OCABC: MAT support is 1/0` | Menentukan apakah `EnableWriteUnprotector` sebaiknya dimatikan (dokumen menunjuk baris ini) |
| `OCABC: Only N/256 slide values are usable!` | Menentukan apakah `ProvideCustomSlide` diperlukan |
| `OCABC: ALRBL 1 RTDFRG 1 … WRUNPROT 1 CLRTS 0` | Nilai efektif sebenarnya dari tiap Booter quirk (ALRBL=AllowRelocationBlock, RTDFRG=AvoidRuntimeDefrag, SMSLIDE=EnableSafeModeSlide, WRUNPROT=EnableWriteUnprotector…) |
| `OCABC: … CSLIDE 1 MSLIDE 0 … RBMAP 1 VMAP 1 RTPERMS 1 ARBAR -1` | ProvideCustomSlide / ProvideMaxSlide / RebuildAppleMemoryMap / SetupVirtualMap / SyncRuntimePermissions / ResizeAppleGpuBars |
| `OCA: Found N ACPI tables` + `Detected table SIG (OEM ID) … at index N` pada tiap tabel | Daftar lengkap ACPI firmware; OEM ID adalah 8 byte heksadesimal (ASCII little-endian) |
| `OCA: Deleting table … with <ID> ID at index N` | Apakah `ACPI>Delete` kena sasaran (pada mesin ini `xh_adls3` dipastikan lewat cara ini) |
| `OCA: Inserted table SSDT (OEM …) of N bytes into ACPI at index M` | Hasil injeksi `ACPI>Add` (bisa mencocokkan identitas dan ukuran tabel) |
| `OCJS: APFS driver <ver>/<date> found …, required >= X/Y, allow|refuse` | Penentuan ambang `UEFI>APFS>MinDate/MinVersion` — **wajib** melihat baris ini setelah diubah dari `-1` |
| `OCB: Registering entry <nama> [<tipe>]` | **Entri boot apa yang benar-benar ada** di selector (satu-satunya dasar yang dapat diandalkan untuk menilai efek "pemblokiran") |
| `OCB: Not adding hidden auxiliary entry …` | Entri yang disembunyikan oleh `HideAuxiliary=true` |
| `OCUI: Failed to load image … - Not Found` | Fallback normal setelah OpenCanopy mendeteksi **ikon opsional**; ketiga set ikon resmi hanya punya 25 file, jangan "melengkapi" |
| `OC: WARN/ERROR` / `OCB: ERROR` | Kesalahan masa boot (seharusnya nol) |

## 6. Kernel log sisi macOS (butuh hak akses tinggi)

Di dalam sandbox `log show` tidak tersedia; jalankan dengan **AppleScript berpermission tinggi** (`scripts/grab-logs.sh` sudah membungkusnya):

```bash
osascript -e 'do shell script "/bin/bash <script>" with administrator privileges'
```

Di dalam skrip, tulis output ke file lalu `chmod 644` agar bisa dibaca user biasa.

**Daftar kriteria (ACPI / platform)**

| Yang diambil | Penjelasan |
|---|---|
| `grep -aiE "acpi error\|ae_not_found\|ae_already\|namespace lookup\|Error evaluating"` | **0 hit = ACPI tidak rusak**, ini "kriteria pertama" untuk menentukan apakah perlu menambahkan SSDT |
| `(AppleACPIPlatform) FACP/FACS/DSDT/XSDT …` | Daftar tabel yang benar-benar di-parse di sisi macOS (bandingkan dengan log OC; membuktikan "apakah sebuah tabel benar-benar ada") |
| Tidak ada DMAR di dalam `(AppleACPIPlatform)` | Artinya firmware tidak mengekspos VT-d |
| `(AppleAHCIPort) … COMRESET did not proceed` + `PxSSTS 0x4` | Port tersebut **PHY offline** (port kosong); lihat dulu `ioreg -r -c IOAHCIDevice` apakah ada perangkat anak sebelum menyimpulkan |
| `(AppleUSBXHCI) createPorts: speed index N has inconsistent speed IDs` | Umumnya tidak berbahaya |
| `Previous shutdown cause:` | Apakah shutdown sebelumnya normal |
| `AppleIGC (isOpen(forClient) == 1)` | Apakah driver kartu jaringan I225-V benar-benar membuka perangkat |

**Poin penting perintah**: `log show` mengeluarkan output **lama→baru**, `| head -N` hanya menyisakan batch paling awal ⇒ wajib `--start "<waktu boot>"` atau gunakan `tail`.
Waktu boot diambil dari `sysctl -n kern.boottime`.

## 7. Peringatan "salah menilai" yang umum

- `Not Found` bertubi-tubi di log ≠ ada masalah: variabel NVRAM, partisi preboot APFS, dan ikon opsional OpenCanopy semuanya bisa memunculkannya.
- "Tabel tertentu tidak muncul di log OC" — pastikan dulu apakah `Target` mengandung `0x40` (di mesin ini pernah muncul gejala aneh "beberapa kali boot hari ini tidak menghasilkan log").
- Melihat pesan sisi driver seperti `X: no driver attached`, bedakan dulu apakah itu fase **OC** atau fase **kext** (yang kedua muncul di `log show` dengan prefiks `(KextName)`).
