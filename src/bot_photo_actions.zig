const std = @import("std");
const w = @import("win32.zig");
const app = @import("app_state.zig");
const photo = @import("bot_photo.zig");
const words = @import("ui_words.zon");
const L = std.unicode.utf8ToUtf16LeStringLiteral;

pub const choices = .{
    .{ app.SEARCH_BOT_PHOTO_UPLOAD, words.bot_photo_upload },
    .{ app.SEARCH_BOT_PHOTO_GENERATE, words.bot_photo_generate },
    .{ app.SEARCH_BOT_PHOTO_RESET, words.bot_photo_reset },
};

pub fn label(target: usize) ?[]const u8 {
    inline for (choices) |choice| if (target == choice[0]) return choice[1];
    return null;
}

pub fn appendResults() void {
    inline for (choices) |choice| {
        if (app.g_search_result_count < app.g_search_results.len and @import("command_palette.zig").asciiContainsQueryInsensitive(choice[1], app.g_search_buf[0..app.g_search_len])) {
            app.g_search_results[app.g_search_result_count] = choice[0];
            app.g_search_result_count += 1;
        }
    }
}

pub fn run(hwnd: w.HANDLE, target: usize) void {
    const sid = app.g_bot_look_sid;
    const idx = @import("inbox.zig").findShellById(sid) orelse return;
    if (!@import("bot_look.zig").eligible(idx)) return;
    if (target == app.SEARCH_BOT_PHOTO_GENERATE) {
        _ = w.SendMessageW(hwnd, w.WM_APP_SEARCH_CLOSE, 0, 0);
        @import("bot_picture.zig").show(hwnd, idx);
        return;
    }
    if (target == app.SEARCH_BOT_PHOTO_RESET) {
        if (photo.key(&app.shells[idx])) |digest| {
            if (!photo.reset(digest)) @import("console.zig").showHeaderNoticeAscii("Could not reset image", 4000, true);
        }
    } else {
        const digest = photo.ensureKey(idx) orelse {
            @import("console.zig").showHeaderNoticeAscii("Could not save picture", 4000, true);
            return;
        };
        const title_id = app.shells[idx].title_id;
        var file: [32768]u16 = @splat(0);
        var picker = std.mem.zeroes(app.OPENFILENAMEW);
        picker.lStructSize = @sizeOf(app.OPENFILENAMEW);
        picker.hwndOwner = hwnd;
        picker.lpstrFilter = L("Images\x00*.png;*.jpg;*.jpeg\x00");
        picker.nFilterIndex = 1;
        picker.lpstrFile = &file;
        picker.nMaxFile = file.len;
        picker.lpstrTitle = L("Upload image");
        picker.Flags = 0x00080000 | 0x00001000 | 0x00000800 | 0x00000004 | 0x00000008;
        if (@import("fonts.zig").openFileName(&picker) != 0) {
            const current = @import("inbox.zig").findShellById(sid) orelse return;
            if (!@import("bot_look.zig").eligible(current) or app.shells[current].title_id != title_id) return;
            const current_key = photo.key(&app.shells[current]) orelse return;
            if (!std.mem.eql(u8, &digest, &current_key)) return;
            if (photo.import(digest, @ptrCast(&file))) {
                @import("diagnostics.zig").debugLog("[bot-photo] import=ok");
            } else {
                @import("diagnostics.zig").debugLog("[bot-photo] import=failed");
                @import("console.zig").showHeaderNoticeAscii("Could not use that image", 4000, true);
            }
        }
    }
    _ = w.SendMessageW(hwnd, w.WM_APP_SEARCH_CLOSE, 0, 0);
    _ = w.InvalidateRect(hwnd, null, 1);
}
