"""Keep the source bundle and kmod on the same development version."""
from pathlib import Path
import plistlib
import re

root = Path(__file__).resolve().parents[1]
with (root / 'AirPort_RTW88.kext/Contents/Info.plist').open('rb') as f:
    info = plistlib.load(f)
kmod = (root / 'src/kext/kmod_info.c').read_text()
air = (root / 'src/kext/AirportRTW88.cpp').read_text()

version = info['CFBundleVersion']
assert version == info['CFBundleShortVersionString']
assert f'"{version}"' in kmod, 'kmod version differs from bundle version'
assert f'AirPort_RTW88 {version}' in air, 'driver-version string differs from bundle version'
assert re.search(rf'DriverBuild", "{re.escape(version)}-', air), 'DriverBuild tag differs from bundle version'
print(f'version coherence: {version}')
