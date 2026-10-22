const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { copyZig, imports, handWrittenLists } = require('./zig-copy');
const root = path.resolve(__dirname, '..');

function temporary(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'zig-copy-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  return dir;
}

function historical(file, revision = '3524346') {
  try {
    return execFileSync('git', ['show', `${revision}:${file}`], { cwd: root, encoding: 'utf8', maxBuffer: 8 * 1024 * 1024 });
  } catch (error) {
    throw new Error(`Required history ${revision}:${file} is unavailable; fetch full history (CI checkout needs fetch-depth: 0)`, { cause: error });
  }
}

test('imports finds Zig files but ignores comments, strings and named modules', () => {
  const source = [
    'const std = @import("std");',
    'const a = @import("nested/a.zig");',
    '  // const ignored = @import("missing.zig");',
    'const text = "@import(\\"not-an-import.zig\\")";',
    'const url = "https://example.test"; const b = @import ( "b.zig" ); // @import("ignored.zig")',
    'const c = @import("data.json");',
  ].join('\n');
  assert.deepEqual(imports(source), ['nested/a.zig', 'b.zig']);
});

test('copyZig follows nested relative imports, preserves layout, deduplicates cycles and permits stub overrides', t => {
  const dir = temporary(t);
  const src = path.join(dir, 'src');
  fs.mkdirSync(path.join(src, 'nested/deeper'), { recursive: true });
  const fixtures = {
    'root.zig': '@import("std"); @import("nested/a.zig"); @import("nested/a.zig"); @import("../outside.zig"); @import("data.json");\n// @import("missing.zig")\n',
    'nested/a.zig': '@import("deeper/b.zig"); @import("../shared.zig");',
    'nested/deeper/b.zig': '@import("../../root.zig");',
    'shared.zig': 'pub const value = 42;\n',
    'unused.zig': 'unused',
  };
  for (const [name, source] of Object.entries(fixtures)) fs.writeFileSync(path.join(src, name), source);
  const dest = path.join(dir, 'dest');
  const copied = copyZig(['root.zig', 'shared.zig', '../outside.zig'], dest, src);
  assert.deepEqual(copied.sort(), ['nested/a.zig', 'nested/deeper/b.zig', 'root.zig', 'shared.zig']);
  for (const name of copied) assert.equal(fs.readFileSync(path.join(dest, name), 'utf8'), fixtures[name]);
  fs.writeFileSync(path.join(dest, 'shared.zig'), 'stub');
  assert.equal(fs.readFileSync(path.join(dest, 'shared.zig'), 'utf8'), 'stub');
  assert.ok(!fs.existsSync(path.join(dest, 'unused.zig')));
  assert.ok(!fs.existsSync(path.join(dir, 'outside.zig')));
});

test('copyZig names the importing file when an import is missing', t => {
  const dir = temporary(t);
  const src = path.join(dir, 'src');
  fs.mkdirSync(path.join(src, 'nested'), { recursive: true });
  fs.writeFileSync(path.join(src, 'root.zig'), '@import("nested/child.zig");');
  fs.writeFileSync(path.join(src, 'nested/child.zig'), '@import("missing.zig");');
  assert.throws(() => copyZig(['root.zig'], path.join(dir, 'dest'), src), /Cannot copy Zig file nested\/missing\.zig imported by nested\/child\.zig/);
});

test('ISSUE-270 replay copies the new chat_diff import that the old literal list omitted', t => {
  const dir = temporary(t);
  const src = path.join(dir, 'src');
  const loaded = new Set();
  function load(name) {
    if (loaded.has(name)) return;
    loaded.add(name);
    const source = historical(`src/${name}`, '7e14a68');
    const file = path.join(src, name);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, source);
    for (const dependency of imports(source)) load(path.posix.normalize(path.posix.join(path.posix.dirname(name), dependency)));
    for (const match of source.matchAll(/@embedFile\("([^"\r\n]+)"\)/g)) {
      const asset = path.posix.normalize(path.posix.join(path.posix.dirname(name), match[1]));
      fs.mkdirSync(path.dirname(path.join(src, asset)), { recursive: true });
      fs.writeFileSync(path.join(src, asset), historical(`src/${asset}`, '7e14a68'));
    }
  }
  load('chat_history.zig');
  const copied = copyZig(['chat_history.zig'], path.join(dir, 'dest'), src);
  assert.ok(copied.includes('chat_diff.zig'));
  assert.equal(fs.readFileSync(path.join(dir, 'dest/chat_diff.zig'), 'utf8'), historical('src/chat_diff.zig', '7e14a68'));
  const old = handWrittenLists(historical('tools/chat-cache-bound.test.js'));
  assert.equal(old.length, 1);
  assert.match(old[0], /chat_history\.zig/);
  assert.doesNotMatch(old[0], /chat_diff\.zig/);
  assert.match(fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8'), /fetch-depth: 0/);
});

test('handWrittenLists flags public historical copy patterns including favorites and read/write copies', () => {
  for (const name of ['chat-delivery', 'chat-transcript-history', 'chat-reset', 'chat-cpu', 'favorites', 'chat-correctness', 'chat_injected', 'chat-tables', 'chat-cache-bound']) {
    const snippets = handWrittenLists(historical(`tools/${name}.test.js`));
    assert.equal(snippets.length, name === 'chat-transcript-history' ? 2 : 1, name);
  }
  for (const source of [
    ['fs.copyFileSync', "('src/example.zig', target);"].join(''),
    ['fs.copyFileSync', "(path.join(__dirname, '../src', 'example.zig'), target);"].join(''),
    ['for (const file of ', "['example.zig']) fs.writeFileSync(path.join(dest, file), fs.readFileSync(`src/${file}`));"].join(''),
  ]) assert.equal(handWrittenLists(source).length, 1, source);
  assert.deepEqual(handWrittenLists("copyZig(['example.zig'], dir);"), []);
});

test('tools test harnesses and recursive mjs tools have no hand-written Zig copy lists', () => {
  const files = fs.readdirSync(__dirname).filter(name => name.endsWith('.test.js'));
  for (const entry of fs.readdirSync(__dirname, { recursive: true, withFileTypes: true })) {
    if (entry.isFile() && entry.name.endsWith('.mjs')) files.push(path.relative(__dirname, path.join(entry.parentPath, entry.name)));
  }
  const offenders = files.flatMap(file => handWrittenLists(fs.readFileSync(path.join(__dirname, file), 'utf8')).map(snippet => ({ file, snippet })));
  assert.deepEqual(offenders, []);
});

test('ISSUE-421 embedded fixtures follow their importing file without copying commented or quoted paths', t => {
  const dir = temporary(t);
  const src = path.join(dir, 'src');
  fs.mkdirSync(path.join(src, 'testdata'), { recursive: true });
  fs.writeFileSync(path.join(src, 'root.zig'), '@embedFile("testdata/table.md");\n// @embedFile("absent.md")\nconst s = "@embedFile(\\"missing.md\\")";');
  fs.writeFileSync(path.join(src, 'testdata/table.md'), '| A | B |');
  const dest = path.join(dir, 'dest');
  copyZig(['root.zig'], dest, src);
  assert.equal(fs.readFileSync(path.join(dest, 'testdata/table.md'), 'utf8'), '| A | B |');
  fs.writeFileSync(path.join(src, 'root.zig'), '@embedFile("../outside.md");');
  assert.throws(() => copyZig(['root.zig'], dest, src), /Embed outside source root/);
});
