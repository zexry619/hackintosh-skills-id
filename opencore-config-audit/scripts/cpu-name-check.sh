#!/bin/sh
# cpu-name-check.sh —— pemeriksaan nama tampilan CPU (nama processor di "Tentang Mac Ini")
#
# Cara pakai: menilai "apakah nama CPU yang ditampilkan sudah benar" dan "apakah tiga kunci untuk mengganti nama sudah lengkap", lalu memberi interpretasi.
#       Gunakan bersama references/cpu-name.md.
#
# Cara pakai:
#   ./cpu-name-check.sh                     # pemeriksaan lengkap
#   ./cpu-name-check.sh --name              # hanya perbandingan nama
#   ./cpu-name-check.sh --args              # hanya parameter rev*
#   ./cpu-name-check.sh /path/to/config.plist   # verifikasi tambahan config (ProcessorType dll)
#
# Dependensi: sysctl / system_profiler / nvram (bawaan macOS). Pemeriksaan config butuh python3.
# Kode keluar: 0 normal; 1 ada item mencurigakan (hanya pemberitahuan).

set -u

ONLY=""
CONFIG=""
for a in "$@"; do
  case "$a" in
    --name) ONLY=name ;;
    --args) ONLY=args ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "parameter tidak dikenal: $a (-h untuk melihat cara pakai)" >&2; exit 2 ;;
    *) CONFIG="$a" ;;
  esac
done

REV_GUID="4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102"
WARN=0

names() {
  echo "=========== 1) Perbandingan nama ==========="
  pn=$(system_profiler SPHardwareDataType 2>/dev/null | sed -n 's/^ *Processor Name: *//p' | head -1)
  bs=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
  printf '  %-26s = %s\n' "Processor Name yang ditampilkan" "${pn:-<kosong>}"
  printf '  %-26s = %s\n' "brand_string yang dilaporkan CPU" "${bs:-<kosong>}"
  printf '  %-26s = %s\n' "model hw.model" "$(sysctl -n hw.model 2>/dev/null)"
  echo
  if [ -n "$pn" ] && [ -n "$bs" ]; then
    if [ "$pn" = "$bs" ]; then
      echo "  ✅ Keduanya sama ⇒ nama tampilan adalah nilai yang dilaporkan CPU (tidak diubah oleh pemetaan model)"
    else
      echo "  ⚠ Keduanya berbeda ⇒ nama tampilan dihasilkan dari pemetaan model (cpu-name.md §0)"
      echo "     Ingin mengubah ke brand_string atau nama kustom ⇒ gunakan revpatch=cpuname + revcpu=1 + revcpuname"
      WARN=1
    fi
  fi
  # Ciri khas nama salah akibat "pemetaan model"
  case "$pn" in
    *Xeon*W*) echo "  ★ Gejala khas: Xeon W adalah nama hasil pemetaan untuk MacPro7,1 (jika CPU sebenarnya i7/i9, jelas tidak cocok)" ;;
  esac
}

args() {
  echo "=========== 2) Parameter rev* (RestrictEvents) ==========="
  ba=$(sysctl -n kern.bootargs 2>/dev/null)
  echo "  -- rev* di dalam boot-args --"
  echo "$ba" | tr ' ' '\n' | grep -E '^-?rev|^revpatch=|^revcpu=|^revcpuname=|^revblock=' | sed 's/^/     /'
  [ -n "$(echo "$ba" | tr ' ' '\n' | grep -E '^rev')" ] || echo "     (tidak ada)"

  echo "  -- NVRAM ($REV_GUID) --"
  got=0
  for k in revpatch revcpu revcpuname revblock; do
    # nvram mencetak byte yang tidak bisa dicetak sebagai %XX; %00 di akhir adalah terminator string C, menghapusnya membuat lebih mudah dibaca
    v=$(nvram "$REV_GUID:$k" 2>/dev/null | sed "s/^$REV_GUID:$k[[:space:]]*//" | sed 's/%00$//')
    if [ -n "$v" ]; then printf '     %-12s = %s\n' "$k" "$v"; got=1; fi
  done
  [ "$got" -eq 1 ] || echo "     (tidak ada)"

  echo "  -- Apakah RestrictEvents dimuat --"
  if command -v kmutil >/dev/null 2>&1; then
    if kmutil showloaded --list-only 2>/dev/null | grep -qi RestrictEvents; then
      echo "     ✅ sudah dimuat"
    else
      echo "     ❌ belum dimuat (atau butuh hak akses yang lebih tinggi) ⇒ ketiga kunci tidak akan berlaku"
      WARN=1
    fi
  else
    echo "     kmutil tidak tersedia, dilewati"
  fi
  echo
  echo "  ★★ Jebakan prioritas: rev* di NVRAM sama efektifnya dengan boot-arg, tapi **prioritasnya lebih rendah**"
  echo "     ⇒ kalau boot-args juga punya revpatch=…, maka **boot-args yang menjadi acuan**"
  echo "     ⇒ Agar cpuname berlaku, revpatch di dalam boot-args **wajib memuat cpuname** juga (cpu-name.md §3)"
  echo "  ★ revcpuname mengandung spasi ⇒ **hanya bisa ditaruh di NVRAM** (boot-args akan terpecah pada spasi) (§3.1)"
  echo "  ★ Pada CPU Intel, revcpu **bawaan 0** ⇒ wajib menulis eksplisit revcpu=1 (§2)"
}

cfg() {
  [ -n "$CONFIG" ] || return 0
  echo
  # ★ bash 3.2: karakter full-width yang menyusul `$VAR` harus ditulis sebagai `${VAR}`, jika tidak nama variabelnya akan tertelan
  echo "=========== 3) Verifikasi config (${CONFIG}) ==========="
  [ -f "$CONFIG" ] || { echo "  File tidak ditemukan, dilewati"; return 0; }
  python3 - "$CONFIG" <<'PY'
import sys, plistlib
d = plistlib.load(open(sys.argv[1], "rb"))
pi = d.get("PlatformInfo", {})
g  = pi.get("Generic", {}) or {}
pt = g.get("ProcessorType", "<hilang>")
print(f"  PlatformInfo>Generic>ProcessorType = {pt}")
try:
    pt = int(pt)
    n = 0x0F01 if pt == 0x0F01 else (0x0601 if pt == 0x0601 else None)
    if n == 0x0F01:
        print("     ✓ 0x0F01 = 8 core atau lebih (persyaratan resmi, lihat cpu-name.md §5)")
    elif n == 0x0601:
        print("     ✓ 0x0601 = 1/2/4/6 core (persyaratan resmi)")
    else:
        print("     ⚠ Bukan 0x0F01 / 0x0601 ⇒ bisa menyebabkan ikon CPU / jumlah core tampil tidak normal")
except Exception:
    pass
print(f"  SystemProductName = {g.get('SystemProductName','<hilang>')}")
ba = ""
for guid, dd in (d.get("NVRAM", {}).get("Add", {}) or {}).items():
    if isinstance(dd, dict) and "boot-args" in dd:
        ba = dd["boot-args"]
toks = ba.split()
has = lambda t: any(x == t or x.startswith(t) for x in toks)
print(f"  boot-args memuat revpatch=cpuname : {'✓' if has('revpatch=cpuname') or any(x.startswith('revpatch=') and 'cpuname' in x for x in toks) else '✗ hilang'}")
print(f"  boot-args memuat revcpu=1         : {'✓' if 'revcpu=1' in toks else '✗ hilang (Intel bawaan 0)'}")
nvr = d.get("NVRAM", {}).get("Add", {}).get("4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102", {}) or {}
rn = nvr.get("revcpuname")
print(f"  NVRAM revcpuname              : {rn if rn else '(tidak ada)'}" + (f"  [{len(rn)} karakter, batas atas 48]" if rn else ""))
# Apakah kunci ini juga dicantumkan di Delete
dl = d.get("NVRAM", {}).get("Delete", {}).get("4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102", []) or []
print(f"  NVRAM>Delete mencantumkan kunci rev* : {dl if dl else '(kosong ⇒ kunci di Add mungkin tidak berlaku)'}")
PY
}

verdict() {
  echo
  echo "=========== 4) Interpretasi ==========="
  echo "  Nama berbeda dan ingin mengubah ⇒ ketiga kunci wajib lengkap:"
  echo "    revpatch=cpuname (boot-args) + revcpu=1 (boot-args) + revcpuname=<nama> (NVRAM)"
  echo "  ★ Setelah diubah harus boot ulang; ★ jangan lupa NVRAM>Delete juga harus memuat kunci ini"
  echo "  ★ Ini murni perubahan tampilan, tidak memengaruhi performa — kalau tidak peduli, jangan diubah (cpu-name.md §0)"
}

case "$ONLY" in
  name) names ;;
  args) args ;;
  *)    names; args; cfg; verdict ;;
esac

[ "$WARN" -eq 0 ] || exit 1
exit 0
