const std = @import("std");
const words = @import("ui_words.zon");

pub fn main(init: std.process.Init) !void {
    var buffer: [4096]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    const writer = &output.interface;
    try std.json.Stringify.value(words, .{ .whitespace = .indent_2 }, writer);
    try writer.writeByte('\n');
    try writer.flush();
}
