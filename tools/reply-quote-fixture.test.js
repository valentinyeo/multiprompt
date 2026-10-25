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
  assert.ok(render.indexOf("reply_text = std.heap.page_allocator.dupe") < render.indexOf("const cmd = TrackPopupMenu"));
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
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'selection.zig'), '--test-filter', 'own message'], { encoding: 'utf8', timeout: 60000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
