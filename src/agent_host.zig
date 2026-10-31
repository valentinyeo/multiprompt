const std = @import("std");

pub const ENABLED = true;
pub const READER = "~/.multiprompt-runtime/reader.py";

pub fn eligible(program: []const u8) bool {
    return ENABLED and std.mem.startsWith(u8, program, "claude");
}

pub fn formatSessionId(out: *[36]u8, random: *const [16]u8) []const u8 {
    const hex = "0123456789abcdef";
    var bytes: [16]u8 = random.*;
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    var index: usize = 0;
    for (bytes, 0..) |byte, i| {
        if (i == 4 or i == 6 or i == 8 or i == 10) {
            out[index] = '-';
            index += 1;
        }
        out[index] = hex[byte >> 4];
        out[index + 1] = hex[byte & 15];
        index += 2;
    }
    return out[0..index];
}

pub fn mintSessionId(out: *[36]u8) ?[]const u8 {
    var random: [16]u8 = undefined;
    if (@import("win32.zig").BCryptGenRandom(null, &random, random.len, 0x00000002) < 0) return null;
    return formatSessionId(out, &random);
}

fn safeSessionId(value: []const u8) bool {
    if (value.len != 36) return false;
    for (value, 0..) |c, i| {
        if (i == 8 or i == 13 or i == 18 or i == 23) {
            if (c != '-') return false;
        } else if (!std.ascii.isDigit(c) and !(c >= 'a' and c <= 'f')) return false;
    }
    return true;
}

fn safeName(value: []const u8) bool {
    if (value.len == 0 or value.len > 64) return false;
    for (value) |c| {
        const ok = std.ascii.isAlphanumeric(c) or c == '_' or c == '-' or c == '.' or c == ':';
        if (!ok) return false;
    }
    return true;
}

fn safePath(value: []const u8) bool {
    if (value.len == 0 or value.len > 220) return false;
    for (value) |c| {
        const ok = std.ascii.isAlphanumeric(c) or c == '/' or c == '_' or c == '-' or c == '.' or c == '~';
        if (!ok) return false;
    }
    return true;
}

pub fn launchCommand(out: []u8, session: []const u8, cwd: []const u8, sid: []const u8) ?[]const u8 {
    if (!safeName(session) or !safePath(cwd) or !safeSessionId(sid)) return null;
    return std.fmt.bufPrint(out, "tmux new-session -d -s {s} -c {s} 2>/dev/null; python3 {s} host enable claude {s} --tmux {s} --cwd {s} >/dev/null 2>&1; python3 {s} host start claude {s} --tmux {s} --cwd {s} >/dev/null 2>&1; tmux attach -t {s}", .{ session, cwd, READER, sid, session, cwd, READER, sid, session, cwd, session }) catch null;
}

test "IGSH-1266 session ids are version four uuids" {
    var out: [36]u8 = undefined;
    const random = [_]u8{0xff} ** 16;
    const id = formatSessionId(&out, &random);
    try std.testing.expectEqual(@as(usize, 36), id.len);
    try std.testing.expectEqualStrings("ffffffff-ffff-4fff-bfff-ffffffffffff", id);
    try std.testing.expect(safeSessionId(id));
    try std.testing.expect(!safeSessionId("ffffffff-ffff-4fff-bfff-fffffffffffg"));
    try std.testing.expect(!safeSessionId("short"));
}

test "IGSH-1266 new Claude sessions start on the app owned host" {
    try std.testing.expect(ENABLED);
    try std.testing.expect(eligible("claude"));
    try std.testing.expect(eligible("claude-code"));
    try std.testing.expect(!eligible("codex"));
    try std.testing.expect(!eligible("pi"));
    try std.testing.expect(!eligible(""));
    try std.testing.expect(!eligible("bash"));
}

test "IGSH-1266 host start types nothing into a pane and names the reader" {
    var out: [1024]u8 = undefined;
    const command = launchCommand(&out, "term-abc", "~/projects", "ffffffff-ffff-4fff-bfff-ffffffffffff") orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.startsWith(u8, command, "tmux new-session -d -s term-abc -c ~/projects"));
    try std.testing.expect(std.mem.indexOf(u8, command, "host enable claude ffffffff-ffff-4fff-bfff-ffffffffffff --tmux term-abc --cwd ~/projects") != null);
    try std.testing.expect(std.mem.indexOf(u8, command, "host start claude ffffffff-ffff-4fff-bfff-ffffffffffff --tmux term-abc --cwd ~/projects") != null);
    try std.testing.expect(std.mem.indexOf(u8, command, "send-keys") == null);
    try std.testing.expect(std.mem.indexOf(u8, command, "reader.py") != null);
    try std.testing.expect(launchCommand(&out, "term-abc", "~/projects", "bad") == null);
    try std.testing.expect(launchCommand(&out, "term-a;b", "~/projects", "ffffffff-ffff-4fff-bfff-ffffffffffff") == null);
    try std.testing.expect(launchCommand(&out, "term-abc", "~/pro jects", "ffffffff-ffff-4fff-bfff-ffffffffffff") == null);
}
