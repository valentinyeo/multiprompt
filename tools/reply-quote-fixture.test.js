const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');

test('the byte-preserved Android fixture has all twelve named cases and is embedded by Zig', () => {
  const fixture = JSON.parse(read('src/testdata/reply-quote-fixture.json'));
  assert.deepEqual(fixture.map(c => c.name), [
    'short single line', 'multi-line', 'exactly 10 lines', '11+ lines',
    'blank lines inside', 'trailing whitespace', 'Markdown and code', 'non-ASCII',
    'null quote', 'blank quote', 'blank reply', 'CRLF',
  ]);
  assert.equal(fixture.find(c => c.name === 'null quote').quoted, null);
  for (const c of fixture) {
    assert.ok(c.quoted === null || typeof c.quoted === 'string');
    assert.equal(typeof c.reply, 'string');
    assert.equal(typeof c.expected, 'string');
  }
  assert.match(read('src/chat_reply.zig'), /@embedFile\("testdata\/reply-quote-fixture.json"\)/);
  assert.match(read('build.zig'), /"src\/chat_reply.zig"/);
  assert.match(read('build.zig'), /"tools\/reply-quote-fixture.test.js"/);
});

test('Reply shares delivery, quotes before skills, and clears only after outbox acceptance', () => {
  const send = read('src/chat_send.zig');
  const start = send.indexOf('pub fn sendChatPrompt()');
  const body = send.slice(start, send.indexOf('\nfn chatNetworkReportsConnected', start));
  assert.ok(body.indexOf('@import("chat_reply.zig").compose') < body.indexOf('skill_model.composeMessage'));
  assert.match(body, /utf16LeToUtf8Alloc\(std.heap.page_allocator, send_text\)/);
  assert.ok(body.indexOf('clearChatReply()') > body.indexOf('chatEchoEnqueueForShell'));
  const composer = read('src/chat_composer.zig');
  assert.match(composer, /wp == 0x1B and app_state.g_chat_reply_len > 0 and GetWindowTextLengthW\(hwnd\) == 0/);
  assert.match(composer, /pointInRect\(chatReplyCancelRect\(\), x, y\)\) return 9/);
  assert.match(read('src/main.zig'), /9 => @import\("chat_composer.zig"\).clearChatReply\(\)/);
  assert.match(read('tools/chat-skill-tab.test.js'), /second quote/);
});

test('context Reply handles user and agent blocks but not tool-only blocks', () => {
  const render = read('src/chat_render.zig');
  assert.match(render, /fn chatContextMenuItems\([^]*?if \(reply\) \.reply else null/);
  assert.match(render, /AppendMenuW\(menu, MF_STRING, @intFromEnum\(item\), item\.text\(\)\)/);
  assert.match(render, /chatContextMenuItems\([^\n]*reply_text != null/);
  assert.match(render, /4 => if \(reply_text\) \|text\| \{[^]*?selectChatReply\(text\)/);
  assert.ok(render.indexOf("reply_text = std.heap.page_allocator.dupe") < render.indexOf("const cmd"));
  assert.match(render, /message_menu\.zig"\)\.track/);
  assert.match(render, /block.role == \.prose or block.role == \.code/);
  const body = render.slice(render.indexOf('pub fn chatReplyToBlock('), render.indexOf('pub fn chatReplyLatestAgent('));
  assert.match(body, /role == \.tool\) return/);
  assert.doesNotMatch(body, /role == \.user\) return/);
  assert.match(body, /selectChatReply\(buf\[disp.start/);
});


test('paste checks selection only when the console host exports the optional API', () => {
  const clipboard = read('src/clipboard.zig');
  const body = clipboard.slice(clipboard.indexOf('pub fn pasteTextToShellDirectEx('), clipboard.indexOf('pub fn queueShotPaste('));
  assert.match(body, /GetProcAddress\([^]*?"GetConsoleSelectionInfo"/);
  assert.match(body, /const sel_ok = if \(get_selection\) \|get\| get\(&sel\) != 0 else false;/);
});

test('executed production Reply selection accepts own messages and finds the newest agent block', () => {
  const os = require('node:os');
  const { spawnSync } = require('node:child_process');
  const { copyZig } = require('./zig-copy');
  const source = require('./app-source').readAppSource();
  const body = name => {
    const start = source.indexOf(`fn ${name}(`);
    assert.ok(start >= 0);
    return source.slice(start, source.indexOf('\n}', start) + 2)
      .replaceAll('@import("chat_composer.zig").selectChatReply', 'selectChatReply');
  };
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh419-selection-'));
  try {
    copyZig(['chat_markdown.zig'], dir);
    const harness = `
const std = @import("std");
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
fn chatReadMark(_: bool) bool { return false; }
const ChatBlock = @import("chat_markdown.zig").Block;
var g_chat_blocks = [_]ChatBlock{
    .{ .start = 0, .len = 3, .role = .user },
    .{ .start = 3, .len = 5, .role = .prose },
    .{ .start = 8, .len = 6, .role = .code },
    .{ .start = 14, .len = 4, .role = .tool },
    .{ .start = 18, .len = 4, .role = .user },
};
var g_chat_block_count: usize = 5;
var g_chat_capture = std.unicode.utf8ToUtf16LeStringLiteral("ownoldernewesttoolmine").*;
var g_chat_last_len: usize = 22;
var g_chat_active = true;
var active_shell: u32 = 0;
var shell_count: u32 = 1;
var g_chat_cache_shell_id: u32 = 7;
const shells = [_]struct { shell_id: u32 }{.{ .shell_id = 7 }};
var selected: []const u16 = &.{};
fn selectChatReply(text: []const u16) void { selected = text; }
fn refreshChatTranscript(_: bool) void {}
fn showHeaderNoticeAscii(_: []const u8, _: u32, _: bool) void {}
`;
    const checks = `
test "own message, newest agent, tools, and bounds" {
    chatReplyToBlock(0);
    try std.testing.expectEqualSlices(u16, g_chat_capture[0..3], selected);
    chatReplyLatestAgent();
    try std.testing.expectEqualSlices(u16, g_chat_capture[8..14], selected);
    selected = &.{};
    chatReplyToBlock(3);
    chatReplyToBlock(100);
    try std.testing.expectEqual(@as(usize, 0), selected.len);
    g_chat_active = false;
    chatReplyLatestAgent();
    try std.testing.expectEqual(@as(usize, 0), selected.len);
}
`;
    fs.writeFileSync(path.join(dir, 'selection.zig'), (harness + body('chatBlockDisplayRange') + body('chatReplyToBlock') + body('chatReplyLatestAgent') + checks).replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
    const result = spawnSync(process.env.ZIG || 'zig', ['test', '-j1', path.join(dir, 'selection.zig'), '--test-filter', 'own message'], { encoding: 'utf8', timeout: 60000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('compact references execute production parsing and older-source navigation', () => {
  const os = require('node:os');
  const { spawnSync } = require('node:child_process');
  const { copyZig } = require('./zig-copy');
  const render = read('src/chat_render.zig');
  const body = name => {
    const start = render.indexOf(`fn ${name}(`);
    assert.ok(start >= 0, `Missing production ${name}`);
    return render.slice(start, render.indexOf('\n}', start) + 2);
  };
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'compact-replies-'));
  try {
    copyZig(['chat_reply.zig'], dir);
    const harness = `
const std = @import("std");
const chat_reply = @import("chat_reply.zig");
const chat_transcript = struct { const Identity = struct { shell_id: u32 = 1 }; };
const Block = struct { start: usize = 0, len: usize = 0, role: enum { user, prose, tool, injected } = .prose, source_offset: u64 = 0 };
const app_state = struct {
    var g_chat_active = true;
    var g_chat_capture: [1024]u16 = undefined;
    var g_chat_last_len: usize = 0;
    var g_chat_blocks: [8]Block = @splat(.{});
    var g_chat_block_count: usize = 0;
    var g_chat_scrolled_up = false;
    var g_chat_scroll_bottom_pending = true;
};
var g_reply_jump: ?struct { identity: chat_transcript.Identity, quoted: []u16, before: u64, limit: usize } = null;
var identity: chat_transcript.Identity = .{};
var history_entry = struct { pending: bool = false, history: struct { start: u64 = 100 } = .{}, before: u64 = 0, show_older: bool = false, next: u64 = 55 }{};
var focused: ?usize = null;
var requests: usize = 0;
var notices: usize = 0;
fn chatFileIdentity() chat_transcript.Identity { return identity; }
fn chatHistoryEntry(_: chat_transcript.Identity) ?*@TypeOf(history_entry) { return &history_entry; }
fn chatFileRequest(_: chat_transcript.Identity) void { requests += 1; history_entry.pending = true; }
fn chatBlockDisplayRange(_: []const u16, block: Block) struct { start: usize, len: usize } { return .{ .start = block.start, .len = block.len }; }
fn debugLog(_: []const u8) void {}
fn chatSelectionClear() void {}
fn chatNavFocus(index: usize) void { focused = index; }
fn showHeaderNoticeAscii(_: []const u8, _: u32, _: bool) void { notices += 1; }
${body('chatReplyJumpClear')}
${body('chatReplyResolve')}
test "load older source, choose nearest preceding original, cancel across sessions" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const text = w("different sourceOriginal lineOriginal line");
    @memcpy(app_state.g_chat_capture[0..text.len], text);
    app_state.g_chat_last_len = text.len;
    app_state.g_chat_block_count = 2;
    app_state.g_chat_blocks[0] = .{ .start = 0, .len = 16, .source_offset = 150 };
    app_state.g_chat_blocks[1] = .{ .start = 16, .len = 13, .source_offset = 350 };
    g_reply_jump = .{ .identity = identity, .quoted = try std.heap.page_allocator.dupe(u16, w("Original line")), .before = 300, .limit = 2 };
    chatReplyResolve();
    try std.testing.expect(focused == null);
    try std.testing.expectEqual(@as(usize, 1), requests);
    try std.testing.expect(history_entry.show_older and history_entry.before == 100 and history_entry.next == 0);
    chatReplyResolve();
    try std.testing.expectEqual(@as(usize, 1), requests);
    app_state.g_chat_blocks[0] = .{ .start = 29, .len = 13, .source_offset = 50 };
    history_entry.pending = false;
    history_entry.history.start = 0;
    chatReplyResolve();
    try std.testing.expectEqual(@as(?usize, 0), focused);
    try std.testing.expect(g_reply_jump == null);
    g_reply_jump = .{ .identity = identity, .quoted = try std.heap.page_allocator.dupe(u16, w("missing")), .before = 300, .limit = 2 };
    identity.shell_id = 2;
    chatReplyResolve();
    try std.testing.expect(g_reply_jump == null and notices == 0 and requests == 1);
    g_reply_jump = .{ .identity = identity, .quoted = try std.heap.page_allocator.dupe(u16, w("missing")), .before = 300, .limit = 2 };
    chatReplyResolve();
    try std.testing.expect(g_reply_jump == null and notices == 1);
}
`;
    fs.writeFileSync(path.join(dir, 'navigation.zig'), harness);
    for (const file of ['chat_reply.zig', 'navigation.zig']) {
      const result = spawnSync(process.env.ZIG || 'zig', ['test', '-j1', path.join(dir, file)], { encoding: 'utf8', timeout: 60000 });
      assert.equal(result.status, 0, `${file}: signal=${result.signal} error=${result.error}\n${result.stdout}${result.stderr}`);
    }
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
