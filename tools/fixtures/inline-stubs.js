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
pub const DeliveryKind = enum { address, fyi };
pub const Delivery = struct { chat: Chat = .{}, kind: DeliveryKind = .address };
pub fn currentLive() []const Chat {
    return &.{};
}
pub fn spanAt(_: []const u16, _: usize, _: []const Chat) ?Span {
    return null;
}
pub fn plainNameLinkAt(_: []const u16, _: usize) ?struct { start: usize, end: usize } {
    return null;
}
pub fn liveSessionForName(_: []const u16) ?[]const u8 {
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
pub fn isMentionNote(_: []const u16) bool {
    return false;
}
pub fn mentionDeliveries(_: []const u16, _: []const u8, _: []const Chat, out: []Delivery) []Delivery {
    return out[0..0];
}
pub fn mentionTargets(_: []const u16, _: []const u8, _: []const Chat, out: []Chat) []Chat {
    return out[0..0];
}
pub fn providerName(_: u8) []const u8 {
    return "";
}
pub fn revealChatNames(_: []u16, len: usize) usize {
    return len;
}
pub fn mentionNote(_: []const u8, _: []const u16, _: []const u8, _: []u16) ?[]const u16 {
    return null;
}
pub fn mentionFyiNote(_: []const u8, _: []const u16, _: []const u8, _: []u16) ?[]const u16 {
    return null;
}
pub fn composeWireText(_: []const u8, _: []const Chat, text: []const u16, _: []u16) []const u16 {
    return text;
}
pub fn trimWireNote(text: []const u16) []const u16 {
    return text;
}
pub fn mentionContextTail(_: anytype, _: []const u16, _: bool, _: []u8) ?[]const u8 {
    return null;
}
pub fn mentionDelivered(_: u64, _: []const u8) bool {
    return false;
}
pub fn mentionMarkDelivered(_: u64, _: []const u8) void {}
`;

function writeChatMention(dir) {
  fs.writeFileSync(path.join(dir, 'chat_mention.zig'), chatMention);
}

const chatInlineCode = `pub fn padX() i32 {
    return 0;
}

pub fn chipWidth(text_w: i32, pad_x: i32) i32 {
    return @max(0, text_w) + 2 * @max(0, pad_x);
}

pub fn fits(x: i32, text_w: i32, max_w: i32, pad_x: i32) bool {
    return x <= 0 or chipWidth(text_w, pad_x) <= max_w - x;
}

pub fn textColor(_: bool) u32 {
    return 0;
}

pub fn paint(_: anytype, _: anytype, _: bool) void {}
`;

function writeChatInlineCode(dir) {
  fs.writeFileSync(path.join(dir, 'chat_inline_code.zig'), chatInlineCode);
}

function writeAll(dir) {
  writeRoomFrontend(dir);
  writeVoice(dir);
  writeAccountDesktop(dir);
  writeChatMention(dir);
  writeChatInlineCode(dir);
}

module.exports = { roomFrontend, voice, accountDesktop, chatMention, chatInlineCode, writeRoomFrontend, writeVoice, writeAccountDesktop, writeChatMention, writeChatInlineCode, writeAll };
