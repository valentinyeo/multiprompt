const std = @import("std");
const app_state = @import("app_state.zig");
const w = @import("win32.zig");
const drawing = @import("drawing.zig");
const focus = @import("focus.zig");
const chat_composer = @import("chat_composer.zig");
const startup = @import("startup.zig");
const more_menu = @import("more_menu.zig");
const fillRoundRect = @import("smooth.zig").fillRoundRect;

const RECT = w.RECT;
const HANDLE = w.HANDLE;
const L = startup.L;
const uiScaled = drawing.uiScaled;

pub const Item = enum(usize) { attach, model_opus, model_sonnet, model_haiku, effort_low, effort_medium, effort_high, mode_ask, mode_edits, mode_plan, mode_bypass };
const ITEM_COUNT = std.meta.tags(Item).len;

const Section = struct { title: ?[]const u8, items: []const Item };

const sections = [_]Section{
    .{ .title = null, .items = &.{.attach} },
    .{ .title = "Model", .items = &.{ .model_opus, .model_sonnet, .model_haiku } },
    .{ .title = "Effort", .items = &.{ .effort_low, .effort_medium, .effort_high } },
    .{ .title = "Permission level", .items = &.{ .mode_ask, .mode_edits, .mode_plan, .mode_bypass } },
};

pub const State = struct {
    shown: [ITEM_COUNT]bool = @splat(false),
    checked: [ITEM_COUNT]bool = @splat(false),
    hover: ?Item = null,
};

fn label(item: Item) []const u8 {
    return switch (item) {
        .attach => "Attach file",
        .model_opus => "Opus",
        .model_sonnet => "Sonnet",
        .model_haiku => "Haiku",
        .effort_low => "Low",
        .effort_medium => "Medium",
        .effort_high => "High",
        .mode_ask => "Ask",
        .mode_edits => "Accept edits",
        .mode_plan => "Plan",
        .mode_bypass => "Bypass",
    };
}

pub const Geometry = struct {
    panel: RECT,
    cards: [sections.len]RECT,
    headers: [sections.len]RECT,
    cells: [ITEM_COUNT]RECT,
    section_shown: [sections.len]bool,
};

fn sectionShown(section: Section, shown: *const [ITEM_COUNT]bool) bool {
    for (section.items) |item| {
        if (shown[@intFromEnum(item)]) return true;
    }
    return false;
}

pub fn geometry(bounds: RECT, anchor: RECT, shown: *const [ITEM_COUNT]bool) Geometry {
    const pad = uiScaled(8);
    const gap = uiScaled(8);
    var rows: i32 = 0;
    var cards: i32 = 0;
    for (sections) |section| {
        if (!sectionShown(section, shown)) continue;
        cards += 1;
        rows += @intCast(section.items.len);
        if (section.title != null) rows += 1;
    }
    var g: Geometry = std.mem.zeroes(Geometry);
    if (rows == 0) return g;
    const fixed_height = 2 * pad + (cards - 1) * gap;
    const bottom = @min(anchor.top - uiScaled(8), bounds.bottom - uiScaled(8));
    const available = bottom - (bounds.top + uiScaled(8)) - fixed_height;
    const row_h = @min(uiScaled(32), @max(1, @divTrunc(available, rows)));
    const width = @min(uiScaled(240), bounds.right - bounds.left - uiScaled(16));
    const right_limit = bounds.right - uiScaled(8);
    const left = @max(bounds.left + uiScaled(8), @min(anchor.left, right_limit - width));
    const right = left + width;
    const height = fixed_height + rows * row_h;
    const panel_top = @max(bounds.top + uiScaled(8), bottom - height);
    const inner_l = left + pad;
    const inner_r = right - pad;
    var y = panel_top + pad;
    for (sections, 0..) |section, si| {
        if (!sectionShown(section, shown)) continue;
        g.section_shown[si] = true;
        const card_top = y;
        if (section.title != null) {
            g.headers[si] = .{ .left = inner_l, .top = y, .right = inner_r, .bottom = y + row_h };
            y += row_h;
        }
        for (section.items) |item| {
            if (!shown[@intFromEnum(item)]) continue;
            g.cells[@intFromEnum(item)] = .{ .left = inner_l, .top = y, .right = inner_r, .bottom = y + row_h };
            y += row_h;
        }
        g.cards[si] = .{ .left = inner_l, .top = card_top, .right = inner_r, .bottom = y };
        y += gap;
    }
    g.panel = .{ .left = left, .top = panel_top, .right = right, .bottom = y - gap + pad };
    return g;
}

fn inside(rc: RECT, x: i32, y: i32) bool {
    return x >= rc.left and x < rc.right and y >= rc.top and y < rc.bottom;
}

fn hitItem(g: *const Geometry, shown: *const [ITEM_COUNT]bool, x: i32, y: i32) ?Item {
    for (std.meta.tags(Item)) |item| {
        if (shown[@intFromEnum(item)] and inside(g.cells[@intFromEnum(item)], x, y)) return item;
    }
    return null;
}

test "IGSH-1521 plus menu rows fit above the plus button and hit independently" {
    var shown: [ITEM_COUNT]bool = @splat(true);
    for ([_]i32{ 360, 480, 640, 900 }) |height| {
        const bounds = RECT{ .left = 0, .top = 0, .right = 700, .bottom = height };
        const anchor = RECT{ .left = 20, .top = height - 60, .right = 52, .bottom = height - 28 };
        const g = geometry(bounds, anchor, &shown);
        try std.testing.expect(g.panel.top >= bounds.top);
        try std.testing.expect(g.panel.bottom <= anchor.top);
        for (std.meta.tags(Item)) |item| {
            const cell = g.cells[@intFromEnum(item)];
            try std.testing.expect(cell.bottom > cell.top and cell.right > cell.left);
            try std.testing.expect(cell.left >= g.panel.left and cell.right <= g.panel.right);
            try std.testing.expect(cell.top >= g.panel.top and cell.bottom <= g.panel.bottom);
            try std.testing.expectEqual(@as(?Item, item), hitItem(&g, &shown, @divTrunc(cell.left + cell.right, 2), @divTrunc(cell.top + cell.bottom, 2)));
        }
    }
    shown = @splat(false);
    shown[@intFromEnum(Item.attach)] = true;
    const only = geometry(.{ .left = 0, .top = 0, .right = 700, .bottom = 480 }, .{ .left = 20, .top = 420, .right = 52, .bottom = 452 }, &shown);
    try std.testing.expect(only.section_shown[0] and !only.section_shown[1]);
    std.debug.print("IGSH-1521 plus menu geometry verified at four heights\n", .{});
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

pub fn paint(dc: HANDLE, bounds: RECT, anchor: RECT, state: *const State) void {
    const g = geometry(bounds, anchor, &state.shown);
    if (g.panel.right <= g.panel.left) return;
    const c = more_menu.colors();
    const edge = @max(1, uiScaled(1));
    const panel_r = uiScaled(20);
    const card_r = uiScaled(14);
    fillRoundRect(dc, g.panel, panel_r, c.outline);
    fillRoundRect(dc, shrink(g.panel, edge), panel_r - edge, c.panel);
    _ = w.SetBkMode(dc, w.TRANSPARENT);
    const flags = w.DT_SINGLELINE | w.DT_VCENTER | w.DT_NOPREFIX | w.DT_END_ELLIPSIS;
    for (sections, 0..) |section, si| {
        if (!g.section_shown[si]) continue;
        const card = g.cards[si];
        fillRoundRect(dc, card, card_r, c.outline);
        fillRoundRect(dc, shrink(card, edge), card_r - edge, c.card);
        if (section.title) |title| {
            const head = g.headers[si];
            _ = w.SelectObject(dc, drawing.uiFontSubtitle());
            _ = w.SetTextColor(dc, c.hint);
            var head_rc = RECT{ .left = head.left + uiScaled(14), .top = head.top, .right = head.right - uiScaled(14), .bottom = head.bottom };
            drawing.drawAscii(dc, title, &head_rc, flags);
        }
        var first = true;
        for (section.items) |item| {
            const idx = @intFromEnum(item);
            if (!state.shown[idx]) continue;
            const cell = g.cells[idx];
            if (state.hover == item) fillRoundRect(dc, shrink(cell, uiScaled(4)), uiScaled(10), c.raised);
            if (!first or section.title != null) {
                solid(dc, .{ .left = cell.left + uiScaled(14), .top = cell.top, .right = cell.right - uiScaled(14), .bottom = cell.top + edge }, c.outline);
            }
            first = false;
            _ = w.SetTextColor(dc, c.text);
            _ = w.SelectObject(dc, drawing.uiFontTitle());
            var row_rc = RECT{ .left = cell.left + uiScaled(14), .top = cell.top, .right = cell.right - uiScaled(40), .bottom = cell.bottom };
            drawing.drawAscii(dc, label(item), &row_rc, flags);
            if (state.checked[idx]) {
                var mark_rc = RECT{ .left = cell.right - uiScaled(40), .top = cell.top, .right = cell.right - uiScaled(14), .bottom = cell.bottom };
                _ = w.DrawTextW(dc, L("\u{2713}"), -1, &mark_rc, flags | w.DT_RIGHT);
            }
        }
    }
}

var g_hwnd: HANDLE = null;
var g_class_registered = false;
var g_open = false;
var g_state: State = .{};
var g_backdrop: ?more_menu.Backdrop = null;
var g_bounds: RECT = std.mem.zeroes(RECT);
var g_anchor: RECT = std.mem.zeroes(RECT);

pub fn isOpen() bool {
    return g_open;
}

fn snapshot(state: *State) void {
    state.* = .{};
    state.shown[@intFromEnum(Item.attach)] = true;
    if (app_state.active_shell >= app_state.shell_count) return;
    const chat_send = @import("chat_send.zig");
    chat_send.chatModeCapturePicker();
    const session = @import("chat_session.zig");
    if (session.chatSettingsEligible()) {
        const selected: @import("chat_live.zig").Settings = @import("chat_live.zig").settings(app_state.shells[app_state.active_shell].shell_id) orelse .{};
        for ([_]Item{ .model_opus, .model_sonnet, .model_haiku, .effort_low, .effort_medium, .effort_high }) |item| state.shown[@intFromEnum(item)] = true;
        state.checked[@intFromEnum(Item.model_opus)] = selected.model == .opus;
        state.checked[@intFromEnum(Item.model_sonnet)] = selected.model == .sonnet;
        state.checked[@intFromEnum(Item.model_haiku)] = selected.model == .haiku;
        state.checked[@intFromEnum(Item.effort_low)] = selected.effort == .low;
        state.checked[@intFromEnum(Item.effort_medium)] = selected.effort == .medium;
        state.checked[@intFromEnum(Item.effort_high)] = selected.effort == .high;
    }
    const identity = session.chatFileIdentityForShell(app_state.active_shell);
    if (std.mem.eql(u8, identity.provider(), "claude") and chat_send.chatModePickerAvailable()) {
        for ([_]Item{ .mode_ask, .mode_edits, .mode_plan, .mode_bypass }) |item| state.shown[@intFromEnum(item)] = true;
    }
}

fn ensureClass() void {
    if (g_class_registered) return;
    const wc = w.WNDCLASSEXW{ .cbSize = @sizeOf(w.WNDCLASSEXW), .style = 0, .lpfnWndProc = wndProc, .cbClsExtra = 0, .cbWndExtra = 0, .hInstance = w.GetModuleHandleW(null), .hIcon = null, .hCursor = w.LoadCursorW(null, @ptrFromInt(32512)), .hbrBackground = null, .lpszMenuName = null, .lpszClassName = L("MultiPromptPlusMenu"), .hIconSm = null };
    _ = w.RegisterClassExW(&wc);
    g_class_registered = true;
}

pub fn open() void {
    if (g_open) return;
    const main = app_state.g_main_hwnd orelse return;
    if (!chat_composer.chatViewOwnsInput()) return;
    const layout = chat_composer.chatViewLayout();
    const pane = layout.pane;
    const width = pane.right - pane.left;
    const height = pane.bottom - pane.top;
    if (width <= 0 or height <= 0) return;
    ensureClass();
    var origin = w.POINT{ .x = pane.left, .y = pane.top };
    _ = w.ClientToScreen(main, &origin);
    const screen = w.GetDC(null);
    const backdrop = more_menu.captureBackdrop(screen, origin.x, origin.y, width, height, 0x40CC0020);
    _ = w.ReleaseDC(null, screen);
    if (backdrop == null) return;
    if (g_hwnd == null) g_hwnd = w.CreateWindowExW(0, L("MultiPromptPlusMenu"), L(""), w.WS_CHILD | w.WS_CLIPSIBLINGS, pane.left, pane.top, width, height, main, null, null, null);
    if (g_hwnd == null) {
        var unused = backdrop.?;
        unused.release();
        return;
    }
    g_backdrop = backdrop;
    snapshot(&g_state);
    g_bounds = .{ .left = 0, .top = 0, .right = width, .bottom = height };
    const plus = layout.attach_btn;
    g_anchor = .{ .left = plus.left - pane.left, .top = plus.top - pane.top, .right = plus.right - pane.left, .bottom = plus.bottom - pane.top };
    g_open = true;
    const g = geometry(g_bounds, g_anchor, &g_state.shown);
    var log_buf: [128]u8 = undefined;
    for ([_]Item{ .attach, .model_opus, .effort_low, .mode_ask }) |item| {
        if (!g_state.shown[@intFromEnum(item)]) continue;
        const cell = g.cells[@intFromEnum(item)];
        @import("diagnostics.zig").debugLog(std.fmt.bufPrint(&log_buf, "[chat] plus menu {s} rect={d},{d},{d},{d}", .{ @tagName(item), cell.left, cell.top, cell.right, cell.bottom }) catch "[chat] plus menu");
    }
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
    if (!g_state.shown[@intFromEnum(item)]) return;
    close();
    _ = focus.PostMessageW(app_state.g_main_hwnd, w.WM_APP_PLUS_MENU_ACTION, @intFromEnum(item), 0);
}

fn step(direction: i32) void {
    const tags = std.meta.tags(Item);
    var current: i32 = if (g_state.hover) |item| @intCast(@intFromEnum(item)) else if (direction > 0) -1 else @as(i32, @intCast(tags.len));
    var tries: usize = 0;
    while (tries < tags.len) : (tries += 1) {
        current = @mod(current + direction, @as(i32, @intCast(tags.len)));
        const candidate: Item = @enumFromInt(@as(usize, @intCast(current)));
        if (g_state.shown[@intFromEnum(candidate)]) {
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
            const g = geometry(g_bounds, g_anchor, &g_state.shown);
            const next = hitItem(&g, &g_state.shown, startup.GET_X(lp), startup.GET_Y(lp));
            if (next != g_state.hover) {
                g_state.hover = next;
                _ = w.InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        w.WM_LBUTTONDOWN => {
            const g = geometry(g_bounds, g_anchor, &g_state.shown);
            const x = startup.GET_X(lp);
            const y = startup.GET_Y(lp);
            if (hitItem(&g, &g_state.shown, x, y)) |item| {
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
