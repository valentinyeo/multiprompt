const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const policy = async () => {
  const { tokenize } = await import(pathToFileURL(path.join(__dirname, 'strip-comments.mjs')).href);
  function noticeCalls(source) {
    const { tokens, comments } = tokenize(source, 'zig');
    const positions = [];
    let cursor = 0;
    let comment = 0;
    for (const [, value] of tokens) {
      while (cursor < source.length) {
        if (comments[comment]?.start === cursor) cursor = comments[comment++].end;
        else if (/\s/.test(source[cursor])) cursor++;
        else break;
      }
      if (!source.startsWith(value, cursor)) throw new Error('Cannot locate notice tokens');
      positions.push(cursor);
      cursor += value.length;
    }
    const declarations = [...source.matchAll(/^(?:pub )?(?:inline )?fn (\w+)\(/gm)];
    const calls = [];
    for (let i = 0; i < tokens.length; i++) {
      if (tokens[i][0] !== 'word' || tokens[i][1] !== 'showHeaderNoticeAscii' || tokens[i + 1]?.[1] !== '(' || tokens[i - 1]?.[1] === 'fn') continue;
      let end = i + 1;
      let depth = 0;
      do {
        if (tokens[end][1] === '(') depth++;
        if (tokens[end][1] === ')') depth--;
        end++;
      } while (depth > 0 && end < tokens.length);
      if (depth !== 0) throw new Error('Unterminated notice call');
      const start = positions[i];
      const name = declarations.findLast(item => item.index < start)?.[1] || 'unknown';
      const line = source.slice(source.lastIndexOf('\n', start) + 1, positions[end - 1] + 1);
      calls.push(`${name}: ${tokenize(line, 'zig').tokens.map(([, value]) => value).join('')}`);
    }
    return calls.sort();
  }

  function noticeInventory(root) {
    return Object.fromEntries(fs.readdirSync(path.join(root, 'src')).filter(file => file.endsWith('.zig')).sort().flatMap(file => {
      const calls = noticeCalls(fs.readFileSync(path.join(root, 'src', file), 'utf8'));
      return calls.length ? [[file, calls]] : [];
    }));
  }
  return { noticeCalls, noticeInventory };
};

test('only reviewed action replies may produce header notices', async () => {
  const { noticeInventory } = await policy();
  assert.deepEqual(noticeInventory(root), JSON.parse(read('tools/fixtures/IGSH-1649/action-notices.json')), 'New or changed notice: review its user click/key origin; background work must stay quiet');
});

test('the notice inventory catches automatic producers and ignores quoted code', async () => {
  const { noticeCalls } = await policy();
  const automatic = 'fn poll() void {\n showHeaderNoticeAscii("Server recovered", 6000, false);\n}';
  const action = 'fn click() void {\n if (requested) showHeaderNoticeAscii("Copied", 1200, false);\n}';
  assert.equal(noticeCalls(automatic).length, 1);
  assert.equal(noticeCalls(action).length, 1);
  assert.notDeepEqual(noticeCalls(action), noticeCalls(automatic));
  assert.notDeepEqual(noticeCalls(action), noticeCalls(action.replace('if (requested) ', '')));
  assert.equal(noticeCalls('const sample = "showHeaderNoticeAscii(\\\"fake\\\", 1, false)";').length, 0);
  assert.equal(noticeCalls('pub fn showHeaderNoticeAscii(msg: []const u8, ms: u64, beep: bool) void {}').length, 0);
});

test('quiet recovery consumes markers without removing saved diagnostics', () => {
  const main = read('src/main.zig');
  const startup = main.slice(main.indexOf('fn initializeDeferred('), main.indexOf('fn expectPinnedActionRefused('));
  assert.doesNotMatch(startup, /showHeaderNoticeAscii/);
  assert.match(startup, /takeFreezeNotice\(\)\) debugLog\(freeze_recorder.NOTICE_TEXT\)/);
  assert.match(startup, /takeRestartNotice\(\)\) debugLog\(crash_recorder.NOTICE_TEXT\)/);
  assert.doesNotMatch(read('src/capacity.zig'), /announceCapacityTransitions/);
  assert.doesNotMatch(read('src/chat_session.zig'), /showHeaderNoticeAscii\("Chat resynced"/);
  assert.doesNotMatch(read('src/drawing.zig').split('\ntest ')[0], /g_account_reauth/);
  const capacity = read('src/capacity.zig');
  assert.match(capacity, /auditCapacityAdmission\(host, workspace, origin, decision, label\);\s*if \(origin == \.automatic\) return decision == \.allow or decision == \.warn;/);
});

test('automatic capacity decisions remain effective without painting notices', () => {
  const os = require('node:os');
  const { spawnSync } = require('node:child_process');
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'quiet-capacity-'));
  try {
    const source = read('src/capacity.zig');
    const production = source.match(/pub fn capacityAdmitNewAgent\([^]*?\n\}/)[0].replaceAll('app_state.', '');
    fs.writeFileSync(path.join(directory, 'proof.zig'), String.raw`
const std = @import("std");
const AdmissionOrigin = enum { user, automatic };
const CapacityAdmission = enum { allow, warn, block_host_pressure, block_host_busy };
var next_decision: CapacityAdmission = .allow;
var notices: usize = 0;
var audits: usize = 0;
var g_capacity_block_notice_until: u64 = 0;
const g_capacity_policy = struct { host_busy_limit: [2]u16 = .{ 3, 3 } }{};
fn effectiveCapacityState(_: u8) u8 { return 1; }
fn hostBusyAgentCount(_: u8) u16 { return 4; }
fn capacityAdmissionFor(_: AdmissionOrigin, _: u8, _: u16, _: u16) CapacityAdmission { return next_decision; }
fn auditCapacityAdmission(_: u8, _: u8, _: AdmissionOrigin, _: CapacityAdmission, _: []const u8) void { audits += 1; }
fn capacityHostMetrics(_: u8) struct { load_milli: u32, cores: u16 } { return .{ .load_milli = 5000, .cores = 2 }; }
fn capacityHostLabel(_: u8) []const u8 { return "fixture"; }
fn capacityStateLabel(_: u8) []const u8 { return "critical"; }
fn GetTickCount64() u64 { return 1000; }
fn showHeaderNoticeAscii(_: []const u8, _: u64, _: bool) void { notices += 1; }
` + production + String.raw`
test "automatic admission remains quiet, while explicit actions retain feedback" {
    for (std.enums.values(CapacityAdmission)) |next| {
        next_decision = next;
        notices = 0;
        audits = 0;
        g_capacity_block_notice_until = 0;
        const expected = next == .allow or next == .warn;
        try std.testing.expectEqual(expected, capacityAdmitNewAgent(0, 0, .automatic, "fixture"));
        try std.testing.expectEqual(@as(usize, 0), notices);
        try std.testing.expectEqual(@as(usize, 1), audits);
        try std.testing.expectEqual(@as(u64, 0), g_capacity_block_notice_until);
        try std.testing.expectEqual(expected, capacityAdmitNewAgent(0, 0, .user, "fixture"));
        try std.testing.expectEqual(@as(usize, if (next == .allow) 0 else 1), notices);
        try std.testing.expectEqual(@as(usize, 2), audits);
    }
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', 'proof.zig'], { cwd: directory, encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.error?.message || result.stdout + result.stderr);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
