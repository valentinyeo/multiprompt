#include "terminal_window.h"
#include <wchar.h>

typedef struct {
    char bytes[8192];
    size_t used;
    int rows, cols;
} WindowFixture;

static void window_output(const char *bytes, size_t length, void *user) {
    WindowFixture *f = user;
    assert(f->used + length < sizeof(f->bytes));
    memcpy(f->bytes + f->used, bytes, length);
    f->used += length;
    f->bytes[f->used] = 0;
}

static void window_resize(int rows, int cols, void *user) {
    WindowFixture *f = user;
    f->rows = rows; f->cols = cols;
}

static void window_feed(HWND hwnd, const char *bytes) {
    mp_terminal_window_feed(hwnd, bytes, strlen(bytes));
}

static void pump_windows(void) {
    MSG message;
    int count = 0;
    while (PeekMessageW(&message, NULL, 0, 0, PM_REMOVE)) {
        assert(++count < 1000);
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }
}

static void terminal_window_cycle(HWND parent, int check_resources) {
    LOGFONTW font = {0};
    font.lfHeight = -16;
    font.lfWeight = FW_NORMAL;
    wcscpy(font.lfFaceName, L"Consolas");
    WindowFixture f = {0};
    HWND warm = mp_terminal_window_new(parent, &font, 0xffffff, 0, NULL, window_output, window_resize, &f);
    assert(warm);
    assert(DestroyWindow(warm));
    pump_windows();
    DWORD gdi_before = GetGuiResources(GetCurrentProcess(), GR_GDIOBJECTS);
    DWORD user_before = GetGuiResources(GetCurrentProcess(), GR_USEROBJECTS);
    HWND windows[30];
    WindowFixture contexts[30] = {0};
    for (int i = 0; i < 30; i++) {
        windows[i] = mp_terminal_window_new(parent, &font, 0xffffff, 0, NULL, window_output, window_resize, &contexts[i]);
        assert(windows[i]);
        DWORD pid = 0;
        GetWindowThreadProcessId(windows[i], &pid);
        assert(pid == GetCurrentProcessId());
        assert(GetParent(windows[i]) == parent);
        assert(MoveWindow(windows[i], 0, 0, 640, 400, FALSE));
        assert(contexts[i].rows > 1 && contexts[i].cols > 1);
    }
    HWND hwnd = windows[0];
    WindowFixture *active = &contexts[0];
    SendMessageW(hwnd, WM_CHAR, 0x96ea, 1);
    SendMessageW(hwnd, WM_CHAR, 0xd83d, 1);
    SendMessageW(hwnd, WM_CHAR, 0xde80, 1);
    assert(!strcmp(active->bytes, "\xe9\x9b\xaa\xf0\x9f\x9a\x80"));
    active->used = 0;
    SendMessageW(hwnd, WM_KEYDOWN, VK_UP, 1);
    assert(!strcmp(active->bytes, "\033[A"));
    active->used = 0;
    window_feed(hwnd, "\033[?1h");
    SendMessageW(hwnd, WM_KEYDOWN, VK_UP, 1);
    assert(!strcmp(active->bytes, "\033OA"));
    active->used = 0;
    SendMessageW(hwnd, WM_KEYDOWN, VK_RETURN, 1);
    SendMessageW(hwnd, WM_CHAR, '\r', 1);
    assert(!strcmp(active->bytes, "\r"));
    for (int i = 1; i < 30; i++) assert(contexts[i].used == 0);
    int old_cols = active->cols;
    assert(MoveWindow(hwnd, 0, 0, 320, 240, FALSE));
    assert(active->cols < old_cols);
    window_feed(hwnd, "\033[2J\033[H\033[41m \033[0m");
    HDC screen = GetDC(hwnd);
    HDC dc = CreateCompatibleDC(screen);
    HBITMAP bitmap = CreateCompatibleBitmap(screen, 320, 240);
    assert(dc && bitmap);
    HGDIOBJ old = SelectObject(dc, bitmap);
    SendMessageW(hwnd, WM_PRINTCLIENT, (WPARAM)dc, PRF_CLIENT);
    assert(GetPixel(dc, 0, 0) == RGB(224, 0, 0));
    assert(GetPixel(dc, 319, 239) == RGB(0, 0, 0));
    SelectObject(dc, old);
    DeleteObject(bitmap);
    DeleteDC(dc);
    ReleaseDC(hwnd, screen);
    HFONT measure = CreateFontIndirectW(&font);
    screen = GetDC(hwnd);
    old = SelectObject(screen, measure);
    TEXTMETRICW metrics;
    assert(GetTextMetricsW(screen, &metrics));
    SelectObject(screen, old);
    ReleaseDC(hwnd, screen);
    DeleteObject(measure);
    window_feed(hwnd, "\033[2J\033[Hcopy");
    SendMessageW(hwnd, WM_LBUTTONDOWN, MK_LBUTTON, MAKELPARAM(0, 0));
    SendMessageW(hwnd, WM_LBUTTONUP, 0, MAKELPARAM(metrics.tmAveCharWidth * 3, 0));
    mp_terminal_window_copy(hwnd);
    assert(OpenClipboard(parent));
    HANDLE memory = GetClipboardData(CF_UNICODETEXT);
    assert(memory);
    const WCHAR *text = GlobalLock(memory);
    assert(text && !wcscmp(text, L"copy"));
    GlobalUnlock(memory);
    CloseClipboard();
    active->used = 0;
    window_feed(hwnd, "\033[?2004h");
    mp_terminal_window_paste(hwnd);
    assert(!strcmp(active->bytes, "\033[200~copy\033[201~"));
    for (int i = 0; i < 30; i++) {
        assert(DestroyWindow(windows[i]));
        assert(!IsWindow(windows[i]));
    }
    pump_windows();
    GdiFlush();
    DWORD gdi_after = GetGuiResources(GetCurrentProcess(), GR_GDIOBJECTS);
    DWORD user_after = GetGuiResources(GetCurrentProcess(), GR_USEROBJECTS);
    printf("TERMINAL_WINDOW_RESOURCES measured=%d GDI=%lu/%lu USER=%lu/%lu\n", check_resources, gdi_before, gdi_after, user_before, user_after);
    fflush(stdout);
    if (check_resources) {
        assert(gdi_after == gdi_before);
        assert(user_after == user_before);
    }
}

static void terminal_window_fixture(void) {
    HWND parent = CreateWindowExW(0, L"STATIC", L"Terminal fixture", WS_POPUP, 0, 0, 800, 600, NULL, NULL, GetModuleHandleW(NULL), NULL);
    assert(parent);
    terminal_window_cycle(parent, 0);
    terminal_window_cycle(parent, 1);
    assert(DestroyWindow(parent));
    pump_windows();
    puts("TERMINAL_WINDOW_PASS 30 owned child windows; Unicode; application keys; resize; pixels; clipboard; zero warmed GDI/USER growth");
}
