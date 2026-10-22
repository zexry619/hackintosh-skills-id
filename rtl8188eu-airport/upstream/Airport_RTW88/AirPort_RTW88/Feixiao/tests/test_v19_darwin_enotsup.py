from pathlib import Path
p = Path(__file__).resolve().parents[1] / 'src/kext/AirportRTW88.cpp'
s = p.read_text()
assert 'static constexpr SInt32 kRTW88DarwinENOTSUP = 45;' in s
assert 'sr == kRTW88DarwinENOTSUP' in s
assert 'sr == ENOTSUP' not in s
assert 'STA_V19_DARWIN_ENOTSUP_FIX' in s
assert 'STA_V19_SPLIT_ENOTSUP_ACK' in s
print('PASS: v19 uses Darwin ENOTSUP=45 instead of Linux compat ENOTSUP')
