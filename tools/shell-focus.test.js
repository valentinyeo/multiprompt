const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const app = require('./app-source').readAppSource();

function body(source, name, next) {
  const start = source.indexOf(`fn ${name}(`);
  const end = source.indexOf(`fn ${next}(`, start + 1);
  assert.ok(start >= 0 && end > start, `${name} must precede ${next}`);
  return source.slice(start, end);
}

function audit(source) {
  const activate = body(source, 'activateConsoleForeground', 'pasteFocusLanded');
  const first = activate.indexOf('if (SetForegroundWindow(target) != 0) {');
  assert.match(activate, /if \(SetForegroundWindow\(target\) != 0\) \{\s*const now_fg = GetForegroundWindow\(\);\s*if \(now_fg == null or now_fg == target\) return 1;\s*\}/);
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
    ['if (now_fg == null or now_fg == target) return 1;', 'if (now_fg == target) return 1;'],
    ['if (!g_igsh354_paste_focus) return 0;', ''],
    ['else activateConsoleForeground(target);', 'else SetForegroundWindow(GetAncestor(target, GA_ROOT));'],
  ];
  for (const [before, after] of mutations) {
    assert.ok(app.includes(before), before);
    assert.throws(() => audit(app.replace(before, after)), `restoring ${before} must fail`);
  }
});

function assertConsoleActivation(source) {
  const activate = body(source, 'activateConsoleForeground', 'pasteFocusLanded');
  const run = new Function('target', 'g_igsh354_paste_focus', 'SetForegroundWindow', 'GetForegroundWindow', 'GetAncestor', 'GA_ROOT', activate.slice(activate.indexOf('{') + 1, activate.lastIndexOf('}'))
    .replace(/\band\b/g, '&&').replace(/\bor\b/g, '||'));
  for (const enabled of [true, false]) {
    for (const result of [0, 1]) {
      for (const foreground of [null, 'console', 'other']) {
        const calls = [];
        let reads = 0;
        const success = result !== 0 && (foreground === null || foreground === 'console');
        const fallback = !success && enabled;
        const actual = run('console', enabled, hwnd => {
          calls.push(hwnd);
          return hwnd === 'console' ? result : 7;
        }, () => {
          reads++;
          return foreground;
        }, (hwnd, kind) => {
          assert.equal(hwnd, 'console');
          assert.equal(kind, 'GA_ROOT');
          return 'frame';
        }, 'GA_ROOT');
        assert.equal(actual, success ? 1 : fallback ? 7 : 0, `result=${result}, foreground=${foreground}, enabled=${enabled}`);
        assert.deepEqual(calls, fallback ? ['console', 'frame'] : ['console'], 'in-flight activation must not activate the frame');
        assert.equal(reads, result === 0 ? 0 : 1);
      }
    }
  }
}

test('IGSH-713 successful console activation with null foreground does not activate the frame', () => {
  assertConsoleActivation(app);
  const fixed = 'if (SetForegroundWindow(target) != 0) {\n        const now_fg = GetForegroundWindow();\n        if (now_fg == null or now_fg == target) return 1;\n    }';
  const old = 'if (SetForegroundWindow(target) != 0 and GetForegroundWindow() == target) return 1;';
  assert.ok(app.includes(fixed));
  assert.throws(() => assertConsoleActivation(app.replace(fixed, old)), /result=1, foreground=null/, 'the old line must fail the in-flight activation scenario');
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
  const journey = source.slice(source.indexOf("        'workspace-focus' {"), source.indexOf("        'chat-view' {"));
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
  const handoff = open.match(/            if \(wp == 1 and foregroundIsOurs\(\)\) \{[^]*?\n            \}/)?.[0];
  assert.ok(handoff, 'authorize the frame before AttachThreadInput can reuse console authorization');
  assert.match(handoff, /g_focus_authorized_hwnd = hwnd;\s*app_state\.g_focus_authorized_until = GetTickCount64\(\) \+ 1500;\s*const allowed = focusGuard\(hwnd\);/);
  assert.match(handoff, /palette_guard allowed=\{\}[^]*?if \(allowed\) \{/);
  assert.match(handoff, /palette_activate foreground=\{X\}[^]*?g_focus_authorized_hwnd = null;\s*app_state\.g_focus_authorized_until = 0;/);
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
    main.replace('app_state.g_focus_authorized_hwnd = hwnd;', ''),
    main.replace(handoff, handoff.replace('GetTickCount64() + 1500;', 'GetTickCount64() + 15000;')),
    main.replace('if (wp == 1 and foregroundIsOurs())', 'if (wp == 1)'),
    main.replace('const allowed = focusGuard(hwnd);', 'const allowed = true;'),
    main.replace('palette_guard allowed={}', 'missing_guard allowed={}'),
    main.replace('palette_activate foreground={X}', 'missing_activation foreground={X}'),
    main.replace(handoff, handoff.replace('app_state.g_focus_authorized_until = 0;', '')),
    main.replace(handoff, '').replace('        WM_APP_SEARCH_OPEN => {', `        WM_APP_SEARCH_OPEN => {\n${handoff}`),
    main.replace(handoff, '').replace('            altqLog("palette_focus', `${handoff}\n            altqLog("palette_focus`),
  ]) assert.throws(() => paletteHandoff(broken));
  const translated = handoff.replaceAll(' and ', ' && ').replaceAll('_ = ', '')
    .replace(/var (\w+): DWORD/g, 'let $1')
    .replaceAll('@as(i32, VK_MENU)', 'VK_MENU')
    .replaceAll('@as(i16, @bitCast(@as(u16, 0x8000)))', '0x8000')
    .replace(/const (\w+) = if \(([^\n]*?)\) ([^\n]*?) else 0;/g, 'const $1 = ($2) ? $3 : 0;')
    .replace(/&(fg_pid|sfw_pid)/g, 'value => { $1 = value; }')
    .replace(/, \.\{ ([^\n]*?) \}\);/g, ', [$1]);');
  const run = new Function('GetTickCount64', 'altqLog', 'altqPtr', 'GetFocus', 'wp', 'hwnd', 'app_state', 'foregroundIsOurs', 'focusGuard', 'cancelShellRefocus', 'GetForegroundWindow', 'GetCurrentThreadId', 'GetWindowThreadProcessId', 'AttachThreadInput', 'SetForegroundWindow', 'SetFocus', 'GetAsyncKeyState', 'VK_MENU', 'KEYEVENTF_KEYUP', 'keybd_event', translated);
  for (const previous of ['console', 'browser', 'frame', 'foreign']) {
    for (const wp of [0, 1]) {
      for (const allowed of [false, true]) {
        for (const physicalAlt of [false, true]) {
          for (const attachResult of [0, 1]) {
            for (const sfwResult of [0, 1]) {
              const state = { g_search_active: true, g_browser_focus_mode: true, g_focus_authorized_hwnd: null, g_focus_authorized_until: 0, g_focus_user_action_tick: 0, g_focus_input_tick: 900 };
              const calls = [];
              let authorized = 'console';
              let foreground = previous;
              let focused = previous;
              let alt = physicalAlt;
              const logs = [];
              run(() => 1000, (format, values) => logs.push([format, values]), hwnd => hwnd, () => focused, wp, 'frame', state, () => previous !== 'foreign', target => {
                assert.equal(state.g_focus_authorized_hwnd, 'frame');
                assert.equal(state.g_focus_authorized_until, 2500);
                assert.equal(state.g_focus_user_action_tick, 0, 'posted shortcut must not need a live hook action');
                if (allowed) authorized = target;
                return allowed;
              }, () => calls.push('cancel'), () => foreground, () => 1, (target, pid) => {
                if (pid) pid(target === 'frame' ? 10 : 20);
                return target === 'frame' ? 1 : 2;
              }, (from, to, attach) => {
                assert.equal(authorized, 'frame');
                calls.push(attach ? 'attach' : 'detach');
                return attach ? attachResult : 1;
              }, target => {
                assert.equal(state.g_search_active, true);
                assert.ok(alt || foreground === 'frame', 'native foreground unlock must precede activation');
                if (sfwResult) foreground = target;
                calls.push('foreground');
                return sfwResult;
              }, target => { focused = target; calls.push('focus'); }, () => physicalAlt ? 0x8000 : 0, 0x12, 2, (vk, scan, flags) => {
                if (vk === 0xFF) calls.push(flags === 0 ? 'mask-down' : 'mask-up');
                else {
                  assert.equal(vk, 0x12);
                  alt = flags === 0;
                  calls.push(alt ? 'alt-down' : 'alt-up');
                }
              });
              if (wp === 1 && allowed && previous !== 'foreign') {
                const landed = sfwResult || previous === 'frame';
                assert.equal(foreground, landed ? 'frame' : previous);
                assert.equal(focused, 'frame');
                assert.equal(state.g_browser_focus_mode, !landed);
                const expected = ['cancel'];
                if (previous !== 'frame' && !physicalAlt) expected.push('alt-down');
                if (previous !== 'frame') expected.push('attach');
                expected.push('foreground', 'focus');
                if (previous !== 'frame' && attachResult) expected.push('detach');
                if (previous !== 'frame' && !physicalAlt) expected.push('mask-down', 'mask-up', 'alt-up');
                assert.deepEqual(calls, expected);
                const native = logs[1];
                assert.match(native[0], /palette_native/);
                assert.deepEqual(native[1], [previous, previous === 'frame' ? 1 : 2, previous === 'frame' ? 10 : 20, 1, previous === 'frame' ? 0 : attachResult, sfwResult, foreground, foreground === 'frame' ? 1 : 2, foreground === 'frame' ? 10 : 20, previous !== 'frame' && attachResult ? 1 : 0, previous !== 'frame' && !physicalAlt]);
              } else assert.deepEqual(calls, []);
              assert.equal(alt, physicalAlt, 'the handoff must restore injected Alt without releasing physical Alt');
              assert.equal(state.g_focus_authorized_hwnd, null, 'frame authority cannot outlive this handoff');
              assert.equal(state.g_focus_authorized_until, 0);
              assert.equal(logs.length, wp === 1 && previous !== 'foreign' ? (allowed ? 3 : 1) : 0);
              if (logs.length) assert.equal(logs[0][1][0], allowed);
              if (logs.length === 3) assert.equal(logs[2][1][0], foreground);
            }
          }
        }
      }
    }
  }
});

test('palette frame authority works without a dispatch tick but never overrides foreign foreground', () => {
  const focus = fs.readFileSync(path.resolve(__dirname, '..', 'src/focus.zig'), 'utf8');
  const policy = focus.match(/fn focusGuardPolicy\([^]*?\) bool \{([^]*?)\n\}/)?.[1];
  assert.ok(policy);
  const allows = new Function('now', 'action_tick', 'same_surface', 'authorized', 'foreground_owned', policy.replace(/\band\b/g, '&&').replace(/\bor\b/g, '||'));
  assert.equal(allows(1000, 0, false, false, true), false, 'clearing console authority alone does not authorize the frame');
  assert.equal(allows(1000, 0, false, true, true), true, 'an explicit frame grant bridges the posted shortcut');
  assert.equal(allows(1000, 0, false, true, false), false, 'a bounded grant never overrides foreign foreground');
  assert.equal(allows(2501, 0, false, false, true), false, 'expired frame authority cannot activate the frame');
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

test('landed handoffs consume authority without losing the exact return surface', () => {
  const focus = fs.readFileSync(path.resolve(__dirname, '..', 'src/focus.zig'), 'utf8');
  const run = workspacePillLanding(focus);
  for (const target of ['console', 'composer', 'pane']) {
    const state = {
      active_shell: 0, shell_count: 1, shells: [{ shell_id: 7, browser_hwnd: 'pane' }],
      g_focus_browser_shell_id: target === 'pane' ? 7 : 0,
      g_focus_authorized_hwnd: target === 'pane' ? null : target,
      g_focus_authorized_until: 2500, g_focus_user_action_tick: 0,
      g_focus_paste_target: null, g_focus_return_hwnd: 'old', g_focus_typing_tick: 900,
    };
    const before = { ...state };
    let captures = 0;
    const capture = () => captures++;
    run('unrelated', state, () => 1300, hwnd => hwnd, capture);
    assert.deepEqual(state, before, 'unrelated landing must not consume a pending handoff');
    run(target, state, () => 2501, hwnd => hwnd, capture);
    assert.deepEqual(state, before, 'expired authority must not change remembered focus');
    assert.equal(captures, 0, 'unrelated or expired handoffs cannot capture workspace focus');
    run(target, state, () => 1300, hwnd => hwnd, capture);
    assert.equal(captures, 1, 'capture the newly landed surface before a pill activates the frame');
    assert.equal(state.g_focus_return_hwnd, target);
    assert.equal(state.g_focus_typing_tick, 0);
    assert.equal(state.g_focus_authorized_hwnd, null);
    assert.equal(state.g_focus_authorized_until, 0);
    assert.equal(state.g_focus_browser_shell_id, 0);
  }
});

function auditPaletteUnlock(main, focus) {
  const handoff = paletteHandoff(main);
  const working = body(focus, 'focusActiveShellInner', 'activateConsoleForeground');
  assert.match(working, /if \(need_alt\) \{\s*keybd_event\(VK_MENU, 0, 0, 0\);[^]*?AttachThreadInput[^]*?activateConsoleForeground\(target_hwnd\)[^]*?keybd_event\(VK_MENU, 0, KEYEVENTF_KEYUP, 0\);/);
  assert.match(handoff, /const tap_alt = fg != hwnd and \(GetAsyncKeyState\(@as\(i32, VK_MENU\)\) & @as\(i16, @bitCast\(@as\(u16, 0x8000\)\)\)\) == 0;/);
  const down = handoff.indexOf('if (tap_alt) keybd_event(VK_MENU, 0, 0, 0);');
  const attach = handoff.indexOf('const attach_result =');
  const activate = handoff.indexOf('const sfw_result = SetForegroundWindow(hwnd);');
  const observed = handoff.indexOf('const sfw_foreground = GetForegroundWindow();');
  const detach = handoff.indexOf('const detach_result =');
  const up = handoff.indexOf('keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);');
  assert.match(handoff, /if \(tap_alt\) \{\s*keybd_event\(0xFF, 0, 0, 0\);\s*keybd_event\(0xFF, 0, KEYEVENTF_KEYUP, 0\);\s*keybd_event\(VK_MENU, 0, KEYEVENTF_KEYUP, 0\);\s*\}/);
  assert.ok(down >= 0 && attach > down && activate > attach && observed > activate && detach > observed && up > detach, 'use the established Alt unlock around the attached foreground handoff');
  assert.match(handoff, /const attach_result = if \(fg_thread != 0 and fg_thread != our_thread\) AttachThreadInput\(our_thread, fg_thread, 1\) else 0;/);
  assert.match(handoff, /const detach_result = if \(attach_result != 0\) AttachThreadInput\(our_thread, fg_thread, 0\) else 0;/);
  assert.match(handoff, /GetWindowThreadProcessId\(fg, &fg_pid\)/);
  assert.match(handoff, /GetWindowThreadProcessId\(sfw_foreground, &sfw_pid\)/);
  assert.match(handoff, /palette_native before=\{X\} tid=\{\} pid=\{\} our_tid=\{\} attach=\{\} sfw=\{\} after=\{X\} tid=\{\} pid=\{\} detach=\{\} alt=\{\}[^]*?\.\{ altqPtr\(fg\), fg_thread, fg_pid, our_thread, attach_result, sfw_result, altqPtr\(sfw_foreground\), sfw_thread, sfw_pid, detach_result, tap_alt \}/);
  const open = main.slice(main.indexOf('        WM_APP_SEARCH_OPEN => {'), main.indexOf('        WM_APP_SEARCH_CLOSE => {'));
  assert.match(open, /palette_refocus rem=\{\} wait_alt=\{\}[^]*?cancelShellRefocus\(hwnd\);\s*app_state\.g_search_active = true;/);
  assert.match(open, /palette_focus wp=\{\} foreground=\{X\} frame=\{X\} focus=\{X\} rem=\{\} wait_alt=\{\}/);
  const timer = main.slice(main.indexOf('} else if (wp == TIMER_REFOCUS) {'), main.indexOf('} else if (wp == TIMER_HOOK_UNINSTALL) {'));
  assert.match(timer, /if \(app_state\.g_search_active\) \{\s*altqLog\("palette_refocus suppressed[^]*?cancelShellRefocus\(hwnd\);\s*return 0;\s*\}\s*if \(!focusGuard\(/);
}

test('palette activation uses the established unlock and rejects missing native diagnostics or timer isolation', () => {
  const root = path.resolve(__dirname, '..');
  const main = fs.readFileSync(path.join(root, 'src/main.zig'), 'utf8');
  const focus = fs.readFileSync(path.join(root, 'src/focus.zig'), 'utf8');
  auditPaletteUnlock(main, focus);
  for (const missing of [
    'if (tap_alt) keybd_event(VK_MENU, 0, 0, 0);',
    'keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);',
    'keybd_event(0xFF, 0, 0, 0);',
    'keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);',
    'const sfw_foreground = GetForegroundWindow();',
    'palette_native before={X}',
    'palette_refocus suppressed',
    'GetWindowThreadProcessId(fg, &fg_pid)',
    'GetWindowThreadProcessId(sfw_foreground, &sfw_pid)',
  ]) {
    assert.ok(main.includes(missing), missing);
    assert.throws(() => auditPaletteUnlock(main.replace(missing, ''), focus), missing);
  }
});

test('palette activation unlock rejects baseline 77519a8', { skip: !process.env.PALETTE_BASELINE }, () => {
  const root = path.resolve(__dirname, '..');
  const focus = fs.readFileSync(path.join(root, 'src/focus.zig'), 'utf8');
  const baseline = execFileSync('git', ['show', `${process.env.PALETTE_BASELINE}:src/main.zig`], { cwd: root, encoding: 'utf8', maxBuffer: 2 * 1024 * 1024 });
  assert.throws(() => auditPaletteUnlock(baseline, focus), /const tap_alt/, 'the native-unlock assertion must fail on the actual previous implementation');
});

function workspacePillLanding(focus) {
  const landed = focus.match(/fn focusGuardLanded\(hwnd: HANDLE\) void \{([^]*?)\n\}/)?.[1];
  assert.ok(landed);
  return new Function('hwnd', 'app_state', 'GetTickCount64', 'focusGuardSurface', 'captureWorkspaceFocus', landed
    .replace('@import("workspaces.zig").captureWorkspaceFocus()', 'captureWorkspaceFocus()')
    .replace('now -| app_state.g_focus_user_action_tick', 'Math.max(0, now - app_state.g_focus_user_action_tick)')
    .replace(/\band\b/g, '&&').replace(/\bor\b/g, '||'));
}

function assertWorkspacePillCapture(focus) {
  const root = path.resolve(__dirname, '..');
  const workspaces = fs.readFileSync(path.join(root, 'src/workspaces.zig'), 'utf8');
  const captureBody = workspaces.match(/pub fn captureWorkspaceFocus\(\) void \{([^]*?)\n\}/)?.[1];
  assert.ok(captureBody);
  const capture = new Function('app_state', 'GetFocus', 'activeShellHasForegroundFocus', 'rememberWorkspaceFocus', captureBody
    .replace('const shell = &', 'const shell = ')
    .replace(/const input: app_state\.WorkspaceFocus = if \(([^]*?)\)\s*\.chat\s*else if \(([^]*?)\)\s*\.shell\s*else\s*\.none;/, 'const input = ($1) ? "chat" : ($2) ? "shell" : "none";')
    .replace('@import("win32.zig").GetFocus()', 'GetFocus()')
    .replace('@import("focus.zig").activeShellHasForegroundFocus()', 'activeShellHasForegroundFocus()')
    .replace(/\band\b/g, '&&').replace(/\bor\b/g, '||'));
  const rememberBody = workspaces.match(/fn rememberWorkspaceFocus\([^]*?\) void \{([^]*?)\n\}/)?.[1];
  assert.ok(rememberBody);
  const remember = new Function('app_state', 'ws', 'shell_id', 'input', 'MAX_LWS', rememberBody
    .replace('input == .none', 'input == "none"').replace(/\bor\b/g, '||'));
  const land = workspacePillLanding(focus);
  for (const surface of ['shell', 'chat']) {
    const state = {
      active_shell: 0, shell_count: 1, shells: [{ shell_id: 7, workspace: 0, browser_hwnd: null }],
      g_restoring: false, g_starred_workspace: false, g_single_window: true, g_active_workspace: 0,
      g_chat_active: surface === 'chat', g_chat_composer_hwnd: 'composer',
      g_ws_last_shell: [7], g_ws_focus: [surface === 'shell' ? 'chat' : 'shell'],
      g_focus_browser_shell_id: 0, g_focus_authorized_hwnd: surface, g_focus_authorized_until: 2500,
      g_focus_user_action_tick: 0, g_focus_paste_target: null, g_focus_return_hwnd: 'old', g_focus_typing_tick: 900,
    };
    let foreground = surface;
    let focused = surface === 'chat' ? 'composer' : 'console';
    const record = () => capture(state, () => focused, () => foreground === 'shell', (ws, id, input) => remember(state, ws, id, input, 16));
    land(surface, state, () => 1300, hwnd => hwnd, record);
    assert.equal(state.g_focus_authorized_hwnd, null);
    assert.equal(state.g_focus_authorized_until, 0);
    assert.equal(state.g_focus_return_hwnd, surface);
    assert.equal(state.g_ws_focus[0], surface, 'landing must capture the selected surface before pill activation');
    foreground = 'frame';
    focused = surface === 'chat' ? 'composer' : 'frame';
    record();
    assert.equal(state.g_ws_focus[0], surface, 'frame activation must not resurrect stale workspace focus');
    assert.equal(state.g_ws_last_shell[0], 7);
  }
}

test('workspace pills preserve the observed shell landing just as synchronous composer repair preserves chat', () => {
  const focus = fs.readFileSync(path.resolve(__dirname, '..', 'src/focus.zig'), 'utf8');
  assertWorkspacePillCapture(focus);
  assert.throws(() => assertWorkspacePillCapture(focus.replace('@import("workspaces.zig").captureWorkspaceFocus();', '')), /landing must capture/);
});

test('workspace pill capture rejects the actual 3729aa3 implementation', { skip: !process.env.WORKSPACE_FOCUS_BASELINE }, () => {
  const baseline = execFileSync('git', ['show', `${process.env.WORKSPACE_FOCUS_BASELINE}:src/focus.zig`], { cwd: path.resolve(__dirname, '..'), encoding: 'utf8' });
  assert.throws(() => assertWorkspacePillCapture(baseline), /landing must capture/, 'the old app must fail the same shell/chat landing scenario');
});

function renameCommitAction(source) {
  const policy = source.match(/fn renameCommitActionTick\([^]*?\) u64 \{([^]*?)\n\}/)?.[1];
  if (!policy) return tick => tick;
  return new Function('dispatched_tick', 'now', 'foreground_owned', policy
    .replace(/return if \(([^]*?)\) ([^]*?) else ([^]*?);/, 'return ($1) ? $2 : $3;'));
}

function assertRenameCommitFocus(rename) {
  const edit = body(rename, 'editSubclassProc', 'startWindowRename');
  const dispatch = edit.slice(edit.indexOf('    const prior_focus_action ='), edit.indexOf('    if (msg == WM_KILLFOCUS'));
  const enter = edit.match(/        if \(wp == 0x0D\) \{([^]*?)\n        \}/)?.[1];
  assert.ok(enter);
  assert.match(dispatch, /defer app_state\.g_focus_user_action_tick = prior_focus_action;/);
  const run = new Function('msg', 'wp', 'lp', 'app_state', 'focusGuardDispatchTick', 'renameCommitActionTick', 'GetTickCount64', 'foregroundIsOurs', 'commitRename', `
    ${dispatch.replace('defer app_state.g_focus_user_action_tick = prior_focus_action;', '')}
    try { if (msg === 256 && wp === 13) { ${enter} } }
    finally { app_state.g_focus_user_action_tick = prior_focus_action; }
  `);
  const focus = fs.readFileSync(path.resolve(__dirname, '..', 'src/focus.zig'), 'utf8');
  const guard = focus.match(/fn focusGuardPolicy\([^]*?\) bool \{([^]*?)\n\}/)?.[1];
  assert.ok(guard);
  const allows = new Function('now', 'action_tick', 'same_surface', 'authorized', 'foreground_owned', guard.replace(/\band\b/g, '&&').replace(/\bor\b/g, '||'));
  const commit = body(rename, 'commitRename', 'openTabContextPalette');
  const tail = commit.slice(commit.lastIndexOf('    app_state.g_shell_focused = true;'), commit.lastIndexOf('}'));
  const finish = new Function('app_state', 'focusActiveShell', 'activeShellHasForegroundFocus', 'requestShellRefocus', tail);
  for (const owned of [false, true]) {
    for (const dispatched of [0, 1000, 5000]) {
      for (const [msg, wp] of [[256, 13], [256, 27], [8, 13]]) {
        const state = { g_focus_user_action_tick: 0, g_focus_input_tick: dispatched, g_focus_return_hwnd: 'edit', g_shell_focused: false };
        let foreground = owned ? 'frame' : 'foreign';
        let commits = 0;
        run(msg, wp, 0, state, () => dispatched, renameCommitAction(rename), () => 5000, () => owned, () => {
          commits++;
          const action = state.g_focus_user_action_tick >= state.g_focus_input_tick ? state.g_focus_user_action_tick : 0;
          if (!owned) assert.equal(state.g_focus_user_action_tick, dispatched, 'rename Enter must not authorize foreign foreground');
          const permitted = () => owned && allows(5000, action, false, false, owned);
          finish(state, () => { if (permitted()) foreground = 'console'; }, () => foreground === 'console', () => {
            if (permitted()) foreground = 'console';
          });
        });
        const committed = msg === 256 && wp === 13;
        assert.equal(commits, committed ? 1 : 0);
        assert.equal(foreground, committed && owned ? 'console' : owned ? 'frame' : 'foreign', 'rename Enter must authorize the console even without a physical input tick');
        assert.equal(state.g_focus_user_action_tick, 0, 'rename authority must end with the edit dispatch');
        assert.equal(state.g_focus_input_tick, dispatched, 'injected Enter must not manufacture physical input history');
        assert.equal(state.g_focus_return_hwnd, 'edit', 'only an actual focus landing may change the return surface');
      }
    }
  }
}

test('ISSUE-597 rename Enter transfers dispatch authority to the console without changing physical input history', () => {
  const rename = fs.readFileSync(path.resolve(__dirname, '..', 'src/rename.zig'), 'utf8');
  assertRenameCommitFocus(rename);
  const grant = 'app_state.g_focus_user_action_tick = renameCommitActionTick(app_state.g_focus_user_action_tick, GetTickCount64(), foregroundIsOurs());';
  assert.ok(rename.includes(grant));
  assert.throws(() => assertRenameCommitFocus(rename.replace(grant, '')), /rename Enter must authorize the console/);
  assert.throws(() => assertRenameCommitFocus(rename.replace('return if (foreground_owned) now else dispatched_tick;', 'return dispatched_tick;')), /rename Enter must authorize the console/);
  assert.throws(() => assertRenameCommitFocus(rename.replace('return if (foreground_owned) now else dispatched_tick;', 'return now;')), /rename Enter must not authorize foreign foreground/);
  const regression = rename.match(/test "ISSUE-597 rename Enter retains focus authority after injected input" \{([^]*?)\n\}/)?.[1];
  assert.ok(regression);
  const assertions = [...regression.matchAll(/expectEqual\(@as\(u64, (\d+)\), renameCommitActionTick\((\d+), (\d+), (true|false)\)\)/g)];
  assert.equal(assertions.length, 5);
  for (const [, expected, tick, now, owned] of assertions) {
    assert.equal(renameCommitAction(rename)(Number(tick), Number(now), owned === 'true'), Number(expected));
  }
  const oldDecision = rename.replace('return if (foreground_owned) now else dispatched_tick;', 'return dispatched_tick;');
  assert.notEqual(renameCommitAction(oldDecision)(0, 5000, true), 5000, 'the first Zig assertion rejects the old zero-authority decision');
});

test('ISSUE-597 console handoff rejects the actual pre-fix edit dispatch', { skip: !process.env.RENAME_FOCUS_BASELINE }, () => {
  const baseline = execFileSync('git', ['show', `${process.env.RENAME_FOCUS_BASELINE}:src/rename.zig`], { cwd: path.resolve(__dirname, '..'), encoding: 'utf8' });
  assert.throws(() => assertRenameCommitFocus(baseline), /rename Enter must authorize the console/);
});
