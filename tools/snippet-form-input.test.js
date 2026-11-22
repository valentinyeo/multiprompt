const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const app = require('./app-source').readAppSource();

function zigFunction(name, nextName) {
  const start = app.indexOf(`fn ${name}(`);
  const end = app.indexOf(`fn ${nextName}(`, start + 1);
  assert.notStrictEqual(start, -1, `missing ${name}`);
  assert.notStrictEqual(end, -1, `missing boundary ${nextName}`);
  return app.slice(start, end);
}

test("Create Snippet transfers foreground input from the shell to its name editor", () => {
  const focus = zigFunction("focusSnippetFormInput", "createSnippetFormControls");
  assert.match(focus, /cancelShellRefocus\(g_main_hwnd\)/);
  assert.match(focus, /AttachThreadInput\(our_thread, fg_thread, 1\)/);
  assert.match(focus, /SetForegroundWindow\(g_main_hwnd\)/);
  assert.match(focus, /SetFocus\(target\)/);

  const open = zigFunction("openSnippetCreateForm", "closeSnippetCreateForm");
  assert.ok(open.indexOf("cancelShellRefocus(hwnd)") < open.indexOf("g_snippet_create_active = true"));
  assert.match(open, /createSnippetFormControls\(\)/);
});

test("the global hook passes form typing to the native EDIT controls", () => {
  const hook = zigFunction("keyboardHookProc", "shouldArmStaleAltBrowserClickRepair");
  const bypass = hook.indexOf("if (g_snippet_create_active) return CallNextHookEx");
  const globalSnippetsShortcut = hook.indexOf("kb.vkCode == 0xBA and foregroundIsOurs() and !g_snippet_create_active");
  const searchCapture = hook.indexOf("if (g_search_active)");
  assert.ok(bypass >= 0, "missing snippet-form keyboard bypass");
  assert.ok(bypass < globalSnippetsShortcut, "form must bypass global app shortcuts");
  assert.ok(bypass < searchCapture, "form must bypass palette key capture");
});

test("the snippet edit subclass keeps modal navigation and save keys", () => {
  const edit = zigFunction("snippetEditSubclassProc", "focusSnippetFormInput");
  assert.match(edit, /wp == 0x1B/);
  assert.match(edit, /wp == 0x0D and isCtrlDown\(\)/);
  assert.match(edit, /wp == 0x0D and hwnd == g_snippet_name_hwnd/);
  assert.match(edit, /wp == 0x09/);
});
