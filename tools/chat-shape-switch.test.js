const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = name => fs.readFileSync(path.join(__dirname, '..', name), 'utf8');
const control = read('.claude/skills/verify-multiprompt/control.ps1');
const workflow = read('.github/workflows/verify.yml');
const observer = read('tools/verify-chat-delivery/chat-switch-observer.cs');
const profile = read('tools/verify-chat-delivery/chat-switch-profile.ps1');

function defaultPath(source) {
  assert.match(source, /else \{\s+& \$env:MP_VERIFY_PYTHON \$env:MP_VERIFY_BOUNDARY shell seed-many 400/);
  assert.match(source, /else \{\s+\$measured = \[VerifyNative\]::SwitchToSession\(/);
  assert.match(source, /Copy-Item \(Join-Path \$PSScriptRoot '\.\.\/\.\.\/\.\.\/extension'\) \$extension -Recurse/);
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
  assert.match(control, /if \(\$shapeProof -and \$env:VERIFY_EXTENSION_ROOT\) \{\s+Copy-Item \$env:VERIFY_EXTENSION_ROOT/);
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
  const receipt = control.indexOf('Save-ShapeLatest $shapeSample.expected_latest', ordinary);
  const replay = control.indexOf('$image = [ChatSwitchObserver]::Measure(', receipt);
  assert.ok(ordinary > 0 && receipt > ordinary && replay > receipt);
  assert.ok(control.slice(ordinary, receipt).includes('$settleMs, $null)'));
  assert.ok(control.slice(receipt, replay).includes('same source painted before image replay'));
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
