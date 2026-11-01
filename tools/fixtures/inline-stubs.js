const fs = require('node:fs');
const path = require('node:path');

const roomFrontend = `const std = @import("std");

pub const enabled = false;
pub const new_room_target: ?u32 = null;
pub const edit_room_target: ?u32 = null;

pub fn privateActionsAllowed() bool {
    return true;
}

pub fn isActive() bool {
    return false;
}

pub fn init(_: std.mem.Allocator) void {}
pub fn deinit() void {}
pub fn startupSettled() void {}
pub fn accountReady(_: bool) void {}
pub fn setAccount(_: anytype) void {}
pub fn applyAccountLayout() void {}
pub fn syncVisibility() void {}
pub fn resize(_: anytype) void {}
pub fn dpiChanged(_: anytype) void {}
pub fn leaveForSession() void {}
pub fn leaveForOtherFront() void {}
pub fn cancelRestoreForUser() void {}
pub fn restoreAfterOverlay() void {}
pub fn hideForOverlay() void {}
pub fn flushUi() void {}
pub fn pollTimer() void {}
pub fn resetPaletteRooms() void {}
pub fn roomHit(_: anytype, _: anytype) ?usize {
    return null;
}
pub fn selectHit(_: anytype, _: anytype) bool {
    return false;
}
pub fn paletteRoomHit(_: anytype, _: anytype) ?usize {
    return null;
}
pub fn paletteRoomName(_: anytype) ?[]const u8 {
    return null;
}
pub fn openCreate(_: anytype) void {}
pub fn editPaletteRoom(_: anytype) void {}
`;

function writeRoomFrontend(dir) {
  fs.writeFileSync(path.join(dir, 'room_frontend.zig'), roomFrontend);
}

function writeAll(dir) {
  writeRoomFrontend(dir);
}

module.exports = { roomFrontend, writeRoomFrontend, writeAll };
