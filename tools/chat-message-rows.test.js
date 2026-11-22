const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, 'src', name), 'utf8');

const hash64 = text => {
  let hash = 0xcbf29ce484222325n;
  for (const byte of Buffer.from(text, 'utf8')) {
    hash ^= BigInt(byte);
    hash = BigInt.asUintN(64, hash * 0x100000001b3n);
  }
  return hash;
};

function rowKeySource(source) {
  const header = /pub fn rowKey\(id: \[\]const u8\) u64 \{\n/.exec(source);
  assert.ok(header, 'rowKey is missing');
  const start = header.index + header[0].length;
  const end = source.indexOf('\n}\n', start);
  assert.ok(end > start, 'rowKey has no body');
  return source.slice(start, end)
    .replace('const base = if (std.mem.indexOf(u8, id, ":text:")) |at| id[0..at] else id;', 'const base = id.includes(":text:") ? id.slice(0, id.indexOf(":text:")) : id;')
    .replace('return std.hash.Wyhash.hash(0, base);', 'return hash64(base);');
}

function drawnOnceSource(source) {
  const header = /pub fn drawnOnce\(key: u64, seen: \[\]const Block\) bool \{\n/.exec(source);
  assert.ok(header, 'drawnOnce is missing');
  const start = header.index + header[0].length;
  const end = source.indexOf('\n}\n', start);
  assert.ok(end > start, 'drawnOnce has no body');
  return source.slice(start, end)
    .replace('for (seen) |block| {\n        if (block.row_key == key) return false;\n    }', 'for (const block of seen) {\n        if (block.row_key == key) return false;\n    }');
}

function rows(source) {
  const rowKey = new Function('hash64', `return function(id) {${rowKeySource(source)}}`)(hash64);
  const drawnOnce = new Function(`return function(key, seen) {${drawnOnceSource(source)}}`)();
  return { rowKey, drawnOnce };
}

test('IGSH-1415 a reply the transcript already carries is drawn once', () => {
  const { rowKey, drawnOnce } = rows(read('chat_markdown.zig'));
  const live = { row_key: rowKey('msg_ab:text:0') };
  const transcript = [{ role: 'prose', row_key: rowKey('msg_ab') }];
  assert.equal(drawnOnce(live.row_key, transcript), false, 'the live reply and the transcript reply are one row');
});

test('IGSH-1415 a sent message and its transcript row key the same message', () => {
  const { rowKey, drawnOnce } = rows(read('chat_markdown.zig'));
  const echo = { row_key: rowKey('um-1') };
  const transcript = [{ role: 'user', row_key: rowKey('um-1') }];
  assert.equal(drawnOnce(echo.row_key, transcript), false, 'the local copy and the transcript copy are one row');
});

test('IGSH-1415 a step the transcript has not carried yet still draws', () => {
  const { rowKey, drawnOnce } = rows(read('chat_markdown.zig'));
  const transcript = [{ role: 'prose', row_key: rowKey('msg_ab') }];
  assert.equal(drawnOnce(rowKey('msg_cd:text:0'), transcript), true, 'a different message keeps its own row');
  assert.equal(drawnOnce(0, transcript), true, 'a row with no id is never hidden');
});

test('IGSH-1415 a text row split around a tool step keeps the key of its message', () => {
  const { rowKey } = rows(read('chat_markdown.zig'));
  assert.equal(rowKey('msg_ab:text:1200:2'), rowKey('msg_ab:text:0'));
  assert.notEqual(rowKey('toolu_01ABC'), rowKey('msg_ab'));
});

test('IGSH-1415 the transcript labels every row with the key of the message it came from', () => {
  const history = read('chat_history.zig');
  assert.match(history, /const row_key = if \(id\.len == 0\) 0 else md\.rowKey\(id\);/);
  assert.match(history, /block\.row_key = row_key;/);
});

test('IGSH-1415 the live tail drops a row the transcript already carries', () => {
  const live = read('chat_live.zig');
  assert.match(live, /if \(!chat_markdown\.drawnOnce\(item\.key, seen\)\) continue;/);
  assert.match(live, /added\.key = if \(id\.len == 0\) 0 else chat_markdown\.rowKey\(id\);/);
  assert.match(live, /\.row_key = item\.key,/);
  assert.match(read('chat_session.zig'), /tailFor\(shell_id, app_state\.g_chat_capture\[len\.\.\], len, &live_blocks, seen\);/);
  assert.match(read('chat_session.zig'), /const seen: \[\]const @import\("chat_markdown\.zig"\)\.Block = if \(from_file\) entry\.\?\.history\.blocks\.items else &\.\{\};/);
});

test('IGSH-1415 the local copy of a sent message drops the same way', () => {
  const send = read('chat_send.zig');
  assert.match(send, /pub fn chatEchoRowLanded\(e: ChatOutboxEntry\) bool \{/);
  assert.match(send, /chat_live\.zig"\)\.sentRowKeys\(app_state\.shells\[shell\]\.shell_id, wire, &keys\)/);
  assert.match(send, /drawnOnce\(key, app_state\.g_chat_blocks\[0\.\.app_state\.g_chat_block_count\]\)/);
  assert.match(read('chat_render.zig'), /if \(chatEchoRowLanded\(e\)\) continue;/);
});
