from pathlib import Path
root = Path(__file__).resolve().parents[1]
cpp = (root/'src/kext/AirportRTW88.cpp').read_text()
hpp = (root/'src/kext/AirportRTW88.hpp').read_text()
iface = (root/'src/kext/AirportRTW88Interface.cpp').read_text()
checks = {
    'AirportItlwm vendor identity': 'newVendorString() const { return OSString::withCString("Apple"); }' in cpp,
    'medium helper declared': 'createMediumTables(const IONetworkMedium **primary)' in hpp,
    'medium prepared before attach': cpp.index('medium table ready before attachInterface') < cpp.index('calling attachInterface (AirportItlwm lifecycle, attach=true)'),
    'configureInterface delegates to super': 'bool ok = super::configureInterface(iface);' in cpp,
    'no test5 userclient override': 'Sonoma newUserClient retry' not in iface,
    'no unsafe size rewrite': '1228->1164' not in cpp and 'len=1228' not in cpp,
}
for name, ok in checks.items():
    assert ok, name
    print('PASS:', name)
