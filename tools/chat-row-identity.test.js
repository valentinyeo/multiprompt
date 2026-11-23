const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, 'src', name), 'utf8');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `${name} is missing`);
  const end = source.indexOf('\n}\n', start);
  assert.ok(end > start, `${name} has no body`);
  return source.slice(start, end + 2);
}

function identityFields(history) {
  const keyed = body(history, 'eql').match(/inline for \(\.\{([^}]+)\}\) \|field\|/);
  assert.ok(keyed, 'the row identity has no field list');
  return [...keyed[1].matchAll(/"(\w+)"/g)].map(match => match[1]);
}

function identity(row, history, fields) {
  const rows = body(history, 'rowIdentity');
  const sourced = /\{[a-z]+}:\{[a-z]+}/.test(rows) || rows.includes('source:');
  const native = row.read_id || row.id || '';
  const id = native || (sourced ? `source:${row.inode}:${row.offset}:${row.end}` : '');
  const text = /\.text = if \(id\.len == 0\) m\.text else ""/.test(rows) && !native ? row.text : '';
  return fields.map(field => (field === 'id' ? id : field === 'text' ? text : row[field] || '')).join('\u0000');
}

function distinctRows(rows, history) {
  const fields = identityFields(history);
  return new Set(rows.map(row => identity(row, history, fields))).size;
}

test('SOFT-3097 a hosted pending row retires when its transcript row has no client id', () => {
  const echo = read('chat_echo.zig');
  const send = read('chat_send.zig');
  assert.doesNotMatch(echo, /\.client_id/, 'a pending row never needs a client id to match its transcript row');
  assert.doesNotMatch(send, /\.client_id/, 'a hosted transcript row never needs a client id to retire its bubble');
  assert.match(body(echo, 'pickBlock'), /^\s*fn pickBlock\([\s\S]*?\{\n    if \(p\.prefix\.len == 0\) return null;/, 'the text prefix is the first thing pickBlock checks');
  assert.match(body(echo, 'pickBlock'), /if \(messageMatches\(b\.text, p, norm\)\) return bi;/);
  const assign = body(send, 'chatEchoAssignForKey');
  assert.doesNotMatch(assign, /if \(wire\.len == 0\) continue;/, 'a pending entry without a wire id still joins the assignment');
  assert.match(assign, /\.prefix = chatEchoNormalizePrefix\(e\.text/);
});

test('SOFT-3097 a retired pending row leaves one row above the reply', () => {
  const render = read('chat_render.zig');
  const landed = render.indexOf('if (chatEchoRowLanded(e)) continue;');
  assert.ok(landed >= 0, 'the layout skips a pending row the transcript already carries');
  assert.ok(render.indexOf('app_state.g_chat_layout_rects[i] = rc;') < landed, 'landed rows are laid out before pending rows');
});

test('SOFT-3097 reading the same id-less row twice yields one row', () => {
  const history = read('chat_history.zig');
  const once = { role: 'user', text: 'same prompt', timestamp: '2026-11-07T00:00:00Z', offset: 0, end: 100, segment: 0 };
  const twice = [
    { ...once, inode: 11 },
    { ...once, inode: 12 },
  ];
  assert.equal(distinctRows(twice, history), 1, 'two reads of one id-less row are one row');
  const different = [
    { ...once, inode: 11 },
    { ...once, inode: 11, text: 'another prompt' },
  ];
  assert.equal(distinctRows(different, history), 2, 'two different id-less rows keep their own rows');
});

test('SOFT-3097 rows that carry a native id keep their own rows', () => {
  const history = read('chat_history.zig');
  const rows = [
    { role: 'user', id: 'native-a', text: 'same prompt', timestamp: '', offset: 0, end: 100, segment: 0 },
    { role: 'user', id: 'native-b', text: 'same prompt', timestamp: '', offset: 100, end: 200, segment: 0 },
  ];
  assert.equal(distinctRows(rows, history), 2, 'identical text under two native ids stays two rows');
});
