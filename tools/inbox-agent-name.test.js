const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const inbox = fs.readFileSync(path.join(__dirname, '../src/inbox.zig'), 'utf8');

function between(start, end) {
  const first = inbox.indexOf(start);
  const last = inbox.indexOf(end, first + start.length);
  assert.ok(first >= 0 && last > first);
  return inbox.slice(first, last);
}

test('Inbox agent names use available space without workspace labels', () => {
  const bounds = between('fn inboxNameBounds(', 'fn inboxLayout(');
  const row = between('        const name = inboxNameBounds(layout, row);', '        if (name.show_age) {');
  assert.doesNotMatch(bounds, /workspace|row\.ws/);
  assert.match(bounds, /\.right = right/);
  assert.match(row, /json_reader\.wide\(row\.name\[0\.\.row\.name_len\]/);
  assert.doesNotMatch(row, /workspace|g_inbox_ws|ws_buf|ws_rc/);
});
