#!/bin/bash
# Periksa apakah pohon Resources OpenCanopy complies (ikon wajib / ukuran piksel asli / label / font / audio)
#
# Cara pakai: oc-theme-check.sh [direktori Resources]     bawaan /Volumes/EFI/EFI/OC/Resources
# Acuan: dokumen OpenCorePkg bagian OpenCanopy (daftar ikon dan ukuran) + Docs/Flavours.md
#
# Penjelasan: "tipe blok" pada .icns hanya membedakan 1x/2x (ic07 / ic13 …), **ukuran asli harus dilihat dari piksel PNG di dalam blok**,
#       jadi skrip ini mengurai ukuran PNG secara langsung, bukan menyimpulkannya dari tipe blok.
set -u

R="${1:-/Volumes/EFI/EFI/OC/Resources}"
PY="${PYTHON:-python3}"
[ -d "$R" ] || { echo "Tidak ditemukan ${R} (ESP sudah di-mount? ls -d /Volumes/EFI)"; exit 2; }

echo "== Pohon resources =="
find "$R" -maxdepth 3 -type d | sed "s|^$R|  .|" | sort
echo

echo "== Kumpulan ikon =="
if [ -d "$R/Image" ]; then
  find "$R/Image" -mindepth 2 -maxdepth 2 -type d | sort | while read -r s; do
    printf "  %-40s %s berkas .icns\n" "${s#$R/Image/}" "$(ls "$s"/*.icns 2>/dev/null | wc -l | tr -d ' ')"
  done
fi
echo

"$PY" - "$R" <<'PY'
import os, struct, sys

R = sys.argv[1]

# Ikon wajib (jika satu saja hilang, OpenCanopy tidak mau mulai); nilainya adalah ukuran yang ditentukan dokumen (lebar, tinggi), None = dimensi itu bebas/tidak ditentukan
MANDATORY = {
    "HardDrive": (128, 128), "ExtHardDrive": (128, 128),
    "Selected": (144, 144),
    "Selector": (None, 40), "SetDefault": (None, 40),   # maksimal 144x40, dan keduanya harus memiliki lebar yang sama
    "Left": (40, 40), "Right": (40, 40),
    "Cursor": (None, None),                              # maksimal 144x144
    "BtnFocus": (None, None), "Dot": (None, None), "Enter": (None, None), "Lock": (None, None),
    "Password": (None, None), "Restart": (None, None), "ShutDown": (None, None),
}
SHIPPED_OPTIONAL = ["AppleRecv", "AppleTM", "ExtAppleRecv", "ExtAppleTM", "Windows",
                    "OpticalDrive", "Other", "Shell", "Tool", "NetworkBoot", "FirmwareSettings"]
NOT_SHIPPED = ["Apple", "ExtApple", "ExtWindows", "ExtOpticalDrive", "ResetNVRAM", "Background"]
OPT_128 = {n: (128, 128) for n in SHIPPED_OPTIONAL + NOT_SHIPPED if n != "Background"}

CHUNK_1X = {"icp4","icp5","icp6","ic07","ic08","ic09","ic10","is32","il32","ih32","it32","ic04","ic05"}
CHUNK_2X = {"ic11","ic12","ic13","ic14"}

def png_size(b):
    if b[:8] == b"\x89PNG\r\n\x1a\n" and b[12:16] == b"IHDR":
        return struct.unpack(">II", b[16:24])
    return None

def scan(path):
    """→ (ukuran maks 1x, ukuran maks 2x); berkas tidak valid mengembalikan 'bad'"""
    try:
        d = open(path, "rb").read()
    except OSError:
        return None
    if len(d) < 8 or d[:4] != b"icns":
        return "bad"
    off, s1, s2 = 8, None, None
    while off + 8 <= len(d):
        t = d[off:off+4].decode("latin1"); n = struct.unpack(">I", d[off+4:off+8])[0]
        if n < 8 or off + n > len(d):
            break
        sz = png_size(d[off+8:off+n])
        if sz:
            if t in CHUNK_1X and (s1 is None or sz[0]*sz[1] > s1[0]*s1[1]): s1 = sz
            if t in CHUNK_2X and (s2 is None or sz[0]*sz[1] > s2[0]*s2[1]): s2 = sz
        off += n
    return (s1, s2)

def judge(name, got):
    exp = MANDATORY.get(name) or OPT_128.get(name)
    if not exp:
        return ""
    w, h = exp
    if not got:
        return f"  ★ Tidak ada ikon 1x yang bisa dibaca (dokumen meminta {w or '≤144'}x{h or '≤144'})"
    gw, gh = got
    if w and gw != w:
        return f"  ★ Lebar seharusnya {w}, tetapi sebenarnya {gw}"
    if h and gh != h:
        return f"  ★ Tinggi seharusnya {h}, tetapi sebenarnya {gh}"
    return ""

img = os.path.join(R, "Image")
sets = []
if os.path.isdir(img):
    for v in sorted(os.listdir(img)):
        vd = os.path.join(img, v)
        if not os.path.isdir(vd): continue
        for s in sorted(os.listdir(vd)):
            if os.path.isdir(os.path.join(vd, s)): sets.append((f"{v}\\{s}", os.path.join(vd, s)))
if not sets:
    print("★ Tidak ditemukan kumpulan ikon apa pun (seharusnya Resources/Image/<vendor>/<kumpulan ikon>/)"); sys.exit(1)

for name, d in sets:
    print(f"== Kumpulan ikon {name} ==")
    miss, bad, sizes = [], [], {}
    for icon in MANDATORY:
        p = os.path.join(d, icon + ".icns")
        if not os.path.exists(p): miss.append(icon); continue
        got = scan(p)
        if got in ("bad", None): bad.append(icon); continue
        s1, s2 = got
        sizes[icon] = s1
        t1 = f"{s1[0]}x{s1[1]}" if s1 else "—"
        t2 = f"{s2[0]}x{s2[1]}" if s2 else "—"
        note = judge(icon, s1)
        if s1 and s2 and s2[0] < s1[0]:   # beri peringatan hanya bila 2x lebih kecil dari 1x (normalnya ≥1x)
            note += f"  ★ 2x({t2}) bahkan lebih kecil dari 1x({t1})"
        print(f"  Wajib {icon+'.icns':22s} 1x={t1:>9}  2x={t2:>9}{note}")

    # Dokumen meminta: lebar SetDefault harus sama dengan Selector
    if sizes.get("Selector") and sizes.get("SetDefault"):
        if sizes["Selector"][0] != sizes["SetDefault"][0]:
            print(f"  ★ Lebar Selector {sizes['Selector'][0]} ≠ lebar SetDefault {sizes['SetDefault'][0]} (dokumen meminta lebar sama)")
        else:
            print(f"  ✓ Selector dan SetDefault memiliki lebar sama ({sizes['Selector'][0]})")

    have = {f[:-5] for f in os.listdir(d) if f.endswith(".icns")}
    print(f"  ⇒ Ikon wajib yang hilang: {miss or 'tidak ada ✓'}")
    if bad: print(f"  ⇒ Bukan .icns yang valid: {bad}")
    print(f"  Opsional (resmi disediakan) yang hilang: {sorted(set(SHIPPED_OPTIONAL)-have) or 'tidak ada'}")
    print(f"  Kumpulan resmi memang tidak menyediakannya (melaporkan Not Found adalah normal): {sorted(set(NOT_SHIPPED)-have)}")
    extra = sorted(have - set(MANDATORY) - set(SHIPPED_OPTIONAL) - set(NOT_SHIPPED))
    print(f"  Ikon tambahan (yang kamu tambahkan sendiri): {extra or 'tidak ada'}")
    print()

print("== Label Resources/Label (semua wajib; tinggi harus tepat 12 px) ==")
LABELS = ["EFIBoot","Apple","AppleRecv","AppleTM","Windows","Other","ResetNVRAM",
          "SIPDisabled","SIPEnabled","Shell","FirmwareSettings","Tool"]
ld = os.path.join(R, "Label")
if os.path.isdir(ld):
    for suf, tag in ((".lbl","1x"), (".l2x","2x")):
        miss = [x for x in LABELS if not os.path.exists(os.path.join(ld, x+suf))]
        print(f"  {tag}: hilang {miss if miss else 'tidak ada ✓'}   total {len([f for f in os.listdir(ld) if f.endswith(suf)])} berkas")
else:
    print("  ★ Tidak ada direktori Label")

print()
print("== Font Resources/Font ==")
fd = os.path.join(R, "Font")
if os.path.isdir(fd):
    print(f"  .bin: {[f for f in os.listdir(fd) if f.endswith('.bin')] or '★ tidak ada'} (seharusnya AngelCode binary BMF)")
else:
    print("  ★ Tidak ada direktori Font")

print()
print("== Audio Resources/Audio ==")
ad = os.path.join(R, "Audio")
if os.path.isdir(ad):
    mp3 = [f for f in os.listdir(ad) if f.lower().endswith(".mp3")]
    print(f"  total .mp3 {len(mp3)} berkas; contoh: {sorted(mp3)[:3]}")
else:
    print("  (Tidak ada direktori Audio —— hanya memengaruhi bunyi metronom/entri, tidak memengaruhi tampilan antarmuka)")
PY
