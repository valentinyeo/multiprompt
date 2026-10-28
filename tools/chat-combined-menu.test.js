const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const render = fs.readFileSync(path.join(root, 'src/chat_render.zig'), 'utf8');

test('assistant message entry points share a below-message menu with stable request identity', () => {
  assert.match(render, /chat_message_menu\.zig/);
  assert.match(render, /chatHoverActionAt\(GET_X\(lp\), GET_Y\(lp\)\)/);
  assert.match(render, /chatMessageMenu\(hwnd, msg, wp, lp, action\.index\)/);
  assert.match(render, /entry\.history\.requestId\(std\.heap\.page_allocator, reaction_reference\)/);
  assert.match(render, /11 => if \(request_id\.len > 0\) chatCopyTextToClipboard\(request_id\)/);
  const menu = fs.readFileSync(path.join(root, 'src/chat_message_menu.zig'), 'utf8');
  assert.match(menu, /copy_request_id = 11/);
  assert.match(render, /run\.last\]\.bottom - app_state\.g_chat_scroll_y \+ uiScaled\(6\)/);
  assert.match(render, /bubble_rc\.bottom \+= reaction_height/);
  if (!process.env.ZIG) return;
  const start = menu.indexOf('pub const Action');
  const end = menu.indexOf('\nconst State');
  assert.ok(start >= 0 && end > start);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'reaction-menu-'));
  try {
    fs.writeFileSync(path.join(dir, 'test.zig'), 'const std = @import("std");\n' + menu.slice(start, end) + `
      test "one horizontal emoji row and three independent menu actions" {
          try std.testing.expectEqual(Action.like, actionAt(20, 20).?);
          try std.testing.expectEqual(Action.dislike, actionAt(65, 20).?);
          try std.testing.expectEqual(Action.heart, actionAt(110, 20).?);
          try std.testing.expectEqual(Action.reply, actionAt(100, 65).?);
          try std.testing.expectEqual(Action.copy, actionAt(100, 100).?);
          try std.testing.expectEqual(Action.copy_request_id, actionAt(100, 140).?);
          for ([_][2]i32{ .{0, 0}, .{-1, 20}, .{232, 80}, .{200, 20}, .{49, 20}, .{20, 50}, .{20, 154} }) |point| {
              try std.testing.expectEqual(@as(?Action, null), actionAt(point[0], point[1]));
          }
      }
    `);
    const result = spawnSync(process.env.ZIG, ['test', '-j1', path.join(dir, 'test.zig')], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All 1 tests passed/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
