const app_state = @import("app_state.zig");
const std = @import("std");
const LOOK_UNIFIED = @import("main.zig").LOOK_UNIFIED;
const DWORD = @import("win32.zig").DWORD;
const HANDLE = @import("win32.zig").HANDLE;
const WS_VSCROLL = @import("win32.zig").WS_VSCROLL;
const WS_HSCROLL = @import("win32.zig").WS_HSCROLL;
const GWL_STYLE = @import("win32.zig").GWL_STYLE;
const SWP_FRAMECHANGED = @import("win32.zig").SWP_FRAMECHANGED;
const SWP_NOZORDER = @import("win32.zig").SWP_NOZORDER;
const SW_HIDE = @import("win32.zig").SW_HIDE;
const DT_SINGLELINE = @import("win32.zig").DT_SINGLELINE;
const DT_VCENTER = @import("win32.zig").DT_VCENTER;
const DT_CENTER = @import("win32.zig").DT_CENTER;
const DT_NOPREFIX = @import("win32.zig").DT_NOPREFIX;
const DT_END_ELLIPSIS = @import("win32.zig").DT_END_ELLIPSIS;
const TRANSPARENT = @import("win32.zig").TRANSPARENT;
const RECT = @import("win32.zig").RECT;
const IsIconic = @import("win32.zig").IsIconic;
const IsWindowVisible = @import("win32.zig").IsWindowVisible;
const GetClientRect = @import("win32.zig").GetClientRect;
const MoveWindow = @import("win32.zig").MoveWindow;
const SetWindowLongPtrW = @import("win32.zig").SetWindowLongPtrW;
const GetWindowLongPtrW = @import("win32.zig").GetWindowLongPtrW;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const DrawTextW = @import("win32.zig").DrawTextW;
const GetWindowTextLengthW = @import("win32.zig").GetWindowTextLengthW;
const CreateSolidBrush = @import("win32.zig").CreateSolidBrush;
const DeleteObject = @import("win32.zig").DeleteObject;
const SetBkMode = @import("win32.zig").SetBkMode;
const SetTextColor = @import("win32.zig").SetTextColor;
const SelectObject = @import("win32.zig").SelectObject;
const CreateFontW = @import("fonts.zig").create;
const CreateRoundRectRgn = @import("win32.zig").CreateRoundRectRgn;
const SetWindowRgn = @import("win32.zig").SetWindowRgn;
const CreatePen = @import("win32.zig").CreatePen;
const L = @import("startup.zig").L;
const RGB = @import("startup.zig").RGB;
const ensureDevThemeInitialized = @import("themes.zig").ensureDevThemeInitialized;
const customColorOr = @import("themes.zig").customColorOr;
const SIDEBAR_W = @import("browser_pane.zig").SIDEBAR_W;
const SHELL_PAD = @import("app_state.zig").SHELL_PAD;
const tabRowH = @import("browser_pane.zig").tabRowH;
const DEV_TOP_PAD = @import("app_state.zig").DEV_TOP_PAD;
const threadTitleHeight = @import("browser_pane.zig").threadTitleHeight;
const threadTitleTop = @import("browser_pane.zig").threadTitleTop;
const tabRowY = @import("sidebar.zig").tabRowY;
const ShowWindow = @import("focus.zig").ShowWindow;
const ShowWindowAsync = @import("focus.zig").ShowWindowAsync;
const SetWindowPos = @import("focus.zig").SetWindowPos;
const verboseLoggingEnabled = @import("diagnostics.zig").verboseLoggingEnabled;
const debugLog = @import("diagnostics.zig").debugLog;
const fontGenStale = @import("console.zig").fontGenStale;
const fontSyncShell = @import("console.zig").fontSyncShell;
const verifyShellWindowSize = @import("focus.zig").verifyShellWindowSize;
const consoleEdgePad = @import("browser_pane.zig").consoleEdgePad;
const consoleCellW = @import("browser_pane.zig").consoleCellW;
const centeredConsoleColumn = @import("browser_pane.zig").centeredConsoleColumn;
const browserSlotReserved = @import("browser_pane.zig").browserSlotReserved;
const calcBrowserLayout = @import("browser_pane.zig").calcBrowserLayout;
const positionActiveBrowser = @import("browser_pane.zig").positionActiveBrowser;
const hideAllBrowserChrome = @import("browser_pane.zig").hideAllBrowserChrome;
const paneFocusInset = @import("browser_pane.zig").paneFocusInset;
const webView2OwnsActiveShell = @import("browser_pane.zig").webView2OwnsActiveShell;
const positionWebView2 = @import("browser_pane.zig").positionWebView2;
const chatViewLayout = @import("chat_composer.zig").chatViewLayout;
const chatViewOwnsInput = @import("chat_composer.zig").chatViewOwnsInput;
const ensureChatFont = @import("chat_composer.zig").ensureChatFont;
const refreshChatBrushes = @import("chat_composer.zig").refreshChatBrushes;
const CHAT_BUBBLE_RADIUS = @import("app_state.zig").CHAT_BUBBLE_RADIUS;
const fillRoundRectAA = @import("chat_render.zig").fillRoundRectAA;
const paintChatAttachButton = @import("chat_render.zig").paintChatAttachButton;
const layoutChatControls = @import("chat_composer.zig").layoutChatControls;
const shellConsoleShouldBeVisible = @import("chat_composer.zig").shellConsoleShouldBeVisible;
const CHAT_WORKING_GENERIC = @import("app_state.zig").CHAT_WORKING_GENERIC;
const uiScaled = @import("drawing.zig").uiScaled;

pub fn paneOuterMargin() i32 {
    return uiScaled(8);
}

pub fn paneGap() i32 {
    return uiScaled(8);
}

pub const PaneRects = struct {
    sidebar: RECT,
    burn: RECT,
    primary: RECT,
    browser: RECT,
    splitter: RECT,
};

pub fn clampPaneSplitWidth(available: i32, width: i32) i32 {
    const min_side = @min(uiScaled(200), @divTrunc(available, 2));
    return std.math.clamp(width, min_side, available - min_side);
}

pub fn paneRects(client: RECT, sidebar_w: i32, browser: bool, split_permille: u32, burn_h: i32) PaneRects {
    const margin = paneOuterMargin();
    const gap = paneGap();
    const sidebar = RECT{ .left = margin, .top = margin, .right = @max(margin, sidebar_w - @divTrunc(gap, 2)), .bottom = client.bottom - margin };
    var primary = RECT{ .left = if (sidebar_w > 0) sidebar.right + gap else margin, .top = margin, .right = client.right - margin, .bottom = client.bottom - margin };
    var browser_rect = RECT{ .left = primary.right, .top = margin, .right = primary.right, .bottom = primary.bottom };
    var splitter = browser_rect;
    if (browser) {
        const available = @max(0, primary.right - primary.left - gap);
        const width = clampPaneSplitWidth(available, @divTrunc(available * @as(i32, @intCast(split_permille)), 1000));
        primary.right = primary.left + width;
        browser_rect.left = primary.right + gap;
        splitter.left = primary.right;
        splitter.right = browser_rect.left;
    }
    return .{
        .sidebar = sidebar,
        .burn = .{ .left = sidebar.left, .top = sidebar.bottom - burn_h, .right = sidebar.right, .bottom = sidebar.bottom },
        .primary = primary,
        .browser = browser_rect,
        .splitter = splitter,
    };
}

pub fn activePaneRects(client: RECT) PaneRects {
    return paneRects(client, SIDEBAR_W(), browserSlotReserved(), @import("browser_pane.zig").browserSplitPermilleForActiveShell(), uiScaled(if (app_state.g_sidebar_collapsed) app_state.SIDEBAR_STICKY_CARD_COLLAPSED_H else app_state.SIDEBAR_STICKY_CARD_H));
}

pub fn activePaneContentRect(client: RECT) RECT {
    const pane = activePaneRects(client).primary;
    const inset = paneFocusInset();
    return .{
        .left = pane.left + inset,
        .top = pane.top + inset,
        .right = pane.right - inset,
        .bottom = pane.bottom - inset,
    };
}

pub fn repositionActive() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    if (app_state.shells[app_state.active_shell].hwnd == null or app_state.g_main_hwnd == null) return;
    if (!shellConsoleShouldBeVisible(app_state.active_shell) and IsWindowVisible(app_state.shells[app_state.active_shell].hwnd) != 0) _ = ShowWindowAsync(app_state.shells[app_state.active_shell].hwnd, SW_HIDE);
    if (IsIconic(app_state.g_main_hwnd) != 0) return;
    if (app_state.g_webview2_active) {
        if (app_state.g_webview2_set_visible) |set_visible|
            set_visible(if (webView2OwnsActiveShell()) 1 else 0);
    }
    if (app_state.g_all_sessions_active) {
        _ = ShowWindow(app_state.shells[app_state.active_shell].hwnd, SW_HIDE);
        hideAllBrowserChrome();
        return;
    }
    if (app_state.g_chat_active) {
        if (app_state.g_chat_browser_swap.shell_id == 0 and IsWindowVisible(app_state.shells[app_state.active_shell].hwnd) != 0) _ = ShowWindowAsync(app_state.shells[app_state.active_shell].hwnd, SW_HIDE);
        if (app_state.g_chat_browser_swap.shell_id == 0) {
            if (browserSlotReserved()) {
                if (webView2OwnsActiveShell()) positionWebView2() else positionActiveBrowser();
            } else {
                hideAllBrowserChrome();
            }
        }
        layoutChatControls();
        return;
    }
    if (!shellConsoleShouldBeVisible(app_state.active_shell)) return;
    if (fontGenStale(app_state.shells[app_state.active_shell].font_gen, app_state.g_font_gen)) _ = fontSyncShell(app_state.active_shell);
    const nudge = app_state.g_nudge_repaint;
    app_state.g_nudge_repaint = false;
    var rc: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(app_state.g_main_hwnd, &rc);
    if (verboseLoggingEnabled()) {
        var lbuf: [128]u8 = undefined;
        const ls = std.fmt.bufPrint(&lbuf, "[reposition] client={d}x{d} sidebar={d}", .{ rc.right, rc.bottom, SIDEBAR_W() }) catch "";
        debugLog(ls);
    }
    if (LOOK_UNIFIED) {
        ensureDevThemeInitialized();
        const pane = activePaneContentRect(rc);
        const con_top = pane.top + threadTitleHeight();
        const h = pane.bottom - con_top;
        const sh = app_state.shells[app_state.active_shell].hwnd;
        var st = GetWindowLongPtrW(sh, GWL_STYLE);
        st &= ~@as(isize, @intCast(WS_VSCROLL | WS_HSCROLL));
        _ = SetWindowLongPtrW(sh, GWL_STYLE, st);
        const col = centeredConsoleColumn(pane.right, pane.left, 0, consoleCellW());
        const full_width = app_state.shells[app_state.active_shell].full_width;
        const w = if (full_width) pane.right - pane.left else col.width;
        const left = if (full_width) pane.left else col.left;
        _ = SetWindowRgn(sh, null, 1);
        if (nudge) _ = SetWindowPos(sh, null, left, con_top, w, h - 1, SWP_FRAMECHANGED | SWP_NOZORDER);
        _ = SetWindowPos(sh, null, left, con_top, w, h, SWP_FRAMECHANGED | SWP_NOZORDER);
        verifyShellWindowSize(sh, left, con_top, w, h);
        if (browserSlotReserved()) {
            if (webView2OwnsActiveShell()) positionWebView2() else positionActiveBrowser();
        }
        return;
    }
    const pad: i32 = SHELL_PAD;
    const w = rc.right - SIDEBAR_W() - pad * 2;
    const h = rc.bottom - pad * 2;
    _ = MoveWindow(app_state.shells[app_state.active_shell].hwnd, SIDEBAR_W() + pad, pad, w, h, 1);
    const corner: i32 = 12;
    const rgn = CreateRoundRectRgn(0, 0, w, h, corner, corner);
    if (rgn != null) _ = SetWindowRgn(app_state.shells[app_state.active_shell].hwnd, rgn, 1);
}

pub fn invalidateSidebar() void {
    if (threadTitleHeight() > 0) {
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
        return;
    }
    var rc = RECT{ .left = 0, .top = 0, .right = SIDEBAR_W(), .bottom = 2000 };
    _ = InvalidateRect(app_state.g_main_hwnd, &rc, 0);
}

fn paintChatButton(hdc: HANDLE, rc: RECT, enabled: bool, glyph: enum { send, stop }) void {
    const hover = glyph == .stop and app_state.g_chat_stop_hover;
    const grey: u8 = if (app_state.g_light_theme) (if (hover) 128 else 104) else (if (hover) 84 else 64);
    const bg = if (enabled) RGB(grey, grey, grey) else customColorOr("overlay_input_bg", if (app_state.g_light_theme) RGB(236, 238, 243) else RGB(38, 42, 52));
    const brush = CreateSolidBrush(bg);
    const pen = CreatePen(0, 1, bg);
    const old_brush = SelectObject(hdc, brush);
    const old_pen = SelectObject(hdc, pen);
    const radius = rc.bottom - rc.top;
    _ = @import("smooth.zig").drawRoundRect(hdc, rc.left, rc.top, rc.right, rc.bottom, radius, radius);
    _ = SelectObject(hdc, old_brush);
    _ = SelectObject(hdc, old_pen);
    _ = DeleteObject(brush);
    _ = DeleteObject(pen);
    const ink = if (enabled)
        (if (app_state.g_light_theme) RGB(255, 255, 255) else RGB(235, 235, 235))
    else
        customColorOr("subtitle", if (app_state.g_light_theme) RGB(150, 155, 165) else RGB(110, 116, 128));
    if (glyph == .stop) {
        const side = @max(uiScaled(8), @divTrunc((rc.bottom - rc.top) * 34, 100));
        const left = rc.left + @divTrunc(rc.right - rc.left - side, 2);
        const top = rc.top + @divTrunc(rc.bottom - rc.top - side, 2);
        fillRoundRectAA(hdc, .{ .left = left, .top = top, .right = left + side, .bottom = top + side }, uiScaled(2), ink);
        return;
    }
    const glyph_h = @max(uiScaled(10), @divTrunc((rc.bottom - rc.top) * 42, 100));
    const glyph_font = CreateFontW(-glyph_h, 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 5, 0, L("Segoe UI Symbol"));
    const old_font = SelectObject(hdc, glyph_font);
    _ = SetTextColor(hdc, ink);
    var text_rc = rc;
    _ = DrawTextW(hdc, L("\u{25B6}"), -1, &text_rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
    _ = SelectObject(hdc, old_font);
    _ = DeleteObject(glyph_font);
}

fn paintChatMicButton(hdc: HANDLE, rc: RECT) void {
    const active = @import("chat_composer.zig").chat_dictation_state != .idle;
    const ink = if (active) customColorOr("accent", RGB(80, 150, 255)) else customColorOr("subtitle", if (app_state.g_light_theme) RGB(112, 117, 128) else RGB(137, 146, 164));
    const base = app_state.g_chat_input_color;
    const fill = if (active) customColorOr("selected_bg", if (app_state.g_light_theme) RGB(222, 235, 252) else RGB(63, 83, 113)) else @import("chat_style.zig").shift(base, if (@import("chat_style.zig").isDark(base)) 22 else -14);
    @import("smooth.zig").fillEllipse(hdc, rc, fill);
    const font = @import("fonts.zig").messageMenuIconFont();
    const old_font = SelectObject(hdc, font);
    defer {
        _ = SelectObject(hdc, old_font);
        _ = DeleteObject(font);
    }
    _ = SetTextColor(hdc, ink);
    var text_rc = rc;
    _ = DrawTextW(hdc, L("\u{E720}"), -1, &text_rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
}

pub fn chatSurfaceRadius() i32 {
    return uiScaled(CHAT_BUBBLE_RADIUS);
}

pub fn chatSurfaceBorderW() i32 {
    return @max(1, uiScaled(1));
}

pub fn chatSurfaceBorderColor() DWORD {
    return customColorOr("overlay_border", if (app_state.g_light_theme) RGB(226, 229, 234) else RGB(41, 45, 55));
}

fn paintChatSurface(hdc: HANDLE, rc: RECT, color: DWORD, border_color: DWORD, radius: i32) void {
    const edge = chatSurfaceBorderW();
    fillRoundRectAA(hdc, rc, radius, border_color);
    fillRoundRectAA(hdc, .{ .left = rc.left + edge, .top = rc.top + edge, .right = rc.right - edge, .bottom = rc.bottom - edge }, @max(0, radius - edge), color);
}

pub fn chatWorkingIndicatorH() i32 {
    return if (chatPermissionVisible()) uiScaled(36) else 0;
}

pub fn chatWorkingIndicatorText() []const u16 {
    if (app_state.g_chat_screen_status_len > 0) return app_state.g_chat_working_text[0..app_state.g_chat_screen_status_len];
    if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].activity == .active) return &CHAT_WORKING_GENERIC;
    return &.{};
}

pub fn chatWorkingTimesPoll() void {
    if (!app_state.ISSUE_265_WORKING_BAR) return;
    const now = @import("win32.zig").GetTickCount64();
    for (app_state.shells[0..app_state.shell_count], 0..) |*shell, i| {
        const working = shell.activity == .active or shell.console_working or (app_state.g_chat_active and i == app_state.active_shell and (app_state.g_chat_screen_working or app_state.g_chat_screen_status_len > 0));
        shell.working_since_ms = @import("chat_working.zig").workingSince(shell.working_since_ms, working, now);
    }
}

pub fn chatWorkingBarVisible() bool {
    return app_state.ISSUE_265_WORKING_BAR and app_state.g_chat_active and app_state.active_shell < app_state.shell_count and
        (app_state.shells[app_state.active_shell].activity == .active or app_state.g_chat_screen_working or app_state.g_chat_screen_status_len > 0);
}

pub fn chatStopVisible() bool {
    return chatWorkingBarVisible() and !chatPermissionVisible();
}

pub fn chatWorkingBarTick() void {
    const previous = app_state.g_chat_working_applied;
    const previous_len = app_state.g_chat_working_applied_len;
    chatWorkingIndicatorSync();
    if (chatWorkingBarVisible() and previous_len == app_state.g_chat_working_applied_len and std.mem.eql(u16, previous[0..previous_len], app_state.g_chat_working_applied[0..previous_len])) chatWorkingIndicatorInvalidate();
}

pub fn chatWorkingIndicatorInvalidate() void {
    if (app_state.g_main_hwnd == null or !app_state.g_chat_active) return;
    const layout = chatViewLayout();
    var rc = RECT{
        .left = layout.transcript.left,
        .top = layout.transcript.bottom,
        .right = layout.transcript.right,
        .bottom = layout.composer_card.top,
    };
    _ = InvalidateRect(app_state.g_main_hwnd, &rc, 0);
}

pub fn chatWorkingIndicatorSync() void {
    @import("chat_render.zig").chatWorkingSync();
    var formatted: [128]u16 = undefined;
    const visible = chatWorkingBarVisible();
    if (app_state.ISSUE_265_WORKING_BAR) {
        const running = visible and app_state.g_main_hwnd != null;
        if (running != app_state.g_chat_working_timer_running) {
            if (running) {
                app_state.g_chat_working_timer_running = @import("win32.zig").SetTimer(app_state.g_main_hwnd, @import("win32.zig").TIMER_CHAT_WORKING, 250, null) != 0;
                if (app_state.g_chat_working_timer_running) debugLog("[chat] working timer started");
            } else {
                _ = @import("win32.zig").KillTimer(app_state.g_main_hwnd, @import("win32.zig").TIMER_CHAT_WORKING);
                app_state.g_chat_working_timer_running = false;
                debugLog("[chat] working timer stopped");
            }
        }
    }
    const text = if (!app_state.ISSUE_265_WORKING_BAR) chatWorkingIndicatorText() else if (visible) @import("chat_working.zig").workingBarText(
        app_state.g_chat_working_text[0..app_state.g_chat_screen_status_len],
        if (app_state.shells[app_state.active_shell].working_since_ms == 0) 0 else @import("win32.zig").GetTickCount64() -| app_state.shells[app_state.active_shell].working_since_ms,
        &formatted,
    ) else &.{};
    if (text.len == app_state.g_chat_working_applied_len and std.mem.eql(u16, text, app_state.g_chat_working_applied[0..text.len])) return;
    app_state.g_chat_working_applied_len = text.len;
    @memcpy(app_state.g_chat_working_applied[0..text.len], text);
    chatWorkingIndicatorInvalidate();
}

pub fn chatPermissionVisible() bool {
    return app_state.g_chat_active and app_state.active_shell < app_state.shell_count and
        app_state.g_chat_permission_sid == app_state.shells[app_state.active_shell].shell_id and app_state.g_chat_permission.count > 0 and
        !app_state.shells[app_state.active_shell].permission_answered;
}

pub fn chatPermissionRect(action: @import("chat_permission.zig").Action) ?RECT {
    if (!chatPermissionVisible() or app_state.g_chat_permission.digit(action) == null) return null;
    const layout = chatViewLayout();
    var count: i32 = 0;
    var index: i32 = 0;
    for (std.meta.tags(@import("chat_permission.zig").Action)) |item| {
        if (app_state.g_chat_permission.digit(item) != null) {
            if (@intFromEnum(item) < @intFromEnum(action)) index += 1;
            count += 1;
        }
    }
    const gap = uiScaled(8);
    const width = @divTrunc(layout.transcript.right - layout.transcript.left - gap * (count - 1), count);
    const left = layout.transcript.left + index * (width + gap);
    return .{ .left = left, .right = left + width, .top = layout.transcript.bottom + @import("chat_composer.zig").chatNewMessagesHeight() + uiScaled(2), .bottom = layout.composer_card.top - uiScaled(2) };
}

fn paintChatPermission(hdc: HANDLE, border: DWORD) void {
    const old_font = SelectObject(hdc, ensureChatFont());
    defer _ = SelectObject(hdc, old_font);
    for (std.meta.tags(@import("chat_permission.zig").Action), 0..) |action, i| {
        const rc = chatPermissionRect(action) orelse continue;
        const text = app_state.g_chat_permission.optionText(action) orelse continue;
        paintChatSurface(hdc, rc, app_state.g_chat_input_color, border, uiScaled(6));
        _ = SetTextColor(hdc, if (app_state.shells[app_state.active_shell].permission_answered) customColorOr("hint", RGB(135, 139, 147)) else customColorOr("text", if (app_state.g_light_theme) RGB(40, 44, 52) else RGB(220, 224, 232)));
        var text_rc = rc;
        text_rc.left += uiScaled(6);
        text_rc.right -= uiScaled(6);
        _ = DrawTextW(hdc, text.ptr, @intCast(text.len), &text_rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX | @import("win32.zig").DT_END_ELLIPSIS);
        if (verboseLoggingEnabled()) {
            var log: [128]u8 = undefined;
            debugLog(std.fmt.bufPrint(&log, "[chat] permission rect {s} {d},{d},{d},{d}", .{ @import("chat_permission.zig").labels[i], rc.left, rc.top, rc.right, rc.bottom }) catch "");
        }
    }
}

pub fn paintChatView(hdc: HANDLE) void {
    var canvas = @import("smooth.zig").Canvas.init(hdc);
    defer canvas.deinit();
    if (!chatViewOwnsInput()) return;
    const layout = chatViewLayout();
    refreshChatBrushes();
    _ = SetBkMode(hdc, TRANSPARENT);
    const card_border = chatSurfaceBorderColor();
    paintChatSurface(hdc, layout.composer_card, app_state.g_chat_input_color, card_border, chatSurfaceRadius());
    if (app_state.g_chat_reply_len > 0) {
        const old_font = SelectObject(hdc, ensureChatFont());
        defer _ = SelectObject(hdc, old_font);
        var preview = layout.composer_card;
        preview.left += uiScaled(14);
        preview.top += uiScaled(4);
        preview.right -= uiScaled(40);
        preview.bottom = layout.composer_card.top + @import("chat_composer.zig").chatReplyBarH();
        _ = SetTextColor(hdc, customColorOr("subtitle", if (app_state.g_light_theme) RGB(112, 117, 128) else RGB(137, 146, 164)));
        _ = DrawTextW(hdc, &app_state.g_chat_reply_preview, @intCast(app_state.g_chat_reply_preview_len), &preview, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        var cancel = @import("chat_composer.zig").chatReplyCancelRect();
        _ = DrawTextW(hdc, L("×"), -1, &cancel, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
    }
    const has_text = app_state.g_chat_composer_hwnd != null and GetWindowTextLengthW(app_state.g_chat_composer_hwnd) > 0;
    if (layout.send_shown) paintChatButton(hdc, layout.send_btn, has_text, .send);
    if (layout.stop_shown) paintChatButton(hdc, layout.stop_btn, true, .stop);
    paintChatAttachButton(hdc, layout.attach_btn);
    paintChatMicButton(hdc, layout.mic_btn);
    logChatButtons(layout);
    if (@import("chat_composer.zig").chatNewMessagesRect()) |pill| {
        paintChatSurface(hdc, pill, app_state.g_chat_input_color, card_border, uiScaled(13));
        const old_font = SelectObject(hdc, ensureChatFont());
        defer _ = SelectObject(hdc, old_font);
        _ = SetTextColor(hdc, customColorOr("text", @import("themes.zig").themeConsoleFg()));
        var label = pill;
        label.right -= uiScaled(28);
        var text: [64]u8 = undefined;
        const caption = std.fmt.bufPrint(&text, "{d} new message{s}", .{ app_state.g_chat_new_messages.count(), if (app_state.g_chat_new_messages.count() == 1) @as([]const u8, "") else "s" }) catch unreachable;
        var wide: [64]u16 = undefined;
        const n = std.unicode.utf8ToUtf16Le(&wide, caption) catch unreachable;
        var arrow = label;
        arrow.right = arrow.left + uiScaled(28);
        _ = DrawTextW(hdc, L("↓"), -1, &arrow, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
        label.left = arrow.right;
        _ = DrawTextW(hdc, &wide, @intCast(n), &label, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        var close = pill;
        close.left = label.right;
        _ = DrawTextW(hdc, L("×"), -1, &close, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
    }
    if (chatPermissionVisible()) {
        paintChatPermission(hdc, card_border);
        return;
    }
    paintChatStopTooltip(hdc, layout);
}

var chat_buttons_logged: [13]i32 = @splat(std.math.minInt(i32));

fn logChatButtons(layout: @import("app_state.zig").ChatViewLayout) void {
    if (!verboseLoggingEnabled()) return;
    const card = layout.composer_card;
    const send = layout.send_btn;
    const stop = layout.stop_btn;
    const now = [_]i32{ card.left, card.top, card.right, card.bottom, send.left, send.top, send.right, send.bottom, stop.left, stop.top, stop.right, stop.bottom, @as(i32, @intFromBool(layout.send_shown)) + 2 * @as(i32, @intFromBool(layout.stop_shown)) };
    if (std.mem.eql(i32, &now, &chat_buttons_logged)) return;
    chat_buttons_logged = now;
    var log: [128]u8 = undefined;
    debugLog(std.fmt.bufPrint(&log, "[chat] composer card {d},{d},{d},{d} size={d}", .{ card.left, card.top, card.right, card.bottom, send.right - send.left }) catch "");
    for ([_]struct { name: []const u8, rect: RECT }{ .{ .name = "attach", .rect = layout.attach_btn }, .{ .name = "mic", .rect = layout.mic_btn } }) |button| {
        const rect = button.rect;
        debugLog(std.fmt.bufPrint(&log, "[chat] {s} rect {d},{d},{d},{d}", .{ button.name, rect.left, rect.top, rect.right, rect.bottom }) catch "");
    }
    if (layout.send_shown) debugLog(std.fmt.bufPrint(&log, "[chat] send rect {d},{d},{d},{d}", .{ send.left, send.top, send.right, send.bottom }) catch "");
    if (layout.stop_shown) debugLog(std.fmt.bufPrint(&log, "[chat] stop rect {d},{d},{d},{d}", .{ stop.left, stop.top, stop.right, stop.bottom }) catch "");
}

fn paintChatStopTooltip(hdc: HANDLE, layout: @import("app_state.zig").ChatViewLayout) void {
    if (!app_state.g_chat_stop_hover or !layout.stop_shown) return;
    const text = L("Stop (Esc)");
    const old_font = SelectObject(hdc, @import("drawing.zig").uiFontSubtitle());
    defer _ = SelectObject(hdc, old_font);
    var calc = RECT{ .left = 0, .top = 0, .right = 0, .bottom = 0 };
    _ = DrawTextW(hdc, text, -1, &calc, @import("win32.zig").DT_CALCRECT | DT_SINGLELINE | DT_NOPREFIX);
    const width = calc.right - calc.left + uiScaled(12);
    const left = @max(layout.composer_card.left, layout.stop_btn.right - width);
    var tip = RECT{ .left = left, .top = layout.composer_card.top - uiScaled(28), .right = left + width, .bottom = layout.composer_card.top - uiScaled(4) };
    const brush = CreateSolidBrush(@import("themes.zig").themeSidebarBg());
    _ = @import("win32.zig").FillRect(hdc, &tip, brush);
    _ = DeleteObject(brush);
    _ = SetTextColor(hdc, customColorOr("text_inactive", if (app_state.g_light_theme) RGB(65, 65, 75) else RGB(215, 215, 225)));
    _ = DrawTextW(hdc, text, -1, &tip, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
}

pub fn invalidateSpinnerRects() void {
    if (app_state.g_main_hwnd == null) return;
    if (app_state.g_inbox_active) {
        var inbox_rc = RECT{ .left = 0, .top = uiScaled(48), .right = SIDEBAR_W(), .bottom = 2000 };
        _ = InvalidateRect(app_state.g_main_hwnd, &inbox_rc, 0);
        return;
    }
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].muted) continue;
        if (app_state.shells[i].activity != .active) continue;
        const top = tabRowY(@intCast(i)) orelse continue;
        const y: i32 = top - app_state.g_sidebar_scroll;
        var rc = RECT{
            .left = 0,
            .top = y,
            .right = SIDEBAR_W(),
            .bottom = y + tabRowH(),
        };
        _ = InvalidateRect(app_state.g_main_hwnd, &rc, 0);
    }
    if (threadTitleHeight() > 0 and app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].activity == .active) {
        const title_left = if (app_state.g_chat_active) chatViewLayout().transcript.left else SIDEBAR_W();
        var title_rc = RECT{
            .left = title_left,
            .top = threadTitleTop(),
            .right = title_left + 56,
            .bottom = threadTitleTop() + threadTitleHeight(),
        };
        _ = InvalidateRect(app_state.g_main_hwnd, &title_rc, 0);
    }
}

test "ISSUE-444 Send button keeps blended corners at 100 and 150 percent" {
    const w = @import("win32.zig");
    const saved_scale = app_state.g_ui_scale;
    const saved_dpi = app_state.g_main_monitor_dpi;
    defer app_state.g_ui_scale = saved_scale;
    defer app_state.g_main_monitor_dpi = saved_dpi;
    app_state.g_main_monitor_dpi = 96;
    const dc = w.CreateCompatibleDC(null);
    try std.testing.expect(dc != null);
    defer _ = w.DeleteDC(dc);
    const info = w.BITMAPINFO{ .header = .{ .width = 128, .height = -128 } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0);
    try std.testing.expect(bitmap != null);
    defer _ = w.DeleteObject(bitmap);
    const old_bitmap = w.SelectObject(dc, bitmap);
    defer _ = w.SelectObject(dc, old_bitmap);
    const area = RECT{ .left = 0, .top = 0, .right = 128, .bottom = 128 };
    const background: DWORD = 0x112233;
    const brush = w.CreateSolidBrush(background);
    defer _ = w.DeleteObject(brush);
    for ([_]u32{ 100, 150 }) |scale| {
        app_state.g_ui_scale = scale;
        const rc = RECT{ .left = 8, .top = 8, .right = 8 + uiScaled(32), .bottom = 8 + uiScaled(32) };
        for ([_]bool{ false, true }) |enabled| {
            _ = w.FillRect(dc, &area, brush);
            paintChatButton(dc, rc, enabled, .send);
            const enabled_bg = if (app_state.g_light_theme) RGB(104, 104, 104) else RGB(64, 64, 64);
            const fill = if (enabled) enabled_bg else customColorOr("overlay_input_bg", if (app_state.g_light_theme) RGB(236, 238, 243) else RGB(38, 42, 52));
            var blended: usize = 0;
            var y = rc.top;
            while (y < rc.top + uiScaled(4)) : (y += 1) {
                var x = rc.left;
                while (x < rc.left + @divTrunc(rc.bottom - rc.top, 2)) : (x += 1) {
                    const pixel = w.GetPixel(dc, x, y);
                    if (pixel != fill and pixel != background and pixel != 0xffffffff) blended += 1;
                }
            }
            try std.testing.expect(blended > 0);
            try std.testing.expectEqual(background, w.GetPixel(dc, rc.left, rc.top));
            try std.testing.expectEqual(background, w.GetPixel(dc, rc.right, rc.top));
            try std.testing.expectEqual(background, w.GetPixel(dc, rc.left, rc.bottom));
        }
    }
}

test "IGSH-884 attach microphone send and stop paint circular backgrounds" {
    const w = @import("win32.zig");
    const saved_scale = app_state.g_ui_scale;
    const saved_dpi = app_state.g_main_monitor_dpi;
    const saved_state = @import("chat_composer.zig").chat_dictation_state;
    defer app_state.g_ui_scale = saved_scale;
    defer app_state.g_main_monitor_dpi = saved_dpi;
    defer @import("chat_composer.zig").chat_dictation_state = saved_state;
    app_state.g_main_monitor_dpi = 96;
    const dc = w.CreateCompatibleDC(null) orelse return error.TestUnexpectedResult;
    defer _ = w.DeleteDC(dc);
    const info = w.BITMAPINFO{ .header = .{ .width = 128, .height = -128 } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0) orelse return error.TestUnexpectedResult;
    defer _ = w.DeleteObject(bitmap);
    const old_bitmap = w.SelectObject(dc, bitmap);
    defer _ = w.SelectObject(dc, old_bitmap);
    const area = RECT{ .left = 0, .top = 0, .right = 128, .bottom = 128 };
    const background: DWORD = 0x112233;
    const brush = w.CreateSolidBrush(background);
    defer _ = w.DeleteObject(brush);
    for ([_]u32{ 100, 150, 200 }) |scale| {
        app_state.g_ui_scale = scale;
        const size = uiScaled(32);
        const rc = RECT{ .left = 8, .top = 8, .right = 8 + size, .bottom = 8 + size };
        for (0..5) |button| {
            _ = w.FillRect(dc, &area, brush);
            var canvas = @import("smooth.zig").Canvas.init(dc);
            switch (button) {
                0 => paintChatAttachButton(dc, rc),
                1, 2 => {
                    @import("chat_composer.zig").chat_dictation_state = if (button == 1) .idle else .listening;
                    paintChatMicButton(dc, rc);
                },
                3 => paintChatButton(dc, rc, true, .send),
                else => paintChatButton(dc, rc, true, .stop),
            }
            canvas.deinit();
            try std.testing.expectEqual(background, w.GetPixel(dc, rc.left, rc.top));
            try std.testing.expectEqual(background, w.GetPixel(dc, rc.left, rc.top + @divTrunc(size, 4)));
            try std.testing.expect(w.GetPixel(dc, rc.left + @divTrunc(size, 2), rc.top + uiScaled(2)) != background);
        }
    }
}
