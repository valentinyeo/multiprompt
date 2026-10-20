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

test('ISSUE-401 ordinary assistant replies starting Ready or Readable are not hidden as tools', { todo: 'ISSUE-401' }, (t) => {
  const run = execute(t, 'capture', 'const std = @import("std");\n' + ['chatWideStartsWithAscii', 'chatWideContainsAscii', 'chatLineIsToolActivity'].map(body).join('\n') + `
test "ordinary assistant replies remain visible" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    try std.testing.expect(chatLineIsToolActivity(w("● Read(src/main.zig)")));
    try std.testing.expect(!chatLineIsToolActivity(w("● The build now passes")));
    try std.testing.expect(!chatLineIsToolActivity(w("● Ready to deploy.")));
    try std.testing.expect(!chatLineIsToolActivity(w("● Readable error messages are now enabled.")));
}
`, [], '', ['-fno-llvm', '-fno-lld']);
  assert.equal(run.status, 0, run.stdout + run.stderr);
});

test('ISSUE-402 a Claude event preserves text/tool/text content ordering in the history wire', { todo: 'ISSUE-402' }, (t) => {
  const dir = prepare(t, 'reader-order');
  const fixture = path.join(dir, 'reader-order.jsonl');
  fs.writeFileSync(fixture, JSON.stringify({ type: 'assistant', timestamp: '2026-10-03T12:34:00Z', message: { role: 'assistant', id: 'message-1', content: [ { type: 'text', text: 'Before the tool.' }, { type: 'tool_use', id: 'tool-1', name: 'Read', input: { file_path: '/work/a.txt' } }, { type: 'text', text: 'After the tool.' } ] } }) + '\n');
  const script = `import importlib.util,json,sys
from pathlib import Path
spec=importlib.util.spec_from_file_location('reader',sys.argv[1])
r=importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)
r.resolve_response_path=lambda *args: ('claude','sid',Path(sys.argv[2]),None)
q=dict(id=1,codex=False,sid='sid',tmux='term-1',cwd='/work',cached_sid='',inode=0,offset=0,start=0,before=0,mtime=0,probe='',source_offsets=True)
wire=r.response(q)
print(json.dumps([json.loads(line) for line in wire.splitlines()[1:-1] if json.loads(line).get('role')!='status']))
`;
  const run = spawnSync('python3', ['-B', '-c', script, path.join(__dirname, '../src/chat_history_reader.py'), fixture], { cwd: dir, encoding: 'utf8', timeout: 10000, env: { ...process.env, PYTHONDONTWRITEBYTECODE: '1' } });
  assert.equal(run.status, 0, run.stdout + run.stderr);
  const rows = JSON.parse(run.stdout);
  assert.deepEqual(rows.map(row => ({ role: row.role, text: row.text })), [ { role: 'assistant', text: 'Before the tool.' }, { role: 'tool', text: 'Read a.txt' }, { role: 'assistant', text: 'After the tool.' } ]);
});

test('ISSUE-403 clicked Chat View links preserve their Unicode path', { todo: 'ISSUE-403' }, (t) => {
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
${body('openClickedLink')}
test "AUDIT click preserves Unicode in a detected transcript link" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("see https://example.test/Kraków");
    const link = links.next(text, 0).?;
    openClickedLink(text[link.start..link.end]);
    try std.testing.expectEqualStrings("https://example.test/Kraków", sent[0..sent_len]);
}
`, ['link_detect.zig'], 'AUDIT');
  assert.equal(run.status, 0, run.stdout + run.stderr);
});

test('ISSUE-404 Copy All does not silently truncate a long loaded conversation', { todo: 'ISSUE-404' }, (t) => {
  const run = execute(t, 'render-copy', `
const std = @import("std");
const ChatBlock = @import("chat_markdown.zig").Block;
var g_chat_capture: [262200]u16 = @splat('x');
var g_chat_last_len: usize = g_chat_capture.len;
var g_chat_block_count: usize = 1;
var g_chat_blocks: [1]ChatBlock = .{.{ .start = 0, .len = 262200, .role = .user, .markdown = true }};
var g_chat_sel_active = false;
var g_chat_sel_anchor: usize = 0;
var g_chat_sel_caret: usize = 0;
var g_chat_sel_dragging = false;
var g_chat_sel_transcript_focus = false;
var g_chat_sel_text: [262144]u16 = undefined;
var g_chat_transcript_hwnd: ?usize = null;
var g_chat_composer_hwnd: ?usize = null;
var copied: usize = 0;
var notice: [64]u8 = undefined;
var notice_len: usize = 0;
fn chatBlockDisplayRange(_: []const u16, block: ChatBlock) struct { start: usize, len: usize } { return .{ .start = block.start, .len = block.len }; }
fn InvalidateRect(_: ?usize, _: ?*anyopaque, _: i32) i32 { return 1; }
fn setUnicodeClipboardTextWithRetry(text: []const u16) bool { copied = text.len; return true; }
fn showHeaderNoticeAscii(text: []const u8, _: u32, _: bool) void { @memcpy(notice[0..text.len], text); notice_len = text.len; }
fn chatComposerFocusAllowed() bool { return false; }
fn SetFocus(_: ?usize) ?usize { return null; }
${['chatSelRange', 'chatSelectionClear', 'chatSelectAll', 'chatSelectionToClipboard', 'chatCopySelection'].map(body).join('\n')}
test "AUDIT full conversation selection copies every selected character" {
    chatSelectAll();
    chatCopySelection();
    try std.testing.expectEqualStrings("Copied", notice[0..notice_len]);
    try std.testing.expectEqual(g_chat_capture.len, copied);
}
`, ['chat_markdown.zig'], 'AUDIT');
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

test('ISSUE-407 the find box searches for ! when Shift+1 is typed', { todo: 'ISSUE-407' }, (t) => {
  const route = fileBody('chat_find_ui.zig', 'routeKey')
    .replaceAll('app_state.', '')
    .replaceAll('@import("focus.zig").PostMessageW', 'PostMessageW')
    .replaceAll('@import("clipboard.zig").readClipboardTextWithRetry', 'readClipboardTextWithRetry')
    .replaceAll('@import("command_palette.zig").reductionSearchChar', 'reductionSearchChar');
  const result = execute(t, 'find-keyboard', `
const std = @import("std");
const g_main_hwnd: usize = 1;
const WM_APP_CHAT_FIND: u32 = 202;
var posted: [400]u16 = undefined;
var count: usize = 0;
fn PostMessageW(_: usize, _: u32, action: usize, char: u16) i32 {
    if (action == 3) {
        posted[count] = char;
        count += 1;
    }
    return 1;
}
fn readClipboardTextWithRetry(_: []u16) usize { return 0; }
${fileBody('command_palette.zig', 'reductionSearchChar')}
${route}
test "letters survive find routing" {
    count = 0;
    routeKey(0x41, false, false, false);
    try std.testing.expectEqualSlices(u16, &.{'a'}, posted[0..count]);
}
test "shift digit searches for the symbol" {
    count = 0;
    routeKey(0x31, false, true, false);
    try std.testing.expectEqualSlices(u16, &.{'!'}, posted[0..count]);
}
`);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
