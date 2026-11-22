const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const read = (file) => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');

test('IGSH-1754 last batch time uses shared history and render hooks', () => {
  const history = read('src/chat_history.zig');
  assert.match(history, /pub fn lastBatchStart\(blocks: \[\]const md\.Block\) BatchBoundary/);
  assert.match(history, /pub fn formatBatchTimeLabel/);
  assert.match(history, /if \(last_user\) idx else/);
  assert.match(history, /test "IGSH-1754 last batch starts on the latest reply run after the last user message"/);
  const render = read('src/chat_render.zig');
  assert.match(render, /fn chatPaintBatchDivider/);
  assert.match(render, /chat_history\.lastBatchStart/);
  assert.match(render, /if \(app_state\.g_chat_batch_boundary\.index == i\)/);
  assert.match(render, /g_chat_batch_divider_y = y/);
  assert.match(render, /chatPaintBatchDivider\(mem_dc, w\)/);
  const batchPaint = render.slice(render.indexOf('fn chatPaintBatchDivider'), render.indexOf('fn chatPaintNavRing'));
  assert.doesNotMatch(batchPaint, /FillRect/);
  assert.match(read('src/app_state.zig'), /g_chat_batch_boundary: chat_history\.BatchBoundary/);
  assert.match(read('src/chat_layout_snapshot.zig'), /batch_divider_y/);
});

test('IGSH-1754 layout reserves a metadata row above the batch and stacks under New', () => {
  const { copyZig } = require('./zig-copy');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh-1754-batch-'));
  try {
    copyZig(['chat_echo.zig', 'chat_markdown.zig'], dir);
    const history = read('src/chat_history.zig');
    const batchFns =
      'pub const BatchBoundary = struct { index: ?usize = null, stamp_ms: i64 = 0 };\n' +
      history.slice(history.indexOf('fn batchMessageStart'), history.indexOf('pub fn unreadBoundary'));
    const source = `const std = @import("std");
const md = @import("chat_markdown.zig");
const chat_history = struct {
${batchFns}
};
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
const RECT = struct { left: i32 = 0, top: i32 = 0, right: i32 = 0, bottom: i32 = 0 };
var g_chat_read_boundary: ReadBoundary = .{ .index = 1 };
var g_chat_batch_boundary: chat_history.BatchBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_batch_divider_y: i32 = 0;
var g_chat_block_count: usize = 0;
var g_chat_layout_reuse: usize = 0;
var g_chat_layout_rects: [8]RECT = @splat(.{});
var g_chat_blocks: [8]md.Block = undefined;
var g_chat_content_h: i32 = 0;
fn uiScaled(v: i32) i32 { return v; }
fn chatReadBoundary() ReadBoundary { return g_chat_read_boundary; }
fn chatRelayout() void {
    g_chat_batch_boundary = chat_history.lastBatchStart(g_chat_blocks[0..g_chat_block_count]);
    var y: i32 = 0;
    const boundary = chatReadBoundary();
    for (0..g_chat_block_count) |i| {
        if (boundary.index == i) { g_chat_read_divider_y = y; y += uiScaled(28); }
        if (g_chat_batch_boundary.index == i) { g_chat_batch_divider_y = y; y += uiScaled(28); }
        g_chat_layout_rects[i] = .{ .top = y, .bottom = y + 40 };
        y += 44;
    }
    g_chat_content_h = y;
    g_chat_layout_reuse = g_chat_block_count;
}
test "same index stacks batch under New" {
    g_chat_blocks[0] = .{ .start = 0, .len = 1, .role = .prose, .first = true, .stamp_ms = 1 };
    g_chat_blocks[1] = .{ .start = 1, .len = 1, .role = .user, .first = true, .stamp_ms = 2 };
    g_chat_blocks[2] = .{ .start = 2, .len = 1, .role = .prose, .first = true, .stamp_ms = 3 };
    g_chat_block_count = 3;
    g_chat_read_boundary = .{ .index = 2 };
    chatRelayout();
    try std.testing.expectEqual(@as(?usize, 2), g_chat_batch_boundary.index);
    try std.testing.expectEqual(@as(i32, 88), g_chat_read_divider_y);
    try std.testing.expectEqual(g_chat_read_divider_y + 28, g_chat_batch_divider_y);
    try std.testing.expectEqual(g_chat_batch_divider_y + 28, g_chat_layout_rects[2].top);
}
`;
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, source);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
