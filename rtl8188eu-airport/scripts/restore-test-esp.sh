#!/bin/bash
# restore-test-esp.sh — kembalikan mesin ke kondisi SEBELUM uji M1.
#
# Melakukan:
#   1. Hapus kext dari ESP (EFI/OC/Kexts) + entri Kernel->Add
#   2. Hapus boot-arg -rtl8188eum1_mode dari config.plist
#   3. Bersihkan staging AuxKC
#   4. Kembalikan driver vendor Realtek ke /Library/Extensions
#   5. Validasi config.plist
#
# Setelah script ini: REBOOT → Wi-Fi vendor kembali normal.
#
# Usage: sudo ./scripts/restore-test-esp.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE="RTL8188EUM1.kext"
BOOTARG="rtl8188eum1_mode"
DISABLED_DIR="/Library/Extensions.disabled-m1"

find_esp() {
	local v
	for v in /Volumes/*; do
		if [ -f "$v/EFI/OC/OpenCore.efi" ]; then echo "$v"; return 0; fi
	done
	return 1
}

if [[ $EUID -ne 0 ]]; then echo "Jalankan dengan sudo" >&2; exit 1; fi

# ── 1. hapus dari ESP + config ──────────────────────────────────────
if ESP_MNT="$(find_esp)"; then
	OC_DIR="$ESP_MNT/EFI/OC"
	rm -rf "$OC_DIR/Kexts/$BUNDLE"
	echo "[restore] kext dihapus dari ESP"

	python3 - "$OC_DIR/config.plist" "$BUNDLE" "$BOOTARG" <<'PY'
import plistlib, sys

path, bundle, argname = sys.argv[1:4]
with open(path, 'rb') as f:
    d = plistlib.load(f)

adds = d.setdefault('Kernel', {}).setdefault('Add', [])
n = len(adds)
adds[:] = [a for a in adds if a.get('BundlePath') != bundle]
print('[restore] Kernel->Add: %d -> %d' % (n, len(adds)))

guid = '7C436110-AB2A-4BBB-A880-FE41995C9F82'
nvram = d.get('NVRAM', {}).get('Add', {})
ba = nvram.get(guid, {}).get('boot-args', '')
if isinstance(ba, bytes):
    ba = ba.decode('utf-8', 'replace')
parts = []
skip = False
for tok in ba.split():
    if skip:
        skip = False
        continue
    if tok.startswith('-%s' % argname):
        skip = True          # buang flag (beserta '=' dan nilainya)
        continue
    # buang juga nilai mode yang nyasar dari install sebelumnya
    if tok in ('readonly', 'poweron', 'full'):
        continue
    parts.append(tok)
if parts:
    nvram[guid]['boot-args'] = ' '.join(parts)
    print('[restore] boot-args: %s' % nvram[guid]['boot-args'])
else:
    nvram.get(guid, {}).pop('boot-args', None)

with open(path, 'wb') as f:
    plistlib.dump(d, f)
PY

	plutil -lint "$OC_DIR/config.plist" >/dev/null \
		&& echo "[restore] plutil -lint: OK" \
		|| { echo "[restore] ⚠️ config.plist RUSAK — restore dari backup!" >&2; exit 1; }
else
	echo "[restore] ESP tidak ditemukan — lewati"
fi

# ── 2. bersihkan staging AuxKC ──────────────────────────────────────
kmutil clear-staging >/dev/null 2>&1 || true
python3 - <<'PY'
import plistlib, shutil, os
base = "/var/db/KernelExtensionManagement/AuxKC/CurrentAuxKC"
for name in ("com.apple.kcgen.instructions.plist", "com.apple.kcgen.uakl.plist"):
    p = os.path.join(base, name)
    if not os.path.exists(p):
        continue
    with open(p, 'rb') as f:
        d = plistlib.load(f)
    changed = False
    ktb = d.get("kextsToBuild", {})
    for k in list(ktb):
        if "zekri" in k.lower():
            del ktb[k]; changed = True
    ul = d.get("UnsignedKernelExtensions", [])
    n = len(ul)
    ul[:] = [x for x in ul if "zekri" not in str(x).lower()]
    if len(ul) != n:
        changed = True
    if changed:
        with open(p, 'wb') as f:
            plistlib.dump(d, f)
        print('[restore] AuxKC staging dibersihkan: %s' % name)
PY

# ── 3. kembalikan driver vendor ─────────────────────────────────────
if [ -d "$DISABLED_DIR" ]; then
	for k in RtWlanU RtWlanU1827; do
		if [ -d "$DISABLED_DIR/$k.kext" ]; then
			mv "$DISABLED_DIR/$k.kext" "/Library/Extensions/$k.kext"
			echo "[restore] $k.kext dikembalikan ke /Library/Extensions"
		fi
	done
	rmdir "$DISABLED_DIR" 2>/dev/null || true
fi

echo
echo "[restore] Driver vendor ADA lagi — reboot untuk memuatnya."
echo "[restore] Setelah reboot: ioreg -l | grep -i rtwlan  (harus ada)"
