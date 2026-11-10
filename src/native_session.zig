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

pub fn remoteShellCommand(buf: []u8, kind: app_state.ShellKind, tmux_session: ?[]const u8, shell_id: u32, new_session: bool) ?[]const u8 {
    if (kind != .vps and kind != .vps2 and kind != .tmux) return null;
    var pos: usize = 0;
    if (!appendBytes(buf, &pos, "export ZSB_SESSION=zss-") or !appendDecimal(buf, &pos, shell_id) or !appendBytes(buf, &pos, "; ")) return null;
    if (kind == .tmux and tmux_session != null) {
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

fn shellFont(font: *LogFont) void {
    @import("themes.zig").ensureDevThemeInitialized();
    var height: i32 = app_state.g_dev_theme.console_font_height;
    if (height < 6 or height > 72) height = 16;
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

pub fn open(kind: app_state.ShellKind, tmux_session: ?[]const u8, shell_id: u32, new_session: bool) ?Opened {
    if (app_state.g_main_hwnd == null) return null;
    const slot = alloc(shell_id) orelse return null;
    const command = remoteShellCommand(&slot.command, kind, tmux_session, shell_id, new_session) orelse {
        slot.live = false;
        return null;
    };
    slot.command_len = command.len;
    slot.host = hostFor(kind);
    slot.rows = 24;
    slot.cols = 80;
    return .{ .hwnd = null, .pending = true, .host = slot.host };
}

fn attachWindow(slot: *Slot) bool {
    if (slot.hwnd != null) return true;
    const parent = app_state.g_main_hwnd orelse return false;
    slot.hwnd = createWindow(slot, parent);
    if (slot.hwnd == null) return false;
    if (@import("inbox.zig").findShellById(slot.shell_id)) |idx| app_state.shells[idx].hwnd = slot.hwnd;
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
    lock(slot);
    slot.opened = ok;
    const current_rows = slot.rows;
    const current_cols = slot.cols;
    slot.mutex.unlock();
    if (!ok) dropChannel(shell_id) else if (current_rows != rows or current_cols != cols) {
        const line = std.fmt.allocPrint(a, "{{\"size\":[{d},{d}]}}", .{ current_rows, current_cols }) catch null;
        if (line) |text| {
            sendLine(slot, text);
            a.free(text);
        }
    }
    postReady(shell_id, ok);
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

fn onResize(rows: c_int, cols: c_int, user: ?*anyopaque) callconv(.c) void {
    const slot: *Slot = @ptrCast(@alignCast(user orelse return));
    if (!slot.live or rows < 1 or cols < 1) return;
    slot.rows = rows;
    slot.cols = cols;
    const line = std.fmt.allocPrint(a, "{{\"size\":[{d},{d}]}}", .{ rows, cols }) catch return;
    defer a.free(line);
    sendLine(slot, line);
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
    shell.ssh_reconnect.lost(now, now ^ shell.shell_id);
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
    shell.ssh_reconnect.ok();
    shell.spawn_tick = w.GetTickCount64();
    if (idx == app_state.active_shell and !app_state.g_chat_active and shell.hwnd != null) {
        _ = @import("chat_composer.zig").showShellConsole(@intCast(idx), w.SW_SHOW, "native-session");
        @import("window_layout.zig").repositionActive();
    }
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
    const command = remoteShellCommand(&command_buf, shell.kind, session, shell.shell_id, shell.ssh_reconnect.create_session);
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

pub fn launch(shell_id: u32, sid: []const u8) void {
    const slot = find(shell_id) orelse return;
    if (sid.len == 0 or sid.len > 48 or slot.command_len == 0) return;
    const command = a.dupe(u8, slot.command[0..slot.command_len]) catch return;
    const owned_sid = a.dupe(u8, sid) catch {
        a.free(command);
        return;
    };
    const thread = std.Thread.spawn(.{}, launchWorker, .{ shell_id, slot.host, command, owned_sid }) catch {
        a.free(command);
        a.free(owned_sid);
        _ = @import("chat_live.zig").startFailed(shell_id, sid, LAUNCH_FAILED);
        return;
    };
    thread.detach();
}

const LAUNCH_FAILED = "This chat could not start on the server. Open a new chat to try again.";
const LAUNCH_TIMEOUT_MS: u64 = 60_000;

fn launchWorker(shell_id: u32, host: u8, command: []u8, sid: []u8) void {
    defer a.free(command);
    defer a.free(sid);
    var output: [4096]u8 = undefined;
    var total: usize = 0;
    if (transport.openCommand(host, command)) |channel| {
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
        if (app_state.g_main_hwnd) |main| _ = w.PostMessageW(main, w.WM_APP_CHAT_FILE_READY, 0, 0);
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
    const attach = remoteShellCommand(&buf, .tmux, "demo", 7, false) orelse return error.NoCommand;
    try std.testing.expect(std.mem.indexOf(u8, attach, "export ZSB_SESSION=zss-7; ") != null);
    try std.testing.expect(std.mem.indexOf(u8, attach, "tmux attach -t ") != null);
    try std.testing.expect(std.mem.indexOf(u8, attach, "ssh") == null);
    const created = remoteShellCommand(&buf, .tmux, "demo", 7, true) orelse return error.NoCommand;
    try std.testing.expect(std.mem.indexOf(u8, created, "tmux new-session -A -s ") != null);
    const resurrect = "if tmux has-session; then true; fi\\\"";
    @memcpy(app_state.g_pending_resurrect[0..resurrect.len], resurrect);
    app_state.g_pending_resurrect_len = @intCast(resurrect.len);
    const restored = remoteShellCommand(&buf, .tmux, "demo", 9, false) orelse return error.NoCommand;
    try std.testing.expect(std.mem.endsWith(u8, restored, "fi"));
    try std.testing.expect(std.mem.indexOf(u8, restored, "\\\"") == null);
    try std.testing.expectEqual(@as(u32, 0), app_state.g_pending_resurrect_len);
    const identity = "1:2:$3";
    app_state.g_pending_tmux_identity = identity;
    app_state.g_pending_resurrect_len = 3;
    const bound = remoteShellCommand(&buf, .tmux, "demo", 4, false) orelse return error.NoCommand;
    try std.testing.expect(std.mem.indexOf(u8, bound, "tmux if-shell") != null);
    try std.testing.expectEqual(@as(u32, 0), app_state.g_pending_resurrect_len);
    const login = remoteShellCommand(&buf, .vps, null, 5, false) orelse return error.NoCommand;
    try std.testing.expect(std.mem.endsWith(u8, login, "exec ${SHELL:-bash} -l"));
}
