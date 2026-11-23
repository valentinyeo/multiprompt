const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');

const root = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('MUBO-237 fixture message fails raw rendering and passes quote block layout and folding', () => {
  const skillQuote = read('tools/fixtures/MUBO-237/user-quote-message.txt').trimEnd();
  const pastedQuote = read('tools/fixtures/MUBO-237/pasted-quote-message.txt').trimEnd();
  assert.match(skillQuote, /^\/pstack:poteto-help > \*\*The fix itself is small/);
  assert.match(skillQuote, /\n>\n> How the hours went:/);
  assert.match(pastedQuote, /^> \*\*The fix itself is small/);

  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mubo-237-'));
  try {
    copyZig(['chat_user_quote.zig'], dir);
    const harness = `
const std = @import("std");
const md = @import("chat_markdown.zig");
const quote = @import("chat_user_quote.zig");

const Fixed = struct {
    char_w: i32 = 8,
    line_h: i32 = 20,

    fn cell(self: *const Fixed, text: []const u16, _: md.Style, level: u3) quote.Size {
        return .{
            .width = @as(i32, @intCast(text.len)) * self.char_w,
            .height = self.line_h + (if (level > 0) @as(i32, 4) else 0),
        };
    }
};

fn expectCleanQuoteFixture(raw_utf8: []const u8, expect_prefix: []const u8, expect_suffix_prefix: []const u8) !void {
    const a = std.testing.allocator;
    const raw = try std.unicode.utf8ToUtf16LeAlloc(a, raw_utf8);
    defer a.free(raw);
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    try std.testing.expect(std.mem.indexOf(u16, raw, w("> ")) != null);
    try std.testing.expect(std.mem.indexOf(u16, raw, w("**")) != null);

    const parts = quote.parse(raw) orelse return error.TestUnexpectedResult;
    const prefix = try std.unicode.utf16LeToUtf8Alloc(a, raw[parts.prefix.start..parts.prefix.end]);
    defer a.free(prefix);
    try std.testing.expectEqualStrings(expect_prefix, prefix);
    const suffix = try std.unicode.utf16LeToUtf8Alloc(a, raw[parts.suffix.start..parts.suffix.end]);
    defer a.free(suffix);
    try std.testing.expect(std.mem.startsWith(u8, suffix, expect_suffix_prefix));

    var unq = try quote.unquote(a, raw, parts.quote);
    defer unq.deinit(a);
    const fixed = Fixed{};
    const metrics = quote.Metrics{ .line_h = 20, .toggle_h = 18, .para_gap = 6, .list_indent = 22, .list_marker_w = 26, .toggle_gap = 4 };

    var folded = try quote.layout(a, unq.text, 480, metrics, false, &fixed, Fixed.cell);
    defer folded.deinit(a);
    try std.testing.expect(folded.foldable);
    try std.testing.expectEqual(@as(usize, 3), folded.visible_lines);
    try std.testing.expect(folded.lines[2].ellipsis_x != null);
    try std.testing.expect(folded.toggle_rect != null);
    try std.testing.expectEqual(folded.lines[2].y + folded.lines[2].height, folded.content_h);

    var expanded = try quote.layout(a, unq.text, 480, metrics, true, &fixed, Fixed.cell);
    defer expanded.deinit(a);
    try std.testing.expectEqual(expanded.total_lines, expanded.visible_lines);
    try std.testing.expect(expanded.visible_lines > 3);
    try std.testing.expect(expanded.total_h > folded.total_h);

    var bold_count: usize = 0;
    var list_count: usize = 0;
    for (expanded.lines[0..expanded.visible_lines]) |line| {
        if (line.marker != null) list_count += 1;
        for (expanded.runs[line.first_run..][0..line.run_count]) |run| {
            const slice = unq.text[run.text.start..run.text.end];
            try std.testing.expect(std.mem.indexOf(u16, slice, w("**")) == null);
            try std.testing.expect(slice.len == 0 or slice[0] != '>');
            if (run.style.bold) bold_count += 1;
        }
    }
    try std.testing.expect(bold_count >= 4);
    try std.testing.expectEqual(@as(usize, 3), list_count);
}

test "MUBO-237 real fixtures render clean folded and expanded quote blocks" {
    try expectCleanQuoteFixture(${JSON.stringify(skillQuote)}, "/pstack:poteto-help", "i thoughtwith pstack");
    try expectCleanQuoteFixture(${JSON.stringify(pastedQuote)}, "", "i thought with pstack");
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    var preview: [256]u16 = undefined;
    const n = quote.formatReplyPreview(w("**The fix itself is small. The time goes into waiting and checks around it.**"), &preview);
    try std.testing.expect(std.mem.indexOf(u16, preview[0..n], w("**")) == null);
    try std.testing.expectEqualSlices(u16, w("\\u{21a9} The fix itself is small. The time goes into waiting and checks around it."), preview[0..n]);
}
`;
    fs.writeFileSync(path.join(dir, 'fixture_test.zig'), harness);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', '-j1', path.join(dir, 'fixture_test.zig')], { encoding: 'utf8', timeout: 60000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('MUBO-237 chat_render and chat_composer wire user quotes reply preview stripping and scroll-preserving toggles', () => {
  const render = read('src/chat_render.zig');
  const quoteUi = read('src/chat_user_quote_ui.zig');
  const composer = read('src/chat_composer.zig');
  assert.match(render, /chat_user_quote\.zig"\)\.formatReplyPreview/);
  assert.match(render, /chat_user_quote_ui\.zig"\)\.measureNaturalWidth/);
  assert.match(render, /chat_user_quote_ui\.zig"\)\.measureHeight/);
  assert.match(render, /chat_user_quote_ui\.zig"\)\.paint/);
  assert.match(render, /chat_user_quote_ui\.zig"\)\.handleClick/);
  assert.match(render, /chat_user_quote_ui\.zig"\)\.toggleAt/);
  assert.match(render, /chat_user_quote_ui\.zig"\)\.linkAt/);
  assert.match(render, /chat_user_quote_ui\.zig"\)\.charAt/);
  assert.match(composer, /chat_user_quote\.zig"\)\.stripInlineMarkdown/);
  assert.match(quoteUi, /chat_session\.chatRelayoutPreservingScroll/);
});
