#!/bin/bash
# Di macOS, blokir semua volume disk selain volume sistem: /etc/fstab + noauto ⇒ tidak ter-mount otomatis saat boot
#   ⇒ tidak muncul di Desktop / Finder / Spotlight; masih bisa di-mount manual (sudo diskutil mount <dev>)
#
# Cara pakai:
#   mask-other-disks.sh                 # hanya mencetak rencana (dry-run), tidak menulis apa pun
#   mask-other-disks.sh --apply         # menulis /etc/fstab dan langsung unmount volume yang diblokir (membutuhkan root)
#   mask-other-disks.sh --apply --keep B97A1BB4-…    # simpan volume tertentu (bisa berulang kali --keep)
#   mask-other-disks.sh --undo          # menghapus /etc/fstab (membatalkan semua pemblokiran)
#
# ★ Aturan mutlak: partisi EFI (Partition Type = EFI) tidak pernah ditulis ke fstab; setelah selesai akan dilakukan
#   sekali verifikasi "cari ESP berdasarkan UUID → unmount → mount ulang → baca config.plist".
set -euo pipefail

APPLY=0; UNDO=0; KEEP=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1;;
    --undo)  UNDO=1;;
    --keep)  KEEP="$KEEP ${2:-}"; shift;;
    *) echo "Parameter tidak dikenal: $1"; exit 2;;
  esac
  shift
done

FSTAB=/etc/fstab

if [ "$UNDO" = 1 ]; then
  echo "== Batalkan pemblokiran: hapus $FSTAB =="
  if [ -f "$FSTAB" ]; then
    cp -p "$FSTAB" "/tmp/fstab.bak-$(date +%Y%m%d-%H%M%S)"
    if [ "$(id -u)" = 0 ]; then rm -f "$FSTAB"; else
      osascript -e "do shell script \"/bin/rm -f $FSTAB\" with administrator privileges"; fi
    echo "   Telah dihapus (salinan lama disimpan di /tmp). Berlaku setelah reboot."
  else
    echo "   $FSTAB tidak ada, tidak perlu dibatalkan."
  fi
  exit 0
fi

echo "== 1) Enumerasi semua volume asli, pilih yang 'bukan sistem dan bukan EFI' =="
TARGETS=""
while IFS= read -r dev; do
  info=$(diskutil info "$dev" 2>/dev/null) || continue
  uuid=$(printf '%s\n' "$info" | awk -F': *' '/Volume UUID/{print $2}')
  name=$(printf '%s\n' "$info" | awk -F': *' '/Volume Name/{print $2}')
  fs=$(printf '%s\n'   "$info" | awk -F': *' '/File System Personality/{print $2}')
  ptype=$(printf '%s\n' "$info" | awk -F': *' '/Partition Type/{print $2}')
  mp=$(printf '%s\n'  "$info" | awk -F': *' '/Mount Point/{print $2}')
  [ -n "$uuid" ] || continue                       # volume tanpa UUID (volume sintetis/container) dilewati
  if [ "$ptype" = "EFI" ]; then printf '   skip %-10s %-22s partisi EFI (tidak pernah diblokir)\n' "$dev" "$name"; continue; fi
  case "$fs" in *APFS*) printf '   skip %-10s %-22s APFS (volume sistem)\n' "$dev" "$name"; continue;; esac
  case "$mp" in /|/System/*) printf '   skip %-10s %-22s titik mount sistem\n' "$dev" "$name"; continue;; esac
  case " $KEEP " in *" $uuid "*) printf '   keep %-10s %-22s disimpan oleh pengguna\n' "$dev" "$name"; continue;; esac
  printf '   MASK %-10s %-22s %-6s %s\n' "$dev" "${name:-<tanpa nama>}" "${fs:-?}" "$uuid"
  TARGETS="$TARGETS $uuid|$dev|${name:-unnamed}|${fs:-ntfs}"
done <<EOF
$(diskutil list | grep -oE 'disk[0-9]+s[0-9]+' | sort -u || true)
EOF

if [ -z "$TARGETS" ]; then echo "   (tidak ada volume yang perlu diblokir)"; fi

echo
echo "== 2) Rencana isi $FSTAB yang akan ditulis =="
{
  echo "# Blokir volume non-macOS —— hanya volume sistem yang ter-mount otomatis (dihasilkan oleh mask-other-disks.sh, $(date +%Y-%m-%d))"
  echo "# ★★ Partisi EFI tidak ada di daftar! Boot berada di atasnya, instalasi App bergantung padanya untuk menulis dan membaca config.plist ⇒ tidak pernah diblokir"
  echo "# Akses sementara: sudo diskutil mount /dev/diskXsY   Batalkan semuanya: sudo rm /etc/fstab lalu reboot"
  for t in $TARGETS; do
    u=${t%%|*}; rest=${t#*|}; d=${rest%%|*}; rest=${rest#*|}; n=${rest%%|*}; fs=${rest##*|}
    printf 'UUID=%s none %s noauto   # %s (%s)\n' "$u" "$(echo "$fs" | tr 'A-Z' 'a-z')" "$n" "$d"
  done
} | tee /tmp/_fstab.new

if [ "$APPLY" != 1 ]; then
  echo
  echo "== dry-run: tidak ada yang ditulis. Setelah yakin, jalankan =="
  echo "   sudo bash \"$0\" --apply"
  exit 0
fi

echo
echo "== 3) Tulis $FSTAB dan langsung unmount volume yang diblokir =="
SCRIPT=/tmp/_mask-apply-$$.sh
cat > "$SCRIPT" <<EOF
#!/bin/bash
cp -p "$FSTAB" /tmp/fstab.bak-\$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
cp /tmp/_fstab.new "$FSTAB"
chmod 644 "$FSTAB"; chown root:wheel "$FSTAB"
echo "== fstab sudah ditulis =="; cat "$FSTAB"
echo
echo "== Unmount volume yang diblokir =="
for t in $(for x in $TARGETS; do printf '%s ' "${x%%|*}"; done); do
  for d in \$(diskutil list | grep -oE 'disk[0-9]+s[0-9]+' | sort -u); do
    u=\$(diskutil info "\$d" 2>/dev/null | awk -F': *' '/Volume UUID/{print \$2}')
    if [ "\$u" = "$t" ]; then printf '  %s (%s) -> ' "\$d" "\$u"; diskutil unmount "\$d" 2>&1 | tail -1; fi
  done
done
echo
echo "== Sekarang /Volumes =="; ls -1 /Volumes
echo
echo "== Verifikasi partisi EFI tidak terpengaruh (cari ESP berdasarkan UUID → unmount → mount ulang → baca config)=="
esp=""
for d in \$(diskutil list | grep -oE 'disk[0-9]+s[0-9]+' | sort -u); do
  i=\$(diskutil info "\$d" 2>/dev/null)
  echo "\$i" | grep -q 'Partition Type:.*EFI' && esp="\$d"
done
if [ -n "\$esp" ]; then
  echo "  ESP = \$esp"
  diskutil unmount "\$esp" 2>&1 | tail -1
  diskutil mount   "\$esp" 2>&1 | tail -1
  ls -d /Volumes/EFI && ls -la /Volumes/EFI/EFI/OC/config.plist | tail -1
  echo "  ↑ bisa di-unmount, bisa di-mount, config terbaca ⇒ EFI tidak terpengaruh"
else
  echo "  ★ Partisi EFI tidak ditemukan, konfirmasi secara manual"
fi
EOF
chmod +x "$SCRIPT"
if [ "$(id -u)" = 0 ]; then bash "$SCRIPT"; else
  osascript -e "do shell script \"/bin/bash \\\"$SCRIPT\\\"\" with administrator privileges"; fi
rm -f "$SCRIPT"
