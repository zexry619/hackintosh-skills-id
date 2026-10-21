#!/bin/bash
# Trigger match driver M1 ke device USB tanpa reboot, lalu tampilkan progres.
#
# Kenapa perlu: pada boot, personality dari KC dipublikasikan sebelum node USB
# ada, sehingga IOKit tidak otomatis match. Mengirim personality ke katalog
# secara manual memaksa matching ulang.
#
# Usage: sudo ./scripts/trigger-match.sh
set -uo pipefail

BUNDLE_ID="io.github.zekri.RTL8188EUM1"
PERSONALITY="${1:-RTL8188EUM1}"

echo "=== kirim personality '$PERSONALITY' ke katalog ==="
sudo kmutil load -b "$BUNDLE_ID" -P "$PERSONALITY" 2>&1 | head -3
sleep 2

echo
echo "=== status match (ioreg) ==="
ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | grep -E 'RTL8188EUM1 <|M1State|M1Provider|M1Mode|M1Mac' | sed 's/^/  /'

echo
echo "=== pesan kernel driver ==="
log show --last 2m --style compact --info --debug \
	--predicate 'eventMessage CONTAINS "RTL8188EUM1:" OR eventMessage CONTAINS "RTL8188EU:"' 2>/dev/null \
	| grep -vE 'kernelmanager|kmutil|log run noninteractively' | tail -25 | sed 's/^/  /'

echo
echo "=== interpretasi M1State ==="
STATE=$(ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | grep -m1 '"M1State"' | sed 's/.*= "//; s/".*//')

echo
echo "=== M1Log (riwayat langkah) ==="
ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | grep -m1 '"M1Log"' | sed 's/^ */  /'
echo
echo "=== penghitung transfer USB ==="
ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | grep -E '"M1In|"M1Out' | sed 's/^ */  /' 
case "$STATE" in
	"")              echo "  (tidak ada M1State → start() belum dipanggil)";;
	start-called)    echo "  start() dipanggil, lanjut ke langkah berikutnya";;
	started)         echo "  driver aktif, timer akan menjalankan init";;
	usb-attach)      echo "  sedang claim device USB";;
	usb-ok)          echo "  USB OK (device + interface diklaim)";;
	chipid)          echo "  sedang deteksi chip";;
	efuse)           echo "  sedang baca EFUSE (MAC)";;
	power-on)        echo "  sedang power-on chip";;
	dma-init)        echo "  sedang inisialisasi DMA/LLT";;
	firmware)        echo "  sedang upload firmware";;
	SELESAI)         echo "  ✅ M1 SELESAI";;
	*)               echo "  state: $STATE";;
esac
