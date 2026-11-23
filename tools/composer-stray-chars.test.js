const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.join(__dirname, '..');
const read = rel => fs.readFileSync(path.join(root, rel), 'utf8');

test('SOFT-2459 shell draft sync filters through composer input before toComposer', () => {
  const sync = read('src/chat_shell_sync.zig');
  assert.match(sync, /filter16\(stage\[0\.\.\], text, true\)/);
  assert.match(sync, /chat_composer_input\.zig/);
});

test('SOFT-2459 transcript draft parsing uses composer input filtering', () => {
  assert.match(read('src/chat_transcript.zig'), /chat_composer_input\.zig"\)\.filterUtf8To16/);
});

test('SOFT-2459 dictation live posts and paste insertions sanitize wide text', () => {
  assert.match(read('src/voice.zig'), /chat_composer_input\.zig"\)\.filter16\(&dictation_live_slot/);
  const composer = read('src/chat_composer.zig');
  assert.match(composer, /filter16\(&clean, clip\[0\.\.len\], true\)/);
  assert.match(composer, /chatComposerPasteFiltered\(\)/);
});

test('SOFT-2459 box draft capture strips stray escape sequences', () => {
  assert.match(read('src/chat_history_reader.py'), /return ANSI\.sub\("", draft\)/);
});

test('SOFT-2459 zig unit tests strip ESC, BOM and zero-width characters', () => {
  const zig = spawnSync(process.env.ZIG || 'zig', ['test', 'src/chat_composer_input.zig', '--test-filter', 'SOFT-2459'], {
    cwd: root,
    encoding: 'utf8',
    timeout: 120000,
  });
  if (zig.error && zig.error.code === 'ENOENT') return;
  assert.equal(zig.status, 0, zig.stderr || zig.stdout);
});