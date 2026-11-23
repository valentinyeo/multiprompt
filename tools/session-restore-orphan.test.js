const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function body(source, name) {
  const start = source.indexOf(`pub fn ${name}(`) >= 0 ? source.indexOf(`pub fn ${name}(`) : source.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, `missing ${name}`);
  const open = source.indexOf('{', start);
  let depth = 1;
  for (let i = open + 1; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(open + 1, i);
  }
  assert.fail(`unclosed ${name}`);
}

test('SOFT-2985 saved session orphans die only when they still look like a shell', () => {
  const helper = body(read('src/console.zig'), 'killSavedOrphanIfStale');
  assert.match(helper, /GetCurrentProcessId\(\)/);
  assert.match(helper, /findWindowByClassAndPid\(pid, "mintty"\)/);
  assert.match(helper, /findConsoleWindowByPid\(pid\)/);
  const check = helper.indexOf('still_a_shell');
  assert.ok(check >= 0, 'decides from the shell window before killing');
  assert.ok(helper.indexOf('killProcessTree(pid)') > check, 'kills only after the shell window check');

  const session = read('src/session.zig');
  for (const name of ['startupRestoreWorker', 'restoreSession']) {
    const fn = body(session, name);
    assert.match(fn, /killSavedOrphanIfStale\(/, `${name} uses the guarded cleanup`);
    assert.doesNotMatch(fn, /killProcessTree\(/, `${name} never kills a saved pid on its own`);
  }
});
