fn lockWorkspaceRegistry() HANDLE {
    var path_buf: [512]u8 = undefined;
    const path = getWorkspaceRegistryPath(&path_buf) orelse return null;
    var name_buf: [96]u8 = undefined;
    const name = std.fmt.bufPrint(&name_buf, "Local\\ZigShell-registry-{x}", .{std.hash.Wyhash.hash(0, path)}) catch return null;
    var wide: [96]u16 = std.mem.zeroes([96]u16);
    for (name, 0..) |c, i| wide[i] = c;
    const mutex = CreateMutexW(null, 0, @ptrCast(&wide)) orelse return null;
    const result = WaitForSingleObject(mutex, if (app_state.g_main_hwnd != null and @import("launch_cache.zig").pending) 0 else 5000);
    if (result != 0 and result != 0x80) {
        _ = CloseHandle(mutex);
        return null;
    }
    return mutex;
}
