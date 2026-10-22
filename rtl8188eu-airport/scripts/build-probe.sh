#!/bin/bash
# Build alat uji user-space (tidak menyentuh kernel sama sekali).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 - <<'PY'
# firmware array harus kompilasi sebagai C untuk probe
import io, re
src = io.open('src/urtwn/firmware_rtl8188eufw.cpp', encoding='utf-8').read()
src = src.replace('#include "rtwn_m1.h"', '')
src = src.replace('extern const unsigned char rtl8188eufw_bin[];\nextern const unsigned int rtl8188eufw_bin_len;\n', '')
io.open('/tmp/fw_as_c.c', 'w', encoding='utf-8').write(src)
PY

clang -O2 -o tools/rtwn_probe \
	tools/rtwn_probe.c src/urtwn/rtwn_seq.c src/urtwn/rtwn_seq_efuse.c src/urtwn/rtwn_flow.c src/urtwn/rtwn_efuse_8188e.c src/urtwn/rtwn_usb.c src/urtwn/rtwn_init_8188e.c src/urtwn/rtwn_chan.c src/urtwn/rtwn_80211.c /tmp/fw_as_c.c \
	-Isrc/urtwn \
	-framework IOKit -framework CoreFoundation
echo "[probe] OK → tools/rtwn_probe"
