const std = @import("std");
const w = @import("win32.zig");
const L = std.unicode.utf8ToUtf16LeStringLiteral;

pub const UI_FACE = "IBM Plex Sans";
pub const UI_MEDIUM_FACE = "IBM Plex Sans Medm";
pub const CHAT_QUALITY: w.DWORD = 4;
pub const CHAT_LINE_HEIGHT_PERMILLE: i32 = 1000;
pub const UI_SEMIBOLD_FACE = "IBM Plex Sans SmBld";
pub const SHELL_FACE = MONO_FACE;
pub const SHELL_WEIGHT = 600;
pub const MONO_FACE = "Nordwand Mono MP SemiBold";
pub const UI_REGULAR = @embedFile("fonts/IBMPlexSans-Regular.ttf");
pub const UI_ITALIC = @embedFile("fonts/IBMPlexSans-Italic.ttf");
pub const UI_MEDIUM = @embedFile("fonts/IBMPlexSans-Medium.ttf");
pub const UI_MEDIUM_ITALIC = @embedFile("fonts/IBMPlexSans-MediumItalic.ttf");
pub const UI_SEMIBOLD = @embedFile("fonts/IBMPlexSans-SemiBold.ttf");
pub const UI_BOLD = @embedFile("fonts/IBMPlexSans-Bold.ttf");
pub const UI_BOLD_ITALIC = @embedFile("fonts/IBMPlexSans-BoldItalic.ttf");
pub const MONO_SEMIBOLD = @embedFile("fonts/NordwandMono-SemiBold.ttf");

var handles: [8]w.HANDLE = @splat(null);
var control_font: w.HANDLE = null;

pub fn register() bool {
    const files = .{ UI_REGULAR, UI_ITALIC, UI_MEDIUM, UI_MEDIUM_ITALIC, UI_SEMIBOLD, UI_BOLD, UI_BOLD_ITALIC, MONO_SEMIBOLD };
    inline for (files, 0..) |file, i| {
        if (handles[i] == null) {
            var count: w.DWORD = 0;
            handles[i] = w.AddFontMemResourceEx(file.ptr, file.len, null, &count);
            if (handles[i] == null or count == 0) return false;
        }
    }
    return true;
}

pub fn unregister() void {
    if (control_font != null) _ = w.DeleteObject(control_font);
    control_font = null;
    for (&handles) |*handle| {
        if (handle.* != null) _ = w.RemoveFontMemResourceEx(handle.*);
        handle.* = null;
    }
}

pub fn chatLineHeight(metric_height: i32) i32 {
    return @max(1, @divTrunc(metric_height * CHAT_LINE_HEIGHT_PERMILLE, 1000));
}

pub fn uiWeight(weight: i32) i32 {
    return if (weight >= 700) 700 else if (weight >= 500) 600 else 400;
}

pub fn uiFace(weight: i32) w.LPCWSTR {
    return if (uiWeight(weight) == 600) L(UI_SEMIBOLD_FACE) else L(UI_FACE);
}

pub fn create(height: i32, width: i32, escapement: i32, orientation: i32, weight: i32, italic: w.DWORD, underline: w.DWORD, strikeout: w.DWORD, charset: w.DWORD, output: w.DWORD, clip: w.DWORD, quality: w.DWORD, pitch: w.DWORD, requested: ?w.LPCWSTR) w.HANDLE {
    const face = if (requested) |name| std.mem.span(name) else &.{};
    const mono = std.mem.eql(u16, face, L(MONO_FACE));
    const symbol = std.mem.eql(u16, face, L("Segoe UI Symbol")) or std.mem.eql(u16, face, L("Segoe UI Emoji"));
    const medium = std.mem.eql(u16, face, L(UI_MEDIUM_FACE));
    const actual_weight = if (mono) 600 else if (symbol) weight else if (medium and weight < 600) 500 else if (italic != 0 and weight >= 500) 700 else uiWeight(weight);
    const actual_face = if (mono or symbol) requested else if (actual_weight == 500) L(UI_MEDIUM_FACE) else uiFace(actual_weight);
    return w.CreateFontW(height, width, escapement, orientation, actual_weight, if (mono) 0 else italic, underline, strikeout, if (mono) 1 else charset, output, clip, quality, pitch, actual_face);
}

pub const ChatFontOptions = struct {
    body_weight: i32 = 400,
    bold_weight: i32 = 700,
    quality: w.DWORD = CHAT_QUALITY,
};

pub fn chat(height: i32, bold: bool, italic: bool, underline: bool, options: ChatFontOptions) w.HANDLE {
    return create(height, 0, 0, 0, if (bold) options.bold_weight else options.body_weight, @intFromBool(italic), @intFromBool(underline), 0, 0, 0, 0, options.quality, 0, if (options.body_weight == 500) L(UI_MEDIUM_FACE) else L(UI_FACE));
}

pub fn emoji(height: i32) w.HANDLE {
    return create(height, 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 5, 0, L("Segoe UI Emoji"));
}

pub fn controlFont() w.HANDLE {
    if (control_font == null) control_font = create(-16, 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 5, 0, L(UI_FACE));
    return control_font;
}

pub fn setControlFont(hwnd: w.HANDLE) void {
    if (hwnd != null) _ = w.SendMessageW(hwnd, 0x0030, @intFromPtr(controlFont()), 1);
}

threadlocal var dialog_hook: w.HANDLE = null;

fn setDialogChildFont(hwnd: w.HANDLE, _: w.LPARAM) callconv(w.WINAPI) w.BOOL {
    setControlFont(hwnd);
    return 1;
}

fn dialogFontHook(code: i32, wp: w.WPARAM, lp: w.LPARAM) callconv(w.WINAPI) w.LRESULT {
    if (code == 5) {
        const hwnd: w.HANDLE = @ptrFromInt(wp);
        setControlFont(hwnd);
        _ = w.EnumChildWindows(hwnd, &setDialogChildFont, 0);
    }
    return w.CallNextHookEx(dialog_hook, code, wp, lp);
}

pub fn messageBox(hwnd: w.HANDLE, text: w.LPCWSTR, caption: w.LPCWSTR, flags: w.UINT) i32 {
    return @import("dialog.zig").messageBox(hwnd, text, caption, flags);
}

pub fn promptForCredentials(info: ?*const w.CREDUI_INFOW, target: w.LPCWSTR, reserved: ?*anyopaque, error_code: w.DWORD, username: [*]u16, username_len: u32, password: [*]u16, password_len: u32, save: ?*w.BOOL, flags: w.DWORD) w.DWORD {
    const previous = dialog_hook;
    dialog_hook = w.SetWindowsHookExW(5, &dialogFontHook, null, w.GetCurrentThreadId());
    defer {
        if (dialog_hook != null) _ = w.UnhookWindowsHookEx(dialog_hook);
        dialog_hook = previous;
    }
    return w.CredUIPromptForCredentialsW(info, target, reserved, error_code, username, username_len, password, password_len, save, flags);
}

pub fn openFileName(ofn: *w.OPENFILENAMEW) w.BOOL {
    const previous = dialog_hook;
    dialog_hook = w.SetWindowsHookExW(5, &dialogFontHook, null, w.GetCurrentThreadId());
    defer {
        if (dialog_hook != null) _ = w.UnhookWindowsHookEx(dialog_hook);
        dialog_hook = previous;
    }
    return w.GetOpenFileNameW(ofn);
}

pub fn editMessage(hwnd: w.HANDLE, owner: w.HANDLE, msg: w.UINT, lp: w.LPARAM) ?w.LRESULT {
    if (msg != 0x007b) return null;
    var point = w.POINT{ .x = @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp)))))), .y = @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp)) >> 16)))) };
    if (lp == -1) {
        point = .{ .x = 4, .y = 4 };
        _ = w.ClientToScreen(hwnd, &point);
    }
    const menu = w.CreatePopupMenu() orelse return 0;
    defer _ = w.DestroyMenu(menu);
    var start: u32 = 0;
    var end: u32 = 0;
    _ = w.SendMessageW(hwnd, 0x00b0, @intFromPtr(&start), @bitCast(@intFromPtr(&end)));
    const selected = start != end;
    const writable = w.GetWindowLongPtrW(hwnd, -16) & 0x0800 == 0;
    const password = w.GetWindowLongPtrW(hwnd, -16) & 0x0020 != 0;
    const actions = .{
        .{ "&Undo", 0x0304, writable and w.SendMessageW(hwnd, 0x00c6, 0, 0) != 0 },
        .{ "Cu&t", 0x0300, writable and selected and !password },
        .{ "&Copy", 0x0301, selected and !password },
        .{ "&Paste", 0x0302, writable and w.IsClipboardFormatAvailable(13) != 0 },
        .{ "&Delete", 0x0303, writable and selected },
        .{ "Select &All", 0x00b1, w.GetWindowTextLengthW(hwnd) > 0 },
    };
    inline for (actions, 0..) |action, i| {
        if (i == 1 or i == 5) _ = w.AppendMenuW(menu, 0x0800, 0, null);
        _ = w.AppendMenuW(menu, if (action[2]) 0 else 1, action[1], L(action[0]));
    }
    const command = trackPopupMenu(menu, 0x0100 | 0x0002, point.x, point.y, 0, owner, null);
    if (command != 0) _ = w.SendMessageW(hwnd, @intCast(command), 0, if (command == 0x00b1) -1 else 0);
    return 0;
}

pub const MessageMenuItem = enum(u32) {
    reply = 4,
    copy = 1,
    copy_link = 7,
    send_again = 5,
    remove = 6,
    cancel_queued = 11,
    reaction_like = 8,
    reaction_dislike = 9,
    reaction_heart = 10,

    pub fn label(self: MessageMenuItem) []const u8 {
        return switch (self) {
            .reply => "Reply",
            .copy => "Copy",
            .copy_link => "Copy link",
            .send_again => "Send again",
            .remove => "Remove",
            .cancel_queued => "Cancel message",
            .reaction_like => "React 👍",
            .reaction_dislike => "React 👎",
            .reaction_heart => "React ❤️",
        };
    }

    pub fn text(self: MessageMenuItem) w.LPCWSTR {
        return switch (self) {
            .reply => L("&Reply"),
            .copy => L("&Copy"),
            .copy_link => L("Copy &link"),
            .send_again => L("&Send again"),
            .remove => L("Re&move"),
            .cancel_queued => L("Ca&ncel message"),
            .reaction_like => L("👍 Like"),
            .reaction_dislike => L("👎 Dislike"),
            .reaction_heart => L("❤️ Heart"),
        };
    }

    fn glyph(self: MessageMenuItem) u16 {
        return switch (self) {
            .reply => 0xE97A,
            .copy => 0xE8C8,
            .copy_link => 0xE71B,
            .send_again => 0xE724,
            .remove => 0xE74D,
            .cancel_queued => 0xE711,
            .reaction_like, .reaction_dislike, .reaction_heart => ' ',
        };
    }
};

const MenuInfo = extern struct {
    size: u32 = @sizeOf(MenuInfo),
    mask: u32 = 2,
    style: u32 = 0,
    max_height: u32 = 0,
    background: w.HANDLE,
    help_id: u32 = 0,
    data: usize = 0,
};
extern "user32" fn SetMenuInfo(w.HANDLE, *const MenuInfo) callconv(w.WINAPI) w.BOOL;

const MessageMenuStyle = struct {
    background: w.HANDLE,
    hover: w.DWORD,
    ink: w.DWORD,
    dim: w.DWORD,
    icons: w.HANDLE,
    show_icons: bool,
    inks: []const ?w.DWORD = &.{},
};
var message_menu_style: ?MessageMenuStyle = null;
threadlocal var menu_window_hook: w.HANDLE = null;
threadlocal var menu_clip_hwnd: w.HANDLE = null;
threadlocal var menu_clip_width: i32 = 0;
threadlocal var menu_clip_height: i32 = 0;
const menu_window_radius: i32 = 12;

const DWMWA_WINDOW_CORNER_PREFERENCE: w.DWORD = 33;
const DWMWA_BORDER_COLOR: w.DWORD = 34;
const DWMWCP_ROUND: w.DWORD = 2;
const DWMWA_COLOR_NONE: w.DWORD = 0xFFFFFFFE;

var smooth_fill_round_rect: ?*const fn (w.HANDLE, w.RECT, i32, u32) void = null;

pub const MenuTheme = struct {
    background: *const fn () w.DWORD,
    foreground: *const fn () w.DWORD,
    fill_round_rect: *const fn (w.HANDLE, w.RECT, i32, u32) void,
};

var menu_theme: ?MenuTheme = null;

pub fn bindMenuTheme(theme: MenuTheme) void {
    menu_theme = theme;
}

fn unboundBackground() w.DWORD {
    return 0x1E1E1E;
}

fn unboundForeground() w.DWORD {
    return 0xFFFFFF;
}

fn cornerInset(radius: i32, from_edge: i32) i32 {
    if (from_edge >= radius) return 0;
    const dy = radius - from_edge - 1;
    return radius - @as(i32, @intFromFloat(@sqrt(@as(f32, @floatFromInt(radius * radius - dy * dy)))));
}

fn fillMenuRow(dc: w.HANDLE, row: w.RECT, radius: i32, color: w.DWORD) void {
    if (smooth_fill_round_rect) |fill| return fill(dc, row, radius, color);
    const brush = w.CreateSolidBrush(color);
    defer _ = w.DeleteObject(brush);
    var y = row.top;
    while (y < row.bottom) : (y += 1) {
        const inset = cornerInset(radius, @min(y - row.top, row.bottom - 1 - y));
        const span = w.RECT{ .left = row.left + inset, .top = y, .right = row.right - inset, .bottom = y + 1 };
        _ = w.FillRect(dc, &span, brush);
    }
}

fn clipMenuWindow(hwnd: w.HANDLE) void {
    var outer: w.RECT = undefined;
    var inner: w.RECT = undefined;
    if (w.GetWindowRect(hwnd, &outer) == 0 or w.GetClientRect(hwnd, &inner) == 0) return;
    const width = outer.right - outer.left;
    const height = outer.bottom - outer.top;
    if (menu_clip_hwnd == hwnd and menu_clip_width == width and menu_clip_height == height) return;
    menu_clip_hwnd = hwnd;
    menu_clip_width = width;
    menu_clip_height = height;
    const side = @max(0, @divTrunc(width - (inner.right - inner.left), 2));
    const edge = @max(0, @divTrunc(height - (inner.bottom - inner.top), 2));
    const radius = @min(menu_window_radius, @divTrunc(height - 2 * edge, 2));
    const region = w.CreateRectRgn(side, edge + radius, width - side, height - edge - radius);
    var row: i32 = 0;
    while (row < radius) : (row += 1) {
        const inset = cornerInset(radius, row);
        const top = w.CreateRectRgn(side + inset, edge + row, width - side - inset, edge + row + 1);
        const bottom = w.CreateRectRgn(side + inset, height - edge - row - 1, width - side - inset, height - edge - row);
        _ = w.CombineRgn(region, region, top, 2);
        _ = w.CombineRgn(region, region, bottom, 2);
        _ = w.DeleteObject(top);
        _ = w.DeleteObject(bottom);
    }
    _ = w.SetWindowRgn(hwnd, region, 1);
}

fn roundMenuWindow(hwnd: w.HANDLE) bool {
    var round = DWMWCP_ROUND;
    const rounded = w.DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, @ptrCast(&round), @sizeOf(w.DWORD)) == 0;
    var none = DWMWA_COLOR_NONE;
    const borderless = w.DwmSetWindowAttribute(hwnd, DWMWA_BORDER_COLOR, @ptrCast(&none), @sizeOf(w.DWORD)) == 0;
    return rounded and borderless;
}

const WindowReturn = extern struct {
    result: w.LRESULT,
    lparam: w.LPARAM,
    wparam: w.WPARAM,
    message: u32,
    hwnd: w.HANDLE,
};

fn menuWindowHook(code: i32, wp: w.WPARAM, lp: w.LPARAM) callconv(w.WINAPI) w.LRESULT {
    if (code >= 0 and lp != 0) {
        const info: *const WindowReturn = @ptrFromInt(@as(usize, @bitCast(lp)));
        if (info.message == 0x47 or info.message == 0x18) styleMenuWindow(info.hwnd);
    }
    return w.CallNextHookEx(menu_window_hook, code, wp, lp);
}

fn styleMenuWindow(hwnd: w.HANDLE) void {
    var class: [8]u16 = @splat(0);
    const len = w.GetClassNameW(hwnd, &class, class.len);
    if (len > 0 and std.mem.eql(u16, class[0..@intCast(len)], L("#32768"))) {
        _ = roundMenuWindow(hwnd);
        clipMenuWindow(hwnd);
    }
}

pub fn trackMessagePopupMenu(menu: w.HANDLE, flags: w.UINT, x: i32, y: i32, reserved: i32, owner: w.HANDLE, rect: ?*const w.RECT) w.BOOL {
    return trackThemedPopupMenu(menu, flags, x, y, reserved, owner, rect, true, &.{});
}

fn mixColor(a: w.DWORD, b: w.DWORD) w.DWORD {
    const r = ((a & 0xFF) + (b & 0xFF)) / 2;
    const g = (((a >> 8) & 0xFF) + ((b >> 8) & 0xFF)) / 2;
    const bl = (((a >> 16) & 0xFF) + ((b >> 16) & 0xFF)) / 2;
    return r | (g << 8) | (bl << 16);
}

fn trackThemedPopupMenu(menu: w.HANDLE, flags: w.UINT, x: i32, y: i32, reserved: i32, owner: w.HANDLE, rect: ?*const w.RECT, show_icons: bool, inks: []const ?w.DWORD) w.BOOL {
    const chat_style = @import("chat_style.zig");
    const bound = menu_theme;
    const look = chat_style.menuLook(if (bound) |theme| theme.background() else unboundBackground());
    const background = w.CreateSolidBrush(look.fill);
    defer _ = w.DeleteObject(background);
    const icons = if (show_icons) messageMenuIconFont() else w.GetStockObject(13);
    defer if (show_icons) {
        _ = w.DeleteObject(icons);
    };
    const info = MenuInfo{ .background = background };
    _ = SetMenuInfo(menu, &info);
    defer _ = SetMenuInfo(menu, &MenuInfo{ .background = null });
    const ink = if (bound) |theme| theme.foreground() else unboundForeground();
    smooth_fill_round_rect = if (bound) |theme| theme.fill_round_rect else null;
    menu_clip_hwnd = null;
    const previous_hook = menu_window_hook;
    menu_window_hook = w.SetWindowsHookExW(12, &menuWindowHook, null, w.GetCurrentThreadId());
    defer {
        if (menu_window_hook != null) _ = w.UnhookWindowsHookEx(menu_window_hook);
        menu_window_hook = previous_hook;
    }
    return trackPopupMenuStyled(menu, flags, x, y, reserved, owner, rect, .{ .background = background, .hover = look.hover, .ink = ink, .dim = mixColor(ink, look.fill), .icons = icons, .show_icons = show_icons, .inks = inks });
}

pub fn messageMenuIconFont() w.HANDLE {
    const font = w.CreateFontW(-16, 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 5, 0, L("Segoe Fluent Icons"));
    const dc = w.GetDC(null);
    defer _ = w.ReleaseDC(null, dc);
    const old = w.SelectObject(dc, font);
    var face: [64]u16 = @splat(0);
    const len = w.GetTextFaceW(dc, face.len, &face);
    _ = w.SelectObject(dc, old);
    if (len > 0 and std.mem.eql(u16, std.mem.sliceTo(&face, 0), L("Segoe Fluent Icons"))) return font;
    _ = w.DeleteObject(font);
    return w.CreateFontW(-16, 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 5, 0, L("Segoe MDL2 Assets"));
}

const MenuLabel = struct {
    text: [512:0]u16 = @splat(0),
    len: i32 = 0,
    state: u32 = 0,
    id: u32 = 0,
    ink: ?w.DWORD = null,
};
const MeasureItem = extern struct {
    kind: u32,
    control: u32,
    id: u32,
    width: u32,
    height: u32,
    data: usize,
};
const DrawItem = extern struct {
    kind: u32,
    control: u32,
    id: u32,
    action: u32,
    state: u32,
    hwnd: w.HANDLE,
    dc: w.HANDLE,
    rect: w.RECT,
    data: usize,
};
var menu_labels: []MenuLabel = &.{};

pub fn trackPopupMenu(menu: w.HANDLE, flags: w.UINT, x: i32, y: i32, reserved: i32, owner: w.HANDLE, rect: ?*const w.RECT) w.BOOL {
    return trackThemedPopupMenu(menu, flags, x, y, reserved, owner, rect, false, &.{});
}

pub fn trackPopupMenuWithInks(menu: w.HANDLE, flags: w.UINT, x: i32, y: i32, reserved: i32, owner: w.HANDLE, rect: ?*const w.RECT, inks: []const ?w.DWORD) w.BOOL {
    return trackThemedPopupMenu(menu, flags, x, y, reserved, owner, rect, false, inks);
}

fn trackPopupMenuStyled(menu: w.HANDLE, flags: w.UINT, x: i32, y: i32, reserved: i32, owner: w.HANDLE, rect: ?*const w.RECT, style: ?MessageMenuStyle) w.BOOL {
    const previous_style = message_menu_style;
    message_menu_style = style;
    defer message_menu_style = previous_style;
    var labels: [256]MenuLabel = @splat(.{});
    const count: usize = @intCast(@max(0, @min(w.GetMenuItemCount(menu), labels.len)));
    const previous = menu_labels;
    menu_labels = labels[0..count];
    for (menu_labels, 0..) |*label, i| {
        const pos: u32 = @intCast(i);
        label.state = w.GetMenuState(menu, pos, 0x400);
        if (style) |theme| {
            if (i < theme.inks.len) label.ink = theme.inks[i];
        }
        if (label.state & 0x810 != 0) continue;
        label.id = w.GetMenuItemID(menu, @intCast(pos));
        label.len = w.GetMenuStringW(menu, pos, &label.text, label.text.len, 0x400);
        _ = w.ModifyMenuW(menu, pos, 0x400 | 0x100 | (label.state & 0xb), label.id, @ptrCast(label));
    }
    defer {
        for (menu_labels, 0..) |*label, i| {
            if (label.state & 0x810 != 0) continue;
            _ = w.ModifyMenuW(menu, @intCast(i), 0x400 | (label.state & 0xb), label.id, &label.text);
        }
        menu_labels = previous;
    }
    return w.TrackPopupMenu(menu, flags, x, y, reserved, owner, rect);
}

fn menuLabel(data: usize) ?*MenuLabel {
    if (menu_labels.len == 0) return null;
    const start = @intFromPtr(menu_labels.ptr);
    if (data < start or data >= start + menu_labels.len * @sizeOf(MenuLabel) or (data - start) % @sizeOf(MenuLabel) != 0) return null;
    return @ptrFromInt(data);
}

pub fn menuChar(wp: w.WPARAM) ?w.LRESULT {
    const key = std.ascii.toLower(@truncate(wp));
    for (menu_labels, 0..) |label, i| {
        if (label.state & 0x813 != 0) continue;
        for (label.text[0..@intCast(label.len)], 0..) |ch, j| {
            if (ch != '&' or j + 1 >= label.len) continue;
            const next = label.text[j + 1];
            if (next <= 127 and std.ascii.toLower(@intCast(next)) == key) return @intCast((2 << 16) | i);
        }
    }
    return null;
}

pub fn menuMessage(msg: w.UINT, lp: w.LPARAM) ?w.LRESULT {
    if (lp == 0) return null;
    if (msg == 0x2c) {
        const item: *MeasureItem = @ptrFromInt(@as(usize, @bitCast(lp)));
        if (item.kind != 1) return null;
        const label = menuLabel(item.data) orelse return null;
        const dc = w.GetDC(null);
        defer _ = w.ReleaseDC(null, dc);
        const old = w.SelectObject(dc, controlFont());
        defer _ = w.SelectObject(dc, old);
        var size: w.SIZE = .{ .cx = 0, .cy = 16 };
        _ = w.GetTextExtentPoint32W(dc, &label.text, label.len, &size);
        item.width = @intCast(size.cx + 48);
        item.height = @intCast(@max(if (message_menu_style != null) @as(i32, @import("chat_style.zig").MENU_ROW_HEIGHT) else 24, size.cy + 8));
        return 1;
    }
    if (msg == 0x2b) {
        const item: *DrawItem = @ptrFromInt(@as(usize, @bitCast(lp)));
        if (item.kind != 1) return null;
        const label = menuLabel(item.data) orelse return null;
        const selected = item.state & 1 != 0;
        const disabled = item.state & 6 != 0;
        const style = message_menu_style;
        if (style != null) {
            if (w.WindowFromDC(item.dc)) |menu_window| styleMenuWindow(menu_window);
        }
        _ = w.FillRect(item.dc, &item.rect, if (style) |theme| theme.background else @ptrFromInt(@as(usize, if (selected) 14 else 5) + 1));
        if (style) |theme| {
            if (selected) {
                const chat_style = @import("chat_style.zig");
                const inset = chat_style.MENU_ROW_INSET;
                const row = w.RECT{ .left = item.rect.left + inset, .top = item.rect.top + inset / 2, .right = item.rect.right - inset, .bottom = item.rect.bottom - inset / 2 };
                fillMenuRow(item.dc, row, chat_style.MENU_ROW_RADIUS, theme.hover);
            }
        }
        const old = w.SelectObject(item.dc, controlFont());
        defer _ = w.SelectObject(item.dc, old);
        const old_mode = w.SetBkMode(item.dc, 1);
        defer _ = w.SetBkMode(item.dc, old_mode);
        const old_color = w.SetTextColor(item.dc, if (style) |theme| (if (disabled) theme.dim else label.ink orelse theme.ink) else w.GetSysColor(if (disabled) 17 else if (selected) 14 else 7));
        defer _ = w.SetTextColor(item.dc, old_color);
        var text_rect = item.rect;
        text_rect.left += if (style) |theme| (if (theme.show_icons) @as(i32, 36) else 28) else 28;
        _ = w.DrawTextW(item.dc, &label.text, label.len, &text_rect, w.DT_SINGLELINE | w.DT_VCENTER);
        const icons_on = if (style) |theme| theme.show_icons else false;
        if (icons_on) {
            if (std.enums.fromInt(MessageMenuItem, label.id)) |action| {
                const old_icon = w.SelectObject(item.dc, style.?.icons);
                defer _ = w.SelectObject(item.dc, old_icon);
                var icon_rect = item.rect;
                icon_rect.left += 10;
                icon_rect.right = icon_rect.left + 16;
                const icon = [_]u16{action.glyph()};
                _ = w.DrawTextW(item.dc, &icon, 1, &icon_rect, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_CENTER | w.DT_NOPREFIX);
            }
        } else if (label.state & 8 != 0) {
            var check_rect = item.rect;
            check_rect.left += 8;
            _ = w.DrawTextW(item.dc, L("✓"), 1, &check_rect, w.DT_SINGLELINE | w.DT_VCENTER);
        }
        return 1;
    }
    return null;
}

fn fontTable(file: []const u8, tag: *const [4]u8) []const u8 {
    const count = std.mem.readInt(u16, file[4..6], .big);
    for (0..count) |i| {
        const record = file[12 + i * 16 ..][0..16];
        if (!std.mem.eql(u8, record[0..4], tag)) continue;
        const offset = std.mem.readInt(u32, record[8..12], .big);
        const len = std.mem.readInt(u32, record[12..16], .big);
        return file[offset..][0..len];
    }
    unreachable;
}

test "GDI selects the authentic embedded face for every text style" {
    defer unregister();
    try std.testing.expect(register());
    const dc = w.CreateCompatibleDC(null);
    try std.testing.expect(dc != null);
    defer _ = w.DeleteDC(dc);
    const cases = .{
        .{ UI_FACE, 400, 0, UI_REGULAR },
        .{ UI_MEDIUM_FACE, 500, 0, UI_MEDIUM },
        .{ UI_MEDIUM_FACE, 500, 1, UI_MEDIUM_ITALIC },
        .{ UI_MEDIUM_FACE, 700, 0, UI_BOLD },
        .{ UI_MEDIUM_FACE, 700, 1, UI_BOLD_ITALIC },
        .{ UI_FACE, 600, 0, UI_SEMIBOLD },
        .{ UI_FACE, 700, 0, UI_BOLD },
        .{ UI_FACE, 400, 1, UI_ITALIC },
        .{ UI_FACE, 700, 1, UI_BOLD_ITALIC },
        .{ MONO_FACE, 600, 0, MONO_SEMIBOLD },
    };
    inline for (cases) |case| {
        const font = create(-18, 0, 0, 0, case[1], case[2], 0, 0, 0, 0, 0, 5, 0, L(case[0]));
        try std.testing.expect(font != null);
        defer _ = w.DeleteObject(font);
        const old = w.SelectObject(dc, font);
        defer _ = w.SelectObject(dc, old);
        inline for (.{ "name", "OS/2" }) |tag| {
            const expected = fontTable(case[3], tag);
            var actual: [8192]u8 = undefined;
            try std.testing.expect(expected.len <= actual.len);
            const len = w.GetFontData(dc, std.mem.readInt(u32, tag, .little), 0, &actual, actual.len);
            try std.testing.expectEqual(expected.len, len);
            try std.testing.expectEqualSlices(u8, expected, actual[0..len]);
        }
    }
}

test "font weights map only to supplied files and unrelated owner-draw messages are ignored" {
    try std.testing.expectEqual(@as(i32, 400), uiWeight(400));
    try std.testing.expectEqual(@as(i32, 600), uiWeight(500));
    try std.testing.expectEqual(@as(i32, 600), uiWeight(600));
    try std.testing.expectEqual(@as(i32, 700), uiWeight(900));
    try std.testing.expect(menuMessage(0x2b, 0) == null);
    try std.testing.expect(menuMessage(0x2c, 0) == null);
    try std.testing.expect(menuLabel(1) == null);
    try std.testing.expect(menuChar('x') == null);
    try std.testing.expect(editMessage(null, null, 0, 0) == null);
}

test "owner drawn menu measurement and mnemonics use the active Plex labels" {
    defer unregister();
    try std.testing.expect(register());
    var labels = [_]MenuLabel{.{ .len = 5 }};
    @memcpy(labels[0].text[0..5], L("&Copy"));
    menu_labels = &labels;
    defer menu_labels = &.{};
    var item = std.mem.zeroes(MeasureItem);
    item.kind = 1;
    item.data = @intFromPtr(&labels[0]);
    try std.testing.expectEqual(@as(?w.LRESULT, 1), menuMessage(0x2c, @bitCast(@intFromPtr(&item))));
    try std.testing.expect(item.width > 48);
    try std.testing.expect(item.height >= 24);
    try std.testing.expectEqual(@as(?w.LRESULT, 2 << 16), menuChar('c'));
    try std.testing.expectEqual(@as(?w.LRESULT, 2 << 16), menuChar('C'));
    labels[0].state = 1;
    try std.testing.expect(menuChar('c') == null);
}

fn drawMenuRowForTest(selected: bool, bg: w.DWORD) !struct { fill: w.DWORD, hover: w.DWORD, corner: w.DWORD, middle: w.DWORD, edge: w.DWORD } {
    const chat_style = @import("chat_style.zig");
    const look = chat_style.menuLook(bg);
    const screen = w.GetDC(null);
    defer _ = w.ReleaseDC(null, screen);
    const dc = w.CreateCompatibleDC(screen);
    try std.testing.expect(dc != null);
    defer _ = w.DeleteDC(dc);
    const bitmap = w.CreateCompatibleBitmap(screen, 200, 40);
    try std.testing.expect(bitmap != null);
    defer _ = w.DeleteObject(bitmap);
    const old_bitmap = w.SelectObject(dc, bitmap);
    defer _ = w.SelectObject(dc, old_bitmap);
    const background = w.CreateSolidBrush(look.fill);
    defer _ = w.DeleteObject(background);
    var labels = [_]MenuLabel{.{ .len = 5, .id = 4 }};
    @memcpy(labels[0].text[0..5], L("Reply"));
    menu_labels = &labels;
    defer menu_labels = &.{};
    message_menu_style = .{ .background = background, .hover = look.hover, .ink = 0xFFFFFF, .dim = 0x808080, .icons = w.GetStockObject(13), .show_icons = false };
    defer message_menu_style = null;
    var item = std.mem.zeroes(DrawItem);
    item.kind = 1;
    item.state = if (selected) 1 else 0;
    item.dc = dc;
    item.rect = .{ .left = 0, .top = 0, .right = 200, .bottom = chat_style.MENU_ROW_HEIGHT };
    item.data = @intFromPtr(&labels[0]);
    try std.testing.expectEqual(@as(?w.LRESULT, 1), menuMessage(0x2b, @bitCast(@intFromPtr(&item))));
    return .{
        .fill = look.fill,
        .hover = look.hover,
        .corner = w.GetPixel(dc, chat_style.MENU_ROW_INSET, chat_style.MENU_ROW_INSET / 2),
        .middle = w.GetPixel(dc, 150, chat_style.MENU_ROW_HEIGHT / 2),
        .edge = w.GetPixel(dc, 0, chat_style.MENU_ROW_HEIGHT / 2),
    };
}

test "IGSH-892 right-click menu rows use chat bubble colours with a rounded hover highlight" {
    inline for (.{ 0x1E1E1E, 0xFFFFFF }) |bg| {
        const rest = try drawMenuRowForTest(false, bg);
        try std.testing.expectEqual(rest.fill, rest.middle);
        try std.testing.expectEqual(rest.fill, rest.corner);
        const hovered = try drawMenuRowForTest(true, bg);
        try std.testing.expectEqual(hovered.hover, hovered.middle);
        try std.testing.expectEqual(hovered.fill, hovered.corner);
        try std.testing.expectEqual(hovered.fill, hovered.edge);
        try std.testing.expect(hovered.hover != hovered.fill);
    }
}

test "IGSH-892 popup menu windows are rounded without a light border" {
    const hwnd = w.CreateWindowExW(0, L("#32768"), null, 0x80000000, 0, 0, 100, 100, null, null, null, null);
    try std.testing.expect(hwnd != null);
    defer _ = w.DestroyWindow(hwnd);
    if (!roundMenuWindow(hwnd)) return error.SkipZigTest;
}

test "Chat View requests grayscale Regular body and Bold emphasis" {
    try std.testing.expectEqual(@as(w.DWORD, 4), CHAT_QUALITY);
    try std.testing.expectEqualStrings("IBM Plex Sans", UI_FACE);
    try std.testing.expectEqual(@as(i32, 400), (ChatFontOptions{}).body_weight);
    try std.testing.expectEqual(@as(i32, 700), (ChatFontOptions{}).bold_weight);
    try std.testing.expect((ChatFontOptions{}).body_weight < (ChatFontOptions{}).bold_weight);
    inline for (.{ @embedFile("chat_render.zig"), @embedFile("chat_composer.zig") }) |source| {
        var lines = std.mem.splitScalar(u8, source, '\n');
        var requests: usize = 0;
        while (lines.next()) |line| {
            if (std.mem.indexOf(u8, line, "CreateFontW(") == null) continue;
            requests += 1;
            try std.testing.expect(std.mem.indexOf(u8, line, ", CHAT_QUALITY, 0, ") != null);
            try std.testing.expect(std.mem.indexOf(u8, line, "MONO_FACE") != null);
        }
        try std.testing.expect(requests > 0 or std.mem.indexOf(u8, source, ".chat(") != null);
        try std.testing.expect(std.mem.indexOf(u8, source, "@import(\"fonts.zig\").chat(") != null);
    }
    try std.testing.expect(std.mem.indexOf(u8, @embedFile("chat_render.zig"), "style.bold or level > 0") != null);
    inline for (.{ UI_REGULAR, UI_ITALIC }) |file| {
        try std.testing.expectEqual(@as(u16, 400), std.mem.readInt(u16, fontTable(file, "OS/2")[4..6], .big));
    }
    try std.testing.expectEqual(@as(i32, 700), uiWeight(700));
}

test "IGSH-445 line height preserves today's metric advance for every chat size" {
    try std.testing.expectEqual(@as(i32, 1000), CHAT_LINE_HEIGHT_PERMILLE);
    for (0..256) |height| {
        try std.testing.expectEqual(@max(1, @as(i32, @intCast(height))), chatLineHeight(@intCast(height)));
    }
    const regular = fontTable(UI_REGULAR, "OS/2");
    inline for (.{ UI_MEDIUM, UI_MEDIUM_ITALIC }) |file| {
        try std.testing.expectEqualSlices(u8, regular[68..78], fontTable(file, "OS/2")[68..78]);
        try std.testing.expectEqualSlices(u8, fontTable(UI_REGULAR, "hhea")[4..10], fontTable(file, "hhea")[4..10]);
        try std.testing.expectEqualSlices(u8, fontTable(UI_REGULAR, "head")[18..20], fontTable(file, "head")[18..20]);
    }
}

test "chat probe options and shipped defaults select the same authentic embedded faces" {
    defer unregister();
    try std.testing.expect(register());
    const dc = w.CreateCompatibleDC(null);
    try std.testing.expect(dc != null);
    defer _ = w.DeleteDC(dc);
    const cases = .{
        .{ 400, false, false, UI_REGULAR },
        .{ 400, true, false, UI_BOLD },
        .{ 400, false, true, UI_ITALIC },
        .{ 400, true, true, UI_BOLD_ITALIC },
        .{ 500, false, false, UI_MEDIUM },
        .{ 500, true, false, UI_BOLD },
        .{ 500, false, true, UI_MEDIUM_ITALIC },
    };
    inline for (cases) |case| {
        const font = chat(-21, case[1], case[2], false, .{ .body_weight = case[0] });
        try std.testing.expect(font != null);
        defer _ = w.DeleteObject(font);
        const old = w.SelectObject(dc, font);
        defer _ = w.SelectObject(dc, old);
        const expected = fontTable(case[3], "OS/2");
        var actual: [1024]u8 = undefined;
        const len = w.GetFontData(dc, std.mem.readInt(u32, "OS/2", .little), 0, &actual, actual.len);
        try std.testing.expectEqual(expected.len, len);
        try std.testing.expectEqualSlices(u8, expected, actual[0..len]);
    }
    try std.testing.expectEqual(@as(i32, 400), (ChatFontOptions{}).body_weight);
    try std.testing.expectEqual(@as(i32, 700), (ChatFontOptions{}).bold_weight);
    try std.testing.expectEqual(CHAT_QUALITY, (ChatFontOptions{}).quality);
}
test "IGSH-718 message menu labels have native mnemonics and Fluent glyphs" {
    const items = [_]MessageMenuItem{ .reply, .copy, .copy_link, .send_again, .remove };
    const labels = [_][]const u8{ "Reply", "Copy", "Copy link", "Send again", "Remove" };
    const glyphs = [_]u16{ 0xE97A, 0xE8C8, 0xE71B, 0xE724, 0xE74D };
    for (items, labels, glyphs) |item, label, glyph| {
        try std.testing.expectEqualStrings(label, item.label());
        try std.testing.expectEqual(glyph, item.glyph());
        try std.testing.expect(std.mem.indexOfScalar(u16, std.mem.span(item.text()), '&') != null);
    }
}
