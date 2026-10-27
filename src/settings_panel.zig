const std = @import("std");
const w = @import("win32.zig");
const state = @import("app_state.zig");
const tokens = @import("design_tokens.zig");
const drawing = @import("drawing.zig");
const smooth = @import("smooth.zig");
const files = @import("file_io.zig");
const L = @import("startup.zig").L;
const a = std.heap.page_allocator;

extern "user32" fn IsDialogMessageW(w.HANDLE, *w.MSG) callconv(w.WINAPI) w.BOOL;
extern "kernel32" fn GetFileSizeEx(w.HANDLE, *i64) callconv(w.WINAPI) w.BOOL;
extern "gdi32" fn StretchBlt(w.HANDLE, i32, i32, i32, i32, w.HANDLE, i32, i32, i32, i32, u32) callconv(w.WINAPI) w.BOOL;

pub const Control = enum(u16) {
    close = 100,
    theme_system,
    theme_dark,
    theme_light,
    font_smaller,
    font_reset,
    font_bigger,
    terminal,
    dictation,
    upload,
    release_notes,
};

const controls_count = std.meta.tags(Control).len;
var window: w.HANDLE = null;
var viewport: w.HANDLE = null;
var owner: w.HANDLE = null;
var previous_focus: w.HANDLE = null;
var backdrop: w.HANDLE = null;
var backdrop_size = w.SIZE{ .cx = 0, .cy = 0 };
var edit_brush: w.HANDLE = null;
var children: [controls_count]w.HANDLE = @splat(null);
var key_labels: [2]w.HANDLE = @splat(null);
var fonts: [3]w.HANDLE = @splat(null);
var dirty = [2]bool{ false, false };
var loading = false;
var scroll: i32 = 0;
var scale: i32 = 100;

fn s(value: i32) i32 {
    return @divTrunc(value * scale, 100);
}

fn index(control: Control) usize {
    return @intFromEnum(control) - @intFromEnum(Control.close);
}

pub fn panelRect(width: i32, height: i32, percent: i32) w.RECT {
    const margin = @divTrunc(16 * percent, 100);
    const width_px = @max(1, @min(@divTrunc(640 * percent, 100), width - margin * 2));
    const height_px = @max(1, @min(@divTrunc(620 * percent, 100), height - margin * 2));
    const left = @divTrunc(width - width_px, 2);
    const top = @divTrunc(height - height_px, 2);
    return .{ .left = left, .top = top, .right = left + width_px, .bottom = top + height_px };
}

fn client(hwnd: w.HANDLE) w.RECT {
    var rect = std.mem.zeroes(w.RECT);
    _ = w.GetClientRect(hwnd, &rect);
    return rect;
}

fn panel() w.RECT {
    const rc = client(window);
    return panelRect(rc.right, rc.bottom, scale);
}

const ContentGeometry = struct {
    stacked: bool,
    row_height: i32,
    key_height: i32,
    look: w.RECT,
    keys: w.RECT,
    about: w.RECT,
};

fn contentGeometry() ContentGeometry {
    const width = client(viewport).right;
    const stacked = width < s(480);
    const row_height = s(if (stacked) @as(i32, 88) else 48);
    const key_height = s(if (stacked) @as(i32, 88) else 52);
    const look = w.RECT{ .left = 0, .right = width, .top = s(24), .bottom = s(24 + 52) + row_height * 2 };
    const keys = w.RECT{ .left = 0, .right = width, .top = look.bottom + s(50), .bottom = look.bottom + s(62) + key_height * 2 };
    const about = w.RECT{ .left = 0, .right = width, .top = keys.bottom + s(50), .bottom = keys.bottom + s(150) };
    return .{ .stacked = stacked, .row_height = row_height, .key_height = key_height, .look = look, .keys = keys, .about = about };
}

fn controlRect(control: Control) w.RECT {
    const width = client(viewport).right;
    const right = width - s(16);
    const geometry = contentGeometry();
    const lower = if (geometry.stacked) s(40) else 0;
    return switch (control) {
        .close => blk: {
            const rc = panel();
            break :blk .{ .left = rc.right - s(64), .right = rc.right - s(28), .top = rc.top + s(24), .bottom = rc.top + s(60) };
        },
        .theme_system, .theme_dark, .theme_light => blk: {
            const cell = @min(s(70), @divTrunc(width - s(32), 3));
            const n: i32 = @intCast(@intFromEnum(control) - @intFromEnum(Control.theme_system));
            const left = right - cell * 3 + cell * n;
            const top = geometry.look.top + s(8) + lower;
            break :blk .{ .left = left, .right = left + cell, .top = top, .bottom = top + s(34) };
        },
        .font_smaller, .font_reset, .font_bigger => blk: {
            const n: i32 = @intCast(@intFromEnum(control) - @intFromEnum(Control.font_smaller));
            const left = right - s(132) + s(44) * n;
            const top = geometry.look.top + geometry.row_height + s(8) + lower;
            break :blk .{ .left = left, .right = left + s(44), .top = top, .bottom = top + s(34) };
        },
        .terminal => blk: {
            const top = geometry.look.top + geometry.row_height * 2 + s(12);
            break :blk .{ .left = right - s(48), .right = right, .top = top, .bottom = top + s(26) };
        },
        .dictation, .upload => blk: {
            const n: i32 = if (control == .dictation) 0 else 1;
            const top = geometry.keys.top + s(16) + n * geometry.key_height + lower;
            break :blk .{ .left = if (geometry.stacked) s(16) else @max(s(180), @divTrunc(width, 2)), .right = right, .top = top, .bottom = top + s(30) };
        },
        .release_notes => .{ .left = right - s(70), .right = right, .top = geometry.about.top + s(10), .bottom = geometry.about.top + s(42) },
    };
}

fn label(control: Control) w.LPCWSTR {
    return switch (control) {
        .close => L("Close Settings"),
        .theme_system => L("System"),
        .theme_dark => L("Dark"),
        .theme_light => L("Light"),
        .font_smaller => L("Decrease chat font size"),
        .font_reset => L("Reset chat font size"),
        .font_bigger => L("Increase chat font size"),
        .terminal => L("Terminal details"),
        .dictation => L("Dictation key"),
        .upload => L("Screencast2 upload key"),
        .release_notes => L("Release notes"),
    };
}

pub fn isOpen() bool {
    return window != null;
}

pub fn ownsWindow(hwnd: w.HANDLE) bool {
    return window != null and hwnd != null and w.GetAncestor(hwnd, 2) == window;
}

pub fn ownsForeground() bool {
    return ownsWindow(w.GetForegroundWindow());
}

pub fn dialogMessage(message: *w.MSG) bool {
    return window != null and IsDialogMessageW(window, message) != 0;
}

fn uploadPath(out: []u8) ?[]const u8 {
    var local: [512]u8 = undefined;
    const len = w.GetEnvironmentVariableA("LOCALAPPDATA", &local, local.len);
    if (len == 0 or len >= local.len) return null;
    return std.fmt.bufPrint(out, "{s}\\screencast2-go\\config.toml", .{local[0..len]}) catch null;
}

pub fn replaceUploadKey(allocator: std.mem.Allocator, contents: []const u8, value: []const u8) ![]u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    const quoted = try std.json.Stringify.valueAlloc(allocator, value, .{});
    defer allocator.free(quoted);
    var in_upload = false;
    var seen_section = false;
    var written = false;
    var lines = std.mem.splitScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        if (line.len == 0 and lines.peek() == null) break;
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (std.mem.startsWith(u8, trimmed, "[")) {
            if (in_upload and !written) {
                try output.appendSlice(allocator, "upload_secret = ");
                try output.appendSlice(allocator, quoted);
                try output.append(allocator, '\n');
                written = true;
            }
            in_upload = std.mem.eql(u8, trimmed, "[upload]");
            seen_section = true;
        }
        const assignment = std.mem.startsWith(u8, trimmed, "upload_secret") and
            std.mem.startsWith(u8, std.mem.trimStart(u8, trimmed[@min(trimmed.len, "upload_secret".len)..], " \t"), "=");
        if ((in_upload or !seen_section) and assignment) {
            try output.appendSlice(allocator, "upload_secret = ");
            try output.appendSlice(allocator, quoted);
            try output.append(allocator, '\n');
            written = true;
        } else {
            try output.appendSlice(allocator, line);
            try output.append(allocator, '\n');
        }
    }
    if (!written) {
        if (!in_upload) try output.appendSlice(allocator, "\n[upload]\napi_base_url = \"https://screencast2.com\"\n");
        try output.appendSlice(allocator, "upload_secret = ");
        try output.appendSlice(allocator, quoted);
        try output.append(allocator, '\n');
    }
    return output.toOwnedSlice(allocator);
}

fn loadKeys() void {
    loading = true;
    defer loading = false;
    var key: [512:0]u16 = @splat(0);
    var bytes: w.DWORD = @sizeOf(@TypeOf(key));
    if (w.RegGetValueW(w.HKEY_CURRENT_USER, L("Environment"), L("DEEPGRAM_API_KEY"), 2, null, &key, &bytes) == 0) {
        key[key.len - 1] = 0;
        _ = w.SetWindowTextW(children[index(.dictation)], &key);
    }
    @memset(&key, 0);
    var path_buf: [768]u8 = undefined;
    const path = uploadPath(&path_buf) orelse return;
    const contents = files.readFileAllocWin32(path, 8192) orelse return;
    defer {
        @memset(contents, 0);
        a.free(contents);
    }
    if (@import("chat_image.zig").parseUploadConfig(contents)) |config_value| {
        var config = config_value;
        const len = std.unicode.utf8ToUtf16Le(&key, config.secretSlice()) catch 0;
        key[len] = 0;
        _ = w.SetWindowTextW(children[index(.upload)], &key);
        @memset(&key, 0);
        @memset(&config.secret, 0);
    }
    dirty = .{ false, false };
}

fn saveKey(control: Control) bool {
    const slot: usize = if (control == .dictation) 0 else 1;
    if (!dirty[slot]) return true;
    const edit = children[index(control)];
    const len = w.GetWindowTextLengthW(edit);
    const text = a.allocSentinel(u16, @intCast(@max(0, len)), 0) catch return false;
    defer {
        @memset(text, 0);
        a.free(text);
    }
    _ = w.GetWindowTextW(edit, text.ptr, @intCast(text.len + 1));
    if (control == .dictation) {
        var current: w.HANDLE = null;
        if (w.RegOpenCurrentUser(0x20006, &current) != 0) return false;
        defer _ = w.RegCloseKey(current);
        var environment: w.HANDLE = null;
        if (w.RegCreateKeyExW(current, L("Environment"), 0, null, 0, 0x20006, null, &environment, null) != 0) return false;
        defer _ = w.RegCloseKey(environment);
        if (w.RegSetValueExW(environment, L("DEEPGRAM_API_KEY"), 0, 1, text.ptr, @intCast((text.len + 1) * 2)) != 0) return false;
    } else {
        const utf8 = std.unicode.utf16LeToUtf8Alloc(a, text) catch return false;
        defer {
            @memset(utf8, 0);
            a.free(utf8);
        }
        var path_buf: [768]u8 = undefined;
        const path = uploadPath(&path_buf) orelse return false;
        var old: ?[]u8 = null;
        if (files.win32OpenRead(path)) |file| {
            defer _ = w.CloseHandle(file);
            var size: i64 = 0;
            if (GetFileSizeEx(file, &size) == 0 or size < 0) return false;
            const bytes = a.alloc(u8, @intCast(size)) catch return false;
            if (files.win32ReadAll(file, bytes) != bytes.len) {
                @memset(bytes, 0);
                a.free(bytes);
                return false;
            }
            old = bytes;
        } else if (w.GetLastError() != 2 and w.GetLastError() != 3) return false;
        defer if (old) |bytes| {
            @memset(bytes, 0);
            a.free(bytes);
        };
        const updated = replaceUploadKey(a, old orelse "", utf8) catch return false;
        defer {
            @memset(updated, 0);
            a.free(updated);
        }
        const slash = std.mem.lastIndexOfScalar(u8, path, '\\') orelse return false;
        files.win32MakePath(path[0..slash]);
        if (!files.writeFileAtomicW(path, updated)) return false;
    }
    dirty[slot] = false;
    return true;
}

fn saveKeys() bool {
    if (saveKey(.dictation) and saveKey(.upload)) return true;
    _ = w.MessageBoxW(window, L("This key could not be saved. Check file permissions and try again."), L("Settings"), 0x10);
    return false;
}

fn paintText(hdc: w.HANDLE, value: []const u8, rect_value: w.RECT, font: usize, color: u32, flags: u32) void {
    var rect = rect_value;
    const old = w.SelectObject(hdc, fonts[font]);
    defer _ = w.SelectObject(hdc, old);
    _ = w.SetTextColor(hdc, color);
    _ = w.SetBkMode(hdc, 1);
    drawing.drawAscii(hdc, value, &rect, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_NOPREFIX | w.DT_END_ELLIPSIS | flags);
}

fn lineRect(top: i32, height: i32) w.RECT {
    return .{ .left = s(16), .right = client(viewport).right - s(16), .top = top - scroll, .bottom = top + height - scroll };
}

fn card(hdc: w.HANDLE, value: w.RECT) void {
    var rc = value;
    rc.top -= scroll;
    rc.bottom -= scroll;
    smooth.fillRoundRect(hdc, rc, s(16), tokens.ReaderControl);
}

fn paintContent(hdc: w.HANDLE) void {
    const rc = client(viewport);
    const brush = w.CreateSolidBrush(tokens.ReaderPanel);
    defer _ = w.DeleteObject(brush);
    _ = w.FillRect(hdc, &rc, brush);
    const g = contentGeometry();
    paintText(hdc, "LOOK", lineRect(0, s(20)), 2, tokens.ReaderHint, 0);
    card(hdc, g.look);
    paintText(hdc, "Theme", lineRect(g.look.top + s(6), s(38)), 0, tokens.ReaderForeground, 0);
    paintText(hdc, "Chat font size", lineRect(g.look.top + g.row_height + s(6), s(38)), 0, tokens.ReaderForeground, 0);
    paintText(hdc, "Terminal details", lineRect(g.look.top + g.row_height * 2 + s(6), s(38)), 0, tokens.ReaderForeground, 0);
    paintText(hdc, "KEYS", lineRect(g.keys.top - s(24), s(20)), 2, tokens.ReaderHint, 0);
    card(hdc, g.keys);
    paintText(hdc, "ABOUT", lineRect(g.about.top - s(24), s(20)), 2, tokens.ReaderHint, 0);
    card(hdc, g.about);
    paintText(hdc, "Release notes", lineRect(g.about.top + s(6), s(38)), 0, tokens.ReaderForeground, 0);
    paintText(hdc, "Version", lineRect(g.about.top + s(52), s(38)), 0, tokens.ReaderForeground, 0);
    paintText(hdc, @import("main.zig").APP_VERSION, lineRect(g.about.top + s(52), s(38)), 0, tokens.ReaderHint, w.DT_RIGHT);
}

const DrawItem = extern struct {
    kind: u32,
    id: u32,
    item: u32,
    action: u32,
    state: u32,
    hwnd: w.HANDLE,
    hdc: w.HANDLE,
    rect: w.RECT,
    data: usize,
};

fn drawControl(item: *const DrawItem) void {
    const control = std.enums.fromInt(Control, item.id) orelse return;
    const rc = item.rect;
    const selected = switch (control) {
        .theme_system => state.g_system_theme,
        .theme_dark => !state.g_system_theme and !state.g_light_theme and !state.g_mid_theme and !state.g_amoled_theme and !state.g_edge_gray_theme and !state.g_multiprompt_theme and !state.g_dev_theme_active,
        .theme_light => !state.g_system_theme and state.g_light_theme,
        else => false,
    };
    const background = w.CreateSolidBrush(if (control == .close) tokens.ReaderPanel else tokens.ReaderControl);
    defer _ = w.DeleteObject(background);
    _ = w.FillRect(item.hdc, &rc, background);
    if (control == .terminal) {
        const on = !state.g_chat_active;
        smooth.fillRoundRect(item.hdc, rc, s(13), if (on) tokens.ReaderForeground else tokens.ReaderRaised);
        const thumb_size = s(20);
        const left = if (on) rc.right - thumb_size - s(3) else rc.left + s(3);
        smooth.fillEllipse(item.hdc, .{ .left = left, .right = left + thumb_size, .top = s(3), .bottom = s(3) + thumb_size }, if (on) tokens.ReaderPanel else tokens.ReaderHint);
    } else {
        smooth.fillRoundRect(item.hdc, rc, if (control == .close) s(18) else s(8), if (selected or (item.state & 0x11) != 0) tokens.ReaderRaised else tokens.ReaderControl);
        var buffer: [24]u8 = undefined;
        const value: []const u8 = switch (control) {
            .close => "x",
            .theme_system => "System",
            .theme_dark => "Dark",
            .theme_light => "Light",
            .font_smaller => "-",
            .font_reset => std.fmt.bufPrint(&buffer, "{d}", .{state.g_chat_font_pt}) catch "",
            .font_bigger => "+",
            .release_notes => "Open",
            else => "",
        };
        paintText(item.hdc, value, rc, 0, tokens.ReaderForeground, w.DT_CENTER);
    }
}

fn arrangeControls() void {
    for (std.meta.tags(Control)) |control| {
        if (control == .close) continue;
        var rc = controlRect(control);
        rc.top -= scroll;
        rc.bottom -= scroll;
        _ = w.MoveWindow(children[index(control)], rc.left, rc.top, rc.right - rc.left, rc.bottom - rc.top, 1);
    }
    const g = contentGeometry();
    for (key_labels, 0..) |child, n| {
        const key = controlRect(if (n == 0) .dictation else .upload);
        const left = s(16);
        const top = g.keys.top + s(12) + @as(i32, @intCast(n)) * g.key_height - scroll;
        const right = if (g.stacked) g.keys.right - s(16) else key.left - s(16);
        _ = w.MoveWindow(child, left, top, @max(1, right - left), s(38), 1);
    }
    _ = w.InvalidateRect(viewport, null, 1);
}

fn setScroll(value: i32) void {
    scroll = std.math.clamp(value, 0, @max(0, contentGeometry().about.bottom - client(viewport).bottom));
    arrangeControls();
}

fn ensureVisible(control: Control) void {
    if (control == .close) return;
    const rc = controlRect(control);
    if (rc.top < scroll) setScroll(rc.top);
    if (rc.bottom > scroll + client(viewport).bottom) setScroll(rc.bottom - client(viewport).bottom);
}

fn dispatch(control: Control) void {
    switch (control) {
        .close => close(),
        .theme_system, .theme_dark, .theme_light => @import("themes.zig").choose(switch (control) {
            .theme_system => .system,
            .theme_dark => .dark,
            .theme_light => .light,
            else => unreachable,
        }),
        .font_smaller => @import("main.zig").setChatFontPoint(state.g_chat_font_pt - 1),
        .font_reset => @import("main.zig").setChatFontPoint(state.CHAT_FONT_DEFAULT_PT),
        .font_bigger => @import("main.zig").setChatFontPoint(state.g_chat_font_pt + 1),
        .terminal => _ = w.SendMessageW(owner, w.WM_APP_CHAT_TOGGLE, 0, 0),
        .release_notes => {
            const target = owner;
            close();
            if (window == null) _ = @import("focus.zig").PostMessageW(target, w.WM_APP_CHANGELOG_OPEN, 0, 0);
        },
        .dictation, .upload => {},
    }
    if (window != null) _ = @import("focus.zig").SetFocus(children[index(control)]);
    for (children) |child| {
        if (child != null) _ = w.InvalidateRect(child, null, 1);
    }
}

fn contentProc(hwnd: w.HANDLE, message: w.UINT, wp: w.WPARAM, lp: w.LPARAM) callconv(w.WINAPI) w.LRESULT {
    const prior_action = state.g_focus_user_action_tick;
    defer state.g_focus_user_action_tick = prior_action;
    state.g_focus_user_action_tick = if (@import("focus.zig").foregroundIsOurs()) state.g_focus_input_tick else 0;
    switch (message) {
        w.WM_PAINT => {
            var ps = std.mem.zeroes(w.PAINTSTRUCT);
            const hdc = w.BeginPaint(hwnd, &ps);
            paintContent(hdc);
            _ = w.EndPaint(hwnd, &ps);
            return 0;
        },
        0x002b => {
            drawControl(@ptrFromInt(@as(usize, @bitCast(lp))));
            return 1;
        },
        w.WM_COMMAND => {
            const control = std.enums.fromInt(Control, @as(u16, @truncate(wp))) orelse return 0;
            const notification: u16 = @truncate(wp >> 16);
            if (notification == 0x100 or notification == 6) ensureVisible(control);
            if ((control == .dictation or control == .upload) and !loading) {
                if (notification == 0x300) dirty[if (control == .dictation) @as(usize, 0) else 1] = true;
                if (notification == 0x200) _ = saveKey(control);
            } else if (notification == 0) dispatch(control);
            return 0;
        },
        0x0133, 0x0138 => {
            const hdc: w.HANDLE = @ptrFromInt(wp);
            _ = w.SetTextColor(hdc, tokens.ReaderForeground);
            _ = w.SetBkColor(hdc, tokens.ReaderControl);
            return @bitCast(@as(usize, @intFromPtr(edit_brush)));
        },
        w.WM_MOUSEWHEEL => {
            const delta: i16 = @bitCast(@as(u16, @truncate(wp >> 16)));
            setScroll(scroll - @divTrunc(@as(i32, delta) * s(48), 120));
            return 0;
        },
        w.WM_ERASEBKGND => return 1,
        else => return w.DefWindowProcW(hwnd, message, wp, lp),
    }
}

fn capture() bool {
    const rc = client(owner);
    if (rc.right <= 0 or rc.bottom <= 0) return false;
    var origin = w.POINT{ .x = 0, .y = 0 };
    _ = w.ClientToScreen(owner, &origin);
    const screen = w.GetDC(null);
    if (screen == null) return false;
    defer _ = w.ReleaseDC(null, screen);
    const dc = w.CreateCompatibleDC(screen);
    if (dc == null) return false;
    defer _ = w.DeleteDC(dc);
    const info = w.BITMAPINFO{ .header = .{ .width = rc.right, .height = -rc.bottom } };
    var bits: ?*anyopaque = null;
    backdrop = w.CreateDIBSection(screen, &info, 0, &bits, null, 0);
    if (backdrop == null or bits == null) return false;
    const old = w.SelectObject(dc, backdrop);
    const copied = w.BitBlt(dc, 0, 0, rc.right, rc.bottom, screen, origin.x, origin.y, w.GDI_SRCCOPY);
    _ = w.SelectObject(dc, old);
    if (copied == 0) return false;
    const pixels = @as([*]u8, @ptrCast(bits.?))[0 .. @as(usize, @intCast(rc.right)) * @as(usize, @intCast(rc.bottom)) * 4];
    for (pixels, 0..) |*pixel, i| pixel.* = if (i % 4 == 3) 255 else @intCast(@as(u16, pixel.*) * 45 / 100);
    backdrop_size = .{ .cx = rc.right, .cy = rc.bottom };
    return true;
}

pub fn reposition() void {
    if (window == null or w.IsIconic(owner) != 0) return;
    const next_scale = drawing.uiScaled(100);
    if (scale != next_scale) {
        scale = next_scale;
        refreshFonts();
        for (children) |child| {
            if (child != null) _ = w.SendMessageW(child, 0x30, @intFromPtr(fonts[0]), 1);
        }
        for (key_labels) |child| {
            if (child != null) _ = w.SendMessageW(child, 0x30, @intFromPtr(fonts[0]), 1);
        }
    }
    const rc = client(owner);
    var origin = w.POINT{ .x = 0, .y = 0 };
    _ = w.ClientToScreen(owner, &origin);
    _ = w.MoveWindow(window, origin.x, origin.y, rc.right, rc.bottom, 1);
    const box = panel();
    _ = w.MoveWindow(viewport, box.left + s(24), box.top + s(92), @max(1, box.right - box.left - s(48)), @max(1, box.bottom - box.top - s(116)), 1);
    const close_rc = controlRect(.close);
    _ = w.MoveWindow(children[index(.close)], close_rc.left, close_rc.top, close_rc.right - close_rc.left, close_rc.bottom - close_rc.top, 1);
    setScroll(scroll);
}

fn panelProc(hwnd: w.HANDLE, message: w.UINT, wp: w.WPARAM, lp: w.LPARAM) callconv(w.WINAPI) w.LRESULT {
    const prior_action = state.g_focus_user_action_tick;
    defer state.g_focus_user_action_tick = prior_action;
    state.g_focus_user_action_tick = if (@import("focus.zig").foregroundIsOurs()) state.g_focus_input_tick else 0;
    switch (message) {
        w.WM_PAINT => {
            var ps = std.mem.zeroes(w.PAINTSTRUCT);
            const hdc = w.BeginPaint(hwnd, &ps);
            if (backdrop != null) {
                const dc = w.CreateCompatibleDC(hdc);
                const old = w.SelectObject(dc, backdrop);
                const rc = client(hwnd);
                _ = StretchBlt(hdc, 0, 0, rc.right, rc.bottom, dc, 0, 0, backdrop_size.cx, backdrop_size.cy, w.GDI_SRCCOPY);
                _ = w.SelectObject(dc, old);
                _ = w.DeleteDC(dc);
            }
            const rc = panel();
            smooth.fillRoundRect(hdc, rc, s(24), tokens.ReaderOutline);
            var inner = rc;
            const outline = @max(1, s(1));
            inner.left += outline;
            inner.top += outline;
            inner.right -= outline;
            inner.bottom -= outline;
            smooth.fillRoundRect(hdc, inner, s(23), tokens.ReaderPanel);
            paintText(hdc, "Settings", .{ .left = rc.left + s(28), .right = rc.right - s(80), .top = rc.top + s(22), .bottom = rc.top + s(62) }, 1, tokens.ReaderForeground, 0);
            _ = w.EndPaint(hwnd, &ps);
            return 0;
        },
        0x002b => {
            drawControl(@ptrFromInt(@as(usize, @bitCast(lp))));
            return 1;
        },
        w.WM_COMMAND => {
            const id: u16 = @truncate(wp);
            if (id == 1 or id == 2 or id == @intFromEnum(Control.close)) close();
            return 0;
        },
        state.WM_CLOSE => {
            close();
            return 0;
        },
        w.WM_MOUSEWHEEL => return contentProc(viewport, message, wp, lp),
        w.WM_LBUTTONDOWN => {
            const x: i16 = @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp)))));
            const y: i16 = @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp)) >> 16)));
            const rc = panel();
            if (x < rc.left or x >= rc.right or y < rc.top or y >= rc.bottom) close();
            return 0;
        },
        w.WM_ERASEBKGND => return 1,
        else => return w.DefWindowProcW(hwnd, message, wp, lp),
    }
}

fn refreshFonts() void {
    for (&fonts) |*font| {
        if (font.* != null) _ = w.DeleteObject(font.*);
    }
    for (&fonts, 0..) |*font, i| font.* = @import("fonts.zig").create(-s(if (i == 1) @as(i32, 24) else if (i == 2) @as(i32, 12) else 15), 0, 0, 0, if (i == 0) 400 else 600, 0, 0, 0, 0, 0, 0, 5, 0, null);
}

pub fn open(parent: w.HANDLE) void {
    if (window != null) {
        _ = @import("focus.zig").SetForegroundWindow(window);
        return;
    }
    owner = parent;
    previous_focus = w.GetFocus();
    scale = drawing.uiScaled(100);
    scroll = 0;
    dirty = .{ false, false };
    refreshFonts();
    const instance = w.GetModuleHandleW(null);
    var wc = std.mem.zeroes(w.WNDCLASSEXW);
    wc.cbSize = @sizeOf(w.WNDCLASSEXW);
    wc.hInstance = instance;
    wc.hCursor = w.LoadCursorW(null, @ptrFromInt(32512));
    wc.lpszClassName = L("MultipromptSettings");
    wc.lpfnWndProc = panelProc;
    _ = w.RegisterClassExW(&wc);
    wc.lpszClassName = L("MultipromptSettingsContent");
    wc.lpfnWndProc = contentProc;
    _ = w.RegisterClassExW(&wc);
    if (!capture()) {
        release();
        return;
    }
    edit_brush = w.CreateSolidBrush(tokens.ReaderControl);
    window = w.CreateWindowExW(0x10000 | 0x80, L("MultipromptSettings"), L("Settings"), 0x80000000 | 0x02000000, 0, 0, 1, 1, owner, null, instance, null);
    if (window == null) {
        release();
        return;
    }
    viewport = w.CreateWindowExW(0x10000, L("MultipromptSettingsContent"), L("Settings cards"), 0x40000000 | 0x10000000 | 0x02000000, 0, 0, 1, 1, window, null, instance, null);
    for (std.meta.tags(Control)) |control| {
        const edit = control == .dictation or control == .upload;
        const parent_window = if (control == .close) window else viewport;
        if (edit) {
            const slot: usize = if (control == .dictation) 0 else 1;
            key_labels[slot] = w.CreateWindowExW(0, L("STATIC"), label(control), 0x40000000 | 0x10000000 | 0x0200 | 0x4000, 0, 0, 1, 1, viewport, null, instance, null);
            _ = w.SendMessageW(key_labels[slot], 0x30, @intFromPtr(fonts[0]), 1);
        }
        children[index(control)] = w.CreateWindowExW(0, if (edit) L("EDIT") else L("BUTTON"), if (edit) L("") else label(control), 0x40000000 | 0x10000000 | 0x00010000 | (if (edit) @as(u32, 0x20 | 0x80) else @as(u32, 0xb | 0x4000)), 0, 0, 1, 1, parent_window, @ptrFromInt(@intFromEnum(control)), instance, null);
        _ = w.SendMessageW(children[index(control)], 0x30, @intFromPtr(fonts[0]), 1);
    }
    reposition();
    loadKeys();
    @import("browser_pane.zig").updateBrowserVisibility();
    _ = @import("focus.zig").ShowWindow(window, 5);
    _ = @import("focus.zig").SetForegroundWindow(window);
    _ = @import("focus.zig").SetFocus(children[index(.close)]);
}

fn release() void {
    if (edit_brush != null) _ = w.DeleteObject(edit_brush);
    edit_brush = null;
    if (backdrop != null) _ = w.DeleteObject(backdrop);
    backdrop = null;
    for (&fonts) |*font| {
        if (font.* != null) _ = w.DeleteObject(font.*);
        font.* = null;
    }
    children = @splat(null);
    key_labels = @splat(null);
    viewport = null;
    owner = null;
    previous_focus = null;
}

pub fn close() void {
    if (window == null or !saveKeys()) return;
    const target = owner;
    const focus = previous_focus;
    const current = window;
    window = null;
    _ = w.DestroyWindow(current);
    release();
    _ = @import("focus.zig").SetForegroundWindow(target);
    @import("browser_pane.zig").updateBrowserVisibility();
    if (focus != null and w.IsWindow(focus) != 0) _ = @import("focus.zig").SetFocus(focus);
}

test "IGSH-1021 panel remains centred and inside its client at supported scales" {
    for ([_]i32{ 100, 125, 150, 200 }) |percent| {
        for ([_][2]i32{ .{ 1920, 1080 }, .{ 1000, 650 }, .{ 640, 480 } }) |size| {
            const rc = panelRect(size[0], size[1], percent);
            try std.testing.expect(rc.left >= 0 and rc.top >= 0 and rc.right <= size[0] and rc.bottom <= size[1]);
            try std.testing.expect(@abs(rc.left - (size[0] - rc.right)) <= 1);
            try std.testing.expect(@abs(rc.top - (size[1] - rc.bottom)) <= 1);
        }
    }
}

test "IGSH-1021 replacing upload key preserves other values and sections" {
    const allocator = std.testing.allocator;
    const original = "[upload]\napi_base_url = \"https://example.invalid\"\nupload_secret = \"old\"\n[other]\nupload_secret = \"untouched\"\nquality = 90\n";
    const updated = try replaceUploadKey(allocator, original, "settings-fixture");
    defer allocator.free(updated);
    try std.testing.expectEqualStrings("[upload]\napi_base_url = \"https://example.invalid\"\nupload_secret = \"settings-fixture\"\n[other]\nupload_secret = \"untouched\"\nquality = 90\n", updated);
    const inserted = try replaceUploadKey(allocator, "[upload]\napi_base_url = \"https://example.invalid\"\n[other]\nx = 1\n", "settings-fixture");
    defer allocator.free(inserted);
    try std.testing.expectEqualStrings("[upload]\napi_base_url = \"https://example.invalid\"\nupload_secret = \"settings-fixture\"\n[other]\nx = 1\n", inserted);
    const created = try replaceUploadKey(allocator, "", "settings-fixture");
    defer allocator.free(created);
    try std.testing.expect(@import("chat_image.zig").parseUploadConfig(created) != null);
}
