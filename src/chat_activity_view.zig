const std = @import("std");
const app_state = @import("app_state.zig");
const chat_activity = @import("chat_activity.zig");
const chat_hit = @import("chat_hit.zig");
const chat_live = @import("chat_live.zig");

const win32 = @import("win32.zig");
const HANDLE = win32.HANDLE;
const RECT = win32.RECT;
const POINT = win32.POINT;
const TRANSPARENT = win32.TRANSPARENT;
const DT_SINGLELINE = win32.DT_SINGLELINE;
const DT_VCENTER = win32.DT_VCENTER;
const DT_CENTER = win32.DT_CENTER;
const DT_NOPREFIX = win32.DT_NOPREFIX;
const DT_END_ELLIPSIS = win32.DT_END_ELLIPSIS;
const SetBkMode = win32.SetBkMode;
const SetTextColor = win32.SetTextColor;
const SelectObject = win32.SelectObject;
const DWORD = win32.DWORD;
const GetSystemTimeAsFileTime = win32.GetSystemTimeAsFileTime;
const GetClientRect = win32.GetClientRect;
const InvalidateRect = win32.InvalidateRect;

const uiScaled = @import("drawing.zig").uiScaled;
const RGB = @import("startup.zig").RGB;
const chatDrawText = @import("dwrite_text.zig").draw;
const customColorOr = @import("themes.zig").customColorOr;
const themeConsoleBg = @import("themes.zig").themeConsoleBg;
const themeConsoleFg = @import("themes.zig").themeConsoleFg;
const fillRoundRectAA = @import("smooth.zig").fillRoundRect;
const chatSurfaceBorderW = @import("window_layout.zig").chatSurfaceBorderW;
const chatSurfaceBorderColor = @import("window_layout.zig").chatSurfaceBorderColor;
const chatRelayoutPreservingScroll = @import("chat_session.zig").chatRelayoutPreservingScroll;
const FILETIME_UNIX_EPOCH_DELTA_100NS = @import("app_state.zig").FILETIME_UNIX_EPOCH_DELTA_100NS;

pub const ROW_H: i32 = 18;
pub const LINE_H: i32 = 20;
pub const PILL_H: i32 = 24;

var activity: chat_activity.Activity = .{};
var visible = false;
var open = false;
var rows: usize = 0;
var line_rect: ?RECT = null;
var rows_rect: ?RECT = null;
var stamp: u64 = 0;
var synced_stamp: u64 = 0;

fn nowMs() u64 {
    var stamp: [2]DWORD = undefined;
    GetSystemTimeAsFileTime(&stamp);
    const ticks = (@as(u64, stamp[1]) << 32) | stamp[0];
    return ticks / 10_000 -| @as(u64, @intCast(FILETIME_UNIX_EPOCH_DELTA_100NS / 10_000));
}

fn metadataFont() HANDLE {
    if (app_state.g_chat_rich_fonts[10] == null) app_state.g_chat_rich_fonts[10] = @import("fonts.zig").chat(-uiScaled(@max(8, app_state.g_chat_font_pt - 3)), false, false, false, .{});
    return app_state.g_chat_rich_fonts[10];
}

fn view(out: *chat_activity.Activity) bool {
    if (app_state.active_shell >= app_state.shell_count) return false;
    const shell_id = app_state.shells[app_state.active_shell].shell_id;
    if (shell_id == 0 or !chat_live.attached(shell_id)) return false;
    return chat_live.activityFor(shell_id, out);
}

fn stampOf(value: *const chat_activity.Activity) u64 {
    var h = std.hash.Wyhash.init(0);
    h.update(std.mem.asBytes(&value.running));
    h.update(value.stepSlice());
    h.update(std.mem.asBytes(&value.worker_count));
    for (value.workers[0..value.worker_count]) |*worker| {
        h.update(worker.idSlice());
        h.update(worker.harnessSlice());
        h.update(worker.modelSlice());
        h.update(worker.labelSlice());
    }
    return h.final();
}

pub fn refresh() void {
    activity = .{};
    visible = view(&activity);
    stamp = stampOf(&activity);
}

pub fn reset() void {
    line_rect = null;
    rows_rect = null;
    rows = 0;
    visible = false;
}

pub fn isVisible() bool {
    return visible;
}

pub fn isOpen() bool {
    return open;
}

pub fn rowCount() usize {
    return rows;
}

pub fn currentStamp() u64 {
    return stamp;
}

pub fn wantRows() usize {
    return if (visible and open) activity.expandedRows() else 0;
}

pub fn hasLine() bool {
    return line_rect != null;
}

pub fn layout(rect: RECT, top: i32) i32 {
    line_rect = rect;
    rows = 0;
    if (!visible or !open) return top;
    rows = activity.expandedRows();
    if (rows == 0) return top;
    const height = uiScaled(ROW_H) * @as(i32, @intCast(rows));
    rows_rect = RECT{ .left = rect.left, .top = top, .right = rect.right, .bottom = top + height };
    return top + height;
}

pub fn region(scroll_y: i32) ?RECT {
    const source = line_rect orelse return null;
    var rc = RECT{ .left = source.left, .top = source.top - scroll_y, .right = source.right, .bottom = source.bottom - scroll_y };
    if (rows_rect) |extra| rc.bottom = extra.bottom - scroll_y;
    return rc;
}

fn clientRect() RECT {
    var rc: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(app_state.g_chat_transcript_hwnd, &rc);
    rc.bottom = @max(rc.top + 1, rc.bottom - app_state.g_chat_bottom_inset);
    return rc;
}

fn relayout() void {
    const rc = clientRect();
    chatRelayoutPreservingScroll(rc.right - rc.left, rc.bottom - rc.top);
}

pub fn sync(dots_visible: bool, dots_rect: ?RECT, scroll_y: i32) void {
    if (app_state.g_chat_transcript_hwnd == null) return;
    refresh();
    const shown = dots_rect != null or line_rect != null;
    if (shown != (dots_visible or visible) or wantRows() != rows) {
        relayout();
        _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    } else if (region(scroll_y)) |found| {
        var rc = found;
        _ = InvalidateRect(app_state.g_chat_transcript_hwnd, &rc, 0);
    } else if (dots_rect) |source| {
        var rc = source;
        rc.top -= scroll_y;
        rc.bottom -= scroll_y;
        _ = InvalidateRect(app_state.g_chat_transcript_hwnd, &rc, 0);
    }
    if (stamp != synced_stamp) {
        synced_stamp = stamp;
        _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    }
}

pub fn toggleAt(y: i32, scroll_y: i32) bool {
    if (!visible) return false;
    const source = line_rect orelse return false;
    const top = source.top - scroll_y;
    const line_bottom = source.bottom - scroll_y;
    var rows_bottom = line_bottom;
    if (rows_rect) |extra| rows_bottom = extra.bottom - scroll_y;
    if (!chat_hit.activityHit(y, top, line_bottom, rows_bottom)) return false;
    open = !open;
    return true;
}

pub fn toggleAndRelayout(y: i32, scroll_y: i32) bool {
    if (!toggleAt(y, scroll_y)) return false;
    relayout();
    _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    return true;
}

fn subtitleColor() u32 {
    return customColorOr("subtitle", if (app_state.g_light_theme) RGB(85, 98, 115) else RGB(167, 180, 198));
}

pub fn paintLine(hdc: HANDLE, scroll_y: i32, dots: bool) void {
    if (!visible) return;
    const source = line_rect orelse return;
    var rc = RECT{ .left = source.left, .top = source.top - scroll_y, .right = source.right, .bottom = source.bottom - scroll_y };
    const old_font = SelectObject(hdc, metadataFont());
    defer _ = SelectObject(hdc, old_font);
    _ = SetBkMode(hdc, TRANSPARENT);
    _ = SetTextColor(hdc, customColorOr("text", themeConsoleFg()));
    var label: [128]u8 = undefined;
    var wide: [160]u16 = undefined;
    const text = chat_activity.lineText(&activity, &label);
    const len = std.unicode.utf8ToUtf16Le(&wide, text) catch 0;
    const indent: i32 = if (dots) uiScaled(38) else 0;
    var text_rc = RECT{ .left = rc.left + indent, .top = rc.top, .right = rc.right - uiScaled(14), .bottom = rc.bottom };
    _ = chatDrawText(hdc, &wide, @intCast(len), &text_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
    paintChevron(hdc, rc);
    const extra = rows_rect orelse return;
    var row_top = extra.top - scroll_y;
    const row_h = uiScaled(ROW_H);
    const bottom = extra.bottom - scroll_y;
    for (activity.steps[0..activity.step_count]) |*step| {
        var row = RECT{ .left = rc.left + indent, .top = row_top, .right = rc.right, .bottom = row_top + row_h };
        _ = SetTextColor(hdc, if (step.running) customColorOr("text", themeConsoleFg()) else subtitleColor());
        const n = std.unicode.utf8ToUtf16Le(&wide, step.textSlice()) catch 0;
        _ = chatDrawText(hdc, &wide, @intCast(n), &row, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        row_top += row_h;
    }
    const now = nowMs();
    for (activity.workers[0..activity.worker_count]) |*worker| {
        if (row_top + row_h > bottom) break;
        var row = RECT{ .left = rc.left + indent, .top = row_top, .right = rc.right, .bottom = row_top + row_h };
        _ = SetTextColor(hdc, subtitleColor());
        var line: [96]u8 = undefined;
        const worker_text = chat_activity.workerLine(worker, now, &line);
        const n = std.unicode.utf8ToUtf16Le(&wide, worker_text) catch 0;
        _ = chatDrawText(hdc, &wide, @intCast(n), &row, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        row_top += row_h;
    }
}

fn paintChevron(hdc: HANDLE, rc: RECT) void {
    var canvas = @import("smooth.zig").Canvas.init(hdc);
    defer canvas.deinit();
    const cx = rc.right - uiScaled(8);
    const cy = rc.top + @divTrunc(rc.bottom - rc.top, 2);
    const arm = uiScaled(4);
    const lift = uiScaled(2);
    const down = [_]POINT{
        .{ .x = cx - arm, .y = cy - lift },
        .{ .x = cx, .y = cy + lift },
        .{ .x = cx + arm, .y = cy - lift },
    };
    const up = [_]POINT{
        .{ .x = cx - arm, .y = cy + lift },
        .{ .x = cx, .y = cy - lift },
        .{ .x = cx + arm, .y = cy + lift },
    };
    canvas.strokePolyline(if (open) &up else &down, subtitleColor(), @floatFromInt(@max(1, uiScaled(1))));
}

pub fn paintPill(hdc: HANDLE, width: i32, top_pad: i32) void {
    if (!visible) return;
    var label: [128]u8 = undefined;
    const text = chat_activity.pillText(&activity, &label);
    if (text.len == 0) return;
    const pill_width = @min(width - uiScaled(32), uiScaled(420));
    if (pill_width <= 0) return;
    const height = uiScaled(PILL_H);
    const top = top_pad + uiScaled(6);
    const left = @divTrunc(width - pill_width, 2);
    const rc = RECT{ .left = left, .top = top, .right = left + pill_width, .bottom = top + height };
    const edge = chatSurfaceBorderW();
    const radius = uiScaled(12);
    fillRoundRectAA(hdc, rc, radius, chatSurfaceBorderColor());
    fillRoundRectAA(hdc, .{ .left = rc.left + edge, .top = rc.top + edge, .right = rc.right - edge, .bottom = rc.bottom - edge }, @max(0, radius - edge), app_state.g_chat_input_color);
    const old_font = SelectObject(hdc, metadataFont());
    defer _ = SelectObject(hdc, old_font);
    _ = SetBkMode(hdc, TRANSPARENT);
    _ = SetTextColor(hdc, customColorOr("text", themeConsoleFg()));
    var wide: [160]u16 = undefined;
    const len = std.unicode.utf8ToUtf16Le(&wide, text) catch 0;
    var text_rc = RECT{ .left = rc.left + uiScaled(10), .top = rc.top, .right = rc.right - uiScaled(10), .bottom = rc.bottom };
    _ = chatDrawText(hdc, &wide, @intCast(len), &text_rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
}
