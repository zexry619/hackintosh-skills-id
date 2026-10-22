"""Execute the actual deferred AWDL callback, with lifecycle mocks."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'src/kext/AirportRTW88AWDL.cpp').read_text()
f=s[s.index('void AirportRTW88::awdlTimerFired('):]
code=r'''
#include <cassert>
struct OSObject {virtual ~OSObject()=default;};
struct IOTimerEventSource {};
#define OSDynamicCast(T,p) dynamic_cast<T *>(p)
constexpr bool kOSBooleanTrue=true,kOSBooleanFalse=false;
struct Manager {void*vif=nullptr;int ticks=0;bool ready=false;
 void*awdlInterface(){return vif;}bool tick(){++ticks;return ready;}};
struct AirportRTW88:OSObject {Manager*_awdlManager=nullptr;int attaches=0,requests=0;bool result=false,reported=false;
 bool ensureAWDLVirtualInterface(){++attaches;if(result)_awdlManager->vif=this;return result;}
 void setProperty(const char*,bool v){reported=v;}
 void requestPacketTx(void*,int){++requests;}
 static void awdlTimerFired(OSObject*,IOTimerEventSource*);
};
'''+f+r'''
int main(){
 OSObject other;AirportRTW88::awdlTimerFired(&other,nullptr);
 AirportRTW88 c;AirportRTW88::awdlTimerFired(&c,nullptr);
 Manager m;c._awdlManager=&m;
 c.awdlTimerFired(&c,nullptr);assert(c.attaches==1&&!c.reported&&m.ticks==0);
 c.result=true;c.awdlTimerFired(&c,nullptr);assert(c.attaches==2&&c.reported&&m.ticks==1&&c.requests==0);
 m.ready=true;c.awdlTimerFired(&c,nullptr);assert(c.attaches==2&&m.ticks==2&&c.requests==1);
}
'''
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'t.cpp').write_text(code)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined',str(p/'t.cpp'),'-o',str(p/'t')],check=True)
 subprocess.run([str(p/'t')],check=True)
print('PASS: deferred AWDL bootstrap failure, successful attach, no duplicate attach and template readiness gating')
