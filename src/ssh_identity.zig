const std = @import("std");
const w = @import("win32.zig");
const state = @import("app_state.zig");
const servers = @import("ssh_servers.zig");
const hosts = @import("account_hosts.zig");
const keys = @import("account_keys.zig");
const files = @import("file_io.zig");
const console = @import("console.zig");
const debugLog = @import("diagnostics.zig").debugLog;

extern "advapi32" fn ConvertSidToStringSidW(?*anyopaque, *?[*:0]u16) callconv(.winapi) w.BOOL;
extern "advapi32" fn ConvertStringSecurityDescriptorToSecurityDescriptorW([*:0]const u16, u32, *?*anyopaque, ?*u32) callconv(.winapi) w.BOOL;
extern "advapi32" fn SetFileSecurityW([*:0]const u16, u32, ?*anyopaque) callconv(.winapi) w.BOOL;
extern "kernel32" fn LocalFree(?*anyopaque) callconv(.winapi) ?*anyopaque;

pub const aliases = [_][]const u8{ state.SSH_TARGET_DE, state.SSH_TARGET_UK, state.SSH_TARGET_INNE };

pub const View = struct {
    table: servers.Table = @splat(.{}),
    checking: ?usize = null,
    busy: bool = false,
    message: servers.Text = .{},
    paste: [1024]u8 = undefined,
    paste_len: usize = 0,
};

const Job = union(enum) { startup, check: usize, add: usize, remove: usize, paste };

var lock: state.SpinMutex = .{};
var table: servers.Table = @splat(.{});
var loaded = false;
var checking: ?usize = null;
var message: servers.Text = .{};
var paste: [1024]u8 = undefined;
var paste_len: usize = 0;
var running = std.atomic.Value(bool).init(false);
var started = std.atomic.Value(bool).init(false);

fn acquire() void {
    while (!lock.tryLock()) w.Sleep(1);
}

fn setMessage(text: []const u8) void {
    acquire();
    defer lock.unlock();
    message.set(text);
}

pub fn view(out: *View) void {
    acquire();
    defer lock.unlock();
    out.table = table;
    out.checking = checking;
    out.busy = running.load(.acquire);
    out.message = message;
    @memcpy(out.paste[0..paste_len], paste[0..paste_len]);
    out.paste_len = paste_len;
}

fn nowSeconds() u64 {
    var stamp: [2]w.DWORD = undefined;
    w.GetSystemTimeAsFileTime(&stamp);
    const ticks = (@as(u64, stamp[1]) << 32) | stamp[0];
    return (ticks / 10_000_000) -| 11_644_473_600;
}

fn dataPath(buf: []u8, name: []const u8) ?[]const u8 {
    var base: [400]u8 = undefined;
    const n = w.GetEnvironmentVariableA("APPDATA", &base, base.len);
    if (n == 0 or n >= base.len) return null;
    return std.fmt.bufPrint(buf, "{s}\\ZigShell\\ssh-key{s}{s}", .{ base[0..n], if (name.len > 0) "\\" else "", name }) catch null;
}

pub fn configFile(buf: []u8) ?[]const u8 {
    return dataPath(buf, "config");
}

fn envPath(buf: []u8, name: [*:0]const u8, tail: []const u8) ?[]const u8 {
    var base: [400]u8 = undefined;
    const n = w.GetEnvironmentVariableA(name, &base, base.len);
    if (n == 0 or n >= base.len) return null;
    return std.fmt.bufPrint(buf, "{s}{s}", .{ base[0..n], tail }) catch null;
}

fn exists(target: []const u8) bool {
    var wide: [520]u16 = undefined;
    const path = files.win32WidePath(&wide, target) orelse return false;
    return w.GetFileAttributesW(path.ptr) != 0xffffffff;
}

fn privateDescriptor() ?*anyopaque {
    var token: w.HANDLE = null;
    if (w.OpenProcessToken(w.GetCurrentProcess(), 0x0008, &token) == 0) return null;
    defer _ = w.CloseHandle(token);
    var data: [256]u8 align(8) = undefined;
    var size: w.DWORD = 0;
    if (w.GetTokenInformation(token, 1, &data, data.len, &size) == 0) return null;
    const sid: *const ?*anyopaque = @ptrCast(&data);
    var text: ?[*:0]u16 = null;
    if (ConvertSidToStringSidW(sid.*, &text) == 0) return null;
    const sid_text = text orelse return null;
    defer _ = LocalFree(@ptrCast(sid_text));
    const user = std.mem.span(sid_text);
    const head = "D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;";
    var sddl: [256:0]u16 = @splat(0);
    if (head.len + user.len + 1 >= sddl.len) return null;
    for (head, 0..) |c, i| sddl[i] = c;
    @memcpy(sddl[head.len .. head.len + user.len], user);
    sddl[head.len + user.len] = ')';
    var descriptor: ?*anyopaque = null;
    if (ConvertStringSecurityDescriptorToSecurityDescriptorW(&sddl, 1, &descriptor, null) == 0) return null;
    return descriptor;
}

fn protect(target: []const u8, descriptor: ?*anyopaque) bool {
    var wide: [520]u16 = undefined;
    const path = files.win32WidePath(&wide, target) orelse return false;
    return SetFileSecurityW(path.ptr, 0x4 | 0x80000000, descriptor) != 0;
}

const Output = struct { ok: bool, text: []const u8 };

fn run(a: std.mem.Allocator, command: []const u8, timeout_ms: u32) !Output {
    var cmd: [4096]u16 = undefined;
    const cmd_z = files.win32WidePath(&cmd, command) orelse return error.TooLong;
    var sa = w.SECURITY_ATTRIBUTES{ .nLength = @sizeOf(w.SECURITY_ATTRIBUTES), .lpSecurityDescriptor = null, .bInheritHandle = 1 };
    var reader: w.HANDLE = null;
    var writer: w.HANDLE = null;
    if (w.CreatePipe(&reader, &writer, &sa, 0) == 0) return error.Storage;
    defer _ = w.CloseHandle(reader);
    if (w.SetHandleInformation(reader, 1, 0) == 0) {
        _ = w.CloseHandle(writer);
        return error.Storage;
    }
    var si = std.mem.zeroes(w.STARTUPINFOW);
    si.cb = @sizeOf(w.STARTUPINFOW);
    si.dwFlags = 0x00000100;
    si.hStdOutput = writer;
    si.hStdError = writer;
    var pi = std.mem.zeroes(w.PROCESS_INFORMATION);
    const created = w.CreateProcessW(null, cmd_z.ptr, null, null, 1, 0x08000000, null, null, &si, &pi);
    _ = w.CloseHandle(writer);
    if (created == 0) return error.Process;
    _ = w.CloseHandle(pi.hThread);
    defer _ = w.CloseHandle(pi.hProcess);
    defer {
        if (w.WaitForSingleObject(pi.hProcess, 0) != 0) {
            _ = w.TerminateProcess(pi.hProcess, 1);
            _ = w.WaitForSingleObject(pi.hProcess, 1000);
        }
    }
    const deadline = w.GetTickCount64() + timeout_ms;
    var output: std.ArrayList(u8) = .empty;
    var done = false;
    while (true) {
        var available: w.DWORD = 0;
        if (w.PeekNamedPipe(reader, null, 0, null, &available, null) != 0 and available > 0) {
            var buf: [4096]u8 = undefined;
            var count: w.DWORD = 0;
            if (w.ReadFile(reader, &buf, @min(available, buf.len), &count, null) == 0) break;
            if (output.items.len + count <= 65536) try output.appendSlice(a, buf[0..count]);
            continue;
        }
        if (done) break;
        if (w.GetTickCount64() >= deadline) return .{ .ok = false, .text = "Connection timed out" };
        done = w.WaitForSingleObject(pi.hProcess, 10) == 0;
    }
    var exit: w.DWORD = 1;
    const ok = w.GetExitCodeProcess(pi.hProcess, &exit) != 0 and exit == 0;
    return .{ .ok = ok, .text = output.items };
}

fn sshPrefix(a: std.mem.Allocator) ![]const u8 {
    var buf: [1024]u8 = undefined;
    for (0..50) |_| {
        var len: usize = 0;
        if (console.appendSshExe(&buf, &len)) return a.dupe(u8, buf[0..len]);
        w.Sleep(20);
    }
    return error.SshUnavailable;
}

fn ensureKey(a: std.mem.Allocator, exe: []const u8) ![]const u8 {
    var dir_buf: [520]u8 = undefined;
    const dir = dataPath(&dir_buf, "") orelse return error.Storage;
    files.win32MakePath(dir);
    const descriptor = privateDescriptor() orelse return error.Storage;
    defer _ = LocalFree(descriptor);
    if (!protect(dir, descriptor)) return error.Storage;
    var key_buf: [520]u8 = undefined;
    const key = dataPath(&key_buf, "multibot_ed25519") orelse return error.Storage;
    const public_path = try std.fmt.allocPrint(a, "{s}.pub", .{key});
    if (!exists(key)) {
        if (exists(public_path)) {
            var wide: [520]u16 = undefined;
            const stale = files.win32WidePath(&wide, public_path) orelse return error.Storage;
            _ = w.DeleteFileW(stale.ptr);
        }
        const slash = std.mem.lastIndexOfAny(u8, exe, "\\/") orelse return error.SshUnavailable;
        const generate = try std.fmt.allocPrint(a, "\"{s}\\ssh-keygen.exe\" -t ed25519 -N \"\" -q -C multibot -f \"{s}\"", .{ exe[0..slash], key });
        const made = try run(a, generate, 30000);
        if (!made.ok) return error.Process;
    }
    if (!protect(key, descriptor)) return error.Storage;
    const bytes = files.readFileAllocWin32(public_path, 4096) orelse return error.Storage;
    defer std.heap.page_allocator.free(bytes);
    return keys.parsePublicKey(a, bytes);
}

fn keyFile(buf: []u8) ?[]const u8 {
    return dataPath(buf, "multibot_ed25519");
}

fn loadLocked() void {
    if (loaded) return;
    loaded = true;
    var buf: [520]u8 = undefined;
    const path = dataPath(&buf, "servers.txt") orelse return;
    const bytes = files.readFileAllocWin32(path, 64 * 1024) orelse return;
    defer std.heap.page_allocator.free(bytes);
    table = servers.decode(bytes);
}

fn publish(a: std.mem.Allocator, exe: []const u8) void {
    acquire();
    const snapshot = table;
    lock.unlock();
    var state_buf: [520]u8 = undefined;
    const state_path = dataPath(&state_buf, "servers.txt") orelse return;
    const encoded = servers.encode(a, &snapshot) catch return;
    if (!files.writeFileAtomicSync(state_path, encoded)) debugLog("ssh-key: could not save server list");
    var key_buf: [520]u8 = undefined;
    var system_buf: [520]u8 = undefined;
    var config_buf: [520]u8 = undefined;
    const key = keyFile(&key_buf) orelse return;
    const system_config = envPath(&system_buf, "PROGRAMDATA", "\\ssh\\ssh_config") orelse return;
    const config = configFile(&config_buf) orelse return;
    const next = std.fmt.allocPrint(a, "{s}.next", .{config}) catch return;
    var config_w_buf: [520]u16 = undefined;
    var next_w_buf: [520]u16 = undefined;
    const config_w = files.win32WidePath(&config_w_buf, config) orelse return;
    const next_w = files.win32WidePath(&next_w_buf, next) orelse return;
    var any_forced = false;
    for (snapshot) |slot| any_forced = any_forced or servers.forced(slot);
    if (!any_forced) {
        console.setSshConfig(null);
        _ = w.DeleteFileW(config_w.ptr);
        return;
    }
    const rendered = servers.renderConfig(a, key, "~/.ssh/config", system_config, &aliases, &snapshot) catch {
        debugLog("ssh-key: config not rendered, using default ssh settings");
        console.setSshConfig(null);
        _ = w.DeleteFileW(config_w.ptr);
        return;
    };
    if (!files.writeFileAtomicSync(next, rendered)) return;
    const probe = std.fmt.allocPrint(a, "\"{s}\" -F \"{s}\" -G {s}", .{ exe, next, aliases[0] }) catch return;
    const checked = run(a, probe, 5000) catch Output{ .ok = false, .text = "" };
    if (!checked.ok or !sameAddresses(a, exe, next, &snapshot) or w.MoveFileExW(next_w.ptr, config_w.ptr, 1 | 8) == 0) {
        debugLog("ssh-key: config check failed, using default ssh settings");
        console.setSshConfig(null);
        _ = w.DeleteFileW(config_w.ptr);
        _ = w.DeleteFileW(next_w.ptr);
        return;
    }
    console.setSshConfig(config);
}

fn sameAddresses(a: std.mem.Allocator, exe: []const u8, config: []const u8, snapshot: *const servers.Table) bool {
    for (snapshot, aliases) |slot, alias| {
        if (!servers.listed(slot)) continue;
        const command = std.fmt.allocPrint(a, "\"{s}\" -F \"{s}\" -G {s}", .{ exe, config, alias }) catch return false;
        const output = run(a, command, 5000) catch return false;
        if (!output.ok) return false;
        const resolved = hosts.parseSshConfig(output.text) orelse return false;
        if (!std.ascii.eqlIgnoreCase(resolved.hostname, slot.hostname.get())) return false;
    }
    return true;
}

fn seed(a: std.mem.Allocator, prefix: []const u8) void {
    for (aliases, 0..) |alias, i| {
        acquire();
        const empty = table[i].status == .empty;
        lock.unlock();
        if (!empty) continue;
        const command = std.fmt.allocPrint(a, "{s}-G {s}", .{ prefix, alias }) catch continue;
        const output = run(a, command, 5000) catch continue;
        if (!output.ok) continue;
        const resolved = hosts.parseSshConfig(output.text) orelse continue;
        if (hosts.shouldImport(alias, resolved)) continue;
        acquire();
        defer lock.unlock();
        if (table[i].status != .empty) continue;
        var slot: servers.Slot = .{ .status = .needs_setup, .port = resolved.port };
        slot.hostname.set(resolved.hostname);
        slot.user.set(resolved.user);
        var name: [16]u8 = undefined;
        slot.name.set(std.fmt.bufPrint(&name, "Server {d}", .{i + 1}) catch "Server");
        table[i] = slot;
    }
}

fn finish(i: usize, ok: bool, reason: []const u8) void {
    acquire();
    defer lock.unlock();
    if (!servers.listed(table[i])) return;
    table[i].status = if (ok) .connected else .failed;
    table[i].tried = nowSeconds();
    table[i].reason.set(if (ok) "" else reason);
}

fn escaped(a: std.mem.Allocator, remote: []const u8) ![]const u8 {
    return std.mem.replaceOwned(u8, a, remote, "\"", "\\\"");
}

fn check(a: std.mem.Allocator, exe: []const u8, i: usize) void {
    acquire();
    const slot = table[i];
    checking = i;
    lock.unlock();
    defer {
        acquire();
        checking = null;
        lock.unlock();
    }
    if (!servers.listed(slot)) return;
    const public_key = ensureKey(a, exe) catch {
        finish(i, false, "could not create the key");
        return;
    };
    const prefix = sshPrefix(a) catch {
        finish(i, false, "ssh is not installed");
        return;
    };
    var hostname = slot.hostname.get();
    var user = slot.user.get();
    var port = slot.port;
    if (!slot.owned) {
        const command = std.fmt.allocPrint(a, "{s}-G {s}", .{ prefix, aliases[i] }) catch return;
        const output = run(a, command, 5000) catch Output{ .ok = false, .text = "" };
        const resolved = hosts.parseSshConfig(output.text) orelse {
            finish(i, false, "address not found");
            return;
        };
        hostname = resolved.hostname;
        user = resolved.user;
        port = resolved.port;
        acquire();
        if (servers.listed(table[i]) and !table[i].owned) {
            table[i].hostname.set(resolved.hostname);
            table[i].user.set(resolved.user);
            table[i].port = resolved.port;
        }
        lock.unlock();
    }
    var key_buf: [520]u8 = undefined;
    const key = keyFile(&key_buf) orelse return;
    const args = servers.proofArgs(a, key, user, hostname, port) catch {
        finish(i, false, "address not found");
        return;
    };
    const proof = std.fmt.allocPrint(a, "\"{s}\" {s}", .{ exe, args }) catch return;
    const existing = run(a, proof, 30000) catch Output{ .ok = false, .text = "" };
    if (existing.ok or slot.owned) {
        finish(i, existing.ok, servers.failureReason(existing.text));
        return;
    }
    const add = keys.addCommand(a, public_key) catch return;
    const remote = escaped(a, add) catch return;
    const install = std.fmt.allocPrint(a, "{s}-o IdentityAgent=none -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10 {s} \"{s}\"", .{ prefix, aliases[i], remote }) catch return;
    const installed = run(a, install, 30000) catch Output{ .ok = false, .text = "" };
    if (!installed.ok) {
        finish(i, false, servers.failureReason(installed.text));
        return;
    }
    const proven = run(a, proof, 30000) catch Output{ .ok = false, .text = "" };
    finish(i, proven.ok, servers.failureReason(proven.text));
}

fn remove(a: std.mem.Allocator, i: usize) void {
    acquire();
    const slot = table[i];
    checking = i;
    lock.unlock();
    defer {
        acquire();
        checking = null;
        lock.unlock();
    }
    var reached = false;
    if (slot.status == .connected) blk: {
        var key_buf: [520]u8 = undefined;
        const key = keyFile(&key_buf) orelse break :blk;
        const public_path = std.fmt.allocPrint(a, "{s}.pub", .{key}) catch break :blk;
        const bytes = files.readFileAllocWin32(public_path, 4096) orelse break :blk;
        defer std.heap.page_allocator.free(bytes);
        const public_key = keys.parsePublicKey(a, bytes) catch break :blk;
        const prefix = sshPrefix(a) catch break :blk;
        const command = keys.removeCommand(a, public_key) catch break :blk;
        const remote = escaped(a, command) catch break :blk;
        const line = std.fmt.allocPrint(a, "{s}-o BatchMode=yes -o ConnectTimeout=10 {s} \"{s}\"", .{ prefix, aliases[i], remote }) catch break :blk;
        const output = run(a, line, 30000) catch break :blk;
        reached = output.ok;
    }
    acquire();
    table[i] = .{ .status = .removed };
    lock.unlock();
    setMessage(if (reached) "Removed. Multibot's key is off that server." else "Removed here. The server was not reachable, so its key stays there.");
}

fn preparePaste(a: std.mem.Allocator, exe: []const u8) bool {
    const public_key = ensureKey(a, exe) catch {
        setMessage("Could not create Multibot's key.");
        return false;
    };
    const line = servers.pasteLine(a, public_key) catch return false;
    acquire();
    defer lock.unlock();
    if (line.len > paste.len) return false;
    @memcpy(paste[0..line.len], line);
    paste_len = line.len;
    return true;
}

fn worker(job: Job) void {
    defer running.store(false, .release);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();
    if (!console.resolveSshPath(false)) {
        setMessage("ssh is not installed on this PC.");
        return;
    }
    var exe_buf: [520]u8 = undefined;
    const exe = console.sshExePath(&exe_buf) orelse return;
    acquire();
    loadLocked();
    lock.unlock();
    switch (job) {
        .startup => {
            const prefix = sshPrefix(a) catch return;
            seed(a, prefix);
            const now = nowSeconds();
            for (0..servers.slot_count) |i| {
                acquire();
                const due = servers.needsMigration(table[i], now);
                lock.unlock();
                if (due) check(a, exe, i);
            }
            publish(a, exe);
            acquire();
            var any = false;
            for (table) |slot| any = any or servers.listed(slot);
            lock.unlock();
            if (any) _ = preparePaste(a, exe);
        },
        .check => |i| {
            check(a, exe, i);
            publish(a, exe);
            acquire();
            const ok = table[i].status == .connected;
            lock.unlock();
            setMessage(if (ok) "Connected. Multibot signs in with its own key." else "Not connected yet. See the reason in the list.");
        },
        .add => {
            _ = preparePaste(a, exe);
            publish(a, exe);
            setMessage("Added. Paste the line below on the server once, then press Test.");
        },
        .remove => |i| {
            remove(a, i);
            publish(a, exe);
        },
        .paste => {
            _ = preparePaste(a, exe);
        },
    }
}

fn launch(job: Job) bool {
    if (running.swap(true, .acq_rel)) {
        setMessage("Still working on the last step. Try again in a moment.");
        return false;
    }
    const thread = std.Thread.spawn(.{}, worker, .{job}) catch {
        running.store(false, .release);
        return false;
    };
    thread.detach();
    return true;
}

pub fn start() void {
    if (started.swap(true, .acq_rel)) return;
    _ = launch(.startup);
}

pub fn checkServer(i: usize) void {
    if (i >= servers.slot_count) return;
    _ = launch(.{ .check = i });
}

pub fn removeServer(i: usize) void {
    if (i >= servers.slot_count) return;
    _ = launch(.{ .remove = i });
}

pub fn loadPaste() void {
    if (running.load(.acquire)) return;
    _ = launch(.paste);
}

pub fn addServer(name: []const u8, address: []const u8, user: []const u8, port: []const u8) bool {
    const draft = servers.parseDraft(address, user, port) orelse {
        setMessage("Check the address, user and port.");
        return false;
    };
    if (running.load(.acquire)) {
        setMessage("Still working on the last step. Try again in a moment.");
        return false;
    }
    acquire();
    loadLocked();
    const free = servers.freeSlot(&table) orelse {
        lock.unlock();
        setMessage("All three server places are in use. Remove one first.");
        return false;
    };
    var slot: servers.Slot = .{ .status = .needs_setup, .owned = true, .port = draft.port };
    slot.hostname.set(draft.hostname);
    slot.user.set(draft.user);
    slot.name.set(if (std.mem.trim(u8, name, " \t").len > 0) std.mem.trim(u8, name, " \t") else draft.hostname);
    table[free] = slot;
    lock.unlock();
    return launch(.{ .add = free });
}
