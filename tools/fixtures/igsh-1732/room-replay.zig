test "IGSH-1732 room answers stay beneath their questions across pages and replay" {
    const previous = building_model;
    defer building_model = previous;
    const source =
        \\{"events":[{"id":"10000000-0000-4000-8000-000000000003","room_id":"10000000-0000-4000-8000-000000000001","seq":2,"type":"human","revision":1,"text":"Question 1","recipients":["10000000-0000-4000-8000-000000000002"]},{"id":"10000000-0000-4000-8000-000000000004","room_id":"10000000-0000-4000-8000-000000000001","seq":3,"type":"human","revision":1,"text":"Question 2","recipients":["10000000-0000-4000-8000-000000000002"]},{"id":"10000000-0000-4000-8000-000000000005","room_id":"10000000-0000-4000-8000-000000000001","seq":4,"type":"agent_reply","parent_event_id":"10000000-0000-4000-8000-000000000004","member_id":"10000000-0000-4000-8000-000000000002","response_id":"10000000-0000-4000-8000-000000000010","text":"Answer 2"},{"id":"10000000-0000-4000-8000-000000000006","room_id":"10000000-0000-4000-8000-000000000001","seq":5,"type":"agent_reply","parent_event_id":"10000000-0000-4000-8000-000000000003","member_id":"10000000-0000-4000-8000-000000000002","response_id":"10000000-0000-4000-8000-000000000011","text":"Answer 1"},{"id":"10000000-0000-4000-8000-000000000007","room_id":"10000000-0000-4000-8000-000000000001","seq":6,"type":"agent_reply","parent_event_id":"10000000-0000-4000-8000-000000000003","member_id":"10000000-0000-4000-8000-000000000002","response_id":"10000000-0000-4000-8000-000000000012","text":"Another answer 1"}],"next_after":6}
    ;
    const expected = [_][]const u16{
        std.unicode.utf8ToUtf16LeStringLiteral("Question 1"),
        std.unicode.utf8ToUtf16LeStringLiteral("Answer 1"),
        std.unicode.utf8ToUtf16LeStringLiteral("Another answer 1"),
        std.unicode.utf8ToUtf16LeStringLiteral("Question 2"),
        std.unicode.utf8ToUtf16LeStringLiteral("Answer 2"),
    };
    const Replay = enum { full, paged, advanced };
    for ([_]Replay{ .full, .paged, .advanced }) |replay| {
        var item = OwnedModel{
            .arena = std.heap.ArenaAllocator.init(std.testing.allocator),
            .value = .{ .room_id = "10000000-0000-4000-8000-000000000001", .name = &.{}, .revision = 1, .members = &.{}, .candidates = &.{}, .messages = &.{} },
            .after = 1,
            .highwater = 6,
            .replay_revision = 1,
        };
        defer item.arena.deinit();
        const a = item.arena.allocator();
        try item.history.append(a, .{ .id = "10000000-0000-4000-8000-000000000002", .sid = "session", .provider = "claude", .alias = "alice", .seen_revision = 1, .author = .{ .name = std.unicode.utf8ToUtf16LeStringLiteral("Alice"), .appearance = .{ .face = 0, .color = 0 }, .name_color = 0 } });
        building_model = &item;
        const parsed = try std.json.parseFromSlice(std.json.Value, a, source, .{});
        const events = parsed.value.object.getPtr("events").?;
        const all = events.array.items;
        const next = parsed.value.object.getPtr("next_after").?;
        if (replay == .advanced) {
            item.highwater = 3;
            try std.testing.expect(acceptEvents(parsed.value));
            try std.testing.expectEqual(@as(u64, 3), item.after);
            try std.testing.expectEqual(@as(usize, 2), item.messages.items.len);
            try std.testing.expect(numberField(parsed.value, "next_after").? > item.highwater);
            item.highwater = 6;
            events.array.items = all[2..];
            try std.testing.expect(acceptEvents(parsed.value));
        } else {
            var start: usize = 0;
            for ([_]usize{ 2, 4, 5 }) |end| {
                if (replay == .full and end != all.len) continue;
                events.array.items = all[start..end];
                next.* = .{ .integer = @intCast(end + 1) };
                try std.testing.expect(acceptEvents(parsed.value));
                start = end;
            }
        }
        try std.testing.expectEqual(@as(u64, 6), item.after);
        try std.testing.expectEqual(expected.len, item.messages.items.len);
        for (expected, item.messages.items, 0..) |text, message, index| {
            try std.testing.expectEqualSlices(u16, text, message.text);
            try std.testing.expectEqual(index != 0 and index != 3, message.author != null);
        }
        try std.testing.expect(!acceptEvents(parsed.value));
        try std.testing.expectEqual(expected.len, item.messages.items.len);
    }
}
