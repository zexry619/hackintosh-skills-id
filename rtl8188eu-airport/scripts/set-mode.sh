#!/bin/bash
# Set mode driver M1 lewat boot-args OpenCore.
#   sudo ./scripts/set-mode.sh readonly   → default, hanya baca register (aman bersama vendor)
#   sudo ./scripts/set-mode.sh full       → power-on + upload firmware (butuh vendor nonaktif)
#
# Usage: sudo ./scripts/set-mode.sh [readonly|full]
set -euo pipefail

# Deteksi ESP secara otomatis (nama volume bisa berubah: EFI-BIG / Mac OS / ...)
find_esp() {
	local v
	for v in /Volumes/*; do
		if [ -f "$v/EFI/OC/OpenCore.efi" ]; then
			echo "$v"
			return 0
		fi
	done
	return 1
}


ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ESP_DEV="${ESP_DEV:-/dev/disk0s2}"
ESP_MNT="${ESP_MNT:-$(find_esp || true)}"
OC_DIR="$ESP_MNT/EFI/OC"
ARG="rtl8188eum1_mode"
MODE="${1:-readonly}"

if [[ $EUID -ne 0 ]]; then
	echo "Jalankan dengan sudo" >&2
	exit 1
fi
if ! mount | grep -q " on $ESP_MNT "; then
	sudo diskutil mount "$ESP_DEV" >/dev/null || true
fi

sudo python3 - "$OC_DIR/config.plist" "$ARG" "$MODE" <<'PY'
import plistlib, sys
path, arg, mode = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, 'rb') as f:
    d = plistlib.load(f)

nv = d.setdefault('NVRAM', {}).setdefault('Add', {})
key = '7C436110-AB2A-4BBB-A880-FE41995C9F82'
nvram = nv.setdefault(key, {})
args = nvram.get('boot-args', '')

parts = [a for a in args.split()
         if not a.lstrip('-').split('=')[0].startswith(arg)
         and a not in ('full', 'readonly')]
if mode == 'full':
    parts.append('-%s=full' % arg)

nvram['boot-args'] = ' '.join(parts)
with open(path, 'wb') as f:
    plistlib.dump(d, f)
print('[mode] boot-args sekarang: %r' % nvram['boot-args'])
PY

plutil -lint "$OC_DIR/config.plist" >/dev/null && echo "[mode] plutil -lint: OK"
echo "[mode] reboot untuk menerapkan: sudo shutdown -r now"
