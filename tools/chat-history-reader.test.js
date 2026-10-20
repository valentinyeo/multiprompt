const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');

test('embedded read-only remote reader: bounded first load, lazy history, deltas, partial writes and stdin transport', () => {
  const run = spawnSync('python3', ['tools/chat-history-reader-test.py'], { encoding: 'utf8', timeout: 30000 });
  assert.equal(run.status, 0, run.stdout + run.stderr);
  assert.match(run.stderr, /Ran \d+ tests/);
  assert.match(run.stdout, /CPU707 first-load source_bytes=\d+ read_bytes=\d+ ms=/);
});

test('remote reader preserves paging without truncating message history', () => {
  const current = fs.readFileSync('src/chat_history_reader.py', 'utf8');
  assert.match(current, /source.seek\(base\)/);
  assert.doesNotMatch(current, /popleft|encoded\[:TRANSCRIPT_BYTES\]/);
});

test('missing transcript reason crosses the worker handoff and selects the minute backoff in Chat View', () => {
  const main = require('./app-source').readAppSource();
  const history = fs.readFileSync('src/chat_history.zig', 'utf8');
  assert.match(history, /MISSING_RETRY_MS: u64 = 60_000/);
  assert.match(main, /missingReason\(wire.items, id\)/);
  assert.match(main, /Transcript not reachable: \{s\}/);
  assert.match(main, /entry\.missing_message = entry\.result_missing;\s*chatFileFailed\(entry\)/);
  assert.match(main, /if \(entry\.missing_message\[0\] != 0\) chat_history\.MISSING_RETRY_MS else chat_history\.retryDelay/);
  assert.match(main, /if \(e\.missing_message\[0\] != 0\).*?&e\.missing_message/);
  assert.match(main, /entry\.failures = 0;\s*entry\.missing_message = @splat\(0\)/);
});

test('ISSUE-268 find intercepts keys before shell/composer routes and has child-window fallbacks', () => {
  const shortcuts = fs.readFileSync('src/shortcuts.zig', 'utf8');
  const hook = shortcuts.slice(shortcuts.indexOf('pub fn keyboardHookProc('));
  const guard = hook.indexOf('ownsKeys(app_state.g_chat_find_open, foregroundIsOurs())');
  assert.ok(guard >= 0 && guard < hook.indexOf('chatComposerOwnsKey('));
  assert.ok(hook.indexOf('claimBrowserTogglePress(false, kb.time, &app_state.g_chat_toggle_chord_held') < guard);
  assert.match(hook, /const find_modifier = [^;]+;/);
  assert.match(hook, /ownsKeys\(app_state\.g_chat_find_open, foregroundIsOurs\(\)\) and !find_modifier/);
  assert.ok(guard < hook.indexOf('globalPaletteChord('));
  const branch = hook.slice(guard, hook.indexOf('if (app_state.ISSUE_268_CHAT_FIND', guard));
  assert.match(branch, /routeKey\(kb\.vkCode/);
  assert.match(branch, /return 1;/);
  for (const file of ['src/chat_composer.zig', 'src/chat_render.zig', 'src/main.zig']) {
    assert.match(fs.readFileSync(file, 'utf8'), /chat_find_ui\.zig"\)\.windowKey\(msg, wp\)/);
  }
  const ui = fs.readFileSync('src/chat_find_ui.zig', 'utf8');
  assert.match(ui, /job\.id == app_state\.g_chat_find_id and history\.sameSession/);
  assert.match(ui, /session\.chatHistoryPersistent\(/);
  assert.match(ui, /\.search = std\.mem\.sliceTo\(&job\.query, 0\)/);
  assert.match(ui, /entry\.before = if \(model\.needsOlder\(hit\.offset, entry\.history\.start\)\) entry\.history\.start/);
  assert.match(ui, /GetTickCount64\(\) \+ 250/);
});


test('ISSUE-268 sticky find bar fences hidden transcript controls and keeps browser find native', () => {
  const source = fs.readFileSync('src/chat_render.zig', 'utf8');
  const transcriptStart = source.indexOf('fn chatTranscriptWndProc(');
  assert.notEqual(transcriptStart, -1);
  const render = source.slice(transcriptStart);
  for (const message of ['WM_LBUTTONDOWN', 'WM_LBUTTONDBLCLK', 'WM_RBUTTONDOWN']) {
    const branch = render.slice(render.indexOf(`        ${message} => {`));
    assert.match(branch, /^        \w+ => \{\s*if \(app_state\.g_chat_find_open and GET_Y\(lp\) < uiScaled\(app_state\.CHAT_FIND_TOP_H\)\) return 0;/);
  }
  const shortcuts = fs.readFileSync('src/shortcuts.zig', 'utf8');
  const start = shortcuts.indexOf('if (app_state.ISSUE_268_CHAT_FIND');
  assert.match(shortcuts.slice(start, shortcuts.indexOf('{', start)), /!activeBrowserHasForegroundFocus\(\)/);
  const ui = fs.readFileSync('src/chat_find_ui.zig', 'utf8');
  const open = ui.slice(ui.indexOf('pub fn open()'), ui.indexOf('pub fn close('));
  assert.match(open, /!@import\("focus\.zig"\)\.foregroundIsOurs\(\)/);
  assert.ok(open.indexOf('SetForegroundWindow(') < open.indexOf('SetFocus('));
});

test('status todo toggle and whole-conversation find keep distinct palette routes', () => {
  const state = fs.readFileSync('src/app_state.zig', 'utf8');
  function distinct(source) {
    const ids = ['TODO', 'FIND', 'TOOL_STEPS'].map(name => {
      const match = source.match(new RegExp(`SEARCH_CHAT_${name}_OFFSET: usize = (\\d+)`));
      assert.ok(match, name);
      return Number(match[1]);
    });
    assert.equal(new Set(ids).size, ids.length);
  }
  distinct(state);
  assert.throws(() => distinct(state.replace(/SEARCH_CHAT_TODO_OFFSET: usize = \d+/, 'SEARCH_CHAT_TODO_OFFSET: usize = 6397')));
  const main = fs.readFileSync('src/main.zig', 'utf8');
  const palette = fs.readFileSync('src/command_palette.zig', 'utf8');
  const sidebar = fs.readFileSync('src/sidebar.zig', 'utf8');
  for (const [name, action] of [['TODO', 'chatToggleTodos'], ['FIND', 'open']]) {
    assert.match(main, new RegExp(`if \\(target == SEARCH_CHAT_${name}_OFFSET\\) \\{[^]*?\\.${action}\\(\\);[^]*?return 0;\\n                \\}`));
    assert.ok(palette.includes(`= SEARCH_CHAT_${name}_OFFSET;`));
    assert.ok(sidebar.includes(`result_idx == SEARCH_CHAT_${name}_OFFSET`));
  }
});
