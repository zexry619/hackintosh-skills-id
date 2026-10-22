from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
cpp = (ROOT / 'src/kext/RTW88IEEE80211.cpp').read_text()
compat_c = (ROOT / 'src/compat/rtw88_compat.c').read_text()
compat_h = (ROOT / 'src/compat/rtw88_compat.h').read_text()

assert 'uint8_t rtw88_get_tx_nss(struct rtw_dev *rtwdev);' in compat_h
assert 'uint8_t rtw88_get_tx_nss(struct rtw_dev *rtwdev)' in compat_c
assert 'rtwdev->efuse.hw_cap.nss' in compat_c
assert 'rtwdev->hal.rf_path_num' in compat_c

start = cpp.index('uint8_t RTW88IEEE80211::txNSS() const')
body = cpp[start: start + 220]
assert 'return rtw88_get_tx_nss(_rtwdev);' in body
assert '_rtwdev->' not in body

# The C++ layer intentionally treats rtw_dev as opaque; only the C compat
# layer, after main.h is included, may inspect Linux-driver internals.
assert '_rtwdev->' not in cpp

print('opaque rtw_dev TX-NSS bridge: OK')
