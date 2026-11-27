const std = @import("std");
const app_state = @import("app_state.zig");
const w = @import("win32.zig");
const drawing = @import("drawing.zig");
const focus = @import("focus.zig");
const chat_live = @import("chat_live.zig");
const chat_composer = @import("chat_composer.zig");
const startup = @import("startup.zig");
const more_menu = @import("more_menu.zig");
const themes = @import("themes.zig");
const fillRoundRect = @import("smooth.zig").fillRoundRect;

const RECT = w.RECT;
const HANDLE = w.HANDLE;
const L = startup.L;
const RGB = startup.RGB;
const uiScaled = drawing.uiScaled;

pub const Item = enum(usize) { ai, models, efforts, permissions, mode_auto, full_access, attach, model_opus, model_sonnet, model_haiku, model_fable, model_sol, model_terra, model_luna, model_astra, model_neon, model_carbon, model_argon, model_hydrogen, model_flash, model_agy_opus, model_agy_sonnet, effort_low, effort_medium, effort_high, effort_xhigh, mode_ask, mode_edits, mode_plan, mode_bypass };
const ITEM_COUNT = std.meta.tags(Item).len;

const Section = struct { title: ?[]const u8, items: []const Item };

const antigravity_models = [_]Item{ .model_neon, .model_carbon, .model_argon, .model_hydrogen, .model_flash, .model_agy_opus, .model_agy_sonnet };
const antigravity_efforts = [_]Item{ .effort_low, .effort_medium, .effort_high, .effort_xhigh };

const sections = [_]Section{
    .{ .title = null, .items = &.{.attach} },
    .{ .title = "Model", .items = &.{ .model_opus, .model_sonnet, .model_haiku, .model_fable } },
    .{ .title = "Model", .items = &.{ .model_sol, .model_terra, .model_luna, .model_astra } },
    .{ .title = "Model", .items = &antigravity_models },
    .{ .title = "Effort", .items = &.{ .effort_low, .effort_medium, .effort_high, .effort_xhigh } },
    .{ .title = "Permission level", .items = &.{ .mode_ask, .mode_auto, .mode_edits, .mode_plan, .mode_bypass, .full_access } },
    .{ .title = null, .items = &.{ .ai, .models, .efforts, .permissions } },
};

pub const State = struct {
    shown: [ITEM_COUNT]bool = @splat(false),
    active: [ITEM_COUNT]bool = @splat(false),
    disabled: [ITEM_COUNT]bool = @splat(false),
    hover: ?Item = null,
};

fn label(item: Item) []const u8 {
    return switch (item) {
        .ai => "AI",
        .models => "Model",
        .efforts => "Effort",
        .permissions => "Permission level",
        .mode_auto => "Auto",
        .full_access => "Bypass (always full access)",
        .attach => "Attach file",
        .model_opus => "Opus",
        .model_sonnet => "Sonnet",
        .model_haiku => "Haiku",
        .model_fable => "Fable",
        .model_sol => "Sol",
        .model_terra => "Terra",
        .model_luna => "Luna",
        .model_astra => "Astra",
        .model_neon => "Neon",
        .model_carbon => "Carbon",
        .model_argon => "Argon",
        .model_hydrogen => "Hydrogen",
        .model_flash => "Flash",
        .model_agy_opus => "Opus",
        .model_agy_sonnet => "Sonnet",
        .effort_low => "Low",
        .effort_medium => "Medium",
        .effort_high => "High",
        .effort_xhigh => "XHigh",
        .mode_ask => if (@import("chat_session.zig").chatSettingsCodex()) "Untrusted / workspace write" else "Default",
        .mode_edits => "On request / workspace write",
        .mode_plan => "Untrusted / read only",
        .mode_bypass => if (@import("chat_session.zig").chatSettingsCodex()) "Never / full access" else "Bypass",
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
        for (section.items) |item| {
            if (shown[@intFromEnum(item)]) rows += 1;
        }
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

test "MUBO-582 antigravity rows show, fit and tick the live choice" {
    try std.testing.expectEqualSlices(Item, &.{ .model_neon, .model_carbon, .model_argon, .model_hydrogen, .model_flash, .model_agy_opus, .model_agy_sonnet }, sections[3].items);
    try std.testing.expectEqualStrings("Neon", label(.model_neon));
    try std.testing.expectEqualStrings("Flash", label(.model_flash));
    try std.testing.expectEqualStrings("Opus", label(.model_agy_opus));
    try std.testing.expectEqualStrings("XHigh", label(.effort_xhigh));
    var state: State = .{};
    state.shown[@intFromEnum(Item.attach)] = true;
    markAntigravity(&state, .{ .model = .carbon, .effort = .xhigh });
    for (antigravity_models) |item| try std.testing.expect(state.shown[@intFromEnum(item)]);
    for (antigravity_efforts) |item| try std.testing.expect(state.shown[@intFromEnum(item)]);
    try std.testing.expect(state.active[@intFromEnum(Item.model_carbon)]);
    try std.testing.expect(state.active[@intFromEnum(Item.effort_xhigh)]);
    try std.testing.expect(!state.active[@intFromEnum(Item.model_neon)]);
    try std.testing.expect(!state.active[@intFromEnum(Item.effort_high)]);
    for ([_]i32{ 360, 480, 640, 900 }) |height| {
        const bounds = RECT{ .left = 0, .top = 0, .right = 700, .bottom = height };
        const anchor = RECT{ .left = 20, .top = height - 60, .right = 52, .bottom = height - 28 };
        const g = geometry(bounds, anchor, &state.shown);
        try std.testing.expect(g.panel.top >= bounds.top);
        try std.testing.expect(g.panel.bottom <= anchor.top);
        try std.testing.expect(g.section_shown[3] and g.section_shown[4] and !g.section_shown[1] and !g.section_shown[2]);
        for (antigravity_models) |item| {
            const cell = g.cells[@intFromEnum(item)];
            try std.testing.expect(cell.bottom > cell.top and cell.right > cell.left);
            try std.testing.expect(cell.left >= g.panel.left and cell.right <= g.panel.right);
            try std.testing.expect(cell.top >= g.panel.top and cell.bottom <= g.panel.bottom);
            try std.testing.expectEqual(@as(?Item, item), hitItem(&g, &state.shown, @divTrunc(cell.left + cell.right, 2), @divTrunc(cell.top + cell.bottom, 2)));
        }
        for (antigravity_efforts) |item| {
            const cell = g.cells[@intFromEnum(item)];
            try std.testing.expectEqual(@as(?Item, item), hitItem(&g, &state.shown, @divTrunc(cell.left + cell.right, 2), @divTrunc(cell.top + cell.bottom, 2)));
        }
    }
}

test "MUBO-582 claude and codex menus keep their own rows" {
    try std.testing.expectEqualSlices(Item, &.{ .model_opus, .model_sonnet, .model_haiku, .model_fable }, sections[1].items);
    try std.testing.expectEqualSlices(Item, &.{ .model_sol, .model_terra, .model_luna, .model_astra }, sections[2].items);
    try std.testing.expectEqualSlices(Item, &.{ .effort_low, .effort_medium, .effort_high, .effort_xhigh }, sections[4].items);
    var claude: State = .{};
    markClaude(&claude, .{ .model = .opus, .effort = .medium }, &.{});
    try std.testing.expect(claude.active[@intFromEnum(Item.model_opus)]);
    try std.testing.expect(!claude.shown[@intFromEnum(Item.effort_xhigh)]);
    for (antigravity_models) |item| try std.testing.expect(!claude.shown[@intFromEnum(item)]);
    var codex: State = .{};
    markCodex(&codex, .{ .model = .sol, .effort = .high });
    try std.testing.expect(codex.active[@intFromEnum(Item.model_sol)]);
    try std.testing.expect(codex.shown[@intFromEnum(Item.effort_low)] and codex.shown[@intFromEnum(Item.effort_medium)] and codex.shown[@intFromEnum(Item.effort_high)]);
    try std.testing.expect(!codex.shown[@intFromEnum(Item.effort_xhigh)]);
    for (antigravity_models) |item| try std.testing.expect(!codex.shown[@intFromEnum(item)]);
}

test "MUBO-588 a codex chat ticks its effort and a pi chat offers only effort rows" {
    var codex: State = .{};
    markCodex(&codex, .{ .model = .terra, .effort = .medium });
    try std.testing.expect(codex.active[@intFromEnum(Item.effort_medium)]);
    try std.testing.expect(!codex.active[@intFromEnum(Item.effort_low)] and !codex.active[@intFromEnum(Item.effort_high)]);
    var pi: State = .{};
    pi.shown[@intFromEnum(Item.attach)] = true;
    markPi(&pi, .{ .effort = .xhigh });
    for (antigravity_efforts) |item| try std.testing.expect(pi.shown[@intFromEnum(item)]);
    try std.testing.expect(pi.active[@intFromEnum(Item.effort_xhigh)]);
    try std.testing.expect(!pi.active[@intFromEnum(Item.effort_high)]);
    for (antigravity_models) |item| try std.testing.expect(!pi.shown[@intFromEnum(item)]);
    for ([_]Item{ .model_opus, .model_sol }) |item| try std.testing.expect(!pi.shown[@intFromEnum(item)]);
    for ([_]i32{ 360, 480, 640, 900 }) |height| {
        const bounds = RECT{ .left = 0, .top = 0, .right = 700, .bottom = height };
        const anchor = RECT{ .left = 20, .top = height - 60, .right = 52, .bottom = height - 28 };
        const g = geometry(bounds, anchor, &pi.shown);
        try std.testing.expect(g.section_shown[4] and !g.section_shown[1] and !g.section_shown[2] and !g.section_shown[3]);
        for (antigravity_efforts) |item| {
            const cell = g.cells[@intFromEnum(item)];
            try std.testing.expectEqual(@as(?Item, item), hitItem(&g, &pi.shown, @divTrunc(cell.left + cell.right, 2), @divTrunc(cell.top + cell.bottom, 2)));
        }
    }
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

fn activeInk() u32 {
    return themes.customColorOr("accent", if (app_state.g_light_theme) RGB(30, 90, 180) else RGB(100, 160, 240));
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
            _ = w.SetTextColor(dc, if (state.disabled[idx]) c.hint else if (state.active[idx]) activeInk() else c.text);
            _ = w.SelectObject(dc, drawing.uiFontTitle());
            var row_rc = RECT{ .left = cell.left + uiScaled(14), .top = cell.top, .right = cell.right - uiScaled(14), .bottom = cell.bottom };
            drawing.drawAscii(dc, label(item), &row_rc, flags);
        }
    }
}

var g_hwnd: HANDLE = null;
var g_class_registered = false;
pub const Page = enum { root, ai, models, efforts, permissions };
var g_page: Page = .root;
var g_identity: @import("chat_transcript.zig").Identity = .{};
var g_open = false;
var g_state: State = .{};
var g_backdrop: ?more_menu.Backdrop = null;
var g_bounds: RECT = std.mem.zeroes(RECT);
var g_anchor: RECT = std.mem.zeroes(RECT);

pub fn isOpen() bool {
    return g_open;
}

fn modelFromStatus(text: []const u16) chat_live.Model {
    inline for (.{ .{ "opus", chat_live.Model.opus }, .{ "sonnet", chat_live.Model.sonnet }, .{ "haiku", chat_live.Model.haiku }, .{ "fable", chat_live.Model.fable } }) |entry| {
        const name = entry[0];
        if (text.len >= name.len) {
            var same = true;
            for (name, 0..) |ch, i| {
                if (text[i] != ch and text[i] != ch - 32) same = false;
            }
            if (same and (text.len == name.len or text[name.len] == ' ' or text[name.len] == '-')) return entry[1];
        }
    }
    return .unknown;
}

fn modelOf(selected: chat_live.Settings, status: []const u16) chat_live.Model {
    return if (selected.model != .unknown) selected.model else modelFromStatus(status);
}

fn markAntigravity(state: *State, selected: chat_live.Settings) void {
    for (antigravity_models) |item| state.shown[@intFromEnum(item)] = true;
    for (antigravity_efforts) |item| state.shown[@intFromEnum(item)] = true;
    state.active[@intFromEnum(Item.model_neon)] = selected.model == .neon;
    state.active[@intFromEnum(Item.model_carbon)] = selected.model == .carbon;
    state.active[@intFromEnum(Item.model_argon)] = selected.model == .argon;
    state.active[@intFromEnum(Item.model_hydrogen)] = selected.model == .hydrogen;
    state.active[@intFromEnum(Item.model_flash)] = selected.model == .flash;
    state.active[@intFromEnum(Item.model_agy_opus)] = selected.model == .opus;
    state.active[@intFromEnum(Item.model_agy_sonnet)] = selected.model == .sonnet;
    state.active[@intFromEnum(Item.effort_low)] = selected.effort == .low;
    state.active[@intFromEnum(Item.effort_medium)] = selected.effort == .medium;
    state.active[@intFromEnum(Item.effort_high)] = selected.effort == .high;
    state.active[@intFromEnum(Item.effort_xhigh)] = selected.effort == .xhigh;
}

fn markCodex(state: *State, selected: chat_live.Settings) void {
    for ([_]Item{ .model_sol, .model_terra, .model_luna, .model_astra, .effort_low, .effort_medium, .effort_high }) |item| state.shown[@intFromEnum(item)] = true;
    state.active[@intFromEnum(Item.model_sol)] = selected.model == .sol;
    state.active[@intFromEnum(Item.model_terra)] = selected.model == .terra;
    state.active[@intFromEnum(Item.model_luna)] = selected.model == .luna;
    state.active[@intFromEnum(Item.model_astra)] = selected.model == .astra;
    state.active[@intFromEnum(Item.effort_low)] = selected.effort == .low;
    state.active[@intFromEnum(Item.effort_medium)] = selected.effort == .medium;
    state.active[@intFromEnum(Item.effort_high)] = selected.effort == .high;
}

fn markPi(state: *State, selected: chat_live.Settings) void {
    for (antigravity_efforts) |item| state.shown[@intFromEnum(item)] = true;
    state.active[@intFromEnum(Item.effort_low)] = selected.effort == .low;
    state.active[@intFromEnum(Item.effort_medium)] = selected.effort == .medium;
    state.active[@intFromEnum(Item.effort_high)] = selected.effort == .high;
    state.active[@intFromEnum(Item.effort_xhigh)] = selected.effort == .xhigh;
}

fn markClaude(state: *State, selected: chat_live.Settings, status: []const u16) void {
    for ([_]Item{ .model_opus, .model_sonnet, .model_haiku, .model_fable, .effort_low, .effort_medium, .effort_high }) |item| state.shown[@intFromEnum(item)] = true;
    const model = modelOf(selected, status);
    state.active[@intFromEnum(Item.model_opus)] = model == .opus;
    state.active[@intFromEnum(Item.model_sonnet)] = model == .sonnet;
    state.active[@intFromEnum(Item.model_haiku)] = model == .haiku;
    state.active[@intFromEnum(Item.model_fable)] = model == .fable;
    state.active[@intFromEnum(Item.effort_low)] = selected.effort == .low;
    state.active[@intFromEnum(Item.effort_medium)] = selected.effort == .medium;
    state.active[@intFromEnum(Item.effort_high)] = selected.effort == .high;
}

pub fn choicesFor(provider: []const u8, selected: chat_live.Settings, status: []const u16, eligible: bool, permissions: bool) State {
    var result: State = .{};
    const state = &result;
    if (eligible) {
        if (std.mem.eql(u8, provider, "antigravity")) {
            markAntigravity(state, selected);
        } else if (std.mem.eql(u8, provider, "codex")) {
            markCodex(state, selected);
        } else if (std.mem.eql(u8, provider, "pi")) {
            markPi(state, selected);
        } else if (std.mem.eql(u8, provider, "claude")) {
            markClaude(state, selected, status);
        }
    }
    if (permissions) {
        if (std.mem.eql(u8, provider, "claude")) {
            for ([_]Item{ .mode_ask, .mode_auto, .mode_bypass }) |item| state.shown[@intFromEnum(item)] = true;
        } else if (std.mem.eql(u8, provider, "codex")) {
            for ([_]Item{ .mode_ask, .mode_edits, .mode_plan, .mode_bypass }) |item| state.shown[@intFromEnum(item)] = true;
        }
        state.active[@intFromEnum(Item.mode_auto)] = selected.mode == .auto;
        state.active[@intFromEnum(Item.mode_ask)] = selected.mode == .manual;
        state.active[@intFromEnum(Item.mode_edits)] = selected.mode == .acceptEdits;
        state.active[@intFromEnum(Item.mode_plan)] = selected.mode == .plan;
        state.active[@intFromEnum(Item.mode_bypass)] = selected.mode == .bypassPermissions;
    }
    if (std.mem.eql(u8, provider, "pi") or std.mem.eql(u8, provider, "antigravity")) {
        state.shown[@intFromEnum(Item.full_access)] = true;
        state.active[@intFromEnum(Item.full_access)] = true;
        state.disabled[@intFromEnum(Item.full_access)] = true;
    }
    if (std.mem.eql(u8, provider, "antigravity") and selected.model != .neon and selected.model != .hydrogen) {
        state.shown[@intFromEnum(Item.effort_xhigh)] = false;
    }
    return result;
}

pub fn pageState(page: Page, choices: State, eligible: bool) State {
    var state = choices;
    for (std.meta.tags(Item)) |item| {
        const visible = switch (page) {
            .root => item == .ai or item == .models or item == .efforts or item == .permissions,
            .ai => false,
            .models => @intFromEnum(item) >= @intFromEnum(Item.model_opus) and @intFromEnum(item) <= @intFromEnum(Item.model_agy_sonnet),
            .efforts => @intFromEnum(item) >= @intFromEnum(Item.effort_low) and @intFromEnum(item) <= @intFromEnum(Item.effort_xhigh),
            .permissions => item == .mode_auto or item == .full_access or @intFromEnum(item) >= @intFromEnum(Item.mode_ask),
        };
        state.shown[@intFromEnum(item)] = visible and (page == .root or choices.shown[@intFromEnum(item)]);
        if (page == .root) {
            state.disabled[@intFromEnum(item)] = if (item == .permissions)
                !choices.shown[@intFromEnum(Item.mode_ask)] and !choices.shown[@intFromEnum(Item.full_access)]
            else
                !eligible;
        }
    }
    state.hover = null;
    return state;
}

fn snapshot(state: *State) void {
    state.* = pageState(g_page, .{}, false);
    if (app_state.active_shell >= app_state.shell_count) return;
    const chat_send = @import("chat_send.zig");
    chat_send.chatModeCapturePicker();
    const session = @import("chat_session.zig");
    const selected: chat_live.Settings = chat_live.settings(app_state.shells[app_state.active_shell].shell_id) orelse .{};
    const identity = session.chatFileIdentityForShell(app_state.active_shell);
    const status: []const u16 = if (session.chatHistoryEntry(session.chatFileIdentity())) |entry| entry.history.status.model[0..entry.history.status.model_len] else &.{};
    const eligible = session.chatSettingsEligible();
    state.* = pageState(g_page, choicesFor(identity.provider(), selected, status, eligible, chat_send.chatModeSelectable()), eligible);
}

test "MUBO-575 every AI starts with exactly four menu rows" {
    for ([_]Page{ .root, .models, .efforts, .permissions }) |page| {
        const state = pageState(page, .{}, true);
        var count: usize = 0;
        for (state.shown) |shown| {
            if (shown) count += 1;
        }
        try std.testing.expectEqual(@as(usize, if (page == .root) 4 else 0), count);
    }
    var choices: State = .{};
    choices.shown[@intFromEnum(Item.full_access)] = true;
    choices.disabled[@intFromEnum(Item.full_access)] = true;
    const fixed = pageState(.permissions, choices, true);
    try std.testing.expect(fixed.shown[@intFromEnum(Item.full_access)] and fixed.disabled[@intFromEnum(Item.full_access)]);
    try std.testing.expect(!fixed.shown[@intFromEnum(Item.mode_auto)]);
}

test "MUBO-575 a live chat can change permission level from the plus menu" {
    const claude = choicesFor("claude", .{}, &.{}, true, true);
    const root = pageState(.root, claude, true);
    try std.testing.expect(root.shown[@intFromEnum(Item.permissions)]);
    try std.testing.expect(!root.disabled[@intFromEnum(Item.permissions)]);
    try std.testing.expect(!root.disabled[@intFromEnum(Item.models)] and !root.disabled[@intFromEnum(Item.efforts)]);
    const modes = pageState(.permissions, claude, true);
    for ([_]Item{ .mode_ask, .mode_auto, .mode_bypass }) |item| {
        try std.testing.expect(modes.shown[@intFromEnum(item)]);
        try std.testing.expect(!modes.disabled[@intFromEnum(item)]);
    }
    for ([_]Item{ .mode_edits, .mode_plan, .full_access }) |item| try std.testing.expect(!modes.shown[@intFromEnum(item)]);
}

test "IGSH-1861 the model falls back to the transcript name and never guesses" {
    const opus = std.unicode.utf8ToUtf16LeStringLiteral("Opus 4.7");
    const raw = std.unicode.utf8ToUtf16LeStringLiteral("sonnet-4-5");
    const fable = std.unicode.utf8ToUtf16LeStringLiteral("Fable 5.2");
    const other = std.unicode.utf8ToUtf16LeStringLiteral("Mystery 1.0");
    const empty = std.unicode.utf8ToUtf16LeStringLiteral("");
    try std.testing.expectEqual(chat_live.Model.opus, modelOf(.{}, opus));
    try std.testing.expectEqual(chat_live.Model.sonnet, modelOf(.{}, raw));
    try std.testing.expectEqual(chat_live.Model.fable, modelOf(.{}, fable));
    try std.testing.expectEqual(chat_live.Model.unknown, modelOf(.{}, other));
    try std.testing.expectEqual(chat_live.Model.unknown, modelOf(.{}, empty));
    try std.testing.expectEqual(chat_live.Model.haiku, modelOf(.{ .model = .haiku }, opus));
}

fn ensureClass() void {
    if (g_class_registered) return;
    const wc = w.WNDCLASSEXW{ .cbSize = @sizeOf(w.WNDCLASSEXW), .style = 0, .lpfnWndProc = wndProc, .cbClsExtra = 0, .cbWndExtra = 0, .hInstance = w.GetModuleHandleW(null), .hIcon = null, .hCursor = w.LoadCursorW(null, @ptrFromInt(32512)), .hbrBackground = null, .lpszMenuName = null, .lpszClassName = L("MultiPromptPlusMenu"), .hIconSm = null };
    _ = w.RegisterClassExW(&wc);
    g_class_registered = true;
}

pub fn open() void {
    openPage(.root);
}

pub fn openPage(page: Page) void {
    if (page == .ai) {
        close();
        openSwitchAi();
        return;
    }
    if (page == .models and @import("chat_session.zig").chatSettingsPi()) {
        close();
        @import("chat_send.zig").chatPiModelPicker();
        return;
    }
    if (g_open) close();
    g_page = page;
    const main = app_state.g_main_hwnd orelse return;
    if (!chat_composer.chatViewOwnsInput()) return;
    _ = w.UpdateWindow(main);
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
    g_identity = @import("chat_session.zig").chatFileIdentityForShell(app_state.active_shell);
    snapshot(&g_state);
    g_bounds = .{ .left = 0, .top = 0, .right = width, .bottom = height };
    const plus = layout.attach_btn;
    g_anchor = .{ .left = plus.left - pane.left, .top = plus.top - pane.top, .right = plus.right - pane.left, .bottom = plus.bottom - pane.top };
    g_open = true;
    const g = geometry(g_bounds, g_anchor, &g_state.shown);
    var log_buf: [128]u8 = undefined;
    for (std.meta.tags(Item)) |item| {
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
    if (!g_state.shown[@intFromEnum(item)] or g_state.disabled[@intFromEnum(item)]) return;
    if (app_state.active_shell >= app_state.shell_count or !std.meta.eql(g_identity, @import("chat_session.zig").chatFileIdentityForShell(app_state.active_shell))) {
        close();
        return;
    }
    switch (item) {
        .ai => {
            close();
            openSwitchAi();
            return;
        },
        .models => {
            openPage(.models);
            return;
        },
        .efforts => {
            openPage(.efforts);
            return;
        },
        .permissions => {
            openPage(.permissions);
            return;
        },
        else => {},
    }
    close();
    _ = focus.PostMessageW(app_state.g_main_hwnd, w.WM_APP_PLUS_MENU_ACTION, @intFromEnum(item), 0);
}

fn step(direction: i32) void {
    var ordered: [ITEM_COUNT]Item = undefined;
    var count: usize = 0;
    var current: i32 = -1;
    for (sections) |section| {
        for (section.items) |item| {
            if (!g_state.shown[@intFromEnum(item)] or g_state.disabled[@intFromEnum(item)]) continue;
            if (g_state.hover == item) current = @intCast(count);
            ordered[count] = item;
            count += 1;
        }
    }
    if (count == 0) return;
    if (current < 0 and direction < 0) current = 0;
    const next: usize = @intCast(@mod(current + direction, @as(i32, @intCast(count))));
    g_state.hover = ordered[next];
    _ = w.InvalidateRect(g_hwnd, null, 0);
}

pub fn key(vk: usize) bool {
    if (!g_open) return false;
    switch (vk) {
        w.VK_ESCAPE => if (g_page != .root) openPage(.root) else close(),
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

pub fn dispatch(wp: usize) void {
    const item: Item = blk: {
        inline for (std.meta.fields(Item)) |field| {
            if (wp == field.value) break :blk @enumFromInt(field.value);
        }
        return;
    };
    switch (item) {
        .ai, .models, .efforts, .permissions, .full_access => {},
        .attach => _ = focus.PostMessageW(app_state.g_main_hwnd, app_state.WM_APP_CHAT_ATTACH, 0, 0),
        .model_opus, .model_sonnet, .model_haiku, .model_fable, .model_sol, .model_terra, .model_luna, .model_astra, .model_neon, .model_carbon, .model_argon, .model_hydrogen, .model_flash, .model_agy_opus, .model_agy_sonnet, .effort_low, .effort_medium, .effort_high, .effort_xhigh => {
            const setting: @import("chat_live.zig").Setting = switch (item) {
                .model_opus => .{ .model = .opus },
                .model_sonnet => .{ .model = .sonnet },
                .model_haiku => .{ .model = .haiku },
                .model_fable => .{ .model = .fable },
                .model_sol => .{ .model = .sol },
                .model_terra => .{ .model = .terra },
                .model_luna => .{ .model = .luna },
                .model_astra => .{ .model = .astra },
                .model_neon => .{ .model = .neon },
                .model_carbon => .{ .model = .carbon },
                .model_argon => .{ .model = .argon },
                .model_hydrogen => .{ .model = .hydrogen },
                .model_flash => .{ .model = .flash },
                .model_agy_opus => .{ .model = .opus },
                .model_agy_sonnet => .{ .model = .sonnet },
                .effort_low => .{ .effort = .low },
                .effort_medium => .{ .effort = .medium },
                .effort_high => .{ .effort = .high },
                else => .{ .effort = .xhigh },
            };
            if (@import("chat_send.zig").chatSetLiveSetting(setting)) @import("chat_send.zig").chatSettingNotice(setting) else @import("console.zig").showHeaderNoticeAscii("Could not change chat settings", 4000, true);
        },
        .mode_ask, .mode_auto, .mode_edits, .mode_plan, .mode_bypass => {
            const mode: @import("chat_slash.zig").PermissionMode = switch (item) {
                .mode_ask => .manual,
                .mode_auto => .auto,
                .mode_edits => .acceptEdits,
                .mode_plan => .plan,
                else => .bypassPermissions,
            };
            if (!@import("chat_send.zig").chatModeSelect(mode)) @import("console.zig").showHeaderNoticeAscii("Could not change permission mode; try again", 4000, true);
        },
    }
}

fn openSwitchAi() void {
    _ = w.SendMessageW(app_state.g_main_hwnd, w.WM_APP_SEARCH_OPEN, 0, 0);
    const query = std.unicode.utf8ToUtf16LeStringLiteral("Chat View: Switch AI to");
    @memcpy(app_state.g_search_buf[0..query.len], query);
    app_state.g_search_len = query.len;
    app_state.g_search_sel = 0;
    app_state.g_search_scroll = 0;
    @import("command_palette.zig").updateSearchResults();
    _ = w.InvalidateRect(app_state.g_main_hwnd, null, 0);
}

pub const palette_rows = [_]struct { id: usize, title: []const u8, page: Page }{
    .{ .id = app_state.SEARCH_CHAT_AI_MENU_OFFSET, .title = "Chat View: AI", .page = .ai },
    .{ .id = app_state.SEARCH_CHAT_MODEL_MENU_OFFSET, .title = "Chat View: Model", .page = .models },
    .{ .id = app_state.SEARCH_CHAT_EFFORT_MENU_OFFSET, .title = "Chat View: Effort", .page = .efforts },
    .{ .id = app_state.SEARCH_CHAT_PERMISSION_MENU_OFFSET, .title = "Chat View: Permission level", .page = .permissions },
};

pub fn palettePage(target: usize) Page {
    for (palette_rows) |row| {
        if (row.id == target) return row.page;
    }
    return .root;
}

pub fn paletteTitle(target: usize) []const u8 {
    for (palette_rows) |row| {
        if (row.id == target) return row.title;
    }
    return "Chat View: Plus Menu";
}

test "MUBO-575 provider choices never offer another AI's controls" {
    for ([_][]const u8{ "claude", "codex", "pi", "antigravity" }) |provider| {
        const choices = choicesFor(provider, .{ .model = .carbon, .mode = .bypassPermissions }, &.{}, true, true);
        const root = pageState(.root, choices, true);
        for ([_]Item{ .ai, .models, .efforts, .permissions }) |item| try std.testing.expect(root.shown[@intFromEnum(item)] and !root.disabled[@intFromEnum(item)]);
        try std.testing.expect(!root.shown[@intFromEnum(Item.attach)]);
        const permission = pageState(.permissions, choices, true);
        if (std.mem.eql(u8, provider, "claude")) {
            try std.testing.expect(permission.shown[@intFromEnum(Item.mode_auto)]);
            try std.testing.expect(!permission.shown[@intFromEnum(Item.mode_edits)]);
            try std.testing.expect(!permission.shown[@intFromEnum(Item.mode_plan)]);
        } else if (std.mem.eql(u8, provider, "codex")) {
            try std.testing.expect(permission.shown[@intFromEnum(Item.mode_edits)]);
            try std.testing.expect(!permission.shown[@intFromEnum(Item.mode_auto)]);
        } else {
            try std.testing.expect(permission.shown[@intFromEnum(Item.full_access)] and permission.disabled[@intFromEnum(Item.full_access)]);
            try std.testing.expect(!permission.shown[@intFromEnum(Item.mode_ask)]);
        }
        if (!std.mem.eql(u8, provider, "pi")) {
            const models = pageState(.models, choices, true);
            try std.testing.expectEqual(std.mem.eql(u8, provider, "codex"), models.shown[@intFromEnum(Item.model_sol)]);
        }
        try std.testing.expect(!choices.shown[@intFromEnum(Item.effort_xhigh)] or std.mem.eql(u8, provider, "pi"));
    }
    const neon = choicesFor("antigravity", .{ .model = .neon }, &.{}, true, true);
    try std.testing.expect(neon.shown[@intFromEnum(Item.effort_xhigh)]);
    const loading = pageState(.root, .{}, false);
    try std.testing.expect(loading.disabled[@intFromEnum(Item.models)] and loading.disabled[@intFromEnum(Item.efforts)]);
}
