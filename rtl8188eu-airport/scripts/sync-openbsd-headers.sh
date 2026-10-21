#!/bin/bash
# Refresh header register Realtek dari OpenBSD (ISC) ke src/urtwn/.
#
# Padding yang diterapkan agar bisa dipakai di kernel Darwin:
#   __packed           -> __attribute__((packed))
#   IEEE80211_ADDR_LEN -> didefinisikan lokal
#   nitems()           -> didefinisikan lokal (OpenBSD punya di sys/param.h)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/upstream/openbsd/sys/dev/ic/r92creg.h"
DST="$ROOT/src/urtwn/r92creg.h"

if [[ ! -s "$SRC" ]]; then
	echo "[sync] $SRC belum ada — jalankan ./scripts/fetch-upstream.sh" >&2
	exit 1
fi

python3 - "$SRC" "$DST" <<'PY'
import io, sys
src, dst = sys.argv[1], sys.argv[2]
s = io.open(src, encoding='utf-8', errors='replace').read()
s = s.replace('__packed', '__attribute__((packed))')

banner = """/*
 * r92creg.h - salinan dari OpenBSD sys/dev/ic/r92creg.h (ISC).
 *
 * Padding untuk dipakai di kernel Darwin:
 *   - __packed            -> __attribute__((packed))
 *   - IEEE80211_ADDR_LEN  -> didefinisikan di sini
 *   - nitems()            -> didefinisikan di sini
 *   - header <sys/...>    -> tidak ada; file ini hanya berisi #define + struct
 *
 * Refresh: ./scripts/sync-openbsd-headers.sh
 */

#ifndef IEEE80211_ADDR_LEN
#define IEEE80211_ADDR_LEN 6
#endif

#ifndef nitems
#define nitems(x) (sizeof(x) / sizeof((x)[0]))
#endif

"""

idx = s.find('#define R92C_MAX_CHAINS')
s = s[:idx] + banner + s[idx:]
io.open(dst, 'w', encoding='utf-8').write(s)
print('[sync] %s -> %s' % (src, dst))
PY
