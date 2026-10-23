#!/bin/bash
# vendor-sym.sh — cari fungsi di driver vendor Realtek (RtWlanU.kext).
#
# Kenapa ini penting: binary vendor TIDAK di-strip. Ada ~10.300 simbol global,
# 224 di antaranya fungsi HAL 8188E dengan nama asli (TxFillDescriptor8188EUsb,
# SetKey8188EUsb, _InitEDCA_8188EU, ...). Artinya kita tidak perlu menebak
# alamat atau membongkar buta — peta fungsinya sudah tersedia.
#
# Pakai:
#   ./scripts/vendor-sym.sh              # semua fungsi 8188E
#   ./scripts/vendor-sym.sh tx           # filter "tx"
#   ./scripts/vendor-sym.sh key          # filter "key"
#   ./scripts/vendor-sym.sh "" | head -50
set -uo pipefail

BIN="${VENDOR_BIN:-/Library/Extensions/RtWlanU.kext/Contents/MacOS/RtWlanU}"
FILTER="${1:-8188}"

if [ ! -f "$BIN" ]; then
	echo "binary vendor tidak ada: $BIN" >&2
	exit 1
fi

nm -gU "$BIN" 2>/dev/null \
	| c++filt \
	| grep " T " \
	| grep -i -- "$FILTER" \
	| sed 's/^[0-9a-f]* T //' \
	| sort
