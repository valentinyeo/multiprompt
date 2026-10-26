const std = @import("std");
const w = @import("win32.zig");
const uiScaled = @import("drawing.zig").uiScaled;
const RGB = @import("startup.zig").RGB;

pub const Button = enum { minimize, maximize, close };
var hovered: ?Button = null;
var pressed: ?Button = null;

pub fn controlsRect(width: i32) w.RECT {
    return .{ .left = width - uiScaled(44) * 3, .top = 0, .right = width, .bottom = uiScaled(32) };
}

pub fn buttonRect(width: i32, button: Button) w.RECT {
    const band = controlsRect(width);
    const left = band.left + @as(i32, @intCast(@intFromEnum(button))) * uiScaled(44);
    return .{ .left = left, .top = band.top, .right = left + uiScaled(44), .bottom = band.bottom };
}

fn buttonAt(width: i32, point: w.POINT) ?Button {
    inline for (std.meta.tags(Button)) |button| {
        const rc = buttonRect(width, button);
        if (point.x >= rc.left and point.x < rc.right and point.y >= rc.top and point.y < rc.bottom) return button;
    }
    return null;
}

fn hitCode(button: Button) w.LRESULT {
    return switch (button) {
        .minimize => 8,
        .maximize => 9,
        .close => 20,
    };
}

fn pointFromMessage(lp: w.LPARAM) w.POINT {
    const bits: usize = @bitCast(lp);
    return .{ .x = @as(i16, @bitCast(@as(u16, @truncate(bits)))), .y = @as(i16, @bitCast(@as(u16, @truncate(bits >> 16)))) };
}

pub fn hitTest(client: w.RECT, point: w.POINT, maximized: bool, border: i32) w.LRESULT {
    const left = point.x < border;
    const right = point.x >= client.right - border;
    const top = point.y < border;
    const bottom = point.y >= client.bottom - border;
    if (!maximized) {
        if (top and left) return 13;
        if (top and right) return 14;
        if (bottom and left) return 16;
        if (bottom and right) return 17;
        if (left) return 10;
        if (right) return 11;
        if (top) return 12;
        if (bottom) return 15;
    }
    if (buttonAt(client.right, point)) |button| return hitCode(button);
    if (point.y < uiScaled(8)) return 2;
    return 1;
}

fn hover(hwnd: w.HANDLE, button: ?Button) void {
    if (button == hovered) return;
    hovered = button;
    var client: w.RECT = undefined;
    _ = w.GetClientRect(hwnd, &client);
    const band = controlsRect(client.right);
    _ = w.InvalidateRect(hwnd, &band, 0);
}

pub fn handle(hwnd: w.HANDLE, msg: w.UINT, wp: w.WPARAM, lp: w.LPARAM) ?w.LRESULT {
    switch (msg) {
        0x0083 => {
            if (lp == 0) return 0;
            const client: *w.RECT = @ptrFromInt(@as(usize, @bitCast(lp)));
            const top = client.top;
            _ = w.DefWindowProcW(hwnd, msg, wp, lp);
            client.top = top;
            if (w.IsZoomed(hwnd) != 0) {
                var monitor = std.mem.zeroes(w.MONITORINFO);
                monitor.cbSize = @sizeOf(w.MONITORINFO);
                if (w.GetMonitorInfoW(w.MonitorFromWindow(hwnd, w.MONITOR_DEFAULTTONEAREST), &monitor) != 0) {
                    client.left = @max(client.left, monitor.rcWork.left);
                    client.top = @max(client.top, monitor.rcWork.top);
                    client.right = @min(client.right, monitor.rcWork.right);
                    client.bottom = @min(client.bottom, monitor.rcWork.bottom);
                }
            }
            return 0;
        },
        w.WM_NCHITTEST => {
            var point = pointFromMessage(lp);
            _ = w.ScreenToClient(hwnd, &point);
            var client: w.RECT = undefined;
            _ = w.GetClientRect(hwnd, &client);
            const border = @max(1, @divTrunc(@as(i32, @intCast(w.GetDpiForWindow(hwnd))) * 4, 96));
            return hitTest(client, point, w.IsZoomed(hwnd) != 0, border);
        },
        w.WM_NCLBUTTONDOWN => {
            if (wp != 8 and wp != 9 and wp != 20) return null;
            @import("focus.zig").cancelShellRefocus(hwnd);
            _ = @import("focus.zig").SetForegroundWindow(hwnd);
            pressed = switch (wp) {
                8 => .minimize,
                9 => .maximize,
                else => .close,
            };
            hover(hwnd, pressed);
            _ = w.SetCapture(hwnd);
            return 0;
        },
        w.WM_LBUTTONUP => {
            const button = pressed orelse return null;
            pressed = null;
            _ = w.ReleaseCapture();
            var client: w.RECT = undefined;
            _ = w.GetClientRect(hwnd, &client);
            if (buttonAt(client.right, pointFromMessage(lp)) == button) {
                const command: w.WPARAM = switch (button) {
                    .minimize => 0xF020,
                    .maximize => if (w.IsZoomed(hwnd) != 0) 0xF120 else w.SC_MAXIMIZE,
                    .close => 0xF060,
                };
                _ = @import("focus.zig").PostMessageW(hwnd, w.WM_SYSCOMMAND, command, 0);
            }
            hover(hwnd, null);
            return 0;
        },
        w.WM_MOUSEMOVE, 0x00A0 => {
            var point = pointFromMessage(lp);
            if (msg == 0x00A0) _ = w.ScreenToClient(hwnd, &point);
            var client: w.RECT = undefined;
            _ = w.GetClientRect(hwnd, &client);
            hover(hwnd, buttonAt(client.right, point));
            if (hovered != null) {
                var tracking = w.TRACKMOUSEEVENT{ .cbSize = @sizeOf(w.TRACKMOUSEEVENT), .dwFlags = 2 | @as(u32, if (msg == 0x00A0) 16 else 0), .hwndTrack = hwnd, .dwHoverTime = 0 };
                _ = w.TrackMouseEvent(&tracking);
            }
        },
        0x02A2, 0x02A3 => hover(hwnd, null),
        w.WM_CANCELMODE, 0x0215 => {
            pressed = null;
            hover(hwnd, null);
        },
        else => {},
    }
    return null;
}

pub fn paint(hwnd: w.HANDLE, dc: w.HANDLE) void {
    var client: w.RECT = undefined;
    _ = w.GetClientRect(hwnd, &client);
    const band = controlsRect(client.right);
    const background = w.CreateSolidBrush(@import("themes.zig").themeConsoleBg());
    _ = w.FillRect(dc, &band, background);
    _ = w.DeleteObject(background);
    const ink = @import("themes.zig").customColorOr("subtitle", if (@import("app_state.zig").g_light_theme) RGB(100, 100, 100) else RGB(160, 160, 160));
    const pen = w.CreatePen(0, @max(1, uiScaled(1)), ink);
    const old = w.SelectObject(dc, pen);
    defer {
        _ = w.SelectObject(dc, old);
        _ = w.DeleteObject(pen);
    }
    inline for (std.meta.tags(Button)) |button| {
        const rc = buttonRect(client.right, button);
        if (hovered == button) {
            const brush = w.CreateSolidBrush(if (@import("app_state.zig").g_light_theme) RGB(225, 225, 225) else RGB(48, 48, 48));
            _ = w.FillRect(dc, &rc, brush);
            _ = w.DeleteObject(brush);
        }
        const x = @divTrunc(rc.left + rc.right, 2);
        const y = @divTrunc(rc.top + rc.bottom, 2);
        const half = uiScaled(5);
        switch (button) {
            .minimize => {
                _ = w.MoveToEx(dc, x - half, y, null);
                _ = w.LineTo(dc, x + half, y);
            },
            .maximize => {
                const offset = if (w.IsZoomed(hwnd) != 0) uiScaled(2) else 0;
                _ = w.MoveToEx(dc, x - half + offset, y - half, null);
                _ = w.LineTo(dc, x + half, y - half);
                _ = w.LineTo(dc, x + half, y + half - offset);
                if (offset > 0) {
                    _ = w.MoveToEx(dc, x - half, y - half + offset, null);
                    _ = w.LineTo(dc, x + half - offset, y - half + offset);
                    _ = w.LineTo(dc, x + half - offset, y + half);
                }
                _ = w.LineTo(dc, x - half, y + half);
                _ = w.LineTo(dc, x - half, y - half + offset);
            },
            .close => {
                _ = w.MoveToEx(dc, x - half, y - half, null);
                _ = w.LineTo(dc, x + half, y + half);
                _ = w.MoveToEx(dc, x + half, y - half, null);
                _ = w.LineTo(dc, x - half, y + half);
            },
        }
    }
}

test "custom frame retains resize corners, native window-button hits and a thin drag strip" {
    const saved = @import("app_state.zig").g_ui_scale;
    defer @import("app_state.zig").g_ui_scale = saved;
    @import("app_state.zig").g_ui_scale = 100;
    const rc = w.RECT{ .left = 0, .top = 0, .right = 1000, .bottom = 700 };
    try std.testing.expectEqual(@as(w.LRESULT, 13), hitTest(rc, .{ .x = 0, .y = 0 }, false, 4));
    try std.testing.expectEqual(@as(w.LRESULT, 11), hitTest(rc, .{ .x = 999, .y = 300 }, false, 4));
    try std.testing.expectEqual(@as(w.LRESULT, 2), hitTest(rc, .{ .x = 500, .y = 6 }, false, 4));
    inline for (std.meta.tags(Button)) |button| {
        const r = buttonRect(rc.right, button);
        const point = w.POINT{ .x = @divTrunc(r.left + r.right, 2), .y = @divTrunc(r.top + r.bottom, 2) };
        try std.testing.expectEqual(hitCode(button), hitTest(rc, point, false, 4));
        try std.testing.expectEqual(hitCode(button), hitTest(rc, point, true, 4));
    }
    try std.testing.expectEqual(@as(w.LRESULT, 1), hitTest(rc, .{ .x = 500, .y = 300 }, false, 4));
}
