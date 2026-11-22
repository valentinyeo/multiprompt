#ifndef MP_TERMINAL_MODEL_H
#define MP_TERMINAL_MODEL_H
#include <stddef.h>
#include <stdint.h>

typedef struct MPTerminal MPTerminal;
typedef void (*MPTerminalOutput)(const char *, size_t, void *);
typedef struct {
    uint32_t chars[6];
    uint32_t foreground;
    uint32_t background;
    uint32_t attributes;
    int width;
} MPTerminalCell;

MPTerminal *mp_terminal_new(int, int, MPTerminalOutput, void *);
void mp_terminal_free(MPTerminal *);
void mp_terminal_feed(MPTerminal *, const char *, size_t);
void mp_terminal_size(MPTerminal *, int, int);
void mp_terminal_palette(MPTerminal *, uint32_t, uint32_t, const uint32_t *);
int mp_terminal_cell(MPTerminal *, int, int, int, MPTerminalCell *);
int mp_terminal_history(MPTerminal *);
int mp_terminal_mouse_mode(MPTerminal *);
int mp_terminal_cursor(MPTerminal *, int *, int *);
void mp_terminal_key(MPTerminal *, int, int);
void mp_terminal_char(MPTerminal *, uint32_t, int);
void mp_terminal_paste(MPTerminal *, int);
void mp_terminal_mouse(MPTerminal *, int, int, int, int, int);
#endif
