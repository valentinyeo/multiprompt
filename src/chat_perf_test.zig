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
        fn expectCpuBudget(phase: []const u8, actual_ms: i64, budget_ms: i64) !void {
            if (actual_ms >= budget_ms) {
                std.debug.print("CPU707 phase={s} actual_cpu_ms={d} strict_budget_ms={d} overage_ms={d} mode={s} clock=cpu_thread\n", .{ phase, actual_ms, budget_ms, actual_ms - budget_ms, @tagName(@import("builtin").mode) });
                return error.TestUnexpectedResult;
            }
        }
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
    try report.expectCpuBudget("parse", parse_ms, 3000);
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
    try report.expectCpuBudget("append", delta_ms, 100);

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
    try report.expectCpuBudget("reconcile", reconcile_ms, 1000);
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

test "IGSH-991 SOFT-3146 echo assign budget credits per-block scan alongside character volume" {
    const ref_block_chars: usize = 1200;
    const ref_work_units: u64 = 6100 * (ref_block_chars + ref_block_chars);
    const heavy_units: u64 = 12200 * (600 + ref_block_chars);
    const ratio = @as(f64, @floatFromInt(heavy_units)) / @as(f64, @floatFromInt(ref_work_units));
    const slack_ratio = 1.2;
    const absolute_floor_ms = 20;
    const budget = @max(@as(f64, @floatFromInt(absolute_floor_ms)), 32 * ratio * slack_ratio);
    try std.testing.expect(33 <= budget);
    try std.testing.expect(66 > budget);
}

test "IGSH-991 CPU961 pending echo assignment stays within a same-run scaled budget on long histories" {
    const Bench = struct {
        const ref_blocks: usize = 6100;
        const ref_block_chars: usize = 1200;
        const slack_ratio: f64 = 1.2;
        const absolute_floor_ms: i64 = 20;
        const tick_ms: f64 = 15.625;
        const min_batch_ms: i64 = 100;
        const trial_count: usize = 3;
        const max_reps: usize = 4096;

        const Measured = struct { per_call_ms: f64, batch_ms: i64, wall_ms: i64, picked: ?usize, reps: usize };
        const Pair = struct { scenario_ms: f64, reference_ms: f64, scenario: Measured, reference: Measured };
        const Subject = struct {
            users: []const echo.UserBlock,
            prefix: []const u16,
            text: []const u16,
            present: bool,
            reps: usize,
            expected_pick: ?usize,
        };

        const ref_work_units: u64 = workUnits(ref_blocks, ref_block_chars);
        const heaviest_work_units: u64 = workUnits(12200, 600);

        fn workUnits(blocks: usize, block_chars: usize) u64 {
            const b = @as(u64, @intCast(blocks));
            const c = @as(u64, @intCast(block_chars));
            return b * (c + @as(u64, @intCast(ref_block_chars)));
        }
        fn budgetMs(reference_per_call_ms: f64, units: u64) f64 {
            const ratio = @as(f64, @floatFromInt(units)) / @as(f64, @floatFromInt(ref_work_units));
            const scaled = reference_per_call_ms * ratio * slack_ratio;
            return @max(@as(f64, @floatFromInt(absolute_floor_ms)), scaled);
        }
        fn repsFor(reference_per_call_ms: f64, units: u64) usize {
            const ratio = @as(f64, @floatFromInt(units)) / @as(f64, @floatFromInt(ref_work_units));
            const expected_ms = reference_per_call_ms * ratio;
            if (!(expected_ms > 0.0)) return max_reps;
            const wanted = @as(f64, @floatFromInt(min_batch_ms)) / expected_ms;
            if (!(wanted > 1.0)) return 1;
            const capped = @min(wanted, @as(f64, @floatFromInt(max_reps)));
            return @max(@as(usize, @intFromFloat(@ceil(capped))), 1);
        }
        fn fillBlocks(storage: []u16, blocks: usize, block_chars: usize) void {
            for (0..blocks) |i| {
                const slice = storage[i * block_chars ..][0..block_chars];
                for (slice, 0..) |*c, k| c.* = if (k % 7 == 6) ' ' else @intCast('a' + (i + k) % 26);
            }
        }
        fn fillPending(text: []u16) void {
            for (text, 0..) |*c, k| c.* = if (k % 9 == 8) ' ' else @intCast('A' + k % 26);
        }
        fn measureAssign(
            users: []const echo.UserBlock,
            prefix: []const u16,
            text: []const u16,
            present: bool,
            reps: usize,
        ) Measured {
            var pending: [1]echo.Pending = .{.{ .prefix = prefix, .text = text, .anchor = .{ .counted = true } }};
            var picked: [1]?usize = undefined;
            const wall_start = std.Io.Clock.awake.now(std.testing.io);
            const start = now();
            for (0..reps) |_| {
                echo.assign(&pending, users[0 .. users.len - 1 + @intFromBool(present)], false, &.{}, &picked);
                std.mem.doNotOptimizeAway(picked[0]);
            }
            const batch_ms = ms(start);
            const wall_ms = wall_start.durationTo(std.Io.Clock.awake.now(std.testing.io)).toMilliseconds();
            const per_call_ms = @as(f64, @floatFromInt(batch_ms)) / @as(f64, @floatFromInt(@max(reps, 1)));
            return .{ .per_call_ms = per_call_ms, .batch_ms = batch_ms, .wall_ms = wall_ms, .picked = picked[0], .reps = reps };
        }
        fn batched(
            users: []const echo.UserBlock,
            prefix: []const u16,
            text: []const u16,
            present: bool,
            reps_hint: usize,
            expected_pick: ?usize,
        ) !Measured {
            var reps = @max(reps_hint, 1);
            var attempt: usize = 0;
            while (true) : (attempt += 1) {
                const measured = measureAssign(users, prefix, text, present, reps);
                try std.testing.expectEqual(expected_pick, measured.picked);
                if (measured.batch_ms >= min_batch_ms or reps >= max_reps or attempt >= 4) return measured;
                const grow: usize = if (measured.batch_ms > 0)
                    @as(usize, @intCast(@divTrunc(min_batch_ms + measured.batch_ms - 1, measured.batch_ms)))
                else
                    8;
                reps = @min(max_reps, reps * @max(grow, 2));
            }
        }
        fn measureSubject(subject: Subject) !Measured {
            return batched(subject.users, subject.prefix, subject.text, subject.present, subject.reps, subject.expected_pick);
        }
        fn paired(scenario: Subject, reference: Subject, scenario_first: bool) !Pair {
            var scenario_measured: Measured = undefined;
            var reference_measured: Measured = undefined;
            if (scenario_first) {
                scenario_measured = try measureSubject(scenario);
                reference_measured = try measureSubject(reference);
            } else {
                reference_measured = try measureSubject(reference);
                scenario_measured = try measureSubject(scenario);
            }
            return .{ .scenario_ms = scenario_measured.per_call_ms, .reference_ms = reference_measured.per_call_ms, .scenario = scenario_measured, .reference = reference_measured };
        }
    };

    const a = std.heap.page_allocator;
    const block_counts = [_]usize{ 12200, 2800, 1200 };
    const block_chars = [_]usize{ 600, 60 };
    const pending_chars = [_]usize{ 40, 2000, 12000 };
    const Case = struct { blocks: usize, chars: usize, pending_len: usize, present: bool, best_ratio: f64, slowest_ms: f64 };
    const case_capacity = block_counts.len * block_chars.len * pending_chars.len * 2;
    var cases: [case_capacity]Case = undefined;
    var case_count: usize = 0;

    const ref_storage = try a.alloc(u16, @as(usize, @intCast(Bench.ref_work_units)));
    defer a.free(ref_storage);
    const ref_users = try a.alloc(echo.UserBlock, Bench.ref_blocks + 1);
    defer a.free(ref_users);
    Bench.fillBlocks(ref_storage, Bench.ref_blocks, Bench.ref_block_chars);
    for (0..Bench.ref_blocks) |i| ref_users[i] = .{ .text = ref_storage[i * Bench.ref_block_chars ..][0..Bench.ref_block_chars] };
    const ref_text = try a.alloc(u16, 40);
    defer a.free(ref_text);
    Bench.fillPending(ref_text);
    ref_users[Bench.ref_blocks] = .{ .text = ref_text };
    const ref_prefix = ref_text[0..@min(ref_text.len, 40)];
    _ = Bench.measureAssign(ref_users, ref_prefix, ref_text, true, 1);
    const calibration = try Bench.batched(ref_users, ref_prefix, ref_text, true, 1, Bench.ref_blocks);
    const reference_per_call_ms = calibration.per_call_ms;
    const reference = Bench.Subject{ .users = ref_users, .prefix = ref_prefix, .text = ref_text, .present = true, .reps = calibration.reps, .expected_pick = Bench.ref_blocks };
    std.debug.print("CPU960 calibrate blocks={d} block_chars={d} pending_chars={d} trial={d} present=true reps={d} batch_ms={d} per_call_ms={d:.3} mode={s} clock=cpu_thread wall_ms={d}\n", .{ Bench.ref_blocks, Bench.ref_block_chars, ref_text.len, 0, calibration.reps, calibration.batch_ms, calibration.per_call_ms, @tagName(@import("builtin").mode), calibration.wall_ms });
    std.debug.print("CPU960 reference_per_call_ms={d:.3} ref_work_units={d} heaviest_work_units={d} slack_ratio={d:.2} absolute_floor_ms={d} min_batch_ms={d} tick_ms={d:.3} trials={d} mode={s} clock=cpu_thread\n", .{ reference_per_call_ms, Bench.ref_work_units, Bench.heaviest_work_units, Bench.slack_ratio, Bench.absolute_floor_ms, Bench.min_batch_ms, Bench.tick_ms, Bench.trial_count, @tagName(@import("builtin").mode) });

    for (block_counts) |bench_count| {
        for (block_chars) |bench_chars| {
            const bench_storage = try a.alloc(u16, bench_count * bench_chars);
            defer a.free(bench_storage);
            const bench_users = try a.alloc(echo.UserBlock, bench_count + 1);
            defer a.free(bench_users);
            Bench.fillBlocks(bench_storage, bench_count, bench_chars);
            for (0..bench_count) |i| bench_users[i] = .{ .text = bench_storage[i * bench_chars ..][0..bench_chars] };
            for (pending_chars) |bench_pending_len| {
                const bench_text = try a.alloc(u16, bench_pending_len);
                defer a.free(bench_text);
                Bench.fillPending(bench_text);
                bench_users[bench_count] = .{ .text = bench_text };
                const bench_prefix = bench_text[0..@min(bench_text.len, 40)];
                const units = Bench.workUnits(bench_count, bench_chars);
                const reps_hint = Bench.repsFor(reference_per_call_ms, units);
                for ([_]bool{ false, true }) |present| {
                    const expected_pick: ?usize = if (present) bench_count else null;
                    const scenario = Bench.Subject{ .users = bench_users, .prefix = bench_prefix, .text = bench_text, .present = present, .reps = reps_hint, .expected_pick = expected_pick };
                    var best_ratio: f64 = std.math.inf(f64);
                    var slowest_case_ms: f64 = 0.0;
                    for (0..Bench.trial_count) |trial| {
                        const scenario_first = trial % 2 == 0;
                        const order: []const u8 = if (scenario_first) "scenario_first" else "reference_first";
                        const pair = try Bench.paired(scenario, reference, scenario_first);
                        const scenario_budget_ms = Bench.budgetMs(pair.reference_ms, units);
                        const ratio = pair.scenario_ms / scenario_budget_ms;
                        best_ratio = @min(best_ratio, ratio);
                        slowest_case_ms = @max(slowest_case_ms, pair.scenario_ms);
                        std.debug.print("CPU961 reconcile blocks={d} block_chars={d} pending_chars={d} trial={d} present={} order={s} scenario_reps={d} scenario_batch_ms={d} scenario_per_call_ms={d:.3} reference_reps={d} reference_batch_ms={d} reference_per_call_ms={d:.3} scenario_budget_ms={d:.3} ratio={d:.3} mode={s} clock=cpu_thread wall_ms={d}\n", .{ bench_count, bench_chars, bench_pending_len, trial, present, order, pair.scenario.reps, pair.scenario.batch_ms, pair.scenario_ms, pair.reference.reps, pair.reference.batch_ms, pair.reference_ms, scenario_budget_ms, ratio, @tagName(@import("builtin").mode), pair.scenario.wall_ms });
                    }
                    cases[case_count] = .{ .blocks = bench_count, .chars = bench_chars, .pending_len = bench_pending_len, .present = present, .best_ratio = best_ratio, .slowest_ms = slowest_case_ms };
                    case_count += 1;
                }
            }
        }
    }

    var slowest_ms: f64 = 0.0;
    var worst_ratio: f64 = 0.0;
    for (cases[0..case_count]) |c| {
        worst_ratio = @max(worst_ratio, c.best_ratio);
        slowest_ms = @max(slowest_ms, c.slowest_ms);
        if (c.best_ratio > 1.0) {
            std.debug.print("CPU961 scenario_over blocks={d} block_chars={d} pending_chars={d} present={} case_ratio={d:.3} slowest_per_call_ms={d:.3} mode={s} clock=cpu_thread\n", .{ c.blocks, c.chars, c.pending_len, c.present, c.best_ratio, c.slowest_ms, @tagName(@import("builtin").mode) });
        }
    }
    std.debug.print("CPU991 matching worst_ratio={d:.3} slowest_ms={d:.3} reference_per_call_ms={d:.3} heaviest_budget_ms={d:.3} mode={s} clock=cpu_thread\n", .{ worst_ratio, slowest_ms, reference_per_call_ms, Bench.budgetMs(reference_per_call_ms, Bench.heaviest_work_units), @tagName(@import("builtin").mode) });
    try std.testing.expect(worst_ratio <= 1.0);
}
