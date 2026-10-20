#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
    FILE *events = fopen("C:\\stub-events.txt", "w");
    if (!events) return 3;
    HANDLE input = GetStdHandle(STD_INPUT_HANDLE);
    HANDLE output = GetStdHandle(STD_OUTPUT_HANDLE);
    SetConsoleMode(input, ENABLE_WINDOW_INPUT | ENABLE_EXTENDED_FLAGS);
    FILE *menu = fopen("C:\\permission-menu.txt", "rb");
    if (!menu) return 6;
    char utf8[16384];
    size_t length = fread(utf8, 1, sizeof(utf8), menu);
    fclose(menu);
    WCHAR wide[16384];
    int n = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8, (int)length, wide, 16384);
    if (!n) return 7;
    CONSOLE_SCREEN_BUFFER_INFO info;
    if (!GetConsoleScreenBufferInfo(output, &info)) return 8;
    COORD size = {160, info.dwSize.Y};
    SetConsoleScreenBufferSize(output, size);
    DWORD written;
    COORD origin = {0, 0};
    FillConsoleOutputCharacterW(output, L' ', (DWORD)size.X * size.Y, origin, &written);
    SetConsoleCursorPosition(output, origin);
    WCHAR rendered[32768];
    DWORD rendered_length = 0;
    for (int i = 0; i < n; i++) {
        if (wide[i] == L'\n') rendered[rendered_length++] = L'\r';
        rendered[rendered_length++] = wide[i];
    }
    if (!WriteConsoleW(output, rendered, rendered_length, &written, NULL) || written != rendered_length) return 12;
    FILE *keys = fopen("C:\\stub-keys.txt", "wb");
    if (!keys) return 9;
    FILE *pid = fopen("C:\\stub-pid.txt", "w");
    if (!pid) return 2;
    fprintf(pid, "%lu", GetCurrentProcessId());
    fclose(pid);
    for (;;) {
        if (GetFileAttributesW(L"C:\\permission-clear.txt") != INVALID_FILE_ATTRIBUTES) {
            DeleteFileW(L"C:\\permission-clear.txt");
            GetConsoleScreenBufferInfo(output, &info);
            FillConsoleOutputCharacterW(output, L' ', (DWORD)info.dwSize.X * info.dwSize.Y, origin, &written);
            SetConsoleCursorPosition(output, origin);
            WriteConsoleW(output, L"Permission answered.\r\n", 22, &written, NULL);

        }
        if (GetFileAttributesW(L"C:\\permission-next.txt") != INVALID_FILE_ATTRIBUTES) {
            DeleteFileW(L"C:\\permission-next.txt");
            GetConsoleScreenBufferInfo(output, &info);
            FillConsoleOutputCharacterW(output, L' ', (DWORD)info.dwSize.X * info.dwSize.Y, origin, &written);
            SetConsoleCursorPosition(output, origin);
            if (!WriteConsoleW(output, rendered, rendered_length, &written, NULL) || written != rendered_length) return 12;
        }
        DWORD count;
        if (!GetNumberOfConsoleInputEvents(input, &count)) return 4;
        if (count) {
            INPUT_RECORD records[32];
            DWORD read;
            if (!ReadConsoleInputW(input, records, 32, &read)) return 5;
            for (DWORD i = 0; i < read; i++) {
                INPUT_RECORD *r = &records[i];
                if (r->EventType == KEY_EVENT) {
                    fprintf(events, "KEY vk=0x%02X down=%d char=0x%04X repeat=%u\n", r->Event.KeyEvent.wVirtualKeyCode, r->Event.KeyEvent.bKeyDown, r->Event.KeyEvent.uChar.UnicodeChar, r->Event.KeyEvent.wRepeatCount);
                    fflush(events);
                    if (r->Event.KeyEvent.bKeyDown) {
                        for (WORD j = 0; j < r->Event.KeyEvent.wRepeatCount; j++) fputc(r->Event.KeyEvent.uChar.UnicodeChar, keys);
                        fflush(keys);

                    }
                } else {
                    fprintf(events, "EVENT type=%u\n", r->EventType);
                    fflush(events);
                }
            }
        }
        Sleep(20);
    }
}
