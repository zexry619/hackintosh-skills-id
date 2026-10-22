from pathlib import Path
root = Path(__file__).resolve().parents[1]
air_h = (root/'src/kext/AirportRTW88.hpp').read_text()
air_c = (root/'src/kext/AirportRTW88.cpp').read_text()
iface = (root/'src/kext/AirportRTW88Interface.cpp').read_text()
rtw = (root/'src/kext/RTW88IEEE80211.cpp').read_text()

# IO80211 presentation stays aligned with AirportItlwm/Ventura, but the
# RTL8822BE-proven WPA2 path intentionally keeps RSN/EAPOL inside rtw88.
checks = {
    'internal RSN restored for proven RTL8822BE path':
        'useAppleRSNSupplicant(IO80211Interface *) override { return false; }' in air_h,
    'Ventura EAPOL IO80211 presentation path retained':
        'ethertype == 0x888E' in iface and 'IO80211Interface::inputPacket' in iface,
    'SSID set benign': 'if (set) return kIOReturnSuccess; // AirportItlwm accepts this' in air_c,
    'BSSID set benign': 'if (isSet) return kIOReturnSuccess;' in air_c,
    'scan multiple accepted': 'case APPLE80211_IOC_SCAN_REQ_MULTIPLE:' in air_c,
    'scan cache clear accepted': 'case APPLE80211_IOC_SCANCACHE_CLEAR:' in air_c,
    'Ventura scan flags simplified': 'APPLE80211_C_FLAG_ACTIVE |\n                           APPLE80211_C_FLAG_20MHZ' in air_c,
    'scan exposes RSN TLV': 'if (b.ies[pos] == 48) { /* RSN TLV */' in air_c,
    'association derives Ventura RSN TLV length': 'd->ad_rsn_ie[1] + 2' in air_c,
    'association requires 32-byte PMK and uses internal backend':
        'd->ad_key.key_len != 32' in air_c and
        'cmdConnect(ssid, nullptr, pmk, bssid, false)' in air_c,
    'disconnected SSID returns ENXIO': 'if (st.state != RTW88_STATE_CONNECTED) return 6;' in air_c,
    'country code implemented': 'case APPLE80211_IOC_COUNTRY_CODE:' in air_c,
    'locale implemented': 'case APPLE80211_IOC_LOCALE:' in air_c,
    'internal EAPOL four-way handshake active':
        'RTW88_STATE_HANDSHAKING && !_externalSupplicant' in rtw,
    'internal WPA2 waits for EAPOL M1':
        'rtw88: WPA2 — waiting for EAPOL M1' in rtw,
    'internal handshake raises link after keys':
        'rtw88: WPA2 connected!' in rtw and
        '_parent->setLinkStatus(kIONetworkLinkActive | kIONetworkLinkValid)' in rtw,
    'ASSOC_DONE for internal path occurs at usable link':
        'STA_ASSOC_DONE_AT_LINK_UP' in air_c and
        'if (_externalSupplicant && _delegate)' in rtw,
    'external key path remains available but dormant': 'cmdInstallExternalKey' in air_c,
}
failed=[k for k,v in checks.items() if not v]
for k,v in checks.items(): print(('PASS' if v else 'FAIL')+': '+k)
if failed: raise SystemExit('alignment checks failed: '+', '.join(failed))
