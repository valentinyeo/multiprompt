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
  assert.match(nativePaste, /GetForegroundWindow\(\) != target_hwnd/,
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
