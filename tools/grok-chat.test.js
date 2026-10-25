const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8').replace(/\r\n/g, '\n');
const sources = Object.fromEntries(['chat_composer', 'window_layout', 'chat_render', 'chat_style', 'voice', 'shortcuts', 'main', 'app_state', 'win32'].map(name => [name, read(`src/${name}.zig`)]));
function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `missing ${name}`);
  const end = source.indexOf('\n}', start);
  assert.ok(end > start, `unterminated ${name}`);
  return source.slice(start, end + 2);
}
function requires(text, ...snippets) {
  for (const snippet of snippets) assert.ok(text.includes(snippet), `missing ${snippet}`);
}
function gate(name, check, file, before, after = 'REMOVED') {
  test(`IGSH-849 ${name}`, () => {
    check(sources);
    assert.ok(sources[file].includes(before), `negative control target: ${before}`);
    const broken = { ...sources, [file]: sources[file].replace(before, after) };
    assert.throws(() => check(broken), assert.AssertionError);
  });
}

gate('recording replaces the Edit with three 1:2:1 pill controls', s => {
  requires(body(s.chat_composer, 'chatDictationRects'), 'const gap = @min(uiScaled(16)', ' - 2 * gap, 4)', '.stop =', '.meter =', '.send =');
  requires(body(s.chat_composer, 'layoutChatControls'), 'if (recording) SW_HIDE else SW_SHOW', 'chatAcClose()');
  requires(body(s.chat_composer, 'chatComposerFocusAllowed'), 'g_chat_find_open or chatDictationBarVisible()');
  requires(body(s.chat_composer, 'openChatView'), 'if (chatDictationBarVisible()) SW_HIDE else SW_SHOW');
  requires(body(s.chat_composer, 'chatViewLayout'), 'if (chatDictationBarVisible()) uiScaled(60)');
  const paint = body(s.window_layout, 'paintChatView');
  assert.match(paint, /if \(recording\) \{\s*paintChatDictationBar\(hdc\);\s*\} else \{/);
  requires(body(s.window_layout, 'paintChatDictationBar'), 'bar.stop.bottom - bar.stop.top, 2', 'paintChatSurface(hdc, bar.stop', 'paintChatSurface(hdc, bar.meter', 'fillRoundRectAA(hdc, bar.send');
}, 'chat_composer', 'if (recording) SW_HIDE else SW_SHOW');

gate('timer resets before recording and displays elapsed m:ss', s => {
  const start = body(s.voice, 'toggleDictation');
  const reset = start.indexOf('g_dictation_start_tick = GetTickCount64()');
  assert.ok(reset >= 0 && reset < start.indexOf('g_dictation_recording.store(true'));
  requires(body(s.window_layout, 'paintChatDictationBar'), 'GetTickCount64() -| app_state.g_dictation_start_tick', '/ 1000', '"{d}:{d:0>2}"', 'seconds / 60, seconds % 60');
  requires(body(s.chat_composer, 'chatDictationSync'), 'TIMER_CHAT_DICTATION, 100, null', 'KillTimer');
  requires(s.main, 'wp == @import("win32.zig").TIMER_CHAT_DICTATION', 'chatDictationSync();\n                const card');
}, 'voice', 'g_dictation_start_tick = GetTickCount64()');

gate('meter consumes real recorded PCM RMS, never a clock animation', s => {
  const publish = body(s.voice, 'publishDictationLevel');
  requires(publish, 'std.mem.bytesAsSlice(i16, pcm', 'pcmFrameRms(samples)', 'g_dictation_level.store(level, .release)');
  const capture = body(s.voice, 'captureDictationPcm');
  requires(capture, 'publishDictationLevel(out[cursor..end])', 'const src = headers[i].lpData.?[0..n]', 'publishDictationLevel(src)');
  const paint = body(s.window_layout, 'paintChatDictationBar');
  requires(paint, 'g_dictation_level.load(.acquire)', 'level -| threshold', 'for (0..12)');
  assert.doesNotMatch(paint.slice(paint.indexOf('const level ='), paint.indexOf('if (verboseLoggingEnabled())')), /GetTickCount|sin\(|cos\(|random/);
  requires(body(s.voice, 'toggleDictation'), 'g_dictation_level.store(0, .release)');
}, 'voice', 'publishDictationLevel(src)');

gate('square stops into the owned draft without sending', s => {
  const click = body(s.chat_composer, 'chatDictationClick');
  assert.match(click, /pointInRect\(bar.stop, x, y\)\) \{\s*app_state.g_dictation_send_on_ready = false;\s*chatDictationToggle\(\);/);
  requires(body(s.voice, 'toggleDictation'), 'g_dictation_recording.store(false, .release)');
  requires(body(s.voice, 'handleDictationReady'), 'chatDraftAppend(app_state.g_dictation_draft_owner[0..app_state.g_dictation_draft_owner_len], transcript)');
  requires(body(s.window_layout, 'paintChatDictationBar'), 'cx - half', 'RGB(255, 255, 255)');
}, 'chat_composer', 'app_state.g_dictation_send_on_ready = false;\n            chatDictationToggle();');

gate('arrow stops then sends only after transcription to the original active tab', s => {
  assert.match(body(s.chat_composer, 'chatDictationClick'), /pointInRect\(bar.send, x, y\)\) \{\s*app_state.g_dictation_send_on_ready = true;\s*chatDictationToggle\(\);/);
  const ready = body(s.voice, 'handleDictationReady');
  requires(ready, 'const send_on_ready = app_state.g_dictation_send_on_ready', 'app_state.g_dictation_send_on_ready = false', 'if (send_on_ready and app_state.g_chat_active and std.mem.eql', 'chatDraftKeyForShell(app_state.active_shell, &owner)', 'sendChatPrompt()');
  assert.ok(ready.indexOf('chatDraftAppend(') < ready.indexOf('if (send_on_ready'));
  const paint = body(s.window_layout, 'paintChatDictationBar');
  requires(paint, 'bar.send', 'RGB(250, 250, 250)', 'canvas.strokePolyline', 'RGB(16, 16, 16)');
}, 'chat_composer', 'app_state.g_dictation_send_on_ready = true;');

gate('Escape cancels even the eventual transcript and cannot send', s => {
  const hook = body(s.shortcuts, 'keyboardHookProc');
  assert.match(hook, /kb\.vkCode == 0x1B[\s\S]{0,240}queueDictationCancelFromEscape\(\)\)/);
  requires(s.main, 'if (wp == 1) {', 'cancelDictation();', 'toggleDictation();');
  requires(body(s.chat_composer, 'chatComposerSubclassProc'), 'wp == 0x1B and app_state.g_dictation_running', 'cancelDictation()');
  requires(body(s.voice, 'cancelDictation'), 'g_dictation_cancelled.store(true, .release)', 'g_dictation_send_on_ready = false', 'g_dictation_recording.store(false, .release)', 'chatDictationSync()');
  const ready = body(s.voice, 'handleDictationReady');
  const discard = ready.indexOf('if (app_state.g_dictation_cancelled.load(.acquire))');
  assert.ok(discard >= 0 && discard < ready.indexOf('rememberLastPasteText(transcript)'));
  requires(ready.slice(discard, ready.indexOf('rememberLastPasteText(transcript)')), 'g_dictation_draft_owner_len = 0', 'dictationAudit("cancelled", 0)', 'return;');
}, 'voice', 'g_dictation_cancelled.store(true, .release)');

gate('bar disappears on stop, cancel, errors and completion; other tabs keep their composer', s => {
  requires(body(s.chat_composer, 'chatDictationBarVisible'), 'g_dictation_recording.load(.acquire)', 'std.mem.eql(u8, app_state.g_dictation_draft_owner', 'app_state.g_chat_draft_owner');
  requires(body(s.voice, 'handleDictationReady'), 'g_dictation_recording.store(false, .release)', 'g_dictation_running.store(false, .release)', 'defer @import("chat_composer.zig").chatDictationSync()');
  requires(body(s.chat_composer, 'chatDictationSync'), 'layoutChatControls()', 'KillTimer');
  requires(body(s.chat_composer, 'layoutChatControls'), 'if (recording) SW_HIDE else SW_SHOW');
}, 'voice', 'app_state.g_dictation_recording.store(false, .release);\n    app_state.g_dictation_running.store(false, .release);');

gate('progress/working strip is neither painted nor reserved; permissions retain space', s => {
  assert.doesNotMatch(body(s.window_layout, 'paintChatView'), /g_chat_working_applied|workingBarText|[Pp]rogress/);
  assert.match(body(s.window_layout, 'chatWorkingIndicatorH'), /return if \(chatPermissionVisible\(\)\) uiScaled\(36\) else 0;/);
  requires(body(s.chat_composer, 'chatViewLayout'), 'composer_card.top - gap - chatWorkingIndicatorH() - chatNewMessagesHeight()');
}, 'window_layout', 'return if (chatPermissionVisible()) uiScaled(36) else 0;', 'return uiScaled(22);');

for (const [label, token] of [['Archive', 'chatArchiveButton'], ['Remind me', 'chatRemindButton'], ['Wait', 'chatWaitButton']]) {
  gate(`${label} control has no paint, hit target or reserved slot`, s => {
    const ui = [body(s.window_layout, 'paintChatView'), body(s.chat_composer, 'chatButtonAt'), body(s.chat_composer, 'chatViewLayout')].join('\n');
    assert.ok(!ui.includes(token));
    assert.ok(!ui.includes(`L("${label}")`));
    assert.doesNotMatch(ui, /\.(?:archive|remind|wait)_(?:btn|rect|shown)/i);
  }, 'window_layout', 'pub fn paintChatView(hdc: HANDLE) void {', `pub fn paintChatView(hdc: HANDLE) void {\n    ${token}();`);
}

gate('ordinary sender labels are removed along with their header height', s => {
  assert.doesNotMatch(body(s.chat_render, 'chatPaintBlock'), /chatPaintAgentHeader|L\("(?:You|Claude|Codex|Agent)"\)/);
  assert.match(body(s.chat_style, 'headerHeight'), /return 0;/);
}, 'chat_style', 'pub fn headerHeight(_: md.Block, _: i32) i32 {\n    return 0;', 'pub fn headerHeight(_: md.Block, _: i32) i32 {\n    return 22;');

gate('timestamps are absent and reserve no row; attribution and read receipts survive', s => {
  assert.doesNotMatch(body(s.chat_render, 'chatPaintTime'), /block\.time|block\.zone/);
  assert.doesNotMatch(body(s.chat_render, 'chatMeasureBlockRect'), /block\.time/);
  assert.doesNotMatch(body(s.chat_render, 'chatPaintBlock'), /block\.time/);
  requires(body(s.chat_render, 'chatPaintTime'), 'block.sender', 'Read');
  requires(body(s.chat_render, 'chatMeasureBlockRect'), 'chatEchoBlockConfirmed(buf, block)');
}, 'chat_render', 'fn chatPaintTime(hdc: HANDLE, block: ChatBlock, area: RECT, right: bool, confirmed: bool) void {', 'fn chatPaintTime(hdc: HANDLE, block: ChatBlock, area: RECT, right: bool, confirmed: bool) void {\n    _ = block.time;');

gate('chat bubbles and composer use rounded corners rather than the old four pixels', s => {
  assert.match(s.app_state, /CHAT_BUBBLE_RADIUS = 20;/);
  requires(body(s.window_layout, 'chatSurfaceRadius'), 'uiScaled(CHAT_BUBBLE_RADIUS)');
  requires(body(s.chat_render, 'chatPaintBlock'), 'uiScaled(CHAT_BUBBLE_RADIUS)');
  requires(body(s.window_layout, 'paintChatButton'), 'const radius = rc.bottom - rc.top;');
}, 'app_state', 'CHAT_BUBBLE_RADIUS = 20;', 'CHAT_BUBBLE_RADIUS = 4;');
