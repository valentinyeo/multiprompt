const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const workflow = fs.readFileSync(path.join(__dirname, '../.github/workflows/bot-avatars.yml'), 'utf8');
const step = workflow.match(/      - name: Reject the original binary avatar clipping\r?\n([\s\S]*?)(?=      - |$)/);
const run = step?.[1].match(/        run: \|\r?\n((?:          .*\r?\n)+)/);
const body = run?.[1].replace(/^          /gm, '');

test('expected failure clears the native exit code after validation', () => {
  assert.ok(body, 'PowerShell step body must exist');
  const validation = body.indexOf("throw 'Original avatar clipping did not fail the native fractional-edge assertion'");
  const reset = body.indexOf('$global:LASTEXITCODE = 0');
  const marker = body.indexOf("Write-Host 'ORIGINAL_BINARY_CLIP_REJECTED'");
  assert.ok(validation !== -1 && reset > validation && marker > reset, 'reset must follow validation and precede the success marker');
});

test('avatar rejection step respects the GitHub PowerShell exit wrapper', t => {
  assert.ok(body, 'PowerShell step body must exist');
  const cases = [
    { code: 1, output: 'IGSH-1192 face=0 scale=100 fractional=0', success: true },
    { code: 1, output: 'unexpected native failure', success: false },
    { code: 0, output: 'IGSH-1192 face=0 scale=100 fractional=0', success: false },
  ];
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'bot-avatar-exit-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  fs.mkdirSync(path.join(dir, 'src'), { recursive: true });
  fs.mkdirSync(path.join(dir, 'tools/fixtures/IGSH-1192'), { recursive: true });
  const source = 'original source\ntest "IGSH-1192 every robot" {}\n';
  const sourceFile = path.join(dir, 'src/bot_avatar.zig');
  fs.writeFileSync(path.join(dir, 'tools/fixtures/IGSH-1192/bot-avatar-before.zig'), 'original binary clipping fixture\n');
  for (const scenario of cases) {
    fs.writeFileSync(sourceFile, source);
    const script = `$ErrorActionPreference = 'stop'\nfunction zig {\n  $global:LASTEXITCODE = ${scenario.code}\n  '${scenario.output}'\n}\ntry {\n${body}\n} catch {\n  [Console]::Error.WriteLine($_.Exception.Message)\n  exit 1\n}\nif ((Test-Path -LiteralPath variable:\\LASTEXITCODE)) { exit $LASTEXITCODE }\n`;
    const scriptFile = path.join(dir, 'step.ps1');
    fs.writeFileSync(scriptFile, script);
    const result = spawnSync('pwsh', ['-NoLogo', '-NoProfile', '-NonInteractive', '-File', scriptFile], {
      cwd: dir, encoding: 'utf8', timeout: 30000,
    });
    if (result.error?.code === 'ENOENT') {
      t.skip('pwsh is not installed');
      return;
    }
    assert.ifError(result.error);
    assert.notEqual(result.status, null, result.stderr);
    assert.equal(fs.readFileSync(sourceFile, 'utf8'), source, 'source must be restored');
    const output = result.stdout + result.stderr;
    if (scenario.success) {
      assert.equal(result.status, 0, output);
      assert.match(output, /ORIGINAL_BINARY_CLIP_REJECTED/);
    } else {
      assert.notEqual(result.status, 0, output);
      assert.doesNotMatch(output, /ORIGINAL_BINARY_CLIP_REJECTED/);
      assert.match(output, /Original avatar clipping did not fail the native fractional-edge assertion/);
    }
  }
});
