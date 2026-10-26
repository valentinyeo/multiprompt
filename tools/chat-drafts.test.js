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
    fs.writeFileSync(path.join(dir, 'test.zig'), code.replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
    const result = spawnSync(process.env.ZIG || 'zig', ['test', 'test.zig', '-j1', '-fllvm'], {
      cwd: dir, encoding: 'utf8', timeout: 120000,
    });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

const prelude = `
const std = @import("std");
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
fn chatReadMark(_: bool) bool { return false; }
const CHAT_OUTBOX_KEY_CAP = 192;
const ShellDraft = struct { fn onComposerEdit(_: ShellDraft, _: u64) void {} };
var shell_draft: ShellDraft = .{};
fn GetTickCount64() u64 { return 0; }
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
const ShellKind = enum { tmux };
const Shell = struct { chat_id: u64 = 0, shell_id: u32 = 0, kind: ShellKind = .tmux, tmux_host: u8 = 0, tmux_session: [64]u8 = [_]u8{'s','a','m','e'} ++ [_]u8{0} ** 60, tmux_session_len: u32 = 4, browser_hwnd: ?usize = null, name: [64]u16 = @splat(0), name_len: u32 = 0, name_source: enum { manual, semantic } = .manual, cached_cwd: [512]u8 = @splat(0), cached_cwd_len: u32 = 0, group_id: u32 = 0, starred_group_id: u32 = 0, favorite: bool = false, workspace: u8 = 0 };
var shells = [_]Shell{ .{.chat_id = 101, .shell_id = 1}, .{.chat_id = 202, .shell_id = 2} };
var composer_text: [16400]u16 = @splat(0);
var files = std.StringHashMap([]u8).init(std.heap.page_allocator);
var saved_chat_ids: [2]u64 = @splat(0);
fn saveSession() void { for (0..shell_count) |i| saved_chat_ids[i] = shells[i].chat_id; }
fn L(comptime value: []const u8) *const [value.len:0]u16 { return std.unicode.utf8ToUtf16LeStringLiteral(value); }
const defer_browser = true;
const defer_native_browser = true;
var revealed_shell: u32 = 0;
fn revealPaintedChatBrowser() void { revealed_shell = shells[active_shell].shell_id; }
fn parkStrayBrowserPanes(_: ?usize) void {}
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
var fail_write = false;
fn chatDraftWriteFile(id: []const u8, bytes: []const u8) bool { if (fail_write) return false; files.put(std.heap.page_allocator.dupe(u8, id) catch unreachable, std.heap.page_allocator.dupe(u8, bytes) catch unreachable) catch unreachable; return true; }
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
  if (current) names.push('chatDraftKeyForShell', 'chatDraftLoad', 'chatDraftHasForShell', 'chatDraftAppend', 'chatDraftCloseForShell');
  let code = prelude + globals + names.map(body).join('\n');
  if (!current) code = code.replace('    chatDraftWriteFile(path, utf8);', '    _ = chatDraftWriteFile(path, utf8);');
  const switchBody = body('switchToShell');
  const switchStart = switchBody.indexOf('    active_shell = idx;');
  const switchEnd = switchBody.indexOf('    if (!g_restoring and idx < shell_count and shells[idx].workspace');
  assert.ok(switchStart >= 0 && switchEnd > switchStart, 'real switch binding boundary');
  code += `
fn switchToShell(idx: u32) void {
${switchBody.slice(switchStart, switchEnd).replaceAll('@import("browser_pane.zig").', '')}
    std.debug.assert(revealed_shell == shells[idx].shell_id);
}
`;
  return code;
}

test('ISSUE-498 real switchToShell isolates typed and pasted drafts across tabs and workspaces', () => {
  execute(production() + `
test "ISSUE-498 typed and pasted drafts follow stable sessions across reordering and workspace switches" {
    switchToShell(active_shell); edit(std.unicode.utf8ToUtf16LeStringLiteral("draft A"));
    switchToShell(1); try expectText(&.{});
    edit(std.unicode.utf8ToUtf16LeStringLiteral("pasted B"));
    std.mem.swap(@TypeOf(shells[0]), &shells[0], &shells[1]);
    switchToShell(active_shell); try expectText(std.unicode.utf8ToUtf16LeStringLiteral("draft A"));
    switchToShell(0); try expectText(std.unicode.utf8ToUtf16LeStringLiteral("pasted B"));
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
var g_dictation_cancelled = std.atomic.Value(bool).init(false);
fn dictationAudit(_: []const u8, _: usize) void {}
fn insertTextIntoChatComposer(value: []const u16) void { var b: [16400]u16 = @splat(0); @memcpy(b[0..value.len], value); edit(@ptrCast(&b)); }
fn begin() void {
${capture}
}
fn deliver(transcript: []const u16) void {
${route.replaceAll('@import("chat_composer.zig").', '')}
}
test "ISSUE-498 late result is bound to its start session" {
    switchToShell(active_shell);
    begin();
    switchToShell(1);
    deliver(std.unicode.utf8ToUtf16LeStringLiteral("spoken A"));
    try expectText(&.{});
    switchToShell(0); try expectText(std.unicode.utf8ToUtf16LeStringLiteral("spoken A"));
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
    switchToShell(active_shell); try std.testing.expect(!sidebarHasDraft(0));
    edit(std.unicode.utf8ToUtf16LeStringLiteral("unsent")); try std.testing.expect(sidebarHasDraft(0));
    try std.testing.expect(!sidebarHasDraft(1));
    ${sent}
    try std.testing.expect(!sidebarHasDraft(0));
    edit(std.unicode.utf8ToUtf16LeStringLiteral("again")); try std.testing.expect(sidebarHasDraft(0));
    edit(std.unicode.utf8ToUtf16LeStringLiteral("")); chatDraftFlush(); try std.testing.expect(!sidebarHasDraft(0));
}
`);
});

test('ISSUE-498 restart recreates sessions using the production saved chat identity', () => {
  const save = body('saveSessionTo');
  assert.match(save, /const chat_id_pre = ",\\"chat_id\\":";/);
  assert.match(save, /writeUintTo\(json_buf\[pos\.\.\], shells\[i\]\.chat_id\)/);
  const restore = body('spawnSavedTab').match(/^    shells\[idx\]\.chat_id = tabs\[t\]\.chat_id;$/m);
  assert.ok(restore, 'real restart identity restoration');
  const reader = fs.readFileSync('src/json_reader.zig', 'utf8');
  assert.match(reader, /tab\.chat_id = uint\(obj, "chat_id"\);/);
  execute(production() + `
fn restoreSaved(idx: usize, id: u64) void {
    const tabs = [_]struct { chat_id: u64 }{.{ .chat_id = id }};
    const t: usize = 0;
    shells[idx] = .{ .shell_id = @intCast(idx + 9) };
${restore[0]}
}
test "ISSUE-498 restart restores recreated sessions instead of retaining fixture ids" {
    switchToShell(0); edit(L("saved A")); chatDraftFlush();
    switchToShell(1); edit(L("saved B")); chatDraftFlush();
    saveSession();
    const saved = saved_chat_ids;
    chat_drafts.deinit(); chat_drafts = draft_model.Store.init(std.heap.page_allocator);
    g_chat_draft_owner_len = 0; composer_text[0] = 0;
    shells = @splat(.{});
    restoreSaved(0, saved[0]); restoreSaved(1, saved[1]);
    switchToShell(0); try expectText(L("saved A"));
    switchToShell(1); try expectText(L("saved B"));
}
`);
});

function lifecycle() {
  const close = body('closeShellRemember');
  const closeStart = close.indexOf('    if (idx >= shell_count) return;');
  const closeEnd = close.indexOf('    accountRecordClose(idx);');
  const historyStart = close.indexOf('    if (remember_closed) {');
  const historyEnd = close.indexOf('\n    if (shells[idx].kind == .tmux)', historyStart);
  const compactStart = close.indexOf('    var i = idx;');
  const compactEnd = close.indexOf('    pruneEmptyGroups();', compactStart);
  assert.ok(closeStart >= 0 && closeEnd > closeStart);
  assert.ok(historyStart >= 0 && historyEnd > historyStart);
  assert.ok(compactStart >= 0 && compactEnd > compactStart);
  const state = fs.readFileSync('src/app_state.zig', 'utf8');
  const closedType = state.match(/pub const ClosedShell = struct \{[^]*?\n\};/);
  assert.ok(closedType);
  const groupType = state.match(/^const TabGroup = struct \{[^]*?\n\};/m);
  assert.ok(groupType);
  const spawn = body('spawnShellWithSession');
  const initializer = spawn.match(/\.chat_id = g_pending_chat_id,/);
  assert.ok(initializer, 'spawn installs reopened identity before switching');
  assert.ok(spawn.indexOf(initializer[0]) < spawn.indexOf('switchToShellByUser(idx)'));
  const reconnect = body('respawnShellInPlace');
  const capture = reconnect.match(/^    const saved_chat_id = shells\[idx\]\.chat_id;$/m);
  const restored = reconnect.match(/\.chat_id = saved_chat_id,/);
  assert.ok(capture && restored, 'reconnect preserves identity in the replacement shell');
  return production() + `
${closedType[0].replace('pub const', 'const')}
${groupType[0]}
var groups: [1]TabGroup = undefined;
fn findGroupIdx(_: u32) ?u32 { return null; }
fn restoreSessionGroup(_: TabGroup, _: u8, _: bool) u32 { return 0; }
const MAX_CLOSED_HISTORY = 10;
const empty_shell: Shell = .{};
var g_closed_history: [MAX_CLOSED_HISTORY]ClosedShell = undefined;
var g_closed_count: u32 = 0;
var g_pending_tmux_host: u8 = 0;
var g_pending_chat_id: u64 = 0;
var fail_spawn = false;
fn closeShellRemember(idx: u32, remember_closed: bool) void {
${close.slice(closeStart, closeEnd).replaceAll('@import("chat_composer.zig").', '')}
${close.slice(historyStart, historyEnd)}
${close.slice(compactStart, compactEnd)}
    if (shell_count > 0) switchToShell(@min(active_shell, shell_count - 1));
}
fn spawnShellWithSession(_: @TypeOf(shells[0].kind), _: ?[]const u8, _: ?[]const u8, _: ?[]const u8) bool {
    if (fail_spawn) return false;
    const idx = shell_count;
    shells[idx] = .{ ${initializer[0]} .shell_id = 20 };
    shell_count += 1;
    switchToShell(idx);
    saveSession();
    return true;
}
${body('reopenLastClosedShell')}
fn reconnect(idx: u32) void {
${capture[0]}
    shells[idx] = .{ ${restored[0]} .shell_id = 30 };
}
`;
}

test('ISSUE-498 reconnect and undo-close preserve draft identity through real lifecycle wiring', () => {
  execute(lifecycle() + `
test "ISSUE-498 reconnect then close-reopen restores the same persisted draft" {
    switchToShell(0); edit(L("draft A"));
    reconnect(0);
    switchToShell(1); try expectText(&.{});
    switchToShell(0); try expectText(L("draft A"));
    closeShellRemember(0, true);
    try expectText(&.{});
    try std.testing.expectEqual(@as(u32, 1), chat_drafts.entries.count());
    reopenLastClosedShell();
    try expectText(L("draft A"));
    try std.testing.expectEqual(@as(u64, 101), shells[1].chat_id);
    try std.testing.expectEqual(@as(u64, 101), saved_chat_ids[1]);
    switchToShell(0); try expectText(&.{});
    switchToShell(1); try expectText(L("draft A"));
    try std.testing.expectEqual(@as(u64, 0), g_pending_chat_id);
}
`);
});

test('ISSUE-498 closed-session dictation is dropped and permanently closed drafts are evicted', () => {
  execute(lifecycle() + `
test "ISSUE-498 a late closed-session result cannot recreate an orphan or enter the active draft" {
    switchToShell(0); edit(L("draft A"));
    var owner_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const owner = chatDraftKeyForShell(0, &owner_buf);
    closeShellRemember(0, false);
    const count = chat_drafts.entries.count();
    try std.testing.expect(!chat_drafts.entries.contains(owner));
    chatDraftAppend(owner, L("late words"));
    try std.testing.expectEqual(count, chat_drafts.entries.count());
    try std.testing.expect(!chat_drafts.entries.contains(owner));
    try expectText(&.{});
    closeShellRemember(0, false);
    try std.testing.expectEqual(@as(u32, 0), chat_drafts.entries.count());
    try std.testing.expectEqual(@as(usize, 0), g_chat_draft_owner_len);
    try expectText(&.{});
}
`);
});

test('ISSUE-498 failed persistence retries before eviction and failed reopen keeps the identity', () => {
  execute(lifecycle() + `
test "ISSUE-498 close retains unsaved text only until persistence succeeds" {
    switchToShell(0); edit(L("retry A"));
    var owner_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const owner = chatDraftKeyForShell(0, &owner_buf);
    fail_write = true;
    closeShellRemember(0, true);
    try std.testing.expect(chat_drafts.entries.get(owner).?.dirty);
    try std.testing.expect(chat_drafts.entries.get(owner).?.evict);
    fail_spawn = true;
    reopenLastClosedShell();
    try std.testing.expectEqual(@as(u32, 1), g_closed_count);
    try std.testing.expectEqual(@as(u64, 0), g_pending_chat_id);
    fail_write = false;
    chatDraftFlush();
    try std.testing.expect(!chat_drafts.entries.contains(owner));
    fail_spawn = false;
    reopenLastClosedShell();
    try expectText(L("retry A"));
    try std.testing.expectEqual(@as(u64, 101), shells[1].chat_id);
}
`);
});
