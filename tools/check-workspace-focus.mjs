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
  assert.match(open, /if \(wp == 1 and foregroundIsOurs\(\)\) \{\s*cancelShellRefocus\(hwnd\);/);
  assert.match(open, /const fg_thread = GetWindowThreadProcessId\(fg, null\);/);
  assert.match(open, /AttachThreadInput\(our_thread, fg_thread, 1\) != 0;\s*_ = SetForegroundWindow\(hwnd\);\s*_ = SetFocus\(hwnd\);\s*if \(attached\) _ = AttachThreadInput\(our_thread, fg_thread, 0\);/);
  assert.match(open, /cancelShellRefocus\(hwnd\);\s*app_state\.g_search_active = true;/);
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
  ['main', '_ = SetForegroundWindow(hwnd);\n                _ = SetFocus(hwnd);', '_ = SetFocus(hwnd);'],
  ['main', 'if (attached) _ = AttachThreadInput(our_thread, fg_thread, 0);', ''],
  ['main', 'const SetForegroundWindow = @import("focus.zig").SetForegroundWindow;', 'const SetForegroundWindow = @import("win32.zig").SetForegroundWindow;'],
]) {
  const source = file === 'shortcuts' ? shortcuts : main;
  const broken = source.replace(before, after);
  assert.notEqual(broken, source, `mutation applies: ${before}`);
  assert.throws(() => appPaletteFocusContract(file === 'shortcuts' ? broken : shortcuts, file === 'main' ? broken : main), assert.AssertionError, `reject palette activation regression: ${before}`);
}

function workspaceLayoutContract(source) {
  const pills = source.slice(source.indexOf('function Click-WorkspacePill('), source.indexOf('function Focus-Palette('));
  const focus = source.slice(source.indexOf("        'workspace-focus' {"), source.indexOf("        'inbox' {"));
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
console.log('workspace-focus static checks passed (guarded palette activation, strict optional layout reads, exact native focus, read-only waits, negative controls; Windows CI still required)');
