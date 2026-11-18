import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
for (const file of ['journey-commands.mjs', 'check-journey-commands.mjs']) {
  assert.ok(fs.existsSync(new URL(file, import.meta.url)), `Stable journey command runner requires tools/${file}`);
}
const { commandCatalog, root } = await import('./journey-commands.mjs');
const { checkJourneyCommands, checkJourneys } = await import('./check-journey-commands.mjs');
const catalog = commandCatalog();

test('PowerShell helper selects the named row with child focus and rejects unchanged screens', context => {
  const result = spawnSync(process.platform === 'win32' ? 'powershell.exe' : 'pwsh', ['-NoProfile', '-File', path.join(root, 'tools/test-journey-commands.ps1')], { encoding: 'utf8' });
  if (result.error?.code === 'ENOENT') return context.skip('PowerShell runs on GitHub-hosted runners');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /NAMED_COMMAND_ROW_AND_SCREEN_VERIFIED/);
});

test('all desktop journeys use current stable names', () => {
  assert.deepEqual(checkJourneys(), []);
});

test('old names and numeric calls fail with the replacement API', () => {
  for (const source of ["Palette 'new cmd'", "Focus-Palette 'new cmd' 2000", "if ($ready) { Palette 'interface' }", "Invoke-JourneyCommand 'new cmd shell' 2000"]) {
    assert.match(checkJourneyCommands(source).join('\n'), /Invoke-JourneyCommand/);
  }
  assert.match(checkJourneyCommands("Invoke-JourneyCommand 'new cmd'").join('\n'), /unknown command name/);
  assert.deepEqual(checkJourneyCommands("Invoke-JourneyCommand 'new cmd shell'"), []);
  assert.deepEqual(checkJourneyCommands("Invoke-JourneyCommand 'Restore middle' -Session"), []);
});

test('the CLI rejects a sample old-style journey', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'journey-commands-'));
  try {
    fs.writeFileSync(path.join(directory, 'old.ps1'), "Focus-Palette 'new cmd' 2000\n");
    const result = spawnSync(process.execPath, [path.join(root, 'tools/check-journey-commands.mjs'), directory], { encoding: 'utf8' });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /old.ps1:1: use Invoke-JourneyCommand/);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('routing renumbering follows production source without editing a journey', () => {
  const read = file => fs.readFileSync(path.join(root, 'src', file), 'utf8');
  const renumbered = commandCatalog(file => file === 'app_state.zig'
    ? read(file).replace(/(pub const SEARCH_NEW_OFFSET: usize = )\d+;/, '$19000;')
    : read(file));
  assert.equal(renumbered['new cmd shell'].target, 9000);
  assert.equal(renumbered['new powershell'].target, 9005);
  assert.equal(renumbered.changelog.target, catalog.changelog.target);
  assert.throws(() => commandCatalog(file => file === 'app_state.zig' ? read(file) : read(file).replace(/changelog/gi, 'release history')), /command name is no longer.*Changelog/);
});

test('tab-order commands resolve to a row the live palette actually produces', () => {
  const state = fs.readFileSync(path.join(root, 'src/app_state.zig'), 'utf8');
  const offsets = new Map([...state.matchAll(/pub const (SEARCH_\w+): usize = (\d+);/g)].map(([, symbol, value]) => [symbol, Number(value)]));
  const palette = fs.readFileSync(path.join(root, 'src/command_palette.zig'), 'utf8');
  const produced = [...palette.matchAll(/g_search_results\[[^\]]+\] = (SEARCH_TABSORT_\w+);/g)].map(([, symbol]) => offsets.get(symbol));
  for (const entry of Object.values(catalog).filter(entry => entry.query === 'tab order')) {
    assert.ok(produced.includes(entry.target), `${entry.name} must select a produced palette row`);
  }
});

test('group selection follows saved session identity rather than grouped display order', () => {
  const driver = fs.readFileSync(path.join(root, '.claude/skills/verify-multiprompt/control-feature-group-rail.ps1'), 'utf8');
  assert.match(driver, /Invoke-JourneyCommand 'Rail A' -Session/);
  assert.match(driver, /Invoke-JourneyCommand \('Rail ' \+ \[char\]\(65 \+ \$selected\)\) -Session/);
  assert.doesNotMatch(driver, /Press @\(0x11, (?:0x3[1-4]|\(0x31 \+ \$selected\))/);
});

test('status-card relies on the named row selection instead of a retired routing number', () => {
  const driver = fs.readFileSync(path.join(root, '.claude/skills/verify-multiprompt/control-feature-status-card.ps1'), 'utf8');
  assert.match(driver, /Invoke-JourneyCommand 'Tab order: auto'/);
  assert.doesNotMatch(driver, /target=6218/);
});

test('catalog entries keep the row name separate from its search query', () => {
  assert.equal(catalog['archive chat'].query, 'archive chat');
  assert.equal(catalog['ui size: reset'].query, 'ui');
  assert.equal(catalog['manage snippets'].target, Number(fs.readFileSync(path.join(root, 'src/app_state.zig'), 'utf8').match(/pub const SEARCH_SNIPPET_MANAGE_OFFSET: usize = (\d+);/)[1]));
});
