#!/bin/bash
# Tangkap log "jendela jeda boot" (versi filter streaming — tidak disimpan ke disk)
#
# Filter waktu dari `log show` pada mesin ini **sepenuhnya gagal**:
#   --start/--end  → melaporkan "Wall Clock adjustment detected", mengembalikan seluruh basis log (terukur 3 GB / 20 juta baris)
#   --last Nm      → sama-sama mengembalikan seluruh basis log
#   --boot         → opsi ini tidak ada
#
# Namun output `log show` adalah **aliran berurutan waktu**, jadi cara yang benar adalah:
#   **filter streaming** — tidak menulis berkas antara, memakai awk untuk hanya mencetak baris dalam jendela waktu target.
#   Berapa pun besar basis log, yang tersimpan ke disk hanya beberapa puluh KB di dalam jendela tersebut.
#
# Cara pakai: sudo bash find-boot-gap.sh [--kernel]
#        --kernel  hanya tangkap pesan kernel (jauh lebih cepat, tetapi user-space akan terlewat)
# Hanya baca, tidak mengubah apa pun.

set -u
[ "$(id -u)" = "0" ] || { echo "Mohon jalankan dengan sudo: sudo bash \"$0\""; exit 1; }

KERNEL_ONLY=0
[ "${1:-}" = "--kernel" ] && KERNEL_ONLY=1

U="${SUDO_USER:-$USER}"
H="$(dscl . -read /Users/"$U" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
[ -n "${H:-}" ] && [ -d "$H" ] || H="/tmp"
OUT="$H/boot-gap-$(date +%Y%m%d-%H%M%S).txt"
FILTERED=$(mktemp /tmp/gapfiltered-XXXXXX.txt)
trap 'rm -f "$FILTERED"' EXIT

BOOT=$(sysctl -n kern.boottime 2>/dev/null | sed -n 's/^[^{]*{ sec = \([0-9][0-9]*\),.*$/\1/p')
[ -n "${BOOT:-}" ] || { echo "!! kern.boottime tidak bisa diambil"; exit 1; }

echo "=============================================="
echo " Pemeriksaan mendalam jendela jeda boot (versi filter streaming)"
echo "=============================================="
echo " Boot: $(date -r "$BOOT" '+%Y-%m-%d %H:%M:%S')"
echo " UUID boot: $(sysctl -n kern.bootsessionuuid 2>/dev/null || echo '?')"
echo

echo "→ Langkah 1: cari celah terbesar dari launchd.log"
GAP=$(python3 - "$BOOT" <<'PY'
import re, sys, datetime
boot = int(sys.argv[1]); t0 = datetime.datetime.fromtimestamp(boot)
L = "/var/log/com.apple.xpc.launchd/launchd.log"
pat = re.compile(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})")
ts = []
with open(L, encoding="utf-8", errors="replace") as f:
    for line in f:
        m = pat.match(line)
        if not m: continue
        t = datetime.datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S")
        off = int((t - t0).total_seconds())
        if 0 <= off <= 180: ts.append(off)
if len(ts) < 2: print("ERR 0 0 0"); raise SystemExit
ts = sorted(set(ts)); best = (0, 0, 0)
for a, b in zip(ts, ts[1:]):
    if b - a > best[0]: best = (b - a, a, b)
print("%d %d %d" % best)
PY
)
set -- $GAP
[ "${1:-ERR}" = "ERR" ] && { echo "  Parsing gagal"; exit 1; }
D=$1; A=$2; B=$3
echo "   Celah terbesar: ${D}s   (+${A}s → +${B}s)"

S=$(date -r $(( BOOT + A - 4 )) '+%Y-%m-%d %H:%M:%S')
E=$(date -r $(( BOOT + B + 8 )) '+%Y-%m-%d %H:%M:%S')
echo "   Jendela target: ${S} ~ ${E}"
echo
if [ "$KERNEL_ONLY" = "1" ]; then
  echo "→ Langkah 2: tangkap secara streaming[hanya kernel](cepat, sekitar 30-90 detik)"
  PRED='process == "kernel" AND NOT (eventMessage CONTAINS "nvAllocVram" OR eventMessage CONTAINS "nvScanoutInfo" OR eventMessage CONTAINS "allocPhysical")'
else
  echo "→ Langkah 2: tangkap secara streaming[semua](sekitar 2-5 menit, harus memindai seluruh basis log; bisa Ctrl-C)"
  echo "   Jika terasa lambat, gunakan: sudo bash \"$0\" --kernel"
  PRED='NOT (eventMessage CONTAINS "nvAllocVram" OR eventMessage CONTAINS "nvScanoutInfo" OR eventMessage CONTAINS "allocPhysical")'
fi

ST=$(date +%s)
log show --style compact --predicate "$PRED" 2>/dev/null \
  | awk -v s="$S" -v e="$E" '{ t=substr($0,1,19); if (t >= s && t <= e) print }' \
  > "$FILTERED"
DUR=$(( $(date +%s) - ST ))
echo "   Selesai, waktu yang dibutuhkan ${DUR}s, $(wc -l < "$FILTERED" | tr -d ' ') baris di dalam jendela"

{
  echo "Pemeriksaan mendalam jendela jeda boot  $(date)"
  echo "Boot: $(date -r "$BOOT" '+%Y-%m-%d %H:%M:%S')   UUID: $(sysctl -n kern.bootsessionuuid 2>/dev/null)"
  echo "Celah terbesar: ${D}s  (+${A}s → +${B}s)"
  echo "Jendela target: ${S} ~ ${E}"
  echo "Mode: $([ "$KERNEL_ONLY" = 1 ] && echo hanya kernel || echo semua)   Waktu yang dibutuhkan ${DUR}s"
  echo
  echo "===== B. Statistik proses di dalam jendela (25 teratas) ====="
  awk '{for(i=1;i<=NF;i++) if ($i ~ /\[[0-9]+:/ || $i ~ /\[[0-9]+\]$/) {sub(/\[.*/,"",$i); print $i; break}}' "$FILTERED" | sort | uniq -c | sort -rn | head -25
  echo
  echo "===== B2. Pesan setelah deduplikasi (statistik setelah timestamp dan angka dihapus, 25 teratas) ====="
  sed -E 's/^[0-9-]+ [0-9:.]+ +//; s/\[[0-9]+:[0-9a-f]+\]/[pid]/g; s/0x[0-9a-f]+/0xX/g; s/[0-9]{3,}/N/g' "$FILTERED" \
    | sort | uniq -c | sort -rn | head -25 | cut -c1-190
  echo
  echo "===== C. Jumlah baris log per detik di dalam jendela (jumlah rendah = idle) ====="
  awk '{print substr($0,1,19)}' "$FILTERED" | uniq -c | head -120
  echo
  echo "===== D. Pemeriksaan mandiri ====="
  echo "  Total baris di dalam jendela: $(wc -l < "$FILTERED" | tr -d ' ')"
  echo -n "  Paling awal di dalam jendela: "; grep -a -m1 -oE "^[0-9-]+ [0-9:]+" "$FILTERED" || echo "(tidak ada)"
  echo -n "  Paling akhir di dalam jendela: "; grep -a -oE "^[0-9-]+ [0-9:]+" "$FILTERED" | tail -1 || echo "(tidak ada)"
  echo
  # otomatis cari proses paling ramai di dalam jendela, lalu kecualikan supaya kuota head tidak habis
  TOP=$(awk '{for(i=1;i<=NF;i++) if ($i ~ /\[[0-9]+:/ || $i ~ /\[[0-9]+\]$/) {sub(/\[.*/,"",$i); print $i; break}}' "$FILTERED" | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
  echo "===== A1. Log di dalam jendela[proses paling ramai sudah dikecualikan: ${TOP:-tidak ada}](300 baris pertama) ====="
  if [ -n "${TOP:-}" ]; then
    grep -av "^[0-9-]* [0-9:.]* [A-Za-z]* *${TOP}\[" "$FILTERED" | head -300
  else
    head -300 "$FILTERED"
  fi
  echo
  echo "===== A2. 250 baris terakhir jendela (momen unlock ada di sini) ====="
  if [ -n "${TOP:-}" ]; then
    grep -av "^[0-9-]* [0-9:.]* [A-Za-z]* *${TOP}\[" "$FILTERED" | tail -250
  else
    tail -250 "$FILTERED"
  fi
} > "$OUT"

echo
echo "=========================================="
echo " Output: $OUT"
echo " Ukuran: $(wc -c < "$OUT") byte"
echo " Jumlah baris: $(wc -l < "$OUT")"
echo " Cukup kirimkan berkasnya kepada saya."
echo "=========================================="
