fn scheduleMetadata(c: *rooms.Controller) bool {
    if (c.job == null and (front == .create or front == .selected) and c.has_host_uuid and candidate_scan < discovered_count and nextStatus(c)) return true;
    if (pumpRefresh(c)) return true;
    if (c.job != null or !catalog_complete or !c.has_host_uuid or request_generation != account_generation) return false;
    const route = configuredRoute(route_slot) orelse return false;
    const key = routeKey(route);
    if (!std.mem.eql(u8, &key, &route_key)) return false;
    if (selection_waiting and front == .selected and std.mem.eql(u8, &front.selected.store.store_uuid, &c.host_uuid)) {
        if (startSnapshot(c)) return true;
        selection_waiting = false;
    }
    const count = catalog_rows.items.len;
    if (count == 0) return false;
    var scanned: usize = 0;
    while (scanned < count) : (scanned += 1) {
        const index = metadata_cursor % count;
        metadata_cursor = (index + 1) % count;
        const row = &catalog_rows.items[index];
        if (row.metadata_state != .queued) continue;
        if (!c.catalogMetadata(row.id)) { row.metadata_state = .failed; last_failure = .{ .kind = .catalog_metadata, .reason = .transport }; _ = w.InvalidateRect(app_state.g_main_hwnd, null, 0); continue; }
        metadata_generation +%= 1;
        row.read_generation = metadata_generation;
        row.metadata_state = .loading;
        var room_id: [36]u8 = undefined;
        @memcpy(&room_id, row.id);
        metadata_read = .{ .room_id = room_id, .store_uuid = c.host_uuid, .catalog_generation = catalog_generation, .read_generation = metadata_generation };
        _ = w.SetTimer(app_state.g_main_hwnd, TIMER_ROOM, 250, null);
        return true;
    }
    return false;
}
