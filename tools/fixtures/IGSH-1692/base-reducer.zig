fn chatMessageReduce(idx: u32, value: std.json.Value) bool {
    const wrapped = json_reader.field(value, "message");
    const message = if (wrapped == .null) value else wrapped;
    const token = json_reader.string(json_reader.field(message, "id")) orelse return true;
    const phase = json_reader.string(json_reader.field(message, "state")) orelse return true;
    var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const key = chatOutboxKeyForShell(idx, &key_buf);
    const identity = chatFileIdentityForShell(idx);
    var found: ?usize = null;
    for (app_state.g_chat_outbox.items, 0..) |entry, i| {
        if (entry.message_v1 and std.mem.eql(u8, entry.key[0..entry.key_len], key) and std.mem.eql(u8, &entry.message_sid, &identity.sid) and std.mem.eql(u8, std.mem.sliceTo(&entry.message_wire_id, 0), token)) { found = i; break; }
    }
    if (std.mem.eql(u8, phase, "accepted") or std.mem.eql(u8, phase, "started") or std.mem.eql(u8, phase, "cancelled")) {
        if (found) |i| chatOutboxRemoveAtIn(&app_state.g_chat_outbox, std.heap.page_allocator, i);
        return true;
    }
    if (!std.mem.eql(u8, phase, "queued") and !std.mem.eql(u8, phase, "sent") and !std.mem.eql(u8, phase, "failed")) return false;
    if (found == null) {
        for (app_state.g_chat_confirmed.items) |c| {
            if (token.len != 0 and std.mem.eql(u8, c.key[0..c.key_len], key) and std.mem.eql(u8, &c.message_sid, &identity.sid) and std.mem.eql(u8, std.mem.sliceTo(&c.message_wire_id, 0), token)) return true;
        }
        const text = json_reader.string(json_reader.field(message, "text")) orelse return false;
        const wide = std.unicode.utf8ToUtf16LeAlloc(std.heap.page_allocator, text) catch return false;
        defer std.heap.page_allocator.free(wide);
        if (!chatOutboxEnqueueInStateLimit(&app_state.g_chat_outbox, std.heap.page_allocator, key, wide, .queued, false)) return false;
        found = app_state.g_chat_outbox.items.len - 1;
        const entry = &app_state.g_chat_outbox.items[found.?];
        entry.message_v1 = true;
        entry.message_sid = chatFileIdentityForShell(idx).sid;
        _ = json_reader.copyString(message, "id", &entry.message_wire_id);
    }
    const entry = &app_state.g_chat_outbox.items[found.?];
    _ = json_reader.copyString(message, "state", &entry.message_phase);
    entry.state = if (std.mem.eql(u8, phase, "failed")) .not_sent else .queued;
    entry.write_started = true;
    entry.channel_sent = true;
    return true;
}
