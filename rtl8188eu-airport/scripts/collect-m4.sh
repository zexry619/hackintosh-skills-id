#!/bin/bash
# collect-m4.sh — satu perintah, semua bukti. Dipakai kalau memang harus
# reboot: satu boot menghasilkan satu laporan lengkap, tidak ada "kurang
# data → reboot lagi".
#
# Output: logs/m4-<timestamp>.txt
#
# Pakai:
#   ./scripts/collect-m4.sh            # tanpa sudo (data yang butuh root dilewati)
#   sudo ./scripts/collect-m4.sh       # lengkap
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/logs/m4-$(date +%Y%m%d-%H%M%S).txt"
BUNDLE_ID="io.github.zekri.RTL8188EAirport"

mkdir -p "$ROOT/logs"

sec() { printf '\n===== %s =====\n' "$*"; }

{
	printf 'RTL8188E M4 — laporan diagnostik\n'
	printf 'waktu   : %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
	printf 'uptime  : %s\n' "$(uptime)"
	printf 'boot    : %s\n' "$(sysctl -n kern.boottime 2>/dev/null)"
	printf 'model   : %s\n' "$(sysctl -n hw.model 2>/dev/null)"
	printf 'macOS   : %s\n' "$(sw_vers -productVersion 2>/dev/null) ($(sw_vers -buildVersion 2>/dev/null))"

	sec "1. kext"
	kextstat 2>/dev/null | grep -i -E "zekri|RTL8188|AirportItlwm" || echo "(tidak ada kext kita)"

	sec "2. USB"
	ioreg -p IOUSB -w0 -l 2>/dev/null | grep -E '"USB Product Name"|"idVendor"|"idProduct"' | head -40

	sec "3. properti diagnostik driver"
	ioreg -l -w0 2>/dev/null | grep -E "RTL8188E-" || echo "(tidak ada)"

	sec "4. interface jaringan"
	ifconfig -a 2>/dev/null | grep -E "^[a-z0-9]+:|status:|ether" | head -60

	sec "5. hardware port (Wi-Fi)"
	networksetup -listallhardwareports 2>/dev/null

	sec "6. state en2"
	ifconfig en2 2>/dev/null || echo "(en2 tidak ada)"
	echo "--- ipconfig getsummary ---"
	ipconfig getsummary en2 2>&1 | head -40
	echo "--- networksetup ---"
	networksetup -getairportnetwork en2 2>&1
	networksetup -getairportpower en2 2>&1

	sec "7. counter en2"
	netstat -I en2 -b 2>/dev/null || echo "(tidak ada)"

	sec "8. route & DNS"
	netstat -rn 2>/dev/null | grep -E "^default|en2" | head -20
	scutil --dns 2>/dev/null | grep -E "nameserver|resolver" | head -10

	sec "9. Wi-Fi (SPAirPortDataType)"
	system_profiler SPAirPortDataType 2>/dev/null | head -40

	sec "10. panic terakhir"
	ls -t /Library/Logs/DiagnosticReports/*.panic 2>/dev/null | head -5 || echo "(tidak ada)"
	latest=$(ls -t /Library/Logs/DiagnosticReports/*.panic 2>/dev/null | head -1)
	if [ -n "${latest:-}" ]; then
		echo "--- $latest ---"
		/usr/bin/python3 - "$latest" <<'PY' 2>/dev/null || head -20 "$latest"
import json, sys
p = sys.argv[1]
for line in open(p, errors='replace'):
    try:
        d = json.loads(line)
    except Exception:
        continue
    s = d.get('macOSPanicString')
    if not s:
        continue
    for l in s.split('\n'):
        if 'panic(' in l or 'RTL8188EAirport :' in l or 'dependency:' in l:
            print(l[:160])
PY
	fi

	sec "11. log kernel (kalau root)"
	if [ "$(id -u)" -eq 0 ]; then
		/usr/bin/log show --last 30m --style compact --predicate \
			'eventMessage CONTAINS "RTL8188E" OR eventMessage CONTAINS "WCL" OR eventMessage CONTAINS "AirportItlwm"' \
			2>/dev/null | tail -80 || echo "(log show gagal)"
	else
		echo "(jalankan dengan sudo untuk bagian ini)"
	fi

	sec "12. catatan"
	echo "Kirim file ini apa adanya. Jangan menambal manual — kalau ada"
	echo "bagian yang kosong, itu juga informasi."
} >"$OUT" 2>&1

echo "laporan: $OUT"
wc -l "$OUT" | sed 's/^/  /'
