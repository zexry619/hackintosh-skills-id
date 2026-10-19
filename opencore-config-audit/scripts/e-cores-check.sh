#!/bin/sh
# e-cores-check.sh —— audit kondisi saat ini pada arsitektur hybrid Intel (P-core / E-core)
#
# Kegunaan: menilai "apakah E-core diaktifkan" dan "dalam kondisi apa", lalu memberikan interpretasi.
#       Dipakai bersama references/e-cores.md.
#
# Cara pakai:
#   ./e-cores-check.sh              # audit lengkap
#   ./e-cores-check.sh --topo       # hanya topologi
#   ./e-cores-check.sh --freq       # hanya frekuensi (memerlukan cpu-freq-probe.sh di direktori yang sama)
#
# Bergantung pada: sysctl / system_profiler (bawaan macOS). Opsional: cpu-freq-probe.sh di direktori yang sama.
# Kode keluar: 0 normal; 1 ada item anomali (hanya peringatan, bukan berarti gagal).

set -u

ONLY=""
for a in "$@"; do
  case "$a" in
    --topo) ONLY=topo ;;
    --freq) ONLY=freq ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Parameter tidak dikenal: $a (-h untuk cara pakai)" >&2; exit 2 ;;
  esac
done

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
WARN=0
say() { printf '%s\n' "$*"; }
kv()  { printf '  %-38s = %s\n' "$1" "${2:-<kosong>}"; }

topo() {
  say "=========== 1) Topologi CPU ==========="
  printf '  %-38s = ' "hw.ncpu / physicalcpu / logicalcpu"
  sysctl -n hw.ncpu hw.physicalcpu hw.logicalcpu 2>/dev/null | tr '\n' ' '; echo

  np=$(sysctl -n hw.nperflevels 2>/dev/null)
  kv "hw.nperflevels" "${np:-<tidak ada>}"

  p0p=$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null)
  p0l=$(sysctl -n hw.perflevel0.logicalcpu  2>/dev/null)
  printf '  %-38s = %s\n' "perflevel0 (P-core) physical/logical" "${p0p:-<tidak ada>} / ${p0l:-<tidak ada>}"

  p1p=$(sysctl -n hw.perflevel1.physicalcpu 2>/dev/null)
  p1l=$(sysctl -n hw.perflevel1.logicalcpu  2>/dev/null)
  printf '  %-38s = %s\n' "perflevel1 (E-core) physical/logical" "${p1p:-<tidak ada>} / ${p1l:-<tidak ada>}"

  kv "machdep.cpu.core_count" "$(sysctl -n machdep.cpu.core_count 2>/dev/null)"
  kv "machdep.cpu.thread_count" "$(sysctl -n machdep.cpu.thread_count 2>/dev/null)"
  kv "hw.cputhreadtype" "$(sysctl -n hw.cputhreadtype 2>/dev/null)"

  say ""
  say "  -- Model mesin --"
  kv "hw.model" "$(sysctl -n hw.model 2>/dev/null)"
  system_profiler SPHardwareDataType 2>/dev/null \
    | grep -E "Model Identifier|Total Number of Cores|Chip|Processor Name" \
    | sed 's/^[[:space:]]*/     /'
}

freq() {
  say "=========== 2) Probe frekuensi ==========="
  if [ -x "$DIR/cpu-freq-probe.sh" ]; then
    say "  Baseline (i7-12700K): single-thread ≈ 4.28 GHz / 8 thread ≈ 4.29–4.35 GHz"
    "$DIR/cpu-freq-probe.sh" 2>/dev/null || say "  (probe gagal dijalankan)"
  else
    say "  cpu-freq-probe.sh tidak ditemukan, dilewati (bisa ditaruh bersama di direktori scripts/)"
  fi
}

kext() {
  say ""
  say "=========== 3) Apakah CpuTopologyRebuild dimuat ==========="
  if command -v kmutil >/dev/null 2>&1; then
    out=$(kmutil showloaded --list-only 2>/dev/null | grep -i CpuTopologyRebuild)
    if [ -n "$out" ]; then
      say "  Dimuat: $out"
    else
      say "  Tidak dimuat (atau perlu hak admin) ⇒ jika Enabled=true di config tapi tidak terlihat, periksa jalur kext dan ketergantungan pada Lilu"
    fi
  else
    say "  kmutil tidak tersedia, dilewati"
  fi
  say "  ★ Perlu juga memastikan config: entri di Kernel > Add memiliki Enabled=true dan berada setelah Lilu"
}

verdict() {
  say ""
  say "=========== 4) Interpretasi ==========="
  np=$(sysctl -n hw.nperflevels 2>/dev/null)
  ncpu=$(sysctl -n hw.ncpu 2>/dev/null)
  case "$np" in
    1) say "  hw.nperflevels=1 ⇒ macOS hanya melihat satu jenis core (E-core tidak diekspos)"
       say "     · Jika BIOS sudah menyetel Active Efficient Cores ke All ⇒ periksa apakah ProvideCurrentCpuInfo bernilai true"
       say "     · Jika E-core sengaja dimatikan ⇒ ini adalah kondisi yang diharapkan, lihat e-cores.md §2 (jangan dianggap kegagalan)" ;;
    2) say "  hw.nperflevels=2 ⇒ kedua tingkat P / E sudah dikenali (E-core aktif)"
       if [ "${ncpu:-0}" -ge 20 ]; then
         say "     hw.ncpu=$ncpu ⇒ 20 thread, E-core sudah diserahkan ke kernel"
       else
         say "     ⚠ hw.ncpu=$ncpu (konfigurasi penuh mesin ini seharusnya 20) ⇒ periksa apakah Hyper-Threading Enabled"
         WARN=1
       fi
       say "     Langkah berikutnya: pastikan CpuTopologyRebuild sudah dimuat (bagian 3 di atas), bandingkan hasil benchmark dengan baseline E-core mesin ini" ;;
    *) say "  hw.nperflevels tidak terbaca (bukan arsitektur hybrid Intel / sistem lama)" ;;
  esac
  say "  ★ Mengaktifkan E-core + boot-arg -v bisa menyebabkan boot gagal secara acak (README resmi menyatakan hal ini) ⇒ perhatikan saat menelusuri masalah"
  say "  ★ Jika frekuensi lebih rendah dari baseline ⇒ rekonstruksi topologi bertabrakan dengan XCPM, pertimbangkan rollback (e-cores.md §6)"
}

case "$ONLY" in
  topo) topo ;;
  freq) freq ;;
  *)    topo; freq; kext; verdict ;;
esac

[ "$WARN" -eq 0 ] || exit 1
exit 0
