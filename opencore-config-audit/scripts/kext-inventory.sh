#!/bin/sh
# kext-inventory.sh —— audit daftar kext (versi / metadata build / ukuran / sha256 / verifikasi referensi config)
#
# Kegunaan: simpan salinan "bukti sebelum perubahan" sebelum memperbarui kext atau OpenCore;
#       dan menjawab kolom-kolom yang dibutuhkan untuk "apakah kext ini produk resmi" (lihat references/kext-and-oc-update.md §1).
#
# Cara pakai:
#   ./kext-inventory.sh /Volumes/EFI                     # titik mount EFI (otomatis mencari EFI/OC/Kexts)
#   ./kext-inventory.sh /Volumes/EFI/EFI/OC/Kexts        # Berikan langsung direktori Kexts
#   ./kext-inventory.sh /Volumes/EFI --config /Volumes/EFI/EFI/OC/config.plist
#   ./kext-inventory.sh /Volumes/EFI --tsv               # dipisahkan tab (memudahkan diff / arsip)
#   ./kext-inventory.sh /Volumes/EFI --save VERSIONS-before.txt
#
# Kode keluar: 0 normal; 1 ada item mencurigakan (file hilang / referensi tidak lengkap).

set -u
# ★ Di sandbox PATH bisa rusak (stat/strings/grep akan command not found)
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

TSV=0; SAVE=""; CONFIG=""; TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tsv) TSV=1 ;;
    --config) shift; CONFIG="${1:-}" ;;
    --save)   shift; SAVE="${1:-}" ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "Parameter tidak dikenal: $1 (-h untuk cara pakai)" >&2; exit 2 ;;
    *) TARGET="$1" ;;
  esac
  shift
done
[ -n "$TARGET" ] || { echo "Cara pakai: $0 <titik mount EFI | direktori Kexts> [--config <config.plist>] [--tsv] [--save <file>]" >&2; exit 2; }

# Menemukan direktori Kexts
if [ -d "$TARGET/EFI/OC/Kexts" ]; then
  KEXTS="$TARGET/EFI/OC/Kexts"
  [ -z "$CONFIG" ] && [ -f "$TARGET/EFI/OC/config.plist" ] && CONFIG="$TARGET/EFI/OC/config.plist"
elif [ -d "$TARGET" ] && ls "$TARGET"/*.kext >/dev/null 2>&1; then
  # Perlakukan "direktori berisi banyak .kext" langsung sebagai Kexts (termasuk direktori backup di workspace)
  KEXTS="$TARGET"
else
  echo "Direktori Kexts tidak ditemukan (percobaan: $TARGET/EFI/OC/Kexts dan $TARGET itu sendiri)" >&2; exit 2
fi
[ -z "$CONFIG" ] && [ -f "$(dirname "$KEXTS")/config.plist" ] && CONFIG="$(dirname "$KEXTS")/config.plist"

pl() { plutil -extract "$2" raw -o - "$1" 2>/dev/null; }

emit() {
  if [ "$TSV" -eq 1 ]; then printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "${6:-}"
  else printf '  %-38s %-9s %-7s %-11s %-9s %s\n' "$1" "$2" "$3" "$4" "$5" "${6:-}"; fi
}

[ "$TSV" -eq 1 ] || {
  echo "══════════════════════════════════════════════════════════════"
  echo "  Daftar kext —— $KEXTS"
  echo "  (dibuat pada $(date '+%Y-%m-%d %H:%M:%S'))"
  echo "══════════════════════════════════════════════════════════════"
  printf '  %-38s %-9s %-7s %-11s %-9s %s\n' "kext (termasuk plugin di dalam paket)" "Versi" "DTXcode" "DTSDKName" "Ukuran" "sha256(12 awal)"
}

ROWS=""
n=0
# kext level atas + kext di dalam PlugIns paket
find "$KEXTS" -name '*.kext' -maxdepth 4 2>/dev/null | sort | while IFS= read -r k; do
  # Lewati file bayangan AppleDouble milik macOS (._Foo.kext), itu bukan kext asli
  case "$(basename "$k")" in ._*) continue ;; esac
  info="$k/Contents/Info.plist"
  if [ ! -f "$info" ]; then
    emit "$(basename "$k")" "?" "?" "?" "?" "Info.plist hilang" ""
    continue
  fi
  name=$(basename "$k")
  # Beri indentasi pada plugin di dalam paket
  case "$k" in "$KEXTS"/*/Contents/PlugIns/*) name="    └ $name" ;; esac
  ver=$(pl "$info" CFBundleVersion)
  xcode=$(pl "$info" DTXcode)
  sdk=$(pl "$info" DTSDKName)
  exe=$(pl "$info" CFBundleExecutable)
  bin="$k/Contents/MacOS/${exe:-}"
  if [ -n "${exe:-}" ] && [ -f "$bin" ]; then
    sz=$(stat -f %z "$bin" 2>/dev/null || echo 0)
    sha=$(shasum -a 256 "$bin" 2>/dev/null | cut -c1-12)
  else
    sz=$(du -sk "$k" 2>/dev/null | awk '{print $1*1024}')
    sha="(tanpa biner)"
  fi
  emit "$name" "${ver:-?}" "${xcode:-?}" "${sdk:-?}" "$sz" "$sha"
  n=$((n+1))
done

# --- verifikasi referensi config ---
rc=0
if [ -n "$CONFIG" ] && [ -f "$CONFIG" ]; then
  echo
  echo "── verifikasi referensi config ($CONFIG)──"
  python3 - "$CONFIG" "$KEXTS" <<'PY'
import sys, plistlib, os
cfg, kdir = sys.argv[1], sys.argv[2]
try:
    d = plistlib.load(open(cfg, "rb"))
except Exception as e:
    print(f"  Tidak bisa membaca config: {e}"); sys.exit(0)
adds = (d.get("Kernel", {}) or {}).get("Add", []) or []
missing, enabled = [], 0
for a in adds:
    bp = a.get("BundlePath", "")
    en = a.get("Enabled", False)
    if en: enabled += 1
    if not os.path.exists(os.path.join(kdir, bp)):
        missing.append((bp, en))
print(f"  Kernel>Add total {len(adds)} entri, {enabled} entri aktif")
if missing:
    print(f"  ❌ referensi hilang: {len(missing)} entri:")
    for bp, en in missing:
        print(f"     - {bp}{'' if en else '(nonaktif, dampak kecil)'}")
    sys.exit(1)
else:
    print("  ✅ Semua BundlePath ditemukan di Kexts/ (0 referensi hilang)")
PY
  [ $? -ne 0 ] && rc=1
else
  echo
  echo "  (config.plist tidak diberikan, verifikasi referensi dilewati; gunakan --config <path>)"
fi

# --- versi OpenCore ---
echo
echo "── Versi OpenCore (NVRAM)──"
ocv=$(nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version 2>/dev/null | sed 's/^.*opencore-version[[:space:]]*//')
if [ -n "$ocv" ]; then
  echo "  $ocv   (DBG- = build DEBUG / REL- = RELEASE)"
else
  echo "  (tidak terbaca; perlu hak admin atau OpenCore tidak berjalan)"
fi

echo
echo "── Pengingat (lihat references/kext-and-oc-update.md)──"
echo "  ★★ Sebelum menilai 'seharusnya diperbarui atau tidak', grep skrip instalasi/mirror.json milik vendor —— itulah definisi 'sumber resmi'"
echo "  ★  tag upstream tidak ditemukan ≠ asal tidak jelas (mungkin build-repo Dortania dibangun per commit, nomor patch +1)"
echo "  ★  Mengganti build OpenCore berarti mengganti Drivers resmi dengan nama yang sama"

[ "$rc" -eq 0 ] || exit 1
exit 0
