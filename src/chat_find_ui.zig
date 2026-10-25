const std = @import("std");
const app_state = @import("app_state.zig");
const win32 = @import("win32.zig");
const model = @import("chat_find.zig");
const session = @import("chat_session.zig");
const render = @import("chat_render.zig");
const history = @import("chat_history.zig");
const L = @import("startup.zig").L;
const RGB = @import("startup.zig").RGB;
const scaled = @import("drawing.zig").uiScaled;

fn invalidate() void {
    if (app_state.g_chat_transcript_hwnd == null) return;
    if (app_state.g_chat_find_layout_open != app_state.g_chat_find_open) {
        const delta = scaled(app_state.CHAT_FIND_TOP_H) * @as(i32, if (app_state.g_chat_find_open) 1 else -1);
        if (app_state.g_chat_layout_reuse < app_state.g_chat_block_count) app_state.g_chat_layout_dirty = true;
        for (app_state.g_chat_layout_rects[0..@min(app_state.g_chat_layout_reuse, app_state.g_chat_block_count)]) |*rect| {
            rect.top += delta;
            rect.bottom += delta;
        }
        for (app_state.g_chat_echo_layout[0..app_state.g_chat_echo_layout_count]) |*rect| {
            rect.top += delta;
            rect.bottom += delta;
        }
        app_state.g_chat_content_h = @max(0, app_state.g_chat_content_h + delta);
        app_state.g_chat_find_layout_open = app_state.g_chat_find_open;
        app_state.g_chat_scroll_y = std.math.clamp(app_state.g_chat_scroll_y, render.chatMinScroll(), render.chatMaxScroll());
    }
    _ = win32.InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
}

pub fn open() void {
    if (!model.ISSUE_268_CHAT_FIND or app_state.g_edit_hwnd != null or !@import("chat_composer.zig").chatViewOwnsInput() or !@import("focus.zig").foregroundIsOurs()) {
        close(false);
        return;
    }
    @import("chat_composer.zig").chatAcClose();
    close(false);
    app_state.g_chat_find_open = true;
    app_state.g_chat_find_key = session.chatFileIdentity();
    app_state.g_chat_find_len = 0;
    app_state.g_chat_find_query = @splat(0);
    app_state.g_chat_find_high_surrogate = 0;
    @import("focus.zig").cancelShellRefocus(app_state.g_main_hwnd);
    _ = @import("focus.zig").SetForegroundWindow(app_state.g_main_hwnd);
    _ = @import("focus.zig").SetFocus(app_state.g_chat_transcript_hwnd);
    _ = win32.SetTimer(app_state.g_main_hwnd, app_state.TIMER_CHAT_FIND, 50, null);
    invalidate();
}

pub fn close(focus: bool) void {
    app_state.g_chat_find_open = false;
    app_state.g_chat_file_request_id +%= 1;
    app_state.g_chat_find_id = app_state.g_chat_file_request_id;
    app_state.g_chat_find_due = 0;
    app_state.g_chat_find_jump = false;
    app_state.g_chat_find_ranges = @splat(null);
    app_state.g_chat_find_ranges_hash = 0;
    app_state.g_chat_find_error = false;
    if (app_state.g_chat_find_result) |*result| result.deinit();
    app_state.g_chat_find_result = null;
    if (app_state.g_chat_find_job == null) _ = win32.KillTimer(app_state.g_main_hwnd, app_state.TIMER_CHAT_FIND);
    if (focus and @import("focus.zig").foregroundIsOurs() and @import("chat_composer.zig").chatViewOwnsInput()) {
        _ = @import("focus.zig").SetForegroundWindow(app_state.g_main_hwnd);
        if (@import("chat_composer.zig").chatComposerFocusAllowed()) _ = @import("focus.zig").SetFocus(app_state.g_chat_composer_hwnd);
    }
    invalidate();
}

fn changed() void {
    app_state.g_chat_file_request_id +%= 1;
    app_state.g_chat_find_id = app_state.g_chat_file_request_id;
    app_state.g_chat_find_due = if (app_state.g_chat_find_len == 0) 0 else win32.GetTickCount64() + 250;
    app_state.g_chat_find_jump = false;
    app_state.g_chat_find_ranges = @splat(null);
    app_state.g_chat_find_ranges_hash = 0;
    app_state.g_chat_find_error = false;
    if (app_state.g_chat_find_result) |*result| result.deinit();
    app_state.g_chat_find_result = null;
    invalidate();
}

pub fn key(action: usize, char: u16) void {
    if (action == 0) {
        open();
        return;
    }
    if (!app_state.g_chat_find_open) return;
    switch (action) {
        1 => close(true),
        2 => {
            app_state.g_chat_find_high_surrogate = 0;
            if (app_state.g_chat_find_len > 0) {
                app_state.g_chat_find_len -= 1;
                if (app_state.g_chat_find_len > 0 and std.unicode.utf16IsHighSurrogate(app_state.g_chat_find_query[app_state.g_chat_find_len - 1])) app_state.g_chat_find_len -= 1;
                app_state.g_chat_find_query[app_state.g_chat_find_len] = 0;
                changed();
            }
        },
        3 => {
            if (std.unicode.utf16IsHighSurrogate(char)) {
                app_state.g_chat_find_high_surrogate = char;
                return;
            }
            const high = app_state.g_chat_find_high_surrogate;
            app_state.g_chat_find_high_surrogate = 0;
            const low = std.unicode.utf16IsLowSurrogate(char);
            if (low and high == 0) return;
            const count = std.unicode.utf16CountCodepoints(app_state.g_chat_find_query[0..app_state.g_chat_find_len]) catch return;
            if (char >= 0x20 and char != 0x7f and count < 200) {
                if (low) {
                    app_state.g_chat_find_query[app_state.g_chat_find_len] = high;
                    app_state.g_chat_find_len += 1;
                }
                app_state.g_chat_find_query[app_state.g_chat_find_len] = char;
                app_state.g_chat_find_len += 1;
                app_state.g_chat_find_query[app_state.g_chat_find_len] = 0;
                changed();
            }
        },
        4, 5 => {
            if (app_state.g_chat_find_result) |result| {
                app_state.g_chat_find_selected = model.step(app_state.g_chat_find_selected, result.hits.len, action == 5);
                app_state.g_chat_find_jump = result.hits.len > 0;
                jump();
                invalidate();
            }
        },
        else => {},
    }
}

pub fn routeKey(vk: u32, ctrl: bool, shift: bool, alt: bool) void {
    const action: usize = if (vk == 0x1b) 1 else if (vk == 0x08) 2 else if (vk == 0x0d or vk == 0x72) (if (shift) @as(usize, 5) else 4) else 0;
    if (action != 0) {
        _ = @import("focus.zig").PostMessageW(app_state.g_main_hwnd, app_state.WM_APP_CHAT_FIND, action, 0);
    } else if (ctrl and vk == 0x56 and !alt) {
        var text: [400]u16 = undefined;
        const n = @import("clipboard.zig").readClipboardTextWithRetry(&text);
        for (text[0..n]) |char| if (char >= 0x20 and char != 0x7f) {
            _ = @import("focus.zig").PostMessageW(app_state.g_main_hwnd, app_state.WM_APP_CHAT_FIND, 3, char);
        };
    }
}

pub fn windowKey(msg: u32, vk: usize) bool {
    const down = msg == win32.WM_KEYDOWN or msg == app_state.WM_SYSKEYDOWN;
    if (!down and msg != 0x0101 and msg != 0x0105 and msg != 0x0102 and msg != 0x0106 and msg != 0x0302) return false;
    const ctrl = @import("focus.zig").isCtrlDown();
    const shift = win32.GetAsyncKeyState(0x10) < 0;
    const alt = win32.GetAsyncKeyState(0x12) < 0;
    if (model.ISSUE_268_CHAT_FIND and !app_state.g_chat_find_open and down and vk == 0x46 and ctrl and !shift and !alt and @import("chat_composer.zig").chatViewOwnsInput()) {
        open();
        return true;
    }
    if (!app_state.g_chat_find_open) return false;
    if (@import("focus.zig").browserFocusChord(msg, vk, ctrl, alt)) return false;
    if (down) routeKey(@intCast(vk), ctrl, shift, alt);
    if (msg == 0x0102) {
        const char: u16 = @truncate(vk);
        if (char >= 0x20 and char != 0x7f) _ = @import("focus.zig").PostMessageW(app_state.g_main_hwnd, app_state.WM_APP_CHAT_FIND, 3, char);
    }
    return down or msg == 0x0101 or msg == 0x0105 or msg == 0x0102 or msg == 0x0106 or msg == 0x0302;
}

fn worker(job: *app_state.ChatFindJob) void {
    const a = std.heap.page_allocator;
    defer job.ready.store(true, .release);
    const key_id = job.key;
    const query = std.json.Stringify.valueAlloc(a, .{
        .id = job.id,
        .codex = key_id.codex,
        .sid = std.mem.sliceTo(&key_id.sid, 0),
        .tmux = std.mem.sliceTo(&key_id.tmux, 0),
        .cwd = std.mem.sliceTo(&key_id.cwd, 0),
        .search = std.mem.sliceTo(&job.query, 0),
    }, .{}) catch return;
    defer a.free(query);
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    var ok = if (session.chatBenchEnabled()) session.chatBenchFetch(key_id.shell_id, job.id, query, &wire) else session.chatHistoryPersistent(key_id.host, job.id, query, 1024 * 1024, &wire, null);
    if (!ok and !session.chatBenchEnabled() and !app_state.g_chat_history_channels_closing.load(.acquire)) {
        wire.clearRetainingCapacity();
        ok = session.chatHistoryFetchOnce(key_id.host, query, 1024 * 1024, &wire);
    }
    if (ok) job.result = model.parse(a, wire.items, job.id, key_id.codex, std.mem.sliceTo(&key_id.tmux, 0)) catch null;
}

pub fn tick() void {
    if (app_state.g_chat_find_job) |job| {
        if (job.ready.load(.acquire)) {
            session.chatFetchRelease();
            app_state.g_chat_find_job = null;
            if (app_state.g_chat_find_open and job.id == app_state.g_chat_find_id and history.sameSession(job.key, session.chatFileIdentity())) {
                app_state.g_chat_find_result = job.result;
                job.result = null;
                app_state.g_chat_find_error = app_state.g_chat_find_result == null;
                if (app_state.g_chat_find_result) |result| {
                    app_state.g_chat_find_selected = result.hits.len -| 1;
                    app_state.g_chat_find_jump = result.hits.len > 0;
                }
                invalidate();
            }
            if (job.result) |*result| result.deinit();
            std.heap.page_allocator.destroy(job);
        }
    }
    if (!app_state.g_chat_find_open) {
        if (app_state.g_chat_find_job == null) _ = win32.KillTimer(app_state.g_main_hwnd, app_state.TIMER_CHAT_FIND);
        return;
    }
    if (!app_state.g_chat_active or !history.sameSession(app_state.g_chat_find_key, session.chatFileIdentity())) {
        close(false);
        return;
    }
    if (app_state.g_chat_find_due > 0 and win32.GetTickCount64() >= app_state.g_chat_find_due and app_state.g_chat_find_job == null and session.chatFetchAcquire()) {
        const a = std.heap.page_allocator;
        const job = a.create(app_state.ChatFindJob) catch {
            session.chatFetchRelease();
            return;
        };
        job.* = .{ .key = session.chatFileIdentity(), .id = app_state.g_chat_find_id };
        const query = std.unicode.utf16LeToUtf8Alloc(a, app_state.g_chat_find_query[0..app_state.g_chat_find_len]) catch {
            a.destroy(job);
            session.chatFetchRelease();
            return;
        };
        defer a.free(query);
        @memcpy(job.query[0..query.len], query);
        const thread = std.Thread.spawn(.{}, worker, .{job}) catch {
            a.destroy(job);
            session.chatFetchRelease();
            return;
        };
        app_state.g_chat_find_job = job;
        app_state.g_chat_find_due = 0;
        thread.detach();
    }
    rebuildRanges();
    jump();
}

fn jump() void {
    if (!app_state.g_chat_find_jump) return;
    const result = app_state.g_chat_find_result orelse return;
    if (app_state.g_chat_find_selected >= result.hits.len) return;
    const hit = result.hits[app_state.g_chat_find_selected];
    const entry = session.chatHistoryEntry(session.chatFileIdentity()) orelse return;
    if (entry.pending) return;
    if (entry.failures > 0) {
        session.chatFileRequest(session.chatFileIdentity());
        return;
    }
    if (!std.mem.eql(u8, std.mem.sliceTo(&entry.history.sid, 0), result.sid) or entry.history.inode != result.inode) {
        app_state.g_chat_find_jump = false;
        changed();
        return;
    }
    if (model.needsOlder(hit.offset, entry.history.start) or hit.offset >= entry.history.offset) {
        entry.before = if (model.needsOlder(hit.offset, entry.history.start)) entry.history.start else 0;
        entry.show_older = entry.before > 0;
        if (entry.failures == 0) entry.next = 0;
        app_state.g_chat_scrolled_up = true;
        session.chatFileRequest(session.chatFileIdentity());
        return;
    }
    var text_start: usize = app_state.g_chat_last_len;
    var text_end: usize = 0;
    for (app_state.g_chat_blocks[0..app_state.g_chat_block_count]) |block| {
        if (!model.contains(block, hit)) continue;
        text_start = @min(text_start, block.start);
        text_end = @max(text_end, block.start + block.len);
        if (block.role == .tool and block.detail_len > 0) text_end = @max(text_end, block.detail_start + block.detail_len);
    }
    rebuildRanges();
    const position = if (app_state.g_chat_find_ranges[app_state.g_chat_find_selected]) |range| range.start else model.snippetPosition(hit, app_state.g_chat_capture[0..app_state.g_chat_last_len], text_start, text_end);
    for (app_state.g_chat_blocks[0..app_state.g_chat_block_count], 0..) |*block, i| {
        if (!model.contains(block.*, hit)) continue;
        if (position) |at| {
            if ((at < block.start or at >= block.start + block.len) and
                !(block.role == .tool and at >= block.detail_start and at < block.detail_start + block.detail_len)) continue;
        }
        if (block.role == .tool and !block.tool_open) {
            block.tool_open = true;
            app_state.g_chat_layout_reuse = 0;
            var client: win32.RECT = std.mem.zeroes(win32.RECT);
            _ = win32.GetClientRect(app_state.g_chat_transcript_hwnd, &client);
            render.chatRelayout(client.right);
        }
        app_state.g_chat_scroll_y = std.math.clamp(render.chatFindY(i, position) - scaled(60), render.chatMinScroll(), render.chatMaxScroll());
        app_state.g_chat_scrolled_up = true;
        app_state.g_chat_find_jump = false;
        invalidate();
        return;
    }
    for (app_state.g_chat_blocks[0..app_state.g_chat_block_count]) |block| {
        if (block.source_end == 0) {
            entry.history.restore_full = true;
            entry.next = 0;
            session.chatFileRequest(session.chatFileIdentity());
            return;
        }
    }
    if (hit.role == .tool and entry.history.start > 0) {
        entry.before = entry.history.start;
        entry.show_older = true;
        entry.next = 0;
        session.chatFileRequest(session.chatFileIdentity());
        return;
    }
    app_state.g_chat_find_jump = false;
    app_state.g_chat_find_error = true;
    invalidate();
}

extern "kernel32" fn FindNLSStringEx([*:0]const u16, u32, [*]const u16, i32, [*]const u16, i32, *i32, ?*anyopaque, ?*anyopaque, isize) callconv(win32.WINAPI) i32;

fn rebuildRanges() void {
    const result = app_state.g_chat_find_result orelse return;
    const hash = app_state.g_chat_last_hash ^ @as(u64, app_state.g_chat_find_id) << 32;
    if (app_state.g_chat_find_ranges_hash == hash) return;
    app_state.g_chat_find_ranges = @splat(null);
    app_state.g_chat_find_ranges_hash = hash;
    const text = app_state.g_chat_capture[0..app_state.g_chat_last_len];
    for (result.hits, 0..) |hit, i| {
        if (hit.role == .tool) {
            for (app_state.g_chat_blocks[0..app_state.g_chat_block_count]) |block| {
                if (!model.contains(block, hit) or !model.toolSnippetMatches(hit, text, block)) continue;
                const regions = [_]@import("chat_markdown.zig").Range{
                    .{ .start = block.start, .end = block.start + block.len },
                    .{ .start = block.detail_start, .end = block.detail_start + block.detail_len },
                };
                for (regions) |region| {
                    if (region.end <= region.start) continue;
                    var length: i32 = 0;
                    const at = FindNLSStringEx(L(""), 0x00400001, text[region.start..region.end].ptr, @intCast(region.end - region.start), &app_state.g_chat_find_query, @intCast(app_state.g_chat_find_len), &length, null, null, 0);
                    if (at >= 0 and length > 0) {
                        app_state.g_chat_find_ranges[i] = .{ .start = region.start + @as(usize, @intCast(at)), .end = region.start + @as(usize, @intCast(at + length)) };
                        break;
                    }
                }
                if (app_state.g_chat_find_ranges[i] == null) app_state.g_chat_find_ranges[i] = regions[0];
                break;
            }
            continue;
        }
        var start: usize = text.len;
        var end: usize = 0;
        for (app_state.g_chat_blocks[0..app_state.g_chat_block_count]) |block| {
            if (!model.contains(block, hit)) continue;
            start = @min(start, block.start);
            end = @max(end, block.start + block.len);
            if (block.role == .tool and block.detail_len > 0) end = @max(end, block.detail_start + block.detail_len);
        }
        if (end <= start) continue;
        if (model.snippetPosition(hit, text, start, end)) |position| start = position;
        var length: i32 = 0;
        const at = FindNLSStringEx(L(""), 0x00400001, text[start..end].ptr, @intCast(end - start), &app_state.g_chat_find_query, @intCast(app_state.g_chat_find_len), &length, null, null, 0);
        if (at >= 0 and length > 0) {
            app_state.g_chat_find_ranges[i] = .{ .start = start + @as(usize, @intCast(at)), .end = start + @as(usize, @intCast(at + length)) };
        } else if (model.snippetPosition(hit, text, start, end)) |position| {
            app_state.g_chat_find_ranges[i] = .{ .start = position, .end = @min(end, position + app_state.g_chat_find_len) };
        }
    }
}

pub fn paintRun(hdc: win32.HANDLE, text: []const u16, base: usize, x: i32, y: i32, height: i32) void {
    if (!app_state.g_chat_find_open) return;
    for (app_state.g_chat_find_ranges, 0..) |maybe, i| {
        const range = maybe orelse continue;
        if (range.start >= base + text.len or range.end <= base) continue;
        const lo = @max(base, range.start) - base;
        const hi = @min(base + text.len, range.end) - base;
        var before: win32.SIZE = std.mem.zeroes(win32.SIZE);
        var through: win32.SIZE = std.mem.zeroes(win32.SIZE);
        _ = win32.GetTextExtentPoint32W(hdc, text.ptr, @intCast(lo), &before);
        _ = win32.GetTextExtentPoint32W(hdc, text.ptr, @intCast(hi), &through);
        const brush = win32.CreateSolidBrush(if (i == app_state.g_chat_find_selected) (if (app_state.g_light_theme) RGB(255, 210, 110) else RGB(120, 82, 18)) else (if (app_state.g_light_theme) RGB(195, 222, 250) else RGB(40, 70, 100)));
        var rect = win32.RECT{ .left = x + before.cx, .top = y, .right = x + through.cx, .bottom = y + height };
        _ = win32.FillRect(hdc, &rect, brush);
        _ = win32.DeleteObject(brush);
    }
}

pub fn paint(hdc: win32.HANDLE, width: i32) void {
    if (!app_state.g_chat_find_open) return;
    var rc = win32.RECT{ .left = scaled(8), .top = scaled(4), .right = width - scaled(8), .bottom = scaled(44) };
    const brush = win32.CreateSolidBrush(if (app_state.g_light_theme) RGB(242, 246, 252) else RGB(28, 34, 44));
    _ = win32.FillRect(hdc, &rc, brush);
    _ = win32.DeleteObject(brush);
    const font = win32.SelectObject(hdc, render.chatMetadataFont());
    defer _ = win32.SelectObject(hdc, font);
    _ = win32.SetBkMode(hdc, win32.TRANSPARENT);
    _ = win32.SetTextColor(hdc, if (app_state.g_light_theme) RGB(30, 90, 170) else RGB(110, 175, 245));
    rc.left += scaled(10);
    rc.right = @min(width, scaled(110));
    _ = win32.DrawTextW(hdc, L("Find Chat"), -1, &rc, win32.DT_SINGLELINE | win32.DT_VCENTER | win32.DT_NOPREFIX);
    rc.left = rc.right;
    rc.right = @max(rc.left, width - scaled(190));
    _ = win32.SetTextColor(hdc, @import("themes.zig").themeConsoleFg());
    _ = win32.DrawTextW(hdc, if (app_state.g_chat_find_len > 0) @ptrCast(&app_state.g_chat_find_query) else L("Type to search..."), -1, &rc, win32.DT_SINGLELINE | win32.DT_VCENTER | win32.DT_NOPREFIX | win32.DT_END_ELLIPSIS);
    rc.left = rc.right;
    rc.right = width - scaled(18);
    var buf: [64]u8 = undefined;
    const label = if (app_state.g_chat_find_error) "Search unavailable" else if (app_state.g_chat_find_result) |result| model.counter(&buf, app_state.g_chat_find_selected, result.hits.len, result.truncated) catch "" else if (app_state.g_chat_find_len > 0) "Searching..." else "Enter / F3 / Esc";
    var wide: [64]u16 = undefined;
    const n = std.unicode.utf8ToUtf16Le(&wide, label) catch 0;
    _ = win32.DrawTextW(hdc, &wide, @intCast(n), &rc, win32.DT_SINGLELINE | win32.DT_VCENTER | win32.DT_NOPREFIX | win32.DT_RIGHT);
}

pub fn paintMatch(hdc: win32.HANDLE, block: app_state.ChatBlock, rect: win32.RECT) void {
    if (!app_state.g_chat_find_open) return;
    const result = app_state.g_chat_find_result orelse return;
    var selected = false;
    var matched = false;
    for (result.hits, 0..) |hit, i| {
        if (model.contains(block, hit)) {
            if (app_state.g_chat_find_ranges[i]) |range| {
                const body = range.start < block.start + block.len and range.end > block.start;
                const detail = block.role == .tool and range.start < block.detail_start + block.detail_len and range.end > block.detail_start;
                if (!body and !detail) continue;
            }
            matched = true;
            selected = selected or i == app_state.g_chat_find_selected;
        }
    }
    if (!matched) return;
    const brush = win32.CreateSolidBrush(if (selected) RGB(235, 163, 38) else RGB(110, 175, 245));
    var mark = rect;
    mark.left -= scaled(5);
    mark.right = mark.left + scaled(if (selected) 4 else 2);
    _ = win32.FillRect(hdc, &mark, brush);
    _ = win32.DeleteObject(brush);
}

test "ISSUE-268 open find bar consumes native key and character messages before composer editing" {
    const old_open = app_state.g_chat_find_open;
    const old_hwnd = app_state.g_chat_transcript_hwnd;
    const old_query = app_state.g_chat_find_query;
    const old_len = app_state.g_chat_find_len;
    const old_id = app_state.g_chat_find_id;
    const old_due = app_state.g_chat_find_due;
    defer {
        app_state.g_chat_find_open = old_open;
        app_state.g_chat_transcript_hwnd = old_hwnd;
        app_state.g_chat_find_query = old_query;
        app_state.g_chat_find_len = old_len;
        app_state.g_chat_find_id = old_id;
        app_state.g_chat_find_due = old_due;
    }
    app_state.g_chat_transcript_hwnd = null;
    app_state.g_chat_find_open = true;
    app_state.g_chat_find_len = 0;
    for (0..256) |vk| {
        try std.testing.expect(windowKey(0x0102, vk));
        try std.testing.expect(windowKey(0x0106, vk));
        try std.testing.expect(windowKey(0x0101, vk));
    }
    key(3, 'x');
    try std.testing.expectEqual(@as(usize, 1), app_state.g_chat_find_len);
    try std.testing.expectEqual(@as(u16, 'x'), app_state.g_chat_find_query[0]);
    try std.testing.expect(app_state.g_chat_find_due > win32.GetTickCount64());
    key(2, 0);
    try std.testing.expectEqual(@as(usize, 0), app_state.g_chat_find_len);
    for (0..200) |_| {
        key(3, 0xd83d);
        key(3, 0xde00);
    }
    try std.testing.expectEqual(@as(usize, 400), app_state.g_chat_find_len);
    try std.testing.expectEqual(@as(usize, 200), try std.unicode.utf16CountCodepoints(app_state.g_chat_find_query[0..app_state.g_chat_find_len]));
    key(3, 'x');
    try std.testing.expectEqual(@as(usize, 400), app_state.g_chat_find_len);
    key(2, 0);
    try std.testing.expectEqual(@as(usize, 398), app_state.g_chat_find_len);
    app_state.g_chat_find_open = false;
    try std.testing.expect(!windowKey(0x0102, 'x'));
}
