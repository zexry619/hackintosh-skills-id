#!/bin/bash
# Load kext Milestone 1 (RTL8188EUM1).
# PERINGATAN: driver ini menulis register chip. Wajib nonaktifkan RtWlanU dulu.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEXT="$ROOT/src/driver/build/RTL8188EUM1.kext"
BUNDLE_ID="io.github.zekri.RTL8188EUM1"

if [[ ! -d "$KEXT" ]]; then
	echo "[load] kext belum dibangun. Jalankan ./scripts/build-m1.sh" >&2
	exit 1
fi

if [[ $EUID -ne 0 ]]; then
	echo "[load] perlu sudo" >&2
	exit 1
fi

# --- safety check: driver vendor tidak boleh aktif bersamaan ---
if kextstat 2>/dev/null | grep -qi 'RtWlanU'; then
	if [[ "${FORCE:-0}" != "1" ]]; then
		echo "[load] DIBATAS: RtWlanU masih aktif — keduanya akan berebut chip." >&2
		echo "" >&2
		echo "  Nonaktifkan dulu (pilih salah satu):" >&2
		echo "   a) pindahkan + reboot:" >&2
		echo "      sudo mv /Library/Extensions/RtWlanU.kext /Library/Extensions/RtWlanU.kext.disabled" >&2
		echo "      sudo mv /Library/Extensions/RtWlanU1827.kext /Library/Extensions/RtWlanU1827.kext.disabled" >&2
		echo "   b) unload saat runtime:" >&2
		echo "      sudo kextunload -b com.realtek.driver.RtWlanU" >&2
		echo "   c) paksa tetap jalankan (berisiko): FORCE=1 $0" >&2
		exit 2
	fi
	echo "[load] PERINGATAN: FORCE=1, RtWlanU masih aktif."
fi

echo "[load] $KEXT"
if kmutil load --bundle-id "$BUNDLE_ID" 2>/dev/null; then
	echo "[load] kmutil: OK"
else
	echo "[load] kmutil gagal, coba kextutil..."
	kextutil -v "$KEXT"
fi

sleep 2
echo
echo "[load] status:"
kextstat 2>/dev/null | grep -i 'RTL8188EUM1' || echo "  (tidak muncul di kextstat)"
echo
echo "[load] log:"
log show --last 3m --predicate 'eventMessage CONTAINS "RTL8188EUM1" OR eventMessage CONTAINS "RTL8188EU:"' 2>/dev/null | tail -60 \
	|| echo "  (log belum tersedia)"
