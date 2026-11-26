#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>

int wmain(void) {
    wchar_t executable[MAX_PATH], directory[MAX_PATH], path[MAX_PATH + 40];
    if (!GetEnvironmentVariableW(L"MP_VERIFY_REAL_SSH", executable, MAX_PATH) ||
        !GetEnvironmentVariableW(L"MP_VERIFY_SSH_LOG", directory, MAX_PATH)) return 90;
    wchar_t *arguments = GetCommandLineW();
    if (*arguments == L'"') { arguments = wcschr(arguments + 1, L'"'); if (!arguments) return 91; arguments++; }
    else { while (*arguments && *arguments != L' ') arguments++; }
    swprintf(path, MAX_PATH + 40, L"%ls/%lu.txt", directory, GetCurrentProcessId());
    FILE *log = _wfopen(path, L"wb");
    if (!log) return 92;
    int length = WideCharToMultiByte(CP_UTF8, 0, arguments, -1, NULL, 0, NULL, NULL);
    char *utf8 = malloc(length);
    if (!utf8) { fclose(log); return 93; }
    WideCharToMultiByte(CP_UTF8, 0, arguments, -1, utf8, length, NULL, NULL);
    fprintf(log, "%llu\n%s\n", GetTickCount64(), utf8);
    free(utf8);
    fclose(log);
    size_t capacity = wcslen(executable) + wcslen(arguments) + 4;
    wchar_t *command = calloc(capacity, sizeof(wchar_t));
    if (!command) return 94;
    swprintf(command, capacity, L"\"%ls\"%ls", executable, arguments);
    STARTUPINFOW startup = { .cb = sizeof(startup), .dwFlags = STARTF_USESTDHANDLES,
        .hStdInput = GetStdHandle(STD_INPUT_HANDLE), .hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE),
        .hStdError = GetStdHandle(STD_ERROR_HANDLE) };
    PROCESS_INFORMATION process = {0};
    DWORD flags = GetConsoleWindow() == NULL ? CREATE_NO_WINDOW : 0;
    BOOL started = CreateProcessW(executable, command, NULL, NULL, TRUE, flags, NULL, NULL, &startup, &process);
    free(command);
    if (!started) return 95;
    CloseHandle(process.hThread);
    WaitForSingleObject(process.hProcess, INFINITE);
    DWORD code = 96;
    GetExitCodeProcess(process.hProcess, &code);
    CloseHandle(process.hProcess);
    return (int)code;
}
