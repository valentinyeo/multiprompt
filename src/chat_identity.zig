const std = @import("std");

pub const Key = struct {
    host: u8 = 0,
    sid: [36]u8 = @splat(0),
    sid_len: usize = 0,
    session: [63]u8 = @splat(0),
    session_len: usize = 0,

    pub fn init(host: u8, sid: []const u8, session: []const u8) Key {
        var value = Key{ .host = host };
        if (sid.len > 0 and sid.len <= value.sid.len) {
            @memcpy(value.sid[0..sid.len], sid);
            value.sid_len = sid.len;
        } else if (liveSid(&value.sid, session)) |len| {
            value.sid_len = len;
        }
        if (session.len > 0 and session.len <= value.session.len) {
            for (session, 0..) |c, i| value.session[i] = std.ascii.toLower(c);
            value.session_len = session.len;
        }
        return value;
    }
};

pub fn liveSid(out: *[36]u8, session: []const u8) ?usize {
    if (session.len != 37 or !std.ascii.startsWithIgnoreCase(session, "live-")) return null;
    var index: usize = 0;
    for (session[5..], 0..) |c, i| {
        if (!std.ascii.isHex(c)) return null;
        if (i == 8 or i == 12 or i == 16 or i == 20) {
            out[index] = '-';
            index += 1;
        }
        out[index] = std.ascii.toLower(c);
        index += 1;
    }
    return index;
}

pub fn same(a: Key, b: Key) bool {
    if (a.host != b.host) return false;
    if (a.sid_len > 0 and b.sid_len > 0) return std.ascii.eqlIgnoreCase(a.sid[0..a.sid_len], b.sid[0..b.sid_len]);
    return a.session_len > 0 and std.mem.eql(u8, a.session[0..a.session_len], b.session[0..b.session_len]);
}

const original_sid = "01234567-89ab-8def-8123-0123456789ab";

test "MUBO-252 a native session and its live name carry the same chat id" {
    const native = Key.init(0, original_sid, "");
    const hosted = Key.init(0, "", "live-0123456789ab8def81230123456789ab");
    var decoded: [36]u8 = @splat(0);
    const len = liveSid(&decoded, "live-0123456789ab8def81230123456789ab") orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings(original_sid, decoded[0..len]);
    try std.testing.expectEqual(@as(usize, 36), hosted.sid_len);
    try std.testing.expect(same(native, hosted));
    try std.testing.expect(same(hosted, Key.init(0, original_sid, "term-restore")));
}

test "MUBO-252 separate chats, hosts and nameless terminals do not share a chat id" {
    try std.testing.expect(same(Key.init(0, "", "term-one"), Key.init(0, "", "TERM-ONE")));
    try std.testing.expect(!same(Key.init(0, "", "term-one"), Key.init(1, "", "term-one")));
    try std.testing.expect(!same(Key.init(0, "", "term-one"), Key.init(0, "", "term-two")));
    try std.testing.expect(!same(Key.init(0, "", ""), Key.init(0, "", "")));
    try std.testing.expect(!same(Key.init(0, original_sid, ""), Key.init(1, original_sid, "")));
    try std.testing.expect(!same(Key.init(0, original_sid, ""), Key.init(0, "ffffffff-ffff-4fff-bfff-ffffffffffff", "")));
    try std.testing.expect(same(Key.init(0, "", "term-one"), Key.init(0, original_sid, "term-one")));
}
