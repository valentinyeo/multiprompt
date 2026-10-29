const win = @import("win32.zig");
const design = @import("design_tokens.zig");

hdc: win.HANDLE,

pub fn roundRect(self: *@This(), rect: design.Rect, radius: i32, color: u32) void {
    @import("chat_render.zig").fillRoundRectAA(self.hdc, @bitCast(rect), radius, color);
}

pub fn clip(self: *@This(), rect: design.Rect) i32 {
    const saved = win.SaveDC(self.hdc);
    _ = win.IntersectClipRect(self.hdc, rect.left, rect.top, rect.right, rect.bottom);
    return saved;
}

pub fn restore(self: *@This(), saved: i32) void {
    _ = win.RestoreDC(self.hdc, saved);
}

pub fn bubbleFill(self: *@This(), rect: design.Rect, radius: i32, color: u32, round_top: bool, round_bottom: bool) void {
    if (round_top and round_bottom) return self.roundRect(rect, radius, color);
    const saved = self.clip(rect);
    defer self.restore(saved);
    var extended = rect;
    if (!round_top) extended.top -= 2 * radius + 2;
    if (!round_bottom) extended.bottom += 2 * radius + 2;
    self.roundRect(extended, radius, color);
}

pub fn label(self: *@This(), rect: design.Rect, text: []const u16, height: i32, ink: u32) void {
    const font = @import("fonts.zig").chat(-height, false, false, false, .{ .body_weight = 500 });
    const old_font = win.SelectObject(self.hdc, font);
    defer {
        _ = win.SelectObject(self.hdc, old_font);
        _ = win.DeleteObject(font);
    }
    _ = win.SetBkMode(self.hdc, 1);
    _ = win.SetTextColor(self.hdc, ink);
    var bounds: win.RECT = @bitCast(rect);
    _ = win.DrawTextW(self.hdc, text.ptr, @intCast(text.len), &bounds, win.DT_SINGLELINE | win.DT_VCENTER | win.DT_NOPREFIX);
}
