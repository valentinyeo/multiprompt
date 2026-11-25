#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static FILE *evidence(const char *name) {
    const char *root = getenv("MP_VERIFY_STATE");
    if (!root || !*root) return NULL;
    char path[MAX_PATH];
    if (snprintf(path, sizeof(path), "%s\\%s", root, name) >= (int)sizeof(path)) return NULL;
    return fopen(path, "ab");
}

static void record(const char *name, const char *text, size_t length) {
    FILE *out = evidence(name);
    if (!out) return;
    fwrite(text, 1, length, out);
    fputc('\n', out);
    fclose(out);
}

static void emit(const char *line) {
    fputs(line, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

static int appendString(char *out, int used, int size, const char *text) {
    for (const char *p = text; *p; p++) {
        if (used >= size - 3) break;
        if (*p == '"' || *p == '\\') out[used++] = '\\';
        out[used++] = *p;
    }
    return used;
}

int main(int argc, char **argv) {
    char argv_line[2048];
    int used = snprintf(argv_line, sizeof(argv_line), "{\"pid\":%lu,\"argv\":[", (unsigned long)GetCurrentProcessId());
    for (int i = 0; i < argc && used > 0 && used < (int)sizeof(argv_line) - 8; i++) {
        if (i) argv_line[used++] = ',';
        argv_line[used++] = '"';
        used = appendString(argv_line, used, (int)sizeof(argv_line) - 4, argv[i]);
        argv_line[used++] = '"';
    }
    if (used > 0 && used < (int)sizeof(argv_line) - 4) {
        snprintf(argv_line + used, sizeof(argv_line) - used, "]}");
        record("agy-agent.jsonl", argv_line, strlen(argv_line));
    }
    SetConsoleOutputCP(CP_UTF8);
    emit("{\"event\":\"init\",\"conversation_id\":\"7d4b2f60-1a3c-4c58-9a41-2f5b8c1d0e37\",\"init\":{\"model\":\"gemini-4-neon-high\"}}");
    char line[16384];
    int step = 0;
    while (fgets(line, sizeof(line), stdin)) {
        size_t length = strlen(line);
        while (length && (line[length - 1] == '\n' || line[length - 1] == '\r')) line[--length] = 0;
        if (!length) continue;
        record("agy-received.jsonl", line, length);
        char out[512];
        snprintf(out, sizeof(out),
                 "{\"event\":\"step_update\",\"step_update\":{\"conversation_id\":\"7d4b2f60-1a3c-4c58-9a41-2f5b8c1d0e37\",\"step_index\":%d,\"state\":\"DONE\",\"step_type\":\"user_input\"}}",
                 step);
        emit(out);
        snprintf(out, sizeof(out),
                 "{\"event\":\"step_update\",\"step_update\":{\"conversation_id\":\"7d4b2f60-1a3c-4c58-9a41-2f5b8c1d0e37\",\"step_index\":%d,\"state\":\"ACTIVE\",\"step_type\":\"agent_response\",\"text_delta\":\"Antigravity stand-in reply %d.\"}}",
                 step + 1, step + 1);
        emit(out);
        snprintf(out, sizeof(out),
                 "{\"event\":\"step_update\",\"step_update\":{\"conversation_id\":\"7d4b2f60-1a3c-4c58-9a41-2f5b8c1d0e37\",\"step_index\":%d,\"state\":\"DONE\",\"step_type\":\"agent_response\"}}",
                 step + 1);
        emit(out);
        snprintf(out, sizeof(out),
                 "{\"event\":\"result\",\"result\":{\"conversation_id\":\"7d4b2f60-1a3c-4c58-9a41-2f5b8c1d0e37\",\"status\":\"SUCCESS\",\"response\":\"Antigravity stand-in reply %d.\",\"usage\":{\"input_tokens\":1,\"output_tokens\":1}}}",
                 step + 1);
        emit(out);
        step += 2;
    }
    return 0;
}
