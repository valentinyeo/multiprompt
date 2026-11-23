const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const harness = String.raw`
const std = @import("std");
const echo = @import("chat_echo.zig");
const history = @import("chat_history.zig");
const transcript = @import("chat_transcript.zig");

const rows = "{\"role\":\"user\",\"text\":\"Please check this\",\"timestamp\":\"2026-11-07T00:00:01Z\",\"offset\":0,\"end\":100}\n" ++
    "{\"role\":\"assistant\",\"text\":\"Checked\",\"timestamp\":\"2026-11-07T00:00:02Z\",\"offset\":100,\"end\":200}\n";

fn load(h: *history.History, inode: u64) !void {
    const a = std.testing.allocator;
    const wire = try std.fmt.allocPrint(a, "@mp\t1\thistory\tok\thosted-session\t0\t200\t{d}\t0\tclaude\thosted-chat\t2000\t\ttail\t0\n{s}@@MP_END@@\n", .{ inode, rows });
    defer a.free(wire);
    try h.apply(a, wire, 1, transcript.Identity.initTmux(1, 0, false, "hosted-chat", "hosted-session"));
}

test "SOFT-3097 hosted pending retires above its reply without a transcript client id" {
    var h: history.History = .{};
    defer h.deinit(std.testing.allocator);
    try load(&h, 11);
    try std.testing.expectEqual(@as(usize, 2), h.blocks.items.len);
    const user = h.blocks.items[0];
    const reply = h.blocks.items[1];
    try std.testing.expectEqual(.user, user.role);
    try std.testing.expectEqual(.prose, reply.role);
    const prompt = std.unicode.utf8ToUtf16LeStringLiteral("Please check this");
    var pending = [_]echo.Pending{.{ .text = prompt, .prefix = prompt, .anchor = .{ .after_ms = user.stamp_ms - 1000, .sent_ms = user.stamp_ms - 100 } }};
    if (@hasField(echo.Pending, "client_id")) pending[0].client_id = 123;
    const blocks = [_]echo.UserBlock{.{ .text = h.text.items[user.start..][0..user.len], .stamp_ms = user.stamp_ms, .message_id = user.message_id }};
    var assigned: [1]?usize = undefined;
    echo.assign(&pending, &blocks, false, &.{}, &assigned);
    try std.testing.expectEqual(@as(?usize, 0), assigned[0]);
    const visible_rows = h.blocks.items.len + @as(usize, if (assigned[0] == null) 1 else 0);
    try std.testing.expectEqual(@as(usize, 2), visible_rows);
    try std.testing.expect(user.start < reply.start);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Checked"), h.text.items[reply.start..][0..reply.len]);
}

test "SOFT-3097 rereading id-less hosted rows after file replacement keeps one ordered pair" {
    var h: history.History = .{};
    defer h.deinit(std.testing.allocator);
    try load(&h, 11);
    try load(&h, 12);
    try std.testing.expectEqual(@as(usize, 2), h.blocks.items.len);
    try std.testing.expectEqual(.user, h.blocks.items[0].role);
    try std.testing.expectEqual(.prose, h.blocks.items[1].role);
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, h.rows.items, "Please check this"));
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, h.rows.items, "Checked"));
    try load(&h, 12);
    try std.testing.expectEqual(@as(usize, 2), h.blocks.items.len);
}
`;

function runZigTest(name) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-row-identity-'));
  try {
    copyZig(['chat_echo.zig', 'chat_history.zig'], dir, path.join(root, 'src'));
    require('./fixtures/inline-stubs').writeChatMention(dir);
    fs.writeFileSync(path.join(dir, 'test.zig'), harness);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '--test-filter', name], { encoding: 'utf8', timeout: 60000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('SOFT-3097 hosted pending retires above its reply without a transcript client id', () => {
  runZigTest('SOFT-3097 hosted pending retires above its reply without a transcript client id');
});

test('SOFT-3097 rereading id-less hosted rows after file replacement keeps one ordered pair', () => {
  runZigTest('SOFT-3097 rereading id-less hosted rows after file replacement keeps one ordered pair');
});