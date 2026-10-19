# Jebakan yang pernah didekati (gejala → penyebab → cara yang benar)

## A. Konfigurasi/konsep

| Gejala | Penyebab | Cara yang benar |
|---|---|---|
| Setelah memblokir dengan `ScanPolicy`, **Windows tidak bisa boot** | `ScanPolicy` adalah **kebijakan keamanan** (membatasi pemindaian sumber yang tidak dipercaya), bukan sakelar tampilan | Pertahankan `ScanPolicy=0`; untuk menampilkan lebih sedikit pakai `HideAuxiliary` / `Misc>Entries` |
| Mengira setelah `ocvalidate` lolos semuanya beres | Yang diperiksa hanya schema / tipe / wajib diisi / urutan | Apakah nilainya **sesuai dokumen** harus dibandingkan manual per kunci (lihat `official-docs-method.md`) |
| Khazir nama file SSDT berubah sehingga identitas tabel ikut berubah | Identitas tabel ditentukan oleh parsing **isi**, bukan nama file | Mengganti nama aman; asal `ACPI>Add>Path` ikut diubah |
| Menulis kunci `NVRAM>Add` tetapi tidak berlaku | Aturan dokumen: **hanya berlaku bila juga ada di `Delete`** | Setiap kunci di Add harus muncul di `Delete` |
| `plutil` melaporkan `Key path not found NVRAM.Delete.0.<GUID>` | `NVRAM>Delete` adalah **dict (GUID→array)**, bukan array | Path kuncinya ditulis `NVRAM.Delete.<GUID>` |
| `plutil -remove 'Kernel.Add.15'` salah hapus setelah menghapus beberapa | Setelah elemen array dihapus **indeksnya bergeser** | **Hapus dari indeks tinggi ke rendah** |
| Mengira `-wegnoigpu` / `-v` adalah "sakelar log" | Yang dipengaruhi adalah **bagian lain** (stack grafis macOS / verbose macOS), tidak terkait bagian OC | Saat atribusi "banjir layar", bedakan dulu bagian OC vs bagian macOS (lihat `logs-and-debug.md`) |
| Menyalakan "debug lengkap" tapi tidak mendapat informasi lebih banyak | Sebagian lapisan meng-hardcode makro verbose (contoh: `#define bootverbose 0` pada suatu port) | Pastikan dulu "siapa yang menyediakan data ini", baru putuskan sumber data yang akan diubah |

## B. Disk/partisi

| Gejala | Penyebab | Cara yang benar |
|---|---|---|
| Yang ditulis untuk `disk0/disk2` hilang saat boot berikutnya | **Nomor disk bisa bergeser** (dalam satu sesi, dua kali `diskutil list` bisa saling tertukar) | Selalu pakai **UUID volume**; ESP dicek langsung dengan `diskutil list \| grep "EFI EFI"` |
| `awk '/^\/dev\/disk/'` tidak menangkap partisi | Di dalam `diskutil list`, **identitas partisi tidak memakai prefiks `/dev/`** | Pakai `grep -oE 'disk[0-9]+s[0-9]+'` |
| Setelah menulis fstab, partisi EFI tidak bisa di-mount (khawatir) | — | **EFI tidak pernah ditulis ke fstab**; setelah menulis, cari ESP berdasarkan UUID lalu lakukan sekali lepas-pasang → pasang → baca config untuk verifikasi |
| Setelah melepas ESP, `PlistBuddy` melaporkan `File Doesn't Exist, Will Create` | ESP belum di-mount (bukan file yang rusak) | Cek dulu dengan `ls -d /Volumes/EFI` sebelum membaca/menulis |
| `diskutil mount <dev>` gagal dengan `failed to mount` pada pemanggilan biasa | Membutuhkan hak akses tinggi | Pakai `osascript -e 'do shell script "diskutil mount <dev>" with administrator privileges'` |
| Muncul file `._xxx` di ESP | AppleDouble yang dihasilkan macOS di atas FAT | Tidak berbahaya (OpenCore hanya membaca file sesuai path di dalam config); bila mengganggu, hapus saja |

## C. Log/pengumpulan bukti

| Gejala | Penyebab | Cara yang benar |
|---|---|---|
| `log show \| head -N` tidak menangkap isi boot ini | `log show` mengeluarkan output **lama→baru**, `head` hanya menyisakan batch paling awal | Pakai `--start "<waktu boot>"` atau gunakan `tail` |
| `log show` / `lsof` / `sudo` tidak tersedia di dalam sandbox | Batasan sandbox | AppleScript berpermission tinggi: `osascript -e 'do shell script "/bin/bash <script>" with administrator privileges'`; di dalam skrip tulis file lalu `chmod 644` |
| Path yang mengandung spasi di dalam skrip gagal secara senyap | `OUT=/Users/x/WorkBuddy AI/…` dianggap "assignment + perintah" | Selalu pakai `OUT="…"` dengan tanda kutip |
| `opencore-*.txt` tidak ditemukan di ESP | `Target` tidak mengandung `0x40`, atau boot tersebut memang tidak menulis | Periksa `Target`; pakai cara baca DataHub (`0x04`) sebagai gantinya |
| Banyak `Not Found` di log dan menganggap rusak | Variabel NVRAM / partisi preboot APFS / ikon opsional OpenCanopy semuanya memunculkannya | Klasifikasikan dulu baru menilai (lihat `logs-and-debug.md` §7) |
| Ingin "melengkapi ikon" saat melihat `OCUI: Failed to load image … - Not Found` | Nama-nama tersebut **tidak ada di dalam set ikon resmi mana pun** | Jangan diubah; GoldenGate/Syrah/Chardonnay resmi masing-masing hanya punya 25 file `.icns` |
| Mengira `AppleAHCIPort … COMRESET did not proceed` berarti hard disk rusak | Port kosong (`PxSSTS 0x4` = PHY offline) juga memunculkan pesan itu | Lihat dulu `ioreg -r -c IOAHCIDevice` apakah ada perangkat anak, dan `diskutil list` apakah ada disk yang hilang |

## D. Alat/kolaborasi

| Gejala | Penyebab | Cara yang benar |
|---|---|---|
| Menggunakan Bash `grep` untuk mencari teks Mandarin/pola majemuk, lalu menyimpulkan "file tidak ada" | Bash `grep` pernah memberikan **false negative** untuk alternasi `\|` dan teks Mandarin | Verifikasi ulang dengan **Grep tool (ripgrep)** |
| Sesi terputus, dan di workspace hilang satu bagian utuh | **turn aborted melakukan rollback perubahan file workspace** | Setelah terputus, periksa dulu apakah file masih ada (laporan/skrip/backup) |
| Setelah `git push \| sed` tidak mendapatkan exit code | Pipa menelan exit code | Jangan menyambungkan `git push` ke pipa; bila perlu filter, simpan ke file dulu |
| GitHub API melaporkan `SSL_ERROR_SYSCALL` | Penyusunan path API salah | Path **wajib diawali `/`** (`/repos/...`, bukan `repos/...`) |
| Mengira "ID sama = terunggah dua kali" | Content-addressed: konten sama mengembalikan ID yang sama | Bandingkan sha256 dulu sebelum menyimpulkan |
| Tidak melihat receipt lokal sebelum melapor | Sisi server/klien mungkin hanya melaporkan sebagian | Baca dulu file receipt/checklist lokal (misalnya `upload-receipt.json`), cocokkan jumlah entri dan sha |
| Skrip melaporkan `unbound variable`, dan nama variabelnya tampak kacau | Ketika **`$VAR` diikuti langsung karakter full-width** (misalnya kurung tutup full-width, koma full-width, titik dua full-width, atau `★`), bash menganggap byte multi-byte sebagai bagian dari nama variabel | Tulis **`${VAR}`**; setelah menulis, sisir sekali: `awk 'match($0, /\$[A-Za-z_][A-Za-z0-9_]*[^ -~]/)' *.sh` |
| Perilaku aneh/bercampur setelah mengganti build OpenCore | Hanya `OpenCore.efi` yang diganti, Drivers tidak (pada versi yang sama, isi **seluruh** Drivers RELEASE/DEBUG berbeda) | Ganti juga Drivers **resmi dengan nama sama**, pertahankan driver pihak ketiga (`scripts/oc-swap-build.sh` sudah menerapkan ini) |

## F. Entri boot firmware (NVRAM `Boot####` / `LauncherOption`)

| Gejala | Penyebab | Cara yang benar |
|---|---|---|
| **Setelah boot sekali dari flash disk, entri OpenCore di hard disk hilang dari menu boot BIOS, tinggal Windows** | `Misc>Boot>LauncherOption=Full` membuat OpenCore setiap kali boot memelihara "entri miliknya sendiri", dan itu **hanya mengenali entri berdasarkan sufiks path file (`OpenCore.efi`), tanpa melihat perangkat** ⇒ saat boot dari flash disk entri hard disk itu ** diarahkan ulang ke flash disk**; setelah flash disk dicabut perangkatnya tidak ada ⇒ firmware membersihkannya | **Ubah `LauncherOption=Disabled` di kedua ESP** + pertahankan `\EFI\BOOT\BOOTx64.efi` sebagai jaring pengaman ⇒ lihat `boot-entries.md` |
| Ingin menjalankan `bcfg boot add/rm` secara manual tetapi tidak berhasil | `UEFI>Quirks>RequestBootVarRouting=true` **melindungi NVRAM** | Jalankan dulu `OpenControl.efi disable`, lalu reboot atau `OpenControl restore` |
| Membuat `Boot0000` secara manual di papan **ASUS** | Komentar di kode sumber: ASUS menganggap `Boot0000` sebagai "sudah dihapus" | **Jangan pakai `Boot0000`** — akibatnya entri menjadi duplikat, bahkan BIOS bisa brick |
| `Boot####` tidak terlihat di `nvram -p`, dianggap tidak ada entri boot | `nvram -p` **tidak mencantumkan** `Boot####` | Baca satu per satu dengan format `GUID:nama`: `nvram 8BE4DF61-93CA-11D2-AA0D-00E098032B8C:BootOrder` |
| Menyamakan "entri di menu boot BIOS" dengan "entri di selector OpenCore" | Yang pertama adalah **NVRAM firmware** (`Boot####`), yang kedua hasil pemindaian OpenCore | Untuk menampilkan lebih sedikit sistem pakai `ScanPolicy`/`HideAuxiliary`; untuk entri boot yang hilang lihat `boot-entries.md` |
| Di macOS, `nvram <GUID>:Boot0001=…` melaporkan **`(iokit/common) general error`** | ★ Bukan masalah pengalihan arah, tapi **tidak punya hak akses tinggi** — hasil uji di mesin ini: tanpa hak akses tinggi bahkan **variabel biasa** tidak bisa ditulis | Pakai Terminal + `sudo`, atau AppleScript berpermission tinggi (`do shell script "…" with administrator privileges`).★ `dump`/`backup` tidak butuh hak akses tinggi |
| Menganggap hasil **baca ulang** `nvram` yang sama berarti "entri boot sudah masuk ke firmware" | `RequestBootVarRouting=true` mengalihkan `Boot*` ke `OC_VENDOR:OCBt*`, **baca dan tulis sama-sama lewat pengalihan yang sama** ⇒ hasil baca ulang yang sama tidak membuktikan masuk ke firmware | **Verifikasi hanya melihat BIOS setelah restart** (atau baris `OCB:` di log boot). Untuk memastikan masuk ke firmware ⇒ biarkan OpenCore menulisnya sendiri (`LauncherOption=Full`) |
| Menulis kembali nilai yang dibaca dari `nvram` **apa adanya** dan gagal | Pada output macOS, **`0x20` adalah spasi literal**, sedangkan `nvram` memperlakukan spasi literal di dalam nilai sebagai **pemisah argumen** | **Enkode ulang secara seragam** sebelum menulis (setiap byte ditulis sebagai `%XX`), jangan menyalin output `nvram` mentah |

## E. Disiplin alur kerja

- **Ubah satu hal saja**; untuk perubahan massal, sebutkan satu per satu di laporan "apa yang diubah / berdasarkan apa / bagaimana cara rollback"
- Sebelum mengubah **baca dulu yang live lalu bandingkan dengan diff** (mungkin ada skrip lain yang menulis secara bersamaan)
- Setelah mengubah **segera**: `plutil -lint` → `ocvalidate` → hitung sha → sinkronkan mirror dan arsip versi → `sync`/lepas-pasang/verifikasi ulang
- Sisipkan seksi "**tidak diubah secara sengaja**" beserta alasannya di laporan, agar lain kali tidak ada yang rusak karena "mengembalikan ke default"
