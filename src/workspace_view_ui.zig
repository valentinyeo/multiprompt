const app_state = @import("app_state.zig");
const HANDLE = @import("win32.zig").HANDLE;
const Builtin = @import("workspace_view.zig").Builtin;
const labelsMatchQuery = @import("command_palette.zig").labelsMatchQuery;

pub fn appendSearchResults() void {
    if (app_state.g_search_result_count < app_state.g_search_results.len and
        labelsMatchQuery(&.{ "Workspace view: All", "all sessions", "alt shift 1" }, app_state.g_search_buf[0..app_state.g_search_len]))
    {
        app_state.g_search_results[app_state.g_search_result_count] = app_state.SEARCH_WORKSPACE_ALL_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len and
        labelsMatchQuery(&.{ "Workspace view: Frequent", "frequent sessions", "alt shift 2" }, app_state.g_search_buf[0..app_state.g_search_len]))
    {
        app_state.g_search_results[app_state.g_search_result_count] = app_state.SEARCH_WORKSPACE_FREQUENT_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len and
        labelsMatchQuery(&.{ "Workspace view: Favorites", "favorites sessions", "alt shift 3" }, app_state.g_search_buf[0..app_state.g_search_len]))
    {
        app_state.g_search_results[app_state.g_search_result_count] = app_state.SEARCH_WORKSPACE_FAVORITES_OFFSET;
        app_state.g_search_result_count += 1;
    }
}

pub fn activatePalette(hwnd: HANDLE, target: usize) bool {
    const view: Builtin = switch (target) {
        app_state.SEARCH_WORKSPACE_ALL_OFFSET => .all,
        app_state.SEARCH_WORKSPACE_FREQUENT_OFFSET => .frequent,
        app_state.SEARCH_WORKSPACE_FAVORITES_OFFSET => .favorites,
        else => return false,
    };
    app_state.g_search_active = false;
    app_state.g_shell_focused = true;
    @import("rename.zig").clearSearchBackdrop();
    app_state.g_search_from_inbox = false;
    if (app_state.g_inbox_active) @import("inbox.zig").closeInbox(hwnd);
    @import("room_frontend.zig").leaveForOtherFront();
    @import("workspaces.zig").switchToWorkspace(@intFromEnum(view));
    return true;
}

pub fn refreshSidebar(hwnd: HANDLE) bool {
    if (app_state.g_sidebar_view == null or app_state.g_inbox_active) return false;
    @import("workspaces.zig").refreshSidebarView();
    _ = @import("win32.zig").InvalidateRect(hwnd, null, 0);
    return true;
}
