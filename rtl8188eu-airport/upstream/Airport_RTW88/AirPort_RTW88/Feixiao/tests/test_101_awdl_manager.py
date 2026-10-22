from pathlib import Path
r=Path(__file__).resolve().parents[1]
h=(r/'src/kext/RTW88AWDLManager.hpp').read_text()
c=(r/'src/kext/RTW88AWDLManager.cpp').read_text()
a=(r/'src/kext/AirportRTW88AWDL.cpp').read_text()
m=(r/'src/kext/AirportRTW88.cpp').read_text()
mk=(r/'Makefile').read_text()
pl=(r/'AirPort_RTW88.kext/Contents/Info.plist').read_text()
for token in ['syncEnabled','electionMetric','setSyncFrameTemplate','setVirtualInterface','notePeerTrafficRegistration']:
    assert token in h or token in c, token
assert 'RTW88AWDLManager.cpp' in mk
assert '_awdlManager->setVirtualInterface' in a
assert 'APPLE80211_IOC_P2P_ENABLE' in a
assert 'txRawManagementFrame' in a
assert 'RTW88AWDLManager' in m
assert '<key>CFBundleIdentifier</key>' in pl and '<string>com.rtw88.airport</string>' in pl
print('AirPort_RTW88 AWDL manager contract: OK')
