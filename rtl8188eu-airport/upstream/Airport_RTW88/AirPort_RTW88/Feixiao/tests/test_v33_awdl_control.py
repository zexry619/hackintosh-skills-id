from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1];s=(r/'src/kext/AirportRTW88AWDL.cpp').read_text()
a=s.index('    case APPLE80211_IOC_STATE:');b=s.index('    case APPLE80211_IOC_SSID:',a)
code=r'''
#include <cassert>
#include <cstring>
#include <cstdint>
constexpr int APPLE80211_IOC_STATE=12,APPLE80211_IOC_BSSID=9,APPLE80211_IOC_AUTH_TYPE=10,APPLE80211_VIF_AWDL=4;
constexpr int APPLE80211_VERSION=1,APPLE80211_S_RUN=4,APPLE80211_S_INIT=0,APPLE80211_AUTHTYPE_OPEN=1,APPLE80211_AUTHTYPE_NONE=0;
constexpr int kIOReturnSuccess=0,kIOReturnBadArgument=22,kIOReturnUnsupported=45,kIOReturnNotReady=6;
struct apple80211_state_data{uint32_t version,state;};
struct apple80211_bssid_data{uint32_t version;struct{uint8_t octet[6];}bssid;};
struct apple80211_authtype_data{uint32_t version,authtype_lower,authtype_upper;};
struct Manager{void*v=nullptr;bool enabled=true;void*awdlInterface(){return v;}bool syncEnabled(){return enabled;}
void getBSSID(uint8_t*p){uint8_t b[]={0,0x25,0,0xff,0x94,0x73};memcpy(p,b,6);}};
Manager*_awdlManager=nullptr;void*_netif=nullptr;int forwarded=0;
int apple80211Request(int,int,void*,void*){++forwarded;return 99;}
int query(int request_number,int role,bool set,void*data,void*interface){int request_type=0;switch(request_number){
'''+s[a:b]+r'''}return 100;}
int main(){Manager m;int iface;m.v=&iface;_awdlManager=&m;
apple80211_state_data st={};assert(query(12,4,false,&st,&iface)==0&&st.state==4&&forwarded==0);
m.enabled=false;assert(query(12,4,false,&st,&iface)==0&&st.state==0);m.enabled=true;
assert(query(12,4,false,&st,nullptr)==0&&st.state==0);
apple80211_bssid_data b={};assert(query(9,4,false,&b,&iface)==0&&b.bssid.octet[1]==0x25&&b.bssid.octet[5]==0x73);
apple80211_authtype_data auth={};assert(query(10,4,false,&auth,&iface)==0&&auth.authtype_lower==1&&auth.authtype_upper==0);
assert(query(12,1,false,&st,&iface)==99&&forwarded==1);
assert(query(12,4,true,&st,&iface)==45);assert(query(12,4,false,nullptr,&iface)==22);
_awdlManager=nullptr;assert(query(12,4,false,&st,&iface)==6);
}
'''
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'t.cpp').write_text(code)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined',str(p/'t.cpp'),'-o',str(p/'t')],check=True)
 subprocess.run([str(p/'t')],check=True)
print('PASS: AWDL lifecycle state, BSSID and auth independent of STA; disabled/missing VIF, validation and other roles')
