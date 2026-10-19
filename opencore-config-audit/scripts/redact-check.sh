#!/bin/bash
# redact-check.sh —— Pemeriksaan mandiri informasi sensitif sebelum publikasi (hanya baca)
#
# Tujuan: sebelum mengemas / mengunggah direktori skill ke lokasi publik mana pun, pindai hal-hal yang seharusnya tidak ada.
#
# Mengapa perlu: platform mengunggah akan menjalankan satu kali pemeriksaan preflight, dan salah satu jenis item konfirmasi adalah `credential`
#   —— deteksi kredensial yang mencurigakan akan meminta konfirmasi, bahkan memblokir secara langsung. Yang lebih mendasar lagi: **mengunggah/mendorong berarti mempublikkan**,
#   nomor seri, MAC kartu jaringan, dan sejenisnya setara dengan identitas mesin ini (iMessage / FaceTime memang mengenali keduanya).
#
# Cara pakai:
#   bash redact-check.sh <direktori> [direktori tambahan...]
#   bash redact-check.sh .
#
# Kode keluar: 0 = tidak ada masalah ditemukan; 1 = ada yang cocok (perlu ditangani)
# Hanya baca, tidak mengubah apa pun.

set -u

if [ "$#" -eq 0 ]; then
  echo "Cara pakai: bash redact-check.sh <direktori> [direktori tambahan...]"
  exit 2
fi

DIRS=("$@")

# Daftar putih: UUID di bawah ini adalah GUID standar dalam spesifikasi Apple / OpenCore / UEFI / Microsoft (konstanta publik), bukan data lokal
#   —— nilainya sama di setiap mesin, jadi keberadaannya di dokumentasi tidak apa-apa. Tambahkan konstanta publik baru ke daftar ini beserta sumbernya.
ALLOW='4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102|4D1EDE05-38C7-4A6A-9CC6-4BCCA8B38C14|7C436110-AB2A-4BBB-A880-FE41995C9F82|E6B92AC5-B7DB-4B0D-B1B5-8A0E0A0E0A0E|8BE4DF61-93CA-11D2-AA0D-00E098032B8C|A17579F0-4FEC-4936-9364-249460863BE5|6994AD04-93EF-11D0-A3CC-00A0C9223196'
# Catatan: dua entri terakhir adalah GUID kelas antarmuka privat Windows HD Audio dan GUID kelas media KS (publik oleh Microsoft, dipakai pada dokumentasi HDAU/HDAudDev)

TOTAL=0

# Perhatikan: di sini harus memakai DIRS global, bukan "$@" — "$@" di dalam fungsi adalah argumen milik fungsi itu sendiri
check() {   # check <label> <regex> <tingkat>
  local label="$1" re="$2" sev="$3"
  local out
  out=$(grep -rnIE --binary-files=without-match --exclude=redact-check.sh "$re" "${DIRS[@]}" 2>/dev/null \
        | grep -vE "$ALLOW" | head -20)
  if [ -n "$out" ]; then
    echo "  [${sev}] ${label}"
    printf '%s\n' "$out" | sed 's/^/        /' | cut -c1-170
    echo
    TOTAL=$(( TOTAL + 1 ))
  fi
}

for DIR in "${DIRS[@]}"; do
  if [ ! -d "${DIR}" ]; then
    echo "Lewati (bukan direktori): ${DIR}"
    continue
  fi
  echo "══════════════════════════════════════════════════════════════"
  echo " Memindai: ${DIR}"
  echo "══════════════════════════════════════════════════════════════"

  # ── Tinggi: kelas kredensial identitas (setara identitas mesin, sama sekali tidak boleh publik)──
  check "Alamat MAC kartu jaringan (termasuk MAC en0 yang dipakai ROM)" \
        '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' "Tinggi"

  check "Nomor seri tiga kode (serial / MLB, pencocokan kontekstual)" \
        '(?i)(serial|MLB|BoardSerial|SystemSerial)[^A-Za-z0-9]{0,6}[A-Z0-9]{8,}' "Tinggi"

  check "Kunci / token" \
        '(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|BEGIN [A-Z ]*PRIVATE KEY|(?i)(api[_-]?key|access[_-]?token|client[_-]?secret|passwd|password)[[:space:]]*[:=][[:space:]]*[^[:space:]]{8,})' "Tinggi"

  check "Path berkas kredensial" \
        '(\.ssh/id_|id_rsa|\.pem\b|\.p12\b|\.netrc|credentials\.json)' "Tinggi"

  # ── Sedang: informasi yang dapat mengidentifikasi mesin / orang tertentu ──
  check "UUID volume (GUID standar Apple / UEFI sudah dikecualikan)" \
        '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' "Sedang"

  check "Alamat email" \
        '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "Sedang"

  check "IP jaringan internal / privat" \
        '\b(10\.[0-9]{1,3}|192\.168\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3})\.[0-9]{1,3}\b' "Sedang"

  echo
done

echo "══════════════════════════════════════════════════════════════"
if [ "$TOTAL" -eq 0 ]; then
  echo " ✅ Tidak ada yang cocok"
  echo "    (Pemindaian otomatis hanyalah pengaman tambahan, sebelum publikasi tetap disarankan untuk diperiksa manual: apakah ada nilai yang jelas hanya milik mesin ini)"
  exit 0
else
  echo " ⚠️  Ada ${TOTAL} kategori yang cocok —— bersihkan dulu baru publikasi / unggah"
  echo "    · Tinggi: **wajib** dihapus atau diganti dengan ⟨placeholder⟩ (nomor seri, MAC, kunci)"
  echo "    · Sedang: ganti dengan ⟨placeholder⟩ (UUID volume, nama host), juga lebih jelas bagi pembaca"
  echo "    · Email: pastikan memang yang ingin kamu publikasikan"
  exit 1
fi
