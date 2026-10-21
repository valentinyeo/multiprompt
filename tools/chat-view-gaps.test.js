const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');
const source = require('./app-source').readAppSource();

function body(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

function fileBody(file, name) {
  const text = fs.readFileSync(path.join(__dirname, '../src', file), 'utf8');
  const start = text.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `${file} ${name}`);
  return text.slice(start, text.indexOf('\n}', start) + 2);
}

function prepare(t, name, modules = []) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), `chat-view-gaps-${name}-`));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  copyZig(modules, dir);
  fs.cpSync(path.join(__dirname, '../src/testdata'), path.join(dir, 'testdata'), { recursive: true });
  return dir;
}

function zig(args, dir) {
  return spawnSync('zig', [...args, '-j1', '--cache-dir', path.join(dir, 'zig-cache'), '--global-cache-dir', path.join(dir, 'zig-global-cache')], {
    cwd: dir, encoding: 'utf8', timeout: 120000, maxBuffer: 8 * 1024 * 1024,
  });
}

function execute(t, name, code, modules = [], filter = '', flags = []) {
  const dir = prepare(t, name, modules);
  fs.writeFileSync(path.join(dir, 'repro.zig'), code);
  return zig(['test', 'repro.zig', ...flags, ...(filter ? ['--test-filter', filter] : [])], dir);
}

test('ISSUE-400 a failed permission key does not consume the only answer attempt', (t) => {
  const production = body('chatPermissionAnswer')
    .replaceAll('@import("chat_permission.zig")', 'permission')
    .replaceAll('@import("chat_capture.zig").captureChatTranscript', 'captureChatTranscript')
    .replaceAll('@import("window_layout.zig").chatWorkingIndicatorInvalidate', 'chatWorkingIndicatorInvalidate');
  const result = execute(t, 'send-permission', String.raw`
const std = @import("std");
const permission = @import("chat_permission.zig");
var g_chat_active = true;
var active_shell: u32 = 0;
var shell_count: u32 = 1;
var shells = [_]struct { permission_answered: bool = false }{.{}};
var g_chat_permission: permission.PermissionMenu = .{ .count = 3, .allow = '1', .always = '2', .deny = '3' };
var attempts: usize = 0;
var transport_ok = false;
fn captureChatTranscript(_: u32, _: []u16, _: bool) ?usize { return 0; }
fn chatWorkingIndicatorInvalidate() void {}
fn chatAgentKey(_: u32, _: u8) bool { attempts += 1; return transport_ok; }
test "audit failed permission send can be retried" {
    try std.testing.expect(!chatPermissionAnswer(0, .allow));
    transport_ok = true;
    const retried = chatPermissionAnswer(0, .allow);
    std.debug.print("first send failed; answered={}; successful retry={}; actual key attempts={d}\n", .{shells[0].permission_answered, retried, attempts});
    try std.testing.expect(retried);
    try std.testing.expectEqual(@as(usize, 2), attempts);
}
` + production, ['chat_permission.zig'], 'audit failed');
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('ISSUE-400 failed remote permission sends restore only the matching shell and never roll back stop', (t) => {
  const thread = fileBody('chat_send.zig', 'chatStopTmuxThread')
    .replaceAll('@import("chat_transcript.zig").Identity', 'Identity')
    .replaceAll('std.heap.page_allocator', 'allocator')
    .replaceAll('@import("chat_session.zig").chatHistoryPersistent', 'chatHistoryPersistent');
  const apply = fileBody('chat_capture.zig', 'chatPermissionSendFailedApply')
    .replaceAll('@import("window_layout.zig").chatWorkingIndicatorInvalidate', 'chatWorkingIndicatorInvalidate');
  assert.match(fileBody('chat_capture.zig', 'chatPermissionCaptureRows'), /\{\s*chatPermissionSendFailedApply\(\);\s*if \(shell_index != app_state\.active_shell\) return;/);
  const result = execute(t, 'remote-permission', String.raw`
const std = @import("std");
const Identity = struct { shell_id: u32, host: u8 = 0, tmux: [16:0]u8 = @splat(0) };
const app_state = struct {
    var g_chat_permission_send_failed = std.atomic.Value(u32).init(0);
    var shell_count: u32 = 2;
    var shells = [_]struct { shell_id: u32, permission_answered: bool = true }{
        .{ .shell_id = 22 }, .{ .shell_id = 11 },
    };
};
var allocator = std.testing.allocator;
var persistent_ok = false;
var reply_ok = false;
var invalidations: usize = 0;
fn debugLog(_: []const u8) void {}
fn chatWorkingIndicatorInvalidate() void { invalidations += 1; }
fn chatHistoryPersistent(_: u8, _: u32, _: []const u8, _: usize, wire: *std.ArrayList(u8), _: ?usize) bool {
    if (!persistent_ok) return false;
    if (reply_ok) wire.appendSlice(allocator, "\tpermission\tok\t") catch return false;
    return true;
}
` + thread + '\n' + apply + String.raw`
test "failed remote permission is retryable by stable shell id" {
    const key: Identity = .{ .shell_id = 11 };
    for ([_]u8{'1', '3'}) |digit| {
        app_state.shells[1].permission_answered = true;
        chatStopTmuxThread(key, digit);
        try std.testing.expectEqual(@as(u32, 11), app_state.g_chat_permission_send_failed.load(.acquire));
        const before = invalidations;
        chatPermissionSendFailedApply();
        try std.testing.expect(!app_state.shells[1].permission_answered);
        try std.testing.expect(app_state.shells[0].permission_answered);
        try std.testing.expectEqual(@as(u32, 0), app_state.g_chat_permission_send_failed.load(.acquire));
        try std.testing.expectEqual(before + 1, invalidations);
        chatPermissionSendFailedApply();
        try std.testing.expectEqual(before + 1, invalidations);
    }
    app_state.shells[1].permission_answered = true;
    chatStopTmuxThread(key, 0x1B);
    try std.testing.expectEqual(@as(u32, 0), app_state.g_chat_permission_send_failed.load(.acquire));
    chatPermissionSendFailedApply();
    try std.testing.expect(app_state.shells[1].permission_answered);
    persistent_ok = true;
    chatStopTmuxThread(key, '1');
    chatPermissionSendFailedApply();
    try std.testing.expect(!app_state.shells[1].permission_answered);
    app_state.shells[1].permission_answered = true;
    reply_ok = true;
    chatStopTmuxThread(key, '1');
    try std.testing.expectEqual(@as(u32, 0), app_state.g_chat_permission_send_failed.load(.acquire));
    chatPermissionSendFailedApply();
    try std.testing.expect(app_state.shells[1].permission_answered);
    allocator = std.testing.failing_allocator;
    chatStopTmuxThread(key, '1');
    try std.testing.expectEqual(@as(u32, 11), app_state.g_chat_permission_send_failed.load(.acquire));
    chatPermissionSendFailedApply();
    try std.testing.expect(!app_state.shells[1].permission_answered);
    try std.testing.expect(app_state.shells[0].permission_answered);
    chatStopTmuxThread(key, 0x1B);
    try std.testing.expectEqual(@as(u32, 0), app_state.g_chat_permission_send_failed.load(.acquire));
    const before = invalidations;
    app_state.g_chat_permission_send_failed.store(99, .release);
    chatPermissionSendFailedApply();
    try std.testing.expect(app_state.shells[0].permission_answered);
    try std.testing.expectEqual(before, invalidations);
    try std.testing.expectEqual(@as(u32, 0), app_state.g_chat_permission_send_failed.load(.acquire));
}
`);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('ISSUE-401 ordinary assistant replies starting Ready or Readable are not hidden as tools', (t) => {
  const run = execute(t, 'capture', 'const std = @import("std");\n' + ['chatWideStartsWithAscii', 'chatWideContainsAscii', 'chatLineIsToolActivity'].map(body).join('\n') + `
test "ordinary assistant replies remain visible" {
    @setEvalBranchQuota(10000);
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    try std.testing.expect(chatLineIsToolActivity(w("● Read(src/main.zig)")));
    try std.testing.expect(chatLineIsToolActivity(w("● Read 3 files (ctrl+o to expand)")));
    try std.testing.expect(chatLineIsToolActivity(w("● Searching for 2 patterns…")));
    try std.testing.expect(chatLineIsToolActivity(w("● Reading 3 files…")));
    try std.testing.expect(chatLineIsToolActivity(w("• Edited src/main.zig (+3 -1)")));
    try std.testing.expect(chatLineIsToolActivity(w("● Bash(zig build test)")));
    try std.testing.expect(chatLineIsToolActivity(w("● Task(Explore repo)")));
    try std.testing.expect(chatLineIsToolActivity(w("• Explored")));
    try std.testing.expect(chatLineIsToolActivity(w("● Searched for 1 pattern, read 2 files")));
    try std.testing.expect(chatLineIsToolActivity(w("● Searching for 1 pattern, reading 2 files…")));
    try std.testing.expect(chatLineIsToolActivity(w("● Listing 2 directories…")));
    try std.testing.expect(chatLineIsToolActivity(w("● Editing 1 file…")));
    try std.testing.expect(chatLineIsToolActivity(w("● Writing for 2 files…")));
    try std.testing.expect(chatLineIsToolActivity(w("● Read: src/main.zig")));
    try std.testing.expect(!chatLineIsToolActivity(w("● The build now passes")));
    try std.testing.expect(!chatLineIsToolActivity(w("● Ready to deploy.")));
    try std.testing.expect(!chatLineIsToolActivity(w("● Readable error messages are now enabled.")));
    try std.testing.expect(!chatLineIsToolActivity(w("● Searching the logs now.")));
    try std.testing.expect(!chatLineIsToolActivity(w("● Editing the config was enough.")));
    try std.testing.expect(!chatLineIsToolActivity(w("● Tasks are done.")));
    try std.testing.expect(!chatLineIsToolActivity(w("● Bashful output is fine.")));
    try std.testing.expect(!chatLineIsToolActivity(w("● Read3 files")));
    try std.testing.expect(!chatLineIsToolActivity(w("● Searching for patterns…")));
    try std.testing.expect(!chatLineIsToolActivity(w("● Reading")));
    try std.testing.expect(!chatLineIsToolActivity(w("● Listing the files now.")));
    try std.testing.expect(!chatLineIsToolActivity(w("● Writing the report now.")));
}
`, [], '', ['-fno-llvm', '-fno-lld']);
  assert.equal(run.status, 0, run.stdout + run.stderr);
});

test('ISSUE-402 a Claude event preserves text/tool/text content ordering in the history wire', (t) => {
  const dir = prepare(t, 'reader-order');
  const fixture = path.join(dir, 'reader-order.jsonl');
  fs.writeFileSync(fixture, JSON.stringify({ type: 'assistant', timestamp: '2026-10-03T12:34:00Z', message: { role: 'assistant', id: 'message-1', content: [ { type: 'text', text: 'Before the tool.' }, { type: 'tool_use', id: 'tool-1', name: 'Read', input: { file_path: '/work/a.txt' } }, { type: 'text', text: 'After the tool.' } ] } }) + '\n');
  const script = `import importlib.util,json,sys,types
from pathlib import Path
if sys.platform == 'win32':
    def unexpected_user_lookup(*args):
        raise AssertionError('the transcript fixture must not query system users')
    sys.modules['pwd']=types.SimpleNamespace(getpwnam=unexpected_user_lookup,getpwuid=unexpected_user_lookup)
spec=importlib.util.spec_from_file_location('reader',sys.argv[1])
r=importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)
if sys.platform == 'win32':
    assert r.conversation_owner(str(Path.home() / 'work')) is None
    assert r.tmux_owner_process('claude','term-1',None) is None
r.resolve_response_path=lambda *args: ('claude','sid',Path(sys.argv[2]),None)
q=dict(id=1,codex=False,sid='sid',tmux='term-1',cwd='/work',cached_sid='',inode=0,offset=0,start=0,before=0,mtime=0,probe='',source_offsets=True)
wire=r.response(q)
rows=[json.loads(line) for line in wire.splitlines()[1:-1] if json.loads(line).get('role')!='status']
fields=wire.splitlines()[0].split('\\t')
with Path(sys.argv[2]).open('a') as output:
    output.write(json.dumps(dict(type='user',message=dict(role='user',content=[dict(type='tool_result',tool_use_id='tool-1',content='finished')])))+'\\n')
q.update(id=2,cached_sid='sid',inode=int(fields[7]),offset=int(fields[6]),start=int(fields[14]),mtime=int(fields[11]),probe=fields[12])
print(json.dumps(dict(rows=rows,wire=wire,delta=r.response(q))))
`;
  const run = spawnSync('python3', ['-B', '-c', script, path.join(__dirname, '../src/chat_history_reader.py'), fixture], { cwd: dir, encoding: 'utf8', timeout: 10000, env: { ...process.env, PYTHONDONTWRITEBYTECODE: '1' } });
  assert.equal(run.status, 0, run.stdout + run.stderr);
  const { rows, wire, delta } = JSON.parse(run.stdout);
  assert.deepEqual(rows.map(row => ({ role: row.role, text: row.text })), [ { role: 'assistant', text: 'Before the tool.' }, { role: 'tool', text: 'Read a.txt' }, { role: 'assistant', text: 'After the tool.' } ]);
  assert.equal(rows[0].id, 'message-1');
  assert.equal(new Set(rows.map(row => row.id)).size, rows.length);
  const native = execute(t, 'history-order', `
const std = @import("std");
const history = @import("chat_history.zig");
const transcript = @import("chat_transcript.zig");
fn expectOrder(h: history.History) !void {
    try std.testing.expectEqual(@as(usize, 3), h.blocks.items.len);
    const expected = [_][]const u16{
        std.unicode.utf8ToUtf16LeStringLiteral("Before the tool."),
        std.unicode.utf8ToUtf16LeStringLiteral("Read a.txt"),
        std.unicode.utf8ToUtf16LeStringLiteral("After the tool."),
    };
    for (h.blocks.items, expected, 0..) |block, text, index| {
        try std.testing.expectEqualSlices(u16, text, h.text.items[block.start..][0..block.len]);
        try std.testing.expectEqual(index == 1, block.role == .tool);
    }
}
test "ISSUE-402 actual reader wire preserves order across suffix delta clone and cache" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "/work");
    var h: history.History = .{};
    defer h.deinit(a);
    try h.apply(a, ${JSON.stringify(wire)}, 1, key);
    try expectOrder(h);
    var next = try h.suffix(a);
    defer next.deinit(a);
    try next.apply(a, ${JSON.stringify(delta)}, 2, key);
    try h.appendParsed(a, &next);
    try expectOrder(h);
    try std.testing.expectEqual(.ok, h.blocks.items[1].tool_status);
    var cloned = try h.clone(a);
    defer cloned.deinit(a);
    try expectOrder(cloned);
    const bytes = try h.encode(a, key);
    defer a.free(bytes);
    var restored = try history.History.decode(a, bytes, key);
    defer restored.deinit(a);
    try expectOrder(restored);
    try std.testing.expectEqualSlices(u8, h.rows.items, restored.rows.items);
}
`, ['chat_history.zig', 'chat_transcript.zig'], 'ISSUE-402');
  assert.equal(native.status, 0, native.stdout + native.stderr);

});

test('ISSUE-403 clicked Chat View links preserve their Unicode path', (t) => {
  const run = execute(t, 'render-link', `
const std = @import("std");
const links = @import("link_detect.zig");
var active_shell: usize = 0;
var shell_count: usize = 1;
var sent: [8192]u8 = undefined;
var sent_len: usize = 0;
fn navigateBrowserPaneWithActivation(_: usize, url: []const u8, _: bool) void {
    @memcpy(sent[0..url.len], url);
    sent_len = url.len;
}
fn webView2OwnsActiveShell() bool { return false; }
fn requestWebView2Focus() void {}
fn requestNativeBrowserFocus() void {}
${body('clickedLinkUrl')}
${source.match(/test "IGSH-403 [\s\S]*?\n}/)[0]}
${body('openClickedLink')}
test "IGSH-403 click preserves Unicode in a detected transcript link" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("see https://example.test/Kraków");
    const link = links.next(text, 0).?;
    openClickedLink(text[link.start..link.end]);
    try std.testing.expectEqualStrings("https://example.test/Krak%C3%B3w", sent[0..sent_len]);
    const oversized: [8193]u16 = @splat('x');
    sent_len = 0;
    openClickedLink(&oversized);
    try std.testing.expectEqual(@as(usize, 0), sent_len);
    openClickedLink(oversized[0..8192]);
    try std.testing.expectEqual(@as(usize, 8192), sent_len);
    const expanded: [4096]u16 = @splat('é');
    sent_len = 0;
    openClickedLink(&expanded);
    try std.testing.expectEqual(@as(usize, 0), sent_len);
}
`, ['link_detect.zig'], 'IGSH-403', ['-fno-llvm', '-fno-lld']);
  assert.equal(run.status, 0, run.stdout + run.stderr);
});

test('ISSUE-404 Copy All does not silently truncate a long loaded conversation', (t) => {
  const production = ['chatSelRange', 'chatSelectionClear', 'chatSelectAll', 'chatCopyPlainText', 'chatCopyRichText', 'chatCopyBlockText', 'chatCopyCapacity', 'chatCopyTextAlloc', 'chatCopyTextToClipboard', 'chatSelectionToClipboard', 'chatCopySelection', 'chatCopyBlockToClipboard'].map(body).join('\n')
    .replaceAll('std.heap.page_allocator', 'copy_allocator');
  const run = execute(t, 'render-copy', String.raw`
const std = @import("std");
const chat_markdown = @import("chat_markdown.zig");
const ChatBlock = chat_markdown.Block;
var copy_allocator = std.testing.allocator;
var g_chat_capture: [262200]u16 = @splat('x');
var g_chat_last_len: usize = g_chat_capture.len;
var g_chat_block_count: usize = 1;
var g_chat_blocks: [2]ChatBlock = .{.{ .start = 0, .len = 262200, .role = .user, .markdown = true }, .{ .start = 0, .len = 0, .role = .user }};
var g_chat_sel_active = false;
var g_chat_sel_anchor: usize = 0;
var g_chat_sel_caret: usize = 0;
var g_chat_sel_dragging = false;
var g_chat_sel_transcript_focus = false;
var g_chat_transcript_hwnd: ?usize = null;
var g_chat_composer_hwnd: ?usize = null;
var copied: usize = 0;
var clipboard: [524404]u16 = undefined;
var clipboard_ok = true;
var clipboard_calls: usize = 0;
var notice: [64]u8 = undefined;
var notice_len: usize = 0;
var notice_error = false;
fn chatBlockDisplayRange(_: []const u16, block: ChatBlock) struct { start: usize, len: usize } { return .{ .start = block.start, .len = block.len }; }
fn InvalidateRect(_: ?usize, _: ?*anyopaque, _: i32) i32 { return 1; }
fn setUnicodeClipboardTextWithRetry(text: []const u16) bool {
    clipboard_calls += 1;
    if (!clipboard_ok) return false;
    copied = text.len;
    @memcpy(clipboard[0..copied], text);
    return true;
}
fn showHeaderNoticeAscii(text: []const u8, _: u32, failed: bool) void {
    @memcpy(notice[0..text.len], text);
    notice_len = text.len;
    notice_error = failed;
}
fn chatComposerFocusAllowed() bool { return false; }
fn SetFocus(_: ?usize) ?usize { return null; }
` + production + String.raw`
test "IGSH-404 long copy preserves every UTF-16 unit and handles failure honestly" {
    g_chat_capture[g_chat_capture.len - 2] = 0xd83d;
    g_chat_capture[g_chat_capture.len - 1] = 0xde00;
    chatSelectAll();
    chatCopySelection();
    try std.testing.expectEqualStrings("Copied", notice[0..notice_len]);
    try std.testing.expect(!notice_error);
    try std.testing.expectEqualSlices(u16, &g_chat_capture, clipboard[0..copied]);
    g_chat_sel_anchor = g_chat_capture.len;
    g_chat_sel_caret = 0;
    chatCopySelection();
    try std.testing.expectEqualSlices(u16, &g_chat_capture, clipboard[0..copied]);
    chatCopyBlockToClipboard(0);
    try std.testing.expectEqualSlices(u16, &g_chat_capture, clipboard[0..copied]);
    const snapshot = try chatCopyTextAlloc(copy_allocator, null);
    defer std.testing.allocator.free(snapshot);
    try std.testing.expectEqualSlices(u16, &g_chat_capture, snapshot);
    clipboard_ok = false;
    chatCopySelection();
    try std.testing.expect(notice_error);
    try std.testing.expectEqualStrings("Could not copy to clipboard; try again", notice[0..notice_len]);
    const calls = clipboard_calls;
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    copy_allocator = failing.allocator();
    chatCopySelection();
    try std.testing.expectEqual(calls, clipboard_calls);
    try std.testing.expect(notice_error);
    try std.testing.expectEqualStrings("Could not copy text; try again", notice[0..notice_len]);
    var rich_failure = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    copy_allocator = rich_failure.allocator();
    g_chat_blocks[0].role = .prose;
    chatCopySelection();
    try std.testing.expectEqual(calls, clipboard_calls);
    try std.testing.expect(notice_error);
    try std.testing.expectEqualStrings("Could not copy text; try again", notice[0..notice_len]);
    g_chat_blocks[0].role = .user;
    copy_allocator = std.testing.allocator;
    clipboard_ok = true;
    @memset(&g_chat_capture, '\n');
    chatCopySelection();
    try std.testing.expectEqual(g_chat_capture.len * 2, copied);
    for (0..g_chat_capture.len) |i| try std.testing.expectEqualSlices(u16, &.{ '\r', '\n' }, clipboard[i * 2 ..][0..2]);
    g_chat_last_len = 2;
    g_chat_capture[0] = 'a';
    g_chat_capture[1] = 'b';
    g_chat_block_count = 2;
    g_chat_blocks[0] = .{ .start = 0, .len = 1, .role = .user };
    g_chat_blocks[1] = .{ .start = 1, .len = 1, .role = .user };
    chatSelectAll();
    chatCopySelection();
    try std.testing.expectEqualSlices(u16, &.{ 'a', '\r', '\n', '\r', '\n', 'b' }, clipboard[0..copied]);
    var small: [1]u16 = undefined;
    try std.testing.expectError(error.NoSpaceLeft, chatSelectionToClipboard(&small));
    chatSelectionClear();
    chatCopySelection();
    try std.testing.expect(!notice_error);
    try std.testing.expectEqualStrings("Nothing selected", notice[0..notice_len]);
}
`, ['chat_markdown.zig'], 'IGSH-404');
  assert.equal(run.status, 0, run.stdout + run.stderr);
});

test('ISSUE-405 inline code preserves Windows path backslashes', { todo: 'ISSUE-405' }, (t) => {
  const run = execute(t, 'markdown-path', String.raw`
const std = @import("std");
const md = @import("chat_markdown.zig");
test "AUDIT inline code preserves the literal Windows path" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("\u{0060}C:\\Users\\name\u{0060}");
    var spans: [64]md.Span = undefined;
    var rendered: std.ArrayList(u16) = .empty;
    defer rendered.deinit(std.testing.allocator);
    const n = md.inlineSpans(text, &spans);
    for (spans[0..n]) |span| try rendered.appendSlice(std.testing.allocator, text[span.text.start..span.text.end]);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("C:\\Users\\name"), rendered.items);
}
`, ['chat_markdown.zig'], 'AUDIT');
  assert.equal(run.status, 0, run.stdout + run.stderr);
});

test('ISSUE-406 sync audit recognizes literal Markdown in user bubbles', { todo: 'ISSUE-406' }, (t) => {
  const dir = prepare(t, 'audit-cli', ['chat_audit.zig']);
  const exe = path.join(dir, process.platform === 'win32' ? 'chat-audit.exe' : 'chat-audit');
  const build = zig(['build-exe', 'chat_audit.zig', '-O', 'ReleaseSafe', `-femit-bin=${exe}`], dir);
  assert.equal(build.status, 0, build.stdout + build.stderr);
  const wire = '@mp\t1\thistory\tok\tsid\t0\t100\t9\t0\tclaude\t-\n' + JSON.stringify({role: 'user', text: '**literal**'}) + '\n@@MP_END@@\n';
  const run = spawnSync(exe, ['--contains', '**literal**'], {input: wire, encoding: 'utf8', timeout: 5000, cwd: dir});
  assert.equal(run.status, 0, run.stdout + run.stderr);
  const rows = run.stdout.trim().split('\n').map(JSON.parse);
  assert.deepEqual(rows, [{probe: 0, present: true}], run.stdout);
});

test('ISSUE-376 received agent messages use the normal Markdown layout path', { todo: 'ISSUE-376' }, (t) => {
  const run = execute(t, 'render-injected', `
const std = @import("std");
const chat_markdown = @import("chat_markdown.zig");
const ChatBlock = chat_markdown.Block;
const HANDLE = usize;
const RECT = struct { left: i32 = 0, top: i32 = 0, right: i32 = 100, bottom: i32 = 100 };
const ChatHit = struct {};
const link_detect = struct { const Range = struct { start: usize, end: usize }; };
const DT_SINGLELINE: u32 = 1;
const DT_NOPREFIX: u32 = 2;
var g_chat_tables: chat_markdown.TableCache = .{};
var rich_calls: usize = 0;
fn ensureChatCodeFont() HANDLE { return 1; }
fn ensureChatFont() HANDLE { return 1; }
fn SelectObject(_: HANDLE, _: HANDLE) HANDLE { return 1; }
fn chatTextWidth(_: HANDLE, _: []const u16) i32 { return 8; }
fn GetTickCount64() u64 { return 0; }
fn chatPerf(_: []const u8, _: u64, _: usize) void {}
fn debugLog(_: []const u8) void {}
fn chatFlowTable(_: HANDLE, _: []const u16, _: RECT, _: bool, _: ?ChatHit, _: usize, _: ?*i32) ?link_detect.Range { return null; }
fn chatFlowText(_: HANDLE, _: []const u16, _: RECT, _: bool, _: bool, _: ?ChatHit, _: usize, _: ?*i32, _: ?[]const usize) ?link_detect.Range { return null; }
fn chatRichText(_: HANDLE, _: []const u16, _: RECT, _: u3, _: bool, _: ?ChatHit, _: usize, _: ?*i32, _: bool) ?link_detect.Range { rich_calls += 1; return null; }
fn uiScaled(n: i32) i32 { return n; }
fn customColorOr(_: []const u8, n: u32) u32 { return n; }
fn themeConsoleFg() u32 { return 0; }
fn SetTextColor(_: HANDLE, _: u32) u32 { return 0; }
fn L(comptime s: []const u8) [*:0]const u16 { return std.unicode.utf8ToUtf16LeStringLiteral(s); }
fn DrawTextW(_: HANDLE, _: [*]const u16, _: i32, _: *RECT, _: u32) i32 { return 20; }
${body('chatFlowBlock')}
test "AUDIT injected agent Markdown reaches the same rich layout as assistant prose" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("**bold**");
    var blocks: [8]ChatBlock = undefined;
    _ = chat_markdown.blocks(text, 0, .prose, &blocks);
    _ = chatFlowBlock(1, text, blocks[0], .{}, false, null, 0, null);
    try std.testing.expectEqual(@as(usize, 1), rich_calls);
    rich_calls = 0;
    _ = chat_markdown.blocks(text, 0, .injected, &blocks);
    _ = chatFlowBlock(1, text, blocks[0], .{}, false, null, 0, null);
    try std.testing.expectEqual(@as(usize, 1), rich_calls);
}
`, ['chat_markdown.zig'], 'AUDIT');
  assert.equal(run.status, 0, run.stdout + run.stderr);
});

function findKeyboard(t, name, assertions) {
  const production = ['routeKey', 'windowKey', 'key'].map(name => fileBody('chat_find_ui.zig', name)).join('\n')
    .replaceAll('app_state.', '')
    .replaceAll('@import("focus.zig").PostMessageW', 'PostMessageW')
    .replaceAll('@import("focus.zig").isCtrlDown', 'isCtrlDown')
    .replaceAll('@import("clipboard.zig").readClipboardTextWithRetry', 'readClipboardTextWithRetry')
    .replaceAll('@import("chat_composer.zig").chatViewOwnsInput', 'chatViewOwnsInput')
    .replaceAll('@import("command_palette.zig").reductionSearchChar', 'reductionSearchChar');
  const result = execute(t, name, `
const std = @import("std");
const win32 = struct {
    const WM_KEYDOWN: u32 = 0x0100;
    fn GetAsyncKeyState(vk: u32) i16 { return if ((vk == 0x10 and shift_down) or (vk == 0x12 and alt_down)) -1 else 0; }
};
const model = struct {
    const ISSUE_268_CHAT_FIND = true;
    fn step(_: usize, _: usize, _: bool) usize { return 0; }
};
const g_main_hwnd: usize = 1;
const WM_APP_CHAT_FIND: u32 = 202;
const WM_SYSKEYDOWN: u32 = 0x0104;
var g_chat_find_open = true;
var g_chat_find_high_surrogate: u16 = 0;
var g_chat_find_len: usize = 0;
var g_chat_find_query: [401]u16 = @splat(0);
var g_chat_find_result: ?struct { hits: []const u8 } = null;
var g_chat_find_selected: usize = 0;
var g_chat_find_jump = false;
var ctrl_down = false;
var shift_down = false;
var alt_down = false;
var actions: [400]usize = undefined;
var posted_count: usize = 0;
fn PostMessageW(_: usize, _: u32, action: usize, char: u16) i32 {
    actions[posted_count] = action;
    posted_count += 1;
    key(action, char);
    return 1;
}
fn readClipboardTextWithRetry(out: []u16) usize { out[0] = 'p'; return 1; }
fn isCtrlDown() bool { return ctrl_down; }
fn chatViewOwnsInput() bool { return true; }
fn open() void { g_chat_find_open = true; }
fn close(_: bool) void { g_chat_find_open = false; }
fn changed() void {}
fn jump() void {}
fn invalidate() void {}
${fileBody('command_palette.zig', 'reductionSearchChar')}
${production}
test "ISSUE-407 ${name}" {
${assertions}
}
`, [], '', ['-fno-llvm', '-fno-lld']);
  assert.equal(result.status, 0, result.stdout + result.stderr);
}

test('ISSUE-407 the find box searches for ! when Shift+1 is typed', (t) => {
  findKeyboard(t, 'find-shift-symbol', `
    shift_down = true;
    try std.testing.expect(windowKey(0x0100, 0x31));
    try std.testing.expect(windowKey(0x0102, '!'));
    try std.testing.expectEqualSlices(u16, &.{'!'}, g_chat_find_query[0..g_chat_find_len]);
  `);
});

test('ISSUE-407 the find box accepts é via WM_CHAR after a dead key', (t) => {
  findKeyboard(t, 'find-dead-key', `
    try std.testing.expect(windowKey(0x0100, 0xde));
    _ = windowKey(0x0103, 0x00b4);
    try std.testing.expect(windowKey(0x0100, 0x45));
    try std.testing.expect(windowKey(0x0102, 0x00e9));
    try std.testing.expectEqualSlices(u16, &.{0x00e9}, g_chat_find_query[0..g_chat_find_len]);
  `);
});

test('ISSUE-407 the find box inserts a plain letter only once from WM_CHAR', (t) => {
  findKeyboard(t, 'find-no-double-insert', `
    try std.testing.expect(windowKey(0x0100, 0x41));
    try std.testing.expectEqual(@as(usize, 0), g_chat_find_len);
    try std.testing.expect(windowKey(0x0102, 'a'));
    try std.testing.expect(windowKey(0x0101, 0x41));
    try std.testing.expectEqualSlices(u16, &.{'a'}, g_chat_find_query[0..g_chat_find_len]);
    try std.testing.expectEqual(@as(usize, 1), posted_count);
    g_chat_find_open = false;
    try std.testing.expect(!windowKey(0x0102, 'b'));
    try std.testing.expectEqual(@as(usize, 1), posted_count);
  `);
});

test('ISSUE-407 the find box preserves AltGr, surrogate pairs, paste and editing', (t) => {
  findKeyboard(t, 'find-unicode-editing', `
    ctrl_down = true;
    alt_down = true;
    try std.testing.expect(windowKey(0x0104, 0x51));
    try std.testing.expect(windowKey(0x0102, '@'));
    ctrl_down = false;
    alt_down = false;
    try std.testing.expect(windowKey(0x0102, 0xd83d));
    try std.testing.expect(windowKey(0x0102, 0xde00));
    try std.testing.expectEqualSlices(u16, &.{'@', 0xd83d, 0xde00}, g_chat_find_query[0..g_chat_find_len]);
    try std.testing.expect(windowKey(0x0100, 0x08));
    try std.testing.expect(windowKey(0x0102, 0x08));
    try std.testing.expectEqualSlices(u16, &.{'@'}, g_chat_find_query[0..g_chat_find_len]);
    ctrl_down = true;
    try std.testing.expect(windowKey(0x0100, 0x56));
    try std.testing.expect(windowKey(0x0102, 0x16));
    try std.testing.expectEqualSlices(u16, &.{'@', 'p'}, g_chat_find_query[0..g_chat_find_len]);
    ctrl_down = false;
    try std.testing.expect(windowKey(0x0100, 0x0d));
    try std.testing.expectEqual(@as(usize, 4), actions[posted_count - 1]);
    const before_enter_char = posted_count;
    try std.testing.expect(windowKey(0x0102, 0x0d));
    try std.testing.expectEqual(before_enter_char, posted_count);
    shift_down = true;
    try std.testing.expect(windowKey(0x0100, 0x72));
    try std.testing.expectEqual(@as(usize, 5), actions[posted_count - 1]);
    try std.testing.expect(windowKey(0x0100, 0x1b));
    try std.testing.expect(!g_chat_find_open);
  `);
});

test('ISSUE-407 the find hook lets Windows translate text instead of swallowing it', () => {
  const hook = fileBody('shortcuts.zig', 'keyboardHookProc');
  const start = hook.indexOf('if (@import("chat_find.zig").ownsKeys(');
  assert.ok(start >= 0);
  const branch = hook.slice(start, hook.indexOf('if (app_state.ISSUE_268_CHAT_FIND', start));
  assert.match(branch, /return CallNextHookEx\(app_state\.g_hook, nCode, wp, lp\);/);
  assert.doesNotMatch(branch, /routeKey|return 1;/);
});
