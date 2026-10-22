from pathlib import Path
r=Path(__file__).resolve().parents[1]
s=(r/'src/kext/AirportRTW88.cpp').read_text(); h=(r/'src/kext/AirportRTW88.hpp').read_text()
assert 'apple80211Request(unsigned int request_type' in s
assert 'apple80211_ioctl_set(IO80211Interface' not in s+h
assert 'apple80211SkywalkRequest(UInt request_type' not in s+h
# Restored-stack shim is the v14 known-good BSD Apple80211 transport.
assert 'SInt32 AirportRTW88::apple80211_ioctl(IO80211Interface *interface' in s
assert 'req->req_type == APPLE80211_IOC_SCAN_RESULT' in s
assert 'copyin((user_addr_t)req->req_data, payload, len)' in s
assert 'apple80211Request(cmd, req->req_type, interface, payload)' in s
# The proven RTL8822BE WPA2 path keeps RSN/EAPOL inside rtw88.
assert 'useAppleRSNSupplicant(IO80211Interface *) override { return false; }' in h
print('PASS: Ventura Legacy/restored-stack transport + internal RSN alignment')
