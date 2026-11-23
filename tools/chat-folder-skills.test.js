const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');

test('SOFT-3102 slash typos find folder skills and exact prefixes rank first', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'folder-skills-'));
  try {
    copyZig(['chat_complete.zig'], dir);
    const program = `const std = @import("std");
const complete = @import("chat_complete.zig");
test "folder skills tolerate one edit including transposition" {
    const names = [_][]const u8{ "verify-multiprompt", "verify-chat-still", "verify-server", "plugin:verify-app" };
    for (names) |name| {
        for ([_][]const u8{ "verfiy", "verfy", "verxify", "verigy", "VERIFY" }) |query| {
            try std.testing.expect(complete.score(name, "", query) != null);
        }
        try std.testing.expect(complete.score(name, "", "zxqwy") == null);
        try std.testing.expect(complete.score(name, "", "vfiy") == null);
    }
    try std.testing.expect(complete.score("copy", "", "cpo") == null);
}
test "exact prefixes beat typo matches even with recent picks" {
    const entries = [_]complete.Entry{
        .{ .kind = 'J', .name = "verify-multiprompt", .hint = "", .desc = "" },
        .{ .kind = 'J', .name = "verify-chat-still", .hint = "", .desc = "" },
        .{ .kind = 'S', .name = "verfiy-custom", .hint = "", .desc = "" },
        .{ .kind = 'B', .name = "copy", .hint = "", .desc = "" },
    };
    var order: [4]u16 = undefined;
    const n = complete.rank(&entries, "verfiy", &.{"verify-multiprompt"}, &order);
    try std.testing.expectEqual(@as(usize, 3), n);
    try std.testing.expectEqualStrings("verfiy-custom", entries[order[0]].name);
    try std.testing.expectEqualStrings("verify-multiprompt", entries[order[1]].name);
    const exact = complete.rank(&entries, "verify", &.{"verfiy-custom"}, &order);
    try std.testing.expectEqual(@as(usize, 3), exact);
    try std.testing.expectEqualStrings("verify-chat-still", entries[order[0]].name);
    try std.testing.expectEqualStrings("verify-multiprompt", entries[order[1]].name);
    try std.testing.expectEqualStrings("verfiy-custom", entries[order[2]].name);
    var insertion: [64]u8 = undefined;
    try std.testing.expectEqualStrings("/verify-multiprompt ", complete.insertionFor(.claude, .slash, entries[order[1]], &insertion));
}
`;
    fs.writeFileSync(path.join(dir, 'test.zig'), program);
    const module = path.join(dir, 'chat_complete.zig');
    const source = fs.readFileSync(module, 'utf8');
    const legacy = fs.readFileSync(path.join(__dirname, 'fixtures/SOFT-3102/score.zig'), 'utf8');
    const start = source.indexOf('pub fn score(');
    const end = source.indexOf('\nfn recent(', start);
    assert.ok(start >= 0 && end > start);
    for (const broken of [true, false]) {
      fs.writeFileSync(module, broken ? source.slice(0, start) + legacy + source.slice(end) : source);
      const run = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig')], { encoding: 'utf8', timeout: 60000 });
      assert.ifError(run.error);
      if (broken) {
        assert.equal(run.status, 1, `${run.signal || ''}\n${run.stdout}${run.stderr}`);
        assert.match(run.stderr, /folder skills tolerate one edit including transposition[^]*FAIL \(TestUnexpectedResult\)/);
        assert.match(run.stderr, /expected 3, found 1/);
      } else {
        assert.equal(run.status, 0, `${run.signal || ''}\n${run.stdout}${run.stderr}`);
      }
    }
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
