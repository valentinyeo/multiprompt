const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function findZig() {
  const zig = process.env.ZIG || 'zig';
  const result = spawnSync(zig, ['version'], { encoding: 'utf8' });
  return result.status === 0 && String(result.stdout).startsWith('0.16') ? zig : null;
}

function declaration(text, name) {
  const start = text.indexOf(`pub fn ${name}(`);
  assert.ok(start >= 0, name);
  return text.slice(start, text.indexOf('\n}', start) + 2);
}

const skill = read('src/chat_skill.zig');
const next = declaration(skill, 'next');
const matches = declaration(read('src/chat_complete.zig'), 'commandMatches');
const leadingOnly = next.replace(
  'if (end > start and known(text[start..end]))',
  () => "if (end > start and ((start == 0 and text[start] == '/') or text[start] == '$') and known(text[start..end]))",
);

const harness = pill => `
const std = @import("std");
const Range = struct { start: usize, end: usize };
${matches}
const catalog = [_][]const u8{ "valentin-mode", "review" };
fn known(token: []const u16) bool {
    for (catalog) |name| {
        if (commandMatches(token, name, '/') or commandMatches(token, name, '$')) return true;
    }
    return false;
}
${pill}
test "SOFT-3086 start middle and end of a message" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    for ([_][]const u16{
        w("/valentin-mode please"),
        w("how did that get in you run under /valentin-mode now"),
        w("how did that get in you run under /valentin-mode"),
        w("lead /valentin-mode then /review"),
    }) |text| {
        const at = std.mem.indexOf(u16, text, w("/valentin-mode")).?;
        const found = next(text, 0) orelse return error.MissingPill;
        try std.testing.expectEqual(at, found.start);
        try std.testing.expectEqualSlices(u16, w("/valentin-mode"), text[found.start..found.end]);
    }
    const twice = w("lead /valentin-mode then /review");
    const first = next(twice, 0) orelse return error.MissingPill;
    const second = next(twice, first.end) orelse return error.MissingPill;
    try std.testing.expectEqual(std.mem.indexOf(u16, twice, w("/review")).?, second.start);
    try std.testing.expect(next(twice, second.end) == null);
}
test "SOFT-3086 paths urls unknown words and dollar skills" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    for ([_][]const u16{ w("a/b"), w("https://example.com/valentin-mode"), w("see /valentin-mode/path"), w("see /unknown"), w("see /valentin") }) |text| {
        try std.testing.expect(next(text, 0) == null);
    }
    const dollar = w("ask $review now");
    const at = std.mem.indexOf(u16, dollar, w("$review")).?;
    const found = next(dollar, 0) orelse return error.MissingPill;
    try std.testing.expectEqual(at, found.start);
    try std.testing.expectEqualSlices(u16, w("$review"), dollar[found.start..found.end]);
}
`;

test('SOFT-3086 the composer pill range accepts a known skill at any position', t => {
  const zig = findZig();
  if (!zig) return t.skip('zig 0.16 not installed');
  assert.notEqual(leadingOnly, next);
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'skill-pill-anywhere-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const file = path.join(directory, 'pill.zig');
  fs.writeFileSync(file, harness(next));
  const after = spawnSync(zig, ['test', file, '--test-filter', 'SOFT-3086'], { encoding: 'utf8', timeout: 120_000 });
  assert.equal(after.status, 0, after.stdout + after.stderr);
  fs.writeFileSync(file, harness(leadingOnly));
  const before = spawnSync(zig, ['test', file, '--test-filter', 'SOFT-3086'], { encoding: 'utf8', timeout: 120_000 });
  assert.notEqual(before.status, 0, 'a leading-only pill range must fail the same executed oracle');
  assert.match(before.stdout + before.stderr, /FAIL/);
});

test('SOFT-3086 the sent message pill asks the same rule for every word', () => {
  const line = read('src/chat_render.zig').split('\n').find(text => text.includes('chat_skill.zig").known(text[word_start..word_end])'));
  assert.ok(line, 'the user bubble must ask the skill catalog about every word');
  assert.match(line, /if \(skill_pills and /);
  assert.doesNotMatch(line, /word_start == 0|text\[word_start\] != '\/'/, 'a sent message must highlight a known skill at any position');
});
