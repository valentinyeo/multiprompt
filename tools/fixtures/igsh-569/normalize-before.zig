pub fn normalizeGroupOrder() void {
    if (app_state.g_starred_workspace) return;
    if (app_state.shell_count < 2) return;
    const active_pid: DWORD = if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].pid else 0;

    var tmp: [MAX_SHELLS]Shell = undefined;
    var written: u32 = 0;
    var consumed: [MAX_SHELLS]bool = [_]bool{false} ** MAX_SHELLS;

    var i: u32 = 0;
    while (i < app_state.shell_count) : (i += 1) {
        if (consumed[i]) continue;
        tmp[written] = app_state.shells[i];
        written += 1;
        consumed[i] = true;
        const gid = app_state.shells[i].group_id;
        if (gid == 0) continue;
        var j: u32 = i + 1;
        while (j < app_state.shell_count) : (j += 1) {
            if (consumed[j]) continue;
            if (app_state.shells[j].group_id == gid) {
                tmp[written] = app_state.shells[j];
                written += 1;
                consumed[j] = true;
            }
        }
    }

    var k: u32 = 0;
    while (k < written) : (k += 1) app_state.shells[k] = tmp[k];

    if (active_pid != 0) {
        k = 0;
        while (k < app_state.shell_count) : (k += 1) {
            if (app_state.shells[k].pid == active_pid) {
                app_state.active_shell = k;
                break;
            }
        }
    }
}
