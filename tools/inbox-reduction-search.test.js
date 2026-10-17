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

test("Inbox reduction search matches every visible identity field", () => {
  const matches = functionBody("inboxFilterMatches", "inboxRowVisible");
  for (const field of ["r.name", "r.sub", "r.pv", "ws.name"]) {
    assert.match(matches, new RegExp(field.replace(".", "\\.")), `Inbox search must match ${field}`);
  }
  for (const agent of ["claude", "codex", "pi", "kimi"]) {
    assert.match(matches, new RegExp(`"${agent}"`), `Inbox search must match ${agent} sessions`);
  }
  assert.match(functionBody("inboxRowVisible", "inboxListTop"), /return inboxFilterMatches\(r\)/,
    "all count, paint, navigation, and mouse paths must share the reduction predicate");
});

test("Ctrl+F and slash enter one shared Inbox search mode", () => {
  const hook = functionBody("keyboardHookProc", "pointOverActiveShell");
  const inboxStart = hook.indexOf("if (g_inbox_active and !g_search_active");
  const inbox = hook.slice(inboxStart, hook.indexOf("if (g_search_active) {", inboxStart));
  assert.match(inbox, /ctrl and !shift and kb\.vkCode == 0x46/);
  assert.match(inbox, /!ctrl and !shift and kb\.vkCode == 0xBF/);
  assert.match(inbox, /WM_APP_INBOX_FILTER_OPEN/);
  assert.match(inbox, /WM_APP_INBOX_FILTER_BACKSPACE/);
  assert.match(inbox, /WM_APP_INBOX_FILTER_CLOSE/);
  assert.match(inbox, /WM_APP_INBOX_KEY, 4, 0/,
    "Enter must use the normal selected-row open path");
});

test("Inbox search has visible query, empty-result, and help states", () => {
  const paint = functionBody("paintInbox", "openInbox");
  assert.match(paint, /L\("Find Inbox"\)/);
  assert.match(paint, /g_inbox_filter_buf/);
  assert.match(paint, /No Inbox sessions match this search/);
  assert.match(paint, /Ctrl\+F or \/ search/);
  assert.match(source, /\.a = "Ctrl\+F or \/", \.b = "Reduce Inbox to matching sessions"/);
});
