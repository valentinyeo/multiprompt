const std = @import("std");
const app_state = @import("app_state.zig");
const w = @import("win32.zig");
const drawing = @import("drawing.zig");
const startup = @import("startup.zig");
const focus = @import("focus.zig");
const workspaces = @import("workspaces.zig");
const browser = @import("browser_pane.zig");
const fillRoundRect = @import("smooth.zig").fillRoundRect;
const scale = drawing.uiScaled;
const RGB = startup.RGB;
const L = startup.L;

var hwnd: w.HANDLE = null;
var registered = false;
var opened = false;
var entries: [app_state.MAX_WORKSPACES]app_state.WorkspaceEntry = undefined;
var entry_count: usize = 0;
var selected: usize = 0;
var first: usize = 0;
var visible: usize = 0;
var width: i32 = 0;
var height: i32 = 0;
var header_font: w.HANDLE = null;
var header_font_height: i32 = 0;

pub fn headerHeight() i32 {
    return if (app_state.g_hide_sidebar or app_state.g_sidebar_collapsed) 0 else scale(52);
}

fn headerRect() w.RECT {
    const top = browser.wsStripHeight() + scale(8);
    return .{ .left = scale(8), .top = top, .right = browser.SIDEBAR_W() - scale(8), .bottom = top + scale(36) };
}

fn inside(rc: w.RECT, x: i32, y: i32) bool {
    return x >= rc.left and x < rc.right and y >= rc.top and y < rc.bottom;
}

fn textColor() u32 {
    return if (app_state.g_light_theme) RGB(28, 28, 30) else RGB(242, 242, 242);
}

fn hintColor() u32 {
    return if (app_state.g_light_theme) RGB(100, 100, 106) else RGB(138, 138, 138);
}

fn outlineColor() u32 {
    return if (app_state.g_light_theme) RGB(216, 216, 220) else RGB(46, 46, 46);
}

fn inset(rc: w.RECT, amount: i32) w.RECT {
    return .{ .left = rc.left + amount, .top = rc.top + amount, .right = rc.right - amount, .bottom = rc.bottom - amount };
}

fn drawName(dc: w.HANDLE, name: []const u8, rect: *w.RECT, flags: u32) void {
    var utf16: [128]u16 = undefined;
    const len = std.unicode.utf8ToUtf16Le(&utf16, name) catch 0;
    _ = w.DrawTextW(dc, &utf16, @intCast(len), rect, flags);
}

pub fn paintHeader(dc: w.HANDLE) void {
    if (headerHeight() == 0) return;
    const rc = headerRect();
    var band = w.RECT{ .left = 0, .top = browser.wsStripHeight(), .right = browser.SIDEBAR_W(), .bottom = browser.wsStripHeight() + headerHeight() };
    const bg = w.CreateSolidBrush(@import("themes.zig").themeSidebarBg());
    _ = w.FillRect(dc, &band, bg);
    _ = w.DeleteObject(bg);
    fillRoundRect(dc, rc, scale(18), outlineColor());
    fillRoundRect(dc, inset(rc, scale(1)), scale(17), if (app_state.g_light_theme) RGB(245, 245, 247) else RGB(31, 31, 31));
    const font_height = -scale(14);
    if (header_font == null or header_font_height != font_height) {
        if (header_font != null) _ = w.DeleteObject(header_font);
        header_font = @import("fonts.zig").create(font_height, 0, 0, 0, 600, 0, 0, 0, 0, 0, 0, 5, 0, L(@import("fonts.zig").UI_SEMIBOLD_FACE));
        header_font_height = font_height;
    }
    const font = w.SelectObject(dc, header_font orelse drawing.uiFontTitle());
    defer _ = w.SelectObject(dc, font);
    _ = w.SetBkMode(dc, w.TRANSPARENT);
    _ = w.SetTextColor(dc, textColor());
    var name_buf: [32]u8 = undefined;
    const name = if (app_state.g_starred_workspace) "Starred" else if (app_state.g_single_window)
        workspaces.workspaceDisplayName(app_state.g_active_workspace, &name_buf)
    else if (app_state.g_window_display_name_u8_len > 0)
        app_state.g_window_display_name_u8[0..app_state.g_window_display_name_u8_len]
    else
        startup.getInstanceName();
    var label = rc;
    label.left += scale(14);
    label.right -= scale(32);
    drawName(dc, name, &label, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_NOPREFIX | w.DT_END_ELLIPSIS);
    _ = w.SetTextColor(dc, hintColor());
    var arrow = rc;
    arrow.left = arrow.right - scale(30);
    arrow.right -= scale(10);
    _ = w.DrawTextW(dc, L("\u{2304}"), -1, &arrow, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_CENTER);
}

fn rowCount() usize {
    return entry_count + 2;
}

fn rowRect(index: usize) w.RECT {
    const top = scale(36) + @as(i32, @intCast(index - first)) * scale(36);
    return .{ .left = scale(8), .top = top, .right = width - scale(8), .bottom = top + scale(36) };
}

fn hit(x: i32, y: i32) ?usize {
    if (x < scale(8) or x >= width - scale(8) or y < scale(36)) return null;
    const offset: usize = @intCast(@divTrunc(y - scale(36), scale(36)));
    if (offset >= visible or first + offset >= rowCount()) return null;
    return first + offset;
}

fn current(index: usize) bool {
    if (index == 0) return app_state.g_starred_workspace;
    if (index > entry_count or app_state.g_starred_workspace) return false;
    const entry = &entries[index - 1];
    const id = entry.id[0..entry.id_len];
    if (app_state.g_single_window) return workspaces.findMyWorkspaceSlot(id) == app_state.g_active_workspace;
    return std.mem.eql(u8, id, startup.getInstanceName());
}

fn sessionCount(index: usize) ?u32 {
    if (index == 0) {
        var count: u32 = 0;
        for (0..app_state.shell_count) |i| {
            if (workspaces.starredShellVisible(i)) count += 1;
        }
        return count;
    }
    const entry = &entries[index - 1];
    const id = entry.id[0..entry.id_len];
    const slot = workspaces.findMyWorkspaceSlot(id) orelse return null;
    var count: u32 = 0;
    for (app_state.shells[0..app_state.shell_count]) |shell| {
        if (shell.workspace == slot) count += 1;
    }
    return count;
}

fn paint(dc: w.HANDLE) void {
    var bounds = w.RECT{ .left = 0, .top = 0, .right = width, .bottom = height };
    const bg = w.CreateSolidBrush(@import("themes.zig").themeSidebarBg());
    _ = w.FillRect(dc, &bounds, bg);
    _ = w.DeleteObject(bg);
    fillRoundRect(dc, bounds, scale(16), outlineColor());
    fillRoundRect(dc, inset(bounds, scale(1)), scale(15), if (app_state.g_light_theme) RGB(250, 250, 251) else RGB(24, 24, 24));
    const font = w.SelectObject(dc, drawing.uiFontSubtitle());
    defer _ = w.SelectObject(dc, font);
    _ = w.SetBkMode(dc, w.TRANSPARENT);
    _ = w.SetTextColor(dc, hintColor());
    var title = w.RECT{ .left = scale(16), .top = scale(4), .right = width - scale(16), .bottom = scale(36) };
    const flags = w.DT_SINGLELINE | w.DT_VCENTER | w.DT_NOPREFIX | w.DT_END_ELLIPSIS;
    drawing.drawAscii(dc, "WORKSPACES", &title, flags);
    for (first..@min(first + visible, rowCount())) |index| {
        const rc = rowRect(index);
        if (current(index) or selected == index) fillRoundRect(dc, rc, scale(10), if (app_state.g_light_theme) RGB(230, 230, 234) else RGB(53, 53, 53));
        var label = rc;
        label.left += scale(10);
        label.right -= scale(if (index <= entry_count) @as(i32, 58) else 10);
        _ = w.SetTextColor(dc, textColor());
        const name = if (index == 0) "Starred" else if (index == entry_count + 1) "+ New workspace" else entries[index - 1].name[0..entries[index - 1].name_len];
        drawName(dc, name, &label, flags);
        if (index <= entry_count) {
            var count_rc = rc;
            count_rc.left = count_rc.right - scale(54);
            count_rc.right -= scale(24);
            _ = w.SetTextColor(dc, hintColor());
            if (sessionCount(index)) |count| {
                var buf: [12]u8 = undefined;
                drawing.drawAscii(dc, std.fmt.bufPrint(&buf, "{d}", .{count}) catch "", &count_rc, flags | w.DT_RIGHT);
            }
            if (current(index)) {
                var check = rc;
                check.left = check.right - scale(24);
                _ = w.SetTextColor(dc, textColor());
                _ = w.DrawTextW(dc, L("\u{2713}"), -1, &check, flags | w.DT_CENTER);
            }
        }
    }
}

pub fn close() void {
    if (!opened) return;
    opened = false;
    _ = w.ReleaseCapture();
    _ = focus.ShowWindow(hwnd, w.SW_HIDE);
    _ = w.InvalidateRect(app_state.g_main_hwnd, null, 0);
}

fn activate(index: usize) void {
    close();
    app_state.g_shell_focused = true;
    if (index == 0) {
        workspaces.switchToWorkspace(@import("workspace_view.zig").starred);
    } else if (index == entry_count + 1) {
        if (app_state.g_single_window) workspaces.newWorkspace() else workspaces.spawnEmptyWorkspace();
    } else if (index <= entry_count) {
        const entry = &entries[index - 1];
        if (workspaces.findWorkspace(entry.id[0..entry.id_len])) |wi| workspaces.openWorkspaceByIndex(wi);
    }
    _ = w.InvalidateRect(app_state.g_main_hwnd, null, 0);
    _ = w.SetTimer(app_state.g_main_hwnd, w.TIMER_REFOCUS, 50, null);
}

pub fn headerClick(x: i32, y: i32) bool {
    if (headerHeight() == 0 or x < 0 or x >= browser.SIDEBAR_W() or y < browser.wsStripHeight() or y >= browser.wsStripHeight() + headerHeight()) return false;
    if (!inside(headerRect(), x, y)) return true;
    if (opened) {
        close();
        return true;
    }
    focus.cancelShellRefocus(app_state.g_main_hwnd);
    app_state.g_shell_focused = false;
    workspaces.syncInProcessWorkspacesToRegistry();
    workspaces.mergeWorkspaceRegistryFromDisk();
    entry_count = app_state.g_workspace_count;
    @memcpy(entries[0..entry_count], app_state.g_workspaces[0..entry_count]);
    selected = 0;
    for (0..entry_count) |i| {
        if (current(i + 1)) selected = i + 1;
    }
    var client: w.RECT = undefined;
    _ = w.GetClientRect(app_state.g_main_hwnd, &client);
    const anchor = headerRect();
    const top = anchor.bottom + scale(8);
    width = anchor.right - anchor.left;
    visible = @min(rowCount(), @as(usize, @intCast(@max(1, @divTrunc(client.bottom - top - scale(44), scale(36))))));
    height = scale(44) + @as(i32, @intCast(visible)) * scale(36);
    first = @min(selected, rowCount() - visible);
    if (!registered) {
        const wc = w.WNDCLASSEXW{ .cbSize = @sizeOf(w.WNDCLASSEXW), .style = 0, .lpfnWndProc = wndProc, .cbClsExtra = 0, .cbWndExtra = 0, .hInstance = w.GetModuleHandleW(null), .hIcon = null, .hCursor = w.LoadCursorW(null, @ptrFromInt(32512)), .hbrBackground = null, .lpszMenuName = null, .lpszClassName = L("MultiPromptWorkspaceSwitcher"), .hIconSm = null };
        _ = w.RegisterClassExW(&wc);
        registered = true;
    }
    if (hwnd == null) hwnd = w.CreateWindowExW(0x00000004, L("MultiPromptWorkspaceSwitcher"), L("Workspaces"), w.WS_CHILD | w.WS_CLIPSIBLINGS, anchor.left, top, width, height, app_state.g_main_hwnd, null, null, null);
    if (hwnd == null) return true;
    opened = true;
    _ = w.MoveWindow(hwnd, anchor.left, top, width, height, 0);
    _ = focus.SetWindowPos(hwnd, w.HWND_TOP, 0, 0, 0, 0, w.SWP_NOMOVE | w.SWP_NOSIZE | w.SWP_NOACTIVATE | w.SWP_SHOWWINDOW);
    _ = w.SetCapture(hwnd);
    _ = w.InvalidateRect(hwnd, null, 0);
    return true;
}

fn step(direction: i32) void {
    selected = @intCast(@mod(@as(i32, @intCast(selected)) + direction, @as(i32, @intCast(rowCount()))));
    if (selected < first) first = selected;
    if (selected >= first + visible) first = selected - visible + 1;
    if (hwnd != null) _ = w.InvalidateRect(hwnd, null, 0);
}

pub fn key(vk: usize) bool {
    if (!opened) return false;
    switch (vk) {
        0x1B => {
            close();
            focus.focusActiveShell();
        },
        0x26 => step(-1),
        0x28 => step(1),
        0x0D, 0x20 => activate(selected),
        0x10, 0x11, 0x12 => return false,
        else => {
            close();
            return false;
        },
    }
    return true;
}

fn wndProc(window: w.HANDLE, msg: w.UINT, wp: w.WPARAM, lp: w.LPARAM) callconv(w.WINAPI) w.LRESULT {
    const previous = app_state.g_focus_user_action_tick;
    app_state.g_focus_user_action_tick = focus.focusGuardDispatchTick(msg, wp, lp);
    defer app_state.g_focus_user_action_tick = previous;
    switch (msg) {
        w.WM_ERASEBKGND => return 1,
        w.WM_PAINT => {
            var ps: w.PAINTSTRUCT = undefined;
            const dc = w.BeginPaint(window, &ps);
            paint(dc);
            _ = w.EndPaint(window, &ps);
            return 0;
        },
        w.WM_LBUTTONDOWN => {
            if (hit(startup.GET_X(lp), startup.GET_Y(lp))) |index| activate(index) else close();
            return 0;
        },
        w.WM_MOUSEMOVE => {
            if (hit(startup.GET_X(lp), startup.GET_Y(lp))) |index| {
                if (index != selected) {
                    selected = index;
                    _ = w.InvalidateRect(window, null, 0);
                }
            }
            return 0;
        },
        w.WM_MOUSEWHEEL => {
            const delta: i16 = @bitCast(@as(u16, @truncate(wp >> 16)));
            step(if (delta > 0) -1 else 1);
            return 0;
        },
        w.WM_KEYDOWN => {
            _ = key(wp);
            return 0;
        },
        w.WM_KILLFOCUS, 0x0215, w.WM_RBUTTONDOWN => {
            close();
            return 0;
        },
        else => return w.DefWindowProcW(window, msg, wp, lp),
    }
}

test "IGSH-1082 workspace name reserves space independently of numbered pills" {
    const old_hide = app_state.g_hide_sidebar;
    const old_collapsed = app_state.g_sidebar_collapsed;
    const old_pills = app_state.g_hide_pills;
    const old_single = app_state.g_single_window;
    defer {
        app_state.g_hide_sidebar = old_hide;
        app_state.g_sidebar_collapsed = old_collapsed;
        app_state.g_hide_pills = old_pills;
        app_state.g_single_window = old_single;
    }
    app_state.g_hide_sidebar = false;
    app_state.g_sidebar_collapsed = false;
    app_state.g_single_window = true;
    for ([_]bool{ true, false }) |hide| {
        app_state.g_hide_pills = hide;
        try std.testing.expectEqual(scale(52), headerHeight());
        const rc = headerRect();
        try std.testing.expectEqual(scale(36), rc.bottom - rc.top);
        try std.testing.expect(rc.top >= browser.wsStripHeight());
        try std.testing.expect(inside(rc, rc.left, rc.top));
        try std.testing.expect(!inside(rc, rc.right, rc.top));
    }
    app_state.g_single_window = false;
    try std.testing.expectEqual(scale(52), headerHeight());
    app_state.g_sidebar_collapsed = true;
    try std.testing.expectEqual(@as(i32, 0), headerHeight());
    app_state.g_sidebar_collapsed = false;
    app_state.g_hide_sidebar = true;
    try std.testing.expectEqual(@as(i32, 0), headerHeight());
}

test "IGSH-1082 workspace menu scroll keeps every row and new workspace reachable" {
    const old_count = entry_count;
    const old_selected = selected;
    const old_first = first;
    const old_visible = visible;
    const old_width = width;
    defer {
        entry_count = old_count;
        selected = old_selected;
        first = old_first;
        visible = old_visible;
        width = old_width;
    }
    entry_count = app_state.MAX_WORKSPACES;
    selected = 0;
    first = 0;
    visible = 3;
    width = scale(203);
    for (0..rowCount() - 1) |_| step(1);
    try std.testing.expectEqual(entry_count + 1, selected);
    try std.testing.expectEqual(selected - visible + 1, first);
    const rc = rowRect(selected);
    try std.testing.expectEqual(selected, hit(rc.left, rc.top).?);
    try std.testing.expect(hit(0, rc.top) == null);
    step(1);
    try std.testing.expectEqual(@as(usize, 0), selected);
    try std.testing.expectEqual(@as(usize, 0), first);
}
