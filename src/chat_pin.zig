const std = @import("std");
const app_state = @import("app_state.zig");
const file_io = @import("file_io.zig");
const win32 = @import("win32.zig");

pub const MAX_NAME = 80;
pub const MAX_CHAT = 96;
pub const MAX_ENTRIES = 128;
pub const NOTE_CAP = 800;
const FILE_CAP = MAX_ENTRIES * (MAX_CHAT + MAX_NAME + 2) + 64;
const HEADER = "# multiprompt pinned skills v1\n";

pub const Entry = struct {
    chat: [MAX_CHAT]u8 = @splat(0),
    chat_len: u8 = 0,
    skill: [MAX_NAME]u8 = @splat(0),
    skill_len: u8 = 0,
};

pub const Pins = struct {
    entries: [MAX_ENTRIES]Entry = @splat(.{}),
    count: u16 = 0,
};

pub const Capture = struct { name_len: usize = 0, note_len: usize = 0 };

pub var g_pins: Pins = .{};
pub var g_pins_loaded: bool = false;

pub fn chatKey(host: u8, session: []const u8, out: *[MAX_CHAT]u8) ?[]const u8 {
    if (session.len == 0 or session.len + 2 > out.len) return null;
    out[0] = '0' + @as(u8, host % 10);
    out[1] = ':';
    for (session, 0..) |c, i| {
        if (c < 0x20 or c == 0x7f or c == ':' or c == '\t') return null;
        out[2 + i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
    }
    return out[0 .. 2 + session.len];
}

pub fn validSkill(name: []const u8) bool {
    if (name.len == 0 or name.len > MAX_NAME) return false;
    for (name) |c| {
        if ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or
            c == '_' or c == '.' or c == ':' or c == '-') continue;
        return false;
    }
    return true;
}

pub fn find(pins: *const Pins, chat: []const u8) ?[]const u8 {
    for (pins.entries[0..pins.count]) |entry| {
        if (std.mem.eql(u8, entry.chat[0..entry.chat_len], chat)) return entry.skill[0..entry.skill_len];
    }
    return null;
}

pub fn setPin(pins: *Pins, chat: []const u8, skill: []const u8) bool {
    if (!validSkill(skill) or chat.len == 0 or chat.len > MAX_CHAT) return false;
    for (pins.entries[0..pins.count]) |*entry| {
        if (!std.mem.eql(u8, entry.chat[0..entry.chat_len], chat)) continue;
        if (std.mem.eql(u8, entry.skill[0..entry.skill_len], skill)) return false;
        @memset(entry.skill[0..], 0);
        @memcpy(entry.skill[0..skill.len], skill);
        entry.skill_len = @intCast(skill.len);
        return true;
    }
    if (pins.count >= MAX_ENTRIES) return false;
    const entry = &pins.entries[pins.count];
    @memcpy(entry.chat[0..chat.len], chat);
    entry.chat_len = @intCast(chat.len);
    @memcpy(entry.skill[0..skill.len], skill);
    entry.skill_len = @intCast(skill.len);
    pins.count += 1;
    return true;
}

pub fn clearPin(pins: *Pins, chat: []const u8) bool {
    var i: usize = 0;
    while (i < pins.count) : (i += 1) {
        if (!std.mem.eql(u8, pins.entries[i].chat[0..pins.entries[i].chat_len], chat)) continue;
        var j = i;
        while (j + 1 < pins.count) : (j += 1) pins.entries[j] = pins.entries[j + 1];
        pins.entries[pins.count - 1] = .{};
        pins.count -= 1;
        return true;
    }
    return false;
}

pub fn serialize(pins: *const Pins, out: []u8) []const u8 {
    if (out.len < HEADER.len) return out[0..0];
    @memcpy(out[0..HEADER.len], HEADER);
    var pos: usize = HEADER.len;
    for (pins.entries[0..pins.count]) |entry| {
        const chat = entry.chat[0..entry.chat_len];
        const skill = entry.skill[0..entry.skill_len];
        if (pos + chat.len + skill.len + 2 > out.len) break;
        @memcpy(out[pos .. pos + chat.len], chat);
        pos += chat.len;
        out[pos] = '\t';
        pos += 1;
        @memcpy(out[pos .. pos + skill.len], skill);
        pos += skill.len;
        out[pos] = '\n';
        pos += 1;
    }
    return out[0..pos];
}

pub fn parse(pins: *Pins, text: []const u8) void {
    pins.* = .{};
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trimRight(u8, raw, "\r");
        if (line.len == 0 or line[0] == '#') continue;
        const tab = std.mem.indexOfScalar(u8, line, '\t') orelse continue;
        if (tab == 0 or tab > MAX_CHAT) continue;
        _ = setPin(pins, line[0..tab], line[tab + 1 ..]);
    }
}

fn pinsPath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = win32.GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 490) return null;
    const rest = "\\ZigShell\\chat-pins.txt";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

pub fn loadPins() *const Pins {
    if (g_pins_loaded) return &g_pins;
    g_pins_loaded = true;
    g_pins = .{};
    var path_buf: [512]u8 = undefined;
    const path = pinsPath(&path_buf) orelse return &g_pins;
    const bytes = file_io.readFileAllocWin32(path, FILE_CAP) orelse return &g_pins;
    defer std.heap.page_allocator.free(bytes);
    parse(&g_pins, bytes);
    return &g_pins;
}

pub fn reloadPins() *const Pins {
    g_pins_loaded = false;
    return loadPins();
}

fn savePins() bool {
    var path_buf: [512]u8 = undefined;
    const path = pinsPath(&path_buf) orelse return false;
    var text_buf: [FILE_CAP]u8 = undefined;
    const text = serialize(&g_pins, &text_buf);
    return file_io.writeFileAtomicW(path, text);
}

fn shellChatKey(idx: u32, out: *[MAX_CHAT]u8) ?[]const u8 {
    if (idx >= app_state.shell_count) return null;
    const shell = &app_state.shells[idx];
    if (shell.tmux_session_len == 0) return null;
    return chatKey(shell.tmux_host, shell.tmux_session[0..shell.tmux_session_len], out);
}

pub fn pinned(idx: u32) ?[]const u8 {
    var key_buf: [MAX_CHAT]u8 = undefined;
    const key = shellChatKey(idx, &key_buf) orelse return null;
    return find(loadPins(), key);
}

pub fn setForShell(idx: u32, skill: ?[]const u8) bool {
    var key_buf: [MAX_CHAT]u8 = undefined;
    const key = shellChatKey(idx, &key_buf) orelse return false;
    _ = loadPins();
    const changed = if (skill) |name| setPin(&g_pins, key, name) else clearPin(&g_pins, key);
    if (!changed) return true;
    return savePins();
}

fn skillNote(name: []const u8, out: []u8) []const u8 {
    for (app_state.g_palette_skills) |skill| {
        if (!std.mem.eql(u8, skill.name, name)) continue;
        var len = @min(skill.body.len, out.len);
        while (len > 0 and len < skill.body.len and (skill.body[len] & 0xC0) == 0x80) len -= 1;
        @memcpy(out[0..len], skill.body[0..len]);
        return out[0..len];
    }
    return out[0..0];
}

pub fn captureInto(idx: u32, name_buf: []u8, note_buf: []u8) Capture {
    const name = pinned(idx) orelse return .{};
    const len = @min(name.len, name_buf.len);
    if (len == 0) return .{};
    @memcpy(name_buf[0..len], name[0..len]);
    const note = skillNote(name[0..len], note_buf);
    return .{ .name_len = len, .note_len = note.len };
}

fn labelContains(label: []const u8, query: []const u16) bool {
    if (query.len == 0) return true;
    if (query.len > label.len) return false;
    const limit = label.len - query.len + 1;
    for (0..limit) |start| {
        var ok = true;
        for (query, 0..) |qc, i| {
            const raw: u8 = if (qc < 128) @intCast(qc) else 0;
            const a: u8 = if (raw >= 'A' and raw <= 'Z') raw + 32 else raw;
            const c = label[start + i];
            const b: u8 = if (c >= 'A' and c <= 'Z') c + 32 else c;
            if (a != b) {
                ok = false;
                break;
            }
        }
        if (ok) return true;
    }
    return false;
}

const Row = struct { target: usize, label: []const u8 };

const rows = [_]Row{
    .{ .target = app_state.SEARCH_TABCTX_PIN_SKILL, .label = "Pin a skill to this chat" },
    .{ .target = app_state.SEARCH_TABCTX_UNPIN_SKILL, .label = "Unpin the skill this chat keeps" },
};

pub fn paletteText(target: usize) ?[]const u8 {
    for (rows) |row| {
        if (row.target != target) continue;
        if (target == app_state.SEARCH_TABCTX_PIN_SKILL) return "pin a skill to this chat keep it on every message without retyping";
        return "unpin the skill this chat keeps on every message";
    }
    return null;
}

pub fn label(target: usize) ?[]const u8 {
    const words = @import("ui_words.zon");
    if (target == app_state.SEARCH_TABCTX_PIN_SKILL) return words.tab_context_pin_skill;
    if (target == app_state.SEARCH_TABCTX_UNPIN_SKILL) return words.tab_context_unpin_skill;
    return null;
}

pub fn isAction(target: usize) bool {
    return target == app_state.SEARCH_TABCTX_PIN_SKILL or target == app_state.SEARCH_TABCTX_UNPIN_SKILL;
}

var g_pins_refresh_tick: u64 = 0;

fn refreshPinsOnce() void {
    const now = win32.GetTickCount64();
    if (g_pins_refresh_tick != 0 and now > g_pins_refresh_tick and now - g_pins_refresh_tick < 1000) return;
    g_pins_refresh_tick = now;
    _ = reloadPins();
}

pub fn appendTabContextRows(tc_idx: ?u32) void {
    const ti = tc_idx orelse return;
    refreshPinsOnce();
    const query = app_state.g_search_buf[0..app_state.g_search_len];
    const is_pinned = pinned(ti) != null;
    for (rows, 0..) |row, i| {
        if (i == 1 and !is_pinned) continue;
        if (app_state.g_search_result_count >= app_state.g_search_results.len) return;
        if (!labelContains(row.label, query)) continue;
        app_state.g_search_results[app_state.g_search_result_count] = row.target;
        app_state.g_search_result_count += 1;
    }
}

fn closePaletteForPin() void {
    app_state.g_search_active = false;
    app_state.g_search_tabctx_mode = false;
    app_state.g_search_skills_mode = false;
    app_state.g_search_pin_skill_mode = false;
    app_state.g_tabctx_sid = 0;
    app_state.g_shell_focused = true;
    @import("rename.zig").clearSearchBackdrop();
    @import("rename.zig").showActiveShellAfterOverlay();
    @import("window_layout.zig").invalidateSidebar();
    _ = win32.InvalidateRect(app_state.g_main_hwnd, null, 0);
}

pub fn handleAction(target: usize) bool {
    if (target == app_state.SEARCH_TABCTX_UNPIN_SKILL) {
        if (@import("inbox.zig").findShellById(app_state.g_tabctx_sid)) |ti| _ = setForShell(ti, null);
        closePaletteForPin();
        return true;
    }
    if (target == app_state.SEARCH_TABCTX_PIN_SKILL) {
        if (!@import("chat_composer.zig").loadPaletteSkills()) return true;
        app_state.g_search_pin_skill_mode = true;
        app_state.g_search_skills_mode = true;
        app_state.g_search_len = 0;
        app_state.g_search_sel = 1;
        app_state.g_search_scroll = 0;
        @import("command_palette.zig").updateSearchResults();
        _ = win32.InvalidateRect(app_state.g_main_hwnd, null, 0);
        return true;
    }
    return false;
}

pub fn consumePick(name: []const u8) bool {
    if (!app_state.g_search_pin_skill_mode) return false;
    const ti = @import("inbox.zig").findShellById(app_state.g_tabctx_sid);
    if (ti) |idx| _ = setForShell(idx, name);
    closePaletteForPin();
    return true;
}

test "MUBO-245 a pinned chat keeps one skill and pinning twice changes nothing" {
    var pins: Pins = .{};
    try std.testing.expect(setPin(&pins, "0:live-a", "pospeak"));
    try std.testing.expect(!setPin(&pins, "0:live-a", "pospeak"));
    try std.testing.expectEqualStrings("pospeak", find(&pins, "0:live-a").?);
    try std.testing.expect(find(&pins, "0:live-b") == null);
    try std.testing.expect(setPin(&pins, "0:live-a", "canary"));
    try std.testing.expectEqualStrings("canary", find(&pins, "0:live-a").?);
}

test "MUBO-245 unpin drops the chat and leaves every other chat alone" {
    var pins: Pins = .{};
    _ = setPin(&pins, "0:live-a", "pospeak");
    _ = setPin(&pins, "1:live-b", "canary");
    try std.testing.expect(clearPin(&pins, "0:live-a"));
    try std.testing.expect(!clearPin(&pins, "0:live-a"));
    try std.testing.expect(find(&pins, "0:live-a") == null);
    try std.testing.expectEqualStrings("canary", find(&pins, "1:live-b").?);
}

test "MUBO-245 the pin file round trips and rejects junk" {
    var pins: Pins = .{};
    _ = setPin(&pins, "0:live-a", "pospeak");
    _ = setPin(&pins, "1:Other-Chat", "canary");
    try std.testing.expect(!setPin(&pins, "0:live-a", "two words"));
    try std.testing.expect(!validSkill(""));
    try std.testing.expect(validSkill("pospeak"));
    var text_buf: [FILE_CAP]u8 = undefined;
    const text = serialize(&pins, &text_buf);
    var reloaded: Pins = .{};
    parse(&reloaded, text);
    try std.testing.expectEqualStrings("pospeak", find(&reloaded, "0:live-a").?);
    try std.testing.expectEqualStrings("canary", find(&reloaded, "1:Other-Chat").?);
}

test "MUBO-245 chat keys are host scoped and lowercase" {
    var buf: [MAX_CHAT]u8 = undefined;
    try std.testing.expectEqualStrings("1:live-a", chatKey(1, "Live-A", &buf).?);
    try std.testing.expect(chatKey(0, "", &buf) == null);
    try std.testing.expect(chatKey(0, "bad:name", &buf) == null);
}

test "MUBO-245 pin palette rows follow the pinned state" {
    var pins: Pins = .{};
    _ = setPin(&pins, "0:live-a", "pospeak");
    try std.testing.expect(find(&pins, "0:live-a") != null);
    try std.testing.expect(paletteText(app_state.SEARCH_TABCTX_PIN_SKILL) != null);
    try std.testing.expect(paletteText(app_state.SEARCH_TABCTX_UNPIN_SKILL) != null);
    try std.testing.expect(paletteText(app_state.SEARCH_TABCTX_MUTE) == null);
}
