const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');

test('SOFT-2528 current Claude transcript drives history and delivery after clear', () => {
  const run = spawnSync('python3', ['tools/clear-old-messages-test.py', '-v'], { encoding: 'utf8', timeout: 30000 });
  assert.equal(run.status, 0, run.stdout + run.stderr);
});

test('SOFT-2528 an empty new transcript clears old messages and stays empty after reload', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'clear-old-messages-'));
  try {
    copyZig(['chat_history.zig'], dir);
    fs.writeFileSync(path.join(dir, 'clear.zig'), `
const std = @import("std");
const history = @import("chat_history.zig");
const transcript = @import("chat_transcript.zig");
test "SOFT-2528 empty new transcript replaces old history" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(2528, 0, false, "fixture", "");
    var h: history.History = .{};
    defer h.deinit(a);
    try h.apply(a, "@mp\\t1\\thistory\\tok\\told\\t0\\t100\\t9\\t0\\tclaude\\tfixture\\t0\\t\\ttail\\t0\\n" ++
        "{\\"role\\":\\"assistant\\",\\"id\\":\\"old-answer\\",\\"text\\":\\"Before clear\\"}\\n@@MP_END@@\\n", 1, key);
    try h.apply(a, "@mp\\t2\\thistory\\tok\\tnew\\t0\\t0\\t10\\t0\\tclaude\\tfixture\\t0\\t\\ttail\\t0\\n@@MP_END@@\\n", 2, key);
    try std.testing.expectEqual(@as(usize, 0), h.blocks.items.len);
    try std.testing.expectEqual(@as(usize, 0), h.rows.items.len);
    try std.testing.expectEqualStrings("new", std.mem.sliceTo(&h.read_sid, 0));
    const encoded = try h.encode(a, key);
    defer a.free(encoded);
    var restored = try history.History.decode(a, encoded, key);
    defer restored.deinit(a);
    try std.testing.expectEqual(@as(usize, 0), restored.blocks.items.len);
    try restored.apply(a, "@mp\\t3\\thistory\\tok\\tnew\\t0\\t100\\t10\\t0\\tclaude\\tfixture\\t0\\t\\tdelta\\t0\\n" ++
        "{\\"role\\":\\"user\\",\\"id\\":\\"next\\",\\"text\\":\\"After clear\\"}\\n@@MP_END@@\\n", 3, key);
    try std.testing.expectEqual(@as(usize, 1), restored.blocks.items.len);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("After clear"), restored.text.items);
}
`);
    const run = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'clear.zig'), '--test-filter', 'SOFT-2528'], { encoding: 'utf8', timeout: 60000 });
    assert.equal(run.status, 0, run.stdout + run.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
