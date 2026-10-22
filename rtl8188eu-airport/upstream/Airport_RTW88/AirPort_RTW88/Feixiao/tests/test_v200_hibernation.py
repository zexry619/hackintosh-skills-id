#!/usr/bin/env python3
from pathlib import Path
root = Path(__file__).resolve().parents[1]
a = (root/'src/kext/AirportRTW88.cpp').read_text()
h = (root/'src/kext/AirportRTW88.hpp').read_text()
i = (root/'src/kext/RTW88IEEE80211.cpp').read_text()
m = (root/'src/kext/RTW88AWDLManager.cpp').read_text()
plist = (root/'AirPort_RTW88.kext/Contents/Info.plist').read_text()
kmod = (root/'src/kext/kmod_info.c').read_text()
checks = [
 ('2.0.0 driver tag', ('2.0.0-hibernate-recovery' in a or ('2.0.0-awdl-itlwm-bridge' in a or '2.0.0-awdl-channel-report' in a or ('2.0.0-awdl-peer-ipv6' in a or '2.0.0-awdl-peer-lifecycle' in a)))),
 ('2.0.0 bundle version', plist.count('<string>2.0.0</string>') >= 2),
 ('2.0.0 kmod version', '"2.0.0"' in kmod),
 ('IONetwork PM registration', 'registerWithPolicyMaker' in a and 'registerPowerDriver' in a),
 ('two explicit PM states', 'kRTW88PowerStateOff' in a and 'kRTW88PowerStateOn' in a),
 ('sleep stops AWDL first', a.find('suspendForPowerTransition()') < a.find('suspendForSystemSleep()')),
 ('sleep powers core off before DMA fence', a.find('suspendForSystemSleep()') < a.find('stopDMA()', a.find('quiesceForSystemSleep'))),
 ('wake restores memory and bus master', 'setMemoryEnable(true)' in a and 'setBusMasterEnable(true)' in a),
 ('DMA remains fenced during firmware restore', a.find('cmdPowerOn()') < a.find('__atomic_store_n(&_dmaStopped, false', a.find('restoreAfterSystemWake'))),
 ('interrupt enabled after firmware restore', a.find('cmdPowerOn()') < a.find('_intrSrc->enable()', a.find('restoreAfterSystemWake'))),
 ('hibernate never resurrects association', 'association is intentionally not resurrected' in a),
 ('scan worker cancelled for system sleep', 'thread_call_cancel_wait(_manualScanTC)' in i and 'suspendForSystemSleep' in i),
 ('AWDL suspend/resume retains manager', 'RTW88AWDLManager::suspendForPowerTransition' in m and 'RTW88AWDLManager::resumeAfterPowerTransition' in m),
 ('Wi-Fi-off wake does not restart AWDL', 'if (_awdlManager && _pmRadioWasPowered)' in a),
 ('TX stalls during PM transition', '_pmTransition' in a and 'kIOReturnOutputStall' in a),
 ('PM telemetry exported', 'PM_LAST_SLEEP_RESULT' in a and 'PM_LAST_WAKE_RESULT' in a and 'PM_SLEEP_COUNT' in a),
]
failed=[]
for name, ok in checks:
    print(('PASS' if ok else 'FAIL') + ': ' + name)
    if not ok: failed.append(name)
if failed:
    raise SystemExit(1)
print(f'PASS: {len(checks)}/{len(checks)} hibernation checks')
