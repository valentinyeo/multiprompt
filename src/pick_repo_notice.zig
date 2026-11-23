const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;

pub fn showPickRepoFailure(saving_folder: bool) void {
    const palette = @import("command_palette.zig");
    if (palette.g_pick_repo_offline) {
        showHeaderNoticeAscii("Pick repo: server is offline", 4000, true);
        return;
    }
    if (saving_folder) {
        showHeaderNoticeAscii("Set workspace folder: could not save", 4000, true);
        return;
    }
    if (palette.g_pick_row_gone) {
        showHeaderNoticeAscii("Pick repo: that row is gone; open the list again", 4000, true);
        return;
    }
    switch (palette.g_start_fail) {
        .capacity => {},
        .launch_command => showHeaderNoticeAscii("Pick repo: that folder path cannot start a session", 5000, true),
        .spawn_shell => showHeaderNoticeAscii("Pick repo: the new tab did not start", 5000, true),
        .none => showHeaderNoticeAscii("Pick repo: nothing started", 4000, true),
    }
}

