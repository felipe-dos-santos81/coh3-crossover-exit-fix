# Makefile for CoH3 CrossOver Exit Fix — version.dll heap shim for Company of Heroes 3
# Stages: 1 build → 2 test → 3 install (uninstall reverts 3)
SERVICE = CoH3 CrossOver Exit Fix

# Variables
bottle ?= Steam
CC = x86_64-w64-mingw32-gcc
CFLAGS = -O2 -Wall
WINE = /Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine --bottle "$(bottle)" --no-update
GAME_DIR = $$HOME/Library/Application Support/CrossOver/Bottles/$(bottle)/drive_c/Program Files (x86)/Steam/steamapps/common/Company of Heroes 3
# Per-game override: only RelicCoH3.exe loads the shim.
REG_KEY = HKCU\Software\Wine\AppDefaults\RelicCoH3.exe\DllOverrides

.PHONY: help build test install uninstall clean

help: ## Print this help message
	@printf '\033[01;32m${SERVICE}\033[00;37m\n\n'
	@printf "\033[33mUsage:\033[0m\n  make [target] [bottle=Steam]\n\n\033[33mTargets:\033[0m\n"
	@grep -E '^[-a-zA-Z0-9_\.\/]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; \
		{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

# ── Stage 1 · Build ──────────────────────────────────────────────────────────

version.dll: coh3fix.c version.def
	$(CC) $(CFLAGS) -shared -nostdlib -e DllMain -o $@ coh3fix.c version.def -lkernel32

selftest.exe: coh3fix.c
	$(CC) $(CFLAGS) -DSELFTEST -o $@ coh3fix.c

build: version.dll selftest.exe ## [STEP 1] Build version.dll and selftest.exe (needs mingw-w64)

# ── Stage 2 · Test ───────────────────────────────────────────────────────────

test: selftest.exe ## [STEP 2] Run the self-test inside the bottle
	@$(WINE) "$(CURDIR)/selftest.exe" 2>/dev/null | tr -d '\r' | tee /dev/stderr | grep -q PASS

# ── Stage 3 · Install ────────────────────────────────────────────────────────

install: version.dll test ## [STEP 3] Install the shim for the game
	@! pgrep -qf 'RelicCoH3[.]exe' || { echo "Quit Company of Heroes 3 first."; exit 1; }
	cp version.dll "$(GAME_DIR)/version.dll"
	$(WINE) reg add '$(REG_KEY)' /v version /t REG_SZ /d native,builtin /f >/dev/null 2>&1
	@echo "Installed: $(GAME_DIR)/version.dll"

uninstall: ## Remove the shim and its override
	rm -f "$(GAME_DIR)/version.dll"
	-$(WINE) reg delete '$(REG_KEY)' /v version /f >/dev/null 2>&1
	@echo "Uninstalled."

clean: ## Remove built files (keeps the installed copy)
	rm -f version.dll selftest.exe
