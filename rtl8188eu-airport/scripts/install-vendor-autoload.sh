#!/bin/bash
# install-vendor-autoload.sh — pastikan driver Wi-Fi vendor (RtWlanU) termuat
# setiap boot, tanpa bergantung pada AuxKC.
#
# Kenapa perlu: entri AuxKC untuk RtWlanU menyimpan path lama
# (/Library/Extensions.disabled-m1/...) sehingga saat boot driver tidak ikut
# termuat. `kmutil load -z -p /Library/Extensions/RtWlanU.kext` TERBUKTI
# berhasil saat runtime, jadi kita jalankan itu lewat LaunchDaemon.
#
# Pakai: sudo ./scripts/install-vendor-autoload.sh
set -uo pipefail

RUNNER="/usr/local/libexec/realtek-autoload.sh"
PLIST="/Library/LaunchDaemons/com.zekri.realtek-autoload.plist"

if [ "$(id -u)" -ne 0 ]; then
	echo "jalankan dengan sudo" >&2
	exit 1
fi

mkdir -p /usr/local/libexec
cat >"$RUNNER" <<'EOF'
#!/bin/bash
# Dimuat LaunchDaemon saat boot.
LOG=/var/log/realtek-autoload.log
exec >>"$LOG" 2>&1
echo "=== $(date '+%Y-%m-%d %H:%M:%S') mulai ==="

# Beri waktu stack USB enumerate dongle.
sleep 4

for k in RtWlanU1827 RtWlanU; do
	if /usr/bin/kmutil showloaded --list-only 2>/dev/null | grep -q "com.realtek.driver.$k "; then
		echo "$k sudah termuat"
		continue
	fi
	if /usr/bin/kmutil load -z -p "/Library/Extensions/$k.kext"; then
		echo "$k dimuat"
	else
		echo "$k GAGAL dimuat"
	fi
done
EOF
chmod 755 "$RUNNER"

cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.zekri.realtek-autoload</string>
	<key>ProgramArguments</key>
	<array>
		<string>$RUNNER</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<false/>
	<key>ProcessType</key>
	<string>Background</string>
</dict>
</plist>
EOF
chown root:wheel "$PLIST"
chmod 644 "$PLIST"
plutil -lint "$PLIST" >/dev/null || { echo "plist tidak valid" >&2; exit 2; }

launchctl bootout system/com.zekri.realtek-autoload 2>/dev/null
launchctl bootstrap system "$PLIST" 2>&1 | sed 's/^/  /'

echo "terpasang. Log: /var/log/realtek-autoload.log"
