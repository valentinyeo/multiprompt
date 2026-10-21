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
        if (browserSlotReserved()) {
            const layout = calcBrowserLayout() orelse return;
            const shb = app_state.shells[app_state.active_shell].hwnd;
            var stb = GetWindowLongPtrW(shb, GWL_STYLE);
            stb &= ~@as(isize, @intCast(WS_VSCROLL | WS_HSCROLL));
            _ = SetWindowLongPtrW(shb, GWL_STYLE, stb);
            _ = SetWindowRgn(shb, null, 1);
            const inset: i32 = if (app_state.shells[app_state.active_shell].browser_native) paneFocusInset() else 0;
            const cx = layout.console_x + inset;
            const cy = layout.console_y + inset;
            const cw = layout.console_w - 2 * inset;
            const ch = layout.console_h - 2 * inset;
            if (nudge) _ = SetWindowPos(shb, null, cx, cy, cw, ch - 1, SWP_FRAMECHANGED | SWP_NOZORDER);
            _ = SetWindowPos(shb, null, cx, cy, cw, ch, SWP_FRAMECHANGED | SWP_NOZORDER);
            verifyShellWindowSize(shb, cx, cy, cw, ch);
            if (webView2OwnsActiveShell()) positionWebView2() else positionActiveBrowser();
            return;
        }
        if (app_state.shells[app_state.active_shell].full_width) {
            const sh0 = app_state.shells[app_state.active_shell].hwnd;
            var st0 = GetWindowLongPtrW(sh0, GWL_STYLE);
            st0 &= ~@as(isize, @intCast(WS_VSCROLL | WS_HSCROLL));
            _ = SetWindowLongPtrW(sh0, GWL_STYLE, st0);
            _ = SetWindowRgn(sh0, null, 1);
            const fw_w = rc.right - SIDEBAR_W();
            const fw_top = DEV_TOP_PAD + threadTitleHeight();
            const fw_h = rc.bottom - DEV_TOP_PAD - fw_top;
            if (nudge) _ = SetWindowPos(sh0, null, SIDEBAR_W(), fw_top, fw_w, fw_h - 1, SWP_FRAMECHANGED | SWP_NOZORDER);
            _ = SetWindowPos(sh0, null, SIDEBAR_W(), fw_top, fw_w, fw_h, SWP_FRAMECHANGED | SWP_NOZORDER);
            verifyShellWindowSize(sh0, SIDEBAR_W(), fw_top, fw_w, fw_h);
            return;
        }
        const con_top = DEV_TOP_PAD + threadTitleHeight();
        const h = rc.bottom - DEV_TOP_PAD - con_top;
        const sh = app_state.shells[app_state.active_shell].hwnd;
        var st = GetWindowLongPtrW(sh, GWL_STYLE);
        st &= ~@as(isize, @intCast(WS_VSCROLL | WS_HSCROLL));
        _ = SetWindowLongPtrW(sh, GWL_STYLE, st);
        const edge_pad: i32 = if (SIDEBAR_W() == 0) consoleEdgePad() else 0;
        const col = centeredConsoleColumn(rc.right, SIDEBAR_W(), edge_pad, consoleCellW());
        const w = col.width;
        const left = col.left;
        _ = SetWindowRgn(sh, null, 1);
        if (nudge) _ = SetWindowPos(sh, null, left, con_top, w, h - 1, SWP_FRAMECHANGED | SWP_NOZORDER);
        _ = SetWindowPos(sh, null, left, con_top, w, h, SWP_FRAMECHANGED | SWP_NOZORDER);
        verifyShellWindowSize(sh, left, con_top, w, h);
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

fn paintChatButton(hdc: HANDLE, rc: RECT, enabled: bool) void {
    const accent = customColorOr("selected_bg", if (app_state.g_light_theme) RGB(54, 118, 232) else RGB(125, 211, 252));
    const bg = if (enabled) accent else customColorOr("overlay_input_bg", if (app_state.g_light_theme) RGB(236, 238, 243) else RGB(38, 42, 52));
    const brush = CreateSolidBrush(bg);
    const pen = CreatePen(0, 1, bg);
    const old_brush = SelectObject(hdc, brush);
    const old_pen = SelectObject(hdc, pen);
    const radius = uiScaled(8);
    _ = @import("smooth.zig").drawRoundRect(hdc, rc.left, rc.top, rc.right, rc.bottom, radius, radius);
    _ = SelectObject(hdc, old_brush);
    _ = SelectObject(hdc, old_pen);
    _ = DeleteObject(brush);
    _ = DeleteObject(pen);
    const glyph_h = @max(uiScaled(10), @divTrunc((rc.bottom - rc.top) * 42, 100));
    const glyph_font = CreateFontW(-glyph_h, 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 5, 0, L("Segoe UI Symbol"));
    const old_font = SelectObject(hdc, glyph_font);
    _ = SetTextColor(hdc, if (enabled)
        (if (app_state.g_light_theme) RGB(255, 255, 255) else RGB(8, 20, 28))
    else
        customColorOr("subtitle", if (app_state.g_light_theme) RGB(150, 155, 165) else RGB(110, 116, 128)));
    var text_rc = rc;
    _ = DrawTextW(hdc, L("\u{25B6}"), -1, &text_rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
    _ = SelectObject(hdc, old_font);
    _ = DeleteObject(glyph_font);
}

fn paintChatSurface(hdc: HANDLE, rc: RECT, color: DWORD, border_color: DWORD, radius: i32) void {
    const edge = @max(1, uiScaled(1));
    fillRoundRectAA(hdc, rc, radius, border_color);
    fillRoundRectAA(hdc, .{ .left = rc.left + edge, .top = rc.top + edge, .right = rc.right - edge, .bottom = rc.bottom - edge }, @max(0, radius - edge), color);
}

pub fn chatWorkingIndicatorH() i32 {
    return uiScaled(if (app_state.ISSUE_265_WORKING_BAR) @as(i32, 22) else @as(i32, 18));
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
    var formatted: [128]u16 = undefined;
    const visible = chatWorkingBarVisible();
    if (app_state.ISSUE_265_WORKING_BAR) {
        const running = visible and app_state.g_main_hwnd != null;
        if (running != app_state.g_chat_working_timer_running) {
            if (running) {
                app_state.g_chat_working_timer_running = @import("win32.zig").SetTimer(app_state.g_main_hwnd, @import("win32.zig").TIMER_CHAT_WORKING, 1000, null) != 0;
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
    return .{ .left = left, .right = left + width, .top = layout.stop_btn.top, .bottom = layout.stop_btn.bottom };
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
    const card_border = customColorOr("overlay_border", if (app_state.g_light_theme) RGB(226, 229, 234) else RGB(41, 45, 55));
    paintChatSurface(hdc, layout.composer_card, app_state.g_chat_input_color, card_border, uiScaled(CHAT_BUBBLE_RADIUS));
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
    paintChatButton(hdc, layout.send_btn, has_text);
    paintChatAttachButton(hdc, layout.attach_btn);
    if (chatPermissionVisible()) {
        paintChatPermission(hdc, card_border);
        return;
    }
    if (app_state.g_chat_working_applied_len == 0) return;
    const old_font = SelectObject(hdc, ensureChatFont());
    defer _ = SelectObject(hdc, old_font);
    var line = RECT{
        .left = layout.transcript.left,
        .top = layout.transcript.bottom,
        .right = layout.transcript.right,
        .bottom = layout.composer_card.top,
    };
    if (chatWorkingBarVisible()) {
        paintChatSurface(hdc, layout.stop_btn, app_state.g_chat_input_color, card_border, uiScaled(6));
        var stop_text = layout.stop_btn;
        _ = SetTextColor(hdc, customColorOr("text", if (app_state.g_light_theme) RGB(40, 44, 52) else RGB(220, 224, 232)));
        _ = DrawTextW(hdc, L("Stop"), -1, &stop_text, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
        line.right = layout.stop_btn.left - uiScaled(10);
        if (verboseLoggingEnabled()) {
            var log: [128]u8 = undefined;
            debugLog(std.fmt.bufPrint(&log, "[chat] stop rect {d},{d},{d},{d}", .{ layout.stop_btn.left, layout.stop_btn.top, layout.stop_btn.right, layout.stop_btn.bottom }) catch "");
        }
    }
    _ = SetTextColor(hdc, customColorOr("hint", if (app_state.g_light_theme) RGB(140, 144, 152) else RGB(135, 139, 147)));
    _ = DrawTextW(hdc, &app_state.g_chat_working_applied, @intCast(app_state.g_chat_working_applied_len), &line, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
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
        const rc = RECT{ .left = 8, .top = 8, .right = 8 + uiScaled(32), .bottom = 8 + uiScaled(28) };
        for ([_]bool{ false, true }) |enabled| {
            _ = w.FillRect(dc, &area, brush);
            paintChatButton(dc, rc, enabled);
            const accent = customColorOr("selected_bg", if (app_state.g_light_theme) RGB(54, 118, 232) else RGB(125, 211, 252));
            const fill = if (enabled) accent else customColorOr("overlay_input_bg", if (app_state.g_light_theme) RGB(236, 238, 243) else RGB(38, 42, 52));
            var blended: usize = 0;
            var y = rc.top;
            while (y < rc.top + uiScaled(4)) : (y += 1) {
                var x = rc.left;
                while (x < rc.left + uiScaled(4)) : (x += 1) {
                    const pixel = w.GetPixel(dc, x, y);
                    if (pixel != fill and pixel != background and pixel != 0xffffffff) blended += 1;
                }
            }
            try std.testing.expect(blended > 0);
            try std.testing.expectEqual(background, w.GetPixel(dc, rc.right, rc.top));
            try std.testing.expectEqual(background, w.GetPixel(dc, rc.left, rc.bottom));
        }
    }
}
