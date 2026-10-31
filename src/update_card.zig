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
    return app_state.g_update_dismissed_len == 0;
}

var card_notes: @import("update_notes.zig").Notes = .{};
var card_notes_logged = false;
var card_expanded = false;
var card_scroll: i32 = 0;
var measured_width: i32 = 0;
var measured_font: HANDLE = null;
var measured_scale: i32 = 0;
var measured_font_gen: u32 = 0;
var measured_shown: usize = 0;
var note_heights: [16]i32 = @splat(0);
var notes_height: i32 = 0;
var last_notes_rect: RECT = std.mem.zeroes(RECT);

fn measureNotes() void {
    const sticky = sidebarStickyCardRect();
    const width = @max(1, sticky.right - sticky.left - uiScaled(20));
    const font = @import("drawing.zig").uiFontStatusCard();
    const shown = card_notes.shown(card_expanded);
    if (measured_width == width and measured_font == font and measured_scale == uiScaled(18) and measured_shown == shown and measured_font_gen == app_state.g_font_gen) return;
    const dc = @import("win32.zig").GetDC(app_state.g_main_hwnd);
    if (dc == null) return;
    defer _ = @import("win32.zig").ReleaseDC(app_state.g_main_hwnd, dc);
    const old_font = SelectObject(dc, font);
    defer _ = SelectObject(dc, old_font);
    notes_height = 0;
    for (0..shown) |i| {
        var wide: [512]u16 = undefined;
        const n = std.unicode.utf8ToUtf16Le(&wide, card_notes.line(i)) catch continue;
        var rect = RECT{ .left = 0, .top = 0, .right = width, .bottom = 0 };
        _ = @import("win32.zig").DrawTextW(dc, &wide, @intCast(n), &rect, DT_WORDBREAK | DT_NOPREFIX | @import("win32.zig").DT_CALCRECT);
        note_heights[i] = @max(uiScaled(14), rect.bottom) + uiScaled(4);
        notes_height += note_heights[i];
    }
    measured_width = width;
    measured_font = font;
    measured_scale = uiScaled(18);
    measured_shown = shown;
    measured_font_gen = app_state.g_font_gen;
    card_notes_logged = false;
}

fn cardHasToggle() bool {
    return card_notes.total > @import("update_notes.zig").COLLAPSED_LINES;
}

fn updateCardHeight() i32 {
    measureNotes();
    const desired = uiScaled(UPDATE_CARD_H) + notes_height + (if (cardHasToggle()) uiScaled(18) else @as(i32, 0));
    const available = sidebarStickyCardRect().top - @import("window_layout.zig").paneGap() - uiScaled(48);
    return @min(desired, @max(uiScaled(UPDATE_CARD_H + 36), available));
}

pub fn updateCardToggleNotes() void {
    if (!cardHasToggle()) return;
    card_expanded = !card_expanded;
    card_scroll = 0;
    card_notes_logged = false;
    if (app_state.g_main_hwnd != null) clampSidebarScroll();
}

pub fn updateCardSpan() i32 {
    if (!updateCardVisible()) return 0;
    return updateCardHeight() + @import("window_layout.zig").paneGap();
}

pub fn updateCardRect() RECT {
    var client: RECT = std.mem.zeroes(RECT);
    if (app_state.g_main_hwnd != null) _ = @import("win32.zig").GetClientRect(app_state.g_main_hwnd, &client);
    return .{ .left = uiScaled(8), .top = client.bottom - uiScaled(96), .right = @import("browser_pane.zig").SIDEBAR_W() - uiScaled(8), .bottom = client.bottom - uiScaled(8) };
}

fn updateCardButtonRect(card: RECT) RECT {
    return .{ .left = card.left + uiScaled(16), .top = card.bottom - uiScaled(32), .right = card.left + uiScaled(96), .bottom = card.bottom - uiScaled(8) };
}

fn updateCardCloseRect(card: RECT) RECT {
    return .{ .left = card.left + uiScaled(104), .top = card.bottom - uiScaled(32), .right = @min(card.left + uiScaled(150), card.right - uiScaled(4)), .bottom = card.bottom - uiScaled(8) };
}

fn updateCardMoreRect(card: RECT) RECT {
    const bottom = card.bottom - uiScaled(30);
    return .{ .left = card.left + uiScaled(10), .top = bottom - uiScaled(18), .right = card.right - uiScaled(10), .bottom = bottom };
}

fn updateCardNotesRect(card: RECT) RECT {
    return .{ .left = card.left + uiScaled(10), .top = card.top + uiScaled(46), .right = card.right - uiScaled(10), .bottom = if (cardHasToggle()) updateCardMoreRect(card).top else card.bottom - uiScaled(30) };
}

pub fn updateCardScroll(x: i32, y: i32, delta: i16) bool {
    if (!updateCardVisible()) return false;
    const card = updateCardRect();
    if (!ptInRect(card, x, y)) return false;
    const notes = updateCardNotesRect(card);
    const limit = @max(0, notes_height - (notes.bottom - notes.top));
    card_scroll = std.math.clamp(card_scroll - @divTrunc(@as(i32, delta) * uiScaled(54), 120), 0, limit);
    card_notes_logged = false;
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    return true;
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
            if (card_notes.count == 0) debugLog2("[update] quiet release waiting ", version);
            card_notes_logged = false;
            card_expanded = false;
            card_scroll = 0;
            measured_width = 0;
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
    card_expanded = false;
    card_scroll = 0;
    measured_width = 0;
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
    const installed_ready = if (update_check.scanFileForVersion(&app_state.g_update_path, &installed_version)) |version| update_check.versionNewer(APP_VERSION, version) and !update_check.versionNewer(app_state.g_update_ver[0..app_state.g_update_ver_len], version) else false;
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
    const smooth = @import("smooth.zig");
    smooth.fillRoundRect(hdc, .{ .left = card.left, .top = card.top + uiScaled(3), .right = card.right, .bottom = card.bottom + uiScaled(3) }, uiScaled(14), RGB(12, 12, 12));
    smooth.fillRoundRect(hdc, card, uiScaled(14), RGB(46, 46, 46));
    smooth.fillRoundRect(hdc, .{ .left = card.left + 1, .top = card.top + 1, .right = card.right - 1, .bottom = card.bottom - 1 }, uiScaled(13), RGB(30, 30, 30));
    _ = font_title;
    _ = font_subtitle;
    const footerFont = @import("usage_card.zig").footerFont;
    const old_font = SelectObject(hdc, footerFont(2, 14, 600));
    defer _ = SelectObject(hdc, old_font);
    _ = SetTextColor(hdc, RGB(242, 242, 242));
    var title = RECT{ .left = card.left + uiScaled(16), .top = card.top + uiScaled(10), .right = card.right - uiScaled(16), .bottom = card.top + uiScaled(30) };
    drawAscii(hdc, if (restart_status.len > 0) restart_status else "Update ready", &title, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
    _ = SelectObject(hdc, footerFont(3, 12, 400));
    _ = SetTextColor(hdc, RGB(138, 138, 138));
    var buf: [128]u8 = undefined;
    const subtitle = std.fmt.bufPrint(&buf, "v{s} \xc2\xb7 takes a few seconds", .{app_state.g_update_ver[0..app_state.g_update_ver_len]}) catch "Takes a few seconds";
    var wide: [128]u16 = undefined;
    const length = std.unicode.utf8ToUtf16Le(&wide, subtitle) catch 0;
    var sub = RECT{ .left = card.left + uiScaled(16), .top = card.top + uiScaled(32), .right = card.right - uiScaled(16), .bottom = card.top + uiScaled(49) };
    _ = @import("win32.zig").DrawTextW(hdc, &wide, @intCast(length), &sub, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
    const button = updateCardButtonRect(card);
    smooth.fillRoundRect(hdc, button, uiScaled(12), RGB(242, 242, 242));
    _ = SelectObject(hdc, footerFont(4, 12, 600));
    _ = SetTextColor(hdc, RGB(0, 0, 0));
    var br = button;
    drawAscii(hdc, "Restart", &br, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
    _ = SelectObject(hdc, footerFont(3, 12, 400));
    _ = SetTextColor(hdc, RGB(138, 138, 138));
    var later = updateCardCloseRect(card);
    drawAscii(hdc, "Later", &later, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
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
