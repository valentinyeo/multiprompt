const app_state = @import("app_state.zig");
const std = @import("std");
const chat_markdown = @import("chat_markdown.zig");
const HANDLE = @import("win32.zig").HANDLE;
const SIZE = @import("win32.zig").SIZE;
const SelectObject = @import("win32.zig").SelectObject;
const GetTextExtentPoint32W = @import("win32.zig").GetTextExtentPoint32W;
const GetTextFaceW = @import("win32.zig").GetTextFaceW;
const CreateFontW = @import("fonts.zig").create;
const CHAT_QUALITY = @import("fonts.zig").CHAT_QUALITY;
const CreateCompatibleDC = @import("win32.zig").CreateCompatibleDC;
const DeleteDC = @import("win32.zig").DeleteDC;
const L = @import("startup.zig").L;
const debugLog = @import("diagnostics.zig").debugLog;
const verboseLoggingEnabled = @import("diagnostics.zig").verboseLoggingEnabled;
const ensureChatFont = @import("chat_composer.zig").ensureChatFont;
const uiScaled = @import("drawing.zig").uiScaled;

pub fn chatCodeFontPx() i32 {
    return uiScaled(@max(8, app_state.g_chat_font_pt - 3));
}

pub fn ensureChatCodeFont() HANDLE {
    if (app_state.g_chat_code_font == null) {
        app_state.g_chat_code_font = CreateFontW(-chatCodeFontPx(), 0, 0, 0, 600, 0, 0, 0, 0, 0, 0, CHAT_QUALITY, 0, L(@import("fonts.zig").MONO_FACE));
        logChatCodeFont(app_state.g_chat_code_font);
    }
    return app_state.g_chat_code_font;
}

pub fn ensureChatEmojiFont() HANDLE {
    if (app_state.g_chat_emoji_font == null) {
        app_state.g_chat_emoji_font = @import("fonts.zig").emoji(-uiScaled(app_state.g_chat_font_pt));
    }
    return app_state.g_chat_emoji_font;
}

fn logChatCodeFont(font: HANDLE) void {
    if (font == null or !verboseLoggingEnabled()) return;
    const dc = CreateCompatibleDC(null) orelse return;
    defer _ = DeleteDC(dc);
    const old_font = SelectObject(dc, ensureChatFont());
    defer _ = SelectObject(dc, old_font);
    const body_em = @import("dwrite_text.zig").emHeight(dc) orelse return;
    _ = SelectObject(dc, font);
    var face: [32]u16 = undefined;
    const face_len = GetTextFaceW(dc, face.len, &face);
    if (face_len <= 1) return;
    var face_utf8: [96]u8 = undefined;
    const face_bytes = std.unicode.utf16LeToUtf8(&face_utf8, face[0..@intCast(face_len - 1)]) catch return;
    const code_em = @import("dwrite_text.zig").emHeight(dc) orelse return;
    var cell: SIZE = undefined;
    if (GetTextExtentPoint32W(dc, L("\u{2588}"), 1, &cell) == 0) return;
    var line: [192]u8 = undefined;
    debugLog(std.fmt.bufPrint(&line, "[chatcode] face={s} em={d} advance={d} body_em={d} pt={d}", .{ face_utf8[0..face_bytes], code_em, cell.cx, body_em, app_state.g_chat_font_pt }) catch return);
}

pub fn chatLinkFont(code: bool) HANDLE {
    const slot = if (code) &app_state.g_chat_code_link_font else &app_state.g_chat_link_font;
    if (slot.* == null) {
        slot.* = if (code) CreateFontW(-chatCodeFontPx(), 0, 0, 0, 500, 0, 1, 0, 0, 0, 0, CHAT_QUALITY, 0, L(@import("fonts.zig").MONO_FACE)) else @import("fonts.zig").chat(-uiScaled(app_state.g_chat_font_pt), false, false, true, .{});
    }
    return slot.*;
}

pub fn chatRichFont(style: chat_markdown.Style, level: u3) HANDLE {
    if (style.code) {
        if (!style.bold) return ensureChatCodeFont();
        if (app_state.g_chat_rich_fonts[11] == null) app_state.g_chat_rich_fonts[11] = CreateFontW(-chatCodeFontPx(), 0, 0, 0, 700, 0, 0, 0, 0, 0, 0, CHAT_QUALITY, 0, L(@import("fonts.zig").MONO_FACE));
        return app_state.g_chat_rich_fonts[11];
    }
    const index: usize = if (level > 0) 4 + @as(usize, level) - 1 else @as(usize, @intFromBool(style.bold)) + 2 * @as(usize, @intFromBool(style.italic));
    if (index == 0) return ensureChatFont();
    if (app_state.g_chat_rich_fonts[index] == null) {
        const extra: i32 = if (level == 1) 8 else if (level == 2) 5 else if (level > 0) 2 else 0;
        app_state.g_chat_rich_fonts[index] = @import("fonts.zig").chat(-uiScaled(app_state.g_chat_font_pt + extra), style.bold or level > 0, style.italic, false, .{});
    }
    return app_state.g_chat_rich_fonts[index];
}

pub fn chatMetadataFont() HANDLE {
    if (app_state.g_chat_rich_fonts[10] == null) app_state.g_chat_rich_fonts[10] = @import("fonts.zig").chat(-uiScaled(@max(8, app_state.g_chat_font_pt - 3)), false, false, false, .{});
    return app_state.g_chat_rich_fonts[10];
}
