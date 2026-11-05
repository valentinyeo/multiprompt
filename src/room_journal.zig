const std = @import("std");
const w = @import("win32.zig");
const file_io = @import("file_io.zig");

const allocator = std.heap.page_allocator;
const max_file = 2 * 1024 * 1024;
const max_request = 131071;
const max_evidence = 262144;

pub const Kind = enum { create, edit, post };
pub const State = enum { prepared, uncertain, accepted, rejected };
pub const Scope = struct { account_digest: [64]u8, store_uuid: [36]u8 };
pub const Binding = @import("room_message.zig").Binding;
pub const Record = struct {
    account_digest: []const u8,
    store_uuid: []const u8,
    kind: Kind,
    command_id: []const u8,
    room_id: []const u8,
    revision: u64,
    request: []const u8,
    bindings: []const Binding,
    state: State,
    evidence: []const u8,
};
const Envelope = struct { record: Record, checksum: []const u8 };
pub const Entry = struct {
    parsed: std.json.Parsed(Envelope),
    pub fn record(self: *const Entry) *const Record { return &self.parsed.value.record; }
    pub fn deinit(self: *Entry) void { self.parsed.deinit(); }
};

fn uuidValid(value: []const u8) bool {
    if (value.len != 36) return false;
    for (value, 0..) |ch, i| {
        if (i == 8 or i == 13 or i == 18 or i == 23) {
            if (ch != '-') return false;
        } else if (!((ch >= '0' and ch <= '9') or (ch >= 'a' and ch <= 'f'))) return false;
    }
    return true;
}

pub fn newCommandId() ?[36]u8 {
    var bytes: [16]u8 = undefined;
    if (w.BCryptGenRandom(null, &bytes, bytes.len, 2) < 0) return null;
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    const hex = std.fmt.bytesToHex(bytes, .lower);
    var id: [36]u8 = undefined;
    @memcpy(id[0..8], hex[0..8]); id[8] = '-';
    @memcpy(id[9..13], hex[8..12]); id[13] = '-';
    @memcpy(id[14..18], hex[12..16]); id[18] = '-';
    @memcpy(id[19..23], hex[16..20]); id[23] = '-';
    @memcpy(id[24..36], hex[20..32]);
    return id;
}

fn validScope(scope: Scope) bool {
    if (!uuidValid(&scope.store_uuid)) return false;
    for (scope.account_digest) |ch| if (!((ch >= '0' and ch <= '9') or (ch >= 'a' and ch <= 'f'))) return false;
    return true;
}

pub const Lock = struct {
    handle: w.HANDLE,
    scope: Scope,
    pub fn deinit(self: *Lock) void { _ = w.ReleaseMutex(self.handle); _ = w.CloseHandle(self.handle); }
};

pub fn lock(scope: Scope) !Lock {
    if (!validScope(scope)) return error.InvalidScope;
    var name_buf: [160]u8 = undefined;
    const name = std.fmt.bufPrint(&name_buf, "Local\\MultipromptRoomCommand-{s}-{s}", .{ &scope.account_digest, &scope.store_uuid }) catch return error.InvalidScope;
    var wide_buf: [160]u16 = undefined;
    const wide = file_io.win32WidePath(&wide_buf, name) orelse return error.InvalidScope;
    const handle = w.CreateMutexW(null, 0, wide.ptr);
    if (handle == null) return error.LockFailed;
    const result = w.WaitForSingleObject(handle, 0);
    if (result != 0 and result != 0x80) { _ = w.CloseHandle(handle); return error.JournalBusy; }
    return .{ .handle = handle, .scope = scope };
}

fn pathFor(scope: Scope, buf: []u8) ![]const u8 {
    if (!validScope(scope)) return error.InvalidScope;
    var dir_buf: [512]u8 = undefined;
    const dir = @import("session.zig").getSessionDir(&dir_buf) orelse return error.InvalidPath;
    return std.fmt.bufPrint(buf, "{s}\\room-command-{s}-{s}.json", .{ dir, &scope.account_digest, &scope.store_uuid }) catch error.InvalidPath;
}

fn field(value: std.json.Value, name: []const u8) ?std.json.Value {
    if (value != .object) return null;
    return value.object.get(name);
}
fn text(value: std.json.Value, name: []const u8) ?[]const u8 {
    const result = field(value, name) orelse return null;
    return if (result == .string) result.string else null;
}
fn number(value: std.json.Value, name: []const u8) ?u64 {
    const result = field(value, name) orelse return null;
    if (result != .integer or result.integer < 0) return null;
    return @intCast(result.integer);
}
fn validText(value: []const u8, limit: usize) bool {
    return value.len > 0 and value.len <= limit and std.unicode.utf8ValidateSlice(value) and std.mem.indexOfScalar(u8, value, 0) == null;
}
fn validMember(member: std.json.Value, store: []const u8) bool {
    if (member != .object or member.object.count() != 6) return false;
    const alias = text(member, "alias") orelse return false;
    const name = text(member, "display_name") orelse return false;
    const host = text(member, "host_uuid") orelse return false;
    const provider = text(member, "provider") orelse return false;
    const sid = text(member, "provider_sid") orelse return false;
    const identity = text(member, "session_identity") orelse return false;
    if (alias.len == 0 or alias.len > 32 or alias[0] < 'a' or alias[0] > 'z' or !validText(name, 256) or !validText(sid, 512) or !validText(identity, 512) or !std.mem.eql(u8, host, store)) return false;
    for (alias) |ch| if (!(ch >= 'a' and ch <= 'z') and !(ch >= '0' and ch <= '9') and ch != '_' and ch != '-') return false;
    if (!std.mem.eql(u8, provider, "claude") and !std.mem.eql(u8, provider, "codex")) return false;
    return identity.len == provider.len + 1 + sid.len and std.mem.startsWith(u8, identity, provider) and identity[provider.len] == ':' and std.mem.eql(u8, identity[provider.len + 1 ..], sid);
}

fn validateRequest(r: Record) bool {
    if (!uuidValid(r.command_id) or r.request.len == 0 or r.request.len > max_request or std.mem.indexOfScalar(u8, r.request, '\n') != null or !std.unicode.utf8ValidateSlice(r.request)) return false;
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, r.request, .{ .allocate = .alloc_always }) catch return false;
    defer parsed.deinit();
    const obj = parsed.value;
    if (obj != .object or obj.object.count() != (if (r.kind == .create) @as(usize, 5) else 7)) return false;
    const op = text(obj, "op") orelse return false;
    const command = text(obj, "command_id") orelse return false;
    const host = text(obj, "host_uuid") orelse return false;
    if (r.kind == .post) {
        if (!std.mem.eql(u8, op, "post_human") or !std.mem.eql(u8, command, r.command_id) or !std.mem.eql(u8, host, r.store_uuid) or !uuidValid(r.room_id) or r.revision == 0 or !std.mem.eql(u8, text(obj, "room_id") orelse return false, r.room_id) or (number(obj, "expected_revision") orelse 0) != r.revision) return false;
        for (r.bindings, 0..) |binding, i| {
            if (!uuidValid(binding.id) or binding.alias.len == 0 or binding.alias.len > 32) return false;
            for (r.bindings[0..i]) |old| if (std.mem.eql(u8, old.id, binding.id) or std.mem.eql(u8, old.alias, binding.alias)) return false;
        }
        const plan = @import("room_message.zig").plan(text(obj, "text") orelse return false, r.bindings) catch return false;
        const recipients = field(obj, "recipients") orelse return false;
        if (recipients != .array or recipients.array.items.len != plan.alias_count) return false;
        for (recipients.array.items, 0..) |recipient, i| {
            if (recipient != .string) return false;
            for (recipients.array.items[0..i]) |old| if (std.mem.eql(u8, old.string, recipient.string)) return false;
            var found = false;
            for (plan.recipients()) |alias| if (std.mem.eql(u8, alias, recipient.string)) {
                found = true;
                break;
            };
            if (!found) return false;
        }
        return true;
    }
    const name = text(obj, "name") orelse return false;
    if (!std.mem.eql(u8, op, if (r.kind == .create) "create" else "edit") or !std.mem.eql(u8, command, r.command_id) or !std.mem.eql(u8, host, r.store_uuid) or !validText(name, 256)) return false;
    if (r.kind == .create) {
        if (r.room_id.len != 0 or r.revision != 0) return false;
    } else {
        if (!uuidValid(r.room_id) or r.revision == 0 or !std.mem.eql(u8, text(obj, "room_id") orelse return false, r.room_id) or (number(obj, "expected_revision") orelse 0) != r.revision) return false;
    }
    const members = field(obj, "members") orelse return false;
    if (members != .array or members.array.items.len > 64) return false;
    for (members.array.items, 0..) |member, i| {
        if (!validMember(member, r.store_uuid)) return false;
        for (members.array.items[0..i]) |old| {
            if (std.mem.eql(u8, text(old, "alias").?, text(member, "alias").?) or (std.mem.eql(u8, text(old, "provider").?, text(member, "provider").?) and std.mem.eql(u8, text(old, "provider_sid").?, text(member, "provider_sid").?))) return false;
        }
    }
    if (r.bindings.len > members.array.items.len or (r.kind == .create and r.bindings.len != 0)) return false;
    for (r.bindings, 0..) |binding, i| {
        if (!uuidValid(binding.id)) return false;
        for (r.bindings[0..i]) |old| if (std.mem.eql(u8, old.id, binding.id) or std.mem.eql(u8, old.alias, binding.alias)) return false;
        var found = false;
        for (members.array.items) |member| if (std.mem.eql(u8, text(member, "alias") orelse return false, binding.alias)) { found = true; break; };
        if (!found) return false;
    }
    return true;
}

fn validateEvidence(r: Record) bool {
    if (r.state == .prepared or r.state == .uncertain) return r.evidence.len == 0;
    if (r.evidence.len == 0 or r.evidence.len > max_evidence) return false;
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, r.evidence, .{ .allocate = .alloc_always }) catch return false;
    defer parsed.deinit();
    const obj = parsed.value;
    if (obj != .object) return false;
    if (r.state == .rejected) {
        if (obj.object.count() != 1) return false;
        const code = text(obj, "error") orelse return false;
        for ([_][]const u8{ "invalid_fields", "invalid_id", "invalid_text", "invalid_number", "invalid_members", "invalid_alias", "invalid_provider", "duplicate_member", "binding_immutable", "room_not_found", "revision_conflict", "unsupported_provider", "unsupported_remote_capability", "invalid_session", "host_disabled", "runtime_unavailable", "request_too_large", "invalid_json", "unknown_op", "invalid_recipients", "invalid_mentions", "runtime_unsupported" }) |known| if (std.mem.eql(u8, code, known)) return true;
        return false;
    }
    const event = field(obj, "event") orelse return false;
    const deliveries = field(obj, "deliveries") orelse return false;
    if (r.kind == .post) {
        if (obj.object.count() != 2 or event != .object or event.object.count() != 7 or deliveries != .array) return false;
        const event_id = text(event, "id") orelse return false;
        const seq = number(event, "seq") orelse return false;
        if (!uuidValid(event_id) or seq == 0 or !std.mem.eql(u8, text(event, "room_id") orelse return false, r.room_id) or !std.mem.eql(u8, text(event, "type") orelse return false, "human") or (number(event, "revision") orelse 0) != r.revision) return false;
        var request = std.json.parseFromSlice(std.json.Value, allocator, r.request, .{ .allocate = .alloc_always }) catch return false;
        defer request.deinit();
        const message = text(request.value, "text") orelse return false;
        if (!std.mem.eql(u8, text(event, "text") orelse return false, message)) return false;
        const plan = @import("room_message.zig").plan(message, r.bindings) catch return false;
        const recipients = field(event, "recipients") orelse return false;
        if (recipients != .array or recipients.array.items.len != plan.target_count or deliveries.array.items.len != plan.target_count) return false;
        for (plan.targets[0..plan.target_count]) |target| {
            var recipient_count: usize = 0;
            var delivery_count: usize = 0;
            for (recipients.array.items) |recipient| {
                if (recipient != .string) return false;
                if (std.mem.eql(u8, recipient.string, target)) recipient_count += 1;
            }
            for (deliveries.array.items) |delivery| {
                if (!uuidValid(text(delivery, "id") orelse return false) or !std.mem.eql(u8, text(delivery, "room_id") orelse return false, r.room_id) or !std.mem.eql(u8, text(delivery, "event_id") orelse return false, event_id) or (number(delivery, "event_seq") orelse 0) != seq or (number(delivery, "delivery_seq") orelse 0) == 0) return false;
                if (std.mem.eql(u8, text(delivery, "member_id") orelse return false, target)) delivery_count += 1;
            }
            if (recipient_count != 1 or delivery_count != 1) return false;
        }
        return true;
    }
    if (obj.object.count() != 2 or event != .object or event.object.count() != 7 or deliveries != .array or deliveries.array.items.len != 0) return false;
    const event_id = text(event, "id") orelse return false;
    const room = text(event, "room_id") orelse return false;
    const kind = text(event, "type") orelse return false;
    const event_name = text(event, "name") orelse return false;
    if (!uuidValid(event_id) or !uuidValid(room) or !std.mem.eql(u8, kind, if (r.kind == .create) "created" else "room_edited") or (number(event, "seq") orelse 0) == 0) return false;
    if (r.kind == .create) {
        if ((number(event, "revision") orelse 0) != 1 or (number(event, "seq") orelse 0) != 1) return false;
    } else if (!std.mem.eql(u8, room, r.room_id) or r.revision == std.math.maxInt(u64) or (number(event, "revision") orelse 0) != r.revision + 1) return false;
    var request = std.json.parseFromSlice(std.json.Value, allocator, r.request, .{ .allocate = .alloc_always }) catch return false;
    defer request.deinit();
    if (!std.mem.eql(u8, event_name, text(request.value, "name") orelse return false)) return false;
    const actual = field(event, "members") orelse return false;
    const wanted = field(request.value, "members") orelse return false;
    if (actual != .array or wanted != .array or actual.array.items.len != wanted.array.items.len) return false;
    for (r.bindings) |binding| {
        var found = false;
        for (actual.array.items) |member| if (std.mem.eql(u8, text(member, "alias") orelse return false, binding.alias)) {
            if (!std.mem.eql(u8, text(member, "id") orelse return false, binding.id)) return false;
            found = true;
            break;
        };
        if (!found) return false;
    }
    for (actual.array.items, 0..) |member, i| {
        if (member != .object or member.object.count() != 7 or !uuidValid(text(member, "id") orelse return false)) return false;
        for (actual.array.items[0..i]) |old| if (std.mem.eql(u8, text(old, "id") orelse return false, text(member, "id").?) or std.mem.eql(u8, text(old, "alias") orelse return false, text(member, "alias") orelse return false)) return false;
        var found = false;
        for (wanted.array.items) |candidate| {
            var equal = true;
            for ([_][]const u8{ "alias", "display_name", "host_uuid", "provider", "provider_sid", "session_identity" }) |key| {
                if (!std.mem.eql(u8, text(member, key) orelse return false, text(candidate, key) orelse return false)) { equal = false; break; }
            }
            if (equal) { found = true; break; }
        }
        if (!found) return false;
    }
    return true;
}

fn checksum(record: Record) ![64]u8 {
    const bytes = try std.json.Stringify.valueAlloc(allocator, record, .{});
    defer allocator.free(bytes);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.bytesToHex(digest, .lower);
}

fn validate(scope: Scope, envelope: Envelope) bool {
    const r = envelope.record;
    if (!validScope(scope) or !std.mem.eql(u8, r.account_digest, &scope.account_digest) or !std.mem.eql(u8, r.store_uuid, &scope.store_uuid) or !validateRequest(r) or !validateEvidence(r)) return false;
    const expected = checksum(r) catch return false;
    return std.mem.eql(u8, envelope.checksum, &expected);
}

pub fn load(scope: Scope) !?Entry {
    var path_buf: [700]u8 = undefined;
    const path = try pathFor(scope, &path_buf);
    var wide_buf: [800]u16 = undefined;
    const wide_path = file_io.win32WidePath(&wide_buf, path) orelse return error.InvalidPath;
    const h = w.CreateFileW(wide_path.ptr, w.GENERIC_READ, w.FILE_SHARE_READ, null, w.OPEN_EXISTING, w.FILE_ATTRIBUTE_NORMAL, null);
    if (h == w.INVALID_HANDLE_VALUE_PTR) {
        if (w.GetLastError() == 2) return null;
        return error.ReadFailed;
    }
    defer _ = w.CloseHandle(h);
    const buffer = try allocator.alloc(u8, max_file + 1);
    defer allocator.free(buffer);
    var used: usize = 0;
    while (used < buffer.len) {
        var count: w.DWORD = 0;
        if (w.ReadFile(h, buffer[used..].ptr, @intCast(buffer.len - used), &count, null) == 0) return error.ReadFailed;
        if (count == 0) break;
        used += count;
    }
    if (used == 0 or used > max_file) return error.InvalidJournal;
    var parsed = std.json.parseFromSlice(Envelope, allocator, buffer[0..used], .{ .allocate = .alloc_always }) catch return error.InvalidJournal;
    if (!validate(scope, parsed.value)) { parsed.deinit(); return error.InvalidJournal; }
    return Entry{ .parsed = parsed };
}

fn persist(scope: Scope, record: Record) !void {
    const digest = try checksum(record);
    const envelope = Envelope{ .record = record, .checksum = &digest };
    if (!validate(scope, envelope)) return error.InvalidJournal;
    const bytes = try std.json.Stringify.valueAlloc(allocator, envelope, .{});
    defer allocator.free(bytes);
    if (bytes.len > max_file) return error.InvalidJournal;
    var path_buf: [700]u8 = undefined;
    const path = try pathFor(scope, &path_buf);
    var path_wide: [800]u16 = undefined;
    const path_w = file_io.win32WidePath(&path_wide, path) orelse return error.InvalidPath;
    const nonce = newCommandId() orelse return error.RandomFailed;
    var temp_buf: [760]u8 = undefined;
    const temp = std.fmt.bufPrint(&temp_buf, "{s}.{s}.tmp", .{ path, &nonce }) catch return error.InvalidPath;
    var temp_wide: [860]u16 = undefined;
    const temp_w = file_io.win32WidePath(&temp_wide, temp) orelse return error.InvalidPath;
    const h = w.CreateFileW(temp_w.ptr, w.GENERIC_WRITE, 0, null, 1, w.FILE_ATTRIBUTE_NORMAL, null);
    if (h == w.INVALID_HANDLE_VALUE_PTR) return error.WriteFailed;
    defer _ = w.DeleteFileW(temp_w.ptr);
    var written: w.DWORD = 0;
    const written_ok = w.WriteFile(h, bytes.ptr, @intCast(bytes.len), &written, null) != 0 and written == bytes.len;
    const flushed = if (written_ok) w.FlushFileBuffers(h) != 0 else false;
    const closed = w.CloseHandle(h) != 0;
    if (!written_ok or !flushed or !closed) return error.WriteFailed;
    if (w.MoveFileExW(temp_w.ptr, path_w.ptr, 1 | 8) == 0) return error.WriteFailed;
}

pub fn prepare(scope: Scope, kind: Kind, command_id: []const u8, room_id: []const u8, revision: u64, request: []const u8, bindings: []const Binding) !void {
    var guard = try lock(scope);
    defer guard.deinit();
    if (try load(scope)) |loaded| {
        var old = loaded;
        defer old.deinit();
        const r = old.record();
        if (r.state == .prepared or r.state == .uncertain) {
            if (r.kind == kind and r.revision == revision and std.mem.eql(u8, r.command_id, command_id) and std.mem.eql(u8, r.room_id, room_id) and std.mem.eql(u8, r.request, request) and r.bindings.len == bindings.len) {
                var equal = true;
                for (r.bindings, bindings) |old_binding, binding| if (!std.mem.eql(u8, old_binding.alias, binding.alias) or !std.mem.eql(u8, old_binding.id, binding.id)) { equal = false; break; };
                if (equal) return;
            }
            return error.UnresolvedCommand;
        }
        if (std.mem.eql(u8, r.command_id, command_id)) return error.ReusedCommandId;
    }
    try persist(scope, .{ .account_digest = &scope.account_digest, .store_uuid = &scope.store_uuid, .kind = kind, .command_id = command_id, .room_id = room_id, .revision = revision, .request = request, .bindings = bindings, .state = .prepared, .evidence = "" });
}

pub fn update(scope: Scope, command_id: []const u8, state: State, evidence: []const u8) !void {
    var guard = try lock(scope);
    defer guard.deinit();
    return updateLocked(&guard, command_id, state, evidence);
}

pub fn updateLocked(guard: *const Lock, command_id: []const u8, state: State, evidence: []const u8) !void {
    const scope = guard.scope;
    var entry = (try load(scope)) orelse return error.NotFound;
    defer entry.deinit();
    var record = entry.record().*;
    if (!std.mem.eql(u8, record.command_id, command_id)) return error.WrongCommand;
    if (record.state == .accepted or record.state == .rejected) {
        if (record.state == state and std.mem.eql(u8, record.evidence, evidence)) return;
        return error.TerminalCommand;
    }
    if (state == .prepared) return error.InvalidTransition;
    record.state = state;
    record.evidence = evidence;
    try persist(scope, record);
}

test "room post journal fences requests and receipts to their room and mentioned members" {
    const a = std.testing.allocator;
    const host = "10000000-0000-4000-8000-000000000001";
    const room = "20000000-0000-4000-8000-000000000002";
    const command = "30000000-0000-4000-8000-000000000003";
    const alpha = "40000000-0000-4000-8000-000000000004";
    const beta = "50000000-0000-4000-8000-000000000005";
    const event = "60000000-0000-4000-8000-000000000006";
    const delivery = "70000000-0000-4000-8000-000000000007";
    const bindings = [_]Binding{ .{ .alias = "alpha", .id = alpha }, .{ .alias = "beta", .id = beta } };
    const request = try std.json.Stringify.valueAlloc(a, .{ .op = "post_human", .host_uuid = host, .command_id = command, .room_id = room, .expected_revision = 3, .text = "@alpha reply", .recipients = [_][]const u8{"alpha"} }, .{});
    defer a.free(request);
    var record = Record{ .account_digest = "", .store_uuid = host, .kind = .post, .command_id = command, .room_id = room, .revision = 3, .request = request, .bindings = &bindings, .state = .prepared, .evidence = "" };
    try std.testing.expect(validateRequest(record));
    try std.testing.expect(validateEvidence(record));
    record.state = .accepted;
    for ([_][]const u8{ alpha, beta }) |target| {
        const evidence = try std.json.Stringify.valueAlloc(a, .{
            .event = .{ .id = event, .room_id = room, .seq = 4, .type = "human", .text = "@alpha reply", .revision = 3, .recipients = [_][]const u8{target} },
            .deliveries = .{.{ .id = delivery, .room_id = room, .event_id = event, .event_seq = 4, .member_id = target, .status = "pending", .delivery_seq = 1 }},
        }, .{});
        defer a.free(evidence);
        record.evidence = evidence;
        try std.testing.expectEqual(std.mem.eql(u8, target, alpha), validateEvidence(record));
        if (std.mem.eql(u8, target, alpha)) {
            record.room_id = host;
            try std.testing.expect(!validateRequest(record));
            try std.testing.expect(!validateEvidence(record));
            record.room_id = room;
            record.revision = 2;
            try std.testing.expect(!validateRequest(record));
            try std.testing.expect(!validateEvidence(record));
            record.revision = 3;
        }
    }
}
