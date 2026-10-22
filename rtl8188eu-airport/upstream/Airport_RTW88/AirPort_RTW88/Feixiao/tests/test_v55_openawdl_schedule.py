#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
protocol = (root/'src/kext/RTW88AWDLProtocol.hpp').read_text()
mgr = (root/'src/kext/RTW88AWDLManager.cpp').read_text()
hdr = (root/'src/kext/RTW88AWDLManager.hpp').read_text()
airport = (root/'src/kext/AirportRTW88.cpp').read_text()
virtual = (root/'src/kext/AirportRTW88AWDL.cpp').read_text()

checks = [
    ('v55 build tag', ('1.0.3-v55-openawdl-schedule' in airport or '1.0.3-v56-awdl-fcs-normalization' in airport or '1.0.3-v57-awdl-social-sweep' in airport or '2.0.0-hibernate-recovery' in airport or '2.0.0-awdl-itlwm-bridge' in airport or ('2.0.0-awdl-peer-ipv6' in airport or ('2.0.0-awdl-peer-lifecycle' in airport or '2.0.0-awdl-output-queues' in airport)))),
    ('v55 scheduler tag', ('v55-openawdl-schedule' in mgr or 'v56-awdl-fcs-normalization' in mgr or 'v57-awdl-social-sweep' in mgr or '2.0.0-awdl-social-sweep' in mgr or '2.0.0-itlwm-control-openawdl-radio' in mgr)),
    ('action parser records subtype', 'a.subtype=p[a.actionOffset+6]' in protocol),
    ('version TLV is parsed', 'type==21' in protocol and 'a.version=v[0]' in protocol and 'a.deviceClass=v[1]' in protocol),
    ('MIF marks peer', 'if (action.subtype == 3) peer->sawMIF = true;' in mgr),
    ('peer requires MIF plus version/devclass', 'peer->valid = peer->sawMIF && peer->versionValid && peer->deviceClass != 0;' in mgr),
    ('unicast gated on valid peer', '!peer.valid' in mgr),
    ('PSF has independent deadline', '_nextPSFUS' in hdr and 'now >= _nextPSFUS' in mgr),
    ('MIF is once per EAW', '_lastMIFEAWValid' in hdr and 'eaw != _lastMIFEAW' in mgr),
    ('MIF targets owned common-window center', 'commonCenterUS' in mgr),
    ('old alternating PSF/MIF scheduler removed', '(_actionSequence&1) ? 3 : 0' not in mgr),
    ('PSF/MIF diagnostics exported', 'AWDL_PSF_TX' in mgr and 'AWDL_MIF_TX' in mgr),
    ('valid-peer diagnostics exported', 'AWDL_VALID_PEERS' in mgr),
    ('native fallback can use IO80211 social master channel', '_masterChannel == 6 || _masterChannel == 44 || _masterChannel == 149' in mgr),
    ('Apple template path preserved', 'memcpy(_txBuffer, _airTemplate, _airTemplateLength)' in mgr),
    ('v54 single-PHY timeslice retained', 'staTxBlockedByAWDL()' in virtual and 'restoreSTAChannelAfterAWDL()' in mgr),
    ('unknown private service ABI not guessed', 'case APPLE80211_IOC_AWDL_PEER_SERVICE_REQUEST' not in virtual),
]

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(('PASS' if ok else 'FAIL') + ': ' + name)
if failed:
    raise SystemExit(f'{len(failed)} v55 invariant(s) failed')
print(f'PASS: all {len(checks)} v55 AirportItlwm/OpenAWDL invariants present')
