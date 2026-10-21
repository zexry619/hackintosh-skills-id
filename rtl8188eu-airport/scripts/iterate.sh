#!/bin/bash
# Loop iterasi TANPA REBOOT.
#
# Rahasia: `kmutil load -z -p <bundle>` bisa HOT-SWAP kext yang sedang termuat
# (bundle id sama) — kext ter-unload dari kernel lalu build baru dimuat.
# Tapi driver instance yang lama masih "nempel" ke device USB (request-nya
# menggantung), sehingga node USB tetap diklaim dan kext baru tidak bisa match.
#
# Solusi: cabut-colok dongle USB → node USB dibuat ulang → driver lama ikut
# mati → kext baru (binary baru) langsung match & jalan.
#
# Usage:
#   ./scripts/iterate.sh          # build + hot-swap + minta replug + cek
#   ./scripts/iterate.sh --check  # hanya cek status
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEXT="$ROOT/src/driver/build/RTL8188EUM1.kext"
BUNDLE_ID="io.github.zekri.RTL8188EUM1"

if [[ "${1:-}" != "--check" ]]; then
	echo "=== 1. build ==="
	"$ROOT/scripts/build-m1.sh" | tail -3

	echo
	echo "=== 2. hot-swap kext ke kernel (tanpa reboot) ==="
	sudo kmutil load -z -p "$KEXT" 2>&1 | head -3
	sleep 2
	kextstat 2>/dev/null | grep -i rtl8188 | sed 's/^/  /'
fi

echo
echo "=============================================================="
echo " 3. CABUT-COLOK dongle Wi-Fi USB (2 detik, bukan reboot!)"
echo "=============================================================="
echo "  Cabut dari port USB, lalu colok lagi."
echo "  Node USB akan dibuat ulang → driver lama mati →"
echo "  kext baru (binary baru) langsung match & jalan."
echo
read -r -p "  Sudah dicabut-colok? [Enter untuk lanjut] " _
sleep 3

echo
echo "=== 4. status ==="
ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | grep -E '"M1' | sed 's/^/  /'

STATE=$(ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | grep -m1 '"M1State"' | sed 's/.*= "//; s/".*//')
echo
echo "=== 5. M1Log ==="
ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | grep -m1 '"M1Log"' | sed 's/^ */  /'
echo
echo "=== 6. interpretasi ==="
case "$STATE" in
	"")              echo "  driver belum match → personality belum fired";;
	usb-attach)      echo "  sedang claim USB";;
	usb-ok)          echo "  USB aman";;
	chipid)          echo "  deteksi chip";;
	efuse)           echo "  baca EFUSE/MAC";;
	power-on)        echo "  power-on chip";;
	dma-init)        echo "  inisialisasi DMA";;
	firmware)        echo "  upload firmware";;
	SELESAI)         echo "  ✅ M1 SELESAI";;
	*)               echo "  state: $STATE";;
esac
