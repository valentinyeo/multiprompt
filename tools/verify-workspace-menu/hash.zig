const std = @import("std");

export fn registryHash(bytes: [*]const u8, len: usize) callconv(.c) u64 {
    return std.hash.Wyhash.hash(0, bytes[0..len]);
}
