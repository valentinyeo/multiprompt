#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static BOOL CALLBACK find_transcript(HWND hwnd, LPARAM result) {
    HWND child = FindWindowExW(hwnd, NULL, L"ZigShellChatTranscript", NULL);
    if (!child) return TRUE;
    *(HWND *)result = child;
    return FALSE;
}

int main(int argc, char **argv) {
    if (argc == 3 && strcmp(argv[1], "--start") == 0) {
        FreeConsole();
        if (!AttachConsole((DWORD)strtoul(argv[2], NULL, 10))) return 10;
        WCHAR command[MAX_PATH + 4] = L"\"";
        DWORD n = GetModuleFileNameW(NULL, command + 1, MAX_PATH);
        command[n + 1] = '"';
        command[n + 2] = '\r';
        INPUT_RECORD records[(MAX_PATH + 4) * 2] = {0};
        for (DWORD i = 0; i < n + 3; i++) {
            INPUT_RECORD r = {0};
            r.EventType = KEY_EVENT;
            r.Event.KeyEvent.bKeyDown = TRUE;
            r.Event.KeyEvent.wRepeatCount = 1;
            r.Event.KeyEvent.wVirtualKeyCode = command[i] == '\r' ? VK_RETURN : VK_PACKET;
            r.Event.KeyEvent.uChar.UnicodeChar = command[i];
            records[i * 2] = r;
            r.Event.KeyEvent.bKeyDown = FALSE;
            records[i * 2 + 1] = r;
        }
        HANDLE input = CreateFileW(L"CONIN$", GENERIC_WRITE | GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL);
        DWORD written;
        return WriteConsoleInputW(input, records, (n + 3) * 2, &written) && written == (n + 3) * 2 ? 0 : 11;
    }
    if (argc == 2 && strcmp(argv[1], "--probe") == 0) {
        HWND transcript = FindWindowExW(NULL, NULL, L"ZigShellChatTranscript", NULL);
        if (!transcript) EnumWindows(find_transcript, (LPARAM)&transcript);
        if (!transcript) return 20;
        HWND parent = GetParent(transcript);
        HWND composer = FindWindowExW(parent, NULL, L"EDIT", NULL);
        RECT t, c;
        GetWindowRect(transcript, &t);
        GetWindowRect(composer, &c);
        FILE *rect = fopen("C:\\reply-rects.json", "w");
        if (!rect) return 21;
        fprintf(rect, "{\"transcript\":[%ld,%ld,%ld,%ld],\"composer\":[%ld,%ld,%ld,%ld]}", t.left, t.top, t.right, t.bottom, c.left, c.top, c.right, c.bottom);
        fclose(rect);
        return 0;
    }
    FILE *pid = fopen("C:\\stub-pid.txt", "w");
    if (!pid) return 2;
    fprintf(pid, "%lu", GetCurrentProcessId());
    fclose(pid);
    FILE *keys = fopen("C:\\stub-keys.txt", "wb");
    if (!keys) return 3;
    HANDLE input = GetStdHandle(STD_INPUT_HANDLE);
    HANDLE output = GetStdHandle(STD_OUTPUT_HANDLE);
    SetConsoleMode(input, ENABLE_WINDOW_INPUT | ENABLE_EXTENDED_FLAGS);
    SetConsoleTitleW(L"Claude Code Reply test");
    CONSOLE_SCREEN_BUFFER_INFO info;
    GetConsoleScreenBufferInfo(output, &info);
    COORD origin = {0, 0};
    DWORD written;
    FillConsoleOutputCharacterW(output, L' ', (DWORD)info.dwSize.X * info.dwSize.Y, origin, &written);
    SetConsoleCursorPosition(output, origin);
    const WCHAR message[] = L"\x25cf Reply fixture line\r\n\r\n";
    WriteConsoleW(output, message, (DWORD)(sizeof(message) / sizeof(WCHAR) - 1), &written, NULL);
    for (;;) {
        DWORD available;
        if (!GetNumberOfConsoleInputEvents(input, &available)) return 4;
        if (!available) { Sleep(20); continue; }
        INPUT_RECORD record;
        DWORD read;
        if (!ReadConsoleInputW(input, &record, 1, &read)) return 4;
        if (record.EventType != KEY_EVENT || !record.Event.KeyEvent.bKeyDown) continue;
        WCHAR c = record.Event.KeyEvent.uChar.UnicodeChar;
        if (!c) continue;
        for (WORD i = 0; i < record.Event.KeyEvent.wRepeatCount; i++) fputc(c == L'\r' ? '\n' : (char)c, keys);
        fflush(keys);
        WriteConsoleW(output, &c, 1, &written, NULL);
    }
}
