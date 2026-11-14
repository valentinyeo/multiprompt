const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = file => (fs.existsSync(path.join(root, 'src', file)) ? fs.readFileSync(path.join(root, 'src', file), 'utf8').replace(/\r\n/g, '\n') : '');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.notStrictEqual(start, -1, `${name} is missing`);
  const rest = source.slice(start + 4);
  const next = rest.indexOf('\nfn ');
  const nextPub = rest.indexOf('\npub fn ');
  const cuts = [next, nextPub].filter(at => at >= 0);
  const end = cuts.length ? Math.min(...cuts) : rest.length;
  return rest.slice(0, end);
}

test('SOFT-2278 dictation shows words while speaking from a separate live unit', () => {
  const live = read('dictation_live.zig');
  assert.match(live, /pub fn compose\(/, 'live words must be spliced as one unit');
  assert.match(live, /pub fn adjustRange\(/, 'live words must follow the typed text around them');
  assert.match(live, /pub fn mapCaret\(/, 'the caret must move with the live words');
  assert.match(live, /pub const Feed = struct/, 'recorded audio must be readable while recording');
  assert.doesNotMatch(live, /@import\("std"\)\.Thread|PostMessageW|SetWindowTextW/, 'the live unit stays pure so its tests need no window');
  const build = fs.readFileSync(path.join(root, 'build.zig'), 'utf8');
  assert.match(build, /"src\/dictation_live\.zig"/, 'the live unit tests must run in CI');
});

test('SOFT-2278 live audio is fed only inside a recording and stops when it ends', () => {
  const voice = read('voice.zig');
  const capture = body(voice, 'captureDictationPcm');
  assert.match(capture, /dictation_live_feed\.append\(/, 'the capture loop must feed the live transcriber');
  const worker = body(voice, 'dictationWorkerThread');
  assert.match(worker, /const live_epoch = dictationLiveBegin\(\);/, 'live words start with the recording');
  assert.match(worker, /dictationLiveEnd\(live_epoch\);/, 'live words stop with the recording');
  assert.ok(worker.indexOf('dictationLiveEnd(live_epoch)') < worker.indexOf('deepgramTranscribePcm'), 'the live transcriber must stop before the final transcript is asked for');
  const wanted = body(voice, 'dictationLiveWanted');
  assert.match(wanted, /dictationFixtureEnabled\(\)/, 'fixture mode must stay on the old path');
  assert.match(wanted, /g_voice_listening_active/, 'voice listening must stay on the old path');
  assert.match(wanted, /g_dictation_draft_owner_len > 0/, 'only a dictation that owns the message box may show live words');
});

test('SOFT-2278 the final transcript replaces the live words and the old path is the fallback', () => {
  const voice = read('voice.zig');
  const ready = body(voice, 'handleDictationReady');
  assert.match(ready, /chatDictationLiveFinish\(owner, transcript\)/, 'the final words must replace the live words');
  assert.match(ready, /chatDraftAppend\(owner, transcript\)/, 'the old append stays as the fallback');
  assert.match(voice, /fn dictationLiveFallback\(/, 'a failed final call must keep the live words');
  assert.match(voice, /if \(failures >= dictation_live\.max_failures\) break;/, 'two live failures must stop the live path');
});

test('SOFT-2278 cancel, close and switch take the live words out of the box', () => {
  const voice = read('voice.zig');
  const cancel = body(voice, 'cancelDictation');
  const discardAt = cancel.indexOf('chatDictationLiveDiscard()');
  const clearAt = cancel.indexOf('g_dictation_draft_owner_len = 0');
  assert.ok(discardAt >= 0, 'cancel must discard the live words');
  assert.ok(clearAt < 0 || discardAt < clearAt, 'cancel must discard the live words before it forgets which chat owns them');
  const composer = read('chat_composer.zig');
  const close = body(composer, 'chatDraftCloseForShell');
  assert.match(close, /chatDictationLiveDiscard\(\);/, 'closing a chat must take its live words away');
  const bind = body(composer, 'chatDraftBindToActive');
  assert.match(bind, /chatLiveStripFromStore\(\);/, 'switching chats must not leave live words in another draft');
});

test('SOFT-2278 the window routes live words to the message box', () => {
  const main = read('main.zig');
  const win32 = read('win32.zig');
  assert.match(win32, /pub const WM_APP_DICTATION_LIVE: u32 = WM_APP \+ \d+;/, 'live words need their own window message');
  assert.match(main, /WM_APP_DICTATION_LIVE => \{[\s\S]*?handleDictationLive\(\)/, 'the window must hand live words to the composer');
  const voice = read('voice.zig');
  const apply = body(voice, 'handleDictationLive');
  assert.match(apply, /chatDictationLiveApply\(/, 'live words must be written into the message box');
  assert.match(apply, /g_dictation_cancelled/, 'a cancelled dictation must never draw live words');
});
