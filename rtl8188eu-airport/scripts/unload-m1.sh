#!/bin/bash
# Unload kext Milestone 1.
set -euo pipefail

BUNDLE_ID="io.github.zekri.RTL8188EUM1"

if [[ $EUID -ne 0 ]]; then
	echo "[unload] perlu sudo" >&2
	exit 1
fi

if kmutil unload --bundle-id "$BUNDLE_ID" 2>/dev/null; then
	echo "[unload] kmutil: OK"
else
	kextunload -b "$BUNDLE_ID" && echo "[unload] kextunload: OK"
fi
