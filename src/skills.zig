const std = @import("std");

pub const Source = enum { multiprompt, harness };

pub const Skill = struct {
    name: []u8,
    description: []u8,
    body: []u8,
    source: Source,

    pub fn deinit(self: *Skill, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.description);
        allocator.free(self.body);
        self.* = undefined;
    }
};

pub const BundledSkill = struct {
    markdown: []const u8,
    source: Source,
};

pub fn stripFrontmatter(markdown: []const u8) []const u8 {
    const trimmed = std.mem.trimStart(u8, markdown, "\xef\xbb\xbf\r\n \t");
    if (!std.mem.startsWith(u8, trimmed, "---")) return markdown;
    const end = std.mem.indexOfPos(u8, trimmed, 3, "\n---") orelse return markdown;
    return std.mem.trimStart(u8, trimmed[end + 4 ..], "\r\n");
}

fn frontmatterField(markdown: []const u8, key: []const u8) ?[]const u8 {
    const trimmed = std.mem.trimStart(u8, markdown, "\xef\xbb\xbf\r\n \t");
    if (!std.mem.startsWith(u8, trimmed, "---")) return null;
    const end = std.mem.indexOfPos(u8, trimmed, 3, "\n---") orelse return null;
    var lines = std.mem.splitScalar(u8, trimmed[3..end], '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        if (!std.mem.eql(u8, std.mem.trim(u8, line[0..colon], " \t"), key)) continue;
        var value = std.mem.trim(u8, line[colon + 1 ..], " \t\r");
        if (value.len >= 2 and ((value[0] == '"' and value[value.len - 1] == '"') or
            (value[0] == '\'' and value[value.len - 1] == '\'')))
        {
            value = value[1 .. value.len - 1];
        }
        return value;
    }
    return null;
}

pub fn parseMarkdown(allocator: std.mem.Allocator, markdown: []const u8, fallback_name: []const u8, source: Source) !?Skill {
    const raw_name = frontmatterField(markdown, "name") orelse fallback_name;
    const name = std.mem.trim(u8, raw_name, " \t\r\n");
    if (name.len == 0) return null;
    const description = frontmatterField(markdown, "description") orelse "";
    const owned_name = try allocator.dupe(u8, name);
    errdefer allocator.free(owned_name);
    const owned_description = try allocator.dupe(u8, description);
    errdefer allocator.free(owned_description);
    const owned_body = try allocator.dupe(u8, std.mem.trim(u8, stripFrontmatter(markdown), " \t\r\n"));
    return .{
        .name = owned_name,
        .description = owned_description,
        .body = owned_body,
        .source = source,
    };
}

fn markerFor(name: []const u8, buf: []u8) ?[]const u8 {
    if (name.len == 0 or name.len + 1 > buf.len) return null;
    buf[0] = '/';
    @memcpy(buf[1..][0..name.len], name);
    return buf[0 .. name.len + 1];
}

fn markerIndex(text: []const u8, marker: []const u8) ?usize {
    var from: usize = 0;
    while (std.mem.indexOfPos(u8, text, from, marker)) |at| {
        const end = at + marker.len;
        const opens = at == 0 or std.ascii.isWhitespace(text[at - 1]);
        const closes = end == text.len or std.ascii.isWhitespace(text[end]);
        if (opens and closes) return at;
        from = at + 1;
    }
    return null;
}

pub fn textSkill(text: []const u8, skills: []const Skill) ?Skill {
    const trimmed = std.mem.trimStart(u8, text, " \t\r\n");
    var found: ?struct { skill: Skill, at: usize } = null;
    for (skills) |skill| {
        var buf: [129]u8 = undefined;
        const marker = markerFor(skill.name, &buf) orelse continue;
        const at = markerIndex(trimmed, marker) orelse continue;
        if (at == 0) continue;
        if (found == null or at < found.?.at) found = .{ .skill = skill, .at = at };
    }
    return if (found) |hit| hit.skill else null;
}

pub fn composeMessage(allocator: std.mem.Allocator, prompt: []const u8, skill: Skill) ![]u8 {
    var buf: [129]u8 = undefined;
    const marker = markerFor(skill.name, &buf) orelse return allocator.dupe(u8, prompt);
    const trimmed = std.mem.trim(u8, prompt, " \t\r\n");
    const at = markerIndex(trimmed, marker) orelse return allocator.dupe(u8, prompt);
    const body = std.mem.trim(u8, skill.body, " \t\r\n");
    if (at > 0) return std.fmt.allocPrint(allocator, "{s}\n\n/{s}\n\n<skill name=\"{s}\">\n{s}\n</skill>", .{ prompt, skill.name, skill.name, body });
    const without_marker = std.mem.trim(u8, trimmed[marker.len..], " \t\r\n");
    return if (without_marker.len == 0)
        std.fmt.allocPrint(allocator, "/{s}\n\n<skill name=\"{s}\">\n{s}\n</skill>", .{ skill.name, skill.name, body })
    else
        std.fmt.allocPrint(allocator, "{s}\n\n/{s}\n\n<skill name=\"{s}\">\n{s}\n</skill>", .{ without_marker, skill.name, skill.name, body });
}

fn isDisabled(overrides: ?std.json.Value, name: []const u8) bool {
    const value = overrides orelse return false;
    if (value != .object) return false;
    const found = value.object.get(name) orelse return false;
    return switch (found) {
        .bool => |enabled| !enabled,
        .string => |state| std.ascii.eqlIgnoreCase(state, "disabled") or std.ascii.eqlIgnoreCase(state, "false") or std.ascii.eqlIgnoreCase(state, "off"),
        else => false,
    };
}

fn addMarkdownSkill(
    allocator: std.mem.Allocator,
    list: *std.ArrayList(Skill),
    markdown: []const u8,
    fallback_name: []const u8,
    source: Source,
    overrides: ?std.json.Value,
) !void {
    if (list.items.len >= 512) return;
    var parsed = (try parseMarkdown(allocator, markdown, fallback_name, source)) orelse return;
    errdefer parsed.deinit(allocator);
    if (source == .harness and isDisabled(overrides, parsed.name)) {
        parsed.deinit(allocator);
        return;
    }
    for (list.items) |existing| {
        if (existing.source == parsed.source and std.ascii.eqlIgnoreCase(existing.name, parsed.name)) {
            parsed.deinit(allocator);
            return;
        }
    }
    try list.append(allocator, parsed);
}

fn readOverrides(allocator: std.mem.Allocator, io: std.Io, home: []const u8) !?std.json.Parsed(std.json.Value) {
    const path = try std.fs.path.join(allocator, &.{ home, ".claude", "settings.json" });
    defer allocator.free(path);
    const bytes = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(4 * 1024 * 1024)) catch return null;
    defer allocator.free(bytes);
    return std.json.parseFromSlice(std.json.Value, allocator, bytes, .{}) catch null;
}

fn scanRoot(
    allocator: std.mem.Allocator,
    io: std.Io,
    root_path: []const u8,
    list: *std.ArrayList(Skill),
    overrides: ?std.json.Value,
    plugin_name: []const u8,
) !void {
    var dir = std.Io.Dir.openDirAbsolute(io, root_path, .{ .iterate = true }) catch return;
    defer dir.close(io);
    var walker = try dir.walkSelectively(allocator);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        const linked_at_root = entry.kind == .sym_link and entry.depth() == 1;
        if (entry.kind == .directory or linked_at_root) {
            var target = entry;
            target.kind = .directory;
            walker.enter(io, target) catch |err| {
                if (!linked_at_root or err == error.OutOfMemory) return err;
            };
            continue;
        }
        if (entry.kind != .file or !std.ascii.eqlIgnoreCase(entry.basename, "SKILL.md")) continue;
        const bytes = entry.dir.readFileAlloc(io, entry.basename, allocator, .limited(1024 * 1024)) catch continue;
        const parent = std.fs.path.basename(std.fs.path.dirname(entry.path) orelse "");
        if (plugin_name.len != 0) {
            const name = frontmatterField(bytes, "name") orelse parent;
            const qualified = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ plugin_name, name });
            defer allocator.free(qualified);
            if (isDisabled(overrides, qualified)) {
                allocator.free(bytes);
                continue;
            }
        }
        addMarkdownSkill(allocator, list, bytes, parent, .harness, overrides) catch |err| {
            allocator.free(bytes);
            return err;
        };
        allocator.free(bytes);
    }
}

fn lessThan(_: void, a: Skill, b: Skill) bool {
    if (a.source != b.source) return a.source == .multiprompt;
    return std.ascii.lessThanIgnoreCase(a.name, b.name);
}

pub fn discover(allocator: std.mem.Allocator, io: std.Io, home: []const u8, bundled: []const BundledSkill) ![]Skill {
    var list: std.ArrayList(Skill) = .empty;
    errdefer {
        for (list.items) |*skill| skill.deinit(allocator);
        list.deinit(allocator);
    }
    for (bundled) |item| try addMarkdownSkill(allocator, &list, item.markdown, "", item.source, null);

    var parsed_settings = try readOverrides(allocator, io, home);
    defer if (parsed_settings) |*parsed| parsed.deinit();
    const overrides = if (parsed_settings) |parsed|
        if (parsed.value == .object) parsed.value.object.get("skillOverrides") else null
    else
        null;

    const user_skills = try std.fs.path.join(allocator, &.{ home, ".claude", "skills" });
    defer allocator.free(user_skills);
    try scanRoot(allocator, io, user_skills, &list, overrides, "");
    const installed_path = try std.fs.path.join(allocator, &.{ home, ".claude", "plugins", "installed_plugins.json" });
    defer allocator.free(installed_path);
    if (std.Io.Dir.cwd().readFileAlloc(io, installed_path, allocator, .limited(4 * 1024 * 1024)) catch null) |bytes| {
        defer allocator.free(bytes);
        if (std.json.parseFromSlice(std.json.Value, allocator, bytes, .{}) catch null) |parsed_value| {
            var parsed = parsed_value;
            defer parsed.deinit();
            const enabled = if (parsed_settings) |settings|
                if (settings.value == .object) settings.value.object.get("enabledPlugins") else null
            else
                null;
            const plugins = if (parsed.value == .object) parsed.value.object.get("plugins") orelse parsed.value else parsed.value;
            if (plugins == .object and enabled != null and enabled.? == .object) {
                var it = plugins.object.iterator();
                while (it.next()) |plugin| {
                    const flag = enabled.?.object.get(plugin.key_ptr.*) orelse continue;
                    if (flag != .bool or !flag.bool) continue;
                    const records = plugin.value_ptr.*;
                    const installed: []const std.json.Value = if (records == .array) records.array.items else if (records == .object) &.{records} else continue;
                    if (installed.len == 0) continue;
                    const record = installed[installed.len - 1];
                    if (record != .object) continue;
                    if (record.object.get("scope")) |scope| {
                        if (scope == .string and !std.mem.eql(u8, scope.string, "user")) continue;
                    }
                    const path = record.object.get("installPath") orelse continue;
                    if (path != .string) continue;
                    const root = try std.fs.path.join(allocator, &.{ path.string, "skills" });
                    defer allocator.free(root);
                    var dir = std.Io.Dir.openDirAbsolute(io, root, .{}) catch continue;
                    dir.close(io);
                    const key = plugin.key_ptr.*;
                    try scanRoot(allocator, io, root, &list, overrides, key[0 .. std.mem.indexOfScalar(u8, key, '@') orelse key.len]);
                }
            }
        }
    }

    std.mem.sort(Skill, list.items, {}, lessThan);
    return list.toOwnedSlice(allocator);
}

pub fn deinitAll(allocator: std.mem.Allocator, items: []Skill) void {
    for (items) |*skill| skill.deinit(allocator);
    allocator.free(items);
}

test "frontmatter is stripped and parsed" {
    const md = "---\nname: unslop\ndescription: Cut AI tells.\n---\n\n# Unslop\n\nBody.";
    var skill = (try parseMarkdown(std.testing.allocator, md, "fallback", .multiprompt)).?;
    defer skill.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("unslop", skill.name);
    try std.testing.expectEqualStrings("Cut AI tells.", skill.description);
    try std.testing.expectEqualStrings("# Unslop\n\nBody.", skill.body);
}

test "message injection matches Android byte for byte" {
    var skill = Skill{
        .name = try std.testing.allocator.dupe(u8, "unslop"),
        .description = try std.testing.allocator.dupe(u8, "desc"),
        .body = try std.testing.allocator.dupe(u8, "body of unslop"),
        .source = .multiprompt,
    };
    defer skill.deinit(std.testing.allocator);
    const message = try composeMessage(std.testing.allocator, "/unslop fix the login bug", skill);
    defer std.testing.allocator.free(message);
    try std.testing.expectEqualStrings("fix the login bug\n\n/unslop\n\n<skill name=\"unslop\">\nbody of unslop\n</skill>", message);
}

test "skill-only sends match Android" {
    var skill = Skill{
        .name = try std.testing.allocator.dupe(u8, "i-have-adhd"),
        .description = try std.testing.allocator.dupe(u8, "desc"),
        .body = try std.testing.allocator.dupe(u8, "body of i-have-adhd"),
        .source = .multiprompt,
    };
    defer skill.deinit(std.testing.allocator);
    const message = try composeMessage(std.testing.allocator, "/i-have-adhd ", skill);
    defer std.testing.allocator.free(message);
    try std.testing.expectEqualStrings("/i-have-adhd\n\n<skill name=\"i-have-adhd\">\nbody of i-have-adhd\n</skill>", message);
}

test "MUBO-491 a skill typed mid-sentence starts and keeps every word" {
    const a = std.testing.allocator;
    const skill = Skill{ .name = @constCast("valentin-mode"), .description = @constCast(""), .body = @constCast("mode instructions"), .source = .multiprompt };
    const typed = "why is this not done via /valentin-mode ?";
    const sent = try composeMessage(a, typed, skill);
    defer a.free(sent);
    try std.testing.expectEqualStrings("why is this not done via /valentin-mode ?\n\n/valentin-mode\n\n<skill name=\"valentin-mode\">\nmode instructions\n</skill>", sent);
}

test "MUBO-491 a skill word that is not the skill stays plain text" {
    const a = std.testing.allocator;
    const skill = Skill{ .name = @constCast("valentin-mode"), .description = @constCast(""), .body = @constCast("mode instructions"), .source = .multiprompt };
    for ([_][]const u8{ "see https://x.test/valentin-mode", "/valentin-mode/path and /valentin-modex", "no skill here", "/tmp/notes.txt says hello" }) |text| {
        const sent = try composeMessage(a, text, skill);
        defer a.free(sent);
        try std.testing.expectEqualStrings(text, sent);
    }
}

test "MUBO-491 a selected skill anywhere in a message runs and keeps the typed words" {
    const a = std.testing.allocator;
    const skill = Skill{ .name = @constCast("review"), .description = @constCast(""), .body = @constCast("review instructions"), .source = .multiprompt };
    for ([_][]const u8{ "/review/path", "/reviewer" }) |text| {
        const message = try composeMessage(a, text, skill);
        defer a.free(message);
        try std.testing.expectEqualStrings(text, message);
    }
    for ([_][]const u8{ "why /review ?", "why\n/review" }) |text| {
        const message = try composeMessage(a, text, skill);
        defer a.free(message);
        const expected = try std.fmt.allocPrint(a, "{s}\n\n/review\n\n<skill name=\"review\">\nreview instructions\n</skill>", .{text});
        defer a.free(expected);
        try std.testing.expectEqualStrings(expected, message);
    }
    const message = try composeMessage(a, "/review check this", skill);
    defer a.free(message);
    try std.testing.expectEqualStrings("check this\n\n/review\n\n<skill name=\"review\">\nreview instructions\n</skill>", message);
    const only = try composeMessage(a, "/review", skill);
    defer a.free(only);
    try std.testing.expectEqualStrings("/review\n\n<skill name=\"review\">\nreview instructions\n</skill>", only);
    const indented = try composeMessage(a, " /review", skill);
    defer a.free(indented);
    try std.testing.expectEqualStrings("/review\n\n<skill name=\"review\">\nreview instructions\n</skill>", indented);
}

test "MUBO-491 the skill catalog finds the skill a message names mid-sentence" {
    const skills = [_]Skill{
        .{ .name = @constCast("ship"), .description = @constCast(""), .body = @constCast("ship body"), .source = .multiprompt },
        .{ .name = @constCast("valentin-mode"), .description = @constCast(""), .body = @constCast("mode body"), .source = .multiprompt },
    };
    try std.testing.expectEqualStrings("valentin-mode", textSkill("why is this not done via /valentin-mode ?", &skills).?.name);
    try std.testing.expectEqualStrings("ship", textSkill("then /ship it", &skills).?.name);
    for ([_][]const u8{ "/ship it", " /ship it", "see https://x.test/ship", "/ships and /ship/path", "nothing to run" }) |text| {
        try std.testing.expect(textSkill(text, &skills) == null);
    }
}

test "SOFT-2476 linked skill folders are discovered but nested links stay unvisited" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, ".claude/skills/ordinary");
    try tmp.dir.createDirPath(io, "installed/nested");
    try tmp.dir.createDirPath(io, "hidden");
    try tmp.dir.writeFile(io, .{ .sub_path = ".claude/skills/ordinary/SKILL.md", .data = "Ordinary skill." });
    try tmp.dir.writeFile(io, .{ .sub_path = "installed/SKILL.md", .data = "---\ndescription: Linked skill.\n---\nLinked instructions." });
    try tmp.dir.writeFile(io, .{ .sub_path = "hidden/SKILL.md", .data = "Hidden instructions." });
    tmp.dir.symLink(io, "../../installed", ".claude/skills/valentin-mode", .{ .is_directory = true }) catch |err| switch (err) {
        error.AccessDenied, error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    try tmp.dir.symLink(io, "../hidden", "installed/hidden-link", .{ .is_directory = true });
    try tmp.dir.symLink(io, "..", "installed/nested/loop", .{ .is_directory = true });
    try tmp.dir.symLink(io, "../../../hidden", ".claude/skills/ordinary/hidden-link", .{ .is_directory = true });
    try tmp.dir.symLink(io, "missing", ".claude/skills/broken", .{ .is_directory = true });
    try tmp.dir.symLink(io, "self-loop", ".claude/skills/self-loop", .{ .is_directory = true });
    const home = try tmp.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(home);
    const items = try discover(allocator, io, home, &.{});
    defer deinitAll(allocator, items);
    try std.testing.expectEqual(@as(usize, 2), items.len);
    try std.testing.expectEqualStrings("ordinary", items[0].name);
    try std.testing.expectEqualStrings("valentin-mode", items[1].name);
    try std.testing.expectEqualStrings("Linked skill.", items[1].description);
    try std.testing.expectEqualStrings("Linked instructions.", items[1].body);
    try std.testing.expectEqual(Source.harness, items[1].source);
    try tmp.dir.writeFile(io, .{ .sub_path = ".claude/settings.json", .data = "{\"skillOverrides\":{\"valentin-mode\":false}}" });
    const enabled = try discover(allocator, io, home, &.{});
    defer deinitAll(allocator, enabled);
    try std.testing.expectEqual(@as(usize, 1), enabled.len);
    try std.testing.expectEqualStrings("ordinary", enabled[0].name);
}

test "SOFT-2476 linked plugin skill folders keep names and qualified overrides" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, "skills");
    try tmp.dir.createDirPath(io, "installed");
    try tmp.dir.writeFile(io, .{ .sub_path = "installed/SKILL.md", .data = "---\nname: review\n---\nReview instructions." });
    tmp.dir.symLink(io, "../installed", "skills/linked-review", .{ .is_directory = true }) catch |err| switch (err) {
        error.AccessDenied, error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    const root = try tmp.dir.realPathFileAlloc(io, "skills", allocator);
    defer allocator.free(root);
    var items: std.ArrayList(Skill) = .empty;
    defer {
        for (items.items) |*skill| skill.deinit(allocator);
        items.deinit(allocator);
    }
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, "{\"example:review\":false}", .{});
    defer parsed.deinit();
    try scanRoot(allocator, io, root, &items, parsed.value, "example");
    try std.testing.expectEqual(@as(usize, 0), items.items.len);
    try scanRoot(allocator, io, root, &items, null, "example");
    try std.testing.expectEqual(@as(usize, 1), items.items.len);
    try std.testing.expectEqualStrings("review", items.items[0].name);
}

test "off skill overrides are excluded" {
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "{\"inactive\":\"off\",\"disabled\":false,\"active\":\"on\"}", .{});
    defer parsed.deinit();
    try std.testing.expect(isDisabled(parsed.value, "inactive"));
    try std.testing.expect(isDisabled(parsed.value, "disabled"));
    try std.testing.expect(!isDisabled(parsed.value, "active"));
}
