const std = @import("std");
const chat_markdown = @import("chat_markdown.zig");
const chat_options = @import("chat_options.zig");
const chat_permission = @import("chat_permission.zig");

pub const MAX_LIVE: usize = 4;
pub const MAX_ITEMS: usize = 96;
pub const MAX_ID: usize = 96;
pub const MAX_LABEL: usize = 192;
pub const MAX_TEXT: usize = 48 * 1024;
pub const MAX_ANSWER: usize = MAX_LABEL;
pub const MAX_PAGE: usize = 4 * 1024 * 1024;

pub const ItemKind = enum { text, thinking, tool, plan };
pub const ItemStatus = enum { running, ok, failed, interrupted };
pub const State = enum { idle, running };
pub const RequestKind = enum { approval, question, plan };
pub const Decision = enum { accept, accept_for_session, decline, cancel };
pub const PlanAction = enum { implement, feedback };

pub const Item = struct {
    id: [MAX_ID]u8 = @splat(0),
    id_len: usize = 0,
    kind: ItemKind = .text,
    status: ItemStatus = .running,
    done: bool = false,
    key: u64 = 0,
    text: std.ArrayList(u8) = .empty,

    pub fn idSlice(self: *const Item) []const u8 {
        return self.id[0..self.id_len];
    }

    fn setId(self: *Item, id: []const u8) void {
        self.id_len = @min(id.len, self.id.len);
        @memcpy(self.id[0..self.id_len], id[0..self.id_len]);
    }

    fn setText(self: *Item, a: std.mem.Allocator, value: []const u8) !void {
        self.text.clearRetainingCapacity();
        try self.text.appendSlice(a, value[0..@min(value.len, MAX_TEXT)]);
    }
};

pub const Request = struct {
    open: bool = false,
    kind: RequestKind = .approval,
    id: [MAX_ID]u8 = @splat(0),
    id_len: usize = 0,
    title: [MAX_LABEL]u8 = @splat(0),
    title_len: usize = 0,

    pub fn idSlice(self: *const Request) []const u8 {
        return self.id[0..self.id_len];
    }

    pub fn titleSlice(self: *const Request) []const u8 {
        return self.title[0..self.title_len];
    }

    fn openWith(self: *Request, kind: RequestKind, id: []const u8, title: []const u8) void {
        self.* = .{ .open = true, .kind = kind };
        self.id_len = @min(id.len, self.id.len);
        @memcpy(self.id[0..self.id_len], id[0..self.id_len]);
        self.title_len = @min(title.len, self.title.len);
        @memcpy(self.title[0..self.title_len], title[0..self.title_len]);
    }
};

pub const SENT_KEYS: usize = 4;

pub const Live = struct {
    used: bool = false,
    shell_id: u32 = 0,
    host: u8 = 0,
    sid: [48]u8 = @splat(0),
    sid_len: usize = 0,
    after: u64 = 0,
    turn: [MAX_ID]u8 = @splat(0),
    turn_len: usize = 0,
    sent_id: [81]u8 = @splat(0),
    sent_id_len: usize = 0,
    sent_keys: [SENT_KEYS]u64 = @splat(0),
    sent_key_count: usize = 0,
    state: State = .idle,
    ended: ItemStatus = .ok,
    revision: u64 = 0,
    card_dismissed: bool = false,
    held: bool = false,
    reply_in_history: bool = false,
    items: std.ArrayList(Item) = .empty,
    request: Request = .{},
    prompt: chat_options.Prompt = .{},
    answers: [chat_options.MAX_QUESTIONS][MAX_ANSWER]u8 = @splat(@splat(0)),
    answer_lens: [chat_options.MAX_QUESTIONS]usize = @splat(0),

    pub fn sidSlice(self: *const Live) []const u8 {
        return self.sid[0..self.sid_len];
    }

    pub fn clear(self: *Live, a: std.mem.Allocator) void {
        for (self.items.items) |*item| item.text.deinit(a);
        self.items.clearRetainingCapacity();
        self.held = false;
        self.reply_in_history = false;
        self.after = 0;
        self.turn_len = 0;
        self.sent_id_len = 0;
        self.sent_key_count = 0;
        self.state = .idle;
        self.ended = .ok;
        self.request = .{};
        self.prompt = .{};
        self.answer_lens = @splat(0);
        self.card_dismissed = false;
        self.touch();
    }

    pub fn deinit(self: *Live, a: std.mem.Allocator) void {
        for (self.items.items) |*item| item.text.deinit(a);
        self.items.deinit(a);
        self.* = .{};
    }

    pub fn touch(self: *Live) void {
        self.revision +%= 1;
    }

    fn itemFor(self: *Live, a: std.mem.Allocator, id: []const u8, kind: ItemKind) !*Item {
        for (self.items.items) |*existing| {
            if (std.mem.eql(u8, existing.idSlice(), id)) return existing;
        }
        if (self.items.items.len >= MAX_ITEMS) return &self.items.items[self.items.items.len - 1];
        try self.items.append(a, .{ .kind = kind });
        const added = &self.items.items[self.items.items.len - 1];
        added.setId(id);
        added.key = if (id.len == 0) 0 else chat_markdown.rowKey(id);
        return added;
    }
};

fn objectOf(value: std.json.Value) ?std.json.ObjectMap {
    return switch (value) {
        .object => |obj| obj,
        else => null,
    };
}

fn fieldOf(value: std.json.Value, key: []const u8) ?std.json.Value {
    const obj = objectOf(value) orelse return null;
    return obj.get(key);
}

fn strOf(value: std.json.Value, key: []const u8) []const u8 {
    const found = fieldOf(value, key) orelse return "";
    return switch (found) {
        .string => |text| text,
        else => "",
    };
}

fn intOf(value: std.json.Value, key: []const u8) ?u64 {
    const found = fieldOf(value, key) orelse return null;
    return switch (found) {
        .integer => |number| if (number < 0) null else @intCast(number),
        else => null,
    };
}

fn boolOf(value: std.json.Value, key: []const u8) bool {
    const found = fieldOf(value, key) orelse return false;
    return switch (found) {
        .bool => |flag| flag,
        else => false,
    };
}

fn statusOf(name: []const u8) ItemStatus {
    if (std.mem.eql(u8, name, "failed") or std.mem.eql(u8, name, "error")) return .failed;
    if (std.mem.eql(u8, name, "interrupted")) return .interrupted;
    if (std.mem.eql(u8, name, "completed") or std.mem.eql(u8, name, "ok")) return .ok;
    return .running;
}

pub fn applyValue(self: *Live, a: std.mem.Allocator, seq: u64, event: std.json.Value) !bool {
    if (seq <= self.after) return false;
    const kind = strOf(event, "kind");
    const payload = fieldOf(event, "payload") orelse std.json.Value{ .null = {} };
    const item_id = strOf(event, "item");
    const turn = strOf(event, "turn");
    var changed = true;
    if (std.mem.eql(u8, kind, "turn.started")) {
        for (self.items.items) |*item| item.text.deinit(a);
        self.items.clearRetainingCapacity();
        self.held = false;
        self.reply_in_history = false;
        self.state = .running;
        self.turn_len = @min(turn.len, self.turn.len);
        @memcpy(self.turn[0..self.turn_len], turn[0..self.turn_len]);
        self.sent_id_len = 0;
        self.sent_key_count = 0;
        const sent = strOf(payload, "message_id");
        self.sent_id_len = @min(sent.len, self.sent_id.len);
        @memcpy(self.sent_id[0..self.sent_id_len], sent[0..self.sent_id_len]);
        if (fieldOf(payload, "uuids")) |listed| switch (listed) {
            .array => |array| for (array.items) |entry| {
                if (self.sent_key_count >= self.sent_keys.len) break;
                const uuid = switch (entry) {
                    .string => |text| text,
                    else => continue,
                };
                if (uuid.len == 0) continue;
                self.sent_keys[self.sent_key_count] = chat_markdown.rowKey(uuid);
                self.sent_key_count += 1;
            },
            else => {},
        };
    } else if (std.mem.eql(u8, kind, "text.delta") or std.mem.eql(u8, kind, "thinking.delta")) {
        const target = try self.itemFor(a, item_id, if (std.mem.eql(u8, kind, "text.delta")) .text else .thinking);
        try target.setText(a, strOf(payload, "text"));
        self.reply_in_history = false;
    } else if (std.mem.eql(u8, kind, "text.done") or std.mem.eql(u8, kind, "thinking.done")) {
        const target = try self.itemFor(a, item_id, if (std.mem.eql(u8, kind, "text.done")) .text else .thinking);
        try target.setText(a, strOf(payload, "text"));
        target.done = true;
    } else if (std.mem.eql(u8, kind, "item.started")) {
        const target = try self.itemFor(a, item_id, .tool);
        self.reply_in_history = false;
        const line = eventLabel(payload);
        try target.setText(a, if (line.len > 0) line else strOf(payload, "tool"));
        target.done = false;
        target.status = .running;
    } else if (std.mem.eql(u8, kind, "item.done")) {
        const target = try self.itemFor(a, item_id, .tool);
        target.done = true;
        target.status = statusOf(strOf(payload, "status"));
    } else if (std.mem.eql(u8, kind, "approval.request")) {
        self.request.openWith(.approval, strOf(payload, "request_id"), eventLabel(payload));
    } else if (std.mem.eql(u8, kind, "question.request")) {
        self.request.openWith(.question, strOf(payload, "request_id"), strOf(payload, "tool"));
        self.prompt = promptOf(payload);
        self.answer_lens = @splat(0);
    } else if (std.mem.eql(u8, kind, "plan.proposed")) {
        const request_id = strOf(payload, "request_id");
        self.request.openWith(.plan, request_id, strOf(payload, "title"));
        var key_buf: [MAX_ID]u8 = undefined;
        const key = if (item_id.len > 0) item_id else std.fmt.bufPrint(&key_buf, "plan:{s}", .{request_id}) catch request_id;
        const target = try self.itemFor(a, key, .plan);
        try target.setText(a, strOf(payload, "markdown"));
        target.done = true;
    } else if (std.mem.eql(u8, kind, "approval.resolved") or std.mem.eql(u8, kind, "question.resolved") or
        std.mem.eql(u8, kind, "plan.resolved"))
    {
        if (self.request.open and std.mem.eql(u8, self.request.idSlice(), strOf(payload, "request_id"))) {
            self.request.open = false;
            self.card_dismissed = true;
        }
        if (std.mem.eql(u8, kind, "question.resolved")) {
            self.prompt = .{};
            self.answer_lens = @splat(0);
        }
    } else if (std.mem.eql(u8, kind, "turn.ended")) {
        self.held = self.state == .running and !self.reply_in_history;
        self.state = .idle;
        self.ended = statusOf(strOf(payload, "status"));
    } else if (std.mem.eql(u8, kind, "host.status") and std.mem.eql(u8, strOf(payload, "state"), "ready") and self.turn_len == 0 and self.state == .running) {
        self.state = .idle;
    } else if (std.mem.eql(u8, kind, "host.status") and std.mem.eql(u8, strOf(payload, "state"), "stopped")) {
        self.held = self.held or self.state == .running;
        self.state = .idle;
    } else {
        changed = false;
    }
    if (changed) self.after = seq;
    return changed;
}

fn eventLabel(payload: std.json.Value) []const u8 {
    const title = strOf(payload, "title");
    if (title.len > 0) return title;
    const display = strOf(payload, "display_name");
    if (display.len > 0) return display;
    return strOf(payload, "tool");
}

fn promptOf(payload: std.json.Value) chat_options.Prompt {
    const questions_value = fieldOf(payload, "questions") orelse return .{};
    const rows = switch (questions_value) {
        .array => |array| array.items,
        else => return .{},
    };
    var options_storage: [chat_options.MAX_QUESTIONS][chat_options.MAX_OPTIONS]chat_options.WireOption = undefined;
    var questions_storage: [chat_options.MAX_QUESTIONS]chat_options.WireQuestion = undefined;
    var count: usize = 0;
    for (rows) |row| {
        if (count >= chat_options.MAX_QUESTIONS) break;
        const options_value = fieldOf(row, "options") orelse continue;
        const option_rows = switch (options_value) {
            .array => |array| array.items,
            else => continue,
        };
        var option_count: usize = 0;
        for (option_rows) |option| {
            if (option_count >= chat_options.MAX_OPTIONS) break;
            options_storage[count][option_count] = .{ .label = strOf(option, "label"), .description = strOf(option, "description") };
            option_count += 1;
        }
        questions_storage[count] = .{
            .question = strOf(row, "question"),
            .header = strOf(row, "header"),
            .options = options_storage[count][0..option_count],
            .multiSelect = boolOf(row, "multiSelect"),
        };
        count += 1;
    }
    return chat_options.Prompt.fromWire(.{ .id = strOf(payload, "request_id"), .questions = questions_storage[0..count] });
}

pub fn decisionText(decision: Decision) []const u8 {
    return switch (decision) {
        .accept => "accept",
        .accept_for_session => "acceptForSession",
        .decline => "decline",
        .cancel => "cancel",
    };
}

pub fn decisionFor(action: chat_permission.Action) Decision {
    return switch (action) {
        .allow => .accept,
        .always => .accept_for_session,
        .deny => .decline,
    };
}

pub fn actionText(action: PlanAction) []const u8 {
    return switch (action) {
        .implement => "implement",
        .feedback => "feedback",
    };
}

fn appendQuoted(out: *std.ArrayList(u8), a: std.mem.Allocator, value: []const u8) !void {
    const quoted = try std.json.Stringify.valueAlloc(a, value, .{});
    defer a.free(quoted);
    try out.appendSlice(a, quoted);
}

fn openLine(a: std.mem.Allocator, id: u32, op: []const u8, provider: []const u8, sid: []const u8) !std.ArrayList(u8) {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(a);
    const head = try std.fmt.allocPrint(a, "{{\"id\":{d},\"op\":", .{id});
    defer a.free(head);
    try out.appendSlice(a, head);
    try appendQuoted(&out, a, op);
    try out.appendSlice(a, ",\"provider\":");
    try appendQuoted(&out, a, provider);
    try out.appendSlice(a, ",\"sid\":");
    try appendQuoted(&out, a, sid);
    return out;
}

fn finish(out: *std.ArrayList(u8), a: std.mem.Allocator) ![]u8 {
    try out.append(a, '}');
    return out.toOwnedSlice(a);
}

pub fn subscribeLine(a: std.mem.Allocator, id: u32, provider: []const u8, sid: []const u8, after: u64) ![]u8 {
    var out = try openLine(a, id, "events_subscribe", provider, sid);
    errdefer out.deinit(a);
    const tail = try std.fmt.allocPrint(a, ",\"after\":{d}", .{after});
    defer a.free(tail);
    try out.appendSlice(a, tail);
    return finish(&out, a);
}

pub fn unsubscribeLine(a: std.mem.Allocator, id: u32, provider: []const u8, sid: []const u8, after: u64) ![]u8 {
    var out = try openLine(a, id, "events_unsubscribe", provider, sid);
    errdefer out.deinit(a);
    const tail = try std.fmt.allocPrint(a, ",\"after\":{d}", .{after});
    defer a.free(tail);
    try out.appendSlice(a, tail);
    return finish(&out, a);
}

pub fn interruptLine(a: std.mem.Allocator, id: u32, provider: []const u8, sid: []const u8) ![]u8 {
    var out = try openLine(a, id, "interrupt", provider, sid);
    errdefer out.deinit(a);
    return finish(&out, a);
}

pub fn approvalReplyLine(a: std.mem.Allocator, id: u32, provider: []const u8, sid: []const u8, request_id: []const u8, decision: Decision) ![]u8 {
    var out = try openLine(a, id, "approval_reply", provider, sid);
    errdefer out.deinit(a);
    try out.appendSlice(a, ",\"request_id\":");
    try appendQuoted(&out, a, request_id);
    try out.appendSlice(a, ",\"decision\":");
    try appendQuoted(&out, a, decisionText(decision));
    return finish(&out, a);
}

pub const Answer = struct { question: []const u8, answer: []const u8 };

pub fn questionReplyLine(a: std.mem.Allocator, id: u32, provider: []const u8, sid: []const u8, request_id: []const u8, answers: []const Answer, dismissed: bool) ![]u8 {
    var out = try openLine(a, id, "question_reply", provider, sid);
    errdefer out.deinit(a);
    try out.appendSlice(a, ",\"request_id\":");
    try appendQuoted(&out, a, request_id);
    try out.appendSlice(a, ",\"answers\":{");
    for (answers, 0..) |pair, index| {
        if (index > 0) try out.append(a, ',');
        try appendQuoted(&out, a, pair.question);
        try out.append(a, ':');
        try appendQuoted(&out, a, pair.answer);
    }
    try out.appendSlice(a, "},\"dismissed\":");
    try out.appendSlice(a, if (dismissed) "true" else "false");
    return finish(&out, a);
}

pub fn planReplyLine(a: std.mem.Allocator, id: u32, provider: []const u8, sid: []const u8, request_id: []const u8, action: PlanAction, feedback: ?[]const u8) ![]u8 {
    var out = try openLine(a, id, "plan_reply", provider, sid);
    errdefer out.deinit(a);
    try out.appendSlice(a, ",\"request_id\":");
    try appendQuoted(&out, a, request_id);
    try out.appendSlice(a, ",\"action\":");
    try appendQuoted(&out, a, actionText(action));
    if (feedback) |text| {
        try out.appendSlice(a, ",\"feedback\":");
        try appendQuoted(&out, a, text);
    }
    return finish(&out, a);
}

pub const Lock = struct {
    state: std.atomic.Value(u8) = std.atomic.Value(u8).init(0),

    pub fn lock(self: *Lock) void {
        while (self.state.cmpxchgWeak(0, 1, .acquire, .monotonic) != null) std.atomic.spinLoopHint();
    }

    pub fn unlock(self: *Lock) void {
        self.state.store(0, .release);
    }
};

pub var mutex: Lock = .{};
var slots: [MAX_LIVE]Live = @splat(.{});

fn slotFor(shell_id: u32, sid: []const u8) ?*Live {
    for (&slots) |*live| {
        if (live.used and live.shell_id == shell_id and std.mem.eql(u8, live.sidSlice(), sid)) return live;
    }
    return null;
}

fn claim(shell_id: u32, host: u8, sid: []const u8) ?*Live {
    if (slotFor(shell_id, sid)) |found| return found;
    for (&slots) |*live| {
        if (live.used and live.shell_id == shell_id) {
            live.clear(std.heap.page_allocator);
            live.sid_len = 0;
            return adopt(live, shell_id, host, sid);
        }
    }
    for (&slots) |*live| {
        if (!live.used) return adopt(live, shell_id, host, sid);
    }
    return null;
}

fn adopt(live: *Live, shell_id: u32, host: u8, sid: []const u8) *Live {
    live.used = true;
    live.shell_id = shell_id;
    live.host = host;
    live.sid_len = @min(sid.len, live.sid.len);
    @memcpy(live.sid[0..live.sid_len], sid[0..live.sid_len]);
    return live;
}

pub fn starting(shell_id: u32, host: u8, sid: []const u8) bool {
    if (shell_id == 0 or sid.len == 0 or sid.len > 48) return false;
    mutex.lock();
    defer mutex.unlock();
    const live = claim(shell_id, host, sid) orelse return false;
    live.state = .running;
    live.touch();
    return true;
}

pub fn begin(shell_id: u32, host: u8, sid: []const u8) u64 {
    if (shell_id == 0 or sid.len == 0 or sid.len >= MAX_ID) return 0;
    mutex.lock();
    defer mutex.unlock();
    const live = claim(shell_id, host, sid) orelse return 0;
    return live.after;
}

pub fn release(shell_id: u32) void {
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (live.used and live.shell_id == shell_id) {
            live.deinit(std.heap.page_allocator);
            live.* = .{};
        }
    }
}

pub fn applyPage(shell_id: u32, sid: []const u8, page: []const u8) bool {
    if (page.len == 0 or page.len > MAX_PAGE) return false;
    mutex.lock();
    defer mutex.unlock();
    const live = slotFor(shell_id, sid) orelse return false;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const parsed = std.json.parseFromSlice(std.json.Value, arena.allocator(), page, .{}) catch return false;
    var root = parsed.value;
    if (fieldOf(root, "result")) |result| root = result;
    const events_value = fieldOf(root, "events") orelse return false;
    const events = switch (events_value) {
        .array => |array| array.items,
        else => return false,
    };
    var changed = false;
    for (events) |entry| {
        const seq = intOf(entry, "seq") orelse continue;
        const event = fieldOf(entry, "event") orelse continue;
        const applied = applyValue(live, std.heap.page_allocator, seq, event) catch false;
        changed = changed or applied;
    }
    if (changed) live.touch();
    return changed;
}

pub fn running(shell_id: u32) bool {
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (live.used and live.shell_id == shell_id) return live.state == .running;
    }
    return false;
}

pub fn revision(shell_id: u32) u64 {
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (live.used and live.shell_id == shell_id) return live.revision;
    }
    return 0;
}

pub const Tail = struct { text_len: usize = 0, blocks: usize = 0 };

fn prefixOf(kind: ItemKind) []const u16 {
    return switch (kind) {
        .thinking => std.unicode.utf8ToUtf16LeStringLiteral("Thinking: "),
        .plan => std.unicode.utf8ToUtf16LeStringLiteral("**Plan ready**\n"),
        else => &.{},
    };
}

pub fn tailInto(self: *const Live, text: []u16, offset: usize, blocks: []chat_markdown.Block, seen: []const chat_markdown.Block) Tail {
    var out = Tail{};
    for (self.items.items) |*item| {
        if (out.blocks >= blocks.len) break;
        if (item.text.items.len == 0) continue;
        if (!chat_markdown.drawnOnce(item.key, seen)) continue;
        if (out.text_len > 0) {
            if (out.text_len >= text.len) break;
            text[out.text_len] = '\n';
            out.text_len += 1;
        }
        const start = out.text_len;
        for (prefixOf(item.kind)) |unit| {
            if (out.text_len >= text.len) break;
            text[out.text_len] = unit;
            out.text_len += 1;
        }
        if (out.text_len < text.len) {
            const converted = std.unicode.utf8ToUtf16Le(text[out.text_len..], item.text.items) catch 0;
            out.text_len += converted;
        }
        if (out.text_len <= start) continue;
        blocks[out.blocks] = .{
            .start = offset + start,
            .len = out.text_len - start,
            .role = switch (item.kind) {
                .thinking, .tool => .tool,
                else => .prose,
            },
            .markdown = true,
            .first = out.blocks == 0,
            .row_key = item.key,
            .tool_status = switch (item.status) {
                .running => .running,
                .failed => .@"error",
                .interrupted => .@"error",
                .ok => if (item.done) .ok else .running,
            },
        };
        out.blocks += 1;
    }
    return out;
}

pub fn tailFor(shell_id: u32, text: []u16, offset: usize, blocks: []chat_markdown.Block, seen: []const chat_markdown.Block) Tail {
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (live.used and live.shell_id == shell_id) return if (live.state == .running or live.held) tailInto(live, text, offset, blocks, seen) else .{};
    }
    return .{};
}

pub fn sentRowKeys(shell_id: u32, message_id: []const u8, out: []u64) usize {
    if (message_id.len == 0) return 0;
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (!live.used or live.shell_id != shell_id) continue;
        if (!std.mem.eql(u8, live.sent_id[0..live.sent_id_len], message_id)) return 0;
        const n = @min(live.sent_key_count, out.len);
        @memcpy(out[0..n], live.sent_keys[0..n]);
        return n;
    }
    return 0;
}

pub fn held(shell_id: u32) bool {
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (live.used and live.shell_id == shell_id) return live.held;
    }
    return false;
}

pub fn historyCaughtUp(shell_id: u32) void {
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (!live.used or live.shell_id != shell_id) continue;
        if (std.mem.eql(u8, live.turn[0..live.turn_len], "startup-failure")) continue;
        if (live.held) {
            live.held = false;
            live.touch();
        } else if (live.state == .running and live.items.items.len > 0) {
            const last = live.items.items[live.items.items.len - 1];
            live.reply_in_history = last.kind == .text and last.done;
        }
    }
}

pub fn approvalMenu(shell_id: u32, out: *chat_permission.PermissionMenu) bool {
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (!live.used or live.shell_id != shell_id) continue;
        if (!live.request.open or live.request.kind != .approval) return false;
        var menu: chat_permission.PermissionMenu = .{};
        const texts = [_][]const u8{ "Approve", "Always allow this session", "Decline" };
        for (texts, 0..) |value, index| {
            const units = std.unicode.utf8ToUtf16Le(&menu.options[index].text, value) catch return false;
            menu.options[index].number = @intCast('1' + index);
            menu.options[index].len = units;
        }
        menu.count = texts.len;
        menu.allow = '1';
        menu.always = '2';
        menu.deny = '3';
        out.* = menu;
        return true;
    }
    return false;
}

pub fn approvalOpen(shell_id: u32) bool {
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (live.used and live.shell_id == shell_id) return live.request.open and live.request.kind == .approval;
    }
    return false;
}

pub fn cardDismissed(shell_id: u32) bool {
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (live.used and live.shell_id == shell_id) return live.card_dismissed;
    }
    return false;
}

pub fn cardShown(shell_id: u32) void {
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (live.used and live.shell_id == shell_id) live.card_dismissed = false;
    }
}

pub fn requestId(shell_id: u32, kind: RequestKind, out: []u8) ?usize {
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (!live.used or live.shell_id != shell_id) continue;
        if (!live.request.open or live.request.kind != kind) return null;
        const id = live.request.idSlice();
        if (id.len == 0 or id.len > out.len) return null;
        @memcpy(out[0..id.len], id);
        return id.len;
    }
    return null;
}

pub fn questionPrompt(shell_id: u32, out: *chat_options.Prompt) bool {
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (!live.used or live.shell_id != shell_id) continue;
        if (!live.request.open or live.request.kind != .question or live.prompt.count == 0) return false;
        out.* = live.prompt;
        return true;
    }
    return false;
}

pub fn attached(shell_id: u32) bool {
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (live.used and live.shell_id == shell_id) return true;
    }
    return false;
}

fn answersComplete(live: *const Live) bool {
    if (!live.request.open or live.request.kind != .question or live.prompt.count == 0) return false;
    for (0..live.prompt.count) |index| {
        if (live.answer_lens[index] == 0) return false;
    }
    return true;
}

pub fn answerQuestion(shell_id: u32, index: usize, text: []const u8) bool {
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (!live.used or live.shell_id != shell_id) continue;
        if (!live.request.open or live.request.kind != .question or index >= live.prompt.count) return false;
        live.answer_lens[index] = @min(text.len, live.answers[index].len);
        @memcpy(live.answers[index][0..live.answer_lens[index]], text[0..live.answer_lens[index]]);
        live.touch();
        return true;
    }
    return false;
}

pub fn answersDone(shell_id: u32) bool {
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (live.used and live.shell_id == shell_id) return answersComplete(live);
    }
    return false;
}

pub fn questionAnswerLine(shell_id: u32, a: std.mem.Allocator, provider: []const u8) ?[]u8 {
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (!live.used or live.shell_id != shell_id) continue;
        if (!answersComplete(live)) return null;
        var keys: [chat_options.MAX_QUESTIONS][4]u8 = undefined;
        var pairs: [chat_options.MAX_QUESTIONS]Answer = undefined;
        for (0..live.prompt.count) |index| {
            pairs[index] = .{
                .question = std.fmt.bufPrint(&keys[index], "{d}", .{index}) catch return null,
                .answer = live.answers[index][0..live.answer_lens[index]],
            };
        }
        return questionReplyLine(a, shell_id, provider, live.sidSlice(), live.request.idSlice(), pairs[0..live.prompt.count], false) catch null;
    }
    return null;
}

pub fn dismissedQuestionLine(shell_id: u32, a: std.mem.Allocator, provider: []const u8) ?[]u8 {
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (!live.used or live.shell_id != shell_id) continue;
        if (!live.request.open or live.request.kind != .question) return null;
        return questionReplyLine(a, shell_id, provider, live.sidSlice(), live.request.idSlice(), &.{}, true) catch null;
    }
    return null;
}

pub fn questionsOpen(shell_id: u32) bool {
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (live.used and live.shell_id == shell_id) return live.request.open and live.request.kind == .question;
    }
    return false;
}

pub fn closeRequest(shell_id: u32) void {
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (live.used and live.shell_id == shell_id) {
            live.request.open = false;
            live.touch();
        }
    }
}

pub fn planOpen(shell_id: u32) bool {
    mutex.lock();
    defer mutex.unlock();
    for (&slots) |*live| {
        if (live.used and live.shell_id == shell_id) return live.request.open and live.request.kind == .plan;
    }
    return false;
}

test "D3 answers are stored per question and only a full set builds the reply" {
    defer release(77);
    _ = begin(77, 0, "11111111-2222-3333-4444-666666666666");
    const a = std.testing.allocator;
    const sid = "11111111-2222-3333-4444-666666666666";
    try std.testing.expect(applyPage(77, sid, "{\"result\":{\"events\":[{\"seq\":1,\"event\":{\"kind\":\"question.request\",\"payload\":{\"request_id\":\"req_5\",\"questions\":[" ++
        "{\"question\":\"Which colour?\",\"options\":[{\"label\":\"Lime\"},{\"label\":\"Orange\"}]}," ++
        "{\"question\":\"Which devices?\",\"multiSelect\":true,\"options\":[{\"label\":\"Desktop\"},{\"label\":\"Phone\"}]}]}}}]}}"));
    try std.testing.expect(questionAnswerLine(77, a, "claude") == null);
    try std.testing.expect(answerQuestion(77, 0, "Lime"));
    try std.testing.expect(questionAnswerLine(77, a, "claude") == null);
    try std.testing.expect(answerQuestion(77, 1, "Desktop, Phone"));
    try std.testing.expect(answersDone(77));
    const line = questionAnswerLine(77, a, "claude").?;
    defer a.free(line);
    try std.testing.expectEqualStrings(
        "{\"id\":77,\"op\":\"question_reply\",\"provider\":\"claude\",\"sid\":\"11111111-2222-3333-4444-666666666666\",\"request_id\":\"req_5\",\"answers\":{\"0\":\"Lime\",\"1\":\"Desktop, Phone\"},\"dismissed\":false}",
        line,
    );
    try std.testing.expect(applyPage(77, sid, "{\"result\":{\"events\":[{\"seq\":2,\"event\":{\"kind\":\"question.resolved\",\"payload\":{\"request_id\":\"req_5\",\"answers\":{},\"dismissed\":false}}}]}}"));
    try std.testing.expect(questionAnswerLine(77, a, "claude") == null);
    try std.testing.expect(!questionsOpen(77));
}

test "D3 a question longer than a display line still answers under its id" {
    defer release(78);
    _ = begin(78, 0, "22222222-3333-4444-5555-666666666666");
    const a = std.testing.allocator;
    const sid = "22222222-3333-4444-5555-666666666666";
    try std.testing.expect(applyPage(78, sid, "{\"result\":{\"events\":[{\"seq\":1,\"event\":{\"kind\":\"question.request\",\"payload\":{\"request_id\":\"req_long\",\"questions\":[" ++
        "{\"question\":\"Which of these three approaches should I take for the retry loop in the chat reader when the host keeps restarting in the middle of a turn while the desktop is asleep and the socket never comes back\",\"options\":[{\"label\":\"Lime\"},{\"label\":\"Orange\"}]}]}}}]}}"));
    try std.testing.expect(answerQuestion(78, 0, "Lime"));
    const line = questionAnswerLine(78, a, "claude").?;
    defer a.free(line);
    try std.testing.expect(std.mem.endsWith(u8, line, ",\"answers\":{\"0\":\"Lime\"},\"dismissed\":false}"));
}

test "D1 a text delta replaces the accumulated text instead of appending" {
    var live: Live = .{};
    defer live.deinit(std.testing.allocator);
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expect(try applyValue(&live, std.testing.allocator, 1, try parse(a, "{\"kind\":\"text.delta\",\"item\":\"m:text:0\",\"payload\":{\"text\":\"Here is the \"}}")));
    try std.testing.expect(try applyValue(&live, std.testing.allocator, 2, try parse(a, "{\"kind\":\"text.delta\",\"item\":\"m:text:0\",\"payload\":{\"text\":\"Here is the answer\"}}")));
    try std.testing.expectEqual(@as(usize, 1), live.items.items.len);
    try std.testing.expectEqualStrings("Here is the answer", live.items.items[0].text.items);
    try std.testing.expectEqualStrings("m:text:0", live.items.items[0].idSlice());
}

test "D1 a duplicate seq is ignored and the cursor does not move backwards" {
    var live: Live = .{};
    defer live.deinit(std.testing.allocator);
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expect(try applyValue(&live, std.testing.allocator, 5, try parse(a, "{\"kind\":\"text.delta\",\"item\":\"m:text:0\",\"payload\":{\"text\":\"one\"}}")));
    try std.testing.expect(!try applyValue(&live, std.testing.allocator, 5, try parse(a, "{\"kind\":\"text.delta\",\"item\":\"m:text:0\",\"payload\":{\"text\":\"two\"}}")));
    try std.testing.expect(!try applyValue(&live, std.testing.allocator, 4, try parse(a, "{\"kind\":\"text.delta\",\"item\":\"m:text:0\",\"payload\":{\"text\":\"three\"}}")));
    try std.testing.expectEqual(@as(u64, 5), live.after);
    try std.testing.expectEqualStrings("one", live.items.items[0].text.items);
}

test "D1 a reconnect replays from the last seen seq and skips what it already has" {
    defer release(99);
    const page = "{\"id\":88,\"message_protocol\":1,\"result\":{\"events\":[" ++
        "{\"seq\":7,\"event\":{\"v\":1,\"kind\":\"turn.started\",\"turn\":\"t-1\",\"payload\":{}}}," ++
        "{\"seq\":8,\"event\":{\"v\":1,\"kind\":\"text.delta\",\"turn\":\"t-1\",\"item\":\"m:text:0\",\"payload\":{\"text\":\"Hel\"}}}," ++
        "{\"seq\":9,\"event\":{\"v\":1,\"kind\":\"text.delta\",\"turn\":\"t-1\",\"item\":\"m:text:0\",\"payload\":{\"text\":\"Hello\"}}}" ++
        "],\"next_after\":9}}";
    try std.testing.expectEqual(@as(u64, 0), begin(99, 0, "11111111-2222-3333-4444-555555555555"));
    defer release(99);
    try std.testing.expect(applyPage(99, "11111111-2222-3333-4444-555555555555", page));
    try std.testing.expectEqual(@as(u64, 9), begin(99, 0, "11111111-2222-3333-4444-555555555555"));
    try std.testing.expect(!applyPage(99, "11111111-2222-3333-4444-555555555555", page));
    try std.testing.expectEqual(@as(u64, 9), begin(99, 0, "11111111-2222-3333-4444-555555555555"));
    var text: [128]u16 = @splat(0);
    var blocks: [4]chat_markdown.Block = undefined;
    const tail = tailFor(99, &text, 0, &blocks, &.{});
    try std.testing.expectEqual(@as(usize, 1), tail.blocks);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Hello"), text[0..tail.text_len]);
}

test "D1 thinking and text deltas keep their arrival order" {
    var live: Live = .{};
    defer live.deinit(std.testing.allocator);
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    _ = try applyValue(&live, std.testing.allocator, 1, try parse(a, "{\"kind\":\"thinking.delta\",\"item\":\"m:thinking:0\",\"payload\":{\"text\":\"weighing\"}}"));
    _ = try applyValue(&live, std.testing.allocator, 2, try parse(a, "{\"kind\":\"text.delta\",\"item\":\"m:text:0\",\"payload\":{\"text\":\"answer\"}}"));
    try std.testing.expectEqual(@as(usize, 2), live.items.items.len);
    try std.testing.expectEqual(ItemKind.thinking, live.items.items[0].kind);
    try std.testing.expectEqual(ItemKind.text, live.items.items[1].kind);
    var text: [128]u16 = @splat(0);
    var blocks: [8]chat_markdown.Block = undefined;
    const tail = tailInto(&live, &text, 40, &blocks, &.{});
    try std.testing.expectEqual(@as(usize, 2), tail.blocks);
    try std.testing.expectEqual(@as(usize, 40), blocks[0].start);
    try std.testing.expectEqual(chat_markdown.Role.tool, blocks[0].role);
    try std.testing.expectEqual(chat_markdown.Role.prose, blocks[1].role);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("answer"), text[blocks[1].start - 40 ..][0..blocks[1].len]);
}

test "D1 a tool step is one line and closes on item.done" {
    var live: Live = .{};
    defer live.deinit(std.testing.allocator);
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    _ = try applyValue(&live, std.testing.allocator, 1, try parse(a, "{\"kind\":\"item.started\",\"item\":\"toolu_1\",\"payload\":{\"type\":\"tool_call\",\"tool\":\"Bash\",\"title\":\"Run the tests\"}}"));
    _ = try applyValue(&live, std.testing.allocator, 2, try parse(a, "{\"kind\":\"item.done\",\"item\":\"toolu_1\",\"payload\":{\"status\":\"completed\"}}"));
    try std.testing.expectEqual(@as(usize, 1), live.items.items.len);
    try std.testing.expectEqualStrings("Run the tests", live.items.items[0].text.items);
    try std.testing.expect(live.items.items[0].done);
    try std.testing.expectEqual(ItemStatus.ok, live.items.items[0].status);
}

test "D2 an approval request fills the existing card and resolved clears it" {
    var live: Live = .{};
    defer live.deinit(std.testing.allocator);
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    _ = try applyValue(&live, std.testing.allocator, 1, try parse(a, "{\"kind\":\"approval.request\",\"payload\":{\"request_id\":\"req_1\",\"tool\":\"Bash\",\"title\":\"Run rm -rf build\",\"decision_reason\":\"needs a shell\"}}"));
    var menu: chat_permission.PermissionMenu = .{};
    try std.testing.expect(live.request.open);
    try std.testing.expectEqualStrings("req_1", live.request.idSlice());
    try std.testing.expectEqualStrings("Run rm -rf build", live.request.titleSlice());
    live.request.openWith(.approval, "req_1", "Run rm -rf build");
    try std.testing.expect(approvalMenu(0, &menu) == false);
    _ = try applyValue(&live, std.testing.allocator, 2, try parse(a, "{\"kind\":\"approval.resolved\",\"payload\":{\"request_id\":\"req_1\",\"decision\":\"accept\"}}"));
    try std.testing.expect(!live.request.open);
    try std.testing.expect(live.card_dismissed);
}

test "D2 the approval card reuses the three existing buttons and their action mapping" {
    release(4242);
    _ = begin(4242, 0, "11111111-2222-3333-4444-555555555555");
    defer release(4242);
    try std.testing.expect(applyPage(4242, "11111111-2222-3333-4444-555555555555", "{\"result\":{\"events\":[{\"seq\":1,\"event\":{\"kind\":\"approval.request\",\"payload\":{\"request_id\":\"req_9\",\"tool\":\"Bash\",\"title\":\"Run ls\"}}}]}}"));
    var menu: chat_permission.PermissionMenu = .{};
    try std.testing.expect(approvalMenu(4242, &menu));
    try std.testing.expectEqual(@as(usize, 3), menu.count);
    try std.testing.expectEqual(@as(?u8, '1'), menu.allow);
    try std.testing.expectEqual(@as(?u8, '2'), menu.always);
    try std.testing.expectEqual(@as(?u8, '3'), menu.deny);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Approve"), menu.optionText(.allow).?);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Always allow this session"), menu.optionText(.always).?);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Decline"), menu.optionText(.deny).?);
    try std.testing.expectEqual(Decision.accept, decisionFor(.allow));
    try std.testing.expectEqual(Decision.accept_for_session, decisionFor(.always));
    try std.testing.expectEqual(Decision.decline, decisionFor(.deny));
}

test "D3 a question request loads the option pills and resolved clears them" {
    var live: Live = .{};
    defer live.deinit(std.testing.allocator);
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    _ = try applyValue(&live, std.testing.allocator, 1, try parse(a,
        "{\"kind\":\"question.request\",\"payload\":{\"request_id\":\"req_2\",\"questions\":[" ++
            "{\"question\":\"Which colour?\",\"header\":\"Accent\",\"multiSelect\":false,\"options\":[{\"label\":\"Lime\"},{\"label\":\"Orange\"}]}," ++
            "{\"question\":\"Which devices?\",\"header\":\"Devices\",\"multiSelect\":true,\"options\":[{\"label\":\"Desktop\"},{\"label\":\"Phone\"}]}]}}"));
    try std.testing.expectEqual(RequestKind.question, live.request.kind);
    try std.testing.expectEqual(@as(usize, 2), live.prompt.count);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Which colour?"), live.prompt.groups[0].questionSlice());
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Orange"), live.prompt.groups[0].options[1].titleSlice());
    try std.testing.expect(live.prompt.groups[1].multi_select);
    _ = try applyValue(&live, std.testing.allocator, 2, try parse(a, "{\"kind\":\"question.resolved\",\"payload\":{\"request_id\":\"req_2\",\"answers\":{\"Which colour?\":\"Lime\"},\"dismissed\":false}}"));
    try std.testing.expect(!live.request.open);
    try std.testing.expectEqual(@as(usize, 0), live.prompt.count);
}

test "D4 a proposed plan renders as an assistant block behind a plan ready line" {
    var live: Live = .{};
    defer live.deinit(std.testing.allocator);
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    _ = try applyValue(&live, std.testing.allocator, 1, try parse(a, "{\"kind\":\"plan.proposed\",\"item\":\"m:text:1\",\"payload\":{\"request_id\":\"req_3\",\"markdown\":\"## Steps\\n- one\"}}"));
    try std.testing.expectEqual(RequestKind.plan, live.request.kind);
    var text: [256]u16 = @splat(0);
    var blocks: [4]chat_markdown.Block = undefined;
    const tail = tailInto(&live, &text, 0, &blocks, &.{});
    try std.testing.expectEqual(@as(usize, 1), tail.blocks);
    try std.testing.expectEqual(chat_markdown.Role.prose, blocks[0].role);
    const body = text[blocks[0].start..][0..blocks[0].len];
    const ready = std.unicode.utf8ToUtf16LeStringLiteral("**Plan ready**");
    try std.testing.expectEqualSlices(u16, ready, body[0..ready.len]);
    try std.testing.expect(std.mem.indexOf(u16, body, std.unicode.utf8ToUtf16LeStringLiteral("one")) != null);
    _ = try applyValue(&live, std.testing.allocator, 2, try parse(a, "{\"kind\":\"plan.resolved\",\"payload\":{\"request_id\":\"req_3\",\"action\":\"implement\"}}"));
    try std.testing.expect(!live.request.open);
}

test "D5 a turn runs from started to ended and an interrupt ends it interrupted" {
    var live: Live = .{};
    defer live.deinit(std.testing.allocator);
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    _ = try applyValue(&live, std.testing.allocator, 1, try parse(a, "{\"kind\":\"turn.started\",\"turn\":\"t-7\",\"payload\":{\"message_id\":\"m\"}}"));
    try std.testing.expectEqual(State.running, live.state);
    try std.testing.expectEqualStrings("t-7", live.turn[0..live.turn_len]);
    _ = try applyValue(&live, std.testing.allocator, 2, try parse(a, "{\"kind\":\"turn.ended\",\"turn\":\"t-7\",\"payload\":{\"status\":\"interrupted\",\"stop_reason\":\"interrupt\"}}"));
    try std.testing.expectEqual(State.idle, live.state);
    try std.testing.expectEqual(ItemStatus.interrupted, live.ended);
}

test "D1 an unknown kind changes nothing" {
    var live: Live = .{};
    defer live.deinit(std.testing.allocator);
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expect(!try applyValue(&live, std.testing.allocator, 3, try parse(a, "{\"kind\":\"rate.limit\",\"payload\":{}}")));
    try std.testing.expectEqual(@as(u64, 0), live.after);
}

test "D1 the subscribe line carries the replay cursor on the existing channel" {
    const a = std.testing.allocator;
    const line = try subscribeLine(a, 88, "claude", "a1b2c3d4-0000-1111-2222-333344445555", 1420);
    defer a.free(line);
    try std.testing.expectEqualStrings(
        "{\"id\":88,\"op\":\"events_subscribe\",\"provider\":\"claude\",\"sid\":\"a1b2c3d4-0000-1111-2222-333344445555\",\"after\":1420}",
        line,
    );
    const stop = try unsubscribeLine(a, 88, "claude", "a1b2c3d4-0000-1111-2222-333344445555", 1420);
    defer a.free(stop);
    try std.testing.expectEqualStrings(
        "{\"id\":88,\"op\":\"events_unsubscribe\",\"provider\":\"claude\",\"sid\":\"a1b2c3d4-0000-1111-2222-333344445555\",\"after\":1420}",
        stop,
    );
}

test "D2 the approval reply sends the exact decision word for its button" {
    const a = std.testing.allocator;
    const accept = try approvalReplyLine(a, 89, "claude", "sid-1", "req_1", .accept);
    defer a.free(accept);
    try std.testing.expectEqualStrings(
        "{\"id\":89,\"op\":\"approval_reply\",\"provider\":\"claude\",\"sid\":\"sid-1\",\"request_id\":\"req_1\",\"decision\":\"accept\"}",
        accept,
    );
    const session = try approvalReplyLine(a, 89, "claude", "sid-1", "req_1", .accept_for_session);
    defer a.free(session);
    try std.testing.expect(std.mem.endsWith(u8, session, "\"decision\":\"acceptForSession\"}"));
    const cancel = try approvalReplyLine(a, 89, "claude", "sid-1", "req_1", .cancel);
    defer a.free(cancel);
    try std.testing.expect(std.mem.endsWith(u8, cancel, "\"decision\":\"cancel\"}"));
}

test "D3 the question reply sends every answer keyed by its question" {
    const a = std.testing.allocator;
    const answers = [_]Answer{
        .{ .question = "Which colour?", .answer = "Lime" },
        .{ .question = "Which devices?", .answer = "Desktop, Phone" },
    };
    const line = try questionReplyLine(a, 90, "claude", "sid-1", "req_2", &answers, false);
    defer a.free(line);
    try std.testing.expectEqualStrings(
        "{\"id\":90,\"op\":\"question_reply\",\"provider\":\"claude\",\"sid\":\"sid-1\",\"request_id\":\"req_2\",\"answers\":{\"Which colour?\":\"Lime\",\"Which devices?\":\"Desktop, Phone\"},\"dismissed\":false}",
        line,
    );
    const dismissed = try questionReplyLine(a, 90, "claude", "sid-1", "req_2", &.{}, true);
    defer a.free(dismissed);
    try std.testing.expectEqualStrings(
        "{\"id\":90,\"op\":\"question_reply\",\"provider\":\"claude\",\"sid\":\"sid-1\",\"request_id\":\"req_2\",\"answers\":{},\"dismissed\":true}",
        dismissed,
    );
}

test "D4 the plan reply is implement with no text and feedback with text" {
    const a = std.testing.allocator;
    const implement = try planReplyLine(a, 91, "claude", "sid-1", "req_3", .implement, null);
    defer a.free(implement);
    try std.testing.expectEqualStrings(
        "{\"id\":91,\"op\":\"plan_reply\",\"provider\":\"claude\",\"sid\":\"sid-1\",\"request_id\":\"req_3\",\"action\":\"implement\"}",
        implement,
    );
    const feedback = try planReplyLine(a, 91, "claude", "sid-1", "req_3", .feedback, "use a queue instead");
    defer a.free(feedback);
    try std.testing.expectEqualStrings(
        "{\"id\":91,\"op\":\"plan_reply\",\"provider\":\"claude\",\"sid\":\"sid-1\",\"request_id\":\"req_3\",\"action\":\"feedback\",\"feedback\":\"use a queue instead\"}",
        feedback,
    );
}

test "Codex and Pi live requests retain the selected provider" {
    const a = std.testing.allocator;
    for ([_][]const u8{ "codex", "pi" }) |provider| {
        const subscribe = try subscribeLine(a, 7, provider, "sid", 42);
        defer a.free(subscribe);
        const expected_subscribe = try std.fmt.allocPrint(a, "{{\"id\":7,\"op\":\"events_subscribe\",\"provider\":\"{s}\",\"sid\":\"sid\",\"after\":42}}", .{provider});
        defer a.free(expected_subscribe);
        try std.testing.expectEqualStrings(expected_subscribe, subscribe);
        const approval = try approvalReplyLine(a, 7, provider, "sid", "req", .accept);
        defer a.free(approval);
        const expected_approval = try std.fmt.allocPrint(a, "{{\"id\":7,\"op\":\"approval_reply\",\"provider\":\"{s}\",\"sid\":\"sid\",\"request_id\":\"req\",\"decision\":\"accept\"}}", .{provider});
        defer a.free(expected_approval);
        try std.testing.expectEqualStrings(expected_approval, approval);
        const interrupt = try interruptLine(a, 7, provider, "sid");
        defer a.free(interrupt);
        const expected_interrupt = try std.fmt.allocPrint(a, "{{\"id\":7,\"op\":\"interrupt\",\"provider\":\"{s}\",\"sid\":\"sid\"}}", .{provider});
        defer a.free(expected_interrupt);
        try std.testing.expectEqualStrings(expected_interrupt, interrupt);
    }
}

test "D5 the interrupt op asks the host to stop the turn without killing it" {
    const a = std.testing.allocator;
    const line = try interruptLine(a, 92, "claude", "sid-1");
    defer a.free(line);
    try std.testing.expectEqualStrings("{\"id\":92,\"op\":\"interrupt\",\"provider\":\"claude\",\"sid\":\"sid-1\"}", line);
}

test "IGSH-1266 a new turn drops the last turn so the live tail shows only the running reply" {
    const sid = "11111111-2222-3333-4444-666666666666";
    _ = begin(98, 0, sid);
    defer release(98);
    const old_turn = "{\"result\":{\"events\":[" ++
        "{\"seq\":1,\"event\":{\"kind\":\"turn.started\",\"turn\":\"t-1\",\"payload\":{}}}," ++
        "{\"seq\":2,\"event\":{\"kind\":\"text.done\",\"turn\":\"t-1\",\"item\":\"a:text:0\",\"payload\":{\"text\":\"Old reply\"}}}," ++
        "{\"seq\":3,\"event\":{\"kind\":\"turn.ended\",\"turn\":\"t-1\",\"payload\":{\"status\":\"completed\"}}}" ++
        "]}}";
    try std.testing.expect(applyPage(98, sid, old_turn));
    var text: [128]u16 = @splat(0);
    var blocks: [4]chat_markdown.Block = undefined;
    try std.testing.expect(held(98));
    try std.testing.expectEqual(@as(usize, 1), tailFor(98, &text, 0, &blocks, &.{}).blocks);
    historyCaughtUp(98);
    try std.testing.expectEqual(@as(usize, 0), tailFor(98, &text, 0, &blocks, &.{}).blocks);
    const new_turn = "{\"result\":{\"events\":[" ++
        "{\"seq\":4,\"event\":{\"kind\":\"turn.started\",\"turn\":\"t-2\",\"payload\":{}}}," ++
        "{\"seq\":5,\"event\":{\"kind\":\"text.delta\",\"turn\":\"t-2\",\"item\":\"b:text:0\",\"payload\":{\"text\":\"New\"}}}" ++
        "]}}";
    try std.testing.expect(applyPage(98, sid, new_turn));
    try std.testing.expect(running(98));
    const tail = tailFor(98, &text, 0, &blocks, &.{});
    try std.testing.expectEqual(@as(usize, 1), tail.blocks);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("New"), text[0..tail.text_len]);
}

test "IGSH-1593 startup runs until ready and survives first subscription" {
    const sid = "11111111-2222-3333-4444-123456789abc";
    try std.testing.expect(starting(91, 0, sid));
    defer release(91);
    try std.testing.expect(running(91));
    try std.testing.expectEqual(@as(u64, 0), begin(91, 0, sid));
    try std.testing.expect(running(91));
    const ready = "{\"result\":{\"events\":[{\"seq\":1,\"event\":{\"kind\":\"host.status\",\"payload\":{\"state\":\"ready\"}}}]}}";
    try std.testing.expect(applyPage(91, sid, ready));
    try std.testing.expect(!running(91));
}

test "IGSH-1593 startup failure survives empty history and replay" {
    const sid = "11111111-2222-3333-4444-123456789abc";
    try std.testing.expect(starting(90, 0, sid));
    defer release(90);
    _ = begin(90, 0, sid);
    const page = "{\"result\":{\"events\":[" ++
        "{\"seq\":1,\"event\":{\"kind\":\"turn.started\",\"turn\":\"startup-failure\",\"payload\":{}}}," ++
        "{\"seq\":2,\"event\":{\"kind\":\"text.done\",\"turn\":\"startup-failure\",\"item\":\"startup-failure\",\"payload\":{\"text\":\"Could not start chat.\"}}}" ++
        "]}}";
    try std.testing.expect(applyPage(90, sid, page));
    historyCaughtUp(90);
    const ended = "{\"result\":{\"events\":[{\"seq\":3,\"event\":{\"kind\":\"turn.ended\",\"turn\":\"startup-failure\",\"payload\":{\"status\":\"failed\"}}}]}}";
    try std.testing.expect(applyPage(90, sid, ended));
    try std.testing.expect(!running(90));
    try std.testing.expect(held(90));
    var text: [128]u16 = @splat(0);
    var blocks: [4]chat_markdown.Block = undefined;
    historyCaughtUp(90);
    try std.testing.expect(!applyPage(90, sid, page));
    const tail = tailFor(90, &text, 0, &blocks, &.{});
    try std.testing.expectEqual(@as(usize, 1), tail.blocks);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Could not start chat."), text[0..tail.text_len]);
    try std.testing.expectEqual(@as(usize, 0), tailFor(90, &text, 0, &blocks, blocks[0..1]).blocks);
    try std.testing.expect(!running(90));
}

test "IGSH-1266 a host that turns ready mid-turn keeps the live reply on screen" {
    const sid = "11111111-2222-3333-4444-777777777777";
    _ = begin(97, 0, sid);
    defer release(97);
    const page = "{\"result\":{\"events\":[" ++
        "{\"seq\":1,\"event\":{\"kind\":\"host.status\",\"payload\":{\"state\":\"starting\"}}}," ++
        "{\"seq\":2,\"event\":{\"kind\":\"turn.started\",\"turn\":\"t-1\",\"payload\":{}}}," ++
        "{\"seq\":3,\"event\":{\"kind\":\"host.status\",\"payload\":{\"state\":\"ready\"}}}," ++
        "{\"seq\":4,\"event\":{\"kind\":\"text.delta\",\"turn\":\"t-1\",\"item\":\"a:text:0\",\"payload\":{\"text\":\"Live\"}}}" ++
        "]}}";
    try std.testing.expect(applyPage(97, sid, page));
    try std.testing.expect(running(97));
    var text: [64]u16 = @splat(0);
    var blocks: [4]chat_markdown.Block = undefined;
    const tail = tailFor(97, &text, 0, &blocks, &.{});
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Live"), text[0..tail.text_len]);
    const stopped = "{\"result\":{\"events\":[{\"seq\":5,\"event\":{\"kind\":\"host.status\",\"payload\":{\"state\":\"stopped\"}}}]}}";
    try std.testing.expect(applyPage(97, sid, stopped));
    try std.testing.expect(!running(97));
    try std.testing.expect(held(97));
}

test "IGSH-1266 history that lands before the turn ends does not leave a second copy of the reply" {
    const sid = "11111111-2222-3333-4444-999999999999";
    _ = begin(95, 0, sid);
    defer release(95);
    const reply = "{\"result\":{\"events\":[" ++
        "{\"seq\":1,\"event\":{\"kind\":\"turn.started\",\"turn\":\"t-1\",\"payload\":{}}}," ++
        "{\"seq\":2,\"event\":{\"kind\":\"text.delta\",\"turn\":\"t-1\",\"item\":\"a:text:0\",\"payload\":{\"text\":\"Rep\"}}}" ++
        "]}}";
    try std.testing.expect(applyPage(95, sid, reply));
    historyCaughtUp(95);
    const done = "{\"result\":{\"events\":[" ++
        "{\"seq\":3,\"event\":{\"kind\":\"text.done\",\"turn\":\"t-1\",\"item\":\"a:text:0\",\"payload\":{\"text\":\"Reply\"}}}" ++
        "]}}";
    try std.testing.expect(applyPage(95, sid, done));
    historyCaughtUp(95);
    const ended = "{\"result\":{\"events\":[{\"seq\":4,\"event\":{\"kind\":\"turn.ended\",\"turn\":\"t-1\",\"payload\":{\"status\":\"completed\"}}}]}}";
    try std.testing.expect(applyPage(95, sid, ended));
    try std.testing.expect(!held(95));
    var text: [64]u16 = @splat(0);
    var blocks: [4]chat_markdown.Block = undefined;
    try std.testing.expectEqual(@as(usize, 0), tailFor(95, &text, 0, &blocks, &.{}).blocks);
}

test "IGSH-1415 a reply the transcript already carries is drawn once while the turn runs" {
    const sid = "11111111-2222-3333-4444-777777777777";
    _ = begin(94, 0, sid);
    defer release(94);
    const page = "{\"result\":{\"events\":[" ++
        "{\"seq\":1,\"event\":{\"kind\":\"turn.started\",\"turn\":\"t-1\",\"payload\":{}}}," ++
        "{\"seq\":2,\"event\":{\"kind\":\"text.done\",\"turn\":\"t-1\",\"item\":\"msg_ab:text:0\",\"payload\":{\"text\":\"Reply\"}}}" ++
        "]}}";
    try std.testing.expect(applyPage(94, sid, page));
    var text: [64]u16 = @splat(0);
    var blocks: [4]chat_markdown.Block = undefined;
    const landed = [_]chat_markdown.Block{.{ .start = 0, .len = 5, .role = .prose, .row_key = chat_markdown.rowKey("msg_ab") }};
    try std.testing.expectEqual(@as(usize, 0), tailFor(94, &text, 0, &blocks, &landed).blocks);
    try std.testing.expectEqual(@as(usize, 1), tailFor(94, &text, 0, &blocks, &.{}).blocks);
}

test "IGSH-1415 a live step the transcript has not carried yet stays on screen" {
    const sid = "11111111-2222-3333-4444-666666666666";
    _ = begin(93, 0, sid);
    defer release(93);
    const page = "{\"result\":{\"events\":[" ++
        "{\"seq\":1,\"event\":{\"kind\":\"turn.started\",\"turn\":\"t-1\",\"payload\":{}}}," ++
        "{\"seq\":2,\"event\":{\"kind\":\"text.delta\",\"turn\":\"t-1\",\"item\":\"msg_cd:text:0\",\"payload\":{\"text\":\"Later\"}}}" ++
        "]}}";
    try std.testing.expect(applyPage(93, sid, page));
    var text: [64]u16 = @splat(0);
    var blocks: [4]chat_markdown.Block = undefined;
    const landed = [_]chat_markdown.Block{.{ .start = 0, .len = 5, .role = .prose, .row_key = chat_markdown.rowKey("msg_ab") }};
    try std.testing.expectEqual(@as(usize, 1), tailFor(93, &text, 0, &blocks, &landed).blocks);
}

test "IGSH-1415 a sent message carries the transcript row key of the turn it started" {
    const sid = "11111111-2222-3333-4444-555555555555";
    _ = begin(92, 0, sid);
    defer release(92);
    const page = "{\"result\":{\"events\":[{\"seq\":1,\"event\":{\"kind\":\"turn.started\",\"turn\":\"t-1\",\"payload\":{\"message_id\":\"mp-1\",\"uuids\":[\"u-1\",\"u-2\"]}}}]}}";
    try std.testing.expect(applyPage(92, sid, page));
    var keys: [SENT_KEYS]u64 = undefined;
    try std.testing.expectEqual(@as(usize, 2), sentRowKeys(92, "mp-1", &keys));
    try std.testing.expectEqual(chat_markdown.rowKey("u-1"), keys[0]);
    try std.testing.expectEqual(@as(usize, 0), sentRowKeys(92, "mp-2", &keys));
}

test "IGSH-1266 an empty thinking item does not hide the reply after it" {
    const sid = "11111111-2222-3333-4444-888888888888";
    _ = begin(96, 0, sid);
    defer release(96);
    const page = "{\"result\":{\"events\":[" ++
        "{\"seq\":1,\"event\":{\"kind\":\"turn.started\",\"turn\":\"t-1\",\"payload\":{}}}," ++
        "{\"seq\":2,\"event\":{\"kind\":\"thinking.done\",\"turn\":\"t-1\",\"item\":\"a:thinking:0\",\"payload\":{\"text\":\"\"}}}," ++
        "{\"seq\":3,\"event\":{\"kind\":\"text.delta\",\"turn\":\"t-1\",\"item\":\"a:text:0\",\"payload\":{\"text\":\"Reply\"}}}" ++
        "]}}";
    try std.testing.expect(applyPage(96, sid, page));
    var text: [64]u16 = @splat(0);
    var blocks: [4]chat_markdown.Block = undefined;
    const tail = tailFor(96, &text, 0, &blocks, &.{});
    try std.testing.expectEqual(@as(usize, 1), tail.blocks);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Reply"), text[0..tail.text_len]);
}

fn parse(a: std.mem.Allocator, json: []const u8) !std.json.Value {
    const parsed = try std.json.parseFromSlice(std.json.Value, a, json, .{});
    return parsed.value;
}
