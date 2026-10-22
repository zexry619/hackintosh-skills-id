"""Run the real request entry and country handler with synchronous native reentry."""
from pathlib import Path
import subprocess,tempfile
s=(Path(__file__).resolve().parents[1]/'src/kext/AirportRTW88.cpp').read_text()
def func(start):
 a=s.index(start);b=s.index('{',a);i=b+1;depth=1
 while depth:
  if s[i]=='{':depth+=1
  elif s[i]=='}':depth-=1
  i+=1
 return s[a:i]
entry=func('SInt32 AirportRTW88::apple80211Request(')
country=func('IOReturn AirportRTW88::handleRequestCOUNTRY_CODE(')
prefix=r"""
#include <cstdint>
#include <cstring>
#include <cassert>
using SInt32=int;using IOReturn=int;using UInt32=unsigned;
constexpr int APPLE80211_IOC_ASSOCIATE=20,APPLE80211_IOC_COUNTRY_CODE=51,APPLE80211_IOC_DISASSOCIATE=21;
constexpr unsigned SIOCSA80211=0x803069c8,SIOCGA80211=0xc03069c9;
constexpr int kIOReturnNotReady=1,kIOReturnBadArgument=2,kIOReturnSuccess=0,APPLE80211_VERSION=1,APPLE80211_MAX_CC_LEN=3,APPLE80211_M_COUNTRY_CODE_CHANGED=9;
constexpr bool kOSBooleanTrue=true;void kprintf(const char*,...){}void IOLog(const char*,...){}
struct IO80211Interface{void postMessage(int);};
struct apple80211_country_code_data{unsigned version;char cc[3];};
struct AirportRTW88{
 void*_ieee80211=this;UInt32 _nativeAssocDispatchCount=0;char _countryCode[3]={'U','S',0};IO80211Interface iface;IO80211Interface*_netif=&iface;int general=0;
 template<class...T>void setProperty(T...){}
 SInt32 apple80211Request(unsigned,int,IO80211Interface*,void*);
 IOReturn handleRequestCOUNTRY_CODE(bool,void*);
 SInt32 handleNativeRequest(unsigned,int,IO80211Interface*,void*){++general;return 0;}
};
AirportRTW88*active;int events=0;
void IO80211Interface::postMessage(int e){assert(e==APPLE80211_M_COUNTRY_CODE_CHANGED);++events;
 apple80211_country_code_data d{};assert(active->apple80211Request(SIOCGA80211,51,this,&d)==0);
 assert(d.version==1&&!memcmp(d.cc,"PY",3));}
"""
main=r"""
int main(){AirportRTW88 a;active=&a;apple80211_country_code_data d{1,{'P','Y',0}};
 assert(a.apple80211Request(SIOCSA80211,51,&a.iface,&d)==0&&events==1&&a.general==0);
 d.cc[0]='X';assert(a.apple80211Request(SIOCSA80211,51,&a.iface,&d)==0&&events==1);
 d.version=99;assert(a.apple80211Request(SIOCSA80211,51,&a.iface,&d)==kIOReturnBadArgument);
 assert(a.apple80211Request(SIOCGA80211,51,&a.iface,nullptr)==kIOReturnBadArgument);
 assert(a.apple80211Request(SIOCGA80211,2,&a.iface,&d)==0&&a.general==1);
}
"""
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'t.cpp').write_text(prefix+entry+country+main)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined',str(p/'t.cpp'),'-o',str(p/'t')],check=True)
 subprocess.run([str(p/'t')],check=True)
print('PASS: real COUNTRY_CODE SET -> synchronous native event -> GET, invalid version/null, special X, general dispatch (ASan/UBSan)')
