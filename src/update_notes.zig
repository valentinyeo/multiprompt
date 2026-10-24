const std = @import("std");
const versionNewer = @import("update_check.zig").versionNewer;

pub const Release = struct { version: []const u8, changes: []const []const u8 };
pub const Document = struct { version: []const u8, releases: []const Release };
pub const Notes = struct {
    lines: [5][512]u8 = @splat(@splat(0)),
    lengths: [5]usize = @splat(0),
    count: usize = 0,
    total: usize = 0,

    pub fn line(self: *const Notes, i: usize) []const u8 {
        return self.lines[i][0..self.lengths[i]];
    }

    pub fn more(self: *const Notes, buf: []u8) []const u8 {
        if (self.total <= self.count) return "";
        return std.fmt.bufPrint(buf, "+{d} more", .{self.total - self.count}) catch "";
    }
};

pub fn plain(text: []const u8) bool {
    if (text.len == 0 or text.len > 512 or !std.unicode.utf8ValidateSlice(text)) return false;
    for (text, 0..) |c, i| {
        if (c < 32 or c == 127 or c == '/' or c == '\\' or c == '`') return false;
        for ([_][]const u8{ "PR ", "pull request " }) |prefix| {
            if (i + prefix.len < text.len and std.ascii.eqlIgnoreCase(text[i .. i + prefix.len], prefix)) {
                const rest = std.mem.trimStart(u8, text[i + prefix.len ..], " #");
                if (rest.len > 0 and std.ascii.isDigit(rest[0])) return false;
            }
        }
        if (c == '#' and i + 1 < text.len and std.ascii.isDigit(text[i + 1])) return false;
        if (c == '-' and i + 1 < text.len and std.ascii.isDigit(text[i + 1])) {
            var start = i;
            while (start > 0 and std.ascii.isUpper(text[start - 1])) start -= 1;
            if (start < i) return false;
        }
        if (c == '.' and i > 0 and i + 1 < text.len and std.ascii.isAlphanumeric(text[i - 1]) and std.ascii.isAlphabetic(text[i + 1])) return false;
    }
    return true;
}

pub fn pick(releases: []const Release, installed: []const u8, offered: []const u8) Notes {
    var result = Notes{};
    var versions: [5][]const u8 = undefined;
    for (releases) |release| {
        if (!versionNewer(installed, release.version) or versionNewer(offered, release.version)) continue;
        for (release.changes) |raw| {
            const text = std.mem.trim(u8, raw, " \t\r\n");
            if (!plain(text)) continue;
            result.total += 1;
            var at: usize = 0;
            while (at < result.count and !versionNewer(versions[at], release.version)) at += 1;
            if (at == result.lines.len) continue;
            var end = @min(result.count, result.lines.len - 1);
            while (end > at) : (end -= 1) {
                result.lines[end] = result.lines[end - 1];
                result.lengths[end] = result.lengths[end - 1];
                versions[end] = versions[end - 1];
            }
            @memcpy(result.lines[at][0..text.len], text);
            result.lengths[at] = text.len;
            versions[at] = release.version;
            result.count = @min(result.count + 1, result.lines.len);
        }
    }
    return result;
}

test "IGSH-728 picks only versions between installed and offered, newest first" {
    const releases = [_]Release{
        .{ .version = "1.9.0", .changes = &.{"Already installed."} },
        .{ .version = "1.10.0", .changes = &.{"Older change."} },
        .{ .version = "2.0.0", .changes = &.{"Not offered yet."} },
        .{ .version = "1.11.0", .changes = &.{ "Newest change.", "Another new change." } },
    };
    const notes = pick(&releases, "1.9.0", "1.11.0");
    try std.testing.expectEqual(@as(usize, 3), notes.count);
    try std.testing.expectEqualStrings("Newest change.", notes.line(0));
    try std.testing.expectEqualStrings("Another new change.", notes.line(1));
    try std.testing.expectEqualStrings("Older change.", notes.line(2));
    try std.testing.expectEqual(@as(usize, 0), pick(&releases, "1.11.0", "1.9.0").count);
}

test "IGSH-728 shows at most five lines then +N more" {
    const releases = [_]Release{.{ .version = "1.1.0", .changes = &.{ "One.", "Two.", "Three.", "Four.", "Five.", "Six.", "Seven." } }};
    const notes = pick(&releases, "1.0.0", "1.1.0");
    try std.testing.expectEqual(@as(usize, 5), notes.count);
    try std.testing.expectEqualStrings("Five.", notes.line(4));
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("+2 more", notes.more(&buf));
    try std.testing.expectEqualStrings("", (Notes{}).more(&buf));
}

test "IGSH-728 skips ticket ids, file paths, file names and PR numbers" {
    const releases = [_]Release{.{ .version = "1.1.0", .changes = &.{ "Fix IGSH-123.", "Fix src/main.zig.", "Fix C:\\app\\settings.", "Fix update.zig.", "Fix PR #12.", "Fix PR 12.", "Typing feels faster." } }};
    const notes = pick(&releases, "1.0.0", "1.1.0");
    try std.testing.expectEqual(@as(usize, 1), notes.total);
    try std.testing.expectEqualStrings("Typing feels faster.", notes.line(0));
}
