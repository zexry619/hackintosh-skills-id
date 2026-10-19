#!/bin/bash
# Ganti OpenCore di ESP dengan build lain dari versi yang sama (RELEASE <-> DEBUG)
#
# Cara pakai: oc-swap-build.sh <debug|release> [nomor versi] [--efi <direktori root EFI>] [--yes]
#   Jika nomor versi dilewati, disimpulkan dari NVRAM: DBG-108-2026-09-27 → 1.0.8 / 1.0.8-2026-09-27 → 1.0.8
#   Direktori root EFI bawaan = /Volumes/EFI/EFI
#
# Mengapa Drivers harus diganti bersamaan: pada versi yang sama, isi **semua** Drivers RELEASE dan DEBUG berbeda
#   (contoh 1.0.8: OpenRuntime.efi 24,576 → 36,864; OpenCanopy.efi 114,688 → 151,552)
#   Hanya mengganti OpenCore.efi akan menghasilkan boot loader "campuran build".
# Hanya ganti driver **resmi dengan nama yang sama**, driver pihak ketiga (seperti NullMothLogo.efi yang dipasang aplikasi driver) tetap dipertahankan.
set -euo pipefail

TARGET="${1:?cara pakai: oc-swap-build.sh <debug|release> [nomor versi] [--efi <direktori root EFI>] [--yes]}"
shift
VER=""; EFIROOT="/Volumes/EFI/EFI"; YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --efi) EFIROOT="${2:-}"; shift;;
    --yes) YES=1;;
    *) [ -z "$VER" ] && VER="$1";;
  esac
  shift
done
case "$TARGET" in debug|DEBUG) TARGET=debug; KIND=DEBUG;; release|RELEASE) TARGET=release; KIND=RELEASE;; *) echo "Target hanya boleh debug atau release"; exit 2;; esac

# ---------- 1) Versi dan build saat ini ----------
CUR=$(nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version 2>/dev/null | awk '{print $2}' || true)
echo "== 1) Kondisi saat ini =="
echo "   NVRAM opencore-version : ${CUR:-<tidak terbaca>}"
CURKIND="tidak diketahui"
case "$CUR" in DBG-*) CURKIND=DEBUG;; ""|-*) CURKIND=tidak diketahui;; *) CURKIND=RELEASE;; esac
if [ -z "$VER" ]; then
  # DBG-108-2026-09-27 → 108 → 1.0.8
  N=$(printf '%s' "$CUR" | sed -n 's/^DBG-\([0-9][0-9]*\)-.*/\1/p')
  [ -n "$N" ] || N=$(printf '%s' "$CUR" | sed -n 's/^\([0-9][0-9]*\)-.*/\1/p')
  if [ -n "$N" ] && [ ${#N} -ge 3 ]; then
    VER="$(printf '%s' "$N" | cut -c1).$(printf '%s' "$N" | cut -c2).$(printf '%s' "$N" | cut -c3-)"
  fi
fi
[ -n "$VER" ] || { echo "   ★ Nomor versi tidak dapat disimpulkan, mohon berikan secara eksplisit, misalnya: oc-swap-build.sh $TARGET 1.0.8"; exit 2; }
echo "   Versi : $VER      Build saat ini : $CURKIND      Build target : $KIND"
if [ "$CURKIND" = "$KIND" ]; then echo; echo "== Sudah ${KIND}, tidak perlu beralih.=="; exit 0; fi

# ---------- 2) Ambil paket resmi ----------
WORK="${PWD}/_oc-build-swap"; mkdir -p "$WORK"; cd "$WORK"
ZIP="OpenCore-$VER-$KIND.zip"
echo
echo "== 2) Ambil paket resmi ${KIND} (OpenCore-${VER}) =="
[ -f "$ZIP" ] || curl -sSL --max-time 300 \
  "https://github.com/acidanthera/OpenCorePkg/releases/download/$VER/$ZIP" -o "$ZIP"
ls -la "$ZIP"
rm -rf "src"; unzip -oq "$ZIP" -d src
SRC="src/X64/EFI"
[ -f "$SRC/OC/OpenCore.efi" ] || { echo "   ★ $SRC/OC/OpenCore.efi tidak ditemukan di dalam paket, apakah nomor versinya benar?"; exit 1; }

# ---------- 3) Verifikasi ESP ----------
OC="$EFIROOT/OC"; BOOT="$EFIROOT/BOOT"
[ -f "$OC/OpenCore.efi" ] || { echo "   ★ $OC/OpenCore.efi tidak ditemukan (ESP sudah ter-mount?)"; exit 1; }
ESP_DEV=""; MP=$(df -P "$OC/OpenCore.efi" | awk 'NR==2{print $NF}')
case "$MP" in
  /Volumes/*) INFO=$(diskutil info "$MP" 2>/dev/null || true)
              printf '%s\n' "$INFO" | grep -q 'Partition Type:.*EFI' \
                && ESP_DEV=$(printf '%s\n' "$INFO" | awk -F': *' '/Device Identifier/{print $2}') || true;;
esac

# ---------- 4) Cadangan ----------
TS=$(date +%Y%m%d-%H%M%S); BK="${PWD}/_oc-build-backup-$TS"
echo
echo "== 3) Cadangan ke $BK =="
mkdir -p "$BK/OC" "$BK/BOOT" "$BK/Drivers"
cp -p "$OC/OpenCore.efi" "$BK/OC/" 2>/dev/null && echo "   OpenCore.efi"
cp -p "$BOOT/bootx64.efi" "$BK/BOOT/" 2>/dev/null && echo "   BOOT/bootx64.efi" || echo "   (tidak ada bootx64.efi, dilewati)"
cp -pR "$OC/Drivers/." "$BK/Drivers/" 2>/dev/null && echo "   Drivers/ ($(ls "$OC/Drivers" | wc -l | tr -d ' ') berkas)"

# ---------- 5) Penggantian ----------
echo
echo "== 4) Penggantian =="
if [ "$YES" != 1 ]; then
  printf "   OpenCore.efi / BOOTx64.efi / Drivers resmi dengan nama sama di %s akan diganti dengan versi $KIND. Lanjutkan? [y/N] " "$EFIROOT"
  read -r a; case "$a" in y|Y) ;; *) echo "   Dibatalkan"; exit 0;; esac
fi
cp -p "$SRC/OC/OpenCore.efi" "$OC/OpenCore.efi" && echo "   OC/OpenCore.efi"
if [ -f "$SRC/BOOT/BOOTx64.efi" ]; then cp -p "$SRC/BOOT/BOOTx64.efi" "$BOOT/bootx64.efi" && echo "   BOOT/bootx64.efi"; fi
for f in "$SRC/OC/Drivers"/*; do
  n=$(basename "$f")
  [ -f "$OC/Drivers/$n" ] || continue          # hanya ganti yang sudah ada di ESP
  cp -p "$f" "$OC/Drivers/$n" && echo "   Drivers/$n"
done
echo "   (driver pihak ketiga dipertahankan: $(ls "$OC/Drivers" | while read -r n; do [ -f "$SRC/OC/Drivers/$n" ] || printf '%s ' "$n"; done))"

# ---------- 6) Verifikasi ----------
echo
echo "== 5) Verifikasi (sha harus sama dengan paket resmi) =="
rc=0
for rel in OC/OpenCore.efi BOOT/BOOTx64.efi; do
  a=$(shasum -a 256 "$EFIROOT/$rel" 2>/dev/null | awk '{print $1}')
  b=$(shasum -a 256 "$SRC/$rel" 2>/dev/null | awk '{print $1}')
  if [ "$a" = "$b" ]; then echo "   ✓ $rel  $a"; else echo "   ★ $rel tidak konsisten"; rc=1; fi
done
for f in "$SRC/OC/Drivers"/*; do
  n=$(basename "$f"); [ -f "$OC/Drivers/$n" ] || continue
  a=$(shasum -a 256 "$OC/Drivers/$n" | awk '{print $1}'); b=$(shasum -a 256 "$f" | awk '{print $1}')
  [ "$a" = "$b" ] || { echo "   ★ Drivers/$n tidak konsisten"; rc=1; }
done
if [ $rc -eq 0 ]; then echo "   Semua konsisten ✓"; else echo "   ★ Ada yang tidak konsisten, jangan restart dulu"; fi

# ---------- 7) Tulis ke disk + petunjuk restart ----------
echo
echo "== 6) Tulis ke disk (sync → unmount → mount ulang) =="
sync
if [ -n "$ESP_DEV" ]; then
  diskutil unmount "$ESP_DEV" >/dev/null 2>&1 || true
  diskutil mount   "$ESP_DEV" >/dev/null 2>&1 || \
    osascript -e "do shell script \"diskutil mount $ESP_DEV\" with administrator privileges" >/dev/null 2>&1 || true
  shasum -a 256 "$OC/OpenCore.efi" | sed 's/^/   OpenCore.efi setelah mount ulang: /'
fi

echo
echo "== Selesai. Berlaku setelah restart, verifikasi setelah restart: =="
echo "   nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version    # diharapkan $([ "$TARGET" = debug ] && echo "DBG-$VER-*" || echo "$VER-*")"
echo "   shasum -a 256 $OC/OpenCore.efi"
echo "   Rollback: cp -pR \"$BK/.\" \"$EFIROOT/\""
if [ "$TARGET" = release ]; then
  cat <<'TIP'

== Beralih ke RELEASE biasanya juga perlu "menonaktifkan log debug" (untuk pemakaian harian) ==
   (gunakan oc-edit-safe.sh begin dari skill ini lebih dulu, lalu jalankan perintah di bawah, terakhir finish)
   plutil -replace 'Misc.Debug.Target'        -integer 3          <config>   # hanya simpan log+konsol; tidak lagi menulis log ke ESP
   plutil -replace 'Misc.Debug.DisplayLevel'  -integer 2147483650 <config>   # 0x80000002 = ERROR+WARN
   plutil -replace 'Misc.Debug.AppleDebug'    -bool false         <config>
   plutil -replace 'Misc.Debug.ApplePanic'    -bool false         <config>   # set true jika ingin menyimpan panic ke disk
   plutil -replace 'Misc.Debug.DisableWatchDog' -bool false       <config>
   plutil -replace 'Misc.Debug.SysReport'     -bool false         <config>   # memang tidak berlaku di RELEASE
   Semua di atas adalah nilai bawaan Sample.plist resmi OpenCore.
   ★ Apakah -v pada boot-args perlu dipertahankan harus ditanyakan ke pengguna, jangan diputuskan sendiri (lihat lifecycle.md tahap⑥).
TIP
fi
