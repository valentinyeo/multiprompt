const { copyZig } = require('./zig-copy');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync, execFileSync } = require('node:child_process');
const source = require('./app-source').readAppSource();
function body(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}
function declaration(name) {
  const start = source.indexOf(`const ${name} = struct {`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n};', start) + 3);
}
const prelude = `
const std = @import("std");
const launch_cache = struct { var pending = false; var tabs_restored = true; };
fn chatCancelFinish() void {}
fn chatLivePlanReply(_: []const u16) bool { return false; }
var test_settings_pending = false;
fn chatSettingsPending(_: u32) bool { return test_settings_pending; }
fn chatLiveQuestionText(_: []const u16) bool { return false; }
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
const chat_echo = @import("chat_echo.zig");
const chat_reaction = @import("chat_reaction.zig");
var g_reaction_view: chat_reaction.View = .{};
const json_reader = @import("json_reader.zig");
const chat_markdown = @import("chat_markdown.zig");
const chat_history = @import("chat_history.zig");
const chat_transcript = @import("chat_transcript.zig");
const chat_complete = @import("chat_complete.zig");
const skill_model = @import("skills.zig");
const ChatBlock = chat_markdown.Block;
const ChatEchoState = chat_echo.OutboxState;
const CHAT_OUTBOX_MAX_PER_KEY = 20;
const CHAT_OUTBOX_TOTAL_MAX = 400;
const CHAT_OUTBOX_MSG_CAP = 16384;
const CHAT_OUTBOX_KEY_CAP = 256;
const CHAT_OUTBOX_LOAD_LIMIT = 16 * 1024 * 1024;
const CHAT_ECHO_PREFIX_CAP = 40;
const CHAT_CONFIRMED_MAX_PER_KEY = 50;
const CHAT_STATUS_H: i32 = 20;
const ShellSendResult = enum { ok, write_failed, enter_failed };
const ReconnectState = struct { phase: enum { connected, ended, closed } = .connected, fn ok(_: *@This()) void {} };
const ShellKind = enum { cmd, tmux, vps, vps2 };
const ChatSendRoute = enum { host_message, terminal_send, wait_for_start };
const ChatPendingReset = struct { key: chat_transcript.Identity = .{}, nonce: u64 = 0, request_nonce: u64 = 0, unconfirmed: u8 = 0 };
var g_chat_pending_reset: ?ChatPendingReset = null;
var g_chat_reset_next: u64 = 0;
const Shell = struct { tmux_session: [64]u8 = @splat(0), tmux_session_len: u32 = 0, chat_question_other: bool = false, chat_question_other_sent: bool = false, chat_question_other_hash: u64 = 0, shell_id: u32 = 1, kind: ShellKind = .cmd, ai_agent: u8 = 0, activity: enum { idle, active } = .idle, disconnected: bool = false, ssh_reconnect: ReconnectState = .{} };
const g_main_hwnd: ?*anyopaque = null;
const g_chat_transcript_hwnd: ?*anyopaque = @ptrFromInt(2);
const send_latency = struct {
    fn markPressed() void {}
    fn markEnqueued(_: u64) void {}
};
fn UpdateWindow(_: anytype) i32 { return 1; }
fn RedrawWindow(_: anytype, _: anytype, _: anytype, _: u32) i32 { return 1; }
fn debugLog(_: []const u8) void {}
fn sshOutboxFlushed(_: u32) void {}
fn repositionActive() void {}
fn showReconnectedConsole(_: u32) void {}
fn invalidateReconnectContent(_: u32) void {}
fn InvalidateRect(_: anytype, _: ?*anyopaque, _: u32) u32 { return 0; }
var save_calls: usize = 0;
var publish_calls: usize = 0;
var title_calls: usize = 0;
var rename_calls: usize = 0;
var rename_index: u32 = 0;
var rename_shell_id: u32 = 0;
var rename_name: [16384]u16 = undefined;
var rename_name_len: usize = 0;
var rename_sync = false;
var private_actions_allowed = true;
fn saveSession() void { save_calls += 1; }
fn publishInboxState() void { publish_calls += 1; }
fn updateMainWindowTitle() void { title_calls += 1; }
fn privateActionsAllowed() bool { return private_actions_allowed; }
fn applyCanonicalSessionRename(idx: u32, name: []const u16, sync: bool) bool {
    rename_calls += 1;
    rename_index = idx;
    rename_shell_id = shells[idx].shell_id;
    @memcpy(rename_name[0..name.len], name);
    rename_name_len = name.len;
    rename_sync = sync;
    return true;
}
var shells = [_]Shell{ .{}, .{} };
var shell_count: u32 = 1;
var active_shell: u32 = 0;
var g_chat_active = true;
var clean_chat: bool = false;
var g_chat_screen_working = false;
var g_chat_scroll_bottom_pending = false;
var g_chat_read_open_pending = true;
var g_chat_read_hold = false;
var g_chat_read_open_ready = false;
var read_marks: usize = 0;
fn chatReadMark(bottom: bool) bool {
    std.debug.assert(bottom and !g_chat_read_open_pending and g_chat_read_open_ready);
    read_marks += 1;
    return false;
}
var terminal_notices: usize = 0;
fn showHeaderNoticeAscii(text: []const u8, _: u32, _: bool) void {
    if (std.mem.indexOf(u8, text, "press Alt+C") != null) terminal_notices += 1;
}
var question_sends: usize = 0;
var question_text: []const u16 = &.{};
var question_send_ok = true;
fn chatShellDraftNoteSend() void {}
fn chatShellOp(_: u32, op: []const u8, text: ?[]const u16, _: ?*std.atomic.Value(bool)) bool {
    std.debug.assert(std.mem.eql(u8, op, "question_text"));
    question_sends += 1;
    question_text = text.?;
    return question_send_ok;
}
const ChatTmuxSendJob = struct {
    key: chat_transcript.Identity = .{},
    echo_id: u64 = 0,
    text: []u16,
    retry: bool = false,
    queued_at: i64 = 0,
    queue_id: u64 = 0,
    message_nonce: u64 = 0,
    request_nonce: u64 = 0,
    message_v1: bool = false,
    message_status: bool = false,
    message_reset: bool = false,
    message_dismiss: bool = false,
    reset_cutoff: u64 = 0,
    history_instance: u64 = 0,
    message_generation: u64 = 0,
    message_epoch: u64 = 0,
    message_admission_epoch: ?u64 = null,
    reset_result_epoch: u64 = 0,
    message_state: [16]u8 = @splat(0),
    message_wire_id: [81]u8 = @splat(0),
    message_replaces: [81]u8 = @splat(0),
    held: bool = false,
    written: bool = true,
    rejected: bool = false,
    box_not_clear: bool = false,
    finished: std.atomic.Value(bool) = .init(false),
};
var g_chat_tmux_send_job: ?*ChatTmuxSendJob = null;
fn discardChannelJob() void {
    const job = g_chat_tmux_send_job orelse return;
    std.heap.page_allocator.free(job.text);
    std.heap.page_allocator.destroy(job);
    g_chat_tmux_send_job = null;
}
fn findShellById(id: u32) ?u32 { return if (id == shells[0].shell_id) 0 else null; }
var channel_enabled = false;
fn chatTmuxSendEligible(_: u32) bool { return channel_enabled; }
var channel_starts: usize = 0;
var delivery_polls: usize = 0;
fn chatTmuxSendStart(idx: u32, text: []const u16, id: u64, retry: bool, _: bool, _: bool) bool {
    std.debug.assert(g_chat_tmux_send_job == null);
    const job = std.heap.page_allocator.create(ChatTmuxSendJob) catch return false;
    job.* = .{ .key = .{ .shell_id = shells[idx].shell_id }, .echo_id = id, .text = std.heap.page_allocator.dupe(u16, text) catch {
        std.heap.page_allocator.destroy(job);
        return false;
    }, .retry = retry };
    channel_starts += 1;
    g_chat_tmux_send_job = job;
    if (chatOutboxIndexById(id)) |i| g_chat_outbox.items[i].channel_pending = true;
    return true;
}
fn chatFileIdentityForShell(_: u32) chat_transcript.Identity {
    var key: chat_transcript.Identity = .{};
    key.sid[0] = 's';
    key.tmux[0] = 't';
    return key;
}
fn chatMessageSyncFinish() void {}
fn chatPendingResetStart(_: u32) void {}
fn chatMessageSyncStart(_: u32) void {}
const ChatIdentity = chat_transcript.Identity;
fn chatLogSendPath(_: u32, _: ?*const ChatOutboxEntry, _: ChatSendRoute, _: []const u8) void {}
const ChatSubmitPatch = struct { write_started: bool, state: ChatEchoState, retryable: bool };
fn chatFileRequestForDelivery(_: chat_transcript.Identity, delivery: bool) void { std.debug.assert(delivery); delivery_polls += 1; }
fn MessageBoxW(_: anytype, _: anytype, _: anytype, _: u32) u32 { return 6; }
fn chatHistoryEntry(_: chat_transcript.Identity) ?*HistoryEntry { return &history_entry; }
const ISSUE_349_FULL_SETTLE = false;
var tmux_steers: usize = 0;
var direct_steers: usize = 0;
var steer_shell: u32 = 99;
var writes_at_steer: usize = 0;
var enters_at_steer: usize = 0;
var state_at_steer: ?ChatEchoState = null;
fn chatAgentKey(idx: u32, digit: u8) bool {
    std.debug.assert(digit == 0x18);
    tmux_steers += 1;
    steer_shell = idx;
    if (g_chat_outbox.items.len > 0) state_at_steer = g_chat_outbox.items[0].state;
    return true;
}
fn sendClaudeSendQueuedNowToShell(idx: u32) bool {
    direct_steers += 1;
    steer_shell = idx;
    writes_at_steer = writes;
    enters_at_steer = enters;
    return true;
}
var chat_steer_prompt = false;
var composer_text: []const u16 = &.{};
const g_chat_composer_hwnd: ?*anyopaque = @ptrFromInt(1);
var g_chat_reply: [1024]u8 = @splat(0);
var g_chat_reply_len: usize = 0;
var g_chat_message_wide: [16384]u16 = undefined;
var g_chat_skill_name: [256]u8 = @splat(0);
var g_chat_skill_name_len: usize = 0;
var g_chat_skill_body: [1024]u8 = @splat(0);
var g_chat_skill_body_len: usize = 0;
var g_voice_mode_active = false;
var g_voice_auto_sending = false;
var g_voice_last_activity_tick: u64 = 0;
var g_voice_utt_open = [_]struct { id: u64 = 0, consumed: bool = false }{.{}};
var g_chat_ac_dialog_len: usize = 0;
var g_chat_ac_dialog_shell_id: u32 = 0;
var g_chat_ac_skill_command_len: usize = 0;
var g_chat_ac_skill_shell_id: u32 = 0;
var g_chat_ac_skill_command: [256]u16 = @splat(0);
var mode_picker: ?bool = null;
fn chatModeOpenPicker(plan: bool) void { mode_picker = plan; }
fn chatPiModelPicker() void {}
var g_chat_ac_dialog_command: [256]u16 = @splat(0);
var g_chat_draft_dirty = false;
const TIMER_CHAT_REFRESH: u32 = 1;
fn GetWindowTextW(_: anytype, buf: [*]u16, cap: i32) i32 {
    const n = @min(composer_text.len, @as(usize, @intCast(cap - 1)));
    @memcpy(buf[0..n], composer_text[0..n]);
    buf[n] = 0;
    return @intCast(n);
}
fn SetWindowTextW(_: anytype, _: anytype) i32 { composer_text = &.{}; return 1; }
fn L(comptime text: []const u8) [*:0]const u16 { return std.unicode.utf8ToUtf16LeStringLiteral(text); }
fn SetTimer(_: anytype, _: u32, _: u32, _: ?*anyopaque) usize { return 0; }
fn chatAcClose() void {}
fn chatAcAfterSend(_: []const u16) void {}
fn chatAcAgent() chat_complete.Agent { return .claude; }
fn chatDraftFlush() void {}
fn stampSessionUse(_: u32, _: bool) void {}
fn clearChatReply() void { g_chat_reply_len = 0; }
fn chatFullSettleFinish() void {}
fn chatFullSettleStart() void {}
fn armChatOutboxTimerIfNeeded() void {}
var g_chat_echo_next_id: u64 = 1;
var g_chat_outbox: std.ArrayList(ChatOutboxEntry) = .empty;
var g_chat_confirmed: std.ArrayList(ChatConfirmedEcho) = .empty;
var g_chat_verify_echo_id: u64 = 0;
var g_chat_block_storage: [300]ChatBlock = undefined;
var g_chat_blocks: []ChatBlock = &g_chat_block_storage;
var g_chat_block_count: usize = 0;
var g_chat_capture: []const u16 = &.{};
var g_chat_last_len: usize = 0;
var g_chat_last_hash: u64 = 0;
var g_chat_outbox_revision: u64 = 0;
var g_chat_reconcile_shell: u32 = 0;
var g_chat_reconcile_hash: u64 = 0;
var g_chat_reconcile_outbox: u64 = 0;
var g_chat_reconcile_generation: u64 = 0;
var g_chat_cache_generation: u64 = 0;
var reconcile_passes: usize = 0;
fn chatPerf(_: []const u8, _: u64, _: usize) void { reconcile_passes += 1; }
fn GetTickCount64() u64 { return @intCast(fake_now_ms); }
var writes: usize = 0;
var written_order: [32]u16 = @splat(0);
var enters: usize = 0;
var input_held: ?bool = null;
fn chatPromptStillInInputBox(_: u32, _: []const u16) ?bool { return input_held; }
fn chatLinkLooksDown(idx: u32) bool { return shells[idx].disconnected; }
var persisted: ?[]u8 = null;
fn getChatOutboxPath(_: *[512]u8) ?[]const u8 { return "outbox.json"; }
fn readFileAllocWin32(_: []const u8, _: usize) ?[]u8 {
    return std.heap.page_allocator.dupe(u8, persisted orelse return null) catch null;
}
var persist_ok = true;
var paste_ok = true;
fn saveChatOutbox() bool {
    if (!persist_ok) return false;
    var n: usize = 0;
    const bytes = chatOutboxSerialize(&g_chat_outbox, std.heap.page_allocator, &n) orelse return false;
    defer std.heap.page_allocator.free(bytes);
    if (persisted) |p| std.heap.page_allocator.free(p);
    persisted = std.heap.page_allocator.dupe(u8, bytes[0..n]) catch return false;
    return true;
}
fn clear() void {
    for (g_chat_outbox.items) |e| std.heap.page_allocator.free(e.text);
    g_chat_outbox.deinit(std.heap.page_allocator);
    g_chat_outbox = .empty;
    g_chat_confirmed.deinit(std.heap.page_allocator);
    g_chat_confirmed = .empty;
    if (persisted) |p| std.heap.page_allocator.free(p);
    persisted = null;
    g_chat_block_count = 0;
    g_chat_capture = &.{};
    g_chat_last_len = 0;
    g_chat_last_hash +%= 1;
    g_chat_outbox_revision +%= 1;
    reconcile_passes = 0;
    writes = 0;
    enters = 0;
    input_held = null;
    input_idle = true;
    g_chat_verify_echo_id = 0;
    channel_enabled = false;
    channel_starts = 0;
    delivery_polls = 0;
    discardChannelJob();
    tmux_steers = 0;
    direct_steers = 0;
    steer_shell = 99;
    writes_at_steer = 0;
    enters_at_steer = 0;
    state_at_steer = null;
    composer_text = &.{};
    test_settings_pending = false;
    g_chat_draft_dirty = false;
    terminal_notices = 0;
    g_chat_ac_dialog_len = 0;
    g_chat_ac_dialog_shell_id = 0;
    g_chat_ac_skill_command_len = 0;
    g_chat_ac_skill_shell_id = 0;
    mode_picker = null;
    shells[0].tmux_session_len = 0;
    chat_steer_prompt = false;
    active_shell = 0;
    shell_count = 1;
    shells[1] = .{};
    save_calls = 0;
    publish_calls = 0;
    title_calls = 0;
    rename_calls = 0;
    rename_index = 0;
    rename_shell_id = 0;
    rename_name_len = 0;
    rename_sync = false;
    private_actions_allowed = true;
    fake_now_ms = 2000;
    fake_loaded_ms = 0;
    history_entry.history.deinit(std.heap.page_allocator);
    history_entry.message_synced = false;
    history_entry.message_epoch = 0;
    history_entry.key = .{ .shell_id = 1 };
    g_chat_pending_reset = null;
    g_chat_screen_working = false;
    g_chat_read_open_pending = true;
    g_chat_read_open_ready = false;
    read_marks = 0;
    persist_ok = true;
    paste_ok = true;
    shells[0].chat_question_other = false;
    shells[0].chat_question_other_sent = false;
    question_sends = 0;
    question_send_ok = true;
    question_text = &.{};
    shells[0].activity = .idle;
    shells[0].disconnected = false;
    test_outbox_key = "test";
}
var test_outbox_key: []const u8 = "test";
fn chatOutboxKeyForShell(_: u32, buf: []u8) []const u8 { @memcpy(buf[0..test_outbox_key.len], test_outbox_key); return buf[0..test_outbox_key.len]; }
fn chatEchoRowLanded(_: anytype) bool { return false; }
fn chatOutboxLegacyKeyForShell(_: u32, buf: []u8) []const u8 { return buf[0..0]; }
fn chatBlockDisplayRange(_: []const u16, b: ChatBlock) struct { start: usize, len: usize } { return .{ .start = b.start, .len = b.len }; }
var fake_now_ms: i64 = 2000;
var fake_loaded_ms: i64 = 0;
var fake_history: chat_history.History = .{};
const CHAT_MESSAGE_SYNC_RETRY_CAP_MS: u64 = 30_000;
const HistoryEntry = struct {
    loaded_ms: i64 = 0,
    generation: u64 = 1,
    retired: bool = false,
    key: chat_transcript.Identity = .{ .shell_id = 1 },
    message_epoch: u64 = 0,
    message_seq: u64 = 0,
    message_generation: u64 = 0,
    message_snapshot: [33]u8 = @splat(0),
    message_cursor: u64 = 0,
    message_snapshot_seq: u64 = 0,
    message_synced: bool = false,
    message_v1_owned: bool = false,
    message_next_tick: u64 = 0,
    message_retry_step: u8 = 0,
    send_retry_step: u8 = 0,
    send_next_tick: u64 = 0,
    history: chat_history.History = .{},
};
var history_entry = HistoryEntry{};
var history_entries = [_]*HistoryEntry{&history_entry};
var g_chat_histories = struct { items: []*HistoryEntry }{ .items = &history_entries };
fn nowFileTime() u64 { return @as(u64, @intCast(fake_now_ms)) * 10000 + 116444736000000000; }
fn chatEchoLoadedMs() i64 { return fake_loaded_ms; }
fn chatEchoWindowFull() bool { return false; }
fn chatEchoAnchorNow(_: u32) chat_echo.Anchor { return .{ .after_ms = 1000, .sent_ms = fake_now_ms, .counted = true, .user_count = 1 }; }
fn chatShouldUseDirectInput(_: u32) bool { return true; }
fn chatSendForceBracketed(_: u32) bool { return true; }
fn chatSendEnterDelayMs(_: ShellKind) u32 { return 0; }
var g_chat_message_sync_job: ?*anyopaque = null;
var g_chat_message_sync_next: usize = 0;
fn Sleep(_: u32) void {}
fn pasteTextToShellDirectEx(_: u32, text: []const u16, _: bool) bool {
    // The disk reservation must precede the first byte, even a partial failure.
    std.debug.assert(persisted != null and std.mem.indexOf(u8, persisted.?, "\\\"x\\\":1") != null);
    written_order[writes] = text[0];
    writes += 1;
    return paste_ok;
}
fn sendLocalChatPrompt(_: u32, _: []const u16) bool { unreachable; }
fn sendEnterToShell(_: u32) bool { enters += 1; return true; }
fn chatArmSendVerify(_: u32, _: []const u16, id: u64) bool { g_chat_verify_echo_id = id; return true; }
fn chatVerifyClear() void { g_chat_verify_echo_id = 0; }
fn chatOutboxChanged() void { g_chat_outbox_revision +%= 1; }
var input_idle = true;
fn chatOutboxInputRowIdle(_: u32) bool { return input_idle; }
`;
const pendingStart = source.indexOf('    g_chat_echo_layout_count = 0;\n    if (active_shell < shell_count)');
assert.ok(pendingStart >= 0, 'production pending layout');
const dotsBoundary = source.includes('    if (chatWorkingDotsVisible()) {', pendingStart)
  ? '    if (chatWorkingDotsVisible()) {'
  : '    if (@import("window_layout.zig").chatStopVisible()) {';
const pendingEnd = source.indexOf(dotsBoundary, pendingStart);
assert.ok(pendingEnd > pendingStart);
const pendingLayout = `
const RECT = struct { left: i32 = 0, right: i32 = 0, bottom: i32 = 0 };
const chat_hit = struct { const pending_selection_base: usize = std.math.maxInt(usize) / 2 + 1; };
var g_chat_sel_anchor: usize = 0;
var g_chat_sel_caret: usize = 0;
fn chatSelectionClear() void { g_chat_sel_anchor = 0; g_chat_sel_caret = 0; }
var g_chat_echo_layout_count: usize = 0;
var g_chat_echo_layout: [20]RECT = undefined;
var g_chat_echo_layout_ids: [20]u64 = undefined;
var g_chat_content_left: i32 = 0;
var g_chat_content_h: i32 = 0;
fn chatBlockGapBefore(_: bool, _: enum { user }, _: bool, _: enum { single }) i32 { return 1; }
fn chatMeasureProjectedEchoRect(_: u8, _: []const u16, _: i32, y: i32${source.includes('y: i32, status: bool, projection:') ? ', _: bool' : ''}, _: anytype) RECT { return .{ .bottom = y + 10 }; }
fn chatShellRowsLayout(_: u8, _: i32, y: i32) i32 { return y; }
fn uiScaled(n: i32) i32 { return n; }
fn layoutPending() void {
    const hdc: u8 = 0;
    const width: i32 = 100;
    var y: i32 = 0;
    const old_echo_count = g_chat_echo_layout_count;
    const old_echo_ids = g_chat_echo_layout_ids;
${source.slice(pendingStart, pendingEnd)}
    g_chat_content_h = y;
}
`;
const acceptance = `
test "IGSH-1289 pending sends work before connect without marking another chat working" {
    defer clear();
    clear();
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("first"), .queued);
    try std.testing.expect(chatOutboxWorkingForShell(0));
    try std.testing.expect(!chatOutboxWorkingForShell(1));
    g_chat_outbox.items[0].state = .not_sent;
    try std.testing.expect(!chatOutboxWorkingForShell(0));
    g_chat_outbox.items[0].state = .cancelled;
    try std.testing.expect(!chatOutboxWorkingForShell(0));
}
fn enqueue(text: []const u16, state: ChatEchoState) !void {
    try std.testing.expect(chatOutboxEnqueueInState(&g_chat_outbox, std.heap.page_allocator, "test", text, state));
    g_chat_outbox.items[g_chat_outbox.items.len - 1].anchor = chatEchoAnchorNow(0);
    g_chat_outbox.items[g_chat_outbox.items.len - 1].anchor.sent_ms = 1500;
    g_chat_outbox.items[g_chat_outbox.items.len - 1].sent_tick_ms = 1500;
    g_chat_outbox.items[g_chat_outbox.items.len - 1].write_started = state != .queued;
    g_chat_outbox_revision +%= 1;
}
fn reload() !void {
    g_chat_confirmed.clearRetainingCapacity();
    loadChatOutbox();
}

fn transcript(text: []const u16, stamp: i64) void {
    g_chat_last_hash +%= 1;
    g_chat_capture = text;
    g_chat_last_len = text.len;
    g_chat_blocks[0] = .{ .role = .user, .start = 0, .len = text.len, .stamp_ms = stamp };
    g_chat_block_count = 1;
}
test "delivery: IGSH-1679 rename uses the active shell without sending a message" {
    clear();
    defer clear();
    shell_count = 2;
    active_shell = 1;
    shells[1].shell_id = 42;
    composer_text = std.unicode.utf8ToUtf16LeStringLiteral("/rename  New name  ");
    sendChatPrompt();
    try std.testing.expectEqual(@as(usize, 1), rename_calls);
    try std.testing.expectEqual(@as(u32, 1), rename_index);
    try std.testing.expectEqual(@as(u32, 42), rename_shell_id);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("New name"), rename_name[0..rename_name_len]);
    try std.testing.expect(rename_sync);
    try std.testing.expectEqual(@as(usize, 1), save_calls);
    try std.testing.expectEqual(@as(usize, 1), publish_calls);
    try std.testing.expectEqual(@as(usize, 1), title_calls);
    try std.testing.expectEqual(@as(usize, 0), composer_text.len);
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
}
test "delivery: IGSH-1679 blank and forbidden renames do not mutate" {
    defer clear();
    const wide = std.unicode.utf8ToUtf16LeStringLiteral;
    for ([_][]const u16{ wide("/rename   "), wide("/rename blocked") }, 0..) |command, index| {
        clear();
        private_actions_allowed = index == 0;
        composer_text = command;
        sendChatPrompt();
        try std.testing.expectEqual(@as(usize, 0), rename_calls + save_calls + publish_calls + title_calls);
        try std.testing.expectEqualSlices(u16, command, composer_text);
        try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    }
}
test "delivery: IGSH-1679 ordinary composer text still uses the outbox" {
    clear();
    defer clear();
    const message = std.unicode.utf8ToUtf16LeStringLiteral("ordinary message");
    composer_text = message;
    sendChatPrompt();
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    try std.testing.expectEqualSlices(u16, message, g_chat_outbox.items[0].text);
    try std.testing.expectEqual(@as(usize, 0), composer_text.len);
    try std.testing.expectEqual(@as(usize, 0), rename_calls + save_calls + publish_calls + title_calls);
}
test "delivery: IGSH-1522 live slash commands never enter the ordinary outbox" {
    defer clear();
    const wide = std.unicode.utf8ToUtf16LeStringLiteral;
    for ([_][]const u16{ wide("/plan"), wide("/permissions"), wide("/model"), wide("/resume"), wide("/rewind") }, 0..) |command, index| {
        clear();
        @memcpy(shells[0].tmux_session[0..9], "live-test");
        shells[0].tmux_session_len = 9;
        composer_text = command;
        sendChatPrompt();
        try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
        try std.testing.expectEqualSlices(u16, command, composer_text);
        try std.testing.expectEqual(@as(usize, 0), terminal_notices);
        if (index < 2) try std.testing.expectEqual(@as(?bool, index == 0), mode_picker) else try std.testing.expect(mode_picker == null);
    }
    clear();
    composer_text = wide("/plan");
    sendChatPrompt();
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    try std.testing.expect(mode_picker == null);
}
test "delivery: pending settings preserve the draft and outbox" {
    clear();
    defer clear();
    const draft = std.unicode.utf8ToUtf16LeStringLiteral("Next message");
    composer_text = draft;
    test_settings_pending = true;
    sendChatPrompt();
    try std.testing.expectEqualSlices(u16, draft, composer_text);
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 0), read_marks);
    try std.testing.expect(!g_chat_draft_dirty);
    test_settings_pending = false;
    sendChatPrompt();
    try std.testing.expectEqual(@as(usize, 0), composer_text.len);
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
}
test "delivery: IGSH-1655 only terminal tabs get an Alt+C hint after a dialog command" {
    defer clear();
    const command = std.unicode.utf8ToUtf16LeStringLiteral("/settings");
    for ([_][]const u8{ "live-test", "term-test" }, 0..) |session, index| {
        clear();
        @memcpy(shells[0].tmux_session[0..session.len], session);
        shells[0].tmux_session_len = @intCast(session.len);
        composer_text = command;
        @memcpy(g_chat_ac_dialog_command[0..command.len], command);
        g_chat_ac_dialog_len = command.len;
        sendChatPrompt();
        try std.testing.expectEqual(index, terminal_notices);
        try std.testing.expectEqual(@as(usize, 0), composer_text.len);
        try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    }
}
test "delivery: IGSH-1063 Other keeps the typed answer until provider progress without an ordinary outbox message" {
    defer clear();
    shells[0].chat_question_other = true;
    composer_text = std.unicode.utf8ToUtf16LeStringLiteral("Purple");
    sendChatPrompt();
    try std.testing.expectEqual(@as(usize, 1), question_sends);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Purple"), question_text);
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Purple"), composer_text);
    sendChatPrompt();
    try std.testing.expectEqual(@as(usize, 1), question_sends);
    chatQuestionOtherFinish(0);
    try std.testing.expectEqual(@as(usize, 0), composer_text.len);
    shells[0].chat_question_other = true;
    composer_text = std.unicode.utf8ToUtf16LeStringLiteral("Orange");
    sendChatPrompt();
    composer_text = std.unicode.utf8ToUtf16LeStringLiteral("next draft");
    chatQuestionOtherFinish(0);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("next draft"), composer_text);
    shells[0].chat_question_other = true;
    question_send_ok = false;
    sendChatPrompt();
    try std.testing.expect(!shells[0].chat_question_other_sent);
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("next draft"), composer_text);
}
test "delivery: IGSH-1102 confirming one source message never confirms its timestamp peer" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("yes");
    try enqueue(text, .delivered);
    transcript(text, 2000);
    g_chat_blocks[0].message_id = 1;
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expect(chatEchoBlockConfirmed(text, g_chat_blocks[0]));
    var peer = g_chat_blocks[0];
    peer.message_id = 2;
    try std.testing.expect(!chatEchoBlockConfirmed(text, peer));
}
test "delivery: IGSH-1102 same-millisecond accepted messages clear without retransmission" {
    defer clear();
    const texts = [_][]const u16{
        std.unicode.utf8ToUtf16LeStringLiteral("Live request 1 part 1"),
        std.unicode.utf8ToUtf16LeStringLiteral("Live request 1 part 2"),
        std.unicode.utf8ToUtf16LeStringLiteral("Live request 1 part 3"),
    };
    for (texts) |text| try enqueue(text, .delivered);
    for (g_chat_outbox.items) |*entry| entry.channel_sent = true;
    for (texts, 0..) |text, i| {
        const start = history_entry.history.text.items.len;
        try history_entry.history.text.appendSlice(std.heap.page_allocator, text);
        try history_entry.history.blocks.append(std.heap.page_allocator, .{ .role = .user, .start = start, .len = text.len, .stamp_ms = 2000, .message_id = i + 1 });
    }
    history_entry.history.revision += 1;
    chatTmuxSettle();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try reload();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 0), channel_starts + writes + enters);
}
test "delivery: IGSH-1102 repeated intent needs distinct source messages even at equal timestamps" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("yes");
    try enqueue(text, .delivered);
    try enqueue(text, .delivered);
    for (g_chat_outbox.items) |*entry| entry.channel_sent = true;
    try history_entry.history.text.appendSlice(std.heap.page_allocator, text);
    try history_entry.history.blocks.append(std.heap.page_allocator, .{ .role = .user, .start = 0, .len = text.len, .stamp_ms = 2000, .message_id = 1 });
    history_entry.history.revision += 1;
    chatTmuxSettle();
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    history_entry.history.revision += 1;
    chatTmuxSettle();
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    try history_entry.history.blocks.append(std.heap.page_allocator, .{ .role = .user, .start = 0, .len = text.len, .stamp_ms = 2000, .message_id = 2 });
    history_entry.history.revision += 1;
    chatTmuxSettle();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 0), channel_starts + writes + enters);
}
test "delivery: IGSH-1102 distinct intents merged into one source message both confirm" {
    defer clear();
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("first request"), .delivered);
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("second request"), .delivered);
    for (g_chat_outbox.items) |*entry| entry.channel_sent = true;
    const merged = std.unicode.utf8ToUtf16LeStringLiteral("first request\\nsecond request");
    try history_entry.history.text.appendSlice(std.heap.page_allocator, merged);
    try history_entry.history.blocks.append(std.heap.page_allocator, .{ .role = .user, .start = 0, .len = merged.len, .stamp_ms = 2000, .message_id = 1 });
    history_entry.history.revision += 1;
    chatTmuxSettle();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 0), channel_starts + writes + enters);
}
test "delivery: IGSH-1102 restart preserves equal-timestamp anchor and rejects backfill" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("yes");
    transcript(text, 2000);
    g_chat_blocks[0].message_id = 2;
    try enqueue(text, .delivered);
    g_chat_outbox.items[0].anchor.after_ms = 2000;
    if (@hasField(chat_echo.Anchor, "after_id")) g_chat_outbox.items[0].anchor.after_id = 2;
    try std.testing.expect(saveChatOutbox());
    try reload();
    g_chat_blocks[0].message_id = 1;
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    g_chat_blocks[0].message_id = 2;
    g_chat_blocks[1] = .{ .role = .user, .start = 0, .len = text.len, .stamp_ms = 2000, .message_id = 3 };
    g_chat_block_count = 2;
    g_chat_last_hash +%= 1;
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 0), channel_starts + writes + enters);
}
test "delivery: IGSH-442 busy channel waits past both budgets without retransmission then confirms" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("please check the build");
    try enqueue(text, .delivered);
    g_chat_outbox.items[0].channel_sent = true;
    g_chat_outbox.items[0].channel_sent_ms = 2000;
    for ([_]bool{ false, true }) |screen_busy| {
        shells[0].activity = if (screen_busy) .idle else .active;
        g_chat_screen_working = screen_busy;
        for ([_]i64{ 2000, 12_000, 22_000, 600_000 }) |now_ms| {
            fake_now_ms = now_ms;
            history_entry.loaded_ms = now_ms;
            chatTmuxSettle();
            try std.testing.expectEqual(ChatEchoState.delivered, g_chat_outbox.items[0].state);
            try std.testing.expect(g_chat_outbox.items[0].delivery_watch.busy_seen);
            try std.testing.expect(!g_chat_outbox.items[0].channel_pending);
            try std.testing.expectEqual(@as(usize, 0), channel_starts + writes + enters);
        }
    }
    try history_entry.history.text.appendSlice(std.heap.page_allocator, text);
    try history_entry.history.blocks.append(std.heap.page_allocator, .{ .role = .user, .start = 0, .len = text.len, .stamp_ms = 2000 });
    history_entry.history.revision += 1;
    chatTmuxSettle();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 1), g_chat_confirmed.items.len);
    try std.testing.expectEqual(@as(usize, 0), channel_starts + writes + enters);
}
test "delivery: IGSH-969 exact acceptance receipt does not accept the next queued message" {
    defer clear();
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("first message"), .delivered);
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("next message"), .delivered);
    for (g_chat_outbox.items) |*entry| entry.channel_sent = true;
    shells[0].activity = .active;
    try history_entry.history.rows.appendSlice(std.heap.page_allocator,
        "{\\"role\\":\\"assistant\\",\\"text\\":\\"\\",\\"timestamp\\":\\"1970-01-01T00:00:02Z\\",\\"settlement\\":{\\"operation\\":\\"enqueue\\",\\"content\\":\\"first message\\"}}\\n" ++
        "{\\"role\\":\\"assistant\\",\\"text\\":\\"\\",\\"timestamp\\":\\"1970-01-01T00:00:02Z\\",\\"settlement\\":{\\"operation\\":\\"enqueue\\",\\"content\\":\\"next message\\"}}\\n" ++
        "{\\"role\\":\\"assistant\\",\\"text\\":\\"\\",\\"timestamp\\":\\"1970-01-01T00:00:03Z\\",\\"settlement\\":{\\"operation\\":\\"remove\\",\\"content\\":\\"first message\\"}}\\n");
    chatTmuxSettle();
    try std.testing.expectEqual(@as(usize, 2), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(i64, 3000), g_chat_outbox.items[0].delivery_watch.removed_ms);
    try std.testing.expect(!g_chat_outbox.items[0].transcript_queued);
    try std.testing.expectEqual(@as(i64, 0), g_chat_outbox.items[1].delivery_watch.removed_ms);
    try std.testing.expect(g_chat_outbox.items[1].transcript_queued);
    try std.testing.expectEqual(@as(usize, 0), channel_starts + writes + enters);
}
test "delivery: IGSH-442 channel idle settlement requires grace and fresh transcript without retyping" {
    defer clear();
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("please check the build"), .delivered);
    g_chat_outbox.items[0].channel_sent = true;
    shells[0].activity = .active;
    chatTmuxSettle();
    shells[0].activity = .idle;
    fake_now_ms = 600_000;
    chatTmuxSettle();
    fake_now_ms = 619_999;
    history_entry.loaded_ms = 620_000;
    chatTmuxSettle();
    try std.testing.expectEqual(ChatEchoState.delivered, g_chat_outbox.items[0].state);
    fake_now_ms = 620_000;
    history_entry.loaded_ms = 619_999;
    chatTmuxSettle();
    try std.testing.expectEqual(ChatEchoState.delivered, g_chat_outbox.items[0].state);
    history_entry.loaded_ms = 620_000;
    chatTmuxSettle();
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(g_chat_outbox.items[0].write_started);
    chatTmuxSettle();
    try std.testing.expectEqual(@as(usize, 0), channel_starts + writes + enters);
}
test "delivery: background queued evidence survives strict unknown dequeue and late evidence restores status" {
    defer clear();
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("please check the build"), .delivered);
    g_chat_outbox.items[0].channel_sent = true;
    g_chat_outbox.items[0].channel_sent_ms = 2000;
    g_chat_outbox.items[0].channel_retries = 1;
    fake_now_ms = 600000;
    history_entry.history.start = 500;
    try history_entry.history.rows.appendSlice(std.heap.page_allocator,
        "{\\"role\\":\\"assistant\\",\\"text\\":\\"\\",\\"timestamp\\":\\"1970-01-01T00:00:02Z\\",\\"settlement\\":{\\"operation\\":\\"enqueue\\",\\"content\\":\\"please check the build\\"}}\\n" ++
        "{\\"role\\":\\"assistant\\",\\"text\\":\\"\\",\\"timestamp\\":\\"1970-01-01T00:00:03Z\\",\\"settlement\\":{\\"operation\\":\\"dequeue\\",\\"content\\":\\"\\"}}\\n");
    chatTmuxSettle();
    try std.testing.expectEqual(ChatEchoState.delivered, g_chat_outbox.items[0].state);
    try std.testing.expect(g_chat_outbox.items[0].transcript_queued);
    try std.testing.expectEqual(@as(usize, 0), channel_starts + writes);
    try std.testing.expect(delivery_polls > 0);
    g_chat_outbox.items[0].state = .not_sent;
    chatTmuxSettle();
    try std.testing.expectEqual(ChatEchoState.delivered, g_chat_outbox.items[0].state);
}
test "delivery: channel transcript retirement retains one-to-one repeat assignment in background" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("please check the build");
    try enqueue(text, .delivered);
    try enqueue(text, .delivered);
    for (g_chat_outbox.items) |*entry| { entry.channel_sent = true; entry.channel_sent_ms = 2000; }
    try history_entry.history.text.appendSlice(std.heap.page_allocator, text);
    try history_entry.history.blocks.append(std.heap.page_allocator, .{ .role = .user, .start = 0, .len = text.len, .stamp_ms = 2000 });
    chatTmuxSettle();
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 1), g_chat_confirmed.items.len);
    chatTmuxSettle();
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 0), channel_starts + writes);
}
test "delivery: busy then idle, restart queued, type once, transcript replaces pending" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral(" https://screencast2.com/a3CKb.png ");
    try enqueue(text, .queued);
    try std.testing.expect(saveChatOutbox());
    try reload();
    shells[0].activity = .active;
    try std.testing.expect(chatOutboxTrySendEntry(0, 0));
    try std.testing.expectEqual(@as(usize, 1), writes);
    shells[0].activity = .idle;
    try std.testing.expect(!chatOutboxTrySendEntry(0, 0));
    try std.testing.expectEqual(@as(usize, 1), writes);
    try std.testing.expect(!chatOutboxTrySendEntry(0, 0));
    try reload(); // restart while send verification is still running
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(!chatOutboxTrySendEntry(0, 0));
    transcript(std.unicode.utf8ToUtf16LeStringLiteral("https://screencast2.com/a3CKb.png"), 2000);
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try reload();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 1), writes);
}
test "delivery: persistence failure writes nothing; partial failure cannot retype" {
    defer clear();
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("a prompt"), .queued);
    persist_ok = false;
    try std.testing.expect(!chatOutboxTrySendEntry(0, 0));
    try std.testing.expectEqual(@as(usize, 0), writes);
    persist_ok = true;
    paste_ok = false;
    try std.testing.expect(!chatOutboxTrySendEntry(0, 0));
    try std.testing.expect(!chatOutboxTrySendEntry(0, 0));
    try reload();
    try std.testing.expect(!chatOutboxTrySendEntry(0, 0));
    try std.testing.expectEqual(@as(usize, 1), writes);
}
test "delivery: repeats survive old history, even if an untyped queue has a newer matching turn" {
    defer clear();
    const yes = std.unicode.utf8ToUtf16LeStringLiteral("yes");
    try enqueue(yes, .delivered);
    try enqueue(yes, .queued);
    try enqueue(yes, .not_sent);
    g_chat_verify_echo_id = g_chat_outbox.items[2].id;
    transcript(yes, 100); // older than after_ms and sent_ms
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 3), g_chat_outbox.items.len);
    try std.testing.expect(g_chat_verify_echo_id != 0);
    try std.testing.expectEqual(@as(usize, 0), g_chat_confirmed.items.len);
    try std.testing.expect(saveChatOutbox());
    try reload();
    try std.testing.expectEqual(@as(usize, 3), g_chat_outbox.items.len);
    transcript(yes, 2000);
    chatEchoMatchActive(); // Only the oldest actually written intent confirms.
    try std.testing.expectEqual(@as(usize, 2), g_chat_outbox.items.len);
    try std.testing.expectEqual(ChatEchoState.queued, g_chat_outbox.items[0].state);
    try std.testing.expectEqual(@as(usize, 0), writes);
}
test "delivery: repeats in an offline queue cannot be confirmed before typing" {
    defer clear();
    const yes = std.unicode.utf8ToUtf16LeStringLiteral("yes");
    try enqueue(yes, .queued);
    transcript(yes, 2000); // A newer external user turn still cannot consume unsent intent.
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 0), writes);
}
test "delivery: legacy offline queues survive upgrade and uncertain writes never auto-retry" {
    defer clear();
    const legacy = "{\\\"version\\\":1,\\\"queues\\\":[{\\\"key\\\":\\\"test\\\",\\\"messages\\\":[{\\\"t\\\":\\\"old uncertain\\\",\\\"s\\\":2},{\\\"t\\\":\\\"queued\\\",\\\"s\\\":0}]}]}";
    chatOutboxParseJson(&g_chat_outbox, std.heap.page_allocator, legacy);
    try std.testing.expectEqual(@as(usize, 2), g_chat_outbox.items.len);
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(g_chat_outbox.items[0].write_started);
    try std.testing.expectEqual(ChatEchoState.queued, g_chat_outbox.items[1].state);
    try std.testing.expect(!g_chat_outbox.items[1].write_started);
    try std.testing.expectEqual(@as(usize, 0), writes);
}
test "delivery: aged unconfirmed messages remain recoverable without transcript access and after restart" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("not in transcript");
    try enqueue(text, .delivered);
    try enqueue(text, .queued);
    fake_now_ms = 601500;
    fake_loaded_ms = 1500;
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 2), g_chat_outbox.items.len);
    fake_loaded_ms = 1501;
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 2), g_chat_outbox.items.len);
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(!g_chat_outbox.items[0].write_started);
    try std.testing.expect(g_chat_outbox.items[0].retryable);
    try reload();
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(!chatOutboxTrySendEntry(0, 0));
    try std.testing.expectEqual(@as(usize, 0), writes);
}
test "delivery: unchanged refreshes cache reconciliation, revision and expiry changes still run" {
    defer clear();
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("not represented"), .queued);
    transcript(std.unicode.utf8ToUtf16LeStringLiteral("another prompt"), 2000);
    const before = reconcile_passes;
    for (0..1000) |_| chatEchoMatchActive();
    try std.testing.expectEqual(before + 1, reconcile_passes);
    g_chat_last_hash +%= 1;
    chatEchoMatchActive();
    try std.testing.expectEqual(before + 2, reconcile_passes);
    g_chat_outbox_revision +%= 1;
    chatEchoMatchActive();
    try std.testing.expectEqual(before + 3, reconcile_passes);
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
}
fn setFacts(rows: []const u8) !void {
    history_entry.history.rows.clearRetainingCapacity();
    try history_entry.history.rows.appendSlice(std.heap.page_allocator, rows);
    g_chat_last_hash +%= 1;
}
test "delivery: refused real slash command is retryable and a later matching block still confirms" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("/hormozi-skills:audit-offer can you use this also to review my own offer");
    try enqueue(text, .delivered);
    try setFacts("{\\"role\\":\\"assistant\\",\\"text\\":\\"\\",\\"timestamp\\":\\"2026-10-13T11:06:59.442Z\\",\\"settlement\\":{\\"operation\\":\\"rejected\\",\\"content\\":\\"Unknown command: /hormozi-skills:audit-offer\\"}}\\n");
    chatEchoMatchActive();
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(!g_chat_outbox.items[0].write_started);
    try std.testing.expect(g_chat_outbox.items[0].retryable);
    try reload();
    try std.testing.expect(g_chat_outbox.items[0].retryable);
    transcript(text, 2000);
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
}
test "delivery: busy idle grace needs a fresh transcript, matches win, idle alone does not settle" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("also review the offer");
    try enqueue(text, .delivered);
    fake_loaded_ms = fake_now_ms;
    chatEchoMatchActive();
    fake_now_ms = 5000;
    chatEchoMatchActive();
    try std.testing.expectEqual(ChatEchoState.delivered, g_chat_outbox.items[0].state);
    shells[0].activity = .active;
    chatEchoMatchActive();
    shells[0].activity = .idle;
    fake_now_ms = 6000;
    chatEchoMatchActive();
    fake_now_ms = 25999;
    fake_loaded_ms = fake_now_ms;
    chatEchoMatchActive();
    try std.testing.expectEqual(ChatEchoState.delivered, g_chat_outbox.items[0].state);
    fake_now_ms = 26000;
    chatEchoMatchActive();
    try std.testing.expectEqual(ChatEchoState.delivered, g_chat_outbox.items[0].state);
    fake_loaded_ms = fake_now_ms;
    chatEchoMatchActive();
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(!g_chat_outbox.items[0].write_started);
    transcript(text, 27000);
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
}
test "delivery: queue removal settles after transcript grace, persists and explicitly retries once" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("also review the offer");
    try enqueue(text, .delivered);
    try setFacts("{\\"role\\":\\"assistant\\",\\"text\\":\\"\\",\\"timestamp\\":\\"2026-10-13T11:06:22.591Z\\",\\"settlement\\":{\\"operation\\":\\"enqueue\\",\\"content\\":\\"also review the offer\\"}}\\n{\\"role\\":\\"assistant\\",\\"text\\":\\"\\",\\"timestamp\\":\\"2026-10-13T11:06:59.442Z\\",\\"settlement\\":{\\"operation\\":\\"remove\\",\\"content\\":\\"also review the offer\\"}}\\n");
    chatEchoMatchActive();
    try std.testing.expectEqual(ChatEchoState.delivered, g_chat_outbox.items[0].state);
    fake_now_ms = 21999;
    fake_loaded_ms = fake_now_ms;
    chatEchoMatchActive();
    try std.testing.expectEqual(ChatEchoState.delivered, g_chat_outbox.items[0].state);
    fake_now_ms = 22000;
    fake_loaded_ms = fake_now_ms;
    chatEchoMatchActive();
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(!g_chat_outbox.items[0].write_started);
    try reload();
    try std.testing.expect(g_chat_outbox.items[0].retryable);
    chatEchoRetryAllForActive();
    try std.testing.expectEqual(@as(usize, 1), writes);
    try std.testing.expect(!g_chat_outbox.items[0].retryable);
    try std.testing.expect(g_chat_outbox.items[0].write_started);
    try std.testing.expect(!chatOutboxTrySendEntry(0, 0));
}
test "delivery: midturn queued attachment and merged normal block win over refusal removal and turn expiry" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("also review the offer");
    try enqueue(text, .delivered);
    shells[0].activity = .active;
    chatEchoMatchActive();
    try history_entry.history.apply(std.heap.page_allocator, "@mp\\t1\\thistory\\tok\\tsid\\t0\\t100\\t9\\t0\\tclaude\\t-\\n{\\"role\\":\\"assistant\\",\\"text\\":\\"\\",\\"timestamp\\":\\"2026-10-13T11:06:22.591Z\\",\\"settlement\\":{\\"operation\\":\\"enqueue\\",\\"content\\":\\"also review the offer\\"}}\\n{\\"role\\":\\"assistant\\",\\"text\\":\\"\\",\\"timestamp\\":\\"2026-10-13T11:06:59.442Z\\",\\"settlement\\":{\\"operation\\":\\"remove\\",\\"content\\":\\"also review the offer\\"}}\\n{\\"role\\":\\"user\\",\\"text\\":\\"also review the offer\\",\\"timestamp\\":\\"2026-10-13T11:06:59.443Z\\"}\\n@@MP_END@@\\n", 1, chat_transcript.Identity.init(1, 0, false, "sid", ""));
    const h = &history_entry.history;
    g_chat_capture = h.text.items;
    g_chat_last_len = h.text.items.len;
    @memcpy(g_chat_blocks[0..h.blocks.items.len], h.blocks.items);
    g_chat_block_count = h.blocks.items.len;
    g_chat_last_hash +%= 1;
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 1), g_chat_confirmed.items.len);
    shells[0].activity = .idle;
    fake_now_ms = 30000;
    fake_loaded_ms = fake_now_ms;
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try enqueue(text, .delivered);
    g_chat_outbox.items[0].anchor.after_ms = 1000;
    transcript(std.unicode.utf8ToUtf16LeStringLiteral("start here\\n\\nalso review the offer"), 40000);
    fake_now_ms = 700000;
    fake_loaded_ms = fake_now_ms;
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
}
test "delivery: legacy delivered entries without a timestamp cannot stay queued forever" {
    defer clear();
    const legacy = "{\\\"version\\\":1,\\\"queues\\\":[{\\\"key\\\":\\\"test\\\",\\\"messages\\\":[{\\\"t\\\":\\\"legacy stuck\\\",\\\"s\\\":3}]}]}";
    chatOutboxParseJson(&g_chat_outbox, std.heap.page_allocator, legacy);
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(g_chat_outbox.items[0].retryable);
    transcript(std.unicode.utf8ToUtf16LeStringLiteral("legacy stuck"), 100);
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
}
test "delivery: restored delivered outbox preserves its deadline and keeps late matching" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("older persisted message");
    try enqueue(text, .delivered);
    try std.testing.expect(saveChatOutbox());
    fake_now_ms = 601499;
    try reload();
    try std.testing.expectEqual(ChatEchoState.delivered, g_chat_outbox.items[0].state);
    fake_now_ms += 600000;
    chatOutboxTick();
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(g_chat_outbox.items[0].write_started);
    try std.testing.expect(g_chat_outbox.items[0].retryable);
    transcript(text, 2000);
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
}
test "delivery: cache round trip preserves timestamp and matches beyond 256 blocks, not injected rows" {
    defer clear();
    const a = std.testing.allocator;
    const key = chat_transcript.Identity.init(1, 0, false, "sid", "/repo");
    var h = chat_history.History{};
    defer h.deinit(a);
    const row = "{\\\"role\\\":\\\"user\\\",\\\"timestamp\\\":\\\"2026-10-12T18:00:00Z\\\",\\\"text\\\":\\\"hello  world\\\"}\\n";
    const wire = "@mp\\t7\\thistory\\tok\\tsid\\t0\\t100\\t4\\t0\\tclaude\\t-\\n" ++ row ++ "@@MP_END@@\\n";
    try h.apply(a, wire, 7, key);
    const disk = try h.encode(a, key);
    defer a.free(disk);
    var restored = try chat_history.History.decode(a, disk, key);
    defer restored.deinit(a);
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("hello\\nworld "), .not_sent);
    g_chat_outbox.items[0].anchor = .{ .after_ms = chat_echo.stampMs("2026-10-12T17:59:00Z") };
    g_chat_capture = restored.text.items;
    g_chat_last_len = restored.text.items.len;
    for (g_chat_blocks[0..299]) |*b| b.* = .{ .role = .injected, .start = 0, .len = restored.text.items.len, .stamp_ms = restored.blocks.items[0].stamp_ms };
    g_chat_block_count = 299;
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    g_chat_blocks[299] = restored.blocks.items[0];
    g_chat_block_count = 300;
    g_chat_last_hash +%= 1;
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 1), g_chat_confirmed.items.len);
}
test "delivery: IGSH-442 Remove persists only the selected message and rolls back failed saves" {
    defer clear();
    const one = std.unicode.utf8ToUtf16LeStringLiteral("remove me");
    const two = std.unicode.utf8ToUtf16LeStringLiteral("keep me");
    try enqueue(one, .not_sent);
    try enqueue(two, .not_sent);
    const id = g_chat_outbox.items[0].id;
    persist_ok = false;
    chatEchoRemove(id);
    try std.testing.expectEqual(@as(usize, 2), g_chat_outbox.items.len);
    persist_ok = true;
    chatEchoRemove(id);
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    try reload();
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    try std.testing.expectEqualSlices(u16, two, g_chat_outbox.items[0].text);
}
test "delivery: IGSH-1810 queued live removal waits for server confirmation and cannot recall received input" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("cancel only this waiting message");
    try enqueue(text, .queued);
    const id = g_chat_outbox.items[0].id;
    g_chat_outbox.items[0].message_v1 = true;
    g_chat_outbox.items[0].write_started = true;
    @memcpy(g_chat_outbox.items[0].message_phase[0..6], "queued");
    @memcpy(g_chat_outbox.items[0].message_sid[0..1], "s");
    chatEchoRemove(id);
    try std.testing.expectEqual(@as(usize, 1), channel_starts);
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    try std.testing.expect(g_chat_outbox.items[0].channel_pending);
    chatEchoRemove(id);
    try std.testing.expectEqual(@as(usize, 1), channel_starts);
    g_chat_outbox.items[0].channel_pending = false;
    @memcpy(g_chat_outbox.items[0].message_phase[0..8], "accepted");
    chatEchoRemove(id);
    try std.testing.expectEqual(@as(usize, 1), channel_starts);
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 0), writes + enters);
}
test "delivery: IGSH-1859 Remove clears a Not sent message tied to an older session" {
    defer clear();
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("sent while a helper held the chat"), .not_sent);
    const id = g_chat_outbox.items[0].id;
    g_chat_outbox.items[0].message_v1 = true;
    g_chat_outbox.items[0].write_started = true;
    @memcpy(g_chat_outbox.items[0].message_phase[0..6], "queued");
    @memcpy(g_chat_outbox.items[0].message_sid[0..6], "helper");
    chatEchoRemove(id);
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 0), channel_starts + writes + enters);
}
test "delivery: IGSH-1859 a message the agent merged into a later turn stops showing Not sent" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("https://example.com/b.png  too much text everywhere ");
    const merged = std.unicode.utf8ToUtf16LeStringLiteral("/reduce-first https://example.com/a.png fix this page\\n\\nhttps://example.com/b.png  too much text everywhere \\n\\nhttps://example.com/c.png one more note");
    try enqueue(text, .not_sent);
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("https://example.com/c.png one more note"), .not_sent);
    for (g_chat_outbox.items) |*entry| {
        entry.anchor = .{ .sent_ms = 100_000 };
        entry.message_v1 = true;
        entry.write_started = true;
        entry.channel_sent = true;
        entry.retryable = true;
        @memcpy(entry.message_phase[0..6], "queued");
    }
    transcript(merged, 1000);
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 2), g_chat_outbox.items.len);
    transcript(merged, 160_000);
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 2), g_chat_confirmed.items.len);
    try std.testing.expectEqual(@as(usize, 0), channel_starts + writes + enters);
}
test "delivery: IGSH-1828 Cancel and Delete take back a handed-off waiting message" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("take this one back");
    try enqueue(text, .queued);
    const id = g_chat_outbox.items[0].id;
    g_chat_outbox.items[0].message_v1 = true;
    g_chat_outbox.items[0].write_started = true;
    @memcpy(g_chat_outbox.items[0].message_phase[0..4], "sent");
    @memcpy(g_chat_outbox.items[0].message_sid[0..1], "s");
    chatEchoRemove(id);
    try std.testing.expectEqual(@as(usize, 1), channel_starts);
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    try std.testing.expect(g_chat_outbox.items[0].channel_pending);
    g_chat_outbox.items[0].channel_pending = false;
    @memcpy(g_chat_outbox.items[0].message_phase[0..8], "accepted");
    chatEchoRemove(id);
    try std.testing.expectEqual(@as(usize, 1), channel_starts);
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
}
test "delivery: IGSH-442 Send again never writes a transcript-confirmed message" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("already arrived");
    try enqueue(text, .not_sent);
    transcript(text, 2000);
    input_held = true;
    chatEchoSendAgain(g_chat_outbox.items[0].id);
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 0), writes);
    try std.testing.expectEqual(@as(usize, 0), enters);
}
test "delivery: IGSH-442 Send again writes nothing for queued transcript evidence" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("queued task");
    try enqueue(text, .not_sent);
    try setFacts("{\\"role\\":\\"assistant\\",\\"text\\":\\"\\",\\"timestamp\\":\\"1970-01-01T00:00:02Z\\",\\"settlement\\":{\\"operation\\":\\"enqueue\\",\\"content\\":\\"queued task\\"}}\\n");
    chatEchoSendAgain(g_chat_outbox.items[0].id);
    try std.testing.expectEqual(ChatEchoState.delivered, g_chat_outbox.items[0].state);
    try std.testing.expectEqual(@as(usize, 0), writes);
    try std.testing.expectEqual(@as(usize, 0), enters);
}
test "delivery: IGSH-442 Send again presses Enter only for held text" {
    defer clear();
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("held prompt"), .not_sent);
    input_held = true;
    chatEchoSendAgain(g_chat_outbox.items[0].id);
    try std.testing.expectEqual(@as(usize, 0), writes);
    try std.testing.expectEqual(@as(usize, 1), enters);
    try std.testing.expectEqual(ChatEchoState.sending, g_chat_outbox.items[0].state);
    try std.testing.expect(g_chat_outbox.items[0].write_started);
}
test "delivery: IGSH-442 Send again requeues missing text through the normal outbox" {
    defer clear();
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("missing prompt"), .not_sent);
    g_chat_outbox.items[0].retryable = true;
    g_chat_outbox.items[0].delivery_watch.busy_seen = true;
    g_chat_outbox.items[0].left_box_ms = 1;
    shells[0].activity = .active;
    input_idle = false;
    chatEchoSendAgain(g_chat_outbox.items[0].id);
    try std.testing.expectEqual(ChatEchoState.queued, g_chat_outbox.items[0].state);
    try std.testing.expect(!g_chat_outbox.items[0].write_started);
    try std.testing.expect(g_chat_outbox.items[0].retryable);
    try std.testing.expect(!g_chat_outbox.items[0].delivery_watch.busy_seen);
    try std.testing.expectEqual(@as(u64, 0), g_chat_outbox.items[0].left_box_ms);
    shells[0].activity = .idle;
    input_idle = true;
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), writes);
}

test "ISSUE-501 reattach flushes FIFO exactly once through confirmed outbox states" {
    defer clear();
    const first = std.unicode.utf8ToUtf16LeStringLiteral("first offline request");
    const second = std.unicode.utf8ToUtf16LeStringLiteral("second offline request");
    try enqueue(first, .queued);
    try enqueue(second, .queued);
    shells[0].disconnected = true;
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 0), writes);
    sshReconnectOk(0);
    try std.testing.expectEqual(@as(usize, 0), writes);
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), writes);
    sshReconnectOk(0);
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), writes);
    g_chat_outbox.items[0].state = .delivered;
    g_chat_verify_echo_id = 0;
    transcript(first, 2000);
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 2), writes);
    try std.testing.expectEqualSlices(u16, &.{ 'f', 's' }, written_order[0..writes]);
    g_chat_outbox.items[0].state = .delivered;
    g_chat_verify_echo_id = 0;
    transcript(second, 3000);
    chatOutboxTick();
    sshReconnectOk(0);
    try std.testing.expectEqual(@as(usize, 2), writes);
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
}
test "ISSUE-460 pending Chat View IDs equal the ordered outbox across save and reload" {
    defer clear();
    for ([_]ChatEchoState{ .queued, .delivered, .not_sent }) |state| {
        try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("pending request"), state);
    }
    try std.testing.expect(chatOutboxEnqueueInState(&g_chat_outbox, std.heap.page_allocator, "other", std.unicode.utf8ToUtf16LeStringLiteral("other session"), .queued));
    for (0..2) |_| {
        layoutPending();
        try std.testing.expectEqual(@as(usize, 3), g_chat_echo_layout_count);
        for (g_chat_outbox.items[0..3], g_chat_echo_layout_ids[0..g_chat_echo_layout_count]) |entry, id| {
            try std.testing.expectEqual(entry.id, id);
        }
        try std.testing.expectEqual(chat_echo.Label.sending, chat_echo.pendingLabel(.offline_queue, false));
        try std.testing.expect(saveChatOutbox());
        try reload();
    }
}
test "ISSUE-460 failed initial persistence never accepts or displays an undurable message" {
    defer clear();
    persist_ok = false;
    try std.testing.expectEqual(@as(?usize, null), chatEchoEnqueueForShell(0, std.unicode.utf8ToUtf16LeStringLiteral("unsaved request"), .queued));
    layoutPending();
    try std.testing.expectEqual(@as(usize, 0), g_chat_echo_layout_count);
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 0), writes + channel_starts);
}
test "ISSUE-460 IGSH-564 dim suggestion text no longer blocks channel typing" {
    defer clear();
    channel_enabled = true;
    input_idle = false;
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("waiting request"), .queued);
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), channel_starts);
    input_idle = true;
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), channel_starts);
}
test "IGSH-564 idle channel with a suggested reply in the input box still types the message" {
    defer clear();
    channel_enabled = true;
    shells[0].activity = .idle;
    input_idle = false;
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("send despite the suggestion"), .queued);
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), channel_starts);
    try std.testing.expectEqual(ChatEchoState.sending, g_chat_outbox.items[0].state);
    try std.testing.expect(g_chat_outbox.items[0].write_started);
}
test "IGSH-564 queued message older than ten minutes is still typed, never marked not sent" {
    defer clear();
    channel_enabled = true;
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("send the aged queued message"), .queued);
    fake_now_ms += 900_000;
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), channel_starts);
    try std.testing.expectEqual(ChatEchoState.sending, g_chat_outbox.items[0].state);
    try std.testing.expect(g_chat_outbox.items[0].write_started);
}
test "ISSUE-460 Send again preserves late matching anchors and persists its own deadline" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("late request");
    try enqueue(text, .not_sent);
    shells[0].activity = .active;
    input_idle = false;
    fake_now_ms = 700000;
    chatEchoSendAgain(g_chat_outbox.items[0].id);
    try std.testing.expectEqual(@as(i64, 1500), g_chat_outbox.items[0].anchor.sent_ms);
    const deadline = g_chat_outbox.items[0].expires_ms;
    try reload();
    try std.testing.expectEqual(deadline, g_chat_outbox.items[0].expires_ms);
    try std.testing.expectEqual(ChatEchoState.queued, g_chat_outbox.items[0].state);
    transcript(text, 2000);
    shells[0].activity = .idle;
    input_idle = true;
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 0), writes + channel_starts);
}
test "ISSUE-460 production reload retains unmatched sessions and does not overwrite malformed persistence" {
    defer clear();
    try std.testing.expect(chatOutboxEnqueueInState(&g_chat_outbox, std.heap.page_allocator, "missing", std.unicode.utf8ToUtf16LeStringLiteral("restored request"), .queued));
    try std.testing.expect(saveChatOutbox());
    try reload();
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    try std.testing.expectEqualStrings("missing", g_chat_outbox.items[0].key[0..g_chat_outbox.items[0].key_len]);
    std.heap.page_allocator.free(persisted.?);
    persisted = try std.heap.page_allocator.dupe(u8, "{invalid");
    try reload();
    try std.testing.expectEqualStrings("{invalid", persisted.?);
}
test "ISSUE-460 IGSH-564 queued intent survives repeated production reloads past its saved deadline" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("offline request");
    _ = chatEchoEnqueueForShell(0, text, .queued) orelse return error.EnqueueFailed;
    shells[0].disconnected = true;
    const deadline = g_chat_outbox.items[0].expires_ms;
    for ([_]i64{ 100000, 300000, deadline - 1, deadline, deadline + 900_000 }) |now_ms| {
        fake_now_ms = now_ms;
        try reload();
        chatOutboxTick();
        try std.testing.expectEqual(ChatEchoState.queued, g_chat_outbox.items[0].state);
        try std.testing.expectEqual(deadline, g_chat_outbox.items[0].expires_ms);
    }
    try std.testing.expectEqual(@as(usize, 0), writes + channel_starts);
    shells[0].disconnected = false;
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), writes);
    try std.testing.expectEqual(ChatEchoState.sending, g_chat_outbox.items[0].state);
    try std.testing.expectEqualSlices(u16, &.{'o'}, written_order[0..writes]);
}
test "ISSUE-460 queued evidence releases the next connected message into Claude buffer" {
    defer clear();
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("first request"), .delivered);
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("second request"), .queued);
    g_chat_outbox.items[0].transcript_queued = true;
    try std.testing.expect(chatOutboxTrySendEntry(0, 1));
    try std.testing.expectEqual(@as(usize, 1), writes + channel_starts);
    transcript(std.unicode.utf8ToUtf16LeStringLiteral("first request"), 2000);
    chatOutboxTick();
    try std.testing.expectEqualSlices(u16, &.{'s'}, written_order[0..writes]);
}
test "IGSH-564 steer busy tmux types before keys and targets the original session once" {
    defer clear();
    channel_enabled = true;
    shells[0].activity = .active;
    g_chat_screen_working = true;
    composer_text = std.unicode.utf8ToUtf16LeStringLiteral("steer this request");
    chatSteerPrompt();
    try std.testing.expectEqual(@as(usize, 1), channel_starts);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("steer this request"), g_chat_tmux_send_job.?.text);
    try std.testing.expectEqual(@as(usize, 0), composer_text.len);
    try std.testing.expectEqual(@as(usize, 0), tmux_steers + direct_steers);
    try std.testing.expect(g_chat_outbox.items[0].steer_pending);
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 0), tmux_steers + direct_steers);
    g_chat_tmux_send_job.?.finished.store(true, .release);
    active_shell = 99;
    chatTmuxSendFinish();
    try std.testing.expectEqual(ChatEchoState.delivered, g_chat_outbox.items[0].state);
    try std.testing.expect(!g_chat_outbox.items[0].steer_pending);
    try std.testing.expectEqual(@as(usize, 1), tmux_steers);
    try std.testing.expectEqual(ChatEchoState.delivered, state_at_steer.?);
    try std.testing.expectEqual(@as(u32, 0), steer_shell);
    chatTmuxSendFinish();
    active_shell = 0;
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), channel_starts);
    try std.testing.expectEqual(@as(usize, 1), tmux_steers);
    try std.testing.expectEqual(@as(usize, 0), writes + enters + direct_steers);
}
test "IGSH-564 steer empty composer needs no delivered entry on either transport" {
    defer clear();
    for ([_]bool{ true, false }) |channel| {
        channel_enabled = channel;
        chatSteerPrompt();
        try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    }
    try std.testing.expectEqual(@as(usize, 1), tmux_steers);
    try std.testing.expectEqual(@as(usize, 1), direct_steers);
    try std.testing.expectEqual(@as(usize, 0), channel_starts + writes + enters);
}
test "IGSH-564 steer direct input pastes and presses Enter before keys exactly once" {
    defer clear();
    shells[0].activity = .active;
    composer_text = std.unicode.utf8ToUtf16LeStringLiteral("direct steer");
    chatSteerPrompt();
    try std.testing.expectEqual(@as(usize, 1), writes);
    try std.testing.expectEqual(@as(usize, 1), enters);
    try std.testing.expectEqual(@as(usize, 1), writes_at_steer);
    try std.testing.expectEqual(@as(usize, 1), enters_at_steer);
    try std.testing.expectEqual(@as(usize, 1), direct_steers);
    try std.testing.expectEqual(@as(usize, 0), tmux_steers + channel_starts);
    try std.testing.expectEqual(@as(u32, 0), steer_shell);
    try std.testing.expect(!g_chat_outbox.items[0].steer_pending);
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), direct_steers);
}
test "IGSH-564 steer failed paste never presses keys and ordinary Enter does not steer" {
    defer clear();
    paste_ok = false;
    composer_text = std.unicode.utf8ToUtf16LeStringLiteral("failed steer");
    chatSteerPrompt();
    try std.testing.expectEqual(@as(usize, 0), enters + tmux_steers + direct_steers);
    clear();
    composer_text = std.unicode.utf8ToUtf16LeStringLiteral("ordinary send");
    sendChatPrompt();
    try std.testing.expectEqual(@as(usize, 1), read_marks);
    try std.testing.expectEqual(@as(usize, 1), writes);
    try std.testing.expectEqual(@as(usize, 1), enters);
    try std.testing.expectEqual(@as(usize, 0), tmux_steers + direct_steers);
}
test "IGSH-564 steer chord fires only for adjacent plain Ctrl X then Ctrl S" {
    var pending = false;
    try std.testing.expect(!chatSteerChord(&pending, 0x53, true, false, false, true));
    try std.testing.expect(!chatSteerChord(&pending, 0x58, true, false, false, true));
    try std.testing.expect(pending);
    for ([_]u32{ 0x11, 0xA2, 0xA3 }) |held| {
        try std.testing.expect(!chatSteerChord(&pending, held, true, false, false, true));
        try std.testing.expect(pending);
    }
    try std.testing.expect(chatSteerChord(&pending, 0x53, true, false, false, true));
    try std.testing.expect(!pending);
    try std.testing.expect(!chatSteerChord(&pending, 0x53, true, false, false, true));
}
test "IGSH-564 steer chord another key disarms without consuming normal editing" {
    for ([_]u32{ 0x41, 0x0D, 0x58 }) |other| {
        var pending = false;
        try std.testing.expect(!chatSteerChord(&pending, 0x58, true, false, false, true));
        try std.testing.expect(!chatSteerChord(&pending, other, true, false, false, true));
        try std.testing.expect(!pending);
        try std.testing.expect(!chatSteerChord(&pending, 0x53, true, false, false, true));
    }
    for (0..4) |case| {
        var pending = false;
        _ = chatSteerChord(&pending, 0x58, true, false, false, true);
        try std.testing.expect(!chatSteerChord(&pending, 0x53, case != 0, case == 1, case == 2, case != 3));
        try std.testing.expect(!pending);
    }
}
test "ISSUE-460 busy channel sends first immediately then confirms in order (IGSH-564)" {
    defer clear();
    channel_enabled = true;
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("first request"), .queued);
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("second request"), .queued);
    shells[0].activity = .active;
    g_chat_screen_working = true;
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), channel_starts);
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), channel_starts);
    g_chat_outbox.items[0].channel_pending = false;
    g_chat_outbox.items[0].state = .delivered;
    discardChannelJob();
    g_chat_outbox.items[0].transcript_queued = true;
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 2), channel_starts);
    transcript(std.unicode.utf8ToUtf16LeStringLiteral("first request"), 2000);
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 2), channel_starts);
}
test "ISSUE-460 IGSH-564 busy channel buffers second before any transcript and skips not sent" {
    defer clear();
    channel_enabled = true;
    shells[0].activity = .active;
    g_chat_screen_working = true;
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("first request"), .queued);
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("second request"), .queued);
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), channel_starts);
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), channel_starts);
    g_chat_outbox.items[0].channel_pending = false;
    g_chat_outbox.items[0].state = .delivered;
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), channel_starts);
    discardChannelJob();
    try std.testing.expect(!g_chat_outbox.items[0].transcript_queued);
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 2), channel_starts);
    try std.testing.expectEqual(@as(usize, 0), g_chat_block_count);
    try std.testing.expectEqual(ChatEchoState.delivered, g_chat_outbox.items[0].state);
    try std.testing.expectEqual(ChatEchoState.sending, g_chat_outbox.items[1].state);
    for ([_]bool{ false, true }, 0..) |written, attempt| {
        g_chat_outbox.items[0].state = .not_sent;
        g_chat_outbox.items[0].write_started = written;
        g_chat_outbox.items[1].state = .queued;
        g_chat_outbox.items[1].write_started = false;
        g_chat_outbox.items[1].channel_pending = false;
        discardChannelJob();
        chatOutboxTick();
        try std.testing.expectEqual(@as(usize, 3) + attempt, channel_starts);
        try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
        try std.testing.expectEqual(written, g_chat_outbox.items[0].write_started);
        try std.testing.expectEqual(ChatEchoState.sending, g_chat_outbox.items[1].state);
        try std.testing.expect(g_chat_outbox.items[1].channel_pending);
    }
}
test "ISSUE-460 IGSH-564 connected direct input buffers while busy and serializes typing" {
    defer clear();
    shells[0].activity = .active;
    g_chat_screen_working = true;
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("first request"), .queued);
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("second request"), .queued);
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), writes);
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), writes);
    g_chat_outbox.items[0].state = .delivered;
    g_chat_verify_echo_id = 0;
    shells[0].disconnected = true;
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), writes);
    shells[0].disconnected = false;
    chatOutboxTick();
    try std.testing.expectEqualSlices(u16, &.{ 'f', 's' }, written_order[0..writes]);
    try std.testing.expectEqual(@as(usize, 2), enters);
    try std.testing.expectEqual(@as(usize, 0), g_chat_block_count);
}
test "ISSUE-460 IGSH-564 offline queues and protected sends survive while unprotected sends expire" {
    defer clear();
    g_chat_active = false;
    defer g_chat_active = true;
    for ([_]ChatEchoState{ .queued, .sending, .delivered, .sending, .delivered }) |state| {
        try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("waiting request"), state);
    }
    g_chat_outbox.items[1].channel_pending = true;
    g_chat_outbox.items[2].transcript_queued = true;
    g_chat_verify_echo_id = g_chat_outbox.items[3].id;
    shells[0].activity = .active;
    shells[0].disconnected = true;
    fake_now_ms = 901500;
    chatOutboxTick();
    const expected = [_]ChatEchoState{ .queued, .sending, .delivered, .not_sent, .not_sent };
    for (g_chat_outbox.items, expected) |entry, state| {
        try std.testing.expectEqual(state, entry.state);
    }
    try std.testing.expect(!g_chat_outbox.items[0].write_started);
    try std.testing.expect(g_chat_outbox.items[1].channel_pending);
    try std.testing.expect(g_chat_outbox.items[2].transcript_queued);
    for (g_chat_outbox.items[3..]) |entry| {
        try std.testing.expect(chat_echo.pendingActions(entry.state).send_again);
        try std.testing.expect(entry.retryable);
        try std.testing.expect(!entry.transcript_queued);
    }
    try std.testing.expectEqual(@as(usize, 0), writes + channel_starts);
}
test "ISSUE-460 IGSH-564 restart keeps aged queues sendable and FIFO without duplicate writes" {
    defer clear();
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("first request"), .queued);
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("second request"), .queued);
    try std.testing.expect(saveChatOutbox());
    shells[0].disconnected = true;
    fake_now_ms = 901500;
    for (0..2) |_| {
        try reload();
        chatOutboxTick();
        try std.testing.expectEqual(@as(usize, 2), g_chat_outbox.items.len);
        try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("first request"), g_chat_outbox.items[0].text);
        try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("second request"), g_chat_outbox.items[1].text);
        for (g_chat_outbox.items) |entry| try std.testing.expectEqual(ChatEchoState.queued, entry.state);
        try std.testing.expectEqual(@as(usize, 0), writes + channel_starts);
    }
    shells[0].disconnected = false;
    chatOutboxTick();
    try std.testing.expectEqual(ChatEchoState.sending, g_chat_outbox.items[0].state);
    try std.testing.expectEqual(ChatEchoState.queued, g_chat_outbox.items[1].state);
    try std.testing.expectEqual(@as(usize, 1), writes);
    try reload();
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expectEqual(ChatEchoState.queued, g_chat_outbox.items[1].state);
    chatOutboxTick();
    try std.testing.expectEqual(ChatEchoState.sending, g_chat_outbox.items[1].state);
    try std.testing.expectEqual(@as(usize, 2), writes);
    chatOutboxTick();
    try std.testing.expectEqualSlices(u16, &.{ 'f', 's' }, written_order[0..writes]);
    try std.testing.expectEqual(@as(usize, 2), enters);
}
test "ISSUE-460 two messages buffer while busy and reach the session in order" {
    defer clear();
    const first = std.unicode.utf8ToUtf16LeStringLiteral("first queued request");
    const second = std.unicode.utf8ToUtf16LeStringLiteral("second queued request");
    try enqueue(first, .queued);
    try enqueue(second, .queued);
    shells[0].activity = .active;
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), writes);
    shells[0].activity = .idle;
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), writes);
    g_chat_outbox.items[0].state = .delivered;
    g_chat_verify_echo_id = 0;
    try std.testing.expect(chatOutboxTrySendEntry(0, 1));
    transcript(first, 2000);
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 2), writes);
    try std.testing.expectEqualSlices(u16, &.{ 'f', 's' }, written_order[0..writes]);
    transcript(second, 3000);
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
}
test "ISSUE-460 v2 persist restore preserves two queued intents and written evidence" {
    defer clear();
    const json = "{\\"version\\":2,\\"queues\\":[{\\"key\\":\\"test\\",\\"messages\\":[{\\"t\\":\\"first queued request\\",\\"s\\":0,\\"a\\":1792579520119,\\"w\\":1792579618161,\\"c\\":4,\\"n\\":1,\\"x\\":0,\\"r\\":0},{\\"t\\":\\"second queued request\\",\\"s\\":0,\\"a\\":1792579520119,\\"w\\":1792579618161,\\"c\\":4,\\"n\\":1,\\"x\\":0,\\"r\\":0}]},{\\"key\\":\\"tmux:1:projects\\",\\"messages\\":[{\\"t\\":\\"uncertain restored request\\",\\"s\\":2,\\"a\\":1792579520119,\\"w\\":1792579618161,\\"c\\":4,\\"n\\":1,\\"x\\":1,\\"r\\":1}]}]}";
    chatOutboxParseJson(&g_chat_outbox, std.heap.page_allocator, json);
    try std.testing.expect(saveChatOutbox());
    try reload();
    try std.testing.expect(g_chat_outbox.items[2].channel_sent);
    try std.testing.expectEqual(@as(u32, 4), g_chat_outbox.items[2].anchor.user_count);
    try std.testing.expect(g_chat_outbox.items[2].anchor.counted);
    try std.testing.expectEqual(@as(i64, 1792579520119), g_chat_outbox.items[2].anchor.after_ms);
    try std.testing.expectEqual(@as(i64, 1792579618161), g_chat_outbox.items[2].anchor.sent_ms);
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[2].state);
    try std.testing.expect(chat_echo.pendingActions(g_chat_outbox.items[2].state).send_again);
    shells[0].activity = .active;
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), writes);
    shells[0].activity = .idle;
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), writes);
    g_chat_outbox.items[0].state = .delivered;
    g_chat_verify_echo_id = 0;
    try std.testing.expect(chatOutboxTrySendEntry(0, 1));
    transcript(std.unicode.utf8ToUtf16LeStringLiteral("first queued request"), 1792579619000);
    chatOutboxTick();
    try std.testing.expectEqualSlices(u16, &.{ 'f', 's' }, written_order[0..writes]);
    transcript(std.unicode.utf8ToUtf16LeStringLiteral("second queued request"), 1792579620000);
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
}
test "ISSUE-460 unconfirmable in flight becomes failed even busy without transcript" {
    defer clear();
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("unconfirmed request"), .delivered);
    g_chat_outbox.items[0].channel_sent = true;
    shells[0].activity = .active;
    g_chat_active = false;
    defer g_chat_active = true;
    fake_now_ms = 601500;
    chatOutboxTick();
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(chat_echo.pendingActions(g_chat_outbox.items[0].state).send_again);
    try std.testing.expect(chat_echo.pendingActions(g_chat_outbox.items[0].state).remove);
    try std.testing.expect(g_chat_outbox.items[0].write_started);
    try std.testing.expectEqual(@as(usize, 0), writes);
    try reload();
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
}
test "ISSUE-460 late echo after Send again never duplicates the write" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("late confirmed request");
    try enqueue(text, .not_sent);
    shells[0].activity = .active;
    input_idle = false;
    chatEchoSendAgain(g_chat_outbox.items[0].id);
    try std.testing.expectEqual(@as(usize, 0), writes);
    transcript(text, 2000);
    shells[0].activity = .idle;
    input_idle = true;
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 0), writes);
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
}
test "ISSUE-460 stale queue evidence cannot claim the session still holds a message" {
    defer clear();
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("queued request"), .delivered);
    g_chat_outbox.items[0].channel_sent = true;
    try setFacts("{\\"role\\":\\"assistant\\",\\"text\\":\\"\\",\\"timestamp\\":\\"1970-01-01T00:00:02Z\\",\\"settlement\\":{\\"operation\\":\\"enqueue\\",\\"content\\":\\"queued request\\"}}\\n");
    history_entry.history.revision += 1;
    history_entry.loaded_ms = 2000;
    shells[0].activity = .active;
    g_chat_active = false;
    defer g_chat_active = true;
    fake_now_ms = 601500;
    chatOutboxTick();
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(!g_chat_outbox.items[0].transcript_queued);
    chatOutboxTick();
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expectEqual(@as(usize, 0), writes);
}
test "ISSUE-460 a full queue rejects new input without dropping accepted intent" {
    defer clear();
    for (0..CHAT_OUTBOX_MAX_PER_KEY) |_| try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("accepted request"), .queued);
    const id = g_chat_outbox.items[0].id;
    try std.testing.expect(!chatOutboxEnqueueInState(&g_chat_outbox, std.heap.page_allocator, "test", std.unicode.utf8ToUtf16LeStringLiteral("overflow request"), .queued));
    try std.testing.expectEqual(id, g_chat_outbox.items[0].id);
    try std.testing.expectEqual(@as(usize, CHAT_OUTBOX_MAX_PER_KEY), g_chat_outbox.items.len);
}

test "ISSUE-460 both saved laptop entries stay failed until positive background evidence" {
    defer clear();
    const json = "{\\"version\\":2,\\"queues\\":[{\\"key\\":\\"tmux:0:inne-cro-2\\",\\"messages\\":[{\\"t\\":\\"first restored request\\",\\"s\\":2,\\"a\\":1792494408626,\\"w\\":1792495839194,\\"c\\":7,\\"n\\":1,\\"x\\":1,\\"r\\":1}]},{\\"key\\":\\"tmux:1:projects\\",\\"messages\\":[{\\"t\\":\\"second restored request\\",\\"s\\":2,\\"a\\":1792579520119,\\"w\\":1792579618161,\\"c\\":4,\\"n\\":1,\\"x\\":1,\\"r\\":1}]}]}";
    chatOutboxParseJson(&g_chat_outbox, std.heap.page_allocator, json);
    g_chat_active = false;
    defer g_chat_active = true;
    for (g_chat_outbox.items) |entry| {
        try std.testing.expectEqual(ChatEchoState.not_sent, entry.state);
        try std.testing.expect(chat_echo.pendingActions(entry.state).send_again);
        try std.testing.expect(chat_echo.pendingActions(entry.state).remove);
        try std.testing.expect(entry.channel_sent);
    }
    test_outbox_key = "tmux:1:projects";
    const text = g_chat_outbox.items[1].text;
    try history_entry.history.text.appendSlice(std.heap.page_allocator, text);
    try history_entry.history.blocks.append(std.heap.page_allocator, .{ .role = .user, .start = 0, .len = text.len, .stamp_ms = 1792579619000 });
    history_entry.history.revision += 1;
    history_entry.loaded_ms = fake_now_ms;
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(u32, 7), g_chat_outbox.items[0].anchor.user_count);
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expectEqual(@as(usize, 0), writes + enters);
}

test "IGSH-975 popup snapshot sends the clicked reply after live blocks change" {
    defer clear();
    const quote = std.unicode.utf8ToUtf16LeStringLiteral("The clicked reply");
    const reference = chat_reaction.reference("msg_clicked");
    const snapshot = try std.heap.page_allocator.dupe(u16, quote);
    defer std.heap.page_allocator.free(snapshot);
    g_chat_capture = std.unicode.utf8ToUtf16LeStringLiteral("An earlier reply now occupies this index");
    g_chat_last_len = g_chat_capture.len;
    g_chat_blocks[0] = .{ .start = 0, .len = g_chat_last_len, .role = .prose, .reaction_reference = chat_reaction.reference("msg_earlier") };
    g_chat_block_count = 1;
    const draft = std.unicode.utf8ToUtf16LeStringLiteral("draft stays here");
    composer_text = draft;
    chatReactToMessage(reference, snapshot, .like);
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    const sent = chat_reaction.parse(g_chat_outbox.items[0].text).?;
    try std.testing.expectEqual(reference, sent.reference);
    try std.testing.expectEqualSlices(u16, quote, sent.quote);
    try std.testing.expectEqualSlices(u16, draft, composer_text);
}

test "delivery: IGSH-1010 cancellation survives restart without retry or terminal writes" {
    defer clear();
    const json = "{\\"version\\":2,\\"queues\\":[{\\"key\\":\\"test\\",\\"messages\\":[{\\"t\\":\\"cancelled prompt\\",\\"s\\":4,\\"x\\":1,\\"held\\":1,\\"qid\\":77}]}]}";
    chatOutboxParseJson(&g_chat_outbox, std.heap.page_allocator, json);
    try std.testing.expect(saveChatOutbox());
    try reload();
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(g_chat_outbox.items[0].state));
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 0), writes + channel_starts);
    try std.testing.expect(!chat_echo.pendingActions(g_chat_outbox.items[0].state).send_again);
}

`;
const admission1640 = String.raw`
fn admissionSetup(epoch: u64) void {
    history_entry.key = chatFileIdentityForShell(0);
    history_entry.message_epoch = epoch;
    history_entry.message_synced = true;
}
fn admissionEntry() !void {
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("request"), .queued);
    const entry = &g_chat_outbox.items[g_chat_outbox.items.len - 1];
    entry.message_v1 = true;
    entry.message_sid = chatFileIdentityForShell(0).sid;
    entry.message_wire_id = @splat(0);
    @memcpy(entry.message_wire_id[0..5], "id-01");
}
test "delivery: IGSH-1640 restored intent waits for final tabs before taking a send reservation" {
    clear();
    defer clear();
    defer { launch_cache.pending = false; launch_cache.tabs_restored = true; shells[0].kind = .cmd; shells[0].ai_agent = 0; }
    shells[0].kind = .tmux;
    shells[0].ai_agent = 1;
    channel_enabled = true;
    try admissionEntry();
    const wire_id = g_chat_outbox.items[0].message_wire_id;
    launch_cache.pending = true;
    launch_cache.tabs_restored = false;
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 0), channel_starts + writes);
    try std.testing.expectEqual(ChatEchoState.queued, g_chat_outbox.items[0].state);
    try std.testing.expect(!g_chat_outbox.items[0].write_started);
    shells[0].shell_id += 1;
    defer shells[0].shell_id -= 1;
    launch_cache.tabs_restored = true;
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), channel_starts);
    try std.testing.expectEqualStrings(std.mem.sliceTo(&wire_id, 0), std.mem.sliceTo(&g_chat_outbox.items[0].message_wire_id, 0));
}
test "delivery: IGSH-1640 a live unknown admission is not invented during retry" {
    clear();
    defer clear();
    defer { shells[0].kind = .cmd; shells[0].ai_agent = 0; }
    shells[0].kind = .tmux;
    shells[0].ai_agent = 1;
    channel_enabled = true;
    try admissionEntry();
    admissionSetup(9);
    const id = g_chat_outbox.items[0].id;
    _ = sendTextToShellVerifiedAt(0, g_chat_outbox.items[0].text, id);
    try std.testing.expectEqual(@as(?u64, null), g_chat_outbox.items[0].message_admission_epoch);
    try std.testing.expectEqual(id, g_chat_outbox.items[0].id);
}
test "delivery: IGSH-1640 the automatic tick releases an older stranded reservation" {
    clear();
    defer clear();
    defer { shells[0].kind = .cmd; shells[0].ai_agent = 0; }
    shells[0].kind = .tmux;
    shells[0].ai_agent = 1;
    channel_enabled = true;
    admissionSetup(9);
    try admissionEntry();
    g_chat_outbox.items[0].message_admission_epoch = 8;
    g_chat_outbox.items[0].state = .sending;
    g_chat_outbox.items[0].write_started = true;
    const id = g_chat_outbox.items[0].id;
    chatOutboxTick();
    try std.testing.expectEqual(@as(usize, 1), channel_starts);
    try std.testing.expectEqual(id, g_chat_outbox.items[0].id);
    try std.testing.expectEqual(@as(?u64, 8), g_chat_outbox.items[0].message_admission_epoch);
}
test "delivery: IGSH-1640 durable enqueue admission round trips, including zero and unknown" {
    clear();
    defer clear();
    admissionSetup(0);
    try admissionEntry();
    chatMessageCaptureAdmission(0, &g_chat_outbox.items[0]);
    const wire_id = g_chat_outbox.items[0].message_wire_id;
    try std.testing.expectEqual(@as(?u64, 0), g_chat_outbox.items[0].message_admission_epoch);
    try std.testing.expect(saveChatOutbox());
    try std.testing.expectEqual(@as(usize, 0), writes + channel_starts);
    try reload();
    try std.testing.expectEqualStrings(std.mem.sliceTo(&wire_id, 0), std.mem.sliceTo(&g_chat_outbox.items[0].message_wire_id, 0));
    try std.testing.expectEqual(@as(?u64, 0), g_chat_outbox.items[0].message_admission_epoch);
    try std.testing.expect(g_chat_outbox.items[0].from_disk);
    g_chat_outbox.items[0].message_admission_epoch = null;
    try std.testing.expect(saveChatOutbox());
    try reload();
    try std.testing.expectEqual(@as(?u64, null), g_chat_outbox.items[0].message_admission_epoch);
    chatMessageCaptureAdmission(0, &g_chat_outbox.items[0]);
    try std.testing.expectEqual(@as(?u64, null), g_chat_outbox.items[0].message_admission_epoch);
    const legacy = "{\"version\":2,\"queues\":[{\"key\":\"test\",\"messages\":[{\"t\":\"legacy\",\"s\":0}]}]}";
    chatOutboxFreeAll(std.heap.page_allocator);
    chatOutboxParseJson(&g_chat_outbox, std.heap.page_allocator, legacy);
    try std.testing.expect(g_chat_outbox.items[0].from_disk);
    try std.testing.expectEqual(@as(?u64, null), g_chat_outbox.items[0].message_admission_epoch);
    chatMessageCaptureAdmission(0, &g_chat_outbox.items[0]);
    try std.testing.expectEqual(@as(?u64, null), g_chat_outbox.items[0].message_admission_epoch);
}
test "delivery: IGSH-1640 enqueue captures before durable save" {
    clear();
    defer clear();
    defer { shells[0].kind = .cmd; shells[0].ai_agent = 0; }
    admissionSetup(17);
    shells[0].kind = .tmux;
    shells[0].ai_agent = 1;
    const index = chatEchoEnqueueForShell(0, std.unicode.utf8ToUtf16LeStringLiteral("request"), .queued).?;
    const wire_id = g_chat_outbox.items[index].message_wire_id;
    try std.testing.expectEqual(@as(?u64, 17), g_chat_outbox.items[index].message_admission_epoch);
    try reload();
    try std.testing.expectEqualStrings(std.mem.sliceTo(&wire_id, 0), std.mem.sliceTo(&g_chat_outbox.items[0].message_wire_id, 0));
    try std.testing.expectEqual(@as(?u64, 17), g_chat_outbox.items[0].message_admission_epoch);
    try std.testing.expectEqual(@as(usize, 0), writes + channel_starts);
}
test "delivery: IGSH-1640 capture requires matching authoritative history and is stable" {
    clear();
    defer clear();
    admissionSetup(12);
    try admissionEntry();
    history_entry.message_synced = false;
    chatMessageCaptureAdmission(0, &g_chat_outbox.items[0]);
    try std.testing.expectEqual(@as(?u64, null), g_chat_outbox.items[0].message_admission_epoch);
    history_entry.message_synced = true;
    g_chat_outbox.items[0].message_sid[0] = 'x';
    chatMessageCaptureAdmission(0, &g_chat_outbox.items[0]);
    try std.testing.expectEqual(@as(?u64, null), g_chat_outbox.items[0].message_admission_epoch);
    g_chat_outbox.items[0].message_sid = chatFileIdentityForShell(0).sid;
    chatMessageCaptureAdmission(0, &g_chat_outbox.items[0]);
    try std.testing.expectEqual(@as(?u64, 12), g_chat_outbox.items[0].message_admission_epoch);
    history_entry.message_epoch = 13;
    chatMessageCaptureAdmission(0, &g_chat_outbox.items[0]);
    try std.testing.expectEqual(@as(?u64, 12), g_chat_outbox.items[0].message_admission_epoch);
}
test "delivery: IGSH-1640 older reservation persists recovery and rolls back failed save" {
    clear();
    defer clear();
    admissionSetup(9);
    try admissionEntry();
    const entry = &g_chat_outbox.items[0];
    entry.message_admission_epoch = 8;
    entry.state = .sending;
    entry.write_started = true;
    entry.retryable = true;
    const id = entry.id;
    const wire_id = entry.message_wire_id;
    try std.testing.expect(saveChatOutbox());
    persist_ok = false;
    _ = chatOutboxRecoverOlderAdmission(0, 0);
    try std.testing.expectEqual(ChatEchoState.sending, entry.state);
    try std.testing.expect(entry.write_started and entry.retryable);
    persist_ok = true;
    _ = chatOutboxRecoverOlderAdmission(0, 0);
    try std.testing.expectEqual(ChatEchoState.queued, entry.state);
    try std.testing.expect(!entry.write_started and !entry.retryable);
    try std.testing.expectEqual(id, entry.id);
    try std.testing.expectEqual(@as(?u64, 8), entry.message_admission_epoch);
    try reload();
    try std.testing.expectEqualStrings(std.mem.sliceTo(&wire_id, 0), std.mem.sliceTo(&g_chat_outbox.items[0].message_wire_id, 0));
    try std.testing.expectEqual(@as(?u64, 8), g_chat_outbox.items[0].message_admission_epoch);
    try std.testing.expectEqual(ChatEchoState.queued, g_chat_outbox.items[0].state);
    try std.testing.expect(!g_chat_outbox.items[0].write_started and !g_chat_outbox.items[0].retryable);
}
test "delivery: IGSH-1640 recovery protects unknown current newer confirmed and pending" {
    clear();
    defer clear();
    admissionSetup(9);
    try admissionEntry();
    const entry = &g_chat_outbox.items[0];
    for ([_]?u64{ null, 9, 10 }) |epoch| {
        entry.message_admission_epoch = epoch;
        entry.state = .sending; entry.write_started = true; entry.retryable = true;
        _ = chatOutboxRecoverOlderAdmission(0, 0);
        try std.testing.expectEqual(ChatEchoState.sending, entry.state);
        try std.testing.expect(entry.write_started and entry.retryable);
    }
    entry.message_admission_epoch = 8;
    entry.state = .queued; entry.write_started = false; entry.retryable = false;
    persist_ok = false;
    _ = chatOutboxRecoverOlderAdmission(0, 0);
    try std.testing.expectEqual(ChatEchoState.queued, entry.state);
    try std.testing.expect(!entry.write_started and !entry.retryable);
    persist_ok = true;
    for (0..6) |case| {
        entry.state = if (case == 3) .cancelled else .sending;
        entry.write_started = true; entry.retryable = true;
        entry.channel_pending = case == 0;
        entry.reset_pending = case == 1;
        entry.message_phase[0] = if (case == 2) 's' else 0;
        entry.message_sid[0] = if (case == 4) 'x' else 's';
        history_entry.message_synced = case != 5;
        const state = entry.state;
        _ = chatOutboxRecoverOlderAdmission(0, 0);
        try std.testing.expectEqual(state, entry.state);
        try std.testing.expect(entry.write_started and entry.retryable);
    }
}
test "delivery: IGSH-1640 cancelled reducer retires only matching identity and late callback cannot resurrect" {
    clear();
    defer clear();
    admissionSetup(9);
    try admissionEntry();
    const id = g_chat_outbox.items[0].id;
    try admissionEntry();
    @memcpy(g_chat_outbox.items[1].message_wire_id[0..5], "id-02");
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("native"), .queued);
    const native_id = g_chat_outbox.items[2].id;
    try g_chat_confirmed.append(std.heap.page_allocator, .{});
    const json = try std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, "{\"id\":\"id-01\",\"state\":\"cancelled\"}", .{});
    defer json.deinit();
    try std.testing.expect(chatTmuxSendStart(0, g_chat_outbox.items[0].text, id, false, false, false));
    g_chat_tmux_send_job.?.message_v1 = true;
    g_chat_tmux_send_job.?.finished.store(true, .release);
    try std.testing.expect(chatMessageReduce(0, json.value));
    try std.testing.expectEqual(@as(usize, 2), g_chat_outbox.items.len);
    try std.testing.expectEqualStrings("id-02", std.mem.sliceTo(&g_chat_outbox.items[0].message_wire_id, 0));
    try std.testing.expectEqual(native_id, g_chat_outbox.items[1].id);
    try std.testing.expectEqual(@as(usize, 1), g_chat_confirmed.items.len);
    chatTmuxSendFinish();
    try std.testing.expectEqual(@as(usize, 2), g_chat_outbox.items.len);
    try std.testing.expect(chatOutboxIndexById(id) == null);
}
test "delivery: IGSH-1831 a receipt stamps an unknown send once" {
    clear();
    defer clear();
    const agent = shells[0].ai_agent;
    defer shells[0].ai_agent = agent;
    shells[0].ai_agent = 1;
    admissionSetup(9);
    try admissionEntry();
    const entry = &g_chat_outbox.items[0];
    entry.anchor.sent_ms = 0;
    const json = try std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, "{\"id\":\"id-01\",\"state\":\"accepted\"}", .{});
    defer json.deinit();
    try std.testing.expect(chatMessageReduce(0, json.value));
    try std.testing.expect(entry.anchor.sent_ms > 0);
    const first = entry.anchor.sent_ms;
    const server = try std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, "{\"created\":1.25}", .{});
    defer server.deinit();
    try std.testing.expectEqual(@as(i64, 1250), chatMessageSentMs(server.value, 9999));
    fake_now_ms += 1000;
    try std.testing.expect(chatMessageReduce(0, json.value));
    try std.testing.expectEqual(first, entry.anchor.sent_ms);
}
`;
const parity1633 = String.raw`
test "delivery: IGSH-1633 old sent messages cannot bury a live reply" {
    clear();
    defer clear();
    const a = std.heap.page_allocator;
    const live = @import("chat_live.zig");
    const sid = "11111111-2222-3333-4444-555555555555";
    var rows: std.ArrayList(u8) = .empty;
    defer rows.deinit(a);
    for (0..20) |i| {
        for ([_][]const u8{ "queued", "sent", "accepted" }) |phase| {
            const message = try std.fmt.allocPrint(a, "{{\"id\":\"request-{d}\",\"state\":\"{s}\",\"text\":\"Old request {d}\"}}", .{ i, phase, i });
            defer a.free(message);
            const parsed = try std.json.parseFromSlice(std.json.Value, a, message, .{});
            defer parsed.deinit();
            try std.testing.expect(chatMessageReduce(0, parsed.value));
            try std.testing.expectEqual(@as(usize, if (std.mem.eql(u8, phase, "accepted")) 0 else 1), g_chat_outbox.items.len);
        }
        const pair = try std.fmt.allocPrint(a, "{{\"role\":\"user\",\"id\":\"user-{d}\",\"text\":\"Old request {d}\",\"offset\":{d},\"end\":{d}}}\n{{\"role\":\"assistant\",\"id\":\"reply-{d}\",\"text\":\"Old reply {d}\",\"offset\":{d},\"end\":{d}}}\n", .{ i, i, i * 200, i * 200 + 100, i, i, i * 200 + 100, i * 200 + 200 });
        defer a.free(pair);
        try rows.appendSlice(a, pair);
    }
    try rows.appendSlice(a, "{\"role\":\"user\",\"id\":\"user-current\",\"text\":\"Latest request\",\"offset\":4000,\"end\":4100}\n");
    var h: chat_history.History = .{};
    defer h.deinit(a);
    const key = chat_transcript.Identity.initTmux(1, 0, false, "term-1", sid);
    const wire = try std.fmt.allocPrint(a, "@mp\t1\thistory\tok\t{s}\t0\t4100\t1\t0\tclaude\tterm-1\n{s}@@MP_END@@\n", .{ sid, rows.items });
    defer a.free(wire);
    try h.apply(a, wire, 1, key);
    try std.testing.expectEqual(@as(usize, 41), h.blocks.items.len);
    for (0..20) |i| {
        try std.testing.expect(h.blocks.items[i * 2].role == .user);
        try std.testing.expect(h.blocks.items[i * 2 + 1].role == .prose);
    }
    const last = h.blocks.items[h.blocks.items.len - 1];
    try std.testing.expect(last.role == .user);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Latest request"), h.text.items[last.start..][0..last.len]);
    _ = live.begin(1, 0, sid);
    defer live.release(1);
    const page = "{\"result\":{\"events\":[{\"seq\":1,\"event\":{\"kind\":\"turn.started\",\"turn\":\"latest\",\"payload\":{}}},{\"seq\":2,\"event\":{\"kind\":\"text.done\",\"turn\":\"latest\",\"item\":\"reply-current:text:0\",\"payload\":{\"text\":\"Latest reply\"}}}]}}";
    try std.testing.expect(live.applyPage(1, sid, page));
    var text: [128]u16 = undefined;
    var blocks: [4]ChatBlock = undefined;
    const tail = live.tailFor(1, &text, h.text.items.len, &blocks, h.blocks.items);
    try std.testing.expectEqual(@as(usize, 1), tail.blocks);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Latest reply"), text[0..tail.text_len]);
    layoutPending();
    try std.testing.expectEqual(@as(usize, 0), g_chat_echo_layout_count);
    try std.testing.expectEqual(@as(usize, 42), h.blocks.items.len + tail.blocks + g_chat_echo_layout_count);
    try std.testing.expect(live.applyPage(1, sid, "{\"result\":{\"events\":[{\"seq\":3,\"event\":{\"kind\":\"turn.ended\",\"turn\":\"latest\",\"payload\":{\"status\":\"completed\"}}}]}}"));
    try std.testing.expectEqual(@as(usize, 1), live.tailFor(1, &text, h.text.items.len, &blocks, h.blocks.items).blocks);
    const reply = "{\"role\":\"assistant\",\"id\":\"reply-current\",\"text\":\"Latest reply\",\"offset\":4100,\"end\":4200}";
    try h.upsertNativeRows(a, &.{reply}, 1, 0);
    try std.testing.expectEqual(@as(usize, 42), h.blocks.items.len);
    try std.testing.expectEqual(@as(usize, 0), live.tailFor(1, &text, h.text.items.len, &blocks, h.blocks.items).blocks);
    const final = h.blocks.items[h.blocks.items.len - 1];
    try std.testing.expect(final.role == .prose);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Latest reply"), h.text.items[final.start..][0..final.len]);
    try std.testing.expectEqual(@as(usize, 0), writes + channel_starts + enters);
}
`;
const names = ['chatMessageSentMs', 'chatConfirmedAddReceipt', 'chatEchoLatestReplyMs', 'chatMessageReduce', 'chatSendQuestionText', 'chatQuestionOtherFinish', 'chatReactToMessage', 'sendChatMessage', 'chatSteerPrompt', 'sendChatPrompt', 'chatPromptNormalizeLineEndings', 'chatSteerChord', 'chatEchoPushQueuedNow', 'chatEchoPushQueuedForShell', 'chatEchoCountDeliveredForShell', 'chatSteerAfterDelivery', 'chatMessageSyncRetryDelayMs', 'chatTmuxSendFinish', 'chatResetConfirmed', 'chatResetGiveUp', 'chatOutboxHeldByLink', 'loadChatOutbox', 'chatOutboxFreeAll', 'chatOutboxPurgeOrphans', 'chatEchoEnqueueForShell', 'chatOutboxClearIn', 'chatOutboxEnqueueIn', 'chatOutboxTick', 'chatEchoSendAgain', 'chatEchoRemove', 'chatEchoTryMatchEntry', 'chatEchoConfirmWithBlock', 'chatOutboxPrefixOf', 'chatOutboxShellForKey', 'chatTmuxSettle', 'chatOutboxCountIn', 'chatOutboxFirstIndexIn', 'chatOutboxFirstSendableIndexIn', 'chatOutboxFindSending', 'chatOutboxSendBlockedIn', 'chatOutboxIndexById', 'chatOutboxRemoveAtIn', 'chatOutboxEnqueueInState', 'chatOutboxSerialize', 'chatOutboxParseJson', 'appendJsonEscaped', 'appendJsonEscapedWide', 'chatEchoNormalizePrefix', 'chatEchoAssignForKey', 'chatEchoStoreAnchors', 'chatEchoAssignedBlock', 'chatConfirmedCountIn', 'chatConfirmedFirstIndexIn', 'chatConfirmedAdd', 'chatConfirmedHas', 'chatEchoPrefixMatches', 'chatEchoBlockConfirmed', 'chatEchoMatchActive', 'chatEchoTakenSettledIn', 'chatEchoDeliveryEvidence', 'chatEchoRetryAllForActive', 'sendTextToShellVerifiedAt', 'chatSendViaConsole', 'chatOutboxReadyToType', 'chatOutboxTrySendEntry', 'chatSubmitRetryPatch', 'chatUpgradeToHostMessage', 'chatPendingResetDropIfStale', 'chatResetSameChat', 'chatResetShellMayOwn', 'chatOutboxCountForShell', 'chatOutboxSyncCountForShell', 'chatOutboxWorkingForShell', 'chatMessageGoesToHost', 'chatHoldLegacyCodex', 'chatEchoWaitsOnTranscript', 'chatOutboxEnqueueInStateLimit', 'chatSendRoute'];
const sourceOutboxTests = ['IGSH-1831 load drops old confirmed echoes across chats but keeps unconfirmed messages', 'Chat View outbox is FIFO and capped per key', 'Chat View outbox flush skips unconfirmed entries and keeps FIFO order', 'ISSUE-460 session queued evidence cannot release the next outbox entry', 'IGSH-564 busy tmux session still gets the queued message typed'].map(name => {
  const start = source.indexOf(`test "${name}" {`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}).join('\n');
test('IGSH-1811 a sent mention keeps the live session for the bot', () => {
  assert.match(body('sendChatPrompt'), /chat_mention\.zig"\)\.apply/);
});
function runHarness(control = false) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh307-'));
  try {
    copyZig(['chat_echo.zig', 'chat_history.zig', 'chat_transcript.zig', 'chat_markdown.zig', 'chat_style.zig', 'chat_image.zig', 'chat_diff.zig', 'json_reader.zig', 'archive_rules.zig', 'voice_filter.zig', 'chat_complete.zig', 'skills.zig', 'chat_reply.zig'], dir);
    require('./fixtures/inline-stubs').writeChatMention(dir);
    if (control === true) {
      const file = path.join(dir, 'chat_history.zig');
      fs.writeFileSync(file, fs.readFileSync(file, 'utf8').replace(/        for \(self.blocks.items\[first_block\.\.\]\) \|\*block\| block.stamp_ms = .*;\n/, ''));
    }
    let functions = [...names, 'chatMessageCaptureAdmission', 'chatOutboxRecoverOlderAdmission'].map(body).join('\n')
      .replaceAll('@import("chat_session.zig").chatSettingsPending', 'chatSettingsPending')
      .replaceAll('@import("chat_session.zig").chatFileRequestForDelivery', 'chatFileRequestForDelivery')
      .replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark')
      .replaceAll('@import("inbox.zig").findShellById', 'findShellById')
      .replaceAll('@import("inbox.zig").stampSessionUse', 'stampSessionUse')
      .replaceAll('@import("inbox.zig").publishInboxState', 'publishInboxState')
      .replaceAll('@import("archive.zig").applyCanonicalSessionRename', 'applyCanonicalSessionRename')
      .replaceAll('@import("room_frontend.zig").privateActionsAllowed', 'privateActionsAllowed')
      .replaceAll('@import("workspaces.zig").updateMainWindowTitle', 'updateMainWindowTitle')
      .replaceAll('@import("chat_composer.zig").clearChatReply', 'clearChatReply')
      .replaceAll('@import("chat_composer.zig").chatAcAgent', 'chatAcAgent')
      .replaceAll('@import("chat_composer.zig").chatShellDraftNoteSend', 'chatShellDraftNoteSend')
      .replaceAll('@import("chat_send.zig").sendChatMessage', 'sendChatMessage')
      .replaceAll('@import("app_state.zig").ShellKind', 'ShellKind')
      .replaceAll('@import("win32.zig").MessageBoxW', 'MessageBoxW')
      .replaceAll('@import("fonts.zig").messageBox', 'MessageBoxW')
      .replaceAll('@import("diagnostics.zig").debugLog', 'debugLog');
    if (source.includes('fn chatOutboxRequeueAfterReconnect(')) functions += '\n' + body('chatOutboxRequeueAfterReconnect');
    functions += '\n' + (source.includes('fn sshReconnectOk(') ? body('sshReconnectOk').replaceAll('@import("console.zig").showReconnectedConsole', 'showReconnectedConsole').replaceAll('@import("drawing.zig").invalidateReconnectContent', 'invalidateReconnectContent') : 'fn sshReconnectOk(_: u32) void {}');
    if (control === 'sent-pile') {
      const changed = functions.replace('if (found) |i| chatOutboxRemoveAtIn(&g_chat_outbox, std.heap.page_allocator, i);', '');
      assert.notEqual(changed, functions, 'accepted-message retirement control exists');
      functions = changed;
    }
    if (control === 'question-old') {
      functions = functions.replace('    if (chatSendQuestionText(send_text)) return;', '');
    }
    if (control === 'steer-before') {
      functions = functions.replace('    chatEchoPushQueuedForShell(idx);', '    _ = idx;');
    }
    if (control === 'steer-empty-before') {
      functions = functions.replace('fn chatEchoPushQueuedForShell(idx: u32) void {', 'fn chatEchoPushQueuedForShell(idx: u32) void {\n    if (chatEchoCountDeliveredForShell(idx) == 0) return;');
    }
    if (control === 'settlement') {
      functions = functions.replace('const facts = chatEchoDeliveryEvidence(e);', 'const facts: chat_echo.DeliveryEvidence = .{};');
      assert.notEqual(functions, names.map(body).join('\n'));
    }
    if (control === 'reaction-index') {
      const original = functions;
      functions = functions.replace('const line = chat_reaction.format(emoji, reference, quote, &out)', 'const wrong = g_chat_blocks[0];\n    _ = reference;\n    _ = quote;\n    const line = chat_reaction.format(emoji, wrong.reaction_reference, g_chat_capture[wrong.start..][0..wrong.len], &out)');
      assert.notEqual(functions, original);
    }
    if (control === 'repeats' || control === 'unreadable') {
      const old = fs.readFileSync('tools/fixtures/chat-before-2b45249.zig', 'utf8');
      const oldBody = name => { const start = old.indexOf(`fn ${name}(`); return old.slice(start, old.indexOf('\n}', start) + 2); };
      let match = oldBody('chatEchoMatchActive').replaceAll(', now_ms, loaded_ms)', ', now_ms)').replace('    const loaded_ms = chatEchoLoadedMs();\n', '');
      if (body('chatConfirmedAdd').includes('block: ChatBlock')) {
        match = match.replace('chatConfirmedAdd(key_copy[0..e.key_len], p, g_chat_blocks[mi].start, g_chat_blocks[mi].len, g_chat_blocks[mi].stamp_ms);', 'chatConfirmedAdd(key_copy[0..e.key_len], p, g_chat_blocks[mi], e);');
      }
      functions = functions.replace(body('chatEchoMatchActive'), match) + '\n' + oldBody('chatEchoRepresentedBlock');
    }
    fs.writeFileSync(path.join(dir, 'test.zig'), (prelude + ['ChatOutboxEntry', 'ChatConfirmedEcho', 'ChatEchoAssignment'].map(declaration).join('\n') + functions + pendingLayout + acceptance + admission1640 + parity1633 + sourceOutboxTests).replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
    return spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '--test-filter', control === 'sent-pile' || control === 'sent-pile-fixed' ? 'IGSH-1633' : control === 'question-old' ? 'IGSH-1063' : control === 'reaction-index' ? 'IGSH-975 popup snapshot' : control === 'settlement' ? 'delivery: refused real' : control === 'repeats' ? 'delivery: repeats' : control === 'unreadable' ? 'delivery: aged unconfirmed' : control === 'steer-before' ? 'IGSH-564 steer busy tmux' : control === 'steer-empty-before' ? 'IGSH-564 steer empty composer' : process.env.ISSUE_460_FILTER || (control === 'issue501' ? 'ISSUE-501' : control === 'igsh564' ? 'IGSH-564' : control === 'issue460' ? 'ISSUE-460' : control === 'outbox' ? 'Chat View outbox' : 'delivery:')], { encoding: 'utf8', timeout: 60000 });
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}
test('IGSH-1640 admission is captured and recovered on production send paths', () => {
  const enqueue = body('chatEchoEnqueueForShell');
  assert.ok(enqueue.indexOf('message_sid =') < enqueue.indexOf('chatMessageCaptureAdmission('));
  assert.ok(enqueue.indexOf('chatMessageCaptureAdmission(') < enqueue.indexOf('saveChatOutbox('));
  const send = body('sendTextToShellVerifiedAt');
  assert.ok(send.indexOf('chatUpgradeToHostMessage(') < send.indexOf('chatMessageCaptureAdmission('));
  assert.ok(send.indexOf('chatMessageCaptureAdmission(') < send.indexOf('saveChatOutbox('));
  const attempt = body('chatOutboxTrySendEntry');
  assert.ok(attempt.indexOf('g_chat_pending_reset') < attempt.indexOf('chatOutboxRecoverOlderAdmission('));
  assert.ok(attempt.indexOf('chatOutboxRecoverOlderAdmission(') < attempt.indexOf('chat_echo.mayType('));
  assert.match(body('chatTmuxSendStart'), /message_admission_epoch/);
  assert.match(body('chatTmuxSendThread'), /admission_epoch/);
});
test('IGSH-1770 working dots remain for a reply while Stop is visible', () => {
  const helper = source.includes('fn chatWorkingDotsVisible(')
    ? body('chatWorkingDotsVisible')
      .replaceAll('@import("window_layout.zig").chatStopVisible', 'chatStopVisible')
      .replaceAll('@import("chat_send.zig").chatOutboxWorkingForShell', 'chatOutboxWorkingForShell')
      .replaceAll('@import("chat_live.zig").replyPresent', 'replyPresent')
    : `fn chatWorkingDotsVisible() bool { return ${dotsBoundary.match(/if \((.*)\) \{/)[1].replace('@import("window_layout.zig").chatStopVisible', 'chatStopVisible')}; }`;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-dots-'));
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, `
const std = @import("std");
var stop = false;
var queued = false;
var reply = false;
var active_shell: u32 = 0;
const shells = [_]struct { shell_id: u32 }{.{ .shell_id = 42 }};
fn chatStopVisible() bool { return stop; }
fn chatOutboxWorkingForShell(idx: u32) bool { std.debug.assert(idx == 0); return queued; }
fn replyPresent(id: u32) bool { std.debug.assert(id == 42); return reply; }
${helper}
test "working dots visibility" {
    stop = false; queued = true; reply = true;
    try std.testing.expect(!chatWorkingDotsVisible());
    stop = true; queued = false; reply = false;
    try std.testing.expect(chatWorkingDotsVisible());
    reply = true;
    try std.testing.expect(chatWorkingDotsVisible());
    queued = true;
    try std.testing.expect(chatWorkingDotsVisible());
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 60000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
test('IGSH-1415 the pending layout drops a local copy the transcript already carries', () => {
  assert.match(body('chatRelayout'), /if \(chatEchoRowLanded\(e\)\) continue;/);
});
test('correctness repeats and unreadable: executed production outbox, write reservation and matching handle restart, busy/idle, repeated text and cache reload', () => {
  assert.match(body('sendChatPrompt'), /\.model => \{\s*if \(shell\.ai_agent == 3\) \{\s*chatPiModelPicker\(\);/);
  const result = runHarness();
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
test('cache timestamp oracle rejects the actual integration omission (positive control)', () => {
  const result = runHarness(true);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /expected 0, found 1/);
});
test('IGSH-1605 a successful reconnect requeues sends that failed while the link was down before the outbox timer re-arms', () => {
  const ok = body('sshReconnectOk');
  assert.match(ok, /chatOutboxRequeueAfterReconnect\(idx\);[\s\S]*armChatOutboxTimerIfNeeded\(\)/);
  const requeue = body('chatOutboxRequeueAfterReconnect');
  assert.match(requeue, /chat_echo\.requeueOnReconnect\(entry\.state, /);
  assert.match(requeue, /entry\.state = \.queued;[\s\S]*entry\.write_started = false;/);
});
test('pending settings block the composer before any delivery mutation', () => {
  const send = body('sendChatPrompt');
  const guard = send.indexOf('chatSettingsPending(');
  assert.ok(guard >= 0, 'pending settings guard');
  for (const mutation of ['chatLivePlanReply(', 'chatEchoEnqueueForShell(', 'chatReadMark(', 'SetWindowTextW(']) {
    assert.ok(send.indexOf(mutation) > guard, mutation);
  }
  assert.match(send, /Wait for chat settings to update/);
});

test('composer always persists through the same outbox before delivery', () => {
  const send = body('sendChatPrompt');
  assert.match(send, /chatEchoEnqueueForShell\(active_shell, send_text, \.queued\)/);
  assert.match(send, /chatOutboxTick\(\)/);
  assert.match(send, /UpdateWindow\(g_chat_transcript_hwnd\)[\s\S]*SetWindowTextW\(g_chat_composer_hwnd[\s\S]*RedrawWindow\(g_main_hwnd[\s\S]*chatOutboxTick\(\)/);
  assert.doesNotMatch(send, /sendTextToActiveShellVerified|chatEchoConfirm/);
});

test('IGSH-1847 a message that was not sent is sent again under a new wire id', () => {
  assert.match(body('chatEchoSendAgain'), /message_replaces/);
  assert.match(body('chatEchoSendAgain'), /desktop-\{x:0>16\}\{x:0>16\}/);
  assert.match(body('chatOutboxTick'), /NOT_SENT_WAIT_MS/);
  assert.match(body('chatRelayout'), /e\.state == \.not_sent/);
});

test('deliberate recovery remains evidence-safe without automatic retry controls', () => {
  assert.doesNotMatch(source, /fn chatEchoRetryAt\(/);
  assert.match(body('chatEchoSendAgain'), /chatEchoTryMatchEntry/);
  assert.match(body('chatEchoSendAgain'), /chat_echo.resendDecision/);
  assert.match(body('chatEchoRetryAllForActive'), /write_started/);
  assert.doesNotMatch(body('chatPaintEcho'), /chatPaintEchoStatus|chatEchoActionRect/);
  assert.match(body('chatPaintEcho'), /if \(e\.waiting\(\)\) chatDimQueuedBubble\(hdc, rc\)/);
  assert.doesNotMatch(body('chatEchoMatchActive'), /chatEchoRepresentedBlock/);
  assert.match(body('chatDeferTranscriptLoad'), /chatEchoMatchActive\(\)/);
});

test('correctness repeats: old destructive cleanup fails the queued-repeat oracle', () => {
  const result = runHarness('repeats');
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, /repeats.*FAIL|expected 3, found 0/);
});
test('correctness unreadable: old expiry erasure fails the recoverable-intent oracle', () => {
  const result = runHarness('unreadable');
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, /aged unconfirmed.*FAIL|expected 2, found 1/);
});

test('stuck-refusal oracle rejects ignored delivery evidence (positive control)', () => {
  const result = runHarness('settlement');
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, /expected .+not_sent, found .+delivered/);
});

test('ISSUE-460 production outbox regression tests', () => {
  const result = runHarness('issue460');
  process.stdout.write(result.stdout + result.stderr);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('IGSH-564 busy tmux readiness and FIFO regression', () => {
  const result = runHarness('igsh564');
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('IGSH-564 steer oracles reject missing post-delivery keys and the old delivered-entry guard', () => {
  for (const control of ['steer-before', 'steer-empty-before']) {
    const result = runHarness(control);
    assert.equal(result.status, 1, result.stdout + result.stderr);
    assert.match(result.stderr, /IGSH-564 steer [\s\S]*FAIL/);
    assert.match(result.stderr, /expected 1, found 0/);
  }
});

test('IGSH-564 steer hook leaves Ctrl+X native and dispatches only the completed chord', () => {
  const hook = body('keyboardHookProc');
  const chord = hook.slice(hook.indexOf('if (wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) {'), hook.indexOf('const find_key_up'));
  assert.match(chord, /chatSteerChord\(&chat_steer_chord_pending/);
  assert.match(chord, /chatViewOwnsInput\(\) and foregroundIsOurs\(\) and !activeBrowserHasForegroundFocus\(\)/);
  assert.match(chord, /WM_APP_CHAT_SEND, 1, 0/);
  assert.ok(hook.indexOf('chatSteerChord(') < hook.indexOf('chatComposerOwnsKey('));
  assert.match(body('chatComposerOwnsKey'), /0x58/);
  assert.match(body('chatSteerPrompt'), /sendChatPrompt\(\)/);
  assert.match(source, /WM_APP_CHAT_SEND => \{\s*if \(!@import\("room_frontend\.zig"\)\.privateActionsAllowed\(\)\) return 0;\s*if \(wp == 1\) @import\("chat_send\.zig"\)\.chatSteerPrompt\(\) else @import\("chat_composer\.zig"\)\.chatSendOrFinishDictation\(\)/);
  assert.doesNotMatch(body('chatSteerChord'), /GetTickCount|Timer|Sleep/);
});

test('production Zig outbox capacity and FIFO unit tests', () => {
  const result = runHarness('outbox');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stderr, /All 2 tests passed/);
});

test('ISSUE-501 reconnect flush uses the production reservation confirmation and FIFO pipeline', () => {
  const result = runHarness('issue501');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stderr, /All 1 tests passed/);
});


test('IGSH-975 clicked-target oracle rejects a live-index lookup after a popup snapshot', () => {
  const result = runHarness('reaction-index');
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /FAIL \(TestExpectedEqual\)/);
});

test('IGSH-1063 Other oracle rejects the previous ordinary-message route', () => {
  const result = runHarness('question-old');
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, /expected 1, found 0/);
});


test('IGSH-1633 old sent copies cannot hide the latest live reply', () => {
  const result = runHarness('sent-pile-fixed');
  assert.equal(result.status, 0, result.error?.message || result.stdout + result.stderr);
  assert.match(result.stderr, /All 1 tests passed/);
  console.log(result.stderr.trim());
});

test('IGSH-1633 reply-position oracle rejects retained accepted messages', () => {
  const result = runHarness('sent-pile');
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, /expected 0, found 1/);
});
