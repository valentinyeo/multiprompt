const std = @import("std");

pub const Route = enum { send, plan, permissions, model, unavailable };
pub const PermissionMode = enum { manual, acceptEdits, plan, bypassPermissions };

const unsupported = [_][]const u8{
    "add-dir", "artifact-capabilities", "artifact-diagramming", "artifacts", "autofix-pr",
    "background", "branch", "btw", "bug", "cd", "chrome", "copy", "design-login", "diff",
    "exit", "export", "feedback", "fork", "help", "hooks", "ide", "install-github-app",
    "install-slack-app", "keybindings", "login", "logout", "memory", "mobile", "passes",
    "plugin", "powerup", "privacy-settings", "radio", "release-notes", "remote-control",
    "remote-env", "resume", "rewind", "sandbox", "scroll-speed", "skills", "slides", "status",
    "statusline", "stickers", "subtask", "tasks", "teleport", "terminal-setup", "theme", "tui",
    "upgrade", "voice", "web-setup", "workflows",
};

pub fn route(live: bool, text: []const u16) Route {
    if (!live) return .send;
    const trimmed = std.mem.trim(u16, text, &.{ ' ', '\t', '\r', '\n' });
    if (trimmed.len < 2 or trimmed[0] != '/') return .send;
    var end: usize = 1;
    while (end < trimmed.len and trimmed[end] != ' ' and trimmed[end] != '\t' and trimmed[end] != '\r' and trimmed[end] != '\n') : (end += 1) {}
    const command = trimmed[1..end];
    const has_arguments = std.mem.trim(u16, trimmed[end..], &.{ ' ', '\t', '\r', '\n' }).len != 0;
    if (equals(command, "plan")) return if (has_arguments) .unavailable else .plan;
    if (equals(command, "permissions")) return if (has_arguments) .unavailable else .permissions;
    if (equals(command, "model")) return .model;
    for (unsupported) |name| if (equals(command, name)) return .unavailable;
    return .send;
}

pub fn decide(live: bool, text: []const u16, selected_skill: bool, interactive_hint: bool) Route {
    if (selected_skill) return .send;
    const result = route(live, text);
    return if (live and result == .send and interactive_hint) .unavailable else result;
}

fn equals(wide: []const u16, ascii: []const u8) bool {
    if (wide.len != ascii.len) return false;
    for (wide, ascii) |a, b| if (a != b) return false;
    return true;
}

pub fn modeRequest(allocator: std.mem.Allocator, id: u32, provider: []const u8, sid: []const u8, mode: PermissionMode) ![]u8 {
    return std.json.Stringify.valueAlloc(allocator, .{ .op = "set_permission_mode", .id = id, .provider = provider, .sid = sid, .mode = @tagName(mode) }, .{});
}

pub fn modeReplyOk(allocator: std.mem.Allocator, response: []const u8) bool {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, response, .{}) catch return false;
    defer parsed.deinit();
    if (parsed.value != .object) return false;
    const status = parsed.value.object.get("status") orelse return false;
    return status == .string and std.mem.eql(u8, status.string, "ok");
}

test "mode replies require an explicit acknowledgement" {
    const a = std.testing.allocator;
    try std.testing.expect(modeReplyOk(a, "{\"status\":\"ok\"}"));
    try std.testing.expect(!modeReplyOk(a, "{\"status\":\"refused\"}"));
    try std.testing.expect(!modeReplyOk(a, "{\"status\":\"error\"}"));
    try std.testing.expect(!modeReplyOk(a, "{}"));
    try std.testing.expect(!modeReplyOk(a, "invalid"));
}

test "live slash commands route without changing terminal or custom messages" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    try std.testing.expectEqual(Route.plan, route(true, w("/plan ")));
    try std.testing.expectEqual(Route.permissions, route(true, w("/permissions")));
    try std.testing.expectEqual(Route.model, route(true, w("/model")));
    try std.testing.expectEqual(Route.unavailable, route(true, w("/rewind")));
    try std.testing.expectEqual(Route.unavailable, route(true, w("/resume old")));
    try std.testing.expectEqual(Route.send, route(true, w("/planning")));
    try std.testing.expectEqual(Route.send, route(true, w("/custom-skill hello")));
    try std.testing.expectEqual(Route.send, route(false, w("/plan")));
    try std.testing.expectEqual(Route.send, decide(true, w("/plan custom"), true, false));
    try std.testing.expectEqual(Route.send, decide(true, w("/resume custom"), true, true));
    try std.testing.expectEqual(Route.unavailable, decide(true, w("/new-builtin"), false, true));
    try std.testing.expectEqual(Route.send, decide(false, w("/new-builtin"), false, true));
}

test "mode requests serialize identity and supported mode" {
    const a = std.testing.allocator;
    for ([_]PermissionMode{ .manual, .acceptEdits, .plan, .bypassPermissions }) |mode| {
        const request = try modeRequest(a, 42, "claude", "session\"id", mode);
        defer a.free(request);
        const parsed = try std.json.parseFromSlice(std.json.Value, a, request, .{});
        defer parsed.deinit();
        try std.testing.expectEqualStrings("set_permission_mode", parsed.value.object.get("op").?.string);
        try std.testing.expectEqual(@as(i64, 42), parsed.value.object.get("id").?.integer);
        try std.testing.expectEqualStrings("claude", parsed.value.object.get("provider").?.string);
        try std.testing.expectEqualStrings("session\"id", parsed.value.object.get("sid").?.string);
        try std.testing.expectEqualStrings(@tagName(mode), parsed.value.object.get("mode").?.string);
    }
}
