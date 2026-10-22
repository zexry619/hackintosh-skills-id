"""Run the production RX dispatcher; bad FCS must not reach either protocol."""
from pathlib import Path
import subprocess, tempfile
root = Path(__file__).resolve().parents[1]
source = (root / 'src/kext/RTW88IEEE80211.cpp').read_text()
start = source.index('void RTW88IEEE80211::rxFrame(')
end = source.index('\nvoid RTW88IEEE80211::processRxMgmt(', start)
code = r'''
#include <cassert>
#include <cstdint>
using __le16=uint16_t;
constexpr unsigned RX_FLAG_FAILED_FCS_CRC=1, RX_FLAG_NO_SIGNAL_VAL=2;
struct ieee80211_rx_status { int signal=-40; unsigned flag=0; };
struct ieee80211_hdr { __le16 frame_control; };
struct sk_buff { unsigned len=24; alignas(8) uint8_t data[40]={}; ieee80211_rx_status status; };
unsigned freed=0, mgmt=0, data=0, awdl=0, signalCalls=0;
void kfree_skb(sk_buff*) { ++freed; }
ieee80211_rx_status* IEEE80211_SKB_RXCB(sk_buff *p) { return &p->status; }
bool rtw88StationSignal(const uint8_t*,unsigned,const uint8_t*,const uint8_t*,int,bool) { ++signalCalls;return true; }
bool ieee80211_is_mgmt(__le16 fc) { return (fc&12)==0; }
bool ieee80211_is_data(__le16 fc) { return (fc&12)==8; }
struct RTW88IEEE80211 {
 uint8_t _macAddr[6]={}; struct { uint8_t bssid[6]={}; } _targetBSS;
 int _rssi=0; unsigned _rxFrameCount=0;
 void rxFrame(sk_buff*);
 void processRxMgmt(sk_buff*p) { ++mgmt;kfree_skb(p); }
 bool tryDeliverAWDLDataFrame(sk_buff*) { ++awdl;return false; }
 void processRxData(sk_buff*p) { ++data;kfree_skb(p); }
};
''' + source[start:end] + r'''
int main() {
 RTW88IEEE80211 hw; sk_buff packet;
 hw.rxFrame(nullptr); assert(freed==0);
 for(unsigned len=0;len<24;++len) { packet.len=len;hw.rxFrame(&packet); }
 assert(freed==24 && !mgmt && !awdl && !data && !signalCalls);
 packet.len=24;packet.status.flag=RX_FLAG_FAILED_FCS_CRC;
 packet.data[0]=0xd0;hw.rxFrame(&packet);
 packet.data[0]=8;hw.rxFrame(&packet);
 assert(freed==26 && !mgmt && !awdl && !data && !signalCalls && !hw._rxFrameCount);
 packet.status.flag=0;packet.data[0]=0xd0;hw.rxFrame(&packet);
 packet.data[0]=8;hw.rxFrame(&packet);
 assert(freed==28 && mgmt==1 && awdl==1 && data==1 && signalCalls==2 && hw._rxFrameCount==2);
}
'''
with tempfile.TemporaryDirectory() as td:
    path = Path(td)
    (path / 'test.cpp').write_text(code)
    subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined',str(path/'test.cpp'),'-o',str(path/'test')],check=True)
    subprocess.run([str(path/'test')],check=True)
print('PASS: production RX dispatcher drops bad FCS before STA/AWDL processing, preserves valid RX and ownership')
