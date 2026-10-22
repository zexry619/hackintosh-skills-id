"""Execute production join identity and AWDL channel arbitration with host mocks."""
from pathlib import Path
import subprocess, tempfile
root = Path(__file__).resolve().parents[1]
s = (root/'src/kext/RTW88IEEE80211.cpp').read_text()
identity = s[s.index('bool RTW88IEEE80211::matchesPendingJoin'):s.index('/* May run on the authentication worker:')]
channel = s[s.index('IOReturn RTW88IEEE80211::setAWDLChannel'):s.index('IOReturn RTW88IEEE80211::powerOn')]
prefix = r'''
#include <cstdint>
#include <cstring>
using IOReturn=int;
constexpr int kIOReturnNotReady=1,kIOReturnUnsupported=2,kIOReturnBusy=3,kIOReturnSuccess=0;
constexpr int NL80211_NUM_BANDS=1,IEEE80211_CHAN_DISABLED=1,IEEE80211_CHAN_NO_IR=2,IEEE80211_CHAN_RADAR=4,NL80211_CHAN_WIDTH_20_NOHT=0;
constexpr int RTW88_STATE_IDLE=0,RTW88_STATE_SCANNING=1,RTW88_STATE_AUTHENTICATING=2,RTW88_STATE_ASSOCIATING=3,RTW88_STATE_HANDSHAKING=4,RTW88_STATE_CONNECTED=5;
struct ieee80211_channel {int hw_value,flags,band,center_freq;};
struct ieee80211_supported_band {int n_channels,band;ieee80211_channel *channels;};
struct Wiphy {ieee80211_supported_band* bands[1];};
struct Hw {Wiphy*wiphy;struct {struct {ieee80211_channel*chan;int width,center_freq1;}chandef;}conf;};
int switches=0;
void rtw88_awdl_switch_channel(Hw*){++switches;}
void IOLog(const char*,...){}
struct RTW88IEEE80211 {
 bool _powered=true,_pmkProvided=true;Hw*_hw=nullptr;int _state=0;uint16_t _awdlChannel=0,_awdlPreparedChannel=0;
 struct {char ssid[33]="test";uint8_t bssid[6]={1,2,3,4,5,6};} _targetBSS;
 uint8_t _pmk[32]={7};
 bool matchesPendingJoin(const char*,const uint8_t*,const uint8_t*)const;
 IOReturn setAWDLChannel(uint16_t);
};
'''
main = r'''
int main(){
 RTW88IEEE80211 obj;uint8_t key[32]={7},bssid[6]={1,2,3,4,5,6};
 if(!obj.matchesPendingJoin("test",bssid,key)||!obj.matchesPendingJoin("test",nullptr,key))return 1;
 if(obj.matchesPendingJoin("other",bssid,key)||obj.matchesPendingJoin("test",bssid,nullptr))return 2;
 key[31]=1;if(obj.matchesPendingJoin("test",bssid,key))return 3;key[31]=0;
 bssid[5]=9;if(obj.matchesPendingJoin("test",bssid,key))return 4;
 ieee80211_channel channels[]={{6,0,0,2437},{11,IEEE80211_CHAN_DISABLED,0,2462},{44,0,0,5220},{52,IEEE80211_CHAN_RADAR,0,5260},{149,IEEE80211_CHAN_NO_IR,0,5745}};
 ieee80211_supported_band band{5,0,channels};Wiphy w{{&band}};Hw hw{&w,{}};obj._hw=&hw;
 if(obj.setAWDLChannel(6)||switches!=1||obj._awdlChannel!=6)return 5;
 for(int state=1;state<5;++state){obj._state=state;if(obj.setAWDLChannel(6)!=kIOReturnBusy||switches!=1)return 6;}
 obj._state=5;if(obj.setAWDLChannel(6)!=kIOReturnSuccess||switches!=1)return 10;
 if(obj.setAWDLChannel(44)!=kIOReturnBusy||switches!=1||hw.conf.chandef.chan!=channels)return 11;
 if(obj.setAWDLChannel(52)!=kIOReturnUnsupported||switches!=1)return 12;
 if(obj.setAWDLChannel(149)!=kIOReturnUnsupported||switches!=1)return 13;
 if(obj.setAWDLChannel(6)!=kIOReturnSuccess||switches!=1)return 14;
 if(obj.setAWDLChannel(11)!=kIOReturnUnsupported||obj._awdlChannel!=6)return 7;
 if(obj.setAWDLChannel(255)!=kIOReturnUnsupported||obj._awdlChannel!=6)return 8;
 obj._powered=false;if(obj.setAWDLChannel(6)!=kIOReturnNotReady||switches!=1)return 9;
}
'''
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'test.cpp').write_text(prefix+identity+channel+main)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined',str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
print('PASS: join identity/PMK and AWDL channel ownership, invalid/disabled channels, powered-off radio')
