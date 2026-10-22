from pathlib import Path
p = Path(__file__).resolve().parents[1] / 'src/kext/AirportRTW88.cpp'
s = p.read_text()
assert 'attachVirtualInterface(&created, &addr, APPLE80211_VIF_AWDL, true)' in s
assert 'SInt32 enableRet = enableVirtualInterface(created);' in s
assert 'proactive AWDL enable result=0x%x' in s
assert 'if (enableRet != kIOReturnSuccess)' in s
print('PASS: proactive AWDL attach is followed by explicit controller enable')
