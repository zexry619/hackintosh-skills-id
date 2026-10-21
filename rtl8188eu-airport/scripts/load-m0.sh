#!/bin/bash
# Load kext M0 (butuh hak admin). Kext M0 read-only.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEXT="$ROOT/src/m0-hello/build/RTL8188EUHello.kext"
BUNDLE_ID="io.github.zekri.RTL8188EUHello"

if [[ ! -d "$KEXT" ]]; then
	echo "[load] kext belum dibangun. Jalankan ./scripts/build-m0.sh" >&2
	exit 1
fi

if [[ $EUID -ne 0 ]]; then
	echo "[load] perlu sudo"
	exit 1
fi

echo "[load] $KEXT"
if kmutil load --bundle-id "$BUNDLE_ID" 2>/dev/null; then
	echo "[load] kmutil: OK"
else
	echo "[load] kmutil gagal, coba kextutil..."
	kextutil -v "$KEXT"
fi

sleep 1
echo "[load] status:"
kextstat 2>/dev/null | grep -i 'RTL8188EUHello' || echo "  (tidak muncul di kextstat)"
echo
echo "[load] log:"
log show --last 2m --predicate 'eventMessage CONTAINS "RTL8188EUHello"' 2>/dev/null | tail -40 \
	|| echo "  (log belum tersedia)"
