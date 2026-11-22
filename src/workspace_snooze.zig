const std = @import("std");

pub fn due(due_at: u64, now: u64) bool {
    return due_at != 0 and due_at <= now;
}

pub fn belongsToWorkspace(member_due: u64, workspace_due: u64, member_id: []const u8, workspace_id: []const u8) bool {
    return member_due != 0 and member_due == workspace_due and std.mem.eql(u8, member_id, workspace_id);
}

pub fn nextVisible(active: u8, snoozed: []const bool) ?u8 {
    if (snoozed.len == 0) return null;
    for (1..snoozed.len) |step| {
        const slot: u8 = @intCast((@as(usize, active) + step) % snoozed.len);
        if (!snoozed[slot]) return slot;
    }
    return null;
}

test "due checks do not wake early" {
    try std.testing.expect(!due(0, 100));
    try std.testing.expect(!due(101, 100));
    try std.testing.expect(due(100, 100));
}

test "only members of the same workspace snooze wake together" {
    try std.testing.expect(belongsToWorkspace(100, 100, "client", "client"));
    try std.testing.expect(!belongsToWorkspace(0, 100, "client", "client"));
    try std.testing.expect(!belongsToWorkspace(90, 100, "client", "client"));
    try std.testing.expect(!belongsToWorkspace(100, 100, "other", "client"));
}

test "next visible wraps and refuses the only open workspace" {
    try std.testing.expectEqual(@as(?u8, 2), nextVisible(0, &.{ true, true, false }));
    try std.testing.expectEqual(@as(?u8, 0), nextVisible(2, &.{ false, true, true }));
    try std.testing.expectEqual(@as(?u8, null), nextVisible(0, &.{false}));
    try std.testing.expectEqual(@as(?u8, null), nextVisible(1, &.{ true, false, true }));
}

pub fn busyLocalTab(has_tmux: bool, active: bool, locked: bool) bool {
    return !has_tmux and (active or locked);
}

pub const ClaudeResume = enum { exact, continue_latest, fresh };

pub fn safeClaudeSessionId(sid: []const u8) bool {
    if (sid.len == 0) return false;
    for (sid) |c| {
        if (!std.ascii.isHex(c) and c != '-') return false;
    }
    return true;
}

fn sameWindowsFolder(a: []const u8, b: []const u8) bool {
    const left = std.mem.trimEnd(u8, a, "\\/");
    const right = std.mem.trimEnd(u8, b, "\\/");
    if (left.len != right.len) return false;
    for (left, right) |x, y| {
        if (std.ascii.toLower(if (x == '/') '\\' else x) != std.ascii.toLower(if (y == '/') '\\' else y)) return false;
    }
    return true;
}

pub fn claudeResume(sid: []const u8, folder: []const u8, occupied: []const []const u8) ClaudeResume {
    if (safeClaudeSessionId(sid)) return .exact;
    if (sid.len > 0 or folder.len == 0) return .fresh;
    for (occupied) |running_folder| {
        if (sameWindowsFolder(folder, running_folder)) return .fresh;
    }
    return .continue_latest;
}

pub fn publishedSlot(slot: u64, fallback: u32) u8 {
    return @intCast(if (slot < 9) slot else @min(fallback, 8));
}

pub fn mayReuseGroup(owner: ?u8, target: u8) bool {
    return owner != null and owner.? == target;
}

test "active or locked local tabs require snooze confirmation" {
    try std.testing.expect(busyLocalTab(false, true, false));
    try std.testing.expect(busyLocalTab(false, false, true));
    try std.testing.expect(!busyLocalTab(false, false, false));
    try std.testing.expect(!busyLocalTab(true, true, true));
}

test "Claude wake selects an exact session or only one latest per folder" {
    try std.testing.expectEqual(ClaudeResume.exact, claudeResume("12345678-abcd", "C:\\Repo", &.{"c:\\repo"}));
    try std.testing.expectEqual(ClaudeResume.fresh, claudeResume("bad id", "C:\\Repo", &.{}));
    try std.testing.expectEqual(ClaudeResume.continue_latest, claudeResume("", "C:\\Repo", &.{"C:\\Other"}));
    try std.testing.expectEqual(ClaudeResume.fresh, claudeResume("", "C:\\Repo", &.{"c:\\repo"}));
    try std.testing.expectEqual(ClaudeResume.fresh, claudeResume("", "C:\\Repo\\", &.{"c:/repo"}));
    try std.testing.expectEqual(ClaudeResume.fresh, claudeResume("", "", &.{}));
}

test "published slot keeps gaps left by hidden pills" {
    try std.testing.expectEqual(@as(u8, 3), publishedSlot(3, 1));
    try std.testing.expectEqual(@as(u8, 1), publishedSlot(99, 1));
}

test "group reuse requires a member in the target workspace" {
    try std.testing.expect(mayReuseGroup(2, 2));
    try std.testing.expect(!mayReuseGroup(1, 2));
    try std.testing.expect(!mayReuseGroup(null, 2));
}

pub const REBUILT_MARKER_TICKS: u64 = 100 * 365 * 86400 * 10_000_000;

pub const MarkerFix = enum { none, recreate, drop_flag };

pub fn markerFix(flagged: bool, has_marker: bool, has_snapshot: bool, live_tabs: bool) MarkerFix {
    if (!flagged or has_marker) return .none;
    if (live_tabs and !has_snapshot) return .drop_flag;
    return .recreate;
}

pub const Remote = struct { host: u8, name: []const u8 };

pub fn sameRemote(a: Remote, b: Remote) bool {
    return a.host == b.host and std.ascii.eqlIgnoreCase(a.name, b.name);
}

pub fn containsRemote(list: []const Remote, r: Remote) bool {
    for (list) |x| if (sameRemote(x, r)) return true;
    return false;
}

pub fn addUniqueRemote(out: []Remote, len: usize, r: Remote) usize {
    if (r.name.len == 0 or len >= out.len or containsRemote(out[0..len], r)) return len;
    out[len] = r;
    return len + 1;
}

pub fn bringBackPlan(recorded: []const Remote, live: []const Remote, open: []const Remote, out: []Remote) usize {
    var n: usize = 0;
    for (live) |l| {
        if (!containsRemote(recorded, l) or containsRemote(open, l)) continue;
        n = addUniqueRemote(out, n, l);
    }
    return n;
}

pub fn parseRecordLine(line: []const u8) ?Remote {
    const trimmed = std.mem.trim(u8, line, " \r\t");
    if (trimmed.len < 3 or trimmed[1] != ':' or trimmed[0] < '0' or trimmed[0] > '9') return null;
    return .{ .host = trimmed[0] - '0', .name = trimmed[2..] };
}

test "marker lost: flag without marker rebuilds it, with a snapshot or without" {
    try std.testing.expectEqual(MarkerFix.recreate, markerFix(true, false, true, false));
    try std.testing.expectEqual(MarkerFix.recreate, markerFix(true, false, false, false));
    try std.testing.expectEqual(MarkerFix.recreate, markerFix(true, false, true, true));
}

test "marker lost: nothing to fix when not flagged or marker present" {
    try std.testing.expectEqual(MarkerFix.none, markerFix(false, false, true, false));
    try std.testing.expectEqual(MarkerFix.none, markerFix(true, true, false, false));
}

test "marker lost: a stale flag on a workspace with live tabs and no snapshot is dropped" {
    try std.testing.expectEqual(MarkerFix.drop_flag, markerFix(true, false, false, true));
}

test "bring back skips sessions that are open anywhere and dedupes" {
    const recorded = [_]Remote{
        .{ .host = 0, .name = "remote-3" },
        .{ .host = 0, .name = "remote-3-2" },
        .{ .host = 0, .name = "remote-3-3" },
        .{ .host = 1, .name = "remote-3" },
    };
    const live = [_]Remote{
        .{ .host = 0, .name = "remote-3" },
        .{ .host = 0, .name = "REMOTE-3-2" },
        .{ .host = 0, .name = "remote-3-2" },
        .{ .host = 0, .name = "other" },
        .{ .host = 1, .name = "remote-3" },
    };
    const open = [_]Remote{.{ .host = 0, .name = "Remote-3" }};
    var out: [8]Remote = undefined;
    const n = bringBackPlan(&recorded, &live, &open, &out);
    try std.testing.expectEqual(@as(usize, 2), n);
    try std.testing.expectEqualStrings("REMOTE-3-2", out[0].name);
    try std.testing.expectEqual(@as(u8, 1), out[1].host);
}

test "bring back with nothing recorded or a full output buffer" {
    const live = [_]Remote{.{ .host = 0, .name = "a" }};
    var out: [1]Remote = undefined;
    try std.testing.expectEqual(@as(usize, 0), bringBackPlan(&.{}, &live, &.{}, &out));
    const rec = [_]Remote{ .{ .host = 0, .name = "a" }, .{ .host = 0, .name = "b" } };
    const live2 = [_]Remote{ .{ .host = 0, .name = "a" }, .{ .host = 0, .name = "b" } };
    try std.testing.expectEqual(@as(usize, 1), bringBackPlan(&rec, &live2, &.{}, &out));
}

test "record lines parse host and session, reject junk" {
    const r = parseRecordLine("0:remote-3-2\r").?;
    try std.testing.expectEqual(@as(u8, 0), r.host);
    try std.testing.expectEqualStrings("remote-3-2", r.name);
    try std.testing.expect(parseRecordLine("") == null);
    try std.testing.expect(parseRecordLine("x:abc") == null);
    try std.testing.expect(parseRecordLine("0:") == null);
    try std.testing.expect(parseRecordLine("12:abc") == null);
}
