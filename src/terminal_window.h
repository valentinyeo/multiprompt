#ifndef MP_TERMINAL_WINDOW_H
#define MP_TERMINAL_WINDOW_H
#include <windows.h>
#include "terminal_model.h"

typedef void (*MPTerminalResize)(int, int, void *);
HWND mp_terminal_window_new(HWND, const LOGFONTW *, uint32_t, uint32_t, const uint32_t *, MPTerminalOutput, MPTerminalResize, void *);
void mp_terminal_window_feed(HWND, const char *, size_t);
void mp_terminal_window_style(HWND, const LOGFONTW *, uint32_t, uint32_t, const uint32_t *);
int mp_terminal_window_copy(HWND);
void mp_terminal_window_paste(HWND);
#endif
