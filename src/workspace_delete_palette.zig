const app_state = @import("app_state.zig");
const w = @import("win32.zig");
const workspaces = @import("workspaces.zig");
const updateSearchResults = @import("command_palette.zig").updateSearchResults;

fn refresh(hwnd: w.HANDLE) void {
    app_state.g_search_len = 0;
    app_state.g_search_sel = 0;
    app_state.g_search_scroll = 0;
    updateSearchResults();
    _ = w.InvalidateRect(hwnd, null, 0);
}

fn finish(hwnd: w.HANDLE) void {
    app_state.g_search_workspace_delete_confirm = null;
    workspaces.clearWorkspaceDeleteFlow();
    refresh(hwnd);
}

pub fn takeRequested() void {
    workspaces.clearWorkspaceDeleteFlow();
    var buf: [64]u8 = undefined;
    if (workspaces.takeRequestedWorkspaceDelete(&buf)) |requested_id| {
        if (workspaces.findWorkspace(requested_id)) |wi| {
            app_state.g_search_workspace_mode = true;
            app_state.g_search_workspace_action = .open;
            app_state.g_search_workspace_delete_mode = true;
            app_state.g_search_workspace_delete_confirm = null;
            if (workspaces.workspaceHasChatsByIndex(wi)) workspaces.setWorkspaceDeleteMoveSource(wi);
        }
    }
}

pub fn confirm(hwnd: w.HANDLE, workspace_idx: u32) void {
    if (workspaces.workspaceDeleteMoveSource()) |source| {
        _ = workspaces.deleteWorkspaceMovingChats(source, workspace_idx);
        finish(hwnd);
        return;
    }
    if (app_state.g_search_workspace_delete_confirm) |confirm_idx| {
        if (confirm_idx == workspace_idx) {
            if (!workspaces.workspaceHasChatsByIndex(workspace_idx)) {
                _ = workspaces.deleteWorkspaceByIndex(workspace_idx);
                finish(hwnd);
                return;
            }
            workspaces.setWorkspaceDeleteMoveSource(workspace_idx);
            refresh(hwnd);
            return;
        }
    }
    app_state.g_search_workspace_delete_confirm = workspace_idx;
    _ = w.InvalidateRect(hwnd, null, 0);
}
