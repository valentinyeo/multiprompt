const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

test('CPU budgets exclude descheduling but count actual thread work', () => {
  const { spawnSync } = require('node:child_process');
  const source = fs.readFileSync(path.join(__dirname, '../src/chat_perf_test.zig'), 'utf8');
  const clock = source.slice(source.indexOf('fn now('), source.indexOf('\ntest ', source.indexOf('fn now(')));
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-perf-clock-'));
  try {
    fs.writeFileSync(path.join(dir, 'test.zig'), `const std = @import("std");
${clock}
test "CPU measurement ignores host pauses without hiding slow computation" {
    const start = now();
    const wall_start = std.Io.Clock.awake.now(std.testing.io);
    try std.Io.sleep(std.testing.io, .fromMilliseconds(120), .awake);
    const paused_cpu_ms = ms(start);
    const paused_wall_ms = wall_start.durationTo(std.Io.Clock.awake.now(std.testing.io)).toMilliseconds();
    try std.testing.expect(paused_wall_ms >= 100);
    try std.testing.expect(paused_cpu_ms < 50);
    const busy_start = std.Io.Clock.cpu_thread.now(std.testing.io);
    const measured_start = now();
    var result: u64 = 1;
    while (busy_start.durationTo(std.Io.Clock.cpu_thread.now(std.testing.io)).toMilliseconds() < 80) {
        result = result *% 6364136223846793005 +% 1;
        std.mem.doNotOptimizeAway(result);
    }
    const busy_cpu_ms = ms(measured_start);
    try std.testing.expect(busy_cpu_ms >= 75);
    try std.testing.expect(result != 1);
    std.debug.print("clock control paused_cpu_ms={d} paused_wall_ms={d} busy_cpu_ms={d}\\n", .{ paused_cpu_ms, paused_wall_ms, busy_cpu_ms });
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', 'test.zig', '-j1'], {
      cwd: dir, encoding: 'utf8', timeout: 120000,
    });
    assert.equal(result.status, 0, `${result.error || result.signal || ''}\n${result.stdout}${result.stderr}`);
    assert.match(result.stderr, /clock control paused_cpu_ms=\d+ paused_wall_ms=\d+ busy_cpu_ms=\d+/);
    console.log(result.stderr.trim());
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
