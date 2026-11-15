#include <windows.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
    int probe = 0, python = 0, i;
    const char *host = "vps1";
    char command[32768], *script, launch[32768];
    STARTUPINFOA start;
    PROCESS_INFORMATION process;
    DWORD wait;
    for (i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-V")) probe = 1;
        if (!strcmp(argv[i], "python3")) python = 1;
        if (!strcmp(argv[i], "remote-2")) host = "vps2";
    }
    if (probe) return 0;
    command[0] = 0;
    for (i = 1; i < argc; i++) {
        if (strlen(command) + strlen(argv[i]) + 2 >= sizeof(command)) return 2;
        strcat(command, argv[i]);
        strcat(command, "\n");
    }
    script = getenv("HARNESS_MATRIX_LOG");
    if (script && script[0]) {
        char path[MAX_PATH];
        FILE *log;
        snprintf(path, sizeof(path), "%s\\ssh-%s.log", script, host);
        log = fopen(path, "ab");
        if (log) {
            fputs(command, log);
            fclose(log);
        }
    }
    if (!python) return 0;
    script = getenv("HARNESS_HOST_PY");
    if (!script || !script[0]) return 3;
    SetEnvironmentVariableA("HARNESS_HOST", host);
    memset(&start, 0, sizeof(start));
    start.cb = sizeof(start);
    start.dwFlags = STARTF_USESTDHANDLES;
    start.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
    start.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
    start.hStdError = GetStdHandle(STD_ERROR_HANDLE);
    if (!start.hStdInput || !start.hStdOutput ||
        !SetHandleInformation(start.hStdInput, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT) ||
        !SetHandleInformation(start.hStdOutput, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT)) return 4;
    if (start.hStdError) SetHandleInformation(start.hStdError, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT);
    snprintf(launch, sizeof(launch), "python \"%s\"", script);
    if (!CreateProcessA(NULL, launch, NULL, NULL, TRUE, CREATE_NO_WINDOW, NULL, NULL, &start, &process)) {
        snprintf(launch, sizeof(launch), "py -3 \"%s\"", script);
        if (!CreateProcessA(NULL, launch, NULL, NULL, TRUE, CREATE_NO_WINDOW, NULL, NULL, &start, &process)) return 4;
    }
    CloseHandle(process.hThread);
    wait = WaitForSingleObject(process.hProcess, INFINITE);
    if (wait != WAIT_OBJECT_0) {
        CloseHandle(process.hProcess);
        return 5;
    }
    if (!GetExitCodeProcess(process.hProcess, &wait)) wait = 6;
    CloseHandle(process.hProcess);
    return (int)wait;
}
