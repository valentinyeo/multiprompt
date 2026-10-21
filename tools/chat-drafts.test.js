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

function execute(code) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-drafts-'));
  try {
    if (fs.existsSync('src/chat_drafts.zig')) copyZig(['chat_drafts.zig'], dir);
    fs.writeFileSync(path.join(dir, 'test.zig'), code);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', 'test.zig', '-j1'], {
      cwd: dir, encoding: 'utf8', timeout: 120000,
    });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

const prelude = `
const std = @import("std");
const CHAT_OUTBOX_KEY_CAP = 192;
const TIMER_CHAT_DRAFT = 1;
const CHAT_DRAFT_SAVE_MS = 300;
var g_main_hwnd: ?usize = 1;
var g_chat_composer_hwnd: ?usize = 2;
var g_chat_draft_dirty = false;
var g_chat_draft_owner: [192]u8 = undefined;
var g_chat_draft_owner_len: usize = 0;
var g_chat_reply: [8192]u8 = undefined;
var g_chat_reply_len: usize = 0;
var g_chat_reply_preview_len: usize = 0;
var g_chat_skill_name: [128]u8 = undefined;
var g_chat_skill_name_len: usize = 0;
var g_chat_skill_body: [8192]u8 = undefined;
var g_chat_skill_body_len: usize = 0;
var active_shell: u32 = 0;
var shell_count: u32 = 2;
var shells = [_]struct { chat_id: u64, shell_id: u32, kind: enum { tmux } = .tmux, tmux_host: u8 = 0, tmux_session: [4]u8 = .{'s','a','m','e'}, tmux_session_len: u32 = 4 }{ .{.chat_id = 101, .shell_id = 1}, .{.chat_id = 202, .shell_id = 2} };
var composer_text: [16400]u16 = @splat(0);
var files = std.StringHashMap([]u8).init(std.heap.page_allocator);
fn saveSession() void {}
fn GetWindowTextW(_: ?usize, out: [*]u16, cap: i32) i32 { const n = @min(std.mem.indexOfScalar(u16, &composer_text, 0).?, @as(usize, @intCast(cap - 1))); @memcpy(out[0..n], composer_text[0..n]); out[n] = 0; return @intCast(n); }
fn SetWindowTextW(_: ?usize, value: [*:0]const u16) bool { const s = std.mem.span(value); @memcpy(composer_text[0..s.len], s); composer_text[s.len] = 0; return true; }
fn SendMessageW(_: ?usize, _: u32, _: usize, _: isize) isize { return 0; }
fn SetTimer(_: ?usize, _: usize, _: u32, _: ?*anyopaque) usize { return 1; }
fn KillTimer(_: ?usize, _: usize) bool { return true; }
fn InvalidateRect(_: ?usize, _: ?*anyopaque, _: i32) bool { return true; }
fn chatComposerAutoGrow() void {}
fn layoutChatControls() void {}
fn chatReplyRefreshPreview() void {}
fn getChatDraftPath(id: []const u8, buf: *[560]u8) ?[]const u8 { @memcpy(buf[0..id.len], id); return buf[0..id.len]; }
fn chatDraftWriteFile(id: []const u8, bytes: []const u8) bool { files.put(std.heap.page_allocator.dupe(u8, id) catch unreachable, std.heap.page_allocator.dupe(u8, bytes) catch unreachable) catch unreachable; return true; }
fn readFileAllocWin32(id: []const u8, _: usize) ?[]u8 { return if (files.get(id)) |v| std.heap.page_allocator.dupe(u8, v) catch unreachable else null; }
fn win32WidePath(out: []u16, id: []const u8) ?[:0]u16 { for (id, 0..) |c,i| out[i] = c; out[id.len] = 0; return out[0..id.len :0]; }
fn GetFileAttributesW(_: [*:0]const u16) u32 { return 0xFFFF_FFFF; }
fn DeleteFileW(id: [*:0]const u16) i32 { var b: [560]u8 = undefined; const s = std.mem.span(id); for(s, 0..) |c,i| b[i] = @intCast(c); _ = files.remove(b[0..s.len]); return 1; }
fn chatOutboxLegacyKeyForShell(_: u32, b: []u8) []const u8 { return b[0..0]; }
fn chatOutboxShellForKey(_: []const u8) ?u32 { return 0; }
fn edit(value: [*:0]const u16) void { _ = SetWindowTextW(g_chat_composer_hwnd, value); chatDraftNoteEdit(); }
fn expectText(value: []const u16) !void { try std.testing.expectEqualSlices(u16, value, std.mem.sliceTo(&composer_text, 0)); }
`;

function production() {
  const current = source.includes('fn chatDraftKeyForShell(');
  const globals = current ? '\nconst draft_model = @import("chat_drafts.zig");\nvar chat_drafts = draft_model.Store.init(std.heap.page_allocator);\nvar chat_draft_loading = false;\n' : '';
  const names = ['chatOutboxKeyForShell', 'chatDraftFlush', 'chatDraftNoteEdit', 'chatDraftBindToActive'];
  if (current) names.push('chatDraftKeyForShell', 'chatDraftLoad', 'chatDraftHasForShell', 'chatDraftAppend');
  let code = prelude + globals + names.map(body).join('\n');
  if (!current) code = code.replace('    chatDraftWriteFile(path, utf8);', '    _ = chatDraftWriteFile(path, utf8);');
  return code;
}

test('ISSUE-498 draft typed in session A is not visible in session B after switch', () => {
  execute(production() + `
test "ISSUE-498 typed and pasted drafts follow stable sessions across reordering and workspace switches" {
    chatDraftBindToActive(); edit(std.unicode.utf8ToUtf16LeStringLiteral("draft A"));
    active_shell = 1; chatDraftBindToActive(); try expectText(&.{});
    edit(std.unicode.utf8ToUtf16LeStringLiteral("pasted B"));
    std.mem.swap(@TypeOf(shells[0]), &shells[0], &shells[1]);
    chatDraftBindToActive(); try expectText(std.unicode.utf8ToUtf16LeStringLiteral("draft A"));
    active_shell = 0; chatDraftBindToActive(); try expectText(std.unicode.utf8ToUtf16LeStringLiteral("pasted B"));
}
`);
});

test('ISSUE-498 dictation started in A completes in A while B is active', () => {
  const ready = body('handleDictationReady');
  const appReady = ready.replaceAll('app_state.', '');
  const branchStart = appReady.lastIndexOf('\n    if (g_chat_active and g_chat_composer_hwnd != null)');
  const marker = appReady.indexOf('\n    if (dictationTargetIsBrowser())');
  const toggle = body('toggleDictation');
  const captureStart = toggle.indexOf('    g_dictation_draft_owner_len = 0;');
  const capture = captureStart < 0 ? '' : toggle.slice(captureStart, toggle.indexOf('    g_dictation_recording.store(true', captureStart)).replaceAll('@import("chat_composer.zig").', '');
  const route = source.includes('chatDraftAppend') ? appReady.slice(appReady.indexOf('    if (g_dictation_draft_owner_len > 0)'), marker) : appReady.slice(branchStart, marker);
  assert.ok(marker >= 0);
  execute(production() + `
var g_chat_active = true;
var g_dictation_draft_owner: [192]u8 = undefined;
var g_dictation_draft_owner_len: usize = 0;
fn dictationAudit(_: []const u8, _: usize) void {}
fn insertTextIntoChatComposer(value: []const u16) void { var b: [16400]u16 = @splat(0); @memcpy(b[0..value.len], value); edit(@ptrCast(&b)); }
fn begin() void {
${capture}
}
fn deliver(transcript: []const u16) void {
${route.replaceAll('@import("chat_composer.zig").', '')}
}
test "ISSUE-498 late result is bound to its start session" {
    chatDraftBindToActive();
    begin();
    active_shell = 1; chatDraftBindToActive();
    deliver(std.unicode.utf8ToUtf16LeStringLiteral("spoken A"));
    try expectText(&.{});
    active_shell = 0; chatDraftBindToActive(); try expectText(std.unicode.utf8ToUtf16LeStringLiteral("spoken A"));
}
`);
});

test('ISSUE-498 DRAFT marker is shown for a draft and removed by send or clear', () => {
  const sidebar = fs.readFileSync('src/sidebar.zig', 'utf8');
  const sidebarLookup = sidebar.match(/chatDraftHasForShell\((?:@intCast\()?i\)?\)/);
  assert.ok(sidebarLookup, "DRAFT predicate missing");
  assert.match(sidebar, /DrawTextW\(hdc, L\("DRAFT"\)/);
  const send = body('sendChatPrompt');
  assert.match(send, /SetWindowTextW\(g_chat_composer_hwnd, L\(""\)\)[^]*chatDraftFlush\(\)/);
  const clearStart = send.indexOf('    _ = SetWindowTextW(g_chat_composer_hwnd, L(""));');
  const clearEnd = send.indexOf('    chatDraftFlush();', clearStart) + '    chatDraftFlush();'.length;
  const sent = send.slice(clearStart, clearEnd).replace('L("")', 'std.unicode.utf8ToUtf16LeStringLiteral("")');

  execute(production() + `
fn sidebarHasDraft(i: usize) bool { return ${sidebarLookup[0]}; }
test "ISSUE-498 draft presence follows edit and clear" {
    chatDraftBindToActive(); try std.testing.expect(!sidebarHasDraft(0));
    edit(std.unicode.utf8ToUtf16LeStringLiteral("unsent")); try std.testing.expect(sidebarHasDraft(0));
    try std.testing.expect(!sidebarHasDraft(1));
    ${sent}
    try std.testing.expect(!sidebarHasDraft(0));
    edit(std.unicode.utf8ToUtf16LeStringLiteral("again")); try std.testing.expect(sidebarHasDraft(0));
    edit(std.unicode.utf8ToUtf16LeStringLiteral("")); chatDraftFlush(); try std.testing.expect(!sidebarHasDraft(0));
}
`);
});

test('ISSUE-498 drafts survive a save/load round trip without leaking across sessions', () => {
  execute(production() + `
test "ISSUE-498 restart restores each stable session independently" {
    chatDraftBindToActive(); edit(std.unicode.utf8ToUtf16LeStringLiteral("saved A")); chatDraftFlush();
    active_shell = 1; chatDraftBindToActive(); edit(std.unicode.utf8ToUtf16LeStringLiteral("saved B")); chatDraftFlush();
    ${source.includes('fn chatDraftKeyForShell(') ? 'chat_drafts.deinit(); chat_drafts = draft_model.Store.init(std.heap.page_allocator);' : ''}
    g_chat_draft_owner_len = 0; composer_text[0] = 0;
    shells[0].shell_id = 9; shells[1].shell_id = 10;
    active_shell = 0; chatDraftBindToActive(); try expectText(std.unicode.utf8ToUtf16LeStringLiteral("saved A"));
    active_shell = 1; chatDraftBindToActive(); try expectText(std.unicode.utf8ToUtf16LeStringLiteral("saved B"));
}
`);
});
