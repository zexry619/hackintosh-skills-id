"""Static contract checks for the Ventura association -> Apple RSN event flow."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
air = (root / 'src/kext/AirportRTW88.cpp').read_text()
rtw = (root / 'src/kext/RTW88IEEE80211.cpp').read_text()
hdr = (root / 'src/kext/RTW88IEEE80211.hpp').read_text()

checks = {
    'backend emits association completion':
        '_delegate->rtw88Event(kRTW88EventAssocDone, nullptr);' in rtw,
    'frontend translates assoc completion to IO80211':
        'case kRTW88EventAssocDone:' in air and '_netif->postMessage(APPLE80211_M_ASSOC_DONE);' in air,
    'backend emits deauth notification':
        'rtw88Event(kRTW88EventDeauth' in rtw,
    'frontend translates deauth notification':
        'APPLE80211_M_DEAUTH_RECEIVED' in air,
    'Apple RSN association exposes BSD link for EAPOL':
        'setLinkStatus(kIONetworkLinkActive | kIONetworkLinkValid)' in rtw and
        'normal BSD Ethernet' in rtw,
    'PTK and GTK are tracked separately':
        '_externalPTKInstalled = true;' in rtw and '_externalGTKInstalled = true;' in rtw,
    'protected data remains gated until both external keys':
        '!externalKeysReady()' in rtw and 'ETH_P_PAE' in rtw and
        '_externalPTKInstalled && _externalGTKInstalled' in rtw,
    'frontend mirrors AirportItlwm RSN event per installed key':
        '_netif->postMessage(APPLE80211_M_RSN_HANDSHAKE_DONE);' in air and
        'APPLE_RSN_PTK_EVENT' in air and 'APPLE_RSN_GTK_EVENT' in air,
    'repeated asynchronous association is coalesced':
        'ASSOCIATE_COALESCED' in air and
        'RTW88_STATE_AUTHENTICATING' in air and
        'RTW88_STATE_ASSOCIATING' in air and
        'RTW88_STATE_HANDSHAKING' in air,
    'backend event enum contains assoc done':
        'kRTW88EventAssocDone' in hdr,
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ': ' + name)
if failed:
    raise SystemExit('association event-flow checks failed: ' + ', '.join(failed))
