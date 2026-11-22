const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');

test('a small source reset retains 2060 messages without multiplying scratch allocations', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-history-reset-'));
  try {
    copyZig(['chat_history.zig'], dir);
    fs.writeFileSync(path.join(dir, 'reset.zig'), `
const std = @import("std");
const history = @import("chat_history.zig");
const transcript = @import("chat_transcript.zig");
test "source reset retains messages with bounded scratch bytes" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(1067, 0, false, "term-1", "");
    var h: history.History = .{};
    defer h.deinit(a);
    var rows: std.ArrayList(u8) = .empty;
    defer rows.deinit(a);
    try rows.appendSlice(a, "@mp\\t1\\thistory\\tok\\tsid\\t0\\t633344\\t9\\t0\\tclaude\\tterm-1\\t0\\t\\ttail\\t0\\n");
    for (0..2060) |i| {
        const row = try std.fmt.allocPrint(a, "{{\\"role\\":\\"assistant\\",\\"id\\":\\"message-{d}\\",\\"timestamp\\":\\"2026-10-27T12:00:00Z\\",\\"text\\":\\"Message {d} retained through source replacement.\\",\\"offset\\":{d},\\"end\\":{d}}}\\n", .{ i, i, i * 300, (i + 1) * 300 });
        defer a.free(row);
        try rows.appendSlice(a, row);
    }
    try rows.appendSlice(a, "@@MP_END@@\\n");
    try h.apply(a, rows.items, 1, key);
    rows.clearRetainingCapacity();
    try rows.appendSlice(a, "@mp\\t2\\thistory\\tok\\tsid\\t0\\t6000\\t10\\t0\\tclaude\\tterm-1\\t0\\t\\ttail\\t0\\n");
    for (2040..2060) |i| {
        const row = try std.fmt.allocPrint(a, "{{\\"role\\":\\"assistant\\",\\"id\\":\\"message-{d}\\",\\"timestamp\\":\\"2026-10-27T12:00:00Z\\",\\"text\\":\\"Message {d} retained through source replacement.\\",\\"offset\\":{d},\\"end\\":{d}}}\\n", .{ i, i, (i - 2040) * 300, (i - 2039) * 300 });
        defer a.free(row);
        try rows.appendSlice(a, row);
    }
    try rows.appendSlice(a, "@@MP_END@@\\n");
    var measured = std.testing.FailingAllocator.init(a, .{});
    try h.apply(measured.allocator(), rows.items, 2, key);
    try std.testing.expectEqual(@as(usize, 2060), h.blocks.items.len);
    for (h.blocks.items, 0..) |block, i| {
        const expected = try std.fmt.allocPrint(a, "Message {d} retained through source replacement.", .{i});
        defer a.free(expected);
        const wide = try std.unicode.utf8ToUtf16LeAlloc(a, expected);
        defer a.free(wide);
        try std.testing.expectEqualSlices(u16, wide, h.text.items[block.start..][0..block.len]);
        try std.testing.expectEqual(@as(u64, if (i < 2040) i * 300 else (i - 2040) * 300), block.source_offset);
    }
    std.debug.print("RESET_SCRATCH_BYTES={d}\\n", .{measured.allocated_bytes});
    try std.testing.expect(measured.allocated_bytes < 2 * 1024 * 1024);
}
`);
    const run = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'reset.zig'), '--test-filter', 'source reset retains messages'], { encoding: 'utf8', timeout: 60000 });
    console.log(run.stderr.match(/RESET_SCRATCH_BYTES=\d+/)?.[0] || run.stderr, run.error || run.signal || "");
    assert.equal(run.status, 0, run.stdout + run.stderr);
    assert.match(run.stderr, /All 1 tests passed/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
