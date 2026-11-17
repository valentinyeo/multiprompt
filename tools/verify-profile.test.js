const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const skill = '.claude/skills/verify-multiprompt/';

test('real-size corpus is deterministic, preserves existing journeys and passes the production reader', () => {
  const result = spawnSync(process.platform === 'win32' ? 'python' : 'python3', ['tools/verify-profile-test.py', '-v'], {
    cwd: root, encoding: 'utf8', timeout: 60000,
  });
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('all desktop profile owners install the same default seed', () => {
  for (const file of [
    skill + 'control.ps1', skill + 'control-feature-server-open-group.ps1',
    'tools/verify-chat-delivery/drive.ps1', 'tools/verify-session-actions/drive.ps1',
    'tools/verify-bot-photo/drive.ps1', 'tools/verify-app-icon/drive.ps1',
    'tools/update-release.test.ps1',
  ]) {
    assert.match(read(file), /seed-profile\.ps1" -Root \$(?:scratch|profile|Root|workRoot) -HomePath \$env:HOME -Evidence/, file);
  }
  assert.match(read(skill + 'drive.ps1'), /seed='real-size-v1'/);
  assert.match(read(skill + 'drive.ps1'), /manifest\.messagesPerLongChat -ne 2400/);
  assert.match(read(skill + 'seed-profile.ps1'), /if \(\$LASTEXITCODE -ne 0\) \{ throw/);
});

test('the seeded streaming journey runs automatically and retains video', () => {
  const features = require('./verify-features.cjs').discoverFeatures();
  assert.ok(features.pr.includes('chat-real-size'));
  assert.ok(features.full.includes('chat-real-size'));
  const automatic = read('.github/workflows/click-through.yml');
  assert.match(automatic, /  chat-real-size:\n    needs: changes\n    if: needs\.changes\.outputs\.run == 'true'\n    uses: \.\/\.github\/workflows\/verify\.yml\n    with:\n      feature: chat-real-size/);
  assert.match(automatic, /needs: \[changes,[^\n]*, chat-real-size\]/);
  assert.match(automatic, /REAL_SIZE: \$\{\{ needs\.chat-real-size\.result \}\}/);
  assert.match(automatic, /for result in [^\n]*"\$REAL_SIZE"; do/);
  const workflow = read('.github/workflows/verify.yml');
  assert.match(workflow, /'chat-real-size' = 'chat-and-composer'/);
  assert.match(workflow, /Install browser toggle recorder\n\s+if: [^\n]*env\.FEATURE == 'chat-real-size'/);
  assert.match(workflow, /Compile chat delivery remote-shell boundary\n\s+if: [^\n]*env\.FEATURE == 'chat-real-size'/);
  assert.match(workflow, /uses: actions\/setup-python@[^\n]+\n\s+with:/);
  assert.match(read(skill + 'drive.ps1'), /journey\.mp4/);
  assert.match(read('tools/verify-chat-delivery/real-size.ps1'), /Copy-RealSize 'streaming'/);
  assert.match(read('tools/verify-chat-delivery/real-size.ps1'), /Copy-RealSize 'completed'/);
});
