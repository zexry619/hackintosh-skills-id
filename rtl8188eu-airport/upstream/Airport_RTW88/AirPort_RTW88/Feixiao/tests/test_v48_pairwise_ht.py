"""Run production cipher gate, channel width and aggregation-start methods."""
from pathlib import Path
import subprocess, tempfile, os
root=Path(__file__).resolve().parents[1]
s=Path(os.environ.get('RTW88_TEST_SOURCE',root/'src/kext/RTW88IEEE80211.cpp')).read_text()
def method(start,end):
    a=s.index(start);return s[a:s.index(end,a)]
code=r'''
#include <cstdint>
#include <cassert>
#include <cstring>
#define IOLog(...) ((void)0)
constexpr uint32_t WLAN_CIPHER_SUITE_TKIP=0x000fac02, WLAN_CIPHER_SUITE_CCMP=0x000fac04;
enum nl80211_band {NL80211_BAND_2GHZ,NL80211_BAND_5GHZ};
constexpr int NL80211_CHAN_WIDTH_20_NOHT=0, NL80211_CHAN_WIDTH_40=1, NL80211_CHAN_WIDTH_80=2;
constexpr int IEEE80211_HT_CAP_SUP_WIDTH_20_40=2,WLAN_EID_HT_OPERATION=61,WLAN_EID_VHT_OPERATION=192;
struct ieee80211_channel {uint32_t center_freq;};
struct ieee80211_supported_band {struct {uint16_t cap;bool ht_supported;} ht_cap; struct {bool vht_supported;}vht_cap;};
struct Wiphy {ieee80211_supported_band* bands[2];};
struct Hw {Wiphy*wiphy;struct{struct {ieee80211_channel*chan;int width;uint32_t center_freq1;}chandef;}conf;};
struct Sta {struct{struct{bool ht_supported;}ht_cap;}deflink;};
struct RTW88IEEE80211 {
 struct {uint32_t cipher,group_cipher;uint8_t channel;uint8_t ies[512];uint16_t ies_len;} _targetBSS{};
 Hw*_hw=nullptr; Sta*_sta=nullptr;unsigned _connChanWidth=0;bool _txBaActive=false;unsigned _baTid=0,requests=0;
 bool htAllowed()const; void setConnectedChandef(ieee80211_channel*);void startTxAggregation();
 void sendAddbaRequest(unsigned){++requests;}
};
'''
code+=method('bool RTW88IEEE80211::htAllowed() const','void RTW88IEEE80211::handleBackAction(')
code+=method('void RTW88IEEE80211::setConnectedChandef(','/* ------------------------------------------------------------------ */\n/*  Scan')
code+=r'''
int main(){
 ieee80211_supported_band b2{{2,true},{false}},b5{{2,true},{true}};
 Wiphy w{{&b2,&b5}};Hw hw{&w,{}};Sta sta{{{true}}};ieee80211_channel ch{5500};
 RTW88IEEE80211 d;d._hw=&hw;d._sta=&sta;d._targetBSS.channel=100;
 const uint8_t ies[]={61,2,100,5,192,3,1,106,0};
 memcpy(d._targetBSS.ies,ies,sizeof(ies));d._targetBSS.ies_len=sizeof(ies);
 for(uint32_t group:{WLAN_CIPHER_SUITE_TKIP,WLAN_CIPHER_SUITE_CCMP,uint32_t(0)}){
  for(uint32_t pair:{WLAN_CIPHER_SUITE_CCMP,uint32_t(0),WLAN_CIPHER_SUITE_TKIP,uint32_t(0x000fac01)}){
   d._targetBSS.cipher=pair;d._targetBSS.group_cipher=group;d.requests=0;
   bool allowed=pair==0||pair==WLAN_CIPHER_SUITE_CCMP;
   assert(d.htAllowed()==allowed);d.setConnectedChandef(&ch);d.startTxAggregation();
   assert(d._connChanWidth==(allowed?80u:20u));assert(d.requests==(allowed?1u:0u));
   assert(d._targetBSS.group_cipher==group);
  }
 }
 d._targetBSS.cipher=WLAN_CIPHER_SUITE_CCMP;d._targetBSS.group_cipher=WLAN_CIPHER_SUITE_TKIP;
 d._targetBSS.ies_len=0;d.setConnectedChandef(&ch);assert(d._connChanWidth==20);
 d._targetBSS.ies_len=sizeof(ies);d._targetBSS.channel=1;ch.center_freq=2412;
 d.setConnectedChandef(&ch);assert(d._connChanWidth==40); // never VHT/80 on 2.4 GHz
 d._txBaActive=true;d.requests=0;d.startTxAggregation();assert(!d.requests);
 d._txBaActive=false;sta.deflink.ht_cap.ht_supported=false;d.startTxAggregation();assert(!d.requests);
 d._sta=nullptr;d.startTxAggregation();assert(!d.requests);
}
'''
code='#include <initializer_list>\n'+code
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'test.cpp').write_text(code)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined',str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
print('PASS: production HT gate, AP-advertised widths and aggregation start; CCMP/TKIP group, legacy rejection, no invented 80 MHz, already active/no HT/no peer')
