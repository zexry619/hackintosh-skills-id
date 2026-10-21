#!/bin/bash
# trigger-init.sh — picu init M1 pada driver yang sudah termuat.
#
# CARA KERJA ( realities of macOS 15 ):
#
#   Driver Decide punya start() yang mengecek:
#       - properti "M1Trigger" == "run"  → init jalan
#       - build varian UJI (M1_ALLOW_USB_TRAFFIC=1) → init jalan
#         pada start() pertama
#
#   Menulis properti IORegistry dari user space TIDAK bisa dilakukan
#   tanpa user client khusus (IOKit tidak mengekspos setProperty untuk
#   node milik kext). Percobaan dengan ctypes/pyobjc selalu gagal.
#
#   Yang JAUH lebih andal: **cabut-colok dongle**.
#   Node USB baru → driver attach ulang → start() → init jalan.
#
#   (Dan `kmutil load -b <id> -P <personality>` TIDAK memicu start()
#    ulang kalau driver sudah attach — sudah dibuktikan.)
#
# Usage: sudo ./scripts/trigger-init.sh [--wait SECONDS]
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WAIT=25
[[ "${1:-}" == "--wait" ]] && WAIT="${2:-25}"

echo "=== 1. status driver sekarang ==="
kextstat 2>/dev/null | grep -i zekri | awk '{print "    kext index: "$1"  "$4}'
ioreg -r -c RTL8188EUM1 -w0 2>/dev/null \
	| grep -oE '"M1[A-Za-z]+" = "[^"]*"' | head -10 | sed 's/^/    /'

echo
echo "=== 2./node USB 2357:010c ==="
if ioreg -l -w0 2>/dev/null | grep -q '"idVendor" = 9047'; then
	echo "    dongle TERPASANG"
else
	echo "    dongle TIDAK terpasang → CABUT-COLOK sekarang"
fi

echo
echo "=== 3. instruksi ==="
cat <<'EOF'
    CARA PALING ANDAL: cabut-colok dongle Wi-Fi USB.
      → node USB baru muncul
      → driver attach ulang
      → start() → init M1 jalan

    Tunggu ${WAIT} detik, lalu periksa marker di bawah.
    (Jika tidak terjadi apa-apa, jalankan ulang skrip ini.)
EOF

echo
echo "=== 4. menunggu ${WAIT} detik ==="
for i in $(seq 1 $((WAIT / 5))); do
	sleep 5
	STATE=$(ioreg -r -c RTL8188EUM1 -w0 2>/dev/null \
		| grep -oE '"M1State" = "[^"]*"' | head -1)
	echo "    [$((i * 5))s] ${STATE:-(belum ada M1State)}"
	case "$STATE" in
		*SELESAI*|*gagal*|*GAGAL*) break ;;
	esac
done

echo
echo "=== 5. marker akhir ==="
ioreg -r -c RTL8188EUM1 -w0 2>/dev/null \
	| grep -oE '"M1[A-Za-z]+" = "[^"]*"' | sed 's/^/    /'

echo
echo "=== 6. Unified Log ==="
log show --last 2m --predicate 'eventMessage contains "RTL8188EU"' \
	--style compact 2>/dev/null | tail -30 | sed 's/^/    /'
