# Superseded by v13: experimental split ingress must stay removed.
from pathlib import Path
r=Path(__file__).resolve().parents[1]
a=(r/'src/kext/AirportRTW88.cpp').read_text(); h=(r/'src/kext/AirportRTW88.hpp').read_text()
assert 'bridgeLegacySplitSet' not in a+h
assert 'apple80211_ioctl_set(IO80211Interface' not in a+h
print('PASS: obsolete v10 split ingress removed')
