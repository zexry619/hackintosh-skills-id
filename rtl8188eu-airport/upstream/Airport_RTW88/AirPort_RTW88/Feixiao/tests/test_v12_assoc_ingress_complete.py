# Superseded by v13 native IO80211FamilyLegacy dispatch.
from pathlib import Path
r=Path(__file__).resolve().parents[1]
a=(r/'src/kext/AirportRTW88.cpp').read_text(); h=(r/'src/kext/AirportRTW88.hpp').read_text()
for bad in ['bridgeLegacyDirectSet','bridgeLegacySplitSet','STA_SPLIT_DIRECT_SET']:
    assert bad not in a+h
assert 'NATIVE_ASSOCIATE_SEEN' in a
print('PASS: v12 opaque split interception removed')
