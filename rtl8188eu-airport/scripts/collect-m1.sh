#!/bin/bash
# collect-m1.sh — kumpulkan hasil uji M1 (marker registry + Unified Log).
#
# Jalankan SETELAH reboot + cabut-colok dongle.
# Usage: sudo ./scripts/collect-m1.sh
set -uo pipefail

echo "═══════════════ HASIL UJI M1 ═══════════════"
echo " uptime : $(uptime | sed 's/.*up //;s/,.*//')"
echo " boot   : $(sysctl -n kern.boottime 2>/dev/null | sed 's/.*sec = //;s/,.*//')"
echo

echo "── kext ──"
kextstat 2>/dev/null | grep -i zekri | sed 's/^/  /' || echo "  (tidak termuat!)"
echo

echo "── marker registry ──"
ioreg -r -c RTL8188EUM1 -w0 2>/dev/null \
	| grep -oE '"M1[A-Za-z0-9]*" = "[^"]*"' | sed 's/^/  /' || echo "  (tidak ada node driver)"
echo

echo "── node USB Wi-Fi & driver yang claim ──"
ioreg -l -w0 2>/dev/null | grep -A12 '"idVendor" = 9047' \
	| grep -E '\+-o |"USB Product Name"' | head -8 | sed 's/^/  /'
echo

echo "── Unified Log (RTL8188EU) ──"
log show --last 10m --predicate 'eventMessage contains "RTL8188EU"' \
	--style compact 2>/dev/null | tail -50 | sed 's/^/  /'
echo

echo "── ringkasan ──"
STATE=$(ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | grep -oE '"M1State" = "[^"]*"' | head -1)
MAC=$(ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | grep -oE '"M1Mac" = "[^"]*"' | head -1)
XTAL=$(ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | grep -oE '"M1Xtal" = "[^"]*"' | head -1)
echo "  M1State : ${STATE:-(tidak ada)}"
echo "  M1Mac   : ${MAC:-(tidak ada)}   (harapan: 98:03:8e:9e:bc:24)"
echo "  M1Xtal  : ${XTAL:-(tidak ada)}   (harapan: bukan 0xff / 0x00)"
echo
echo "── panic? ──"
ls -lt /Library/Logs/DiagnosticReports/*.panic 2>/dev/null | head -2 \
	| awk '{print "  "$6,$7,$8,$9}'
