const std = @import("std");
const win = @import("win32.zig");

pub var peer_check: *const fn (win.SOCKET) bool = peerIsSameUser;

pub fn peerIsSameUser(_: win.SOCKET) bool {
    return true;
}
