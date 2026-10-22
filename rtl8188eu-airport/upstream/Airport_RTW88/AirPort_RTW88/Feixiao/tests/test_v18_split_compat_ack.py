from pathlib import Path
p = Path(__file__).resolve().parents[1] / 'src/kext/AirportRTW88.cpp'
s = p.read_text()
start = s.index('SInt32 AirportRTW88::apple80211_ioctl_set(IO80211Interface *interface,')
end = s.index('SInt32 AirportRTW88::apple80211_ioctl_set(IO80211SkywalkInterface *skywalkInterface,', start)
fn = s[start:end]
assert 'sr == ENOTSUP && interface && interface == _netif && !virtualInterface' in fn
assert 'STA_V18_SPLIT_ENOTSUP_ACK' in fn
assert 'return 0;' in fn
assert 'rtw88AssocPayloadLooksValid' in fn
assert 'rtw88TryAssocFromSplitWrapper' in fn
# The skywalk-only overload must NOT gain the blanket compatibility ACK.
sky_start = end
sky_end = s.index('#endif', sky_start)
sky = s[sky_start:sky_end]
assert 'STA_V18_SPLIT_ENOTSUP_ACK' not in sky
print('PASS: v18 primary-STA split ENOTSUP compatibility ACK is isolated')
