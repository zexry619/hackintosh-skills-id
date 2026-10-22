#!/bin/bash
# probe-join.sh — uji jalur TX data dari user space, sekali jalan.
#
# Dipakai SETELAH reboot dengan ESP bersih: dongle harus bebas dari driver
# kernel (M4 tidak diinjeksi, vendor Realtek dimatikan).
#
# Yang dibuktikan:
#   1. chip bisa init + cari AP + auth + assoc          (state machine)
#   2. frame data (QoS-Null) benar-benar dikirim & di-ACK (TX report)
#
# Kalau TX report muncul → masalah DHCP bukan di jalur data, tapi di kernel
# (sinkronisasi WCL / link state). Kalau tidak muncul → descriptor/queue TX.
#
# Pakai:
#   sudo ./scripts/probe-join.sh                 # SSID default ZEKRI.NET
#   sudo ./scripts/probe-join.sh "SSID Lain"
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSID="${1:-ZEKRI.NET}"
OUT="$ROOT/logs/join-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$ROOT/logs"

if [ "$(id -u)" -ne 0 ]; then
	echo "jalankan dengan sudo" >&2
	exit 1
fi

# Pastikan tidak ada yang memegang dongle.
if kextstat 2>/dev/null | grep -qi "zekri"; then
	echo "!! kext M4 masih termuat — cabut dongle / reboot dulu" >&2
	exit 2
fi
if kextstat 2>/dev/null | grep -qi "RtWlanU"; then
	echo "!! driver vendor Realtek masih termuat — lepas dulu:" >&2
	echo "   sudo kextunload -b com.realtek.RtWlanU" >&2
	exit 3
fi

echo "== uji join \"$SSID\" ==" | tee "$OUT"
"$ROOT/tools/rtwn_probe" --join "$SSID" --txnull 2>&1 | tee -a "$OUT"
rc=${PIPESTATUS[0]}

echo | tee -a "$OUT"
echo "log: $OUT" | tee -a "$OUT"
exit "$rc"
