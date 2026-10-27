const std = @import("std");
const md = @import("chat_markdown.zig");
const style = @import("chat_style.zig");
const echo = @import("chat_echo.zig");

pub const Identity = struct {
    shell_id: u32 = 0,
    host: u8 = 0,
    codex: bool = false,
    sid: [40]u8 = @splat(0),
    tmux: [64]u8 = @splat(0),
    cwd: [192]u8 = @splat(0),

    pub fn init(shell_id: u32, host: u8, codex: bool, sid: []const u8, cwd: []const u8) Identity {
        var key = Identity{ .shell_id = shell_id, .host = host, .codex = codex };
        if (sid.len >= key.sid.len or cwd.len >= key.cwd.len) return .{};
        @memcpy(key.sid[0..sid.len], sid);
        @memcpy(key.cwd[0..cwd.len], cwd);
        return key;
    }

    pub fn initTmux(shell_id: u32, host: u8, codex: bool, tmux: []const u8, cwd: []const u8) Identity {
        var key = Identity{ .shell_id = shell_id, .host = host, .codex = codex };
        if (tmux.len >= key.tmux.len or cwd.len >= key.cwd.len) return .{};
        @memcpy(key.tmux[0..tmux.len], tmux);
        @memcpy(key.cwd[0..cwd.len], cwd);
        return key;
    }
};
pub fn matches(a: Identity, b: Identity) bool {
    return std.meta.eql(a, b) and a.shell_id != 0 and (a.sid[0] != 0 or a.tmux[0] != 0);
}

pub const TodoStatus = enum { pending, in_progress, completed };
pub const Todo = struct {
    text: [200]u16 = @splat(0),
    len: usize = 0,
    status: TodoStatus = .pending,
};
pub const QUEUE_MAX: usize = 8;
pub const QUEUE_TEXT: usize = 256;
pub const DRAFT_TEXT: usize = 512;
pub const QueueItem = struct {
    text: [QUEUE_TEXT]u16 = @splat(0),
    len: usize = 0,
    sent: bool = false,
    injected: bool = false,
    sender: [64]u16 = @splat(0),
};
pub const Status = struct {
    queue: [QUEUE_MAX]QueueItem = @splat(.{}),
    queue_len: usize = 0,
    live_known: bool = false,
    draft: [DRAFT_TEXT]u16 = @splat(0),
    draft_len: usize = 0,
    draft_known: bool = false,
    model: [128]u16 = @splat(0),
    model_len: usize = 0,
    percent_left: ?u8 = null,
    todos: [50]Todo = @splat(.{}),
    total: usize = 0,
    done: usize = 0,
    todos_known: bool = false,

    pub fn known(self: *const Status) bool {
        return self.todos_known;
    }

    pub fn label(self: *const Status, out: []u16) usize {
        if (!self.todos_known) return 0;
        var bytes: [80]u8 = undefined;
        const part = std.fmt.bufPrint(&bytes, "{d} of {d} done", .{ self.done, self.total }) catch unreachable;
        return std.unicode.utf8ToUtf16Le(out, part) catch 0;
    }
};

fn statusText(out: []u16, text: []const u8) usize {
    var view = std.unicode.Utf8View.init(text) catch return 0;
    var it = view.iterator();
    var n: usize = 0;
    while (it.nextCodepoint()) |cp| {
        if (n + @as(usize, if (cp > 0xFFFF) 2 else 1) > out.len) break;
        if (cp > 0xFFFF) {
            out[n] = @intCast(0xD800 + ((cp - 0x10000) >> 10));
            n += 1;
            out[n] = @intCast(0xDC00 + ((cp - 0x10000) & 0x3FF));
        } else out[n] = if (cp < 32) ' ' else @intCast(cp);
        n += 1;
    }
    return n;
}

fn keepText(out: []u16, text: []const u8, keep_newlines: bool) usize {
    var view = std.unicode.Utf8View.init(text) catch return 0;
    var it = view.iterator();
    var n: usize = 0;
    while (it.nextCodepoint()) |cp| {
        if (n + @as(usize, if (cp > 0xFFFF) 2 else 1) > out.len) break;
        if (cp > 0xFFFF) {
            out[n] = @intCast(0xD800 + ((cp - 0x10000) >> 10));
            n += 1;
            out[n] = @intCast(0xDC00 + ((cp - 0x10000) & 0x3FF));
        } else out[n] = if (cp == '\n' and keep_newlines) '\n' else if (cp < 32) ' ' else @intCast(cp);
        n += 1;
    }
    return n;
}

fn fillQueue(result: *Status, items: ?[]const std.json.Value, sent: bool) void {
    for (items orelse return) |value| {
        if (result.queue_len >= QUEUE_MAX) return;
        var item = &result.queue[result.queue_len];
        item.* = .{ .sent = sent };
        switch (value) {
            .string => |text| {
                const wide = std.unicode.utf8ToUtf16LeAlloc(std.heap.page_allocator, text) catch continue;
                defer std.heap.page_allocator.free(wide);
                if (injectedEnvelope(wide, true)) |injected| {
                    item.injected = true;
                    const sender_len = injected.decode(injected.sender, item.sender[0 .. item.sender.len - 1], false);
                    for (item.sender[0..sender_len]) |*c| if (c.* < 32) {
                        c.* = ' ';
                    };
                    item.len = injected.decode(injected.body, &item.text, true);
                    for (item.text[0..item.len]) |*c| if (c.* < 32) {
                        c.* = ' ';
                    };
                } else item.len = keepText(&item.text, text, false);
            },
            .object => |object| {
                const text = object.get("text") orelse continue;
                if (text != .string) continue;
                item.len = keepText(&item.text, text.string, false);
                if (object.get("injected")) |flag| {
                    item.injected = flag == .bool and flag.bool;
                }
                if (item.injected) {
                    const sender = object.get("sender");
                    const name = if (sender != null and sender.? == .string and sender.?.string.len > 0) sender.?.string else "another session";
                    _ = keepText(item.sender[0 .. item.sender.len - 1], name, false);
                }
            },
            else => continue,
        }
        result.queue_len += 1;
    }
}

pub fn parseStatus(line: []const u8) ?Parsed {
    if (std.mem.indexOf(u8, line, "\"status\"") == null) return null;
    const WireTodo = struct { text: []const u8 = "", status: []const u8 = "pending" };
    const WireStatus = struct { role: []const u8, model: []const u8 = "", percent_left: ?u8 = null, todos: ?[]const WireTodo = null, queue: ?[]const std.json.Value = null, sent: ?[]const std.json.Value = null, draft: ?[]const u8 = null };
    const parsed = std.json.parseFromSlice(WireStatus, std.heap.page_allocator, line, .{ .ignore_unknown_fields = true }) catch return null;
    defer parsed.deinit();
    const value = parsed.value;
    if (!std.mem.eql(u8, value.role, "status")) return null;
    var result: Status = .{};
    result.model_len = statusText(&result.model, value.model);
    result.percent_left = if (value.percent_left) |left| @min(left, 100) else null;
    if (value.queue != null or value.sent != null) {
        result.live_known = true;
        fillQueue(&result, value.sent, true);
        fillQueue(&result, value.queue, false);
    }
    if (value.draft) |draft| {
        if (draft.len <= DRAFT_TEXT) {
            result.draft_len = keepText(&result.draft, draft, true);
            result.draft_known = true;
        }
    }
    if (value.todos) |todos| {
        result.todos_known = true;
        for (todos[0..@min(todos.len, result.todos.len)]) |todo| {
            var item = &result.todos[result.total];
            item.len = statusText(&item.text, todo.text);
            item.status = std.meta.stringToEnum(TodoStatus, todo.status) orelse .pending;
            result.done += @intFromBool(item.status == .completed);
            result.total += 1;
        }
    }
    return .{ .len = 0, .count = 0, .status = result };
}

pub const Parsed = struct {
    status: Status = .{},
    len: usize,
    count: usize,
    resolved_sid: [40]u8 = @splat(0),
    resolved_sid_len: u32 = 0,
    resolved_codex: bool = false,
    same: bool = false,
    token: [40]u8 = @splat(0),
    token_len: usize = 0,
    full: bool = false,
};

pub const MAX_MESSAGES: usize = 96;

pub const InjectedMessage = struct {
    sender: []const u16,
    body: []const u16,
    xml_encoded: bool = true,

    fn decode(self: InjectedMessage, text: []const u16, out: []u16, strip_tags: bool) usize {
        if (self.xml_encoded) return decodeXml(text, out, strip_tags);
        var n = @min(text.len, out.len);
        if (n > 0 and n < text.len and text[n - 1] >= 0xD800 and text[n - 1] <= 0xDBFF and text[n] >= 0xDC00 and text[n] <= 0xDFFF) n -= 1;
        std.mem.copyForwards(u16, out[0..n], text[0..n]);
        return n;
    }
};
const XML_SPACE = &[_]u16{ ' ', '\t', '\r', '\n' };

fn xmlTagEnd(text: []const u16) ?usize {
    var quote: u16 = 0;
    for (text, 0..) |c, i| {
        if (quote != 0) {
            if (c == quote) quote = 0;
        } else if (c == '"' or c == '\'') {
            quote = c;
        } else if (c == '>') return i;
    }
    return null;
}

pub fn injectedMessage(raw: []const u16) ?InjectedMessage {
    const text = std.mem.trim(u16, raw, XML_SPACE);
    const prefix = std.unicode.utf8ToUtf16LeStringLiteral("[from ");
    if (std.mem.startsWith(u16, text, prefix)) {
        const end = std.mem.indexOfScalar(u16, text, ']') orelse return null;
        if (end <= prefix.len or end - prefix.len > 80 or std.mem.indexOfScalar(u16, text[prefix.len..end], '\n') != null) return null;
        const sender = std.mem.trim(u16, text[prefix.len..end], XML_SPACE);
        const body = std.mem.trim(u16, text[end + 1 ..], XML_SPACE);
        if (sender.len == 0 or body.len == 0) return null;
        return .{ .sender = sender, .body = body, .xml_encoded = false };
    }
    return injectedEnvelope(raw, false);
}

pub fn noteKey(block: md.Block, text: []const u16) u64 {
    if (block.message_id != 0) return block.message_id;
    const sender = std.hash.Wyhash.hash(block.source_offset ^ block.segment, std.mem.sliceAsBytes(std.mem.sliceTo(&block.sender, 0)));
    return std.hash.Wyhash.hash(sender, std.mem.sliceAsBytes(text[block.start..][0..block.len]));
}

pub fn noteLabel(out: []u16, sender: []const u16, recipient: []const u16, body: []const u16) usize {
    var ticket: []const u16 = &.{};
    for (body, 0..) |c, start| {
        if (c < 'A' or c > 'Z' or (start > 0 and wordChar(body[start - 1]))) continue;
        var pos = start + 1;
        while (pos < body.len and pos - start < 8 and ((body[pos] >= 'A' and body[pos] <= 'Z') or std.ascii.isDigit(@intCast(@min(body[pos], 255))))) : (pos += 1) {}
        if (pos - start < 2 or pos >= body.len or body[pos] != '-') continue;
        pos += 1;
        const digits = pos;
        while (pos < body.len and pos - digits < 6 and body[pos] >= '0' and body[pos] <= '9') : (pos += 1) {}
        if (pos == digits or (pos < body.len and wordChar(body[pos]))) continue;
        ticket = body[start..pos];
        break;
    }
    var len: usize = 0;
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    for ([_][]const u16{ sender, if (recipient.len > 0) w(" to ") else &.{}, recipient, if (ticket.len > 0) w(" · ") else &.{}, ticket }) |part| {
        const n = @min(part.len, out.len - len);
        @memcpy(out[len..][0..n], part[0..n]);
        len += n;
    }
    return len;
}

fn wordChar(c: u16) bool {
    return (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or (c >= '0' and c <= '9') or c == '_';
}

fn injectedEnvelope(raw: []const u16, allow_truncated: bool) ?InjectedMessage {
    const text = std.mem.trim(u16, raw, XML_SPACE);
    const cross = std.unicode.utf8ToUtf16LeStringLiteral("<cross-session-message");
    const task = std.unicode.utf8ToUtf16LeStringLiteral("<task-notification");
    const is_task = std.mem.startsWith(u16, text, task);
    const prefix = if (is_task) task else cross;
    if (!std.mem.startsWith(u16, text, prefix) or text.len <= prefix.len) return null;
    if (text[prefix.len] != '>' and std.mem.indexOfScalar(u16, XML_SPACE, text[prefix.len]) == null) return null;
    const end = xmlTagEnd(text) orelse return null;
    const close = if (is_task) std.unicode.utf8ToUtf16LeStringLiteral("</task-notification>") else std.unicode.utf8ToUtf16LeStringLiteral("</cross-session-message>");
    const close_at = std.mem.indexOfPos(u16, text, end + 1, close) orelse if (allow_truncated) text.len else return null;
    if (close_at < text.len and close_at + close.len != text.len) return null;
    var sender: []const u16 = std.unicode.utf8ToUtf16LeStringLiteral("another session");
    var attrs = std.mem.trim(u16, text[prefix.len..end], XML_SPACE);
    while (attrs.len > 0) {
        const name_end = std.mem.indexOfAny(u16, attrs, &.{ '=', ' ', '\t', '\r', '\n' }) orelse return null;
        const name = attrs[0..name_end];
        if (name.len == 0) return null;
        attrs = std.mem.trimStart(u16, attrs[name_end..], XML_SPACE);
        if (attrs.len == 0 or attrs[0] != '=') return null;
        attrs = std.mem.trimStart(u16, attrs[1..], XML_SPACE);
        if (attrs.len == 0 or (attrs[0] != '"' and attrs[0] != '\'')) return null;
        const quote = attrs[0];
        attrs = attrs[1..];
        const value_end = std.mem.indexOfScalar(u16, attrs, quote) orelse return null;
        const value = attrs[0..value_end];
        if (std.mem.eql(u16, name, std.unicode.utf8ToUtf16LeStringLiteral("from-name")) and std.mem.trim(u16, value, XML_SPACE).len > 0) sender = value;
        attrs = attrs[value_end + 1 ..];
        if (attrs.len > 0 and std.mem.indexOfScalar(u16, XML_SPACE, attrs[0]) == null) return null;
        attrs = std.mem.trimStart(u16, attrs, XML_SPACE);
    }
    return .{ .sender = if (is_task) std.unicode.utf8ToUtf16LeStringLiteral("Task") else sender, .body = std.mem.trim(u16, text[end + 1 .. close_at], XML_SPACE) };
}

pub fn decodeXml(text: []const u16, out: []u16, strip_tags: bool) usize {
    var i: usize = 0;
    var n: usize = 0;
    while (i < text.len and n < out.len) {
        if (strip_tags and text[i] == '<' and i + 1 < text.len and
            (std.ascii.isAlphabetic(@intCast(@min(text[i + 1], 255))) or text[i + 1] == '/'))
        {
            if (xmlTagEnd(text[i..])) |end| {
                i += end + 1;
                continue;
            }
        }
        if (text[i] == '&') {
            if (std.mem.indexOfScalar(u16, text[i..@min(text.len, i + 16)], ';')) |end| {
                const entity = text[i + 1 .. i + end];
                var cp: ?u21 = null;
                const names = [_][]const u8{ "amp", "lt", "gt", "quot", "apos" };
                const values = [_]u21{ '&', '<', '>', '"', '\'' };
                for (names, values) |name, value| {
                    if (entity.len == name.len) {
                        var equal = true;
                        for (entity, name) |a, b| if (a != b) {
                            equal = false;
                        };
                        if (equal) cp = value;
                    }
                }
                if (entity.len > 1 and entity[0] == '#') {
                    const hex = entity.len > 2 and entity[1] == 'x';
                    var num: [12]u8 = undefined;
                    const digits = entity[if (hex) @as(usize, 2) else 1..];
                    if (digits.len <= num.len) {
                        for (digits, 0..) |c, j| num[j] = @intCast(@min(c, 255));
                        const value = std.fmt.parseInt(u21, num[0..digits.len], if (hex) 16 else 10) catch 0;
                        if (value > 0 and value <= 0x10FFFF and !(value >= 0xD800 and value <= 0xDFFF)) cp = value;
                    }
                }
                if (cp) |value| {
                    if (value > 0xFFFF) {
                        if (n + 2 > out.len) break;
                        out[n] = @intCast(0xD800 + ((value - 0x10000) >> 10));
                        out[n + 1] = @intCast(0xDC00 + ((value - 0x10000) & 0x3FF));
                        n += 2;
                    } else {
                        out[n] = @intCast(value);
                        n += 1;
                    }
                    i += end + 1;
                    continue;
                }
            }
        }
        if (text[i] >= 0xD800 and text[i] <= 0xDBFF and i + 1 < text.len and text[i + 1] >= 0xDC00 and text[i + 1] <= 0xDFFF) {
            if (n + 2 > out.len) break;
            out[n] = text[i];
            out[n + 1] = text[i + 1];
            i += 2;
            n += 2;
        } else {
            out[n] = text[i];
            i += 1;
            n += 1;
        }
    }
    return n;
}

pub fn messageBlocks(bytes: []const u8, wide: []u16, offset: usize, role: md.Role, out: []md.Block) !struct { len: usize, count: usize } {
    var len = try std.unicode.utf8ToUtf16Le(wide, bytes);
    var actual_role = role;
    var sender: [64]u16 = @splat(0);
    if (role == .user) {
        if (injectedMessage(wide[0..len])) |injected| {
            const sender_len = injected.decode(injected.sender, sender[0 .. sender.len - 1], false);
            for (sender[0..sender_len]) |*c| if (c.* < 32) {
                c.* = ' ';
            };
            len = injected.decode(injected.body, wide, true);
            if (len == 0) {
                wide[0] = ' ';
                len = 1;
            }
            actual_role = .injected;
        }
    }
    const n = md.blocks(wide[0..len], offset, actual_role, out);
    if (n > 0 and actual_role == .injected) out[0].sender = sender;
    return .{ .len = len, .count = n };
}

pub fn parse(wire: []const u8, id: u32, key: Identity, wide: []u16, out: []md.Block) ?Parsed {
    var lines = std.mem.splitScalar(u8, wire, '\n');
    const header = lines.next() orelse return null;
    var fields = std.mem.splitScalar(u8, header, '\t');
    if (!std.mem.eql(u8, fields.next() orelse "", "@mp")) return null;
    if ((std.fmt.parseInt(u32, fields.next() orelse "", 10) catch return null) != id) return null;
    if (!std.mem.eql(u8, fields.next() orelse "", "transcript")) return null;
    const status = fields.next() orelse return null;
    const is_ok = std.mem.eql(u8, status, "ok");
    const is_same = std.mem.eql(u8, status, "same");
    if (!is_ok and !is_same) return null;
    const sid_field = fields.next() orelse return null;
    const expected = std.fmt.parseInt(usize, fields.next() orelse "", 10) catch return null;
    var parsed = Parsed{ .len = 0, .count = 0, .same = is_same };
    if (fields.next()) |token| {
        if (token.len > parsed.token.len) return null;
        if (!std.mem.eql(u8, token, "-")) {
            @memcpy(parsed.token[0..token.len], token);
            parsed.token_len = token.len;
        }
    } else if (key.tmux[0] != 0) return null;
    if (key.tmux[0] != 0) {
        const agent_field = fields.next() orelse return null;
        const tmux_field = fields.next() orelse return null;
        if (!std.mem.eql(u8, tmux_field, std.mem.sliceTo(&key.tmux, 0))) return null;
        if (!std.mem.eql(u8, agent_field, if (key.codex) "codex" else "claude")) return null;
        parsed.resolved_codex = key.codex;
        if (sid_field.len > 0 and !std.mem.eql(u8, sid_field, "-")) {
            if (sid_field.len >= parsed.resolved_sid.len) return null;
            @memcpy(parsed.resolved_sid[0..sid_field.len], sid_field);
            parsed.resolved_sid_len = @intCast(sid_field.len);
        }
    } else if (!std.mem.eql(u8, sid_field, std.mem.sliceTo(&key.sid, 0))) return null;
    if (fields.next() != null) return null;
    if (is_same) {
        if (expected != 0) return null;
        if (!std.mem.eql(u8, lines.next() orelse "", "@@MP_END@@")) return null;
        while (lines.next()) |line| if (line.len != 0) return null;
        return parsed;
    }
    if (expected == 0 or expected > MAX_MESSAGES) return null;
    parsed.full = expected == MAX_MESSAGES;
    if (out.len == 0) return null;
    var bytes: [180000]u8 = undefined;
    var message_blocks: [256]md.Block = undefined;
    var used: usize = 0;
    var count: usize = 0;
    for (0..expected) |_| {
        const line = lines.next() orelse return null;
        var row = std.mem.splitScalar(u8, line, '\t');
        if (!std.mem.eql(u8, row.next() orelse "", "M")) return null;
        const role_text = row.next() orelse return null;
        const role: md.Role = if (std.mem.eql(u8, role_text, "user")) .user else if (std.mem.eql(u8, role_text, "assistant")) .prose else if (std.mem.eql(u8, role_text, "tool")) .tool else continue;
        const stamp = row.next() orelse return null;
        const b64 = row.next() orelse return null;
        if (row.next() != null) return null;
        const size = std.base64.standard.Decoder.calcSizeForSlice(b64) catch return null;
        if (size > bytes.len or size > wide.len - used) return null;
        std.base64.standard.Decoder.decode(bytes[0..size], b64) catch return null;
        const message = messageBlocks(bytes[0..size], wide[used..], used, role, message_blocks[0..@min(out.len, message_blocks.len)]) catch return null;
        const len = message.len;
        const n = message.count;
        if (n == 0) return null;
        const recorded = style.timestamp(stamp);
        message_blocks[0].time = recorded.time;
        message_blocks[0].zone = recorded.zone;
        const stamp_ms = echo.stampMs(stamp);
        for (message_blocks[0..n]) |*mb| mb.stamp_ms = stamp_ms;
        if (count + n > out.len) {
            const drop = count + n - out.len;
            std.mem.copyForwards(md.Block, out[0 .. count - drop], out[drop..count]);
            count -= drop;
        }
        @memcpy(out[count .. count + n], message_blocks[0..n]);
        count += n;
        used += len;
    }
    if (!std.mem.eql(u8, lines.next() orelse "", "@@MP_END@@")) return null;
    while (lines.next()) |line| if (line.len != 0) return null;
    parsed.len = used;
    parsed.count = count;
    return parsed;
}

test "wire decodes roles markdown and timestamp without terminal markers" {
    var text: [256]u16 = undefined;
    var blocks: [16]md.Block = undefined;
    const key = Identity.init(5, 0, false, "sid", "");
    const result = parse("@mp\t5\ttranscript\tok\tsid\t2\nM\tuser\t-\tSGk=\nM\tassistant\t2026-10-03T12:34:00Z\tIyBUaXRsZQoKKipib2xkKio=\n@@MP_END@@\n", 5, key, &text, &blocks).?;
    try std.testing.expectEqual(@as(usize, 3), result.count);
    try std.testing.expectEqual(md.Role.user, blocks[0].role);
    try std.testing.expectEqual(md.Kind.heading, blocks[1].kind);
    try std.testing.expectEqualSlices(u16, &.{ '1', '2', ':', '3', '4' }, &blocks[1].time);
    try std.testing.expect(blocks[1].first and !blocks[2].first);
    try std.testing.expectEqual(@as(i64, 0), blocks[0].stamp_ms);
    try std.testing.expectEqual(echo.stampMs("2026-10-03T12:34:00Z"), blocks[1].stamp_ms);
    try std.testing.expectEqual(blocks[1].stamp_ms, blocks[2].stamp_ms);
    try std.testing.expect(blocks[1].stamp_ms > 0);
}
test "unchanged transcript returns same and carries the observed token" {
    var text: [64]u16 = undefined;
    var blocks: [4]md.Block = undefined;
    const same = parse("@mp\t7\ttranscript\tsame\tabc\t0\t1234.5678\n@@MP_END@@\n", 7, Identity.init(1, 0, false, "abc", ""), &text, &blocks).?;
    try std.testing.expect(same.same);
    try std.testing.expectEqual(@as(usize, 0), same.count);
    try std.testing.expectEqualStrings("1234.5678", same.token[0..same.token_len]);
    try std.testing.expect(parse("@mp\t7\ttranscript\tsame\tabc\t1\t1234.5678\n@@MP_END@@\n", 7, Identity.init(1, 0, false, "abc", ""), &text, &blocks) == null);
}
test "ok transcript exposes the version token as its seventh field" {
    var text: [64]u16 = undefined;
    var blocks: [4]md.Block = undefined;
    const parsed = parse("@mp\t5\ttranscript\tok\tsid\t1\t99.42\nM\tuser\t-\tSGk=\n@@MP_END@@\n", 5, Identity.init(1, 0, false, "sid", ""), &text, &blocks).?;
    try std.testing.expectEqualStrings("99.42", parsed.token[0..parsed.token_len]);
    try std.testing.expect(!parsed.same);
}
test "wrong response identity missing sentinel malformed base64 and unavailable helper fail closed" {
    var text: [256]u16 = undefined;
    var blocks: [16]md.Block = undefined;
    const key = Identity.init(5, 0, false, "sid", "");
    const good = "@mp\t5\ttranscript\tok\tsid\t1\nM\tuser\t-\tSGk=\n@@MP_END@@\n";
    try std.testing.expect(parse(good, 6, key, &text, &blocks) == null);
    try std.testing.expect(parse(good, 5, Identity.init(5, 0, false, "other", ""), &text, &blocks) == null);
    try std.testing.expect(parse(good[0 .. good.len - 12], 5, key, &text, &blocks) == null);
    try std.testing.expect(parse("@mp\t5\ttranscript\tok\tsid\t1\nM\tuser\t-\t!!!\n@@MP_END@@\n", 5, key, &text, &blocks) == null);
    try std.testing.expect(parse("@mp\t0\tping\terror\t-\t0\n@@MP_END@@\n", 5, key, &text, &blocks) == null);
}
test "bounded buffers reject oversize rather than apply partial conversations" {
    var text: [1]u16 = undefined;
    var blocks: [1]md.Block = undefined;
    const key = Identity.init(5, 0, false, "sid", "");
    try std.testing.expect(parse("@mp\t5\ttranscript\tok\tsid\t1\nM\tuser\t-\tSGk=\n@@MP_END@@\n", 5, key, &text, &blocks) == null);
}
test "tmux identity resolves the server sid and agent on first response" {
    var text: [256]u16 = undefined;
    var blocks: [16]md.Block = undefined;
    const key = Identity.initTmux(4, 1, false, "term-18e12a0a", "");
    const wire = "@mp\t9\ttranscript\tok\t19187a1f-db8b-4249-b632-36ef8507aba4\t1\t10.20\tclaude\tterm-18e12a0a\nM\tuser\t-\tSGk=\n@@MP_END@@\n";
    const result = parse(wire, 9, key, &text, &blocks).?;
    try std.testing.expectEqualStrings("19187a1f-db8b-4249-b632-36ef8507aba4", result.resolved_sid[0..result.resolved_sid_len]);
    try std.testing.expectEqual(@as(usize, 1), result.count);
    try std.testing.expect(parse(wire, 9, Identity.initTmux(4, 1, false, "other", ""), &text, &blocks) == null);
    try std.testing.expect(parse(wire, 9, Identity.initTmux(4, 1, true, "term-18e12a0a", ""), &text, &blocks) == null);
    try std.testing.expect(parse("@mp\t9\ttranscript\tok\t-\t0\t-\tclaude\tterm-18e12a0a\n@@MP_END@@\n", 9, key, &text, &blocks) == null);
}
test "tab host agent session and cwd changes invalidate asynchronous identity" {
    const key = Identity{ .shell_id = 8, .host = 1, .sid = .{'a'} ++ @as([39]u8, @splat(0)) };
    try std.testing.expect(matches(key, key));
    const tmux_key = Identity.initTmux(8, 1, false, "term-1", "");
    try std.testing.expect(matches(tmux_key, tmux_key));
    try std.testing.expect(!matches(tmux_key, key));
    var changed = key;
    changed.host = 2;
    try std.testing.expect(!matches(key, changed));
    changed = key;
    changed.sid[0] = 'b';
    try std.testing.expect(!matches(key, changed));
    changed = key;
    changed.codex = true;
    try std.testing.expect(!matches(key, changed));
    changed = key;
    changed.shell_id = 9;
    try std.testing.expect(!matches(key, changed));
    changed = key;
    changed.cwd[0] = '/';
    try std.testing.expect(!matches(key, changed));
    changed = key;
    changed.tmux[0] = 'x';
    try std.testing.expect(!matches(key, changed));
}

test "identity copies recorded lengths instead of stale suffixes after a folder change" {
    const cwd = "/new/old-folder-tail";
    const key = Identity.init(1, 0, false, "sid-old-tail"[0..3], cwd[0..4]);
    try std.testing.expectEqualStrings("sid", std.mem.sliceTo(&key.sid, 0));
    try std.testing.expectEqualStrings("/new", std.mem.sliceTo(&key.cwd, 0));
    const tmux_key = Identity.initTmux(1, 0, false, "term-old-tail"[0..5], cwd[0..4]);
    try std.testing.expectEqualStrings("term-", std.mem.sliceTo(&tmux_key.tmux, 0));
    try std.testing.expectEqualStrings("/new", std.mem.sliceTo(&tmux_key.cwd, 0));
}

test "injected envelopes extract only the named sender and whole body" {
    @setEvalBranchQuota(10000);
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const message = injectedMessage(w(" \n<cross-session-message from=\"uds:/run/user/1000/private.sock\" from-mode='bypass' from-name = \"RUNNER 7\">scope added</cross-session-message>\n ")).?;
    try std.testing.expectEqualSlices(u16, w("RUNNER 7"), message.sender);
    try std.testing.expectEqualSlices(u16, w("scope added"), message.body);
    try std.testing.expectEqualSlices(u16, w("another session"), injectedMessage(w("<cross-session-message from='secret'>hello</cross-session-message>")).?.sender);
    try std.testing.expectEqualSlices(u16, w("another session"), injectedMessage(w("<cross-session-message from-name='  '>hello</cross-session-message>")).?.sender);
    try std.testing.expectEqualSlices(u16, w("Task"), injectedMessage(w("<task-notification from-name='ignored'><summary>done</summary></task-notification>")).?.sender);
}

test "mixed messages mentions siblings and malformed wrappers stay normal" {
    @setEvalBranchQuota(10000);
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    for ([_][]const u16{
        w("Please read <cross-session-message from-name='R'>hi</cross-session-message>"),
        w("<cross-session-message>hi</cross-session-message> and reply"),
        w("<cross-session-message>one</cross-session-message><cross-session-message>two</cross-session-message>"),
        w("<cross-session-message-extra>hi</cross-session-message>"),
        w("<cross-session-message from-name=R>hi</cross-session-message>"),
        w("<cross-session-message from-name='R>hi</cross-session-message>"),
        w("<cross-session-message>missing close"),
        w("Use <task-notification>done</task-notification> as an example"),
    }) |sample| try std.testing.expect(injectedMessage(sample) == null);
}

test "XML entity decoding is single pass and keeps unknown or invalid references" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    var decoded: [256]u16 = undefined;
    const n = decodeXml(w("&lt;x&gt; &amp; &quot;q&quot; &apos;a&apos; &#65; &#x1F680; &amp;lt; &bogus; &#xD800; &#1114112;"), &decoded, true);
    try std.testing.expectEqualSlices(u16, w("<x> & \"q\" 'a' A 🚀 &lt; &bogus; &#xD800; &#1114112;"), decoded[0..n]);
    const task_len = decodeXml(w("<task-id>42</task-id>\n<summary>Build &amp; tests done</summary>"), &decoded, true);
    try std.testing.expectEqualSlices(u16, w("42\nBuild & tests done"), decoded[0..task_len]);
}

test "message blocks classify only user injections and decode sender and body" {
    var text: [512]u16 = undefined;
    var out: [8]md.Block = undefined;
    const xml = "<cross-session-message from-name='RUNNER &amp; 7'>**scope** &lt;ok&gt;</cross-session-message>";
    const message = try messageBlocks(xml, &text, 9, .user, &out);
    try std.testing.expectEqual(@as(usize, 1), message.count);
    try std.testing.expectEqual(md.Role.injected, out[0].role);
    try std.testing.expectEqual(@as(usize, 9), out[0].start);
    try std.testing.expect(out[0].markdown and out[0].first);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("RUNNER & 7"), std.mem.sliceTo(&out[0].sender, 0));
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("**scope** <ok>"), text[0..message.len]);
    const assistant = try messageBlocks(xml, &text, 0, .prose, &out);
    try std.testing.expectEqual(md.Role.prose, out[0].role);
    try std.testing.expectEqual(xml.len, assistant.len);
    _ = try messageBlocks("<task-notification></task-notification>", &text, 0, .user, &out);
    try std.testing.expectEqual(md.Role.injected, out[0].role);
    try std.testing.expectEqual(@as(usize, 1), out[0].len);
}

test "legacy transcript wire applies injection classification and provider time" {
    const a = std.testing.allocator;
    const xml = "<cross-session-message from-name='RUNNER 7'>scope &amp; tests</cross-session-message>";
    const b64 = try a.alloc(u8, std.base64.standard.Encoder.calcSize(xml.len));
    defer a.free(b64);
    _ = std.base64.standard.Encoder.encode(b64, xml);
    const wire = try std.fmt.allocPrint(a, "@mp\t5\ttranscript\tok\tsid\t1\nM\tuser\t2026-10-03T17:32:00Z\t{s}\n@@MP_END@@\n", .{b64});
    defer a.free(wire);
    var text: [256]u16 = undefined;
    var out: [4]md.Block = undefined;
    const parsed = parse(wire, 5, Identity.init(5, 0, false, "sid", ""), &text, &out).?;
    try std.testing.expectEqual(md.Role.injected, out[0].role);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("scope & tests"), text[0..parsed.len]);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("17:32"), &out[0].time);
}

test "ISSUE-263 legacy wire skips unknown roles and renders tools as one block" {
    var text: [128]u16 = undefined;
    var blocks: [4]md.Block = undefined;
    const result = parse("@mp\t5\ttranscript\tok\tsid\t3\nM\tfuture\t-\taWdub3JlZA==\nM\ttool\t-\tUmFuIHRlc3Rz\nM\tassistant\t-\tZG9uZQ==\n@@MP_END@@\n", 5, Identity.init(5, 0, false, "sid", ""), &text, &blocks).?;
    try std.testing.expectEqual(@as(usize, 2), result.count);
    try std.testing.expectEqual(md.Role.tool, blocks[0].role);
    try std.testing.expectEqual(md.Role.prose, blocks[1].role);
}

test "status row parses model context and bounded todos without treating free text as wire fields" {
    const result = (parseStatus("{\"role\":\"status\",\"model\":\"Opus 5.5\",\"percent_left\":62,\"todos\":[{\"text\":\"one\\tline\\nnext\",\"status\":\"completed\"},{\"text\":\"two\",\"status\":\"completed\"},{\"text\":\"three\",\"status\":\"completed\"},{\"text\":\"four\",\"status\":\"in_progress\"},{\"text\":\"five\",\"status\":\"pending\"},{\"text\":\"six\",\"status\":\"pending\"},{\"text\":\"seven\",\"status\":\"pending\"}]}").?).status;
    try std.testing.expectEqual(@as(?u8, 62), result.percent_left);
    try std.testing.expectEqual(@as(usize, 3), result.done);
    try std.testing.expectEqual(@as(usize, 7), result.total);
    try std.testing.expectEqual(TodoStatus.in_progress, result.todos[3].status);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("one line next"), result.todos[0].text[0..result.todos[0].len]);
    var label: [256]u16 = undefined;
    const len = result.label(&label);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("3 of 7 done"), label[0..len]);
}

test "status row label omits missing parts and old responses parse identically" {
    var text: [64]u16 = undefined;
    var blocks: [4]md.Block = undefined;
    const key = Identity.init(5, 0, false, "sid", "");
    const old = parse("@mp\t5\ttranscript\tok\tsid\t1\nM\tuser\t-\tSGk=\n@@MP_END@@\n", 5, key, &text, &blocks).?;
    try std.testing.expect(!old.status.known());
    try std.testing.expectEqual(@as(usize, 1), old.count);
    try std.testing.expectEqualSlices(u16, &.{ 'H', 'i' }, text[0..old.len]);
    const partial = (parseStatus("{\"role\":\"status\",\"model\":\"Opus 5.5\",\"percent_left\":0}").?).status;
    var label: [256]u16 = undefined;
    try std.testing.expect(!partial.known());
    try std.testing.expectEqual(@as(usize, 0), partial.label(&label));
    const empty = (parseStatus("{\"role\":\"status\",\"todos\":[]}").?).status;
    try std.testing.expect(empty.known());
    try std.testing.expectEqual(@as(usize, 0), empty.total);
    try std.testing.expect(parseStatus("{\"role\":\"status\",\"percent_left\":\"bad\"}") == null);
}

test "IGSH-682 status row carries the shell queue sent first and the box draft" {
    const parsed = (parseStatus("{\"role\":\"status\",\"queue\":[\"two\",\"three\\nlines\"],\"sent\":[\"one\"],\"draft\":\"typed\\nhere\"}").?).status;
    try std.testing.expect(parsed.live_known);
    try std.testing.expectEqual(@as(usize, 3), parsed.queue_len);
    try std.testing.expect(parsed.queue[0].sent);
    try std.testing.expect(!parsed.queue[1].sent);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("one"), parsed.queue[0].text[0..parsed.queue[0].len]);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("three lines"), parsed.queue[2].text[0..parsed.queue[2].len]);
    try std.testing.expect(parsed.draft_known);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("typed\nhere"), parsed.draft[0..parsed.draft_len]);
    const plain = (parseStatus("{\"role\":\"status\",\"percent_left\":10}").?).status;
    try std.testing.expect(!plain.live_known);
    try std.testing.expect(!plain.draft_known);
    const empty = (parseStatus("{\"role\":\"status\",\"queue\":[],\"sent\":[],\"draft\":\"\"}").?).status;
    try std.testing.expect(empty.live_known);
    try std.testing.expect(empty.draft_known);
    try std.testing.expectEqual(@as(usize, 0), empty.queue_len);
}

test "IGSH-722 long queued envelopes and clipped old reader strings become incoming notes" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const opening = "<cross-session-message from=\\\"uds:/run/user/1000/cc-socks/92156.sock\\\" hop-chain=\\\"relay\\\" from-name=\\\"RUNNER 5\\\" from-mode=\\\"bypass\\\">";
    const body = "RUNNER 5: 7686 update &amp; <summary>ready</summary> " ++ "x" ** 700;
    const prefix = "{\"role\":\"status\",\"queue\":[\"";
    const suffix = "\"]}";
    for ([_][]const u8{
        prefix ++ opening ++ body ++ "</cross-session-message>" ++ suffix,
        prefix ++ opening ++ body[0..300] ++ suffix,
    }) |line| {
        const status = (parseStatus(line).?).status;
        const item = status.queue[0];
        try std.testing.expectEqual(@as(usize, 1), status.queue_len);
        try std.testing.expect(item.injected);
        try std.testing.expect(!item.sent);
        try std.testing.expectEqualSlices(u16, w("RUNNER 5"), std.mem.sliceTo(&item.sender, 0));
        const text = item.text[0..item.len];
        try std.testing.expect(std.mem.startsWith(u16, text, w("RUNNER 5: 7686 update & ready ")));
        for ([_][]const u16{ w("<cross-session-message"), w("uds:"), w("hop-chain"), w("<summary>"), w("&amp;") }) |hidden| {
            try std.testing.expect(std.mem.indexOf(u16, text, hidden) == null);
        }
    }
}

test "IGSH-722 queue accepts decoded reader notes and legacy task and sender fallback" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const status = (parseStatus("{\"role\":\"status\",\"sent\":[{\"text\":\"done & <ok>\",\"sender\":\"RUNNER & 5\",\"injected\":true}],\"queue\":[\"<task-notification><summary>done &amp; ready</summary></task-notification>\",\"<cross-session-message from='hidden'>hello\",\"mine\"]}").?).status;
    try std.testing.expectEqual(@as(usize, 4), status.queue_len);
    try std.testing.expect(status.queue[0].sent and status.queue[0].injected);
    try std.testing.expectEqualSlices(u16, w("done & <ok>"), status.queue[0].text[0..status.queue[0].len]);
    try std.testing.expectEqualSlices(u16, w("RUNNER & 5"), std.mem.sliceTo(&status.queue[0].sender, 0));
    try std.testing.expect(status.queue[1].injected);
    try std.testing.expectEqualSlices(u16, w("Task"), std.mem.sliceTo(&status.queue[1].sender, 0));
    try std.testing.expectEqualSlices(u16, w("done & ready"), status.queue[1].text[0..status.queue[1].len]);
    try std.testing.expect(status.queue[2].injected);
    try std.testing.expectEqualSlices(u16, w("another session"), std.mem.sliceTo(&status.queue[2].sender, 0));
    try std.testing.expect(!status.queue[3].injected);
    try std.testing.expectEqualSlices(u16, w("mine"), status.queue[3].text[0..status.queue[3].len]);
}

test "status row caps todo arrays and keeps truncated Unicode valid" {
    const a = std.testing.allocator;
    const item = "{\"text\":\"" ++ "😀" ** 201 ++ "\",\"status\":\"completed\"}";
    const wire = "{\"role\":\"status\",\"todos\":[" ++ (item ++ ",") ** 59 ++ item ++ "]}";
    const parsed = parseStatus(wire).?;
    try std.testing.expectEqual(@as(usize, 50), parsed.status.total);
    try std.testing.expectEqual(@as(usize, 50), parsed.status.done);
    for (parsed.status.todos[0..parsed.status.total]) |todo| {
        try std.testing.expectEqual(@as(usize, 200), todo.len);
        const text = try std.unicode.utf16LeToUtf8Alloc(a, todo.text[0..todo.len]);
        defer a.free(text);
        try std.testing.expectEqualStrings("😀" ** 100, text);
    }
}

test "IGSH-1030 bracket session notes match Android without decoding literal entities" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    var text: [512]u16 = undefined;
    var blocks: [8]md.Block = undefined;
    const source = "  [from Hax Runner 10] IGSH-975 scope &amp; tests\nSee https://example.com/run";
    const parsed = try messageBlocks(source, &text, 0, .user, &blocks);
    try std.testing.expectEqual(md.Role.injected, blocks[0].role);
    try std.testing.expectEqualSlices(u16, w("Hax Runner 10"), std.mem.sliceTo(&blocks[0].sender, 0));
    try std.testing.expectEqualSlices(u16, w("IGSH-975 scope &amp; tests\nSee https://example.com/run"), text[0..parsed.len]);
    _ = try messageBlocks(source, &text, 0, .prose, &blocks);
    try std.testing.expectEqual(md.Role.prose, blocks[0].role);
    for ([_][]const u8{ "My own question", "I wrote [from Hax Runner 10] in the middle", "[from Hax Runner 10]", "[from ] empty sender", "[from first\nsecond] body" }) |ordinary| {
        _ = try messageBlocks(ordinary, &text, 0, .user, &blocks);
        try std.testing.expectEqual(md.Role.user, blocks[0].role);
    }
}

test "IGSH-1030 labels match Android and disclosure identity ignores buffer moves" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    var out: [256]u16 = undefined;
    var n = noteLabel(&out, w("Hax Runner 10"), w("Mini Boss CEO"), w("IGSH-975 native journey is now fully green."));
    try std.testing.expectEqualSlices(u16, w("Hax Runner 10 to Mini Boss CEO · IGSH-975"), out[0..n]);
    n = noteLabel(&out, w("Chief Of Staff"), w("Mini Boss CEO"), w("ping"));
    try std.testing.expectEqualSlices(u16, w("Chief Of Staff to Mini Boss CEO"), out[0..n]);
    n = noteLabel(&out, w("Hax Runner 10"), &.{}, w("IGSH-975 done"));
    try std.testing.expectEqualSlices(u16, w("Hax Runner 10 · IGSH-975"), out[0..n]);
    n = noteLabel(&out, w("Task"), &.{}, w("xIGSH-975 not a ticket"));
    try std.testing.expectEqualSlices(u16, w("Task"), out[0..n]);
    var before = md.Block{ .start = 0, .len = 4, .role = .injected, .message_id = 17 };
    var after = before;
    after.start = 2;
    try std.testing.expectEqual(noteKey(before, w("body")), noteKey(after, w("xxbody")));
    before.message_id = 0;
    after.message_id = 0;
    try std.testing.expectEqual(noteKey(before, w("body")), noteKey(after, w("xxbody")));
    after.source_offset = 1;
    try std.testing.expect(noteKey(before, w("body")) != noteKey(after, w("xxbody")));
    try std.testing.expect(!before.note_open);
}
