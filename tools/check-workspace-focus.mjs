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
console.log('workspace-focus static checks passed (exact native focus, read-only waits, negative controls; Windows CI still required)');
