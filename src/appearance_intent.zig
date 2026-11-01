const std = @import("std");
const layout = @import("session_layout.zig");

pub const face_bit: u8 = 1;
pub const color_bit: u8 = 2;
pub const Edit = union(enum) { face: ?u8, color: ?u8 };
pub const Intent = struct {
    tmux_host: u8,
    tmux_session: []const u8,
    touched: u8,
    face: ?u8 = null,
    color: ?u8 = null,
};
pub const Touch = struct { tmux_host: u8, tmux_session: []const u8, touched: u8 };

pub fn same(host: u8, session: []const u8, intent: Intent) bool {
    return host == intent.tmux_host and std.ascii.eqlIgnoreCase(session, intent.tmux_session);
}

pub fn validate(intents: []const Intent) !void {
    if (intents.len > 4096) return error.InvalidAppearance;
    for (intents, 0..) |intent, i| {
        if (intent.tmux_host > 2 or intent.tmux_session.len == 0 or intent.tmux_session.len > 63 or intent.touched == 0 or intent.touched > 3) return error.InvalidAppearance;
        for (intent.tmux_session) |c| {
            if ((!std.ascii.isAlphanumeric(c) and c != '_' and c != '-') or std.ascii.isUpper(c)) return error.InvalidAppearance;
        }
        if (intent.face) |face| {
            if (face >= 20) return error.InvalidAppearance;
        }
        if (intent.color) |color| {
            if (color >= 7) return error.InvalidAppearance;
        }
        for (intents[0..i]) |previous| {
            if (same(previous.tmux_host, previous.tmux_session, intent)) return error.InvalidAppearance;
        }
    }
}

pub fn overlay(a: std.mem.Allocator, target: layout.Layout, intents: []const Intent) !layout.Layout {
    var result = target;
    const tabs = try a.dupe(layout.Tab, target.tabs);
    for (tabs) |*tab| {
        for (intents) |intent| {
            if (!same(tab.tmux_host, tab.tmux_session, intent)) continue;
            if (intent.touched & face_bit != 0) tab.face = intent.face;
            if (intent.touched & color_bit != 0) tab.color = intent.color;
            break;
        }
    }
    result.tabs = tabs;
    return result;
}

pub fn clone(a: std.mem.Allocator, intents: []const Intent) ![]Intent {
    const copy = try a.alloc(Intent, intents.len);
    var count: usize = 0;
    errdefer {
        for (copy[0..count]) |intent| a.free(intent.tmux_session);
        a.free(copy);
    }
    for (intents) |intent| {
        copy[count] = intent;
        copy[count].tmux_session = try a.dupe(u8, intent.tmux_session);
        count += 1;
    }
    return copy;
}

pub fn free(a: std.mem.Allocator, intents: []Intent) void {
    for (intents) |intent| a.free(intent.tmux_session);
    a.free(intents);
}
