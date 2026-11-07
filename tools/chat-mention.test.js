const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

function read(name) {
  return fs.readFileSync(`src/${name}`, 'utf8');
}

test('IGSH-1811 @ names another live chat and the sent text keeps its session', () => {
  assert.match(read('chat_complete.zig'), /if \(e\.kind == 'M'\) "@"/);
  assert.match(read('chat_composer.zig'), /chat_mention\.zig/);
  assert.match(read('chat_render.zig'), /spanAt\(text, pos, mentions\)/);
  assert.match(read('chat_send.zig'), /chat_mention\.zig"\)\.apply/);
});
