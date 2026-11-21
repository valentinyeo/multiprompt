const assert = require('node:assert/strict');
const test = require('node:test');

const readAppSource = require('./app-source').readAppSource;
const main = readAppSource();
const shortcuts = require('fs').readFileSync(require('path').join(__dirname, '..', 'src', 'shortcuts.zig'), 'utf8');
const win32 = require('fs').readFileSync(require('path').join(__dirname, '..', 'src', 'win32.zig'), 'utf8');
const terminal = require('fs').readFileSync(require('path').join(__dirname, '..', 'src', 'terminal_window.c'), 'utf8');

const hook = shortcuts.slice(shortcuts.indexOf('fn keyboardHookProc('), shortcuts.indexOf('\nfn pointOverActiveShell'));

test('SOFT-3008 shell focus blocks SC_KEYMENU on the owner frame', () => {
  assert.match(win32, /pub const SC_KEYMENU: usize = 0xF100;/);
  function contract(source) {
    assert.match(source, /WM_SYSCOMMAND => \{\s*if \(\(wp & 0xFFF0\) == @import\("win32.zig"\)\.SC_MAXIMIZE and activeBrowserHasForegroundFocus\(\)\) return 0;\s*if \(\(wp & 0xFFF0\) == @import\("win32.zig"\)\.SC_KEYMENU and activeShellHasForegroundFocus\(\)\) return 0;\s*return DefWindowProcW\(hwnd, msg, wp, lp\);\s*\}/);
  }
  contract(main);
  for (const [label, broke] of [
    ['SC_KEYMENU guard', main.replaceAll('SC_KEYMENU', '')],
    ['shell focus check', main.replaceAll('activeShellHasForegroundFocus()', '')],
  ]) {
    assert.throws(() => contract(broke), label);
  }
});

test('SOFT-3008 Enter and Alt+Space in a hosted shell never arm the title-bar system menu', () => {
  const guard = hook.match(
    /if \(activeShellHasForegroundFocus\(\) and !isCtrlDown\(\) and wp == WM_SYSKEYDOWN and \(kb\.vkCode == 0x0D or kb\.vkCode == 0x20\)\) \{\s*app_state\.g_sysmenu_pending = false;\s*return CallNextHookEx\(app_state\.g_hook, nCode, wp, lp\);\s*\}/,
  );
  assert.ok(guard, 'shell sysmenu guard must passthrough Enter and Space before Alt+Space arms the menu');
  const arm = hook.indexOf('if (wp == WM_SYSKEYDOWN and kb.vkCode == 0x20 and !isCtrlDown() and foregroundIsOurs())');
  assert.ok(arm > guard.index, 'Alt+Space menu arm must stay after the shell passthrough guard');
  assert.match(
    hook,
    /if \(\(wp == WM_KEYUP or wp == WM_SYSKEYUP\) and app_state\.g_sysmenu_pending\) \{\s*if \(activeShellHasForegroundFocus\(\)\) \{\s*app_state\.g_sysmenu_pending = false;\s*return 1;\s*\}/,
    'pending Alt+Space must not open the owner menu while the shell still owns focus',
  );
});

test('SOFT-3008 native terminal windows ignore SC_KEYMENU locally', () => {
  assert.match(terminal, /case WM_SYSCOMMAND:\s*if \(\(wp & 0xfff0\) == 0xf100\) return 0;/);
});