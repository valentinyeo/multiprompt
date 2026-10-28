const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { readChangelogEntry } = require('./changelog-entry');
const session = fs.readFileSync('src/chat_session.zig', 'utf8');
const history = fs.readFileSync('src/chat_history.zig', 'utf8');
const state = fs.readFileSync('src/app_state.zig', 'utf8');

const ENTRY_LINE = /^Chat View [^.]+\.$/;

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  const end = source.indexOf('\n}', start);
  assert.ok(end > start, name);
  return source.slice(start, end + 2);
}

function fairContract(source) {
  const acquire = body(source, 'chatFetchAcquire');
  const oldest = body(source, 'chatFetchOldest');
  assert.match(acquire, /g_chat_fetch_busy or app_state\.g_main_hwnd == null\) return false/);
  assert.ok(acquire.indexOf('MultipromptChatFetchPending') < acquire.indexOf('WaitForSingleObject'));
  assert.match(acquire, /WaitForSingleObject\(app_state\.g_chat_fetch_mutex, 0\)/);
  assert.match(acquire, /Local\\\\MultipromptChatTranscriptWorker/);
  assert.match(acquire, /EnumWindows\(&chatFetchOldest[^]*turn\.hwnd != hwnd\) \{\s*_ = ReleaseMutex\(app_state\.g_chat_fetch_mutex\);\s*return false;/);
  assert.ok(acquire.indexOf('turn.hwnd != hwnd') < acquire.indexOf('app_state.g_chat_fetch_busy = true'));
  assert.match(acquire, /MultipromptChatFetchServed"\), @ptrFromInt\(turn.latest \+ 1\)/);
  assert.match(acquire, /MultipromptChatFetchPending"\), null/);
  assert.match(oldest, /requested == 0 or GetTickCount64\(\) -\| seen > 3000/);
  assert.match(oldest, /requested < turn.requested/);
  assert.match(oldest, /requested == turn.requested and[^]*served < turn.served/);
  assert.match(oldest, /turn.latest = @max\(turn.latest, served\)/);
  assert.doesNotMatch(acquire, /foregroundIsOurs|Priority|Sleep\(/);
  const release = body(source, 'chatFetchRelease');
  assert.ok(release.indexOf('ReleaseMutex') < release.indexOf('PostMessageW'));
  assert.match(release, /PostMessageW\(turn.hwnd, WM_TIMER, TIMER_CHAT_REFRESH, 0\)/);
  assert.match(body(source, 'chatFileRequestForDelivery'), /if \(!load_disk and pushed == null and !chatFetchAcquire\(\)\) return/);
}

function stagingContract(source, model) {
  const worker = body(source, 'chatFileFetchThread');
  assert.match(worker, /history = \(if \(older\) input else if/);
  assert.match(worker, /history.defer_render = older/);
  assert.match(worker, /entry.backfill.stage\(a, &history\)/);
  assert.match(worker, /entry.backfill.start == 0 or entry.show_older/);
  assert.match(worker, /const publish_staged = entry.show_older and entry.backfill.pages.items.len > 0/);
  assert.match(worker, /var ok = publish_staged or pushed != null or chatHistoryFetch/);
  assert.match(worker, /if \(!entry.staged and entry.cache_dirty/);
  assert.match(model, /if \(!self.defer_render\) try next.render\(a\)/);
  const stage = model.slice(model.indexOf('    pub fn stage('), model.indexOf('    pub fn finish('));
  assert.match(stage, /page.rows.toOwnedSlice\(a\)/);
  assert.match(stage, /pages.appendAssumeCapacity\(rows\)/);
  assert.doesNotMatch(stage, /clone|render|insertSlice|tail\.rows|history\.rows/);
  const finish = model.slice(model.indexOf('    pub fn finish('), model.indexOf('\npub fn statusOnly('));
  assert.match(finish, /for \(self.pages.items\) \|page\| size \+= page.len/);
  assert.match(finish, /var i = self.pages.items.len;[^]*i -= 1;[^]*self.pages.items\[i\]/);
  assert.match(finish, /recent.rows.appendSlice\(a, tail.rows.items\)/);
  assert.match(finish, /recent.retainRows\(a, result\)/);
  assert.match(finish, /result.rows = recent.rows/);
  assert.equal((finish.match(/result.render\(a\)/g) || []).length, 1);
  assert.doesNotMatch(finish, /TAIL_BYTES|MAX_CACHE_BYTES|@min|break;/);
  const ready = body(source, 'chatFileOnReady');
  const staged = ready.slice(ready.indexOf('if (entry.staged) {'), ready.indexOf('const added ='));
  assert.match(staged, /entry.before = 0/);
  assert.match(staged, /chatFileRequest\(entry.key\);\s*}\s*continue;/);
  assert.ok(staged.indexOf('UpdateWindow') < staged.indexOf('chatFileRequest'));
  assert.match(staged, /UpdateWindow\(app_state.g_chat_transcript_hwnd\)/);
  assert.doesNotMatch(staged, /layoutChatControls|refreshChatTranscript|g_chat_switch_loading/);
  assert.doesNotMatch(ready, /\.render\(|\.apply\(|\.decode\(/);
  assert.match(ready, /const before = if \(entry.stalled\) 0 else if \(entry.backfill.pages.items.len > 0\) entry.backfill.start else if \(disk or history.start < entry.history.start/);
  assert.match(ready, /entry.before = entry.history.start;\s*entry.missing_message = entry.result_missing/);
  assert.doesNotMatch(body(source, 'chatFileRequestForDelivery'), /entry.before = entry.backfill.start/);
  assert.match(body(source, 'chatHistoryForget'), /entry.backfill.deinit/);
  assert.match(ready, /if \(entry.retired\)[^]*entry.backfill.deinit/);
  assert.match(model, /IGSH-815 staged older pages keep the visible tail stable and materialize every message across cache restore/);
}

test('static gate: zero-delay backfill cannot bypass another live pending window', () => {
  fairContract(session);
  assert.throws(() => fairContract(session.replace('turn.hwnd != hwnd', 'false')));
  assert.throws(() => fairContract(session.replace('served < turn.served', 'false')));
});

test('static gate: page turns transfer owned rows without full clone/prepend/render or UI relayout', () => {
  stagingContract(session, history);
  assert.throws(() => stagingContract(session.replace('if (older) input else if', 'if (older) entry.history.clone(a) else if'), history));
  assert.throws(() => stagingContract(session, history.replace('if (!self.defer_render) try next.render(a)', 'try next.render(a)')));
  assert.match(state, /backfill: chat_history.Backfill/);
  assert.doesNotMatch(body(session, 'chatFileRequestForDelivery'), /show_older = app_state.g_chat_scrolled_up/);
  assert.match(body(session, 'chatFileOnReady'), /entry.pending = false;\s*entry.show_older = false/);
  assert.match(body(fs.readFileSync('src/chat_render.zig', 'utf8'), 'chatScrollBy'), /new_y <= uiScaled\(80\)[^]*entry.show_older = true/);
  assert.match(fs.readFileSync('src/chat_find_ui.zig', 'utf8'), /entry.show_older = entry.before > 0/);
});

test('turn-order model: forty continuously pending windows progress without a same-tick reacquire', () => {
  fairContract(session);
  const windows = Array.from({ length: 40 }, (_, hwnd) => ({ hwnd, requested: 1, served: 0 }));
  let latest = 0;
  const turns = [];
  for (let turn = 0; turn < 4000; turn++) {
    const chosen = [...windows].sort((a, b) => a.requested - b.requested || a.served - b.served || a.hwnd - b.hwnd)[0];
    turns.push(chosen.hwnd);
    chosen.served = ++latest;
    chosen.requested = 1;
  }
  for (let start = 0; start < turns.length; start += windows.length) {
    assert.deepEqual(turns.slice(start, start + windows.length), windows.map(window => window.hwnd));
  }
});

test('staging-order model: all fifty messages survive page staging and one publication without a cap', () => {
  stagingContract(session, history);
  const tail = ['message 49'];
  const pages = [];
  let copied = 0;
  for (let index = 48; index >= 0; index--) {
    const page = [`message ${index}`];
    copied += page.length;
    pages.push(page);
    assert.deepEqual(tail, ['message 49']);
  }
  const complete = [...pages.reverse().flat(), ...tail];
  assert.equal(copied, 49);
  assert.deepEqual(complete, Array.from({ length: 50 }, (_, index) => `message ${index}`));
  assert.deepEqual(JSON.parse(JSON.stringify(complete)), complete);
});

test('full-history continuation stays automatic across disk restore without a cap or new loading gate', () => {
  const ready = body(session, 'chatFileOnReady');
  assert.match(ready, /const before = if \(entry.stalled\) 0 else if \(entry.backfill.pages.items.len > 0\) entry.backfill.start else if \(disk or history.start < entry.history.start/);
  assert.match(ready, /entry.before = before/);
  assert.match(ready, /if \(!disk and !history.more and history.start == 0\) entry.loaded_ms/);
  assert.match(ready, /if \(disk or entry.prepended or entry.before > 0\) @as\(u64, 0\)/);
  assert.match(body(session, 'chatFileFetchThread'), /chat_history.History.decode/);
  assert.match(history, /try std.testing.expectEqual\(@as\(usize, 50\), restored.blocks.items.len\)/);
  const changelog = readChangelogEntry('IGSH-815').trim();
  assert.ok(changelog.length > 0);
  for (const line of changelog.split('\n')) assert.match(line, ENTRY_LINE, line);
});

test('changelog rule: several lines per ticket are fine, each line is one sentence, an empty or two-sentence line is rejected', () => {
  assert.match('Chat View loads every message in long sessions.', ENTRY_LINE);
  assert.doesNotMatch('', ENTRY_LINE);
  assert.doesNotMatch('Chat View loads every message. Chat View keeps your place.', ENTRY_LINE);
  assert.doesNotMatch('Chat View loads every message', ENTRY_LINE);
});
