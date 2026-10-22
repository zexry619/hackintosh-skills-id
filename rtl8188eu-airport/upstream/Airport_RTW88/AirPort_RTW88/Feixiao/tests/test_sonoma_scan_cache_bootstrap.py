from pathlib import Path
root=Path(__file__).resolve().parents[1]
cpp=(root/'src/kext/AirportRTW88.cpp').read_text()
hpp=(root/'src/kext/AirportRTW88.hpp').read_text()
assert '_scanCacheBootstrapAttempted' in hpp
assert '_sawExplicitScanRequest' not in hpp
assert 'version_major >= 23' in cpp
assert 'Sonoma cache-only SCAN_RESULT triggered bootstrap scan' in cpp
assert '_scanInProgress = true' in cpp
assert '_ieee80211->cmdScan()' in cpp
assert 'return kIOReturnBusy' in cpp
assert 'handleSCAN_RESULT((struct apple80211_scan_result **)data)' in cpp
print('restored-stack scan-cache bootstrap contract: OK')
