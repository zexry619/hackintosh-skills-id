#!/bin/bash
# Siapkan uji M1:
#   1. nonaktifkan driver vendor Realtek (rename, bukan hapus — reversible)
#   2. stage kext M1 ke AuxKC (butuh reboot untuk dimuat)
#   3. cetak langkah berikutnya
#
# Usage: sudo ./scripts/prepare-m1-boot.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEXT="$ROOT/src/driver/build/RTL8188EUM1.kext"
DISABLED_DIR="/Library/Extensions.disabled-m1"

if [[ $EUID -ne 0 ]]; then
	echo "Jalankan dengan sudo" >&2
	exit 1
fi

if [[ ! -d "$KEXT" ]]; then
	echo "Kext belum dibangun: ./scripts/build-m1.sh" >&2
	exit 1
fi

echo "=== 1. nonaktifkan driver vendor Realtek ==="
mkdir -p "$DISABLED_DIR"
for k in RtWlanU RtWlanU1827; do
	src="/Library/Extensions/$k.kext"
	if [[ -d "$src" ]]; then
		mv "$src" "$DISABLED_DIR/$k.kext"
		echo "  $k.kext  ->  $DISABLED_DIR/$k.kext"
	else
		echo "  $k.kext: sudah tidak ada di /Library/Extensions"
	fi
done

echo
echo "=== 2. stage kext M1 ke AuxKC (dimuat saat reboot) ==="
kmutil load -z -p "$KEXT" 2>&1 | head -5 || true
sudo chown -R root:wheel "$KEXT" 2>/dev/null || true

echo
echo "=== 3. bersihkan jejak vendor dari AuxKC (supaya tidak ikut dimuat) ==="
python3 - <<'PYEOF'
import plistlib, shutil, os, glob

base = "/var/db/KernelExtensionManagement/AuxKC/CurrentAuxKC"
inst = os.path.join(base, "com.apple.kcgen.instructions.plist")
uakl = os.path.join(base, "com.apple.kcgen.uakl.plist")

def load(p):
    with open(p, 'rb') as f:
        return plistlib.load(f)

def save(p, d):
    shutil.copy(p, p + ".bak-m1")
    with open(p, 'wb') as f:
        plistlib.dump(d, f)

try:
    d = load(inst)
    ktb = d.get("kextsToBuild", {})
    for k in list(ktb):
        if "realtek" in k.lower():
            print("  instructions: hapus", k)
            del ktb[k]
    save(inst, d)
except Exception as e:
    print("  instructions: lewati (%s)" % e)

try:
    d = load(uakl)
    for team, entries in list(d.get("SignedKernelExtensions", {}).items()):
        kept = [e for e in entries if not any("realtek" in str(x).lower() for x in e)]
        if len(kept) != len(entries):
            print("  uakl: hapus entri realtek untuk team", team)
            if kept:
                d["SignedKernelExtensions"][team] = kept
            else:
                del d["SignedKernelExtensions"][team]
    save(uakl, d)
except Exception as e:
    print("  uakl: lewati (%s)" % e)

# Daftarkan kext unsigned (ad-hoc) ke daftar persetujuan.
try:
    d = load(uakl)
    lst = d.setdefault("UnsignedKernelExtensions", [])
    if "io.github.zekri.RTL8188EUM1" not in lst:
        lst.append("io.github.zekri.RTL8188EUM1")
        save(uakl, d)
        print("  uakl: daftarkan kext unsigned")
except Exception as e:
    print("  uakl: lewati (%s)" % e)

stashed = os.path.join(base, "StashedExtensions")
for p in glob.glob(os.path.join(stashed, "*", "RtWlanU*.kext")):
    print("  staged: hapus", p)
    shutil.rmtree(p, ignore_errors=True)
PYEOF

echo
echo "=== 4. status ==="
kextstat 2>/dev/null | grep -iE 'RtWlanU|RTL8188EUM1' | sed 's/^/  /' || echo "  (belum ada yang dimuat; akan aktif setelah reboot)"
sudo plutil -p /var/db/KernelExtensionManagement/AuxKC/CurrentAuxKC/com.apple.kcgen.instructions.plist 2>/dev/null \
	| grep -E 'io.github.zekri|com.realtek' | sed 's/^/  /' || true

echo
echo "=== 5. verifikasi isi AuxKC di disk ==="
kmutil inspect -p /Library/KernelCollections/AuxiliaryKernelExtensions.kc --show-extension-info 2>/dev/null \
	| grep -iE 'zekri|RtWlan' | sed 's/^/  /' || echo "  (belum ada entri Wi-Fi di AuxKC)"

cat <<'EOF'

============================================================
 LANGKAH BERIKUTNYA
============================================================
 1. REBOOT mesin (AuxKC di disk SUDAH berisi kext M1; kernel akan
    memuatnya di boot berikutnya):
        sudo shutdown -r now

 2. Setelah boot, buka Terminal dan jalankan:
        cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport
        ./scripts/collect-m1-log.sh

 3. Kalau mau mengembalikan Wi-Fi vendor:
        sudo ./scripts/restore-vendor-wifi.sh
        sudo shutdown -r now

 CATATAN:
  - Wi-Fi hardware AKAN MATI sampai kext vendor dikembalikan.
  - Pastikan tethering HP aktif selama reboot.
  - Kalau kernel panic saat boot: boot via USB rescue OpenCore,
    lalu jalankan restore-vendor-wifi.sh.
============================================================
EOF
