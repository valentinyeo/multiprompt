const std = @import("std");

pub const initial_bytes: usize = 1_440_000;

pub const Audio = struct {
    buf: []u8,
    len: usize = 0,

    pub fn init(allocator: std.mem.Allocator) !Audio {
        return .{ .buf = try allocator.alloc(u8, initial_bytes) };
    }

    pub fn deinit(self: *Audio, allocator: std.mem.Allocator) void {
        allocator.free(self.buf);
        self.buf = &.{};
        self.len = 0;
    }

    pub fn append(self: *Audio, allocator: std.mem.Allocator, bytes: []const u8) bool {
        const needed = self.len + bytes.len;
        if (needed > self.buf.len) {
            const grown = @max(self.buf.len * 2, needed);
            self.buf = allocator.realloc(self.buf, grown) catch return false;
        }
        @memcpy(self.buf[self.len..][0..bytes.len], bytes);
        self.len = needed;
        return true;
    }

    pub fn slice(self: *const Audio) []const u8 {
        return self.buf[0..self.len];
    }
};

test "IGSH-885 dictation audio keeps growing past the old 45 second wall" {
    var audio = try Audio.init(std.testing.allocator);
    defer audio.deinit(std.testing.allocator);
    var chunk: [3200]u8 = undefined;
    for (&chunk, 0..) |*byte, i| byte.* = @truncate(i);
    const old_wall = initial_bytes;
    var appended: usize = 0;
    while (appended < old_wall * 3) : (appended += chunk.len) {
        try std.testing.expect(audio.append(std.testing.allocator, &chunk));
    }
    try std.testing.expectEqual(appended, audio.slice().len);
    try std.testing.expect(audio.slice().len > old_wall * 2);
    try std.testing.expectEqualSlices(u8, &chunk, audio.slice()[old_wall..][0..chunk.len]);
}
