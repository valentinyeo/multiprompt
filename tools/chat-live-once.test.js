const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const fixture = name => fs.readFileSync(path.join(root, 'tools/fixtures/MUBO-135', name), 'utf8');

const harness = `
const std = @import("std");
const history = @import("chat_history.zig");
const live = @import("chat_live.zig");
const transcript = @import("chat_transcript.zig");

test "MUBO-135 a reply first seen cut then full shows once beside its history row" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(1, 0, false, "mubo-135", "");
    var h: history.History = .{};
    defer h.deinit(a);
    try h.apply(a, ${JSON.stringify(fixture('history-wire.txt'))}, 1, key);
    try std.testing.expectEqual(@as(usize, 2), h.blocks.items.len);
    const sid = "mubo-135-live";
    _ = live.begin(1, 0, sid);
    defer live.release(1);
    try std.testing.expect(live.applyPage(1, sid, ${JSON.stringify(fixture('live-events.json'))}));
    var text: [1024]u16 = @splat(0);
    var blocks: [8]@import("chat_markdown.zig").Block = undefined;
    const tail = live.tailFor(1, &text, 0, &blocks, h.blocks.items, h.text.items);
    try std.testing.expectEqual(@as(usize, 0), tail.blocks);
    var seen: usize = 0;
    const wanted = std.unicode.utf8ToUtf16LeStringLiteral("Pulling the KPI counts by hand now.");
    for (h.blocks.items) |block| {
        if (block.role != .prose) continue;
        const body = h.text.items[block.start..][0..block.len];
        if (std.mem.indexOf(u16, body, wanted) != null) seen += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), seen);
}
`;

function runZigTest(name) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-live-once-'));
  try {
    copyZig(['chat_live.zig', 'chat_history.zig'], dir, path.join(root, 'src'));
    require('./fixtures/inline-stubs').writeChatMention(dir);
    fs.writeFileSync(path.join(dir, 'test.zig'), harness);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '--test-filter', name], { encoding: 'utf8', timeout: 90000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('MUBO-135 a reply first seen cut then full shows once beside its history row', () => {
  runZigTest('MUBO-135 a reply first seen cut then full shows once beside its history row');
});
