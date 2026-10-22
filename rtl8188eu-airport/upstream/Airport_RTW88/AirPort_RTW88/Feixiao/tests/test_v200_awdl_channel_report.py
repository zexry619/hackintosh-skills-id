#!/usr/bin/env python3
from pathlib import Path

root=Path(__file__).resolve().parents[1]
awdl=(root/'src/kext/AirportRTW88AWDL.cpp').read_text()
air=(root/'src/kext/AirportRTW88.cpp').read_text()
mgrh=(root/'src/kext/RTW88AWDLManager.hpp').read_text()
mgr=(root/'src/kext/RTW88AWDLManager.cpp').read_text()

checks=[
 ('dynamic Realtek chip labels', all(x in air for x in ['RTL8822BE','RTL8822CE','RTL8821CE'])),
 ('firmware display combines chip and driver', ' (AirPort_RTW88 2.0.0)' in air),
 ('AWDL reported-channel accessor', 'reportedChannel() const' in mgrh),
 ('reported AWDL channel telemetry', 'AWDL_REPORTED_CHANNEL' in mgr),
 ('regulatory social-channel chooser', 'rtw88PreferredAWDLSocialChannel' in awdl),
 ('5 GHz social preference 149', 'if (ch149) return 149;' in awdl),
 ('regional fallback channel 44', 'if (ch44) return 44;' in awdl),
 ('2.4 GHz fallback channel 6', 'if (ch6) return 6;' in awdl),
 ('AWDL VIF seeds missing master channel', '!_awdlManager->masterChannel()' in awdl and 'setMasterChannel(social)' in awdl),
 ('virtual CHANNEL GET reports AWDL channel', '_awdlManager->reportedChannel()' in awdl),
 ('virtual MASTER_CHANNEL GET reports AWDL channel', 'd->master_channel = _awdlManager->reportedChannel();' in awdl),
 ('primary controller exposes AWDL master channel', 'case APPLE80211_IOC_AWDL_MASTER_CHANNEL:' in air and 'd->master_channel = _awdlManager->reportedChannel();' in air),
 ('primary controller exposes AWDL sync state', 'case APPLE80211_IOC_AWDL_SYNC_ENABLED:' in air),
 ('2.0.0 channel-report build tag', ('2.0.0-awdl-channel-report' in air or ('2.0.0-awdl-peer-ipv6' in air or '2.0.0-awdl-peer-lifecycle' in air))),
]

bad=0
for name, ok in checks:
    print(('PASS' if ok else 'FAIL')+': '+name)
    bad += not ok
if bad:
    raise SystemExit(1)
print(f'PASS: {len(checks)}/{len(checks)} AWDL channel/report checks')
