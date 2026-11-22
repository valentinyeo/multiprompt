fn chatComposerSubclassProc(hwnd: HANDLE, msg: UINT, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT {
    defer @import("chat_composer_text.zig").invalidateAfter(hwnd, msg);
    if (@import("fonts.zig").editMessage(hwnd, app_state.g_main_hwnd, msg, lp)) |result| return result;
    if (msg == 0x0233) {
        chatDropFiles(@ptrFromInt(wp));
        return 0;
    }
    const prior_focus_action = app_state.g_focus_user_action_tick;
    app_state.g_focus_user_action_tick = focusGuardDispatchTick(msg, wp, lp);
    defer app_state.g_focus_user_action_tick = prior_focus_action;
    if (@import("chat_find_ui.zig").windowKey(msg, wp)) return 0;
    if (msg == WM_KEYDOWN and wp == 0x1B and app_state.g_chat_reply_len > 0 and GetWindowTextLengthW(hwnd) == 0 and !app_state.g_chat_ac.open) {
        clearChatReply();
        return 0;
    }
    if (msg == WM_KEYDOWN and wp == 0x1B and app_state.g_chat_sel_active and !app_state.g_chat_ac.open) {
        chatSelectionClear();
        app_state.g_chat_sel_transcript_focus = false;
        if (app_state.g_chat_transcript_hwnd != null) _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
        return 0;
    }
    if (msg == 0x0102 and app_state.g_chat_sel_transcript_focus and @import("chat_render.zig").chatSelectionReply(msg, wp, lp)) return 0;
    if (msg == 0x0201 or msg == 0x0102) app_state.g_chat_sel_transcript_focus = false;
    if ((msg == 0x0201 or msg == 0x0102) and app_state.g_chat_sel_active) {
        chatSelectionClear();
        if (app_state.g_chat_transcript_hwnd != null) _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    }
    if (!app_state.g_chat_ac.open and msg == WM_KEYDOWN and (wp == 0x21 or wp == 0x22) and !app_state.g_chat_composer_scroll_shown and app_state.g_chat_transcript_hwnd != null) {
        _ = SendMessageW(app_state.g_chat_transcript_hwnd, WM_KEYDOWN, wp, lp);
        return 0;
    }
    const can_edit = msg == 0x0102 or msg == WM_KEYDOWN or msg == 0x000C or msg == 0x00C2 or
        msg == 0x0300 or msg == 0x0302 or msg == 0x0303 or msg == 0x0304 or msg == 0x00C7;
    const was_empty = can_edit and GetWindowTextLengthW(hwnd) == 0;
    const result = chatComposerSubclassCore(hwnd, msg, wp, lp);
    if (can_edit) {
        if (was_empty != (GetWindowTextLengthW(hwnd) == 0)) {
            _ = InvalidateRect(hwnd, null, 1);
            if (hwnd == app_state.g_chat_composer_hwnd and @import("window_layout.zig").chatStopVisible()) chatComposerButtonsRefresh();
        }
        chatComposerAutoGrow();
        chatDraftNoteEdit();
        if (!chat_draft_loading and !shell_applying) shell_draft.onComposerEdit(GetTickCount64());
        if (msg == 0x0102 and wp >= 32 and !isCtrlDown()) app_state.g_chat_ac.browse = false;
        if (!(msg == WM_KEYDOWN and (wp == 0x0D or wp == 0x09 or wp == 0x26 or wp == 0x28 or wp == 0x21 or wp == 0x22 or
            wp == 0x10 or wp == 0x11 or wp == 0x12 or wp == 0xA0 or wp == 0xA1 or wp == 0xA2 or wp == 0xA3 or wp == 0xA4 or wp == 0xA5)))
            chatAcOnComposerChanged();
    } else if (msg == WM_LBUTTONUP or (msg == WM_KEYUP and
        !(app_state.g_chat_ac.open and (wp == 0x26 or wp == 0x28 or wp == 0x21 or wp == 0x22))))
    {
        chatAcOnComposerChanged();
    }
    return result;
}

fn chatComposerSubclassCore(hwnd: HANDLE, msg: UINT, wp: WPARAM, lp: LPARAM) LRESULT {
    if (msg == WM_KEYDOWN and wp == 0x41 and isCtrlDown() and (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) == 0) {
        _ = SendMessageW(hwnd, 0x00B1, 0, -1);
        return 0;
    }
    if (msg == 0x0102 and wp == 0x01) return 0;
    if (chatImagePasteIntercept(msg, wp)) return 0;
    if (msg == WM_KEYDOWN and chatCopyCodeKeyDown(wp)) {
        chatCopyLatestCode();
        return 0;
    }

    if (msg == WM_PAINT or msg == 0x0318) {
        const result = CallWindowProcW(app_state.g_chat_composer_orig_proc, hwnd, msg, wp, lp);
        const dc = if (msg == WM_PAINT) GetDC(hwnd) else @as(HANDLE, @ptrFromInt(wp));
        if (dc == null) return result;
        defer if (msg == WM_PAINT) {
            _ = ReleaseDC(hwnd, dc);
        };
        var probe: [2]u16 = .{ 0, 0 };
        if (GetWindowTextW(hwnd, &probe, 2) == 0) {
            var rc: RECT = std.mem.zeroes(RECT);
            _ = SendMessageW(hwnd, 0x00B2, 0, @bitCast(@as(isize, @intCast(@intFromPtr(&rc)))));
            if (rc.right <= rc.left) {
                _ = GetClientRect(hwnd, &rc);
                rc.left += uiScaled(2);
            }
            _ = SetBkMode(dc, TRANSPARENT);
            _ = SelectObject(dc, ensureChatFont());
            _ = SetTextColor(dc, customColorOr("subtitle", if (app_state.g_light_theme) RGB(112, 117, 128) else RGB(137, 146, 164)));
            _ = chatDrawText(dc, L("Message this session"), -1, &rc, DT_SINGLELINE | DT_NOPREFIX);
        } else if (@import("chat_composer_text.zig").enabled()) {
            if (!@import("chat_composer_text.zig").paint(hwnd, dc, customColorOr("text", themeConsoleFg()), app_state.g_chat_input_color)) {
                @import("chat_composer_text.zig").native_paint = true;
                defer @import("chat_composer_text.zig").native_paint = false;
                _ = CallWindowProcW(app_state.g_chat_composer_orig_proc, hwnd, 0x0318, @intFromPtr(dc), 4);
            }
        }
        return result;
    }
    if (msg == WM_KEYDOWN and wp != 0x09) app_state.g_chat_ac_tab_accepted = false;
    if (msg == WM_KEYDOWN and wp == 0xBF and isCtrlDown() and (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) == 0) {
        chatAcOpenBrowse();
        return 0;
    }
    if (msg == WM_KEYDOWN and app_state.g_chat_ac.open) {
        switch (wp) {
            0x26 => {
                chatAcMove(-1);
                return 0;
            },
            0x28 => {
                chatAcMove(1);
                return 0;
            },
            0x21 => {
                chatAcMove(-8);
                return 0;
            },
            0x22 => {
                chatAcMove(8);
                return 0;
            },
            0x09 => {
                if (chatAcAccept()) {
                    app_state.g_chat_ac_tab_accepted = true;
                    return 0;
                }
                chatAcClose();
            },
            0x1B => {
                var text: [16384]u16 = undefined;
                const n = GetWindowTextW(hwnd, &text, text.len);
                const token = app_state.g_chat_ac.token;
                if (n >= 0 and token.end <= @as(usize, @intCast(n)) and token.end - token.start <= app_state.g_chat_ac.dismissed_text.len) {
                    app_state.g_chat_ac.dismissed = true;
                    app_state.g_chat_ac.dismissed_start = token.start;
                    app_state.g_chat_ac.dismissed_len = token.end - token.start;
                    @memcpy(app_state.g_chat_ac.dismissed_text[0..app_state.g_chat_ac.dismissed_len], text[token.start..token.end]);
                }
                chatAcClose();
                return 0;
            },
            else => {},
        }
    }
    if (msg == WM_KILLFOCUS) {
        if (hwnd == app_state.g_chat_composer_hwnd) @import("diagnostics.zig").focusTrace(.composer_killfocus, @ptrFromInt(wp), 0);
        chatAcClose();
    }
    if (msg == WM_KEYDOWN and wp == 0x1B) {
        if (@import("chat_working.zig").composerEscStops(@import("window_layout.zig").chatWorkingBarVisible(), app_state.g_chat_ac.open, app_state.g_chat_sel_active) and (lp & 0x40000000) == 0) _ = @import("chat_send.zig").chatStopAgent(app_state.active_shell);
        return 0;
    }
    if (msg == WM_KEYDOWN and chatPaletteToggleKeyDown(wp)) {
        postPaletteToggle();
        return 0;
    }
    if (msg == 0x0102) {
        if (wp == 0x09 and app_state.g_chat_ac_tab_accepted) {
            app_state.g_chat_ac_tab_accepted = false;
            return 0;
        }
        if (wp == 0x1B or wp == 0x0B or (wp == 0x09 and app_state.g_chat_ac.open) or ((wp == 0x2F or wp == 0x1F) and isCtrlDown() and (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) == 0)) return 0;
        if (wp == 0x0D) {
            const shift = (GetAsyncKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
            if (!shift) {
                if (app_state.g_chat_ac.open and !CHAT_AC_ENTER_SENDS) {
                    if (chatAcAccept()) return 0;
                    chatAcClose();
                }
                chatShellDraftNoteSend();
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHAT_SEND, 0, 0);
                return 0;
            }
            chatAcClose();
        }
    }
    return CallWindowProcW(app_state.g_chat_composer_orig_proc, hwnd, msg, wp, lp);
}
