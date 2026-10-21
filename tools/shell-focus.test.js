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

function auditWorkspaceFocusJourney(source) {
  const reader = source.slice(source.indexOf('public static string EditText('), source.indexOf('public static string Title('));
  assert.match(reader, /Class\(hwnd\) != "Edit"/);
  assert.match(reader, /SendMessageTimeout\(hwnd, 0x000D, new UIntPtr\(\(uint\)text.Capacity\), text, 2, 1000, out length\) == IntPtr.Zero\) throw/);
  assert.match(reader, /length.ToUInt64\(\) >= \(ulong\)\(text.Capacity - 1\)\) throw/);
  assert.match(reader, /return text.ToString\(\);/);
  assert.doesNotMatch(reader, /GetWindowText\(|SetFocus\(|SetForegroundWindow\(/);
  const journey = source.slice(source.indexOf("        'workspace-focus' {"), source.indexOf("        'inbox' {"));
  assert.doesNotMatch(journey, /ValuePattern|GetCurrentPattern/);
  for (const expected of ["'before-'", '$expectedText', "($expectedText + '-pill')"]) {
    assert.ok(journey.includes(`[VerifyNative]::EditText([IntPtr]$composerHandle) -ceq ${expected}`), `exact composer text: ${expected}`);
  }
  assert.match(journey, /\$expectedText = 'before-workspace-focus-chat'/);
  assert.match(journey, /\$focused.Current.NativeWindowHandle -ne \$composerHandle/);
  assert.match(journey, /\$chatState.active_tab -ne \$initialTab -or \$chatState.workspaces\[0\].focus -ne 'chat'/);
  const keyboardReturn = journey.slice(journey.indexOf("Press @(0x11, 0x4E) 'Ctrl+N:"), journey.indexOf("Snapshot 'chat-returned'"));
  assert.match(keyboardReturn, /Type-Text 'workspace-focus-chat'/);
  assert.doesNotMatch(keyboardReturn, /SetFocus|SetForegroundWindow|ShowWindow|Click/);
}

test('workspace focus journey reads cross-process Edit text with a bounded read-only message and keeps no-click assertions', () => {
  const source = fs.readFileSync(path.resolve(__dirname, '..', '.claude/skills/verify-multiprompt/control.ps1'), 'utf8');
  auditWorkspaceFocusJourney(source);
  for (const [before, after] of [
    ['SendMessageTimeout(hwnd, 0x000D,', 'GetWindowText(hwnd,'],
    ['text, 2, 1000, out length', 'text, 8, 1000, out length'],
    ["[VerifyNative]::EditText([IntPtr]$composerHandle) -ceq $expectedText", '$true'],
    ["Type-Text 'workspace-focus-chat'", "[void][VerifyNative]::SetForegroundWindow($script:window)\n            Type-Text 'workspace-focus-chat'"],
  ]) {
    assert.ok(source.includes(before), before);
    assert.throws(() => auditWorkspaceFocusJourney(source.replace(before, after)), `mutation must fail: ${before}`);
  }
});
