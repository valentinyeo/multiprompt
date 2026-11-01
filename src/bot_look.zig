const state = @import("app_state.zig");
const words = @import("ui_words.zon");

pub const faces = [_][]const u8{
    words.settings_color_auto, words.bot_face_classic, words.bot_face_happy, words.bot_face_square_eyes,
    words.bot_face_calm, words.bot_face_cyclops, words.bot_face_wink, words.bot_face_curious,
    words.bot_face_dome, words.bot_face_peek_left, words.bot_face_peek_left_square, words.bot_face_rise,
    words.bot_face_square_head, words.bot_face_tilted, words.bot_face_closeup, words.bot_face_tv,
    words.bot_face_headphones, words.bot_face_profile, words.bot_face_corner_peek, words.bot_face_grill,
    words.bot_face_hang,
};
pub const colors = [_][]const u8{
    words.settings_color_auto, words.bot_color_sage, words.bot_color_clay, words.bot_color_sand,
    words.bot_color_mist, words.bot_color_lilac, words.bot_color_rose, words.bot_color_mint,
};

pub fn eligible(idx: u32) bool {
    if (idx >= state.shell_count or state.g_account_locked or state.g_restoring or state.g_account_applying) return false;
    if (@import("launch_cache.zig").pending and !@import("launch_cache.zig").tabs_restored) return false;
    if (!@import("room_frontend.zig").privateActionsAllowed()) return false;
    const shell = &state.shells[idx];
    if (shell.kind == .tmux and !state.g_account_bypass) {
        if (shell.tmux_host > 2 or shell.tmux_session_len == 0 or shell.tmux_session_len > 63) return false;
        for (shell.tmux_session[0..shell.tmux_session_len]) |c| {
            if (!@import("std").ascii.isAlphanumeric(c) and c != '_' and c != '-') return false;
        }
    }
    return true;
}
