#include <windows.h>
#include <stdlib.h>
#include <wchar.h>

static int run(void) {
    const wchar_t *python = _wgetenv(L"MP_VERIFY_PYTHON");
    const wchar_t *script = _wgetenv(L"MP_VERIFY_BOUNDARY");
    if (!python || !script) return 90;
    wchar_t *tail = GetCommandLineW();
    if (*tail == L'"') { tail++; while (*tail && *tail != L'"') tail++; if (*tail) tail++; }
    else { while (*tail && *tail != L' ') tail++; }
    wchar_t *command = calloc(32768, sizeof(wchar_t));
    if (!command) return 91;
    wchar_t module[32768];
    if (!GetModuleFileNameW(NULL, module, 32768)) { free(command); return 92; }
    const wchar_t *mode = wcsstr(module, L"tmux.exe") ? L"tmux" : L"ssh";
    int n = swprintf(command, 32768, L"\"%ls\" -u \"%ls\" %ls %ls", python, script, mode, tail);
    if (n < 0 || n >= 32767) { free(command); return 92; }
    STARTUPINFOW si = {0};
    PROCESS_INFORMATION pi = {0};
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_SHOWNOACTIVATE;
    si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
    si.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
    si.hStdError = GetStdHandle(STD_ERROR_HANDLE);
    HANDLE job = CreateJobObjectW(NULL, NULL);
    if (!job) { free(command); return 95; }
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {0};
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof(limits))) { CloseHandle(job); free(command); return 95; }
    DWORD flags = CREATE_SUSPENDED | (GetConsoleWindow() == NULL ? CREATE_NO_WINDOW : 0);
    if (!CreateProcessW(python, command, NULL, NULL, TRUE, flags, NULL, NULL, &si, &pi)) { CloseHandle(job); free(command); return 93; }
    free(command);
    if (!AssignProcessToJobObject(job, pi.hProcess) || ResumeThread(pi.hThread) == (DWORD)-1) {
        TerminateProcess(pi.hProcess, 1);
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
        CloseHandle(job);
        return 95;
    }
    CloseHandle(pi.hThread);
    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD result = 94;
    GetExitCodeProcess(pi.hProcess, &result);
    CloseHandle(pi.hProcess);
    CloseHandle(job);
    return (int)result;
}

int wmain(void) { return run(); }

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, LPWSTR command, int show) {
    (void)instance; (void)previous; (void)command; (void)show;
    return run();
}
