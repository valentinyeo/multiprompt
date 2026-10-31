const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

test('IGSH-1266 the dev instance never shares the stable single-instance lock or owner record', () => {
  const source = read('src/account_desktop.zig');
  const body = source.slice(source.indexOf('pub fn accountClaim'), source.indexOf('pub fn accountBootstrap'));
  assert.match(body, /const IS_DEV = |IS_DEV/, 'the check must know which build it is');
  assert.match(body, /ZigShell-account\{s\}-/, 'the mutex name must carry a per-build suffix');
  assert.match(body, /if \(IS_DEV\) "-dev" else ""/, 'the suffix is dev for the dev build');
  assert.match(body, /account-instance-dev\.pid/, 'the dev build owns its own owner record');
  assert.match(body, /other_is_dev == IS_DEV/, 'an instance of the other build is never treated as this one');
  assert.ok(!/if \(IS_DEV\) "-dev" else ""[\s\S]{0,80}account-instance\.pid"/.test(body), 'the stable record name is untouched for stable');
});
