const app_state = @import("app_state.zig");
const std = @import("std");
const WINAPI = @import("win32.zig").WINAPI;
const UINT = @import("win32.zig").UINT;
const WPARAM = @import("win32.zig").WPARAM;
const LPARAM = @import("win32.zig").LPARAM;
const LRESULT = @import("win32.zig").LRESULT;
const HANDLE = @import("win32.zig").HANDLE;
const LPCWSTR = @import("win32.zig").LPCWSTR;
const WS_VISIBLE = @import("win32.zig").WS_VISIBLE;
const WS_CHILD = @import("win32.zig").WS_CHILD;
const WS_BORDER = @import("win32.zig").WS_BORDER;
const WM_KILLFOCUS = @import("win32.zig").WM_KILLFOCUS;
const SW_SHOW = @import("win32.zig").SW_SHOW;
const SW_HIDE = @import("win32.zig").SW_HIDE;
const SWP_HIDEWINDOW = @import("win32.zig").SWP_HIDEWINDOW;
const SWP_NOMOVE = @import("win32.zig").SWP_NOMOVE;
const SWP_NOSIZE = @import("win32.zig").SWP_NOSIZE;
const SWP_NOZORDER = @import("win32.zig").SWP_NOZORDER;
const SWP_NOACTIVATE = @import("win32.zig").SWP_NOACTIVATE;
const ES_AUTOHSCROLL = @import("win32.zig").ES_AUTOHSCROLL;
const WM_KEYDOWN = @import("win32.zig").WM_KEYDOWN;
const WM_APP_SEARCH_OPEN = @import("win32.zig").WM_APP_SEARCH_OPEN;
const WM_APP_URLBAR_DISMISS = @import("win32.zig").WM_APP_URLBAR_DISMISS;
const TIMER_REFOCUS = @import("win32.zig").TIMER_REFOCUS;
const POINT = @import("win32.zig").POINT;
const RECT = @import("win32.zig").RECT;
const CreateWindowExW = @import("win32.zig").CreateWindowExW;
const GetClientRect = @import("win32.zig").GetClientRect;
const SetWindowLongPtrW = @import("win32.zig").SetWindowLongPtrW;
const GetWindowLongPtrW = @import("win32.zig").GetWindowLongPtrW;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const GetDC = @import("win32.zig").GetDC;
const ReleaseDC = @import("win32.zig").ReleaseDC;
const DestroyWindow = @import("win32.zig").DestroyWindow;
const GetWindowTextW = @import("win32.zig").GetWindowTextW;
const SetWindowTextW = @import("win32.zig").SetWindowTextW;
const GetForegroundWindow = @import("win32.zig").GetForegroundWindow;
const DeleteObject = @import("win32.zig").DeleteObject;
const SelectObject = @import("win32.zig").SelectObject;
const CreateCompatibleDC = @import("win32.zig").CreateCompatibleDC;
const CreateCompatibleBitmap = @import("win32.zig").CreateCompatibleBitmap;
const BitBlt = @import("win32.zig").BitBlt;
const DeleteDC = @import("win32.zig").DeleteDC;
const GDI_SRCCOPY = @import("win32.zig").GDI_SRCCOPY;
const SendMessageW = @import("win32.zig").SendMessageW;
const CallWindowProcW = @import("win32.zig").CallWindowProcW;
const CreatePopupMenu = @import("win32.zig").CreatePopupMenu;
const AppendMenuW = @import("win32.zig").AppendMenuW;
const TrackPopupMenu = @import("fonts.zig").trackPopupMenu;
const DestroyMenu = @import("win32.zig").DestroyMenu;
const ClientToScreen = @import("win32.zig").ClientToScreen;
const MF_STRING = @import("win32.zig").MF_STRING;
const TPM_RETURNCMD = @import("win32.zig").TPM_RETURNCMD;
const TPM_LEFTALIGN = @import("win32.zig").TPM_LEFTALIGN;
const MENU_MOVE_TO_WORKSPACE_BASE = @import("win32.zig").MENU_MOVE_TO_WORKSPACE_BASE;
const MENU_MOVE_TO_PILL_BASE = @import("win32.zig").MENU_MOVE_TO_PILL_BASE;
const MENU_HEADER_RENAME = @import("win32.zig").MENU_HEADER_RENAME;
const MENU_HEADER_COLLAPSE = @import("win32.zig").MENU_HEADER_COLLAPSE;
const MENU_HEADER_UNGROUP = @import("win32.zig").MENU_HEADER_UNGROUP;
const MENU_HEADER_CLOSE = @import("win32.zig").MENU_HEADER_CLOSE;
const MENU_HEADER_NEW_TAB = @import("win32.zig").MENU_HEADER_NEW_TAB;
const MENU_HEADER_MOVE_WORKSPACE = @import("win32.zig").MENU_HEADER_MOVE_WORKSPACE;
const MENU_HEADER_COLOR_BASE = @import("win32.zig").MENU_HEADER_COLOR_BASE;
const L = @import("startup.zig").L;
const getInstanceName = @import("startup.zig").getInstanceName;
const SIDEBAR_W = @import("browser_pane.zig").SIDEBAR_W;
const tabRowH = @import("browser_pane.zig").tabRowH;
const MAX_LWS = @import("app_state.zig").MAX_LWS;
const threadTitleHeight = @import("browser_pane.zig").threadTitleHeight;
const threadTitleTop = @import("browser_pane.zig").threadTitleTop;
const findGroupIdx = @import("sidebar.zig").findGroupIdx;
const GROUP_COLORS = @import("app_state.zig").GROUP_COLORS;
const GROUP_COLOR_NAMES = @import("app_state.zig").GROUP_COLOR_NAMES;
const deleteGroup = @import("sidebar.zig").deleteGroup;
const normalizeGroupOrder = @import("sidebar.zig").normalizeGroupOrder;
const Row = @import("app_state.zig").Row;
const MAX_ROWS = @import("app_state.zig").MAX_ROWS;
const layoutRows = @import("sidebar.zig").layoutRows;
const tabRowY = @import("sidebar.zig").tabRowY;
const PostMessageW = @import("focus.zig").PostMessageW;
const focusGuardDispatchTick = @import("focus.zig").focusGuardDispatchTick;
const focusGuard = @import("focus.zig").focusGuard;
const foregroundIsOurs = @import("focus.zig").foregroundIsOurs;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const SetForegroundWindow = @import("focus.zig").SetForegroundWindow;
const SetFocus = @import("focus.zig").SetFocus;
const SetWindowPos = @import("focus.zig").SetWindowPos;
const ShowWindow = @import("focus.zig").ShowWindow;
const isCtrlDown = @import("focus.zig").isCtrlDown;
const MAX_WORKSPACES = @import("app_state.zig").MAX_WORKSPACES;
const setWindowDisplayNameWide = @import("workspaces.zig").setWindowDisplayNameWide;
const updateMainWindowTitle = @import("workspaces.zig").updateMainWindowTitle;
const mergeWorkspaceRegistryFromDisk = @import("workspaces.zig").mergeWorkspaceRegistryFromDisk;
const scanLiveWorkspaceWindows = @import("workspaces.zig").scanLiveWorkspaceWindows;
const saveWorkspaceRegistry = @import("workspaces.zig").saveWorkspaceRegistry;
const syncInProcessWorkspacesToRegistry = @import("workspaces.zig").syncInProcessWorkspacesToRegistry;
const moveGroupToNewWorkspace = @import("workspaces.zig").moveGroupToNewWorkspace;
const moveGroupToWorkspace = @import("workspaces.zig").moveGroupToWorkspace;
const moveGroupToPill = @import("workspaces.zig").moveGroupToPill;
const workspaceCanMoveIntoClosedStandalone = @import("workspaces.zig").workspaceCanMoveIntoClosedStandalone;
const moveGroupToClosedWorkspace = @import("workspaces.zig").moveGroupToClosedWorkspace;
const newPillForMove = @import("workspaces.zig").newPillForMove;
const saveSession = @import("session.zig").saveSession;
const paletteWideTextMatchRank = @import("command_palette.zig").paletteWideTextMatchRank;
const applyCanonicalSessionRename = @import("archive.zig").applyCanonicalSessionRename;
const rejectPinnedGroupClose = @import("archive.zig").rejectPinnedGroupClose;
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;
const closeShell = @import("console.zig").closeShell;
const clampSidebarScroll = @import("console.zig").clampSidebarScroll;
const workspaceDisplayName = @import("workspaces.zig").workspaceDisplayName;
const isOtherWorkspaceSlot = @import("workspaces.zig").isOtherWorkspaceSlot;
const switchToWorkspace = @import("workspaces.zig").switchToWorkspace;
const keybd_event = @import("win32.zig").keybd_event;
const VK_MENU = @import("app_state.zig").VK_MENU;
const KEYEVENTF_KEYUP = @import("app_state.zig").KEYEVENTF_KEYUP;
const focusActiveShell = @import("focus.zig").focusActiveShell;
const activeShellHasForegroundFocus = @import("focus.zig").activeShellHasForegroundFocus;
const requestShellRefocus = @import("focus.zig").requestShellRefocus;
const navigateBrowserPane = @import("browser_pane.zig").navigateBrowserPane;
const hideAllBrowserChrome = @import("browser_pane.zig").hideAllBrowserChrome;
const updateBrowserVisibility = @import("browser_pane.zig").updateBrowserVisibility;
const closeWebView2 = @import("browser_pane.zig").closeWebView2;
const chatViewLayout = @import("chat_composer.zig").chatViewLayout;
const refreshChatTranscript = @import("chat_session.zig").refreshChatTranscript;
const chatAcClose = @import("chat_composer.zig").chatAcClose;
const showShellConsole = @import("chat_composer.zig").showShellConsole;
const repositionActive = @import("window_layout.zig").repositionActive;
const threadTitleNameRectFor = @import("drawing.zig").threadTitleNameRectFor;
const updateSearchResults = @import("command_palette.zig").updateSearchResults;
const KillTimer = @import("win32.zig").KillTimer;
const publishInboxState = @import("inbox.zig").publishInboxState;
const closeInbox = @import("inbox.zig").closeInbox;

pub fn editSubclassProc(hwnd: HANDLE, msg: UINT, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT {
    if (@import("fonts.zig").editMessage(hwnd, app_state.g_main_hwnd, msg, lp)) |result| return result;
    const prior_focus_action = app_state.g_focus_user_action_tick;
    app_state.g_focus_user_action_tick = focusGuardDispatchTick(msg, wp, lp);
    defer app_state.g_focus_user_action_tick = prior_focus_action;
    if (msg == WM_KILLFOCUS and app_state.g_edit_is_browser_urlbar and app_state.g_main_hwnd != null) {
        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_URLBAR_DISMISS, 0, 0);
    }
    if (msg == WM_KEYDOWN) {
        if (wp == 0x41 and isCtrlDown()) {
            _ = SendMessageW(hwnd, 0x00B1, 0, @bitCast(@as(isize, -1)));
            return 0;
        }
        if (wp == 0x0D) {
            app_state.g_focus_user_action_tick = renameCommitActionTick(app_state.g_focus_user_action_tick, GetTickCount64(), foregroundIsOurs());
            commitRename();
            return 0;
        }
        if (wp == 0x1B) {
            const h = app_state.g_edit_hwnd;
            const was_browser_urlbar = app_state.g_edit_is_browser_urlbar;
            const was_inbox = app_state.g_edit_is_inbox;
            app_state.g_edit_hwnd = null;
            app_state.g_edit_is_group = false;
            app_state.g_edit_is_window = false;
            app_state.g_edit_is_browser_urlbar = false;
            app_state.g_edit_is_thread_title = false;
            app_state.g_edit_is_inbox = false;
            app_state.g_edit_sync_remote_name = false;
            _ = DestroyWindow(h);
            _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
            if (was_browser_urlbar) {
                _ = InvalidateRect(app_state.g_urlbar_hwnd, null, 0);
                app_state.g_shell_focused = true;
                focusActiveShell();
                if (!activeShellHasForegroundFocus()) requestShellRefocus(60, 8);
            } else if (was_inbox) {
                _ = SetFocus(app_state.g_main_hwnd);
            }
            return 0;
        }
    }
    return CallWindowProcW(app_state.g_edit_orig_proc, hwnd, msg, wp, lp);
}

pub fn startWindowRename() void {
    if (app_state.g_starred_workspace) return;
    if (!focusGuard(app_state.g_main_hwnd)) return;
    commitRename();
    _ = KillTimer(app_state.g_main_hwnd, TIMER_REFOCUS);
    app_state.g_edit_is_window = true;
    app_state.g_edit_is_group = false;
    app_state.g_edit_is_thread_title = false;
    app_state.g_edit_is_inbox = false;
    app_state.g_edit_sync_remote_name = false;
    app_state.g_edit_idx = 0;

    const edit_w: i32 = if (SIDEBAR_W() < 300) 300 else SIDEBAR_W() - 24;
    app_state.g_edit_hwnd = CreateWindowExW(
        0,
        L("EDIT"),
        null,
        WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOHSCROLL,
        12,
        10,
        edit_w,
        24,
        app_state.g_main_hwnd,
        null,
        null,
        null,
    );
    if (app_state.g_edit_hwnd != null) {
        @import("fonts.zig").setControlFont(app_state.g_edit_hwnd);
        const GWLP_WNDPROC: i32 = -4;
        app_state.g_edit_orig_proc = GetWindowLongPtrW(app_state.g_edit_hwnd, GWLP_WNDPROC);
        _ = SetWindowLongPtrW(app_state.g_edit_hwnd, GWLP_WNDPROC, @bitCast(@intFromPtr(&editSubclassProc)));
        if (app_state.g_single_window) {
            var nbuf: [32]u8 = undefined;
            const nm = workspaceDisplayName(app_state.g_active_workspace, &nbuf);
            var wbuf: [33]u16 = std.mem.zeroes([33]u16);
            for (nm, 0..) |c, ci| wbuf[ci] = c;
            _ = SetWindowTextW(app_state.g_edit_hwnd, @ptrCast(&wbuf));
        } else {
            _ = SetWindowTextW(app_state.g_edit_hwnd, @ptrCast(&app_state.g_window_display_name));
        }
        keybd_event(VK_MENU, 0, 0, 0);
        _ = SetForegroundWindow(app_state.g_main_hwnd);
        _ = SetFocus(app_state.g_edit_hwnd);
        keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);
        _ = SendMessageW(app_state.g_edit_hwnd, 0x00B1, 0, @bitCast(@as(isize, -1)));
    }
}

pub fn startRename(idx: u32) void {
    startRenameInternal(idx, false);
}

fn startRenameSync(idx: u32) void {
    startRename(idx);
}

pub fn beginPaletteRenameInput(idx: u32) bool {
    if (idx >= app_state.shell_count or !app_state.g_search_active) return false;
    app_state.g_search_rename_input_mode = true;
    app_state.g_search_rename_sid = app_state.shells[idx].shell_id;
    app_state.g_search_rename_select_all = true;
    app_state.g_search_len = @min(app_state.shells[idx].name_len, @as(u32, @intCast(app_state.g_search_buf.len - 1)));
    @memcpy(app_state.g_search_buf[0..app_state.g_search_len], app_state.shells[idx].name[0..app_state.g_search_len]);
    app_state.g_search_sel = 0;
    app_state.g_search_scroll = 0;
    updateSearchResults();
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    return true;
}

pub fn startThreadTitleRename() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    startRenameInternal(app_state.active_shell, true);
}

fn startRenameInternal(idx: u32, thread_title: bool) void {
    if (!focusGuard(app_state.g_main_hwnd)) return;
    commitRename();
    if (idx >= app_state.shell_count) return;
    _ = KillTimer(app_state.g_main_hwnd, TIMER_REFOCUS);
    app_state.g_edit_tab = idx;
    app_state.g_edit_is_group = false;
    app_state.g_edit_is_window = false;
    app_state.g_edit_is_browser_urlbar = false;
    app_state.g_edit_is_thread_title = thread_title;
    app_state.g_edit_is_inbox = false;
    app_state.g_edit_sync_remote_name = true;
    app_state.g_edit_idx = idx;
    const tth_edit = threadTitleHeight();
    if ((thread_title or app_state.g_hide_sidebar) and tth_edit > 0 and app_state.g_main_hwnd != null) {
        var crc: RECT = std.mem.zeroes(RECT);
        _ = GetClientRect(app_state.g_main_hwnd, &crc);
        const edit_h: i32 = 24;
        const edit_y = threadTitleTop() + @divTrunc(tth_edit - edit_h, 2);
        const name_rc = threadTitleNameRectFor(crc.right, idx) orelse RECT{
            .left = SIDEBAR_W() + 16,
            .top = threadTitleTop(),
            .right = crc.right - 120,
            .bottom = threadTitleTop() + tth_edit,
        };
        const edit_x = name_rc.left;
        const edit_w = @max(name_rc.right - name_rc.left, 100);
        app_state.g_edit_hwnd = CreateWindowExW(0, L("EDIT"), null, WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOHSCROLL, edit_x, edit_y, edit_w, edit_h, app_state.g_main_hwnd, null, null, null);
    } else {
        const logical_y: i32 = tabRowY(idx) orelse (@as(i32, @intCast(idx)) * tabRowH());
        const y: i32 = logical_y - app_state.g_sidebar_scroll;
        app_state.g_edit_hwnd = CreateWindowExW(
            0,
            L("EDIT"),
            null,
            WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOHSCROLL,
            12,
            y + 3,
            SIDEBAR_W() - 54,
            22,
            app_state.g_main_hwnd,
            null,
            null,
            null,
        );
    }
    if (app_state.g_edit_hwnd != null) {
        @import("fonts.zig").setControlFont(app_state.g_edit_hwnd);
        const GWLP_WNDPROC: i32 = -4;
        app_state.g_edit_orig_proc = GetWindowLongPtrW(app_state.g_edit_hwnd, GWLP_WNDPROC);
        _ = SetWindowLongPtrW(app_state.g_edit_hwnd, GWLP_WNDPROC, @bitCast(@intFromPtr(&editSubclassProc)));
        _ = SetWindowTextW(app_state.g_edit_hwnd, @ptrCast(&app_state.shells[idx].name));
        if (GetForegroundWindow() == app_state.g_main_hwnd) {
            _ = SetFocus(app_state.g_edit_hwnd);
        } else {
            keybd_event(VK_MENU, 0, 0, 0);
            _ = SetForegroundWindow(app_state.g_main_hwnd);
            _ = SetFocus(app_state.g_edit_hwnd);
            keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);
        }
        _ = SendMessageW(app_state.g_edit_hwnd, 0x00B1, 0, @bitCast(@as(isize, -1)));
    }
}

pub fn startGroupRename(gidx: u32) void {
    if (!focusGuard(app_state.g_main_hwnd)) return;
    commitRename();
    if (gidx >= app_state.group_count) return;
    _ = KillTimer(app_state.g_main_hwnd, TIMER_REFOCUS);
    app_state.g_edit_is_group = true;
    app_state.g_edit_is_window = false;
    app_state.g_edit_is_thread_title = false;
    app_state.g_edit_is_inbox = false;
    app_state.g_edit_sync_remote_name = false;
    app_state.g_edit_idx = gidx;

    var rows: [MAX_ROWS]Row = undefined;
    const n = layoutRows(&rows);
    var hdr_y: i32 = 0;
    for (0..n) |ri| {
        if (rows[ri].kind == .header and rows[ri].gidx == gidx) {
            hdr_y = rows[ri].y;
            break;
        }
    }
    const y: i32 = hdr_y - app_state.g_sidebar_scroll;

    app_state.g_edit_hwnd = CreateWindowExW(
        0,
        L("EDIT"),
        null,
        WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOHSCROLL,
        24,
        y + 3,
        SIDEBAR_W() - 48,
        22,
        app_state.g_main_hwnd,
        null,
        null,
        null,
    );
    if (app_state.g_edit_hwnd != null) {
        @import("fonts.zig").setControlFont(app_state.g_edit_hwnd);
        const GWLP_WNDPROC: i32 = -4;
        app_state.g_edit_orig_proc = GetWindowLongPtrW(app_state.g_edit_hwnd, GWLP_WNDPROC);
        _ = SetWindowLongPtrW(app_state.g_edit_hwnd, GWLP_WNDPROC, @bitCast(@intFromPtr(&editSubclassProc)));
        _ = SetWindowTextW(app_state.g_edit_hwnd, @ptrCast(&app_state.groups[gidx].name));
        keybd_event(VK_MENU, 0, 0, 0);
        _ = SetForegroundWindow(app_state.g_main_hwnd);
        _ = SetFocus(app_state.g_edit_hwnd);
        keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);
        _ = SendMessageW(app_state.g_edit_hwnd, 0x00B1, 0, @bitCast(@as(isize, -1)));
    }
}

pub fn commitRename() void {
    if (app_state.g_edit_hwnd == null) return;
    if (app_state.g_edit_is_browser_urlbar) {
        var buf: [512]u16 = std.mem.zeroes([512]u16);
        const len = GetWindowTextW(app_state.g_edit_hwnd, &buf, 512);
        const ulen: usize = if (len > 0) @intCast(len) else 0;
        _ = DestroyWindow(app_state.g_edit_hwnd);
        app_state.g_edit_hwnd = null;
        app_state.g_edit_is_browser_urlbar = false;
        app_state.g_edit_is_thread_title = false;
        app_state.g_edit_sync_remote_name = false;
        _ = InvalidateRect(app_state.g_urlbar_hwnd, null, 0);
        if (ulen > 0) {
            var url8: [512]u8 = undefined;
            for (0..ulen) |i| url8[i] = if (buf[i] < 128) @intCast(buf[i]) else '?';
            navigateBrowserPane(app_state.active_shell, url8[0..ulen]);
            saveSession();
        }
        app_state.g_shell_focused = true;
        focusActiveShell();
        if (!activeShellHasForegroundFocus()) requestShellRefocus(60, 8);
        return;
    }
    if (app_state.g_edit_is_window) {
        var buf: [64]u16 = std.mem.zeroes([64]u16);
        const len = GetWindowTextW(app_state.g_edit_hwnd, &buf, 64);
        const ulen: usize = if (len > 0) @intCast(len) else 0;
        if (app_state.g_single_window) {
            const ws = app_state.g_active_workspace;
            if (isOtherWorkspaceSlot(ws) or paletteWideTextMatchRank(buf[0..ulen], L("Other")[0..5]) == 4) {
                showHeaderNoticeAscii("Other is the permanent catch-all", 3500, true);
            } else {
                const cap = @min(ulen, app_state.g_ws_names[ws].len);
                var nlen: u32 = 0;
                for (0..cap) |ci| {
                    const ch = buf[ci];
                    app_state.g_ws_names[ws][nlen] = if (ch < 128) @intCast(ch) else '?';
                    nlen += 1;
                }
                app_state.g_ws_name_len[ws] = nlen;
            }
            syncInProcessWorkspacesToRegistry();
            publishInboxState();
            saveSession();
        } else {
            setWindowDisplayNameWide(buf[0..ulen]);
            saveWorkspaceRegistry();
        }
        updateMainWindowTitle();
        _ = DestroyWindow(app_state.g_edit_hwnd);
        app_state.g_edit_hwnd = null;
        app_state.g_edit_is_window = false;
        app_state.g_edit_is_thread_title = false;
        app_state.g_edit_sync_remote_name = false;
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
        return;
    }
    if (app_state.g_edit_is_group) {
        if (app_state.g_edit_idx < app_state.group_count) {
            var buf: [64]u16 = std.mem.zeroes([64]u16);
            const len = GetWindowTextW(app_state.g_edit_hwnd, &buf, 64);
            const ulen: u32 = if (len > 0) @intCast(len) else 0;
            @memcpy(app_state.groups[app_state.g_edit_idx].name[0..ulen], buf[0..ulen]);
            if (ulen < app_state.groups[app_state.g_edit_idx].name.len) app_state.groups[app_state.g_edit_idx].name[ulen] = 0;
            app_state.groups[app_state.g_edit_idx].name_len = ulen;
        }
        _ = DestroyWindow(app_state.g_edit_hwnd);
        app_state.g_edit_hwnd = null;
        app_state.g_edit_is_group = false;
        app_state.g_edit_is_window = false;
        app_state.g_edit_is_thread_title = false;
        app_state.g_edit_sync_remote_name = false;
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
        saveSession();
        return;
    }
    const was_inbox_rename = app_state.g_edit_is_inbox;
    const renamed_sid: u32 = if (app_state.g_edit_tab < app_state.shell_count) app_state.shells[app_state.g_edit_tab].shell_id else 0;
    if (app_state.g_edit_tab < app_state.shell_count) {
        var buf: [64]u16 = std.mem.zeroes([64]u16);
        const len = GetWindowTextW(app_state.g_edit_hwnd, &buf, 64);
        const sync_remote = app_state.g_edit_sync_remote_name;
        const ulen: usize = if (len > 0) @intCast(len) else 0;
        _ = applyCanonicalSessionRename(app_state.g_edit_tab, buf[0..ulen], sync_remote);
    }
    _ = DestroyWindow(app_state.g_edit_hwnd);
    app_state.g_edit_hwnd = null;
    app_state.g_edit_is_thread_title = false;
    app_state.g_edit_is_inbox = false;
    app_state.g_edit_sync_remote_name = false;
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    saveSession();
    if (was_inbox_rename) {
        if (renamed_sid != 0 and app_state.g_edit_tab < app_state.shell_count) {
            for (0..app_state.g_inbox_row_count) |ri| {
                const row = &app_state.g_inbox_rows[ri];
                if (row.sid != renamed_sid or app_state.g_inbox_ws[row.ws].hwnd != @intFromPtr(app_state.g_main_hwnd)) continue;
                const name_len: usize = @min(app_state.shells[app_state.g_edit_tab].name_len, row.name.len - 1);
                for (0..name_len) |ni| {
                    const ch = app_state.shells[app_state.g_edit_tab].name[ni];
                    row.name[ni] = if (ch < 128) @intCast(ch) else '?';
                }
                row.name[name_len] = 0;
                row.name_len = @intCast(name_len);
            }
        }
        publishInboxState();
        _ = SetFocus(app_state.g_main_hwnd);
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
        return;
    }
    app_state.g_shell_focused = true;
    focusActiveShell();
    if (!activeShellHasForegroundFocus()) requestShellRefocus(60, 8);
}

pub fn openTabContextPalette(hwnd: HANDLE, tab_idx: u32) void {
    if (tab_idx >= app_state.shell_count) return;
    const sid = app_state.shells[tab_idx].shell_id;
    _ = SendMessageW(hwnd, WM_APP_SEARCH_OPEN, 0, 0);
    app_state.g_search_tabctx_mode = true;
    app_state.g_tabctx_sid = sid;
    app_state.g_search_len = 0;
    app_state.g_search_sel = 1;
    app_state.g_search_scroll = 0;
    updateSearchResults();
    _ = InvalidateRect(hwnd, null, 0);
}

pub fn paletteGroupId() u32 {
    if (app_state.g_search_groupctx_mode) return app_state.g_groupctx_gid;
    return if (app_state.active_shell < app_state.shell_count) @import("sidebar.zig").tabGroupId(app_state.active_shell) else 0;
}

pub fn groupPaletteCommand(action: usize) usize {
    return switch (action) {
        0 => MENU_HEADER_NEW_TAB,
        1 => MENU_HEADER_RENAME,
        2 => MENU_HEADER_COLLAPSE,
        3 => MENU_HEADER_UNGROUP,
        4 => MENU_HEADER_CLOSE,
        5 => MENU_HEADER_MOVE_WORKSPACE,
        8...15 => MENU_HEADER_COLOR_BASE + action - 8,
        16...24 => MENU_MOVE_TO_PILL_BASE + action - 16,
        25...88 => MENU_MOVE_TO_WORKSPACE_BASE + action - 25,
        else => 0,
    };
}

pub fn groupPaletteLabel(action: usize, buf: *[192]u16) usize {
    const gi = findGroupIdx(paletteGroupId()) orelse return 0;
    const label: []const u8 = switch (action) {
        0 => "New tab in this group",
        1 => "Rename group",
        2 => if (app_state.groups[gi].collapsed) "Expand group" else "Collapse group",
        3 => "Ungroup",
        4 => "Close all tabs in group",
        5 => "Move group to new workspace",
        8...15 => GROUP_COLOR_NAMES[action - 8],
        16...88 => "Move group to workspace: ",
        else => return 0,
    };
    var len: usize = 0;
    if (action >= 8 and action < 16) {
        for ("Group color: ") |c| {
            buf[len] = c;
            len += 1;
        }
    }
    for (label) |c| {
        buf[len] = c;
        len += 1;
    }
    if (action >= 16 and action < 25) {
        const slot = action - 16;
        for (app_state.g_ws_names[slot][0..app_state.g_ws_name_len[slot]]) |c| {
            buf[len] = c;
            len += 1;
        }
        if (app_state.g_ws_name_len[slot] == 0) {
            buf[len] = @intCast('1' + slot);
            len += 1;
        }
    } else if (action >= 25 and action < 89) {
        const wi = action - 25;
        if (wi >= app_state.g_workspace_count) return 0;
        const ws = &app_state.g_workspaces[wi];
        for (ws.name[0..ws.name_len]) |c| {
            buf[len] = c;
            len += 1;
        }
    }
    return len;
}

pub fn groupPaletteActionAvailable(action: usize) bool {
    if (findGroupIdx(paletteGroupId()) == null or groupPaletteCommand(action) == 0) return false;
    if (action >= 16 and action < 25) return app_state.g_single_window and action - 16 < app_state.g_lws_count and !app_state.g_ws_snoozed[action - 16] and action - 16 != app_state.g_active_workspace;
    if (action >= 25) return action - 25 < app_state.g_workspace_count and (if (app_state.g_single_window) workspaceCanMoveIntoClosedStandalone(@intCast(action - 25)) else !std.mem.eql(u8, app_state.g_workspaces[action - 25].id[0..app_state.g_workspaces[action - 25].id_len], getInstanceName()));
    return true;
}

pub fn openGroupContextPalette(hwnd: HANDLE, gidx: u32) void {
    if (gidx >= app_state.group_count) return;
    const gid = app_state.groups[gidx].id;
    mergeWorkspaceRegistryFromDisk();
    if (app_state.g_single_window) scanLiveWorkspaceWindows(false);
    _ = SendMessageW(hwnd, WM_APP_SEARCH_OPEN, 0, 0);
    app_state.g_search_groupctx_mode = true;
    app_state.g_groupctx_gid = gid;
    app_state.g_search_len = 0;
    app_state.g_search_sel = 0;
    app_state.g_search_scroll = 0;
    updateSearchResults();
    _ = InvalidateRect(hwnd, null, 0);
}

pub fn runGroupPaletteAction(hwnd: HANDLE, gidx: u32, action: usize) void {
    if (gidx >= app_state.group_count) return;
    const cmd_u = groupPaletteCommand(action);
    if (cmd_u == MENU_HEADER_MOVE_WORKSPACE) {
        if (app_state.g_single_window) {
            if (newPillForMove()) |slot| moveGroupToPill(gidx, slot);
            return;
        }
        moveGroupToNewWorkspace(gidx);
        return;
    } else if (cmd_u >= MENU_MOVE_TO_PILL_BASE and cmd_u < MENU_MOVE_TO_PILL_BASE + MAX_LWS) {
        moveGroupToPill(gidx, @intCast(cmd_u - MENU_MOVE_TO_PILL_BASE));
        return;
    } else if (cmd_u >= MENU_MOVE_TO_WORKSPACE_BASE and cmd_u < MENU_MOVE_TO_WORKSPACE_BASE + MAX_WORKSPACES) {
        const wi = cmd_u - MENU_MOVE_TO_WORKSPACE_BASE;
        if (wi < app_state.g_workspace_count) {
            if (app_state.g_single_window) {
                moveGroupToClosedWorkspace(gidx, @intCast(wi));
            } else {
                moveGroupToWorkspace(gidx, @intCast(wi));
            }
        }
        return;
    }
    const gid = app_state.groups[gidx].id;
    if (cmd_u == MENU_HEADER_NEW_TAB) {
        app_state.g_pending_new_tab_group = gid;
        _ = PostMessageW(hwnd, WM_APP_SEARCH_OPEN, 0, 0);
    } else if (cmd_u == MENU_HEADER_RENAME) {
        startGroupRename(gidx);
    } else if (cmd_u == MENU_HEADER_COLLAPSE) {
        app_state.groups[gidx].collapsed = !app_state.groups[gidx].collapsed;
        clampSidebarScroll();
        saveSession();
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    } else if (cmd_u == MENU_HEADER_UNGROUP) {
        for (0..app_state.shell_count) |i| {
            if (@import("sidebar.zig").tabGroupId(i) == gid) @import("sidebar.zig").setTabGroupId(i, 0);
        }
        deleteGroup(gid);
        normalizeGroupOrder();
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
        saveSession();
    } else if (cmd_u == MENU_HEADER_CLOSE) {
        if (rejectPinnedGroupClose(gid)) return;
        var i: u32 = app_state.shell_count;
        while (i > 0) {
            i -= 1;
            if (@import("sidebar.zig").tabGroupId(i) == gid) closeShell(i);
        }
    } else if (cmd_u >= MENU_HEADER_COLOR_BASE and cmd_u < MENU_HEADER_COLOR_BASE + GROUP_COLORS.len) {
        const ci = cmd_u - MENU_HEADER_COLOR_BASE;
        app_state.groups[gidx].color = @intCast(ci);
        app_state.groups[gidx].color_set = true;
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
        saveSession();
    }
}

pub fn clearSearchBackdrop() void {
    if (app_state.g_search_backdrop_bmp != null) {
        _ = DeleteObject(app_state.g_search_backdrop_bmp);
    }
    app_state.g_search_backdrop_bmp = null;
    app_state.g_search_backdrop_w = 0;
    app_state.g_search_backdrop_h = 0;
}

pub fn hideShellsForOverlay() void {
    chatAcClose();
    closeWebView2();
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].hwnd != null) {
            _ = SetWindowPos(app_state.shells[i].hwnd, null, 0, 0, 0, 0, SWP_HIDEWINDOW | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
        }
    }
    if (app_state.g_chat_status_hwnd != null) _ = SetWindowPos(app_state.g_chat_status_hwnd, null, 0, 0, 0, 0, SWP_HIDEWINDOW | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
    if (app_state.g_chat_transcript_hwnd != null) _ = SetWindowPos(app_state.g_chat_transcript_hwnd, null, 0, 0, 0, 0, SWP_HIDEWINDOW | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
    if (app_state.g_chat_composer_hwnd != null) _ = SetWindowPos(app_state.g_chat_composer_hwnd, null, 0, 0, 0, 0, SWP_HIDEWINDOW | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
    hideAllBrowserChrome();
}

pub fn showActiveShellAfterOverlay() void {
    if (app_state.g_all_sessions_active) return;
    if (app_state.g_search_from_inbox) {
        app_state.g_search_from_inbox = false;
        app_state.g_search_spawn_ws = 0xFF;
        if (app_state.g_inbox_active) closeInbox(app_state.g_main_hwnd);
        return;
    }
    if (app_state.active_shell >= app_state.shell_count) return;
    if (app_state.g_single_window and app_state.shells[app_state.active_shell].workspace != app_state.g_active_workspace) return;
    if (app_state.shells[app_state.active_shell].hwnd == null) return;
    if (app_state.g_chat_active) {
        _ = ShowWindow(app_state.g_chat_transcript_hwnd, SW_SHOW);
        _ = ShowWindow(app_state.g_chat_composer_hwnd, SW_SHOW);
        repositionActive();
        updateBrowserVisibility();
        refreshChatTranscript(true);
        _ = SetFocus(app_state.g_chat_composer_hwnd);
        return;
    }
    _ = showShellConsole(app_state.active_shell, SW_SHOW, "showActiveShellAfterOverlay");
    repositionActive();
    updateBrowserVisibility();
}

pub fn applySearchSpawnContext(hwnd: HANDLE) void {
    if (app_state.g_search_from_inbox) {
        app_state.g_search_from_inbox = false;
        if (app_state.g_inbox_active) closeInbox(hwnd);
    }
    if (app_state.g_search_spawn_ws != 0xFF and app_state.g_search_spawn_ws < app_state.g_lws_count and
        !app_state.g_ws_snoozed[app_state.g_search_spawn_ws] and app_state.g_search_spawn_ws != app_state.g_active_workspace)
    {
        switchToWorkspace(app_state.g_search_spawn_ws);
    }
    app_state.g_search_spawn_ws = 0xFF;
}

fn captureChatBackdrop() void {
    if (app_state.g_main_hwnd == null) return;
    const pane = chatViewLayout().pane;
    const w = pane.right - pane.left;
    const h = pane.bottom - pane.top;
    if (w <= 0 or h <= 0) return;

    var top_left = POINT{ .x = pane.left, .y = pane.top };
    _ = ClientToScreen(app_state.g_main_hwnd, &top_left);

    const screen_dc = GetDC(null);
    if (screen_dc == null) return;
    defer _ = ReleaseDC(null, screen_dc);

    const mem_dc = CreateCompatibleDC(screen_dc);
    if (mem_dc == null) return;
    defer _ = DeleteDC(mem_dc);

    const bmp = CreateCompatibleBitmap(screen_dc, w, h);
    if (bmp == null) return;

    const old_bmp = SelectObject(mem_dc, bmp);
    const ok = BitBlt(mem_dc, 0, 0, w, h, screen_dc, top_left.x, top_left.y, GDI_SRCCOPY);
    _ = SelectObject(mem_dc, old_bmp);
    if (ok == 0) {
        _ = DeleteObject(bmp);
        return;
    }

    app_state.g_search_backdrop_bmp = bmp;
    app_state.g_search_backdrop_w = w;
    app_state.g_search_backdrop_h = h;
}

pub fn captureSearchBackdrop() void {
    clearSearchBackdrop();
    if (app_state.g_chat_active) {
        captureChatBackdrop();
        return;
    }
    if (app_state.active_shell >= app_state.shell_count) return;
    const shell_hwnd = app_state.shells[app_state.active_shell].hwnd;
    if (shell_hwnd == null) return;

    var shell_rc: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(shell_hwnd, &shell_rc);
    const w = shell_rc.right - shell_rc.left;
    const h = shell_rc.bottom - shell_rc.top;
    if (w <= 0 or h <= 0) return;

    const src_dc = GetDC(shell_hwnd);
    if (src_dc == null) return;
    defer _ = ReleaseDC(shell_hwnd, src_dc);

    const mem_dc = CreateCompatibleDC(src_dc);
    if (mem_dc == null) return;
    defer _ = DeleteDC(mem_dc);

    const bmp = CreateCompatibleBitmap(src_dc, w, h);
    if (bmp == null) return;

    const old_bmp = SelectObject(mem_dc, bmp);
    const ok = BitBlt(mem_dc, 0, 0, w, h, src_dc, 0, 0, GDI_SRCCOPY);
    _ = SelectObject(mem_dc, old_bmp);
    if (ok == 0) {
        _ = DeleteObject(bmp);
        return;
    }

    app_state.g_search_backdrop_bmp = bmp;
    app_state.g_search_backdrop_w = w;
    app_state.g_search_backdrop_h = h;
}

fn renameCommitActionTick(dispatched_tick: u64, now: u64, foreground_owned: bool) u64 {
    return if (foreground_owned) now else dispatched_tick;
}

test "ISSUE-597 rename Enter retains focus authority after injected input" {
    try std.testing.expectEqual(@as(u64, 5000), renameCommitActionTick(0, 5000, true));
    try std.testing.expectEqual(@as(u64, 5000), renameCommitActionTick(1000, 5000, true));
    try std.testing.expectEqual(@as(u64, 5000), renameCommitActionTick(5000, 5000, true));
    try std.testing.expectEqual(@as(u64, 0), renameCommitActionTick(0, 5000, false));
    try std.testing.expectEqual(@as(u64, 1000), renameCommitActionTick(1000, 5000, false));
}
