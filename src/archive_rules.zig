const std = @import("std");
const voice_filter = @import("voice_filter.zig");

pub const Content = struct {
    rows: [64]u64 = [_]u64{0} ** 64,
    len: u8 = 0,

    pub fn add(self: *Content, raw: []const u16, status_bar: bool, idle_prompt: bool, working: bool) void {
        if (status_bar or idle_prompt or working or voice_filter.isClaudeChrome(raw)) return;
        var start: usize = 0;
        var end = raw.len;
        while (start < end and (raw[start] == ' ' or raw[start] == 0 or raw[start] == '\t')) start += 1;
        while (end > start and (raw[end - 1] == ' ' or raw[end - 1] == 0 or raw[end - 1] == '\t')) end -= 1;
        if (start == end) return;
        var hash = std.hash.Wyhash.init(0);
        for (raw[start..end]) |ch| {
            if (ch == 0) continue;
            hash.update(std.mem.asBytes(&ch));
        }
        const value = hash.final();
        if (self.len < self.rows.len) {
            self.rows[self.len] = value;
            self.len += 1;
        }
    }

    pub fn hasNewRows(self: *const Content, current: *const Content) bool {
        for (current.rows[0..current.len], 0..) |row, index| {
            var prior: usize = 0;
            for (current.rows[0..index]) |old| if (old == row) {
                prior += 1;
            };
            var baseline_count: usize = 0;
            for (self.rows[0..self.len]) |old| if (old == row) {
                baseline_count += 1;
            };
            if (prior >= baseline_count) return true;
        }
        return false;
    }
};

pub fn doneHasActivity(last_done: u64, active: bool, baseline: ?*const Content, current: ?*const Content) bool {
    if (active) return true;
    const rows = current orelse return false;
    if (baseline) |prior| return prior.hasNewRows(rows);
    return last_done == 0 and rows.len > 0;
}

pub fn hidePendingInboxArchive(owner: usize, sid: u32, pending_owner: usize, pending_sid: u32, deadline_tick: u64, now_tick: u64) bool {
    return owner != 0 and owner == pending_owner and sid == pending_sid and now_tick < deadline_tick;
}

test "pending Inbox archive filters only the same owner and shell until expiry" {
    try std.testing.expect(hidePendingInboxArchive(10, 42, 10, 42, 20_000, 11_000));
    try std.testing.expect(!hidePendingInboxArchive(11, 42, 10, 42, 20_000, 11_000));
    try std.testing.expect(!hidePendingInboxArchive(10, 43, 10, 42, 20_000, 11_000));
    try std.testing.expect(!hidePendingInboxArchive(10, 42, 10, 42, 20_000, 20_000));
}

pub const Reason = enum { none, new_turn, new_output };

pub fn returnReason(archive_time: u64, last_done: u64, active_time: u64, baseline: *const Content, current: *const Content) Reason {
    if (archive_time == 0 or !baseline.hasNewRows(current)) return .none;
    if (active_time > archive_time and active_time > last_done) return .new_turn;
    return .new_output;
}

test "self-resumed 26-minute turn without ACTIVE earns DONE only after output" {
    var prior = Content{};
    prior.add(std.unicode.utf8ToUtf16LeStringLiteral("Previous reply"), false, false, false);
    var current = prior;
    const last_done: u64 = 100;
    try std.testing.expect(!doneHasActivity(last_done, false, &prior, &current));
    current.add(std.unicode.utf8ToUtf16LeStringLiteral("Working (25m 51s)"), false, false, true);
    try std.testing.expect(!doneHasActivity(last_done, false, &prior, &current));
    current.add(std.unicode.utf8ToUtf16LeStringLiteral("Final reply after 26 minutes"), false, false, false);
    try std.testing.expect(doneHasActivity(last_done, false, &prior, &current));
    try std.testing.expectEqual(Reason.new_output, returnReason(105, last_done, 0, &prior, &current));
    prior = current;
    try std.testing.expect(!doneHasActivity(130, false, &prior, &current));
    try std.testing.expect(doneHasActivity(130, true, &prior, &current));
}

test "only new content returns a filed session" {
    var baseline = Content{};
    const old = [_]u16{ 'R', 'e', 'p', 'l', 'y' };
    baseline.add(&old, false, false, false);
    var current = baseline;
    try std.testing.expectEqual(Reason.none, returnReason(100, 99, 0, &baseline, &current));
    try std.testing.expectEqual(Reason.none, returnReason(100, 99, 101, &baseline, &current));
    const status = [_]u16{ '1', '2', ':', '3', '0' };
    current.add(&status, true, false, false);
    try std.testing.expectEqual(Reason.none, returnReason(100, 99, 101, &baseline, &current));
    const spinner = [_]u16{ '*', ' ', 'W', 'h', 'i', 's', 'k', 'i', 'n', 'g', 0x2026, ' ', '(', '5', 'm', ' ', '3', '1', 's', ' ', 0x00b7, ' ', '2', '0', '0', ' ', 't', 'o', 'k', 'e', 'n', 's', ')' };
    current.add(&spinner, false, false, false);
    try std.testing.expectEqual(Reason.none, returnReason(100, 99, 101, &baseline, &current));
    const reply = [_]u16{ 'N', 'e', 'w', ' ', 'r', 'e', 'p', 'l', 'y' };
    current.add(&reply, false, false, false);
    try std.testing.expectEqual(Reason.new_output, returnReason(100, 99, 0, &baseline, &current));
    try std.testing.expectEqual(Reason.new_turn, returnReason(100, 99, 101, &baseline, &current));
    try std.testing.expectEqual(Reason.none, returnReason(0, 99, 101, &baseline, &current));
}

test "carried ETA and duplicate completion after filing need new console content" {
    var filed = Content{};
    const reply = [_]u16{ 'R', 'e', 'p', 'l', 'y' };
    filed.add(&reply, false, false, false);
    var current = filed;
    const archive_time: u64 = 100;
    try std.testing.expectEqual(Reason.none, returnReason(archive_time, 90, 0, &filed, &current));
    try std.testing.expectEqual(Reason.none, returnReason(archive_time, 110, 0, &filed, &current));
    try std.testing.expectEqual(Reason.none, returnReason(archive_time, 110, 120, &filed, &current));
    const spinner = [_]u16{ '*', ' ', 'W', 'o', 'r', 'k', 'i', 'n', 'g' };
    current.add(&spinner, false, false, true);
    try std.testing.expectEqual(Reason.none, returnReason(archive_time, 110, 120, &filed, &current));
    const new_reply = [_]u16{ 'N', 'e', 'w', ' ', 'r', 'e', 'p', 'l', 'y' };
    current.add(&new_reply, false, false, false);
    try std.testing.expectEqual(Reason.new_turn, returnReason(archive_time, 110, 120, &filed, &current));
}

test "self-resumed turn stays filed until its later DONE has new output" {
    var filed = Content{};
    const old_reply = [_]u16{ 'O', 'l', 'd' };
    filed.add(&old_reply, false, false, false);
    var current = filed;
    try std.testing.expectEqual(Reason.none, returnReason(100, 90, 120, &filed, &current));
    const spinner = [_]u16{ '*', ' ', 'W', 'o', 'r', 'k', 'i', 'n', 'g' };
    current.add(&spinner, false, false, true);
    try std.testing.expectEqual(Reason.none, returnReason(100, 130, 120, &filed, &current));
    const new_reply = [_]u16{ 'N', 'e', 'w' };
    current.add(&new_reply, false, false, false);
    try std.testing.expectEqual(Reason.new_turn, returnReason(100, 90, 120, &filed, &current));
}

test "screen movement and status rows do not count as new content" {
    var baseline = Content{};
    const a = [_]u16{'a'};
    const b = [_]u16{'b'};
    baseline.add(&a, false, false, false);
    baseline.add(&b, false, false, false);
    var moved = Content{};
    moved.add(&b, false, false, false);
    moved.add(&a, false, false, false);
    try std.testing.expect(!baseline.hasNewRows(&moved));
    var removed = Content{};
    removed.add(&b, false, false, false);
    try std.testing.expect(!baseline.hasNewRows(&removed));
    var repeated = baseline;
    repeated.add(&a, false, false, false);
    try std.testing.expect(baseline.hasNewRows(&repeated));
}
