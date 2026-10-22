"""Execute actual lifecycle methods with PCI fault injection; never load a kext."""
from pathlib import Path
import subprocess, tempfile
root = Path(__file__).resolve().parents[1]
s = (root/'src/kext/AirportRTW88.cpp').read_text()
def method(signature):
    start=s.index(signature); opening=s.index('{',start); depth=1; end=opening+1
    while depth:
        depth += (s[end]=='{')-(s[end]=='}'); end+=1
    return s[start:end]
code=r'''
#include <cassert>
using SInt32=int; using IOReturn=int; using IOOptionBits=unsigned;
constexpr int kIOReturnSuccess=0,kIOReturnError=1,kIOReturnNotReady=2;
constexpr int kIOPCIConfigCommand=4,kIOMessageSystemWillPowerOff=10,kIOMessageSystemWillRestart=11;
void IOLog(const char*,...){}
struct IONetworkInterface {};
struct PCI { unsigned command=4; bool stuck=false; void setBusMasterEnable(bool on){if(!stuck) command=on?4:0;} unsigned configRead16(int){return command;} };
struct IRQ {bool active=true;void enable(){active=true;}void disable(){active=false;}};
struct Backend {int calls=0;int powerOn(){++calls;return 0;}void powerOff(){}};
struct AWDL {void scheduleDiscovery(){}};
struct Base {int notifications=0;int enable(IONetworkInterface*){return 0;}void systemWillShutdown(unsigned){++notifications;}};
#define super Base
struct AirportRTW88:Base {
 bool _shutdown=false,_dmaStopped=false,_scanCacheBootstrapAttempted=true;
 AWDL *_awdlManager=nullptr;
 PCI *_pciDev=nullptr;IRQ *_intrSrc=nullptr;Backend *_ieee80211=nullptr;
 SInt32 stopDMA();void systemWillShutdown(IOOptionBits);IOReturn enable(IONetworkInterface*);
};
'''
code+='\n'.join(method(x) for x in ['SInt32 AirportRTW88::stopDMA()', 'void AirportRTW88::systemWillShutdown(', 'IOReturn AirportRTW88::enable('])
code+=r'''
int main(){
 PCI pci;IRQ irq;Backend backend;AirportRTW88 d;d._pciDev=&pci;d._intrSrc=&irq;d._ieee80211=&backend;
 for(int i=0;i<100;++i){assert(d.stopDMA()==0);assert(!pci.command&&!irq.active&&d._dmaStopped);assert(d.stopDMA()==0);assert(d.enable(nullptr)==0);assert(pci.command==4&&irq.active&&!d._dmaStopped);}
 pci.stuck=true;assert(d.stopDMA()==kIOReturnError);assert(d._dmaStopped&&!irq.active);
 pci.stuck=false;assert(d.stopDMA()==0);pci.stuck=true;assert(d.enable(nullptr)==kIOReturnNotReady);assert(d._dmaStopped&&!irq.active);
 pci.stuck=false;assert(d.enable(nullptr)==0);
 d.systemWillShutdown(99);assert(!d._shutdown&&d.notifications==1);
 d.systemWillShutdown(kIOMessageSystemWillRestart);assert(d._shutdown&&!pci.command&&!irq.active&&d.notifications==2);
 int before=backend.calls;assert(d.enable(nullptr)==kIOReturnNotReady&&backend.calls==before);
 d.systemWillShutdown(kIOMessageSystemWillPowerOff);assert(d.notifications==3&&!pci.command);
 AirportRTW88 empty;assert(empty.stopDMA()==0);empty.systemWillShutdown(kIOMessageSystemWillPowerOff);assert(empty.notifications==1);
}
'''
with tempfile.TemporaryDirectory() as t:
    p=Path(t); (p/'test.cpp').write_text(code)
    subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined',str(p/'test.cpp'),'-o',str(p/'test')],check=True)
    subprocess.run([str(p/'test')],check=True)
teardown=method('void AirportRTW88::teardown()')
assert teardown.index('stopDMA()') < teardown.index('_ieee80211->stop()') < teardown.index('detachInterface') < teardown.index('releaseDMAEntries()')
assert 'disable(_netif)' not in method('SInt32 AirportRTW88::stopDMA()')
print('PASS: 100 DMA stop/enable cycles, PCI write failures, restart/poweroff, superclass notification, partial init, teardown ordering (ASan/UBSan)')
