const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');
const read = file => fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';

test('SOFT-1425 Generate is offered, painted and routed from the bot face palette', () => {
  const actions = read('src/bot_photo_actions.zig');
  assert.match(actions, /app\.SEARCH_BOT_PHOTO_GENERATE, words\.bot_photo_generate/);
  assert.match(read('src/command_palette.zig'), /bot_photo_actions\.zig"\)\.appendResults\(\)/);
  assert.match(read('src/sidebar.zig'), /bot_photo_actions\.zig"\)\.label\(result_idx\)/);
  assert.match(read('src/main.zig'), /bot_photo_actions\.zig"\)\.run\(hwnd, target\)/);
  assert.match(actions, /bot_picture\.zig"\)\.show\(hwnd, idx\)/);
});

test('SOFT-1425 the F1 and generated keyboard documentation describe Keep, Try again and Reset', async () => {
  const { parseShortcutRows, renderShortcutRows } = await import('./shortcuts-doc.mjs');
  const rows = parseShortcutRows(read('src/shortcuts.zig'));
  const row = rows.find(row => row.a === 'Ctrl+K -> Bot face -> Generate');
  assert.ok(row);
  for (const word of ['Keep', 'Try again', 'Reset']) assert.ok(row.b.includes(word));
  assert.ok(read('openwiki/operations/keyboard-shortcuts.md').includes(renderShortcutRows(rows)));
});

test('SOFT-1425 a paid picture preview is explicitly screen-only', async () => {
  const { screen, screenOnly } = await import('./palette-verbs.mjs');
  assert.equal(screen.SEARCH_BOT_PHOTO_GENERATE, 'picture');
  const reason = screenOnly.picture;
  assert.equal(reason, 'picture previews with Keep or Try again');
  assert.ok(read('CLAUDE.md').includes(reason));
  assert.ok(read('openwiki/operations/spawn-multibot-session.md').includes(reason));
});

test('SOFT-1425 the desktop uses its existing server channel and only Keep imports a preview', () => {
  const source = read('src/bot_picture.zig');
  assert.match(source, /transport\.open\(self\.host, false\)/);
  assert.match(source, /\.op = "bot_picture"/);
  assert.doesNotMatch(source, /OPENAI_API_KEY|api\.openai|Sleep\(|SetTimer\(/);
  const start = source.indexOf('fn start(');
  const accept = source.indexOf('fn accept(');
  assert.ok(start > 0 && accept > start);
  assert.doesNotMatch(source.slice(start, accept), /photo\.import/);
  assert.match(source.slice(accept, source.indexOf('fn load(')), /photo\.import\(self\.digest/);
  assert.match(source, /self\.discard\(\)/);
  assert.match(source, /s\.discard\(\)/);
  assert.match(source, /self\.deadline = w\.GetTickCount64\(\) \+ 25_000/);
  assert.match(source, /ownsForeground\(\) bool/);
  assert.match(read('src/shortcuts.zig'), /bot_picture\.zig"\)\.ownsForeground\(\)/);
});
