const std = @import("std");
const app = @import("app_state.zig");
const win = @import("win32.zig");
const drawing = @import("drawing.zig");
const archive = @import("archive.zig");
const model = @import("all_sessions_model.zig");
const smooth = @import("smooth.zig");
const RGB = @import("startup.zig").RGB;
const L = @import("startup.zig").L;
const scale = drawing.uiScaled;
const RECT = win.RECT;

pub var state_filter: ?model.RunState = null;
pub var server_filter: ?u8 = null;
var today: u64 = 0;
var tab_first: usize = 0;
const Hit = struct { rect: RECT, action: union(enum) { server: u8, state: ?model.RunState, tab: u32, search } };
var hits: [app.MAX_LWS + 270]Hit = undefined;
var hit_count: usize = 0;

pub fn selection() model.Selection {
    return .{ .state = state_filter, .host = server_filter, .tab = app.g_all_sessions_tab };
}

pub fn reset() void {
    state_filter = if (app.g_all_sessions_unattached_only) .no_window else null;
    server_filter = null;
    tab_first = 0;
}

pub fn dayStart() u64 {
    var local: win.SYSTEMTIME = undefined;
    win.GetLocalTime(&local);
    local.hour = 0;
    local.minute = 0;
    local.second = 0;
    local.milliseconds = 0;
    var utc: win.SYSTEMTIME = undefined;
    var stamp: win.FILETIME = undefined;
    if (win.TzSpecificLocalTimeToSystemTime(null, &local, &utc) == 0 or win.SystemTimeToFileTime(&utc, &stamp) == 0) return 0;
    return (@as(u64, stamp.dwHighDateTime) << 32) | stamp.dwLowDateTime;
}

pub fn cardLeft(width: i32) i32 {
    return @max(scale(12), @divTrunc(width - scale(1180), 2));
}

fn text(hdc: win.HANDLE, value: []const u8, rect: RECT, color: win.DWORD, right: bool) void {
    var wide: [256]u16 = undefined;
    const len = @import("json_reader.zig").wide(value, &wide);
    var rc = rect;
    _ = win.SetTextColor(hdc, color);
    _ = @import("dwrite_text.zig").draw(hdc, &wide, @intCast(len), &rc, win.DT_SINGLELINE | win.DT_VCENTER | win.DT_NOPREFIX | win.DT_END_ELLIPSIS | (if (right) win.DT_RIGHT else @as(u32, 0)));
}

fn hit(rect: RECT, action: @FieldType(Hit, "action")) void {
    if (hit_count == hits.len) return;
    hits[hit_count] = .{ .rect = rect, .action = action };
    hit_count += 1;
}

fn contains(rc: RECT, x: i32, y: i32) bool {
    return x >= rc.left and x < rc.right and y >= rc.top and y < rc.bottom;
}

fn pill(hdc: win.HANDLE, x: *i32, y: i32, edge: i32, label: []const u8, count: u32, active: bool, action: @FieldType(Hit, "action")) void {
    var buf: [128]u8 = undefined;
    const value = std.fmt.bufPrint(&buf, "{s}  {d}", .{ label, count }) catch label;
    var wide: [128]u16 = undefined;
    const n = @import("json_reader.zig").wide(value, &wide);
    var measure = RECT{ .left = 0, .top = 0, .right = 0, .bottom = 0 };
    _ = win.DrawTextW(hdc, &wide, @intCast(n), &measure, win.DT_CALCRECT | win.DT_SINGLELINE | win.DT_NOPREFIX);
    const rc = RECT{ .left = x.*, .top = y, .right = @min(edge, x.* + measure.right + scale(28)), .bottom = y + scale(30) };
    if (rc.right <= rc.left) return;
    if (active) smooth.fillRoundRect(hdc, rc, scale(15), if (app.g_light_theme) RGB(225, 225, 225) else RGB(53, 53, 53));
    text(hdc, value, .{ .left = rc.left + scale(14), .top = rc.top, .right = rc.right - scale(10), .bottom = rc.bottom }, if (app.g_light_theme) RGB(50, 50, 50) else if (active) RGB(242, 242, 242) else RGB(160, 160, 160), false);
    hit(rc, action);
    x.* = rc.right + scale(4);
}

const Layout = struct {
    left: i32,
    right: i32,
    top: i32,
    bottom: i32,
    scroll: i32,
};

fn layout(width: i32, height: i32) Layout {
    const top = archive.allSessionsListTop();
    const bottom = @max(top, height - scale(60));
    var y: i32 = 0;
    var selected_bottom: i32 = 0;
    var previous: ?model.Group = null;
    var visible: u32 = 0;
    for (app.g_session_overview_rows.items) |row| {
        if (!archive.allSessionsRowVisible(&row)) continue;
        const group = model.group(row, today);
        if (previous != group) y += scale(26);
        previous = group;
        y += scale(60);
        if (visible == app.g_all_sessions_sel) selected_bottom = y;
        visible += 1;
    }
    return .{ .left = cardLeft(width) + scale(10), .right = width - cardLeft(width) - scale(10), .top = top, .bottom = bottom, .scroll = @max(0, selected_bottom - (bottom - top)) };
}

pub fn paint(hdc: win.HANDLE) void {
    var rc: RECT = undefined;
    _ = win.GetClientRect(app.g_main_hwnd, &rc);
    const w = rc.right;
    const h = rc.bottom;
    const bg = @import("themes.zig").themeConsoleBg();
    const brush = win.CreateSolidBrush(bg);
    _ = win.FillRect(hdc, &rc, brush);
    _ = win.DeleteObject(brush);
    const left = cardLeft(w);
    const right = w - left;
    const bright = if (app.g_light_theme) RGB(30, 30, 30) else RGB(242, 242, 242);
    const muted = if (app.g_light_theme) RGB(100, 100, 100) else RGB(138, 138, 138);
    const surface = if (app.g_light_theme) RGB(250, 250, 250) else RGB(21, 21, 21);
    smooth.fillRoundRect(hdc, .{ .left = left, .top = scale(16), .right = right, .bottom = h - scale(16) }, scale(16), if (app.g_light_theme) RGB(215, 215, 215) else RGB(48, 48, 48));
    smooth.fillRoundRect(hdc, .{ .left = left + 1, .top = scale(17), .right = right - 1, .bottom = h - scale(17) }, scale(15), surface);
    const old_font = win.SelectObject(hdc, drawing.uiFontBot(.name));
    defer _ = win.SelectObject(hdc, old_font);
    _ = win.SetBkMode(hdc, win.TRANSPARENT);
    today = dayStart();
    hit_count = 0;
    const rows = app.g_session_overview_rows.items;
    const count = archive.allSessionsVisibleCount();
    if (app.g_all_sessions_sel >= count) app.g_all_sessions_sel = count -| 1;
    text(hdc, "Show all sessions", .{ .left = left + scale(22), .top = scale(30), .right = right - scale(22), .bottom = scale(54) }, bright, false);
    _ = win.SelectObject(hdc, drawing.uiFontBot(.preview));
    var summary: [128]u8 = undefined;
    text(hdc, std.fmt.bufPrint(&summary, "{d} running on {d} servers, {d} archived", .{ model.count(rows, .{ .state = .running }), model.serverCount(rows), model.count(rows, .{ .state = .archived }) }) catch "", .{ .left = left + scale(22), .top = scale(56), .right = right - scale(22), .bottom = scale(76) }, muted, false);
    var x = left + scale(18);
    var seen = [_]bool{false} ** 256;
    for (rows) |row| {
        if (seen[row.host]) continue;
        seen[row.host] = true;
        pill(hdc, &x, scale(86), right - scale(18), @import("capacity.zig").tmuxHostLongLabel(row.host), model.count(rows, .{ .host = row.host, .state = .running }), server_filter == row.host, .{ .server = row.host });
    }
    x = left + scale(18);
    const states = [_]?model.RunState{ null, .running, .no_window, .archived };
    for (states) |state| {
        pill(hdc, &x, scale(124), right - scale(18), if (state) |value| model.stateLabel(value) else "All", model.count(rows, .{ .state = state, .host = server_filter }), state_filter == state, .{ .state = state });
    }
    const search_left = @min(right - scale(22), @max(left + scale(230), right - scale(450)));
    const search = RECT{ .left = search_left, .top = scale(32), .right = right - scale(22), .bottom = scale(68) };
    if (w - left * 2 > scale(550)) {
        smooth.fillRoundRect(hdc, search, scale(10), if (app.g_light_theme) RGB(235, 235, 235) else RGB(15, 15, 15));
        var query = search;
        query.left += scale(12);
        query.right -= scale(12);
        _ = win.SetTextColor(hdc, if (app.g_all_sessions_filter_len > 0) bright else muted);
        if (app.g_all_sessions_filter_len > 0) {
            _ = @import("dwrite_text.zig").draw(hdc, &app.g_all_sessions_filter_buf, @intCast(app.g_all_sessions_filter_len), &query, win.DT_SINGLELINE | win.DT_VCENTER | win.DT_NOPREFIX | win.DT_END_ELLIPSIS);
        } else {
            _ = win.DrawTextW(hdc, if (app.g_all_sessions_filter_active) L("Type to search sessions...") else L("Search sessions, workspaces or servers...  Ctrl+F"), -1, &query, win.DT_SINGLELINE | win.DT_VCENTER | win.DT_NOPREFIX | win.DT_END_ELLIPSIS);
        }
        hit(search, .search);
    }
    var tabs: [app.ALL_SESSIONS_TAB_COUNT]u32 = undefined;
    var n: usize = 0;
    for ([_]u32{ app.AS_TAB_ALL, app.AS_TAB_FREQUENT, app.AS_TAB_FAVORITES, app.AS_TAB_WAITING }) |id| {
        tabs[n] = id;
        n += 1;
    }
    for (0..app.g_lws_count) |ws| {
        tabs[n] = @intCast(ws);
        n += 1;
    }
    tabs[n] = app.AS_TAB_OTHER;
    tabs[n + 1] = app.AS_TAB_ARCHIVED;
    n += 2;
    app.g_all_sessions_split_tab_count = n;
    @memcpy(app.g_all_sessions_split_ids[0..n], tabs[0..n]);
    var selected_tab: usize = 0;
    for (tabs[0..n], 0..) |id, i| if (id == app.g_all_sessions_tab) {
        selected_tab = i;
    };
    if (selected_tab < tab_first) tab_first = selected_tab;
    const max_tabs: usize = @intCast(@max(1, @divTrunc(right - left - scale(36), scale(120))));
    if (selected_tab >= tab_first + max_tabs) tab_first = selected_tab - max_tabs + 1;
    x = left + scale(18);
    _ = win.SelectObject(hdc, drawing.uiFontBot(.name));
    for (tabs[tab_first..@min(n, tab_first + max_tabs)]) |id| {
        var label: [32]u8 = undefined;
        pill(hdc, &x, scale(172), right - scale(18), archive.allSessionsTabLabel(id, &label), archive.allSessionsClusterCount(id), id == app.g_all_sessions_tab, .{ .tab = id });
    }
    const bounds = layout(w, h);
    const saved = win.SaveDC(hdc);
    _ = win.IntersectClipRect(hdc, bounds.left, bounds.top, bounds.right, bounds.bottom);
    var y = bounds.top - bounds.scroll;
    var previous: ?model.Group = null;
    var visible: u32 = 0;
    for (rows) |row| {
        if (!archive.allSessionsRowVisible(&row)) continue;
        const group = model.group(row, today);
        if (previous != group) {
            _ = win.SelectObject(hdc, drawing.uiFontBot(.preview));
            text(hdc, switch (group) { .waiting => "WAITING ON YOU", .today => "TODAY", .earlier => "EARLIER" }, .{ .left = bounds.left + scale(12), .top = y, .right = bounds.right, .bottom = y + scale(26) }, muted, false);
            y += scale(26);
        }
        previous = group;
        if (y + scale(60) > bounds.top and y < bounds.bottom) paintRow(hdc, row, bounds, y, visible == app.g_all_sessions_sel, bright, muted);
        visible += 1;
        y += scale(60);
    }
    if (count == 0) text(hdc, "No sessions match these filters.", .{ .left = bounds.left + scale(12), .top = bounds.top, .right = bounds.right, .bottom = bounds.top + scale(40) }, muted, false);
    _ = win.RestoreDC(hdc, saved);
    archive.paintAllSessionsActions(hdc, w, h);
}

fn paintRow(hdc: win.HANDLE, row: model.Row, bounds: Layout, y: i32, selected: bool, bright: win.DWORD, muted: win.DWORD) void {
    const width = bounds.right - bounds.left;
    if (selected) smooth.fillRoundRect(hdc, .{ .left = bounds.left, .top = y, .right = bounds.right, .bottom = y + scale(58) }, scale(12), if (app.g_light_theme) RGB(225, 225, 225) else RGB(38, 38, 42));
    const avatar_rc = RECT{ .left = bounds.left + scale(12), .top = y + scale(10), .right = bounds.left + scale(52), .bottom = y + scale(50) };
    const avatar = @import("bot_avatar.zig");
    const shell = if (@import("inbox.zig").findShellById(row.shell_id)) |idx| &app.shells[idx] else null;
    const photo = if (shell) |value| @import("bot_photo.zig").draw(value, hdc, avatar_rc) else false;
    if (!photo) avatar.draw(hdc, avatar_rc, if (shell) |value| avatar.forShell(value) else avatar.Appearance.forSession(row.name[0..row.name_len]));
    const marked = archive.allSessionsRowMarked(&row);
    if (marked or row.attention or row.favorite) archive.drawAttentionDot(hdc, avatar_rc.right - scale(2), avatar_rc.bottom - scale(2), scale(4), if (marked) RGB(240, 130, 70) else if (row.attention) RGB(245, 180, 70) else RGB(240, 196, 75));
    const text_left = bounds.left + scale(68);
    const details_left = @max(text_left + scale(100), bounds.right - scale(380));
    const name_right = if (width >= scale(650)) details_left - scale(12) else bounds.right - scale(70);
    _ = win.SelectObject(hdc, drawing.uiFontBot(.name));
    text(hdc, row.name[0..row.name_len], .{ .left = text_left, .top = y + scale(6), .right = name_right, .bottom = y + scale(27) }, bright, false);
    _ = win.SelectObject(hdc, drawing.uiFontBot(.preview));
    text(hdc, if (row.preview_len > 0) row.preview[0..row.preview_len] else "No message preview", .{ .left = text_left, .top = y + scale(29), .right = name_right, .bottom = y + scale(50) }, muted, false);
    const state = model.runState(row);
    const state_color = switch (state) { .running => RGB(80, 195, 125), .no_window => RGB(137, 180, 248), .archived => muted };
    if (width >= scale(650)) {
        text(hdc, model.stateLabel(state), .{ .left = details_left, .top = y + scale(6), .right = details_left + scale(90), .bottom = y + scale(28) }, state_color, false);
        var ws: [32]u8 = undefined;
        text(hdc, archive.allSessionsTabLabel(if (row.workspace == 255) app.AS_TAB_OTHER else row.workspace, &ws), .{ .left = details_left + scale(100), .top = y + scale(6), .right = bounds.right - scale(90), .bottom = y + scale(28) }, muted, false);
        text(hdc, @import("capacity.zig").tmuxHostLongLabel(row.host), .{ .left = details_left, .top = y + scale(29), .right = details_left + scale(170), .bottom = y + scale(50) }, muted, false);
        if (model.highMemory(row)) {
            var memory: [24]u8 = undefined;
            text(hdc, std.fmt.bufPrint(&memory, "{d} MB", .{row.ram_mb}) catch "", .{ .left = details_left + scale(180), .top = y + scale(29), .right = bounds.right - scale(90), .bottom = y + scale(50) }, RGB(230, 160, 65), true);
        }
    } else {
        text(hdc, model.stateLabel(state), .{ .left = text_left, .top = y + scale(48), .right = bounds.right, .bottom = y + scale(60) }, state_color, false);
    }
    var age: [24]u16 = undefined;
    const age_len = @import("inbox.zig").inboxRelTime(row.last_active, &age);
    var age_rc = RECT{ .left = bounds.right - scale(72), .top = y + scale(6), .right = bounds.right - scale(12), .bottom = y + scale(28) };
    _ = win.SetTextColor(hdc, muted);
    _ = @import("dwrite_text.zig").draw(hdc, &age, @intCast(age_len), &age_rc, win.DT_SINGLELINE | win.DT_VCENTER | win.DT_NOPREFIX | win.DT_RIGHT);
}

pub fn click(hwnd: win.HANDLE, x: i32, y: i32) void {
    if (app.g_all_sessions_close_running or app.g_all_sessions_confirm) return;
    app.g_all_sessions_ctx = false;
    for (hits[0..hit_count]) |target| {
        if (!contains(target.rect, x, y)) continue;
        switch (target.action) {
            .search => archive.openAllSessionsFilter(hwnd),
            .server => |host| server_filter = if (server_filter == host) null else host,
            .state => |state| {
                state_filter = state;
                app.g_all_sessions_unattached_only = state == .no_window;
                if (app.g_all_sessions_tab == app.AS_TAB_ARCHIVED and state != .archived) app.g_all_sessions_tab = app.AS_TAB_ALL;
            },
            .tab => |tab| {
                app.g_all_sessions_tab = tab;
                if (tab == app.AS_TAB_ARCHIVED) {
                    state_filter = null;
                    app.g_all_sessions_unattached_only = false;
                }
            },
        }
        app.g_all_sessions_sel = 0;
        _ = win.InvalidateRect(hwnd, null, 0);
        return;
    }
    var rc: RECT = undefined;
    _ = win.GetClientRect(hwnd, &rc);
    const bounds = layout(rc.right, rc.bottom);
    if (x < bounds.left or x >= bounds.right or y < bounds.top or y >= bounds.bottom) return;
    var top = bounds.top - bounds.scroll;
    var previous: ?model.Group = null;
    var visible: u32 = 0;
    for (app.g_session_overview_rows.items) |row| {
        if (!archive.allSessionsRowVisible(&row)) continue;
        const group = model.group(row, today);
        if (previous != group) top += scale(26);
        previous = group;
        if (y >= top and y < top + scale(60)) {
            app.g_all_sessions_sel = visible;
            archive.allSessionsJump(hwnd);
            return;
        }
        visible += 1;
        top += scale(60);
    }
}

pub fn archiveSelected() void {
    const index = archive.allSessionsNthVisible(app.g_all_sessions_sel) orelse return;
    archive.archiveOverviewRow(app.g_session_overview_rows.items[index]);
    archive.buildSessionOverviewRows();
}

pub fn starSelected() void {
    const index = archive.allSessionsNthVisible(app.g_all_sessions_sel) orelse return;
    const row = app.g_session_overview_rows.items[index];
    if (!@import("all_sessions_metadata.zig").set(row.host, row.session[0..row.session_len], !row.favorite)) {
        @import("console.zig").showHeaderNoticeAscii("Could not save favorite", 3000, true);
        return;
    }
    if (@import("inbox.zig").findShellById(row.shell_id)) |shell| @import("inbox.zig").toggleFavorite(shell);
    archive.buildSessionOverviewRows();
}
