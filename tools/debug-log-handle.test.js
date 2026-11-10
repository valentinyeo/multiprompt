const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const stubs = {
  'win32.zig': `pub const HANDLE = ?*anyopaque;
pub const DWORD = u32;
pub const BOOL = i32;
pub const WORD = u16;
pub const LPCWSTR = [*:0]const u16;
pub const SYSTEMTIME = extern struct { year: WORD, month: WORD, day_of_week: WORD, day: WORD, hour: WORD, minute: WORD, second: WORD, milliseconds: WORD };
pub const MOVEFILE_REPLACE_EXISTING: DWORD = 1;
pub const FILE_APPEND_DATA: DWORD = 4;
pub const FILE_SHARE_READ: DWORD = 1;
pub const FILE_SHARE_WRITE: DWORD = 2;
pub const FILE_SHARE_DELETE: DWORD = 4;
pub const OPEN_ALWAYS: DWORD = 4;
pub const FILE_ATTRIBUTE_NORMAL: DWORD = 0x80;
pub const INVALID_HANDLE_VALUE_PTR: HANDLE = @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))));
pub var opens: usize = 0;
pub var lines: usize = 0;
pub fn Sleep(_: DWORD) void {}
pub fn CloseHandle(_: HANDLE) BOOL { return 1; }
pub fn GetFileSizeEx(_: HANDLE, size: *i64) BOOL { size.* = 1024; return 1; }
pub fn MoveFileExW(_: LPCWSTR, _: LPCWSTR, _: DWORD) BOOL { return 1; }
pub fn GetTickCount64() u64 { return 0; }
pub fn GetEnvironmentVariableA(_: [*:0]const u8, buf: ?[*]u8, _: DWORD) DWORD {
    const value = "C:\\\\appdata";
    @memcpy(buf.?[0..value.len], value);
    return value.len;
}
pub fn GetLocalTime(st: *SYSTEMTIME) void {
    st.* = .{ .year = 2026, .month = 11, .day_of_week = 2, .day = 10, .hour = 1, .minute = 2, .second = 3, .milliseconds = 4 };
}
pub fn CreateFileW(_: LPCWSTR, _: DWORD, _: DWORD, _: ?*anyopaque, _: DWORD, _: DWORD, _: HANDLE) HANDLE {
    opens += 1;
    return @ptrFromInt(8);
}
`,
  'file_io.zig': `const std = @import("std");
const w = @import("win32.zig");
pub fn win32OpenAppend(_: []const u8) w.HANDLE {
    w.opens += 1;
    return @ptrFromInt(8);
}
pub fn win32WidePath(out: []u16, path: []const u8) ?[:0]u16 {
    const n = std.unicode.utf8ToUtf16Le(out[0 .. out.len - 1], path) catch return null;
    out[n] = 0;
    return out[0..n :0];
}
pub fn win32WriteAll(_: w.HANDLE, bytes: []const u8) void {
    if (bytes.len > 0 and bytes[bytes.len - 1] == '\\n') w.lines += 1;
}
pub fn win32MakeDir(_: []const u8) void {}
`,
  'startup.zig': '',
  'capacity.zig': '',
  'session.zig': '',
  'chat_composer.zig': '',
  'harness.zig': `const std = @import("std");
const diagnostics = @import("diagnostics.zig");
const w = @import("win32.zig");
test "two hundred log lines reuse one open log file" {
    for (0..200) |_| diagnostics.syncLog("[photo-proof] expanded target=7 rect=20,193,56,229");
    std.debug.print("IGSH-1907 log_opens_per_200_lines={d} lines={d}\\n", .{ w.opens, w.lines });
    try std.testing.expectEqual(@as(usize, 200), w.lines);
    try std.testing.expect(w.opens <= 4);
}
`,
};

test('IGSH-1907 writing the debug log does not reopen the file for every line', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'debug-log-handle-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  require('./zig-copy').copyZig(['diagnostics.zig'], dir);
  const appState = fs.readFileSync(path.join(__dirname, '../src/app_state.zig'), 'utf8');
  const mutexStart = appState.indexOf('pub const SpinMutex = struct {');
  const mutex = appState.slice(mutexStart, appState.indexOf('\n};', mutexStart) + 3);
  fs.writeFileSync(path.join(dir, 'app_state.zig'), `const std = @import("std");\n${mutex}\npub var g_debug_log_mutex: SpinMutex = .{};\n`);
  for (const [name, text] of Object.entries(stubs)) fs.writeFileSync(path.join(dir, name), text);
  const run = spawnSync(process.env.ZIG || 'zig', ['test', 'harness.zig'], {
    cwd: dir, encoding: 'utf8', timeout: 240000, maxBuffer: 16 * 1024 * 1024,
  });
  const output = `${run.stdout || ''}${run.stderr || ''}`;
  console.log(output.split('\n').filter(line => line.includes('IGSH-1907')).join('\n'));
  assert.equal(run.error, undefined, output);
  assert.match(output, /IGSH-1907 log_opens_per_200_lines=\d+ lines=200/, output);
  assert.equal(run.status, 0, output);
});
