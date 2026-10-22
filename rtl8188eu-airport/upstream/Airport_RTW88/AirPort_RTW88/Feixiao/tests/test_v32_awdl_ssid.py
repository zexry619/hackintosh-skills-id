from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'src/kext/AirportRTW88AWDL.cpp').read_text();a=s.index('    case APPLE80211_IOC_SSID: {');b=s.index('    case APPLE80211_IOC_CHANNEL:',a)
code=r'''
#include <cassert>
#include <cstring>
#include <cstdint>
constexpr int APPLE80211_IOC_SSID=1,APPLE80211_VIF_AWDL=4,APPLE80211_VERSION=1;
constexpr int kIOReturnSuccess=0,kIOReturnBadArgument=22,kIOReturnUnsupported=45;
struct apple80211_ssid_data {uint32_t version,ssid_len;uint8_t ssid_bytes[32];};
void bzero(void*p,size_t n){memset(p,0,n);}
int forwards=0;void*_netif=nullptr;
int apple80211Request(int,int,void*,void*){++forwards;return 6;}
int get(int role,bool set,void*data){int request_type=0,request_number=1;switch(request_number){
'''+s[a:b]+r'''}return 99;}
int main(){apple80211_ssid_data d;memset(&d,0xa5,sizeof(d));
 assert(get(4,false,&d)==0&&forwards==0&&d.version==1&&d.ssid_len==0);
 for(auto c:d.ssid_bytes)assert(c==0);
 assert(get(4,true,&d)==45&&forwards==0);
 assert(get(4,false,nullptr)==22);
 assert(get(1,false,&d)==6&&forwards==1);
}
'''
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'t.cpp').write_text(code)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined',str(p/'t.cpp'),'-o',str(p/'t')],check=True)
 subprocess.run([str(p/'t')],check=True)
print('PASS: AWDL SSID query independent of disconnected STA; empty initialized response; SET/null validation; other roles preserved')
