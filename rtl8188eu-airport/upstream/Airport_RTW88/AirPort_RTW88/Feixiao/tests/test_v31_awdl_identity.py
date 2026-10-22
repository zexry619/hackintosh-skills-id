from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'src/kext/AirportRTW88.cpp').read_text();a=s.index('bool AirportRTW88::ensureAWDLVirtualInterface()');b=s.index('IOReturn AirportRTW88::handleVIRTUAL_IF_CREATE',a)
f=s[a:b]
code=r'''
#include <cassert>
#include <cstring>
#include <cstdint>
#include "RTW88AWDLProtocol.hpp"
using SInt32=int;
constexpr int kIOReturnSuccess=0,APPLE80211_VIF_AWDL=4;
struct ether_addr {uint8_t octet[6];};struct IOEthernetAddress{uint8_t bytes[6];};
void IOLog(const char*,...){}
struct IO80211VirtualInterface {const char*getBSDName(){return "awdl0";}unsigned getInterfaceRole(){return 4;}};
struct Manager {IO80211VirtualInterface*v=nullptr;auto awdlInterface(){return v;}void clearVirtualInterface(IO80211VirtualInterface*){v=nullptr;}};
struct AirportRTW88 {
 Manager*_awdlManager;void*_netif=this;IO80211VirtualInterface vif;
 IOEthernetAddress mac={{0x84,1,2,3,4,5}};ether_addr captured={};int gets=0,attaches=0,enables=0,error=0,enableError=0;
 int getHardwareAddress(IOEthernetAddress*out){++gets;*out=mac;return error;}
 bool attachVirtualInterface(IO80211VirtualInterface**out,ether_addr*addr,int,bool){++attaches;captured=*addr;*out=&vif;return true;}
 int enableVirtualInterface(IO80211VirtualInterface*p){++enables;if(!enableError)_awdlManager->v=p;return enableError;}
 bool ensureAWDLVirtualInterface();
};
'''+f+r'''
int main(){Manager m;AirportRTW88 c{&m};
 assert(c.ensureAWDLVirtualInterface());assert(c.gets==1&&c.attaches==1&&c.enables==1);
 assert(c.captured.octet[0]==0x86&&c.captured.octet[5]==0x85&&c.captured.octet[1]==1);
 assert(c.ensureAWDLVirtualInterface()&&c.attaches==1);
 m.v=nullptr;c.mac={};assert(!c.ensureAWDLVirtualInterface()&&c.attaches==1);
 c.mac.bytes[0]=1;assert(!c.ensureAWDLVirtualInterface()&&c.attaches==1);
 c.mac.bytes[0]=2;c.error=1;assert(!c.ensureAWDLVirtualInterface()&&c.attaches==1);
 c.error=0;c.enableError=1;assert(!c.ensureAWDLVirtualInterface()&&m.v==nullptr);
}
'''
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'t.cpp').write_text(code)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined','-I'+str(r/'src/kext'),str(p/'t.cpp'),'-o',str(p/'t')],check=True)
 subprocess.run([str(p/'t')],check=True)
print('PASS: actual AWDL attach uses backend identity, rejects invalid MAC/read failure, avoids duplicate, propagates enable failure')
