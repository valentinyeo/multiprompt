const std = @import("std");
const w = @import("win32.zig");
const state = @import("app_state.zig");
const a = std.heap.page_allocator;
const MAX_BUFFER = 32 * 1024 * 1024;

pub const Channel = struct {
    host: *Host,
    id: u32,
    watch: bool,
    terminal: bool = false,
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
    stopping: bool = false,
    outgoing: std.ArrayList(Packet) = .empty,
    outgoing_bytes: usize = 0,
    wake: w.HANDLE = null,
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

fn start(host: *Host, index: u8) bool {
    if (host.wake == null) host.wake = w.CreateEventW(null, 0, 0, null);
    if (host.wake == null) return false;
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
    var accepted = false;
    defer {
        if (child_input != null) _ = w.CloseHandle(child_input);
        if (child_output != null) _ = w.CloseHandle(child_output);
        if (!accepted) {
            if (process != null) {
                _ = w.TerminateProcess(process, 0);
                _ = w.CloseHandle(process);
            }
            if (input != null) _ = w.CloseHandle(input);
            if (output != null) _ = w.CloseHandle(output);
        }
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
    if (w.CreateProcessW(null, @ptrCast(&cmd), null, null, 1, 0x08000000, null, null, &si, &pi) == 0) return false;
    _ = w.CloseHandle(pi.hThread);
    process = pi.hProcess;
    if (state.g_tunnel_job == null or w.AssignProcessToJobObject(state.g_tunnel_job, process) == 0) return false;
    const reader = @import("chat_session.zig").chatReaderBundle(a) orelse return false;
    defer a.free(reader);
    const terminal_source = @embedFile("terminal_channel.py");
    const terminal64 = a.alloc(u8, std.base64.standard.Encoder.calcSize(terminal_source.len)) catch return false;
    defer a.free(terminal64);
    _ = std.base64.standard.Encoder.encode(terminal64, terminal_source);
    const broker = std.fmt.allocPrint(a, "TERMINAL_SOURCE = '{s}'\n{s}", .{ terminal64, @embedFile("chat_transport.py") }) catch return false;
    defer a.free(broker);
    for ([_][]const u8{ broker, reader }) |source| {
        const encoded = a.alloc(u8, std.base64.standard.Encoder.calcSize(source.len)) catch return false;
        defer a.free(encoded);
        _ = std.base64.standard.Encoder.encode(encoded, source);
        if (!writeAll(input, encoded) or !writeAll(input, "\n")) return false;
    }
    const deadline = w.GetTickCount64() + 15_000;
    var ready: [15]u8 = undefined;
    var ready_len: usize = 0;
    while (ready_len < ready.len and w.GetTickCount64() < deadline) {
        var available: u32 = 0;
        if (w.PeekNamedPipe(output, null, 0, null, &available, null) == 0) return false;
        if (available == 0) {
            if (w.WaitForSingleObject(process, 0) == 0) return false;
            w.Sleep(5);
            continue;
        }
        var count: u32 = 0;
        if (w.ReadFile(output, ready[ready_len..].ptr, @intCast(ready.len - ready_len), &count, null) == 0 or count == 0) return false;
        ready_len += count;
    }
    if (!std.mem.eql(u8, ready[0..ready_len], "{\"ready\":true}\n")) return false;
    host.process = process;
    host.input = input;
    host.output = output;
    host.running = true;
    const thread = std.Thread.spawn(.{}, receive, .{host}) catch {
        host.running = false;
        host.process = null;
        host.input = null;
        host.output = null;
        return false;
    };
    thread.detach();
    accepted = true;
    return true;
}

pub fn open(index: u8, watch: bool) ?*Channel {
    if (index >= hosts.len or state.g_chat_history_channels_closing.load(.acquire)) return null;
    const host = &hosts[index];
    lock(host);
    defer host.mutex.unlock();
    if (host.channels.items.len >= 128) return null;
    if (!host.running) {
        if (host.stopping or w.GetTickCount64() < host.retry_at) return null;
        if (!start(host, index)) {
            host.retry_at = w.GetTickCount64() + 250;
            return null;
        }
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
    if (!packet(host, .{ .channel = channel.id, .watch = channel.watch, .terminal = channel.terminal, .open = !channel.started, .data = line })) {
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
        if (host.running) _ = w.TerminateProcess(host.process, 0);
        for (host.channels.items) |channel| {
            channel.ended = true;
            notify(channel);
        }
        host.mutex.unlock();
    }
}

pub fn respawn(index: u8) void {
    if (index >= hosts.len or state.g_chat_history_channels_closing.load(.acquire)) return;
    const host = &hosts[index];
    lock(host);
    defer host.mutex.unlock();
    if (host.running) _ = w.TerminateProcess(host.process, 0);
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
