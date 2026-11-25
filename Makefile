# Makefile for CoH3 CrossOver Exit Fix — version.dll heap shim for Company of Heroes 3
# Targets are numbered by pipeline stage:
#   1 build → 2 test → 3 install        (uninstall reverts stage 3)
# Needs: brew install mingw-w64
SERVICE = CoH3 CrossOver Exit Fix

# Variables
bottle ?= Steam
CC = x86_64-w64-mingw32-gcc
CFLAGS = -O2 -Wall
WINE = /Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine --bottle "$(bottle)" --no-update
GAME_DIR = $$HOME/Library/Application Support/CrossOver/Bottles/$(bottle)/drive_c/Program Files (x86)/Steam/steamapps/common/Company of Heroes 3
# Only RelicCoH3.exe loads the shim; every other program in the bottle keeps Wine's own version.dll.
REG_KEY = HKCU\Software\Wine\AppDefaults\RelicCoH3.exe\DllOverrides

.PHONY: help build test install uninstall clean

# ── Environment ──────────────────────────────────────────────────────────────

help: ## Print this help message
	@printf '\033[01;32m${SERVICE} — version.dll heap shim\033[00;37m\n\n'
	@printf "\033[33mUsage:\033[0m\n  make [target] [arg=\"val\"...]\n\n\033[33mTargets:\033[0m\n"
	@grep -E '^[-a-zA-Z0-9_\.\/]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; \
		{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

clean: ## Remove the built version.dll and selftest.exe (does not touch the installed copy)
	rm -f version.dll selftest.exe
	@echo "Cleanup complete."

# ── Stage 1 · Build (mingw-w64 → version.dll + selftest.exe) ─────────────────

version.dll: coh3fix.c version.def
	$(CC) $(CFLAGS) -shared -nostdlib -e DllMain -o $@ coh3fix.c version.def -lkernel32

selftest.exe: coh3fix.c
	$(CC) $(CFLAGS) -DSELFTEST -o $@ coh3fix.c

build: version.dll selftest.exe ## [STEP 1] Cross-compile the shim DLL and its self-test

# ── Stage 2 · Self-test (inside the bottle) ──────────────────────────────────

# A FAIL means Wine's heap thresholds changed and enable_lfh() in coh3fix.c needs updating.
test: selftest.exe ## [STEP 2] Check inside the bottle that freed blocks keep their data (usage: make test [bottle=Steam])
	@echo "Running self-test in bottle $(bottle)..."
	@$(WINE) "$(CURDIR)/selftest.exe" 2>/dev/null | tr -d '\r' | tee /dev/stderr | grep -q PASS

# ── Stage 3 · Install / uninstall (game folder + per-game DLL override) ──────

install: version.dll test ## [STEP 3] Copy version.dll into the game folder and set the per-game override (usage: make install [bottle=Steam])
	@! pgrep -qf 'RelicCoH3[.]exe' || { echo "Quit Company of Heroes 3 first."; exit 1; }
	cp version.dll "$(GAME_DIR)/version.dll"
	$(WINE) reg add '$(REG_KEY)' /v version /t REG_SZ /d native,builtin /f >/dev/null 2>&1
	@echo "Installed: $(GAME_DIR)/version.dll"

uninstall: ## Remove version.dll from the game folder and delete the per-game override
	rm -f "$(GAME_DIR)/version.dll"
	-$(WINE) reg delete '$(REG_KEY)' /v version /f >/dev/null 2>&1
	@echo "Uninstalled."
