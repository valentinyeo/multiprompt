#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static char root[MAX_PATH];
static char sessions[4096];

static void load_sessions(void) {
    char path[MAX_PATH];
    snprintf(path, sizeof(path), "%s\\sessions.txt", root);
    FILE *f = fopen(path, "rb");
    sessions[0] = 0;
    if (f) { size_t n = fread(sessions, 1, sizeof(sessions) - 1, f); sessions[n] = 0; fclose(f); }
}

static int exists(const char *name) {
    char copy[4096];
    strcpy(copy, sessions);
    for (char *p = strtok(copy, "\r\n"); p; p = strtok(NULL, "\r\n")) if (!strcmp(p, name)) return 1;
    return 0;
}

static int alive(DWORD pid) {
    HANDLE p = OpenProcess(SYNCHRONIZE, FALSE, pid);
    if (!p) return 0;
    int result = WaitForSingleObject(p, 0) == WAIT_TIMEOUT;
    CloseHandle(p);
    return result;
}

static void clients(void) {
    char glob[MAX_PATH];
    snprintf(glob, sizeof(glob), "%s\\transport-*.txt", root);
    WIN32_FIND_DATAA data;
    HANDLE search = FindFirstFileA(glob, &data);
    if (search == INVALID_HANDLE_VALUE) return;
    do {
        DWORD pid = strtoul(data.cFileName + 10, NULL, 10);
        if (!alive(pid)) continue;
        char path[MAX_PATH], name[128];
        snprintf(path, sizeof(path), "%s\\%s", root, data.cFileName);
        FILE *f = fopen(path, "rb");
        if (f) { if (fgets(name, sizeof(name), f)) { name[strcspn(name, "\r\n")] = 0; if (exists(name)) puts(name); } fclose(f); }
    } while (FindNextFileA(search, &data));
    FindClose(search);
}

int main(int argc, char **argv) {
    if (argc == 2 && !strcmp(argv[1], "-V")) { puts("OpenSSH_verification"); return 0; }
    if (!GetEnvironmentVariableA("MP_VERIFY_STATE", root, sizeof(root))) return 90;
    char cmd[16384] = "", path[MAX_PATH];
    for (int i = 1; i < argc; i++) { strncat(cmd, argv[i], sizeof(cmd) - strlen(cmd) - 2); strcat(cmd, " "); }
    snprintf(path, sizeof(path), "%s\\invocation-%lu.txt", root, GetCurrentProcessId());
    FILE *log = fopen(path, "wb");
    if (log) { fprintf(log, "%llu %lu %s\n", GetTickCount64(), GetCurrentProcessId(), cmd); fclose(log); }
    load_sessions();
    if (strstr(cmd, "tmux list-clients")) {
        clients();
        if (strstr(cmd, "tmux list-sessions")) {
            if (sessions[0]) {
                for (char *p = strtok(sessions, "\r\n"); p; p = strtok(NULL, "\r\n")) printf("@@S %s\n", p);
                if (strstr(cmd, "@@LS_OK@@")) puts("@@LS_OK@@");
            } else {
                const char *error = "no server running on /tmp/tmux-1000/default";
                fprintf(stderr, "%s\n", error);
                if (strstr(cmd, "2>&1") && strstr(cmd, "no server running") && strstr(cmd, "@@LS_OK@@")) puts("@@LS_OK@@");
            }
        }
        puts("@@MP_LIVE@@"); return 0;
    }
    char *victim = strstr(cmd, "tmux kill-session -t ");
    if (victim) {
        victim += strlen("tmux kill-session -t ");
        while (*victim == '\'' || *victim == '"') victim++;
        victim[strcspn(victim, " '\";\r\n")] = 0;
        if (!exists(victim)) { fprintf(stderr, "can't find session: %s\n", victim); return 1; }
        char keep[4096] = "";
        for (char *p = strtok(sessions, "\r\n"); p; p = strtok(NULL, "\r\n")) if (strcmp(p, victim)) { strcat(keep, p); strcat(keep, "\n"); }
        snprintf(path, sizeof(path), "%s\\sessions.next", root);
        FILE *f = fopen(path, "wb"); if (!f) return 93; fputs(keep, f); fclose(f);
        char target[MAX_PATH];
        snprintf(target, sizeof(target), "%s\\sessions.txt", root);
        if (!MoveFileExA(path, target, MOVEFILE_REPLACE_EXISTING)) return 94;
        return 0;
    }
    if (strstr(cmd, "tmux list-sessions -F")) {
        if (strstr(cmd, " vps ")) {
            for (char *p = strtok(sessions, "\r\n"); p; p = strtok(NULL, "\r\n"))
                printf("%s|%lld|0|/home/runner/work/%s|%s|\n", p, (long long)time(NULL) - 120, p, strncmp(p, "agent-", 6) ? "bash" : "claude");
        }
        return 0;
    }
    if (strstr(cmd, "tmux list-sessions")) {
        for (char *p = strtok(sessions, "\r\n"); p; p = strtok(NULL, "\r\n")) printf("%s\t1\t0\n", p);
        return 0;
    }
    char *name = strstr(cmd, "tmux attach -t ");
    int create = 0;
    if (name) name += strlen("tmux attach -t ");
    else { name = strstr(cmd, "tmux new-session -A -s "); if (name) { name += strlen("tmux new-session -A -s "); create = 1; } }
    if (!name) { if (strstr(cmd, "MP_RELAY")) puts("MP_RELAY_LEGACY"); return 0; }
    while (*name == '\'' || *name == '"') name++;
    if (!create && *name == '=') name++;
    name[strcspn(name, " '\";\r\n")] = 0;
    if (create && !exists(name)) {
        snprintf(path, sizeof(path), "%s\\sessions.txt", root);
        FILE *f = fopen(path, "ab"); if (!f) return 91; fprintf(f, "%s\n", name); fclose(f);
    } else if (!exists(name)) { fprintf(stderr, "can't find session: %s\n", name); return 1; }
    snprintf(path, sizeof(path), "%s\\transport-%lu.txt", root, GetCurrentProcessId());
    FILE *f = fopen(path, "wb"); if (!f) return 92; fprintf(f, "%s\n", name); fclose(f);
    printf("Connected to verification session %s\r\nverify> ", name); fflush(stdout);
    for (;;) Sleep(1000);
}
