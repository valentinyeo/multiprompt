const test = require('node:test');

const assert = require('node:assert/strict');
const { readControlSource } = require('./app-source');
assert.equal(typeof readControlSource, 'function', 'Control readers must follow physical feature files');
const fs = require('node:fs');
const path = require('node:path');
const { runInNewContext } = require('node:vm');
function featureMatrix(source) {
  assert.match(source, /fromJSON\(needs\.journeys\.outputs\.full\)/);
  return require('./verify-features.cjs').discoverFeatures();
}
const read = file => (file.endsWith('control.ps1') ? readControlSource() : fs.readFileSync(path.join(__dirname, '..', file), 'utf8'));
const base = '.claude/skills/verify-multiprompt/';
const control = read(base + 'control.ps1');
const workflow = read('.github/workflows/verify.yml');
const timing = read('src/switch_timing.zig');
const consoleSource = read('src/console.zig');
const browser = read('src/browser_pane.zig');
const journey = control.slice(control.indexOf("        'browser-switch-speed' {"), control.indexOf("        'browser-pane-locked' {"));
const native = control.slice(control.indexOf('    public static System.Diagnostics.Stopwatch BeginSessionSwitch()'), control.indexOf('    [DllImport("user32.dll")] static extern int GetSystemMetrics'));

function assertsNative(source) {
  for (const input of [
    'inputs[0].data.keyboard = new Keyboard { key = 0x11 }',
    'inputs[1].data.keyboard = new Keyboard { key = 0x09 }',
    'inputs[2].data.keyboard = new Keyboard { key = 0x09, flags = 2 }',
    'inputs[3].data.keyboard = new Keyboard { key = 0x11, flags = 2 }',
  ]) assert.ok(source.includes(input));
  assert.match(source, /Stopwatch.StartNew\(\);\s+if \(SendInput/);
  for (const condition of [
    'GetForegroundWindow() != console', 'GetAncestor(console, 2) != owner', '!IsWindowVisible(console)',
    'Class(console) != "ConsoleWindowClass"', '!Title(console).EndsWith(suffix, StringComparison.Ordinal)',
    'GetProp(browser, "ZigShellPaneOwner") != owner', '!IsWindowVisible(browser)', '!GetWindowRect(browser, out actual)',
    'actual.Left != dock.Left', 'actual.Top != dock.Top', 'actual.Right != dock.Right', 'actual.Bottom != dock.Bottom',
    'else if (PaneVisible(owner)) return false;', 'GetForegroundWindow() != owner', '!IsWindowVisible(composer)',
    'GetAncestor(composer, 2) != owner', 'GetFocusedWindow(owner) != composer', 'EditText(composer) != draft',
  ]) assert.ok(source.includes(condition), condition);
  const measure = source.slice(source.indexOf('public static double[] MeasureSessionSwitch'));
  assert.match(measure, /Bitmap\(3, 3\)[\s\S]*double visible = -1;[\s\S]*var timer = BeginSessionSwitch\(\);/);
  assert.match(measure, /if \(SwitchReady\(owner, console, suffix, browser, dock, composer, draft\)\)/);
  assert.match(measure, /if \(visible < 0\) visible = timer.Elapsed.TotalMilliseconds;/);
  assert.match(measure, /if \(painted < 0 && Painted\(dock, rgb, patch, pixels, graphics\)\) painted = timer.Elapsed.TotalMilliseconds;/);
  assert.match(measure, /if \(painted >= 0 && \(!frozen \|\| awake >= 0\)\) \{\s+timer.Stop\(\);\s+return new double\[\] \{ painted, visible, awake \};/);
  assert.match(measure, /Thread.Sleep\(1\);[\s\S]*timer.ElapsedMilliseconds < 20000/);
  assert.doesNotMatch(source, /AutomationElement|SetForegroundWindow|::Chord|SendMessage\(|PostMessage|DwmFlush/);
}

test('timed input and native polling stay in one call without UIA or PowerShell dispatch latency', () => {
  assertsNative(native);
  for (const before of ['GetForegroundWindow() != console', '!IsWindowVisible(console)', '!Title(console).EndsWith(suffix, StringComparison.Ordinal)', 'GetProp(browser, "ZigShellPaneOwner") != owner', 'actual.Left != dock.Left', 'EditText(composer) != draft', 'timer.Stop();', 'Thread.Sleep(1);', 'Painted(dock, rgb, patch, pixels, graphics)']) {
    assert.throws(() => assertsNative(native.replaceAll(before, 'false')));
  }
  const sample = journey.slice(journey.indexOf('$measurement ='), journey.indexOf("$pattern = 'switch-timing"));
  assert.match(sample, /MeasureSessionSwitch\(\$script:window, \$consoles\[\$target\], \('ZigShell-' \+ \$shellIds\[\$target\]\), \$browsers\[\$target\], \$docks\[\$target\], \$composerHandle, \$drafts\[\$target\], \$paintRgb\[\$target\], \$frozenMarker, \$paintPatch\[\$target\]\)/);
  assert.match(sample, /samples_ms\[\$sample\] = \$measurement\[0\]/);
  assert.match(sample, /window_visible_ms\[\$sample\] = \$measurement\[1\]/);
  assert.ok(sample.indexOf('Wait-WorkspaceSurface') > sample.indexOf('window_visible_ms'));
});

function assertsPaint(source, driver) {
  assert.match(source, /dock.Bottom - dock.Top < 200/);
  assert.match(source, /int x = dock.Left \+ \(dock.Right - dock.Left\) \/ 2;/);
  assert.match(source, /int y = dock.Top \+ \(dock.Bottom - dock.Top\) \* 3 \/ 4;/);
  assert.match(source, /BitBlt\(target, 0, 0, pixels.Width, pixels.Height, screen, x, y, 0x00CC0020\)/);
  assert.doesNotMatch(source.slice(source.indexOf('static void ReadPatch'), source.indexOf('public static double[] MeasureSessionSwitch')), /CopyFromScreen/);
  assert.match(source, /row < pixels.Height/);
  assert.match(source, /col < pixels.Width/);
  for (const channel of ['R', 'G', 'B']) assert.match(source, new RegExp(`Math.Abs\\(pixel\\.${channel} - [^;]+ > 8`));
  assert.match(driver, /\$colors = @\('#db2855', '#26b8d4'\)/);
  assert.match(driver, /\$rgb = @\(0xDB2855, 0x26B8D4\)/);
  assert.match(driver, /html,body\{margin:0;width:100%;height:100%;background:/);
  assert.match(driver, /Palette 'jump browser'/);
  assert.match(driver, /GetForegroundWindow\(\) -eq \$browser/);
  assert.match(driver, /DockedPaneWindow\(\$script:window\) -ne \$browser/);
  assert.match(driver, /::Chord\(@\(0x11, 0x4C\)\)/);
  assert.match(driver, /\$pageUrl = 'data:text\/html,' \+ \[Uri\]::EscapeDataString\(\$html\)/);
  assert.match(driver, /::Text\(\$pageUrl\)/);
  assert.match(driver, /::Chord\(@\(0x0D\)\)/);
  assert.match(driver, /PagePainted\(\$dock, \$rgb\[\$tab\]\)/);
  assert.match(driver, /PagePainted\(\$docks\[0\], \$paintRgb\[0\], \$paintPatch\[0\]\)/);
}

function assertsOffProbe(source, driver) {
  assert.doesNotMatch(source, /CopyFromScreen/);
  const measure = source.slice(source.indexOf('public static double[] MeasureSessionSwitch'));
  assert.doesNotMatch(measure, /browser == IntPtr.Zero \|\|/);
  assert.match(measure, /Painted\(dock, rgb, patch, pixels, graphics\)/);
  for (const literal of [
    "$consoleCodes = @('1F', '2F')",
    "Type-Text ('color ' + $consoleCodes[$tab])",
    '[VerifyNative]::SolidPatch($consoleArea)',
    '$docks[$tab] = $consoleArea',
    '$paintRgb = if ($browserOn) { $rgb } else { $consoleRgb }',
    "$paintPatch = if ($mode -eq 'chat_browser_off') { $patches } else { @($null, $null) }",
    '$regions[$tab] = [VerifyNative]::CaptureComposerStart($composerHandle)',
    '$patches = [VerifyNative]::CalibratePatches($regions[0], $regions[1])',
    "throw 'Timing console colors are not distinct'",
  ]) assert.ok(driver.includes(literal), literal);
  assert.doesNotMatch(driver, /if \(\$browserOn\) \{ Wait-Until \{ \[VerifyNative\]::PagePainted/);
  assert.match(driver, /Wait-Until \{ \[VerifyNative\]::PagePainted\(\$docks\[0\], \$paintRgb\[0\], \$paintPatch\[0\]\) \} 'first session color before measurement'/);
  const drafts = driver.match(/\$drafts = @\('([^']+)', '([^']+)'\)/).slice(1);
  assert.notEqual(drafts[0][0], drafts[1][0]);
}

test('browser-off waits on a target-specific pixel read by the same BitBlt probe as browser-on', () => {
  assertsOffProbe(native, journey);
  assert.throws(() => assertsOffProbe(native.replace('if (painted < 0 && Painted(dock, rgb, patch, pixels, graphics))', 'if (painted < 0 && (browser == IntPtr.Zero || Painted(dock, rgb, patch, pixels, graphics)))'), journey));
  assert.throws(() => assertsOffProbe(native.replace('BitBlt(target, 0, 0, pixels.Width', 'graphics.CopyFromScreen(x, y, 0, 0, pixels.Size); BitBlt(target, 0, 0, pixels.Width'), journey));
  assert.throws(() => assertsOffProbe(native, journey.replaceAll('[VerifyNative]::SolidPatch($consoleArea)', '$plainRgb')));
  assert.throws(() => assertsOffProbe(native, journey.replace('$paintRgb = if ($browserOn) { $rgb } else { $consoleRgb }', '$paintRgb = $rgb')));
  assert.throws(() => assertsOffProbe(native, journey.replace("$drafts = @('Wswitch-paint-0', '.switch-paint-1')", "$drafts = @('switch-paint-0', 'switch-paint-1')")));
  assert.throws(() => assertsOffProbe(native, journey.replace("Wait-Until { [VerifyNative]::PagePainted($docks[0], $paintRgb[0], $paintPatch[0]) }", "if ($browserOn) { Wait-Until { [VerifyNative]::PagePainted($docks[0], $paintRgb[0], $paintPatch[0]) }")));
});

test('paint is an actual target-colored 3x3 screen patch below the toolbar, reached by real native omnibox input', () => {
  assertsPaint(native, journey);
  for (const before of ['BitBlt(target, 0, 0, pixels.Width, pixels.Height, screen, x, y, 0x00CC0020)', 'row < pixels.Height', 'col < pixels.Width', 'dock.Bottom - dock.Top < 200']) {
    assert.throws(() => assertsPaint(native.replace(before, 'false'), journey));
  }
  for (const before of ["Palette 'jump browser'", '0x26B8D4', 'width:100%;height:100%', 'PagePainted($dock, $rgb[$tab])']) {
    assert.throws(() => assertsPaint(native, journey.replace(before, 'false')));
  }
  const colors = journey.match(/\$rgb = @\(0x([0-9A-F]+), 0x([0-9A-F]+)\)/).slice(1).map(value => parseInt(value, 16));
  const matches = (a, b) => [16, 8, 0].every(shift => Math.abs(((a >> shift) & 255) - ((b >> shift) & 255)) <= 8);
  assert.equal(matches(colors[0], colors[1]), false);
  for (const target of colors) {
    assert.equal(matches(target, target), true);
    for (const wrong of [0, 0xffffff, colors.find(value => value !== target)]) assert.equal(matches(wrong, target), false);
  }
});

function assertsActivePage(source) {
  const steps = [
    "$browser = [VerifyNative]::DockedPaneWindow($script:window)",
    "Palette 'jump browser'",
    "GetProp($browser, 'ZigShellPaneOwner') -ne $script:window",
    'GetWindowThreadProcessId($browser, [ref]$browserPid)',
    'FocusOwnedWindow($browser, $browserPid, $script:window)',
    "throw 'Browser lost focus before Ctrl+L'",
    '::Chord(@(0x11, 0x4C))',
    'AutomationElement]::FromHandle($browser)',
    "ClassNameProperty, 'OmniboxViewViews'",
    '$omnibox.Current.HasKeyboardFocus',
    'Automation]::Compare($omnibox, [System.Windows.Automation.AutomationElement]::FocusedElement)',
    "'verified pane native address bar has keyboard focus'",
    "$pageTitle = 'Switch paint ' + $tab",
    "$pageUrl = 'data:text/html,' + [Uri]::EscapeDataString($html)",
    '::Text($pageUrl)',
    '$omnibox.Current.HasKeyboardFocus',
    '$omnibox.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value -ceq $pageUrl',
    "'complete color URL is in the focused pane address bar'",
    "throw 'Navigation browser ownership changed before Enter'",
    "throw 'Browser lost focus before navigation'",
    '::Chord(@(0x0D))',
    'DockedPaneWindow($script:window) -eq $browser',
    "Title($browser).StartsWith($pageTitle + ' ', [StringComparison]::Ordinal)",
    'PagePainted($dock, $rgb[$tab])',
    "'active pane tab is the color page and target session color visibly painted below the browser toolbar' -Tight",
    '$browsers[$tab] = $browser',
    '$docks[$tab] = $dock',
  ];
  let offset = -1;
  for (const step of steps) {
    const next = source.indexOf(step, offset + 1);
    assert.ok(next > offset, step);
    offset = next;
  }
  const setup = source.slice(source.indexOf('$browser = [VerifyNative]::DockedPaneWindow'), source.indexOf('$docks[$tab] = $dock'));
  assert.doesNotMatch(setup, /Seconds|Start-Sleep|SendMessage|PostMessage|SetValue|InvokePattern|SelectPattern|0x57|0x09/);
}

test('setup verifies the pane HWND, focused native omnibox, complete typed URL and active page before paint sampling', () => {
  assertsActivePage(journey);
  const activeTitle = title => title.startsWith('Switch paint 0 ');
  for (const title of ['Switch paint 0 - Microsoft Edge', 'Switch paint 0 and 1 more page - Profile 1 - Microsoft Edge']) assert.equal(activeTitle(title), true);
  for (const title of ['New tab and 1 more page - Profile 1 - Microsoft Edge', 'Switch paint 1 - Microsoft Edge', 'Switch paint 10 - Microsoft Edge']) assert.equal(activeTitle(title), false);
  for (const step of [
    'FocusOwnedWindow($browser, $browserPid, $script:window)',
    "ClassNameProperty, 'OmniboxViewViews'", '$omnibox.Current.HasKeyboardFocus',
    'Automation]::Compare($omnibox, [System.Windows.Automation.AutomationElement]::FocusedElement)',
    '.Current.Value -ceq $pageUrl', "throw 'Navigation browser ownership changed before Enter'",
    'DockedPaneWindow($script:window) -eq $browser',
    "Title($browser).StartsWith($pageTitle + ' ', [StringComparison]::Ordinal)",
    'PagePainted($dock, $rgb[$tab])',
  ]) assert.throws(() => assertsActivePage(journey.replaceAll(step, 'false')));
  assert.throws(() => assertsActivePage(journey.replace('::Text($pageUrl)', '::Chord(@(0x0D))').replace("Record 'Enter: show the synthetic full-viewport session color'", '::Text($pageUrl)')));
});

function assertsJourney(source) {
  assert.match(source, /\$modes = @\('browser_off', 'browser_on', 'frozen_browser_on', 'chat_browser_off', 'chat_browser_on', 'chat_frozen_browser_on'\)/);
  assert.match(source, /foreach \(\$mode in \$modes\)/);
  assert.match(source, /for \(\$sample = 0; \$sample -lt \$sampleCount; \$sample\+\+\)/);
  assert.match(source, /\$target = \(\$sample \+ 1\) % 2/);
  assert.match(source, /\$sampleCount = if \(\$mode.Contains\('frozen_'\)\) \{ 5 \} else \{ 20 \}/);
  assert.match(source, /\$sampleCount = \$timings\[\$mode\].samples_ms.Count/);
  assert.match(source, /samples_ms = @\(\$null\) \* \$sampleCount; median_ms = \$null; window_visible_ms = @\(\$null\) \* \$sampleCount; window_visible_median_ms = \$null/);
  assert.match(source, /\$pane = Open-BrowserPane/);
  assert.match(source, /\$pane.browser_state -eq 'connected'/);
  assert.match(source, /\$browsers\[0\] -eq \$browsers\[1\]/);
  assert.match(source, /@\(@\('browser_off', 'browser_on'\), @\('chat_browser_off', 'chat_browser_on'\), @\('browser_off', 'frozen_browser_on'\), @\('chat_browser_off', 'chat_frozen_browser_on'\)\)/);
  assert.match(source, /\$gap = \$timings\[\$pair\[1\]\].median_ms - \$timings\[\$pair\[0\]\].median_ms/);
  assert.ok(source.includes("foreach ($pair in $gaps) { Assert-ReleaseTiming 'browser-switch-gap' ([Math]::Max(0, $pair.gap_ms))"));
  assert.match(source, /name = 'switch-gap'; status = 'failed';[^\n]+phase = 'initial-console'/);
  assert.match(source, /catch \{\s+\$gapCase.detail = \$gapCase.phase \+ ': ' \+ \$_\.Exception.Message\s+throw\s+\} finally \{/);
  assert.match(source, /finally \{[\s\S]+Save-Json \$timings 'switch-timings.json'/);
  assert.match(source, /window_visible_median_ms = Get-SwitchMedian \$timings\[\$mode\].window_visible_ms/);
  assert.doesNotMatch(source, /SetForegroundWindow|SendMessage|PostMessage|Set-Content[^\n]*session.json|Start-Sleep/);
}

test('four warm twenty-sample and two frozen five-sample sets enforce all matching 50ms gaps and retain null failure evidence', () => {
  assertsJourney(journey);
  for (const [before, after] of [
    ['$sample -lt $sampleCount', '$sample -lt 2'], ['([Math]::Max(0, $pair.gap_ms))', '([Math]::Max(0, 0))'],
    ["$pane.browser_state -eq 'connected'", '$true'], ['finally {', 'if ($false) {'],
    ["name = 'switch-gap'; status = 'failed'", "name = 'switch-gap'; status = 'passed'"],
    ["@('chat_browser_off', 'chat_browser_on')", "@('browser_off', 'browser_on')"],
  ]) assert.throws(() => assertsJourney(journey.replace(before, after)));
  const gapLimit = JSON.parse(read('tools/release-gates.json')).checks['browser-switch-gap'].limit;
  for (const [off, on, fails] of [[10, 60, false], [10, 60.001, true], [100, 90, false]]) assert.equal(on - off > gapLimit, fails);
  const median = control.slice(control.indexOf('function Get-SwitchMedian'), control.indexOf('function Doctor'));
  assert.match(median, /foreach \(\$value in \$Values\) \{ if \(\$null -eq \$value\) \{ return \$null \} \}/);
  assert.match(median, /Sort-Object/);
  assert.match(median, /\(\[double\]\$sorted\[\$middle - 1\] \+ \[double\]\$sorted\[\$middle\]\) \/ 2/);
});

function assertsOptionalTrace(source) {
  assert.match(source, /\$timings.steps\[\$mode\] = \$null/);
  assert.match(source, /if \(\$traceMatches.Count -ne 1 -or \[int\]\$traceMatches\[0\].Groups\[1\].Value -ne \$target\) \{ throw "Sample was not exactly one app switch to session \$target;[^\n]+\}\s+\$line = \$traceMatches\[0\].Value/);
  assert.match(source, /\$pattern = 'switch-timing: to=\(\\d\+\) total_us=/);
  assert.match(source, /\$traces\[\$mode\] \+= \$steps/);
  assert.match(source, /\$traces\[\$mode\].Count -eq \$timings\[\$mode\].samples_ms.Count -and @\(\$traces\[\$mode\] \| Where-Object \{ \$null -eq \$_ \}\).Count -eq 0/);
  assert.match(source, /\$timings.steps\[\$mode\]\[\$step\] = Get-SwitchMedian \$values/);
  assert.match(source, /Save-Json \$traces 'switch-traces.json'/);
  assert.match(source, /switch-timing-debug.log/);
  assert.doesNotMatch(source, /matching per-switch debug timing|Incomplete switch-timing|Expected exactly one switch-timing|Wait-Until[^\n]*switch-timing/);
}

test('every sample must be exactly one app switch to its target, with null steps kept only as failure evidence', () => {
  assertsOptionalTrace(journey);
  for (const [before, after] of [
    ['$timings.steps[$mode] = $null', '$timings.steps[$mode] = @{}'],
    ['$traceMatches.Count -ne 1 -or ', ''],
    ['-ne $target) { throw "Sample was not exactly one app switch', '-ne $target) { Write-Host "Sample was not exactly one app switch'],
    ['[int]$traceMatches[0].Groups[1].Value -ne $target', '$false'],
    ["$traces[$mode] += $steps", "throw 'Expected exactly one switch-timing'"],
  ]) assert.throws(() => assertsOptionalTrace(journey.replace(before, after)), before);
});

function assertsSwitchStart(source, driver) {
  const start = source.slice(source.indexOf('public static void RequireSwitchStart'), source.indexOf('static bool PaintMatches'));
  for (const check of [
    'sourceConsole == targetConsole', 'sourceBrowser == targetBrowser && sourceBrowser != IntPtr.Zero', 'sourceSuffix == targetSuffix', 'sourceDraft == targetDraft',
    '!SwitchReady(owner, sourceConsole, sourceSuffix, sourceBrowser, sourceDock, composer, sourceDraft)',
    'if (SwitchReady(owner, targetConsole, targetSuffix, targetBrowser, targetDock, composer, targetDraft)) throw new InvalidOperationException("Target session is already visible before Ctrl+Tab',
    '!PagePainted(sourceDock, sourceRgb, sourcePatch)', 'PagePainted(targetDock, targetRgb, targetPatch)',
  ]) assert.ok(start.includes(check), check);
  const sample = driver.slice(driver.indexOf('for ($sample = 0;'), driver.indexOf('foreach ($mode in $modes) { $timings[$mode].median_ms'));
  assert.match(sample, /\$source = 1 - \$target\s+\[VerifyNative\]::RequireSwitchStart\(\$script:window, \$composerHandle, \$consoles\[\$source\], \('ZigShell-' \+ \$shellIds\[\$source\]\), \$browsers\[\$source\], \$docks\[\$source\], \$drafts\[\$source\], \$consoles\[\$target\], \('ZigShell-' \+ \$shellIds\[\$target\]\), \$browsers\[\$target\], \$docks\[\$target\], \$drafts\[\$target\], \$paintRgb\[\$source\], \$paintRgb\[\$target\], \$paintPatch\[\$source\], \$paintPatch\[\$target\]\)\s+Record \("Ctrl\+Tab timing/);
  assert.ok(sample.indexOf('RequireSwitchStart(') < sample.indexOf('$measurement ='));
  assert.ok(sample.indexOf('worker_finished_utc') < sample.indexOf('RequireSwitchStart('));
  assert.match(sample, /if \(\$frozenText -notmatch \('\(\?s\)browser freeze confirmed: ' \+ \$idPattern \+ '\.\*hook: Ctrl\\\+Tab shift=0 -> NEXT_TAB\.\*browser wake sent: ' \+ \$idPattern \+ '\.\*switchToShell: ' \+ \(1 - \$target\) \+ ' -> ' \+ \$target \+ ' '\)\) \{ throw "Frozen target/);
  assert.match(sample, /\$frozenText = \$debugAfter.Substring\(\$freeze.log_start\)/);
}

test('a sample whose target is already visible, whose source is not visible, or whose frozen target never woke fails the journey', () => {
  assertsSwitchStart(native, journey);
  for (const [before, after] of [
    ['sourceConsole == targetConsole || ', ''], ['|| sourceSuffix == targetSuffix', ''], ['|| sourceDraft == targetDraft', ''],
    ['if (!SwitchReady(owner, sourceConsole, sourceSuffix, sourceBrowser, sourceDock, composer, sourceDraft)) throw', 'if (false) throw'],
    ['if (SwitchReady(owner, targetConsole, targetSuffix, targetBrowser, targetDock, composer, targetDraft)) throw', 'if (false) throw'],
    ['if (!PagePainted(sourceDock, sourceRgb, sourcePatch)) throw', 'if (false) throw'],
    ['if (PagePainted(targetDock, targetRgb, targetPatch)) throw', 'if (false) throw'],
  ]) assert.throws(() => assertsSwitchStart(native.replace(before, after), journey), before);
  for (const [before, after] of [
    ['[VerifyNative]::RequireSwitchStart(', '[VerifyNative]::Chord('], ['$frozenText -notmatch', '$frozenText -match'],
    ['browser wake sent: ', 'browser wake: '], ['$source = 1 - $target', '$source = $target'],
  ]) assert.throws(() => assertsSwitchStart(native, journey.replace(before, after)), before);
  const wakeLog = id => ['browser freeze confirmed: shell=' + id + ' window=1 path=pipe', 'hook: Ctrl+Tab shift=0 -> NEXT_TAB', 'browser wake sent: shell=' + id + ' window=1 path=pipe queued', 'switchToShell: 1 -> 0 restoring=false'].join('\n');
  const pattern = id => new RegExp('browser freeze confirmed: shell=' + id + ' .*hook: Ctrl\\+Tab shift=0 -> NEXT_TAB.*browser wake sent: shell=' + id + ' .*switchToShell: 1 -> 0 ', 's');
  assert.equal(pattern(1).test(wakeLog(1)), true);
  assert.equal(pattern(2).test(wakeLog(1)), false);
  assert.equal(pattern(1).test(wakeLog(1).split('\n').slice(1).join('\n')), false);
  assert.equal(pattern(1).test(wakeLog(1).split('\n').filter(line => !line.includes('wake sent')).join('\n')), false);
});

test('console ordering stays grouped-first and Chat View uses real Alt+C with target-specific unsent drafts', () => {
  const steps = [
    '$initial = Read-Session', 'Wait-WorkspaceSurface $initial.active_workspace 0 $false',
    "Focus-Palette 'move to group' 6301", "Type-Text 'new group'", '$state.tabs[0].group_id -eq $state.groups[0].id',
    "Palette 'new cmd'", '@($state.tabs).Count -eq 2 -and $state.active_tab -eq 1',
    "(-not $state.tabs[1].PSObject.Properties['group_id'] -or $state.tabs[1].group_id -eq 0)",
    '$consoleTab = (Read-Session).active_tab', 'Wait-WorkspaceSurface $initial.active_workspace $consoleTab $false',
    '$shellIds = @($state.tabs[0].shell_id, $state.tabs[1].shell_id)',
    'Wait-WorkspaceSurface $initial.active_workspace $tab $false', '$consoles[$tab] = [VerifyNative]::GetForegroundWindow()',
    'foreach ($mode in $modes)',
  ];
  let offset = -1;
  for (const step of steps) { const next = journey.indexOf(step, offset + 1); assert.ok(next > offset, step); offset = next; }
  assert.match(journey, /Focus-Palette 'chat view off everywhere' 6347/);
  assert.ok(journey.includes("@($state.tabs | Where-Object { ($_.PSObject.Properties['cv'] -and $_.cv) -or $_.PSObject.Properties['chat_view_lock'] }).Count -eq 0"));
  assert.match(journey, /Press-CloseBrowserPane 'Alt\+A: close browser pane for Chat View baseline'\s+\$null = Assert-BrowserPane 'closed' \('chat-baseline-' \+ \$tab\)/);
  const closer = control.slice(control.indexOf('function Press-CloseBrowserPane'), control.indexOf('function Focus-BrowserPaneOwner'));
  assert.match(closer, /for \(\$attempt = 1; \$attempt -le 3; \$attempt\+\+\) \{\s+Press @\(0x12, 0x41\) \$Label\s+try \{\s+Wait-Until \{ \$pane = Read-BrowserPane; \$null -ne \$pane -and \$pane.browser_state -eq 'closed' \} "Alt\+A attempt \$attempt closed the browser pane" 3\s+return\s+\} catch \{ if \(\$attempt -eq 3\) \{ throw \} \}/);
  assert.throws(() => assert.match(closer.replace('-eq 3', '-eq 4'), /\$attempt -eq 3\) \{ throw/));
  assert.match(journey, /Press @\(0x12, 0x43\) 'Alt\+C:/);
  assert.match(journey, /Wait-Until \{ \(Read-Session\).tabs\[\$tab\].cv \}/);
  assert.match(journey, /Type-Text \$drafts\[\$tab\]/);
  assert.match(journey, /EditText\(\$composerHandle\) -ceq \$drafts\[\$tab\]/);
  assert.match(journey, /\$browsers\[\$tab\] = \[IntPtr\]::Zero/);
  assert.match(journey, /Wait-WorkspaceSurface \$initial.active_workspace 0 \$chat \(\$composerHandle.ToInt32\(\)\)/);
  assert.match(journey, /\$warmupStopped = \$warmupJob.Stop\(\)[\s\S]*\$warmupJob = \$null[\s\S]*\$pane = Open-BrowserPane/);
});

test('onscreen browser identity excludes visible parked HWNDs and records each view dock and color', () => {
  const docked = control.slice(control.indexOf('    public static IntPtr DockedPaneWindow'), control.indexOf('    public static System.Diagnostics.Stopwatch BeginSessionSwitch'));
  for (const check of ['GetProp(hwnd, "ZigShellPaneOwner") != owner', '!IsWindowVisible(hwnd)', 'rect.Right <= rect.Left', 'rect.Bottom <= rect.Top', 'rect.Left >= frame.Right', 'rect.Right <= frame.Left', 'rect.Top >= frame.Bottom', 'rect.Bottom <= frame.Top']) assert.ok(docked.includes(check));
  assert.match(journey, /\$docks\[\$tab\] = \$dock/);
  assert.match(journey, /consoleHwnd = \$consoles\[\$tab\].ToInt64\(\); browserHwnd = \$browsers\[\$tab\].ToInt64\(\); dock = \$docks\[\$tab\]; color = \$colors\[\$tab\]/);
  assert.match(journey, /Save-Json @\(\$identities\) \("\$mode-window-identities.json"\)/);
});

test('QPC tracing is debug-gated, thread-local and emits exactly one aggregate line per switch', () => {
  assert.match(timing, /threadlocal var active: \?\*Trace = null/);
  assert.match(timing, /if \(!diagnostics.verboseLoggingEnabled\(\)\) return previous;\s+_ = win.QueryPerformanceFrequency[\s\S]+QueryPerformanceCounter/);
  assert.match(timing, /if \(active == null\) return 0;\s+var now: i64 = 0;\s+_ = win.QueryPerformanceCounter/);
  assert.match(timing, /1_000_000, @max\(1, trace.frequency\)/);
  assert.equal((timing.match(/diagnostics.debugLog\(/g) || []).length, 1);
  assert.match(timing, /active = previous;/);
  assert.match(consoleSource, /pub fn switchToShell\(idx: u32\) void \{\s+var timing: switch_timing.Trace = .\{\};\s+const timing_previous = switch_timing.begin\(&timing\);\s+defer switch_timing.finish\(&timing, timing_previous, idx\);/);
  for (const step of ['console_shown', 'focus', 'reposition']) assert.ok(consoleSource.includes(`defer switch_timing.record(.${step}, timing_started);`));
  for (const [fn, step] of [['hideActiveBrowser', 'hide_prev_browser'], ['parkStrayBrowserPanes', 'park'], ['updateBrowserVisibility', 'browser_visible'], ['armBrowserVisibilitySettle', 'arm_settle'], ['positionActiveBrowser', 'position'], ['setBrowserWindowPosAsync', 'browser_swp'], ['showBrowserWindowAsync', 'browser_show'], ['spawnBrowserCliHidden', 'browser_launch'], ['launchBrowserForShellEx', 'browser_launch'], ['wakeBrowserPaneFromFreeze', 'browser_wake']]) {
    assert.match(browser, new RegExp(`fn ${fn}\\([^\\n]*\\) void \\{\\s+const timing_started = switch_timing.start\\(\\);\\s+defer switch_timing.record\\(\\.${step}, timing_started\\);`));
  }
  assert.match(timing, /switch-timing: to=\{d\} total_us=\{d\}/);
  assert.match(timing, /field.name \+\+ "_us=\{d\}"/);
});

function journeyMatrix(source, event, feature = '', ref = 'refs/heads/master', flags = {}) {
  const expression = source.match(/^        feature: \$\{\{ (.+) \}\}$/m);
  assert.ok(expression, 'journey matrix expression exists');
  const discovered = featureMatrix(source);
  return runInNewContext(expression[1], {
    needs: { journeys: { outputs: { pr: JSON.stringify(discovered.pr), full: JSON.stringify(discovered.full) } } },
    github: { event_name: event, ref },
    inputs: { feature, ...flags },
    fromJSON: JSON.parse,
    startsWith: (value, prefix) => value.startsWith(prefix),
    format: (pattern, value) => pattern.replace('{0}', value),
  }, { timeout: 1000 });
}

function assertsDispatchOnly(source) {
  for (const [event, feature] of [['pull_request', ''], ['push', ''], ['workflow_dispatch', 'all']]) {
    assert.equal(journeyMatrix(source, event, feature).includes('browser-switch-speed'), false);
  }
  assert.deepEqual(journeyMatrix(source, 'workflow_dispatch', 'browser-switch-speed'), ['browser-switch-speed']);
  assert.match(source, /workflow_dispatch:[\s\S]+feature:/);
  assert.match(source, /fromJSON\(format\('\["\{0\}"\]', inputs\.feature\)\)/);
  assert.match(source, /node tools\/verify-features.cjs \$env:FEATURE/);
  assert.ok(featureMatrix(source).available.includes('browser-switch-speed'));
}

test('IGSH-1033 master smoke stays small while release candidates retain feature-owned coverage', async () => {
  const { verifyPushBranches } = await import('./verify-workflow-branches.mjs');
  const full = ['appearance', 'chat-dictation', 'relaunch-saved-sessions', 'settings-panel', 'session-restore', 'workspace-focus', 'tmux-binding', 'favorites-groups', 'browser-pane-stuck', 'browser-pane-locked', 'group-rail', 'pane-layout', 'chat-view', 'chat-messages-only', 'chat-view-everywhere', 'chat-focus', 'browser-own-profile', 'status-card', 'palette-order', 'remind-me', 'chat-send-latency', 'chat-first-paint'];
  function contract(source) {
    verifyPushBranches(source);
    assert.deepEqual(journeyMatrix(source, 'pull_request'), featureMatrix(source).pr);
    assert.deepEqual(journeyMatrix(source, 'pull_request', 'all'), featureMatrix(source).pr);
    assert.deepEqual(journeyMatrix(source, 'push'), ['appearance', 'relaunch-saved-sessions']);
    for (const feature of full) assert.ok(journeyMatrix(source, 'push', 'all').includes(feature));
    assert.deepEqual(journeyMatrix(source, 'push', '', 'refs/heads/ceo/IGSH-1072-proof-1'), ['chat-dictation']);
    assert.deepEqual(journeyMatrix(source, 'push', '', 'refs/heads/ceo/IGSH-1061-recovery'), ['browser-pane-stuck']);
    assert.deepEqual(journeyMatrix(source, 'push', '', 'refs/heads/ceo/IGSH-1083'), ['appearance']);
    assert.deepEqual(journeyMatrix(source, 'push', '', 'refs/heads/ceo/IGSH-1079'), ['appearance']);
    assert.deepEqual(journeyMatrix(source, 'push', '', 'refs/heads/ceo/IGSH-1055-hax2'), ['browser-pane-stuck', 'chat-messages-only']);
    for (const feature of full) assert.ok(journeyMatrix(source, 'workflow_dispatch', 'all', 'refs/tags/v0.28.837').includes(feature));
    assert.deepEqual(journeyMatrix(source, 'workflow_dispatch', 'chat-dictation'), ['chat-dictation']);
  }
  contract(workflow);
  for (const [before, after] of [
    ['fromJSON(needs.journeys.outputs.pr)', 'fromJSON(needs.journeys.outputs.full)'],
    ['fromJSON(needs.journeys.outputs.full)', 'fromJSON(needs.journeys.outputs.pr)'],
    [`github.event_name == 'push' && fromJSON('["appearance", "relaunch-saved-sessions"]')`, `github.event_name == 'pull_request' && fromJSON('["appearance", "relaunch-saved-sessions"]')`],
    ["inputs.feature == 'all'", "inputs.feature == 'appearance'"],
  ]) {
    const broken = workflow.replace(before, after);
    assert.notEqual(broken, workflow, before);
    assert.throws(() => contract(broken), assert.AssertionError, before);
  }
});

test('explicit runner-note proof selects its native journey without expanding ordinary PR checks', () => {
  assert.deepEqual(journeyMatrix(workflow, 'pull_request', 'chat-delivery', 'refs/pull/577/merge', { chat_notes_proof: true }), ['chat-delivery']);
  assert.deepEqual(journeyMatrix(workflow, 'pull_request', 'all'), featureMatrix(workflow).pr);
});

test('switch timing is dispatch-only while allowlists and artifact contracts retain it', () => {
  assertsDispatchOnly(workflow);
  for (const before of ['fromJSON(needs.journeys.outputs.pr)', 'fromJSON(needs.journeys.outputs.full)']) {
    const broken = workflow.replace(before, `fromJSON('["browser-switch-speed"]')`);
    assert.notEqual(broken, workflow, before);
    assert.throws(() => assertsDispatchOnly(broken), assert.AssertionError);
  }
  assert.throws(() => assertsDispatchOnly(workflow.replaceAll(`fromJSON(format('["{0}"]', inputs.feature))`, `fromJSON(format('["{0}"]', inputs.other))`)));
  assert.match(workflow, /node tools\/verify-features.cjs \$env:FEATURE/);
  assert.ok(featureMatrix(workflow).available.includes('browser-switch-speed'));
  assert.match(control, /ValidateSet\([^\n]*'browser-switch-speed'/);
  assert.match(workflow, /name: verify-\$\{\{ env.FEATURE \}\}/);
  assert.match(workflow, /node --test --test-concurrency=1 tools\/verify-multiprompt.test.js[^\n]+tools\/browser-switch-speed.test.js/);
  assert.match(workflow, /paths:[\s\S]*?- tools\/browser-switch-speed.test.js/);
  assert.match(control, /if \(\$Feature -in @\('browser-pane-stuck', 'pane-layout', 'browser-pane-locked', 'browser-switch-speed', 'chat-switch-speed', 'chat-first-paint', 'browser-corners', 'window-controls'\)\)/);
  const map = read(base + 'features/browser-switch-speed.md');
  assert.deepEqual([...map.matchAll(/^## (.+)$/gm)].map(match => match[1]), ['Sub-features', 'How to get to it (user POV)', 'Driving it with control.ps1', 'Gotchas']);
  assert.match(map, /on demand only/);
  for (const file of ['SKILL.md', 'features/README.md']) {
    const prLine = read(base + file).split('\n').find(line => /PR.*trigger|pull_request.*trigger/.test(line));
    assert.ok(prLine);
    assert.equal(prLine.includes('browser-switch-speed'), false);
  }
  for (const term of ['Ctrl+Tab', 'verify-browser-switch-speed', '50 ms', '100 ms', '180 ms', 'not a switch-speed fix']) assert.ok(map.includes(term));
  assert.match(read(base + 'features/README.md'), /\[Browser switch speed\]\(browser-switch-speed.md\)/);
  assert.match(read(base + 'SKILL.md'), /`browser-switch-speed`/);
});

function assertsFrozen(source, driver, app, yaml) {
  assertsJourney(source);
  const marker = driver.slice(driver.indexOf('function Read-BrowserFrozen'), driver.indexOf('function Assert-BrowserPane'));
  assert.match(marker, /\[uint32\]\$SessionId/);
  assert.match(marker, /Join-Path \$scratch \("roaming\/ZigShell\/panehib-zss-\$SessionId.flag"\)/);
  assert.match(marker, /Test-Path -LiteralPath \$path -PathType Leaf/);
  assert.match(marker, /Get-Content -LiteralPath \$path -Raw -ErrorAction Stop\).Trim\(\) -ceq '1'\) \{ return \$true \}/);
  assert.match(marker, /catch \{ return \$null \}/);
  assert.match(marker, /return \$null\s+\}\s+return \$false/);
  assert.match(source, /\$frozen = \$mode.Contains\('frozen_'\)/);
  assert.match(source, /if \(\$browserOn -and -not \$frozen\)/);
  assert.match(source, /foreach \(\$tab in @\(1, 0\)\)/);
  assert.match(source, /Wait-Until \{ \$false -eq \(Read-BrowserFrozen \$shellIds\[\$tab\]\) \} 'active browser freeze marker cleared'/);
  assert.match(source, /\$_.sid -in \$shellIds -and \$_.browser_state -eq 'connected' -and \$_.browser_window_id -gt 0/);
  assert.match(source, /\$panes.Count -eq 2/);
  assert.match(source, /\$pane.browser_state -eq 'connected' -and \$pane.browser_window_id -gt 0 -and/);
  const sample = source.slice(source.indexOf('for ($sample = 0;'), source.indexOf('foreach ($mode in $modes) { $timings[$mode].median_ms'));
  const steps = [
    'Doctor', 'if ($frozen) {', "$frozenLogStart = ((Get-Content $log -Raw) -join '').Length",
    '[void]$frozenSwitches.Add($freeze)',
    "if ($false -ne (Read-BrowserFrozen $shellIds[$target])) { throw 'Target already frozen; expected a fresh freeze after its last activation' }",
    '$parked = [Diagnostics.Stopwatch]::StartNew()',
    'Wait-Until {', '$state = Read-Session',
    '$state.active_tab -eq (1 - $target)', '$state.tabs[$target].shell_id -eq $shellIds[$target]',
    '(Read-BrowserFrozen $shellIds[$target])',
    '} "fresh app-published freeze marker for parked target $target" 150',
    "$freeze.status = 'frozen'", '$freeze.observed_utc = [DateTime]::UtcNow.ToString(\'o\')',
    'Doctor', 'Assert-Foreground',
    '$measurement = [VerifyNative]::MeasureSessionSwitch(',
    '$timings[$mode].samples_ms[$sample] = $measurement[0]',
    '$timings[$mode].window_visible_ms[$sample] = $measurement[1]',
    'Wait-WorkspaceSurface',
    "Wait-Until { $false -eq (Read-BrowserFrozen $shellIds[$target]) } 'target freeze marker removed by app wake'",
    '$freeze.marker_cleared = $true', "$freeze.status = 'painted-and-awake'",
  ];
  let offset = -1;
  for (const step of steps) {
    const next = sample.indexOf(step, offset + 1);
    assert.ok(next > offset, step);
    offset = next;
  }
  assert.equal((sample.match(/MeasureSessionSwitch\(/g) || []).length, 1);
  assert.doesNotMatch(marker + source, /(?:Set-Content|New-Item|Remove-Item)[^\n]*panehib|cdp Page|hibernate.*now/i);
  assert.match(source, /finally \{[\s\S]*\$debug = \(Get-Content \$log -Raw\) -join ''[\s\S]*foreach \(\$freeze in \$frozenSwitches\)/);
  assert.match(source, /if \(\$null -eq \$freeze.log_end\) \{ \$debug.Length \} else \{ \$freeze.log_end \}/);
  assert.match(source, /\$debug.Substring\(\$freeze.log_start, \$end - \$freeze.log_start\)/);
  assert.match(source, /"\{0\}-\{1\}-debug.log" -f \$freeze.mode, \$freeze.sample/);
  assert.match(source, /Save-Json @\(\$frozenSwitches.ToArray\(\)\) 'frozen-switches.json'/);
  const publish = app.slice(app.indexOf('fn setBrowserFrozenMarkerForShell'), app.indexOf('pub fn buildBrowserCdpLifecycleCmd'));
  assert.doesNotMatch(publish, /isRemoteShellKind/);
  assert.match(publish, /shellZsbSessionKey\(app_state.shells\[idx\].shell_id, &key_buf\)/);
  assert.match(publish, /if \(frozen\) writeBrowserFrozenMarkerKey\(key\) else removeBrowserFrozenMarkerKey\(key\)/);
  assert.match(app, /const prefix = "\\\\ZigShell\\\\panehib-"/);
  assert.match(app, /const prefix = "zss-"/);
  assert.match(app, /win32WriteAll\(h, "1\\n"\)/);
  assert.match(app, /if \(job.confirmed\) \{\s+setBrowserFrozenMarkerForShell\(idx, job.frozen\)/);
  assert.match(app, /browser_frozen != job.frozen\) return;/);
  const timeout = yaml.match(/timeout-minutes: \$\{\{ (?:inputs.long_chat_proof && \d+ \|\| )?(?:matrix.feature == '(?:pane-layout|chat-switch-speed)' && \d+ \|\| )*matrix.feature == 'browser-switch-speed' && (\d+) \|\| (\d+) \}\}/);
  assert.ok(timeout);
  const sets = source.match(/\$modes = @\(([^\n]+)\)/)[1].match(/'[^']+'/g).filter(mode => mode.includes('frozen_')).length;
  const samples = Number(source.match(/Contains\('frozen_'\)\) \{ (\d+) \}/)[1]);
  const wait = Number(source.match(/fresh app-published freeze marker[^\n]+" (\d+)/)[1]);
  assert.ok(Number(timeout[1]) >= Number(timeout[2]) + Math.ceil(sets * samples * wait / 60));
}

test('frozen returns require five fresh app-published freezes per view, native color timing, wake clearing and bounded evidence', () => {
  assertsFrozen(journey, control, browser, workflow);
  for (const [before, after] of [
    ["{ 5 } else { 20 }", "{ 1 } else { 20 }"],
    ['$browserOn -and -not $frozen', '$browserOn'],
    ['foreach ($tab in @(1, 0))', 'foreach ($tab in @(0))'],
    ['if ($false -ne (Read-BrowserFrozen $shellIds[$target]))', 'if ($false)'],
    ['$state.active_tab -eq (1 - $target)', '$true'],
    ['$state.tabs[$target].shell_id -eq $shellIds[$target]', '$true'],
    ['} "fresh app-published freeze marker for parked target $target" 150', '} "parked" 1'],
    ['Wait-Until { $false -eq (Read-BrowserFrozen $shellIds[$target]) }', 'Wait-Until { $true }'],
    ['$_.browser_window_id -gt 0', '$true'],
    ["@('chat_browser_off', 'chat_frozen_browser_on')", "@('browser_off', 'chat_frozen_browser_on')"],
    ["Save-Json @($frozenSwitches.ToArray()) 'frozen-switches.json'", ''],
    ['$debug.Substring($freeze.log_start, $end - $freeze.log_start)', '$debug'],
  ]) assert.throws(() => assertsFrozen(journey.replace(before, after), control, browser, workflow), `reject frozen regression: ${before}`);
  assert.throws(() => assertsFrozen(journey, control.replace(".Trim() -ceq '1'", '.Trim() -ceq \'0\''), browser, workflow));
  assert.throws(() => assertsFrozen(journey, control, browser.replace('fn setBrowserFrozenMarkerForShell(idx: u32, frozen: bool) void {', 'fn setBrowserFrozenMarkerForShell(idx: u32, frozen: bool) void {\n    if (isRemoteShellKind(app_state.shells[idx].kind)) return;'), workflow));
  assert.throws(() => assertsFrozen(journey, control, browser, workflow.replace("&& 60 || 30", "&& 30 || 30")));
});

function assertsSwitchExtension(driver) {
  const setup = driver.slice(driver.indexOf("    if ($Feature -in @('browser-switch-speed', 'chat-switch-speed', 'browser-own-profile')) {"), driver.indexOf("    $env:IGSH_246 = '0'"));
  for (const step of [
    "Join-Path $env:USERPROFILE 'Documents/GitHub/zigshell/extension'",
    "$extensionSource = if ($shapeProof -and $env:VERIFY_EXTENSION_ROOT) { $env:VERIFY_EXTENSION_ROOT } else { Join-Path $PSScriptRoot '../../../extension' }",
    "Copy-Item $extensionSource $extension -Recurse",
    'Add-Member -NotePropertyName key -NotePropertyValue $publicKey -Force',
    'allowed_origins = @("chrome-extension://$extensionId/")',
    "path = (Join-Path (Split-Path $Exe) 'zigshell-bridge.exe')",
    'HKCU:\\Software\\Google\\Chrome\\NativeMessagingHosts\\com.zigshell.bridge',
    "if (Test-Path $registry) { throw 'Switch timing requires an unregistered disposable native host' }",
    '$switchNativeRegistry = $registry', 'New-Item -Path $registry -Force', 'Set-Item -Path $registry -Value $nativeManifest',
  ]) assert.ok(setup.includes(step), step);
  assert.match(driver, /if \(\$Feature -notin @\('browser-switch-speed', 'chat-switch-speed'\) -and \$pane.browser_window_id -ne 0\)/);
  assert.match(driver, /finally \{\s+if \(\$null -ne \$switchNativeRegistry\) \{\s+Remove-Item -LiteralPath \$switchNativeRegistry -Recurse -Force/);
  const key = Buffer.from(setup.match(/\$publicKey = '([^']+)'/)[1], 'base64');
  const crypto = require('node:crypto');
  assert.equal(crypto.createPublicKey({ key, format: 'der', type: 'spki' }).asymmetricKeyType, 'rsa');
  const id = crypto.createHash('sha256').update(key).digest('hex').slice(0, 32).replace(/[0-9a-f]/g, n => String.fromCharCode(97 + parseInt(n, 16)));
  assert.match(id, /^[a-p]{32}$/);
  assert.match(setup, /\$digest\[0\.\.15\] \| ForEach-Object \{ \[char\]\(97 \+ \(\$_ -shr 4\)\); \[char\]\(97 \+ \(\$_ -band 15\)\) \}/);
  assert.match(browser, /const suffix = "\\\\Documents\\\\GitHub\\\\zigshell\\\\extension"/);
}

test('switch journey installs only the fixture extension and matching native host, refuses shared registration and cleans it up', () => {
  assertsSwitchExtension(control);
  for (const before of [
    "$extensionSource = if ($shapeProof -and $env:VERIFY_EXTENSION_ROOT) { $env:VERIFY_EXTENSION_ROOT } else { Join-Path $PSScriptRoot '../../../extension' }",
    "Copy-Item $extensionSource $extension -Recurse",
    'Add-Member -NotePropertyName key -NotePropertyValue $publicKey -Force',
    "if (Test-Path $registry) { throw 'Switch timing requires an unregistered disposable native host' }",
    'Remove-Item -LiteralPath $switchNativeRegistry -Recurse -Force',
  ]) assert.throws(() => assertsSwitchExtension(control.replace(before, '')));
});

test('new measurement code adds no removable code comments', async () => {
  const { strip } = await import('./strip-comments.mjs');
  for (const [source, language] of [[timing, 'zig'], [browser, 'zig'], [control, 'powershell'], [workflow, 'yaml'], [read('tools/browser-switch-speed.test.js'), 'javascript']]) assert.equal(strip(source, language).commentLines, 0);
});

function assertsRealBridge(driver, yaml) {
  yaml = yaml.slice(yaml.indexOf('\n  verify:\n'));
  const setup = driver.slice(driver.indexOf("    if ($Feature -in @('browser-switch-speed', 'chat-switch-speed', 'browser-own-profile')) {"), driver.indexOf("    $env:IGSH_246 = '0'"));
  for (const step of [
    "Join-Path $PSScriptRoot 'browser-switch-chrome.mjs'",
    "Join-Path $config 'chrome-exe.txt'", "Join-Path $config 'browser-engine.txt'",
    "HKCU:\\Software\\Google\\Chrome\\NativeMessagingHosts\\com.zigshell.bridge",
    "'zigshell-bridge.exe'", 'chrome-extension://$extensionId/',
  ]) assert.ok(setup.includes(step), step);
  assert.match(yaml, /Copy-Item zig-out\/bin\/zigshell-bridge.exe verify-bin\/zigshell-bridge.exe/);
  for (const name of ['actions/setup-node@', 'name: Install isolated Chrome for Testing driver', 'name: Verify real native browser journey']) {
    const step = yaml.slice(yaml.indexOf(name), yaml.indexOf('\n      - ', yaml.indexOf(name) + name.length));
    assert.match(step, /if: env.FEATURE == 'browser-emulation' \|\| env.FEATURE == 'browser-switch-speed'/);
  }
  assert.match(yaml, /puppeteer@24\.31\.0/);
  const wait = driver.slice(driver.indexOf('function Wait-SwitchNativeHost'), driver.indexOf('function Read-BrowserFrozen'));
  for (const step of ["'multiprompt-browser-isolated'", '$pipe.Connect(100)', '$pipe.IsConnected', '$pipe.Dispose()', "'native messaging host reconnect on extension keepalive' 90"]) assert.ok(wait.includes(step), step);
  assert.match(driver, /\$pane = Open-BrowserPane \(\$mode \+ '-' \+ \$tab\)\s+Wait-SwitchNativeHost\s+Wait-Until/);
  assert.ok(driver.indexOf("Join-Path $PSScriptRoot 'browser-switch-chrome.mjs'") < driver.indexOf("$env:USERPROFILE = Join-Path $scratch 'profile'"));
  assert.match(driver, /\$edge = \$chrome\s+\$profile = Join-Path \$env:LOCALAPPDATA 'ZigShell\/ChromeUserData'/);
}

test('switch panes use pinned real Chrome via user configuration and wait for real host keepalive reconnect', () => {
  assertsRealBridge(control, workflow);
  const resolver = read(base + 'browser-switch-chrome.mjs');
  assert.match(resolver, /createRequire\(path.join\(process.env.VERIFY_BROWSER_MODULE, 'package.json'\)\)/);
  assert.match(resolver, /require\('puppeteer'\).executablePath\(\)/);
  for (const before of ["Join-Path $PSScriptRoot 'browser-switch-chrome.mjs'", "Join-Path $config 'chrome-exe.txt'", '$pipe.Connect(100)', '$pipe.IsConnected', 'Wait-SwitchNativeHost\n                            Wait-Until']) {
    assert.throws(() => assertsRealBridge(control.replaceAll(before, 'false'), workflow), `reject missing real bridge step: ${before}`);
  }
  assert.throws(() => assertsRealBridge(control, workflow.replaceAll("|| env.FEATURE == 'browser-switch-speed'", '')));
});

function assertsWakeTiming(source, driver) {
  const measure = source.slice(source.indexOf('public static double[] MeasureSessionSwitch'));
  assert.match(measure, /File.ReadAllText\(frozenMarker\).Trim\(\) != "1"[\s\S]+var timer = BeginSessionSwitch\(\)/);
  assert.match(measure, /if \(frozen && awake < 0 && !System.IO.File.Exists\(frozenMarker\)\) awake = timer.Elapsed.TotalMilliseconds/);
  assert.match(measure, /if \(painted >= 0 && \(!frozen \|\| awake >= 0\)\)/);
  assert.match(measure, /return new double\[\] \{ painted, visible, awake \}/);
  assert.match(driver, /\$frozenMarker = if \(\$frozen\) \{ Join-Path \$scratch \("roaming\/ZigShell\/panehib-zss-\$\(\$shellIds\[\$target\]\).flag"\) \} else \{ \$null \}/);
  for (const [field, index] of [['window_visible_ms', 1], ['wake_flag_cleared_ms', 2], ['target_color_painted_ms', 0]]) {
    assert.ok(driver.includes(`$freeze.${field} = $measurement[${index}]`));
    assert.ok(driver.includes(`${field} = $null`));
  }
}

test('each frozen sample records independent native-loop visible, marker-cleared and color-paint times', () => {
  assertsWakeTiming(native, journey);
  for (const before of ['File.ReadAllText(frozenMarker).Trim() != "1"', '!System.IO.File.Exists(frozenMarker)', 'awake >= 0', 'painted, visible, awake']) assert.throws(() => assertsWakeTiming(native.replaceAll(before, 'false'), journey));
  for (const field of ['window_visible_ms', 'wake_flag_cleared_ms', 'target_color_painted_ms']) assert.throws(() => assertsWakeTiming(native, journey.replace(`$freeze.${field} = $measurement`, '$ignored = $measurement')));
});

test('timing log appends permit concurrent evidence readers without permitting another writer', () => {
  const io = read('src/file_io.zig');
  const append = io.slice(io.indexOf('pub fn win32OpenAppend('), io.indexOf('pub fn win32WriteAll('));
  const sharedRead = /CreateFileW\(w.ptr, GENERIC_WRITE, FILE_SHARE_READ, null, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, null\)/;
  assert.match(append, sharedRead);
  for (const sharing of ['0', 'FILE_SHARE_READ | FILE_SHARE_WRITE']) assert.doesNotMatch(append.replace('GENERIC_WRITE, FILE_SHARE_READ,', `GENERIC_WRITE, ${sharing},`), sharedRead);
});

test('optional trace reads retain the real sample and a range record if the live log shrinks', () => {
  assert.match(journey, /\$traceMatches = @\(\)\s+if \(\$debugAfter.Length -ge \$logStart\) \{ \$traceMatches = \[regex\]::Matches\(\$debugAfter.Substring\(\$logStart\), \$pattern\) \}/);
  assert.match(journey, /complete = \$debugAfter.Length -ge \$logStart/);
  assert.match(journey, /\$freeze.log_start -le \$end -and \$end -le \$debug.Length/);
});

test('the long freeze fixture disables only tier-three window closing through real palette input', () => {
  assert.match(journey, /Focus-Palette 'browser auto suspend' 6240/);
  assert.match(journey, /Press @\(0x0D\) 'Enter: disable timed browser closing while measuring fresh tier-two freezes'/);
  assert.match(journey, /\$state.PSObject.Properties\['browser_suspend_min'\] -and \$state.browser_suspend_min -eq 0/);
  assert.ok(journey.indexOf('switch-idle-close-fixture.json') < journey.indexOf('foreach ($mode in $modes)', journey.indexOf('$warmupJob = $null')));
  const freezeTick = browser.slice(browser.indexOf('pub fn browserHibernationTick('), browser.indexOf('pub fn findDataFileNameAscii('));
  assert.doesNotMatch(freezeTick, /g_browser_autosuspend|g_browser_suspend_min/);
  assertsFrozen(journey, control, browser, workflow);
});

test('fresh freeze setup waits for the exact fixture lifecycle helper to exit before waking the target', () => {
  const sample = journey.slice(journey.indexOf('for ($sample = 0;'), journey.indexOf('foreach ($mode in $modes) { $timings[$mode].median_ms'));
  const barrier = sample.slice(sample.indexOf("$freeze.observed_utc ="), sample.indexOf('Assert-Foreground'));
  assert.match(barrier, /Get-CimInstance Win32_Process -Filter "Name = 'zigshell-bridge.exe'"/);
  for (const check of ['ExecutablePath -ceq $bridgePath', '$freezeWindow', 'Page\\.setWebLifecycleState', "CommandLine.Contains('frozen')", '$workers.Count -eq 0', '$freeze.worker_finished_utc']) assert.ok(barrier.includes(check), check);
  assert.ok(sample.indexOf('worker_finished_utc') < sample.indexOf('$measurement ='));
});

function joinedLogReads(source) {
  const reads = [...source.matchAll(/Get-Content \$log -Raw/g)];
  assert.ok(reads.length > 0);
  for (const read of reads) assert.ok(source.slice(read.index + read[0].length).startsWith(") -join ''"));
}

test('live PowerShell raw-reader chunks are joined before string offsets and lengths are used', () => {
  joinedLogReads(control);
  assert.throws(() => joinedLogReads(control.replace("(Get-Content $log -Raw) -join ''", 'Get-Content $log -Raw')));
});

test('failed samples retain read-only Chrome DOM and compositor evidence without altering the measurement result', () => {
  const diagnostics = journey.slice(journey.indexOf("if ($gapCase.status -ne 'passed' -and $gapCase.phase -like '*sample-*')"));
  for (const literal of ["method = 'Runtime.evaluate'", "method = 'Page.captureScreenshot'", "name = 'tabs'", 'document.visibilityState', 'getComputedStyle(document.body).backgroundColor', 'switch-failure-browser-diagnostics.json']) assert.ok(diagnostics.includes(literal), literal);
  assert.doesNotMatch(diagnostics, /setWebLifecycleState|navigate|Page.bringToFront|\$gapCase.status =/);
});

test('failure-only pixel diagnostics compare the same visible patch with and without layered-window capture', () => {
  const capture = control.slice(control.indexOf('public static int[] ReadSwitchScreenPatch'), control.indexOf('public static System.Diagnostics.Stopwatch BeginSessionSwitch'));
  assert.match(capture, /0x00CC0020 \| \(layered \? 0x40000000 : 0\)/);
  assert.match(capture, /dock.Left \+ \(dock.Right - dock.Left\) \/ 2/);
  assert.match(capture, /dock.Top \+ \(dock.Bottom - dock.Top\) \* 3 \/ 4/);
  assert.match(journey, /ReadSwitchScreenPatch\(\$docks\[\$target\], \$false\)/);
  assert.match(journey, /ReadSwitchScreenPatch\(\$docks\[\$target\], \$true\)/);
  assert.doesNotMatch(native, /ReadSwitchScreenPatch/);
});

test('a completed warm pair reports its speed while every run still checks every warm and frozen pair', () => {
  const earlyStart = journey.indexOf("\n                    if ($mode -eq 'browser_on') {");
  assert.ok(earlyStart >= 0);
  const early = journey.slice(earlyStart, journey.indexOf('foreach ($mode in $modes) { $timings[$mode].median_ms'));
  for (const literal of ['Get-SwitchMedian $timings.browser_off.samples_ms', 'Get-SwitchMedian $timings.browser_on.samples_ms', 'if ($onMedian - $offMedian -gt $browserGapLimitMs)', "$gapCase.phase = 'switch-gap'", "Assert-ReleaseTiming 'browser-switch-gap'"]) assert.ok(early.includes(literal), literal);
  assert.ok(earlyStart > journey.indexOf('$timings[$mode].samples_ms[$sample] = $measurement[0]'));
  assertsJourney(journey);
  assertsFrozen(journey, control, browser, workflow);
});

test('failure probes own separate single-launch jobs and stop only their own process trees', () => {
  const probes = journey.slice(journey.indexOf('foreach ($probe in $probes)'));
  assert.match(probes, /\$probeJob = New-Object VerifyJob/);
  assert.match(probes, /\$probeProcess = \$probeJob.Start/);
  assert.match(probes, /\$probeStopped = \$probeJob.Stop/);
  assert.match(probes, /\$probeJob.Dispose\(\)/);
  assert.doesNotMatch(probes, /\$job.Start|\$job.Stop/);
});

function assertsPageFocus(focus, main, pane, driver) {
  assert.match(focus, /pub fn browserPageFocusCommand\(pane_foreground: bool, alt_down: bool\) \?WPARAM/);
  assert.match(focus, /const IDC_FOCUS_WEB_CONTENTS_PANE = 39009;/);
  assert.match(focus, /return if \(pane_foreground and !alt_down\) IDC_FOCUS_WEB_CONTENTS_PANE else null;/);
  const unlock = focus.slice(focus.indexOf('pub fn unlockBrowserForeground()'), focus.indexOf('pub fn focusActiveBrowserPane()'));
  let unlockCursor = 0;
  for (const statement of [
    'if (phys_alt) return;',
    'keybd_event(VK_MENU, 0, 0, 0);',
    'keybd_event(0xE8, 0, 0, 0);',
    'keybd_event(0xE8, 0, KEYEVENTF_KEYUP, 0);',
    'keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);',
    'app_state.g_native_browser_alt_unlocked_at = GetTickCount64();',
  ]) {
    const position = unlock.indexOf(statement, unlockCursor);
    assert.ok(position >= 0, statement);
    unlockCursor = position + statement.length;
  }
  assert.equal((unlock.match(/keybd_event\(/g) ?? []).length, 4);
  const handoff = focus.slice(focus.indexOf('pub fn focusActiveBrowserPaneUnlocked()'), focus.indexOf('pub fn cancelPendingNativeBrowserFocus()'));
  let cursor = 0;
  for (const statement of [
    'if (!focusGuard(bh)) return;',
    'if (phys_alt) return;',
    '_ = SetForegroundWindow(bh);',
    '_ = SetFocus(bh);',
    'if (attached_target) _ = AttachThreadInput(our_thread, target_thread, 0);',
    'browserPageFocusCommand(GetForegroundWindow() == bh, phys_alt)',
    'PostMessageW(bh, @import("win32.zig").WM_COMMAND, command, 0)',
  ]) {
    const position = handoff.indexOf(statement, cursor);
    assert.ok(position >= 0, statement);
    cursor = position + statement.length;
  }
  assert.equal((handoff.match(/keybd_event\(|SendInput\(/g) ?? []).length, 0);
  assert.match(read('src/shortcuts.zig'), /kb\.vkCode != 0xFF and kb\.vkCode != 0xE8 and\n\s+foregroundIsOurs\(\)\)/);
  const timer = main.slice(main.indexOf('if (wp == TIMER_NATIVE_BROWSER_FOCUS)'), main.indexOf('if (wp == TIMER_WEBVIEW2_FOCUS)'));
  const unlockTick = timer.indexOf('if ((app_state.g_native_browser_alt_unlocked_at == 0 or GetTickCount64() -| app_state.g_native_browser_alt_unlocked_at > 100) and !activeBrowserHasForegroundFocus()) {\n                    unlockBrowserForeground();');
  const activation = timer.indexOf('focusActiveBrowserPaneUnlocked();');
  assert.ok(unlockTick >= 0 && unlockTick < activation && activation < timer.indexOf('if (activeBrowserHasForegroundFocus())'));
  assert.match(pane, /if \(idx == app_state.active_shell\) @import\("focus.zig"\)\.requestNativeBrowserFocus\(\);/);
  assert.match(pane, /browserFocusRequestMatches\(app_state.g_focus_browser_shell_id, app_state.shells\[idx\]\.shell_id, foregroundIsOurs\(\)\)/);
  assert.match(focus, /return requested_sid != 0 and requested_sid == active_sid and foreground_owned;/);
  assert.match(focus, /const authorized = pane_authorized or/);
  for (const name of [
    'IGSH-724 browser handoff focuses web contents instead of restoring toolbar focus',
    'IGSH-724 browser foreground unlock masks lone Alt menu activation',
    'IGSH-724 pending page focus survives docking only without intervening input or a session change',
  ]) assert.ok(focus.includes(`test "${name}"`));
  for (const required of [
    'document.title="', 'let keys=0', '++keys', 'foreach ($key in @(0x20, 0x28, 0x4A, 0x4B))',
    'IGSH-724 Alt+Q sent a page key to browser chrome', 'IGSH-724 opening a pane sent Space to browser chrome',
    'foreach ($round in 1..5)', 'Alt+Q sent a page key to the browser menu',
    "::Chord(@(0x75))", "::Chord(@(0x11, 0x4C))", "Palette 'open browser'",
    'IGSH-724 page-to-input return lost session typing focus', "name = 'IGSH-724 browser-page-focus'",
  ]) assert.ok(driver.includes(required), required);
}

function assertsOpenPaneHopSync(driver) {
  const palette = driver.indexOf("Palette 'open browser'");
  const offset = driver.indexOf("$hopStart = (Read-SharedText $hopLog).Length", palette);
  const press = driver.indexOf("Press @(0x0D) 'IGSH-724: opening an existing pane focuses its page'", palette);
  const wait = driver.indexOf("-match 'pane_hop result bh_fg=true' } 'IGSH-998 app finished the open-pane hop to its browser'", palette);
  const foreground = driver.indexOf("throw 'Opening the pane did not focus its browser'", palette);
  const space = driver.indexOf("throw 'IGSH-724 opening a pane sent Space to browser chrome'", palette);
  assert.ok(palette >= 0 && palette < offset && offset < press && press < wait && wait < foreground && foreground < space);
}

test('IGSH-998 open-pane foreground check waits for the app pane_hop result and stays strict', () => {
  assertsOpenPaneHopSync(journey);
  for (const before of [
    "$hopStart = (Read-SharedText $hopLog).Length\n",
    "-match 'pane_hop result bh_fg=true'",
  ]) assert.throws(() => assertsOpenPaneHopSync(journey.replace(before, '')), before);
  const wait = /^ *Wait-Until \{ \(Read-SharedText \$hopLog\)[^\n]*\n/m;
  assert.match(journey, wait);
  assert.throws(() => assertsOpenPaneHopSync(journey.replace(wait, '')));
  assert.ok(journey.includes("if ([VerifyNative]::GetForegroundWindow() -ne $browser) { throw 'Opening the pane did not focus its browser' }"));
  assert.ok(!/Start-Sleep|Thread\]::Sleep/.test(journey.slice(journey.indexOf("$hopStart"), journey.indexOf("throw 'Opening the pane did not focus its browser'"))));
});

test('IGSH-724 native handoff targets Chrome web contents and real keys distinguish page focus from toolbar activation', () => {
  const focus = read('src/focus.zig');
  const main = read('src/main.zig');
  assertsPageFocus(focus, main, browser, journey);
  const unlock = focus.slice(focus.indexOf('pub fn unlockBrowserForeground()'), focus.indexOf('pub fn focusActiveBrowserPane()'));
  for (const statement of ['if (phys_alt) return;', 'keybd_event(VK_MENU, 0, 0, 0);', 'keybd_event(0xE8, 0, 0, 0);', 'keybd_event(0xE8, 0, KEYEVENTF_KEYUP, 0);', 'keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);', 'app_state.g_native_browser_alt_unlocked_at = GetTickCount64();']) {
    assert.throws(() => assertsPageFocus(focus.replace(unlock, unlock.replace(statement, '')), main, browser, journey));
  }
  const neutral = '    keybd_event(0xE8, 0, 0, 0);\n    keybd_event(0xE8, 0, KEYEVENTF_KEYUP, 0);\n';
  assert.throws(() => assertsPageFocus(focus.replace(unlock, unlock.replace(neutral, '')), main, browser, journey));
  const handoff = focus.slice(focus.indexOf('pub fn focusActiveBrowserPaneUnlocked()'), focus.indexOf('pub fn cancelPendingNativeBrowserFocus()'));
  assert.throws(() => assertsPageFocus(focus.replace(handoff, handoff.replace('    _ = SetForegroundWindow(bh);\n', '    keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);\n    _ = SetForegroundWindow(bh);\n')), main, browser, journey));
  assert.throws(() => assertsPageFocus(focus.replace(handoff, handoff.replace('    armBrowserEdgeMaskRaise();\n', '    keybd_event(0xE8, 0, 0, 0);\n    armBrowserEdgeMaskRaise();\n')), main, browser, journey));
  for (const before of ['const IDC_FOCUS_WEB_CONTENTS_PANE = 39009;', 'pane_foreground and !alt_down', 'PostMessageW(bh, @import("win32.zig").WM_COMMAND, command, 0)', 'const authorized = pane_authorized or']) {
    assert.throws(() => assertsPageFocus(focus.replace(before, ''), main, browser, journey));
  }
  assert.throws(() => assertsPageFocus(focus, main.replace('                focusActiveBrowserPaneUnlocked();', ''), browser, journey));
  assert.throws(() => assertsPageFocus(focus, main.replace('                    unlockBrowserForeground();\n', ''), browser, journey));
  assert.throws(() => assertsPageFocus(focus, main, browser.replace('if (idx == app_state.active_shell) @import("focus.zig").requestNativeBrowserFocus();', ''), journey));
  for (const before of ['IGSH-724 Alt+Q sent a page key to browser chrome', 'IGSH-724 opening a pane sent Space to browser chrome', '++keys', 'foreach ($round in 1..5)', 'Alt+Q sent a page key to the browser menu']) {
    assert.throws(() => assertsPageFocus(focus, main, browser, journey.replace(before, '')));
  }
});


test('long-chat continuity reserves thirty minutes without shortening browser freeze budgets', () => {
  const timeout = workflow.match(/timeout-minutes: \$\{\{ inputs.long_chat_proof && (\d+) \|\| matrix.feature/);
  assert.ok(timeout, 'native long-chat proof must have its own observation budget');
  assert.ok(Number(timeout[1]) >= 40, 'thirty-minute observation plus setup and cleanup');
  assertsFrozen(journey, control, browser, workflow);
});
