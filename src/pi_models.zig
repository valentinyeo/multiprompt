const std = @import("std");
const app_state = @import("app_state.zig");

pub const MAX_MODELS: usize = 512;
pub const MAX_NAME: usize = 160;
pub const MAX_PROVIDER: usize = 24;
pub const MAX_DETAIL: usize = 24;
pub const REFRESH_MS: u64 = 600_000;

pub const Model = struct {
    name: [MAX_NAME]u8 = std.mem.zeroes([MAX_NAME]u8),
    name_len: u8 = 0,
    provider: [MAX_PROVIDER]u8 = std.mem.zeroes([MAX_PROVIDER]u8),
    provider_len: u8 = 0,
    detail: [MAX_DETAIL]u8 = std.mem.zeroes([MAX_DETAIL]u8),
    detail_len: u8 = 0,

    pub fn nameText(self: Model) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn providerText(self: Model) []const u8 {
        return self.provider[0..self.provider_len];
    }

    pub fn detailText(self: Model) []const u8 {
        return self.detail[0..self.detail_len];
    }
};

pub const Status = enum { idle, loading, ready, failed };

var g_slots: [2][MAX_MODELS]Model = std.mem.zeroes([2][MAX_MODELS]Model);
var g_lens: [2]usize = .{ 0, 0 };
var g_active = std.atomic.Value(usize).init(0);
var g_status = std.atomic.Value(u8).init(@as(u8, @intFromEnum(Status.idle)));
var g_host: u8 = 0xFF;
var g_fetched_ms: u64 = 0;
var g_pending = std.atomic.Value(bool).init(false);
var g_request_id = std.atomic.Value(u32).init(1);

pub fn models() []const Model {
    const active = g_active.load(.acquire);
    return g_slots[active][0..g_lens[active]];
}

pub fn status() Status {
    return @enumFromInt(g_status.load(.acquire));
}

pub fn loadedHost() u8 {
    return g_host;
}

pub fn ready() bool {
    return status() == .ready and models().len > 0;
}

pub fn reset() void {
    g_active.store(0, .release);
    g_lens = .{ 0, 0 };
    g_host = 0xFF;
    g_fetched_ms = 0;
    g_status.store(@intFromEnum(Status.idle), .release);
}

pub fn setModelsForTest(items: []const Model) void {
    const active = g_active.load(.acquire);
    const target = 1 - active;
    const n = @min(items.len, MAX_MODELS);
    for (items[0..n], 0..) |item, i| g_slots[target][i] = item;
    g_lens[target] = n;
    g_status.store(@intFromEnum(Status.ready), .release);
    g_active.store(target, .release);
}

pub fn isPiAgent(agent: u8) bool {
    return agent == 3;
}

pub fn hostForShell(index: u32) ?u8 {
    if (index >= app_state.shell_count) return null;
    const shell = &app_state.shells[index];
    if (!console.isRemoteShellKind(shell.kind)) return null;
    return if (shell.kind == .tmux) shell.tmux_host else if (shell.kind == .vps2) 1 else 0;
}

pub fn requestLine(a: std.mem.Allocator, id: u32, sid: []const u8, provider: []const u8, model: []const u8) ![]u8 {
    return std.json.Stringify.valueAlloc(a, .{ .op = "set_model", .id = id, .provider = "pi", .sid = sid, .provider_name = provider, .model = model }, .{});
}

pub fn replyOk(response: []const u8) bool {
    const parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, response, .{}) catch return false;
    defer parsed.deinit();
    if (parsed.value != .object) return false;
    const reply = parsed.value.object.get("status") orelse return false;
    return reply == .string and std.mem.eql(u8, reply.string, "ok");
}

test "SOFT-2275 host request carries the Pi model and reads only an explicit ok" {
    const a = std.testing.allocator;
    const line = try requestLine(a, 42, "sid-1", "baseten", "baseten/deepseek-ai/DeepSeek-V4-Pro-0813");
    defer a.free(line);
    try std.testing.expect(std.mem.indexOf(u8, line, "\"set_model\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, line, "baseten/deepseek-ai/DeepSeek-V4-Pro-0813") != null);
    try std.testing.expect(replyOk("{\"status\":\"ok\"}"));
    try std.testing.expect(!replyOk("{\"status\":\"refused\"}"));
    try std.testing.expect(!replyOk("nope"));
}

pub fn fillModel(model: *Model, name: []const u8, provider: []const u8, detail: []const u8) void {
    model.* = .{};
    const n = @min(name.len, MAX_NAME);
    @memcpy(model.name[0..n], name[0..n]);
    model.name_len = @intCast(n);
    const p = @min(provider.len, MAX_PROVIDER);
    @memcpy(model.provider[0..p], provider[0..p]);
    model.provider_len = @intCast(p);
    const d = @min(detail.len, MAX_DETAIL);
    @memcpy(model.detail[0..d], detail[0..d]);
    model.detail_len = @intCast(d);
}

fn modelNameFields(line: []const u8, fields: anytype) usize {
    var count: usize = 0;
    var start: usize = 0;
    var i: usize = 0;
    while (i <= line.len) : (i += 1) {
        if (i == line.len or line[i] == '\t') {
            if (count < fields.len) {
                fields[count] = line[start..i];
                count += 1;
            }
            start = i + 1;
        }
    }
    return count;
}

pub fn parseResponse(text: []const u8, out: []Model) usize {
    var count: usize = 0;
    var lines = std.mem.splitScalar(u8, text, '\n');
    var header_seen = false;
    while (lines.next()) |raw| {
        const line = std.mem.trimEnd(u8, raw, "\r");
        if (line.len == 0) continue;
        if (!header_seen) {
            if (!std.mem.startsWith(u8, line, "@mp\t")) continue;
            header_seen = true;
            var header: [6][]const u8 = undefined;
            const header_fields = modelNameFields(line, &header);
            if (header_fields < 6 or !std.mem.eql(u8, header[2], "models") or !std.mem.eql(u8, header[3], "ok")) return 0;
            continue;
        }
        if (std.mem.eql(u8, line, "@@MP_END@@")) break;
        if (line[0] != 'M' or line.len < 2 or line[1] != '\t') continue;
        var fields: [4][]const u8 = undefined;
        const field_count = modelNameFields(line, &fields);
        if (field_count < 2) continue;
        if (fields[1].len == 0 or count >= out.len) continue;
        fillModel(&out[count], fields[1], if (field_count > 2) fields[2] else "", if (field_count > 3) fields[3] else "");
        count += 1;
    }
    return count;
}

pub fn commandText(buf: []u8, model: Model) []const u8 {
    if (model.provider_len == 0) return std.fmt.bufPrint(buf, "/model {s}", .{model.nameText()}) catch "/model";
    return std.fmt.bufPrint(buf, "/model {s}/{s}", .{ model.providerText(), model.nameText() }) catch "/model";
}

test "SOFT-2275 parses Pi's model rows and builds the switch command" {
    var models_buf: [MAX_MODELS]Model = undefined;
    var frame: [512]u8 = undefined;
    const response = "@mp\t7\tmodels\tok\t/home/me\t2\n" ++
        "M\tdeepseek-ai/DeepSeek-V4-Pro-0813\tbaseten\t1.0M\n" ++
        "M\tgpt-5.6-sol\topenai-codex\t272K\n" ++
        "@@MP_END@@\n";
    const count = parseResponse(response, &models_buf);
    try std.testing.expectEqual(@as(usize, 2), count);
    try std.testing.expectEqualStrings("deepseek-ai/DeepSeek-V4-Pro-0813", models_buf[0].nameText());
    try std.testing.expectEqualStrings("baseten", models_buf[0].providerText());
    try std.testing.expectEqualStrings("1.0M", models_buf[0].detailText());
    const command = commandText(&frame, models_buf[1]);
    try std.testing.expectEqualStrings("/model openai-codex/gpt-5.6-sol", command);
    try std.testing.expectEqual(@as(usize, 0), parseResponse("@mp\t7\tmodels\terror\t-\t0\n@@MP_END@@\n", &models_buf));
    try std.testing.expectEqual(@as(usize, 0), parseResponse("not a frame\n", &models_buf));
}

test "SOFT-2275 keeps a bare model name usable and rejects junk rows" {
    var models_buf: [MAX_MODELS]Model = undefined;
    var frame: [128]u8 = undefined;
    var bare: Model = .{};
    fillModel(&bare, "gpt-oss-120b", "", "");
    try std.testing.expectEqualStrings("/model gpt-oss-120b", commandText(&frame, bare));
    const count = parseResponse("@mp\t1\tmodels\tok\t-\t2\nX\tignored\t\t\nM\t\tempty\t\n@@MP_END@@\n", &models_buf);
    try std.testing.expectEqual(@as(usize, 0), count);
}

const vps = @import("vps.zig");
const console = @import("console.zig");
const win32 = @import("win32.zig");
const focus = @import("focus.zig");

pub fn ensure(host: u8) void {
    if (host >= app_state.g_ac_channels.len) return;
    const stale = g_host != host or g_fetched_ms == 0 or win32.GetTickCount64() -% g_fetched_ms >= REFRESH_MS;
    if (!stale or g_pending.load(.acquire)) return;
    if (g_pending.cmpxchgStrong(false, true, .acq_rel, .acquire) != null) return;
    g_status.store(@intFromEnum(Status.loading), .release);
    const thread = std.Thread.spawn(.{}, fetchThread, .{host}) catch {
        g_pending.store(false, .release);
        g_status.store(@intFromEnum(Status.failed), .release);
        return;
    };
    thread.detach();
}

fn fetchThread(host: u8) void {
    defer g_pending.store(false, .release);
    const id = g_request_id.fetchAdd(1, .monotonic);
    var request_buf: [96]u8 = undefined;
    const request = std.fmt.bufPrint(&request_buf, "{d}\tmodels\tpi\t-\t-\t\n", .{id}) catch {
        g_status.store(@intFromEnum(Status.failed), .release);
        return;
    };
    var bytes: [192 * 1024]u8 = undefined;
    var n = vps.fetchAcPersistent(host, request, &bytes) orelse 0;
    if (n == 0) n = fetchOverSsh(host, request, &bytes);
    const active = g_active.load(.acquire);
    const target = 1 - active;
    const count = if (n > 0) parseResponse(bytes[0..n], &g_slots[target]) else 0;
    if (count == 0) {
        g_status.store(@intFromEnum(Status.failed), .release);
        postReady(0);
        return;
    }
    g_lens[target] = count;
    g_host = host;
    g_fetched_ms = win32.GetTickCount64();
    g_status.store(@intFromEnum(Status.ready), .release);
    g_active.store(target, .release);
    postReady(count);
}

fn fetchOverSsh(host: u8, request: []const u8, bytes: []u8) usize {
    var encoded: [512]u8 = undefined;
    const b64 = std.base64.standard.Encoder.encode(&encoded, request);
    var command: [2048]u8 = undefined;
    var pos: usize = 0;
    if (!console.appendSshExe(&command, &pos)) return 0;
    const tail = std.fmt.bufPrint(command[pos..], "-T -o BatchMode=yes -o ConnectTimeout=5 {s} python3 ~/.local/share/zigshell/mp_complete.py --once {s}", .{ console.tmuxSshTarget(host), b64 }) catch return 0;
    return vps.sshOneShotCapture(command[0 .. pos + tail.len], bytes);
}

fn postReady(count: usize) void {
    if (app_state.g_main_hwnd == null) return;
    _ = focus.PostMessageW(app_state.g_main_hwnd, win32.WM_APP_PI_MODELS_READY, 0, @intCast(count));
}
