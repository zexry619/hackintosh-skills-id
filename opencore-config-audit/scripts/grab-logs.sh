#!/bin/bash
# Ambil bukti saat boot: log milik OpenCore sendiri + kernel log dari boot ini (ACPI / perangkat platform)
#
# Cara pakai: grab-logs.sh [direktori keluaran] [--oc-only]     default ./_oc-logs
#   --oc-only  hanya ambil log OpenCore (tidak perlu root; memudahkan untuk melihat sekilas)
#   Bagian kernel log memerlukan root; bila bukan root akan otomatis memakai AppleScript untuk memperoleh hak akses (akan menampilkan dialog kata sandi)
set -u

OUT="./_oc-logs"; OC_ONLY=0
for a in "$@"; do
  case "$a" in
    --oc-only) OC_ONLY=1;;
    *) OUT="$a";;
  esac
done
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)

# ---------- 1) Log boot OpenCore ----------
echo "== 1) Log boot OpenCore (opencore-*.txt di root ESP, Target harus memuat 0x40) =="
: > "$OUT/oc-boot-log-summary.txt"
FOUND=0
for esp in /Volumes/*/; do
  for f in "$esp"opencore-*.txt; do
    [ -f "$f" ] || continue
    FOUND=1
    echo "--- $f  ($(stat -f %z "$f") B) ---" >> "$OUT/oc-boot-log-summary.txt"
    grep -aE "OpenCore .*(loading|is loading)|OCABC:|OCA: (Found|Deleting|Inserted)|OCJS: APFS driver|OCB: Registering entry|OCB: Not adding hidden|OC: (WARN|ERROR)|OCB: ERROR|OCAU: [0-9]" "$f" \
      | cut -c1-190 >> "$OUT/oc-boot-log-summary.txt" 2>/dev/null
    cp -p "$f" "$OUT/" 2>/dev/null || true
  done
done
if [ "$FOUND" = 0 ]; then
  echo "   opencore-*.txt tidak ditemukan. Kemungkinan penyebab:" | tee -a "$OUT/oc-boot-log-summary.txt"
  echo "   - Misc>Debug>Target tidak memuat 0x40 (tidak menulis berkas)" | tee -a "$OUT/oc-boot-log-summary.txt"
  echo "   - ESP tidak di-mount (ls -d /Volumes/EFI)" | tee -a "$OUT/oc-boot-log-summary.txt"
  echo "   Cara baca cadangan (cukup Target memuat 0x04):" | tee -a "$OUT/oc-boot-log-summary.txt"
  echo "   ioreg -lw0 -p IODeviceTree | grep boot-log | sort | sed 's/.*<\\(.*\\)>.*/\\1/' | xxd -r -p" | tee -a "$OUT/oc-boot-log-summary.txt"
else
  echo "   → $OUT/oc-boot-log-summary.txt"
fi

# ---------- 2) Kernel log boot ini ----------
if [ "$OC_ONLY" = 1 ]; then
  echo
  echo "(--oc-only: bagian kernel log dilewati)"
  echo "== Selesai =="; ls -la "$OUT"; exit 0
fi

BOOT=$(sysctl -n kern.boottime 2>/dev/null | sed -n 's/.*sec = \([0-9]*\).*/\1/p')
START=$(date -r "${BOOT:-0}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
echo
echo "== 2) Kernel log boot ini (waktu boot ${START:-tidak diketahui}) =="

SCRIPT="$OUT/_grab-kernel.sh"
cat > "$SCRIPT" <<EOF
#!/bin/bash
OUT="$OUT/kernel-log-acpi.txt"
{
  echo "=== Waktu pengambilan ==="; date
  echo "=== Waktu boot ==="; sysctl -n kern.boottime
  echo
  echo "=== A) Error ACPI (0 hit = ACPI tidak rusak) ==="
  /usr/bin/log show --start "$START" --style compact 2>&1 \
    | grep -aiE "acpi error|ae_not_found|ae_already|ae_error|namespace lookup|ACPI Exception|Error evaluating" | head -40
  echo
  echo "=== B) Tabel ACPI yang diurai macOS ==="
  /usr/bin/log show --start "$START" --style compact 2>&1 \
    | grep -a "AppleACPIPlatform" | grep -aE "FACP|FACS|DSDT|XSDT|RSDT|RSDP|MCFG|HPET|APIC|SSDT|DMAR|BGRT|WSMT" | sort -u | head -40
  echo
  echo "=== C) Perangkat platform / pemasangan driver ==="
  /usr/bin/log show --start "$START" --style compact --predicate 'process == "kernel"' 2>&1 \
    | grep -aiE "smbus|AppleSMBus|hpet|AppleRTC|GPRW|GPE |xhci|AppleUSB|igc|I225|AppleIntelPCH|SATA|AHCI|COMRESET|AppleHDAController|AppleSMC|Previous shutdown cause" | head -80
  echo
  echo "=== D) Keberadaan perangkat bidang ACPI ==="
  for n in SBUS BUS0 MCHC PMCR AWAC RTC RTC0 HPET GPRW XHCI GFX0 IGPU PEG0 PEG1 SAT0 HDAS; do
    printf "  %-6s %s\n" "\$n" "\$(/usr/sbin/ioreg -p IOACPIPlane -w0 2>/dev/null | grep -c "\$n")"
  done
  echo
  echo "=== E) Disk / mount ==="
  /usr/sbin/diskutil list 2>&1 | head -40
  /bin/ls -1 /Volumes
} > "\$OUT" 2>&1
/bin/chmod 644 "\$OUT"
echo done
EOF
chmod +x "$SCRIPT"

if [ "$(id -u)" = 0 ]; then
  bash "$SCRIPT"
else
  echo "   Perlu memperoleh hak akses (akan menampilkan dialog kata sandi)..."
  osascript -e "do shell script \"/bin/bash \\\"$SCRIPT\\\"\" with administrator privileges" 2>&1 | tail -2
fi

if [ -s "$OUT/kernel-log-acpi.txt" ]; then
  echo "   → $OUT/kernel-log-acpi.txt"
else
  echo "   ★ Tidak ada konten yang terambil. Jalankan manual: sudo bash \"$SCRIPT\""
fi

echo
echo "== Selesai =="
ls -la "$OUT"
