const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
const base = '.claude/skills/verify-multiprompt/';
const workflow = read('.github/workflows/verify.yml');
const control = read(base + 'control.ps1');
const journey = read(base + 'title-bar.ps1');
const native = read(base + 'title-bar-native.cs');

test('IGSH-845 dispatch uses six real monitor DPI and Chrome theme cases with separate evidence', () => {
  assert.match(workflow, /caption-dpi:.*inputs.feature == 'title-bar'.*\[96,120,144\]/);
  assert.match(workflow, /caption-browser-theme:.*inputs.feature == 'title-bar'.*\["light","dark"\]/);
  assert.match(workflow, /name: verify-.*format\('-\{0\}-\{1\}', env.CAPTION_DPI, env.CAPTION_BROWSER_THEME\)/);
  assert.match(control, /ValidateSet\([^\n]*'title-bar'/);
  assert.match(workflow, /FEATURE -notin @\([^\n]*'title-bar'/);
  assert.match(workflow, /ParseFile\("\$pwd\/\.claude\/skills\/verify-multiprompt\/title-bar.ps1"/);
  assert.match(workflow, /run: node --test[^\n]*tools\/title-bar.test.js/);
  assert.match(native, /DisplayConfigSetDeviceInfo\(packet\) == 0/);
  assert.match(journey, /\$geometry\[8\] -ne \$targetDpi/);
  assert.match(control, /CaptionProof\]::RestoreDpi\(\)/);
  assert.doesNotMatch(journey, /WM_DPICHANGED|0x02E0|ui_scale\s*=/);
});

test('IGSH-845 compares app caption against the same native set in both window modes after live theme changes', () => {
  assert.match(journey, /foreach \(\$mode in @\('restored', 'maximized'\)\)/);
  assert.match(journey, /foreach \(\$theme in @\('dark', 'light', 'amoled'\)\)/);
  assert.match(journey, /PaneWindow\(\$script:window\) -ne \$browser/);
  assert.match(journey, /Save-Json \$proofs 'caption-pixels.json'/);
  assert.match(native, /glyphs.Count == 3/);
  assert.match(native, /captionMismatches"\] == 0/);
  assert.match(native, /nonBlackBackgroundPixels"\] == 0/);
  assert.match(native, /greyBandPixels"\] == 0/);
  assert.match(native, /Delta\(expected, pixel\) > 8/);
  assert.match(native, /appMaskNonBlackPixels"\] == 0/);
  assert.match(native, /appMaskChromeDelta"\] > 8/);
  assert.match(native, /browserMaskChromeDelta"\] <= 10/);
  assert.match(native, /browserThemeObserved/);
  assert.match(journey, /\$color\[0\] -lt 235/);
});

test('IGSH-845 the identical pixel oracle rejects added faint duplicate glyphs and a grey caption band', () => {
  assert.match(native, /doubled.SetPixel\(x \+ shift, y \+ shift, Color.FromArgb\(96, 96, 96\)\)/);
  assert.match(native, /band.SetPixel\(x, bottom - 1, Color.FromArgb\(192, 192, 192\)\)/);
  assert.match(journey, /foreach \(\$defect in @\('doubled', 'band'\)\)/);
  assert.match(journey, /\$negative = \[CaptionProof\]::Measure\(/);
  assert.match(journey, /try \{ \[CaptionProof\]::Check\(\$negative\) \} catch/);
  assert.match(journey, /if \(-not \$rejected\) \{ throw/);
  assert.match(journey, /Exception.Message -notmatch 'caption doubled-pixel signature or non-black band'/);
});

test('IGSH-858 frame proof compares top and right bands with adjacent unobscured frame pixels in every theme', () => {
  assert.match(native, /referenceX = maskRect\[0\] -/);
  assert.match(native, /referenceY = maskRect\[3\] \+/);
  assert.match(native, /frameMismatches"\] == 0/);
  assert.match(journey, /CaptionProof\]::CheckFrame\(\$proof.pixels\)/);
});

test('IGSH-858 real 150 percent scale has enough logical desktop space and restores the runner display', () => {
  assert.match(native, /Marshal.WriteInt32\(settings, 172, 1920\)/);
  assert.match(native, /Marshal.WriteInt32\(settings, 176, 1080\)/);
  assert.match(native, /ChangeDisplaySettings\(settings, 0\) == 0/);
  assert.match(native, /Marshal.Copy\(originalDisplay, 0, settings, originalDisplay.Length\)/);
});

test('IGSH-858 native glyph counting excludes the DWM outline but pixel comparison retains it', () => {
  assert.match(native, /glyphTop = top \+ \(int\)Math.Ceiling\(2 \* scale\)/);
  assert.match(native, /glyphRight = right - \(int\)Math.Ceiling\(2 \* scale\)/);
  assert.match(native, /for \(int y = top; y < bottom; y\+\+\) \{[\s\S]*?for \(int x = left; x < right; x\+\+\)/);
});
