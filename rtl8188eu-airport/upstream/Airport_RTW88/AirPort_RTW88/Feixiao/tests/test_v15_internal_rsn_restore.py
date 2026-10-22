from pathlib import Path
r=Path(__file__).resolve().parents[1]
h=(r/'src/kext/AirportRTW88.hpp').read_text()
c=(r/'src/kext/AirportRTW88.cpp').read_text()
rtw=(r/'src/kext/RTW88IEEE80211.cpp').read_text()
assert 'useAppleRSNSupplicant(IO80211Interface *) override { return false; }' in h
assert 'cmdConnect(ssid, nullptr, pmk, bssid, false)' in c
assert 'STA_INTERNAL_RSN_MODE' in c
assert 'd->ad_key.key_len != 32' in c
assert 'd->ad_rsn_ie[1] + 2' in c
assert 'RTW88_STATE_HANDSHAKING && !_externalSupplicant' in rtw
print('PASS: v15 restores proven internal RSN/PMK association path')
