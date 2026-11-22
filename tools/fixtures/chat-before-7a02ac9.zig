fn chatFileRequest(key: chat_transcript.Identity) void {
    if (!g_chat_active or key.shell_id == 0) return;
    if (g_main_hwnd == null or IsIconic(g_main_hwnd) != 0 or IsWindowVisible(g_main_hwnd) == 0) return;
    const entry = chatHistoryEntry(key) orelse return;
    const now = GetTickCount64();
    if (!chat_history.retryDue(entry.pending, now, entry.next)) return;
    if (!foregroundIsOurs()) {
        var input: LASTINPUTINFO = .{ .cbSize = @sizeOf(LASTINPUTINFO), .dwTime = 0 };
        if (GetLastInputInfo(&input) == 0 or @as(u32, @truncate(now)) -% input.dwTime < 5000) return;
    }
    if (!chatFetchAcquire()) return;
    entry.pending = true;
    entry.loading_disk = !entry.disk_loaded;
    entry.key = key;
    if (key.sid[0] == 0) entry.key.sid = entry.history.sid;
    g_chat_file_request_id +%= 1;
    var log_buf: [96]u8 = undefined;
    debugLog(std.fmt.bufPrint(&log_buf, "[chat] transcript request shell={d} offset={d}", .{ key.shell_id, entry.history.offset }) catch "[chat] transcript request");
    const thread = std.Thread.spawn(.{}, chatFileFetchThread, .{ entry, key, g_chat_file_request_id, entry.loading_disk }) catch {
        entry.pending = false;
        chatFetchRelease();
        chatFileFailed(entry);
        debugLog(std.fmt.bufPrint(&log_buf, "[chat] transcript load shell={d} fail bytes=0 ms=0", .{key.shell_id}) catch "[chat] transcript load fail");
        return;
    };
    thread.detach();
}

fn chatFileIdentityForShell(idx: u32) chat_transcript.Identity {
    if (idx >= shell_count) return .{};
    const s = &shells[idx];
    if (s.kind != .tmux and !chatBenchEnabled()) return .{};
    var key = chat_transcript.Identity.init(s.shell_id, s.tmux_host, s.ai_agent == 2 or (chatBenchEnabled() and std.mem.startsWith(u8, s.claude_sid[0..s.claude_sid_len], "codex-")), s.claude_sid[0..s.claude_sid_len], s.claude_cwd[0..s.claude_cwd_len]);
    if (s.tmux_session_len < key.tmux.len) @memcpy(key.tmux[0..s.tmux_session_len], s.tmux_session[0..s.tmux_session_len]);
    if (key.sid[0] == 0 and key.tmux[0] == 0) return .{};
    return key;
}

fn chatFileFailed(entry: *ChatHistoryEntry) void {
    entry.failures +|= 1;
    entry.next = GetTickCount64() + (if (entry.missing_message[0] != 0) chat_history.MISSING_RETRY_MS else chat_history.retryDelay(entry.failures));
}

fn chatFileFetchThread(entry: *ChatHistoryEntry, key: chat_transcript.Identity, id: u32, load_disk: bool) void {
    const a = std.heap.page_allocator;
    const start = GetTickCount64();
    if (load_disk) {
        var path_buf: [560]u8 = undefined;
        entry.result = null;
        if (chatHistoryPath(key, &path_buf)) |path| {
            if (chatHistoryRead(path)) |bytes| {
                defer a.free(bytes);
                const cache_parse_start = GetTickCount64();
                entry.result = chat_history.History.decode(a, bytes, key) catch null;
                chatPerf("cache parse", cache_parse_start, bytes.len);
            }
        }
        entry.ready.store(true, .release);
        if (g_main_hwnd != null) _ = PostMessageW(g_main_hwnd, WM_APP_CHAT_FILE_READY, 0, 0);
        return;
    }
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    const input = if (entry.history.restore_full) chat_history.History{} else entry.history.cursor();
    var ok = chatHistoryFetch(key, id, input, entry.before, &wire);
    var history: chat_history.History = .{};
    const parse_start = GetTickCount64();
    entry.unchanged = false;
    entry.incremental = false;
    entry.prepended = false;
    entry.result_missing = @splat(0);
    if (ok) {
        if (chat_history.missingReason(wire.items, id)) |reason| {
            var message: [256]u8 = undefined;
            const text = std.fmt.bufPrint(&message, "Transcript not reachable: {s}", .{reason}) catch "Transcript not reachable: session transcript not found";
            const len = std.unicode.utf8ToUtf16Le(entry.result_missing[0..255], text) catch 0;
            entry.result_missing[len] = 0;
            ok = false;
        }
    }
    if (ok) {
        const header_end = std.mem.indexOfScalar(u8, wire.items, '\n');
        const no_rows = if (header_end) |n| std.mem.eql(u8, wire.items[n + 1 ..], "@@MP_END@@\n") else false;
        const delta = if (header_end) |n| std.mem.indexOf(u8, wire.items[0..n], "\tdelta\t") != null else false;
        entry.incremental = delta and !no_rows and !entry.history.restore_full and entry.history.rows.items.len > 0;
        history = (if (delta and no_rows and !entry.history.restore_full) entry.history.cursor() else if (entry.incremental) entry.history.suffix(a) else entry.history.clone(a)) catch blk: {
            ok = false;
            break :blk chat_history.History{};
        };
        const revision = history.revision;
        if (ok) history.apply(a, wire.items, id, key) catch {
            ok = false;
        };
        if (ok) {
            entry.unchanged = no_rows and history.revision == revision;
            const older = if (header_end) |n| std.mem.indexOf(u8, wire.items[0..n], "\tolder\t") != null else false;
            if (older and history.start < entry.history.start) entry.prepended = true;
        }
    }
    chatPerf("parse", parse_start, wire.items.len);
    if (ok) {
        const changed = history.revision != entry.history.revision;
        entry.cache_dirty = entry.cache_dirty or changed;
        var path_buf: [560]u8 = undefined;
        if (if (entry.cache_dirty and (entry.cache_written == 0 or GetTickCount64() -| entry.cache_written >= chat_history.CACHE_WRITE_MS)) chatHistoryPath(key, &path_buf) else null) |path| {
            const write_start = GetTickCount64();
            var snapshot = history.cursor();
            defer snapshot.deinit(a);
            var snapshot_ok = true;
            if (entry.incremental or entry.unchanged) {
                const old = entry.history.rows.items;
                const from = old.len -| chat_history.TAIL_BYTES;
                snapshot.rows.appendSlice(a, old[from..]) catch {
                    snapshot_ok = false;
                };
                if (entry.incremental) {
                    const old_suffix = old.len - entry.history.last_row;
                    snapshot.rows.appendSlice(a, history.rows.items[old_suffix..]) catch {
                        snapshot_ok = false;
                    };
                }
                snapshot.restore_full = from > 0 or entry.history.restore_full;
            }
            const encoded = if (snapshot_ok) (if (entry.incremental or entry.unchanged) snapshot else history).encode(a, key) else error.OutOfMemory;
            if (encoded) |bytes| {
                defer a.free(bytes);
                if (std.mem.lastIndexOfScalar(u8, path, '\\')) |end| win32MakePath(path[0..end]);
                while (!g_chat_cache_write_mutex.tryLock()) Sleep(1);
                defer g_chat_cache_write_mutex.unlock();
                if (!entry.cache_cancelled.load(.acquire)) {
                    if (writeFileAtomicW(path, bytes)) {
                        entry.cache_written = GetTickCount64();
                        entry.cache_dirty = false;
                        if (GetTickCount64() -| g_chat_cache_pruned >= 60_000) {
                            chatHistoryPrune(path);
                            g_chat_cache_pruned = GetTickCount64();
                        }
                    } else debugLog("[chat] transcript cache write failed");
                }
                chatPerf("cache write", write_start, bytes.len);
            } else |_| debugLog("[chat] transcript cache encode failed");
        }
        entry.result = history;
    } else {
        history.deinit(a);
        entry.result = null;
    }
    var log_buf: [128]u8 = undefined;
    debugLog(std.fmt.bufPrint(&log_buf, "[chat] transcript load shell={d} {s} bytes={d} ms={d}", .{ key.shell_id, if (ok) "ok" else "fail", wire.items.len, GetTickCount64() - start }) catch "[chat] transcript load fail");
    entry.ready.store(true, .release);
    if (g_main_hwnd != null) _ = PostMessageW(g_main_hwnd, WM_APP_CHAT_FILE_READY, 0, 0);
}
