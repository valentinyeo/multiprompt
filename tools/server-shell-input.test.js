const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = rel => path.join(__dirname, '..', rel);
const read = name => fs.readFileSync(root(`src/${name}`), 'utf8');
const readMain = () => fs.readFileSync(root('src/main.zig'), 'utf8');

function body(source, signature) {
  const start = source.indexOf(signature);
  assert.notEqual(start, -1, `${signature} must exist`);
  const open = source.indexOf('{', start);
  let depth = 0;
  for (let i = open; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(open, i + 1);
  }
  assert.fail(`${signature} has no closing brace`);
}

test('SOFT-3048 native VPS shells send interrupt through the terminal channel', () => {
  const send = body(read('clipboard.zig'), 'pub fn sendCtrlCToShell(');
  assert.match(
    send,
    /native_terminal[\s\S]*interrupt\(/,
    'sendCtrlCToShell must not use AttachConsole when the tab has no conhost pid',
  );
});

test('SOFT-3048 the frame forwards mouse wheel to the native shell child', () => {
  const main = readMain();
  const wheel = body(main, 'WM_MOUSEWHEEL, WM_MOUSEHWHEEL =>');
  assert.match(
    wheel,
    /native_terminal[\s\S]*SendMessageW\(target, msg, wp, lp\)/,
    'wheel over the shell pane must reach MPTerminal scrollback',
  );
});

test('SOFT-3048 copying a native shell selection clears it so the next Ctrl+C interrupts', () => {
  const copy = body(fs.readFileSync(root('src/terminal_window.c'), 'utf8'), 'int mp_terminal_window_copy(HWND hwnd)');
  assert.match(copy, /if \(copied\)[\s\S]*?selected = t->selecting = 0/, 'a copied selection must not survive to turn the next Ctrl+C into another copy');
  assert.match(copy, /InvalidateRect\(hwnd, NULL, FALSE\)/, 'the cleared selection must repaint without the highlight');
});

test('SOFT-3048 copy-or-interrupt keeps using the shared clipboard path for native tabs', () => {
  const copy = body(read('clipboard.zig'), 'pub fn copyConsoleSelectionToClipboard(');
  assert.match(copy, /native_terminal[\s\S]*native_session\.zig.*copy/);
  const verify = fs.readFileSync(root('.claude/skills/verify-multiprompt/features/server-shell-input.md'), 'utf8');
  assert.match(verify, /server-shell-input/);
  assert.match(verify, /Driving it with control\.ps1/);
});

test('SOFT-3048 the journey proves copy, interrupt and wheel scrollback on the native child', () => {
  const journey = fs.readFileSync(root('.claude/skills/verify-multiprompt/server-shell-input.ps1'), 'utf8');
  assert.match(journey, /GetFocusedWindow\(\$script:window\) -eq \$shell/);
  assert.match(journey, /interrupt\.json/);
  assert.match(journey, /WheelClientPoint/);
  assert.match(journey, /afterIndex -ge \$beforeIndex/);
});
