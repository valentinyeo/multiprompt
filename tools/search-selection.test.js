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

function searchModeBody(mode, nextMode) {
  const updateStart = source.indexOf("fn updateSearchResults(");
  const start = source.indexOf(`if (${mode}) {`, updateStart);
  const end = source.indexOf(`\n    if (${nextMode}) {`, start);
  assert.notStrictEqual(start, -1, `${mode} result builder is missing`);
  assert.notStrictEqual(end, -1, `could not isolate ${mode}`);
  return source.slice(start, end);
}

test("filtered Back-row menus select their first actionable result", () => {
  const helper = functionBody("preferFirstFilteredResultAfterBack", "updateSearchResults");
  assert.match(helper, /g_search_len > 0 and g_search_result_count > 1/,
    "selection must move only for a non-empty query with a real result after Back");
  assert.match(helper, /g_search_sel = 1;/,
    "row 1 must become the selected first filtered result");
  assert.match(helper, /g_search_scroll = 0;/,
    "a new query must reveal the first filtered result");

  const searchableBackRowModes = [
    ["g_search_reminders_mode", "g_search_session_overview_mode"],
    ["g_search_session_overview_mode", "g_search_snippet_mode"],
    ["g_search_snippet_mode", "g_search_theme_mode"],
    ["g_search_theme_mode", "g_search_ws_sort_mode"],
    ["g_search_ws_move_mode", "g_search_group_move_mode"],
    ["g_search_group_move_mode", "g_search_tabctx_mode"],
    ["g_search_tabctx_mode", "g_search_workspace_mode"],
  ];
  for (const [mode, nextMode] of searchableBackRowModes) {
    const body = searchModeBody(mode, nextMode);
    assert.match(body, /preferFirstFilteredResultAfterBack\(\);/,
      `${mode} must select its first match instead of Back`);
  }

  const updateStart = source.indexOf("fn updateSearchResults(");
  const workspaceStart = source.indexOf("if (g_search_workspace_mode) {", updateStart);
  const workspaceEnd = source.indexOf("\n    if (g_nextunread_count > 0 and g_search_result_count < g_search_results.len) {", workspaceStart);
  assert.notStrictEqual(workspaceStart, -1, "workspace search result builder is missing");
  assert.notStrictEqual(workspaceEnd, -1, "could not isolate workspace search result builder");
  const workspaceBody = source.slice(workspaceStart, workspaceEnd);
  assert.match(workspaceBody, /preferFirstFilteredResultAfterBack\(\);/,
    "workspace open/delete search must use the shared selection invariant");
  assert.doesNotMatch(workspaceBody, /first_workspace_result/,
    "workspace search must not drift into a one-off selection implementation");
});

test("the physical reorder menu does not pretend to support search", () => {
  const fixedOrderModes = [
    ["g_search_ws_sort_mode", "g_search_ws_move_mode"],
  ];
  for (const [mode, nextMode] of fixedOrderModes) {
    const body = searchModeBody(mode, nextMode);
    assert.doesNotMatch(body, /preferFirstFilteredResultAfterBack\(\);/,
      `${mode} has fixed rows and must preserve explicit keyboard selection`);
  }
  assert.match(source, /WM_APP_SEARCH_CHAR => \{[\s\S]*?if \(g_search_ws_sort_mode\) return 0;/);
});

test("destination searches filter open workspaces, closed workspaces and groups", () => {
  const workspaces = searchModeBody("g_search_ws_move_mode", "g_search_group_move_mode");
  assert.match(workspaces, /appendWorkspaceMovePills\(\)/);
  const pills = functionBody("appendWorkspaceMovePills", "preferFirstFilteredResultAfterBack");
  assert.match(pills, /workspaceDisplayName/);
  assert.match(pills, /labelsMatchQuery\(&\.\{name\}/);
  assert.match(workspaces, /workspaceMatchesSearch\(&g_workspaces\[wi\]/);
  const groups = searchModeBody("g_search_group_move_mode", "g_search_tabctx_mode");
  assert.match(groups, /u16ContainsInsensitive\(groups\[gi\]\.name/);
  for (const body of [workspaces, groups]) {
    assert.doesNotMatch(body, /[Qq]uery is ignored/);
    assert.match(body, /g_search_result_count = 0;/,
      "root commands must not leak into the submenu before Back");
  }
  const helper = functionBody("preferFirstFilteredResultAfterBack", "updateSearchResults");
  assert.match(helper, /paletteQueryRank\(target\) > paletteQueryRank/,
    "exact names must precede prefix and substring matches");
});

test("preset queries filter and VPS Back stays outside the query filter", () => {
  const presets = searchModeBody("g_search_remind_preset_mode", "g_search_reminders_mode");
  assert.match(presets, /labelsMatchQuery\(&\.\{remindPresetLabel\(pi\)\}/);
  assert.match(presets, /g_search_sel = 0/);
  const hosts = searchModeBody("g_search_openall_host_mode", "g_search_theme_mode");
  assert.match(hosts, /id == SEARCH_OPENALL_HOST_BACK_OFFSET or/);
});

test("typing rebuilds results after resetting stale selection", () => {
  const start = source.indexOf("WM_APP_SEARCH_CHAR => {");
  const end = source.indexOf("\n        WM_APP_SEARCH_BACKSPACE => {", start);
  assert.notStrictEqual(start, -1, "search character handler is missing");
  assert.notStrictEqual(end, -1, "could not isolate search character handler");
  const body = source.slice(start, end);
  assert.match(body, /g_search_sel = 0;[\s\S]*?updateSearchResults\(\);/,
    "each typed character must rebuild results from a deterministic selection");
});

test("All Sessions search remains a direct-result list with row zero selected", () => {
  const start = source.indexOf("WM_APP_ALL_SESSIONS_FILTER_CHAR => {");
  const end = source.indexOf("\n        WM_APP_ALL_SESSIONS_FILTER_BACKSPACE => {", start);
  assert.notStrictEqual(start, -1, "All Sessions filter character handler is missing");
  assert.notStrictEqual(end, -1, "could not isolate All Sessions filter handler");
  const body = source.slice(start, end);
  assert.match(body, /g_all_sessions_sel = 0;/,
    "All Sessions has no Back row and must continue selecting its first match directly");
});

test("Ctrl+K selection follows the mouse pointer over visible result rows", () => {
  const helper = functionBody("searchResultRowAtClientPoint", "uiFontTitle");
  assert.match(helper, /g_search_scroll \+ visual_row/,
    "hover hit-testing must return the absolute row after palette scrolling");
  assert.match(helper, /searchOverlayOx\(win_w, overlay_w\)/,
    "hover hit-testing must share the browser-aware palette origin");
  assert.match(helper, /searchRowH\(\)/,
    "hover hit-testing must use the same DPI-scaled row height as paint");

  const mainStart = source.indexOf("fn wndProc(");
  assert.notStrictEqual(mainStart, -1, "main window procedure is missing");
  const start = source.indexOf("        WM_MOUSEMOVE => {", mainStart);
  const end = source.indexOf("\n        WM_LBUTTONUP => {", start);
  assert.notStrictEqual(start, -1, "WM_MOUSEMOVE handler is missing");
  assert.notStrictEqual(end, -1, "could not isolate WM_MOUSEMOVE handler");
  const body = source.slice(start, end);
  assert.match(body, /searchResultRowAtClientPoint\(GET_X\(lp\), GET_Y\(lp\)\)/,
    "ordinary pointer movement must hit-test Ctrl+K results");
  assert.match(body, /hovered_row != g_search_sel[\s\S]*?g_search_sel = hovered_row;[\s\S]*?InvalidateRect/,
    "moving to a new result must update and repaint the selected row");
});
