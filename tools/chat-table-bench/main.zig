const std = @import("std");
const w = @import("win32.zig");
const app_state = @import("app_state.zig");
const render = @import("chat_render.zig");

pub fn main() !void {
    const dc = w.GetDC(null) orelse return error.NoDeviceContext;
    defer _ = w.ReleaseDC(null, dc);
    defer app_state.g_chat_tables.clear(std.heap.page_allocator);
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| Name | Value | Flag |\n|---|---|---|\n| Alpha | 100 | ready |\n| Beta | 200 | done |");
    var frequency: i64 = 0;
    if (w.QueryPerformanceFrequency(&frequency) == 0) return error.NoCounter;
    var total_ticks: i64 = 0;
    for (0..2050) |index| {
        app_state.g_chat_tables.clear(std.heap.page_allocator);
        var start: i64 = 0;
        var end: i64 = 0;
        _ = w.QueryPerformanceCounter(&start);
        const layout = render.benchTableLayout(dc, text, 0, 688) orelse return error.NoLayout;
        _ = w.QueryPerformanceCounter(&end);
        if (layout.table.columns != 3 or layout.table.rows.items.len != 3) return error.WrongTable;
        if (index >= 50) total_ticks += end - start;
    }
    std.debug.print("CHAT_TABLE_SAMPLE builds=2000 ticks={d} frequency={d}\n", .{ total_ticks, frequency });
}
