pub fn notifyListenerThread() void {
    crash_recorder.guardThread();
    var wsa: WSADATA = undefined;
    if (WSAStartup(0x0202, &wsa) != 0) {
        logNotifyListenerStatus("WSAStartup failed", 0, WSAGetLastError());
        return;
    }

    var srv: SOCKET = INVALID_SOCKET;
    var bound_port: u16 = 0;
    for (NOTIFY_PORTS) |port| {
        const s = socket(AF_INET, SOCK_STREAM, 0);
        if (s == INVALID_SOCKET) continue;
        var addr = SOCKADDR_IN{
            .sin_family = AF_INET,
            .sin_port = htons(port),
            .sin_addr = 0x0100007F,
            .sin_zero = std.mem.zeroes([8]u8),
        };
        if (bind(s, &addr, @sizeOf(SOCKADDR_IN)) != 0) {
            _ = closesocket(s);
            continue;
        }
        if (listen(s, 5) != 0) {
            _ = closesocket(s);
            continue;
        }
        srv = s;
        bound_port = port;
        break;
    }
    if (srv == INVALID_SOCKET) {
        logNotifyListenerStatus("no free notify port", 0, WSAGetLastError());
        return;
    }
    app_state.g_notify_bound_port = bound_port;
    logNotifyListenerStatus("listening", bound_port, 0);

    while (true) {
        const client = accept(srv, null, null);
        if (client == INVALID_SOCKET) continue;

        var buf: [NOTIFY_PAYLOAD_CAP]u8 = undefined;
        const n = recv(client, &buf, @intCast(buf.len), 0);

        if (n <= 0) {
            _ = closesocket(client);
            continue;
        }

        const trimmed = std.mem.trim(u8, buf[0..@intCast(n)], &[_]u8{ '\n', '\r', ' ', '\t' });
        if (trimmed.len == 0) {
            _ = closesocket(client);
            continue;
        }

        if (std.mem.startsWith(u8, trimmed, "DIAG:")) {
            sendDiagResponseForRequest(client, trimmed["DIAG:".len..]);
            _ = closesocket(client);
            continue;
        }

        _ = closesocket(client);
        enqueueNotification(trimmed);
        if (app_state.g_main_hwnd != null) {
            _ = PostMessageW(app_state.g_main_hwnd, WM_APP_NOTIFY, 0, 0);
        }
    }
}
