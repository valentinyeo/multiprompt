#include <windows.h>
#include <stdlib.h>
#include <wchar.h>

static int append(wchar_t *out, int capacity, int position, const wchar_t *text) {
    while (*text) {
        if (position >= capacity - 1) return -1;
        out[position++] = *text++;
    }
    out[position] = 0;
    return position;
}

static int append_quoted(wchar_t *out, int capacity, int position, const wchar_t *argument) {
    position = append(out, capacity, position, L" \"");
    if (position < 0) return -1;
    while (*argument) {
        if (*argument == L'\\' || *argument == L'"') {
            position = append(out, capacity, position, L"\\");
            if (position < 0) return -1;
        }
        if (position >= capacity - 1) return -1;
        out[position++] = *argument++;
        out[position] = 0;
    }
    return append(out, capacity, position, L"\"");
}

int wmain(int argc, wchar_t **argv) {
    const wchar_t *bash = _wgetenv(L"ZSB_WRAPPER_BASH");
    const wchar_t *script = _wgetenv(L"ZSB_WRAPPER_SCRIPT");
    if (!bash || !*bash || !script || !*script) return 90;
    const int capacity = 32768;
    wchar_t *command = (wchar_t *)calloc(capacity, sizeof(wchar_t));
    if (!command) return 91;
    int position = append_quoted(command, capacity, 0, bash);
    if (position < 0) { free(command); return 92; }
    position = append_quoted(command, capacity, position, script);
    if (position < 0) { free(command); return 92; }
    for (int i = 1; i < argc; i++) {
        position = append_quoted(command, capacity, position, argv[i]);
        if (position < 0) { free(command); return 92; }
    }
    STARTUPINFOW si;
    PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof(si));
    ZeroMemory(&pi, sizeof(pi));
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
    si.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
    si.hStdError = GetStdHandle(STD_ERROR_HANDLE);
    if (!CreateProcessW(bash, command, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) {
        free(command);
        return 93;
    }
    free(command);
    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD code = 94;
    GetExitCodeProcess(pi.hProcess, &code);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return (int)code;
}
