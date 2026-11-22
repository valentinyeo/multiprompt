const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const read = (file) => fs.readFileSync(file, 'utf8');

test('IGSH-1266 an empty hosted answer may carry inode zero, nothing else may', () => {
  const history = read('src/chat_history.zig');
  assert.match(history, /const empty_answer = inode == 0 and base == 0 and end == 0 and !std\.mem\.eql\(u8, mode_text, "older"\);/,
    'the reader answers a brand-new hosted chat with an empty ok history whose inode is zero');
  assert.match(history, /\(inode == 0 and !empty_answer\)/,
    'every other inode zero answer must stay InvalidHistory');
  assert.match(history, /if \(empty_answer and next\.rows\.items\.len != 0\) return error\.InvalidHistory;/,
    'an empty answer may not smuggle rows');
  assert.match(history, /test "IGSH-1266 an empty hosted answer opens the chat and the first tail answer fills it"/,
    'the empty apply and the following tail apply are covered');
  assert.match(history, /test "IGSH-1266 an inode zero answer with rows or a cursor mode stays invalid"/);
});
