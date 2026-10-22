from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'src/kext/AirportRTW88.cpp').read_text()
fn=s[s.index('SInt32 AirportRTW88::apple80211_ioctl(IO80211Interface'):s.index('/* Native IO80211 request payloads;')]
assert 'manualScanSet' in fn
assert 'APPLE80211_IOC_SCAN_REQ' in fn and 'APPLE80211_IOC_SCAN_REQ_MULTIPLE' in fn
assert 'copyin' in fn and 'apple80211Request(cmd, req->req_type, interface, payload)' in fn
print('PASS: restored-stack scan request bridge preserved')
