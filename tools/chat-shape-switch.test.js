const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = name => {
  const file = path.join(__dirname, '..', name);
  assert.ok(fs.existsSync(file), `Missing native switching support: ${name}`);
  return fs.readFileSync(file, 'utf8');
};
const control = read('.claude/skills/verify-multiprompt/control.ps1');
const workflow = read('.github/workflows/verify.yml');
const observer = read('tools/verify-chat-delivery/chat-switch-observer.cs');
const profile = read('tools/verify-chat-delivery/chat-switch-profile.ps1');

function defaultPath(source) {
  assert.match(source, /else \{\s+& \$env:MP_VERIFY_PYTHON \$env:MP_VERIFY_BOUNDARY shell seed-many 400/);
  assert.match(source, /else \{\s+\$measured = \[VerifyNative\]::SwitchToSession\(/);
  assert.ok(source.includes("else { Join-Path $PSScriptRoot '../../../extension' }"));
  assert.ok(source.includes('$timings[$mode].median_ms -gt $chatLimitMs'));
  assert.ok(source.includes('$timings[$mode].max_hang_ms -gt $hangLimitMs'));
  assert.ok(source.includes('$timings[$mode].first_frame_wrong_width -gt 0'));
  assert.ok(source.includes('$timings[$mode].moved_after_first_frame -gt 0'));
}

test('IGSH-1040 keeps the original fixture, native input, extension and assertions when opt-in is absent', () => {
  defaultPath(control);
  assert.throws(() => defaultPath(control.replace('shell seed-many 400', 'shell seed-many 1')));
  assert.throws(() => defaultPath(control.replace('$timings[$mode].max_hang_ms -gt $hangLimitMs', '$false')));
});

test('IGSH-1040 opt-in keeps published946 app, bridge and extension together and uses ReleaseSmall for the candidate', () => {
  assert.match(workflow, /chat_shape_proof:[\s\S]*?default: false/);
  assert.match(workflow, /chat_switch_profile:[\s\S]*?default: false/);
  assert.ok(workflow.includes("$env:RELEASE_TAG -ne 'v0.28.946'"));
  assert.ok(workflow.includes("env.CHAT_SHAPE_PROOF == '1' && '-Doptimize=ReleaseSmall'"));
  assert.ok(workflow.includes('git archive --format=zip "--output=$archive" $env:RELEASE_TAG extension'));
  assert.ok(workflow.includes("'45bef2a5da04ef62f4e3a2789467b17adb6ee4e38db3d6fc34916beef6f700cd'"));
  assert.ok(control.includes('$extensionSource = if ($shapeProof -and $env:VERIFY_EXTENSION_ROOT) { $env:VERIFY_EXTENSION_ROOT }'));
  assert.ok(control.includes('Copy-Item $extensionSource $extension -Recurse'));
  assert.ok(workflow.includes('chat-shapes-test.py'));
  assert.ok(workflow.includes('chat-switch-evidence-test.py'));
});

test('IGSH-1040 ordinary CPU windows do not request paints or capture images', () => {
  assert.doesNotMatch(observer, /InvalidateRect|WM_PAINT|0x000F|DwmFlush|RedrawWindow/);
  assert.match(observer, /if \(images\) \{\s+captureStarted[\s\S]*?Capture\(owner, pid/);
  assert.match(observer, /if \(images\) Capture\(owner, pid, imagePrefix \+ "-settled"\)/);
  assert.match(observer, /"cpu_one_core_percent", 100 \* cpu \/ elapsed/);
  assert.doesNotMatch(observer, /ProcessorCount/);
  assert.match(observer, /GetForegroundWindow\(\) != owner/);
});

test('IGSH-1040 replay and copied receipt stay outside the ordinary measurement call', () => {
  const ordinary = control.indexOf('$shapeSample = [ChatSwitchObserver]::Measure(');
  const replay = control.indexOf('$image = [ChatSwitchObserver]::Measure(', ordinary);
  const receipt = control.indexOf('Save-ShapeLatest $shapeSample.expected_latest', replay);
  assert.ok(ordinary > 0 && replay > ordinary && receipt > replay);
  assert.ok(control.slice(ordinary, replay).includes('$settleMs, $null)'));
  assert.ok(control.slice(ordinary, replay).includes('same source painted before image replay'));
  assert.match(control, /\$latest = \[regex\]::Match\(\$copied,/);
  assert.match(control, /\$last = \[regex\]::Match\(\$copied,/);
  assert.ok(observer.includes('not compositor-first-present'));
});

function ownedProfile(source) {
  const status = source.indexOf('$recorder -status');
  const idle = source.indexOf("if ($status -notmatch", status);
  const start = source.indexOf('$recorder -start CPU -filemode', idle);
  const owned = source.indexOf('$started = $true', start);
  const replay = source.indexOf('$observation.switch = & $Switch', owned);
  const guard = source.indexOf('if ($started)', replay);
  const stop = source.indexOf('$recorder -stop $trace', guard);
  assert.ok(status >= 0 && idle > status && start > idle && owned > start && replay > owned && guard > replay && stop > guard);
  assert.ok(source.includes('analyzed = $false'));
  assert.ok(source.includes('separate_from_acceptance = $true'));
  assert.doesNotMatch(source, /-cancel|Stop-Process|taskkill/);
}

test('IGSH-1040 profile capture refuses ambiguous recorder ownership and never calls a global cancel', () => {
  ownedProfile(profile);
  assert.throws(() => ownedProfile(profile.replace('if ($started)', 'if ($true)')));
  assert.throws(() => ownedProfile(profile + '\nwpr -cancel'));
  assert.ok(control.indexOf('Invoke-ChatSwitchProfile -TargetProcessId') > control.indexOf('$shapeResult.idle.after ='));
  assert.ok(control.includes('$slow = $allSamples | Sort-Object -Property @{ Expression = { [double]$_.shown_ms } } -Descending | Select-Object -First 1'));
});

test('IGSH-1040 final evidence is checked after cleanup even when the measured budgets fail', () => {
  assert.match(workflow, /name: Check real-shape observations after owned cleanup\s+if: always\(\) && env.CHAT_SHAPE_PROOF == '1'/);
  assert.ok(workflow.includes('chat-switch-evidence.py evidence/shape-switch.json --require-cleanup'));
});

test('IGSH-1040 every direct observer call restores the exact owned foreground before timing', () => {
  const journey = control.slice(control.indexOf("        'chat-switch-speed' {"), control.indexOf("        'chat-switch-speed' {") + 40000);
  const calls = [...journey.matchAll(/\[ChatSwitchObserver\]::Measure\(/g)];
  assert.equal(calls.length, 5);
  for (const call of calls) {
    assert.match(journey.slice(0, call.index).split('\n').slice(-2, -1).join(''), /^\s*Wait-SwitchForeground$/);
  }
  const helper = journey.slice(journey.indexOf('function Wait-SwitchForeground {'), journey.indexOf('function Test-TabChat('));
  assert.match(helper, /Doctor[\s\S]*Wait-Until/);
  assert.match(helper, /if \(\[VerifyNative\]::GetForegroundWindow\(\) -ne \$script:window\) \{[\s\S]*\[VerifyNative\]::BringToForeground\(\$script:window\)/);
  assert.match(helper, /\[VerifyNative\]::GetForegroundWindow\(\) -eq \$script:window/);
  assert.match(helper, /'owned main window foreground before switch observation' 10/);
});

test('IGSH-1040 PowerShell empty-string binding keeps ordinary CPU samples image-free', () => {
  assert.match(observer, /bool images = ![Ss]tring\.IsNullOrEmpty\(imagePrefix\);/);
});

test('IGSH-1040 native idle observer accepts PowerShell null and empty image paths without capture', { skip: process.platform !== 'win32' }, () => {
  const { spawnSync } = require('node:child_process');
  const source = path.join(__dirname, 'verify-chat-delivery/chat-switch-observer.cs').replaceAll("'", "''");
  const result = spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', `
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -Path '${source}'
$form = New-Object Windows.Forms.Form
try {
  $form.Show()
  $form.Activate()
  [Windows.Forms.Application]::DoEvents()
  foreach ($prefix in @($null, '')) {
    $sample = [ChatSwitchObserver]::Measure($PID, $form.Handle, -1, '', 0, '', 1, $prefix)
    if ($sample.image_probe -or $sample.input -ne 'idle') { throw 'Ordinary idle window attempted image capture' }
  }
  $refused = $false
  try { [void][ChatSwitchObserver]::Measure($PID, $form.Handle, -1, '', 0, '', 1, 'capture') }
  catch {
    if ($_.Exception.Message -notmatch 'Image replay needs a real target') { throw }
    $refused = $true
  }
  if (-not $refused) { throw 'Real image replay accepted an idle target' }
  'POWERSHELL_IDLE_IMAGE_BINDING_PROVEN'
} finally { $form.Dispose() }
`], { encoding: 'utf8', timeout: 30000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /POWERSHELL_IDLE_IMAGE_BINDING_PROVEN/);
});

test('IGSH-1040 receipts follow seeded session identity, not saved-tab position', () => {
  const helper = control.slice(control.indexOf('            function Add-SeedTurn('), control.indexOf('            $result.checks += $gapCase', control.indexOf('            function Add-SeedTurn(')));
  assert.ok(helper.includes('$seed.sids.PSObject.Properties[$SessionName].Value'));
  assert.ok(helper.includes('[Array]::IndexOf(@($seed.sessions), $SessionName)'));
  assert.ok(control.includes('$shapeSample.expected_latest = $seedTurn.expected_latest'));
  assert.ok(control.includes('$shapeSample.last_marker = $seedTurn.last_marker'));
  assert.doesNotMatch(helper, /SessionName -replace|0927-4000/);
});

test('IGSH-1040 reordered saved tabs append and verify only their mapped transcript', { skip: process.platform !== 'win32' }, () => {
  const { spawnSync } = require('node:child_process');
  const helper = control.slice(control.indexOf('            function Add-SeedTurn('), control.indexOf('            $result.checks += $gapCase', control.indexOf('            function Add-SeedTurn(')));
  const result = spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', `
$ErrorActionPreference = 'Stop'
$scratch = Join-Path $env:TEMP ('receipt-' + [guid]::NewGuid().ToString('N'))
$remoteState = Join-Path $scratch 'remote'
try {
  New-Item -ItemType Directory -Path $remoteState | Out-Null
  $names = @('session-blue', 'session-green', 'session-red', 'session-gold', 'session-grey')
  $ids = @{}
  for ($i = 0; $i -lt 5; $i++) {
    $ids[$names[$i]] = 'stable-id-' + $i
    $folder = Join-Path $scratch ('profile/.claude/projects/C--verify-work' + $i)
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $folder ($ids[$names[$i]] + '.jsonl')), '')
  }
  @{ sessions = $names; sids = $ids } | ConvertTo-Json | Set-Content (Join-Path $remoteState 'state.json')
  ${helper}
  foreach ($i in @(4, 0, 1, 2, 3)) {
    $receipt = Add-SeedTurn $names[$i] 7
    $file = Join-Path $scratch ('profile/.claude/projects/C--verify-work' + $i + '/stable-id-' + $i + '.jsonl')
    $row = Get-Content $file -Raw | ConvertFrom-Json
    if ($receipt.session_id -ne $row.sessionId -or $row.sessionId -ne $ids[$names[$i]]) { throw 'Wrong transcript identity' }
    if (-not $row.message.content[0].text.StartsWith($receipt.expected_latest)) { throw 'Receipt differs from appended text' }
    if ($receipt.last_marker -ne ('IGSH1040_LAST_' + ($i + 1))) { throw 'Wrong seeded endpoint' }
  }
  'REORDERED_SESSION_RECEIPTS_PROVEN'
} finally { if (Test-Path $scratch) { Remove-Item $scratch -Recurse -Force } }
`], { encoding: 'utf8', timeout: 30000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /REORDERED_SESSION_RECEIPTS_PROVEN/);
});

test('IGSH-1040 receipts use existing owned app copy commands, not keyboard focus timing', () => {
  const receipt = control.slice(control.indexOf('function Save-ShapeLatest('), control.indexOf('function Wait-SwitchForeground'));
  assert.ok(receipt.includes('[ChatSwitchObserver]::CopyTranscript($process.Id, $script:window)'));
  assert.doesNotMatch(receipt, /KeyDown|KeyUp|Focus-Palette/);
  assert.ok(observer.includes('actual != pid || GetForegroundWindow() != owner'));
  assert.ok(observer.includes('new uint[] { 0x8000 + 149, 0x8000 + 148 }'));
  assert.ok(observer.includes('PostMessage(owner, message, UIntPtr.Zero, IntPtr.Zero)'));
  assert.doesNotMatch(observer, /SendMessageTimeout/);
  assert.match(read('src/win32.zig'), /WM_APP_CHAT_SELECT_ALL: u32 = WM_APP \+ 149/);
  assert.match(read('src/win32.zig'), /WM_APP_CHAT_COPY_SELECTION: u32 = WM_APP \+ 148/);
  assert.ok(receipt.includes("if (-not $last.Success) { throw 'Copied target transcript belongs to a different seeded session' }"));
});

test('IGSH-1040 shape timing clicks the owned sidebar row instead of a keyboard substitute', () => {
  assert.ok(observer.includes('"idle" : "sidebar-click"'));
  assert.ok(observer.includes('WindowFromPoint(point) != owner'));
  assert.ok(observer.includes('GetDpiForWindow(owner) != 96'));
  assert.ok(observer.includes('new Point { X = 100, Y = 8 + SidebarHeaderHeight + 24 + 38 * target + 19 }'));
  assert.ok(observer.includes('new Mouse { Flags = 2 }'));
  assert.ok(observer.includes('new Mouse { Flags = 4 }'));
  assert.doesNotMatch(observer.slice(observer.indexOf('if (target >= 0) {'), observer.indexOf('long position = offset;')), /Keyboard =/);
  assert.ok(control.includes('Sidebar timing requires the default ungrouped five-row fixture at 96 DPI'));
  assert.ok(control.includes("[ChatSwitchObserver]::SidebarHeaderHeight = if ($env:RELEASE_TAG -eq 'v0.28.946') { 0 } else { 52 }"));
  assert.match(read('src/workspace_switcher.zig'), /pub fn headerHeight\(\)[^]*?scale\(52\)/);
  assert.match(read('src/sidebar.zig'), /var y:[^;]*workspace_switcher\.zig[^;]*headerHeight\(\)/);
});
