const std = @import("std");

pub fn providerShortLabel(provider: []const u8) []const u8 {
    if (std.mem.eql(u8, provider, "claude")) return "CL";
    if (std.mem.eql(u8, provider, "codex")) return "CX";
    if (std.mem.eql(u8, provider, "kimi")) return "KM";
    return "AI";
}

pub fn wholePercent(tenths: u32) u32 {
    return (tenths + 5) / 10;
}

pub fn formatWeekSegment(buf: []u8, short: []const u8, has_used: bool, used_tenths: u32) []const u8 {
    if (!has_used) return std.fmt.bufPrint(buf, "{s} -", .{short}) catch short;
    return std.fmt.bufPrint(buf, "{s} {d}%", .{ short, wholePercent(used_tenths) }) catch short;
}

pub fn formatVpsLoad(buf: []u8, valid: bool, load_percent: u32, ram_free_percent: u32) []const u8 {
    if (!valid) return "waiting...";
    return std.fmt.bufPrint(buf, "CPU {d}% | RAM {d}%", .{ load_percent, ram_free_percent }) catch "?";
}

pub fn formatHostLoad(buf: []u8, host: []const u8, valid: bool, load_percent: u32) []const u8 {
    if (!valid) return std.fmt.bufPrint(buf, "{s} -", .{host}) catch host;
    return std.fmt.bufPrint(buf, "{s} {d}%", .{ host, load_percent }) catch host;
}

test "status line provider labels are the short Claude and Codex names" {
    try std.testing.expectEqualStrings("CL", providerShortLabel("claude"));
    try std.testing.expectEqualStrings("CX", providerShortLabel("codex"));
    try std.testing.expectEqualStrings("KM", providerShortLabel("kimi"));
    try std.testing.expectEqualStrings("AI", providerShortLabel("unknown"));
}

test "status line week segments round to whole percent" {
    var buf: [24]u8 = undefined;
    try std.testing.expectEqualStrings("CL 45%", formatWeekSegment(&buf, "CL", true, 449));
    try std.testing.expectEqualStrings("CX 49%", formatWeekSegment(&buf, "CX", true, 485));
    try std.testing.expectEqualStrings("CX 0%", formatWeekSegment(&buf, "CX", true, 4));
    try std.testing.expectEqualStrings("CL 100%", formatWeekSegment(&buf, "CL", true, 1000));
    try std.testing.expectEqualStrings("CL -", formatWeekSegment(&buf, "CL", false, 450));
}

test "status line VPS text keeps CPU load and RAM free" {
    var buf: [48]u8 = undefined;
    try std.testing.expectEqualStrings("CPU 145% | RAM 50%", formatVpsLoad(&buf, true, 145, 50));
    try std.testing.expectEqualStrings("waiting...", formatVpsLoad(&buf, false, 0, 0));
    try std.testing.expectEqualStrings("Host 1 45%", formatHostLoad(&buf, "Host 1", true, 45));
    try std.testing.expectEqualStrings("Host 1 -", formatHostLoad(&buf, "Host 1", false, 0));
}
