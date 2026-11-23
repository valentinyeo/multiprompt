pub fn spawnShellFromMenuIndex(kind_idx: usize) bool {
    if (kind_idx >= NUM_BUTTONS) return false;
    const k = MENU_KIND_ORDER[kind_idx];
    if (tmuxHostForMenuIndex(kind_idx)) |host| {
        app_state.g_pending_tmux_host = host;
        defer app_state.g_pending_tmux_host = 0;
        return spawnShell(k);
    }
    return spawnShell(k);
}
