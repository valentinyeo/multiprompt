const app_state = @import("app_state.zig");
const std = @import("std");
const APP_VERSION = @import("main.zig").APP_VERSION;
const update_release = @import("update_release.zig");
const update_check = @import("update_check.zig");
const mp_version_marker = @import("main.zig").mp_version_marker;
const DWORD = @import("win32.zig").DWORD;
const HANDLE = @import("win32.zig").HANDLE;
const DT_WORDBREAK = @import("win32.zig").DT_WORDBREAK;
const DT_SINGLELINE = @import("win32.zig").DT_SINGLELINE;
const DT_VCENTER = @import("win32.zig").DT_VCENTER;
const DT_CENTER = @import("win32.zig").DT_CENTER;
const DT_NOPREFIX = @import("win32.zig").DT_NOPREFIX;
const DT_END_ELLIPSIS = @import("win32.zig").DT_END_ELLIPSIS;
const WM_APP_UPDATE_CHANGED = @import("win32.zig").WM_APP_UPDATE_CHANGED;
const RECT = @import("win32.zig").RECT;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const CreateSolidBrush = @import("win32.zig").CreateSolidBrush;
const DeleteObject = @import("win32.zig").DeleteObject;
const SetTextColor = @import("win32.zig").SetTextColor;
const SelectObject = @import("win32.zig").SelectObject;
const CreatePen = @import("win32.zig").CreatePen;
const GetModuleFileNameW = @import("win32.zig").GetModuleFileNameW;
const CloseHandle = @import("win32.zig").CloseHandle;
const GetWindowThreadProcessId = @import("win32.zig").GetWindowThreadProcessId;
const GetCurrentProcessId = @import("win32.zig").GetCurrentProcessId;
const CreateEventW = @import("win32.zig").CreateEventW;
const INVALID_HANDLE_VALUE_PTR = @import("win32.zig").INVALID_HANDLE_VALUE_PTR;
const EnumWindows = @import("win32.zig").EnumWindows;
const RGB = @import("startup.zig").RGB;
const customColorOr = @import("themes.zig").customColorOr;
const SIDEBAR_STICKY_CARD_GAP = @import("app_state.zig").SIDEBAR_STICKY_CARD_GAP;
const remoteHostForShell = @import("capacity.zig").remoteHostForShell;
const sidebarStickyCardRect = @import("capacity.zig").sidebarStickyCardRect;
const UPDATE_CARD_H = @import("app_state.zig").UPDATE_CARD_H;
const FindFirstChangeNotificationW = @import("win32.zig").FindFirstChangeNotificationW;
const FindNextChangeNotification = @import("win32.zig").FindNextChangeNotification;
const FindCloseChangeNotification = @import("win32.zig").FindCloseChangeNotification;
const WaitForMultipleObjects = @import("win32.zig").WaitForMultipleObjects;
const PostMessageW = @import("focus.zig").PostMessageW;
const SetEvent = @import("win32.zig").SetEvent;
const MAX_WORKSPACES = @import("app_state.zig").MAX_WORKSPACES;
const debugLog = @import("diagnostics.zig").debugLog;
const debugLog2 = @import("diagnostics.zig").debugLog2;
const ZigShellWindowList = @import("app_state.zig").ZigShellWindowList;
const listZigShellWindowsEnum = @import("console.zig").listZigShellWindowsEnum;
const rememberOpenWorkspaceForQuit = @import("console.zig").rememberOpenWorkspaceForQuit;
const quitAllZigShellWindows = @import("console.zig").quitAllZigShellWindows;
const clampSidebarScroll = @import("console.zig").clampSidebarScroll;
const drawAscii = @import("drawing.zig").drawAscii;
const uiScaled = @import("drawing.zig").uiScaled;
const paintSidebarCardFrame = @import("capacity.zig").paintSidebarCardFrame;

pub fn updateCardInit() void {
    const n = GetModuleFileNameW(null, &app_state.g_update_path, 520);
    if (n == 0 or n >= 520) return;
    app_state.g_update_path[n] = 0;
    app_state.g_update_path_len = n;
    app_state.g_update_startup_stamp = update_check.statFile(&app_state.g_update_path);
    debugLog2("update-card: launch path stamp captured, marker ", &mp_version_marker);
}

fn updateCardWatchThread(change: HANDLE, stop: HANDLE, hwnd: HANDLE) void {
    defer _ = FindCloseChangeNotification(change);
    const handles = [_]HANDLE{ stop, change };
    while (true) {
        const result = WaitForMultipleObjects(handles.len, &handles, 0, 0xFFFFFFFF);
        if (result == 0) return;
        if (result != 1 or FindNextChangeNotification(change) == 0) {
            _ = PostMessageW(hwnd, WM_APP_UPDATE_CHANGED, 1, 0);
            return;
        }
        _ = PostMessageW(hwnd, WM_APP_UPDATE_CHANGED, 0, 0);
    }
}

pub fn startUpdateCardWatch() bool {
    const path = app_state.g_update_path[0..app_state.g_update_path_len];
    const slash = std.mem.lastIndexOfScalar(u16, path, '\\') orelse return false;
    var directory: [520:0]u16 = @splat(0);
    @memcpy(directory[0 .. slash + 1], path[0 .. slash + 1]);
    const change = FindFirstChangeNotificationW(&directory, 0, 0x1 | 0x8 | 0x10);
    if (change == null or change == INVALID_HANDLE_VALUE_PTR) return false;
    const stop = CreateEventW(null, 1, 0, null);
    if (stop == null) {
        _ = FindCloseChangeNotification(change);
        return false;
    }
    const thread = std.Thread.spawn(.{}, updateCardWatchThread, .{ change, stop, app_state.g_main_hwnd }) catch {
        _ = CloseHandle(stop);
        _ = FindCloseChangeNotification(change);
        return false;
    };
    app_state.g_update_watch_stop = stop;
    app_state.g_update_watch_thread = thread;
    return true;
}

pub fn stopUpdateCardWatch() void {
    if (app_state.g_update_watch_thread) |thread| {
        _ = SetEvent(app_state.g_update_watch_stop);
        thread.join();
        _ = CloseHandle(app_state.g_update_watch_stop);
        app_state.g_update_watch_stop = null;
        app_state.g_update_watch_thread = null;
    }
}

pub fn updateCardVisible() bool {
    if (app_state.g_update_ver_len == 0 or app_state.g_hide_sidebar or app_state.g_sidebar_collapsed or app_state.g_update_relaunching) return false;
    const cur = app_state.g_update_ver[0..app_state.g_update_ver_len];
    return !std.mem.eql(u8, cur, app_state.g_update_dismissed[0..app_state.g_update_dismissed_len]);
}

var card_notes: @import("update_notes.zig").Notes = .{};
var card_notes_logged = false;

fn updateCardHeight() i32 {
    const rows = card_notes.count + @intFromBool(card_notes.total > card_notes.count);
    return uiScaled(UPDATE_CARD_H) + @as(i32, @intCast(rows)) * uiScaled(18);
}

pub fn updateCardSpan() i32 {
    if (!updateCardVisible()) return 0;
    return updateCardHeight() + @import("window_layout.zig").paneGap();
}

pub fn updateCardRect() RECT {
    const sticky = sidebarStickyCardRect();
    return .{
        .left = sticky.left,
        .top = sticky.top - @import("window_layout.zig").paneGap() - updateCardHeight(),
        .right = sticky.right,
        .bottom = sticky.top - @import("window_layout.zig").paneGap(),
    };
}

fn updateCardButtonRect(card: RECT) RECT {
    return .{ .left = card.left + uiScaled(10), .top = card.bottom - uiScaled(26), .right = card.left + uiScaled(96), .bottom = card.bottom - uiScaled(7) };
}

fn updateCardCloseRect(card: RECT) RECT {
    return .{ .left = card.right - uiScaled(24), .top = card.top + uiScaled(3), .right = card.right - uiScaled(4), .bottom = card.top + uiScaled(23) };
}

fn ptInRect(r: RECT, x: i32, y: i32) bool {
    return x >= r.left and x < r.right and y >= r.top and y < r.bottom;
}

pub fn updateCardHit(x: i32, y: i32) u8 {
    if (!updateCardVisible()) return 0;
    const card = updateCardRect();
    if (!ptInRect(card, x, y)) return 0;
    if (ptInRect(updateCardCloseRect(card), x, y)) return 2;
    if (ptInRect(updateCardButtonRect(card), x, y)) return 1;
    return 3;
}

var release_ready = false;
var restart_after_download = false;
var restart_status: []const u8 = "";

pub fn updateCardPoll() void {
    if (update_release.poll()) |version| {
        if (!release_ready or !std.mem.eql(u8, version, app_state.g_update_ver[0..app_state.g_update_ver_len])) {
            card_notes = update_release.cardNotes(version);
            card_notes_logged = false;
            restart_status = "";
        }
        release_ready = true;
        @memcpy(app_state.g_update_ver[0..version.len], version);
        app_state.g_update_ver_len = version.len;
        if (restart_after_download and !update_release.checking()) {
            restart_after_download = false;
            updateCardRelaunch(app_state.g_main_hwnd);
        }
        if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
        return;
    }
    if (restart_after_download and !update_release.checking()) {
        restart_after_download = false;
        restart_status = "Download failed. Try Restart again.";
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
        @import("console.zig").showHeaderNoticeAscii("No verified update available. Please try again later.", 6000, false);
    }
    if (release_ready) {
        release_ready = false;
        if (restart_status.len == 0) app_state.g_update_ver_len = 0;
    }
    if (app_state.g_update_path_len == 0) return;
    const stamp = update_check.statFile(&app_state.g_update_path) orelse return;
    if (app_state.g_update_startup_stamp) |s0| {
        if (s0.eql(stamp)) return;
    }
    if (app_state.g_update_attempt_stamp) |a| {
        if (a.eql(stamp)) return;
    }
    var buf: [update_check.MAX_VERSION_LEN]u8 = undefined;
    const found = update_check.scanFileForVersion(&app_state.g_update_path, &buf) orelse {
        app_state.g_update_attempt_stamp = stamp;
        return;
    };
    app_state.g_update_attempt_stamp = stamp;
    if (!update_check.versionDiffers(APP_VERSION, found)) return;
    card_notes = update_release.cardNotes(found);
    card_notes_logged = false;
    @memcpy(app_state.g_update_ver[0..found.len], found);
    app_state.g_update_ver_len = found.len;
    debugLog2("update-card: new version ready ", found);
    if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

pub fn updateCardDismiss() void {
    @memcpy(app_state.g_update_dismissed[0..app_state.g_update_ver_len], app_state.g_update_ver[0..app_state.g_update_ver_len]);
    app_state.g_update_dismissed_len = app_state.g_update_ver_len;
    app_state.g_update_hover = 0;
    if (app_state.g_main_hwnd != null) {
        clampSidebarScroll();
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    }
}

pub fn updateCardRelaunch(hwnd: HANDLE) void {
    if (app_state.g_update_relaunching) return;
    var installed_version: [update_check.MAX_VERSION_LEN]u8 = undefined;
    const installed_ready = if (update_check.scanFileForVersion(&app_state.g_update_path, &installed_version)) |version| update_check.versionNewer(APP_VERSION, version) else false;
    if (!installed_ready and !update_release.hasStaged() and update_release.checking()) {
        restart_after_download = true;
        restart_status = "Downloading update. Restart will follow.";
        _ = InvalidateRect(hwnd, null, 0);
        @import("console.zig").showHeaderNoticeAscii("Update still downloading. Will restart when ready.", 6000, false);
        return;
    }
    if (app_state.g_update_ver_len == 0 or app_state.g_update_path_len == 0 or app_state.g_update_relaunching) return;
    if (!installed_ready and !update_release.hasStaged()) {
        restart_status = "Update unavailable. Try again later.";
        _ = InvalidateRect(hwnd, null, 0);
        return;
    }
    restart_after_download = false;
    restart_status = "";
    rememberOpenWorkspaceForQuit();
    var ctx = ZigShellWindowList{
        .current = hwnd,
        .hwnds = std.mem.zeroes([MAX_WORKSPACES]HANDLE),
        .count = 0,
    };
    _ = EnumWindows(&listZigShellWindowsEnum, @bitCast(@intFromPtr(&ctx)));
    var pids: [update_check.MAX_PIDS]u32 = undefined;
    var np: usize = 0;
    pids[np] = GetCurrentProcessId();
    np += 1;
    for (0..ctx.count) |i| {
        var pid: DWORD = 0;
        _ = GetWindowThreadProcessId(ctx.hwnds[i], &pid);
        if (pid == 0 or np >= pids.len) continue;
        var dup = false;
        for (pids[0..np]) |q| {
            if (q == pid) dup = true;
        }
        if (!dup) {
            pids[np] = pid;
            np += 1;
        }
    }
    const launched = if (installed_ready) update_check.spawnRelaunchHelper(app_state.g_update_path[0..app_state.g_update_path_len], pids[0..np]) else update_release.restart(pids[0..np]);
    if (!launched) {
        restart_status = "Could not restart. Try again.";
        _ = InvalidateRect(hwnd, null, 0);
        debugLog("update-card: could not start relaunch helper");
        @import("console.zig").showHeaderNoticeAscii("Could not start update. Please try again.", 6000, true);
        return;
    }
    app_state.g_update_relaunching = true;
    quitAllZigShellWindows(hwnd);
}

fn lightenColor(c: DWORD, amount: DWORD) DWORD {
    const r: DWORD = @min(255, (c & 0xFF) + amount);
    const g: DWORD = @min(255, ((c >> 8) & 0xFF) + amount);
    const b: DWORD = @min(255, ((c >> 16) & 0xFF) + amount);
    return r | (g << 8) | (b << 16);
}

pub fn paintSidebarUpdateCard(hdc: HANDLE, font_title: HANDLE, font_subtitle: HANDLE) void {
    if (!updateCardVisible()) return;
    const card = updateCardRect();
    paintSidebarCardFrame(hdc, card);
    const bright: DWORD = customColorOr("text_active", if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(235, 238, 244));
    const dim: DWORD = customColorOr("muted", if (app_state.g_light_theme) RGB(100, 100, 100) else RGB(135, 142, 152));
    const accent: DWORD = customColorOr("selected_bg", if (app_state.g_light_theme) RGB(54, 118, 232) else RGB(63, 120, 190));
    var text_buf: [96]u8 = undefined;
    const text = if (restart_status.len > 0) restart_status else std.fmt.bufPrint(&text_buf, "Update ready: restart to get v{s}", .{app_state.g_update_ver[0..app_state.g_update_ver_len]}) catch "Update is ready";
    _ = SelectObject(hdc, font_title);
    _ = SetTextColor(hdc, bright);
    var text_rc = RECT{ .left = card.left + uiScaled(10), .top = card.top + uiScaled(5), .right = card.right - uiScaled(26), .bottom = card.top + uiScaled(46) };
    drawAscii(hdc, text, &text_rc, DT_WORDBREAK | DT_NOPREFIX | DT_END_ELLIPSIS);

    _ = SelectObject(hdc, font_subtitle);
    var close_rc = updateCardCloseRect(card);
    _ = SetTextColor(hdc, if (app_state.g_update_hover == 2) bright else dim);
    drawAscii(hdc, "x", &close_rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);

    _ = SetTextColor(hdc, dim);
    for (0..card_notes.count) |i| {
        var note_rc = RECT{ .left = card.left + uiScaled(10), .top = card.top + uiScaled(46) + @as(i32, @intCast(i)) * uiScaled(18), .right = card.right - uiScaled(10), .bottom = card.top + uiScaled(46) + @as(i32, @intCast(i + 1)) * uiScaled(18) };
        var wide: [512]u16 = undefined;
        const n = std.unicode.utf8ToUtf16Le(&wide, card_notes.line(i)) catch continue;
        _ = @import("win32.zig").DrawTextW(hdc, &wide, @intCast(n), &note_rc, DT_SINGLELINE | DT_NOPREFIX | DT_END_ELLIPSIS);
    }
    if (card_notes.total > card_notes.count) {
        var more_buf: [32]u8 = undefined;
        var more_rc = RECT{ .left = card.left + uiScaled(10), .top = card.top + uiScaled(46) + @as(i32, @intCast(card_notes.count)) * uiScaled(18), .right = card.right - uiScaled(10), .bottom = card.bottom - uiScaled(26) };
        drawAscii(hdc, card_notes.more(&more_buf), &more_rc, DT_SINGLELINE | DT_NOPREFIX);
    }
    if (!card_notes_logged) {
        card_notes_logged = true;
        var log_buf: [640]u8 = undefined;
        const restart_button = updateCardButtonRect(card);
        debugLog(std.fmt.bufPrint(&log_buf, "[update] restart button={d},{d}", .{ @divTrunc(restart_button.left + restart_button.right, 2), @divTrunc(restart_button.top + restart_button.bottom, 2) }) catch "[update] restart button unavailable");
        debugLog(std.fmt.bufPrint(&log_buf, "[update] card notes n={d} first={s}", .{ card_notes.count, if (card_notes.count > 0) card_notes.line(0) else "" }) catch "[update] card notes unavailable");
        for (0..card_notes.count) |i| debugLog(std.fmt.bufPrint(&log_buf, "[update] card note {d}={s}", .{ i, card_notes.line(i) }) catch continue);
        var more_buf: [32]u8 = undefined;
        debugLog2("[update] card remaining=", card_notes.more(&more_buf));
    }

    const btn = updateCardButtonRect(card);
    const btn_color: DWORD = if (app_state.g_update_hover == 1) lightenColor(accent, 28) else accent;
    const brush = CreateSolidBrush(btn_color);
    const pen = CreatePen(0, 1, btn_color);
    const old_brush = SelectObject(hdc, brush);
    const old_pen = SelectObject(hdc, pen);
    _ = @import("smooth.zig").drawRoundRect(hdc, btn.left, btn.top, btn.right, btn.bottom, uiScaled(6), uiScaled(6));
    _ = SelectObject(hdc, old_brush);
    _ = SelectObject(hdc, old_pen);
    _ = DeleteObject(brush);
    _ = DeleteObject(pen);
    _ = SetTextColor(hdc, RGB(255, 255, 255));
    var btn_rc = btn;
    drawAscii(hdc, "Restart", &btn_rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
}

pub fn hostBusyAgentCount(host: u8) u16 {
    var count: u16 = 0;
    for (0..app_state.shell_count) |i| {
        const shell_host = remoteHostForShell(&app_state.shells[i]) orelse continue;
        if (shell_host == host and app_state.shells[i].ai_agent != 0 and app_state.shells[i].activity == .active) count +|= 1;
    }
    return count;
}

pub fn workspaceBusyAgentCount(workspace: u8) u16 {
    var count: u16 = 0;
    for (0..app_state.shell_count) |i| {
        if (app_state.g_single_window and app_state.shells[i].workspace != workspace) continue;
        if (remoteHostForShell(&app_state.shells[i]) != null and app_state.shells[i].ai_agent != 0 and app_state.shells[i].activity == .active) count +|= 1;
    }
    return count;
}
