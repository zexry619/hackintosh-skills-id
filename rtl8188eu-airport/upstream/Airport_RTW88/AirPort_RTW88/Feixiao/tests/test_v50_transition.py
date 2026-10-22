"""Execute transition code with completion delivered inside scan cancellation."""
from pathlib import Path
import subprocess,tempfile,os
root=Path(__file__).resolve().parents[1]
base=Path(os.environ.get('RTW88_TEST_DIR',root/'src/kext'))
s=(base/'RTW88IEEE80211.cpp').read_text();a=(base/'AirportRTW88.cpp').read_text()
def cut(text,start,end):
 i=text.index(start);return text[i:text.index(end,i)]
clear=cut(s,'void RTW88IEEE80211::clearDeferredJoin()','void RTW88IEEE80211::cancelAuthentication()') if 'void RTW88IEEE80211::clearDeferredJoin()' in s else 'void RTW88IEEE80211::clearDeferredJoin() {}\n'
power=cut(s,'IOReturn RTW88IEEE80211::cmdPowerOff()','void RTW88IEEE80211::doDisconnect()')
disc=cut(s,'IOReturn RTW88IEEE80211::cmdDisconnect()','IOReturn RTW88IEEE80211::cmdPowerOn()')
i=a.index('    RTW88StateResult current = {};',a.index('IOReturn AirportRTW88::handleASSOCIATE'))
switch=a[i:a.index('    _authLower =',i)]
code=r'''
#include <cassert>
#include <cstring>
using IOReturn=int;
constexpr int kIOReturnSuccess=0,kIOReturnBusy=2,kIONetworkLinkValid=1;
constexpr bool kOSBooleanTrue=true,kOSBooleanFalse=false;
enum State{RTW88_STATE_IDLE,RTW88_STATE_SCANNING,RTW88_STATE_CONNECTED,RTW88_STATE_AUTHENTICATING,RTW88_STATE_ASSOCIATING,RTW88_STATE_HANDSHAKING};
struct RTW88StateResult{State state;};
#define IOLog(...) ((void)0)
struct Parent{void setLinkStatus(int){}};
struct RTW88IEEE80211 {
 bool _deferredConnectPending=true,_deferredPMKValid=true,_deferredBSSIDValid=true,_deferredExternalSupplicant=true;
 char _deferredSSID[33]={'x'},_deferredPassword[65]={'x'};unsigned char _deferredPMK[32]={1},_deferredBSSID[6]={2};
 State _state=RTW88_STATE_SCANNING,_scanReturnState=RTW88_STATE_IDLE;
 bool _associatedVisible=false,_powered=true,abortOK=true,same=false;
 int staleJoins=0,disconnects=0,clears=0,releases=0,cancels=0;Parent*_parent=nullptr;
 void clearDeferredJoin();IOReturn cmdPowerOff();IOReturn cmdDisconnect();
 void cancelAuthentication(){++cancels;}
 bool abortActiveScan(bool){if(_deferredConnectPending&&_powered)++staleJoins;if(abortOK)_state=RTW88_STATE_IDLE;return abortOK;}
 void clearKeys(){++clears;}void releaseSta(){++releases;}void clearAssocRsnIE(){}
 void doDisconnect(){++disconnects;clearKeys();releaseSta();_state=RTW88_STATE_IDLE;}
 void powerOff(){_powered=false;}
 int cmdGetState(RTW88StateResult*s){s->state=_state;return 0;}
 bool matchesPendingJoin(const char*,const unsigned char*,const unsigned char*){return same;}
};
struct AirportRTW88{RTW88IEEE80211*_ieee80211;void setProperty(const char*,bool){};int prepare(const char*ssid,const unsigned char*bssid,const unsigned char*pmk){
'''+switch+r'''
return 9; // reached installation of new RSN/association request
}};
'''+clear+power+disc+r'''
int main(){
 for(int i=0;i<100;i++){
  RTW88IEEE80211 d;assert(d.cmdPowerOff()==0);assert(!d.staleJoins&&!d._powered);
  assert(!d._deferredConnectPending&&!d._deferredPMKValid&&!d._deferredBSSIDValid&&!d._deferredExternalSupplicant);
  assert(!d._deferredSSID[0]&&!d._deferredPassword[0]&&!d._deferredPMK[0]&&!d._deferredBSSID[0]);
 }
 RTW88IEEE80211 blocked;blocked.abortOK=false;assert(blocked.cmdPowerOff()==kIOReturnBusy);assert(!blocked.staleJoins&&!blocked._deferredConnectPending&&blocked._powered);
 for(auto state:{RTW88_STATE_IDLE,RTW88_STATE_SCANNING,RTW88_STATE_CONNECTED,RTW88_STATE_AUTHENTICATING,RTW88_STATE_ASSOCIATING,RTW88_STATE_HANDSHAKING}){
  RTW88IEEE80211 d;d._state=state;assert(d.cmdDisconnect()==0);assert(!d._deferredConnectPending);
  if(state==RTW88_STATE_SCANNING)assert(d._state==state&&!d.disconnects);
 }
 for(auto state:{RTW88_STATE_CONNECTED,RTW88_STATE_AUTHENTICATING,RTW88_STATE_ASSOCIATING,RTW88_STATE_HANDSHAKING}){
  RTW88IEEE80211 d;d._state=state;AirportRTW88 controller{&d};
  d.same=true;assert(controller.prepare("A",nullptr,nullptr)==0);assert(!d.disconnects);
  d.same=false;assert(controller.prepare("B",nullptr,nullptr)==9);assert(d.disconnects==1&&d.cancels==1&&d.clears==1&&d.releases==1&&d._state==RTW88_STATE_IDLE);
 }
}
'''
code='#include <initializer_list>\n'+code
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'t.cpp').write_text(code)
 subprocess.run(['xcrun','clang++','-std=c++17']+([] if os.environ.get('RTW88_SANITIZERS')=='0' else ['-fsanitize=address,undefined'])+[str(p/'t.cpp'),'-o',str(p/'t')],check=True)
 subprocess.run([str(p/'t')],check=True)
print('PASS: production power/disconnect and association transition; 100 shutdown cycles, completion during abort, abort failure, duplicate join, network replacement and old-link cleanup')
