from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT.parent / 'rtw88-stable' / 'drivers/net/wireless/realtek/rtw88'
compat = (ROOT/'src/compat/rtw88_compat.c').read_text()
interrupt = (ROOT/'src/compat/linux/interrupt.h').read_text()
airport = (ROOT/'src/kext/AirportRTW88.cpp').read_text()
hpp = (ROOT/'src/kext/AirportRTW88.hpp').read_text()
ieee = (ROOT/'src/kext/RTW88IEEE80211.cpp').read_text()
main = (CORE/'main.c').read_text()
ps = (CORE/'ps.c').read_text()
tx = (CORE/'tx.c').read_text()

checks = {
    'dedicated ordered datapath queue': 'alloc_ordered_workqueue("rtw88_datapath_wq", 0)' in compat,
    'IRQ no longer backed by thread_call': 'g_irq_thread_call' not in compat and 'rtw88_irq_work_fn' in compat,
    'NAPI no longer backed by thread_call': 'napi->thread_call' not in compat and 'rtw88_napi_work_fn' in compat,
    'real synchronize_irq bridge': 'rtw88_synchronize_irq();' in interrupt and 'void rtw88_synchronize_irq(void)' in compat,
    'TX stall watermark': 'kRTW88TxStallAvail  = 96' in airport and 'kIOReturnOutputStall' in airport,
    'TX resume hysteresis': 'kRTW88TxResumeAvail = 160' in airport and 'kServiceAsync' in airport,
    'TX resume callback registered': 'rtw88_set_tx_resume_cb(rtw88_airport_tx_resume_trampoline)' in airport,
    'TX resume callback cleared on teardown': 'rtw88_set_tx_resume_cb(nullptr)' in airport,
    'RX progress can recover TX queue': 'if (_txStalled)\n        resumeTxIfStalled();' in airport,
    'deferred DMA reclaimed during runtime': 'if (preemption_enabled())\n        drainPendingFree();' in airport,
    'no per-IRQ IOLog': 'handling interrupt (count=' not in ieee,
    'direct RX remains (no legacy batching regression)': '_netif->inputPacket(m, (UInt32)plen, 0);' in airport,
    'macOS watchdog not rearmed': 'if (rtw88_disable_watchdog_work)\n\t\tgoto unlock;' in main,
    'pwr_track fallback removed': 'rtwdev->chip->ops->pwr_track(rtwdev);' not in main,
    'macOS LPS disabled': '#ifdef RTW88_MACOS' in ps and 'rtwdev->ps_enabled = false;' in ps,
    'Modern AWDL fixed-rate path preserved': 'rtw_tx_is_awdl' in tx and 'DESC_RATE6M' in tx,
    'v53+ build tag': ('1.0.3-v53-datapath-stability' in airport or '1.0.3-v54-awdl-timeslice' in airport or ('1.0.3-v55-openawdl-schedule' in airport or '1.0.3-v56-awdl-fcs-normalization' in airport or '1.0.3-v57-awdl-social-sweep' in airport or '2.0.0-hibernate-recovery' in airport or '2.0.0-awdl-itlwm-bridge' in airport or '2.0.0-awdl-channel-report' in airport or ('2.0.0-awdl-peer-ipv6' in airport or '2.0.0-awdl-peer-lifecycle' in airport))),
    'header tracks output stall': 'volatile bool _txStalled = false;' in hpp,
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ': ' + name)
if failed:
    raise SystemExit('v53 datapath checks failed: ' + ', '.join(failed))
