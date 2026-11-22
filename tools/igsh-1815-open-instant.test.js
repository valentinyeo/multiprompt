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

function body(name) {
  const start = src.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  const end = src.indexOf('\nfn ', start + 1);
  return src.slice(start, end < 0 ? src.length : end);
}

const history = fs.readFileSync(path.join(__dirname, 'chat-transcript-history.test.js'), 'utf8');
const preludeOpen = history.indexOf('const prelude = `');
const prelude = history.slice(preludeOpen + 'const prelude = `'.length, history.indexOf('`;\nconst entry', preludeOpen));
const entry = src.slice(src.indexOf('const ChatHistoryEntry = struct {'), src.indexOf('\n};', src.indexOf('const ChatHistoryEntry = struct {')) + 3);
const needed = ['chatActivateTables', 'chatGrowSlice', 'chatEnsureTranscriptCapacity', 'chatFileIdentity', 'chatFileIdentityForShell', 'chatCacheIdentity', 'chatLoadSaved'];

const masterDefer = `
fn chatDeferTranscriptLoad() void {
    if (!g_chat_active or g_chat_transcript_hwnd == null) return;
    if (g_main_hwnd != null) _ = SetTimer(g_main_hwnd, TIMER_CHAT_REFRESH, 750, null);
    if (@import("launch_cache.zig").pending and @import("launch_cache.zig").queue.next <= 2) return;
    chat_layout_snapshot.save();
    @import("chat_find_ui.zig").close(false);
    g_chat_prepend_pending = false;
    g_chat_layout_reuse = 0;
    const cached = chatHistoryEntry(chatCacheIdentity());
    chatActivateTables(cached);
    g_chat_received.clear(std.heap.page_allocator);
    g_chat_block_count = 0;
    g_chat_last_len = 0;
    g_chat_last_hash = 0;
    g_chat_cache_generation = 0;
    g_chat_file_valid = false;
    g_chat_blocks_from_file = false;
    g_chat_window_full = false;
    g_chat_screen_status_len = 0;
    g_chat_screen_working = false;
    g_chat_working_applied_len = 0;
    g_chat_cache_shell_id = if (active_shell < shell_count) shells[active_shell].shell_id else 0;
    if (cached) |entry| {
        const history = &entry.history;
        if (chatEnsureTranscriptCapacity(history.text.items.len, history.blocks.items.len)) {
            g_chat_last_hash = history.revision;
            g_chat_cache_generation = if (history.rows.items.len > 0) entry.generation else 0;
            g_chat_last_len = history.text.items.len;
            g_chat_block_count = history.blocks.items.len;
            @memcpy(g_chat_capture[0..g_chat_last_len], history.text.items);
            @memcpy(g_chat_blocks[0..g_chat_block_count], history.blocks.items);
            g_chat_file_valid = history.rows.items.len > 0;
            g_chat_blocks_from_file = g_chat_file_valid;
        }
    }
    chatEchoMatchActive();
    g_chat_switch_loading = g_chat_block_count == 0;
    g_chat_content_h = 0;
    g_chat_scroll_y = 0;
    g_chat_scrolled_up = false;
    g_chat_new_messages = .{};
    g_chat_read_boundary = .{};
    if (g_chat_read_visit_shell_id != g_chat_cache_shell_id) {
        g_chat_read_visit_shell_id = g_chat_cache_shell_id;
        g_chat_read_visit_marker = if (active_shell < shell_count) shells[active_shell].last_read_message_id else 0;
        g_chat_read_visit_state = .pending;
    }
    g_chat_read_open_ready = false;
    g_chat_read_hold = active_shell < shell_count and shells[active_shell].last_read_message_id != 0;
    g_chat_read_open_pending = false;
    if (g_chat_read_hold) {
        if (cached) |entry| {
            if (entry.failures == 0) entry.next = 0;
        }
    }
    g_chat_echo_layout_count = 0;
    g_chat_hover_copy = null;
    g_chat_hover_link = null;
    g_chat_sel_transcript_focus = false;
    chatSelectionClear();
    _ = chat_layout_snapshot.restore(cached);
    g_chat_layout_dirty = true;
    _ = InvalidateRect(g_chat_transcript_hwnd, null, 0);
    if (g_chat_block_count == 0) chatFileRequest(chatFileIdentity());
}
`;

const cases = String.raw`
test "IGSH-1815 cache-first switch-back opens saved messages without a loading screen" {
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
    try wire.appendSlice(a, "@mp\t1\thistory\tok\tsid\t0\t40\t9\t0\tclaude\tterm-1\n");
    try wire.appendSlice(a, "{\"role\":\"user\",\"id\":\"saved\",\"text\":\"Saved hello\",\"offset\":0,\"end\":40}\n");
    try wire.appendSlice(a, "@@MP_END@@\n");
    try one.history.apply(a, wire.items, 1, one.key);
    const disk = try one.history.encode(a, one.key);
    defer a.free(disk);
    one.history.deinit(a);
    one.history = .{};
    one.disk_loaded = false;
    disk_bytes = disk;
    active_shell = 0;
    g_chat_active = true;
    request_count = 0;
    chatDeferTranscriptLoad();
    try std.testing.expect(g_chat_block_count > 0);
    try std.testing.expect(!g_chat_switch_loading);
    try std.testing.expectEqual(@as(usize, 0), request_count);
    try std.testing.expect(one.disk_loaded);
    const hello = std.unicode.utf8ToUtf16LeStringLiteral("Saved hello");
    try std.testing.expect(std.mem.indexOf(u16, g_chat_capture[0..g_chat_last_len], hello) != null);
    const before = g_chat_block_count;
    try one.history.apply(a, "@mp\t2\thistory\tok\tsid\t40\t80\t9\t0\tclaude\tterm-1\n{\"role\":\"assistant\",\"text\":\"Later reply\"}\n@@MP_END@@\n", 2, one.key);
    chatDeferTranscriptLoad();
    try std.testing.expect(g_chat_block_count > before);
    try std.testing.expect(!g_chat_switch_loading);
    try std.testing.expectEqual(@as(usize, 0), request_count);
    const later = std.unicode.utf8ToUtf16LeStringLiteral("Later reply");
    try std.testing.expect(std.mem.indexOf(u16, g_chat_capture[0..g_chat_last_len], later) != null);
    active_shell = 1;
    chatDeferTranscriptLoad();
    try std.testing.expectEqual(@as(usize, 0), g_chat_block_count);
    try std.testing.expectEqual(@as(usize, 0), g_chat_last_len);
    try std.testing.expect(!g_chat_switch_loading);
}
`;

function run(deferSource) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh1815-'));
  require('./fixtures/inline-stubs').writeAll(dir);
  try {
    copyZig(['chat_hit.zig', 'chat_echo.zig', 'chat_history.zig', 'chat_switch.zig', 'chat_transcript.zig', 'chat_live.zig', 'chat_markdown.zig', 'chat_style.zig', 'chat_image.zig', 'chat_diff.zig'], dir);
    fs.writeFileSync(path.join(dir, 'agent_second_line.zig'), 'pub var calls: usize = 0;\npub fn forShell(_: usize) u8 { calls += 1; return 0; }\n');
    fs.writeFileSync(path.join(dir, 'window_layout.zig'), 'pub fn invalidateSidebar() void {}\n');
    fs.writeFileSync(path.join(dir, 'inbox.zig'), 'pub fn publishInboxState() void {}\n');
    fs.writeFileSync(path.join(dir, 'chat_find_ui.zig'), 'pub fn close(_: bool) void {}\n');
    fs.writeFileSync(path.join(dir, 'launch_cache.zig'), 'pub var pending = false;\npub var queue = struct { next: usize = 0 }{};\npub fn changed() void {}\n');
    fs.cpSync('src/testdata', path.join(dir, 'testdata'), { recursive: true });
    const zig = prelude + entry + needed.map(name => fn(name)).join('\n') + deferSource + cases;
    fs.writeFileSync(path.join(dir, 'main-test.zig'), zig.replaceAll('@import("chat_render.zig").chatViewClientRect', 'chatViewClientRect').replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary').replaceAll('@import("win32.zig").UpdateWindow', 'UpdateWindow').replaceAll('@import("win32.zig").SetEvent', 'SetEvent').replaceAll('@import("window_layout.zig").chatWorkingIndicatorSync', 'chatWorkingIndicatorSync'));
    return spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'main-test.zig'), '--test-filter', 'IGSH-1815'], { encoding: 'utf8', timeout: 90000 });
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('IGSH-1815 a used chat paints saved messages and never a loading note', () => {
  assert.match(prelude, /fn chatHistoryRead/);
  const render = fs.readFileSync(path.join(__dirname, '../src/chat_render.zig'), 'utf8');
  const live = render.slice(render.indexOf('const missing_note = if (entry)'), render.indexOf('} else g_note_logged = false;'));
  assert.doesNotMatch(live, /Loading conversation/);
  assert.match(live, /Could not load the conversation, retrying/);
  assert.match(fn('chatDeferTranscriptLoad'), /chatLoadSaved\(entry\)/);
  assert.match(fn('chatDeferTranscriptLoad'), /g_chat_switch_loading = false/);
  assert.match(fn('chatLoadSaved'), /History\.decode/);
  assert.doesNotMatch(fn('chatLoadSaved'), /chatHistoryFetch/);
  assert.match(body('chatFileOnReady'), /g_chat_switch_loading = history\.more and entry\.history\.blocks\.items\.len == 0/);
  const session = fs.readFileSync(path.join(__dirname, '../src/chat_session.zig'), 'utf8');
  const warm = session.slice(session.indexOf('pub fn chatWarmOftenUsed'), session.indexOf('pub fn chatSwitchDidPaint'));
  assert.match(warm, /ranked: \[5\]/);
  assert.match(warm, /last_viewed == 0/);
  assert.match(warm, /chatFileRequestForDelivery\(key, true\)/);
  assert.match(fs.readFileSync(path.join(__dirname, '../src/main.zig'), 'utf8'), /refreshChatTranscript\(false\);\s*chatWarmOftenUsed\(\)/);
  const opened = run(fn('chatDeferTranscriptLoad'));
  assert.equal(opened.status, 0, opened.stdout + opened.stderr);
  assert.match(opened.stderr, /All 1 tests passed/);
});

test('IGSH-1815 the previous open path leaves a saved chat blank', () => {
  const opened = run(masterDefer);
  assert.notEqual(opened.status, 0, opened.stdout + opened.stderr);
  assert.match(opened.stderr, /TestUnexpectedResult/);
});
