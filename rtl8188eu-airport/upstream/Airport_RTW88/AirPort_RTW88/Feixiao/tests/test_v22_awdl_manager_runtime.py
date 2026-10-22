"""Run the production AWDL manager with deterministic IOKit/radio/mbuf mocks."""
from pathlib import Path
import re,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
stubs=r'''
#pragma once
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cassert>
#include <vector>
#include <map>
#include <string>
using UInt=unsigned;using IOReturn=int;
constexpr int kIOReturnSuccess=0,kIOReturnBadArgument=1,kIOReturnNoMemory=2,kIOReturnNotReady=3,kIOReturnNoSpace=4,kIOReturnBusy=5;
constexpr unsigned APPLE80211_VIF_AWDL=4,APPLE80211_VIF_P2P_DEVICE=1,APPLE80211_VIF_P2P_GO=3;
constexpr bool kOSBooleanTrue=true;
inline int allocations=0,mbufs=0;
inline void*IOMalloc(size_t n){void*p=malloc(n);if(p)++allocations;return p;}
inline void IOFree(void*p,size_t){if(p){--allocations;free(p);}}
inline void IOLog(const char*,...){}
struct OSObject{};
struct IOService:OSObject{
 std::map<std::string,uint64_t> props;
 std::map<std::string,std::string> strings;
 std::map<std::string,std::vector<uint8_t>> blobs;
 void setProperty(const char*k,uint64_t v,unsigned=0){props[k]=v;}
 void setProperty(const char*k,const char*v){strings[k]=v;}
 void setProperty(const char*k,void*v,unsigned n){const auto*p=static_cast<const uint8_t*>(v);blobs[k]=std::vector<uint8_t>(p,p+n);}
};
struct IOTimerEventSource{
 using Action=void(*)(OSObject*,IOTimerEventSource*);
 unsigned delay=0;bool cancelled=false;
 static IOTimerEventSource*timerEventSource(OSObject*,Action){return new IOTimerEventSource;}
 void setTimeoutMS(unsigned d){delay=d;cancelled=false;}
 void cancelTimeout(){cancelled=true;}
 void release(){delete this;}
};
struct IOWorkLoop {
 using Action=IOReturn(*)(OSObject*,void*,void*,void*,void*);
 int attached=0;
 IOReturn addEventSource(IOTimerEventSource*){++attached;return 0;}
 void removeEventSource(IOTimerEventSource*){--attached;}
 IOReturn runAction(Action a,OSObject*o,void*p){return a(o,p,nullptr,nullptr,nullptr);}
};
struct IO80211VirtualInterface{};
struct Packet {std::vector<uint8_t> bytes;};using mbuf_t=Packet*;
inline size_t mbuf_pkthdr_len(mbuf_t p){return p->bytes.size();}
inline int mbuf_copydata(mbuf_t p,size_t o,size_t n,void*out){if(o+n>p->bytes.size())return 1;memcpy(out,p->bytes.data()+o,n);return 0;}
inline void mbuf_freem(mbuf_t p){assert(p);--mbufs;delete p;}
inline uint64_t testNow=10000000;
inline uint64_t mach_absolute_time(){return testNow*1000;}
inline void absolutetime_to_nanoseconds(uint64_t t,uint64_t*out){*out=t;}
struct RTW88IEEE80211{
 void setAWDLAddress(const uint8_t*){}
 bool powered=true;unsigned state=0;uint16_t channel=0,desired=0;unsigned actions=0,data=0;
 std::vector<uint8_t> last;
 IOReturn setAWDLChannel(uint16_t c){desired=c;if(!powered)return kIOReturnNotReady;if(state&&(state!=2||c!=channel))return kIOReturnBusy;channel=c;return 0;}
 bool canTransmitAWDL()const{return powered&&state!=1&&channel&&channel==desired;}
 bool staAssociatedForAWDL()const{return state==2;}
 uint16_t infrastructureChannel()const{return channel;}
 bool staTxBlockedByAWDL()const{return false;}
 void restoreSTAChannelAfterAWDL(){}
 bool txRawManagementFrame(const uint8_t*p,uint32_t n){if(!canTransmitAWDL())return false;++actions;last.assign(p,p+n);return true;}
 bool txAWDLDataFrame(mbuf_t p){assert(canTransmitAWDL());++data;mbuf_freem(p);return true;}
};
'''
main=r'''
#include "RTW88AWDLManager.hpp"
#include "awdl_fixture.hpp"
mbuf_t packet(const uint8_t*mac){auto*p=new Packet;p->bytes.resize(80);memcpy(p->bytes.data(),mac,6);++mbufs;return p;}
int main(){
 RTW88IEEE80211 hw;IOWorkLoop loop;IOService owner;IO80211VirtualInterface vif;
 {
 RTW88AWDLManager m;
 assert(m.init(&hw,&loop,&owner,[](OSObject*,IOTimerEventSource*){}));
 uint8_t mac[]={2,1,2,3,4,5},multicast[]={0x33,0x33,0,0,0,0xfb},peerMac[]={2,1,2,3,4,9};
 m.setLocalAddress(mac);m.setVirtualInterface(4,&vif);
 auto f=awdlFixture();assert(m.setSyncFrameTemplate(f.data(),f.size())==0);
 std::vector<uint8_t> out(f.size(),0xa5);uint32_t n=1;
 assert(m.copySyncFrameTemplate(out.data(),&n)==kIOReturnNoSpace&&out[0]==0xa5&&n==f.size());
 n=out.size();assert(m.copySyncFrameTemplate(out.data(),&n)==0&&out==f);
 auto bad=f;bad[41]=255;assert(m.setSyncFrameTemplate(bad.data(),bad.size())!=0);
 assert(m.enqueueData(packet(multicast)));m.tick();assert(hw.data==0&&hw.actions==0);
 testNow+=64*1024+4*1024;assert(m.tick());assert(hw.data==1&&hw.actions==1);
 // Updated timestamps and sequence survive parsing; raw GET remains unchanged.
 RTW88AWDL::Action parsed;assert(RTW88AWDL::parseAction(hw.last.data(),hw.last.size(),parsed)&&parsed.awCounter==0);
 auto peer=f;memcpy(peer.data()+10,peerMac,6);peer[30]=3;
 RTW88AWDL::put16(peer.data()+43+29,0);RTW88AWDL::put16(peer.data()+43+1,60);
 peer.push_back(21);peer.push_back(2);peer.push_back(0);peer.push_back(0x34);peer.push_back(1);
 m.observeAction(peer.data(),peer.size());assert(m.enqueueData(packet(peerMac)));m.tick();assert(hw.data==2);
 // No radio traffic during scan; packets remain queued until expiry.
 hw.state=1;assert(m.enqueueData(packet(multicast)));unsigned sent=hw.data;
 testNow+=4000;m.tick();m.publishStats();assert(hw.data==sent&&owner.props["AWDL_QUEUE_DEPTH"]==1);
 testNow+=2000001;m.tick();m.publishStats();assert(owner.props["AWDL_QUEUE_DEPTH"]==0);
 // Bounded queue, shutdown frees every owned mbuf; template GET survives disable.
 for(unsigned i=0;i<128;++i)assert(m.enqueueData(packet(peerMac)));
 assert(!m.enqueueData(packet(peerMac)));m.setSyncEnabled(false);assert(mbufs==0);
 unsigned actions=hw.actions;testNow+=1000000;assert(!m.tick()&&hw.actions==actions);
 m.clearVirtualInterface(&vif);m.reset();assert(loop.attached==0&&allocations==0&&mbufs==0);
 }
 assert(allocations==0&&mbufs==0);
}
'''
with tempfile.TemporaryDirectory() as td:
 p=Path(td)
 (p/'stubs.hpp').write_text(stubs)
 for name in ['RTW88AWDLManager.cpp','RTW88AWDLManager.hpp']:
  s=(root/'src/kext'/name).read_text()
  s=re.sub(r'^#include <[^\n]+>\n','',s,flags=re.M)
  s=s.replace('#include "RTW88IEEE80211.hpp"','')
  (p/name).write_text('#include "stubs.hpp"\n'+s)
 (p/'RTW88AWDLProtocol.hpp').write_text((root/'src/kext/RTW88AWDLProtocol.hpp').read_text())
 (p/'test.cpp').write_text(main)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined','-I'+td,'-I'+str(root/'tests/fixtures'),str(p/'RTW88AWDLManager.cpp'),str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
print('PASS: production timer/queue, peer windows, template roundtrip, malformed replacement, scan/expiry, queue bound and teardown ownership')
