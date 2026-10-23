const { copyZig } = require('./zig-copy');
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const source = require('./app-source').readAppSource();
const read = name => fs.readFileSync(path.join(__dirname, '..', name), 'utf8');
function between(start, end, text = source) {
  const a = text.indexOf(start), b = text.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `${start} / ${end}`);
  return text.slice(a, b);
}
const normalize = text => text.replaceAll('pub fn ', 'fn ').replaceAll('app_state.', '').replaceAll('@import("inbox.zig").nowFileTime()', 'nowFileTime()').replaceAll('@import("account_desktop.zig").publishSessionLayout()', 'publishSessionLayout()').replaceAll('@import("account_desktop.zig").accountPush()', 'accountPush()');
const painting = between('    var y: i32 = list_top;', '    _ = SelectObject(hdc, font_subtitle);\n    _ = SetTextColor(hdc, fg_dim);\n    var ft_rc', read('src/inbox.zig'));
const harness = `const std = @import("std");
const frequent = @import("frequent.zig");
const launch_cache = struct { var pending = false; };
const json_reader = @import("json_reader.zig");
const archive_rules = @import("archive_rules.zig");
const DWORD = u32;
const SWP_NOSIZE: u32 = 0x0001;
const SWP_NOMOVE: u32 = 0x0002;
const SWP_FRAMECHANGED: u32 = 0x0020;
const SWP_SHOWWINDOW: u32 = 0x0040;
const SWP_HIDEWINDOW: u32 = 0x0080;
const MAX_LWS: u8 = 16;
const BROWSER_SPLIT_DEFAULT_PERMILLE: u16 = 350;
const Shell = struct { last_used: u64 = 0, input: u64 = 0, synced_input: u64 = 0, input_publish_pending: bool = false, visits: frequent.Visits = .{}, shell_id: u32 = 1, workspace: u8 = 0, inbox_excluded: bool = false };
var active_shell: u32 = 0;
var g_single_window = false;
var g_active_workspace: u8 = 0;
var g_front_period: frequent.FrontPeriod = .{};
var g_account_locked = false;
var g_inbox_active = false;
var g_all_sessions_active = false;
var g_search_active = false;
var g_shortcuts_active = false;
var g_changelog_active = false;
var g_url_picker_active = false;
const TIMER_VISIT_DWELL: usize = 173;
var fake_tick: u64 = 0;
var focused = true;
var visit_publications: usize = 0;
var saves: usize = 0;
fn foregroundIsOurs() bool { return focused; }
fn GetTickCount64() u64 { return fake_tick; }
fn KillTimer(_: ?*anyopaque, _: usize) i32 { return 1; }
fn SetTimer(_: ?*anyopaque, _: usize, _: u32, _: ?*anyopaque) usize { return 1; }
fn publishInboxStateNow() void { visit_publications += 1; }
fn saveSession() void { saves += 1; }
fn loadInboxModel() void {}
fn InvalidateRect(_: ?*anyopaque, _: ?*anyopaque, _: i32) i32 { return 1; }
const InboxWs = struct { hwnd: usize = 2, attn: u32 = 0, name: [64]u8 = .{0} ** 64, name_len: u32 = 0 };
var shells = [_]Shell{.{}} ** 6;
var shell_count: u32 = 1;
var g_restoring = false;
var g_startup_progress = false;
var g_account_applying = false;
var g_account_dirty_at: u64 = 0;
var g_session_save_pending = false;
var g_main_hwnd: ?*anyopaque = @ptrFromInt(1);
var g_inbox_tab: u32 = 0;
var g_unread_only = false;
var g_inbox_ws = [_]InboxWs{.{}} ** 4;
var g_inbox_ws_count: u32 = 4;
var g_inbox_rows: [6]InboxRow = undefined;
var g_inbox_row_count: u32 = 0;
var fake_now_ms: u64 = 1_800_000_000_000;
var pushes: usize = 0;
fn nowFileTime() u64 { return (fake_now_ms + 11_644_473_600_000) * 10_000; }
fn publishInboxState() void {}
fn publishSessionLayout() void { g_account_dirty_at = 1; }
fn accountPush() void { pushes += 1; }
fn findShellById(sid: u32) ?u32 { for (shells[0..shell_count], 0..) |shell, i| { if (sid == shell.shell_id) return @intCast(i); } return null; }
fn inboxFilterMatches(_: *const InboxRow) bool { return true; }
const RECT = struct { left: i32, top: i32, right: i32, bottom: i32 };
var g_inbox_sel: u32 = 0;
var g_multiprompt_theme = false;
var g_light_theme = false;
var g_eta_numbers_on = false;
var g_eta_progress_on = false;
const hdc: usize = 0;
const font_title: usize = 0;
const font_subtitle: usize = 0;
const fg_bright: u32 = 0;
const fg_dim: u32 = 0;
const blue: u32 = 0;
const DT_SINGLELINE: u32 = 1;
const DT_VCENTER: u32 = 2;
const DT_NOPREFIX: u32 = 4;
const DT_END_ELLIPSIS: u32 = 8;
const DT_RIGHT: u32 = 16;
var drawn_names: [6][64]u16 = undefined;
var drawn_y: [6]i32 = undefined;
var drawn_count: usize = 0;
fn uiScaled(n: i32) i32 { return n; }
fn RGB(_: u8, _: u8, _: u8) u32 { return 0; }
fn customColorOr(_: []const u8, n: u32) u32 { return n; }
fn CreateSolidBrush(_: u32) usize { return 0; }
fn FillRect(_: usize, _: *RECT, _: usize) i32 { return 1; }
fn DeleteObject(_: usize) i32 { return 1; }
fn SelectObject(_: usize, _: usize) usize { return 0; }
fn SetTextColor(_: usize, _: u32) u32 { return 0; }
fn drawAttentionDot(_: usize, _: i32, _: i32, _: i32, _: u32) void {}
fn drawAgentIcon(_: usize, _: *RECT, _: u8, _: bool) void {}
fn asciiToU16(s: []const u8, out: []u16) usize { for (s, 0..) |c, i| out[i] = c; return s.len; }
fn DrawTextW(_: usize, text: [*]const u16, len: i32, rc: *RECT, _: u32) i32 {
    if (rc.left == 44 and rc.right == 400) {
        drawn_names[drawn_count] = .{0} ** 64;
        @memcpy(drawn_names[drawn_count][0..@intCast(len)], text[0..@intCast(len)]);
        drawn_y[drawn_count] = rc.top;
        drawn_count += 1;
    }
    return 1;
}
fn inboxRelTime(_: u64, _: []u16) usize { return 0; }
fn etaRemainingMs(_: u64, _: u64) i64 { return 0; }
fn formatEtaRemaining(_: i64, _: []u8) []const u8 { return ""; }
fn etaOverdueColor() u32 { return 0; }
fn etaFillFraction(_: u64, _: u64) f32 { return 0; }
fn etaElapsedMs(_: u64, _: i64) u64 { return 0; }
` + between('const ShellKind =', 'const ShellActivity =') +
  between('const SavedTab = struct', 'const ISSUE_347_KEEP_FULL_WIDTH') +
  between('const InboxRow = struct', 'var g_session_save_pending') +
  normalize(between('fn stampSessionUse(', 'fn inboxPublishesShell(')) +
  normalize(between('pub fn sessionFrontSelected(', 'fn wndProc(', read('src/main.zig'))) +
  between('fn inboxFrequent(', 'fn loadInboxModel(') +
  between('const favoriteSplitMatches =', 'fn toggleFavorite(') +
  between('fn inboxRowVisible(', 'test "cached inbox navigation') +
  between('fn inboxVisibleCount(', 'fn rememberInboxRow(') + `
fn paintRows() void {
    const list_top: i32 = 54;
    const row_h: i32 = 32;
    const w: i32 = 1000;
    const scroll_row: u32 = 0;
    const max_rows: u32 = 20;
` + normalize(painting) + `
}
test "v2 production stamp every input and publish once per synced minute" {
    shells[0] = .{};
    pushes = 0;
    stampSessionUse(0, false);
    try std.testing.expectEqual(fake_now_ms, shells[0].input);
    try std.testing.expectEqual(@as(usize, 1), pushes);
    fake_now_ms += 1;
    stampSessionUse(0, true);
    try std.testing.expectEqual(fake_now_ms, shells[0].input);
    try std.testing.expectEqual(@as(usize, 1), pushes);
    shells[0].synced_input = fake_now_ms;
    shells[0].input_publish_pending = false;
    fake_now_ms += 60_000;
    stampSessionUse(0, true);
    try std.testing.expectEqual(@as(usize, 1), pushes);
    fake_now_ms += 1;
    stampSessionUse(0, true);
    try std.testing.expectEqual(@as(usize, 2), pushes);
    g_restoring = true;
    const before = shells[0].input;
    fake_now_ms += 1;
    stampSessionUse(0, false);
    try std.testing.expectEqual(before, shells[0].input);
    g_restoring = false;
}
test "v2 production user-only focused dwell resets on loss of focus and switches stamp nothing" {
    g_front_period = .{};
    shell_count = 2;
    shells[0] = .{ .shell_id = 1 };
    shells[1] = .{ .shell_id = 2 };
    active_shell = 0;
    fake_tick = 0;
    focused = true;
    visit_publications = 0;
    sessionFrontChanged();
    fake_tick = 10_000;
    recordFrontVisit();
    try std.testing.expectEqual(@as(usize, 0), visit_publications);
    sessionFrontSelected();
    fake_tick += 9999;
    recordFrontVisit();
    try std.testing.expectEqual(@as(usize, 0), visit_publications);
    focused = false;
    sessionFrontChanged();
    fake_tick += 60_000;
    recordFrontVisit();
    try std.testing.expectEqual(@as(usize, 0), visit_publications);
    focused = true;
    fake_now_ms += 60_000;
    sessionFrontChanged();
    const started = fake_now_ms;
    fake_tick += 10_000;
    recordFrontVisit();
    try std.testing.expectEqualSlices(u64, &.{started}, shells[0].visits.optional().?);
    recordFrontVisit();
    sessionFrontSelected();
    try std.testing.expectEqual(@as(usize, 1), visit_publications);
    active_shell = 1;
    sessionFrontChanged();
    fake_tick += 10_000;
    recordFrontVisit();
    try std.testing.expectEqual(@as(u8, 0), shells[1].visits.len);
    try std.testing.expectEqual(@as(u64, 0), shells[1].input);
    try std.testing.expectEqual(@as(u64, 0), shells[1].last_used);
    sessionFrontSelected();
    fake_tick += 10_000;
    recordFrontVisit();
    try std.testing.expectEqual(@as(usize, 2), visit_publications);
}
test "ISSUE-502 v2 cached placeholders cannot record a front visit before deferred restore" {
    g_front_period = .{};
    shell_count = 1;
    shells[0] = .{ .shell_id = 42 };
    active_shell = 0;
    fake_tick = 0;
    focused = true;
    launch_cache.pending = true;
    defer launch_cache.pending = false;
    sessionFrontSelected();
    fake_tick += 10_000;
    recordFrontVisit();
    try std.testing.expectEqual(@as(u8, 0), shells[0].visits.len);
    launch_cache.pending = false;
    sessionFrontSelected();
    fake_tick += 10_000;
    recordFrontVisit();
    try std.testing.expectEqual(@as(u8, 1), shells[0].visits.len);
}
test "v2 fixture production paint puts beta alpha gamma on screen and gamma at greatest y" {
    const Fixture = struct { now: u64, layout: @import("session_layout.zig").Layout, expected: []const []const u8 };
    const parsed = try std.json.parseFromSlice(Fixture, std.testing.allocator, @embedFile("fixture.json"), .{});
    defer parsed.deinit();
    const fixture = parsed.value;
    fake_now_ms = fixture.now;
    g_inbox_tab = frequent.frequent_split;
    g_inbox_row_count = @intCast(fixture.layout.tabs.len);
    for (fixture.layout.tabs, 0..) |tab, i| {
        g_inbox_rows[i] = .{ .ws = 0, .sid = @intCast(i + 1), .input = tab.input orelse 0, .last_used = tab.used orelse 0, .visits = frequent.Visits.merge(tab.visits, null), .name_len = @intCast(tab.name.len), .la = if (i == 5) nowFileTime() else 1 };
        @memcpy(g_inbox_rows[i].name[0..tab.name.len], tab.name);
    }
    sortInboxRows();
    try std.testing.expectEqual(@as(u32, 3), inboxVisibleCount());
    drawn_count = 0;
    paintRows();
    try std.testing.expectEqual(fixture.expected.len, drawn_count);
    for (fixture.expected, 0..) |name, i| {
        var wide: [64]u16 = .{0} ** 64;
        _ = asciiToU16(name, &wide);
        try std.testing.expectEqualSlices(u16, &wide, &drawn_names[i]);
        try std.testing.expectEqual(@as(i32, 54) + @as(i32, @intCast(i)) * 32, drawn_y[i]);
    }
    try std.testing.expect(drawn_y[2] > drawn_y[1]);
}
`;

function runHarness(mutate = x => x) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-frequent-'));
  try {
    copyZig(['frequent.zig', 'json_reader.zig', 'archive_rules.zig', 'voice_filter.zig', 'session_layout.zig', 'workspace_view.zig'], dir);
    fs.mkdirSync(path.join(dir, 'fixtures'), { recursive: true });
    fs.copyFileSync(path.join(__dirname, 'fixtures/issue-415-frequent.json'), path.join(dir, 'fixture.json'));
    fs.copyFileSync(path.join(__dirname, 'fixtures/issue-415-frequent.json'), path.join(dir, 'fixtures/issue-415-frequent.json'));
    fs.writeFileSync(path.join(dir, 'integration.zig'), mutate(harness));
    return spawnSync(process.env.ZIG || 'zig', ['test', '-j1', path.join(dir, 'integration.zig'), '--test-filter', 'v2'], { encoding: 'utf8', timeout: 120000 });
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('v2 production input stamps focused user-only dwell and actual painted screen rows execute', () => {
  const result = runHarness();
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stderr, /All \d+ tests passed/);
});

test('v2 regressions reject missing focus gating input stamps and reversed on-screen ordering', () => {
  for (const mutate of [
    s => s.replace('foregroundIsOurs(), frequent.unixMs', 'true, frequent.unixMs'),
    s => s.replace('!launch_cache.pending and ', ''),
    s => s.replace('shells[idx].input = @max(shells[idx].input, now_ms);', ''),
    s => s.replace('return frequent.bottomOrder(ka, kb);', 'return ka > kb;'),
  ]) {
    const result = runHarness(mutate);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /FAIL/, result.stdout + result.stderr);
  }
});

test('v2 send voice auto-send voice terminal and physical keystrokes all stamp input', () => {
  const send = between('fn sendChatPrompt(', 'fn chatNetworkReportsConnected(');
  assert.match(send, /stampSessionUse\(active_shell, false\)/);
  assert.doesNotMatch(send, /if \(!g_voice_auto_sending\).*stampSessionUse/);
  for (const name of ['voiceSendTranscriptToShell', 'voicePasteTranscriptToShellNoEnter']) {
    assert.match(between(`pub fn ${name}(`, '\npub fn ', read('src/chat_send.zig')), /stampSessionUse\(app_state.active_shell, false\)/);
  }
  assert.match(read('src/voice.zig'), /paste_result != \.delivery_failed\).*stampSessionUse/);
  const hook = between('fn keyboardHookProc(', 'fn pointOverActiveShell(');
  assert.match(hook, /\(kb.flags & 0x10\) == 0 and activeShellHasForegroundFocus\(\)[\s\S]*?stampSessionUse\(active_shell, true\)/);
  assert.match(hook, /if \(nCode >= 0 and \(wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN\)\) \{[\s\S]*?shellInputKey\(kb.vkCode\)[\s\S]*?stampSessionUse\(active_shell, true\)/);
});

test('v2 only explicit user navigation arms looks and switches never stamp used', () => {
  const console = read('src/console.zig');
  const main = read('src/main.zig');
  const inbox = read('src/inbox.zig');
  const switching = between('pub fn switchToShell(idx:', 'pub fn nthVisibleShell(', console);
  assert.doesNotMatch(switching, /stampSessionUse/);
  assert.doesNotMatch(switching, /sessionFrontSelected/);
  assert.match(between('pub fn switchToShellByUser(', 'pub fn switchToShell(idx:', console), /sessionFrontSelected/);
  for (const msg of ['WM_APP_NEXT_TAB', 'WM_APP_PREV_TAB', 'WM_APP_SWITCH_TAB']) assert.match(between(`        ${msg} =>`, '\n        WM_APP_', main), /switchToShellByUser/);
  assert.match(main, /switchToShellByUser\(tab_idx\)/);
  assert.match(main, /switchToShellByUser\(@intCast\(target\)\)/);
  assert.doesNotMatch(between('        WM_APP_NEXT_UNREAD =>', '\n        WM_APP_', main), /switchToShellByUser/);
  assert.match(between('pub fn jumpToInboxRow(', 'fn jumpToInboxRowSelected(', inbox), /jumpToInboxRowSelected\(ri, false\)/);
  assert.match(between('pub fn inboxJump(', 'pub fn inboxStepJump(', inbox), /jumpToInboxRowSelected\(ri, true\)/);
  assert.doesNotMatch(between('pub fn inboxStepJump(', 'pub fn refreshNextUnreadCache(', inbox), /sessionFrontSelected|switchToShellByUser|Selected\(ri, true\)/);
  assert.match(read('src/focus.zig'), /EVENT_SYSTEM_FOREGROUND[\s\S]*?sessionFrontChanged\(\)/);
  assert.match(between('pub fn respawnShellInPlace(', '\npub fn ', console), /g_front_period.selected = null/);
});

test('v2 input survives every persistence move restore and sync path', () => {
  for (const file of ['src/session.zig', 'src/workspaces.zig', 'src/inbox.zig', 'src/reminders.zig']) assert.match(read(file), /writeInput\(/, file);
  for (const literal of ['shell.input = tab.input;', 'shells[idx].input = tabs[t].input;', '.input = saved_input,', 'transfer.input = shell.input;', 'new_shell.input = transfer.input;', 'new_shell.input = g_adopt_input;', 'g_inbox_rows[ri].input = json_reader.uint(o, "input");']) assert.ok(source.includes(literal), literal);
  assert.match(read('src/json_reader.zig'), /tab.input = uint\(obj, "input"\)/);
  assert.match(read('src/account_desktop.zig'), /shell.input = @max\(shell.input, input\)/);
  assert.match(read('src/account_client.zig'), /X-Layout-Features: favorite,muted,used,visits,input/);
  assert.match(read('src/startup.zig'), /g_adopt_input = std.fmt.parseInt/);
  assert.match(read('src/workspaces.zig'), /writeNum\(&cmd_buf, &pos, shell.input\)/);
});

test('v2 shared fixture is byte-identical and Frequent stays first with selected-split migration', () => {
  const file = read('tools/fixtures/issue-415-frequent.json');
  assert.equal(read('src/fixtures/issue-415-frequent.json'), file);
  const fixture = JSON.parse(file);
  assert.equal(fixture.now, 1_800_000_000_000);
  assert.deepEqual(fixture.expected, ['beta', 'alpha', 'gamma']);
  assert.ok(fixture.layout.tabs.every(tab => tab.tmux_host === 0));
  const paint = between('fn paintInbox(', 'fn openInbox(');
  assert.ok(paint.indexOf('"Frequent"') < paint.indexOf('"All"'));
  assert.ok(paint.indexOf('"All"') < paint.indexOf('"Favorites"'));
  assert.match(read('src/session.zig'), /migrateSplit/);
  assert.ok(read('src/sidebar.zig').includes('L("Inbox: Frequent")'));
  assert.ok(read('src/shortcuts.zig').includes('.a = "Ctrl+K -> Inbox: Frequent"'));
});
