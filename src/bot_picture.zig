const std = @import("std");
const w = @import("win32.zig");
const app = @import("app_state.zig");
const photo = @import("bot_photo.zig");
const transport = @import("chat_transport.zig");
const focus = @import("focus.zig");
const L = std.unicode.utf8ToUtf16LeStringLiteral;
const a = std.heap.page_allocator;
extern "user32" fn EnableWindow(w.HANDLE, w.BOOL) callconv(.winapi) w.BOOL;
extern "user32" fn IsDialogMessageW(w.HANDLE, *w.MSG) callconv(.winapi) w.BOOL;
extern "kernel32" fn GetTempPathW(u32, [*]u16) callconv(.winapi) u32;
extern "kernel32" fn GetTempFileNameW([*:0]const u16, [*:0]const u16, u32, [*]u16) callconv(.winapi) u32;

var window: w.HANDLE = null;

pub fn ownsForeground() bool {
    return window != null and w.GetForegroundWindow() == window;
}

const State = struct {
    phase: enum { description, busy, preview, failed } = .description,
    done: bool = false,
    hwnd: w.HANDLE = null,
    edit: w.HANDLE = null,
    generate: w.HANDLE = null,
    failure_label: w.HANDLE = null,
    keep: w.HANDLE = null,
    again: w.HANDLE = null,
    scale: i32 = 96,
    sid: u32,
    title_id: u32,
    digest: [32]u8,
    host: u8,
    channel: ?*transport.Channel = null,
    request: ?[]u8 = null,
    response: std.ArrayList(u8) = .empty,
    deadline: u64 = 0,
    image: ?photo.Preview = null,
    path: [260]u16 = @splat(0),
    failure: [256]u16 = @splat(0),
    brush: w.HANDLE = null,

    fn px(self: *const State, value: i32) i32 {
        return @divTrunc(value * self.scale, 96);
    }

    fn disconnect(self: *State) void {
        if (self.channel) |channel| transport.close(channel);
        self.channel = null;
        if (self.request) |request| a.free(request);
        self.request = null;
        self.response.clearAndFree(a);
    }

    fn discard(self: *State) void {
        if (self.image) |image| image.deinit();
        self.image = null;
        if (self.path[0] != 0) _ = w.DeleteFileW(@ptrCast(&self.path));
        self.path = @splat(0);
    }

    fn refresh(self: *State) void {
        _ = EnableWindow(self.edit, if (self.phase == .busy) 0 else 1);
        _ = focus.ShowWindow(self.generate, if (self.phase == .description or self.phase == .failed) 5 else 0);
        _ = focus.ShowWindow(self.keep, if (self.phase == .preview) 5 else 0);
        _ = focus.ShowWindow(self.again, if (self.phase == .preview) 5 else 0);
        _ = focus.ShowWindow(self.failure_label, if (self.phase == .failed) 5 else 0);
        _ = w.InvalidateRect(self.hwnd, null, 1);
    }

    fn fail(self: *State, text: []const u8) void {
        self.failure = @splat(0);
        _ = std.unicode.utf8ToUtf16Le(self.failure[0 .. self.failure.len - 1], text) catch 0;
        self.disconnect();
        self.phase = .failed;
        _ = w.SetWindowTextW(self.failure_label, @ptrCast(&self.failure));
        self.refresh();
        _ = focus.SetFocus(self.edit);
    }

    fn start(self: *State) void {
        if (self.phase == .busy) return;
        var wide: [2001]u16 = @splat(0);
        const count = w.GetWindowTextW(self.edit, &wide, wide.len);
        if (count <= 0) return;
        const description = std.unicode.utf16LeToUtf8Alloc(a, wide[0..@intCast(count)]) catch {
            self.fail("Could not read the description");
            return;
        };
        defer a.free(description);
        self.disconnect();
        self.discard();
        self.request = std.json.Stringify.valueAlloc(a, .{ .id = @as(u32, 1), .op = "bot_picture", .description = description }, .{}) catch {
            self.fail("Could not make the picture");
            return;
        };
        self.phase = .busy;
        self.deadline = w.GetTickCount64() + 25_000;
        self.refresh();
        self.poll();
    }

    fn accept(self: *State) void {
        if (self.phase != .preview) return;
        const index = @import("inbox.zig").findShellById(self.sid) orelse {
            self.fail("That bot is no longer open");
            return;
        };
        const current = photo.key(&app.shells[index]);
        if (!@import("bot_look.zig").eligible(index) or app.shells[index].title_id != self.title_id or current == null or !std.mem.eql(u8, &current.?, &self.digest)) {
            self.fail("That bot has changed. Open its look menu again");
            return;
        }
        if (!photo.import(self.digest, @ptrCast(&self.path))) {
            self.fail("Could not save the picture");
            return;
        }
        self.done = true;
    }

    fn load(self: *State, encoded: []const u8) bool {
        const size = std.base64.standard.Decoder.calcSizeForSlice(encoded) catch return false;
        if (size == 0 or size > 8 * 1024 * 1024) return false;
        const bytes = a.alloc(u8, size) catch return false;
        defer a.free(bytes);
        std.base64.standard.Decoder.decode(bytes, encoded) catch return false;
        var directory: [260]u16 = undefined;
        const len = GetTempPathW(directory.len, &directory);
        if (len == 0 or len >= directory.len or GetTempFileNameW(@ptrCast(&directory), L("mbp"), 0, &self.path) == 0) return false;
        const file = w.CreateFileW(@ptrCast(&self.path), w.GENERIC_WRITE, 0, null, w.OPEN_EXISTING, w.FILE_ATTRIBUTE_NORMAL, null);
        if (file == w.INVALID_HANDLE_VALUE_PTR) return false;
        var written: u32 = 0;
        const saved = w.WriteFile(file, bytes.ptr, @intCast(bytes.len), &written, null) != 0 and written == bytes.len;
        const closed = w.CloseHandle(file) != 0;
        if (!saved or !closed) return false;
        self.image = photo.Preview.open(@ptrCast(&self.path)) orelse return false;
        return true;
    }

    fn poll(self: *State) void {
        if (self.phase != .busy) return;
        if (w.GetTickCount64() >= self.deadline) {
            self.fail("Picture service took too long. Try again");
            return;
        }
        if (self.channel == null) {
            const channel = transport.open(self.host, false) orelse return;
            self.channel = channel;
            transport.notifyWindow(channel, self.hwnd, w.WM_APP_BOT_PICTURE_READY);
            if (!transport.write(channel, self.request.?)) {
                self.fail("Could not reach the picture service. Try again");
                return;
            }
        }
        var bytes: [65536]u8 = undefined;
        while (true) {
            const count = transport.read(self.channel.?, &bytes, false) orelse {
                self.fail("Could not reach the picture service. Try again");
                return;
            };
            if (count == 0) return;
            if (self.response.items.len + count > 12 * 1024 * 1024) {
                self.fail("Picture service returned an invalid picture");
                return;
            }
            self.response.appendSlice(a, bytes[0..count]) catch {
                self.fail("Could not open the picture");
                return;
            };
            const end = std.mem.indexOfScalar(u8, self.response.items, '\n') orelse continue;
            const Reply = struct { id: u32, result: ?struct { png: ?[]const u8 = null, @"error": ?[]const u8 = null } = null };
            const parsed = std.json.parseFromSlice(Reply, a, self.response.items[0..end], .{ .ignore_unknown_fields = true }) catch {
                self.fail("Picture service returned an invalid picture");
                return;
            };
            defer parsed.deinit();
            const result = if (parsed.value.id == 1) parsed.value.result else null;
            if (result) |value| {
                if (value.@"error") |failure| {
                    self.fail(failure);
                    return;
                }
                if (value.png) |png| {
                    if (self.load(png)) {
                        self.disconnect();
                        self.phase = .preview;
                        self.refresh();
                        _ = focus.SetFocus(self.keep);
                        return;
                    }
                }
            }
            self.fail("Picture service returned an invalid picture");
            return;
        }
    }
};

fn control(s: *State, class: w.LPCWSTR, label: w.LPCWSTR, id: usize, x: i32, y: i32, width: i32, height: i32, style: u32, font: w.HANDLE) w.HANDLE {
    const hwnd = w.CreateWindowExW(0, class, label, w.WS_CHILD | w.WS_VISIBLE | style, s.px(x), s.px(y), s.px(width), s.px(height), s.hwnd, @ptrFromInt(id), w.GetModuleHandleW(null), null);
    _ = w.SendMessageW(hwnd, 0x0030, @intFromPtr(font), 1);
    return hwnd;
}

fn paint(s: *State, dc: w.HANDLE) void {
    var bounds: w.RECT = undefined;
    _ = w.GetClientRect(s.hwnd, &bounds);
    _ = w.FillRect(dc, &bounds, s.brush);
    if (s.image) |image| image.draw(dc, .{ .left = s.px(120), .top = s.px(112), .right = s.px(312), .bottom = s.px(304) });
    if (s.phase == .busy) {
        const tick = w.GetTickCount64() / 240 % 3;
        for (0..3) |i| {
            const x = s.px(202 + @as(i32, @intCast(i)) * 12);
            @import("smooth.zig").fillEllipse(dc, .{ .left = x, .top = s.px(202), .right = x + s.px(5), .bottom = s.px(207) }, if (tick == i) (if (app.g_light_theme) 0x606060 else 0xaaaaaa) else (if (app.g_light_theme) 0xbbbbbb else 0x555555));
        }
    }

}

fn wndProc(hwnd: w.HANDLE, message: u32, wp: usize, lp: isize) callconv(.winapi) isize {
    const pointer = w.GetWindowLongPtrW(hwnd, -21);
    const s: ?*State = if (pointer == 0) null else @ptrFromInt(@as(usize, @bitCast(pointer)));
    switch (message) {
        w.WM_COMMAND => {
            const state = s orelse return 0;
            switch (wp & 0xffff) {
                1, 3 => state.start(),
                2 => state.done = true,
                4 => state.accept(),
                else => {},
            }
            return 0;
        },
        w.WM_APP_BOT_PICTURE_READY => {
            if (s) |state| state.poll();
            return 0;
        },
        w.WM_PAINT => {
            var ps: w.PAINTSTRUCT = undefined;
            const dc = w.BeginPaint(hwnd, &ps);
            defer _ = w.EndPaint(hwnd, &ps);
            if (s) |state| paint(state, dc);
            return 0;
        },
        w.WM_CTLCOLOREDIT, w.WM_CTLCOLORSTATIC => {
            const state = s orelse return 0;
            const dc: w.HANDLE = @ptrFromInt(wp);
            _ = w.SetTextColor(dc, if (app.g_light_theme) 0x202020 else 0xeeeeee);
            _ = w.SetBkColor(dc, if (app.g_light_theme) 0xfafafa else 0x181818);
            return @bitCast(@intFromPtr(state.brush));
        },
        0x0010 => {
            if (s) |state| state.done = true;
            return 0;
        },
        0x0014 => return 1,
        else => return w.DefWindowProcW(hwnd, message, wp, lp),
    }
}

pub fn show(owner: w.HANDLE, index: u32) void {
    if (window != null or !@import("bot_look.zig").eligible(index)) return;
    const shell = &app.shells[index];
    const digest = photo.ensureKey(index) orelse {
        @import("console.zig").showHeaderNoticeAscii("Could not save picture", 4000, true);
        return;
    };
    var s = State{ .sid = shell.shell_id, .title_id = shell.title_id, .digest = digest, .host = if (shell.kind == .tmux) shell.tmux_host else if (shell.kind == .vps2) 1 else 0 };
    s.scale = @intCast(@max(96, w.GetDpiForWindow(owner)));
    s.brush = w.CreateSolidBrush(if (app.g_light_theme) 0xfafafa else 0x181818);
    defer _ = w.DeleteObject(s.brush);
    const class = w.WNDCLASSEXW{ .cbSize = @sizeOf(w.WNDCLASSEXW), .style = 0, .lpfnWndProc = wndProc, .cbClsExtra = 0, .cbWndExtra = 0, .hInstance = w.GetModuleHandleW(null), .hIcon = null, .hCursor = w.LoadCursorW(null, @ptrFromInt(32512)), .hbrBackground = null, .lpszMenuName = null, .lpszClassName = L("MultiPromptBotPicture"), .hIconSm = null };
    _ = w.RegisterClassExW(&class);
    var bounds: w.RECT = undefined;
    _ = w.GetWindowRect(owner, &bounds);
    const width = s.px(432);
    const height = s.px(428);
    window = w.CreateWindowExW(0x00000001, L("MultiPromptBotPicture"), L("Generate bot picture"), w.WS_POPUP | w.WS_CAPTION | w.WS_SYSMENU | w.WS_CLIPCHILDREN, bounds.left + @divTrunc(bounds.right - bounds.left - width, 2), bounds.top + @divTrunc(bounds.bottom - bounds.top - height, 2), width, height, owner, null, w.GetModuleHandleW(null), null) orelse {
        @import("console.zig").showHeaderNoticeAscii("Could not open picture preview", 4000, true);
        return;
    };
    s.hwnd = window;
    defer {
        s.disconnect();
        s.discard();
        _ = w.DestroyWindow(window);
        window = null;
    }
    _ = w.SetWindowLongPtrW(window, -21, @bitCast(@intFromPtr(&s)));
    const font = @import("fonts.zig").create(-s.px(14), 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 5, 0, null);
    defer _ = w.DeleteObject(font);
    _ = control(&s, L("STATIC"), L("Describe your bot picture"), 10, 24, 16, 384, 24, 0, font);
    s.edit = control(&s, L("EDIT"), L(""), 11, 24, 48, 380, 32, w.WS_BORDER | w.WS_TABSTOP | 0x0080, font);
    _ = w.SendMessageW(s.edit, 0x00c5, 2000, 0);
    s.generate = control(&s, L("BUTTON"), L("Generate"), 1, 292, 332, 112, 32, w.WS_TABSTOP | 1, font);
    s.keep = control(&s, L("BUTTON"), L("Keep"), 4, 292, 332, 112, 32, w.WS_TABSTOP | 1, font);
    s.again = control(&s, L("BUTTON"), L("Try again"), 3, 160, 332, 112, 32, w.WS_TABSTOP, font);
    _ = control(&s, L("BUTTON"), L("Cancel"), 2, 24, 332, 112, 32, w.WS_TABSTOP, font);
    s.failure_label = control(&s, L("STATIC"), L(""), 12, 24, 150, 380, 130, 1, font);
    s.refresh();
    _ = EnableWindow(owner, 0);
    defer {
        _ = EnableWindow(owner, 1);
        _ = focus.SetForegroundWindow(owner);
        _ = focus.SetFocus(owner);
        _ = w.InvalidateRect(owner, null, 1);
    }
    _ = focus.ShowWindow(window, 5);
    _ = focus.SetForegroundWindow(window);
    _ = focus.SetFocus(s.edit);
    var message: w.MSG = undefined;
    while (!s.done) {
        const wait = w.MsgWaitForMultipleObjects(0, null, 0, if (s.phase == .busy) 80 else std.math.maxInt(u32), 0x04ff);
        if (wait == 0xffffffff) break;
        while (w.PeekMessageW(&message, null, 0, 0, 1) != 0) {
            if (message.message == 0x0012) {
                w.PostQuitMessage(@intCast(message.wParam));
                s.done = true;
                break;
            }
            if (message.message == w.WM_KEYDOWN and (message.hwnd == window or w.GetParent(message.hwnd) == window)) {
                if (message.wParam == 0x1b) { s.done = true; break; }
                if (message.wParam == 0x0d and message.hwnd == s.edit) { s.start(); continue; }
            }
            if (IsDialogMessageW(window, &message) == 0) {
                _ = w.TranslateMessage(&message);
                _ = w.DispatchMessageW(&message);
            }
            if (s.done) break;
        }
        s.poll();
        if (s.phase == .busy) _ = w.InvalidateRect(window, null, 0);
    }
}
