const std = @import("std");

pub const Store = struct {
    pub const Draft = struct { text: []u16, dirty: bool };

    allocator: std.mem.Allocator,
    entries: std.StringHashMap(Draft),

    pub fn init(allocator: std.mem.Allocator) Store {
        return .{ .allocator = allocator, .entries = std.StringHashMap(Draft).init(allocator) };
    }

    pub fn deinit(self: *Store) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.text);
        }
        self.entries.deinit();
    }

    pub fn set(self: *Store, id: []const u8, text: []const u16, dirty: bool) !void {
        const owned_text = try self.allocator.dupe(u16, text);
        errdefer self.allocator.free(owned_text);
        if (self.entries.getPtr(id)) |draft| {
            self.allocator.free(draft.text);
            draft.* = .{ .text = owned_text, .dirty = dirty };
        } else {
            const key = try self.allocator.dupe(u8, id);
            errdefer self.allocator.free(key);
            try self.entries.put(key, .{ .text = owned_text, .dirty = dirty });
        }
    }

    pub fn hasDraft(self: *const Store, id: []const u8) bool {
        const draft = self.entries.get(id) orelse return false;
        return std.mem.trim(u16, draft.text, &.{ ' ', '\t', '\r', '\n' }).len > 0;
    }

    pub fn append(self: *Store, id: []const u8, text: []const u16) !void {
        const current = if (self.entries.get(id)) |draft| draft.text else &.{};
        var out: [16384]u16 = undefined;
        const n = @min(current.len, out.len - 1);
        @memcpy(out[0..n], current[0..n]);
        var pos = n;
        if (pos > 0 and pos < out.len - 1) {
            out[pos] = ' ';
            pos += 1;
        }
        const added = @min(text.len, out.len - 1 - pos);
        @memcpy(out[pos..][0..added], text[0..added]);
        try self.set(id, out[0 .. pos + added], true);
    }
};

test "ISSUE-498 stable-id draft map isolates edits, dictation and clearing" {
    var store = Store.init(std.testing.allocator);
    defer store.deinit();
    const a = std.unicode.utf8ToUtf16LeStringLiteral("typed");
    const b = std.unicode.utf8ToUtf16LeStringLiteral("pasted");
    try store.set("session-a", a, true);
    try store.set("session-b", b, true);
    try store.append("session-a", std.unicode.utf8ToUtf16LeStringLiteral("spoken"));
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("typed spoken"), store.entries.get("session-a").?.text);
    try std.testing.expectEqualSlices(u16, b, store.entries.get("session-b").?.text);
    try std.testing.expect(store.hasDraft("session-a"));
    try store.set("session-a", &.{}, true);
    try std.testing.expect(!store.hasDraft("session-a"));
    try std.testing.expect(store.hasDraft("session-b"));
}
