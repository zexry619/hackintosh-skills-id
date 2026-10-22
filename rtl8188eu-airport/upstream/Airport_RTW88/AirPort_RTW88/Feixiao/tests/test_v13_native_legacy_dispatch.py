from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
cpp = (ROOT/'src/kext/AirportRTW88.cpp').read_text()
hpp = (ROOT/'src/kext/AirportRTW88.hpp').read_text()

# Keep speculative split/Skywalk overrides out of the controller.  The restored
# stack uses the known-good v14 BSD shim plus the normal apple80211Request selector dispatcher.
assert 'apple80211Request(unsigned int request_type' in cpp
assert 'apple80211_ioctl_set(IO80211Interface' not in cpp
assert 'apple80211_ioctl_set(IO80211SkywalkInterface' not in cpp
assert 'apple80211SkywalkRequest(UInt request_type' not in cpp
assert 'bridgeLegacyDirectSet' not in cpp
assert 'bridgeLegacySplitSet' not in cpp
assert 'apple80211_ioctl_set(IO80211Interface' not in hpp
assert 'apple80211SkywalkRequest(UInt request_type' not in hpp

fn = cpp[cpp.index('SInt32 AirportRTW88::apple80211_ioctl(IO80211Interface'):cpp.index('/* Native IO80211 request payloads;')]
assert 'APPLE80211_IOC_SCAN_RESULT' in fn
assert 'copyin((user_addr_t)req->req_data, payload, len)' in fn
assert 'apple80211Request(cmd, req->req_type, interface, payload)' in fn
assert 'TEST9_SEEN_SET_ASSOCIATE' in fn

# Selector 20 stays in the normal Ventura dispatcher when CoreWiFi submits it.
assert 'case APPLE80211_IOC_ASSOCIATE:' in cpp
assert 'handleASSOCIATE((struct apple80211_assoc_data *)data)' in cpp
assert 'NATIVE_ASSOCIATE_SEEN' in cpp
print('PASS: restored-stack BSD transport + Ventura selector dispatcher')
