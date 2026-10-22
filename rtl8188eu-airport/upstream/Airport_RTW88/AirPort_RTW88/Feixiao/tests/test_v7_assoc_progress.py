from pathlib import Path
root = Path(__file__).resolve().parents[1]
air = (root/'src/kext/AirportRTW88.cpp').read_text()
rtw = (root/'src/kext/RTW88IEEE80211.cpp').read_text()
checks = {
    'explicit assoc RSN length ABI used': 'uint16_t rsnLen = d->pad;' in air,
    'assoc RSN drives backend security': 'rtw88RsnSelectCcmpPsk(_assocRsnIE + 2' in rtw,
    'scan metadata is not sole WPA2 authority': 'requested protected BSS is not CCMP-PSK' in rtw,
    'BSD link raised for Apple EAPOL': 'normal BSD Ethernet' in rtw and 'kIONetworkLinkActive | kIONetworkLinkValid' in rtw,
    'non-EAPOL blocked before external keys': '!externalKeysReady()' in rtw and '!= ETH_P_PAE' in rtw,
    'ASSOC_DONE still posted': 'kRTW88EventAssocDone' in rtw and 'APPLE80211_M_ASSOC_DONE' in air,
    'PTK event posted': 'APPLE_RSN_PTK_EVENT' in air,
    'GTK event posted': 'APPLE_RSN_GTK_EVENT' in air,
}
failed=[k for k,v in checks.items() if not v]
for k,v in checks.items(): print(('PASS' if v else 'FAIL')+': '+k)
if failed: raise SystemExit('v7 association checks failed: '+', '.join(failed))
