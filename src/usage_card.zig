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

var window: w.HANDLE = null;
var registered = false;
var backdrop: ?@import("more_menu.zig").Backdrop = null;
var previous_focus: w.HANDLE = null;
var bounds: RECT = std.mem.zeroes(RECT);
var anchor: RECT = std.mem.zeroes(RECT);
var snapshot: state.AiPaceSnapshot = .{};
var footer_focused = false;
var scroll: i32 = 0;

pub fn updateReady() bool {
    return state.g_update_ver_len > 0 and !state.g_update_relaunching;
}

pub fn versionStripRect() RECT {
    const pill = @import("capacity.zig").sidebarStickyCardRect();
    return .{ .left = pill.left + px(10), .top = pill.top - px(22), .right = pill.right, .bottom = pill.top - px(2) };
}

pub fn versionStripHit(x: i32, y: i32) bool {
    return !state.g_hide_sidebar and !state.g_sidebar_collapsed and updateReady() and inside(versionStripRect(), x, y);
}

pub fn paintVersionStrip(dc: w.HANDLE) void {
    if (state.g_hide_sidebar or state.g_sidebar_collapsed) return;
    const font = fonts.create(-px(11), 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 5, 0, null);
    defer _ = w.DeleteObject(font);
    const old = w.SelectObject(dc, font);
    defer _ = w.SelectObject(dc, old);
    _ = w.SetTextColor(dc, if (state.g_light_theme) RGB(110, 110, 110) else RGB(90, 90, 90));
    var buffer: [128]u8 = undefined;
    const label = if (updateReady())
        std.fmt.bufPrint(&buffer, "Update ready: v{s} \xc2\xb7 Restart", .{state.g_update_ver[0..state.g_update_ver_len]}) catch "Update ready"
    else
        "Multiprompt v" ++ @import("main.zig").APP_VERSION;
    const rect = versionStripRect();
    text(dc, label, rect, if (state.g_light_theme) RGB(110, 110, 110) else RGB(90, 90, 90), 0);
}

pub fn geometry(client: RECT, pill: RECT, count: usize) RECT {
    const width = @min(px(308), client.right - client.left - px(16));
    const left = @max(client.left + px(8), @min(pill.left, client.right - width - px(8)));
    const bottom = pill.top - px(8);
    const height = px(74) + @as(i32, @intCast(@max(1, count))) * px(109);
    return .{ .left = left, .top = @max(client.top + px(8), bottom - height), .right = left + width, .bottom = bottom };
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
    const count = @min(data.goal_count, data.goals.len);
    const card = geometry(client, pill, count);
    const light = state.g_light_theme;
    const panel = if (light) RGB(250, 250, 250) else RGB(24, 24, 24);
    const edge = if (light) RGB(220, 220, 220) else RGB(46, 46, 46);
    const ink = if (light) RGB(28, 28, 28) else RGB(242, 242, 242);
    const dim = if (light) RGB(100, 100, 100) else RGB(138, 138, 138);
    const track = if (light) RGB(225, 225, 225) else RGB(42, 42, 42);
    drawing.drawModalShadow(dc, card.left, card.top, card.right - card.left, card.bottom - card.top, px(32));
    smooth.fillRoundRect(dc, card, px(16), edge);
    smooth.fillRoundRect(dc, .{ .left = card.left + 1, .top = card.top + 1, .right = card.right - 1, .bottom = card.bottom - 1 }, px(16) - 1, panel);
    const regular = fonts.create(-px(12), 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 5, 0, null);
    defer _ = w.DeleteObject(regular);
    const heading = fonts.create(-px(14), 0, 0, 0, 600, 0, 0, 0, 0, 0, 0, 5, 0, null);
    defer _ = w.DeleteObject(heading);
    const small = fonts.create(-px(11), 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 5, 0, null);
    defer _ = w.DeleteObject(small);
    const old = w.SelectObject(dc, small);
    defer _ = w.SelectObject(dc, old);
    const old_mode = w.SetBkMode(dc, w.TRANSPARENT);
    defer _ = w.SetBkMode(dc, old_mode);
    const left = card.left + px(16);
    const right = card.right - px(16);
    text(dc, "AI USAGE THIS WEEK", .{ .left = left, .top = card.top + px(12), .right = right, .bottom = card.top + px(32) }, dim, 0);
    const clipped = w.SaveDC(dc);
    _ = w.IntersectClipRect(dc, left, card.top + px(38), right, card.bottom - px(50));
    var y = card.top + px(40) - scroll;
    const now = @import("inbox.zig").nowFileTime();
    for (data.goals[0..count], 0..) |goal, slot| {
        _ = w.SelectObject(dc, heading);
        text(dc, goal.shortLabel(), .{ .left = left, .top = y, .right = right - px(48), .bottom = y + px(20) }, ink, 0);
        const name_width = drawing.asciiTextWidth(dc, goal.shortLabel());
        _ = w.SelectObject(dc, small);
        var short: [16]u8 = undefined;
        text(dc, telemetry.aiPoolShortLabel(&short, data, slot), .{ .left = left + name_width + px(6), .top = y, .right = right - px(44), .bottom = y + px(20) }, dim, 0);
        _ = w.SelectObject(dc, heading);
        var percent: [24]u8 = undefined;
        text(dc, if (goal.has_total_used) telemetry.formatAiPacePercent(&percent, goal.total_used_tenths) else "--", .{ .left = right - px(48), .top = y, .right = right, .bottom = y + px(20) }, ink, w.DT_RIGHT);
        const bar = RECT{ .left = left, .top = y + px(30), .right = right, .bottom = y + px(36) };
        smooth.fillRoundRect(dc, bar, px(3), track);
        if (goal.has_total_used and goal.total_used_tenths > 0) smooth.fillRoundRect(dc, .{ .left = left, .top = bar.top, .right = left + @divTrunc((right - left) * @as(i32, goal.total_used_tenths), 1000), .bottom = bar.bottom }, px(3), ink);
        if (weeklyElapsed(goal, now)) |elapsed| {
            const x = std.math.clamp(left + @divTrunc((right - left) * @as(i32, elapsed), 1000), left, right - @max(1, px(1)));
            const brush = w.CreateSolidBrush(dim);
            defer _ = w.DeleteObject(brush);
            const tick = RECT{ .left = x, .top = bar.top - px(2), .right = x + @max(1, px(1)), .bottom = bar.bottom + px(2) };
            _ = w.FillRect(dc, &tick, brush);
        }
        _ = w.SelectObject(dc, regular);
        var detail: [192]u8 = undefined;
        text(dc, weeklyDetail(&detail, goal, now), .{ .left = left, .top = y + px(42), .right = right, .bottom = y + px(61) }, dim, 0);
        text(dc, fiveHourDetail(&detail, goal, now), .{ .left = left, .top = y + px(63), .right = right, .bottom = y + px(82) }, dim, 0);
        const divider = RECT{ .left = left, .top = y + px(96), .right = right, .bottom = y + px(96) + 1 };
        const brush = w.CreateSolidBrush(track);
        _ = w.FillRect(dc, &divider, brush);
        _ = w.DeleteObject(brush);
        y += px(109);
    }
    if (count == 0) {
        _ = w.SelectObject(dc, regular);
        text(dc, "Usage is loading", .{ .left = left, .top = y, .right = right, .bottom = y + px(24) }, dim, 0);
    }
    _ = w.RestoreDC(dc, clipped);
    _ = w.SelectObject(dc, regular);
    const footer = RECT{ .left = left, .top = card.bottom - px(48), .right = right, .bottom = card.bottom - px(22) };
    text(dc, "Multiprompt", footer, dim, 0);
    text(dc, "v" ++ @import("main.zig").APP_VERSION, .{ .left = left + px(74), .top = footer.top, .right = right - px(90), .bottom = footer.bottom }, ink, 0);
    text(dc, "Release notes \xe2\x80\xba", .{ .left = right - px(88), .top = footer.top, .right = right, .bottom = footer.bottom }, if (footer_focused) ink else dim, w.DT_RIGHT);
    _ = w.SelectObject(dc, small);
    text(dc, "Grey tick = how much of the week has passed", .{ .left = left, .top = card.bottom - px(22), .right = right, .bottom = card.bottom - px(3) }, if (light) dim else RGB(90, 90, 90), 0);
}

pub fn close() void {
    if (backdrop == null) return;
    var saved = backdrop.?;
    backdrop = null;
    state.g_popup_menu_active = false;
    if (w.GetCapture() == window) _ = w.ReleaseCapture();
    _ = focus.ShowWindow(window, w.SW_HIDE);
    saved.release();
    if (previous_focus != null and w.IsWindow(previous_focus) != 0) _ = focus.SetFocus(previous_focus);
    _ = w.InvalidateRect(state.g_main_hwnd, null, 0);
}

pub fn open() void {
    if (backdrop != null) {
        close();
        return;
    }
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
    for (pixels) |*pixel| {
        const value = pixel.*;
        pixel.* = ((((value >> 16) & 255) * 7 / 10) << 16) | ((((value >> 8) & 255) * 7 / 10) << 8) | ((value & 255) * 7 / 10);
    }
    backdrop = .{ .dc = dc, .bitmap = bitmap, .old = old, .width = bounds.right, .height = bounds.bottom };
    if (window == null) window = w.CreateWindowExW(0, L("MultiPromptUsageCard"), L("AI usage this week"), w.WS_CHILD | w.WS_CLIPSIBLINGS, 0, 0, bounds.right, bounds.bottom, main, null, null, null);
    if (window == null) {
        close();
        return;
    }
    previous_focus = w.GetFocus();
    focus.cancelShellRefocus(main);
    state.g_popup_menu_active = true;
    snapshot = state.g_ai_pace;
    footer_focused = false;
    scroll = 0;
    _ = w.MoveWindow(window, 0, 0, bounds.right, bounds.bottom, 0);
    _ = focus.SetWindowPos(window, w.HWND_TOP, 0, 0, 0, 0, w.SWP_NOMOVE | w.SWP_NOSIZE | w.SWP_NOACTIVATE | w.SWP_SHOWWINDOW);
    _ = focus.SetFocus(window);
    _ = w.SetCapture(window);
    _ = w.InvalidateRect(window, null, 0);
}

pub fn key(value: usize) bool {
    if (backdrop == null) return false;
    switch (value) {
        w.VK_ESCAPE => close(),
        0x09 => {
            footer_focused = true;
            _ = w.InvalidateRect(window, null, 0);
        },
        0x0D => {
            if (footer_focused) {
                close();
                _ = focus.PostMessageW(state.g_main_hwnd, w.WM_APP_CHANGELOG_OPEN, 0, 0);
            }
        },
        else => {},
    }
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
        w.WM_LBUTTONDOWN => {
            const x = @import("startup.zig").GET_X(lp);
            const y = @import("startup.zig").GET_Y(lp);
            const card = geometry(bounds, anchor, snapshot.goal_count);
            if (!inside(card, x, y)) close() else if (x >= card.right - px(110) and y >= card.bottom - px(48) and y < card.bottom - px(22)) {
                close();
                _ = focus.PostMessageW(state.g_main_hwnd, w.WM_APP_CHANGELOG_OPEN, 0, 0);
            }
            return 0;
        },
        w.WM_MOUSEWHEEL => {
            const delta: i16 = @bitCast(@as(u16, @truncate(wp >> 16)));
            const card = geometry(bounds, anchor, snapshot.goal_count);
            const overflow = @max(0, @as(i32, @intCast(snapshot.goal_count)) * px(109) - (card.bottom - card.top - px(90)));
            scroll = std.math.clamp(scroll - @divTrunc(@as(i32, delta) * px(54), 120), 0, overflow);
            _ = w.InvalidateRect(hwnd, null, 0);
            return 0;
        },
        w.WM_KEYDOWN => {
            _ = key(wp);
            return 0;
        },
        w.WM_RBUTTONDOWN, w.WM_KILLFOCUS, 0x0215 => {
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
