const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function body(source, name, exported = true) {
  const anchor = exported ? `pub fn ${name}(` : `fn ${name}(`;
  const start = source.indexOf(anchor);
  assert.notEqual(start, -1, `missing ${name}`);
  const open = source.indexOf('{', start);
  let depth = 1;
  for (let i = open + 1; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(open + 1, i);
  }
  assert.fail(`unclosed ${name}`);
}

test('SOFT-2985 startup orphan cleanup only kills restorable shell consoles', () => {
  const consoleSource = read('src/console.zig');
  const helper = body(consoleSource, 'killSavedOrphanIfStale');
  assert.match(helper, /GetCurrentProcessId\(\)/);
  assert.match(helper, /findConsoleWindowByPid\(pid\)/);
  assert.match(helper, /findWindowByClassAndPid\(pid, "mintty"\)/);
  assert.match(helper, /killProcessTree\(pid\)/);
  assert.doesNotMatch(helper, /Sleep\(|WaitForSingleObject/);

  const worker = body(read('src/session.zig'), 'startupRestoreWorker', false);
  assert.match(worker, /killSavedOrphanIfStale\(tab\.pid, tab\.kind\)/);
  assert.doesNotMatch(worker, /killProcessTree\(tab\.pid\)/);

  const restore = body(read('src/session.zig'), 'restoreSession');
  assert.match(restore, /killSavedOrphanIfStale\(tabs\[t\]\.pid, tabs\[t\]\.kind\)/);
  assert.doesNotMatch(restore, /killProcessTree\(tabs\[t\]\.pid\)/);

  const broken = consoleSource.replace('if (!still_a_shell) return;', '');
  assert.notEqual(broken, consoleSource);
  assert.throws(() => assert.match(body(broken, 'killSavedOrphanIfStale'), /if \(!still_a_shell\) return;/), assert.AssertionError);
});