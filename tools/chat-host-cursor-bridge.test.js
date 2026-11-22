const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

test('cursor host adapter registers agent and stream-json argv', () => {
  assert.match(source, /HOST_PROVIDERS = \(.*'cursor'/);
  assert.match(source, /'cursor': 'agent'/);
  assert.match(source, /"cursor": dict\(argv=host_cursor_argv/);
  assert.match(source, /def host_cursor_argv\(/);
  assert.match(source, /stream-json/);
});
