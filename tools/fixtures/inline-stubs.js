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
pub fn accountReady() void {}
pub fn setAccount(_: ?[]const u8) void {}
pub fn applyAccountLayout(_: ?[]const u8, _: []const u8) bool {
    return false;
}
pub fn syncVisibility() void {}
pub fn resize(_: ?*anyopaque) void {}
pub fn dpiChanged(_: u32) void {}
pub fn leaveForSession() void {}
pub fn leaveForOtherFront() void {}
pub fn cancelRestoreForUser() void {}
pub fn restoreAfterOverlay() bool {
    return false;
}
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
  writeChatMention(dir);
}

const voice = `const std = @import("std");

pub fn voiceManualFrontChanged() void {}
pub fn voiceStopSpeaking() void {}
`;

function writeVoice(dir) {
  fs.writeFileSync(path.join(dir, "voice.zig"), voice);
}

const accountDesktop = `pub fn applyPendingAppearance(_: u32) void {}
`;

function writeAccountDesktop(dir) {
  fs.writeFileSync(path.join(dir, 'account_desktop.zig'), accountDesktop);
}

const chatMention = `pub const Chat = struct { name: []const u8 = "", session: []const u8 = "", index: u32 = 0 };
pub const Span = struct { start: usize = 0, visible_end: usize = 0, end: usize = 0 };
pub fn currentLive(_: ?u32) []const Chat {
    return &.{};
}
pub fn spanAt(_: []const u16, _: usize, _: []const Chat) ?Span {
    return null;
}
pub fn hasMarker(_: []const u16) bool {
    return false;
}
pub fn copyVisible(text: []const u16, _: []const Chat, _: []u16) []const u16 {
    return text;
}
pub fn apply(text: []const u16, _: []u16) []const u16 {
    return text;
}
pub fn clearPicks() void {}
`;

function writeChatMention(dir) {
  fs.writeFileSync(path.join(dir, 'chat_mention.zig'), chatMention);
}

function writeAll(dir) {
  writeRoomFrontend(dir);
  writeVoice(dir);
  writeAccountDesktop(dir);
  writeChatMention(dir);
}

module.exports = { roomFrontend, voice, accountDesktop, chatMention, writeRoomFrontend, writeVoice, writeAccountDesktop, writeChatMention, writeAll };
