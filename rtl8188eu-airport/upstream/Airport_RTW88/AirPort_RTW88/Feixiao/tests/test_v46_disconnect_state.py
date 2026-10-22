"""Execute the production disconnect method; backend must observe disconnected cfg."""
from pathlib import Path
import subprocess, tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'src/kext/RTW88IEEE80211.cpp').read_text()
a=s.index('void RTW88IEEE80211::doDisconnect()')
b=s.index('\n/* ------------------------------------------------------------------ */',a)
code=r'''
#include <cassert>
#include <cstdint>
#include <cstring>
constexpr int RTW88_STATE_IDLE=0,RTW88_STATE_CONNECTED=5;
constexpr int IEEE80211_FTYPE_MGMT=0,IEEE80211_STYPE_DEAUTH=0xc0,WLAN_REASON_DEAUTH_LEAVING=3;
constexpr int BSS_CHANGED_ASSOC=1,kIONetworkLinkValid=1,kRTW88EventDisconnected=1;
uint16_t cpu_to_le16(uint16_t n){return n;}
struct ieee80211_hdr_3addr { uint16_t frame_control,duration;uint8_t addr1[6],addr2[6],addr3[6];uint16_t seq; };
struct ieee80211_bss_conf { bool assoc=true;unsigned aid=42; };
struct Vif { ieee80211_bss_conf bss_conf;struct {bool assoc=true;unsigned aid=42;}cfg; };
struct Hw;
struct Ops {void(*bss_info_changed)(Hw*,Vif*,ieee80211_bss_conf*,unsigned);};
struct Hw {Ops*ops;};
unsigned callbacks=0,releases=0,keys=0,frames=0,events=0,cancels=0;
void changed(Hw*,Vif*v,ieee80211_bss_conf*b,unsigned flags){
 assert(flags==BSS_CHANGED_ASSOC);assert(!b->assoc&&!b->aid&&!v->cfg.assoc&&!v->cfg.aid);
 assert(keys==releases+1);++callbacks;
}
struct Timer{void cancelTimeout(){++cancels;}};
struct Parent{void setLinkStatus(int n){assert(n==kIONetworkLinkValid);}};
struct Delegate{void rtw88Event(int,void*){++events;}};
struct RTW88IEEE80211 {
 Hw*_hw;Vif*_vif;Timer*_timer;Parent*_parent;Delegate*_delegate;
 int _state=RTW88_STATE_CONNECTED,_scanReturnState=RTW88_STATE_CONNECTED;
 bool _associatedVisible=true;unsigned _assocAID=42;
 struct {uint8_t bssid[6]={2,1,2,3,4,5};}_targetBSS;
 uint8_t _macAddr[6]={2,6,7,8,9,10};
 void clearKeys(){++keys;}void clearAssocRsnIE(){}
 void releaseSta(){assert(callbacks==releases+1);++releases;}
 bool txMgmtFrame(const uint8_t*p,unsigned len){assert(len==26&&p[24]==3);++frames;return true;}
 void doDisconnect();
};
''' + s[a:b] + r'''
int main(){
 Ops ops{changed};Hw hw{&ops};Vif vif;Timer timer;Parent parent;Delegate delegate;
 RTW88IEEE80211 driver{&hw,&vif,&timer,&parent,&delegate};
 for(unsigned i=0;i<100;++i){
  vif.cfg.assoc=vif.bss_conf.assoc=true;vif.cfg.aid=vif.bss_conf.aid=driver._assocAID=42+i;
  driver._state=RTW88_STATE_CONNECTED;driver._associatedVisible=true;
  driver.doDisconnect();assert(!driver._assocAID&&!driver._associatedVisible&&driver._state==RTW88_STATE_IDLE);
 }
 assert(callbacks==100&&releases==100&&keys==100&&frames==100&&events==100&&cancels==100);
}
'''
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'test.cpp').write_text(code)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined',str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
print('PASS: production disconnect clears both association mirrors and AIDs before backend notification, 100 cycles')
