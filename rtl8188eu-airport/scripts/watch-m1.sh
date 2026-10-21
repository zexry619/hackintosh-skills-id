#!/bin/bash
# watch-m1.sh — TANGKAP marker M1 secepat mungkin selama init berjalan.
#
# Driver melakukan self-detach setelah init selesai → node IORegistry
# hilang → hasil yang tertinggal di property node hilang juga.
# Skrip ini mem-poll registry tiap 100 ms dan menyimpan setiap perubahan.
#
# Usage: sudo ./scripts/watch-m1.sh [durasi_detik]
set -uo pipefail

DUR="${1:-90}"
OUT="/Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/logs/watch-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$(dirname "$OUT")"

echo "menangkap selama ${DUR} detik → $OUT"
echo "mulai: $(date +%H:%M:%S)"

last=""
end=$(( $(date +%s) + DUR ))
while [ "$(date +%s)" -lt "$end" ]; do
	cur=$(ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | tr -d '\n' \
		| grep -oE '"M1[A-Za-z0-9]*" = "[^"]*"' | sed 's/"//g' | tr '\n' '|')
	if [ -n "$cur" ] && [ "$cur" != "$last" ]; then
		printf '%s\n' "$cur" >> "$OUT"
		printf '[%s] %s\n' "$(date +%H:%M:%S)" "$cur"
		last="$cur"
	fi
	sleep 0.1
done
echo "selesai → $OUT"
