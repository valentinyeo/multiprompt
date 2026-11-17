import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { snapshot, featureDirectory } from './check-feature-coverage.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const skill = '.claude/skills/verify-multiprompt';
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
async function generator() {
  assert.ok(fs.existsSync(path.join(root, 'tools/generate-feature-journeys.mjs')), 'Source-row journey generator must exist');
  return import('./generate-feature-journeys.mjs');
}

test('source lists generate only rows with an independent behavioral assertion', async () => {
  const { generate } = await generator();
  const { rows, gaps } = generate(read);
  assert.equal(rows.length, 7);
  assert.deepEqual(rows.filter(row => row.shape === 'theme-color').map(row => row.saved).sort(), ['amoled', 'dark', 'edgegray', 'light', 'mid']);
  assert.equal(rows.find(row => row.saved === 'light').rgb, 243);
  assert.equal(rows.find(row => row.id === 'shortcut:view/ctrl-shift-b').chord, 'Ctrl+Shift+B');
  assert.ok(gaps.some(row => row.id === 'palette:SEARCH_THEME_SYSTEM_OFFSET'));
  assert.ok(gaps.some(row => row.id === 'palette:SEARCH_THEME_MULTIPROMPT_OFFSET'));
  assert.ok(gaps.every(row => !rows.some(covered => covered.id === row.id)));
});

test('new unsupported shortcut and palette rows remain explicit gaps', async () => {
  const { generate } = await generator();
  const changed = file => file === 'src/shortcuts.zig'
    ? read(file).replace('pub const SHORTCUT_ROWS = [_]ShortcutRow{', 'pub const SHORTCUT_ROWS = [_]ShortcutRow{\n    .{ .a = "New section", .b = "", .header = true },\n    .{ .a = "Ctrl+F12", .b = "New behavior", .header = false },')
    : file === 'src/command_palette.zig' ? read(file).replace('SEARCH_THEME_MID_OFFSET, SEARCH_THEME_LIGHT_OFFSET', 'SEARCH_NEW_THEME_OFFSET, SEARCH_THEME_MID_OFFSET, SEARCH_THEME_LIGHT_OFFSET') : read(file);
  const { rows, gaps } = generate(changed);
  assert.equal(rows.length, 7);
  assert.ok(gaps.some(row => row.id === 'shortcut:new-section/ctrl-f12'));
  assert.ok(gaps.some(row => row.id === 'palette:SEARCH_NEW_THEME_OFFSET'));
});

test('removing a supported source row removes its generated journey and claim', async () => {
  const { generate } = await generator();
  const { rows, gaps } = generate(file => file === 'src/shortcuts.zig'
    ? read(file).replace(/^.*\.a = "Ctrl\+Shift\+B".*\n/m, '')
    : file === 'src/command_palette.zig' ? read(file).replace('SEARCH_THEME_MID_OFFSET, SEARCH_THEME_LIGHT_OFFSET', 'SEARCH_THEME_LIGHT_OFFSET') : read(file));
  assert.equal(rows.length, 5);
  assert.ok(!rows.some(row => row.id === 'shortcut:view/ctrl-shift-b'));
  assert.ok(gaps.some(row => row.id === 'palette:SEARCH_THEME_MID_OFFSET'));
});

test('generation is repeatable, checked for drift, and reduces real coverage gaps by seven', async t => {
  const { main } = await generator();
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'generated-row-test-'));
  t.after(() => fs.rmSync(scratch, { recursive: true, force: true }));
  for (const file of ['src/shortcuts.zig', 'src/command_palette.zig', 'openwiki/architecture/features.md', `${skill}/control.ps1`]) {
    fs.mkdirSync(path.dirname(path.join(scratch, file)), { recursive: true });
    fs.writeFileSync(path.join(scratch, file), read(file));
  }
  fs.cpSync(path.join(root, featureDirectory), path.join(scratch, featureDirectory), { recursive: true });
  for (const name of fs.readdirSync(path.join(scratch, featureDirectory)).filter(name => name.startsWith('generated-'))) fs.unlinkSync(path.join(scratch, featureDirectory, name));
  const before = snapshot(scratch);
  const first = main([], scratch);
  assert.equal(first.rows.length, 7);
  const after = snapshot(scratch);
  assert.equal(before.gaps.length - after.gaps.length, 7);
  assert.deepEqual(after.invalid, []);
  const files = [...fs.readdirSync(path.join(scratch, featureDirectory)).filter(name => name.startsWith('generated-')).map(name => `${featureDirectory}/${name}`), `${skill}/generated-journeys.json`, `${skill}/control.ps1`, `${featureDirectory}/README.md`];
  const bytes = files.map(file => fs.readFileSync(path.join(scratch, file), 'utf8'));
  main([], scratch);
  assert.deepEqual(files.map(file => fs.readFileSync(path.join(scratch, file), 'utf8')), bytes);
  main(['--check'], scratch);
  fs.appendFileSync(path.join(scratch, files[0]), 'stale');
  assert.throws(() => main(['--check'], scratch), /stale/);
  main([], scratch);
  main(['--check'], scratch);
});

test('planted break consumes the actual shortcut but leaves its advertised source row intact', async () => {
  await generator();
  assert.ok(fs.existsSync(path.join(root, 'tools/plant-shortcut-break.mjs')));
  const { plantShortcutBreak } = await import('./plant-shortcut-break.mjs');
  const original = read('src/shortcuts.zig');
  const broken = plantShortcutBreak(original);
  assert.notEqual(broken, original);
  assert.equal(original.length - broken.length, '_ = PostMessageW(app_state.g_main_hwnd, WM_APP_TOGGLE_SIDEBAR, 0, 0);'.length);
  assert.match(broken, /\.a = "Ctrl\+Shift\+B"/);
  assert.throws(() => plantShortcutBreak(broken), /exactly one/);
  const { generate } = await generator();
  assert.deepEqual(generate(file => file === 'src/shortcuts.zig' ? broken : read(file)).rows, generate(read).rows);
});

test('hosted desktop routing runs generated rows and rejects a mutation failing for the wrong reason', async () => {
  await generator();
  const workflow = read('.github/workflows/verify.yml');
  assert.match(workflow, /plant-shortcut-break\.mjs/);
  assert.match(workflow, /generated-sidebar-cycle/);
  assert.match(workflow, /collapsed sidebar saved/);
  assert.match(workflow, /shortcut-break\/result\.json/);
  assert.match(workflow, /activeAfterStop -ne 0/);
  const driver = read(`${skill}/control-feature-generated.ps1`);
  assert.match(driver, /Sidebar-Dominant/);
  assert.match(driver, /GetWindowRect/);
  assert.match(driver, /Wait-WorkspaceSurface/);
  const { spawnSync } = await import('node:child_process');
  const matrix = workflow.split("          node - <<'NODE' >> \"$GITHUB_OUTPUT\"\n")[1].split('          NODE')[0].replace(/^ {10}/gm, '');
  for (const [revision, expected] of [['', ['normal', 'shortcut-break']], ['base-sha', ['normal']]]) {
    const run = spawnSync(process.execPath, ['-e', matrix], { cwd: root, encoding: 'utf8', env: { ...process.env, FEATURES: '["generated-sidebar-cycle"]', APP_REVISION: revision } });
    assert.equal(run.status, 0, run.stderr);
    assert.deepEqual(JSON.parse(run.stdout.match(/^builds=(.+)$/m)[1]), expected);
  }
  assert.equal((workflow.match(/name: shortcut-break-app/g) || []).length, 2);
});
