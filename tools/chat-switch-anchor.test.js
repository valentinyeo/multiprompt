const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const read = name => fs.readFileSync(path.join(__dirname, '..', 'src', name), 'utf8');
const session = read('chat_session.zig');
const history = read('chat_history.zig');
const render = read('chat_render.zig');
const fixture = name => fs.readFileSync(path.join(__dirname, 'fixtures', 'IGSH-1924', name), 'utf8');
const masterScroll = fixture('master-scroll.txt');
const post918Scroll = fixture('post918-scroll.txt');
const post918History = history.slice(0, history.indexOf('pub fn openScroll(')) + fixture('post918-open-scroll.txt') + history.slice(history.indexOf('pub const MISSING_RETRY_MS'));

function between(source, start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, start);
  return source.slice(a, b);
}

const renderScroll = between(render, 'pub fn chatSetTopPad(', 'pub fn chatTopPad()') + between(render, 'pub fn chatMaxScroll()', 'pub fn chatScrollStateChanged(') + between(render, 'pub fn chatJumpToNewest()', 'pub fn chatScrollBy(');

const harness = (scroll, historySource, renderSource) => `const std = @import("std");
const RECT = struct { left: i32 = 0, top: i32 = 0, right: i32 = 800, bottom: i32 = 600 };
const chat_history = struct {
${between(history, 'pub const ReadBoundary = struct', '\n')}
${between(historySource, 'pub const Anchor =', 'pub const MISSING_RETRY_MS')}
};
const BLOCK_H: i32 = 100;
const DIVIDER_H: i32 = 28;
const UNREAD_FROM: usize = 30;
const app_state = struct {
  var g_chat_browser_swap = struct { shell_id: u32 = 0 }{};
  var g_chat_active = true;
  var g_chat_transcript_hwnd: ?usize = 1;
  var active_shell: usize = 0;
  var shell_count: usize = 1;
  var g_chat_scroll_y: i32 = 0;
  var g_chat_content_h: i32 = 0;
  var g_chat_top_pad: i32 = 20;
  var g_chat_layout_top_pad: i32 = 20;
  var g_chat_layout_reuse: usize = 0;
  var g_chat_layout_dirty = false;
  var g_chat_hover_copy: ?usize = null;
  var g_chat_hover_link: ?usize = null;
  var g_chat_echo_layout_count: usize = 0;
  var g_chat_echo_layout: [1]RECT = undefined;
  var g_chat_batch_boundary: chat_history.ReadBoundary = .{};
  var g_chat_batch_divider_y: i32 = 0;
  var has_unread = true;
  var tail_h: i32 = 0;
  var next_blocks: ?usize = null;
  var g_chat_read_open_pending = false;
  var g_chat_read_open_ready = false;
  var g_chat_read_hold = false;
  var g_chat_scroll_bottom_pending = false;
  var g_chat_scrolled_up = false;
  var g_chat_prepend_pending = false;
  var g_chat_read_boundary: chat_history.ReadBoundary = .{};
  var g_chat_read_divider_y: i32 = 0;
  var g_chat_block_count: usize = 0;
  var g_chat_layout_rects: [128]RECT = undefined;
};
fn chatViewClientRect(rc: *RECT) void { rc.* = .{}; }
fn InvalidateRect(_: ?usize, _: ?*const RECT, _: i32) i32 { return 1; }
fn chatEchoMatchActive() void {}
fn chatScrollStateChanged(viewport_h: i32) void {
${between(render, '    app_state.g_chat_scrolled_up =', '\n').replaceAll('uiScaled(4)', '4')}
}
fn refreshChatBlockCache(_: bool) bool {
  if (app_state.next_blocks) |count| app_state.g_chat_block_count = count;
  app_state.next_blocks = null;
  return true;
}
fn uiScaled(value: i32) i32 { return value; }
fn chatScrollActivity() void {}
const HistoryEntry = struct {
  pending: bool = false,
  history: struct { start: u64 = 0 } = .{},
  before: u64 = 0,
  show_older: bool = false,
  next: u64 = 0,
};
fn chatHistoryEntry(_: u32) ?*HistoryEntry { return null; }
fn chatFileIdentity() u32 { return 0; }
fn chatFileRequest(_: u32) void {}
${between(render, 'pub fn chatScrollBy(', 'const scroll_ui =')}
fn chatReadBoundary() chat_history.ReadBoundary {
  return if (app_state.has_unread and app_state.g_chat_block_count > UNREAD_FROM) .{ .index = UNREAD_FROM } else .{};
}
fn chatRelayout(_: i32) void {
  const boundary = chatReadBoundary();
  app_state.g_chat_read_boundary = boundary;
  var y: i32 = app_state.g_chat_top_pad;
  for (0..app_state.g_chat_block_count) |i| {
    if (boundary.index == i) {
      app_state.g_chat_read_divider_y = y;
      y += DIVIDER_H;
    }
    app_state.g_chat_layout_rects[i] = .{ .top = y, .bottom = y + BLOCK_H };
    y += BLOCK_H;
  }
  app_state.g_chat_content_h = y + app_state.tail_h;
  app_state.g_chat_layout_reuse = app_state.g_chat_block_count;
  app_state.g_chat_layout_top_pad = app_state.g_chat_top_pad;
}
${renderSource}
${scroll.replaceAll('@import("chat_render.zig").chatViewClientRect', 'chatViewClientRect')}
fn openTab(blocks: usize, unread: bool) void {
  app_state.has_unread = unread;
  app_state.tail_h = 0;
  app_state.g_chat_top_pad = 20;
  app_state.g_chat_content_h = 0;
  app_state.g_chat_block_count = blocks;
  app_state.g_chat_scroll_y = 0;
  app_state.g_chat_scrolled_up = false;
  app_state.g_chat_read_boundary = .{};
  app_state.g_chat_read_hold = true;
  chatRelayoutPreservingScroll(800, 600);
}
fn dividerTop() i32 { return app_state.g_chat_read_divider_y - app_state.g_chat_top_pad; }
test "IGSH-1924 a switch opens on the New divider and later content never moves it" {
  openTab(40, true);
  try std.testing.expect(app_state.g_chat_read_boundary.index != null);
  try std.testing.expectEqual(dividerTop(), app_state.g_chat_scroll_y);
  const first = app_state.g_chat_scroll_y;
  app_state.next_blocks = 56;
  refreshChatTranscript(false);
  try std.testing.expectEqual(first, app_state.g_chat_scroll_y);
  app_state.next_blocks = 40;
  refreshChatTranscript(false);
  try std.testing.expectEqual(first, app_state.g_chat_scroll_y);
  app_state.g_chat_top_pad = 82;
  chatRelayoutPreservingScroll(800, 600);
  try std.testing.expectEqual(dividerTop(), app_state.g_chat_scroll_y);
  app_state.g_chat_top_pad = 20;
}
test "IGSH-1924 a stale cache lands on the divider once the newest page arrives" {
  openTab(UNREAD_FROM, true);
  try std.testing.expectEqual(app_state.g_chat_content_h - 600, app_state.g_chat_scroll_y);
  app_state.next_blocks = 40;
  refreshChatTranscript(false);
  try std.testing.expectEqual(dividerTop(), app_state.g_chat_scroll_y);
}
test "IGSH-1924 reader scroll releases the anchor and new content follows the bottom again" {
  openTab(40, true);
  app_state.g_chat_read_hold = false;
  app_state.g_chat_scroll_y = app_state.g_chat_content_h - 600;
  chatScrollStateChanged(600);
  app_state.next_blocks = 50;
  refreshChatTranscript(false);
  try std.testing.expectEqual(app_state.g_chat_content_h - 600, app_state.g_chat_scroll_y);
}
test "IGSH-1924 short unread stays at New while the tail changes" {
  openTab(UNREAD_FROM + 1, true);
  const first = dividerTop();
  try std.testing.expectEqual(first, app_state.g_chat_scroll_y);
  for ([_]i32{ 1600, 0, 700, 0 }) |tail| {
    app_state.tail_h = tail;
    refreshChatTranscript(false);
    try std.testing.expectEqual(first, app_state.g_chat_scroll_y);
    chatRelayoutPreservingScroll(800, 600);
    try std.testing.expectEqual(first, app_state.g_chat_scroll_y);
  }
  chatSetTopPad(82);
  try std.testing.expectEqual(dividerTop(), app_state.g_chat_scroll_y);
}
test "IGSH-1924 caught-up stays on its newest message through tail changes" {
  openTab(40, false);
  const first = app_state.g_chat_content_h - 600;
  try std.testing.expectEqual(first, app_state.g_chat_scroll_y);
  for ([_]i32{ 1734, 0, 442, 0 }) |tail| {
    app_state.tail_h = tail;
    refreshChatTranscript(false);
    try std.testing.expectEqual(first, app_state.g_chat_scroll_y);
    chatRelayoutPreservingScroll(800, 600);
    try std.testing.expectEqual(first, app_state.g_chat_scroll_y);
  }
  chatSetTopPad(82);
  try std.testing.expectEqual(first + 62, app_state.g_chat_scroll_y);
}
test "IGSH-1924 short caught-up chat stays still with live additions" {
  openTab(1, false);
  const first = app_state.g_chat_content_h - 600;
  try std.testing.expect(first < 0);
  app_state.tail_h = 900;
  refreshChatTranscript(false);
  try std.testing.expectEqual(first, app_state.g_chat_scroll_y);
  app_state.tail_h = 0;
  refreshChatTranscript(false);
  try std.testing.expectEqual(first, app_state.g_chat_scroll_y);
}
test "IGSH-1924 scrolling away from a short unread boundary is gradual" {
  openTab(UNREAD_FROM + 1, true);
  const first = app_state.g_chat_scroll_y;
  chatScrollBy(100);
  try std.testing.expectEqual(first - 100, app_state.g_chat_scroll_y);
  try std.testing.expect(!app_state.g_chat_read_hold);
  refreshChatTranscript(false);
  try std.testing.expectEqual(first - 100, app_state.g_chat_scroll_y);
  chatScrollBy(100);
  try std.testing.expectEqual(first - 200, app_state.g_chat_scroll_y);
}
test "IGSH-1924 newest releases the hold even at an unchanged bottom" {
  openTab(40, false);
  chatJumpToNewest();
  try std.testing.expect(!app_state.g_chat_read_hold);
  app_state.next_blocks = 50;
  refreshChatTranscript(false);
  try std.testing.expectEqual(app_state.g_chat_content_h - 600, app_state.g_chat_scroll_y);
  openTab(UNREAD_FROM + 1, true);
  chatJumpToNewest();
  try std.testing.expect(!app_state.g_chat_read_hold);
  try std.testing.expectEqual(app_state.g_chat_content_h - 600, app_state.g_chat_scroll_y);
}
`;

function run(scroll, historySource = history, renderSource = renderScroll) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-switch-anchor-'));
  try {
    fs.writeFileSync(path.join(dir, 'test.zig'), harness(scroll, historySource, renderSource));
    return spawnSync(process.env.ZIG_EXE || process.env.ZIG || 'zig', ['test', '-j1', 'test.zig'], { cwd: dir, encoding: 'utf8', timeout: 90000 });
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

const current = between(session, 'pub fn refreshChatTranscript(force: bool) void {', 'pub fn chatLatestAgentReply');

test('IGSH-1924 switching to an unread chat stays on the New divider', () => {
  const result = run(current);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stderr, /All 8 tests passed/);
});

test('IGSH-1924 the previous switch path follows the bottom past the divider', () => {
  const result = run(masterScroll);
  assert.notEqual(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stderr, /expected -?\d+, found -?\d+/);
});

test('IGSH-1924 the first fix still jumps on short unread and caught-up chats', () => {
  const result = run(post918Scroll, post918History, fixture('post918-render-scroll.txt'));
  assert.notEqual(result.status, 0, result.stdout + result.stderr);
  for (const name of ['short unread stays at New while the tail changes', 'caught-up stays on its newest message through tail changes']) {
    assert.match(result.stderr, new RegExp(`${name}[^]*?FAIL \\(TestExpectedEqual\\)`));
  }
  assert.match(result.stderr, /expected -?\d+, found -?\d+/);
});

test('IGSH-1924 legacy and caught-up tabs also hold their initial reading position', () => {
  assert.match(session, /g_chat_read_hold = app_state.active_shell < app_state.shell_count;/);
});

test('IGSH-1924 the warm pass runs while the open chat streams', () => {
  const warm = between(session, 'pub fn chatWarmOftenUsed', 'pub fn chatSwitchDidPaint');
  assert.match(warm, /entry\.\?\.stream == null and \(entry\.\?\.pending/);
});
