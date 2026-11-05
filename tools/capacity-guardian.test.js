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
    ["spawnHostedChatSession", "spawnCodexTmuxSession"],
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
  const rows = paint.indexOf("paintChatSidebarRow(");
  const sticky = paint.indexOf("paintSidebarStickyStatusCard");
  assert.ok(rows >= 0 && sticky > rows, "sticky card must cover scrolling session rows");

  assert.match(source, /const btns_y: i32 = content_end_logical \+ 4/);
  assert.match(source, /return content_end \+ 4 \+ BTN_H \+ 8/);
  assert.match(source, /return @max\(@as\(i32, 0\), rc\.bottom - sidebarStickyCardSpan\(\)\)/);
});

test('IGSH-1648 manual admission is silent and unlimited while automation stays protected', () => {
  const os = require('node:os');
  const { spawnSync } = require('node:child_process');
  const state = fs.readFileSync(path.join(root, 'src/app_state.zig'), 'utf8');
  const capacity = fs.readFileSync(path.join(root, 'src/capacity.zig'), 'utf8');
  const between = (text, start, end) => {
    const a = text.indexOf(start), b = text.indexOf(end, a + start.length);
    assert.ok(a >= 0 && b > a, `missing production range ${start}`);
    return text.slice(a, b);
  };
  const types = between(state, 'pub const CapacityState =', 'pub var g_capacity_policy =');
  const admissionType = state.match(/pub const CapacityAdmission = enum \{[^}]+\};/);
  assert.ok(admissionType, 'production admission decisions exist');
  const policy = between(capacity, 'pub const AdmissionOrigin =', 'fn capacityHostMetrics(');
  const admit = between(capacity, 'pub fn capacityAdmitNewAgent(', 'pub fn capacityBlockNoticeActive(');
  const classify = between(capacity, 'fn capacityStateForMetrics(', 'pub fn applyCapacityHysteresis(');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'capacity-origin-'));
  try {
    fs.writeFileSync(path.join(dir, 'test.zig'), `
const std = @import("std");
const app_state = @This();
${types}
${admissionType[0]}
pub var g_capacity_policy = CapacityPolicy{};
pub var g_capacity_block_notice_until: u64 = 0;
var pressure: CapacityState = .critical;
var busy: u16 = 20;
var notices: usize = 0;
var audits: usize = 0;
fn effectiveCapacityState(_: u8) CapacityState { return pressure; }
fn hostBusyAgentCount(_: u8) u16 { return busy; }
fn capacityHostMetrics(_: u8) HostCapacity { return .{ .cores = 8, .load_milli = 64000 }; }
fn capacityHostLabel(_: u8) []const u8 { return "test host"; }
fn capacityStateLabel(_: CapacityState) []const u8 { return "test pressure"; }
fn auditCapacityAdmission(_: u8, _: u8, _: AdmissionOrigin, _: CapacityAdmission, _: []const u8) void { audits += 1; }
fn showHeaderNoticeAscii(_: []const u8, _: u32, _: bool) void { notices += 1; }
fn GetTickCount64() u64 { return 100; }
${policy}
${admit}
${classify}
test "manual starts proceed silently for every pressure, workspace and busy count" {
    for ([_]CapacityState{ .unknown, .green, .amber, .red, .critical }) |p| {
        pressure = p;
        for ([_]u16{ 0, 8, 20 }) |b| {
            busy = b;
            for ([_]u8{ 0, 1, 255 }) |workspace| {
                for ([_]u8{ 0, 1, 2 }) |host| {
                    notices = 0;
                    g_capacity_block_notice_until = 0;
                    try std.testing.expect(capacityAdmitNewAgent(host, workspace, .user, "manual session"));
                    try std.testing.expectEqual(@as(usize, 0), notices);
                    try std.testing.expectEqual(@as(u64, 0), g_capacity_block_notice_until);
                }
            }
        }
    }
    try std.testing.expect(audits > 0);
}
test "automatic pressure and busy refusals stay quiet and still block" {
    g_capacity_block_notice_until = 0;
    for ([_]CapacityState{ .red, .critical }) |p| {
        pressure = p; busy = 0; notices = 0;
        try std.testing.expect(!capacityAdmitNewAgent(0, 0, .automatic, "automatic session"));
        try std.testing.expectEqual(@as(usize, 0), notices);
        try std.testing.expectEqual(@as(u64, 0), g_capacity_block_notice_until);
    }
    pressure = .green; busy = 8; notices = 0;
    try std.testing.expect(!capacityAdmitNewAgent(0, 0, .automatic, "automatic session"));
    try std.testing.expectEqual(@as(usize, 0), notices);
    busy = 0; notices = 0;
    try std.testing.expect(capacityAdmitNewAgent(0, 0, .automatic, "automatic session"));
    try std.testing.expectEqual(@as(usize, 0), notices);
}
test "quiet sustained PSI stays green and sustained critical PSI still blocks automation" {
    var metrics = HostCapacity{ .valid = true, .cores = 8, .mem_total_kb = 100000, .mem_available_kb = 50000, .cpu_psi_milli = 1000, .mem_psi_milli = 2000, .io_psi_milli = 3000 };
    try std.testing.expectEqual(CapacityState.green, capacityStateForMetrics(metrics, CapacityPolicy{}));
    metrics.cpu_psi_milli = 60000;
    try std.testing.expectEqual(CapacityState.critical, capacityStateForMetrics(metrics, CapacityPolicy{}));
}
`);
    const run = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig')], { encoding: 'utf8', timeout: 120000 });
    assert.equal(run.error, undefined);
    assert.equal(run.status, 0, run.stdout + run.stderr);
    console.log(run.stderr.trim());
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('IGSH-1648 the real remote probe ignores short PSI spikes and retains sustained pressure', { skip: process.platform === 'win32' }, () => {
  const os = require('node:os');
  const { spawnSync } = require('node:child_process');
  const state = fs.readFileSync(path.join(root, 'src/app_state.zig'), 'utf8');
  const declaration = state.match(/pub const VPS_PROBE_SCRIPT =([\s\S]+?);\n/);
  assert.ok(declaration, 'production remote probe exists');
  const script = [...declaration[1].matchAll(/"(?:\\.|[^"\\])*"/g)].map(match => JSON.parse(match[0])).join('');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'capacity-probe-'));
  try {
    fs.mkdirSync(path.join(dir, 'pressure'));
    fs.writeFileSync(path.join(dir, 'loadavg'), '0.10 0.10 0.10 1/10 10\n');
    fs.writeFileSync(path.join(dir, 'meminfo'), 'MemTotal: 100000 kB\nMemAvailable: 50000 kB\nSwapTotal: 1000 kB\nSwapFree: 1000 kB\n');
    const probe = () => {
      const run = spawnSync('/bin/sh', ['-c', script.replaceAll('/proc', dir)], { encoding: 'utf8', timeout: 10000 });
      assert.equal(run.status, 0, run.stderr);
      const fields = run.stdout.trim().split('|');
      assert.equal(fields[0], '@capacity');
      assert.equal(fields.length, 11, 'wire field count remains compatible');
      return fields.slice(7, 10).map(Number);
    };
    for (const [index, kind] of ['cpu', 'memory', 'io'].entries()) {
      fs.writeFileSync(path.join(dir, 'pressure', kind), `some avg10=90.00 avg60=${index + 1}.00 avg300=0.00 total=123\n`);
    }
    assert.deepEqual(probe(), [1, 2, 3], 'a ten-second spike must not enter the capacity sample');
    for (const kind of ['cpu', 'memory', 'io']) {
      fs.writeFileSync(path.join(dir, 'pressure', kind), 'some avg10=0.00 avg60=60.00 avg300=0.00 total=123\n');
    }
    assert.deepEqual(probe(), [60, 60, 60], 'sustained pressure must still reach automatic admission');
    fs.rmSync(path.join(dir, 'pressure'), { recursive: true });
    assert.deepEqual(probe(), [0, 0, 0], 'missing pressure files retain zero fallback');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('IGSH-1648 manual launch paths and resurrection retain explicit origins', () => {
  const palette = fs.readFileSync(path.join(root, 'src/command_palette.zig'), 'utf8');
  for (const reason of ['c.label[0..c.label_len]', '"new workspace session"', 'reason']) {
    assert.ok(palette.includes(`capacityAdmitNewAgent(host, workspace, .user, ${reason})`));
  }
  const archive = fs.readFileSync(path.join(root, 'src/archive.zig'), 'utf8');
  assert.ok(archive.includes('capacityAdmitNewAgent(host, workspace, .automatic, "Claude resurrection")'));
});
