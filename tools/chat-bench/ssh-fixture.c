#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <string.h>
#include <wchar.h>

static void put(DWORD stream, const char *text) {
    DWORD written;
    WriteFile(GetStdHandle(stream), text, (DWORD)lstrlenA(text), &written, NULL);
}

static int session_name(const wchar_t *start, wchar_t *name, size_t size) {
    size_t length = 0;
    while (start[length] && start[length] != L'\'') {
        wchar_t c = start[length];
        if (length + 1 >= size || !((c >= L'a' && c <= L'z') || (c >= L'A' && c <= L'Z') || (c >= L'0' && c <= L'9') || c == L'-' || c == L'_')) return 0;
        name[length] = c;
        length++;
    }
    name[length] = 0;
    return length > 0 && start[length] == L'\'';
}

static int list_clients(const wchar_t *dir) {
    wchar_t pattern[MAX_PATH];
    if (swprintf(pattern, MAX_PATH, L"%ls\\*.client", dir) < 0) return 255;
    WIN32_FIND_DATAW entry;
    HANDLE find = FindFirstFileW(pattern, &entry);
    if (find != INVALID_HANDLE_VALUE) {
        do {
            char name[MAX_PATH];
            int length = WideCharToMultiByte(CP_UTF8, 0, entry.cFileName, -1, name, sizeof name, NULL, NULL);
            char *dot = length > 0 ? strchr(name, '.') : NULL;
            if (!dot) continue;
            *dot = 0;
            put(STD_OUTPUT_HANDLE, name);
            put(STD_OUTPUT_HANDLE, "\n");
        } while (FindNextFileW(find, &entry));
        FindClose(find);
    }
    put(STD_OUTPUT_HANDLE, "@@MP_LIVE@@\n");
    return 0;
}

static int attach(const wchar_t *dir, const wchar_t *session) {
    wchar_t file[MAX_PATH];
    if (swprintf(file, MAX_PATH, L"%ls\\%ls.%lu.client", dir, session, GetCurrentProcessId()) < 0) return 255;
    HANDLE client = CreateFileW(file, GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, CREATE_NEW, FILE_ATTRIBUTE_TEMPORARY | FILE_FLAG_DELETE_ON_CLOSE, NULL);
    if (client == INVALID_HANDLE_VALUE) return 255;
    put(STD_OUTPUT_HANDLE, "chat-bench fixture session attached\r\n");
    Sleep(INFINITE);
    return 0;
}

int wmain(int argc, wchar_t **argv) {
    const wchar_t *command = GetCommandLineW();
    for (int i = 1; i < argc; i++) {
        if (!wcscmp(argv[i], L"-V")) {
            put(STD_ERROR_HANDLE, "OpenSSH chat-bench fixture\n");
            return 0;
        }
    }
    wchar_t dir[MAX_PATH];
    DWORD length = GetEnvironmentVariableW(L"CHAT_BENCH_SSH_DIR", dir, MAX_PATH);
    if (length == 0 || length >= MAX_PATH) {
        put(STD_ERROR_HANDLE, "ssh: chat-bench fixture has no session directory\n");
        return 255;
    }
    if (wcsstr(command, L"tmux list-clients")) return list_clients(dir);
    const wchar_t *target = wcsstr(command, L"tmux attach -t '");
    wchar_t session[128];
    if (target && session_name(target + 16, session, 128)) return attach(dir, session);
    put(STD_ERROR_HANDLE, "ssh: unsupported chat-bench fixture command\n");
    return 255;
}
