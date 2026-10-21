#!/bin/bash
# ⭐ LOOP ITERASI TANPA REBOOT.
#
#   1. build kext (varian UJI: boleh traffic USB)
#   2. hot-swap ke kernel  (kmutil load -z -p)
#   3. cabut-colok dongle USB  →  node USB dibuat ulang → driver baru attach
#   4. cek hasil (M1State / M1Log / M1Rx)
#
# Karena driver build AMAN (default) tidak pernah menyentuh device, kext di ESP
# aman → tidak ada lagi yang perlu di-reboot.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_KEXT="$ROOT/src/build-test/RTL8188EUM1.kext"
BUNDLE_ID="io.github.zekri.RTL8188EUM1"

cd "$ROOT"

echo "=== 1. build (varian UJI) ==="
./scripts/build-m1.sh 2>&1 | grep -E 'error|varian UJI|\[build\] OK' | head -4

echo
echo "=== 2. hot-swap ke kernel ==="
sudo kmutil load -z -p "$TEST_KEXT" 2>&1 | head -3
sleep 2
kextstat 2>/dev/null | grep -i zekri | sed 's/^/  /'

echo
echo "=============================================================="
echo " 3. CABUT-COLOK dongle Wi-Fi USB (2 detik)"
echo "    Driver yang lama akan mati bersama node USB-nya,"
echo "    lalu kext baru attach & menjalankan init."
echo "=============================================================="
read -r -p "  Sudah? [Enter] " _
sleep 6

echo
echo "=== 4. hasil ==="
ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | grep -E '"M1' | sed 's/^/  /'

STATE=$(ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | grep -m1 '"M1State"' | sed 's/.*= "//; s/".*//')
echo
case "$STATE" in
	started-safe-no-traffic) echo "  ⚠️  build AMAN aktif — tidak ada traffic USB (normal untuk build default)";;
	started-inert)          echo "  ℹ️  attach < 60 dtk setelah boot → INERT (aman)";;
	usb-attach)            echo "  claim USB";;
	usb-ok)                echo "  ✅ USB aman (device+interface diklaim)";;
	efuse)                 echo "  baca EFUSE (MAC)";;
	power-on)              echo "  power-on (flow vendor)";;
	dma-init)              echo "  LLT/DMA init";;
	firmware)              echo "  upload firmware";;
	usb-bulk)              echo "  buka pipe bulk";;
	SELESAI)               echo "  ✅✅ M1 SELESAI";;
	watchdog-abort)        echo "  ⚠️  watchdog: init dibatalkan (device tidak merespons)";;
	*)                     echo "  state: ${STATE:-<tidak ada>}";;
esac

echo
echo "  (detail: ioreg -r -c RTL8188EUM1 -w0 | grep M1)"
