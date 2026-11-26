const std = @import("std");
const app_state = @import("app_state.zig");
const transport = @import("chat_transport.zig");
const w = @import("win32.zig");

const a = std.heap.page_allocator;
const OutputFn = *const fn ([*c]const u8, usize, ?*anyopaque) callconv(.c) void;
const ResizeFn = *const fn (c_int, c_int, ?*anyopaque) callconv(.c) void;

const LogFont = extern struct {
    height: i32 = 0,
    width: i32 = 0,
    escapement: i32 = 0,
    orientation: i32 = 0,
    weight: i32 = 0,
    italic: u8 = 0,
    underline: u8 = 0,
    strike_out: u8 = 0,
    charset: u8 = 0,
    out_precision: u8 = 0,
    clip_precision: u8 = 0,
    quality: u8 = 0,
    pitch_and_family: u8 = 0,
    face: [32]u16 = @splat(0),
};

extern fn mp_terminal_window_new(w.HANDLE, *const LogFont, u32, u32, ?[*]const u32, OutputFn, ResizeFn, ?*anyopaque) w.HANDLE;
extern fn mp_terminal_window_feed(w.HANDLE, [*]const u8, usize) void;
extern fn mp_terminal_window_style(w.HANDLE, *const LogFont, u32, u32, ?[*]const u32) void;
extern fn mp_terminal_window_report(w.HANDLE) void;
extern fn mp_terminal_window_copy(w.HANDLE) c_int;
extern fn mp_terminal_window_paste(w.HANDLE) void;

pub const Opened = struct { hwnd: w.HANDLE, pending: bool, host: u8 };

const Slot = struct {
    live: bool = false,
    opened: bool = false,
    paused: bool = false,
    shell_id: u32 = 0,
    host: u8 = 0,
    rows: i32 = 24,
    cols: i32 = 80,
    hwnd: w.HANDLE = null,
    channel: ?*transport.Channel = null,
    command: [8192]u8 = @splat(0),
    command_len: usize = 0,
    mutex: app_state.SpinMutex = .{},
};

var slots_ready = false;
var slots: [app_state.MAX_SHELLS]Slot = undefined;

fn lock(slot: *Slot) void {
    while (!slot.mutex.tryLock()) w.Sleep(1);
}

fn allSlots() *[app_state.MAX_SHELLS]Slot {
    if (!slots_ready) {
        for (&slots) |*slot| slot.* = .{};
        slots_ready = true;
    }
    return &slots;
}

fn find(shell_id: u32) ?*Slot {
    for (allSlots()) |*slot| if (slot.live and slot.shell_id == shell_id) return slot;
    return null;
}

fn alloc(shell_id: u32) ?*Slot {
    if (find(shell_id)) |slot| return slot;
    for (allSlots()) |*slot| if (!slot.live) {
        slot.* = .{};
        slot.live = true;
        slot.shell_id = shell_id;
        return slot;
    };
    return null;
}

fn onGui() bool {
    const main = app_state.g_main_hwnd orelse return false;
    return w.GetCurrentThreadId() == w.GetWindowThreadProcessId(main, null);
}

pub fn hostFor(kind: app_state.ShellKind) u8 {
    return switch (kind) {
        .vps => app_state.TMUX_HOST_DE,
        .vps2 => app_state.TMUX_HOST_UK,
        .tmux => app_state.g_pending_tmux_host,
        else => 0,
    };
}

fn appendBytes(buf: []u8, pos: *usize, text: []const u8) bool {
    if (pos.* + text.len > buf.len) return false;
    @memcpy(buf[pos.*..][0..text.len], text);
    pos.* += text.len;
    return true;
}

fn appendDecimal(buf: []u8, pos: *usize, value: u32) bool {
    var digits: [10]u8 = undefined;
    var count: usize = 0;
    var rest = value;
    if (rest == 0) {
        digits[0] = '0';
        count = 1;
    } else {
        while (rest > 0) : (rest /= 10) {
            digits[count] = @intCast('0' + rest % 10);
            count += 1;
        }
    }
    while (count > 0) {
        count -= 1;
        if (!appendBytes(buf, pos, digits[count .. count + 1])) return false;
    }
    return true;
}

pub fn remoteShellCommand(buf: []u8, kind: app_state.ShellKind, tmux_session: ?[]const u8, shell_id: u32, new_session: bool, cwd: ?[]const u8) ?[]const u8 {
    if (kind != .vps and kind != .vps2 and kind != .tmux) return null;
    var pos: usize = 0;
    if (!appendBytes(buf, &pos, "export ZSB_SESSION=zss-") or !appendDecimal(buf, &pos, shell_id) or !appendBytes(buf, &pos, "; ")) return null;
    if ((kind == .vps or kind == .vps2) and tmux_session != null) {
        var command_buf: [2048]u8 = undefined;
        const command = @import("tmux_identity.zig").workspaceShellCommand(&command_buf, tmux_session.?, app_state.g_pending_tmux_identity orelse "", cwd, new_session) catch return null;
        if (!appendBytes(buf, &pos, command)) return null;
    } else if (kind == .tmux and tmux_session != null) {
        const identity = app_state.g_pending_tmux_identity orelse "";
        if (identity.len > 0) {
            app_state.g_pending_resurrect_len = 0;
            app_state.g_pending_tmux_cmd_len = 0;
        }
        if (app_state.g_pending_resurrect_len > 0) {
            const len = app_state.g_pending_resurrect_len;
            app_state.g_pending_resurrect_len = 0;
            var text = app_state.g_pending_resurrect[0..len];
            if (std.mem.endsWith(u8, text, "\\\"")) text = text[0 .. text.len - 2];
            if (!appendBytes(buf, &pos, text)) return null;
        } else if (app_state.g_pending_tmux_cmd_len > 0) {
            const len = app_state.g_pending_tmux_cmd_len;
            app_state.g_pending_tmux_cmd_len = 0;
            if (!appendBytes(buf, &pos, app_state.g_pending_tmux_cmd[0..len])) return null;
        } else {
            var attach_buf: [1536]u8 = undefined;
            const attach = @import("tmux_identity.zig").attachCommand(&attach_buf, tmux_session.?, identity, new_session) catch return null;
            if (!appendBytes(buf, &pos, attach)) return null;
        }
    } else switch (kind) {
        .vps, .vps2 => {
            if (app_state.g_pending_spawn_cmd_len > 0) {
                const len = app_state.g_pending_spawn_cmd_len;
                app_state.g_pending_spawn_cmd_len = 0;
                if (!appendBytes(buf, &pos, "bash -ic '") or !appendBytes(buf, &pos, app_state.g_pending_spawn_cmd[0..len]) or !appendBytes(buf, &pos, "'")) return null;
            } else if (!appendBytes(buf, &pos, "exec ${SHELL:-bash} -l")) return null;
        },
        .tmux => if (!appendBytes(buf, &pos, "~/.local/bin/tmux-pick.sh")) return null,
        else => return null,
    }
    return buf[0..pos];
}

fn shellFontHeight() i32 {
    if (app_state.g_console_font_override > 0) {
        const dpi: i32 = @intCast(@import("console.zig").mainWindowDpi());
        const scaled = @divTrunc(@as(i32, app_state.g_console_font_override) * dpi + 48, 96);
        return std.math.clamp(scaled, 6, 72);
    }
    @import("themes.zig").ensureDevThemeInitialized();
    const height: i32 = app_state.g_dev_theme.console_font_height;
    if (height < 6 or height > 72) return 16;
    return height;
}

fn shellFont(font: *LogFont) void {
    const height = shellFontHeight();
    font.* = .{};
    font.height = -height;
    font.weight = @import("fonts.zig").SHELL_WEIGHT;
    font.charset = 1;
    font.quality = 5;
    font.pitch_and_family = 49;
    const written = std.unicode.utf8ToUtf16Le(font.face[0 .. font.face.len - 1], @import("fonts.zig").SHELL_FACE) catch 0;
    font.face[written] = 0;
}

fn palette() ?[*]const u32 {
    if (!@import("themes.zig").devThemeOn()) return null;
    return &app_state.g_dev_theme.console_palette;
}

fn createWindow(slot: *Slot, parent: w.HANDLE) w.HANDLE {
    var font: LogFont = .{};
    shellFont(&font);
    return mp_terminal_window_new(parent, &font, @import("themes.zig").themeConsoleFg(), @import("themes.zig").themeConsoleBg(), palette(), onOutput, onResize, slot);
}

pub fn open(kind: app_state.ShellKind, tmux_session: ?[]const u8, shell_id: u32, new_session: bool, cwd: ?[]const u8) ?Opened {
    if (app_state.g_main_hwnd == null) return null;
    const slot = alloc(shell_id) orelse return null;
    const command = remoteShellCommand(&slot.command, kind, tmux_session, shell_id, new_session, cwd) orelse {
        slot.live = false;
        return null;
    };
    slot.command_len = command.len;
    slot.host = hostFor(kind);
    slot.rows = 24;
    slot.cols = 80;
    if (@import("window_layout.zig").shellPaneCellCounts(shellFontHeight())) |size| {
        slot.rows = size[0];
        slot.cols = size[1];
    }
    return .{ .hwnd = null, .pending = true, .host = slot.host };
}

fn attachWindow(slot: *Slot) bool {
    if (slot.hwnd != null) return true;
    const parent = app_state.g_main_hwnd orelse return false;
    slot.hwnd = createWindow(slot, parent);
    if (slot.hwnd == null) return false;
    if (@import("inbox.zig").findShellById(slot.shell_id)) |idx| {
        app_state.shells[idx].hwnd = slot.hwnd;
        if (idx == app_state.active_shell) @import("window_layout.zig").repositionActive();
    }
    return true;
}

pub fn ensureWindow(shell_id: u32) bool {
    const slot = find(shell_id) orelse return false;
    if (!onGui()) {
        const main = app_state.g_main_hwnd orelse return false;
        return w.PostMessageW(main, w.WM_APP_NATIVE_SPAWN, shell_id, 0) != 0;
    }
    return attachWindow(slot);
}

pub fn connect(shell_id: u32) bool {
    const slot = find(shell_id) orelse return false;
    if (slot.channel != null) return true;
    if (slot.hwnd == null) {
        if (!onGui()) {
            const main = app_state.g_main_hwnd orelse return false;
            return w.PostMessageW(main, w.WM_APP_NATIVE_SPAWN, shell_id, 0) != 0;
        }
        if (!attachWindow(slot)) return false;
    }
    const thread = std.Thread.spawn(.{}, connectWorker, .{shell_id}) catch return false;
    thread.detach();
    return true;
}

pub fn finish(shell_id: u32) void {
    const slot = find(shell_id) orelse return;
    if (!attachWindow(slot)) {
        ready(shell_id, false);
        return;
    }
    if (!connect(shell_id)) ready(shell_id, false);
}

fn postReady(shell_id: u32, ok: bool) void {
    const main = app_state.g_main_hwnd orelse return;
    _ = w.PostMessageW(main, w.WM_APP_NATIVE_READY, shell_id, @as(w.LPARAM, @intCast(@intFromBool(ok))));
}

fn connectWorker(shell_id: u32) void {
    const slot = find(shell_id) orelse {
        postReady(shell_id, false);
        return;
    };
    if (!slot.live or app_state.g_main_hwnd == null) {
        postReady(shell_id, false);
        return;
    }
    const channel = transport.openTerminal(slot.host, app_state.g_main_hwnd, w.WM_APP_NATIVE_TERMINAL, shell_id) orelse {
        postReady(shell_id, false);
        return;
    };
    lock(slot);
    if (!slot.live) {
        slot.mutex.unlock();
        transport.close(channel);
        postReady(shell_id, false);
        return;
    }
    const rows = slot.rows;
    const cols = slot.cols;
    const command_len = slot.command_len;
    slot.channel = channel;
    slot.mutex.unlock();
    const ok = sendOpening(slot, channel, rows, cols, command_len);
    if (!ok) {
        dropChannel(shell_id);
        postReady(shell_id, false);
        return;
    }
    lock(slot);
    slot.opened = true;
    const current_rows = slot.rows;
    const current_cols = slot.cols;
    slot.mutex.unlock();
    sendSize(slot, current_rows, current_cols);
    postSizeReport(shell_id);
    postReady(shell_id, true);
}

pub fn sizeMessage(buf: []u8, rows: i32, cols: i32) []const u8 {
    return std.fmt.bufPrint(buf, "{{\"size\":[{d},{d}]}}", .{ rows, cols }) catch "";
}

test "MUBO-598 a terminal resize leaves as one size line" {
    var buf: [48]u8 = undefined;
    try std.testing.expectEqualStrings("{\"size\":[50,104]}", sizeMessage(&buf, 50, 104));
    try std.testing.expectEqualStrings("{\"size\":[8,20]}", sizeMessage(&buf, 8, 20));
}

fn sendSize(slot: *Slot, rows: i32, cols: i32) void {
    if (!reportableSize(rows, cols)) return;
    var buf: [48]u8 = undefined;
    sendLine(slot, sizeMessage(&buf, rows, cols));
}

fn sendOpening(slot: *Slot, channel: *transport.Channel, rows: i32, cols: i32, command_len: usize) bool {
    const json = std.json.Stringify.valueAlloc(a, .{ .command = slot.command[0..command_len], .size = [2]i32{ rows, cols } }, .{}) catch return false;
    defer a.free(json);
    return transport.write(channel, json);
}

fn sendLine(slot: *Slot, line: []const u8) void {
    const channel = slot.channel orelse return;
    if (!slot.opened or slot.paused) return;
    if (!transport.write(channel, line)) slot.paused = true;
}

fn emitInput(slot: *Slot, bytes: []const u8) void {
    if (!slot.live or !slot.opened or slot.paused or bytes.len == 0 or bytes.len > 1024 * 1024) return;
    const encoded_len = std.base64.standard.Encoder.calcSize(bytes.len);
    const encoded = a.alloc(u8, encoded_len) catch return;
    defer a.free(encoded);
    _ = std.base64.standard.Encoder.encode(encoded, bytes);
    const line = std.fmt.allocPrint(a, "{{\"input\":\"{s}\"}}", .{encoded}) catch return;
    defer a.free(line);
    sendLine(slot, line);
}

fn onOutput(bytes: [*c]const u8, length: usize, user: ?*anyopaque) callconv(.c) void {
    if (length == 0 or bytes == null) return;
    const slot: *Slot = @ptrCast(@alignCast(user orelse return));
    emitInput(slot, bytes[0..length]);
}

pub fn reportableSize(rows: c_int, cols: c_int) bool {
    return rows >= 8 and cols >= 20;
}

fn onResize(rows: c_int, cols: c_int, user: ?*anyopaque) callconv(.c) void {
    const slot: *Slot = @ptrCast(@alignCast(user orelse return));
    if (!slot.live or !reportableSize(rows, cols)) return;
    slot.rows = rows;
    slot.cols = cols;
    sendSize(slot, rows, cols);
}

fn postSizeReport(shell_id: u32) void {
    const main = app_state.g_main_hwnd orelse return;
    _ = w.PostMessageW(main, w.WM_APP_NATIVE_SIZE, shell_id, 0);
}

pub fn reportSize(shell_id: u32) void {
    const slot = find(shell_id) orelse return;
    const hwnd = slot.hwnd orelse return;
    mp_terminal_window_report(hwnd);
}

pub fn pump(shell_id: u32) void {
    const slot = find(shell_id) orelse return;
    const channel = slot.channel orelse return;
    if (channel.pending_bytes < 64 * 1024) slot.paused = false;
    var buf: [65536]u8 = undefined;
    var fed: usize = 0;
    while (fed < 256 * 1024) {
        const n = transport.read(channel, &buf, false) orelse {
            noteEnded(shell_id);
            return;
        };
        if (n == 0) return;
        if (slot.hwnd != null) mp_terminal_window_feed(slot.hwnd, &buf, n);
        fed += n;
    }
    if (app_state.g_main_hwnd) |main| _ = w.PostMessageW(main, w.WM_APP_NATIVE_TERMINAL, shell_id, 0);
}

fn noteEnded(shell_id: u32) void {
    const idx = @import("inbox.zig").findShellById(shell_id) orelse return;
    const shell = &app_state.shells[idx];
    if (!shell.native_terminal or shell.console_inflight or shell.disconnected or shell.ssh_reconnect.phase == .closed) return;
    dropChannel(shell_id);
    shell.disconnected = true;
    shell.activity = .idle;
    const now = w.GetTickCount64();
    shell.ssh_reconnect.ended(now, now ^ shell.shell_id, now -| shell.spawn_tick);
    if (shell.ssh_reconnect.gave_up) {
        var buf: [96]u8 = undefined;
        @import("diagnostics.zig").debugLog(std.fmt.bufPrint(&buf, "ssh-reconnect gave-up id={d} reason=channel-ends-at-once", .{shell_id}) catch "ssh-reconnect gave-up");
    }
    @import("chat_send.zig").armSshReconnectTimerIfNeeded();
}

pub fn ready(shell_id: u32, ok: bool) void {
    const found = @import("inbox.zig").findShellById(shell_id) orelse return;
    const idx: usize = found;
    const shell = &app_state.shells[idx];
    shell.console_inflight = false;
    if (!shell.native_terminal) return;
    if (!ok) {
        shell.disconnected = true;
        const now = w.GetTickCount64();
        shell.ssh_reconnect.lost(now, now ^ shell.shell_id);
        @import("chat_send.zig").armSshReconnectTimerIfNeeded();
        return;
    }
    shell.disconnected = false;
    shell.ssh_reconnect.opened();
    shell.spawn_tick = w.GetTickCount64();
    if (idx == app_state.active_shell and !app_state.g_chat_active and shell.hwnd != null and !@import("sidebar.zig").isTabHidden(@intCast(idx))) {
        _ = @import("chat_composer.zig").showShellConsole(@intCast(idx), w.SW_SHOW, "native-session");
        @import("window_layout.zig").repositionActive();
        if (@import("focus.zig").foregroundIsOurs()) @import("focus.zig").focusActiveShell();
    }
    if (shell.hwnd) |hwnd| mp_terminal_window_report(hwnd);
}

pub fn alive(shell_id: u32) bool {
    const slot = find(shell_id) orelse return false;
    const channel = slot.channel orelse return false;
    return slot.opened and !channel.ended;
}

pub fn dropChannel(shell_id: u32) void {
    const slot = find(shell_id) orelse return;
    lock(slot);
    const channel = slot.channel;
    slot.channel = null;
    slot.opened = false;
    slot.mutex.unlock();
    if (channel) |item| transport.close(item);
}

pub fn close(shell_id: u32) void {
    const slot = find(shell_id) orelse return;
    slot.live = false;
    dropChannel(shell_id);
    if (slot.hwnd) |hwnd| _ = w.DestroyWindow(hwnd);
    slot.hwnd = null;
}

pub fn reconnect(idx: u32) bool {
    if (idx >= app_state.shell_count) return false;
    const shell = &app_state.shells[idx];
    if (!shell.native_terminal or shell.ssh_reconnect.phase == .closed) return false;
    const slot = find(shell.shell_id) orelse return false;
    var command_buf: [8192]u8 = undefined;
    const previous_identity = app_state.g_pending_tmux_identity;
    const previous_host = app_state.g_pending_tmux_host;
    const previous_resurrect = app_state.g_pending_resurrect_len;
    const previous_cmd = app_state.g_pending_tmux_cmd_len;
    app_state.g_pending_tmux_host = shell.tmux_host;
    app_state.g_pending_tmux_identity = if (shell.tmux_identity_len > 0) shell.tmux_identity[0..shell.tmux_identity_len] else null;
    app_state.g_pending_resurrect_len = 0;
    app_state.g_pending_tmux_cmd_len = 0;
    const session = if (shell.tmux_session_len > 0) shell.tmux_session[0..shell.tmux_session_len] else null;
    const command = remoteShellCommand(&command_buf, shell.kind, session, shell.shell_id, shell.ssh_reconnect.create_session or shell.ssh_reconnect.creating_session, shell.cached_cwd[0..shell.cached_cwd_len]);
    app_state.g_pending_tmux_identity = previous_identity;
    app_state.g_pending_tmux_host = previous_host;
    app_state.g_pending_resurrect_len = previous_resurrect;
    app_state.g_pending_tmux_cmd_len = previous_cmd;
    const text = command orelse return false;
    if (text.len > slot.command.len) return false;
    @memcpy(slot.command[0..text.len], text);
    slot.command_len = text.len;
    slot.host = shell.tmux_host;
    dropChannel(shell.shell_id);
    shell.console_inflight = true;
    shell.disconnected = true;
    shell.spawn_tick = w.GetTickCount64();
    if (!connect(shell.shell_id)) {
        ready(shell.shell_id, false);
        return false;
    }
    return true;
}

pub fn launch(identity: @import("session_identity.zig").Session) void {
    const shell_id = identity.owner;
    const sid = std.mem.sliceTo(&identity.sid, 0);
    if (sid.len == 0) return;
    const slot = find(shell_id) orelse {
        failStart(shell_id, sid);
        return;
    };
    if (slot.host != identity.host.index() or slot.command_len == 0) {
        failStart(shell_id, sid);
        return;
    }
    const command = a.dupe(u8, slot.command[0..slot.command_len]) catch {
        failStart(shell_id, sid);
        return;
    };
    const thread = std.Thread.spawn(.{}, launchWorker, .{ identity, command }) catch {
        a.free(command);
        _ = @import("chat_live.zig").startFailed(shell_id, sid, LAUNCH_FAILED);
        return;
    };
    thread.detach();
}

const LAUNCH_FAILED = "This chat could not start on the server. Open a new chat to try again.";
const LAUNCH_TIMEOUT_MS: u64 = 60_000;

fn failStart(shell_id: u32, sid: []const u8) void {
    if (@import("chat_live.zig").startFailed(shell_id, sid, LAUNCH_FAILED)) {
        if (app_state.g_main_hwnd) |main| w.postChatFileReady(main);
    }
}

fn launchWorker(identity: @import("session_identity.zig").Session, command: []u8) void {
    const shell_id = identity.owner;
    const sid = std.mem.sliceTo(&identity.sid, 0);
    defer a.free(command);
    var output: [4096]u8 = undefined;
    var total: usize = 0;
    if (transport.openCommand(identity.host.index(), command)) |channel| {
        if (transport.write(channel, "")) {
            const deadline = w.GetTickCount64() + LAUNCH_TIMEOUT_MS;
            while (w.GetTickCount64() < deadline and total < output.len) {
                const n = transport.read(channel, output[total..], false) orelse break;
                if (n == 0) {
                    w.Sleep(50);
                    continue;
                }
                total += n;
            }
        }
        transport.close(channel);
    }
    if (launchStarted(output[0..total])) return;
    @import("diagnostics.zig").debugLog2("live-chat start failed: ", output[0..@min(total, 400)]);
    if (@import("chat_live.zig").startFailed(shell_id, sid, LAUNCH_FAILED)) {
        if (app_state.g_main_hwnd) |main| w.postChatFileReady(main);
    }
}

fn launchStarted(output: []const u8) bool {
    const trimmed = std.mem.trim(u8, output, " \t\r\n");
    const start = if (std.mem.lastIndexOfScalar(u8, trimmed, '\n')) |index| index + 1 else 0;
    const parsed = std.json.parseFromSlice(std.json.Value, a, trimmed[start..], .{}) catch return false;
    defer parsed.deinit();
    const status = switch (parsed.value) {
        .object => |object| object.get("status") orelse return false,
        else => return false,
    };
    return switch (status) {
        .string => |text| std.mem.eql(u8, text, "started") or std.mem.eql(u8, text, "already"),
        else => false,
    };
}

test "SOFT-1925 a live chat with no start command says it could not start" {
    const live = @import("chat_live.zig");
    const sid = "ffffffff-ffff-4fff-bfff-ffffffffffff";
    const shell_id: u32 = 9925;
    try std.testing.expect(live.starting(shell_id, 1, sid));
    try std.testing.expect(live.running(shell_id));
    launch(@import("chat_transcript.zig").Identity.init(shell_id, 1, false, sid, "").checked().?);
    try std.testing.expect(!live.running(shell_id));
    try std.testing.expect(live.held(shell_id));
    live.release(shell_id);
}

test "a live chat start counts only a started or already running host" {
    try std.testing.expect(launchStarted("{\"status\":\"started\",\"pid\":7}\n"));
    try std.testing.expect(launchStarted("noise\n{\"status\":\"already\",\"reason\":\"host_running\"}\n"));
    try std.testing.expect(!launchStarted("{\"status\":\"error\",\"reason\":\"host_timeout\"}\n"));
    try std.testing.expect(!launchStarted("{\"status\":\"refused\",\"reason\":\"host_disabled\"}"));
    try std.testing.expect(!launchStarted(""));
    try std.testing.expect(!launchStarted("Traceback (most recent call last):"));
}

pub fn restyle(shell_id: u32) void {
    const slot = find(shell_id) orelse return;
    if (slot.hwnd == null) return;
    var font: LogFont = .{};
    shellFont(&font);
    mp_terminal_window_style(slot.hwnd, &font, @import("themes.zig").themeConsoleFg(), @import("themes.zig").themeConsoleBg(), palette());
    mp_terminal_window_report(slot.hwnd.?);
}

pub fn interrupt(shell_id: u32) void {
    const slot = find(shell_id) orelse return;
    emitInput(slot, "\x03");
}

pub fn copy(hwnd: w.HANDLE) bool {
    return hwnd != null and mp_terminal_window_copy(hwnd) != 0;
}

pub fn paste(hwnd: w.HANDLE) void {
    if (hwnd != null) mp_terminal_window_paste(hwnd);
}

test "remote shell command keeps attach, create and resurrect text without ssh" {
    const previous_identity = app_state.g_pending_tmux_identity;
    const previous_resurrect = app_state.g_pending_resurrect_len;
    const previous_cmd = app_state.g_pending_tmux_cmd_len;
    const previous_spawn = app_state.g_pending_spawn_cmd_len;
    defer {
        app_state.g_pending_tmux_identity = previous_identity;
        app_state.g_pending_resurrect_len = previous_resurrect;
        app_state.g_pending_tmux_cmd_len = previous_cmd;
        app_state.g_pending_spawn_cmd_len = previous_spawn;
    }
    app_state.g_pending_tmux_identity = null;
    app_state.g_pending_resurrect_len = 0;
    app_state.g_pending_tmux_cmd_len = 0;
    app_state.g_pending_spawn_cmd_len = 0;
    var buf: [1024]u8 = undefined;
    const attach = remoteShellCommand(&buf, .tmux, "demo", 7, false, null) orelse return error.NoCommand;
    try std.testing.expect(std.mem.indexOf(u8, attach, "export ZSB_SESSION=zss-7; ") != null);
    try std.testing.expect(std.mem.indexOf(u8, attach, "tmux attach -t ") != null);
    try std.testing.expect(std.mem.indexOf(u8, attach, "ssh") == null);
    const created = remoteShellCommand(&buf, .tmux, "demo", 7, true, null) orelse return error.NoCommand;
    try std.testing.expect(std.mem.indexOf(u8, created, "tmux new-session -A -s ") != null);
    const resurrect = "if tmux has-session; then true; fi\\\"";
    @memcpy(app_state.g_pending_resurrect[0..resurrect.len], resurrect);
    app_state.g_pending_resurrect_len = @intCast(resurrect.len);
    const restored = remoteShellCommand(&buf, .tmux, "demo", 9, false, null) orelse return error.NoCommand;
    try std.testing.expect(std.mem.endsWith(u8, restored, "fi"));
    try std.testing.expect(std.mem.indexOf(u8, restored, "\\\"") == null);
    try std.testing.expectEqual(@as(u32, 0), app_state.g_pending_resurrect_len);
    const identity = "1:2:$3";
    app_state.g_pending_tmux_identity = identity;
    app_state.g_pending_resurrect_len = 3;
    const bound = remoteShellCommand(&buf, .tmux, "demo", 4, false, null) orelse return error.NoCommand;
    try std.testing.expect(std.mem.indexOf(u8, bound, "tmux if-shell") != null);
    try std.testing.expectEqual(@as(u32, 0), app_state.g_pending_resurrect_len);
    const login = remoteShellCommand(&buf, .vps, null, 5, false, null) orelse return error.NoCommand;
    try std.testing.expect(std.mem.endsWith(u8, login, "exec ${SHELL:-bash} -l"));
}

test "MUBO-597 native VPS commands create in a quoted workspace and reattach without changing directory" {
    const previous = app_state.g_pending_tmux_identity;
    defer app_state.g_pending_tmux_identity = previous;
    app_state.g_pending_tmux_identity = null;
    var buf: [4096]u8 = undefined;
    for ([_]app_state.ShellKind{ .vps, .vps2 }) |kind| {
        const created = remoteShellCommand(&buf, kind, "term-597", 597, true, "~/projects/example") orelse return error.NoCommand;
        try std.testing.expectEqualStrings("export ZSB_SESSION=zss-597; cd -- \"$HOME\"/'projects/example' 2>/dev/null || cd; tmux new-session -A -s 'term-597' -c \"$PWD\"", created);
        const fallback = remoteShellCommand(&buf, kind, "term-597", 597, true, null) orelse return error.NoCommand;
        try std.testing.expectEqualStrings("export ZSB_SESSION=zss-597; cd; tmux new-session -A -s 'term-597' -c \"$PWD\"", fallback);
        const restored = remoteShellCommand(&buf, kind, "term-597", 598, false, "/another/repo") orelse return error.NoCommand;
        try std.testing.expectEqualStrings("export ZSB_SESSION=zss-598; tmux attach -t '=term-597'", restored);
    }
    app_state.g_pending_tmux_identity = "1:2:$3";
    const guarded = remoteShellCommand(&buf, .vps2, "term-597", 599, false, null) orelse return error.NoCommand;
    try std.testing.expect(std.mem.indexOf(u8, guarded, "tmux if-shell -F -t '=term-597:'") != null);
    try std.testing.expect(std.mem.indexOf(u8, guarded, "new-session") == null);
}

test "MUBO-597 palette VPS tabs keep their workspace and native attachment through save and restore" {
    const previous = .{
        .shells = app_state.shells[0..2].*, .count = app_state.shell_count, .active = app_state.active_shell,
        .main = app_state.g_main_hwnd, .shared = app_state.g_shared_server_connection, .chat = app_state.g_chat_active,
        .single = app_state.g_single_window, .workspace = app_state.g_active_workspace, .restoring = app_state.g_restoring,
        .locked = app_state.g_account_locked, .background = app_state.g_pending_background_workspace,
        .identity = app_state.g_pending_tmux_identity, .host = app_state.g_pending_tmux_host,
        .spawn = app_state.g_pending_spawn_cmd_len, .pending_chat = app_state.g_pending_chat_view,
        .commands = app_state.g_custom_cmds_count, .command = app_state.g_custom_cmds[0],
        .mtime_lo = app_state.g_custom_cmds_mtime_lo, .mtime_hi = app_state.g_custom_cmds_mtime_hi,
        .name = app_state.g_ws_names[1], .name_len = app_state.g_ws_name_len[1],
        .lws_count = app_state.g_lws_count, .sidebar = app_state.g_sidebar_view, .starred = app_state.g_starred_workspace,
        .snoozed = app_state.g_ws_snoozed, .focus = app_state.g_ws_focus, .last = app_state.g_ws_last_shell,
        .next_id = app_state.next_shell_id,
    };
    defer {
        for (app_state.shells[0..app_state.shell_count]) |shell| close(shell.shell_id);
        app_state.shells[0..2].* = previous.shells;
        app_state.shell_count = previous.count;
        app_state.active_shell = previous.active;
        app_state.g_main_hwnd = previous.main;
        app_state.g_shared_server_connection = previous.shared;
        app_state.g_chat_active = previous.chat;
        app_state.g_single_window = previous.single;
        app_state.g_active_workspace = previous.workspace;
        app_state.g_restoring = previous.restoring;
        app_state.g_account_locked = previous.locked;
        app_state.g_pending_background_workspace = previous.background;
        app_state.g_pending_tmux_identity = previous.identity;
        app_state.g_pending_tmux_host = previous.host;
        app_state.g_pending_spawn_cmd_len = previous.spawn;
        app_state.g_pending_chat_view = previous.pending_chat;
        app_state.g_custom_cmds_count = previous.commands;
        app_state.g_custom_cmds[0] = previous.command;
        app_state.g_custom_cmds_mtime_lo = previous.mtime_lo;
        app_state.g_custom_cmds_mtime_hi = previous.mtime_hi;
        app_state.g_ws_names[1] = previous.name;
        app_state.g_ws_name_len[1] = previous.name_len;
        app_state.g_lws_count = previous.lws_count;
        app_state.g_sidebar_view = previous.sidebar;
        app_state.g_starred_workspace = previous.starred;
        app_state.g_ws_snoozed = previous.snoozed;
        app_state.g_ws_focus = previous.focus;
        app_state.g_ws_last_shell = previous.last;
        app_state.next_shell_id = previous.next_id;
    }
    app_state.shell_count = 0;
    app_state.active_shell = 0;
    app_state.g_account_locked = false;
    app_state.g_main_hwnd = @ptrFromInt(1);
    app_state.g_shared_server_connection = true;
    app_state.g_chat_active = true;
    app_state.g_single_window = true;
    app_state.g_active_workspace = 1;
    app_state.g_lws_count = 3;
    app_state.g_restoring = false;
    app_state.g_sidebar_view = null;
    app_state.g_starred_workspace = false;
    app_state.g_ws_snoozed = @splat(false);
    app_state.g_pending_background_workspace = 1;
    app_state.g_pending_tmux_identity = null;
    app_state.g_pending_spawn_cmd_len = 0;
    app_state.g_pending_chat_view = false;
    app_state.g_custom_cmds_mtime_lo = 0xfffffffe;
    app_state.g_custom_cmds_mtime_hi = 0xfffffffe;
    @memcpy(app_state.g_ws_names[1][0..7], "Example");
    app_state.g_ws_name_len[1] = 7;
    var command: app_state.CustomCmd = .{};
    command.kind = .vps;
    command.is_default = true;
    @memcpy(command.workspace[0..7], "Example");
    command.workspace_len = 7;
    const dir = "~/projects/example";
    @memcpy(command.cwd[0..dir.len], dir);
    command.cwd_len = dir.len;
    app_state.g_custom_cmds[0] = command;
    app_state.g_custom_cmds_count = 1;
    for ([_]usize{ 3, 4 }, 0..) |menu, i| {
        try std.testing.expect(@import("console.zig").spawnShellFromMenuIndex(menu));
        const shell = &app_state.shells[i];
        try std.testing.expectEqual(@as(u8, @intCast(i)), shell.tmux_host);
        try std.testing.expectEqual(@as(u8, 1), shell.workspace);
        try std.testing.expect(std.mem.startsWith(u8, shell.tmux_session[0..shell.tmux_session_len], "term-"));
        try std.testing.expectEqualStrings(dir, shell.cached_cwd[0..shell.cached_cwd_len]);
        const slot = find(shell.shell_id) orelse return error.NoSlot;
        try std.testing.expect(std.mem.indexOf(u8, slot.command[0..slot.command_len], "tmux new-session -A -s") != null);
        try std.testing.expect(std.mem.indexOf(u8, slot.command[0..slot.command_len], "/'projects/example'") != null);
        const opening = slot.command;
        const opening_len = slot.command_len;
        app_state.g_main_hwnd = null;
        defer app_state.g_main_hwnd = @ptrFromInt(1);
        ready(shell.shell_id, false);
        shell.ssh_reconnect.start();
        try std.testing.expect(!reconnect(@intCast(i)));
        try std.testing.expectEqualStrings(opening[0..opening_len], slot.command[0..slot.command_len]);
        try std.testing.expect(shell.ssh_reconnect.creating_session);
        ready(shell.shell_id, true);
        try std.testing.expect(!shell.ssh_reconnect.creating_session);
        shell.ssh_reconnect.lost(0, 0);
        shell.ssh_reconnect.start();
        try std.testing.expect(!reconnect(@intCast(i)));
        var expected_buf: [256]u8 = undefined;
        const expected = try std.fmt.bufPrint(&expected_buf, "export ZSB_SESSION=zss-{d}; tmux attach -t '={s}'", .{ shell.shell_id, shell.tmux_session[0..shell.tmux_session_len] });
        try std.testing.expectEqualStrings(expected, slot.command[0..slot.command_len]);
    }
    try std.testing.expect(!std.mem.eql(u8, &app_state.shells[0].tmux_session, &app_state.shells[1].tmux_session));
    const identity = "1:2:$3";
    @memcpy(app_state.shells[0].tmux_identity[0..identity.len], identity);
    app_state.shells[0].tmux_identity_len = identity.len;
    const before = app_state.shells[0..2].*;
    app_state.g_main_hwnd = null;
    app_state.g_chat_active = false;
    app_state.g_restoring = true;
    @import("workspaces.zig").switchToWorkspace(2);
    try std.testing.expectEqual(@as(u32, 2), app_state.shell_count);
    for (app_state.shells[0..2], before, 0..) |shell, original, i| {
        try std.testing.expectEqual(original.shell_id, shell.shell_id);
        try std.testing.expectEqual(original.hwnd, shell.hwnd);
        try std.testing.expectEqual(original.native_terminal, shell.native_terminal);
        try std.testing.expectEqualSlices(u8, &original.tmux_session, &shell.tmux_session);
        try std.testing.expectEqualSlices(u8, &original.tmux_identity, &shell.tmux_identity);
        try std.testing.expect(find(shell.shell_id) != null);
        try std.testing.expect(@import("sidebar.zig").isTabHidden(@intCast(i)));
    }
    var temp: [512]u8 = undefined;
    const len = w.GetEnvironmentVariableA("TEMP", &temp, temp.len);
    try std.testing.expect(len > 0 and len < temp.len);
    var path_buf: [640]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "{s}\\mubo-597-{d}-{d}.json", .{ temp[0..len], w.GetCurrentProcessId(), w.GetTickCount64() });
    defer {
        for ([_][]const u8{ "", ".tmp", ".bak" }) |suffix| {
            var clean_buf: [680]u8 = undefined;
            const clean = std.fmt.bufPrint(&clean_buf, "{s}{s}", .{ path, suffix }) catch unreachable;
            var wide: [680]u16 = undefined;
            const wp = @import("file_io.zig").win32WidePath(&wide, clean).?;
            _ = w.DeleteFileW(wp.ptr);
        }
    }
    try std.testing.expect(@import("session.zig").saveSessionTo(path, null));
    const bytes = @import("file_io.zig").readFileAllocWin32(path, app_state.SESSION_JSON_CAPACITY) orelse return error.NoSave;
    defer a.free(bytes);
    var parsed = try @import("json_reader.zig").parse(std.testing.allocator, bytes);
    defer parsed.deinit();
    var tabs: [2]app_state.SavedTab = undefined;
    try std.testing.expectEqual(@as(u32, 2), @import("json_reader.zig").sessionTabs(parsed.value, &tabs, app_state.MAX_LWS));
    for (app_state.shells[0..2]) |shell| close(shell.shell_id);
    app_state.shell_count = 0;
    app_state.g_main_hwnd = @ptrFromInt(1);
    app_state.g_chat_active = true;
    app_state.g_restoring = false;
    for (&tabs, before, 0..) |*tab, original, i| {
        try std.testing.expectEqual(original.kind, tab.kind);
        try std.testing.expectEqual(original.tmux_host, tab.tmux_host);
        try std.testing.expectEqual(original.workspace, tab.workspace);
        try std.testing.expectEqualSlices(u8, original.tmux_session[0..original.tmux_session_len], tab.tmux_session[0..tab.tmux_session_len]);
        try std.testing.expect(@import("session.zig").spawnSavedTab(tab, .continue_latest));
        const shell = &app_state.shells[i];
        try std.testing.expect(shell.native_terminal);
        try std.testing.expectEqual(original.workspace, shell.workspace);
        try std.testing.expectEqualSlices(u8, &original.tmux_session, &shell.tmux_session);
        try std.testing.expectEqualSlices(u8, &original.tmux_identity, &shell.tmux_identity);
        const slot = find(shell.shell_id) orelse return error.NoSlot;
        try std.testing.expectEqual(original.tmux_host, slot.host);
        try std.testing.expect(std.mem.indexOf(u8, slot.command[0..slot.command_len], if (i == 0) "tmux if-shell" else "tmux attach -t '=") != null);
        try std.testing.expect(std.mem.indexOf(u8, slot.command[0..slot.command_len], "new-session") == null);
    }
}

test "SOFT-2460 the console font override is the shell tab face height" {
    const saved_override = app_state.g_console_font_override;
    const saved_dpi = app_state.g_main_monitor_dpi;
    defer {
        app_state.g_console_font_override = saved_override;
        app_state.g_main_monitor_dpi = saved_dpi;
    }
    app_state.g_main_monitor_dpi = 96;
    app_state.g_console_font_override = 20;
    try std.testing.expectEqual(@as(i32, 20), shellFontHeight());
    app_state.g_main_monitor_dpi = 192;
    try std.testing.expectEqual(@as(i32, 40), shellFontHeight());
}

test "IGSH-1923 a squeezed terminal never shrinks the remote session" {
    try std.testing.expect(!reportableSize(1, 100));
    try std.testing.expect(!reportableSize(7, 100));
    try std.testing.expect(!reportableSize(30, 10));
    try std.testing.expect(reportableSize(8, 20));
    try std.testing.expect(reportableSize(29, 100));
}
