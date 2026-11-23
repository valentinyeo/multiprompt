pub fn score(name: []const u8, desc: []const u8, query: []const u8) ?u16 {
    if (query.len == 0) return 6;
    if (std.ascii.eqlIgnoreCase(name, query)) return 0;
    if (std.ascii.startsWithIgnoreCase(name, query)) return 1;
    if (prefixAtWord(name, query, ":-_/")) return 2;
    if (std.ascii.indexOfIgnoreCase(name, query) != null) return 3;
    if (prefixAtWord(desc, query, " \t.,:;()")) return 4;
    var q: usize = 0;
    for (name) |c| {
        if (q < query.len and std.ascii.toLower(c) == std.ascii.toLower(query[q])) q += 1;
    }
    return if (q == query.len) 5 else null;
}

