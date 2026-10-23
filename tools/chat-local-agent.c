#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

int main(int argc, char **argv) {
    if (argc != 3) return 1;
    BOOL suggestion = strcmp(argv[1], "suggestion") == 0;
    if (!suggestion && strcmp(argv[1], "typed") != 0) return 1;
    char path[MAX_PATH];
    if (snprintf(path, sizeof(path), "%s-stdin.bin", argv[2]) >= (int)sizeof(path)) return 2;
    FILE *received = fopen(path, "wb");
    if (!received) return 2;
    HANDLE input = GetStdHandle(STD_INPUT_HANDLE);
    HANDLE output = GetStdHandle(STD_OUTPUT_HANDLE);
    DWORD mode;
    if (!GetConsoleMode(output, &mode) || !SetConsoleMode(output, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING)) return 3;
    if (!SetConsoleMode(input, ENABLE_WINDOW_INPUT | ENABLE_EXTENDED_FLAGS)) return 3;
    if (!SetConsoleTitleW(L"Claude Code - Local route verification")) return 3;
    const WCHAR *clear = L"\x1b[0m\x1b[2J";
    DWORD written;
    if (!WriteConsoleW(output, clear, (DWORD)wcslen(clear), &written, NULL)) return 4;
    CONSOLE_SCREEN_BUFFER_INFO info;
    if (!GetConsoleScreenBufferInfo(output, &info)) return 4;
    COORD origin = {0, info.srWindow.Bottom};
    if (!SetConsoleCursorPosition(output, origin)) return 4;
    const WCHAR *prompt = suggestion
        ? L"\x276f \x1b[90m\x1b[7mT\x1b[27m\x1b[2mry a suggested reply\x1b[22m\x1b[39m\r\x1b[2C"
        : L"\x276f user draft\x1b[7m \x1b[27m";
    if (!WriteConsoleW(output, prompt, (DWORD)wcslen(prompt), &written, NULL)) return 4;
    WCHAR chars[32];
    WORD attributes[32];
    DWORD chars_read, attrs_read;
    if (!GetConsoleScreenBufferInfo(output, &info) ||
        !ReadConsoleOutputCharacterW(output, chars, 32, origin, &chars_read) || chars_read != 32 ||
        !ReadConsoleOutputAttribute(output, attributes, 32, origin, &attrs_read) || attrs_read != 32) return 5;
    if (snprintf(path, sizeof(path), "%s-ready.json", argv[2]) >= (int)sizeof(path)) return 2;
    FILE *ready = fopen(path, "w");
    if (!ready) return 2;
    fprintf(ready, "{\"pid\":%lu,\"row\":%d,\"defaultAttributes\":%u,\"chars\":[", GetCurrentProcessId(), origin.Y, info.wAttributes);
    for (int i = 0; i < 32; i++) fprintf(ready, "%s%u", i ? "," : "", chars[i]);
    fputs("],\"attributes\":[", ready);
    for (int i = 0; i < 32; i++) fprintf(ready, "%s%u", i ? "," : "", attributes[i]);
    fputs("]}", ready);
    fclose(ready);
    for (;;) {
        INPUT_RECORD record;
        DWORD read;
        if (!ReadConsoleInputW(input, &record, 1, &read) || read != 1) return 6;
        if (record.EventType != KEY_EVENT || !record.Event.KeyEvent.bKeyDown) continue;
        WCHAR c = record.Event.KeyEvent.uChar.UnicodeChar;
        if (!c) continue;
        for (WORD i = 0; i < record.Event.KeyEvent.wRepeatCount; i++) {
            if (c > 127 || fputc((char)c, received) == EOF) return 7;
        }
        if (fflush(received) != 0) return 7;
    }
}
