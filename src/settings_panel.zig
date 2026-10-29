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
extern "user32" fn GetKeyState(i32) callconv(w.WINAPI) i16;
extern "user32" fn EnableWindow(w.HANDLE, w.BOOL) callconv(w.WINAPI) w.BOOL;
extern "kernel32" fn GetFileSizeEx(w.HANDLE, *i64) callconv(w.WINAPI) w.BOOL;
extern "gdi32" fn StretchBlt(w.HANDLE, i32, i32, i32, i32, w.HANDLE, i32, i32, i32, i32, u32) callconv(w.WINAPI) w.BOOL;

pub const Control = enum(u16) {
    close = 100,
    theme,
    font_small,
    font_normal,
    font_large,
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
var key_window: w.HANDLE = null;
var key_edit: w.HANDLE = null;
var key_edit_proc: isize = 0;
var key_control: Control = .dictation;
var fonts: [3]w.HANDLE = @splat(null);
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
    const width_px = @max(1, @min(@divTrunc(600 * percent, 100), width - margin * 2));
    const height_px = @max(1, @min(@divTrunc(568 * percent, 100), height - margin * 2));
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
    look: w.RECT,
    colors: w.RECT,
    keys: w.RECT,
    about: w.RECT,
};

fn contentGeometry() ContentGeometry {
    const width = client(viewport).right;
    const stacked = width < s(440);
    const extra = if (stacked) s(40) else @as(i32, 0);
    const look = w.RECT{ .left = 0, .right = width, .top = s(24), .bottom = s(168) + extra };
    const colors = w.RECT{ .left = 0, .right = width, .top = look.bottom + s(44), .bottom = look.bottom + s(44) + s(@as(i32, @intCast(state.g_lws_count)) * 80) };
    const keys = w.RECT{ .left = 0, .right = width, .top = colors.bottom + s(44), .bottom = colors.bottom + s(148) };
    const about = w.RECT{ .left = 0, .right = width, .top = keys.bottom + s(44), .bottom = keys.bottom + s(148) };
    return .{ .stacked = stacked, .look = look, .colors = colors, .keys = keys, .about = about };
}

fn controlRect(control: Control) w.RECT {
    const width = client(viewport).right;
    const right = width - s(16);
    const g = contentGeometry();
    const extra = if (g.stacked) s(40) else @as(i32, 0);
    return switch (control) {
        .close => blk: {
            const rc = panel();
            break :blk .{ .left = rc.right - s(56), .right = rc.right - s(24), .top = rc.top + s(24), .bottom = rc.top + s(56) };
        },
        .theme => .{ .left = right - s(120), .right = right, .top = g.look.top + s(4), .bottom = g.look.top + s(44) },
        .font_small, .font_normal, .font_large => blk: {
            const cell = @min(s(72), @divTrunc(width - s(32), 3));
            const n: i32 = @intCast(@intFromEnum(control) - @intFromEnum(Control.font_small));
            const left = right - cell * 3 + cell * n;
            const top = g.look.top + s(56) + extra;
            break :blk .{ .left = left, .right = left + cell, .top = top, .bottom = top + s(32) };
        },
        .terminal => .{ .left = right - s(40), .right = right, .top = g.look.top + s(110) + extra, .bottom = g.look.top + s(132) + extra },
        .dictation, .upload => blk: {
            const top = g.keys.top + (if (control == .dictation) @as(i32, 0) else s(52));
            break :blk .{ .left = s(16), .right = right, .top = top + s(4), .bottom = top + s(48) };
        },
        .release_notes => .{ .left = s(16), .right = right, .top = g.about.top + s(4), .bottom = g.about.top + s(48) },
    };
}

fn label(control: Control) w.LPCWSTR {
    return switch (control) {
        .close => L("Close Settings"),
        .theme => L("Theme"),
        .font_small => L("Small"),
        .font_normal => L("Normal"),
        .font_large => L("Large"),
        .terminal => L("Terminal details"),
        .dictation => L("Dictation key"),
        .upload => L("Screencast2 upload key"),
        .release_notes => L("Release notes"),
    };
}

pub fn windowKey(message: u32, vk: usize, comptime hook: bool) bool {
    if (state.g_account_locked or message != w.WM_KEYDOWN or vk != 0xbc or isOpen()) return false;
    const focus = @import("focus.zig");
    const keyState = if (hook) w.GetAsyncKeyState else GetKeyState;
    if (keyState(0x11) >= 0 or keyState(0x10) < 0 or keyState(0x12) < 0 or
        keyState(0x5b) < 0 or keyState(0x5c) < 0 or !focus.foregroundIsOurs()) return false;
    return focus.PostMessageW(state.g_main_hwnd, w.WM_APP_SETTINGS_OPEN, 0, 0) != 0;
}

pub fn isOpen() bool {
    return window != null;
}

pub fn ownsWindow(hwnd: w.HANDLE) bool {
    return window != null and hwnd != null and (w.GetAncestor(hwnd, 2) == window or (key_window != null and w.GetAncestor(hwnd, 2) == key_window));
}

pub fn ownsForeground() bool {
    return ownsWindow(w.GetForegroundWindow());
}

pub fn dialogMessage(message: *w.MSG) bool {
    return window != null and IsDialogMessageW(if (key_window != null) key_window else window, message) != 0;
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

fn loadKey(control: Control) void {
    var key: [512:0]u16 = @splat(0);
    defer @memset(&key, 0);
    if (control == .dictation) {
        var bytes: [512]u8 = undefined;
        defer @memset(&bytes, 0);
        if (@import("voice.zig").readDeepgramApiKey(&bytes)) |value| {
            const len = std.unicode.utf8ToUtf16Le(&key, value) catch return;
            key[len] = 0;
            _ = w.SetWindowTextW(key_edit, &key);
        }
        return;
    }
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
        _ = w.SetWindowTextW(key_edit, &key);
        @memset(&config.secret, 0);
    }
}

fn saveKey(control: Control) bool {
    const edit = key_edit;
    const len = w.GetWindowTextLengthW(edit);
    const text = a.allocSentinel(u16, @intCast(@max(0, len)), 0) catch return false;
    defer {
        @memset(text, 0);
        a.free(text);
    }
    _ = w.GetWindowTextW(edit, text.ptr, @intCast(text.len + 1));
    if (control == .dictation) {
        if (!@import("voice.zig").saveDeepgramApiKey(text)) return false;
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
    return true;
}

fn closeKey() void {
    if (key_window == null) return;
    const current = key_window;
    _ = EnableWindow(window, 1);
    key_window = null;
    key_edit = null;
    _ = w.DestroyWindow(current);
    _ = @import("focus.zig").SetForegroundWindow(window);
    _ = @import("focus.zig").SetFocus(children[index(key_control)]);
}

fn keyEditProc(hwnd: w.HANDLE, message: w.UINT, wp: w.WPARAM, lp: w.LPARAM) callconv(w.WINAPI) w.LRESULT {
    if (message == w.WM_KEYDOWN and wp == 0x41 and GetKeyState(0x11) < 0 and GetKeyState(0x12) >= 0) {
        _ = w.SendMessageW(hwnd, 0x00b1, 0, -1);
        return 0;
    }
    if (message == 0x0102 and wp == 1) return 0;
    return w.CallWindowProcW(key_edit_proc, hwnd, message, wp, lp);
}

fn keyProc(hwnd: w.HANDLE, message: w.UINT, wp: w.WPARAM, lp: w.LPARAM) callconv(w.WINAPI) w.LRESULT {
    const prior_action = state.g_focus_user_action_tick;
    defer state.g_focus_user_action_tick = prior_action;
    state.g_focus_user_action_tick = if (@import("focus.zig").foregroundIsOurs()) state.g_focus_input_tick else 0;
    switch (message) {
        w.WM_COMMAND => {
            const id: u16 = @truncate(wp);
            if (id == 2) closeKey();
            if (id == 1) {
                if (saveKey(key_control)) closeKey() else _ = w.MessageBoxW(hwnd, L("This key could not be saved. Check file permissions and try again."), L("Settings"), 0x10);
            }
            return 0;
        },
        state.WM_CLOSE => {
            closeKey();
            return 0;
        },
        w.WM_PAINT => {
            var ps = std.mem.zeroes(w.PAINTSTRUCT);
            const hdc = w.BeginPaint(hwnd, &ps);
            const rc = client(hwnd);
            const brush = w.CreateSolidBrush(tokens.ReaderPanel);
            _ = w.FillRect(hdc, &rc, brush);
            _ = w.DeleteObject(brush);
            paintText(hdc, if (key_control == .dictation) "Dictation key" else "Screencast2 upload key", .{ .left = s(24), .right = rc.right - s(24), .top = s(16), .bottom = s(56) }, 1, tokens.ReaderForeground, 0);
            _ = w.EndPaint(hwnd, &ps);
            return 0;
        },
        0x0133, 0x0138 => {
            const hdc: w.HANDLE = @ptrFromInt(wp);
            _ = w.SetTextColor(hdc, tokens.ReaderForeground);
            _ = w.SetBkColor(hdc, tokens.ReaderControl);
            return @bitCast(@as(usize, @intFromPtr(edit_brush)));
        },
        else => return w.DefWindowProcW(hwnd, message, wp, lp),
    }
}

fn openKey(control: Control) void {
    if (key_window != null) return;
    key_control = control;
    const instance = w.GetModuleHandleW(null);
    var wc = std.mem.zeroes(w.WNDCLASSEXW);
    wc.cbSize = @sizeOf(w.WNDCLASSEXW);
    wc.hInstance = instance;
    wc.hCursor = w.LoadCursorW(null, @ptrFromInt(32512));
    wc.lpszClassName = L("MultipromptSettingsKey");
    wc.lpfnWndProc = keyProc;
    _ = w.RegisterClassExW(&wc);
    const bounds = client(window);
    const width = @min(s(440), bounds.right);
    const height = s(200);
    var origin = w.POINT{ .x = @divTrunc(bounds.right - width, 2), .y = @divTrunc(bounds.bottom - height, 2) };
    _ = w.ClientToScreen(window, &origin);
    key_window = w.CreateWindowExW(0x10000 | 0x80, L("MultipromptSettingsKey"), label(control), 0x80000000 | 0x02000000, origin.x, origin.y, width, height, window, null, instance, null);
    if (key_window == null) return;
    key_edit = w.CreateWindowExW(0, L("EDIT"), L(""), 0x40000000 | 0x10000000 | 0x00010000 | 0x20 | 0x80, s(24), s(76), width - s(48), s(32), key_window, @ptrFromInt(10), instance, null);
    key_edit_proc = w.SetWindowLongPtrW(key_edit, -4, @bitCast(@intFromPtr(&keyEditProc)));
    const cancel = w.CreateWindowExW(0, L("BUTTON"), L("Cancel"), 0x40000000 | 0x10000000 | 0x00010000, width - s(208), s(140), s(84), s(36), key_window, @ptrFromInt(2), instance, null);
    const save = w.CreateWindowExW(0, L("BUTTON"), L("Save"), 0x40000000 | 0x10000000 | 0x00010000 | 1, width - s(108), s(140), s(84), s(36), key_window, @ptrFromInt(1), instance, null);
    for ([_]w.HANDLE{ key_edit, cancel, save }) |child| _ = w.SendMessageW(child, 0x30, @intFromPtr(fonts[0]), 1);
    loadKey(control);
    _ = EnableWindow(window, 0);
    _ = @import("focus.zig").ShowWindow(key_window, 5);
    _ = @import("focus.zig").SetForegroundWindow(key_window);
    _ = @import("focus.zig").SetFocus(key_edit);
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
    smooth.fillRoundRect(hdc, rc, s(20), tokens.ReaderOutline);
    rc.left += s(1);
    rc.right -= s(1);
    rc.top += s(1);
    rc.bottom -= s(1);
    smooth.fillRoundRect(hdc, rc, s(19), tokens.ReaderControl);
}

fn paintContent(hdc: w.HANDLE) void {
    const rc = client(viewport);
    const brush = w.CreateSolidBrush(tokens.ReaderPanel);
    defer _ = w.DeleteObject(brush);
    _ = w.FillRect(hdc, &rc, brush);
    const g = contentGeometry();
    const extra = if (g.stacked) s(40) else @as(i32, 0);
    paintText(hdc, "LOOK", lineRect(0, s(20)), 2, tokens.ReaderHint, 0);
    card(hdc, g.look);
    paintText(hdc, "Theme", lineRect(g.look.top, s(48)), 0, tokens.ReaderForeground, 0);
    paintText(hdc, "Chat font size", lineRect(g.look.top + s(48), s(48)), 0, tokens.ReaderForeground, 0);
    paintText(hdc, "Terminal details", lineRect(g.look.top + s(96) + extra, s(48)), 0, tokens.ReaderForeground, 0);
    var presets = controlRect(.font_small);
    presets.left -= s(3);
    presets.right = controlRect(.font_large).right + s(3);
    presets.top -= scroll + s(3);
    presets.bottom += s(3) - scroll;
    smooth.fillRoundRect(hdc, presets, s(19), tokens.ReaderOutline);
    presets.left += s(1);
    presets.right -= s(1);
    presets.top += s(1);
    presets.bottom -= s(1);
    smooth.fillRoundRect(hdc, presets, s(18), tokens.ReaderPanel);
    paintWorkspaceColors(hdc);
    paintText(hdc, "KEYS", lineRect(g.keys.top - s(24), s(20)), 2, tokens.ReaderHint, 0);
    card(hdc, g.keys);
    paintText(hdc, "ABOUT", lineRect(g.about.top - s(24), s(20)), 2, tokens.ReaderHint, 0);
    card(hdc, g.about);
    paintText(hdc, "Version", lineRect(g.about.top + s(52), s(52)), 0, tokens.ReaderForeground, 0);
    paintText(hdc, @import("main.zig").APP_VERSION, lineRect(g.about.top + s(52), s(52)), 0, tokens.ReaderHint, w.DT_RIGHT);
    const separator = w.CreateSolidBrush(tokens.ReaderOutline);
    defer _ = w.DeleteObject(separator);
    for ([_]i32{ g.look.top + s(48), g.look.top + s(96) + extra, g.keys.top + s(52), g.about.top + s(52) }) |top| {
        const line = lineRect(top, @max(1, s(1)));
        _ = w.FillRect(hdc, &line, separator);
    }
}

fn colorDotRect(workspace: usize, color: usize) w.RECT {
    const cell = @min(s(40), @divTrunc(client(viewport).right - s(32), 8));
    const left = s(16) + cell * @as(i32, @intCast(color));
    const top = contentGeometry().colors.top + s(@as(i32, @intCast(workspace)) * 80 + 36);
    return .{ .left = left, .right = left + cell, .top = top - scroll, .bottom = top + s(36) - scroll };
}

fn paintWorkspaceColors(hdc: w.HANDLE) void {
    const g = contentGeometry();
    paintText(hdc, "WORKSPACE COLORS", lineRect(g.colors.top - s(24), s(20)), 2, tokens.ReaderHint, 0);
    card(hdc, g.colors);
    for (0..state.g_lws_count) |workspace| {
        var name: [32]u8 = undefined;
        paintText(hdc, @import("workspaces.zig").workspaceDisplayName(@intCast(workspace), &name), lineRect(g.colors.top + s(@as(i32, @intCast(workspace)) * 80), s(36)), 0, tokens.ReaderForeground, 0);
        for (@import("bot_avatar.zig").colors, 0..) |hex, color| {
            var rc = colorDotRect(workspace, color);
            const selected = @import("session_layout.zig").workspaceColor(workspace, state.g_ws_colors[workspace]) == color;
            if (selected) smooth.fillEllipse(hdc, rc, tokens.ReaderForeground);
            rc.left += s(4);
            rc.right -= s(4);
            rc.top += s(4);
            rc.bottom -= s(4);
            smooth.fillEllipse(hdc, rc, ((hex >> 16) & 255) | (hex & 0xFF00) | ((hex & 255) << 16));
        }
        paintText(hdc, "Auto", colorDotRect(workspace, 7), 2, if (state.g_ws_colors[workspace] == null) tokens.ReaderForeground else tokens.ReaderHint, w.DT_CENTER);
    }
}

fn chooseWorkspaceColor(workspace: usize, color: ?u8) void {
    state.g_ws_colors[workspace] = color;
    @import("session.zig").saveSession();
    _ = w.InvalidateRect(state.g_main_hwnd, null, 0);
    _ = w.InvalidateRect(viewport, null, 0);
}

fn currentTheme() []const u8 {
    if (state.g_system_theme) return "System";
    if (state.g_light_theme) return "Light";
    if (state.g_mid_theme) return "Mid";
    if (state.g_amoled_theme) return "AMOLED";
    if (state.g_edge_gray_theme) return "Edge gray";
    if (state.g_multiprompt_theme) return "Multi Bot";
    if (state.g_dev_theme_active) return "Custom";
    return "Dark";
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
    const preset = control == .font_small or control == .font_normal or control == .font_large;
    const selected = switch (control) {
        .font_small => state.g_chat_font_pt == 12,
        .font_normal => state.g_chat_font_pt == 14,
        .font_large => state.g_chat_font_pt == 16,
        else => false,
    };
    const background = w.CreateSolidBrush(if (control == .close or preset) tokens.ReaderPanel else tokens.ReaderControl);
    defer _ = w.DeleteObject(background);
    _ = w.FillRect(item.hdc, &rc, background);
    if (control == .close) {
        smooth.fillRoundRect(item.hdc, rc, s(16), tokens.ReaderOutline);
        var inner = rc;
        inner.left += s(1);
        inner.right -= s(1);
        inner.top += s(1);
        inner.bottom -= s(1);
        smooth.fillRoundRect(item.hdc, inner, s(15), if ((item.state & 0x11) != 0) tokens.ReaderRaised else tokens.ReaderControl);
        const pen = w.CreatePen(0, @max(1, s(1)), tokens.ReaderHint);
        const old = w.SelectObject(item.hdc, pen);
        const x = @divTrunc(rc.left + rc.right, 2);
        const y = @divTrunc(rc.top + rc.bottom, 2);
        _ = w.MoveToEx(item.hdc, x - s(5), y - s(5), null);
        _ = w.LineTo(item.hdc, x + s(5), y + s(5));
        _ = w.MoveToEx(item.hdc, x + s(5), y - s(5), null);
        _ = w.LineTo(item.hdc, x - s(5), y + s(5));
        _ = w.SelectObject(item.hdc, old);
        _ = w.DeleteObject(pen);
        return;
    }
    if (control == .terminal) {
        const on = !state.g_chat_active;
        smooth.fillRoundRect(item.hdc, rc, s(11), if (on) tokens.ReaderForeground else tokens.ReaderRaised);
        const thumb_size = s(16);
        const left = if (on) rc.right - thumb_size - s(3) else rc.left + s(3);
        smooth.fillEllipse(item.hdc, .{ .left = left, .right = left + thumb_size, .top = s(3), .bottom = s(3) + thumb_size }, if (on) tokens.ReaderPanel else tokens.ReaderHint);
        return;
    }
    if (control == .dictation or control == .upload or control == .release_notes) {
        paintText(item.hdc, if (control == .dictation) "Dictation key" else if (control == .upload) "Screencast2 upload key" else "Release notes", rc, 0, tokens.ReaderForeground, 0);
        paintText(item.hdc, if (control == .release_notes) ">" else "Set >", rc, 0, tokens.ReaderHint, w.DT_RIGHT);
    } else {
        if (control == .close or selected or (item.state & 0x11) != 0) smooth.fillRoundRect(item.hdc, rc, s(16), tokens.ReaderRaised);
        var buffer: [40]u8 = undefined;
        const value: []const u8 = switch (control) {
            .close => "x",
            .theme => std.fmt.bufPrint(&buffer, "{s} >", .{currentTheme()}) catch "",
            .font_small => "Small",
            .font_normal => "Normal",
            .font_large => "Large",
            else => "",
        };
        paintText(item.hdc, value, rc, 0, if (selected or control == .close) tokens.ReaderForeground else tokens.ReaderHint, if (control == .theme) w.DT_RIGHT else w.DT_CENTER);
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

fn chooseTheme() void {
    const menu = w.CreatePopupMenu();
    defer _ = w.DestroyMenu(menu);
    const labels = [_]w.LPCWSTR{ L("System"), L("Dark"), L("Mid"), L("Light"), L("AMOLED"), L("Edge gray"), L("Multi Bot") };
    for (labels, 0..) |name, i| _ = w.AppendMenuW(menu, 0, i + 1, name);
    var bounds = std.mem.zeroes(w.RECT);
    _ = w.GetWindowRect(children[index(.theme)], &bounds);
    const selected = @import("fonts.zig").trackPopupMenu(menu, w.TPM_RETURNCMD, bounds.left, bounds.bottom, 0, window, null);
    if (selected > 0 and selected <= labels.len) @import("themes.zig").choose(@enumFromInt(selected - 1));
}

fn dispatch(control: Control) void {
    switch (control) {
        .close => close(),
        .theme => chooseTheme(),
        .font_small => @import("main.zig").setChatFontPoint(12),
        .font_normal => @import("main.zig").setChatFontPoint(14),
        .font_large => @import("main.zig").setChatFontPoint(16),
        .terminal => _ = w.SendMessageW(owner, w.WM_APP_CHAT_TOGGLE, 0, 0),
        .release_notes => {
            const target = owner;
            close();
            if (window == null) _ = @import("focus.zig").PostMessageW(target, w.WM_APP_CHANGELOG_OPEN, 0, 0);
        },
        .dictation, .upload => openKey(control),
    }
    if (window != null and key_window == null) _ = @import("focus.zig").SetFocus(children[index(control)]);
    for (children) |child| {
        if (child != null) _ = w.InvalidateRect(child, null, 1);
    }
}

var color_focus: usize = 0;

fn contentProc(hwnd: w.HANDLE, message: w.UINT, wp: w.WPARAM, lp: w.LPARAM) callconv(w.WINAPI) w.LRESULT {
    const prior_action = state.g_focus_user_action_tick;
    defer state.g_focus_user_action_tick = prior_action;
    state.g_focus_user_action_tick = if (@import("focus.zig").foregroundIsOurs()) state.g_focus_input_tick else 0;
    switch (message) {
        w.WM_LBUTTONDOWN => {
            const x: i16 = @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp)))));
            const y: i16 = @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp)) >> 16)));
            for (0..state.g_lws_count) |workspace| for (0..8) |color| {
                const rc = colorDotRect(workspace, color);
                if (x >= rc.left and x < rc.right and y >= rc.top and y < rc.bottom) {
                    color_focus = workspace;
                    _ = @import("focus.zig").SetFocus(hwnd);
                    chooseWorkspaceColor(workspace, if (color < 7) @intCast(color) else null);
                    return 0;
                }
            };
            return 0;
        },
        w.WM_KEYDOWN => {
            if (state.g_lws_count == 0) return 0;
            color_focus = @min(color_focus, state.g_lws_count - 1);
            if (wp == 0x26 or wp == 0x28) {
                if (wp == 0x26) color_focus -|= 1 else color_focus = @min(color_focus + 1, state.g_lws_count - 1);
                const rc = colorDotRect(color_focus, 0);
                setScroll(scroll + rc.top - s(40));
            } else if (wp == 0x25 or wp == 0x27) {
                const current = @import("session_layout.zig").workspaceColor(color_focus, state.g_ws_colors[color_focus]);
                chooseWorkspaceColor(color_focus, (current + @as(u8, if (wp == 0x25) 6 else 1)) % 7);
            } else if (wp == 0x24 or wp == 0x2e) chooseWorkspaceColor(color_focus, null);
            return 0;
        },
        0x0087 => return 1,
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
            if (notification == 0) dispatch(control);
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
    var rc = client(owner);
    const sidebar = @import("browser_pane.zig").SIDEBAR_W();
    rc.right -= sidebar;
    if (rc.right <= 0 or rc.bottom <= 0) return false;
    var origin = w.POINT{ .x = @import("browser_pane.zig").SIDEBAR_W(), .y = 0 };
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
    }
    const rc = client(owner);
    var origin = w.POINT{ .x = @import("browser_pane.zig").SIDEBAR_W(), .y = 0 };
    _ = w.ClientToScreen(owner, &origin);
    _ = w.MoveWindow(window, origin.x, origin.y, @max(1, rc.right - @import("browser_pane.zig").SIDEBAR_W()), rc.bottom, 1);
    const box = panel();
    _ = w.MoveWindow(viewport, box.left + s(24), box.top + s(80), @max(1, box.right - box.left - s(48)), @max(1, box.bottom - box.top - s(104)), 1);
    const close_rc = controlRect(.close);
    _ = w.MoveWindow(children[index(.close)], close_rc.left, close_rc.top, close_rc.right - close_rc.left, close_rc.bottom - close_rc.top, 1);
    setScroll(scroll);
}

fn panelProc(hwnd: w.HANDLE, message: w.UINT, wp: w.WPARAM, lp: w.LPARAM) callconv(w.WINAPI) w.LRESULT {
    const prior_action = state.g_focus_user_action_tick;
    defer state.g_focus_user_action_tick = prior_action;
    state.g_focus_user_action_tick = if (@import("focus.zig").foregroundIsOurs()) state.g_focus_input_tick else 0;
    if (@import("fonts.zig").menuMessage(message, lp)) |result| return result;
    if (message == 0x0120) if (@import("fonts.zig").menuChar(wp)) |result| return result;
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
            paintText(hdc, "Settings", .{ .left = rc.left + s(24), .right = rc.right - s(80), .top = rc.top + s(24), .bottom = rc.top + s(56) }, 1, tokens.ReaderForeground, 0);
            _ = w.EndPaint(hwnd, &ps);
            return 0;
        },
        0x002b => {
            drawControl(@ptrFromInt(@as(usize, @bitCast(lp))));
            return 1;
        },
        w.WM_COMMAND => {
            const id: u16 = @truncate(wp);
            const notification: u16 = @truncate(wp >> 16);
            if (notification == 0 and (id == 1 or id == 2 or id == @intFromEnum(Control.close))) close();
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
    for (&fonts, 0..) |*font, i| font.* = @import("fonts.zig").create(-s(if (i == 1) @as(i32, 20) else if (i == 2) @as(i32, 12) else 14), 0, 0, 0, if (i == 0) 400 else 600, 0, 0, 0, 0, 0, 0, 5, 0, null);
}

pub fn open(parent: w.HANDLE) void {
    @import("diagnostics.zig").debugLog("[settings] open entered");
    if (window != null) {
        _ = @import("focus.zig").SetForegroundWindow(window);
        return;
    }
    owner = parent;
    previous_focus = w.GetFocus();
    scale = drawing.uiScaled(100);
    scroll = 0;
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
        @import("diagnostics.zig").debugLog("[settings] capture failed");
        release();
        return;
    }
    edit_brush = w.CreateSolidBrush(tokens.ReaderControl);
    window = w.CreateWindowExW(0x10000 | 0x80, L("MultipromptSettings"), L("Settings"), 0x80000000 | 0x02000000, 0, 0, 1, 1, owner, null, instance, null);
    if (window == null) {
        var trace: [100]u8 = undefined;
        @import("diagnostics.zig").debugLog(std.fmt.bufPrint(&trace, "[settings] create failed error={d}", .{w.GetLastError()}) catch "[settings] create failed");
        release();
        return;
    }
    viewport = w.CreateWindowExW(0x10000, L("MultipromptSettingsContent"), L("Settings cards"), 0x40000000 | 0x10000000 | 0x02000000 | 0x00010000, 0, 0, 1, 1, window, null, instance, null);
    for (std.meta.tags(Control)) |control| {
        const parent_window = if (control == .close) window else viewport;
        children[index(control)] = w.CreateWindowExW(0, L("BUTTON"), label(control), 0x40000000 | 0x10000000 | 0x00010000 | 0xb | 0x4000, 0, 0, 1, 1, parent_window, @ptrFromInt(@intFromEnum(control)), instance, null);
        _ = w.SendMessageW(children[index(control)], 0x30, @intFromPtr(fonts[0]), 1);
    }
    reposition();
    @import("browser_pane.zig").updateBrowserVisibility();
    _ = @import("focus.zig").ShowWindow(window, 5);
    _ = @import("focus.zig").SetForegroundWindow(window);
    _ = @import("focus.zig").SetFocus(children[index(.close)]);
    @import("diagnostics.zig").debugLog("[settings] open completed");
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
    viewport = null;
    owner = null;
    previous_focus = null;
}

pub fn close() void {
    if (window == null) return;
    @import("diagnostics.zig").debugLog("[settings] close");
    if (key_window != null) closeKey();
    const target = owner;
    const focus = previous_focus;
    const current = window;
    if (ownsForeground()) state.g_focus_return_hwnd = if (focus != null and w.IsWindow(focus) != 0) focus else target;
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
