# Superseded by v13: never infer selector from opaque split-set void*.
from pathlib import Path
r=Path(__file__).resolve().parents[1]
a=(r/'src/kext/AirportRTW88.cpp').read_text()
assert 'rtw88LooksLikeDirectAssocPayload' not in a
assert 'bridgeLegacyDirectSet' not in a
print('PASS: obsolete v11 direct-payload guessing removed')
