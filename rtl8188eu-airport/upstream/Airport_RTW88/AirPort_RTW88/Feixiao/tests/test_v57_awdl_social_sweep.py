#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
m=(r/'src/kext/RTW88AWDLManager.cpp').read_text()
h=(r/'src/kext/RTW88AWDLManager.hpp').read_text()
a=(r/'src/kext/AirportRTW88.cpp').read_text()
checks=[
 ('v57+ build tag', '1.0.3-v57-awdl-social-sweep' in a or '2.0.0-hibernate-recovery' in a or '2.0.0-awdl-itlwm-bridge' in a or ('2.0.0-awdl-peer-ipv6' in a or ('2.0.0-awdl-peer-lifecycle' in a or '2.0.0-awdl-output-queues' in a))),
 ('v57+ scheduler tag', 'v57-awdl-social-sweep' in m or '2.0.0-awdl-social-sweep' in m or '2.0.0-itlwm-control-openawdl-radio' in m),
 ('canonical social sweep', 'static const uint8_t socials[3] = { 6, 44, 149 };' in m),
 ('sweep only before first candidate', '_actionCandidates == 0' in m),
 ('IO80211 social hint seeds the starting channel', '_discoverySocialIndex = v == 6 ? 0 : v == 44 ? 1 : 2;' in m),
 ('sequence retargeted on sweep', 'memset(_action.sequence.channel, _discoveryChannel' in m),
 ('PSF/MIF rearmed on channel change', '_lastMIFEAWValid = false;' in m and '_nextPSFUS = 0;' in m),
 ('discovery channel telemetry', 'AWDL_DISCOVERY_CHANNEL' in m),
 ('social sweep telemetry', 'AWDL_SOCIAL_SWEEPS' in m),
 ('master-channel telemetry', 'AWDL_MASTER_CHANNEL_HINT' in m),
 ('sweep state exists', '_nextSocialSweepUS' in h and '_discoverySocialIndex' in h),
 ('candidate RX counters retained', 'AWDL_ACTION_CANDIDATES' in m and 'AWDL_ACTION_RX' in m),
]
for name,ok in checks:
 print(('PASS' if ok else 'FAIL')+': '+name)
 if not ok: raise SystemExit(1)
print(f'PASS: all {len(checks)} v57 social-discovery invariants present')
