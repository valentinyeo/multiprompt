const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
const base = '.claude/skills/verify-multiprompt/';
const workflow = read('.github/workflows/verify.yml');
const control = read(base + 'control.ps1');
const native = read(base + 'title-bar-native.cs');

test('title-bar keeps real monitor DPI coverage while migrating to the app-owned controls journey', () => {
  assert.match(workflow, /caption-dpi:.*inputs.feature == 'title-bar'.*\[96,120,144\]/);
  assert.match(workflow, /caption-dpi:.*inputs.feature == 'window-controls'.*\[96,120,144\]/);
  assert.match(control, /Feature -in @\('title-bar', 'window-controls'\)[\s\S]*CaptionProof\]::SetDpi/);
  assert.match(control, /Feature -in @\('title-bar', 'window-controls'\) -and \('CaptionProof'/);
  assert.match(read(base + 'title-bar.ps1'), /Join-Path \$PSScriptRoot 'window-controls.ps1'/);
  assert.match(read(base + 'window-controls.ps1'), /\$dpi -ne \[int\]\$env:CAPTION_DPI/);
  assert.doesNotMatch(read(base + 'window-controls.ps1'), /WM_DPICHANGED|0x02E0|ui_scale\s*=/);
});

test('real 150 percent scale has enough logical desktop space and restores the runner display', () => {
  assert.match(native, /DisplayConfigSetDeviceInfo\(packet\) == 0/);
  assert.match(native, /Marshal.WriteInt32\(settings, 172, 1920\)/);
  assert.match(native, /Marshal.WriteInt32\(settings, 176, 1080\)/);
  assert.match(native, /ChangeDisplaySettings\(settings, 0\) == 0/);
  assert.match(native, /Marshal.Copy\(originalDisplay, 0, settings, originalDisplay.Length\)/);
  assert.match(control, /CaptionProof\]::RestoreDpi\(\)/);
});

test('browser masks retain existing stacking repair after live theme changes', () => {
  const pane = read('src/browser_pane.zig');
  const refresh = pane.slice(pane.indexOf('pub fn refreshBrowserEdgeMasks()'), pane.indexOf('pub fn armBrowserEdgeMaskRaise()'));
  assert.match(refresh, /positionBrowserEdgeMasks\(layout\);\n    raiseBrowserEdgeMasksZOrderOnly\(\);/);
});
