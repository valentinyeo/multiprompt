const std = @import("std");
const app_state = @import("app_state.zig");
const chat_view = @import("chat_view.zig");

const request_id: u32 = 0x7fff1865;
const host_slots = 3;

pub const Entry = struct { name: []const u8, tmux: []const u8, sid: []const u8 };

var last_hash: [host_slots]std.atomic.Value(u64) = @splat(std.atomic.Value(u64).init(0));
var in_flight = std.atomic.Value(bool).init(false);

const Job = struct { host: u8, body: []u8 };

pub fn payload(a: std.mem.Allocator, host: u8, entries: []const Entry) ?[]u8 {
    return std.json.Stringify.valueAlloc(a, .{ .op = "chat_names", .id = request_id, .host = host, .names = entries }, .{}) catch null;
}

fn publishThread(job: *Job) void {
    const a = std.heap.page_allocator;
    defer {
        a.free(job.body);
        a.destroy(job);
        in_flight.store(false, .release);
    }
    var response: std.ArrayList(u8) = .empty;
    defer response.deinit(a);
    if (!@import("chat_session.zig").chatHistoryPersistent(job.host, request_id, job.body, 4096, &response, null)) {
        last_hash[job.host].store(0, .release);
    }
}

pub fn publishIfChanged() void {
    if (in_flight.load(.acquire)) return;
    const a = std.heap.page_allocator;
    var host: u8 = 0;
    while (host < host_slots) : (host += 1) {
        var entries: [app_state.MAX_SHELLS]Entry = undefined;
        var names: [app_state.MAX_SHELLS][192]u8 = undefined;
        var count: usize = 0;
        var i: u32 = 0;
        while (i < app_state.shell_count and count < entries.len) : (i += 1) {
            const shell = &app_state.shells[i];
            if (shell.tmux_host != host or shell.name_len == 0 or shell.name_len > shell.name.len) continue;
            if (shell.tmux_session_len == 0 or shell.tmux_session_len > shell.tmux_session.len) continue;
            const tmux = shell.tmux_session[0..shell.tmux_session_len];
            if (!chat_view.isLive(tmux)) continue;
            const n = std.unicode.utf16LeToUtf8(&names[count], shell.name[0..shell.name_len]) catch continue;
            entries[count] = .{ .name = names[count][0..n], .tmux = tmux, .sid = shell.claude_sid[0..shell.claude_sid_len] };
            count += 1;
        }
        if (count == 0) continue;
        const body = payload(a, host, entries[0..count]) orelse continue;
        const hash = std.hash.Wyhash.hash(0, body) | 1;
        if (last_hash[host].load(.acquire) == hash) {
            a.free(body);
            continue;
        }
        const job = a.create(Job) catch {
            a.free(body);
            return;
        };
        job.* = .{ .host = host, .body = body };
        last_hash[host].store(hash, .release);
        in_flight.store(true, .release);
        const thread = std.Thread.spawn(.{ .stack_size = 256 * 1024 }, publishThread, .{job}) catch {
            a.free(body);
            a.destroy(job);
            in_flight.store(false, .release);
            last_hash[host].store(0, .release);
            return;
        };
        thread.detach();
        return;
    }
}

test "IGSH-1865 the desktop names its live chats for the server in one request" {
    const entries = [_]Entry{
        .{ .name = "Multi Bot Opus Lead", .tmux = "live-308b1fc", .sid = "11111111-2222-3333-4444-555555555555" },
        .{ .name = "Say \"hi\"", .tmux = "live-abc", .sid = "" },
    };
    const body = payload(std.testing.allocator, 1, &entries) orelse return error.TestUnexpectedResult;
    defer std.testing.allocator.free(body);
    try std.testing.expectEqualStrings("{\"op\":\"chat_names\",\"id\":2147424357,\"host\":1,\"names\":[{\"name\":\"Multi Bot Opus Lead\",\"tmux\":\"live-308b1fc\",\"sid\":\"11111111-2222-3333-4444-555555555555\"},{\"name\":\"Say \\\"hi\\\"\",\"tmux\":\"live-abc\",\"sid\":\"\"}]}", body);
}
