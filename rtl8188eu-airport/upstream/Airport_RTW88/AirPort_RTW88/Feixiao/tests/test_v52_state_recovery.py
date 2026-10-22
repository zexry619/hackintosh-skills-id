from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ieee = (ROOT / 'src/kext/RTW88IEEE80211.cpp').read_text()
ctrl = (ROOT / 'src/kext/AirportRTW88.cpp').read_text()

checks = {
    'CURRENT_NETWORK uses persistent RUN latch':
        'if (!_powered || !_associatedVisible)' in ieee,
    'network switch drains connected background scan':
        '_scanReturnState == RTW88_STATE_CONNECTED' in ieee and
        'abortActiveScan(true)' in ieee[ieee.index('IOReturn RTW88IEEE80211::cmdDisconnect()'):ieee.index('IOReturn RTW88IEEE80211::cmdPowerOn()')],
    'Wi-Fi disable performs full radio teardown':
        '_ieee80211->cmdPowerOff()' in ctrl[ctrl.index('IOReturn AirportRTW88::disable'):ctrl.index('IOReturn AirportRTW88::getPacketFilters')],
    'BSD ioctl wrapper is snapshotted':
        'const uint32_t reqType = req->req_type;' in ctrl and
        'const user_addr_t reqData = (user_addr_t)req->req_data;' in ctrl,
    'opaque split ingress no longer blindly copies 40 bytes':
        '(void)data;' in ctrl[ctrl.index('static void rtw88CaptureSplitTrace'):ctrl.index('static void rtw88PublishSplitTrace')]
        and 'memcpy(out->words, data, sizeof(out->words))' not in ctrl,
    'build tag updated': '1.0.3-v52-state-recovery' in ctrl,
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ': ' + name)
if failed:
    raise SystemExit('v52 static regression failures: ' + ', '.join(failed))
