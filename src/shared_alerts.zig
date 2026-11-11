const std = @import("std");
const w = @import("win32.zig");
const state = @import("app_state.zig");
const transport = @import("chat_transport.zig");
const diagnostics = @import("diagnostics.zig");
const htons = @import("notifications.zig").htons;
const crash_recorder = @import("crash_recorder.zig");
const slots = @import("alert_slots.zig");

const a = std.heap.page_allocator;
const HOSTS = slots.hosts;
const MAX_REPLY = 20 * 1024 * 1024;
const MAX_FRAME = 1024 * 1024;
const MAX_REQUEST = 65536;
const CHUNK = 256 * 1024;
const RECV_TIMEOUT_MS: u32 = 600_000;
const COMMAND_CAP = 16 * 1024;
const COMMAND_HEAD = "python3 -u -c 'import base64,sys;exec(base64.b64decode(\"";
const COMMAND_TAIL = "\"))' ";
const PUMP_SOURCE = @embedFile("notify_link.py");

comptime {
    const encoded = std.base64.standard.Encoder.calcSize(PUMP_SOURCE.len);
    if (COMMAND_HEAD.len + encoded + COMMAND_TAIL.len + 96 > COMMAND_CAP) @compileError("notify_link.py no longer fits one ssh channel command");
}

const Frame = struct {
    kind: u8,
    id: u32,
    payload: []const u8,
};

var g_started: [HOSTS]bool = @splat(false);
var g_started_mutex: state.SpinMutex = .{};
var g_stop: std.atomic.Value(bool) = .init(false);
var g_table: slots.Table = undefined;
var g_table_ready = false;
var g_slot_mutex: state.SpinMutex = .{};

fn lockTable() void {
    while (!g_slot_mutex.tryLock()) w.Sleep(1);
    if (!g_table_ready) {
        g_table = slots.Table.empty();
        g_table_ready = true;
    }
}
var g_command: [COMMAND_CAP]u8 = undefined;
var g_command_len: usize = 0;
var g_name: [96]u8 = undefined;
var g_name_len: usize = 0;

pub fn retryMs(failures: u8) u64 {
    return switch (failures) {
        0 => 5_000,
        1 => 15_000,
        2 => 60_000,
        else => 300_000,
    };
}

pub fn parseFrame(line: []const u8) ?Frame {
    if (line.len < 3 or line[1] != ' ') return null;
    if (line[0] == 'x') {
        const id = std.fmt.parseInt(u32, std.mem.trim(u8, line[2..], " \t\r\n"), 10) catch return null;
        return .{ .kind = 'x', .id = id, .payload = "" };
    }
    if (line[0] != 'a') return null;
    const space = std.mem.indexOfScalar(u8, line[2..], ' ') orelse return null;
    const id = std.fmt.parseInt(u32, line[2..][0..space], 10) catch return null;
    return .{ .kind = 'a', .id = id, .payload = line[2..][space + 1 ..] };
}

test "notify frames split the id from the base64 body" {
    const frame = parseFrame("a 12 aGVsbG8=") orelse unreachable;
    try std.testing.expectEqual(@as(u8, 'a'), frame.kind);
    try std.testing.expectEqual(@as(u32, 12), frame.id);
    try std.testing.expectEqualStrings("aGVsbG8=", frame.payload);
    const close = parseFrame("x 12") orelse unreachable;
    try std.testing.expectEqual(@as(u8, 'x'), close.kind);
    try std.testing.expectEqual(@as(u32, 12), close.id);
    try std.testing.expect(parseFrame("rdy tcp") == null);
    try std.testing.expect(parseFrame("a 12") == null);
    try std.testing.expect(parseFrame("a x12 aGk=") == null);
    try std.testing.expect(parseFrame("") == null);
}

test "alert link backs off and resets the same way as the tunnel keeper" {
    try std.testing.expectEqual(@as(u64, 5000), retryMs(0));
    try std.testing.expectEqual(@as(u64, 15_000), retryMs(1));
    try std.testing.expectEqual(@as(u64, 60_000), retryMs(2));
    try std.testing.expectEqual(@as(u64, 300_000), retryMs(9));
}

fn buildCommand() void {
    const encoded_len = std.base64.standard.Encoder.calcSize(PUMP_SOURCE.len);
    var pos: usize = 0;
    @memcpy(g_command[pos..][0..COMMAND_HEAD.len], COMMAND_HEAD);
    pos += COMMAND_HEAD.len;
    _ = std.base64.standard.Encoder.encode(g_command[pos..][0..encoded_len], PUMP_SOURCE);
    pos += encoded_len;
    @memcpy(g_command[pos..][0..COMMAND_TAIL.len], COMMAND_TAIL);
    pos += COMMAND_TAIL.len;
    @memcpy(g_command[pos..][0..g_name_len], g_name[0..g_name_len]);
    pos += g_name_len;
    g_command_len = pos;
}

fn pumpCommand() []const u8 {
    return g_command[0..g_command_len];
}

pub fn start(name: []const u8) void {
    if (name.len == 0 or name.len > g_name.len) return;
    if (g_name_len != name.len or !std.mem.eql(u8, g_name[0..g_name_len], name)) {
        @memcpy(g_name[0..name.len], name);
        g_name_len = name.len;
        buildCommand();
    }
    g_stop.store(false, .release);
    for (0..HOSTS) |host| {
        if (!claimHost(@intCast(host))) continue;
        const thread = std.Thread.spawn(.{}, pumpThread, .{@as(u8, @intCast(host))}) catch {
            releaseHost(@intCast(host));
            continue;
        };
        thread.detach();
    }
}

pub fn stop() void {
    g_stop.store(true, .release);
}

fn claimHost(host: usize) bool {
    while (!g_started_mutex.tryLock()) w.Sleep(1);
    defer g_started_mutex.unlock();
    if (g_started[host]) return false;
    g_started[host] = true;
    return true;
}

fn releaseHost(host: usize) void {
    while (!g_started_mutex.tryLock()) w.Sleep(1);
    defer g_started_mutex.unlock();
    g_started[host] = false;
}

fn pumpThread(host: u8) void {
    crash_recorder.guardThread();
    defer releaseHost(host);
    if (g_command_len == 0) return;
    var failures: u8 = 0;
    while (!g_stop.load(.acquire) and state.g_shared_server_connection) {
        if (state.g_tunnel_inbound_port == 0) {
            w.Sleep(100);
            continue;
        }
        const channel = transport.openCommand(host, pumpCommand()) orelse {
            failures +|= 1;
            w.Sleep(@intCast(retryMs(failures)));
            continue;
        };
        if (runChannel(host, channel)) {
            failures = 0;
        } else {
            failures +|= 1;
        }
        transport.close(channel);
        if (!g_stop.load(.acquire)) w.Sleep(@intCast(retryMs(failures)));
    }
}

fn runChannel(host: u8, channel: *transport.Channel) bool {
    const generation = beginChannel(host);
    defer endChannel(host, generation);
    if (generation == 0 or !transport.write(channel, "open")) return false;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(a);
    var chunk: [8192]u8 = undefined;
    while (!g_stop.load(.acquire)) {
        const n = transport.read(channel, &chunk, false) orelse return true;
        if (n > 0) {
            frame.appendSlice(a, chunk[0..n]) catch return false;
            while (std.mem.indexOfScalar(u8, frame.items, '\n')) |end| {
                const keep = handleLine(host, generation, frame.items[0..end]);
                std.mem.copyForwards(u8, frame.items, frame.items[end + 1 ..]);
                frame.items.len -= end + 1;
                if (!keep) return false;
            }
            if (frame.items.len > MAX_FRAME) return false;
        }
        flushSlots(channel, host, generation);
        w.Sleep(20);
    }
    return true;
}

fn handleLine(host: u8, generation: u32, line: []const u8) bool {
    if (std.mem.startsWith(u8, line, "rdy ")) {
        diagnostics.debugLog2("alert-link ready host=", line[4..]);
        return true;
    }
    if (std.mem.startsWith(u8, line, "err ")) {
        diagnostics.debugLog2("alert-link refused host=", line[4..]);
        return false;
    }
    const frame = parseFrame(line) orelse return true;
    if (frame.kind != 'a') return true;
    const size = std.base64.standard.Decoder.calcSizeForSlice(frame.payload) catch return true;
    if (size == 0 or size > MAX_REQUEST) return true;
    const bytes = a.alloc(u8, size) catch return true;
    std.base64.standard.Decoder.decode(bytes, frame.payload) catch {
        a.free(bytes);
        return true;
    };
    if (!claimSlot(host, generation, frame.id)) {
        a.free(bytes);
        return true;
    }
    const thread = std.Thread.spawn(.{}, forwardThread, .{ host, generation, frame.id, bytes }) catch {
        a.free(bytes);
        releaseSlot(host, generation, frame.id);
        return true;
    };
    thread.detach();
    return true;
}

fn beginChannel(host: u8) u32 {
    lockTable();
    defer g_slot_mutex.unlock();
    return g_table.begin(a, host);
}

fn endChannel(host: u8, generation: u32) void {
    lockTable();
    defer g_slot_mutex.unlock();
    g_table.end(a, host, generation);
}

fn claimSlot(host: u8, generation: u32, id: u32) bool {
    lockTable();
    defer g_slot_mutex.unlock();
    return g_table.claim(host, generation, id);
}

fn releaseSlot(host: u8, generation: u32, id: u32) void {
    lockTable();
    defer g_slot_mutex.unlock();
    g_table.release(a, host, generation, id);
}

fn finishSlot(host: u8, generation: u32, id: u32, payload: ?[]u8) void {
    lockTable();
    defer g_slot_mutex.unlock();
    g_table.finish(a, host, generation, id, payload);
}

fn takeReady(host: u8, generation: u32) ?slots.Ready {
    lockTable();
    defer g_slot_mutex.unlock();
    return g_table.takeReady(host, generation);
}

fn flushSlots(channel: *transport.Channel, host: u8, generation: u32) void {
    while (takeReady(host, generation)) |ready| {
        if (ready.payload) |bytes| {
            defer a.free(bytes);
            var offset: usize = 0;
            while (offset < bytes.len) {
                const end = @min(offset + CHUNK, bytes.len);
                _ = sendFrame(channel, "a", ready.id, bytes[offset..end]);
                offset = end;
            }
        }
        _ = sendFrame(channel, "x", ready.id, "");
    }
}

fn sendFrame(channel: *transport.Channel, kind: []const u8, id: u32, payload: []const u8) bool {
    var header: [24]u8 = undefined;
    const head = std.fmt.bufPrint(&header, "{s} {d} ", .{ kind, id }) catch return false;
    const encoded_len = std.base64.standard.Encoder.calcSize(payload.len);
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(a);
    buf.appendSlice(a, head) catch return false;
    const offset = buf.items.len;
    buf.resize(a, offset + encoded_len) catch return false;
    _ = std.base64.standard.Encoder.encode(buf.items[offset..], payload);
    return transport.write(channel, buf.items);
}

fn forwardThread(host: u8, generation: u32, id: u32, data: []u8) void {
    crash_recorder.guardThread();
    defer a.free(data);
    const port = state.g_tunnel_inbound_port;
    if (port == 0) {
        finishSlot(host, generation, id, null);
        return;
    }
    finishSlot(host, generation, id, loopback(port, data));
}

fn loopback(port: u16, data: []const u8) ?[]u8 {
    var wsa: w.WSADATA = undefined;
    if (w.WSAStartup(0x0202, &wsa) != 0) return null;
    const client = w.socket(w.AF_INET, w.SOCK_STREAM, 0);
    if (client == w.INVALID_SOCKET) return null;
    defer _ = w.closesocket(client);
    var addr = w.SOCKADDR_IN{
        .sin_family = w.AF_INET,
        .sin_port = htons(port),
        .sin_addr = 0x0100007F,
        .sin_zero = std.mem.zeroes([8]u8),
    };
    if (w.connect(client, &addr, @sizeOf(w.SOCKADDR_IN)) != 0) return null;
    const timeout: u32 = RECV_TIMEOUT_MS;
    _ = w.setsockopt(client, w.SOL_SOCKET, 0x1006, @ptrCast(&timeout), @sizeOf(u32));
    var sent: usize = 0;
    while (sent < data.len) {
        const n = w.send(client, data[sent..].ptr, @intCast(data.len - sent), 0);
        if (n <= 0) return null;
        sent += @intCast(n);
    }
    var reply: std.ArrayList(u8) = .empty;
    defer reply.deinit(a);
    var chunk: [65536]u8 = undefined;
    while (reply.items.len < MAX_REPLY) {
        const want: i32 = @intCast(@min(chunk.len, MAX_REPLY - reply.items.len));
        const n = w.recv(client, &chunk, want, 0);
        if (n <= 0) break;
        reply.appendSlice(a, chunk[0..@intCast(n)]) catch break;
    }
    if (reply.items.len == 0) return null;
    return reply.toOwnedSlice(a) catch null;
}
