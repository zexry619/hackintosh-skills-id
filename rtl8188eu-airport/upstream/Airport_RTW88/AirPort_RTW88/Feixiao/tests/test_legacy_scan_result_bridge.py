from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'src/kext/AirportRTW88.cpp').read_text()
fn=s[s.index('SInt32 AirportRTW88::apple80211_ioctl(IO80211Interface'):s.index('/* Native IO80211 request payloads;')]
assert 'manualScanGet' in fn and 'APPLE80211_IOC_SCAN_RESULT' in fn
assert 'struct apple80211_scan_result *result = nullptr' in fn
assert 'copyout' in fn
print('PASS: restored-stack SCAN_RESULT bridge preserved')
