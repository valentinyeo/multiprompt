#include <windows.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
    char root[MAX_PATH], path[MAX_PATH], cmd[32768] = "";
    if (!GetEnvironmentVariableA("MP_VERIFY_STATE", root, sizeof(root))) return 1;
    for (int i = 1; i < argc; i++) {
        if (strlen(cmd) + strlen(argv[i]) + 2 >= sizeof(cmd)) return 2;
        strcat(cmd, argv[i]);
        strcat(cmd, " ");
    }
    snprintf(path, sizeof(path), "%s\\invocation-%lu.txt", root, GetCurrentProcessId());
    FILE *log = fopen(path, "wb");
    if (!log) return 3;
    fputs(cmd, log);
    fclose(log);
    if (strstr(cmd, "for d in /home/*/projects/*/") && strstr(cmd, ".git")) {
        puts("/work/projects/alpha");
        puts("/work/projects/beta");
        fflush(stdout);
        snprintf(path, sizeof(path), "%s\\listing-%lu.txt", root, GetCurrentProcessId());
        FILE *done = fopen(path, "wb");
        if (!done) return 4;
        fputs("alpha\nbeta\n", done);
        fclose(done);
        return 0;
    }
    if (strstr(cmd, "tmux list-clients")) {
        if (strstr(cmd, "@@LS_OK@@")) puts("@@LS_OK@@");
        puts("@@MP_LIVE@@");
        return 0;
    }
    if (strstr(cmd, "tmux attach") || strstr(cmd, "tmux new-session")) {
        puts("Verification terminal");
        fflush(stdout);
        for (;;) Sleep(1000);
    }
    if (strstr(cmd, "MP_RELAY")) puts("MP_RELAY_LEGACY");
    return 0;
}
