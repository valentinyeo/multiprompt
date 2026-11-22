const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const history = fs.readFileSync(path.join(__dirname, '..', 'src/chat_history.zig'), 'utf8');

function body(name) {
  const start = history.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `${name} is missing`);
  return history.slice(start, history.indexOf('\n}', start) + 2);
}

test('SOFT-2420 a reset keeps an assistant reply on the assistant side', () => {
  const retain = body('retainRows');
  const side = body('keepReplySide');
  assert.match(retain, /keepReplySide\(/);
  assert.match(side, /"assistant"/);
  assert.match(side, /"user"/);
  assert.match(history, /a transcript reset does not draw an assistant reply as the user/);
});
