"""Exercise production RX handoff with chained mbufs and optional captured frame."""
from pathlib import Path
import os,re,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
base=Path(os.environ.get('RTW88_RX_SOURCE',root/'src/kext'))
a=(base/'AirportRTW88.cpp').read_text();b=(base/'AirportRTW88Interface.cpp').read_text()
a=a[a.index('void AirportRTW88::injectRxFrame('):a.index('\nnamespace {',a.index('void AirportRTW88::injectRxFrame('))]
b=b[b.index('UInt32 AirportRTW88Interface::inputPacket('):]
frame=bytearray(340);frame[12:14]=b'\x08\x00'
if os.environ.get('RTW88_CAPTURE'):
 blocks=re.split(r'(?=2026-09-21 )',Path(os.environ['RTW88_CAPTURE']).read_text())
 offer=next(block for block in blocks if 'length 1: Offer' in block)
 hexlines=[]
 for line in offer.splitlines():
  m=re.match(r'\s*0x[0-9a-f]+:\s+((?:[0-9a-f]{4}\s+)+)',line)
  if m:hexlines.append(''.join(m.group(1).split()))
 frame=bytes.fromhex(''.join(hexlines))
code=r'''
#include <cstdint>
#include <cstddef>
#include <cassert>
#include <vector>
using UInt32=uint32_t;using IOOptionBits=uint32_t;
struct Packet {std::vector<uint8_t> bytes;size_t first;bool freed=false;};using mbuf_t=Packet*;
size_t mbuf_len(mbuf_t p){return p->first;}size_t mbuf_pkthdr_len(mbuf_t p){return p->bytes.size();}
void*mbuf_data(mbuf_t p){return p->bytes.data();}void mbuf_freem(mbuf_t p){assert(!p->freed);p->freed=true;}
#define IOLog(...) ((void)0)
int ethernet=0,eapol=0,flushes=0;size_t deliveredLength=0;std::vector<uint8_t> delivered;
struct IONetworkInterface {static constexpr unsigned kInputOptionQueuePacket=1;};
struct IOEthernetInterface:IONetworkInterface {
 UInt32 inputPacket(mbuf_t p,UInt32 n,IOOptionBits options,void*){assert(options==0);assert(n==p->bytes.size());++ethernet;delivered=p->bytes;deliveredLength=n;return 1;}
};
struct IO80211Interface:IOEthernetInterface {
 UInt32 inputPacket(mbuf_t p,UInt32 n,IOOptionBits options,void*){assert(!options);assert(n==p->bytes.size());++eapol;delivered=p->bytes;deliveredLength=n;return 1;}
};
struct AirportRTW88Interface:IO80211Interface {
 UInt32 inputPacket(mbuf_t,UInt32=0,IOOptionBits=0,void*=nullptr);
 UInt32 flushInputQueue(){++flushes;return 1;}
};
struct AirportRTW88{AirportRTW88Interface*_netif;void injectRxFrame(mbuf_t);};
'''.replace('void*=nullptr','void * = nullptr')+b+a
code+='\nconst uint8_t captured[]={'+','.join(str(v) for v in frame)+'};\n'
code+=r'''
int main(){
 AirportRTW88Interface iface;AirportRTW88 driver{&iface};
 for(int i=0;i<100;++i){Packet p{{captured,captured+sizeof(captured)},64};driver.injectRxFrame(&p);assert(delivered==p.bytes&&!p.freed);}
 assert(ethernet==100&&!flushes);
 Packet e{{captured,captured+sizeof(captured)},64};e.bytes[12]=0x88;e.bytes[13]=0x8e;driver.injectRxFrame(&e);assert(eapol==1&&deliveredLength==e.bytes.size());
 Packet bad{std::vector<uint8_t>(13),13};driver.injectRxFrame(&bad);assert(bad.freed);
 Packet large{std::vector<uint8_t>(4097),64};driver.injectRxFrame(&large);assert(large.freed);
 driver._netif=nullptr;Packet detached{{captured,captured+sizeof(captured)},64};driver.injectRxFrame(&detached);assert(detached.freed);
 driver.injectRxFrame(nullptr);assert(ethernet==100&&eapol==1&&!flushes);
}
'''
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'t.cpp').write_text(code)
 flags=[] if os.environ.get('RTW88_SANITIZERS')=='0' else ['-fsanitize=address,undefined']
 subprocess.run(['xcrun','clang++','-std=c++17']+flags+[str(p/'t.cpp'),'-o',str(p/'t')],check=True)
 subprocess.run([str(p/'t')],check=True)
print('PASS: production immediate Ethernet RX handoff, byte preservation, 100 packets, chained EAPOL length, invalid/detached ownership; mocked interface, not IP/DHCP or radio validation')
