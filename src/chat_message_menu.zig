const std = @import("std");
const w = @import("win32.zig");
const fonts = @import("fonts.zig");
const drawing = @import("smooth.zig");
const L = std.unicode.utf8ToUtf16LeStringLiteral;

pub const Action = enum(u32) { like = 8, dislike = 9, heart = 10, reply = 4, copy = 1, copy_request_id = 11 };
pub const actions = [_]Action{ .like, .dislike, .heart, .reply, .copy, .copy_request_id };
pub const width = 232;
pub const height = 162;

pub fn actionAt(x: i32, y: i32) ?Action {
    if (x < 8 or x >= width - 8 or y < 8) return null;
    if (y < 48) return if (x < 140 and @mod(x - 8, 44) < 40) actions[@intCast(@divTrunc(x - 8, 44))] else null;
    if (y < 52 or y >= 154) return null;
    return actions[3 + @as(usize, @intCast(@divTrunc(y - 52, 34)))];
}

pub fn completedPress(down: ?Action, up: ?Action) ?Action {
    return if (down != null and down == up) down else null;
}

const State = struct { chosen: u32 = 0, hover: ?Action = null, pressed: ?Action = null, done: bool = false, scale: i32 };
var active: ?*State = null;

fn scaled(value: i32) i32 {
    return @divTrunc(value * active.?.scale + 48, 96);
}

fn actionRect(action: Action) w.RECT {
    for (actions, 0..) |candidate, i| {
        if (candidate != action) continue;
        const top: i32 = if (i < 3) 8 else 52 + @as(i32, @intCast(i - 3)) * 34;
        const left: i32 = if (i < 3) 8 + @as(i32, @intCast(i)) * 44 else 8;
        return .{ .left = scaled(left), .top = scaled(top), .right = scaled(if (i < 3) left + 40 else width - 8), .bottom = scaled(top + (if (i < 3) @as(i32, 40) else 34)) };
    }
    unreachable;
}

fn paint(dc: w.HANDLE) void {
    const outer = w.RECT{ .left = 0, .top = 0, .right = scaled(width), .bottom = scaled(height) };
    drawing.fillRoundRect(dc, outer, scaled(16), 0x2e2e2e);
    const inner = w.RECT{ .left = scaled(1), .top = scaled(1), .right = scaled(width - 1), .bottom = scaled(height - 1) };
    drawing.fillRoundRect(dc, inner, scaled(15), 0x1f1f1f);
    const divider = w.RECT{ .left = scaled(8), .top = scaled(50), .right = scaled(width - 8), .bottom = scaled(51) };
    const brush = w.CreateSolidBrush(0x2a2a2a);
    _ = w.FillRect(dc, &divider, brush);
    _ = w.DeleteObject(brush);
    const text_font = fonts.chat(-scaled(14), false, false, false, .{});
    defer _ = w.DeleteObject(text_font);
    const emoji_font = fonts.emoji(-scaled(20));
    defer _ = w.DeleteObject(emoji_font);
    const icon_font = fonts.messageMenuIconFont();
    defer _ = w.DeleteObject(icon_font);
    const old = w.SelectObject(dc, text_font);
    defer _ = w.SelectObject(dc, old);
    _ = w.SetBkMode(dc, w.TRANSPARENT);
    for (actions, 0..) |action, i| {
        var rc = actionRect(action);
        if (active.?.hover == action) drawing.fillRoundRect(dc, rc, scaled(10), 0x353535);
        _ = w.SetTextColor(dc, 0xf2f2f2);
        if (i < 3) {
            _ = w.SelectObject(dc, emoji_font);
            const text = @as(@import("chat_reaction.zig").Emoji, @enumFromInt(i)).text();
            _ = w.DrawTextW(dc, text.ptr, @intCast(text.len), &rc, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_CENTER | w.DT_NOPREFIX);
        } else {
            var icon_rc = rc;
            icon_rc.left += scaled(10);
            icon_rc.right = icon_rc.left + scaled(16);
            _ = w.SelectObject(dc, icon_font);
            _ = w.SetTextColor(dc, 0x8a8a8a);
            const glyph = [_]u16{switch (action) {
                .reply => 0xe97a,
                .copy => 0xe8c8,
                .copy_request_id => 0xe943,
                else => unreachable,
            }};
            _ = w.DrawTextW(dc, &glyph, 1, &icon_rc, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_CENTER | w.DT_NOPREFIX);
            rc.left += scaled(36);
            _ = w.SelectObject(dc, text_font);
            _ = w.SetTextColor(dc, 0xf2f2f2);
            _ = w.DrawTextW(dc, switch (action) {
                .reply => L("Reply"),
                .copy => L("Copy"),
                .copy_request_id => L("Copy request ID"),
                else => unreachable,
            }, -1, &rc, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_NOPREFIX);
        }
    }
}

fn hit(lp: w.LPARAM) ?Action {
    const x: i32 = @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp))))));
    const y: i32 = @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp)) >> 16))));
    return actionAt(@divTrunc(x * 96, active.?.scale), @divTrunc(y * 96, active.?.scale));
}

fn proc(hwnd: w.HANDLE, msg: w.UINT, wp: w.WPARAM, lp: w.LPARAM) callconv(w.WINAPI) w.LRESULT {
    const state = active orelse return w.DefWindowProcW(hwnd, msg, wp, lp);
    switch (msg) {
        w.WM_ERASEBKGND => return 1,
        w.WM_PAINT => {
            var ps: w.PAINTSTRUCT = std.mem.zeroes(w.PAINTSTRUCT);
            const dc = w.BeginPaint(hwnd, &ps);
            defer _ = w.EndPaint(hwnd, &ps);
            if (dc != null) paint(dc);
            return 0;
        },
        w.WM_MOUSEMOVE => {
            const hover = hit(lp);
            if (state.hover != hover) {
                state.hover = hover;
                _ = w.InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        w.WM_LBUTTONDOWN, w.WM_RBUTTONDOWN => {
            state.pressed = if (msg == w.WM_LBUTTONDOWN) hit(lp) else null;
            if (hit(lp) == null) state.done = true;
            return 0;
        },
        w.WM_LBUTTONUP => {
            if (completedPress(state.pressed, hit(lp))) |action| {
                state.chosen = @intFromEnum(action);
                state.done = true;
            }
            state.pressed = null;
            return 0;
        },
        0x0215, 0x001f, 0x0010 => {
            state.done = true;
            return 0;
        },
        else => return w.DefWindowProcW(hwnd, msg, wp, lp),
    }
}

pub fn track(owner: w.HANDLE, anchor: w.POINT) u32 {
    if (active != null) return 0;
    const dpi = w.GetDpiForWindow(owner);
    var state = State{ .scale = @intCast(if (dpi == 0) 96 else dpi) };
    active = &state;
    defer active = null;
    const class = L("MultipromptMessageMenu");
    const instance = w.GetModuleHandleW(null);
    var wc = std.mem.zeroes(w.WNDCLASSEXW);
    wc.cbSize = @sizeOf(w.WNDCLASSEXW);
    wc.style = 0x20000;
    wc.lpfnWndProc = proc;
    wc.hInstance = instance;
    wc.hCursor = w.LoadCursorW(null, @ptrFromInt(32512));
    wc.lpszClassName = class;
    _ = w.RegisterClassExW(&wc);
    var point = anchor;
    var monitor = std.mem.zeroes(w.MONITORINFO);
    monitor.cbSize = @sizeOf(w.MONITORINFO);
    if (w.GetMonitorInfoW(w.MonitorFromPoint(point, 2), &monitor) != 0) {
        point.x = @max(monitor.rcWork.left, @min(point.x, monitor.rcWork.right - scaled(width)));
        point.y = @max(monitor.rcWork.top, @min(point.y, monitor.rcWork.bottom - scaled(height)));
    }
    const hwnd = w.CreateWindowExW(w.WS_EX_TOOLWINDOW, class, L("Message actions"), w.WS_POPUP, point.x, point.y, scaled(width), scaled(height), owner, null, instance, null) orelse return 0;
    defer _ = w.DestroyWindow(hwnd);
    const region = w.CreateRoundRectRgn(0, 0, scaled(width) + 1, scaled(height) + 1, scaled(32), scaled(32));
    if (w.SetWindowRgn(hwnd, region, 0) == 0) _ = w.DeleteObject(region);
    _ = @import("focus.zig").ShowWindow(hwnd, 4);
    _ = w.SetCapture(hwnd);
    defer _ = w.ReleaseCapture();
    var message: w.MSG = undefined;
    while (!state.done) {
        const result = w.GetMessageW(&message, null, 0, 0);
        if (result <= 0) {
            if (result == 0) w.PostQuitMessage(@intCast(message.wParam));
            break;
        }
        if (message.message == w.WM_KEYDOWN or message.message == 0x0104) {
            const key = message.wParam;
            if (key == 0x1b or message.message == 0x0104) break;
            if (key == 0x0d or key == 0x20) {
                state.chosen = @intFromEnum(state.hover orelse .like);
                break;
            }
            if (key == 0x25 or key == 0x26 or key == 0x27 or key == 0x28 or key == 9) {
                var index: usize = 0;
                if (state.hover) |selected| for (actions, 0..) |action, i| {
                    if (selected == action) {
                        index = i;
                        break;
                    }
                };
                state.hover = actions[if (state.hover == null) 0 else if (key == 0x25 or key == 0x26) (index + actions.len - 1) % actions.len else (index + 1) % actions.len];
                _ = w.InvalidateRect(hwnd, null, 0);
            }
            continue;
        }
        _ = w.TranslateMessage(&message);
        _ = w.DispatchMessageW(&message);
    }
    return state.chosen;
}
