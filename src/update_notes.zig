const std = @import("std");
const versionNewer = @import("update_check.zig").versionNewer;

pub const Release = struct { version: []const u8, changes: []const []const u8 };
pub const Document = struct { version: []const u8, releases: []const Release };
pub const COLLAPSED_LINES = 3;
pub const MAX_LINES = 64;
pub const TICKET_KEYS = [_][]const u8{ "IGSH-", "MUBO-" };
pub const RELEASE_URL = "https://github.com/valentinyeo/multiprompt/releases/tag/v";

pub const Notes = struct {
    lines: [MAX_LINES][512]u8 = @splat(@splat(0)),
    lengths: [MAX_LINES]usize = @splat(0),
    ids: [MAX_LINES][16]u8 = @splat(@splat(0)),
    id_lengths: [MAX_LINES]usize = @splat(0),
    count: usize = 0,
    total: usize = 0,

    pub fn shown(self: *const Notes) usize {
        return @min(self.count, COLLAPSED_LINES);
    }

    pub fn line(self: *const Notes, i: usize) []const u8 {
        return self.lines[i][0..self.lengths[i]];
    }

    pub fn id(self: *const Notes, i: usize) []const u8 {
        return self.ids[i][0..self.id_lengths[i]];
    }
};

pub fn releaseUrl(buf: []u8, offered: []const u8) []const u8 {
    if (offered.len == 0) return "";
    return std.fmt.bufPrint(buf, RELEASE_URL ++ "{s}", .{offered}) catch "";
}

fn ticketKeyLength(text: []const u8) ?usize {
    for (TICKET_KEYS) |key| if (std.mem.startsWith(u8, text, key)) return key.len;
    return null;
}

fn titlePrefix(title: []const u8, prefix: []const u8) bool {
    return title.len >= prefix.len and std.ascii.eqlIgnoreCase(title[0..prefix.len], prefix);
}

fn hasWord(title: []const u8, word: []const u8) bool {
    var at: usize = 0;
    while (at + word.len <= title.len) {
        if (std.ascii.eqlIgnoreCase(title[at .. at + word.len], word)) {
            const before_ok = at == 0 or !std.ascii.isAlphanumeric(title[at - 1]);
            const after = at + word.len;
            const after_ok = after >= title.len or !std.ascii.isAlphanumeric(title[after]);
            if (before_ok and after_ok) return true;
        }
        at += 1;
    }
    return false;
}

fn productTitle(title: []const u8) bool {
    if (title.len == 0) return false;
    if (std.ascii.indexOfIgnoreCase(title, "behind the scenes") != null) return false;
    if (std.ascii.indexOfIgnoreCase(title, "latest improvements") != null) return false;
    const trimmed = std.mem.trim(u8, title, " \t\r\n");
    if (std.ascii.eqlIgnoreCase(trimmed, "various improvements") or
        std.ascii.eqlIgnoreCase(trimmed, "bug fixes") or
        std.ascii.eqlIgnoreCase(trimmed, "maintenance") or
        std.ascii.eqlIgnoreCase(trimmed, "improvements") or
        std.ascii.eqlIgnoreCase(trimmed, "fixes"))
        return false;
    const words = [_][]const u8{ "test", "tests", "proof", "proofs", "pipeline", "pipelines", "workflow", "workflows" };
    for (words) |word| if (hasWord(title, word)) return false;
    return true;
}

fn userFacingTitle(title: []const u8) bool {
    if (std.ascii.indexOfIgnoreCase(title, "Checks and fixes, no visible change") != null) return false;
    if (titlePrefix(title, "[INFRA] ") or
        titlePrefix(title, "Multiprompt verify: ") or
        titlePrefix(title, "Multiprompt verification playbook: ") or
        titlePrefix(title, "Release gate: ") or
        titlePrefix(title, "CI: "))
        return false;
    return productTitle(title);
}

pub fn plain(text: []const u8) bool {
    if (text.len == 0 or text.len > 512 or !std.unicode.utf8ValidateSlice(text)) return false;
    const prefix = ticketKeyLength(text) orelse return false;
    if (text.len <= prefix or text[prefix] < '1' or text[prefix] > '9') return false;
    var i = prefix;
    while (i < text.len and std.ascii.isDigit(text[i])) : (i += 1) {}
    if (i + 1 >= text.len or text[i] != ' ' or text[i + 1] == ' ' or text[text.len - 1] == ' ') return false;
    for (text) |c| if (c < 32 or c == 127) return false;
    return userFacingTitle(text[i + 1 ..]);
}

const Change = struct { id: []const u8, text: []const u8 };

fn productChange(text: []const u8) ?Change {
    if (!plain(text)) return null;
    const prefix = ticketKeyLength(text).?;
    var i = prefix;
    while (i < text.len and std.ascii.isDigit(text[i])) : (i += 1) {}
    return .{ .id = text[0..i], .text = text[i + 1 ..] };
}

pub fn pick(releases: []const Release, installed: []const u8, offered: []const u8) Notes {
    var result = Notes{};
    if (!versionNewer(installed, offered)) return result;
    for (releases) |release| {
        if (!std.mem.eql(u8, release.version, offered)) continue;
        for (release.changes) |raw| {
            const text = std.mem.trim(u8, raw, " \t\r\n");
            const change = productChange(text) orelse continue;
            result.total += 1;
            if (result.count == result.lines.len) continue;
            @memcpy(result.lines[result.count][0..change.text.len], change.text);
            result.lengths[result.count] = change.text.len;
            const id_len = @min(change.id.len, result.ids[result.count].len);
            @memcpy(result.ids[result.count][0..id_len], change.id[0..id_len]);
            result.id_lengths[result.count] = id_len;
            result.count += 1;
        }
    }
    return result;
}

test "only the offered release change lines reach the card" {
    const releases = [_]Release{
        .{ .version = "1.9.0", .changes = &.{"IGSH-1 Already installed"} },
        .{ .version = "1.10.0", .changes = &.{"IGSH-2 Older change"} },
        .{ .version = "2.0.0", .changes = &.{"IGSH-3 Not offered"} },
        .{ .version = "1.11.0", .changes = &.{ "IGSH-4 Newest change", "HYCI-5 Another change" } },
    };
    const notes = pick(&releases, "1.9.0", "1.11.0");
    try std.testing.expectEqual(@as(usize, 1), notes.count);
    try std.testing.expectEqual(@as(usize, 1), notes.total);
    try std.testing.expectEqualStrings("Newest change", notes.line(0));
    try std.testing.expectEqualStrings("IGSH-4", notes.id(0));
    try std.testing.expectEqual(@as(usize, 0), pick(&releases, "1.11.0", "1.9.0").count);
}

test "a release with no published change shows no lines instead of older changes" {
    const releases = [_]Release{
        .{ .version = "1.11.0", .changes = &.{ "IGSH-0 Bad", "IGSH-12 Checks and fixes, no visible change" } },
        .{ .version = "1.10.0", .changes = &.{"IGSH-2 Older change"} },
        .{ .version = "1.9.0", .changes = &.{"IGSH-1 Already installed"} },
    };
    const notes = pick(&releases, "1.9.0", "1.11.0");
    try std.testing.expectEqual(@as(usize, 0), notes.count);
    try std.testing.expectEqual(@as(usize, 0), notes.total);
    try std.testing.expectEqual(@as(usize, 0), notes.shown());
}

test "invalid notes and filler are not displayed" {
    const releases = [_]Release{.{ .version = "1.1.0", .changes = &.{ "Old unnumbered note", "IGSH-0 Bad", "IGSH-12 ", "IGSH-12 Checks and fixes, no visible change", "IGSH-12 Valid café" } }};
    const notes = pick(&releases, "1.0.0", "1.1.0");
    try std.testing.expectEqual(@as(usize, 1), notes.count);
    try std.testing.expectEqualStrings("Valid café", notes.line(0));
    try std.testing.expectEqualStrings("IGSH-12", notes.id(0));
}

test "capacity counts notes beyond the stored lines" {
    const releases = [_]Release{.{ .version = "1.1.0", .changes = &.{ "IGSH-1 One", "IGSH-2 Two", "IGSH-3 Three", "IGSH-4 Four", "IGSH-5 Five", "IGSH-6 Six", "IGSH-7 Seven", "IGSH-8 Eight", "IGSH-9 Nine", "IGSH-10 Ten", "IGSH-11 Eleven", "IGSH-12 Twelve", "IGSH-13 Thirteen", "IGSH-14 Fourteen", "IGSH-15 Fifteen", "IGSH-16 Sixteen", "IGSH-17 Seventeen", "IGSH-18 Eighteen" } }};
    const notes = pick(&releases, "1.0.0", "1.1.0");
    try std.testing.expectEqual(@as(usize, 18), notes.count);
    try std.testing.expectEqual(@as(usize, 18), notes.total);
    try std.testing.expectEqualStrings("Eighteen", notes.line(17));
    try std.testing.expectEqual(@as(usize, 3), notes.shown());
}

test "engineering ticket titles never reach the card" {
    const releases = [_]Release{.{ .version = "1.2.0", .changes = &.{
        "IGSH-900 Release gate: 3 launches on saved sessions must pass before every release",
        "IGSH-893 Multiprompt verify: chat-dictation journey hangs with no output for 25 minutes and has never run green 17/30",
        "HYCI-101 share one Windows app build cache",
        "IGSH-895 Chat View: pasting text adds an extra line break",
    } }};
    const notes = pick(&releases, "1.0.0", "1.2.0");
    try std.testing.expectEqual(@as(usize, 1), notes.count);
    try std.testing.expectEqualStrings("Chat View: pasting text adds an extra line break", notes.line(0));
    try std.testing.expectEqual(@as(usize, 1), notes.total);
}

test "three cards lines show by default and the extra changes stay counted" {
    const releases = [_]Release{.{ .version = "1.1.0", .changes = &.{ "IGSH-1 One", "IGSH-2 Two", "IGSH-3 Three", "IGSH-4 Four" } }};
    const notes = pick(&releases, "1.0.0", "1.1.0");
    try std.testing.expectEqual(@as(usize, 3), notes.shown());
    try std.testing.expectEqual(@as(usize, 4), notes.count);
    try std.testing.expectEqual(@as(usize, 4), notes.total);
}

test "one published change still links the full release notes" {
    const releases = [_]Release{.{ .version = "0.28.1985", .changes = &.{"MUBO-243 Poteto tab points at its chat from before a clear"} }};
    const notes = pick(&releases, "0.28.1984", "0.28.1985");
    try std.testing.expectEqual(@as(usize, 1), notes.shown());
    try std.testing.expectEqualStrings("Poteto tab points at its chat from before a clear", notes.line(0));
    var url: [128]u8 = undefined;
    try std.testing.expectEqualStrings("https://github.com/valentinyeo/multiprompt/releases/tag/v0.28.1985", releaseUrl(&url, "0.28.1985"));
    try std.testing.expectEqualStrings("", releaseUrl(&url, ""));
}

test "a release past the stored lines keeps every change behind the release notes link" {
    var texts: [70][24]u8 = undefined;
    var changes: [70][]const u8 = undefined;
    for (0..70) |i| changes[i] = std.fmt.bufPrint(&texts[i], "IGSH-{d} Change {d}", .{ i + 1, i + 1 }) catch unreachable;
    const releases = [_]Release{.{ .version = "1.1.0", .changes = &changes }};
    const notes = pick(&releases, "1.0.0", "1.1.0");
    try std.testing.expectEqual(@as(usize, 70), notes.total);
    try std.testing.expectEqual(@as(usize, MAX_LINES), notes.count);
    try std.testing.expectEqual(@as(usize, 3), notes.shown());
    try std.testing.expect(notes.total > notes.count);
}

test "published board keys reach the card and keep long Unicode notes whole" {
    const long = "Chats keep your place when the sidebar scrolls, the window resizes, the theme changes, and the keyboard is used across crowded workspaces with long names, café menus, and trailing ellipses… plus one more clause that keeps this line long";
    const releases = [_]Release{
        .{ .version = "1.2.0", .changes = &.{ "MUBO-243 Poteto tab points at its chat from before a clear", "MUBO-77 " ++ long } },
        .{ .version = "1.1.0", .changes = &.{"SOFT-2272 Cleared chats keep their new replies"} },
        .{ .version = "1.0.0", .changes = &.{"IGSH-12 Valid café"} },
    };
    const notes = pick(&releases, "0.9.0", "1.2.0");
    try std.testing.expectEqual(@as(usize, 2), notes.count);
    try std.testing.expectEqualStrings("Poteto tab points at its chat from before a clear", notes.line(0));
    try std.testing.expectEqualStrings(long, notes.line(1));
    try std.testing.expectEqualStrings("MUBO-243", notes.id(0));
    try std.testing.expectEqualStrings("MUBO-77", notes.id(1));
    try std.testing.expectEqual(@as(usize, 2), notes.shown());
}

test "MUBO-577 offered release never paints an older release change" {
    const parsed = try std.json.parseFromSlice(Document, std.testing.allocator, @embedFile("testdata/mubo-577-release-notes.json"), .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const newest = pick(parsed.value.releases, "0.28.1983", "0.28.1985");
    try std.testing.expectEqual(@as(usize, 1), newest.total);
    try std.testing.expectEqual(@as(usize, 1), newest.count);
    try std.testing.expectEqualStrings("Poteto tab points at its chat from before a clear", newest.line(0));
    try std.testing.expectEqualStrings("MUBO-243", newest.id(0));
    const older = pick(parsed.value.releases, "0.28.1983", "0.28.1984");
    try std.testing.expectEqual(@as(usize, 1), older.count);
    try std.testing.expectEqualStrings("Switch a chat to Antigravity and back", older.line(0));
    try std.testing.expectEqualStrings("IGSH-3050", older.id(0));
}

test "MUBO-577 real published release paints change lines for an available update" {
    const parsed = try std.json.parseFromSlice(Document, std.testing.allocator, @embedFile("testdata/mubo-577-release-notes.json"), .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings("0.28.1985", parsed.value.version);
    const newest = pick(parsed.value.releases, "0.28.1984", "0.28.1985");
    try std.testing.expectEqual(@as(usize, 1), newest.total);
    try std.testing.expectEqual(@as(usize, 1), newest.shown());
    try std.testing.expectEqualStrings("Poteto tab points at its chat from before a clear", newest.line(0));
    try std.testing.expectEqualStrings("MUBO-243", newest.id(0));
    var url: [128]u8 = undefined;
    try std.testing.expectEqualStrings("https://github.com/valentinyeo/multiprompt/releases/tag/v0.28.1985", releaseUrl(&url, "0.28.1985"));
    const month = pick(parsed.value.releases, "0.28.1900", "0.28.1961");
    try std.testing.expectEqual(@as(usize, 4), month.count);
    try std.testing.expectEqual(@as(usize, 3), month.shown());
    try std.testing.expectEqualStrings("Chats can list and message other chats in their workspace", month.line(0));
    try std.testing.expectEqualStrings("Wishes from any chat reach the Multi Bot board", month.line(3));
}
