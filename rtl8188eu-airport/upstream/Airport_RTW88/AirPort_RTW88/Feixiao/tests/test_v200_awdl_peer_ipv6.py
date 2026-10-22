from pathlib import Path
root=Path(__file__).resolve().parents[1]
m=(root/'src/kext/RTW88AWDLManager.cpp').read_text()
h=(root/'src/kext/RTW88AWDLManager.hpp').read_text()
p=(root/'src/kext/RTW88AWDLProtocol.hpp').read_text()
a=(root/'src/kext/AirportRTW88.cpp').read_text()
checks={
 'sentinel rejected':'!isConcreteChannel(v)' in m and 'fill_channel' in m and '0xff' in m,
 'report fallback':'_observedMasterChannel' in h and 'reportedChannel() const' in h,
 'sync channels parsed':'a.nextAwChannel=v[0]; a.masterChannel=v[3];' in p,
 'peer channels observed':'_observedMasterChannel = action.masterChannel' in m,
 'ipv6 presence':'postPeerPresenceIPv6' in a,
 'modified eui64':'ipv6[8]  = sa[0] ^ 0x02' in a and 'ipv6[11] = 0xff' in a and 'ipv6[12] = 0xfe' in a,
 'semantic version':'AirPort_RTW88 2.0.0' in a,
}
for k,v in checks.items(): print(('PASS' if v else 'FAIL')+': '+k)
raise SystemExit(0 if all(checks.values()) else 1)
