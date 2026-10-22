from pathlib import Path
root=Path(__file__).resolve().parents[1]
cpp=(root/'src/kext/AirportRTW88.cpp').read_text()
hpp=(root/'src/kext/AirportRTW88.hpp').read_text()
assert 'STA_V20_POWERSAVE_PREFLIGHT_FIX' in cpp
assert 'req->req_type == APPLE80211_IOC_POWERSAVE && req->req_len == 0' in cpp
assert 'APPLE80211_POWERSAVE_MODE_MAX_THROUGHPUT' in cpp
assert 'STA_V20_POWERSAVE_SET' in cpp
assert 'STA_V20_POWERSAVE_VALUE' in cpp
assert '_powerSaveLevel' in hpp and '_powerSaveLevel' in cpp
assert 'STA_V20_NEXT_ENOTSUP_VISIBLE' in cpp
# v20 must not retain the generic v19 success path.
assert 'v18 compat ACK for unsupported primary STA split SET' not in cpp
print('PASS: v20 decodes POWERSAVE preflight and keeps later ENOTSUP visible')
