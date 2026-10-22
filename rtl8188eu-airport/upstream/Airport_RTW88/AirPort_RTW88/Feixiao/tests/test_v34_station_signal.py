from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
code=r'''
#include "RTW88MgmtValidation.hpp"
#include <cassert>
#include <cstring>
int main(){
 uint8_t mac[]={2,1,2,3,4,5},ap[]={4,6,7,8,9,10},frame[32]={};
 frame[0]=0x80;memset(frame+4,255,6);memcpy(frame+10,ap,6);memcpy(frame+16,ap,6);
 assert(rtw88StationSignal(frame,32,mac,ap,-45,false));
 for(unsigned n=0;n<24;++n)assert(!rtw88StationSignal(frame,n,mac,ap,-45,false));
 int signal=-45;
 for(unsigned i=0;i<10000;++i){frame[10]=6;if(rtw88StationSignal(frame,32,mac,ap,-95,false))signal=-95;}
 assert(signal==-45);frame[10]=4;
 assert(!rtw88StationSignal(frame,32,mac,ap,-45,true));
 assert(!rtw88StationSignal(frame,32,mac,ap,0,false));
 frame[0]=8;frame[1]=2;memcpy(frame+4,mac,6);
 assert(rtw88StationSignal(frame,32,mac,ap,-95,false)); // A real drop remains visible.
 frame[4]=6;assert(!rtw88StationSignal(frame,32,mac,ap,-45,false));
 frame[4]=0x33;assert(rtw88StationSignal(frame,32,mac,ap,-45,false));
 frame[1]=0;assert(!rtw88StationSignal(frame,32,mac,ap,-45,false)); // Direct/AWDL.
 frame[1]=3;assert(!rtw88StationSignal(frame,32,mac,ap,-45,false));
 uint8_t zero[6]={};assert(!rtw88StationSignal(frame,32,mac,zero,-45,false));
}
'''
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'t.cpp').write_text(code)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined','-I'+str(r/'src/kext'),str(p/'t.cpp'),'-o',str(p/'t')],check=True)
 subprocess.run([str(p/'t')],check=True)
s=(r/'src/kext/RTW88IEEE80211.cpp').read_text()
assert 'if (rtw88StationSignal(skb->data' in s
assert 'RX_FLAG_NO_SIGNAL_VAL | RX_FLAG_FAILED_FCS_CRC' in s
assert 'bool rtw88_disable_watchdog_work = true;' in (r/'src/compat/rtw88_compat.c').read_text()
print('PASS: AP-only RSSI, 10000 foreign frames, real signal drop, direct/AWDL rejection, missing signal/FCS guards; full RF watchdog remains guarded')
