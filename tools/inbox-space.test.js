const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

test('IGSH-1688 actual Inbox layout fills the area above its footer at every scale', () => {
  const source = fs.readFileSync(path.join(__dirname, '../src/inbox.zig'), 'utf8');
  const drawing = fs.readFileSync(path.join(__dirname, '../src/drawing.zig'), 'utf8');
  const extract = (text, start, end) => {
    const first = text.indexOf(start), last = text.indexOf(end, first + start.length);
    assert.ok(first >= 0 && last > first);
    return text.slice(first, last);
  };
  const layout = extract(source, 'const InboxLayout = struct {', 'const InboxNameBounds = struct {');
  const calculate = extract(source, 'fn inboxLayout(', 'pub fn inboxMouseClick(');
  const scale = extract(drawing, 'pub fn uiScaled(', 'pub fn uiUnscaled(');
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'inbox-space-'));
  try {
    fs.writeFileSync(path.join(directory, 'proof.zig'), `const std = @import("std");
const app_state = struct {
    var g_ui_scale: u32 = 100;
    var g_inbox_sel: u32 = 0;
    var g_inbox_filter_active: bool = false;
    var dpi: u32 = 96;
};
fn mainWindowDpi() u32 { return app_state.dpi; }
${scale}
${layout}
${calculate}
test "existing Inbox rows fully use the area above the footer" {
    const screenshot = inboxLayout(1920, 1032);
    try std.testing.expectEqual(@as(u32, 16), screenshot.max_rows);
    try std.testing.expectEqual(@as(i32, 72), screenshot.top);
    try std.testing.expectEqual(@as(i32, 56), screenshot.row_height);
    try std.testing.expectEqual(@as(i32, 58), screenshot.stride);
    for ([_]u32{ 75, 100, 125, 150 }) |ui_scale| {
        app_state.g_ui_scale = ui_scale;
        for ([_]u32{ 96, 144, 192 }) |dpi| {
            app_state.dpi = dpi;
            for ([_]bool{ false, true }) |search| {
                app_state.g_inbox_filter_active = search;
                for ([_]u32{ 0, 15, 50 }) |selection| {
                    app_state.g_inbox_sel = selection;
                    var height: i32 = 32;
                    while (height <= 1600) : (height += 1) {
                        const value = inboxLayout(1920, height);
                        const bottom = height - uiScaled(30);
                        if (value.max_rows == 0) {
                            try std.testing.expect(value.top + value.row_height > bottom);
                            try std.testing.expectEqual(@as(u32, 0), value.scroll);
                        } else {
                            const last = value.top + @as(i32, @intCast(value.max_rows - 1)) * value.stride;
                            try std.testing.expect(last + value.row_height <= bottom);
                            try std.testing.expect(last + value.stride + value.row_height > bottom);
                            try std.testing.expect(selection >= value.scroll and selection < value.scroll + value.max_rows);
                        }
                    }
                }
            }
        }
    }
    std.debug.print("IGSH1688_INBOX_SPACE_GEOMETRY_PROVEN\\n", .{});
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', 'proof.zig'], { cwd: directory, encoding: 'utf8', timeout: 120000 });
    const output = (result.stdout || '') + (result.stderr || '');
    assert.equal(result.status, 0, output);
    assert.match(output, /IGSH1688_INBOX_SPACE_GEOMETRY_PROVEN/);
    process.stdout.write(output);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
