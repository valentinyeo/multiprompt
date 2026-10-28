const std = @import("std");
const app_state = @import("app_state.zig");
const w = @import("win32.zig");
const drawing = @import("drawing.zig");
const focus = @import("focus.zig");
const chat_composer = @import("chat_composer.zig");
const window_layout = @import("window_layout.zig");
const startup = @import("startup.zig");
const fillRoundRect = @import("smooth.zig").fillRoundRect;

const RECT = w.RECT;
const HANDLE = w.HANDLE;
const RGB = startup.RGB;
const L = startup.L;
const uiScaled = drawing.uiScaled;

pub const Item = enum(usize) { approve, stop, terminal, rename, history, resync, waiting, remind, archive, model, end_session, remove };
const ITEM_COUNT = std.meta.tags(Item).len;
const CARD_COUNT = 5;

pub const State = struct {
    enabled: [ITEM_COUNT]bool = @splat(true),
    hover: ?Item = null,
    model: [128]u16 = @splat(0),
    model_len: usize = 0,
};

const Colors = struct {
    panel: u32,
    outline: u32,
    card: u32,
    raised: u32,
    text: u32,
    hint: u32,
    red: u32,
};

fn colors() Colors {
    if (app_state.g_light_theme) return .{
        .panel = RGB(250, 250, 251),
        .outline = RGB(222, 224, 228),
        .card = RGB(241, 242, 244),
        .raised = RGB(228, 230, 234),
        .text = RGB(28, 28, 30),
        .hint = RGB(128, 128, 134),
        .red = RGB(198, 48, 42),
    };
    return .{
        .panel = RGB(0x18, 0x18, 0x18),
        .outline = RGB(0x2E, 0x2E, 0x2E),
        .card = RGB(0x1F, 0x1F, 0x1F),
        .raised = RGB(0x35, 0x35, 0x35),
        .text = RGB(0xF2, 0xF2, 0xF2),
        .hint = RGB(0x8A, 0x8A, 0x8A),
        .red = RGB(0xF2, 0x8B, 0x82),
    };
}

fn label(item: Item) []const u8 {
    return switch (item) {
        .approve => "Approve",
        .stop => "Stop",
        .terminal => "Terminal",
        .rename => "Rename",
        .history => "History",
        .resync => "Resync chat",
        .waiting => "Waiting",
        .remind => "Remind me",
        .archive => "Archive",
        .model => "Model",
        .end_session => "End session",
        .remove => "Remove from list",
    };
}

fn glyph(item: Item) [*:0]const u16 {
    return switch (item) {
        .approve => L("\u{2713}"),
        .stop => L("\u{25A0}"),
        else => L(">_"),
    };
}

pub const Geometry = struct {
    panel: RECT,
    cards: [CARD_COUNT]RECT,
    cells: [ITEM_COUNT]RECT,
};

pub fn geometry(bounds: RECT, anchor: RECT) Geometry {
    const pad = uiScaled(8);
    const gap = uiScaled(8);
    const top_h = uiScaled(64);
    const width = @min(uiScaled(264), bounds.right - bounds.left - uiScaled(16));
    const right = @min(anchor.right, bounds.right - uiScaled(8));
    const left = @max(bounds.left + uiScaled(8), right - width);
    const panel_top = anchor.bottom + uiScaled(8);
    const spare = bounds.bottom - uiScaled(8) - panel_top - 2 * pad - top_h - 4 * gap;
    const row_h = std.math.clamp(@divTrunc(spare, 9), uiScaled(24), uiScaled(38));
    const inner_l = left + pad;
    const inner_r = right - pad;
    var g: Geometry = std.mem.zeroes(Geometry);
    var y = panel_top + pad;
    g.cards[0] = .{ .left = inner_l, .top = y, .right = inner_r, .bottom = y + top_h };
    const cell_w = @divTrunc(inner_r - inner_l, 3);
    for (0..3) |i| {
        const n: i32 = @intCast(i);
        g.cells[i] = .{ .left = inner_l + n * cell_w, .top = y, .right = if (i == 2) inner_r else inner_l + (n + 1) * cell_w, .bottom = y + top_h };
    }
    y += top_h + gap;
    const groups = [_][]const Item{
        &.{ .rename, .history, .resync },
        &.{ .waiting, .remind, .archive },
        &.{.model},
        &.{ .end_session, .remove },
    };
    for (groups, 0..) |group, gi| {
        const count: i32 = @intCast(group.len);
        g.cards[gi + 1] = .{ .left = inner_l, .top = y, .right = inner_r, .bottom = y + row_h * count };
        for (group, 0..) |item, ri| {
            const n: i32 = @intCast(ri);
            g.cells[@intFromEnum(item)] = .{ .left = inner_l, .top = y + n * row_h, .right = inner_r, .bottom = y + (n + 1) * row_h };
        }
        y += row_h * count + gap;
    }
    g.panel = .{ .left = left, .top = panel_top, .right = right, .bottom = y - gap + pad };
    return g;
}

fn inside(rc: RECT, x: i32, y: i32) bool {
    return x >= rc.left and x < rc.right and y >= rc.top and y < rc.bottom;
}

fn shrink(rc: RECT, by: i32) RECT {
    return .{ .left = rc.left + by, .top = rc.top + by, .right = rc.right - by, .bottom = rc.bottom - by };
}

fn solid(dc: HANDLE, rc: RECT, color: u32) void {
    var r = rc;
    const brush = w.CreateSolidBrush(color);
    _ = w.FillRect(dc, &r, brush);
    _ = w.DeleteObject(brush);
}

fn hitItem(g: *const Geometry, x: i32, y: i32) ?Item {
    for (std.meta.tags(Item)) |item| {
        if (inside(g.cells[@intFromEnum(item)], x, y)) return item;
    }
    return null;
}

pub fn paint(dc: HANDLE, bounds: RECT, anchor: RECT, state: *const State) void {
    const g = geometry(bounds, anchor);
    const c = colors();
    const edge = @max(1, uiScaled(1));
    const panel_r = uiScaled(20);
    const card_r = uiScaled(14);
    fillRoundRect(dc, g.panel, panel_r, c.outline);
    fillRoundRect(dc, shrink(g.panel, edge), panel_r - edge, c.panel);
    for (g.cards) |card| {
        fillRoundRect(dc, card, card_r, c.outline);
        fillRoundRect(dc, shrink(card, edge), card_r - edge, c.card);
    }
    _ = w.SetBkMode(dc, w.TRANSPARENT);
    const flags = w.DT_SINGLELINE | w.DT_VCENTER | w.DT_NOPREFIX | w.DT_END_ELLIPSIS;
    for (std.meta.tags(Item)) |item| {
        const idx = @intFromEnum(item);
        const cell = g.cells[idx];
        const enabled = state.enabled[idx];
        if (enabled and state.hover == item) {
            fillRoundRect(dc, shrink(cell, uiScaled(4)), uiScaled(10), c.raised);
        }
        const ink = if (!enabled and item != .model) c.hint else if (item == .end_session or item == .remove) c.red else c.text;
        _ = w.SetTextColor(dc, ink);
        if (idx < 3) {
            _ = w.SelectObject(dc, drawing.uiFontTitle());
            var glyph_rc = RECT{ .left = cell.left, .top = cell.top + uiScaled(6), .right = cell.right, .bottom = cell.top + @divTrunc((cell.bottom - cell.top) * 55, 100) };
            _ = w.DrawTextW(dc, glyph(item), -1, &glyph_rc, flags | w.DT_CENTER);
            _ = w.SelectObject(dc, drawing.uiFontSubtitle());
            var text_rc = RECT{ .left = cell.left, .top = cell.top + @divTrunc((cell.bottom - cell.top) * 50, 100), .right = cell.right, .bottom = cell.bottom - uiScaled(4) };
            drawing.drawAscii(dc, label(item), &text_rc, flags | w.DT_CENTER);
            continue;
        }
        if (idx != @intFromEnum(Item.rename) and idx != @intFromEnum(Item.waiting) and idx != @intFromEnum(Item.model) and idx != @intFromEnum(Item.end_session)) {
            solid(dc, .{ .left = cell.left + uiScaled(14), .top = cell.top, .right = cell.right - uiScaled(14), .bottom = cell.top + edge }, c.outline);
        }
        _ = w.SelectObject(dc, drawing.uiFontTitle());
        var row_rc = RECT{ .left = cell.left + uiScaled(14), .top = cell.top, .right = cell.right - uiScaled(14), .bottom = cell.bottom };
        drawing.drawAscii(dc, label(item), &row_rc, flags);
        if (item == .model and state.model_len > 0) {
            _ = w.SelectObject(dc, drawing.uiFontSubtitle());
            _ = w.SetTextColor(dc, c.hint);
            var value_rc = RECT{ .left = cell.left + uiScaled(90), .top = cell.top, .right = cell.right - uiScaled(14), .bottom = cell.bottom };
            _ = w.DrawTextW(dc, &state.model, @intCast(state.model_len), &value_rc, flags | w.DT_RIGHT);
        }
    }
}

pub const Backdrop = struct {
    dc: HANDLE,
    bitmap: HANDLE,
    old: HANDLE,
    width: i32,
    height: i32,

    pub fn release(self: *Backdrop) void {
        _ = w.SelectObject(self.dc, self.old);
        _ = w.DeleteObject(self.bitmap);
        _ = w.DeleteDC(self.dc);
    }
};

pub fn captureBackdrop(src: HANDLE, sx: i32, sy: i32, width: i32, height: i32, rop: u32) ?Backdrop {
    if (width <= 0 or height <= 0) return null;
    const dc = w.CreateCompatibleDC(null) orelse return null;
    const info: w.BITMAPINFO = .{ .header = .{ .width = width, .height = -height } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0) orelse {
        _ = w.DeleteDC(dc);
        return null;
    };
    const old = w.SelectObject(dc, bitmap);
    _ = w.BitBlt(dc, 0, 0, width, height, src, sx, sy, rop);
    _ = w.GdiFlush();
    const pixels = @as([*]u32, @ptrCast(@alignCast(bits.?)))[0..@as(usize, @intCast(width)) * @as(usize, @intCast(height))];
    for (pixels) |*px| {
        const v = px.*;
        const r = ((v >> 16) & 0xFF) * 5 / 12;
        const gr = ((v >> 8) & 0xFF) * 5 / 12;
        const b = (v & 0xFF) * 5 / 12;
        px.* = (r << 16) | (gr << 8) | b;
    }
    return .{ .dc = dc, .bitmap = bitmap, .old = old, .width = width, .height = height };
}

pub fn snapshot(state: *State) void {
    state.* = .{};
    const idx = app_state.active_shell;
    const tmux = idx < app_state.shell_count and app_state.shells[idx].tmux_session_len > 0;
    state.enabled[@intFromEnum(Item.approve)] = window_layout.chatPermissionVisible();
    state.enabled[@intFromEnum(Item.stop)] = window_layout.chatStopVisible();
    state.enabled[@intFromEnum(Item.remind)] = tmux;
    state.enabled[@intFromEnum(Item.end_session)] = tmux;
    state.enabled[@intFromEnum(Item.model)] = false;
    const session = @import("chat_session.zig");
    if (session.chatHistoryEntry(session.chatFileIdentity())) |entry| {
        state.model_len = entry.history.status.model_len;
        @memcpy(state.model[0..state.model_len], entry.history.status.model[0..state.model_len]);
    }
}

var g_hwnd: HANDLE = null;
var g_class_registered = false;
var g_open = false;
var g_state: State = .{};
var g_backdrop: ?Backdrop = null;
var g_bounds: RECT = std.mem.zeroes(RECT);
var g_anchor: RECT = std.mem.zeroes(RECT);

pub fn isOpen() bool {
    return g_open;
}

fn ensureClass() void {
    if (g_class_registered) return;
    const wc = w.WNDCLASSEXW{ .cbSize = @sizeOf(w.WNDCLASSEXW), .style = 0, .lpfnWndProc = wndProc, .cbClsExtra = 0, .cbWndExtra = 0, .hInstance = w.GetModuleHandleW(null), .hIcon = null, .hCursor = w.LoadCursorW(null, @ptrFromInt(32512)), .hbrBackground = null, .lpszMenuName = null, .lpszClassName = L("MultiPromptMoreMenu"), .hIconSm = null };
    _ = w.RegisterClassExW(&wc);
    g_class_registered = true;
}

pub fn open() void {
    if (g_open) return;
    const main = app_state.g_main_hwnd orelse return;
    if (!chat_composer.chatViewOwnsInput()) return;
    const title = drawing.chatTitleLayout() orelse return;
    var client: w.RECT = undefined;
    _ = w.GetClientRect(main, &client);
    if (drawing.reconnectButtonRect(client.right) != null) return;
    const pane = chat_composer.chatViewLayout().pane;
    const width = pane.right - pane.left;
    const height = pane.bottom - pane.top;
    if (width <= 0 or height <= 0) return;
    ensureClass();
    var origin = w.POINT{ .x = pane.left, .y = pane.top };
    _ = w.ClientToScreen(main, &origin);
    const screen = w.GetDC(null);
    const backdrop = captureBackdrop(screen, origin.x, origin.y, width, height, 0x40CC0020);
    _ = w.ReleaseDC(null, screen);
    if (backdrop == null) return;
    if (g_hwnd == null) g_hwnd = w.CreateWindowExW(0, L("MultiPromptMoreMenu"), L(""), w.WS_CHILD | w.WS_CLIPSIBLINGS, pane.left, pane.top, width, height, main, null, null, null);
    if (g_hwnd == null) {
        var unused = backdrop.?;
        unused.release();
        return;
    }
    g_backdrop = backdrop;
    snapshot(&g_state);
    g_bounds = .{ .left = 0, .top = 0, .right = width, .bottom = height };
    g_anchor = .{ .left = title.more.left - pane.left, .top = title.more.top - pane.top, .right = title.more.right - pane.left, .bottom = title.more.bottom - pane.top };
    g_open = true;
    _ = w.MoveWindow(g_hwnd, pane.left, pane.top, width, height, 0);
    _ = focus.SetWindowPos(g_hwnd, w.HWND_TOP, 0, 0, 0, 0, w.SWP_NOMOVE | w.SWP_NOSIZE | w.SWP_NOACTIVATE | w.SWP_SHOWWINDOW);
    _ = w.SetCapture(g_hwnd);
    _ = w.InvalidateRect(g_hwnd, null, 0);
    if (chat_composer.chatComposerFocusAllowed()) _ = focus.SetFocus(app_state.g_chat_composer_hwnd);
}

pub fn close() void {
    if (!g_open) return;
    g_open = false;
    _ = w.ReleaseCapture();
    if (g_hwnd != null) _ = focus.ShowWindow(g_hwnd, w.SW_HIDE);
    if (g_backdrop) |*backdrop| backdrop.release();
    g_backdrop = null;
    if (app_state.g_main_hwnd != null) _ = w.InvalidateRect(app_state.g_main_hwnd, null, 0);
}

fn activate(item: Item) void {
    if (!g_state.enabled[@intFromEnum(item)]) return;
    close();
    _ = focus.PostMessageW(app_state.g_main_hwnd, w.WM_APP_MORE_MENU_ACTION, @intFromEnum(item), 0);
}

fn step(direction: i32) void {
    const tags = std.meta.tags(Item);
    var current: i32 = if (g_state.hover) |item| @intCast(@intFromEnum(item)) else if (direction > 0) -1 else @as(i32, @intCast(tags.len));
    var tries: usize = 0;
    while (tries < tags.len) : (tries += 1) {
        current = @mod(current + direction, @as(i32, @intCast(tags.len)));
        const candidate: Item = @enumFromInt(@as(usize, @intCast(current)));
        if (g_state.enabled[@intFromEnum(candidate)]) {
            g_state.hover = candidate;
            _ = w.InvalidateRect(g_hwnd, null, 0);
            return;
        }
    }
}

pub fn key(vk: usize) bool {
    if (!g_open) return false;
    switch (vk) {
        w.VK_ESCAPE => close(),
        0x26 => step(-1),
        0x28 => step(1),
        0x0D => {
            if (g_state.hover) |item| activate(item) else close();
        },
        0x10, 0x11, 0x12 => return false,
        else => {
            close();
            return false;
        },
    }
    return true;
}

fn paintWindow(hwnd: HANDLE) void {
    var ps: w.PAINTSTRUCT = undefined;
    const target = w.BeginPaint(hwnd, &ps);
    if (target == null) return;
    defer _ = w.EndPaint(hwnd, &ps);
    const backdrop = g_backdrop orelse return;
    const memory = w.CreateCompatibleDC(target) orelse return;
    defer _ = w.DeleteDC(memory);
    const bitmap = w.CreateCompatibleBitmap(target, backdrop.width, backdrop.height) orelse return;
    defer _ = w.DeleteObject(bitmap);
    const old = w.SelectObject(memory, bitmap);
    defer _ = w.SelectObject(memory, old);
    _ = w.BitBlt(memory, 0, 0, backdrop.width, backdrop.height, backdrop.dc, 0, 0, 0x00CC0020);
    paint(memory, g_bounds, g_anchor, &g_state);
    _ = w.BitBlt(target, 0, 0, backdrop.width, backdrop.height, memory, 0, 0, 0x00CC0020);
}

fn wndProc(hwnd: HANDLE, msg: w.UINT, wp: w.WPARAM, lp: w.LPARAM) callconv(w.WINAPI) w.LRESULT {
    const prior_focus_action = app_state.g_focus_user_action_tick;
    app_state.g_focus_user_action_tick = focus.focusGuardDispatchTick(msg, wp, lp);
    defer app_state.g_focus_user_action_tick = prior_focus_action;
    switch (msg) {
        w.WM_ERASEBKGND => return 1,
        w.WM_PAINT => {
            paintWindow(hwnd);
            return 0;
        },
        w.WM_MOUSEMOVE => {
            const g = geometry(g_bounds, g_anchor);
            const hit = hitItem(&g, startup.GET_X(lp), startup.GET_Y(lp));
            const next: ?Item = if (hit) |item| (if (g_state.enabled[@intFromEnum(item)]) item else null) else null;
            if (next != g_state.hover) {
                g_state.hover = next;
                _ = w.InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        w.WM_LBUTTONDOWN => {
            const g = geometry(g_bounds, g_anchor);
            const x = startup.GET_X(lp);
            const y = startup.GET_Y(lp);
            if (hitItem(&g, x, y)) |item| {
                activate(item);
            } else if (!inside(g.panel, x, y)) {
                close();
            }
            return 0;
        },
        w.WM_RBUTTONDOWN => {
            close();
            return 0;
        },
        0x0215 => {
            close();
            return 0;
        },
        else => return w.DefWindowProcW(hwnd, msg, wp, lp),
    }
}
