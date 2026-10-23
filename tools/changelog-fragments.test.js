const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const fragment = 'changelog.d/DEMO-1-change.md';

for (const line of ['Fix IGSH-123.', 'Fix ABC-9.', 'Fix src/main.zig.', 'Fix main.zig.', 'Fix C:\\app\\settings.', 'Fix PR #123.', 'Fix PR 123.', 'Fix pull request 123.', 'Fix #123.', 'Fix `renderer`.', 'A\ttab.']) {
  test(`fragment red case: ${JSON.stringify(line)}`, async () => {
    const { checkFragments, stampTree, plainChange } = await import('./version-stamp.mjs');
    assert.equal(plainChange(line), false);
    const tree = { [fragment]: `${line}\n` };
    assert.throws(() => checkFragments({}, tree, ['src/example.zig', fragment]), /plain product lines/);
    assert.throws(() => stampTree({
      'src/main.zig': 'pub const APP_VERSION = "1.0.0";\n',
      'src/changelog.zig': 'pub const CHANGELOG = [_]ChangelogEntry{\n};\n',
      ...tree,
    }), /plain product lines/);
  });
}

test('app code requires a newly added fragment, not an edited or inherited one', async () => {
  const { checkFragments } = await import('./version-stamp.mjs');
  assert.throws(() => checkFragments({}, {}, ['src/example.zig']), /App code changed: add changelog.d/);
  const base = { [fragment]: 'Typing feels faster.\n' };
  assert.throws(() => checkFragments(base, base, ['src/example.zig']), /App code changed/);
  assert.throws(() => checkFragments(base, { [fragment]: 'Tabs open sooner.\n' }, ['src/example.zig', fragment]), /App code changed/);
  assert.throws(() => checkFragments({}, { [fragment]: ' \n' }, ['src/example.zig', fragment]), /no text/);
  assert.throws(() => checkFragments({}, { 'changelog.d/README.md': 'Guide.' }, ['src/example.zig', 'changelog.d/README.md']), /App code changed/);
  assert.doesNotThrow(() => checkFragments({}, base, ['src/example.zig', fragment]));
  assert.doesNotThrow(() => checkFragments({}, {}, ['tools/example.mjs']));
});

test('all pending fragments are plain, including those inherited from master', async () => {
  const { fragmentLines } = await import('./version-stamp.mjs');
  const names = fs.readdirSync(path.join(root, 'changelog.d')).filter(name => name !== 'README.md');
  assert.ok(names.length > 0);
  for (const name of names) assert.ok(fragmentLines(`changelog.d/${name}`, fs.readFileSync(path.join(root, 'changelog.d', name), 'utf8')).length > 0);
});

test('release stamps preserve plain Unicode and quoted product lines; exact stamps still bypass code-fragment requirement', async () => {
  const { stampTree, classifyTrees } = await import('./version-stamp.mjs');
  const base = {
    'src/main.zig': 'pub const APP_VERSION = "1.0.0";\n',
    'src/changelog.zig': 'pub const CHANGELOG = [_]ChangelogEntry{\n};\n',
    [fragment]: 'Open "saved chats" at the café.\n',
  };
  const stamp = stampTree(base);
  assert.equal(stamp.version, '1.0.1');
  assert.match(stamp.files['src/changelog.zig'], /Open \\"saved chats\\" at the café/);
  assert.equal(classifyTrees(base, stamp.files, ['src/main.zig', 'src/changelog.zig', fragment]), 'STAMP');
});

test('existing CI version check enforces fragments for code but preserves generated stamps', () => {
  const script = fs.readFileSync(path.join(root, 'tools/version-stamp.mjs'), 'utf8');
  assert.match(script, /if \(kind === 'CODE'\) checkFragments\(base, head, changed\);/);
  assert.match(script, /const lines = fragmentLines\(file, files\[file\]\);/);
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  assert.match(workflow, /node tools\/version-stamp\.mjs check/);
  assert.match(workflow, /node --test tools\/changelog-fragments\.test\.js tools\/update-card-notes\.test\.js/);
});
