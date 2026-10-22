import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8').replace(/\r\n/g, '\n');
const driver = process.argv[2] ? fs.readFileSync(process.argv[2], 'utf8').replace(/\r\n/g, '\n') : read('.claude/skills/verify-multiprompt/control.ps1');

function nativePaletteFocusContract(source) {
  const native = source.match(/public static IntPtr GetFocusedWindow\(IntPtr hwnd\) \{([\s\S]*?)\n    \}/)?.[1];
  assert.ok(native, 'palette focus must read the owned GUI thread, not a UIA proxy handle');
  assert.match(source, /\[StructLayout\(LayoutKind.Sequential\)\] public struct GuiThreadInfo \{ public uint Size, Flags; public IntPtr Active, Focus, Capture, MenuOwner, MoveSize, Caret; public Rect CaretRect; \}/);
  assert.match(source, /\[DllImport\("user32.dll", SetLastError=true\)\] static extern bool GetGUIThreadInfo\(uint thread, ref GuiThreadInfo info\);/);
  assert.match(native, /uint thread = GetWindowThreadProcessId\(hwnd, out pid\);/);
  assert.match(native, /if \(thread == 0\) throw /);
  assert.match(native, /info.Size = \(uint\)Marshal.SizeOf\(typeof\(GuiThreadInfo\)\);/);
  assert.match(native, /if \(!GetGUIThreadInfo\(thread, ref info\)\) throw /);
  assert.match(native, /return info.Focus;/);
  assert.doesNotMatch(native, /SetFocus|SetForegroundWindow|AttachThreadInput|SendInput|GetAncestor/);
  const palette = source.match(/function Focus-Palette\([^\n]*\) \{([\s\S]*?)\n\}/)?.[1];
  assert.ok(palette);
  assert.match(palette, /\$start = \(Get-Content \$log -Raw\).Length\s+Press @\(0x11, 0x4B\) 'Ctrl\+K: open command palette'/);
  assert.match(palette, /\$trace = \(Get-Content \$log -Raw\).Substring\(\$start\)/);
  assert.ok(palette.includes("$trace -match '\\[palette\\] ready chars=0 count=\\d+ target=\\d+' -and [VerifyNative]::GetForegroundWindow() -eq $script:window -and [VerifyNative]::GetFocusedWindow($script:window) -eq $script:window"), 'initialized palette, foreground frame and exact native focus are all required');
  assert.match(palette, /\} 'command palette initialized and owned frame focused'\s+Type-Text \$Query\s+Wait-Until \{/);
  assert.ok(palette.includes("' count=[1-9]\\d* target=' + $Target + '(?:\\r?\\n|$)'"), 'query must still select the exact command');
  assert.match(palette, /\$Query.Length/);
  assert.equal((palette.match(/Wait-Until \{/g) || []).length, 2);
  assert.doesNotMatch(palette, /FocusedElement|SetFocus|SetForegroundWindow|ClickClient/);
  const surface = source.slice(source.indexOf('function Wait-WorkspaceSurface('), source.indexOf('function Wait-ConsoleText('));
  assert.match(surface, /\$focused.Current.NativeWindowHandle -eq \$Composer/);
  assert.match(surface, /\$element.Current.ProcessId -eq \$process.Id -and -not \$element.Current.IsOffscreen/);
  assert.doesNotMatch(surface, /SetFocus|SetForegroundWindow|ClickClient/);
  assert.ok(source.includes("Save-Json $focus ($Name + '.focus.json')"));
  assert.match(source, /\$focus.native = \[VerifyNative\]::GetFocusedWindow\(\$script:window\).ToInt64\(\)/);
  assert.match(source, /\$focus.uia = @\{ handle = \$focused.Current.NativeWindowHandle; pid = \$focused.Current.ProcessId; class = \$focused.Current.ClassName \}/);
}

function appPaletteFocusContract(shortcuts, main) {
  const chord = shortcuts.match(/if \(!shift and kb\.vkCode == 0x4B and \(kb\.flags & 0x20\) == 0\) \{([\s\S]*?)\n                \}/)?.[1];
  assert.ok(chord, 'Ctrl+K must retain its non-Alt, non-Shift chord');
  assert.match(chord, /if \(activeBrowserHasForegroundFocus\(\)\) \{\s*return CallNextHookEx/);
  assert.match(chord, /PostMessageW\(app_state\.g_main_hwnd, WM_APP_SEARCH_OPEN, 1, 0\)/, 'Ctrl+K must activate the frame, not leave the embedded console foreground');
  const open = main.slice(main.indexOf('        WM_APP_SEARCH_OPEN => {'), main.indexOf('        WM_APP_SEARCH_CLOSE => {'));
  assert.match(open, /if \(wp == 1 and foregroundIsOurs\(\)\) \{\s*app_state\.g_focus_authorized_hwnd = hwnd;\s*app_state\.g_focus_authorized_until = GetTickCount64\(\) \+ 1500;\s*const allowed = focusGuard\(hwnd\);[^]*?if \(allowed\) \{\s*cancelShellRefocus\(hwnd\);/);
  const handoff = open.match(/            if \(wp == 1 and foregroundIsOurs\(\)\) \{[\s\S]*?\n            \}/)?.[0];
  assert.ok(handoff);
  const native = handoff.match(/                if \(allowed\) \{[\s\S]*?\n                \}/)?.[0];
  assert.ok(native, 'native activation must remain inside the focus guard');
  assert.match(native, /cancelShellRefocus\(hwnd\);\s*const fg = GetForegroundWindow\(\);\s*const our_thread = GetCurrentThreadId\(\);\s*var fg_pid: DWORD = 0;\s*const fg_thread = GetWindowThreadProcessId\(fg, &fg_pid\);/);
  assert.match(native, /const tap_alt = fg != hwnd and \(GetAsyncKeyState\(@as\(i32, VK_MENU\)\) & @as\(i16, @bitCast\(@as\(u16, 0x8000\)\)\)\) == 0;/);
  assert.match(native, /if \(tap_alt\) keybd_event\(VK_MENU, 0, 0, 0\);\s*const attach_result = if \(fg_thread != 0 and fg_thread != our_thread\) AttachThreadInput\(our_thread, fg_thread, 1\) else 0;\s*const sfw_result = SetForegroundWindow\(hwnd\);\s*const sfw_foreground = GetForegroundWindow\(\);\s*var sfw_pid: DWORD = 0;\s*const sfw_thread = GetWindowThreadProcessId\(sfw_foreground, &sfw_pid\);\s*_ = SetFocus\(hwnd\);\s*const detach_result = if \(attach_result != 0\) AttachThreadInput\(our_thread, fg_thread, 0\) else 0;/);
  assert.match(native, /if \(tap_alt\) \{\s*keybd_event\(0xFF, 0, 0, 0\);\s*keybd_event\(0xFF, 0, KEYEVENTF_KEYUP, 0\);\s*keybd_event\(VK_MENU, 0, KEYEVENTF_KEYUP, 0\);\s*\}/);
  assert.match(handoff.slice(handoff.indexOf(native) + native.length), /app_state\.g_focus_authorized_hwnd = null;\s*app_state\.g_focus_authorized_until = 0;/);
  assert.match(open, /cancelShellRefocus\(hwnd\);\s*app_state\.g_search_active = true;/);
  const activation = open.indexOf('if (wp == 1 and foregroundIsOurs())');
  const searchActive = open.indexOf('app_state.g_search_active = true;');
  assert.ok(searchActive >= 0 && searchActive < activation, 'palette state must precede reentrant native activation');
  assert.doesNotMatch(open.slice(0, activation), /SetForegroundWindow\(|SetFocus\(|AttachThreadInput\(|keybd_event\(/);
  assert.ok(open.indexOf(handoff) + handoff.length < open.indexOf('hideShellsForOverlay();'), 'park foreground before hiding the input surfaces');
  assert.match(open, /altqLog\("palette_focus wp=\{\} foreground=\{X\} frame=\{X\} focus=\{X\} rem=\{\} wait_alt=\{\}", \.\{ wp, altqPtr\(GetForegroundWindow\(\)\), altqPtr\(hwnd\), altqPtr\(GetFocus\(\)\), app_state\.g_refocus_remaining, app_state\.g_refocus_waiting_for_alt_release \}\);/);
  assert.match(main, /const SetForegroundWindow = @import\("focus.zig"\)\.SetForegroundWindow;/);
  assert.match(main, /const SetFocus = @import\("focus.zig"\)\.SetFocus;/);
  assert.match(main, /const AttachThreadInput = @import\("focus.zig"\)\.AttachThreadInput;/);
}

const shortcuts = read('src/shortcuts.zig');
const main = read('src/main.zig');
appPaletteFocusContract(shortcuts, main);
for (const [file, before, after] of [
  ['shortcuts', 'debugLog("hook: Ctrl+K seen, posting WM_APP_SEARCH_OPEN");\n                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_OPEN, 1, 0);', 'debugLog("hook: Ctrl+K seen, posting WM_APP_SEARCH_OPEN");\n                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_OPEN, 0, 0);'],
  ['shortcuts', 'if (activeBrowserHasForegroundFocus()) {\n                        return CallNextHookEx', 'if (false) {\n                        return CallNextHookEx'],
  ['main', 'wp == 1 and foregroundIsOurs()', 'wp == 1'],
  ['main', 'const allowed = focusGuard(hwnd);', 'const allowed = true;'],
  ['main', 'app_state.g_focus_authorized_hwnd = hwnd;', ''],
  ['main', 'const sfw_result = SetForegroundWindow(hwnd);', 'const sfw_result = 0;'],
  ['main', 'const detach_result = if (attach_result != 0) AttachThreadInput(our_thread, fg_thread, 0) else 0;', ''],
  ['main', 'const fg_thread = GetWindowThreadProcessId(fg, &fg_pid);', 'const fg_thread = GetWindowThreadProcessId(fg, null);'],
  ['main', 'GetTickCount64() + 1500;\n                const allowed = focusGuard(hwnd);', 'GetTickCount64() + 60000;\n                const allowed = focusGuard(hwnd);'],
  ['main', 'if (allowed) {\n                    cancelShellRefocus(hwnd);', 'if (true) {\n                    cancelShellRefocus(hwnd);'],
  ['main', 'fg_thread != 0 and fg_thread != our_thread', 'fg_thread != 0'],
  ['main', 'if (attach_result != 0) AttachThreadInput', 'if (true) AttachThreadInput'],
  ['main', 'const tap_alt = fg != hwnd and ', 'const tap_alt = '],
  ['main', 'if (tap_alt) keybd_event(VK_MENU, 0, 0, 0);', ''],
  ['main', 'keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);', ''],
  ['main', 'keybd_event(0xFF, 0, 0, 0);', ''],
  ['main', 'keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);', ''],
  ['main', '_ = SetFocus(hwnd);\n                    const detach_result', 'const detach_result'],
  ['main', 'app_state.g_focus_authorized_hwnd = null;\n                app_state.g_focus_authorized_until = 0;', 'app_state.g_focus_authorized_until = 0;'],
  ['main', 'app_state.g_focus_authorized_hwnd = null;\n                app_state.g_focus_authorized_until = 0;', 'app_state.g_focus_authorized_hwnd = null;'],
  ['main', 'const SetForegroundWindow = @import("focus.zig").SetForegroundWindow;', 'const SetForegroundWindow = @import("win32.zig").SetForegroundWindow;'],
]) {
  const source = file === 'shortcuts' ? shortcuts : main;
  const broken = source.replace(before, after);
  assert.notEqual(broken, source, `mutation applies: ${before}`);
  assert.throws(() => appPaletteFocusContract(file === 'shortcuts' ? broken : shortcuts, file === 'main' ? broken : main), assert.AssertionError, `reject palette activation regression: ${before}`);
}

const paletteActivation = main.slice(main.indexOf('        WM_APP_SEARCH_OPEN => {'), main.indexOf('        WM_APP_SEARCH_CLOSE => {'))
  .match(/            if \(wp == 1 and foregroundIsOurs\(\)\) \{[\s\S]*?\n            \}/)?.[0];
assert.ok(paletteActivation);
for (const newline of ['\n', '\r\n']) {
  appPaletteFocusContract(shortcuts.replaceAll('\n', newline), main.replaceAll('\n', newline));
  const earlyActivation = main.replace(paletteActivation, '').replace('        WM_APP_SEARCH_OPEN => {', `        WM_APP_SEARCH_OPEN => {\n${paletteActivation}`);
  assert.notEqual(earlyActivation, main);
  assert.throws(() => appPaletteFocusContract(shortcuts, earlyActivation.replaceAll('\n', newline)), assert.AssertionError, 'reject activation before palette state blocks reentrant repairs');
  const earlyNative = main.replace('        WM_APP_SEARCH_OPEN => {', '        WM_APP_SEARCH_OPEN => {\n            _ = SetForegroundWindow(hwnd);');
  assert.throws(() => appPaletteFocusContract(shortcuts, earlyNative.replaceAll('\n', newline)), assert.AssertionError, 'reject unguarded native activation before palette state');
}

function hookFocusAuthorityContract(source, focus) {
  const attribution = source.slice(source.indexOf('        const prior_focus_action ='), source.indexOf('        const find_key_up ='));
  assert.match(attribution, /defer app_state\.g_focus_user_action_tick = prior_focus_action;/);
  assert.match(attribution, /app_state\.g_focus_user_action_tick = 0;/);
  assert.match(attribution, /if \(\(kb\.flags & 0x10\) == 0\) \{[^}]*focusGuardNoteInput\(surface, GetTickCount64\(\), true\);[^}]*foregroundHwndIsOurs\(fg\)/);
  const injected = attribution.match(/\} else if \(([\s\S]*?)\)\s*\{\s*(?:app_state\.g_focus_(?:authorized_hwnd|authorized_until|browser_shell_id) = (?:null|0);\s*)*app_state\.g_focus_user_action_tick = GetTickCount64\(\);\s*\}/);
  assert.ok(injected, 'owned injected shortcut commands need dispatch authority, not physical typing history');
  assert.doesNotMatch(injected[0], /focusGuardNoteInput|g_focus_input_tick =|g_focus_return_hwnd =/);
  const allows = new Function('wp', 'key', 'owned', `return ${injected[1]
    .replaceAll('WM_SYSKEYDOWN', '260').replaceAll('WM_KEYDOWN', '256').replaceAll('kb.vkCode', 'key')
    .replaceAll('VK_MENU', '18').replaceAll('foregroundIsOurs()', 'owned').replaceAll(' and', ' &&').replaceAll(' or', ' ||')};`);
  for (const key of [0x0D, 0x4B, 0x43, 0x4E, 0x32, 0x25, 0x27, 0x57]) {
    for (const wp of [256, 257, 260, 261]) {
      for (const owned of [false, true]) assert.equal(allows(wp, key, owned), owned && [256, 260].includes(wp));
    }
  }
  for (const key of [0x12, 0xA4, 0xA5, 0xFF]) {
    for (const wp of [256, 260]) assert.equal(allows(wp, key, true), false, 'internal Alt tricks must not manufacture authority');
  }
  assert.match(source, /const PostMessageW = @import\("focus.zig"\)\.PostMessageW;/);
  for (const message of ['SEARCH_OPEN', 'SEARCH_CHAR', 'SEARCH_CONFIRM', 'CHAT_TOGGLE', 'NEW_WINDOW', 'SWITCH_WORKSPACE', 'CYCLE_WORKSPACE']) {
    assert.match(source, new RegExp(`PostMessageW\\(app_state\\.g_main_hwnd, WM_APP_${message},`));
  }
  const post = focus.slice(focus.indexOf('pub fn PostMessageW('), focus.indexOf('fn focusGuardPasteAllows('));
  assert.match(post, /GetCurrentThreadId\(\) == GetWindowThreadProcessId\(app_state\.g_main_hwnd, null\) and app_state\.g_focus_user_action_tick != 0/);
  assert.match(post, /\.msg = msg, \.wp = wp, \.lp = lp, \.tick = app_state\.g_focus_user_action_tick/);
  assert.match(post, /entry\.msg == msg and entry\.wp == wp and entry\.lp == lp/);
  assert.match(post, /entry\.tick = 0;\s*return if \(now -\| tick <= 1500\) tick else 0;/);
}

const focusSource = read('src/focus.zig');
hookFocusAuthorityContract(shortcuts, focusSource);
for (const [before, after] of [
  ['} else if ((wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and', '} else if ((wp == WM_KEYDOWN) and'],
  ['foregroundIsOurs())\n        {\n            app_state.g_focus_authorized_hwnd = null;', 'true)\n        {\n            app_state.g_focus_authorized_hwnd = null;'],
  ['kb.vkCode != VK_MENU and ', ''],
  ['kb.vkCode != 0xA4 and ', ''],
  ['kb.vkCode != 0xA5 and ', ''],
  [' and kb.vkCode != 0xFF', ''],
  ['app_state.g_focus_user_action_tick = GetTickCount64();', 'app_state.g_focus_user_action_tick = 0;'],
]) {
  const broken = shortcuts.replace(before, after);
  assert.notEqual(broken, shortcuts, `mutation applies: ${before}`);
  assert.throws(() => hookFocusAuthorityContract(broken, focusSource), assert.AssertionError);
}

function journeyOptionalChatContract(source) {
  const journey = source.slice(source.indexOf("        'workspace-focus' {"), source.indexOf("        'chat-view' {"));
  assert.match(journey, /\$tab\.PSObject\.Properties\.Name -contains 'cv' -and \$tab\.cv/);
  assert.doesNotMatch(journey, /\(Read-Session\)\.tabs\[[^\]]+\]\.cv/);
  const wait = journey.match(/Wait-Until \{\s*\$state = Read-Session\s*([^\n]+)\s*\} 'test session Chat View enabled'/);
  assert.ok(wait, 'cv readiness must handle absent saved state and omitted false preferences');
  assert.equal(wait[1], "$null -ne $state -and $state.tabs[$initialTab].PSObject.Properties['cv'] -and $state.tabs[$initialTab].cv");
  const evaluate = new Function('state', `return Boolean(${wait[1]
    .replaceAll('$null', 'null').replaceAll('$state', 'state').replaceAll('[$initialTab]', '[0]')
    .replace("state.tabs[0].PSObject.Properties['cv']", "Object.hasOwn(state.tabs[0], 'cv')")
    .replaceAll(' -ne ', ' !== ').replaceAll(' -and ', ' && ')});`);
  assert.equal(evaluate(null), false);
  for (const saved of [{}, { cv: false }, { cv: true }]) {
    const tab = new Proxy(saved, { get(target, key) {
      assert.ok(Object.hasOwn(target, key), `StrictMode read of missing ${key}`);
      return target[key];
    } });
    assert.equal(evaluate({ tabs: [tab] }), saved.cv === true);
  }
}

journeyOptionalChatContract(driver);
for (const [before, after] of [
  ["$state.tabs[$initialTab].PSObject.Properties['cv'] -and ", ''],
  [' -and $state.tabs[$initialTab].cv', ''],
  ['$null -ne $state -and $state.tabs[$initialTab]', '$state.tabs[$initialTab]'],
]) {
  const broken = driver.replace(before, after);
  assert.notEqual(broken, driver, `mutation applies: ${before}`);
  assert.throws(() => journeyOptionalChatContract(broken), assert.AssertionError);
}

function workspaceLayoutContract(source) {
  const pills = source.slice(source.indexOf('function Click-WorkspacePill('), source.indexOf('function Focus-Palette('));
  const focus = source.slice(source.indexOf("        'workspace-focus' {"), source.indexOf("        'chat-view' {"));
  const conditions = [pills, focus].map(text => {
    const expression = text.split('\n').find(line => line.includes("$state.PSObject.Properties['hide_pills'] -and"));
    assert.ok(expression, 'saved pill visibility must remain required');
    for (const field of ['hide_sidebar', 'sidebar_collapsed']) {
      assert.ok(expression.includes(`-not ($state.PSObject.Properties['${field}'] -and $state.${field})`), `${field} must default to false without an absent-property read`);
    }
    return expression;
  });
  assert.ok(conditions[0].includes("Where-Object { $_.PSObject.Properties['snoozed'] -and $_.snoozed }).Count -eq 0"));
  assert.ok(conditions[0].includes("-not $state.PSObject.Properties['ui_scale'] -or $state.ui_scale -eq 100"));
  const evaluate = conditions.map(expression => new Function('state', 'workspace', `return ${expression
    .replace(/@\(\$state.workspaces \| Where-Object \{ (.*?) \}\).Count/g, 'state.workspaces.filter(item => $1).length')
    .replace(/(\$state|\$_)\.PSObject.Properties\['(\w+)'\]/g, (_, object, field) => `Object.hasOwn(${object === '$state' ? 'state' : 'item'}, '${field}')`)
    .replace(/\$state\b/g, 'state').replace(/\$_\b/g, 'item').replace(/\$Workspace\b/g, 'workspace').replace(/\$null\b/g, 'null')
    .replace(/-not /g, '!').replace(/ -and /g, ' && ').replace(/ -or /g, ' || ')
    .replace(/ -eq /g, ' === ').replace(/ -ne /g, ' !== ').replace(/ -ge /g, ' >= ').replace(/ -lt /g, ' < ')};`));
  const strict = object => new Proxy(object, {
    get(target, key) {
      assert.ok(Object.hasOwn(target, key), `StrictMode read of missing ${key}`);
      return target[key];
    },
  });
  const check = (saved, workspace, expected) => {
    const state = saved === null ? null : strict({ ...saved, workspaces: saved.workspaces.map(strict) });
    assert.deepEqual(evaluate.map(test => Boolean(test(state, workspace))), expected);
  };
  const visible = { hide_pills: false, single_window: true, workspace_count: 1, workspaces: [{}] };
  check(null, 0, [false, false]);
  check(visible, 0, [true, true]);
  for (const field of ['hide_sidebar', 'sidebar_collapsed', 'hide_pills']) {
    check({ ...visible, [field]: false }, 0, [true, true]);
    check({ ...visible, [field]: true }, 0, [false, false]);
  }
  const { hide_pills, ...unsaved } = visible;
  check(unsaved, 0, [false, false]);
  check({ ...visible, single_window: false }, 0, [false, true]);
  for (const workspace of [-1, 1]) check(visible, workspace, [false, true]);
  for (const scale of [0, 80, 100, 110, 150]) check({ ...visible, ui_scale: scale }, 0, [scale === 100, true]);
  for (const snoozed of [false, true]) check({ ...visible, workspaces: [{ snoozed }] }, 0, [!snoozed, true]);
}

workspaceLayoutContract(driver);
for (const [before, after] of [
  ["$state.PSObject.Properties['hide_sidebar'] -and ", ''],
  ["$state.PSObject.Properties['sidebar_collapsed'] -and ", ''],
  ["$_.PSObject.Properties['snoozed'] -and ", ''],
  ["-not $state.PSObject.Properties['ui_scale']", '-not $state.ui_scale'],
  ["-not ($state.PSObject.Properties['hide_sidebar'] -and $state.hide_sidebar)", '$true'],
  ["-not ($state.PSObject.Properties['sidebar_collapsed'] -and $state.sidebar_collapsed)", '$true'],
  [' -and $_.snoozed', ''],
  ['$state.ui_scale -eq 100', '$state.ui_scale -ge 0'],
  ['.Count -eq 0', '.Count -ge 0'],
]) {
  const broken = driver.replaceAll(before, after);
  assert.notEqual(broken, driver, `mutation applies: ${before}`);
  assert.throws(() => workspaceLayoutContract(broken), assert.AssertionError, `reject optional layout regression: ${before}`);
}
const session = read('src/session.zig');
for (const [field, variable] of [['hide_sidebar', 'g_hide_sidebar'], ['sidebar_collapsed', 'g_sidebar_collapsed'], ['snoozed', 'g_ws_snoozed[wi]']]) {
  assert.ok(session.includes(`if (app_state.${variable}) {\n`));
  assert.ok(session.includes(`\\"${field}\\":true`));
}
assert.ok(session.includes('if (app_state.g_ui_scale != 100 and pos + 24 < json_buf.len)'));

nativePaletteFocusContract(driver);
for (const [before, after] of [
  ['GetFocusedWindow($script:window) -eq $script:window', 'GetForegroundWindow() -eq $script:window'],
  ['GetFocusedWindow($script:window) -eq $script:window', 'GetFocusedWindow($script:window) -ne [IntPtr]::Zero'],
  ['GetWindowThreadProcessId(hwnd, out pid)', 'GetCurrentThreadId()'],
  ['if (thread == 0) throw', 'if (thread == 0) return'],
  ['info.Size = (uint)Marshal.SizeOf(typeof(GuiThreadInfo));', ''],
  ['if (!GetGUIThreadInfo(thread, ref info)) throw', 'if (!GetGUIThreadInfo(0, ref info)) throw'],
  ['return info.Focus;', 'return info.Active;'],
  ['return info.Focus;', 'SetFocus(hwnd); return info.Focus;'],
  [' -and [VerifyNative]::GetForegroundWindow() -eq $script:window', ''],
  ["Save-Json $focus ($Name + '.focus.json')", ''],
]) {
  const broken = driver.replace(before, after);
  assert.notEqual(broken, driver, `mutation applies: ${before}`);
  assert.throws(() => nativePaletteFocusContract(broken), assert.AssertionError, `reject focus regression: ${before}`);
}
const workflow = read('.github/workflows/verify.yml');
assert.ok(workflow.includes('      - tools/check-workspace-focus.mjs'));
assert.ok(workflow.includes('run: node tools/check-workspace-focus.mjs'));
function authorizationLifetimeContract(focus, shortcuts, main) {
  const clears = /app_state\.g_focus_authorized_hwnd = null;\s*app_state\.g_focus_authorized_until = 0;\s*app_state\.g_focus_browser_shell_id = 0;/;
  const landed = focus.slice(focus.indexOf('fn focusGuardLanded('), focus.indexOf('pub noinline fn AttachThreadInput('));
  assert.match(landed, /now <= app_state\.g_focus_authorized_until and \(hwnd == app_state\.g_focus_authorized_hwnd or requested_pane\)/);
  assert.match(landed, /app_state\.g_focus_return_hwnd = focusGuardSurface\(hwnd\);/);
  assert.match(landed.slice(landed.indexOf('app_state.g_focus_return_hwnd = focusGuardSurface(hwnd);')), clears, 'landing consumes the handoff, not just its remembered return surface');
  const injected = shortcuts.slice(shortcuts.indexOf('} else if ((wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and'), shortcuts.indexOf('        const find_key_up ='));
  assert.match(injected.slice(0, injected.indexOf('app_state.g_focus_user_action_tick = GetTickCount64();')), clears, 'new owned injected shortcuts supersede stale handoffs before dispatch');
  assert.match(injected, /foregroundIsOurs\(\)/);
  assert.doesNotMatch(injected, /focusGuardNoteInput|g_focus_input_tick =|g_focus_return_hwnd =/);
  const open = main.slice(main.indexOf('        WM_APP_SEARCH_OPEN => {'), main.indexOf('        WM_APP_SEARCH_CLOSE => {'));
  assert.match(open.slice(0, open.indexOf('if (app_state.g_all_sessions_active)')), clears, 'all palette entry paths clear old authority before any guarded activation');
  const input = focus.slice(focus.indexOf('pub fn focusGuardNoteInput('), focus.indexOf('pub fn focusGuardReadMouse('));
  assert.match(input, clears, 'physical shortcuts also cancel old authority');
}

authorizationLifetimeContract(focusSource, shortcuts, main);
for (const [index, before] of [
  [0, 'app_state.g_focus_authorized_hwnd = null;'],
  [0, 'app_state.g_focus_authorized_until = 0;'],
  [0, 'app_state.g_focus_browser_shell_id = 0;'],
  [1, 'app_state.g_focus_authorized_hwnd = null;'],
  [1, 'app_state.g_focus_authorized_until = 0;'],
  [1, 'app_state.g_focus_browser_shell_id = 0;'],
  [2, 'app_state.g_focus_authorized_hwnd = null;'],
  [2, 'app_state.g_focus_authorized_until = 0;'],
  [2, 'app_state.g_focus_browser_shell_id = 0;'],
]) {
  const sources = [focusSource, shortcuts, main];
  const start = sources[index].indexOf(index === 0 ? 'fn focusGuardLanded(' : index === 1 ? '} else if ((wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and' : '        WM_APP_SEARCH_OPEN => {');
  const broken = sources[index].slice(0, start) + sources[index].slice(start).replace(before, '');
  assert.notEqual(broken, sources[index]);
  sources[index] = broken;
  assert.throws(() => authorizationLifetimeContract(...sources), assert.AssertionError, `reject stale authorization: ${index} ${before}`);
}
console.log('workspace-focus static checks passed (owned injected shortcut authority, strict optional journey reads, exact native focus, read-only waits, negative controls; Windows CI still required)');
