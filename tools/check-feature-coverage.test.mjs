import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const root = path.resolve(import.meta.dirname, '..');
const tool = path.join(root, 'tools/check-feature-coverage.mjs');

test('the coverage CLI runs and reports numeric source coverage', () => {
  const result = spawnSync(process.execPath, [tool, '--json'], { cwd: root, encoding: 'utf8', env: { ...process.env, GITHUB_STEP_SUMMARY: '' } });
  assert.equal(result.status, 0, 'The source coverage CLI must run successfully before its coverage can be trusted');
  const report = JSON.parse(result.stdout);
  assert.equal(typeof report.percent, 'number');
  assert.ok(report.total > 300);
});

if (fs.existsSync(tool)) {
const { coverage, inventory, liveRecipe, featureDirectory } = await import('./check-feature-coverage.mjs');
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
    'openwiki/architecture/features.md': '## Core Design\n### Architecture\n- **Drag to reorder**: move tabs.\n\n## Features\n- **One**: useful.\n- Plain feature.\n\nFavorites has groups.\n\n## Future Features\n- Future only.\n\n## Unread boundary\nThe current behavior.\n',
  });
  const ids = inventory(file => data[file]).map(entry => entry.id);
  for (const id of ['shortcut:tabs/alt-s', 'palette:SEARCH_OLD_OFFSET', 'palette:SEARCH_NEW_OFFSET+5', 'palette:SEARCH_TABLE_ROW', 'palette:SEARCH_DYNAMIC_OFFSET', 'palette:new_room_target', 'architecture:drag-to-reorder', 'architecture:one', 'architecture:plain-feature', 'architecture:favorites', 'architecture:unread-boundary']) assert.ok(ids.includes(id), id);
  assert.ok(!ids.some(id => /future|shortcut:tabs\/$/.test(id)));
});

test('comments and test-only palette additions are not user-facing features', () => {
  const data = files({ 'src/command_palette.zig': palette + `\ntest "example" {\n    app_state.g_search_results[0] = SEARCH_TEST_OFFSET;\n}\n` });
  assert.ok(!inventory(file => data[file]).some(entry => entry.id.includes('SEARCH_TEST_OFFSET')));
});

test('new gaps are counted in the report and never change the result', () => {
  const before = measure(files());
  const after = measure(files({ 'src/command_palette.zig': palette.replace('SEARCH_OLD_OFFSET;', 'SEARCH_OLD_OFFSET;\n    app_state.g_search_results[1] = SEARCH_NEW_OFFSET;') }));
  assert.equal(after.gaps.length, before.gaps.length + 1);
  assert.ok(after.gaps.some(entry => entry.id === 'palette:SEARCH_NEW_OFFSET'));
});

test('a real mapped live recipe counts and cannot be deleted or replaced by unreachable', () => {
  const before = measure(files());
  assert.equal(before.covered, 1);
  const removed = files();
  delete removed[`${featureDirectory}/old.md`];
  assert.equal(measure(removed).covered, 0);
  for (const text of [recipe.replace('Press Ctrl+K', 'Unreachable. Press Ctrl+K'), recipe.replace('## Driving recipe', '## Notes'), '# Placeholder\nCovers: palette:SEARCH_OLD_OFFSET\n']) {
    assert.equal(liveRecipe(text), false);
    assert.equal(measure(files({ [`${featureDirectory}/old.md`]: text })).covered, 0);
    assert.equal(measure(files({ [`${featureDirectory}/old.md`]: text })).invalid.length, 1);
  }
});

test('unknown source claims and missing source formats fail closed', () => {
  assert.match(measure(files({ [`${featureDirectory}/old.md`]: recipe.replace('SEARCH_OLD_OFFSET', 'SEARCH_TYPO_OFFSET') })).invalid.join('\n'), /unknown source entry/);
  assert.throws(() => measure(files({ 'src/shortcuts.zig': 'renamed' })), /SHORTCUT_ROWS/);
  assert.throws(() => measure(files({ 'src/command_palette.zig': '' })), /No palette/);
});

test('CLI reports numeric coverage and the full gap list without failing on gaps', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'feature-coverage-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  for (const [file, text] of Object.entries(files())) {
    fs.mkdirSync(path.dirname(path.join(directory, file)), { recursive: true });
    fs.writeFileSync(path.join(directory, file), text);
  }
  const run = args => spawnSync(process.execPath, [tool, ...args], { cwd: directory, encoding: 'utf8', env: { ...process.env, GITHUB_STEP_SUMMARY: '' } });
  const report = run([]);
  assert.equal(report.status, 0, report.stdout + report.stderr);
  assert.match(report.stdout, /33.33% \(1\/3\)/);
  assert.match(report.stdout, /shortcut:tabs\/alt-s/);
  assert.match(report.stdout, /architecture:existing-behavior/);
  const current = JSON.parse(run(['--json']).stdout);
  assert.equal(current.percent, 33.33);
  assert.equal(current.gaps.length, 2);
  const legacy = run(['--base', 'missing-commit']);
  assert.equal(legacy.status, 1);
  assert.match(legacy.stderr, /Usage: node tools\/check-feature-coverage\.mjs \[--json\]/);
  fs.writeFileSync(path.join(directory, `${featureDirectory}/old.md`), recipe.replace('SEARCH_OLD_OFFSET', 'SEARCH_TYPO_OFFSET'));
  assert.equal(run([]).status, 1);
});
}
