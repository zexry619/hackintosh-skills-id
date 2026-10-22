"""Execute production AWDL descriptor helpers; reject infrastructure lookalikes."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root.parent / 'rtw88-stable/drivers/net/wireless/realtek/rtw88/tx.c').read_text()

def extract(signature):
    start = source.index(signature)
    end = source.index('{', start) + 1
    depth = 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]

code = r'''
#include <cassert>
#include <cstdint>
#include <cstring>
using u8 = uint8_t;
struct sk_buff { u8 *data; unsigned len; };
constexpr int DESC_RATE6M=4, RTW_RATEID_G=7, RTW_CHANNEL_WIDTH_20=0;
struct rtw_tx_pkt_info {
    unsigned rate=0, rate_id=0, bw=2;
    bool use_rate=false, dis_rate_fallback=false;
};
''' + extract('static bool rtw_tx_is_awdl(') + extract('static void rtw_tx_awdl_rate(') + r'''
int main() {
    u8 frame[40] = {};
    sk_buff skb{frame, sizeof(frame)};
    const u8 bssid[]={0,0x25,0,0xff,0x94,0x73};
    const u8 action[]={127,0,0x17,0xf2,8,0x10,0};
    frame[0]=0xd0; memcpy(frame+16,bssid,6); memcpy(frame+24,action,7);
    assert(rtw_tx_is_awdl(&skb));
    frame[30]=3; assert(rtw_tx_is_awdl(&skb));
    frame[30]=1; assert(!rtw_tx_is_awdl(&skb)); frame[30]=0;
    for (unsigned n=0;n<40;++n) { skb.len=n; assert(!rtw_tx_is_awdl(&skb)); }
    skb.len=40;
    for (u8 bad : {u8(1),u8(2),u8(4),u8(0x40),u8(0x80)}) {
        frame[1]=bad; assert(!rtw_tx_is_awdl(&skb));
    }
    frame[1]=0; frame[16]=1; assert(!rtw_tx_is_awdl(&skb)); frame[16]=0;
    frame[24]=3; assert(!rtw_tx_is_awdl(&skb));
    const u8 data[]={0xaa,0xaa,3,0,0x17,0xf2,8,0,3,4};
    frame[0]=8; memcpy(frame+24,data,10); assert(rtw_tx_is_awdl(&skb));
    frame[1]=1; assert(!rtw_tx_is_awdl(&skb)); frame[1]=0;
    frame[27]=1; assert(!rtw_tx_is_awdl(&skb));
    rtw_tx_pkt_info info;
    rtw_tx_awdl_rate(&info);
    assert(info.rate==DESC_RATE6M && info.rate_id==RTW_RATEID_G);
    assert(info.bw==RTW_CHANNEL_WIDTH_20 && info.use_rate && info.dis_rate_fallback);
}
'''
code = '#include <initializer_list>\n' + code
with tempfile.TemporaryDirectory() as td:
    path = Path(td)
    (path / 'test.cpp').write_text(code)
    subprocess.run(['xcrun', 'clang++', '-std=c++17', '-fsanitize=address,undefined',
                    str(path / 'test.cpp'), '-o', str(path / 'test')], check=True)
    subprocess.run([str(path / 'test')], check=True)
print('PASS: production AWDL classification and OFDM descriptor; truncated and non-AWDL frames rejected')
