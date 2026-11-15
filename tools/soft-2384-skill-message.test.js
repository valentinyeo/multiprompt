const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const echo = fs.readFileSync('src/chat_echo.zig', 'utf8');
const sync = fs.readFileSync('src/chat_shell_sync.zig', 'utf8');

function skillToken(word) {
  return word.length >= 2 && word[0] === '/' && /^[A-Za-z0-9:_-]+$/.test(word.slice(1));
}

function words(text) {
  return text.split(/\s+/).filter(Boolean);
}

function sameSkillText(left, right) {
  const l = words(left);
  const r = words(right);
  let li = 0;
  let ri = 0;
  let leftSkills = 0;
  let rightSkills = 0;
  while (li < l.length) {
    if (skillToken(l[li])) {
      leftSkills += 1;
      li += 1;
      continue;
    }
    while (ri < r.length && skillToken(r[ri])) {
      rightSkills += 1;
      ri += 1;
    }
    if (ri >= r.length || l[li] !== r[ri]) return false;
    li += 1;
    ri += 1;
  }
  while (ri < r.length) {
    if (!skillToken(r[ri])) return false;
    rightSkills += 1;
    ri += 1;
  }
  if (leftSkills === 0 || leftSkills !== rightSkills) return false;
  const count = (list, skill) => list.filter(word => word === skill).length;
  for (const skill of l) {
    if (!skillToken(skill)) continue;
    if (count(l, skill) !== count(r, skill)) return false;
  }
  return true;
}

function pendingMatches(pending, sent) {
  const norm = text => text.replace(/\s+/g, ' ').trim();
  if (norm(pending) === norm(sent)) return true;
  if (/p\.confirmed and sameSkillText/.test(echo)) return false;
  return sameSkillText(norm(sent), norm(pending));
}

test('SOFT-2384 a skill command shows once after send, and a plain message shows once', () => {
  const pending = 'lets make it simpler right?\n\n/pstack:poteto-mode confirm that';
  const sent = '/pstack:poteto-mode lets make it simpler right?\n\nconfirm that';
  assert.equal(pendingMatches(pending, sent), true);
  assert.equal(pendingMatches('hello there', 'hello there'), true);
  assert.equal(pendingMatches(pending, '/other:skill lets make it simpler right?\n\nconfirm that'), false);
  assert.equal(pendingMatches('hello there', 'hello there friend'), false);
  assert.equal(/p\.confirmed and sameSkillText/.test(echo), false);
  assert.match(echo, /sameSkillText\(body, norm\)/);
  assert.match(sync, /sameSkillText\(clipped\(entry\.text\), item\.text\[0\.\.item\.len\]\)/);
  assert.match(echo, /test "SOFT-2384 /);
});
