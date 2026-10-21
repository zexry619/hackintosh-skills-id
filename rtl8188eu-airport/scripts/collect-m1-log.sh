#!/bin/bash
# Kumpulkan log hasil uji M1 (jalankan setelah reboot).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/m1-log.txt"

echo "=== status kext ==="
kextstat 2>/dev/null | grep -iE 'RtWlanU|RTL8188EUM1' | sed 's/^/  /' || echo "  (tidak ada kext Wi-Fi aktif)"

echo
echo "=== AuxKC di disk ==="
kmutil inspect -p /Library/KernelCollections/AuxiliaryKernelExtensions.kc --show-extension-info 2>/dev/null \
	| grep -iE 'zekri|RtWlan' | sed 's/^/  /' || echo "  (tidak ada entri Wi-Fi)"

echo
echo "=== ioreg ==="
ioreg -r -c RTL8188EUM1 2>/dev/null | head -10 || echo "  (driver tidak match device)"

echo
echo "=== log kernel (10 menit terakhir) ==="
log show --last 45m --style compact \
	--predicate 'eventMessage CONTAINS "RTL8188EUM1" OR eventMessage CONTAINS "RTL8188EU:"' 2>/dev/null \
	| tail -80 | tee "$OUT"

echo
echo "=== ringkasan ==="
if grep -q 'M1 init SELESAI' "$OUT" 2>/dev/null; then
	echo "  ✅ M1 BERHASIL"
	grep -E 'rom: MAC|firmware: upload OK|chip flags' "$OUT" | sed 's/^/     /'
else
	echo "  ⚠️  M1 belum selesai — lihat log di atas"
fi
echo
echo "(log tersimpan di $OUT)"
