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

pub const Controller = struct {
    host: u8,
    host_uuid: [36]u8 = undefined,
    has_host_uuid: bool = false,
    job: ?*transport.Job = null,
    kind: RequestKind = .capabilities,

    pub fn init(host: u8) Controller {
        return .{ .host = host };
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
        if (self.job != null) return false;
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
        job.* = .{ .host = self.host, .request = request, .output = output };
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

    pub fn poll(self: *Controller) ?Result {
        const job = self.job orelse return null;
        if (!job.finished.load(.acquire)) return null;
        defer {
            allocator.free(job.request);
            allocator.free(job.output);
            allocator.destroy(job);
            self.job = null;
        }
        if (!job.success) return null;
        const parsed = std.json.parseFromSlice(std.json.Value, allocator, job.output[0..job.output_len], .{ .allocate = .alloc_always }) catch return null;
        return .{ .kind = self.kind, .value = parsed };
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
