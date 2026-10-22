#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
files = {
    'ieee_h': (root/'src/kext/RTW88IEEE80211.hpp').read_text(),
    'ieee': (root/'src/kext/RTW88IEEE80211.cpp').read_text(),
    'mgr': (root/'src/kext/RTW88AWDLManager.cpp').read_text(),
    'airport': (root/'src/kext/AirportRTW88.cpp').read_text(),
    'awdl': (root/'src/kext/AirportRTW88AWDL.cpp').read_text(),
    'compat_h': (root/'src/compat/rtw88_compat.h').read_text(),
    'compat': (root/'src/compat/rtw88_compat.c').read_text(),
}

checks = [
    ('v54+ build tag', '1.0.3-v54-awdl-timeslice' in files['airport'] or '1.0.3-v55-openawdl-schedule' in files['airport'] or '1.0.3-v56-awdl-fcs-normalization' in files['airport'] or '1.0.3-v57-awdl-social-sweep' in files['airport'] or '2.0.0-hibernate-recovery' in files['airport'] or '2.0.0-awdl-itlwm-bridge' in files['airport'] or ('2.0.0-awdl-peer-ipv6' in files['airport'] or ('2.0.0-awdl-peer-lifecycle' in files['airport'] or '2.0.0-awdl-output-queues' in files['airport']))),
    ('scheduler tag', 'v54-sta-awdl-timeslice' in files['mgr'] or 'v55-openawdl-schedule' in files['mgr'] or 'v56-awdl-fcs-normalization' in files['mgr'] or 'v57-awdl-social-sweep' in files['mgr'] or '2.0.0-awdl-social-sweep' in files['mgr'] or '2.0.0-itlwm-control-openawdl-radio' in files['mgr']),
    ('off-channel ownership latch', '_awdlOffChannel' in files['ieee_h']),
    ('STA PM enter before AWDL hop', 'txNullFunc(true)' in files['ieee']),
    ('STA PM exit after AWDL hop', 'txNullFunc(false)' in files['ieee']),
    ('fast connected AWDL hop helper declared', 'rtw88_awdl_timeslice_switch_channel' in files['compat_h']),
    ('fast connected AWDL hop helper implemented', 'void rtw88_awdl_timeslice_switch_channel' in files['compat']),
    ('home channel restore helper implemented', 'rtw88_restore_connected_hw_timeslice' in files['compat']),
    ('manager gates off-channel to common window', 'inCommonWindow' in files['mgr'] and 'commonUS' in files['mgr']),
    ('manager restores STA outside window', '_backend->restoreSTAChannelAfterAWDL();' in files['mgr']),
    ('en0 stalls while AWDL owns PHY', 'staTxBlockedByAWDL()' in files['airport'] and 'kIOReturnOutputStall' in files['airport']),
    ('en0 resumes after AWDL returns home', 'resumeTxIfStalled()' in files['awdl']),
    ('disconnect restores STA before deauth', files['ieee'].find('if (_awdlOffChannel)\n        restoreSTAChannelAfterAWDL();', files['ieee'].find('void RTW88IEEE80211::doDisconnect')) >= 0),
    ('manager reset restores STA before backend release', files['mgr'].find('restoreSTAChannelAfterAWDL()', files['mgr'].find('void RTW88AWDLManager::reset')) >= 0),
    ('v53 TX backpressure retained', 'kRTW88TxStallAvail' in files['airport'] and 'rtw88_be_tx_avail()' in files['airport']),
]

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(('PASS' if ok else 'FAIL') + ': ' + name)
if failed:
    raise SystemExit(f'{len(failed)} v54 invariant(s) failed')
print(f'PASS: all {len(checks)} v54 AWDL/STA coexistence invariants present')
