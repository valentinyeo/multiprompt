const std = @import("std");
const app = @import("app_state.zig");
const w = @import("win32.zig");
const words = @import("ui_words.zon");
const file = @import("file_io.zig");

pub const TIMER: usize = 1087;
pub const State = enum { connecting, live, sleeping, reconnecting, lost };
const Phase = enum { idle, discover, page, forward, paint, connected, stopping, delay };
const SessionKey = [32]u8;
const DesktopKey = [64]u8;
const ProfileKey = [32]u8;
const SshResult = extern struct {
    state: c_int = 0,
    local_port: u16 = 0,
    profile: ProfileKey = @splat(0),
    json: [4096]u8 = @splat(0),
};
const Owner = struct {
    sid: u32,
    session: SessionKey,
    host: u8,
};
const Target = struct {
    desktop: DesktopKey,
    profile: ProfileKey,
    uid: u32,
    host_name: [253]u8 = @splat(0),
    host_name_len: usize = 0,
    user: [128]u8 = @splat(0),
    user_len: usize,
    display: [32]u8 = @splat(0),
    display_len: usize,
    port: u16,
    fn same(a: Target, b: Target) bool {
        return std.mem.eql(u8, &a.desktop, &b.desktop) and std.mem.eql(u8, &a.profile, &b.profile) and a.uid == b.uid and a.port == b.port and
            std.mem.eql(u8, a.user[0..a.user_len], b.user[0..b.user_len]) and std.mem.eql(u8, a.display[0..a.display_len], b.display[0..b.display_len]);
    }
};
const Job = struct { handle: *anyopaque, generation: u64, owner: Owner, target: ?Target };
const Machine = struct {
    state: State = .sleeping,
    phase: Phase = .idle,
    owner: ?Owner = null,
    target: ?Target = null,
    job: ?Job = null,
    generation: u64 = 1,
    attempts: u8 = 0,
    deadline: u64 = 0,
    controlling: bool = false,
    visible: bool = false,
    full_width: bool = false,
    split_permille: u16 = 500,
    page_selected: bool = false,
    fn accepts(self: *const Machine, generation: u64, owner: Owner) bool {
        const current = self.owner orelse return false;
        return generation == self.generation and owner.sid == current.sid and owner.host == current.host and std.mem.eql(u8, &owner.session, &current.session);
    }
};
const KnownTarget = struct { sid: u32 = 0, session: SessionKey = @splat(0), target: ?Target = null };
var known_targets: [app.MAX_SHELLS]KnownTarget = @splat(.{});
var machine: Machine = .{};

fn knownTarget(owner: Owner) ?Target {
    for (known_targets) |known| if (known.sid == owner.sid and std.mem.eql(u8, &known.session, &owner.session)) return known.target;
    return null;
}

fn rememberTarget(owner: Owner, target: Target) void {
    var slot: usize = 0;
    for (known_targets, 0..) |known, i| {
        if (std.mem.eql(u8, &known.session, &owner.session)) { slot = i; break; }
        if (known.target == null) slot = i;
    }
    known_targets[slot] = .{ .sid = owner.sid, .session = owner.session, .target = target };
}
var syncing = false;
var shutting_down = false;
var closing_requested = false;
var timer_armed = false;
var account_suppressed = false;
const Choice = struct { session: SessionKey = @splat(0), computer: bool = false };
var choices: [app.MAX_SHELLS]Choice = @splat(.{});
var loaded_path: [640]u8 = @splat(0);
var loaded_path_len: usize = 0;

extern fn mp_computer_create(w.HANDLE) c_int;
extern fn mp_computer_ready() c_int;
extern fn mp_computer_present(c_int, c_int, c_int, c_int, c_int) void;
extern fn mp_computer_command(u64, [*]const u8, usize) void;
extern fn mp_computer_fallback(u64, [*]const u8, usize) void;
extern fn mp_computer_focus() void;
extern fn mp_computer_has_input_focus() c_int;
extern fn mp_computer_cursor_inside() c_int;
pub fn cursorInside() bool { return machine.visible and selected() and currentOwnerMatches() and mp_computer_cursor_inside() != 0; }
extern fn mp_computer_destroy() void;
extern fn mp_computer_ssh_start([*]const u16, usize, [*]const u8, usize, [*]const u8, usize, u16, ?[*]const u8) ?*anyopaque;
extern fn mp_computer_ssh_poll(*anyopaque, *SshResult) c_int;
extern fn mp_computer_ssh_close(*anyopaque) void;

fn namespacePath(out: *[640]u8) ?[]const u8 {
    var base: [512]u8 = undefined;
    return std.fmt.bufPrint(out, "{s}.computer", .{@import("session.zig").getSessionPath(&base) orelse return null}) catch null;
}

fn loadChoices() void {
    var path_buf: [640]u8 = undefined;
    const path = namespacePath(&path_buf) orelse return;
    if (std.mem.eql(u8, loaded_path[0..loaded_path_len], path)) return;
    choices = @splat(.{});
    @memcpy(loaded_path[0..path.len], path);
    loaded_path_len = path.len;
    const handle = file.win32OpenRead(path) orelse return;
    defer _ = w.CloseHandle(handle);
    var bytes: [app.MAX_SHELLS * 66]u8 = undefined;
    const n = file.win32ReadAll(handle, &bytes);
    var lines = std.mem.splitScalar(u8, bytes[0..n], '\n');
    var i: usize = 0;
    while (lines.next()) |line| {
        if (i == choices.len) break;
        if (line.len != 65 or line[64] != '1') continue;
        var key: SessionKey = undefined;
        _ = std.fmt.hexToBytes(&key, line[0..64]) catch continue;
        choices[i] = .{ .session = key, .computer = true };
        i += 1;
    }
}

fn saveChoices() void {
    if (loaded_path_len == 0) return;
    var buffer: [app.MAX_SHELLS * 66]u8 = undefined;
    var pos: usize = 0;
    for (choices) |choice| {
        if (!choice.computer) continue;
        const key = std.fmt.bytesToHex(choice.session, .lower);
        @memcpy(buffer[pos..][0..64], &key);
        pos += 64;
        buffer[pos] = '1'; buffer[pos + 1] = '\n'; pos += 2;
    }
    _ = file.writeFileAtomicW(loaded_path[0..loaded_path_len], buffer[0..pos]);
}

fn ownerFor(idx: u32) ?Owner {
    if (idx >= app.shell_count) return null;
    const shell = &app.shells[idx];
    if (shell.tmux_host > app.TMUX_HOST_INNE or shell.tmux_session_len == 0 or !@import("console.zig").isRemoteShellKind(shell.kind)) return null;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(loaded_path[0..loaded_path_len]);
    hash.update(&.{shell.tmux_host});
    hash.update(shell.tmux_session[0..shell.tmux_session_len]);
    var key: SessionKey = undefined;
    hash.final(&key);
    return .{ .sid = shell.shell_id, .session = key, .host = shell.tmux_host };
}

pub fn chosenFor(idx: u32) bool {
    loadChoices();
    const owner = ownerFor(idx) orelse return false;
    for (choices) |choice| if (choice.computer and std.mem.eql(u8, &choice.session, &owner.session)) return true;
    return false;
}

pub fn selected() bool {
    return app.active_shell < app.shell_count and chosenFor(app.active_shell) and !@import("launch_cache.zig").pending;
}

pub fn splitPermille() u16 { return machine.split_permille; }
pub fn setSplitPermille(value: u16) void {
    machine.split_permille = value;
    @import("window_layout.zig").repositionActive();
}
pub fn fullWidth() bool { return selected() and currentOwnerMatches() and machine.full_width; }
pub fn actionLabel(target: usize) []const u8 {
    return switch (target) {
        app.SEARCH_COMPUTER_CONTROL_OFFSET => if (controlling()) words.computer_give_action else words.computer_take_action,
        app.SEARCH_COMPUTER_WIDTH_OFFSET => words.computer_full_width,
        app.SEARCH_COMPUTER_RETRY_OFFSET => words.computer_retry_action,
        else => words.computer_toggle,
    };
}
fn currentOwnerMatches() bool {
    const owner = ownerFor(app.active_shell) orelse return false;
    return machine.accepts(machine.generation, owner);
}

pub fn controlling() bool { return machine.controlling and machine.visible and selected() and currentOwnerMatches(); }
pub fn hasInputFocus() bool { return machine.visible and selected() and currentOwnerMatches() and mp_computer_has_input_focus() != 0; }

pub fn chooseBrowser(idx: u32) void {
    loadChoices();
    const owner = ownerFor(idx) orelse return;
    var changed = false;
    for (&choices) |*choice| {
        if (choice.computer and std.mem.eql(u8, &choice.session, &owner.session)) { choice.computer = false; changed = true; }
    }
    if (!changed) return;
    saveChoices();
    if (idx == app.active_shell) {
        sync();
        @import("window_layout.zig").repositionActive();
        if (@import("focus.zig").foregroundIsOurs()) @import("focus.zig").focusActiveShell();
    }
}

pub fn toggle(idx: u32) void {
    if (idx >= app.shell_count or app.g_account_locked or !@import("room_frontend.zig").privateActionsAllowed()) return;
    loadChoices();
    const owner = ownerFor(idx) orelse return;
    if (chosenFor(idx)) { chooseBrowser(idx); return; }
    var slot: ?usize = null;
    for (&choices, 0..) |*choice, i| {
        if (std.mem.eql(u8, &choice.session, &owner.session)) { slot = i; break; }
        if (!choice.computer and slot == null) slot = i;
    }
    if (slot) |i| choices[i] = .{ .session = owner.session, .computer = true } else return;
    saveChoices();
    if (idx != app.active_shell) @import("console.zig").switchToShellByUser(idx);
    if (app.active_shell >= app.shell_count or app.shells[app.active_shell].shell_id != owner.sid) return;
    @import("focus.zig").cancelPendingNativeBrowserFocus();
    app.g_browser_focus_mode = false;
    app.g_shell_focused = true;
    @import("browser_pane.zig").hideAllBrowserChrome();
    sync();
    @import("window_layout.zig").repositionActive();
    if (@import("focus.zig").foregroundIsOurs()) @import("focus.zig").focusActiveShell();
    _ = w.InvalidateRect(app.g_main_hwnd, null, 0);
}

fn allowed() bool {
    return selected() and !shutting_down and !closing_requested and !app.g_app_closing and !app.g_account_locked and !app.g_account_applying and !app.g_restoring and !app.g_startup_progress and
        @import("room_frontend.zig").privateActionsAllowed() and !app.g_inbox_active and !app.g_all_sessions_active and (!app.g_search_active or @import("browser_pane.zig").paletteAnchoredBesideBrowser()) and !app.g_shortcuts_active and
        !app.g_changelog_active and !app.g_url_picker_active and !app.g_snippet_create_active and app.g_edit_hwnd == null and !@import("settings_panel.zig").isOpen() and
        w.IsIconic(app.g_main_hwnd) == 0 and w.IsWindowVisible(app.g_main_hwnd) != 0 and !app.g_power_display_off;
}

fn send(comptime command: []const u8, extra: []const u8) void {
    var buffer: [8192]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "{{\"command\":\"" ++ command ++ "\",\"generation\":\"{d}\"{s}}}", .{ machine.generation, extra }) catch return;
    mp_computer_command(machine.generation, text.ptr, text.len);
    std.crypto.secureZero(u8, &buffer);
}

fn setState(state: State) void {
    const changed = machine.state != state;
    machine.state = state;
    var extra: [80]u8 = undefined;
    if (changed) send("state", std.fmt.bufPrint(&extra, ",\"state\":\"{s}\"", .{@tagName(state)}) catch unreachable);
    const caption = switch (state) { .connecting => words.computer_connecting, .live => words.computer_live, .sleeping => words.computer_sleeping, .reconnecting => words.computer_reconnecting, .lost => words.computer_lost_retry };
    mp_computer_fallback(machine.generation, caption.ptr, caption.len);
}

pub fn revoke() void {
    if (!machine.controlling) return;
    machine.controlling = false;
    send("control", ",\"enabled\":false");
}

fn closeJob() void {
    if (machine.job) |job| mp_computer_ssh_close(job.handle);
    machine.job = null;
}

fn suspend(now: u64) void {
    revoke();
    machine.full_width = false;
    if (machine.phase == .stopping) return;
    if (machine.phase == .paint or machine.phase == .connected) {
        send("suspend", "");
        machine.phase = .stopping;
        machine.deadline = now + 500;
    } else { closeJob(); machine.phase = .idle; }
    setState(.sleeping);
    machine.page_selected = false;
}

fn selectPage() void {
    if (mp_computer_ready() == 0 or machine.owner == null) return;
    var target_buf: [200]u8 = undefined;
    const target: []const u8 = if (machine.target) |value| std.fmt.bufPrint(&target_buf, "{s}{s}", .{ std.fmt.bytesToHex(value.profile, .lower), value.desktop }) catch unreachable else "";
    const host: []const u8 = if (machine.target) |*target_value| target_value.host_name[0..target_value.host_name_len] else @import("console.zig").tmuxSshTarget(machine.owner.?.host);
    const Wording = struct { computer: []const u8 = words.computer_title, connecting: []const u8 = words.computer_connecting, live: []const u8 = words.computer_live, sleeping: []const u8 = words.computer_sleeping, reconnecting: []const u8 = words.computer_reconnecting, lost: []const u8 = words.computer_lost, take_control: []const u8 = words.computer_take_control, give_back: []const u8 = words.computer_give_back, in_control: []const u8 = words.computer_in_control, full_width: []const u8 = words.computer_full_width, retry: []const u8 = words.computer_retry };
    var buffer: [4096]u8 = undefined;
    const data = std.json.Stringify.valueAlloc(std.heap.page_allocator, .{ .command = "select", .generation = std.fmt.bufPrint(&buffer, "{d}", .{machine.generation}) catch unreachable, .target = target, .host = host, .state = @tagName(machine.state), .words = Wording{} }, .{}) catch return;
    defer std.heap.page_allocator.free(data);
    mp_computer_command(machine.generation, data.ptr, data.len);
    machine.page_selected = true;
}

fn startJob(remote_port: u16, profile: ?ProfileKey) bool {
    const owner = machine.owner orelse return false;
    var prefix: [1024]u16 = @splat(0);
    var pos: usize = 0;
    if (!@import("console.zig").appendSshExe(&prefix, &pos)) return false;
    const alias = @import("console.zig").tmuxSshTarget(owner.host);
    const script = @import("computer_assets").discovery;
    const handle = mp_computer_ssh_start(&prefix, pos, alias.ptr, alias.len, script.ptr, script.len, remote_port, if (profile) |*key| key else null) orelse return false;
    machine.job = .{ .handle = handle, .generation = machine.generation, .owner = owner, .target = if (remote_port == 0) null else machine.target };
    machine.phase = if (remote_port == 0) .discover else .forward;
    machine.deadline = w.GetTickCount64() + 20000;
    return true;
}

fn begin() void {
    machine.generation += 1;
    machine.controlling = false;
    machine.page_selected = false;
    machine.target = if (machine.owner) |owner| knownTarget(owner) else null;
    setState(if (machine.attempts == 0) .connecting else .reconnecting);
    selectPage();
    if (!startJob(0, null)) fail();
}

fn fail() void {
    revoke();
    if (machine.phase == .connected or machine.phase == .paint) {
        send("suspend", "");
        machine.phase = .stopping;
        machine.deadline = w.GetTickCount64() + 500;
    } else { closeJob(); machine.phase = .delay; machine.deadline = w.GetTickCount64() + 1000; }
    machine.attempts += 1;
    setState(if (machine.attempts < 3 and machine.visible) .reconnecting else .lost);
}

fn parseTarget(bytes: []const u8, profile: ProfileKey, password: *[8]u8, password_len: *usize) ?Target {
    const parsed = std.json.parseFromSlice(struct { version: u8, host: []const u8, uid: u32, user: []const u8, display: []const u8, desktop: []const u8, viewer_port: u16, password: []const u8 }, std.heap.page_allocator, bytes, .{ .allocate = .alloc_always }) catch return null;
    defer parsed.deinit();
    defer std.crypto.secureZero(u8, @constCast(parsed.value.password));
    const data = parsed.value;
    if (data.version != 1 or data.uid == 0 or data.viewer_port == 0 or data.desktop.len != 64 or data.user.len == 0 or data.user.len > 128 or data.display.len < 2 or data.display.len > 32 or data.display[0] != ':') return null;
    if (data.host.len == 0 or data.host.len > 253) return null;
    for (data.host) |c| if (!std.ascii.isAlphanumeric(c) and c != '-' and c != '.') return null;
    for (data.desktop) |c| if (!std.ascii.isHex(c) or std.ascii.isUpper(c)) return null;
    for (data.user) |c| if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '-' and c != '.') return null;
    const display_digits = if (std.mem.endsWith(u8, data.display, ".0")) data.display[1 .. data.display.len - 2] else data.display[1..];
    if (display_digits.len == 0) return null;
    for (display_digits) |c| if (!std.ascii.isDigit(c)) return null;
    password_len.* = std.base64.standard.Decoder.calcSizeForSlice(data.password) catch return null;
    if (password_len.* > password.len) return null;
    std.base64.standard.Decoder.decode(password[0..password_len.*], data.password) catch return null;
    for (password[0..password_len.*]) |c| if (c < 32 or c > 126) return null;
    var target: Target = .{ .desktop = undefined, .profile = profile, .uid = data.uid, .user_len = data.user.len, .display_len = data.display.len, .port = data.viewer_port };
    target.host_name_len = data.host.len;
    @memcpy(target.host_name[0..data.host.len], data.host);
    @memcpy(&target.desktop, data.desktop);
    @memcpy(target.user[0..data.user.len], data.user);
    @memcpy(target.display[0..data.display.len], data.display);
    return target;
}

pub fn sync() void {
    if (syncing or shutting_down or app.g_main_hwnd == null) return;
    syncing = true;
    defer syncing = false;
    const now = w.GetTickCount64();
    if (app.g_search_active or app.g_popup_menu_active or app.g_move_size_active or !@import("focus.zig").foregroundIsOurs()) revoke();
    if (!allowed()) {
        machine.visible = false;
        suspend(now);
        if ((app.g_account_locked or app.g_account_applying) and !account_suppressed) {
            known_targets = @splat(.{});
            machine.target = null;
            send("forget", "");
            account_suppressed = true;
        }
        mp_computer_present(0, 0, 0, 0, 0);
        return;
    }
    account_suppressed = false;
    const owner = ownerFor(app.active_shell) orelse return;
    if (machine.owner) |current| {
        if (current.sid != owner.sid or !std.mem.eql(u8, &current.session, &owner.session)) {
            revoke();
            machine.full_width = false;
            const known = knownTarget(owner);
            if (current.host == owner.host and machine.phase == .connected and machine.target != null and known != null and Target.same(machine.target.?, known.?)) {
                var extra: [100]u8 = undefined;
                const previous = machine.generation;
                machine.generation += 1;
                machine.owner = owner;
                send("transfer", std.fmt.bufPrint(&extra, ",\"previous\":\"{d}\"", .{previous}) catch unreachable);
            } else {
                suspend(now);
                machine.owner = null;
                machine.target = null;
                machine.attempts = 0;
                mp_computer_present(0, 0, 0, 0, 0);
                if (machine.phase == .stopping) return;
            }
        }
    }
    machine.visible = true;
    if (machine.owner == null) { machine.owner = owner; machine.generation += 1; machine.page_selected = false; }
    if (!timer_armed) timer_armed = w.SetTimer(app.g_main_hwnd, TIMER, 50, null) != 0;
    @import("crash_recorder.zig").disableMemoryDumpsForPrivateViewer();
    if (mp_computer_create(app.g_main_hwnd) < 0) { closeJob(); machine.phase = .idle; setState(.lost); }
    if (!machine.page_selected and mp_computer_ready() != 0) selectPage();
    if (machine.phase == .idle and machine.state != .lost) { machine.attempts = 0; begin(); }
    present();
}

pub fn present() void {
    if (!machine.visible or !allowed() or !currentOwnerMatches()) { mp_computer_present(0, 0, 0, 0, 0); return; }
    var client: w.RECT = std.mem.zeroes(w.RECT);
    _ = w.GetClientRect(app.g_main_hwnd, &client);
    var rect = @import("window_layout.zig").activePaneRects(client).browser;
    if (machine.full_width) {
        const pad = @import("window_layout.zig").paneOuterMargin();
        rect.left = pad;
        rect.right = client.right - pad;
    }
    mp_computer_present(rect.left, rect.top, @max(1, rect.right - rect.left), @max(1, rect.bottom - rect.top), 1);
}

pub fn tick() void {
    sync();
    const now = w.GetTickCount64();
    if (machine.phase == .stopping and now >= machine.deadline) {
        closeJob();
        machine.phase = if (machine.state == .reconnecting) .delay else .idle;
        machine.deadline = now + 1000;
    }
    if (!machine.visible) {
        if (machine.phase != .stopping) {
            _ = w.KillTimer(app.g_main_hwnd, TIMER);
            timer_armed = false;
            if (closing_requested) _ = @import("focus.zig").PostMessageW(app.g_main_hwnd, app.WM_CLOSE, 0, 0);
        }
        return;
    }
    if (machine.phase == .page) {
        if (mp_computer_ready() != 0) {
            selectPage();
            const target = machine.target orelse { fail(); return; };
            if (!startJob(target.port, target.profile)) fail();
        } else if (now >= machine.deadline) fail();
        return;
    }
    if (machine.phase == .delay) {
        if (now >= machine.deadline and machine.state == .reconnecting) begin();
        return;
    }
    if (machine.phase == .paint and now >= machine.deadline) { fail(); return; }
    if (machine.phase != .discover and machine.phase != .forward and machine.phase != .connected and machine.phase != .paint) return;
    const job = machine.job orelse return;
    if (machine.phase == .connected) {
        if (job.target == null or machine.target == null or !Target.same(job.target.?, machine.target.?)) { fail(); return; }
    } else if (!machine.accepts(job.generation, job.owner)) { closeJob(); return; }
    var result: SshResult = .{};
    defer std.crypto.secureZero(u8, std.mem.asBytes(&result));
    const status = mp_computer_ssh_poll(job.handle, &result);
    if (status < 0 or ((machine.phase == .discover or machine.phase == .forward) and now >= machine.deadline)) { fail(); return; }
    if (status == 0 or machine.phase == .connected or machine.phase == .paint) return;
    var password: [8]u8 = @splat(0);
    defer std.crypto.secureZero(u8, &password);
    var password_len: usize = 0;
    const data = std.mem.sliceTo(&result.json, 0);
    const target = parseTarget(data, result.profile, &password, &password_len) orelse { fail(); return; };
    if (machine.phase == .discover) {
        if (password_len != 0) { fail(); return; }
        closeJob();
        machine.target = target;
        machine.phase = .page;
        machine.deadline = now + 20000;
        selectPage();
    } else {
        if (machine.target == null or !Target.same(machine.target.?, target) or password_len == 0 or result.local_port == 0) { fail(); return; }
        if (mp_computer_ready() == 0) { fail(); return; }
        var gen_buf: [24]u8 = undefined;
        const payload = std.json.Stringify.valueAlloc(std.heap.page_allocator, .{ .command = "connect", .generation = std.fmt.bufPrint(&gen_buf, "{d}", .{machine.generation}) catch unreachable, .port = result.local_port, .password = password[0..password_len] }, .{}) catch { fail(); return; };
        defer { std.crypto.secureZero(u8, payload); std.heap.page_allocator.free(payload); }
        mp_computer_command(machine.generation, payload.ptr, payload.len);
        rememberTarget(job.owner, target);
        machine.phase = .paint;
        machine.deadline = now + 15000;
    }
}

pub fn toggleFullWidth() void {
    if (!machine.visible or !allowed() or !currentOwnerMatches()) return;
    revoke();
    machine.full_width = !machine.full_width;
    @import("window_layout.zig").repositionActive();
    present();
}

pub fn retry() void {
    if (!machine.visible or !allowed() or !currentOwnerMatches() or machine.state != .lost) return;
    closeJob();
    if (mp_computer_ready() == 0) mp_computer_destroy();
    machine.phase = .idle;
    machine.attempts = 0;
    machine.page_selected = false;
    setState(.connecting);
    sync();
}

pub export fn mp_computer_event(generation: u64, event: c_uint) void {
    if (shutting_down) return;
    if (event == 1 and generation == 0) { machine.page_selected = false; return; }
    if (generation != machine.generation) return;
    if (event != 4 and !currentOwnerMatches()) {
        revoke();
        mp_computer_present(0, 0, 0, 0, 0);
        return;
    }
    switch (event) {
        2 => if (machine.visible and machine.phase != .stopping and machine.state != .lost) { fail(); },
        3 => if (machine.visible and allowed() and machine.phase == .paint) { machine.phase = .connected; machine.attempts = 0; setState(.live); },
        4 => {},
        5 => if (!machine.controlling) { takeOrGiveControl(); },
        6 => giveBack(),
        7 => toggleFullWidth(),
        8 => retry(),
        9 => revoke(),
        else => {},
    }
}

pub fn prepareClose() bool {
    closing_requested = true;
    machine.visible = false;
    suspend(w.GetTickCount64());
    if (machine.phase != .stopping) return true;
    if (!timer_armed) timer_armed = w.SetTimer(app.g_main_hwnd, TIMER, 50, null) != 0;
    return !timer_armed;
}

pub fn giveBack() void {
    const had_control = machine.controlling;
    revoke();
    const owner = machine.owner orelse return;
    if (had_control and machine.visible and allowed() and currentOwnerMatches() and !app.g_search_active and !app.g_popup_menu_active and app.active_shell < app.shell_count and
        app.shells[app.active_shell].shell_id == owner.sid and @import("focus.zig").foregroundIsOurs()) @import("focus.zig").focusActiveShell();
}

pub fn takeOrGiveControl() void {
    if (machine.controlling) { giveBack(); return; }
    if (!machine.visible or !allowed() or !currentOwnerMatches() or machine.state != .live or app.g_search_active or app.g_popup_menu_active or !@import("focus.zig").foregroundIsOurs()) return;
    machine.controlling = true;
    @import("focus.zig").cancelPendingNativeBrowserFocus();
    app.g_browser_focus_mode = false;
    @import("focus.zig").cancelShellRefocus(app.g_main_hwnd);
    app.g_shell_focused = false;
    send("control", ",\"enabled\":true");
    mp_computer_focus();
}

pub fn shutdown() void {
    shutting_down = true;
    revoke();
    send("suspend", "");
    closeJob();
    mp_computer_destroy();
    machine = .{};
}

test "IGSH-1087 stale discovery cannot acquire a changed session or generation" {
    const owner: Owner = .{ .sid = 41, .host = 0, .session = @splat(1) };
    const current: Machine = .{ .owner = owner, .generation = 9 };
    try std.testing.expect(current.accepts(9, owner));
    try std.testing.expect(!current.accepts(8, owner));
    var other = owner; other.sid = 42;
    try std.testing.expect(!current.accepts(9, other));
    other = owner; other.host = 1;
    try std.testing.expect(!current.accepts(9, other));
    other = owner; other.session[0] = 2;
    try std.testing.expect(!current.accepts(9, other));
}

test "IGSH-1087 target identity includes resolved profile user display and service" {
    const target: Target = .{ .desktop = @splat('a'), .profile = @splat(1), .uid = 1001, .user_len = 0, .display_len = 0, .port = 12345 };
    try std.testing.expect(Target.same(target, target));
    var other = target; other.profile[0] = 2;
    try std.testing.expect(!Target.same(target, other));
    other = target; other.uid += 1;
    try std.testing.expect(!Target.same(target, other));
    other = target; other.port += 1;
    try std.testing.expect(!Target.same(target, other));
    other = target; other.desktop[0] = 'b';
    try std.testing.expect(!Target.same(target, other));
}

pub export fn mp_computer_asset(name: [*]const u8, length: usize, size: *usize) ?[*]const u8 {
    if (std.mem.eql(u8, name[0..length], "vendor/webview2/WIN32METADATA-LICENSE")) {
        const data = @embedFile("computer_windows_header_license");
        size.* = data.len;
        return data.ptr;
    }
    inline for (.{ "LICENSE.txt", "NOTICE.txt" }) |path| {
        if (std.mem.eql(u8, name[0..length], "vendor/webview2/" ++ path)) {
            const data = if (comptime std.mem.eql(u8, path, "LICENSE.txt")) @embedFile("computer_webview2_license") else @embedFile("computer_webview2_notice");
            size.* = data.len;
            return data.ptr;
        }
    }
    return @import("computer_assets").asset(name[0..length], size);
}

pub export fn mp_computer_loader(size: *usize, hash: *[*:0]const u8) ?[*]const u8 {
    const arm = @import("builtin").cpu.arch == .aarch64;
    const data = @embedFile("computer_loader");
    hash.* = if (arm) "0f753606aaa25e21b6c6f4c270ab4a9831029e75c1741d9f27a434961ee6b657" else "2f965e10aed3b356a408978a0e6d74eb86e3e722dd008fa9ad39f68884479e85";
    size.* = data.len;
    return data.ptr;
}

extern fn mp_computer_profile_policy_test() c_int;

test "IGSH-1087 private SSH profile excludes other forwards and preserves identity and host-key policy" {
    try std.testing.expectEqual(@as(c_int, 0), mp_computer_profile_policy_test());
}

test "IGSH-1087 embedded loader matches its architecture pin and assets reject traversal" {
    var length: usize = 0;
    var expected: [*:0]const u8 = undefined;
    const data = mp_computer_loader(&length, &expected) orelse return error.TestUnexpectedResult;
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data[0..length], &hash, .{});
    const actual = std.fmt.bytesToHex(hash, .lower);
    try std.testing.expectEqualStrings(std.mem.span(expected), &actual);
    try std.testing.expect(length > 100000);
    const forbidden = "../discover.py";
    try std.testing.expect(mp_computer_asset(forbidden.ptr, forbidden.len, &length) == null);
    const script = "adapter.js";
    try std.testing.expect(mp_computer_asset(script.ptr, script.len, &length) != null);
    try std.testing.expect(length > 0);
}

test "IGSH-1087 discovery output rejects malformed identity display and credential sizes" {
    const prefix = "{\"version\":1,\"host\":\"example.invalid\",\"uid\":1001,\"user\":\"example\",\"desktop\":\"" ++ "a" ** 64 ++ "\",\"viewer_port\":12345,";
    var password: [8]u8 = @splat(0);
    defer std.crypto.secureZero(u8, &password);
    var length: usize = 0;
    const valid = parseTarget(prefix ++ "\"display\":\":7.0\",\"password\":\"ZXhhbXBsZQ==\"}", @splat(1), &password, &length) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(u16, 12345), valid.port);
    try std.testing.expectEqualStrings("example", password[0..length]);
    try std.testing.expectEqualStrings(":7.0", valid.display[0..valid.display_len]);
    try std.testing.expect(parseTarget(prefix ++ "\"display\":\":..\",\"password\":\"\"}", @splat(1), &password, &length) == null);
    try std.testing.expect(parseTarget(prefix ++ "\"display\":\":7\",\"password\":\"QUFBQUFBQUFB\"}", @splat(1), &password, &length) == null);
}
