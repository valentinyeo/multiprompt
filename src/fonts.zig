const std = @import("std");
const w = @import("win32.zig");
const L = std.unicode.utf8ToUtf16LeStringLiteral;

pub const UI_FACE = "IBM Plex Sans";
pub const UI_MEDIUM_FACE = "IBM Plex Sans Medm";
pub const CHAT_QUALITY: w.DWORD = 4;
pub const CHAT_LINE_HEIGHT_PERMILLE: i32 = 1000;
pub const UI_SEMIBOLD_FACE = "IBM Plex Sans SmBld";
pub const SHELL_FACE = "Hack";
pub const SHELL_WEIGHT = 400;
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
    const previous = dialog_hook;
    dialog_hook = w.SetWindowsHookExW(5, &dialogFontHook, null, w.GetCurrentThreadId());
    defer {
        if (dialog_hook != null) _ = w.UnhookWindowsHookEx(dialog_hook);
        dialog_hook = previous;
    }
    return w.MessageBoxW(hwnd, text, caption, flags);
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

const MenuLabel = struct {
    text: [512:0]u16 = @splat(0),
    len: i32 = 0,
    state: u32 = 0,
    id: u32 = 0,
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
    var labels: [256]MenuLabel = @splat(.{});
    const count: usize = @intCast(@max(0, @min(w.GetMenuItemCount(menu), labels.len)));
    const previous = menu_labels;
    menu_labels = labels[0..count];
    for (menu_labels, 0..) |*label, i| {
        const pos: u32 = @intCast(i);
        label.state = w.GetMenuState(menu, pos, 0x400);
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
        item.height = @intCast(@max(24, size.cy + 8));
        return 1;
    }
    if (msg == 0x2b) {
        const item: *DrawItem = @ptrFromInt(@as(usize, @bitCast(lp)));
        if (item.kind != 1) return null;
        const label = menuLabel(item.data) orelse return null;
        const selected = item.state & 1 != 0;
        const disabled = item.state & 6 != 0;
        _ = w.FillRect(item.dc, &item.rect, @ptrFromInt(@as(usize, if (selected) 14 else 5) + 1));
        const old = w.SelectObject(item.dc, controlFont());
        defer _ = w.SelectObject(item.dc, old);
        const old_mode = w.SetBkMode(item.dc, 1);
        defer _ = w.SetBkMode(item.dc, old_mode);
        const old_color = w.SetTextColor(item.dc, w.GetSysColor(if (disabled) 17 else if (selected) 14 else 7));
        defer _ = w.SetTextColor(item.dc, old_color);
        var text_rect = item.rect;
        text_rect.left += 28;
        _ = w.DrawTextW(item.dc, &label.text, label.len, &text_rect, w.DT_SINGLELINE | w.DT_VCENTER);
        if (label.state & 8 != 0) {
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

test "IGSH-445 Chat View requests grayscale Medium body and Bold emphasis" {
    try std.testing.expectEqual(@as(w.DWORD, 4), CHAT_QUALITY);
    try std.testing.expectEqualStrings("IBM Plex Sans Medm", UI_MEDIUM_FACE);
    inline for (.{ @embedFile("chat_render.zig"), @embedFile("chat_composer.zig") }) |source| {
        var lines = std.mem.splitScalar(u8, source, '\n');
        var requests: usize = 0;
        while (lines.next()) |line| {
            if (std.mem.indexOf(u8, line, "CreateFontW(") == null) continue;
            requests += 1;
            try std.testing.expect(std.mem.indexOf(u8, line, ", CHAT_QUALITY, 0, ") != null);
            try std.testing.expect(std.mem.indexOf(u8, line, ", 400, ") == null);
        }
        try std.testing.expect(requests > 0);
        try std.testing.expect(std.mem.indexOf(u8, source, "L(@import(\"fonts.zig\").UI_MEDIUM_FACE)") != null);
    }
    try std.testing.expect(std.mem.indexOf(u8, @embedFile("chat_render.zig"), "if (style.bold or level > 0) 700 else 500") != null);
    const medium_os2 = fontTable(UI_MEDIUM, "OS/2");
    const italic_os2 = fontTable(UI_MEDIUM_ITALIC, "OS/2");
    try std.testing.expectEqual(@as(u16, 500), std.mem.readInt(u16, medium_os2[4..6], .big));
    try std.testing.expectEqual(@as(u16, 500), std.mem.readInt(u16, italic_os2[4..6], .big));
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
