const std = @import("std");
const w = @import("win32.zig");
const app_state = @import("app_state.zig");
const drawing = @import("drawing.zig");
const smooth = @import("smooth.zig");
const L = std.unicode.utf8ToUtf16LeStringLiteral;

pub fn keycap(dc: w.HANDLE, text: [*:0]const u16, rc: *w.RECT) void {
    const light = app_state.g_light_theme;
    smooth.fillRoundRect(dc, rc.*, drawing.uiScaled(8), if (light) 0xdddddd else 0x2e2e2e);
    var inner = rc.*;
    inner.left += 1;
    inner.top += 1;
    inner.right -= 1;
    inner.bottom -= 1;
    smooth.fillRoundRect(dc, inner, drawing.uiScaled(8), if (light) 0xf5f5f5 else 0x1f1f1f);
    _ = w.SetTextColor(dc, if (light) 0x606060 else 0x8a8a8a);
    _ = w.DrawTextW(dc, text, -1, rc, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_CENTER | w.DT_NOPREFIX);
}

pub fn sentence(text: []const u16, out: []u16) []const u16 {
    var len = @min(text.len, out.len);
    @memcpy(out[0..len], text[0..len]);
    while (len > 0 and (out[len - 1] == '.' or out[len - 1] == 0x2026)) : (len -= 1) {}
    for (out[0..len], 0..) |*c, i| {
        if (i == 0 or c.* < 'A' or c.* > 'Z') continue;
        if (out[i - 1] == ' ' and i + 1 < len and out[i + 1] >= 'a' and out[i + 1] <= 'z') c.* += 32;
    }
    return out[0..len];
}

pub fn draw(dc: w.HANDLE, text: [*]const u16, count: i32, rc: *w.RECT, flags: u32) i32 {
    const original = if (count < 0) std.mem.span(@as([*:0]const u16, @ptrCast(text))) else text[0..@intCast(count)];
    if ((flags & w.DT_RIGHT) != 0) {
        const shortcut = std.mem.startsWith(u16, original, L("Ctrl+")) or std.mem.startsWith(u16, original, L("Alt+")) or std.mem.startsWith(u16, original, L("C-S-")) or std.mem.eql(u16, original, L("F1")) or std.mem.eql(u16, original, L("Esc"));
        if (!shortcut) return 0;
        var parts: [8][32:0]u16 = @splat(@splat(0));
        var widths: [8]i32 = @splat(0);
        var n: usize = 0;
        var it = std.mem.tokenizeAny(u16, original, L("+-"));
        while (it.next()) |part| {
            if (n == parts.len) break;
            const label = if (std.mem.eql(u16, part, L("C"))) L("Ctrl") else if (std.mem.eql(u16, part, L("S"))) L("Shift") else part;
            const len = @min(label.len, 31);
            @memcpy(parts[n][0..len], label[0..len]);
            var measure = std.mem.zeroes(w.RECT);
            _ = w.DrawTextW(dc, &parts[n], @intCast(len), &measure, w.DT_CALCRECT | w.DT_SINGLELINE | w.DT_NOPREFIX);
            widths[n] = measure.right + drawing.uiScaled(12);
            n += 1;
        }
        if (n < parts.len and original.len >= 2 and original[original.len - 2] == '+' and (original[original.len - 1] == '+' or original[original.len - 1] == '-')) {
            parts[n][0] = original[original.len - 1];
            widths[n] = drawing.uiScaled(24);
            n += 1;
        }
        var x = rc.right - drawing.uiScaled(16);
        var i = n;
        while (i > 0) {
            i -= 1;
            x -= widths[i];
            var cell = w.RECT{ .left = x, .top = @divFloor(rc.top + rc.bottom - drawing.uiScaled(24), 2), .right = x + widths[i], .bottom = @divFloor(rc.top + rc.bottom + drawing.uiScaled(24), 2) };
            keycap(dc, &parts[i], &cell);
            x -= drawing.uiScaled(4);
        }
        return 1;
    }
    var out: [256]u16 = undefined;
    const label = sentence(original, &out);
    return w.DrawTextW(dc, label.ptr, @intCast(label.len), rc, flags | w.DT_END_ELLIPSIS);
}

test "palette labels use sentence case without changing acronyms" {
    var out: [128]u16 = undefined;
    try std.testing.expectEqualSlices(u16, L("New host 1 VPS shell"), sentence(L("New Host 1 VPS Shell"), &out));
    try std.testing.expectEqualSlices(u16, L("Show all sessions"), sentence(L("Show All Sessions..."), &out));
}

pub fn footer(dc: w.HANDLE, rc: *const w.RECT) void {
    var x = rc.left;
    const keys = [_][*:0]const u16{ L("↑↓"), L("Enter"), L("Esc") };
    const labels = [_][*:0]const u16{ L("move"), L("open"), L("close") };
    for (keys, labels, 0..) |key, label, i| {
        const width = drawing.uiScaled(if (i == 1) @as(i32, 40) else 28);
        const top = @divFloor(rc.top + rc.bottom - drawing.uiScaled(24), 2);
        var cell = w.RECT{ .left = x, .top = top, .right = x + width, .bottom = top + drawing.uiScaled(24) };
        keycap(dc, key, &cell);
        var caption = w.RECT{ .left = cell.right + drawing.uiScaled(8), .top = rc.top, .right = cell.right + drawing.uiScaled(56), .bottom = rc.bottom };
        _ = w.DrawTextW(dc, label, -1, &caption, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_NOPREFIX);
        x = caption.right;
    }
}
