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

function paletteHandoff(main) {
  const open = main.slice(main.indexOf('        WM_APP_SEARCH_OPEN => {'), main.indexOf('        WM_APP_SEARCH_CLOSE => {'));
  const handoff = open.match(/            if \(wp == 1 and foregroundIsOurs\(\) and focusGuard\(hwnd\)\) \{[^]*?\n            \}/)?.[0];
  assert.ok(handoff, 'authorize the frame before AttachThreadInput can reuse console authorization');
  const active = open.indexOf('app_state.g_search_active = true;');
  assert.ok(active >= 0 && active < open.indexOf(handoff), 'activation callbacks must see the palette as active');
  assert.ok(open.indexOf(handoff) < open.indexOf('hideShellsForOverlay();'), 'park the frame before hiding a foreground console or browser');
  assert.match(open, /hideShellsForOverlay\(\);[^]*_ = SetFocus\(app_state.g_main_hwnd\);/);
  return handoff;
}

test('palette handoff authorizes the frame and blocks reentrant shell repair before overlay setup', () => {
  const main = fs.readFileSync(path.resolve(__dirname, '..', 'src/main.zig'), 'utf8').replaceAll('\r\n', '\n');
  const handoff = paletteHandoff(main);
  for (const broken of [
    main.replace(' and focusGuard(hwnd)', ''),
    main.replace(handoff, '').replace('        WM_APP_SEARCH_OPEN => {', `        WM_APP_SEARCH_OPEN => {\n${handoff}`),
    main.replace(handoff, '').replace('            altqLog("palette_focus', `${handoff}\n            altqLog("palette_focus`),
  ]) assert.throws(() => paletteHandoff(broken));
  const run = new Function('wp', 'hwnd', 'app_state', 'foregroundIsOurs', 'focusGuard', 'cancelShellRefocus', 'GetForegroundWindow', 'GetCurrentThreadId', 'GetWindowThreadProcessId', 'AttachThreadInput', 'SetForegroundWindow', 'SetFocus', handoff.replaceAll(' and ', ' && ').replaceAll('_ = ', ''));
  for (const previous of ['console', 'browser', 'frame', 'foreign']) {
    for (const allowed of [false, true]) {
      const state = { g_search_active: true, g_browser_focus_mode: true };
      const calls = [];
      let authorized = 'console';
      let foreground = previous;
      let focused = previous;
      run(1, 'frame', state, () => previous !== 'foreign', target => {
        if (allowed) authorized = target;
        return allowed;
      }, () => calls.push('cancel'), () => foreground, () => 1, target => target === 'frame' ? 1 : 2,
      (from, to, attach) => {
        assert.equal(authorized, 'frame');
        calls.push(attach ? 'attach' : 'detach');
        return 1;
      }, target => {
        assert.equal(state.g_search_active, true);
        foreground = target;
        calls.push('foreground');
      }, target => { focused = target; calls.push('focus'); });
      if (allowed && previous !== 'foreign') {
        assert.equal(foreground, 'frame');
        assert.equal(focused, 'frame');
        assert.equal(state.g_browser_focus_mode, false);
        assert.deepEqual(calls, previous === 'frame' ? ['cancel', 'foreground', 'focus'] : ['cancel', 'attach', 'foreground', 'focus', 'detach']);
      } else assert.deepEqual(calls, []);
    }
  }
});

function auditOverlayHide(source) {
  const hide = body(source, 'hideShellsForOverlay', 'showActiveShellAfterOverlay');
  for (const target of ['app_state.shells[i].hwnd', 'app_state.g_chat_status_hwnd', 'app_state.g_chat_transcript_hwnd', 'app_state.g_chat_composer_hwnd']) {
    assert.ok(hide.includes(`SetWindowPos(${target}, null, 0, 0, 0, 0, SWP_HIDEWINDOW | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE)`), `${target} must hide without selecting another active window`);
  }
  assert.doesNotMatch(hide, /ShowWindow\(/);
  assert.match(source, /const SetWindowPos = @import\("focus.zig"\).SetWindowPos;/);
}

test('overlay hides cannot reactivate the console after palette frame handoff', () => {
  const source = fs.readFileSync(path.resolve(__dirname, '..', 'src/rename.zig'), 'utf8');
  auditOverlayHide(source);
  for (const flag of ['SWP_HIDEWINDOW', 'SWP_NOMOVE', 'SWP_NOSIZE', 'SWP_NOZORDER', 'SWP_NOACTIVATE']) {
    assert.throws(() => auditOverlayHide(source.replaceAll(flag, '0')));
  }
  assert.throws(() => auditOverlayHide(source.replace('SetWindowPos(app_state.shells[i].hwnd, null, 0, 0, 0, 0, SWP_HIDEWINDOW | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE)', 'ShowWindow(app_state.shells[i].hwnd, SW_HIDE)')));
});
