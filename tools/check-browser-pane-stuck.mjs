import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8').replace(/\r\n/g, '\n');
const directory = '.claude/skills/verify-multiprompt';
const driver = read(`${directory}/control.ps1`);
const workflow = read('.github/workflows/verify.yml');
const map = read(`${directory}/features/browser-pane-stuck.md`);

for (const [file, names] of [
  ['src/browser_pane.zig', [
    'IGSH-523 opening close keeps URL, reopen isolates replies, timeout permits retry',
    'IGSH-523 connected pane stays visible without an extension past the opening deadline',
    'IGSH-523 cancelled launches reuse expired slots and evict oldest when full',
    'IGSH-523 docked pane without an extension never resolves on health ticks',
    'IGSH-523 adoption retries preserve the first opening deadline',
    'IGSH-523 bench launch guard does not arm an opening deadline',
    'browserPlaceholderPure applies the deadline only to uncovered slots',
  ]],
  ['src/shortcuts.zig', [
    'Alt browser open guard rejects a delayed complete second chord',
    'Alt browser shortcut recovers an enabled pane with no live window',
  ]],
]) {
  assert.ok(read('src/main.zig').includes(`_ = @import("${path.basename(file)}");`), `${file} is in the desktop unit suite`);
  for (const name of names) assert.ok(read(file).includes(`test "${name}"`), `behavior unit exists: ${name}`);
}

function prMatrixContract(source) {
  assert.match(source, /feature:.*github\.event_name == 'pull_request'.*fromJSON\('\["appearance", "browser-pane-stuck"\]'\)/);
  assert.ok(source.includes('FEATURE: ${{ matrix.feature }}'));
  for (const trigger of ['src/**', 'tools/check-browser-pane-stuck.mjs']) assert.ok(source.includes(`      - ${trigger}`));
}
prMatrixContract(workflow);
assert.throws(() => prMatrixContract(workflow.replace('["appearance", "browser-pane-stuck"]', '["appearance"]')));

const featureFiles = fs.readdirSync(path.join(root, directory, 'features')).filter(name => name.endsWith('.md') && name !== 'README.md');
const index = read(`${directory}/features/README.md`);
const allowed = driver.match(/ValidateSet\(([^)]*)\)/)?.[1].match(/'([^']+)'/g).map(value => value.slice(1, -1));
assert.deepEqual([...allowed].sort(), featureFiles.map(file => file.slice(0, -3)).sort());
for (const file of featureFiles) {
  const name = file.slice(0, -3);
  assert.ok(index.includes(`](${file})`), `index lists ${name}`);
  assert.ok(workflow.includes(`'${name}'`), `workflow allows ${name}`);
  assert.ok(driver.includes(`        '${name}' {`), `driver implements ${name}`);
}
for (const section of ['Sub-features', 'How to get to it (user POV)', 'Driving it with control.ps1', 'Gotchas']) {
  assert.ok(map.includes(`## ${section}`), `feature map has ${section}`);
}
for (const step of ['initial-open', 'shortcut-close', 'reopen-after-shortcut', 'palette-close-all', 'palette-close-pane', 'reopen-after-close-pane', 'connected-pane-docked', 'connected-pane-stays-visible', 'shift-a-toggle', 'shift-b-toggle', 'final-close']) {
  assert.ok(driver.includes(`'${step}'`), `journey asserts ${step}`);
}
for (const observation of ['GetProp(hwnd, "ZigShellPaneOwner")', 'IsWindowVisible(hwnd)', 'GetWindowRect(hwnd, out pane)', 'AddSeconds(21)', 'Assert-ConnectedPaneStaysVisible $fourth.browser_connection_id']) {
  assert.ok(driver.includes(observation), `connected journey observes ${observation}`);
}
for (const input of ['Press @(0x12, 0x41)', "Palette 'close all browser panes'", 'Press @(0x12, 0x10, 0x41)', 'Press @(0x12, 0x10, 0x42)']) {
  assert.ok(driver.includes(input), `real input: ${input}`);
}
function foregroundInputContract(source) {
  const press = source.slice(source.indexOf('function Press('), source.indexOf('function Type-Text('));
  assert.match(press, /Doctor\s+if \(\$Feature -eq 'browser-pane-stuck'\) \{\s+\[void\]\[VerifyNative\]::SetForegroundWindow\(\$script:window\)\s+Wait-Until \{ \[VerifyNative\]::GetAncestor\(\[VerifyNative\]::GetForegroundWindow\(\), 2\) -eq \$script:window \}/);
  assert.match(press, /\}\s+Assert-Foreground\s+Record \$Label\s+\[VerifyNative\]::Chord\(\$Keys\)/);
}
foregroundInputContract(driver);
assert.throws(() => foregroundInputContract(driver.replace('[void][VerifyNative]::SetForegroundWindow($script:window)', '')));
assert.throws(() => foregroundInputContract(driver.replace('    Assert-Foreground\n    Record $Label', '    Record $Label')));
function shiftedShortcutTimingContract(source) {
  const debounce = Number(read('src/app_state.zig').match(/BROWSER_TOGGLE_DEBOUNCE_MS: u32 = ([\d_]+);/)?.[1].replaceAll('_', ''));
  assert.ok(Number.isFinite(debounce) && debounce > 0, 'production browser shortcut debounce exists');
  const sequence = source.match(/Press @\(0x12, 0x10, 0x41\)[^\n]*\n\s+\$shiftToggleCooldown = \[Diagnostics.Stopwatch\]::StartNew\(\)\n\s+\$closed = Assert-BrowserPane 'closed' 'shift-a-toggle'\n\s+Wait-Until \{ \$shiftToggleCooldown.ElapsedMilliseconds -ge (\d+) \} 'browser shortcut debounce elapsed' (\d+)\n\s+Press @\(0x12, 0x10, 0x42\)[^\n]*\n\s+\$fifth = Assert-BrowserPane 'open' 'shift-b-toggle' \$fourth.browser_connection_id/);
  assert.ok(sequence, 'shifted shortcuts retain close/new-identity assertions with a bounded monotonic cooldown after the first chord');
  const cooldown = Number(sequence[1]);
  const timeout = Number(sequence[2]) * 1000;
  assert.ok(cooldown > debounce && timeout > cooldown && timeout <= 10000, 'journey waits past production debounce within a bounded timeout');
}
shiftedShortcutTimingContract(driver);
assert.throws(() => shiftedShortcutTimingContract(driver.replace("            Wait-Until { $shiftToggleCooldown.ElapsedMilliseconds -ge 1600 } 'browser shortcut debounce elapsed' 5\n", '')));
assert.throws(() => shiftedShortcutTimingContract(driver.replace('ElapsedMilliseconds -ge 1600', 'ElapsedMilliseconds -ge 1000')));
function browserForegroundContract(source) {
  const helper = source.match(/function Focus-BrowserPaneOwner\([^\n]*\) \{\n([\s\S]*?)\n\}/)?.[1];
  assert.ok(helper, 'browser launches explicitly activate the main window after docking');
  const steps = [
    'Wait-Until {', '$pane = Read-BrowserPane',
    "$null -ne $pane -and $pane.browser_state -eq 'connected' -and",
    '$pane.browser_connection_id -eq $ConnectionId -and [VerifyNative]::PaneVisible($script:window)',
    '} "browser-pane-stuck ${Step}: docked pane ready for main-window activation" 25',
    'Doctor', 'Record "Activate main window after browser-pane-stuck ${Step} docking"',
    '[void][VerifyNative]::SetForegroundWindow($script:window)',
    'Wait-Until { [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window } "browser-pane-stuck ${Step}: main window is foreground" 5',
  ];
  let offset = -1;
  for (const step of steps) {
    const next = helper.indexOf(step, offset + 1);
    assert.ok(next > offset, `missing or misordered foreground handoff: ${step}`);
    offset = next;
  }
  assert.match(source, /function Open-BrowserPane\([^\n]*\) \{\s*Palette 'open browser'\s*Press @\(0x0D\) 'Enter: Open Browser Pane'\s*\$pane = Assert-BrowserPane 'open' \$Step \$PreviousId\s*Focus-BrowserPaneOwner \$Step \$pane.browser_connection_id\s*return \$pane\s*\}/);
  assert.match(source, /\$fifth = Assert-BrowserPane 'open' 'shift-b-toggle' \$fourth.browser_connection_id\s*Focus-BrowserPaneOwner 'shift-b-toggle' \$fifth.browser_connection_id\s*Palette 'close all browser panes'/);
  assert.match(source, /function Assert-Foreground \{\s*if \(\[VerifyNative\]::GetAncestor\(\[VerifyNative\]::GetForegroundWindow\(\), 2\) -ne \$script:window\) \{ throw 'Refusing input: owned app is not foreground' \}\s*\}/);
  for (const name of ['Press', 'Type-Text']) {
    assert.match(source, new RegExp(`function ${name}\\([^\\n]*\\) \\{\\s*Doctor\\s*(?:Wait-Until \\{[^}]*\\} '[^']*'\\s*)?Assert-Foreground\\s*Record`));
  }
}
browserForegroundContract(driver);
for (const [before, after] of [
  ["$pane.browser_state -eq 'connected' -and", "$pane.browser_state -eq 'opening' -and"],
  ['$pane.browser_connection_id -eq $ConnectionId -and ', ''],
  [' -and [VerifyNative]::PaneVisible($script:window)', ''],
  ['docked pane ready for main-window activation" 25', 'docked pane ready for main-window activation"'],
  ['    Focus-BrowserPaneOwner $Step $pane.browser_connection_id\n', ''],
  ["            Focus-BrowserPaneOwner 'shift-b-toggle' $fifth.browser_connection_id\n", ''],
  ["throw 'Refusing input: owned app is not foreground'", 'return'],
  ['    Assert-Foreground\n    Record $Label', '    Record $Label'],
]) assert.throws(() => browserForegroundContract(driver.replace(before, after)), `reject foreground regression: ${before}`);
const activation = '    [void][VerifyNative]::SetForegroundWindow($script:window)\n';
const earlyActivation = driver.replace(activation, '').replace('function Focus-BrowserPaneOwner([string]$Step, [long]$ConnectionId) {\n', `function Focus-BrowserPaneOwner([string]$Step, [long]$ConnectionId) {\n${activation}`);
assert.throws(() => browserForegroundContract(earlyActivation), 'activation before docking repeats the original race');
function scratchCleanupContract(source) {
  assert.ok(source.includes('$script:scratchLinks = @()'), 'reparse evidence starts with an empty list');
  const prepare = source.match(/function Prepare-ScratchEvidence\([^\n]*\) \{\n([\s\S]*?)\n\}/)?.[1];
  assert.ok(prepare, 'scratch is prepared without traversing protected WinINet compatibility links');
  assert.ok(prepare.includes('foreach ($entry in Get-ChildItem -LiteralPath $Path -Force) {'));
  assert.ok(!prepare.includes('-Recurse'), 'enumeration cannot enter a reparse point before inspecting it');
  assert.match(prepare, /if \(\(\$entry.Attributes -band \[IO.FileAttributes\]::ReparsePoint\) -ne 0\) \{\s*\$script:scratchLinks \+= @\{ path = \$entry.FullName.Substring\(\$scratch.Length \+ 1\); attributes = \$entry.Attributes.ToString\(\); linkType = \$entry.LinkType; target = @\(\$entry.Target\) \}\s*Save-Json @\(\$script:scratchLinks\) 'scratch-links.json'\s*\$entry.Delete\(\)/);
  assert.match(prepare, /\} else \{\s*\$entry.Attributes = \$entry.Attributes -band \(-bnot \$blockedAttributes\)\s*if \(\$entry -is \[IO.DirectoryInfo\]\) \{ Prepare-ScratchEvidence \$entry.FullName \}/);
  assert.ok(prepare.includes('$blockedAttributes = [IO.FileAttributes]::ReadOnly -bor [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System'));
  const cleanup = source.slice(source.indexOf("    $result.status = 'passed'"));
  let offset = -1;
  for (const step of [
    '$stopped = $job.Stop()', "'process-tree.json'", 'Prepare-ScratchEvidence $scratch',
    "Copy-Item (Join-Path $scratch '*') $data -Recurse -Force; break",
    'Remove-Item $scratch -Recurse -Force', '$result.scratchRemoved = -not (Test-Path $scratch)',
    "if (-not $result.scratchRemoved) { throw 'Scratch directory still exists' }",
    "foreach ($name in @('before.png', 'action.png', 'after.png', 'doctor.json', 'actions.json'))",
    'throw "Evidence lost during cleanup: $name"',
  ]) {
    const next = cleanup.indexOf(step, offset + 1);
    assert.ok(next > offset, `missing or misordered scratch cleanup: ${step}`);
    offset = next;
  }
}
scratchCleanupContract(driver);
for (const [before, after] of [
  ['                    Prepare-ScratchEvidence $scratch\n', ''],
  ['Get-ChildItem -LiteralPath $Path -Force', 'Get-ChildItem -LiteralPath $Path -Force -Recurse'],
  ["            Save-Json @($script:scratchLinks) 'scratch-links.json'\n", ''],
  ['$entry.Delete()', '$entry.Delete($true)'],
  ['[IO.FileAttributes]::ReparsePoint) -ne 0', '[IO.FileAttributes]::ReparsePoint) -eq 0'],
  ['$entry.Attributes = $entry.Attributes -band (-bnot $blockedAttributes)', ''],
  ["if (-not $result.scratchRemoved) { throw 'Scratch directory still exists' }", ''],
  ['throw "Evidence lost during cleanup: $name"', ''],
]) assert.throws(() => scratchCleanupContract(driver.replace(before, after)), `reject scratch cleanup regression: ${before}`);
function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, `${name} exists`);
  const end = source.indexOf('\n}', start);
  assert.notEqual(end, -1, `${name} has a body`);
  return source.slice(start, end + 2);
}
const pane = read('src/browser_pane.zig');
function healthContract(source) {
  assert.ok(!body(source, 'browserHealthTick').includes('startBrowserWindowResolve('), 'health ticks never spawn resolve workers');
  assert.ok(body(source, 'adoptBrowserTick').includes('startBrowserWindowResolve(target)'), 'adoption still resolves once');
  const unit = source.slice(source.indexOf('test "IGSH-523 docked pane without an extension never resolves on health ticks"'));
  for (const observation of ['CreateWindowExW(0, L("STATIC")', 'for (0..5)', 'browserHealthTick();', 'entry.shell_id', 'browser_window_id']) {
    assert.ok(unit.includes(observation), `health regression observes ${observation}`);
  }
}
healthContract(pane);
assert.throws(() => healthContract(pane.replace('pub fn browserHealthTick() void {', 'pub fn browserHealthTick() void {\n    startBrowserWindowResolve(0);')));
function placeholderContract(source) {
  const pure = body(source, 'browserPlaceholderPure');
  assert.ok(pure.includes('shown_ms >= BROWSER_PLACEHOLDER_NOT_OPEN_MS and !launch_in_flight) return .not_open;'));
  assert.ok(!pure.includes('.failed'), 'an uncovered live slot is not a failed launch');
  assert.ok(body(source, 'currentBrowserPlaceholder').includes('if (sh.browser_open_failed) return .failed;'));
  assert.ok(body(source, 'paintBrowserPlaceholder').includes('L("Browser not open — Alt+W to open")'));
  assert.ok(body(source, 'browserPlaceholderClick').includes('if (currentBrowserPlaceholder() != .failed) return false;'));
}
placeholderContract(pane);
assert.throws(() => placeholderContract(pane.replace('return .not_open;', 'return .failed;')));
function openingClockContract(source) {
  assert.ok(body(source, 'beginBrowserOpening').includes('if (sh.browser_first_launch_tick == 0) sh.browser_first_launch_tick = now;'));
  assert.ok(body(source, 'resetBrowserConnection').includes('sh.browser_first_launch_tick = 0;'));
  const expires = body(source, 'browserOpeningExpired');
  assert.ok(expires.includes('sh.browser_hwnd == null and sh.browser_first_launch_tick != 0'));
  assert.ok(expires.includes('now -| sh.browser_first_launch_tick >= BROWSER_PLACEHOLDER_NOT_OPEN_MS'));
  const adopt = body(source, 'adoptBrowserTick');
  const timeout = adopt.slice(adopt.indexOf('if (now >= app_state.g_browser_adopt_deadline) {'));
  assert.ok(timeout.includes('app_state.shells[target].browser_launch_tick = 0;'));
  assert.ok(!timeout.includes('browser_first_launch_tick'), 'adoption timeout preserves the opening deadline');
  for (const name of ['dockBrowserWindow', 'forgetCrashedBrowserPane']) {
    assert.ok(body(source, name).includes('app_state.shells[idx].browser_first_launch_tick = 0;'));
  }
}
openingClockContract(pane);
assert.throws(() => openingClockContract(pane.replace('if (sh.browser_first_launch_tick == 0) sh.browser_first_launch_tick = now;', 'sh.browser_first_launch_tick = now;')));
assert.throws(() => openingClockContract(pane.replace('        app_state.shells[target].browser_launch_tick = 0;', '')));
function benchContract(source) {
  const tick = body(source, 'chatBenchTick');
  assert.ok(tick.includes('shell.browser_launch_tick = GetTickCount64();'), 'bench keeps master launch suppression');
  assert.ok(tick.includes('shell.browser_first_launch_tick = 0;'), 'bench never arms the opening deadline');
  assert.ok(tick.includes('shell.browser_open_failed = false;'));
}
benchContract(read('src/chat_session.zig'));
assert.throws(() => benchContract(read('src/chat_session.zig').replace('shell.browser_first_launch_tick = 0;', 'shell.browser_first_launch_tick = GetTickCount64();')));
function paletteOpeningContract(source) {
  const start = source.indexOf('public static void OpenAndCloseBrowserPane()');
  assert.notEqual(start, -1);
  const batch = source.slice(start, source.indexOf('    delegate bool EnumWindow', start));
  assert.ok(batch.includes('new string[] { "open browser", "close browser pane" }'));
  assert.equal((batch.match(/SendInput\(/g) || []).length, 1, 'both commands use one input batch');
  assert.ok(!batch.includes('Sleep'), 'no inter-command pauses allow adoption timers');
  assert.ok(source.includes('[VerifyNative]::OpenAndCloseBrowserPane()'));
  assert.ok(source.includes('$fourth.browser_connection_id -le $second.browser_connection_id + 1'), 'the reopen identity proves the batch created an intermediate connection');
  assert.ok(!source.includes("Palette 'close browser pane'"), 'no slow close query races docking');
}
paletteOpeningContract(driver);
assert.throws(() => paletteOpeningContract(driver.replace('new string[] { "open browser", "close browser pane" }', 'new string[] { "close browser pane" }')));
assert.ok(map.includes('the palette closes an opening pane only'));
function inboxPrivacyContract(source) {
  assert.ok(!source.includes('browser_url'), 'inbox must not publish pane URLs');
}
const inbox = read('src/inbox.zig');
const inboxEnd = inbox.indexOf('const tail = "]}";');
assert.ok(inboxEnd > 0, 'inbox serialization boundary exists');
inboxPrivacyContract(inbox.slice(0, inboxEnd));
assert.throws(() => inboxPrivacyContract('const pane_url = "browser_url";'));
assert.ok(!driver.includes('browser_url'), 'journey must not require URL disclosure');
assert.ok(workflow.includes('node tools/check-browser-pane-stuck.mjs'));
assert.ok(read(`${directory}/SKILL.md`).includes('node tools/check-browser-pane-stuck.mjs'));
console.log('browser-pane-stuck checks passed (static wiring only; behavior units and desktop journey require Windows CI)');
