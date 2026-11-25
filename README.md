# CoH3 CrossOver Exit Fix

Stops Company of Heroes 3 from crashing on exit in a CrossOver bottle on macOS.

Without it, quitting the game ends in CrossOver's "Program Error" dialog, or occasionally a hang.

## Install

Needs `brew install mingw-w64` and the game installed through Steam in a CrossOver bottle. Quit the game first.

```sh
make install     # build, self-test in the bottle, install
make uninstall   # remove the fix
make help        # list all targets
```

The bottle defaults to `Steam`; use `bottle=<name>` for another one.

## Cause

While shutting down, the game writes to memory it has already freed.
Windows leaves a freed block's contents alone, so nothing happens there.
Wine keeps heap bookkeeping in the first 16 bytes of a freed block, so the write corrupts the heap and the next thread to exit crashes in `ntdll` (`LdrShutdownThread` → `RtlFreeHeap`).

## Fix

A small `version.dll` switches Wine's heap to its Windows-like mode (the low-fragmentation heap) at startup, so freed blocks stay intact.

`make install` changes two things, both limited to this game:

- copies `version.dll` into the game folder
- sets `version=native,builtin` under `HKCU\Software\Wine\AppDefaults\RelicCoH3.exe\DllOverrides`

The game executable and CrossOver are not modified.

## If the crash comes back

Run `make install` again, for example after a CrossOver upgrade or a Steam "verify files".

If the self-test prints `FAIL`, Wine's heap thresholds changed: update `enable_lfh()` in `coh3fix.c` to match `bin_try_enable()` in Wine's `dlls/ntdll/heap.c`.

## Tested with

CrossOver 26.3 (Wine 11.0, D3DMetal) on Apple silicon, game version 3.0.3.52650.
Launch → main menu → quit gave 6 of 6 clean exits with the fix and 0 of 6 without.
Quitting after a played mission was not tested separately.
