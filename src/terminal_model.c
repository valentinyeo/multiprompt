#include "terminal_model.h"
#include "vterm.h"
#include <stdlib.h>
#include <string.h>

#define HISTORY_LINES 512

struct MPTerminal {
    VTerm *terminal;
    VTermScreen *screen;
    VTermScreenCell *history[HISTORY_LINES];
    int lengths[HISTORY_LINES];
    int first;
    int count;
    int rows;
    int cols;
    int cursor_visible;
    int mouse_mode;
    int alternate;
};

static int clear_history(void *user) {
    MPTerminal *t = user;
    for (int i = 0; i < t->count; i++) free(t->history[(t->first + i) % HISTORY_LINES]);
    t->count = 0;
    t->first = 0;
    return 1;
}

static int push_line(int cols, const VTermScreenCell *cells, void *user) {
    MPTerminal *t = user;
    VTermScreenCell *copy = malloc((size_t)cols * sizeof(*copy));
    if (!copy) return 0;
    memcpy(copy, cells, (size_t)cols * sizeof(*copy));
    if (t->count == HISTORY_LINES) {
        free(t->history[t->first]);
        t->first = (t->first + 1) % HISTORY_LINES;
        t->count--;
    }
    int i = (t->first + t->count++) % HISTORY_LINES;
    t->history[i] = copy;
    t->lengths[i] = cols;
    return 1;
}

static int pop_line(int cols, VTermScreenCell *cells, void *user) {
    MPTerminal *t = user;
    if (!t->count) return 0;
    int i = (t->first + --t->count) % HISTORY_LINES;
    memset(cells, 0, (size_t)cols * sizeof(*cells));
    for (int x = 0; x < cols; x++) {
        cells[x].width = 1;
        vterm_state_get_default_colors(vterm_obtain_state(t->terminal), &cells[x].fg, &cells[x].bg);
    }
    int copy = cols < t->lengths[i] ? cols : t->lengths[i];
    memcpy(cells, t->history[i], (size_t)copy * sizeof(*cells));
    free(t->history[i]);
    return 1;
}

static int property(VTermProp prop, VTermValue *value, void *user) {
    MPTerminal *t = user;
    if (prop == VTERM_PROP_CURSORVISIBLE) t->cursor_visible = value->boolean;
    if (prop == VTERM_PROP_MOUSE) t->mouse_mode = value->number;
    if (prop == VTERM_PROP_ALTSCREEN) t->alternate = value->boolean;
    return 1;
}

static const VTermScreenCallbacks callbacks = {
    .settermprop = property,
    .sb_pushline = push_line,
    .sb_popline = pop_line,
    .sb_clear = clear_history,
};

MPTerminal *mp_terminal_new(int rows, int cols, MPTerminalOutput output, void *user) {
    if (rows < 1 || rows > 512 || cols < 1 || cols > 1024) return NULL;
    MPTerminal *t = calloc(1, sizeof(*t));
    if (!t) return NULL;
    t->terminal = vterm_new(rows, cols);
    t->rows = rows;
    t->cols = cols;
    t->cursor_visible = 1;
    vterm_set_utf8(t->terminal, 1);
    vterm_output_set_callback(t->terminal, output, user);
    t->screen = vterm_obtain_screen(t->terminal);
    vterm_screen_set_callbacks(t->screen, &callbacks, t);
    vterm_screen_enable_altscreen(t->screen, 1);
    vterm_screen_set_damage_merge(t->screen, VTERM_DAMAGE_SCREEN);
    vterm_screen_reset(t->screen, 1);
    return t;
}

void mp_terminal_free(MPTerminal *t) {
    if (!t) return;
    clear_history(t);
    vterm_free(t->terminal);
    free(t);
}

void mp_terminal_feed(MPTerminal *t, const char *bytes, size_t length) {
    vterm_input_write(t->terminal, bytes, length);
    vterm_screen_flush_damage(t->screen);
}

void mp_terminal_size(MPTerminal *t, int rows, int cols) {
    if (rows < 1 || rows > 512 || cols < 1 || cols > 1024) return;
    t->rows = rows;
    t->cols = cols;
    vterm_set_size(t->terminal, rows, cols);
    vterm_screen_flush_damage(t->screen);
}

static VTermColor color(uint32_t value) {
    VTermColor result;
    vterm_color_rgb(&result, value & 255, (value >> 8) & 255, (value >> 16) & 255);
    return result;
}

void mp_terminal_palette(MPTerminal *t, uint32_t foreground, uint32_t background, const uint32_t *palette) {
    VTermState *state = vterm_obtain_state(t->terminal);
    VTermColor fg = color(foreground), bg = color(background);
    vterm_state_set_default_colors(state, &fg, &bg);
    if (palette) for (int i = 0; i < 16; i++) {
        VTermColor entry = color(palette[i]);
        vterm_state_set_palette_color(state, i, &entry);
    }
}

static uint32_t rgb(MPTerminal *t, VTermColor value) {
    vterm_screen_convert_color_to_rgb(t->screen, &value);
    return value.rgb.red | ((uint32_t)value.rgb.green << 8) | ((uint32_t)value.rgb.blue << 16);
}

int mp_terminal_cell(MPTerminal *t, int row, int col, int scroll, MPTerminalCell *out) {
    if (row < 0 || row >= t->rows || col < 0 || col >= t->cols) return 0;
    if (t->alternate) scroll = 0;
    if (scroll < 0) scroll = 0;
    if (scroll > t->count) scroll = t->count;
    row -= scroll;
    VTermScreenCell cell;
    if (row < 0) {
        int i = (t->first + t->count + row) % HISTORY_LINES;
        if (col >= t->lengths[i]) {
            memset(&cell, 0, sizeof(cell));
            cell.width = 1;
            vterm_state_get_default_colors(vterm_obtain_state(t->terminal), &cell.fg, &cell.bg);
        } else cell = t->history[i][col];
    } else if (!vterm_screen_get_cell(t->screen, (VTermPos){row, col}, &cell)) return 0;
    memcpy(out->chars, cell.chars, sizeof(out->chars));
    out->foreground = rgb(t, cell.attrs.reverse ? cell.bg : cell.fg);
    out->background = rgb(t, cell.attrs.reverse ? cell.fg : cell.bg);
    out->attributes = (cell.attrs.bold ? 1 : 0) | (cell.attrs.italic ? 2 : 0) | (cell.attrs.underline ? 4 : 0) |
                      (cell.attrs.strike ? 8 : 0) | (cell.attrs.conceal ? 16 : 0);
    out->width = cell.width;
    return 1;
}

int mp_terminal_history(MPTerminal *t) { return t->alternate ? 0 : t->count; }
int mp_terminal_mouse_mode(MPTerminal *t) { return t->mouse_mode; }

int mp_terminal_cursor(MPTerminal *t, int *row, int *col) {
    VTermPos position;
    vterm_state_get_cursorpos(vterm_obtain_state(t->terminal), &position);
    *row = position.row;
    *col = position.col;
    return t->cursor_visible;
}

void mp_terminal_key(MPTerminal *t, int key, int modifiers) {
    if (key <= VTERM_KEY_NONE || key >= VTERM_KEY_MAX) return;
    vterm_keyboard_key(t->terminal, (VTermKey)key, (VTermModifier)(modifiers & VTERM_ALL_MODS_MASK));
}

void mp_terminal_char(MPTerminal *t, uint32_t value, int modifiers) {
    if (value > 0x10ffff || (value >= 0xd800 && value <= 0xdfff)) value = 0xfffd;
    vterm_keyboard_unichar(t->terminal, value, (VTermModifier)(modifiers & VTERM_ALL_MODS_MASK));
}

void mp_terminal_paste(MPTerminal *t, int begin) {
    if (begin) vterm_keyboard_start_paste(t->terminal); else vterm_keyboard_end_paste(t->terminal);
}

void mp_terminal_mouse(MPTerminal *t, int row, int col, int button, int pressed, int modifiers) {
    VTermModifier mod = (VTermModifier)(modifiers & VTERM_ALL_MODS_MASK);
    vterm_mouse_move(t->terminal, row, col, mod);
    if (button) vterm_mouse_button(t->terminal, button, pressed != 0, mod);
}
