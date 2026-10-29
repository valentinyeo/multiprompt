const app_state = @import("app_state.zig");
const std = @import("std");
const json_reader = @import("json_reader.zig");
const IS_DEV = @import("main.zig").IS_DEV;
const LOOK_UNIFIED = @import("main.zig").LOOK_UNIFIED;
const BOOL = @import("win32.zig").BOOL;
const DWORD = @import("win32.zig").DWORD;
const HANDLE = @import("win32.zig").HANDLE;
const LPCWSTR = @import("win32.zig").LPCWSTR;
const TIMER_SYSTEM_THEME = @import("win32.zig").TIMER_SYSTEM_THEME;
const powerModeForTimers = @import("power.zig").powerModeForTimers;
const setCoalescableTimerInterval = @import("power.zig").setCoalescableTimerInterval;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const CloseHandle = @import("win32.zig").CloseHandle;
const DwmSetWindowAttribute = @import("win32.zig").DwmSetWindowAttribute;
const RegOpenCurrentUser = @import("win32.zig").RegOpenCurrentUser;
const RegGetValueW = @import("win32.zig").RegGetValueW;
const RegCloseKey = @import("win32.zig").RegCloseKey;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const ShellExecuteW = @import("win32.zig").ShellExecuteW;
const L = @import("startup.zig").L;
const tokens = @import("design_tokens.zig");
const RGB = @import("startup.zig").RGB;
const DevTheme = @import("app_state.zig").DevTheme;
const DEFAULT_DEV_THEME_JSON = @import("app_state.zig").DEFAULT_DEV_THEME_JSON;
const getSessionDir = @import("session.zig").getSessionDir;
const win32WidePath = @import("file_io.zig").win32WidePath;
const win32OpenRead = @import("file_io.zig").win32OpenRead;
const win32OpenWrite = @import("file_io.zig").win32OpenWrite;
const win32WriteAll = @import("file_io.zig").win32WriteAll;
const win32ReadAll = @import("file_io.zig").win32ReadAll;
const win32MakeDir = @import("file_io.zig").win32MakeDir;
const applyConsoleThemeToAllShells = @import("console.zig").applyConsoleThemeToAllShells;
const syncEdgeProfileTheme = @import("browser_pane.zig").syncEdgeProfileTheme;
const refreshBrowserEdgeMasks = @import("browser_pane.zig").refreshBrowserEdgeMasks;
const repositionActive = @import("window_layout.zig").repositionActive;
const resetFontCache = @import("drawing.zig").resetFontCache;
const KillTimer = @import("win32.zig").KillTimer;

pub fn setWideAscii(out: *[64]u16, value: []const u8) void {
    out.* = std.mem.zeroes([64]u16);
    const n = @min(value.len, out.len - 1);
    for (0..n) |i| {
        const c = value[i];
        out[i] = if (c >= 32 and c < 127) @intCast(c) else '?';
    }
}

pub const Choice = enum { system, dark, mid, light, amoled, edge_gray, multiprompt };

pub fn choose(choice: Choice) void {
    app_state.g_system_theme = choice == .system;
    app_state.g_dev_theme_active = false;
    app_state.g_multiprompt_theme = choice == .multiprompt;
    if (app_state.g_system_theme) {
        resolveSystemThemeFlags();
    } else {
        app_state.g_light_theme = choice == .light;
        app_state.g_mid_theme = choice == .mid;
        app_state.g_edge_gray_theme = choice == .edge_gray;
        app_state.g_amoled_theme = choice == .amoled;
    }
    resetFontCache();
    applyTitleBarTheme();
    applyConsoleThemeToAllShells();
    repositionActive();
    refreshBrowserEdgeMasks();
    if (choice == .multiprompt) @import("clipboard.zig").startSpinnerTimerIfNeeded();
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    saveGlobalTheme();
}

fn resetDevThemeDefaults() void {
    app_state.g_dev_theme = std.mem.zeroes(DevTheme);
    setWideAscii(&app_state.g_dev_theme.title_font, @import("fonts.zig").UI_FACE);
    setWideAscii(&app_state.g_dev_theme.subtitle_font, @import("fonts.zig").UI_FACE);
    setWideAscii(&app_state.g_dev_theme.close_font, @import("fonts.zig").UI_FACE);
    setWideAscii(&app_state.g_dev_theme.console_font, app_state.DEFAULT_CONSOLE_FONT);
    app_state.g_dev_theme.title_height = 16;
    app_state.g_dev_theme.subtitle_height = 14;
    app_state.g_dev_theme.close_height = 14;
    app_state.g_dev_theme.title_weight = 400;
    app_state.g_dev_theme.subtitle_weight = 400;
    app_state.g_dev_theme.close_weight = 400;
    app_state.g_dev_theme.console_font_height = 18;
    app_state.g_dev_theme.console_font_weight = @import("fonts.zig").SHELL_WEIGHT;
    app_state.g_dev_theme.sidebar_bg = RGB(3, 8, 14);
    app_state.g_dev_theme.shell_bg = RGB(3, 8, 14);
    app_state.g_dev_theme.titlebar_bg = RGB(3, 8, 14);
    app_state.g_dev_theme.border_bg = RGB(56, 72, 94);
    app_state.g_dev_theme.active_tab_bg = RGB(3, 8, 14);
    app_state.g_dev_theme.header_bg = RGB(6, 13, 22);
    app_state.g_dev_theme.overlay_bg = RGB(3, 8, 14);
    app_state.g_dev_theme.overlay_input_bg = RGB(3, 8, 14);
    app_state.g_dev_theme.overlay_border = RGB(17, 36, 55);
    app_state.g_dev_theme.overlay_divider = RGB(12, 26, 42);
    app_state.g_dev_theme.selected_bg = RGB(18, 50, 78);
    app_state.g_dev_theme.text = RGB(218, 228, 237);
    app_state.g_dev_theme.text_inactive = RGB(184, 199, 213);
    app_state.g_dev_theme.subtitle = RGB(122, 143, 162);
    app_state.g_dev_theme.muted = RGB(91, 111, 130);
    app_state.g_dev_theme.hint = RGB(68, 86, 104);
    app_state.g_dev_theme.accent = RGB(58, 92, 125);
    app_state.g_dev_theme.attention = RGB(66, 110, 145);
    app_state.g_dev_theme.spinner = RGB(93, 122, 150);
    app_state.g_dev_theme.tag_tmux = RGB(119, 146, 169);
    app_state.g_dev_theme.tag_tmux_active = RGB(175, 196, 212);
    app_state.g_dev_theme.tag_vps = RGB(119, 146, 169);
    app_state.g_dev_theme.tag_vps_active = RGB(175, 196, 212);
    app_state.g_dev_theme.tag_neutral = RGB(109, 133, 154);
    app_state.g_dev_theme.tag_neutral_active = RGB(165, 185, 201);
    app_state.g_dev_theme.console_fg = RGB(255, 255, 255);
    app_state.g_dev_theme.console_palette = [_]DWORD{
        RGB(3, 8, 14),
        RGB(24, 44, 61),
        RGB(27, 51, 71),
        RGB(32, 59, 82),
        RGB(40, 76, 104),
        RGB(49, 91, 122),
        RGB(59, 109, 144),
        RGB(218, 228, 237),
        RGB(66, 84, 102),
        RGB(36, 63, 85),
        RGB(43, 74, 98),
        RGB(53, 89, 114),
        RGB(69, 111, 138),
        RGB(91, 131, 157),
        RGB(120, 154, 175),
        RGB(238, 243, 247),
    };
    app_state.g_dev_theme.shadow_outer = RGB(0, 2, 6);
    app_state.g_dev_theme.shadow_mid = RGB(1, 5, 10);
    app_state.g_dev_theme.shadow_inner = RGB(2, 8, 14);
    app_state.g_dev_theme.scrollbar_track = RGB(8, 18, 30);
    app_state.g_dev_theme.scrollbar_thumb = RGB(32, 59, 82);
    app_state.g_dev_theme_initialized = true;
}

pub fn ensureDevThemeInitialized() void {
    if (!app_state.g_dev_theme_initialized) resetDevThemeDefaults();
}

pub fn devThemeOn() bool {
    return IS_DEV and app_state.g_dev_theme_active;
}

fn globalThemePath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 470) return null;
    const rest = "\\ZigShell\\theme-mode.txt";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

fn sidebarStatusCardPath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 470) return null;
    const rest = "\\ZigShell\\sidebar-status-card.txt";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

pub fn saveSidebarStatusCard() void {
    var pb: [512]u8 = undefined;
    const path = sidebarStatusCardPath(&pb) orelse return;
    const h = win32OpenWrite(path) orelse return;
    defer _ = CloseHandle(h);
    const token: []const u8 = switch (app_state.g_sidebar_status_card) {
        1 => "1",
        2 => "2",
        else => "0",
    };
    win32WriteAll(h, token);
}

pub fn loadSidebarStatusCard() void {
    var pb: [512]u8 = undefined;
    const path = sidebarStatusCardPath(&pb) orelse return;
    const h = win32OpenRead(path) orelse return;
    defer _ = CloseHandle(h);
    var buf: [8]u8 = undefined;
    const raw = buf[0..win32ReadAll(h, &buf)];
    const token = std.mem.trim(u8, raw, " \t\r\n");
    if (token.len != 1) return;
    app_state.g_sidebar_status_card = switch (token[0]) {
        '0' => 0,
        '1' => 1,
        '2' => 2,
        else => 0,
    };
}

pub fn currentThemeToken() []const u8 {
    return if (app_state.g_multiprompt_theme) "multiprompt" else if (devThemeOn()) "devblue" else if (app_state.g_amoled_theme) "amoled" else if (app_state.g_edge_gray_theme) "edgegray" else if (app_state.g_light_theme) "light" else if (app_state.g_mid_theme) "mid" else "dark";
}

fn windowsAppsUseLightTheme() bool {
    var current_user: HANDLE = null;
    const KEY_QUERY_VALUE: DWORD = 0x0001;
    if (RegOpenCurrentUser(KEY_QUERY_VALUE, &current_user) != 0 or current_user == null) return true;
    defer _ = RegCloseKey(current_user);

    var value: DWORD = 1;
    var value_size: DWORD = @sizeOf(DWORD);
    const status = RegGetValueW(
        current_user,
        L("Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize"),
        L("AppsUseLightTheme"),
        0,
        null,
        &value,
        &value_size,
    );
    return status != 0 or value != 0;
}

pub fn resolveSystemThemeFlags() void {
    app_state.g_light_theme = windowsAppsUseLightTheme();
    app_state.g_mid_theme = false;
    app_state.g_edge_gray_theme = false;
    app_state.g_amoled_theme = false;
    app_state.g_dev_theme_active = false;
    app_state.g_multiprompt_theme = false;
}

fn themePreferenceToken() []const u8 {
    return if (app_state.g_system_theme) "system" else currentThemeToken();
}

pub fn syncSystemThemeTimer(hwnd: HANDLE) void {
    if (hwnd == null) return;
    if (!app_state.g_system_theme) {
        _ = KillTimer(hwnd, TIMER_SYSTEM_THEME);
        return;
    }
    switch (powerModeForTimers()) {
        .normal => setCoalescableTimerInterval(hwnd, TIMER_SYSTEM_THEME, 1000),
        .saving => setCoalescableTimerInterval(hwnd, TIMER_SYSTEM_THEME, 10_000),
        .deep_idle => _ = KillTimer(hwnd, TIMER_SYSTEM_THEME),
    }
}

pub fn refreshSystemTheme(hwnd: HANDLE) void {
    if (!app_state.g_system_theme) return;
    const light = windowsAppsUseLightTheme();
    if (app_state.g_light_theme == light and !app_state.g_mid_theme and !app_state.g_edge_gray_theme and !app_state.g_amoled_theme and !app_state.g_dev_theme_active and !app_state.g_multiprompt_theme) return;
    resolveSystemThemeFlags();
    resetFontCache();
    applyTitleBarTheme();
    applyConsoleThemeToAllShells();
    repositionActive();
    refreshBrowserEdgeMasks();
    _ = InvalidateRect(hwnd, null, 0);
    syncEdgeProfileTheme();
}

pub fn saveGlobalTheme() void {
    defer syncEdgeProfileTheme();
    syncSystemThemeTimer(app_state.g_main_hwnd);
    var pb: [512]u8 = undefined;
    const path = globalThemePath(&pb) orelse return;
    const tok = themePreferenceToken();
    const h = win32OpenWrite(path) orelse return;
    defer _ = CloseHandle(h);
    win32WriteAll(h, tok);
}

pub fn loadGlobalTheme() void {
    defer syncSystemThemeTimer(app_state.g_main_hwnd);
    var pb: [512]u8 = undefined;
    const path = globalThemePath(&pb) orelse return;
    const h = win32OpenRead(path) orelse return;
    var buf: [64]u8 = undefined;
    const n = win32ReadAll(h, &buf);
    _ = CloseHandle(h);
    const s = buf[0..n];
    app_state.g_light_theme = false;
    app_state.g_system_theme = false;
    app_state.g_mid_theme = false;
    app_state.g_edge_gray_theme = false;
    app_state.g_amoled_theme = false;
    app_state.g_dev_theme_active = false;
    app_state.g_multiprompt_theme = false;
    if (std.mem.indexOf(u8, s, "system") != null) {
        app_state.g_system_theme = true;
        resolveSystemThemeFlags();
    } else if (std.mem.indexOf(u8, s, "multiprompt") != null) {
        app_state.g_multiprompt_theme = true;
    } else if (IS_DEV and std.mem.indexOf(u8, s, "devblue") != null) {
        app_state.g_dev_theme_active = true;
        loadDevThemeFromFile();
    } else if (std.mem.indexOf(u8, s, "amoled") != null) {
        app_state.g_amoled_theme = true;
    } else if (std.mem.indexOf(u8, s, "light") != null) {
        app_state.g_light_theme = true;
    } else if (std.mem.indexOf(u8, s, "edgegray") != null or std.mem.indexOf(u8, s, "edgegrey") != null) {
        app_state.g_edge_gray_theme = true;
    } else if (std.mem.indexOf(u8, s, "mid") != null) {
        app_state.g_mid_theme = true;
    }
}

fn changelogSeenFilePath(buf: []u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf.ptr, @intCast(buf.len));
    if (appdata_len == 0 or appdata_len >= 470) return null;
    const base_len: usize = @intCast(appdata_len);
    const rest = "\\ZigShell\\changelog-seen.txt";
    if (base_len + rest.len > buf.len) return null;
    @memcpy(buf[base_len .. base_len + rest.len], rest);
    return buf[0 .. base_len + rest.len];
}

pub fn readChangelogSeen(out: []u8) []const u8 {
    var pb: [512]u8 = undefined;
    const path = changelogSeenFilePath(pb[0..]) orelse return out[0..0];
    const h = win32OpenRead(path) orelse return out[0..0];
    defer _ = CloseHandle(h);
    const n = win32ReadAll(h, out);
    var s = out[0..n];
    while (s.len > 0 and (s[s.len - 1] == ' ' or s[s.len - 1] == '\r' or s[s.len - 1] == '\n')) {
        s = s[0 .. s.len - 1];
    }
    return s;
}

pub fn writeChangelogSeen(version: []const u8) void {
    var pb: [512]u8 = undefined;
    const path = changelogSeenFilePath(pb[0..]) orelse return;
    const h = win32OpenWrite(path) orelse return;
    defer _ = CloseHandle(h);
    win32WriteAll(h, version);
}

fn devThemePath(buf: *[512]u8) ?[]const u8 {
    if (!IS_DEV) return null;
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 470) return null;
    const rest = "\\ZigShell\\theme-dev.json";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

fn ensureDevThemeConfigFile() void {
    if (!IS_DEV) return;
    var dir_buf: [512]u8 = undefined;
    if (getSessionDir(&dir_buf)) |dir| win32MakeDir(dir);
    var path_buf: [512]u8 = undefined;
    const path = devThemePath(&path_buf) orelse return;
    if (win32OpenRead(path)) |h| {
        var head: [16384]u8 = undefined;
        const n = win32ReadAll(h, &head);
        _ = CloseHandle(h);
        if (json_reader.parse(std.heap.page_allocator, head[0..n])) |document| {
            var parsed = document;
            defer parsed.deinit();
            if (json_reader.uint(parsed.value, "theme_revision") == 11) return;
        } else |_| {}
    }
    const h = win32OpenWrite(path) orelse return;
    defer _ = CloseHandle(h);
    win32WriteAll(h, DEFAULT_DEV_THEME_JSON);
}

fn themeField(json: std.json.Value, field: []const u8) std.json.Value {
    const direct = json_reader.field(json, field);
    if (direct != .null) return direct;
    const font = json_reader.field(json_reader.field(json, "fonts"), field);
    if (font != .null) return font;
    return json_reader.field(json_reader.field(json, "colors"), field);
}

fn parseThemeStringField(json: std.json.Value, field: []const u8, out: []u8) ?[]const u8 {
    const value = json_reader.string(themeField(json, field)) orelse return null;
    const n = @min(value.len, out.len);
    @memcpy(out[0..n], value[0..n]);
    return out[0..n];
}

pub fn parseThemeIntField(json: std.json.Value, field: []const u8, out: *i32) void {
    const value = themeField(json, field);
    if (value == .number_string) out.* = std.fmt.parseInt(i32, value.number_string, 10) catch return;
}

fn hexNibble(c: u8) ?u8 {
    if (c >= '0' and c <= '9') return c - '0';
    if (c >= 'a' and c <= 'f') return c - 'a' + 10;
    if (c >= 'A' and c <= 'F') return c - 'A' + 10;
    return null;
}

fn parseHexColor(token: []const u8) ?DWORD {
    var p: usize = if (token.len > 0 and token[0] == '#') 1 else 0;
    if (token.len - p < 6) return null;
    var v: u32 = 0;
    for (0..6) |_| {
        const n = hexNibble(token[p]) orelse return null;
        v = (v << 4) | n;
        p += 1;
    }
    return RGB(@intCast((v >> 16) & 0xFF), @intCast((v >> 8) & 0xFF), @intCast(v & 0xFF));
}

fn parseThemeColorField(json: std.json.Value, field: []const u8, out: *DWORD) void {
    var token: [32]u8 = undefined;
    const value = parseThemeStringField(json, field, &token) orelse return;
    if (parseHexColor(value)) |c| out.* = c;
}

pub fn parseThemeFontField(json: std.json.Value, field: []const u8, out: *[64]u16) void {
    if (std.mem.eql(u8, field, "console_font")) {
        setWideAscii(out, app_state.DEFAULT_CONSOLE_FONT);
        return;
    }
    var token: [96]u8 = undefined;
    const value = parseThemeStringField(json, field, &token) orelse return;
    _ = json_reader.wide(value, out);
}

pub fn loadDevThemeFromFile() void {
    if (!IS_DEV) return;
    resetDevThemeDefaults();
    ensureDevThemeConfigFile();
    var path_buf: [512]u8 = undefined;
    const path = devThemePath(&path_buf) orelse return;
    const h = win32OpenRead(path) orelse return;
    defer _ = CloseHandle(h);
    var buf: [16384]u8 = undefined;
    const n = win32ReadAll(h, &buf);
    if (n == 0) return;
    var parsed = json_reader.parse(std.heap.page_allocator, buf[0..n]) catch return;
    defer parsed.deinit();
    const json = parsed.value;
    setWideAscii(&app_state.g_dev_theme.title_font, @import("fonts.zig").UI_FACE);
    setWideAscii(&app_state.g_dev_theme.subtitle_font, @import("fonts.zig").UI_FACE);
    setWideAscii(&app_state.g_dev_theme.close_font, @import("fonts.zig").UI_FACE);
    parseThemeFontField(json, "console_font", &app_state.g_dev_theme.console_font);
    parseThemeIntField(json, "title_height", &app_state.g_dev_theme.title_height);
    parseThemeIntField(json, "subtitle_height", &app_state.g_dev_theme.subtitle_height);
    parseThemeIntField(json, "close_height", &app_state.g_dev_theme.close_height);
    parseThemeIntField(json, "title_weight", &app_state.g_dev_theme.title_weight);
    parseThemeIntField(json, "subtitle_weight", &app_state.g_dev_theme.subtitle_weight);
    parseThemeIntField(json, "close_weight", &app_state.g_dev_theme.close_weight);
    parseThemeIntField(json, "console_font_height", &app_state.g_dev_theme.console_font_height);
    app_state.g_dev_theme.console_font_weight = @import("fonts.zig").SHELL_WEIGHT;
    parseThemeColorField(json, "sidebar_bg", &app_state.g_dev_theme.sidebar_bg);
    parseThemeColorField(json, "shell_bg", &app_state.g_dev_theme.shell_bg);
    parseThemeColorField(json, "console_fg", &app_state.g_dev_theme.console_fg);
    app_state.g_dev_theme.console_palette[7] = app_state.g_dev_theme.console_fg;
    for (0..16) |ci| {
        var key_buf: [16]u8 = undefined;
        const key = std.fmt.bufPrint(&key_buf, "console_{d}", .{ci}) catch continue;
        parseThemeColorField(json, key, &app_state.g_dev_theme.console_palette[ci]);
    }
    parseThemeColorField(json, "titlebar_bg", &app_state.g_dev_theme.titlebar_bg);
    parseThemeColorField(json, "border_bg", &app_state.g_dev_theme.border_bg);
    parseThemeColorField(json, "active_tab_bg", &app_state.g_dev_theme.active_tab_bg);
    parseThemeColorField(json, "header_bg", &app_state.g_dev_theme.header_bg);
    parseThemeColorField(json, "overlay_bg", &app_state.g_dev_theme.overlay_bg);
    parseThemeColorField(json, "overlay_input_bg", &app_state.g_dev_theme.overlay_input_bg);
    parseThemeColorField(json, "overlay_border", &app_state.g_dev_theme.overlay_border);
    parseThemeColorField(json, "overlay_divider", &app_state.g_dev_theme.overlay_divider);
    parseThemeColorField(json, "selected_bg", &app_state.g_dev_theme.selected_bg);
    parseThemeColorField(json, "text", &app_state.g_dev_theme.text);
    parseThemeColorField(json, "text_inactive", &app_state.g_dev_theme.text_inactive);
    parseThemeColorField(json, "subtitle", &app_state.g_dev_theme.subtitle);
    parseThemeColorField(json, "muted", &app_state.g_dev_theme.muted);
    parseThemeColorField(json, "hint", &app_state.g_dev_theme.hint);
    parseThemeColorField(json, "accent", &app_state.g_dev_theme.accent);
    parseThemeColorField(json, "attention", &app_state.g_dev_theme.attention);
    parseThemeColorField(json, "spinner", &app_state.g_dev_theme.spinner);
    parseThemeColorField(json, "tag_tmux", &app_state.g_dev_theme.tag_tmux);
    parseThemeColorField(json, "tag_tmux_active", &app_state.g_dev_theme.tag_tmux_active);
    parseThemeColorField(json, "tag_vps", &app_state.g_dev_theme.tag_vps);
    parseThemeColorField(json, "tag_vps_active", &app_state.g_dev_theme.tag_vps_active);
    parseThemeColorField(json, "tag_neutral", &app_state.g_dev_theme.tag_neutral);
    parseThemeColorField(json, "tag_neutral_active", &app_state.g_dev_theme.tag_neutral_active);
    parseThemeColorField(json, "shadow_outer", &app_state.g_dev_theme.shadow_outer);
    parseThemeColorField(json, "shadow_mid", &app_state.g_dev_theme.shadow_mid);
    parseThemeColorField(json, "shadow_inner", &app_state.g_dev_theme.shadow_inner);
    parseThemeColorField(json, "scrollbar_track", &app_state.g_dev_theme.scrollbar_track);
    parseThemeColorField(json, "scrollbar_thumb", &app_state.g_dev_theme.scrollbar_thumb);
}

pub fn openDevThemeFileInEditor() void {
    if (!IS_DEV) return;
    ensureDevThemeConfigFile();
    var path_buf: [512]u8 = undefined;
    const path = devThemePath(&path_buf) orelse return;
    var wpath_buf: [512]u16 = undefined;
    const wpath = win32WidePath(&wpath_buf, path) orelse return;
    const SHOW_NORMAL: i32 = 1;
    _ = ShellExecuteW(null, L("open"), L("notepad.exe"), wpath.ptr, null, SHOW_NORMAL);
}

pub fn multipromptColorOr(comptime field: []const u8, fallback: DWORD) DWORD {
    if (!app_state.g_multiprompt_theme) return fallback;
    if (std.mem.eql(u8, field, "sidebar_bg")) return RGB(15, 16, 17);
    if (std.mem.eql(u8, field, "shell_bg")) return RGB(8, 9, 10);
    if (std.mem.eql(u8, field, "titlebar_bg")) return RGB(18, 19, 21);
    if (std.mem.eql(u8, field, "border_bg")) return RGB(35, 37, 42);
    if (std.mem.eql(u8, field, "active_tab_bg")) return RGB(32, 33, 36);
    if (std.mem.eql(u8, field, "header_bg")) return RGB(17, 18, 20);
    if (std.mem.eql(u8, field, "overlay_bg")) return RGB(15, 16, 17);
    if (std.mem.eql(u8, field, "overlay_input_bg")) return RGB(25, 26, 27);
    if (std.mem.eql(u8, field, "overlay_border")) return RGB(35, 37, 42);
    if (std.mem.eql(u8, field, "overlay_divider")) return RGB(35, 37, 42);
    if (std.mem.eql(u8, field, "selected_bg")) return RGB(36, 36, 71);
    if (std.mem.eql(u8, field, "text")) return RGB(247, 248, 248);
    if (std.mem.eql(u8, field, "text_inactive")) return RGB(208, 214, 224);
    if (std.mem.eql(u8, field, "subtitle")) return RGB(138, 143, 152);
    if (std.mem.eql(u8, field, "muted")) return RGB(98, 102, 109);
    if (std.mem.eql(u8, field, "hint")) return RGB(98, 102, 109);
    if (std.mem.eql(u8, field, "accent")) return RGB(113, 112, 255);
    if (std.mem.eql(u8, field, "attention")) return RGB(94, 158, 255);
    if (std.mem.eql(u8, field, "spinner")) return RGB(113, 112, 255);
    if (std.mem.eql(u8, field, "scrollbar_track")) return RGB(25, 26, 27);
    if (std.mem.eql(u8, field, "scrollbar_thumb")) return RGB(98, 102, 109);
    if (std.mem.eql(u8, field, "shadow_outer")) return RGB(1, 1, 2);
    if (std.mem.eql(u8, field, "shadow_mid")) return RGB(5, 6, 8);
    if (std.mem.eql(u8, field, "shadow_inner")) return RGB(8, 9, 10);
    if (std.mem.eql(u8, field, "tab_bg")) return RGB(25, 26, 27);
    if (std.mem.eql(u8, field, "search_bg")) return RGB(25, 26, 27);
    if (std.mem.eql(u8, field, "search_border")) return RGB(35, 37, 42);
    if (std.mem.eql(u8, field, "browser_cover")) return RGB(0, 0, 0);
    if (std.mem.eql(u8, field, "tab_text")) return RGB(208, 214, 224);
    if (std.mem.eql(u8, field, "tab_text_dim")) return RGB(98, 102, 109);
    return fallback;
}

pub fn customColorOr(comptime field: []const u8, fallback: DWORD) DWORD {
    if (app_state.g_multiprompt_theme) return multipromptColorOr(field, fallback);
    if (!devThemeOn()) return fallback;
    ensureDevThemeInitialized();
    if (std.mem.eql(u8, field, "sidebar_bg")) return app_state.g_dev_theme.sidebar_bg;
    if (std.mem.eql(u8, field, "shell_bg")) return app_state.g_dev_theme.shell_bg;
    if (std.mem.eql(u8, field, "titlebar_bg")) return app_state.g_dev_theme.titlebar_bg;
    if (std.mem.eql(u8, field, "border_bg")) return app_state.g_dev_theme.border_bg;
    if (std.mem.eql(u8, field, "active_tab_bg")) return app_state.g_dev_theme.active_tab_bg;
    if (std.mem.eql(u8, field, "header_bg")) return app_state.g_dev_theme.header_bg;
    if (std.mem.eql(u8, field, "overlay_bg")) return app_state.g_dev_theme.overlay_bg;
    if (std.mem.eql(u8, field, "overlay_input_bg")) return app_state.g_dev_theme.overlay_input_bg;
    if (std.mem.eql(u8, field, "overlay_border")) return app_state.g_dev_theme.overlay_border;
    if (std.mem.eql(u8, field, "overlay_divider")) return app_state.g_dev_theme.overlay_divider;
    if (std.mem.eql(u8, field, "selected_bg")) return app_state.g_dev_theme.selected_bg;
    if (std.mem.eql(u8, field, "text")) return app_state.g_dev_theme.text;
    if (std.mem.eql(u8, field, "text_inactive")) return app_state.g_dev_theme.text_inactive;
    if (std.mem.eql(u8, field, "subtitle")) return app_state.g_dev_theme.subtitle;
    if (std.mem.eql(u8, field, "muted")) return app_state.g_dev_theme.muted;
    if (std.mem.eql(u8, field, "hint")) return app_state.g_dev_theme.hint;
    if (std.mem.eql(u8, field, "accent")) return app_state.g_dev_theme.accent;
    if (std.mem.eql(u8, field, "attention")) return app_state.g_dev_theme.attention;
    if (std.mem.eql(u8, field, "spinner")) return app_state.g_dev_theme.spinner;
    if (std.mem.eql(u8, field, "scrollbar_track")) return app_state.g_dev_theme.scrollbar_track;
    if (std.mem.eql(u8, field, "scrollbar_thumb")) return app_state.g_dev_theme.scrollbar_thumb;
    if (std.mem.eql(u8, field, "shadow_outer")) return app_state.g_dev_theme.shadow_outer;
    if (std.mem.eql(u8, field, "shadow_mid")) return app_state.g_dev_theme.shadow_mid;
    if (std.mem.eql(u8, field, "shadow_inner")) return app_state.g_dev_theme.shadow_inner;
    return fallback;
}

pub fn themeTitleFontFace() LPCWSTR {
    return @import("fonts.zig").uiFace(themeTitleFontWeight());
}

pub fn themeSubtitleFontFace() LPCWSTR {
    return @import("fonts.zig").uiFace(themeSubtitleFontWeight());
}

pub fn themeCloseFontFace() LPCWSTR {
    return @import("fonts.zig").uiFace(themeCloseFontWeight());
}

pub fn themeTitleFontHeight() i32 {
    if (LOOK_UNIFIED) {
        ensureDevThemeInitialized();
        return app_state.g_dev_theme.title_height;
    }
    return 19;
}

pub fn themeSubtitleFontHeight() i32 {
    if (LOOK_UNIFIED) {
        ensureDevThemeInitialized();
        return app_state.g_dev_theme.subtitle_height;
    }
    return 12;
}

pub fn themeCloseFontHeight() i32 {
    if (LOOK_UNIFIED) {
        ensureDevThemeInitialized();
        return app_state.g_dev_theme.close_height;
    }
    return 24;
}

pub fn themeTitleFontWeight() i32 {
    if (app_state.g_multiprompt_theme) return 500;
    if (LOOK_UNIFIED) {
        ensureDevThemeInitialized();
        return app_state.g_dev_theme.title_weight;
    }
    return 600;
}

pub fn themeSubtitleFontWeight() i32 {
    if (app_state.g_multiprompt_theme) return 400;
    if (LOOK_UNIFIED) {
        ensureDevThemeInitialized();
        return app_state.g_dev_theme.subtitle_weight;
    }
    return 400;
}

pub fn themeCloseFontWeight() i32 {
    if (app_state.g_multiprompt_theme) return 500;
    if (LOOK_UNIFIED) {
        ensureDevThemeInitialized();
        return app_state.g_dev_theme.close_weight;
    }
    return 700;
}

pub fn themeTagTmux(active: bool, fallback: DWORD) DWORD {
    if (app_state.g_multiprompt_theme) return if (active) RGB(208, 214, 224) else RGB(138, 143, 152);
    if (!devThemeOn()) return fallback;
    ensureDevThemeInitialized();
    return if (active) app_state.g_dev_theme.tag_tmux_active else app_state.g_dev_theme.tag_tmux;
}

pub fn themeTagVps(active: bool, fallback: DWORD) DWORD {
    if (app_state.g_multiprompt_theme) return if (active) RGB(130, 143, 255) else RGB(113, 112, 255);
    if (!devThemeOn()) return fallback;
    ensureDevThemeInitialized();
    return if (active) app_state.g_dev_theme.tag_vps_active else app_state.g_dev_theme.tag_vps;
}

pub fn themeTagNeutral(active: bool, fallback: DWORD) DWORD {
    if (app_state.g_multiprompt_theme) return if (active) RGB(208, 214, 224) else RGB(98, 102, 109);
    if (!devThemeOn()) return fallback;
    ensureDevThemeInitialized();
    return if (active) app_state.g_dev_theme.tag_neutral_active else app_state.g_dev_theme.tag_neutral;
}

pub fn themeReaderDark() bool {
    return !app_state.g_light_theme and !app_state.g_amoled_theme and !app_state.g_edge_gray_theme and !app_state.g_mid_theme and !app_state.g_multiprompt_theme and !devThemeOn();
}

pub fn themeSidebarBg() DWORD {
    if (app_state.g_amoled_theme) return RGB(0, 0, 0);
    return customColorOr("sidebar_bg", if (app_state.g_light_theme) RGB(243, 243, 243) else if (app_state.g_edge_gray_theme) RGB(51, 51, 51) else if (app_state.g_mid_theme) RGB(60, 60, 60) else tokens.ReaderBackground);
}

pub fn themeConsoleBg() DWORD {
    if (app_state.g_multiprompt_theme) return multipromptColorOr("shell_bg", RGB(8, 9, 10));
    if (LOOK_UNIFIED) return themeSidebarBg();
    return customColorOr("shell_bg", RGB(0, 0, 0));
}

pub fn themeConsoleFg() DWORD {
    if (app_state.g_multiprompt_theme) return RGB(247, 248, 248);
    if (!devThemeOn()) return if (app_state.g_light_theme) RGB(28, 28, 28) else if (themeReaderDark()) tokens.ReaderForeground else RGB(255, 255, 255);
    ensureDevThemeInitialized();
    return app_state.g_dev_theme.console_fg;
}

pub fn themeRaised() DWORD {
    if (themeReaderDark()) return tokens.ReaderRaised;
    const base = customColorOr("overlay_input_bg", if (app_state.g_light_theme) RGB(255, 255, 255) else themeSidebarBg());
    return tokens.shift(base, if (tokens.isDark(base)) 22 else -14);
}

pub fn themeTitleBarBg() DWORD {
    if (app_state.g_multiprompt_theme) return multipromptColorOr("titlebar_bg", RGB(18, 19, 21));
    if (devThemeOn()) {
        ensureDevThemeInitialized();
        return app_state.g_dev_theme.titlebar_bg;
    }
    return themeSidebarBg();
}

pub fn applyTitleBarTheme() void {
    if (app_state.g_main_hwnd == null) return;
    const DWMWA_USE_IMMERSIVE_DARK_MODE: DWORD = 20;
    const DWMWA_CAPTION_COLOR: DWORD = 35;
    const DWMWA_BORDER_COLOR: DWORD = 34;
    const DWMWA_TEXT_COLOR: DWORD = 36;
    defer {
        const caption_color = themeTitleBarBg();
        _ = DwmSetWindowAttribute(app_state.g_main_hwnd, DWMWA_CAPTION_COLOR, @ptrCast(&caption_color), @sizeOf(DWORD));
    }
    if (app_state.g_multiprompt_theme) {
        const dark_mode: BOOL = 1;
        _ = DwmSetWindowAttribute(app_state.g_main_hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, @ptrCast(&dark_mode), @sizeOf(BOOL));
        const text_color: DWORD = RGB(208, 214, 224);
        _ = DwmSetWindowAttribute(app_state.g_main_hwnd, DWMWA_TEXT_COLOR, @ptrCast(&text_color), @sizeOf(DWORD));
        const border_color: DWORD = multipromptColorOr("border_bg", RGB(35, 37, 42));
        _ = DwmSetWindowAttribute(app_state.g_main_hwnd, DWMWA_BORDER_COLOR, @ptrCast(&border_color), @sizeOf(DWORD));
        return;
    }
    if (devThemeOn()) {
        ensureDevThemeInitialized();
        const dark_mode: BOOL = 1;
        _ = DwmSetWindowAttribute(app_state.g_main_hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, @ptrCast(&dark_mode), @sizeOf(BOOL));
        const text_color: DWORD = RGB(255, 255, 255);
        _ = DwmSetWindowAttribute(app_state.g_main_hwnd, DWMWA_TEXT_COLOR, @ptrCast(&text_color), @sizeOf(DWORD));
        const border_color: DWORD = app_state.g_dev_theme.border_bg;
        _ = DwmSetWindowAttribute(app_state.g_main_hwnd, DWMWA_BORDER_COLOR, @ptrCast(&border_color), @sizeOf(DWORD));
        return;
    }
    if (app_state.g_light_theme) {
        const light_mode: BOOL = 0;
        _ = DwmSetWindowAttribute(app_state.g_main_hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, @ptrCast(&light_mode), @sizeOf(BOOL));
        const text_color: DWORD = RGB(28, 28, 28);
        _ = DwmSetWindowAttribute(app_state.g_main_hwnd, DWMWA_TEXT_COLOR, @ptrCast(&text_color), @sizeOf(DWORD));
        const border_color: DWORD = RGB(205, 205, 205);
        _ = DwmSetWindowAttribute(app_state.g_main_hwnd, DWMWA_BORDER_COLOR, @ptrCast(&border_color), @sizeOf(DWORD));
    } else {
        const dark_mode: BOOL = 1;
        _ = DwmSetWindowAttribute(app_state.g_main_hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, @ptrCast(&dark_mode), @sizeOf(BOOL));
        const text_color: DWORD = RGB(255, 255, 255);
        _ = DwmSetWindowAttribute(app_state.g_main_hwnd, DWMWA_TEXT_COLOR, @ptrCast(&text_color), @sizeOf(DWORD));
        const border_color: DWORD = if (app_state.g_amoled_theme) RGB(0, 0, 0) else if (app_state.g_edge_gray_theme) RGB(86, 86, 86) else if (app_state.g_mid_theme) RGB(104, 104, 104) else RGB(86, 86, 86);
        _ = DwmSetWindowAttribute(app_state.g_main_hwnd, DWMWA_BORDER_COLOR, @ptrCast(&border_color), @sizeOf(DWORD));
    }
}

test "IGSH-443 shell face and saved font names migrate idempotently" {
    try std.testing.expectEqualStrings("Nordwand Mono MP SemiBold", app_state.DEFAULT_CONSOLE_FONT);
    try std.testing.expect(app_state.DEFAULT_CONSOLE_FONT.len < 32);
    try std.testing.expectEqualStrings(app_state.DEFAULT_CONSOLE_FONT, app_state.DEV_CONSOLE_FONTS[app_state.DEFAULT_CONSOLE_FONT_IDX]);
    for ([_][]const u8{
        "{\"console_font\":\"Nordwand Mono\",\"console_font_height\":22}",
        "{\"console_font\":\"Nordwand Mono SemiBold\",\"console_font_height\":22}",
        "{\"console_font\":\"Nordwand Mono MP SemiBold\",\"console_font_height\":22}",
        "{\"console_font\":\"JetBrainsMono NFM\",\"console_font_height\":22}",
        "{\"console_font\":\"Hack Nerd Font Mono\",\"console_font_height\":22}",
        "{\"console_font\":\"Unknown stale family\",\"console_font_height\":22}",
        "{\"console_font\":\"Hack\",\"console_font_height\":22}",
    }) |text| {
        var parsed = try json_reader.parse(std.testing.allocator, text);
        defer parsed.deinit();
        var face: [64]u16 = @splat(0);
        parseThemeFontField(parsed.value, "console_font", &face);
        try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Nordwand Mono MP SemiBold"), std.mem.sliceTo(&face, 0));
        var height: i32 = 18;
        parseThemeIntField(parsed.value, "console_font_height", &height);
        try std.testing.expectEqual(@as(i32, 22), height);
    }
}

test "IGSH-456 nested and missing saved faces preserve unrelated settings" {
    for ([_][]const u8{
        "{\"fonts\":{\"console_font\":\"old face\",\"console_font_height\":24,\"title_font\":\"IBM Plex Sans\"},\"colors\":{\"shell_bg\":\"#123456\"}}",
        "{\"console_font\":null,\"console_font_height\":24,\"title_font\":\"IBM Plex Sans\",\"shell_bg\":\"#123456\"}",
        "{\"console_font_height\":24,\"title_font\":\"IBM Plex Sans\",\"shell_bg\":\"#123456\"}",
    }) |text| {
        var parsed = try json_reader.parse(std.testing.allocator, text);
        defer parsed.deinit();
        var face: [64]u16 = @splat(0);
        parseThemeFontField(parsed.value, "console_font", &face);
        try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Nordwand Mono MP SemiBold"), std.mem.sliceTo(&face, 0));
        parseThemeFontField(parsed.value, "title_font", &face);
        try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("IBM Plex Sans"), std.mem.sliceTo(&face, 0));
        var height: i32 = 18;
        parseThemeIntField(parsed.value, "console_font_height", &height);
        try std.testing.expectEqual(@as(i32, 24), height);
        var color: DWORD = 0;
        parseThemeColorField(parsed.value, "shell_bg", &color);
        try std.testing.expectEqual(RGB(0x12, 0x34, 0x56), color);
    }
}

fn issue456Table(file: []const u8, tag: *const [4]u8) []const u8 {
    for (0..std.mem.readInt(u16, file[4..6], .big)) |i| {
        const record = file[12 + i * 16 ..][0..16];
        if (std.mem.eql(u8, record[0..4], tag)) return file[std.mem.readInt(u32, record[8..12], .big)..][0..std.mem.readInt(u32, record[12..16], .big)];
    }
    return &.{};
}

fn issue456WindowsName(file: []const u8, id: u16, out: []u16) []const u16 {
    const name = issue456Table(file, "name");
    const strings = name[std.mem.readInt(u16, name[4..6], .big)..];
    for (0..std.mem.readInt(u16, name[2..4], .big)) |i| {
        const record = name[6 + i * 12 ..][0..12];
        if (std.mem.readInt(u16, record[0..2], .big) != 3 or std.mem.readInt(u16, record[6..8], .big) != id) continue;
        const text = strings[std.mem.readInt(u16, record[10..12], .big)..][0..std.mem.readInt(u16, record[8..10], .big)];
        for (0..text.len / 2) |j| out[j] = std.mem.readInt(u16, text[j * 2 ..][0..2], .big);
        return out[0 .. text.len / 2];
    }
    return out[0..0];
}

test "ISSUE-456 shell face is the bundled Nordwand Mono MP SemiBold and declares the code pages conhost requests" {
    const fonts = @import("fonts.zig");
    try std.testing.expectEqualStrings("Nordwand Mono MP SemiBold", fonts.SHELL_FACE);
    try std.testing.expectEqual(600, fonts.SHELL_WEIGHT);
    var face: [64]u16 = undefined;
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral(fonts.SHELL_FACE), issue456WindowsName(fonts.MONO_SEMIBOLD, 1, &face));
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral(fonts.SHELL_FACE), issue456WindowsName(fonts.MONO_SEMIBOLD, 4, &face));
    const os2 = issue456Table(fonts.MONO_SEMIBOLD, "OS/2");
    try std.testing.expectEqual(@as(u16, fonts.SHELL_WEIGHT), std.mem.readInt(u16, os2[4..6], .big));
    try std.testing.expectEqual(@as(u8, 9), os2[35]);
    try std.testing.expect(std.mem.readInt(u16, os2[0..2], .big) >= 1);
    try std.testing.expect(std.mem.readInt(u32, os2[78..82], .big) & 1 != 0);
    try std.testing.expect(std.mem.readInt(u32, os2[82..86], .big) & (1 << 31) != 0);
    try std.testing.expect(std.mem.readInt(u32, os2[82..86], .big) & (1 << 30) != 0);
    try std.testing.expect(std.mem.readInt(u32, issue456Table(fonts.MONO_SEMIBOLD, "post")[12..16], .big) != 0);
}

test "ISSUE-456 conhost reads the shell font from a content-named session font file" {
    const source = @embedFile("console.zig");
    const start = std.mem.indexOf(u8, source, "pub fn bundledShellFontFileName(").?;
    const end = std.mem.indexOf(u8, source[start..], "\npub fn unregisterBundledConsoleFonts(").? + start;
    const register = source[start..end];
    try std.testing.expect(std.mem.indexOf(u8, register, "Wyhash.hash(0, @import(\"fonts.zig\").MONO_SEMIBOLD)") != null);
    try std.testing.expect(std.mem.indexOf(u8, register, "@import(\"fonts.zig\").MONO_SEMIBOLD },") != null);
    try std.testing.expect(std.mem.indexOf(u8, register, "AddFontResourceExW(@ptrCast(path), 0, null)") != null);
    try std.testing.expect(std.mem.indexOf(u8, register, "AddFontMemResourceEx") == null);
    try std.testing.expect(std.mem.indexOf(u8, register, "Hack") == null);
    try std.testing.expect(std.mem.indexOf(u8, register, "NordwandMono-Regular") == null);
    try std.testing.expect(std.mem.indexOf(u8, register, "NordwandMono-Bold") == null);
    try std.testing.expect(std.mem.indexOf(u8, app_state.DEFAULT_DEV_THEME_JSON, "\"console_font_weight\": 600") != null);
}
