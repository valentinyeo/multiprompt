const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const source = fs.readFileSync(path.join(__dirname, '../.claude/skills/verify-multiprompt/settings-panel.ps1'), 'utf8');
const start = source.indexOf('function Click-Setting(');
const end = source.indexOf('\nfunction Open-Settings', start);
assert.ok(start >= 0 && end > start);
const click = source.slice(start, end);

test('settings clicks bring the target into view through bounded native Tab focus', () => {
  assert.match(click, /for \(\$attempt = 0; \$attempt -lt 12 -and -not \$element\.Current\.HasKeyboardFocus; \$attempt\+\+\)/);
  assert.match(click, /Press @\(0x09\)/);
  assert.match(click, /if \(-not \$element\.Current\.HasKeyboardFocus\) \{ throw/);
  assert.ok(click.indexOf('HasKeyboardFocus') < click.indexOf('GetClientRect'));
  assert.ok(click.indexOf('GetClientRect') < click.indexOf('[VerifyNative]::ClickClient'));
});

test('key verification saves an unset key and replaces it before opening Chat View', () => {
  const outside = source.slice(source.indexOf('    Remove-ItemProperty'), source.indexOf("    Snapshot 'settings-backdrop'"));
  assert.match(outside, /Fill-SettingKey 'Dictation key' 'settings-cancelled' -Cancel/);
  assert.match(outside, /Paste wrapped synthetic key/);
  assert.match(outside, /Wrapped key was not normalized before persistence/);
  assert.match(outside, /Fill-SettingKey 'Dictation key' 'settings-dictation-before-zzzzzzzzzz'/);
  assert.match(outside, /savedAndReplaced = \$true; chatOpened = \$false/);
  assert.ok(outside.indexOf('settings-key-outside-chat') < outside.indexOf("'Alt+C: show the chat behind Settings'"));
});

test('actual Settings click function handles scrolled, focused and unreachable controls', t => {
  const available = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', 'exit 0'], { encoding: 'utf8', timeout: 30000 });
  if (available.error?.code === 'ENOENT') return t.skip('PowerShell execution is covered on hosted Windows');
  assert.equal(available.status, 0, available.stderr);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'settings-focus-'));
  try {
    const file = path.join(dir, 'focus.ps1');
    fs.writeFileSync(file, `$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
public static class VerifyNative {
    public struct Rect { public int Left, Top, Right, Bottom; }
    public static bool Visible;
    public static int Clicks;
    public static bool GetClientRect(IntPtr handle, out Rect rect) {
        rect = new Rect { Right = 100, Bottom = 20 };
        return handle == new IntPtr(7);
    }
    public static void ClickClient(IntPtr handle, int x, int y) {
        if (!Visible || handle != new IntPtr(7) || x != 50 || y != 10)
            throw new InvalidOperationException("Control is outside the owned visible area");
        Clicks++;
    }
}
'@
$script:settingsWindow = [IntPtr]3
function Doctor {}
function Assert-Foreground {}
function Record([string]$Text) {}
function Settings-Control([string]$Name, [IntPtr]$RootWindow) { return $script:element }
function Press($Keys, [string]$Text) {
    if ($Keys.Count -ne 1 -or $Keys[0] -ne 9) { throw 'Expected actual Tab navigation' }
    $script:tabs++
    if ($script:tabs -eq $script:focusAfter) {
        $script:element.Current.HasKeyboardFocus = $true
        [VerifyNative]::Visible = $true
    }
}
${click}
function Reset([bool]$Focused, [int]$After) {
    $script:tabs = 0
    $script:focusAfter = $After
    $script:element = [pscustomobject]@{ Current = [pscustomobject]@{ NativeWindowHandle = 7; HasKeyboardFocus = $Focused } }
    [VerifyNative]::Visible = $Focused
    [VerifyNative]::Clicks = 0
}
Reset $false 3
Click-Setting 'Theme'
if ($script:tabs -ne 3 -or [VerifyNative]::Clicks -ne 1) { throw 'Scrolled control was not focused before clicking' }
Reset $true 99
Click-Setting 'Save' ([IntPtr]4)
if ($script:tabs -ne 0 -or [VerifyNative]::Clicks -ne 1) { throw 'Already focused control was disturbed' }
Reset $false 99
$refused = $false
try { Click-Setting 'Missing focus' } catch {
    if ($_.ToString() -notmatch 'did not receive keyboard focus') { throw }
    $refused = $true
}
if (!$refused -or $script:tabs -ne 12 -or [VerifyNative]::Clicks -ne 0) { throw 'Unreachable focus must fail without clicking' }
Write-Output 'FOCUS_VERIFIED scrolled focused unreachable'
`);
    const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', file], { encoding: 'utf8', timeout: 60000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stdout, /FOCUS_VERIFIED scrolled focused unreachable/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
