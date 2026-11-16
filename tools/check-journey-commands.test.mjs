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

test('PowerShell helper rejects unchanged screens and wrong commands', context => {
  const result = spawnSync('pwsh', ['-NoProfile', '-File', path.join(root, 'tools/test-journey-commands.ps1')], { encoding: 'utf8' });
  if (result.error?.code === 'ENOENT') return context.skip('PowerShell runs on GitHub-hosted runners');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /NAMED_COMMAND_ROW_SCREEN_AND_IDENTITY_VERIFIED/);
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
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'journey-catalog-'));
  try {
    fs.mkdirSync(path.join(directory, 'src'));
    for (const file of ['app_state.zig', 'command_palette.zig', 'sidebar.zig', 'ui_words.zon', 'shortcuts.zig']) {
      fs.copyFileSync(path.join(root, 'src', file), path.join(directory, 'src', file));
    }
    const state = path.join(directory, 'src/app_state.zig');
    fs.writeFileSync(state, fs.readFileSync(state, 'utf8').replace(/(pub const SEARCH_NEW_OFFSET: usize = )\d+;/, '$19000;'));
    assert.equal(commandCatalog(directory)['new cmd shell'].target, 9000);
    assert.equal(commandCatalog(directory)['new powershell'].target, 9005);
    assert.equal(commandCatalog(directory).changelog.target, catalog.changelog.target);
    for (const file of ['command_palette.zig', 'sidebar.zig', 'ui_words.zon', 'shortcuts.zig']) {
      const source = path.join(directory, 'src', file);
      fs.writeFileSync(source, fs.readFileSync(source, 'utf8').replace(/changelog/gi, 'release history'));
    }
    assert.throws(() => commandCatalog(directory), /command name is no longer.*Changelog/);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('catalog entries keep the row name separate from its search query', () => {
  assert.equal(catalog['archive chat'].query, 'archive chat');
  assert.equal(catalog['ui size: reset'].query, 'ui');
  assert.equal(catalog['manage snippets'].target, Number(fs.readFileSync(path.join(root, 'src/app_state.zig'), 'utf8').match(/pub const SEARCH_SNIPPET_MANAGE_OFFSET: usize = (\d+);/)[1]));
});
