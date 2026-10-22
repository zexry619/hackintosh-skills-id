"""Static Apple RSN / Ventura IO80211 contract checks."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
air_h=(root/'src/kext/AirportRTW88.hpp').read_text()
air_c=(root/'src/kext/AirportRTW88.cpp').read_text()
iface=(root/'src/kext/AirportRTW88Interface.cpp').read_text()
rtw=(root/'src/kext/RTW88IEEE80211.cpp').read_text()
mk=(root/'Makefile').read_text()
checks={
 'Apple RSN enabled': 'useAppleRSNSupplicant(IO80211Interface *) override { return true; }' in air_h,
 'Ventura target enables Apple supplicant': '-DUSE_APPLE_SUPPLICANT=1' in mk and '-D__IO80211_TARGET=__MAC_13_0' in mk,
 'EAPOL gets IO80211 receive path': 'ethertype == 0x888E' in iface and 'IO80211Interface::inputPacket' in iface,
 'ASSOCIATE selector handled': 'case APPLE80211_IOC_ASSOCIATE:' in air_c,
 'RSN_IE selector handled': 'case APPLE80211_IOC_RSN_IE:' in air_c,
 'CIPHER_KEY selector handled': 'case APPLE80211_IOC_CIPHER_KEY:' in air_c,
 'RSN length honors AirportItlwm ABI field': 'uint16_t rsnLen = d->pad;' in air_c and 'd->ad_rsn_ie[1] + 2' in air_c,
 'ASSOCIATE preserves PMK but selects Apple external EAPOL': 'cmdConnect(ssid, nullptr, pmk, bssid, secure)' in air_c,
 'External key install present': 'cmdInstallExternalKey' in air_c,
 'PTK+GTK gate protected data': '_externalPTKInstalled && _externalGTKInstalled' in rtw and '!externalKeysReady()' in rtw,
 'RSN completion event mirrors AirportItlwm per key': 'APPLE_RSN_PTK_EVENT' in air_c and 'APPLE_RSN_GTK_EVENT' in air_c,
}
failed=[name for name,ok in checks.items() if not ok]
for name,ok in checks.items(): print(('PASS' if ok else 'FAIL')+': '+name)
if failed: raise SystemExit('missing contract pieces: '+', '.join(failed))
