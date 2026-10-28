const test = require('node:test');
const assert = require('node:assert/strict');
const { readControlSource } = require('./app-source');
assert.equal(typeof readControlSource, 'function', 'Control readers must follow physical feature files');
const fs = require('node:fs');
const path = require('node:path');
const read = name => (name.endsWith('control.ps1') ? readControlSource() : fs.readFileSync(path.join(__dirname, '..', name), 'utf8'));
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

test('IGSH-1000 maximized client content excludes the native invisible resize borders', () => {
  const frame = read('src/window_frame.zig');
  assert.match(frame, /client.top = @max\(client.top, monitor.rcWork.top\)/);
  assert.match(frame, /client.bottom = @min\(client.bottom, monitor.rcWork.bottom\)/);
  assert.match(journey, /Abs\(\$pixels.captionInset\) -gt 1 -or -not \$pixels.clientInsideWorkArea/);
  assert.match(native, /origin.Y, client.Right, client.Bottom[\s\S]*monitor.Work.Left, monitor.Work.Top/);
});

test('IGSH-1000 window hit areas follow monitor DPI, not smaller chat content settings', () => {
  const frame = read('src/window_frame.zig');
  const geometry = frame.slice(frame.indexOf('fn frameScaled('), frame.indexOf('fn buttonAt('));
  assert.match(geometry, /mainWindowDpi\(\)/);
  assert.doesNotMatch(geometry, /g_ui_scale|drawing.zig/);
  assert.match(frame, /window control hit areas do not shrink with the app content scale/);
});

test('IGSH-1000 the header reads the current theme before drawing its existing title', () => {
  const drawing = read('src/drawing.zig');
  const title = drawing.slice(drawing.indexOf('fn paintChatTitlePill('), drawing.indexOf('pub fn paintThreadTitle('));
  assert.ok(title.indexOf('refreshChatBrushes();') >= 0);
  assert.ok(title.indexOf('refreshChatBrushes();') < title.indexOf('const fill = app_state.g_chat_input_color;'));
  assert.match(journey, /titleInkPixels -lt 8/);
  assert.match(native, /Delta\(image.GetPixel\(x, y\), fill\) > 80/);
});

test('IGSH-1124 maximize readiness rejects transitional client geometry before the next click', t => {
  const { spawnSync } = require('node:child_process');
  const shell = process.env.PWSH || (process.platform === 'win32' ? 'powershell.exe' : 'pwsh');
  const available = spawnSync(shell, ['-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()'], { encoding: 'utf8' });
  if (available.error?.code === 'ENOENT' && !process.env.CI) return t.skip('PowerShell behavior runs on hosted CI');
  assert.equal(available.status, 0, available.stdout + available.stderr);
  const ready = [0, 0, 1942, 1030, 0, 0, 1920, 1008, 144, 47, 0, 0, 1920, 1008, 1];
  const cases = [
    { name: 'restored frame with early maximized flag', zoomed: true, geometry: [50, 50, 1010, 750, 50, 50, 960, 700, 144, 47, 0, 0, 1920, 1008, 1], accepted: false },
    { name: 'client width still restored', zoomed: true, geometry: ready.with(6, 960), accepted: false },
    { name: 'client height still restored', zoomed: true, geometry: ready.with(7, 700), accepted: false },
    { name: 'native flag not maximized', zoomed: false, geometry: ready, accepted: false },
    { name: 'settled maximized client', zoomed: true, geometry: ready, accepted: true },
    { name: 'settled secondary monitor client', zoomed: true, geometry: [1910, -10, 3860, 1050, 1920, 0, 1920, 1040, 144, 47, 1920, 0, 3840, 1040, 1], accepted: true },
  ];
  for (const label of ['custom maximize button maximizes', 'double-clicking the top strip maximizes', 'custom maximize works while the docked browser has focus']) {
    const predicate = journey.match(new RegExp(`Wait-Until \\{([^{}]*)\\} '${label}'`))?.[1];
    assert.ok(predicate, `Missing maximize predicate: ${label}`);
    const script = `
$ErrorActionPreference = 'Stop'
Add-Type @'
public static class VerifyNative {
    public static bool Zoomed;
    public static bool IsZoomed(System.IntPtr window) { return Zoomed; }
}
public static class WindowControlsProof {
    public static int[] Current;
    public static int[] Geometry(System.IntPtr window) { return Current; }
}
'@
$script:window = [IntPtr]42
$cases = ConvertFrom-Json @'
${JSON.stringify(cases)}
'@
$results = @(foreach ($case in $cases) {
    [VerifyNative]::Zoomed = $case.zoomed
    [WindowControlsProof]::Current = [int[]]$case.geometry
    @{ name = $case.name; accepted = [bool](& { ${predicate} }) }
})
ConvertTo-Json -InputObject $results -Compress
`;
    const result = spawnSync(shell, ['-NoProfile', '-EncodedCommand', Buffer.from(script, 'utf16le').toString('base64')], { encoding: 'utf8', timeout: 30000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.deepEqual(JSON.parse(result.stdout.trim()), cases.map(({ name, accepted }) => ({ name, accepted })), label);
  }
});
