const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const read = name => fs.readFileSync(path.join(__dirname, '..', 'src', name), 'utf8');
const session = read('chat_session.zig');
const history = read('chat_history.zig');
function between(source, start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, start);
  return source.slice(a, b);
}

test('IGSH-871 unread divider stays above the first unread reply until leaving the tab', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-unread-visit-'));
  try {
    const source = `const std = @import("std");
const Block = struct { role: enum { prose, user, tool } = .prose, first: bool = true, message_id: u64, start: usize = 0, len: usize = 1 };
const md = struct { const Block = ThisBlock; };
const ThisBlock = Block;
const chat_history = struct {
${between(history, 'pub const ReadBoundary =', 'test "IGSH-814 history gap')}
${between(history, 'pub const NewMessages =', 'pub const Anchor =')}
};
const RECT = struct { bottom: i32 = 600 };
fn GetClientRect(_: ?usize, _: *RECT) i32 { return 1; }
fn saveSession() void {}
const app_state = struct {
  var active_shell: usize = 0;
  var shell_count: usize = 1;
  var shells = [_]struct { shell_id: u32 = 7, last_read_message_id: u64 = 11 }{.{}};
  var g_chat_active = true;
  var g_chat_blocks_from_file = true;
  var g_chat_cache_shell_id: u32 = 7;
  var g_chat_read_visit_shell_id: u32 = 0;
  var g_chat_read_visit_marker: u64 = 0;
  var g_chat_read_open_pending = false;
  var g_chat_read_open_ready = true;
  var g_chat_read_boundary: chat_history.ReadBoundary = .{};
  var g_chat_read_divider_y: i32 = 0;
  var g_chat_transcript_hwnd: ?usize = 1;
  var g_chat_scroll_y: i32 = 0;
  var g_chat_layout_reuse: usize = 0;
  var g_chat_layout_dirty = false;
  var g_chat_new_messages: chat_history.NewMessages = .{};
  var g_chat_blocks = [_]Block{.{ .message_id = 11 }, .{ .message_id = 22 }, .{ .message_id = 22, .first = false }, .{ .message_id = 33 }};
  var g_chat_block_count: usize = 4;
  var g_chat_layout_rects = [_]RECT{ .{}, .{}, .{}, .{} };
};
${between(session, 'pub fn chatReadBoundary()', 'pub fn chatDeferTranscriptLoad()')}
fn openTab() void {
${between(session, '    app_state.g_chat_new_messages = .{};', '    if (app_state.g_chat_read_open_pending)')}
  app_state.g_chat_read_open_pending = false;
  app_state.g_chat_read_open_ready = true;
}
test "divider stays at first unread after reading and clears on all-read revisit" {
  openTab();
  try std.testing.expectEqual(@as(?usize, 1), chatReadBoundary().index);
  try std.testing.expect(chatReadMark(true));
  try std.testing.expectEqual(@as(u64, 33), app_state.shells[0].last_read_message_id);
  try std.testing.expectEqual(@as(?usize, 1), chatReadBoundary().index);
  openTab();
  try std.testing.expectEqual(@as(?usize, 1), chatReadBoundary().index);
  app_state.g_chat_read_visit_shell_id = 0;
  openTab();
  try std.testing.expectEqual(@as(?usize, null), chatReadBoundary().index);
}
test "count tracks arrivals above bottom, not repaint or reaching bottom" {
  var count: chat_history.NewMessages = .{};
  count.arrive(0, true);
  count.arrive(2, true);
  count.arrive(1, true);
  try std.testing.expectEqual(@as(usize, 3), count.count());
  count.atBottom(true);
  try std.testing.expectEqual(@as(usize, 3), count.count());
  count.atBottom(false);
  count.arrive(1, false);
  try std.testing.expectEqual(@as(usize, 0), count.count());
}
`;
    fs.writeFileSync(path.join(dir, 'test.zig'), source);
    const result = spawnSync(process.env.ZIG_EXE || (process.platform === 'win32' ? 'zig' : path.join(os.homedir(), '.local/zig-0.16.0/zig')), ['test', '-fno-llvm', 'test.zig'], { cwd: dir, encoding: 'utf8', timeout: 60000 });
    assert.equal(result.status, 0, JSON.stringify(result));
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
