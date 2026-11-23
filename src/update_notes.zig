const std = @import("std");
const versionNewer = @import("update_check.zig").versionNewer;

pub const Release = struct { version: []const u8, changes: []const []const u8 };
pub const Document = struct { version: []const u8, releases: []const Release };
pub const COLLAPSED_LINES = 3;

pub const Notes = struct {
    lines: [16][512]u8 = @splat(@splat(0)),
    lengths: [16]usize = @splat(0),
    count: usize = 0,
    total: usize = 0,

    pub fn shown(self: *const Notes, expanded: bool) usize {
        return if (expanded) self.count else @min(self.count, COLLAPSED_LINES);
    }

    pub fn hidden(self: *const Notes, expanded: bool) usize {
        return self.total - self.shown(expanded);
    }

    pub fn line(self: *const Notes, i: usize) []const u8 {
        return self.lines[i][0..self.lengths[i]];
    }

    pub fn more(self: *const Notes, buf: []u8, expanded: bool) []const u8 {
        const rest = self.hidden(expanded);
        if (rest == 0) return "";
        return std.fmt.bufPrint(buf, "and {d} more", .{rest}) catch "";
    }
};

pub fn plain(text: []const u8) bool {
    if (text.len == 0 or text.len > 512 or !std.unicode.utf8ValidateSlice(text)) return false;
    const prefix: usize = if (std.mem.startsWith(u8, text, "IGSH-")) 5 else if (std.mem.startsWith(u8, text, "HYCI-")) 5 else return false;
    if (text.len <= prefix or text[prefix] < '1' or text[prefix] > '9') return false;
    var i = prefix;
    while (i < text.len and std.ascii.isDigit(text[i])) : (i += 1) {}
    if (i + 1 >= text.len or text[i] != ' ' or text[i + 1] == ' ' or text[text.len - 1] == ' ') return false;
    for (text) |c| if (c < 32 or c == 127) return false;
    if (std.ascii.indexOfIgnoreCase(text[i + 1 ..], "Checks and fixes, no visible change") != null) return false;
    return true;
}

pub fn pick(releases: []const Release, installed: []const u8, offered: []const u8) Notes {
    var result = Notes{};
    var versions: [16][]const u8 = undefined;
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

test "ticket titles and skipped releases retain newest-first order" {
    const releases = [_]Release{
        .{ .version = "1.9.0", .changes = &.{"IGSH-1 Already installed"} },
        .{ .version = "1.10.0", .changes = &.{"IGSH-2 Older change"} },
        .{ .version = "2.0.0", .changes = &.{"IGSH-3 Not offered"} },
        .{ .version = "1.11.0", .changes = &.{ "IGSH-4 Newest change", "HYCI-5 Another change" } },
    };
    const notes = pick(&releases, "1.9.0", "1.11.0");
    try std.testing.expectEqual(@as(usize, 3), notes.count);
    try std.testing.expectEqualStrings("IGSH-4 Newest change", notes.line(0));
    try std.testing.expectEqualStrings("HYCI-5 Another change", notes.line(1));
    try std.testing.expectEqualStrings("IGSH-2 Older change", notes.line(2));
    try std.testing.expectEqual(@as(usize, 0), pick(&releases, "1.11.0", "1.9.0").count);
}

test "invalid notes and filler are not displayed" {
    const releases = [_]Release{.{ .version = "1.1.0", .changes = &.{ "Old unnumbered note", "IGSH-0 Bad", "IGSH-12 ", "IGSH-12 Checks and fixes, no visible change", "IGSH-12 Valid café" } }};
    const notes = pick(&releases, "1.0.0", "1.1.0");
    try std.testing.expectEqual(@as(usize, 1), notes.count);
    try std.testing.expectEqualStrings("IGSH-12 Valid café", notes.line(0));
}

test "capacity counts notes beyond the first sixteen" {
    const releases = [_]Release{.{ .version = "1.1.0", .changes = &.{ "IGSH-1 One", "IGSH-2 Two", "IGSH-3 Three", "IGSH-4 Four", "IGSH-5 Five", "IGSH-6 Six", "IGSH-7 Seven", "IGSH-8 Eight", "IGSH-9 Nine", "IGSH-10 Ten", "IGSH-11 Eleven", "IGSH-12 Twelve", "IGSH-13 Thirteen", "IGSH-14 Fourteen", "IGSH-15 Fifteen", "IGSH-16 Sixteen", "IGSH-17 Seventeen", "IGSH-18 Eighteen" } }};
    const notes = pick(&releases, "1.0.0", "1.1.0");
    try std.testing.expectEqual(@as(usize, 16), notes.count);
    try std.testing.expectEqual(@as(usize, 18), notes.total);
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("and 15 more", notes.more(&buf, false));
    try std.testing.expectEqualStrings("and 2 more", notes.more(&buf, true));
}

test "collapsed and expanded counts retain omitted items" {
    const releases = [_]Release{.{ .version = "1.1.0", .changes = &.{ "IGSH-1 One", "IGSH-2 Two", "IGSH-3 Three", "IGSH-4 Four" } }};
    const notes = pick(&releases, "1.0.0", "1.1.0");
    try std.testing.expectEqual(@as(usize, 3), notes.shown(false));
    try std.testing.expectEqual(@as(usize, 4), notes.shown(true));
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("and 1 more", notes.more(&buf, false));
    try std.testing.expectEqualStrings("", notes.more(&buf, true));
}
