from pathlib import Path
r=Path(__file__).resolve().parents[1]
a=(r/'src/kext/AirportRTW88.cpp').read_text()
h=(r/'src/kext/AirportRTW88.hpp').read_text()
i=(r/'src/kext/RTW88IEEE80211.cpp').read_text()
ih=(r/'src/kext/RTW88IEEE80211.hpp').read_text()
assert 'setHardwareAddress(const IOEthernetAddress *addr) override' in h
assert 'AirportRTW88::setHardwareAddress' in a
assert '_ieee80211->setMACAddress(addr->bytes)' in a
assert 'setMACAddress(const uint8_t *mac)' in ih
assert 'RTW88IEEE80211::setMACAddress' in i
c=(r/'src/compat/rtw88_compat.c').read_text()
assert 'rtw88_set_station_mac(_hw, _vif, mac)' in i
assert 'rtw_vif_port_config(rtwdev, rtwvif, PORT_SET_MAC_ADDR)' in c
assert 'ASSOCIATE enter version=' in a
assert '1228->1164' not in a
print('private-MAC association gate static checks: OK')
