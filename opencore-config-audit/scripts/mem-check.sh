#!/bin/bash
# Validasi penempatan injeksi memori untuk model MacPro (PlatformInfo > Memory > Devices)
#
# Cara pakai: mem-check.sh [config.plist]        default /Volumes/EFI/EFI/OC/config.plist
#
# Aturan (terbukti pada mesin 10-13 ini, lulus uji nyata di v38):
#   Gambar "Tentang Mac Ini → Memori" menggambar entri ke-D dari Devices ke dalam posisi gambar ke-f(j) yang tetap,
#   f = [8,7,10,9,12,11,5,6,3,4,1,2] (= urutan tabel SMBIOS Type 17 pada mesin asli)
#   ⇒ nomor slot harus memakai penomoran mesin asli, dan array harus diurutkan menurut urutan f, agar "posisi gambar v = Slot v = baris ke-v dalam daftar"
set -u

CFG="${1:-/Volumes/EFI/EFI/OC/config.plist}"
PY="${PYTHON:-python3}"
[ -f "$CFG" ] || { echo "${CFG} tidak ditemukan (ESP sudah di-mount? ls -d /Volumes/EFI)"; exit 2; }

echo "== Target =="; echo "   $CFG"
echo

"$PY" - "$CFG" <<'PY'
import plistlib, re, sys

F = [8, 7, 10, 9, 12, 11, 5, 6, 3, 4, 1, 2]          # entri ke-j pada array → posisi gambar F[j-1]
SLOT2CH = {1:"F1",2:"F2",3:"E1",4:"E2",5:"D1",6:"D2",
           7:"A2",8:"A1",9:"B2",10:"B1",11:"C2",12:"C1"}

p = plistlib.load(open(sys.argv[1], "rb"))
mem = p.get("PlatformInfo", {}).get("Memory")
if not mem:
    print("★ Tidak ada bagian PlatformInfo > Memory —— memori dienumerasi sendiri oleh macOS (tanpa kustomisasi)")
    sys.exit(0)

devs = mem.get("Devices") or []
cap = mem.get("MaxCapacity")
print(f"== Tingkat atas ==")
print(f"   Jumlah entri Devices : {len(devs)}")
print(f"   MaxCapacity    : {cap} ({'≈ %.1f GB' % (cap/1024**3) if isinstance(cap, int) and cap else 'belum diatur'}; ★satuan bytes)")
print()

print("== Rincian: nomor array → posisi gambar yang diprediksi ==")
print("   No  | Pos Gambar | DeviceLocator                                    | Size(MB) | Putusan")
print("   -----+-----------+--------------------------------------------------+----------+------")
bad = 0
filled = []
for j, d in enumerate(devs, 1):
    loc = str(d.get("DeviceLocator", ""))
    size = d.get("Size", 0)
    m = re.search(r"Slot\s*(\d+)", loc)
    slot = int(m.group(1)) if m else None
    pred = F[j - 1] if j <= len(F) else None
    if slot is None:
        verdict = "★ Tidak ada 'Slot N' pada nama, tidak bisa diputuskan"
        bad += 1
    elif pred is None:
        verdict = f"★ Melebihi 12 slot (entri ke-{j} tidak akan digambar)"
        bad += 1
    elif slot == pred:
        verdict = "✓ Konsisten"
    else:
        verdict = f"★ Salah posisi: akan digambar pada posisi {pred} (di sana ditampilkan Slot {slot} milik entri ini)"
        bad += 1
    if isinstance(size, int) and size > 0:
        filled.append((slot, pred, size, loc))
    print(f"   {j:>4} | {str(pred):>8} | {loc[:48]:<48} | {str(size):>8} | {verdict}")

print()
print("== Kesimpulan ==")
if bad == 0 and devs:
    print("   ✓ Urutan array benar: posisi gambar v = Slot v = baris ke-v dalam daftar, selalu konsisten")
else:
    print(f"   ★ Ada {bad} yang tidak konsisten ⇒ grafik memori 'Tentang Mac Ini' akan bergeser dari daftar 'Informasi Sistem'")
    print("     Cara memperbaiki: ① nomor slot memakai penomoran mesin asli (1=F1 2=F2 3=E1 4=E2 5=D1 6=D2 7=A2 8=A1 9=B2 10=B1 11=C2 12=C1)")
    print("           ② array Devices diurutkan menurut urutan f: entri ke-1=Slot8, ke-2=Slot7, ke-3=Slot10 … ke-12=Slot2")
print()
if filled:
    print("== Terpasang (Size>0) ==")
    for slot, pred, size, loc in filled:
        ch = SLOT2CH.get(slot, "?")
        print(f"   Slot {slot:<2} ({ch:<2}) → posisi gambar {pred:<2} | {size} MB | {loc}")
    if len(filled) not in (4, 6, 8, 10, 12):
        print(f"   ⚠ Terpasang {len(filled)} entri: Apple resmi hanya mendukung 4/6/8/10/12 entri")
        print("     ⇒ macOS akan menampilkan popup 'disarankan berpasangan, minimal empat' + tanda seru Advisor —— sama seperti pada mesin asli, tidak bisa dihilangkan dengan memindahkan posisi")
else:
    print("== Terpasang: tidak ada (semua Size=0) ==")
PY
