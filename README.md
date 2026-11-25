# CoH3 CrossOver Exit Fix

Stops Company of Heroes 3 from crashing on exit when it runs in a CrossOver (Wine) bottle on macOS.

Without the fix, quitting the game ends with CrossOver's "Program Error" dialog ("RelicCoH3.exe has encountered a serious problem and needs to close"), or occasionally a hang.

## Requirements

- CrossOver with Company of Heroes 3 installed through Steam in a bottle (default name: `Steam`)
- mingw-w64: `brew install mingw-w64`

## Usage

```sh
make install     # build, self-test inside the bottle, install
make uninstall   # remove the fix
make help        # list all targets
```

Quit the game before installing. For a bottle with another name, add `bottle=<name>`.

## Why the game crashes

1. While shutting down, the game reads and writes objects it has already freed.
2. On Windows this goes unnoticed: the heap leaves the contents of a freed block alone.
3. Wine's heap stores its free-list links in the first 16 bytes of a freed block. The game writes a NULL through one of those links and corrupts the process heap.
4. The next thread to exit crashes in `ntdll` (`LdrShutdownThread` → `RtlFreeHeap`).

## How the fix works

Wine has a Windows-like heap mode (the low-fragmentation heap) that keeps freed blocks intact, but it only turns on for a block size after heavy use of that size.
The fix is a small `version.dll` that the game loads at startup. It allocates and frees enough blocks of every size class to switch that mode on for the whole run.

`make install` makes two changes, both limited to this game:

- copies `version.dll` into the game folder
- sets `version=native,builtin` under `HKCU\Software\Wine\AppDefaults\RelicCoH3.exe\DllOverrides`

The game executable and CrossOver itself are not modified.

## If the crash comes back

Run `make install` again. This covers a CrossOver upgrade or a Steam "verify files" that removed the DLL.

If the self-test prints `FAIL`, Wine's heap thresholds have changed and `enable_lfh()` in `coh3fix.c` needs updating to match `bin_try_enable()` in Wine's `dlls/ntdll/heap.c`.

## Tested with

- CrossOver 26.3 (Wine 11.0), D3DMetal, macOS on Apple silicon
- Company of Heroes 3 version 3.0.3.52650
- Launch → main menu → quit: 6 of 6 clean exits with the fix, 0 of 6 without

Quitting after a played mission uses the same shutdown code but was not tested separately.

## Files

| File | Purpose |
|---|---|
| `coh3fix.c` | The shim and its self-test |
| `version.def` | Forwards the real `version.dll` API to `kernelbase` |
| `Makefile` | Build, test, install, uninstall |
| `install.sh` | Wrapper around `make install`, kept for convenience |
