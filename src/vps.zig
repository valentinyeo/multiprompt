const app_state = @import("app_state.zig");
const std = @import("std");
const crash_recorder = @import("crash_recorder.zig");
const DWORD = @import("win32.zig").DWORD;
const HANDLE = @import("win32.zig").HANDLE;
const WM_APP_TMUX_LIST_READY = @import("win32.zig").WM_APP_TMUX_LIST_READY;
const WM_APP_FAVICON_FETCHED = @import("win32.zig").WM_APP_FAVICON_FETCHED;
const STARTUPINFOW = @import("win32.zig").STARTUPINFOW;
const PROCESS_INFORMATION = @import("win32.zig").PROCESS_INFORMATION;
const WIN32_FIND_DATAW = @import("win32.zig").WIN32_FIND_DATAW;
const CreateProcessW = @import("win32.zig").CreateProcessW;
const Sleep = @import("win32.zig").Sleep;
const CloseHandle = @import("win32.zig").CloseHandle;
const TerminateProcess = @import("win32.zig").TerminateProcess;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const FindFirstFileW = @import("win32.zig").FindFirstFileW;
const FindClose = @import("win32.zig").FindClose;
const AssignProcessToJobObject = @import("win32.zig").AssignProcessToJobObject;
const CreatePipe = @import("win32.zig").CreatePipe;
const ReadFile = @import("win32.zig").ReadFile;
const PeekNamedPipe = @import("win32.zig").PeekNamedPipe;
const WriteFile = @import("win32.zig").WriteFile;
const WaitForSingleObject = @import("win32.zig").WaitForSingleObject;
const INVALID_HANDLE_VALUE_PTR = @import("win32.zig").INVALID_HANDLE_VALUE_PTR;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const GetSystemTimeAsFileTime = @import("win32.zig").GetSystemTimeAsFileTime;
const SECURITY_ATTRIBUTES = @import("win32.zig").SECURITY_ATTRIBUTES;
const GetExitCodeProcess = @import("win32.zig").GetExitCodeProcess;
const SESSION_JSON_CAPACITY = @import("app_state.zig").SESSION_JSON_CAPACITY;
const L = @import("startup.zig").L;
const Shell = @import("app_state.zig").Shell;
const MAX_SHELLS = @import("app_state.zig").MAX_SHELLS;
const MAX_TMUX_SESSIONS = @import("app_state.zig").MAX_TMUX_SESSIONS;
const TmuxSessionEntry = @import("app_state.zig").TmuxSessionEntry;
const HostCapacity = @import("app_state.zig").HostCapacity;
const parseAsciiU64 = @import("capacity.zig").parseAsciiU64;
const parseDecimalMilli = @import("capacity.zig").parseDecimalMilli;
const applyCapacityHysteresis = @import("capacity.zig").applyCapacityHysteresis;
const remoteHostForShell = @import("capacity.zig").remoteHostForShell;
const tmuxHostLongLabel = @import("capacity.zig").tmuxHostLongLabel;
const PostMessageW = @import("focus.zig").PostMessageW;
const getSessionDir = @import("session.zig").getSessionDir;
const getFaviconDir = @import("session.zig").getFaviconDir;
const win32WidePath = @import("file_io.zig").win32WidePath;
const win32OpenRead = @import("file_io.zig").win32OpenRead;
const win32OpenWrite = @import("file_io.zig").win32OpenWrite;
const win32WriteAll = @import("file_io.zig").win32WriteAll;
const win32ReadAll = @import("file_io.zig").win32ReadAll;
const win32MakeDir = @import("file_io.zig").win32MakeDir;
const writeFileAtomicW = @import("file_io.zig").writeFileAtomicW;
const win32MakePath = @import("file_io.zig").win32MakePath;
const appendJsonEscaped = @import("workspaces.zig").appendJsonEscaped;
const CreateMutexW = @import("win32.zig").CreateMutexW;
const ReleaseMutex = @import("win32.zig").ReleaseMutex;
const debugLog = @import("diagnostics.zig").debugLog;
const debugLog2 = @import("diagnostics.zig").debugLog2;
const SSH_TARGET_DE = @import("app_state.zig").SSH_TARGET_DE;
const TMUX_HOST_DE = @import("app_state.zig").TMUX_HOST_DE;
const TMUX_HOST_UK = @import("app_state.zig").TMUX_HOST_UK;
const TMUX_HOST_INNE = @import("app_state.zig").TMUX_HOST_INNE;
const sshLoaderFailed = @import("console.zig").sshLoaderFailed;
const sshSpawnFailed = @import("console.zig").sshSpawnFailed;
const appendSshExe = @import("console.zig").appendSshExe;
const tmuxSshTarget = @import("console.zig").tmuxSshTarget;
const appendWideAscii = @import("console.zig").appendWideAscii;
const asciiEqualsCI = @import("command_palette.zig").asciiEqualsCI;
const appendAsciiBuf = @import("archive.zig").appendAsciiBuf;
const VPS_CHANNEL_SENTINEL = @import("app_state.zig").VPS_CHANNEL_SENTINEL;
const VPS_CHANNEL_RESPAWN_BACKOFF_MS = @import("app_state.zig").VPS_CHANNEL_RESPAWN_BACKOFF_MS;
const VPS_CHANNEL_READ_TIMEOUT_MS = @import("app_state.zig").VPS_CHANNEL_READ_TIMEOUT_MS;
const HANDLE_FLAG_INHERIT = @import("app_state.zig").HANDLE_FLAG_INHERIT;
const SetHandleInformation = @import("win32.zig").SetHandleInformation;
const VpsChannel = @import("app_state.zig").VpsChannel;
const AC_SENTINEL = @import("app_state.zig").AC_SENTINEL;
const VPS_PROBE_SCRIPT = @import("app_state.zig").VPS_PROBE_SCRIPT;
const VPS_TMUX_LIST_SCRIPT = @import("app_state.zig").VPS_TMUX_LIST_SCRIPT;
const WorkspaceRepoCandidate = @import("app_state.zig").WorkspaceRepoCandidate;
const publishInboxState = @import("inbox.zig").publishInboxState;

pub fn faviconHostForShell(shell: *const Shell) ?[]const u8 {
    return switch (shell.kind) {
        .vps => SSH_TARGET_DE,
        .tmux => tmuxSshTarget(shell.tmux_host),
        .vps2 => "remote-2",
        else => null,
    };
}

pub fn startFaviconFetch(shell_idx: u32) void {
    if (app_state.g_favicon_fetching) return;
    if (shell_idx >= app_state.shell_count) return;

    const shell = &app_state.shells[shell_idx];
    const host = faviconHostForShell(shell) orelse return;

    var dir_buf: [512]u8 = undefined;
    const dir = getFaviconDir(&dir_buf) orelse return;
    win32MakePath(dir);

    var local_path: [512]u8 = undefined;
    @memcpy(local_path[0..dir.len], dir);
    var lpos: usize = dir.len;
    local_path[lpos] = '\\';
    lpos += 1;
    var clean_count: usize = 0;
    for (0..shell.name_len) |ni| {
        const ch = shell.name[ni];
        if (lpos >= local_path.len - 5) break;
        if ((ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or (ch >= '0' and ch <= '9') or ch == '-' or ch == '_' or ch == '.') {
            local_path[lpos] = @intCast(ch & 0xFF);
            lpos += 1;
            clean_count += 1;
        }
    }
    if (clean_count == 0) {
        const fallback = "favicon";
        @memcpy(local_path[lpos .. lpos + fallback.len], fallback);
        lpos += fallback.len;
    }
    const ext = ".ico";
    @memcpy(local_path[lpos .. lpos + ext.len], ext);
    lpos += ext.len;

    var cmd_buf: [1024]u16 = undefined;
    var cp: usize = 0;
    if (!appendSshExe(&cmd_buf, &cp)) return;
    if (!appendWideAscii(&cmd_buf, &cp, "-o BatchMode=yes -o ConnectTimeout=5 ")) return;
    for (host) |c| {
        if (cp >= cmd_buf.len - 1) return;
        cmd_buf[cp] = @intCast(c);
        cp += 1;
    }

    var cwd_ok = shell.cached_cwd_len > 0;
    for (shell.cached_cwd[0..shell.cached_cwd_len]) |c| {
        if (c == '\'') {
            cwd_ok = false;
            break;
        }
    }
    var tmux_ok = shell.kind == .tmux and shell.tmux_session_len > 0;
    for (shell.tmux_session[0..shell.tmux_session_len]) |c| {
        if (c == '\'') {
            tmux_ok = false;
            break;
        }
    }

    const pre = " \"r=\\\"";
    for (pre) |c| {
        if (cp >= cmd_buf.len - 1) return;
        cmd_buf[cp] = @intCast(c);
        cp += 1;
    }
    if (cwd_ok) {
        for (shell.cached_cwd[0..shell.cached_cwd_len]) |c| {
            if (cp >= cmd_buf.len - 1) return;
            cmd_buf[cp] = @intCast(c);
            cp += 1;
        }
    } else if (tmux_ok) {
        const t1 = "$(tmux display-message -p -t '";
        for (t1) |c| {
            if (cp >= cmd_buf.len - 1) return;
            cmd_buf[cp] = @intCast(c);
            cp += 1;
        }
        for (shell.tmux_session[0..shell.tmux_session_len]) |c| {
            if (cp >= cmd_buf.len - 1) return;
            cmd_buf[cp] = @intCast(c);
            cp += 1;
        }
        const t2 = "' '#{pane_current_path}' 2>/dev/null || echo $HOME)";
        for (t2) |c| {
            if (cp >= cmd_buf.len - 1) return;
            cmd_buf[cp] = @intCast(c);
            cp += 1;
        }
    } else {
        const h = "$HOME";
        for (h) |c| {
            if (cp >= cmd_buf.len - 1) return;
            cmd_buf[cp] = @intCast(c);
            cp += 1;
        }
    }
    const post = "\\\"; f=$(find \\\"$r\\\" -maxdepth 4 -name favicon.ico -type f 2>/dev/null | head -1); [ -n \\\"$f\\\" ] && cat \\\"$f\\\"\"";
    for (post) |c| {
        if (cp >= cmd_buf.len - 1) return;
        cmd_buf[cp] = @intCast(c);
        cp += 1;
    }
    cmd_buf[cp] = 0;

    var log_ascii: [512]u8 = undefined;
    var log_len: usize = 0;
    var lci: usize = 0;
    while (lci < cp and log_len < log_ascii.len - 1) : (lci += 1) {
        log_ascii[log_len] = @intCast(cmd_buf[lci] & 0x7F);
        log_len += 1;
    }
    debugLog2("favicon fetch cmd: ", log_ascii[0..log_len]);

    @memcpy(app_state.g_favicon_fetch_local_path[0..lpos], local_path[0..lpos]);
    app_state.g_favicon_fetch_local_len = @intCast(lpos);
    app_state.g_favicon_fetch_shell_id = shell.shell_id;

    var sa = SECURITY_ATTRIBUTES{
        .nLength = @sizeOf(SECURITY_ATTRIBUTES),
        .lpSecurityDescriptor = null,
        .bInheritHandle = 1,
    };
    var read_pipe: HANDLE = null;
    var write_pipe: HANDLE = null;
    if (CreatePipe(&read_pipe, &write_pipe, &sa, 0) == 0) return;

    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    si.dwFlags = 0x00000100;
    si.hStdOutput = write_pipe;
    si.hStdError = write_pipe;
    si.hStdInput = null;

    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    const CREATE_NO_WINDOW: DWORD = 0x08000000;
    app_state.g_favicon_fetching = true;
    const ok = CreateProcessW(null, @ptrCast(&cmd_buf), null, null, 1, CREATE_NO_WINDOW, null, null, &si, &pi);
    _ = CloseHandle(write_pipe);

    if (ok == 0) {
        _ = CloseHandle(read_pipe);
        app_state.g_favicon_fetching = false;
        sshSpawnFailed();
        return;
    }

    _ = CloseHandle(pi.hThread);
    app_state.g_favicon_fetch_pipe = read_pipe;
    app_state.g_favicon_fetch_process = pi.hProcess;

    const fetch_thread = std.Thread.spawn(.{}, faviconFetchThread, .{}) catch {
        _ = CloseHandle(read_pipe);
        _ = CloseHandle(pi.hProcess);
        app_state.g_favicon_fetching = false;
        return;
    };
    fetch_thread.detach();
}

fn faviconFetchThread() void {
    crash_recorder.guardThread();
    const WAIT_TIMEOUT_CONST: DWORD = 0x00000102;
    const res = WaitForSingleObject(app_state.g_favicon_fetch_process, 15000);
    if (res == WAIT_TIMEOUT_CONST) _ = TerminateProcess(app_state.g_favicon_fetch_process, 1);

    var exit_code: DWORD = 1;
    _ = GetExitCodeProcess(app_state.g_favicon_fetch_process, &exit_code);
    if (exit_code == 0xC0000139) sshSpawnFailed();
    _ = CloseHandle(app_state.g_favicon_fetch_process);

    var buf: [65536]u8 = undefined;
    var total: usize = 0;
    while (total < buf.len) {
        var bytes_read: DWORD = 0;
        const rr = ReadFile(app_state.g_favicon_fetch_pipe, @ptrCast(buf[total..].ptr), @intCast(buf.len - total), &bytes_read, null);
        if (rr == 0 or bytes_read == 0) break;
        total += bytes_read;
    }
    _ = CloseHandle(app_state.g_favicon_fetch_pipe);

    var success: usize = 0;
    var dbg: [128]u8 = undefined;
    const dbg_msg = std.fmt.bufPrint(&dbg, "favicon fetch done: exit={d} bytes={d} hdr={x},{x},{x},{x}", .{
        exit_code,                    total,
        if (total > 0) buf[0] else 0, if (total > 1) buf[1] else 0,
        if (total > 2) buf[2] else 0, if (total > 3) buf[3] else 0,
    }) catch dbg[0..0];
    debugLog(dbg_msg);
    if (total > 22 and buf[0] == 0 and buf[1] == 0 and (buf[2] == 1 or buf[2] == 2) and buf[3] == 0) {
        if (win32OpenWrite(app_state.g_favicon_fetch_local_path[0..app_state.g_favicon_fetch_local_len])) |h| {
            defer _ = CloseHandle(h);
            win32WriteAll(h, buf[0..total]);
            success = 1;
        }
    }

    app_state.g_favicon_fetching = false;
    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_FAVICON_FETCHED, app_state.g_favicon_fetch_shell_id, @intCast(success));
}

pub fn fetchTmuxSessions() void {
    if (app_state.g_tmux_fetching) {
        debugLog("fetchTmuxSessions: skip (already fetching)");
        return;
    }
    const now = GetTickCount64();
    if (now -| app_state.g_tmux_fetch_tick < 15_000 and app_state.g_tmux_cache_count > 0) {
        debugLog("fetchTmuxSessions: skip (throttled)");
        return;
    }

    debugLog("fetchTmuxSessions: starting background SSH (DE + UK + HOST3)");
    app_state.g_tmux_fetching = true;

    const fetch_thread = std.Thread.spawn(.{}, tmuxFetchThreadDual, .{}) catch {
        debugLog("fetchTmuxSessions: thread spawn failed");
        app_state.g_tmux_fetching = false;
        return;
    };
    fetch_thread.detach();
}

pub fn tmuxAgentFromPaneCommand(command: []const u8) u8 {
    if (std.ascii.eqlIgnoreCase(command, "claude")) return 1;
    if (std.ascii.eqlIgnoreCase(command, "codex")) return 2;
    if (std.ascii.eqlIgnoreCase(command, "pi")) return 3;
    if (std.ascii.eqlIgnoreCase(command, "kimi") or
        std.ascii.eqlIgnoreCase(command, "kimi-code")) return 4;
    if (std.ascii.eqlIgnoreCase(command, "hax")) return 5;
    if (std.ascii.eqlIgnoreCase(command, "grok")) return 6;
    if (std.ascii.eqlIgnoreCase(command, "cursor") or
        std.ascii.eqlIgnoreCase(command, "cursor-agent")) return 7;
    return 0;
}

fn closeVpsChannelUnlocked(host: u8) void {
    if (host >= app_state.g_vps_channels.len) return;
    const ch = &app_state.g_vps_channels[host];
    if (ch.stdin_write != null) _ = CloseHandle(ch.stdin_write);
    if (ch.stdout_read != null) _ = CloseHandle(ch.stdout_read);
    if (ch.process != null) {
        sshLoaderFailed(ch.process);
        _ = TerminateProcess(ch.process, 0);
        _ = CloseHandle(ch.process);
    }
    ch.* = .{ .last_spawn_attempt = ch.last_spawn_attempt };
}

pub fn closeAllVpsPersistentChannels() void {
    if (!app_state.g_vps_channel_mutex.tryLock()) {
        app_state.g_vps_channels_close_pending.store(true, .release);
        return;
    }
    defer app_state.g_vps_channel_mutex.unlock();
    for (0..app_state.g_vps_channels.len) |h| closeVpsChannelUnlocked(@intCast(h));
}

fn buildVpsChannelLoopCommand(host: u8, buf: *[2048]u16) bool {
    var pos: usize = 0;
    if (!appendSshExe(buf, &pos)) return false;
    if (!appendWideAscii(buf, &pos, "-T -o BatchMode=yes -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o ConnectTimeout=5 ")) return false;
    if (!appendWideAscii(buf, &pos, tmuxSshTarget(host))) return false;
    if (!appendWideAscii(buf, &pos, " \"while IFS= read -r _; do { ")) return false;
    if (!appendWideAscii(buf, &pos, VPS_PROBE_SCRIPT)) return false;
    if (!appendWideAscii(buf, &pos, VPS_TMUX_LIST_SCRIPT)) return false;
    if (!appendWideAscii(buf, &pos, "; } </dev/null; printf '@@ZS_END@@\\n'; done\"")) return false;
    if (pos >= buf.len) return false;
    buf[pos] = 0;
    return true;
}

fn spawnPersistentChannelUnlocked(host: u8, ch: *VpsChannel, ac: bool) void {
    const now = GetTickCount64();
    if (now < ch.last_spawn_attempt + VPS_CHANNEL_RESPAWN_BACKOFF_MS) return;
    ch.last_spawn_attempt = now;

    var cmd_buf: [2048]u16 = undefined;
    if (!(if (ac) buildAcChannelCommand(host, &cmd_buf) else buildVpsChannelLoopCommand(host, &cmd_buf))) return;

    var sa = SECURITY_ATTRIBUTES{ .nLength = @sizeOf(SECURITY_ATTRIBUTES), .lpSecurityDescriptor = null, .bInheritHandle = 1 };
    var child_stdin_read: HANDLE = null;
    var parent_stdin_write: HANDLE = null;
    var parent_stdout_read: HANDLE = null;
    var child_stdout_write: HANDLE = null;
    if (CreatePipe(&child_stdin_read, &parent_stdin_write, &sa, 0) == 0) {
        debugLog2(if (ac) "chat-ac: stdin CreatePipe failed host=" else "vps-channel: stdin CreatePipe failed host=", tmuxHostLongLabel(host));
        return;
    }
    if (CreatePipe(&parent_stdout_read, &child_stdout_write, &sa, 1 << 20) == 0) {
        debugLog2(if (ac) "chat-ac: stdout CreatePipe failed host=" else "vps-channel: stdout CreatePipe failed host=", tmuxHostLongLabel(host));
        _ = CloseHandle(child_stdin_read);
        _ = CloseHandle(parent_stdin_write);
        return;
    }
    _ = SetHandleInformation(parent_stdin_write, HANDLE_FLAG_INHERIT, 0);
    _ = SetHandleInformation(parent_stdout_read, HANDLE_FLAG_INHERIT, 0);

    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    si.dwFlags = 0x00000100;
    si.hStdInput = child_stdin_read;
    si.hStdOutput = child_stdout_write;
    si.hStdError = child_stdout_write;
    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    const CREATE_NO_WINDOW: DWORD = 0x08000000;
    const ok = CreateProcessW(null, @ptrCast(&cmd_buf), null, null, 1, CREATE_NO_WINDOW, null, null, &si, &pi);
    _ = CloseHandle(child_stdin_read);
    _ = CloseHandle(child_stdout_write);
    if (ok == 0) {
        sshSpawnFailed();
        debugLog2(if (ac) "chat-ac: CreateProcessW failed host=" else "vps-channel: CreateProcessW failed host=", tmuxHostLongLabel(host));
        _ = CloseHandle(parent_stdin_write);
        _ = CloseHandle(parent_stdout_read);
        return;
    }
    _ = CloseHandle(pi.hThread);
    if (app_state.g_tunnel_job != null) _ = AssignProcessToJobObject(app_state.g_tunnel_job, pi.hProcess);
    ch.process = pi.hProcess;
    ch.stdin_write = parent_stdin_write;
    ch.stdout_read = parent_stdout_read;
    ch.alive = true;
    debugLog2(if (ac) "chat-ac: spawned host=" else "vps-channel: spawned host=", tmuxHostLongLabel(host));
}

fn spawnVpsChannelUnlocked(host: u8) void {
    if (host >= app_state.g_vps_channels.len) return;
    spawnPersistentChannelUnlocked(host, &app_state.g_vps_channels[host], false);
}

fn closeAcChannelUnlocked(host: u8) void {
    if (host >= app_state.g_ac_channels.len) return;
    const ch = &app_state.g_ac_channels[host];
    if (ch.stdin_write != null) _ = CloseHandle(ch.stdin_write);
    if (ch.stdout_read != null) _ = CloseHandle(ch.stdout_read);
    if (ch.process != null) {
        sshLoaderFailed(ch.process);
        _ = TerminateProcess(ch.process, 0);
        _ = CloseHandle(ch.process);
    }
    ch.* = .{ .last_spawn_attempt = ch.last_spawn_attempt };
}

pub fn closeAllAcChannels() void {
    if (!app_state.g_ac_channel_mutex.tryLock()) {
        app_state.g_ac_channels_close_pending.store(true, .release);
        return;
    }
    defer app_state.g_ac_channel_mutex.unlock();
    for (0..app_state.g_ac_channels.len) |h| closeAcChannelUnlocked(@intCast(h));
}

fn buildAcChannelCommand(host: u8, buf: *[2048]u16) bool {
    var pos: usize = 0;
    if (!appendSshExe(buf, &pos)) return false;
    if (!appendWideAscii(buf, &pos, "-T -o BatchMode=yes -o ConnectTimeout=5 ")) return false;
    if (!appendWideAscii(buf, &pos, tmuxSshTarget(host))) return false;
    if (!appendWideAscii(buf, &pos, " python3 ~/.local/share/zigshell/mp_complete.py --serve")) return false;
    buf[pos] = 0;
    return true;
}

fn spawnAcChannelUnlocked(host: u8) void {
    if (host >= app_state.g_ac_channels.len) return;
    spawnPersistentChannelUnlocked(host, &app_state.g_ac_channels[host], true);
}
pub fn fetchAcPersistent(host: u8, request: []const u8, buf: []u8) ?usize {
    if (host >= app_state.g_ac_channels.len) return null;
    while (!app_state.g_ac_channel_mutex.tryLock()) Sleep(1);
    defer app_state.g_ac_channel_mutex.unlock();
    defer if (app_state.g_ac_channels_close_pending.swap(false, .acq_rel)) {
        for (0..app_state.g_ac_channels.len) |h| closeAcChannelUnlocked(@intCast(h));
    };
    const ch = &app_state.g_ac_channels[host];
    if (!ch.alive) spawnAcChannelUnlocked(host);
    if (!ch.alive) return null;
    var written: DWORD = 0;
    if (WriteFile(ch.stdin_write, request.ptr, @intCast(request.len), &written, null) == 0 or written != request.len) {
        closeAcChannelUnlocked(host);
        return null;
    }
    const n = readVpsChannelUntilSentinel(ch.stdout_read, buf, AC_SENTINEL) orelse {
        closeAcChannelUnlocked(host);
        return null;
    };
    return n + AC_SENTINEL.len;
}

fn readVpsChannelUntilSentinel(h: HANDLE, buf: []u8, sentinel: []const u8) ?usize {
    const deadline = GetTickCount64() + VPS_CHANNEL_READ_TIMEOUT_MS;
    var total: usize = 0;
    while (GetTickCount64() < deadline and total < buf.len) {
        var avail: DWORD = 0;
        if (PeekNamedPipe(h, null, 0, null, &avail, null) == 0) return null;
        if (avail == 0) {
            Sleep(20);
            continue;
        }
        const want: DWORD = @intCast(@min(@as(usize, avail), buf.len - total));
        var bytes_read: DWORD = 0;
        if (ReadFile(h, @ptrCast(buf[total..].ptr), want, &bytes_read, null) == 0 or bytes_read == 0) return null;
        total += bytes_read;
        if (std.mem.indexOf(u8, buf[0..total], sentinel)) |idx| return idx;
    }
    return null;
}

fn fetchHostPersistent(host: u8, buf: []u8) ?usize {
    if (host >= app_state.g_vps_channels.len) return null;
    while (!app_state.g_vps_channel_mutex.tryLock()) Sleep(1);
    defer app_state.g_vps_channel_mutex.unlock();
    defer if (app_state.g_vps_channels_close_pending.swap(false, .acq_rel)) {
        for (0..app_state.g_vps_channels.len) |h| closeVpsChannelUnlocked(@intCast(h));
    };

    const ch = &app_state.g_vps_channels[host];
    if (!ch.alive) spawnVpsChannelUnlocked(host);
    if (!ch.alive) return null;

    var written: DWORD = 0;
    if (WriteFile(ch.stdin_write, "\n", 1, &written, null) == 0 or written == 0) {
        closeVpsChannelUnlocked(host);
        return null;
    }
    const n = readVpsChannelUntilSentinel(ch.stdout_read, buf, VPS_CHANNEL_SENTINEL) orelse {
        closeVpsChannelUnlocked(host);
        return null;
    };
    return n;
}

pub fn sshOneShotCapture(cmd_str: []const u8, buf: []u8) usize {
    return sshOneShotCaptureInput(cmd_str, buf, null, 20000).len;
}

fn sshInputPump(input: HANDLE, output: HANDLE, activity: *std.atomic.Value(u64)) void {
    defer _ = CloseHandle(output);
    var chunk: [4096]u8 = undefined;
    while (true) {
        var count: DWORD = 0;
        if (ReadFile(input, &chunk, chunk.len, &count, null) == 0 or count == 0) return;
        var pos: DWORD = 0;
        while (pos < count) {
            var written: DWORD = 0;
            if (WriteFile(output, chunk[pos..].ptr, count - pos, &written, null) == 0 or written == 0) return;
            pos += written;
            _ = activity.fetchMax(GetTickCount64(), .release);
        }
    }
}

pub fn sshOneShotCaptureInput(cmd_str: []const u8, buf: []u8, stdin: HANDLE, timeout_ms: DWORD) struct { len: usize, success: bool } {
    var sa = SECURITY_ATTRIBUTES{
        .nLength = @sizeOf(SECURITY_ATTRIBUTES),
        .lpSecurityDescriptor = null,
        .bInheritHandle = 1,
    };
    var read_pipe: HANDLE = null;
    var write_pipe: HANDLE = null;
    if (CreatePipe(&read_pipe, &write_pipe, &sa, 1 << 20) == 0) {
        debugLog("sshOneShotCapture: CreatePipe failed");
        return .{ .len = 0, .success = false };
    }

    var stdin_read: HANDLE = null;
    var stdin_write: HANDLE = null;
    if (stdin != null) {
        if (CreatePipe(&stdin_read, &stdin_write, &sa, 0) == 0) {
            _ = CloseHandle(write_pipe);
            _ = CloseHandle(read_pipe);
            return .{ .len = 0, .success = false };
        }
        if (SetHandleInformation(stdin_write, HANDLE_FLAG_INHERIT, 0) == 0) {
            _ = CloseHandle(stdin_read);
            _ = CloseHandle(stdin_write);
            _ = CloseHandle(write_pipe);
            _ = CloseHandle(read_pipe);
            return .{ .len = 0, .success = false };
        }
    }
    defer if (stdin_write != null) {
        _ = CloseHandle(stdin_write);
    };

    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    si.dwFlags = 0x00000100;
    si.hStdOutput = write_pipe;
    si.hStdError = write_pipe;
    si.hStdInput = stdin_read;

    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    var cmd_buf: [4096]u16 = undefined;
    var pos: usize = 0;
    pos = std.unicode.utf8ToUtf16Le(cmd_buf[0 .. cmd_buf.len - 1], cmd_str) catch {
        if (stdin_read != null) _ = CloseHandle(stdin_read);
        _ = CloseHandle(write_pipe);
        _ = CloseHandle(read_pipe);
        return .{ .len = 0, .success = false };
    };
    cmd_buf[pos] = 0;

    const CREATE_NO_WINDOW: DWORD = 0x08000000;
    const ok = CreateProcessW(
        null,
        @ptrCast(&cmd_buf),
        null,
        null,
        1,
        CREATE_NO_WINDOW,
        null,
        null,
        &si,
        &pi,
    );
    if (stdin_read != null) _ = CloseHandle(stdin_read);
    _ = CloseHandle(write_pipe);
    if (ok == 0) {
        sshSpawnFailed();
        debugLog("sshOneShotCapture: CreateProcessW failed");
        _ = CloseHandle(read_pipe);
        return .{ .len = 0, .success = false };
    }
    _ = CloseHandle(pi.hThread);

    var activity = std.atomic.Value(u64).init(GetTickCount64());
    const pump = if (stdin != null) std.Thread.spawn(.{}, sshInputPump, .{ stdin, stdin_write, &activity }) catch {
        _ = TerminateProcess(pi.hProcess, 1);
        _ = CloseHandle(pi.hProcess);
        _ = CloseHandle(read_pipe);
        return .{ .len = 0, .success = false };
    } else null;
    if (pump != null) stdin_write = null;
    defer if (pump) |thread| thread.join();

    const WAIT_TIMEOUT: DWORD = 0x00000102;
    var total: usize = 0;
    while (true) {
        const result = WaitForSingleObject(pi.hProcess, 100);
        var available: DWORD = 0;
        while (PeekNamedPipe(read_pipe, null, 0, null, &available, null) != 0 and available > 0) {
            var chunk: [4096]u8 = undefined;
            var bytes_read: DWORD = 0;
            if (ReadFile(read_pipe, &chunk, @min(available, chunk.len), &bytes_read, null) == 0 or bytes_read == 0) break;
            if (stdin != null) _ = activity.fetchMax(GetTickCount64(), .release);
            if (stdin == null) {
                const keep = @min(bytes_read, buf.len - 1 - total);
                @memcpy(buf[total .. total + keep], chunk[0..keep]);
                total += keep;
            } else {
                const keep = @min(bytes_read, buf.len - 1);
                const retained = @min(total, buf.len - 1 - keep);
                std.mem.copyForwards(u8, buf[0..retained], buf[total - retained .. total]);
                @memcpy(buf[retained .. retained + keep], chunk[bytes_read - keep .. bytes_read]);
                total = retained + keep;
            }
        }
        if (result != WAIT_TIMEOUT) break;
        const last_activity = activity.load(.acquire);
        if (GetTickCount64() - last_activity >= timeout_ms) {
            debugLog("sshOneShotCapture: SSH timed out");
            _ = TerminateProcess(pi.hProcess, 1);
            _ = CloseHandle(pi.hProcess);
            _ = CloseHandle(read_pipe);
            return .{ .len = 0, .success = false };
        }
    }
    var exit_code: DWORD = 1;
    const exited = GetExitCodeProcess(pi.hProcess, &exit_code) != 0 and exit_code == 0;
    sshLoaderFailed(pi.hProcess);
    _ = CloseHandle(pi.hProcess);
    _ = CloseHandle(read_pipe);
    return .{ .len = total, .success = exited };
}

fn parseHostOutputIntoCache(host: u8, buf: []const u8, cache_count: *u32) u32 {
    var capacity = HostCapacity{};
    const total = buf.len;

    var added: u32 = 0;
    var line_start: usize = 0;
    var i: usize = 0;
    while (i <= total) : (i += 1) {
        if (i == total or buf[i] == '\n' or buf[i] == '\r') {
            const line_len = i - line_start;
            if (line_len > 0) {
                const line = buf[line_start .. line_start + line_len];
                if (std.mem.startsWith(u8, line, "@capacity|")) {
                    var capacity_fields = [_][]const u8{ "", "", "", "", "", "", "", "", "", "" };
                    var capacity_n: usize = 0;
                    var capacity_start: usize = 0;
                    var capacity_i: usize = 0;
                    while (capacity_i <= line.len and capacity_n < capacity_fields.len) : (capacity_i += 1) {
                        if (capacity_i == line.len or line[capacity_i] == '|') {
                            capacity_fields[capacity_n] = line[capacity_start..capacity_i];
                            capacity_n += 1;
                            capacity_start = capacity_i + 1;
                        }
                    }
                    if (capacity_n >= 10) {
                        capacity.cores = @intCast(@min(parseAsciiU64(capacity_fields[1]), std.math.maxInt(u16)));
                        capacity.load_milli = parseDecimalMilli(capacity_fields[2]);
                        capacity.mem_total_kb = parseAsciiU64(capacity_fields[3]);
                        capacity.mem_available_kb = parseAsciiU64(capacity_fields[4]);
                        capacity.swap_total_kb = parseAsciiU64(capacity_fields[5]);
                        capacity.swap_free_kb = parseAsciiU64(capacity_fields[6]);
                        capacity.cpu_psi_milli = parseDecimalMilli(capacity_fields[7]);
                        capacity.mem_psi_milli = parseDecimalMilli(capacity_fields[8]);
                        capacity.io_psi_milli = parseDecimalMilli(capacity_fields[9]);
                        capacity.valid = capacity.cores > 0 and capacity.mem_total_kb > 0;
                        capacity.updated_tick = GetTickCount64();
                    }
                } else if (cache_count.* < MAX_TMUX_SESSIONS) {
                    var fields = [_][]const u8{ "", "", "", "", "", "" };
                    var nf: usize = 0;
                    var fstart: usize = 0;
                    var ci: usize = 0;
                    while (ci <= line.len and nf < fields.len) : (ci += 1) {
                        if (ci == line.len or line[ci] == '|') {
                            fields[nf] = line[fstart..ci];
                            nf += 1;
                            fstart = ci + 1;
                        }
                    }
                    var entry: TmuxSessionEntry = undefined;
                    entry.activity = 0;
                    entry.ram_mb = 0;
                    entry.host = host;
                    entry.path_len = 0;
                    entry.title_len = 0;
                    entry.agent = 0;
                    const name_len = @min(fields[0].len, 63);
                    @memcpy(entry.name[0..name_len], fields[0][0..name_len]);
                    entry.name_len = @intCast(name_len);
                    if (nf >= 2) {
                        var unix_epoch: u64 = 0;
                        for (fields[1]) |c| {
                            if (c >= '0' and c <= '9') unix_epoch = unix_epoch * 10 + (c - '0');
                        }
                        if (unix_epoch > 0) entry.activity = (unix_epoch + 11_644_473_600) * 1000;
                    }
                    var fi: usize = 2;
                    while (fi < nf) : (fi += 1) {
                        const f = fields[fi];
                        if (f.len == 0) continue;
                        if (f[0] == '/') {
                            const pl = @min(f.len, 255);
                            @memcpy(entry.path[0..pl], f[0..pl]);
                            entry.path_len = @intCast(pl);
                        } else {
                            var ram: u32 = 0;
                            var all_digit = true;
                            for (f) |c| {
                                if (c >= '0' and c <= '9') {
                                    ram = ram * 10 + (c - '0');
                                } else {
                                    all_digit = false;
                                    break;
                                }
                            }
                            if (all_digit) entry.ram_mb = ram;
                        }
                        if (entry.agent == 0) entry.agent = tmuxAgentFromPaneCommand(f);

                        var raw = f;
                        if (raw.len >= 3 and raw[0] == 0xE2 and raw[1] == 0x9C and raw[2] == 0xB3) {
                            if (entry.agent == 0) entry.agent = 1;
                            var ts = raw[3..];
                            if (ts.len > 0 and ts[0] == ' ') ts = ts[1..];
                            while (ts.len > 0 and ts[0] == ' ') ts = ts[1..];
                            var out: [80]u8 = undefined;
                            var out_len: usize = 0;
                            for (ts) |c| {
                                if (out_len >= 79) break;
                                if (c >= 0x20 and c <= 0x7E) {
                                    out[out_len] = c;
                                    out_len += 1;
                                }
                            }
                            while (out_len > 0 and out[out_len - 1] == ' ') out_len -= 1;
                            var is_generic = false;
                            const out_slice = out[0..out_len];
                            if (asciiEqualsCI(out_slice, "Claude Code") or
                                asciiEqualsCI(out_slice, "Codex") or
                                asciiEqualsCI(out_slice, "OpenAI Codex") or
                                asciiEqualsCI(out_slice, "Kimi") or
                                asciiEqualsCI(out_slice, "Kimi Code") or
                                asciiEqualsCI(out_slice, "Kimi Code CLI") or
                                asciiEqualsCI(out_slice, "Hax") or
                                asciiEqualsCI(out_slice, "Grok") or
                                asciiEqualsCI(out_slice, "Cursor"))
                                is_generic = true;
                            if (!is_generic and out_len == entry.name_len) {
                                var same = true;
                                for (0..out_len) |ji| {
                                    const oc: u8 = if (out[ji] >= 'A' and out[ji] <= 'Z') out[ji] + 32 else out[ji];
                                    const nc: u8 = if (entry.name[ji] >= 'A' and entry.name[ji] <= 'Z') entry.name[ji] + 32 else entry.name[ji];
                                    if (oc != nc) {
                                        same = false;
                                        break;
                                    }
                                }
                                if (same) is_generic = true;
                            }
                            if (out_len > 0 and !is_generic) {
                                @memcpy(entry.title[0..out_len], out[0..out_len]);
                                entry.title_len = @intCast(out_len);
                            }
                        }
                    }
                    app_state.g_tmux_cache[cache_count.*] = entry;
                    cache_count.* += 1;
                    added += 1;
                    capacity.tmux_sessions +|= 1;
                    if (entry.agent != 0) {
                        capacity.resident_agents +|= 1;
                        capacity.resident_ram_mb +|= entry.ram_mb;
                    }
                }
            }
            if (i < total and buf[i] == '\r' and i + 1 < total and buf[i + 1] == '\n') i += 1;
            line_start = i + 1;
        }
    }

    if (capacity.valid and host < app_state.g_host_capacity.len) {
        app_state.g_host_capacity[host] = applyCapacityHysteresis(host, capacity);
    }
    return added;
}

fn fetchHostIntoCache(host: u8, cmd_str: []const u8, cache_count: *u32) void {
    var buf: [131072]u8 = undefined;
    var total: usize = 0;
    var via_persistent = false;
    if (host < app_state.g_vps_channels.len) {
        if (fetchHostPersistent(host, &buf)) |n| {
            total = n;
            via_persistent = true;
        }
    }
    if (total == 0) {
        via_persistent = false;
        total = sshOneShotCapture(cmd_str, &buf);
    }
    if (total == 0) {
        debugLog2("fetchHostIntoCache: no output host=", tmuxHostLongLabel(host));
        return;
    }

    const added = parseHostOutputIntoCache(host, buf[0..total], cache_count);

    var stat_buf: [128]u8 = undefined;
    const stat_str = std.fmt.bufPrint(&stat_buf, "fetchHostIntoCache(host={d}) done: total={d} bytes, added={d}, persistent={d}", .{ host, total, added, @intFromBool(via_persistent) }) catch "fetchHostIntoCache done: (fmt err)";
    debugLog(stat_str);
    if (added == 0 and total > 0) {
        const head_len = @min(total, @as(usize, 400));
        debugLog2("fetchHostIntoCache raw: ", buf[0..head_len]);
    }
}

fn tmuxFetchThreadDual() void {
    crash_recorder.guardThread();
    var count: u32 = 0;
    var command_de: [2048]u8 = undefined;
    var pos_de: usize = 0;
    if (appendSshExe(&command_de, &pos_de) and
        appendAsciiBuf(&command_de, &pos_de, "-o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o ConnectTimeout=5 vps \"" ++ VPS_PROBE_SCRIPT ++ VPS_TMUX_LIST_SCRIPT ++ "\""))
        fetchHostIntoCache(TMUX_HOST_DE, command_de[0..pos_de], &count);
    var command_uk: [2048]u8 = undefined;
    var pos_uk: usize = 0;
    if (appendSshExe(&command_uk, &pos_uk) and
        appendAsciiBuf(&command_uk, &pos_uk, "-o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o ConnectTimeout=5 remote-2 \"" ++ VPS_PROBE_SCRIPT ++ VPS_TMUX_LIST_SCRIPT ++ "\""))
        fetchHostIntoCache(TMUX_HOST_UK, command_uk[0..pos_uk], &count);
    var command_inne: [2048]u8 = undefined;
    var pos_inne: usize = 0;
    if (appendSshExe(&command_inne, &pos_inne) and
        appendAsciiBuf(&command_inne, &pos_inne, "-o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o ConnectTimeout=5 remote-3 \"" ++ VPS_PROBE_SCRIPT ++ VPS_TMUX_LIST_SCRIPT ++ "\""))
        fetchHostIntoCache(TMUX_HOST_INNE, command_inne[0..pos_inne], &count);

    app_state.g_tmux_cache_count = count;
    var ft_now: [2]DWORD = undefined;
    GetSystemTimeAsFileTime(&ft_now);
    app_state.g_tmux_cache_tick = ((@as(u64, ft_now[1]) << 32) | @as(u64, ft_now[0])) / 10_000;
    app_state.g_tmux_fetch_tick = GetTickCount64();
    app_state.g_tmux_fetching = false;

    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_TMUX_LIST_READY, 0, 0);
}

fn vpsPollCachePath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 470) return null;
    const rest = "\\ZigShell\\poll-cache-vps.json";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

pub fn ensureVpsPollLeadership() void {
    if (app_state.g_vps_poll_is_leader) return;
    if (app_state.g_vps_poll_leader_mutex == null) {
        app_state.g_vps_poll_leader_mutex = CreateMutexW(null, 0, L("Local\\ZigShellPowerPollLeader"));
        if (app_state.g_vps_poll_leader_mutex == null) return;
    }
    const result = WaitForSingleObject(app_state.g_vps_poll_leader_mutex, 0);
    const WAIT_ABANDONED: DWORD = 0x80;
    if (result == 0 or result == WAIT_ABANDONED) {
        app_state.g_vps_poll_is_leader = true;
        debugLog("[power] this window is the VPS-poll leader");
    }
}

pub fn releaseVpsPollLeadership() void {
    if (app_state.g_vps_poll_leader_mutex == null) return;
    if (app_state.g_vps_poll_is_leader) _ = ReleaseMutex(app_state.g_vps_poll_leader_mutex);
    _ = CloseHandle(app_state.g_vps_poll_leader_mutex);
    app_state.g_vps_poll_leader_mutex = null;
    app_state.g_vps_poll_is_leader = false;
}

pub fn writeVpsPollCache() void {
    var dir_buf: [512]u8 = undefined;
    if (getSessionDir(&dir_buf)) |dir| win32MakeDir(dir);
    var path_buf: [512]u8 = undefined;
    const path = vpsPollCachePath(&path_buf) orelse return;

    var json: [SESSION_JSON_CAPACITY]u8 = undefined;
    var pos: usize = 0;
    const head = "{\"v\":1,\"cap\":[";
    @memcpy(json[pos .. pos + head.len], head);
    pos += head.len;
    for (0..app_state.g_host_capacity.len) |h| {
        if (h > 0 and pos < json.len) {
            json[pos] = ',';
            pos += 1;
        }
        const cap = app_state.g_host_capacity[h];
        const line = std.fmt.bufPrint(json[pos..], "{{\"host\":{d},\"valid\":{s},\"cores\":{d},\"load_milli\":{d},\"mem_total_kb\":{d},\"mem_available_kb\":{d},\"swap_total_kb\":{d},\"swap_free_kb\":{d},\"cpu_psi_milli\":{d},\"mem_psi_milli\":{d},\"io_psi_milli\":{d}}}", .{
            h, if (cap.valid) "true" else "false", cap.cores, cap.load_milli, cap.mem_total_kb, cap.mem_available_kb, cap.swap_total_kb, cap.swap_free_kb, cap.cpu_psi_milli, cap.mem_psi_milli, cap.io_psi_milli,
        }) catch break;
        pos += line.len;
    }
    const mid = "],\"sessions\":[";
    if (pos + mid.len >= json.len) return;
    @memcpy(json[pos .. pos + mid.len], mid);
    pos += mid.len;
    var si: u32 = 0;
    while (si < app_state.g_tmux_cache_count and pos + 900 < json.len) : (si += 1) {
        const e = &app_state.g_tmux_cache[si];
        if (si > 0) {
            json[pos] = ',';
            pos += 1;
        }
        const h1 = "{\"name\":\"";
        @memcpy(json[pos .. pos + h1.len], h1);
        pos += h1.len;
        appendJsonEscaped(&json, &pos, e.name[0..e.name_len]);
        const numbers = std.fmt.bufPrint(json[pos..], "\",\"activity\":{d},\"ram_mb\":{d},\"host\":{d},\"agent\":{d},\"path\":\"", .{ e.activity, e.ram_mb, e.host, e.agent }) catch break;
        pos += numbers.len;
        appendJsonEscaped(&json, &pos, e.path[0..e.path_len]);
        const p2 = "\",\"title\":\"";
        @memcpy(json[pos .. pos + p2.len], p2);
        pos += p2.len;
        appendJsonEscaped(&json, &pos, e.title[0..e.title_len]);
        const p3 = "\"}";
        @memcpy(json[pos .. pos + p3.len], p3);
        pos += p3.len;
    }
    const tail = "]}";
    if (pos + tail.len >= json.len) return;
    @memcpy(json[pos .. pos + tail.len], tail);
    pos += tail.len;

    _ = writeFileAtomicW(path, json[0..pos]);
}

fn vpsPollCacheJsonString(value: ?std.json.Value) []const u8 {
    if (value) |v| if (v == .string) return v.string;
    return "";
}
fn vpsPollCacheJsonInt(value: ?std.json.Value) i64 {
    if (value) |v| {
        if (v == .integer) return v.integer;
        if (v == .float) return @intFromFloat(v.float);
    }
    return 0;
}
fn vpsPollCacheJsonBool(value: ?std.json.Value) bool {
    if (value) |v| if (v == .bool) return v.bool;
    return false;
}

pub fn loadVpsPollCacheIfChanged() void {
    var path_buf: [512]u8 = undefined;
    const path = vpsPollCachePath(&path_buf) orelse return;
    var wbuf: [520]u16 = undefined;
    const w = win32WidePath(&wbuf, path) orelse return;
    var data: WIN32_FIND_DATAW = undefined;
    const find = FindFirstFileW(w.ptr, &data);
    if (find == INVALID_HANDLE_VALUE_PTR) return;
    _ = FindClose(find);
    if (data.ftLastWriteTime.dwLowDateTime == app_state.g_vps_poll_cache_mtime_lo and
        data.ftLastWriteTime.dwHighDateTime == app_state.g_vps_poll_cache_mtime_hi) return;
    app_state.g_vps_poll_cache_mtime_lo = data.ftLastWriteTime.dwLowDateTime;
    app_state.g_vps_poll_cache_mtime_hi = data.ftLastWriteTime.dwHighDateTime;

    const h = win32OpenRead(path) orelse return;
    var json_buf: [SESSION_JSON_CAPACITY]u8 = undefined;
    const n = win32ReadAll(h, &json_buf);
    _ = CloseHandle(h);
    if (n == 0) return;

    var parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, json_buf[0..n], .{}) catch return;
    defer parsed.deinit();
    const root = parsed.value;
    if (root != .object) return;

    if (root.object.get("cap")) |cap_arr| {
        if (cap_arr == .array) {
            for (cap_arr.array.items) |item| {
                if (item != .object) continue;
                const o = item.object;
                const host: u8 = @intCast(@max(0, @min(255, vpsPollCacheJsonInt(o.get("host")))));
                if (host >= app_state.g_host_capacity.len) continue;
                var fresh = HostCapacity{};
                fresh.valid = vpsPollCacheJsonBool(o.get("valid"));
                fresh.cores = @intCast(@max(0, @min(std.math.maxInt(u16), vpsPollCacheJsonInt(o.get("cores")))));
                fresh.load_milli = @intCast(@max(0, vpsPollCacheJsonInt(o.get("load_milli"))));
                fresh.mem_total_kb = @intCast(@max(0, vpsPollCacheJsonInt(o.get("mem_total_kb"))));
                fresh.mem_available_kb = @intCast(@max(0, vpsPollCacheJsonInt(o.get("mem_available_kb"))));
                fresh.swap_total_kb = @intCast(@max(0, vpsPollCacheJsonInt(o.get("swap_total_kb"))));
                fresh.swap_free_kb = @intCast(@max(0, vpsPollCacheJsonInt(o.get("swap_free_kb"))));
                fresh.cpu_psi_milli = @intCast(@max(0, vpsPollCacheJsonInt(o.get("cpu_psi_milli"))));
                fresh.mem_psi_milli = @intCast(@max(0, vpsPollCacheJsonInt(o.get("mem_psi_milli"))));
                fresh.io_psi_milli = @intCast(@max(0, vpsPollCacheJsonInt(o.get("io_psi_milli"))));
                fresh.updated_tick = GetTickCount64();
                if (fresh.valid) app_state.g_host_capacity[host] = applyCapacityHysteresis(host, fresh);
            }
        }
    }

    if (root.object.get("sessions")) |sess_arr| {
        if (sess_arr == .array) {
            var count: u32 = 0;
            for (sess_arr.array.items) |item| {
                if (count >= MAX_TMUX_SESSIONS) break;
                if (item != .object) continue;
                const o = item.object;
                var entry: TmuxSessionEntry = undefined;
                entry.activity = @intCast(@max(0, vpsPollCacheJsonInt(o.get("activity"))));
                entry.ram_mb = @intCast(@max(0, vpsPollCacheJsonInt(o.get("ram_mb"))));
                entry.host = @intCast(@max(0, @min(255, vpsPollCacheJsonInt(o.get("host")))));
                entry.agent = @intCast(@max(0, @min(255, vpsPollCacheJsonInt(o.get("agent")))));
                entry.path_len = 0;
                entry.title_len = 0;
                const name = vpsPollCacheJsonString(o.get("name"));
                const name_len = @min(name.len, entry.name.len);
                @memcpy(entry.name[0..name_len], name[0..name_len]);
                entry.name_len = @intCast(name_len);
                const path_s = vpsPollCacheJsonString(o.get("path"));
                const path_len = @min(path_s.len, entry.path.len);
                @memcpy(entry.path[0..path_len], path_s[0..path_len]);
                entry.path_len = @intCast(path_len);
                const title_s = vpsPollCacheJsonString(o.get("title"));
                const title_len = @min(title_s.len, entry.title.len);
                @memcpy(entry.title[0..title_len], title_s[0..title_len]);
                entry.title_len = @intCast(title_len);
                app_state.g_tmux_cache[count] = entry;
                count += 1;
            }
            app_state.g_tmux_cache_count = count;
            var ft_now: [2]DWORD = undefined;
            GetSystemTimeAsFileTime(&ft_now);
            app_state.g_tmux_cache_tick = ((@as(u64, ft_now[1]) << 32) | @as(u64, ft_now[0])) / 10_000;
            app_state.g_tmux_fetch_tick = GetTickCount64();
        }
    }

    if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_TMUX_LIST_READY, 0, 0);
}

pub fn syncLiveTmuxMetadataFromCache() bool {
    var changed = false;

    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].kind != .tmux or app_state.shells[i].tmux_session_len == 0) continue;
        const sname = app_state.shells[i].tmux_session[0..app_state.shells[i].tmux_session_len];

        var match: ?*const TmuxSessionEntry = null;
        var ti: u32 = 0;
        while (ti < app_state.g_tmux_cache_count) : (ti += 1) {
            const e = &app_state.g_tmux_cache[ti];
            if (e.host != app_state.shells[i].tmux_host) continue;
            if (!std.mem.eql(u8, e.name[0..e.name_len], sname)) continue;
            match = e;
            break;
        }
        const e = match orelse continue;

        if (e.agent != 0 and app_state.shells[i].ai_agent != e.agent) {
            app_state.shells[i].ai_agent = e.agent;
            changed = true;
        }
    }

    if (changed) publishInboxState();
    return changed;
}

pub fn tmuxHostForShell(shell: *const Shell) ?u8 {
    return switch (shell.kind) {
        .tmux => shell.tmux_host,
        .vps => 0,
        .vps2 => 1,
        else => null,
    };
}

pub fn tmuxCacheEntryAlreadyOpen(entry: *const TmuxSessionEntry) bool {
    const cached_name = entry.name[0..entry.name_len];
    for (0..app_state.shell_count) |si| {
        if (app_state.shells[si].tmux_session_len == 0) continue;
        const host = tmuxHostForShell(&app_state.shells[si]) orelse continue;
        if (host != entry.host) continue;
        if (app_state.shells[si].tmux_session_len != entry.name_len) continue;
        const active_name = app_state.shells[si].tmux_session[0..app_state.shells[si].tmux_session_len];
        if (std.ascii.eqlIgnoreCase(cached_name, active_name)) return true;
    }
    return false;
}

pub fn buildFilteredTmux() void {
    app_state.g_inactive_filtered_count = 0;
    var ti: u32 = 0;
    while (ti < app_state.g_tmux_cache_count) : (ti += 1) {
        if (tmuxCacheEntryAlreadyOpen(&app_state.g_tmux_cache[ti])) continue;

        if (app_state.g_inactive_filtered_count < app_state.g_inactive_filtered.len) {
            app_state.g_inactive_filtered[app_state.g_inactive_filtered_count] = ti;
            app_state.g_inactive_filtered_count += 1;
        }
    }

    var i: u32 = 1;
    while (i < app_state.g_inactive_filtered_count) : (i += 1) {
        const key_idx = app_state.g_inactive_filtered[i];
        const key_activity = app_state.g_tmux_cache[key_idx].activity;
        var j: i32 = @as(i32, @intCast(i)) - 1;
        while (j >= 0 and app_state.g_tmux_cache[app_state.g_inactive_filtered[@intCast(j)]].activity < key_activity) : (j -= 1) {
            app_state.g_inactive_filtered[@intCast(j + 1)] = app_state.g_inactive_filtered[@intCast(j)];
        }
        app_state.g_inactive_filtered[@intCast(j + 1)] = key_idx;
    }
}

pub fn inactiveTmuxCountForHost(host: u8) u32 {
    var count: u32 = 0;
    var i: u32 = 0;
    while (i < app_state.g_inactive_filtered_count) : (i += 1) {
        if (app_state.g_tmux_cache[app_state.g_inactive_filtered[i]].host == host) count += 1;
    }
    return count;
}

pub fn pathUnderFolder(p: []const u8, folder: []const u8) bool {
    var f = folder;
    while (f.len > 1 and f[f.len - 1] == '/') f = f[0 .. f.len - 1];
    if (f.len == 0) return false;
    if (p.len == f.len and std.mem.eql(u8, p, f)) return true;
    if (p.len > f.len and std.mem.startsWith(u8, p, f) and p[f.len] == '/') return true;
    return false;
}

pub fn shellKnownRemotePath(shell: *const Shell, host: u8) ?[]const u8 {
    if (tmuxCachePathForShell(shell, host)) |p| return p;
    if (shell.cached_cwd_len > 0) return shell.cached_cwd[0..shell.cached_cwd_len];
    if (shell.claude_cwd_len > 0) return shell.claude_cwd[0..shell.claude_cwd_len];
    return null;
}

pub fn focusedSessionFolder(out_host: *u8, out_path: *[256]u8, out_len: *u32) bool {
    if (app_state.active_shell >= app_state.shell_count) return false;
    const s = &app_state.shells[app_state.active_shell];
    if (s.kind != .tmux and s.kind != .vps and s.kind != .vps2) return false;
    const host = remoteHostForShell(s) orelse return false;
    if (s.kind == .tmux and s.tmux_session_len > 0) {
        const sname = s.tmux_session[0..s.tmux_session_len];
        var ti: u32 = 0;
        while (ti < app_state.g_tmux_cache_count) : (ti += 1) {
            const e = &app_state.g_tmux_cache[ti];
            if (e.host == host and e.path_len > 0 and std.mem.eql(u8, e.name[0..e.name_len], sname)) {
                @memcpy(out_path[0..e.path_len], e.path[0..e.path_len]);
                out_len.* = e.path_len;
                out_host.* = host;
                return true;
            }
        }
    }
    if (shellKnownRemotePath(s, host)) |p| {
        const n = @min(p.len, 255);
        @memcpy(out_path[0..n], p[0..n]);
        out_len.* = n;
        out_host.* = host;
        return true;
    }
    return false;
}

fn shellBelongsToActiveWorkspace(i: usize) bool {
    return !app_state.g_single_window or app_state.shells[i].workspace == app_state.g_active_workspace;
}

fn tmuxCachePathForShell(shell: *const Shell, host: u8) ?[]const u8 {
    if (shell.tmux_session_len == 0) return null;
    const sname = shell.tmux_session[0..shell.tmux_session_len];
    var ti: u32 = 0;
    while (ti < app_state.g_tmux_cache_count) : (ti += 1) {
        const e = &app_state.g_tmux_cache[ti];
        if (e.host != host or e.path_len == 0) continue;
        if (std.ascii.eqlIgnoreCase(e.name[0..e.name_len], sname)) return e.path[0..e.path_len];
    }
    return null;
}

pub fn remoteRepoRoot(path: []const u8) []const u8 {
    var p = std.mem.trim(u8, path, &[_]u8{ ' ', '\t', '\r', '\n' });
    while (p.len > 1 and p[p.len - 1] == '/') p = p[0 .. p.len - 1];
    if (p.len == 0 or p[0] != '/') return p[0..0];

    const home = "/home/";
    if (!std.mem.startsWith(u8, p, home)) return p;
    const user_end = std.mem.indexOfScalarPos(u8, p, home.len, '/') orelse return p;
    const projects = "/projects/";
    const project_start = user_end + projects.len;
    if (std.mem.startsWith(u8, p[user_end..], projects) and p.len > project_start) {
        var end = project_start;
        while (end < p.len and p[end] != '/') : (end += 1) {}
        return p[0..end];
    }
    return p;
}

pub fn workspacePrimaryRepo(out_host: *u8, out_path: *[256]u8, out_len: *u32) bool {
    var candidates: [MAX_SHELLS]WorkspaceRepoCandidate = undefined;
    var candidate_count: u32 = 0;

    for (0..app_state.shell_count) |i| {
        if (!shellBelongsToActiveWorkspace(i)) continue;
        const host = tmuxHostForShell(&app_state.shells[i]) orelse continue;
        const raw_path = shellKnownRemotePath(&app_state.shells[i], host) orelse continue;
        const root = remoteRepoRoot(raw_path);
        if (root.len == 0 or root.len > 255) continue;

        var found: ?u32 = null;
        var ci: u32 = 0;
        while (ci < candidate_count) : (ci += 1) {
            const c = &candidates[ci];
            if (c.host == host and c.path_len == root.len and std.mem.eql(u8, c.path[0..c.path_len], root)) {
                found = ci;
                break;
            }
        }
        const idx = found orelse blk2: {
            if (candidate_count >= candidates.len) continue;
            const ni = candidate_count;
            candidate_count += 1;
            candidates[ni] = WorkspaceRepoCandidate{};
            candidates[ni].host = host;
            @memcpy(candidates[ni].path[0..root.len], root);
            candidates[ni].path_len = @intCast(root.len);
            break :blk2 ni;
        };
        candidates[idx].score += if (i == app_state.active_shell) 3 else 1;
        if (app_state.shells[i].last_active > candidates[idx].last_active) candidates[idx].last_active = app_state.shells[i].last_active;
    }

    if (candidate_count == 0) return false;
    var best: u32 = 0;
    var ci: u32 = 1;
    while (ci < candidate_count) : (ci += 1) {
        if (candidates[ci].score > candidates[best].score or
            (candidates[ci].score == candidates[best].score and candidates[ci].last_active > candidates[best].last_active))
        {
            best = ci;
        }
    }
    out_host.* = candidates[best].host;
    out_len.* = candidates[best].path_len;
    @memcpy(out_path[0..out_len.*], candidates[best].path[0..out_len.*]);
    return true;
}

pub fn countFolderSessions(host: u8, folder: []const u8) u32 {
    var n: u32 = 0;
    var ti: u32 = 0;
    while (ti < app_state.g_inactive_filtered_count) : (ti += 1) {
        const e = &app_state.g_tmux_cache[app_state.g_inactive_filtered[ti]];
        if (e.host != host or e.path_len == 0) continue;
        if (pathUnderFolder(e.path[0..e.path_len], folder)) n += 1;
    }
    return n;
}
