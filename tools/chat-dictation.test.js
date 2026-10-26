const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8').replace(/\r\n/g, '\n');
const skill = '.claude/skills/verify-multiprompt/';
const driver = read(skill + 'control.ps1');
const workflow = read('.github/workflows/verify.yml');
const voice = read('src/voice.zig');

function journeyContract(source) {
  const begin = source.indexOf("        'chat-dictation' {");
  assert.ok(begin >= 0);
  const recipe = source.slice(begin, source.indexOf("        'chat-tables' {", begin));
  let offset = 0;
  for (const step of [
    "Select-Theme 'dark'", "Press @(0x12, 0x43)", "Wait-ChatFocus 'Edit'",
    '$composer.Current.ProcessId -ne $process.Id', '$mic = Get-DictationMic $handle',
    "Assert-DictationMic $mic $false 'dictation-idle'", "Snapshot 'before'",
    "foreach ($stop in @('enter', 'ctrl-d', 'mic-click'))",
    "if ([VerifyNative]::EditText($handle) -cne '') { throw",
    'Press @(0x11, 0x44)', 'fixture-audio-bytes\\t89160$',
    "Assert-DictationMic $micLive $true ($stop + '-listening')", 'Type-Text $typed',
    "[VerifyNative]::EditText($handle) -ceq $typed } 'IGSH-812 typing is accepted while listening' -Seconds 1",
    'GetFocusedWindow($script:window) -ne $handle', "Assert-DictationMic $micLive $true ($stop + '-typed-listening')",
    "Snapshot 'action'", 'Doctor\n                Assert-Foreground',
    '$immediate = [Diagnostics.Stopwatch]::StartNew()',
    "'enter' { [VerifyNative]::Chord(@(0x0D)) }", "'ctrl-d' { [VerifyNative]::Chord(@(0x11, 0x44)) }",
    "'mic-click' { [VerifyNative]::ClickClient($script:window,", "$expected = $typed + ' Go forward ten meters.'",
    "[VerifyNative]::EditText($handle) -ceq $expected } 'IGSH-812 transcript appears immediately without another input' -Seconds 1",
    '$elapsed = $immediate.ElapsedMilliseconds', 'if ($elapsed -gt 1000) { throw',
    'WM_GETTEXT = [VerifyNative]::EditText($handle)', "Assert-DictationMic $mic $false ($stop + '-stopped')",
    "@('audio-bytes\\t89160', 'fixture-response-bytes\\t101', 'http-status\\t200', 'target-chat-composer\\t22')",
    '.Count -ne $iteration) { throw', "Snapshot ($stop + '-delivered')",
    "name = ('dictation-' + $stop); passed = $true; typedWhileListening = $typed",
    'if ($result.checks.Count -ne 3) { throw', "Snapshot 'after'",
  ]) {
    const at = recipe.indexOf(step, offset);
    assert.ok(at >= offset, `missing or misordered ${step}`);
    offset = at + step.length;
  }
  const timed = recipe.slice(recipe.indexOf('$immediate ='), recipe.indexOf('$elapsed ='));
  assert.equal((timed.match(/::Chord\(/g) || []).length, 2);
  assert.equal((timed.match(/::ClickClient\(/g) || []).length, 1);
  assert.doesNotMatch(timed, /Type-Text|Press |Snapshot|Start-Sleep|Get-Content|SetFocus/);
  assert.doesNotMatch(recipe, /Set-Content|WriteAll|PostMessage|SetEnvironmentVariable|\.SetFocus\(|\.SetValue\(|Start-Sleep/);
  const geometry = source.slice(source.indexOf('function Get-DictationMic('), source.indexOf('function Wait-ChatFocus('));
  for (const required of [
    "[VerifyNative]::Class($Composer) -cne 'Edit'", '$transcript.Current.ProcessId -ne $process.Id',
    'GetAncestor($transcriptHandle, 2) -ne $script:window', '$left -lt $edit.Right - $origin.X',
    '[VerifyNative]::GetDpiForWindow($script:window) / 96.0', '::DictationMicPixels(',
    '$pixels[1] -ge 3', '$pixels[0] -gt $pixels[2] / 2', '$pixels[0] -eq 0',
  ]) assert.ok(geometry.includes(required), required);
  const pixels = source.slice(source.indexOf('public static int[] DictationMicPixels('), source.indexOf('public static List<int[]> GreyButtonPixels('));
  for (const required of ['WindowFromPoint(center) != owner', 'graphics.CopyFromScreen(', 'pixels.Save(output,', 'c.R == 63 && c.G == 83 && c.B == 113', 'active ? 80 : 137', 'active ? 150 : 146', 'active ? 255 : 164']) assert.ok(pixels.includes(required), required);
}

test('IGSH-812 real Windows inputs, visible mic pixels and immediate owned native Edit text are mandatory', () => {
  journeyContract(driver);
  for (const required of [
    'Press @(0x11, 0x44)', "'enter' { [VerifyNative]::Chord(@(0x0D)) }",
    "'ctrl-d' { [VerifyNative]::Chord(@(0x11, 0x44)) }", "'mic-click' { [VerifyNative]::ClickClient($script:window,",
    "Assert-DictationMic $micLive $true ($stop + '-listening')", 'Type-Text $typed',
    '[VerifyNative]::EditText($handle) -ceq $typed', '[VerifyNative]::EditText($handle) -ceq $expected',
    'if ($elapsed -gt 1000) { throw', '$pixels[0] -gt $pixels[2] / 2',
    'WindowFromPoint(center) != owner', '$transcript.Current.ProcessId -ne $process.Id',
  ]) {
    const broken = driver.replaceAll(required, 'REMOVED');
    assert.notEqual(broken, driver, required);
    assert.throws(() => journeyContract(broken), assert.AssertionError, required);
  }
});

test('IGSH-846 Windows journey covers Escape discard and restart through real inputs', () => {
  const begin = driver.indexOf("            $draft = [VerifyNative]::EditText($handle)", driver.indexOf("        'chat-dictation' {"));
  const recipe = driver.slice(begin, driver.indexOf("        'chat-tables' {", begin));
  let offset = 0;
  for (const step of [
    "$draft = [VerifyNative]::EditText($handle)",
    "Press @(0x11, 0x44) 'Ctrl+D: start dictation over the existing draft'",
    "Assert-DictationMic $micLive $true 'escape-listening'", "Type-Text ' keep this'",
    'Press @(0x1B, 0x1B)', "'\\tcancel\\t0$'", "'\\taudio-bytes\\t89160$'",
    "Assert-DictationMic $mic $false 'escape-cancelled'",
    "if ([VerifyNative]::EditText($handle) -cne $draft) { throw 'IGSH-846 Escape changed the existing draft' }",
    "Press @(0x11, 0x44) 'Ctrl+D: restart dictation after cancellation'",
    "Assert-DictationMic $micLive $true 'escape-restarted'",
    "throw 'IGSH-846 cancelled transcript arrived late'",
    "throw \"IGSH-846 cancelled recording reached transcription or delivery: $stage\"",
    "Press @(0x0D) 'Enter: transcribe only the restarted recording'",
    "$expected = $draft + ' Go forward ten meters.'",
    "Assert-DictationMic $mic $false 'escape-restart-stopped'",
    "throw \"IGSH-846 restarted recording did not deliver exactly once: $stage\"",
    "'escape-restart.text.json'",
  ]) {
    const at = recipe.indexOf(step, offset);
    assert.ok(at >= offset, `missing or misordered ${step}`);
    offset = at + step.length;
  }
  assert.doesNotMatch(recipe, /Set-Content|WriteAll|PostMessage|SetEnvironmentVariable|\.SetFocus\(|\.SetValue\(|Start-Sleep/);
});

function sendContract(source) {
  const begin = source.indexOf("            Press @(0x11, 0x41) 'Ctrl+A: select the restarted dictation draft before the send cases'");
  assert.ok(begin >= 0);
  const recipe = source.slice(begin, source.indexOf("        'chat-tables' {", begin));
  let offset = 0;
  for (const step of [
    '$send = Get-DictationSend $mic', "foreach ($way in @('send-click', 'ctrl-enter'))",
    "Press @(0x11, 0x44) 'Ctrl+D: start composer dictation for the send case'",
    "Assert-DictationMic $micLive $true ($way + '-listening')", "$typed = 'typing-' + $way", 'Type-Text $typed',
    "Snapshot ($way + '-listening')",
    "'send-click' { [VerifyNative]::ClickClient($script:window,", "'ctrl-enter' { [VerifyNative]::Chord(@(0x11, 0x0D)) }",
    "[VerifyNative]::EditText($handle) -ceq ''",
    "$expected = $typed + ' Go forward ten meters.'", 'Test-Path $outbox', '$_.t -ceq $expected',
    "Assert-DictationMic $mic $false ($way + '-stopped')", '$deliveries++', "Snapshot ($way + '-sent')",
    "name = ('dictation-' + $way)",
  ]) {
    const at = recipe.indexOf(step, offset);
    assert.ok(at >= offset, `missing or misordered ${step}`);
    offset = at + step.length;
  }
  const press = recipe.slice(recipe.indexOf('$immediate ='), recipe.indexOf('$elapsed ='));
  assert.doesNotMatch(press, /Type-Text|Press |Snapshot|Start-Sleep|SetFocus|PostMessage/);
  assert.doesNotMatch(recipe, /Set-Content|WriteAll|PostMessage|SetEnvironmentVariable|\.SetFocus\(|\.SetValue\(|Start-Sleep/);
  const geometry = source.slice(source.indexOf('function Get-DictationSend('), source.indexOf('function Assert-DictationMic('));
  for (const required of ['$transcript.Current.ProcessId -ne $process.Id', '$left -le $Mic[2]', 'GetDpiForWindow($script:window) / 96.0']) assert.ok(geometry.includes(required), required);
  const mic = source.slice(source.indexOf('function Get-DictationMic('), source.indexOf('function Get-DictationSend('));
  assert.ok(mic.includes('- [Math]::Floor(6 * $scale) - $size'));
}

test('IGSH-965 one press on send or Ctrl+Enter while dictating stops, appends the spoken words and sends them to the session', () => {
  sendContract(driver);
  for (const required of ["'ctrl-enter' { [VerifyNative]::Chord(@(0x11, 0x0D)) }", '$_.t -ceq $expected', '$send = Get-DictationSend $mic', "[VerifyNative]::EditText($handle) -ceq ''", 'Test-Path $outbox', '- [Math]::Floor(6 * $scale) - $size']) {
    const broken = driver.replaceAll(required, 'REMOVED');
    assert.notEqual(broken, driver, required);
    assert.throws(() => sendContract(broken), assert.AssertionError, required);
  }
});

test('IGSH-965 send sits at the far right and the queued send is armed and consumed on the real paths', () => {
  const composer = read('src/chat_composer.zig');
  const main = read('src/main.zig');
  assert.match(composer, /const slots = chatSendSlots\(composer_card, send_size, send_margin, [^\n]*chatComposerHasText\(\) or chat_dictation_state != \.idle\);/);
  assert.match(composer, /\.left = slots\.left - uiScaled\(6\) - chatDictationMicWidth\(chat_dictation_state\),/);
  assert.match(composer, /\.right = mic_btn\.left - uiScaled\(12\),/);
  assert.match(composer, /try std\.testing\.expect\(layout\.send_btn\.left > layout\.mic_btn\.right\);/);
  assert.match(main, /WM_APP_CHAT_SEND => \{\s*if \(wp == 1\) @import\("chat_send\.zig"\)\.chatSteerPrompt\(\) else @import\("chat_composer\.zig"\)\.chatSendOrFinishDictation\(\);/);
  const readyStart = voice.indexOf('pub fn handleDictationReady(');
  const ready = voice.slice(readyStart, readyStart + 6000);
  assert.match(ready, /const send_queued = app_state\.g_dictation_send_queued\.swap\(false, \.acq_rel\);/);
  assert.equal((ready.match(/chatDictationSendFlush\(send_queued\)/g) || []).length, 2);
  assert.match(voice, /pub fn cancelDictation\(\) void \{[^}]*g_dictation_send_queued\.store\(false, \.release\);/);
  assert.match(composer, /const dictating = dictated\.len > 0 and app_state\.g_dictation_running\.load\(\.acquire\) and\s*std\.mem\.eql\(u8, dictated, app_state\.g_chat_draft_owner\[0\.\.app_state\.g_chat_draft_owner_len\]\);/);
  const keys = composer.slice(composer.indexOf('fn chatDictationKey('), composer.indexOf('pub fn chatDictationClick('));
  assert.doesNotMatch(keys, /g_dictation_send_queued/);
});

function seamContract(source) {
  const fixture = source.slice(source.indexOf('fn dictationFixtureEnabled('), source.indexOf('fn captureDictationPcm('));
  for (const required of ['"GITHUB_ACTIONS", "true"', '"RUNNER_OS", "Windows"', '"MULTIPROMPT_NO_LOGIN", "1"', '"MULTIPROMPT_DICTATION_FIXTURE"', 'win32OpenRead(file)', 'win32ReadAll(handle, out)']) assert.ok(fixture.includes(required), required);
  const capture = source.slice(source.indexOf('fn captureDictationPcm('), source.indexOf('fn deepgramTranscribePcm('));
  assert.match(capture, /if \(dictationFixtureEnabled\(\)\) \{\s*const n = readDictationFixture\("goforward.pcm", audio.buf\);[\s\S]*?while \(app_state.g_dictation_recording.load\(.acquire\)\) Sleep\(1\);\s*return;/);
  const transcribe = source.slice(source.indexOf('fn deepgramTranscribePcm('), source.indexOf('fn dictationWorkerThread('));
  const offline = transcribe.slice(0, transcribe.indexOf('    var key_buf:'));
  for (const required of ['if (dictationFixtureEnabled())', 'readDictationFixture("goforward.pcm", expected)', '!std.mem.eql(u8, audio, expected[0..expected_len])', 'readDictationFixture("response.json", &response)', 'parseDeepgramTranscript(response[0..n], transcript_out)']) assert.ok(offline.includes(required), required);
  assert.doesNotMatch(offline, /WinHttp|dictationSetTranscript|SetWindowText|chatDraftAppend/);
  assert.match(source, /if \(!dictationFixtureEnabled\(\) and readDeepgramApiKey\(&key_buf\) == null\)/);
  const worker = source.slice(source.indexOf('fn dictationWorkerThread('), source.indexOf('pub fn synthesizeCtrlVIntoForeground('));
  for (const required of ['captureDictationPcm(&audio)', 'deepgramTranscribePcm(audio.slice(), &transcript_utf8)', 'dictationSetTranscriptUtf8(', 'WM_APP_DICTATION_READY']) assert.ok(worker.includes(required), required);
}

test('IGSH-812 replay replaces only hardware/provider I/O and retains the production worker and parser', () => {
  seamContract(voice);
  for (const required of ['"GITHUB_ACTIONS", "true"', '"MULTIPROMPT_NO_LOGIN", "1"', 'readDictationFixture("goforward.pcm", audio.buf)', '!std.mem.eql(u8, audio, expected[0..expected_len])', 'parseDeepgramTranscript(response[0..n], transcript_out)', 'captureDictationPcm(&audio)']) {
    const broken = voice.replaceAll(required, 'REMOVED');
    assert.notEqual(broken, voice);
    assert.throws(() => seamContract(broken), assert.AssertionError, required);
  }
  assert.match(driver, /\$env:MULTIPROMPT_DICTATION_FIXTURE = \$null\s+if \(\$Feature -eq 'chat-dictation'\)/);
  assert.match(driver, /'IGSH_246', 'MULTIPROMPT_DICTATION_FIXTURE'\)\)/);
});

test('IGSH-812 speech fixture is recorded, pinned, licensed, non-silent PCM with an explicit response stand-in', () => {
  const base = 'tools/fixtures/IGSH-812/';
  const pcm = fs.readFileSync(path.join(root, base, 'goforward.pcm'));
  const source = JSON.parse(read(base + 'source.json'));
  assert.equal(pcm.length, 89160);
  assert.equal(createHash('sha256').update(pcm).digest('hex'), source.sha256);
  assert.equal(source.sha256, 'f15c60ec54059d8b66e410d0064945a0b0a04ea56e1ddca1958e493c0cf70e71');
  assert.match(source.revision, /^[a-f0-9]{40}$/);
  assert.equal(source.path, 'test/data/goforward.raw');
  let power = 0;
  for (let i = 0; i < pcm.length; i += 2) power += pcm.readInt16LE(i) ** 2;
  assert.ok(Math.sqrt(power / (pcm.length / 2)) > 100);
  const response = read(base + 'response.json');
  assert.equal(Buffer.byteLength(response), 101);
  const transcript = JSON.parse(response).results.channels[0].alternatives[0].transcript;
  assert.equal(transcript, 'Go forward ten meters.');
  assert.equal(transcript.length, 22);
  assert.match(read(base + 'LICENSE.pocketsphinx'), /Redistribution and use/);
  assert.match(read(base + 'README.md'), /hand-authored provider-format response/);
});

test('IGSH-812 registration is additive and existing contract checks remain on the Windows workflow', () => {
  assert.match(driver, /ValidateSet\([^\n]*'chat-dictation'/);
  assert.match(workflow, /FEATURE -notin @\([^\n]*'chat-dictation'/);
  assert.match(workflow, /feature:.*fromJSON\('\[[^\n]*"chat-dictation"/);
  assert.match(workflow, /run: node --test [^\n]*tools\/chat-dictation.test.js/);
  assert.ok(workflow.includes('- tools/chat-dictation.test.js'));
  assert.ok(workflow.includes('- tools/fixtures/IGSH-812/**'));
  assert.match(workflow, /FEATURE -eq 'chat-dictation' -and \$env:RELEASE_TAG\) \{ throw/);
  for (const required of ['Check verification contracts', 'Check workspace focus journey contract', 'Check browser recovery journey contract', 'Validate journey and syntax', 'node tools/check-workspace-focus.mjs', 'node tools/check-browser-pane-stuck.mjs', 'Language.Parser]::ParseFile', 'Build branch executable', 'Launch Doctor Drive Evidence Cleanup', 'Upload durable verification evidence']) assert.ok(workflow.includes(required), required);
  const map = read(skill + 'features/chat-dictation.md');
  assert.deepEqual(map.match(/^## .+$/gm), ['## Sub-features', '## How to get to it (user POV)', '## Driving it with control.ps1', '## Gotchas']);
  for (const item of ['dictation-enter', 'dictation-ctrl-d', 'dictation-mic-click', '1000 ms', 'f94e5952', 'Windows runtime proof']) assert.ok(map.includes(item), item);
  assert.ok(read(skill + 'features/README.md').includes('](chat-dictation.md)'));
  assert.ok(read(skill + 'SKILL.md').includes('](features/chat-dictation.md)'));
  assert.match(read(skill + 'coverage.md'), /\| IGSH-812 \|[^\n]*\| chat-dictation \| Windows proof recorded/);
});

test('IGSH-893 audit evidence serializes plain lines within five seconds on Windows PowerShell', { skip: process.platform !== 'win32' }, () => {
  const { spawnSync } = require('node:child_process');
  const os = require('node:os');
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'dictation-audit-'));
  try {
    const auditPath = path.join(directory, 'dictation-audit.log');
    const lines = ['123\tfixture-audio-bytes\t89160', '124\ttarget-chat-composer\t22'];
    fs.writeFileSync(auditPath, lines.join('\n'));
    const auditRead = driver.match(/^\s*\$audit = (.+)$/m);
    assert.ok(auditRead, 'production audit read exists');
    const helper = driver.slice(driver.indexOf('function Read-DictationAudit('), driver.indexOf('function Get-DictationMic('));
    const script = `$ErrorActionPreference = 'Stop'; ${helper}; $auditPath = $env:AUDIT_PATH; $held = [IO.File]::Open($auditPath, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite); try { $audit = ${auditRead[1]} } finally { $held.Dispose() }; if ((ConvertTo-Json -InputObject @{} -Compress) -cne '{}') { throw 'JSON serializer precondition failed' }; Write-Host ('AUDIT_READ_READY type=' + $audit[0].GetType().FullName + ' properties=' + ($audit[0].PSObject.Properties.Name -join ',')); $clock = [Diagnostics.Stopwatch]::StartNew(); $json = ConvertTo-Json -InputObject @{ audit = $audit } -Depth 12 -Compress; Write-Host ('SERIALIZATION_MS=' + $clock.ElapsedMilliseconds); Write-Output $json`;
    const result = spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', script], {
      encoding: 'utf8', timeout: 30000, env: { ...process.env, AUDIT_PATH: auditPath },
    });
    assert.equal(result.error, undefined, JSON.stringify({ error: result.error?.message, stdout: result.stdout, stderr: result.stderr, expression: auditRead[1] }));
    assert.equal(result.status, 0, result.stderr);
    console.log(result.stdout);
    const elapsed = result.stdout.match(/SERIALIZATION_MS=(\d+)/);
    assert.ok(elapsed, result.stdout);
    assert.ok(Number(elapsed[1]) < 5000, result.stdout);
    assert.deepEqual(JSON.parse(result.stdout.split(/SERIALIZATION_MS=\d+\s*/)[1]).audit, lines);
    const broken = spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', script.replace(auditRead[1], '@(Get-Content $auditPath)')], {
      encoding: 'utf8', timeout: 30000, env: { ...process.env, AUDIT_PATH: auditPath },
    });
    assert.match(broken.stdout, /AUDIT_READ_READY[^\n]*PSPath/);
    if (broken.error) {
      assert.equal(broken.error.code, 'ETIMEDOUT', broken.stderr);
    } else {
      assert.equal(broken.status, 0, broken.stderr);
      const oldElapsed = broken.stdout.match(/SERIALIZATION_MS=(\d+)/);
      assert.ok(oldElapsed, broken.stdout);
      const oldAudit = JSON.parse(broken.stdout.split(/SERIALIZATION_MS=\d+\s*/)[1]).audit;
      assert.ok(Number(oldElapsed[1]) >= 5000 || JSON.stringify(oldAudit) !== JSON.stringify(lines));
    }
    console.log('DICTATION_OLD_PROVIDER_METADATA_REJECTED');
    console.log('DICTATION_AUDIT_SERIALIZATION_OK');
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('IGSH-893 a stalled precondition fails within its named timeout', { skip: process.platform !== 'win32' }, () => {
  const { spawnSync } = require('node:child_process');
  const start = driver.indexOf('function Wait-Until(');
  const wait = driver.slice(start, driver.indexOf('\nfunction ', start + 1));
  const script = `$ErrorActionPreference = 'Stop'; $process = $null; ${wait}
    try { Wait-Until { $false } 'deliberately stalled recorded PCM capture precondition' -Seconds 1 -PollMilliseconds 20; throw 'Stall unexpectedly passed' }
    catch { if ($_.Exception.Message -notlike 'Waited 1 s for deliberately stalled recorded PCM capture precondition.*') { throw }; Write-Output 'DICTATION_STALL_TIMEOUT_OK' }`;
  const result = spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', script], { encoding: 'utf8', timeout: 5000 });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /DICTATION_STALL_TIMEOUT_OK/);
});
