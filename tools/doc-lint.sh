#!/bin/bash
# doc-lint.sh —— Pemeriksaan konsistensi dokumen skill (hanya baca, tidak mengubah file apa pun)
#
# Mengapa perlu: references dalam skill ini saling merujuk, satu kesimpulan yang salah
#   akan menyebar mengikuti rantai rujukan.
#   Sudah pernah kejadian sekali: `network-en0-order.md` salah memperluas permintaan
#   **iServices** (iMessage) dari Dortania ke **AirDrop**, sehingga `broadcom-wifi.md` /
#   `ethernet-drivers.md` / `smbios-and-serials.md` / `SKILL.md` semuanya ikut salah,
#   dan penelusuran sempat tersesat ke `ROM`.
#   Tidak mungkin ditangkap dengan review manual, jadi "ucapan yang salah" yang sudah
#   diketahui ditulis menjadi aturan; jalankan sekali setiap selesai mengubah.
#
# Cara pakai:
#   bash tools/doc-lint.sh              # pemeriksaan penuh
#   bash tools/doc-lint.sh --with-redact  # sekaligus jalankan pemeriksaan redaksi (sebelum rilis)
#
# Kode keluar: 0 = semua lulus; 1 = ada peringatan
#
# ★ Pengecualian false positive: baris yang memuat “” atau " (kutipan pendapat orang lain),
#   atau mengandung `doc-lint:ignore`, dianggap "kutipan / sengaja dipertahankan"
#   dan tidak dilaporkan. Jika perlu pengecualian permanen, tambahkan `doc-lint:ignore`
#   pada baris itu.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/opencore-config-audit"
GREP=/usr/bin/grep
ERRORS=0

if [ ! -d "$SKILL" ]; then
  echo "✗ Direktori skill tidak ditemukan: $SKILL"
  exit 2
fi

# Dokumen yang dipindai: isi skill + panduan penggunaan + seluruh references + README repositori
# ★ Tidak boleh memakai mapfile — bash 3.2 bawaan macOS tidak memiliki built-in command ini
DOCS=()
while IFS= read -r p; do
  [ -n "$p" ] && DOCS+=("$p")
done < <(
  {
    [ -f "$SKILL/SKILL.md" ] && echo "$SKILL/SKILL.md"
    [ -f "$SKILL/USAGE.md" ] && echo "$SKILL/USAGE.md"
    ls "$SKILL"/references/*.md 2>/dev/null
    [ -f "$ROOT/README.md" ] && echo "$ROOT/README.md"
  } | sort -u
)

hdr() { echo; echo "── $* ──"; }
bad() { echo "   ✗ $*"; ERRORS=$((ERRORS + 1)); }

# Turunkan huruf besar (kode ASCII saja, aman untuk teks UTF-8) supaya pencocokan
# kata kunci pengecualian tidak bergantung pada kapitalisasi di dokumen.
lower() { printf '%s' "$1" | LC_ALL=C tr 'A-Z' 'a-z'; }

# Apakah baris berada dalam konteks "kutipan / pengecualian"
exempt_line() {
  case "$1" in
    *“*|*\"*|*doc-lint:ignore*) return 0 ;;
  esac
  return 1
}

# Aturan A1: AirDrop × en0 — tidak boleh mengatakan "AirDrop bergantung pada en0"
rule_airdrop_en0() {
  hdr "A1  Apakah AirDrop / Handoff salah disebut bergantung pada en0"
  local hit=0 line n f lc
  while IFS= read -r f; do
    while IFS=: read -r n line; do
      exempt_line "$line" && continue
      lc=$(lower "$line")
      case "$lc" in
        *tidak\ terkait*|*tidak\ ada\ hubungannya*|*tidak\ ada\ hubungan*|*tidak\ bergantung*|*independen\ dari*|*tidak\ ada\ di*|*tidak\ berada\ di*|*tidak\ terpengaruh*|*tidak\ dipengaruhi*|*bukan*|*jangan*|*salah*|*salah\ menilai*|*❌*|*tidak\ terpasang*|*tidak\ perlu*|*tidak\ memengaruhi*|*tidak\ ada\ satu\ pun*|*unrelated*|*never*|*not\ related*) continue ;;
      esac
      bad "$(basename "$f"):$n  AirDrop dan en0 dicampur-aduk"
      echo "      ${line:0:150}"
      hit=1
    done < <($GREP -nE '(AirDrop|Handoff|Serah Terima|Continuity|Kesinambungan).*(en0)|(en0).*(AirDrop|Handoff|Serah Terima|Continuity|Kesinambungan)|(AirDrop|Handoff|Serah Terima|Continuity|Kesinambungan)[^.]{0,20}terpasang pada (itu|atasnya|di atasnya)' "$f" 2>/dev/null)
  done < <(printf '%s\n' "${DOCS[@]}")
  [ "$hit" -eq 0 ] && echo "   ✓ Tidak ada temuan"
}

# Aturan A2: itlwm × AirDrop — tidak boleh mengatakan itlwm bisa mendapatkan AirDrop
rule_itlwm_airdrop() {
  hdr "A2  Apakah itlwm salah disebut mendukung AirDrop"
  local hit=0 line n f lc
  while IFS= read -r f; do
    while IFS=: read -r n line; do
      exempt_line "$line" && continue
      lc=$(lower "$line")
      case "$lc" in
        *tidak\ mendukung*|*tidak\ tersedia*|*tidak\ bisa*|*tidak\ mungkin*|*tidak\ pernah*|*tidak\ akan\ pernah*|*pasti*|*tidak\ ada*|*❌*) continue ;;
      esac
      bad "$(basename "$f"):$n  Pernyataan positif itlwm dan AirDrop"
      echo "      ${line:0:150}"
      hit=1
    done < <($GREP -nE 'itlwm.*(AirDrop|Handoff)|(AirDrop|Handoff).*itlwm' "$f" 2>/dev/null \
             | $GREP -E '(mendukung|bisa|dapat\ digunakan|dapat\ dipakai|mampu)')
  done < <(printf '%s\n' "${DOCS[@]}")
  [ "$hit" -eq 0 ] && echo "   ✓ Tidak ada temuan"
}

# Aturan A3: ROM × AirDrop — tidak boleh mengatakan AirDrop membutuhkan ROM yang benar
rule_rom_airdrop() {
  hdr "A3  Apakah ROM salah disebut sebagai prasyarat AirDrop"
  local hit=0 line n f lc
  while IFS= read -r f; do
    while IFS=: read -r n line; do
      exempt_line "$line" && continue
      lc=$(lower "$line")
      case "$lc" in
        *tidak\ terkait*|*tidak\ ada\ hubungannya*|*tidak\ ada\ hubungan*|*tidak\ bergantung*|*tidak\ memengaruhi*|*bukan*|*jangan*|*salah*|*salah\ menilai*|*❌*) continue ;;
      esac
      bad "$(basename "$f"):$n  Pernyataan positif ROM dan AirDrop"
      echo "      ${line:0:150}"
      hit=1
    done < <($GREP -nE 'ROM.*(AirDrop|Handoff)|(AirDrop|Handoff).*ROM' "$f" 2>/dev/null \
             | $GREP -E '(wajib|harus|jika tidak|konsisten|ubah menjadi|diubah|tidak berlaku)')
  done < <(printf '%s\n' "${DOCS[@]}")
  [ "$hit" -eq 0 ] && echo "   ✓ Tidak ada temuan"
}

# Aturan B: kelengkapan indeks — references / scripts selaras dua arah dengan SKILL.md
rule_index() {
  hdr "B1  Setiap reference terindeks di SKILL.md"
  local miss=0 f b
  for f in "$SKILL"/references/*.md; do
    [ -e "$f" ] || continue
    b=$(basename "$f")
    $GREP -q "$b" "$SKILL/SKILL.md" || { bad "Belum diindeks: references/$b"; miss=1; }
  done
  [ "$miss" -eq 0 ] && echo "   ✓ Tidak ada temuan"

  hdr "B2  Setiap script terindeks di SKILL.md"
  miss=0
  for f in "$SKILL"/scripts/*; do
    [ -e "$f" ] || continue
    b=$(basename "$f")
    $GREP -q "$b" "$SKILL/SKILL.md" || { bad "Belum diindeks: scripts/$b"; miss=1; }
  done
  [ "$miss" -eq 0 ] && echo "   ✓ Tidak ada temuan"

  hdr "B3  Semua file yang dirujuk SKILL.md benar-benar ada"
  miss=0
  while read -r p; do
    [ -z "$p" ] && continue
    [ -f "$SKILL/$p" ] || { bad "Tautan mati: $p"; miss=1; }
  done < <($GREP -oE '\b(references|scripts)/[A-Za-z0-9._-]+\.[A-Za-z0-9]+' "$SKILL/SKILL.md" | sort -u)
  [ "$miss" -eq 0 ] && echo "   ✓ Tidak ada temuan"

  hdr "B4  Path references/ dan scripts/ yang ditulis di tiap dokumen benar-benar ada"
  # ★ Hanya diperiksa path yang memiliki prefiks direktori **dan** ekstensi. Dua alasan:
  #   1. Nama file telanjang (seperti `install.sh` / `Audio_Tahoe.md`) umumnya berasal dari
  #     dokumen **repositori lain**, sehingga pemeriksaan hanya menghasilkan false positive;
  #   2. Dalam isi teks sering muncul gabungan seperti "indeks references/scripts", yang
  #     bukan path dan tidak boleh dianggap tautan mati.
  miss=0
  while read -r p; do
    [ -z "$p" ] && continue
    [ -f "$SKILL/$p" ] || { bad "Tautan mati: $p"; miss=1; }
  done < <(
    for f in "${DOCS[@]}"; do
      $GREP -ohE '\b(references|scripts)/[A-Za-z0-9._-]+\.[A-Za-z0-9]+' "$f" 2>/dev/null
    done | sort -u
  )
  [ "$miss" -eq 0 ] && echo "   ✓ Tidak ada temuan"

  hdr "B5  Setiap entri daftar aset berada pada baris sendiri (mencegah menempel saat diedit)"
  # ★ Gejalanya: dua entri `- \`references/xxx.md\` — …` menjadi satu baris (biasanya
  #   karena lupa menambah baris baru saat mengedit).
  #   Path-nya sendiri semuanya ada ⇒ B3/B4 tidak dapat menemukannya; baru terlihat
  #   ketika jumlah entri tidak cocok.
  #   Kriteria: baris yang diawali `- \`references/` atau `- \`scripts/` tidak boleh memuat
  #   awalan yang sama untuk kedua kalinya di dalam satu baris.
  #   Narasi multi-path seperti "gunakan A; lalu B" tidak dihitung — tidak diawali `- \``.
  python3 - "$SKILL/SKILL.md" <<'PY'
import re, sys
path = sys.argv[1]
head = re.compile(r'^- `(?:references|scripts)/')
item = re.compile(r'- `(?:references|scripts)/')
hits = []
for i, line in enumerate(open(path, encoding='utf-8'), 1):
    if not head.match(line):
        continue
    n = len(item.findall(line))
    if n > 1:
        hits.append((i, n, line.strip()[:60]))
for i, n, s in hits:
    print(f"   ✗ Entri menempel ({n} entri menjadi satu baris) L{i}: {s}…")
if not hits:
    print("   ✓ Tidak ada temuan")
sys.exit(1 if hits else 0)
PY
  [ $? -eq 0 ] || ERRORS=$((ERRORS + 1))
}

# Aturan C: nomor versi konsisten di tiga tempat (langkah yang paling sering terlewat sebelum rilis)
rule_version() {
  hdr "C1  Nomor versi konsisten di tiga tempat (SKILL.md / plugin.json / marketplace.json)"
  python3 - "$SKILL" "$ROOT/.codebuddy-plugin/marketplace.json" <<'PY'
import json, sys, re, os
skill, market = sys.argv[1], sys.argv[2]
name = os.path.basename(skill)
found = {}
try:
    txt = open(os.path.join(skill, "SKILL.md"), encoding="utf-8").read()
    fm = txt.split("---", 2)[1] if txt.startswith("---") else ""
    m = re.search(r"^version:\s*(\S+)", fm, re.M)
    found["SKILL.md"] = m.group(1).strip("'\"") if m else None
except FileNotFoundError:
    found["SKILL.md"] = "MISSING"
try:
    found["plugin.json"] = json.load(open(os.path.join(skill, ".codebuddy-plugin", "plugin.json"), encoding="utf-8")).get("version")
except Exception:
    found["plugin.json"] = "MISSING"
try:
    mk = json.load(open(market, encoding="utf-8"))
    e = next((p for p in mk.get("plugins", []) if p.get("name") == name), {})
    found["marketplace.json"] = e.get("version")
except Exception:
    found["marketplace.json"] = "MISSING"
for k, v in found.items():
    print(f"      {k:<18} {v}")
vals = list(found.values())
ok = len(set(vals)) == 1 and vals[0] not in (None, "MISSING")
print("   ✓ Konsisten di ketiga tempat" if ok else "   ✗ Nomor versi tidak konsisten, wajib diselaraskan sebelum rilis")
sys.exit(0 if ok else 1)
PY
  [ $? -ne 0 ] && ERRORS=$((ERRORS + 1))
}

echo "══════════════════════════════════════════════════════════"
echo "  doc-lint · $(basename "$ROOT")"
echo "  Memindai $(( ${#DOCS[@]} )) dokumen"
echo "══════════════════════════════════════════════════════════"

rule_airdrop_en0
rule_itlwm_airdrop
rule_rom_airdrop
rule_index
rule_version

if [ "${1:-}" = "--with-redact" ]; then
  hdr "D1  Pemeriksaan redaksi sebelum rilis"
  if bash "$SKILL/scripts/redact-check.sh" "$SKILL" > /tmp/.doclint_redact.$$ 2>&1; then
    echo "   ✓ Tidak ada temuan"
  else
    bad "Pemeriksaan redaksi menemukan masalah (detail: bash opencore-config-audit/scripts/redact-check.sh opencore-config-audit)"
  fi
  rm -f /tmp/.doclint_redact.$$
fi

echo
echo "══════════════════════════════════════════════════════════"
if [ "$ERRORS" -eq 0 ]; then
  echo " ✅ Semua lulus"
else
  echo " ⚠️  $ERRORS peringatan"
fi
echo "══════════════════════════════════════════════════════════"
exit $([ "$ERRORS" -eq 0 ] && echo 0 || echo 1)
