"""Exercise production AWDL bootstrap with no Apple template (v40 failure)."""
from pathlib import Path
import ast,re,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
fixture=ast.parse((root/'tests/test_v22_awdl_manager_runtime.py').read_text())
stubs=next(ast.literal_eval(n.value) for n in fixture.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='stubs' for t in n.targets))
main=r'''
#include "RTW88AWDLManager.hpp"
int main(){
 RTW88IEEE80211 hw;IOWorkLoop loop;IOService owner;IO80211VirtualInterface vif;
 uint8_t local[]={2,1,2,3,4,5},remote[]={2,1,2,3,4,9};
 RTW88AWDLManager m;assert(m.init(&hw,&loop,&owner,[](OSObject*,IOTimerEventSource*){}));
 assert(!m.scheduleReady());m.setVirtualInterface(4,&vif);assert(!m.scheduleReady());
 // 2.0.0 gives IO80211 a grace period before native/OpenAWDL fallback.
 m.setLocalAddress(local);assert(!m.scheduleReady());
 testNow+=1600000;m.tick();assert(m.scheduleReady());
 unsigned bootstrapActions=hw.actions;
 if(!bootstrapActions){testNow+=4096;m.tick();}
 assert(hw.actions>=1&&hw.channel==6);
 RTW88AWDL::Action a;assert(RTW88AWDL::parseAction(hw.last.data(),hw.last.size(),a));
 assert(a.electionValid&&a.height==0&&a.masterMetric==60&&!memcmp(a.master,local,6));
 assert(hw.last.size()==255&&hw.last[30]==0);
 for(int i=0;i<16;++i)assert(a.sequence.channel[i]==6);
 // The encoder must never write to an insufficient output buffer.
 uint8_t frame[RTW88AWDL::NativeFrameSize+2];memset(frame,0xa5,sizeof(frame));
 for(size_t cap=0;cap<RTW88AWDL::NativeFrameSize;++cap)assert(!RTW88AWDL::buildNativeAction(frame+1,cap,local,a,0));
 assert(frame[1]==0xa5);
 // A stronger peer on channel 6 becomes our synchronization parent.
 memcpy(a.master,remote,6);memcpy(a.syncAddress,remote,6);a.masterMetric=100;a.masterCounter=7;
 auto n=RTW88AWDL::buildNativeAction(frame+1,sizeof(frame)-2,remote,a,3);
 assert(n==255&&frame[0]==0xa5&&frame[256]==0xa5);
 RTW88AWDL::Action peer;assert(RTW88AWDL::parseAction(frame+1,n,peer));
 // Truncated and malformed election data are rejected atomically.
 for(size_t len=0;len<n;++len){RTW88AWDL::Action tmp;RTW88AWDL::parseAction(frame+1,len,tmp);}
 auto corrupt=std::vector<uint8_t>(frame+1,frame+1+n);corrupt[40+1]=0xff;
 m.observeAction(corrupt.data(),corrupt.size());m.publishStats();assert(owner.props["AWDL_ACTION_RX"]==0);
 assert(owner.strings["AWDL_REJECT_REASON"]=="truncated-tlv");
 assert(owner.props["AWDL_REJECT_OFFSET"]==40);
 assert(owner.blobs["AWDL_REJECT_FRAME"]==corrupt);
 auto second=corrupt;second[42]=1;m.observeAction(second.data(),second.size());
 assert(owner.blobs["AWDL_REJECT_FRAME"]==corrupt); // rate limited, count still increases
 m.publishStats();assert(owner.props["AWDL_ACTION_PARSE_REJECTED"]==2);
 m.observeAction(frame+1,n);m.publishStats();assert(owner.props["AWDL_SYNC_UPDATES"]==1);
 bool sawMIF=false;for(int i=0;i<40&&!sawMIF;++i){testNow+=4000;m.tick();m.publishStats();sawMIF=owner.props["AWDL_MIF_TX"]>0;}
 assert(sawMIF);
 RTW88AWDL::Action adopted;assert(RTW88AWDL::parseAction(hw.last.data(),hw.last.size(),adopted));
 assert(adopted.height==1&&adopted.masterCounter==7&&!memcmp(adopted.master,remote,6));
 // A packet queued for this neighbor can leave in a common window.
 auto*p=new Packet;p->bytes.resize(80);memcpy(p->bytes.data(),remote,6);++mbufs;
 assert(m.enqueueData(p));m.tick();assert(hw.data==1);
 m.noteDataRX(0);m.publishStats();assert(owner.props["AWDL_DATA_RX"]==1);
 // Expired master returns to discovery; radio OFF must not send anything.
 testNow+=3100000;m.tick();testNow+=4096;m.tick();
 assert(RTW88AWDL::parseAction(hw.last.data(),hw.last.size(),adopted));
 assert(adopted.height==0&&!memcmp(adopted.master,local,6));
 unsigned sent=hw.actions;hw.powered=false;testNow+=200000;m.tick();assert(hw.actions==sent);
 hw.powered=true;m.setSyncEnabled(false);testNow+=200000;assert(!m.tick());
 m.setSyncEnabled(true);assert(m.scheduleReady());
 // A genuine Apple template replaces the fallback and roundtrips unchanged.
 assert(m.setSyncFrameTemplate(frame+1,n)==0);uint8_t copy[300];uint32_t length=sizeof(copy);
 assert(!m.copySyncFrameTemplate(copy,&length)&&length==n&&!memcmp(copy,frame+1,n));
 m.reset();assert(allocations==0&&mbufs==0&&loop.attached==0);
 // Many hostile radio payloads exercise bounded TLV reads under sanitizers.
 uint32_t random=1;uint8_t bytes[512];
 for(int round=0;round<10000;++round){for(auto &v:bytes){random=random*1664525+1013904223;v=random>>24;}RTW88AWDL::Action parsed;RTW88AWDL::parseAction(bytes,random%sizeof(bytes),parsed);}
}
'''
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'stubs.hpp').write_text(stubs)
 for name in ['RTW88AWDLManager.cpp','RTW88AWDLManager.hpp']:
  s=(root/'src/kext'/name).read_text();s=re.sub(r'^#include <[^\n]+>\n','',s,flags=re.M).replace('#include "RTW88IEEE80211.hpp"','')
  (p/name).write_text('#include "stubs.hpp"\n'+s)
 (p/'RTW88AWDLProtocol.hpp').write_text((root/'src/kext/RTW88AWDLProtocol.hpp').read_text())
 (p/'test.cpp').write_text(main)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined','-I'+td,str(p/'RTW88AWDLManager.cpp'),str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
print('PASS: absent-template bootstrap, PSF/MIF, peer synchronization, unicast queue, expiry, OFF, Apple takeover, malformed frames and ownership (ASan/UBSan)')
