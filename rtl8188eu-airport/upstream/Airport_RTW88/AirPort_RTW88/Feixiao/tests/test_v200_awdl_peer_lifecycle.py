#!/usr/bin/env python3
from pathlib import Path
root=Path(__file__).resolve().parents[1]
a=(root/'src/kext/AirportRTW88.cpp').read_text()
ah=(root/'src/kext/AirportRTW88.hpp').read_text()
m=(root/'src/kext/RTW88AWDLManager.cpp').read_text()
mh=(root/'src/kext/RTW88AWDLManager.hpp').read_text()
aw=(root/'src/kext/AirportRTW88AWDL.cpp').read_text()
i=(root/'src/kext/RTW88IEEE80211.cpp').read_text()
checks={
 'build tag':'2.0.0-awdl-peer-lifecycle' in a,
 'presence only after validated peer':'p2p && validatedPeer && presenceDue' in a,
 'manager throttles peer presence':'now - peer->lastPresenceUS >= 1000000ULL' in m,
 'published peer state tracked':'announced = false' in mh and 'lastPresenceUS = 0' in mh,
 'stale peers expire':'expirePublishedPeers' in m and '3000000ULL' in m,
 'IO80211 receives peer absence':'postPeerAbsence' in aw,
 'no per-action RX console spam':'AWDL action RX sa=' not in a,
 'no requestPacketTx console spam':'requestPacketTx AWDL sent=' not in aw,
 'no connected chandef console spam':'connected chandef:' not in i,
 'peer IPv6 return not trusted':'AWDL_PEER_IPV6_RESULT' not in a and '(void)p2p->postPeerPresenceIPv6' in a,
 'presence counters exported':'AWDL_PEER_PRESENCE_POSTS' in a and 'AWDL_PEER_ABSENCE_POSTS' in aw,
 'validated peer wakes AWDL output':'signalOutputThread()' in a,
}
failed=[]
for name,ok in checks.items():
    print(('PASS' if ok else 'FAIL')+': '+name)
    if not ok: failed.append(name)
if failed: raise SystemExit(1)
print(f'PASS: {len(checks)}/{len(checks)} peer lifecycle/logging checks')
