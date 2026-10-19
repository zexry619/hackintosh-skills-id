#!/bin/bash
# Pengumpulan linimasa boot (versi cepat)
# Cara pakai:  sudo bash boot-timeline.sh
#         (keluaran ditulis ke direktori home pemanggil ~/boot-timeline-<waktu>.txt)
#
# Urutan disesuaikan: data "cepat tapi penting" ditulis lebih dulu (pesan kernel driver sudah ada di dmesg),
# `log show` yang paling lambat diletakkan paling akhir, dan hanya berjalan maksimal 60 detik sebelum otomatis dihentikan, jadi tidak akan menggantung terus.
# Hanya baca, tidak mengubah apa pun.

set -u
U="${SUDO_USER:-$USER}"
H="$(dscl . -read /Users/"$U" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
[ -n "${H:-}" ] && [ -d "$H" ] || H="/tmp"
OUT="$H/boot-timeline-$(date +%Y%m%d-%H%M%S).txt"
: > "$OUT"

step() { printf '\n>>> %s\n' "$*"; printf '\n>>> %s\n' "$*" >&2; }
H2()   { { echo; echo "===================== $* ====================="; } >> "$OUT"; }

# Jalankan satu perintah dengan batas waktu, keluaran ditambahkan ke $OUT
timed() {   # timed <detik> <perintah...>
  local t=$1; shift
  ( "$@" >> "$OUT" 2>&1 ) & local pid=$!
  ( sleep "$t"; kill -TERM "$pid" 2>/dev/null ) & local killer=$!
  wait "$pid" 2>/dev/null; local rc=$?
  kill -TERM "$killer" 2>/dev/null; wait "$killer" 2>/dev/null
  echo "# (exit $rc, timeout ${t}s)" >> "$OUT"
}

# Waktu boot
BOOT=$(sysctl -n kern.boottime 2>/dev/null | sed -n 's/^[^{]*{ sec = \([0-9][0-9]*\),.*$/\1/p')
if [ -n "${BOOT:-}" ] && [ "$BOOT" -gt 1000000000 ] 2>/dev/null; then
  START=$(date -r "$BOOT" "+%Y-%m-%d %H:%M:%S")
  END=$(date -v+5M -r "$BOOT" "+%Y-%m-%d %H:%M:%S")
else
  START=$(date -v-1H "+%Y-%m-%d %H:%M:%S"); END=$(date "+%Y-%m-%d %H:%M:%S")
fi

# ---------- 1. Cepat ----------
step "1/5 Informasi dasar"
H2 "Informasi dasar"; { echo "boottime: $START"; echo "sekarang: $(date)"; uptime; sw_vers; } >> "$OUT" 2>&1

step "2/5 Properti boot NVRM"
H2 "Properti boot NVRM"
ioreg -r -n NVRM -d 1 -l 2>/dev/null | grep -E '"nvrm-|"model"' >> "$OUT" 2>&1

# ---------- 3. Cepat, dan paling penting: pesan kernel driver ada di dmesg ----------
step "3/5 dmesg (cincin pesan kernel driver — data penting ada di sini)"
H2 "dmesg: pesan driver"
dmesg 2>&1 | grep -iE 'nvrm|nvaccel|nvidia|nullmoth|gsp|bar1|flip|vblank|settle|armed|hold' | tail -400 >> "$OUT" 2>&1
{ echo; echo "-- jumlah baris dmesg --"; dmesg 2>&1 | wc -l; dmesg 2>&1 | tail -1; } >> "$OUT" 2>&1
echo "    (sudah ditulis ke ${OUT} , boleh lihat bagian ini dulu)"

# ---------- 4. Cepat: linimasa launchd ----------
step "4/5 Linimasa boot launchd"
H2 "Linimasa boot launchd"
{
  echo "-- kemunculan pertama layanan penting --"
  for s in WindowServer loginwindow Dock Finder coreservicesd; do
    t=$(grep -m1 "$s" /var/log/com.apple.xpc.launchd/launchd.log 2>/dev/null | cut -c1-23)
    echo "  $s: ${t:-?}"
  done
  echo
  echo "-- jumlah event per titik waktu (240 detik pertama; celah adalah tempat macet) --"
} >> "$OUT" 2>&1
python3 - >> "$OUT" 2>&1 <<'PY'
import re, collections, datetime
L = "/var/log/com.apple.xpc.launchd/launchd.log"
c = collections.Counter()
try:
    with open(L, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = re.match(r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})", line)
            if m: c[m.group(1)] += 1
except Exception as e:
    print("  gagal membaca:", e); raise SystemExit
if not c: print("  tidak ada data"); raise SystemExit
ts = sorted(c); t0 = datetime.datetime.strptime(ts[0], "%Y-%m-%d %H:%M:%S")
prev = None
for t in ts:
    d = datetime.datetime.strptime(t, "%Y-%m-%d %H:%M:%S")
    off = (d - t0).total_seconds()
    if off > 240: break
    gap = "" if prev is None else ("   <<< jeda %ds >>>" % (d - prev).total_seconds() if (d - prev).total_seconds() >= 5 else "")
    print("   +%4ds  %5d event  %s%s" % (off, c[t], t, gap))
    prev = d
PY

# ---------- 5. Lambat: unified log, diletakkan paling akhir, timeout 60 detik ----------
# ⚠️ Dua jebakan:
#   1) Tidak boleh memakai --start/--end: jam sistem dikoreksi saat boot, log show akan melaporkan
#      "Wall Clock adjustment detected" dan mengembalikan periode **boot sebelumnya** (terukur tertangkap 17:47–21:28, sedangkan boot ini 23:10). Gunakan --last.
#   2) Predicate jangan memakai eventMessage CONTAINS (butuh pemindaian penuh, sangat lambat). Hanya pakai field terindeks process == "kernel",
#      dan filter kata kunci dilakukan secara lokal dengan grep.
#   ★ Jika --last juga gagal di mesin ini (mengembalikan seluruh basis log), jangan tunggu di sini: gunakan find-boot-gap.sh (filter streaming).
UP=$(( $(date +%s) - ${BOOT:-0} )); MIN=$(( UP / 60 + 2 )); [ "$MIN" -gt 30 ] && MIN=30; [ "$MIN" -lt 3 ] && MIN=3
step "5/5 Kernel log (lebih lambat, maksimal 90 detik, otomatis dihentikan saat timeout)"
H2 "Kernel log: pesan driver (--last ${MIN}m, menghindari masalah koreksi jam)"
KD=$(mktemp /tmp/bt-kdump-XXXXXX.txt)
( /usr/bin/log show --last "${MIN}m" --style compact --predicate 'process == "kernel"' > "$KD" 2>/dev/null ) & _p=$!
( sleep 90; kill -TERM "$_p" 2>/dev/null ) & _k=$!
wait "$_p" 2>/dev/null; _rc=$?
kill -TERM "$_k" 2>/dev/null; wait "$_k" 2>/dev/null
echo "# (log show exit $_rc, tertangkap $(wc -c < "$KD" | tr -d ' ') byte)" >> "$OUT"
grep -a -iE "nvrm|nvaccel|gsp|bar1|nvidia|nullmoth" "$KD" >> "$OUT" 2>&1
rm -f "$KD"

echo
echo "=========================================="
echo " Selesai, sudah ditulis ke:"
echo "   $OUT"
echo " Ukuran: $(wc -c < "$OUT") byte"
echo " Cukup kirimkan berkasnya kepada saya (bagian dmesg pada tahap 3 paling penting)."
echo "=========================================="
