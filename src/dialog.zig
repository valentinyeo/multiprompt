const std = @import("std");
const w = @import("win32.zig");
const fonts = @import("fonts.zig");
const smooth = @import("smooth.zig");
const focus = @import("focus.zig");
const app_state = @import("app_state.zig");
const L = std.unicode.utf8ToUtf16LeStringLiteral;

extern "user32" fn EnableWindow(w.HANDLE, w.BOOL) callconv(w.WINAPI) w.BOOL;
extern "user32" fn IsWindowEnabled(w.HANDLE) callconv(w.WINAPI) w.BOOL;

pub const Button = struct {
    label: w.LPCWSTR,
    result: i32,
    destructive: bool = false,
};

const State = struct {
    title: [:0]const u16,
    text: [:0]const u16,
    buttons: []const Button,
    selected: usize,
    result: ?i32 = null,
    scale: i32 = 96,
    card: w.RECT = undefined,
    cells: [3]w.RECT = undefined,
    backdrop: ?Backdrop = null,

    fn key(self: *State, value: usize, shift: bool) void {
        switch (value) {
            0x1b => self.result = closeResult(self),
            0x0d, 0x20 => self.result = self.buttons[self.selected].result,
            0x09 => self.selected = if (shift) (self.selected + self.buttons.len - 1) % self.buttons.len else (self.selected + 1) % self.buttons.len,
            0x27, 0x28 => self.selected = (self.selected + 1) % self.buttons.len,
            0x25, 0x26 => self.selected = (self.selected + self.buttons.len - 1) % self.buttons.len,
            else => {},
        }
    }

    fn px(self: *const State, value: i32) i32 {
        return @divTrunc(value * self.scale, 96);
    }
};

const Backdrop = struct {
    dc: w.HANDLE,
    bitmap: w.HANDLE,
    old: w.HANDLE,

    fn release(self: Backdrop) void {
        _ = w.SelectObject(self.dc, self.old);
        _ = w.DeleteObject(self.bitmap);
        _ = w.DeleteDC(self.dc);
    }
};

fn capture(dc: w.HANDLE, x: i32, y: i32, width: i32, height: i32) ?Backdrop {
    if (width <= 0 or height <= 0) return null;
    const memory = w.CreateCompatibleDC(dc) orelse return null;
    const info = w.BITMAPINFO{ .header = .{ .width = width, .height = -height } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0) orelse {
        _ = w.DeleteDC(memory);
        return null;
    };
    const old = w.SelectObject(memory, bitmap);
    _ = w.BitBlt(memory, 0, 0, width, height, dc, x, y, 0x00CC0020);
    _ = w.GdiFlush();
    const pixels = @as([*]u32, @ptrCast(@alignCast(bits.?)))[0 .. @as(usize, @intCast(width)) * @as(usize, @intCast(height))];
    for (pixels) |*pixel| pixel.* = (pixel.* >> 1) & 0x007f7f7f;
    return .{ .dc = memory, .bitmap = bitmap, .old = old };
}

pub fn dim(dc: w.HANDLE, width: i32, height: i32) void {
    const backdrop = capture(dc, 0, 0, width, height) orelse return;
    defer backdrop.release();
    _ = w.BitBlt(dc, 0, 0, width, height, backdrop.dc, 0, 0, 0x00CC0020);
}

fn closeResult(state: *const State) i32 {
    for (state.buttons) |button| if (button.result == 2) return 2;
    for (state.buttons) |button| if (button.result == 7) return 7;
    return state.buttons[0].result;
}

fn paint(dc: w.HANDLE, state: *State, bounds: w.RECT) void {
    const light = app_state.g_light_theme;
    const panel: u32 = if (light) 0xfafafa else 0x181818;
    const outline: u32 = if (light) 0xdedede else 0x2e2e2e;
    const text: u32 = if (light) 0x202020 else 0xf2f2f2;
    const hint: u32 = if (light) 0x606060 else 0x8a8a8a;
    if (state.backdrop) |backdrop| {
        _ = w.BitBlt(dc, 0, 0, bounds.right, bounds.bottom, backdrop.dc, 0, 0, 0x00CC0020);
    } else {
        const brush = w.CreateSolidBrush(if (light) 0xeaeaea else 0x101010);
        _ = w.FillRect(dc, &bounds, brush);
        _ = w.DeleteObject(brush);
    }
    _ = w.SetBkMode(dc, w.TRANSPARENT);
    const title_font = fonts.create(-state.px(18), 0, 0, 0, 600, 0, 0, 0, 0, 0, 0, 5, 0, null);
    defer _ = w.DeleteObject(title_font);
    const body_font = fonts.create(-state.px(14), 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 5, 0, null);
    defer _ = w.DeleteObject(body_font);
    const old_font = w.SelectObject(dc, title_font);
    defer _ = w.SelectObject(dc, old_font);
    const width = @min(state.px(440), bounds.right - state.px(16));
    var title_rc = w.RECT{ .left = 0, .top = 0, .right = width - state.px(48), .bottom = 0 };
    _ = w.DrawTextW(dc, state.title.ptr, @intCast(state.title.len), &title_rc, w.DT_CALCRECT | w.DT_WORDBREAK | w.DT_NOPREFIX);
    const title_h = title_rc.bottom;
    _ = w.SelectObject(dc, body_font);
    var body = w.RECT{ .left = 0, .top = 0, .right = width - state.px(48), .bottom = 0 };
    _ = w.DrawTextW(dc, state.text.ptr, @intCast(state.text.len), &body, w.DT_CALCRECT | w.DT_WORDBREAK | w.DT_NOPREFIX);
    const body_h = body.bottom;
    const height = title_h + body_h + state.px(120);
    const left = @divFloor(bounds.right - width, 2);
    const top = @max(state.px(8), @divFloor(bounds.bottom - height, 2));
    state.card = .{ .left = left, .top = top, .right = left + width, .bottom = top + height };
    smooth.fillRoundRect(dc, state.card, state.px(20), outline);
    var inner = state.card;
    inner.left += 1;
    inner.top += 1;
    inner.right -= 1;
    inner.bottom -= 1;
    smooth.fillRoundRect(dc, inner, state.px(20) - 1, panel);
    _ = w.SelectObject(dc, title_font);
    _ = w.SetTextColor(dc, text);
    title_rc = .{ .left = left + state.px(24), .top = top + state.px(24), .right = left + width - state.px(24), .bottom = top + state.px(24) + title_h };
    _ = w.DrawTextW(dc, state.title.ptr, @intCast(state.title.len), &title_rc, w.DT_WORDBREAK | w.DT_NOPREFIX);
    _ = w.SelectObject(dc, body_font);
    _ = w.SetTextColor(dc, hint);
    body = .{ .left = title_rc.left, .top = title_rc.bottom + state.px(8), .right = title_rc.right, .bottom = title_rc.bottom + state.px(8) + body_h };
    _ = w.DrawTextW(dc, state.text.ptr, @intCast(state.text.len), &body, w.DT_WORDBREAK | w.DT_NOPREFIX);
    var x = state.card.right - state.px(24);
    var i = state.buttons.len;
    while (i > 0) {
        i -= 1;
        const button = state.buttons[i];
        var measured = std.mem.zeroes(w.RECT);
        _ = w.DrawTextW(dc, button.label, -1, &measured, w.DT_CALCRECT | w.DT_SINGLELINE | w.DT_NOPREFIX);
        const button_width = @max(state.px(80), measured.right + state.px(32));
        const cell = w.RECT{ .left = x - button_width, .top = state.card.bottom - state.px(64), .right = x, .bottom = state.card.bottom - state.px(24) };
        state.cells[i] = cell;
        const primary = i == state.buttons.len - 1;
        const fill: u32 = if (button.destructive) (if (light) 0x2a30c6 else 0x828bf2) else if (primary) text else panel;
        smooth.fillRoundRect(dc, cell, state.px(40), if (i == state.selected) hint else outline);
        var face = cell;
        face.left += state.px(1);
        face.top += state.px(1);
        face.right -= state.px(1);
        face.bottom -= state.px(1);
        smooth.fillRoundRect(dc, face, state.px(40), fill);
        _ = w.SetTextColor(dc, if (primary or button.destructive) panel else text);
        var label = cell;
        _ = w.DrawTextW(dc, button.label, -1, &label, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_CENTER | w.DT_NOPREFIX);
        x -= button_width + state.px(8);
    }
}

fn wndProc(hwnd: w.HANDLE, msg: w.UINT, wp: w.WPARAM, lp: w.LPARAM) callconv(w.WINAPI) w.LRESULT {
    const data = w.GetWindowLongPtrW(hwnd, -21);
    const state: ?*State = if (data == 0) null else @ptrFromInt(@as(usize, @bitCast(data)));
    switch (msg) {
        w.WM_PAINT => {
            var ps: w.PAINTSTRUCT = undefined;
            const dc = w.BeginPaint(hwnd, &ps);
            defer _ = w.EndPaint(hwnd, &ps);
            if (state) |s| {
                var bounds: w.RECT = undefined;
                _ = w.GetClientRect(hwnd, &bounds);
                paint(dc, s, bounds);
            }
            return 0;
        },
        w.WM_LBUTTONUP => {
            const s = state orelse return 0;
            const x: i32 = @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp))))));
            const y: i32 = @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp)) >> 16))));
            for (s.buttons, 0..) |button, i| {
                const cell = s.cells[i];
                if (x >= cell.left and x < cell.right and y >= cell.top and y < cell.bottom) s.result = button.result;
            }
            return 0;
        },
        0x0010 => {
            if (state) |s| s.result = closeResult(s);
            return 0;
        },
        0x0014 => return 1,
        else => return w.DefWindowProcW(hwnd, msg, wp, lp),
    }
}

pub fn show(requested_owner: w.HANDLE, text: w.LPCWSTR, title: w.LPCWSTR, buttons: []const Button, selected: usize) i32 {
    if (buttons.len == 0 or buttons.len > 3) return 2;
    const owner = requested_owner orelse app_state.g_main_hwnd;
    _ = fonts.register();
    const class = w.WNDCLASSEXW{ .cbSize = @sizeOf(w.WNDCLASSEXW), .style = 0, .lpfnWndProc = wndProc, .cbClsExtra = 0, .cbWndExtra = 0, .hInstance = w.GetModuleHandleW(null), .hIcon = null, .hCursor = w.LoadCursorW(null, @ptrFromInt(32512)), .hbrBackground = null, .lpszMenuName = null, .lpszClassName = L("MultiPromptDialog"), .hIconSm = null };
    _ = w.RegisterClassExW(&class);
    var bounds = w.RECT{ .left = 0, .top = 0, .right = w.GetSystemMetrics(0), .bottom = w.GetSystemMetrics(1) };
    var state = State{ .title = std.mem.span(title), .text = std.mem.span(text), .buttons = buttons, .selected = @min(selected, buttons.len - 1) };
    if (owner != null) {
        state.scale = @intCast(@max(96, w.GetDpiForWindow(owner)));
        _ = w.GetClientRect(owner, &bounds);
        var point = w.POINT{ .x = 0, .y = 0 };
        _ = w.ClientToScreen(owner, &point);
        bounds.right += point.x;
        bounds.bottom += point.y;
        bounds.left = point.x;
        bounds.top = point.y;
    } else {
        const x = @divFloor(bounds.right - 488, 2);
        const y = @divFloor(bounds.bottom - 360, 2);
        bounds = .{ .left = x, .top = y, .right = x + 488, .bottom = y + 360 };
    }
    const width = bounds.right - bounds.left;
    const height = bounds.bottom - bounds.top;
    if (owner != null) {
        const screen = w.GetDC(null);
        state.backdrop = capture(screen, bounds.left, bounds.top, width, height);
        _ = w.ReleaseDC(null, screen);
    }
    defer if (state.backdrop) |backdrop| backdrop.release();
    const hwnd = w.CreateWindowExW(0x00000080, L("MultiPromptDialog"), title, w.WS_POPUP, bounds.left, bounds.top, width, height, owner, null, w.GetModuleHandleW(null), null) orelse return closeResult(&state);
    defer _ = w.DestroyWindow(hwnd);
    _ = w.SetWindowLongPtrW(hwnd, -21, @bitCast(@intFromPtr(&state)));
    const enabled = owner != null and IsWindowEnabled(owner) != 0;
    if (enabled) _ = EnableWindow(owner, 0);
    defer if (enabled) {
        _ = EnableWindow(owner, 1);
        _ = focus.SetForegroundWindow(owner);
    };
    _ = focus.ShowWindow(hwnd, 5);
    _ = focus.SetForegroundWindow(hwnd);
    _ = focus.SetFocus(hwnd);
    _ = w.UpdateWindow(hwnd);
    var message: w.MSG = undefined;
    while (state.result == null) {
        const got = w.GetMessageW(&message, null, 0, 0);
        if (got <= 0) {
            if (got == 0) w.PostQuitMessage(@intCast(message.wParam));
            break;
        }
        if (message.hwnd == hwnd and message.message == w.WM_KEYDOWN) {
            state.key(message.wParam, w.GetAsyncKeyState(0x10) < 0);
            _ = w.InvalidateRect(hwnd, null, 0);
            continue;
        }
        _ = w.TranslateMessage(&message);
        _ = w.DispatchMessageW(&message);
    }
    return state.result orelse closeResult(&state);
}

pub fn messageBox(owner: w.HANDLE, text: w.LPCWSTR, title: w.LPCWSTR, flags: w.UINT) i32 {
    const buttons: []const Button = switch (flags & 0xf) {
        1 => &.{ .{ .label = L("Cancel"), .result = 2 }, .{ .label = L("OK"), .result = 1 } },
        3 => &.{ .{ .label = L("Cancel"), .result = 2 }, .{ .label = L("No"), .result = 7 }, .{ .label = L("Yes"), .result = 6 } },
        4 => &.{ .{ .label = L("No"), .result = 7 }, .{ .label = L("Yes"), .result = 6 } },
        else => &.{.{ .label = L("OK"), .result = 1 }},
    };
    const index: usize = if ((flags & 0x100) != 0) 0 else buttons.len - 1;
    return show(owner, text, title, buttons, index);
}

test "IGSH-1061 dialog uses native approved pixels and keeps click and keyboard results" {
    const saved_light = app_state.g_light_theme;
    defer app_state.g_light_theme = saved_light;
    _ = fonts.register();
    const dc = w.CreateCompatibleDC(null) orelse return error.TestUnexpectedResult;
    defer _ = w.DeleteDC(dc);
    const width = 700;
    const height = 360;
    const info = w.BITMAPINFO{ .header = .{ .width = width, .height = -height } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0) orelse return error.TestUnexpectedResult;
    defer _ = w.DeleteObject(bitmap);
    const old = w.SelectObject(dc, bitmap);
    defer _ = w.SelectObject(dc, old);
    const owner = w.CreateWindowExW(0, L("STATIC"), L("IGSH-1061 isolated proof"), w.WS_POPUP, 0, 0, width, height, null, null, null, null) orelse return error.TestUnexpectedResult;
    defer _ = w.DestroyWindow(owner);
    var state = State{ .title = L("Remove server 2?"), .text = L("It disappears from your account on every device. Sessions on it keep running."), .buttons = &.{
        .{ .label = L("Cancel"), .result = 7 },
        .{ .label = L("Remove"), .result = 6, .destructive = true },
    }, .selected = 0 };
    _ = w.SetWindowLongPtrW(owner, -21, @bitCast(@intFromPtr(&state)));
    for ([_]bool{ false, true }) |light| {
        app_state.g_light_theme = light;
        paint(dc, &state, .{ .left = 0, .top = 0, .right = width, .bottom = height });
        _ = w.GdiFlush();
        const center = @divTrunc(state.card.left + state.card.right, 2);
        try std.testing.expectEqual(@as(u32, if (light) 0xfafafa else 0x181818), w.GetPixel(dc, center, state.card.top + 8) & 0xffffff);
        try std.testing.expectEqual(@as(i32, 440), state.card.right - state.card.left);
        const panel: u32 = if (light) 0xfafafa else 0x181818;
        try std.testing.expectEqual(panel, w.GetPixel(dc, state.card.left + 10, state.card.top + 5) & 0xffffff);
        const card_height = state.card.bottom - state.card.top;
        state.title = L("Server");
        paint(dc, &state, .{ .left = 0, .top = 0, .right = width, .bottom = height });
        try std.testing.expectEqual(card_height, state.card.bottom - state.card.top);
        state.title = L("Remove server 2?");
        paint(dc, &state, .{ .left = 0, .top = 0, .right = width, .bottom = height });
        const remove = state.cells[1];
        try std.testing.expectEqual(@as(u32, if (light) 0x2a30c6 else 0x828bf2), w.GetPixel(dc, remove.left + 24, remove.top + 8) & 0xffffff);
        try std.testing.expect((w.GetPixel(dc, state.card.left, state.card.top) & 0xffffff) != (w.GetPixel(dc, center, state.card.top + 8) & 0xffffff));
        const bytes = @as([*]u8, @ptrCast(bits.?))[0 .. width * height * 4];
        const bmp = try std.testing.allocator.alloc(u8, 54 + bytes.len);
        defer std.testing.allocator.free(bmp);
        @memset(bmp[0..54], 0);
        @memcpy(bmp[0..2], "BM");
        std.mem.writeInt(u32, bmp[2..6], @intCast(bmp.len), .little);
        std.mem.writeInt(u32, bmp[10..14], 54, .little);
        @memcpy(bmp[14..54], std.mem.asBytes(&info.header));
        @memcpy(bmp[54..], bytes);
        try std.testing.expect(@import("file_io.zig").writeFileAtomicW(if (light) "dialog-design-light.bmp" else "dialog-design-dark.bmp", bmp));
    }
    state.key(0x0d, false);
    try std.testing.expectEqual(@as(?i32, 7), state.result);
    state.result = null;
    state.key(0x09, true);
    try std.testing.expectEqual(@as(usize, 1), state.selected);
    state.key(0x0d, false);
    try std.testing.expectEqual(@as(?i32, 6), state.result);
    state.result = null;
    state.key(0x1b, false);
    try std.testing.expectEqual(@as(?i32, 7), state.result);
    state.result = null;
    const remove = state.cells[1];
    const x = @divTrunc(remove.left + remove.right, 2);
    const y = @divTrunc(remove.top + remove.bottom, 2);
    _ = wndProc(owner, w.WM_LBUTTONUP, 0, @intCast((y << 16) | x));
    try std.testing.expectEqual(@as(?i32, 6), state.result);
}
