"""Execute production join-during-scan branch: preserve complete idle scan."""
from pathlib import Path
import subprocess,tempfile,os
root=Path(__file__).resolve().parents[1]
s=Path(os.environ.get('RTW88_TEST_SOURCE',root/'src/kext/RTW88IEEE80211.cpp')).read_text()
a=s.index('IOReturn RTW88IEEE80211::cmdConnect(')
b=s.index('    if (_state != RTW88_STATE_IDLE)',a)
body=s[a:b]+'    return kIOReturnBusy;\n}\n'
code=r'''
#include <cstdint>
#include <cstring>
#include <cassert>
#include <cstdio>
#define IOLog(...) ((void)0)
using IOReturn=int;
constexpr int kIOReturnBadArgument=1,kIOReturnSuccess=0,kIOReturnBusy=2;
constexpr int RTW88_STATE_SCANNING=1,RTW88_STATE_IDLE=0,RTW88_STATE_CONNECTED=2;
struct Hw;unsigned cancels=0;void cancel(Hw*,void*){++cancels;}
struct Ops {void(*cancel_hw_scan)(Hw*,void*)=cancel;};struct Hw{Ops*ops;};
struct RTW88IEEE80211 {
 int _state=RTW88_STATE_SCANNING,_scanReturnState=RTW88_STATE_IDLE;
 char _deferredSSID[33]{},_deferredPassword[65]{};uint8_t _deferredPMK[32]{},_deferredBSSID[6]{};
 bool _deferredPMKValid=false,_deferredBSSIDValid=false,_deferredExternalSupplicant=false,_deferredConnectPending=false;
 unsigned _manualScanChannelCount=39;bool _manualScanAbort=false;Hw*_hw=nullptr;void*_vif=nullptr;
 IOReturn cmdConnect(const char*,const char*,const uint8_t*,const uint8_t*,bool);
};
'''+body+r'''
int main(){
 Ops ops;Hw hw{&ops};RTW88IEEE80211 d;d._hw=&hw;uint8_t key[32]={5},bssid[6]={2,3,4,5,6,7};
 // Autojoin arrives after the first channels. All subsequent scan channels
 // must remain eligible, and the credential/target request stays deferred.
 assert(d.cmdConnect("network","secret",key,bssid,true)==0);
 assert(!d._manualScanAbort&&!cancels&&d._deferredConnectPending);
 assert(d._deferredPMKValid&&d._deferredBSSIDValid&&d._deferredExternalSupplicant);
 assert(!memcmp(d._deferredPMK,key,32)&&!memcmp(d._deferredBSSID,bssid,6));
 for(int i=0;i<10;++i)assert(d.cmdConnect("network",nullptr,nullptr,nullptr,false)==0);
 assert(!d._manualScanAbort&&!cancels);assert(!d._deferredPMKValid&&!d._deferredBSSIDValid);
 assert(d._deferredPMK[0]==0&&d._deferredBSSID[0]==0);
 // An existing cancellation is not undone by a late association request.
 d._manualScanAbort=true;d.cmdConnect("network",nullptr,nullptr,nullptr,false);assert(d._manualScanAbort);
 d._manualScanAbort=false;d._scanReturnState=RTW88_STATE_CONNECTED;
 d.cmdConnect("network",nullptr,nullptr,nullptr,false);assert(d._manualScanAbort);
 d._manualScanChannelCount=0;d._manualScanAbort=false;
 d.cmdConnect("network",nullptr,nullptr,nullptr,false);assert(cancels==1);
 assert(d.cmdConnect("",nullptr,nullptr,nullptr,false)==kIOReturnBadArgument);
}
'''
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'t.cpp').write_text(code)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined',str(p/'t.cpp'),'-o',str(p/'t')],check=True)
 subprocess.run([str(p/'t')],check=True)
print('PASS: production pending-join branch preserves idle software scan, repeated joins, key clearing, existing cancellation, live-STA/firmware cancellation and validation')
