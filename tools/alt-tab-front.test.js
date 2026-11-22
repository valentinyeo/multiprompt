const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const focus = fs.readFileSync(path.join(root, 'src/focus.zig'), 'utf8');
const appMain = fs.readFileSync(path.join(root, 'src/main.zig'), 'utf8');

function between(text, start, end) {
  const from = text.indexOf(start);
  const to = text.indexOf(end, from + start.length);
  assert.ok(from >= 0 && to > from, `${start} must precede ${end}`);
  return text.slice(from, to);
}

function functionSlice(text, signature) {
  const start = text.indexOf(signature);
  assert.ok(start >= 0, `${signature} must exist`);
  let depth = 0;
  for (let i = text.indexOf('{', start); i < text.length; i += 1) {
    if (text[i] === '{') depth += 1;
    else if (text[i] === '}') {
      depth -= 1;
      if (depth === 0) return text.slice(start, i + 1);
    }
  }
  throw new Error(`unbalanced ${signature}`);
}

function raisePredicate(text) {
  const zig = functionSlice(text, 'fn activationRaiseAllows(');
  const inner = zig.slice(zig.indexOf('{') + 1, zig.lastIndexOf('}'))
    .replace(/\band\b/g, '&&')
    .replace(/\bor\b/g, '||');
  return new Function('now', 'until', 'target', 'raise_hwnd', inner);
}

function auditActivationPath(text, raiseSource) {
  const activation = between(text, 'WM_ACTIVATEAPP => {', '0x0006 => {');
  const activate = between(text, '0x0006 => {', 'WM_SETFOCUS => {');
  for (const handler of [activation, activate]) {
    const raise = handler.indexOf('frontOnActivation()');
    assert.ok(raise >= 0, 'both activation handlers raise the frame');
    const composer = handler.indexOf('focusGuardComposerRepairAllowed()');
    if (composer >= 0) assert.ok(raise < composer, 'the frame is in front before composer focus is repaired');
    const refocus = handler.indexOf('requestShellRefocus(');
    if (refocus >= 0) assert.ok(raise < refocus, 'the frame is in front before the shell refocus timer is armed');
  }
  assert.match(activate, /frontOnActivation\(\);\s*focusGuardNoteActivation\(\);/, 'the activation grace starts with the raise');
  assert.doesNotMatch(activate, /SetForegroundWindow\(app_state\.g_main_hwnd\)/, 'the raise lives in one place');
}

function auditRaiseFunction(text) {
  const raise = functionSlice(text, 'pub fn frontOnActivation() void {');
  assert.match(raise, /const main = app_state\.g_main_hwnd orelse return;/, 'there is a frame to raise');
  assert.match(raise, /if \(IsIconic\(main\) != 0\) return;/, 'Windows restores a minimized frame');
  assert.match(raise, /if \(@import\("computer_pane\.zig"\)\.controlling\(\)\) return;/, 'the computer pane owns input');
  assert.match(raise, /if \(@import\("settings_panel\.zig"\)\.isOpen\(\)\) return;/, 'the settings modal owns focus');
  const owned = raise.indexOf('if (!foregroundHwndIsOurs(fg)) {');
  const take = raise.indexOf('_ = SetForegroundWindow(main);');
  assert.ok(owned >= 0 && take > owned, 'a frame, pane or popup we already own keeps the foreground');
  assert.match(raise, /const attached_fg = [^;]*FocusNative\.AttachThreadInput\(our_thread, fg_thread, 1\) != 0;/, 'attach to the foreign foreground thread first');
  const detach = raise.indexOf('if (attached_fg) _ = FocusNative.AttachThreadInput(our_thread, fg_thread, 0);');
  assert.ok(detach > take, 'detach after the foreground attempt');
  assert.match(raise, /if \(GetForegroundWindow\(\) != main\) SwitchToThisWindow\(main, 0\);/, 'fall back to the taskbar-click switch');
  assert.match(raise, /_ = FocusNative\.SetWindowPos\(main, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE \| SWP_NOSIZE \| SWP_NOACTIVATE\);/, 'raise the frame group without taking focus');
  assert.match(raise, /g_focus_activation_raise_hwnd = main;/, 'remember what the raise may activate');
  assert.match(raise, /g_focus_activation_raise_until = GetTickCount64\(\) \+ app_state\.ACTIVATION_RAISE_MS;/, 'bound the raise authority');
  assert.match(raise, /g_focus_activation_raise_hwnd = null;/, 'clear the raise authority');
  const guard = functionSlice(text, 'fn focusGuardAt(');
  const raised = guard.indexOf('activationRaiseAllows(GetTickCount64(), app_state.g_focus_activation_raise_until, target, app_state.g_focus_activation_raise_hwnd)');
  const policy = guard.indexOf('focusGuardPolicy(');
  assert.ok(raised >= 0, 'the guard consults the activation raise');
  assert.ok(policy > raised, 'the activation raise is decided before the general foreground policy');
}

function auditRaiseAuthority(text) {
  const allows = raisePredicate(text);
  assert.equal(allows(100, 1100, 'frame', 'frame'), true);
  assert.equal(allows(100, 1100, 'pane', 'frame'), false);
  assert.equal(allows(100, 1100, null, 'frame'), false);
  assert.equal(allows(100, 1100, 'frame', null), false);
  assert.equal(allows(1200, 1100, 'frame', 'frame'), false);
}

test('Alt+Tab activation raises the frame before focus is restored to the session', () => {
  auditActivationPath(appMain, focus);
  const withoutActivate = appMain.replace('                @import("focus.zig").frontOnActivation();\n                focusGuardNoteActivation();\n                exitDeepIdleNow(hwnd);', '                focusGuardNoteActivation();\n                exitDeepIdleNow(hwnd);');
  assert.notEqual(withoutActivate, appMain);
  assert.throws(() => auditActivationPath(withoutActivate, focus), 'a WM_ACTIVATE that never raises the frame must fail');
  const withoutApp = appMain.replace('            } else {\n                @import("focus.zig").frontOnActivation();\n                focusGuardNoteActivation();', '            } else {\n                focusGuardNoteActivation();');
  assert.notEqual(withoutApp, appMain);
  assert.throws(() => auditActivationPath(withoutApp, focus), 'a WM_ACTIVATEAPP that never raises the frame must fail');
});

test('the front frame is taken back from a foreign window and never from our own pane', () => {
  auditRaiseFunction(focus);
  const mutations = [
    ['if (IsIconic(main) != 0) return;', ''],
    ['if (@import("settings_panel.zig").isOpen()) return;', ''],
    ['if (!foregroundHwndIsOurs(fg)) {', 'if (fg != null) {'],
    ['if (attached_fg) _ = FocusNative.AttachThreadInput(our_thread, fg_thread, 0);', ''],
    ['if (GetForegroundWindow() != main) SwitchToThisWindow(main, 0);', ''],
    ['_ = FocusNative.SetWindowPos(main, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);', ''],
    ['g_focus_activation_raise_hwnd = null;', ''],
  ];
  for (const [before, after] of mutations) {
    assert.ok(focus.includes(before), before);
    const changed = focus.replace(before, after);
    assert.throws(() => auditRaiseFunction(changed), `removing ${before} must fail the activation raise contract`);
  }
  const withoutConsult = focus.replace('    if (activationRaiseAllows(GetTickCount64(), app_state.g_focus_activation_raise_until, target, app_state.g_focus_activation_raise_hwnd)) {\n        focusTrace(.activation_raise, target, caller);\n        return true;\n    }\n', '');
  assert.notEqual(withoutConsult, focus);
  assert.throws(() => auditRaiseFunction(withoutConsult), 'a guard that ignores the activation raise must fail');
});

test('the activation raise authorizes only the frame, only during the activation window', () => {
  auditRaiseAuthority(focus);
  assert.throws(() => auditRaiseAuthority(focus.replace('target == raise_hwnd and', 'target != null and')), 'authorizing any target must fail');
  assert.throws(() => auditRaiseAuthority(focus.replace('now <= until', 'true')), 'an unbounded authority must fail');
  assert.throws(() => auditRaiseAuthority(focus.replace('return target != null and raise_hwnd != null and target == raise_hwnd and now <= until;', 'return now <= until;')), 'an authority that ignores the target must fail');
});
