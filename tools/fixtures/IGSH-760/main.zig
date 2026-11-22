        WM_CTLCOLOREDIT, WM_CTLCOLORSTATIC => {
            const child: HANDLE = if (lp == 0) null else @ptrFromInt(@as(usize, @bitCast(lp)));
            if (child == app_state.g_chat_composer_hwnd) {
                refreshChatBrushes();
                const dc: HANDLE = if (wp == 0) null else @ptrFromInt(wp);
                _ = SetTextColor(dc, if (@import("chat_composer_text.zig").enabled() and !@import("chat_composer_text.zig").native_paint) app_state.g_chat_input_color else customColorOr("text", themeConsoleFg()));
                _ = SetBkColor(dc, app_state.g_chat_input_color);
                if (app_state.g_chat_input_brush != null) return @bitCast(@as(usize, @intFromPtr(app_state.g_chat_input_brush.?)));
            }
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
