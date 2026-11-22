fn chatFlowText(hdc: HANDLE, text: []const u16, area: RECT, code: bool, paint: bool, hit: ?ChatHit, offset: usize, height: ?*i32, source_map: ?[]const usize) ?link_detect.Range {
    const base = if (code) ensureChatCodeFont() else ensureChatFont();
    const old_font = SelectObject(hdc, base);
    defer _ = SelectObject(hdc, old_font);
    var line_rc = RECT{ .left = 0, .top = 0, .right = 100, .bottom = 0 };
    const line_h = @max(1, DrawTextW(hdc, L("Ag"), 2, &line_rc, DT_CALCRECT | DT_SINGLELINE | DT_NOPREFIX));
    const max_w = @max(1, area.right - area.left);
    var indent: i32 = if (code) 0 else chatLineIndentPx(hdc, text, 0);
    if (indent >= max_w) indent = 0;
    var nearest = chat_hit.Nearest{ .char = offset };
    defer if (hit) |pt| {
        if (pt.char) |out| out.* = nearest.boundary(pt.y, offset, offset + text.len);
    };
    var x: i32 = 0;
    var y: i32 = 0;
    var pos: usize = 0;
    var search: usize = 0;
    var link: ?link_detect.Range = null;
    var syntax = chat_code.Iterator{ .text = text };
    var token: ?chat_code.Token = if (code) syntax.next() else null;
    while (pos < text.len) {
        if (text[pos] == '\r' or text[pos] == '\n') {
            if (hit) |pt| if (pt.char != null) nearest.consider(pt.x, pt.y, area.left + x, area.top + y, area.left + x, area.top + y + line_h, offset + pos);
            if (text[pos] == '\r' and pos + 1 < text.len and text[pos + 1] == '\n') pos += 1;
            pos += 1;
            indent = if (code) 0 else chatLineIndentPx(hdc, text, pos);
            if (indent >= max_w) indent = 0;
            x = 0;
            y += line_h;
            continue;
        }
        var word_end = pos;
        const space = text[pos] == ' ' or text[pos] == '\t';
        while (word_end < text.len and (text[word_end] == ' ' or text[word_end] == '\t') == space and text[word_end] != '\r' and text[word_end] != '\n') : (word_end += 1) {}
        if (!space and x > 0 and chatTextWidth(hdc, text[pos..word_end]) > max_w - x) {
            x = indent;
            y += line_h;
        }
        if (space and x == 0 and !code) {
            pos = word_end;
            continue;
        }
        while (pos < word_end) {
            while (token != null and pos >= token.?.end) token = syntax.next();
            if (link == null or pos >= link.?.end) {
                link = link_detect.next(text, search);
                search = if (link) |l| l.end else text.len;
            }
            const in_link = link != null and pos >= link.?.start and pos < link.?.end;
            var limit = @min(word_end, if (in_link) link.?.end else if (link) |l| l.start else text.len);
            if (token) |t| limit = @min(limit, t.end);
            if (limit <= pos) limit = pos + 1;
            var fit: i32 = 0;
            var size: SIZE = undefined;
            _ = GetTextExtentExPointW(hdc, text[pos..limit].ptr, @intCast(limit - pos), max_w - x, &fit, null, &size);
            const count = chat_code.fitCount(text[pos..limit], fit);
            const segment = text[pos .. pos + count];
            const w = chatTextWidth(hdc, segment);
            const rect = RECT{ .left = area.left + x, .top = area.top + y, .right = area.left + x + w, .bottom = area.top + y + line_h };
            if (hit) |pt| {
                if (pt.char != null) {
                    const at = pos + chatCharAtX(hdc, segment, pt.x - rect.left);
                    const source = if (source_map) |map| (if (at < map.len) map[at] else map[map.len - 1] + 1) else at;
                    nearest.consider(pt.x, pt.y, rect.left, rect.top, rect.right, rect.bottom, offset + source);
                }
                if (in_link and pointInRect(rect, pt.x, pt.y)) return .{ .start = offset + (if (source_map) |map| map[link.?.start] else link.?.start), .end = offset + (if (source_map) |map| map[link.?.end - 1] + 1 else link.?.end) };
            }
            if (in_link) {
                if (paint) {
                    _ = SetTextColor(hdc, customColorOr("link", if (app_state.g_light_theme) RGB(30, 90, 170) else RGB(110, 175, 245)));
                    if (app_state.g_chat_hover_link != null and app_state.g_chat_hover_link.?.start == offset + link.?.start and app_state.g_chat_hover_link.?.end == offset + link.?.end) _ = SelectObject(hdc, chatLinkFont(code));
                }
            } else if (paint) {
                _ = SetTextColor(hdc, chatCodeTokenColor(if (token) |t| t.kind else .normal));
            }
            if (paint) {
                if (app_state.g_chat_find_open) {
                    if (source_map) |map| {
                        var left = rect.left;
                        for (segment, 0..) |_, i| {
                            @import("chat_find_ui.zig").paintRun(hdc, segment[i .. i + 1], offset + map[pos + i], left, rect.top, line_h);
                            left += chatTextWidth(hdc, segment[i .. i + 1]);
                        }
                    } else @import("chat_find_ui.zig").paintRun(hdc, segment, offset + pos, rect.left, rect.top, line_h);
                }
                if (app_state.g_chat_sel_active) {
                    if (source_map) |map| {
                        var left = rect.left;
                        for (segment, 0..) |_, i| {
                            chatPaintSelectionRun(hdc, segment[i .. i + 1], offset + map[pos + i], left, rect.top, line_h);
                            left += chatTextWidth(hdc, segment[i .. i + 1]);
                        }
                    } else chatPaintSelectionRun(hdc, segment, offset + pos, rect.left, rect.top, line_h);
                }
                var draw = rect;
                _ = DrawTextW(hdc, segment.ptr, @intCast(segment.len), &draw, DT_SINGLELINE | DT_NOPREFIX);
                _ = SelectObject(hdc, base);
            }
            pos += count;
            x += w;
            if (pos < word_end and x >= max_w) {
                x = indent;
                y += line_h;
            }
        }
    }
    if (height) |h| h.* = y + line_h;
    return null;
}

fn chatRichText(hdc: HANDLE, text: []const u16, area: RECT, level: u3, paint: bool, hit: ?ChatHit, offset: usize, height: ?*i32, force_bold: bool) ?link_detect.Range {
    const old_font = SelectObject(hdc, chatRichFont(.{ .bold = force_bold }, level));
    defer _ = SelectObject(hdc, old_font);
    var calc = RECT{ .left = 0, .top = 0, .right = 100, .bottom = 0 };
    const line_h = @max(1, DrawTextW(hdc, L("Ag"), 2, &calc, DT_CALCRECT | DT_SINGLELINE | DT_NOPREFIX));
    const max_w = @max(1, area.right - area.left);
    var span_buf: [512]chat_markdown.Span = undefined;
    const spans = if (text.len <= span_buf.len) span_buf[0..] else std.heap.page_allocator.alloc(chat_markdown.Span, text.len) catch return chatFlowText(hdc, text, area, false, paint, hit, offset, height, null);
    defer if (text.len > span_buf.len) std.heap.page_allocator.free(spans);
    const n = chat_markdown.inlineSpans(text, spans);
    var nearest = chat_hit.Nearest{ .char = offset };
    defer if (hit) |pt| {
        if (pt.char) |out| out.* = nearest.boundary(pt.y, offset, offset + text.len);
    };
    var x: i32 = 0;
    var y: i32 = 0;
    var raw_link = link_detect.next(text, 0);
    for (spans[0..n]) |span| {
        var style = span.style;
        style.bold = style.bold or force_bold;
        _ = SelectObject(hdc, chatRichFont(style, level));
        const space_w = chatTextWidth(hdc, &.{' '});
        var pos = span.text.start;
        while (pos < span.text.end) {
            if (text[pos] == '\r') {
                pos += 1;
                continue;
            }
            if (text[pos] == '\n' or text[pos] == ' ' or text[pos] == '\t') {
                if (x > 0) {
                    if (hit) |pt| if (pt.char != null) nearest.consider(pt.x, pt.y, area.left + x, area.top + y, area.left + x + space_w, area.top + y + line_h, offset + pos + @intFromBool(pt.x - area.left - x >= @divTrunc(space_w + 1, 2)));
                    if (paint) chatPaintSelectionRun(hdc, &.{' '}, offset + pos, area.left + x, area.top + y, line_h);
                    x += space_w;
                }
                pos += 1;
                continue;
            }
            var end = pos + 1;
            while (end < span.text.end and text[end] != ' ' and text[end] != '\t' and text[end] != '\r' and text[end] != '\n') : (end += 1) {}
            var target = span.target;
            if (target == null) {
                if (raw_link != null and raw_link.?.start < pos) raw_link = link_detect.next(text, pos);
                if (raw_link) |link| {
                    if (link.start == pos) {
                        target = .{ .start = link.start, .end = link.end };
                        end = @min(end, link.end);
                    } else if (link.start > pos and link.start < end) {
                        end = link.start;
                    }
                }
            }
            if (x > 0 and chatTextWidth(hdc, text[pos..end]) > max_w - x) {
                x = 0;
                y += line_h;
            }
            while (pos < end) {
                var fit: i32 = 0;
                var size: SIZE = undefined;
                const measured = GetTextExtentExPointW(hdc, text[pos..end].ptr, @intCast(end - pos), @max(0, max_w - x), &fit, null, &size) != 0;
                const count = chat_code.fitCount(text[pos..end], fit);
                const segment = text[pos .. pos + count];
                const w = if (measured and count == end - pos) size.cx else chatTextWidth(hdc, segment);
                var rc = RECT{ .left = area.left + x, .top = area.top + y, .right = area.left + x + w, .bottom = area.top + y + line_h };
                if (hit) |pt| {
                    if (pt.char != null) {
                        nearest.consider(pt.x, pt.y, rc.left, rc.top, rc.right, rc.bottom, offset + pos + chatCharAtX(hdc, segment, pt.x - rc.left));
                    }
                    if (pointInRect(rc, pt.x, pt.y)) {
                        if (target) |t| return .{ .start = offset + t.start, .end = offset + t.end };
                    }
                }
                if (paint) {
                    if (span.style.code) {
                        const brush = CreateSolidBrush(chatCodePanelColor());
                        _ = FillRect(hdc, &rc, brush);
                        _ = DeleteObject(brush);
                    }
                    @import("chat_find_ui.zig").paintRun(hdc, segment, offset + pos, rc.left, rc.top, line_h);
                    chatPaintSelectionRun(hdc, segment, offset + pos, rc.left, rc.top, line_h);
                    _ = SetTextColor(hdc, if (target != null) customColorOr("link", if (app_state.g_light_theme) RGB(30, 90, 170) else RGB(110, 175, 245)) else customColorOr("text", themeConsoleFg()));
                    _ = DrawTextW(hdc, segment.ptr, @intCast(segment.len), &rc, DT_SINGLELINE | DT_NOPREFIX);
                }
                x += w;
                pos += count;
                if (pos < end) {
                    x = 0;
                    y += line_h;
                }
            }
        }
    }
    if (height) |h| h.* = y + line_h;
    return null;
}
