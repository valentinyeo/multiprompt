const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');
const { writeChatMention } = require('./fixtures/inline-stubs');

const root = path.join(__dirname, '..');

test('a reply containing Poteto{live-8bc7bac} yields a link span with the name and tmux target', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'soft2464-'));
  try {
    copyZig(['chat_markdown.zig', 'link_detect.zig', 'chat_markdown_unicode.zig'], dir);
    writeChatMention(dir);
    fs.writeFileSync(path.join(dir, 'probe.zig'), `const std = @import("std");
const md = @import("chat_markdown.zig");

test "reply token" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("See Poteto{live-8bc7bac} now");
    var spans: [16]md.Span = undefined;
    const n = md.inlineSpans(text, &spans);
    var name: []const u16 = &.{};
    var target: []const u16 = &.{};
    for (spans[0..n]) |span| {
        if (span.target) |hit| {
            name = text[span.text.start..span.text.end];
            target = text[hit.start..hit.end];
        }
    }
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Poteto"), name);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("live-8bc7bac"), target);
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', 'probe.zig', '--test-filter', 'reply token'], {
      cwd: dir, encoding: 'utf8', timeout: 120000,
    });
    assert.equal(result.status, 0, `signal=${result.signal || ''}\n${result.stdout || ''}${result.stderr || ''}`);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});