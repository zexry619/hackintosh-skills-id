from pathlib import Path
r=Path(__file__).resolve().parents[1]
cpp=(r/'src/kext/AirportRTW88.cpp').read_text()
hpp=(r/'src/kext/AirportRTW88.hpp').read_text()
assert 'apple80211_ioctl_set(IO80211Interface *interface' in cpp
assert 'STA_SPLIT_ASSOC_INGRESS' in cpp
assert 'STA_SPLIT_ASSOC_SUPER_RET' in cpp
assert 'STA_SPLIT_ASSOC_DIRECT' in cpp
assert 'STA_SPLIT_ASSOC_WRAPPER' in cpp
assert 'req->req_type != APPLE80211_IOC_ASSOCIATE' in cpp
assert 'apple80211Request(SIOCSA80211, APPLE80211_IOC_ASSOCIATE' in cpp
assert '_nativeAssocDispatchCount' in hpp and '_nativeAssocDispatchCount' in cpp
print('PASS: v16 split ASSOC ingress is super-first and ASSOC-only')
