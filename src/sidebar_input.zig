const std = @import("std");
const app_state = @import("app_state.zig");
const HANDLE = @import("win32.zig").HANDLE;
const RECT = @import("win32.zig").RECT;
const GetClientRect = @import("win32.zig").GetClientRect;
const searchOverlayW = @import("drawing.zig").searchOverlayW;
const searchInputH = @import("drawing.zig").searchInputH;
const searchRowH = @import("drawing.zig").searchRowH;
const searchFooterH = @import("drawing.zig").searchFooterH;
const searchOverlayOx = @import("drawing.zig").searchOverlayOx;
const searchOverlayOy = @import("drawing.zig").searchOverlayOy;
const inboxButtonHitTest = @import("browser_pane.zig").inboxButtonHitTest;
const SIDEBAR_W = @import("browser_pane.zig").SIDEBAR_W;
const sidebarStickyCardHitTest = @import("capacity.zig").sidebarStickyCardHitTest;
const sidebarStickyCardHoverTest = @import("capacity.zig").sidebarStickyCardHoverTest;
const updateCardHit = @import("update_card.zig").updateCardHit;
const hitTestSidebar = @import("sidebar.zig").hitTestSidebar;
const clearTabSelection = @import("sidebar.zig").clearTabSelection;
const invalidateSidebar = @import("window_layout.zig").invalidateSidebar;

pub fn resetSidebarDrag() void {
    app_state.drag_id_count = 0;
    app_state.drag_crossed = false;
    app_state.drag_collapse = false;
    app_state.drag_active = false;
    app_state.drag_pending_materialize = false;
    app_state.drag_is_group = false;
    app_state.drag_section_only = false;
    app_state.drag_detach_blocked = false;
    invalidateSidebar();
}

pub fn sidebarDragValid() bool {
    if (app_state.drag_starred != app_state.g_starred_workspace or
        (!app_state.drag_starred and app_state.drag_workspace != app_state.g_active_workspace) or
        app_state.drag_unread_only != app_state.g_unread_only or app_state.g_hide_sidebar or
        app_state.drag_sidebar_collapsed != app_state.g_sidebar_collapsed or app_state.drag_single_window != app_state.g_single_window or
        app_state.drag_pinned_collapsed != app_state.g_pinned_section_collapsed or app_state.drag_recents_collapsed != app_state.g_recents_section_collapsed or
        (app_state.drag_id_count > 1 and app_state.drag_groups_token != @import("sidebar.zig").dragGroupsToken()) or
        app_state.g_account_locked or @import("settings_panel.zig").isOpen() or
        app_state.g_search_active or app_state.g_inbox_active or app_state.g_all_sessions_active or
        app_state.g_shortcuts_active or app_state.g_changelog_active or app_state.g_url_picker_active or
        app_state.g_snippet_create_active) return false;
    return @import("sidebar.zig").dragIdsInCurrentWorkspace(app_state.drag_ids[0..app_state.drag_id_count]);
}

pub fn clearSelectionForClick(hwnd: HANDLE, mx: i32, my: i32) void {
    if (app_state.g_search_active) {
        var rc: RECT = std.mem.zeroes(RECT);
        _ = GetClientRect(hwnd, &rc);
        const width = searchOverlayW();
        const height = searchInputH() + @as(i32, @intCast(@min(app_state.g_search_result_count, @import("drawing.zig").searchVisibleRows()))) * searchRowH() + searchFooterH();
        const x = searchOverlayOx(rc.right - rc.left, width);
        const y = searchOverlayOy(rc.bottom - rc.top, height);
        if (mx >= x and mx < x + width and my >= y and my < y + height) return;
    } else if (!@import("settings_panel.zig").isOpen() and !app_state.g_account_locked and !app_state.g_hide_sidebar and
        !inboxButtonHitTest(mx, my) and !app_state.g_inbox_active and !app_state.g_all_sessions_active and !app_state.g_shortcuts_active and
        !app_state.g_changelog_active and !app_state.g_url_picker_active and !app_state.g_snippet_create_active and
        mx >= 0 and mx < SIDEBAR_W() - 4 and my >= @import("browser_pane.zig").wsStripHeight() + @import("workspace_switcher.zig").headerHeight() and
        !sidebarStickyCardHitTest(my) and !sidebarStickyCardHoverTest(mx, my) and updateCardHit(mx, my) == 0)
    {
        if (hitTestSidebar(mx, my + app_state.g_sidebar_scroll) == .tab) return;
    }
    app_state.drag_anchor = null;
    if (clearTabSelection()) invalidateSidebar();
}
