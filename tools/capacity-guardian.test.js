const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const source = require('./app-source').readAppSource();

function functionBody(name, nextName) {
  const start = source.indexOf(`fn ${name}(`);
  const end = source.indexOf(`fn ${nextName}(`, start + 1);
  assert.notStrictEqual(start, -1, `missing ${name}`);
  assert.notStrictEqual(end, -1, `missing boundary ${nextName}`);
  return source.slice(start, end);
}

test("host telemetry includes normalized load, memory, swap, and Linux PSI", () => {
  assert.match(source, /@capacity\|/);
  assert.match(source, /_NPROCESSORS_ONLN/);
  assert.match(source, /\/proc\/loadavg/);
  assert.match(source, /MemAvailable:/);
  assert.match(source, /SwapFree:/);
  assert.match(source, /\/proc\/pressure\/cpu/);
  assert.match(source, /\/proc\/pressure\/memory/);
  assert.match(source, /\/proc\/pressure\/io/);
  assert.match(source, /TIMER_VPS_CAPACITY/);
});

test("all known new-agent paths use the shared admission gate", () => {
  for (const [name, next] of [
    ["spawnCodexTmuxSession", "showHeaderNoticeAscii"],
    ["spawnCustomCmd", "remotePathSafeForShell"],
    ["resurrectArchivedByKey", "remoteShellTextIsSafe"],
  ]) {
    assert.match(functionBody(name, next), /capacityAdmitNewAgent\(/, `${name} bypasses capacity admission`);
  }
  assert.match(source, /block_host_pressure/);
  assert.match(source, /block_host_busy/);
  assert.doesNotMatch(source, /block_workspace_busy/);
  assert.doesNotMatch(source, /g_capacity_policy\.workspace_busy_limit/);
  assert.doesNotMatch(source, /capacityJsonValue\(json, "workspace_busy_agents"/);
});

test("neutral Alt+T shells skip admission while opt-in agents use it", () => {
  const spawnBody = functionBody("spawnWorkspaceTmuxSession", "activeRemoteContextForCodexTmux");
  assert.match(spawnBody, /program\.len > 0 and commandCreatesAgentWorkload\(program\) and\s+!capacityAdmitNewAgent/);
  assert.match(spawnBody, /spawnShellWithSession\(\.tmux/);
  assert.match(spawnBody, /ai_agent = if \(claude\) 1 else 0/);
});

test("workspace busy counts are diagnostic and never an admission ceiling", () => {
  const admission = functionBody("capacityAdmissionFor", "capacityAuditPath");
  assert.doesNotMatch(admission, /workspace/);

  const workspaceState = functionBody("workspaceCapacityState", "commandCreatesAgentWorkload");
  assert.doesNotMatch(workspaceState, /workspaceBusyAgentCount|busy_limit/);

  assert.match(source, /capacity_workspace_busy_agents/);
  assert.match(source, /"capacity_workspace_busy_limit", 0/);
});

test("existing attaches and cleanup remain available under pressure", () => {
  const spawnBody = functionBody("spawnShellWithSession", "respawnShellInPlace");
  assert.doesNotMatch(spawnBody, /capacityAdmitNewAgent/);
  const queueBody = functionBody("unarchiveNextUnattachedSession", "activateSessionOverviewRow");
  assert.doesNotMatch(queueBody, /capacityAdmitNewAgent/);
});

test("cleanup classification is advisory and cannot auto-kill sessions", () => {
  assert.match(source, /stale_candidate: bool = false,/);
  assert.match(source, /STALE_AFTER_MS: u64 = 72 \* 60 \* 60 \* 1000/);
  const guardianStart = source.indexOf("const CapacityState = enum");
  const guardianEnd = source.indexOf("var g_main_hwnd", guardianStart);
  const guardian = source.slice(guardianStart, guardianEnd);
  assert.doesNotMatch(guardian, /killRemoteTmuxSession|TerminateProcess|tmux kill-session/);
});

test("capacity policy and decisions are durable and diagnosable", () => {
  assert.ok(source.includes("\\\\ZigShell\\\\capacity.json"));
  assert.ok(source.includes("\\\\ZigShell\\\\capacity-audit.tsv"));
  assert.match(source, /capacity_uk_state/);
  assert.match(source, /capacity_workspace_busy_agents/);
  assert.match(source, /recovery_samples < 4/);
});

test("All Sessions exposes per-session RAM and deduplicated workspace totals", () => {
  const rows = functionBody("buildSessionOverviewRows", "sessionOverviewHostLabel");
  assert.match(rows, /row\.ram_mb = tmuxSessionRamMb\(host, sess, shells\[i\]\.ram_mb\)/);
  assert.match(rows, /row\.ram_mb = tmuxSessionRamMb\(e\.tmux_host, reminder_session, 0\)/);
  assert.match(rows, /row\.ram_mb = e\.ram_mb/);

  const totals = functionBody("sessionOverviewRowsRamMb", "allSessionsTabRamMb");
  assert.match(totals, /row\.kind == \.archived/);
  assert.match(totals, /duplicate = true/);

  const paint = functionBody("paintAllSessions", "openAllSessions");
  assert.match(paint, /allSessionsTabRamMb\(tabid\)/);
  assert.match(paint, /"\{d\} MB"/);
  assert.match(paint, /row\.kind == \.archived[\s\S]*"0 MB"/);
});

test("sidebar VPS card explains pressure as percentages with explicit Critical boundaries", () => {
  const card = functionBody("paintSidebarVpsCard", "paintSidebar");
  assert.match(card, /capacityStateLabel\(state\)/);
  assert.match(card, /formatCapacityCriticalCause/);
  assert.match(card, /"CPU load"/);
  assert.match(card, /capacityLoadPercent\(metrics\)/);
  assert.match(card, /"RAM free"/);
  assert.match(card, /capacityAvailableRamPercent\(metrics\)/);
  assert.doesNotMatch(card, /\/ \{d\} cores/,
    "raw Linux load versus core-count notation is not user-readable");
  assert.match(card, /"START: LOAD 150%\+ \| WAIT 50%\+"/);
  assert.match(card, /"START: RAM FREE 8%-"/);
  assert.match(card, /"END: 4 LOWER CHECKS \(~1 MIN\)"/);
  assert.match(card, /hostBusyAgentCount\(host\)/);
  assert.match(card, /"Claude \{d\}"/);
  assert.match(card, /"Codex \{d\}"/);
  assert.match(card, /"Other \{d\}"/);

  const carousel = functionBody("paintSidebarStickyStatusCard", "paintSidebar");
  assert.match(carousel, /paintSidebarCombinedCard/);
  assert.match(carousel, /paintSidebarVpsCard/);
  assert.match(carousel, /paintSidebarAiPaceCard/);

  const paint = functionBody("paintSidebar", "clampSearchSelectionAndScroll");
  const newTab = paint.indexOf('L("+ New tab")');
  const sticky = paint.indexOf("paintSidebarStickyStatusCard");
  assert.ok(newTab >= 0 && sticky > newTab, "sticky card must cover scrolling New Tab content");

  assert.match(source, /const button_y = content_end \+ 4/);
  assert.match(source, /return content_end \+ 4 \+ BTN_H \+ 8/);
  assert.match(source, /return @max\(@as\(i32, 0\), rc\.bottom - sidebarStickyCardSpan\(\)\)/);
});
