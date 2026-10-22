#!/bin/bash
# Build kext Milestone 1 (RTL8188EUM1): firmware upload + EFUSE + chip ID.
#   generate firmware array → compile → link → validasi → sign
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/src"
BUILD="$SRC/driver/build"
KEXT_NAME="RTL8188EUM1"
KEXT="$BUILD/$KEXT_NAME.kext"
MKS="$ROOT/vendor/MacKernelSDK"

if [[ ! -d "$MKS/Headers" ]]; then
	echo "[build] MacKernelSDK belum ada. Jalankan: ./scripts/fetch-upstream.sh" >&2
	exit 1
fi

echo "[build] generate firmware array"
"$ROOT/scripts/gen-firmware-array.sh"

rm -rf "$BUILD"
mkdir -p "$KEXT/Contents/MacOS"
cp "$SRC/driver/Info.plist" "$KEXT/Contents/Info.plist"

COMMON=(
	-mkernel
	-fno-common
	-O2
	-Wall
	-Wno-deprecated-declarations
	-Wno-sign-conversion
	-Wno-implicit-int-conversion
	-DKERNEL=1
	-DKERNEL_PRIVATE=1
	-I"$MKS/Headers"
	-I"$SRC/urtwn"
	-I"$SRC/usb"
	-I"$SRC/driver"
	-I"$ROOT/upstream/itlwm/include"
	-I"$ROOT/upstream/itlwm/include/HAL"
	-I"$ROOT/upstream/itlwm/itl80211"
	-I"$ROOT/upstream/itlwm/itl80211/linux"
	-I"$ROOT/upstream/itlwm/itl80211/openbsd"
	-I"$ROOT/upstream/itlwm/itl80211/openbsd/net80211"
)

CXXFLAGS=(
	-std=c++17
	-fno-rtti
	-fno-exceptions
	-nostdinc++
	"${COMMON[@]}"
)

CFLAGS=(
	-std=gnu11
	"${COMMON[@]}"
)

SOURCES=(
	"$SRC/driver/RTL8188EUM1.cpp"
	"$SRC/driver/UsbBackend.cpp"
	"$SRC/driver/ItlRtl8188E.cpp"
	"$SRC/driver/kmod_info.c"
	"$SRC/urtwn/rtwn_m1.cpp"
	"$SRC/urtwn/rtwn_seq.c"
	"$SRC/urtwn/rtwn_seq_efuse.c"
	"$SRC/urtwn/rtwn_flow.c"
	"$SRC/urtwn/rtwn_efuse_8188e.c"
	"$SRC/urtwn/rtwn_usb.c"
	"$SRC/urtwn/rtwn_mp_8188e.c"
	"$SRC/urtwn/rtwn_hal_8188e.c"
	"$SRC/urtwn/rtwn_platform_kernel.c"
	"$SRC/urtwn/firmware_rtl8188eufw.cpp"
	"$SRC/usb/usb_compat.cpp"
)

OBJECTS=()
for src in "${SOURCES[@]}"; do
	obj="$BUILD/$(basename "${src%.*}").o"
	echo "[build] compile $(basename "$src")"
	case "$src" in
		*.c) "${CC:-clang}" "${CFLAGS[@]}" -c "$src" -o "$obj" ;;
		*)   "${CXX:-clang++}" "${CXXFLAGS[@]}" -c "$src" -o "$obj" ;;
	esac
	OBJECTS+=("$obj")
done

echo "[build] link    $KEXT"
ld -kext -arch x86_64 -undefined dynamic_lookup \
   -L "$MKS/Library/x86_64" -lkmod \
   -o "$KEXT/Contents/MacOS/$KEXT_NAME" "${OBJECTS[@]}"

# Exported symbols list: KC builder butuh SEMUA simbol yang dipanggil antar
# translation unit agar bisa di-bind. Tanpa ini, hot-swap gagal dengan
# "could not find a kext which exports this symbol".
# Exported symbols list.
# PENTING: daftar ini harus dibuat dari OBJECT FILES (bukan dari binary),
# karena setelah link pertama, `ld -kext` membuat simbol yang tidak
# diekspor menjadi LOKAL (t) sehingga tidak bisa di-bind KC builder.
# Sumber: nm -g <*.o> → kolom "T" = defined global text.
echo "[build] exported symbols"
nm -g "${OBJECTS[@]}" 2>/dev/null \
	| awk '{ if (NF == 3 && $2 == "T" && $3 ~ /^_/) print $3 }' \
	| sort -u > "$BUILD/$KEXT_NAME.exp"
echo "         $(wc -l < "$BUILD/$KEXT_NAME.exp") simbol diekspor"
ld -kext -arch x86_64 -undefined dynamic_lookup \
   -exported_symbols_list "$BUILD/$KEXT_NAME.exp" \
   -L "$MKS/Library/x86_64" -lkmod \
   -o "$KEXT/Contents/MacOS/$KEXT_NAME" "${OBJECTS[@]}"

echo "[build] validate"
plutil -lint "$KEXT/Contents/Info.plist" >/dev/null
if ! file "$KEXT/Contents/MacOS/$KEXT_NAME" | grep -q 'Mach-O 64-bit kext bundle x86_64'; then
	echo "[build] GAGAL: binary bukan kext bundle yang valid" >&2
	file "$KEXT/Contents/MacOS/$KEXT_NAME" >&2
	exit 1
fi

echo "[build] sign (ad-hoc)"
codesign -f -s - "$KEXT" >/dev/null 2>&1
codesign --verify --deep --strict "$KEXT"

echo "[build] chown root:wheel (syarat kmutil)"
chown -R root:wheel "$KEXT"

UNDEF="$(nm -u "$KEXT/Contents/MacOS/$KEXT_NAME" 2>/dev/null | wc -l | tr -d ' ')"
echo "[build] simbol undefined (dicepat di kernel): $UNDEF"
# --- build varian UJI (boleh traffic USB; hanya untuk hot-swap runtime) ---
# (bagian ini berada di bawah; default build = AMAN)
# Mode untuk varian UJI: readonly(0) / poweron(1) / full(2)
#
# PENTING: varian UJI hanya dibangun kalau MODE diisi eksplisit.
# Kalau tidak, build script ini (yang dipanggil run-tests.sh) akan
# menimpa varian UJI dengan mode default 'full' — lalu test yang
# dijalankan dengan mode 'poweron' diam-diam berubah. (22 Okt 2026)
MODE_NUM=2
BUILD_TEST=0
if [[ -n "${MODE:-}" ]]; then
	BUILD_TEST=1
	case "$MODE" in
		readonly) MODE_NUM=0 ;;
		poweron)  MODE_NUM=1 ;;
		full)     MODE_NUM=2 ;;
		*) echo "[build] MODE tidak dikenal: $MODE" >&2; exit 2 ;;
	esac
	echo "[build] varian UJI mode: $MODE (-DM1_TEST_MODE=$MODE_NUM)"
fi

if [[ $BUILD_TEST -eq 1 ]]; then
TEST_DIR="$SRC/build-test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR/$KEXT_NAME.kext/Contents/MacOS"
cp "$SRC/driver/Info.plist" "$TEST_DIR/$KEXT_NAME.kext/Contents/Info.plist"

TEST_OBJECTS=()
for src in "${SOURCES[@]}"; do
	obj="$TEST_DIR/$(basename "${src%.*}").o"
	case "$src" in
		*.c) "${CC:-clang}" "${CFLAGS[@]}" -DM1_ALLOW_USB_TRAFFIC=1 -DM1_TEST_MODE=$MODE_NUM -c "$src" -o "$obj" ;;
		*)   "${CXX:-clang++}" "${CXXFLAGS[@]}" -DM1_ALLOW_USB_TRAFFIC=1 -DM1_TEST_MODE=$MODE_NUM -c "$src" -o "$obj" ;;
	esac
	TEST_OBJECTS+=("$obj")
done
ld -kext -arch x86_64 -undefined dynamic_lookup \
   -L "$MKS/Library/x86_64" -lkmod \
   -o "$TEST_DIR/$KEXT_NAME.kext/Contents/MacOS/$KEXT_NAME" "${TEST_OBJECTS[@]}"
# exported symbols (KC builder butuh semua simbol lintas-TU)
nm -g "${TEST_OBJECTS[@]}" 2>/dev/null \
	| awk '{ if (NF == 3 && $2 == "T" && $3 ~ /^_/) print $3 }' \
	| sort -u > "$TEST_DIR/$KEXT_NAME.exp"
ld -kext -arch x86_64 -undefined dynamic_lookup \
   -exported_symbols_list "$TEST_DIR/$KEXT_NAME.exp" \
   -L "$MKS/Library/x86_64" -lkmod \
   -o "$TEST_DIR/$KEXT_NAME.kext/Contents/MacOS/$KEXT_NAME" "${TEST_OBJECTS[@]}"
codesign -f -s - "$TEST_DIR/$KEXT_NAME.kext" >/dev/null 2>&1
chown -R root:wheel "$TEST_DIR/$KEXT_NAME.kext" 2>/dev/null || true
echo "[build] varian UJI (USB traffic aktif) → $TEST_DIR/$KEXT_NAME.kext"
fi

echo "[build] OK  → $KEXT"
du -sh "$KEXT" | sed 's/^/[build] ukuran: /'
echo
echo "PERINGATAN: matikan RtWlanU sebelum load (driver ini menulis register chip)."
echo "  sudo mv /Library/Extensions/RtWlanU.kext /Library/Extensions/RtWlanU.kext.disabled"
