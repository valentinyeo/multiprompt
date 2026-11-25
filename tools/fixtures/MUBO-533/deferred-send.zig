test "a send pressed while the room opens waits for that room and sends once" {
    defer reset();
    const empty = ViewModel{ .room_id = "" };
    const room = ViewModel{ .room_id = "room-a", .revision = 4 };
    var view = View{ .model = &empty, .callbacks = callbacks };
    view.showLoading(room.room_id);
    w.compose(std.unicode.utf8ToUtf16LeStringLiteral("Hello room"));
    view.submit();
    try std.testing.expectEqual(@as(usize, 0), sent);
    try std.testing.expect(view.deferred_submit);
    try std.testing.expectEqual(@as(?ActionResult, null), view.result);
    try std.testing.expect(view.setModel(&room));
    view.flushDeferred();
    try std.testing.expectEqual(@as(usize, 1), sent);
    try std.testing.expectEqualStrings("room-a", sent_room);
    try std.testing.expectEqual(@as(u64, 4), sent_revision);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Hello room"), sent_text[0..sent_len]);
    view.flushDeferred();
    try std.testing.expectEqual(@as(usize, 1), sent);
}

test "a send already on a presented room goes straight away" {
    defer reset();
    const room = ViewModel{ .room_id = "room-a", .revision = 4 };
    var view = View{ .model = &room, .callbacks = callbacks };
    try std.testing.expect(view.setModel(&room));
    w.compose(std.unicode.utf8ToUtf16LeStringLiteral("Hello room"));
    view.submit();
    try std.testing.expectEqual(@as(usize, 1), sent);
    try std.testing.expect(!view.deferred_submit);
}

test "a held send whose draft was cleared sends nothing and shows no error" {
    defer reset();
    const empty = ViewModel{ .room_id = "" };
    const room = ViewModel{ .room_id = "room-a", .revision = 4 };
    var view = View{ .model = &empty, .callbacks = callbacks };
    view.showLoading(room.room_id);
    w.compose(std.unicode.utf8ToUtf16LeStringLiteral("Hello room"));
    view.submit();
    w.compose(&.{});
    try std.testing.expect(view.setModel(&room));
    view.flushDeferred();
    try std.testing.expectEqual(@as(usize, 0), sent);
    try std.testing.expectEqual(@as(?ActionResult, null), view.result);
    try std.testing.expectEqual(@as(usize, 0), view.error_len);
}

test "a held send never follows you into another room or back again" {
    defer reset();
    const empty = ViewModel{ .room_id = "" };
    const room = ViewModel{ .room_id = "room-a", .revision = 4 };
    const other = ViewModel{ .room_id = "room-b", .revision = 9 };
    var view = View{ .model = &empty, .callbacks = callbacks };
    view.showLoading(room.room_id);
    w.compose(std.unicode.utf8ToUtf16LeStringLiteral("Hello room"));
    view.submit();
    try std.testing.expect(view.deferred_submit);
    view.showLoading(other.room_id);
    w.compose(std.unicode.utf8ToUtf16LeStringLiteral("Other room draft"));
    try std.testing.expect(!view.deferred_submit);
    try std.testing.expect(view.setModel(&other));
    view.flushDeferred();
    try std.testing.expectEqual(@as(usize, 0), sent);
    try std.testing.expect(view.setModel(&room));
    view.flushDeferred();
    try std.testing.expectEqual(@as(usize, 0), sent);
    try std.testing.expectEqual(@as(usize, 0), view.error_len);
}
