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
    FILE *pid = fopen("C:\\stub-pid.txt", "w");
    if (!pid) return 2;
    fprintf(pid, "%lu", GetCurrentProcessId());
    fclose(pid);
    FILE *events = fopen("C:\\stub-events.txt", "w");
    if (!events) return 3;
    HANDLE input = GetStdHandle(STD_INPUT_HANDLE);
    HANDLE output = GetStdHandle(STD_OUTPUT_HANDLE);
    SetConsoleMode(input, ENABLE_WINDOW_INPUT | ENABLE_EXTENDED_FLAGS);
    DWORD next = 0;
    int working = 1;
    for (;;) {
        if (working && GetTickCount() >= next) {
            const WCHAR line[] = L"\r* Working\x2026 (3s \x00b7 esc to interrupt)        ";
            DWORD written;
            WriteConsoleW(output, line, (DWORD)(sizeof(line) / sizeof(WCHAR) - 1), &written, NULL);
            next = GetTickCount() + 1000;
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
                    fprintf(events, "KEY vk=0x%02X down=%d char=0x%04X\n", r->Event.KeyEvent.wVirtualKeyCode, r->Event.KeyEvent.bKeyDown, r->Event.KeyEvent.uChar.UnicodeChar);
                    fflush(events);
                    if (r->Event.KeyEvent.bKeyDown && r->Event.KeyEvent.wVirtualKeyCode == VK_ESCAPE) {
                        working = 0;
                        DWORD written;
                        const WCHAR done[] = L"\rDone.                                                    \r";
                        WriteConsoleW(output, done, (DWORD)(sizeof(done) / sizeof(WCHAR) - 1), &written, NULL);
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
