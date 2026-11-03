const std = @import("std");
const history = @import("chat_history.zig");
const transcript = @import("chat_transcript.zig");
const echo = @import("chat_echo.zig");
const md = @import("chat_markdown.zig");

fn now() std.Io.Timestamp {
    return std.Io.Clock.cpu_thread.now(std.testing.io);
}
fn ms(start: std.Io.Timestamp) i64 {
    return @intCast(start.durationTo(now()).toMilliseconds());
}

test "CPU707 synthetic 50 MB parse, incremental append and reconcile budgets" {
    const report = struct {
        const Delta = struct { cpu_ms: i64, wall_ms: i64 };
        fn peakRssKb() ?u64 {
            if (@import("builtin").os.tag != .linux) return null;
            const kb: u64 = @intCast(std.posix.getrusage(std.posix.rusage.SELF).maxrss);
            return kb;
        }
        fn stage(comptime name: []const u8) void {
            std.debug.print("CPU707 stage {s} peak_rss_kb={d}\n", .{ name, peakRssKb() orelse 0 });
        }
        fn checked(comptime what: []const u8, result: anytype) @TypeOf(result) {
            return result catch |err| {
                std.debug.print("CPU707 {s} failed: {s} peak_rss_kb={d} mode={s}\n", .{ what, @errorName(err), peakRssKb() orelse 0, @tagName(@import("builtin").mode) });
                return err;
            };
        }
        fn appendDelta(a: std.mem.Allocator, target: *history.History, key: transcript.Identity, row_len: usize) !Delta {
            const wall_start = std.Io.Clock.awake.now(std.testing.io);
            const cpu_start = now();
            var suffix = try target.suffix(a);
            defer suffix.deinit(a);
            std.debug.print("CPU707 suffix rows={d} expected_rows={d} peak_rss_kb={d}\n", .{ suffix.rows.items.len, row_len, peakRssKb() orelse 0 });
            try std.testing.expectEqual(row_len, suffix.rows.items.len);
            try suffix.apply(a, "@mp\t2\thistory\tok\tsid\t52428800\t52428900\t9\t0\tclaude\tterm-1\n{\"role\":\"user\",\"text\":\"new prompt\"}\n@@MP_END@@\n", 2, key);
            try target.appendParsed(a, &suffix);
            return .{ .cpu_ms = ms(cpu_start), .wall_ms = wall_start.durationTo(std.Io.Clock.awake.now(std.testing.io)).toMilliseconds() };
        }
    };
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
    while (wire.items.len < 50 * 1024 * 1024) : (messages += 1) try report.checked("build wire", wire.appendSlice(a, row));
    try report.checked("close wire", wire.appendSlice(a, "@@MP_END@@\n"));
    report.stage("wire built");
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "");
    var h: history.History = .{};
    defer h.deinit(a);
    const parse_wall_start = std.Io.Clock.awake.now(std.testing.io);
    const parse_start = now();
    try report.checked("parse", h.apply(a, wire.items, 1, key));
    const parse_ms = ms(parse_start);
    const parse_wall_ms = parse_wall_start.durationTo(std.Io.Clock.awake.now(std.testing.io)).toMilliseconds();
    const parse_peak_kb = report.peakRssKb() orelse 0;
    report.stage("parsed");
    std.debug.print("CPU707 parse rows={d} blocks={d} messages={d} parse_cpu_ms={d} parse_wall_ms={d} peak_rss_kb={d}\n", .{ h.rows.items.len, h.blocks.items.len, messages, parse_ms, parse_wall_ms, parse_peak_kb });
    try std.testing.expectEqual(messages, h.blocks.items.len);
    try std.testing.expect(h.rows.items.len >= 50 * 1024 * 1024 - 256);
    try std.testing.expect(parse_ms < 3000);
    try std.testing.expect(parse_peak_kb < 1024 * 1024);

    var delta_cpu_trials: [3]i64 = undefined;
    var delta_wall_trials: [3]i64 = undefined;
    for (&delta_cpu_trials, &delta_wall_trials, 0..) |*cpu, *wall, trial| {
        if (trial == delta_cpu_trials.len - 1) {
            const measured = try report.checked("append delta", report.appendDelta(a, &h, key, row.len));
            cpu.* = measured.cpu_ms;
            wall.* = measured.wall_ms;
            continue;
        }
        var copy = try report.checked("clone history", h.clone(a));
        defer copy.deinit(a);
        const measured = try report.checked("append delta", report.appendDelta(a, &copy, key, row.len));
        cpu.* = measured.cpu_ms;
        wall.* = measured.wall_ms;
    }
    const delta_ms = @min(delta_cpu_trials[0], @min(delta_cpu_trials[1], delta_cpu_trials[2]));
    std.debug.print("CPU707 delta cpu_ms={d}/{d}/{d} wall_ms={d}/{d}/{d} best_cpu_ms={d} budget_ms=100 blocks={d} changed_from={d} peak_rss_kb={d}\n", .{ delta_cpu_trials[0], delta_cpu_trials[1], delta_cpu_trials[2], delta_wall_trials[0], delta_wall_trials[1], delta_wall_trials[2], delta_ms, h.blocks.items.len, h.changed_from, report.peakRssKb() orelse 0 });
    try std.testing.expectEqual(messages + 1, h.blocks.items.len);
    try std.testing.expectEqual(messages - 1, h.changed_from);
    try std.testing.expect(delta_ms < 100);

    const users = try report.checked("allocate users", a.alloc(echo.UserBlock, h.blocks.items.len));
    defer a.free(users);
    for (h.blocks.items, 0..) |b, i| users[i] = .{ .text = h.text.items[b.start..][0..b.len], .stamp_ms = b.stamp_ms };
    var pending: [20]echo.Pending = @splat(.{ .prefix = std.unicode.utf8ToUtf16LeStringLiteral("new prompt"), .text = std.unicode.utf8ToUtf16LeStringLiteral("new prompt"), .anchor = .{ .counted = true } });
    var picked: [20]?usize = undefined;
    const reconcile_wall_start = std.Io.Clock.awake.now(std.testing.io);
    const reconcile_start = now();
    echo.assign(&pending, users, false, &.{}, &picked);
    const picked_first: i64 = if (picked[0]) |p| @intCast(p) else -1;
    const represented: i64 = if (echo.represented(pending[0].text, users)) |p| @intCast(p) else -1;
    var extra_picks: usize = 0;
    for (picked[1..]) |p| extra_picks += @intFromBool(p != null);
    const reconcile_ms = ms(reconcile_start);
    const reconcile_wall_ms = reconcile_wall_start.durationTo(std.Io.Clock.awake.now(std.testing.io)).toMilliseconds();
    std.debug.print("CPU707 reconcile picked={d} expected_pick={d} represented={d} extra_picks={d} reconcile_cpu_ms={d} reconcile_wall_ms={d} peak_rss_kb={d}\n", .{ picked_first, messages, represented, extra_picks, reconcile_ms, reconcile_wall_ms, report.peakRssKb() orelse 0 });
    try std.testing.expectEqual(@as(?usize, messages), picked[0]);
    for (picked[1..]) |p| try std.testing.expect(p == null);
    try std.testing.expectEqual(@as(?usize, messages), echo.represented(pending[0].text, users));
    try std.testing.expect(reconcile_ms < 1000);
    std.debug.print("CPU707 benchmark bytes={d} messages={d} parse_ms={d} delta_ms={d} reconcile_ms={d} clock=awake parse_cpu_ms={d} delta_cpu_ms={d} reconcile_cpu_ms={d} cpu_clock=cpu_thread peak_rss_kb={d} delta_cpu_trials={d}/{d}/{d}\n", .{ wire.items.len, messages, parse_wall_ms, delta_wall_trials[2], reconcile_wall_ms, parse_ms, delta_ms, reconcile_ms, report.peakRssKb() orelse 0, delta_cpu_trials[0], delta_cpu_trials[1], delta_cpu_trials[2] });
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

test "IGSH-991 CPU961 pending echo assignment stays within 50 ms on long histories" {
    const a = std.heap.page_allocator;
    const block_counts = [_]usize{ 1200, 2800, 12200 };
    const block_chars = [_]usize{ 60, 600 };
    const pending_chars = [_]usize{ 40, 2000, 12000 };
    var slowest_ms: i64 = 0;
    for (block_counts) |count| for (block_chars) |chars| {
        const storage = try a.alloc(u16, count * chars);
        defer a.free(storage);
        const users = try a.alloc(echo.UserBlock, count + 1);
        defer a.free(users);
        for (0..count) |i| {
            const slice = storage[i * chars ..][0..chars];
            for (slice, 0..) |*c, k| c.* = if (k % 7 == 6) ' ' else @intCast('a' + (i + k) % 26);
            users[i] = .{ .text = slice };
        }
        for (pending_chars) |pending_len| {
            const text = try a.alloc(u16, pending_len);
            defer a.free(text);
            for (text, 0..) |*c, k| c.* = if (k % 9 == 8) ' ' else @intCast('A' + k % 26);
            users[count] = .{ .text = text };
            for (0..5) |trial| for ([_]bool{ false, true }) |present| {
                var pending: [1]echo.Pending = .{.{ .prefix = text[0..@min(text.len, 40)], .text = text, .anchor = .{ .counted = true } }};
                var picked: [1]?usize = undefined;
                const wall_start = std.Io.Clock.awake.now(std.testing.io);
                const start = now();
                echo.assign(&pending, users[0 .. count + @intFromBool(present)], false, &.{}, &picked);
                const elapsed = ms(start);
                const wall_ms = wall_start.durationTo(std.Io.Clock.awake.now(std.testing.io)).toMilliseconds();
                std.mem.doNotOptimizeAway(picked[0]);
                try std.testing.expectEqual(if (present) @as(?usize, count) else null, picked[0]);
                slowest_ms = @max(slowest_ms, elapsed);
                std.debug.print("CPU961 reconcile blocks={d} block_chars={d} pending_chars={d} trial={d} present={} ms={d} mode={s} clock=cpu_thread wall_ms={d}\n", .{ count, chars, pending_len, trial, present, elapsed, @tagName(@import("builtin").mode), wall_ms });
            };
        }
    };
    std.debug.print("CPU991 matching slowest_ms={d} budget_ms=50 mode={s} clock=cpu_thread\n", .{ slowest_ms, @tagName(@import("builtin").mode) });
    try std.testing.expect(slowest_ms <= 50);
}
