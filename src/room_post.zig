const std = @import("std");

pub const max_text = 65536;
pub const max_recipients = 64;

pub fn blank(value: []const u8) bool {
    for (value) |ch| if (ch != ' ' and ch != '\t' and ch != '\n' and ch != '\r') return false;
    return true;
}

pub fn validText(value: []const u8) bool {
    return value.len > 0 and value.len <= max_text and std.unicode.utf8ValidateSlice(value) and std.mem.indexOfScalar(u8, value, 0) == null and !blank(value);
}

fn aliasByte(ch: u8) bool {
    return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or (ch >= '0' and ch <= '9') or ch == '_' or ch == '-';
}

fn blocksMention(ch: u8) bool {
    return ch >= 0x80 or (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or (ch >= '0' and ch <= '9') or ch == '_' or ch == '@' or ch == '.' or ch == '\\' or ch == '+' or ch == '-';
}

pub fn recipients(message: []const u8, active: []const []const u8, out: *[max_recipients][]const u8) ?usize {
    var count: usize = 0;
    for (message, 0..) |ch, at| {
        if (ch != '@' or (at > 0 and blocksMention(message[at - 1]))) continue;
        var end = at + 1;
        while (end < message.len and aliasByte(message[end])) end += 1;
        const alias = message[at + 1 .. end];
        if (alias.len == 0) return null;
        var known = false;
        for (active) |name| if (std.mem.eql(u8, name, alias)) {
            known = true;
            break;
        };
        if (!known) return null;
        var seen = false;
        for (out[0..count]) |old| if (std.mem.eql(u8, old, alias)) {
            seen = true;
            break;
        };
        if (seen) continue;
        if (count == max_recipients) return null;
        out[count] = alias;
        count += 1;
    }
    return count;
}

test "post text rejects blank, oversize and NUL" {
    try std.testing.expect(validText("hello"));
    try std.testing.expect(!validText(""));
    try std.testing.expect(!validText(" \t\r\n"));
    try std.testing.expect(!validText("a\x00b"));
    try std.testing.expect(!validText("\xff"));
    var big: [max_text + 1]u8 = @splat('a');
    try std.testing.expect(validText(big[0..max_text]));
    try std.testing.expect(!validText(big[0..]));
}

test "mentions: plain message has no recipients" {
    var out: [max_recipients][]const u8 = undefined;
    const active = [_][]const u8{ "alpha", "beta" };
    try std.testing.expectEqual(@as(?usize, 0), recipients("hello team", &active, &out));
}

test "mentions: one alias" {
    var out: [max_recipients][]const u8 = undefined;
    const active = [_][]const u8{ "alpha", "beta" };
    try std.testing.expectEqual(@as(?usize, 1), recipients("@alpha look", &active, &out));
    try std.testing.expectEqualStrings("alpha", out[0]);
}

test "mentions: two aliases keep first-seen order" {
    var out: [max_recipients][]const u8 = undefined;
    const active = [_][]const u8{ "alpha", "beta" };
    try std.testing.expectEqual(@as(?usize, 2), recipients("hi @beta and @alpha.", &active, &out));
    try std.testing.expectEqualStrings("beta", out[0]);
    try std.testing.expectEqualStrings("alpha", out[1]);
}

test "mentions: duplicate alias counts once" {
    var out: [max_recipients][]const u8 = undefined;
    const active = [_][]const u8{ "alpha", "beta" };
    try std.testing.expectEqual(@as(?usize, 1), recipients("@alpha then @alpha again", &active, &out));
}

test "mentions: email address is not a mention" {
    var out: [max_recipients][]const u8 = undefined;
    const active = [_][]const u8{ "alpha" };
    try std.testing.expectEqual(@as(?usize, 0), recipients("mail a@b.c now", &active, &out));
}

test "mentions: blocked by word, at, dot, backslash, plus and minus before the at sign" {
    var out: [max_recipients][]const u8 = undefined;
    const active = [_][]const u8{ "alpha" };
    for ([_][]const u8{ "x@nobody", "9@nobody", "_@nobody", ".@nobody", "\\@nobody", "+@nobody", "-@nobody", "\xc3\xa9@nobody" }) |text| {
        try std.testing.expectEqual(@as(?usize, 0), recipients(text, &active, &out));
    }
    try std.testing.expectEqual(@as(?usize, null), recipients("@@nobody", &active, &out));
}

test "mentions: allowed before the at sign" {
    var out: [max_recipients][]const u8 = undefined;
    const active = [_][]const u8{ "alpha" };
    for ([_][]const u8{ "(@alpha)", " @alpha", "\n@alpha", ",@alpha", ":@alpha" }) |text| {
        try std.testing.expectEqual(@as(?usize, 1), recipients(text, &active, &out));
    }
}

test "mentions: unknown alias fails" {
    var out: [max_recipients][]const u8 = undefined;
    const active = [_][]const u8{ "alpha" };
    try std.testing.expectEqual(@as(?usize, null), recipients("@ghost hi", &active, &out));
    try std.testing.expectEqual(@as(?usize, null), recipients("@Alpha hi", &active, &out));
}

test "mentions: bare at sign fails" {
    var out: [max_recipients][]const u8 = undefined;
    const active = [_][]const u8{ "alpha" };
    try std.testing.expectEqual(@as(?usize, null), recipients("hi @", &active, &out));
    try std.testing.expectEqual(@as(?usize, null), recipients("hi @ there", &active, &out));
    try std.testing.expectEqual(@as(?usize, null), recipients("@", &active, &out));
}

test "mentions: alias run is the longest run of alias bytes" {
    var out: [max_recipients][]const u8 = undefined;
    const active = [_][]const u8{ "agent_one-two", "agent" };
    try std.testing.expectEqual(@as(?usize, 1), recipients("@agent_one-two!", &active, &out));
    try std.testing.expectEqualStrings("agent_one-two", out[0]);
    try std.testing.expectEqual(@as(?usize, null), recipients("@agent_one", &active, &out));
}
