#!/bin/bash
# Validasi config.plist OpenCore sekali jalan (schema + kelengkapan referensi + sha)
#
# Cara pakai: oc-verify.sh <config.plist> [docs-dir]
#   docs-dir = direktori output fetch-opencore-docs.sh (berisi oc<versi>/Utilities/ocvalidate/ocvalidate)
#              jika tidak diisi, otomatis dicari di <config>/_oc-docs-audit dan ./_oc-docs-audit
set -u

CFG="${1:?Cara pakai: oc-verify.sh <config.plist> [docs-dir]}"
DOCS="${2:-}"
PY="${PYTHON:-python3}"
rc=0

[ -f "$CFG" ] || { echo "$CFG tidak ditemukan"; exit 2; }
OCDIR="$(cd "$(dirname "$CFG")" && pwd)"

# --- cari ocvalidate ---
OV=""
if [ -n "$DOCS" ]; then
  OV=$(ls -1 "$DOCS"/oc*/Utilities/ocvalidate/ocvalidate 2>/dev/null | head -1)
fi
[ -n "$OV" ] || OV=$(ls -1 "$OCDIR"/_oc-docs-audit/oc*/Utilities/ocvalidate/ocvalidate 2>/dev/null | head -1)
[ -n "$OV" ] || OV=$(ls -1 ./_oc-docs-audit/oc*/Utilities/ocvalidate/ocvalidate 2>/dev/null | head -1)

echo "== 1) sintaks plutil =="
plutil -lint "$CFG" || rc=1

echo
echo "== 2) ocvalidate resmi =="
if [ -n "$OV" ]; then
  echo "   Validator: $OV"
  "$OV" "$CFG" || rc=1
else
  echo "   ★ ocvalidate tidak ditemukan. Jalankan fetch-opencore-docs.sh <versi> dulu untuk mendapat validator resmi"
  echo "     (versi harus sama dengan OpenCore pada mesin ini, konfirmasi dengan nvram 4D1FDA02-…:opencore-version)"
  rc=1
fi

echo
echo "== 3) apakah file yang dirujuk ACPI / Kernel ada =="
"$PY" - "$CFG" "$OCDIR" <<'PY'
import os, plistlib, sys
cfg, ocdir = sys.argv[1], sys.argv[2]
d = plistlib.load(open(cfg, "rb"))
bad = 0
base = os.path.join(ocdir, "ACPI")
for e in d.get("ACPI", {}).get("Add", []):
    p = os.path.join(base, e.get("Path", ""))
    ok = os.path.exists(p)
    if e.get("Enabled") and not ok:
        bad += 1
    print(f"   [{'aktif' if e.get('Enabled') else 'nonaktif'}] ACPI/{e.get('Path'):34s} {'ada' if ok else '★hilang★'}")
kbase = os.path.join(ocdir, "Kexts")
for e in d.get("Kernel", {}).get("Add", []):
    p = os.path.join(kbase, e.get("BundlePath", ""))
    ok = os.path.exists(p)
    if e.get("Enabled") and not ok:
        bad += 1
    print(f"   [{'aktif' if e.get('Enabled') else 'nonaktif'}] Kexts/{e.get('BundlePath'):34s} {'ada' if ok else '★hilang★'}")
# file yatim (abaikan AppleDouble ._xxx yang dibuat macOS di FAT)
ref = {e.get("BundlePath", "") for e in d.get("Kernel", {}).get("Add", [])}
if os.path.isdir(kbase):
    for f in sorted(os.listdir(kbase)):
        if f.startswith("._") or f == ".DS_Store":
            continue
        if f not in ref:
            print(f"   Yatim(tidak dirujuk oleh Add): Kexts/{f}")
print(f"   ⇒ jumlah entri aktif yang hilang: {bad}")
sys.exit(1 if bad else 0)
PY
[ $? -eq 0 ] || rc=1

echo
echo "== 4) sha256 =="
shasum -a 256 "$CFG"

echo
if [ $rc -eq 0 ]; then echo "== Kesimpulan: validasi lulus =="; else echo "== Kesimpulan: ada masalah, lihat di atas =="; fi
exit $rc
