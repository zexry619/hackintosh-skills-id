#!/usr/bin/env python3
from pathlib import Path
root = Path(__file__).resolve().parents[1]
mgr = (root/'src/kext/RTW88AWDLManager.cpp').read_text()
hdr = (root/'src/kext/RTW88AWDLManager.hpp').read_text()
awdl = (root/'src/kext/AirportRTW88AWDL.cpp').read_text()
air = (root/'src/kext/AirportRTW88.cpp').read_text()

checks = [
 ('2.0.0 bridge build tag', ('2.0.0-awdl-itlwm-bridge' in air or '2.0.0-awdl-channel-report' in air or ('2.0.0-awdl-peer-ipv6' in air or '2.0.0-awdl-peer-lifecycle' in air))),
 ('IO80211 control mask exists', 'kAppleCtlTemplate' in hdr and 'AWDL_APPLE_CONTROL_MASK' in mgr),
 ('VIF waits for IO80211 before fallback', '_fallbackDeadlineUS = now + 1500000ULL' in mgr and 'arm(25)' in mgr),
 ('timer runs while waiting for template', 'if (_timer && _syncEnabled && _awdlInterface)' in mgr),
 ('Apple template is authoritative', '_nativeSchedule = !fromIO80211' in mgr),
 ('BPF Apple action can seed template', 'AWDL_BPF_TEMPLATE_ADOPTED' in mgr and 'setSyncFrameTemplate(_txBuffer' in mgr),
 ('AWDL BPF action frames are queued', 'enqueueActionFrame(m)' in awdl),
 ('queued Apple action sent only by scheduler', 'drainActions(now)' in mgr),
 ('Apple action queue has stale bound', '750000ULL' in mgr),
 ('channel IOCTL does not retune PHY directly', 'Do not retune here' in awdl),
 ('master-channel IOCTL only stores policy', '_awdlManager->setMasterChannel(d->master_channel);' in awdl),
 ('channel sequence does not retune from IOCTL', 'not retuned from an IOCTL callback' in awdl),
 ('sync channel sequence retained exactly', 'memcpy(_syncChannelSequence, data, length)' in mgr),
 ('private sequence flags not guessed', 'packed seq flags' in mgr and 'fill_channel' in mgr),
 ('OpenAWDL native fallback retained', 'buildNativeAction' in mgr and '_nativeSchedule' in mgr),
 ('single-PHY STA/AWDL timeslice retained', 'staAssociatedForAWDL' in mgr and 'restoreSTAChannelAfterAWDL' in mgr),
 ('new scheduler identity exported', '2.0.0-itlwm-control-openawdl-radio' in mgr),
 ('control-plane mode telemetry exported', 'AWDL_CONTROL_PLANE' in mgr),
 ('Apple BPF TX telemetry exported', 'AWDL_APPLE_AF_TX' in mgr and 'AWDL_APPLE_AF_QUEUE_DEPTH' in mgr),
]
failed=[]
for name, ok in checks:
    print(('PASS' if ok else 'FAIL') + ': ' + name)
    if not ok: failed.append(name)
if failed:
    raise SystemExit(f'{len(failed)} AWDL bridge invariant(s) failed: ' + ', '.join(failed))
print(f'PASS: {len(checks)}/{len(checks)} AirportItlwm/OpenAWDL bridge checks')
