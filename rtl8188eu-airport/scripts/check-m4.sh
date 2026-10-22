#!/bin/bash
# check-m4.sh — cek status driver Wi-Fi native M4 (RTL8188EAirport)
set -uo pipefail

echo "═══════════════════════════════════════════════════════════════"
echo " STATUS DRIVER NATIVE M4 (RTL8188EAirport)"
echo "═══════════════════════════════════════════════════════════════"

echo ""
echo "1. USB Hardware (0x2357:0x010c):"
ioreg -p IOUSB -l -w0 | grep -E -i "idVendor|idProduct|USB Product Name" | grep -B2 -A2 "268" || echo "   ❌ Dongle USB (2357:010c) TIDAK TERDETEKSI di bus USB! Pastikan tertancap."

echo ""
echo "2. Kext Status (kextstat):"
kextstat | grep -i RTL8188EAirport || echo "   ❌ RTL8188EAirport belum termuat di kernel."

echo ""
echo "3. IORegistry - IOPCIEDeviceWrapper & ItlRtl8188E:"
ioreg -r -c IOPCIEDeviceWrapper -w0 -l | grep -E -i "RTL8188E|IOClass" || echo "   (belum ada node IOPCIEDeviceWrapper)"

echo ""
echo "4. IORegistry - AirportItlwm:"
ioreg -r -c AirportItlwm -w0 -l | grep -E -i "IOClass|IO80211|RTL8188E|built-in" | head -20 || echo "   (belum ada node AirportItlwm)"

echo ""
echo "5. Network Hardware Ports (Wi-Fi):"
networksetup -listallhardwareports | grep -A3 -i "wi-fi" || echo "   (belum terdaftar sebagai Wi-Fi)"

echo ""
echo "6. Status Interface Jaringan:"
ifconfig | grep -E "^[a-z0-9]+: "
echo "═══════════════════════════════════════════════════════════════"
