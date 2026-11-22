const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || process.cwd();
const session = fs.readFileSync(path.join(root, 'src/chat_session.zig'), 'utf8');
const live = fs.readFileSync(path.join(root, 'src/chat_live.zig'), 'utf8');

test('SOFT-3047 history catch-up runs after merged transcript rows land', () => {
  const handler = session.slice(session.indexOf('if (entry.result) |history|'), session.indexOf('} else if (disk)'));
  assert.match(handler, /historyCaughtUpWithSeen\(entry\.key\.shell_id, entry\.history\.blocks\.items\)/);
  const preMerge = handler.indexOf('historyCaughtUpWithSeen');
  const append = handler.indexOf('entry.history.appendParsed');
  const replace = handler.indexOf('entry.history = history');
  assert.ok(preMerge > append || preMerge > replace);
});

test('SOFT-3047 history catch-up can compare live row keys against landed blocks', () => {
  assert.match(live, /pub fn historyCaughtUpWithSeen\(shell_id: u32, seen: \[\]const chat_markdown\.Block\) void/);
  assert.match(live, /chat_markdown\.drawnOnce\(item\.key, seen\)/);
});