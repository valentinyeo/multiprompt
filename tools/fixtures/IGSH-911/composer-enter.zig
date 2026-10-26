pub fn chatComposerOwnsKey(wp: WPARAM, vkCode: DWORD, ctrl: bool, alt: bool, flags: DWORD) bool {
    if (wp != WM_KEYDOWN and wp != WM_SYSKEYDOWN) return false;
    if (ctrl and (flags & 0x20) != 0) return true;
    if (alt and !ctrl) return false;
    if (wp != WM_KEYDOWN) return false;
    if (vkCode == 0x70 or vkCode == 0x71) return false;
    if (!ctrl) return true;
    return switch (vkCode) {
        0x41, 0x43, 0x44, 0x56, 0x58, 0x59, 0x5A => true,
        0xBF => true,
        0x25, 0x27 => true,
        0x08, 0x2E => true,
        else => false,
    };
}

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
