const std = @import("std");

pub const ENABLED = true;
pub const READER = "~/.multiprompt-runtime/reader.py";

pub const Provider = enum {
    claude,
    codex,
    pi,
    cursor,
    antigravity,

    pub fn wire(self: Provider) []const u8 {
        return @tagName(self);
    }

    pub fn label(self: Provider) []const u8 {
        return switch (self) {
            .claude => "Claude",
            .codex => "Codex",
            .pi => "Pi",
            .cursor => "Cursor",
            .antigravity => "Antigravity",
        };
    }

    pub fn aiAgent(self: Provider) u8 {
        return switch (self) {
            .claude => 1,
            .codex => 2,
            .pi => 3,
            .cursor => 7,
            .antigravity => 8,
        };
    }
};

pub fn hostedWorkspaceProvider(program: []const u8) ?Provider {
    if (std.mem.startsWith(u8, program, "claude")) return .claude;
    if (std.mem.eql(u8, program, "cursor") or std.mem.eql(u8, program, "agent") or std.mem.startsWith(u8, program, "cursor ")) return .cursor;
    if (std.mem.eql(u8, program, "antigravity") or std.mem.eql(u8, program, "agy") or std.mem.startsWith(u8, program, "antigravity ") or std.mem.startsWith(u8, program, "agy ")) return .antigravity;
    return null;
}

pub fn eligible(program: []const u8) bool {
    return ENABLED and hostedWorkspaceProvider(program) != null;
}

pub fn formatSessionId(out: *[36]u8, random: *const [16]u8) []const u8 {
    const hex = "0123456789abcdef";
    var bytes: [16]u8 = random.*;
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    var index: usize = 0;
    for (bytes, 0..) |byte, i| {
        if (i == 4 or i == 6 or i == 8 or i == 10) {
            out[index] = '-';
            index += 1;
        }
        out[index] = hex[byte >> 4];
        out[index + 1] = hex[byte & 15];
        index += 2;
    }
    return out[0..index];
}

pub fn restoreSyncedSession(shell: anytype, session: []const u8) void {
    if (!@import("chat_view.zig").isLive(session)) return;
    shell.chat_view_on = true;
    if (shell.claude_sid_len != 0 or session.len != 37) return;
    for (session[5..]) |c| if (!std.ascii.isDigit(c) and !(c >= 'a' and c <= 'f')) return;
    var sid: [36]u8 = undefined;
    var index: usize = 0;
    for (session[5..], 0..) |c, i| {
        if (i == 8 or i == 12 or i == 16 or i == 20) {
            sid[index] = '-';
            index += 1;
        }
        sid[index] = c;
        index += 1;
    }
    @memcpy(shell.claude_sid[0..sid.len], &sid);
    shell.claude_sid_len = sid.len;
    shell.ai_agent = 1;
}

pub fn mintSessionId(out: *[36]u8) ?[]const u8 {
    var random: [16]u8 = undefined;
    if (@import("win32.zig").BCryptGenRandom(null, &random, random.len, 0x00000002) < 0) return null;
    return formatSessionId(out, &random);
}

fn safeSessionId(value: []const u8) bool {
    if (value.len != 36) return false;
    for (value, 0..) |c, i| {
        if (i == 8 or i == 13 or i == 18 or i == 23) {
            if (c != '-') return false;
        } else if (!std.ascii.isDigit(c) and !(c >= 'a' and c <= 'f')) return false;
    }
    return true;
}

fn safeName(value: []const u8) bool {
    if (value.len == 0 or value.len > 64) return false;
    for (value) |c| {
        const ok = std.ascii.isAlphanumeric(c) or c == '_' or c == '-' or c == '.' or c == ':';
        if (!ok) return false;
    }
    return true;
}

fn safePath(value: []const u8) bool {
    if (value.len == 0 or value.len > 220) return false;
    for (value) |c| {
        const ok = std.ascii.isAlphanumeric(c) or c == '/' or c == '_' or c == '-' or c == '.' or c == '~';
        if (!ok) return false;
    }
    return true;
}

pub fn launchCommand(out: []u8, session: []const u8, cwd: []const u8, sid: []const u8) ?[]const u8 {
    return launchCommandFor(out, .claude, session, cwd, sid);
}

pub fn launchCommandFor(out: []u8, provider: Provider, session: []const u8, cwd: []const u8, sid: []const u8) ?[]const u8 {
    if (!safeName(session) or !safePath(cwd) or !safeSessionId(sid)) return null;
    const mode = if (provider == .claude) " --permission-mode bypassPermissions" else "";
    const name = provider.wire();
    return std.fmt.bufPrint(out, "python3 {s} host enable {s} {s} --tmux {s} --cwd {s}{s} && python3 {s} host start {s} {s}", .{ READER, name, sid, session, cwd, mode, READER, name, sid }) catch null;
}

pub fn resumeCommandFor(out: []u8, provider: Provider, session: []const u8, sid: []const u8) ?[]const u8 {
    if (!safeName(session) or !safeSessionId(sid)) return null;
    return std.fmt.bufPrint(out, "python3 {s} host start {s} {s} --tmux {s}", .{ READER, provider.wire(), sid, session }) catch null;
}

pub const MoveTarget = enum { terminal, chat };

pub fn moveRequest(out: []u8, target: MoveTarget, identity: @import("session_identity.zig").Session, cwd: []const u8) ?[]const u8 {
    const id = identity.owner;
    const host = identity.host.index();
    const sid = std.mem.sliceTo(&identity.sid, 0);
    const tmux = std.mem.sliceTo(&identity.tmux, 0);
    if (!safeSessionId(sid) or !safeName(tmux) or !safePath(cwd)) return null;
    const op = switch (target) {
        .terminal => "host_terminal",
        .chat => "host_resume",
    };
    return std.fmt.bufPrint(out, "{{\"op\":\"{s}\",\"id\":{d},\"host\":{d},\"provider\":\"claude\",\"sid\":\"{s}\",\"tmux\":\"{s}\",\"cwd\":\"{s}\"}}", .{ op, id, host, sid, tmux, cwd }) catch null;
}

pub fn movedReply(body: []const u8) bool {
    return std.mem.indexOf(u8, body, "\"status\":\"moved\"") != null or std.mem.indexOf(u8, body, "\"status\":\"already\"") != null;
}

fn safeProvider(value: []const u8) bool {
    for ([_][]const u8{ "claude", "codex", "pi", "hax", "cursor", "antigravity" }) |name| {
        if (std.mem.eql(u8, value, name)) return true;
    }
    return false;
}

pub fn restartRequest(out: []u8, identity: @import("session_identity.zig").Session) ?[]const u8 {
    const id = identity.owner;
    const host = identity.host.index();
    const provider = identity.provider();
    const sid = std.mem.sliceTo(&identity.sid, 0);
    const tmux = std.mem.sliceTo(&identity.tmux, 0);
    if (!safeSessionId(sid) or !safeName(tmux) or !safeProvider(provider)) return null;
    return std.fmt.bufPrint(out, "{{\"op\":\"host_restart\",\"id\":{d},\"host\":{d},\"provider\":\"{s}\",\"sid\":\"{s}\",\"tmux\":\"{s}\"}}", .{ id, host, provider, sid, tmux }) catch null;
}

pub fn restartAllRequest(out: []u8, identity: @import("session_identity.zig").Session) ?[]const u8 {
    const id = identity.owner;
    const host = identity.host.index();
    return std.fmt.bufPrint(out, "{{\"op\":\"host_restart\",\"id\":{d},\"host\":{d},\"all\":true}}", .{ id, host }) catch null;
}

pub fn restartedReply(body: []const u8) bool {
    return std.mem.indexOf(u8, body, "\"status\":\"restarted\"") != null;
}

pub fn restartWaitingReply(body: []const u8) bool {
    return std.mem.indexOf(u8, body, "\"status\":\"waiting\"") != null;
}

pub fn restartingReply(body: []const u8) bool {
    return std.mem.indexOf(u8, body, "\"status\":\"restarting\"") != null;
}

pub fn restartRefusedReply(body: []const u8) bool {
    return std.mem.indexOf(u8, body, "\"status\":\"refused\"") != null or std.mem.indexOf(u8, body, "\"status\":\"error\"") != null or std.mem.indexOf(u8, body, "\"status\":\"already\"") != null;
}

pub fn restartAllAnswered(body: []const u8) bool {
    return std.mem.indexOf(u8, body, "\"status\":\"ok\"") != null;
}

pub fn restartAllWaiting(body: []const u8) bool {
    if (std.mem.indexOf(u8, body, "\"waiting\":") == null) return false;
    return std.mem.indexOf(u8, body, "\"waiting\":0") == null;
}

pub fn restartAllNothing(body: []const u8) bool {
    return restartAllAnswered(body) and std.mem.indexOf(u8, body, "\"restarted\":0") != null;
}

test "IGSH-1921 a restart asks the reader for one chat or for every idle chat" {
    var out: [512]u8 = undefined;
    const sid = "ffffffff-ffff-4fff-bfff-ffffffffffff";
    var key = @import("chat_transcript.zig").Identity.init(7, 1, false, sid, "");
    @memcpy(key.tmux[0..8], "live-abc");
    try std.testing.expectEqualStrings("{\"op\":\"host_restart\",\"id\":7,\"host\":1,\"provider\":\"claude\",\"sid\":\"ffffffff-ffff-4fff-bfff-ffffffffffff\",\"tmux\":\"live-abc\"}", restartRequest(&out, key.checked().?) orelse return error.TestUnexpectedResult);
    key.shell_id = 9;
    key.host = 0;
    key.agent = 7;
    try std.testing.expectEqualStrings("{\"op\":\"host_restart\",\"id\":9,\"host\":0,\"provider\":\"cursor\",\"sid\":\"ffffffff-ffff-4fff-bfff-ffffffffffff\",\"tmux\":\"live-abc\"}", restartRequest(&out, key.checked().?) orelse return error.TestUnexpectedResult);
    key.agent = 8;
    try std.testing.expectEqualStrings("{\"op\":\"host_restart\",\"id\":9,\"host\":0,\"provider\":\"antigravity\",\"sid\":\"ffffffff-ffff-4fff-bfff-ffffffffffff\",\"tmux\":\"live-abc\"}", restartRequest(&out, key.checked().?) orelse return error.TestUnexpectedResult);
    try std.testing.expectEqualStrings("{\"op\":\"host_restart\",\"id\":9,\"host\":0,\"all\":true}", restartAllRequest(&out, key.checked().?) orelse return error.TestUnexpectedResult);
    key.sid = @splat(0);
    @memcpy(key.sid[0..5], "short");
    try std.testing.expect(restartRequest(&out, key.checked().?) == null);
    @memcpy(key.sid[0..sid.len], sid);
    @memcpy(key.tmux[0..8], "live-a;b");
    try std.testing.expect(restartRequest(&out, key.checked().?) == null);
}

test "IGSH-1921 a restart counts as done once the reader says the host changed" {
    try std.testing.expect(restartedReply("{\"status\":\"restarted\",\"generation\":109}"));
    try std.testing.expect(!restartedReply("{\"status\":\"waiting\",\"reason\":\"chat_busy\"}"));
    try std.testing.expect(restartWaitingReply("{\"status\":\"waiting\",\"reason\":\"chat_busy\"}"));
    try std.testing.expect(!restartWaitingReply("{\"status\":\"restarting\"}"));
    try std.testing.expect(restartingReply("{\"status\":\"restarting\"}"));
    try std.testing.expect(!restartingReply("{\"status\":\"restarted\"}"));
    try std.testing.expect(restartRefusedReply("{\"status\":\"already\",\"reason\":\"not_hosted\"}"));
    try std.testing.expect(!restartRefusedReply("{\"status\":\"restarted\"}"));
    try std.testing.expect(!restartWaitingReply(""));
    try std.testing.expect(restartAllAnswered("{\"status\":\"ok\",\"restarted\":2,\"waiting\":0}"));
    try std.testing.expect(restartAllWaiting("{\"status\":\"ok\",\"restarted\":1,\"waiting\":1}"));
    try std.testing.expect(!restartAllWaiting("{\"status\":\"ok\",\"restarted\":2,\"waiting\":0}"));
    try std.testing.expect(restartAllNothing("{\"status\":\"ok\",\"restarted\":0,\"waiting\":0}"));
    try std.testing.expect(!restartAllNothing("{\"status\":\"ok\",\"restarted\":1,\"waiting\":0}"));
}

test "IGSH-1653 synced named live chats restore their identity and chat view" {
    const Session = struct {
        claude_sid: [40]u8 = @splat(0),
        claude_sid_len: u32 = 0,
        chat_view_on: bool = false,
        ai_agent: u8 = 0,
    };
    var shell: Session = .{};
    restoreSyncedSession(&shell, "live-0123456789ab8def81230123456789ab");
    try std.testing.expectEqualStrings("01234567-89ab-8def-8123-0123456789ab", shell.claude_sid[0..shell.claude_sid_len]);
    try std.testing.expect(shell.chat_view_on);
    try std.testing.expectEqual(@as(u8, 1), shell.ai_agent);
    shell.chat_view_on = false;
    restoreSyncedSession(&shell, "live-ffffffffffff8fff8fffffffffffffff");
    try std.testing.expect(shell.chat_view_on);
    try std.testing.expectEqualStrings("01234567-89ab-8def-8123-0123456789ab", shell.claude_sid[0..shell.claude_sid_len]);
    for ([_][]const u8{ "live-project-abc123", "live-h0123456789ab8def81230123456789ab", "live-123", "live-0123456789ab8def81230123456789ag", "live-0123456789AB8def81230123456789ab", "live-0123456789ab8def81230123456789ab0" }) |name| {
        var named_shell: Session = .{};
        restoreSyncedSession(&named_shell, name);
        try std.testing.expect(named_shell.chat_view_on);
        try std.testing.expectEqual(@as(u32, 0), named_shell.claude_sid_len);
        try std.testing.expectEqual(@as(u8, 0), named_shell.ai_agent);
    }
    for ([_][]const u8{ "term-0123456789ab8def81230123456789ab", "", "main" }) |name| {
        var untouched: Session = .{};
        restoreSyncedSession(&untouched, name);
        try std.testing.expectEqualDeep(Session{}, untouched);
    }
}

test "IGSH-1266 moving a chat asks the reader for the side it should run on" {
    var out: [512]u8 = undefined;
    const sid = "ffffffff-ffff-4fff-bfff-ffffffffffff";
    var key = @import("chat_transcript.zig").Identity.init(7, 0, false, sid, "");
    @memcpy(key.tmux[0..8], "term-abc");
    try std.testing.expectEqualStrings("{\"op\":\"host_terminal\",\"id\":7,\"host\":0,\"provider\":\"claude\",\"sid\":\"ffffffff-ffff-4fff-bfff-ffffffffffff\",\"tmux\":\"term-abc\",\"cwd\":\"/home/x/proj\"}", moveRequest(&out, .terminal, key.checked().?, "/home/x/proj") orelse return error.TestUnexpectedResult);
    key.shell_id = 9;
    key.host = 1;
    try std.testing.expectEqualStrings("{\"op\":\"host_resume\",\"id\":9,\"host\":1,\"provider\":\"claude\",\"sid\":\"ffffffff-ffff-4fff-bfff-ffffffffffff\",\"tmux\":\"term-abc\",\"cwd\":\"/home/x/proj\"}", moveRequest(&out, .chat, key.checked().?, "/home/x/proj") orelse return error.TestUnexpectedResult);
    try std.testing.expect(moveRequest(&out, .terminal, key.checked().?, "/home/x proj") == null);
    key.sid = @splat(0);
    @memcpy(key.sid[0..5], "short");
    try std.testing.expect(moveRequest(&out, .terminal, key.checked().?, "/home/x/proj") == null);
    @memcpy(key.sid[0..sid.len], sid);
    @memcpy(key.tmux[0..8], "term-a;b");
    try std.testing.expect(moveRequest(&out, .terminal, key.checked().?, "/home/x/proj") == null);
}

test "IGSH-1266 a move counts as done once the chat runs in the place that was asked for" {
    try std.testing.expect(movedReply("{\"id\":7,\"host_terminal\":{\"status\":\"moved\",\"command\":\"claude --resume x\"}}"));
    try std.testing.expect(movedReply("{\"id\":7,\"host_resume\":{\"status\":\"already\",\"reason\":\"not_hosted\"}}"));
    try std.testing.expect(!movedReply("{\"id\":7,\"host_terminal\":{\"status\":\"error\",\"reason\":\"pane_agent_timeout\"}}"));
    try std.testing.expect(!movedReply(""));
}

test "IGSH-1266 session ids are version four uuids" {
    var out: [36]u8 = undefined;
    const random = [_]u8{0xff} ** 16;
    const id = formatSessionId(&out, &random);
    try std.testing.expectEqual(@as(usize, 36), id.len);
    try std.testing.expectEqualStrings("ffffffff-ffff-4fff-bfff-ffffffffffff", id);
    try std.testing.expect(safeSessionId(id));
    try std.testing.expect(!safeSessionId("ffffffff-ffff-4fff-bfff-fffffffffffg"));
    try std.testing.expect(!safeSessionId("short"));
}

test "IGSH-1266 new Claude sessions start on the app owned host" {
    try std.testing.expect(ENABLED);
    try std.testing.expect(eligible("claude"));
    try std.testing.expect(eligible("claude-code"));
    try std.testing.expect(!eligible("codex"));
    try std.testing.expect(!eligible("pi"));
    try std.testing.expect(eligible("cursor"));
    try std.testing.expect(eligible("agent"));
    try std.testing.expect(eligible("antigravity"));
    try std.testing.expect(eligible("agy"));
    try std.testing.expect(!eligible(""));
    try std.testing.expect(!eligible("bash"));
}

test "IGSH-1447 a new Claude tab is a live chat with no shell or terminal Claude under it" {
    var out: [1024]u8 = undefined;
    const command = launchCommand(&out, "live-abc", "~/projects", "ffffffff-ffff-4fff-bfff-ffffffffffff") orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("python3 ~/.multiprompt-runtime/reader.py host enable claude ffffffff-ffff-4fff-bfff-ffffffffffff --tmux live-abc --cwd ~/projects --permission-mode bypassPermissions && python3 ~/.multiprompt-runtime/reader.py host start claude ffffffff-ffff-4fff-bfff-ffffffffffff", command);
    try std.testing.expect(std.mem.indexOf(u8, command, ">/dev/null") == null);
    try std.testing.expect(std.mem.indexOf(u8, command, "handover") == null);
    try std.testing.expect(std.mem.indexOf(u8, command, "send-keys") == null);
    try std.testing.expect(std.mem.indexOf(u8, command, "claude --session-id") == null);
    try std.testing.expect(std.mem.indexOf(u8, command, "\"") == null);
    try std.testing.expect(launchCommand(&out, "live-abc", "~/projects", "bad") == null);
    try std.testing.expect(launchCommand(&out, "live-a;b", "~/projects", "ffffffff-ffff-4fff-bfff-ffffffffffff") == null);
    try std.testing.expect(launchCommand(&out, "live-abc", "~/pro jects", "ffffffff-ffff-4fff-bfff-ffffffffffff") == null);
}

test "IGSH-1546 a Codex or Pi live chat starts on the host with its own provider and no Claude permission flag" {
    var out: [1024]u8 = undefined;
    const sid = "ffffffff-ffff-4fff-bfff-ffffffffffff";
    const codex = launchCommandFor(&out, .codex, "live-abc", "~/projects", sid) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("python3 ~/.multiprompt-runtime/reader.py host enable codex ffffffff-ffff-4fff-bfff-ffffffffffff --tmux live-abc --cwd ~/projects && python3 ~/.multiprompt-runtime/reader.py host start codex ffffffff-ffff-4fff-bfff-ffffffffffff", codex);
    const pi = launchCommandFor(&out, .pi, "live-abc", "~/projects", sid) orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, pi, "host enable pi ffffffff") != null);
    try std.testing.expect(std.mem.indexOf(u8, pi, "host start pi ffffffff") != null);
    try std.testing.expect(std.mem.indexOf(u8, pi, "permission-mode") == null);
    try std.testing.expect(std.mem.indexOf(u8, pi, "send-keys") == null);
    try std.testing.expect(launchCommandFor(&out, .pi, "live-abc", "~/projects", "bad") == null);
    const cursor = launchCommandFor(&out, .cursor, "live-abc", "~/projects", sid) orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, cursor, "host enable cursor ffffffff") != null);
    try std.testing.expect(std.mem.indexOf(u8, cursor, "host start cursor ffffffff") != null);
    try std.testing.expect(std.mem.indexOf(u8, cursor, "permission-mode") == null);
    const antigravity = launchCommandFor(&out, .antigravity, "live-abc", "~/projects", sid) orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, antigravity, "host enable antigravity ffffffff") != null);
    try std.testing.expect(std.mem.indexOf(u8, antigravity, "host start antigravity ffffffff") != null);
    try std.testing.expect(std.mem.indexOf(u8, antigravity, "permission-mode") == null);
    try std.testing.expect(std.mem.indexOf(u8, antigravity, ">/dev/null") == null);
    const claude = launchCommandFor(&out, .claude, "live-abc", "~/projects", sid) orelse return error.TestUnexpectedResult;
    var expected: [1024]u8 = undefined;
    try std.testing.expectEqualStrings(launchCommand(&expected, "live-abc", "~/projects", sid) orelse return error.TestUnexpectedResult, claude);
}

test "IGSH-1546 each provider maps to the agent kind its tab shows" {
    try std.testing.expectEqual(@as(u8, 1), Provider.claude.aiAgent());
    try std.testing.expectEqual(@as(u8, 2), Provider.codex.aiAgent());
    try std.testing.expectEqual(@as(u8, 3), Provider.pi.aiAgent());
    try std.testing.expectEqual(@as(u8, 7), Provider.cursor.aiAgent());
    try std.testing.expectEqual(@as(u8, 8), Provider.antigravity.aiAgent());
    try std.testing.expectEqualStrings("Codex", Provider.codex.label());
    try std.testing.expectEqualStrings("Antigravity", Provider.antigravity.label());
    try std.testing.expectEqualStrings("pi", Provider.pi.wire());
    try std.testing.expectEqualStrings("cursor", Provider.cursor.wire());
    try std.testing.expectEqualStrings("antigravity", Provider.antigravity.wire());
}

test "IGSH-1666 hosted resumes retain provider and host identity" {
    var out: [1024]u8 = undefined;
    const sid = "ffffffff-ffff-4fff-bfff-ffffffffffff";
    const codex = resumeCommandFor(&out, .codex, "live-codex", sid) orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, codex, "host start codex ffffffff-ffff-4fff-bfff-ffffffffffff --tmux live-codex") != null);
    try std.testing.expect(std.mem.indexOf(u8, codex, "host enable") == null);
    const pi = resumeCommandFor(&out, .pi, "live-pi", sid) orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, pi, "host start pi ffffffff-ffff-4fff-bfff-ffffffffffff --tmux live-pi") != null);
    try std.testing.expect(resumeCommandFor(&out, .codex, "live-codex", "bad") == null);
}
