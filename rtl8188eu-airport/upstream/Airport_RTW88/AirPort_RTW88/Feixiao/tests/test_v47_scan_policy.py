"""Execute production scan policy across all supported PCI chip families."""
from pathlib import Path
import subprocess, tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'src/compat/rtw88_compat.c').read_text()
a=s.index('bool rtw88_hw_scan_supported(');b=s.index('\nvoid rtw88_sw_scan_start(',a)
code=r'''
#include <cassert>
constexpr int RTW_CHIP_TYPE_8822C=2,FW_FEATURE_SCAN_OFFLOAD=1;
struct Chip {int id;};struct Firmware {bool supported;};
struct rtw_dev {Chip*chip;Firmware fw;};struct ieee80211_hw {void*priv;};
bool rtw_fw_feature_check(Firmware*f,int){return f->supported;}
''' + s[a:b] + r'''
int main(){
 assert(!rtw88_hw_scan_supported(nullptr));ieee80211_hw empty{nullptr};assert(!rtw88_hw_scan_supported(&empty));
 for(int id=0;id<3;++id)for(int feature=0;feature<2;++feature){
  Chip chip{id};rtw_dev dev{&chip,{bool(feature)}};ieee80211_hw hw{&dev};
  assert(rtw88_hw_scan_supported(&hw)==(id!=RTW_CHIP_TYPE_8822C&&feature));
 }
}
'''
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'test.cpp').write_text(code)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined',str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
print('PASS: production scan policy selects software for 8822C, preserves firmware capability for other families, null hardware')
