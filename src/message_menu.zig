const std = @import("std");
const w = @import("win32.zig");
const drawing = @import("drawing.zig");
const fonts = @import("fonts.zig");
const tokens = @import("design_tokens.zig");
const Item = fonts.MessageMenuItem;
const L = std.unicode.utf8ToUtf16LeStringLiteral;
const scaled = drawing.uiScaled;

pub const capacity = 11;

pub const Geometry = struct {
    panel: w.RECT,
    cells: [capacity]w.RECT = @splat(std.mem.zeroes(w.RECT)),
    divider: ?i32 = null,
    count: usize,
};

pub fn geometry(items: []const Item) Geometry {
    const pad = scaled(8);
    const width = scaled(232);
    var g: Geometry = .{ .panel = .{ .left = 0, .top = 0, .right = width, .bottom = 0 }, .count = items.len };
    if (items.len > capacity) {
        g.count = 0;
        return g;
    }
    var y = pad;
    var reaction: i32 = 0;
    var reaction_top: i32 = 0;
    for (items, 0..) |item, i| {
        if (@intFromEnum(item) >= 8 and @intFromEnum(item) <= 10) {
            if (reaction == 0) reaction_top = y;
            g.cells[i] = .{ .left = pad + reaction * scaled(42), .top = reaction_top, .right = pad + (reaction + 1) * scaled(42), .bottom = reaction_top + scaled(38) };
            reaction += 1;
            y = reaction_top + scaled(47);
            g.divider = reaction_top + scaled(42);
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
    if (items.len > capacity) return;
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
            _ = @import("dwrite_text.zig").draw(dc, glyph, -1, &text, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_CENTER | w.DT_NOPREFIX);
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

const State = struct { items: []const Item, hover: ?usize = null, pointer: ?w.POINT = null, selected: u32 = 0, open: bool = true, light: bool };
var active: ?*State = null;
var registered = false;
var suppress_activation: w.WPARAM = 0;

pub fn activationCharMatches(key: w.WPARAM, char: w.WPARAM) bool {
    return char == key or (key >= 'A' and key <= 'Z' and char == key + ('a' - 'A'));
}

fn mnemonic(items: []const Item, key: w.WPARAM) ?usize {
    if (key < 'A' or key > 'Z') return null;
    for (items, 0..) |item, i| {
        const text = std.mem.span(item.text());
        var j: usize = 0;
        while (j + 1 < text.len) : (j += 1) {
            if (text[j] != '&') continue;
            j += 1;
            if (text[j] <= 127 and std.ascii.toUpper(@as(u8, @intCast(text[j]))) == key) return i;
        }
    }
    return null;
}

pub fn suppressComposerActivation(msg: w.UINT, wp: w.WPARAM, lp: w.LPARAM) bool {
    if (suppress_activation == 0) return false;
    if ((msg == w.WM_KEYUP or msg == 0x0105) and wp == suppress_activation) {
        suppress_activation = 0;
        return true;
    }
    if ((msg == w.WM_KEYDOWN or msg == 0x0104) and wp == suppress_activation) {
        if ((lp & 0x40000000) != 0) return true;
        suppress_activation = 0;
        return false;
    }
    return (msg == 0x0102 or msg == 0x0106) and activationCharMatches(suppress_activation, wp);
}

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
            const point = w.POINT{ .x = startup.GET_X(lp), .y = startup.GET_Y(lp) };
            if (state.pointer) |previous| {
                if (std.meta.eql(previous, point)) return 0;
            }
            state.pointer = point;
            const next = hit(geometry(state.items), point.x, point.y);
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
        0x0205 => return 0,
        w.WM_RBUTTONDOWN, w.WM_MOUSEWHEEL, 0x0215, 0x001F, w.WM_DESTROY => {
            state.open = false;
            _ = @import("focus.zig").PostMessageW(hwnd, 0, 0, 0);
            return 0;
        },
        else => return w.DefWindowProcW(hwnd, msg, wp, lp),
    }
}

pub fn track(owner: w.HANDLE, anchor: w.RECT, items: []const Item, default_action: ?Item) u32 {
    if (active != null or items.len == 0 or items.len > capacity) return 0;
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
    if (default_action) |action| {
        for (items, 0..) |item, i| if (item == action) { state.hover = i; break; };
    }
    active = &state;
    defer active = null;
    const hwnd = w.CreateWindowExW(w.WS_EX_TOOLWINDOW | w.WS_EX_NOACTIVATE, L("MultiPromptMessageMenu"), L("Message actions"), w.WS_POPUP, left, top, g.panel.right, g.panel.bottom, owner, null, w.GetModuleHandleW(null), null) orelse return 0;
    defer _ = w.DestroyWindow(hwnd);
    const region = w.CreateRoundRectRgn(0, 0, g.panel.right + 1, g.panel.bottom + 1, scaled(32), scaled(32));
    if (region != null and w.SetWindowRgn(hwnd, region, 0) == 0) _ = w.DeleteObject(region);
    _ = @import("focus.zig").ShowWindow(hwnd, 4);
    _ = w.UpdateWindow(hwnd);
    var pointer: w.POINT = undefined;
    if (w.GetCursorPos(&pointer) != 0 and w.ScreenToClient(hwnd, &pointer) != 0) state.pointer = pointer;
    _ = w.SetCapture(hwnd);
    defer _ = w.ReleaseCapture();
    var message: w.MSG = undefined;
    const down = @as(i16, @bitCast(@as(u16, 0x8000)));
    var opening_enter_held = (w.GetAsyncKeyState(0x0D) & down) != 0;
    while (state.open) {
        const status = w.GetMessageW(&message, null, 0, 0);
        if (status <= 0) {
            if (status == 0) w.PostQuitMessage(@intCast(message.wParam));
            return 0;
        }
        if (message.message == w.WM_KEYUP and message.wParam == 0x0D) {
            opening_enter_held = false;
            continue;
        }
        if (message.message == w.WM_KEYDOWN or message.message == 0x0104) {
            if (message.wParam == 0x0D and (opening_enter_held or (message.lParam & 0x40000000) != 0)) continue;
            switch (message.wParam) {
                w.VK_ESCAPE => state.open = false,
                0x0D, 0x20 => {
                    if (state.hover) |index| {
                        state.selected = @intFromEnum(items[index]);
                        suppress_activation = message.wParam;
                    }
                    state.open = false;
                },
                0x25, 0x26, 0x27, 0x28 => {
                    const backwards = message.wParam == 0x25 or message.wParam == 0x26;
                    state.hover = if (state.hover) |index| (if (backwards) (index + items.len - 1) % items.len else (index + 1) % items.len) else if (backwards) items.len - 1 else 0;
                    _ = w.InvalidateRect(hwnd, null, 0);
                },
                else => {
                    const ctrl_down = (w.GetKeyState(0x11) & down) != 0;
                    if (!ctrl_down) {
                        if (mnemonic(items, message.wParam)) |index| {
                            if ((message.lParam & 0x40000000) == 0) {
                                state.selected = @intFromEnum(items[index]);
                                suppress_activation = message.wParam;
                                state.open = false;
                            }
                            continue;
                        }
                    }
                    state.open = false;
                    _ = w.TranslateMessage(&message);
                    _ = w.DispatchMessageW(&message);
                },
            }
            continue;
        }
        if (message.message == 0x0102 and message.wParam == 0x0D) continue;
        if (message.message == w.WM_ACTIVATEAPP and message.wParam == 0) state.open = false;
        _ = w.TranslateMessage(&message);
        _ = w.DispatchMessageW(&message);
    }
    if (state.selected != 0 and suppress_activation == 0 and (w.GetAsyncKeyState(0x0D) & down) != 0) suppress_activation = 0x0D;
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

test "IGSH-1019 stationary mouse messages preserve keyboard action selection" {
    const items = [_]Item{ .reaction_like, .reaction_dislike, .reaction_heart, .reply, .copy, .copy_request_id };
    var state: State = .{ .items = &items, .hover = 5, .pointer = .{ .x = 20, .y = 20 }, .light = false };
    active = &state;
    defer active = null;
    _ = wndProc(null, w.WM_MOUSEMOVE, 0, (20 << 16) | 20);
    try std.testing.expectEqual(@as(?usize, 5), state.hover);
    try std.testing.expect(state.open);
}

test "IGSH-832 maximum menu geometry remains bounded" {
    const items = [_]Item{ .add_to_chat, .reaction_like, .reaction_dislike, .reaction_heart, .reply, .copy, .copy_link, .send_again, .remove, .cancel_queued, .copy_request_id };
    const g = geometry(&items);
    try std.testing.expectEqual(@as(usize, capacity), g.count);
    for (g.cells[0..items.len], 0..) |rc, i| try std.testing.expectEqual(@as(?usize, i), hit(g, @divTrunc(rc.left + rc.right, 2), @divTrunc(rc.top + rc.bottom, 2)));
}

test "IGSH-832 menu mnemonics select only present actions" {
    const items = [_]Item{ .reply, .copy, .copy_link, .copy_request_id, .send_again, .remove, .cancel_queued };
    try std.testing.expectEqual(@as(?usize, 0), mnemonic(&items, 'R'));
    try std.testing.expectEqual(@as(?usize, 1), mnemonic(&items, 'C'));
    try std.testing.expectEqual(@as(?usize, 2), mnemonic(&items, 'L'));
    try std.testing.expectEqual(@as(?usize, 3), mnemonic(&items, 'I'));
    try std.testing.expectEqual(@as(?usize, 4), mnemonic(&items, 'S'));
    try std.testing.expectEqual(@as(?usize, 5), mnemonic(&items, 'M'));
    try std.testing.expectEqual(@as(?usize, 6), mnemonic(&items, 'N'));
    try std.testing.expectEqual(@as(?usize, null), mnemonic(&items, 'X'));
    try std.testing.expect(activationCharMatches('R', 'r'));
    try std.testing.expect(!activationCharMatches('R', 's'));
}
