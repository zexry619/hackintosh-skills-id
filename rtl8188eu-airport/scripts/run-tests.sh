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

run "Parser EFUSE — differential vs transkripsi pseudocode Ghidra" bash -c \
	'clang -O2 -o /tmp/t_diff tools/test_efuse_diff.c src/urtwn/rtwn_seq.c -Isrc/urtwn && /tmp/t_diff'

run "Parser EFUSE — image sintetis (tabel mask asli vendor)" bash -c \
	'clang -O2 -o /tmp/t_syn tools/test_efuse.c src/urtwn/rtwn_seq.c -Isrc/urtwn && /tmp/t_syn'

run "Transport USB — descriptor TX/RX + ring TX" bash -c \
	'clang -O2 -o /tmp/t_usb tools/test_usb.c src/urtwn/rtwn_usb.c -Isrc/urtwn && /tmp/t_usb'

run "Keamanan rtwn_seq — regression F1/F4/F5" bash -c \
	'clang -O2 -o /tmp/t_seq tools/test_seq_safety.c src/urtwn/rtwn_seq.c src/urtwn/rtwn_seq_efuse.c src/urtwn/rtwn_efuse_8188e.c -Isrc/urtwn && /tmp/t_seq'

run "Frame 802.11 — probe request & parser SSID/BSSID (M2)" bash -c \
	'clang -O2 -o /tmp/t_80211 tools/test_80211.c src/urtwn/rtwn_80211.c -Isrc/urtwn && /tmp/t_80211'

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
