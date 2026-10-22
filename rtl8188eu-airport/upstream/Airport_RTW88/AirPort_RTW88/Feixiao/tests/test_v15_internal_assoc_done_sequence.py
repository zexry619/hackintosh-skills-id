from pathlib import Path
root=Path(__file__).resolve().parents[1]
a=(root/'src/kext/AirportRTW88.cpp').read_text()
h=(root/'src/kext/AirportRTW88.hpp').read_text()
r=(root/'src/kext/RTW88IEEE80211.cpp').read_text()
assert '_assocDoneReported = false;' in h
assert 'STA_ASSOC_DONE_AT_LINK_UP' in a
assert '_netif->postMessage(APPLE80211_M_ASSOC_DONE);' in a
assert 'if (_externalSupplicant && _delegate)' in r
assert 'cmdConnect(ssid, nullptr, pmk, bssid, false)' in a
print('PASS: internal RSN ASSOC_DONE sequencing restored')
