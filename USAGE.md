# Panduan penggunaan

Repositori ini berisi dua skill, dan panduan penggunaan detail masing-masing ada **di dalam direktori skill**:

| Skill | Panduan penggunaan |
|---|---|
| `opencore-config-audit` | [`opencore-config-audit/USAGE.md`](opencore-config-audit/USAGE.md) |

> Menaruh panduan di dalam direktori skill memang **disengaja**: saat instalasi `cp -R <skill> ...` hanya menyalin direktori skill,
> sedangkan panduan yang ditaruh di sini akan **ikut terpasang**, jadi pengguna cukup bertanya "panduan penggunaan" di dalam percakapan.
> Berkas ini hanya membahas **cara memanggil** dan **cara mengubah skill**.

---

## 1. Cara memanggil

### Cara 1: langsung saja nyatakan kebutuhannya (disarankan, tidak perlu mengingat apa pun)

**Cukup jelaskan masalahnya dengan bahasa alami**, dan sistem akan memilih skill yang tepat secara otomatis. Contoh:

```
"Tolong audit konfigurasi OpenCore saya"
"Kartu Wi-Fi saya MT7922, apakah bisa di-driver di macOS"
"Boot sangat lambat, bantu saya cek macetnya di mana"
"Saat instalasi sistem, disk tidak ditemukan"
"Ganti tema OpenCore"
```

### Cara 2: tentukan secara manual

- Ketik **`/`** di kolom input → pilih skill dari daftar
- Atau klik **`+` → Skill** di pojok kiri bawah kolom input → pilih lalu kirim

Skill yang sering dipakai juga bisa **ditempelkan di atas**, atau cepat ditemukan lewat **yang paling baru digunakan**.

### Cara 3: tanya "panduan penggunaan"

Cukup tanyakan langsung ke skill itu sendiri, misalnya:

```
"Bagaimana cara pakai opencore-config-audit"
"Kemampuan apa saja yang dimiliki skill ini"
"Tunjukkan panduan penggunaan"
```

Setelah skill dimuat, skill tersebut akan **mengeluarkan `USAGE.md` miliknya sendiri** (perintah ini ditulis di dalam `SKILL.md`).
Memanggil lewat `/` secara manual lalu bertanya hal yang sama juga berlaku.

---

## 2. Instalasi

**Cara pertama: instalasi lewat marketplace plugin (disarankan)**

```bash
/plugin marketplace add GeekAudio/hackintosh-skills
/plugin install opencore-config-audit@hackintosh-skills
```

**Cara kedua: salin manual (offline / hanya satu)**

```bash
cp -R opencore-config-audit ~/.workbuddy-ai/skills/
```

Setelah terpasang, buat percakapan baru lalu ucapkan salah satu contoh kalimat di atas untuk memverifikasi apakah sudah aktif.

> Untuk mempublikasikan / mendistribusikan skill sendiri, lihat [`PUBLISHING.md`](PUBLISHING.md).

---

## 3. Untuk maintainer skill

<details>
<summary>Buka: field kontrol pemanggilan, perilaku default, override settings, troubleshooting</summary>

### 3.1 Field di dalam `SKILL.md` yang mengatur pemanggilan (`frontmatter`)

| Field | Tipe | Fungsi |
|---|---|---|
| `name` | String | Nama skill (sekaligus kunci override settings) |
| `description` | String | **Dasar pemicu utama** —— model memakainya untuk menilai "apakah permintaan ini layak ditangani skill ini" |
| `description_zh` / `description_en` | String | Deskripsi Mandarin/Inggris (masing-masing untuk lingkungan bahasa Mandarin/Inggris) |
| `when-to-use` | String | Tambahan penjelasan "kapan dipakai" |
| `allowed-tools` | Array | Alat yang diizinkan untuk skill ini |
| `disable` | Boolean | Menonaktifkan skill secara keseluruhan |
| **`disable-model-invocation`** | Boolean | ★ **Melarang pemanggilan otomatis** (`true` = hanya bisa dipanggil manual) |
| **`user-invocable`** | Boolean | Apakah muncul di daftar pemanggilan manual `/` |
| `license` / `version` | String | Metadata |

### 3.2 Perilaku default

| Field | Default | Arti |
|---|---|---|
| `disable` | `false` | Diaktifkan secara default |
| `disable-model-invocation` | **`false`** | **Pemanggilan otomatis diizinkan secara default** |
| `user-invocable` | **`true`** (asalkan tidak ditulis eksplisit `false`) | **Muncul di daftar `/` secara default** |

Aturan filter daftar `/`: `user-invocable` bukan `false`, dan sumbernya adalah `userSettings / user / builtin / plugin`
(sumber `connector` dikecualikan).

> ⇒ **Skill yang dipasang sendiri secara default bisa dipanggil otomatis; skill bawaan bawaan tidak bisa**, sehingga harus dipanggil eksplisit dengan `/`.

### 3.3 Override settings (prioritas tertinggi)

`skillOverrides` pada pengaturan menggunakan **nama skill** sebagai kunci, dengan tiga nilai yang mungkin:

| Nilai | Arti |
|---|---|
| `user-invocable-only` | **Melarang pemanggilan otomatis**, hanya bisa dipanggil manual |
| `off` | Menonaktifkan skill tersebut |
| `name-only` | Hanya muncul di daftar dalam bentuk nama |

```json
{ "skillOverrides": { "opencore-config-audit": "user-invocable-only" } }
```

> ★ **Skill dari sumber plugin (`plugin`) tidak menerima override** dan akan dilewati.

### 3.4 Bagaimana "panduan penggunaan" dikeluarkan

Aplikasi **tidak** punya perintah bawaan untuk "mencetak panduan penggunaan". Ini dicapai lewat konvensi berikut:

1. Setiap direktori skill berisi satu **`USAGE.md`** (untuk dilihat pengguna)
2. Di dalam `SKILL.md` ditulis: **Saat pengguna bertanya "cara pakai / panduan penggunaan / kemampuan apa saja", keluarkan langsung `USAGE.md`**
3. Kata pemicu yang sesuai ditambahkan ke dalam `description`, supaya pertanyaan seperti itu bisa dikenali

⇒ Jadi `USAGE.md` **harus berada di dalam direktori skill** (sejajar dengan `SKILL.md`); kalau ditaruh di root repositori, file ini tidak ikut tersalin saat instalasi.

### 3.5 Troubleshooting: kenapa tidak terpanggil?

| Gejala | Pemeriksaan |
|---|---|
| Kebutuhan sudah disampaikan tapi skill tidak aktif | ① Apakah `disable` bernilai `true`; ② Apakah `skillOverrides` disetel ke `user-invocable-only` / `off` |
| Tidak terlihat di daftar `/` | Apakah `user-invocable` disetel eksplisit ke `false`; atau sumbernya `connector` (akan dikecualikan) |
| Terpasang tapi tidak aktif | Apakah kata pemicunya cukup spesifik — tambahkan ungkapan yang biasa dipakai pengguna ke dalam `description` |
| Bertanya "panduan penggunaan" tapi tidak ada output | Apakah `USAGE.md` berada **di dalam direktori skill**; apakah perintah keluaran itu ada di `SKILL.md` |
| Skill bawaan tidak bisa dipanggil otomatis | Dirancang begitu (lihat 3.2) ⇒ panggil eksplisit dengan `/` |
| Frontmatter diubah tapi tidak ada efek | Field terkait pemanggilan **mengikuti override settings** dan akan menimpa nilai di dalam file |

</details>
