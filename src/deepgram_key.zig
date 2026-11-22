const std = @import("std");

pub const Check = enum { accepted, rejected, unknown };

pub fn fixturePort(github: []const u8, runner: []const u8, offline: []const u8, port: []const u8) ?u16 {
    if (!std.mem.eql(u8, github, "true") or !std.mem.eql(u8, runner, "Windows") or !std.mem.eql(u8, offline, "1")) return null;
    if (port.len == 0 or port.len >= 16) return null;
    for (port) |c| if (c < '0' or c > '9') { return null; };
    const value = std.fmt.parseInt(u16, port, 10) catch return null;
    return if (value == 0) null else value;
}

pub fn classify(status: ?u32) Check {
    const code = status orelse return .unknown;
    if (code == 401 or code == 403) return .rejected;
    if (code < 500 and code != 429) return .accepted;
    return .unknown;
}

fn isHex(c: u16) bool {
    return (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F');
}

fn isWhitespace(c: u16) bool {
    return (c >= 0x09 and c <= 0x0d) or (c >= 0x1c and c <= 0x20) or c == 0xa0 or c == 0x1680 or (c >= 0x2000 and c <= 0x200a) or c == 0x2028 or c == 0x2029 or c == 0x202f or c == 0x205f or c == 0x3000;
}

pub fn normalize(raw: []const u16, out: *[512:0]u16) ?[:0]const u16 {
    var i: usize = 0;
    while (i + 40 <= raw.len) : (i += 1) {
        if (i > 0 and isHex(raw[i - 1])) continue;
        var n: usize = 0;
        while (n < 40 and isHex(raw[i + n])) : (n += 1) {}
        if (n != 40 or (i + 40 < raw.len and isHex(raw[i + 40]))) continue;
        for (raw[i..][0..40], 0..) |c, j| out[j] = if (c >= 'A' and c <= 'F') c + 32 else c;
        out[40] = 0;
        return out[0..40 :0];
    }
    var start: usize = 0;
    var end = raw.len;
    while (start < end and isWhitespace(raw[start])) : (start += 1) {}
    while (end > start and isWhitespace(raw[end - 1])) : (end -= 1) {}
    for (raw[start..end]) |c| if (isWhitespace(c)) { return null; };
    start = 0;
    end = raw.len;
    while (start < end and (raw[start] < '!' or raw[start] > '~' or raw[start] == '"' or raw[start] == '\'')) : (start += 1) {}
    while (end > start and (raw[end - 1] < '!' or raw[end - 1] > '~' or raw[end - 1] == '"' or raw[end - 1] == '\'')) : (end -= 1) {}
    var count: usize = 0;
    for (raw[start..end]) |c| {
        if (c < '!' or c > '~') continue;
        if (count == 512) return null;
        out[count] = c;
        count += 1;
    }
    if (count < 32) return null;
    if (count < 512) out[count] = 0;
    return out[0..count :0];
}

test "normalize bounded hex and opaque keys" {
    var out: [512:0]u16 = @splat(0);
    const hex = [_]u16{'A'} ** 40;
    const raw = [_]u16{ 'k', 'e', 'y', ':', ' ' } ++ hex ++ [_]u16{ ' ', '!' };
    const expected = [_]u16{'a'} ** 40;
    try std.testing.expectEqual(@as(usize, 40), hex.len);
    try std.testing.expectEqualSlices(u16, &expected, normalize(&raw, &out).?);
    const opaque_key = std.unicode.utf8ToUtf16LeStringLiteral("\"zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz\"");
    try std.testing.expectEqual(@as(usize, 32), normalize(opaque_key, &out).?.len);
    try std.testing.expect(normalize(std.unicode.utf8ToUtf16LeStringLiteral("not a key"), &out) == null);
}

test "classify provider responses" {
    try std.testing.expectEqual(Check.accepted, classify(200));
    try std.testing.expectEqual(Check.accepted, classify(400));
    try std.testing.expectEqual(Check.rejected, classify(401));
    try std.testing.expectEqual(Check.rejected, classify(403));
    try std.testing.expectEqual(Check.unknown, classify(429));
    try std.testing.expectEqual(Check.unknown, classify(503));
    try std.testing.expectEqual(Check.unknown, classify(null));
}


test "normalization boundaries and decorations" {
    var out: [512:0]u16 = @splat(0);
    const hex = [_]u16{'a'} ** 40;
    const upper = [_]u16{'A'} ** 40;
    const prefixed = [_]u16{ 'p', 'r', 'e', 'f', 'i', 'x', ':', ' ' } ++ upper;
    const wrapped = [_]u16{'\''} ++ upper ++ [_]u16{'\''};
    const oversized_hex = [_]u16{'a'} ** 41;
    try std.testing.expectEqualSlices(u16, &hex, normalize(&prefixed, &out).?);
    try std.testing.expectEqualSlices(u16, &hex, normalize(&hex, &out).?);
    try std.testing.expectEqualSlices(u16, &hex, normalize(&wrapped, &out).?);
    try std.testing.expectEqual(@as(usize, 41), normalize(&oversized_hex, &out).?.len);
    try std.testing.expectEqual(@as(usize, 32), normalize(std.unicode.utf8ToUtf16LeStringLiteral("\u{200b}'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz'\u{200b}"), &out).?.len);
    try std.testing.expect(normalize(std.unicode.utf8ToUtf16LeStringLiteral("zzzzzzzzzzzzzzzz zzzzzzzzzzzzzzzz"), &out) == null);
    try std.testing.expect(normalize(std.unicode.utf8ToUtf16LeStringLiteral("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"), &out) == null);
    var maximum: [513]u16 = @splat('z');
    try std.testing.expectEqual(@as(usize, 512), normalize(maximum[0..512], &out).?.len);
    try std.testing.expect(normalize(&maximum, &out) == null);
    var quoted: [514]u16 = @splat('z');
    quoted[0] = '"';
    quoted[513] = '"';
    try std.testing.expectEqual(@as(usize, 512), normalize(&quoted, &out).?.len);
    maximum[512] = '0';
    try std.testing.expect(normalize(&maximum, &out) == null);
}

test "fixture endpoint requires hosted offline Windows and valid port" {
    try std.testing.expectEqual(@as(?u16, 1), fixturePort("true", "Windows", "1", "1"));
    try std.testing.expectEqual(@as(?u16, 65535), fixturePort("true", "Windows", "1", "65535"));
    for ([_][]const u8{ "", "false", "TRUE" }) |value| try std.testing.expect(fixturePort(value, "Windows", "1", "1234") == null);
    for ([_][]const u8{ "", "Linux", "windows" }) |value| try std.testing.expect(fixturePort("true", value, "1", "1234") == null);
    for ([_][]const u8{ "", "0", "true" }) |value| try std.testing.expect(fixturePort("true", "Windows", value, "1234") == null);
    for ([_][]const u8{ "", "0", "00000", "65536", "9999999999999999", "-1", "+1", "12x", " 80" }) |value| try std.testing.expect(fixturePort("true", "Windows", "1", value) == null);
}
