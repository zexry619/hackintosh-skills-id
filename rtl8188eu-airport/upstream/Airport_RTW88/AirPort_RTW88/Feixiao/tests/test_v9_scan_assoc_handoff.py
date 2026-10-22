"""v9: ASSOCIATE must be accepted while a disconnected scan is finishing."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
a = (root/'src/kext/AirportRTW88.cpp').read_text()
r = (root/'src/kext/RTW88IEEE80211.cpp').read_text()
h = (root/'src/kext/RTW88IEEE80211.hpp').read_text()
assert '_deferredConnectPending = false;' in h
assert 'ASSOCIATE deferred until active scan completes' in r
assert '_deferredConnectPending = true;' in r
assert 'scanDone() continues' in r
assert 'deferred ASSOCIATE after scan' in r
assert 'STA_ASSOCIATE_BEFORE_RAW_STATE' in a
assert 'STA_ASSOCIATE_CMD_RET' in a
assert 'STA_ASSOCIATE_AFTER_RAW_STATE' in a
assert 'STA_ASSOCIATE_ACCEPTED' in a
assert 'STA_DISASSOC_ACK_SCAN_ONLY' in a
assert 'DISASSOCIATE acknowledged during disconnected scan (no link teardown)' in r
# Regression guard: cmdConnect must not synchronously fail a SCANNING join via abortActiveScan(true).
start = r.index('IOReturn RTW88IEEE80211::cmdConnect')
end = r.index('void RTW88IEEE80211::connectTCFn', start)
cmd = r[start:end]
assert 'abortActiveScan(true)' not in cmd
assert 'if (_state == RTW88_STATE_SCANNING)' in cmd
assert 'return kIOReturnSuccess;' in cmd
print('PASS: scan->ASSOC handoff is deferred/accepted, not EBUSY')
