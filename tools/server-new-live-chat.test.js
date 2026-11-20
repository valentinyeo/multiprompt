const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');

test('SOFT-1925 server-chat journey creates a new live chat on the shared connection', () => {
  const drive = read('tools/verify-server-chat/drive.ps1');
  assert.match(drive, /shared_server_connection = \$true/);
  assert.match(drive, /"cwd":"\/home\/mpverify"/);
  assert.match(drive, /Press @\(0x11, 0x54\) 'Ctrl\+T: new Claude live chat on the shared server connection'/);
  assert.match(drive, /name = 'new-chat'/);
  assert.match(drive, /stayed Not sent/);
  const evidence = read('tools/verify-server-chat/check-evidence.cjs');
  assert.match(evidence, /\['new-chat', true\]/);
  assert.match(evidence, /new-chat-copied\.txt/);
  assert.match(evidence, /assert\.doesNotMatch\(text\('new-chat-copied\.txt'\)/);
});
