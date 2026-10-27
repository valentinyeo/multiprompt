const { copyZig } = require('./zig-copy');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const src = require('./app-source').readAppSource();
function fn(name, text = src) {
  const start = text.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return text.slice(start, text.indexOf('\n}', start) + 2);
}
const prelude = `
const std = @import("std");
const chat_history = @import("chat_history.zig");
const chat_echo = @import("chat_echo.zig");
const chat_switch = @import("chat_switch.zig");
const chat_transcript = @import("chat_transcript.zig");
const chat_markdown = @import("chat_markdown.zig");
const chat_style = @import("chat_style.zig");
const chat_image = @import("chat_image.zig");
const ChatBlock = chat_markdown.Block;
const HANDLE = ?*anyopaque;
const RECT = chat_history.Rect;
const ChatImgItem = struct { dummy: u8 = 0 };
const ChatLayoutSnapshot = struct { rects: []RECT };
const chat_layout_snapshot = struct { fn save() void {} fn restore(_: anytype) usize { return 0; } };
const CHAT_MAX_BLOCKS = 256;
const TIMER_CHAT_REFRESH = 27;
const Shell = struct {
  last_read_message_id: u64 = 0, shell_id: u32 = 0, kind: enum { tmux, cmd } = .tmux, tmux_host: u8 = 0, ai_agent: u8 = 1,
  claude_sid: [40]u8 = @splat(0), claude_sid_len: u32 = 0,
  claude_cwd: [192]u8 = @splat(0), claude_cwd_len: u32 = 0,
  tmux_session: [64]u8 = @splat(0), tmux_session_len: u32 = 0,
};
var shells: [2]Shell = @splat(.{});
var shell_count: usize = 2;
var active_shell: u32 = 0;
var g_chat_active = true;
var g_voice_mode_active = false;
var g_main_hwnd: HANDLE = @ptrFromInt(1);
var g_chat_transcript_hwnd: HANDLE = @ptrFromInt(1);
var g_chat_file_valid = false;
var g_chat_browser_swap: chat_switch.Pending = .{};
var g_chat_working_applied_len: usize = 0;
var g_chat_layout_dirty = false;
var g_chat_layout_reuse: usize = 0;
var g_chat_cache_generation: u64 = 0;
var g_chat_prepend_pending = false;
var g_chat_tables: chat_markdown.TableCache = .{};
var g_chat_tables_shell_id: u32 = 0;
var g_chat_received: chat_markdown.BlockCache = .{};
var chat_received_parses: usize = 0;
var chat_table_drag: ?struct { offset: usize } = null;
var g_chat_cache_pruned: u64 = 0;
fn chatPerf(_: []const u8, _: u64, _: usize) void {}
fn chatFetchRelease() void {}
const ChatHistoryPush = struct { wire: std.ArrayList(u8), id: u32, read_us: u64 };
const ChatHistoryStream = struct {
    ready: std.atomic.Value(bool) = .init(true), ended: std.atomic.Value(bool) = .init(false),
    id: u32 = 0, wire: std.ArrayList(u8) = .empty, read_us: u64 = 0, ack: HANDLE = null,
};
var test_stream: ChatHistoryStream = .{};
var captured_key: chat_transcript.Identity = .{};
fn chatHistoryStreamsKeep(_: u32) void {}
fn chatHistoryStreamStop(entry: *ChatHistoryEntry) void { entry.stream = null; }
fn chatHistoryStreamStart(key: chat_transcript.Identity, _: u32, _: chat_history.History) ?*ChatHistoryStream {
    captured_key = key;
    test_stream.ready.store(true, .release);
    return &test_stream;
}
fn SetEvent(_: HANDLE) i32 { return 1; }
fn UpdateWindow(_: HANDLE) i32 { return 1; }
var g_chat_file_key: chat_transcript.Identity = .{};
var g_chat_histories: std.ArrayList(*ChatHistoryEntry) = .empty;
var g_chat_cache_shell_id: u32 = 0;
var g_chat_last_len: usize = 0;
var g_chat_last_hash: u64 = 0;
var g_chat_capture_storage: [4]u16 = @splat(0);
var g_chat_capture: []u16 = &g_chat_capture_storage;
var g_chat_screen: [262144]u16 = undefined;
var g_chat_blocks_storage: [CHAT_MAX_BLOCKS]ChatBlock = undefined;
var g_chat_blocks: []ChatBlock = &g_chat_blocks_storage;
var g_chat_layout_storage: [CHAT_MAX_BLOCKS]RECT = undefined;
var g_chat_layout_rects: []RECT = &g_chat_layout_storage;
var g_chat_bubble_storage: [CHAT_MAX_BLOCKS]chat_style.BubblePos = @splat(.single);
var g_chat_bubble_pos: []chat_style.BubblePos = &g_chat_bubble_storage;
var g_chat_img_count_storage: [CHAT_MAX_BLOCKS]u8 = @splat(0);
var g_chat_img_count: []u8 = &g_chat_img_count_storage;
var g_chat_img_items_storage: [CHAT_MAX_BLOCKS][chat_image.MAX_PER_BLOCK]ChatImgItem = undefined;
var g_chat_img_items: [][chat_image.MAX_PER_BLOCK]ChatImgItem = &g_chat_img_items_storage;
var g_chat_block_count: usize = 0;
var g_chat_hover_copy: ?usize = null;
var g_chat_hover_link: ?usize = null;
var g_chat_sel_transcript_focus = false;
var g_chat_sel_anchor: usize = 0;
var g_chat_sel_caret: usize = 0;
var g_chat_window_full = false;
var g_chat_blocks_from_file = false;
var g_voice_cursor_shell_id: u32 = 0;
var g_voice_cursor_latest_hash: u64 = 0;
var g_voice_cursor_start: ?usize = null;
var g_voice_highlight: ?usize = null;
var g_chat_switch_loading = false;
var g_chat_screen_working = false;
var g_chat_screen_status_len: usize = 0;
var g_chat_load_tries: u8 = 0; // old-defer positive control only
var g_chat_content_h: i32 = 0;
var g_chat_scroll_y: i32 = 0;
var g_chat_top_pad: i32 = 0;
var g_chat_scrolled_up = false;
var g_chat_new_messages: chat_history.NewMessages = .{};
var g_chat_scroll_bottom_pending = false;
var g_chat_read_visit_shell_id: u32 = 0;
var g_chat_read_visit_marker: u64 = 0;
var g_chat_read_visit_state: enum { pending, all_read, unread } = .pending;
var g_chat_read_open_pending = false;
var g_chat_read_hold = false;
var g_chat_read_open_ready = false;
var g_chat_read_boundary: chat_history.ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
fn chatReadMark(_: bool) bool { return false; }
fn chatReadBoundary() chat_history.ReadBoundary { return .{}; }
fn foregroundIsOurs() bool { return true; }
var g_chat_echo_layout_count: usize = 0;
var request_count: usize = 0;
var capture_count: usize = 0;
var capture_result: ?usize = null;
var first_image_extra: i32 = 0;
var disk_bytes: ?[]const u8 = null;
var remote_pages: []const []const u8 = &.{};
var remote_calls: usize = 0;
var cache_writes: usize = 0;
var capture_cache = false;
var captured_cache: std.ArrayList(u8) = .empty;
var status_layout_calls: usize = 0;
fn layoutChatControls() void { status_layout_calls += 1; _ = chatReadBoundary(); }
fn chatNewMessagesChanged(_: bool) void {}
const WM_APP_CHAT_FILE_READY = 1;
var g_chat_cache_write_mutex: struct {
    fn tryLock(_: *@This()) bool { return true; }
    fn unlock(_: *@This()) void {}
} = .{};
fn chatHistoryPath(_: chat_transcript.Identity, _: *[560]u8) ?[]const u8 { return "C:\\\\cache\\\\history.jsonl"; }
fn chatHistoryRead(_: []const u8) ?[]u8 { return if (disk_bytes) |b| std.heap.page_allocator.dupe(u8, b) catch null else null; }
fn chatHistoryFetch(_: chat_transcript.Identity, _: u32, _: chat_history.History, _: u64, out: *std.ArrayList(u8)) bool {
    if (remote_calls >= remote_pages.len) return false;
    const page = remote_pages[remote_calls];
    remote_calls += 1;
    out.appendSlice(std.heap.page_allocator, page) catch return false;
    return true;
}
fn win32MakePath(_: []const u8) void {}
fn writeFileAtomicW(_: []const u8, bytes: []const u8) bool {
    cache_writes += 1;
    if (capture_cache) {
        captured_cache.clearRetainingCapacity();
        captured_cache.appendSlice(std.heap.page_allocator, bytes) catch return false;
    }
    return true;
}
fn chatHistoryPrune(_: []const u8) void {}
fn debugLog(_: []const u8) void {}
fn chatBenchEnabled() bool { return false; }
fn PostMessageW(_: HANDLE, _: u32, _: usize, _: isize) i32 { return 1; }
fn Sleep(_: u32) void {}
fn uiScaled(n: i32) i32 { return n; }
var ticks: u64 = 500;
var fake_viewport_h: i32 = 800;
fn GetTickCount64() u64 { return ticks; }
fn nowFileTime() u64 { return 116444736000000000 + 500 * 10000; }
fn GetClientRect(_: HANDLE, out: *RECT) i32 { out.* = .{ .left = 0, .top = 0, .right = 900, .bottom = fake_viewport_h }; return 1; }
fn InvalidateRect(_: HANDLE, _: ?*const RECT, _: i32) i32 { return 1; }
fn chatViewClientRect(rc: *RECT) void { _ = GetClientRect(null, rc); }
fn chatScrollActivity() void {}
var timer_calls: usize = 0;
fn SetTimer(_: HANDLE, _: usize, _: u32, _: ?*anyopaque) usize { timer_calls += 1; return 1; }
fn chatSelectionClear() void {}
fn chatEchoMatchActive() void {}
fn chatFilePollInterval() u64 { return 2000; }
fn chatDeliveryPending(_: u32, _: bool) bool { return false; }
fn chatFileRequest(key: chat_transcript.Identity) void {
    if (chatHistoryEntry(key)) |e| if (chat_history.retryDue(e.pending, GetTickCount64(), e.next)) { e.pending = true; request_count += 1; };
}
fn chatHistoryEntry(key: chat_transcript.Identity) ?*ChatHistoryEntry {
    for (g_chat_histories.items) |e| if (chat_history.sameSession(key, e.key)) return e;
    return null;
}
fn captureChatTranscript(_: usize, _: []u16, _: bool) ?usize { capture_count += 1; return capture_result; }
fn chatClassifyBlocks(_: []const u16, _: []ChatBlock) usize { return 0; }
fn chatApplyDisplayGlyphs(_: []u16, _: []const ChatBlock) void {}
fn chatLatestAgentReply(_: []u16) usize { return 0; }
fn findShellById(id: u32) ?usize { for (shells, 0..) |s, i| if (s.shell_id == id) return i; return null; }
fn saveSession() void {}
fn chatRelayout(_: i32) void {
    var y: i32 = 0;
    for (g_chat_blocks[0..g_chat_block_count], 0..) |_, i| {
        const h: i32 = 40 + (if (i == 0) first_image_extra else 0);
        g_chat_layout_rects[i] = .{ .left = 0, .top = y, .right = 800, .bottom = y + h };
        y += h;
    }
    g_chat_content_h = y;
}
`;
const entry = src.slice(src.indexOf('const ChatHistoryEntry = struct {'), src.indexOf('\n};', src.indexOf('const ChatHistoryEntry = struct {')) + 3);
const functions = ['chatTableRefresh', 'chatReceivedBlocks', 'chatFileFetchThread', 'chatFileIdentity', 'chatFileIdentityForShell', 'chatCacheIdentity', 'chatStoreTabCache', 'chatActivateTables', 'chatHistoryForget', 'chatGrowSlice', 'chatEnsureTranscriptCapacity', 'refreshChatBlockCache', 'chatFileFailed', 'chatFileOnReady', 'refreshChatTranscript', 'chatRelayoutPreservingScroll', 'chatMinScroll', 'chatMaxScroll', 'chatScrollBy', 'chatScrollStateChanged'];
const acceptance = `
test "cache-first switch-back, stale completion and failure preserve complete messages" {
    const a = std.heap.page_allocator;
    var one: ChatHistoryEntry = .{ .key = chat_transcript.Identity.initTmux(1, 0, false, "term-1", "") };
    var two: ChatHistoryEntry = .{ .key = chat_transcript.Identity.initTmux(2, 0, false, "term-2", "") };
    defer one.history.deinit(a);
    defer two.history.deinit(a);
    try g_chat_histories.append(a, &one);
    try g_chat_histories.append(a, &two);
    for (&shells, 0..) |*s, i| {
        s.shell_id = @intCast(i + 1);
        @memcpy(s.tmux_session[0..6], if (i == 0) "term-1" else "term-2");
        s.tmux_session_len = 6;
    }
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    try wire.appendSlice(a, "@mp\\t1\\thistory\\tok\\tsid\\t0\\t1000\\t9\\t0\\tclaude\\tterm-1\\n");
    for (0..500) |_| try wire.appendSlice(a, "{\\"role\\":\\"assistant\\",\\"text\\":\\"first paragraph\\\\n\\\\nsecond paragraph\\"}\\n");
    try wire.appendSlice(a, "@@MP_END@@\\n");
    try one.history.apply(a, wire.items, 1, one.key);
    // Simulated app restart: use only the production disk codec, not its prior RAM.
    const disk = try one.history.encode(a, one.key);
    defer a.free(disk);
    one.history.deinit(a);
    one.history = try chat_history.History.decode(a, disk, one.key);
    active_shell = 0;
    chatDeferTranscriptLoad();
    try std.testing.expectEqual(@as(usize, 1000), g_chat_block_count);
    try std.testing.expectEqual(@as(usize, 0), request_count);
    try std.testing.expectEqual(@as(usize, 0), capture_count);
    // Layout and deferred refresh happen only after the cache has been bound.
    chatRelayout(900);
    refreshChatTranscript(true);
    try std.testing.expectEqual(@as(usize, 1), request_count);
    try std.testing.expectEqual(@as(usize, 0), capture_count);
    try std.testing.expect(one.pending); // display did not wait for the remote read
    try std.testing.expect(g_chat_content_h > 800);
    chatScrollBy(100000);
    try std.testing.expectEqual(@as(i32, 0), g_chat_scroll_y);
    try std.testing.expect(g_chat_scrolled_up);
    g_chat_scrolled_up = true;
    g_chat_scroll_y = 0;
    refreshChatTranscript(false);
    try std.testing.expectEqual(@as(i32, 0), g_chat_scroll_y);
    active_shell = 1;
    chatDeferTranscriptLoad();
    try std.testing.expectEqual(@as(usize, 0), g_chat_block_count);
    // A completes while B is active: cache A, never paint it under B.
    one.result = try one.history.clone(a);
    one.ready.store(true, .release);
    chatFileOnReady();
    try std.testing.expectEqual(@as(usize, 0), g_chat_block_count);
    try std.testing.expectEqual(@as(usize, 1000), one.history.blocks.items.len);
    active_shell = 0;
    chatDeferTranscriptLoad();
    try std.testing.expectEqual(@as(usize, 1000), g_chat_block_count);
    // Failure after switch-back preserves every row and schedules per-session retry.
    one.pending = true;
    one.result = null;
    one.ready.store(true, .release);
    chatFileOnReady();
    try std.testing.expectEqual(@as(usize, 1000), g_chat_block_count);
    try std.testing.expectEqual(@as(u8, 1), one.failures);
    try std.testing.expectEqual(@as(u64, 1500), one.next);
    // Appending changes the transcript but not the reader's current message.
    var appended = try one.history.clone(a);
    try appended.apply(a, "@mp\\t2\\thistory\\tok\\tsid\\t1000\\t1200\\t9\\t0\\tclaude\\tterm-1\\n{\\"role\\":\\"assistant\\",\\"text\\":\\"appended reply\\"}\\n@@MP_END@@\\n", 2, one.key);
    g_chat_scrolled_up = true;
    g_chat_scroll_y = 45;
    one.result = appended;
    one.ready.store(true, .release);
    chatFileOnReady();
    try std.testing.expectEqual(@as(i32, 45), g_chat_scroll_y);
    try std.testing.expectEqual(@as(usize, 1001), g_chat_block_count);
    g_chat_scrolled_up = true;
    g_chat_scroll_y = 45;
    first_image_extra = 300;
    chatRelayoutPreservingScroll(900, 800);
    try std.testing.expectEqual(@as(i32, 345), g_chat_scroll_y);
    g_chat_scroll_y = 0;
    refreshChatTranscript(false);
    try std.testing.expectEqual(@as(i32, 0), g_chat_scroll_y);
    // A pending worker pins its input even when a tab closes. Completion can
    // then retire the entry without painting the late result under another tab.
    const closed = try a.create(ChatHistoryEntry);
    closed.* = .{ .key = chat_transcript.Identity.initTmux(3, 0, false, "term-closed", ""), .pending = true };
    try g_chat_histories.append(a, closed);
    const worker = try std.Thread.spawn(.{}, chatFileFetchThread, .{ closed, closed.key, @as(u32, 1), true, null });
    chatHistoryForget(3);
    try std.testing.expect(closed.retired);
    worker.join();
    chatFileOnReady();
    try std.testing.expectEqual(@as(usize, 2), g_chat_histories.items.len);
    // Cold disk publishes independently of remote success, but never on defer.
    disk_bytes = disk;
    one.key.sid = @splat(0);
    one.loading_disk = true;
    one.pending = true;
    chatFileFetchThread(&one, one.key, 1, true, null);
    chatFileOnReady();
    try std.testing.expect(g_chat_block_count > 0);
    try std.testing.expectEqualStrings("sid", std.mem.sliceTo(&one.key.sid, 0));
    var reused = one.key;
    reused.sid = @splat(0);
    @memcpy(reused.sid[0..3], "new");
    try std.testing.expect(chatHistoryEntry(reused) == null);
    disk_bytes = null;
    // A reset whose first page has only tool records must not fail forever.
    remote_pages = &.{
        "@mp\\t2\\thistory\\tok\\tsid\\t0\\t50\\t10\\t1\\tclaude\\tterm-1\\n@@MP_END@@\\n",
        "@mp\\t2\\thistory\\tok\\tsid\\t50\\t100\\t10\\t0\\tclaude\\tterm-1\\n{\\"role\\":\\"assistant\\",\\"text\\":\\"rebuilt full reply\\"}\\n@@MP_END@@\\n",
    };
    one.pending = true;
    chatFileFetchThread(&one, one.key, 2, false, null);
    try std.testing.expectEqual(@as(usize, 1), remote_calls);
    // Bounded requests never run a rehydration loop inside one worker.
    try std.testing.expect(one.result == null);
    chatFileOnReady();
    remote_pages = &.{ remote_pages[1] };
    remote_calls = 0;
    // Reset to the latest bounded window on the next backed-off request.
    remote_pages = &.{ "@mp\\t2\\thistory\\tok\\tsid\\t0\\t100\\t10\\t0\\tclaude\\tterm-1\\n{\\\"role\\\":\\\"assistant\\\",\\\"text\\\":\\\"rebuilt full reply\\\"}\\n@@MP_END@@\\n" };
    one.pending = true;
    chatFileFetchThread(&one, one.key, 2, false, null);
    try std.testing.expect(one.result != null);
    try std.testing.expectEqual(@as(usize, 500), one.history.blocks.items.len / 2);
    chatFileOnReady();
    try std.testing.expectEqual(@as(usize, 1), g_chat_block_count);
    try std.testing.expect(cache_writes > 0);
    // An unchanged successful delta does not rewrite the whole disk snapshot.
    remote_pages = &.{ "@mp\\t4\\thistory\\tok\\tsid\\t100\\t100\\t10\\t0\\tclaude\\tterm-1\\n@@MP_END@@\\n" };
    remote_calls = 0;
    const writes_before = cache_writes;
    one.pending = true;
    chatFileFetchThread(&one, one.key, 4, false, null);
    chatFileOnReady();
    try std.testing.expectEqual(writes_before, cache_writes);
    // A reset cancels an old worker's cache write even if its fetch succeeds.
    remote_pages = &.{ "@mp\\t5\\thistory\\tok\\tsid\\t100\\t150\\t10\\t0\\tclaude\\tterm-1\\n{\\"role\\":\\"assistant\\",\\"text\\":\\"cancelled reply\\"}\\n@@MP_END@@\\n" };
    remote_calls = 0;
    one.cache_cancelled.store(true, .release);
    one.pending = true;
    chatFileFetchThread(&one, one.key, 5, false, null);
    try std.testing.expect(one.result != null);
    try std.testing.expectEqual(writes_before, cache_writes);
    one.result.?.deinit(a);
    one.result = null;
    one.ready.store(false, .release);
    one.pending = false;
    one.cache_cancelled.store(false, .release);
    // A failed rebuild of an evicted prefix retains the shown cached tail.
    one.history.restore_full = true;
    one.pending = true;
    chatFileFetchThread(&one, one.key, 3, false, null);
    chatFileOnReady();
    try std.testing.expectEqual(@as(usize, 1), g_chat_block_count);
    // Debounce flushes the final delta even if subsequent polls have no rows.
    one.history.restore_full = false;
    remote_pages = &.{ "@mp\\t8\\thistory\\tok\\tsid\\t100\\t150\\t10\\t0\\tclaude\\tterm-1\\t0\\t" ++ ("a" ** 64) ++ "\\tdelta\\t0\\n{\\\"role\\\":\\\"user\\\",\\\"text\\\":\\\"later prompt\\\"}\\n@@MP_END@@\\n" };
    remote_calls = 0;
    ticks = 600;
    one.pending = true;
    chatFileFetchThread(&one, one.key, 8, false, null);
    try std.testing.expect(one.incremental);
    chatFileOnReady();
    try std.testing.expect(one.cache_dirty);
    try std.testing.expectEqual(writes_before, cache_writes);
    const text_ptr = one.history.text.items.ptr;
    ticks = 31_000;
    remote_pages = &.{ "@mp\\t9\\thistory\\tok\\tsid\\t150\\t150\\t10\\t0\\tclaude\\tterm-1\\t0\\t" ++ ("a" ** 64) ++ "\\tdelta\\t0\\n@@MP_END@@\\n" };
    remote_calls = 0;
    one.pending = true;
    chatFileFetchThread(&one, one.key, 9, false, null);
    try std.testing.expect(one.unchanged);
    chatFileOnReady();
    try std.testing.expectEqual(text_ptr, one.history.text.items.ptr);
    try std.testing.expect(!one.cache_dirty);
    try std.testing.expectEqual(writes_before + 1, cache_writes);
    // A replaced cache entry can have the same revision and text length.
    // Its generation must still invalidate both content and reusable geometry.
    const prior_hash = g_chat_last_hash;
    one.generation += 1;
    one.history.text.items[0] = '^';
    try std.testing.expect(refreshChatBlockCache(false));
    try std.testing.expectEqual(prior_hash, g_chat_last_hash);
    try std.testing.expectEqual(@as(u16, '^'), g_chat_capture[0]);
    try std.testing.expectEqual(@as(usize, 0), g_chat_layout_reuse);
    // Scroll-up prepends just one requested page and preserves the old message.
    one.history.start = 50;
    one.before = 50;
    fake_viewport_h = 80;
    g_chat_scrolled_up = true;
    one.show_older = true;
    g_chat_scroll_y = 0;
    remote_pages = &.{ "@mp\\t10\\thistory\\tok\\tsid\\t25\\t50\\t10\\t0\\tclaude\\tterm-1\\t0\\t" ++ ("a" ** 64) ++ "\\tolder\\t25\\n{\\\"role\\\":\\\"assistant\\\",\\\"text\\\":\\\"older reply\\\"}\\n@@MP_END@@\\n" };
    remote_calls = 0;
    one.pending = true;
    chatFileFetchThread(&one, one.key, 10, false, null);
    try std.testing.expect(one.prepended);
    chatFileOnReady();
    try std.testing.expectEqual(@as(usize, 3), g_chat_block_count);
    try std.testing.expectEqual(@as(i32, 40), g_chat_scroll_y);
    try std.testing.expectEqual(@as(u64, 150), one.history.offset);
    try std.testing.expectEqual(@as(u64, 25), one.history.start);
    try std.testing.expectEqual(@as(u64, 25), one.before);
    try std.testing.expectEqual(GetTickCount64(), one.next);
    const status_text_ptr = one.history.text.items.ptr;
    const status_blocks = g_chat_block_count;
    const prior_layouts = status_layout_calls;
    g_chat_layout_reuse = status_blocks;
    remote_pages = &.{ "@mp\\t11\\thistory\\tok\\tsid\\t150\\t150\\t10\\t0\\tclaude\\tterm-1\\t0\\t" ++ ("a" ** 64) ++ "\\tdelta\\t25\\n{\\\"role\\\":\\\"status\\\",\\\"model\\\":\\\"Opus 5.5\\\",\\\"percent_left\\\":62}\\n@@MP_END@@\\n" };
    remote_calls = 0;
    one.pending = true;
    chatFileFetchThread(&one, one.key, 11, false, null);
    try std.testing.expect(one.unchanged);
    chatFileOnReady();
    try std.testing.expectEqual(status_text_ptr, one.history.text.items.ptr);
    try std.testing.expectEqual(status_blocks, g_chat_block_count);
    try std.testing.expectEqual(status_blocks, g_chat_layout_reuse);
    try std.testing.expectEqual(@as(?u8, 62), one.history.status.percent_left);
    try std.testing.expectEqual(prior_layouts + 1, status_layout_calls);
    const known_layouts = status_layout_calls;
    remote_calls = 0;
    one.pending = true;
    chatFileFetchThread(&one, one.key, 11, false, null);
    chatFileOnReady();
    try std.testing.expectEqual(known_layouts, status_layout_calls);
    fake_viewport_h = 800;
    shells[0].kind = .cmd;
    capture_result = 0;
    refreshChatTranscript(false);
    try std.testing.expectEqual(@as(usize, 3), g_chat_block_count);
}
`;
function runHarness(deferSource, oldImage, cases = acceptance, scroll = fn('chatScrollBy'), boundary = 'fn chatReadBoundary() chat_history.ReadBoundary { return .{}; }') {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh301-'));
  try {
    copyZig(['chat_hit.zig', 'chat_echo.zig', 'chat_history.zig', 'chat_switch.zig', 'chat_transcript.zig', 'chat_markdown.zig', 'chat_style.zig', 'chat_image.zig', 'chat_diff.zig'], dir);
    fs.writeFileSync(path.join(dir, 'chat_find_ui.zig'), 'pub fn close(_: bool) void {}\n');
    fs.writeFileSync(path.join(dir, 'launch_cache.zig'), 'pub var pending = false;\npub var queue = struct { next: usize = 0 }{};\npub fn changed() void {}\n');
    fs.cpSync('src/testdata', path.join(dir, 'testdata'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'main-test.zig'), prelude.replace('fn chatReadBoundary() chat_history.ReadBoundary { return .{}; }', boundary) + entry + (functions.map(n => n === 'chatScrollBy' ? scroll : n === 'chatRelayoutPreservingScroll' && oldImage ? oldImage : fn(n)).join('\n') + deferSource + cases).replaceAll('@import("chat_render.zig").chatViewClientRect', 'chatViewClientRect').replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary').replaceAll('@import("win32.zig").UpdateWindow', 'UpdateWindow').replaceAll('@import("win32.zig").SetEvent', 'SetEvent'));
    return spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'main-test.zig'), '--test-filter', 'cache-first switch-back'], { encoding: 'utf8', timeout: 60000 });
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}
test('executed production switch/refresh/completion/layout code keeps cached full history, scroll and stale results safe', () => {
  const run = runHarness(fn('chatDeferTranscriptLoad'));
  assert.equal(run.status, 0, run.stdout + run.stderr);
  assert.match(run.stderr, /All 1 tests passed/);
});
test('pushed replies persist without waiting for another transcript event', () => {
  const cases = String.raw`
test "cache-first switch-back pushed persistence" {
    const a = std.heap.page_allocator;
    var one: ChatHistoryEntry = .{ .key = chat_transcript.Identity.initTmux(1, 0, false, "term-1", "") };
    defer one.history.deinit(a);
    defer if (one.result) |*history| history.deinit(a);
    capture_cache = true;
    defer captured_cache.deinit(a);
    try one.history.apply(a, "@mp\t1\thistory\tok\tsid\t0\t100\t9\t0\tclaude\tterm-1\n{\"role\":\"assistant\",\"id\":\"old\",\"text\":\"First reply\",\"offset\":0,\"end\":100}\n@@MP_END@@\n", 1, one.key);
    one.cache_written = 500;
    ticks = 600;
    var wire: std.ArrayList(u8) = .empty;
    try wire.appendSlice(a, "@mp\t2\thistory\tok\tsid\t100\t200\t9\t0\tclaude\tterm-1\t0\t-\tdelta\t0\n{\"role\":\"assistant\",\"id\":\"new\",\"text\":\"Pushed second reply\",\"offset\":100,\"end\":200}\n@@MP_END@@\n");
    chatFileFetchThread(&one, one.key, 2, false, .{ .wire = wire, .id = 2, .read_us = 0 });
    try std.testing.expectEqual(@as(usize, 0), remote_calls);
    try std.testing.expectEqual(@as(usize, 1), cache_writes);
    var restored = try chat_history.History.decode(a, captured_cache.items, one.key);
    defer restored.deinit(a);
    try std.testing.expect(std.mem.indexOf(u8, restored.rows.items, "First reply") != null);
    try std.testing.expect(std.mem.indexOf(u8, restored.rows.items, "Pushed second reply") != null);
    try std.testing.expectEqual(@as(usize, 2), restored.blocks.items.len);
    try std.testing.expect(!one.cache_dirty);
}
`;
  const run = runHarness(fn('chatDeferTranscriptLoad'), undefined, cases);
  assert.equal(run.status, 0, run.stdout + run.stderr);
  assert.match(run.stderr, /All 1 tests passed/);
});
test('IGSH-871 live completion preserves the first offline reply before settling the visit', () => {
  const cases = `
test "cache-first switch-back IGSH-871 live completion" {
    const a = std.heap.page_allocator;
    var one: ChatHistoryEntry = .{ .key = chat_transcript.Identity.initTmux(1, 0, false, "term-1", "") };
    defer one.history.deinit(a);
    try g_chat_histories.append(a, &one);
    shell_count = 1;
    active_shell = 0;
    shells[0].shell_id = 1;
    @memcpy(shells[0].tmux_session[0..6], "term-1");
    shells[0].tmux_session_len = 6;
    try one.history.apply(a, "@mp\\t1\\thistory\\tok\\tsid\\t0\\t100\\t9\\t0\\tclaude\\tterm-1\\n{\\"role\\":\\"assistant\\",\\"id\\":\\"read\\",\\"text\\":\\"Read reply\\",\\"offset\\":0,\\"end\\":100}\\n@@MP_END@@\\n", 1, one.key);
    shells[0].last_read_message_id = one.history.blocks.items[0].message_id;
    chatDeferTranscriptLoad();
    try std.testing.expectEqual(@as(usize, 1), g_chat_block_count);
    one.loaded_ms = 1;
    var incoming = try one.history.clone(a);
    try incoming.apply(a, "@mp\\t2\\thistory\\tok\\tsid\\t100\\t200\\t9\\t0\\tclaude\\tterm-1\\n{\\"role\\":\\"assistant\\",\\"id\\":\\"unread\\",\\"text\\":\\"Offline reply\\",\\"offset\\":100,\\"end\\":200}\\n@@MP_END@@\\n", 2, one.key);
    one.result = incoming;
    one.ready.store(true, .release);
    chatFileOnReady();
    try std.testing.expectEqual(@as(usize, 2), g_chat_block_count);
    try std.testing.expectEqual(@as(?usize, 1), chatReadBoundary().index);
}
`;
  const run = runHarness(fn('chatDeferTranscriptLoad'), undefined, cases, fn('chatScrollBy'), fn('chatReadBoundary'));
  assert.equal(run.status, 0, run.stdout + run.stderr);
  assert.match(run.stderr, /All 1 tests passed/);
});
test('IGSH-720 upward scrolling cancels stale send jumps but fresh sends and forced refreshes follow', () => {
  const cases = `
test "cache-first switch-back IGSH-720 follows only while at the bottom" {
    const a = std.heap.page_allocator;
    var one: ChatHistoryEntry = .{ .key = chat_transcript.Identity.initTmux(1, 0, false, "term-1", "") };
    defer one.history.deinit(a);
    try g_chat_histories.append(a, &one);
    shells[0].shell_id = 1;
    @memcpy(shells[0].tmux_session[0..6], "term-1");
    shells[0].tmux_session_len = 6;
    fake_viewport_h = 80;
    try one.history.apply(a, "@mp\\t1\\thistory\\tok\\tsid\\t0\\t100\\t9\\t0\\tclaude\\tterm-1\\n" ++
        ("{\\"role\\":\\"assistant\\",\\"text\\":\\"message\\"}\\n" ** 10) ++ "@@MP_END@@\\n", 1, one.key);
    refreshChatTranscript(true);
    try std.testing.expectEqual(@as(i32, 320), g_chat_scroll_y);
    g_chat_scroll_bottom_pending = true;
    chatScrollBy(120);
    try std.testing.expect(g_chat_scrolled_up);
    const pending_after_scroll = g_chat_scroll_bottom_pending;
    const reading_y = g_chat_scroll_y;
    try one.history.apply(a, "@mp\\t2\\thistory\\tok\\tsid\\t100\\t200\\t9\\t0\\tclaude\\tterm-1\\n{\\"role\\":\\"assistant\\",\\"text\\":\\"reply\\"}\\n@@MP_END@@\\n", 2, one.key);
    refreshChatTranscript(false);
    try std.testing.expectEqual(reading_y, g_chat_scroll_y);
    try std.testing.expect(!pending_after_scroll);
    try std.testing.expect(g_chat_scrolled_up);
    chatRelayoutPreservingScroll(900, fake_viewport_h);
    try std.testing.expectEqual(reading_y, g_chat_scroll_y);
    g_chat_scroll_bottom_pending = true;
    refreshChatTranscript(false);
    try std.testing.expect(g_chat_scroll_bottom_pending);
    try std.testing.expectEqual(reading_y, g_chat_scroll_y);
    try one.history.apply(a, "@mp\\t3\\thistory\\tok\\tsid\\t200\\t300\\t9\\t0\\tclaude\\tterm-1\\n{\\"role\\":\\"user\\",\\"text\\":\\"fresh send\\"}\\n@@MP_END@@\\n", 3, one.key);
    refreshChatTranscript(false);
    try std.testing.expectEqual(g_chat_content_h - fake_viewport_h, g_chat_scroll_y);
    try std.testing.expect(!g_chat_scroll_bottom_pending);
    try std.testing.expect(!g_chat_scrolled_up);
    try one.history.apply(a, "@mp\\t4\\thistory\\tok\\tsid\\t300\\t400\\t9\\t0\\tclaude\\tterm-1\\n{\\"role\\":\\"assistant\\",\\"text\\":\\"newest\\"}\\n@@MP_END@@\\n", 4, one.key);
    refreshChatTranscript(false);
    try std.testing.expectEqual(g_chat_content_h - fake_viewport_h, g_chat_scroll_y);
    chatScrollBy(120);
    try std.testing.expect(g_chat_scrolled_up);
    try std.testing.expect(!g_chat_scroll_bottom_pending);
    refreshChatTranscript(true);
    try std.testing.expectEqual(g_chat_content_h - fake_viewport_h, g_chat_scroll_y);
}
`;
  const run = runHarness(fn('chatDeferTranscriptLoad'), undefined, cases);
  assert.equal(run.status, 0, run.stdout + run.stderr);
  assert.match(run.stderr, /All 1 tests passed/);
  const preFixScroll = `fn chatScrollBy(delta_px: i32) void {
    if (g_chat_transcript_hwnd == null) return;
    const max_scroll = chatMaxScroll();
    const new_y = std.math.clamp(g_chat_scroll_y - delta_px, chatMinScroll(), max_scroll);
    if (delta_px > 0 and new_y <= uiScaled(80)) {
        if (chatHistoryEntry(chatFileIdentity())) |entry| {
            if (!entry.pending and entry.history.start > 0) {
                entry.before = entry.history.start;
                g_chat_scrolled_up = true;
                entry.next = 0;
                chatFileRequest(chatFileIdentity());
            }
        }
    }
    if (new_y == g_chat_scroll_y) return;
    g_chat_scroll_y = new_y;
    g_chat_scrolled_up = new_y < max_scroll - uiScaled(4);
    g_chat_hover_copy = null;
    _ = InvalidateRect(g_chat_transcript_hwnd, null, 0);
}`;
  const old = runHarness(fn('chatDeferTranscriptLoad'), undefined, cases, preFixScroll);
  assert.notEqual(old.status, 0);
  assert.match(old.stderr, /expected 200, found 360/);
  assert.match(fn('layoutChatControls'), /chatRelayoutPreservingScroll/);
});
test('acceptance oracle rejects a blanking defer (positive control)', () => {
  const run = runHarness('fn chatDeferTranscriptLoad() void { g_chat_block_count = 0; }');
  assert.notEqual(run.status, 0);
  assert.match(run.stderr, /expected 1000, found 0/);
});
test('thumbnail anchor oracle rejects raw-offset relayout (positive control)', () => {
  const image = 'fn chatRelayoutPreservingScroll(_: i32, _: i32) void { chatRelayout(800); }';
  const run = runHarness(fn('chatDeferTranscriptLoad'), image);
  assert.notEqual(run.status, 0);
  assert.match(run.stderr, /expected 345, found 45/);
});
test('background retries, local cache, complete dynamic layout and diagnostics are wired without browser-path changes', () => {
  assert.doesNotMatch(fn('chatHistoryEntry'), /chatHistoryRead|History.decode/);
  assert.match(fn('chatFileFetchThread'), /chatHistoryRead[\s\S]*History.decode/);
  assert.match(fn('chatFileRequestForDelivery'), /retryDue[\s\S]*std.Thread.spawn/);
  assert.match(fn('chatFileFetchThread'), /history.apply[\s\S]*writeFileAtomicW[\s\S]*transcript load shell=/);
  assert.match(fn('chatHistoryChannelStart'), /@embedFile\("chat_history_reader.py"\)/);
  assert.match(fn('chatHistoryFetchOnce'), /@embedFile\("chat_history_reader.py"\)/);
  assert.match(fn('chatHistoryPersistent'), /60_000/);
  assert.match(fn('chatHistoryFetchOnce'), /60_000/);
  assert.doesNotMatch(fn('chatHistoryFetch'), /fetchAcPersistent|mp_complete/);
  assert.match(fn('chatPaintTranscriptContent'), /Could not load the conversation, retrying/);
  assert.match(fn('chatImageReady'), /chatRelayoutPreservingScroll/);
  assert.match(fn('chatViewLayout'), /activePaneContentRect\(rc\)/);
  assert.match(fn('activePaneRects'), /browserSlotReserved/);
  assert.doesNotMatch(fn('chatViewLayout'), /centeredConsoleColumn|chatBrowserVisible/);
  assert.doesNotMatch(src, /CHAT_LOAD_MAX_TRIES/);
});

function runMetadataHarness(text) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-metadata-'));
  const support = `
var g_chat_file_request_id: u32 = 0;
const LASTINPUTINFO = struct { cbSize: u32, dwTime: u32 };
fn IsIconic(_: HANDLE) i32 { return 0; }
fn IsWindowVisible(_: HANDLE) i32 { return 1; }
fn GetLastInputInfo(_: *LASTINPUTINFO) i32 { return 1; }
fn chatFetchAcquire() bool { return true; }
const TestThread = struct {
    fn spawn(_: anytype, comptime _: anytype, args: anytype) !@This() {
        captured_key = args[1];
        return .{};
    }
    fn detach(_: @This()) void {}
};
test "learned metadata survives an empty shell identity but not a new session" {
    var history: ChatHistoryEntry = .{ .key = chat_transcript.Identity.initTmux(1, 0, false, "term-1", "/work/demo") };
    @memcpy(history.key.sid[0..3], "sid");
    try g_chat_histories.append(std.heap.page_allocator, &history);
    defer {
        g_chat_histories.deinit(std.heap.page_allocator);
        g_chat_histories = .empty;
    }
    shells[0] = .{ .shell_id = 1, .tmux_session_len = 6 };
    @memcpy(shells[0].tmux_session[0..6], "term-1");
    const key = chatFileIdentityForShell(0);
    try std.testing.expectEqualStrings("sid", std.mem.sliceTo(&key.sid, 0));
    try std.testing.expectEqualStrings("/work/demo", std.mem.sliceTo(&key.cwd, 0));
    @memcpy(shells[0].claude_sid[0..3], "new");
    shells[0].claude_sid_len = 3;
    const changed = chatFileIdentityForShell(0);
    try std.testing.expectEqualStrings("new", std.mem.sliceTo(&changed.sid, 0));
    try std.testing.expect(changed.cwd[0] == 0);
    shells[0].claude_sid_len = 0;
    history.retired = true;
    try std.testing.expect(chatFileIdentityForShell(0).sid[0] == 0);
}
test "worker receives retained sid and cwd, including a disk-learned sid" {
    var history: ChatHistoryEntry = .{ .key = chat_transcript.Identity.initTmux(1, 0, false, "term-1", "/work/demo"), .disk_loaded = true };
    @memcpy(history.key.sid[0..3], "sid");
    try g_chat_histories.append(std.heap.page_allocator, &history);
    defer {
        g_chat_histories.deinit(std.heap.page_allocator);
        g_chat_histories = .empty;
    }
    const empty = chat_transcript.Identity.initTmux(1, 0, false, "term-1", "");
    chatFileRequest(empty);
    try std.testing.expectEqualStrings("sid", std.mem.sliceTo(&captured_key.sid, 0));
    try std.testing.expectEqualStrings("/work/demo", std.mem.sliceTo(&captured_key.cwd, 0));
    history.key.sid = @splat(0);
    @memcpy(history.history.sid[0..4], "disk");
    history.pending = false;
    history.stream = null;
    chatFileRequest(empty);
    try std.testing.expectEqualStrings("disk", std.mem.sliceTo(&captured_key.sid, 0));
    try std.testing.expectEqualStrings("/work/demo", std.mem.sliceTo(&captured_key.cwd, 0));
}
`;
  try {
    copyZig(['chat_echo.zig', 'chat_history.zig', 'chat_switch.zig', 'chat_transcript.zig', 'chat_markdown.zig', 'chat_style.zig', 'chat_image.zig', 'chat_diff.zig'], dir);
    fs.writeFileSync(path.join(dir, 'chat_find_ui.zig'), 'pub fn close(_: bool) void {}\n');
    fs.writeFileSync(path.join(dir, 'launch_cache.zig'), 'pub var pending = false;\npub var queue = struct { next: usize = 0 }{};\npub fn changed() void {}\n');
    fs.cpSync('src/testdata', path.join(dir, 'testdata'), { recursive: true });
    const fixturePrelude = prelude.replace(fn('chatFileRequest', prelude), '');
    const request = ['chatFileRequest', 'chatFileRequestForDelivery'].filter(n => text.includes(`fn ${n}(`)).map(n => fn(n, text)).join('\n').replace('std.Thread.spawn', 'TestThread.spawn');
    fs.writeFileSync(path.join(dir, 'main-test.zig'), (fixturePrelude + entry +
      ['chatFileIdentityForShell', 'chatFileFailed', 'chatFileFetchThread'].map(n => fn(n, text)).join('\n') + request + support).replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary').replaceAll('@import("win32.zig").UpdateWindow', 'UpdateWindow').replaceAll('@import("win32.zig").SetEvent', 'SetEvent'));
    return spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'main-test.zig'), '--test-filter', 'main-test.test'], { encoding: 'utf8', timeout: 60000 });
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}

test('production chat identity and worker dispatch retain learned sid/cwd when shell metadata is empty', () => {
  const run = runMetadataHarness(src);
  assert.equal(run.status, 0, run.stdout + run.stderr);
  assert.match(run.stderr, /All \d+ tests passed/);
});

test('metadata retention oracle rejects the actual 708 identity and worker dispatch (positive control)', () => {
  const old = ({ status: 0, stdout: fs.readFileSync('tools/fixtures/chat-before-7a02ac9.zig', 'utf8') });
  assert.equal(old.status, 0);
  const run = runMetadataHarness(old.stdout);
  assert.notEqual(run.status, 0);
  assert.match(run.stderr, /learned metadata[\s\S]*?FAIL \(TestExpectedEqual\)/);
  assert.match(run.stderr, /worker receives retained[\s\S]*?FAIL \(TestExpectedEqual\)/);
  assert.match(run.stderr, /TestExpectedEqual/);
});

test('IGSH-815 snapshot deferral arms polling and stalled older pages stop continuing', () => {
  const cases = `
test "cache-first switch-back IGSH-815 restart and continuation progress" {
    const a = std.heap.page_allocator;
    const launch = @import("launch_cache.zig");
    launch.pending = true;
    launch.queue.next = 2;
    g_chat_block_count = 24;
    const timers = timer_calls;
    chatDeferTranscriptLoad();
    try std.testing.expectEqual(timers + 1, timer_calls);
    try std.testing.expectEqual(@as(usize, 24), g_chat_block_count);
    launch.pending = false;
    var one: ChatHistoryEntry = .{ .key = chat_transcript.Identity.initTmux(1, 0, false, "term-1", "") };
    defer one.history.deinit(a);
    try g_chat_histories.append(a, &one);
    shells[0].shell_id = 1;
    @memcpy(shells[0].tmux_session[0..6], "term-1");
    shells[0].tmux_session_len = 6;
    try one.history.apply(a, "@mp\\t1\\thistory\\tok\\tsid\\t100\\t200\\t9\\t0\\tclaude\\tterm-1\\t1\\t\\ttail\\t100\\n{\\"role\\":\\"user\\",\\"text\\":\\"last\\"}\\n@@MP_END@@\\n", 1, one.key);
    one.disk_loaded = true;
    shells[0].last_read_message_id = 42;
    one.failures = 1;
    one.next = 99999;
    chatDeferTranscriptLoad();
    try std.testing.expectEqual(@as(u64, 99999), one.next);
    one.failures = 0;
    chatDeferTranscriptLoad();
    try std.testing.expectEqual(@as(u64, 0), one.next);
    one.before = 100;
    remote_pages = &.{ "@mp\\t2\\thistory\\tok\\tsid\\t100\\t100\\t9\\t0\\tclaude\\tterm-1\\t1\\t\\tolder\\t100\\n{\\"role\\":\\"user\\",\\"text\\":\\"duplicate\\"}\\n@@MP_END@@\\n" };
    remote_calls = 0;
    one.pending = true;
    chatFileFetchThread(&one, one.key, 2, false, null);
    chatFileOnReady();
    try std.testing.expectEqual(@as(u64, 0), one.before);
    try std.testing.expectEqual(@as(u64, 100), one.history.start);
    try std.testing.expectEqual(@as(usize, 1), one.history.blocks.items.len);
    try std.testing.expectEqual(ticks + chatFilePollInterval(), one.next);
    remote_pages = &.{ "@mp\\t3\\thistory\\tok\\tsid\\t200\\t200\\t9\\t0\\tclaude\\tterm-1\\t1\\t\\tdelta\\t100\\n@@MP_END@@\\n" };
    remote_calls = 0;
    one.pending = true;
    chatFileFetchThread(&one, one.key, 3, false, null);
    chatFileOnReady();
    try std.testing.expectEqual(@as(u64, 0), one.before);
    try std.testing.expectEqual(ticks + chatFilePollInterval(), one.next);
    try std.testing.expectEqual(@as(usize, 1), one.history.blocks.items.len);
}
`;
  const run = runHarness(fn('chatDeferTranscriptLoad'), undefined, cases);
  assert.equal(run.status, 0, run.stdout + run.stderr);
  assert.match(run.stderr, /All 1 tests passed/);
});
