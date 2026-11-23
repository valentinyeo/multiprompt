const std = @import("std");
const files = @import("file_io.zig");

const Entry = struct {
    host: u8,
    session: [64]u8 = @splat(0),
    len: u32,
    starred: ?bool = null,
    preview: [96]u8 = @splat(0),
    preview_len: u32 = 0,
    last_active: u64 = 0,
};
var entries: std.ArrayList(Entry) = .empty;
var loaded = false;

fn path(out: *[512]u8) ?[]const u8 {
    var dir: [512]u8 = undefined;
    const base = @import("session.zig").getSessionDir(&dir) orelse return null;
    return std.fmt.bufPrint(out, "{s}\\all-sessions.json", .{base}) catch null;
}

fn load() void {
    if (loaded) return;
    loaded = true;
    var buf: [512]u8 = undefined;
    const name = path(&buf) orelse return;
    const bytes = files.readFileAllocWin32(name, 1024 * 1024) orelse return;
    defer std.heap.page_allocator.free(bytes);
    const parsed = std.json.parseFromSlice([]Entry, std.heap.page_allocator, bytes, .{}) catch return;
    defer parsed.deinit();
    for (parsed.value) |entry| {
        if (entry.len == 0 or entry.len > entry.session.len) continue;
        entries.append(std.heap.page_allocator, entry) catch return;
    }
}

pub fn get(host: u8, session: []const u8) ?bool {
    load();
    for (entries.items) |entry| {
        if (entry.host == host and std.ascii.eqlIgnoreCase(entry.session[0..entry.len], session)) return entry.starred;
    }
    return null;
}

pub fn set(host: u8, session: []const u8, starred: bool) bool {
    load();
    if (session.len == 0 or session.len > 64) return false;
    var index: ?usize = null;
    for (entries.items, 0..) |entry, i| {
        if (entry.host == host and std.ascii.eqlIgnoreCase(entry.session[0..entry.len], session)) {
            index = i;
            break;
        }
    }
    const old = if (index) |i| entries.items[i].starred else null;
    if (index) |i| {
        entries.items[i].starred = starred;
    } else {
        var entry = Entry{ .host = host, .len = @intCast(session.len), .starred = starred };
        @memcpy(entry.session[0..session.len], session);
        entries.append(std.heap.page_allocator, entry) catch return false;
    }
    const ok = save();
    if (!ok) {
        if (index) |i| {
            entries.items[i].starred = old;
        } else {
            _ = entries.pop();
        }
    }
    return ok;
}

fn save() bool {
    var buf: [512]u8 = undefined;
    const name = path(&buf) orelse return false;
    const bytes = std.json.Stringify.valueAlloc(std.heap.page_allocator, entries.items, .{}) catch return false;
    defer std.heap.page_allocator.free(bytes);
    return files.writeFileAtomicW(name, bytes);
}

pub fn remember(row: @import("all_sessions_model.zig").Row) bool {
    load();
    var index: ?usize = null;
    for (entries.items, 0..) |entry, i| {
        if (entry.host == row.host and std.ascii.eqlIgnoreCase(entry.session[0..entry.len], row.session[0..row.session_len])) {
            index = i;
            break;
        }
    }
    if (index == null) {
        entries.append(std.heap.page_allocator, .{ .host = row.host, .session = row.session, .len = row.session_len }) catch return false;
        index = entries.items.len - 1;
    }
    const entry = &entries.items[index.?];
    entry.starred = row.favorite;
    entry.preview = row.preview;
    entry.preview_len = row.preview_len;
    entry.last_active = row.last_active;
    return save();
}

pub fn restore(row: *@import("all_sessions_model.zig").Row) void {
    load();
    for (entries.items) |entry| {
        if (entry.host != row.host or !std.ascii.eqlIgnoreCase(entry.session[0..entry.len], row.session[0..row.session_len])) continue;
        if (row.preview_len == 0 and entry.preview_len <= row.preview.len) {
            row.preview = entry.preview;
            row.preview_len = entry.preview_len;
        }
        if (row.last_active == 0) row.last_active = entry.last_active;
        return;
    }
}
