const std = @import("std");
const state = @import("account_state.zig");
const auth = @import("sync_auth.zig");
const a = std.heap.page_allocator;
const H = ?*anyopaque;
const L = std.unicode.utf8ToUtf16LeStringLiteral;
pub const origin = "https://account.multiprompt.dev";
extern "winhttp" fn WinHttpOpen([*:0]const u16, u32, ?[*:0]const u16, ?[*:0]const u16, u32) callconv(.winapi) H;
extern "winhttp" fn WinHttpSetTimeouts(H, i32, i32, i32, i32) callconv(.winapi) i32;
extern "winhttp" fn WinHttpConnect(H, [*:0]const u16, u16, u32) callconv(.winapi) H;
extern "winhttp" fn WinHttpOpenRequest(H, [*:0]const u16, [*:0]const u16, ?[*:0]const u16, ?[*:0]const u16, ?*anyopaque, u32) callconv(.winapi) H;
extern "winhttp" fn WinHttpAddRequestHeaders(H, [*:0]const u16, u32, u32) callconv(.winapi) i32;
extern "winhttp" fn WinHttpSetOption(H, u32, *const anyopaque, u32) callconv(.winapi) i32;
extern "winhttp" fn WinHttpSendRequest(H, ?[*:0]const u16, u32, ?*anyopaque, u32, u32, usize) callconv(.winapi) i32;
extern "winhttp" fn WinHttpReceiveResponse(H, ?*anyopaque) callconv(.winapi) i32;
extern "winhttp" fn WinHttpQueryHeaders(H, u32, ?[*:0]const u16, *anyopaque, *u32, ?*u32) callconv(.winapi) i32;
extern "winhttp" fn WinHttpReadData(H, [*]u8, u32, *u32) callconv(.winapi) i32;
extern "winhttp" fn WinHttpCloseHandle(H) callconv(.winapi) i32;
extern "shell32" fn ShellExecuteW(H, [*:0]const u16, [*:0]const u16, ?[*:0]const u16, ?[*:0]const u16, i32) callconv(.winapi) H;
extern "kernel32" fn GetTickCount64() callconv(.winapi) u64;
extern "kernel32" fn Sleep(u32) callconv(.winapi) void;
extern "kernel32" fn GetComputerNameW([*]u16, *u32) callconv(.winapi) i32;
const Address = extern struct { family: i16 = 2, port: u16 = 0, ip: u32 = 0x0100007f, zero: [8]u8 = @splat(0) };
extern "ws2_32" fn WSAStartup(u16, *[408]u8) callconv(.winapi) i32;
extern "ws2_32" fn WSACleanup() callconv(.winapi) i32;
extern "ws2_32" fn socket(i32, i32, i32) callconv(.winapi) usize;
extern "ws2_32" fn bind(usize, *const Address, i32) callconv(.winapi) i32;
extern "ws2_32" fn listen(usize, i32) callconv(.winapi) i32;
extern "ws2_32" fn getsockname(usize, *Address, *i32) callconv(.winapi) i32;
extern "ws2_32" fn ioctlsocket(usize, i32, *u32) callconv(.winapi) i32;
extern "ws2_32" fn accept(usize, ?*anyopaque, ?*i32) callconv(.winapi) usize;
extern "ws2_32" fn recv(usize, [*]u8, i32, i32) callconv(.winapi) i32;
extern "ws2_32" fn send(usize, [*]const u8, i32, i32) callconv(.winapi) i32;
extern "ws2_32" fn setsockopt(usize, i32, i32, *const anyopaque, i32) callconv(.winapi) i32;
extern "ws2_32" fn closesocket(usize) callconv(.winapi) i32;

pub const Response = struct {
    status: u32,
    bytes: []u8,
    hosts_supported: bool = false,
    removal_supported: bool = false,
    pub fn deinit(self: Response) void {
        std.crypto.secureZero(u8, self.bytes);
        a.free(self.bytes);
    }
};
pub fn layoutSupportsHosts(headers: []const u8) bool {
    return layoutSupports(headers, "hosts");
}
pub fn layoutSupportsRemoval(headers: []const u8) bool {
    return layoutSupports(headers, "host_removal");
}
fn layoutSupports(headers: []const u8, feature: []const u8) bool {
    var lines = std.mem.splitSequence(u8, headers, "\r\n");
    while (lines.next()) |line| {
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        if (!std.ascii.eqlIgnoreCase(std.mem.trim(u8, line[0..colon], " \t"), "X-Layout-Features")) continue;
        var tokens = std.mem.splitScalar(u8, line[colon + 1 ..], ',');
        while (tokens.next()) |token| {
            if (std.mem.eql(u8, std.mem.trim(u8, token, " \t"), feature)) return true;
        }
    }
    return false;
}
pub fn request(method: []const u8, path: []const u8, token: []const u8, body: []const u8) !Response {
    const session = WinHttpOpen(L("multiprompt-account"), 0, null, null, 0) orelse return error.Network;
    defer _ = WinHttpCloseHandle(session);
    _ = WinHttpSetTimeouts(session, 5000, 5000, 5000, 5000);
    const connection = WinHttpConnect(session, L("account.multiprompt.dev"), 443, 0) orelse return error.Network;
    defer _ = WinHttpCloseHandle(connection);
    const mw = try std.unicode.utf8ToUtf16LeAllocZ(a, method);
    defer a.free(mw);
    const pw = try std.unicode.utf8ToUtf16LeAllocZ(a, path);
    defer a.free(pw);
    const req = WinHttpOpenRequest(connection, mw.ptr, pw.ptr, null, null, null, 0x00800000) orelse return error.Network;
    defer _ = WinHttpCloseHandle(req);
    const disable_redirects: u32 = 2;
    _ = WinHttpSetOption(req, 63, &disable_redirects, @sizeOf(u32));
    const headers = try std.fmt.allocPrint(a, "Content-Type: application/json\r\nAccept: application/json\r\n{s}{s}{s}{s}", .{ if (token.len > 0) "Authorization: Bearer " else "", token, if (token.len > 0) "\r\n" else "", if (std.mem.eql(u8, path, "/v1/layout")) "X-Layout-Features: favorite,muted,used,visits,input,settings,hosts,host_removal,workspace_color\r\n" else "" });
    defer a.free(headers);
    const hw = try std.unicode.utf8ToUtf16LeAllocZ(a, headers);
    defer a.free(hw);
    if (WinHttpAddRequestHeaders(req, hw.ptr, 0xffffffff, 0x20000000) == 0 or WinHttpSendRequest(req, null, 0, if (body.len > 0) @ptrCast(@constCast(body.ptr)) else null, @intCast(body.len), @intCast(body.len), 0) == 0 or WinHttpReceiveResponse(req, null) == 0) return error.Network;
    var status: u32 = 0;
    var size: u32 = @sizeOf(u32);
    if (WinHttpQueryHeaders(req, 19 | 0x20000000, null, &status, &size, null) == 0) return error.Network;
    var hosts_supported = false;
    var removal_supported = false;
    var header_buf: [8192]u16 = @splat(0);
    size = @sizeOf(@TypeOf(header_buf));
    if (WinHttpQueryHeaders(req, 22, null, &header_buf, &size, null) != 0) {
        const raw = try std.unicode.utf16LeToUtf8Alloc(a, std.mem.trim(u16, header_buf[0 .. size / 2], &.{0}));
        defer a.free(raw);
        hosts_supported = layoutSupportsHosts(raw);
        removal_supported = layoutSupportsRemoval(raw);
    }
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(a);
    var chunk: [8192]u8 = undefined;
    const deadline = GetTickCount64() + 15000;
    while (GetTickCount64() < deadline) {
        var n: u32 = 0;
        if (WinHttpReadData(req, &chunk, chunk.len, &n) == 0) return error.Network;
        if (n == 0) return .{ .status = status, .bytes = try out.toOwnedSlice(a), .hosts_supported = hosts_supported, .removal_supported = removal_supported };
        if (out.items.len + n >= 1024 * 1024) return error.TooLarge;
        try out.appendSlice(a, chunk[0..n]);
    }
    return error.Network;
}
pub fn field(bytes: []const u8, key: []const u8) ![]u8 {
    const parsed = try std.json.parseFromSlice(std.json.Value, a, bytes, .{});
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidToken;
    const value = parsed.value.object.get(key) orelse return error.InvalidToken;
    if (value != .string or value.string.len == 0) return error.InvalidToken;
    return a.dupe(u8, value.string);
}
pub fn refresh(bytes: []const u8) !Response {
    const token = try field(bytes, "refresh_token");
    defer {
        std.crypto.secureZero(u8, token);
        a.free(token);
    }
    const body = try std.json.Stringify.valueAlloc(a, .{ .grant_type = "refresh_token", .refresh_token = token }, .{});
    defer {
        std.crypto.secureZero(u8, body);
        a.free(body);
    }
    return request("POST", "/oauth/token", "", body);
}
pub fn signIn(cancel: *const std.atomic.Value(bool)) !Response {
    if (cancel.load(.acquire)) return error.Cancelled;
    var wsa: [408]u8 = undefined;
    if (WSAStartup(0x0202, &wsa) != 0) return error.Network;
    defer _ = WSACleanup();
    const srv = socket(2, 1, 6);
    if (srv == std.math.maxInt(usize)) return error.Network;
    defer _ = closesocket(srv);
    const exclusive: i32 = 1;
    if (setsockopt(srv, 0xffff, ~@as(i32, 4), &exclusive, @sizeOf(i32)) != 0) return error.Network;
    var addr: Address = .{};
    if (bind(srv, &addr, @sizeOf(Address)) != 0 or listen(srv, 4) != 0) return error.Network;
    var len: i32 = @sizeOf(Address);
    if (getsockname(srv, &addr, &len) != 0) return error.Network;
    var nonblocking: u32 = 1;
    if (ioctlsocket(srv, @bitCast(@as(u32, 0x8004667e)), &nonblocking) != 0) return error.Network;
    var vb: [64]u8 = undefined;
    var sb: [43]u8 = undefined;
    var cb: [43]u8 = undefined;
    const pkce = try auth.generatePkce(&vb, &sb, &cb);
    defer std.crypto.secureZero(u8, &vb);
    const redirect = try std.fmt.allocPrint(a, "http://127.0.0.1:{d}/callback", .{@byteSwap(addr.port)});
    defer a.free(redirect);
    const config = auth.Config{ .client_id = "multiprompt-desktop", .authorization_endpoint = origin ++ "/login", .token_endpoint = origin ++ "/oauth/token", .redirect_uri = redirect };
    const url = try auth.buildAuthorizationUrl(a, config, pkce.state, pkce.challenge);
    defer a.free(url);
    var computer: [80]u16 = undefined;
    var count: u32 = computer.len;
    const name = if (GetComputerNameW(&computer, &count) != 0) try std.unicode.utf16LeToUtf8Alloc(a, computer[0..count]) else try a.dupe(u8, "Windows desktop");
    defer a.free(name);
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(a);
    for (name) |c| {
        if (std.ascii.isAlphanumeric(c) or c == '-') try encoded.append(a, c) else try encoded.appendSlice(a, "_");
    }
    const named = try std.fmt.allocPrint(a, "{s}&device_name={s}", .{ url, encoded.items });
    defer a.free(named);
    const uw = try std.unicode.utf8ToUtf16LeAllocZ(a, named);
    defer a.free(uw);
    const launched = ShellExecuteW(null, L("open"), uw.ptr, null, null, 1);
    if (@intFromPtr(launched) <= 32) return error.Browser;
    const deadline = GetTickCount64() + 180000;
    while (GetTickCount64() < deadline) {
        if (cancel.load(.acquire)) return error.Cancelled;
        const client = accept(srv, null, null);
        if (client == std.math.maxInt(usize)) {
            Sleep(30);
            continue;
        }
        defer _ = closesocket(client);
        var blocking: u32 = 0;
        _ = ioctlsocket(client, @bitCast(@as(u32, 0x8004667e)), &blocking);
        const timeout: u32 = 1000;
        _ = setsockopt(client, 0xffff, 0x1006, &timeout, @sizeOf(u32));
        _ = setsockopt(client, 0xffff, 0x1005, &timeout, @sizeOf(u32));
        var input: [8192]u8 = undefined;
        var used: usize = 0;
        const header_deadline = @min(deadline, GetTickCount64() + 3000);
        while (!cancel.load(.acquire) and GetTickCount64() < header_deadline and used < input.len and std.mem.indexOf(u8, input[0..used], "\r\n\r\n") == null) {
            const n = recv(client, input[used..].ptr, @intCast(input.len - used), 0);
            if (n <= 0) break;
            used += @intCast(n);
        }
        if (!std.mem.startsWith(u8, input[0..used], "GET /callback?")) continue;
        const end = std.mem.indexOf(u8, input[4..used], " HTTP/1.") orelse continue;
        const callback = auth.parseCallback(a, input[4..][0..end]) catch continue;
        defer auth.deinitCallback(a, callback);
        if (cancel.load(.acquire)) return error.Cancelled;
        switch (state.callback(callback.code, callback.state, callback.oauth_error, pkce.state)) {
            .ignore => continue,
            .denied => {
                const message = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nConnection: close\r\nCache-Control: no-store\r\n\r\nSign-in was declined. Return to multiprompt to retry.";
                _ = send(client, message.ptr, message.len, 0);
                return error.LoginDenied;
            },
            .exchange => {},
        }
        const body = try std.json.Stringify.valueAlloc(a, .{ .grant_type = "authorization_code", .code = callback.code.?, .code_verifier = pkce.verifier, .redirect_uri = redirect }, .{});
        defer {
            std.crypto.secureZero(u8, body);
            a.free(body);
        }
        const response = try request("POST", "/oauth/token", "", body);
        const message = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nConnection: close\r\nCache-Control: no-store\r\n\r\nReturn to multiprompt. You may close this window.";
        _ = send(client, message.ptr, message.len, 0);
        return response;
    }
    return error.LoginTimeout;
}

test "layout hosts capability requires an advertised complete token" {
    try std.testing.expect(layoutSupportsHosts("HTTP/1.1 200 OK\r\nX-Layout-Features: favorite,used,visits,input,hosts\r\n"));
    try std.testing.expect(!layoutSupportsHosts("X-Layout-Features: favorite,used,visits,input,settings\r\n"));
    try std.testing.expect(!layoutSupportsHosts(""));
    try std.testing.expect(!layoutSupportsHosts("X-Other: hosts\r\n"));
    try std.testing.expect(!layoutSupportsHosts("X-Layout-Features: ghostsmith,hosts-extra\r\n"));
}

test "layout hosts capability trims spaces and ignores header name case" {
    try std.testing.expect(layoutSupportsHosts("x-LaYoUt-FeAtUrEs: \t favorite , hosts \t, input \r\n"));
    try std.testing.expect(layoutSupportsHosts("X-Layout-Features: hosts"));
    try std.testing.expect(layoutSupportsHosts("X-Layout-Features: used\r\nX-Layout-Features: hosts\r\n"));
    try std.testing.expect(!layoutSupportsHosts("X-Layout-Features-Other: hosts\r\n"));
}

test "IGSH-600 removal support requires the exact advertised token" {
    try std.testing.expect(layoutSupportsRemoval("x-layout-features: hosts, host_removal \r\n"));
    try std.testing.expect(!layoutSupportsRemoval("X-Layout-Features: hosts,host_removal-extra\r\n"));
    try std.testing.expect(!layoutSupportsRemoval("X-Other: host_removal\r\n"));
    try std.testing.expect(!layoutSupportsRemoval("X-Layout-Features: hosts\r\n"));
    try std.testing.expect(!layoutSupportsRemoval(""));
}
