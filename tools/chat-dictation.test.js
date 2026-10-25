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

require('./grok-chat.test.js');

function journeyContract(source) {
  const begin = source.indexOf("        'chat-dictation' {");
  assert.ok(begin >= 0);
  const recipe = source.slice(begin, source.indexOf("        'chat-tables' {", begin));
  for (const step of [
    "Select-Theme 'dark'", "Press @(0x12, 0x43)", "Wait-ChatFocus 'Edit'",
    '$composer.Current.ProcessId -ne $process.Id', 'GetAncestor($handle, 2) -ne $script:window',
    'foreach ($size in @(@(1000, 650), @(1400, 900)))',
    "foreach ($stop in @('enter', 'ctrl-d', 'mic-click', 'arrow', 'escape'))",
    "Type-Text 'echo'", 'Press @(0x11, 0x44)', 'fixture-audio-bytes\\t89160$',
    '-not [VerifyNative]::IsWindowVisible($handle)', '$middle - 2 * $side',
    '::DictationBarPixels($script:window, $bar,', "Snapshot ('dictation-bar-' + $step)",
    '$immediate = [Diagnostics.Stopwatch]::StartNew()',
    "'enter' { [VerifyNative]::Chord(@(0x0D)) }", "'ctrl-d' { [VerifyNative]::Chord(@(0x11, 0x44)) }",
    "'mic-click' { [VerifyNative]::ClickClient($script:window,", "'arrow' { [VerifyNative]::ClickClient($script:window,",
    "'escape' { [VerifyNative]::Chord(@(0x1B)) }", '[VerifyNative]::EditText($handle) -ceq $expected',
    'if ($elapsed -gt 1000) { throw', 'Only the arrow may enqueue', 'Escape discards the eventual transcript',
    "Snapshot ('clean-chat-' + $step)", 'if ($result.checks.Count -ne 12) { throw',
  ]) assert.ok(recipe.includes(step), step);
  const timed = recipe.slice(recipe.indexOf('$immediate ='), recipe.indexOf('$elapsed ='));
  assert.doesNotMatch(timed, /Type-Text|Press |Snapshot|Start-Sleep|Get-Content|SetFocus/);
  assert.doesNotMatch(recipe, /Set-Content|WriteAll|PostMessage|SetEnvironmentVariable|\.SetFocus\(|\.SetValue\(|Start-Sleep/);
  const pixels = source.slice(source.indexOf('public static int[] DictationBarPixels('), source.indexOf('public static int[] DictationMicPixels('));
  for (const required of ['WindowFromPoint(center) != owner', 'graphics.CopyFromScreen(', 'pixels.Save(output,', 'c.R == 42 && c.G == 42 && c.B == 44', 'c.R == 255', 'c.R == 250', 'c.R == 16']) assert.ok(pixels.includes(required), required);
}

test('IGSH-849 Windows journey requires real inputs, bar pixels, owned draft and send/cancel at both sizes', () => {
  journeyContract(driver);
  for (const required of ['Press @(0x11, 0x44)', "'enter' { [VerifyNative]::Chord(@(0x0D)) }", "'ctrl-d' { [VerifyNative]::Chord(@(0x11, 0x44)) }", "'arrow' { [VerifyNative]::ClickClient($script:window,", "'escape' { [VerifyNative]::Chord(@(0x1B)) }", '[VerifyNative]::EditText($handle) -ceq $expected', 'if ($elapsed -gt 1000) { throw', 'WindowFromPoint(center) != owner']) {
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
    "Assert-DictationMic $mic $true 'escape-listening'", "Type-Text ' keep this'",
    'Press @(0x1B, 0x1B)', "'\\tcancel\\t0$'", "'\\taudio-bytes\\t89160$'",
    "Assert-DictationMic $mic $false 'escape-cancelled'",
    "if ([VerifyNative]::EditText($handle) -cne $draft) { throw 'IGSH-846 Escape changed the existing draft' }",
    "Press @(0x11, 0x44) 'Ctrl+D: restart dictation after cancellation'",
    "Assert-DictationMic $mic $true 'escape-restarted'",
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

function seamContract(source) {
  const fixture = source.slice(source.indexOf('fn dictationFixtureEnabled('), source.indexOf('fn captureDictationPcm('));
  for (const required of ['"GITHUB_ACTIONS", "true"', '"RUNNER_OS", "Windows"', '"MULTIPROMPT_NO_LOGIN", "1"', '"MULTIPROMPT_DICTATION_FIXTURE"', 'win32OpenRead(file)', 'win32ReadAll(handle, out)']) assert.ok(fixture.includes(required), required);
  const capture = source.slice(source.indexOf('fn captureDictationPcm('), source.indexOf('fn deepgramTranscribePcm('));
  assert.match(capture, /if \(dictationFixtureEnabled\(\)\) \{\s*const n = readDictationFixture\("goforward.pcm", out\);[\s\S]*?while \(app_state.g_dictation_recording.load\(.acquire\)\) \{[\s\S]*?publishDictationLevel\(out\[cursor\.\.end\]\);[\s\S]*?Sleep\(100\);\s*\}\s*return n;/);
  const transcribe = source.slice(source.indexOf('fn deepgramTranscribePcm('), source.indexOf('fn dictationWorkerThread('));
  const offline = transcribe.slice(0, transcribe.indexOf('    var key_buf:'));
  for (const required of ['if (dictationFixtureEnabled())', 'readDictationFixture("goforward.pcm", expected)', '!std.mem.eql(u8, audio, expected[0..expected_len])', 'readDictationFixture("response.json", &response)', 'parseDeepgramTranscript(response[0..n], transcript_out)']) assert.ok(offline.includes(required), required);
  assert.doesNotMatch(offline, /WinHttp|dictationSetTranscript|SetWindowText|chatDraftAppend/);
  assert.match(source, /if \(!dictationFixtureEnabled\(\) and readDeepgramApiKey\(&key_buf\) == null\)/);
  const worker = source.slice(source.indexOf('fn dictationWorkerThread('), source.indexOf('pub fn synthesizeCtrlVIntoForeground('));
  for (const required of ['captureDictationPcm(audio)', 'deepgramTranscribePcm(audio[0..audio_len], &transcript_utf8)', 'dictationSetTranscriptUtf8(', 'WM_APP_DICTATION_READY']) assert.ok(worker.includes(required), required);
}

test('IGSH-812 replay replaces only hardware/provider I/O and retains the production worker and parser', () => {
  seamContract(voice);
  for (const required of ['"GITHUB_ACTIONS", "true"', '"MULTIPROMPT_NO_LOGIN", "1"', 'readDictationFixture("goforward.pcm", out)', '!std.mem.eql(u8, audio, expected[0..expected_len])', 'parseDeepgramTranscript(response[0..n], transcript_out)', 'captureDictationPcm(audio)']) {
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
  for (const item of ['dictation-enter', 'dictation-ctrl-d', 'dictation-mic-click', 'dictation-arrow', 'dictation-escape', '1000 ms', 'not yet run']) assert.ok(map.includes(item), item);
  assert.ok(read(skill + 'features/README.md').includes('](chat-dictation.md)'));
  assert.ok(read(skill + 'SKILL.md').includes('](features/chat-dictation.md)'));
  assert.match(read(skill + 'coverage.md'), /\| IGSH-812 \|[^\n]*\| chat-dictation \| journey added, not yet run \|/);
});
