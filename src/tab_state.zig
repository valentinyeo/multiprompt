const std = @import("std");

pub const Kind = enum { chat, shell };
pub const Shell = enum { cmd, pwsh, vps, tmux, vps2, bash, gitbash };
pub const Verb = enum { open, close, move, pin, unpin, archive, unarchive, wait, restore };
pub const State = struct {
    host: []const u8,
    user: []const u8,
    workspace: []const u8,
    group: ?[]const u8 = null,
    position: u32,
    kind: Kind,
    sid: ?[]const u8 = null,
    shell: Shell = .tmux,
    agent: u8 = 0,
    cwd: ?[]const u8 = null,
    pinned: bool = false,
    archived: bool = false,
    waiting: bool = false,
    closed: bool = false,
    visible: bool = false,
    hidden_reason: ?[]const u8 = null,
    tmux: []const u8,
    name: []const u8,

    pub fn jsonStringify(self: State, json: anytype) !void {
        try json.beginObject();
        inline for (std.meta.fields(State)) |field| {
            try json.objectField(field.name);
            try json.write(@field(self, field.name));
        }
        try json.endObject();
    }

    pub fn dupe(self: State, a: std.mem.Allocator) !State {
        var result = self;
        inline for (std.meta.fields(State)) |field| {
            if (field.type == []const u8) @field(result, field.name) = try a.dupe(u8, @field(self, field.name));
            if (field.type == ?[]const u8) {
                @field(result, field.name) = if (@field(self, field.name)) |value| try a.dupe(u8, value) else null;
            }
        }
        return result;
    }

    pub fn deinit(self: State, a: std.mem.Allocator) void {
        inline for (std.meta.fields(State)) |field| {
            if (field.type == []const u8) a.free(@field(self, field.name));
            if (field.type == ?[]const u8) {
                if (@field(self, field.name)) |value| a.free(value);
            }
        }
    }
};
pub const Request = struct { verb: Verb, expected: ?State, state: State };

pub fn equal(a: State, b: State) bool {
    inline for (std.meta.fields(State)) |field| {
        if (comptime std.mem.eql(u8, field.name, "visible") or std.mem.eql(u8, field.name, "hidden_reason") or std.mem.eql(u8, field.name, "cwd")) continue;
        const x = @field(a, field.name);
        const y = @field(b, field.name);
        if (field.type == []const u8) {
            if (!std.mem.eql(u8, x, y)) return false;
        } else if (field.type == ?[]const u8) {
            if ((x == null) != (y == null)) return false;
            if (x) |value| if (!std.mem.eql(u8, value, y.?)) return false;
        } else if (x != y) return false;
    }
    return true;
}

fn text(value: []const u8, max: usize) bool {
    if (value.len == 0 or value.len > max or !std.unicode.utf8ValidateSlice(value)) return false;
    for (value) |c| if (c < 32 or c == 127) return false;
    return true;
}

pub fn validate(state: State) !void {
    if (!text(state.host, 255) or !text(state.workspace, 31) or !text(state.name, 255) or state.position >= 256) return error.InvalidState;
    if (state.user.len > 32 or state.agent > 7) return error.InvalidState;
    if (state.cwd) |cwd| if (!text(cwd, 511)) return error.InvalidState;
    if (state.group) |group| if (!text(group, 255)) return error.InvalidState;
    if (state.sid) |sid| if (!text(sid, 39)) return error.InvalidState;
    if (state.tmux.len == 0 or state.tmux.len > 63) return error.InvalidState;
    const key = if (std.mem.startsWith(u8, state.tmux, "@shell-")) state.tmux[1..] else state.tmux;
    for (key) |c| if (!std.ascii.isAlphanumeric(c) and c != '-' and c != '_' and c != '.') return error.InvalidState;
    if (state.archived and state.waiting) return error.InvalidState;
}

pub fn transition(current: ?State, request: Request) !State {
    try validate(request.state);
    if (current == null) {
        if (request.expected != null) return error.Conflict;
        if (request.verb != .open or request.state.closed or request.state.archived or request.state.waiting) return error.ExplicitOpenRequired;
        return request.state;
    }
    const old = current.?;
    if (request.expected == null or !equal(old, request.expected.?)) return error.Conflict;
    var next = old;
    switch (request.verb) {
        .open, .restore => {
            next.closed = false;
            next.archived = false;
            next.waiting = false;
        },
        .close => next.closed = true,
        .pin => next.pinned = true,
        .unpin => next.pinned = false,
        .archive => {
            next.archived = true;
            next.waiting = false;
        },
        .unarchive => next.archived = false,
        .wait => {
            next.waiting = true;
            next.archived = false;
        },
        .move => {
            next.workspace = request.state.workspace;
            next.group = request.state.group;
            next.position = request.state.position;
        },
    }
    if (!equal(next, request.state)) return error.InvalidChange;
    return next;
}

test "SOFT-3141 every verb is idempotent and only open or restore clears closed" {
    const original = State{ .host = "remote-1", .user = "agent", .workspace = "Research", .position = 1, .kind = .chat, .sid = "session-id", .tmux = "live-fixture", .name = "Fixture", .closed = true };
    inline for (std.meta.tags(Verb)) |verb| {
        var desired = original;
        switch (verb) {
            .open, .restore => desired.closed = false,
            .close => desired.closed = true,
            .pin => desired.pinned = true,
            .unpin => desired.pinned = false,
            .archive => desired.archived = true,
            .unarchive => desired.archived = false,
            .wait => desired.waiting = true,
            .move => desired.workspace = "Home",
        }
        const next = try transition(original, .{ .verb = verb, .expected = original, .state = desired });
        const again = try transition(next, .{ .verb = verb, .expected = next, .state = desired });
        try std.testing.expect(equal(next, again));
        try std.testing.expectEqual(verb != .open and verb != .restore, next.closed);
        try std.testing.expectEqualStrings(original.host, next.host);
        try std.testing.expectEqualStrings(original.sid.?, next.sid.?);
    }
}

test "SOFT-3141 stale state and identity changes are refused before apply" {
    const original = State{ .host = "remote-1", .user = "agent", .workspace = "Research", .position = 1, .kind = .chat, .tmux = "live-fixture", .name = "Fixture" };
    var desired = original;
    desired.pinned = true;
    try std.testing.expectError(error.Conflict, transition(original, .{ .verb = .pin, .expected = null, .state = desired }));
    desired.host = "remote-2";
    try std.testing.expectError(error.InvalidChange, transition(original, .{ .verb = .pin, .expected = original, .state = desired }));
}
