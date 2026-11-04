const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');

const control = readFileSync('.claude/skills/verify-multiprompt/control.ps1', 'utf8');
const sessions = readFileSync('.claude/skills/verify-multiprompt/control-feature-sessions.ps1', 'utf8');
const ssh = readFileSync('tools/verify-repo-picker/ssh.c', 'utf8');

test('sessions installs the SSH boundary before launch', () => {
  const setup = control.indexOf("if ($Feature -eq 'sessions') {");
  const launch = control.indexOf('$process = $job.Start(');
  assert.ok(setup > 0 && setup < launch);
  assert.match(control.slice(setup, launch), /zig cc[\s\S]*ssh-path\.txt/);
  assert.match(ssh, /invocation-%lu\.txt/);
  assert.match(ssh, /\/work\/projects\/alpha/);
  assert.match(ssh, /\/work\/projects\/beta/);
});

test('Ctrl+T picks beta directly and checks the saved chat', () => {
  const journey = sessions.slice(0, sessions.indexOf("Palette 'new claude in terminal'"));
  assert.match(journey, /Ctrl\+T: new Claude chat[\s\S]*listing-\*\.txt[\s\S]*Type-Text 'beta'[\s\S]*Enter: select beta[\s\S]*\$tab\.cwd -eq '\/work\/projects\/beta' -and \$tab\.cv -eq \$true/);
  assert.doesNotMatch(journey, /Palette|commands\.json|catch|fallback/i);
});

test('cancel precedes alpha chat and beta terminal checks', () => {
  assert.match(sessions, /cancel repository picker[\s\S]*close palette[\s\S]*Ctrl\+T: new Claude chat after cancel[\s\S]*Type-Text 'alpha'[\s\S]*\$tab\.cwd -eq '\/work\/projects\/alpha' -and \$tab\.cv -eq \$true[\s\S]*New Claude in terminal[\s\S]*Type-Text 'beta'[\s\S]*\$tab\.cwd -eq '\/work\/projects\/beta'[\s\S]*\$tab\.cv -eq \$false/);
});
