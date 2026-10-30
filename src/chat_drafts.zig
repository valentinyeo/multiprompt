const std = @import("std");

pub const OwnedDraft = struct {
    owner: [33]u8 = @splat(0),
    sid: [40]u8 = @splat(0),
    inode: u64 = 0,
    revision: u64 = 0,

    pub fn valid(self: OwnedDraft) bool {
        const owner = std.mem.sliceTo(&self.owner, 0);
        const sid = std.mem.sliceTo(&self.sid, 0);
        if (owner.len != 32 or sid.len == 0 or sid.len >= self.sid.len or self.inode == 0 or self.inode > std.math.maxInt(i64) or self.revision == 0 or self.revision > std.math.maxInt(i64)) return false;
        for (owner) |c| if (!((c >= '0' and c <= '9') or (c >= 'a' and c <= 'f'))) return false;
        for (sid) |c| if (!std.ascii.isAlphanumeric(c) and c != '-' and c != '_') return false;
        return true;
    }

    pub fn advance(self: *OwnedDraft) bool {
        if (self.revision >= std.math.maxInt(i64)) return false;
        self.revision += 1;
        return self.valid();
    }

    pub fn wire(self: *const OwnedDraft) Wire {
        return .{ .owner = std.mem.sliceTo(&self.owner, 0), .revision = self.revision, .sid = std.mem.sliceTo(&self.sid, 0), .inode = self.inode };
    }

    pub const Wire = struct { owner: []const u8, revision: u64, sid: []const u8, inode: u64 };
};

pub const Store = struct {
    pub const Draft = struct { text: []u16, dirty: bool, evict: bool = false };

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
            draft.text = owned_text;
            draft.dirty = dirty;
        } else {
            const key = try self.allocator.dupe(u8, id);
            errdefer self.allocator.free(key);
            try self.entries.put(key, .{ .text = owned_text, .dirty = dirty });
        }
    }

    pub fn remove(self: *Store, id: []const u8) void {
        if (self.entries.fetchRemove(id)) |entry| {
            self.allocator.free(entry.key);
            self.allocator.free(entry.value.text);
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

test "ISSUE-498 evicting a closed draft frees its key and text without touching another session" {
    var store = Store.init(std.testing.allocator);
    defer store.deinit();
    try store.set("session-a", &.{'a'}, true);
    try store.set("session-b", &.{'b'}, true);
    store.remove("session-a");
    store.remove("session-a");
    try std.testing.expectEqual(@as(u32, 1), store.entries.count());
    try std.testing.expect(!store.entries.contains("session-a"));
    try std.testing.expect(store.hasDraft("session-b"));
}

test "owned draft identity and revision survive metadata roundtrip" {
    var owned: OwnedDraft = .{};
    @memcpy(owned.owner[0..32], "0123456789abcdef0123456789abcdef");
    @memcpy(owned.sid[0..3], "sid");
    owned.inode = 19;
    try std.testing.expect(owned.advance());
    const bytes = try std.json.Stringify.valueAlloc(std.testing.allocator, owned.wire(), .{});
    defer std.testing.allocator.free(bytes);
    const parsed = try std.json.parseFromSlice(OwnedDraft.Wire, std.testing.allocator, bytes, .{});
    defer parsed.deinit();
    try std.testing.expectEqualStrings("0123456789abcdef0123456789abcdef", parsed.value.owner);
    try std.testing.expectEqual(@as(u64, 1), parsed.value.revision);
    try std.testing.expect(owned.advance());
    try std.testing.expectEqual(@as(u64, 2), owned.revision);
    owned.revision = std.math.maxInt(i64);
    try std.testing.expect(!owned.advance());
}
