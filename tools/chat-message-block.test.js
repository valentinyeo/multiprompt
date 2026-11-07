const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');
const { copyZig } = require('./zig-copy');
const root = path.resolve(__dirname, '..');
const render = fs.readFileSync(path.join(root, 'src/chat_render.zig'), 'utf8');
function body(name) {
  const start = render.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `${name} exists`);
  return render.slice(start, render.indexOf('\n}', start) + 2);
}

test('one visible agent bubble has one reply, copy target, action position and keyboard stop', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-message-block-'));
  try {
    copyZig(['chat_style.zig'], dir);
    const fixture = String.raw`
const std = @import("std");
const chat_style = @import("chat_style.zig");
const ChatBlock = @import("chat_markdown.zig").Block;
const RECT = struct { left: i32, top: i32, right: i32, bottom: i32 };
const text = std.unicode.utf8ToUtf16LeStringLiteral("questionFirstSecondThirdnext");
const app_state = struct {
    var g_chat_block_count: usize = 5;
    var g_chat_bubble_pos = [_]chat_style.BubblePos{ .single, .first, .middle, .last, .single };
    var g_chat_blocks = [_]ChatBlock{
        .{ .start = 0, .len = 8, .role = .user, .first = true },
        .{ .start = 8, .len = 5, .role = .prose, .first = true, .reaction_reference = 1 },
        .{ .start = 13, .len = 6, .role = .prose, .reaction_reference = 1 },
        .{ .start = 19, .len = 5, .role = .prose, .reaction_reference = 1 },
        .{ .start = 24, .len = 4, .role = .user, .first = true },
    };
    var g_chat_scroll_y: i32 = 20;
};
const g_reaction_view = struct { fn hides(_: usize) bool { return false; } };
const Display = struct { text: []const u16, block: ChatBlock, source_map: ?[]const usize = null };
fn chatSelectionDisplay(index: usize) ?Display {
    if (index >= app_state.g_chat_block_count) return null;
    const block = app_state.g_chat_blocks[index];
    return .{ .text = text[block.start..][0..block.len], .block = block };
}
fn chatSelectionRect(index: usize) RECT {
    const row: i32 = @intCast(index);
    return .{ .left = 100, .right = 600, .top = row * 100, .bottom = (row + 1) * 100 };
}
fn uiScaled(value: i32) i32 { return value; }
fn chatViewClientRect(rect: *RECT) void { rect.* = .{ .left = 0, .top = 0, .right = 960, .bottom = 800 }; }
fn chatCopyBlockText(out: []u16, block: ChatBlock, _: usize, _: usize) !usize {
    return chatCopyPlainText(out, text[block.start..][0..block.len]);
}
` + ['chatMessageBounds', 'chatMessageRect', 'chatMessageTextAlloc', 'chatCopyCapacity', 'chatCopyPlainText', 'chatMessageActionRect', 'chatNavEligible'].map(body).join('\n') + String.raw`
test "one bubble is one message without changing its text or adjacent messages" {
    const a = std.testing.allocator;
    for (1..4) |i| {
        const range = chatMessageBounds(i);
        try std.testing.expectEqual(@as(usize, 1), range.first);
        try std.testing.expectEqual(@as(usize, 3), range.last);
        const reply = try chatMessageTextAlloc(a, i, true);
        defer a.free(reply);
        try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("First\n\nSecond\n\nThird"), reply);
        const copy = try chatMessageTextAlloc(a, i, false);
        defer a.free(copy);
        try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("First\r\n\r\nSecond\r\n\r\nThird"), copy);
        try std.testing.expectEqualDeep(chatMessageActionRect(1), chatMessageActionRect(i));
        try std.testing.expectEqual(i == 1, chatNavEligible(i));
    }
    const rect = chatMessageRect(2);
    try std.testing.expectEqual(@as(i32, 100), rect.top);
    try std.testing.expectEqual(@as(i32, 400), rect.bottom);
    for ([_]usize{0, 4}) |i| {
        const range = chatMessageBounds(i);
        try std.testing.expectEqual(i, range.first);
        try std.testing.expectEqual(i, range.last);
        try std.testing.expect(chatNavEligible(i));
    }
    app_state.g_chat_bubble_pos = @splat(.single);
    for (1..4) |i| {
        const range = chatMessageBounds(i);
        try std.testing.expectEqual(i, range.first);
        try std.testing.expectEqual(i, range.last);
        try std.testing.expect(chatNavEligible(i));
    }
}
`;
    fs.writeFileSync(path.join(dir, 'message.zig'), fixture);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'message.zig'), '--test-filter', 'one bubble'], { encoding: 'utf8', timeout: 60000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
