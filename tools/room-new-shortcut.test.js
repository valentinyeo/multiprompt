const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const sourceDir = path.join(__dirname, '..', 'src');
const read = (file) => fs.readFileSync(path.join(sourceDir, file), 'utf8');

function body(source, signature) {
  const start = source.indexOf(signature);
  assert.ok(start >= 0, `production code ${signature}`);
  const end = source.indexOf('\n}', start);
  assert.ok(end > start, `end of ${signature}`);
  return source.slice(start, end + 2);
}

test('Ctrl+Shift+N opens the new room form from anywhere', () => {
  const win32 = read('win32.zig');
  const declared = win32.match(/pub const WM_APP_NEW_ROOM: u32 = WM_APP \+ (\d+);/);
  assert.ok(declared, 'win32.zig declares WM_APP_NEW_ROOM');

  const used = new Map();
  for (const file of fs.readdirSync(sourceDir).filter((name) => name.endsWith('.zig'))) {
    for (const match of read(file).matchAll(/pub const (\w+): u32 = WM_APP \+ (\d+);/g)) {
      const list = used.get(match[2]) || [];
      list.push(match[1]);
      used.set(match[2], list);
    }
  }
  assert.deepEqual(used.get(declared[1]), ['WM_APP_NEW_ROOM'], 'message number is not shared with another message');

  const shortcuts = read('shortcuts.zig');
  assert.match(
    shortcuts,
    /if \(shift and kb\.vkCode == 0x4E\) \{\s*if \(@import\("room_frontend\.zig"\)\.enabled\) \{\s*_ = PostMessageW\(app_state\.g_main_hwnd, WM_APP_NEW_ROOM, 0, 0\);\s*return 1;/,
    'keyboard hook posts WM_APP_NEW_ROOM for Ctrl+Shift+N when rooms are enabled'
  );
  assert.match(shortcuts, /\.a = "Ctrl\+Shift\+N", \.b = "Create a Room"/, 'SHORTCUT_ROWS lists the key');

  const main = read('main.zig');
  const handler = main.match(/WM_APP_NEW_ROOM => \{([\s\S]*?)\n        \},/);
  assert.ok(handler, 'main window handles WM_APP_NEW_ROOM');
  assert.match(handler[1], /openNewRoom\(hwnd\);/, 'handler opens the room form');

  const palette = main.match(/target == @import\("room_frontend\.zig"\)\.new_room_target\) \{([\s\S]*?)\n                \}/);
  assert.ok(palette, 'palette handles the New room row');
  assert.match(palette[1], /openNewRoom\(hwnd\);/, 'palette row shares the same opener');

  const opener = body(main, 'fn openNewRoom(hwnd: HANDLE) void {');
  assert.match(opener, /app_state\.g_search_active = false;/);
  assert.match(opener, /room_frontend\.zig"\)\.openCreate\(\);/);
});
