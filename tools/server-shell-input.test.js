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
  assert.match(journey, /Snapshot 'after'/, 'the harness requires an after snapshot before it reports passed');
});

test('MUBO-209 paste leaves the window as one write with intact markers', () => {
  const paste = body(read('terminal_window.c'), 'void mp_terminal_window_paste(HWND hwnd)');
  assert.match(paste, /mp_terminal_paste_text\(/, 'the whole paste must leave as one terminal write');
  assert.doesNotMatch(paste, /character\(/, 'per character input turns the paste markers into typed keys');
  assert.doesNotMatch(paste, /mp_terminal_paste\(/, 'libvterm must not type the bracketed paste markers one call at a time');
  assert.match(paste, /"\\x1b\[200~"/, 'the start marker must carry its escape byte');
  assert.match(paste, /"\\x1b\[201~"/, 'the end marker must carry its escape byte');
  assert.match(paste, /memcpy\(payload \+ used/, 'the marker and the text must be copied into the same buffer');
});

test('MUBO-209 a single line paste stays plain text for the remote shell', () => {
  const paste = body(read('terminal_window.c'), 'void mp_terminal_window_paste(HWND hwnd)');
  assert.match(
    paste,
    /mp_terminal_bracketed_paste\(t->model\) && paste_has_line_break\(text, count\)/,
    'markers may only go to a remote that enabled bracketed paste, and only for a multi line paste',
  );
  const hasBreak = body(read('terminal_window.c'), 'static int paste_has_line_break(');
  assert.match(hasBreak, /L'\\r' \|\| text\[i\] == L'\\n'/, 'a line break decides the marker path');
});

test('MUBO-209 paste after Escape completes the meta prefix instead of losing the command', () => {
  const paste = body(read('terminal_window.c'), 'void mp_terminal_window_paste(HWND hwnd)');
  assert.match(paste, /if \(t->escape_pending\) payload\[used\+\+\] = 0x1b/, 'a bare Escape leaves readline mid sequence, so the paste must spend one escape byte');
  assert.match(paste, /t->escape_pending = 0/, 'the paste consumes the pending escape');
  const keys = body(read('terminal_window.c'), 'case WM_KEYDOWN: case WM_SYSKEYDOWN: {');
  assert.match(keys, /t->escape_pending = k == VTERM_KEY_ESCAPE/, 'only the Escape key arms the pending escape');
  const input = body(read('terminal_window.c'), 'static void input(TerminalWindow *t, uint32_t value, int mod)');
  assert.match(input, /t->escape_pending = 0/, 'any other typed input disarms it');
});

test('MUBO-209 the terminal model writes paste bytes straight to the shell transport', () => {
  const write = body(read('terminal_model.c'), 'void mp_terminal_paste_text(');
  assert.match(write, /t->output\(bytes, length, t->user\)/, 'the paste buffer must reach the transport in one call');
  const flag = body(read('terminal_model.c'), 'int mp_terminal_bracketed_paste(');
  assert.match(flag, /vterm_get_bracketpaste\(/, 'the marker decision reads the mode the remote shell enabled');
});

test('MUBO-209 a tmux attach tab keeps scrollback so the wheel moves', () => {
  const premove = body(fs.readFileSync(root('src/terminal/vendor/libvterm/src/screen.c'), 'utf8'), 'static int premove(');
  assert.doesNotMatch(premove, /BUFIDX_PRIMARY/, 'tmux attach draws on the alternate screen, so scrollback must record it too');
  const history = body(read('terminal_model.c'), 'int mp_terminal_history(');
  assert.doesNotMatch(history, /alternate/, 'the alternate screen history must count for the wheel');
  const cell = body(read('terminal_model.c'), 'int mp_terminal_cell(');
  assert.doesNotMatch(cell, /alternate\) scroll = 0/, 'the wheel must scroll the alternate screen history too');
});

function auditClipboardChords(chars) {
  assert.match(chars, /int plain = !shift && \(mod & \(VTERM_MOD_CTRL \| VTERM_MOD_ALT\)\) == VTERM_MOD_CTRL;/, 'the chords are Ctrl without Shift and without Alt, so AltGr keeps typing');
  const paste = chars.indexOf('if (plain && wp == 22) { mp_terminal_window_paste(hwnd); return 0; }');
  const copy = chars.indexOf('if (plain && wp == 3 && t->selected) { mp_terminal_window_copy(hwnd); return 0; }');
  const typed = chars.indexOf('character(t, (WCHAR)wp, mod)');
  assert.ok(typed >= 0, 'every other character still reaches the shell');
  assert.ok(paste >= 0, 'plain Ctrl+V must paste instead of typing ^V');
  assert.ok(copy >= 0, 'plain Ctrl+C with a selection must copy it');
  assert.ok(typed > paste && typed > copy, 'a copied or pasted chord must return before any byte reaches the shell');
}

test('MUBO-225 plain Ctrl+C copies a selection and plain Ctrl+V pastes in a shell or tmux tab', () => {
  const source = read('terminal_window.c');
  const chars = body(source, 'case WM_CHAR: case WM_SYSCHAR: {');
  auditClipboardChords(chars);
  const mutations = [
    ['if (plain && wp == 3 && t->selected) { mp_terminal_window_copy(hwnd); return 0; }', 'if (plain && wp == 3) { mp_terminal_window_copy(hwnd); return 0; }'],
    ['if (plain && wp == 22) { mp_terminal_window_paste(hwnd); return 0; }', ''],
    ['int plain = !shift && (mod & (VTERM_MOD_CTRL | VTERM_MOD_ALT)) == VTERM_MOD_CTRL;', 'int plain = (mod & VTERM_MOD_CTRL) == VTERM_MOD_CTRL;'],
  ];
  for (const [before, after] of mutations) {
    assert.ok(source.includes(before), before);
    assert.throws(
      () => auditClipboardChords(body(source.replace(before, after), 'case WM_CHAR: case WM_SYSCHAR: {')),
      `mutation must fail: ${before}`,
    );
  }
});

test('MUBO-225 Ctrl+Shift+C and Ctrl+Shift+V keep their own handler', () => {
  const keys = body(read('terminal_window.c'), 'case WM_KEYDOWN: case WM_SYSKEYDOWN: {');
  assert.match(keys, /\(mod & \(VTERM_MOD_CTRL \| VTERM_MOD_SHIFT\)\) == \(VTERM_MOD_CTRL \| VTERM_MOD_SHIFT\) && \(wp == 'C' \|\| wp == 'V'\)/);
  assert.match(keys, /if \(wp == 'C'\) mp_terminal_window_copy\(hwnd\); else mp_terminal_window_paste\(hwnd\);/);
  const chars = body(read('terminal_window.c'), 'case WM_CHAR: case WM_SYSCHAR: {');
  assert.match(chars, /if \(shift && \(mod & VTERM_MOD_CTRL\) && \(wp == 3 \|\| wp == 22\)\) return 0;/, 'the character left behind by Ctrl+Shift must not reach the shell');
});
