#!/bin/bash
# safe-test-window.sh — JENDELA UJI TERKENDALI untuk driver RTL8188EUM1.
#
# TUJUAN: satu perintah untuk mencoba driver kernel kita TANPA risiko
# leaving the machine in a broken state.
#
# Yang dilakukan skrip ini:
#   1. Pastikan build varian UJI (M1_ALLOW_USB_TRAFFIC=1) sudah ada
#   2. Matikan driver vendor Realtek (WIFI MATI selama jendela uji)
#   3. Load kext varian UJI (hot-swap runtime — TIDAK PERLU REBOOT)
#   4. Trigger init secara EKSPLISIT
#   5. Kumpulkan semua marker (M1State / M1Log / M1Mac / ...)
#   6. ** SELALU kembalikan driver vendor, apa pun hasilnya **
#   7. Laporan hasil
#
# Jaminan: langkah 6 berjalan lewat `trap`, jadi meskipun skrip di-Ctrl-C
# atau crash, driver vendor tetap dikembalikan. Ini penting karena
# driver vendor = jalur Wi-Fi Anda yang sekarang BEKERJA.
#
# CATATAN PENTING:
#   - Driver vendor dimatikan HANYA dengan memindahkan folder .kext.
#     Efeknya berlaku setelah reboot; untuk sesi ini kita juga unload
#     lewat kmutil (best-effort).
#   - Untuk pemakaian SEHARI-HARI: `sudo ./scripts/vendor-on.sh`.
#
# Usage:  sudo ./scripts/safe-test-window.sh [--keep]
#           --keep  = jangan kembalikan driver vendor (untuk debugging)

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="io.github.zekri.RTL8188EUM1"
PERSONALITY="RTL8188EUM1"
UJI_KEXT="$ROOT/src/build-test/RTL8188EUM1.kext"
LOG_DIR="$ROOT/logs"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/window-$STAMP.log"

KEEP=0
[[ "${1:-}" == "--keep" ]] && KEEP=1

mkdir -p "$LOG_DIR"

say() { printf '%s\n' "$*" | tee -a "$LOG"; }
hr()  { say "────────────────────────────────────────────────────────"; }

restore_vendor() {
	if [[ $KEEP -eq 1 ]]; then
		say "[restore] --keep dipakai → driver vendor TIDAK dikembalikan."
		say "[restore] Kembalikan manual: sudo $ROOT/scripts/vendor-on.sh"
		return
	fi
	hr
	say "[restore] mengembalikan driver vendor Realtek..."

	# 1. lepas driver kita dulu — kalau tidak, driver kita yang tetap
	#    memegang node USB dan vendor tidak bisa mengklaimnya kembali.
	say "[restore] melepas driver eksperimental (supaya vendor bisa klaim balik)..."
	sudo kmutil unload -b "$BUNDLE_ID" 2>&1 | head -2 | tee -a "$LOG"

	# 2. kembalikan folder .kext vendor
	"$ROOT/scripts/vendor-on.sh" 2>&1 | tee -a "$LOG"

	# 3. coba muat ulang vendor di sesi ini
	say "[restore] mencoba memuat ulang RtWlanU di sesi ini..."
	if sudo kmutil load -z -p /Library/Extensions/RtWlanU.kext 2>&1 | tee -a "$LOG" | head -3; then
		say "[restore] percobaan muat ulang selesai."
	else
		say "[restore] muat ulang GAGAL."
	fi

	sleep 2
	if kextstat 2>/dev/null | grep -qi rtwlan; then
		say "[restore] ✅ driver vendor TERMUAT lagi — Wi-Fi aktif."
	else
		say "[restore] ⚠️  driver vendor belum termuat di sesi ini."
		say "[restore]    Folder .kext SUDAH dikembalikan (berlaku setelah reboot)."
		say "[restore]    → reboot SEKALI untuk Wi-Fi vendor kembali."
		say "[restore]    (Ini tetap aman: reboot normal, tidak ada driver eksperimental di ESP.)"
	fi
}

# trap: apa pun yang terjadi (Ctrl-C, error, exit), vendor dikembalikan.
trap restore_vendor EXIT INT TERM

hr
say "═══ JENDELA UJI TERKENDALI — $STAMP ═══"
say "log: $LOG"

# ── 0. cek prasyarat ────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
	say "❌ jalankan dengan sudo"
	exit 1
fi

if [[ ! -d "$UJI_KEXT" ]]; then
	say "⟳ build varian UJI belum ada → build dulu..."
	"$ROOT/scripts/build-m1.sh" 2>&1 | tee -a "$LOG" | tail -3
fi
if [[ ! -d "$UJI_KEXT" ]]; then
	say "❌ gagal build varian UJI — batal"
	exit 1
fi
say "[0] varian UJI siap: $UJI_KEXT"

# ── 1. catat kondisi sebelum ────────────────────────────────────────
say "[1] kondisi sebelum:"
say "    Wi-Fi sebelum: $(ifconfig en2 2>/dev/null | grep -o 'inet [0-9.]*' || echo 'tidak ada')"
say "    kext eksperimen termuat: $(kextstat 2>/dev/null | grep -ic zekri)"

# ── 2. matikan vendor ───────────────────────────────────────────────
hr
say "[2] mematikan driver vendor Realtek (Wi-Fi mati sebentar)..."
"$ROOT/scripts/vendor-off.sh" 2>&1 | tee -a "$LOG"
say "    ℹ️  perubahan folder .kext berlaku penuh setelah reboot;"
say "       untuk sesi ini kita ALSO unload lewat kmutil (best-effort)."

sudo kmutil unload -b com.realtek.driver.RtWlanU 2>&1 | tee -a "$LOG" | head -2
sudo kmutil unload -b com.realtek.driver.RtWlanU1827 2>&1 | tee -a "$LOG" | head -2

# tunggu USB stack melepas klaim
sleep 2
say "[2] kext vendor masih termuat? $(kextstat 2>/dev/null | grep -ic rtwlan)"

# ── 3. load kext varian UJI (hot-swap, TANPA reboot) ───────────────
hr
say "[3] load kext varian UJI (hot-swap runtime)..."
sudo kmutil load -z -p "$UJI_KEXT" 2>&1 | tee -a "$LOG" | head -3
sleep 2
say "[3] termuat? $(kextstat 2>/dev/null | grep -i zekri | awk '{print $1}')"

# ── 4. memicu init ─────────────────────────────────────────────────
hr
say "[4] memicu init..."
say "    Varian UJI (M1_ALLOW_USB_TRAFFIC=1) menjalankan init pada"
say "    start() pertama — jadi load di atas SUDAH memicu init."
say "    Kalau node USB sudah diklaim driver lain, perlu CABUT-COLOK"
say "    dongle → node baru → driver attach ulang → init jalan."
say ""
say "    ⏳ Silakan CABUT-COLOK dongle Wi-Fi USB sekarang."
say "       (jika tidak, init mungkin sudah jalan saat load di atas)"
sleep 3
say "    status: $(ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | grep -oE '"M1State" = "[^"]*"' | head -1)"

# ── 5. kumpulkan marker ─────────────────────────────────────────────
hr
say "[5] marker registry:"
ioreg -r -c RTL8188EUM1 -w0 2>/dev/null \
	| grep -oE '"M1[A-Za-z]+" = "[^"]*"' | sed 's/^/    /' | tee -a "$LOG"

hr
say "[5] Unified Log (RTL8188EU):"
log show --last 3m --predicate 'eventMessage contains "RTL8188EU"' \
	--style compact 2>/dev/null | tail -40 | tee -a "$LOG"

# ── 6. ringkasan langsung ─────────────────────────────────────────
hr
say "[6] ringkasan:"
STATE=$(ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | grep -oE '"M1State" = "[^"]*"' | head -1)
MAC=$(ioreg -r -c RTL8188EUM1 -w0 2>/dev/null | grep -oE '"M1Mac" = "[^"]*"' | head -1)
say "    M1State: ${STATE:-(tidak ada)}"
say "    M1Mac  : ${MAC:-(tidak ada)}"
say "    MAC dongle yang diharapkan: 98:03:8e:9e:bc:24"

hr
say "═══ SELESAI — vendor dikembalikan oleh trap ═══"
say "log lengkap: $LOG"
