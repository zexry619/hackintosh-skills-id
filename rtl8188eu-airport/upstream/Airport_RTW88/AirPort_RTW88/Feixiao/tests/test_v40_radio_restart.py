from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'src/kext/RTW88IEEE80211.cpp').read_text()
a=s.index('IOReturn RTW88IEEE80211::powerOn()');b=s.index('/* ------------------------------------------------------------------ */',a)
body=s[a:b]
c=(r/'src/compat/rtw88_compat.c').read_text()
a=c.index('int rtw88_restore_interface(');b=c.index('int rtw88_set_station_mac(',a)
restore=c[a:b]
code=r'''
#include <cassert>
#include <cstdint>
#include <cerrno>
using IOReturn=int;
constexpr int kIOReturnSuccess=0,kIOReturnNotReady=1,kIOReturnError=2;
void IOLog(const char*,...){}
int locked=0,starts=0,stops=0,ports=0,channels=0,filters=0,startResult=0,filterResult=0;
bool portRestored=false;
void mutex_lock(int*){assert(!locked);locked=1;}
void mutex_unlock(int*){assert(locked);locked=0;}
struct rtw_dev {int mutex=0;bool need_rfk=false;};
struct rtw_vif {void*conf=(void*)1;};
struct ieee80211_vif {rtw_vif drv_priv[1];};
struct ieee80211_hw;
struct Ops {int(*start)(ieee80211_hw*);void(*stop)(ieee80211_hw*,bool);};
struct ieee80211_hw {rtw_dev*priv;Ops*ops;struct {struct {void*chan;}chandef;}conf;};
void rtw_vif_port_config(rtw_dev*,rtw_vif*,unsigned mask){assert(locked&&mask==~0U);++ports;portRestored=true;}
void rtw_set_channel(rtw_dev*){assert(locked);++channels;}
int startHW(ieee80211_hw*){++starts;portRestored=false;return startResult;}
void stopHW(ieee80211_hw*,bool){++stops;}
'''+restore+r'''
struct RTW88IEEE80211 {
 bool _powered=false,_awdlReceiveMode=false,_receiveMulticast=false;
 int _awdlPreparedChannel=149;ieee80211_hw*_hw;ieee80211_vif*_vif;
 int powerOn();void powerOff();
 int setAWDLReceiveMode(bool){assert(portRestored);++filters;return filterResult;}
 int setReceiveMulticast(bool){assert(portRestored);++filters;return filterResult;}
};
'''+body+r'''
int main(){
 rtw_dev dev;Ops ops{startHW,stopHW};ieee80211_hw hw{&dev,&ops,{{(void*)1}}};ieee80211_vif vif;
 RTW88IEEE80211 radio;radio._hw=&hw;radio._vif=&vif;
 for(int i=0;i<50;++i){
  radio._awdlReceiveMode=i%2;
  assert(radio.powerOn()==0&&radio._powered&&portRestored&&dev.need_rfk);
  assert(radio._awdlPreparedChannel==0);
  int n=starts;assert(radio.powerOn()==0&&starts==n);radio.powerOff();assert(!radio._powered);
 }
 assert(starts==50&&stops==50&&ports==50&&channels==50&&filters==50);
 startResult=-1;assert(radio.powerOn()==kIOReturnError&&!radio._powered&&ports==50);
 startResult=0;vif.drv_priv[0].conf=nullptr;
 assert(radio.powerOn()==kIOReturnError&&!radio._powered&&stops==51);
 vif.drv_priv[0].conf=(void*)1;filterResult=3;
 assert(radio.powerOn()==3&&!radio._powered&&stops==52);
 filterResult=0;hw.conf.chandef.chan=nullptr;int n=channels;
 assert(radio.powerOn()==0&&channels==n);radio.powerOff();
 assert(rtw88_restore_interface(nullptr,&vif)==-EINVAL);
 assert(rtw88_restore_interface(&hw,nullptr)==-EINVAL);
}
'''
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'t.cpp').write_text(code)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined',str(p/'t.cpp'),'-o',str(p/'t')],check=True)
 subprocess.run([str(p/'t')],check=True)
print('PASS: actual powerOn/powerOff and port restore, 50 cycles, idempotence, start/restore/filter failure rollback, channel absent')
