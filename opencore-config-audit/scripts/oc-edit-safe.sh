#!/bin/bash
# Pembungkus untuk mengubah config.plist di ESP secara aman: cadangan → (kamu yang mengedit) → validasi/arsip/verifikasi ulang setelah ditulis
#
# Cara pakai:
#   oc-edit-safe.sh begin  <esp_config> <workdir>            cadangan + catat baseline sha
#   ... ubah config dengan plutil ...
#   oc-edit-safe.sh finish <esp_config> <workdir> [label]     validasi + sinkronkan mirror + arsip versi + verifikasi ulang setelah unmount/remount
#
# Contoh:
#   S=/Volumes/EFI/EFI/OC/config.plist; W="$PWD"
#   oc-edit-safe.sh begin  "$S" "$W"
#   plutil -replace 'Misc.Debug.Target' -integer 69 "$S"
#   oc-edit-safe.sh finish "$S" "$W" docaudit-console-off
#
# Konvensi: di dalam workdir disimpan _oc-current.plist (mirror) dan <archive-dir>/config.plist.vNN-<keterangan> (arsip versi)
set -euo pipefail

MODE="${1:?Cara pakai: oc-edit-safe.sh begin|finish <esp_config> <workdir> [label]}"
CFG="${2:?esp_config wajib diisi}"
WORK="${3:?workdir wajib diisi}"
LABEL="${4:-edit}"
TS=$(date +%Y%m%d-%H%M%S)

[ -f "$CFG" ] || { echo "Tidak ditemukan ${CFG} (ESP sudah di-mount? ls -d /Volumes/EFI)"; exit 2; }
mkdir -p "$WORK"

# Identifier perangkat ESP (untuk verifikasi ulang setelah unmount/remount)
# ★ Pengaman: unmount/remount hanya dilakukan bila config memang berada di **partisi EFI**
#   di bawah /Volumes/. Kalau tidak (misalnya yang dimasukkan adalah salinan dari workdir),
#   df akan mengembalikan volume sistem seperti /System/Volumes/Data, dan unmount volume sistem itu berbahaya => lebih baik dilewati.
ESP_DEV=""
MP=$(df -P "$CFG" | awk 'NR==2{print $NF}' || true)
case "$MP" in
  /Volumes/*)
    INFO=$(diskutil info "$MP" 2>/dev/null || true)
    if printf '%s\n' "$INFO" | grep -q 'Partition Type:.*EFI'; then
      ESP_DEV=$(printf '%s\n' "$INFO" | awk -F': *' '/Device Identifier/{print $2}')
    fi
    ;;
esac

case "$MODE" in
begin)
  BASE=$(shasum -a 256 "$CFG" | awk '{print $1}')
  echo "== Baseline =="
  echo "   config : $CFG"
  echo "   sha256 : $BASE"
  echo "   titik mount : ${MP:-tidak diketahui}   perangkat: ${ESP_DEV:-tidak diketahui}"
  cp -p "$CFG" "$WORK/_oc-backup-before-$LABEL-$TS.plist"
  echo "   cadangan   : $WORK/_oc-backup-before-$LABEL-$TS.plist"
  printf '%s' "$BASE" > "$WORK/.oc-edit-baseline"
  echo
  echo "Sekarang kamu bisa mengubah config dengan plutil; setelah selesai jalankan:"
  echo "  oc-edit-safe.sh finish \"$CFG\" \"$WORK\" $LABEL"
  ;;

finish)
  echo "== 1) Sintaks dan validasi resmi =="
  plutil -lint "$CFG" || { echo "Validasi plutil gagal —— rollback ke cadangan disarankan"; exit 1; }

  OV=$(ls -1 "$WORK"/_oc-docs-audit/oc*/Utilities/ocvalidate/ocvalidate 2>/dev/null | head -1 || true)
  if [ -n "$OV" ]; then "$OV" "$CFG" || echo "   ★ ocvalidate melaporkan error, perbaiki dulu"; else echo "   (ocvalidate tidak ditemukan, dilewati)"; fi

  echo
  echo "== 2) Perbedaan semantik (relatif terhadap cadangan baseline) =="
  BASE_F=$(ls -t "$WORK"/_oc-backup-before-$LABEL-*.plist 2>/dev/null | head -1 || true)
  # Saat label tidak sama, kembali ke cadangan terakhir (LABEL pada begin/finish tidak harus identik)
  [ -n "$BASE_F" ] || BASE_F=$(ls -t "$WORK"/_oc-backup-before-*.plist 2>/dev/null | head -1 || true)
  if [ -n "$BASE_F" ]; then
    echo "   baseline: $BASE_F"
    "${PYTHON:-python3}" - "$BASE_F" "$CFG" <<'PY'
import plistlib, sys
a = plistlib.load(open(sys.argv[1], "rb")); b = plistlib.load(open(sys.argv[2], "rb"))
def walk(x, y, p=""):
    if isinstance(x, dict) and isinstance(y, dict):
        for k in sorted(set(x) | set(y)):
            if k not in x: yield ("+", f"{p}/{k}", repr(y[k])[:60]); continue
            if k not in y: yield ("-", f"{p}/{k}", repr(x[k])[:60]); continue
            yield from walk(x[k], y[k], f"{p}/{k}")
    elif isinstance(x, list) and isinstance(y, list):
        if x != y: yield ("~", p, f"list berubah: {len(x)} item → {len(y)} item")
    elif x != y:
        yield ("~", p, f"{x!r} -> {y!r}")
n = 0
for t, p, v in walk(a, b):
    n += 1; print(f"   {t} {p} | {v}")
print(f"   total {n} perbedaan")
PY
  fi

  echo
  echo "== 3) Sinkronkan mirror di workdir =="
  cp -p "$CFG" "$WORK/_oc-current.plist" && echo "   → $WORK/_oc-current.plist"

  echo
  echo "== 4) Arsip versi =="
  ARCH="$WORK/xh_adls3perbaikan-20261013"
  mkdir -p "$ARCH"
  N=$(ls -1 "$ARCH"/config.plist.v[0-9]* 2>/dev/null | sed -n 's/.*\.v\([0-9]\+\).*/\1/p' | sort -n | tail -1 || true)
  N=$(( ${N:-0} + 1 ))
  DST="$ARCH/config.plist.v$N-$LABEL"
  cp -p "$CFG" "$DST" && echo "   → $DST"

  echo
  echo "== 5) Verifikasi ulang setelah ditulis (sync → unmount → remount → verifikasi sha) =="
  NEW=$(shasum -a 256 "$CFG" | awk '{print $1}')
  sync
  if [ -n "$ESP_DEV" ]; then
    diskutil unmount "$ESP_DEV" >/dev/null 2>&1 || true
    diskutil mount   "$ESP_DEV" >/dev/null 2>&1 || \
      osascript -e "do shell script \"diskutil mount $ESP_DEV\" with administrator privileges" >/dev/null 2>&1 || true
    AFTER=$(shasum -a 256 "$CFG" 2>/dev/null | awk '{print $1}')
    if [ "$AFTER" = "$NEW" ]; then echo "   ✓ sha konsisten setelah remount: $NEW"
    else echo "   ★ sha tidak konsisten setelah remount (diharapkan ${NEW}, diperoleh ${AFTER:-tidak terbaca}) —— periksa apakah ESP sudah ter-mount"; fi
  else
    echo "   (perangkat ESP tidak dapat ditentukan, unmount/remount dilewati; sha = $NEW)"
  fi
  echo
  echo "== Kesimpulan =="
  echo "   sha256 : $NEW"
  echo "   arsip   : $DST"
  echo "   rollback   : cp -p \"$BASE_F\" \"$CFG\"  (lalu sync/unmount/remount)"
  ;;
*)
  echo "Mode tidak dikenal $MODE"; exit 2;;
esac
