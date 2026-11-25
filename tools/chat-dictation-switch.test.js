const { test } = require('node:test');

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { readControlSource } = require('./app-source');
assert.equal(typeof readControlSource, 'function', 'Control readers must follow physical feature files');

const root = path.resolve(__dirname, '..');
const skill = '.claude/skills/verify-multiprompt/';
const read = file => (file.endsWith('control.ps1') ? readControlSource() : fs.readFileSync(path.join(root, file), 'utf8')).replace(/\r\n/g, '\n');
const driver = read(skill + 'control.ps1');
const recipe = read(skill + 'control-feature-chat-dictation-switch.ps1');
const map = read(skill + 'features/chat-dictation-switch.md');

function journeyContract(source) {
  let offset = 0;
  for (const step of [
    "Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq 2 -and $state.active_tab -eq 0 }",
    "Press @(0x12, 0x43) 'Alt+C: open Chat View on the first chat'",
    "Wait-ChatFocus 'Edit' 'dictation-switch-composer'",
    "Assert-DictationMic $mic $false 'dictation-switch-idle'",
    "if ([VerifyNative]::EditText($handle) -cne '') { throw 'The first chat must start with an empty message box' }",
    "Snapshot 'before'",
    "Press @(0x11, 0x44) 'Ctrl+D: start dictation in the first chat'",
    "'\\tfixture-audio-bytes\\t89160$'",
    "Assert-DictationMic $mic $true 'dictation-switch-listening'",
    'Doctor\nAssert-Foreground',
    '$immediate = [Diagnostics.Stopwatch]::StartNew()',
    "Press @(0x11, 0x09) 'Ctrl+Tab: switch to the second chat while dictating'",
    'Wait-Until { (Read-Session).active_tab -eq 1 }',
    "'\\tchat-switch\\t0$'",
    "'switching chats stopped the dictation recording' -Seconds 2",
    "Snapshot 'action'",
    "'\\tcancel\\t0$'",
    "@('fixture-response-bytes', 'http-status', 'target-chat-composer', 'target-shell', 'shell-output-verified', 'target-browser')",
    "'\\taudio-bytes\\t89160$'",
    "'owned visible composer on the second chat'",
    "Wait-Until { [VerifyNative]::EditText($second) -ceq '' } 'the second chat message box stays empty'",
    "if ([VerifyNative]::EditText($second) -cne '') { throw 'Dictated text landed in the second chat' }",
    "Assert-DictationMic $micSecond $false 'dictation-switch-stopped'",
    "Press @(0x11, 0x09) 'Ctrl+Tab: return to the first chat'",
    "Wait-Until { [VerifyNative]::EditText($handle) -ceq '' }",
    "if ([VerifyNative]::EditText($handle) -cne '') { throw 'The abandoned dictation words came back to the first chat' }",
    "'switch-stop.json'",
    "name = 'dictation-stops-on-chat-switch'",
    "Snapshot 'after'",
  ]) {
    const at = source.indexOf(step, offset);
    assert.ok(at >= offset, `missing or misordered ${step}`);
    offset = at + step.length;
  }
  assert.doesNotMatch(source, /Set-Content|WriteAll|PostMessage|SetEnvironmentVariable|\.SetFocus\(|\.SetValue\(|Start-Sleep/);
  assert.doesNotMatch(source, /Cancel-Dictation|SetValue|sendChatPrompt/);
}

test('MUBO-291 a real Ctrl+Tab during dictation stops the recording and both chats stay empty', () => {
  journeyContract(recipe);
  for (const required of [
    "Press @(0x11, 0x44) 'Ctrl+D: start dictation in the first chat'",
    "Press @(0x11, 0x09) 'Ctrl+Tab: switch to the second chat while dictating'",
    "'\\tchat-switch\\t0$'",
    "if ([VerifyNative]::EditText($second) -cne '') { throw 'Dictated text landed in the second chat' }",
    "if ([VerifyNative]::EditText($handle) -cne '') { throw 'The abandoned dictation words came back to the first chat' }",
  ]) {
    const broken = recipe.replaceAll(required, 'REMOVED');
    assert.notEqual(broken, recipe, required);
    assert.throws(() => journeyContract(broken), assert.AssertionError, required);
  }
});

function switchContract(files) {
  const { console, voice, composer } = files;
  assert.match(console, /if \(idx != app_state\.active_shell\) \{\n        @import\("voice\.zig"\)\.cancelDictationOnTabSwitch\(\);/);
  const stop = voice.slice(voice.indexOf('pub fn cancelDictationOnTabSwitch()'), voice.indexOf('pub fn handleDictationReady()'));
  assert.ok(stop.length > 0);
  for (const required of [
    'if (!app_state.g_dictation_running.load(.acquire)) return;',
    'if (app_state.g_voice_listening_active.load(.acquire)) return;',
    'app_state.g_dictation_cancelled.store(true, .release);',
    'cancelDictation();',
    'dictationAudit("chat-switch", 0);',
  ]) assert.ok(stop.includes(required), required);
  const discard = composer.slice(composer.indexOf('pub fn chatDictationLiveDiscard()'), composer.indexOf('fn chatLiveStripFromStore()'));
  assert.ok(discard.length > 0);
  assert.match(discard, /if \(!live_draft\.active\) return;\n    chatLiveStripFromStore\(\);/);
}

test('MUBO-291 one tab switch stops the recording and drops the words from the stored draft', () => {
  const files = {
    console: read('src/console.zig'),
    voice: read('src/voice.zig'),
    composer: read('src/chat_composer.zig'),
  };
  switchContract(files);
  for (const [field, from, to] of [
    ['console', '        @import("voice.zig").cancelDictationOnTabSwitch();\n', ''],
    ['voice', '    cancelDictation();\n    dictationAudit("chat-switch", 0);', '    dictationAudit("chat-switch", 0);'],
    ['composer', '    chatLiveStripFromStore();\n    live_draft.sealed = false;', '    live_draft.sealed = false;'],
  ]) {
    const broken = { ...files };
    broken[field] = files[field].replace(from, to);
    assert.notEqual(broken[field], files[field], field);
    assert.throws(() => switchContract(broken), assert.AssertionError, field);
  }
});

test('MUBO-291 the journey is registered, indexed and seeded with two chats', () => {
  assert.match(driver, /ValidateSet\([^\n]*'chat-dictation-switch'/);
  const registration = fs.readFileSync(path.join(root, skill, 'control.ps1'), 'utf8').replace(/\r\n/g, '\n');
  assert.match(registration, /\n        'chat-dictation-switch' \{\n            \. \(Join-Path \$PSScriptRoot 'control-feature-chat-dictation-switch\.ps1'\)\n        \}/);
  assert.match(driver, /if \(\$Feature -eq 'chat-dictation-switch'\) \{[\s\S]*?shell_id = 1; cv = \$false/);
  assert.match(driver, /shell_id = 2; cv = \$true/);
  assert.match(driver, /if \(\$Feature -in @\('chat-dictation', 'chat-dictation-switch'\)\) \{/);
  assert.ok(read(skill + 'features/README.md').includes('](chat-dictation-switch.md)'));
  assert.match(read(skill + 'coverage.md'), /\| MUBO-291 \|[^\n]*\| chat-dictation-switch \|/);
  assert.deepEqual(map.match(/^## .+$/gm), ['## Sub-features', '## How to get to it (user POV)', '## Driving it with control.ps1', '## Gotchas']);
  assert.doesNotMatch(map, /^Verify on: /m);
  const workflow = read('.github/workflows/verify.yml');
  assert.match(workflow, /FEATURE -in @\('chat-dictation', 'chat-dictation-switch'\) -and \$env:RELEASE_TAG\) \{ throw/);
  assert.match(workflow, /run: node --test [^\n]*tools\/chat-dictation-switch\.test\.js/);
  assert.ok(require('./verify-features.cjs').discoverFeatures().available.includes('chat-dictation-switch'));
});
