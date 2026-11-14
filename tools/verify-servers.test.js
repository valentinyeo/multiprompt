const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const skill = '.claude/skills/verify-multiprompt';

test('servers journey runs the one-time setup line from a file without a byte-order mark', () => {
  const driver = read(`${skill}/servers.ps1`);
  assert.match(driver, /New-Object Text\.UTF8Encoding\(\$false\)\)\.GetBytes\(\$paste/);
  assert.match(driver, /\[IO\.File\]::WriteAllBytes\(\$pasteScript/);
  assert.match(driver, /Arguments = '--noprofile --norc "' \+ \$pasteScript/);
  assert.doesNotMatch(driver, /StandardInput\.BaseStream/);
  assert.doesNotMatch(driver, /--norc -s/);
  assert.match(driver, /Remove-Item -LiteralPath \$pasteScript/);
});

test('servers journey is dispatched by control.ps1 and indexed with the required four sections', () => {
  assert.match(read(`${skill}/control.ps1`), /'servers' \{\s+\. \(Join-Path \$PSScriptRoot 'servers\.ps1'\)/);
  assert.ok(read(`${skill}/features/README.md`).includes('](servers.md)'));
  assert.deepEqual(read(`${skill}/features/servers.md`).match(/^## .+$/gm), [
    '## Sub-features',
    '## How to get to it (user POV)',
    '## Driving it with control.ps1',
    '## Gotchas',
  ]);
});

test('disposable endpoint accepts only public-key sign-in and the two production commands', () => {
  const server = read('tools/verify-servers/server.py');
  assert.match(server, /check_auth_publickey/);
  assert.doesNotMatch(server, /check_auth_password\s*\(/);
});
