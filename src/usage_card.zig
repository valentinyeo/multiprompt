const std = @import("std");
const w = @import("win32.zig");
const state = @import("app_state.zig");
const drawing = @import("drawing.zig");
const focus = @import("focus.zig");
const telemetry = @import("telemetry_panel.zig");
const smooth = @import("smooth.zig");
const fonts = @import("fonts.zig");
const L = @import("startup.zig").L;
const RGB = @import("startup.zig").RGB;
const px = drawing.uiScaled;
const RECT = w.RECT;
const debugLog = @import("diagnostics.zig").debugLog;

var window: w.HANDLE = null;
var registered = false;
var backdrop: ?@import("more_menu.zig").Backdrop = null;
var previous_focus: w.HANDLE = null;
var bounds: RECT = std.mem.zeroes(RECT);
var anchor: RECT = std.mem.zeroes(RECT);
var snapshot: state.AiPaceSnapshot = .{};
var hover_open = false;
var hover_suppressed_until_row_exit = false;
var footer_fonts: [5]w.HANDLE = @splat(null);

pub fn resetFooterFonts() void {
    for (&footer_fonts) |*font| {
        if (font.* != null) _ = w.DeleteObject(font.*);
        font.* = null;
    }
}

pub fn footerFont(index: usize, size: i32, weight: i32) w.HANDLE {
    if (footer_fonts[index] == null) footer_fonts[index] = fonts.create(-px(size), 0, 0, 0, weight, 0, 0, 0, 0, 0, 0, 5, 0, if (weight == 500) L(fonts.UI_MEDIUM_FACE) else null);
    return footer_fonts[index];
}

pub fn updateReady() bool {
    return state.g_update_ver_len > 0 and !state.g_update_relaunching;
}

fn usageSlots(data: *const state.AiPaceSnapshot) [3]?state.AiPaceGoal {
    var slots: [3]?state.AiPaceGoal = .{ null, null, null };
    for (data.goals[0..@min(data.goal_count, data.goals.len)]) |goal| {
        if (goal.provider == .codex and slots[1] == null) slots[1] = goal else if (goal.provider == .claude) {
            if (slots[0] == null) slots[0] = goal else if (slots[2] == null) slots[2] = goal;
        }
    }
    return slots;
}

fn statusColor(used: u16) w.DWORD {
    var red = used >= 1000;
    var amber = used >= 850;
    for (0..state.g_host_capacity.len) |i| {
        switch (@import("capacity.zig").effectiveCapacityState(@intCast(i))) {
            .red, .critical => red = true,
            .amber => amber = true,
            else => {},
        }
    }
    return if (red) RGB(229, 72, 77) else if (amber) RGB(245, 165, 36) else RGB(242, 242, 242);
}

pub fn paintSidebarFooter(dc: w.HANDLE) void {
    if (state.g_hide_sidebar or state.g_sidebar_collapsed) return;
    const rect = @import("capacity.zig").sidebarUsageRowRect();
    smooth.fillEllipse(dc, rect, RGB(26, 26, 26));
    var used: u16 = 0;
    var known = false;
    for (usageSlots(&state.g_ai_pace)) |slot| {
        if (slot) |goal| {
            if (goal.available and goal.status != .stale and goal.has_total_used) {
                known = true;
                used = @max(used, @min(goal.total_used_tenths, 1000));
            }
        }
    }
    var points: [33]w.POINT = undefined;
    const cx: f64 = @floatFromInt(rect.left + px(18));
    const cy: f64 = @floatFromInt(rect.top + px(22));
    const radius: f64 = @floatFromInt(px(10));
    for (&points, 0..) |*point, i| {
        const angle = std.math.pi + std.math.pi * @as(f64, @floatFromInt(i)) / 32.0;
        point.* = .{ .x = @intFromFloat(cx + radius * @cos(angle)), .y = @intFromFloat(cy + radius * @sin(angle)) };
    }
    var canvas = smooth.Canvas.init(dc);
    defer canvas.deinit();
    canvas.strokePolyline(&points, RGB(64, 64, 64), @floatFromInt(px(4)));
    const segments: usize = if (known) @intCast(@divTrunc(@as(u32, used) * 32, 1000)) else 0;
    if (segments > 0) canvas.strokePolyline(points[0 .. segments + 1], statusColor(used), @floatFromInt(px(4)));
    smooth.fillEllipse(dc, .{ .left = rect.left + px(16), .top = rect.top + px(20), .right = rect.left + px(20), .bottom = rect.top + px(24) }, if (known or statusColor(used) != RGB(242, 242, 242)) statusColor(used) else RGB(100, 100, 100));
}

pub fn geometry(client: RECT, pill: RECT, count: usize) RECT {
    _ = count;
    const width = @min(px(240), client.right - client.left - px(16));
    const left = @max(client.left + px(8), @min(pill.left, client.right - width - px(8)));
    const bottom = pill.top - px(8);
    return .{ .left = left, .top = @max(client.top + px(8), bottom - px(206)), .right = left + width, .bottom = bottom };
}

fn inside(rect: RECT, x: i32, y: i32) bool {
    return x >= rect.left and x < rect.right and y >= rect.top and y < rect.bottom;
}

fn text(dc: w.HANDLE, value: []const u8, rect: RECT, color: w.DWORD, flags: w.UINT) void {
    _ = w.SetTextColor(dc, color);
    var r = rect;
    var wide: [256]u16 = undefined;
    const length = std.unicode.utf8ToUtf16Le(&wide, value) catch return;
    _ = w.DrawTextW(dc, &wide, @intCast(length), &r, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_NOPREFIX | w.DT_END_ELLIPSIS | flags);
}

pub fn weeklyElapsed(goal: state.AiPaceGoal, now: u64) ?u16 {
    if (goal.week_elapsed_tenths) |elapsed| return elapsed;
    if (!goal.has_weekly_reset) return null;
    const week: u64 = 7 * 24 * 60 * 60 * 10_000_000;
    const remaining = @min(week, goal.weekly_reset_filetime -| now);
    const elapsed = week - remaining;
    return @intCast(elapsed * 1000 / week);
}

fn countdown(buffer: []u8, reset: u64, now: u64) []const u8 {
    if (reset <= now) return "now";
    const minutes = (reset - now + 60 * 10_000_000 - 1) / (60 * 10_000_000);
    const hours = minutes / 60;
    if (hours >= 24) return std.fmt.bufPrint(buffer, "{d}d {d}h", .{ hours / 24, hours % 24 }) catch "?";
    if (hours > 0) return std.fmt.bufPrint(buffer, "{d}h {d}m", .{ hours, minutes % 60 }) catch "?";
    return std.fmt.bufPrint(buffer, "{d}m", .{minutes}) catch "?";
}

pub fn weeklyDetail(buffer: []u8, goal: state.AiPaceGoal, now: u64) []const u8 {
    const pace = if (!goal.available or goal.status == .stale) "Usage not current" else switch (if (goal.weekly_pace.comparison) |value| value.verdict else goal.pace) {
        .ahead => "Ahead of pace",
        .on_pace => "On pace",
        .behind => "Below pace",
    };
    if (!goal.has_weekly_reset) return std.fmt.bufPrint(buffer, "{s} \xc2\xb7 reset not reported", .{pace}) catch pace;
    const local = telemetry.aiPaceLocalTime(goal.weekly_reset_filetime) orelse return pace;
    const days = [_][]const u8{ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" };
    var remaining: [32]u8 = undefined;
    return std.fmt.bufPrint(buffer, "{s} \xc2\xb7 resets {s} {d:0>2}:{d:0>2}, in {s}", .{ pace, days[@min(local.day_of_week, 6)], local.hour, local.minute, countdown(&remaining, goal.weekly_reset_filetime, now) }) catch pace;
}

pub fn fiveHourDetail(buffer: []u8, goal: state.AiPaceGoal, now: u64) []const u8 {
    if (!goal.has_five_hour_used) return "5-hour window not reported";
    var percent: [24]u8 = undefined;
    var remaining: [32]u8 = undefined;
    return std.fmt.bufPrint(buffer, "5-hour window {s} \xc2\xb7 {s}{s}", .{ telemetry.formatAiPacePercent(&percent, goal.five_hour_used_tenths), if (goal.has_five_hour_reset) "resets in " else "reset not reported", if (goal.has_five_hour_reset) countdown(&remaining, goal.five_hour_reset_filetime, now) else "" }) catch "5-hour window not reported";
}

pub fn paint(dc: w.HANDLE, client: RECT, pill: RECT, data: *const state.AiPaceSnapshot) void {
    const card = geometry(client, pill, data.goal_count);
    smooth.fillRoundRect(dc, .{ .left = card.left, .top = card.top + px(3), .right = card.right, .bottom = card.bottom + px(3) }, px(12), RGB(10, 10, 10));
    smooth.fillRoundRect(dc, card, px(12), RGB(46, 46, 46));
    smooth.fillRoundRect(dc, .{ .left = card.left + 1, .top = card.top + 1, .right = card.right - 1, .bottom = card.bottom - 1 }, px(11), RGB(30, 30, 30));
    const regular = footerFont(0, 12, 400);
    const medium = footerFont(1, 12, 500);
    const old = w.SelectObject(dc, regular);
    defer _ = w.SelectObject(dc, old);
    const old_mode = w.SetBkMode(dc, w.TRANSPARENT);
    defer _ = w.SetBkMode(dc, old_mode);
    const left = card.left + px(16);
    const right = card.right - px(16);
    const slots = usageSlots(data);
    const labels = [_][]const u8{ "Claude", "Codex", "Claude 2" };
    for (slots, labels, 0..) |slot, label, i| {
        const y = card.top + px(14) + @as(i32, @intCast(i)) * px(34);
        _ = w.SelectObject(dc, regular);
        text(dc, label, .{ .left = left, .top = y, .right = right, .bottom = y + px(16) }, RGB(138, 138, 138), 0);
        const known = if (slot) |goal| goal.available and goal.status != .stale and goal.has_total_used else false;
        const used: u16 = if (slot) |goal| @min(goal.total_used_tenths, 1000) else 0;
        var value: [24]u8 = undefined;
        _ = w.SelectObject(dc, medium);
        text(dc, if (known) telemetry.formatAiPacePercent(&value, used) else "n/a", .{ .left = left, .top = y, .right = right, .bottom = y + px(16) }, RGB(242, 242, 242), w.DT_RIGHT);
        const bar = RECT{ .left = left, .top = y + px(21), .right = right, .bottom = y + px(24) };
        smooth.fillRoundRect(dc, bar, px(2), RGB(64, 64, 64));
        if (known and used > 0) smooth.fillRoundRect(dc, .{ .left = left, .top = bar.top, .right = left + @divTrunc((right - left) * @as(i32, used), 1000), .bottom = bar.bottom }, px(2), statusColor(used));
    }
    _ = w.SelectObject(dc, regular);
    const sy = card.top + px(119);
    text(dc, "Servers", .{ .left = left, .top = sy, .right = right, .bottom = sy + px(16) }, RGB(138, 138, 138), 0);
    const hosts = [_]u8{ 1, 0 };
    const names = [_][]const u8{ "UK", "DE" };
    for (hosts, names, 0..) |host, name, i| {
        const hs = @import("capacity.zig").effectiveCapacityState(host);
        const metrics = state.g_host_capacity[host];
        var buf: [32]u8 = undefined;
        const value = if (hs == .unknown) std.fmt.bufPrint(&buf, "{s} ?", .{name}) catch "?" else std.fmt.bufPrint(&buf, "{s} {d}/{d}", .{ name, metrics.load_milli / 1000, metrics.cores }) catch "?";
        const color = switch (hs) { .red, .critical => RGB(229, 72, 77), .amber => RGB(245, 165, 36), .green => RGB(242, 242, 242), .unknown => RGB(138, 138, 138) };
        const x = right - px(104) + @as(i32, @intCast(i)) * px(54);
        text(dc, value, .{ .left = x, .top = sy, .right = x + px(53), .bottom = sy + px(16) }, color, 0);
    }
    const line = RECT{ .left = left, .top = card.top + px(148), .right = right, .bottom = card.top + px(149) };
    const brush = w.CreateSolidBrush(RGB(46, 46, 46));
    _ = w.FillRect(dc, &line, brush);
    _ = w.DeleteObject(brush);
    text(dc, "Multiprompt v" ++ @import("main.zig").APP_VERSION, .{ .left = left, .top = card.top + px(158), .right = right, .bottom = card.top + px(174) }, RGB(138, 138, 138), 0);
    const update_status = if (state.g_update_relaunching) "Restarting" else if (updateReady()) "Update ready" else if (@import("update_release.zig").checking()) "Checking for updates" else "Up to date";
    text(dc, update_status, .{ .left = left, .top = card.top + px(176), .right = right, .bottom = card.top + px(192) }, RGB(110, 110, 110), 0);
}

pub fn refresh() void {
    if (backdrop == null) return;
    if (hover_open and @import("update_card.zig").updateCardVisible()) {
        close();
        return;
    }
    snapshot = state.g_ai_pace;
    _ = w.InvalidateRect(window, null, 0);
}

pub fn close() void {
    if (backdrop == null) return;
    var log: [160]u8 = undefined;
    debugLog(std.fmt.bufPrint(&log, "[usage-hover] close hover={} visible={} caller=0x{x}", .{ hover_open, w.IsWindowVisible(window), @returnAddress() }) catch "[usage-hover] close");
    var saved = backdrop.?;
    const was_hover = hover_open;
    backdrop = null;
    hover_open = false;
    state.g_popup_menu_active = false;
    if (w.GetCapture() == window) _ = w.ReleaseCapture();
    _ = focus.ShowWindow(window, w.SW_HIDE);
    saved.release();
    if (!was_hover and previous_focus != null and w.IsWindow(previous_focus) != 0) _ = focus.SetFocus(previous_focus);
    _ = w.InvalidateRect(state.g_main_hwnd, null, 0);
}

pub fn updateHoverSuppression() void {
    if (!hover_suppressed_until_row_exit) return;
    const main = state.g_main_hwnd orelse return;
    var point: w.POINT = undefined;
    if (w.GetCursorPos(&point) != 0 and w.ScreenToClient(main, &point) != 0 and
        !inside(@import("capacity.zig").sidebarUsageRowRect(), point.x, point.y)) hover_suppressed_until_row_exit = false;
}

fn dismiss() void {
    hover_suppressed_until_row_exit = true;
    close();
    updateHoverSuppression();
    if (hover_suppressed_until_row_exit) {
        var tracking = w.TRACKMOUSEEVENT{ .cbSize = @sizeOf(w.TRACKMOUSEEVENT), .dwFlags = 2, .hwndTrack = state.g_main_hwnd, .dwHoverTime = 0 };
        _ = w.TrackMouseEvent(&tracking);
    }
}

pub fn openHover() void {
    if (backdrop != null or hover_suppressed_until_row_exit) return;
    openMode(true);
}

pub fn open() void {
    if (backdrop != null) {
        if (!hover_open) {
            dismiss();
            return;
        }
        close();
    }
    openMode(false);
}

fn openMode(passive: bool) void {
    const main = state.g_main_hwnd orelse return;
    if (state.g_sidebar_collapsed or state.g_hide_sidebar) return;
    _ = w.GetClientRect(main, &bounds);
    anchor = @import("capacity.zig").sidebarStickyCardRect();
    if (bounds.right <= 0 or bounds.bottom <= 0) return;
    if (!registered) {
        const cls = w.WNDCLASSEXW{ .cbSize = @sizeOf(w.WNDCLASSEXW), .style = 0, .lpfnWndProc = wndProc, .cbClsExtra = 0, .cbWndExtra = 0, .hInstance = w.GetModuleHandleW(null), .hIcon = null, .hCursor = w.LoadCursorW(null, @ptrFromInt(32512)), .hbrBackground = null, .lpszMenuName = null, .lpszClassName = L("MultiPromptUsageCard"), .hIconSm = null };
        if (w.RegisterClassExW(&cls) == 0) return;
        registered = true;
    }
    var origin = w.POINT{ .x = 0, .y = 0 };
    _ = w.ClientToScreen(main, &origin);
    const screen = w.GetDC(null);
    defer _ = w.ReleaseDC(null, screen);
    const dc = w.CreateCompatibleDC(screen) orelse return;
    const info = w.BITMAPINFO{ .header = .{ .width = bounds.right, .height = -bounds.bottom } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0) orelse {
        _ = w.DeleteDC(dc);
        return;
    };
    const old = w.SelectObject(dc, bitmap);
    _ = w.BitBlt(dc, 0, 0, bounds.right, bounds.bottom, screen, origin.x, origin.y, 0x40CC0020);
    _ = w.GdiFlush();
    const pixels = @as([*]u32, @ptrCast(@alignCast(bits.?)))[0 .. @as(usize, @intCast(bounds.right)) * @as(usize, @intCast(bounds.bottom))];
    if (!passive) {
        for (pixels) |*pixel| {
            const value = pixel.*;
            pixel.* = ((((value >> 16) & 255) * 7 / 10) << 16) | ((((value >> 8) & 255) * 7 / 10) << 8) | ((value & 255) * 7 / 10);
        }
    }
    hover_open = passive;
    backdrop = .{ .dc = dc, .bitmap = bitmap, .old = old, .width = bounds.right, .height = bounds.bottom };
    if (window == null) window = w.CreateWindowExW(0, L("MultiPromptUsageCard"), L("AI usage this week"), w.WS_CHILD | w.WS_CLIPSIBLINGS, 0, 0, bounds.right, bounds.bottom, main, null, null, null);
    if (window == null) {
        close();
        return;
    }
    previous_focus = if (passive) null else w.GetFocus();
    if (!passive) {
        focus.cancelShellRefocus(main);
        state.g_popup_menu_active = true;
    }
    snapshot = state.g_ai_pace;
    _ = w.MoveWindow(window, 0, 0, bounds.right, bounds.bottom, 0);
    if (passive) {
        const card = geometry(bounds, anchor, snapshot.goal_count);
        const row = @import("capacity.zig").sidebarUsageRowRect();
        const region = w.CreateRectRgn(@min(card.left, row.left), card.top, @max(card.right, row.right), row.bottom) orelse {
            var log: [96]u8 = undefined;
            debugLog(std.fmt.bufPrint(&log, "[usage-hover] create-region failed error={d}", .{w.GetLastError()}) catch "[usage-hover] create-region failed");
            close();
            return;
        };
        if (w.SetWindowRgn(window, region, 0) == 0) {
            var log: [96]u8 = undefined;
            debugLog(std.fmt.bufPrint(&log, "[usage-hover] set-region failed error={d}", .{w.GetLastError()}) catch "[usage-hover] set-region failed");
            _ = w.DeleteObject(region);
            close();
            return;
        }
        var log: [160]u8 = undefined;
        debugLog(std.fmt.bufPrint(&log, "[usage-hover] set-region ok rect={d},{d},{d},{d}", .{ @min(card.left, row.left), card.top, @max(card.right, row.right), row.bottom }) catch "[usage-hover] set-region ok");
    } else if (w.SetWindowRgn(window, null, 0) == 0) {
        close();
        return;
    }
    const shown = focus.SetWindowPos(window, w.HWND_TOP, 0, 0, 0, 0, w.SWP_NOMOVE | w.SWP_NOSIZE | w.SWP_NOACTIVATE | w.SWP_SHOWWINDOW);
    if (passive) {
        const show_error = if (shown == 0) w.GetLastError() else 0;
        var log: [160]u8 = undefined;
        debugLog(std.fmt.bufPrint(&log, "[usage-hover] show result={d} error={d} visible={} open={}", .{ shown, show_error, w.IsWindowVisible(window), backdrop != null }) catch "[usage-hover] show");
    } else {
        _ = focus.SetFocus(window);
        _ = w.SetCapture(window);
    }
    _ = w.InvalidateRect(window, null, 0);
}

pub fn key(value: usize) bool {
    if (backdrop == null) return false;
    if (hover_open) {
        debugLog("[usage-hover] close on key");
        if (value == w.VK_ESCAPE) dismiss() else close();
        return value == w.VK_ESCAPE;
    }
    if (value == w.VK_ESCAPE) dismiss();
    return true;
}

fn wndProc(hwnd: w.HANDLE, msg: w.UINT, wp: w.WPARAM, lp: w.LPARAM) callconv(w.WINAPI) w.LRESULT {
    const action = state.g_focus_user_action_tick;
    state.g_focus_user_action_tick = focus.focusGuardDispatchTick(msg, wp, lp);
    defer state.g_focus_user_action_tick = action;
    switch (msg) {
        w.WM_ERASEBKGND => return 1,
        w.WM_PAINT => {
            var ps: w.PAINTSTRUCT = undefined;
            const dc = w.BeginPaint(hwnd, &ps);
            defer _ = w.EndPaint(hwnd, &ps);
            if (backdrop) |saved| {
                _ = w.BitBlt(dc, 0, 0, saved.width, saved.height, saved.dc, 0, 0, 0x00CC0020);
                paint(dc, bounds, anchor, &snapshot);
            }
            return 0;
        },
        w.WM_MOUSEMOVE => {
            updateHoverSuppression();
            if (hover_open) {
                const x = @import("startup.zig").GET_X(lp);
                const y = @import("startup.zig").GET_Y(lp);
                var card = geometry(bounds, anchor, snapshot.goal_count);
                card.bottom = anchor.top;
                if (!inside(card, x, y) and !inside(@import("capacity.zig").sidebarUsageRowRect(), x, y)) {
                    var log: [128]u8 = undefined;
                    debugLog(std.fmt.bufPrint(&log, "[usage-hover] close on move x={d} y={d}", .{ x, y }) catch "[usage-hover] close on move");
                    close();
                } else {
                    var tracking = w.TRACKMOUSEEVENT{ .cbSize = @sizeOf(w.TRACKMOUSEEVENT), .dwFlags = 2, .hwndTrack = hwnd, .dwHoverTime = 0 };
                    if (w.TrackMouseEvent(&tracking) == 0) {
                        var log: [96]u8 = undefined;
                        debugLog(std.fmt.bufPrint(&log, "[usage-hover] track failed error={d}", .{w.GetLastError()}) catch "[usage-hover] track failed");
                        close();
                    }
                }
            }
            return 0;
        },
        w.WM_LBUTTONDOWN => {
            const x = @import("startup.zig").GET_X(lp);
            const y = @import("startup.zig").GET_Y(lp);
            const card = geometry(bounds, anchor, snapshot.goal_count);
            if (hover_open and (inside(@import("capacity.zig").sidebarUsageRowRect(), x, y) or inside(card, x, y))) {
                close();
                open();
            } else if (!inside(card, x, y)) dismiss();
            return 0;
        },
        0x02A3 => {
            updateHoverSuppression();
            if (hover_open) {
                var point: w.POINT = undefined;
                var card = geometry(bounds, anchor, snapshot.goal_count);
                card.bottom = anchor.top;
                if (w.GetCursorPos(&point) != 0 and w.ScreenToClient(hwnd, &point) != 0 and
                    (inside(card, point.x, point.y) or inside(@import("capacity.zig").sidebarUsageRowRect(), point.x, point.y))) return 0;
                debugLog("[usage-hover] close on mouse leave");
                close();
            }
            return 0;
        },
        w.WM_KEYDOWN => {
            _ = key(wp);
            return 0;
        },
        w.WM_RBUTTONDOWN, w.WM_KILLFOCUS, 0x0215 => {
            var log: [96]u8 = undefined;
            debugLog(std.fmt.bufPrint(&log, "[usage-hover] close on window message=0x{x}", .{msg}) catch "[usage-hover] close on window message");
            close();
            return 0;
        },
        else => return w.DefWindowProcW(hwnd, msg, wp, lp),
    }
}

test "IGSH-1086 usage card keeps missing windows honest and weekly elapsed independent of usage" {
    var goal: state.AiPaceGoal = .{};
    var buffer: [192]u8 = undefined;
    try std.testing.expectEqualStrings("5-hour window not reported", fiveHourDetail(&buffer, goal, 0));
    try std.testing.expect(weeklyElapsed(goal, 0) == null);
    goal.week_elapsed_tenths = 250;
    goal.total_used_tenths = 530;
    try std.testing.expectEqual(@as(?u16, 250), weeklyElapsed(goal, 0));
    goal.has_five_hour_used = true;
    goal.five_hour_used_tenths = 20;
    try std.testing.expectEqualStrings("5-hour window 2% \xc2\xb7 reset not reported", fiveHourDetail(&buffer, goal, 0));
    goal.has_five_hour_reset = true;
    goal.five_hour_reset_filetime = 224 * 60 * 10_000_000;
    try std.testing.expectEqualStrings("5-hour window 2% \xc2\xb7 resets in 3h 44m", fiveHourDetail(&buffer, goal, 0));
    goal.week_elapsed_tenths = null;
    goal.has_weekly_reset = true;
    goal.weekly_reset_filetime = 7 * 24 * 60 * 60 * 10_000_000;
    try std.testing.expectEqual(@as(?u16, 0), weeklyElapsed(goal, 0));
    try std.testing.expectEqual(@as(?u16, 500), weeklyElapsed(goal, goal.weekly_reset_filetime / 2));
    try std.testing.expectEqual(@as(?u16, 1000), weeklyElapsed(goal, goal.weekly_reset_filetime));
    goal.weekly_reset_filetime *= 2;
    try std.testing.expectEqual(@as(?u16, 0), weeklyElapsed(goal, 0));
}
