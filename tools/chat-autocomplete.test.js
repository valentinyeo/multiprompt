const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const src = require('./app-source').readAppSource();
const docs = fs.readFileSync('openwiki/operations/keyboard-shortcuts.md', 'utf8');
test('command browse is reachable from keyboard, palette, and F1', () => {
  assert.match(src, /SEARCH_CHAT_AC_OFFSET: usize = 6356/);
  assert.match(src, /CHAT_AC_ENTER_SENDS = false/);
  assert.match(src, /0xBF => true/);
  assert.match(src, /chatAcOpenBrowse\(\)/);
  assert.match(src, /Chat View: Insert Command or Skill\.\.\./);
  assert.match(src, /\.a = "Ctrl\+\/ in Chat View"/);
  assert.match(docs, /Ctrl\+\/ in Chat View/);
});
test('popup is hidden on send, tab switch, close and overlay', () => {
  for (const fn of ['sendChatPrompt', 'switchToShell', 'closeChatView', 'hideShellsForOverlay']) {
    assert.match(src, new RegExp(`fn ${fn}\\([^]*?\\) void \\{\\s*chatAcClose\\(\\);`));
  }
  assert.match(src, /endsInTriggerToken\(send_text/);
  assert.match(src, /g_chat_ac_mru_count/);
  assert.match(src, /chat_ac_\{s\}_\{d\}/);
  assert.match(src, /WM_APP_CHAT_AC_READY: u32 = WM_APP \+ 143/);
});

test('IGSH-911 Ctrl+Enter sends once before native translation; Enter and Shift+Enter stay unchanged', () => {
  const os = require('node:os');
  const path = require('node:path');
  const { spawnSync } = require('node:child_process');
  const shortcuts = fs.readFileSync('src/shortcuts.zig', 'utf8');
  const hookStart = shortcuts.indexOf('        if (kb.vkCode == 0x0D and wp == WM_KEYDOWN and isCtrlDown()');
  const hookEnd = shortcuts.indexOf('\n        if (wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN)', hookStart);
  assert.ok(hookStart >= 0 && hookEnd > hookStart);
  const hook = shortcuts.slice(hookStart, hookEnd)
    .replaceAll('@import("chat_composer.zig").chatShellDraftNoteSend', 'chatShellDraftNoteSend')
    .replaceAll('@import("win32.zig").WM_APP_CHAT_SEND', 'WM_APP_CHAT_SEND');
  for (const [source, broken] of [['tools/fixtures/IGSH-911/composer-enter.zig', true], ['src/chat_composer.zig', false]]) {
    const composer = fs.readFileSync(source, 'utf8');
    const start = composer.indexOf('    if (msg == 0x0102) {', composer.indexOf('fn chatComposerSubclassCore('));
    const end = composer.indexOf('\n    return CallWindowProcW', start);
    assert.ok(start >= 0 && end > start);
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'composer-enter-'));
    const program = `const std = @import("std");
const app_state = struct {
    var g_chat_ac_tab_accepted = false;
    var g_chat_ac = struct { open: bool = false }{};
    var g_win_held = false;
    var g_chat_composer_hwnd: ?usize = 2;
    const g_main_hwnd: ?usize = 1;
};
const WM_KEYDOWN = 0x0100;
const VK_MENU = 0x12;
const WM_APP_CHAT_SEND = 123;
const CHAT_AC_ENTER_SENDS = false;
var ctrl_down = false;
var shift_down = false;
var alt_down = false;
var chat_active = true;
var focus: ?usize = 2;
var foreground: ?usize = 1;
var sends: usize = 0;
var notes: usize = 0;
var accepts: usize = 0;
fn isCtrlDown() bool { return ctrl_down; }
fn isAltDown(_: u32) bool { return alt_down; }
fn GetAsyncKeyState(key: i32) i16 { return if (key == 0x10 and shift_down) -32768 else 0; }
fn GetFocus() ?usize { return focus; }
fn GetForegroundWindow() ?usize { return foreground; }
fn chatViewOwnsInput() bool { return chat_active; }
fn chatAcAccept() bool { accepts += 1; return true; }
fn chatAcClose() void { app_state.g_chat_ac.open = false; }
fn chatShellDraftNoteSend() void { notes += 1; }
fn PostMessageW(_: ?usize, message: u32, wp: usize, lp: usize) i32 {
    std.debug.assert(message == WM_APP_CHAT_SEND and wp == 0 and lp == 0);
    sends += 1;
    return 1;
}
fn keyboard(wp: usize, vk: u32) i32 {
    const kb = .{ .vkCode = vk, .flags = @as(u32, 0) };
${broken ? '    _ = wp; _ = kb;' : hook}
    return 0;
}
fn character(wp: usize) i32 {
    const msg = 0x0102;
${composer.slice(start, end)}
    return 1;
}
test "composer keyboard delivery" {
    ctrl_down = true;
    const consumed = keyboard(WM_KEYDOWN, 0x0D);
    if (consumed == 0) _ = character(0x0A);
    try std.testing.expectEqual(@as(usize, 1), sends);
    try std.testing.expectEqual(@as(usize, 1), notes);
    try std.testing.expectEqual(@as(i32, 1), consumed);
    try std.testing.expectEqual(@as(i32, 0), keyboard(0x0101, 0x0D));
    try std.testing.expectEqual(@as(usize, 1), sends);
    shift_down = true;
    try std.testing.expectEqual(@as(i32, 0), keyboard(WM_KEYDOWN, 0x0D));
    try std.testing.expectEqual(@as(i32, 1), character(0x0A));
    ctrl_down = false;
    try std.testing.expectEqual(@as(i32, 1), character(0x0D));
    try std.testing.expectEqual(@as(usize, 1), sends);
    shift_down = false;
    try std.testing.expectEqual(@as(i32, 0), keyboard(WM_KEYDOWN, 0x0D));
    try std.testing.expectEqual(@as(i32, 0), character(0x0D));
    try std.testing.expectEqual(@as(usize, 2), sends);
    app_state.g_chat_ac.open = true;
    try std.testing.expectEqual(@as(i32, 0), character(0x0D));
    try std.testing.expectEqual(@as(usize, 1), accepts);
    ctrl_down = true;
    try std.testing.expectEqual(@as(i32, 1), keyboard(WM_KEYDOWN, 0x0D));
    try std.testing.expectEqual(@as(usize, 3), sends);
    try std.testing.expectEqual(@as(usize, 1), accepts);
    try std.testing.expectEqual(@as(i32, 0), keyboard(WM_KEYDOWN, 0x4A));
    try std.testing.expectEqual(@as(i32, 1), character(0x0A));
    alt_down = true;
    try std.testing.expectEqual(@as(i32, 0), keyboard(WM_KEYDOWN, 0x0D));
    alt_down = false;
    app_state.g_win_held = true;
    try std.testing.expectEqual(@as(i32, 0), keyboard(WM_KEYDOWN, 0x0D));
    app_state.g_win_held = false;
    chat_active = false;
    try std.testing.expectEqual(@as(i32, 0), keyboard(WM_KEYDOWN, 0x0D));
    chat_active = true;
    focus = 3;
    try std.testing.expectEqual(@as(i32, 0), keyboard(WM_KEYDOWN, 0x0D));
    focus = 2;
    foreground = 4;
    try std.testing.expectEqual(@as(i32, 0), keyboard(WM_KEYDOWN, 0x0D));
    try std.testing.expectEqual(@as(usize, 3), sends);
    try std.testing.expectEqual(@as(usize, 3), notes);
}
`;
    try {
      const file = path.join(directory, 'enter.zig');
      fs.writeFileSync(file, program);
      const result = spawnSync(process.env.ZIG || 'zig', ['test', file, '-fno-llvm', '-fno-lld'], { encoding: 'utf8', timeout: 30000 });
      assert.ifError(result.error);
      if (broken) {
        assert.notEqual(result.status, 0, 'Original composer must reject the regression');
        assert.match(result.stderr, /expected 1, found 0/);
        console.log('IGSH-911 RED_CONTROL_REJECTED: original Ctrl+Enter bypassed send');
      } else {
        assert.equal(result.status, 0, `${result.signal || ''}\n${result.stdout}${result.stderr}`);
      }
    } finally {
      fs.rmSync(directory, { recursive: true, force: true });
    }
  }
});
