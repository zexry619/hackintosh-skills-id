#!/bin/bash
# install-m4-esp.sh — pasang kext M4 (RTL8188EAirport) ke ESP, ganti M1.
#
# Yang dilakukan:
#   1. backup config.plist + seluruh EFI
#   2. buang RTL8188EUM1.kext (Kernel->Add + file) — supaya tidak berebut USB
#   3. salin RTL8188EAirport.kext + entri Kernel->Add
#   4. hapus boot-arg -rtl8188eum1_mode
#   5. bersihkan staging AuxKC lama
#   6. pastikan driver vendor tetap mati
#
# Usage:
#   ALLOW_BOOT_INJECTION=1 sudo ./scripts/install-m4-esp.sh ["/Volumes/ESP"]
#
# Pasangan: scripts/restore-test-esp.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEXT="$ROOT/src/driver/build-m4/RTL8188EAirport.kext"
BUNDLE="RTL8188EAirport.kext"
OLD_BUNDLE="RTL8188EUM1.kext"
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
	echo "[m4-install] Beberapa ESP ditemukan; pilih satu:" >&2
	for v in /Volumes/*; do
		if [ -f "$v/EFI/OC/OpenCore.efi" ]; then
			printf '  sudo %s "%s"\n' "$0" "$v" >&2
		fi
	done
	return 2
}

if [[ $EUID -ne 0 ]]; then echo "Jalankan dengan sudo" >&2; exit 1; fi
if [[ "${ALLOW_BOOT_INJECTION:-0}" != "1" ]]; then
	echo "[m4-install] DITAHAN. Set ALLOW_BOOT_INJECTION=1 kalau benar-benar mau." >&2
	exit 3
fi

ESP_MNT="$(find_esp)" || {
	echo "[m4-install] ESP tidak ditemukan / ambigu." >&2
	echo "[m4-install] Jalankan: sudo $0 \"/Volumes/NAMA_ESP\"" >&2
	exit 1
}
OC_DIR="$ESP_MNT/EFI/OC"
echo "[m4-install] ESP: $ESP_MNT"

if [[ ! -d "$KEXT" ]]; then
	echo "[m4-install] build M4 belum ada → build..."
	"$ROOT/scripts/build-m4.sh" 2>&1 | tail -3
fi
[[ -d "$KEXT" ]] || { echo "[m4-install] gagal build M4" >&2; exit 1; }

# ── 1. backup ───────────────────────────────────────────────────────
TS=$(date +%Y%m%d-%H%M%S)
mkdir -p "$ROOT/backup"
BACKUP_CFG="$ROOT/backup/config.plist.pre-m4.$TS.bak"
cp "$OC_DIR/config.plist" "$BACKUP_CFG"
tar -cf - -C "$ESP_MNT" EFI 2>/dev/null | gzip -1 > "$ROOT/backup/EFI-pre-m4.$TS.tar.gz"
echo "[m4-install] backup: backup/config.plist.pre-m4.$TS.bak + EFI-pre-m4.$TS.tar.gz"

# ── 2. salin M4 DULU, baru buang M1 (jangan tinggalkan ESP kosong) ──
rm -rf "$OC_DIR/Kexts/$BUNDLE"
cp -R "$KEXT" "$OC_DIR/Kexts/$BUNDLE"
chown -R root:wheel "$OC_DIR/Kexts/$BUNDLE"
codesign -f -s - "$OC_DIR/Kexts/$BUNDLE" >/dev/null 2>&1 || true
if [[ ! -f "$OC_DIR/Kexts/$BUNDLE/Contents/MacOS/RTL8188EAirport" ]]; then
	echo "[m4-install] executable M4 hilang setelah salin" >&2
	exit 1
fi
rm -rf "$OC_DIR/Kexts/$OLD_BUNDLE"
echo "[m4-install] $BUNDLE disalin; $OLD_BUNDLE dibuang dari ESP"

# ── 3. config: Kernel->Add + buang boot-arg M1 ──────────────────────
python3 - "$OC_DIR/config.plist" "$BUNDLE" "$OLD_BUNDLE" <<'PY'
import plistlib, sys

path, bundle, old_bundle = sys.argv[1:4]
with open(path, 'rb') as f:
    d = plistlib.load(f)

adds = d.setdefault('Kernel', {}).setdefault('Add', [])
adds[:] = [a for a in adds
           if a.get('BundlePath') not in (bundle, old_bundle)]
adds.append({
    'Arch': 'Any',
    'BundlePath': bundle,
    'Comment': 'RTL8188EUS native Wi-Fi (M4: IO80211/Skywalk)',
    'Enabled': True,
    'ExecutablePath': 'Contents/MacOS/RTL8188EAirport',
    'MaxKernel': '24.99.99',
    'MinKernel': '24.0.0',
    'PlistPath': 'Contents/Info.plist',
})

# hapus boot-arg mode M1 (hanya flag itu + nilainya)
nvram = d.setdefault('NVRAM', {}).setdefault('Add', {})
guid = '7C436110-AB2A-4BBB-A880-FE41995C9F82'
ba = nvram.setdefault(guid, {}).get('boot-args', '')
if isinstance(ba, bytes):
    ba = ba.decode('utf-8', 'replace')
parts = []
skip_next = False
for tok in ba.split():
    if skip_next:
        skip_next = False
        if tok in ('readonly', 'poweron', 'full'):
            continue
        parts.append(tok)
        continue
    if tok == '-rtl8188eum1_mode':
        skip_next = True
        continue
    if tok.startswith('-rtl8188eum1_mode='):
        continue
    parts.append(tok)
nvram[guid]['boot-args'] = ' '.join(parts)

with open(path, 'wb') as f:
    plistlib.dump(d, f)
print('[m4-install] Kernel->Add: %d entri' % len(adds))
print('[m4-install] boot-args: %s' % nvram[guid]['boot-args'])
PY

if ! plutil -lint "$OC_DIR/config.plist" >/dev/null; then
	echo "[m4-install] config.plist RUSAK — memulihkan backup" >&2
	cp "$BACKUP_CFG" "$OC_DIR/config.plist"
	exit 1
fi
echo "[m4-install] plutil -lint: OK"

# ── 4. bersihkan staging AuxKC ──────────────────────────────────────
kmutil clear-staging >/dev/null 2>&1 || true
python3 - <<'PY' || echo "[m4-install] peringatan: staging AuxKC dilewati"
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
        shutil.copy(p, p + ".bak-m4")
        with open(p, 'wb') as f:
            plistlib.dump(d, f)
        print('[m4-install] AuxKC staging dibersihkan: %s' % name)
PY

# ── 5. driver vendor tetap mati ─────────────────────────────────────
mkdir -p "$DISABLED_DIR"
for k in RtWlanU RtWlanU1827; do
	src="/Library/Extensions/$k.kext"
	if [ -d "$src" ]; then
		mv "$src" "$DISABLED_DIR/$k.kext"
		echo "[m4-install] $k.kext dimatikan"
	fi
done

cat <<'EOF'

═══════════════════════════════════════════════════════════════════
 SIAP REBOOT (M4). Setelah reboot:

   1. OpenCore menyuntik $BUNDLE ke BootKC
      (M1 tidak lagi disuntik).
   2. Driver mencoba: USB open → firmware → EFUSE → MAC/BB/RF
      → net80211 attach → SCAN.
   3. Cek cepat setelah login:
        ioreg -r -c ItlRtl8188E -w0 | head
        kextstat | grep RTL8188EAirport
        networksetup -listallhardwareports | grep -A2 Wi-Fi
   4. Kalau Wi-Fi muncul di menu: pilih jaringan → uji asosiasi.
   5. Kalau macet/panic: cabut dongle, boot dengan
      sudo ./scripts/restore-test-esp.sh   (dari sesi ini)
      atau lepas entri Kernel->Add lewat Recovery.

 CATATAN: log `log show` rusak di mesin ini; andalkan ioreg + probe.
═══════════════════════════════════════════════════════════════════
EOF
