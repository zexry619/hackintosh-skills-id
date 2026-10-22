#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
core = root.parent / 'rtw88-stable' / 'drivers/net/wireless/realtek/rtw88'
compat = (root/'src/compat/rtw88_compat.c').read_text()
main = (core/'main.c').read_text()
airport = (root/'src/kext/AirportRTW88.cpp').read_text()
mgr = (root/'src/kext/RTW88AWDLManager.cpp').read_text()

rx_fn = compat[compat.index('void ieee80211_rx_irqsafe'):compat.index('void ieee80211_rx_napi')]
checks = [
    ('v56+ build tag', '1.0.3-v56-awdl-fcs-normalization' in airport or '1.0.3-v57-awdl-social-sweep' in airport or '2.0.0-hibernate-recovery' in airport or '2.0.0-awdl-itlwm-bridge' in airport or ('2.0.0-awdl-peer-ipv6' in airport or ('2.0.0-awdl-peer-lifecycle' in airport or '2.0.0-awdl-output-queues' in airport))),
    ('rtw88 advertises RX_INCLUDES_FCS', 'ieee80211_hw_set(hw, RX_INCLUDES_FCS);' in main),
    ('compat emulates mac80211 FCS removal', 'ieee80211_hw_check(hw, RX_INCLUDES_FCS)' in rx_fn and 'skb_trim(skb, skb->len - 4);' in rx_fn),
    ('FCS removed before kext callback', rx_fn.find('skb_trim(skb, skb->len - 4);') < rx_fn.find('g_hw_cbs->rx_frame(ctx, skb)')),
    ('short skb guarded before trim', 'skb->len >= 4' in rx_fn),
    ('normal schedule skip is not channel busy', '_lastChannelResult = kIOReturnSuccess;' in mgr and '_lastChannelResult = kIOReturnBusy;' not in mgr[mgr.index('if (offChannelWanted && !inCommonWindow)'):mgr.index('// A channel hop may cross')]),
    ('window skips exported separately', 'AWDL_WINDOW_SKIPS' in mgr),
    ('blocked windows only count intended windows', 'if (inCommonWindow) ++_blockedWindows;' in mgr),
]

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(('PASS' if ok else 'FAIL') + ': ' + name)
if failed:
    raise SystemExit(f'{len(failed)} v56 invariant(s) failed: ' + ', '.join(failed))
print(f'PASS: all {len(checks)} v56 FCS/AWDL diagnostics invariants present')
