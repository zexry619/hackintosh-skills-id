from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'src/kext/AirportRTW88.cpp').read_text()
fn=s[s.index('SInt32 AirportRTW88::apple80211_ioctl(IO80211Interface'):s.index('/* Native IO80211 request payloads;')]
assert 'manualScanSet' in fn and 'manualScanGet' in fn
assert 'super::apple80211_ioctl(interface, virtualInterface, net, cmd, data)' in fn
assert 'bridgeLegacySplitSet' not in fn and 'bridgeLegacyDirectSet' not in fn
print('PASS: legacy ioctl bridge is scan-only; family owns association')
