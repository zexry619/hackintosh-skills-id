#!/bin/bash
# oc-nvram-bootentry.sh —— baca / tulis entri boot firmware dari macOS (Boot#### / BootOrder di bawah EFI_GLOBAL_VARIABLE_GUID)
#
# Cara pakai: periksa, cadangkan, rollback, tambah, hapus entri boot BIOS/UEFI di dalam macOS, tanpa perlu boot ulang ke BIOS atau memakai Windows.
#
# ★★ Baca baris ini dulu, kalau tidak kerja sia-sia ★★
#   Jika di config ada `UEFI>Quirks>RequestBootVarRouting=true` (dan OpenRuntime.efi dimuat),
#   OpenRuntime akan mengarahkan semua variabel yang diawali `Boot` di bawah EFI_GLOBAL_VARIABLE_GUID
#   **diarahkan** ke OC_VENDOR_VARIABLE_GUID (`Boot0001` → `OCBt0001`, `BootOrder` → `OCBtOrder`).
#   ⇒ Pada kondisi ini `add` / `del` tampak berhasil (baca-balik juga cocok), tetapi **kemungkinan besar hanya mendarat di namespace milik OpenCore itu sendiri**,
#     **tidak mendarat di firmware**. Harus boot ulang ke BIOS untuk memastikan.
#   ⇒ Agar `add` / `del` langsung berlaku: config pada boot tersebut gunakan `RequestBootVarRouting=false` (persyaratan resmi untuk Linux efibootmgr juga sama).
#   ★ Cara yang direkomendasikan resmi adalah **OpenShell `bcfg boot add`** (cuma lewat U disk, tanpa masuk ke OS mana pun);
#     Jika `bcfg` melaporkan "tidak bisa menulis", jalankan dulu `\EFI\OC\Tools\OpenControl.efi disable`, lalu coba lagi.
#   ★ `dump` / `backup` / `restore` tidak terpengaruh (baca dan tulis balik pada namespace yang sama, konsisten sendiri).
#
# Cara pakai:
#   oc-nvram-bootentry.sh dump [--scan 0x0000-0x001f]
#   oc-nvram-bootentry.sh backup [direktori]
#   oc-nvram-bootentry.sh restore <direktori>
#   oc-nvram-bootentry.sh del <N> [N...]
#   oc-nvram-bootentry.sh add --esp diskXs1 --name OpenCore \
#          [--file '\EFI\OC\OpenCore.efi'] [--index N] [--first] \
#          (--dp-prefix '<string UEFI>' | --dp-prefix-hex <hex> | --from-entry BootXXXX)
#
# Dependensi: /usr/sbin/nvram, /usr/bin/python3, diskutil (semuanya bawaan sistem)
# Implementasi: logika utama ada di Python yang tertanam di bawah (satu proses — fork `nvram` satu per satu sepuluh kali lebih lambat)

exec /usr/bin/python3 - "$0" "$@" <<'PYEOF'
import os, re, subprocess, sys, time

SCRIPT = sys.argv[1]

G       = "8BE4DF61-93CA-11D2-AA0D-00E098032B8C"   # EFI_GLOBAL_VARIABLE_GUID
NVRAM   = "/usr/sbin/nvram"
PROG    = "oc-nvram-bootentry.sh"

def die(msg): print("  ✗ %s" % msg, file=sys.stderr); sys.exit(1)
def info(msg): print("  %s" % msg)

# ── baca/tulis nvram (nvram macOS mengodekan byte yang tidak bisa dicetak sebagai %XX, '%' sendiri dienkode sebagai %25)──
def nv_get(name):
    r = subprocess.run([NVRAM, "%s:%s" % (G, name)], capture_output=True, text=True)
    if r.returncode != 0: return None
    line = r.stdout.rstrip("\n")
    return line.split("\t", 1)[1] if "\t" in line else line

def nv_set(name, val):
    return subprocess.run([NVRAM, "%s:%s=%s" % (G, name, val)], capture_output=True).returncode == 0

def nv_del(name):
    return subprocess.run([NVRAM, "-d", "%s:%s" % (G, name)], capture_output=True).returncode == 0

def decode(s):
    out = bytearray(); i = 0
    while i < len(s):
        if s[i] == "%" and i + 3 <= len(s):
            try: out.append(int(s[i+1:i+3], 16)); i += 3; continue
            except ValueError: pass
        out.append(ord(s[i]) & 0xFF); i += 1
    return bytes(out)

def encode(b):
    # ★ Setiap byte ditulis sebagai %XX, tanpa menyisakan karakter literal pun.
    #   Alasan: nvram macOS menganggap "spasi literal di dalam nilai" sebagai pemisah argumen (penulisan akan gagal),
    #   jadi "apa yang dibaca ditulis balik apa adanya" tidak andal — harus decode dulu lalu encode secara seragam.
    #   (output macOS sendiri adalah "ASCII yang bisa dicetak apa adanya + sisanya %XX", kita hanya memakai bentuk ekuivalen yang lain.)
    return "".join("%%%02x" % c for c in b)

def order_list():
    raw = nv_get("BootOrder")
    if not raw: return []
    b = decode(raw)
    return [int.from_bytes(b[j:j+2], "little") for j in range(0, len(b) - 1, 2)]

def order_enc(nums):
    b = bytearray()
    for n in nums: b += int(n).to_bytes(2, "little")
    return encode(bytes(b))

# ── device path ──
def node(t, st, body): return bytes([t, st]) + (4 + len(body)).to_bytes(2, "little") + body

def dp_parse(dp):
    out = []; k = 0
    while k + 4 <= len(dp):
        t, st = dp[k], dp[k+1]; ln = int.from_bytes(dp[k+2:k+4], "little")
        if ln < 4: break
        out.append((t, st, dp[k+4:k+ln])); k += ln
    return out

def guid_bytes(g):
    p = g.split("-")
    return (bytes.fromhex(p[0])[::-1] + bytes.fromhex(p[1])[::-1]
            + bytes.fromhex(p[2])[::-1] + bytes.fromhex(p[3]) + bytes.fromhex(p[4]))

def dp_show(dp):
    for t, st, body in dp_parse(dp):
        if (t, st) == (0x02, 0x01):
            print("     ACPI  PciRoot(0x%x)" % int.from_bytes(body[4:8], "little"))
        elif (t, st) == (0x01, 0x01):
            # UEFI: pada node PCI, Function di depan dan Device di belakang; bentuk teksnya Pci(Device,Function)
            print("     Pci   (0x%x,0x%x)" % (body[1], body[0]))
        elif (t, st) == (0x03, 0x17):
            print("     NVMe  (0x%x,%s)" % (int.from_bytes(body[0:4], "little"),
                  "-".join("%02X" % c for c in body[4:12])))
        elif (t, st) == (0x04, 0x01):
            pn = int.from_bytes(body[0:4], "little")
            lba = int.from_bytes(body[4:12], "little"); sz = int.from_bytes(body[12:20], "little")
            sig = body[20:36]; styp = body[37] if len(body) > 37 else 0
            if styp == 2:
                a, c, d, e = (sig[0:4][::-1].hex(), sig[4:6][::-1].hex(),
                              sig[6:8][::-1].hex(), sig[8:16].hex())
                sigs = "%s-%s-%s-%s-%s" % (a, c, d, e[:4], e[4:])
            else:
                sigs = sig.hex()
            print("     HD    (%d, %s, %s, 0x%x, 0x%x)" % (
                  pn, "GPT" if styp == 2 else "type%d" % styp, sigs, lba, sz))
        elif (t, st) == (0x04, 0x04):
            print("     File  %s" % body.decode("utf-16-le", "replace"))
        elif (t, st) == (0x7f, 0xff):
            pass
        else:
            print("     node  type=0x%02x sub=0x%02x len=%d" % (t, st, len(body) + 4))

def dp_text(dp):
    """Dikembalikan ke bentuk teks UEFI (node yang dikenali), sisanya pakai hex sebagai cadangan."""
    out = []
    for t, st, body in dp_parse(dp):
        if (t, st) == (0x02, 0x01): out.append("PciRoot(0x%x)" % int.from_bytes(body[4:8], "little"))
        elif (t, st) == (0x01, 0x01): out.append("Pci(0x%x,0x%x)" % (body[1], body[0]))
        elif (t, st) == (0x03, 0x17):
            out.append("NVMe(0x%x,%s)" % (int.from_bytes(body[0:4], "little"),
                       "-".join("%02X" % c for c in body[4:12])))
        elif (t, st) == (0x04, 0x01):
            out.append("HD(%d,GPT,%s,0x%x,0x%x)" % (
                int.from_bytes(body[0:4], "little"),
                "%s-%s-%s-%s-%s" % (body[20:24][::-1].hex(), body[24:26][::-1].hex(),
                                    body[26:28][::-1].hex(), body[28:30].hex(), body[30:36].hex()),
                int.from_bytes(body[4:12], "little"), int.from_bytes(body[12:20], "little")))
        elif (t, st) == (0x04, 0x04): out.append(body.decode("utf-16-le", "replace"))
        elif (t, st) == (0x7f, 0xff): pass
        else: out.append("<type=0x%02x,sub=0x%02x>" % (t, st))
    return "/".join(out)

def dp_from_text(s):
    out = bytearray()
    for part in [x for x in s.split("/") if x.strip()]:
        m = re.fullmatch(r"PciRoot\((0x[0-9a-fA-F]+)\)", part)
        if m:
            # Node ACPI = HID(UINT32) + UID(UINT32); HID PciRoot selalu = EISA_PNP_ID(0x0A03) = 0x0A0341D0
            out += node(0x02, 0x01, (0x0A0341D0).to_bytes(4, "little")
                        + int(m.group(1), 16).to_bytes(4, "little")); continue
        m = re.fullmatch(r"Pci\((0x[0-9a-fA-F]+),(0x[0-9a-fA-F]+)\)", part)
        if m: out += node(0x01, 0x01, bytes([int(m.group(2), 16), int(m.group(1), 16)])); continue
        m = re.fullmatch(r"NVMe\((0x[0-9a-fA-F]+),([0-9A-Fa-f-]+)\)", part)
        if m:
            out += node(0x03, 0x17, int(m.group(1), 16).to_bytes(4, "little")
                        + bytes(int(x, 16) for x in m.group(2).split("-"))); continue
        die("node tidak dikenali: %s\n(selain PciRoot/Pci/NVMe, mohon pakai --dp-prefix-hex)" % part)
    return bytes(out)

def parse_entry(b):
    """EFI_LOAD_OPTION → (attrs, desc, device_path)"""
    if len(b) < 6: return None
    attrs = int.from_bytes(b[0:4], "little"); fpll = int.from_bytes(b[4:6], "little")
    j = 6
    while j + 1 < len(b) and b[j:j+2] != b"\x00\x00": j += 2
    desc = b[6:j].decode("utf-16-le", "replace")
    return attrs, desc, (b[j+2:j+2+fpll] if fpll else b[j+2:])

def build_entry(name, fpath, guid, off, size, prefix):
    dp  = prefix
    hd  = (1).to_bytes(4, "little") + int(off).to_bytes(8, "little") + int(size).to_bytes(8, "little")
    hd += guid_bytes(guid) + bytes([2, 2])
    dp += node(0x04, 0x01, hd)
    dp += node(0x04, 0x04, fpath.encode("utf-16-le"))     # tanpa NUL di akhir, konsisten dengan gaya OpenCore sendiri
    dp += bytes.fromhex("7fff0400")
    blob = (1).to_bytes(4, "little") + len(dp).to_bytes(2, "little") + name.encode("utf-16-le") + b"\x00\x00" + dp
    return encode(blob)

def diskutil_info(esp):
    r = subprocess.run(["diskutil", "info", esp], capture_output=True, text=True)
    if r.returncode != 0: die("diskutil tidak dapat membaca %s" % esp)
    t = r.stdout
    g = re.search(r"Partition UUID:\s*([0-9A-Fa-f-]{36})", t)
    o = re.search(r"Partition Offset:\s*(\d+)\s*Bytes\s*\((\d+)\s+512-Byte-Device-Blocks\)", t)
    s = re.search(r"exactly\s+(\d+)\s+512-Byte-Units", t)
    if not g: die("%s tidak punya Partition UUID (bukan partisi GPT?)" % esp)
    if not (o and s): die("tidak dapat mengambil Partition Offset / Disk Size dari %s" % esp)
    # ★ satuan LBA awal pada node HD adalah "blok 512 byte" (ketentuan UEFI), bukan jumlah byte
    return g.group(1), int(o.group(2)), int(s.group(1))

def scan_range(spec):
    a, b = spec.split("-"); return list(range(int(a, 16), int(b, 16) + 1))

# ── subperintah ──
def cmd_dump(argv):
    spec = "0x0000-0x001f"
    if argv and argv[0] == "--scan": spec = argv[1]
    order = order_list()
    print("BootOrder = %s" % (nv_get("BootOrder") or "(kosong)"))
    if order: print("  urutan → %s" % " ".join("Boot%04X" % n for n in order))
    print("\n── Masing-masing entri boot ─────────────────────────────────────────────")
    idx = sorted(set(scan_range(spec)) | set(order) | {128, 129})
    found = 0
    for i in idx:
        nm = "Boot%04X" % i
        raw = nv_get(nm)
        if not raw: continue
        found += 1
        pe = parse_entry(decode(raw))
        print("\n%s" % nm)
        if not pe: print("   (terlalu pendek, tidak bisa diurai)"); continue
        attrs, desc, dp = pe
        print("   Nama      : %s" % desc)
        print("   Attributes: 0x%08x%s" % (attrs, "  (ACTIVE)" if attrs & 1 else "  (tidak aktif)"))
        print("   Path dev  : %d byte" % len(dp))
        dp_show(dp)
    if not found: info("(tidak ada entri boot dalam rentang pindaian)")
    print()
    info("Rentang pindaian: %s + nomor yang ada di BootOrder (ubah rentang dengan --scan A-B)" % spec)

def cmd_backup(argv):
    d = argv[0] if argv else "nvram-bootentry-cadangan-%s" % time.strftime("%Y%m%d-%H%M%S")
    os.makedirs(d, exist_ok=True)
    n = 0
    for i in sorted(set(scan_range("0x0000-0x001f")) | set(order_list()) | {128, 129}):
        nm = "Boot%04X" % i; v = nv_get(nm)
        if not v: continue
        open(os.path.join(d, nm + ".txt"), "w").write(v + "\n"); n += 1
        info("Cadangan %s (%d byte)" % (nm, len(v)))
    bo = nv_get("BootOrder")
    if bo: open(os.path.join(d, "BootOrder.txt"), "w").write(bo + "\n"); info("Cadangan BootOrder")
    info("→ %s (%d variabel)" % (d, n))

def cmd_restore(argv):
    if not argv: die("Cara pakai: %s restore <direktori cadangan>" % PROG)
    d = argv[0]
    if not os.path.isdir(d): die("direktori tidak ditemukan: %s" % d)
    n = 0
    for f in sorted(os.listdir(d)):
        if not f.endswith(".txt"): continue
        nm = f[:-4]; v = open(os.path.join(d, f)).read().rstrip("\n")
        # ★ Wajib encode ulang: di dalam cadangan tersimpan bentuk campuran macOS (mengandung spasi literal), penulisan langsung akan gagal
        if nv_set(nm, encode(decode(v))): info("sudah ditulis balik %s" % nm); n += 1
        else: info("gagal menulis balik %s" % nm)
    if not n: die("tidak ada variabel yang ditulis balik")

def cmd_del(argv):
    if not argv: die("Cara pakai: %s del <N> [N...]" % PROG)
    tgt = [int(x, 0) for x in argv]
    for i in tgt:
        nm = "Boot%04X" % i
        if nv_del(nm): info("sudah dihapus %s" % nm)
        else: info("%s tidak ditemukan atau gagal dihapus" % nm)
    keep = [n for n in order_list() if n not in tgt]
    if keep:
        v = order_enc(keep); nv_set("BootOrder", v); info("BootOrder ditulis ulang menjadi %s" % v)
    else:
        nv_del("BootOrder"); info("BootOrder sudah dikosongkan")

def cmd_add(argv):
    a = {"esp": None, "name": None, "file": "\\EFI\\OC\\OpenCore.efi",
         "index": None, "first": False, "dpp": None, "dphx": None, "from": None, "dry": False}
    while argv:
        k = argv.pop(0)
        if k == "--first": a["first"] = True; continue
        if k == "--dry-run": a["dry"] = True; continue
        if k not in ("--esp", "--name", "--file", "--index", "--dp-prefix", "--dp-prefix-hex", "--from-entry"):
            die("parameter tidak dikenal: %s" % k)
        if not argv: die("%s kurang nilai" % k)
        a[{"--esp": "esp", "--name": "name", "--file": "file", "--index": "index",
           "--dp-prefix": "dpp", "--dp-prefix-hex": "dphx", "--from-entry": "from"}[k]] = argv.pop(0)
    if not a["esp"]: die("wajib berikan --esp (misalnya disk2s1)")
    if not a["name"]: die("wajib berikan --name (nama yang ditampilkan di BIOS)")

    guid, off, size = diskutil_info(a["esp"])

    if a["dphx"]:
        prefix = bytes.fromhex(a["dphx"])
    elif a["dpp"]:
        prefix = dp_from_text(a["dpp"])
    elif a["from"]:
        raw = nv_get(a["from"]) or die("%s tidak ditemukan" % a["from"])
        _, _, dp = parse_entry(decode(raw))
        pre = bytearray()
        for t, st, body in dp_parse(dp):
            if (t, st) in ((0x04, 0x01), (0x7f, 0xff)): break
            pre += node(t, st, body)
        prefix = bytes(pre)
    else:
        die("wajib berikan salah satu dari --dp-prefix '<string UEFI>' / --dp-prefix-hex <hex> / --from-entry BootXXXX")
    if not prefix: die("awalan device path kosong")

    payload = build_entry(a["name"], a["file"], guid, off, size, prefix)
    idx = int(a["index"], 0) if a["index"] else None
    if idx is None:
        used = set(order_list())
        idx = next(i for i in range(1, 0xFFFF) if i not in used)
    nm = "Boot%04X" % idx

    info("Menulis %s  →  %s" % (nm, a["name"]))
    info("  ESP   : %s   GUID %s   LBA 0x%x   0x%x sektor" % (a["esp"], guid, off, size))
    info("  File  : %s" % a["file"])
    info("  Awalan device path: %s" % dp_text(prefix))
    info("  Payload: %d byte (%d karakter setelah di-encode)" % (len(decode(payload)), len(payload)))
    if a["dry"]:
        print(); info("--dry-run: tidak ada variabel yang ditulis. Payload-nya:")
        print(payload)
        print(); info("Perbandingan: %s dump untuk melihat entri yang ada; atau %s add ... --index N untuk menulis sungguhan" % (PROG, PROG))
        return
    if not nv_set(nm, payload): die("gagal menulis %s" % nm)
    if nv_get(nm) != payload: die("❌ baca balik tidak cocok")
    info("✅ baca balik identik byte per byte (★ ini belum tentu mendarat di firmware, lihat peringatan di kepala file)")

    rest = [n for n in order_list() if n != idx]
    new_order = ([idx] + rest) if a["first"] else (rest + [idx])
    v = order_enc(new_order); nv_set("BootOrder", v)
    info("BootOrder = %s%s" % (v, "(sudah jadi yang pertama)" if a["first"] else "(sudah ditambahkan)"))
    print(); info("Rollback: %s del %d" % (PROG, idx))

def usage():
    for ln in open(SCRIPT, encoding="utf-8").read().splitlines()[1:34]:
        print(re.sub(r"^# ?", "", ln))

CMDS = {"dump": cmd_dump, "backup": cmd_backup, "restore": cmd_restore,
        "del": cmd_del, "rm": cmd_del, "add": cmd_add}
argv = sys.argv[2:]
if not argv or argv[0] in ("-h", "--help", "help"):
    usage(); sys.exit(0)
cmd = CMDS.get(argv[0])
if not cmd: die("subperintah tidak dikenal: %s (coba --help)" % argv[0])
cmd(argv[1:])
PYEOF
