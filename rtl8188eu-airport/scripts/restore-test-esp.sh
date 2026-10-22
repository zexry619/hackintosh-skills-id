#!/bin/bash
# restore-test-esp.sh — kembalikan mesin ke kondisi SEBELUM uji M1/M4.
#
# Melakukan:
#   1. Hapus RTL8188EAirport.kext DAN RTL8188EUM1.kext dari ESP
#      beserta entri Kernel->Add
#   2. Hapus boot-arg -rtl8188eum1_mode dari config.plist
#   3. Bersihkan staging AuxKC
#   4. Kembalikan driver vendor Realtek ke /Library/Extensions
#   5. Validasi config.plist (kalau rusak, pulihkan backup pre-M4)
#
# Setelah script ini: REBOOT → Wi-Fi vendor kembali normal.
#
# Usage: sudo ./scripts/restore-test-esp.sh ["/Volumes/ESP"]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLES=("RTL8188EAirport.kext" "RTL8188EUM1.kext")
BOOTARG="rtl8188eum1_mode"
DISABLED_DIR="/Library/Extensions.disabled-m1"
ESP_OVERRIDE="${1:-}"

find_esp() {
	local v one="" count=0
	# Argumen pertama = path ESP eksplisit (mis. "/Volumes/MAC OS 2").
	if [ -n "$ESP_OVERRIDE" ]; then
		if [ -f "$ESP_OVERRIDE/EFI/OC/OpenCore.efi" ]; then
			echo "$ESP_OVERRIDE"
			return 0
		fi
		return 1
	fi
	for v in /Volumes/*; do
		if [ -f "$v/EFI/OC/OpenCore.efi" ]; then
			one="$v"
			count=$((count + 1))
		fi
	done
	if [ "$count" -eq 1 ]; then
		echo "$one"
		return 0
	fi
	if [ "$count" -eq 0 ]; then
		return 1
	fi
	echo "[restore] Beberapa ESP ditemukan; pilih satu:" >&2
	for v in /Volumes/*; do
		if [ -f "$v/EFI/OC/OpenCore.efi" ]; then
			printf '  sudo %s "%s"\n' "$0" "$v" >&2
		fi
	done
	return 2
}

if [[ $EUID -ne 0 ]]; then echo "Jalankan dengan sudo" >&2; exit 1; fi

# ── 1. hapus dari ESP + config ──────────────────────────────────────
if ESP_MNT="$(find_esp)"; then
	OC_DIR="$ESP_MNT/EFI/OC"
	for b in "${BUNDLES[@]}"; do
		rm -rf "$OC_DIR/Kexts/$b"
	done
	echo "[restore] kext M4/M1 dihapus dari ESP"

	python3 - "$OC_DIR/config.plist" "$BOOTARG" "${BUNDLES[@]}" <<'PY'
import plistlib, sys

path, argname = sys.argv[1:3]
bundles = sys.argv[3:]
with open(path, 'rb') as f:
    d = plistlib.load(f)

adds = d.setdefault('Kernel', {}).setdefault('Add', [])
n = len(adds)
adds[:] = [a for a in adds if a.get('BundlePath') not in bundles]
print('[restore] Kernel->Add: %d -> %d' % (n, len(adds)))

guid = '7C436110-AB2A-4BBB-A880-FE41995C9F82'
nvram = d.get('NVRAM', {}).get('Add', {})
ba = nvram.get(guid, {}).get('boot-args', '')
if isinstance(ba, bytes):
    ba = ba.decode('utf-8', 'replace')
parts = []
skip_next = False
for tok in ba.split():
    if skip_next:
        skip_next = False
        if tok in ('readonly', 'poweron', 'full'):
            continue
        parts.append(tok)       # token ini boot-arg asli, jangan dibuang
        continue
    if tok == '-%s' % argname:
        skip_next = True        # flag terpisah dari nilainya
        continue
    if tok.startswith('-%s=' % argname):
        continue                # flag + nilai dalam satu token
    parts.append(tok)
if parts:
    nvram[guid]['boot-args'] = ' '.join(parts)
    print('[restore] boot-args: %s' % nvram[guid]['boot-args'])
else:
    nvram.get(guid, {}).pop('boot-args', None)

with open(path, 'wb') as f:
    plistlib.dump(d, f)
PY

	if ! plutil -lint "$OC_DIR/config.plist" >/dev/null; then
		echo "[restore] ⚠️ config.plist RUSAK — memulihkan backup pre-M4 terbaru" >&2
		LATEST="$(ls -t "$ROOT"/backup/config.plist.pre-m4.*.bak 2>/dev/null | head -1 || true)"
		if [ -n "$LATEST" ]; then
			cp "$LATEST" "$OC_DIR/config.plist"
			plutil -lint "$OC_DIR/config.plist" >/dev/null \
				&& echo "[restore] dipulihkan dari $LATEST" \
				|| { echo "[restore] backup juga rusak — perbaiki manual" >&2; exit 1; }
		else
			echo "[restore] tidak ada backup; perbaiki manual" >&2
			exit 1
		fi
	else
		echo "[restore] plutil -lint: OK"
	fi
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
        shutil.copy(p, p + ".bak-restore")
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
