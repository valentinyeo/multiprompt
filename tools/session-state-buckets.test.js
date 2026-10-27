const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const source = require('./app-source').readAppSource();

test("all close paths park owned foreground before destroying a session surface", () => {
  const close = functionBody("closeShellRemember", "closeShell");
  const park = close.indexOf("parkMainWindowBeforeActiveShellRemoval(idx)");
  assert.ok(park > 0);
  for (const operation of ["closeWebView2()", "closeBrowserForShell(idx)", "ShowWindow(shells[idx].hwnd", "killProcessTree(shells[idx].pid)"]) {
    assert.ok(park < close.indexOf(operation), operation);
  }
});

test("complete close handles local shells as well as tmux sessions", () => {
  const start = source.indexOf("        WM_APP_CLOSE_SESSION => {");
  const end = source.indexOf("        WM_APP_CHAT_TOGGLE =>", start);
  assert.match(source.slice(start, end), /tmux_session_len > 0[\s\S]*endActiveTmuxSession\(\)[\s\S]*else[\s\S]*closeNonTmuxTabAt\(active_shell\)/);
});

function functionBody(name, nextName) {
  const start = source.indexOf(`fn ${name}(`);
  const end = source.indexOf(`\nfn ${nextName}(`, start);
  assert.notStrictEqual(start, -1, `${name} is missing`);
  assert.notStrictEqual(end, -1, `could not isolate ${name}`);
  return source.slice(start, end);
}

test("Waiting and Archived are permanent, disjoint All Sessions destinations", () => {
  assert.match(source, /const AS_TAB_WAITING: u32 = 202;/);
  assert.match(source, /const AS_TAB_ARCHIVED: u32 = 203;/);
  const membership = functionBody("allSessionsRowInTab", "sessionOverviewRowsRamMb");
  assert.match(membership, /AS_TAB_WAITING\) return row\.kind == \.hidden/);
  assert.match(membership, /AS_TAB_ARCHIVED\) return row\.kind == \.archived/);
  const visibility = functionBody("allSessionsSplitVisible", "allSessionsKindColor");
  assert.match(visibility, /AS_TAB_WAITING/);
  assert.match(visibility, /AS_TAB_ARCHIVED/);
  assert.match(functionBody("allSessionsTabLabel", "allSessionsFilterMatches"), /"Waiting"[\s\S]*"Archived"/);
});

test("All Sessions exposes direct Waiting and Archived keyboard routes", () => {
  const hook = functionBody("keyboardHookProc", "pointOverActiveShell");
  assert.match(hook, /kb\.vkCode == 0x57[\s\S]*WM_APP_ALL_SESSIONS_KEY, 35/);
  assert.match(hook, /kb\.vkCode == 0x41[\s\S]*WM_APP_ALL_SESSIONS_KEY, 36/);
  const handler = functionBody("handleAllSessionsKey", "finishUnarchiveUnattachedQueue");
  assert.match(handler, /35 =>[\s\S]*AS_TAB_WAITING/);
  assert.match(handler, /36 =>[\s\S]*AS_TAB_ARCHIVED/);
});

test("Current UI names Alt+E Waiting and Alt+X Archive", () => {
  assert.match(source, /L\("Archive Session"\)/);
  assert.match(source, /L\("Restore Workspace Waiting Sessions"\)/);
  assert.match(source, /"Press Alt\+X again to archive"/);
  assert.match(source, /w waiting   a archived/);
  assert.doesNotMatch(functionBody("sessionOverviewKindLabel", "sessionOverviewKindMatches"), /"hidden"|"dissolved"/);
});

test("Archived palette command opens the permanent Archived destination", () => {
  const confirm = source.slice(source.indexOf("if (target == SEARCH_ARCHIVED_VIEW_OFFSET)"), source.indexOf("if (target == SEARCH_SNIPPETS_MENU_OFFSET)"));
  assert.match(confirm, /g_all_sessions_tab = AS_TAB_ARCHIVED/);
  assert.doesNotMatch(confirm, /killed_count|g_all_sessions_killed_only|resurrectArchivedByKey/);
});
