const std = @import("std");
const win = @import("win32.zig");

pub var peer_check: *const fn (win.SOCKET) bool = peerIsSameUser;

pub fn peerIsSameUser(client: win.SOCKET) bool {
    var local: win.SOCKADDR_IN = undefined;
    var remote: win.SOCKADDR_IN = undefined;
    var local_len: i32 = @sizeOf(win.SOCKADDR_IN);
    var remote_len: i32 = @sizeOf(win.SOCKADDR_IN);
    if (win.getsockname(client, &local, &local_len) != 0 or
        win.getpeername(client, &remote, &remote_len) != 0 or
        local_len != @sizeOf(win.SOCKADDR_IN) or remote_len != @sizeOf(win.SOCKADDR_IN) or
        local.sin_family != win.AF_INET or remote.sin_family != win.AF_INET) return false;

    var size: u32 = 0;
    if (win.GetExtendedTcpTable(null, &size, 0, win.AF_INET, 5, 0) != 122) return false;
    const allocator = std.heap.page_allocator;
    const pid = lookup: while (true) {
        if (size < @sizeOf(u32)) return false;
        const words = allocator.alloc(u32, (@as(usize, size) + 3) / 4) catch return false;
        defer allocator.free(words);
        const result = win.GetExtendedTcpTable(words.ptr, &size, 0, win.AF_INET, 5, 0);
        if (result == 122) continue;
        if (result != 0 or size < @sizeOf(u32) or size > words.len * 4) return false;
        const count = words[0];
        if (count > (size - @sizeOf(u32)) / @sizeOf(win.MIB_TCPROW_OWNER_PID)) return false;
        const rows: [*]const win.MIB_TCPROW_OWNER_PID = @ptrCast(words.ptr + 1);
        for (rows[0..count]) |row| {
            if (row.local_addr == remote.sin_addr and
                (row.local_port & 0xffff) == remote.sin_port and
                row.remote_addr == local.sin_addr and
                (row.remote_port & 0xffff) == local.sin_port) break :lookup row.owning_pid;
        }
        return false;
    };
    if (pid == 0) return false;
    if (pid == win.GetCurrentProcessId()) return true;
    const process = win.OpenProcess(win.PROCESS_QUERY_LIMITED_INFORMATION, 0, pid) orelse return false;
    defer _ = win.CloseHandle(process);
    var peer_token: win.HANDLE = null;
    if (win.OpenProcessToken(process, 0x0008, &peer_token) == 0) return false;
    defer _ = win.CloseHandle(peer_token);
    var own_token: win.HANDLE = null;
    if (win.OpenProcessToken(win.GetCurrentProcess(), 0x0008, &own_token) == 0) return false;
    defer _ = win.CloseHandle(own_token);
    var users: [2][]usize = .{ &.{}, &.{} };
    defer for (users) |user| allocator.free(user);
    var sids: [2]*const anyopaque = undefined;
    for ([_]win.HANDLE{ peer_token, own_token }, 0..) |token, i| {
        var needed: u32 = 0;
        if (win.GetTokenInformation(token, 1, null, 0, &needed) != 0 or win.GetLastError() != 122 or needed < @sizeOf(win.TOKEN_USER)) return false;
        users[i] = allocator.alloc(usize, (@as(usize, needed) + @sizeOf(usize) - 1) / @sizeOf(usize)) catch return false;
        const capacity = needed;
        if (win.GetTokenInformation(token, 1, users[i].ptr, capacity, &needed) == 0 or needed > capacity or needed < @sizeOf(win.TOKEN_USER)) return false;
        const user: *const win.TOKEN_USER = @ptrCast(users[i].ptr);
        sids[i] = user.sid orelse return false;
    }
    return win.EqualSid(sids[0], sids[1]) != 0;
}
