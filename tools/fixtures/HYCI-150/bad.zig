fn paint() void {
            if (entry.items.len == 0) {
                if (entry.summary.len > 0) drawChangeRow(hdc, layout, noteSelection(idx, 0), entry.summary, entry.ticket, text, dim, selected, body_font, action_font.handle);
            } else for (entry.items, 0..) |item, i| {
                const sel = noteSelection(idx, i);
                const range = selectionRange(sel);
                if (range.top + range.h <= app_state.g_changelog_scroll) continue;
                if (range.top >= app_state.g_changelog_scroll + layout.view_h) break;
                drawChangeRow(hdc, layout, sel, item.text, item.ticket, text, dim, selected, body_font, action_font.handle);
            };
}
