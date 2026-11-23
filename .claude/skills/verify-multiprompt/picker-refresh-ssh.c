#define main baseline_main
#include "../../../tools/verify-repo-picker/ssh.c"
#undef main

int main(int argc, char **argv) {
    char root[MAX_PATH], path[MAX_PATH];
    if (!GetEnvironmentVariableA("MP_VERIFY_STATE", root, sizeof(root))) return 1;
    int listing = 0, host = 0;
    for (int i = 1; i < argc; i++) {
        if (strstr(argv[i], "@@MP_REPOS_OK@@")) listing = 1;
        if (!strcmp(argv[i], "remote-3")) host = 2;
    }
    snprintf(path, sizeof(path), "%s\\picker-refresh-repos.txt", root);
    FILE *repos = listing && host == 2 ? fopen(path, "rb") : NULL;
    if (!repos) return baseline_main(argc, argv);
    snprintf(path, sizeof(path), "%s\\picker-refresh-gate.txt", root);
    FILE *gate = fopen(path, "rb");
    if (gate) {
        char name[128] = "";
        if (!fgets(name, sizeof(name), gate)) { fclose(gate); fclose(repos); return 5; }
        fclose(gate);
        HANDLE event = OpenEventA(SYNCHRONIZE, FALSE, name);
        if (!event) { fclose(repos); return 6; }
        snprintf(path, sizeof(path), "%s\\picker-refresh-waiting.txt", root);
        FILE *receipt = fopen(path, "wb");
        if (!receipt) { CloseHandle(event); fclose(repos); return 7; }
        fputs("host=2; listing blocked until screenshot\n", receipt);
        fclose(receipt);
        DWORD status = WaitForSingleObject(event, 9000);
        CloseHandle(event);
        if (status != WAIT_OBJECT_0) { fclose(repos); return 8; }
    }
    int c;
    while ((c = fgetc(repos)) != EOF) putchar(c);
    fclose(repos);
    puts("\n@@MP_REPOS_OK@@");
    fflush(stdout);
    snprintf(path, sizeof(path), "%s\\picker-refresh-published-%lu.txt", root, GetCurrentProcessId());
    FILE *receipt = fopen(path, "wb");
    if (!receipt) return 9;
    fputs("host=2; listing delivered\n", receipt);
    fclose(receipt);
    return 0;
}
