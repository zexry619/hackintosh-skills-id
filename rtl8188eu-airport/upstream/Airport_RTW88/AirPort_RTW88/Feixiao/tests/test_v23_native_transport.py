"""Execute the production BSD bridge with a native-family mock and ASan/UBSan.
The mock models the verified Ventura getSSID/getCardCapabilities wire formats.
"""
from pathlib import Path
import subprocess, tempfile
src = (Path(__file__).resolve().parents[1] / 'src/kext/AirportRTW88.cpp').read_text()
a = src.index('SInt32 AirportRTW88::apple80211_ioctl(')
b = src.index('\n#if __IO80211_TARGET', a)
body = src[a:b]
prefix = r"""
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cassert>
#include <cerrno>
using SInt32=int;using UInt32=uint32_t;using ifnet_t=void*;
struct IO80211Interface{};struct IO80211VirtualInterface{};
struct apple80211req{char name[16];int req_type,req_val;uint32_t req_len;void*req_data;};
struct apple80211_channels_info{char bytes[160];};
struct apple80211_scan_result{char bytes[64];};
struct apple80211_scan_data{char bytes[80];};
struct apple80211_scan_multiple_data{char bytes[100];};
constexpr unsigned long SIOCGA80211=0xc03069c9,SIOCSA80211=0x803069c8;
constexpr int APPLE80211_IOC_CHANNELS_INFO=207,APPLE80211_IOC_SSID=1,APPLE80211_IOC_AUTH_TYPE=2,APPLE80211_IOC_CIPHER_KEY=3,
 APPLE80211_IOC_POWERSAVE=5,APPLE80211_IOC_SCAN_REQ=10,APPLE80211_IOC_SCAN_RESULT=11,
 APPLE80211_IOC_ASSOCIATE=20,APPLE80211_IOC_RSN_IE=22,APPLE80211_IOC_DISASSOCIATE=21,
 APPLE80211_IOC_SCAN_REQ_MULTIPLE=90,APPLE80211_POWERSAVE_MODE_DISABLED=0,
 APPLE80211_POWERSAVE_MODE_MAX_POWERSAVE=8,kIOReturnSuccess=0;
constexpr bool kOSBooleanTrue=true,kOSBooleanFalse=false;
int version_major=24,allocs=0,copies=0;bool failAlloc=false,failCopy=false;
void IOLog(const char*,...){}
void* IOMallocZero(size_t n){++allocs;return failAlloc?nullptr:calloc(1,n);}
void IOFree(void*p,size_t){free(p);}
int copyin(user_addr_t a,void*b,size_t n){++copies;if(failCopy)return EFAULT;memcpy(b,(void*)a,n);return 0;}
int copyout(const void*a,user_addr_t b,size_t n){++copies;if(failCopy)return EFAULT;memcpy((void*)b,a,n);return 0;}
int errnoFromReturn(int){return EIO;}
namespace RTW88AssocWire { constexpr unsigned RequestSize=900; }
struct AirportRTW88;
static bool rtw88TryHostAssociation(AirportRTW88*,IO80211Interface*,apple80211req*,SInt32*){return false;}
static bool rtw88TryAssocFromSplitWrapper(AirportRTW88*,IO80211Interface*,void*,SInt32*);
bool validAssoc=false,consumeNative=false;int fallbackCalls=0;
struct Native {
 UInt32 _nativeAssocDispatchCount=0;
 int nativeCalls=0;IO80211VirtualInterface*seenVif=nullptr;void*seenData=nullptr;int nativeRet=0;
 SInt32 apple80211_ioctl(IO80211Interface*,IO80211VirtualInterface*v,ifnet_t,unsigned long cmd,void*p){
  ++nativeCalls;seenVif=v;seenData=p;if(consumeNative)++_nativeAssocDispatchCount;
  if(p&&cmd==SIOCGA80211){auto*r=(apple80211req*)p;
   if(r->req_type==12){uint8_t caps[12]={0x12,0x34,0x56,0x78};size_t n=r->req_len<12?r->req_len:12;memcpy(r->req_data,caps,n);r->req_len=n;}
   if(r->req_type==1){size_t n=r->req_len<3?r->req_len:3;memcpy(r->req_data,"abc",n);r->req_len=n;}
  }return nativeRet;
 }
};
struct AirportRTW88:Native{
 IO80211Interface*_netif=nullptr;using super=Native;unsigned _powerSaveLevel=0;int typedCalls=0,lastSelector=0,typedRet=0;
 apple80211_scan_result result{};
 template<class...T>void setProperty(T...){}
 int apple80211Request(unsigned long,int s,IO80211Interface*,void*p){
  ++typedCalls;lastSelector=s;if(s==APPLE80211_IOC_SCAN_RESULT&&typedRet==0)*(apple80211_scan_result**)p=&result;
  return typedRet;
 }
 SInt32 apple80211_ioctl(IO80211Interface*,IO80211VirtualInterface*,ifnet_t,unsigned long,void*);
};
"""
prefix += r"""
static bool rtw88TryAssocFromSplitWrapper(AirportRTW88*a,IO80211Interface*,void*,SInt32*r){
 ++fallbackCalls;if(!validAssoc)return false;++a->_nativeAssocDispatchCount;*r=a->typedRet;return true;
}
"""
main=r"""
int main(){
 AirportRTW88 a;IO80211Interface iface;IO80211VirtualInterface vif;uint8_t data[256]={};
 apple80211req r{};r.req_data=data;r.req_len=12;r.req_type=12;
 assert(a.apple80211_ioctl(&iface,nullptr,nullptr,SIOCGA80211,&r)==0);
 assert(a.nativeCalls==1&&a.typedCalls==0&&allocs==0&&r.req_len==12&&data[0]==0x12&&data[1]==0x34);
 r.req_type=1;r.req_len=32;assert(a.apple80211_ioctl(&iface,nullptr,nullptr,SIOCGA80211,&r)==0);
 assert(r.req_len==3&&!memcmp(data,"abc",3));
 // Even a one-byte native request must never become a typed kernel buffer.
 for(int s:{2,3,12,20,22,51,99}){r.req_type=s;r.req_len=1;a.nativeRet=45;
  assert(a.apple80211_ioctl(&iface,nullptr,nullptr,SIOCSA80211,&r)==45);assert(a.typedCalls==0&&allocs==0);}
 a.nativeRet=0;r.req_type=5;r.req_len=0;r.req_val=7;
 int n=a.nativeCalls;assert(a.apple80211_ioctl(&iface,nullptr,nullptr,SIOCSA80211,&r)==0);
 assert(a._powerSaveLevel==7&&a.nativeCalls==n);
 r.req_val=9;assert(a.apple80211_ioctl(&iface,nullptr,nullptr,SIOCSA80211,&r)==EINVAL);
 r.req_type=10;r.req_len=sizeof(apple80211_scan_data)-1;
 assert(a.apple80211_ioctl(&iface,nullptr,nullptr,SIOCSA80211,&r)==EINVAL&&a.typedCalls==0);
 r.req_len=sizeof(apple80211_scan_data);
 assert(a.apple80211_ioctl(&iface,nullptr,nullptr,SIOCSA80211,&r)==0&&a.typedCalls==1);
 failCopy=true;assert(a.apple80211_ioctl(&iface,nullptr,nullptr,SIOCSA80211,&r)==EFAULT);failCopy=false;
 failAlloc=true;assert(a.apple80211_ioctl(&iface,nullptr,nullptr,SIOCSA80211,&r)==ENOMEM);failAlloc=false;
 int t=a.typedCalls;r.req_len=65537;assert(a.apple80211_ioctl(&iface,nullptr,nullptr,SIOCSA80211,&r)==EINVAL&&a.typedCalls==t);
 r.req_len=100;r.req_type=90;assert(a.apple80211_ioctl(&iface,nullptr,nullptr,SIOCSA80211,&r)==0);
 // AWDL/virtual requests must retain their routing, even for scan/powersave.
 for(int s:{10,11,5,20}){r.req_type=s;t=a.typedCalls;n=a.nativeCalls;
  assert(a.apple80211_ioctl(&iface,&vif,nullptr,SIOCSA80211,&r)==0);
  assert(a.seenVif==&vif&&a.nativeCalls==n+1&&a.typedCalls==t);}
 r.req_type=11;r.req_len=128;memset(data,0xff,sizeof(data));a.result.bytes[0]=42;
 assert(a.apple80211_ioctl(&iface,nullptr,nullptr,SIOCGA80211,&r)==0&&data[0]==42&&data[127]==0&&data[128]==0xff);
 a.typedRet=ENOENT;assert(a.apple80211_ioctl(&iface,nullptr,nullptr,SIOCGA80211,&r)==ENOENT);
 a.typedRet=0;r.req_type=207;r.req_len=159;t=a.typedCalls;
 assert(a.apple80211_ioctl(&iface,nullptr,nullptr,SIOCGA80211,&r)==EINVAL&&a.typedCalls==t);
 r.req_len=200;memset(data,0xff,sizeof(data));n=a.nativeCalls;
 assert(a.apple80211_ioctl(&iface,nullptr,nullptr,SIOCGA80211,&r)==0&&a.typedCalls==t+1&&a.nativeCalls==n&&data[199]==0&&data[200]==0xff);
 a._netif=&iface;r.req_type=20;r.req_len=900;a.nativeRet=102;validAssoc=true;
 int f=fallbackCalls;assert(a.apple80211_ioctl(&iface,nullptr,nullptr,SIOCSA80211,&r)==0&&fallbackCalls==f+1);
 consumeNative=true;f=fallbackCalls;assert(a.apple80211_ioctl(&iface,nullptr,nullptr,SIOCSA80211,&r)==102&&fallbackCalls==f);
 consumeNative=false;validAssoc=false;assert(a.apple80211_ioctl(&iface,nullptr,nullptr,SIOCSA80211,&r)==102);
 validAssoc=true;a.nativeRet=EINVAL;f=fallbackCalls;assert(a.apple80211_ioctl(&iface,nullptr,nullptr,SIOCSA80211,&r)==EINVAL&&fallbackCalls==f);
 a.nativeRet=0;version_major=22;t=a.typedCalls;n=a.nativeCalls;r.req_type=10;
 assert(a.apple80211_ioctl(&iface,nullptr,nullptr,SIOCSA80211,&r)==0&&a.nativeCalls==n+1&&a.typedCalls==t);
}
"""
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'test.cpp').write_text('#include <initializer_list>\n'+prefix+body+main)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined',str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
print('PASS: native capabilities/SSID/association routing, short buffers, AWDL interface routing, scan exceptions, powersave, copy/allocation failures, Ventura delegation (ASan/UBSan)')
