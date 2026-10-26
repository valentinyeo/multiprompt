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

test('IGSH-911 composer CR and Ctrl+Enter LF send once; Shift+Enter and autocomplete stay native', () => {
  const os = require('node:os');
  const path = require('node:path');
  const { spawnSync } = require('node:child_process');
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
      const g_main_hwnd = 1;
  };
  const WPARAM = usize;
  const DWORD = u32;
  const WM_KEYDOWN = 0x0100;
  const WM_SYSKEYDOWN = 0x0104;
  ${composer.slice(composer.indexOf('pub fn chatComposerOwnsKey('), composer.indexOf('\n}', composer.indexOf('pub fn chatComposerOwnsKey(')) + 2)}
  const VK_MENU = 0x12;
  const WM_APP_CHAT_SEND = 123;
  const CHAT_AC_ENTER_SENDS = false;
  var ctrl_down = false;
  var shift_down = false;
  var sends: usize = 0;
  var notes: usize = 0;
  var accepts: usize = 0;
  fn isCtrlDown() bool { return ctrl_down; }
  fn GetAsyncKeyState(key: i32) i16 { return if (key == 0x10 and shift_down) -32768 else 0; }
  fn chatAcAccept() bool { accepts += 1; return true; }
  fn chatAcClose() void { app_state.g_chat_ac.open = false; }
  fn chatShellDraftNoteSend() void { notes += 1; }
  fn PostMessageW(_: usize, _: u32, _: usize, _: usize) i32 { sends += 1; return 1; }
  fn character(wp: usize) i32 {
      const msg = 0x0102;
  ${composer.slice(start, end)}
      return 1;
  }
  test "composer submit and newline behavior" {
      ctrl_down = true;
      try std.testing.expectEqual(@as(i32, 0), character(0x0A));
      try std.testing.expectEqual(@as(usize, 1), sends);
      try std.testing.expectEqual(@as(usize, 1), notes);
      ctrl_down = false;
      try std.testing.expectEqual(@as(i32, 0), character(0x0D));
      try std.testing.expectEqual(@as(usize, 2), sends);
      shift_down = true;
      try std.testing.expectEqual(@as(i32, 1), character(0x0D));
      ctrl_down = true;
      try std.testing.expectEqual(@as(i32, 1), character(0x0A));
      try std.testing.expectEqual(@as(usize, 2), sends);
      shift_down = false;
      ctrl_down = false;
      app_state.g_chat_ac.open = true;
      try std.testing.expectEqual(@as(i32, 0), character(0x0D));
      try std.testing.expectEqual(@as(usize, 1), accepts);
      try std.testing.expectEqual(@as(usize, 2), sends);
      ctrl_down = true;
      try std.testing.expectEqual(@as(i32, 0), character(0x0A));
      try std.testing.expectEqual(@as(usize, 3), sends);
      try std.testing.expectEqual(@as(usize, 1), accepts);
      try std.testing.expectEqual(@as(usize, 3), notes);
      ctrl_down = false;
      try std.testing.expectEqual(@as(i32, 0), character(0x0A));
      try std.testing.expectEqual(@as(usize, 4), sends);
      try std.testing.expectEqual(@as(i32, 1), character('x'));
      try std.testing.expectEqual(@as(usize, 4), sends);
      try std.testing.expect(chatComposerOwnsKey(WM_KEYDOWN, 0x0D, true, false, 0));
  }
  `;
    try {
      const file = path.join(directory, 'enter.zig');
      fs.writeFileSync(file, program);
      const result = spawnSync(process.env.ZIG || 'zig', ['test', file, '-fno-llvm', '-fno-lld'], { encoding: 'utf8', timeout: 30000 });
      assert.ifError(result.error);
      if (broken) {
        assert.notEqual(result.status, 0, 'Original composer must reject the regression');
        assert.match(result.stderr, /expected 0, found 1/);
        console.log('IGSH-911 RED_CONTROL_REJECTED: original Ctrl+Enter LF bypassed send');
      } else {
        assert.equal(result.status, 0, `${result.signal || ''}\n${result.stdout}${result.stderr}`);
      }
    } finally {
      fs.rmSync(directory, { recursive: true, force: true });
    }
  }
});
