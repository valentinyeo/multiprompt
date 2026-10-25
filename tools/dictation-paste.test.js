const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const source = require('./app-source').readAppSource();

function functionBody(name, nextName) {
  const start = source.indexOf(`fn ${name}(`);
  const end = source.indexOf(`\nfn ${nextName}(`, start);
  assert.notStrictEqual(start, -1, `${name} is missing`);
  assert.notStrictEqual(end, -1, `could not isolate ${name}`);
  return source.slice(start, end);
}

test("custom SSH paste routing runs on the UI thread for each paste", () => {
  const hook = functionBody("keyboardHookProc", "staleAltMouseHookProc");
  assert.doesNotMatch(hook, /shellNeedsDirectPaste\(/);
  assert.match(hook, /PostMessageW\(g_main_hwnd, WM_APP_PASTE, active_shell, 0\)/);
  const route = functionBody("shellNeedsDirectPaste", "processTreeNeedsDirectPaste");
  assert.match(route, /proc_cache\.refresh\(\)/);
  assert.match(route, /processTreeNeedsDirectPaste\(&proc_cache, sh\.pid\)/);
  const paste = functionBody("pasteClipboardToShell", "readDeepgramApiKey");
  assert.match(paste, /shellNeedsDirectPaste\(shell_index\)/);
  assert.match(paste, /pasteClipboardToShellDirect\(shell_index\)/);
});

test("plain CMD bypasses synthetic Ctrl+V and uses direct console input", () => {
  const kindRoute = functionBody("shellKindNeedsDirectPaste", "shellNeedsDirectPaste");
  assert.match(kindRoute, /kind == \.cmd/);
  const route = functionBody("shellNeedsDirectPaste", "processTreeNeedsDirectPaste");
  assert.match(route, /shellKindNeedsDirectPaste\(sh\.kind\)/);
});

test("remaining local-console native paste verifies focus before Ctrl+V", () => {
  const nativePaste = functionBody("nativePasteToShell", "pasteClipboardToShell");
  assert.match(nativePaste, /if \(g_igsh354_paste_focus\) pasteFocusLanded\(target_hwnd\) else GetForegroundWindow\(\) == target_hwnd/,
    "dictation must not report success when shell focus never landed");
  assert.match(nativePaste, /synthesizeCtrlVIntoForeground\(\)/);
  assert.doesNotMatch(nativePaste, /VK_INSERT_U8|VK_SHIFT_U8/,
    "Shift+Insert must not return after failing in the live embedded console");
  const ctrlV = functionBody("synthesizeCtrlVIntoForeground", "dictationTargetIsBrowser");
  assert.match(ctrlV, /g_native_paste_passthrough_until = GetTickCount64\(\) \+ 1000/,
    "synthetic Ctrl+V must bypass the app's own paste interception exactly once");
  assert.match(ctrlV, /VK_V_U8/);
  assert.match(nativePaste, /return true/);
});

test("Unicode console records use VK_PACKET instead of the discarded zero keycode", () => {
  const writer = functionBody("writeUnicodeCharsAsInput", "copyUnicodeClipboardTextMaybe");
  assert.match(writer, /\.wVirtualKeyCode = VK_PACKET_U16/g);
  assert.doesNotMatch(writer, /\.wVirtualKeyCode = 0,/,
    "OpenSSH/tmux discarded the old zero-keycode records");
});

test("dictation reports success only after console output verification", () => {
  const ready = functionBody("handleDictationReady", "toggleDictation");
  assert.match(ready, /pasteDictationToShellVerified\(active_shell, transcript\)/);
  const verified = ready.indexOf('dictationAudit("shell-output-verified"');
  const success = ready.indexOf('showHeaderNoticeAscii("Dictation pasted"', verified);
  assert.ok(verified >= 0 && success > verified,
    "the shell branch must verify output before announcing a successful paste");
  assert.match(ready, /Dictation copied: console rejected input/);
  assert.match(ready, /Dictation copied: console did not confirm paste/);
  assert.match(ready, /preserveClipboardTextAfterPaste\(transcript\)/,
    "the complete transcript must remain recoverable after every shell result");
});

test("verification compares pre/post in-memory console output", () => {
  const paste = functionBody("pasteDictationToShellVerified", "handleDictationReady");
  assert.match(paste, /readShellViewportComparable\(shell_index, &before\)/);
  assert.match(paste, /pasteTextToShellDirect\(shell_index, transcript\)/);
  assert.match(paste, /dictationOutputShowsNewText\(before\[0\.\.before_len\], after\[0\.\.after_len\], transcript\)/);
  assert.match(paste, /return \.output_unverified/,
    "a written input queue is not itself proof that the terminal accepted text");
});

test("bare Enter is a deduplicated stop-only alias while recording", () => {
  const queue = functionBody("queueDictationStopFromEnter", "keyboardHookProc");
  assert.match(queue, /if \(!g_dictation_recording\.load\(\.acquire\)\) return false/,
    "Enter must never start dictation");
  assert.match(queue, /g_dictation_enter_stop_queued\.cmpxchgStrong\(false, true/,
    "held Enter must queue only one stop request");
  assert.match(queue, /PostMessageW\(g_main_hwnd, WM_APP_DICTATION_TOGGLE/);

  const hook = functionBody("keyboardHookProc", "staleAltMouseHookProc");
  const enterStop = hook.indexOf("kb.vkCode == 0x0D and queueDictationStopFromEnter()");
  const regularToggle = hook.indexOf("kb.vkCode == 0x20", enterStop);
  assert.ok(enterStop >= 0 && regularToggle > enterStop,
    "recording Enter must be consumed before ordinary modal/shell Enter routing");
  assert.match(hook, /!ctrl and !shift and kb\.vkCode == 0x0D/,
    "only bare Enter is the stop alias");

  const toggle = functionBody("toggleDictation", "pasteClipboardToShellDirect");
  assert.match(toggle, /g_dictation_enter_stop_queued\.store\(false, \.release\)/,
    "the UI handler must re-arm Enter after consuming the stop");
});

test("restored remote shells explicitly retain true-color terminal capability", () => {
  assert.match(source, /const SSH_TERM = "xterm-256color"/);
  assert.match(source, /const SSH_COLORTERM = "truecolor"/);
  const spawn = functionBody("spawnShellWithSession", "respawnShellInPlace");
  assert.match(spawn, /setEnvironmentAscii\(L\("TERM"\), SSH_TERM\)/);
  assert.match(spawn, /setEnvironmentAscii\(L\("COLORTERM"\), SSH_COLORTERM\)/);
});


test("IGSH-846 recording Escape discards audio and never delivers a transcript", () => {
  const queue = functionBody("queueDictationCancelFromEscape", "queueDictationStopFromEnter");
  assert.match(queue, /if \(!g_dictation_recording\.load\(\.acquire\)\) return false/);
  assert.match(queue, /g_dictation_cancelled\.cmpxchgStrong\(false, true/);
  assert.match(queue, /PostMessageW\(g_main_hwnd, WM_APP_DICTATION_TOGGLE, 1, 0\)/);
  assert.match(queue, /g_dictation_cancelled\.store\(false, \.release\)/,
    "failed posting must allow another cancellation attempt");
  assert.match(source, /WM_APP_DICTATION_TOGGLE => \{\s*if \(wp == 1\) \{\s*cancelDictation\(\);\s*\} else \{\s*toggleDictation\(\);/);
  const cancel = functionBody("cancelDictation", "handleDictationReady");
  assert.match(cancel, /g_dictation_recording\.store\(false, \.release\)/);
  const worker = functionBody("dictationWorkerThread", "synthesizeCtrlVIntoForeground");
  assert.match(worker, /captureDictationPcm\(audio\)[\s\S]*?if \(g_dictation_cancelled\.load\(\.acquire\)\) \{\s*if \(g_main_hwnd != null\) _ = PostMessageW\(g_main_hwnd, WM_APP_DICTATION_READY, 0, 0\);\s*return;\s*\}[\s\S]*?deepgramTranscribePcm\(/,
    "cancelled audio must be freed without provider transcription");
  const ready = functionBody("handleDictationReady", "toggleDictation");
  const discard = ready.indexOf('if (g_dictation_cancelled.load(.acquire))');
  assert.ok(discard >= 0 && discard < ready.indexOf('rememberLastPasteText(transcript)'));
  assert.match(ready.slice(discard, ready.indexOf('if (was_voice_listening and')), /return;/,
    "even a late result must not reach any composer, shell or clipboard delivery");
  const toggle = functionBody("toggleDictation", "pasteClipboardToShellDirect");
  assert.match(toggle, /g_dictation_cancelled\.store\(false, \.release\);\s*g_dictation_recording\.store\(true, \.release\)/);
});

test("IGSH-846 cancellation preserves an existing draft and restores the idle mic", () => {
  const cancel = functionBody("cancelDictation", "handleDictationReady");
  assert.match(cancel, /g_dictation_draft_owner_len = 0/,
    "detach the cancelled recording, not the user's draft");
  assert.match(cancel, /chatDictationSync\(\)/);
  assert.doesNotMatch(cancel, /chatDraft(?:Append|Set|Clear|Remove)|SetWindowText|insertTextIntoChatComposer|sendChatPrompt/);
  const ready = functionBody("handleDictationReady", "toggleDictation");
  assert.ok(ready.indexOf('if (g_dictation_cancelled.load(.acquire))') < ready.indexOf('chatDraftAppend('));
  const composer = fs.readFileSync(path.join(__dirname, '../src/chat_composer.zig'), 'utf8');
  assert.match(composer, /const next: DictationState = if \(app_state\.g_dictation_draft_owner_len == 0[^\n]*\)\s*\.idle/);
});

test("IGSH-846 idle Escape falls through unchanged, held cancellation Escape is consumed", () => {
  const queue = functionBody("queueDictationCancelFromEscape", "queueDictationStopFromEnter");
  assert.match(queue, /if \(!g_dictation_recording\.load\(\.acquire\)\) return false/,
    "idle Escape must not queue cancellation or consume the key");
  const hook = functionBody("keyboardHookProc", "staleAltMouseHookProc");
  assert.match(hook, /kb\.vkCode == 0x1B and wp == WM_KEYDOWN and !g_win_held and \(kb\.flags & 0x20\) == 0 and !isCtrlDown\(\) and\s*\(GetAsyncKeyState\(0x10\)[^\n]*== 0 and foregroundIsOurs\(\) and queueDictationCancelFromEscape\(\)\)\s*\{\s*return 1;/);
  assert.match(hook, /if \(kb\.vkCode == 0x1B and g_dictation_escape_held\) \{\s*if \(wp == WM_KEYUP or wp == WM_SYSKEYUP\) g_dictation_escape_held = false;\s*return 1;/,
    "repeats must stay consumed after recording ends, until keyup");
  const escape = hook.indexOf('and queueDictationCancelFromEscape()');
  const modal = hook.indexOf('if (g_shortcuts_active)');
  assert.ok(escape >= 0 && modal > escape);
  assert.ok(escape < hook.indexOf('and g_account_login_active'));
  assert.ok(escape < hook.indexOf('const find_key_up'));
  const composer = fs.readFileSync(path.join(__dirname, '../src/chat_composer.zig'), 'utf8');
  assert.match(composer, /if \(msg == WM_KEYDOWN and wp == 0x1B\) \{\s*if \(@import\("chat_working.zig"\).composerEscStops\(/,
    "idle composer Escape retains its existing stop-agent action");
  assert.match(hook.slice(modal), /if \(kb\.vkCode == 0x1B or kb\.vkCode == 0x70\) \{\s*_ = PostMessageW\(g_main_hwnd, WM_APP_SHORTCUTS_CLOSE, 0, 0\);/,
    "the existing shortcuts-dialog Escape action remains available when idle");
});
