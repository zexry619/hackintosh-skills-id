# Menerbitkan ke WorkBuddy

> Memasang skill dari repo ini ke WorkBuddy punya **dua rute**, lihat tabel ini dulu untuk memilih salah satu.

| | **Rute A: repo marketplace sendiri** (disarankan, **repo ini sudah dikonfigurasi**) | **Rute B: publikasikan ke SkillHub** |
|---|---|---|
| Ditujukan untuk | Distribusi publik / berbagi terbatas / internal tim | Masuk ke toko skill publik agar bisa dicari |
| Cara pengguna memasang | `/plugin marketplace add GeekAudio/hackintosh-skills` lalu `/plugin install …` | Menjelajah dan memasang di **<https://skillhub.cn>** |
| **Di mana dioperasikan** | Repo Git Anda | **Web: <https://skillhub.cn>** (submit setelah login) |
| Perlu ditinjau? | **Tidak** | Ada validasi / mekanisme seleksi di sisi platform |
| Perlu akun? | Tidak (cukup ada repo publik) | **Perlu** akun SkillHub |
| Cara pembaruan | Setelah diubah, `git push` saja, sisi pengguna menyinkronkan metadata marketplace | Ulangi seluruh alur submit |

---

## Rute A: repo marketplace sendiri

### A.1 File yang sudah dikonfigurasi di repo ini

```
hackintosh-skills/
├── .codebuddy-plugin/
│   └── marketplace.json          ← manifest marketplace (wajib, tanpa ini seluruh repo tidak tampil)
└── opencore-config-audit/
    ├── .codebuddy-plugin/
    │   └── plugin.json           ← metadata plugin
    ├── SKILL.md                  ← isi skill
    ├── USAGE.md
    ├── references/  scripts/
```

### A.2 Cara pengguna memasang (tiga langkah)

```bash
# ① Tambahkan marketplace
/plugin marketplace add GeekAudio/hackintosh-skills

# ② Pasang plugin (<nama plugin>@<nama marketplace>)
/plugin install opencore-config-audit@hackintosh-skills
```

> Pintasan: `/plugin market` = `/plugin marketplace`; `rm` = `remove`.
> Anda juga bisa menjalankan `/plugin` lalu menelusuri tab "Temukan".

**Sumber lain untuk menambahkan marketplace** (semuanya didukung):

```bash
/plugin marketplace add https://gitlab.com/team/plugins.git      # Host Git lain
/plugin marketplace add https://gitlab.com/team/plugins.git#v1.0.0   # Tentukan branch/tag
/plugin marketplace add ./my-marketplace                          # Direktori lokal (untuk pengembangan/debug)
/plugin marketplace add https://example.com/marketplace.json      # Hosting HTTP
```

> ⚠️ **Marketplace bertipe URL** (alamat HTTP langsung ke marketplace.json) tidak mendukung **path relatif** dengan baik,
> saat dipasang bisa muncul error "path tidak ditemukan" ⇒ **prioritaskan tipe Git** (`owner/repo`).

### A.3 Penjelasan field (schema resmi)

**`.codebuddy-plugin/marketplace.json` (manifest marketplace)**

| Field | Tipe | Wajib | Keterangan |
|---|---|---|---|
| `name` | string | ✅ | Identifier marketplace (kebab-case, tanpa spasi) |
| `owner` | object | ✅ | Info pengelola marketplace (`name` / `email`) |
| `plugins` | array | ✅ | Daftar plugin yang tersedia |
| `description` | string | | Deskripsi singkat marketplace |
| `version` | string | | Versi marketplace |

**Setiap entri di `plugins[]`**

| Field | Tipe | Wajib | Keterangan |
|---|---|---|---|
| `name` | string | ✅ | Identifier plugin (kebab-case, tanpa spasi) |
| `source` | string/object | ✅ | Sumber pengambilan plugin (lihat di bawah) |
| `description` | string | ✅ | Deskripsi singkat plugin |
| `version` | string | | Versi plugin |
| `author` | object | | Info penulis |
| `homepage` / `repository` | string | | URL halaman utama / repo kode sumber |
| `license` | string | | Identifier SPDX (misal `MIT`) |
| `keywords` | array | | Tag untuk penemuan dan klasifikasi |
| `category` | string | | Kategori plugin |
| **`strict`** | boolean | | **Bawaan `true`**: direktori plugin **harus** berisi `plugin.json`.<br>Jika `false`, `plugin.json` opsional dan entri ini sudah menjadi manifest lengkap |
| `commands` / `agents` / **`skills`** / `hooks` / `mcpServers` | string/array/object | | **Override path komponen** — menentukan posisi tiap komponen |

**Tiga cara menulis `source`**

```jsonc
// ① Path relatif dalam repo yang sama (yang dipakai repo ini)
"source": "./opencore-config-audit"

// ② Repo GitHub
"source": { "source": "github", "repo": "owner/plugin-repo" }

// ③ URL Git sembarang
"source": { "source": "url", "url": "https://gitlab.com/team/plugin.git" }
```

**`.codebuddy-plugin/plugin.json` (metadata plugin)**

Field sama seperti di atas (`name` / `version` / `description` / `author` / `repository` / `license` / `keywords` / `category`),
ditambah **path komponen**:

| Field | Keterangan |
|---|---|
| `skills` | Path Skill. **Repo ini menulis `["./SKILL.md"]`** — langsung menunjuk ke `SKILL.md` di root plugin, jadi layout yang ada tidak perlu diubah |
| `commands` / `agents` / `hooks` / `mcpServers` | Perintah / Agent / hook / server MCP |

### A.4 Menambahkan skill baru

1. Buat direktori `my-new-skill/` di root repo, isi dengan `SKILL.md` (wajib), `USAGE.md`, `references/`, `scripts/`
2. Buat `my-new-skill/.codebuddy-plugin/plugin.json`, jangan lupa **`"skills": ["./SKILL.md"]`**
3. Tambahkan satu entri di `plugins[]` pada `.codebuddy-plugin/marketplace.json` di root, `"source": "./my-new-skill"`
4. Validasi JSON agar valid → `git push` (terlihat setelah sisi pengguna menyinkronkan metadata marketplace)

### A.5 Pemeriksaan mandiri sebelum rilis

```bash
# ① Sintaks JSON
python3 -c "import json;[json.load(open(p)) for p in ['.codebuddy-plugin/marketplace.json',
  'opencore-config-audit/.codebuddy-plugin/plugin.json']];print('JSON OK')"

# ② Setiap skill tetap valid
python3 <skill-creator>/scripts/quick_validate.py opencore-config-audit

# ③ Direktori yang ditunjuk `source` benar-benar ada, dan berisi .codebuddy-plugin/plugin.json

# ④ ★ Pemeriksaan mandiri konsistensi dokumen (keselarasan indeks / tautan mati / nomor versi di tiga tempat / regresi klaim salah yang sudah dikenal)
bash tools/doc-lint.sh
# Jalankan sekaligus dengan redaksi data sebelum terbit:
bash tools/doc-lint.sh --with-redact
```

> **④ Mengapa layak dijalankan**: reference saling merujuk, satu kesimpulan yang salah akan menyebar lewat rantai referensi —
> skill ini pernah mengalaminya (persyaratan **iServices** dari Dortania diperluas secara keliru menjadi AirDrop yang bergantung pada `en0`,
> hasilnya 5 file semuanya salah tulis). `doc-lint.sh` menulis jenis "klaim salah yang sudah dikenal" itu sebagai aturan,
> dan memeriksa apakah setiap reference / script sudah terindeks di `SKILL.md` (terlewat diindeks = model tidak akan pernah membacanya).
> Kode keluar 0 = bersih, 1 = ada peringatan.

### A.6 Masalah umum

| Gejala | Penyebab / penanganan |
|---|---|
| Marketplace ditambahkan tapi plugin tidak terlihat | Path `marketplace.json` salah (harus berada di `.codebuddy-plugin/` pada root repo), atau sintaks JSON salah |
| Plugin terpasang tapi skill tidak tampil | Bersihkan cache: `rm -rf ~/.workbuddy-ai/plugins/cache`, restart lalu pasang ulang |
| Setelah memasang muncul "file tidak ditemukan" | **Plugin disalin ke cache**, sehingga **path di luar direktori plugin tidak bisa dipakai** — semua resource harus berada di dalam direktori plugin |
| Marketplace bertipe URL melaporkan error path | Beralih ke marketplace tipe Git (`owner/repo`) |

---

## Rute B: publikasikan ke SkillHub (toko skill publik)

### ★ Bedakan dulu tiga hal yang mudah tertukar

| Yang Anda kira | Sebenarnya apa | Apakah itu "publikasi ke toko" |
|---|---|---|
| Panel skill WorkBuddy → **"Unggah Skill"** | Judul pop-up sebenarnya **`Import Skill`** — mengimpor skill **ke pustaka / proyek milik Anda sendiri** | ❌ **Bukan** (ini impor lokal) |
| **"Unggah ke WorkBuddy Cloud"** di pengaturan skill | Teks aslinya: *"{names} will be available in **cloud sessions** after upload"* — menyinkronkan ke **sesi cloud milik Anda sendiri** (sakelar fitur `EnableSkillToCloud` **bawaan nonaktif**) | ❌ **Bukan** (ini sinkronisasi cloud Anda sendiri) |
| **`https://skillhub.cn`** | **SkillHub — komunitas AI Skills yang dioptimalkan untuk pengguna Tiongkok** (dihosting di Tencent Cloud), dengan pilihan terbaik, kategori, jumlah unduhan/bintang, skill berbayar, zona perusahaan, dan kompetisi | ✅ **Inilah tokonya** |

### B.1 Toko dan alamat API

| Kegunaan | Alamat |
|---|---|
| **Website toko (untuk manusia)** | **<https://skillhub.cn>** |
| Halaman daftar skill | `https://skillhub.cn/skills` |
| **Tutorial** | `https://skillhub.cn/tutorials` ← **lihat ini dulu sebelum publikasi** |
| **Dokumentasi verifikasi tanda tangan** | `https://skillhub.cn/docs/verify-signature` ← terkait dengan validasi publikasi |
| Kompetisi / pemenang | `https://skillhub.cn/contest` · `/contest/winners` |
| Zona perusahaan | `https://skillhub.cn/enterprise-zone` |
| API skill | `https://api.skillhub.cn` — `/api/skills` (daftar) · `/api/v1/categories` (kategori) · `/api/v1/search?q=` (pencarian semantik) |
| Halaman detail skill | `https://api.skillhub.cn/<penulis>/<slug>` (contoh: `/indiv-ebandao/dev-expert`) |
| Gateway sisi aplikasi | `https://lightmake.site` (WorkBuddy memakainya secara internal untuk mengambil daftar/pencarian/kategori) |

> `robots.txt` + `sitemap.xml` situs ini publik, semua route di atas berasal dari sana.

### B.2 Sebelum publikasi: siapkan paketnya

```bash
python3 <skill-creator>/scripts/package_skill.py opencore-config-audit ./dist
# → dist/opencore-config-audit.zip (memuat SKILL.md dengan YAML name + description)
```

**Pemeriksaan mandiri**:

```bash
# ① Konten
python3 - <<'EOF'
import zipfile
z='dist/opencore-config-audit.zip'; zf=zipfile.ZipFile(z); n=zf.namelist()
md=[x for x in n if x.endswith('/SKILL.md')][0]
fm=zf.read(md).decode('utf-8').split('---')[1]
print(z, '| SKILL.md ✅' if ('name:' in fm and 'description:' in fm) else '❌', '| jumlah file', len(n))
EOF

# ② ★ Redaksi data (wajib)
bash opencore-config-audit/scripts/redact-check.sh opencore-config-audit
# Kode keluar 0 = bersih; 1 = ada yang terdeteksi, tangani dulu sebelum dikemasan
```

> ★★ **Tiga kode (serial/MLB/UUID) + MAC yang dipakai ROM sama dengan identitas Apple mesin ini** (iMessage / FaceTime hanya mengenali mereka).
> **Unggah berarti langsung publik** — wajib jalankan `redact-check.sh` sekali sebelum dikemasan, lalu periksa manual sekali lagi.

### B.3 Publikasi

**Buka <https://skillhub.cn> di browser** → login → cari pintu masuk submit/publikasi (lihat dulu `/tutorials`).

> ⚠️ **Pintu masuk spesifiknya tidak bisa saya pastikan untuk Anda**: situsnya SPA dan pintu masuk submit ada setelah login,
> dari sisi saya hanya bisa mengambil HTML kerangka dengan curl, tidak melihat tampilan setelah login. **Ikuti tutorial di dalam situs.**

### B.3.1 ★ Saat submit akan muncul pemeriksaan "overhaul pembayaran Alipay" — **klik "Tetap submit" saja**

Saat mengirim dokumentasi teknis murni, platform akan menampilkan kotak konfirmasi **"Sebagian pemeriksaan overhaul pembayaran Alipay lolos"** yang mencantumkan 5 "item yang hilang":

| Item yang hilang | Apa itu |
|---|---|
| 402 penerbitan tagihan | Alur **penerbitan tagihan** dari protokol pembayaran Alipay |
| Retry dengan bukti | Mengirim bukti saat mencoba ulang pembayaran |
| Panggilan verifikasi pembayaran | Memanggil verifikasi pembayaran Alipay |
| Konfirmasi pemenuhan | Konfirmasi pemenuhan setelah pembayaran |
| Persistensi dan idempotensi pesanan | Penyimpanan pesanan + idempotensi |

**⇒ Ini pemeriksaan untuk "skill berbayar (SkillPay)", tidak ada hubungannya dengan dokumentasi teknis gratis.**

Ketiga kalimat di pop-up itu menyatakan bahwa pemeriksaan ini **tidak berlaku dan tidak memblokir**:

- Kotak merah: *"skill ini adalah dokumentasi teknis murni… sama sekali tidak terkait dengan pembayaran/penagihan… **kelima ciri tidak terdeteksi**"*
- Bawah: *"**pemeriksaan ini tidak memblokir submit**"*
- Bawah: *"setelah submit, peninjauan platform akan mengulang pemeriksaan lengkap, dan akan ditolak bila tidak sesuai"*

**⇒ Klik "Tetap submit".** Kelima item itu memang **seharusnya tidak terdeteksi** untuk dokumentasi teknis gratis, bukan berarti skill Anda bermasalah.
(Hanya jika Anda benar-benar ingin membuat skill berbayar, barulah perlu mengikuti "Lihat panduan praktik terbaik overhaul pembayaran Alipay" dari pop-up itu.)

### B.3.2 ★ Setelah publikasi "tidak ditemukan" — bedakan dulu apakah masalahnya di sisi server atau di kata kunci pencarian

**Kesimpulan dulu**: pada kebanyakan kasus **bukan berarti belum dipublikasikan**, melainkan **kata kunci/kategori tidak cocok**. Periksa sesuai urutan berikut.

#### Langkah 1: pastikan server benar-benar punya (bisa dicek lewat dua API)

```bash
# ① Daftar kata kunci (dipakai untuk kategori/browsing)
curl -s "https://api.skillhub.cn/api/skills?keyword=hackintosh&page=1&pageSize=20"

# ② Pencarian semantik (dipakai oleh kotak pencarian)
curl -s "https://api.skillhub.cn/api/v1/search?q=hackintosh&limit=10"
```

Kalau di respons ditemukan `slug` + `namespace.canonicalName` (misal `@user_b1ac2e69/hackintosh`) ⇒ **sudah dipublikasikan dan sudah diindeks**.
⇒ berarti **bukan masalah publikasi**, lanjutkan ke bawah.

#### Langkah 2: ganti kata kunci (★ jebakan paling umum)

**Pencarian semantik sangat buruk untuk kata pendek/general.** Hasil uji (skill yang sama):

| Cara mencari | Hasil |
|---|---|
| `q=hackintosh` | ✅ ketemu |
| `q=instalasi apel hitam` (**nama lengkap**) | ✅ ketemu |
| `q=apel hitam` | ❌ **tidak ketemu** |
| `q=OpenCore` | ❌ **tidak ketemu** |
| `keyword=apel hitam` (API daftar) | ✅ ketemu |
| `keyword=OpenCore` (API daftar) | ✅ ketemu |

⇒ **Kotak pencarian di dalam aplikasi (memakai pencarian semantik) sebaiknya memakai "hackintosh" atau nama lengkap skill**;
hanya mencari kata umum seperti "apel hitam" atau "OpenCore", recall semantis bisa gagal mengembalikan hasil.

#### Langkah 3: pastikan Anda mencari di kotak pencarian yang mana

| Lokasi | Yang dicari |
|---|---|
| **Panel skill → tab SkillHub** | ✅ **Toko cloud** (cari barang yang sudah dipublikasikan di sini) |
| Panel skill → tab **Terpasang** | Yang sudah terpasang secara lokal |
| Ketik **`/`** di kolom input | **Skill yang sudah terpasang lokal** — ★ **publikasi tidak otomatis muncul di sini, harus "dipasang" dulu** |
| Panel skill → kategori + urutan (semua / nilai gabungan / jumlah unduhan / pembaruan terbaru / jumlah pemasangan) | Menjelajah per kategori (memakai `/api/skills`) |

> ★ **Yang paling sering disalahpahami**: publikasi ke SkillHub **≠** muncul di daftar `/` Anda.
> Daftar `/` hanya menampilkan skill yang **terpasang lokal** — harus klik "Pasang" dulu di SkillHub.

#### Langkah 4: tidak terlihat di daftar bawaan itu wajar

SkillHub punya **190 ribu+** skill. Skill yang baru dipublikasikan punya `downloads / installs / stars = 0`,
jadi saat diurutkan berdasarkan "nilai gabungan / jumlah unduhan / pembaruan terbaru" **ada di urutan terakhir** ⇒ **hanya bisa ditemukan lewat pencarian atau tautan langsung**.
Ini bukan kegagalan.

#### ★ Agar lebih mudah ditemukan, ubah empat hal ini

| Item | Mengapa penting |
|---|---|
| **Deskripsi (`description`)** | ★★ **Jangan memakai seluruh deskripsi SKILL.md yang ratusan kata sebagai deskripsi toko** — vektor semantis akan terencerunkan, recall kata pendek makin buruk. **Tulis ringkasan yang fokus dan kasual** (jelaskan "untuk siapa, menyelesaikan apa") |
| **Tag (`tags`)** | ★ Jika dikosongkan saat publikasi (`tags: null`), pencarian hanya bisa mengandalkan nama+deskripsi. **Tambahkan kata seperti `hackintosh` / `opencore` / `macos` / `efi` / `apel hitam`** |
| **Kategori / subkategori** | Jangan sampai masuk ke kategori yang tidak relevan (misal dokumentasi teknis masuk ke "Pembuatan kode / Peninjauan kode") — memengaruhi **exposure saat menjelajah per kategori** |
| Ikon | Lebih mudah diberi klik jika ada ikon (opsional) |

### B.4 Langkah ini harus Anda lakukan

Kemasan dan pemeriksaan mandiri **sudah dikerjakan di repo ini** (di `dist/` ada paket yang siap diunggah).
Tapi **login dan submit harus memakai akun Anda**, saya tidak bisa menggantikannya.

### Dua rute bisa berjalan bersamaan

Pertama jadikan repo ini marketplace yang bisa ditambahkan (Rute A) **untuk dipakai Anda sendiri dan orang yang dikenal**,
setelah skill-nya stabil baru dikemasan dan dipublikasikan ke kanal resmi (Rute B) — keduanya tidak saling bertentangan.
