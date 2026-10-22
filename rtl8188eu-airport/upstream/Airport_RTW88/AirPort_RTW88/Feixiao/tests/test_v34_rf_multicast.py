from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'src/kext/RTW88IEEE80211.cpp').read_text();a=s.index('IOReturn RTW88IEEE80211::setReceiveMulticast(');b=s.index('IOReturn RTW88IEEE80211::setAWDLReceiveMode',a)
linux=(r.parent/'rtw88-stable/drivers/net/wireless/realtek/rtw88/main.c').read_text();x=linux.index('\tif (rtw88_disable_watchdog_work) {');y=linux.index('\n\n',x)
code=r'''
#include <cassert>
using IOReturn=int;
constexpr int kIOReturnNotReady=6,kIOReturnSuccess=0,FIF_ALLMULTI=1,RTW_FLAG_SCANNING=1;
struct HW;struct Ops{void(*configure_filter)(HW*,unsigned,unsigned*,int);};struct HW{Ops*ops;};
unsigned applied=0,calls=0;void filter(HW*,unsigned,unsigned*f,int){applied=*f;++calls;}
struct RTW88IEEE80211 {HW*_hw=nullptr;bool _powered=true,_receiveMulticast=false,_awdlReceiveMode=false;IOReturn setReceiveMulticast(bool);};
'''+s[a:b]+r'''
struct Dev;struct ChipOps{void(*pwr_track)(Dev*);};struct Chip{ChipOps*ops;};struct Dev{int sta_cnt;unsigned flags;Chip*chip;};
int powerCalls=0,wakes=0;bool rtw88_disable_watchdog_work=true;
bool test_bit(int bit,unsigned flags){return flags&bit;}void rtw_leave_lps(Dev*){++wakes;}void power(Dev*){++powerCalls;}
void tick(Dev*rtwdev){
'''+linux[x:y]+r'''
unlock:return;}
int main(){Ops ops{filter};HW hw{&ops};RTW88IEEE80211 r;r._hw=&hw;
assert(r.setReceiveMulticast(false)==0&&applied==0);r._awdlReceiveMode=true;
assert(r.setReceiveMulticast(false)==0&&applied==1&&!r._receiveMulticast);
r._awdlReceiveMode=false;assert(r.setReceiveMulticast(true)==0&&applied==1);
r._powered=false;unsigned old=calls;r.setReceiveMulticast(false);assert(calls==old);
ChipOps cp{power};Chip chip{&cp};Dev d{1,0,&chip};tick(&d);assert(powerCalls==1&&wakes==1);
d.flags=1;tick(&d);assert(powerCalls==1);d.flags=0;d.sta_cnt=0;tick(&d);assert(powerCalls==1);
d.sta_cnt=1;cp.pwr_track=nullptr;tick(&d);assert(powerCalls==1&&wakes==1);
}
'''
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'t.cpp').write_text(code)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined',str(p/'t.cpp'),'-o',str(p/'t')],check=True)
 subprocess.run([str(p/'t')],check=True)
print('PASS: thermal maintenance only with STA/no scan/valid callback; AWDL multicast survives STA multicast changes')
