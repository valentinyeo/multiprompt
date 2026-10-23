const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const source = require('./app-source').readAppSource();

const hookStart = source.indexOf("fn keyboardHookProc(");
const hookEnd = source.indexOf("\nfn pointOverActiveShell", hookStart);
assert.notStrictEqual(hookStart, -1, "keyboard hook is missing");
assert.notStrictEqual(hookEnd, -1, "could not isolate keyboard hook");
const hook = source.slice(hookStart, hookEnd);

test("Windows-level chords pass through before modal shortcut routing", () => {
  const passthrough = hook.indexOf("isWindowsLevelShortcut(");
  const browserFocus = hook.indexOf("if (g_browser_focus_mode and activeBrowserSurfaceHasForegroundFocus())");
  const allSessions = hook.indexOf("if (g_all_sessions_active and !g_search_active)");
  const inbox = hook.indexOf("if (g_inbox_active and !g_search_active");

  assert.ok(passthrough >= 0, "the keyboard hook must call the Windows-level passthrough predicate");
  assert.ok(passthrough < browserFocus && passthrough < allSessions && passthrough < inbox,
    "Windows-level chords must bypass browser and modal overlay routing");
  assert.match(hook.slice(passthrough, passthrough + 500), /return CallNextHookEx/,
    "reserved chords must continue down the Windows hook chain");
});

test("Ctrl+Shift+A no longer opens All Sessions directly", () => {
  assert.doesNotMatch(hook, /kb\.vkCode == 0x41[^\n]*Ctrl\+Shift\+A[\s\S]{0,200}?WM_APP_ALL_SESSIONS_OPEN/);
  assert.doesNotMatch(source, /\.a = "Ctrl\+Shift\+A"/,
    "the native shortcut help must not advertise the removed binding");
  assert.match(source, /\.a = "Ctrl\+K -> All Sessions"/,
    "All Sessions must remain discoverable through Ctrl+K");
});

test("Alt-modified spawn digits cannot trigger multiprompt spawn actions", () => {
  assert.match(hook,
    /if \(shift and \(kb\.flags & 0x20\) == 0 and kb\.vkCode >= 0x31 and kb\.vkCode <= 0x38\)/,
    "Ctrl+Shift+digit spawn routing must require Alt to be up");
});

test("Alt+Shift+S reaches the screenshot extension instead of toggling favorites", () => {
  const toggle = hook.match(/if \(([^\n]*kb\.vkCode == 0x53 and foregroundIsOurs\(\)[^\n]*)\) \{\n([\s\S]*?)\n        \}/);
  assert.ok(toggle, "the Alt+S route must remain available");
  assert.match(toggle[1], /!isCtrlDown\(\)/);
  assert.match(toggle[1], /\(GetAsyncKeyState\(0x10\) & @as\(i16, @bitCast\(@as\(u16, 0x8000\)\)\)\) == 0/,
    "Alt+S must require Shift up before consuming the extension screenshot chord");
  assert.match(toggle[2], /WM_APP_FAVORITE_TOGGLE/);
  assert.doesNotMatch(toggle[2], /WM_APP_WEBVIEW2_TOGGLE/);
  const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, "..", "extension", "manifest.json"), "utf8"));
  assert.equal(manifest.commands["take-tab-screenshot"].suggested_key.default, "Alt+Shift+S");
});

function assertFocusRepeatContract(text) {
  const end = text.indexOf('\n}');
  assert.ok(end > 0, "could not isolate the keyboard hook body");
  text = text.slice(0, end + 2);
  const release = text.match(/if \(\(kb\.vkCode == 0x51 or kb\.vkCode == 0x4D\) and \(wp == WM_KEYUP or wp == WM_SYSKEYUP\)\) \{\s*_ = claimBrowserFocusPress\(false, &g_browser_focus_chord_held\);/);
  assert.ok(release, "Q and M key-up must release the one-press latch");
  const chord = text.indexOf('const focus_chord = @import("focus.zig").browserFocusChord(wp, kb.vkCode, isCtrlDown(), isAltDown(kb.flags));');
  const find = text.indexOf('if (@import("chat_find.zig").ownsKeys(g_chat_find_open, foregroundIsOurs()) and !find_modifier and !focus_chord)');
  const toggle = text.match(/if \(focus_chord and foregroundIsOurs\(\) and active_shell < shell_count\) \{\n([\s\S]*?)\n        \}/);
  assert.ok(toggle, "Alt+Q must reach the repeat latch even without a browser pane");
  assert.ok(release.index < chord && chord < find && find < toggle.index,
    "key-up releases the latch before Find routing, and Find-open chords reach the same toggle route");
  assert.match(toggle[1], /^\s*if \(!claimBrowserFocusPress\(true, &g_browser_focus_chord_held\)\) return 1;/,
    "repeated keydowns must be consumed before any focus toggle is posted");
  assert.match(toggle[1], /g_sysmenu_pending = false;/);
  assert.equal((toggle[1].match(/PostMessageW\(g_main_hwnd, WM_APP_BROWSER_FOCUS_TOGGLE, 0, 0\)/g) || []).length, 1,
    "only the first keydown from one physical Alt+Q press may post a focus toggle");
  assert.match(toggle[1], /return 1;\s*$/, "the first keydown must also be consumed");
  assert.doesNotMatch(toggle[1], /g_browser_focus_chord_held\s*=|claimBrowserFocusPress\(false/,
    "keydown routing must not rearm the latch before physical key-up");
}

test("Alt+Q focus switching consumes key repeat until physical key-up", () => {
  assert.match(source, /var g_browser_focus_chord_held: bool = false/);
  assert.match(source, /fn claimBrowserFocusPress\(key_down: bool, held: \*bool\) bool \{\s*if \(!key_down\) \{\s*held\.\* = false;\s*return false;\s*\}\s*if \(held\.\*\) return false;\s*held\.\* = true;\s*return true;\s*\}/,
    "the latch must reject repeats and rearm only on key-up");
  assert.match(source, /fn browserFocusChord\(msg: usize, vk: usize, ctrl: bool, alt: bool\) bool \{\s*return \(msg == WM_KEYDOWN or msg == WM_SYSKEYDOWN\) and alt and !ctrl and \(vk == 0x51 or vk == 0x4D\);\s*\}/,
    "the shared chord must match only Alt+Q/M keydowns, excluding Ctrl/AltGr");
  assertFocusRepeatContract(hook);
  assert.match(source,
    /fn uninstallKeyboardHook\(\)[\s\S]{0,300}?g_browser_focus_chord_held = false/,
    "hook replacement must not preserve a stale focus latch");
});

test("Alt+Q repeat contract rejects passthrough, duplicate posts, Find interception and a pane prerequisite", () => {
  const latch = 'if (!claimBrowserFocusPress(true, &g_browser_focus_chord_held)) return 1;';
  const post = '_ = PostMessageW(g_main_hwnd, WM_APP_BROWSER_FOCUS_TOGGLE, 0, 0);';
  for (const [before, after] of [
    [latch, ''],
    [latch, latch.replace('return 1;', 'return CallNextHookEx(g_hook, nCode, wp, lp);')],
    [latch, post + '\n            ' + latch],
    [post, post + '\n            ' + post],
    [post, 'g_browser_focus_chord_held = false;\n            ' + post],
    ['and !find_modifier and !focus_chord', 'and !find_modifier'],
    ['focus_chord and foregroundIsOurs() and active_shell < shell_count)', 'focus_chord and foregroundIsOurs() and active_shell < shell_count and shells[active_shell].browser_enabled)'],
    ['claimBrowserFocusPress(false, &g_browser_focus_chord_held)', 'claimBrowserFocusPress(true, &g_browser_focus_chord_held)'],
  ]) {
    assert.ok(hook.includes(before), before);
    assert.throws(() => assertFocusRepeatContract(hook.replaceAll(before, after)), assert.AssertionError, before);
  }
});
