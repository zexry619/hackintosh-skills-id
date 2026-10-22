from pathlib import Path
root = Path(__file__).resolve().parents[1]
a = (root/'src/kext/AirportRTW88AWDL.cpp').read_text()
c = (root/'src/kext/AirportRTW88.cpp').read_text()
checks = {
    'AWDL VIF does not start private output queues': 'startOutputQueues()' not in a,
    'AWDL VIF does not stop private output queues': 'stopOutputQueues()' not in a,
    'peer publication does not manipulate queue state': 'p2p->startOutputQueues()' not in c and 'p2p->clearOutputFlowControlled()' not in c,
    'peer publication may request output service safely': 'p2p->signalOutputThread()' in c,
    'AWDL requestPacketTx remains controller-driven': 'void AirportRTW88::requestPacketTx' in a,
    'AWDL dequeue remains bounded': 'dequeueOutputPacketsWithServiceClass(32' in a,
    'quiet AWDL RX telemetry': 'AWDL_LAST_DATA_INPUT_RAW' in c,
    'recovery build tag present': '2.0.0-awdl-peer-lifecycle-sta-recovery' in c,
}
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ': ' + name)
if not all(checks.values()):
    raise SystemExit(1)
