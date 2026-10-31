const std = @import("std");
const transport = @import("room_transport.zig");
const room_view = @import("room_view.zig");

const allocator = std.heap.page_allocator;

pub const Member = struct {
    alias: []const u8,
    display_name: []const u8,
    host_uuid: []const u8,
    provider: []const u8,
    provider_sid: []const u8,
    session_identity: []const u8,
};

pub const RequestKind = enum { capabilities, catalog, snapshot, events, create, edit, status };
pub const Result = struct {
    kind: RequestKind,
    value: std.json.Parsed(std.json.Value),

    pub fn deinit(self: *Result) void {
        self.value.deinit();
    }
};

pub const Failure = struct {
    kind: RequestKind,
    reason: enum { transport, timeout, cancelled, parse, remote },
    code: [64]u8 = @splat(0),
    code_len: usize = 0,
    outcome_unknown: bool = false,
};
pub const Completion = union(enum) {
    pending,
    failed: Failure,
    finished: Result,
};

pub const Controller = struct {
    host: u8,
    route: ?transport.Route = null,
    account_digest: [64]u8 = undefined,
    has_account: bool = false,
    host_uuid: [36]u8 = undefined,
    has_host_uuid: bool = false,
    job: ?*transport.Job = null,
    kind: RequestKind = .capabilities,

    pub fn init(host: u8) Controller {
        return .{ .host = host };
    }

    pub fn bindRoute(self: *Controller, hostname: []const u8, user: []const u8, port: u16) bool {
        if (self.route != null or self.job != null) return false;
        self.route = transport.Route.init(hostname, user, port, self.host) orelse return false;
        return true;
    }

    pub fn bindAccount(self: *Controller, account: []const u8) bool {
        if (account.len == 0 or account.len > 256) return false;
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(account, &digest, .{});
        const hex = std.fmt.bytesToHex(digest, .lower);
        if (self.has_account) return std.mem.eql(u8, &self.account_digest, &hex);
        self.account_digest = hex;
        self.has_account = true;
        return true;
    }

    pub fn bindHost(self: *Controller, expected: []const u8) bool {
        if (expected.len != self.host_uuid.len) return false;
        if (self.has_host_uuid) return std.mem.eql(u8, &self.host_uuid, expected);
        for (expected, 0..) |c, i| {
            if (i == 8 or i == 13 or i == 18 or i == 23) {
                if (c != '-') return false;
            } else if (!((c >= '0' and c <= '9') or (c >= 'a' and c <= 'f'))) return false;
        }
        @memcpy(&self.host_uuid, expected);
        self.has_host_uuid = true;
        return true;
    }

    fn launch(self: *Controller, kind: RequestKind, value: anytype) bool {
        if (!self.has_account or self.job != null) return false;
        const route = self.route orelse return false;
        const request = std.json.Stringify.valueAlloc(allocator, value, .{}) catch return false;
        const output = allocator.alloc(u8, 262145) catch {
            allocator.free(request);
            return false;
        };
        const job = allocator.create(transport.Job) catch {
            allocator.free(output);
            allocator.free(request);
            return false;
        };
        job.* = .{ .route = route, .account_digest = self.account_digest, .request = request, .output = output };
        if (!transport.start(job)) {
            allocator.destroy(job);
            allocator.free(output);
            allocator.free(request);
            return false;
        }
        self.kind = kind;
        self.job = job;
        return true;
    }

    pub fn capabilities(self: *Controller) bool {
        return self.launch(.capabilities, .{ .op = "capabilities" });
    }

    pub fn catalog(self: *Controller, after: u64, through: ?u64) bool {
        if (!self.has_host_uuid) return false;
        return self.launch(.catalog, .{ .op = "list", .host_uuid = self.host_uuid[0..], .after = after, .through = through, .limit = 100 });
    }

    pub fn snapshot(self: *Controller, room_id: []const u8) bool {
        if (!self.has_host_uuid) return false;
        return self.launch(.snapshot, .{ .op = "snapshot", .host_uuid = self.host_uuid[0..], .room_id = room_id });
    }

    pub fn events(self: *Controller, room_id: []const u8, after: u64) bool {
        if (!self.has_host_uuid) return false;
        return self.launch(.events, .{ .op = "events", .host_uuid = self.host_uuid[0..], .room_id = room_id, .after = after, .limit = 100 });
    }

    pub fn status(self: *Controller, sid: []const u8) bool {
        if (!self.has_host_uuid) return false;
        return self.launch(.status, .{ .op = "status", .host_uuid = self.host_uuid[0..], .sid = sid });
    }

    pub fn create(self: *Controller, command_id: []const u8, name: []const u8, members: []const Member) bool {
        if (!self.has_host_uuid) return false;
        return self.launch(.create, .{ .op = "create", .host_uuid = self.host_uuid[0..], .command_id = command_id, .name = name, .members = members });
    }

    pub fn edit(self: *Controller, command_id: []const u8, room_id: []const u8, revision: u64, members: []const Member) bool {
        if (!self.has_host_uuid) return false;
        return self.launch(.edit, .{ .op = "edit_members", .host_uuid = self.host_uuid[0..], .command_id = command_id, .room_id = room_id, .expected_revision = revision, .members = members });
    }

    pub fn submit(_: *Controller) room_view.ActionResult {
        return .unsupported;
    }

    pub fn restart(_: *Controller) room_view.ActionResult {
        return .unsupported;
    }

    pub fn shutdown(self: *Controller) void {
        const job = self.job orelse return;
        job.cancelled.store(true, .release);
        if (job.thread) |thread| thread.join();
        allocator.free(job.request);
        allocator.free(job.output);
        allocator.destroy(job);
        self.job = null;
    }

    pub fn poll(self: *Controller) ?Completion {
        const job = self.job orelse return null;
        if (!job.finished.load(.acquire)) return .pending;
        if (job.thread) |thread| thread.join();
        defer {
            allocator.free(job.request);
            allocator.free(job.output);
            allocator.destroy(job);
            self.job = null;
        }
        const mutation = self.kind == .create or self.kind == .edit;
        if (!job.success) return .{ .failed = .{ .kind = self.kind, .reason = if (job.cancelled.load(.acquire)) .cancelled else if (job.timed_out) .timeout else .transport, .outcome_unknown = mutation } };
        var parsed = std.json.parseFromSlice(std.json.Value, allocator, job.output[0..job.output_len], .{ .allocate = .alloc_always }) catch return .{ .failed = .{ .kind = self.kind, .reason = .parse, .outcome_unknown = mutation } };
        if (parsed.value != .object) {
            parsed.deinit();
            return .{ .failed = .{ .kind = self.kind, .reason = .parse, .outcome_unknown = mutation } };
        }
        const ok = parsed.value.object.get("ok") orelse {
            parsed.deinit();
            return .{ .failed = .{ .kind = self.kind, .reason = .parse, .outcome_unknown = mutation } };
        };
        if (ok == .bool and !ok.bool) {
            var failure = Failure{ .kind = self.kind, .reason = .remote };
            if (parsed.value.object.get("error")) |code| {
                if (code == .string and code.string.len <= failure.code.len) {
                    failure.code_len = code.string.len;
                    @memcpy(failure.code[0..failure.code_len], code.string);
                }
            }
            parsed.deinit();
            if (failure.code_len == 0) return .{ .failed = .{ .kind = self.kind, .reason = .parse, .outcome_unknown = mutation } };
            return .{ .failed = failure };
        }
        if (ok != .bool or parsed.value.object.get("result") == null) {
            parsed.deinit();
            return .{ .failed = .{ .kind = self.kind, .reason = .parse, .outcome_unknown = mutation } };
        }
        return .{ .finished = .{ .kind = self.kind, .value = parsed } };
    }
};

test "room controller pins remote UUID before catalog operations" {
    var controller = Controller.init(0);
    try std.testing.expect(!controller.has_host_uuid);
    try std.testing.expect(!controller.bindHost("invalid"));
    try std.testing.expect(controller.bindHost("10000000-0000-4000-8000-000000000001"));
    try std.testing.expectEqualStrings("10000000-0000-4000-8000-000000000001", &controller.host_uuid);
    try std.testing.expect(!controller.bindHost("20000000-0000-4000-8000-000000000002"));
    try std.testing.expectEqual(room_view.ActionResult.unsupported, controller.submit());
    try std.testing.expectEqual(room_view.ActionResult.unsupported, controller.restart());
}
