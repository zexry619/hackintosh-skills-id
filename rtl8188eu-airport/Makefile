# RTL8188EU Airport — top level Makefile
#
#   make fetch     # unduh sumber upstream (itlwm, OpenBSD urtwn, MacKernelSDK, firmware)
#   make m0        # build kext minimal (binding USB + log properti)
#   make check     # cek device USB & konflik kext vendor
#   make clean

SHELL := /bin/bash
ROOT  := $(shell pwd)

.PHONY: all fetch m0 m1 sync check logs clean

all: m1

fetch:
	@./scripts/fetch-upstream.sh

sync:
	@./scripts/sync-openbsd-headers.sh

m0:
	@./scripts/build-m0.sh

m1:
	@./scripts/build-m1.sh

check:
	@./scripts/check-device.sh

logs:
	@./scripts/log-m0.sh

clean:
	@rm -rf src/m0-hello/build src/driver/build
	@echo "cleaned"
