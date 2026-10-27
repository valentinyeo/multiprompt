const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const fixtures = String.raw`
test "IGSH-1047 section headings above a yes-no question are never answers" {
    var group: Group = .{};
    const chunks = [_]Chunk{
        .{ .text = w("1. What a pro would add\nA shared build check catches broken releases.") },
        .{ .text = w("2. Raw material\nStart from build logs and the failing run.") },
        .{ .text = w("Should I file a ticket for this?") },
    };
    try std.testing.expect(!parseReply(&chunks, &group));
}

test "IGSH-1047 a later question cannot inherit earlier choices or their body text" {
    var group: Group = .{};
    const chunks = [_]Chunk{.{ .text = w("Which approach?\nA. First approach. Earlier detail.\nB. Second approach. More old detail.\nShould I file a ticket instead?") }};
    try std.testing.expect(!parseReply(&chunks, &group));
}

test "IGSH-1047 real lettered choices keep only their exact titles and subtitles" {
    var group: Group = .{};
    const chunks = [_]Chunk{
        .{ .text = w("1. Findings\nUnrelated body text.") },
        .{ .text = w("2. Evidence\nMore unrelated body text.") },
        .{ .text = w("Which approach should we use?") },
        .{ .text = w("A. **Repair now**. Keep current behavior.\n  Use the smallest patch.") },
        .{ .text = w("B. **Wait for evidence**. Collect a trace.\nMy recommendation is A.") },
    };
    try std.testing.expect(parseReply(&chunks, &group));
    try std.testing.expectEqual(@as(usize, 2), group.count);
    try expectUtf16("Repair now", group.options[0].titleSlice());
    try expectUtf16(". Keep current behavior. Use the smallest patch.", group.options[0].detailSlice());
    try expectUtf16("Wait for evidence", group.options[1].titleSlice());
    try expectUtf16(". Collect a trace.", group.options[1].detailSlice());
    var answer: [TITLE_MAX + 8]u16 = undefined;
    const n = answerLen(&group.options[1], &answer);
    try expectUtf16("B: Wait for evidence", answer[0..n]);
}

test "IGSH-1047 numbered choices require an adjacent question or choice invitation" {
    var group: Group = .{};
    const bare = [_]Chunk{.{ .text = w("1. Findings\n2. Evidence") }};
    try std.testing.expect(!parseReply(&bare, &group));
    const separated = [_]Chunk{.{ .text = w("Which approach?\nUnrelated explanation.\n1. Findings\n2. Evidence") }};
    try std.testing.expect(!parseReply(&separated, &group));
    const options = [_]Chunk{.{ .text = w("Pick one:\n1. Keep current behavior. No migration.\n2. Replace the parser. Needs testing.") }};
    try std.testing.expect(parseReply(&options, &group));
    try std.testing.expectEqual(@as(usize, 2), group.count);
    try expectUtf16("Keep current behavior", group.options[0].titleSlice());
    try expectUtf16("No migration.", group.options[0].detailSlice());
    try expectUtf16("Replace the parser", group.options[1].titleSlice());
    try expectUtf16("Needs testing.", group.options[1].detailSlice());
}
`;

test('IGSH-1047 real parser binds exact card text to the current question', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-options-'));
  try {
    const source = process.env.IGSH_1047_SOURCE || path.join(__dirname, '..', 'src', 'chat_options.zig');
    const file = path.join(dir, 'options.zig');
    fs.writeFileSync(file, fs.readFileSync(source, 'utf8') + fixtures);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', '-j1', file, '--test-filter', 'IGSH-1047'], {
      encoding: 'utf8', timeout: 120000,
    });
    assert.equal(result.status, 0, `${result.error || result.signal || ''}${result.stdout || ''}${result.stderr || ''}`);
    assert.match(result.stderr, /All 4 tests passed\./);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
