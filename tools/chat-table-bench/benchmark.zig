pub fn benchmarkTableBuilds() !void {
    const w = @import("win32.zig");
    const dc = w.GetDC(null) orelse return error.TestUnexpectedResult;
    defer _ = w.ReleaseDC(null, dc);
    const Context = if (@hasDecl(@This(), "TableMeasurer")) TableMeasurer else struct {
        hdc: HANDLE,
        fn cell(self: *@This(), text: []const u16, bold: bool) chat_markdown.TableSize {
            return chatTableCellSize(self.hdc, text, bold);
        }
        fn deinit(_: *@This()) void {}
    };
    var cache: chat_markdown.TableCache = .{};
    defer cache.deinit(std.heap.page_allocator);
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| Name | Value | Flag |\n|---|---|---|\n| Alpha | 100 | ready |\n| Beta | 200 | done |");
    const key = chat_markdown.TableKey{ .view_w = 688, .font_pt = app_state.g_chat_font_pt, .scale = uiScaled(1024), .pad_x = uiScaled(10), .pad_y = uiScaled(6) };
    var frequency: i64 = 0;
    try std.testing.expect(w.QueryPerformanceFrequency(&frequency) != 0);
    var total_us: i64 = 0;
    for (0..2000) |index| {
        cache.clear(std.heap.page_allocator);
        var context: Context = if (@hasDecl(@This(), "TableMeasurer")) .{ .backend = .{ .hdc = dc }, .metrics = &table_metrics } else .{ .hdc = dc };
        var start: i64 = 0;
        var end: i64 = 0;
        _ = w.QueryPerformanceCounter(&start);
        const layout = try cache.layout(std.heap.page_allocator, text, 0, key, &context, Context.cell);
        context.deinit();
        _ = w.QueryPerformanceCounter(&end);
        try std.testing.expectEqual(@as(usize, 3), layout.table.columns);
        try std.testing.expectEqual(@as(usize, 3), layout.table.rows.items.len);
        const us = @divTrunc((end - start) * 1_000_000, frequency);
        total_us += us;
        var line: [192]u8 = undefined;
        debugLog(try std.fmt.bufPrint(&line, "CHAT_TABLE_BUILD index={d} us={d} cells=9", .{ index, us }));
    }
    std.debug.print("CHAT_TABLE_BENCH builds={d} total_us={d} mean_us={d}\n", .{ cache.builds, total_us, @divTrunc(total_us, @as(i64, @intCast(cache.builds))) });
    try std.testing.expectEqual(@as(usize, 2000), cache.builds);
}
