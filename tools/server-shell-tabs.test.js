const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = rel => path.join(__dirname, '..', rel);
const journey = fs.readFileSync(root('.claude/skills/verify-multiprompt/control-feature-server-shell-tabs.ps1'), 'utf8');
const setup = fs.readFileSync(root('.claude/skills/verify-multiprompt/server-shell-release-setup.ps1'), 'utf8');
const workflow = fs.readFileSync(root('.github/workflows/verify.yml'), 'utf8');
const control = fs.readFileSync(root('.claude/skills/verify-multiprompt/control.ps1'), 'utf8');
const map = fs.readFileSync(root('.claude/skills/verify-multiprompt/features/server-shell-tabs.md'), 'utf8');

test('SOFT-3128 server-shell-tabs is registered in control and the workflow', () => {
  assert.match(control, /'server-shell-tabs'/);
  assert.match(workflow, /FEATURE == 'server-shell-tabs'/);
  assert.match(workflow, /server-shell-tabs' && 20/);
  assert.ok(fs.readFileSync(root('.claude/skills/verify-multiprompt/features/README.md'), 'utf8').includes('](server-shell-tabs.md)'));
  assert.match(map, /server-shell-tabs/);
});

test('SOFT-3128 remote shell reads use a bounded local process wait', () => {
  assert.match(setup, /function Read-ProofServer/);
  assert.match(setup, /WaitForExit\(\$DeadlineSeconds \* 1000\)/);
  assert.match(setup, /BatchMode=yes/);
  assert.match(setup, /function Proof-SyncKnownHosts/);
});

test('SOFT-3128 paste, interrupt and restore wait on visible shell evidence', () => {
  assert.match(journey, /Proof-SyncKnownHosts/);
  assert.match(journey, /pasted the command onto the shell prompt/);
  assert.match(journey, /Proof-VisibleContains \$marker/);
  assert.match(journey, /the running proof command painted output in the shell/);
  assert.match(journey, /SOFT3001 INTERRUPTED/);
  assert.match(journey, /the restored tmux tab shows a terminal window/);
  assert.match(fs.readFileSync(root('.claude/skills/verify-multiprompt/server-shell-release-fixture.py'), 'utf8'), /mouse', 'off'/);
});

test('SOFT-3128 every wait in the journey names a step and uses an explicit timeout', () => {
  const lines = journey.split('\n');
  for (const line of lines) {
    if (!line.includes('Wait-Until')) continue;
    if (line.includes('Wait-Until {')) continue;
    assert.match(line, /Wait-Until .*'[^']+' \d+/, 'every Wait-Until must pass a timeout on one line: ' + line.trim());
  }
  assert.ok(lines.filter(l => l.includes('Wait-Until')).length >= 12);
  assert.match(journey, /keyboard focus is not on the shell terminal window before typing/);
  assert.match(journey, /shell-focus-timeout/);
  assert.match(journey, /journey-steps\.json/);
});

test('SOFT-3128 failed steps retain screenshots and the recorder stops in finally', () => {
  assert.match(journey, /Snapshot \(\$Name\.Replace/);
  assert.match(journey, /finally \{[\s\S]*Proof-StopVideo/);
  assert.doesNotMatch(journey, /-t 1500/);
});