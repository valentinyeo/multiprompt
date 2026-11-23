const std = @import("std");
const app_state = @import("app_state.zig");
const HANDLE = @import("win32.zig").HANDLE;
const RECT = @import("win32.zig").RECT;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const uiScaled = @import("drawing.zig").uiScaled;
const customColorOr = @import("themes.zig").customColorOr;
const themeConsoleBg = @import("themes.zig").themeConsoleBg;
const themeConsoleFg = @import("themes.zig").themeConsoleFg;
const CHAT_AGENT_PAD_X = app_state.CHAT_AGENT_PAD_X;

pub const WORKING_DOT_SIZE = 4;
pub const WORKING_DOT_STEP = 8;
const WORKING_DOT_ALPHA: u8 = 102;

var layout_rect: ?RECT = null;
var painted_rect: ?RECT = null;

pub fn visible() bool {
    return @import("window_layout.zig").chatStopVisible();
}

pub fn layoutRect() ?RECT {
    return layout_rect;
}

pub fn setLayoutRect(rc: RECT) void {
    layout_rect = rc;
}

pub fn clearLayoutRect() void {
    layout_rect = null;
}

pub fn shiftLayout(delta: i32) void {
    if (layout_rect) |*rect| {
        rect.top += delta;
        rect.bottom += delta;
    }
}

pub fn screenRect(source: ?RECT, scroll_y: i32) ?RECT {
    const rect = source orelse return null;
    return .{ .left = rect.left, .top = rect.top - scroll_y, .right = rect.right, .bottom = rect.bottom - scroll_y };
}

pub fn repaintRegion(painted: ?RECT, current: ?RECT) ?RECT {
    const a = painted orelse return current;
    const b = current orelse return a;
    return .{ .left = @min(a.left, b.left), .top = @min(a.top, b.top), .right = @max(a.right, b.right), .bottom = @max(a.bottom, b.bottom) };
}

fn overlaps(a: RECT, b: RECT) bool {
    return a.bottom > b.top and a.top < b.bottom and a.right > b.left and a.left < b.right;
}

pub fn sync() void {
    const hwnd = app_state.g_chat_transcript_hwnd orelse return;
    if ((layout_rect != null) != visible()) {
        var rc: RECT = std.mem.zeroes(RECT);
        @import("chat_render.zig").chatViewClientRect(&rc);
        @import("chat_session.zig").chatRelayoutPreservingScroll(rc.right - rc.left, rc.bottom - rc.top);
        _ = InvalidateRect(hwnd, null, 0);
        painted_rect = null;
        return;
    }
    const current = screenRect(layout_rect, app_state.g_chat_scroll_y);
    if (repaintRegion(painted_rect, current)) |rc| _ = InvalidateRect(hwnd, &rc, 0);
    painted_rect = current;
}

pub fn paint(hdc: HANDLE, paint_rect: RECT, now: u64) void {
    const rc = screenRect(layout_rect, app_state.g_chat_scroll_y) orelse {
        if (painted_rect) |stale| {
            if (overlaps(stale, paint_rect)) painted_rect = null;
        }
        return;
    };
    if (!visible() or !overlaps(rc, paint_rect)) return;
    paintDots(hdc, rc, now);
    painted_rect = repaintRegion(painted_rect, rc);
}

pub fn paintDots(hdc: HANDLE, rc: RECT, now: u64) void {
    const size = uiScaled(WORKING_DOT_SIZE);
    const step = uiScaled(WORKING_DOT_STEP);
    const active = (now / 250) % 3;
    const color = @import("chat_scrollbar.zig").blend(themeConsoleBg(), customColorOr("text", themeConsoleFg()), WORKING_DOT_ALPHA);
    for (0..3) |i| {
        const x = rc.left + uiScaled(CHAT_AGENT_PAD_X) + @as(i32, @intCast(i)) * step;
        const y = rc.top + @divTrunc(rc.bottom - rc.top - size, 2) - (if (i == active) uiScaled(2) else @as(i32, 0));
        @import("smooth.zig").fillEllipse(hdc, .{ .left = x, .top = y, .right = x + size, .bottom = y + size }, color);
    }
}

test "SOFT-2642 a moved working row repaints the row it left behind" {
    const first = RECT{ .left = 8, .top = 100, .right = 608, .bottom = 128 };
    const moved = RECT{ .left = 8, .top = 128, .right = 608, .bottom = 156 };
    try std.testing.expectEqualDeep(@as(?RECT, first), repaintRegion(null, first));
    try std.testing.expectEqualDeep(@as(?RECT, first), repaintRegion(first, null));
    try std.testing.expectEqualDeep(@as(?RECT, null), repaintRegion(null, null));
    try std.testing.expectEqualDeep(RECT{ .left = 8, .top = 100, .right = 608, .bottom = 156 }, repaintRegion(first, moved).?);
}

test "SOFT-2642 the working row is measured against the scroll offset" {
    const doc = RECT{ .left = 8, .top = 100, .right = 608, .bottom = 128 };
    try std.testing.expectEqualDeep(@as(?RECT, RECT{ .left = 8, .top = 140, .right = 608, .bottom = 168 }), screenRect(doc, -40));
    try std.testing.expectEqualDeep(@as(?RECT, null), screenRect(null, -40));
}
