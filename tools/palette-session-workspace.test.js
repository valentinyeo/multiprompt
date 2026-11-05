const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('session and workspace tiers precede query and usage ranking', () => {
  const source = read('src/command_palette.zig');
  const start = source.indexOf('fn paletteResultOutranks(');
  const end = source.indexOf('\nfn sortSearchResultsByRank()', start);
  assert.ok(start >= 0 && end > start);
  const comparator = source.slice(start, end);
  const kind = comparator.indexOf('if (key_kind != prev_kind) return key_kind < prev_kind;');
  const query = comparator.indexOf('paletteQueryRank(key)');
  const usage = comparator.indexOf('paletteFrecencyAt(key_usage, now)');
  assert.ok(kind >= 0 && kind < query && query < usage);
  const sort = source.slice(end, source.indexOf('\ntest "session and workspace', end));
  assert.match(sort, /target >= SEARCH_WORKSPACE_OFFSET[\s\S]*workspaceIsLiveAnywhere\(workspace\.id\[0\.\.workspace\.id_len\]\)/);
  assert.match(sort, /paletteResultOutranks\(key, prev, key_kind, kinds\[j - 1\], now\)/);
});

test('palette usage fixture preserves the original counts and timestamps', () => {
  const parse = file => read(file).trim().split(/\r?\n/).map(line => line.split('\t'));
  const old = parse('tools/fixtures/IGSH-612/palette-usage.tsv');
  const current = parse('tools/fixtures/IGSH-1743/palette-usage.tsv');
  const replacements = { 2000: '6295', 2005: '6248', 2002: '6240' };
  assert.deepEqual(current, old.map(([id, count, last]) => [replacements[id] ?? id, count, last]));
  assert.match(read('.claude/skills/verify-multiprompt/control.ps1'), /tools\/fixtures\/IGSH-1743\/palette-usage\.tsv/);
});

test('native palette journey seeds and checks the real session and workspace rows', () => {
  const journey = read('.claude/skills/verify-multiprompt/control-feature-palette-order.ps1');
  const control = read('.claude/skills/verify-multiprompt/control.ps1');
  const setupStart = control.indexOf('$paletteRankingSeed = {');
  const setupEnd = control.indexOf('$env:MULTIPROMPT_DICTATION_FIXTURE = $null', setupStart);
  assert.ok(setupStart >= 0 && setupEnd > setupStart);
  const setup = control.slice(setupStart, setupEnd);
  for (const file of ['session.json', 'session-closed-fune-fixture.json', 'windows.json']) {
    assert.match(setup, new RegExp(`WriteAllText\\(\\(Join-Path \\$config '${file.replaceAll('.', '\\.')}'\\)`));
  }
  assert.match(setup, /\$saved\.tabs -isnot \[array\]/);
  assert.match(setup, /\$savedRegistry\.windows -isnot \[array\]/);
  assert.doesNotMatch(journey, /Set-Content|WriteAllText|WriteAllBytes|SetEnvironmentVariable|PostMessage|Copy-Item/);
  const restart = journey.indexOf("Restart-SessionRestore 'palette-ranking' $false $false $paletteRankingSeed");
  assert.ok(restart > 0);
  const restored = journey.slice(restart);
  assert.match(restored, /GetFocusedWindow\(\$script:window\)/);
  assert.match(restored, /Type-Text 'fune'/);
  assert.match(restored, /ready chars=4 count=.*target=0/);
  assert.match(restored, /\$ranked\.Count -lt 2[\s\S]*\$ranked -notcontains \$workspaceId[\s\S]*\$ranked\[0\] -ne '0'[\s\S]*\$ranked\[-1\] -ne \$workspaceId/);
  assert.match(restored, /Snapshot 'typed-session-workspace'/);
  assert.doesNotMatch(restored, /WriteAllBytes|SetEnvironmentVariable|PostMessage|Copy-Item/);
});
