const std = @import("std");

pub fn build(out: []u8, reader: []const u8, session: []const u8, sid: []const u8, agent: u8) ?[]const u8 {
    if (!safePath(reader)) return null;
    if (!safeTarget(session)) return null;
    if (sid.len != 0 and !safeSid(sid)) return null;
    var pos: usize = 0;
    if (!append(out, &pos, "tmux kill-session -t '")) return null;
    if (!append(out, &pos, session)) return null;
    if (!append(out, &pos, "' 2>/dev/null; ")) return null;
    if (sid.len != 0) {
        if (!append(out, &pos, "python3 ")) return null;
        if (!append(out, &pos, reader)) return null;
        const live = @import("chat_view.zig").isLive(session);
        const command = switch (agent) {
            2 => if (live) " host disable codex '" else " host stop codex '",
            3 => if (live) " host disable pi '" else " host stop pi '",
            else => if (live) " host disable claude '" else " host stop claude '",
        };
        if (!append(out, &pos, command)) return null;
        if (!append(out, &pos, sid)) return null;
        if (!append(out, &pos, "' >/dev/null 2>&1; ")) return null;
    }
    if (!append(out, &pos, "true")) return null;
    return out[0..pos];
}

fn append(out: []u8, pos: *usize, text: []const u8) bool {
    if (pos.* + text.len > out.len) return false;
    @memcpy(out[pos.*..][0..text.len], text);
    pos.* += text.len;
    return true;
}

fn safeTarget(value: []const u8) bool {
    if (value.len == 0 or value.len > 63) return false;
    for (value) |c| {
        const ok = (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_' or c == '-';
        if (!ok) return false;
    }
    return true;
}

fn safePath(value: []const u8) bool {
    if (value.len == 0 or value.len > 220) return false;
    for (value) |c| {
        const ok = std.ascii.isAlphanumeric(c) or c == '~' or c == '/' or c == '.' or c == '_' or c == '-';
        if (!ok) return false;
    }
    return true;
}

fn safeSid(value: []const u8) bool {
    if (value.len != 36) return false;
    for (value, 0..) |c, i| {
        if (i == 8 or i == 13 or i == 18 or i == 23) {
            if (c != '-') return false;
        } else if (!std.ascii.isDigit(c) and !(c >= 'a' and c <= 'f')) return false;
    }
    return true;
}

test "IGSH-1266 a session the server no longer has still counts as ended" {
    var out: [256]u8 = undefined;
    const script = build(&out, "~/.multiprompt-runtime/reader.py", "term-abc", "", 1) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("tmux kill-session -t 'term-abc' 2>/dev/null; true", script);
    try std.testing.expect(build(&out, "~/.multiprompt-runtime/reader.py", "term-a;b", "", 1) == null);
    try std.testing.expect(build(&out, "~/.multiprompt-runtime/reader.py", "", "", 1) == null);
    try std.testing.expect(build(&out, "~/.multiprompt-runtime/reader.py", "term-abc", "short", 1) == null);
    try std.testing.expect(build(&out, "~/reader.py; rm -rf /", "term-abc", "", 1) == null);
}

test "IGSH-1266 ending a live chat session stops the app owned host too" {
    var out: [256]u8 = undefined;
    const script = build(&out, "~/.multiprompt-runtime/reader.py", "term-abc", "ffffffff-ffff-4fff-bfff-ffffffffffff", 1) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("tmux kill-session -t 'term-abc' 2>/dev/null; python3 ~/.multiprompt-runtime/reader.py host stop claude 'ffffffff-ffff-4fff-bfff-ffffffffffff' >/dev/null 2>&1; true", script);
}

test "IGSH-1666 stopping a hosted chat selects its provider" {
    var out: [256]u8 = undefined;
    const sid = "ffffffff-ffff-4fff-bfff-ffffffffffff";
    const codex = build(&out, "~/.multiprompt-runtime/reader.py", "live-codex", sid, 2) orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, codex, "host disable codex 'ffffffff") != null);
    const pi = build(&out, "~/.multiprompt-runtime/reader.py", "live-pi", sid, 3) orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, pi, "host disable pi 'ffffffff") != null);
}
