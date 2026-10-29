const std = @import("std");
const app_state = @import("app_state.zig");
const w32 = @import("win32.zig");
const RECT = w32.RECT;

const RGN_DIFF: i32 = 4;
const MAX_HOLES = 7 + std.meta.tags(@import("chat_permission.zig").Action).len;

pub fn moat() i32 {
    return @import("drawing.zig").uiScaled(6);
}

pub const Hole = struct {
    rect: RECT,
    radius: i32,
};

pub const HoleList = struct {
    items: [MAX_HOLES]Hole = undefined,
    len: usize = 0,

    pub fn add(self: *HoleList, rect: RECT, radius: i32) void {
        if (rect.right <= rect.left or rect.bottom <= rect.top) return;
        std.debug.assert(self.len < MAX_HOLES);
        self.items[self.len] = .{ .rect = rect, .radius = radius };
        self.len += 1;
    }

    pub fn addFloating(self: *HoleList, rect: RECT, radius: i32) void {
        const gap = moat();
        self.add(.{ .left = rect.left - gap, .top = rect.top - gap, .right = rect.right + gap, .bottom = rect.bottom + gap }, radius + gap);
    }
};

pub fn collectHoles(out: *HoleList) void {
    const chat_composer = @import("chat_composer.zig");
    const window_layout = @import("window_layout.zig");
    const drawing = @import("drawing.zig");
    const layout = chat_composer.chatViewLayout();
    out.addFloating(layout.composer_card, window_layout.chatSurfaceRadius());
    out.addFloating(layout.attach_btn, @divTrunc(layout.attach_btn.bottom - layout.attach_btn.top, 2));
    var main_rc: RECT = std.mem.zeroes(RECT);
    if (app_state.g_main_hwnd != null) _ = w32.GetClientRect(app_state.g_main_hwnd, &main_rc);
    out.add(@import("window_frame.zig").controlsRect(main_rc.right), 0);
    if (drawing.chatTitleHoleRect(main_rc.right - main_rc.left)) |band| {
        out.add(band, 0);
    } else if (drawing.chatTitleLayout()) |title| {
        out.addFloating(title.pill, @divTrunc(title.pill.bottom - title.pill.top, 2));
        out.addFloating(title.more, @divTrunc(title.more.bottom - title.more.top, 2));
        if (title.meta.len > 0) out.addFloating(title.meta_pill, @divTrunc(title.meta_pill.bottom - title.meta_pill.top, 2));
    }
    if (chat_composer.chatNewMessagesRect()) |pill| out.addFloating(pill, drawing.uiScaled(13));
    if (window_layout.chatPermissionVisible()) {
        for (std.meta.tags(@import("chat_permission.zig").Action)) |action| {
            if (window_layout.chatPermissionRect(action)) |rc| out.addFloating(rc, drawing.uiScaled(6));
        }
    }
}

fn signature(window: RECT, holes: *const HoleList) u64 {
    var hasher = std.hash.Wyhash.init(0x933);
    hasher.update(std.mem.asBytes(&window));
    for (holes.items[0..holes.len]) |hole| hasher.update(std.mem.asBytes(&hole));
    return hasher.final() | 1;
}

pub fn buildRegion(window: RECT, holes: *const HoleList) w32.HANDLE {
    const width = window.right - window.left;
    const height = window.bottom - window.top;
    const base = w32.CreateRectRgn(0, 0, width, height);
    if (base == null) return null;
    for (holes.items[0..holes.len]) |hole| {
        const r = hole.rect;
        const left = r.left - window.left - 1;
        const top = r.top - window.top - 1;
        const right = r.right - window.left + 1;
        const bottom = r.bottom - window.top + 1;
        const diameter = if (hole.radius > 0) (hole.radius + 1) * 2 else 0;
        const piece = if (diameter > 0) w32.CreateRoundRectRgn(left, top, right + 1, bottom + 1, diameter, diameter) else w32.CreateRectRgn(left, top, right, bottom);
        if (piece == null) continue;
        _ = w32.CombineRgn(base, base, piece, RGN_DIFF);
        _ = w32.DeleteObject(piece);
    }
    return base;
}

pub fn syncChatRegion() void {
    const hwnd = app_state.g_chat_transcript_hwnd;
    if (hwnd == null) return;
    if (!app_state.g_chat_active or !@import("chat_composer.zig").chatViewOwnsInput()) {
        if (app_state.g_chat_hole_signature != 0) {
            _ = w32.SetWindowRgn(hwnd, null, 1);
            app_state.g_chat_hole_signature = 0;
        }
        return;
    }
    const window = @import("chat_composer.zig").chatViewLayout().transcript_window;
    var holes = HoleList{};
    collectHoles(&holes);
    const sig = signature(window, &holes);
    if (sig == app_state.g_chat_hole_signature) return;
    const base = buildRegion(window, &holes) orelse return;
    if (w32.SetWindowRgn(hwnd, base, 1) == 0) {
        _ = w32.DeleteObject(base);
        return;
    }
    app_state.g_chat_hole_signature = sig;
}
