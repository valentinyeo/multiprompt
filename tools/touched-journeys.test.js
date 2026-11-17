const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { touchedJourneys } = require('./touched-journeys.cjs');
const { discoverFeatures, journeyMatrix } = require('./verify-features.cjs');

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
  assert.deepEqual(touchedJourneys(['README.md', '.github/workflows/test.yml', 'tools/pr-verifier.cjs', '.claude/skills/verify-multiprompt/features/appearance.md'], directory), { features: [], unmapped: [] });
});

test('every runnable feature has source-file ownership in its map', () => {
  const directory = path.join(__dirname, '../.claude/skills/verify-multiprompt/features');
  for (const name of discoverFeatures(directory).available) {
    const text = fs.readFileSync(path.join(directory, `${name}.md`), 'utf8');
    assert.match(text, /^Source files: .+$/m, name);
    assert.ok(touchedJourneys(['src/main.zig'], directory).features.includes(name), name);
  }
  assert.deepEqual(touchedJourneys(['src/themes.zig']).features, ['appearance', 'chat-code-font', 'chat-composer-text', 'settings-panel', 'status-card']);
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
  const features = ['appearance', 'chat-view', 'pane-layout', 'command-palette', 'title-bar'];
  fs.writeFileSync(path.join(out, 'mapped.json'), JSON.stringify({ features, unmapped: [] }));
  const result = require('node:child_process').spawnSync(process.execPath, [path.join(__dirname, 'pr-verifier.cjs'), 'select', out], {
    encoding: 'utf8', env: { ...process.env, GITHUB_OUTPUT: path.join(directory, 'output'), FEATURES_DIR: directory, SELECTION: JSON.stringify({ features: ['pane-layout'], compare_base: true }) },
  });
  assert.equal(result.status, 0, result.stderr);
  const selection = JSON.parse(fs.readFileSync(path.join(out, 'selection.json'), 'utf8'));
  assert.deepEqual(selection.features, features);
  assert.equal(selection.compareBase, true);
});
