#!/bin/zsh
# Kept so `./install.sh` and `./install.sh uninstall` still work; the Makefile is the source of truth.
exec make -C "${0:A:h}" "${1:-install}"
