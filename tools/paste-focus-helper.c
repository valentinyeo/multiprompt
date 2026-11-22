#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static HWND composer;
static HWND console;

static BOOL CALLBACK child(HWND hwnd, LPARAM unused) {
    char cls[128];
    (void)unused;
    GetClassNameA(hwnd, cls, sizeof(cls));
    if (!_stricmp(cls, "EDIT") && IsWindowVisible(hwnd)) composer = hwnd;
    if (strstr(cls, "Console") && IsWindowVisible(hwnd)) console = hwnd;
    return TRUE;
}

static void quoted(const WCHAR *text) {
    putchar('"');
    for (; *text; text++) {
        if (*text == '"' || *text == '\\') printf("\\%c", *text);
        else if (*text < 32 || *text > 126) printf("\\u%04x", *text);
        else putchar(*text);
    }
    putchar('"');
}

static void rect(HWND hwnd) {
    RECT r = {0};
    GetWindowRect(hwnd, &r);
    printf("[%ld,%ld,%ld,%ld]", r.left, r.top, r.right, r.bottom);
}

int main(int argc, char **argv) {
    if (argc < 2) return 2;
    if (!strcmp(argv[1], "text") || !strcmp(argv[1], "image")) {
        HWND owner = CreateWindowA("STATIC", "paste-focus-clipboard", 0, 0, 0, 1, 1, NULL, NULL, NULL, NULL);
        if (!OpenClipboard(owner)) return 3;
        EmptyClipboard();
        HANDLE data;
        UINT format;
        if (!strcmp(argv[1], "text")) {
            if (argc < 3) return 2;
            int n = MultiByteToWideChar(CP_UTF8, 0, argv[2], -1, NULL, 0);
            data = GlobalAlloc(GMEM_MOVEABLE, n * sizeof(WCHAR));
            WCHAR *p = GlobalLock(data);
            MultiByteToWideChar(CP_UTF8, 0, argv[2], -1, p, n);
            GlobalUnlock(data);
            format = CF_UNICODETEXT;
        } else {
            DWORD bytes = sizeof(BITMAPINFOHEADER) + 16 * 16 * 4;
            data = GlobalAlloc(GMEM_MOVEABLE | GMEM_ZEROINIT, bytes);
            BITMAPINFOHEADER *h = GlobalLock(data);
            h->biSize = sizeof(*h);
            h->biWidth = 16;
            h->biHeight = 16;
            h->biPlanes = 1;
            h->biBitCount = 32;
            h->biCompression = BI_RGB;
            h->biSizeImage = 16 * 16 * 4;
            memset(h + 1, 0x7f, h->biSizeImage);
            GlobalUnlock(data);
            format = CF_DIB;
        }
        if (!SetClipboardData(format, data)) return 4;
        CloseClipboard();
        DestroyWindow(owner);
        return 0;
    }
    if (!strcmp(argv[1], "console")) {
        if (argc < 3) return 2;
        FreeConsole();
        if (!AttachConsole(strtoul(argv[2], NULL, 10))) return 5;
        HANDLE h = CreateFileW(L"CONOUT$", GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL);
        WCHAR text[32769] = {0};
        DWORD n = 0;
        COORD origin = {0, 0};
        if (!ReadConsoleOutputCharacterW(h, text, 32768, origin, &n)) return 6;
        text[n] = 0;
        quoted(text);
        CloseHandle(h);
        FreeConsole();
        return 0;
    }
    HWND main = FindWindowA("ZigShell", NULL);
    if (!main) return 7;
    EnumChildWindows(main, child, 0);
    if (!strcmp(argv[1], "clear")) {
        if (!composer) return 8;
        SendMessageW(composer, WM_SETTEXT, 0, (LPARAM)L"");
        return 0;
    }
    GUITHREADINFO info = {0};
    info.cbSize = sizeof(info);
    GetGUIThreadInfo(GetWindowThreadProcessId(GetForegroundWindow(), NULL), &info);
    WCHAR text[16384] = {0};
    if (composer) SendMessageW(composer, WM_GETTEXT, 16384, (LPARAM)text);
    printf("{\"main\":%llu,\"composer\":%llu,\"console\":%llu,\"foreground\":%llu,\"focus\":%llu,\"composerRect\":", (unsigned long long)(UINT_PTR)main, (unsigned long long)(UINT_PTR)composer, (unsigned long long)(UINT_PTR)console, (unsigned long long)(UINT_PTR)GetForegroundWindow(), (unsigned long long)(UINT_PTR)info.hwndFocus);
    rect(composer);
    printf(",\"consoleRect\":");
    rect(console);
    printf(",\"text\":");
    quoted(text);
    puts("}");
    return 0;
}
