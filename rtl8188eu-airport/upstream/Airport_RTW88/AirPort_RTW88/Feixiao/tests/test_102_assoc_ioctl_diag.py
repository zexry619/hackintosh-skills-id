from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'src/kext/AirportRTW88.cpp').read_text()
for token in ['LEGACY_IOCTL_ENTER','LEGACY_IOCTL_SELECTOR','LEGACY_IOCTL_ASSOCIATE_SEEN',
              'LEGACY_ASSOC_SUPER_ENTER','LEGACY_ASSOC_SUPER_RET',
              'NATIVE_REQUEST_SELECTOR','NATIVE_ASSOCIATE_SEEN','TEST9_ASSOCIATE_ENTER']:
    assert token in s, token
print('PASS: association ingress diagnostics')
