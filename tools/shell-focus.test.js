const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const app = require('./app-source').readAppSource();

function body(source, name, next) {
  const start = source.indexOf(`fn ${name}(`);
  const end = source.indexOf(`fn ${next}(`, start + 1);
  assert.ok(start >= 0 && end > start, `${name} must precede ${next}`);
  return source.slice(start, end);
}

function audit(source) {
  const activate = body(source, 'activateConsoleForeground', 'pasteFocusLanded');
  const first = activate.indexOf('if (SetForegroundWindow(target) != 0 and GetForegroundWindow() == target) return 1;');
  const fallback = activate.indexOf('return SetForegroundWindow(GetAncestor(target, GA_ROOT));');
  assert.ok(first >= 0, 'the console window itself must be activated first');
  assert.ok(fallback > first, 'the app frame is only a fallback after the console refused');
  assert.match(activate, /if \(!g_igsh354_paste_focus\) return 0;/);
  const inner = body(source, 'focusActiveShellInner', 'activateConsoleForeground');
  assert.match(inner, /_ = activateConsoleForeground\(target_hwnd\);\s*_ = SetFocus\(target_hwnd\);/);
  assert.doesNotMatch(inner, /SetForegroundWindow\([^)]*GA_ROOT/);
  const shot = body(source, 'shotFocusTick', 'paintChatAttachButton');
  assert.match(shot, /const foreground_ok = if \(chat\) SetForegroundWindow\(g_main_hwnd\) else activateConsoleForeground\(target\);/);
}

test('leaving Chat View activates the console window so typing reaches the shell', () => {
  audit(app);
  const mutations = [
    ['_ = activateConsoleForeground(target_hwnd);', '_ = SetForegroundWindow(if (g_igsh354_paste_focus) GetAncestor(target_hwnd, GA_ROOT) else target_hwnd);'],
    ['if (SetForegroundWindow(target) != 0 and GetForegroundWindow() == target) return 1;', ''],
    ['if (!g_igsh354_paste_focus) return 0;', ''],
    ['else activateConsoleForeground(target);', 'else SetForegroundWindow(GetAncestor(target, GA_ROOT));'],
  ];
  for (const [before, after] of mutations) {
    assert.ok(app.includes(before), before);
    assert.throws(() => audit(app.replace(before, after)), `restoring ${before} must fail`);
  }
});

test('CI runs the shell focus regression through the full Zig test graph', () => {
  const build = fs.readFileSync(path.resolve(__dirname, '..', 'build.zig'), 'utf8');
  assert.match(build, /const shell_focus_tests = b.addSystemCommand\(&\.\{ "node", "--test", "tools\/shell-focus.test.js" \}\);\s*test_step.dependOn\(&shell_focus_tests.step\)/);
});
