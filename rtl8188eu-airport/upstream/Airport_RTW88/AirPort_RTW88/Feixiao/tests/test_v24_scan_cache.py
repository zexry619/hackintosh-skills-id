"""Execute production scan cache reads during overlapping physical scans."""
from pathlib import Path
import subprocess,tempfile
s=(Path(__file__).resolve().parents[1]/'src/kext/AirportRTW88.cpp').read_text()
body=s[s.index('IOReturn AirportRTW88::handleSCAN_RESULT('):s.index('IOReturn AirportRTW88::handleCURRENT_NETWORK(')]
prefix=r"""
#include <cstdint>
#include <cassert>
using IOReturn=int;
constexpr int kIOReturnBadArgument=1,kIOReturnBusy=2,kIOReturnNotFound=3,kIOReturnSuccess=0,RTW88_STATE_IDLE=0;
constexpr bool kOSBooleanTrue=true,kOSBooleanFalse=false;int version_major=24;
void IOLog(const char*,...){}
struct RTW88BSS{int id=0;};struct RTW88StateResult{int state=0;};struct apple80211_scan_result{int id=0;};
struct Backend{
 int count=2,scans=0,scanReturn=0;
 int copyScanBSS(unsigned i,RTW88BSS*b){if(i>=(unsigned)count)return kIOReturnNotFound;b->id=i+1;return 0;}
 int cmdGetState(RTW88StateResult*s){s->state=0;return 0;}
 int cmdScan(){++scans;return scanReturn;}
};
struct AirportRTW88{
 bool _scanInProgress=true,_scanCacheBootstrapAttempted=false;unsigned _scanCursor=0;
 Backend backend;Backend*_ieee80211=&backend;apple80211_scan_result _scanResult;
 template<class...T>void setProperty(T...){}
 void fillScanResultFromBSS(const RTW88BSS&b,apple80211_scan_result*r,bool){r->id=b.id;}
 int handleSCAN_RESULT(apple80211_scan_result**);
};
"""
main=r"""
int main(){
 AirportRTW88 a;apple80211_scan_result*r=nullptr;
 assert(a.handleSCAN_RESULT(&r)==0&&r&&r->id==1);
 assert(a.handleSCAN_RESULT(&r)==0&&r->id==2);
 assert(a.handleSCAN_RESULT(&r)==5&&r==nullptr&&a._scanCursor==0&&a.backend.scans==0);
 a.backend.count=0;assert(a.handleSCAN_RESULT(&r)==kIOReturnBusy&&r==nullptr&&a.backend.scans==0);
 a._scanInProgress=false;assert(a.handleSCAN_RESULT(&r)==kIOReturnBusy&&a.backend.scans==1);
 assert(a.handleSCAN_RESULT(&r)==kIOReturnBusy&&a.backend.scans==1);
 a._scanInProgress=false;assert(a.handleSCAN_RESULT(&r)==5&&a.backend.scans==1);
 a.backend.count=2;assert(a.handleSCAN_RESULT(&r)==0&&r->id==1);
 version_major=22;a._scanInProgress=true;assert(a.handleSCAN_RESULT(&r)==kIOReturnBusy&&r==nullptr);
 assert(a.handleSCAN_RESULT(nullptr)==kIOReturnBadArgument);
}
"""
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'t.cpp').write_text(prefix+body+main)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined',str(p/'t.cpp'),'-o',str(p/'t')],check=True)
 subprocess.run([str(p/'t')],check=True)
print('PASS: cached networks readable during scan, partial list terminates, empty cache busy, single bootstrap, Ventura unchanged (ASan/UBSan)')
