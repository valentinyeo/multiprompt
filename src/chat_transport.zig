const std = @import("std");
const w = @import("win32.zig");
const state = @import("app_state.zig");
const idle_budget = @import("idle_budget.zig");
const a = std.heap.page_allocator;
const MAX_BUFFER = 32 * 1024 * 1024;

pub const Channel = struct {
    host: *Host,
    id: u32,
    watch: bool,
    terminal: bool = false,
    command: []const u8 = "",
    started: bool = false,
    notify_hwnd: w.HANDLE = null,
    notify_message: u32 = 0,
    user: usize = 0,
    ended: bool = false,
    bytes: std.ArrayList(u8) = .empty,
    offset: usize = 0,
    pending_bytes: usize = 0,
    pending_packets: usize = 0,
};

const Packet = struct { id: u32, bytes: []u8 };

const Host = struct {
    mutex: state.SpinMutex = .{},
    process: w.HANDLE = null,
    input: w.HANDLE = null,
    output: w.HANDLE = null,
    running: bool = false,
    starting: bool = false,
    stopping: bool = false,
    outgoing: std.ArrayList(Packet) = .empty,
    outgoing_bytes: usize = 0,
    wake: w.HANDLE = null,
    ready: w.HANDLE = null,
    progress: w.HANDLE = null,
    retry_at: u64 = 0,
    next_id: u32 = 0,
    channels: std.ArrayList(*Channel) = .empty,
};

var hosts: [3]Host = @splat(.{});

fn lock(host: *Host) void {
    while (!host.mutex.tryLock()) w.Sleep(1);
}

fn writeAll(handle: w.HANDLE, bytes: []const u8) bool {
    var offset: usize = 0;
    while (offset < bytes.len) {
        var written: u32 = 0;
        if (w.WriteFile(handle, bytes[offset..].ptr, @intCast(bytes.len - offset), &written, null) == 0 or written == 0) return false;
        offset += written;
    }
    return true;
}

fn packet(host: *Host, value: anytype) bool {
    const closing = @hasField(@TypeOf(value), "close");
    if (!host.running or host.outgoing.items.len >= 4096 + @as(usize, if (closing) 128 else 0)) return false;
    const json = std.json.Stringify.valueAlloc(a, value, .{}) catch return false;
    defer a.free(json);
    if (json.len + 1 > 2 * 1024 * 1024 or host.outgoing_bytes + json.len + 1 > MAX_BUFFER + @as(usize, if (closing) 8192 else 0)) return false;
    var owner: ?*Channel = null;
    for (host.channels.items) |channel| {
        if (channel.id == value.channel) {
            if (!closing and (channel.pending_packets >= 256 or channel.pending_bytes + json.len + 1 > 2 * 1024 * 1024)) return false;
            owner = channel;
            break;
        }
    }
    const bytes = a.alloc(u8, json.len + 1) catch return false;
    @memcpy(bytes[0..json.len], json);
    bytes[json.len] = '\n';
    host.outgoing.append(a, .{ .id = value.channel, .bytes = bytes }) catch {
        a.free(bytes);
        return false;
    };
    host.outgoing_bytes += bytes.len;
    _ = w.SetEvent(host.wake);
    if (owner) |channel| {
        channel.pending_bytes += bytes.len;
        channel.pending_packets += 1;
    }
    return true;
}

fn transmit(host: *Host) void {
    while (true) {
        lock(host);
        if (!host.running) {
            host.mutex.unlock();
            return;
        }
        if (host.outgoing.items.len == 0) {
            const wake = host.wake;
            host.mutex.unlock();
            _ = w.WaitForSingleObject(wake, std.math.maxInt(u32));
            continue;
        }
        const item = host.outgoing.orderedRemove(0);
        host.outgoing_bytes -= item.bytes.len;
        for (host.channels.items) |channel| {
            if (channel.id == item.id) {
                channel.pending_bytes -= item.bytes.len;
                channel.pending_packets -= 1;
                break;
            }
        }
        const input = host.input;
        const process = host.process;
        host.mutex.unlock();
        const sent = writeAll(input, item.bytes);
        a.free(item.bytes);
        if (!sent) {
            _ = w.TerminateProcess(process, 0);
            return;
        }
    }
}

const Boot = struct {
    host: *Host,
    input: w.HANDLE,
    output: w.HANDLE,
    process: w.HANDLE,
};

fn closeBoot(b: Boot) void {
    _ = w.TerminateProcess(b.process, 0);
    _ = w.CloseHandle(b.process);
    _ = w.CloseHandle(b.input);
    _ = w.CloseHandle(b.output);
}

fn abortBoot(b: Boot) void {
    closeBoot(b);
    lock(b.host);
    b.host.starting = false;
    b.host.retry_at = w.GetTickCount64() + 250;
    b.host.mutex.unlock();
}

fn handshakeWorker(b: Boot) void {
    const deadline = w.GetTickCount64() + 15_000;
    var ready: [15]u8 = undefined;
    var ready_len: usize = 0;
    var ok = false;
    while (ready_len < ready.len and w.GetTickCount64() < deadline) {
        var available: u32 = 0;
        if (w.PeekNamedPipe(b.output, null, 0, null, &available, null) == 0) break;
        if (available == 0) {
            if (w.WaitForSingleObject(b.process, 0) == 0) break;
            w.Sleep(5);
            continue;
        }
        var count: u32 = 0;
        if (w.ReadFile(b.output, ready[ready_len..].ptr, @intCast(ready.len - ready_len), &count, null) == 0 or count == 0) break;
        ready_len += count;
    }
    if (ready_len >= "{\"ready\":true}\n".len and std.mem.eql(u8, ready[0..ready_len], "{\"ready\":true}\n")) ok = true;
    if (!ok or state.g_chat_history_channels_closing.load(.acquire)) {
        abortBoot(b);
        return;
    }
    lock(b.host);
    if (b.host.stopping or !b.host.starting) {
        const abort = Boot{ .host = b.host, .input = b.input, .output = b.output, .process = b.process };
        b.host.starting = false;
        b.host.mutex.unlock();
        closeBoot(abort);
        return;
    }
    b.host.process = b.process;
    b.host.input = b.input;
    b.host.output = b.output;
    b.host.running = true;
    b.host.starting = false;
    const ready_event = b.host.ready;
    b.host.mutex.unlock();
    if (ready_event != null) _ = w.SetEvent(ready_event);
    idle_budget.bump(.thread_spawn);
    const thread = std.Thread.spawn(.{}, receive, .{b.host}) catch {
        lock(b.host);
        if (b.host.process) |process| _ = w.TerminateProcess(process, 0);
        b.host.running = false;
        b.host.process = null;
        b.host.input = null;
        b.host.output = null;
        b.host.retry_at = w.GetTickCount64() + 250;
        b.host.mutex.unlock();
        return;
    };
    thread.detach();
}

fn bootHost(host: *Host, index: u8) bool {
    if (host.wake == null) host.wake = w.CreateEventW(null, 0, 0, null);
    if (host.wake == null) return false;
    if (host.ready == null) host.ready = w.CreateEventW(null, 0, 0, null);
    if (host.ready == null) return false;
    if (host.progress == null) host.progress = w.CreateEventW(null, 1, 0, null);
    if (host.progress == null) return false;
    var cmd: [2048]u16 = undefined;
    var pos: usize = 0;
    const console = @import("console.zig");
    if (!console.appendSshExe(&cmd, &pos) or
        !console.appendWideAscii(&cmd, &pos, "-T -o BatchMode=yes -o ConnectTimeout=5 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 ") or
        !console.appendWideAscii(&cmd, &pos, console.tmuxSshTarget(index)) or
        !console.appendWideAscii(&cmd, &pos, " python3 -u -c 'import base64,sys;exec(base64.b64decode(sys.stdin.buffer.readline()))'")) return false;
    cmd[pos] = 0;
    var sa = w.SECURITY_ATTRIBUTES{ .nLength = @sizeOf(w.SECURITY_ATTRIBUTES), .lpSecurityDescriptor = null, .bInheritHandle = 1 };
    var child_input: w.HANDLE = null;
    var child_output: w.HANDLE = null;
    var input: w.HANDLE = null;
    var output: w.HANDLE = null;
    var process: w.HANDLE = null;
    defer {
        if (child_input != null) _ = w.CloseHandle(child_input);
        if (child_output != null) _ = w.CloseHandle(child_output);
    }
    if (w.CreatePipe(&child_input, &input, &sa, 1 << 20) == 0 or
        w.CreatePipe(&output, &child_output, &sa, 1 << 20) == 0 or
        w.SetHandleInformation(input, state.HANDLE_FLAG_INHERIT, 0) == 0 or
        w.SetHandleInformation(output, state.HANDLE_FLAG_INHERIT, 0) == 0) return false;
    const stderr = w.CreateFileW(std.unicode.utf8ToUtf16LeStringLiteral("NUL"), w.GENERIC_WRITE, w.FILE_SHARE_READ | w.FILE_SHARE_WRITE, &sa, w.OPEN_EXISTING, w.FILE_ATTRIBUTE_NORMAL, null);
    if (stderr == w.INVALID_HANDLE_VALUE_PTR) return false;
    defer _ = w.CloseHandle(stderr);
    var si = std.mem.zeroes(w.STARTUPINFOW);
    si.cb = @sizeOf(w.STARTUPINFOW);
    si.dwFlags = 0x100;
    si.hStdInput = child_input;
    si.hStdOutput = child_output;
    si.hStdError = stderr;
    var pi = std.mem.zeroes(w.PROCESS_INFORMATION);
    idle_budget.bump(.process_spawn);
    if (w.CreateProcessW(null, @ptrCast(&cmd), null, null, 1, console.SSH_HELPER_FLAGS, null, null, &si, &pi) == 0) return false;
    _ = w.CloseHandle(pi.hThread);
    process = pi.hProcess;
    if (state.g_tunnel_job == null or w.AssignProcessToJobObject(state.g_tunnel_job, process) == 0) {
        _ = w.TerminateProcess(process, 0);
        _ = w.CloseHandle(process);
        _ = w.CloseHandle(input);
        _ = w.CloseHandle(output);
        return false;
    }
    const reader = @import("chat_session.zig").chatReaderBundle(a) orelse {
        _ = w.TerminateProcess(process, 0);
        _ = w.CloseHandle(process);
        _ = w.CloseHandle(input);
        _ = w.CloseHandle(output);
        return false;
    };
    defer a.free(reader);
    const terminal_source = @embedFile("terminal_channel.py");
    const terminal64 = a.alloc(u8, std.base64.standard.Encoder.calcSize(terminal_source.len)) catch {
        _ = w.TerminateProcess(process, 0);
        _ = w.CloseHandle(process);
        _ = w.CloseHandle(input);
        _ = w.CloseHandle(output);
        return false;
    };
    defer a.free(terminal64);
    _ = std.base64.standard.Encoder.encode(terminal64, terminal_source);
    const broker = std.fmt.allocPrint(a, "TERMINAL_SOURCE = '{s}'\n{s}", .{ terminal64, @embedFile("chat_transport.py") }) catch {
        _ = w.TerminateProcess(process, 0);
        _ = w.CloseHandle(process);
        _ = w.CloseHandle(input);
        _ = w.CloseHandle(output);
        return false;
    };
    defer a.free(broker);
    for ([_][]const u8{ broker, reader }) |source| {
        const encoded = a.alloc(u8, std.base64.standard.Encoder.calcSize(source.len)) catch {
            _ = w.TerminateProcess(process, 0);
            _ = w.CloseHandle(process);
            _ = w.CloseHandle(input);
            _ = w.CloseHandle(output);
            return false;
        };
        defer a.free(encoded);
        _ = std.base64.standard.Encoder.encode(encoded, source);
        if (!writeAll(input, encoded) or !writeAll(input, "\n")) {
            _ = w.TerminateProcess(process, 0);
            _ = w.CloseHandle(process);
            _ = w.CloseHandle(input);
            _ = w.CloseHandle(output);
            return false;
        }
    }
    host.starting = true;
    const job = Boot{ .host = host, .input = input, .output = output, .process = process };
    const thread = std.Thread.spawn(.{}, handshakeWorker, .{job}) catch {
        host.starting = false;
        _ = w.TerminateProcess(process, 0);
        _ = w.CloseHandle(process);
        _ = w.CloseHandle(input);
        _ = w.CloseHandle(output);
        return false;
    };
    thread.detach();
    return true;
}

pub fn open(index: u8, watch: bool) ?*Channel {
    if (index >= hosts.len or state.g_chat_history_channels_closing.load(.acquire)) return null;
    const host = &hosts[index];
    lock(host);
    defer host.mutex.unlock();
    if (host.channels.items.len >= 128) return null;
    if (!host.running) {
        if (host.stopping or host.starting or w.GetTickCount64() < host.retry_at) return null;
        if (!bootHost(host, index)) {
            host.retry_at = w.GetTickCount64() + 250;
            return null;
        }
        return null;
    }
    if (host.next_id == std.math.maxInt(u32)) return null;
    host.next_id += 1;
    const channel = a.create(Channel) catch return null;
    channel.* = .{ .host = host, .id = host.next_id, .watch = watch };
    host.channels.append(a, channel) catch {
        a.destroy(channel);
        return null;
    };
    return channel;
}

pub fn openCommand(index: u8, command: []const u8) ?*Channel {
    const channel = open(index, false) orelse return null;
    lock(channel.host);
    channel.command = command;
    channel.host.mutex.unlock();
    return channel;
}

pub fn openTerminal(index: u8, hwnd: w.HANDLE, message: u32, user: usize) ?*Channel {
    const channel = open(index, false) orelse return null;
    lock(channel.host);
    channel.terminal = true;
    channel.notify_hwnd = hwnd;
    channel.notify_message = message;
    channel.user = user;
    channel.host.mutex.unlock();
    return channel;
}

fn notify(channel: *const Channel) void {
    if (channel.notify_hwnd != null and channel.notify_message != 0) _ = w.PostMessageW(channel.notify_hwnd, channel.notify_message, channel.user, 0);
}

pub fn write(channel: *Channel, line: []const u8) bool {
    const host = channel.host;
    lock(host);
    defer host.mutex.unlock();
    if (channel.ended or !host.running) return false;
    if (!channel.terminal) idle_budget.bump(.server_fetch);
    const sent = if (channel.command.len > 0 and !channel.started)
        packet(host, .{ .channel = channel.id, .command = channel.command, .data = line })
    else
        packet(host, .{ .channel = channel.id, .watch = channel.watch, .terminal = channel.terminal, .open = !channel.started, .data = line });
    if (!sent) {
        channel.ended = true;
        _ = packet(host, .{ .channel = channel.id, .close = true });
        notify(channel);
        return false;
    }
    channel.started = true;
    return true;
}

pub fn read(channel: *Channel, bytes: []u8, wait: bool) ?usize {
    const host = channel.host;
    while (true) {
        lock(host);
        const available = channel.bytes.items.len - channel.offset;
        if (available > 0) {
            const n = @min(available, bytes.len);
            @memcpy(bytes[0..n], channel.bytes.items[channel.offset..][0..n]);
            channel.offset += n;
            if (channel.offset == channel.bytes.items.len) {
                if (channel.bytes.capacity > 2 * 1024 * 1024) channel.bytes.clearAndFree(a) else channel.bytes.clearRetainingCapacity();
                channel.offset = 0;
            }
            host.mutex.unlock();
            return n;
        }
        const ended = channel.ended or state.g_chat_history_channels_closing.load(.acquire);
        host.mutex.unlock();
        if (ended) return null;
        if (!wait) return 0;
        w.Sleep(5);
    }
}

pub fn readWithin(channel: *Channel, bytes: []u8, timeout_ms: u32) ?usize {
    const host = channel.host;
    const deadline = w.GetTickCount64() + timeout_ms;
    while (true) {
        const n = read(channel, bytes, false) orelse return null;
        if (n > 0) return n;
        const now = w.GetTickCount64();
        if (now >= deadline) return null;
        lock(host);
        const progress = host.progress;
        host.mutex.unlock();
        if (progress == null) return null;
        _ = w.WaitForSingleObject(progress, @intCast(@min(deadline - now, 50)));
        _ = w.ResetEvent(progress);
    }
}

pub fn cancel(channel: *Channel) void {
    const host = channel.host;
    lock(host);
    defer host.mutex.unlock();
    if (!channel.ended and host.running) _ = packet(host, .{ .channel = channel.id, .close = true });
    channel.ended = true;
}

pub fn close(channel: *Channel) void {
    cancel(channel);
    const host = channel.host;
    lock(host);
    defer host.mutex.unlock();
    for (host.channels.items, 0..) |item, i| {
        if (item == channel) {
            _ = host.channels.swapRemove(i);
            break;
        }
    }
    channel.bytes.deinit(a);
    a.destroy(channel);
}

pub fn shutdown() void {
    for (&hosts) |*host| {
        lock(host);
        if ((host.running or host.starting) and host.process != null) _ = w.TerminateProcess(host.process, 0);
        host.starting = false;
        for (host.channels.items) |channel| {
            channel.ended = true;
            notify(channel);
        }
        host.mutex.unlock();
    }
}

pub fn kick(index: u8) void {
    if (open(index, false)) |channel| close(channel);
}

pub fn waitReady(index: u8, timeout_ms: u32) bool {
    if (index >= hosts.len) return false;
    const host = &hosts[index];
    lock(host);
    const already = host.running;
    const ready = host.ready;
    host.mutex.unlock();
    if (already) return true;
    if (ready == null or w.WaitForSingleObject(ready, timeout_ms) != 0) return false;
    lock(host);
    const running = host.running;
    host.mutex.unlock();
    return running;
}

pub fn respawn(index: u8) void {
    if (index >= hosts.len or state.g_chat_history_channels_closing.load(.acquire)) return;
    const host = &hosts[index];
    lock(host);
    defer host.mutex.unlock();
    if ((host.running or host.starting) and host.process != null) _ = w.TerminateProcess(host.process, 0);
    host.starting = false;
}

fn rejectTerminal(channel: *Channel) bool {
    channel.ended = true;
    notify(channel);
    return true;
}

fn dispatch(host: *Host, line: []const u8) bool {
    const Reply = struct { channel: u32, data: ?[]const u8 = null, closed: bool = false };
    const parsed = std.json.parseFromSlice(Reply, a, line, .{}) catch return false;
    defer parsed.deinit();
    lock(host);
    defer host.mutex.unlock();
    for (host.channels.items) |channel| {
        if (channel.id != parsed.value.channel or channel.ended) continue;
        if (parsed.value.closed) {
            channel.ended = true;
            notify(channel);
            return true;
        }
        const encoded = parsed.value.data orelse return false;
        var decoded: ?[]u8 = null;
        defer if (decoded) |bytes| a.free(bytes);
        if (channel.terminal) {
            const size = std.base64.standard.Decoder.calcSizeForSlice(encoded) catch return rejectTerminal(channel);
            const buffer = a.alloc(u8, size) catch return false;
            decoded = buffer;
            std.base64.standard.Decoder.decode(buffer, encoded) catch return rejectTerminal(channel);
        }
        const bytes: []const u8 = if (decoded) |value| value else encoded;
        if (channel.bytes.items.len + bytes.len + 1 > MAX_BUFFER) {
            channel.ended = true;
            _ = packet(host, .{ .channel = channel.id, .close = true });
            notify(channel);
            return true;
        }
        channel.bytes.appendSlice(a, bytes) catch return false;
        if (!channel.terminal) channel.bytes.append(a, '\n') catch return false;
        if (host.progress != null) _ = w.SetEvent(host.progress);
        notify(channel);
        return true;
    }
    return true;
}

fn receive(host: *Host) void {
    var writer: ?std.Thread = null;
    defer {
        lock(host);
        host.running = false;
        host.starting = false;
        host.stopping = true;
        _ = w.SetEvent(host.wake);
        _ = w.TerminateProcess(host.process, 0);
        for (host.channels.items) |channel| {
            channel.ended = true;
            channel.pending_bytes = 0;
            channel.pending_packets = 0;
            notify(channel);
        }
        for (host.outgoing.items) |item| a.free(item.bytes);
        host.outgoing.clearAndFree(a);
        host.outgoing_bytes = 0;
        host.mutex.unlock();
        if (writer) |thread| thread.join();
        lock(host);
        _ = w.CloseHandle(host.process);
        _ = w.CloseHandle(host.input);
        _ = w.CloseHandle(host.output);
        host.process = null;
        host.input = null;
        host.output = null;
        host.stopping = false;
        host.retry_at = w.GetTickCount64() + 250;
        host.mutex.unlock();
    }
    idle_budget.bump(.thread_spawn);
    writer = std.Thread.spawn(.{}, transmit, .{host}) catch return;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(a);
    var chunk: [65536]u8 = undefined;
    while (!state.g_chat_history_channels_closing.load(.acquire)) {
        var n: u32 = 0;
        if (w.ReadFile(host.output, &chunk, chunk.len, &n, null) == 0 or n == 0) return;
        frame.appendSlice(a, chunk[0..n]) catch return;
        while (std.mem.indexOfScalar(u8, frame.items, '\n')) |end| {
            if (!dispatch(host, frame.items[0..end])) return;
            std.mem.copyForwards(u8, frame.items, frame.items[end + 1 ..]);
            frame.items.len -= end + 1;
        }
        if (frame.items.len > 6 * MAX_BUFFER + 1024) return;
    }
}
