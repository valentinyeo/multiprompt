const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8').replace(/\r\n/g, '\n');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.notStrictEqual(start, -1, `${name} is missing`);
  const rest = source.slice(start);
  const next = rest.indexOf('\nfn ', 1);
  const nextPub = rest.indexOf('\npub fn ', 1);
  const cuts = [next, nextPub].filter(at => at >= 0);
  const end = cuts.length ? Math.min(...cuts) : rest.length;
  return rest.slice(0, end);
}

test('SOFT-2421 an edit during dictation keeps the edited text and later speech starts at the caret', () => {
  const live = read('src/dictation_live.zig');
  const composer = read('src/chat_composer.zig');
  assert.match(live, /pub fn laterSpeech\(/);
  assert.match(live, /pub fn planApply\(/);
  assert.match(live, /test "SOFT-2421 deleted dictated words stay gone and later speech is inserted at the caret"/);
  const plan = body(live, 'planApply');
  assert.match(plan, /laterSpeech\(shown, incoming\)/);
  assert.match(plan, /\.at_caret = true/);
  assert.match(plan, /if \(tail\.len == 0\) return \.\{ \.skip = true, \.seal = true \}/);
  const apply = body(composer, 'chatDictationLiveApply');
  assert.match(apply, /dictation_live\.planApply\(/);
  assert.match(apply, /live_draft\.sealed/);
  assert.match(apply, /live_draft\.baseline/);
  assert.match(apply, /live_draft\.shown/);
  assert.match(apply, /decided\.at_caret/);
  assert.doesNotMatch(apply, /chatDraftNoteEdit|chat_drafts\./);
  const finish = body(composer, 'chatDictationLiveFinish');
  assert.match(finish, /dictation_live\.planApply\(/);
  assert.match(finish, /chatLiveWrite\(cur, range, words, true\)/);
  assert.match(finish, /decided\.words/);
});
