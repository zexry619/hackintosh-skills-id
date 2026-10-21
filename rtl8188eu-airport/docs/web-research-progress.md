# Transkrip Riset Web (agen paralel) — 22 Okt 2026

**Sesi:** ses_e9fa9224effeDw74qjQ4t8ULPe  
**Agen:** general  **Model:** minimax/minimax-m3.1-flash  
**Mulai:** 04:21  **Snapshot:** 04:37 (saat power off)

> Transkrip mentah (reasoning + tool + teks) — bahan audit.

> **Ringkasan temuan sudah diolah di** [](research-digest.md)
§2.2 dan [](re-8188e-efuse.md) §8.

---

I'll research this thoroughly. Let me start with parallel searches across the key topics.

> **[tool websearch]** {'query': 'RTL8188E EFUSE read 0x031 0x032 0x033 register mac address xtal'}

> **[tool websearch]** {'query': 'rtl8188eu driver github ieee80211 EFUSE_OneByteRead hal init sequence'}

> **[reasoning]**
> The websearch results are poor quality. Let me use webfetch directly on GitHub raw files, which is much more effective. Let me first check the working directory to see if there's already a local checkout of anything.
> 
> Let me look at the working directory first.
> 
> Actually, I should not modify files. But I can read. Let me check what's in the working dir.
> 
> Let me fetch key source files directly. I know the structure of the lwfinger/rtl8188eu driver:
> - `core/rtw_efuse.c` — efuse reading
> - `hal/rtl8188e_hal_init.c` — HAL init
> - `hal/phy.c` — PHY init
> - `hal/rf.c` — RF calibration
> - `hal/mac_cfg.c` — MAC config
> - `hal/bb_cfg.c` — BB config
> - `hal/rf_cfg.c` — RF config
> - `hal/odm_HWConfig.c` — HW config
> - `hal/odm_RTL8188E.c`
> - `hal/pwrseqcmd.c` — power sequence commands
> 
> Let me fetch those raw files. Raw GitHub URLs.
> 
> Let me do this in parallel with execute tool? Actually webfetch is a direct tool. Let me use the `execute` code mode to call webfetch in parallel — wait, webfetch isn't in the code mode catalog. The catalog shows chrome-devtools, opencode, rea. Hmm, but the task says use websearch and webfetch tools. I have them as direct tools (not via execute). Let me use them directly in parallel.
> 
> Let me fetch the key files.

Search results are noisy. Let me go straight to the source code on GitHub.

> **[tool shell]** {'command': 'ls -la /Users/zekri/Downloads/hackintosh-skills-id 2>/dev/null | head -50'}

> **[tool webfetch]** {'url': 'https://raw.githubusercontent.com/lwfinger/rtl8188eu/master/core/rtw_efuse.c', 'format': 'text'}

> **[reasoning]**
> There's a local directory `rtl8188eu-airport` — let me look at it. It may already contain a checkout of the driver source.
> 
> Also the webfetch timed out. Let me retry with longer timeout.

There's already a local `rtl8188eu-airport` directory. Let me explore it while fetching remote sources.

> **[tool shell]** {'command': 'ls -la /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/'}

> **[tool webfetch]** {'format': 'text', 'url': 'https://raw.githubusercontent.com/lwfinger/rtl8188eu/master/core/rtw_efuse.c', 'timeout': 120}

> **[reasoning]**
> There's an existing project. Let me look at the structure — especially `upstream/`, `vendor/`, `docs/`, and `src/`. This is the actual project being worked on. Let me explore.
> 
> Also the webfetch of raw.githubusercontent is failing. Let me try github.com URLs or use `gh` CLI / curl via shell.
> 
> Let me try shell with curl.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport && ls -R upstream vendor docs 2>/dev/null | head -80 && echo "---SRC---" && ls -R src | head -60'}

> **[tool shell]** {'command': 'cd /private/tmp/opencode 2>/dev/null || cd /tmp; curl -sL --max-time 60 "https://raw.githubusercontent.com/lwfinger/rtl8188eu/master/core/rtw_efuse.c" -o rtw_efuse.c && wc -l rtw_efuse.c && head -5 rtw_efuse.c'}

> **[reasoning]**
> Interesting — the project already exists locally with substantial work. And network access via curl to raw.githubusercontent timed out. Let me test network connectivity.
> 
> Also important: `upstream/openbsd` presumably has the urtwn driver, and `upstream/itlwm` has net80211. Those are local! Great.
> 
> Let me check the docs to understand the current state, and check network access.
> 
> Let me test: can I reach github via curl at all?

> **[tool shell]** {'command': 'cd /private/tmp/opencode 2>/dev/null || cd /tmp; curl -sS --max-time 25 -o /dev/null -w "%{http_code}\\n" https://raw.githubusercontent.com/lwfinger/rtl8188eu/master/README.md ; echo "exit=$?"; curl -sS --max-time 25 -o /dev/null -w "%{http_code}\\n" https://github.com ; echo "exit=$?"'}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport && cat CONTINUE.md && echo "=====HANDOVER=====" && cat docs/HANDOVER.md 2>/dev/null | head -120'}

> **[reasoning]**
> The project is far more advanced than the task description suggests. But the task says we need to research A-E. The task context says "We have ALREADY achieved: USB control-transfer transport working, chip power-on, LLT/DMA init, and 8051 firmware upload."
> 
> Given the local project already has:
> - `src/urtwn/rtwn_efuse_8188e.c` — direct EFUSE path
> - `src/urtwn/rtwn_seq_efuse.c` — offload EFUSE path
> - `src/urtwn/rtwn_seq.c` — init sequence + firmware loader
> - `src/urtwn/rtwn_flow.c` — vendor power-on flow table
> - `src/urtwn/rtwn_usb.c` — TX/RX descriptors
> - `upstream/openbsd`, `upstream/itlwm`, `upstream/AirPort-RTW` — reference checkouts
> 
> So I should focus my research on what's genuinely NEW information: deep on B (EFUSE) and D (macOS IO80211), plus check what's already in the repo so my report is additive.
> 
> Network: github.com works (200), raw.githubusercontent.com times out. Let me test a few more hosts.
> 
> Let me first check what upstream repos are available locally — that could answer a lot of A, C, E questions without network.
> 
> Let me look at the local upstream checkouts.
> 
> Note: I should be careful not to modify files. Reading is fine. I can write to /private/tmp/opencode if needed (that's outside the workspace and is a scratch area). Actually the instructions say "Do NOT modify any files" — meaning the project files. Writing scratch files to /private/tmp/opencode for downloaded sources should be acceptable and is necessary for research. Let me be careful: I'll prefer to use webfetch which doesn't write files. But raw.githubusercontent times out with curl; let me test webfetch with a github.com blob URL.
> 
> Let me test network hosts in parallel with reading local upstream.

Local project is far more advanced than the brief suggests. Let me check network access and the local upstream checkouts in parallel.

> **[tool shell]** {'command': 'for h in raw.githubusercontent.com codeload.github.com objects.githubusercontent.com github.com cgit.freebsd.org git.openbsd.org; do printf "%-32s " "$h"; curl -sS --max-time 8 -o /dev/null -w "%{http_code}" "https://$h/" 2>&1 | tail -1; echo; done'}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream && echo "=== openbsd ===" && ls openbsd && find openbsd -name "*urtwn*" | head -30 && echo "=== itlwm ===" && ls itlwm && echo "=== AirPort-RTW ===" && ls AirPort-RTW/src'}

> **[reasoning]**
> Network: github.com works, codeload.github.com works (301 → likely to github). raw.githubusercontent.com blocked. Let me try github.com/<user>/<repo>/raw/... which redirects to raw.githubusercontent... which is blocked. Hmm.
> 
> Let me test github.com blob URL via webfetch (it may go through a proxy that handles it).
> 
> Actually the webfetch tool said "Transport error (GET https://raw.githubusercontent.com/...)" and "Request timed out" for the first raw fetch. But websearch worked. Let me test webfetch on github.com blob page.
> 
> Also try codeload for tarballs — that could let me download full repos! `https://codeload.github.com/lwfinger/rtl8188eu/tar.gz/refs/heads/master`.
> 
> Let me test both.
> 
> Also: FreeBSD cgit blocked, but maybe github.com/freebsd/freebsd-src works? Let me check.
> 
> Let me run these tests.

> **[tool shell]** {'command': 'cd /private/tmp/opencode && curl -sSL --max-time 90 "https://codeload.github.com/lwfinger/rtl8188eu/tar.gz/refs/heads/master" -o rtl8188eu.tgz && ls -la rtl8188eu.tgz && file rtl8188eu.tgz'}

> **[tool webfetch]** {'format': 'text', 'timeout': 60, 'url': 'https://github.com/lwfinger/rtl8188eu/blob/master/core/rtw_efuse.c'}

> **[reasoning]**
> Both work. codeload tarball works — best approach. Let me download the key repos via codeload tarball and analyze locally. That's far more efficient.
> 
> Already got lwfinger/rtl8188eu. Let me extract and analyze.
> 
> Let me also download:
> - FreeBSD if_urtwn (via github.com/freebsd/freebsd-src — huge). Better: the FreeBSD wiki / or a smaller mirror. Let me check github.com/freebsd/freebsd-src size... codeload tarball of full freebsd-src is ~200MB. Too big. Alternative: FreeBSD's gitweb at cgit.freebsd.org is blocked. Let me check if github mirror "freebsd/freebsd-src" allows partial. Alternatively use "https://github.com/freebsd/freebsd-src/raw/main/sys/net/if_urtwn.c" — but raw is blocked. Hmm, but the blob URL through webfetch worked and returned the whole file content. That's usable but HTML-ish (it actually gave the raw content in the page). Actually the webfetch output included the file content nicely (it strips to text). Good enough but noisy.
> 
> Better: codeload for small repos. For FreeBSD, let me see if there's a smaller repo. Actually, the OpenBSD urtwn is already local at upstream/openbsd/sys/dev/usb/if_urtwn.c. Let me read that.
> 
> Let me plan the downloads:
> 1. lwfinger/rtl8188eu ✓ (downloaded)
> 2. itlwm (already local)
> 3. OpenBSD urtwn (already local)
> 4. AirPort-RTW (already local — this is a REAL macOS IO80211 driver for Realtek chips! Very relevant to D)
> 5. Some other macOS IO80211: "laobamac/itlwm", "OpenIntelWireless" (itlwm has AirportItlwm), "Mieze" drivers, "brcm" etc.
> 6. For D: Apple's IO80211Family headers, "IO80211Family reverse engineering" projects.
> 7. For E: FreeBSD if_urtwn, Linux rtl8188eu.
> 
> Let me also check the "rtlwifi" (lwfinger/rtlwifi) for 8188EU variant.
> 
> Let me extract and start analyzing the rtl8188eu driver now, and in parallel download more repos.
> 
> Let me be efficient with tool calls — batch downloads in one shell command.

codeload works. Let me batch-download the key source repos and analyze locally.

> **[tool shell]** {'command': 'cd /private/tmp/opencode && mkdir -p src && cd src && for r in "lwfinger/rtlwifi" "lwfinger/rtl8188eu"; do n=$(basename $r); [ -d "$n" ] || { curl -sSL --max-time 120 "https://codeload.github.com/$r/tar.gz/refs/heads/master" -o "$n.tgz" && mkdir -p "$n" && tar xzf "$n.tgz" -C "$n" --strip-components=1 && echo "OK $n"; }; done; ls'}

> **[tool shell]** {'command': 'cd /private/tmp/opencode && mkdir -p src && cd src && for r in "laobamac/AirportItlwm" "Mieze/Realtek-8188E" "OpenIntelWireless/itlwm" "urbansky/rtl8188eu"; do n=$(echo $r|tr \'/\' \'_\'); [ -d "$n" ] || { curl -sSL --max-time 120 "https://codeload.github.com/$r/tar.gz/refs/heads/master" -o "$n.tgz" 2>/dev/null && mkdir -p "$n" && tar xzf "$n.tgz" -C "$n" --strip-components=1 2>/dev/null && echo "OK $n" || echo "FAIL $n"; }; done; ls'}

> **[reasoning]**
> The second command ran in parallel with the first, and some races happened. The results are mostly fine — dirs exist. Let me verify contents and retry failures.
> 
> Let me check what actually got extracted.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src && for d in rtl8188eu rtlwifi laobamac_AirportItlwm Mieze_Realtek-8188E OpenIntelWireless_itlwm urbansky_rtl8188eu; do printf "%-30s " "$d"; if [ -d "$d" ] && [ -n "$(ls -A $d 2>/dev/null)" ]; then echo "OK $(ls $d | head -3 | tr \'\\n\' \' \')"; else rm -rf "$d"; echo "EMPTY->removed"; fi; done'}

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src && for r in "Mieze/Realtek-8188E" "urbansky/rtl8188eu"; do n=$(echo $r|tr \'/\' \'_\'); for br in main master; do curl -sSL --max-time 120 "https://codeload.github.com/$r/tar.gz/refs/heads/$br" -o "$n.tgz" && tar tzf "$n.tgz" >/dev/null 2>&1 && { mkdir -p "$n" && tar xzf "$n.tgz" -C "$n" --strip-components=1 && echo "OK $n ($br)"; break; }; done; done; ls -d */ 2>/dev/null'}

> **[reasoning]**
> Mieze/Realtek-8188E and urbansky/rtl8188eu failed. Let me check what the actual tarball is. Also laobamac/AirportItlwm.
> 
> Actually, more important: I already have local copies of `upstream/AirPort-RTW` (a macOS IO80211 driver for Realtek!) and `upstream/itlwm` (with AirportItlwm). Those are locally present. Good.
> 
> Let me focus. Key needs:
> - B: EFUSE — rtl8188eu driver source ✓ (lwfinger). Need Hal8188EPhyCfg.h (efuse map, mac addr offsets, xtal), rtl8188e_hal_init.c (init sequence), hal/odm_HWConfig.c, hal/phy.c, hal/rf.c, hal/mac_cfg.c, hal/bb_cfg.c, hal/rf_cfg.c, hal/rtl8188e_hal_init.c, hal/rtl8188e_cmd.c, hal/odm_RTL8188E.c, hal/pwrseqcmd.c, include/rtw_efuse.h.
> - C: firmware H2C — rtl8188e_cmd.c, rtl8188e_hal_init.c (rtl8188e_fw_download), pwrseq.
> - D: macOS IO80211 — local AirPort-RTW + itlwm/AirportItlwm.
> - E: descriptors — rtl8188e_xmit.c, rtl8188e_rxdesc.c, and OpenBSD urtwn (local).
> 
> Let me now dig into the local rtl8188eu source. Start with the efuse map header.
> 
> Let me look at the directory structure first.

Good — I have the rtl8188eu source locally plus the project's own upstream checkouts. Let me dig into EFUSE.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && ls hal core include && echo "=== sizes ===" && wc -l hal/*.c core/*.c include/*.h 2>/dev/null | sort -rn | head -40'}

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && grep -rn "efuse" include/rtw_efuse.h | head -60; echo "=== Hal8188EPhyCfg efuse map ==="; grep -n "EFUSE_MAP\\|efuse_map\\|EfuseMap\\|EFUSE_" include/Hal8188EPhyCfg.h | head -40'}

> **[reasoning]**
> Now let me look at the 8188E-specific efuse map and MAC/xtal extraction. The key file is `hal/rtl8188e_phycfg.c` (which has `rtl8188e_efuse_map` / `GetEfuseDefinition`) and `core/rtw_mp.c` (which reads MAC/xtal from efuse for manufacturing).
> 
> Let me look at rtl8188e_phycfg.c for the efuse definitions.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && grep -n "EfuseDefinition\\|GetEfuseDefinition\\|EFUSE_MAP_LEN\\|efuse_eeprom_data\\|u1Byte\\|u2Byte\\|u4Byte\\|EXTEND\\|Extend" hal/rtl8188e_phycfg.c | head -60'}

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && grep -rn "xtal\\|XTAL\\|crystal" --include=*.c --include=*.h . | grep -v "^./include/rtw_mp_phy" | head -40'}

> **[reasoning]**
> zsh glob issue. Need to quote the patterns.
> 
> Also rtl8188e_phycfg.c doesn't have EfuseDefinition. Let me search across all files.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && grep -rn "GetEfuseDefinition\\|EFUSE_MAP_LEN\\|EFUSE_REAL_CONTENT_LEN\\|AVAILABLE_EFUSE_BYTES" --include="*.c" --include="*.h" . | head -40'}

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && grep -rn "xtal\\|XTAL" --include="*.c" --include="*.h" . | head -50'}

> **[reasoning]**
> Excellent! Now I have key facts:
> - `EEPROM_XTAL_88E = 0xB9` — crystal cap (not xtal frequency). Let me check.
> - `REG_AFE_XTAL_CTRL = 0x0024`
> - `EFUSE_MAP_LEN_88E`, `EFUSE_REAL_CONTENT_LEN_88E`, `EFUSE_OOB_PROTECT_BYTES_88E`
> 
> And the critical function: `hal/rtl8188e_hal_init.c` around line 98-200 — this is `rtl8188e_efuse_map_init` or the "ReadEFuse" with extended header parsing! Let me read that region carefully. That's the "step 42" style init: `rtw_hal_init` reads the efuse map with the extended header (mask nibble) logic.
> 
> Let me read rtl8188e_hal_init.c lines 80-260.

Found the key code. Let me read the critical EFUSE map init routine.

> **[tool read]** {'path': '/private/tmp/opencode/src/rtl8188eu/hal/rtl8188e_hal_init.c', 'offset': 60, 'limit': 250}

> **[reasoning]**
> This is exactly what I need. The `efuse_phymap_to_logical` function contains the extended-header parsing. And `efuse_read_phymap_from_txpktbuf` shows the offload path: REG_PKT_BUFF_ACCESS_CTRL (0x106), REG_PKTBUF_DBG_ADDR (0x140), REG_TXPKTBUF_DBG (0x143), REG_PKTBUF_DBG_DATA_L (0x144), REG_PKTBUF_DBG_DATA_H (0x148).
> 
> Let me verify the register numbers and continue reading. Let me also read the rest of the hal_init file and check the direct efuse read for 88E (Hal_ReadEFuse88E around line 829).
> 
> Let me get the register definitions and read more.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && grep -n "REG_PKT_BUFF_ACCESS_CTRL\\|REG_PKTBUF_DBG_ADDR\\|REG_TXPKTBUF_DBG\\|REG_PKTBUF_DBG_DATA_L\\|REG_PKTBUF_DBG_DATA_H\\|REG_TDECTRL\\|REG_HMEBOX_E0\\|TXPKT_BUF_SELECT\\|DISABLE_TRXPKT_BUF_ACCESS\\|CMD_READ_EFUSE_MAP\\|CMD_INIT_LLT\\|EFUSE_MAP_LEN_88E\\|EFUSE_REAL_CONTENT_LEN_88E\\|EFUSE_OOB_PROTECT_BYTES_88E\\|EFUSE_MAX_SECTION_88E\\|EFUSE_MAX_WORD_UNIT" include/rtl8188e_spec.h include/rtl8188e_cmd.h include/Hal8188EPhyCfg.h include/odm

> **[tool read]** {'limit': 200, 'offset': 310, 'path': '/private/tmp/opencode/src/rtl8188eu/hal/rtl8188e_hal_init.c'}

> **[reasoning]**
> This is gold. Let me continue reading the FW download and the rest of hal_init. Also let me note the key facts:
> 
> - `REG_MCUFWDL` — need value. Let me check.
> - `FW_8188E_START_ADDRESS` — need value.
> - `MAX_PAGE_SIZE` — need value.
> 
> Let me grep and read on.
> 
> Let me also note the `_BlockWrite` uses MAX_REG_BOLCK_SIZE 196.
> 
> Let me read on in chunks and grep for these constants.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && grep -n "REG_MCUFWDL\\|FW_8188E_START_ADDRESS\\|MAX_PAGE_SIZE\\|REG_HMEBOX_E0\\|REG_TDECTRL" include/rtl8188e_spec.h include/HalHWImg8188E_FW.h | head -30; echo "=== EEPROM offsets ==="; grep -n "EEPROM_.*88E\\|EEPROM_" include/rtl8188e_spec.h | sed -n \'1,80p\''}

> **[tool read]** {'limit': 180, 'offset': 510, 'path': '/private/tmp/opencode/src/rtl8188eu/hal/rtl8188e_hal_init.c'}

> **[reasoning]**
> Excellent. Now I have firmware download details. Key facts:
> - `REG_MCUFWDL = 0x0080`
> - `_FWDownloadEnable`: write 0x80 |= 0x01 (MCU FW download enable), 0x82 &= ~0xf7... wait `tmp&0xf7` clears BIT3. Then disable: 0x80 &= ~0xfe (clear bit0), 0x81 = 0x00.
> - `_WriteFW`: page size MAX_PAGE_SIZE, `_PageWrite` sets REG_MCUFWDL+2 low 3 bits = page & 0x07.
> - `_BlockWrite`: MAX_REG_BOLCK_SIZE = 196; 3 phases: 196-byte, 8-byte, 1-byte writes. FW_8188E_START_ADDRESS.
> - `_FWFreeToGo`: poll REG_MCUFWDL for FWDL_ChkSum_rpt, then set MCUFWDL_RDY, clear WINTINI_RDY, then _8051Reset88E, then poll WINTINI_RDY.
> 
> Let me get those constants: FW_8188E_START_ADDRESS, MAX_PAGE_SIZE, FWDL_ChkSum_rpt, MCUFWDL_RDY, WINTINI_RDY, RAM_DL_SEL, FW_8188E_SIZE, POLLING_READY_TIMEOUT_COUNT.
> 
> Let me grep.
> 
> Also need to see the rest of rtl8188e_hal_init.c (the main init sequence — rtw_hal_init / Hal_HalInit) and hal/odm_HWConfig.c (PHY init), hal/HalPhyRf_8188e.c (RF cal), hal/odm_RTL8188E.c.
> 
> Let me batch grep.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && grep -rn "FW_8188E_START_ADDRESS\\|MAX_PAGE_SIZE\\|FWDL_ChkSum_rpt\\|MCUFWDL_RDY\\|WINTINI_RDY\\|RAM_DL_SEL\\|FW_8188E_SIZE\\|POLLING_READY_TIMEOUT_COUNT\\|IS_FW_HEADER_EXIST\\|struct rt_firmware_hdr" --include="*.h" --include="*.c" . | grep "#define\\|struct rt_firmware_hdr {" | head -30'}

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && grep -n "" include/HalHWImg8188E_FW.h | sed -n \'1,60p\''}

> **[reasoning]**
> Now let me read the rest of rtl8188e_hal_init.c: the main init sequence (rtw_hal_init). Let me find the function names.
> 
> Also let's look at hal/odm_HWConfig.c for the HW config, and the "step 42" init.
> 
> Let me list all function names in rtl8188e_hal_init.c and odm_HWConfig.c.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && echo "=== rtl8188e_hal_init.c functions ===" && grep -n "^[a-zA-Z_].*(" hal/rtl8188e_hal_init.c | grep -v ";" | head -60'}

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && echo "=== odm_HWConfig.c functions ===" && grep -n "^[a-zA-Z_].*(" hal/odm_HWConfig.c | grep -v ";" | head -60 && echo "=== HalPhyRf_8188e.c ===" && grep -n "^[a-zA-Z_].*(" hal/HalPhyRf_8188e.c | grep -v ";" | head -60'}

> **[reasoning]**
> Excellent. Now let me read the main HAL init sequence in rtl8188e_hal_init.c (the `rtw_hal_init` function at the end of the file) and `Hal_EfuseReadEFuse88E` (the direct read path). Let me read lines 810-980 and the main init function.
> 
> Also I need the "step 42" init which the project already documented in docs/init-sequence-8188e.md. Let me read that local doc to know what's already covered, so my report is additive.
> 
> Let me do both in parallel.

> **[tool read]** {'limit': 180, 'offset': 700, 'path': '/private/tmp/opencode/src/rtl8188eu/hal/rtl8188e_hal_init.c'}

> **[tool shell]** {'command': "cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport && sed -n '1,200p' docs/init-sequence-8188e.md"}

> **[reasoning]**
> The project has already done a lot of reverse-engineering work. My report needs to be ADDITIVE — find things they don't yet know.
> 
> Key gaps I can fill from the lwfinger/rtl8188eu source:
> 1. **The efuse map has MAC/xtal offsets that the vendor doc doesn't have**: `EEPROM_MAC_ADDR_88EU = 0xD7`, `EEPROM_XTAL_88E = 0xB9` (this is CrystalCap, not xtal frequency!). Note the driver uses `EEPROM_Default_CrystalCap_88E = 0x20`.
> 2. **The efuse logical map layout**: `out[section*8 + wordunit*2 + 0/1]` — so section N starts at byte N*8. This matches the vendor's `out[blok*8 + slot*2]`.
> 3. The `efuse_phymap_to_logical` in lwfinger is the SAME algorithm as the vendor's `ParsingEfuseContent_8188EU`.
> 4. **The direct read path for 8188E in lwfinger uses `EFUSE_CTRL = 0x0030`** with `EFUSE_CTRL+1 = 0x031`, `+2 = 0x032`, `+3 = 0x033`. And `ReadEFuseByte` does: write 0x031 = offset&0xff; read 0x032, write 0x032 = ((offset>>8)&0x03)|(readbyte&0xfc); read 0x033, write 0x033 = readbyte & 0x7f; then poll 0x033 bit 7 set (ready) — wait, the lwfinger code says "Check bit 32 read-ready" and polls until `((value32>>24)&0xff) & 0x80` i.e. 0x033 bit7 set. But the vendor code polls until bit7 CLEAR. Hmm! Interesting discrepancy. Let me look more carefully.
> 
> In lwfinger `efuse_OneByteRead`:
> ```c
> rtw_write8(pAdapter, EFUSE_CTRL+1, (u8)(addr & 0xff));
> rtw_write8(pAdapter, EFUSE_CTRL+2, ((u8)((addr>>8) & 0x03)) | (rtw_read8(pAdapter, EFUSE_CTRL+2) & 0xFC));
> rtw_write8(pAdapter, EFUSE_CTRL+3, 0x72);   /* read cmd */
> while (!(0x80 & rtw_read8(pAdapter, EFUSE_CTRL+3)) && (tmpidx < 100)) tmpidx++;
> if (tmpidx < 100) { *data = rtw_read8(pAdapter, EFUSE_CTRL); result = true; }
> ```
> So: write 0x033 = 0x72 (NOT read-modify-write!). And poll until bit7 is SET (0x80). Then read data at 0x030.
> 
> In `ReadEFuseByte` (also in lwfinger):
> ```c
> rtw_write8(Adapter, EFUSE_CTRL+1, (_offset & 0xff));
> readbyte = rtw_read8(Adapter, EFUSE_CTRL+2);
> rtw_write8(Adapter, EFUSE_CTRL+2, ((_offset >> 8) & 0x03) | (readbyte & 0xfc));
> readbyte = rtw_read8(Adapter, EFUSE_CTRL+3);
> rtw_write8(Adapter, EFUSE_CTRL+3, (readbyte & 0x7f));   /* Write bit 32 0 */
> /* Check bit 32 read-ready */
> retry=0; value32 = rtw_read32(Adapter, EFUSE_CTRL);
> while (!(((value32 >> 24) & 0xff) & 0x80) && (retry < 10000)) { value32 = rtw_read32(...); retry++; }
> rtw_udelay_os(50);
> value32 = rtw_read32(Adapter, EFUSE_CTRL);
> *pbuf = (u8)(value32 & 0xff);
> ```
> 
> So there are TWO variants in the same file! `ReadEFuseByte` writes 0x033 = readbyte & 0x7f (clears bit7 = start bit), then polls until bit7 SET (done). `efuse_OneByteRead` writes 0x033 = 0x72 (bits: 0x70 = ? and 0x02 = read cmd) then polls until bit7 set.
> 
> Hmm wait, in `ReadEFuseByte` the sequence is: write 0x033 = readbyte&0x7f → that clears bit 7 (the "start/ready" bit). Then it polls until bit7 becomes 1 again, meaning the read completed. That's the "clear busy to start, wait for ready" pattern.
> 
> The vendor (per the project's doc) does: write 0x033 = v & 0x7F (clear busy) then `for (i=0; i<100 && (read(0x033) & 0x80); i++) stall(1000);` — polls while busy is SET, i.e. waits for it to CLEAR. Then reads data. That's a different polarity!
> 
> Hmm. Actually the real hardware: 0x033 bit7 might be "EFUSE read ready" (1 = data ready). In lwfinger's ReadEFuseByte, writing 0x033 & 0x7f clears bit7 = clears the ready flag, then hardware sets it when done. So polling for SET is correct.
> 
> The vendor driver per the project doc polls while bit is SET — that would exit immediately since bit7 was just cleared. Wait: `for (i = 0; i < 100 && (read(0x033) & 0x80); i++)` — right after writing 0x033 = v & 0x7F, bit7 = 0, so the loop doesn't execute at all → reads data immediately with no wait! That would be a bug... unless the vendor's readback of 0x033 returns something different.
> 
> Hmm, but actually the project's doc says "tunggu busy clear" (wait for busy to clear). This is a significant potential BUG in the current implementation: **the polarity of the ready bit poll may be inverted**. This is a very actionable finding. Let me verify by checking the lwfinger `efuse_OneByteRead` more carefully: it writes 0x033 = 0x72 and polls until bit7 SET. 0x72 = 0b0111_0010. So bits: bit1 (0x02) = read command; bits 4,5,6 (0x70) = ? and bit7 = 0.
> 
> Hmm, and in `ReadEFuseByte` it writes 0x033 = (readbyte & 0x7f) — preserving bits 0-6 which after a previous 0x72 write would be 0x72 & 0x7f = 0x72. So bit1 (read cmd) stays set! So actually the sequence ReadEFuseByte is: after the first 0x72 write, subsequent writes keep 0x72. And polling for bit7 SET.
> 
> OK so both lwfinger variants poll for bit7 SET (ready=1). The project's doc says the vendor polls while bit7 is set. Let me double-check the project's implementation to see what it does. But I shouldn't modify files — I can read.
> 
> Let me look at src/urtwn/rtwn_efuse_8188e.c to check.
> 
> Also very important: **the READ of the data is at 0x030 via `rtw_read8(EFUSE_CTRL)`** and the lwfinger `ReadEFuseByte` reads a 32-bit value at 0x030 and takes the low byte. Note 0x030 low byte = data.
> 
> Another important detail: `hal_EfusePowerSwitch_RTL8188E` — the EFUSE power switch! The vendor's `EFUSE_OneByteRead` may require `Efuse_PowerSwitch(adapter, write=false, PwrState=true)` FIRST. In lwfinger, `rtw_efuse_access` calls `Efuse_PowerSwitch(padapter, write, true)` before the byte loop. But `Hal_EfuseReadEFuse88E` → `ReadEFuseByte` — does it call power switch? Let me check `rtl8188e_ReadEFuse` (line 971) and `ReadEFuseByIC` (945).
> 
> That's a KEY finding: **REG_EFUSE_ACCESS (0x?) with EFUSE_ACCESS_ON/OFF, REG_SYS_ISO_CTRL PWC_EV12V, REG_SYS_FUNC_EN FEN_ELDR, REG_SYS_CLKR LOADER_CLK_EN|ANA8M** must be set before EFUSE reads. Let me get those register numbers.
> 
> Let me check:
> - REG_EFUSE_ACCESS
> - EFUSE_ACCESS_ON / EFUSE_ACCESS_OFF
> - REG_SYS_ISO_CTRL, PWC_EV12V
> - REG_SYS_FUNC_EN, FEN_ELDR
> - REG_SYS_CLKR, LOADER_CLK_EN, ANA8M
> - EFUSE_TEST
> 
> Let me grep.
> 
> Also need: EFUSE_MAP_LEN_88E, EFUSE_REAL_CONTENT_LEN_88E, EFUSE_OOB_PROTECT_BYTES_88E, EFUSE_MAX_SECTION_88E, EFUSE_MAX_WORD_UNIT.
> 
> Let me grep all these.

Critical finding forming on EFUSE power-switch. Let me pull the exact register constants.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && grep -rn "define REG_EFUSE_ACCESS\\|define EFUSE_ACCESS_ON\\|define EFUSE_ACCESS_OFF\\|define REG_SYS_ISO_CTRL\\|define PWC_EV12V\\|define REG_SYS_FUNC_EN\\|define FEN_ELDR\\|define REG_SYS_CLKR\\|define LOADER_CLK_EN\\|define ANA8M\\|define EFUSE_TEST\\|define EFUSE_MAP_LEN_88E\\|define EFUSE_REAL_CONTENT_LEN_88E\\|define EFUSE_OOB_PROTECT_BYTES_88E\\|define EFUSE_MAX_SECTION_88E\\|define EFUSE_MAX_WORD_UNIT\\|define REG_EFUSE_CTRL\\|define

> **[tool shell]** {'command': "cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport && sed -n '1,160p' src/urtwn/rtwn_efuse_8188e.c"}

> **[reasoning]**
> Now I can see the project's current implementation, and I can find **concrete bugs/gaps**:
> 
> ### BUG 1: `EFUSE_ACCESS_8188E 0x106` is WRONG for the direct read path.
> In the lwfinger source, `REG_EFUSE_ACCESS = 0x00CF` and `EFUSE_ACCESS_ON = 0x69`. The value 0x69 is used for 0x106 in the *offload* path (`REG_PKT_BUFF_ACCESS_CTRL = 0x0106`, `TXPKT_BUF_SELECT = 0x69`). The project conflated the two:
> - `hal_EfusePowerSwitch_RTL8188E` writes **0x00CF** = 0x69 to turn EFUSE access ON (for direct read).
> - The offload path writes **0x0106** = 0x69 to select TX packet buffer.
> 
> So in the direct path the project writes 0x69 to 0x106 — that's the *packet buffer* access control register, not the EFUSE access protection register. **Should be 0x00CF.**
> 
> Wait, but the project's own doc says the vendor's `InitOffload_ReadEfuse_8188EU` writes 0x106 = 0x69. Yes, that's the offload path. And the direct path (`EFUSE_OneByteRead`) does NOT write 0x106 at all in the vendor (per project doc). Hmm, but the vendor's `EFUSE_OneByteRead` might be preceded by `Efuse_PowerSwitch`. Let me check the vendor reverse doc.
> 
> ### BUG 2: The ready-bit polarity.
> lwfinger polls until bit7 **SET** (ready), not CLEAR. The project polls until bit7 **CLEAR**. This is the critical difference. Let me verify with the lwfinger `ReadEFuseByte` once more:
> 
> ```c
> /* Write bit 32 0 */
> readbyte = rtw_read8(Adapter, EFUSE_CTRL+3);
> rtw_write8(Adapter, EFUSE_CTRL+3, (readbyte & 0x7f));
> /* Check bit 32 read-ready */
> retry = 0;
> value32 = rtw_read32(Adapter, EFUSE_CTRL);
> while (!(((value32 >> 24) & 0xff) & 0x80) && (retry < 10000)) {
>     value32 = rtw_read32(Adapter, EFUSE_CTRL);
>     retry++;
> }
> ```
> value32>>24 = byte at 0x033. So it loops while bit7 of 0x033 is 0 → waits for bit7 SET. Yes, definitively: **wait for bit7 to become 1**.
> 
> And `efuse_OneByteRead`:
> ```c
> rtw_write8(pAdapter, EFUSE_CTRL+3, 0x72);  /* read cmd */
> while (!(0x80 & rtw_read8(pAdapter, EFUSE_CTRL+3)) && (tmpidx < 100)) tmpidx++;
> ```
> → waits for bit7 SET. Confirmed twice.
> 
> So the project's "wait for busy CLEAR" is **inverted**. This is very likely THE bug blocking MAC/xtal. This is my headline finding for B.
> 
> Hmm, but wait. Let me be careful. The vendor's decompiled code (per project doc) is: `write 0x033 = v & 0x7F; for (i=0;i<100 && (read(0x033)&0x80); i++) stall(1000); data = read(0x030);`
> 
> Reading vendor code again: the loop condition is `(read(0x033) & 0x80)` — loop WHILE bit7 SET. So it waits for bit7 to CLEAR. Hmm, that contradicts lwfinger.
> 
> Unless... the decompilation in the project doc misread the condition. OR the vendor driver really does a different thing. Let me look at the actual vendor reverse doc in the project to see the exact decompiled code.
> 
> Actually, there's a subtlety: maybe the vendor writes 0x033 = v & 0x7F to *clear* the "start/busy" bit, and bit7 is the READY bit. So after clearing bit7, the hardware needs to SET bit7 when the read completes. The vendor loop "while bit7 set, delay" would exit immediately (bit7 = 0 right after the write). Then read 0x030 → garbage. So the vendor code as decompiled would be a bug... unless the decompiler produced `!(x & 0x80)`.
> 
> Hold on — let me re-read the project doc text: "for (i = 0; i < 100 && (read(0x033) & 0x80); i++) stall(1000);      // tunggu busy clear". Hmm, but maybe the actual decompiled condition was `(!(read(0x033) & 0x80))`.
> 
> I should check the project's `docs/vendor-reverse.md` for the actual decompiled listing. Let me look.
> 
> Also:
> 
> ### BUG 3: MAC offset.
> Project uses `rom + 215` for MAC and `rom[185]` for xtal, `rom[184]` channel plan.
> From lwfinger: `EEPROM_MAC_ADDR_88EU = 0xD7 = 215` ✓ and `EEPROM_XTAL_88E = 0xB9 = 185` ✓ and `EEPROM_ChannelPlan_88E = 0xB8 = 184` ✓. 
> 
> So the project's offsets are RIGHT. Good. But note: `EEPROM_XTAL_88E` (0xB9) is used by lwfinger as `CrystalCap` (EEPROM_Default_CrystalCap_88E = 0x20), not as the xtal frequency. The vendor's `InitCrystalFrequency_8188E` probably reads a different field for the actual xtal (20MHz vs 40MHz). Let me check the vendor reverse doc.
> 
> Hmm — actually for 8188E, the crystal is always 40MHz? No... RTL8188E supports 20/26/40MHz crystals? Actually 8188E is 40MHz I think. Let's check: in lwfinger, `PHY_SetBBReg(Adapter, REG_AFE_XTAL_CTRL, 0x7ff800, (CrystalCap | (CrystalCap << 6)))` where CrystalCap comes from `hwinfo[EEPROM_XTAL_88E]`. So 0xB9 = crystal *capacitance* (load cap) code, used for AFE XO tuning. That's a genuinely useful finding: **efuse[0xB9] = crystal cap code, and the 8188E applies it to REG_AFE_XTAL_CTRL (0x24) bits [10:6] and [4:0]**.
> 
> Also `EEPROM_Default_CrystalCap_88E = 0x20` and `EEPROM_Default_TxPwDiff_CrystalCap = 0x5`.
> 
> Note: the project stores `r->xtal = rom[185]` — the value 0x20 default is a cap code, and if the efuse byte is 0xFF (unprogrammed), that'd be invalid. Worth flagging.
> 
> Now, what about the actual "xtal frequency"? In the vendor, `InitCrystalFrequency_8188E`. Let me look at the vendor-reverse doc.
> 
> ### BUG 4: The `rtw_seq_efuse_parse` — need to verify it matches `efuse_phymap_to_logical`.
> 
> Key: lwfinger's `efuse_phymap_to_logical` has output layout `efuseTbl[(i*8)+(j*2)]` where i = section (0..EFUSE_MAX_SECTION_88E-1) and j = word unit (0..3). So section N occupies bytes N*8 .. N*8+7. And the MAC at 0xD7 = 215 → section 215/8 = 26 (0x1A), word unit (215%8)/2 = 3, byte 1. So the logical map is 512 bytes = 64 sections × 8 bytes.
> 
> EFUSE_MAX_SECTION_88E — need value. Let me grep. It wasn't in the grep output; maybe it's in rtl8188e_spec.h with a different spelling. Let me search again.
> 
> Also EFUSE_MAP_LEN_88E, EFUSE_REAL_CONTENT_LEN_88E, EFUSE_OOB_PROTECT_BYTES_88E.
> 
> Let me grep for them in all headers.
> 
> Let me also check the vendor-reverse doc for InitCrystalFrequency_8188E and EFUSE_OneByteRead.
> 
> Let me batch these.

Found a likely critical polarity bug. Let me verify against the project's own vendor RE notes and the exact EFUSE constants.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && grep -rn "EFUSE_MAX_SECTION_88E\\|EFUSE_MAP_LEN_88E\\|EFUSE_REAL_CONTENT_LEN_88E\\|EFUSE_OOB_PROTECT_BYTES_88E\\|EFUSE_MAX_WORD_UNIT" --include="*.h" . ; echo "--- defs in .c ---"; grep -rn "define EFUSE_MAX_SECTION_88E\\|define EFUSE_MAP_LEN_88E\\|define EFUSE_REAL_CONTENT_LEN_88E\\|define EFUSE_OOB_PROTECT" --include="*.c" .'}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport && grep -n "InitCrystalFrequency\\|EFUSE_OneByteRead\\|0x033\\|CrystalCap\\|crystal" docs/vendor-reverse.md | head -40'}

> **[reasoning]**
> Interesting: `docs/vendor-reverse.md:310` says "crystal cap dari rom[6] (bukan 185!)". Let me read the vendor-reverse doc around there.
> 
> Key constants:
> - EFUSE_REAL_CONTENT_LEN_88E = 256
> - EFUSE_MAP_LEN_88E = 512
> - EFUSE_MAX_SECTION_88E = 64
> - EFUSE_MAX_WORD_UNIT_88E = 4
> - EFUSE_OOB_PROTECT_BYTES_88E = 18
> 
> So 64 sections × 4 word units × 2 bytes = 512 bytes logical map. And the physical content is 256 bytes.
> 
> Now let's read the vendor-reverse doc.

> **[tool shell]** {'command': "cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport && sed -n '270,380p' docs/vendor-reverse.md"}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport && grep -n "EFUSE_OneByteRead" -A 40 docs/vendor-reverse.md | head -70'}

> **[reasoning]**
> The project's vendor RE is quite complete. They already found:
> - rom[185] = xtal ✓ (matches `EEPROM_XTAL_88E 0xB9`)
> - rom[6] = crystal cap
> - MAC at rom[0xD7] = 215 ✓ (matches `EEPROM_MAC_ADDR_88EU 0xD7`)
> - The efuse mask table from vendor binary.
> 
> They also mention the "EFUSE_OneByteRead" in init-sequence doc, but the vendor-reverse doc doesn't have it. So the doc in init-sequence-8188e.md §3 has the decompiled version. Let me re-read that: 
> 
> ```c
> PlatformIOWrite1Byte(adapter, 0x031, offset & 0xFF);
> v = PlatformEFIORead1Byte(adapter, 0x032);
> PlatformIOWrite1Byte(adapter, 0x032, (v & 0xFC) | ((offset >> 8) & 3));
> v = PlatformEFIORead1Byte(adapter, 0x033);
> PlatformIOWrite1Byte(adapter, 0x033, v & 0x7F);
> for (i = 0; i < 100 && (read(0x033) & 0x80); i++) stall(1000);
> data = PlatformEFIORead1Byte(adapter, 0x030);
> ```
> 
> Now — the polarity question. lwfinger's `efuse_OneByteRead` is essentially the same function, and it writes **0x033 = 0x72** (a fixed value, not read-modify-write) then polls until bit7 **SET**.
> 
> Interesting: the project version writes `v & 0x7F` (RMW preserving bits 0-6) and polls while bit7 SET (exit when CLEAR).
> 
> Now consider: the vendor's `EFUSE_OneByteRead` is used to read the *physical* efuse bytes, and the lwfinger `efuse_OneByteRead` writes 0x72. The value 0x72 = 0b0111_0010. Bit 7 = 0 (not busy). Bits 4,5,6 = 0x70. Bit 1 = 0x02.
> 
> Hypothesis: 0x033 bit 7 = "read data ready" (0 = busy/not ready, 1 = ready), and writing 0x72 starts a read (bit1 = read command, bit0 = ?). The lwfinger code polls until bit7 == 1.
> 
> But the vendor's decompiled loop `while (read(0x033) & 0x80)` would then exit immediately. Unless the decompile is imprecise, OR unless the vendor wrote `v & 0x7F` (bit7=0) and the hardware takes time to set bit7=1... then reading immediately gives stale data.
> 
> Actually hold on. Let me reconsider: maybe bit7 is a "start" trigger, and 1 = read in progress / busy. Writing 0x72 with bit7=0... hmm that doesn't start anything.
> 
> OK let me consider the most likely truth: For RTL8188E, register 0x033 is `EFUSE_CMD` / `EFUSE_ACCESS`. In the 92C family, 0x30 = EFUSE_CTRL with ADDR in bits 8-17 and VALID in bit 31. In 8188E, the lwfinger driver defines:
> - 0x030 = EFUSE_CTRL (read returns data at low byte)
> - 0x031 = addr low
> - 0x032 = addr high
> - 0x033 = cmd/status
> 
> The lwfinger `ReadEFuseByte` comment says: "/* Write bit 32 0 */" then "/* Check bit 32 read-ready */" and loops `while (!((value32>>24)&0x80))` → wait for bit 32 (=0x033 bit 7) to be 1.
> 
> Actually hmm — "Write bit 32 0" then "check bit 32 read-ready": so writing bit7=0 STARTS the read, and the hardware sets bit7=1 when ready. This is definitive from the lwfinger source. Two independent functions in the same file agree.
> 
> So the correct sequence for 8188E direct efuse read:
> 1. write 0x031 = addr & 0xFF
> 2. read 0x032, write 0x032 = (v & 0xFC) | ((addr >> 8) & 3)
> 3. write 0x033 = (v & 0x7F)   [clear ready bit → starts read]   (or write 0x72)
> 4. poll 0x033 until bit7 == 1 (max ~10000 iterations in ReadEFuseByte, 100 in efuse_OneByteRead)
> 5. read data at 0x030 (low byte)
> 
> The project does step 4 with INVERTED polarity (waits for bit7 == 0) and thus reads 0x030 immediately after clearing bit7 — i.e. it reads STALE/garbage data, and worse, after 100 iterations of 1ms it will always have bit7 == 0 (since it cleared it) so it exits immediately on iteration 0. Hence **MAC = ff:ff:ff:ff:ff:ff**. That perfectly explains the observed symptom!
> 
> This is a very high-value finding. Let me make sure I'm right by checking if there's any other source (e.g., the Zircon/Chromium copy of rtl8188eu, or other rtl8188eu forks) that also does it, plus check `Hal8188EPhyCfg.h` and `rtl8188e_phycfg.c` for `GetEfuseDefinition` — wait, the lwfinger `rtl8188e_phycfg.c` didn't have it. Let me check `hal/odm_RTL8188E.c`.
> 
> Actually, better corroboration: let me look for OTHER independent implementations of the 8188E efuse read. Options:
> - The `RoryWarden/rtl8188eu-driver` (2026, new).
> - `quickreflex/rtl8188eus`
> - The Zircon OS copy (zircon-guest.googlesource.com/third_party/linux/drivers/staging/rtl8188eu) — that's Google-hosted, might be accessible.
> - `martinhoffmann`? 
> 
> Let me also check `ralink`? no.
> 
> Let me check the itlwm/OpenBSD urtwn approach: OpenBSD's urtwn reads efuse via the 92C-style 0x30 register for 92C chips; for 88e it does something different. Let me look at the local OpenBSD if_urtwn.c for the efuse handling of 88e — this is important because our project is based on it and may have inherited the wrong path.
> 
> Let me look at the local upstream/openbsd/sys/dev/usb/if_urtwn.c.
> 
> Let me do that plus grab another independent 8188E efuse implementation.
> 
> Also for the MAC offset: project uses rom+215 for MAC. Let me double check with OpenBSD urtwn's r88e rom struct.
> 
> Let me run several greps.

Now let me cross-check against the OpenBSD urtwn source (local) and find an independent EFUSE implementation.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/openbsd/sys/dev/usb && wc -l if_urtwn.c && grep -n "efuse\\|EFUSE" if_urtwn.c | head -60'}

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src && for r in "quickreflex/rtl8188eus" "RoryWarden/rtl8188eu-driver"; do n=$(echo $r|tr \'/\' \'_\'); for br in master main; do curl -sSL --max-time 90 "https://codeload.github.com/$r/tar.gz/refs/heads/$br" -o "$n.tgz" && tar tzf "$n.tgz" >/dev/null 2>&1 && { rm -rf "$n"; mkdir -p "$n"; tar xzf "$n.tgz" -C "$n" --strip-components=1 && echo "OK $n ($br)"; break; }; done; done; ls -d */'}

> **[reasoning]**
> Interesting: OpenBSD's if_urtwn.c has NO efuse code at all! Let me confirm — grep returned nothing for efuse. Let me check more carefully (maybe case).
> 
> Let me grep for r88e rom and xtal in if_urtwn.c.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/openbsd/sys/dev/usb && echo "--- efuse ---" && grep -in "efuse" if_urtwn.c | head -30; echo "--- r88e struct ---" && grep -n "r88e\\|88e\\|xtal\\|R88E" if_urtwn.c | head -50'}

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src && echo "=== RoryWarden efuse ===" && grep -rn "0x031\\|0x032\\|0x033\\|efuse\\|EFUSE" RoryWarden_rtl8188eu-driver/*.c RoryWarden_rtl8188eu-driver/*.h 2>/dev/null | head -40'}

> **[reasoning]**
> HUGE finding: **OpenBSD's urtwn has NO efuse code at all.** The `crystal_cap` is a compile-time constant from `rtl8188eu_*` config, not read from efuse.
> 
> Let me look at the OpenBSD urtwn 88e code in detail — lines 2280-2500 (the `urtwn_r88e_*` config), and see where the MAC address comes from (line 2308: `rtl8188eu_mac[]` — a hardcoded table?).
> 
> Let me read that region.
> 
> This is very important for topic E and A: the OpenBSD driver uses a **compiled-in MAC address table**! Let's see.
> 
> Let me read lines 2250-2500.

Major finding: OpenBSD's urtwn has **no EFUSE code at all**. Let me examine its 88E config path.

> **[tool read]** {'limit': 150, 'offset': 2270, 'path': '/Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/openbsd/sys/dev/usb/if_urtwn.c'}

> **[reasoning]**
> This is the OpenBSD urtwn `urtwn_bb_init` and `urtwn_mac_init`. This is EXACTLY the "HAL/PHY/RF initialization sequence" the project needs for M1d. And it does NOT use the vendor's 42-step init — it uses pre-computed register tables (`rtl8188eu_bb_prog`, `rtl8188eu_mac[]`).
> 
> This is a very important strategic finding: **OpenBSD's urtwn 88E path is a complete, working, table-driven HAL init that bypasses the vendor's 42-step sequence entirely.** The project should port that rather than the vendor's step-42 flow. This is a big actionable recommendation.
> 
> Let me look at:
> 1. `rtl8188eu_bb_prog` — where is it defined? Probably in if_urtwn.c itself or a header. Let me grep.
> 2. `urtwn_r88e_power_on`
> 3. `urtwn_rf_init` / `urtwn_rf_antenna_config`
> 4. The `crystal_cap` — how is it set? `sc->sc_sc.crystal_cap`
> 
> Let me grep for these.
> 
> Also very important: **How does OpenBSD get the MAC address?** It doesn't read efuse. Let me find `sc->sc_sc.ether` or the MAC setup.
> 
> Let me grep.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/openbsd/sys/dev/usb && grep -n "rtl8188eu_bb_prog\\|rtl8188eu_mac\\|crystal_cap\\|sc_sc.ether\\|r88e_rom\\|urtwn_rf_init\\|urtwn_rf_antenna\\|R92C_AFE_XTAL_CTRL" if_urtwn.c | head -40; echo "=== where defined ==="; ls -la; find /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/openbsd -name "*.h" | head'}

> **[tool shell]** {'command': "cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/openbsd/sys/dev/usb && sed -n '1,80p' if_urtwn.c"}

> **[reasoning]**
> The local OpenBSD checkout only has `if_urtwn.c`, `rtwnvar.h`, `r92creg.h`, `usbdevs`. The BB programming tables (`rtl8188eu_bb_prog`) are in `r92creg.h`? No, probably in a separate file `if_urtwn.c`... Let me grep r92creg.h for rtl8188eu_bb_prog.
> 
> Actually, in OpenBSD, `rtl8188eu_bb_prog` is defined in `sys/dev/ic/r92creg.h`? Let's check. Or maybe in `if_urtwnvar.h`. Let me grep.
> 
> Also I need `r92creg.h` for all the register definitions.
> 
> Let me grep across the openbsd dir.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/openbsd/sys/dev/ic && grep -n "rtl8188eu_bb_prog\\|rtl8188eu_mac\\|r92c_bb_prog\\|struct r92c_bb_prog" r92creg.h | head -20; echo "=== size ==="; wc -l r92creg.h rtwnvar.h'}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/openbsd/sys/dev/ic && grep -n "R92C_AFE_XTAL_CTRL\\b\\|R92C_AFE_XTAL_CTRL_ADDR\\|R92C_AFE_XTAL_CTRL_EXT\\|R92C_AFE_CTRL3_ADDR\\|R92C_SYS_FUNC_EN\\b\\|R92C_RF_CTRL\\b\\|R92C_LDOHCI12_CTRL\\|R92C_TXPKTBUF\\|R92C_RXPKT\\|R92C_TDECTRL" r92creg.h | head -40'}

> **[reasoning]**
> Good. Now I have the OpenBSD 88E BB programming table at r92creg.h:2445 and the MAC table at :1836. This is the concrete "PHY init" for 88E.
> 
> Now, a critical question: does OpenBSD's urtwn set the MAC address from efuse? Let me check how it gets the MAC. Search for "ether" in if_urtwn.c.
> 
> Let me also confirm: `crystal_cap` — where does it come from? `sc_sc.crystal_cap` — probably set from a device-specific table or default.
> 
> Let me grep.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/openbsd/sys/dev/ic && grep -n "crystal_cap\\|board_type\\|struct urtwn_sc_sc\\|sc_sc" rtwnvar.h; echo "=== if_urtwn MAC setup ==="; cd ../usb && grep -n "ether\\|ieee80211_softc_init\\|sc_sc\\." if_urtwn.c | head -40'}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/openbsd/sys/dev/usb && grep -n "urtwn_r88e_power_on" -A 80 if_urtwn.c | sed -n \'1,100p\''}

> **[reasoning]**
> This is very informative. Let me now confirm how OpenBSD's urtwn sets the MAC address — I saw `sc_sc.sc_ops` and the net80211 layer. In OpenBSD, `rtwn` (the bus-agnostic part, in sys/net/if) calls `ieee80211_softc_init` and the MAC comes from... Let me look for `rtwn_attach` in the openbsd source (net80211 rtwn). The local checkout only has if_urtwn.c, rtwnvar.h, r92creg.h, usbdevs. The `rtwn.c` in sys/net/if is missing.
> 
> Anyway — in OpenBSD rtwn.c, `rtwn_attach()` does:
> ```c
> 	/* Read the MAC address from the EEPROM/EFUSE ... */
> ```
> Actually, I recall OpenBSD's rtwn.c reads the MAC address from the device's "ethernet address" via the USB device descriptor (`uaa->vendor`/`product` ... no). Actually in OpenBSD, `rtwn_attach` does:
> 
> ```c
> 	/*
> 	 * Some devices don't have a valid MAC address in the EEPROM,
> 	 * so use the one from the USB descriptor or generate one.
> 	 */
> ```
> 
> Let me fetch the OpenBSD rtwn.c to be accurate. But git.openbsd.org is blocked. Let me try github mirror: "github.com/openbsd/src"? Hmm, there's "openbsd/src" on GitHub? There is a mirror at https://github.com/openbsd/src. Let me try codeload for a specific file — but codeload gives whole repo tarball which is huge (OpenBSD src is ~200MB).
> 
> Alternative: use the github.com blob URL via webfetch (worked earlier). Let me use that for specific files.
> 
> Let me use webfetch on:
> - https://github.com/openbsd/src/blob/master/sys/net/if/rtwn.c  (hmm, is there such a mirror?)
> 
> Let me check via websearch/webfetch.
> 
> Actually, let me prioritize. The user's priorities: B (EFUSE) and D (macOS IO80211). I have strong B findings. Let me now:
> 1. Verify the EFUSE polarity issue with an independent implementation (quickreflex/rtl8188eus, RoryWarden, or Zircon copy).
> 2. Nail down D.
> 
> Let me check quickreflex first for efuse.
> 
> Then move to D which is the bigger unknown.
> 
> Let me also check the project's own AirPort-RTW upstream (a real macOS IO80211 driver for Realtek!) — that's the closest model for D.
> 
> Let me batch: check quickreflex efuse + look at AirPort-RTW structure.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/quickreflex_rtl8188eus && ls && echo "=== efuse refs ===" && grep -rn "0x031\\|0x032\\|0x033\\|EFUSE\\|efuse" --include="*.c" --include="*.h" . 2>/dev/null | head -30'}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/AirPort-RTW && ls -R src kext | head -60; echo "=== README ==="; head -60 README.md'}

> **[reasoning]**
> **AirPort-RTW is exactly what I need for D.** It's a native macOS IO80211 driver for Realtek PCIe cards, using IO80211FamilyLegacy and IOSkywalkFamily. This is the best template for making a USB-based IO80211 interface appear in the Wi-Fi menu.
> 
> Let me examine the AirPort-RTW kext source in depth:
> - `src/kext/` — the IO80211 interface classes
> - Info.plist
> - The IO80211Family bundle loading
> 
> Let me look at the kext dir.
> 
> Also `rtw_ieee80211.c:1388: "MAC Address from efuse error, assign default one !!!"` in quickreflex — let me look at that, it's the MAC-from-efuse extraction in the Linux driver. That will confirm the MAC offset.
> 
> Let me batch.

AirPort-RTW is the ideal template for topic D. Let me examine it and the Linux MAC-from-EFUSE code.

> **[tool shell]** {'command': "cd /private/tmp/opencode/src/quickreflex_rtl8188eus && sed -n '1360,1400p' core/rtw_ieee80211.c"}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/AirPort-RTW && ls -R src/kext | head -60; echo "=== find plist ==="; find . -name "Info.plist" -not -path "./.git/*" | head'}

> **[reasoning]**
> PERFECT. AirPort-RTW has `RTW88USBDevice.cpp` — so it DOES have a USB device path (even though README says USB not supported). This is a very relevant template.
> 
> Let me examine:
> 1. `AirPortRTW.kext/Contents/Info.plist` — the IO80211Family / bundle structure
> 2. `AirPortRTWKext.cpp` — the IO80211Family bundle loader
> 3. `AirPortRTWInterface.cpp` — IO80211Interface subclass
> 4. `RTW88USBDevice.cpp` — USB device matching
> 
> Let me read them.
> 
> First, let me find `rtw_macaddr_cfg` in the lwfinger driver to see the actual MAC offset used.
> 
> Let me batch: rtw_macaddr_cfg in lwfinger + AirPortRTW Info.plist.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && grep -rn "rtw_macaddr_cfg" --include="*.c" . | head -5; echo "---"; grep -n "rtw_macaddr_cfg" -A 40 core/rtw_ieee80211.c | head -60'}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/AirPort-RTW && cat AirPortRTW.kext/Contents/Info.plist'}

> **[reasoning]**
> Now I have the AirPortRTW Info.plist — key facts for D:
> - `OSBundleLibraries` includes `com.apple.iokit.IO80211FamilyLegacy` 12.0, `com.apple.iokit.IONetworkingFamily` 3.4, `com.apple.iokit.IOSkywalkFamily` 1.0.
> - `OSBundleRequired` = `Network-Root`
> - `IOKitPersonalities` with `IOProviderClass` = `IOPCIDevice` and `IOPCIMatch`.
> 
> Note: this is the modern "IO80211FamilyLegacy" + "IOSkywalkFamily" approach. For a USB device, `IOProviderClass` would be `IOUSBHostDevice` or `IOUSBHostInterface`.
> 
> Now let me look at:
> - `AirPortRTWKext.cpp` — the bundle loader / IO80211Family mechanism
> - `AirPortRTWInterface.cpp` — the IO80211Interface subclass
> - `RTW88USBDevice.cpp` — USB device
> 
> Let me read AirPortRTWKext.cpp/hpp first.
> 
> Also, I should look at the itlwm AirportItlwm for the older-style approach (IO80211Family vs IO80211FamilyLegacy).
> 
> Let me batch read.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/AirPort-RTW/src/kext && wc -l *.cpp *.hpp && echo "=== AirPortRTWKext.hpp ===" && cat AirPortRTWKext.hpp'}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/AirPort-RTW/src/kext && cat AirPortRTWKext.cpp'}

> **[reasoning]**
> Now let me look at `RTW88Kext.cpp` (the class that registers with IO80211Family) and `RTW88USBDevice.cpp`. And `AirPortRTWInterface.cpp`.
> 
> The `RTW88Kext.cpp` is only 39 lines — probably a "RTW88Kext" personality class.
> 
> Let me read both.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/AirPort-RTW/src/kext && echo "=== RTW88Kext.cpp ===" && cat RTW88Kext.cpp && echo "=== RTW88Kext.hpp ===" && cat RTW88Kext.hpp && echo "=== AirPortRTWInterface.cpp ===" && cat AirPortRTWInterface.cpp && echo "=== AirPortRTWInterface.hpp ===" && cat AirPortRTWInterface.hpp'}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/AirPort-RTW/src/kext && grep -n "IO80211\\|attachToController\\|IO80211Interface\\|IO80211Controller\\|IO80211Provider\\|IO80211Family\\|findProvider\\|IO80211FamilyLegacy" AirPortRTW.cpp | head -60'}

> **[reasoning]**
> This is exactly the D material. AirPortRTW is a full `IO80211Controller` subclass with `IO80211Interface` subclass, using `IO80211FamilyLegacy` + `IOSkywalkFamily`.
> 
> Key things to extract:
> 1. `createInterface` / `attachInterface` / `detachInterface` — how the interface is created and attached
> 2. The `IO80211Controller` lifecycle: `createWorkLoop`, `attachToController`
> 3. `apple80211_ioctl` — the IOCTL dispatch
> 4. `setLinkStatus`, `setMedium`, `publish` of BSD name
> 5. `getHardwareAddressForInterface`
> 6. `enableFeature` / `IO80211SupportedFeatures`
> 7. The "IO80211Family" bundle mechanism — how the kext gets loaded as an IO80211 family member.
> 
> Let me look at the specific functions. Let me grep for the key ones and read them.
> 
> Also let's check RTW88USBDevice.cpp for the USB side.
> 
> Let me also check the itlwm AirportItlwm for the older approach.
> 
> Let me batch: read AirPortRTW.cpp key sections (createInterface, attachInterface, start) and RTW88USBDevice.cpp.

Now let me extract the critical IO80211 lifecycle code from AirPortRTW.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/AirPort-RTW/src/kext && grep -n "^bool AirPortRTW::\\|^void AirPortRTW::\\|^IOReturn AirPortRTW::\\|^SInt32 AirPortRTW::\\|^OSObject \\*AirPortRTW::\\|^void AirPortRTW::" AirPortRTW.cpp | head -70'}

> **[tool shell]** {'command': "cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/AirPort-RTW/src/kext && sed -n '1,120p' RTW88USBDevice.cpp"}

> **[reasoning]**
> Excellent. Now let me get the key IO80211 lifecycle details from AirPortRTW.cpp — the `start()` function, `configureInterface`, `createMediumTables`, `getHardwareAddress`, `apple80211_ioctl`, `enableFeature`. And the `IO80211Controller` attach mechanism.
> 
> Also very important: how does the driver get discovered by IO80211FamilyLegacy? The mechanism is:
> - The kext's `IOKitPersonalities` matches the device and starts an `IO80211Controller` subclass.
> - `IO80211Controller::start()` calls `attachToController()`? Actually in IO80211Family, the mechanism is: `IO80211Controller` publishes the service, and `IO80211FamilyLegacy` (loaded as a bundle by `com.apple.iokit.IO80211FamilyLegacy` OSBundleLibraries) attaches to it and provides the `IO80211Interface`.
> 
> Let me check the details: In the classic Apple wireless driver architecture (AirPort_BrcmNIC / AirPort_IOPCIFamily):
> - `IO80211Controller` is the base class in IO80211Family.
> - The driver subclass implements `attachToController(IO80211Controller *)`? No...
> - Actually: `IO80211Controller::attachToController(IO80211Controller *controller)` is called by `IO80211Provider`?
> 
> Let me look at the Apple headers. The vendor/MacKernelSDK in the project may have IO80211 headers! Let me check.
> 
> Actually, the project has `vendor/MacKernelSDK`. Let me check if it includes IOKit/80211/IO80211Interface.h. That would be a goldmine for D.
> 
> Let me check.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/vendor && ls -R MacKernelSDK 2>/dev/null | head -40; echo "=== find IO80211 headers ==="; find / -name "IO80211Interface.h" -not -path "*/proc/*" 2>/dev/null | head -10'}

> **[tool shell]** {'command': "cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/AirPort-RTW/src/kext && sed -n '104,270p' AirPortRTW.cpp"}

> **[reasoning]**
> This is the complete IO80211 lifecycle:
> 
> 1. `start(provider)`:
>    - `super::start(provider)` → `IO80211Controller::start()` calls `createWorkLoop()` which creates an `IO80211WorkLoop`.
>    - Create medium tables → `setCurrentMedium` / `setSelectedMedium`
>    - `attachInterface((IONetworkInterface **)&_netif, true)` → creates the `IO80211Interface` subclass
>    - `IO80211Controller::setLinkStatus(kIONetworkLinkValid)`
>    - `registerService()` (controller)
>    - `_netif->registerService()` (interface)
> 
> 2. `apple80211_ioctl` — the IOCTL dispatch for scan/join etc.
> 3. `enableFeature(IO80211FeatureCode, void*)`
> 
> Now I need:
> - `IO80211Controller` header from MacKernelSDK (project has it!) — let me read IO80211Interface.h and IO80211Controller.h to get the exact API and the `attachToController` mechanism.
> - How IO80211FamilyLegacy attaches.
> 
> Let me look at the MacKernelSDK 80211 headers.
> 
> Let me also check the itlwm AirportItlwm which is the classic IO80211 driver.
> 
> Let me batch.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/vendor/MacKernelSDK/Headers/IOKit/80211 && ls -la && echo "=== IO80211Controller.h ===" && cat IO80211Controller.h'}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/vendor/MacKernelSDK/Headers/IOKit/80211 && cat IO80211Interface.h'}

> **[reasoning]**
> I now have the full IO80211Controller / IO80211Interface API. 
> 
> Key pure-virtual methods that a subclass MUST implement (marked `= 0`):
> - `apple80211Request(unsigned int, int, IO80211Interface*, void*)` = 0
> - `stopDMA()` = 0
> - `hardwareOutputQueueDepth(IO80211Interface*)` = 0
> - `performCountryCodeOperation(IO80211Interface*, IO80211CountryCodeOp)` = 0
> - `enableFeature(IO80211FeatureCode, void*)` = 0
> 
> And overridable: `apple80211_ioctl`, `apple80211_ioctl_get`, `apple80211_ioctl_set`, `createInterface`, `attachInterface`, `configureInterface`, `getHardwareAddress`, `getHardwareAddressForInterface`, `createWorkLoop`, `enable`, `disable`, `outputStart` (under __PRIVATE_SPI__), `monitorModeSetEnabled`, `inputPacket`.
> 
> Now, the critical "how does the driver get discovered by the Wi-Fi menu" question. Let me research the IO80211Family mechanism:
> - `IO80211FamilyLegacy` is a kext bundle that provides the "family" glue. It's loaded via `OSBundleLibraries` in the third-party kext's Info.plist.
> - The `IO80211Family` (classic) had a special mechanism where the driver kext's `IOKitPersonalities` had `IOProviderClass = IO80211Controller`? No.
> 
> Actually, the classic mechanism (AirPort2 / AirPort_BrcmNIC):
> - Third-party driver provides an `IO80211Controller` subclass matched to the device.
> - IO80211Family (or IO80211FamilyLegacy) is loaded as a bundle dependency and hooks the controller: it creates the `IO80211Interface` and manages the CoreWLAN/Apple80211 interface.
> 
> But also: the "AirPort" app / CoreWLAN scans for IO80211Interface instances.
> 
> Let me research this. Key: 
> - `IO80211Family` bundle: `com.apple.iokit.IO80211Family`
> - `IO80211FamilyLegacy`: `com.apple.iokit.IO80211FamilyLegacy`
> - The `IOSkywalkFamily` for macOS 11+.
> 
> Also, there is the important question of the "IO80211Family" plist keys the brief mentions (e.g. `IO80211SupportedFeatures`). Let me check itlwm's AirportItlwm Info.plist and code.
> 
> Let me look at the itlwm AirportItlwm (local) and the newer OpenIntelWireless_itlwm (downloaded).
> 
> Let me check both. The itlwm one is the classic IO80211 driver (IO80211Family, not Legacy).
> 
> Let me examine.

Now let me examine the itlwm AirportItlwm frontend (classic IO80211Family path).

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/itlwm && ls AirportItlwm && echo "=== plist ===" && find . -name "Info.plist" | head && cat AirportItlwm/Info.plist 2>/dev/null | head -80'}

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/OpenIntelWireless_itlwm && ls AirportItlwm && find . -name "Info.plist" | head -5'}

> **[reasoning]**
> Now I have the classic `com.apple.iokit.IO80211Family` (1200.12.2b1) bundle dependency.
> 
> Important: `com.apple.iokit.IO80211Family` version 1200.12.2b1 corresponds to the macOS 12 (Monterey) version. For macOS 13+ (Ventura/Sonoma/Sequoia), you need `IO80211FamilyLegacy` + `IOSkywalkFamily` (like AirPort-RTW). itlwm has "AirportItlwm-Monterey-Info.plist" and "AirportItlwm-Sonoma-Info.plist" variants — exactly this distinction.
> 
> Let me diff the two Info.plist files to see the Sonoma vs Monterey differences (very actionable for the project since they're on macOS 15.8.1 / Darwin 24.6).
> 
> Let me also look at the Sonoma plist.
> 
> And check AirportItlwm.cpp for the IO80211Controller subclass and the key methods.
> 
> Let me batch.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/itlwm/AirportItlwm && diff <(plutil -convert xml1 -o - Info.plist 2>/dev/null || cat Info.plist) <(plutil -convert xml1 -o - AirportItlwm-Sonoma-Info.plist 2>/dev/null || cat AirportItlwm-Sonoma-Info.plist) | head -60; echo "=== SONOMA plist ==="; cat AirportItlwm-Sonoma-Info.plist | sed -n \'1,60p\''}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/itlwm/AirportItlwm && grep -n "IO80211\\|class AirportItlwm" AirportItlwm.hpp | head -60'}

> **[reasoning]**
> Excellent — this is the key D finding:
> 
> **The `NetworkController` personality with `IOMatchCategory = WiFiDriver`, `IONetworkRootType = airport`, `IOProbeScore = 70000`** is what makes the interface appear in the Wi-Fi menu. This is the "airport" network root type that CoreWLAN/CoreWiFi recognizes.
> 
> Let me confirm what `IONetworkRootType = airport` does. In IONetworkFamily, `IONetworkRootType` in the personality dictionary sets the `kIONetworkRootType` property on the matched service. CoreWLAN scans for network controllers with `IONetworkRootType` == "airport" (or the Apple wireless drivers have a specific property). Hmm.
> 
> Actually, more likely: the `IOMatchCategory = WiFiDriver` + `IONetworkRootType = airport` is what the itlwm project uses to get its interface recognized as an airport device by the macOS Wi-Fi stack. Let me verify by looking at itlwm's git history / issues.
> 
> Let me search the web for confirmation of this mechanism and for "IONetworkRootType airport" + IO80211.
> 
> Let me also check the `AirportItlwm.cpp` for `attachToController` and the "IO80211Family" `IO80211BundleLoader`.
> 
> Let me look at the itlwm `AirportItlwm.cpp` start() to see the full flow, and also grep for "IONetworkRootType" across the project.
> 
> Let me also do web searches on:
> - "IONetworkRootType airport" IO80211 third party driver
> - IO80211FamilyLegacy vs IO80211Family macOS 13
> - IO80211BundleLoader
> 
> Let me batch.

> **[tool websearch]** {'query': '"IONetworkRootType" airport IO80211 third-party driver macOS Wi-Fi menu CoreWLAN'}

> **[tool websearch]** {'query': 'IO80211FamilyLegacy vs IO80211Family macOS 13 third party driver bundle OSBundleLibraries'}

> **[reasoning]**
> Very good D material. Key points:
> - For macOS 13+ (Ventura/Sonoma/Sequoia), third-party drivers need `IO80211FamilyLegacy.kext` (V1200.12.2b1) + `IOSkywalkFamily.kext` (V1.0) + `corecapture` (for Apple80211Helpers) injected via OpenCore.
> - OCLP provides these as payload kexts: `dortania/OpenCore-Legacy-Patcher/payloads/Kexts/Wifi`.
> - For macOS Sequoia 15, itlwm says use the Ventura AirportItlwm.
> 
> The project runs macOS 15.8.1 Darwin 24.6.0. So they need IO80211FamilyLegacy + IOSkywalkFamily.
> 
> Now the question about whether the Wi-Fi menu requires "Apple wireless" entitlement/PCIe: the answer is NO — a USB-based IO80211 interface can appear (that's exactly what AirportItlwm does with a USB Wi-Fi dongle, e.g. Realtek 8812AU/8814AU USB dongles are supported by itlwm). Actually wait — itlwm supports USB dongles? The itlwm project's supported hardware includes USB adapters with RTL8812AU. Let me verify.
> 
> Yes — itlwm supports: "Intel 7260/8260/8265/AX200", "Broadcom BCM4360 (PCIe)", "Realtek RTL8812AU/8814AU (USB)". Let me confirm.
> 
> Hmm, and itlwm's `AirportItlwm` uses `IOPCIEDeviceWrapper` — so the personality matches `IOPCIDevice` and wraps it. For USB, itlwm has `itlwm` kext (the IOKit part) which uses `IOUSBHostInterface`? Let me check the itlwm `itlwm/Info.plist`.
> 
> Let me look at that — it will show how a USB device is matched in itlwm.
> 
> Let me also check the `itl80211` kext (the net80211 → IO80211 glue) Info.plist — that's the "IO80211Family" glue.
> 
> Let me batch.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/itlwm && echo "=== itlwm/Info.plist (USB) ===" && cat itlwm/Info.plist && echo "=== itl80211/Info.plist ===" && cat itl80211/Info.plist'}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/itlwm && ls itlwm itl80211 && echo "=== itl80211 hpp ===" && ls itl80211/*.hpp 2>/dev/null && grep -rn "class .*IO80211" itl80211/*.hpp itl80211/*.cpp 2>/dev/null | head -20'}

> **[reasoning]**
> Good. Now let me look at the itlwm's `AirportItlwm.cpp` `start()` method to see the complete IO80211Controller lifecycle, especially:
> - `attachInterface`
> - `createInterface`
> - `apple80211_ioctl`
> - `setLinkStatus`
> - The `IO80211Interface` subclass.
> 
> And look at `AirportItlwmInterface.cpp` (the IO80211Interface subclass).
> 
> Also let me look at `IOPCIEDeviceWrapper.cpp` — the wrapper that provides a fake IOPCIDevice for non-PCI buses (USB). That's a VERY relevant pattern: for a USB Wi-Fi dongle, itlwm wraps the USB device in an `IOPCIDeviceWrapper` so the IO80211 personality matches `IOPCIEDeviceWrapper`.
> 
> Wait, actually the itlwm `itlwm` kext matches `IOPCIDevice` with `IOPCIPrimaryMatch` 0x00008086 — that's the Intel Wi-Fi over PCIe (CNVi) device. And the AirportItlwm personality matches `IOPCIEDeviceWrapper` with `IOResourceMatch=IOBSD` and `IONetworkRootType=airport`.
> 
> For USB dongles with itlwm: there's a separate project "itlwm" for USB? Actually, itlwm supports Realtek RTL8812AU USB dongles via the `itlwm` kext matching `IOUSBHostDevice`? Hmm, let me check the itlwm README for supported hardware.
> 
> Let me look at AirportItlwm.cpp start() and the README supported devices.
> 
> Let me also check the itlwm repo README for USB support.
> 
> Let me batch.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/itlwm && grep -n "USB\\|8812AU\\|8814AU\\|rtl88" README.md | head -30; echo "=== README head ==="; sed -n \'1,60p\' README.md'}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/itlwm/AirportItlwm && grep -n "attachInterface\\|createInterface\\|setLinkStatus\\|registerService\\|createWorkLoop\\|::start\\|::init\\|getHardwareAddress\\|configureInterface\\|createMediumTables\\|setCurrentMedium" AirportItlwm.cpp | head -40'}

> **[reasoning]**
> Now I have the classic pattern from itlwm's AirportItlwm.cpp:
> - `init()` 
> - `createInterface()` (line 128) — creates the IO80211Interface subclass
> - `createMediumTables()` (314)
> - `start()` (339): `super::start()` → `createMediumTables` → `setCurrentMedium`/`setSelectedMedium` → `attachInterface(&fNetIf, true)` → `setLinkStatus(kIONetworkLinkValid)` → `registerService()` → `fNetIf->registerService()`
> - `getHardwareAddress()` (650)
> - `getHardwareAddressForInterface()` (672)
> - `configureInterface()` (103)
> 
> Let me read the key sections: createInterface (128-180), start (339-440), createMediumTables (314-340), getHardwareAddress (650-680), and the `AirportItlwmInterface` subclass.
> 
> Let me read them.
> 
> Also, I should check the itlwm docs site: openintelwireless.github.io/itlwm — for D documentation.
> 
> And I want to verify the "USB Wi-Fi dongle appears in Wi-Fi menu" question — itlwm has a separate project for Realtek USB: "itlwm" only supports Intel. But there IS the "RTL8188E USB" case... Hmm.
> 
> Actually the key question: does a USB-based IO80211 interface appear in the macOS Wi-Fi menu? The answer is YES — this is what the "USB Wi-Fi adapter native IO80211" goal is. Examples:
> - Realtek RTL8812AU USB dongles with "AirportItlwm" — hmm, itlwm doesn't support Realtek.
> - But "Mieze" has macOS drivers for Realtek USB.
> - There's also the known project "Realtek RTL8812AU USB macOS driver" by "ElliottChip"? 
> - "USB-C" adapters like the "Realtek RTL8822BU" work with AirPortItlwm? Hmm.
> 
> Let me search for the specific question: does a USB IO80211 interface appear in the Wi-Fi menu bar on macOS?
> 
> Actually, AirPort-RTW's `RTW88USBDevice.cpp` shows they built a USB path (as an IOEthernetController though, and README says USB not supported).
> 
> Key insight to verify: the macOS Wi-Fi menu (CoreWLAN/CoreWiFi) enumerates **IO80211Interface** instances. The IO80211Family/IO80211FamilyLegacy "family" driver attaches to IO80211Controller and creates the interface. The bus (PCIe/USB) doesn't matter for the menu. The "Apple wireless" split mentioned in the brief is about `AppleBCMWLANIO80211Interface` (the Apple internal one) vs third-party `IO80211Interface` — the latter works fine.
> 
> Let me verify with a search and also look at the itlwm FAQ/docs.
> 
> But actually, more valuable: let me check the project's own docs for D (m3-m4-integration.md) to know what's already planned, then focus on filling gaps.
> 
> Let me batch: read itlwm key functions + project m3-m4 doc.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/itlwm/AirportItlwm && sed -n \'100,180p\' AirportItlwm.cpp && echo "..... START ....." && sed -n \'339,440p\' AirportItlwm.cpp'}

> **[tool shell]** {'command': "cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport && sed -n '1,120p' docs/m3-m4-integration.md"}

> **[reasoning]**
> The project has a detailed plan. My job is to add NEW findings. Let me now consolidate and verify the key EFUSE issue, then do the remaining research areas.
> 
> Key things to still verify/do:
> 1. **EFUSE polarity** — I need stronger corroboration. Let me look at the Zircon OS copy of rtl8188eu (Google-hosted) or other independent drivers. Let me also look at `hal/odm_RTL8188E.c` and `hal/rtl8188e_phycfg.c` for `Hal_EfuseParseXtal_8188E` equivalent in Linux, and `Hal8188EPhyCfg.h` for the efuse-related structures.
> 
> Actually — big one: the Linux driver has `Hal_EfuseParseXtal_8188E`? Let me grep. The project mentioned `Hal_EfuseParseXtal_8188E` in the vendor binary. In Linux, look for `rtw_efuse_map_read` + `hal/rtl8188e_phycfg.c` `hal_phy_init`. Let me grep for "CrystalCap" and "ParseXtal".
> 
> 2. The **`Hal8188EPhyCfg.h`** may have the efuse "map" (the `EFUSE_Map` for 8188E) with section names, which would let us find MAC/xtal in the logical map.
> 
> 3. The **H2C / firmware** question: the Linux driver uses the `_WriteFW` + `_FWFreeToGo` sequence I found (not H2C packets). But the vendor's `FW_FirmwareDownload` uses H2C commands. The brief asks about H2C. Let me look at `hal/rtl8188e_cmd.c` for the H2C command structure (`H2C_CMD`, `H2C_Header`).
> 
> 4. Topic E: USB TX/RX descriptors for 8188E — `hal/rtl8188e_xmit.c` (tx desc), `hal/rtl8188e_rxdesc.c` (rx desc), `include/rtl8188e_xmit.h` (usb tx desc struct).
> 
> Let me batch several greps.
> 
> Let me also check `include/rtl8188e_xmit.h` for `txdesc_usb` size.
> 
> Let me do these.

Let me now verify the EFUSE polarity with independent sources and dig into the H2C/TX/RX descriptor formats.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && echo "=== ParseXtal / CrystalCap ===" && grep -rn "ParseXtal\\|CrystalCap\\|hal_phy_init\\|EFUSE_Map\\|eeprom_eeprom_data\\[" --include="*.c" --include="*.h" . | head -25; echo; echo "=== USB TX desc struct ===" && grep -n "txdesc_usb\\|struct txdesc\\|TX_DESC_SIZE\\|TXDESC_SIZE" include/rtl8188e_xmit.h include/rtl8188e_spec.h include/rtl8188e_hal.h | head -20'}

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && echo "=== H2C command structs ===" && grep -n "H2C_Header\\|H2C_CMD\\|H2C_BOX_PARAM\\|h2c" include/hal_com.h include/rtl8188e_cmd.h 2>/dev/null | head -40; echo "=== h2clbk ==="; cat include/h2clbk.h 2>/dev/null | head -60'}

> **[reasoning]**
> Excellent! `Hal_EfuseParseXtal_8188E` at rtl8188e_hal_init.c:2236 — let me read it. It confirms:
> - `pHalData->CrystalCap = hwinfo[EEPROM_XTAL_88E]` (= hwinfo[0xB9] = 185)
> - If 0xFF → `EEPROM_Default_CrystalCap_88E` = 0x20
> - `PHY_SetBBReg(Adapter, REG_AFE_XTAL_CTRL, 0x7ff800, (CrystalCap & 0x3F) | ((CrystalCap & 0x3F) << 6))` — i.e. 0x24[16:11] = 0x24[22:17] = cap.
> 
> This matches the vendor's `Hal_EfuseParseXtal_8188E` exactly (rom[0xB9] = xtal).
> 
> Also `hal/usb_halinit.c:1203` calls `Hal_EfuseParseXtal_8188E(adapt, eeprom->efuse_eeprom_data, ...)` — that's the USB HAL init. This is the exact 8188E USB init sequence file! `hal/usb_halinit.c` (2334 lines). Let me read that — it's THE reference for the 8188E USB HAL init.
> 
> Let me read usb_halinit.c around the init function.
> 
> Also let me look at `hal/rtl8188e_xmit.h` for the tx desc struct.
> 
> Let me batch.

`usb_halinit.c` is the exact 8188E USB init reference. Let me read it.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && grep -n "^[a-zA-Z_].*(\\|^static.*(" hal/usb_halinit.c | grep -v ";" | head -40; echo "=== Hal_EfuseParseXtal_8188E ==="; sed -n \'2230,2260p\' hal/rtl8188e_hal_init.c'}

> **[tool shell]** {'command': "cd /private/tmp/opencode/src/rtl8188eu && sed -n '1100,1330p' hal/usb_halinit.c"}

> **[reasoning]**
> PERFECT. `Hal_EfuseParseMACAddr_8188EU` confirms:
> - `memcpy(eeprom->mac_addr, &hwinfo[EEPROM_MAC_ADDR_88EU], ETH_ALEN);` where `EEPROM_MAC_ADDR_88EU = 0xD7 = 215`. ✓ Matches the project's `rom + 215`.
> 
> And `readAdapterInfo_8188EU` gives the complete efuse parse sequence.
> 
> Also `_ReadPROMContent` reads `REG_9346CR` to check boot source: `BOOT_FROM_EEPROM` / `EEPROM_EN` bit. Let me get `REG_9346CR` value and the bit definitions. This is a **critical diagnostic**: if the chip boots from EFUSE and autoload succeeds, the efuse is valid.
> 
> Let me get REG_9346CR.
> 
> Now let me read `rtl8188eu_hal_init` (line 699) — the master HAL init for the 8188E USB. That's the "step 42" equivalent in Linux! This is very valuable for topic A(2).
> 
> Let me read it.
> 
> Also `Hal_InitPGData88E` — that's the efuse read! Let me find it.
> 
> Let me batch.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && grep -rn "REG_9346CR\\|BOOT_FROM_EEPROM\\|define EEPROM_EN\\|Hal_InitPGData88E" --include="*.c" --include="*.h" . | head -10; echo "=== Hal_InitPGData88E body ==="; grep -n "Hal_InitPGData88E" -A 30 hal/rtl8188e_hal_init.c | head -45'}

> **[tool shell]** {'command': "cd /private/tmp/opencode/src/rtl8188eu && sed -n '699,860p' hal/usb_halinit.c"}

> **[reasoning]**
> This is the complete Linux 8188E USB HAL init sequence. Now I have a very precise "step 42"-equivalent for topic A(2).
> 
> Let me get the remaining part of `rtl8188eu_hal_init` (lines 860-975) and `rtl8188eu_InitPowerOn` (105-135).
> 
> Let me also collect the key constants: TX_PAGE_BOUNDARY_88E, WMM_NORMAL_TX_PAGE_BOUNDARY_88E.
> 
> Let me batch.
> 
> Then I want to:
> 1. Verify the EFUSE polarity issue with a third source. Let me try the Zircon copy of rtl8188eu via googlesource (might be accessible), or find another driver. Actually, let me look at the vendor's `Efuse_OneByteRead` in a *different* Realtek driver that has 8188E support, e.g. the "rtl8188eu" in the `rtlwifi` (lwfinger/rtlwifi) — wait, that's PCI only.
> 
> Better: Let me look at how the *vendor* driver for 8188E does the read — we have the vendor binary in the project (backed up?). The project has `backup/` with 59 entries. Let me check if RtWlanU.kext is there, and whether they have Ghidra output. I could check the disassembly myself with `otool`/`nm`... that's heavy.
> 
> Actually, I can check the project's `docs/vendor-reverse.md` §... let me search for the 0x033 poll in the doc.
> 
> Actually, the project already has a `tools/` directory with a probe. Let me check `tools/rtwn_probe.c` to see what the probe does and if there's a raw register dump. And `logs/` might have a dump of 0x030/0x031/0x032/0x033 from the actual chip! That would let me determine the polarity empirically. Let me look at the logs.
> 
> That's high value: if there's a log showing 0x033 values, I can determine whether bit7 is set after a read.
> 
> Let me check logs/.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport && ls -la logs/ && echo "=== find efuse logs ===" && grep -rln "0x033\\|efuse" logs/ 2>/dev/null | head'}

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && sed -n \'105,135p\' hal/usb_halinit.c; echo "=== rest of hal_init ==="; sed -n \'860,975p\' hal/usb_halinit.c'}

> **[reasoning]**
> I now have the complete Linux 8188E USB HAL init. Let me check the logs for efuse-related output.
> 
> Let me look at the watch logs.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport && cat logs/watch-20261022-041309.log'}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport && ls tools/ && grep -n "0x033\\|0x032\\|0x031\\|efuse" tools/rtwn_probe.c 2>/dev/null | head -30'}

> **[reasoning]**
> Critical evidence from the log:
> - `efuse-direct` → **efuse-direct-gagal** (FAILED) — consistent with the inverted ready-bit poll causing a timeout... actually no, the inverted poll would exit IMMEDIATELY (bit7 = 0 after clearing) and return 0xFF data, not fail. Hmm, the log says "efuse-direct-gagal" — so it returned -1 (timeout). That means bit7 stayed SET for 100 iterations. Interesting! That means the hardware does NOT clear bit7 when we write 0x033 = v & 0x7F — i.e., bit7 is not writable, OR the readback of 0x033 is stuck.
> 
> Wait — if the write of `v & 0x7F` to 0x033 didn't actually clear bit 7 (because bit 7 might be read-only "ready" flag), then bit7 stays 1 and the project polls for 100×1ms and times out → "efuse-direct-gagal". Then the offload path returns "ok" but with MAC = ff:ff:ff:ff:ff:ff and xtal = 0xff — i.e., the offload read produced all-0xFF (empty) data, and the parser mapped to ff:ff:ff:ff:ff:ff.
> 
> Hmm, interesting. So BOTH paths fail. That's very useful diagnostic info.
> 
> Now, key question: is the direct path failing because (a) the polarity is inverted, or (b) the address registers are wrong, or (c) the EFUSE power switch (0x00CF / 0x69) is missing?
> 
> The lwfinger `efuse_OneByteRead` does NOT do the power switch either (it's called from `rtw_efuse_access` which does `Efuse_PowerSwitch(padapter, write, true)` first). And `hal_EfusePowerSwitch_RTL8188E` writes **REG_EFUSE_ACCESS (0x00CF) = 0x69**, plus REG_SYS_ISO_CTRL (0x0000) PWC_EV12V (BIT15), REG_SYS_FUNC_EN (0x0002) FEN_ELDR (BIT12), REG_SYS_CLKR (0x0008) LOADER_CLK_EN (BIT5) | ANA8M (BIT1).
> 
> The project writes 0x69 to **0x106** — the wrong register! (0x106 is REG_PKT_BUFF_ACCESS_CTRL used by the offload path with TXPKT_BUF_SELECT=0x69.) So the direct path is missing the EFUSE power switch entirely, which likely makes 0x033 never assert ready → timeout. **That explains "efuse-direct-gagal" perfectly.**
> 
> So the fix list for B:
> 1. Use **0x00CF** (REG_EFUSE_ACCESS) = 0x69 for the direct-read EFUSE power switch, plus the ISO/FUNC/CLK enable bits. (0x106 is the offload packet-buffer select.)
> 2. Poll 0x033 bit7 for **SET** (ready), not CLEAR.
> 3. Write 0x033 = 0x72 (fixed) or RMW preserving bits 0-6.
> 4. Optionally add a 50 µs delay after ready before reading 0x030 (lwfinger's `rtw_udelay_os(50)` comment: "there shall be some delay after ready bit is set, or the result will always stay on last data we read").
> 
> That 4th point is GOLD: "Designer says that there shall be some delay after ready bit is set, or the result will always stay on last data we read." — exactly the "stale data" symptom.
> 
> Now for the offload path returning all-0xFF: the vendor's offload sequence (per the project doc) is:
> ```
> write8(0x209, mode)            mode = 0xaa → base = mode << 4 (= 0xAA0)
> write8(0x0F0, v|0x80)
> reset 8051 (0x093/0x003)
> write8(0x088, v|0x02)         trigger
> poll 0x088 sampai bit1 hilang
> write8(0x106, 0x69)
> write16(0x140, base)
> write8(0x143, 0); poll bit0
> read32(0x144) = hdr, read32(0x148) = data
> ```
> The offload path requires the 8051 firmware to be ALREADY uploaded (it runs the efuse-read routine in the 8051). In the project's flow, the offload read happens BEFORE firmware upload! Look at the log: `power-on-ok > efuse-direct > efuse-direct-gagal > efuse-offload > efuse-offload-ok > ok > ff:ff:ff:ff:ff:ff > 0xff > dma-init > firmware`. So the offload EFUSE read runs before the firmware is uploaded → the 8051 has no code to service the request → returns nothing/0xFF.
> 
> **The CONTINUE.md even hints at this**: "Sisa M1: MAC/xtal dari EFUSE masih ff:ff:ff:ff:ff:ff / 0xff ( hopes: urutan baru 'firmware → EFUSE' akan memperbaikinya)." — the project already suspects the ordering. But it's not the *only* problem: the direct path also has the wrong register + inverted polarity.
> 
> Now, also important: the Linux driver reads EFUSE **before** firmware download? Let's check: In `rtl8188eu_hal_init`, `rtl8188e_FirmwareDownload` is called, then PHY_MACConfig, BB, RF, then `rtl8188e_iol_efuse_patch`. But `_ReadPROMContent` (which reads the efuse) is called from `ReadAdapterInfo8188EU` — which happens in `rtw_ops` before hal_init? Let me check the call order in the Linux driver: `rtw_ops_init` → ... Actually `ReadAdapterInfo8188EU` is called from `rtl8188eu_ops`? Let me grep.
> 
> Actually in the Linux driver, `ReadAdapterInfo8188EU` is called during probe (before hal_init), and it uses the **direct** efuse read path (`Hal_EfuseReadEFuse88E` via `rtl8188e_ReadEFuse`). And the efuse power switch is invoked via `EFUSE_ShadowMapUpdate` → `Efuse_ReadAllMap` → `Efuse_PowerSwitch(pAdapter, false, true)` → `hal_EfusePowerSwitch_RTL8188E` (writes 0x00CF = 0x69 etc.).
> 
> So YES — the direct read in Linux works WITHOUT firmware (the 8188E has a hardware EFUSE controller). And the Linux driver reads EFUSE **before** firmware download. Good.
> 
> Let me verify the Linux call order: grep for ReadAdapterInfo8188EU callers.
> 
> Let me also verify: is there a "usb_halinit" wrapper that calls ReadAdapterInfo8188EU? Let me grep.
> 
> Let me also check the 8188E's `Efuse_PgPacketRead_8188e` (offset 1251) and `hal_EfuseGetCurrentSize_8188e` (1185) — the latter gives the "current size" which is how the driver knows how much efuse data exists.
> 
> Let me batch these greps.
> 
> Also: I should check `hal_EfuseGetCurrentSize_8188e` to see how it determines the used size — this tells us the physical map length.
> 
> Let me run.

Critical: the log shows `efuse-direct-gagal` then offload reads all-0xFF. Let me confirm the Linux call ordering and power-switch requirements.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && echo "=== who calls ReadAdapterInfo8188EU ===" && grep -rn "ReadAdapterInfo8188EU\\|rtl8188eu_hal_init\\|rtl8188eu_InitPowerOn" --include="*.c" . | head -20; echo; echo "=== hal_EfuseGetCurrentSize_8188e ==="; sed -n \'1185,1250p\' hal/rtl8188e_hal_init.c'}

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && echo "=== hal_EfusePgPacketRead_8188e ===" && sed -n \'1251,1340p\' hal/rtl8188e_hal_init.c'}

> **[reasoning]**
> Note: `hal_EfusePgPacketRead_8188e` uses `EXT_HEADER(efuse_data)` and `ALL_WORDS_DISABLED` macros. Let me get them from rtl8188e_hal.h.
> 
> Now let me also check the `RTW8188E` "H2C" mechanism: `include/rtl8188e_cmd.h` enum RTL8188E_H2C_CMD_ID. And `hal/rtl8188e_cmd.c` for the H2C command structures.
> 
> And I need topic E: USB TX/RX descriptors. Let me look at `include/rtl8188e_xmit.h` for `struct txdesc_88e` and the USB variants, plus `hal/rtl8188e_rxdesc.c` for rx desc.
> 
> Let me also check OpenBSD's `r92c_tx_desc_usb` / `r92c_rx_desc_usb` in the local if_urtwn.c.
> 
> Let me batch: H2C enum + xmit header + openbsd usb desc.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && echo "=== EXT_HEADER / ALL_WORDS_DISABLED ===" && grep -rn "define EXT_HEADER\\|define ALL_WORDS_DISABLED\\|define PG_STATE\\|define PGPKT_DATA_SIZE\\|define HW_VAR_EFUSE_BYTES" --include="*.h" . ; echo; echo "=== H2C cmd ids ===" && sed -n \'20,60p\' include/rtl8188e_cmd.h'}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/openbsd/sys/dev/usb && grep -n "r92c_tx_desc_usb\\|r92c_rx_desc_usb\\|struct r92c_tx_desc\\|struct r92c_rx_desc\\|TX_DESC_SIZE\\|RX_DESC_SIZE" if_urtwn.c | head -20; echo "=== ic/r92creg.h desc ==="; grep -n "tx_desc_usb\\|rx_desc_usb" ../ic/r92creg.h | head -20'}

> **[reasoning]**
> Let me read the OpenBSD USB TX/RX descriptor structures (r92creg.h:1545-1650) and compare with the Linux 8188E USB ones.
> 
> Let me also look at the Linux 8188E tx desc structure.
> 
> Let me batch.

> **[tool shell]** {'command': "cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/openbsd/sys/dev/ic && sed -n '1540,1640p' r92creg.h"}

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && grep -n "struct txdesc_88e\\|struct txdesc_88e_txdesc\\|txdesc_usb\\|USB_TX_DESC_SIZE\\|struct rxdesc_88e" include/rtl8188e_xmit.h include/rtl8188e_recv.h include/rtl8188e_spec.h 2>/dev/null | head -20; echo "=== txdesc_88e struct ==="; sed -n \'/^struct txdesc_88e {/,/^};/p\' include/rtl8188e_xmit.h | head -60'}

> **[reasoning]**
> The Linux 8188E USB TX descriptor: let me look in `include/rtl8188e_xmit.h` for the actual struct definition. Let me search for "txdesc" more broadly.
> 
> Also note: OpenBSD's `r92c_tx_desc_usb` is 32 bytes (4+4+4+2+2+4+4+4+2+2 = 32). ✓ matches the brief's "32 bytes".
> `r92c_rx_desc_usb` is 24 bytes (6 × uint32). ✓
> 
> Let me find the Linux 8188E tx desc.
> 
> And let me now also look at the rtl8188e_xmit.h for USB-related TX.
> 
> Then I'll move to the remaining topics: A (FreeBSD urtwn port, macOS drivers), D (deeper), E (OpenBSD urtwn scan/join).
> 
> Let me batch: find Linux txdesc + check FreeBSD urtwn via webfetch.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && grep -n "txdesc" include/rtl8188e_xmit.h | head -30; echo "=== struct txdesc ==="; sed -n \'/txdesc_88e/,/} txdesc_88e/p\' include/rtl8188e_xmit.h | head -80'}

> **[tool webfetch]** {'format': 'text', 'timeout': 90, 'url': 'https://github.com/freebsd/freebsd-src/blob/main/sys/net/if_urtwn.c'}

> **[reasoning]**
> FreeBSD's urtwn is at `sys/net/if_urtwn.c`? Let me check. FreeBSD has `sys/net/if_urtwn.c` — hmm, 404 means the file isn't at that path in freebsd-src. FreeBSD's urtwn is at `sys/net/if_urtwn.c`. Let me check the actual path. Maybe it's `sys/net/if_urtwn.c` doesn't exist — it could be `sys/net/if_urtwn.c` in the release branch. Let me search.
> 
> Let me use the GitHub API to search the freebsd-src tree, or just try the `master` branch.
> 
> Actually FreeBSD's main branch is `main`. The file might be `sys/net/if_urtwn.c`. Let me use the GitHub API to list.
> 
> Let me try: https://api.github.com/repos/freebsd/freebsd-src/contents/sys/net — but that returns a huge list. Let me use the git trees API with recursive... too big.
> 
> Alternative: use the GitHub code search UI? Or just try a few paths.
> 
> Let me try websearch for "freebsd if_urtwn.c" and check.
> 
> Also, let me find the Linux 8188E USB TX descriptor struct: it's probably in `include/rtl8188e_xmit.h` — search for "tx_desc" struct definitions. Let me grep for "struct tx_desc" across headers.
> 
> Let me batch.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && grep -rn "struct tx_desc\\b" --include="*.h" . | head; echo "---"; grep -rn "TX_DESC_SIZE\\|TXDESC_SIZE\\|USB_TX_DESC" --include="*.h" --include="*.c" . | head -20'}

> **[tool websearch]** {'query': 'FreeBSD if_urtwn.c rtl8188eu 88e support sys/net urtwn driver'}

> **[reasoning]**
> Excellent! **FreeBSD has `sys/dev/rtwn/rtl8188e/usb/r88eu_init.c`** — a full port of the 8188E USB support into FreeBSD's rtwn driver! This is a major finding for topic A. Let me fetch that file and the surrounding directory.
> 
> Let me get the FreeBSD rtwn rtl8188e directory listing and the r88eu_init.c content.
> 
> Since raw.githubusercontent is blocked, I'll use webfetch on the github blob URL (which worked). Let me fetch r88eu_init.c.
> 
> Also let me list the directory: https://github.com/freebsd/freebsd-src/tree/main/sys/dev/rtwn/rtl8188e/usb
> 
> Let me do both in parallel.
> 
> Also the Linux 8188E USB TX descriptor: TXDESC_SIZE — let me find its value. It's probably 32. Let me grep in rtw_xmit.h.
> 
> Let me batch.

Major find: FreeBSD has a dedicated RTL8188E USB port. Let me pull it.

> **[tool webfetch]** {'format': 'text', 'timeout': 90, 'url': 'https://github.com/freebsd/freebsd-src/blob/main/sys/dev/rtwn/rtl8188e/usb/r88eu_init.c'}

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/rtl8188eu && grep -rn "define TXDESC_SIZE\\|define OFFSET_SZ\\|define PACKET_OFFSET_SZ\\|define TXDESC_OFFSET" --include="*.h" . ; echo "=== rtw_xmit.h tx_desc ==="; sed -n \'90,120p\' include/rtw_xmit.h'}

> **[reasoning]**
> Excellent! FreeBSD's `sys/dev/rtwn/rtl8188e/usb/` is a full port. Files: `r88eu.h`, `r88eu_reg.h`, `r88eu_init.c`, and likely `r88eu_usb.c`, `r88eu_var.c`, etc. This is a **much better reference than OpenBSD's urtwn** for the 8188E specifically, because it has 8188E-specific init (r88eu_power_on, r88eu_init_bb, r88eu_init_intr, r88eu_init_rx_agg, r88eu_post_init) AND the FreeBSD `rtwn` driver has a proper `rtwn` (net80211) integration.
> 
> Also critical: **FreeBSD's `r88e_init_bb_common(sc)`** — that's the shared 88E BB programming (from `sys/dev/rtwn/rtl8188e/`).
> 
> Also `r88e_fw_reset(sc, RTWN_FW_RESET_SHUTDOWN)` and `R92C_MCUFWDL` / `R92C_MCUFWDL_RDY` — the 92C-style MCUFWDL register for the 88E in OpenBSD/FreeBSD. Hmm! So OpenBSD/FreeBSD use 0x080 for MCUFWDL on 88E, same as Linux. Good.
> 
> Let me get the FreeBSD rtl8188e directory listing to enumerate files. Let me use the GitHub API (api.github.com) — is it reachable? Let me test.
> 
> Also `r88eu_reg.h` would have the 8188E-specific registers. And there's likely `r88eu_usb.c` with the USB descriptors and `r88eu_var.h`.
> 
> Let me try the GitHub API for the directory listing.
> 
> Also, I should now do topic D more: I need to find:
> 1. Whether a USB-based IO80211 interface appears in the Wi-Fi menu (evidence).
> 2. The `IO80211BundleLoader` mention.
> 3. "IO80211SupportedFeatures".
> 
> Let me search for those.
> 
> Let me batch: GitHub API dir listing + websearch for IO80211BundleLoader.
> 
> Actually — note the brief mentions "the IO80211BundleLoader". Let me search for that specifically. Also there might be relevant knowledge: in the old IO80211Family, the third-party driver needs to be loaded by `IO80211Family`'s "IO80211BundleLoader" which scans `/System/Library/Extensions` and third-party kext directories for IO80211Controller subclasses.
> 
> Let me search.

> **[tool shell]** {'command': 'cd /private/tmp/opencode && curl -sS --max-time 30 "https://api.github.com/repos/freebsd/freebsd-src/contents/sys/dev/rtwn/rtl8188e?ref=main" | python3 -c "import json,sys; d=json.load(sys.stdin); [print(x[\'type\'], x[\'name\'], x.get(\'size\')) for x in d]" 2>&1 | head -30; echo "=== usb subdir ==="; curl -sS --max-time 30 "https://api.github.com/repos/freebsd/freebsd-src/contents/sys/dev/rtwn/rtl8188e/usb?ref=main" | python3 -c "import json,sys; d=json.load(sys.stdin); [print(x[\

> **[tool websearch]** {'query': '"IO80211BundleLoader" OR "IO80211Family" third-party driver bundle load mechanism kext macOS'}

> **[reasoning]**
> Let me now get the FreeBSD 8188E files via the API (raw content is available via api.github.com content endpoint, which returns base64). Let me fetch:
> - `sys/dev/rtwn/rtl8188e/r88e_rom.c` (the ROM/efuse definitions!)
> - `sys/dev/rtwn/rtl8188e/r88e_rom_defs.h`
> - `sys/dev/rtwn/rtl8188e/r88e_fw.c` (firmware download)
> - `sys/dev/rtwn/rtl8188e/r88e_rx_desc.h`
> - `sys/dev/rtwn/rtl8188e/r88e_tx_desc.h`
> - `sys/dev/rtwn/rtl8188e/usb/r88eu_attach.c`
> - `sys/dev/rtwn/rtl8188e/usb/r88eu_reg.h`
> 
> This is a goldmine. Let me write a small script that fetches via the API and decodes base64, saving to /private/tmp/opencode/src/freebsd-r88e/.
> 
> Let me do that.
> 
> Also I still need to verify the "USB IO80211 appears in Wi-Fi menu" question. Let me look for a specific known example: the "Mieze" Realtek macOS drivers, or "OSX RTL8188E". Let me search for a macOS RTL8188E kext specifically.
> 
> Let me batch.

> **[tool shell]** {'command': 'mkdir -p /private/tmp/opencode/src/freebsd-r88e && cd /private/tmp/opencode/src/freebsd-r88e && for p in "sys/dev/rtwn/rtl8188e/r88e.h" "sys/dev/rtwn/rtl8188e/r88e_rom.c" "sys/dev/rtwn/rtl8188e/r88e_rom_defs.h" "sys/dev/rtwn/rtl8188e/r88e_fw.c" "sys/dev/rtwn/rtl8188e/r88e_fw_cmd.h" "sys/dev/rtwn/rtl8188e/r88e_rx_desc.h" "sys/dev/rtwn/rtl8188e/r88e_tx_desc.h" "sys/dev/rtwn/rtl8188e/r88e_init.c" "sys/dev/rtwn/rtl8188e/r88e_calib.c" "sys/dev/rtwn/rtl8188e/usb/r88eu.h" "sys/dev/rtwn/rtl

> **[tool websearch]** {'query': 'macOS RTL8188E USB Wi-Fi kext IO80211 native Airport menu third-party driver github'}

> **[reasoning]**
> Good. Now let me read the FreeBSD r88e files — the ROM definitions (efuse/ROM layout) are the most valuable.
> 
> Let me read r88e_rom.c, r88e_rom_defs.h, r88e_fw.c, r88e_rx_desc.h, r88e_tx_desc.h, r88eu_attach.c.
> 
> Note: `r88e_rom.c` — this is FreeBSD's "ROM" (efuse logical map) definition for the 88E, which includes MAC address offset and xtal. This directly answers B.
> 
> Let me read them.

Now the FreeBSD 88E ROM/EFUSE definitions — directly relevant to blocker B.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/freebsd-r88e && echo "############ r88e_rom_defs.h ############" && cat r88e_rom_defs.h && echo "############ r88e_rom.c ############" && cat r88e_rom.c'}

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/freebsd-r88e && echo "############ r88e_fw.c ############" && cat r88e_fw.c'}

> **[reasoning]**
> Very useful. FreeBSD's `r88e_fw_download_enable`:
> ```c
> rtwn_setbits_1(sc, R92C_MCUFWDL, 0, R92C_MCUFWDL_EN);      /* enable */
> rtwn_setbits_1_shift(sc, R92C_MCUFWDL, R92C_MCUFWDL_ROM_DLEN, 0, 2);  /* 8051 reset: clear bit 3 */
> ```
> So: MCUFWDL bit0 = EN, bit3 = ROM_DLEN (cleared for reset). Matches Linux: 0x80 |= 0x01, 0x82 &= ~0x08 (0xf7 mask clears bit 3). ✓ Consistent!
> 
> And disable: clear bit0, write 0x81 = 0. ✓ Matches Linux exactly.
> 
> Now, the important thing: `r88e_rom_image.h` has the `struct r88e_rom` with byte offsets. Let me get that. And `r88e.h` for the ROM struct + MAC address.
> 
> Let me fetch r88e_rom_image.h and read r88e.h.
> 
> Also, FreeBSD's approach to the MAC address: `rtwn_r92c_set_rom_opts(sc, buf)` and the MAC comes from `sc->sc_arp`? Actually in FreeBSD's rtwn, the MAC address is set from the USB device descriptor's `iSerialNumber`? No — in FreeBSD rtwn, `rtwn_attach` reads the MAC from the ROM/efuse: `rtwn_r92c_set_rom_opts`.
> 
> Let me get r88e_rom_image.h and r88e.h.
> 
> Also r88e_rx_desc.h and r88e_tx_desc.h for the 8188E-specific USB descriptors — critical for topic E.
> 
> Let me batch.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/freebsd-r88e && for p in "sys/dev/rtwn/rtl8188e/r88e_rom_image.h" "sys/dev/rtwn/rtl8188e/r88e_reg.h" "sys/dev/rtwn/rtl8192c/r92c_rom_defs.h"; do out=$(basename $p); curl -sS --max-time 30 "https://api.github.com/repos/freebsd/freebsd-src/contents/$p?ref=main" | python3 -c "import json,sys,base64; d=json.load(sys.stdin); sys.stdout.write(base64.b64decode(d[\'content\']).decode(\'utf-8\',\'replace\'))" > "$out" 2>/dev/null; printf "%-22s %s\\n" "$out" "$(w

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/freebsd-r88e && echo "############ r88e_tx_desc.h ############" && cat r88e_tx_desc.h && echo "############ r88e_rx_desc.h ############" && cat r88e_rx_desc.h'}

> **[reasoning]**
> CRITICAL FINDING: FreeBSD's `struct r88e_rom` gives the EXACT byte offsets in the 512-byte logical EFUSE map:
> 
> ```
> offset 0x00: reserved1[16]           (0..15)
> offset 0x10: cck_tx_pwr[6]            (16..21)     ← EEPROM_TX_PWR_INX_88E = 0x10 ✓
> offset 0x16: ht40_tx_pwr[5]           (22..26)
> offset 0x1B: tx_pwr_diff              (27)
> offset 0x1C: reserved2[156]           (28..183)
> offset 0xB8: channel_plan             (184)        ← EEPROM_ChannelPlan_88E = 0xB8 ✓
> offset 0xB9: crystalcap               (185)        ← EEPROM_XTAL_88E = 0xB9 ✓
> offset 0xBA: thermal_meter            (186)        ← EEPROM_THERMAL_METER_88E = 0xBA ✓
> offset 0xBB: reserved3[6]             (187..192)
> offset 0xBC: rf_board_opt             (193)        ← EEPROM_RF_BOARD_OPTION_88E = 0xC1?? 
> ```
> 
> Hmm wait. Let me recount. `reserved3[6]` after thermal_meter (0xBA) → 0xBB..0xC0. Then rf_board_opt at 0xC1 ✓ (EEPROM_RF_BOARD_OPTION_88E = 0xC1). rf_feature_opt 0xC2 ✓, rf_bt_opt 0xC3 ✓, version 0xC4 ✓, customer_id 0xC5 ✓, reserved4[3] 0xC6..0xC8, rf_ant_opt 0xC9 ✓ (EEPROM_RF_ANTENNA_OPT_88E = 0xC9), reserved5[6] 0xCA..0xCF.
> 
> Then `diff_d0` union at 0xD0:
> - USB variant: vid(2) @0xD0, pid(2) @0xD2, usb_opt(1) @0xD4, reserved6[2] @0xD5-0xD6, macaddr[6] @0xD7 ✓ (EEPROM_MAC_ADDR_88EU = 0xD7!)
> - PCI variant: macaddr[6] @0xD0, vid @0xD6, pid @0xD8
> 
> So for 8188EU (USB): **MAC address at rom[0xD7..0xDC] = 215..220** ✓✓ — exactly what the project uses (rom+215).
> And VID @0xD0, PID @0xD2, USB_OPT @0xD4.
> 
> For 8188EE (PCIe): MAC @0xD0 (EEPROM_MAC_ADDR_88EE = 0xD0 ✓).
> 
> Then reserved7[2] @0xDD-0xDE, string[33] @0xDF..0xFF ("realtek 802.11n NIC"), reserved8[256].
> 
> Also: `R88E_EFUSE_MAX_LEN 256` (physical content), `R88E_EFUSE_MAP_LEN 512` (logical map) — matches Linux EFUSE_REAL_CONTENT_LEN_88E=256, EFUSE_MAP_LEN_88E=512. ✓
> 
> This is a great confirmation.
> 
> **Note the FreeBSD struct says `crystalcap` at 0xB9 and `R88E_ROM_CRYSTALCAP_DEF 0x20`.** And `rs->crystalcap` is used by `urtwn_bb_init` → `xtal = sc->sc_sc.crystal_cap & 0x3f; reg = RW(reg, R92C_AFE_XTAL_CTRL, R92C_AFE_XTAL_CTRL_ADDR, xtal | xtal << 6)`.
> 
> IMPORTANT: **FreeBSD DOES read the efuse!** `r88e_parse_rom(sc, buf)` is called with the ROM buffer. Where does `buf` come from? FreeBSD's rtwn reads the ROM/efuse for 92C via `rtwn_r92c_parse_rom`? Hmm — actually in FreeBSD, the "ROM" is read from the hardware via `rtwn_read_rom`? Let me check: FreeBSD rtwn has `r92c_rom.c` with `r92c_parse_rom` and the ROM data comes from `rtwn_efuse_read`? Actually I recall FreeBSD's rtwn reads the efuse via `rtwn_read_efuse()` in `if_rtwn_usb.c`? Hmm.
> 
> Actually in FreeBSD rtwn, the 92C ROM is read from the **EEPROM/EFUSE via `rtwn_r92c_rom` / `r92c_efuse`**. Let me check: FreeBSD `sys/dev/rtwn/rtl8192c/r92c_rom.c` has `r92c_parse_rom`, and the ROM buffer is obtained in `if_rtwn.c` `rtwn_attach` via `rtwn_read_rom(sc)`? Hmm, I'm not sure.
> 
> Actually I remember: In FreeBSD rtwn, the "ROM" (EEPROM/EFUSE content) is read from the **USB device descriptor** — no. Let me check `r88e_attach.c` for the USB attach and see.
> 
> Hmm, actually! In FreeBSD's rtwn, for USB devices the ROM is obtained by reading the **EEPROM emulation via vendor requests**? No...
> 
> Wait — I think I remember: FreeBSD's rtwn reads the "ROM" for 92C chips from the efuse using `rtwn_efuse_read` implemented in `sys/dev/rtwn/if_rtwn_usb.c`? Hmm.
> 
> Let me just fetch `r88eu_attach.c` and `r92c_rom.c` / `if_rtwnvar.h` to find out. This is CRUCIAL — because if FreeBSD/OpenBSD never actually read the efuse from hardware and instead used a **hardcoded/assumed** MAC, then the MAC in OpenBSD's urtwn comes from elsewhere.
> 
> Actually, hold on! I recall now: **FreeBSD's rtwn reads the MAC address from the USB device's `iSerialNumber`?** No.
> 
> Let me look: FreeBSD rtwn `if_rtwn.c` → `rtwn_attach()`:
> ```c
> 	/* Read the MAC address from the ROM/EEPROM. */
> ```
> Hmm.
> 
> Actually! I remember clearly now: In FreeBSD's rtwn driver, `rtwn_r92c_parse_rom` is called and the ROM comes from `rtwn_efuse_read`? Let me just check. Let me fetch `r88eu_attach.c` (230 lines) and search the freebsd-src for "parse_rom".
> 
> Let me use the GitHub code search API: https://api.github.com/search/code?q=... requires auth. Alternative: use grep.app? Let me instead fetch the `if_rtwn.c` from freebsd and grep.
> 
> Let me do that. `sys/dev/rtwn/if_rtwn.c` is large but let's fetch it.
> 
> Also fetch `r88eu_attach.c`.
> 
> This is important for understanding where the MAC comes from in the BSD drivers.
> 
> Let me batch.

Big finding: FreeBSD's `struct r88e_rom` gives exact EFUSE map offsets. Let me confirm how BSD gets the ROM.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/freebsd-r88e && curl -sS --max-time 60 "https://api.github.com/repos/freebsd/freebsd-src/contents/sys/dev/rtwn/if_rtwn.c?ref=main" | python3 -c "import json,sys,base64; d=json.load(sys.stdin); sys.stdout.write(base64.b64decode(d[\'content\']).decode(\'utf-8\',\'replace\'))" > if_rtwn.c 2>/dev/null; wc -l if_rtwn.c; echo "=== rom / mac / efuse ==="; grep -n "parse_rom\\|rom\\b\\|efuse\\|ether_addr\\|sc_ar\\|MAC" if_rtwn.c | head -40'}

> **[tool shell]** {'command': "cd /private/tmp/opencode/src/freebsd-r88e && cat r88eu_attach.c | sed -n '1,120p'"}

> **[reasoning]**
> CONFIRMED! FreeBSD's rtwn:
> - `rtwn_read_rom(sc)` reads the ROM (efuse) → `sys/dev/rtwn/if_rtwn_efuse.h` — there IS an efuse read implementation in FreeBSD!
> - `r88eu_set_macaddr`: `IEEE80211_ADDR_COPY(sc->sc_ic.ic_macaddr, rom->diff_d0.usb.macaddr);` — MAC at rom[0xD7] ✓
> 
> So FreeBSD HAS an efuse reader: `sys/dev/rtwn/if_rtwn_efuse.c` / `if_rtwn_efuse.h`. This is CRITICAL for topic B! Let me fetch it — it will show the 92C-style efuse read (0x30) and possibly the 88E-specific one.
> 
> Let me fetch `if_rtwn_efuse.c` and `if_rtwn_efuse.h` and `if_rtwnvar.h`'s `rtwn_read_rom`.
> 
> Let me do that.
> 
> Also `rtwn_read_rom` — where is it defined? Probably in `if_rtwn.c` or `if_rtwn_efuse.c`. Let me grep in if_rtwn.c.
> 
> Let me batch.

FreeBSD has an EFUSE reader. Let me pull it — this is the key B artifact.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/freebsd-r88e && for p in "sys/dev/rtwn/if_rtwn_efuse.c" "sys/dev/rtwn/if_rtwn_efuse.h"; do out=$(basename $p); curl -sS --max-time 30 "https://api.github.com/repos/freebsd/freebsd-src/contents/$p?ref=main" | python3 -c "import json,sys,base64; d=json.load(sys.stdin); sys.stdout.write(base64.b64decode(d[\'content\']).decode(\'utf-8\',\'replace\'))" > "$out" 2>/dev/null; printf "%-22s %s\\n" "$out" "$(wc -l < $out)"; done; echo "=== rtwn_read_rom in if_rtw

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/freebsd-r88e && cat if_rtwn_efuse.c'}

> **[reasoning]**
> PERFECT. FreeBSD's efuse reader is the **92C-style** (0x30 with ADDR in bits 8-17 and VALID bit 31) — `R92C_EFUSE_CTRL`. It also does the **power switch**:
> - `rtwn_write_1(sc, R92C_EFUSE_ACCESS, R92C_EFUSE_ACCESS_ON)`
> - `R92C_SYS_FUNC_EN |= R92C_SYS_FUNC_EN_ELDR`
> - `R92C_SYS_CLKR |= R92C_SYS_CLKR_LOADER_EN | R92C_SYS_CLKR_ANA8M`
> - After: `rtwn_write_1(sc, R92C_EFUSE_ACCESS, R92C_EFUSE_ACCESS_OFF)`
> 
> **But is this the 8188E path?** In FreeBSD, `rtwn_efuse_preread`/`rtwn_efuse_postread` are per-chip hooks (in `if_rtwn_efuse.h` — a header of function pointers? Let's see). And `R92C_EFUSE_ACCESS` = 0x00CF? Let me check `R92C_EFUSE_ACCESS` value in FreeBSD's `r92c_reg.h`.
> 
> Critical: for the 8188E, does FreeBSD use the same 0x30-style efuse read? The 8188E's efuse read in Linux uses 0x31/0x32/0x33 + 0x30 data. If FreeBSD's `R92C_EFUSE_CTRL` is 0x30 and `R92C_EFUSE_ACCESS` is 0x00CF, then FreeBSD's r88eu would use the 92C path — which the project already determined is WRONG for the 8188E.
> 
> Hmm! But FreeBSD's 8188E support reportedly works... Let me check `if_rtwn_efuse.h` and `r92c_reg.h` for R92C_EFUSE_*.
> 
> Actually, wait. Important: `RTWN_FLAG_EXT_HDR` is a per-chip flag. And the FreeBSD r88e might set `sc->efuse_maxlen = 256` and `efuse_maplen = 512`.
> 
> Let me check the values:
> - R92C_EFUSE_CTRL: in OpenBSD's r92creg.h, let me grep. And R92C_EFUSE_ACCESS.
> 
> Let me also check `if_rtwn_efuse.h`.
> 
> Hmm, but also: maybe the 8188E actually DOES support the 92C-style 0x30 register read! Let me think:
> - The Linux driver for 8188E uses 0x30 as EFUSE_CTRL where `rtw_read8(EFUSE_CTRL)` = data, and writes address to 0x31/0x32.
> - The 92C uses 0x30 as a 32-bit register: address in bits 8-17, VALID in bit 31, DATA in bits 0-7.
> 
> These are CONFLICTING interpretations of 0x30! In the 92C, writing 0x30 starts the read; in the 8188E, 0x30 is read-only data.
> 
> Hmm, but actually... maybe they're compatible in a way: In the 92C, `R92C_EFUSE_CTRL_ADDR` might be bits 8-17 of a 32-bit write. For the 8188E, writing to 0x30 (low byte) might be ignored/harmless, and reading 0x30 gives data. If the 92C-style write to 0x30 (addr<<8) happens to be a no-op on the 8188E, then the poll for VALID bit 31 would never succeed → timeout. So FreeBSD's 92C-style read would fail on 8188E.
> 
> UNLESS FreeBSD's r88eu overrides `rtwn_efuse_preread`/`postread` or uses a different chip flag. Let me check `if_rtwn_efuse.h` and `if_rtwnvar.h` for the efuse hooks.
> 
> Let me look. Also, let's check R92C_EFUSE_CTRL and R92C_EFUSE_ACCESS values in FreeBSD.
> 
> Let me fetch r92c_reg.h (just grep) and if_rtwn_efuse.h.
> 
> Let me batch.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/freebsd-r88e && cat if_rtwn_efuse.h; echo "=== fetch r92c_reg.h ==="; curl -sS --max-time 60 "https://api.github.com/repos/freebsd/freebsd-src/contents/sys/dev/rtwn/rtl8192c/r92c_reg.h?ref=main" | python3 -c "import json,sys,base64; d=json.load(sys.stdin); sys.stdout.write(base64.b64decode(d[\'content\']).decode(\'utf-8\',\'replace\'))" > r92c_reg.h 2>/dev/null; grep -n "EFUSE" r92c_reg.h | head -30'}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/openbsd/sys/dev/ic && grep -n "EFUSE" r92creg.h | head -20; echo "=== openbsd rtwnvar ==="; cat ../ic/rtwnvar.h | sed -n \'80,137p\''}

> **[reasoning]**
> So OpenBSD's `R92C_EFUSE_ACCESS = 0x0cf` and `R92C_EFUSE_ACCESS_ON = 0x69` — exactly matching Linux's `REG_EFUSE_ACCESS = 0x00CF` / `EFUSE_ACCESS_ON = 0x69`. ✓✓
> 
> And the OpenBSD `rtwnvar.h` has `struct r88e_rom` in the union and `crystal_cap`. But OpenBSD's urtwn (if_urtwn.c) has NO efuse code — so OpenBSD must read the ROM in `sys/net/if/rtwn.c` (the bus-agnostic part). Let me check: OpenBSD's `sys/net/if/rtwn.c` has `rtwn_attach()` which calls `rtwn_read_rom`? Hmm, OpenBSD's urtwn has `rtwn_efuse_read`? The local checkout doesn't include rtwn.c. Let me fetch it from a GitHub mirror of OpenBSD src.
> 
> Let me check: is there "openbsd/src" on GitHub? Let me try the API.
> 
> Also note: OpenBSD's `struct r88e_rom` — the project says "rom[185] = xtal ✓ identik dengan `struct r88e_rom.xtal` (offset 185) di OpenBSD ✓". So they have the OpenBSD r88e_rom struct (probably from a header they fetched). Let me find it: `sys/net/if/rtwnvar.h`? or `sys/dev/ic/r92creg.h`? The local r92creg.h might have it. Let me grep.
> 
> Let me do that + try to get OpenBSD's rtwn.c for the efuse read.
> 
> Also I realize: OpenBSD's urtwn for 88E — the `if_urtwn.c` we have has no efuse. But `rtwn.c` in sys/net/if does. Let me check via GitHub API for openbsd/src mirror.
> 
> Let me batch.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/openbsd/sys/dev/ic && grep -n "r88e_rom" -A 45 r92creg.h | head -60'}

> **[tool shell]** {'command': 'for repo in openbsd/src openbsd/openbsd-src; do printf "%-22s " "$repo"; curl -sS --max-time 20 -o /dev/null -w "%{http_code}" "https://api.github.com/repos/$repo" 2>/dev/null; echo; done; echo "--- try openbsd mirror list ---"; curl -sS --max-time 20 "https://api.github.com/search/repositories?q=openbsd+src+in:name&sort=stars&per_page=8" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); [print(i[\'full_name\'], i[\'stargazers_count\'], i[\'description\']) for i in 

> **[reasoning]**
> `openbsd/src` on GitHub — 3903 stars. Let me fetch `sys/net/if/rtwn.c` from it via the API. That's the bus-agnostic part with the efuse read.
> 
> Let me do it.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src && curl -sS --max-time 60 "https://api.github.com/repos/openbsd/src/contents/sys/net/if/rtwn.c" | python3 -c "import json,sys,base64; d=json.load(sys.stdin); sys.stdout.write(base64.b64decode(d[\'content\']).decode(\'utf-8\',\'replace\'))" > openbsd_rtwn.c 2>/dev/null; wc -l openbsd_rtwn.c; echo "=== efuse / rom ==="; grep -n "efuse\\|read_rom\\|rom\\b\\|macaddr\\|crystal" openbsd_rtwn.c | head -40'}

> **[reasoning]**
> Empty. The API might need a ref. Let me try with `?ref=master`. openbsd/src's default branch is "master".
> 
> Let me retry.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src && curl -sS --max-time 60 "https://api.github.com/repos/openbsd/src/contents/sys/net/if/rtwn.c?ref=master" -o /tmp/o.json 2>/dev/null; head -c 300 /tmp/o.json; echo; python3 -c "\nimport json,base64\nd=json.load(open(\'/tmp/o.json\'))\nprint(d.get(\'name\'), d.get(\'size\'))\nopen(\'openbsd_rtwn.c\',\'wb\').write(base64.b64decode(d[\'content\']))\n" 2>&1 | head -5; wc -l openbsd_rtwn.c 2>/dev/null'}

> **[reasoning]**
> Not found — the path may be different. Let me list the repo root / sys/net/if to find it.
> 
> Let me use the git trees API to find "rtwn" files.
> 
> Actually, `https://api.github.com/repos/openbsd/src/git/trees/master?recursive=1` would be huge. Let me instead list `sys/net/if`.
> 
> Hmm, but maybe the openbsd/src repo is huge and the contents API is slow/limited. Let me try listing.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src && curl -sS --max-time 60 "https://api.github.com/repos/openbsd/src/contents/sys/net/if?ref=master" -o /tmp/l.json 2>/dev/null; python3 -c "\nimport json\nd=json.load(open(\'/tmp/l.json\'))\nif isinstance(d,dict): print(d); raise SystemExit\nfor x in d:\n  if \'rtwn\' in x[\'name\'] or \'if_urtwn\' in x[\'name\']: print(x[\'name\'], x[\'size\'])\n" 2>&1 | head -20'}

> **[reasoning]**
> Hmm, the repo may be a "git conversion" with a different default branch name, or the API is blocked for that repo. Let me check the repo's default branch.
> 
> Actually, maybe the default branch is "master" but the API returns 404 for contents because the repo is a mirror with submodule-like structure? Let me just check the repo metadata and try a simple path.
> 
> Let me try webfetch on the github blob page for openbsd/src sys/net/if/rtwn.c.
> 
> Actually, let me be efficient — the key info I need from OpenBSD's rtwn.c is the efuse read for 88E. But we already know from FreeBSD that the BSD lineage uses the 92C-style efuse read at 0x30 for ALL chips including 88E (FreeBSD's `rtwn_efuse_read` is generic, and `rtwn_efuse_preread`/`postread` are per-chip). Let me check FreeBSD's `rtwn_efuse_preread`/`rtwn_efuse_postread` — they're declared where? In `if_rtwnvar.h` as function pointers? Let me grep if_rtwn.c / if_rtwnvar.h.
> 
> Let me fetch FreeBSD's `if_rtwnvar.h` and grep for efuse hooks + `RTWN_FLAG_EXT_HDR` + `efuse_maxlen`/`efuse_maplen` for r88eu.
> 
> That's the decisive question: does FreeBSD's r88eu override the efuse read to use the 8188E-style registers?
> 
> Let me check `r88eu_attach.c` (rest of it) for `efuse` and `RTWN_FLAG_EXT_HDR`.
> 
> Let me batch.

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/freebsd-r88e && sed -n \'120,230p\' r88eu_attach.c; echo "=== grep efuse flags ==="; grep -rn "efuse\\|EXT_HDR" r88eu_attach.c r88eu.h r88eu_reg.h | head -20'}

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/freebsd-r88e && curl -sS --max-time 30 "https://api.github.com/repos/freebsd/freebsd-src/contents/sys/dev/rtwn/if_rtwnvar.h?ref=main" | python3 -c "import json,sys,base64; d=json.load(sys.stdin); sys.stdout.write(base64.b64decode(d[\'content\']).decode(\'utf-8\',\'replace\'))" > if_rtwnvar.h 2>/dev/null; grep -n "efuse\\|EXT_HDR\\|rom\\b\\|parse_rom\\|preread\\|postread" if_rtwnvar.h | head -30'}

> **[reasoning]**
> **DECISIVE FINDING for topic B:**
> 
> FreeBSD's r88eu uses the **generic 92C-style efuse reader** (`rtwn_efuse_read` at register 0x30 with ADDR in bits 8-17 and VALID in bit 31), with `sc_efuse_preread = rtwn_nop_int_softc` and `sc_efuse_postread = rtwn_nop_softc` — **no 8188E-specific efuse read override!**
> 
> This means **FreeBSD (and therefore presumably OpenBSD) successfully read the 8188E EFUSE using the 92C-style 0x30 register access**!
> 
> Wait... but the project determined from vendor RE that "OpenBSD menulis address ke 0x030 — pada 8188E itu register DATA, bukan address." That conclusion was based on the vendor's `EFUSE_OneByteRead` using 0x031/0x032/0x033.
> 
> Hmm. So there is a conflict. Two possibilities:
> (a) The 0x30 32-bit write (addr<<8) on the 8188E ALSO works — i.e. the 8188E's 0x30 register in 32-bit read/write has the same layout as 92C when accessed as 32-bit, and the 0x31/0x32/0x33 registers are an alias. Then reading 0x030 as 8-bit gives the data byte, and reading 0x030 as 32-bit gives data|addr<<8|valid<<31. That's actually consistent! The 92C-style read:
>    - write 0x30 (32-bit) = (addr << 8) & 0x3FF00, clear VALID bit
>    - poll 0x30 until bit31 set
>    - data = 0x30 & 0xFF
> 
>    And the 8188E-style read (Linux):
>    - write 0x31 = addr & 0xFF
>    - write 0x32 = (0x32 & 0xFC) | ((addr>>8) & 3)
>    - write 0x33 = 0x72
>    - poll 0x33 bit7
>    - data = 0x30 (8-bit read)
> 
>    These are two different register interfaces to the same efuse block. But **if the 8188E's 0x30 is writable as a 32-bit register with the address in bits 8-17**, then the 92C-style works too. However, the project RE'd the vendor binary and found the 8188E uses 0x31/0x32/0x33.
> 
> Hmm, so FreeBSD's 8188E support: does it actually work? FreeBSD's r88eu was contributed by Andriy Voskoboinyk in 2015-2016. Let me check if there are known issues. Actually — I recall FreeBSD's 88E support was indeed flaky, and there were commits fixing the efuse read for 88E. Let me check FreeBSD's git history for `if_rtwn_efuse.c` and `r88eu`.
> 
> Actually, more decisive: let me check the current FreeBSD `if_rtwn_efuse.c` — we already have it and it's 92C-only with no 88E special-casing. And `rtwn_efuse_read_next` reads `R92C_EFUSE_CTRL` (0x030) as 32-bit.
> 
> Hmm, BUT: notice `rtwn_efuse_read_next` does:
> ```c
> reg = rtwn_read_4(sc, R92C_EFUSE_CTRL);
> reg = RW(reg, R92C_EFUSE_CTRL_ADDR, sc->next_rom_addr);
> reg &= ~R92C_EFUSE_CTRL_VALID;
> rtwn_write_4(sc, R92C_EFUSE_CTRL, reg);
> ```
> On the 8188E, writing 32 bits to 0x30 would write the low byte (0x30) = data byte AND 0x31 = addr low AND 0x32 = addr high bits AND 0x33 = ... 
> 
> OH WAIT. That's IT! On the 8188E:
> - 0x30 = DATA (byte 0 of the 32-bit word)
> - 0x31 = address low (byte 1)
> - 0x32 = address high (byte 2)
> - 0x33 = status/cmd (byte 3)
> 
> A 32-bit WRITE to 0x30 writes all four bytes: 0x30 = data, 0x31 = addr_lo, 0x32 = addr_hi, 0x33 = status. So writing `(addr << 8) & 0x3FF00` to 0x30 as 32-bit sets:
> - byte0 (0x30) = 0x00 (data, don't care)
> - byte1 (0x31) = addr & 0xFF ✓
> - byte2 (0x32) = (addr >> 8) & 0xFF — but the 8188E only uses bits 1:0 of 0x32, so (addr>>8)&3 ✓ (as long as addr < 1024, bits 2-7 are 0 → 0x32 = (addr>>8) & 0x03, and the 8188E masks with 0xFC on read-modify-write so other bits are preserved) ✓
> - byte3 (0x33) = 0x00 (status: bit7 = 0 → "not ready"/start) ✓ — matches the Linux `write 0x033 = v & 0x7F`!
> 
> **So the 92C-style 32-bit write to 0x30 IS EQUIVALENT to the 8188E's 0x31/0x32/0x33 sequence!** That's a beautiful reconciliation.
> 
> And then the READ: `rtwn_read_4(sc, R92C_EFUSE_CTRL)` reads 0x30..0x33 as 32-bit:
> - byte0 (0x30) = data ✓
> - byte1 (0x31) = addr echo
> - byte2 (0x32) = addr high echo
> - byte3 (0x33) = status → bit7 = ready
> 
> The 92C code polls `reg & R92C_EFUSE_CTRL_VALID` (bit 31 of the 32-bit value) = **bit 7 of byte 3 = 0x033 bit 7** = **the 8188E's READY bit**!!! ✓✓✓
> 
> **THAT IS THE ANSWER.** The 92C-style read works on the 8188E:
> - write 0x30 (32-bit) = (addr << 8) → sets 0x031 = addr_lo, 0x032 = addr_hi, 0x033 = 0x00 (bit7 clear = start)
> - poll read32(0x30) until bit31 (i.e. 0x033 bit7) is SET = ready
> - data = read32(0x30) & 0xFF = 0x030 byte
> 
> This 100% matches the Linux 8188E driver semantics:
> - Linux `ReadEFuseByte`: write 0x031 = addr&0xFF, write 0x032 = ((addr>>8)&3)|(0x32&0xFC), write 0x033 = 0x33&0x7F (bit7 clear = start), poll 0x033 bit7 SET, then read 0x030.
> - Linux `efuse_OneByteRead`: write 0x031, write 0x032, write 0x033 = 0x72 (bit1 = read cmd, bit7 = 0), poll 0x033 bit7 SET, read 0x030.
> 
> Wait, there's a subtlety: the 92C write does `reg &= ~R92C_EFUSE_CTRL_VALID` which clears bit31 = byte3 bit7 = 0x033 bit7. And it doesn't set 0x033 bit1 (the "read cmd"). Linux's `ReadEFuseByte` also doesn't set bit1. Linux's `efuse_OneByteRead` sets 0x72 = 0b0111_0010, i.e. bit1=1 (read cmd), bits 4,5,6 = 1. Hmm — so which is needed?
> 
> Note: 0x72 has bit1 set. In the 92C-style write, byte3 = 0x00 (bit1 clear). Hmm.
> 
> But hold on — is bit1 of 0x033 a "read command" trigger? If so, the 92C-style path (which never sets bit1) would never trigger the read... unless the write to 0x031/0x032 itself triggers it.
> 
> Hmm, but actually: In the 92C-style write, the FULL 32-bit write also writes 0x030 = data byte 0x00. On the 92C, writing 0x30 with the VALID bit clear *starts* the read. On the 8188E, writing 0x030 (data) might be harmless, and writing 0x031/0x032 (address) starts the read, and 0x033 bit7 = busy/ready.
> 
> Given Linux's `ReadEFuseByte` explicitly does the RMW `0x033 = 0x33 & 0x7F` (clear bit7) and then polls for bit7 SET, and the 92C-style write naturally sets 0x033 = 0x00 (bit7 clear), the 92C-style write is equivalent to Linux's `ReadEFuseByte` sequence, EXCEPT that the 92C write also clobbers 0x033 bits 0-6 to 0 (whereas Linux preserves them, e.g. bit1 = read cmd set by a previous `efuse_OneByteRead`).
> 
> Hmm, that's the potential difference: if bit1 of 0x033 must be 1 to trigger a read, then the 92C-style path never triggers it and would time out. But FreeBSD's 88E support apparently works...
> 
> Let me resolve this definitively. I should check:
> 1. FreeBSD's `rtwn_efuse_read_next` for 88E — does it work? Let me look for FreeBSD commit history / bugs.
> 2. Another idea: check the Realtek *SDIO* driver or the rtl8189es, which use the same 0x30/0x31/0x32/0x33.
> 
> Actually, here's a cleaner reconciliation. Let's look at the RTL8189E / RTL8188E **SDIO** driver (8189es), where the efuse is accessed via SDIO. Not helpful.
> 
> Let me instead look at **another Linux Realtek driver that supports 8188E**: e.g. `rtl8188eu` in the Zircon tree (same as lwfinger). Or, better, look at how the **rtl8188eu driver reads the efuse in `rtw_efuse_map_read`**, which is what the project would use.
> 
> Actually, the decisive question for the project is: which register sequence to use. Let me get more evidence:
> 
> Evidence 1 (Linux, 2 independent functions): 0x31/0x32/0x33 with poll for 0x033 bit7 SET.
> Evidence 2 (FreeBSD/OpenBSD, 1 function): 32-bit 0x30 with poll for bit31 SET (= 0x033 bit7 SET) and data = low byte.
> These AGREE on the ready polarity (bit7 SET = ready) — the 92C-style VALID bit is exactly 0x033 bit7 in the 8188E's register layout!
> 
> The only difference is whether 0x033 bit1 must be set.
> 
> Let me check: does FreeBSD's 88E actually work? Let me search FreeBSD's git log for r88eu/efuse fixes. Let me use the GitHub API for commits touching `sys/dev/rtwn/if_rtwn_efuse.c` — hmm, API for commits: `https://api.github.com/repos/freebsd/freebsd-src/commits?path=sys/dev/rtwn/if_rtwn_efuse.c`.
> 
> Let me do that — it will reveal if there were fixes for 88E.
> 
> Also let me check OpenBSD's git log for `rtwn_efuse` / 88E.
> 
> This is a very high-value investigation. Let me do it.
> 
> Also — I should double check: is the "ready" bit at 0x033 bit 7, or is the project's `0x033 & 0x80` check on the *busy* flag? Both Linux functions poll for bit7 SET = "read-ready". The project polls for bit7 CLEAR. And the project's direct path timed out (bit7 never cleared) → meaning bit7 is READ-ONLY 1 (hardware sets it) OR the write of 0x7F didn't take effect.
> 
> Hmm! If bit7 is read-only and always 1 once the efuse is powered, then:
> - The project clears bit7 (no effect, stays 1) → polls for CLEAR → times out ✓ matches "efuse-direct-gagal"
> - Linux clears bit7 (no effect) then polls for SET → immediately true → reads 0x030. But then the data might be STALE... unless the read is triggered by the address write and completes fast enough.
> 
> Hmm, but Linux's `ReadEFuseByte` has: write address → write 0x033 (clear bit7) → poll for bit7 set → `rtw_udelay_os(50)` → read 0x030. The 50µs delay comment says "there shall be some delay after ready bit is set, or the result will always stay on last data we read". This implies bit7 CAN be cleared by the write (it becomes 0 during the read and 1 when done). So writing bit7=0 starts the read.
> 
> If the project's write of 0x033 = v & 0x7F is effective, bit7 → 0, and then the poll for CLEAR would succeed IMMEDIATELY (first iteration) and read 0x030 → stale/garbage. But the log says it FAILED (timeout). So the write of 0x033 = v & 0x7F did NOT clear bit7 in the project's implementation. Why?
> 
> Possible reasons:
> 1. The EFUSE power switch was never enabled (0x00CF = 0x69 + SYS_ISO/CLK enable). Without power, the efuse block doesn't respond, and 0x033 reads 0xFF (bit7 set) always. → project polls for CLEAR, sees 0xFF (bit7 set) → times out. ✓✓✓ EXACTLY matches!
> 
> **So the root cause is: the project never enables the EFUSE access (0x00CF = 0x69 + clock/ISO enables), so 0x033 always reads 0xFF.**
> 
> And after enabling power, the correct polarity is "wait for bit7 SET" (ready).
> 
> This is a very strong, coherent diagnosis:
> - Project writes 0x69 to 0x106 (wrong register; should be 0x00CF) and never sets REG_SYS_ISO_CTRL/PWC_EV12V, REG_SYS_FUNC_EN/FEN_ELDR, REG_SYS_CLKR/LOADER_CLK_EN|ANA8M.
> - Project polls for 0x033 bit7 CLEAR; hardware wants bit7 SET (ready).
> 
> And the 32-bit 0x30 write trick means the project could even use the OpenBSD/FreeBSD-style code unchanged IF it also did the power switch! Because FreeBSD's `rtwn_efuse_switch_power` does exactly:
> - write 0x0CF = 0x69 (R92C_EFUSE_ACCESS_ON)
> - SYS_FUNC_EN |= ELDR
> - SYS_CLKR |= LOADER_EN | ANA8M
> 
> **THIS IS THE KEY INSIGHT**: OpenBSD's urtwn *does* have a working efuse read for the 88E, IF you add the power switch. The project probably ported the OpenBSD 0x30-style read but WITHOUT the power switch and WITHOUT checking that the 88E's 0x30 write also writes 0x31/0x32/0x33.
> 
> Hold on — but OpenBSD's urtwn (if_urtwn.c) has no efuse code, and I couldn't fetch rtwn.c. Let me try harder to get OpenBSD's rtwn.c because it contains `rtwn_efuse_read` for the 88E including `rtwn_efuse_read_next` with the EXT_HDR handling and the per-chip `rtwn_efuse_preread`.
> 
> Let me try the openbsd/src repo via a different route — maybe the default branch is "master" but the API path needs "master" and the repo is large. Let me use the raw path via codeload? The whole openbsd/src tarball is huge.
> 
> Alternative: search for a mirror with the file. Or use `https://github.com/openbsd/src/blob/master/sys/net/if/rtwn.c` via webfetch (worked for other repos). Let me try that — but the file is large and webfetch may truncate.
> 
> Let me try the contents API with a different branch name, e.g. "main".
> 
> Let me test a couple of things in parallel:
> 1. webfetch openbsd/src blob rtwn.c
> 2. GitHub API commits for freebsd if_rtwn_efuse.c
> 
> Let me go.

Major reconciliation found. Let me verify against OpenBSD's `rtwn.c` and FreeBSD's efuse history.

> **[tool webfetch]** {'format': 'text', 'timeout': 120, 'url': 'https://github.com/openbsd/src/blob/master/sys/net/if/rtwn.c'}

> **[tool shell]** {'command': 'curl -sS --max-time 40 "https://api.github.com/repos/freebsd/freebsd-src/commits?path=sys/dev/rtwn/if_rtwn_efuse.c&per_page=20" | python3 -c "\nimport json,sys\nd=json.load(sys.stdin)\nfor c in d:\n  print(c[\'commit\'][\'author\'][\'date\'][:10], c[\'commit\'][\'message\'].split(chr(10))[0][:100])\n" 2>&1 | head -25'}

> **[reasoning]**
> Interesting: "rtwn: add rtwn_efuse_preread" (2026-08-23) — very recent! Let me see that commit's diff. It probably adds the per-chip efuse preread for 88E. That's exactly the fix I hypothesized!
> 
> Let me fetch the commit details.
> 
> Also, openbsd/src 404 for `sys/net/if/rtwn.c` — maybe the path is `sys/net/if/rtwn.c` doesn't exist; OpenBSD's is `sys/net/if/rtwn.c`... hmm. Let me check the repo structure. Maybe the default branch is different. Let me check repo metadata.
> 
> Let me batch: get the FreeBSD commit diff + check openbsd/src repo info.

> **[tool shell]** {'command': 'curl -sS --max-time 40 "https://api.github.com/repos/freebsd/freebsd-src/commits?path=sys/dev/rtwn/if_rtwn_efuse.c&per_page=5" -o /tmp/c.json; SHA=$(python3 -c "import json;print(json.load(open(\'/tmp/c.json\'))[0][\'sha\'])"); echo "SHA=$SHA"; curl -sS --max-time 40 "https://api.github.com/repos/freebsd/freebsd-src/commits/$SHA" | python3 -c "\nimport json,sys\nd=json.load(sys.stdin)\nprint(\'MSG:\', d[\'commit\'][\'message\'][:600])\nfor f in d[\'files\']:\n  print(\'---\', f[\'fi

> **[tool shell]** {'command': 'curl -sS --max-time 30 "https://api.github.com/repos/openbsd/src" | python3 -c "import json,sys;d=json.load(sys.stdin);print(\'default:\',d.get(\'default_branch\'),\'size:\',d.get(\'size\'))" 2>&1; echo "--- try tree ---"; curl -sS --max-time 60 "https://api.github.com/repos/openbsd/src/contents/sys/net?ref=master" -o /tmp/t.json; python3 -c "\nimport json\nd=json.load(open(\'/tmp/t.json\'))\nif isinstance(d,dict): print(d)\nelse:\n  print([x[\'name\'] for x in d][:40])\n"'}

> **[reasoning]**
> The openbsd/src repo works; `sys/net` is flat (not `sys/net/if/`). So OpenBSD's rtwn.c is at `sys/net/rtwn.c`? Hmm, OpenBSD's `rtwn.c` is in `sys/net/if/`? The listing shows `sys/net` contains if.c, if.h etc. directly — so OpenBSD 7.x moved `sys/net/if/*` to `sys/net/`? Let me grep the listing for "rtwn".
> 
> Let me list sys/net and grep for rtwn.
> 
> And the FreeBSD commit confirms: the 88E uses the **generic 92C-style efuse reader** with `rtwn_efuse_preread`/`postread` as no-ops. So the 92C-style 32-bit 0x30 read DOES work for the 8188E. CONFIRMED by FreeBSD shipping 8188E USB support for years.
> 
> So my reconciliation is right, and the project's claim that "OpenBSD writes address to 0x030 which is DATA on the 8188E" is only *partially* right: a 32-bit write to 0x30 writes all four bytes 0x30-0x33, which is exactly the 8188E's address+status sequence.
> 
> Hmm, but wait. There's a critical detail: the 92C-style write is `reg = RW(reg, ADDR, addr); reg &= ~VALID; write_4(0x30, reg)`. `reg` was READ from 0x30 first, so byte0 = previous data, byte1 = previous 0x31, etc. So:
> - 0x031 ← (addr & 0xFF)  ✓
> - 0x032 ← (addr >> 8) & 0xFF — the 8188E uses only bits 1:0 of 0x032, and the upper 6 bits of 0x032 in the 92C-style write come from the read-back of 0x032 (preserved) — wait no: `reg` is read as 32-bit from 0x30, so byte2 = current 0x032 value. Then `RW(reg, ADDR, addr)` sets bits 8-17 = addr, i.e. byte1 = addr&0xFF, byte2 = (addr>>8)&0xFF. So byte2 is OVERWRITTEN with (addr>>8)&0xFF, i.e. the upper bits (2-7) become 0, clobbering any preserved bits. The 8188E only cares about bits 1:0, and Linux does RMW to preserve 0x32's upper bits. Since Linux's `ReadEFuseByte` preserves them and the 92C-style clobbers them to 0... could that matter? 0x032 bits 2-7 in the 8188E are probably unused/reserved. Risky but probably fine.
> 
> - 0x033 ← (reg & ~VALID) bit 31 cleared → byte3 = current 0x033 with bit7 cleared. ✓ EXACTLY Linux's `rtw_write8(EFUSE_CTRL+3, readbyte & 0x7f)`!!
> 
> **PERFECT MATCH.** The 92C-style 32-bit write to 0x30 is byte-for-byte equivalent to Linux's 8188E `ReadEFuseByte` sequence (modulo 0x032 upper bits).
> 
> And the poll: 92C polls `read_4(0x30) & VALID` (bit31 = 0x033 bit7) → SET = ready. Linux polls 0x033 bit7 → SET = ready. ✓✓✓ IDENTICAL.
> 
> And the data: 92C takes `MS(reg, DATA)` = bits 0-7 = 0x030 byte. Linux reads 0x030 as 8-bit. ✓
> 
> **CONCLUSION: The project's "direct EFUSE" implementation is unnecessary — the OpenBSD/FreeBSD 92C-style reader works on the 8188E, PROVIDED the EFUSE power switch is done (write 0x00CF = 0x69, SYS_FUNC_EN |= ELDR, SYS_CLKR |= LOADER_EN|ANA8M).**
> 
> And the project ALREADY has `rtwn_seq_read_efuse` (the OpenBSD-style path) per tools/rtwn_probe.c line 233! So the fix might be simply: add the power switch to that path.
> 
> Let me verify: does the project's `rtwn_seq_read_efuse` do the power switch? Let me look at src/urtwn/rtwn_seq.c.
> 
> Let me check.
> 
> Also, let me find OpenBSD's rtwn.c path. Let me list sys/net for rtwn.
> 
> Let me batch.

Decisive reconciliation. Let me verify the project's own OpenBSD-style EFUSE path and OpenBSD's `rtwn.c`.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport && grep -n "0x0cf\\|0xCF\\|EFUSE_ACCESS\\|efuse_switch_power\\|0x00cf\\|0x002\\|0x008\\|0x0000" src/urtwn/rtwn_seq.c | head -30; echo "=== rtwn_seq_read_efuse ==="; grep -n "rtwn_seq_read_efuse" -A 60 src/urtwn/rtwn_seq.c | head -80'}

> **[tool shell]** {'command': 'curl -sS --max-time 60 "https://api.github.com/repos/openbsd/src/contents/sys/net?ref=master" -o /tmp/t2.json; python3 -c "\nimport json\nd=json.load(open(\'/tmp/t2.json\'))\nprint([x[\'name\'] for x in d if \'rtwn\' in x[\'name\'] or \'urtwn\' in x[\'name\']])\n"'}

> **[reasoning]**
> The project ALREADY has the OpenBSD-style `rtwn_seq_read_efuse` with the power switch! And it reads raw bytes 0..255 sequentially.
> 
> **CRITICAL BUG**: The OpenBSD/FreeBSD efuse reader is NOT a "sequential read of 256 physical bytes". It's a **header-driven walk**:
> 1. Read byte at addr 0.
> 2. If 0xFF → done.
> 3. Interpret as a PG header: `off = reg >> 4`, `msk = reg & 0xF`.
> 4. Read `word_cnts = popcount(~msk & 0xF)` words (2 bytes each) of DATA for that section.
> 5. Advance addr by `1 + word_cnts*2`.
> 6. Read the next header.
> 
> The project's `rtwn_seq_read_efuse` reads **physically sequential** bytes 0..255 and feeds them to `efuse_parse_8188e(raw, 256, rom)`. But `efuse_parse_8188e` expects a **header+data stream** (like the physical map) — so this is roughly right in that it reads the raw physical stream! Actually yes — the physical efuse IS a sequential stream of [header][data...][header][data...]. So reading bytes 0..255 sequentially gives the physical stream, and then the parser walks it. That's consistent with Linux's `efuse_phymap_to_logical`.
> 
> BUT: the project **stops at the first 0xFF byte** (`if (v == 0xff) break;`). In the physical efuse stream, a 0xFF byte can legitimately appear in the middle of a data block! The header always has `(hdr & 0x1F) == 0x0F` or a valid section/mask, but DATA bytes can be 0xFF (unprogrammed bits). FreeBSD's reader only treats 0xFF as "end" when it appears at a **header position**. The project's early break on the first 0xFF would truncate the map → possibly losing the MAC at 0xD7!
> 
> That's a REAL BUG. And it's exactly the kind of thing that produces ff:ff:ff:ff:ff:ff.
> 
> Hmm, but the log says the direct path failed and the offload path "succeeded" with ff:ff:ff:ff:ff:ff. The `rtwn_seq_read_efuse` (OpenBSD-style) path — was it even tried? The log shows only "efuse-direct" then "efuse-offload". So the OpenBSD-style path may not have been in the M1 flow.
> 
> Also, **the project's `efuse_read_1`** — let me look at it. It's the 92C-style read. Let me read it (lines ~380-425 of rtwn_seq.c).
> 
> Let me look at the whole efuse section of rtwn_seq.c.
> 
> Also, the loop: `for (addr = 0; addr < len && addr < sizeof(raw); addr++)` with len=256 and sizeof(raw)=256 → fine now.
> 
> Let me read rtwn_seq.c lines 200-426.
> 
> This is the most valuable thing I can deliver: an exact, actionable diagnosis of the EFUSE path.
> 
> Let me read.

> **[tool read]** {'limit': 230, 'offset': 200, 'path': '/Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/src/urtwn/rtwn_seq.c'}

> **[reasoning]**
> Now I have a full picture of the project's EFUSE code. Key findings for B:
> 
> ### Confirmed bugs in the project's EFUSE path:
> 
> 1. **`rtwn_seq_read_efuse` (OpenBSD-style) breaks at the first 0xFF byte.** In the physical EFUSE stream, 0xFF can legitimately occur inside a data block. FreeBSD/OpenBSD only treat 0xFF as "end of map" when it appears at a *header* position. The project must read the full 256 bytes (or use the header-driven walk) and let the parser handle it. Actually — since `efuse_parse_8188e` walks the stream itself and stops at `cur == 0xff` at a header position, the project should just read ALL 256 bytes unconditionally and let the parser handle termination. This is likely THE bug in the OpenBSD-style path (if it's used).
> 
> Hmm, wait. But also: the project's `efuse_read_1` (line ~195-216) uses the 92C-style 32-bit access. That is correct for the 8188E (as I reconciled). And it does the power switch. So the OpenBSD-style path SHOULD work... except for the 0xFF early break.
> 
> Hmm, but hold on: there's another subtlety. The 92C-style read does `reg = rd32(0x30)` then modifies ADDR and clears VALID then `wr32(0x30, reg)`. The byte written to 0x030 is the *previous data byte*. On the 8188E, writing to 0x030 (data register) — is it harmless? If 0x030 is read-only, the write is ignored → fine. If writable, it just changes the data register → fine.
> 
> Also byte2 (0x032) gets `(addr>>8)&0xFF` — the 8188E only uses bits 1:0. But Linux preserves bits 2-7 of 0x032 via RMW. If bits 2-7 of 0x032 have other meanings on the 8188E, clobbering them could break something. Risk noted.
> 
> And byte3 (0x033) = (previous 0x033) & ~0x80 — matches Linux's `0x33 & 0x7F` ✓.
> 
> 2. **The "direct" path (`rtwn_seq_read_efuse_direct_8188e`)** has 3 bugs:
>    a. Writes 0x69 to **0x106** instead of **0x00CF** (REG_EFUSE_ACCESS). 0x106 is REG_PKT_BUFF_ACCESS_CTRL (the offload packet-buffer select) — unrelated to the direct read.
>    b. **No EFUSE power switch** (SYS_ISO_CTRL/PWC_EV12V, SYS_FUNC_EN/ELDR, SYS_CLKR/LOADER_EN|ANA8M). Without it the EFUSE block is not powered → 0x033 reads 0xFF forever → the "wait for bit7 CLEAR" poll times out → "efuse-direct-gagal" ✓ exactly what the log shows.
>    c. **Ready-bit polarity inverted**: waits for bit7 CLEAR; hardware signals ready with bit7 SET (Linux: `while (!((value32>>24) & 0x80))`; and 92C-style: poll bit31 = 0x033 bit7 SET).
> 
>    Also: it should add a ~50 µs delay after ready before reading 0x030 (Linux's comment: "there shall be some delay after ready bit is set, or the result will always stay on last data we read").
> 
>    And: `efuse_OneByteRead` in Linux writes 0x033 = **0x72** (not RMW of 0x7F). 0x72 sets bit1 (read command). Whether bit1 is required is unclear; Linux's `ReadEFuseByte` doesn't set it and works, so the 92C-style (byte3 = prev & 0x7F) is probably fine.
> 
> 3. **The offload path returns all-0xFF because it runs BEFORE the firmware is uploaded.** The offload EFUSE read is executed by the 8051 firmware; with no firmware in RAM the 8051 can't service it. Fix: do the offload read AFTER `rtl8188e_FirmwareDownload` (i.e., after firmware upload). The project's own CONTINUE.md suspects this.
> 
> 4. **The MAC/xtal offsets are CORRECT**: MAC at rom[0xD7..0xDC] = 215..220 (confirmed by FreeBSD `struct r88e_rom` `diff_d0.usb.macaddr` and Linux `EEPROM_MAC_ADDR_88EU = 0xD7`); xtal/crystal cap at rom[0xB9] = 185 (FreeBSD `crystalcap`, Linux `EEPROM_XTAL_88E`).
> 
> 5. **xtal semantics**: rom[0xB9] is the crystal *load-cap* code (0..0x3F), default 0x20, applied to REG_AFE_XTAL_CTRL (0x24) bits [16:11] and [22:17] = cap | (cap<<6). It is NOT a frequency in Hz. Also rom[0x06] is a second crystal-cap field (from the vendor's Hal_EfuseParseXtal_8188E). The 8188E crystal is 40 MHz (per Linux's `REG_AFE_XTAL_CTRL` usage; actually RTL8188E supports 20/40 MHz; Realtek's 8188E is 40MHz). Hmm — I should be careful. Let me note: the vendor's `InitCrystalFrequency_8188E` reads rom[0xB9] as "xtal". Both Linux and the vendor agree that rom[0xB9] is the cap code. So the project's `r->xtal = rom[185]` is semantically "crystal cap", which is what should be applied to 0x24.
> 
> 6. **Vendor's `Hal_EfuseParseXtal_8188E` also reads rom[0x06]** for a second cap value (project doc already found this).
> 
> 7. **ROM ID check**: Linux checks `EEPROMId = le16_to_cpu(*(u16*)hwinfo)` == `RTL_EEPROM_ID` (0x8129) to validate autoload. hwinfo[0..1] = rom[0..1] = the "id" field. That's a great sanity check: **if rom[0..1] == 0x8129 (LE), the EFUSE read is valid.** Note FreeBSD's `struct r88e_rom` starts with `uint16_t id;` — same thing.
> 
> Now let me also double check the "vendor broadcast 2×" note in the project comment: "Vendor juga mem-broadcast setiap byte 2× (2 bank)". Hmm, that's about the vendor's `ParsingEfuseContent`. Interesting but the project's differential test validated it.
> 
> Hmm, one thing to check: the project's `efuse_parse_8188e` handles the extended header as:
> ```
> off = ((nxt >> 1) & 0x78) | (cur >> 5)
> ```
> whereas Linux's `efuse_phymap_to_logical` does:
> ```
> u1temp = (rtemp8 & 0xE0) >> 5;     /* 3 bits from header 1 */
> offset = ((rtemp8 & 0xF0) >> 1) | u1temp;   /* 7 bits from header 2 */
> ```
> = ((nxt & 0xF0) >> 1) | ((cur & 0xE0) >> 5) = ((nxt>>1) & 0x78) | (cur>>5). ✓ IDENTICAL.
> 
> And Linux's `wren = rtemp8 & 0x0F` (mask from header 2) ✓ = project's `mask = nxt & 0x0f` ✓.
> 
> And the offset range: Linux `if (offset < EFUSE_MAX_SECTION_88E)` (64). The project masks `off & 0x3f` ✓.
> 
> Wait — but there's a subtle difference: Linux's `efuse_phymap_to_logical` handles the case where the extended header's second byte has `(rtemp8 & 0x0F) == 0x0F` by skipping 2 bytes and continuing. The project does `ri += 2; cur = raw[ri]; ri++; continue;` — hmm, Linux does:
> ```c
> if ((rtemp8 & 0x0F) == 0x0F) {
>     eFuse_Addr++;               /* now points at 2nd byte */
>     rtemp8 = *(phymap+eFuse_Addr);
>     if (rtemp8 != 0xFF && (eFuse_Addr < EFUSE_REAL_CONTENT_LEN_88E))
>         eFuse_Addr++;
>     continue;                   /* continue the while loop with the SAME rtemp8 */
> }
> ```
> So Linux: after the extended header byte, eFuse_Addr++ (now at byte2), read byte2; if byte2 != 0xFF, eFuse_Addr++ (now at byte3); then `continue` → the while condition is checked with `rtemp8` = byte2. So byte2 is re-processed as a header! Hmm, and byte3 is skipped.
> 
> The project: `ri += 2; cur = raw[ri]; ri++; continue;` — after ri was pointing at byte2 (nxt). ri += 2 → points at byte4?? Let me trace:
> - Before the ext-header branch: cur = raw[0] (header 1), ri = 1.
> - nxt = raw[ri] = raw[1] (header 2). If (nxt & 0x0f) == 0x0f:
>   - Project: `ri += 2` → ri = 3; `cur = raw[3]`; `ri++` → ri = 4; continue.
>   - Linux: eFuse_Addr was 1 (pointing at header 2). eFuse_Addr++ → 2 (byte3). rtemp8 = raw[2]; if != 0xFF, eFuse_Addr++ → 3. continue → while loop re-checks rtemp8 = raw[2] as a header.
> 
> So Linux processes raw[2] as a header and continues from eFuse_Addr=3. The project skips raw[2] and raw[3] and continues from raw[4]. **DIFFERENT!** 
> 
> Hmm, so the project's parser may differ from Linux's here. But the project says it validated against the vendor's decompiled pseudocode with a 20,000-image differential test — so the vendor's behavior matches the project's version. It's plausible Linux and the vendor differ here (a vendor bug, or my reading of Linux is off). Since the project validated against the vendor, and the vendor is the ground truth for this chip, I should flag it as a *cross-check opportunity* rather than claim a bug. I'll note: Linux's `efuse_phymap_to_logical` handles the "double 0x0F" extended header differently from the vendor; worth testing which one the actual chip needs (real images rarely hit that branch).
> 
> Actually more important: **Linux's `efuse_phymap_to_logical` is the GOLD REFERENCE for a from-scratch implementation** and it's simpler/more careful than the vendor decompile. I'd recommend the project cross-validate against it.
> 
> OK, I have enough for B. Let me now cover:
> - C: firmware (I have the full Linux `_WriteFW`/`_FWFreeToGo` sequence + FreeBSD's `r88e_fw_download_enable`). Also the project says "FW_FirmwareDownload (versi OpenBSD, perlu port H2C vendor)". Let me check what OpenBSD's urtwn does for firmware on 88E: `urtwn_fw_loadpage` + `urtwn_load_firmware`. Let me look at the local if_urtwn.c for the 88E firmware path — that's what the project ported. And compare to the Linux H2C-free approach.
> 
> Actually, important: the Linux 8188E firmware download is NOT H2C — it's a direct memory write to the 8051 code area (0x1000) with MCUFWDL handshake. The H2C mechanism (H2C_COM_RSVD_PAGE etc.) is for runtime commands, not for the initial firmware blob. The vendor's `FW_FirmwareDownload` for 8188E USB might use H2C though (the project doc says "FW_FirmwareDownload (versi OpenBSD, perlu port H2C vendor)"). Hmm.
> 
> Let me check OpenBSD's urtwn 88E firmware path in the local if_urtwn.c.
> 
> - E: descriptors + OpenBSD scan/join.
> 
> Let me also spend remaining effort on D (the other blocker) — specifically:
>   * The `IONetworkRootType=airport` + `IOMatchCategory=WiFiDriver` mechanism — verify.
>   * What `IO80211FamilyLegacy` does and whether the third-party kext needs to be a "PlugIn" inside it.
>   * The `IO80211SupportedFeatures` thing the brief mentions.
>   * USB → IO80211: does the Wi-Fi menu require "Apple wireless"?
> 
> Let me grep the itlwm AirportItlwm for "IO80211SupportedFeatures" / "SupportedFeatures" and check the itlwm docs site.
> 
> Let me batch: OpenBSD firmware path + itlwm features grep.

Let me now cover the firmware path and the macOS "supported features" mechanism.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/openbsd/sys/dev/usb && grep -n "urtwn_load_firmware\\|urtwn_fw_loadpage\\|MCUFWDL\\|fw_loadpage" -A 30 if_urtwn.c | sed -n \'1,120p\''}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/itlwm && grep -rn "IO80211SupportedFeatures\\|SupportedFeatures\\|supportedFeatures\\|enableFeature\\|kIO80211Feature" --include="*.cpp" --include="*.hpp" . | head -20'}

> **[reasoning]**
> Now I have:
> - OpenBSD's `urtwn_fw_loadpage`: MCUFWDL PAGE field, max block size 196 (254 for 92E), writes at R92C_FW_START_ADDR, in chunks: full blocks of 196, then 4-byte, then 1-byte. This EXACTLY matches Linux's `_BlockWrite` 3-phase scheme (196 / 8 / 1 — OpenBSD uses 4 instead of 8 for the middle phase). Interesting nuance: Linux uses 8-byte for phase 2, OpenBSD uses 4-byte. Both work; the 196 is the key (matching USB bulk boundary of 512? 196*2+... hmm, 196 = (512-32-8)/2.33? Actually 196*2 = 392... The 196 comes from the 92C "max block size" = 196 because the USB bulk-out boundary is 512 bytes: 196 + 196 + 120 = 512. So the firmware is written in 196-byte chunks to align with USB 512-byte boundaries.
> 
> - `R92C_FW_START_ADDR` — let me get the value (Linux: FW_8188E_START_ADDRESS = 0x1000).
> - `R92C_MCUFWDL_PAGE` mask.
> 
> - itlwm: `supportedFeatures()` → `fHalService->getDriverInfo()->supportedFeatures()` and `enableFeature(kIO80211Feature80211n)`. This is the "IO80211SupportedFeatures" mechanism the brief mentioned: the driver reports supported features via `apple80211Request`/`getIO80211SupportedFeatures`? Let me look at AirportItlwm.cpp:731 context.
> 
> Let me look at that and the `apple80211_ioctl` implementation to see how scan/join is dispatched.
> 
> Let me also get R92C_FW_START_ADDR and R92C_MCUFWDL_PAGE from the local r92creg.h.
> 
> Let me batch.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/openbsd/sys/dev/ic && grep -n "R92C_FW_START_ADDR\\|R92C_MCUFWDL_PAGE\\|R92C_MCUFWDL\\b\\|R92C_MCUFWDL_EN\\|R92C_MCUFWDL_RDY\\|R92C_MCUFWDL_CHKSUM\\|R92C_MCUFWDL_WINTINI\\|R92C_MCUFWDL_RAM" r92creg.h | head -20; echo "=== 88E page/pktbuf ==="; grep -n "R88E_TXPKTBUF_COUNT\\|R88E_TX_PAGE_COUNT\\|R88E_MAX_RX_DMA\\|R88E_TX_RPT\\|R88E_HISR\\|R88E_HIMR" r92creg.h | head -20'}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/itlwm/AirportItlwm && sed -n \'700,760p\' AirportItlwm.cpp; echo "=== enableFeature ==="; sed -n \'945,985p\' AirportItlwm.cpp'}

> **[reasoning]**
> `getFeatures()` is the "IO80211SupportedFeatures" mechanism — `AirportItlwm::getFeatures()` returns `supportedFeatures()`. Let me find where getFeatures is used — probably in `apple80211_ioctl` for `AI_GET_...`? Or it's an `IO80211Controller` method? Hmm, `getFeatures` isn't in the IO80211Controller header I read. Let me grep in itlwm for where getFeatures is called.
> 
> Actually, it might be part of `ItlDriverInfo::supportedFeatures()` → `IEEE80211_CHAN_...`. Let me check ItlIwx.cpp:340.
> 
> Let me also find the `apple80211_ioctl` in itlwm and the scan/join path (AirportSTAIOCTL.cpp).
> 
> Let me look at the key parts of AirportItlwm.cpp's apple80211_ioctl.
> 
> And check the itlwm docs for the "AirportItlwm" architecture doc.
> 
> Let me batch: grep getFeatures usage + look at AirportSTAIOCTL.cpp scan/join.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/itlwm && grep -rn "getFeatures" --include="*.cpp" --include="*.hpp" . | head; echo "=== supportedFeatures impl ==="; sed -n \'335,350p\' itlwm/hal_iwx/ItlIwx.cpp; echo "=== apple80211_ioctl in AirportItlwm ==="; grep -n "apple80211_ioctl" -A 60 AirportItlwm/AirportItlwm.cpp | sed -n \'1,90p\''}

> **[reasoning]**
> `getFeatures()` is an `IONetworkController` virtual (`IONetworkController::getFeatures()` returns `kIONetworkFeature...` flags). And `supportedFeatures()` returns `kIONetworkFeatureMultiPages`.
> 
> Now let me find where the scan/join is dispatched in itlwm. It's in `AirportSTAIOCTL.cpp` — the IOCTL handler. Let me look at it. And `apple80211_ioctl` is likely in `AirportItlwmV2.cpp` (for the modern Skywalk path).
> 
> Let me look at AirportSTAIOCTL.cpp for the scan/join handlers, since that's the "how do I make the Wi-Fi menu scan and join" logic.
> 
> Let me grep for the key request numbers.
> 
> Let me batch: AirportSTAIOCTL.cpp structure + the itlwm docs site fetch.
> 
> Actually, time/effort check: I've gathered a lot. Let me now:
> 1. Quickly scan AirportSTAIOCTL.cpp for the scan/join/associate request handling (D).
> 2. Verify the "does a USB IO80211 interface appear in the Wi-Fi menu" question with a concrete source.
> 3. Wrap up topic E (OpenBSD scan/join, descriptors).
> 
> Let me batch #1 and #2.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/itlwm/AirportItlwm && wc -l AirportSTAIOCTL.cpp && grep -n "case \\|AI_\\|IEEE80211_IOCTL\\|apple80211req" AirportSTAIOCTL.cpp | head -60'}

> **[tool webfetch]** {'format': 'markdown', 'timeout': 60, 'url': 'https://openintelwireless.github.io/itlwm/'}

> **[reasoning]**
> Now I have the full IOCTL dispatch list. This is exactly the set of `APPLE80211_IOC_*` requests the macOS Wi-Fi stack sends to the driver.
> 
> Now, the critical D question: what makes the interface appear in the Wi-Fi menu?
> 
> Let me verify the mechanism with a search for how "airport" IONetworkRootType works and whether itlwm's Sonoma plist personality is required. Let me look at the itlwm git log/commit that added the "NetworkController" personality. I can check the local itlwm repo's git history (it has .git).
> 
> Let me search the local itlwm git log for "NetworkController" or "IONetworkRootType".
> 
> That's a good, concrete way to find the rationale.
> 
> Let me also check the project's existing docs for M4 to see if they already know about the "NetworkController" personality.
> 
> Let me batch.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/itlwm && git log --oneline --all -S "IONetworkRootType" -- . 2>/dev/null | head -10; echo "=== log for NetworkController ==="; git log --oneline --all -S "NetworkController" -- AirportItlwm/AirportItlwm-Sonoma-Info.plist 2>/dev/null | head -10; echo "=== any commit msgs mentioning airport/wifi menu ==="; git log --oneline --all --grep="Wi-Fi menu\\|wifi menu\\|airport\\|AirPort\\|NetworkController\\|root type"

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport && grep -rn "NetworkController\\|IONetworkRootType\\|WiFiDriver\\|IO80211FamilyLegacy\\|IOSkywalkFamily\\|Info.plist" docs/*.md | head -30; echo "=== project driver Info.plist ==="; cat src/driver/Info.plist'}

> **[reasoning]**
> Good. Now I have the project's current Info.plist (M1 only, an IOUSBHostInterface personality).
> 
> Now let me confirm the "NetworkController"/"airport" personality requirement. The local itlwm git log search for "IONetworkRootType" returned commit 738d4c6 "Fix TX aggregation queue validation for newer Intel firmware" — that's a squashed/shallow clone so the log is limited.
> 
> Let me check the itlwm upstream GitHub for the commit that added the `NetworkController` personality. Let me use the GitHub API to search commits in laobamac/itlwm.
> 
> Actually, more valuable: let me look at the itlwm upstream repo for the `AirportItlwm-Sonoma-Info.plist` and any doc explaining. Let me check the itlwm docs repo (OpenIntelWireless/itlwm has a `docs/` folder? or the gh-pages site).
> 
> Let me try fetching https://openintelwireless.github.io/itlwm/ again with a longer timeout, and also check the repo for a "docs" dir.
> 
> Actually, let me use the GitHub API to list laobamac/itlwm root.
> 
> Let me batch: API list of laobamac/itlwm + commits touching the Sonoma plist.
> 
> Actually — the most important remaining verification for D is:
> 1. Confirm `IOMatchCategory = WiFiDriver` + `IONetworkRootType = airport` is what makes the Wi-Fi menu show the interface.
> 2. Confirm a USB bus is acceptable.
> 
> For (1), the strongest evidence: itlwm ships the "NetworkController" personality with `IONetworkRootType=airport` only in the Monterey/Sonoma plists (the ones that support the native Wi-Fi menu), and NOT in the base plist. And AirPort-RTW (which also shows in the menu) does NOT use IONetworkRootType — hmm, that weakens the theory. AirPort-RTW's personality is a plain IOPCIDevice match with IOProbeScore 5000 and no IOMatchCategory.
> 
> Hmm. So how does AirPort-RTW appear in the menu but the "itlwm" (non-Airport) kext does not? Because AirPort-RTW is an IO80211Controller and the IO80211FamilyLegacy/Apple80211 machinery picks it up.
> 
> Let me think about the real mechanism:
> - `IO80211Controller` subclass published as an IONetworkController. `IONetworkFamily` creates the BSD interface.
> - The macOS Wi-Fi menu (CoreWLAN/CoreWiFi) enumerates interfaces via `SCNetworkConfiguration`/`AirPortUtil` and checks the network service's "Hardware" — for a Wi-Fi menu entry, the interface must be of type "airport" / have `IO80211Interface` in the interface's class hierarchy. CoreWLAN's `CWWiFiClient` looks for network interfaces whose BSD name is `enX` and whose `IOEthernetInterface` is an `IO80211Interface` (via `IO80211Controller`).
> - The "Apple wireless" split the brief mentions: Apple's own `AppleBCMWLANIO80211Interface` vs third-party `IO80211Interface` — both are IO80211Interface subclasses, so both work.
> 
> The `IONetworkRootType = airport` property: In `IONetworkFamily`, the `IONetworkRoot` matching uses `IONetworkRootType` to decide which "network root" class to instantiate. Apple's `IO80211Family` registers a network root with type "airport" (kIONetworkRootTypeAirport?). Hmm.
> 
> Actually, `IONetworkRootType` is a **personality** key in IOKitPersonalities: it tells the matching engine to match the driver to a **network root** rather than to a device. From Apple docs: "IONetworkRootType — Specifies the type of network root (e.g. 'Ethernet', 'AppleTalk', 'Wireless')" — the driver's `IOClass` is instantiated as the network root for that type. Hmm, and the `IOResourceMatch = IOBSD` means match the BSD network resource.
> 
> Hmm, in the itlwm Sonoma plist, the "NetworkController" personality has:
> - IOClass = AirportItlwm
> - IOMatchCategory = WiFiDriver
> - IONetworkRootType = airport
> - IOProviderClass = IOPCIEDeviceWrapper
> - IOResourceMatch = IOBSD
> - IOProbeScore = 70000
> 
> This is a *second* personality in addition to the plain device one. The `IOResourceMatch = IOBSD` + `IONetworkRootType = airport` is the IOKit "network root" personality used by `IO80211Family` to find candidate Wi-Fi drivers: the IO80211 family enumerates network roots of type "airport" and matches drivers against them.
> 
> I recall from the IOKit docs: "IONetworkRootType: ... The value is the type of the network root (e.g., 'AppleTalk', 'Ethernet'). Drivers can use this to be matched to a specific network root."
> 
> And in `IONetworkFamily`, `IONetworkRoot` objects are published with a `IONetworkRootType` property. `IO80211Family` (or `Apple80211`) creates an `IONetworkRoot` of type "airport" once it detects that a wireless controller exists, then matches drivers.
> 
> Hmm, honestly, I should present this carefully: the itlwm "NetworkController" personality with `IONetworkRootType=airport` + `IOResourceMatch=IOBSD` + `IOMatchCategory=WiFiDriver` is the *observed working recipe* in itlwm's Monterey/Sonoma builds, whereas the older "IO80211Family" builds didn't have it. And AirPort-RTW works with just a plain device personality + IO80211FamilyLegacy. I'll present both recipes and note the difference (AirPort-RTW's approach = publish an IO80211Controller; itlwm's = extra "NetworkController" root personality).
> 
> Let me verify the "IONetworkRootType" semantics with a quick search of Apple's IOKit docs. And also check whether `IO80211FamilyLegacy` is needed on macOS 15 (Sequoia).
> 
> Given the project is on macOS 15.8.1, and itlwm's README says "The `AirportItlwm-Sequoia` target supports macOS Sequoia 15.2 and later on x86_64 through the native Wi-Fi interface. It has been tested on macOS 15.8 (24H23)." — **that's EXACTLY the project's macOS version!** And "Use this kext only on Darwin 24.2.0–24.99.99."
> 
> So: the project should use itlwm's **AirportItlwm-Sequoia** target. Let me check if the local itlwm checkout has a Sequoia target. The README mentions "AirportItlwm-Sequoia" scheme. Let me check the xcodeproj and the local checkout for Sequoia plists.
> 
> Let me check. And let me also look for the OpenIntelWireless_itlwm (downloaded) for the Sequoia plist.
> 
> Let me batch.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/itlwm && ls AirportItlwm/ && git log --oneline -3 2>/dev/null; echo "=== xcodeproj schemes ==="; grep -o "AirportItlwm[A-Za-z-]*" itlwm.xcodeproj/project.pbxproj 2>/dev/null | sort -u | head -20; echo "=== Sequoia plist in downloaded OIW itlwm ==="; ls /private/tmp/opencode/src/OpenIntelWireless_itlwm/AirportItlwm/'}

> **[tool shell]** {'command': 'cd /private/tmp/opencode/src/OpenIntelWireless_itlwm && git log --oneline -5 2>/dev/null; echo "=== diff of plists ==="; for f in AirportItlwm/Info.plist AirportItlwm/AirportItlwm-Sonoma-Info.plist; do echo "--- $f"; ls -la $f 2>/dev/null; done; echo "=== search Sequoia ==="; grep -rn "Sequoia" --include="*.plist" --include="*.pbxproj" . 2>/dev/null | head -10'}

> **[reasoning]**
> The local itlwm checkout has the `AirportItlwm-Sequoia` scheme in the xcodeproj but no separate Sequoia plist (the Sequoia target presumably reuses the Sonoma plist but with different `__IO80211_TARGET` / deployment target). Let me check the pbxproj for the Sequoia target's INFOPLIST_FILE.
> 
> Let me grep the pbxproj for "Sequoia".
> 
> This is important for D: which plist to use on macOS 15.8.1 (Darwin 24.6).
> 
> Let me check.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/itlwm && grep -n "Sequoia" -B 5 -A 20 itlwm.xcodeproj/project.pbxproj | head -80'}

> **[reasoning]**
> Let me find the Sequoia build settings: `INFOPLIST_FILE`, `MACOSX_DEPLOYMENT_TARGET`, `__IO80211_TARGET`, `IO80211_FAMILY_TARGET`.
> 
> Let me grep for the Sequoia build config block.
> 
> Let me also grab the "Sonoma14.0" and "Sonoma14.4" plists since the project is on Sequoia.
> 
> Let me look at the full build config for Sequoia.

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/itlwm && awk \'/C9DEB043F00A4DCFAC3294DD/,/};/\' itlwm.xcodeproj/project.pbxproj | grep -n "INFOPLIST_FILE\\|DEPLOYMENT_TARGET\\|IO80211_TARGET\\|GCC_PREPROCESSOR\\|OTHER_CFLAGS\\|MACOSX_DEPLOYMENT" | head -30; echo "=== search Sequoia INFOPLIST ==="; grep -n "Sequoia" itlwm.xcodeproj/project.pbxproj | grep -i "plist\\|INFOPLIST" | head'}

> **[tool shell]** {'command': 'cd /Users/zekri/Downloads/hackintosh-skills-id/rtl8188eu-airport/upstream/itlwm && grep -n "INFOPLIST_FILE" itlwm.xcodeproj/project.pbxproj | sort -u | head -30'}

