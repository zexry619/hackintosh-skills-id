#!/bin/bash
# Nyalakan lagi driver vendor Realtek (RtWlanU) — Wi-Fi + aplikasi vendor.
# Usage: sudo ./scripts/vendor-on.sh
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

for k in RtWlanU RtWlanU1827; do
	if [[ -d "$DISABLED_DIR/$k.kext" ]]; then
		mv "$DISABLED_DIR/$k.kext" "/Library/Extensions/$k.kext"
		echo "[vendor-on] $k.kext dikembalikan ke /Library/Extensions"
	fi
done
rmdir "$DISABLED_DIR" 2>/dev/null || true

echo "[vendor-on] rebuild AuxKC..."
kmutil rebuild >/dev/null 2>&1 || true
if kmutil inspect -p /Library/KernelCollections/AuxiliaryKernelExtensions.kc \
    --show-extension-info 2>/dev/null | grep -qi RtWlanU; then
	echo "[vendor-on] RtWlanU ada di AuxKC ✓"
else
	echo "[vendor-on] PERINGATAN: RtWlanU belum masuk AuxKC"
fi

echo "[vendor-on] reboot: sudo shutdown -r now"
