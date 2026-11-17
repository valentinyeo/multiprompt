const nodeTest = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const modulePath = path.join(__dirname, 'touched-journeys.cjs');
const { touchedJourneys } = fs.existsSync(modulePath) ? require(modulePath) : {};
const { discoverFeatures, journeyMatrix } = require('./verify-features.cjs');

function test(name, fn) {
  nodeTest(name, t => {
    assert.equal(typeof touchedJourneys, 'function', 'The changed-file journey selector is available');
    assert.equal(typeof journeyMatrix, 'function', 'The journey matrix includes all feature variants');
    return fn(t);
  });
}

function maps(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'touched-journeys-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  for (const [name, sources] of [['appearance', 'src/themes.zig'], ['chat-view', 'src/chat*.zig, tools/drive-chat.ps1'], ['pane-layout', 'src/panes.zig']]) {
    fs.writeFileSync(path.join(directory, `${name}.md`), `# ${name}\nSource files: ${sources}\nVerify on: push, pull_request\n## Driving it with control.ps1\n`);
  }
  return directory;
}

test('source-file mapping runs only the touched journeys', t => {
  const directory = maps(t);
  assert.deepEqual(touchedJourneys(['src/themes.zig'], directory), { features: ['appearance'], unmapped: [] });
  assert.deepEqual(touchedJourneys(['src/chat_input.zig', 'tools/drive-chat.ps1', 'src/panes.zig'], directory), { features: ['chat-view', 'pane-layout'], unmapped: [] });
  assert.deepEqual(touchedJourneys(['src/chat_inputXzig'], directory).features, ['appearance', 'chat-view', 'pane-layout']);
});

test('unknown application files run every available journey instead of losing coverage', t => {
  const directory = maps(t);
  assert.deepEqual(touchedJourneys(['src/new_feature.zig'], directory), { features: ['appearance', 'chat-view', 'pane-layout'], unmapped: ['src/new_feature.zig'] });
  assert.equal(touchedJourneys(['extension/new.js'], directory).features.length, 3);
  assert.equal(touchedJourneys(['.claude/skills/verify-multiprompt/new-driver.ps1'], directory).features.length, 3);
});

test('documentation and CI-only changes do not launch unrelated desktop journeys', t => {
  const directory = maps(t);
  assert.deepEqual(touchedJourneys(['README.md', '.github/workflows/test.yml', 'tools/pr-verifier.cjs', '.claude/skills/verify-multiprompt/features/appearance.md', 'src/chat.test.js', 'tools/chat-dictation.test.js', 'tools/chat-history-reader-test.py'], directory), { features: [], unmapped: [] });
});

test('diff routing excludes only proven edits inside existing top-level Zig tests', async t => {
  const { touchedJourneysForDiff } = require(modulePath);
  assert.equal(typeof touchedJourneysForDiff, 'function', 'Diff routing compares production source before selecting desktop journeys');
  const { execFileSync } = require('node:child_process');
  const directory = maps(t);
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'journey-source-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8' }).trim();
  git('init', '--quiet');
  git('config', 'user.name', 'Fixture');
  git('config', 'user.email', 'fixture@example.invalid');
  fs.mkdirSync(path.join(root, 'src'));
  const original = 'pub fn color() u8 { return 1; }\n\ntest "fixture" {\n    const nested = .{ .text = "} test \\"fake\\" {" };\n    _ = nested;\n}\n';
  const save = (name, source) => fs.writeFileSync(path.join(root, 'src', name), source);
  const commit = () => { git('add', '.'); git('commit', '--quiet', '-m', 'fixture'); return git('rev-parse', 'HEAD'); };
  save('themes.zig', original);
  const base = commit();
  save('themes.zig', original.replace('_ = nested;', 'try std.testing.expectEqualStrings("} test", nested.text);'));
  let head = commit();
  assert.deepEqual(await touchedJourneysForDiff(base, head, directory, root), { features: [], unmapped: [] });
  save('themes.zig', original.replace('return 1;', 'return 2;'));
  head = commit();
  assert.deepEqual(await touchedJourneysForDiff(base, head, directory, root), { features: ['appearance'], unmapped: [] });
  save('themes.zig', original.replace('const nested', 'const added = 3;\n    const nested') + '\npub const added = 3;\n');
  head = commit();
  assert.deepEqual((await touchedJourneysForDiff(base, head, directory, root)).features, ['appearance']);
  save('themes.zig', original.replace('test "fixture"', 'test "renamed"'));
  head = commit();
  assert.deepEqual((await touchedJourneysForDiff(base, head, directory, root)).features, ['appearance']);
  for (const source of [original + '\ntest "added" {}\n', original.replace('\n}\n', '\n'), original.replace('test "fixture"', 'test')]) {
    save('themes.zig', source);
    head = commit();
    assert.deepEqual((await touchedJourneysForDiff(base, head, directory, root)).features, ['appearance']);
  }
  save('themes.zig', original.replace('_ = nested;', 'try std.testing.expect(true);'));
  fs.mkdirSync(path.join(root, 'tools'));
  fs.writeFileSync(path.join(root, 'tools/drive-chat.ps1'), 'Write-Output changed');
  head = commit();
  assert.deepEqual((await touchedJourneysForDiff(base, head, directory, root)).features, ['chat-view'], 'Desktop driver edits remain covered alongside test-only source edits');
  fs.unlinkSync(path.join(root, 'tools/drive-chat.ps1'));
  save('themes.zig', original);
  save('new_feature.zig', 'test "new" {}\n');
  head = commit();
  assert.deepEqual(await touchedJourneysForDiff(base, head, directory, root), { features: ['appearance', 'chat-view', 'pane-layout'], unmapped: ['src/new_feature.zig'] });
  fs.unlinkSync(path.join(root, 'src/themes.zig'));
  head = commit();
  assert.ok((await touchedJourneysForDiff(base, head, directory, root)).features.includes('appearance'));
  assert.equal(git('worktree', 'list', '--porcelain').match(/^worktree /gm).length, 1, 'Temporary comparison checkouts are removed');
});

test('every runnable feature has source-file ownership in its map', () => {
  const directory = path.join(__dirname, '../.claude/skills/verify-multiprompt/features');
  for (const name of discoverFeatures(directory).available) {
    const text = fs.readFileSync(path.join(directory, `${name}.md`), 'utf8');
    assert.match(text, /^Source files: .+$/m, name);
    assert.ok(touchedJourneys(['src/main.zig'], directory).features.includes(name), name);
  }
  assert.deepEqual(touchedJourneys(['src/themes.zig']).features, ['appearance', 'chat-code-font', 'chat-composer-text', 'generated-theme-amoled', 'generated-theme-dark', 'generated-theme-edgegray', 'generated-theme-light', 'generated-theme-mid', 'settings-panel', 'status-card']);
});

test('the full set retains every DPI and browser-theme variant without multiplying unrelated journeys', () => {
  const features = discoverFeatures().available;
  const matrix = journeyMatrix(features, 'base-revision');
  assert.deepEqual([...new Set(matrix.map(row => row.feature))], features);
  assert.equal(matrix.filter(row => row.feature === 'title-bar').length, 6);
  assert.equal(matrix.filter(row => row.feature === 'window-controls').length, 3);
  assert.equal(matrix.filter(row => row.feature === 'bot-photo').length, 2);
  assert.equal(matrix.filter(row => row.feature === 'appearance').length, 1);
  assert.ok(matrix.every(row => row['app-revision'] === 'base-revision'));
  assert.ok(matrix.length <= 256);
});

test('the verifier runs every mapped journey, even when its picker proposes fewer or slower journeys', t => {
  const directory = maps(t);
  const out = path.join(directory, 'out');
  fs.mkdirSync(out);
  fs.writeFileSync(path.join(out, 'pr.json'), JSON.stringify({ title: 'Speed up checks', body: '', labels: [] }));
  const features = ['appearance', 'chat-view', 'pane-layout', 'command-palette', 'title-bar'];
  fs.writeFileSync(path.join(out, 'mapped.json'), JSON.stringify({ features, unmapped: [] }));
  const result = require('node:child_process').spawnSync(process.execPath, [path.join(__dirname, 'pr-verifier.cjs'), 'select', out], {
    encoding: 'utf8', env: { ...process.env, GITHUB_OUTPUT: path.join(directory, 'output'), FEATURES_DIR: directory, SELECTION: JSON.stringify({ features: ['pane-layout'], compare_base: true }) },
  });
  assert.equal(result.status, 0, result.stderr);
  const selection = JSON.parse(fs.readFileSync(path.join(out, 'selection.json'), 'utf8'));
  assert.deepEqual(selection.features, [...features].sort());
  assert.equal(selection.compareBase, true);
});

test('mandatory chat stillness survives an empty mapper and picker', t => {
  const directory = maps(t);
  fs.writeFileSync(path.join(directory, 'chat-still.md'), '# Stillness\nSource files: src/chat*.zig\nVerify on: pull_request\n## Driving it with control.ps1\n');
  const out = path.join(directory, 'out');
  fs.mkdirSync(out);
  fs.writeFileSync(path.join(out, 'pr.json'), JSON.stringify({ title: 'Chat update', body: '', labels: [], files: [{ path: 'src/chat_render.zig' }] }));
  fs.writeFileSync(path.join(out, 'mapped.json'), JSON.stringify({ features: [], unmapped: [] }));
  const result = require('node:child_process').spawnSync(process.execPath, [path.join(__dirname, 'pr-verifier.cjs'), 'select', out], {
    encoding: 'utf8', env: { ...process.env, GITHUB_OUTPUT: path.join(directory, 'output'), FEATURES_DIR: directory, SELECTION: JSON.stringify({ features: [], compare_base: false }) },
  });
  assert.equal(result.status, 0, result.stderr);
  const selection = JSON.parse(fs.readFileSync(path.join(out, 'selection.json'), 'utf8'));
  assert.deepEqual(selection.features, ['chat-still']);
});

test('shared build profiles and artifact names isolate instrumented and comparison apps', () => {
  const { spawnSync } = require('node:child_process');
  const { runInNewContext } = require('node:vm');
  const root = path.join(__dirname, '..');
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/verify.yml'), 'utf8');
  const script = workflow.split("          node - <<'NODE' >> \"$GITHUB_OUTPUT\"\n")[1].split('          NODE')[0].replace(/^ {10}/gm, '');
  const names = [...workflow.matchAll(/name: (verify-app[^\n]+)/g)].map(match => match[1]);
  assert.equal(names.length, 2);
  for (const [features, profiles] of [
    [['appearance', 'chat-view'], ['normal']],
    [['chat-still'], ['chat-still']],
    [['appearance', 'chat-still', 'chat-view'], ['normal', 'chat-still']],
  ]) {
    const result = spawnSync(process.execPath, ['-e', script], { cwd: root, encoding: 'utf8', env: { ...process.env, FEATURES: JSON.stringify(features), APP_REVISION: '' } });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout.match(/^builds=(.+)$/m)[1]), profiles);
    assert.deepEqual(JSON.parse(result.stdout.match(/^selected=(.+)$/m)[1]), features);
  }
  for (const feature of ['appearance', 'chat-still']) {
    for (const revision of ['', 'base-sha']) {
      const context = { matrix: { profile: feature === 'chat-still' ? 'chat-still' : 'normal' }, env: { FEATURE: feature }, inputs: { app_revision: revision } };
      const actual = names.map(name => name.replace(/\$\{\{ (.*?) \}\}/g, (_, expression) => runInNewContext(expression, context)));
      const expected = `verify-app${feature === 'chat-still' ? '-chat-still' : ''}${revision ? '-compare' : ''}`;
      assert.deepEqual(actual, [expected, expected]);
    }
  }
});

test('mapped model and live-working journeys retain their chat-delivery driver', () => {
  const workflow = fs.readFileSync(path.join(__dirname, '../.github/workflows/verify.yml'), 'utf8');
  const condition = workflow.split('      - name: Select instant chat driver\n')[1].split('\n')[0].trim().slice(4);
  for (const flag of ['CHAT_MODEL_PROOF', 'CHAT_WORKING_LIVE_PROOF', 'CHAT_DOUBLE_CLICK_PROOF']) {
    const expression = condition.replace(/env\.([A-Z_]+)/g, (_, name) => JSON.stringify(name === flag ? '1' : ''));
    assert.equal(require('node:vm').runInNewContext(expression), true, flag);
  }
  const shared = workflow.split('      - name: Download the shared Windows app build\n')[1].split('      - name: Build branch executable')[0];
  assert.doesNotMatch(shared, /CHAT_MODEL_PROOF/);
});

test('a required failing-master journey survives an empty diff selection and a picker that disables comparison', t => {
  const directory = maps(t);
  const out = path.join(directory, 'out');
  fs.mkdirSync(out);
  fs.writeFileSync(path.join(out, 'pr.json'), JSON.stringify({ title: 'Fix appearance', body: 'Repro journey: appearance', labels: [] }));
  fs.writeFileSync(path.join(out, 'mapped.json'), JSON.stringify({ features: [], unmapped: [] }));
  const result = require('node:child_process').spawnSync(process.execPath, [path.join(__dirname, 'pr-verifier.cjs'), 'select', out], {
    encoding: 'utf8', env: { ...process.env, GITHUB_OUTPUT: path.join(directory, 'output'), FEATURES_DIR: directory, SELECTION: JSON.stringify({ features: [], compare_base: false }) },
  });
  assert.equal(result.status, 0, result.stderr);
  const selection = JSON.parse(fs.readFileSync(path.join(out, 'selection.json'), 'utf8'));
  assert.deepEqual(selection.features, ['appearance']);
  assert.equal(selection.compareBase, true);
  assert.match(fs.readFileSync(path.join(directory, 'output'), 'utf8'), /repro_features=\["appearance"\]/);
});
