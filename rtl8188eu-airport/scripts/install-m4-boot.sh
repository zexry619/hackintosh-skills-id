#!/bin/bash
# install-m4-boot.sh — muat RTL8188EAirport saat boot TANPA menaruhnya di ESP.
#
# Kenapa tidak di ESP:
#   kext yang diinjeksi OpenCore terkunci di kernel sejak boot; mengganti
#   binary-nya butuh reboot. Dengan LaunchDaemon, binary ada di /usr/local/lib
#   dan bisa diganti kapan saja (unload → load), tanpa reboot.
#
# Alur saat boot:
#   1. lepas driver vendor kalau sedang memegang dongle
#   2. kmutil load driver kita
#   3. tunggu 8 dtk, cek interface Wi-Fi muncul
#   4. kalau gagal → unload kita, muat driver vendor (fallback)
#
# Pakai: sudo ./scripts/install-m4-boot.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEXT_SRC="$ROOT/src/driver/build-m4/RTL8188EAirport.kext"
KEXT_DST="/usr/local/lib/RTL8188EAirport.kext"
RUNNER="/usr/local/libexec/rtl8188e-start.sh"
PLIST="/Library/LaunchDaemons/com.zekri.rtl8188e-start.plist"
VENDOR_DIR="/Library/Extensions.disabled-m1"

if [ "$(id -u)" -ne 0 ]; then
	echo "jalankan dengan sudo" >&2
	exit 1
fi
if [ ! -d "$KEXT_SRC" ]; then
	echo "kext belum dibuild: $KEXT_SRC" >&2
	exit 2
fi

echo "[1/4] pasang kext ke $KEXT_DST"
rm -rf "$KEXT_DST"
cp -R "$KEXT_SRC" "$KEXT_DST"
chown -R root:wheel "$KEXT_DST"
chmod -R go-w "$KEXT_DST"

echo "[2/4] tulis runner $RUNNER"
mkdir -p /usr/local/libexec
cat >"$RUNNER" <<EOF
#!/bin/bash
# Dimuat LaunchDaemon saat boot. Log: /var/log/rtl8188e-start.log
LOG=/var/log/rtl8188e-start.log
KEXT=$KEXT_DST
VENDOR=$VENDOR_DIR
exec >>"\$LOG" 2>&1
echo "=== \$(date '+%Y-%m-%d %H:%M:%S') mulai ==="

# Tunggu stack USB siap.
sleep 3

# Driver vendor (kalau termuat) harus lepas dulu.
kmutil unload -b com.realtek.RtWlanU 2>/dev/null
kmutil unload -b com.realtek.RtWlanU1827 2>/dev/null

echo "load \$KEXT"
if ! kmutil load -z -p "\$KEXT"; then
	echo "load gagal"
fi

# Beri waktu attach + IO80211 mendaftarkan interface.
# Cek dua-duanya: driver sudah attach (properti RTL8188E-stage) ATAU
# port Wi-Fi sudah muncul. Dongle USB internal bisa telat enumerate.
for i in \$(seq 1 30); do
	sleep 1
	if ioreg -l -w0 2>/dev/null | grep -q "RTL8188E-stage"; then
		echo "driver attach setelah \${i}s"
		exit 0
	fi
	if networksetup -listallhardwareports 2>/dev/null | grep -qi "Wi-Fi"; then
		echo "interface Wi-Fi muncul setelah \${i}s"
		exit 0
	fi
done

echo "interface tidak muncul — fallback ke driver vendor"
kmutil unload -b io.github.zekri.RTL8188EAirport 2>/dev/null
for k in RtWlanU RtWlanU1827; do
	if [ -d "\$VENDOR/\$k.kext" ]; then
		kmutil load -p "\$VENDOR/\$k.kext" && echo "vendor \$k dimuat"
	fi
done
exit 1
EOF
chmod 755 "$RUNNER"

echo "[3/4] tulis LaunchDaemon $PLIST"
cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.zekri.rtl8188e-start</string>
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
plutil -lint "$PLIST" >/dev/null || { echo "plist tidak valid" >&2; exit 3; }

echo "[4/4] daftarkan daemon"
launchctl bootout system/com.zekri.rtl8188e-start 2>/dev/null
launchctl bootstrap system "$PLIST" 2>&1 | sed 's/^/  /'
launchctl enable system/com.zekri.rtl8188e-start 2>/dev/null

echo
echo "selesai. Saat boot berikutnya driver dimuat otomatis dari:"
echo "  $KEXT_DST"
echo "Log: /var/log/rtl8188e-start.log"
echo
echo "Ganti binary tanpa reboot:"
echo "  sudo kmutil unload -b io.github.zekri.RTL8188EAirport   # kalau interface sudah lepas"
echo "  sudo cp -R <build-baru> $KEXT_DST && sudo kmutil load -z -p $KEXT_DST"
