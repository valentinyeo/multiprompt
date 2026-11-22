const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { readControlSource } = require('./app-source');

const root = path.resolve(__dirname, '..');
const read = file => (file.endsWith('control.ps1') ? readControlSource() : fs.readFileSync(path.join(root, file), 'utf8'));
const skill = '.claude/skills/verify-multiprompt/';

function featureMatrix(source) {
  assert.match(source, /fromJSON\(needs\.journeys\.outputs\.matrix\)/);
  return require('./verify-features.cjs').discoverFeatures();
}

function caretContract(source) {
  assert.match(source, /int caret_created/);
  assert.match(source, /t->caret_created = 0/);
  assert.match(source, /SetCaretPos\(/);
  assert.doesNotMatch(source, /DestroyCaret\(\);\s*if \(visible && CreateCaret/);
  assert.match(source, /void mp_terminal_window_repair_caret\(HWND hwnd\)/);
}

test('SOFT-3046 terminal caret avoids recreate on every move', () => {
  caretContract(read('src/terminal_window.c'));
  assert.match(read('src/terminal_window.h'), /mp_terminal_window_repair_caret/);
  assert.throws(() => caretContract(read('src/terminal_window.c').replace('int caret_created', '')));
});

test('SOFT-3046 native repair path and main activation hooks', () => {
  const sessionCaret = read('src/session_caret.zig');
  assert.match(sessionCaret, /pub fn repairActiveSessionCaret\(\) void/);
  assert.match(sessionCaret, /GetCaretBlinkTime\(\)/);
  assert.match(sessionCaret, /native_terminal.*mp_terminal_window_repair_caret/s);
  const main = read('src/main.zig');
  assert.match(main, /repairActiveSessionCaret\(\)/);
  assert.ok(main.indexOf('WM_ACTIVATEAPP =>') < main.indexOf('repairActiveSessionCaret()'));
  const refocus = main.slice(main.indexOf('} else if (wp == TIMER_REFOCUS)'), main.indexOf('} else if (wp == TIMER_HOOK_UNINSTALL)'));
  assert.match(refocus, /landed.*repairActiveSessionCaret/s);
});

test('SOFT-3046 journey registration and workflow contract', () => {
  const driver = read(skill + 'control.ps1');
  const workflow = read('.github/workflows/verify.yml');
  assert.match(driver, /ValidateSet\([^\n]*'session-caret'/);
  assert.match(driver, /'session-caret' \{/);
  const recipe = driver.slice(driver.indexOf("        'session-caret' {"), driver.indexOf("        'session-tabs' {"));
  assert.match(recipe, /GetGUIThreadInfo|CaretRect/);
  assert.match(recipe, /notepad/i);
  assert.match(recipe, /0x12, 0x43|Alt\+C/);
  assert.ok(featureMatrix(workflow).available.includes('session-caret'));
  assert.match(workflow, /run: node --test [^\n]*tools\/session-caret\.test\.js/);
  assert.ok(read(skill + 'features/session-caret.md').includes('GetGUIThreadInfo'));
});