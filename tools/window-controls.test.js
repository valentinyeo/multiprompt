const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = name => fs.readFileSync(path.join(__dirname, '..', name), 'utf8');
const base = '.claude/skills/verify-multiprompt/';
const journey = read(base + 'window-controls.ps1');
const native = read(base + 'window-controls-native.cs');

test('IGSH-1000 records the native-caption red control before rejecting it', () => {
  assert.ok(journey.indexOf("'window-controls-baseline.json'") < journey.indexOf("throw 'IGSH-1000 native title bar"));
  assert.match(native, /AdjustWindowRectExForDpi\(ref native, 0x00CF0000/);
  assert.match(journey, /chatTop -gt \$existingChatInset \+ 1/);
  assert.match(journey, /existingChatInset = \[Math\]::Floor\(8 \* \$dpi \/ 96\) \+ \[Math\]::Floor\(6 \* \$dpi \/ 96\) \+ \[Math\]::Floor\(4 \* \$dpi \/ 96\)/);
});

test('IGSH-1000 input remains in the owned foreground frame and uses real mouse movement', () => {
  assert.match(native, /GetForegroundWindow\(\) != hwnd/);
  assert.match(native, /WindowFromPoint\(point\) != hwnd/);
  assert.match(native, /mouse_event\(2/);
  assert.match(native, /finally \{ mouse_event\(4/);
  assert.match(journey, /ClickClient[\s\S]*custom minimize button minimizes/);
  assert.match(journey, /WindowControlsProof\]::Drag[\s\S]*WindowControlsProof\]::DoubleClick/);
  assert.match(journey, /Win\+Left: snap[\s\S]*real resize-edge drag/);
  assert.match(journey, /WaitForExit\(15000\)/);
});

test('IGSH-1000 screenshots prove three glyphs and top-edge separator in both window modes and three themes', () => {
  assert.match(journey, /foreach \(\$mode in @\('restored', 'maximized'\)\)/);
  assert.match(journey, /foreach \(\$theme in @\('dark', 'light', 'amoled'\)\)/);
  assert.match(journey, /separatorTopPixels -ne 6/);
  assert.match(journey, /glyphPixels \| Where-Object \{ \$_ -lt 8 -or \$_ -gt 150 \}/);
  assert.match(journey, /-ne '8,9,20'/);
  assert.match(read(base + 'control.ps1'), /windowControls.closed -or -not \$process.HasExited/);
});
