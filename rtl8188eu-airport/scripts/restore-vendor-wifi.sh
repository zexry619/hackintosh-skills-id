#!/bin/bash
# Kembalikan driver vendor Realtek (RtWlanU) ke /Library/Extensions.
# Usage: sudo ./scripts/restore-vendor-wifi.sh
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


DISABLED_DIR="/Library/Extensions.disabled-m1"

if [[ $EUID -ne 0 ]]; then
	echo "Jalankan dengan sudo" >&2
	exit 1
fi

if [[ ! -d "$DISABLED_DIR" ]]; then
	echo "Tidak ada $DISABLED_DIR — mungkin sudah dipulihkan."
	exit 0
fi

for k in RtWlanU RtWlanU1827; do
	if [[ -d "$DISABLED_DIR/$k.kext" ]]; then
		mv "$DISABLED_DIR/$k.kext" "/Library/Extensions/$k.kext"
		echo "  $k.kext dipulihkan ke /Library/Extensions"
	fi
done
rmdir "$DISABLED_DIR" 2>/dev/null || true

if [[ -f /Library/LaunchDaemons/com.zekri.realtek-autoload.plist.disabled ]]; then
	mv /Library/LaunchDaemons/com.zekri.realtek-autoload.plist.disabled /Library/LaunchDaemons/com.zekri.realtek-autoload.plist
	echo "  launchdaemon autoload dipulihkan"
fi

# Stage ulang ke vendor agar ikut ter-build AuxKC pada boot berikutnya.
kmutil load -z -p /Library/Extensions/RtWlanU.kext 2>&1 | head -3 || true

echo
echo "Wi-Fi vendor akan aktif setelah reboot."
echo "  sudo shutdown -r now"
