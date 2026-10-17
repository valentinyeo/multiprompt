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

pub fn composeMessage(allocator: std.mem.Allocator, prompt: []const u8, skill: Skill) ![]u8 {
    const marker = try std.fmt.allocPrint(allocator, "/{s} ", .{skill.name});
    defer allocator.free(marker);
    const left_trimmed = std.mem.trimStart(u8, prompt, " \t\r\n");
    const without_marker = if (std.mem.startsWith(u8, left_trimmed, marker))
        std.mem.trim(u8, left_trimmed[marker.len..], " \t\r\n")
    else
        std.mem.trim(u8, prompt, " \t\r\n");
    return if (without_marker.len == 0)
        std.fmt.allocPrint(allocator, "/{s}\n\n<skill name=\"{s}\">\n{s}\n</skill>", .{ skill.name, skill.name, std.mem.trim(u8, skill.body, " \t\r\n") })
    else
        std.fmt.allocPrint(allocator, "{s}\n\n/{s}\n\n<skill name=\"{s}\">\n{s}\n</skill>", .{ without_marker, skill.name, skill.name, std.mem.trim(u8, skill.body, " \t\r\n") });
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
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
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

test "off skill overrides are excluded" {
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "{\"inactive\":\"off\",\"disabled\":false,\"active\":\"on\"}", .{});
    defer parsed.deinit();
    try std.testing.expect(isDisabled(parsed.value, "inactive"));
    try std.testing.expect(isDisabled(parsed.value, "disabled"));
    try std.testing.expect(!isDisabled(parsed.value, "active"));
}
