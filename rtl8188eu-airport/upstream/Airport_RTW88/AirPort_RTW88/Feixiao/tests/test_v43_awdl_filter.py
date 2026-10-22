from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
def extract(s,sig):
 a=s.index(sig);b=s.index('{',a)+1;depth=1
 while depth:depth+=(s[b]=='{')-(s[b]=='}');b+=1
 return s[a:b]
backend=(r/'src/kext/RTW88IEEE80211.cpp').read_text()
linux=(r.parent/'rtw88-stable/drivers/net/wireless/realtek/rtw88/mac80211.c').read_text()
code=r'''
#include <cassert>
#include <cstdint>
using IOReturn=int;using u64=uint64_t;
constexpr int kIOReturnNotReady=1,kIOReturnSuccess=0;
constexpr unsigned FIF_ALLMULTI=2,FIF_OTHER_BSS=64,FIF_FCSFAIL=4,FIF_BCN_PRBRESP_PROMISC=16;
constexpr unsigned BIT_AM=4,BIT_AAP=1,BIT_ACRC32=32,BIT_CBSSID_BCN=128,BIT_CBSSID_DATA=64,REG_RCR=0,RTW_DBG_RX=0;
struct rtw_dev {int mutex=0;struct{unsigned rcr=BIT_CBSSID_BCN|BIT_CBSSID_DATA;}hal;};
struct ieee80211_hw;struct Ops{void(*configure_filter)(ieee80211_hw*,unsigned,unsigned*,u64);};
struct ieee80211_hw{rtw_dev*priv;Ops*ops;};
int calls=0;unsigned last=0;
void mutex_lock(int*p){assert(!*p);*p=1;}void mutex_unlock(int*p){assert(*p);*p=0;}
void rtw_leave_lps_deep(rtw_dev*){}void rtw_dbg(rtw_dev*,int,const char*,...){}
void rtw_write32(rtw_dev*,int,unsigned value){++calls;last=value;}
void IOLog(const char*,...){}
struct RTW88IEEE80211{ieee80211_hw*_hw;bool _powered=false,_awdlReceiveMode=false,_receiveMulticast=false,_awdlOffChannel=false;unsigned _awdlChannel=6,_awdlPreparedChannel=6;void restoreSTAChannelAfterAWDL(){_awdlOffChannel=false;}int setAWDLReceiveMode(bool);};
'''+extract(linux,'static void rtw_ops_configure_filter(')+extract(backend,'IOReturn RTW88IEEE80211::setAWDLReceiveMode(')+r'''
int main(){rtw_dev dev;Ops ops{rtw_ops_configure_filter};ieee80211_hw hw{&dev,&ops};RTW88IEEE80211 b;b._hw=&hw;
 assert(!b.setAWDLReceiveMode(true)&&calls==0&&b._awdlReceiveMode);
 b._powered=true;assert(!b.setAWDLReceiveMode(true)&&calls==1);
 assert((last&(BIT_AAP|BIT_AM))==(BIT_AAP|BIT_AM));assert(!(last&(BIT_CBSSID_BCN|BIT_CBSSID_DATA|BIT_ACRC32)));
 dev.hal.rcr|=BIT_CBSSID_BCN;assert(!b.setAWDLReceiveMode(true)&&!(last&BIT_CBSSID_BCN));
 assert(!b.setAWDLReceiveMode(false)&&!(last&(BIT_AAP|BIT_AM))&&(last&BIT_CBSSID_BCN));
 assert(!b._awdlChannel&&!b._awdlPreparedChannel);
 b._hw=nullptr;assert(b.setAWDLReceiveMode(true)==kIOReturnNotReady);
}
'''
with tempfile.TemporaryDirectory() as t:
 p=Path(t);(p/'test.cpp').write_text(code)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined',str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
print('PASS: actual rtw88 RX filter accepts AWDL MAC/BSSID, scan reset, disable, no hardware access while OFF')
