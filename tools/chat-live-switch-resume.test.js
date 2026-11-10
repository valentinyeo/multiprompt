const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, 'src', name), 'utf8');

function body(source, name) {
  const start = source.search(new RegExp(`fn ${name}\\(`));
  assert.notEqual(start, -1, `missing fn ${name}`);
  const open = source.indexOf('{', start);
  let depth = 1;
  for (let i = open + 1; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(open + 1, i);
  }
  assert.fail(name);
}

test('leaving a live chat keeps its event cursor so a switch back does not replay its whole history', () => {
  const stop = body(read('chat_session.zig'), 'chatLiveStreamStopLocked');
  assert.doesNotMatch(stop, /chat_live\.zig"\)\.release\(/, 'switching away must not throw away the live chat state and cursor');
  assert.match(stop, /chat_live\.zig"\)\.park\(stream\.shell_id\)/, 'switching away parks the live chat state');
});

test('a switch back restores the parked live chat before it would start a fresh one at seq zero', () => {
  const live = read('chat_live.zig');
  const claim = body(live, 'claim');
  const restored = claim.indexOf('unpark(shell_id, host, sid)');
  assert.ok(restored >= 0, 'claim restores a parked live chat');
  assert.ok(restored < claim.indexOf('live.clear('), 'restore runs before a same-shell slot is cleared');
  assert.ok(restored < claim.indexOf('if (!live.used) return adopt('), 'restore runs before a fresh slot starts at seq zero');
  const unpark = body(live, 'unpark');
  assert.match(unpark, /held\.host != host/);
  assert.match(unpark, /std\.mem\.eql\(u8, held\.sidSlice\(\), sid\)/);
  assert.match(unpark, /live\.touch\(\)/, 'the restored chat redraws once');
  const park = body(live, 'park');
  assert.match(park, /held\.parked_at < target\.parked_at/, 'the oldest parked chat makes room');
  assert.match(park, /target\.deinit\(/, 'an evicted parked chat frees its items');
  assert.match(body(live, 'release'), /for \(&parked\)/, 'closing a chat also drops its parked state');
});

test('parked live chats never count as attached, running or drawn for the sidebar', () => {
  const live = read('chat_live.zig');
  for (const name of ['attached', 'running', 'revision', 'slotFor']) {
    assert.doesNotMatch(body(live, name), /parked/, `${name} reads only active live chats`);
  }
});
