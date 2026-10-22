"""Compile production AWDL parser/clock, exercise boundaries and fuzz under ASan/UBSan."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
code=r'''
#include "RTW88AWDLProtocol.hpp"
#include "awdl_fixture.hpp"
#include <cassert>
using namespace RTW88AWDL;
int main(){
 auto full=awdlFixture(),body=awdlFixture(false);Action a,b;
 assert(parseAction(full.data(),full.size(),a)&&a.actionOffset==24);
 assert(parseAction(body.data(),body.size(),b)&&b.actionOffset==0);
 assert(a.awPeriod==16&&a.presence==4&&a.afPeriod==16&&a.sequence.channel[1]==149);
 for(size_t n=0;n<full.size();++n)assert(!parseAction(full.data(),n,b));
 assert(!parseAction(nullptr,0,b));
 auto bad=full;bad[41]=255;assert(!parseAction(bad.data(),bad.size(),b));
 bad=full;bad[43+5]=0;assert(!parseAction(bad.data(),bad.size(),b));
 bad=full;bad[43+27]=3;assert(!parseAction(bad.data(),bad.size(),b));
 bad=full;bad[43+35]=1;assert(!parseAction(bad.data(),bad.size(),b));
 bad=full;bad[43+1]=65;assert(!parseAction(bad.data(),bad.size(),b));
 Clock clock;auto partial=a;partial.countdown=32;assert(!clock.set(partial,0));assert(clock.set(a,10000000));
 auto first=window(clock,a.sequence,10000000);assert(first.aw==65532&&first.slot==15&&!insideGuard(first));
 auto next=window(clock,a.sequence,10000000+64*1024);assert(next.aw==0&&next.slot==0&&next.channel==6);
 next=window(clock,a.sequence,10000000+64*1024+4*1024);assert(insideGuard(next)&&multicastWindow(next));
 auto edge=window(clock,a.sequence,10000000+128*1024-1024);assert(!insideGuard(edge));
 auto stamped=full;stamp(stamped.data(),a,next,10000000+68*1024,4097);
 assert(le16(stamped.data()+22)==16&&le16(stamped.data()+43+29)==next.aw);
 assert(parseAction(stamped.data(),stamped.size(),b)&&b.countdown==60);

 // Two aggregated MSDUs, including padding, destination filtering and atomic rejection.
 const uint8_t local[6]={2,1,2,3,4,5};
 auto sub=[&](size_t bytes){std::vector<uint8_t> v(30+bytes,0);memcpy(v.data(),local,6);
  v[6]=2;v[11]=9;v[12]=uint8_t((16+bytes)>>8);v[13]=uint8_t(16+bytes);
  const uint8_t h[]={0xaa,0xaa,3,0,0x17,0xf2,8,0,3,4,0,0,0,0,0x86,0xdd};
  memcpy(v.data()+14,h,16);return v;};
 auto one=sub(1),two=sub(2),agg=one;agg.push_back(0);agg.insert(agg.end(),two.begin(),two.end());
 unsigned delivered=0;
 auto accept=[&](const uint8_t*,const uint8_t*,uint16_t type,const uint8_t*,size_t length){
  assert(type==0x86dd && (length==1||length==2));++delivered;};
 assert(receiveAggregate(agg.data(),agg.size(),local,accept)&&delivered==2);
 for(size_t len=0;len<agg.size();++len){
  delivered=0;bool ok=receiveAggregate(agg.data(),len,local,accept);
  if(len==one.size())assert(ok&&delivered==1);else assert(!ok&&delivered==0);
 }
 auto other=agg;other[5]=6;delivered=0;
 assert(receiveAggregate(other.data(),other.size(),local,accept)&&delivered==1);
 auto corrupt=agg;corrupt[32+13]=255;delivered=0;
 assert(!receiveAggregate(corrupt.data(),corrupt.size(),local,accept)&&!delivered);
 corrupt=agg;corrupt[32+14]=0;delivered=0;
 assert(!receiveAggregate(corrupt.data(),corrupt.size(),local,accept)&&!delivered);
 uint32_t seed=42;
 for(unsigned trial=0;trial<100000;++trial){
  auto f=full;
  for(unsigned j=0;j<1+trial%16;++j){seed=seed*1664525+1013904223;size_t at=seed%f.size();seed=seed*1664525+1013904223;f[at]=uint8_t(seed>>24);}
  if(parseAction(f.data(),f.size(),b)){
   Clock c;if(c.set(b,100000000)){auto w=window(c,b.sequence,100005000);assert(w.slot<16);stamp(f.data(),b,w,100005000,1);}
  }
 }
}
'''
with tempfile.TemporaryDirectory() as td:
 p=Path(td);(p/'test.cpp').write_text(code)
 subprocess.run(['xcrun','clang++','-std=c++17','-fsanitize=address,undefined','-I'+str(root/'src/kext'),'-I'+str(root/'tests/fixtures'),str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
print('PASS: production AWDL TLVs, truncation, malformed fields, 16-bit wrap, guard windows, stamping and 100000 mutated frames')
