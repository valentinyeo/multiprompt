const std = @import("std");
const render = @import("chat_render.zig");

test "IGSH-436 table build benchmark" {
    try render.benchmarkTableBuilds();
}
