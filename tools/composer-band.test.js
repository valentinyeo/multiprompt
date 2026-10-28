const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('IGSH-805 composer band buffered paint fills the full client background before native print', () => {
  const composer = read('src/chat_composer.zig');
  const buffered = composer.slice(composer.indexOf('fn chatComposerPaintBuffered('), composer.indexOf('fn chatComposerSubclassCore('));
  const backgroundFill = /    const background = CreateSolidBrush\(app_state\.g_chat_input_color\) orelse return false;\s*defer _ = DeleteObject\(background\);\s*if \(FillRect\(dc, &client, background\) == 0\) return false;\n/;
  const fullClientPaint = /GetClientRect\(hwnd, &client\)[\s\S]*?SelectObject\(dc, bitmap\);\s*defer _ = SelectObject\(dc, old_bitmap\);\s*const background = CreateSolidBrush\(app_state\.g_chat_input_color\) orelse return false;\s*defer _ = DeleteObject\(background\);\s*if \(FillRect\(dc, &client, background\) == 0\) return false;\s*_ = CallWindowProcW\(app_state\.g_chat_composer_orig_proc, hwnd, 0x0318, @intFromPtr\(dc\), 4\);/;
  assert.match(buffered, fullClientPaint);
  const broken = buffered.replace(backgroundFill, '');
  assert.notEqual(broken, buffered);
  assert.throws(() => assert.match(broken, fullClientPaint), assert.AssertionError);
});

test('repeated chat layout preserves composer font without redundant edit redraws', () => {
  const os = require('node:os');
  const { spawnSync } = require('node:child_process');
  const composer = require('./app-source').readAppSource();
  const start = composer.indexOf('fn layoutChatControls()');
  const end = composer.indexOf('    const base_h = chatComposerBaseEditH();', start);
  assert.ok(start >= 0 && end > start);
  const production = composer.slice(start, end) + '    _ = &layout;\n}\n';
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'composer-font-layout-'));
  try {
    fs.writeFileSync(path.join(dir, 'test.zig'), `
const std = @import("std");
var g_chat_active = true;
var g_chat_composer_hwnd: ?usize = 1;
var g_chat_layout_browser_reserved = false;
var current_font: usize = 0;
var desired_font: usize = 42;
var redraws: usize = 0;
fn browserSlotReserved() bool { return false; }
fn chatViewLayout() u8 { return 0; }
fn ensureChatFont() ?*anyopaque { return @ptrFromInt(desired_font); }
fn SendMessageW(_: ?usize, msg: u32, wp: usize, _: isize) isize {
    if (msg == 0x0031) return @bitCast(current_font);
    if (msg == 0x0030) {
        current_font = wp;
        redraws += 1;
    }
    return 0;
}
${production}
test "font changes redraw once; repeated session layouts retain text and font" {
    layoutChatControls();
    try std.testing.expectEqual(@as(usize, 42), current_font);
    try std.testing.expectEqual(@as(usize, 1), redraws);
    for (0..80) |_| layoutChatControls();
    try std.testing.expectEqual(@as(usize, 1), redraws);
    desired_font = 43;
    layoutChatControls();
    try std.testing.expectEqual(@as(usize, 43), current_font);
    try std.testing.expectEqual(@as(usize, 2), redraws);
    g_chat_active = false;
    desired_font = 44;
    layoutChatControls();
    try std.testing.expectEqual(@as(usize, 43), current_font);
    try std.testing.expectEqual(@as(usize, 2), redraws);
}
`);
    const result = spawnSync('zig', ['test', path.join(dir, 'test.zig')], { encoding: 'utf8', timeout: 60000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
