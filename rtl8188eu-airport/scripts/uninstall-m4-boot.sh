#!/bin/bash
# uninstall-m4-boot.sh — lepas driver dari boot dan kembalikan kondisi awal.
#
# Pakai: sudo ./scripts/uninstall-m4-boot.sh
set -uo pipefail

PLIST="/Library/LaunchDaemons/com.zekri.rtl8188e-start.plist"
RUNNER="/usr/local/libexec/rtl8188e-start.sh"
KEXT="/usr/local/lib/RTL8188EAirport.kext"

if [ "$(id -u)" -ne 0 ]; then
	echo "jalankan dengan sudo" >&2
	exit 1
fi

launchctl bootout system/com.zekri.rtl8188e-start 2>/dev/null
rm -f "$PLIST" "$RUNNER"
rm -rf "$KEXT"

# Lepas dari kernel kalau sedang termuat (bisa gagal kalau interface masih pegang).
kmutil unload -b io.github.zekri.RTL8188EAirport 2>/dev/null \
	|| echo "catatan: kext masih termuat sampai reboot"

echo "daemon + kext dihapus."
echo "driver vendor ada di /Library/Extensions.disabled-m1 — kembalikan dengan:"
echo "  sudo mv /Library/Extensions.disabled-m1/*.kext /Library/Extensions/"
