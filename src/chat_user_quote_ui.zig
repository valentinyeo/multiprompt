const std = @import("std");
const app_state = @import("app_state.zig");
const win32 = @import("win32.zig");
const md = @import("chat_markdown.zig");
const quote = @import("chat_user_quote.zig");
const chat_render = @import("chat_render.zig");
const chat_session = @import("chat_session.zig");
const chat_composer = @import("chat_composer.zig");
const chat_find_ui = @import("chat_find_ui.zig");
const chat_hit = @import("chat_hit.zig");
const chat_style = @import("chat_style.zig");
const link_detect = @import("link_detect.zig");
const dwrite_text = @import("dwrite_text.zig");
const fonts = @import("fonts.zig");
const smooth = @import("smooth.zig");
const themes = @import("themes.zig");
const drawing = @import("drawing.zig");
const startup = @import("startup.zig");

const RECT = win32.RECT;
const HANDLE = win32.HANDLE;

const MeasureCtx = struct {
    hdc: HANDLE,

    fn cell(self: *const MeasureCtx, text: []const u16, style: md.Style, level: u3) quote.Size {
        const old = win32.SelectObject(self.hdc, chat_render.chatRichFont(style, level));
        defer _ = win32.SelectObject(self.hdc, old);
        var rc = RECT{ .left = 0, .top = 0, .right = 100, .bottom = 0 };
        const h = fonts.chatLineHeight(win32.DrawTextW(self.hdc, startup.L("Ag"), 2, &rc, win32.DT_CALCRECT | win32.DT_SINGLELINE | win32.DT_NOPREFIX));
        return .{ .width = chat_render.chatTextWidth(self.hdc, text), .height = h };
    }
};

fn sliceRange(display: chat_render.ChatDisplay, start: usize, end: usize) chat_render.ChatDisplay {
    const s = @min(start, display.text.len);
    const e = @max(s, @min(end, display.text.len));
    return .{
        .text = display.text[s..e],
        .offset = if (display.source_map == null) display.offset + s else if (s == e) display.sourceBoundary(s, false) else display.offset,
        .source_map = if (display.source_map) |map| map[s..e] else null,
    };
}

fn buildMetrics(hdc: HANDLE) quote.Metrics {
    const old = win32.SelectObject(hdc, chat_composer.ensureChatFont());
    defer _ = win32.SelectObject(hdc, old);
    var rc = RECT{ .left = 0, .top = 0, .right = 100, .bottom = 0 };
    const line_h = fonts.chatLineHeight(win32.DrawTextW(hdc, startup.L("Ag"), 2, &rc, win32.DT_CALCRECT | win32.DT_SINGLELINE | win32.DT_NOPREFIX));
    _ = win32.SelectObject(hdc, chat_render.chatMetadataFont());
    var trc = RECT{ .left = 0, .top = 0, .right = 100, .bottom = 0 };
    const toggle_h = @max(drawing.uiScaled(16), win32.DrawTextW(hdc, startup.L("Ag"), 2, &trc, win32.DT_CALCRECT | win32.DT_SINGLELINE | win32.DT_NOPREFIX));
    const more_w = chat_render.chatTextWidth(hdc, quote.SHOW_MORE);
    const less_w = chat_render.chatTextWidth(hdc, quote.SHOW_LESS);
    return .{
        .line_h = line_h,
        .toggle_h = toggle_h,
        .para_gap = drawing.uiScaled(quote.PARA_GAP),
        .list_indent = drawing.uiScaled(quote.LIST_INDENT_STEP),
        .list_marker_w = drawing.uiScaled(quote.LIST_MARKER_W),
        .toggle_gap = drawing.uiScaled(quote.TOGGLE_GAP),
        .toggle_more_w = more_w,
        .toggle_less_w = less_w,
    };
}

fn measurePlainWidth(hdc: HANDLE, text: []const u16, max_w: i32) i32 {
    if (text.len == 0) return 0;
    const old = win32.SelectObject(hdc, chat_composer.ensureChatFont());
    defer _ = win32.SelectObject(hdc, old);
    var calc = RECT{ .left = 0, .top = 0, .right = max_w, .bottom = 0 };
    _ = win32.DrawTextW(hdc, text.ptr, @intCast(text.len), &calc, win32.DT_CALCRECT | win32.DT_WORDBREAK | win32.DT_NOPREFIX);
    return @min(max_w, calc.right);
}

pub fn measureNaturalWidth(hdc: HANDLE, display: chat_render.ChatDisplay, block: md.Block, parts: quote.Parts, max_text_w: i32) i32 {
    var natural_w: i32 = 0;
    if (parts.prefix.end > parts.prefix.start) {
        natural_w = @max(natural_w, measurePlainWidth(hdc, display.text[parts.prefix.start..parts.prefix.end], max_text_w));
    }
    if (parts.suffix.end > parts.suffix.start) {
        natural_w = @max(natural_w, measurePlainWidth(hdc, display.text[parts.suffix.start..parts.suffix.end], max_text_w));
    }
    const bar_w = @max(3, drawing.uiScaled(quote.BAR_PX));
    const pad_x = drawing.uiScaled(quote.INSET_PAD_X);
    const inner_q_w = @max(1, max_text_w - bar_w - 2 * pad_x);
    const a = std.heap.page_allocator;
    var unq = quote.unquote(a, display.text, parts.quote) catch return max_text_w;
    defer unq.deinit(a);
    const ctx = MeasureCtx{ .hdc = hdc };
    const expanded = quote.isOpen(quote.blockKey(block, display.text));
    var lay = quote.layout(a, unq.text, inner_q_w, buildMetrics(hdc), expanded, &ctx, MeasureCtx.cell) catch return max_text_w;
    defer lay.deinit(a);
    return @max(natural_w, @min(max_text_w, lay.natural_w + bar_w + 2 * pad_x));
}

pub fn measureHeight(hdc: HANDLE, display: chat_render.ChatDisplay, block: md.Block, parts: quote.Parts, inner_w: i32) i32 {
    const gap = drawing.uiScaled(quote.SECTION_GAP);
    var total: i32 = 0;
    if (parts.prefix.end > parts.prefix.start) {
        var ph: i32 = 0;
        const pref = sliceRange(display, parts.prefix.start, parts.prefix.end);
        _ = chat_render.chatFlowText(hdc, pref.text, .{ .left = 0, .top = 0, .right = inner_w, .bottom = 0 }, false, false, null, pref.offset, &ph, pref.source_map, true);
        total += ph + gap;
    }
    const bar_w = @max(3, drawing.uiScaled(quote.BAR_PX));
    const pad_x = drawing.uiScaled(quote.INSET_PAD_X);
    const pad_y = drawing.uiScaled(quote.INSET_PAD_Y);
    const inner_q_w = @max(1, inner_w - bar_w - 2 * pad_x);
    const a = std.heap.page_allocator;
    var unq = quote.unquote(a, display.text, parts.quote) catch {
        var fh: i32 = 0;
        _ = chat_render.chatFlowText(hdc, display.text, .{ .left = 0, .top = 0, .right = inner_w, .bottom = 0 }, false, false, null, display.offset, &fh, display.source_map, true);
        return fh;
    };
    defer unq.deinit(a);
    const ctx = MeasureCtx{ .hdc = hdc };
    const expanded = quote.isOpen(quote.blockKey(block, display.text));
    var lay = quote.layout(a, unq.text, inner_q_w, buildMetrics(hdc), expanded, &ctx, MeasureCtx.cell) catch {
        var fh: i32 = 0;
        _ = chat_render.chatFlowText(hdc, display.text, .{ .left = 0, .top = 0, .right = inner_w, .bottom = 0 }, false, false, null, display.offset, &fh, display.source_map, true);
        return fh;
    };
    defer lay.deinit(a);
    total += lay.total_h + 2 * pad_y;
    if (parts.suffix.end > parts.suffix.start) {
        total += gap;
        var sh: i32 = 0;
        const suff = sliceRange(display, parts.suffix.start, parts.suffix.end);
        _ = chat_render.chatFlowText(hdc, suff.text, .{ .left = 0, .top = 0, .right = inner_w, .bottom = 0 }, false, false, null, suff.offset, &sh, suff.source_map, true);
        total += sh;
    }
    return total;
}

pub fn paint(hdc: HANDLE, display: chat_render.ChatDisplay, block: md.Block, parts: quote.Parts, area: RECT) void {
    const inner_w = @max(1, area.right - area.left);
    const gap = drawing.uiScaled(quote.SECTION_GAP);
    const text_color = themes.customColorOr("text", themes.themeConsoleFg());
    var cur_y = area.top;

    if (parts.prefix.end > parts.prefix.start) {
        var ph: i32 = 0;
        const pref = sliceRange(display, parts.prefix.start, parts.prefix.end);
        _ = win32.SelectObject(hdc, chat_composer.ensureChatFont());
        _ = win32.SetTextColor(hdc, text_color);
        _ = chat_render.chatFlowText(hdc, pref.text, .{ .left = area.left, .top = cur_y, .right = area.right, .bottom = area.bottom }, false, true, null, pref.offset, &ph, pref.source_map, true);
        cur_y += ph + gap;
    }

    const bar_w = @max(3, drawing.uiScaled(quote.BAR_PX));
    const pad_x = drawing.uiScaled(quote.INSET_PAD_X);
    const pad_y = drawing.uiScaled(quote.INSET_PAD_Y);
    const inner_q_w = @max(1, inner_w - bar_w - 2 * pad_x);
    const a = std.heap.page_allocator;
    var unq = quote.unquote(a, display.text, parts.quote) catch {
        _ = chat_render.chatFlowText(hdc, display.text, area, false, true, null, display.offset, null, display.source_map, true);
        return;
    };
    defer unq.deinit(a);
    const ctx = MeasureCtx{ .hdc = hdc };
    const expanded = quote.isOpen(quote.blockKey(block, display.text));
    var lay = quote.layout(a, unq.text, inner_q_w, buildMetrics(hdc), expanded, &ctx, MeasureCtx.cell) catch {
        _ = chat_render.chatFlowText(hdc, display.text, area, false, true, null, display.offset, null, display.source_map, true);
        return;
    };
    defer lay.deinit(a);

    const q_rc = RECT{ .left = area.left, .top = cur_y, .right = area.right, .bottom = cur_y + lay.total_h + 2 * pad_y };
    const accent = themes.customColorOr("accent", if (app_state.g_light_theme) startup.RGB(30, 90, 170) else startup.RGB(110, 175, 245));
    const cols = quote.colors(chat_render.chatUserBubbleColor(), text_color, accent, app_state.g_light_theme);
    const rad = chat_style.cornerRadius(q_rc.right - q_rc.left, q_rc.bottom - q_rc.top, drawing.uiScaled(quote.INSET_RADIUS));
    smooth.fillRoundRect(hdc, q_rc, rad, cols.inset_bg);
    const bar_pad = @min(drawing.uiScaled(2), @divTrunc(@max(0, q_rc.bottom - q_rc.top), 4));
    smooth.fillRoundRect(hdc, .{ .left = q_rc.left, .top = q_rc.top + bar_pad, .right = q_rc.left + bar_w, .bottom = q_rc.bottom - bar_pad }, bar_w, cols.bar);

    const content_left = q_rc.left + bar_w + pad_x;
    const content_top = q_rc.top + pad_y;
    const saved_font = win32.SelectObject(hdc, chat_composer.ensureChatFont());
    defer _ = win32.SelectObject(hdc, saved_font);

    for (lay.lines[0..lay.visible_lines]) |line| {
        if (line.marker) |marker| {
            _ = win32.SelectObject(hdc, chat_composer.ensureChatFont());
            _ = win32.SetTextColor(hdc, cols.text);
            var mrc = RECT{
                .left = content_left + marker.x,
                .top = content_top + line.y,
                .right = content_left + marker.x + marker.width,
                .bottom = content_top + line.y + line.height,
            };
            if (marker.bullet) {
                _ = dwrite_text.draw(hdc, quote.BULLET.ptr, @intCast(quote.BULLET.len), &mrc, win32.DT_SINGLELINE | win32.DT_NOPREFIX);
            } else {
                const mtext = unq.text[marker.text.start..marker.text.end];
                _ = dwrite_text.draw(hdc, mtext.ptr, @intCast(mtext.len), &mrc, win32.DT_SINGLELINE | win32.DT_NOPREFIX);
            }
        }
        for (lay.runs[line.first_run..][0..line.run_count]) |run| {
            const seg = unq.text[run.text.start..run.text.end];
            if (seg.len == 0) continue;
            _ = win32.SelectObject(hdc, chat_render.chatRichFont(run.style, run.level));
            var rrc = RECT{
                .left = content_left + run.x,
                .top = content_top + line.y,
                .right = content_left + run.x + run.width,
                .bottom = content_top + line.y + line.height,
            };
            if (run.style.code) {
                const brush = win32.CreateSolidBrush(chat_render.chatCodePanelColor());
                _ = win32.FillRect(hdc, &rrc, brush);
                _ = win32.DeleteObject(brush);
            }
            const src_base = display.sourceBoundary(unq.map[run.text.start], true);
            if (app_state.g_chat_find_open) chat_find_ui.paintRun(hdc, seg, src_base, rrc.left, rrc.top, line.height);
            if (app_state.g_chat_sel_active) chat_render.chatPaintSelectionRun(hdc, seg, src_base, rrc.left, rrc.top, line.height);
            _ = win32.SetTextColor(hdc, if (run.target != null) cols.link else if (run.style.bold or run.level > 0) cols.bold_text else cols.text);
            _ = dwrite_text.draw(hdc, seg.ptr, @intCast(seg.len), &rrc, win32.DT_SINGLELINE | win32.DT_NOPREFIX);
        }
        if (line.ellipsis_x) |ex| {
            _ = win32.SelectObject(hdc, chat_composer.ensureChatFont());
            _ = win32.SetTextColor(hdc, cols.text);
            var erc = RECT{
                .left = content_left + ex,
                .top = content_top + line.y,
                .right = q_rc.right - pad_x,
                .bottom = content_top + line.y + line.height,
            };
            _ = dwrite_text.draw(hdc, quote.ELLIPSIS.ptr, @intCast(quote.ELLIPSIS.len), &erc, win32.DT_SINGLELINE | win32.DT_NOPREFIX);
        }
    }

    if (lay.toggle_rect) |tr| {
        _ = win32.SelectObject(hdc, chat_render.chatMetadataFont());
        _ = win32.SetTextColor(hdc, cols.toggle);
        const label = if (lay.expanded) quote.SHOW_LESS else quote.SHOW_MORE;
        var trc = RECT{
            .left = content_left + tr.left,
            .top = content_top + tr.top,
            .right = @min(q_rc.right - pad_x, content_left + tr.right + drawing.uiScaled(4)),
            .bottom = content_top + tr.bottom,
        };
        _ = dwrite_text.draw(hdc, label.ptr, @intCast(label.len), &trc, win32.DT_SINGLELINE | win32.DT_NOPREFIX);
    }

    cur_y = q_rc.bottom;
    if (parts.suffix.end > parts.suffix.start) {
        cur_y += gap;
        const suff = sliceRange(display, parts.suffix.start, parts.suffix.end);
        _ = win32.SelectObject(hdc, chat_composer.ensureChatFont());
        _ = win32.SetTextColor(hdc, text_color);
        _ = chat_render.chatFlowText(hdc, suff.text, .{ .left = area.left, .top = cur_y, .right = area.right, .bottom = area.bottom }, false, true, null, suff.offset, null, suff.source_map, true);
    }
}

pub fn toggleAt(hwnd: HANDLE, x: i32, y: i32) ?u64 {
    const dc = win32.GetDC(hwnd) orelse return null;
    defer _ = win32.ReleaseDC(hwnd, dc);
    const pad = drawing.uiScaled(app_state.CHAT_BUBBLE_PAD);
    const bar_w = @max(3, drawing.uiScaled(quote.BAR_PX));
    const pad_x = drawing.uiScaled(quote.INSET_PAD_X);
    const pad_y = drawing.uiScaled(quote.INSET_PAD_Y);
    const gap = drawing.uiScaled(quote.SECTION_GAP);
    const hit_pad = drawing.uiScaled(4);

    const captured = chat_render.chatTranscriptBlockAtPoint(y);
    const first = captured orelse app_state.g_chat_block_count;
    const end = if (captured != null) first + 1 else first + app_state.g_chat_echo_layout_count;

    for (first..end) |i| {
        const sel = chat_render.chatSelectionDisplay(i) orelse continue;
        if (sel.block.role != .user) continue;
        var area = chat_render.chatSelectionRect(i);
        area.top -= app_state.g_chat_scroll_y;
        area.bottom -= app_state.g_chat_scroll_y;
        const reply_h: i32 = if (sel.reply_ref != null) drawing.uiScaled(24) else 0;
        area.left += pad;
        area.right -= pad;
        area.top += pad + reply_h;
        area.bottom -= pad;
        if (!chat_composer.pointInRect(area, x, y)) continue;

        const mapped = chat_render.ChatDisplay{ .text = sel.text, .offset = sel.start, .source_map = sel.source_map, .reply_ref = sel.reply_ref };
        const start = if (sel.reply_ref) |r| r.body_start else 0;
        const body = sliceRange(mapped, start, mapped.text.len);
        const parts = quote.parse(body.text) orelse continue;

        const inner_w = @max(1, area.right - area.left);
        var cur_y = area.top;
        if (parts.prefix.end > parts.prefix.start) {
            var ph: i32 = 0;
            const pref = sliceRange(body, parts.prefix.start, parts.prefix.end);
            _ = chat_render.chatFlowText(dc, pref.text, .{ .left = area.left, .top = cur_y, .right = area.right, .bottom = area.bottom }, false, false, null, pref.offset, &ph, pref.source_map, true);
            cur_y += ph + gap;
        }
        const inner_q_w = @max(1, inner_w - bar_w - 2 * pad_x);
        const a = std.heap.page_allocator;
        var unq = quote.unquote(a, body.text, parts.quote) catch continue;
        defer unq.deinit(a);
        const ctx = MeasureCtx{ .hdc = dc };
        const key = quote.blockKey(sel.block, body.text);
        var lay = quote.layout(a, unq.text, inner_q_w, buildMetrics(dc), quote.isOpen(key), &ctx, MeasureCtx.cell) catch continue;
        defer lay.deinit(a);
        const tr = lay.toggle_rect orelse continue;
        const content_left = area.left + bar_w + pad_x;
        const content_top = cur_y + pad_y;
        const hit_rc = RECT{
            .left = content_left + tr.left - hit_pad,
            .top = content_top + tr.top - hit_pad,
            .right = content_left + tr.right + hit_pad,
            .bottom = content_top + tr.bottom + hit_pad,
        };
        if (chat_composer.pointInRect(hit_rc, x, y)) return key;
    }
    return null;
}

pub fn handleClick(hwnd: HANDLE, x: i32, y: i32) bool {
    const key = toggleAt(hwnd, x, y) orelse return false;
    _ = quote.toggle(key);
    app_state.g_chat_scrolled_up = true;
    app_state.g_chat_read_hold = false;
    app_state.g_chat_layout_reuse = 0;
    if (app_state.g_chat_active and app_state.g_chat_transcript_hwnd != null and (app_state.g_chat_block_count > 0 or app_state.g_chat_echo_layout_count > 0)) {
        var client_rc: RECT = std.mem.zeroes(RECT);
        chat_render.chatViewClientRect(&client_rc);
        chat_session.chatRelayoutPreservingScroll(client_rc.right - client_rc.left, client_rc.bottom - client_rc.top);
        _ = win32.InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    }
    return true;
}

pub fn linkAt(hdc: HANDLE, display: chat_render.ChatDisplay, block: md.Block, parts: quote.Parts, area: RECT, x: i32, y: i32) ?link_detect.Range {
    const inner_w = @max(1, area.right - area.left);
    const gap = drawing.uiScaled(quote.SECTION_GAP);
    var cur_y = area.top;

    if (parts.prefix.end > parts.prefix.start) {
        var ph: i32 = 0;
        const pref = sliceRange(display, parts.prefix.start, parts.prefix.end);
        if (chat_render.chatFlowText(hdc, pref.text, .{ .left = area.left, .top = cur_y, .right = area.right, .bottom = area.bottom }, false, false, .{ .x = x, .y = y }, pref.offset, &ph, pref.source_map, true)) |link| return link;
        cur_y += ph + gap;
    }

    const bar_w = @max(3, drawing.uiScaled(quote.BAR_PX));
    const pad_x = drawing.uiScaled(quote.INSET_PAD_X);
    const pad_y = drawing.uiScaled(quote.INSET_PAD_Y);
    const inner_q_w = @max(1, inner_w - bar_w - 2 * pad_x);
    const a = std.heap.page_allocator;
    var unq = quote.unquote(a, display.text, parts.quote) catch return null;
    defer unq.deinit(a);
    const ctx = MeasureCtx{ .hdc = hdc };
    const expanded = quote.isOpen(quote.blockKey(block, display.text));
    var lay = quote.layout(a, unq.text, inner_q_w, buildMetrics(hdc), expanded, &ctx, MeasureCtx.cell) catch return null;
    defer lay.deinit(a);

    const content_left = area.left + bar_w + pad_x;
    const content_top = cur_y + pad_y;
    for (lay.lines[0..lay.visible_lines]) |line| {
        for (lay.runs[line.first_run..][0..line.run_count]) |run| {
            const target = run.target orelse continue;
            const rrc = RECT{
                .left = content_left + run.x,
                .top = content_top + line.y,
                .right = content_left + run.x + run.width,
                .bottom = content_top + line.y + line.height,
            };
            if (chat_composer.pointInRect(rrc, x, y) and target.start < unq.map.len and target.end > target.start and target.end <= unq.map.len) {
                return display.sourceRange(unq.map[target.start], unq.map[target.end - 1] + 1);
            }
        }
    }

    cur_y += lay.total_h + 2 * pad_y;
    if (parts.suffix.end > parts.suffix.start) {
        cur_y += gap;
        const suff = sliceRange(display, parts.suffix.start, parts.suffix.end);
        return chat_render.chatFlowText(hdc, suff.text, .{ .left = area.left, .top = cur_y, .right = area.right, .bottom = area.bottom }, false, false, .{ .x = x, .y = y }, suff.offset, null, suff.source_map, true);
    }
    return null;
}

pub fn charAt(hdc: HANDLE, display: chat_render.ChatDisplay, block: md.Block, parts: quote.Parts, area: RECT, x: i32, y: i32, out_char: *usize) void {
    const inner_w = @max(1, area.right - area.left);
    const gap = drawing.uiScaled(quote.SECTION_GAP);
    var cur_y = area.top;

    if (parts.prefix.end > parts.prefix.start) {
        var ph: i32 = 0;
        const pref = sliceRange(display, parts.prefix.start, parts.prefix.end);
        _ = chat_render.chatFlowText(hdc, pref.text, .{ .left = area.left, .top = cur_y, .right = area.right, .bottom = area.bottom }, false, false, null, pref.offset, &ph, pref.source_map, true);
        if (y < cur_y + ph) {
            _ = chat_render.chatFlowText(hdc, pref.text, .{ .left = area.left, .top = cur_y, .right = area.right, .bottom = area.bottom }, false, false, .{ .x = x, .y = y, .char = out_char }, pref.offset, null, pref.source_map, true);
            return;
        }
        cur_y += ph + gap;
    }

    const bar_w = @max(3, drawing.uiScaled(quote.BAR_PX));
    const pad_x = drawing.uiScaled(quote.INSET_PAD_X);
    const pad_y = drawing.uiScaled(quote.INSET_PAD_Y);
    const inner_q_w = @max(1, inner_w - bar_w - 2 * pad_x);
    const a = std.heap.page_allocator;
    var unq = quote.unquote(a, display.text, parts.quote) catch {
        _ = chat_render.chatFlowText(hdc, display.text, area, false, false, .{ .x = x, .y = y, .char = out_char }, display.offset, null, display.source_map, true);
        return;
    };
    defer unq.deinit(a);
    const ctx = MeasureCtx{ .hdc = hdc };
    const expanded = quote.isOpen(quote.blockKey(block, display.text));
    var lay = quote.layout(a, unq.text, inner_q_w, buildMetrics(hdc), expanded, &ctx, MeasureCtx.cell) catch {
        _ = chat_render.chatFlowText(hdc, display.text, area, false, false, .{ .x = x, .y = y, .char = out_char }, display.offset, null, display.source_map, true);
        return;
    };
    defer lay.deinit(a);

    const q_bottom = cur_y + lay.total_h + 2 * pad_y;
    if (y < q_bottom or parts.suffix.end <= parts.suffix.start) {
        const content_left = area.left + bar_w + pad_x;
        const content_top = cur_y + pad_y;
        const first_src = display.sourceBoundary(parts.quote.start, true);
        const end_src = display.sourceBoundary(parts.quote.end, false);
        var nearest = chat_hit.Nearest{ .char = first_src };
        const saved = win32.SelectObject(hdc, chat_composer.ensureChatFont());
        defer _ = win32.SelectObject(hdc, saved);
        for (lay.lines[0..lay.visible_lines]) |line| {
            for (lay.runs[line.first_run..][0..line.run_count]) |run| {
                const seg = unq.text[run.text.start..run.text.end];
                if (seg.len == 0) continue;
                _ = win32.SelectObject(hdc, chat_render.chatRichFont(run.style, run.level));
                const rrc = RECT{
                    .left = content_left + run.x,
                    .top = content_top + line.y,
                    .right = content_left + run.x + run.width,
                    .bottom = content_top + line.y + line.height,
                };
                const at = if (y >= rrc.top and y < rrc.bottom) chat_render.chatCharAtX(hdc, seg, x - rrc.left) else if (y < rrc.top or x <= rrc.left) @as(usize, 0) else seg.len;
                const mapped_idx = if (at < seg.len) unq.map[run.text.start + at] else unq.map[run.text.end - 1] + 1;
                const src = display.sourceBoundary(mapped_idx, at < seg.len);
                nearest.consider(x, y, rrc.left, rrc.top, rrc.right, rrc.bottom, src);
            }
        }
        out_char.* = nearest.boundary(y, first_src, end_src);
        return;
    }

    const suff = sliceRange(display, parts.suffix.start, parts.suffix.end);
    _ = chat_render.chatFlowText(hdc, suff.text, .{ .left = area.left, .top = q_bottom + gap, .right = area.right, .bottom = area.bottom }, false, false, .{ .x = x, .y = y, .char = out_char }, suff.offset, null, suff.source_map, true);
}
