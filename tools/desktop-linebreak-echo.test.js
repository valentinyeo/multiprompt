const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');

function run(control) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'desktop-linebreak-'));
  try {
    copyZig(['chat_echo.zig', 'chat_history.zig', 'chat_live.zig'], dir);
    const source = fs.readFileSync(path.join(__dirname, '../src/chat_send.zig'), 'utf8');
    const start = source.indexOf('pub fn chatEchoRowLanded(');
    const end = source.indexOf('\n}', start) + 2;
    assert.ok(start >= 0 && end > start, 'production pending-row visibility exists');
    let landed = source.slice(start, end);
    if (control === 'duplicate-row') {
      const changed = landed.replace('return true;', 'return false;');
      assert.notEqual(changed, landed);
      landed = changed;
    }
    if (control === 'raw-comparison') {
      const file = path.join(dir, 'chat_echo.zig');
      const echo = fs.readFileSync(file, 'utf8');
      const begin = echo.indexOf('pub fn sameText(');
      const finish = echo.indexOf('\n}', begin) + 2;
      assert.ok(begin >= 0 && finish > begin);
      fs.writeFileSync(file, echo.slice(0, begin) + 'pub fn sameText(a: []const u16, b: []const u16) bool { return std.mem.eql(u16, a, b); }' + echo.slice(finish));
    }
    fs.writeFileSync(path.join(dir, 'parity.zig'), String.raw`
const std = @import("std");
const echo = @import("chat_echo.zig");
const history = @import("chat_history.zig");
const live = @import("chat_live.zig");
const md = @import("chat_markdown.zig");
const app_state = @This();
const ChatOutboxEntry = struct { key: [7]u8 = "desktop".*, key_len: usize = 7, message_wire_id: [81:0]u8 = @splat(0) };
pub var shells = [_]struct { shell_id: u32 }{.{ .shell_id = 101 }};
pub var shell_count: usize = 1;
pub var g_chat_blocks: []const md.Block = &.{};
pub var g_chat_block_count: usize = 0;
fn chatOutboxShellForKey(key: []const u8) ?usize { return if (std.mem.eql(u8, key, "desktop")) 0 else null; }
` + landed + String.raw`
test "IGSH-1642 desktop recognizes Windows line breaks without changing message text" {
    const lf = std.unicode.utf8ToUtf16LeStringLiteral("First line\nSecond line 😀");
    const crlf = std.unicode.utf8ToUtf16LeStringLiteral("First line\r\nSecond line 😀   ");
    try std.testing.expect(echo.sameText(lf, crlf));
    try std.testing.expect(echo.sameText(crlf, lf));
    try std.testing.expect(!echo.sameText(lf, std.unicode.utf8ToUtf16LeStringLiteral("First line\nDifferent line 😀")));
    try std.testing.expect(std.mem.indexOfScalar(u16, crlf, '\r') != null);
}

test "IGSH-1642 live CRLF transcript hides its local copy but keeps deliberate repeats" {
    const a = std.testing.allocator;
    const sid = "11111111-2222-3333-4444-555555555555";
    var h: history.History = .{};
    defer h.deinit(a);
    defer { g_chat_blocks = &.{}; g_chat_block_count = 0; }
    _ = live.begin(101, 0, sid);
    defer live.release(101);
    var pending: ChatOutboxEntry = .{};
    @memcpy(pending.message_wire_id[0..7], "mp-crlf");
    try std.testing.expect(!chatEchoRowLanded(pending));
    const page = "{\"result\":{\"events\":[{\"seq\":1,\"event\":{\"kind\":\"turn.started\",\"turn\":\"turn-1\",\"payload\":{\"message_id\":\"mp-crlf\",\"uuids\":[\"user-1\"]}}}]}}";
    try std.testing.expect(live.applyPage(101, sid, page));
    try std.testing.expect(!chatEchoRowLanded(pending));
    const row = "{\"role\":\"user\",\"id\":\"user-1\",\"offset\":0,\"end\":100,\"timestamp\":\"2026-11-01T12:00:00Z\",\"text\":\"First line\\r\\nSecond line 😀   \"}";
    try h.upsertNativeRows(a, &.{row}, 1, 0);
    g_chat_blocks = h.blocks.items;
    g_chat_block_count = h.blocks.items.len;
    try std.testing.expectEqual(@as(usize, 1), h.blocks.items.len);
    try std.testing.expectEqual(md.Role.user, h.blocks.items[0].role);
    try std.testing.expect(chatEchoRowLanded(pending));
    const shown_rows = h.blocks.items.len + @as(usize, if (chatEchoRowLanded(pending)) 0 else 1);
    try std.testing.expectEqual(@as(usize, 1), shown_rows);
    try std.testing.expect(echo.sameText(std.unicode.utf8ToUtf16LeStringLiteral("First line\nSecond line 😀"), h.text.items));
    var repeated = pending;
    repeated.message_wire_id = @splat(0);
    @memcpy(repeated.message_wire_id[0..8], "mp-again");
    try std.testing.expect(!chatEchoRowLanded(repeated));
    try std.testing.expectEqual(@as(usize, 2), h.blocks.items.len + @as(usize, if (chatEchoRowLanded(repeated)) 0 else 1));
    const again = "{\"role\":\"user\",\"id\":\"user-2\",\"offset\":100,\"end\":200,\"timestamp\":\"2026-11-01T12:01:00Z\",\"text\":\"First line\\r\\nSecond line 😀   \"}";
    try h.upsertNativeRows(a, &.{again}, 1, 0);
    g_chat_blocks = h.blocks.items;
    g_chat_block_count = h.blocks.items.len;
    try std.testing.expectEqual(@as(usize, 2), h.blocks.items.len);
    try std.testing.expect(h.blocks.items[0].row_key != h.blocks.items[1].row_key);
}
`);
    return spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'parity.zig'), '--test-filter', 'IGSH-1642'], { encoding: 'utf8', timeout: 120000 });
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('IGSH-1642 existing desktop CRLF matching and one-copy live rows', () => {
  const result = run();
  assert.equal(result.error, undefined);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stderr, /All 2 tests passed/);
  console.log(result.stderr.trim());
});

for (const control of ['raw-comparison', 'duplicate-row']) {
  test(`IGSH-1642 parity oracle rejects ${control}`, () => {
    const result = run(control);
    assert.equal(result.error, undefined);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /FAIL \(TestUnexpectedResult\)/);
  });
}
