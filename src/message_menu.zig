const std = @import("std");
const w = @import("win32.zig");
const drawing = @import("drawing.zig");
const fonts = @import("fonts.zig");
const tokens = @import("design_tokens.zig");
const Item = fonts.MessageMenuItem;
const L = std.unicode.utf8ToUtf16LeStringLiteral;
const scaled = drawing.uiScaled;

pub const Geometry = struct {
    panel: w.RECT,
    cells: [9]w.RECT = @splat(std.mem.zeroes(w.RECT)),
    divider: ?i32 = null,
    count: usize,
};

pub fn geometry(items: []const Item) Geometry {
    const pad = scaled(8);
    const width = scaled(232);
    var g: Geometry = .{ .panel = .{ .left = 0, .top = 0, .right = width, .bottom = 0 }, .count = items.len };
    var y = pad;
    var reaction: i32 = 0;
    for (items, 0..) |item, i| {
        if (@intFromEnum(item) >= 8 and @intFromEnum(item) <= 10) {
            g.cells[i] = .{ .left = pad + reaction * scaled(42), .top = pad, .right = pad + (reaction + 1) * scaled(42), .bottom = pad + scaled(38) };
            reaction += 1;
            y = pad + scaled(47);
            g.divider = pad + scaled(42);
        } else {
            g.cells[i] = .{ .left = pad, .top = y, .right = width - pad, .bottom = y + scaled(34) };
            y += scaled(34);
        }
    }
    g.panel.bottom = y + pad;
    return g;
}

pub fn hit(g: Geometry, x: i32, y: i32) ?usize {
    for (g.cells[0..g.count], 0..) |rc, i| {
        if (x >= rc.left and x < rc.right and y >= rc.top and y < rc.bottom) return i;
    }
    return null;
}

pub fn paint(dc: w.HANDLE, items: []const Item, hover: ?usize, light: bool) void {
    const g = geometry(items);
    const fill: u32 = if (light) 0xFAFAFA else tokens.ReaderControl;
    const outline: u32 = if (light) 0xDEDEDE else tokens.ReaderOutline;
    const hint: u32 = if (light) 0x696969 else tokens.ReaderHint;
    const round = @import("smooth.zig").fillRoundRect;
    const edge = @max(1, scaled(1));
    round(dc, g.panel, scaled(16), outline);
    round(dc, .{ .left = edge, .top = edge, .right = g.panel.right - edge, .bottom = g.panel.bottom - edge }, scaled(16) - edge, fill);
    const old_mode = w.SetBkMode(dc, w.TRANSPARENT);
    defer _ = w.SetBkMode(dc, old_mode);
    const text_font = fonts.create(-scaled(14), 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 5, 0, L(fonts.UI_FACE));
    defer _ = w.DeleteObject(text_font);
    const old_font = w.SelectObject(dc, text_font);
    defer _ = w.SelectObject(dc, old_font);
    const old_color = w.SetTextColor(dc, hint);
    defer _ = w.SetTextColor(dc, old_color);
    if (g.divider) |y| {
        var line = w.RECT{ .left = scaled(8), .top = y, .right = g.panel.right - scaled(8), .bottom = y + edge };
        const brush = w.CreateSolidBrush(if (light) outline else 0x2A2A2A);
        _ = w.FillRect(dc, &line, brush);
        _ = w.DeleteObject(brush);
    }
    const icons = fonts.messageMenuIconFont();
    defer _ = w.DeleteObject(icons);
    const emoji_font = fonts.emoji(-scaled(20));
    defer _ = w.DeleteObject(emoji_font);
    for (items, 0..) |item, i| {
        const cell = g.cells[i];
        if (hover == i) round(dc, cell, scaled(10), if (light) 0xE4E4E4 else tokens.ReaderRaised);
        var text = cell;
        _ = w.SetTextColor(dc, if (light) 0x1C1C1C else tokens.ReaderForeground);
        if (@intFromEnum(item) >= 8 and @intFromEnum(item) <= 10) {
            _ = w.SelectObject(dc, emoji_font);
            const glyph = switch (item) {
                .reaction_like => L("👍"),
                .reaction_dislike => L("👎"),
                else => L("❤️"),
            };
            _ = w.DrawTextW(dc, glyph, -1, &text, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_CENTER | w.DT_NOPREFIX);
        } else {
            _ = w.SelectObject(dc, text_font);
            text.left += scaled(34);
            _ = w.DrawTextW(dc, item.text(), -1, &text, w.DT_SINGLELINE | w.DT_VCENTER);
            _ = w.SelectObject(dc, icons);
            _ = w.SetTextColor(dc, hint);
            var icon = cell;
            icon.left += scaled(8);
            icon.right = icon.left + scaled(18);
            const glyph = [_]u16{item.glyph()};
            _ = w.DrawTextW(dc, &glyph, 1, &icon, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_CENTER | w.DT_NOPREFIX);
        }
    }
}

const State = struct { items: []const Item, hover: ?usize = null, selected: u32 = 0, open: bool = true, light: bool };
var active: ?*State = null;
var registered = false;

fn wndProc(hwnd: w.HANDLE, msg: w.UINT, wp: w.WPARAM, lp: w.LPARAM) callconv(w.WINAPI) w.LRESULT {
    const state = active orelse return w.DefWindowProcW(hwnd, msg, wp, lp);
    const startup = @import("startup.zig");
    switch (msg) {
        w.WM_ERASEBKGND => return 1,
        w.WM_PAINT => {
            var ps: w.PAINTSTRUCT = undefined;
            const dc = w.BeginPaint(hwnd, &ps);
            if (dc != null) paint(dc, state.items, state.hover, state.light);
            _ = w.EndPaint(hwnd, &ps);
            return 0;
        },
        w.WM_MOUSEMOVE => {
            const next = hit(geometry(state.items), startup.GET_X(lp), startup.GET_Y(lp));
            if (next != state.hover) {
                state.hover = next;
                _ = w.InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        w.WM_LBUTTONDOWN => {
            if (hit(geometry(state.items), startup.GET_X(lp), startup.GET_Y(lp))) |index| state.selected = @intFromEnum(state.items[index]);
            state.open = false;
            return 0;
        },
        w.WM_RBUTTONDOWN, w.WM_MOUSEWHEEL, 0x0215, 0x001F, w.WM_DESTROY => {
            state.open = false;
            return 0;
        },
        else => return w.DefWindowProcW(hwnd, msg, wp, lp),
    }
}

pub fn track(owner: w.HANDLE, anchor: w.RECT, items: []const Item) u32 {
    if (active != null or items.len == 0 or items.len > 9) return 0;
    if (!registered) {
        const wc = w.WNDCLASSEXW{ .cbSize = @sizeOf(w.WNDCLASSEXW), .style = 0x00020000, .lpfnWndProc = wndProc, .cbClsExtra = 0, .cbWndExtra = 0, .hInstance = w.GetModuleHandleW(null), .hIcon = null, .hCursor = w.LoadCursorW(null, @ptrFromInt(32512)), .hbrBackground = null, .lpszMenuName = null, .lpszClassName = L("MultiPromptMessageMenu"), .hIconSm = null };
        if (w.RegisterClassExW(&wc) == 0) return 0;
        registered = true;
    }
    const g = geometry(items);
    var monitor: w.MONITORINFO = .{ .cbSize = @sizeOf(w.MONITORINFO), .rcMonitor = undefined, .rcWork = undefined, .dwFlags = 0 };
    if (w.GetMonitorInfoW(w.MonitorFromRect(&anchor, 2), &monitor) == 0) return 0;
    const left = std.math.clamp(anchor.left, monitor.rcWork.left, @max(monitor.rcWork.left, monitor.rcWork.right - g.panel.right));
    const top = std.math.clamp(anchor.bottom + scaled(6), monitor.rcWork.top, @max(monitor.rcWork.top, monitor.rcWork.bottom - g.panel.bottom));
    var state: State = .{ .items = items, .light = @import("app_state.zig").g_light_theme };
    active = &state;
    defer active = null;
    const hwnd = w.CreateWindowExW(w.WS_EX_TOOLWINDOW | w.WS_EX_NOACTIVATE, L("MultiPromptMessageMenu"), L("Message actions"), w.WS_POPUP, left, top, g.panel.right, g.panel.bottom, owner, null, w.GetModuleHandleW(null), null) orelse return 0;
    defer _ = w.DestroyWindow(hwnd);
    const region = w.CreateRoundRectRgn(0, 0, g.panel.right + 1, g.panel.bottom + 1, scaled(32), scaled(32));
    if (region != null and w.SetWindowRgn(hwnd, region, 0) == 0) _ = w.DeleteObject(region);
    _ = w.ShowWindow(hwnd, 4);
    _ = w.UpdateWindow(hwnd);
    _ = w.SetCapture(hwnd);
    defer _ = w.ReleaseCapture();
    var message: w.MSG = undefined;
    while (state.open) {
        const status = w.GetMessageW(&message, null, 0, 0);
        if (status <= 0) {
            if (status == 0) w.PostQuitMessage(@intCast(message.wParam));
            return 0;
        }
        if (message.message == w.WM_KEYDOWN or message.message == 0x0104) {
            switch (message.wParam) {
                w.VK_ESCAPE => state.open = false,
                0x0D, 0x20 => {
                    if (state.hover) |index| state.selected = @intFromEnum(items[index]);
                    state.open = false;
                },
                0x25, 0x26, 0x27, 0x28 => {
                    const backwards = message.wParam == 0x25 or message.wParam == 0x26;
                    state.hover = if (state.hover) |index| (if (backwards) (index + items.len - 1) % items.len else (index + 1) % items.len) else if (backwards) items.len - 1 else 0;
                    _ = w.InvalidateRect(hwnd, null, 0);
                },
                else => state.open = false,
            }
            continue;
        }
        if (message.message == 0x0102 or message.message == w.WM_KEYUP) continue;
        if (message.message == w.WM_ACTIVATEAPP and message.wParam == 0) state.open = false;
        _ = w.TranslateMessage(&message);
        _ = w.DispatchMessageW(&message);
    }
    return state.selected;
}

test "IGSH-1019 reactions share a row above separate reply copy and identity hit areas" {
    const items = [_]Item{ .reaction_like, .reaction_dislike, .reaction_heart, .reply, .copy, .copy_request_id };
    const g = geometry(&items);
    try std.testing.expectEqual(scaled(232), g.panel.right);
    try std.testing.expectEqual(g.cells[0].top, g.cells[2].top);
    try std.testing.expect(g.cells[3].top > g.cells[2].bottom);
    for (g.cells[0..items.len], 0..) |rc, i| try std.testing.expectEqual(@as(?usize, i), hit(g, @divTrunc(rc.left + rc.right, 2), @divTrunc(rc.top + rc.bottom, 2)));
    try std.testing.expectEqual(@as(?usize, null), hit(g, -1, -1));
}
