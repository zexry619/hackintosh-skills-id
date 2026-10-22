"""Verify v28 retained the association code the user confirmed on hardware."""
from pathlib import Path
import re
r=Path(__file__).resolve().parents[1]
a=r/'experiments/v27-working-base/src/kext';b=r/'src/kext'
def function(text,name):
 start=text.index(name);body=text.index('{',start);depth=0
 for end in range(body,len(text)):
  if text[end]=='{':depth+=1
  elif text[end]=='}':
   depth-=1
   if not depth:return text[start:end+1]
 raise AssertionError(name)
# Envelope sizes now include Tahoe; the validated decoder remains identical.
assert function((a/'RTW88AssocWire.hpp').read_text(),'inline bool decode(')==function((b/'RTW88AssocWire.hpp').read_text(),'inline bool decode(')
for file,names in {
 'AirportRTW88.cpp':['static bool rtw88TryHostAssociation(', 'IOReturn AirportRTW88::handleASSOCIATE('],
 'RTW88IEEE80211.cpp':['IOReturn RTW88IEEE80211::cmdConnect(', 'bool RTW88IEEE80211::txMgmtFrame(']
}.items():
 old=(a/file).read_text();new=(b/file).read_text()
 for name in names:
  # v29 removes diagnostic-only properties; transport has executable tests.
  clean=lambda x:re.sub(r'^\s*setProperty\("TEST9_[^\n]*\n', '', x, flags=re.M)
  old_body=clean(function(old,name));new_body=clean(function(new,name))
  # v34 seeds only the displayed RSSI from the selected BSS.
  seed='    _rssi = target->rssi < 0 && target->rssi >= -127 ? target->rssi : -100;\n'
  new_body=new_body.replace(seed,'')
  # v36 admits the observed Tahoe envelope; conversion is otherwise unchanged.
  new_body=new_body.replace('!RTW88AssocWire::supportedRequestSize(req->req_len)', 'req->req_len != RTW88AssocWire::RequestSize')
  assert old_body==new_body,name
print('PASS: v27 wire adapter, association handler, connect and management TX retained apart from diagnostic removal, v34 RSSI initialization and validated Tahoe envelope admission')
