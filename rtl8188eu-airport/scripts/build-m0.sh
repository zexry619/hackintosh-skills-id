#!/bin/bash
# Build kext Milestone 0 (RTL8188EUHello).
#   compile → link → validasi (plist/Mach-O/signature) → ad-hoc sign
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/src/m0-hello"
BUILD="$SRC/build"
KEXT_NAME="RTL8188EUHello"
KEXT="$BUILD/$KEXT_NAME.kext"
MKS="$ROOT/vendor/MacKernelSDK"
SDK="$(xcrun --sdk macosx --show-sdk-path)"

if [[ ! -d "$MKS/Headers" ]]; then
	echo "[build] MacKernelSDK belum ada. Jalankan: ./scripts/fetch-upstream.sh" >&2
	exit 1
fi

rm -rf "$BUILD"
mkdir -p "$KEXT/Contents/MacOS"
cp "$SRC/Info.plist" "$KEXT/Contents/Info.plist"

CXXFLAGS=(
	-mkernel
	-std=c++17
	-fno-rtti
	-fno-exceptions
	-fno-common
	-nostdinc++
	-O2
	-Wall
	-Wno-deprecated-declarations
	-DKERNEL=1
	-DKERNEL_PRIVATE=1
	-I"$MKS/Headers"
)

echo "[build] compile $SRC/$KEXT_NAME.cpp"
clang++ "${CXXFLAGS[@]}" -c "$SRC/$KEXT_NAME.cpp" -o "$BUILD/$KEXT_NAME.o"

echo "[build] link    $KEXT"
# -kext menghasilkan MH_KEXT_BUNDLE (tipe yang dipakai macOS untuk kext).
ld -kext -arch x86_64 -undefined dynamic_lookup \
   -L "$MKS/Library/x86_64" -lkmod \
   -o "$KEXT/Contents/MacOS/$KEXT_NAME" "$BUILD/$KEXT_NAME.o"

echo "[build] validate"
# macOS 15+: 'kextutil -n' sudah tidak didukung (kextutil kini wrapper kmutil).
# Validasi lokal yang tersedia: lint plist, cek tipe Mach-O, cek signature.
plutil -lint "$KEXT/Contents/Info.plist" >/dev/null
if ! file "$KEXT/Contents/MacOS/$KEXT_NAME" | grep -q 'Mach-O 64-bit kext bundle x86_64'; then
	echo "[build] GAGAL: binary bukan Mach-O bundle yang valid" >&2
	file "$KEXT/Contents/MacOS/$KEXT_NAME" >&2
	exit 1
fi

echo "[build] sign (ad-hoc)"
codesign -f -s - "$KEXT" >/dev/null 2>&1
codesign --verify --deep --strict "$KEXT"

UNDEF="$(nm -u "$KEXT/Contents/MacOS/$KEXT_NAME" 2>/dev/null | wc -l | tr -d ' ')"
echo "[build] simbol undefined (dicepat di kernel): $UNDEF"

echo "[build] OK  → $KEXT"
du -sh "$KEXT" | sed 's/^/[build] ukuran: /'
echo
echo "Catatan: jangan load sebelum './scripts/check-device.sh' (konflik dengan RtWlanU)."
echo "M0 bersifat READ-ONLY sehingga tetap aman walau RtWlanU masih aktif."
