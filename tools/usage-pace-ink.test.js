const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');

const root = path.resolve(__dirname, '..');

test('both visible pace surfaces use the glyph-aware rejection check', () => {
  const source = fs.readFileSync(path.join(root, '.claude/skills/verify-multiprompt/control-feature-status-card.ps1'), 'utf8');
  assert.match(source, /Assert-UsagePaceInk \$closedInk \$usagePaceSnapshot 'usage pill'/);
  assert.match(source, /\$paceProof\.panel = \$look/);
  assert.match(source, /Assert-UsageCardPixels 'pill-open'/);
});

test('pace proof accepts visible small marks but rejects missing or wrong-state ink', t => {
  if (process.platform !== 'win32') return t.skip('Native proof assertion runs on Windows');
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'pace-ink-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const script = path.join(directory, 'proof.ps1');
  fs.writeFileSync(script, `
$ErrorActionPreference = 'Stop'
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $pwd '.claude/skills/verify-multiprompt/control-feature-status-card.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$function = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Assert-UsagePaceInk' }, $true)
if (-not $function) { throw 'Native pace proof must check visible glyphs, not a fixed label-sized count' }
Invoke-Expression $function.Extent.Text
$sample = Get-Content tools/fixtures/IGSH-997/sample.json -Raw | ConvertFrom-Json
$sample.accounts[0].week.pace.verdict = 'above'
$sample.accounts[0].five_hour.pace.verdict = 'below'
$sample.accounts[1].week.pace.verdict = 'above'
Assert-UsagePaceInk @{ above = 79; below = 2 } $sample 'pill'
foreach ($counts in @(@{ above = 79; below = 0 }, @{ above = 0; below = 2 })) {
    $rejected = $false
    try { Assert-UsagePaceInk $counts $sample 'pill' } catch { $rejected = $true }
    if (-not $rejected) { throw 'Missing live pace state was accepted' }
}
foreach ($grade in @('above', 'below')) {
    $control = Get-Content ('tools/fixtures/IGSH-997/' + $grade + '.json') -Raw | ConvertFrom-Json
    $counts = @{ above = 0; below = 0 }; $counts[$grade] = 12
    Assert-UsagePaceInk $counts $control 'pill'
    $counts[$grade] = 11
    $rejected = $false
    try { Assert-UsagePaceInk $counts $control 'pill' } catch { $rejected = $true }
    if (-not $rejected) { throw 'Full-label control lost its original twelve-pixel minimum' }
}
Write-Output 'PACE_GLYPH_PROOF_OK'
`);
  const result = spawnSync('powershell.exe', ['-NoProfile', '-File', script], {
    cwd: root, encoding: 'utf8', timeout: 30000,
  });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /PACE_GLYPH_PROOF_OK/);
});
