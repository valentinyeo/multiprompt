#include <winsock2.h>
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char base64_chars[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static char *base64_encode(const unsigned char *data, int length) {
    int size = 4 * ((length + 2) / 3);
    char *out = (char *)calloc((size_t)size + 1, 1);
    if (!out) return NULL;
    int position = 0;
    for (int i = 0; i < length; i += 3) {
        unsigned int value = (unsigned int)data[i] << 16;
        if (i + 1 < length) value |= (unsigned int)data[i + 1] << 8;
        if (i + 2 < length) value |= (unsigned int)data[i + 2];
        out[position++] = base64_chars[(value >> 18) & 0x3f];
        out[position++] = base64_chars[(value >> 12) & 0x3f];
        out[position++] = i + 1 < length ? base64_chars[(value >> 6) & 0x3f] : '=';
        out[position++] = i + 2 < length ? base64_chars[value & 0x3f] : '=';
    }
    out[position] = 0;
    return out;
}

static void emit_error(const char *code, const char *message) {
    printf("{\"ok\":false,\"error\":\"%s\",\"message\":\"%s\"}\n", code, message);
    fflush(stdout);
}

int main(int argc, char **argv) {
    const char *port_text = getenv("ZSB_PORT");
    const int port = port_text ? atoi(port_text) : 0;
    if (port <= 0) {
        emit_error("bad_args", "ZSB_PORT is required");
        return 1;
    }
    if (argc < 2) {
        emit_error("bad_args", "a verb is required");
        return 1;
    }
    int length = 0;
    for (int i = 1; i < argc; i++) length += (int)strlen(argv[i]) + 1;
    unsigned char *raw = (unsigned char *)calloc((size_t)length, 1);
    if (!raw) {
        emit_error("out_of_memory", "request buffer unavailable");
        return 1;
    }
    int position = 0;
    for (int i = 1; i < argc; i++) {
        size_t size = strlen(argv[i]);
        memcpy(raw + position, argv[i], size);
        position += (int)size;
        raw[position++] = 0x1f;
    }
    char *encoded = base64_encode(raw, position);
    free(raw);
    if (!encoded) {
        emit_error("out_of_memory", "request encoding unavailable");
        return 1;
    }
    char request[8192];
    int request_length = snprintf(request, sizeof(request), "ZSB:workspace:%s\n", encoded);
    free(encoded);
    if (request_length <= 0 || request_length >= (int)sizeof(request)) {
        emit_error("bad_args", "request exceeds the command-line transport limit");
        return 1;
    }

    WSADATA winsock;
    if (WSAStartup(0x0202, &winsock) != 0) {
        emit_error("socket_unavailable", "winsock did not start");
        return 1;
    }
    SOCKET client = socket(AF_INET, SOCK_STREAM, 0);
    if (client == INVALID_SOCKET) {
        WSACleanup();
        emit_error("socket_unavailable", "socket creation failed");
        return 1;
    }
    DWORD timeout = 60000;
    setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, (const char *)&timeout, sizeof(timeout));
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_port = htons((unsigned short)port);
    address.sin_addr.s_addr = htonl(0x7f000001);
    if (connect(client, (struct sockaddr *)&address, sizeof(address)) != 0) {
        closesocket(client);
        WSACleanup();
        emit_error("tunnel_down", "multiprompt app not reachable on the loopback port");
        return 1;
    }
    if (send(client, request, request_length, 0) != request_length) {
        closesocket(client);
        WSACleanup();
        emit_error("tunnel_down", "multiprompt app did not accept the request");
        return 1;
    }
    int capacity = 262144;
    char *reply = (char *)calloc((size_t)capacity, 1);
    if (!reply) {
        closesocket(client);
        WSACleanup();
        emit_error("out_of_memory", "reply buffer unavailable");
        return 1;
    }
    int total = 0;
    while (total < capacity - 1) {
        int read = recv(client, reply + total, capacity - 1 - total, 0);
        if (read <= 0) break;
        total += read;
    }
    closesocket(client);
    WSACleanup();
    if (total == 0) {
        free(reply);
        emit_error("no_reply", "multiprompt app closed without a reply");
        return 1;
    }
    fwrite(reply, 1, (size_t)total, stdout);
    if (reply[total - 1] != '\n') printf("\n");
    fflush(stdout);
    const int ok = strstr(reply, "\"ok\":true") != NULL || strstr(reply, "\"ok\": true") != NULL;
    free(reply);
    return ok ? 0 : 1;
}
