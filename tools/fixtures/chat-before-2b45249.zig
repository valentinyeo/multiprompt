var next_shell_id: u32 = 0;

fn chatArmSendVerify(shell_index: u32, text: []const u16, echo_id: u64) void {
    if (shell_index >= shell_count or g_main_hwnd == null) return;
    var start: usize = 0;
    while (start < text.len and (text[start] == ' ' or text[start] == '\t')) : (start += 1) {}
    var n: usize = 0;
    while (start + n < text.len and n < g_chat_verify_prefix.len) : (n += 1) {
        const c = text[start + n];
        if (c == '\r' or c == '\n') break;
        g_chat_verify_prefix[n] = c;
    }
    g_chat_verify_prefix_len = n;
    g_chat_verify_shell_id = shells[shell_index].shell_id;
    g_chat_verify_checks = 0;
    g_chat_verify_echo_id = echo_id;
    if (n > 0) _ = SetTimer(g_main_hwnd, TIMER_CHAT_SEND_VERIFY, CHAT_SEND_VERIFY_DELAYS_MS[0], null);
}

fn chatSendVerifyTick() void {
    if (g_chat_verify_prefix_len == 0) {
        chatVerifyClear();
        return;
    }
    var found: ?u32 = null;
    for (0..shell_count) |i| {
        if (shells[i].shell_id == g_chat_verify_shell_id) {
            found = @intCast(i);
            break;
        }
    }
    const echo_index: ?usize = if (g_chat_verify_echo_id != 0) chatOutboxIndexById(g_chat_verify_echo_id) else null;
    g_chat_verify_checks += 1;
    if (found) |si| {
        if (chatPromptStillInInputBox(si, g_chat_verify_prefix[0..g_chat_verify_prefix_len])) {
            if (chatSendVerifyDelayMs(g_chat_verify_checks)) |delay| {
                dictationAudit("chat-send-enter-retry", g_chat_verify_checks);
                _ = sendEnterToShell(si);
                if (g_main_hwnd != null) {
                    _ = SetTimer(g_main_hwnd, TIMER_CHAT_SEND_VERIFY, delay, null);
                    return;
                }
            } else {
                dictationAudit("chat-send-failed", g_chat_verify_checks);
                if (echo_index) |ei| chatEchoMarkNotSent(ei);
                showHeaderNoticeAscii("Message not sent - still in the input box (press Enter in the terminal)", 8000, true);
            }
        } else if (echo_index) |ei| {
            if (chatEchoTryMatchEntry(ei)) {
                chatVerifyClear();
                return;
            }
            g_chat_outbox.items[ei].state = .delivered;
            g_chat_outbox.items[ei].left_box_ms = GetTickCount64();
            _ = saveChatOutbox();
            chatOutboxChanged();
            chatVerifyClear();
            chatOutboxTick();
            return;
        }
    }
    chatVerifyClear();
}

fn sendTextToShellVerifiedAt(shell_index: u32, send_text: []const u16, echo_id: u64) ShellSendResult {
    if (shell_index >= shell_count) return .write_failed;
    if (chatOutboxIndexById(echo_id)) |ei| {
        const entry = &g_chat_outbox.items[ei];
        if (entry.write_started) return .write_failed;
        entry.state = .sending;
        entry.anchor = chatEchoAnchorNow(shell_index);
        entry.write_started = true;
        if (!saveChatOutbox()) {
            entry.write_started = false;
            entry.state = .queued;
            return .write_failed;
        }
    }
    const direct_input = chatShouldUseDirectInput(shell_index);
    const sent = if (direct_input)
        pasteTextToShellDirectEx(shell_index, send_text, chatSendForceBracketed(shell_index))
    else
        sendLocalChatPrompt(shell_index, send_text);
    if (!sent) return .write_failed;
    if (direct_input) {
        Sleep(chatSendEnterDelayMs(shells[shell_index].kind));
        if (!sendEnterToShell(shell_index)) return .enter_failed;
        chatArmSendVerify(shell_index, send_text, echo_id);
    }
    return .ok;
}

fn chatPromptStillInInputBox(shell_index: u32, prefix: []const u16) bool {
    const pid = shells[shell_index].pid;
    if (pid == 0) return false;
    _ = FreeConsole();
    if (AttachConsole(pid) == 0) return false;
    defer _ = FreeConsole();
    const handle = openAttachedConsoleOutput() orelse return false;
    defer _ = CloseHandle(handle);
    var info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (GetConsoleScreenBufferInfo(handle, &info) == 0 or info.dwSize.x <= 0) return false;
    const width: usize = @intCast(info.dwSize.x);
    const bottom: i32 = @max(@as(i32, info.dwCursorPosition.y), @as(i32, info.srWindow.bottom));
    if (bottom < 0) return false;
    const rows: usize = @intCast(@min(@as(i32, 40), bottom + 1));
    if (rows == 0 or rows * width > g_chat_raw.len) return false;
    const start_row: i16 = @intCast(bottom - @as(i32, @intCast(rows)) + 1);
    var chars_read: DWORD = 0;
    if (ReadConsoleOutputCharacterW(handle, &g_chat_raw, @intCast(rows * width), .{ .x = 0, .y = start_row }, &chars_read) == 0) return false;
    var row_slices: [40][]const u16 = undefined;
    for (0..rows) |r| row_slices[r] = chatTrimRawConsoleRow(width, chars_read, r);
    return chatInputBoxShowsUnsentPrompt(row_slices[0..rows], prefix);
}

fn chatEchoMatchActive() void {
    if (active_shell >= shell_count) return;
    const shell_id = shells[active_shell].shell_id;
    var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const key = chatOutboxKeyForShell(active_shell, &key_buf);
    if (key.len == 0) return;
    var expired = false;
    const loaded_ms = chatEchoLoadedMs();
    const now_ms = chat_echo.fileTimeToUnixMs(nowFileTime());
    for (g_chat_outbox.items) |e| {
        if (std.mem.eql(u8, e.key[0..e.key_len], key) and chat_echo.expiredSent(e.state, e.anchor.sent_ms, now_ms, loaded_ms)) {
            expired = true;
            break;
        }
    }
    if (!expired and g_chat_reconcile_shell == shell_id and g_chat_reconcile_hash == g_chat_last_hash and
        g_chat_reconcile_outbox == g_chat_outbox_revision and g_chat_reconcile_generation == g_chat_cache_generation) return;
    const reconcile_start = GetTickCount64();
    defer {
        g_chat_reconcile_shell = shell_id;
        g_chat_reconcile_hash = g_chat_last_hash;
        g_chat_reconcile_outbox = g_chat_outbox_revision;
        g_chat_reconcile_generation = g_chat_cache_generation;
        chatPerf("reconcile", reconcile_start, g_chat_block_count);
    }
    var changed = false;
    var i: usize = 0;
    var assignment: ChatEchoAssignment = .{};
    chatEchoAssignForKey(key, g_chat_blocks[0..g_chat_block_count], g_chat_capture[0..g_chat_last_len], chatEchoWindowFull(), &assignment);
    chatEchoStoreAnchors(&assignment);
    while (i < g_chat_outbox.items.len) {
        const e = g_chat_outbox.items[i];
        if (!std.mem.eql(u8, e.key[0..@as(usize, e.key_len)], key)) {
            i += 1;
            continue;
        }
        if (chatEchoAssignedBlock(&assignment, e.id)) |mi| {
            var prefix: [CHAT_ECHO_PREFIX_CAP]u16 = undefined;
            const p = chatEchoNormalizePrefix(e.text, &prefix);
            var key_copy: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
            @memcpy(key_copy[0..e.key_len], e.key[0..e.key_len]);
            chatConfirmedAdd(key_copy[0..e.key_len], p, g_chat_blocks[mi].start, g_chat_blocks[mi].len, g_chat_blocks[mi].stamp_ms);
            if (g_chat_verify_echo_id == e.id) chatVerifyClear();
            chatOutboxRemoveAtIn(&g_chat_outbox, std.heap.page_allocator, i);
            changed = true;
            continue;
        }
        if (chatEchoRepresentedBlock(e.text) != null or chat_echo.expiredSent(e.state, e.anchor.sent_ms, now_ms, loaded_ms)) {
            if (g_chat_verify_echo_id == e.id) chatVerifyClear();
            chatOutboxRemoveAtIn(&g_chat_outbox, std.heap.page_allocator, i);
            changed = true;
            continue;
        }
        i += 1;
    }
    if (changed) {
        _ = saveChatOutbox();
        chatOutboxChanged();
    }
}

fn chatEchoRepresentedBlock(text: []const u16) ?usize {
    for (g_chat_blocks[0..g_chat_block_count], 0..) |b, i| {
        if (b.role != .user) continue;
        const disp = chatBlockDisplayRange(g_chat_capture[0..g_chat_last_len], b);
        const user = [_]chat_echo.UserBlock{.{ .text = g_chat_capture[disp.start .. disp.start + disp.len] }};
        if (chat_echo.represented(text, &user) != null) return i;
    }
    return null;
}
