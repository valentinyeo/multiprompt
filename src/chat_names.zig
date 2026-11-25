const std = @import("std");
const app_state = @import("app_state.zig");
const chat_view = @import("chat_view.zig");
const sidebar = @import("sidebar.zig");
const workspaces = @import("workspaces.zig");

const request_id: u32 = 0x7fff1865;
const host_slots = 3;

pub const Entry = struct { name: []const u8, tmux: []const u8, sid: []const u8, workspace: []const u8 = "", group: []const u8 = "" };

var last_hash: [host_slots]std.atomic.Value(u64) = @splat(std.atomic.Value(u64).init(0));
var in_flight = std.atomic.Value(bool).init(false);

const Host = @import("session_identity.zig").Host;
const Job = struct { host: Host, body: []u8 };

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
    if (!@import("chat_session.zig").chatHostPersistent(job.host, job.body, 4096, &response)) {
        last_hash[job.host.index()].store(0, .release);
    }
}

pub fn publishIfChanged() void {
    if (in_flight.load(.acquire)) return;
    const a = std.heap.page_allocator;
    const entries = a.alloc(Entry, app_state.MAX_SHELLS) catch return;
    defer a.free(entries);
    const names = a.alloc([192]u8, app_state.MAX_SHELLS) catch return;
    defer a.free(names);
    const ws_names = a.alloc([32]u8, app_state.MAX_SHELLS) catch return;
    defer a.free(ws_names);
    const group_names = a.alloc([192]u8, app_state.MAX_SHELLS) catch return;
    defer a.free(group_names);
    var host: u8 = 0;
    while (host < host_slots) : (host += 1) {
        var count: usize = 0;
        var i: u32 = 0;
        while (i < app_state.shell_count and count < entries.len) : (i += 1) {
            const shell = &app_state.shells[i];
            if (shell.tmux_host != host or shell.name_len == 0 or shell.name_len > shell.name.len) continue;
            if (shell.tmux_session_len == 0 or shell.tmux_session_len > shell.tmux_session.len) continue;
            const tmux = shell.tmux_session[0..shell.tmux_session_len];
            if (!chat_view.isLive(tmux)) continue;
            const n = std.unicode.utf16LeToUtf8(&names[count], shell.name[0..shell.name_len]) catch continue;
            const ws_name = workspaces.workspaceDisplayName(shell.workspace, &ws_names[count]);
            const group_name: []const u8 = if (sidebar.findGroupIdx(shell.group_id)) |gi| blk: {
                const group = &app_state.groups[gi];
                if (group.name_len == 0 or group.name_len > group.name.len) break :blk "";
                const glen = std.unicode.utf16LeToUtf8(&group_names[count], group.name[0..group.name_len]) catch 0;
                break :blk group_names[count][0..glen];
            } else "";
            entries[count] = .{ .name = names[count][0..n], .tmux = tmux, .sid = shell.claude_sid[0..shell.claude_sid_len], .workspace = ws_name, .group = group_name };
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
        job.* = .{ .host = Host.fromIndex(host) orelse unreachable, .body = body };
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
        .{ .name = "Multi Bot Opus Lead", .tmux = "live-308b1fc", .sid = "11111111-2222-3333-4444-555555555555", .workspace = "Studio", .group = "Core" },
        .{ .name = "Say \"hi\"", .tmux = "live-abc", .sid = "" },
    };
    const body = payload(std.testing.allocator, 1, &entries) orelse return error.TestUnexpectedResult;
    defer std.testing.allocator.free(body);
    try std.testing.expectEqualStrings("{\"op\":\"chat_names\",\"id\":2147424357,\"host\":1,\"names\":[{\"name\":\"Multi Bot Opus Lead\",\"tmux\":\"live-308b1fc\",\"sid\":\"11111111-2222-3333-4444-555555555555\",\"workspace\":\"Studio\",\"group\":\"Core\"},{\"name\":\"Say \\\"hi\\\"\",\"tmux\":\"live-abc\",\"sid\":\"\",\"workspace\":\"\",\"group\":\"\"}]}", body);
}
