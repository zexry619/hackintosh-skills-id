"""Static contract checks for v8 association RUN visibility."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
air = (root / 'src/kext/AirportRTW88.cpp').read_text()
rtw = (root / 'src/kext/RTW88IEEE80211.cpp').read_text()
hdr = (root / 'src/kext/RTW88IEEE80211.hpp').read_text()
checks = {
    'persistent associated-visible latch exists': '_associatedVisible = false;' in hdr,
    'assoc response publishes visible RUN': '_associatedVisible = true;' in rtw and 'associated! AID=' in rtw,
    'state query reports RUN from latch': 'reportedState = _associatedVisible ? RTW88_STATE_CONNECTED : _state' in rtw,
    'explicit disconnect clears visible RUN': 'Explicit disassociation ends the IO80211 RUN latch immediately.' in rtw,
    'AP deauth clears visible RUN': 'rtw88Event(kRTW88EventDeauth' in rtw and '_associatedVisible = false;' in rtw,
    'external keys require associated-visible state': '!_associatedVisible' in rtw and 'cmdInstallExternalKey' in rtw,
    'join-time disassociate does not cancel auth/assoc': 'STA_DISASSOC_IGNORED_DURING_JOIN' in air,
    'assoc-done has sticky diagnostics': 'STA_ASSOC_DONE_EVENT' in air and 'STA_ASSOC_DONE_RAW_STATE' in air,
    'SSID GET records raw/effective state': 'STA_LAST_RAW_STATE' in air and 'STA_LAST_REPORTED_STATE' in air,
}
failed=[]
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ': ' + name)
    if not ok: failed.append(name)
if failed:
    raise SystemExit('v8 association visibility checks failed: ' + ', '.join(failed))
