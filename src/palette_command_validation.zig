const std = @import("std");

pub fn customCmdHasQuote(s: []const u8) bool {
    for (s) |c| {
        if (c == '\'' or c == '"') return true;
    }
    return false;
}

pub fn altTProgramSafe(program: []const u8) bool {
    if (program.len == 0 or program.len >= 127) return false;
    for (program) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != ' ' and c != '-' and c != '_' and c != '.' and c != '/' and c != '=') return false;
    }
    return true;
}

