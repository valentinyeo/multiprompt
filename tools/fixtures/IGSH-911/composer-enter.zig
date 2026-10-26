fn chatComposerSubclassCore() void {
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
    return CallWindowProcW();
}
