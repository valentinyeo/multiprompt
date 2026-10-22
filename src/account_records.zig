const std = @import("std");
const layout = @import("session_layout.zig");
const Allocator = std.mem.Allocator;
const eq = std.mem.eql;

pub const poll_ms = 180000;
pub const max_records = 4096;
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
};
pub const State = struct {
    account: []const u8,
    records: []const Record = &.{},
    local: layout.Layout = .{ .workspaces = &.{}, .tabs = &.{} },
};
pub const Documents = struct { records: []const Record };

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
        if (record.deleted) {
            if (count != 0) return error.InvalidRecord;
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
            if (newer(incoming, result.items[i])) result.items[i] = incoming;
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
    for (after) |record| {
        if (find(before, record)) |i| {
            if (try payloadEqual(a, before[i], record)) continue;
        }
        if (find(records, record)) |i| {
            if (try payloadEqual(a, records[i], record)) continue;
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
    var output: std.ArrayList(u8) = .empty;
    var block: std.ArrayList(u8) = .empty;
    var header: []const u8 = "";
    var target = false;
    var lines = std.mem.splitScalar(u8, config, '\n');
    while (lines.next()) |line| {
        if (line.len == 0 and lines.peek() == null) break;
        var fields = std.mem.tokenizeAny(u8, std.mem.trim(u8, line, " \t\r"), " \t=");
        const key = fields.next() orelse "";
        if (std.ascii.eqlIgnoreCase(key, "Host") or std.ascii.eqlIgnoreCase(key, "Match")) {
            if (header.len > 0 and (!target or std.mem.trim(u8, block.items, " \t\r\n").len > 0)) {
                try output.appendSlice(a, header);
                try output.append(a, '\n');
            }
            try output.appendSlice(a, block.items);
            block.clearRetainingCapacity();
            header = line;
            target = false;
            if (std.ascii.eqlIgnoreCase(key, "Host")) {
                if (fields.next()) |value| target = std.ascii.eqlIgnoreCase(value, alias) and fields.next() == null;
            }
            continue;
        }
        if (target and (std.ascii.eqlIgnoreCase(key, "HostName") or std.ascii.eqlIgnoreCase(key, "Port") or std.ascii.eqlIgnoreCase(key, "User"))) continue;
        try block.appendSlice(a, line);
        try block.append(a, '\n');
    }
    if (header.len > 0 and (!target or std.mem.trim(u8, block.items, " \t\r\n").len > 0)) {
        try output.appendSlice(a, header);
        try output.append(a, '\n');
    }
    try output.appendSlice(a, block.items);
    const prefix = if (host) |h|
        try std.fmt.allocPrint(a, "Host {s}\n  HostName {s}\n  Port {d}\n  User {s}\nHost *\n", .{ alias, h.hostname, h.port, h.user })
    else
        try std.fmt.allocPrint(a, "Host {s}\n  HostName {s}\n  Port 22\nHost *\n", .{ alias, alias });
    try output.insertSlice(a, 0, prefix);
    return output.toOwnedSlice(a);
}

test "ISSUE-252 record protocol scenarios" {
    _ = @import("account_records_test.zig");
}
