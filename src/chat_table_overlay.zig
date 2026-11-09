const std = @import("std");
const w = @import("win32.zig");
const app_state = @import("app_state.zig");
const dialog = @import("dialog.zig");
const focus = @import("focus.zig");
const chat_markdown = @import("chat_markdown.zig");
const expand = @import("chat_table_expand.zig");
const render = @import("chat_render.zig");
const uiScaled = @import("drawing.zig").uiScaled;
const debugLog = @import("diagnostics.zig").debugLog;
const L = std.unicode.utf8ToUtf16LeStringLiteral;

extern "user32" fn EnableWindow(w.HANDLE, w.BOOL) callconv(w.WINAPI) w.BOOL;

const Overlay = struct {
    text: []const u16,
    cache: chat_markdown.TableCache = .{},
    content: expand.Size = .{ .w = 1, .h = 1 },
    geometry: expand.Geometry = std.mem.zeroes(expand.Geometry),
    scroll: expand.Scroll = .{},
    backdrop: ?dialog.Backdrop = null,
    close_hot: bool = false,
    done: bool = false,

    fn view(self: *const Overlay) expand.Size {
        return .{ .w = self.geometry.body.right - self.geometry.body.left, .h = self.geometry.body.bottom - self.geometry.body.top };
    }

    fn apply(self: *Overlay, hwnd: w.HANDLE, command: expand.Command) void {
        switch (command) {
            .none => {},
            .close => self.done = true,
            .scroll => |delta| if (self.scroll.by(self.content, self.view(), delta.dx, delta.dy)) {
                _ = w.InvalidateRect(hwnd, null, 0);
            },
        }
    }

    fn measure(self: *Overlay, hwnd: w.HANDLE) void {
        var client: w.RECT = undefined;
        _ = w.GetClientRect(hwnd, &client);
        const bounds = expand.Rect{ .left = client.left, .top = client.top, .right = client.right, .bottom = client.bottom };
        const spacing = expand.Spacing{ .pad = uiScaled(app_state.CHAT_CODE_PAD), .margin = uiScaled(24), .close = uiScaled(28) };
        const dc = w.GetDC(hwnd) orelse return;
        defer _ = w.ReleaseDC(hwnd, dc);
        self.content = render.chatExpandedTableSize(dc, &self.cache, self.text, expand.bodyLimit(bounds, spacing).w);
        self.geometry = expand.place(bounds, spacing, self.content);
        _ = self.scroll.by(self.content, self.view(), 0, 0);
        var log: [160]u8 = undefined;
        debugLog(std.fmt.bufPrint(&log, "CHAT_TABLE_EXPAND open card_w={d} content_w={d} view_w={d} content_h={d} view_h={d}", .{ self.geometry.card.right - self.geometry.card.left, self.content.w, self.view().w, self.content.h, self.view().h }) catch "CHAT_TABLE_EXPAND open");
    }

    fn paint(self: *Overlay, dc: w.HANDLE, bounds: w.RECT) void {
        const width = bounds.right - bounds.left;
        const height = bounds.bottom - bounds.top;
        if (width <= 0 or height <= 0) return;
        const memory = w.CreateCompatibleDC(dc) orelse return;
        defer _ = w.DeleteDC(memory);
        const bitmap = w.CreateCompatibleBitmap(dc, width, height) orelse return;
        defer _ = w.DeleteObject(bitmap);
        const old = w.SelectObject(memory, bitmap);
        defer _ = w.SelectObject(memory, old);
        if (self.backdrop) |backdrop| {
            _ = w.BitBlt(memory, 0, 0, width, height, backdrop.dc, 0, 0, w.GDI_SRCCOPY);
        } else {
            const brush = w.CreateSolidBrush(if (app_state.g_light_theme) 0xeaeaea else 0x101010);
            defer _ = w.DeleteObject(brush);
            _ = w.FillRect(memory, &bounds, brush);
        }
        render.chatPaintExpandedTable(memory, &self.cache, self.text, self.geometry, self.scroll, self.close_hot);
        _ = w.BitBlt(dc, 0, 0, width, height, memory, 0, 0, w.GDI_SRCCOPY);
    }
};

var window: w.HANDLE = null;

pub fn ownsForeground() bool {
    return window != null and w.GetForegroundWindow() == window;
}

fn pointX(lp: w.LPARAM) i32 {
    return @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp))))));
}

fn pointY(lp: w.LPARAM) i32 {
    return @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp)) >> 16))));
}

fn wndProc(hwnd: w.HANDLE, msg: w.UINT, wp: w.WPARAM, lp: w.LPARAM) callconv(w.WINAPI) w.LRESULT {
    const data = w.GetWindowLongPtrW(hwnd, -21);
    const state: ?*Overlay = if (data == 0) null else @ptrFromInt(@as(usize, @bitCast(data)));
    switch (msg) {
        w.WM_PAINT => {
            var ps: w.PAINTSTRUCT = undefined;
            const dc = w.BeginPaint(hwnd, &ps);
            defer _ = w.EndPaint(hwnd, &ps);
            if (state) |s| {
                var bounds: w.RECT = undefined;
                _ = w.GetClientRect(hwnd, &bounds);
                s.paint(dc, bounds);
            }
            return 0;
        },
        w.WM_LBUTTONDOWN => {
            if (state) |s| s.apply(hwnd, expand.click(s.geometry, pointX(lp), pointY(lp)));
            return 0;
        },
        w.WM_MOUSEMOVE => {
            if (state) |s| {
                const hot = s.geometry.hit(pointX(lp), pointY(lp)) == .close;
                if (hot != s.close_hot) {
                    s.close_hot = hot;
                    _ = w.InvalidateRect(hwnd, null, 0);
                }
            }
            return 0;
        },
        w.WM_MOUSEWHEEL, w.WM_MOUSEHWHEEL => {
            const delta: i16 = @bitCast(@as(u16, @truncate(wp >> 16)));
            if (state) |s| s.apply(hwnd, expand.wheel(delta, uiScaled(54), msg == w.WM_MOUSEHWHEEL, (wp & 0x0004) != 0));
            return 0;
        },
        w.WM_SETCURSOR => {
            if (state) |s| if (s.close_hot) {
                _ = w.SetCursor(w.LoadCursorW(null, @ptrFromInt(32649)));
                return 1;
            };
            return w.DefWindowProcW(hwnd, msg, wp, lp);
        },
        0x0010 => {
            if (state) |s| s.done = true;
            return 0;
        },
        0x0014 => return 1,
        else => return w.DefWindowProcW(hwnd, msg, wp, lp),
    }
}

pub fn show(text: []const u16) void {
    if (window != null) return;
    const owner = app_state.g_main_hwnd orelse return;
    const copy = std.heap.page_allocator.dupe(u16, text) catch return;
    defer std.heap.page_allocator.free(copy);
    var state = Overlay{ .text = copy };
    defer state.cache.deinit(std.heap.page_allocator);
    const class = w.WNDCLASSEXW{ .cbSize = @sizeOf(w.WNDCLASSEXW), .style = 0, .lpfnWndProc = wndProc, .cbClsExtra = 0, .cbWndExtra = 0, .hInstance = w.GetModuleHandleW(null), .hIcon = null, .hCursor = w.LoadCursorW(null, @ptrFromInt(32512)), .hbrBackground = null, .lpszMenuName = null, .lpszClassName = L("MultiPromptTableOverlay"), .hIconSm = null };
    _ = w.RegisterClassExW(&class);
    var bounds: w.RECT = undefined;
    _ = w.GetClientRect(owner, &bounds);
    var origin = w.POINT{ .x = 0, .y = 0 };
    _ = w.ClientToScreen(owner, &origin);
    const width = bounds.right - bounds.left;
    const height = bounds.bottom - bounds.top;
    if (width <= 0 or height <= 0) return;
    _ = w.RedrawWindow(owner, null, null, 0x0001 | 0x0080 | 0x0100);
    const screen = w.GetDC(null);
    state.backdrop = dialog.capture(screen, origin.x, origin.y, width, height);
    _ = w.ReleaseDC(null, screen);
    defer if (state.backdrop) |backdrop| backdrop.release();
    const hwnd = w.CreateWindowExW(0x00000080, L("MultiPromptTableOverlay"), L("Table"), w.WS_POPUP, origin.x, origin.y, width, height, owner, null, w.GetModuleHandleW(null), null) orelse return;
    window = hwnd;
    defer {
        window = null;
        _ = w.DestroyWindow(hwnd);
    }
    _ = w.SetWindowLongPtrW(hwnd, -21, @bitCast(@intFromPtr(&state)));
    state.measure(hwnd);
    _ = EnableWindow(owner, 0);
    defer {
        _ = EnableWindow(owner, 1);
        _ = focus.SetForegroundWindow(owner);
        if (@import("chat_composer.zig").chatComposerFocusAllowed()) _ = focus.SetFocus(app_state.g_chat_composer_hwnd);
        debugLog("CHAT_TABLE_EXPAND closed");
    }
    _ = focus.ShowWindow(hwnd, 5);
    _ = focus.SetForegroundWindow(hwnd);
    _ = focus.SetFocus(hwnd);
    _ = w.UpdateWindow(hwnd);
    var message: w.MSG = undefined;
    while (!state.done) {
        const got = w.GetMessageW(&message, null, 0, 0);
        if (got <= 0) {
            if (got == 0) w.PostQuitMessage(@intCast(message.wParam));
            break;
        }
        if (message.hwnd == hwnd and message.message == w.WM_KEYDOWN) {
            state.apply(hwnd, expand.key(message.wParam, uiScaled(54), state.view()));
            continue;
        }
        _ = w.TranslateMessage(&message);
        _ = w.DispatchMessageW(&message);
    }
}
