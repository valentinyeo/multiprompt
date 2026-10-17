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

test("Alt+Q focus switching consumes key repeat until physical key-up", () => {
  assert.match(source, /var g_browser_focus_chord_held: bool = false/);
  assert.match(hook,
    /\(kb\.vkCode == 0x51 or kb\.vkCode == 0x4D\)[\s\S]{0,180}?WM_KEYUP[\s\S]{0,180}?claimBrowserFocusPress\(false, &g_browser_focus_chord_held\)/,
    "Q and M key-up must release the one-press latch");
  assert.match(hook,
    /foregroundIsOurs\(\) and \(\(active_shell < shell_count[\s\S]{0,180}?claimBrowserFocusPress\(true, &g_browser_focus_chord_held\)[\s\S]{0,260}?WM_APP_BROWSER_FOCUS_TOGGLE/,
    "only the first keydown from one physical Alt+Q press may post a focus toggle");
  assert.match(source,
    /fn uninstallKeyboardHook\(\)[\s\S]{0,300}?g_browser_focus_chord_held = false/,
    "hook replacement must not preserve a stale focus latch");
});
