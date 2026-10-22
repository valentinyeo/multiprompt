const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function fn(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `Missing production function ${name}`);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

test('ISSUE-573 extracted production link routing preserves exact URLs and legacy pane behavior', () => {
  const source = read('src/browser_pane.zig');
  const shortcuts = read('src/shortcuts.zig');
  const production = `const std = @import("std");
const app_state = @This();
const SW_SHOW = 5;
const L = std.unicode.utf8ToUtf16LeStringLiteral;
var shells = [_]struct { browser_enabled: bool = false }{ .{}, .{} };
var shell_count: u32 = 2;
var active_shell: u32 = 0;
var g_external_browser_links = true;
var g_main_hwnd: ?usize = 1;
var webview_owner: ?u32 = null;
var external_calls: usize = 0;
var pane_calls: usize = 0;
var native_focus_calls: usize = 0;
var webview_focus_calls: usize = 0;
var pane_idx: u32 = 0;
var pane_activate = false;
var external_url: [16384]u16 = undefined;
var external_len: usize = 0;
var pane_url: [16384]u8 = undefined;
var pane_len: usize = 0;
const POINT = struct { x: i32 = 0, y: i32 = 0 };
fn webView2OwnsShell(idx: u32) bool { return webview_owner != null and webview_owner.? == idx; }
fn webView2OwnsActiveShell() bool { return webView2OwnsShell(active_shell); }
fn requestNativeBrowserFocus() void { native_focus_calls += 1; }
fn requestWebView2Focus() void { webview_focus_calls += 1; }
fn IsIconic(_: ?usize) i32 { return 0; }
fn pointOverActiveShell(_: POINT) bool { return true; }
fn isCtrlDown() bool { return true; }
fn ShellExecuteW(owner: ?usize, operation: ?[*:0]const u16, url: [*:0]const u16, parameters: ?[*:0]const u16, directory: ?[*:0]const u16, show: i32) usize {
    std.debug.assert(owner == null and parameters == null and directory == null and show == SW_SHOW);
    std.debug.assert(std.mem.eql(u16, std.mem.span(operation.?), L("open")));
    external_calls += 1;
    const text = std.mem.span(url);
    @memcpy(external_url[0..text.len], text);
    external_len = text.len;
    return 33;
}
fn navigateBrowserPaneWithActivation(idx: u32, url: []const u8, activate: bool) void {
    pane_calls += 1;
    pane_idx = idx;
    pane_activate = activate;
    @memcpy(pane_url[0..url.len], url);
    pane_len = url.len;
    shells[idx].browser_enabled = true;
}
${fn(source, 'openSessionLink').replaceAll('std.heap.page_allocator', 'std.testing.allocator')}
${fn(read('src/chat_render.zig'), 'chatOpenUrlBytes')}
${fn(shortcuts, 'ctrlClickOverActiveShell')}
${fn(read('src/focus.zig'), 'wantMouseHookForUrlClicks')}
fn reset() void {
    shells = .{ .{}, .{} };
    g_external_browser_links = true;
    active_shell = 0;
    webview_owner = null;
    external_calls = 0;
    pane_calls = 0;
    native_focus_calls = 0;
    webview_focus_calls = 0;
    external_len = 0;
    pane_len = 0;
}
fn expectExternal(url: []const u8) !void {
    reset();
    try std.testing.expect(!openSessionLink(0, url));
    try std.testing.expectEqual(@as(usize, 1), external_calls);
    try std.testing.expectEqual(@as(usize, 0), pane_calls);
    const expected = try std.unicode.utf8ToUtf16LeAllocZ(std.testing.allocator, url);
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqualSlices(u16, expected, external_url[0..external_len]);
    try std.testing.expect(!shells[0].browser_enabled);
}
fn expectPane(idx: u32, url: []const u8) !void {
    try std.testing.expect(openSessionLink(idx, url));
    try std.testing.expectEqual(@as(usize, 0), external_calls);
    try std.testing.expectEqual(@as(usize, 1), pane_calls);
    try std.testing.expectEqual(idx, pane_idx);
    try std.testing.expect(pane_activate);
    try std.testing.expectEqualStrings(url, pane_url[0..pane_len]);
}
test "ISSUE-573 pane off and mode on requests exact HTTP(S) URL with ShellExecute open" {
    for ([_][]const u8{ "http://example.test/a?x=1&y=2#part", "https://example.test/a%2Fb?q=x+y#part", "HTTPS://example.test/Case", "https://example.test/中文?q=é#😀" }) |url| try expectExternal(url);
    const long = "https://example.test/" ++ "x" ** 9000;
    try expectExternal(long);
}
test "ISSUE-573 pane on uses the pane and never requests an external open" {
    reset();
    shells[0].browser_enabled = true;
    try expectPane(0, "https://example.test/pane");
}
test "ISSUE-573 WebView2 is a pane even when native browser_enabled is false" {
    reset();
    webview_owner = 0;
    try expectPane(0, "https://example.test/webview");
}
test "ISSUE-573 mode off preserves pane-off navigation that reopens the pane" {
    reset();
    g_external_browser_links = false;
    try expectPane(0, "https://example.test/legacy");
    try std.testing.expect(shells[0].browser_enabled);
}
test "ISSUE-573 non-HTTP schemes never request an external open" {
    for ([_][]const u8{ "file:///C:/example.txt", "mailto:hello@example.test", "javascript:alert(1)", "data:text/plain,hello", "about:blank", "ftp://example.test/a", "httpsx://example.test", "www.example.test" }) |url| {
        reset();
        try expectPane(0, url);
    }
}
test "ISSUE-573 routing uses the clicked session, not another session's pane" {
    reset();
    shells[0].browser_enabled = true;
    try std.testing.expect(!openSessionLink(1, "https://example.test/off"));
    try std.testing.expectEqual(@as(usize, 1), external_calls);
    try std.testing.expectEqual(@as(usize, 0), pane_calls);
    try std.testing.expect(!shells[1].browser_enabled);
    reset();
    shells[1].browser_enabled = true;
    try expectPane(1, "https://example.test/on");
}
test "ISSUE-573 external links do not request pane focus and pane links retain their focus path" {
    reset();
    chatOpenUrlBytes("https://example.test/external");
    try std.testing.expectEqual(@as(usize, 1), external_calls);
    try std.testing.expectEqual(@as(usize, 0), native_focus_calls + webview_focus_calls);
    reset();
    shells[0].browser_enabled = true;
    chatOpenUrlBytes("https://example.test/native");
    try std.testing.expectEqual(@as(usize, 1), native_focus_calls);
    try std.testing.expectEqual(@as(usize, 0), webview_focus_calls + external_calls);
    reset();
    webview_owner = 0;
    chatOpenUrlBytes("https://example.test/webview");
    try std.testing.expectEqual(@as(usize, 1), webview_focus_calls);
    try std.testing.expectEqual(@as(usize, 0), native_focus_calls + external_calls);
}
test "ISSUE-573 missing sessions never open a browser" {
    reset();
    try std.testing.expect(!openSessionLink(2, "https://example.test/missing"));
    try std.testing.expectEqual(@as(usize, 0), external_calls + pane_calls);
}
test "ISSUE-573 terminal Ctrl-click eligibility preserves mode-off behavior" {
    reset();
    try std.testing.expect(ctrlClickOverActiveShell(.{}));
    try std.testing.expect(wantMouseHookForUrlClicks());
    g_external_browser_links = false;
    try std.testing.expect(!ctrlClickOverActiveShell(.{}));
    try std.testing.expect(!wantMouseHookForUrlClicks());
    shells[0].browser_enabled = true;
    try std.testing.expect(ctrlClickOverActiveShell(.{}));
    try std.testing.expect(wantMouseHookForUrlClicks());
    shells[0].browser_enabled = false;
    webview_owner = 0;
    try std.testing.expect(ctrlClickOverActiveShell(.{}));
    try std.testing.expect(wantMouseHookForUrlClicks());
}
`;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'external-browser-links-'));
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, production);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.error, undefined);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
    console.log(result.stderr.trim());
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
