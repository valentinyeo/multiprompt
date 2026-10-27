const smooth = @import("smooth.zig");
const app_state = @import("app_state.zig");
const std = @import("std");
const tokens = @import("design_tokens.zig");
const DWORD = @import("win32.zig").DWORD;
const HANDLE = @import("win32.zig").HANDLE;
const DT_SINGLELINE = @import("win32.zig").DT_SINGLELINE;
const DT_VCENTER = @import("win32.zig").DT_VCENTER;
const DT_CENTER = @import("win32.zig").DT_CENTER;
const DT_RIGHT = @import("win32.zig").DT_RIGHT;
const DT_NOPREFIX = @import("win32.zig").DT_NOPREFIX;
const DT_END_ELLIPSIS = @import("win32.zig").DT_END_ELLIPSIS;
const DT_CALCRECT = @import("win32.zig").DT_CALCRECT;
const TRANSPARENT = @import("win32.zig").TRANSPARENT;
const NULL_BRUSH = @import("win32.zig").NULL_BRUSH;
const RECT = @import("win32.zig").RECT;
const IsWindow = @import("win32.zig").IsWindow;
const GetClientRect = @import("win32.zig").GetClientRect;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const FillRect = @import("win32.zig").FillRect;
const DrawTextW = @import("win32.zig").DrawTextW;
const CreateSolidBrush = @import("win32.zig").CreateSolidBrush;
const DeleteObject = @import("win32.zig").DeleteObject;
const SetBkMode = @import("win32.zig").SetBkMode;
const SetTextColor = @import("win32.zig").SetTextColor;
const SelectObject = @import("win32.zig").SelectObject;
const GetStockObject = @import("win32.zig").GetStockObject;
const CreateFontW = @import("fonts.zig").create;
const CreatePen = @import("win32.zig").CreatePen;
const MoveToEx = @import("win32.zig").MoveToEx;
const LineTo = @import("win32.zig").LineTo;
const CreateCompatibleDC = @import("win32.zig").CreateCompatibleDC;
const CreateCompatibleBitmap = @import("win32.zig").CreateCompatibleBitmap;
const DeleteDC = @import("win32.zig").DeleteDC;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const SendMessageW = @import("win32.zig").SendMessageW;
const L = @import("startup.zig").L;
const RGB = @import("startup.zig").RGB;
const Shell = @import("app_state.zig").Shell;
const customColorOr = @import("themes.zig").customColorOr;
const themeTitleFontFace = @import("themes.zig").themeTitleFontFace;
const themeSubtitleFontFace = @import("themes.zig").themeSubtitleFontFace;
const themeCloseFontFace = @import("themes.zig").themeCloseFontFace;
const themeTitleFontHeight = @import("themes.zig").themeTitleFontHeight;
const themeSubtitleFontHeight = @import("themes.zig").themeSubtitleFontHeight;
const themeCloseFontHeight = @import("themes.zig").themeCloseFontHeight;
const themeTitleFontWeight = @import("themes.zig").themeTitleFontWeight;
const themeSubtitleFontWeight = @import("themes.zig").themeSubtitleFontWeight;
const themeCloseFontWeight = @import("themes.zig").themeCloseFontWeight;
const themeSidebarBg = @import("themes.zig").themeSidebarBg;
const themeConsoleBg = @import("themes.zig").themeConsoleBg;
const themeConsoleFg = @import("themes.zig").themeConsoleFg;
const SIDEBAR_W = @import("browser_pane.zig").SIDEBAR_W;
const MAX_LWS = @import("app_state.zig").MAX_LWS;
const WS_STRIP_H = @import("app_state.zig").WS_STRIP_H;
const WS_PILL_TOP = @import("app_state.zig").WS_PILL_TOP;
const WS_PILL_H = @import("app_state.zig").WS_PILL_H;
const WS_PILL_W = @import("app_state.zig").WS_PILL_W;
const WS_PILL_GAP = @import("app_state.zig").WS_PILL_GAP;
const WS_STRIP_LEFT = @import("app_state.zig").WS_STRIP_LEFT;
const inboxButtonRect = @import("browser_pane.zig").inboxButtonRect;
const threadTitleHeight = @import("browser_pane.zig").threadTitleHeight;
const threadTitleTop = @import("browser_pane.zig").threadTitleTop;
const tintColor = @import("sidebar.zig").tintColor;
const CapacityState = @import("app_state.zig").CapacityState;
const activeCapacityStatus = @import("capacity.zig").activeCapacityStatus;
const workspaceCapacityState = @import("capacity.zig").workspaceCapacityState;
const SEARCH_VISIBLE_ROWS = @import("app_state.zig").SEARCH_VISIBLE_ROWS;
const mainWindowDpi = @import("console.zig").mainWindowDpi;
const drawAttentionDot = @import("archive.zig").drawAttentionDot;
const contentHeaderLeft = @import("browser_pane.zig").contentHeaderLeft;
const browserSlotReserved = @import("browser_pane.zig").browserSlotReserved;
const calcBrowserLayout = @import("browser_pane.zig").calcBrowserLayout;
const paletteAnchoredBesideBrowser = @import("browser_pane.zig").paletteAnchoredBesideBrowser;
const chatViewLayout = @import("chat_composer.zig").chatViewLayout;
const chatRelayout = @import("chat_render.zig").chatRelayout;
const voiceStatusLabel = @import("voice.zig").voiceStatusLabel;
const inboxPublishesShell = @import("inbox.zig").inboxPublishesShell;
const inboxRelTime = @import("inbox.zig").inboxRelTime;

pub fn drawAscii(hdc: HANDLE, text: []const u8, rc: *RECT, flags: u32) void {
    var buf: [128]u16 = undefined;
    var n: usize = 0;
    for (text) |c| {
        if (n >= buf.len) break;
        buf[n] = @intCast(c);
        n += 1;
    }
    _ = DrawTextW(hdc, @ptrCast(&buf), @intCast(n), rc, flags);
}

pub fn drawAsciiLong(hdc: HANDLE, text: []const u8, rc: *RECT, flags: u32) void {
    var buf: [1024]u16 = undefined;
    var n: usize = 0;
    for (text) |c| {
        if (n >= buf.len) break;
        buf[n] = @intCast(c);
        n += 1;
    }
    _ = DrawTextW(hdc, @ptrCast(&buf), @intCast(n), rc, flags);
}

pub fn asciiTextWidth(hdc: HANDLE, text: []const u8) i32 {
    var calc = RECT{ .left = 0, .top = 0, .right = 0, .bottom = 0 };
    drawAscii(hdc, text, &calc, DT_CALCRECT | DT_SINGLELINE | DT_NOPREFIX);
    return calc.right - calc.left;
}

pub fn drawAsciiRun(hdc: HANDLE, text: []const u8, x: i32, top: i32, bottom: i32, right_limit: i32) i32 {
    if (text.len == 0 or x >= right_limit) return x;
    const width = asciiTextWidth(hdc, text);
    var rc = RECT{ .left = x, .top = top, .right = @min(x + width, right_limit), .bottom = bottom };
    drawAscii(hdc, text, &rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
    return x + width;
}

pub fn drawModalShadow(hdc: HANDLE, x: i32, y: i32, w: i32, h: i32, radius: i32) void {
    var canvas = smooth.Canvas.init(hdc);
    defer canvas.deinit();
    if (w <= 0 or h <= 0) return;

    const old_brush = SelectObject(hdc, GetStockObject(NULL_BRUSH));
    defer _ = SelectObject(hdc, old_brush);

    const ShadowSpec = struct { offset: i32, width: i32, color: DWORD };
    const specs = if (app_state.g_light_theme)
        [_]ShadowSpec{
            .{ .offset = 11, .width = 6, .color = RGB(215, 215, 215) },
            .{ .offset = 7, .width = 4, .color = RGB(190, 190, 190) },
            .{ .offset = 4, .width = 2, .color = RGB(165, 165, 165) },
        }
    else
        [_]ShadowSpec{
            .{ .offset = 11, .width = 6, .color = customColorOr("shadow_outer", RGB(20, 20, 20)) },
            .{ .offset = 7, .width = 4, .color = customColorOr("shadow_mid", RGB(12, 12, 12)) },
            .{ .offset = 4, .width = 2, .color = customColorOr("shadow_inner", RGB(4, 4, 4)) },
        };

    for (specs) |spec| {
        const pen = CreatePen(0, spec.width, spec.color);
        if (pen == null) continue;
        const old_pen = SelectObject(hdc, pen);
        _ = canvas.drawRoundRect(x + spec.offset, y + spec.offset, x + w + spec.offset, y + h + spec.offset, radius, radius);
        _ = SelectObject(hdc, old_pen);
        _ = DeleteObject(pen);
    }
}

var paint_canvas = smooth.Canvas{ .hdc = null };

pub fn beginPaintCanvas() *smooth.Canvas {
    paint_canvas.activate();
    return &paint_canvas;
}

pub fn resetPaintBackbuffer() void {
    paint_canvas.deinit();
    if (app_state.g_paint_mem_dc) |dc| {
        if (app_state.g_paint_old_bmp != null) _ = SelectObject(dc, app_state.g_paint_old_bmp);
    }
    if (app_state.g_paint_bmp != null) _ = DeleteObject(app_state.g_paint_bmp);
    if (app_state.g_paint_mem_dc != null) _ = DeleteDC(app_state.g_paint_mem_dc);
    app_state.g_paint_mem_dc = null;
    app_state.g_paint_bmp = null;
    app_state.g_paint_old_bmp = null;
    app_state.g_paint_w = 0;
    app_state.g_paint_h = 0;
}

pub fn ensurePaintBackbuffer(hdc: HANDLE, w: i32, h: i32) HANDLE {
    if (w <= 0 or h <= 0) return null;
    if (app_state.g_paint_mem_dc != null and app_state.g_paint_bmp != null and app_state.g_paint_w >= w and app_state.g_paint_h >= h) return app_state.g_paint_mem_dc;

    resetPaintBackbuffer();
    const mem_dc = CreateCompatibleDC(hdc);
    if (mem_dc == null) return null;
    const width = @divTrunc(w + 127, 128) * 128;
    const height = @divTrunc(h + 127, 128) * 128;
    const info = @import("win32.zig").BITMAPINFO{ .header = .{ .width = width, .height = -height } };
    var bits: ?*anyopaque = null;
    const bmp = @import("win32.zig").CreateDIBSection(hdc, &info, 0, &bits, null, 0);
    if (bmp == null) {
        _ = DeleteDC(mem_dc);
        return null;
    }
    app_state.g_paint_old_bmp = SelectObject(mem_dc, bmp);
    app_state.g_paint_mem_dc = mem_dc;
    app_state.g_paint_bmp = bmp;
    app_state.g_paint_w = width;
    app_state.g_paint_h = height;
    paint_canvas = smooth.Canvas.init(mem_dc);
    paint_canvas.deactivate();
    return mem_dc;
}

pub fn resetFontCache() void {
    @import("dwrite_text.zig").resetFonts();
    @import("chat_render.zig").resetTableMetrics();
    app_state.g_chat_tables.clear(std.heap.page_allocator);
    for (app_state.g_chat_histories.items) |entry| entry.tables.clear(std.heap.page_allocator);
    if (app_state.g_font_title != null) _ = DeleteObject(app_state.g_font_title);
    if (app_state.g_font_shell_tab_title != null) _ = DeleteObject(app_state.g_font_shell_tab_title);
    if (app_state.g_font_subtitle != null) _ = DeleteObject(app_state.g_font_subtitle);
    if (app_state.g_font_status_card != null) _ = DeleteObject(app_state.g_font_status_card);
    if (app_state.g_font_close != null) _ = DeleteObject(app_state.g_font_close);
    if (app_state.g_font_inbox_title != null) _ = DeleteObject(app_state.g_font_inbox_title);
    if (app_state.g_font_inbox_sub != null) _ = DeleteObject(app_state.g_font_inbox_sub);
    if (app_state.g_font_thread_title != null) _ = DeleteObject(app_state.g_font_thread_title);
    for (&app_state.g_chat_rich_fonts) |*font| {
        if (font.* != null) _ = DeleteObject(font.*);
        font.* = null;
    }
    if (app_state.g_chat_link_font != null) {
        _ = DeleteObject(app_state.g_chat_link_font);
        app_state.g_chat_link_font = null;
    }
    if (app_state.g_chat_code_link_font != null) {
        _ = DeleteObject(app_state.g_chat_code_link_font);
        app_state.g_chat_code_link_font = null;
    }
    if (app_state.g_chat_font != null) {
        const fallback = @import("fonts.zig").controlFont();
        if (app_state.g_chat_composer_hwnd != null) _ = SendMessageW(app_state.g_chat_composer_hwnd, 0x0030, @intFromPtr(fallback), 0);
        _ = DeleteObject(app_state.g_chat_font);
        app_state.g_chat_font = null;
    }
    if (app_state.g_chat_code_font != null) {
        _ = DeleteObject(app_state.g_chat_code_font);
        app_state.g_chat_code_font = null;
    }
    if (app_state.g_chat_active and app_state.g_chat_transcript_hwnd != null and app_state.g_chat_layout_width > 0) {
        chatRelayout(app_state.g_chat_layout_width);
        _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    }
    app_state.g_font_title = null;
    app_state.g_font_shell_tab_title = null;
    app_state.g_font_subtitle = null;
    app_state.g_font_status_card = null;
    app_state.g_font_close = null;
    app_state.g_font_inbox_title = null;
    app_state.g_font_inbox_sub = null;
    app_state.g_font_thread_title = null;
    app_state.g_chat_font = null;
}

pub fn resetGdiCache() void {
    resetFontCache();
    resetPaintBackbuffer();
}

pub fn uiScaled(px: i32) i32 {
    const numerator = @as(i64, px) *
        @as(i64, @intCast(app_state.g_ui_scale)) *
        @as(i64, @intCast(mainWindowDpi()));
    return @intCast(@divTrunc(numerator, 100 * 96));
}

pub fn uiUnscaled(px: i32) i32 {
    const scale = @as(i64, @intCast(app_state.g_ui_scale)) *
        @as(i64, @intCast(mainWindowDpi()));
    if (scale <= 0) return px;
    return @intCast(@divTrunc(@as(i64, px) * 100 * 96, scale));
}

pub fn searchRowH() i32 {
    return uiScaled(32);
}
pub fn searchInputH() i32 {
    return uiScaled(36);
}
pub fn searchOverlayW() i32 {
    return uiScaled(430);
}

pub fn searchOverlayOx(win_w: i32, overlay_w: i32) i32 {
    if (paletteAnchoredBesideBrowser()) {
        const layout = calcBrowserLayout().?;
        const console_right = layout.splitter_left;
        var ox = SIDEBAR_W() + @divFloor((console_right - SIDEBAR_W()) - overlay_w, 2);
        if (ox < SIDEBAR_W() + 8) ox = SIDEBAR_W() + 8;
        if (ox + overlay_w > console_right - 8) ox = console_right - 8 - overlay_w;
        return ox;
    }
    return @divFloor(win_w - overlay_w, 2);
}

pub fn searchResultRowAtClientPoint(mx: i32, my: i32) ?u32 {
    if (!app_state.g_search_active or app_state.g_search_result_count == 0 or app_state.g_search_rename_input_mode or app_state.g_browser_url_mode) return null;

    var win_rc: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(app_state.g_main_hwnd, &win_rc);
    const win_w = win_rc.right - win_rc.left;
    const win_h = win_rc.bottom - win_rc.top;
    const overlay_w = searchOverlayW();
    const row_h = searchRowH();
    const input_h = searchInputH();
    const visible_capacity: u32 = @min(app_state.g_search_result_count, SEARCH_VISIBLE_ROWS);
    const visible_rows: u32 = @min(app_state.g_search_result_count -| app_state.g_search_scroll, visible_capacity);
    const overlay_h = input_h + @as(i32, @intCast(visible_capacity)) * row_h;
    const ox = searchOverlayOx(win_w, overlay_w);
    const oy = @divFloor(win_h - overlay_h, 3);

    if (mx < ox or mx >= ox + overlay_w or my < oy + input_h or my >= oy + overlay_h) return null;
    const visual_row: u32 = @intCast(@divFloor(my - (oy + input_h), row_h));
    if (visual_row >= visible_rows) return null;
    return app_state.g_search_scroll + visual_row;
}

pub fn uiFontTitle() HANDLE {
    if (app_state.g_font_title == null) {
        app_state.g_font_title = CreateFontW(uiScaled(themeTitleFontHeight()), 0, 0, 0, themeTitleFontWeight(), 0, 0, 0, 0, 0, 0, 0, 0, themeTitleFontFace());
    }
    return app_state.g_font_title orelse @import("fonts.zig").controlFont();
}

pub fn uiFontShellTabTitle() HANDLE {
    if (!app_state.g_multiprompt_theme) return uiFontTitle();
    if (app_state.g_font_shell_tab_title == null) {
        const base = themeTitleFontHeight();
        const smaller = if (base < 0) @min(base + 1, -1) else @max(base - 1, 1);
        app_state.g_font_shell_tab_title = CreateFontW(uiScaled(smaller), 0, 0, 0, themeTitleFontWeight(), 0, 0, 0, 0, 0, 0, 0, 0, themeTitleFontFace());
    }
    return app_state.g_font_shell_tab_title orelse uiFontTitle();
}

pub fn uiFontSubtitle() HANDLE {
    if (app_state.g_font_subtitle == null) {
        app_state.g_font_subtitle = CreateFontW(uiScaled(themeSubtitleFontHeight()), 0, 0, 0, themeSubtitleFontWeight(), 0, 0, 0, 0, 0, 0, 0, 0, themeSubtitleFontFace());
    }
    return app_state.g_font_subtitle orelse @import("fonts.zig").controlFont();
}

pub fn uiFontStatusCard() HANDLE {
    if (app_state.g_font_status_card == null) {
        const base = themeSubtitleFontHeight();
        const smaller = if (base < 0) @min(base + 1, -1) else @max(base - 1, 1);
        app_state.g_font_status_card = CreateFontW(uiScaled(smaller), 0, 0, 0, themeSubtitleFontWeight(), 0, 0, 0, 0, 0, 0, 0, 0, themeSubtitleFontFace());
    }
    return app_state.g_font_status_card orelse uiFontSubtitle();
}

pub fn uiFontInboxTitle() HANDLE {
    if (app_state.g_font_inbox_title == null) {
        const h = themeTitleFontHeight();
        const derived = if (app_state.g_multiprompt_theme) h else if (h < 0) h - 2 else h + 2;
        const weight: i32 = if (app_state.g_multiprompt_theme) 500 else 700;
        app_state.g_font_inbox_title = CreateFontW(uiScaled(derived), 0, 0, 0, weight, 0, 0, 0, 0, 0, 0, 0, 0, themeTitleFontFace());
    }
    return app_state.g_font_inbox_title orelse @import("fonts.zig").controlFont();
}

pub fn uiFontInboxSub() HANDLE {
    if (app_state.g_font_inbox_sub == null) {
        const h = themeSubtitleFontHeight();
        const derived = if (app_state.g_multiprompt_theme) h else if (h < 0) h - 2 else h + 2;
        const weight: i32 = if (app_state.g_multiprompt_theme) 400 else 700;
        app_state.g_font_inbox_sub = CreateFontW(uiScaled(derived), 0, 0, 0, weight, 0, 0, 0, 0, 0, 0, 0, 0, themeSubtitleFontFace());
    }
    return app_state.g_font_inbox_sub orelse @import("fonts.zig").controlFont();
}

fn uiFontThreadTitle() HANDLE {
    if (app_state.g_font_thread_title == null) {
        app_state.g_font_thread_title = CreateFontW(uiScaled(@as(i32, @intCast(@abs(themeTitleFontHeight()))) + 8), 0, 0, 0, 700, 0, 0, 0, 0, 0, 0, 0, 0, themeTitleFontFace());
    }
    return app_state.g_font_thread_title orelse @import("fonts.zig").controlFont();
}

pub fn uiFontClose() HANDLE {
    if (app_state.g_font_close == null) {
        app_state.g_font_close = CreateFontW(uiScaled(themeCloseFontHeight()), 0, 0, 0, themeCloseFontWeight(), 0, 0, 0, 0, 0, 0, 0, 0, themeCloseFontFace());
    }
    return app_state.g_font_close orelse @import("fonts.zig").controlFont();
}

fn browserPaneLive(shell: *const Shell) bool {
    if (!shell.browser_enabled) return false;
    if (shell.browser_hwnd) |bh| return IsWindow(bh) != 0;
    return false;
}

pub fn browserInboxState(shell: *const Shell) u8 {
    if (!shell.browser_enabled) return 0;
    return if (browserPaneLive(shell)) 2 else 1;
}

fn drawNativeLine(canvas: *smooth.Canvas, pen: HANDLE, x1: i32, y1: i32, x2: i32, y2: i32) void {
    canvas.strokePenLine(pen, x1, y1, x2, y2);
}

pub fn drawAgentIcon(hdc: HANDLE, rc: *RECT, agent: u8, active: bool) void {
    var canvas = smooth.Canvas.init(hdc);
    defer canvas.deinit();
    const cx = @divTrunc(rc.left + rc.right, 2);
    const cy = @divTrunc(rc.top + rc.bottom, 2);
    const pulse = if (active) app_state.g_spinner_frame % 4 else 0;
    if (agent == 7) {
        const cursor_ink: DWORD = if (!active)
            (if (app_state.g_light_theme) RGB(40, 43, 50) else RGB(225, 229, 236))
        else switch (pulse) {
            0 => RGB(118, 124, 138),
            1, 3 => RGB(224, 228, 238),
            else => RGB(255, 255, 255),
        };
        const cursor_core: DWORD = if (!active)
            (if (app_state.g_light_theme) RGB(104, 108, 119) else RGB(153, 160, 176))
        else switch (pulse) {
            0 => RGB(91, 98, 114),
            1, 3 => RGB(174, 181, 198),
            else => RGB(207, 214, 230),
        };
        const outer_pen = CreatePen(0, uiScaled(1), cursor_ink);
        drawNativeLine(&canvas, outer_pen, cx, cy - 7, cx + 7, cy);
        drawNativeLine(&canvas, outer_pen, cx + 7, cy, cx, cy + 7);
        drawNativeLine(&canvas, outer_pen, cx, cy + 7, cx - 7, cy);
        drawNativeLine(&canvas, outer_pen, cx - 7, cy, cx, cy - 7);
        drawNativeLine(&canvas, outer_pen, cx, cy - 7, cx, cy - 3);
        drawNativeLine(&canvas, outer_pen, cx + 7, cy, cx + 3, cy);
        drawNativeLine(&canvas, outer_pen, cx, cy + 7, cx, cy + 3);
        drawNativeLine(&canvas, outer_pen, cx - 7, cy, cx - 3, cy);
        _ = DeleteObject(outer_pen);

        const core_pen = CreatePen(0, uiScaled(1), cursor_core);
        drawNativeLine(&canvas, core_pen, cx, cy - 3, cx + 3, cy);
        drawNativeLine(&canvas, core_pen, cx + 3, cy, cx, cy + 3);
        drawNativeLine(&canvas, core_pen, cx, cy + 3, cx - 3, cy);
        drawNativeLine(&canvas, core_pen, cx - 3, cy, cx, cy - 3);
        _ = DeleteObject(core_pen);
        return;
    }
    if (agent == 6) {
        const grok_ink: DWORD = if (!active)
            (if (app_state.g_light_theme) RGB(44, 48, 58) else RGB(226, 230, 238))
        else switch (pulse) {
            0 => RGB(130, 142, 160),
            1, 3 => RGB(219, 228, 242),
            else => RGB(255, 255, 255),
        };
        const grok_blue: DWORD = if (!active)
            RGB(64, 142, 255)
        else switch (pulse) {
            0 => RGB(45, 112, 220),
            1, 3 => RGB(85, 164, 255),
            else => RGB(135, 197, 255),
        };
        _ = SelectObject(hdc, uiFontTitle());
        _ = SetTextColor(hdc, grok_ink);
        _ = DrawTextW(hdc, L("G"), -1, rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
        const orbit_pen = CreatePen(0, uiScaled(1), grok_blue);
        drawNativeLine(&canvas, orbit_pen, cx + 1, cy - 6, cx + 6, cy - 2);
        _ = DeleteObject(orbit_pen);
        return;
    }
    if (agent == 5) {
        const hax_orange: DWORD = if (!active)
            RGB(215, 135, 95)
        else switch (pulse) {
            0 => RGB(191, 111, 74),
            1, 3 => RGB(231, 151, 111),
            else => RGB(245, 174, 137),
        };
        const hax_cyan: DWORD = if (!active)
            RGB(0, 175, 175)
        else switch (pulse) {
            0 => RGB(0, 142, 142),
            1, 3 => RGB(20, 196, 196),
            else => RGB(69, 221, 221),
        };
        const chevron_pen = CreatePen(0, uiScaled(2), hax_orange);
        drawNativeLine(&canvas, chevron_pen, cx - 6, cy - 5, cx - 1, cy);
        drawNativeLine(&canvas, chevron_pen, cx - 1, cy, cx - 6, cy + 5);
        _ = DeleteObject(chevron_pen);

        const cursor_brush = CreateSolidBrush(hax_cyan);
        var cursor_rc = RECT{ .left = cx + 1, .top = cy + 3, .right = cx + 7, .bottom = cy + 5 };
        _ = FillRect(hdc, &cursor_rc, cursor_brush);
        _ = DeleteObject(cursor_brush);
        return;
    }
    if (agent == 4) {
        const kimi_ink = themeConsoleFg();
        const kimi_blue: DWORD = if (!active)
            RGB(49, 120, 255)
        else switch (pulse) {
            0 => RGB(36, 96, 220),
            1, 3 => RGB(70, 145, 255),
            else => RGB(115, 178, 255),
        };
        const mark_pen = CreatePen(0, uiScaled(2), kimi_ink);
        drawNativeLine(&canvas, mark_pen, cx - 4, cy - 5, cx - 4, cy + 5);
        drawNativeLine(&canvas, mark_pen, cx - 4, cy, cx + 3, cy - 5);
        drawNativeLine(&canvas, mark_pen, cx - 4, cy, cx + 3, cy + 5);
        _ = DeleteObject(mark_pen);

        const dot_brush = CreateSolidBrush(kimi_blue);
        const dot_pen = CreatePen(0, 1, kimi_blue);
        const old_brush = SelectObject(hdc, dot_brush);
        const old_pen = SelectObject(hdc, dot_pen);
        _ = canvas.drawEllipse(cx + 3, cy - 7, cx + 7, cy - 3);
        _ = SelectObject(hdc, old_pen);
        _ = SelectObject(hdc, old_brush);
        _ = DeleteObject(dot_pen);
        _ = DeleteObject(dot_brush);
        return;
    }
    if (agent == 3) {
        _ = SelectObject(hdc, uiFontTitle());
        const pi_color: DWORD = if (!active)
            RGB(167, 139, 250)
        else switch (pulse) {
            0 => RGB(167, 139, 250),
            1, 3 => RGB(190, 170, 255),
            else => RGB(216, 204, 255),
        };
        _ = SetTextColor(hdc, pi_color);
        _ = DrawTextW(hdc, L("\u{03C0}"), -1, rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
        return;
    }
    if (agent == 2) {
        _ = SelectObject(hdc, uiFontTitle());
        const codex_green: DWORD = if (!active)
            RGB(16, 163, 127)
        else switch (pulse) {
            0 => RGB(12, 132, 103),
            1, 3 => RGB(24, 190, 148),
            else => RGB(70, 225, 181),
        };
        _ = SetTextColor(hdc, codex_green);
        _ = DrawTextW(hdc, L("\u{2B21}"), -1, rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
        return;
    }
    if (agent == 1) {
        const orange: DWORD = if (!active)
            RGB(217, 119, 87)
        else switch (pulse) {
            0 => RGB(194, 91, 62),
            1, 3 => RGB(238, 139, 101),
            else => RGB(248, 165, 128),
        };
        const ray: i32 = if (!active) 5 else switch (pulse) {
            0 => 4,
            1, 3 => 6,
            else => 7,
        };
        const diagonal: i32 = if (!active) 4 else switch (pulse) {
            0 => 3,
            1, 3 => 5,
            else => 5,
        };
        const pen = CreatePen(0, uiScaled(2), orange);
        drawNativeLine(&canvas, pen, cx - ray, cy, cx + ray, cy);
        drawNativeLine(&canvas, pen, cx, cy - ray, cx, cy + ray);
        drawNativeLine(&canvas, pen, cx - diagonal, cy - diagonal, cx + diagonal, cy + diagonal);
        drawNativeLine(&canvas, pen, cx - diagonal, cy + diagonal, cx + diagonal, cy - diagonal);
        _ = DeleteObject(pen);
        const br = CreateSolidBrush(orange);
        const dot_pen = CreatePen(0, 1, orange);
        const old_br = SelectObject(hdc, br);
        const old_pen = SelectObject(hdc, dot_pen);
        _ = canvas.drawEllipse(cx - 2, cy - 2, cx + 2, cy + 2);
        _ = SelectObject(hdc, old_pen);
        _ = SelectObject(hdc, old_br);
        _ = DeleteObject(dot_pen);
        _ = DeleteObject(br);
    }
}

fn threadTitleBandRightFor(win_w: i32) i32 {
    if (app_state.g_chat_active) return @min(chatViewLayout().transcript.right, @import("window_frame.zig").controlsRect(win_w).left);
    if (browserSlotReserved()) {
        if (calcBrowserLayout()) |layout| {
            return @min(win_w, layout.splitter_left);
        }
    }
    return @import("window_frame.zig").controlsRect(win_w).left;
}

pub fn threadTitleNameRectFor(win_w: i32, shell_idx: u32) ?RECT {
    const th = threadTitleHeight();
    if (th == 0 or shell_idx >= app_state.shell_count) return null;
    const title_top = threadTitleTop();
    const sw = SIDEBAR_W();
    const band_right = threadTitleBandRightFor(win_w);
    const band_w = band_right - sw;
    if (band_w <= 0) return null;

    var text_left: i32 = if (app_state.g_chat_active) chatViewLayout().transcript.left else contentHeaderLeft();
    if (app_state.shells[shell_idx].ai_agent != 0) text_left += 30;

    const now = GetTickCount64();
    const cap_msg = app_state.g_account_reauth or app_state.g_cap_msg_until > now;
    const voice_status = !cap_msg and app_state.g_chat_active and app_state.g_voice_mode_active;
    const right_margin: i32 = if (cap_msg) 360 else if (voice_status) 200 else if (browserSlotReserved()) 16 else 120;
    const title_right = band_right - right_margin - 8;
    if (title_right <= text_left + 20) return null;

    return RECT{ .left = text_left, .top = title_top, .right = title_right, .bottom = title_top + th };
}

pub const ChatTitleLayout = struct {
    pill: RECT,
    more: RECT,
    icon: RECT,
    has_icon: bool,
    text: RECT,
    meta_pill: RECT,
    meta_text: RECT,
    has_meta: bool,
    meta_warn: bool,
};

fn measureTitleText(font: HANDLE, text: []const u16) i32 {
    if (app_state.g_main_hwnd == null or text.len == 0) return 0;
    const dc = @import("win32.zig").GetDC(app_state.g_main_hwnd);
    if (dc == null) return 0;
    defer _ = @import("win32.zig").ReleaseDC(app_state.g_main_hwnd, dc);
    const old = SelectObject(dc, font);
    defer _ = SelectObject(dc, old);
    var size: @import("win32.zig").SIZE = undefined;
    if (@import("win32.zig").GetTextExtentPoint32W(dc, text.ptr, @intCast(text.len), &size) == 0) return 0;
    return size.cx;
}

fn chatTitleMetaText() []const u16 {
    const cap_msg = app_state.g_account_reauth or app_state.g_cap_msg_until > GetTickCount64();
    if (cap_msg) {
        if (app_state.g_account_reauth) {
            return std.mem.span(L("Sign in again: Ctrl+K > Sign in to multiprompt"));
        }
        if (app_state.g_cap_msg_len > 0) return app_state.g_cap_msg_text[0..app_state.g_cap_msg_len];
        return std.mem.span(L("Tab limit reached (256) - close a tab"));
    }
    if (app_state.g_chat_active and app_state.g_voice_mode_active) return std.mem.span(@import("voice.zig").voiceStatusLabel());
    return &.{};
}

pub fn chatTitleLayout() ?ChatTitleLayout {
    const th = threadTitleHeight();
    if (th == 0 or app_state.active_shell >= app_state.shell_count or app_state.g_chat_find_open) return null;
    const shell = &app_state.shells[app_state.active_shell];
    var column = chatViewLayout().transcript;
    var client: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(app_state.g_main_hwnd, &client);
    column.right = @min(column.right, @import("window_frame.zig").controlsRect(client.right).left - uiScaled(8));
    const title_top = threadTitleTop();
    const pill_h = th - uiScaled(10);
    const pill_top = title_top + @divTrunc(th - pill_h, 2);
    const pad = uiScaled(16);
    const margin = uiScaled(12);
    var layout: ChatTitleLayout = std.mem.zeroes(ChatTitleLayout);
    layout.more = .{ .left = column.right - margin - pill_h, .top = pill_top, .right = column.right - margin, .bottom = pill_top + pill_h };
    var right_limit = layout.more.left - margin;
    const meta = chatTitleMetaText();
    if (meta.len > 0) {
        const meta_w = measureTitleText(uiFontSubtitle(), meta) + pad * 2;
        const width = @min(meta_w, @divTrunc((column.right - column.left) * 2, 5));
        const meta_h = pill_h - uiScaled(4);
        const top = pill_top + @divTrunc(pill_h - meta_h, 2);
        layout.meta_pill = .{ .left = layout.more.left - margin - width, .top = top, .right = layout.more.left - margin, .bottom = top + meta_h };
        layout.meta_text = .{ .left = layout.meta_pill.left + pad, .top = layout.meta_pill.top, .right = layout.meta_pill.right - pad, .bottom = layout.meta_pill.bottom };
        layout.has_meta = true;
        layout.meta_warn = app_state.g_account_reauth or app_state.g_cap_msg_until > GetTickCount64();
        right_limit = layout.meta_pill.left - margin;
    }
    const center = @divTrunc(column.left + column.right, 2);
    const icon_w: i32 = 0;
    const name = shell.name[0..shell.name_len];
    const text_w = measureTitleText(uiFontTitle(), name);
    const max_w = @min(column.right - column.left - margin * 2, 2 * (right_limit - center));
    if (max_w < pad * 2 + uiScaled(40)) return null;
    const width = std.math.clamp(icon_w + text_w + pad * 2, pad * 2 + uiScaled(40), max_w);
    layout.pill = .{ .left = center - @divTrunc(width, 2), .top = pill_top, .right = center - @divTrunc(width, 2) + width, .bottom = pill_top + pill_h };
    layout.has_icon = icon_w > 0;
    layout.icon = .{ .left = layout.pill.left + pad - uiScaled(2), .top = pill_top, .right = layout.pill.left + pad - uiScaled(2) + uiScaled(24), .bottom = pill_top + pill_h };
    layout.text = .{ .left = layout.pill.left + pad + icon_w, .top = pill_top, .right = layout.pill.right - pad, .bottom = pill_top + pill_h };
    return layout;
}

pub fn chatTitleHoleRect(win_w: i32) ?RECT {
    if (reconnectButtonRect(win_w) != null) {
        const column = chatViewLayout().transcript;
        return .{ .left = column.left, .top = threadTitleTop(), .right = column.right, .bottom = threadTitleTop() + threadTitleHeight() };
    }
    return null;
}

fn paintMoreButton(hdc: HANDLE, more: RECT, border: u32, fill: u32, edge: i32) void {
    const fillRoundRectAA = @import("chat_render.zig").fillRoundRectAA;
    const radius = @divTrunc(more.bottom - more.top, 2);
    fillRoundRectAA(hdc, more, radius, border);
    fillRoundRectAA(hdc, .{ .left = more.left + edge, .top = more.top + edge, .right = more.right - edge, .bottom = more.bottom - edge }, radius - edge, fill);
    const dot = @max(2, uiScaled(3));
    const step = dot * 2 + @max(1, uiScaled(1));
    const cx = @divTrunc(more.left + more.right, 2);
    const cy = @divTrunc(more.top + more.bottom, 2);
    const ink: u32 = if (app_state.g_light_theme) RGB(20, 20, 20) else RGB(242, 242, 242);
    var i: i32 = -1;
    while (i <= 1) : (i += 1) {
        const x = cx + i * step - @divTrunc(dot, 2);
        fillRoundRectAA(hdc, .{ .left = x, .top = cy - @divTrunc(dot, 2), .right = x + dot, .bottom = cy - @divTrunc(dot, 2) + dot }, @divTrunc(dot, 2), ink);
    }
}

fn paintChatTitlePill(hdc: HANDLE) void {
    const layout = chatTitleLayout() orelse return;
    const shell = &app_state.shells[app_state.active_shell];
    const window_layout = @import("window_layout.zig");
    @import("chat_composer.zig").refreshChatBrushes();
    const fill = app_state.g_chat_input_color;
    const border = window_layout.chatSurfaceBorderColor();
    const edge = window_layout.chatSurfaceBorderW();
    const fillRoundRectAA = @import("chat_render.zig").fillRoundRectAA;
    _ = SetBkMode(hdc, TRANSPARENT);
    fillRoundRectAA(hdc, layout.pill, @divTrunc(layout.pill.bottom - layout.pill.top, 2), border);
    fillRoundRectAA(hdc, .{ .left = layout.pill.left + edge, .top = layout.pill.top + edge, .right = layout.pill.right - edge, .bottom = layout.pill.bottom - edge }, @divTrunc(layout.pill.bottom - layout.pill.top, 2) - edge, fill);
    if (shell.name_len > 0) {
        _ = SelectObject(hdc, uiFontTitle());
        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(20, 20, 20) else if (@import("themes.zig").themeReaderDark()) tokens.ReaderForeground else RGB(255, 255, 255));
        var text = layout.text;
        _ = DrawTextW(hdc, @ptrCast(&shell.name), @intCast(shell.name_len), &text, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
    }
    paintMoreButton(hdc, layout.more, border, fill, edge);
    if (layout.has_meta) {
        const meta_r = layout.meta_pill;
        fillRoundRectAA(hdc, meta_r, @divTrunc(meta_r.bottom - meta_r.top, 2), border);
        fillRoundRectAA(hdc, .{ .left = meta_r.left + edge, .top = meta_r.top + edge, .right = meta_r.right - edge, .bottom = meta_r.bottom - edge }, @divTrunc(meta_r.bottom - meta_r.top, 2) - edge, fill);
        _ = SelectObject(hdc, uiFontSubtitle());
        const warn_col: DWORD = if (app_state.g_light_theme) RGB(150, 95, 0) else RGB(245, 170, 70);
        const dim_col: DWORD = if (app_state.g_light_theme) RGB(140, 140, 140) else RGB(110, 110, 120);
        _ = SetTextColor(hdc, if (layout.meta_warn) warn_col else dim_col);
        const meta = chatTitleMetaText();
        var text = layout.meta_text;
        _ = DrawTextW(hdc, meta.ptr, @intCast(meta.len), &text, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
    }
}

pub fn paintThreadTitle(hdc: HANDLE, win_w: i32) void {
    const th = threadTitleHeight();
    if (th == 0) return;
    if (app_state.active_shell >= app_state.shell_count) return;
    const title_top = threadTitleTop();
    const title_bottom = title_top + th;
    if (reconnectButtonRect(win_w)) |button| {
        paintDisconnectedNotice(hdc, button, title_top, title_bottom);
        return;
    }
    if (app_state.g_chat_active and @import("chat_composer.zig").chatViewOwnsInput()) {
        paintChatTitlePill(hdc);
        return;
    }
    const sw = SIDEBAR_W();
    const band_right = threadTitleBandRightFor(win_w);
    const band_w = band_right - sw;
    if (band_w <= 0) return;

    _ = SetBkMode(hdc, TRANSPARENT);

    var text_left: i32 = if (app_state.g_chat_active) chatViewLayout().transcript.left else contentHeaderLeft();
    const ag = app_state.shells[app_state.active_shell].ai_agent;
    const attention = app_state.shells[app_state.active_shell].needs_attention;
    if (attention or ag != 0) {
        var ag_rc = RECT{ .left = text_left, .top = title_top, .right = text_left + 24, .bottom = title_bottom };
        if (attention) {
            drawAttentionDot(hdc, @divTrunc(ag_rc.left + ag_rc.right, 2), @divTrunc(ag_rc.top + ag_rc.bottom, 2), 4, customColorOr("attention", RGB(80, 140, 255)));
        } else {
            drawAgentIcon(hdc, &ag_rc, ag, app_state.shells[app_state.active_shell].activity == .active);
        }
        text_left += 30;
    }

    const now = GetTickCount64();
    const cap_msg = app_state.g_account_reauth or app_state.g_cap_msg_until > now;
    const voice_status = !cap_msg and app_state.g_chat_active and app_state.g_voice_mode_active;
    const show_meta = !browserSlotReserved();
    const right_margin: i32 = if (cap_msg) 360 else if (voice_status) 200 else if (show_meta) 120 else 16;
    const right_x: i32 = band_right - right_margin;
    const dim_col: DWORD = if (app_state.g_light_theme) RGB(140, 140, 140) else RGB(110, 110, 120);
    if (cap_msg) {
        _ = SelectObject(hdc, uiFontSubtitle());
        const warn_col: DWORD = if (app_state.g_light_theme) RGB(150, 95, 0) else RGB(245, 170, 70);
        _ = SetTextColor(hdc, warn_col);
        var cap_rc = RECT{ .left = right_x, .top = title_top, .right = band_right - 8, .bottom = title_bottom };
        if (app_state.g_account_reauth) {
            _ = DrawTextW(hdc, L("Sign in again: Ctrl+K > Sign in to multiprompt"), -1, &cap_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        } else if (app_state.g_cap_msg_len > 0) {
            _ = DrawTextW(hdc, @ptrCast(&app_state.g_cap_msg_text), @intCast(app_state.g_cap_msg_len), &cap_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        } else {
            _ = DrawTextW(hdc, L("Tab limit reached (256) - close a tab"), -1, &cap_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        }
    } else if (voice_status) {
        _ = SelectObject(hdc, uiFontSubtitle());
        _ = SetTextColor(hdc, dim_col);
        var vs_rc = RECT{ .left = right_x, .top = title_top, .right = band_right - 8, .bottom = title_bottom };
        _ = DrawTextW(hdc, voiceStatusLabel(), -1, &vs_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_RIGHT | DT_END_ELLIPSIS);
    }

    var capacity_buf: [48]u16 = undefined;
    var capacity_state: CapacityState = .unknown;
    const capacity_len = if (!app_state.g_chat_active and !cap_msg and !voice_status and show_meta) activeCapacityStatus(&capacity_buf, &capacity_state) else 0;
    if (capacity_len > 0) {
        _ = SelectObject(hdc, uiFontSubtitle());
        const capacity_col: DWORD = switch (capacity_state) {
            .green => if (app_state.g_light_theme) RGB(30, 125, 70) else RGB(85, 190, 115),
            .amber => if (app_state.g_light_theme) RGB(150, 95, 0) else RGB(245, 170, 70),
            .red, .critical => RGB(235, 80, 75),
            .unknown => dim_col,
        };
        _ = SetTextColor(hdc, capacity_col);
        var capacity_rc = RECT{ .left = right_x, .top = title_top, .right = band_right - 8, .bottom = title_bottom };
        _ = DrawTextW(hdc, @ptrCast(&capacity_buf), @intCast(capacity_len), &capacity_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_RIGHT | DT_END_ELLIPSIS);
    }

    if (!app_state.g_chat_active and !cap_msg and !voice_status and show_meta) {
        if (capacity_len == 0) {
            var time_buf: [24]u16 = undefined;
            const time_len = inboxRelTime(app_state.shells[app_state.active_shell].last_active, &time_buf);
            if (time_len > 0) {
                _ = SelectObject(hdc, uiFontSubtitle());
                _ = SetTextColor(hdc, dim_col);
                var t_rc = RECT{ .left = right_x, .top = title_top, .right = band_right - 8, .bottom = title_bottom };
                _ = DrawTextW(hdc, @ptrCast(&time_buf), @intCast(time_len), &t_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
            }
        }
    }

    if (threadTitleNameRectFor(win_w, app_state.active_shell)) |title_rc| {
        if (app_state.shells[app_state.active_shell].name_len > 0) {
            const title_col: DWORD = if (app_state.g_light_theme) RGB(20, 20, 20) else RGB(255, 255, 255);
            _ = SelectObject(hdc, uiFontThreadTitle());
            _ = SetTextColor(hdc, title_col);
            var t_rc = title_rc;
            _ = DrawTextW(hdc, @ptrCast(&app_state.shells[app_state.active_shell].name), @intCast(app_state.shells[app_state.active_shell].name_len), &t_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        }
    }
}

test "IGSH-910 active ETA leaves Chat View header pixels and title space unchanged" {
    const w = @import("win32.zig");
    const gdi = struct {
        extern "gdi32" fn GdiFlush() callconv(w.WINAPI) w.BOOL;
    };
    const saved = .{
        .hwnd = app_state.g_main_hwnd,
        .shell = app_state.shells[0],
        .count = app_state.shell_count,
        .active = app_state.active_shell,
        .chat = app_state.g_chat_active,
        .title = app_state.g_thread_title,
        .numbers = app_state.g_eta_numbers_on,
        .light = app_state.g_light_theme,
        .reauth = app_state.g_account_reauth,
        .cap_until = app_state.g_cap_msg_until,
        .voice = app_state.g_voice_mode_active,
        .scale = app_state.g_ui_scale,
        .dpi = app_state.g_main_monitor_dpi,
    };
    defer {
        app_state.g_main_hwnd = saved.hwnd;
        app_state.shells[0] = saved.shell;
        app_state.shell_count = saved.count;
        app_state.active_shell = saved.active;
        app_state.g_chat_active = saved.chat;
        app_state.g_thread_title = saved.title;
        app_state.g_eta_numbers_on = saved.numbers;
        app_state.g_light_theme = saved.light;
        app_state.g_account_reauth = saved.reauth;
        app_state.g_cap_msg_until = saved.cap_until;
        app_state.g_voice_mode_active = saved.voice;
        app_state.g_ui_scale = saved.scale;
        app_state.g_main_monitor_dpi = saved.dpi;
        resetFontCache();
    }
    const width = 1200;
    const height = 160;
    const window = w.CreateWindowExW(0, L("STATIC"), L(""), 0x80000000, 0, 0, width, height, null, null, null, null) orelse return error.TestUnexpectedResult;
    defer _ = w.DestroyWindow(window);
    app_state.g_main_hwnd = window;
    app_state.shell_count = 1;
    app_state.active_shell = 0;
    app_state.shells[0] = app_state.empty_shell;
    const title = std.unicode.utf8ToUtf16LeStringLiteral("My working session");
    @memcpy(app_state.shells[0].name[0..title.len], title);
    app_state.shells[0].name_len = title.len;
    app_state.g_chat_active = true;
    app_state.g_thread_title = true;
    app_state.g_eta_numbers_on = true;
    app_state.g_light_theme = false;
    app_state.g_account_reauth = false;
    app_state.g_cap_msg_until = 0;
    app_state.g_voice_mode_active = false;
    app_state.g_ui_scale = 100;
    app_state.g_main_monitor_dpi = 96;
    resetFontCache();
    const dc = w.CreateCompatibleDC(null) orelse return error.TestUnexpectedResult;
    defer _ = w.DeleteDC(dc);
    const info = w.BITMAPINFO{ .header = .{ .width = width, .height = -height } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0) orelse return error.TestUnexpectedResult;
    defer _ = w.DeleteObject(bitmap);
    const old_bitmap = w.SelectObject(dc, bitmap);
    defer _ = w.SelectObject(dc, old_bitmap);
    const pixels = @as([*]u8, @ptrCast(bits.?))[0 .. width * height * 4];
    const idle = try std.testing.allocator.alloc(u8, pixels.len);
    defer std.testing.allocator.free(idle);
    var idle_rect: RECT = undefined;
    for ([_]bool{ false, true }) |eta_active| {
        app_state.shells[0].eta_total_ms = if (eta_active) 120_000 else 0;
        app_state.shells[0].eta_deadline_tick = GetTickCount64() + 120_000;
        @memset(pixels, 0);
        paintThreadTitle(dc, width);
        _ = gdi.GdiFlush();
        const title_rect = (if (chatTitleLayout()) |pill_layout| pill_layout.text else threadTitleNameRectFor(width, 0)) orelse return error.TestUnexpectedResult;
        var ink: usize = 0;
        var y = title_rect.top;
        while (y < title_rect.bottom) : (y += 1) {
            var x = title_rect.left;
            while (x < @min(title_rect.left + 160, title_rect.right)) : (x += 1) {
                if ((w.GetPixel(dc, x, y) & 0xffffff) != 0) ink += 1;
            }
        }
        try std.testing.expect(ink > 20);
        const bmp = try std.testing.allocator.alloc(u8, 54 + pixels.len);
        defer std.testing.allocator.free(bmp);
        @memset(bmp[0..54], 0);
        @memcpy(bmp[0..2], "BM");
        std.mem.writeInt(u32, bmp[2..6], @intCast(bmp.len), .little);
        std.mem.writeInt(u32, bmp[10..14], 54, .little);
        @memcpy(bmp[14..54], std.mem.asBytes(&info.header));
        @memcpy(bmp[54..], pixels);
        try std.testing.expect(@import("file_io.zig").writeFileAtomicW(if (eta_active) "chat-header-eta-active.bmp" else "chat-header-eta-idle.bmp", bmp));
        if (!eta_active) {
            @memcpy(idle, pixels);
            idle_rect = title_rect;
        } else {
            var changed: usize = 0;
            for (idle, pixels) |a, b| {
                if (a != b) changed += 1;
            }
            std.debug.print("IGSH-910 header changed bytes={d}, title ink={d}\n", .{ changed, ink });
            try std.testing.expectEqual(@as(usize, 0), changed);
            try std.testing.expectEqualDeep(idle_rect, title_rect);
        }
    }
}

pub fn paintInboxButtonTooltip(hdc: HANDLE, in_overlay: bool) void {
    if (!app_state.g_inbox_button_hover) return;
    const r = inboxButtonRect(in_overlay);
    const tip_w = uiScaled(156);
    const x = @max(uiScaled(4), r.right - tip_w);
    const y = if (in_overlay) uiScaled(46) else WS_STRIP_H + uiScaled(2);
    var tip = RECT{ .left = x, .top = y, .right = x + tip_w, .bottom = y + uiScaled(24) };
    const brush = CreateSolidBrush(themeSidebarBg());
    _ = FillRect(hdc, &tip, brush);
    _ = DeleteObject(brush);
    _ = SelectObject(hdc, uiFontSubtitle());
    _ = SetBkMode(hdc, TRANSPARENT);
    _ = SetTextColor(hdc, customColorOr("text_inactive", if (app_state.g_light_theme) RGB(65, 65, 75) else RGB(215, 215, 225)));
    tip.left += uiScaled(5);
    drawAscii(hdc, "Inbox (Alt+I)", &tip, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
}

pub fn paintInboxButton(hdc: HANDLE, in_overlay: bool) void {
    var canvas = smooth.Canvas.init(hdc);
    defer canvas.deinit();
    const r = inboxButtonRect(in_overlay);
    const bg = if (in_overlay) themeConsoleBg() else themeSidebarBg();
    const button_bg = tintColor(bg, customColorOr("accent", RGB(80, 150, 255)), if (app_state.g_inbox_button_hover) 2 else 1, if (app_state.g_inbox_button_hover) 8 else 16);
    const brush = CreateSolidBrush(button_bg);
    const pen = CreatePen(0, 1, button_bg);
    const old_brush = SelectObject(hdc, brush);
    const old_pen = SelectObject(hdc, pen);
    _ = @import("smooth.zig").drawRoundRect(hdc, r.left, r.top, r.right, r.bottom, uiScaled(7), uiScaled(7));
    _ = SelectObject(hdc, old_brush);
    _ = SelectObject(hdc, old_pen);
    _ = DeleteObject(brush);
    _ = DeleteObject(pen);

    const glyph = customColorOr("text_inactive", if (app_state.g_light_theme) RGB(65, 65, 75) else RGB(215, 215, 225));
    const width: f32 = @floatFromInt(@max(1, uiScaled(2)));
    const cx = @divTrunc(r.left + r.right, 2);
    const cy = @divTrunc(r.top + r.bottom, 2);
    canvas.strokePolyline(&.{
        .{ .x = cx - uiScaled(7), .y = cy - uiScaled(4) },
        .{ .x = cx + uiScaled(7), .y = cy - uiScaled(4) },
        .{ .x = cx + uiScaled(7), .y = cy + uiScaled(5) },
        .{ .x = cx - uiScaled(7), .y = cy + uiScaled(5) },
        .{ .x = cx - uiScaled(7), .y = cy - uiScaled(4) },
    }, glyph, width);
    canvas.strokePolyline(&.{
        .{ .x = cx - uiScaled(4), .y = cy + uiScaled(1) },
        .{ .x = cx - uiScaled(2), .y = cy + uiScaled(3) },
        .{ .x = cx + uiScaled(2), .y = cy + uiScaled(3) },
        .{ .x = cx + uiScaled(4), .y = cy + uiScaled(1) },
    }, glyph, width);

    var count: u32 = 0;
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].needs_attention and !app_state.shells[i].muted and inboxPublishesShell(&app_state.shells[i]) and
            (!app_state.g_single_window or !app_state.g_ws_snoozed[app_state.shells[i].workspace])) count += 1;
    }
    if (count > 0) {
        const blue = customColorOr("attention", RGB(60, 120, 220));
        const radius = uiScaled(if (count < 10) @as(i32, 7) else 9);
        const bx = r.right - uiScaled(2);
        const by = r.top + uiScaled(2);
        drawAttentionDot(hdc, bx, by, radius, blue);
        var buf: [12]u8 = undefined;
        const label = std.fmt.bufPrint(&buf, "{d}", .{count}) catch "";
        _ = SelectObject(hdc, uiFontSubtitle());
        _ = SetTextColor(hdc, RGB(255, 255, 255));
        var badge_rc = RECT{ .left = bx - radius, .top = by - radius, .right = bx + radius, .bottom = by + radius };
        drawAscii(hdc, label, &badge_rc, DT_SINGLELINE | DT_CENTER | DT_VCENTER);
    }
}

pub fn paintWorkspaceStrip(hdc: HANDLE, sidebar_bg: DWORD) void {
    if (!app_state.g_single_window or app_state.g_hide_sidebar or app_state.g_hide_pills) return;
    const sw = SIDEBAR_W();

    const band_brush = CreateSolidBrush(sidebar_bg);
    var band_rc = RECT{ .left = 0, .top = 0, .right = sw, .bottom = WS_STRIP_H };
    _ = FillRect(hdc, &band_rc, band_brush);
    _ = DeleteObject(band_brush);

    const font = uiFontSubtitle();
    _ = SelectObject(hdc, font);

    if (app_state.g_sidebar_collapsed) {
        _ = SetTextColor(hdc, customColorOr("accent", RGB(120, 170, 255)));
        var nbuf: [4]u8 = undefined;
        const number = std.fmt.bufPrint(&nbuf, "{d}", .{if (app_state.g_starred_workspace) @as(u32, 1) else @as(u32, app_state.g_active_workspace) + 2}) catch "";
        var nrc = RECT{ .left = 0, .top = WS_PILL_TOP, .right = sw, .bottom = WS_PILL_TOP + WS_PILL_H };
        drawAscii(hdc, number, &nrc, DT_SINGLELINE | DT_VCENTER | DT_CENTER);
        const state = if (app_state.g_starred_workspace) .unknown else workspaceCapacityState(app_state.g_active_workspace);
        if (state == .amber or state == .red or state == .critical) {
            drawAttentionDot(hdc, sw - 5, WS_PILL_TOP + 4, 3, if (state == .amber) RGB(245, 170, 70) else RGB(235, 80, 75));
        }
        return;
    }

    const accent = customColorOr("accent", RGB(80, 150, 255));
    const inactive_bg = tintColor(sidebar_bg, RGB(160, 160, 170), 1, 8);
    const text_active: DWORD = RGB(255, 255, 255);
    const text_inactive: DWORD = if (app_state.g_light_theme) RGB(90, 90, 90) else RGB(185, 185, 195);
    const pill_right = inboxButtonRect(false).left - 4;

    var x: i32 = WS_STRIP_LEFT;
    var position: u8 = 0;
    while (position <= app_state.g_lws_count) : (position += 1) {
        const is_starred = position == 0;
        const ws: u8 = if (is_starred) 0 else position - 1;
        if (!is_starred and app_state.g_ws_snoozed[ws]) continue;
        if (x + WS_PILL_W > pill_right) break;
        const is_active = if (is_starred) app_state.g_starred_workspace else !app_state.g_starred_workspace and ws == app_state.g_active_workspace;
        const pill_bg = if (is_active) accent else inactive_bg;
        const br = CreateSolidBrush(pill_bg);
        const pen = CreatePen(0, 1, pill_bg);
        const ob = SelectObject(hdc, br);
        const op = SelectObject(hdc, pen);
        _ = @import("smooth.zig").drawRoundRect(hdc, x, WS_PILL_TOP, x + WS_PILL_W, WS_PILL_TOP + WS_PILL_H, 7, 7);
        _ = SelectObject(hdc, ob);
        _ = SelectObject(hdc, op);
        _ = DeleteObject(br);
        _ = DeleteObject(pen);
        _ = SetTextColor(hdc, if (is_active) text_active else text_inactive);
        var nbuf: [4]u8 = undefined;
        const number = std.fmt.bufPrint(&nbuf, "{d}", .{position + 1}) catch "";
        var nrc = RECT{ .left = x, .top = WS_PILL_TOP, .right = x + WS_PILL_W, .bottom = WS_PILL_TOP + WS_PILL_H };
        drawAscii(hdc, number, &nrc, DT_SINGLELINE | DT_VCENTER | DT_CENTER);
        const state = if (is_starred) .unknown else workspaceCapacityState(ws);
        if (state == .amber or state == .red or state == .critical) {
            drawAttentionDot(hdc, x + WS_PILL_W - 4, WS_PILL_TOP + 4, 3, if (state == .amber) RGB(245, 170, 70) else RGB(235, 80, 75));
        }
        x += WS_PILL_W + WS_PILL_GAP;
    }

    if (app_state.g_lws_count < MAX_LWS and x + WS_PILL_W <= pill_right) {
        const add_bg = tintColor(sidebar_bg, RGB(120, 120, 130), 1, 12);
        const br = CreateSolidBrush(add_bg);
        const pen = CreatePen(0, 1, add_bg);
        const ob = SelectObject(hdc, br);
        const op = SelectObject(hdc, pen);
        _ = @import("smooth.zig").drawRoundRect(hdc, x, WS_PILL_TOP, x + WS_PILL_W, WS_PILL_TOP + WS_PILL_H, 7, 7);
        _ = SelectObject(hdc, ob);
        _ = SelectObject(hdc, op);
        _ = DeleteObject(br);
        _ = DeleteObject(pen);
        _ = SetTextColor(hdc, text_inactive);
        var pbuf = [_]u16{ '+', 0 };
        var prc = RECT{ .left = x, .top = WS_PILL_TOP, .right = x + WS_PILL_W, .bottom = WS_PILL_TOP + WS_PILL_H };
        _ = DrawTextW(hdc, @ptrCast(&pbuf), 1, &prc, DT_SINGLELINE | DT_VCENTER | DT_CENTER);
        x += WS_PILL_W + WS_PILL_GAP;
    }

    paintInboxButton(hdc, false);

    const line_col: DWORD = customColorOr("overlay_divider", if (app_state.g_light_theme) RGB(228, 228, 228) else RGB(52, 52, 52));
    const line_br = CreateSolidBrush(line_col);
    var line_rc = RECT{ .left = 4, .top = WS_STRIP_H - 1, .right = sw - 4, .bottom = WS_STRIP_H };
    _ = FillRect(hdc, &line_rc, line_br);
    _ = DeleteObject(line_br);
    paintInboxButtonTooltip(hdc, false);
    if (app_state.g_workspace_hover) |hover| {
        var name_buf: [32]u8 = undefined;
        const name = if (hover == @import("workspace_view.zig").starred) "Starred" else if (hover == app_state.WS_NEW_PILL) "New workspace" else @import("workspaces.zig").workspaceDisplayName(hover, &name_buf);
        var label_buf: [80]u8 = undefined;
        const digit: u32 = if (hover == @import("workspace_view.zig").starred) 1 else @as(u32, hover) + 2;
        const label = if (digit <= 9) std.fmt.bufPrint(&label_buf, "{s} (Alt+{d})", .{ name, digit }) catch name else name;
        var tip = RECT{ .left = 4, .top = WS_STRIP_H + 2, .right = sw - 4, .bottom = WS_STRIP_H + 26 };
        const br = CreateSolidBrush(sidebar_bg);
        _ = FillRect(hdc, &tip, br);
        _ = DeleteObject(br);
        _ = SetTextColor(hdc, text_inactive);
        drawAscii(hdc, label, &tip, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
    }
}

test "IGSH-907 Chat View header ignores capacity while terminal keeps it" {
    const w = @import("win32.zig");
    const saved_shell = app_state.shells[0];
    const saved_count = app_state.shell_count;
    const saved_active = app_state.active_shell;
    const saved_chat = app_state.g_chat_active;
    const saved_hwnd = app_state.g_main_hwnd;
    const saved_capacity = app_state.g_host_capacity[1];
    const saved_title = app_state.g_thread_title;
    defer {
        app_state.shells[0] = saved_shell;
        app_state.shell_count = saved_count;
        app_state.active_shell = saved_active;
        app_state.g_chat_active = saved_chat;
        app_state.g_main_hwnd = saved_hwnd;
        app_state.g_host_capacity[1] = saved_capacity;
        app_state.g_thread_title = saved_title;
    }
    const width = 1200;
    const height = 160;
    const hwnd = w.CreateWindowExW(0, L("STATIC"), L(""), 0x80000000, 0, 0, width, 800, null, null, null, null) orelse return error.TestUnexpectedResult;
    defer _ = w.DestroyWindow(hwnd);
    app_state.g_main_hwnd = hwnd;
    app_state.g_thread_title = true;
    app_state.shell_count = 1;
    app_state.active_shell = 0;
    app_state.shells[0] = app_state.empty_shell;
    app_state.shells[0].kind = .tmux;
    app_state.shells[0].tmux_host = 1;
    const name = std.unicode.utf8ToUtf16LeStringLiteral("Session title stays unchanged");
    @memcpy(app_state.shells[0].name[0..name.len], name);
    app_state.shells[0].name_len = name.len;
    const dc = w.CreateCompatibleDC(null) orelse return error.TestUnexpectedResult;
    defer _ = w.DeleteDC(dc);
    const info = w.BITMAPINFO{ .header = .{ .width = width, .height = -height } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0) orelse return error.TestUnexpectedResult;
    defer _ = w.DeleteObject(bitmap);
    const old_bitmap = w.SelectObject(dc, bitmap);
    defer _ = w.SelectObject(dc, old_bitmap);
    const pixels = @as([*]u8, @ptrCast(bits.?))[0 .. width * height * 4];
    const baseline = try std.testing.allocator.alloc(u8, pixels.len);
    defer std.testing.allocator.free(baseline);
    var chat_equal = false;
    var terminal_equal = true;
    for ([_]bool{ true, false }) |chat| {
        app_state.g_chat_active = chat;
        for ([_]bool{ false, true }) |amber| {
            app_state.g_host_capacity[1] = .{ .valid = true, .cores = 18, .load_milli = 8000, .state = if (amber) .amber else .unknown, .updated_tick = GetTickCount64() };
            @memset(pixels, 0);
            const brush = w.CreateSolidBrush(themeConsoleBg());
            defer _ = w.DeleteObject(brush);
            const area = RECT{ .left = 0, .top = 0, .right = width, .bottom = height };
            _ = w.FillRect(dc, &area, brush);
            paintThreadTitle(dc, width);
            _ = w.GetPixel(dc, 0, 0);
            const title = threadTitleNameRectFor(width, 0) orelse return error.TestUnexpectedResult;
            var ink: usize = 0;
            var y = title.top;
            while (y < title.bottom) : (y += 1) {
                var x = title.left;
                while (x < title.right) : (x += 1) {
                    if (w.GetPixel(dc, x, y) != themeConsoleBg()) ink += 1;
                }
            }
            try std.testing.expect(ink > 100);
            if (!amber) {
                @memcpy(baseline, pixels);
            } else {
                const equal = std.mem.eql(u8, baseline, pixels);
                if (chat) chat_equal = equal else terminal_equal = equal;
                const file = @import("file_io.zig").win32OpenWrite(if (chat) "chat-header-capacity.bmp" else "terminal-header-capacity.bmp") orelse return error.TestUnexpectedResult;
                defer _ = w.CloseHandle(file);
                var header = [_]u8{0} ** 54;
                @memcpy(header[0..2], "BM");
                std.mem.writeInt(u32, header[2..6], @intCast(header.len + pixels.len), .little);
                std.mem.writeInt(u32, header[10..14], 54, .little);
                std.mem.writeInt(u32, header[14..18], 40, .little);
                std.mem.writeInt(i32, header[18..22], width, .little);
                std.mem.writeInt(i32, header[22..26], -height, .little);
                std.mem.writeInt(u16, header[26..28], 1, .little);
                std.mem.writeInt(u16, header[28..30], 32, .little);
                @import("file_io.zig").win32WriteAll(file, &header);
                @import("file_io.zig").win32WriteAll(file, pixels);
            }
        }
    }
    std.debug.print("IGSH-907 chat_equal={} terminal_equal={}\n", .{ chat_equal, terminal_equal });
    try std.testing.expect(!terminal_equal);
    try std.testing.expect(chat_equal);
}

test "ISSUE-444 inbox button and envelope have blended edges at 100 and 150 percent" {
    const w = @import("win32.zig");
    const saved_scale = app_state.g_ui_scale;
    const saved_dpi = app_state.g_main_monitor_dpi;
    defer app_state.g_main_monitor_dpi = saved_dpi;
    app_state.g_main_monitor_dpi = 96;
    const saved_count = app_state.shell_count;
    const saved_hover = app_state.g_inbox_button_hover;
    defer app_state.g_ui_scale = saved_scale;
    defer app_state.shell_count = saved_count;
    defer app_state.g_inbox_button_hover = saved_hover;
    app_state.shell_count = 0;
    app_state.g_inbox_button_hover = false;
    const dc = w.CreateCompatibleDC(null);
    try std.testing.expect(dc != null);
    defer _ = w.DeleteDC(dc);
    const info = w.BITMAPINFO{ .header = .{ .width = 1024, .height = -256 } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0);
    try std.testing.expect(bitmap != null);
    defer _ = w.DeleteObject(bitmap);
    const old_bitmap = w.SelectObject(dc, bitmap);
    defer _ = w.SelectObject(dc, old_bitmap);
    for ([_]u32{ 100, 150 }) |scale| {
        app_state.g_ui_scale = scale;
        const rc = inboxButtonRect(false);
        const bg = themeSidebarBg();
        const button_bg = tintColor(bg, customColorOr("accent", RGB(80, 150, 255)), 1, 16);
        const brush = w.CreateSolidBrush(bg);
        defer _ = w.DeleteObject(brush);
        const area = RECT{ .left = 0, .top = 0, .right = 1024, .bottom = 256 };
        _ = w.FillRect(dc, &area, brush);
        paintInboxButton(dc, false);
        var blended_edge: usize = 0;
        var y = rc.top;
        while (y < rc.top + uiScaled(4)) : (y += 1) {
            var x = rc.left;
            while (x < rc.left + uiScaled(4)) : (x += 1) {
                const pixel = w.GetPixel(dc, x, y);
                var between = true;
                for ([_]u5{ 0, 8, 16 }) |shift| {
                    const channel = (pixel >> shift) & 0xff;
                    const a = (bg >> shift) & 0xff;
                    const b = (button_bg >> shift) & 0xff;
                    between = between and channel >= @min(a, b) and channel <= @max(a, b);
                }
                if (between and pixel != bg and pixel != button_bg) blended_edge += 1;
            }
        }
        if (blended_edge == 0) std.debug.print("ISSUE-444 inbox edge: scale={d}, blended pixels=0\n", .{scale});
        try std.testing.expect(blended_edge > 0);
        const glyph = customColorOr("text_inactive", if (app_state.g_light_theme) RGB(65, 65, 75) else RGB(215, 215, 225));
        const cx = @divTrunc(rc.left + rc.right, 2);
        const cy = @divTrunc(rc.top + rc.bottom, 2);
        var blended_glyph: usize = 0;
        y = cy;
        while (y <= cy + uiScaled(4)) : (y += 1) {
            var x = cx - uiScaled(5);
            while (x < cx + uiScaled(5)) : (x += 1) {
                const pixel = w.GetPixel(dc, x, y);
                var between = true;
                for ([_]u5{ 0, 8, 16 }) |shift| {
                    const channel = (pixel >> shift) & 0xff;
                    const a = (button_bg >> shift) & 0xff;
                    const b = (glyph >> shift) & 0xff;
                    between = between and channel >= @min(a, b) and channel <= @max(a, b);
                }
                if (between and pixel != button_bg and pixel != glyph) blended_glyph += 1;
            }
        }
        try std.testing.expect(blended_glyph > 0);
        try std.testing.expectEqual(bg, w.GetPixel(dc, rc.right, rc.top));
        try std.testing.expectEqual(bg, w.GetPixel(dc, rc.left, rc.bottom));
    }
}

pub fn reconnectTabVisible(idx: u32) bool {
    return idx < app_state.shell_count and idx == app_state.active_shell and
        (!app_state.g_single_window or app_state.shells[idx].workspace == app_state.g_active_workspace) and
        !app_state.g_search_active and !app_state.g_inbox_active and !app_state.g_all_sessions_active and
        !app_state.g_shortcuts_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and
        !app_state.g_snippet_create_active and !app_state.g_restoring and !app_state.g_account_locked;
}

pub fn invalidateReconnectContent(idx: u32) void {
    if (!@import("ssh_reconnect.zig").eventEffects(reconnectTabVisible(idx)).invalidate_content) return;
    var rc: RECT = undefined;
    if (GetClientRect(app_state.g_main_hwnd, &rc) == 0) return;
    rc.left = SIDEBAR_W();
    rc.top = threadTitleTop();
    rc.right = threadTitleBandRightFor(rc.right);
    if (app_state.g_chat_active) rc.bottom = threadTitleTop() + threadTitleHeight();
    _ = InvalidateRect(app_state.g_main_hwnd, &rc, 0);
}

pub fn reconnectButtonRect(win_w: i32) ?RECT {
    if (app_state.active_shell >= app_state.shell_count or !app_state.shells[app_state.active_shell].disconnected) return null;
    const shell = app_state.shells[app_state.active_shell];
    if (shell.kind != .tmux and shell.kind != .vps and shell.kind != .vps2) return null;
    const right = threadTitleBandRightFor(win_w) - uiScaled(8);
    return .{ .left = @max(SIDEBAR_W(), right - uiScaled(if (shell.ssh_reconnect.phase == .ended) 152 else 96)), .top = threadTitleTop() + uiScaled(3), .right = right, .bottom = threadTitleTop() + threadTitleHeight() - uiScaled(3) };
}

fn paintDisconnectedNotice(hdc: HANDLE, button: RECT, top: i32, bottom: i32) void {
    const shell = app_state.shells[app_state.active_shell];
    _ = SetBkMode(hdc, TRANSPARENT);
    const old_font = SelectObject(hdc, uiFontSubtitle());
    defer _ = SelectObject(hdc, old_font);
    _ = SetTextColor(hdc, customColorOr("warning", if (app_state.g_light_theme) RGB(150, 95, 0) else RGB(245, 170, 70)));
    var buf: [192]u8 = undefined;
    const now = GetTickCount64();
    const seconds = (shell.ssh_reconnect.next_tick -| now + 999) / 1000;
    const text = if (shell.ssh_reconnect.phase == .ended)
        "Session ended"
    else if (shell.ssh_reconnect.noticeReason(now, shell.disconnected)) |reason|
        std.fmt.bufPrint(&buf, "{s} disconnected: {s} - Ctrl+Shift+R to reconnect", .{ if (shell.pinned_top) "Pinned session" else "Session", reason }) catch "Reconnecting..."
    else if (shell.ssh_reconnect.phase == .reconnecting)
        "Reconnecting..."
    else
        std.fmt.bufPrint(&buf, "Reconnecting in {d}s", .{seconds}) catch "Reconnecting...";
    var notice = RECT{ .left = SIDEBAR_W() + uiScaled(16), .top = top, .right = button.left - uiScaled(8), .bottom = bottom };
    drawAscii(hdc, text, &notice, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
    const brush = CreateSolidBrush(customColorOr("button_bg", if (app_state.g_light_theme) RGB(220, 225, 232) else RGB(60, 65, 75)));
    var rc = button;
    _ = FillRect(hdc, &rc, brush);
    _ = DeleteObject(brush);
    _ = SetTextColor(hdc, themeConsoleFg());
    _ = DrawTextW(hdc, if (shell.ssh_reconnect.phase == .ended) L("Start new session") else L("Reconnect"), -1, &rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
}

pub fn paintDisconnectedShell(hdc: HANDLE) void {
    if (app_state.g_chat_active or app_state.g_search_active or app_state.g_inbox_active or app_state.g_all_sessions_active or app_state.g_shortcuts_active or app_state.g_changelog_active or app_state.g_url_picker_active or app_state.g_snippet_create_active) return;
    var client: RECT = undefined;
    _ = GetClientRect(app_state.g_main_hwnd, &client);
    const launch_failed = app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].launch_failed;
    if (!launch_failed and reconnectButtonRect(client.right) == null) return;
    var rc = RECT{ .left = SIDEBAR_W() + uiScaled(16), .top = threadTitleTop() + threadTitleHeight() + uiScaled(40), .right = threadTitleBandRightFor(client.right) - uiScaled(16), .bottom = threadTitleTop() + threadTitleHeight() + uiScaled(100) };
    _ = SetBkMode(hdc, TRANSPARENT);
    const old_font = SelectObject(hdc, uiFontTitle());
    defer _ = SelectObject(hdc, old_font);
    _ = SetTextColor(hdc, themeConsoleFg());
    _ = DrawTextW(hdc, if (launch_failed) L("Terminal could not start. Close this tab and try again.") else if (app_state.shells[app_state.active_shell].ssh_reconnect.phase == .ended) L("Session ended") else L("Disconnected. Your session will reconnect automatically."), -1, &rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
}

test "ISSUE-444 paint backbuffer exposes pixels so smooth shapes avoid full-surface transfers" {
    const w = @import("win32.zig");
    const Bitmap = extern struct { kind: i32, width: i32, height: i32, stride: i32, planes: u16, bits_pixel: u16, bits: ?*anyopaque };
    resetPaintBackbuffer();
    defer resetPaintBackbuffer();
    const screen = w.GetDC(null);
    try std.testing.expect(screen != null);
    defer _ = w.ReleaseDC(null, screen);
    for ([_][2]i32{ .{ 1250, 950 }, .{ 1251, 950 }, .{ 1251, 950 } }) |size| {
        const dc = ensurePaintBackbuffer(screen, size[0], size[1]);
        try std.testing.expect(dc != null);
        var bitmap: Bitmap = undefined;
        try std.testing.expect(w.GetObjectW(w.GetCurrentObject(dc, 7), @sizeOf(Bitmap), &bitmap) != 0);
        try std.testing.expect(bitmap.width >= size[0]);
        try std.testing.expect(bitmap.height >= size[1]);
        try std.testing.expectEqual(@as(u16, 32), bitmap.bits_pixel);
        try std.testing.expect(bitmap.bits != null);
        const area = RECT{ .left = 0, .top = 0, .right = size[0], .bottom = size[1] };
        const brush = CreateSolidBrush(0x123456);
        defer _ = DeleteObject(brush);
        _ = FillRect(dc, &area, brush);
        var canvas = smooth.Canvas.init(dc);
        defer canvas.deinit();
        try std.testing.expect(canvas.graphics != null);
        var nested = smooth.Canvas.init(dc);
        try std.testing.expectEqual(canvas.graphics, nested.graphics);
        nested.deinit();
        smooth.fillRoundRect(dc, .{ .left = 10, .top = 10, .right = 42, .bottom = 38 }, 4, 0xffffff);
        try std.testing.expectEqual(@as(u32, 0xffffff), w.GetPixel(dc, 20, 20));
        try std.testing.expectEqual(@as(u32, 0x123456), w.GetPixel(dc, 10, 10));
        const pixels: [*]const u32 = @ptrCast(@alignCast(bitmap.bits.?));
        try std.testing.expectEqual(@as(u32, 0xffffff), pixels[@intCast(20 * @divTrunc(bitmap.stride, 4) + 20)] & 0xffffff);
    }
}

test "ISSUE-444 repaint and nearby resizes reuse one graphics and refresh its clipping" {
    const w = @import("win32.zig");
    const Probe = struct {
        var create: @TypeOf(app_state.g_gdip_api.create_from_hdc) = undefined;
        var count: usize = 0;
        fn graphics(dc: HANDLE, result: *HANDLE) callconv(w.WINAPI) app_state.GpStatus {
            count += 1;
            return create(dc, result);
        }
    };
    try std.testing.expect(smooth.gdipLoad());
    Probe.create = app_state.g_gdip_api.create_from_hdc;
    Probe.count = 0;
    app_state.g_gdip_api.create_from_hdc = Probe.graphics;
    defer app_state.g_gdip_api.create_from_hdc = Probe.create;
    resetPaintBackbuffer();
    defer resetPaintBackbuffer();
    const screen = w.GetDC(null);
    try std.testing.expect(screen != null);
    defer _ = w.ReleaseDC(null, screen);
    const brush = CreateSolidBrush(0x123456);
    defer _ = DeleteObject(brush);
    var graphics: HANDLE = null;
    for ([_]i32{ 1250, 1251, 1250 }, 0..) |width, frame| {
        const dc = ensurePaintBackbuffer(screen, width, 950);
        try std.testing.expect(dc != null);
        const area = RECT{ .left = 0, .top = 0, .right = width, .bottom = 950 };
        _ = FillRect(dc, &area, brush);
        const saved = w.SaveDC(dc);
        try std.testing.expect(saved != 0);
        if (frame == 0) _ = w.IntersectClipRect(dc, 10, 10, 30, 38);
        const canvas = beginPaintCanvas();
        try std.testing.expect(canvas.graphics != null);
        if (frame == 0) graphics = canvas.graphics;
        try std.testing.expectEqual(graphics, canvas.graphics);
        smooth.fillRoundRect(dc, .{ .left = 10, .top = 10, .right = 42, .bottom = 38 }, 4, 0xffffff);
        canvas.deactivate();
        _ = w.RestoreDC(dc, saved);
        try std.testing.expectEqual(@as(u32, 0xffffff), w.GetPixel(dc, 20, 20));
        try std.testing.expectEqual(@as(u32, if (frame == 0) 0x123456 else 0xffffff), w.GetPixel(dc, 35, 20));
        try std.testing.expectEqual(@as(usize, 1), Probe.count);
    }
    try std.testing.expect(ensurePaintBackbuffer(screen, 1500, 950) != null);
    try std.testing.expectEqual(@as(usize, 2), Probe.count);
}
