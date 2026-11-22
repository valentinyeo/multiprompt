const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const source = fs.readFileSync(path.join(__dirname, '..', 'src/computer_view.cpp'), 'utf8');

test('Windows OpenSSH global known hosts paths do not block the Computer connection', () => {
  const policy = source.slice(source.indexOf('bool pinnedConfig('), source.indexOf('void sshWorker('));
  assert.match(policy, /key == "globalknownhostsfile" && value\.rfind\("__PROGRAMDATA__",0\) == 0\) continue;/);
  assert.match(source, /globalknownhostsfile __PROGRAMDATA__\\\\ssh\/ssh_known_hosts[^\n]*return 11;/);
});
