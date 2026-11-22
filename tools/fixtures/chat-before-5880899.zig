fn ensureUsageTelemetryCollector() void {
    var executable: [768]u16 = std.mem.zeroes([768]u16);
    const length = GetModuleFileNameW(null, &executable, executable.len);
    if (length == 0 or length >= executable.len) return;
    if (usage_telemetry_mode.isRunning()) return;
    _ = ShellExecuteW(null, L("open"), @ptrCast(&executable), L("--usage-telemetry"), null, SW_HIDE);
}

fn chatRelayout(client_width: i32) void {
    g_chat_layout_dirty = false;
    g_chat_layout_width = client_width;
    if (client_width <= 0 or g_chat_transcript_hwnd == null) {
        g_chat_content_h = 0;
        g_chat_echo_layout_count = 0;
        g_chat_content_left = 0;
        return;
    }
    const hdc = GetDC(g_chat_transcript_hwnd);
    if (hdc == null) {
        g_chat_content_h = 0;
        g_chat_echo_layout_count = 0;
        return;
    }
    defer _ = ReleaseDC(g_chat_transcript_hwnd, hdc);
    const content = chatContentRectInset(client_width);
    g_chat_content_left = content.left;
    const width = @max(1, content.right - content.left);
    const buf = g_chat_capture[0..g_chat_last_len];
    chat_style.bubblePositions(g_chat_blocks[0..g_chat_block_count], g_chat_bubble_pos[0..g_chat_block_count]);
    var y: i32 = 0;
    g_chat_img_pass +%= 1;
    const first_img_block = chatImgFirstBlock(buf);
    for (0..g_chat_block_count) |i| {
        y += chatBlockGapBefore(i > 0, g_chat_blocks[i].role, g_chat_blocks[i].first, g_chat_bubble_pos[i]);
        var block_imgs = ChatImgLayout{};
        const rc = chatMeasureBlockRect(hdc, buf, g_chat_blocks[i], g_chat_bubble_pos[i], width, y, if (i >= first_img_block) &block_imgs else null);
        g_chat_layout_rects[i] = rc;
        chatImgStoreLayout(i, block_imgs);
        y = rc.bottom;
    }
    g_chat_echo_layout_count = 0;
    if (active_shell < shell_count) {
        var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
        const key = chatOutboxKeyForShell(active_shell, &key_buf);
        if (key.len > 0) {
            for (g_chat_outbox.items) |e| {
                if (g_chat_echo_layout_count >= g_chat_echo_layout.len) break;
                if (!std.mem.eql(u8, e.key[0..@as(usize, e.key_len)], key)) continue;
                y += chatBlockGapBefore(true, .user, true, .single);
                var rc = chatMeasureEchoRect(hdc, e.text, width, y, true);
                rc.left += g_chat_content_left;
                rc.right += g_chat_content_left;
                g_chat_echo_layout[g_chat_echo_layout_count] = rc;
                g_chat_echo_layout_ids[g_chat_echo_layout_count] = e.id;
                g_chat_echo_layout_count += 1;
                y = rc.bottom;
            }
        }
    }
    g_chat_content_h = y;
}

fn chatFlowText(hdc: HANDLE, text: []const u16, area: RECT, code: bool, paint: bool, hit: ?ChatHit, offset: usize, height: ?*i32, source_map: ?[]const usize) ?link_detect.Range {
    const base = if (code) ensureChatCodeFont() else ensureChatFont();
    const old_font = SelectObject(hdc, base);
    defer _ = SelectObject(hdc, old_font);
    var line_rc = RECT{ .left = 0, .top = 0, .right = 100, .bottom = 0 };
    const line_h = @max(1, DrawTextW(hdc, L("Ag"), 2, &line_rc, DT_CALCRECT | DT_SINGLELINE | DT_NOPREFIX));
    const max_w = @max(1, area.right - area.left);
    var indent: i32 = if (code) 0 else chatLineIndentPx(hdc, text, 0);
    if (indent >= max_w) indent = 0;
    var x: i32 = 0;
    var y: i32 = 0;
    var pos: usize = 0;
    var search: usize = 0;
    var link: ?link_detect.Range = null;
    var syntax = chat_code.Iterator{ .text = text };
    var token: ?chat_code.Token = if (code) syntax.next() else null;
    while (pos < text.len) {
        if (text[pos] == '\r' or text[pos] == '\n') {
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
            if (hit) |pt| if (pointInRect(rect, pt.x, pt.y)) {
                if (pt.char) |out| {
                    const at = pos + chatCharAtX(hdc, segment, pt.x - rect.left);
                    out.* = offset + (if (source_map) |map| map[@min(at, map.len - 1)] else at);
                }
                if (in_link) return .{ .start = offset + (if (source_map) |map| map[link.?.start] else link.?.start), .end = offset + (if (source_map) |map| map[link.?.end - 1] + 1 else link.?.end) };
            };
            if (in_link) {
                if (paint) {
                    _ = SetTextColor(hdc, customColorOr("link", if (g_light_theme) RGB(30, 90, 170) else RGB(110, 175, 245)));
                    if (g_chat_hover_link != null and g_chat_hover_link.?.start == offset + link.?.start and g_chat_hover_link.?.end == offset + link.?.end) _ = SelectObject(hdc, chatLinkFont(code));
                }
            } else if (paint) {
                _ = SetTextColor(hdc, chatCodeTokenColor(if (token) |t| t.kind else .normal));
            }
            if (paint) {
                if (source_map) |map| {
                    var left = rect.left;
                    for (segment, 0..) |_, i| {
                        chatPaintSelectionRun(hdc, segment[i .. i + 1], offset + map[pos + i], left, rect.top, line_h);
                        left += chatTextWidth(hdc, segment[i .. i + 1]);
                    }
                } else chatPaintSelectionRun(hdc, segment, offset + pos, rect.left, rect.top, line_h);
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
