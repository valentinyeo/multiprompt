const app_state = @import("app_state.zig");
const std = @import("std");
const WINAPI = @import("win32.zig").WINAPI;
const BOOL = @import("win32.zig").BOOL;
const LPARAM = @import("win32.zig").LPARAM;
const HANDLE = @import("win32.zig").HANDLE;
const SW_HIDE = @import("win32.zig").SW_HIDE;
const TIMER_BROWSER_EDGE_MASK_RAISE = @import("win32.zig").TIMER_BROWSER_EDGE_MASK_RAISE;
const TIMER_CONSOLE_GEOMETRY_SETTLE = @import("win32.zig").TIMER_CONSOLE_GEOMETRY_SETTLE;
const TIMER_MONITOR_TRANSITION = @import("win32.zig").TIMER_MONITOR_TRANSITION;
const POINT = @import("win32.zig").POINT;
const RECT = @import("win32.zig").RECT;
const IsIconic = @import("win32.zig").IsIconic;
const GetWindowRect = @import("win32.zig").GetWindowRect;
const MonitorFromWindow = @import("win32.zig").MonitorFromWindow;
const GetMonitorInfoW = @import("win32.zig").GetMonitorInfoW;
const MONITORINFO = @import("win32.zig").MONITORINFO;
const MONITOR_DEFAULTTONEAREST = @import("win32.zig").MONITOR_DEFAULTTONEAREST;
const EnumDisplayMonitors = @import("win32.zig").EnumDisplayMonitors;
const MonitorSlot = @import("app_state.zig").MonitorSlot;
const MonitorDirection = @import("app_state.zig").MonitorDirection;
const MonitorTransitionReason = @import("app_state.zig").MonitorTransitionReason;
const IsWindow = @import("win32.zig").IsWindow;
const GetClientRect = @import("win32.zig").GetClientRect;
const CloseHandle = @import("win32.zig").CloseHandle;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const ClientToScreen = @import("win32.zig").ClientToScreen;
const ShowWindow = @import("focus.zig").ShowWindow;
const cancelBrowserVisibilitySettle = @import("browser_pane.zig").cancelBrowserVisibilitySettle;
const armConsoleGeometrySettle = @import("console.zig").armConsoleGeometrySettle;
const BROWSER_EDGE_MASK_COUNT = @import("app_state.zig").BROWSER_EDGE_MASK_COUNT;
const win32OpenAppend = @import("file_io.zig").win32OpenAppend;
const win32WriteAll = @import("file_io.zig").win32WriteAll;
const writeAuditU64 = @import("diagnostics.zig").writeAuditU64;
const syncMainWindowDpi = @import("console.zig").syncMainWindowDpi;
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;
const browserAppTitlebarH = @import("browser_pane.zig").browserAppTitlebarH;
const browserNativeBottomOverrun = @import("browser_pane.zig").browserNativeBottomOverrun;
const activeBrowserTransientPopupHasForegroundFocus = @import("browser_pane.zig").activeBrowserTransientPopupHasForegroundFocus;
const calcBrowserLayout = @import("browser_pane.zig").calcBrowserLayout;
const parkBrowserWindow = @import("browser_pane.zig").parkBrowserWindow;
const updateBrowserVisibility = @import("browser_pane.zig").updateBrowserVisibility;
const paneFocusInset = @import("browser_pane.zig").paneFocusInset;
const browserChromeForegroundAllowed = @import("browser_pane.zig").browserChromeForegroundAllowed;
const activeBrowserEdgeMasksAllowed = @import("browser_pane.zig").activeBrowserEdgeMasksAllowed;
const hideBrowserEdgeMasks = @import("browser_pane.zig").hideBrowserEdgeMasks;
const armBrowserEdgeMaskRaise = @import("browser_pane.zig").armBrowserEdgeMaskRaise;
const repositionActive = @import("window_layout.zig").repositionActive;
const SetTimer = @import("win32.zig").SetTimer;
const KillTimer = @import("win32.zig").KillTimer;
const nowFileTime = @import("inbox.zig").nowFileTime;

fn rectWidth64(r: RECT) i64 {
    return @as(i64, r.right) - @as(i64, r.left);
}

fn rectHeight64(r: RECT) i64 {
    return @as(i64, r.bottom) - @as(i64, r.top);
}

fn rectCenterX2(r: RECT) i64 {
    return @as(i64, r.left) + @as(i64, r.right);
}

fn rectCenterY2(r: RECT) i64 {
    return @as(i64, r.top) + @as(i64, r.bottom);
}

fn abs64(v: i64) i64 {
    return if (v < 0) -v else v;
}

fn axisGap(a0: i32, a1: i32, b0: i32, b1: i32) i64 {
    if (b0 > a1) return @as(i64, b0) - @as(i64, a1);
    if (a0 > b1) return @as(i64, a0) - @as(i64, b1);
    return 0;
}

fn rectLexLess(a: RECT, b: RECT) bool {
    if (a.left != b.left) return a.left < b.left;
    if (a.top != b.top) return a.top < b.top;
    if (a.right != b.right) return a.right < b.right;
    return a.bottom < b.bottom;
}

fn directionalMonitorIndex(works: []const RECT, current_idx: usize, direction: MonitorDirection) ?usize {
    if (works.len < 2 or current_idx >= works.len) return null;
    const src = works[current_idx];
    const sx = rectCenterX2(src);
    const sy = rectCenterY2(src);
    var best: ?usize = null;
    var best_lane_gap: i64 = std.math.maxInt(i64);
    var best_angle: i64 = std.math.maxInt(i64);
    var best_distance: i64 = std.math.maxInt(i64);
    var has_axis_variation = false;

    for (works, 0..) |candidate, i| {
        if (i == current_idx) continue;
        const dx = rectCenterX2(candidate) - sx;
        const dy = rectCenterY2(candidate) - sy;
        has_axis_variation = has_axis_variation or switch (direction) {
            .left, .right => dx != 0,
            .up, .down => dy != 0,
        };
        const forward = switch (direction) {
            .left => -dx,
            .right => dx,
            .up => -dy,
            .down => dy,
        };
        if (forward <= 0) continue;
        const perpendicular = switch (direction) {
            .left, .right => abs64(dy),
            .up, .down => abs64(dx),
        };
        const lane_gap = switch (direction) {
            .left, .right => axisGap(src.top, src.bottom, candidate.top, candidate.bottom),
            .up, .down => axisGap(src.left, src.right, candidate.left, candidate.right),
        };
        const angle = @divTrunc(perpendicular * 4096, forward);
        const distance = forward + perpendicular;
        const better = lane_gap < best_lane_gap or
            (lane_gap == best_lane_gap and angle < best_angle) or
            (lane_gap == best_lane_gap and angle == best_angle and distance < best_distance) or
            (lane_gap == best_lane_gap and angle == best_angle and distance == best_distance and
                (best == null or rectLexLess(candidate, works[best.?])));
        if (better) {
            best = i;
            best_lane_gap = lane_gap;
            best_angle = angle;
            best_distance = distance;
        }
    }
    if (best != null) return best;
    if (has_axis_variation) return null;

    var nearest: ?usize = null;
    var nearest_distance: i64 = std.math.maxInt(i64);
    for (works, 0..) |candidate, i| {
        if (i == current_idx) continue;
        const dx = rectCenterX2(candidate) - sx;
        const dy = rectCenterY2(candidate) - sy;
        const distance = dx * dx + dy * dy;
        if (distance < nearest_distance or
            (distance == nearest_distance and (nearest == null or rectLexLess(candidate, works[nearest.?]))))
        {
            nearest = i;
            nearest_distance = distance;
        }
    }
    return nearest;
}

fn mappedAxisPosition(src_start: i32, src_extent: i64, dst_start: i32, dst_extent: i64, window_extent: i64, window_start: i32) i32 {
    const bounded_window = @min(window_extent, src_extent);
    const src_travel = @max(@as(i64, 0), src_extent - bounded_window);
    const dst_travel = @max(@as(i64, 0), dst_extent - window_extent);
    if (src_travel == 0 or dst_travel == 0) return dst_start;
    const raw_offset = @as(i64, window_start) - @as(i64, src_start);
    const offset = @max(@as(i64, 0), @min(src_travel, raw_offset));
    const mapped = @divTrunc(offset * dst_travel + @divTrunc(src_travel, 2), src_travel);
    return @intCast(@as(i64, dst_start) + mapped);
}

pub fn mapWindowRectToWorkArea(window: RECT, source: RECT, destination: RECT) RECT {
    const dst_w = @max(@as(i64, 1), rectWidth64(destination));
    const dst_h = @max(@as(i64, 1), rectHeight64(destination));
    const w = @min(@max(@as(i64, 1), rectWidth64(window)), dst_w);
    const h = @min(@max(@as(i64, 1), rectHeight64(window)), dst_h);
    const x = mappedAxisPosition(source.left, @max(@as(i64, 1), rectWidth64(source)), destination.left, dst_w, w, window.left);
    const y = mappedAxisPosition(source.top, @max(@as(i64, 1), rectHeight64(source)), destination.top, dst_h, h, window.top);
    return .{
        .left = x,
        .top = y,
        .right = @intCast(@as(i64, x) + w),
        .bottom = @intCast(@as(i64, y) + h),
    };
}

fn monitorEnumCb(mon: HANDLE, hdc: HANDLE, rc: ?*RECT, lp: LPARAM) callconv(WINAPI) BOOL {
    _ = hdc;
    _ = rc;
    _ = lp;
    if (app_state.g_mon_count < app_state.g_mon_list.len) {
        var mi: MONITORINFO = std.mem.zeroes(MONITORINFO);
        mi.cbSize = @sizeOf(MONITORINFO);
        if (mon != null and GetMonitorInfoW(mon, &mi) != 0) {
            app_state.g_mon_list[app_state.g_mon_count] = .{ .mon = mon, .bounds = mi.rcMonitor, .work = mi.rcWork };
            app_state.g_mon_count += 1;
        }
    }
    return 1;
}

fn collectMonitors() void {
    app_state.g_mon_count = 0;
    _ = EnumDisplayMonitors(null, null, monitorEnumCb, 0);
}

pub fn rectNear(r: RECT, x: i32, y: i32, w: i32, h: i32) bool {
    return @abs(r.left - x) <= 32 and @abs(r.top - y) <= 32 and
        @abs((r.right - r.left) - w) <= 32 and @abs((r.bottom - r.top) - h) <= 32;
}

pub fn monitorSlotInDirection(cur: HANDLE, direction: MonitorDirection) ?MonitorSlot {
    collectMonitors();
    var current_idx: ?usize = null;
    var works: [8]RECT = undefined;
    for (0..app_state.g_mon_count) |i| {
        works[i] = app_state.g_mon_list[i].work;
        if (app_state.g_mon_list[i].mon == cur) current_idx = i;
    }
    const selected = directionalMonitorIndex(works[0..app_state.g_mon_count], current_idx orelse return null, direction) orelse return null;
    return app_state.g_mon_list[selected];
}

test "monitor selection handles gaps diagonals vertical stacks and more than two displays" {
    const current = [_]RECT{
        .{ .left = -2560, .top = -514, .right = -512, .bottom = 718 },
        .{ .left = 0, .top = 0, .right = 1920, .bottom = 1032 },
    };
    try std.testing.expectEqual(@as(?usize, 0), directionalMonitorIndex(&current, 1, .left));
    try std.testing.expectEqual(@as(?usize, 1), directionalMonitorIndex(&current, 0, .right));
    try std.testing.expectEqual(@as(?usize, null), directionalMonitorIndex(&current, 0, .left));

    const compass = [_]RECT{
        .{ .left = 0, .top = 0, .right = 1920, .bottom = 1040 },
        .{ .left = -1800, .top = 120, .right = -200, .bottom = 1020 },
        .{ .left = 2300, .top = -300, .right = 3900, .bottom = 700 },
        .{ .left = 200, .top = -1500, .right = 1400, .bottom = -200 },
        .{ .left = 300, .top = 1300, .right = 1500, .bottom = 2500 },
    };
    try std.testing.expectEqual(@as(?usize, 1), directionalMonitorIndex(&compass, 0, .left));
    try std.testing.expectEqual(@as(?usize, 2), directionalMonitorIndex(&compass, 0, .right));
    try std.testing.expectEqual(@as(?usize, 3), directionalMonitorIndex(&compass, 0, .up));
    try std.testing.expectEqual(@as(?usize, 4), directionalMonitorIndex(&compass, 0, .down));

    const vertical = [_]RECT{
        .{ .left = 0, .top = 0, .right = 1920, .bottom = 1080 },
        .{ .left = 0, .top = -1300, .right = 1920, .bottom = -220 },
    };
    try std.testing.expectEqual(@as(?usize, 1), directionalMonitorIndex(&vertical, 0, .right));
}

test "window mapping is proportional clamped and independent of virtual desktop origin" {
    const src = RECT{ .left = 0, .top = 0, .right = 1920, .bottom = 1032 };
    const dst = RECT{ .left = -2560, .top = -514, .right = -512, .bottom = 718 };
    const mapped = mapWindowRectToWorkArea(.{ .left = 960, .top = 516, .right = 1920, .bottom = 1032 }, src, dst);
    try std.testing.expectEqual(@as(i32, -1472), mapped.left);
    try std.testing.expectEqual(@as(i32, 202), mapped.top);
    try std.testing.expectEqual(@as(i32, -512), mapped.right);
    try std.testing.expectEqual(@as(i32, 718), mapped.bottom);

    const portrait = RECT{ .left = 2500, .top = -800, .right = 3580, .bottom = 1120 };
    const oversized = mapWindowRectToWorkArea(.{ .left = -100, .top = -100, .right = 2300, .bottom = 1400 }, src, portrait);
    try std.testing.expectEqual(@as(i32, 2500), oversized.left);
    try std.testing.expectEqual(@as(i32, -800), oversized.top);
    try std.testing.expectEqual(@as(i32, 3580), oversized.right);
    try std.testing.expectEqual(@as(i32, 700), oversized.bottom);
}

fn rectApproximatelyEqual(a: RECT, b: RECT, tolerance: i32) bool {
    return @abs(a.left - b.left) <= tolerance and
        @abs(a.top - b.top) <= tolerance and
        @abs(a.right - b.right) <= tolerance and
        @abs(a.bottom - b.bottom) <= tolerance;
}

fn rectContainedBy(outer: RECT, inner: RECT, tolerance: i32) bool {
    return inner.left >= outer.left - tolerance and
        inner.top >= outer.top - tolerance and
        inner.right <= outer.right + tolerance and
        inner.bottom <= outer.bottom + tolerance;
}

fn monitorSlotForHandle(mon: HANDLE) ?MonitorSlot {
    if (mon == null) return null;
    collectMonitors();
    for (0..app_state.g_mon_count) |i| {
        if (app_state.g_mon_list[i].mon == mon) return app_state.g_mon_list[i];
    }
    return null;
}

fn currentMonitorSlot(hwnd: HANDLE) ?MonitorSlot {
    if (hwnd == null) return null;
    return monitorSlotForHandle(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST));
}

fn monitorMoveAuditPath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 466) return null;
    const rest = "\\ZigShell\\monitor-move-audit.tsv";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

fn auditMonitorTransition(stage: []const u8, ok: bool, actual: RECT) void {
    var path_buf: [512]u8 = undefined;
    const path = monitorMoveAuditPath(&path_buf) orelse return;
    const h = win32OpenAppend(path) orelse return;
    defer _ = CloseHandle(h);
    writeAuditU64(h, nowFileTime());
    var buf: [448]u8 = undefined;
    const line = std.fmt.bufPrint(
        &buf,
        "\t{s}\tok={d}\tgen={d}\treason={s}\tsrc=({d},{d},{d},{d})\tdst=({d},{d},{d},{d})\texpected=({d},{d},{d},{d})\tactual=({d},{d},{d},{d})\r\n",
        .{
            stage,
            @intFromBool(ok),
            app_state.g_monitor_transition.generation,
            @tagName(app_state.g_monitor_transition.reason),
            app_state.g_monitor_transition.source_work.left,
            app_state.g_monitor_transition.source_work.top,
            app_state.g_monitor_transition.source_work.right,
            app_state.g_monitor_transition.source_work.bottom,
            app_state.g_monitor_transition.target_work.left,
            app_state.g_monitor_transition.target_work.top,
            app_state.g_monitor_transition.target_work.right,
            app_state.g_monitor_transition.target_work.bottom,
            app_state.g_monitor_transition.expected_frame.left,
            app_state.g_monitor_transition.expected_frame.top,
            app_state.g_monitor_transition.expected_frame.right,
            app_state.g_monitor_transition.expected_frame.bottom,
            actual.left,
            actual.top,
            actual.right,
            actual.bottom,
        },
    ) catch return;
    win32WriteAll(h, line);
}

pub fn parkBrowserForMonitorTransition() void {
    cancelBrowserVisibilitySettle();
    app_state.g_browser_edge_mask_raise_ticks = 0;
    if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_BROWSER_EDGE_MASK_RAISE);
    hideBrowserEdgeMasks();
    if (app_state.g_urlbar_hwnd != null and IsWindow(app_state.g_urlbar_hwnd) != 0) _ = ShowWindow(app_state.g_urlbar_hwnd, SW_HIDE);
    if (app_state.active_shell < app_state.shell_count) {
        if (app_state.shells[app_state.active_shell].browser_hwnd) |bh| {
            if (IsWindow(bh) != 0) parkBrowserWindow(bh);
        }
    }
}

pub fn armMonitorTransitionTimer(hwnd: HANDLE) void {
    if (hwnd == null or !app_state.g_monitor_transition.active) return;
    _ = KillTimer(hwnd, TIMER_MONITOR_TRANSITION);
    _ = SetTimer(hwnd, TIMER_MONITOR_TRANSITION, 80, null);
}

pub fn beginMonitorTransition(hwnd: HANDLE, target: MonitorSlot, expected: RECT, expected_valid: bool, reason: MonitorTransitionReason) void {
    if (hwnd == null or IsIconic(hwnd) != 0) return;
    const source_mon = if (app_state.g_last_main_monitor != null) app_state.g_last_main_monitor else MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
    const source = monitorSlotForHandle(source_mon) orelse currentMonitorSlot(hwnd) orelse target;
    var next_generation = app_state.g_monitor_transition.generation +% 1;
    if (next_generation == 0) next_generation = 1;
    app_state.g_monitor_transition = .{
        .active = true,
        .generation = next_generation,
        .reason = reason,
        .source_mon = source.mon,
        .target_mon = target.mon,
        .source_work = source.work,
        .target_work = target.work,
        .expected_frame = expected,
        .expected_valid = expected_valid,
    };
    _ = KillTimer(hwnd, TIMER_CONSOLE_GEOMETRY_SETTLE);
    app_state.g_console_geometry_settle_ticks = 0;
    parkBrowserForMonitorTransition();
    var actual: RECT = std.mem.zeroes(RECT);
    _ = GetWindowRect(hwnd, &actual);
    auditMonitorTransition("begin", false, actual);
    armMonitorTransitionTimer(hwnd);
}

pub fn beginMonitorTransitionAtCurrent(hwnd: HANDLE, reason: MonitorTransitionReason) void {
    const target = currentMonitorSlot(hwnd) orelse return;
    var frame: RECT = std.mem.zeroes(RECT);
    if (GetWindowRect(hwnd, &frame) == 0) return;
    beginMonitorTransition(hwnd, target, frame, true, reason);
}

pub fn retargetMonitorTransitionToCurrent(hwnd: HANDLE) void {
    if (!app_state.g_monitor_transition.active) {
        beginMonitorTransitionAtCurrent(hwnd, .detected_crossing);
        return;
    }
    const target = currentMonitorSlot(hwnd) orelse return;
    var frame: RECT = std.mem.zeroes(RECT);
    if (GetWindowRect(hwnd, &frame) == 0) return;
    app_state.g_monitor_transition.target_mon = target.mon;
    app_state.g_monitor_transition.target_work = target.work;
    app_state.g_monitor_transition.expected_frame = frame;
    app_state.g_monitor_transition.expected_valid = true;
    app_state.g_monitor_transition.last_frame_valid = false;
    app_state.g_monitor_transition.stable_samples = 0;
    app_state.g_monitor_transition.attempts = 0;
    armMonitorTransitionTimer(hwnd);
}

pub fn noteMainWindowMonitor(hwnd: HANDLE) void {
    if (hwnd == null) return;
    const mon = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
    if (mon == null) return;
    if (app_state.g_last_main_monitor == null) {
        app_state.g_last_main_monitor = mon;
        return;
    }
    if (mon != app_state.g_last_main_monitor and !app_state.g_monitor_transition.active) {
        beginMonitorTransitionAtCurrent(hwnd, .detected_crossing);
    }
    app_state.g_last_main_monitor = mon;
}

pub fn expectedActiveBrowserRect() ?RECT {
    if (app_state.active_shell >= app_state.shell_count or app_state.g_main_hwnd == null) return null;
    const bh = app_state.shells[app_state.active_shell].browser_hwnd orelse return null;
    if (IsWindow(bh) == 0 or !app_state.shells[app_state.active_shell].browser_enabled) return null;
    const layout = calcBrowserLayout() orelse return null;
    var pt = POINT{ .x = layout.browser_x, .y = layout.browser_y };
    if (ClientToScreen(app_state.g_main_hwnd, &pt) == 0) return null;
    if (app_state.shells[app_state.active_shell].browser_native) {
        const inset = paneFocusInset();
        const w = @max(@as(i32, 1), layout.browser_w - 2 * inset);
        const h = @max(@as(i32, 1), layout.browser_h - 2 * inset + browserNativeBottomOverrun());
        return .{ .left = pt.x + inset, .top = pt.y + inset, .right = pt.x + inset + w, .bottom = pt.y + inset + h };
    }
    const tbh = browserAppTitlebarH();
    return .{ .left = pt.x, .top = pt.y - tbh, .right = pt.x + layout.browser_w, .bottom = pt.y + layout.browser_h };
}

fn monitorTransitionComponentsReady(hwnd: HANDLE, frame: RECT) bool {
    if (app_state.g_monitor_transition.target_mon != null and
        MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST) != app_state.g_monitor_transition.target_mon)
        return false;
    if (app_state.g_monitor_transition.expected_valid and !rectApproximatelyEqual(frame, app_state.g_monitor_transition.expected_frame, 40))
        return false;

    var client: RECT = std.mem.zeroes(RECT);
    if (GetClientRect(hwnd, &client) == 0) return false;
    var origin = POINT{ .x = 0, .y = 0 };
    if (ClientToScreen(hwnd, &origin) == 0) return false;
    const client_screen = RECT{
        .left = origin.x,
        .top = origin.y,
        .right = origin.x + client.right,
        .bottom = origin.y + client.bottom,
    };
    if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].hwnd != null and IsWindow(app_state.shells[app_state.active_shell].hwnd) != 0) {
        var shell_rect: RECT = std.mem.zeroes(RECT);
        if (GetWindowRect(app_state.shells[app_state.active_shell].hwnd, &shell_rect) == 0 or !rectContainedBy(client_screen, shell_rect, 12))
            return false;
    }
    if (expectedActiveBrowserRect()) |expected_browser| {
        const bh = app_state.shells[app_state.active_shell].browser_hwnd orelse return false;
        var browser_rect: RECT = std.mem.zeroes(RECT);
        if (GetWindowRect(bh, &browser_rect) == 0 or !rectApproximatelyEqual(browser_rect, expected_browser, 16))
            return false;
    }
    return true;
}

fn monitorTransitionMasksReady() bool {
    if (app_state.active_shell >= app_state.shell_count or !app_state.shells[app_state.active_shell].browser_native) return true;
    if (!activeBrowserEdgeMasksAllowed()) return true;
    if (!browserChromeForegroundAllowed() or activeBrowserTransientPopupHasForegroundFocus()) return true;
    for (0..BROWSER_EDGE_MASK_COUNT) |i| {
        if (!app_state.g_browser_edge_mask_shown[i]) return false;
        const mask = app_state.g_browser_edge_mask_hwnds[i];
        if (mask == null or IsWindow(mask) == 0) return false;
        var mask_rect: RECT = std.mem.zeroes(RECT);
        if (GetWindowRect(mask, &mask_rect) == 0 or !rectContainedBy(app_state.g_monitor_transition.target_work, mask_rect, 32))
            return false;
    }
    return true;
}

fn finishMonitorTransition(hwnd: HANDLE, ok: bool, stage: []const u8) void {
    var actual: RECT = std.mem.zeroes(RECT);
    _ = GetWindowRect(hwnd, &actual);
    app_state.g_monitor_transition.active = false;
    app_state.g_monitor_transition.positioning = false;
    _ = KillTimer(hwnd, TIMER_MONITOR_TRANSITION);
    app_state.g_last_main_monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
    repositionActive();
    updateBrowserVisibility();
    if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_native) armBrowserEdgeMaskRaise();
    armConsoleGeometrySettle(hwnd);
    const final_ok = ok and monitorTransitionMasksReady();
    auditMonitorTransition(if (ok and !final_ok) "mask_readback" else stage, final_ok, actual);
    if (!final_ok) showHeaderNoticeAscii("Monitor move incomplete - audit saved", 5000, true);
}

pub fn monitorTransitionTick(hwnd: HANDLE) void {
    if (!app_state.g_monitor_transition.active) {
        _ = KillTimer(hwnd, TIMER_MONITOR_TRANSITION);
        return;
    }
    if (IsIconic(hwnd) != 0) {
        var frame: RECT = std.mem.zeroes(RECT);
        _ = GetWindowRect(hwnd, &frame);
        auditMonitorTransition("cancelled_iconic", false, frame);
        app_state.g_monitor_transition.active = false;
        app_state.g_monitor_transition.positioning = false;
        _ = KillTimer(hwnd, TIMER_MONITOR_TRANSITION);
        return;
    }
    if (app_state.g_move_size_active) return;
    if (app_state.g_monitor_transition.target_mon == null) retargetMonitorTransitionToCurrent(hwnd);

    _ = syncMainWindowDpi(hwnd, 0);
    app_state.g_monitor_transition.positioning = true;
    repositionActive();
    app_state.g_monitor_transition.positioning = false;

    var frame: RECT = std.mem.zeroes(RECT);
    if (GetWindowRect(hwnd, &frame) == 0) {
        app_state.g_monitor_transition.attempts +|= 1;
    } else {
        if (app_state.g_monitor_transition.last_frame_valid and rectApproximatelyEqual(frame, app_state.g_monitor_transition.last_frame, 1))
            app_state.g_monitor_transition.stable_samples +|= 1
        else
            app_state.g_monitor_transition.stable_samples = 0;
        app_state.g_monitor_transition.last_frame = frame;
        app_state.g_monitor_transition.last_frame_valid = true;
        app_state.g_monitor_transition.attempts +|= 1;
        if (app_state.g_monitor_transition.stable_samples >= 2 and monitorTransitionComponentsReady(hwnd, frame)) {
            finishMonitorTransition(hwnd, true, "verified");
            return;
        }
    }
    if (app_state.g_monitor_transition.attempts >= 15) {
        finishMonitorTransition(hwnd, false, "timeout");
    }
}
