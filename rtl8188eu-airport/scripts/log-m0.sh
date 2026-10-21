#!/bin/bash
# Tampilkan log kernel untuk kext M0 (live stream, tekan Ctrl+C untuk berhenti).
set -uo pipefail

echo "[log] streaming log kernel untuk RTL8188EUHello (Ctrl+C untuk berhenti)…"
log stream --style compact --level debug \
	--predicate 'eventMessage CONTAINS "RTL8188EUHello"' 2>/dev/null
