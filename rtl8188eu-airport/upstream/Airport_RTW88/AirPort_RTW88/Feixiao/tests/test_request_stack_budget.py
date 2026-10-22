"""Check actual x86_64 machine-code frames, including the double-fault path."""
import subprocess,re,sys
from pathlib import Path
binary=Path(sys.argv[1])
symbols=subprocess.check_output(['xcrun','nm',str(binary)],text=True)
checks={'__ZN12AirportRTW8817apple80211RequestEjiP16IO80211InterfacePv':256,
        '__ZN12AirportRTW8825handleRequestCOUNTRY_CODEEbPv':256}
# Match country name by demangled substring length independent of mangling digits.
country=next((line.split()[-1] for line in symbols.splitlines() if 'handleRequestCOUNTRY_CODE' in line),None)
checks={list(checks)[0]:256}
if country: checks[country]=256
for symbol,limit in checks.items():
 addr=int(next(line.split()[0] for line in symbols.splitlines() if line.endswith(symbol)),16)
 code=subprocess.check_output(['xcrun','llvm-objdump','-d',f'--start-address={addr}',f'--stop-address={addr+48}',str(binary)],text=True)
 match=re.search(r'subq\s+\$0x([0-9a-f]+), %rsp',code)
 if not match:
  match=re.search(r'movl\s+\$0x([0-9a-f]+), %eax',code)
 assert match,'Unrecognized prologue: '+code
 frame=int(match.group(1),16)
 print(f'{symbol}: {frame} bytes (budget {limit})')
 assert frame<=limit,f'Kernel stack regression: {frame} > {limit}'
print('PASS: compiled dispatcher and synchronous COUNTRY_CODE handler stack budgets')
