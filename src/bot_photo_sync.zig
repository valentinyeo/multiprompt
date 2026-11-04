const std = @import("std");
const Key = @import("bot_photo_key.zig").Key;

pub const Photo = union(enum) { absent, deleted, png: []u8 };
const Entry = struct { identity: [32]u8, content: [32]u8 };
pub const Sync = struct {
    entries: []Entry = &.{},
    generation: u64 = 0,

    pub fn deinit(self: *Sync, a: std.mem.Allocator) void {
        a.free(self.entries);
        self.* = .{};
    }

    pub fn parse(a: std.mem.Allocator, bytes: []const u8) !Sync {
        const parsed = try std.json.parseFromSlice(Sync, a, bytes, .{});
        defer parsed.deinit();
        return .{ .entries = try a.dupe(Entry, parsed.value.entries), .generation = parsed.value.generation };
    }

    pub fn run(self: *Sync, a: std.mem.Allocator, account: []const u8, tabs: anytype, context: anytype) !void {
        for (tabs) |tab| {
            const digest = (Key{ .remote = .{ .host = tab.tmux_host, .session = tab.tmux_session } }).digest() orelse continue;
            const photo = context.read(digest) catch continue;
            defer if (photo == .png) a.free(photo.png);
            if (photo == .absent) continue;
            var hash = std.crypto.hash.sha2.Sha256.init(.{});
            hash.update(account);
            hash.update(&digest);
            var identity: [32]u8 = undefined;
            hash.final(&identity);
            hash = std.crypto.hash.sha2.Sha256.init(.{});
            hash.update(if (photo == .png) "png" else "deleted");
            if (photo == .png) hash.update(photo.png);
            var content: [32]u8 = undefined;
            hash.final(&content);
            var slot: ?usize = null;
            for (self.entries, 0..) |entry, i| {
                if (std.mem.eql(u8, &entry.identity, &identity)) { slot = i; break; }
            }
            if (slot) |i| {
                if (std.mem.eql(u8, &self.entries[i].content, &content)) continue;
            }
            const hex = std.fmt.bytesToHex(digest, .lower);
            const path = try std.fmt.allocPrint(a, "/v1/bot-photos/{s}", .{hex});
            defer a.free(path);
            var body: []const u8 = "";
            defer if (body.len > 0) a.free(body);
            if (photo == .png) {
                if (photo.png.len > 65536) continue;
                const base64 = try a.alloc(u8, std.base64.standard.Encoder.calcSize(photo.png.len));
                defer a.free(base64);
                _ = std.base64.standard.Encoder.encode(base64, photo.png);
                body = try std.json.Stringify.valueAlloc(a, .{ .png = base64 }, .{});
            }
            const status = context.send(if (photo == .png) "PUT" else "DELETE", path, body) catch continue;
            if (status < 200 or status >= 300) continue;
            if (slot) |i| {
                self.entries[i].content = content;
            } else {
                const index = self.entries.len;
                self.entries = try a.realloc(self.entries, index + 1);
                self.entries[index] = .{ .identity = identity, .content = content };
            }
            self.generation +%= 1;
        }
    }
};

test "pictures migrate, retry, replace and reset without duplicate successful uploads" {
    const Fixture = struct {
        bytes: ?[]const u8 = "first",
        reset: bool = false,
        fail: bool = false,
        sends: usize = 0,
        last_delete: bool = false,
        pub fn read(self: *@This(), _: [32]u8) !Photo {
            if (self.bytes) |bytes| return .{ .png = try std.testing.allocator.dupe(u8, bytes) };
            return if (self.reset) .deleted else .absent;
        }
        pub fn send(self: *@This(), method: []const u8, path: []const u8, body: []const u8) !u32 {
            self.sends += 1;
            self.last_delete = std.mem.eql(u8, method, "DELETE");
            try std.testing.expectEqualStrings("/v1/bot-photos/7fb158a6819a5e497a67662c60c7837ffbd327627773fd876686c60f93d88d5a", path);
            if (!self.last_delete) {
                const parsed = try std.json.parseFromSlice(struct { png: []const u8 }, std.testing.allocator, body, .{});
                defer parsed.deinit();
                const expected = try std.testing.allocator.alloc(u8, std.base64.standard.Encoder.calcSize(self.bytes.?.len));
                defer std.testing.allocator.free(expected);
                _ = std.base64.standard.Encoder.encode(expected, self.bytes.?);
                try std.testing.expectEqualStrings(expected, parsed.value.png);
            }
            return if (self.fail) 503 else 200;
        }
    };
    var fixture = Fixture{};
    var sync = Sync{};
    defer sync.deinit(std.testing.allocator);
    const tabs = [_]struct { tmux_host: u8, tmux_session: []const u8 }{.{ .tmux_host = 1, .tmux_session = "My-Bot" }};
    const a = std.testing.allocator;
    fixture.fail = true;
    try sync.run(a, "account-a", &tabs, &fixture);
    try std.testing.expectEqual(@as(usize, 1), fixture.sends);
    fixture.fail = false;
    try sync.run(a, "account-a", &tabs, &fixture);
    try sync.run(a, "account-a", &tabs, &fixture);
    try std.testing.expectEqual(@as(usize, 2), fixture.sends);
    fixture.bytes = "replacement";
    try sync.run(a, "account-a", &tabs, &fixture);
    try std.testing.expectEqual(@as(usize, 3), fixture.sends);
    try sync.run(a, "account-b", &tabs, &fixture);
    try std.testing.expectEqual(@as(usize, 4), fixture.sends);
    fixture.bytes = null;
    try sync.run(a, "account-a", &tabs, &fixture);
    try std.testing.expectEqual(@as(usize, 4), fixture.sends);
    fixture.reset = true;
    try sync.run(a, "account-a", &tabs, &fixture);
    try std.testing.expect(fixture.last_delete);
    try std.testing.expectEqual(@as(usize, 5), fixture.sends);
    try sync.run(a, "account-a", &tabs, &fixture);
    try std.testing.expectEqual(@as(usize, 5), fixture.sends);
    const saved = try std.json.Stringify.valueAlloc(a, sync, .{});
    defer a.free(saved);
    var restarted = try Sync.parse(a, saved);
    defer restarted.deinit(a);
    try restarted.run(a, "account-a", &tabs, &fixture);
    try std.testing.expectEqual(@as(usize, 5), fixture.sends);
    fixture.bytes = "after restart";
    try restarted.run(a, "account-a", &tabs, &fixture);
    try std.testing.expectEqual(@as(usize, 6), fixture.sends);
    fixture.bytes = null;
    var migrated_reset = Sync{};
    defer migrated_reset.deinit(a);
    try migrated_reset.run(a, "account-a", &tabs, &fixture);
    try std.testing.expect(fixture.last_delete);
    try std.testing.expectEqual(@as(usize, 7), fixture.sends);
}

test "acknowledgements survive more than 256 identities and restart" {
    const Fixture = struct {
        sends: usize = 0,
        pub fn read(_: *@This(), _: [32]u8) !Photo {
            return .{ .png = try std.testing.allocator.dupe(u8, "picture") };
        }
        pub fn send(self: *@This(), _: []const u8, _: []const u8, _: []const u8) !u32 {
            self.sends += 1;
            return 200;
        }
    };
    const a = std.testing.allocator;
    var sync = Sync{};
    defer sync.deinit(a);
    var fixture = Fixture{};
    const tabs = [_]struct { tmux_host: u8, tmux_session: []const u8 }{.{ .tmux_host = 1, .tmux_session = "My-Bot" }};
    for (0..300) |i| {
        const account = try std.fmt.allocPrint(a, "account-{d}", .{i});
        defer a.free(account);
        try sync.run(a, account, &tabs, &fixture);
    }
    const saved = try std.json.Stringify.valueAlloc(a, sync, .{});
    defer a.free(saved);
    var restarted = try Sync.parse(a, saved);
    defer restarted.deinit(a);
    try restarted.run(a, "account-0", &tabs, &fixture);
    try std.testing.expectEqual(@as(usize, 300), fixture.sends);
}
