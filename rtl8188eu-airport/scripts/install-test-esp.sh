#!/bin/bash
# install-test-esp.sh — pasang kext UJI ke ESP untuk SATU siklus uji M1.
#
# Berbeda dari install-opencore.sh (yang memasang build AMAN/inert),
# skrip ini memasang build UJI (M1_ALLOW_USB_TRAFFIC=1) + boot-arg mode,
# supaya driver bisa benar-benar menjalankan init setelah di-replug.
#
# MODE yang didukung (boot-arg -rtl8188eum1_mode <mode>):
#   readonly  — hanya baca register (chip harus sudah hidup)
#   poweron   — chip-id + EFUSE + power-on flow vendor, lalu BERHENTI  ← default
#   full      — + LLT/DMA + upload firmware 8051
#
# Usage:
#   ALLOW_BOOT_INJECTION=1 MODE=poweron sudo ./scripts/install-test-esp.sh
#
# Pasangan: scripts/restore-test-esp.sh (mengembalikan segalanya & vendor).
set -euo pipefail

MODE="${MODE:-poweron}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UJI_KEXT="$ROOT/src/build-test/RTL8188EUM1.kext"
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
if [[ "${ALLOW_BOOT_INJECTION:-0}" != "1" ]]; then
	echo "[install-test] DITAHAN. Set ALLOW_BOOT_INJECTION=1 kalau benar-benar mau." >&2
	exit 3
fi
case "$MODE" in
	readonly|poweron|full) ;;
	*) echo "[install-test] MODE tidak dikenal: $MODE" >&2; exit 2 ;;
esac

ESP_MNT="$(find_esp)" || { echo "[install-test] ESP tidak ditemukan" >&2; exit 1; }
OC_DIR="$ESP_MNT/EFI/OC"

if [[ ! -d "$UJI_KEXT" ]]; then
	echo "[install-test] build varian UJI belum ada → build..."
	MODE="$MODE" "$ROOT/scripts/build-m1.sh" 2>&1 | tail -3
fi
[[ -d "$UJI_KEXT" ]] || { echo "[install-test] gagal build UJI" >&2; exit 1; }

# ── 1. backup ───────────────────────────────────────────────────────
TS=$(date +%Y%m%d-%H%M%S)
mkdir -p "$ROOT/backup"
cp "$OC_DIR/config.plist" "$ROOT/backup/config.plist.pre-test.$TS.bak"
tar -cf - -C "$ESP_MNT" EFI 2>/dev/null | gzip -1 > "$ROOT/backup/EFI-pre-test.$TS.tar.gz"
echo "[install-test] backup: backup/config.plist.pre-test.$TS.bak + EFI-pre-test.$TS.tar.gz"

# ── 2. salin kext UJI ───────────────────────────────────────────────
rm -rf "$OC_DIR/Kexts/$BUNDLE"
cp -R "$UJI_KEXT" "$OC_DIR/Kexts/$BUNDLE"
chown -R root:wheel "$OC_DIR/Kexts/$BUNDLE"
codesign -f -s - "$OC_DIR/Kexts/$BUNDLE" >/dev/null 2>&1 || true
echo "[install-test] kext UJI disalin → $OC_DIR/Kexts/$BUNDLE"

# ── 3. config: entri Kernel->Add + boot-arg ─────────────────────────
python3 - "$OC_DIR/config.plist" "$BUNDLE" "$BOOTARG" "$MODE" <<'PY'
import plistlib, sys

path, bundle, argname, mode = sys.argv[1:5]
with open(path, 'rb') as f:
    d = plistlib.load(f)

adds = d.setdefault('Kernel', {}).setdefault('Add', [])
adds[:] = [a for a in adds if a.get('BundlePath') != bundle]
adds.append({
    'Arch': 'Any',
    'BundlePath': bundle,
    'Comment': 'RTL8188EUS native Wi-Fi (uji M1: mode %s)' % mode,
    'Enabled': True,
    'ExecutablePath': 'Contents/MacOS/RTL8188EUM1',
    'MaxKernel': '24.99.99',
    'MinKernel': '24.0.0',
    'PlistPath': 'Contents/Info.plist',
})

# boot-arg: NVRAM -> boot-args
nvram = d.setdefault('NVRAM', {}).setdefault('Add', {})
guid = '7C436110-AB2A-4BBB-A880-FE41995C9F82'
ba = nvram.setdefault(guid, {}).get('boot-args', '')
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
parts.append('-%s=%s' % (argname, mode))   # WAJIB '=' : PE_parse_boot_argn
nvram[guid]['boot-args'] = ' '.join(parts)

with open(path, 'wb') as f:
    plistlib.dump(d, f)
print('[install-test] Kernel->Add: %d entri' % len(adds))
print('[install-test] boot-args: %s' % nvram[guid]['boot-args'])
PY

plutil -lint "$OC_DIR/config.plist" >/dev/null && echo "[install-test] plutil -lint: OK"

# ── 4. bersihkan staging AuxKC (hindari dobel load) ─────────────────
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
        shutil.copy(p, p + ".bak-test")
        with open(p, 'wb') as f:
            plistlib.dump(d, f)
        print('[install-test] AuxKC staging dibersihkan: %s' % name)
PY

# ── 5. matikan driver vendor (node USB harus bebas untuk driver kita) ─
mkdir -p "$DISABLED_DIR"
for k in RtWlanU RtWlanU1827; do
	src="/Library/Extensions/$k.kext"
	if [ -d "$src" ]; then
		mv "$src" "$DISABLED_DIR/$k.kext"
		echo "[install-test] $k.kext dimatikan (pindah ke $DISABLED_DIR)"
	fi
done

cat <<EOF

═══════════════════════════════════════════════════════════════════
 SIAP. Yang akan terjadi setelah reboot:

   1. OpenCore menyuntik $BUNDLE ke BootKC.
   2. Driver attach ke node USB Wi-Fi → state "started-inert"
      (uptime < 60 detik → NOL traffic USB. Aturan A3.)
   3. Tunggu > 60 detik, lalu CABUT-COLOK dongle Wi-Fi USB.
      → node USB baru → driver attach ulang → init berjalan
        dengan mode: $MODE
   4. Baca hasilnya:
        ioreg -r -c RTL8188EUM1 -w0 | grep M1
      atau pakai:  sudo ./scripts/collect-m1.sh

 CATATAN: Wi-Fi vendor MATI sampai kext ini dilepas
          (sudo ./scripts/restore-test-esp.sh lalu reboot).
          Jalur internet cadangan: USB tethering (HoRNDIS).
═══════════════════════════════════════════════════════════════════
EOF
