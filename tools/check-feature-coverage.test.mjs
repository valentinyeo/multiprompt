import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { coverage, compare, inventory, liveRecipe, featureDirectory, snapshot } from './check-feature-coverage.mjs';

const root = path.resolve(import.meta.dirname, '..');
const tool = path.join(root, 'tools/check-feature-coverage.mjs');
const row = (a, b, header = false) => `    .{ .a = "${a}", .b = "${b}", .header = ${header} },`;
const shortcuts = rows => `pub const SHORTCUT_ROWS = [_]ShortcutRow{\n${rows.join('\n')}\n};\n`;
const palette = `pub fn updateSearchResults() void {\n    app_state.g_search_results[0] = SEARCH_OLD_OFFSET;\n}\n`;
const recipe = `# Old action\n\nCovers: palette:SEARCH_OLD_OFFSET\n\n## User entry points\nCtrl+K Old action.\n\n## Driving recipe\nRun control.ps1 -Feature old. Press Ctrl+K, type Old and select it. Require the exact visible result and inspect screenshots and result.json after cleanup.\n\n## Gotchas\nUse an isolated hosted desktop.\n`;
function files(extra = {}) {
  return {
    'src/shortcuts.zig': shortcuts([row('Tabs', '', true), row('Alt+S', 'Favorite')]),
    'src/command_palette.zig': palette,
    'openwiki/architecture/features.md': '## Features\n\n- **Existing behavior**: useful.\n\n## Future Features\n\n- Not shipped.\n',
    [`${featureDirectory}/old.md`]: recipe,
    ...extra,
  };
}
const measure = data => coverage(file => data[file], Object.keys(data));

test('enumerates shortcut actions, palette literals, tables, row families and all shipped wiki features', () => {
  const data = files({
    'src/command_palette.zig': palette + `const ROWS = [_]Row{\n    .{ .target = SEARCH_NEW_OFFSET + 5, .label = "PowerShell" },\n    .{ .id = app_state.SEARCH_TABLE_ROW, .label = "New" },\n};\nfn appendRows() void {\n    app_state.g_search_results[0] = SEARCH_DYNAMIC_OFFSET + i;\n    app_state.g_search_results[1] = room.new_room_target;\n}\n`,
    'openwiki/architecture/features.md': '## Features\n- **One**: useful.\n- Plain feature.\n\nFavorites has groups.\n\n## Future Features\n- Future only.\n\n## Unread boundary\nThe current behavior.\n',
  });
  const ids = inventory(file => data[file]).map(entry => entry.id);
  for (const id of ['shortcut:tabs/alt-s', 'palette:SEARCH_OLD_OFFSET', 'palette:SEARCH_NEW_OFFSET+5', 'palette:SEARCH_TABLE_ROW', 'palette:SEARCH_DYNAMIC_OFFSET', 'palette:new_room_target', 'architecture:one', 'architecture:plain-feature', 'architecture:favorites', 'architecture:unread-boundary']) assert.ok(ids.includes(id), id);
  assert.ok(!ids.some(id => /future|shortcut:tabs\/$/.test(id)));
});

test('comments and test-only palette additions are not user-facing features', () => {
  const data = files({ 'src/command_palette.zig': palette + `\ntest "example" {\n    app_state.g_search_results[0] = SEARCH_TEST_OFFSET;\n}\n` });
  assert.ok(!inventory(file => data[file]).some(entry => entry.id.includes('SEARCH_TEST_OFFSET')));
});

test('every gap is printed but only new gaps fail when a base is supplied', () => {
  const before = measure(files());
  assert.equal(compare(before, before).length, 0);
  const after = measure(files({ 'src/command_palette.zig': palette.replace('SEARCH_OLD_OFFSET;', 'SEARCH_OLD_OFFSET;\n    app_state.g_search_results[1] = SEARCH_NEW_OFFSET;') }));
  assert.deepEqual(compare(after, before).map(entry => entry.id), ['palette:SEARCH_NEW_OFFSET']);
  assert.equal(after.gaps.length, before.gaps.length + 1);
});

test('a real mapped live recipe counts and cannot be deleted or replaced by unreachable', () => {
  const before = measure(files());
  assert.equal(before.covered, 1);
  const removed = files();
  delete removed[`${featureDirectory}/old.md`];
  assert.deepEqual(compare(measure(removed), before).map(entry => entry.id), ['palette:SEARCH_OLD_OFFSET']);
  for (const text of [recipe.replace('Press Ctrl+K', 'Unreachable. Press Ctrl+K'), recipe.replace('## Driving recipe', '## Notes'), '# Placeholder\nCovers: palette:SEARCH_OLD_OFFSET\n']) {
    assert.equal(liveRecipe(text), false);
    assert.equal(measure(files({ [`${featureDirectory}/old.md`]: text })).covered, 0);
    assert.equal(measure(files({ [`${featureDirectory}/old.md`]: text })).invalid.length, 1);
  }
});

test('fixing an inherited gap locks that improvement in on the next change', () => {
  const before = measure(files());
  const fixed = measure(files({ [`${featureDirectory}/old.md`]: recipe.replace('palette:SEARCH_OLD_OFFSET', 'palette:SEARCH_OLD_OFFSET, shortcut:tabs/alt-s') }));
  assert.equal(compare(fixed, before).length, 0);
  assert.deepEqual(compare(before, fixed).map(entry => entry.id), ['shortcut:tabs/alt-s']);
});

test('unknown source claims and missing source formats fail closed', () => {
  assert.match(measure(files({ [`${featureDirectory}/old.md`]: recipe.replace('SEARCH_OLD_OFFSET', 'SEARCH_TYPO_OFFSET') })).invalid.join('\n'), /unknown source entry/);
  assert.throws(() => measure(files({ 'src/shortcuts.zig': 'renamed' })), /SHORTCUT_ROWS/);
  assert.throws(() => measure(files({ 'src/command_palette.zig': '' })), /No palette/);
});

test('CLI reports numeric coverage, the full gap list and a nonzero strict result', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'feature-coverage-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  for (const [file, text] of Object.entries(files())) {
    fs.mkdirSync(path.dirname(path.join(directory, file)), { recursive: true });
    fs.writeFileSync(path.join(directory, file), text);
  }
  const git = args => execFileSync('git', args, { cwd: directory, stdio: 'pipe' });
  git(['init']);
  git(['add', '.']);
  git(['-c', 'user.name=Coverage fixture', '-c', 'user.email=coverage@example.invalid', 'commit', '-m', 'Initial fixture']);
  const run = args => spawnSync(process.execPath, [tool, ...args], { cwd: directory, encoding: 'utf8', env: { ...process.env, GITHUB_STEP_SUMMARY: '' } });
  assert.equal(run([]).status, 1);
  assert.match(run([]).stdout, /33.33% \(1\/3\)/);
  assert.match(run([]).stdout, /shortcut:tabs\/alt-s/);
  assert.match(run([]).stdout, /architecture:existing-behavior/);
  assert.equal(run(['--base', 'HEAD']).status, 0);
  const current = JSON.parse(run(['--base', 'HEAD', '--json']).stdout);
  assert.equal(current.percent, 33.33);
  assert.equal(current.gaps.length, 2);
  assert.equal(current.newGaps.length, 0);
  fs.writeFileSync(path.join(directory, 'src/command_palette.zig'), palette.replace('SEARCH_OLD_OFFSET;', 'SEARCH_NEW_OFFSET;'));
  assert.equal(run(['--base', 'HEAD']).status, 1);
  assert.equal(run(['--base', 'missing-commit']).status, 1);
});

test('SOFT-2276 real Pi login addition is rejected without a map entry', t => {
  const fixture = JSON.parse(fs.readFileSync(path.join(root, 'tools/fixtures/SOFT-2567e/pi-login.json'), 'utf8'));
  assert.equal(fixture.commit, '0e0c8c7cfddb8bb97c556d41e185ef4a665030b7');
  const before = measure(files({ 'src/shortcuts.zig': fixture.before.shortcuts, 'src/command_palette.zig': fixture.before.palette }));
  const after = measure(files({ 'src/shortcuts.zig': fixture.after.shortcuts, 'src/command_palette.zig': fixture.after.palette }));
  assert.deepEqual(compare(after, before).map(entry => entry.id), [
    'palette:SEARCH_PI_LOGIN_OFFSET',
    'shortcut:palette-actions/ctrl-k-log-in',
    'shortcut:palette-actions/login-in-a-pi-chat',
  ]);
  assert.deepEqual(fixture.featureFilesWithLoginRecipe, []);
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'feature-coverage-history-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const data = files({ 'src/shortcuts.zig': fixture.before.shortcuts, 'src/command_palette.zig': fixture.before.palette });
  delete data[`${featureDirectory}/old.md`];
  data[`${featureDirectory}/README.md`] = 'Historical Pi login had no feature map.\n';
  for (const [file, text] of Object.entries(data)) {
    fs.mkdirSync(path.dirname(path.join(directory, file)), { recursive: true });
    fs.writeFileSync(path.join(directory, file), text);
  }
  const git = args => execFileSync('git', args, { cwd: directory, stdio: 'pipe' });
  git(['init']);
  git(['add', '.']);
  git(['-c', 'user.name=Coverage fixture', '-c', 'user.email=coverage@example.invalid', 'commit', '-m', 'Before the Pi login addition']);
  fs.writeFileSync(path.join(directory, 'src/shortcuts.zig'), fixture.after.shortcuts);
  fs.writeFileSync(path.join(directory, 'src/command_palette.zig'), fixture.after.palette);
  const result = spawnSync(process.execPath, [tool, '--base', 'HEAD'], { cwd: directory, encoding: 'utf8', env: { ...process.env, GITHUB_STEP_SUMMARY: '' } });
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, /3 new gaps/);
  assert.match(result.stderr, /SEARCH_PI_LOGIN_OFFSET/);
  t.diagnostic(`Historical ${fixture.commit}: exit ${result.status}; 3 new Pi login gaps rejected.`);
});

test('the real checkout inventory is nonempty and baseline mode reports every current gap', () => {
  const report = snapshot(root);
  assert.ok(report.total > 300);
  assert.equal(report.invalid.length, 0, report.invalid.join('\n'));
  assert.equal(report.covered + report.gaps.length, report.total);
});
