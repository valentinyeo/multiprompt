#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <wchar.h>

int wmain(int argc, wchar_t **argv) {
    if (argc == 2 && wcscmp(argv[1], L"-V") == 0) {
        puts("OpenSSH_9.0");
        return 0;
    }
    int cat = 0, status = 0;
    for (int i = 1; i < argc; i++) {
        cat |= wcscmp(argv[i], L"cat") == 0;
        status |= wcsstr(argv[i], L"token-ladder/status.json") != NULL;
    }
    if (!cat || !status) return 1;
    wchar_t path[32768];
    DWORD length = GetModuleFileNameW(NULL, path, 32768);
    if (!length || length >= 32768) return 2;
    wchar_t *name = wcsrchr(path, L'\\');
    if (!name || name - path + 32 >= 32768) return 2;
    wcscpy(name + 1, L"usage-pace.json");
    FILE *input = _wfopen(path, L"rb");
    if (!input) return 3;
    char buffer[4096];
    size_t count;
    while ((count = fread(buffer, 1, sizeof(buffer), input)) != 0) {
        if (fwrite(buffer, 1, count, stdout) != count) {
            fclose(input);
            return 4;
        }
    }
    int failed = ferror(input);
    fclose(input);
    if (failed) return 4;
    wcscpy(name + 1, L"usage-ssh-read.log");
    FILE *log = _wfopen(path, L"ab");
    if (!log) return 5;
    fputs("cat token-ladder/status.json\n", log);
    fclose(log);
    return 0;
}
