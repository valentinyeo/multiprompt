const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
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
  assert.match(measure, /if \(painted < 0 && \(browser == IntPtr.Zero \|\| PaintMatches\(dock, rgb, pixels, graphics\)\)\) painted = timer.Elapsed.TotalMilliseconds;/);
  assert.match(measure, /if \(painted >= 0 && \(!frozen \|\| awake >= 0\)\) \{\s+timer.Stop\(\);\s+return new double\[\] \{ painted, visible, awake \};/);
  assert.match(measure, /Thread.Sleep\(1\);[\s\S]*timer.ElapsedMilliseconds < 20000/);
  assert.doesNotMatch(source, /AutomationElement|SetForegroundWindow|::Chord|SendMessage\(|PostMessage|DwmFlush/);
}

test('timed input and native polling stay in one call without UIA or PowerShell dispatch latency', () => {
  assertsNative(native);
  for (const before of ['GetForegroundWindow() != console', '!IsWindowVisible(console)', '!Title(console).EndsWith(suffix, StringComparison.Ordinal)', 'GetProp(browser, "ZigShellPaneOwner") != owner', 'actual.Left != dock.Left', 'EditText(composer) != draft', 'timer.Stop();', 'Thread.Sleep(1);', 'PaintMatches(dock, rgb, pixels, graphics)']) {
    assert.throws(() => assertsNative(native.replaceAll(before, 'false')));
  }
  const sample = journey.slice(journey.indexOf('$measurement ='), journey.indexOf("$pattern = 'switch-timing"));
  assert.match(sample, /MeasureSessionSwitch\(\$script:window, \$consoles\[\$target\], \('ZigShell-' \+ \$shellIds\[\$target\]\), \$browsers\[\$target\], \$docks\[\$target\], \$composerHandle, \$drafts\[\$target\], \$rgb\[\$target\], \$frozenMarker\)/);
  assert.match(sample, /samples_ms\[\$sample\] = \$measurement\[0\]/);
  assert.match(sample, /window_visible_ms\[\$sample\] = \$measurement\[1\]/);
  assert.ok(sample.indexOf('Wait-WorkspaceSurface') > sample.indexOf('window_visible_ms'));
});

function assertsPaint(source, driver) {
  assert.match(source, /dock.Bottom - dock.Top < 200/);
  assert.match(source, /int x = dock.Left \+ \(dock.Right - dock.Left\) \/ 2;/);
  assert.match(source, /int y = dock.Top \+ \(dock.Bottom - dock.Top\) \* 3 \/ 4;/);
  assert.match(source, /graphics.CopyFromScreen\(x, y, 0, 0, pixels.Size\)/);
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
  assert.match(driver, /PagePainted\(\$docks\[0\], \$rgb\[0\]\)/);
}

test('paint is an actual target-colored 3x3 screen patch below the toolbar, reached by real native omnibox input', () => {
  assertsPaint(native, journey);
  for (const before of ['graphics.CopyFromScreen(x, y, 0, 0, pixels.Size)', 'row < pixels.Height', 'col < pixels.Width', 'dock.Bottom - dock.Top < 200']) {
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
  assert.match(source, /foreach \(\$pair in \$gaps\) \{ if \(\$pair.gap_ms -gt 50\) \{ throw \$gapCase.detail \} \}/);
  assert.match(source, /name = 'switch-gap'; status = 'failed';[^\n]+phase = 'initial-console'/);
  assert.match(source, /catch \{\s+\$gapCase.detail = \$gapCase.phase \+ ': ' \+ \$_\.Exception.Message\s+throw\s+\} finally \{/);
  assert.match(source, /finally \{[\s\S]+Save-Json \$timings 'switch-timings.json'/);
  assert.match(source, /window_visible_median_ms = Get-SwitchMedian \$timings\[\$mode\].window_visible_ms/);
  assert.doesNotMatch(source, /SetForegroundWindow|SendMessage|PostMessage|Set-Content[^\n]*session.json|Start-Sleep/);
}

test('four warm twenty-sample and two frozen five-sample sets enforce all matching 50ms gaps and retain null failure evidence', () => {
  assertsJourney(journey);
  for (const [before, after] of [
    ['$sample -lt $sampleCount', '$sample -lt 2'], ['$pair.gap_ms -gt 50', '$pair.gap_ms -gt 500'],
    ["$pane.browser_state -eq 'connected'", '$true'], ['finally {', 'if ($false) {'],
    ["name = 'switch-gap'; status = 'failed'", "name = 'switch-gap'; status = 'passed'"],
    ["@('chat_browser_off', 'chat_browser_on')", "@('browser_off', 'browser_on')"],
  ]) assert.throws(() => assertsJourney(journey.replace(before, after)));
  const gapLimit = Number(journey.match(/if \(\$pair.gap_ms -gt (\d+)\)/)[1]);
  for (const [off, on, fails] of [[10, 60, false], [10, 60.001, true], [100, 90, false]]) assert.equal(on - off > gapLimit, fails);
  const median = control.slice(control.indexOf('function Get-SwitchMedian'), control.indexOf('function Doctor'));
  assert.match(median, /foreach \(\$value in \$Values\) \{ if \(\$null -eq \$value\) \{ return \$null \} \}/);
  assert.match(median, /Sort-Object/);
  assert.match(median, /\(\[double\]\$sorted\[\$middle - 1\] \+ \[double\]\$sorted\[\$middle\]\) \/ 2/);
});

function assertsOptionalTrace(source) {
  assert.match(source, /\$timings.steps\[\$mode\] = \$null/);
  assert.match(source, /\$steps = \$null\s+if \(\$traceMatches.Count -eq 1\) \{/);
  assert.match(source, /\$traces\[\$mode\] \+= \$steps/);
  assert.match(source, /\$traces\[\$mode\].Count -eq \$timings\[\$mode\].samples_ms.Count -and @\(\$traces\[\$mode\] \| Where-Object \{ \$null -eq \$_ \}\).Count -eq 0/);
  assert.match(source, /\$timings.steps\[\$mode\]\[\$step\] = Get-SwitchMedian \$values/);
  assert.match(source, /Save-Json \$traces 'switch-traces.json'/);
  assert.match(source, /switch-timing-debug.log/);
  assert.doesNotMatch(source, /matching per-switch debug timing|Incomplete switch-timing|Expected exactly one switch-timing|Wait-Until[^\n]*switch-timing/);
}

test('older releases without timing traces still retain real samples and null steps, without waiting or failing', () => {
  assertsOptionalTrace(journey);
  for (const [before, after] of [
    ['$steps = $null', '$steps = @{}'], ['$timings.steps[$mode] = $null', '$timings.steps[$mode] = @{}'],
    ['$traceMatches.Count -eq 1', '$traceMatches.Count -ne 1'],
    ["$traces[$mode] += $steps", "throw 'Expected exactly one switch-timing'"],
  ]) assert.throws(() => assertsOptionalTrace(journey.replace(before, after)));
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
  assert.match(journey, /Focus-Palette 'clear always view for this session' 6466/);
  assert.doesNotMatch(journey, /Focus-Palette 'per tab' 6345/);
  assert.match(journey, /Press @\(0x12, 0x41\) 'Alt\+A: close browser pane for Chat View baseline'\s+\$null = Assert-BrowserPane 'closed' \('chat-baseline-' \+ \$tab\)/);
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

function assertsDispatchOnly(source) {
  const matrix = JSON.parse(source.match(/matrix:[\s\S]+?fromJSON\('(\[[^']+\])'\)/)[1]);
  assert.equal(matrix.includes('browser-switch-speed'), false);
  assert.match(source, /workflow_dispatch:[\s\S]+feature:/);
  assert.match(source, /fromJSON\(format\('\["\{0\}"\]', inputs\.feature\)\)/);
  assert.match(source, /FEATURE -notin @\([^\n]*'browser-switch-speed'/);
}

test('switch timing is dispatch-only while allowlists and artifact contracts retain it', () => {
  assertsDispatchOnly(workflow);
  assert.throws(() => assertsDispatchOnly(workflow.replace('["appearance",', '["browser-switch-speed", "appearance",')));
  assert.throws(() => assertsDispatchOnly(workflow.replace('inputs.feature))', 'inputs.other))')));
  assert.match(workflow, /FEATURE -notin @\([^\n]*'browser-switch-speed'/);
  assert.match(control, /ValidateSet\([^\n]*'browser-switch-speed'/);
  assert.match(workflow, /name: verify-\$\{\{ env.FEATURE \}\}/);
  assert.match(workflow, /node --test tools\/verify-multiprompt.test.js[^\n]+tools\/browser-switch-speed.test.js/);
  assert.match(workflow, /paths:[\s\S]*?- tools\/browser-switch-speed.test.js/);
  assert.match(control, /if \(\$Feature -in @\('browser-pane-stuck', 'pane-layout', 'browser-pane-locked', 'browser-switch-speed'\)\)/);
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
  const timeout = yaml.match(/timeout-minutes: \$\{\{ matrix.feature == 'browser-switch-speed' && (\d+) \|\| (\d+) \}\}/);
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
  const setup = driver.slice(driver.indexOf("    if ($Feature -eq 'browser-switch-speed') {"), driver.indexOf("    $env:IGSH_246 = '0'"));
  for (const step of [
    "Join-Path $env:USERPROFILE 'Documents/GitHub/zigshell/extension'",
    "Copy-Item (Join-Path $PSScriptRoot '../../../extension') $extension -Recurse",
    'Add-Member -NotePropertyName key -NotePropertyValue $publicKey -Force',
    'allowed_origins = @("chrome-extension://$extensionId/")',
    "path = (Join-Path (Split-Path $Exe) 'zigshell-bridge.exe')",
    'HKCU:\\Software\\Google\\Chrome\\NativeMessagingHosts\\com.zigshell.bridge',
    "if (Test-Path $registry) { throw 'Switch timing requires an unregistered disposable native host' }",
    '$switchNativeRegistry = $registry', 'New-Item -Path $registry -Force', 'Set-Item -Path $registry -Value $nativeManifest',
  ]) assert.ok(setup.includes(step), step);
  assert.match(driver, /if \(\$Feature -ne 'browser-switch-speed' -and \$pane.browser_window_id -ne 0\)/);
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
    "Copy-Item (Join-Path $PSScriptRoot '../../../extension') $extension -Recurse",
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
  const setup = driver.slice(driver.indexOf("    if ($Feature -eq 'browser-switch-speed') {"), driver.indexOf("    $env:IGSH_246 = '0'"));
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

test('a completed warm pair can fail fast at the same threshold while every successful run still checks every warm and frozen pair', () => {
  const earlyStart = journey.indexOf("\n                    if ($mode -eq 'browser_on') {");
  assert.ok(earlyStart >= 0);
  const early = journey.slice(earlyStart, journey.indexOf('foreach ($mode in $modes) { $timings[$mode].median_ms'));
  for (const literal of ['Get-SwitchMedian $timings.browser_off.samples_ms', 'Get-SwitchMedian $timings.browser_on.samples_ms', 'if ($onMedian - $offMedian -gt 50)', "$gapCase.phase = 'switch-gap'", 'throw $gapCase.detail']) assert.ok(early.includes(literal), literal);
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
