const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

test('session writes preserve detected agents and saved identities without another process scan', () => {
  const source = fs.readFileSync('src/session.zig', 'utf8');
  const marker = source.indexOf('const cf = ",\\"claude_session\\":true";');
  assert.ok(marker >= 0);
  const condition = source.lastIndexOf('            if (', marker);
  const scan = source.lastIndexOf('            if (!proc_cache_ready)', condition);
  const start = scan > source.lastIndexOf('const cwd_pre', condition) ? scan : condition;
  const end = source.indexOf('\n        }', marker);
  const production = source.slice(start, end);
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'session-agent-'));
  try {
    const file = path.join(directory, 'test.zig');
    fs.writeFileSync(file, `const std = @import("std");
const app_state = struct {
    var shells = [_]struct { pid: u32 = 0, claude_session: bool = false, claude_sid_len: usize = 0 }{.{}};
};
const Cache = struct {
    scans: usize = 0,
    fn refresh(self: *@This()) void { self.scans += 1; }
    fn findClaudeChildPid(_: *@This(), _: u32) ?u32 { return null; }
};
var proc_cache: Cache = .{};
var proc_cache_ready = false;
var json_buf: [128]u8 = undefined;
var pos: usize = 0;
const i = 0;
fn write() void {
    ${production}
}
test "detected active agent persists before a session identifier arrives" {
    app_state.shells[0] = .{ .claude_session = true };
    pos = 0; proc_cache = .{}; proc_cache_ready = false;
    write();
    try std.testing.expectEqualStrings(",\\\"claude_session\\\":true", json_buf[0..pos]);
    try std.testing.expectEqual(@as(usize, 0), proc_cache.scans);
}
test "saved session identity remains resumable" {
    app_state.shells[0] = .{ .claude_sid_len = 12 };
    pos = 0; proc_cache = .{}; proc_cache_ready = false;
    write();
    try std.testing.expectEqualStrings(",\\\"claude_session\\\":true", json_buf[0..pos]);
}
test "ordinary shells do not enumerate unrelated processes while saving" {
    app_state.shells[0] = .{};
    pos = 0; proc_cache = .{}; proc_cache_ready = false;
    write();
    try std.testing.expectEqualStrings("", json_buf[0..pos]);
    try std.testing.expectEqual(@as(usize, 0), proc_cache.scans);
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 60000 });
    assert.equal(result.status, 0, (result.stdout || '') + (result.stderr || ''));
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
