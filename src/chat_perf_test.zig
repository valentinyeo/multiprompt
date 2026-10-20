const std = @import("std");
const history = @import("chat_history.zig");
const transcript = @import("chat_transcript.zig");
const echo = @import("chat_echo.zig");
const md = @import("chat_markdown.zig");

fn now() std.Io.Timestamp {
    return std.Io.Clock.awake.now(std.testing.io);
}
fn ms(start: std.Io.Timestamp) i64 {
    return @intCast(start.durationTo(now()).toMilliseconds());
}

test "CPU707 synthetic 50 MB parse, incremental append and reconcile budgets" {
    const a = std.heap.page_allocator;
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    try wire.appendSlice(a, "@mp\t1\thistory\tok\tsid\t0\t52428800\t9\t0\tclaude\tterm-1\n");
    const padding = try a.alloc(u8, 1900);
    defer a.free(padding);
    @memset(padding, 'x');
    const row = try std.fmt.allocPrint(a, "{{\"role\":\"user\",\"timestamp\":\"2026-10-03T12:34:00Z\",\"text\":\"{s}\"}}\n", .{padding});
    defer a.free(row);
    var messages: usize = 0;
    while (wire.items.len < 50 * 1024 * 1024) : (messages += 1) try wire.appendSlice(a, row);
    try wire.appendSlice(a, "@@MP_END@@\n");
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "");
    var h: history.History = .{};
    defer h.deinit(a);
    const parse_start = now();
    try h.apply(a, wire.items, 1, key);
    const parse_ms = ms(parse_start);
    try std.testing.expectEqual(messages, h.blocks.items.len);
    try std.testing.expect(h.rows.items.len >= 50 * 1024 * 1024 - 256);
    try std.testing.expect(parse_ms < 3000);

    const delta_start = now();
    var suffix = try h.suffix(a);
    defer suffix.deinit(a);
    try std.testing.expectEqual(row.len, suffix.rows.items.len);
    try suffix.apply(a, "@mp\t2\thistory\tok\tsid\t52428800\t52428900\t9\t0\tclaude\tterm-1\n{\"role\":\"user\",\"text\":\"new prompt\"}\n@@MP_END@@\n", 2, key);
    try h.appendParsed(a, &suffix);
    const delta_ms = ms(delta_start);
    try std.testing.expectEqual(messages + 1, h.blocks.items.len);
    try std.testing.expectEqual(messages - 1, h.changed_from);
    try std.testing.expect(delta_ms < 100);

    const users = try a.alloc(echo.UserBlock, h.blocks.items.len);
    defer a.free(users);
    for (h.blocks.items, 0..) |b, i| users[i] = .{ .text = h.text.items[b.start..][0..b.len], .stamp_ms = b.stamp_ms };
    var pending: [20]echo.Pending = @splat(.{ .prefix = std.unicode.utf8ToUtf16LeStringLiteral("new prompt"), .text = std.unicode.utf8ToUtf16LeStringLiteral("new prompt"), .anchor = .{ .counted = true } });
    var picked: [20]?usize = undefined;
    const reconcile_start = now();
    echo.assign(&pending, users, false, &.{}, &picked);
    try std.testing.expectEqual(@as(?usize, messages), picked[0]);
    for (picked[1..]) |p| try std.testing.expect(p == null);
    try std.testing.expectEqual(@as(?usize, messages), echo.represented(pending[0].text, users));
    const reconcile_ms = ms(reconcile_start);
    try std.testing.expect(reconcile_ms < 1000);
    std.debug.print("CPU707 benchmark bytes={d} messages={d} parse_ms={d} delta_ms={d} reconcile_ms={d}\n", .{ wire.items.len, messages, parse_ms, delta_ms, reconcile_ms });
}

test "CPU707 bounded cache and tail/older paging preserve complete accessible history" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "");
    var h: history.History = .{};
    defer h.deinit(a);
    const probe = "a" ** 64;
    try h.apply(a, "@mp\t1\thistory\tok\tsid\t50000000\t52428800\t9\t0\tclaude\tterm-1\t1\t" ++ probe ++ "\ttail\t50000000\n{\"role\":\"assistant\",\"id\":\"one\",\"text\":\"latest reply\"}\n@@MP_END@@\n", 1, key);
    try std.testing.expectEqual(@as(u64, 50000000), h.start);
    try std.testing.expect(!h.more and !h.restore_full);
    try h.apply(a, "@mp\t2\thistory\tok\tsid\t49000000\t50000000\t9\t0\tclaude\tterm-1\t1\t" ++ probe ++ "\tolder\t49000000\n{\"role\":\"user\",\"text\":\"older prompt\"}\n@@MP_END@@\n", 2, key);
    try std.testing.expectEqual(@as(u64, 52428800), h.offset);
    try std.testing.expectEqual(@as(u64, 49000000), h.start);
    try std.testing.expectEqual(@as(usize, 2), h.blocks.items.len);
    const bytes = try h.encode(a, key);
    defer a.free(bytes);
    try std.testing.expect(bytes.len <= history.TAIL_BYTES);
    var restored = try history.History.decode(a, bytes, key);
    defer restored.deinit(a);
    try std.testing.expectEqualSlices(u16, h.text.items, restored.text.items);
    try std.testing.expectEqual(h.start, restored.start);
    const revision = h.revision;
    try h.apply(a, "@mp\t3\thistory\tok\tsid\t52428800\t52428800\t9\t0\tclaude\tterm-1\t1\t" ++ probe ++ "\tdelta\t49000000\n@@MP_END@@\n", 3, key);
    try std.testing.expectEqual(revision, h.revision);
    const previous_text = h.text.items.ptr;
    try std.testing.expectError(error.InvalidHistory, h.apply(a, "@mp\t4\thistory\tok\tsid\t1\t2\t10\t0\tclaude\tterm-1\t1\t" ++ probe ++ "\tolder\t1\n@@MP_END@@\n", 4, key));
    try std.testing.expectEqual(previous_text, h.text.items.ptr);
}

test "CPU707 table layout is cached across paints and invalidated by width/content" {
    const a = std.testing.allocator;
    var cache: md.TableCache = .{};
    defer cache.deinit(a);
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| A | B |\n|---|---|\n| x | y |");
    var key = md.TableKey{ .view_w = 80, .font_pt = 13, .scale = 1024, .pad_x = 8, .pad_y = 4 };
    const Measure = struct {
        fn cell(_: void, cell_text: []const u16, _: bool) md.TableSize {
            return .{ .width = @intCast(cell_text.len * 8), .height = 20 };
        }
    };
    const first = try cache.layout(a, text, 1, key, {}, Measure.cell);
    const ptr = first.widths.ptr;
    for (0..1000) |_| try std.testing.expectEqual(ptr, (try cache.layout(a, text, 1, key, {}, Measure.cell)).widths.ptr);
    try std.testing.expectEqual(@as(usize, 1), cache.builds);
    _ = try cache.layout(a, text, 2, key, {}, Measure.cell);
    key.view_w = 40;
    _ = try cache.layout(a, text, 1, key, {}, Measure.cell);
    try std.testing.expectEqual(@as(usize, 3), cache.builds);
    cache.clearFrom(a, 2);
    try std.testing.expectEqual(@as(u32, 1), cache.entries.count());
    _ = try cache.layout(a, text, 1, key, {}, Measure.cell);
    try std.testing.expectEqual(@as(usize, 3), cache.builds);
    cache.clear(a);
    _ = try cache.layout(a, text, 1, key, {}, Measure.cell);
    try std.testing.expectEqual(@as(usize, 4), cache.builds);
}

test "ISSUE-421 layout cache invalidates same-length text font and scale and keeps row positions" {
    const a = std.testing.allocator;
    var cache: md.TableCache = .{};
    defer cache.deinit(a);
    const Measure = struct {
        fn cell(_: void, text: []const u16, bold: bool) md.TableSize {
            return .{ .width = @as(i32, @intCast(text.len)) * (if (bold) @as(i32, 9) else 8), .height = 20 };
        }
    };
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| A | B |\n|---|---|\n| x | y |");
    const other = std.unicode.utf8ToUtf16LeStringLiteral("| W | B |\n|---|---|\n| x | y |");
    var key = md.TableKey{ .view_w = 20, .font_pt = 13, .scale = 1024, .pad_x = 8, .pad_y = 4 };
    const first = try cache.layout(a, text, 7, key, {}, Measure.cell);
    try std.testing.expectEqual(@as(i32, 53), first.content_w);
    try std.testing.expectEqual(@as(i32, 0), first.rowY(2));
    try std.testing.expectEqual(@as(i32, 29), first.rowY(text.len - 3));
    first.scroll = 30;
    _ = try cache.layout(a, other, 7, key, {}, Measure.cell);
    key.font_pt += 1;
    _ = try cache.layout(a, other, 7, key, {}, Measure.cell);
    key.scale += 1;
    _ = try cache.layout(a, other, 7, key, {}, Measure.cell);
    try std.testing.expectEqual(@as(usize, 4), cache.builds);
    key.view_w = 100;
    const last = try cache.layout(a, other, 7, key, {}, Measure.cell);
    try std.testing.expectEqual(@as(i32, 0), last.scroll);
    try std.testing.expectEqual(@as(usize, 5), cache.builds);
}
