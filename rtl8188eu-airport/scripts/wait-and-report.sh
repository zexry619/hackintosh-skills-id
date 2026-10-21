#!/bin/bash
# Tunggu user mencabut-colok dongle USB, lalu tampilkan hasil init M1.
#
# Alur (tanpa reboot):
#   1. build + hot-swap ke kernel   (scripts/dev-loop.sh, atau sudah manual)
#   2. cabut-colok dongle USB       (user)
#   3. driver attach ulang → uptime > 60 s → init jalan otomatis
#   4. script ini membaca hasil dari ioreg
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=============================================================="
echo " Cabut-colok dongle Wi-Fi USB sekarang (2 detik)"
echo " Driver akan attach ulang & langsung menjalankan init."
echo "=============================================================="
read -r -p " Sudah? [Enter] " _
sleep 5

echo
echo "=== M1Log (riwayat langkah) ==="
ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | grep -m1 '"M1Log"' | sed 's/^ */  /'

echo
echo "=== state & counter ==="
ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | grep -E '"M1(Build|State|Last|Interface|Uptime|In|Out)' | sed 's/^/  /'

STATE=$(ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | grep -m1 '"M1State"' | sed 's/.*= "//; s/".*//')
echo
case "$STATE" in
	started-inert)   echo "  masih inert —attach terjadi < 60 dtk setelah boot?";;
	init-dijadwalkan) echo "  init dijadwalkan, tunggu…";;
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
