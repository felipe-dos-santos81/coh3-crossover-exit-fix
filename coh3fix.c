/* version.dll shim: makes Company of Heroes 3 exit cleanly under Wine / CrossOver.
 *
 * Root cause (found with WINEDEBUG=+seh,warn+heap): during shutdown the game's main thread
 * dereferences objects it has already freed (RelicCoH3.exe+0x35D7BAE). On Windows that is
 * harmless because the process heap runs in low-fragmentation (LFH) mode, where a freed block
 * keeps its contents. Wine only turns LFH on per size class once ~4 MB of one size is live, so the
 * game's ~1 KB blocks are freed through the classic path, which stores free-list links in the
 * first 16 bytes of the block. The game then writes NULL through one of those links, zeroing a
 * free-list head of the process heap; the next thread to exit crashes in
 * ntdll LdrShutdownThread -> RtlFreeHeap while holding the loader lock ("Erro do Programa").
 *
 * Fix: at process start, push every LFH size class of the process heap over Wine's enable
 * threshold once. From then on frees leave user data alone, as on Windows.
 *
 * ponytail: relies on Wine's bin thresholds (dlls/ntdll/heap.c, bin_try_enable); if a future
 * Wine changes them, `selftest.exe` fails. The real fix is Windows-like LFH activation in Wine.
 */
#include <windows.h>

static void enable_lfh(HANDLE heap)
{
    /* Wine's LFH block sizes: 8 classes x 16 bins (BLOCK_BIN_SIZE). Sizes include the 8-byte header. */
    static const unsigned min[8] = {0, 0x100, 0x200, 0x400, 0x800, 0x1000, 0x2000, 0x4000};
    static void *p[0x400000 / 0x440 + 2];                       /* largest count: the 0x440 bin */

    for (int c = 0; c < 8; c++)
        for (int k = 1; k <= 16; k++) {
            unsigned size = min[c] + k * (c ? min[c] >> 4 : 16);
            unsigned n = size <= 0x400 ? 0x12 : 0x400000 / size + 2, i;  /* just over the live-block threshold */
            for (i = 0; i < n; i++)
                if (!(p[i] = HeapAlloc(heap, 0, size - 8))) break;
            while (i--) HeapFree(heap, 0, p[i]);
        }
}

#ifndef SELFTEST

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, void *reserved)
{
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(inst);
        enable_lfh(GetProcessHeap());
    }
    return TRUE;
}

/* VerInstallFileA/W are the only version.dll exports kernelbase does not provide; nothing in a game calls them. */
DWORD WINAPI ver_install_stub(void) { return 0x10000; /* VIF_CANNOTREADSRC */ }

#else /* selftest.exe: the property the fix relies on, checked inside the bottle */

#include <stdio.h>

/* 1 if a freed block still holds its first 16 bytes (deliberately reads freed memory) */
static int free_keeps_data(HANDLE heap, SIZE_T size)
{
    volatile unsigned char *p = HeapAlloc(heap, 0, size);
    void *neighbour = HeapAlloc(heap, 0, size);  /* keeps p's pages committed after the free */
    int ok = 1;
    for (int i = 0; i < 16; i++) p[i] = 0xAA;
    HeapFree(heap, 0, (void *)p);
    for (int i = 0; i < 16; i++) ok &= p[i] == 0xAA;
    HeapFree(heap, 0, neighbour);
    return ok;
}

int main(void)
{
    static const SIZE_T sizes[] = {0x58, 0x418, 0x428, 0xff8, 0x6ff8};
    HANDLE heap = GetProcessHeap();
    int before = free_keeps_data(heap, 0x418), after = 1;

    enable_lfh(heap);
    for (int i = 0; i < 5; i++) after &= free_keeps_data(heap, sizes[i]);
    printf("freed block keeps its data: before=%d after=%d -> %s\n", before, after, after ? "PASS" : "FAIL");
    return !after;
}

#endif
