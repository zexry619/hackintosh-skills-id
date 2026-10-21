#!/bin/bash
# Ambil seluruh sumber upstream yang dibutuhkan oleh proyek.
# Idempotent: file yang sudah ada dilewati (kecuali dipaksa hapus manual).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM="$ROOT/upstream"
VENDOR="$ROOT/vendor"
FIRMWARE="$ROOT/firmware"

ITLWM_REPO="https://github.com/laobamac/itlwm.git"
RTW_REPO="https://github.com/JoMei9019-real/AirPort-RTW.git"
MKS_REPO="https://github.com/acidanthera/MacKernelSDK.git"
OPENBSD_RAW="https://raw.githubusercontent.com/openbsd/src/master"

FW_URL="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/rtlwifi/rtl8188eufw.bin"
FW_SHA="2ff74315287529dec2e50eb57d6e0c97d2116f28ae166773ccdf93b6360000c4"

mkdir -p "$UPSTREAM/openbsd/sys/dev/usb" \
         "$UPSTREAM/openbsd/sys/dev/ic" \
         "$VENDOR" "$FIRMWARE"

clone() { # clone <url> <dir> <branch>
	local url="$1" dir="$2" branch="$3"
	if [[ -d "$dir/.git" ]]; then
		echo "[fetch] sudah ada: $(basename "$dir")"
		return 0
	fi
	echo "[fetch] clone $url -> ${dir#$ROOT/}"
	git clone --depth 1 --branch "$branch" -q "$url" "$dir"
}

fetch_file() { # fetch_file <remote-path> <local-path>
	local remote="$1" local="$2"
	if [[ -s "$local" ]]; then
		echo "[fetch] sudah ada: ${local#$ROOT/}"
		return 0
	fi
	echo "[fetch] unduh $remote"
	curl -fsSL -o "$local" "$OPENBSD_RAW/$remote"
}

echo "=== 1/5  laobamac/itlwm (GPL-2.0) — net80211 + frontend AirportItlwm"
clone "$ITLWM_REPO" "$UPSTREAM/itlwm" main

echo "=== 2/5  AirPort-RTW (GPL-2.0) — pola shim USB + frontend Realtek"
clone "$RTW_REPO" "$UPSTREAM/AirPort-RTW" main

echo "=== 3/5  MacKernelSDK — header kernel"
clone "$MKS_REPO" "$VENDOR/MacKernelSDK" master

echo "=== 4/5  OpenBSD urtwn + rtwn (ISC)"
fetch_file "sys/dev/usb/if_urtwn.c"   "$UPSTREAM/openbsd/sys/dev/usb/if_urtwn.c"
fetch_file "sys/dev/ic/rtwn.c"         "$UPSTREAM/openbsd/sys/dev/ic/rtwn.c"
fetch_file "sys/dev/ic/rtwnvar.h"      "$UPSTREAM/openbsd/sys/dev/ic/rtwnvar.h"
fetch_file "sys/dev/ic/r92creg.h"      "$UPSTREAM/openbsd/sys/dev/ic/r92creg.h"
fetch_file "sys/dev/usb/usbdevs"       "$UPSTREAM/openbsd/sys/dev/usb/usbdevs"

echo "=== 5/5  firmware rtl8188eufw.bin"
if [[ ! -s "$FIRMWARE/rtl8188eufw.bin" ]]; then
	curl -fsSL -o "$FIRMWARE/rtl8188eufw.bin" "$FW_URL"
fi
ACTUAL="$(shasum -a 256 "$FIRMWARE/rtl8188eufw.bin" | awk '{print $1}')"
if [[ "$ACTUAL" != "$FW_SHA" ]]; then
	echo "[fetch] PERINGATAN: checksum firmware tidak cocok"
	echo "       harapan: $FW_SHA"
	echo "        aktual: $ACTUAL"
else
	echo "[fetch] firmware OK (sha256 cocok)"
fi

cat <<'EOF'

Selesai. Ringkasan isi:
  upstream/itlwm/            → itl80211 (net80211 port) + AirportItlwm (frontend)
  upstream/AirPort-RTW/      → contoh shim USB (src/kext/RTW88USBDevice.cpp)
  upstream/openbsd/          → if_urtwn.c, rtwn.c, rtwnvar.h, r92creg.h
  vendor/MacKernelSDK/       → header kernel untuk build kext
  firmware/rtl8188eufw.bin   → firmware upload (15.262 byte)

Langkah berikutnya:  ./scripts/build-m0.sh
EOF
