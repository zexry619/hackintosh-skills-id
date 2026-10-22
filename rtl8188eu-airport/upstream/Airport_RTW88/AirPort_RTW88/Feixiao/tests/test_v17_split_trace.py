from pathlib import Path
r=Path(__file__).resolve().parents[1]
s=(r/'src/kext/AirportRTW88.cpp').read_text()
assert 'RTW88SplitTraceSnapshot' in s
assert 'rtw88CaptureSplitTrace(data, &splitPre);' in s
assert 'if (sr == kRTW88DarwinENOTSUP)' in s
assert 'rtw88PublishSplitTrace(this, splitPre, 1U, sr);' in s
assert 'rtw88PublishSplitTrace(this, splitPre, 2U, sr);' in s
assert 'STA_V17_TRACE%u_%s' in s
assert 'REQ_TYPE' in s and 'REQ_LEN' in s and 'RAW0' in s
print('PASS: v17 split trace is pre-super and observation-only')
