#!/bin/bash
# Ambil sumber daya OpenCanopy (set ikon / font / label / audio) dari OcBinaryData resmi
#
# Cara pakai:
#   oc-fetch-iconset.sh iconset <GoldenGate|Syrah|Chardonnay|all> [direktori Resources]
#   oc-fetch-iconset.sh font    [direktori Resources]
#   oc-fetch-iconset.sh label   [direktori Resources]
#   oc-fetch-iconset.sh audio   [kode bahasa] [direktori Resources]     # kode bahasa seperti zh_CN / en; jika dihilangkan hanya ambil yang umum
#   Direktori Resources default = /Volumes/EFI/EFI/OC/Resources
#
# Sumber: https://github.com/acidanthera/OcBinaryData (repositori sumber daya resmi)
# Perhatikan: hanya menambahkan file, tidak menghapus file yang ada; file dengan nama sama akan ditimpa (backup dulu sendiri)
set -u

REPO="acidanthera/OcBinaryData"
RAW="https://raw.githubusercontent.com/$REPO/master/Resources"

mode="${1:?cara pakai: oc-fetch-iconset.sh <iconset|font|label|audio> [argumen] [direktori Resources]}"
shift

case "$mode" in
  iconset)
    SET="${1:?nama set ikon wajib diisi: GoldenGate | Syrah | Chardonnay | all}"; shift
    R="${1:-/Volumes/EFI/EFI/OC/Resources}"
    [ -d "$R" ] || { echo "$R tidak ditemukan"; exit 2; }
    case "$SET" in
      all) SETS="GoldenGate Syrah Chardonnay";;
      *)   SETS="$SET";;
    esac
    for s in $SETS; do
      dst="$R/Image/Acidanthera/$s"
      mkdir -p "$dst"
      echo "== Ambil set ikon $s → $dst =="
      list=$(curl -sSL --max-time 60 "https://api.github.com/repos/$REPO/contents/Resources/Image/Acidanthera/$s" \
             | grep -o '"name": "[^"]*\.icns"' | sed 's/.*: "//;s/"//')
      [ -n "$list" ] || { echo "   ★ gagal mengambil daftar (jaringan/rate limit?)"; continue; }
      n=0
      for f in $list; do
        if curl -sSL --max-time 60 -f "$RAW/Image/Acidanthera/$s/$f" -o "$dst/$f"; then n=$((n+1)); else echo "   ★ unduhan gagal $f"; fi
      done
      echo "   selesai $n berkas .icns"
    done
    ;;

  font)
    R="${1:-/Volumes/EFI/EFI/OC/Resources}"; dst="$R/Font"; mkdir -p "$dst"
    echo "== Ambil font → $dst =="
    for f in Font_1x.bin Font_2x.bin Font_1x.png Font_2x.png; do
      curl -sSL --max-time 60 -f "$RAW/Font/$f" -o "$dst/$f" && echo "   $f" || echo "   ★ $f gagal"
    done
    ;;

  label)
    R="${1:-/Volumes/EFI/EFI/OC/Resources}"; dst="$R/Label"; mkdir -p "$dst"
    echo "== Ambil label → $dst =="
    list=$(curl -sSL --max-time 60 "https://api.github.com/repos/$REPO/contents/Resources/Label" \
           | grep -o '"name": "[^"]*"' | sed 's/.*: "//;s/"//' | grep -E '\.(lbl|l2x)$')
    n=0
    for f in $list; do
      curl -sSL --max-time 60 -f "$RAW/Label/$f" -o "$dst/$f" && n=$((n+1)) || echo "   ★ $f gagal"
    done
    echo "   selesai $n label"
    ;;

  audio)
    LANG_="${1:-}"; case "$LANG_" in /*|"") R="${1:-/Volumes/EFI/EFI/OC/Resources}"; LANG_="";; *) R="${2:-/Volumes/EFI/EFI/OC/Resources}";; esac
    dst="$R/Audio"; mkdir -p "$dst"
    echo "== Ambil audio → $dst (bahasa: ${LANG_:-hanya umum}) =="
    list=$(curl -sSL --max-time 60 "https://api.github.com/repos/$REPO/contents/Resources/Audio" \
           | grep -o '"name": "[^"]*\.mp3"' | sed 's/.*: "//;s/"//')
    [ -n "$list" ] || { echo "   ★ gagal mengambil daftar"; exit 1; }
    n=0
    for f in $list; do
      keep=0
      case "$f" in
        AXEFIAudio_Beep.mp3|AXEFIAudio_Click.mp3|AXEFIAudio_VoiceOver_Boot.mp3) keep=1;;
        AXEFIAudio_"$LANG"_*) [ -n "$LANG_" ] && keep=1;;
      esac
      [ "$keep" = 1 ] || continue
      curl -sSL --max-time 60 -f "$RAW/Audio/$f" -o "$dst/$f" && n=$((n+1)) || echo "   ★ $f gagal"
    done
    echo "   selesai $n mp3 (kumpulan lengkap ada 362, ambil lagi seperlunya)"
    ;;

  *) echo "mode tidak dikenal ${mode} (pilihan: iconset / font / label / audio)"; exit 2;;
esac

echo
echo "== Catatan =="
echo "  1) Kemudian di config set Misc>Boot>PickerMode ke External, dan PickerVariant arahkan ke set ikon (misalnya Acidanthera\\GoldenGate)"
echo "  2) Jalankan oc-theme-check.sh untuk verifikasi, setelah restart periksa baris OCUI: di log OC"
echo "  3) Yang diubah adalah ESP ⇒ ingat untuk sync → unmount → remount → verifikasi ulang sha"
