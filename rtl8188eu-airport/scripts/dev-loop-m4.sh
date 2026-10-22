#!/bin/bash
# dev-loop-m4.sh — iterasi driver M4 TANPA reboot.
#
# Alur:
#   1. build RTL8188EAirport.kext
#   2. lepas instance lama dari kernel (unload; kalau ditolak → cabut dongle)
#   3. kmutil load -z -p  (binary baru masuk kernel)
#   4. colok dongle → attach → interface muncul
#   5. check-m4.sh
#
# Syarat: kext TIDAK diinjeksi dari ESP. Kalau masih ada di ESP, binary
# terkunci sejak boot dan langkah 2 pasti gagal.
#
# Pakai:
#   ./scripts/dev-loop-m4.sh              # interaktif (minta cabut/colok)
#   SKIP_PROMPTS=1 ./scripts/dev-loop-m4.sh   # kalau dongle dikendalikan sendiri
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEXT="$ROOT/src/driver/build-m4/RTL8188EAirport.kext"
BUNDLE_ID="io.github.zekri.RTL8188EAirport"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
pause() {
	if [ "${SKIP_PROMPTS:-0}" = "1" ]; then
		return 0
	fi
	read -r -p "  $* [Enter] " _
}

say "[1/5] build"
"$ROOT/scripts/build-m4.sh" || { echo "build gagal"; exit 1; }

say "[2/5] lepas instance lama"
if kextstat 2>/dev/null | grep -q "$BUNDLE_ID"; then
	# Instance biasanya masih memegang IO80211 + USB. Coba unload dulu.
	if ! sudo kmutil unload -b "$BUNDLE_ID" 2>&1 | sed 's/^/  /'; then
		echo "  unload ditolak (masih dipakai)."
	fi
	if kextstat 2>/dev/null | grep -q "$BUNDLE_ID"; then
		echo "  → cabut dongle supaya instance lepas."
		pause "Sudah dicabut?"
		sleep 2
		sudo kmutil unload -b "$BUNDLE_ID" 2>&1 | sed 's/^/  /'
	fi
else
	echo "  (belum termuat)"
fi

if kextstat 2>/dev/null | grep -q "$BUNDLE_ID"; then
	echo "  ✗ masih termuat — tidak bisa ganti binary tanpa reboot."
	echo "    Pastikan kext tidak ada di ESP (lihat CONTINUE.md §2)."
	exit 2
fi

say "[3/5] load binary baru"
sudo kmutil load -z -p "$KEXT" 2>&1 | sed 's/^/  /'
sleep 1
kextstat 2>/dev/null | grep "$BUNDLE_ID" | sed 's/^/  /' || {
	echo "  ✗ kext tidak muncul di kextstat"
	exit 3
}

say "[4/5] colok dongle"
pause "Sudah dicolok?"
sleep 6

say "[5/5] status"
"$ROOT/scripts/check-m4.sh"

say "selesai"
cat <<'EOF'
Iterasi berikutnya: jalankan skrip ini lagi (tanpa reboot).
Kalau dongle tidak mau attach: cabut, tunggu 2 dtk, colok lagi.
EOF
