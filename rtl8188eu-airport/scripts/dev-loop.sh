#!/bin/bash
# Loop pengembangan driver TANPA REBOOT.
#
# Kenapa butuh 2× cabut-colok:
#   1. Replug #1 → instance lama lepas → kext bisa di-unload
#   2. kmutil load -z -p → binary baru masuk kernel (hot-swap)
#   3. Replug #2 → instance baru attach → init jalan (uptime > 60 dtk)
#
# Driver inert saat boot, jadi mesin tidak pernah gagal boot karena kext ini.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEXT="$ROOT/src/driver/build/RTL8188EUM1.kext"
BUNDLE_ID="io.github.zekri.RTL8188EUM1"
PERSONALITY="RTL8188EUM1"

echo "=============================================================="
echo " [1/4] build kext"
echo "=============================================================="
"$ROOT/scripts/build-m1.sh" | tail -2 || exit 1

echo
echo "=============================================================="
echo " [2/4] CABUT-COLOK dongle USB #1"
echo "        (supaya instance lama lepas & kext bisa di-unload)"
echo "=============================================================="
read -r -p "  Sudah dicabut-colok? [Enter] " _
sleep 4

echo
echo "=============================================================="
echo " [3/4] hot-swap binary baru ke kernel"
echo "=============================================================="
sudo kmutil load -z -p "$KEXT" 2>&1 | head -3
sleep 2
kextstat 2>/dev/null | grep -i zekri | sed 's/^/  /'

echo
echo "=============================================================="
echo " [4/4] CABUT-COLOK dongle USB #2"
echo "        (instance baru attach → init otomatis jalan)"
echo "=============================================================="
read -r -p "  Sudah dicabut-colok? [Enter] " _
sleep 6

echo
echo "=============================================================="
echo " HASIL"
echo "=============================================================="
ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | grep -E '"M1' | sed 's/^/  /'

STATE=$(ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | grep -m1 '"M1State"' | sed 's/.*= "//; s/".*//')
echo
case "$STATE" in
	started-inert)   echo "  ⚠️  masih inert — cek M1Build (build mana yang aktif?)";;
	init-dijadwalkan) echo "  init dijadwalkan…";;
	usb-attach)      echo "  claim USB";;
	usb-ok)          echo "  ✅ USB aman (device diklaim)";;
	chipid)          echo "  deteksi chip";;
	efuse)           echo "  baca EFUSE (MAC)";;
	power-on)        echo "  power-on chip";;
	dma-init)        echo "  inisialisasi DMA/LLT";;
	firmware)        echo "  upload firmware";;
	SELESAI)         echo "  ✅✅ M1 SELESAI";;
	watchdog-abort)  echo "  ⚠️  watchdog: init dibatalkan (device tidak merespons)";;
	*)               echo "  state: ${STATE:-<tidak ada>}";; 
esac
