const std = @import("std");

pub fn composerEscStops(bar_visible: bool, ac_open: bool, sel_active: bool) bool {
    return bar_visible and !ac_open and !sel_active;
}

pub const StopTransport = enum { console, tmux };

pub fn stopTransportFor(kind: anytype, has_tmux: bool) StopTransport {
    return if (has_tmux and (kind == .tmux or kind == .vps or kind == .vps2)) .tmux else .console;
}

pub fn workingSince(previous: u64, working: bool, now: u64) u64 {
    return if (!working) 0 else if (previous == 0) now else previous;
}

fn hasTime(text: []const u16) bool {
    for (text, 0..) |ch, i| {
        if ((ch == 's' or ch == 'm' or ch == 'h') and i > 0 and text[i - 1] >= '0' and text[i - 1] <= '9') return true;
    }
    return false;
}

pub fn workingBarText(status: []const u16, elapsed_ms: u64, out: []u16) []const u16 {
    var body = std.mem.trim(u16, status, &.{ ' ', '\r', '\n' });
    while (std.mem.endsWith(u16, body, &.{')'})) {
        const open = std.mem.lastIndexOfScalar(u16, body, '(') orelse break;
        const tail = body[open..];
        if (!hasTime(tail) and std.mem.indexOf(u16, tail, std.unicode.utf8ToUtf16LeStringLiteral("esc to interrupt")) == null) break;
        body = std.mem.trimEnd(u16, body[0..open], &.{' '});
    }
    if (body.len == 0) body = std.unicode.utf8ToUtf16LeStringLiteral("Working…");
    const secs = elapsed_ms / 1000;
    var clock: [40]u8 = undefined;
    const time = if (secs >= 3600)
        std.fmt.bufPrint(&clock, "{d}h {d:0>2}m", .{ secs / 3600, secs % 3600 / 60 }) catch unreachable
    else if (secs >= 60)
        std.fmt.bufPrint(&clock, "{d}m {d:0>2}s", .{ secs / 60, secs % 60 }) catch unreachable
    else
        std.fmt.bufPrint(&clock, "{d}s", .{secs}) catch unreachable;
    if (out.len < time.len + 3) return &.{};
    const n = @min(body.len, out.len - time.len - 3);
    @memcpy(out[0..n], body[0..n]);
    @memcpy(out[n..][0..3], &[_]u16{ ' ', 0xB7, ' ' });
    for (time, 0..) |ch, i| out[n + 3 + i] = ch;
    return out[0 .. n + 3 + time.len];
}

test "ISSUE-265 working bar strips Claude and Codex timers and keeps only our clock" {
    var out: [128]u16 = undefined;
    const cases = .{
        .{ "✻ Blanching… (6m 54s · esc to interrupt)", "✻ Blanching… · 1m 20s" },
        .{ "• Working (25m 51s • esc to interrupt)", "• Working · 1m 20s" },
        .{ "Thinking (3s)", "Thinking · 1m 20s" },
        .{ "Thinking (3s) (esc to interrupt)", "Thinking · 1m 20s" },
        .{ "Thinking (esc to interrupt)", "Thinking · 1m 20s" },
        .{ "Thinking (about code)", "Thinking (about code) · 1m 20s" },
        .{ "", "Working… · 1m 20s" },
    };
    inline for (cases) |case| try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral(case[1]), workingBarText(std.unicode.utf8ToUtf16LeStringLiteral(case[0]), 80_000, &out));
}

test "ISSUE-265 elapsed formats and bounded output" {
    var out: [128]u16 = undefined;
    const cases = .{ .{ 0, "Working… · 0s" }, .{ 999, "Working… · 0s" }, .{ 59_000, "Working… · 59s" }, .{ 80_000, "Working… · 1m 20s" }, .{ 3_720_000, "Working… · 1h 02m" } };
    inline for (cases) |case| try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral(case[1]), workingBarText(&.{}, case[0], &out));
    try std.testing.expectEqual(@as(usize, 0), workingBarText(&.{}, 0, out[0..2]).len);
}

test "ISSUE-265 Stop transport follows tmux identity not console visibility" {
    const Kind = enum { cmd, pwsh, vps, tmux, vps2, bash, gitbash };
    inline for (std.meta.tags(Kind)) |kind| {
        try std.testing.expectEqual(StopTransport.console, stopTransportFor(kind, false));
        try std.testing.expectEqual(if (kind == .tmux or kind == .vps or kind == .vps2) StopTransport.tmux else StopTransport.console, stopTransportFor(kind, true));
    }
}

test "ISSUE-265 composer Escape gives autocomplete and selection priority" {
    for ([_]bool{ false, true }) |bar| for ([_]bool{ false, true }) |ac| {
        for ([_]bool{ false, true }) |sel| try std.testing.expectEqual(bar and !ac and !sel, composerEscStops(bar, ac, sel));
    };
}

test "ISSUE-265 per-session working edges preserve background elapsed time" {
    try std.testing.expectEqual(@as(u64, 100), workingSince(0, true, 100));
    try std.testing.expectEqual(@as(u64, 100), workingSince(100, true, 8000));
    try std.testing.expectEqual(@as(u64, 0), workingSince(100, false, 9000));
    try std.testing.expectEqual(@as(u64, 9500), workingSince(0, true, 9500));
}
