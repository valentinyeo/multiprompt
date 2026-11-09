const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');
const zig =
  process.env.ZIG ||
  process.env.ZIG_EXE ||
  (process.platform === 'win32' ? 'zig' : path.join(os.homedir(), '.local/zig-0.16.0/zig'));

const root = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const exists = file => fs.existsSync(path.join(root, file));

test('IGSH-1897 the expanded table opens centered, scrolls, and closes on Esc, the X or a click outside', () => {
  assert.ok(exists('src/chat_table_expand.zig'), 'expanded table model');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh1897-'));
  try {
    copyZig(['chat_table_expand.zig'], dir);
    const run = spawnSync(zig, ['test', 'chat_table_expand.zig', '-j1', '--cache-dir', path.join(dir, 'cache'), '--global-cache-dir', process.env.ZIG_GLOBAL_CACHE_DIR || path.join(dir, 'global-cache')], {
      cwd: dir, encoding: 'utf8', timeout: 180000, maxBuffer: 4 * 1024 * 1024,
    });
    assert.equal(run.status, 0, `${run.error || ''}\n${run.stdout}\n${run.stderr}`);
    assert.match(run.stderr, /All 5 tests passed/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('IGSH-1897 Ctrl+K "Chat View: Expand table" is listed in Chat View and opens the nearest table', () => {
  const words = read('src/ui_words.zon');
  assert.match(words, /\.palette_chat_expand_table = "Chat View: Expand table",/);
  assert.match(read('src/app_state.zig'), /pub const SEARCH_CHAT_EXPAND_TABLE_OFFSET: usize = \d+;/);
  const palette = read('src/command_palette.zig');
  assert.match(palette, /labelsMatchQuery\(&\[_\]\[\]const u8\{ @import\("ui_words\.zon"\)\.palette_chat_expand_table,[^}]*\}[^)]*\)\)\s*\{\s*app_state\.g_search_results\[app_state\.g_search_result_count\] = SEARCH_CHAT_EXPAND_TABLE_OFFSET;/);
  assert.match(read('src/sidebar.zig'), /is_chat_expand_table\) \{[^]*?L\(ui_words\.palette_chat_expand_table\)/);
  assert.match(read('src/main.zig'), /if \(target == SEARCH_CHAT_EXPAND_TABLE_OFFSET\) \{[^}]*chatExpandTableNearest\(\);\s*return 0;/);
  const render = read('src/chat_render.zig');
  assert.match(render, /pub fn chatExpandTableNearest\(\) void \{[^]*?chat_table_expand\.Nearest\{[^]*?nearest\.consider\(i, rc\.top, rc\.bottom\)[^]*?chatExpandTable\(index\);/);
});

test('IGSH-1897 each table shows an Expand button on hover and a click opens the overlay', () => {
  const render = read('src/chat_render.zig');
  const clicks = render.match(/if \(chatTableExpandAt\(GET_X\(lp\), GET_Y\(lp\)\)\) \|index\| \{\s*chatExpandTable\(index\);\s*return 0;\s*\}\s*if \(chatTableMouseDown/g) || [];
  assert.equal(clicks.length, 2, 'button clicks win over table scrollbar and selection');
  assert.match(render, /chatPaintTableExpand\(hdc, rc, block\);\s*return;/);
  assert.ok(exists('src/chat_table_overlay.zig'), 'overlay window');
  const overlay = read('src/chat_table_overlay.zig');
  assert.match(overlay, /w\.WM_LBUTTONDOWN => \{\s*if \(state\) \|s\| s\.apply\(hwnd, expand\.click\(s\.geometry, pointX\(lp\), pointY\(lp\)\)\);/);
  assert.match(overlay, /message\.message == w\.WM_KEYDOWN\) \{\s*state\.apply\(hwnd, expand\.key\(/);
  assert.match(overlay, /chatComposerFocusAllowed\(\)\) _ = focus\.SetFocus\(app_state\.g_chat_composer_hwnd\)/);
  assert.match(read('src/shortcuts.zig'), /chat_table_overlay\.zig"\)\.ownsForeground\(\)\) return CallNextHookEx/);
});
