const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

test('CPU707 strict budgets report failures through the native runner', () => {
  const source = fs.readFileSync(path.join(__dirname, '../src/chat_perf_test.zig'), 'utf8');
  const build = fs.readFileSync(path.join(__dirname, '../build.zig'), 'utf8');
  const startHelper = source.indexOf('    const report = struct {\n        fn expectCpuBudget(');
  assert.ok(startHelper >= 0);
  const helperStart = source.indexOf('fn expectCpuBudget(', startHelper);
  const helperEnd = source.indexOf('\n        const Delta =', helperStart);
  assert.ok(helperEnd > helperStart);
  const helper = source.slice(helperStart, helperEnd);
  const stages = [['parse', 'parse_ms', 3000], ['append', 'delta_ms', 100], ['reconcile', 'reconcile_ms', 1000]];
  for (const [phase, variable, budget] of stages) {
    assert.ok(source.includes(`try report.expectCpuBudget("${phase}", ${variable}, ${budget});`));
  }
  const start = build.indexOf('    const run_chat_perf_tests =');
  const end = build.indexOf('    const chat_echo_budget_tests =', start);
  assert.ok(start >= 0 && end > start);
  const launch = build.slice(start, end);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-perf-reporting-'));
  try {
    fs.writeFileSync(path.join(dir, 'build.zig'), `const std = @import("std");
pub fn build(b: *std.Build) void {
    const chat_perf_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("fixture.zig"), .target = b.graph.host, .optimize = .ReleaseFast,
    }) });
${launch}
    b.step("check", "Run reporting control").dependOn(&run_chat_perf_tests.step);
}
`);
    const run = failing => {
      const cases = stages.flatMap(([phase, , budget]) => failing
        ? [budget, budget + 7].map(actual => `test "${phase} ${actual}" { try expectCpuBudget("${phase}", ${actual}, ${budget}); }`)
        : [`test "${phase} within" { try expectCpuBudget("${phase}", ${budget - 1}, ${budget}); }`]);
      fs.writeFileSync(path.join(dir, 'fixture.zig'), `const std = @import("std");\n${helper}\n${cases.join('\n')}\n`);
      return spawnSync(process.env.ZIG || 'zig', ['build', 'check', '-j1'], { cwd: dir, encoding: 'utf8', timeout: 120000 });
    };
    const green = run(false);
    assert.equal(green.status, 0, `${green.error || green.signal || ''}\n${green.stdout}${green.stderr}`);
    assert.doesNotMatch(green.stderr, /CPU707 phase=/);
    const red = run(true);
    assert.notEqual(red.status, 0);
    assert.equal(red.error, undefined);
    const output = red.stdout + red.stderr;
    for (const [phase, , budget] of stages) {
      for (const overage of [0, 7]) {
        assert.ok(output.includes(`CPU707 phase=${phase} actual_cpu_ms=${budget + overage} strict_budget_ms=${budget} overage_ms=${overage} mode=ReleaseFast clock=cpu_thread`), output);
      }
    }
    assert.match(output, /TestUnexpectedResult/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
