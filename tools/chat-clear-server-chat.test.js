const { copyZig } = require('./zig-copy');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const source = String.raw`
const std = @import("std");
const history = @import("chat_history.zig");
const transcript = @import("chat_transcript.zig");

const before =
    "@mp\t1\thistory\tok\tsid\t0\t200\t9\t0\tclaude\tremote-tab\t0\t\ttail\t0\n" ++
    "{\"role\":\"user\",\"id\":\"before\",\"text\":\"old question\",\"offset\":0,\"end\":100}\n" ++
    "{\"role\":\"assistant\",\"id\":\"old-answer\",\"text\":\"old answer\",\"offset\":100,\"end\":200}\n@@MP_END@@\n";

test "a cleared server chat shows only the messages after the clear" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(2528, 2, false, "remote-tab", "");
    var h: history.History = .{};
    defer h.deinit(a);
    try h.apply(a, before, 1, key);
    try h.apply(a,
        "@mp\t2\thistory\tok\tsid\t0\t200\t10\t0\tclaude\tremote-tab\t0\t\ttail\t0\n" ++
        "{\"role\":\"user\",\"id\":\"new-question\",\"text\":\"new question\",\"offset\":0,\"end\":100}\n" ++
        "{\"role\":\"assistant\",\"id\":\"new-answer\",\"text\":\"new answer\",\"offset\":100,\"end\":200}\n@@MP_END@@\n", 2, key);
    try std.testing.expectEqual(@as(usize, 2), h.blocks.items.len);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("new questionnew answer"), h.text.items);
    const encoded = try h.encode(a, key);
    defer a.free(encoded);
    var restored = try history.History.decode(a, encoded, key);
    defer restored.deinit(a);
    try std.testing.expectEqual(@as(usize, 2), restored.blocks.items.len);
}

test "a server chat keeps a replaced transcript that still carries its messages" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(2529, 2, false, "remote-tab", "");
    var h: history.History = .{};
    defer h.deinit(a);
    try h.apply(a, before, 1, key);
    try h.apply(a,
        "@mp\t2\thistory\tok\tsid\t100\t300\t10\t0\tclaude\tremote-tab\t0\t\ttail\t100\n" ++
        "{\"role\":\"assistant\",\"id\":\"old-answer\",\"text\":\"old answer\",\"offset\":100,\"end\":200}\n" ++
        "{\"role\":\"assistant\",\"id\":\"new-answer\",\"text\":\"new answer\",\"offset\":200,\"end\":300}\n@@MP_END@@\n", 2, key);
    try std.testing.expectEqual(@as(usize, 3), h.blocks.items.len);
}

test "a local chat keeps a replaced transcript" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(2530, 0, false, "remote-tab", "");
    var h: history.History = .{};
    defer h.deinit(a);
    try h.apply(a, before, 1, key);
    try h.apply(a,
        "@mp\t2\thistory\tok\tsid\t0\t200\t10\t0\tclaude\tremote-tab\t0\t\ttail\t0\n" ++
        "{\"role\":\"user\",\"id\":\"new-question\",\"text\":\"new question\",\"offset\":0,\"end\":100}\n" ++
        "{\"role\":\"assistant\",\"id\":\"new-answer\",\"text\":\"new answer\",\"offset\":100,\"end\":200}\n@@MP_END@@\n", 2, key);
    try std.testing.expectEqual(@as(usize, 4), h.blocks.items.len);
}
`;

test('a cleared server chat keeps only its new messages', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-clear-server-chat-'));
  try {
    copyZig(['chat_history.zig'], dir);
    fs.writeFileSync(path.join(dir, 'clear-test.zig'), source);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'clear-test.zig')], { encoding: 'utf8', timeout: 180000 });
    assert.equal(result.status, 0, `${result.stdout}${result.stderr}\nsignal=${result.signal} error=${result.error || ''}`);
    assert.match(result.stderr, /All \d+ tests passed/);
    for (const name of [
      'a cleared server chat shows only the messages after the clear',
      'a server chat keeps a replaced transcript that still carries its messages',
      'a local chat keeps a replaced transcript',
    ]) assert.match(result.stderr, new RegExp(`${name}\\.\\.\\.OK`), name);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
