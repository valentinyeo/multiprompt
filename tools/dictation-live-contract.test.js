const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = file => (fs.existsSync(path.join(root, file)) ? fs.readFileSync(path.join(root, file), 'utf8').replace(/\r\n/g, '\n') : '');

function fnBody(source, header) {
  const start = source.indexOf(header);
  assert.ok(start >= 0, `${header} is missing`);
  const end = source.indexOf('\n}\n', start);
  assert.ok(end > start, `${header} has no end`);
  return source.slice(start, end + 3);
}

const voice = read('src/voice.zig');
const composer = read('src/chat_composer.zig');
const live = read('src/dictation_live.zig');

test('IGSH-2278 the live planner module exists, is unit tested in CI and is registered in the build', () => {
  assert.ok(live.length > 0, 'src/dictation_live.zig must exist');
  const tests = live.match(/^test "IGSH-2278 [^"]+" \{/gm) || [];
  assert.ok(tests.length >= 8, `expected at least 8 planner tests, found ${tests.length}`);
  assert.match(read('build.zig'), /"src\/dictation_live\.zig"/);
  assert.doesNotMatch(live, /@import\("(?!std)/, 'the planner stays std-only so it can be tested alone');
});

test('IGSH-2278 nothing runs unless a chat dictation is recording', () => {
  const spawns = voice.match(/std\.Thread\.spawn\(\.\{\}, dictationLiveThread/g) || [];
  assert.equal(spawns.length, 1, 'one spawn site only');
  const begin = fnBody(voice, 'fn dictationLiveBegin()');
  assert.match(begin, /if \(!dictationLiveWanted\(\)\) return 0;/);
  assert.ok(begin.indexOf('dictationLiveWanted') < begin.indexOf('std.Thread.spawn'));
  const alive = fnBody(voice, 'fn dictationLiveAlive(');
  assert.match(alive, /g_dictation_recording\.load\(\.acquire\)/);
  assert.match(alive, /g_dictation_cancelled\.load\(\.acquire\)/);
  const thread = fnBody(voice, 'fn dictationLiveThread(');
  assert.match(thread, /while \(dictationLiveAlive\(epoch\)\)/);
  assert.match(thread, /Sleep\(@intCast\(dictation_live\.tick_ms\)\)/);
  assert.doesNotMatch(voice, /SetTimer\([^)]*dictation_live|TIMER_DICTATION_LIVE/);
  assert.match(voice, /dictation_live_feed\.append\(std\.heap\.page_allocator, src\);/);
});

test('IGSH-2278 a failed final request keeps the live words instead of losing the speech', () => {
  const worker = fnBody(voice, 'fn dictationWorkerThread()');
  assert.match(worker, /and !dictationLiveFallback\(result\.status\)\) \{/);
  assert.match(fnBody(voice, 'fn dictationLiveFallback('), /if \(status == 200\) return false;/);
});

test('IGSH-2278 live words are written at the cursor without disturbing typed text or the draft store', () => {
  const write = fnBody(composer, 'fn chatLiveWrite(');
  assert.match(write, /chat_draft_loading = true;\s*_ = SetWindowTextW\(hwnd, @ptrCast\(&out\)\);\s*chat_draft_loading = false;/);
  assert.match(write, /dictation_live\.compose\(/);
  assert.match(write, /dictation_live\.mapCaret\(/);
  assert.match(fnBody(composer, 'fn chatLiveCurrentRange('), /dictation_live\.adjustRange\(/);
  const apply = fnBody(composer, 'pub fn chatDictationLiveApply(');
  assert.match(apply, /!chatLiveOwnerMatches\(owner\)/, 'words never land in another chat');
  assert.doesNotMatch(apply, /chatDraftNoteEdit|chat_drafts\./, 'preview words are not persisted');
  const finish = fnBody(composer, 'pub fn chatDictationLiveFinish(');
  assert.match(finish, /chatLiveWrite\(cur, range, words, true\)/);
  assert.ok(finish.indexOf('chatLiveWrite') < finish.indexOf('chatDraftNoteEdit();'), 'only the final text is persisted');
});
