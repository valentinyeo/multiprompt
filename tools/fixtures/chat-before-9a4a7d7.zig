fn chatRichText(hdc: HANDLE, text: []const u16, area: RECT, level: u3, paint: bool, hit: ?ChatHit, offset: usize, height: ?*i32) ?link_detect.Range {
    const old_font = SelectObject(hdc, chatRichFont(.{}, level));
    defer _ = SelectObject(hdc, old_font);
    var calc = RECT{ .left = 0, .top = 0, .right = 100, .bottom = 0 };
    const line_h = @max(1, DrawTextW(hdc, L("Ag"), 2, &calc, DT_CALCRECT | DT_SINGLELINE | DT_NOPREFIX));
    const max_w = @max(1, area.right - area.left);
    var span_buf: [512]chat_markdown.Span = undefined;
    const spans = if (text.len <= span_buf.len) span_buf[0..] else std.heap.page_allocator.alloc(chat_markdown.Span, text.len) catch return chatFlowText(hdc, text, area, false, paint, hit, offset, height, null);
    defer if (text.len > span_buf.len) std.heap.page_allocator.free(spans);
    const n = chat_markdown.inlineSpans(text, spans);
    var x: i32 = 0;
    var y: i32 = 0;
    for (spans[0..n]) |span| {
        _ = SelectObject(hdc, chatRichFont(span.style, level));
        var pos = span.text.start;
        while (pos < span.text.end) {
            if (text[pos] == '\r') {
                pos += 1;
                continue;
            }
            if (text[pos] == '\n' or text[pos] == ' ' or text[pos] == '\t') {
                if (x > 0) x += chatTextWidth(hdc, &.{' '});
                pos += 1;
                continue;
            }
            var end = pos + 1;
            while (end < span.text.end and text[end] != ' ' and text[end] != '\t' and text[end] != '\r' and text[end] != '\n') : (end += 1) {}
            var target = span.target;
            if (target == null) {
                if (link_detect.next(text, pos)) |link| {
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
                _ = GetTextExtentExPointW(hdc, text[pos..end].ptr, @intCast(end - pos), @max(0, max_w - x), &fit, null, &size);
                const count = chat_code.fitCount(text[pos..end], fit);
                const segment = text[pos .. pos + count];
                const w = chatTextWidth(hdc, segment);
                var rc = RECT{ .left = area.left + x, .top = area.top + y, .right = area.left + x + w, .bottom = area.top + y + line_h };
                if (hit) |pt| if (pointInRect(rc, pt.x, pt.y)) {
                    if (pt.char) |out| out.* = offset + pos + chatCharAtX(hdc, segment, pt.x - rc.left);
                    if (target) |t| return .{ .start = offset + t.start, .end = offset + t.end };
                };
                if (paint) {
                    if (span.style.code) {
                        const brush = CreateSolidBrush(chatCodePanelColor());
                        _ = FillRect(hdc, &rc, brush);
                        _ = DeleteObject(brush);
                    }
                    chatPaintSelectionRun(hdc, segment, offset + pos, rc.left, rc.top, line_h);
                    _ = SetTextColor(hdc, if (target != null) customColorOr("link", if (g_light_theme) RGB(30, 90, 170) else RGB(110, 175, 245)) else customColorOr("text", themeConsoleFg()));
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
