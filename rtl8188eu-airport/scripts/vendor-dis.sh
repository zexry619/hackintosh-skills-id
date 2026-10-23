#!/bin/bash
# vendor-dis.sh — disassembly satu fungsi driver vendor berdasarkan NAMA.
#
# Pakai:
#   ./scripts/vendor-dis.sh _InitEDCA_8188EU
#   ./scripts/vendor-dis.sh TxFillDescriptor8188EUsb 600
#
# Alamat dicari otomatis dari tabel simbol, jadi tidak perlu menghitung
# offset manual. Hasilnya bisa dibandingkan langsung dengan implementasi
# kita di src/urtwn/.
set -uo pipefail

BIN="${VENDOR_BIN:-/Library/Extensions/RtWlanU.kext/Contents/MacOS/RtWlanU}"
NAME="${1:?pakai: vendor-dis.sh <nama-fungsi> [panjang-byte]}"
LEN="${2:-400}"

if [ ! -f "$BIN" ]; then
	echo "binary vendor tidak ada: $BIN" >&2
	exit 1
fi

ADDR=$(nm -gU "$BIN" 2>/dev/null | c++filt \
	| grep " T " | grep -F -- "$NAME(" | head -1 | awk '{print $1}')

if [ -z "$ADDR" ]; then
	echo "fungsi tidak ditemukan: $NAME" >&2
	echo "coba: ./scripts/vendor-sym.sh \"$NAME\"" >&2
	exit 2
fi

START=$((16#$ADDR))
END=$((START + LEN))

echo "# $NAME @ 0x$ADDR ($LEN byte)"
objdump -d --start-address="$START" --stop-address="$END" "$BIN"
