#!/bin/bash
# Matikan driver vendor Realtek (RtWlanU) supaya driver kita bisa attach
# ke node USB modern (IOUSBHostDevice / IOUSBHostInterface).
#
# Kenapa wajib: selama RtWlanU aktif, stack USB legacy claiming node
# IOUSBHostDevice (AppleUSBHostLegacyClient) DAN node interface
# (AppleUSBInterface). Satu node hanya bisa punya satu driver → driver kita
# tidak akan match ("!matched" di ioreg).
#
# Usage: sudo ./scripts/vendor-off.sh
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

mkdir -p "$DISABLED_DIR"
for k in RtWlanU RtWlanU1827; do
	src="/Library/Extensions/$k.kext"
	if [[ -d "$src" ]]; then
		mv "$src" "$DISABLED_DIR/$k.kext"
		echo "[vendor-off] $k.kext dimatikan"
	fi
done

# Bersihkan staging AuxKC (instructions + uakl + StashedExtensions) supaya
# kext vendor tidak ikut ter-build, lalu rebuild.
echo "[vendor-off] bersihkan staging AuxKC..."
python3 scripts/clean-auxkc.py rtwlanu

echo "[vendor-off] rebuild AuxKC..."
kmutil rebuild >/dev/null 2>&1 || true
if kmutil inspect -p /Library/KernelCollections/AuxiliaryKernelExtensions.kc \
    --show-extension-info 2>/dev/null | grep -qi RtWlanU; then
	echo "[vendor-off] PERINGATAN: RtWlanU masih ada di AuxKC"
else
	echo "[vendor-off] AuxKC bersih (tidak ada RtWlanU)"
fi

echo "[vendor-off] reboot: sudo shutdown -r now"
