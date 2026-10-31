const w = @import("win32.zig");
const room_view = @import("room_view.zig");

pub const enabled = false;

const empty_model = room_view.ViewModel{
    .room_id = "",
    .name = &.{},
    .revision = 0,
    .members = &.{},
    .candidates = &.{},
    .messages = &.{},
};

var view: room_view.View = undefined;
var created = false;
var context: u8 = 0;

fn createRoom(_: *anyopaque, _: room_view.ActionToken, _: []const u16, _: []const []const u8) room_view.ActionResult {
    return .unsupported;
}

fn editRoom(_: *anyopaque, _: room_view.ActionToken, _: []const u8, _: u64, _: []const u16, _: []const []const u8) room_view.ActionResult {
    return .unsupported;
}

fn submit(_: *anyopaque, _: room_view.ActionToken, _: []const u8, _: u64, _: []const u16) room_view.ActionResult {
    return .unsupported;
}

fn restart(_: *anyopaque, _: room_view.ActionToken, _: []const u8, _: []const u8) room_view.ActionResult {
    return .unsupported;
}

pub fn init(parent: w.HANDLE) void {
    if (!enabled or created) return;
    created = view.create(parent, &empty_model, .{ .context = &context, .create = createRoom, .edit = editRoom, .submit = submit, .restart = restart });
}

pub fn resize(parent: w.HANDLE) void {
    if (!enabled or !created) return;
    var client: w.RECT = undefined;
    if (w.GetClientRect(parent, &client) == 0) return;
    view.setBounds(@import("window_layout.zig").activePaneContentRect(client));
}

pub fn dpiChanged(dpi: u32) void {
    if (!enabled or !created) return;
    _ = view.setDpi(dpi);
}

pub fn deinit() void {
    if (!created) return;
    view.destroy();
    created = false;
}
