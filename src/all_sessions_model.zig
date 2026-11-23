const std = @import("std");

pub const Kind = enum(u8) { open, hidden, reminder, vps_only, archived };

pub const Row = struct {
    kind: Kind = .open,
    shell_id: u32 = 0,
    ref_idx: u32 = 0,
    snapshot_order: ?u32 = null,
    snapshot_name: [256]u8 = @splat(0),
    snapshot_name_len: u32 = 0,
    snapshot_favorite: bool = false,
    host: u8 = 0,
    activity: u8 = 0,
    attention: bool = false,
    last_active: u64 = 0,
    name: [96]u8 = std.mem.zeroes([96]u8),
    name_len: u32 = 0,
    session: [64]u8 = std.mem.zeroes([64]u8),
    session_len: u32 = 0,
    context: [64]u8 = std.mem.zeroes([64]u8),
    context_len: u32 = 0,
    workspace: u8 = 0,
    ram_mb: u32 = 0,
    agent: u8 = 0,
    stale_candidate: bool = false,
    preview: [96]u8 = @splat(0),
    preview_len: u32 = 0,
    favorite: bool = false,
    frequent: bool = false,
};


pub const RunState = enum { running, no_window, archived };
pub const Group = enum { waiting, today, earlier };
pub const Selection = struct {
    state: ?RunState = null,
    host: ?u8 = null,
    tab: u32 = 200,
};

pub fn runState(row: Row) RunState {
    return switch (row.kind) {
        .open, .hidden => .running,
        .reminder, .vps_only => .no_window,
        .archived => .archived,
    };
}

pub fn stateLabel(state: RunState) []const u8 {
    return switch (state) {
        .running => "Running",
        .no_window => "No window",
        .archived => "Archived",
    };
}

pub fn inTab(row: Row, tab: u32) bool {
    return switch (tab) {
        200 => true,
        201 => row.workspace == 255,
        202 => row.attention and row.kind != .archived,
        203 => row.kind == .archived,
        204 => row.frequent,
        205 => row.favorite,
        else => row.workspace == tab,
    };
}

pub fn matches(row: Row, selection: Selection) bool {
    if (selection.host) |host| if (row.host != host) return false;
    if (selection.state) |state| if (runState(row) != state) return false;
    return inTab(row, selection.tab);
}

pub fn count(rows: []const Row, selection: Selection) u32 {
    var total: u32 = 0;
    for (rows) |row| if (matches(row, selection)) {
        total += 1;
    };
    return total;
}

pub fn serverCount(rows: []const Row) u32 {
    var hosts = [_]bool{false} ** 256;
    var total: u32 = 0;
    for (rows) |row| {
        if (runState(row) == .archived or hosts[row.host]) continue;
        hosts[row.host] = true;
        total += 1;
    }
    return total;
}

pub fn group(row: Row, today: u64) Group {
    if (row.attention and row.kind != .archived) return .waiting;
    return if (row.last_active >= today and row.last_active != 0) .today else .earlier;
}

pub fn less(today: u64, a: Row, b: Row) bool {
    const ga = @intFromEnum(group(a, today));
    const gb = @intFromEnum(group(b, today));
    if (ga != gb) return ga < gb;
    if (a.last_active != b.last_active) return a.last_active > b.last_active;
    const name_order = std.ascii.orderIgnoreCase(a.name[0..a.name_len], b.name[0..b.name_len]);
    if (name_order != .eq) return name_order == .lt;
    if (a.host != b.host) return a.host < b.host;
    return std.mem.order(u8, a.session[0..a.session_len], b.session[0..b.session_len]) == .lt;
}

pub fn deduplicate(rows: []Row) usize {
    var len: usize = 0;
    for (rows) |row| {
        var found: ?usize = null;
        for (rows[0..len], 0..) |previous, i| {
            if (row.session_len != 0 and row.host == previous.host and std.ascii.eqlIgnoreCase(row.session[0..row.session_len], previous.session[0..previous.session_len])) {
                found = i;
                break;
            }
        }
        if (found) |i| {
            if (@intFromEnum(runState(row)) < @intFromEnum(runState(rows[i]))) rows[i] = row;
        } else {
            rows[len] = row;
            len += 1;
        }
    }
    return len;
}

pub fn highMemory(row: Row) bool {
    return runState(row) != .archived and row.ram_mb >= 400;
}
