const app_state = @import("app_state.zig");
const std = @import("std");
const json_reader = @import("json_reader.zig");
const skill_model = @import("skills.zig");
const chat_complete = @import("chat_complete.zig");
const chat_echo = @import("chat_echo.zig");
const shell_exit = @import("shell_exit.zig");
const DWORD = @import("win32.zig").DWORD;
const UINT = @import("win32.zig").UINT;
const SW_SHOW = @import("win32.zig").SW_SHOW;
const TIMER_CHAT_REFRESH = @import("win32.zig").TIMER_CHAT_REFRESH;
const TIMER_CHAT_SEND_VERIFY = @import("win32.zig").TIMER_CHAT_SEND_VERIFY;
const TIMER_SSH_RECONNECT = @import("win32.zig").TIMER_SSH_RECONNECT;
const TIMER_CHAT_OUTBOX = @import("win32.zig").TIMER_CHAT_OUTBOX;
const RECT = @import("win32.zig").RECT;
const GetClientRect = @import("win32.zig").GetClientRect;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const GetWindowTextW = @import("win32.zig").GetWindowTextW;
const SetWindowTextW = @import("win32.zig").SetWindowTextW;
const Sleep = @import("win32.zig").Sleep;
const CloseHandle = @import("win32.zig").CloseHandle;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const AttachConsole = @import("win32.zig").AttachConsole;
const FreeConsole = @import("win32.zig").FreeConsole;
const GetConsoleScreenBufferInfo = @import("win32.zig").GetConsoleScreenBufferInfo;
const ReadConsoleOutputAttribute = @import("win32.zig").ReadConsoleOutputAttribute;
const WriteConsoleInputW = @import("win32.zig").WriteConsoleInputW;
const OpenClipboard = @import("win32.zig").OpenClipboard;
const CloseClipboard = @import("win32.zig").CloseClipboard;
const EmptyClipboard = @import("win32.zig").EmptyClipboard;
const DeleteFileW = @import("win32.zig").DeleteFileW;
const KEY_EVENT = @import("win32.zig").KEY_EVENT;
const INPUT_RECORD = @import("win32.zig").INPUT_RECORD;
const GetExitCodeProcess = @import("win32.zig").GetExitCodeProcess;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const CONSOLE_SCREEN_BUFFER_INFO = @import("win32.zig").CONSOLE_SCREEN_BUFFER_INFO;
const COORD = @import("win32.zig").COORD;
const L = @import("startup.zig").L;
const ShellKind = @import("app_state.zig").ShellKind;
const ChatBlock = @import("app_state.zig").ChatBlock;
const win32WidePath = @import("file_io.zig").win32WidePath;
const readFileAllocWin32 = @import("file_io.zig").readFileAllocWin32;
const writeFileAtomicW = @import("file_io.zig").writeFileAtomicW;
const appendJsonEscaped = @import("workspaces.zig").appendJsonEscaped;
const logSessionAuditAlways = @import("diagnostics.zig").logSessionAuditAlways;
const debugLog = @import("diagnostics.zig").debugLog;
const saveSession = @import("session.zig").saveSession;
const appendJsonEscapedWide = @import("snippets.zig").appendJsonEscapedWide;
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;
const respawnShellInPlace = @import("console.zig").respawnShellInPlace;
const markSshTabDisconnected = @import("console.zig").markSshTabDisconnected;
const fetchTmuxSessions = @import("vps.zig").fetchTmuxSessions;
const keybd_event = @import("win32.zig").keybd_event;
const KEYEVENTF_KEYUP = @import("app_state.zig").KEYEVENTF_KEYUP;
const focusActiveShell = @import("focus.zig").focusActiveShell;
const chatClassifyBlocks = @import("chat_capture.zig").chatClassifyBlocks;
const chatBlockDisplayRange = @import("chat_capture.zig").chatBlockDisplayRange;
const chatTrimRawConsoleRow = @import("chat_capture.zig").chatTrimRawConsoleRow;
const chatFileIdentityForShell = @import("chat_session.zig").chatFileIdentityForShell;
const chatPerf = @import("chat_session.zig").chatPerf;
const chatBenchEnabled = @import("chat_session.zig").chatBenchEnabled;
const threadTitleTop = @import("browser_pane.zig").threadTitleTop;
const threadTitleHeight = @import("browser_pane.zig").threadTitleHeight;
const chatHistoryPath = @import("chat_session.zig").chatHistoryPath;
const chatHistoryEntry = @import("chat_session.zig").chatHistoryEntry;
const chatHistoryForget = @import("chat_session.zig").chatHistoryForget;
const chatDeferTranscriptLoad = @import("chat_session.zig").chatDeferTranscriptLoad;
const refreshChatTranscript = @import("chat_session.zig").refreshChatTranscript;
const chatRelayoutPreservingScroll = @import("chat_session.zig").chatRelayoutPreservingScroll;
const layoutChatControls = @import("chat_composer.zig").layoutChatControls;
const chatAcAgent = @import("chat_composer.zig").chatAcAgent;
const chatAcClose = @import("chat_composer.zig").chatAcClose;
const CHAT_SEND_VERIFY_DELAYS_MS = @import("app_state.zig").CHAT_SEND_VERIFY_DELAYS_MS;
const ShellSendResult = @import("app_state.zig").ShellSendResult;
const CHAT_OUTBOX_MAX_PER_KEY = @import("app_state.zig").CHAT_OUTBOX_MAX_PER_KEY;
const CHAT_OUTBOX_TOTAL_MAX = @import("app_state.zig").CHAT_OUTBOX_TOTAL_MAX;
const CHAT_OUTBOX_MSG_CAP = @import("app_state.zig").CHAT_OUTBOX_MSG_CAP;
const CHAT_OUTBOX_KEY_CAP = @import("app_state.zig").CHAT_OUTBOX_KEY_CAP;
const CHAT_OUTBOX_LOAD_LIMIT = @import("app_state.zig").CHAT_OUTBOX_LOAD_LIMIT;
const CHAT_ECHO_PREFIX_CAP = @import("app_state.zig").CHAT_ECHO_PREFIX_CAP;
const CHAT_CONFIRMED_MAX_PER_KEY = @import("app_state.zig").CHAT_CONFIRMED_MAX_PER_KEY;
const ChatEchoState = @import("app_state.zig").ChatEchoState;
const ChatOutboxEntry = @import("app_state.zig").ChatOutboxEntry;
const ChatConfirmedEcho = @import("app_state.zig").ChatConfirmedEcho;
const InternetGetConnectedState = @import("win32.zig").InternetGetConnectedState;
const ChatEchoAssignment = @import("app_state.zig").ChatEchoAssignment;
const SSH_AUTO_RECONNECT_ENABLED = @import("app_state.zig").SSH_AUTO_RECONNECT_ENABLED;
const shellConsoleShouldBeVisible = @import("chat_composer.zig").shellConsoleShouldBeVisible;
const showShellConsole = @import("chat_composer.zig").showShellConsole;
const chatDraftFlush = @import("chat_composer.zig").chatDraftFlush;
const repositionActive = @import("window_layout.zig").repositionActive;
const ReadConsoleOutputCharacterW = @import("win32.zig").ReadConsoleOutputCharacterW;
const setUnicodeClipboardTextWithRetry = @import("clipboard.zig").setUnicodeClipboardTextWithRetry;
const readClipboardTextWithRetry = @import("clipboard.zig").readClipboardTextWithRetry;
const chatSendForceBracketed = @import("clipboard.zig").chatSendForceBracketed;
const chatShouldUseDirectInput = @import("clipboard.zig").chatShouldUseDirectInput;
const nativePasteToShell = @import("clipboard.zig").nativePasteToShell;
const pasteTextToShellDirect = @import("clipboard.zig").pasteTextToShellDirect;
const pasteTextToShellDirectEx = @import("clipboard.zig").pasteTextToShellDirectEx;
const openAttachedConsoleInput = @import("clipboard.zig").openAttachedConsoleInput;
const openAttachedConsoleOutput = @import("clipboard.zig").openAttachedConsoleOutput;
const sendClaudeSendQueuedNowToShell = @import("clipboard.zig").sendClaudeSendQueuedNowToShell;
const SetTimer = @import("win32.zig").SetTimer;
const KillTimer = @import("win32.zig").KillTimer;
const nowFileTime = @import("inbox.zig").nowFileTime;
const shellProcessAliveForRead = @import("shell_poll.zig").shellProcessAliveForRead;

fn sendEnterToShell(shell_index: u32) bool {
    if (shell_index >= app_state.shell_count or app_state.shells[shell_index].pid == 0) return false;
    _ = FreeConsole();
    if (AttachConsole(app_state.shells[shell_index].pid) == 0) return false;
    defer _ = FreeConsole();
    const handle = openAttachedConsoleInput() orelse return false;
    defer _ = CloseHandle(handle);
    var records: [2]INPUT_RECORD = undefined;
    records[0] = .{ .EventType = KEY_EVENT, .Event = .{ .KeyEvent = .{
        .bKeyDown = 1,
        .wRepeatCount = 1,
        .wVirtualKeyCode = 0x0D,
        .wVirtualScanCode = 0x1C,
        .UnicodeChar = '\r',
        .dwControlKeyState = 0,
    } } };
    records[1] = records[0];
    records[1].Event.KeyEvent.bKeyDown = 0;
    var written: DWORD = 0;
    return WriteConsoleInputW(handle, &records, 2, &written) != 0 and written == 2;
}

fn chatSendVerifyDelayMs(after_check: u8) ?u32 {
    if (after_check >= CHAT_SEND_VERIFY_DELAYS_MS.len) return null;
    return CHAT_SEND_VERIFY_DELAYS_MS[after_check];
}

fn chatSendEnterDelayMs(kind: ShellKind) u32 {
    return switch (kind) {
        .tmux, .vps, .vps2 => 250,
        else => 120,
    };
}

fn chatInputRowHoldsPrompt(row: []const u16, prefix: []const u16) bool {
    if (prefix.len == 0 or row.len < 2) return false;
    if (row[0] != 0x276F and row[0] != 0x203A) return false;
    var i: usize = 1;
    while (i < row.len and (row[i] == ' ' or row[i] == 0xA0)) : (i += 1) {}
    const rest = row[i..];
    return rest.len >= prefix.len and std.mem.eql(u16, rest[0..prefix.len], prefix);
}

fn chatInputBoxShowsUnsentPrompt(rows: []const []const u16, prefix: []const u16) bool {
    var idx: ?usize = null;
    var i = rows.len;
    while (i > 0) {
        i -= 1;
        const row = rows[i];
        if (row.len > 0 and (row[0] == 0x276F or row[0] == 0x203A)) {
            idx = i;
            break;
        }
    }
    const start = idx orelse return false;
    return chatInputRowHoldsPrompt(rows[start], prefix);
}

test "Chat View send check: the agent input row still holding the prompt" {
    const held = std.unicode.utf8ToUtf16LeStringLiteral("\u{276F} i am in voice mode but agent");
    const empty = std.unicode.utf8ToUtf16LeStringLiteral("\u{276F}");
    const other = std.unicode.utf8ToUtf16LeStringLiteral("\u{276F} something else entirely");
    const prefix = std.unicode.utf8ToUtf16LeStringLiteral("i am in voice");
    try std.testing.expect(chatInputRowHoldsPrompt(held, prefix));
    try std.testing.expect(!chatInputRowHoldsPrompt(empty, prefix));
    try std.testing.expect(!chatInputRowHoldsPrompt(other, prefix));
    try std.testing.expect(!chatInputRowHoldsPrompt(held, prefix[0..0]));
}

test "Chat View send check: prefix row and empty continuation row are unsent" {
    const prefix = std.unicode.utf8ToUtf16LeStringLiteral("hello there");
    const previous = std.unicode.utf8ToUtf16LeStringLiteral("\u{276F} previous prompt");
    const newline_rows = [_][]const u16{ previous, std.unicode.utf8ToUtf16LeStringLiteral("\u{276F} hello there"), std.unicode.utf8ToUtf16LeStringLiteral("") };
    try std.testing.expect(chatInputBoxShowsUnsentPrompt(&newline_rows, prefix));
    const wrapped_rows = [_][]const u16{ std.unicode.utf8ToUtf16LeStringLiteral("\u{276F} hello there and more"), std.unicode.utf8ToUtf16LeStringLiteral("wrapped tail") };
    try std.testing.expect(chatInputBoxShowsUnsentPrompt(&wrapped_rows, prefix));
    const sent_rows = [_][]const u16{ previous, std.unicode.utf8ToUtf16LeStringLiteral("\u{276F}") };
    try std.testing.expect(!chatInputBoxShowsUnsentPrompt(&sent_rows, prefix));
    const draft_rows = [_][]const u16{ std.unicode.utf8ToUtf16LeStringLiteral("\u{276F} my own draft"), std.unicode.utf8ToUtf16LeStringLiteral("") };
    try std.testing.expect(!chatInputBoxShowsUnsentPrompt(&draft_rows, prefix));
}

test "Chat View send: verify delay schedule grows then ends" {
    try std.testing.expectEqual(@as(?u32, 700), chatSendVerifyDelayMs(0));
    try std.testing.expectEqual(@as(?u32, 1200), chatSendVerifyDelayMs(1));
    try std.testing.expectEqual(@as(?u32, 5000), chatSendVerifyDelayMs(5));
    try std.testing.expectEqual(@as(?u32, null), chatSendVerifyDelayMs(6));
}

test "Chat View send: ssh/tmux waits longer for the paste marker" {
    try std.testing.expectEqual(@as(u32, 120), chatSendEnterDelayMs(.cmd));
    try std.testing.expectEqual(@as(u32, 120), chatSendEnterDelayMs(.pwsh));
    try std.testing.expectEqual(@as(u32, 250), chatSendEnterDelayMs(.tmux));
    try std.testing.expectEqual(@as(u32, 250), chatSendEnterDelayMs(.vps));
    try std.testing.expectEqual(@as(u32, 250), chatSendEnterDelayMs(.vps2));
}

fn chatArmSendVerify(shell_index: u32, text: []const u16, echo_id: u64) bool {
    if (shell_index >= app_state.shell_count or app_state.g_main_hwnd == null) return false;
    var start: usize = 0;
    while (start < text.len and (text[start] == ' ' or text[start] == '\t')) : (start += 1) {}
    var n: usize = 0;
    while (start + n < text.len and n < app_state.g_chat_verify_prefix.len) : (n += 1) {
        const c = text[start + n];
        if (c == '\r' or c == '\n') break;
        app_state.g_chat_verify_prefix[n] = c;
    }
    app_state.g_chat_verify_prefix_len = n;
    app_state.g_chat_verify_shell_id = app_state.shells[shell_index].shell_id;
    app_state.g_chat_verify_checks = 0;
    app_state.g_chat_verify_echo_id = echo_id;
    if (SetTimer(app_state.g_main_hwnd, TIMER_CHAT_SEND_VERIFY, CHAT_SEND_VERIFY_DELAYS_MS[0], null) != 0) return true;
    chatVerifyClear();
    return false;
}

fn chatVerifyClear() void {
    app_state.g_chat_verify_echo_id = 0;
    app_state.g_chat_verify_prefix_len = 0;
    app_state.g_chat_verify_checks = 0;
    if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_CHAT_SEND_VERIFY);
}

fn chatPromptStillInInputBox(shell_index: u32, prefix: []const u16) ?bool {
    const pid = app_state.shells[shell_index].pid;
    if (pid == 0) return null;
    _ = FreeConsole();
    if (AttachConsole(pid) == 0) return null;
    defer _ = FreeConsole();
    const handle = openAttachedConsoleOutput() orelse return null;
    defer _ = CloseHandle(handle);
    var info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (GetConsoleScreenBufferInfo(handle, &info) == 0 or info.dwSize.x <= 0) return null;
    const width: usize = @intCast(info.dwSize.x);
    const bottom: i32 = @max(@as(i32, info.dwCursorPosition.y), @as(i32, info.srWindow.bottom));
    if (bottom < 0) return null;
    const rows: usize = @intCast(@min(@as(i32, 40), bottom + 1));
    if (rows == 0 or rows * width > app_state.g_chat_raw.len) return null;
    const start_row: i16 = @intCast(bottom - @as(i32, @intCast(rows)) + 1);
    var chars_read: DWORD = 0;
    if (ReadConsoleOutputCharacterW(handle, &app_state.g_chat_raw, @intCast(rows * width), .{ .x = 0, .y = start_row }, &chars_read) == 0 or chars_read != rows * width) return null;
    var row_slices: [40][]const u16 = undefined;
    for (0..rows) |r| row_slices[r] = chatTrimRawConsoleRow(width, chars_read, r);
    for (row_slices[0..rows]) |row| {
        if (row.len > 0 and (row[0] == 0x276F or row[0] == 0x203A)) return chatInputBoxShowsUnsentPrompt(row_slices[0..rows], prefix);
    }
    return null;
}

pub fn chatSendVerifyTick() void {
    var found: ?u32 = null;
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].shell_id == app_state.g_chat_verify_shell_id) {
            found = @intCast(i);
            break;
        }
    }
    const echo_index: ?usize = if (app_state.g_chat_verify_echo_id != 0) chatOutboxIndexById(app_state.g_chat_verify_echo_id) else null;
    if (echo_index) |ei| {
        if (chatEchoTryMatchEntry(ei)) {
            chatVerifyClear();
            chatOutboxTick();
            return;
        }
    }
    app_state.g_chat_verify_checks += 1;
    if (found) |si| {
        const held = if (app_state.g_chat_verify_prefix_len > 0) chatPromptStillInInputBox(si, app_state.g_chat_verify_prefix[0..app_state.g_chat_verify_prefix_len]) else null;
        if (held != null and !held.?) {
            if (echo_index) |ei| {
                app_state.g_chat_outbox.items[ei].state = .delivered;
                app_state.g_chat_outbox.items[ei].left_box_ms = GetTickCount64();
                _ = saveChatOutbox();
                chatOutboxChanged();
            }
            chatVerifyClear();
            chatOutboxTick();
            return;
        }
        if (chatSendVerifyDelayMs(app_state.g_chat_verify_checks)) |delay| {
            const retry_ok = if (held == true) sendEnterToShell(si) else true;
            if (retry_ok and app_state.g_main_hwnd != null and SetTimer(app_state.g_main_hwnd, TIMER_CHAT_SEND_VERIFY, delay, null) != 0) return;
        }
        const busy = app_state.shells[si].activity == .active or (si == app_state.active_shell and app_state.g_chat_screen_working);
        if (echo_index != null and chat_echo.verifyExpiredState(busy, held) == .delivered) {
            const entry = &app_state.g_chat_outbox.items[echo_index.?];
            entry.state = .delivered;
            entry.left_box_ms = GetTickCount64();
            entry.delivery_watch.observe(busy, @intCast(GetTickCount64()));
            _ = saveChatOutbox();
            chatOutboxChanged();
            chatVerifyClear();
            chatOutboxTick();
            return;
        }
    }
    if (echo_index) |ei| chatEchoMarkNotSent(ei);
    showHeaderNoticeAscii("Delivery unconfirmed - check the terminal before sending again", 8000, true);
    chatVerifyClear();
    chatOutboxTick();
}

fn sendLocalChatPrompt(shell_index: u32, text: []const u16) bool {
    return sendLocalChatPromptEx(shell_index, text, true);
}

fn sendLocalChatPromptEx(shell_index: u32, text: []const u16, press_enter: bool) bool {
    if (!shellConsoleShouldBeVisible(shell_index)) {
        if (!pasteTextToShellDirect(shell_index, text)) return false;
        return !press_enter or sendEnterToShell(shell_index);
    }
    var previous_clipboard: [16384]u16 = undefined;
    const previous_len = readClipboardTextWithRetry(&previous_clipboard);
    if (!setUnicodeClipboardTextWithRetry(text)) return false;
    defer {
        if (previous_len > 0) {
            _ = setUnicodeClipboardTextWithRetry(previous_clipboard[0..previous_len]);
        } else if (OpenClipboard(app_state.g_main_hwnd) != 0) {
            _ = EmptyClipboard();
            _ = CloseClipboard();
        }
    }

    _ = showShellConsole(shell_index, SW_SHOW, "sendLocalChatPromptEx");
    repositionActive();
    const pasted = nativePasteToShell(shell_index);
    if (pasted and press_enter) {
        Sleep(25);
        keybd_event(0x0D, 0x1C, 0, 0);
        keybd_event(0x0D, 0x1C, KEYEVENTF_KEYUP, 0);
    }
    focusActiveShell();
    return pasted;
}

fn sendTextToActiveShellVerified(send_text: []const u16, echo_id: u64) ShellSendResult {
    return sendTextToShellVerifiedAt(app_state.active_shell, send_text, echo_id);
}

pub fn voiceSendTranscriptToShell(transcript: []const u16) bool {
    if (app_state.active_shell >= app_state.shell_count) return false;
    @import("inbox.zig").stampSessionUse(app_state.active_shell, false);
    switch (sendTextToActiveShellVerified(transcript, 0)) {
        .ok => {
            _ = SetTimer(app_state.g_main_hwnd, TIMER_CHAT_REFRESH, 120, null);
            return true;
        },
        .write_failed => {
            showHeaderNoticeAscii("Voice Mode could not write to this terminal", 3500, true);
            return false;
        },
        .enter_failed => {
            showHeaderNoticeAscii("Voice Mode sent the reply but could not press Enter", 3500, true);
            return false;
        },
    }
}

pub fn voicePasteTranscriptToShellNoEnter(transcript: []const u16) bool {
    if (app_state.active_shell >= app_state.shell_count) return false;
    @import("inbox.zig").stampSessionUse(app_state.active_shell, false);
    return if (chatShouldUseDirectInput(app_state.active_shell))
        pasteTextToShellDirect(app_state.active_shell, transcript)
    else
        sendLocalChatPromptEx(app_state.active_shell, transcript, false);
}

var chat_steer_prompt = false;

pub fn chatSteerPrompt() void {
    chat_steer_prompt = true;
    defer chat_steer_prompt = false;
    sendChatPrompt();
}

pub fn sendChatPrompt() void {
    chatAcClose();
    if (!app_state.g_chat_active or app_state.g_chat_composer_hwnd == null or app_state.active_shell >= app_state.shell_count) return;
    var text_buf: [16384]u16 = undefined;
    const text_len_i = GetWindowTextW(app_state.g_chat_composer_hwnd, &text_buf, @intCast(text_buf.len));
    if (text_len_i <= 0) {
        if (chat_steer_prompt) chatEchoPushQueuedNow();
        return;
    }
    const text_len: usize = @intCast(text_len_i);
    var has_text = false;
    for (text_buf[0..text_len]) |c| {
        if (c != ' ' and c != '\t' and c != '\r' and c != '\n') {
            has_text = true;
            break;
        }
    }
    if (!has_text) {
        if (chat_steer_prompt) chatEchoPushQueuedNow();
        return;
    }
    var send_text: []const u16 = chatPromptNormalizeLineEndings(text_buf[0..text_len]);
    var composed_utf8: ?[]u8 = null;
    defer if (composed_utf8) |bytes| std.heap.page_allocator.free(bytes);
    if (app_state.g_chat_reply_len > 0) {
        const a = std.heap.page_allocator;
        const draft = std.unicode.utf16LeToUtf8Alloc(a, send_text) catch return;
        defer a.free(draft);
        const composed = @import("chat_reply.zig").compose(a, app_state.g_chat_reply[0..app_state.g_chat_reply_len], draft) catch return;
        composed_utf8 = composed;
        const n = std.unicode.utf8ToUtf16Le(app_state.g_chat_message_wide[0 .. app_state.g_chat_message_wide.len - 1], composed) catch {
            showHeaderNoticeAscii("This quoted reply is too large to send", 3500, true);
            return;
        };
        send_text = app_state.g_chat_message_wide[0..n];
    }
    if (app_state.g_chat_skill_name_len > 0) {
        const prompt_utf8 = std.unicode.utf16LeToUtf8Alloc(std.heap.page_allocator, send_text) catch {
            showHeaderNoticeAscii("The skill prompt contains invalid text", 3500, true);
            return;
        };
        defer std.heap.page_allocator.free(prompt_utf8);
        const selected = skill_model.Skill{
            .name = app_state.g_chat_skill_name[0..app_state.g_chat_skill_name_len],
            .description = @constCast(""),
            .body = app_state.g_chat_skill_body[0..app_state.g_chat_skill_body_len],
            .source = .multiprompt,
        };
        const composed = skill_model.composeMessage(std.heap.page_allocator, prompt_utf8, selected) catch {
            showHeaderNoticeAscii("Chat View could not compose the skill prompt", 3500, true);
            return;
        };
        if (composed_utf8) |bytes| std.heap.page_allocator.free(bytes);
        composed_utf8 = composed;
        const composed_len = std.unicode.utf8ToUtf16Le(app_state.g_chat_message_wide[0 .. app_state.g_chat_message_wide.len - 1], composed) catch {
            showHeaderNoticeAscii("The selected skill contains invalid text", 3500, true);
            return;
        };
        send_text = app_state.g_chat_message_wide[0..composed_len];
    }
    if (chat_complete.endsInTriggerToken(send_text, chatAcAgent()) and send_text.len + 1 < text_buf.len and composed_utf8 == null) {
        text_buf[send_text.len] = ' ';
        send_text = text_buf[0 .. send_text.len + 1];
    }
    if (app_state.g_voice_mode_active and !app_state.g_voice_auto_sending) {
        app_state.g_voice_last_activity_tick = GetTickCount64();
        for (&app_state.g_voice_utt_open) |*slot| if (slot.id != 0) {
            slot.consumed = true;
        };
    }
    const ei = chatEchoEnqueueForShell(app_state.active_shell, send_text, .queued) orelse {
        showHeaderNoticeAscii("Could not save the message; keep it here and try again", 3500, true);
        return;
    };
    app_state.g_chat_read_open_pending = false;
    app_state.g_chat_read_hold = false;
    app_state.g_chat_read_open_ready = true;
    _ = @import("chat_session.zig").chatReadMark(true);
    app_state.g_chat_outbox.items[ei].steer_pending = chat_steer_prompt;
    chatOutboxTick();
    @import("inbox.zig").stampSessionUse(app_state.active_shell, false);
    app_state.g_chat_scroll_bottom_pending = true;
    if (app_state.g_chat_ac_dialog_len > 0 and std.mem.startsWith(u16, send_text, app_state.g_chat_ac_dialog_command[0..app_state.g_chat_ac_dialog_len])) {
        showHeaderNoticeAscii("Opened in the terminal, press Alt+C to see it", 4000, false);
    }
    app_state.g_chat_ac_dialog_len = 0;
    _ = SetWindowTextW(app_state.g_chat_composer_hwnd, L(""));
    app_state.g_chat_draft_dirty = true;
    chatDraftFlush();
    app_state.g_chat_skill_name_len = 0;
    app_state.g_chat_skill_body_len = 0;
    @import("chat_composer.zig").clearChatReply();
    _ = SetTimer(app_state.g_main_hwnd, TIMER_CHAT_REFRESH, 120, null);
}

fn chatNetworkReportsConnected() bool {
    var flags: DWORD = 0;
    return InternetGetConnectedState(&flags, 0) != 0;
}

fn chatLinkDownDecision(disconnected: bool, pid: u32, process_alive: bool, net_connected: bool, host_unreachable: bool) bool {
    if (disconnected) return true;
    if (pid == 0) return true;
    if (!process_alive) return true;
    if (!net_connected) return true;
    if (host_unreachable) return true;
    return false;
}

test "Chat View link health treats any down signal as down" {
    try std.testing.expect(chatLinkDownDecision(false, 123, true, true, false) == false);
    try std.testing.expect(chatLinkDownDecision(true, 123, true, true, false));
    try std.testing.expect(chatLinkDownDecision(false, 0, true, true, false));
    try std.testing.expect(chatLinkDownDecision(false, 123, false, true, false));
    try std.testing.expect(chatLinkDownDecision(false, 123, true, false, false));
    try std.testing.expect(chatLinkDownDecision(false, 123, true, true, true));
}

fn chatLinkLooksDown(shell_index: u32) bool {
    if (shell_index >= app_state.shell_count) return true;
    const sh = &app_state.shells[shell_index];
    const alive = if (sh.process != null) shellProcessAliveForRead(@intCast(shell_index)) else true;
    return chatLinkDownDecision(
        sh.disconnected or sh.ssh_reconnect.phase == .reconnecting,
        sh.pid,
        alive,
        true,
        false,
    );
}

pub fn chatOutboxKeyForShell(idx: u32, buf: []u8) []const u8 {
    if (idx >= app_state.shell_count) return buf[0..0];
    const sh = &app_state.shells[idx];
    if (sh.tmux_session_len > 0) {
        return std.fmt.bufPrint(buf, "tmux:{d}:{s}", .{ sh.tmux_host, sh.tmux_session[0..@as(usize, sh.tmux_session_len)] }) catch buf[0..0];
    }
    if (sh.chat_id == 0) {
        var io = std.Io.Threaded.init(std.heap.page_allocator, .{});
        defer io.deinit();
        while (sh.chat_id == 0) {
            io.io().random(std.mem.asBytes(&sh.chat_id));
            sh.chat_id &= (1 << 53) - 1;
        }
        saveSession();
    }
    return std.fmt.bufPrint(buf, "{s}:#{x:0>16}", .{ @tagName(sh.kind), sh.chat_id }) catch buf[0..0];
}

pub fn chatOutboxLegacyKeyForShell(idx: u32, buf: []u8) []const u8 {
    if (idx >= app_state.shell_count) return buf[0..0];
    const sh = &app_state.shells[idx];
    if (sh.tmux_session_len > 0) return buf[0..0];
    var name_buf: [128]u8 = undefined;
    var ni: usize = 0;
    const nlen: usize = @as(usize, sh.name_len);
    while (ni < nlen and ni < name_buf.len) : (ni += 1) {
        const c = sh.name[ni];
        name_buf[ni] = if (c >= 0x20 and c < 0x7F) @intCast(c) else '?';
    }
    return std.fmt.bufPrint(buf, "{s}:{s}", .{ @tagName(sh.kind), name_buf[0..ni] }) catch buf[0..0];
}

pub fn chatOutboxShellForKey(key: []const u8) ?u32 {
    var buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    var i: u32 = 0;
    while (i < app_state.shell_count) : (i += 1) {
        const k = chatOutboxKeyForShell(i, &buf);
        if (k.len > 0 and std.mem.eql(u8, k, key)) return i;
    }
    if (std.mem.startsWith(u8, key, "tmux:") or std.mem.indexOf(u8, key, ":#") != null) return null;
    var match: ?u32 = null;
    i = 0;
    while (i < app_state.shell_count) : (i += 1) {
        const legacy = chatOutboxLegacyKeyForShell(i, &buf);
        if (legacy.len == 0 or !std.mem.eql(u8, legacy, key)) continue;
        if (match != null) return null;
        match = i;
    }
    return match;
}

fn chatOutboxCountIn(list: *const std.ArrayList(ChatOutboxEntry), key: []const u8) usize {
    var n: usize = 0;
    for (list.items) |e| {
        if (std.mem.eql(u8, e.key[0..@as(usize, e.key_len)], key)) n += 1;
    }
    return n;
}

fn chatOutboxFirstIndexIn(list: *const std.ArrayList(ChatOutboxEntry), key: []const u8) ?usize {
    for (list.items, 0..) |e, i| {
        if (std.mem.eql(u8, e.key[0..@as(usize, e.key_len)], key)) return i;
    }
    return null;
}

fn chatOutboxAutoSendable(state: ChatEchoState) bool {
    return state == .queued;
}

fn chatOutboxFirstSendableIndexIn(list: *const std.ArrayList(ChatOutboxEntry), key: []const u8, claude_buffer: bool) ?usize {
    for (list.items, 0..) |e, i| {
        if (!std.mem.eql(u8, e.key[0..@as(usize, e.key_len)], key)) continue;
        if (e.state == .sending or (e.state == .delivered and !claude_buffer)) return null;
        if (chat_echo.mayType(e.state, e.write_started, false, false)) return i;
    }
    return null;
}

fn chatOutboxFindSending(list: *const std.ArrayList(ChatOutboxEntry)) ?usize {
    for (list.items, 0..) |e, i| {
        if (e.state == .sending) return i;
    }
    return null;
}

pub fn chatOutboxIndexById(id: u64) ?usize {
    if (id == 0) return null;
    for (app_state.g_chat_outbox.items, 0..) |e, i| {
        if (e.id == id) return i;
    }
    return null;
}

fn chatOutboxRemoveAtIn(list: *std.ArrayList(ChatOutboxEntry), allocator: std.mem.Allocator, index: usize) void {
    if (index >= list.items.len) return;
    if (list.items[index].text.len > 0) allocator.free(list.items[index].text);
    _ = list.orderedRemove(index);
}

fn chatOutboxClearIn(list: *std.ArrayList(ChatOutboxEntry), allocator: std.mem.Allocator, key: []const u8) u32 {
    var dropped: u32 = 0;
    var i: usize = 0;
    while (i < list.items.len) {
        if (std.mem.eql(u8, list.items[i].key[0..@as(usize, list.items[i].key_len)], key)) {
            chatOutboxRemoveAtIn(list, allocator, i);
            dropped += 1;
        } else {
            i += 1;
        }
    }
    return dropped;
}

fn chatOutboxEnqueueIn(list: *std.ArrayList(ChatOutboxEntry), allocator: std.mem.Allocator, key: []const u8, text: []const u16) bool {
    return chatOutboxEnqueueInState(list, allocator, key, text, .queued);
}

fn chatOutboxEnqueueInState(list: *std.ArrayList(ChatOutboxEntry), allocator: std.mem.Allocator, key: []const u8, text: []const u16, state: ChatEchoState) bool {
    if (key.len == 0 or text.len == 0 or text.len > CHAT_OUTBOX_MSG_CAP) return false;
    if (list.items.len >= CHAT_OUTBOX_TOTAL_MAX) return false;
    if (chatOutboxCountIn(list, key) >= CHAT_OUTBOX_MAX_PER_KEY) return false;
    const owned = allocator.dupe(u16, text) catch return false;
    var entry = ChatOutboxEntry{};
    const klen = @min(key.len, entry.key.len);
    @memcpy(entry.key[0..klen], key[0..klen]);
    entry.key_len = @intCast(klen);
    entry.text = owned;
    entry.state = state;
    entry.id = app_state.g_chat_echo_next_id;
    app_state.g_chat_echo_next_id +%= 1;
    if (entry.id == 0) entry.id = app_state.g_chat_echo_next_id;
    list.append(allocator, entry) catch {
        allocator.free(owned);
        return false;
    };
    return true;
}

fn chatEchoAnchorNow(idx: u32) chat_echo.Anchor {
    var anchor = chat_echo.Anchor{ .sent_ms = chat_echo.fileTimeToUnixMs(nowFileTime()) };
    if (idx != app_state.active_shell) return anchor;
    anchor.counted = app_state.g_chat_block_count > 0;
    for (app_state.g_chat_blocks[0..app_state.g_chat_block_count]) |b| {
        if (b.role == .user) anchor.user_count +|= 1;
        if (b.stamp_ms > anchor.after_ms) anchor.after_ms = b.stamp_ms;
    }
    for (app_state.g_chat_histories.items) |history| {
        if (history.retired or history.key.shell_id != app_state.shells[idx].shell_id) continue;
        const facts = history.history.deliveryEvidence(std.heap.page_allocator, .{ .text = &.{}, .prefix = &.{}, .anchor = .{} }) catch continue;
        anchor.after_ms = @max(anchor.after_ms, facts.latest_ms);
    }
    return anchor;
}

fn chatEchoStateOnLoad(saved: u8) ChatEchoState {
    return chat_echo.stateOnLoad(saved, saved != 0);
}

fn chatOutboxSerialize(list: *const std.ArrayList(ChatOutboxEntry), allocator: std.mem.Allocator, out_len: *usize) ?[]u8 {
    var total: usize = 128;
    for (list.items) |e| total += e.text.len * 6 + CHAT_OUTBOX_KEY_CAP + 160;
    const out = allocator.alloc(u8, total) catch return null;
    var pos: usize = 0;
    const head = "{\"version\":2,\"queues\":[";
    @memcpy(out[pos .. pos + head.len], head);
    pos += head.len;
    var first_queue = true;
    for (list.items, 0..) |e, i| {
        const key = e.key[0..@as(usize, e.key_len)];
        const first = chatOutboxFirstIndexIn(list, key) orelse continue;
        if (first != i) continue;
        if (!first_queue) {
            out[pos] = ',';
            pos += 1;
        }
        first_queue = false;
        const q1 = "{\"key\":\"";
        @memcpy(out[pos .. pos + q1.len], q1);
        pos += q1.len;
        appendJsonEscaped(out, &pos, key);
        const q2 = "\",\"messages\":[";
        @memcpy(out[pos .. pos + q2.len], q2);
        pos += q2.len;
        var first_msg = true;
        for (list.items) |m| {
            if (!std.mem.eql(u8, m.key[0..@as(usize, m.key_len)], key)) continue;
            if (!first_msg) {
                out[pos] = ',';
                pos += 1;
            }
            first_msg = false;
            const m1 = "{\"t\":\"";
            @memcpy(out[pos .. pos + m1.len], m1);
            pos += m1.len;
            appendJsonEscapedWide(out, &pos, m.text);
            const m2 = "\",\"s\":";
            @memcpy(out[pos .. pos + m2.len], m2);
            pos += m2.len;
            out[pos] = '0' + @as(u8, @intFromEnum(m.state));
            pos += 1;
            const anchor_text = std.fmt.bufPrint(out[pos..], ",\"a\":{d},\"w\":{d},\"c\":{d},\"n\":{d},\"x\":{d},\"r\":{d},\"d\":{d}", .{ @max(m.anchor.after_ms, 0), @max(m.anchor.sent_ms, 0), m.anchor.user_count, @intFromBool(m.anchor.counted), @intFromBool(m.write_started), @intFromBool(m.retryable), @max(m.expires_ms, 0) }) catch "";
            pos += anchor_text.len;
            out[pos] = '}';
            pos += 1;
        }
        const qend = "]}";
        @memcpy(out[pos .. pos + qend.len], qend);
        pos += qend.len;
    }
    const end = "]}";
    @memcpy(out[pos .. pos + end.len], end);
    pos += end.len;
    out_len.* = pos;
    return out;
}

fn chatOutboxParseJson(list: *std.ArrayList(ChatOutboxEntry), allocator: std.mem.Allocator, json: []const u8) void {
    var parsed = json_reader.parse(allocator, json) catch return;
    defer parsed.deinit();
    const version = json_reader.uintDefault(parsed.value, "version", 0);
    if (version != 1 and version != 2) return;
    for (json_reader.array(json_reader.field(parsed.value, "queues"))) |obj| {
        var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = std.mem.zeroes([CHAT_OUTBOX_KEY_CAP]u8);
        const klen = json_reader.copyString(obj, "key", &key_buf);
        if (klen > 0) {
            const key = key_buf[0..klen];
            for (json_reader.array(json_reader.field(obj, "messages"))) |mobj| {
                var text_buf: [CHAT_OUTBOX_MSG_CAP + 1]u16 = undefined;
                const tlen = json_reader.copyWide(mobj, "t", &text_buf);
                if (tlen > 0) {
                    const saved: u8 = @intCast(@min(json_reader.uintDefault(mobj, "s", 0), 3));
                    if (chatOutboxEnqueueInState(list, allocator, key, text_buf[0..tlen], chat_echo.stateOnLoad(saved, json_reader.uintDefault(mobj, "x", @intFromBool(saved != 0)) != 0))) {
                        list.items[list.items.len - 1].retryable = json_reader.uintDefault(mobj, "r", 0) != 0;
                        list.items[list.items.len - 1].write_started = json_reader.uintDefault(mobj, "x", @intFromBool(saved != 0)) != 0;
                        const max_ms: u64 = std.math.maxInt(i64);
                        list.items[list.items.len - 1].anchor = .{
                            .after_ms = @intCast(@min(json_reader.uintDefault(mobj, "a", 0), max_ms)),
                            .sent_ms = @intCast(@min(json_reader.uintDefault(mobj, "w", 0), max_ms)),
                            .user_count = @intCast(@min(json_reader.uintDefault(mobj, "c", 0), std.math.maxInt(u32))),
                            .counted = json_reader.uintDefault(mobj, "n", 0) != 0,
                        };
                        const entry = &list.items[list.items.len - 1];
                        entry.channel_sent = entry.write_started and std.mem.startsWith(u8, key, "tmux:");
                        const now_ms = chat_echo.fileTimeToUnixMs(nowFileTime());
                        const saved_ms = if (entry.anchor.sent_ms > 0) entry.anchor.sent_ms else entry.anchor.after_ms;
                        const saved_deadline = @min(json_reader.uintDefault(mobj, "d", 0), max_ms);
                        entry.expires_ms = if (saved_deadline > 0) @intCast(saved_deadline) else (if (saved_ms > 0) saved_ms else now_ms) +| 600_000;
                        const remaining_ms = std.math.clamp(entry.expires_ms -| now_ms, 0, 600_000);
                        entry.sent_tick_ms = @as(i64, @intCast(GetTickCount64())) - (600_000 - remaining_ms);
                        if (entry.state == .delivered and entry.anchor.sent_ms == 0) {
                            entry.state = .not_sent;
                            entry.retryable = true;
                        }
                    }
                }
            }
        }
    }
}

fn getChatOutboxPath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 478) return null;
    const rest = "\\ZigShell\\chat-outbox.json";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

fn chatOutboxFreeAll(allocator: std.mem.Allocator) void {
    for (app_state.g_chat_outbox.items) |e| {
        if (e.text.len > 0) allocator.free(e.text);
    }
    app_state.g_chat_outbox.clearRetainingCapacity();
}

pub fn saveChatOutbox() bool {
    var path_buf: [512]u8 = undefined;
    const path = getChatOutboxPath(&path_buf) orelse return false;
    if (app_state.g_chat_outbox.items.len == 0) {
        return writeFileAtomicW(path, "{\"version\":2,\"queues\":[]}");
    }
    var out_len: usize = 0;
    const bytes = chatOutboxSerialize(&app_state.g_chat_outbox, std.heap.page_allocator, &out_len) orelse return false;
    defer std.heap.page_allocator.free(bytes);
    return writeFileAtomicW(path, bytes[0..out_len]);
}

pub fn loadChatOutbox() void {
    chatOutboxFreeAll(std.heap.page_allocator);
    var path_buf: [512]u8 = undefined;
    const path = getChatOutboxPath(&path_buf) orelse return;
    const json = readFileAllocWin32(path, CHAT_OUTBOX_LOAD_LIMIT) orelse return;
    defer std.heap.page_allocator.free(json);
    chatOutboxParseJson(&app_state.g_chat_outbox, std.heap.page_allocator, json);
    var parsed = json_reader.parse(std.heap.page_allocator, json) catch return;
    defer parsed.deinit();
    const version = json_reader.uintDefault(parsed.value, "version", 0);
    if (version != 1 and version != 2) return;
    _ = chatOutboxPurgeOrphans();
    _ = saveChatOutbox();
    armChatOutboxTimerIfNeeded();
}

fn armChatOutboxTimerIfNeeded() void {
    if (app_state.g_main_hwnd == null) return;
    if (app_state.g_chat_outbox.items.len > 0 or app_state.g_chat_tmux_send_job != null or app_state.g_chat_full_settle_job != null) {
        if (!app_state.g_chat_outbox_timer_on) {
            app_state.g_chat_outbox_timer_on = true;
            _ = SetTimer(app_state.g_main_hwnd, TIMER_CHAT_OUTBOX, 1500, null);
        }
    } else if (app_state.g_chat_outbox_timer_on) {
        app_state.g_chat_outbox_timer_on = false;
        _ = KillTimer(app_state.g_main_hwnd, TIMER_CHAT_OUTBOX);
    }
}

pub fn chatOutboxChanged() void {
    app_state.g_chat_outbox_revision +%= 1;
    if (app_state.g_main_hwnd == null) return;
    layoutChatControls();
    if (app_state.g_chat_active and app_state.g_chat_transcript_hwnd != null) {
        var rc: RECT = std.mem.zeroes(RECT);
        _ = GetClientRect(app_state.g_chat_transcript_hwnd, &rc);
        chatRelayoutPreservingScroll(rc.right - rc.left, @import("chat_render.zig").chatViewportH(rc.bottom - rc.top));
        _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    }
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    armChatOutboxTimerIfNeeded();
}

fn chatOutboxEnqueueForShell(idx: u32, text: []const u16) bool {
    var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const key = chatOutboxKeyForShell(idx, &key_buf);
    if (key.len == 0) return false;
    if (!chatOutboxEnqueueIn(&app_state.g_chat_outbox, std.heap.page_allocator, key, text)) return false;
    _ = saveChatOutbox();
    chatOutboxChanged();
    return true;
}

pub fn chatOutboxCountForShell(idx: u32) usize {
    var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const key = chatOutboxKeyForShell(idx, &key_buf);
    if (key.len == 0) return 0;
    return chatOutboxCountIn(&app_state.g_chat_outbox, key);
}

pub fn chatEchoCountNotSentForShell(idx: u32) usize {
    if (idx >= app_state.shell_count) return 0;
    var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const key = chatOutboxKeyForShell(idx, &key_buf);
    if (key.len == 0) return 0;
    var n: usize = 0;
    for (app_state.g_chat_outbox.items) |e| {
        if (e.state != .not_sent) continue;
        if (std.mem.eql(u8, e.key[0..@as(usize, e.key_len)], key)) n += 1;
    }
    return n;
}

fn chatOutboxDropForKey(key: []const u8) void {
    if (key.len == 0) return;
    chatConfirmedDropKey(key);
    const dropped = chatOutboxClearIn(&app_state.g_chat_outbox, std.heap.page_allocator, key);
    if (dropped == 0) return;
    _ = saveChatOutbox();
    chatOutboxChanged();
}

pub fn chatResetForShell(idx: u32) void {
    if (idx >= app_state.shell_count) return;
    var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const outbox_key = chatOutboxKeyForShell(idx, &key_buf);
    if (app_state.g_chat_verify_shell_id == app_state.shells[idx].shell_id) chatVerifyClear();
    chatOutboxDropForKey(outbox_key);
    const shell_id = app_state.shells[idx].shell_id;
    const key = chatFileIdentityForShell(idx);
    while (!app_state.g_chat_cache_write_mutex.tryLock()) Sleep(1);
    for (app_state.g_chat_histories.items) |entry| {
        if (entry.key.shell_id == shell_id) entry.cache_cancelled.store(true, .release);
    }
    chatHistoryForget(shell_id);
    var path_buf: [560]u8 = undefined;
    if (key.shell_id != 0) {
        if (chatHistoryPath(key, &path_buf)) |path| {
            var wide: [600]u16 = undefined;
            if (win32WidePath(&wide, path)) |w| _ = DeleteFileW(w.ptr);
        }
        if (chatHistoryEntry(key)) |entry| entry.disk_loaded = true;
    }
    app_state.g_chat_cache_write_mutex.unlock();
    if (idx == app_state.active_shell) {
        chatDeferTranscriptLoad();
        if (app_state.g_chat_active) refreshChatTranscript(true);
    }
}

pub fn chatOutboxDropForShell(idx: u32) void {
    var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const key = chatOutboxKeyForShell(idx, &key_buf);
    chatOutboxDropForKey(key);
}

fn chatOutboxPurgeOrphans() bool {
    var removed = false;
    var i: usize = 0;
    while (i < app_state.g_chat_outbox.items.len) {
        const key = app_state.g_chat_outbox.items[i].key[0..@as(usize, app_state.g_chat_outbox.items[i].key_len)];
        if (chatOutboxShellForKey(key)) |idx| {
            var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
            const current = chatOutboxKeyForShell(idx, &key_buf);
            if (!std.mem.eql(u8, key, current)) {
                @memcpy(app_state.g_chat_outbox.items[i].key[0..current.len], current);
                app_state.g_chat_outbox.items[i].key_len = @intCast(current.len);
                removed = true;
            }
            i += 1;
        } else {
            i += 1;
        }
    }
    return removed;
}

fn chatEchoNormalizePrefix(text: []const u16, out: []u16) []const u16 {
    var n: usize = 0;
    var pending_space = false;
    for (text) |c| {
        const is_ws = c == ' ' or c == '\t' or c == '\r' or c == '\n' or c == 0xA0;
        if (is_ws) {
            if (n > 0) pending_space = true;
            continue;
        }
        if (pending_space) {
            if (n >= out.len) break;
            out[n] = ' ';
            n += 1;
            pending_space = false;
        }
        if (n >= out.len) break;
        out[n] = c;
        n += 1;
    }
    return out[0..n];
}

fn chatEchoPrefixMatches(block_norm: []const u16, prefix: []const u16) bool {
    if (prefix.len == 0 or block_norm.len < prefix.len) return false;
    return std.mem.eql(u16, block_norm[0..prefix.len], prefix);
}

fn chatEchoWindowFull() bool {
    return app_state.g_chat_window_full and app_state.g_chat_blocks_from_file;
}

fn chatEchoAssignForKey(key: []const u8, blocks: []const ChatBlock, buf: []const u16, window_full: bool, result: *ChatEchoAssignment) void {
    result.* = .{};
    var prefixes: [CHAT_OUTBOX_MAX_PER_KEY][CHAT_ECHO_PREFIX_CAP]u16 = undefined;
    var pending: [CHAT_OUTBOX_MAX_PER_KEY]chat_echo.Pending = undefined;
    for (app_state.g_chat_outbox.items) |e| {
        if (result.count >= pending.len) break;
        if ((!e.write_started and !e.retryable) or !std.mem.eql(u8, e.key[0..@as(usize, e.key_len)], key)) continue;
        pending[result.count] = .{
            .prefix = chatEchoNormalizePrefix(e.text, &prefixes[result.count]),
            .text = e.text,
            .anchor = e.anchor,
            .unanchored_delivery = (e.write_started or e.retryable) and e.anchor.after_ms == 0 and e.anchor.sent_ms == 0 and !e.anchor.counted,
        };
        result.id[result.count] = e.id;
        result.count += 1;
    }
    if (result.count == 0) return;
    const allocator = std.heap.page_allocator;
    const users = allocator.alloc(chat_echo.UserBlock, blocks.len) catch return;
    defer allocator.free(users);
    const user_at = allocator.alloc(usize, blocks.len) catch return;
    defer allocator.free(user_at);
    var user_count: usize = 0;
    for (blocks, 0..) |b, bi| {
        if (b.role != .user or user_count >= users.len) continue;
        const disp = chatBlockDisplayRange(buf, b);
        users[user_count] = .{ .text = buf[disp.start .. disp.start + disp.len], .stamp_ms = b.stamp_ms };
        user_at[user_count] = bi;
        user_count += 1;
    }
    var claimed: [CHAT_CONFIRMED_MAX_PER_KEY]i64 = undefined;
    var claimed_count: usize = 0;
    for (app_state.g_chat_confirmed.items) |c| {
        if (claimed_count >= claimed.len) break;
        if (c.stamp_ms == 0 or !std.mem.eql(u8, c.key[0..@as(usize, c.key_len)], key)) continue;
        claimed[claimed_count] = c.stamp_ms;
        claimed_count += 1;
    }
    var picked: [CHAT_OUTBOX_MAX_PER_KEY]?usize = undefined;
    chat_echo.assign(pending[0..result.count], users[0..user_count], window_full, claimed[0..claimed_count], picked[0..result.count]);
    for (0..result.count) |k| {
        result.block[k] = if (picked[k]) |ui| user_at[ui] else null;
        result.anchor[k] = pending[k].anchor;
    }
}

fn chatEchoStoreAnchors(a: *const ChatEchoAssignment) void {
    for (0..a.count) |k| {
        const ei = chatOutboxIndexById(a.id[k]) orelse continue;
        app_state.g_chat_outbox.items[ei].anchor = a.anchor[k];
    }
}

fn chatEchoAssignedBlock(a: *const ChatEchoAssignment, id: u64) ?usize {
    for (0..a.count) |k| {
        if (a.id[k] == id) return a.block[k];
    }
    return null;
}

fn chatConfirmedCountIn(key: []const u8) usize {
    var n: usize = 0;
    for (app_state.g_chat_confirmed.items) |c| {
        if (std.mem.eql(u8, c.key[0..@as(usize, c.key_len)], key)) n += 1;
    }
    return n;
}

fn chatConfirmedFirstIndexIn(key: []const u8) ?usize {
    for (app_state.g_chat_confirmed.items, 0..) |c, i| {
        if (std.mem.eql(u8, c.key[0..@as(usize, c.key_len)], key)) return i;
    }
    return null;
}

fn chatConfirmedDropKey(key: []const u8) void {
    if (key.len == 0) return;
    var i: usize = 0;
    while (i < app_state.g_chat_confirmed.items.len) {
        if (std.mem.eql(u8, app_state.g_chat_confirmed.items[i].key[0..@as(usize, app_state.g_chat_confirmed.items[i].key_len)], key)) {
            _ = app_state.g_chat_confirmed.orderedRemove(i);
        } else {
            i += 1;
        }
    }
}

fn chatConfirmedAdd(key: []const u8, prefix: []const u16, block_start: usize, block_len: usize, stamp_ms: i64) void {
    if (key.len == 0 or prefix.len == 0) return;
    while (chatConfirmedCountIn(key) >= CHAT_CONFIRMED_MAX_PER_KEY) {
        const victim = chatConfirmedFirstIndexIn(key) orelse break;
        _ = app_state.g_chat_confirmed.orderedRemove(victim);
    }
    var c = ChatConfirmedEcho{};
    const klen = @min(key.len, c.key.len);
    @memcpy(c.key[0..klen], key[0..klen]);
    c.key_len = @intCast(klen);
    const plen = @min(prefix.len, c.prefix.len);
    @memcpy(c.prefix[0..plen], prefix[0..plen]);
    c.prefix_len = @intCast(plen);
    c.block_start = block_start;
    c.block_len = block_len;
    c.stamp_ms = stamp_ms;
    app_state.g_chat_confirmed.append(std.heap.page_allocator, c) catch {};
}

fn chatConfirmedHas(key: []const u8, block_norm: []const u16, stamp_ms: i64) bool {
    if (key.len == 0 or block_norm.len == 0) return false;
    for (app_state.g_chat_confirmed.items) |c| {
        if (!std.mem.eql(u8, c.key[0..@as(usize, c.key_len)], key)) continue;
        if (c.stamp_ms != 0 and stamp_ms != 0) {
            if (c.stamp_ms == stamp_ms) return true;
            continue;
        }
        const p = c.prefix[0..@as(usize, c.prefix_len)];
        if (p.len > 0 and chatEchoPrefixMatches(block_norm, p)) return true;
    }
    return false;
}

pub fn chatEchoBlockConfirmed(buf: []const u16, block: ChatBlock) bool {
    if (app_state.active_shell >= app_state.shell_count or app_state.g_chat_confirmed.items.len == 0) return false;
    var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const key = chatOutboxKeyForShell(app_state.active_shell, &key_buf);
    if (key.len == 0) return false;
    const disp = chatBlockDisplayRange(buf, block);
    if (disp.len == 0) return false;
    var norm: [CHAT_ECHO_PREFIX_CAP]u16 = undefined;
    const p = chatEchoNormalizePrefix(buf[disp.start .. disp.start + disp.len], &norm);
    return chatConfirmedHas(key, p, block.stamp_ms);
}

fn chatEchoEnqueueForShell(idx: u32, text: []const u16, state: ChatEchoState) ?usize {
    var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const key = chatOutboxKeyForShell(idx, &key_buf);
    if (key.len == 0) return null;
    const anchor = chatEchoAnchorNow(idx);
    if (!chatOutboxEnqueueInState(&app_state.g_chat_outbox, std.heap.page_allocator, key, text, state)) return null;
    const added = app_state.g_chat_outbox.items.len - 1;
    app_state.g_chat_outbox.items[added].anchor = anchor;
    app_state.g_chat_outbox.items[added].sent_tick_ms = @intCast(GetTickCount64());
    app_state.g_chat_outbox.items[added].expires_ms = anchor.sent_ms +| 600_000;
    if (!saveChatOutbox()) {
        chatOutboxRemoveAtIn(&app_state.g_chat_outbox, std.heap.page_allocator, added);
        return null;
    }
    chatOutboxChanged();
    return added;
}

fn chatEchoMarkNotSent(ei: usize) void {
    if (ei >= app_state.g_chat_outbox.items.len) return;
    if (app_state.g_chat_outbox.items[ei].state != .sending) return;
    app_state.g_chat_outbox.items[ei].state = .not_sent;
    app_state.g_chat_outbox.items[ei].left_box_ms = 0;
    _ = saveChatOutbox();
    chatOutboxChanged();
}

fn chatEchoConfirmWithBlock(ei: usize, block_start: usize, block_len: usize, stamp_ms: i64) void {
    if (ei >= app_state.g_chat_outbox.items.len) return;
    const e = app_state.g_chat_outbox.items[ei];
    var key_copy: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const klen: usize = e.key_len;
    @memcpy(key_copy[0..klen], e.key[0..klen]);
    var prefix: [CHAT_ECHO_PREFIX_CAP]u16 = undefined;
    const p = chatEchoNormalizePrefix(e.text, &prefix);
    if (p.len > 0) chatConfirmedAdd(key_copy[0..klen], p, block_start, block_len, stamp_ms);
    chatOutboxRemoveAtIn(&app_state.g_chat_outbox, std.heap.page_allocator, ei);
    _ = saveChatOutbox();
    chatOutboxChanged();
}

fn chatEchoConfirm(ei: usize) void {
    chatEchoConfirmWithBlock(ei, 0, 0, 0);
}

fn chatEchoTryMatchEntry(ei: usize) bool {
    if (ei >= app_state.g_chat_outbox.items.len) return false;
    const entry = app_state.g_chat_outbox.items[ei];
    const id = entry.id;
    if (chatOutboxShellForKey(entry.key[0..entry.key_len])) |si| {
        if (chatHistoryEntry(chatFileIdentityForShell(si))) |history| {
            var assignment: ChatEchoAssignment = .{};
            chatEchoAssignForKey(entry.key[0..entry.key_len], history.history.blocks.items, history.history.text.items, !history.history.restore_full and history.history.start == 0, &assignment);
            if (chatEchoAssignedBlock(&assignment, id)) |bi| {
                chatEchoStoreAnchors(&assignment);
                const block = history.history.blocks.items[bi];
                chatEchoConfirmWithBlock(ei, block.start, block.len, block.stamp_ms);
                return true;
            }
        }
    }
    if (app_state.active_shell >= app_state.shell_count) return false;
    var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const key = chatOutboxKeyForShell(app_state.active_shell, &key_buf);
    if (key.len == 0 or !std.mem.eql(u8, key, app_state.g_chat_outbox.items[ei].key[0..@as(usize, app_state.g_chat_outbox.items[ei].key_len)])) return false;
    var assignment: ChatEchoAssignment = .{};
    chatEchoAssignForKey(key, app_state.g_chat_blocks[0..app_state.g_chat_block_count], app_state.g_chat_capture[0..app_state.g_chat_last_len], chatEchoWindowFull(), &assignment);
    const bi = chatEchoAssignedBlock(&assignment, id) orelse return false;
    chatEchoStoreAnchors(&assignment);
    const ci = chatOutboxIndexById(id) orelse return false;
    chatEchoConfirmWithBlock(ci, app_state.g_chat_blocks[bi].start, app_state.g_chat_blocks[bi].len, app_state.g_chat_blocks[bi].stamp_ms);
    return true;
}

fn chatEchoLoadedMs() i64 {
    if (app_state.active_shell >= app_state.shell_count) return 0;
    for (app_state.g_chat_histories.items) |entry| {
        if (!entry.retired and entry.key.shell_id == app_state.shells[app_state.active_shell].shell_id) return entry.loaded_ms;
    }
    return 0;
}

fn chatEchoDeliveryEvidence(entry: ChatOutboxEntry) chat_echo.DeliveryEvidence {
    const si = chatOutboxShellForKey(entry.key[0..entry.key_len]) orelse return .{};
    for (app_state.g_chat_histories.items) |history| {
        if (history.retired or history.key.shell_id != app_state.shells[si].shell_id) continue;
        return history.history.deliveryEvidence(std.heap.page_allocator, .{ .text = entry.text, .prefix = &.{}, .anchor = entry.anchor }) catch .{};
    }
    return .{};
}

pub fn chatEchoMatchActive() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    const shell_id = app_state.shells[app_state.active_shell].shell_id;
    var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const key = chatOutboxKeyForShell(app_state.active_shell, &key_buf);
    if (key.len == 0) return;
    var expired = false;
    const loaded_ms = chatEchoLoadedMs();
    const now_ms: i64 = @intCast(GetTickCount64());
    const busy = app_state.shells[app_state.active_shell].activity == .active or app_state.g_chat_screen_working;
    for (app_state.g_chat_outbox.items) |*e| {
        if (e.state != .delivered or !std.mem.eql(u8, e.key[0..e.key_len], key)) continue;
        if (e.channel_sent or e.channel_pending) continue;
        e.delivery_watch.observe(busy, now_ms);
        if (!busy and (chat_echo.expiredSent(e.state, e.sent_tick_ms, now_ms) or e.delivery_watch.due(now_ms, loaded_ms))) {
            expired = true;
            break;
        }
    }
    if (!expired and app_state.g_chat_reconcile_shell == shell_id and app_state.g_chat_reconcile_hash == app_state.g_chat_last_hash and
        app_state.g_chat_reconcile_outbox == app_state.g_chat_outbox_revision and app_state.g_chat_reconcile_generation == app_state.g_chat_cache_generation) return;
    const reconcile_start = GetTickCount64();
    defer {
        app_state.g_chat_reconcile_shell = shell_id;
        app_state.g_chat_reconcile_hash = app_state.g_chat_last_hash;
        app_state.g_chat_reconcile_outbox = app_state.g_chat_outbox_revision;
        app_state.g_chat_reconcile_generation = app_state.g_chat_cache_generation;
        chatPerf("reconcile", reconcile_start, app_state.g_chat_block_count);
    }
    var changed = false;
    var i: usize = 0;
    var assignment: ChatEchoAssignment = .{};
    chatEchoAssignForKey(key, app_state.g_chat_blocks[0..app_state.g_chat_block_count], app_state.g_chat_capture[0..app_state.g_chat_last_len], chatEchoWindowFull(), &assignment);
    chatEchoStoreAnchors(&assignment);
    while (i < app_state.g_chat_outbox.items.len) {
        const e = app_state.g_chat_outbox.items[i];
        if (!std.mem.eql(u8, e.key[0..@as(usize, e.key_len)], key)) {
            i += 1;
            continue;
        }
        if (chatEchoAssignedBlock(&assignment, e.id)) |mi| {
            var prefix: [CHAT_ECHO_PREFIX_CAP]u16 = undefined;
            const p = chatEchoNormalizePrefix(e.text, &prefix);
            var key_copy: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
            @memcpy(key_copy[0..e.key_len], e.key[0..e.key_len]);
            chatConfirmedAdd(key_copy[0..e.key_len], p, app_state.g_chat_blocks[mi].start, app_state.g_chat_blocks[mi].len, app_state.g_chat_blocks[mi].stamp_ms);
            if (app_state.g_chat_verify_echo_id == e.id) chatVerifyClear();
            chatOutboxRemoveAtIn(&app_state.g_chat_outbox, std.heap.page_allocator, i);
            changed = true;
            continue;
        }
        if (e.channel_sent or e.channel_pending) {
            i += 1;
            continue;
        }
        var refused = false;
        var enqueued = false;
        if (e.state == .delivered or (e.state == .not_sent and e.write_started)) {
            const facts = chatEchoDeliveryEvidence(e);
            refused = facts.refused;
            enqueued = facts.enqueued and !chat_echo.pendingExpired(.delivered, e.sent_tick_ms, now_ms);
            if (app_state.g_chat_outbox.items[i].transcript_queued != enqueued) changed = true;
            app_state.g_chat_outbox.items[i].transcript_queued = enqueued;
            if (enqueued and e.state == .not_sent) {
                app_state.g_chat_outbox.items[i].state = .delivered;
                changed = true;
            }
            app_state.g_chat_outbox.items[i].delivery_watch.evidence(facts, now_ms);
        }
        if (e.state == .delivered and !enqueued and (refused or (!busy and (app_state.g_chat_outbox.items[i].delivery_watch.due(now_ms, loaded_ms) or chat_echo.expiredSent(e.state, e.sent_tick_ms, now_ms))))) {
            app_state.g_chat_outbox.items[i].state = .not_sent;
            app_state.g_chat_outbox.items[i].write_started = false;
            app_state.g_chat_outbox.items[i].retryable = true;
            app_state.g_chat_outbox.items[i].left_box_ms = 0;
            changed = true;
        }
        i += 1;
    }
    if (changed) {
        _ = saveChatOutbox();
        chatOutboxChanged();
    }
}

pub fn chatEchoCountDeliveredForShell(idx: u32) usize {
    if (idx >= app_state.shell_count) return 0;
    var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const key = chatOutboxKeyForShell(idx, &key_buf);
    if (key.len == 0) return 0;
    var n: usize = 0;
    for (app_state.g_chat_outbox.items) |e| {
        if (e.state == .delivered and std.mem.eql(u8, e.key[0..@as(usize, e.key_len)], key)) n += 1;
    }
    return n;
}

pub fn chatEchoPushQueuedNow() void {
    chatEchoPushQueuedForShell(app_state.active_shell);
}

fn chatEchoPushQueuedForShell(idx: u32) void {
    if (idx >= app_state.shell_count) return;
    const sent = if (chatTmuxSendEligible(idx))
        chatAgentKey(idx, 0x18)
    else
        chatShouldUseDirectInput(idx) and sendClaudeSendQueuedNowToShell(idx);
    if (!sent) {
        showHeaderNoticeAscii("Could not reach this terminal; press Ctrl+X Ctrl+S in the terminal", 4000, true);
        return;
    }
    app_state.g_chat_scroll_bottom_pending = true;
    if (app_state.g_main_hwnd != null) _ = SetTimer(app_state.g_main_hwnd, TIMER_CHAT_REFRESH, 120, null);
    showHeaderNoticeAscii("Asked Claude to take the queued message now", 2500, false);
}

fn chatSteerAfterDelivery(idx: u32, ei: usize) void {
    const entry = &app_state.g_chat_outbox.items[ei];
    if (!entry.steer_pending) return;
    entry.steer_pending = false;
    chatEchoPushQueuedForShell(idx);
}

pub fn chatEchoSendAgain(id: u64) void {
    const ei = chatOutboxIndexById(id) orelse return;
    const entry = &app_state.g_chat_outbox.items[ei];
    if (!chat_echo.pendingActions(entry.state).send_again or entry.channel_pending) return;
    if (chatEchoTryMatchEntry(ei)) return;
    const facts = chatEchoDeliveryEvidence(entry.*);
    const si = chatOutboxShellForKey(entry.key[0..entry.key_len]) orelse return;
    var prefix_buf: [20]u16 = undefined;
    const prefix = chatOutboxPrefixOf(entry.text, &prefix_buf);
    const held = if (prefix.len > 0) chatPromptStillInInputBox(si, prefix) else null;
    entry.sent_tick_ms = @intCast(GetTickCount64());
    entry.expires_ms = chatEchoAnchorNow(si).sent_ms +| 600_000;
    switch (chat_echo.resendDecision(false, facts, held)) {
        .mark_delivered => {
            entry.state = .delivered;
            entry.transcript_queued = facts.enqueued;
            entry.delivery_watch.evidence(facts, @intCast(GetTickCount64()));
        },
        .press_enter_only => {
            if (app_state.g_chat_verify_echo_id != 0 or chatLinkLooksDown(si)) {
                showHeaderNoticeAscii("Waiting for the terminal before sending again", 3000, true);
                return;
            }
            if (!sendEnterToShell(si)) return;
            entry.write_started = true;
            entry.channel_sent = false;
            entry.state = if (chatArmSendVerify(si, entry.text, id)) .sending else .not_sent;
            entry.delivery_watch = .{};
            entry.left_box_ms = 0;
        },
        .write_again => {
            entry.state = .queued;
            entry.write_started = false;
            entry.retryable = true;
            entry.delivery_watch = .{};
            entry.left_box_ms = 0;
            entry.channel_sent = false;
            entry.channel_retries = 0;
            entry.transcript_queued = false;
        },
    }
    _ = saveChatOutbox();
    app_state.g_chat_scroll_bottom_pending = true;
    chatOutboxChanged();
    chatOutboxTick();
}

pub fn chatEchoRemove(id: u64) void {
    const ei = chatOutboxIndexById(id) orelse return;
    if (!chat_echo.pendingActions(app_state.g_chat_outbox.items[ei].state).remove) return;
    const entry = app_state.g_chat_outbox.orderedRemove(ei);
    if (!saveChatOutbox()) {
        app_state.g_chat_outbox.insertAssumeCapacity(ei, entry);
        showHeaderNoticeAscii("Could not save message removal; try again", 3500, true);
        return;
    }
    if (entry.text.len > 0) std.heap.page_allocator.free(entry.text);
    if (app_state.g_chat_verify_echo_id == id) chatVerifyClear();
    chatOutboxChanged();
}

pub fn chatEchoRetryAllForActive() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const key = chatOutboxKeyForShell(app_state.active_shell, &key_buf);
    if (key.len == 0) return;
    var retried: u32 = 0;
    for (app_state.g_chat_outbox.items) |*e| {
        if (e.state != .not_sent or e.write_started or !std.mem.eql(u8, e.key[0..@as(usize, e.key_len)], key)) continue;
        e.state = .queued;
        e.expires_ms = chatEchoAnchorNow(app_state.active_shell).sent_ms +| 600_000;
        e.sent_tick_ms = @intCast(GetTickCount64());
        e.retryable = false;
        e.delivery_watch = .{};
        e.channel_sent = false;
        e.channel_retries = 0;
        e.transcript_queued = false;
        e.left_box_ms = 0;
        retried += 1;
    }
    if (retried == 0) {
        showHeaderNoticeAscii("No unsent messages for this tab", 3000, false);
        return;
    }
    _ = saveChatOutbox();
    app_state.g_chat_scroll_bottom_pending = true;
    chatOutboxChanged();
    chatOutboxTick();
    var buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Retrying {d} unsent message{s}", .{ retried, if (retried == 1) "" else "s" }) catch "Retrying unsent messages";
    showHeaderNoticeAscii(msg, 3000, false);
}

pub fn chatEchoDiscardUnsentForActive() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const key = chatOutboxKeyForShell(app_state.active_shell, &key_buf);
    if (key.len == 0) return;
    var dropped: u32 = 0;
    var i: usize = 0;
    while (i < app_state.g_chat_outbox.items.len) {
        const e = app_state.g_chat_outbox.items[i];
        if (e.state == .not_sent and std.mem.eql(u8, e.key[0..@as(usize, e.key_len)], key)) {
            chatOutboxRemoveAtIn(&app_state.g_chat_outbox, std.heap.page_allocator, i);
            dropped += 1;
        } else {
            i += 1;
        }
    }
    if (dropped == 0) {
        showHeaderNoticeAscii("No unsent messages for this tab", 3000, false);
        return;
    }
    _ = saveChatOutbox();
    chatOutboxChanged();
    var buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Discarded {d} unsent message{s}", .{ dropped, if (dropped == 1) "" else "s" }) catch "Discarded unsent messages";
    showHeaderNoticeAscii(msg, 3000, false);
}

fn chatOutboxPrefixOf(text: []const u16, out: *[20]u16) []const u16 {
    var start: usize = 0;
    while (start < text.len and (text[start] == ' ' or text[start] == '\t')) : (start += 1) {}
    var n: usize = 0;
    while (start + n < text.len and n < out.len) : (n += 1) {
        const c = text[start + n];
        if (c == '\r' or c == '\n') break;
        out[n] = c;
    }
    return out[0..n];
}

fn chatInputRowIsIdle(row: []const u16, attributes: []const u16) bool {
    if (row.len == 0) return false;
    if (row[0] != 0x276F and row[0] != 0x203A) return false;
    var blank = true;
    for (row[1..]) |c| {
        if (c != ' ' and c != 0xA0) blank = false;
    }
    if (blank) return true;
    if (attributes.len != row.len or row.len < 3 or (row[1] != ' ' and row[1] != 0xA0)) return false;
    const foreground_mask: u16 = 0x000F;
    const reverse_video: u16 = 0x4000;
    const gray_foreground: u16 = 0x0008;
    if (attributes[2] & reverse_video == 0) return false;
    const default_foreground = attributes[1] & foreground_mask;
    var saw_gray = false;
    for (row[2..], attributes[2..], 0..) |c, attr, i| {
        if (i != 0 and attr & reverse_video != 0) return false;
        if (c == ' ' or c == 0xA0) continue;
        const foreground = attr & foreground_mask;
        if (i == 0 and foreground == default_foreground) continue;
        if (foreground == default_foreground or foreground != gray_foreground) return false;
        saw_gray = true;
    }
    return saw_gray;
}

test "Chat View idle input row detection" {
    const idle = std.unicode.utf8ToUtf16LeStringLiteral("\u{276F}");
    const idle_gt = std.unicode.utf8ToUtf16LeStringLiteral("\u{203A}   ");
    const typed = std.unicode.utf8ToUtf16LeStringLiteral("\u{276F} hello");
    const not_prompt = std.unicode.utf8ToUtf16LeStringLiteral("$ hello");
    try std.testing.expect(chatInputRowIsIdle(idle, &.{}));
    try std.testing.expect(chatInputRowIsIdle(idle_gt, &.{}));
    try std.testing.expect(!chatInputRowIsIdle(typed, &.{}));
    try std.testing.expect(!chatInputRowIsIdle(not_prompt, &.{}));
    try std.testing.expect(!chatInputRowIsIdle(idle[0..0], &.{}));
}

test "ISSUE-599 suggestion row counts idle" {
    const row = std.unicode.utf8ToUtf16LeStringLiteral("\u{276F} hello");
    try std.testing.expect(chatInputRowIsIdle(row, &.{ 7, 7, 0x4008, 8, 8, 8, 8 }));
    try std.testing.expect(chatInputRowIsIdle(row, &.{ 7, 7, 0x4007, 8, 8, 8, 8 }));
    const alternate = std.unicode.utf8ToUtf16LeStringLiteral("\u{203A} hello");
    try std.testing.expect(chatInputRowIsIdle(alternate, &.{ 15, 15, 0x4008, 8, 8, 8, 8 }));
}

test "ISSUE-599 typed text row counts busy" {
    const row = std.unicode.utf8ToUtf16LeStringLiteral("\u{276F} hello");
    try std.testing.expect(!chatInputRowIsIdle(row, &.{ 7, 7, 7, 7, 7, 7, 7 }));
    try std.testing.expect(!chatInputRowIsIdle(row, &.{ 7, 7, 8, 8, 8, 8, 8 }));
    try std.testing.expect(!chatInputRowIsIdle(row, &.{ 7, 7, 0x4007, 7, 7, 7, 7 }));
    try std.testing.expect(!chatInputRowIsIdle(row, &.{ 8, 8, 0x4007, 7, 7, 7, 7 }));
    try std.testing.expect(!chatInputRowIsIdle(row, &.{ 8, 8, 0x4008, 8, 8, 8, 8 }));
    try std.testing.expect(!chatInputRowIsIdle(row, &.{ 7, 7, 0x4008, 8, 7, 8, 8 }));
    try std.testing.expect(!chatInputRowIsIdle(row, &.{ 7, 7, 0x4008, 8, 8 }));
}

test "ISSUE-599 typed text with the inverse cursor after it counts busy" {
    const row = std.unicode.utf8ToUtf16LeStringLiteral("\u{276F} hello ");
    try std.testing.expect(!chatInputRowIsIdle(row, &.{ 7, 7, 7, 7, 7, 7, 7, 0x4007 }));
    try std.testing.expect(!chatInputRowIsIdle(row, &.{ 7, 7, 8, 8, 8, 8, 8, 0x4008 }));
}

test "ISSUE-599 blank row still idle" {
    const row = std.unicode.utf8ToUtf16LeStringLiteral("\u{276F}  \u{A0}");
    try std.testing.expect(chatInputRowIsIdle(row, &.{ 7, 7, 0x4007, 7 }));
    try std.testing.expect(chatInputRowIsIdle(row, &.{}));
}

fn chatOutboxInputRowIdle(shell_index: u32) bool {
    const pid = app_state.shells[shell_index].pid;
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
    if (rows == 0 or rows * width > app_state.g_chat_raw.len) return false;
    const start_row: i16 = @intCast(bottom - @as(i32, @intCast(rows)) + 1);
    var chars_read: DWORD = 0;
    if (ReadConsoleOutputCharacterW(handle, &app_state.g_chat_raw, @intCast(rows * width), .{ .x = 0, .y = start_row }, &chars_read) == 0) return false;
    var r = rows;
    while (r > 0) {
        r -= 1;
        const line = chatTrimRawConsoleRow(width, chars_read, r);
        if (line.len > 0 and (line[0] == 0x276F or line[0] == 0x203A)) {
            if (chatInputRowIsIdle(line, &.{})) return true;
            const attributes = std.heap.page_allocator.alloc(u16, line.len) catch return false;
            defer std.heap.page_allocator.free(attributes);
            const column = (@intFromPtr(line.ptr) - @intFromPtr(&app_state.g_chat_raw[r * width])) / @sizeOf(u16);
            const origin = COORD{ .x = @intCast(column), .y = @intCast(@as(i32, start_row) + @as(i32, @intCast(r))) };
            var attributes_read: DWORD = 0;
            if (ReadConsoleOutputAttribute(handle, attributes.ptr, @intCast(line.len), origin, &attributes_read) == 0 or attributes_read != line.len) return false;
            return chatInputRowIsIdle(line, attributes);
        }
    }
    return false;
}

fn sendTextToShellVerifiedAt(shell_index: u32, send_text: []const u16, echo_id: u64) ShellSendResult {
    if (shell_index >= app_state.shell_count) return .write_failed;
    if (chatOutboxIndexById(echo_id)) |ei| {
        const entry = &app_state.g_chat_outbox.items[ei];
        if (entry.write_started) return .write_failed;
        entry.state = .sending;
        entry.anchor = chatEchoAnchorNow(shell_index);
        if (entry.expires_ms == 0) {
            entry.expires_ms = entry.anchor.sent_ms +| 600_000;
            entry.sent_tick_ms = @intCast(GetTickCount64());
        }
        entry.write_started = true;
        if (!saveChatOutbox()) {
            entry.write_started = false;
            entry.state = .queued;
            return .write_failed;
        }
    }
    if (chatTmuxSendEligible(shell_index) and app_state.g_chat_tmux_send_job != null) {
        if (chatOutboxIndexById(echo_id)) |ei| {
            app_state.g_chat_outbox.items[ei].write_started = false;
            app_state.g_chat_outbox.items[ei].state = .queued;
            _ = saveChatOutbox();
        }
        return .write_failed;
    }
    if (chatTmuxSendEligible(shell_index) and chatTmuxSendStart(shell_index, send_text, echo_id, false)) return .ok;
    return chatSendViaConsole(shell_index, send_text, echo_id);
}

fn chatSendViaConsole(shell_index: u32, send_text: []const u16, echo_id: u64) ShellSendResult {
    const direct_input = chatShouldUseDirectInput(shell_index);
    const sent = if (direct_input)
        pasteTextToShellDirectEx(shell_index, send_text, chatSendForceBracketed(shell_index))
    else
        sendLocalChatPrompt(shell_index, send_text);
    if (!sent) return .write_failed;
    if (direct_input) {
        Sleep(chatSendEnterDelayMs(app_state.shells[shell_index].kind));
        if (!sendEnterToShell(shell_index)) return .enter_failed;
        if (!chatArmSendVerify(shell_index, send_text, echo_id)) return .enter_failed;
    }
    return .ok;
}

fn chatOutboxReadyToType(channel: bool, direct: bool, busy: bool, screen_working_here: bool, input_row_idle: bool, is_active_shell: bool) bool {
    if (channel) return true;
    if (!direct and busy) return false;
    if (!direct and screen_working_here) return false;
    if (direct and !input_row_idle) return false;
    if (!channel and !direct and !is_active_shell) return false;
    return true;
}

fn chatOutboxTrySendEntry(shell_index: u32, e: usize) bool {
    if (e >= app_state.g_chat_outbox.items.len) return false;
    if (!chat_echo.mayType(app_state.g_chat_outbox.items[e].state, app_state.g_chat_outbox.items[e].write_started, false, false)) return false;
    if (chatOutboxFindSending(&app_state.g_chat_outbox) != null or app_state.g_chat_tmux_send_job != null) return false;
    if (chatLinkLooksDown(shell_index)) return false;
    const channel = chatTmuxSendEligible(shell_index);
    const direct = chatShouldUseDirectInput(shell_index);
    const key = app_state.g_chat_outbox.items[e].key[0..@as(usize, app_state.g_chat_outbox.items[e].key_len)];
    const first = chatOutboxFirstSendableIndexIn(&app_state.g_chat_outbox, key, channel or direct) orelse return false;
    if (first != e) return false;
    if (app_state.g_chat_outbox.items[e].retryable and chatEchoTryMatchEntry(e)) return true;
    if (app_state.g_chat_outbox.items[e].retryable and chatEchoDeliveryEvidence(app_state.g_chat_outbox.items[e]).enqueued) {
        app_state.g_chat_outbox.items[e].state = .delivered;
        app_state.g_chat_outbox.items[e].transcript_queued = true;
        app_state.g_chat_outbox.items[e].write_started = true;
        _ = saveChatOutbox();
        chatOutboxChanged();
        return true;
    }
    const busy = app_state.shells[shell_index].activity == .active;
    const screen_working_here = shell_index == app_state.active_shell and app_state.g_chat_screen_working;
    const input_row_idle = if (!channel and direct) chatOutboxInputRowIdle(shell_index) else false;
    if (!chatOutboxReadyToType(channel, direct, busy, screen_working_here, input_row_idle, shell_index == app_state.active_shell)) return false;
    const echo_id = app_state.g_chat_outbox.items[e].id;
    switch (sendTextToShellVerifiedAt(shell_index, app_state.g_chat_outbox.items[e].text, echo_id)) {
        .ok => {},
        .write_failed, .enter_failed => {
            app_state.g_chat_outbox.items[e].state = if (app_state.g_chat_outbox.items[e].write_started) .not_sent else .queued;
            _ = saveChatOutbox();
            if (app_state.g_chat_active) chatOutboxChanged();
            return false;
        },
    }
    app_state.g_chat_outbox.items[e].state = if (direct or app_state.g_chat_outbox.items[e].channel_pending) .sending else .delivered;
    app_state.g_chat_outbox.items[e].left_box_ms = 0;
    if (!app_state.g_chat_outbox.items[e].channel_pending) chatSteerAfterDelivery(shell_index, e);
    _ = saveChatOutbox();
    if (app_state.g_chat_active) chatOutboxChanged();
    return true;
}

pub fn chatOutboxTick() void {
    chatTmuxSendFinish();
    if (ISSUE_349_FULL_SETTLE) chatFullSettleFinish();
    chatTmuxSettle();
    var changed = false;
    const now_ms: i64 = @intCast(GetTickCount64());
    for (app_state.g_chat_outbox.items) |*entry| {
        if (!entry.channel_pending and chat_echo.orphanedSending(entry.state, entry.id, app_state.g_chat_verify_echo_id)) {
            entry.state = .delivered;
            entry.left_box_ms = GetTickCount64();
            changed = true;
        }
        if (entry.state != .delivered and entry.state != .sending) continue;
        if (chat_echo.expiredSent(.delivered, entry.sent_tick_ms, now_ms) and !entry.channel_pending and !entry.transcript_queued) {
            entry.state = .not_sent;
            entry.retryable = true;
            entry.transcript_queued = false;
            changed = true;
            continue;
        }
        const idx = chatOutboxShellForKey(entry.key[0..entry.key_len]) orelse continue;
        const busy = app_state.shells[idx].activity == .active or (idx == app_state.active_shell and app_state.g_chat_screen_working);
        entry.delivery_watch.observe(busy, now_ms);
    }
    if (changed) {
        _ = saveChatOutbox();
        chatOutboxChanged();
    }
    if (app_state.g_chat_active) chatEchoMatchActive();
    if (chatOutboxFindSending(&app_state.g_chat_outbox) == null) {
        for (0..app_state.g_chat_outbox.items.len) |e| {
            const key = app_state.g_chat_outbox.items[e].key[0..@as(usize, app_state.g_chat_outbox.items[e].key_len)];
            const idx = chatOutboxShellForKey(key) orelse continue;
            if (chatLinkLooksDown(idx)) continue;
            if (chatOutboxTrySendEntry(idx, e)) {
                sshOutboxFlushed(idx);
                break;
            }
        }
    }
    if (ISSUE_349_FULL_SETTLE) chatFullSettleStart();
    armChatOutboxTimerIfNeeded();
}

pub fn chatOutboxFlushActiveNow() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    if (chatOutboxCountForShell(app_state.active_shell) == 0) {
        showHeaderNoticeAscii("No queued messages for this tab", 3000, false);
        return;
    }
    if (chatOutboxFindSending(&app_state.g_chat_outbox) != null) {
        showHeaderNoticeAscii("A queued message is already sending", 3000, false);
        return;
    }
    var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const key = chatOutboxKeyForShell(app_state.active_shell, &key_buf);
    const claude_buffer = !chatLinkLooksDown(app_state.active_shell) and (chatTmuxSendEligible(app_state.active_shell) or chatShouldUseDirectInput(app_state.active_shell));
    const e = chatOutboxFirstSendableIndexIn(&app_state.g_chat_outbox, key, claude_buffer) orelse {
        showHeaderNoticeAscii("No queued messages for this tab", 3000, false);
        return;
    };
    if (chatOutboxTrySendEntry(app_state.active_shell, e)) {
        showHeaderNoticeAscii("Sending queued message...", 2500, false);
    } else {
        showHeaderNoticeAscii("Waiting for the agent's input prompt", 3500, true);
    }
}

pub fn chatOutboxClearActive() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
    const key = chatOutboxKeyForShell(app_state.active_shell, &key_buf);
    if (key.len == 0) return;
    const dropped = chatOutboxClearIn(&app_state.g_chat_outbox, std.heap.page_allocator, key);
    if (dropped == 0) {
        showHeaderNoticeAscii("No queued messages for this tab", 3000, false);
        return;
    }
    _ = saveChatOutbox();
    chatOutboxChanged();
    var buf: [80]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Dropped {d} queued message{s}", .{ dropped, if (dropped == 1) "" else "s" }) catch "Dropped queued messages";
    showHeaderNoticeAscii(msg, 3500, false);
}

pub fn armSshReconnectTimerIfNeeded() void {
    if (chatBenchEnabled() or app_state.g_main_hwnd == null) return;
    var any = ssh_probe_job != null;
    var urgent = any;
    for (app_state.shells[0..app_state.shell_count]) |shell| {
        if (shell.kind != .tmux and shell.kind != .vps and shell.kind != .vps2) continue;
        if (shell.console_inflight or shell.ssh_reconnect.phase == .closed or shell.ssh_reconnect.phase == .ended) continue;
        any = true;
        if (shell.disconnected or shell.ssh_reconnect.phase != .connected) urgent = true;
    }
    if (any and ssh_probe_pending_request) urgent = true;
    const interval: UINT = if (urgent) 1000 else if (any) 15_000 else 0;
    if (interval == app_state.g_ssh_reconnect_timer_ms) return;
    app_state.g_ssh_reconnect_timer_ms = interval;
    if (interval != 0) {
        _ = SetTimer(app_state.g_main_hwnd, TIMER_SSH_RECONNECT, interval, null);
    } else {
        _ = KillTimer(app_state.g_main_hwnd, TIMER_SSH_RECONNECT);
    }
}

pub fn sshReconnectArm(affected: ?u32, reason: []const u8) void {
    if (chatBenchEnabled()) return;
    const now = GetTickCount64();
    for (app_state.shells[0..app_state.shell_count], 0..) |*shell, i| {
        if (affected != null and affected.? != i) continue;
        if (shell.kind != .tmux and shell.kind != .vps and shell.kind != .vps2) continue;
        if (shell.console_inflight or shell.ssh_reconnect.phase == .closed or shell.ssh_reconnect.phase == .ended) continue;
        if (affected != null) {
            shell.ssh_reconnect.lost(now, now ^ shell.shell_id);
        } else if (shell.process == null or !shellProcessAliveForRead(i)) {
            sshDisconnect(@intCast(i), reason);
        }
    }
    if (affected == null) sshRequestSessionProbe();
    armSshReconnectTimerIfNeeded();
}

pub fn sshDisconnect(idx: u32, reason: []const u8) void {
    if (chatBenchEnabled() or idx >= app_state.shell_count) return;
    const shell = &app_state.shells[idx];
    if (shell.console_inflight or shell.ssh_reconnect.phase == .closed or shell.ssh_reconnect.phase == .ended) return;
    var exit_code: DWORD = std.math.maxInt(DWORD);
    const got_code = shell.process != null and GetExitCodeProcess(shell.process, &exit_code) != 0;
    if (shell.kind == .tmux and got_code and exit_code == 1 and GetTickCount64() -| shell.spawn_tick <= 3000) {
        shell.ssh_reconnect.awaiting_probe = true;
        sshRequestSessionProbe();
    }
    var buf: [224]u8 = undefined;
    debugLog(std.fmt.bufPrint(&buf, "ssh-reconnect disconnect id={d} reason={s} exit_code={d} known={} phase={s}", .{ shell.shell_id, reason, exit_code, got_code, @tagName(shell.ssh_reconnect.phase) }) catch "ssh-reconnect disconnect log-overflow");
    if (!shell.disconnected) sshRequestSessionProbe();
    shell.ssh_reconnect.confirmDisconnect(GetTickCount64(), reason, shell.process != null and shellProcessAliveForRead(idx));
    markSshTabDisconnected(idx);
}

pub fn sshReconnectNow(idx: u32) void {
    if (chatBenchEnabled() or idx >= app_state.shell_count) return;
    const shell = &app_state.shells[idx];
    if (shell.kind != .tmux and shell.kind != .vps and shell.kind != .vps2) return;
    if (shell.console_inflight or shell.ssh_reconnect.phase == .closed or shell.ssh_reconnect.phase == .reconnecting) return;
    const was_ended = shell.ssh_reconnect.phase == .ended;
    shell.ssh_reconnect.manual(GetTickCount64());
    shell.disconnected = true;
    if (was_ended) @import("drawing.zig").invalidateReconnectContent(idx);
    sshReconnectAttempt(idx);
}

fn sshReconnectAttempt(idx: u32) void {
    const shell = &app_state.shells[idx];
    if (shell.console_inflight or shell.ssh_reconnect.phase != .disconnected) return;
    shell.ssh_reconnect.start();
    var buf: [160]u8 = undefined;
    debugLog(std.fmt.bufPrint(&buf, "ssh-reconnect attempt={d} id={d} delay_ms={d}", .{ shell.ssh_reconnect.attempts, shell.shell_id, shell.ssh_reconnect.delay_ms }) catch return);
    if (!respawnShellInPlace(idx, true)) sshDisconnect(idx, "spawn-failed");
    armSshReconnectTimerIfNeeded();
}

fn sshNetworkVeto(idx: u32, now: u64) bool {
    const shell = &app_state.shells[idx];
    const veto = shell.ssh_reconnect.networkVeto(now, chatNetworkReportsConnected());
    if (veto) {
        var buf: [160]u8 = undefined;
        debugLog(std.fmt.bufPrint(&buf, "ssh-reconnect veto reason=windows-network-offline id={d} cap_ms={d}", .{ shell.shell_id, shell.ssh_reconnect.delay_ms }) catch "ssh-reconnect veto reason=windows-network-offline");
    }
    return veto;
}

pub fn sshAutoReconnectTick() void {
    if (chatBenchEnabled()) return;
    sshProbeFinish();
    const now = GetTickCount64();
    var attempted = [_]bool{false} ** 256;
    for (0..app_state.shell_count) |i| {
        const shell = &app_state.shells[i];
        if (shell.kind != .tmux and shell.kind != .vps and shell.kind != .vps2) continue;
        if (shell.console_inflight or shell.ssh_reconnect.phase == .closed or shell.ssh_reconnect.phase == .ended) continue;
        if (shell.process == null and !shell.disconnected) {
            sshDisconnect(@intCast(i), "process-missing-poll");
        } else if (shell.process != null and !shellProcessAliveForRead(i)) {
            sshDisconnect(@intCast(i), "process-exit-poll");
        } else if (shell.ssh_reconnect.phase == .reconnecting and now -| shell.spawn_tick >= 60_000) {
            sshDisconnect(@intCast(i), "attach-timeout");
        } else if (shell.kind != .tmux and shell.ssh_reconnect.phase == .reconnecting and now -| shell.spawn_tick >= 3000) {
            sshReconnectOk(@intCast(i));
        }
        if (shell.disconnected and shell.ssh_reconnect.phase == .connected) sshReconnectArm(@intCast(i), "link-disconnected");
        shell.ssh_reconnect.expireProbeWait(now, shell.spawn_tick);
        const host = shell.tmux_host;
        if (!attempted[host] and shell.ssh_reconnect.due(now)) {
            if (sshNetworkVeto(@intCast(i), now)) continue;
            attempted[host] = true;
            sshReconnectAttempt(@intCast(i));
        }
    }
    sshProbeStart();
    armSshReconnectTimerIfNeeded();
    if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].disconnected and
        @import("drawing.zig").reconnectTabVisible(app_state.active_shell))
    {
        var header: RECT = undefined;
        if (GetClientRect(app_state.g_main_hwnd, &header) != 0) {
            header.top = threadTitleTop();
            header.bottom = header.top + threadTitleHeight();
            _ = InvalidateRect(app_state.g_main_hwnd, &header, 0);
        }
    }
}

fn sshReconnectOk(idx: u32) void {
    const shell = &app_state.shells[idx];
    if (shell.ssh_reconnect.phase == .ended or shell.ssh_reconnect.phase == .closed) return;
    const state_changed = shell.disconnected;
    shell.ssh_reconnect.ok();
    shell.disconnected = false;
    var buf: [128]u8 = undefined;
    debugLog(std.fmt.bufPrint(&buf, "ssh-reconnect ok id={d}", .{shell.shell_id}) catch return);
    armChatOutboxTimerIfNeeded();
    @import("console.zig").showReconnectedConsole(idx);
    if (state_changed) @import("drawing.zig").invalidateReconnectContent(idx);
    saveSession();
}

pub fn sshRequestSessionProbe() void {
    ssh_probe_pending_request = true;
    ssh_probe_next_tick = 0;
    armSshReconnectTimerIfNeeded();
}

fn sshSessionEnded(idx: u32) void {
    if (chatBenchEnabled()) return;
    const shell = &app_state.shells[idx];
    if (shell.ssh_reconnect.phase == .ended or shell.ssh_reconnect.phase == .closed or (shell.process != null and shellProcessAliveForRead(idx))) return;
    @import("workspaces.zig").unregisterShellExitWait(idx);
    if (shell.hwnd != null) _ = @import("focus.zig").ShowWindow(shell.hwnd, @import("win32.zig").SW_HIDE);
    shell.hwnd = null;
    if (shell.pid != 0) @import("console.zig").killProcessTree(shell.pid);
    if (shell.process != null) _ = CloseHandle(shell.process);
    shell.process = null;
    shell.pid = 0;
    shell.disconnected = true;
    shell.activity = .idle;
    shell.needs_attention = false;
    shell.ssh_reconnect.end();
    var buf: [128]u8 = undefined;
    debugLog(std.fmt.bufPrint(&buf, "ssh-reconnect ended id={d} reason=session-gone", .{shell.shell_id}) catch "ssh-reconnect ended reason=session-gone");
    @import("drawing.zig").invalidateReconnectContent(idx);
    saveSession();
}

const SshProbeJob = struct {
    const Item = struct { id: u32, host: u8, session: [64]u8, len: u32, spawn_tick: u64 = 0, attached: bool = false, session_gone: bool = false };
    items: [256]Item = undefined,
    count: usize = 0,
    healthy: [256]bool = @splat(false),
    results: [256]struct {
        exit_code: u32 = std.math.maxInt(u32),
        ms: u64 = 0,
        tail: [60]u8 = @splat(0),
        len: usize = 0,
    } = @splat(.{}),
    finished: std.atomic.Value(bool) = .init(false),
    abandoned: std.atomic.Value(bool) = .init(false),
    owners: std.atomic.Value(u32) = .init(2),
    started_tick: u64 = 0,
};

var ssh_probe_job: ?*SshProbeJob = null;
var ssh_probe_next_tick: u64 = 0;
var ssh_probe_pending_request: bool = false;
var ssh_probe_misses: [256]u8 = @splat(0);

fn sshProbeStart() void {
    if (chatBenchEnabled()) return;
    if (ssh_probe_job != null or GetTickCount64() < ssh_probe_next_tick) return;
    const job = std.heap.page_allocator.create(SshProbeJob) catch return;
    job.* = .{ .started_tick = GetTickCount64() };
    for (app_state.shells[0..app_state.shell_count]) |shell| {
        if (shell.console_inflight or shell.kind != .tmux or shell.ssh_reconnect.phase == .closed or shell.ssh_reconnect.phase == .ended or shell.tmux_session_len == 0 or (!shell.ssh_reconnect.awaiting_probe and GetTickCount64() -| shell.spawn_tick < 3000)) continue;
        job.items[job.count] = .{ .id = shell.shell_id, .host = shell.tmux_host, .session = shell.tmux_session, .len = shell.tmux_session_len, .spawn_tick = shell.spawn_tick };
        job.count += 1;
    }
    if (job.count == 0) {
        ssh_probe_pending_request = false;
        std.heap.page_allocator.destroy(job);
        return;
    }
    const thread = std.Thread.spawn(.{}, sshProbeThread, .{job}) catch {
        std.heap.page_allocator.destroy(job);
        debugLog("ssh-probe start-failed reason=thread-spawn");
        ssh_probe_next_tick = GetTickCount64() + 15_000;
        return;
    };
    ssh_probe_job = job;
    ssh_probe_pending_request = false;
    thread.detach();
}

fn sshProbeThread(job: *SshProbeJob) void {
    defer {
        job.finished.store(true, .release);
        if (job.owners.fetchSub(1, .acq_rel) == 1) std.heap.page_allocator.destroy(job);
    }
    var checked = [_]bool{false} ** 256;
    for (job.items[0..job.count]) |item| {
        if (job.abandoned.load(.acquire)) return;
        if (checked[item.host]) continue;
        checked[item.host] = true;
        var wide: [2048]u16 = undefined;
        var pos: usize = 0;
        if (!@import("console.zig").appendSshExe(&wide, &pos)) continue;
        if (!@import("console.zig").appendWideAscii(&wide, &pos, "-T -o BatchMode=yes -o ConnectTimeout=5 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 ")) continue;
        if (!@import("console.zig").appendWideAscii(&wide, &pos, @import("console.zig").tmuxSshTarget(item.host))) continue;
        if (!@import("console.zig").appendWideAscii(&wide, &pos, " \"tmux list-clients -F '#{session_name}' 2>/dev/null; listing=$(tmux list-sessions -F '@@S #{session_name}' 2>&1); if [ $? -eq 0 ]; then printf '%s\\n' \\\"$listing\\\"; printf '@@LS_OK@@\\n'; else case $listing in *'no server running'*|*'error connecting to'*'No such file or directory'*) printf '@@LS_OK@@\\n';; *) printf '%s\\n' \\\"$listing\\\" >&2;; esac; fi; printf '@@MP_LIVE@@\\n'\"")) continue;
        const a = std.heap.page_allocator;
        const cmd = std.unicode.utf16LeToUtf8Alloc(a, wide[0..pos]) catch continue;
        defer a.free(cmd);
        var output: [32768]u8 = undefined;
        const started = GetTickCount64();
        const result = @import("vps.zig").sshOneShotCaptureInput(cmd, &output, null, 10_000);
        const probe = &job.results[item.host];
        probe.exit_code = result.exit_code;
        probe.ms = GetTickCount64() -| started;
        probe.len = @min(result.len, probe.tail.len);
        for (output[result.len - probe.len .. result.len], 0..) |byte, i| {
            probe.tail[i] = if (byte < 0x20 or byte == 0x7f) ' ' else byte;
        }
        job.healthy[item.host] = result.success and result.exit_code == 0 and @import("ssh_reconnect.zig").attached(output[0..result.len], "@@MP_LIVE@@") and @import("ssh_reconnect.zig").attached(output[0..result.len], "@@LS_OK@@");
        for (job.items[0..job.count]) |*candidate| {
            if (candidate.host != item.host) continue;
            candidate.attached = @import("ssh_reconnect.zig").attached(output[0..result.len], candidate.session[0..candidate.len]);
            candidate.session_gone = @import("ssh_reconnect.zig").sessionGone(output[0..result.len], candidate.session[0..candidate.len], result.success, result.exit_code);
        }
    }
}

fn sshProbeFinish() void {
    if (chatBenchEnabled()) return;
    const job = ssh_probe_job orelse return;
    if (!job.finished.load(.acquire)) {
        if (GetTickCount64() -| job.started_tick < 45_000) return;
        job.abandoned.store(true, .release);
        ssh_probe_job = null;
        ssh_probe_next_tick = 0;
        debugLog("ssh-probe abandoned reason=timeout timeout_ms=45000");
        if (job.owners.fetchSub(1, .acq_rel) == 1) std.heap.page_allocator.destroy(job);
        return;
    }
    defer {
        if (job.owners.fetchSub(1, .acq_rel) == 1) std.heap.page_allocator.destroy(job);
        ssh_probe_job = null;
        ssh_probe_next_tick = if (ssh_probe_pending_request) 0 else GetTickCount64() + 15_000;
    }
    var checked: [256]bool = @splat(false);
    for (job.items[0..job.count]) |item| {
        if (checked[item.host]) continue;
        checked[item.host] = true;
        ssh_probe_misses[item.host] = @import("ssh_reconnect.zig").probeMisses(ssh_probe_misses[item.host], job.healthy[item.host]);
        const probe = job.results[item.host];
        var buf: [224]u8 = undefined;
        debugLog(std.fmt.bufPrint(&buf, "ssh-probe result host={d} ok={d} exit={d} ms={d} misses={d} tail={s}", .{ item.host, @intFromBool(job.healthy[item.host]), probe.exit_code, probe.ms, ssh_probe_misses[item.host], probe.tail[0..probe.len] }) catch "ssh-probe result log-overflow");
    }
    for (job.items[0..job.count]) |item| {
        const idx = @import("inbox.zig").findShellById(item.id) orelse continue;
        const shell = &app_state.shells[idx];
        var tab_log: [224]u8 = undefined;
        debugLog(std.fmt.bufPrint(&tab_log, "ssh-probe tab id={d} phase={s} disconnected={} live={} attached={} gone={} incarnation={}", .{ shell.shell_id, @tagName(shell.ssh_reconnect.phase), shell.disconnected, shell.process != null and shellProcessAliveForRead(idx), item.attached, item.session_gone, shell.spawn_tick == item.spawn_tick }) catch "ssh-probe tab log-overflow");
        if (shell.console_inflight or shell.ssh_reconnect.phase == .closed or shell.ssh_reconnect.phase == .ended or shell.spawn_tick != item.spawn_tick or shell.tmux_host != item.host or
            !std.mem.eql(u8, shell.tmux_session[0..shell.tmux_session_len], item.session[0..item.len])) continue;
        const process_alive = shell.process != null and shellProcessAliveForRead(idx);
        if (shell.ssh_reconnect.observeGone(item.session_gone, process_alive, GetTickCount64())) {
            sshSessionEnded(idx);
            continue;
        }
        if (shell.ssh_reconnect.gone_results > 0) {
            sshRequestSessionProbe();
            continue;
        }
        shell.ssh_reconnect.awaiting_probe = false;
        if (item.session_gone and process_alive) continue;
        if (app_state.shells[idx].process == null) {
            sshDisconnect(idx, "probe-process-missing");
        } else if (!job.healthy[item.host]) {
            if (@import("ssh_reconnect.zig").probeUnreachable(ssh_probe_misses[item.host], shellProcessAliveForRead(idx))) {
                sshDisconnect(idx, "probe-unreachable");
            }
        } else if (!item.attached) {
            if (shell.ssh_reconnect.phase != .reconnecting and !shell.ssh_reconnect.create_session and shell.ssh_reconnect.healthy_attach) sshDisconnect(idx, "tmux-detached");
        } else if (process_alive) {
            shell.ssh_reconnect.healthy_attach = true;
            shell.ssh_reconnect.ever_healthy = true;
            shell.ssh_reconnect.creating_session = false;
            if (shell.disconnected) sshReconnectOk(idx);
        }
    }
}

test "Chat View outbox is FIFO and capped per key" {
    const allocator = std.testing.allocator;
    var list: std.ArrayList(ChatOutboxEntry) = .empty;
    defer {
        for (list.items) |e| if (e.text.len > 0) allocator.free(e.text);
        list.deinit(allocator);
    }
    const key_a = "tmux:0:alpha";
    const key_b = "tmux:1:beta";
    for (0..25) |i| {
        var buf: [8]u16 = undefined;
        for (0..8) |j| buf[j] = @intCast('a' + ((i + j) % 26));
        try std.testing.expectEqual(i < CHAT_OUTBOX_MAX_PER_KEY, chatOutboxEnqueueIn(&list, allocator, key_a, &buf));
    }
    try std.testing.expectEqual(@as(usize, CHAT_OUTBOX_MAX_PER_KEY), chatOutboxCountIn(&list, key_a));
    var first_buf: [8]u16 = undefined;
    for (0..8) |j| first_buf[j] = @intCast('a' + (j % 26));
    const first = chatOutboxFirstIndexIn(&list, key_a) orelse return error.Missing;
    try std.testing.expect(std.mem.eql(u16, list.items[first].text, &first_buf));
    const msg_b = std.unicode.utf8ToUtf16LeStringLiteral("beta");
    try std.testing.expect(chatOutboxEnqueueIn(&list, allocator, key_b, msg_b));
    try std.testing.expectEqual(@as(usize, 1), chatOutboxCountIn(&list, key_b));
    try std.testing.expect((chatOutboxFirstIndexIn(&list, key_a) orelse 999) < (chatOutboxFirstIndexIn(&list, key_b) orelse 0));
    try std.testing.expectEqual(@as(u32, 20), chatOutboxClearIn(&list, allocator, key_a));
    try std.testing.expectEqual(@as(usize, 0), chatOutboxCountIn(&list, key_a));
    try std.testing.expectEqual(@as(usize, 1), chatOutboxCountIn(&list, key_b));
}

test "Chat View outbox JSON round-trips quotes, newlines and unicode" {
    const allocator = std.testing.allocator;
    var list: std.ArrayList(ChatOutboxEntry) = .empty;
    defer {
        for (list.items) |e| if (e.text.len > 0) allocator.free(e.text);
        list.deinit(allocator);
    }
    const msg1 = std.unicode.utf8ToUtf16LeStringLiteral("line one\nline \"two\"\tend");
    const msg2 = std.unicode.utf8ToUtf16LeStringLiteral("\u{00E9}\u{4E2D}\u{1F600} unicode");
    try std.testing.expect(chatOutboxEnqueueIn(&list, allocator, "tmux:2:gamma", msg1));
    try std.testing.expect(chatOutboxEnqueueIn(&list, allocator, "tmux:2:gamma", msg2));
    try std.testing.expect(chatOutboxEnqueueIn(&list, allocator, "cmd:Local", msg1));
    var jlen: usize = 0;
    const json = chatOutboxSerialize(&list, allocator, &jlen) orelse return error.SerializeFailed;
    defer allocator.free(json);

    var parsed: std.ArrayList(ChatOutboxEntry) = .empty;
    defer {
        for (parsed.items) |e| if (e.text.len > 0) allocator.free(e.text);
        parsed.deinit(allocator);
    }
    chatOutboxParseJson(&parsed, allocator, json[0..jlen]);
    try std.testing.expectEqual(@as(usize, 3), parsed.items.len);
    try std.testing.expectEqual(@as(usize, 2), chatOutboxCountIn(&parsed, "tmux:2:gamma"));
    try std.testing.expectEqual(@as(usize, 1), chatOutboxCountIn(&parsed, "cmd:Local"));
    const g0 = chatOutboxFirstIndexIn(&parsed, "tmux:2:gamma") orelse return error.Missing;
    try std.testing.expect(std.mem.eql(u16, parsed.items[g0].text, msg1));
    try std.testing.expect(std.mem.eql(u16, parsed.items[g0 + 1].text, msg2));
}

test "outbox reordered queues and raw Unicode use the old-version state fallbacks" {
    const allocator = std.testing.allocator;
    var list: std.ArrayList(ChatOutboxEntry) = .empty;
    defer {
        for (list.items) |entry| allocator.free(entry.text);
        list.deinit(allocator);
    }
    const json = "{\"queues\":[{\"messages\":[{\"extra\":{\"t\":\"wrong\"},\"t\":\"Raw 日🚀 \\\"key\\\":\\\"fake\\\" } ]\",\"s\":1},{\"t\":\"queued\"}],\"key\":\"tmux:2:real\"}],\"version\":1,\"extra\":true}";
    chatOutboxParseJson(&list, allocator, json);
    try std.testing.expectEqual(@as(usize, 2), list.items.len);
    try std.testing.expectEqual(ChatEchoState.not_sent, list.items[0].state);
    try std.testing.expect(list.items[0].write_started);
    try std.testing.expectEqual(ChatEchoState.queued, list.items[1].state);
    try std.testing.expect(!list.items[1].write_started);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Raw 日🚀 \"key\":\"fake\" } ]"), list.items[0].text);
}

test "Chat View outbox prefix matches the Enter-retry prefix" {
    var out: [20]u16 = undefined;
    const text = std.unicode.utf8ToUtf16LeStringLiteral("   hello world");
    const prefix = chatOutboxPrefixOf(text, &out);
    const expected = std.unicode.utf8ToUtf16LeStringLiteral("hello world");
    try std.testing.expect(std.mem.eql(u16, prefix, expected));
}

test "Chat View echo state on load never retries a possibly typed send" {
    try std.testing.expectEqual(ChatEchoState.queued, chatEchoStateOnLoad(0));
    try std.testing.expectEqual(ChatEchoState.not_sent, chatEchoStateOnLoad(1));
    try std.testing.expectEqual(ChatEchoState.not_sent, chatEchoStateOnLoad(2));
    try std.testing.expectEqual(ChatEchoState.delivered, chatEchoStateOnLoad(3));
}

test "Chat View echo prefix collapses whitespace" {
    var out: [CHAT_ECHO_PREFIX_CAP]u16 = undefined;
    const text = std.unicode.utf8ToUtf16LeStringLiteral("  hello\n   wrapped\tworld  ");
    const p = chatEchoNormalizePrefix(text, &out);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("hello wrapped world"), p);
    const long = std.unicode.utf8ToUtf16LeStringLiteral("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ");
    try std.testing.expectEqual(@as(usize, CHAT_ECHO_PREFIX_CAP), chatEchoNormalizePrefix(long, &out).len);
}

fn chatEchoTestAssign(blocks: []const ChatBlock, buf: []const u16, anchor: chat_echo.Anchor, window_full: bool, text: []const u16) !?usize {
    const allocator = std.testing.allocator;
    const saved = app_state.g_chat_outbox;
    app_state.g_chat_outbox = .empty;
    defer {
        for (app_state.g_chat_outbox.items) |e| if (e.text.len > 0) allocator.free(e.text);
        app_state.g_chat_outbox.deinit(allocator);
        app_state.g_chat_outbox = saved;
    }
    if (!chatOutboxEnqueueInState(&app_state.g_chat_outbox, allocator, "tmux:7:echo-test", text, .sending)) return error.EnqueueFailed;
    app_state.g_chat_outbox.items[0].write_started = true;
    app_state.g_chat_outbox.items[0].anchor = anchor;
    var assignment: ChatEchoAssignment = .{};
    chatEchoAssignForKey("tmux:7:echo-test", blocks, buf, window_full, &assignment);
    return chatEchoAssignedBlock(&assignment, app_state.g_chat_outbox.items[0].id);
}

test "Chat View echo matches only user blocks after the baseline" {
    const buf = std.unicode.utf8ToUtf16LeStringLiteral(
        "\u{276f} old message\r\n\r\n\u{25cf} reply\r\n\r\n\u{276f} hello wrapped\r\n",
    );
    var blocks: [8]ChatBlock = undefined;
    const n = chatClassifyBlocks(buf, &blocks);
    const text = std.unicode.utf8ToUtf16LeStringLiteral("hello   wrapped");
    try std.testing.expectEqual(@as(?usize, 2), try chatEchoTestAssign(blocks[0..n], buf, .{ .user_count = 1, .counted = true }, false, text));
    try std.testing.expect((try chatEchoTestAssign(blocks[0..n], buf, .{ .user_count = 2, .counted = true }, false, text)) == null);
    const other = std.unicode.utf8ToUtf16LeStringLiteral("totally other");
    try std.testing.expect((try chatEchoTestAssign(blocks[0..n], buf, .{ .counted = true }, false, other)) == null);
}

test "Chat View echo in a full transcript window confirms only from newer entries" {
    const buf = std.unicode.utf8ToUtf16LeStringLiteral(
        "\u{276f} hello wrapped\r\n\r\n\u{25cf} reply\r\n\r\n\u{276f} hello wrapped\r\n",
    );
    var blocks: [8]ChatBlock = undefined;
    const n = chatClassifyBlocks(buf, &blocks);
    const text = std.unicode.utf8ToUtf16LeStringLiteral("hello wrapped");
    try std.testing.expect((try chatEchoTestAssign(blocks[0..n], buf, .{ .user_count = 1, .counted = true }, true, text)) == null);
    blocks[0].stamp_ms = 1_000;
    blocks[2].stamp_ms = 3_000;
    try std.testing.expectEqual(@as(?usize, 2), try chatEchoTestAssign(blocks[0..n], buf, .{ .after_ms = 2_000 }, true, text));
    try std.testing.expect((try chatEchoTestAssign(blocks[0..n], buf, .{ .after_ms = 3_000 }, true, text)) == null);
}

test "Chat View echo persistence retains a reserved send without retyping" {
    const allocator = std.testing.allocator;
    var list: std.ArrayList(ChatOutboxEntry) = .empty;
    defer {
        for (list.items) |e| if (e.text.len > 0) allocator.free(e.text);
        list.deinit(allocator);
    }
    const msg = std.unicode.utf8ToUtf16LeStringLiteral("unconfirmed hello");
    try std.testing.expect(chatOutboxEnqueueInState(&list, allocator, "tmux:0:alpha", msg, .sending));
    const queued = std.unicode.utf8ToUtf16LeStringLiteral("waiting hello");
    try std.testing.expect(chatOutboxEnqueueInState(&list, allocator, "tmux:0:alpha", queued, .queued));
    list.items[0].anchor = .{ .after_ms = 1_760_170_353_456, .sent_ms = 1_760_170_354_000 };
    list.items[0].write_started = true;
    var jlen: usize = 0;
    const json = chatOutboxSerialize(&list, allocator, &jlen) orelse return error.SerializeFailed;
    defer allocator.free(json);
    var parsed: std.ArrayList(ChatOutboxEntry) = .empty;
    defer {
        for (parsed.items) |e| if (e.text.len > 0) allocator.free(e.text);
        parsed.deinit(allocator);
    }
    chatOutboxParseJson(&parsed, allocator, json[0..jlen]);
    try std.testing.expectEqual(@as(usize, 2), parsed.items.len);
    try std.testing.expectEqual(ChatEchoState.not_sent, parsed.items[0].state);
    try std.testing.expectEqual(ChatEchoState.queued, parsed.items[1].state);
    try std.testing.expect(parsed.items[0].id != 0 and parsed.items[0].id != parsed.items[1].id);
    try std.testing.expectEqual(@as(i64, 1_760_170_353_456), parsed.items[0].anchor.after_ms);
    try std.testing.expectEqual(@as(i64, 1_760_170_354_000), parsed.items[0].anchor.sent_ms);
    try std.testing.expectEqual(@as(i64, 0), parsed.items[1].anchor.after_ms);
}

test "Chat View outbox never auto-sends an already-delivered message" {
    try std.testing.expect(chatOutboxAutoSendable(.queued));
    try std.testing.expect(!chatOutboxAutoSendable(.sending));
    try std.testing.expect(!chatOutboxAutoSendable(.not_sent));
    try std.testing.expect(!chatOutboxAutoSendable(.delivered));
}

test "Chat View outbox flush skips unconfirmed entries and keeps FIFO order" {
    const allocator = std.testing.allocator;
    var list: std.ArrayList(ChatOutboxEntry) = .empty;
    defer {
        for (list.items) |e| if (e.text.len > 0) allocator.free(e.text);
        list.deinit(allocator);
    }
    const one = std.unicode.utf8ToUtf16LeStringLiteral("first");
    const two = std.unicode.utf8ToUtf16LeStringLiteral("second");
    const three = std.unicode.utf8ToUtf16LeStringLiteral("third");
    try std.testing.expect(chatOutboxEnqueueInState(&list, allocator, "tmux:1:zigshell-2", one, .delivered));
    try std.testing.expect(chatOutboxEnqueueInState(&list, allocator, "tmux:1:zigshell-2", two, .not_sent));
    try std.testing.expect(chatOutboxEnqueueInState(&list, allocator, "tmux:1:zigshell-2", three, .queued));
    try std.testing.expectEqual(@as(?usize, null), chatOutboxFirstSendableIndexIn(&list, "tmux:1:zigshell-2", false));
    list.items[0].transcript_queued = true;
    try std.testing.expectEqual(@as(?usize, null), chatOutboxFirstSendableIndexIn(&list, "tmux:1:zigshell-2", false));
    list.items[0].state = .not_sent;
    try std.testing.expectEqual(@as(?usize, 2), chatOutboxFirstSendableIndexIn(&list, "tmux:1:zigshell-2", false));
    try std.testing.expectEqual(@as(?usize, 0), chatOutboxFirstIndexIn(&list, "tmux:1:zigshell-2"));
    const four = std.unicode.utf8ToUtf16LeStringLiteral("fourth");
    try std.testing.expect(chatOutboxEnqueueInState(&list, allocator, "tmux:3:delta", four, .delivered));
    try std.testing.expect(chatOutboxFirstSendableIndexIn(&list, "tmux:3:delta", false) == null);
    try std.testing.expect(chatOutboxFirstSendableIndexIn(&list, "tmux:9:absent", false) == null);
}

test "Chat View echo confirmation survives CRLF, wrapping and a slash command" {
    const typed = std.unicode.utf8ToUtf16LeStringLiteral("\r\n  explain to me /pospeak simply what the\r\ndifferences are and the legality\r\n");
    const buf = std.unicode.utf8ToUtf16LeStringLiteral(
        "\u{276f} explain to me /pospeak simply what the\r\ndifferences are and the legality\r\n\r\n\u{25cf} reply\r\n",
    );
    var blocks: [8]ChatBlock = undefined;
    const n = chatClassifyBlocks(buf, &blocks);
    var prefix: [CHAT_ECHO_PREFIX_CAP]u16 = undefined;
    const p = chatEchoNormalizePrefix(typed, &prefix);
    try std.testing.expectEqual(@as(usize, CHAT_ECHO_PREFIX_CAP), p.len);
    try std.testing.expect(std.mem.startsWith(u16, p, std.unicode.utf8ToUtf16LeStringLiteral("explain to me /pospeak simply")));
    try std.testing.expect((try chatEchoTestAssign(blocks[0..n], buf, .{ .counted = true }, false, typed)) != null);
}

pub const ISSUE_349_TMUX_SEND = true;

fn chatTmuxSendEligible(idx: u32) bool {
    if (!ISSUE_349_TMUX_SEND or idx >= app_state.shell_count) return false;
    const key = chatFileIdentityForShell(idx);
    return app_state.shells[idx].kind == .tmux and key.tmux[0] != 0 and key.host < app_state.g_chat_history_channels.len;
}

fn chatTmuxSendStart(idx: u32, text: []const u16, echo_id: u64, retry: bool) bool {
    if (app_state.g_chat_tmux_send_job != null) return false;
    const a = std.heap.page_allocator;
    const job = a.create(app_state.ChatTmuxSendJob) catch return false;
    job.* = .{ .key = chatFileIdentityForShell(idx), .echo_id = echo_id, .text = a.dupe(u16, text) catch {
        a.destroy(job);
        return false;
    }, .retry = retry };
    const thread = std.Thread.spawn(.{}, chatTmuxSendThread, .{job}) catch {
        a.free(job.text);
        a.destroy(job);
        return false;
    };
    app_state.g_chat_tmux_send_job = job;
    if (chatOutboxIndexById(echo_id)) |ei| app_state.g_chat_outbox.items[ei].channel_pending = true;
    thread.detach();
    armChatOutboxTimerIfNeeded();
    return true;
}

fn chatTmuxSendThread(job: *app_state.ChatTmuxSendJob) void {
    defer job.finished.store(true, .release);
    const a = std.heap.page_allocator;
    const text = std.unicode.utf16LeToUtf8Alloc(a, job.text) catch return;
    defer a.free(text);
    const id: u32 = @truncate(job.echo_id);
    const query = std.json.Stringify.valueAlloc(a, .{ .op = "send", .id = id, .tmux = std.mem.sliceTo(&job.key.tmux, 0), .text = text }, .{}) catch return;
    defer a.free(query);
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    if (@import("chat_session.zig").chatHistoryPersistent(job.key.host, id, query, 4096, &wire, &job.written)) {
        job.rejected = chatTmuxSendRejected(wire.items);
        job.box_not_clear = std.mem.indexOf(u8, wire.items, "\tsend\terror\tbox_not_clear\t") != null;
    }
}

fn chatTmuxSendRejected(wire: []const u8) bool {
    return std.mem.indexOf(u8, wire, "\tsend\terror\t") != null;
}

test "ISSUE-349 an explicit tmux send error falls back, a timeout does not" {
    try std.testing.expect(chatTmuxSendRejected("@mp\t7\tsend\terror\ttmux_send_failed\t0\n@@MP_END@@\n"));
    try std.testing.expect(!chatTmuxSendRejected("@mp\t7\tsend\tok\t-\t0\n@@MP_END@@\n"));
    try std.testing.expect(!chatTmuxSendRejected(""));
}

fn chatTmuxSendFinish() void {
    const job = app_state.g_chat_tmux_send_job orelse return;
    if (!job.finished.load(.acquire)) return;
    defer {
        app_state.g_chat_tmux_send_job = null;
        std.heap.page_allocator.free(job.text);
        std.heap.page_allocator.destroy(job);
    }
    const idx = @import("inbox.zig").findShellById(job.key.shell_id) orelse return;
    const ei = chatOutboxIndexById(job.echo_id);
    if (ei == null and job.echo_id != 0) return;
    if (ei) |i| {
        const entry = &app_state.g_chat_outbox.items[i];
        entry.channel_pending = false;
        entry.channel_sent = (job.written and !job.rejected) or job.retry;
        entry.channel_sent_ms = @intCast(GetTickCount64());
        if (job.retry) entry.channel_retries += 1;
        if (entry.state != .not_sent) entry.state = .delivered;
        if (job.box_not_clear) {
            entry.channel_sent = false;
            entry.state = .not_sent;
            entry.write_started = false;
            entry.retryable = true;
        }
    }
    if (!job.box_not_clear and (!job.written or job.rejected) and !job.retry and (ei == null or app_state.g_chat_outbox.items[ei.?].state != .not_sent)) {
        const result = chatSendViaConsole(idx, job.text, job.echo_id);
        if (ei) |i| {
            app_state.g_chat_outbox.items[i].state = if (result != .ok) .not_sent else if (chatShouldUseDirectInput(idx)) .sending else .delivered;
            if (result == .ok) chatSteerAfterDelivery(idx, i);
        }
    } else if (ei) |i| {
        if (app_state.g_chat_outbox.items[i].state == .delivered) chatSteerAfterDelivery(idx, i);
    }
    _ = saveChatOutbox();
    chatOutboxChanged();
}

fn chatTmuxSettle() void {
    const now_ms: i64 = @intCast(GetTickCount64());
    var changed = false;
    var i: usize = 0;
    while (i < app_state.g_chat_outbox.items.len) {
        const entry = &app_state.g_chat_outbox.items[i];
        if (!entry.channel_sent or entry.channel_pending or (entry.state != .delivered and entry.state != .not_sent)) {
            i += 1;
            continue;
        }
        const idx = chatOutboxShellForKey(entry.key[0..entry.key_len]) orelse {
            i += 1;
            continue;
        };
        const key = chatFileIdentityForShell(idx);
        @import("chat_session.zig").chatFileRequestForDelivery(key, true);
        const history = chatHistoryEntry(key) orelse {
            i += 1;
            continue;
        };
        var matched: ?usize = null;
        var evidence: chat_echo.TranscriptEvidence = if (entry.transcript_queued) .enqueued else .none;
        if (entry.channel_history_revision != history.history.revision or entry.channel_history_generation != history.generation) {
            const facts = history.history.deliveryEvidence(std.heap.page_allocator, .{ .text = entry.text, .prefix = &.{}, .anchor = entry.anchor }) catch {
                i += 1;
                continue;
            };
            var assignment: ChatEchoAssignment = .{};
            chatEchoAssignForKey(entry.key[0..entry.key_len], history.history.blocks.items, history.history.text.items, !history.history.restore_full and history.history.start == 0, &assignment);
            chatEchoStoreAnchors(&assignment);
            matched = chatEchoAssignedBlock(&assignment, entry.id);
            evidence = if (matched != null) .delivered else if (facts.enqueued) .enqueued else .none;
            if (entry.transcript_queued != facts.enqueued) changed = true;
            entry.transcript_queued = facts.enqueued;
            entry.channel_history_revision = history.history.revision;
            entry.channel_history_generation = history.generation;
        }
        if (evidence == .enqueued and (now_ms -| history.loaded_ms > 60_000 or
            chat_echo.pendingExpired(.delivered, entry.sent_tick_ms, now_ms)))
        {
            evidence = .none;
            entry.transcript_queued = false;
            changed = true;
        }
        const busy = app_state.shells[idx].activity == .active or (idx == app_state.active_shell and app_state.g_chat_screen_working);
        switch (chat_echo.transcriptStatus(&entry.delivery_watch, busy, now_ms, history.loaded_ms, evidence)) {
            .wait => {},
            .queued => {
                if (entry.state != .delivered) {
                    entry.state = .delivered;
                    changed = true;
                }
            },
            .delivered => {
                const block = history.history.blocks.items[matched.?];
                var prefix: [CHAT_ECHO_PREFIX_CAP]u16 = undefined;
                chatConfirmedAdd(entry.key[0..entry.key_len], chatEchoNormalizePrefix(entry.text, &prefix), block.start, block.len, block.stamp_ms);
                chatOutboxRemoveAtIn(&app_state.g_chat_outbox, std.heap.page_allocator, i);
                changed = true;
                continue;
            },
            .unconfirmed => {
                if (entry.state != .not_sent) {
                    entry.state = .not_sent;
                    entry.retryable = true;
                    changed = true;
                }
            },
        }
        i += 1;
    }
    if (changed) {
        _ = saveChatOutbox();
        chatOutboxChanged();
    }
}

pub const ISSUE_349_FULL_SETTLE = true;

fn chatFullSettleStart() void {
    if (!ISSUE_349_FULL_SETTLE or app_state.g_chat_full_settle_job != null) return;
    const a = std.heap.page_allocator;
    const now_ms: i64 = @intCast(GetTickCount64());
    const tick = GetTickCount64();
    for (app_state.g_chat_outbox.items) |entry| {
        if (!chat_echo.needsFullSettle(entry.state, entry.write_started, entry.transcript_queued, entry.sent_tick_ms, now_ms)) continue;
        const outbox_key = entry.key[0..entry.key_len];
        const idx = chatOutboxShellForKey(outbox_key) orelse continue;
        const key = chatFileIdentityForShell(idx);
        if (app_state.shells[idx].kind != .tmux or key.tmux[0] == 0 or key.host >= app_state.g_chat_history_channels.len) continue;
        var slot: usize = 0;
        var found = false;
        for (&app_state.g_chat_full_settle_attempts, 0..) |*attempt, i| {
            if (attempt.key_len > 0 and std.mem.eql(u8, attempt.key[0..attempt.key_len], outbox_key)) {
                slot = i;
                found = true;
                break;
            }
            if (attempt.at < app_state.g_chat_full_settle_attempts[slot].at) slot = i;
        }
        const attempt = &app_state.g_chat_full_settle_attempts[slot];
        if (found and tick - attempt.at < 30_000) continue;
        const job = a.create(app_state.ChatFullSettleJob) catch return;
        job.* = .{ .key = key, .outbox_key = entry.key, .key_len = entry.key_len };
        const last_id = if (found) attempt.last_id else 0;
        for (0..2) |pass| {
            for (app_state.g_chat_outbox.items) |candidate| {
                if (job.count == job.entries.len) break;
                if ((candidate.id > last_id) != (pass == 0)) continue;
                if (!std.mem.eql(u8, candidate.key[0..candidate.key_len], outbox_key) or
                    !chat_echo.needsFullSettle(candidate.state, candidate.write_started, candidate.transcript_queued, candidate.sent_tick_ms, now_ms)) continue;
                const text = a.dupe(u16, candidate.text) catch {
                    for (job.entries[0..job.count]) |target| a.free(target.text);
                    a.destroy(job);
                    return;
                };
                job.entries[job.count] = .{ .id = candidate.id, .sent_ms = candidate.anchor.sent_ms, .text = text };
                job.count += 1;
                job.after_ms = @min(job.after_ms, candidate.anchor.sent_ms);
            }
        }
        const thread = std.Thread.spawn(.{}, chatFullSettleThread, .{job}) catch {
            for (job.entries[0..job.count]) |target| a.free(target.text);
            a.destroy(job);
            return;
        };
        attempt.* = .{ .key = entry.key, .key_len = entry.key_len, .at = tick, .last_id = job.entries[job.count - 1].id };
        app_state.g_chat_full_settle_job = job;
        thread.detach();
        return;
    }
}

fn chatFullSettleThread(job: *app_state.ChatFullSettleJob) void {
    defer job.finished.store(true, .release);
    const a = std.heap.page_allocator;
    var texts: [16][]const u8 = undefined;
    var count: usize = 0;
    defer for (texts[0..count]) |text| a.free(text);
    for (job.entries[0..job.count]) |target| {
        texts[count] = std.unicode.utf16LeToUtf8Alloc(a, target.text) catch return;
        count += 1;
    }
    const id: u32 = @truncate(job.entries[0].id);
    const query = std.json.Stringify.valueAlloc(a, .{
        .op = "settle",
        .id = id,
        .codex = job.key.codex,
        .sid = std.mem.sliceTo(&job.key.sid, 0),
        .tmux = std.mem.sliceTo(&job.key.tmux, 0),
        .cwd = std.mem.sliceTo(&job.key.cwd, 0),
        .texts = texts[0..count],
        .after_ms = job.after_ms,
    }, .{}) catch return;
    defer a.free(query);
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    if (!@import("chat_session.zig").chatHistoryPersistent(job.key.host, id, query, 4096, &wire, null)) return;
    var header_buf: [96]u8 = undefined;
    const header = std.fmt.bufPrint(&header_buf, "@mp\t{d}\tsettle\tok\t-\t{d}\n", .{ id, count }) catch return;
    if (!std.mem.startsWith(u8, wire.items, header)) return;
    var lines = std.mem.splitScalar(u8, wire.items[header.len..], '\n');
    while (lines.next()) |line| {
        if (std.mem.eql(u8, line, "@@MP_END@@")) break;
        const parsed = std.json.parseFromSlice(struct { i: usize, delivered_ms: i64, line: u64 }, a, line, .{}) catch return;
        defer parsed.deinit();
        if (parsed.value.i < count and parsed.value.delivered_ms > 0) job.delivered_ms[parsed.value.i] = parsed.value.delivered_ms;
    }
}

fn chatFullSettleFinish() void {
    const job = app_state.g_chat_full_settle_job orelse return;
    if (!job.finished.load(.acquire)) return;
    const a = std.heap.page_allocator;
    defer {
        for (job.entries[0..job.count]) |target| a.free(target.text);
        a.destroy(job);
        app_state.g_chat_full_settle_job = null;
    }
    var changed = false;
    for (job.entries[0..job.count], 0..) |target, i| {
        if (job.delivered_ms[i] == 0) continue;
        const ei = chatOutboxIndexById(target.id) orelse continue;
        const entry = app_state.g_chat_outbox.items[ei];
        if (entry.anchor.sent_ms != target.sent_ms or !std.mem.eql(u8, entry.key[0..entry.key_len], job.outbox_key[0..job.key_len])) continue;
        if (entry.state != .delivered and !(entry.state == .not_sent and entry.write_started)) continue;
        var log_buf: [256]u8 = undefined;
        if (std.fmt.bufPrint(&log_buf, "chat-outbox settled id={d} key={s} sent_ms={d} delivered_ms={d}", .{ target.id, job.outbox_key[0..job.key_len], target.sent_ms, job.delivered_ms[i] })) |line| debugLog(line) else |_| {}
        chatOutboxRemoveAtIn(&app_state.g_chat_outbox, a, ei);
        changed = true;
    }
    if (changed) {
        _ = saveChatOutbox();
        chatOutboxChanged();
    }
}

pub fn chatStopAgent(shell_index: u32) bool {
    if (!app_state.ISSUE_265_WORKING_BAR or shell_index >= app_state.shell_count) return false;
    return chatAgentKey(shell_index, 0x1B);
}

pub fn chatPermissionAnswer(shell_index: u32, action: @import("chat_permission.zig").Action) bool {
    if (!app_state.g_chat_active or shell_index != app_state.active_shell or shell_index >= app_state.shell_count) return false;
    var scratch: [2]u16 = undefined;
    if (@import("chat_capture.zig").captureChatTranscript(shell_index, &scratch, true) == null) return false;
    const shell = &app_state.shells[shell_index];
    if (shell.permission_answered) return false;
    const digit = app_state.g_chat_permission.digit(action) orelse return false;
    if (!chatAgentKey(shell_index, digit)) return false;
    shell.permission_answered = true;
    @import("window_layout.zig").chatWorkingIndicatorInvalidate();
    return true;
}

fn chatAgentKey(shell_index: u32, digit: u8) bool {
    const shell = &app_state.shells[shell_index];
    if (@import("chat_working.zig").stopTransportFor(shell.kind, shell.tmux_session_len > 0) == .tmux) {
        const key = @import("chat_transcript.zig").Identity.initTmux(shell.shell_id, shell.tmux_host, false, shell.tmux_session[0..shell.tmux_session_len], "");
        if (key.tmux[0] == 0 or key.host >= app_state.g_chat_history_channels.len) return false;
        const thread = std.Thread.spawn(.{}, chatStopTmuxThread, .{ key, digit }) catch return false;
        thread.detach();
        return true;
    }
    if (shell.pid == 0) return false;
    _ = FreeConsole();
    if (AttachConsole(shell.pid) == 0) return false;
    defer _ = FreeConsole();
    const handle = openAttachedConsoleInput() orelse return false;
    defer _ = CloseHandle(handle);
    var records: [2]INPUT_RECORD = undefined;
    records[0] = .{ .EventType = KEY_EVENT, .Event = .{ .KeyEvent = .{
        .bKeyDown = 1,
        .wRepeatCount = 1,
        .wVirtualKeyCode = digit,
        .wVirtualScanCode = if (digit == 0x1B) 0x01 else 0,
        .UnicodeChar = digit,
        .dwControlKeyState = 0,
    } } };
    records[1] = records[0];
    records[1].Event.KeyEvent.bKeyDown = 0;
    var written: DWORD = 0;
    if (WriteConsoleInputW(handle, &records, 2, &written) == 0 or written != 2) return false;
    var log: [96]u8 = undefined;
    debugLog(std.fmt.bufPrint(&log, "[chat] {s} sent shell={d} via=console", .{ if (digit == 0x1B) @as([]const u8, "stop") else "permission", shell.shell_id }) catch "");
    return true;
}

fn chatStopTmuxThread(key: @import("chat_transcript.zig").Identity, digit: u8) void {
    const a = std.heap.page_allocator;
    const op: []const u8 = if (digit == 0x1B) "stop" else if (digit == 0x18) "send_queued" else "permission";
    const permission = digit != 0x1B and digit != 0x18;
    const query = std.json.Stringify.valueAlloc(a, .{ .op = op, .digit = digit, .id = key.shell_id, .tmux = std.mem.sliceTo(&key.tmux, 0) }, .{}) catch {
        if (permission) app_state.g_chat_permission_send_failed.store(key.shell_id, .release);
        return;
    };
    defer a.free(query);
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    if (!@import("chat_session.zig").chatHistoryPersistent(key.host, key.shell_id, query, 4096, &wire, null) or std.mem.indexOf(u8, wire.items, if (digit == 0x1B) "\tstop\tok\t" else if (digit == 0x18) "\tsend_queued\tok\t" else "\tpermission\tok\t") == null) {
        if (permission) app_state.g_chat_permission_send_failed.store(key.shell_id, .release);
        debugLog(if (digit == 0x1B) "[chat] stop failed via=tmux" else if (digit == 0x18) "[chat] send queued failed via=tmux" else "[chat] permission failed via=tmux");
        return;
    }
    var log: [96]u8 = undefined;
    debugLog(std.fmt.bufPrint(&log, "[chat] {s} sent shell={d} via=tmux", .{ op, key.shell_id }) catch "");
}

pub fn chatShellEditQueued() bool {
    if (!app_state.g_chat_active) return false;
    return chatShellOp(app_state.active_shell, "edit_queued", null, null);
}

pub fn chatShellOp(shell_index: u32, op: []const u8, text: ?[]const u16, in_flight: ?*std.atomic.Value(bool)) bool {
    if (shell_index >= app_state.shell_count) return false;
    const shell = &app_state.shells[shell_index];
    if (@import("chat_working.zig").stopTransportFor(shell.kind, shell.tmux_session_len > 0) != .tmux) return false;
    const key = @import("chat_transcript.zig").Identity.initTmux(shell.shell_id, shell.tmux_host, false, shell.tmux_session[0..shell.tmux_session_len], "");
    if (key.tmux[0] == 0 or key.host >= app_state.g_chat_history_channels.len) return false;
    const a = std.heap.page_allocator;
    const store = if (text) |t| (std.unicode.utf16LeToUtf8Alloc(a, t) catch return false) else (a.alloc(u8, 0) catch return false);
    var kept: usize = 0;
    for (store) |c| {
        if (c == '\r') continue;
        store[kept] = c;
        kept += 1;
    }
    const thread = std.Thread.spawn(.{}, chatShellOpThread, .{ key, op, store, kept, in_flight }) catch {
        a.free(store);
        return false;
    };
    thread.detach();
    return true;
}

fn chatShellOpThread(key: @import("chat_transcript.zig").Identity, op: []const u8, store: []u8, kept: usize, in_flight: ?*std.atomic.Value(bool)) void {
    defer if (in_flight) |flag| flag.store(false, .release);
    const a = std.heap.page_allocator;
    defer a.free(store);
    const query = std.json.Stringify.valueAlloc(a, .{ .op = op, .id = key.shell_id, .tmux = std.mem.sliceTo(&key.tmux, 0), .text = store[0..kept] }, .{}) catch return;
    defer a.free(query);
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    var needle: [48]u8 = undefined;
    const want = std.fmt.bufPrint(&needle, "\t{s}\tok\t", .{op}) catch return;
    var log: [96]u8 = undefined;
    if (!@import("chat_session.zig").chatHistoryPersistent(key.host, key.shell_id, query, 4096, &wire, null) or std.mem.indexOf(u8, wire.items, want) == null) {
        debugLog(std.fmt.bufPrint(&log, "[chat] {s} failed via=tmux", .{op}) catch "");
        return;
    }
    debugLog(std.fmt.bufPrint(&log, "[chat] {s} sent shell={d} via=tmux", .{ op, key.shell_id }) catch "");
}

test "IGSH-442 removed outbox entry is absent after JSON save and reload" {
    const allocator = std.testing.allocator;
    var list: std.ArrayList(ChatOutboxEntry) = .empty;
    defer {
        for (list.items) |entry| allocator.free(entry.text);
        list.deinit(allocator);
    }
    const removed = std.unicode.utf8ToUtf16LeStringLiteral("remove this unconfirmed message");
    const kept = std.unicode.utf8ToUtf16LeStringLiteral("keep this message");
    try std.testing.expect(chatOutboxEnqueueInState(&list, allocator, "tmux:0:test", removed, .not_sent));
    list.items[0].write_started = true;
    try std.testing.expect(chatOutboxEnqueueIn(&list, allocator, "tmux:0:test", kept));
    chatOutboxRemoveAtIn(&list, allocator, 0);
    var len: usize = 0;
    const json = chatOutboxSerialize(&list, allocator, &len) orelse return error.SerializeFailed;
    defer allocator.free(json);
    var loaded: std.ArrayList(ChatOutboxEntry) = .empty;
    defer {
        for (loaded.items) |entry| allocator.free(entry.text);
        loaded.deinit(allocator);
    }
    chatOutboxParseJson(&loaded, allocator, json[0..len]);
    try std.testing.expectEqual(@as(usize, 1), loaded.items.len);
    try std.testing.expectEqualSlices(u16, kept, loaded.items[0].text);
}

fn sshOutboxFlushed(idx: u32) void {
    var buf: [128]u8 = undefined;
    debugLog(std.fmt.bufPrint(&buf, "ssh-reconnect outbox-flushed id={d} count=1", .{app_state.shells[idx].shell_id}) catch return);
}

test "ISSUE-460 session queued evidence cannot release the next outbox entry" {
    const allocator = std.testing.allocator;
    var list: std.ArrayList(ChatOutboxEntry) = .empty;
    defer {
        for (list.items) |entry| allocator.free(entry.text);
        list.deinit(allocator);
    }
    const key = "tmux:0:test";
    try std.testing.expect(chatOutboxEnqueueInState(&list, allocator, key, std.unicode.utf8ToUtf16LeStringLiteral("first request"), .delivered));
    try std.testing.expect(chatOutboxEnqueueIn(&list, allocator, key, std.unicode.utf8ToUtf16LeStringLiteral("second request")));
    list.items[0].transcript_queued = true;
    try std.testing.expectEqual(@as(?usize, null), chatOutboxFirstSendableIndexIn(&list, key, false));
    chatOutboxRemoveAtIn(&list, allocator, 0);
    try std.testing.expectEqual(@as(?usize, 0), chatOutboxFirstSendableIndexIn(&list, key, false));
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("second request"), list.items[0].text);
}

test "IGSH-564 busy tmux session still gets the queued message typed" {
    try std.testing.expect(chatOutboxReadyToType(true, false, true, true, true, true));
    try std.testing.expect(chatOutboxReadyToType(true, false, true, true, false, true));
    try std.testing.expect(chatOutboxReadyToType(false, true, true, false, true, true));
    try std.testing.expect(chatOutboxReadyToType(false, true, true, true, true, true));
    try std.testing.expect(!chatOutboxReadyToType(false, false, true, false, true, true));
    try std.testing.expect(!chatOutboxReadyToType(false, true, false, false, false, true));
    try std.testing.expect(chatOutboxReadyToType(false, true, false, false, true, true));

    const allocator = std.testing.allocator;
    var list: std.ArrayList(ChatOutboxEntry) = .empty;
    defer {
        for (list.items) |entry| allocator.free(entry.text);
        list.deinit(allocator);
    }
    const key = "tmux:0:test";
    try std.testing.expect(chatOutboxEnqueueInState(&list, allocator, key, std.unicode.utf8ToUtf16LeStringLiteral("first request"), .delivered));
    try std.testing.expect(chatOutboxEnqueueIn(&list, allocator, key, std.unicode.utf8ToUtf16LeStringLiteral("second request")));
    try std.testing.expectEqual(@as(?usize, null), chatOutboxFirstSendableIndexIn(&list, key, false));
    try std.testing.expectEqual(@as(?usize, 1), chatOutboxFirstSendableIndexIn(&list, key, true));
    list.items[0].state = .sending;
    try std.testing.expectEqual(@as(?usize, null), chatOutboxFirstSendableIndexIn(&list, key, true));
    list.items[0].state = .not_sent;
    try std.testing.expectEqual(@as(?usize, 1), chatOutboxFirstSendableIndexIn(&list, key, true));
}

fn chatPromptNormalizeLineEndings(text: []u16) []const u16 {
    var len: usize = 0;
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        const character = text[i];
        text[len] = if (character == '\r') '\n' else character;
        len += 1;
        if (character == '\r' and i + 1 < text.len and text[i + 1] == '\n') i += 1;
    }
    return text[0..len];
}

test "IGSH-895 typed prefix plus native paste preserves the draft and sends one newline per break" {
    const w = @import("win32.zig");
    const prefix = L("I cannot send ");
    const parent = w.CreateWindowExW(0, L("STATIC"), L(""), 0, 0, 0, 600, 100, null, null, null, null) orelse return error.TestUnexpectedResult;
    defer _ = w.DestroyWindow(parent);
    const edit = w.CreateWindowExW(0, L("EDIT"), L(""), w.WS_CHILD | w.ES_MULTILINE | w.ES_AUTOVSCROLL, 0, 0, 600, 100, parent, null, null, null) orelse return error.TestUnexpectedResult;
    defer _ = w.DestroyWindow(edit);
    const clipboard = @import("clipboard.zig");
    var previous: [16384]u16 = undefined;
    const previous_len = clipboard.readClipboardTextWithRetry(&previous);
    defer _ = clipboard.setUnicodeClipboardTextWithRetry(previous[0..previous_len]);
    const cases = .{
        .{ L("screenshots"), L("I cannot send screenshots"), L("I cannot send screenshots") },
        .{ L("screenshots\r\n"), L("I cannot send screenshots\r\n"), L("I cannot send screenshots\n") },
        .{ L("\r\nscreenshots\r\nnext\r\n"), L("I cannot send \r\nscreenshots\r\nnext\r\n"), L("I cannot send \nscreenshots\nnext\n") },
        .{ L("screenshots\r\n\r\nnext"), L("I cannot send screenshots\r\n\r\nnext"), L("I cannot send screenshots\n\nnext") },
    };
    inline for (cases) |case| {
        _ = w.SetWindowTextW(edit, L(""));
        for (std.mem.span(prefix)) |character| _ = w.SendMessageW(edit, 0x0102, character, 1);
        try std.testing.expect(clipboard.setUnicodeClipboardTextWithRetry(std.mem.span(case[0])));
        _ = w.SendMessageW(edit, 0x0302, 0, 0);
        var text: [256]u16 = undefined;
        const length: usize = @intCast(w.GetWindowTextW(edit, &text, text.len));
        try std.testing.expectEqualSlices(u16, std.mem.span(case[1]), text[0..length]);
        try std.testing.expectEqualSlices(u16, std.mem.span(case[2]), chatPromptNormalizeLineEndings(text[0..length]));
    }
    _ = w.SetWindowTextW(edit, L("before after"));
    _ = w.SendMessageW(edit, 0x00B1, 7, 7);
    try std.testing.expect(clipboard.setUnicodeClipboardTextWithRetry(std.mem.span(L("screenshots\r\n"))));
    _ = w.SendMessageW(edit, 0x0302, 0, 0);
    var middle: [256]u16 = undefined;
    const middle_len: usize = @intCast(w.GetWindowTextW(edit, &middle, middle.len));
    try std.testing.expectEqualSlices(u16, std.mem.span(L("before screenshots\r\nafter")), middle[0..middle_len]);
    try std.testing.expectEqualSlices(u16, std.mem.span(L("before screenshots\nafter")), chatPromptNormalizeLineEndings(middle[0..middle_len]));
    var mixed = [_]u16{ 'a', '\r', '\n', '\r', '\n', 'b', '\n', 'c', '\r' };
    try std.testing.expectEqualSlices(u16, std.mem.span(L("a\n\nb\nc\n")), chatPromptNormalizeLineEndings(&mixed));
    std.debug.print("IGSH-895 exact draft paste and canonical outgoing line endings PASS\n", .{});
}
