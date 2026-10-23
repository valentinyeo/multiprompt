const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { execFileSync, spawnSync } = require('node:child_process');
const { tmpdir } = require('node:os');
const { join, resolve } = require('node:path');
const script = join(__dirname, 'check-powershell-host-names.ps1');
const inventory = JSON.parse(fs.readFileSync(join(__dirname, 'powershell-host-names.json'), 'utf8'));
const pwsh = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', script, '-Root', resolve(__dirname, '..')], { encoding: 'utf8' });
const unavailable = pwsh.error?.code === 'ENOENT';

function fixture(t, source, extension = 'ps1') {
  const dir = fs.mkdtempSync(join(tmpdir(), 'powershell-host-names-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd: dir, encoding: 'utf8' });
  git('init', '-q');
  fs.writeFileSync(join(dir, `control.${extension}`), source);
  git('add', '.');
  return spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', script, '-Root', dir], { encoding: 'utf8' });
}

function expect(result, status, pattern) {
  assert.equal(result.status, status, result.stdout + result.stderr);
  assert.match(result.stdout + result.stderr, pattern);
}

test('Windows 5.1 inventory includes the required automatic names and aliases without case duplicates', () => {
  for (const [key, names] of Object.entries({ automaticVariables: ['ShellId', 'Host', 'PID', 'PSHOME', 'true', 'false', 'null', 'Error', 'ConsoleFileName', 'ExecutionContext', 'HOME', 'PSCulture', 'PSEdition', 'PSUICulture', 'PSVersionTable'], aliases: ['Move', 'cd', 'ls', 'cp', 'mv', 'rm', 'del', 'sort', 'where', 'select', 'foreach'] })) {
    const actual = inventory[key].map(name => name.toLowerCase());
    assert.equal(new Set(actual).size, actual.length);
    for (const name of names) assert.ok(actual.includes(name.toLowerCase()), name);
  }
});

test('checker uses tracked files and ParseFile, not execution of inspected scripts', () => {
  const source = fs.readFileSync(script, 'utf8');
  assert.match(source, /git -C \$rootPath ls-files -z -- '\*\.ps1' '\*\.psm1'/);
  assert.match(source, /\[System\.Management\.Automation\.Language\.Parser\]::ParseFile/);
  assert.doesNotMatch(source, /::ParseInput|Invoke-Expression|Invoke-Command|\.\s+\$file|&\s+\$file/i);
});

test('historical 73c3331 typed ShellId parameter is rejected case-insensitively', { skip: unavailable && 'pwsh is not installed; GitHub must run parse controls' }, t => {
  for (const name of ['ShellId', 'sHeLlId']) {
    expect(fixture(t, `function Read-BrowserFrozen([uint32]$${name}) { throw 'must never execute' }`), 1, new RegExp(`control.ps1:1 parameter \\$${name} shadows a read-only PowerShell automatic variable; rename it`));
  }
});

test('reserved automatic parameters and read-only assignment/foreach targets are rejected', { skip: unavailable }, t => {
  for (const name of inventory.automaticVariables) expect(fixture(t, `param($${name})`), 1, /automatic variable/);
  for (const source of ['$Host = 1', '[uint32]$PID = 2', '$PSHOME += 1', '$local, $Error = 1, 2', '$null, $ShellId = 1, 2', '[string]$ShellId = "bad"', 'foreach ($Host in 1, 2) {}', '$PID++']) {
    expect(fixture(t, source, 'psm1'), 1, /control.psm1:1 .*automatic variable/);
  }
});

test('$null discard assignments, including casts and tuple forms, pass without execution', { skip: unavailable }, t => {
  for (const source of ['$null = Get-Thing', '$null = $a, $b', '[void]($null = Get-Thing)', '[object]$NuLl = Get-Thing', '$null, $value = Get-Thing', '$value, $null = Get-Thing', '[void](Get-Thing)']) {
    expect(fixture(t, source), 0, /PowerShell host names OK: 1 tracked scripts/);
  }
});

test('writable Windows 5.1 automatic bindings are not inventoried as read-only', () => {
  const names = inventory.automaticVariables.map(name => name.toLowerCase());
  for (const name of ['Matches', 'input', 'args', 'this', '_', 'PSItem', 'PSDebugContext']) assert.ok(!names.includes(name.toLowerCase()), name);
});

test('writable Windows 5.1 automatic assignments and input binders pass', { skip: unavailable }, t => {
  for (const name of ['Matches', 'input', 'args', 'this', '_', 'PSItem', 'PSDebugContext']) {
    expect(fixture(t, `$${name} = @()`), 0, /PowerShell host names OK: 1 tracked scripts/);
  }
  expect(fixture(t, 'foreach ($input in 1, 2) {}'), 0, /PowerShell host names OK: 1 tracked scripts/);
});

test('historical caa9eb9 Move function and all requested aliases are rejected', { skip: unavailable }, t => {
  for (const name of ['Move', 'mOvE', 'cd', 'ls', 'cp', 'mv', 'rm', 'del', 'sort', 'where', 'select', 'foreach', 'global:Move']) {
    expect(fixture(t, `function ${name} { throw 'must never execute' }`), 1, /function .* is hidden by the Windows PowerShell .* alias; rename the helper/);
  }
});

test('reads, member writes, distinct scoped variables, strings and safe helper names pass without execution', { skip: unavailable }, t => {
  const source = [
    'param([uint32]$SessionId)', '$script:ShellId = 3', '$env:PID = "safe"', '$object.Host = 1', '$object[$PID] = 2',
    '$Error[0] = "collection element"', 'Write-Output $ShellId, $Host, $PID, $PSHOME, $true, $false, $null, $Error, $input, $args, $this, $_, $PSItem, $Matches',
    'function Move-Pointer([uint32]$SessionId) {}', '"function Move { param($ShellId) }"', "throw 'must never execute'"
  ].join('\n');
  expect(fixture(t, source), 0, /PowerShell host names OK: 1 tracked scripts/);
});

test('malformed scripts fail with a parse diagnostic and location', { skip: unavailable }, t => {
  expect(fixture(t, 'function Broken {'), 1, /control.ps1:1 PowerShell parse error/);
});

test('tracked current repository passes the same parser-only checker', { skip: unavailable }, () => {
  expect(spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', script, '-Root', resolve(__dirname, '..')], { encoding: 'utf8' }), 0, /PowerShell host names OK/);
});

test('PR job preserves existing guards and independently runs each new test and checker', () => {
  const workflow = fs.readFileSync(join(__dirname, '../.github/workflows/no-comments.yml'), 'utf8');
  const job = workflow.split('\n  extension-version:')[0];
  assert.match(job, /^name: PR checks/m);
  assert.match(job, /\n  no-comments:\n    name: no-comments/);
  assert.match(job, /actions\/checkout@[^\n]+\n        with:\n          fetch-depth: 0/);
  const oldSteps = ['Lint GitHub workflows', 'Test the comment checker', 'Fail on any code comment'];
  let previous = -1;
  for (const step of oldSteps) { const index = job.indexOf(`- name: ${step}`); assert.ok(index > previous); previous = index; }
  const steps = job.split('      - name: ').slice(1 + oldSteps.length);
  assert.equal(steps.length, 6);
  const commands = [
    'node --test tools/check-routing-ids.test.js', 'node tools/check-routing-ids.mjs',
    'node --test tools/check-regression-inputs.test.js', 'node tools/check-regression-inputs.mjs origin/${{ github.base_ref }}',
    'node --test tools/check-powershell-host-names.test.js', './tools/check-powershell-host-names.ps1 -Root .'
  ];
  for (const [i, step] of steps.entries()) {
    assert.ok(step.includes(`run: ${commands[i]}`), step);
    if (i === 3) assert.ok(step.includes("if: (success() || failure()) && github.event_name == 'pull_request'"));
    else assert.ok(step.includes('if: success() || failure()'));
    if (i >= 4) assert.ok(step.includes('shell: pwsh'));
  }
});

test('agent rules remain under 80 lines and name the concrete enforcement tools', () => {
  const rules = fs.readFileSync(join(__dirname, '../CLAUDE.md'), 'utf8');
  assert.ok(rules.trimEnd().split('\n').length < 80);
  assert.match(rules, /## Rules and what enforces them\n\n\| Rule \| Enforced by \|/);
  for (const tool of ['check-routing-ids.mjs', 'check-regression-inputs.mjs', 'check-powershell-host-names.ps1', 'palette-rows.test.js', 'version-stamp.mjs', 'strip-comments.mjs', 'check-extension-version.mjs', 'secret-scan']) assert.ok(rules.includes(tool), tool);
});
