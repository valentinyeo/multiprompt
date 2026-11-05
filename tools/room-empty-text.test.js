const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

test('IGSH-1697 room text skips empty strings and draws nonempty strings', t => {
  const source = fs.readFileSync(path.join(__dirname, '../src/room_view.zig'), 'utf8');
  const start = source.indexOf('fn text(');
  const end = source.indexOf('\n}', start);
  assert.ok(start >= 0 && end > start, 'production text function exists');
  const production = source.slice(start, end + 2);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'room-empty-text-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const file = path.join(dir, 'room-text.zig');
  fs.writeFileSync(file, `const std = @import("std");
const w = struct {
    const HANDLE = ?*anyopaque;
    const RECT = struct { left: i32, top: i32, right: i32, bottom: i32 };
    const DT_NOPREFIX: u32 = 0x800;
    var colors: usize = 0;
    var draws: usize = 0;
    var length: i32 = 0;
    var flags: u32 = 0;
    var first: u16 = 0;
    fn SetTextColor(_: HANDLE, _: u32) u32 { colors += 1; return 0; }
    fn DrawTextW(_: HANDLE, value: [*]const u16, len: i32, _: *RECT, format: u32) i32 {
        draws += 1;
        length = len;
        flags = format;
        if (len > 0) first = value[0];
        return 0;
    }
};
fn rgb(color: u32) u32 { return color; }
${production}
test "empty text never reaches Win32" {
    w.colors = 0;
    w.draws = 0;
    text(null, &.{}, .{ .left = 0, .top = 0, .right = 10, .bottom = 10 }, 0, 0);
    try std.testing.expectEqual(@as(usize, 0), w.colors);
    try std.testing.expectEqual(@as(usize, 0), w.draws);
}
test "nonempty UTF-16 text reaches DrawTextW" {
    w.colors = 0;
    w.draws = 0;
    const value = [_]u16{ 'A', 0x03a9 };
    text(null, &value, .{ .left = 0, .top = 0, .right = 10, .bottom = 10 }, 0, 0x20);
    try std.testing.expectEqual(@as(usize, 1), w.colors);
    try std.testing.expectEqual(@as(usize, 1), w.draws);
    try std.testing.expectEqual(@as(i32, 2), w.length);
    try std.testing.expectEqual(@as(u32, 0x820), w.flags);
    try std.testing.expectEqual(@as(u16, 'A'), w.first);
}
`);
  const result = spawnSync(process.env.ZIG || 'zig', ['test', '-j1', file], { encoding: 'utf8', timeout: 120000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
