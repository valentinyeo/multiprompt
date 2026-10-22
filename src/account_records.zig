const std = @import("std");
const layout = @import("session_layout.zig");
const Allocator = std.mem.Allocator;
const eq = std.mem.eql;

pub const poll_ms = 180000;
pub const max_records = 4096;
pub const retention_ms = 30 * 24 * 60 * 60 * 1000;
pub const Stamp = struct { updated_at: u64, device_id: []const u8 };
pub const Fields = struct { name: Stamp, manual: Stamp, favorite: Stamp, workspace: Stamp };
pub const Host = struct { slot: u8, name: []const u8, hostname: []const u8, port: u16, user: []const u8 };
pub const Kind = enum { host, workspace, session, settings };
pub const Record = struct {
    kind: Kind,
    id: []const u8,
    updated_at: u64,
    device_id: []const u8,
    deleted: bool = false,
    host: ?Host = null,
    workspace: ?layout.Workspace = null,
    session: ?layout.Tab = null,
    settings: ?layout.Settings = null,
    fields: ?Fields = null,
};
pub const State = struct {
    account: []const u8,
    initialized: bool = false,
    observed_at: u64 = 0,
    records: []const Record = &.{},
    local: layout.Layout = .{ .workspaces = &.{}, .tabs = &.{} },
};
pub const Documents = struct { records: []const Record, server_time: u64 = 0 };

fn identity(a: Allocator, record: Record) ![]const u8 {
    return switch (record.kind) {
        .host => try std.fmt.allocPrint(a, "{d}", .{(record.host orelse return error.InvalidRecord).slot}),
        .workspace => (record.workspace orelse return error.InvalidRecord).name,
        .session => blk: {
            const tab = record.session orelse return error.InvalidRecord;
            const id = try std.fmt.allocPrint(a, "{d}:{s}", .{ tab.tmux_host, tab.tmux_session });
            for (id) |*c| c.* = std.ascii.toLower(c.*);
            break :blk id;
        },
        .settings => "settings",
    };
}

fn same(a: Record, b: Record) bool {
    return a.kind == b.kind and eq(u8, a.id, b.id);
}

pub fn find(records: []const Record, record: Record) ?usize {
    for (records, 0..) |old, i| if (same(old, record)) return i;
    return null;
}

pub fn newer(a: Record, b: Record) bool {
    return a.updated_at > b.updated_at or (a.updated_at == b.updated_at and std.mem.order(u8, a.device_id, b.device_id) == .gt);
}

pub fn validate(a: Allocator, records: []const Record) !void {
    if (records.len > max_records) return error.RecordCapacity;
    for (records, 0..) |record, i| {
        if (record.updated_at == 0 or record.updated_at > 9_007_199_254_740_991 or record.device_id.len == 0 or record.device_id.len > 64 or record.id.len == 0 or record.id.len > 96) return error.InvalidRecord;
        for (record.device_id) |c| if (!std.ascii.isAlphanumeric(c) and c != '-' and c != '_') return error.InvalidRecord;
        for (records[0..i]) |old| if (same(old, record)) return error.InvalidRecord;
        const count = @as(u8, @intFromBool(record.host != null)) + @intFromBool(record.workspace != null) + @intFromBool(record.session != null) + @intFromBool(record.settings != null);
        if (record.fields) |fields| {
            if (record.kind != .session or record.deleted) return error.InvalidRecord;
            inline for (std.meta.fields(Fields)) |field| {
                const stamp = @field(fields, field.name);
                if (stamp.updated_at == 0 or stamp.updated_at > record.updated_at or stamp.device_id.len == 0 or stamp.device_id.len > 64) return error.InvalidRecord;
                for (stamp.device_id) |c| if (!std.ascii.isAlphanumeric(c) and c != '-' and c != '_') return error.InvalidRecord;
            }
        }
        if (record.deleted) {
            if (count != 0) return error.InvalidRecord;
            switch (record.kind) {
                .host => if (record.id.len != 1 or record.id[0] < '0' or record.id[0] > '2') return error.InvalidRecord,
                .workspace => {
                    if (record.id.len > 31) return error.InvalidRecord;
                    try layout.validate(.{ .workspaces = &.{.{ .name = record.id }}, .tabs = &.{} });
                },
                .session => {
                    if (record.id.len < 3 or record.id.len > 65 or record.id[0] < '0' or record.id[0] > '2' or record.id[1] != ':') return error.InvalidRecord;
                    for (record.id[2..]) |c| if ((!std.ascii.isLower(c) and !std.ascii.isDigit(c)) and c != '_' and c != '-') return error.InvalidRecord;
                },
                .settings => if (!eq(u8, record.id, "settings")) return error.InvalidRecord,
            }
            continue;
        }
        if (count != 1 or !eq(u8, record.id, try identity(a, record))) return error.InvalidRecord;
        switch (record.kind) {
            .host => {
                const h = record.host orelse return error.InvalidRecord;
                try @import("account_hosts.zig").validate(&.{.{ .slot = h.slot, .name = h.name, .hostname = h.hostname, .port = h.port, .user = h.user }});
            },
            .workspace => try layout.validate(.{ .workspaces = &.{record.workspace orelse return error.InvalidRecord}, .tabs = &.{} }),
            .session => {
                const tab = record.session orelse return error.InvalidRecord;
                try layout.validate(.{ .workspaces = &.{.{ .name = tab.workspace }}, .tabs = &.{tab} });
            },
            .settings => if (record.settings == null) return error.InvalidRecord,
        }
    }
}

pub fn merge(a: Allocator, left: []const Record, right: []const Record) ![]const Record {
    try validate(a, left);
    try validate(a, right);
    var result: std.ArrayList(Record) = .empty;
    try result.appendSlice(a, left);
    for (right) |incoming| {
        if (find(result.items, incoming)) |i| {
            if (incoming.kind == .session and !incoming.deleted and !result.items[i].deleted) {
                result.items[i] = try mergeSession(a, result.items[i], incoming);
            } else if (newer(incoming, result.items[i])) result.items[i] = incoming;
        } else try result.append(a, incoming);
    }
    if (result.items.len > max_records) return error.RecordCapacity;
    std.mem.sort(Record, result.items, {}, struct {
        fn less(_: void, x: Record, y: Record) bool {
            if (x.kind != y.kind) return @intFromEnum(x.kind) < @intFromEnum(y.kind);
            return std.mem.order(u8, x.id, y.id) == .lt;
        }
    }.less);
    return result.toOwnedSlice(a);
}

pub fn project(a: Allocator, value: layout.Layout, device: []const u8, stamp: u64) ![]const Record {
    try layout.validate(value);
    var records: std.ArrayList(Record) = .empty;
    for (value.hosts orelse &.{}) |host| try records.append(a, .{ .kind = .host, .id = "", .device_id = device, .updated_at = stamp, .host = .{ .slot = host.slot, .name = host.name, .hostname = host.hostname, .port = host.port, .user = host.user } });
    for (value.workspaces) |ws| try records.append(a, .{ .kind = .workspace, .id = "", .device_id = device, .updated_at = stamp, .workspace = ws });
    for (value.tabs) |tab| try records.append(a, .{ .kind = .session, .id = "", .device_id = device, .updated_at = stamp, .session = tab });
    if (value.settings) |settings| try records.append(a, .{ .kind = .settings, .id = "settings", .device_id = device, .updated_at = stamp, .settings = settings });
    for (records.items) |*record| record.id = try identity(a, record.*);
    return records.toOwnedSlice(a);
}

fn payloadEqual(a: Allocator, x: Record, y: Record) !bool {
    var left = x;
    var right = y;
    left.updated_at = 1;
    right.updated_at = 1;
    left.device_id = "device";
    right.device_id = "device";
    left.fields = null;
    right.fields = null;
    const l = try std.json.Stringify.valueAlloc(a, left, .{ .emit_null_optional_fields = false });
    defer a.free(l);
    const r = try std.json.Stringify.valueAlloc(a, right, .{ .emit_null_optional_fields = false });
    defer a.free(r);
    return eq(u8, l, r);
}

pub fn edit(a: Allocator, records: []const Record, base: layout.Layout, current: layout.Layout, device: []const u8, now: u64) ![]const Record {
    var stamp = @max(now, 1);
    for (records) |record| stamp = @max(stamp, record.updated_at + 1);
    const before = try project(a, base, device, stamp);
    const after = try project(a, current, device, stamp);
    var changed: std.ArrayList(Record) = .empty;
    for (after) |projected| {
        var record = projected;
        if (find(before, record)) |i| {
            if (try payloadEqual(a, before[i], record)) continue;
        }
        if (find(records, record)) |i| {
            if (try payloadEqual(a, records[i], record)) continue;
        }
        if (record.session) |current_tab| {
            const stamp_value = Stamp{ .updated_at = stamp, .device_id = device };
            var fields = Fields{ .name = stamp_value, .manual = stamp_value, .favorite = stamp_value, .workspace = stamp_value };
            if (find(records, record)) |i| {
                const old = records[i];
                if (old.session) |old_tab| {
                    const previous = if (find(before, record)) |j| before[j].session.? else old_tab;
                    const old_fields = fieldStamps(old);
                    inline for (std.meta.fields(Fields)) |field| {
                        const key = field.name;
                        const equal = if (@TypeOf(@field(current_tab, key)) == []const u8)
                            eq(u8, @field(current_tab, key), @field(previous, key))
                        else
                            @field(current_tab, key) == @field(previous, key);
                        if (equal) @field(fields, key) = @field(old_fields, key);
                    }
                }
            }
            record.fields = fields;
        }
        try changed.append(a, record);
    }
    for (before) |record| {
        if (find(after, record) != null) continue;
        if (find(records, record)) |i| {
            if (records[i].deleted) continue;
        }
        try changed.append(a, .{ .kind = record.kind, .id = record.id, .updated_at = stamp, .device_id = device, .deleted = true });
    }
    return merge(a, records, changed.items);
}

pub fn materialize(a: Allocator, records: []const Record) !layout.Layout {
    try validate(a, records);
    var hosts: std.ArrayList(layout.Host) = .empty;
    var workspaces: std.ArrayList(layout.Workspace) = .empty;
    var tabs: std.ArrayList(layout.Tab) = .empty;
    var settings: ?layout.Settings = null;
    for (records) |record| {
        if (record.deleted) continue;
        if (record.host) |h| try hosts.append(a, .{ .slot = h.slot, .name = h.name, .hostname = h.hostname, .port = h.port, .user = h.user });
        if (record.workspace) |ws| try workspaces.append(a, ws);
        if (record.settings) |s| settings = s;
    }
    for (records) |record| {
        if (record.deleted) continue;
        if (record.session) |tab| {
            for (workspaces.items) |ws| {
                if (!eq(u8, ws.name, tab.workspace)) continue;
                try tabs.append(a, tab);
                break;
            }
        }
    }
    const result = layout.Layout{ .hosts = try hosts.toOwnedSlice(a), .workspaces = try workspaces.toOwnedSlice(a), .tabs = try tabs.toOwnedSlice(a), .settings = settings };
    try layout.validate(result);
    return result;
}

pub fn needsPush(a: Allocator, local: []const Record, remote: []const Record) !bool {
    try validate(a, remote);
    for (local) |record| {
        const i = find(remote, record) orelse return true;
        if (newer(record, remote[i])) return true;
        if (!newer(remote[i], record) and !try payloadEqual(a, record, remote[i])) return true;
    }
    return false;
}

pub fn roundTrip(a: Allocator, sent: []const Record, received: []const Record) !void {
    try validate(a, received);
    for (sent) |record| {
        const i = find(received, record) orelse return error.UnprovenRoundTrip;
        const remote = received[i];
        if (newer(record, remote)) return error.UnprovenRoundTrip;
        if (!newer(remote, record) and !try payloadEqual(a, record, remote)) return error.UnprovenRoundTrip;
    }
}

pub fn rewriteHost(a: Allocator, config: []const u8, alias: []const u8, host: ?Host) ![]const u8 {
    if (!@import("account_hosts.zig").validHostname(alias)) return error.InvalidRecord;
    if (host == null) return a.dupe(u8, config);
    const h = host.?;
    try @import("account_hosts.zig").validate(&.{.{ .slot = h.slot, .name = h.name, .hostname = h.hostname, .port = h.port, .user = h.user }});
    const prefix = try std.fmt.allocPrint(a, "Host {s}\n  HostName {s}\n  Port {d}\n  User {s}\nHost *\n", .{ alias, h.hostname, h.port, h.user });
    if (std.mem.startsWith(u8, config, prefix)) return a.dupe(u8, config);
    return std.fmt.allocPrint(a, "{s}{s}", .{ prefix, config });
}

fn fieldStamps(record: Record) Fields {
    const stamp = Stamp{ .updated_at = record.updated_at, .device_id = record.device_id };
    return record.fields orelse .{ .name = stamp, .manual = stamp, .favorite = stamp, .workspace = stamp };
}

pub fn mergeSession(a: Allocator, left: Record, right: Record) !Record {
    var result = if (newer(right, left)) right else left;
    var tab = result.session.?;
    var fields = fieldStamps(result);
    const l = fieldStamps(left);
    const r = fieldStamps(right);
    inline for (std.meta.fields(Fields)) |field| {
        const ls = @field(l, field.name);
        const rs = @field(r, field.name);
        const use_right = rs.updated_at > ls.updated_at or (rs.updated_at == ls.updated_at and std.mem.order(u8, rs.device_id, ls.device_id) == .gt);
        @field(tab, field.name) = @field((if (use_right) right else left).session.?, field.name);
        @field(fields, field.name) = if (use_right) rs else ls;
    }
    tab.used = layout.maxUsed(left.session.?.used, right.session.?.used);
    tab.input = layout.maxUsed(left.session.?.input, right.session.?.input);
    tab.visits = try layout.mergeVisits(a, left.session.?.visits, right.session.?.visits);
    result.session = tab;
    result.fields = fields;
    return result;
}

pub fn prune(a: Allocator, records: []const Record, now: u64) ![]const Record {
    var kept: std.ArrayList(Record) = .empty;
    for (records) |record| {
        if (record.deleted and record.updated_at < now -| retention_ms) continue;
        try kept.append(a, record);
    }
    return kept.toOwnedSlice(a);
}

pub fn delta(a: Allocator, local: []const Record, remote: []const Record) ![]const Record {
    var changed: std.ArrayList(Record) = .empty;
    for (local) |record| {
        if (find(remote, record)) |i| {
            if (!newer(record, remote[i]) and try payloadEqual(a, record, remote[i])) continue;
            if (newer(remote[i], record)) continue;
        }
        try changed.append(a, record);
    }
    return changed.toOwnedSlice(a);
}

pub fn bootstrap(a: Allocator, state: *State, remote: []const Record, local: layout.Layout) !void {
    if (!state.initialized) {
        state.records = try a.dupe(Record, remote);
        state.local = local;
        state.initialized = true;
    }
}

pub fn deletionHistory(a: Allocator, records: []const Record, base: layout.Layout, current: layout.Layout, device: []const u8, now: u64) ![]const Record {
    const edited = try edit(a, records, base, current, device, now);
    var history: std.ArrayList(Record) = .empty;
    for (edited) |record| if (record.deleted) try history.append(a, record);
    return prune(a, history.items, now);
}

pub fn clockOffset(local: u64, server: u64) i64 {
    if (server == 0) return 0;
    return @as(i64, @intCast(server)) - @as(i64, @intCast(local));
}

test "ISSUE-252 record protocol scenarios" {
    _ = @import("account_records_test.zig");
}
