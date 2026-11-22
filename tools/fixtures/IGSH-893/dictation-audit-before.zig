pub fn dictationAudit(stage: []const u8, value: usize) void {
    var path_buf: [512]u8 = undefined;
    const appdata_len = GetEnvironmentVariableA("APPDATA", &path_buf, path_buf.len);
    if (appdata_len == 0 or appdata_len >= 470) return;
    const suffix = "\\ZigShell\\dictation-audit.log";
    const start: usize = @intCast(appdata_len);
    if (start + suffix.len >= path_buf.len) return;
    @memcpy(path_buf[start .. start + suffix.len], suffix);
    const h = win32OpenAppend(path_buf[0 .. start + suffix.len]) orelse return;
    defer _ = CloseHandle(h);
    writeAuditU64(h, GetTickCount64());
    win32WriteAll(h, "\t");
    win32WriteAll(h, stage);
    win32WriteAll(h, "\t");
    writeAuditU64(h, value);
    win32WriteAll(h, "\n");
}
