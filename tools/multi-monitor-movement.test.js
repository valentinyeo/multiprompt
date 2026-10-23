const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = require('./app-source').readAppSource();

function between(startText, endText) {
  const start = source.indexOf(startText);
  const end = source.indexOf(endText, start + startText.length);
  assert.notEqual(start, -1, `missing ${startText}`);
  assert.notEqual(end, -1, `missing boundary ${endText}`);
  return source.slice(start, end);
}

test("monitor selection is spatial and placement is work-area relative", () => {
  const monitorHelpers = between("const MonitorDirection = enum", "const MonitorTransitionReason = enum");
  assert.match(monitorHelpers, /directionalMonitorIndex/);
  assert.match(monitorHelpers, /lane_gap/);
  assert.match(monitorHelpers, /has_axis_variation/);
  assert.match(monitorHelpers, /mapWindowRectToWorkArea/);
  assert.doesNotMatch(monitorHelpers, /sorted left-to-right|adjacentMonitorWork/);
  assert.match(source, /monitor selection handles gaps diagonals vertical stacks and more than two displays/);
  assert.match(source, /window mapping is proportional clamped and independent of virtual desktop origin/);
});

test("all movement paths share a verified transition", () => {
  const snap = between("WM_APP_WIN_SNAP =>", "WM_APP_SEARCH_CONFIRM =>");
  assert.match(snap, /monitorSlotInDirection\(mon, direction\)/);
  assert.match(snap, /mapWindowRectToWorkArea\(wr, wa, target_slot\.work\)/);
  assert.match(snap, /beginMonitorTransition\(hwnd, target_slot/);

  const modal = between("WM_ENTERSIZEMOVE =>", "WM_LBUTTONDBLCLK =>");
  assert.match(modal, /beginMonitorTransitionAtCurrent\(hwnd, \.interactive_drag\)/);
  assert.match(modal, /retargetMonitorTransitionToCurrent\(hwnd\)/);

  assert.match(source, /WM_DISPLAYCHANGE =>[\s\S]*?beginMonitorTransitionAtCurrent\(hwnd, \.display_change\)/);
  assert.match(source, /WM_MOVE =>[\s\S]*?noteMainWindowMonitor\(hwnd\)/);
  assert.match(source, /TIMER_MONITOR_TRANSITION[\s\S]*?monitorTransitionTick\(hwnd\)/);
});

test("console Edge and masks cannot race the frame transition", () => {
  const transition = between("fn beginMonitorTransition(", "const WM_SYSCOMMAND");
  assert.match(transition, /parkBrowserForMonitorTransition/);
  assert.match(transition, /monitorTransitionComponentsReady/);
  assert.match(transition, /monitorTransitionMasksReady/);
  assert.match(transition, /expectedActiveBrowserRect/);
  assert.match(transition, /stable_samples >= 2/);
  assert.match(transition, /finishMonitorTransition\(hwnd, true, "verified"\)/);
  assert.match(transition, /finishMonitorTransition\(hwnd, false, "timeout"\)/);
  assert.match(source, /monitor-move-audit\.tsv/);

  assert.match(source, /fn positionActiveBrowser\(\) void \{\s*const timing_started = switch_timing.start\(\);\s*defer switch_timing.record\(\.position, timing_started\);\s*if \(g_monitor_transition\.active and !g_monitor_transition\.positioning\)/);
  assert.match(source, /fn updateBrowserVisibility\(\) void \{[\s\S]*?if \(g_monitor_transition\.active\) \{\s*parkBrowserForMonitorTransition\(\)/);
  assert.match(source, /fn positionBrowserEdgeMasks\(layout: BrowserLayout\) void \{[\s\S]*?if \(g_monitor_transition\.active\)/);
});
