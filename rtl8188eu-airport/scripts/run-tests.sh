#!/bin/bash
# Jalankan seluruh test offline (tanpa hardware, tanpa reboot).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail=0

run() {
	echo "───────────────────────────────────────────────"
	echo " $1"
	echo "───────────────────────────────────────────────"
	shift
	"$@" || fail=1
	echo
}

echo "=== TEST SUITE (offline) ==="
echo

# Catatan (22 Okt 2026): test_efuse_diff.c DIHENTIKAN dari suite.
# Referensinya adalah transkripsi pseudocode Ghidra yang sama-sama salah
# membaca semantik mask (bit SET dianggap 1 byte, bukan ABSENT). Test itu
# lulus hanya karena membandingkan dua implementasi yang salah dengan cara
# yang sama. Penggantinya adalah golden test dengan dump NYATA dari chip.
run "Parser EFUSE — golden test dump nyata 8188E (MAC/VID/strings)" bash -c \
	'clang -O2 -o /tmp/t_real tools/test_efuse_real.c src/urtwn/rtwn_seq.c -Isrc/urtwn && /tmp/t_real'

run "Parser EFUSE — image sintetis (tabel mask asli vendor)" bash -c \
	'clang -O2 -o /tmp/t_syn tools/test_efuse.c src/urtwn/rtwn_seq.c -Isrc/urtwn && /tmp/t_syn'

run "Transport USB — descriptor TX/RX + ring TX" bash -c \
	'clang -O2 -o /tmp/t_usb tools/test_usb.c src/urtwn/rtwn_usb.c -Isrc/urtwn && /tmp/t_usb'

run "Keamanan rtwn_seq — regression F1/F4/F5" bash -c \
	'clang -O2 -o /tmp/t_seq tools/test_seq_safety.c src/urtwn/rtwn_seq.c src/urtwn/rtwn_seq_efuse.c src/urtwn/rtwn_efuse_8188e.c -Isrc/urtwn && /tmp/t_seq'

run "Frame 802.11 — probe request & parser SSID/BSSID (M2)" bash -c \
	'clang -O2 -o /tmp/t_80211 tools/test_80211.c src/urtwn/rtwn_80211.c -Isrc/urtwn && /tmp/t_80211'

run "Set kanal 8188E — RF/BB register path (M2)" bash -c \
	'clang -O2 -o /tmp/t_chan tools/test_chan.c src/urtwn/rtwn_chan.c src/urtwn/rtwn_seq.c src/urtwn/rtwn_seq_efuse.c src/urtwn/rtwn_efuse_8188e.c -Isrc/urtwn && /tmp/t_chan'

run "Sequence pause/enable 8051 (regresi root cause EFUSE)" bash -c \
	'clang -O2 -o /tmp/t_8051 tools/test_8051.c src/urtwn/rtwn_seq_efuse.c src/urtwn/rtwn_seq.c src/urtwn/rtwn_efuse_8188e.c -Isrc/urtwn && /tmp/t_8051'

run "Keseimbangan lock/unlock (regression PANIC #4)" bash -c \
	'python3 scripts/lint-locks.py'

run "Tabel & applier HAL 8188E (ekstraksi vendor)" bash -c \
	'clang -O2 -o /tmp/t_hal tools/test_hal_tables.c src/urtwn/rtwn_hal_8188e.c src/urtwn/rtwn_mp_8188e.c -Isrc/urtwn && /tmp/t_hal'

run "Build kext (AMAN, inert)" bash -c './scripts/build-m1.sh | tail -3'
run "Build probe (user space)" bash -c './scripts/build-probe.sh | tail -1'

if [[ $fail -eq 0 ]]; then
	echo "✅ SEMUA TEST LULUS"
else
	echo "❌ ADA TEST YANG GAGAL"
fi
exit $fail
