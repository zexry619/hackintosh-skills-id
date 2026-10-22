#pragma once
#include <vector>
#include <cstdint>
// Synthetic 802.11 PSF, 16 AWDL windows alternating between channels 6/149.
// Offsets in the fixture are kept explicit, independent of parser internals.
inline std::vector<uint8_t> awdlFixture(bool withMac=true) {
    std::vector<uint8_t> f(100,0);
    f[0]=0xd0; for(int i=4;i<10;++i)f[i]=255;
    uint8_t mac[]={2,1,2,3,4,5},bssid[]={0,0x25,0,0xff,0x94,0x73};
    for(int i=0;i<6;++i){f[10+i]=mac[i];f[16+i]=bssid[i];}
    uint8_t af[]={127,0,0x17,0xf2,8,0x10,0,0};
    for(int i=0;i<8;++i)f[24+i]=af[i];
    f[40]=4;f[41]=57; // synchronization TLV and payload length
    uint8_t *v=f.data()+43;
    v[0]=6;v[1]=64;v[3]=6;v[5]=16;v[7]=16;
    v[11]=16;v[13]=16;v[17]=v[18]=v[19]=v[20]=3;
    for(int i=0;i<6;++i)v[21+i]=mac[i];
    v[27]=4;v[29]=0xfc;v[30]=0xff;
    v[33]=15;v[34]=0;v[35]=0;v[36]=3;v[37]=v[38]=255;
    for(int i=0;i<16;++i)v[39+i]=(i%2)?149:6;
    if(!withMac)f.erase(f.begin(),f.begin()+24);
    return f;
}
