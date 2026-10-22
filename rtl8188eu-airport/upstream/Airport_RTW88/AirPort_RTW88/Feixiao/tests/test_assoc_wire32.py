"""Reproduce the captured misread fields; execute the production wire decoder."""
from pathlib import Path
import os,subprocess,tempfile
sanitizers=os.environ.get("RTW88_TEST_SANITIZERS", "address,undefined")
r=Path(__file__).resolve().parents[1]
code=r"""
#include "RTW88AssocWire.hpp"
#include <cassert>
#include <vector>
using namespace RTW88AssocWire;
void put(std::vector<uint8_t>&p,unsigned o,uint32_t v){for(unsigned i=0;i<4;i++)p[o+i]=v>>(i*8);}
int main(){
 std::vector<uint8_t> p(RequestSize);put(p,0,1);put(p,4,2);put(p,8,1);put(p,12,8);
 const char*ssid="SyntheticPhone!";put(p,16,15);memcpy(p.data()+20,ssid,15);
 p[52]=2;put(p,60,1);put(p,64,32);put(p,68,11);
 for(unsigned i=0;i<32;i++)p[76+i]=uint8_t(i+1);
 // These are exactly the v26 observations produced by the wrong layout.
 assert((p[6]|p[7]<<8)==0&&(p[8]|p[9]<<8)==1&&le32(p.data()+12)==8&&le32(p.data()+60)==1);
 Personal a{};assert(decode(p.data(),PrefixSize,a));
 assert(a.lower==1&&a.upper==8&&a.ssidLength==15&&a.keyLength==32);
 assert(!memcmp(a.ssid,ssid,15)&&a.bssid[0]==2&&a.key[31]==32);
 for(size_t i=0;i<PrefixSize;i++)assert(!decode(p.data(),i,a));
 auto bad=p;put(bad,64,33);assert(!decode(bad.data(),PrefixSize,a));
 bad=p;put(bad,16,33);assert(!decode(bad.data(),PrefixSize,a));
 bad=p;put(bad,8,0);assert(!decode(bad.data(),PrefixSize,a));
 bad=p;put(bad,12,4);assert(!decode(bad.data(),PrefixSize,a));
 bad=p;put(bad,60,0);assert(!decode(bad.data(),PrefixSize,a));
 bad=p;bad[52]=1;assert(!decode(bad.data(),PrefixSize,a));
 bad=p;bad[22]=0;assert(!decode(bad.data(),PrefixSize,a));
 bad=p;put(bad,12,0);put(bad,64,0);assert(decode(bad.data(),PrefixSize,a)&&a.keyLength==0);
 wipe(&a,sizeof(a));for(auto c:std::vector<uint8_t>((uint8_t*)&a,(uint8_t*)&a+sizeof(a)))assert(c==0);
 uint32_t seed=123;for(unsigned i=0;i<100000;i++){
  bad=p;seed=seed*1664525+1013904223;bad[seed%PrefixSize]^=uint8_t(seed>>24);
  if(decode(bad.data(),PrefixSize,a))assert(a.ssidLength<=32&&a.lower==1&&(a.keyLength==0||a.keyLength==32));
 }
}
"""

# Exercise the production adapter, including return mapping and no dispatch on
# malformed data. The legacy prefix below matches the fields this adapter uses.
source=(r/'src/kext/AirportRTW88.cpp').read_text()
a=source.index('static bool rtw88TryHostAssociation(');b=source.index('\n}\n}',a)+2
adapter=source[a:b]
# Execute the production ingress branch as well as the adapter. v36's adapter
# test passed even though its caller still rejected the Tahoe envelope.
gate_start=source.index('    if (isSet && req->req_type == APPLE80211_IOC_ASSOCIATE && !virtualInterface &&')
gate_end=source.index('    const bool scanBridge',gate_start)
gate=source[gate_start:gate_end].replace('rtw88TryHostAssociation(this,', 'rtw88TryHostAssociation(self,')

stubs=r"""
using SInt32=int;using user_addr_t=unsigned long long;
constexpr int APPLE80211_VERSION=1,SIOCSA80211=1,APPLE80211_IOC_ASSOCIATE=20,kIOReturnSuccess=0;
constexpr bool kOSBooleanTrue=true;
struct IO80211Interface{};
struct apple80211req{void*req_data;unsigned req_len;unsigned req_type=20;};
struct Key{unsigned version,key_len,key_cipher_type;unsigned short flags,index;unsigned char key[32];};
struct apple80211_assoc_data{unsigned version;unsigned short ad_mode,ad_auth_lower,ad_auth_upper;unsigned ad_ssid_len;unsigned char ad_ssid[32];struct{unsigned char octet[6];}ad_bssid;Key ad_key;};
int copyin(user_addr_t a,void*b,size_t n){memcpy(b,(void*)a,n);return 0;}
struct AirportRTW88{
 int calls=0,reply=0;
 template<class...T>void setProperty(T...){}
 int errnoFromReturn(int){return 45;}
 int apple80211Request(int,int,IO80211Interface*,void*data){
  auto*d=(apple80211_assoc_data*)data;++calls;
  assert(d->ad_auth_lower==1&&d->ad_auth_upper==8&&d->ad_ssid_len==15&&d->ad_key.key_len==32);
  assert(d->ad_key.key[31]==32&&!memcmp(d->ad_ssid,"SyntheticPhone!",15));return reply;
 }
};
"""
ingress="""
int ingress(AirportRTW88*self,IO80211Interface*interface,IO80211Interface*_netif,
            bool isSet,void*virtualInterface,apple80211req*req){
 const unsigned len=req->req_len;
"""+gate+" return 999; }\n"
code=code.replace('int main(){',stubs+adapter+ingress+'\nint main(){')
needle=' Personal a{};assert(decode(p.data(),PrefixSize,a));'
code=code.replace(needle,r"""
 AirportRTW88 driver;IO80211Interface iface;apple80211req req{p.data(),900};SInt32 ret=-1;
 assert(rtw88TryHostAssociation(&driver,&iface,&req,&ret)&&ret==0&&driver.calls==1);
 driver.reply=-123;assert(rtw88TryHostAssociation(&driver,&iface,&req,&ret)&&ret==45&&driver.calls==2);
 req.req_len=899;assert(!rtw88TryHostAssociation(&driver,&iface,&req,&ret)&&driver.calls==2);
 // Tahoe's extended envelope uses the same validated prefix; tail is opaque.
 auto tahoe=p;tahoe.resize(908,0xa5);req.req_data=tahoe.data();req.req_len=908;
 driver.reply=0;assert(rtw88TryHostAssociation(&driver,&iface,&req,&ret)&&ret==0&&driver.calls==3);
 AirportRTW88 routed;
 assert(ingress(&routed,&iface,&iface,true,nullptr,&req)==0&&routed.calls==1);
 req.req_len=900;assert(ingress(&routed,&iface,&iface,true,nullptr,&req)==0&&routed.calls==2);
 req.req_len=908;
 assert(ingress(&routed,&iface,&iface,false,nullptr,&req)==999);
 assert(ingress(&routed,&iface,&iface,true,&iface,&req)==999);
 IO80211Interface other;assert(ingress(&routed,&other,&iface,true,nullptr,&req)==999);
 req.req_type=1;assert(ingress(&routed,&iface,&iface,true,nullptr,&req)==999);req.req_type=20;
 assert(routed.calls==2);

 for(unsigned n: {0u,107u,899u,901u,907u,909u,65535u}){
  req.req_len=n;assert(ingress(&routed,&iface,&iface,true,nullptr,&req)==999);assert(!rtw88TryHostAssociation(&driver,&iface,&req,&ret)&&driver.calls==3);
 }
 put(tahoe,64,31);req.req_len=908;
 assert(!rtw88TryHostAssociation(&driver,&iface,&req,&ret)&&driver.calls==3);
 req.req_data=nullptr;assert(!rtw88TryHostAssociation(&driver,&iface,&req,&ret)&&driver.calls==3);
 req.req_len=900;auto invalid=p;put(invalid,64,31);req.req_data=invalid.data();
 assert(!rtw88TryHostAssociation(&driver,&iface,&req,&ret)&&driver.calls==3);
"""+needle)
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'t.cpp').write_text(code)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize='+sanitizers,'-I'+str(r/'src/kext'),str(p/'t.cpp'),'-o',str(p/'t')],check=True)
 subprocess.run([str(p/'t')],check=True)
print('PASS ('+sanitizers+'): captured 0/1/8/1 misread reproduced, WPA2/open conversion, lengths, malformed auth/key/SSID, wipe and 100000 mutations')
