const std = @import("std");
const app_state = @import("app_state.zig");
const win32 = @import("win32.zig");
const render = @import("chat_render.zig");
const quote = @import("chat_user_quote.zig");
const quote_ui = @import("chat_user_quote_ui.zig");
const reply = @import("chat_reply.zig");
const drawing = @import("drawing.zig");

test "MUBO-237 blank-separated reply quotes keep their folded and expanded bubble body" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const text = w("> **First line**\n> Second line\n> Third line\n> Fourth line\n> Fifth line\n> Sixth line\n\nMy own words");
    const block = app_state.ChatBlock{ .start = 0, .len = text.len, .role = .user };
    const display = render.ChatDisplay{ .text = text, .offset = 0, .reply_ref = reply.reference(text) };
    try std.testing.expect(display.reply_ref != null);
    const parts = quote.parse(text) orelse return error.TestUnexpectedResult;
    const dc = win32.GetDC(null) orelse return error.TestUnexpectedResult;
    defer _ = win32.ReleaseDC(null, dc);
    const key = quote.blockKey(block, text);
    quote.setOpen(key, false);
    defer quote.setOpen(key, false);
    const pad = drawing.uiScaled(app_state.CHAT_BUBBLE_PAD);
    const folded = render.chatMeasureBlockRect(dc, text, block, .single, 720, 0, null);
    const inner_w = folded.right - folded.left - 2 * pad;
    const body_h = quote_ui.measureHeight(dc, display, block, parts, inner_w);
    try std.testing.expectEqual(body_h + 2 * pad + drawing.uiScaled(24), folded.bottom);
    quote.setOpen(key, true);
    const expanded = render.chatMeasureBlockRect(dc, text, block, .single, 720, 0, null);
    try std.testing.expect(expanded.bottom > folded.bottom);
    const expanded_w = expanded.right - expanded.left - 2 * pad;
    const expanded_h = quote_ui.measureHeight(dc, display, block, parts, expanded_w);
    try std.testing.expectEqual(expanded_h + 2 * pad + drawing.uiScaled(24), expanded.bottom);
}
