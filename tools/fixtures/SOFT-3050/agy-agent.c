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

static int appendJsonText(char *out, int used, int size, const char *text) {
    for (const char *p = text; *p; p++) {
        if (used >= size - 8) break;
        unsigned char character = (unsigned char)*p;
        if (character == '"' || character == '\\') { out[used++] = '\\'; out[used++] = (char)character; }
        else if (character == '\n') { out[used++] = '\\'; out[used++] = 'n'; }
        else if (character == '\r') { out[used++] = '\\'; out[used++] = 'r'; }
        else if (character == '\t') { out[used++] = '\\'; out[used++] = 't'; }
        else if (character < 0x20) out[used++] = ' ';
        else out[used++] = (char)character;
    }
    return used;
}

static unsigned long long nowMs(void) {
    FILETIME file;
    ULARGE_INTEGER value;
    GetSystemTimeAsFileTime(&file);
    value.LowPart = file.dwLowDateTime;
    value.HighPart = file.dwHighDateTime;
    return (value.QuadPart - 116444736000000000ULL) / 10000ULL;
}

static int holdRequested(void) {
    const char *root = getenv("MP_VERIFY_STATE");
    if (!root || !*root) return 0;
    char path[MAX_PATH];
    if (snprintf(path, sizeof(path), "%s\\hold-reply", root) >= (int)sizeof(path)) return 0;
    return GetFileAttributesA(path) != INVALID_FILE_ATTRIBUTES;
}

static int userText(const char *line, char *out, int size) {
    const char *mark = strstr(line, "\"content\":\"");
    if (!mark) return 0;
    mark += 11;
    int used = 0;
    while (*mark && *mark != '"' && used < size - 1) {
        if (*mark == '\\' && mark[1]) {
            mark++;
            if (*mark == 'n') out[used++] = '\n';
            else if (*mark == 'r') out[used++] = '\r';
            else if (*mark == 't') out[used++] = '\t';
            else out[used++] = *mark;
            mark++;
        } else {
            out[used++] = *mark++;
        }
    }
    out[used] = 0;
    return used > 0;
}

static void holdRecord(const char *stage, const char *text, const char *reply, int released) {
    char line[8192];
    int used = snprintf(line, sizeof(line), "{\"ms\": %llu, \"stage\": \"%s\", \"text\": \"", nowMs(), stage);
    used = appendJsonText(line, used, (int)sizeof(line), text);
    used += snprintf(line + used, sizeof(line) - used, "\", \"reply\": \"");
    used = appendJsonText(line, used, (int)sizeof(line), reply);
    used += snprintf(line + used, sizeof(line) - used, released ? "\", \"released\": true}" : "\"}");
    record("antigravity-hold.jsonl", line, (size_t)used);
}

static int releaseHeld(void) {
    unsigned long long deadline = nowMs() + 180000ULL;
    for (;;) {
        HANDLE event = OpenEventW(SYNCHRONIZE, FALSE, L"Local\\multiprompt-verify-antigravity-release");
        if (event) {
            DWORD result = WaitForSingleObject(event, 180000);
            CloseHandle(event);
            return result == WAIT_OBJECT_0;
        }
        if (nowMs() >= deadline) return 0;
        Sleep(100);
    }
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
        char reply[128];
        snprintf(reply, sizeof(reply), "Antigravity stand-in reply %d.", step + 1);
        if (holdRequested()) {
            char text[1024];
            if (userText(line, text, (int)sizeof(text))) {
                holdRecord("replying", text, reply, 0);
                if (releaseHeld()) holdRecord("released", text, reply, 1);
                else holdRecord("timeout", text, reply, 0);
            }
        }
        char out[512];
        snprintf(out, sizeof(out),
                 "{\"event\":\"step_update\",\"step_update\":{\"conversation_id\":\"7d4b2f60-1a3c-4c58-9a41-2f5b8c1d0e37\",\"step_index\":%d,\"state\":\"DONE\",\"step_type\":\"user_input\"}}",
                 step);
        emit(out);
        snprintf(out, sizeof(out),
                 "{\"event\":\"step_update\",\"step_update\":{\"conversation_id\":\"7d4b2f60-1a3c-4c58-9a41-2f5b8c1d0e37\",\"step_index\":%d,\"state\":\"ACTIVE\",\"step_type\":\"agent_response\",\"text_delta\":\"%s\"}}",
                 step + 1, reply);
        emit(out);
        snprintf(out, sizeof(out),
                 "{\"event\":\"step_update\",\"step_update\":{\"conversation_id\":\"7d4b2f60-1a3c-4c58-9a41-2f5b8c1d0e37\",\"step_index\":%d,\"state\":\"DONE\",\"step_type\":\"agent_response\"}}",
                 step + 1);
        emit(out);
        snprintf(out, sizeof(out),
                 "{\"event\":\"result\",\"result\":{\"conversation_id\":\"7d4b2f60-1a3c-4c58-9a41-2f5b8c1d0e37\",\"status\":\"SUCCESS\",\"response\":\"%s\",\"usage\":{\"input_tokens\":1,\"output_tokens\":1}}}",
                 reply);
        emit(out);
        step += 2;
    }
    return 0;
}
