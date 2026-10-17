const std = @import("std");

pub const Source = enum { hook_done, heuristic, notification, restore, manual };

pub const State = struct {
    hook_capable: bool = false,
    turn_active: bool = false,
    done_after_activity: bool = false,
    console_working: bool = false,
};

pub fn allow(source: Source, state: State) bool {
    if (source == .manual) return !state.turn_active and !state.console_working;
    if (source == .notification) return true;
    if (state.console_working) return false;
    return switch (source) {
        .hook_done => state.done_after_activity and !state.turn_active,
        .heuristic => !state.hook_capable and !state.turn_active,
        .restore => !state.turn_active,
        .notification, .manual => unreachable,
    };
}

pub fn isWorkingLine(line: []const u16) bool {
    const needles = [_][]const u8{ "esc to interrupt", "waiting for", "running shell command", "running 1 shell command", "running 2 shell commands", "ideating", "cogitating", "churning", "orchestrating", "meandering", "thinking" };
    for (line, 0..) |ch, i| {
        if (ch == 0x2026 and i >= 7 and containsAsciiCI(line[i - 7 .. i], "running")) return true;
    }
    for (needles) |needle| {
        if (containsAsciiCI(line, needle)) return true;
    }
    for (line, 0..) |ch, i| {
        if (ch != '(' or i + 2 >= line.len) continue;
        var j = i + 1;
        while (j < line.len and line[j] >= '0' and line[j] <= '9') : (j += 1) {}
        if (j > i + 1 and j < line.len and (line[j] == 'm' or line[j] == 's')) return true;
    }
    return false;
}

fn containsAsciiCI(line: []const u16, needle: []const u8) bool {
    if (line.len < needle.len) return false;
    for (0..line.len - needle.len + 1) |start| {
        var match = true;
        for (needle, 0..) |ch, j| {
            if (line[start + j] > 127 or std.ascii.toLower(@as(u8, @intCast(line[start + j]))) != ch) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

const working_markers = [_]u16{ 0x2022, 0x25CF, 0x23FA, 0x273B, 0x2733, 0x2736, 0x2722, 0x2737, 0x273D, 0x2734, 0x2217, 0x00B7, '*' };

fn trimSpaces(line: []const u16) []const u16 {
    var start: usize = 0;
    var end: usize = line.len;
    while (start < end and (line[start] == ' ' or line[start] == '\t')) start += 1;
    while (end > start and (line[end - 1] == ' ' or line[end - 1] == '\t')) end -= 1;
    return line[start..end];
}

pub fn workingStatusText(line: []const u16, out: []u16) ?usize {
    if (!containsAsciiCI(line, "esc to interrupt")) return null;
    var start: usize = 0;
    if (line.len > 0) {
        for (working_markers) |m| {
            if (line[0] == m) {
                start = 1;
                break;
            }
        }
    }
    while (start < line.len and line[start] == ' ') : (start += 1) {}
    const body = trimSpaces(line[start..]);
    if (body.len == 0) return null;
    var verb_end = body.len;
    for (body, 0..) |ch, i| {
        if (ch == '(') {
            verb_end = i;
            break;
        }
    }
    const verb = trimSpaces(body[0..verb_end]);
    if (verb.len == 0) return null;
    var elapsed: []const u16 = &.{};
    if (verb_end < body.len) {
        const rest = body[verb_end + 1 ..];
        var e: usize = 0;
        while (e < rest.len and rest[e] != ')' and rest[e] != 0x00B7) : (e += 1) {}
        const tok = trimSpaces(rest[0..e]);
        for (tok) |ch| {
            if (ch >= '0' and ch <= '9') {
                elapsed = tok;
                break;
            }
        }
    }
    if (verb.len > out.len) return null;
    @memcpy(out[0..verb.len], verb);
    var n = verb.len;
    if (elapsed.len > 0 and n + 1 + elapsed.len <= out.len) {
        out[n] = ' ';
        n += 1;
        @memcpy(out[n .. n + elapsed.len], elapsed);
        n += elapsed.len;
    }
    return n;
}

test "hooked Claude quiet while working cannot gain a dot" {
    try std.testing.expect(!allow(.heuristic, .{ .hook_capable = true, .turn_active = true }));
    try std.testing.expect(!allow(.heuristic, .{ .hook_capable = true }));
    try std.testing.expect(!allow(.heuristic, .{ .console_working = true }));
    try std.testing.expect(isWorkingLine(&[_]u16{ '*', ' ', 'B', 'l', 'a', 'n', 'c', 'h', 'i', 'n', 'g', 0x2026, ' ', '(', '6', 'm', ' ', '5', '4', 's', ')' }));
    try std.testing.expect(isWorkingLine(std.unicode.utf8ToUtf16LeStringLiteral("Waiting for QA helper result · 17s")));
    try std.testing.expect(isWorkingLine(std.unicode.utf8ToUtf16LeStringLiteral("Running…")));
    try std.testing.expect(isWorkingLine(std.unicode.utf8ToUtf16LeStringLiteral("esc to interrupt")));
}

test "only first DONE after activity creates completion dot" {
    try std.testing.expect(allow(.hook_done, .{ .hook_capable = true, .done_after_activity = true }));
    try std.testing.expect(!allow(.hook_done, .{ .hook_capable = true }));
    try std.testing.expect(!allow(.hook_done, .{ .turn_active = true, .done_after_activity = true }));
    try std.testing.expect(!allow(.hook_done, .{ .done_after_activity = true, .console_working = true }));
}

test "plain shell quiet still gets dot, permission during turn allowed" {
    try std.testing.expect(allow(.heuristic, .{}));
    try std.testing.expect(allow(.notification, .{ .hook_capable = true, .turn_active = true, .console_working = true }));
}

test "workingStatusText extracts the live status text and rejects other rows" {
    var buf: [64]u16 = undefined;
    const cogitating_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{273b} Cogitating\u{2026} (12s \u{b7} esc to interrupt)");
    const minutes_z = std.unicode.utf8ToUtf16LeStringLiteral("* Hashing\u{2026} (5m 31s \u{b7} esc to interrupt)");
    const prose_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{25cf} The build now passes");
    const finished_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{2733} Cogitated for 12s");
    const no_clock_z = std.unicode.utf8ToUtf16LeStringLiteral("\u{273b} Cogitating\u{2026} (esc to interrupt)");

    const n = workingStatusText(cogitating_z[0..cogitating_z.len], &buf) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Cogitating\u{2026} 12s"), buf[0..n]);
    const m = workingStatusText(minutes_z[0..minutes_z.len], &buf) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Hashing\u{2026} 5m 31s"), buf[0..m]);
    const k = workingStatusText(no_clock_z[0..no_clock_z.len], &buf) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Cogitating\u{2026}"), buf[0..k]);
    try std.testing.expect(workingStatusText(prose_z[0..prose_z.len], &buf) == null);
    try std.testing.expect(workingStatusText(finished_z[0..finished_z.len], &buf) == null);
}
