const assert = require("node:assert/strict");
const fs = require("node:fs");
const test = require("node:test");

const source = fs.readFileSync("src/shortcuts.zig", "utf8");

function functionBody(name, nextName) {
  const start = source.indexOf(`pub fn ${name}(`);
  const end = source.indexOf(`\nfn ${nextName}(`, start);
  assert.notStrictEqual(start, -1, `${name} is missing`);
  assert.notStrictEqual(end, -1, `could not isolate ${name}`);
  return source.slice(start, end);
}

test("SOFT-3001 shell Ctrl+C posts copy-or-interrupt before frame-owned routing", () => {
  const hook = functionBody("keyboardHookProc", "pointOverActiveShell");
  const keyHandler = functionBody("shellCopyOrInterruptKey", "noteJumpBadgeKey");
  assert.match(
    keyHandler,
    /activeShellHasForegroundFocus\(\) and !chatViewOwnsInput\(\)/,
    "shell copy must follow paste-landed console focus, not only the frame HWND",
  );

  const early = hook.indexOf("if (wp != WM_KEYDOWN) return CallNextHookEx");
  const fg = hook.indexOf("const fg = GetForegroundWindow();", early);
  assert.notStrictEqual(early, -1);
  assert.notStrictEqual(fg, -1);
  const between = hook.slice(early, fg);
  assert.match(
    between,
    /shellCopyOrInterruptKey\([\s\S]*?WM_APP_COPY_OR_INTERRUPT/,
    "copy-or-interrupt must run before the narrow is_ours gate",
  );

  const browserStart = hook.indexOf("if (app_state.g_browser_focus_mode and activeBrowserSurfaceHasForegroundFocus())");
  const browserEnd = hook.indexOf("if (wp == WM_SYSKEYDOWN and !isCtrlDown() and activeBrowserSurfaceHasForegroundFocus())", browserStart);
  const browser = hook.slice(browserStart, browserEnd);
  assert.match(
    browser,
    /shellCopyOrInterruptKey\([\s\S]*?WM_APP_COPY_OR_INTERRUPT[\s\S]*?return CallNextHookEx/,
    "browser focus mode must not swallow shell Ctrl+C",
  );

  const isolationStart = hook.indexOf("if (ctrl and (kb.flags & 0x20) == 0 and kb.vkCode != 0x09");
  const isolationEnd = hook.indexOf("if (ctrl and kb.vkCode == 0x56)", isolationStart);
  const isolation = hook.slice(isolationStart, isolationEnd);
  assert.match(
    isolation,
    /!\(shellCopyOrInterruptKey\([\s\S]*?\)\) and activeBrowserHasForegroundFocus\(\)/,
    "browser passthrough must not steal shell Ctrl+C",
  );
  assert.doesNotMatch(
    hook.slice(hook.indexOf("var is_ours"), hook.indexOf("if (app_state.g_shortcuts_active)")),
    /WM_APP_COPY_OR_INTERRUPT/,
    "the legacy frame HWND gate must not own shell Ctrl+C anymore",
  );
});