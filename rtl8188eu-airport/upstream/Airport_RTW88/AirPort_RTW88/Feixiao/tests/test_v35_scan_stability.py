"""Exercise production home-channel restore: no calibration storm while scanning."""
from pathlib import Path
import subprocess, tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'src/compat/rtw88_compat.c').read_text()
a=s.index('void rtw88_restore_connected_hw(');b=s.index('\nvoid rtw88_get_fw_version',a)
code=r'''
#include <cassert>
#include <cstdint>
#include <cstring>
constexpr int ETH_ALEN=6,PORT_SET_BSSID=1,RTW_FLAG_SCANNING=1;
struct rtw_dev {int mutex=0;unsigned flags=1;bool need_rfk=false;struct{int fix_rate=0;}dm_info;};
struct rtw_vif {uint8_t bssid[6];};
struct ieee80211_hw {void*priv;};struct ieee80211_vif {void*drv_priv;};
int switches=0,calibrations=0,bssidWrites=0;
bool test_bit(int bit,unsigned flags){return (flags&bit)!=0;}
void mutex_lock(int*m){assert(*m==0);*m=1;}void mutex_unlock(int*m){assert(*m==1);*m=0;}
void rtw_set_channel(rtw_dev*d){assert(d->mutex);++switches;if(!test_bit(RTW_FLAG_SCANNING,d->flags))d->need_rfk=true;}
void rtw_vif_port_config(rtw_dev*d,rtw_vif*,int){assert(d->mutex);++bssidWrites;}
void rtw_chip_prepare_tx(rtw_dev*d){assert(d->mutex);if(d->need_rfk){++calibrations;d->need_rfk=false;}}
'''+s[a:b]+r'''
int main(){rtw_dev d;rtw_vif v{};ieee80211_hw h{&d};ieee80211_vif vif{&v};uint8_t ap[]={2,3,4,5,6,7};
// An existing pending calibration must also remain deferred through the scan.
d.need_rfk=true;
for(int i=0;i<100;i++)rtw88_restore_connected_hw(&h,&vif,ap);
assert(switches==100&&calibrations==0&&bssidWrites==100&&d.need_rfk);
assert(memcmp(ap,v.bssid,6)==0&&d.mutex==0&&d.dm_info.fix_rate==255);
d.flags=0;rtw88_restore_connected_hw(&h,&vif,ap);
assert(calibrations==1&&!d.need_rfk&&switches==101);
rtw88_restore_connected_hw(nullptr,&vif,ap);rtw88_restore_connected_hw(&h,nullptr,ap);rtw88_restore_connected_hw(&h,&vif,nullptr);
assert(switches==101);
}
'''
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'t.cpp').write_text(code)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined',str(p/'t.cpp'),'-o',str(p/'t')],check=True)
 subprocess.run([str(p/'t')],check=True)
s=(r/'src/kext/RTW88IEEE80211.cpp').read_text()
worker=s[s.index('void RTW88IEEE80211::runManualScan()'):s.index('bool RTW88IEEE80211::matchesPendingJoin')]
tail=worker[worker.index('rtw88_sw_scan_complete'):]
assert 'restoreConnectedChannel' not in tail and 'txNullFunc' not in tail
assert 'scanDone(_manualScanAbort)' in tail
complete=s[s.index('void RTW88IEEE80211::scanDone('):s.index('IOReturn RTW88IEEE80211::cmdScan(')]
assert 'restoreConnectedChannel();\n            txNullFunc(false);' in complete
assert complete.index('txNullFunc(false)') < complete.index('kRTW88EventScanDone')
print('PASS: 100 scan home visits without IQK, deferred calibration runs after scan, one final restore path with AP wake before completion')
