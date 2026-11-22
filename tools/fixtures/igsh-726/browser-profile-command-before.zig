pub fn command(buf: []u8, original: []const u8, value: []const u8) ![]const u8 {
    if (value.len == 0) return std.fmt.bufPrint(buf, "{s}", .{original});
    if (!isToken(value) or original.len == 0 or original[0] != '"') return error.InvalidProfileCommand;
    const end = (std.mem.indexOfScalarPos(u8, original, 1, '"') orelse return error.InvalidProfileCommand) + 1;
    return std.fmt.bufPrint(buf, "{s} --profile {s}{s}", .{ original[0..end], value, original[end..] });
}
