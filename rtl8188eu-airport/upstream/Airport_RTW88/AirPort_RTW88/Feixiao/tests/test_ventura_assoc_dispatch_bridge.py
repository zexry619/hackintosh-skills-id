from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'src/kext/AirportRTW88.cpp').read_text()
assert 'NATIVE_ASSOCIATE_SEEN' in s
assert 'TEST9_ASSOCIATE_ENTER' in s
fn=s[s.index('SInt32 AirportRTW88::apple80211_ioctl(IO80211Interface'):s.index('/* Native IO80211 request payloads;')]
assert 'LEGACY_ASSOC_SUPER_ENTER' in fn
assert 'super::apple80211_ioctl(interface, virtualInterface, net, cmd, data)' in fn
print('PASS: Ventura association dispatch is family-native')
