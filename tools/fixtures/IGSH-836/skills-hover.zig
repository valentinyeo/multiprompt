        WM_MOUSEMOVE => {
            var client: RECT = std.mem.zeroes(RECT);
            _ = GetClientRect(hwnd, &client);
            if (GET_Y(lp) < 0 or GET_Y(lp) >= client.bottom - uiScaled(30)) return 0;
            const row: usize = @intCast(@max(0, @divFloor(GET_Y(lp), @max(1, uiScaled(32)))));
            const idx = row + app_state.g_chat_ac.top;
            if (row < @min(8, app_state.g_chat_ac.count -| app_state.g_chat_ac.top) and idx != app_state.g_chat_ac.sel) {
                app_state.g_chat_ac.sel = idx;
                chatAcRememberSelection();
                _ = InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
