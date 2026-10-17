#define WIN32_LEAN_AND_MEAN
#include <windows.h>

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, PWSTR title, int show) {
    (void)previous;
    (void)show;
    HWND window = CreateWindowExW(WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW, L"STATIC", title,
        WS_POPUP | WS_BORDER, 0, 0, 100, 100, NULL, NULL, instance, NULL);
    if (!window) return 1;
    ShowWindow(window, SW_SHOWNOACTIVATE);
    MSG message;
    while (IsWindow(window) && GetMessageW(&message, NULL, 0, 0) > 0) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }
    return 0;
}
