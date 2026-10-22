"""Run the production timer handler: timed-out scan must complete deferred join path."""
from pathlib import Path
import subprocess,tempfile
s=(Path(__file__).resolve().parents[1]/'src/kext/RTW88IEEE80211.cpp').read_text()
body=s[s.index('void RTW88IEEE80211::onTimer()'):s.index('/*  Status queries')]
prefix=r'''
#include <cstdint>
constexpr int RTW88_STATE_IDLE=0,RTW88_STATE_SCANNING=1,RTW88_STATE_AUTHENTICATING=2,RTW88_STATE_ASSOCIATING=3,RTW88_STATE_HANDSHAKING=4;
void IOLog(const char*,...){} void thread_call_enter(void*){}
struct Hw;struct Ops {void(*cancel_hw_scan)(Hw*,void*);};struct Hw{Ops*ops;};
struct RTW88IEEE80211{
 int _state=RTW88_STATE_SCANNING,_manualScanChannelCount=0,completions=0,failures=0;
 bool _manualScanAbort=false;Hw*_hw=nullptr;void*_vif=nullptr,*_connectTC=nullptr;
 void onTimer();bool authenticationCancelled(){return false;}
 void scanDone(bool aborted){if(_state!=RTW88_STATE_SCANNING)return;if(!aborted)__builtin_trap();completions++;_state=RTW88_STATE_IDLE;}
 void failJoin(const char*){failures++;_state=RTW88_STATE_IDLE;}void doDisconnect(){failJoin("disconnect");}
};
RTW88IEEE80211*active;
void cancelSync(Hw*,void*){active->scanDone(true);}
'''
main=r'''
int main(){
 RTW88IEEE80211 a; a.onTimer();if(a.completions!=1||a._state!=RTW88_STATE_IDLE)return 1;
 RTW88IEEE80211 b;Ops ops{cancelSync};Hw hw{&ops};b._hw=&hw;active=&b;b.onTimer();if(b.completions!=1)return 2;
 RTW88IEEE80211 c;c._manualScanChannelCount=5;c.onTimer();if(!c._manualScanAbort||c.completions)return 3;
 RTW88IEEE80211 d;d._state=RTW88_STATE_ASSOCIATING;d.onTimer();if(d.failures!=1||d._state!=RTW88_STATE_IDLE)return 4;
}
'''
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'test.cpp').write_text(prefix+body+main)
 subprocess.run(['xcrun','clang++','-std=c++17',str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
print('PASS: scan timeout completes with absent/synchronous cancel callback, manual scan abort, association failure notification')
