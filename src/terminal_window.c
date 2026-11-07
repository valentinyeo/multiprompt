#include "terminal_window.h"
#include "vterm_keycodes.h"
#include <windowsx.h>
#include <stdlib.h>
#include <string.h>

#define CLASS_NAME L"MPTerminal"

typedef struct {
    HWND hwnd;
    MPTerminal *model;
    MPTerminalResize resize;
    void *user;
    HFONT fonts[16];
    int width, height, rows, cols, scroll, wheel;
    int anchor, end, selecting, selected;
    WCHAR surrogate;
    uint32_t background;
} TerminalWindow;

typedef struct { TerminalWindow *window; int attached; } Creation;

static TerminalWindow *get(HWND hwnd) { return (TerminalWindow *)GetWindowLongPtrW(hwnd, GWLP_USERDATA); }
static int clamp(int value, int lo, int hi) { return value < lo ? lo : value > hi ? hi : value; }

static int modifiers(void) {
    int result = 0;
    if (GetKeyState(VK_SHIFT) < 0) result |= VTERM_MOD_SHIFT;
    if (GetKeyState(VK_MENU) < 0) result |= VTERM_MOD_ALT;
    if (GetKeyState(VK_CONTROL) < 0) result |= VTERM_MOD_CTRL;
    if (GetKeyState(VK_RMENU) < 0) result &= ~(VTERM_MOD_ALT | VTERM_MOD_CTRL);
    return result;
}

static int utf16(uint32_t cp, WCHAR *out) {
    if (cp > 0x10ffff || (cp >= 0xd800 && cp <= 0xdfff)) cp = 0xfffd;
    if (cp < 0x10000) { out[0] = (WCHAR)cp; return 1; }
    cp -= 0x10000;
    out[0] = (WCHAR)(0xd800 + (cp >> 10));
    out[1] = (WCHAR)(0xdc00 + (cp & 1023));
    return 2;
}

static void caret(TerminalWindow *t) {
    if (GetFocus() != t->hwnd) return;
    int row, col;
    int visible = mp_terminal_cursor(t->model, &row, &col) && !t->scroll;
    DestroyCaret();
    if (visible && CreateCaret(t->hwnd, NULL, t->width, t->height)) {
        SetCaretPos(col * t->width, row * t->height);
        ShowCaret(t->hwnd);
    }
}

static void resize(TerminalWindow *t) {
    if (!t->fonts[0]) return;
    RECT rect;
    GetClientRect(t->hwnd, &rect);
    if (rect.right <= 0 || rect.bottom <= 0) return;
    int rows = clamp(rect.bottom / t->height, 1, 512);
    int cols = clamp(rect.right / t->width, 1, 1024);
    if (rows != t->rows || cols != t->cols) {
        t->rows = rows;
        t->cols = cols;
        t->selected = t->selecting = 0;
        mp_terminal_size(t->model, rows, cols);
        if (t->resize) t->resize(rows, cols, t->user);
    }
    t->scroll = clamp(t->scroll, 0, mp_terminal_history(t->model));
    caret(t);
    InvalidateRect(t->hwnd, NULL, FALSE);
}

void mp_terminal_window_style(HWND hwnd, const LOGFONTW *font, uint32_t fg, uint32_t bg, const uint32_t *palette) {
    TerminalWindow *t = get(hwnd);
    if (!t || !font) return;
    HFONT fonts[16] = {0};
    for (int i = 0; i < 16; i++) {
        LOGFONTW lf = *font;
        if (i & 1) lf.lfWeight = FW_BOLD;
        if (i & 2) lf.lfItalic = TRUE;
        if (i & 4) lf.lfUnderline = TRUE;
        if (i & 8) lf.lfStrikeOut = TRUE;
        fonts[i] = CreateFontIndirectW(&lf);
        if (!fonts[i]) {
            for (int j = 0; j < i; j++) DeleteObject(fonts[j]);
            return;
        }
    }
    for (int i = 0; i < 16; i++) {
        if (t->fonts[i]) DeleteObject(t->fonts[i]);
        t->fonts[i] = fonts[i];
    }
    HDC dc = GetDC(hwnd);
    HGDIOBJ old = SelectObject(dc, t->fonts[0]);
    TEXTMETRICW metrics;
    GetTextMetricsW(dc, &metrics);
    t->width = metrics.tmAveCharWidth > 0 ? metrics.tmAveCharWidth : 1;
    t->height = metrics.tmHeight > 0 ? metrics.tmHeight : 1;
    SelectObject(dc, old);
    ReleaseDC(hwnd, dc);
    t->background = bg;
    mp_terminal_palette(t->model, fg, bg, palette);
    resize(t);
}

static void paint(TerminalWindow *t, HDC target, const RECT *damage) {
    RECT client;
    GetClientRect(t->hwnd, &client);
    HDC dc = CreateCompatibleDC(target);
    HBITMAP bitmap = CreateCompatibleBitmap(target, client.right > 0 ? client.right : 1, client.bottom > 0 ? client.bottom : 1);
    if (!dc || !bitmap) {
        if (dc) DeleteDC(dc);
        if (bitmap) DeleteObject(bitmap);
        return;
    }
    HGDIOBJ old_bitmap = SelectObject(dc, bitmap);
    HGDIOBJ old_font = SelectObject(dc, t->fonts[0]);
    SetBkColor(dc, t->background);
    ExtTextOutW(dc, 0, 0, ETO_OPAQUE, &client, NULL, 0, NULL);
    int lo = t->anchor < t->end ? t->anchor : t->end;
    int hi = t->anchor > t->end ? t->anchor : t->end;
    for (int pass = 0; pass < 2; pass++) for (int row = 0; row < t->rows; row++) for (int col = 0; col < t->cols; col++) {
        MPTerminalCell cell;
        if (!mp_terminal_cell(t->model, row, col, t->scroll, &cell)) continue;
        int index = row * t->cols + col;
        int selected = t->selected && index >= lo && index <= hi;
        COLORREF fg = selected ? cell.background : cell.foreground;
        COLORREF bg = selected ? cell.foreground : cell.background;
        RECT rect = {col * t->width, row * t->height, (col + 1) * t->width, (row + 1) * t->height};
        if (!pass) {
            SetBkColor(dc, bg);
            ExtTextOutW(dc, rect.left, rect.top, ETO_OPAQUE, &rect, NULL, 0, NULL);
            continue;
        }
        if ((cell.attributes & 16) || !cell.chars[0] || cell.chars[0] == UINT32_MAX) continue;
        WCHAR text[12];
        int length = 0;
        for (int i = 0; i < 6 && cell.chars[i]; i++) length += utf16(cell.chars[i], text + length);
        rect.right = (col + (cell.width > 0 ? cell.width : 1)) * t->width;
        SetTextColor(dc, fg);
        SetBkMode(dc, TRANSPARENT);
        SelectObject(dc, t->fonts[cell.attributes & 15]);
        ExtTextOutW(dc, rect.left, rect.top, ETO_CLIPPED, &rect, text, length, NULL);
    }
    BitBlt(target, damage->left, damage->top, damage->right - damage->left, damage->bottom - damage->top, dc, damage->left, damage->top, SRCCOPY);
    SelectObject(dc, old_font);
    SelectObject(dc, old_bitmap);
    DeleteObject(bitmap);
    DeleteDC(dc);
}

void mp_terminal_window_feed(HWND hwnd, const char *bytes, size_t length) {
    TerminalWindow *t = get(hwnd);
    if (!t) return;
    mp_terminal_feed(t->model, bytes, length);
    t->scroll = clamp(t->scroll, 0, mp_terminal_history(t->model));
    caret(t);
    InvalidateRect(hwnd, NULL, FALSE);
}

static void input(TerminalWindow *t, uint32_t value, int mod) {
    t->selected = t->selecting = t->scroll = 0;
    mp_terminal_char(t->model, value, mod);
    caret(t);
    InvalidateRect(t->hwnd, NULL, FALSE);
}

static void character(TerminalWindow *t, WCHAR value, int mod) {
    if (t->surrogate) {
        WCHAR high = t->surrogate;
        t->surrogate = 0;
        if (value >= 0xdc00 && value <= 0xdfff) {
            input(t, 0x10000 + ((high - 0xd800) << 10) + value - 0xdc00, mod);
            return;
        }
        input(t, 0xfffd, mod);
    }
    if (value >= 0xd800 && value <= 0xdbff) t->surrogate = value;
    else input(t, value, mod);
}

int mp_terminal_window_copy(HWND hwnd) {
    TerminalWindow *t = get(hwnd);
    if (!t || !t->selected) return 0;
    int lo = t->anchor < t->end ? t->anchor : t->end;
    int hi = t->anchor > t->end ? t->anchor : t->end;
    size_t capacity = ((size_t)(hi - lo + 1) * 12 + (size_t)t->rows * 2 + 1) * sizeof(WCHAR);
    HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, capacity);
    if (!memory) return 0;
    WCHAR *text = GlobalLock(memory);
    if (!text) { GlobalFree(memory); return 0; }
    size_t used = 0, row_start = 0;
    for (int i = lo; i <= hi; i++) {
        MPTerminalCell cell;
        if (mp_terminal_cell(t->model, i / t->cols, i % t->cols, t->scroll, &cell) && cell.chars[0] != UINT32_MAX) {
            if (!cell.chars[0]) text[used++] = L' ';
            else for (int j = 0; j < 6 && cell.chars[j]; j++) used += utf16(cell.chars[j], text + used);
        }
        if (i % t->cols == t->cols - 1 && i < hi) {
            while (used > row_start && text[used - 1] == L' ') used--;
            text[used++] = L'\r'; text[used++] = L'\n';
            row_start = used;
        }
    }
    text[used] = 0;
    GlobalUnlock(memory);
    int copied = 0;
    if (OpenClipboard(hwnd)) {
        if (EmptyClipboard() && SetClipboardData(CF_UNICODETEXT, memory)) {
            memory = NULL;
            copied = 1;
        }
        CloseClipboard();
    }
    if (memory) GlobalFree(memory);
    return copied;
}

void mp_terminal_window_paste(HWND hwnd) {
    TerminalWindow *t = get(hwnd);
    if (!t || !OpenClipboard(hwnd)) return;
    HANDLE memory = GetClipboardData(CF_UNICODETEXT);
    const WCHAR *text = memory ? GlobalLock(memory) : NULL;
    size_t count = memory ? GlobalSize(memory) / sizeof(WCHAR) : 0;
    if (text) {
        mp_terminal_paste(t->model, 1);
        for (size_t i = 0; i < count && text[i]; i++) {
            WCHAR value = text[i];
            if (value == L'\r' && i + 1 < count && text[i + 1] == L'\n') i++;
            character(t, value, 0);
        }
        if (t->surrogate) { t->surrogate = 0; input(t, 0xfffd, 0); }
        mp_terminal_paste(t->model, 0);
        GlobalUnlock(memory);
    }
    CloseClipboard();
}

static int key(WPARAM value) {
    switch (value) {
        case VK_RETURN: return VTERM_KEY_ENTER;
        case VK_TAB: return VTERM_KEY_TAB;
        case VK_BACK: return VTERM_KEY_BACKSPACE;
        case VK_ESCAPE: return VTERM_KEY_ESCAPE;
        case VK_UP: return VTERM_KEY_UP;
        case VK_DOWN: return VTERM_KEY_DOWN;
        case VK_LEFT: return VTERM_KEY_LEFT;
        case VK_RIGHT: return VTERM_KEY_RIGHT;
        case VK_INSERT: return VTERM_KEY_INS;
        case VK_DELETE: return VTERM_KEY_DEL;
        case VK_HOME: return VTERM_KEY_HOME;
        case VK_END: return VTERM_KEY_END;
        case VK_PRIOR: return VTERM_KEY_PAGEUP;
        case VK_NEXT: return VTERM_KEY_PAGEDOWN;
        default: return value >= VK_F1 && value <= VK_F24 ? VTERM_KEY_FUNCTION((int)value - VK_F1 + 1) : 0;
    }
}

static int point(TerminalWindow *t, LPARAM lparam) {
    int row = clamp(GET_Y_LPARAM(lparam) / t->height, 0, t->rows - 1);
    int col = clamp(GET_X_LPARAM(lparam) / t->width, 0, t->cols - 1);
    return row * t->cols + col;
}

static LRESULT CALLBACK procedure(HWND hwnd, UINT message, WPARAM wp, LPARAM lp) {
    TerminalWindow *t = get(hwnd);
    if (message == WM_NCCREATE) {
        Creation *creation = ((CREATESTRUCTW *)lp)->lpCreateParams;
        t = creation->window;
        creation->attached = 1;
        t->hwnd = hwnd;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)t);
    }
    if (!t) return DefWindowProcW(hwnd, message, wp, lp);
    switch (message) {
        case WM_ERASEBKGND: return 1;
        case WM_PAINT: {
            PAINTSTRUCT ps;
            HDC dc = BeginPaint(hwnd, &ps);
            paint(t, dc, &ps.rcPaint);
            EndPaint(hwnd, &ps);
            return 0;
        }
        case WM_PRINTCLIENT: {
            RECT rect;
            GetClientRect(hwnd, &rect);
            paint(t, (HDC)wp, &rect);
            return 0;
        }
        case WM_SIZE: resize(t); return 0;
        case WM_GETDLGCODE: return DLGC_WANTALLKEYS | DLGC_WANTCHARS;
        case WM_SETFOCUS: caret(t); return 0;
        case WM_KILLFOCUS: t->surrogate = 0; DestroyCaret(); return 0;
        case WM_KEYDOWN: case WM_SYSKEYDOWN: {
            int mod = modifiers();
            if ((mod & (VTERM_MOD_CTRL | VTERM_MOD_SHIFT)) == (VTERM_MOD_CTRL | VTERM_MOD_SHIFT) && (wp == 'C' || wp == 'V')) {
                if (wp == 'C') mp_terminal_window_copy(hwnd); else mp_terminal_window_paste(hwnd);
                return 0;
            }
            if ((mod & VTERM_MOD_SHIFT) && (wp == VK_PRIOR || wp == VK_NEXT)) {
                t->scroll = clamp(t->scroll + (wp == VK_PRIOR ? t->rows : -t->rows), 0, mp_terminal_history(t->model));
                t->selected = 0;
                caret(t);
                InvalidateRect(hwnd, NULL, FALSE);
                return 0;
            }
            int k = key(wp);
            if (k) {
                t->scroll = t->selected = 0;
                int repeats = LOWORD(lp); if (!repeats) repeats = 1;
                for (int i = 0; i < repeats; i++) mp_terminal_key(t->model, k, mod);
                caret(t);
                InvalidateRect(hwnd, NULL, FALSE);
                return 0;
            }
            break;
        }
        case WM_CHAR: case WM_SYSCHAR: {
            if (wp == '\r' || wp == '\t' || wp == '\b' || wp == 27) return 0;
            int mod = modifiers() & ~VTERM_MOD_SHIFT;
            if ((GetKeyState(VK_SHIFT) < 0) && (mod & VTERM_MOD_CTRL) && (wp == 3 || wp == 22)) return 0;
            int repeats = LOWORD(lp); if (!repeats) repeats = 1;
            for (int i = 0; i < repeats; i++) character(t, (WCHAR)wp, mod);
            return 0;
        }
        case WM_UNICHAR:
            if (wp == UNICODE_NOCHAR) return TRUE;
            input(t, (uint32_t)wp, modifiers() & ~VTERM_MOD_SHIFT);
            return 0;
        case WM_LBUTTONDOWN: case WM_LBUTTONUP: case WM_MOUSEMOVE: {
            int index = point(t, lp);
            int mod = modifiers();
            if (message == WM_LBUTTONDOWN) SetFocus(hwnd);
            if (mp_terminal_mouse_mode(t->model) && !(mod & VTERM_MOD_SHIFT)) {
                if (message == WM_LBUTTONDOWN) SetCapture(hwnd);
                if (message == WM_LBUTTONUP && GetCapture() == hwnd) ReleaseCapture();
                mp_terminal_mouse(t->model, index / t->cols, index % t->cols, message == WM_MOUSEMOVE ? 0 : 1, message == WM_LBUTTONDOWN, mod);
                return 0;
            }
            if (message == WM_LBUTTONDOWN) {
                t->anchor = t->end = index;
                t->selecting = t->selected = 1;
                SetCapture(hwnd);
            } else if (t->selecting) {
                t->end = index;
                if (message == WM_LBUTTONUP) { t->selecting = 0; ReleaseCapture(); }
            } else return 0;
            InvalidateRect(hwnd, NULL, FALSE);
            return 0;
        }
        case WM_CAPTURECHANGED: t->selecting = 0; return 0;
        case WM_MOUSEWHEEL: {
            t->wheel += GET_WHEEL_DELTA_WPARAM(wp);
            int steps = t->wheel / WHEEL_DELTA;
            t->wheel %= WHEEL_DELTA;
            if (mp_terminal_mouse_mode(t->model) && !(modifiers() & VTERM_MOD_SHIFT)) {
                POINT p = {GET_X_LPARAM(lp), GET_Y_LPARAM(lp)};
                ScreenToClient(hwnd, &p);
                int row = clamp(p.y / t->height, 0, t->rows - 1);
                int col = clamp(p.x / t->width, 0, t->cols - 1);
                for (int i = 0; i < abs(steps); i++) mp_terminal_mouse(t->model, row, col, steps > 0 ? 4 : 5, 1, modifiers());
            } else {
                t->scroll = clamp(t->scroll + steps * 3, 0, mp_terminal_history(t->model));
                t->selected = 0;
                caret(t);
                InvalidateRect(hwnd, NULL, FALSE);
            }
            return 0;
        }
        case WM_NCDESTROY:
            SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0);
            mp_terminal_free(t->model);
            for (int i = 0; i < 16; i++) if (t->fonts[i]) DeleteObject(t->fonts[i]);
            free(t);
            return DefWindowProcW(hwnd, message, wp, lp);
    }
    return DefWindowProcW(hwnd, message, wp, lp);
}

HWND mp_terminal_window_new(HWND parent, const LOGFONTW *font, uint32_t fg, uint32_t bg, const uint32_t *palette, MPTerminalOutput output, MPTerminalResize on_resize, void *user) {
    WNDCLASSEXW wc = {0};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = procedure;
    wc.hInstance = GetModuleHandleW(NULL);
    wc.hCursor = LoadCursorW(NULL, MAKEINTRESOURCEW(32513));
    wc.lpszClassName = CLASS_NAME;
    if (!RegisterClassExW(&wc) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) return NULL;
    TerminalWindow *t = calloc(1, sizeof(*t));
    if (!t) return NULL;
    t->width = t->height = 1;
    t->rows = 24; t->cols = 80;
    t->resize = on_resize; t->user = user; t->background = bg;
    t->model = mp_terminal_new(t->rows, t->cols, output, user);
    if (!t->model) { free(t); return NULL; }
    Creation creation = {t, 0};
    HWND hwnd = CreateWindowExW(0, CLASS_NAME, L"", WS_CHILD | WS_CLIPSIBLINGS, 0, 0, 0, 0, parent, NULL, wc.hInstance, &creation);
    if (!hwnd) {
        if (!creation.attached) { mp_terminal_free(t->model); free(t); }
        return NULL;
    }
    mp_terminal_window_style(hwnd, font, fg, bg, palette);
    if (!t->fonts[0]) { DestroyWindow(hwnd); return NULL; }
    return hwnd;
}
