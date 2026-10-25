const std = @import("std");
pub const OPENFILENAMEW = @import("app_state.zig").OPENFILENAMEW;
pub const CREDUI_INFOW = @import("app_state.zig").CREDUI_INFOW;

pub const WINAPI: std.builtin.CallingConvention = .winapi;
pub const BOOL = i32;
pub const DWORD = u32;
pub const WORD = u16;
pub const UINT = u32;
pub const LONG = i32;
pub const LONG_PTR = isize;
pub const WPARAM = usize;
pub const LPARAM = isize;
pub const LRESULT = isize;
const ATOM = u16;
pub const HANDLE = ?*anyopaque;
pub const LPCWSTR = [*:0]const u16;
pub const HKEY = HANDLE;

pub const WS_OVERLAPPEDWINDOW: u32 = 0x00CF0000;
pub const WS_MAXIMIZE: u32 = 0x01000000;
pub const WS_VISIBLE: u32 = 0x10000000;
pub const WS_POPUP: u32 = 0x80000000;
pub const WS_CHILD: u32 = 0x40000000;
pub const WS_CLIPSIBLINGS: u32 = 0x04000000;
pub const WS_CLIPCHILDREN: u32 = 0x02000000;
pub const WS_CAPTION: u32 = 0x00C00000;
pub const WS_MAXIMIZEBOX: u32 = 0x00010000;
pub const WS_MINIMIZEBOX: u32 = 0x00020000;
pub const WS_THICKFRAME: u32 = 0x00040000;
pub const WS_BORDER: u32 = 0x00800000;
pub const WS_VSCROLL: u32 = 0x00200000;
pub const WS_HSCROLL: u32 = 0x00100000;
const CS_HREDRAW: u32 = 0x0002;
const CS_VREDRAW: u32 = 0x0001;
pub const CS_DBLCLKS: u32 = 0x0008;
pub const CW_USEDEFAULT: i32 = @bitCast(@as(u32, 0x80000000));
pub const GWL_STYLE: i32 = -16;
pub const GWL_EXSTYLE: i32 = -20;
pub const GWLP_HWNDPARENT: i32 = -8;
pub const SWP_FRAMECHANGED: u32 = 0x0020;
pub const SWP_NOZORDER: u32 = 0x0004;
pub const SWP_NOMOVE: u32 = 0x0002;
pub const SWP_NOSIZE: u32 = 0x0001;
pub const SWP_NOACTIVATE: u32 = 0x0010;
pub const SWP_SHOWWINDOW: u32 = 0x0040;
pub const SWP_HIDEWINDOW: u32 = 0x0080;
pub const SWP_NOREDRAW: u32 = 0x0008;
pub const SWP_ASYNCWINDOWPOS: u32 = 0x4000;
pub const WS_EX_APPWINDOW: u32 = 0x00040000;
pub const WS_EX_TOOLWINDOW: u32 = 0x00000080;
pub const WS_EX_TOPMOST: u32 = 0x00000008;
pub const WS_EX_LAYERED: u32 = 0x00080000;
pub const WS_EX_NOACTIVATE: u32 = 0x08000000;
pub const WS_EX_TRANSPARENT: u32 = 0x00000020;
pub const GW_HWNDFIRST: UINT = 0;
pub const GW_HWNDLAST: UINT = 1;
pub const GW_HWNDNEXT: UINT = 2;
pub const GW_HWNDPREV: UINT = 3;
pub const LWA_ALPHA: DWORD = 0x00000002;
pub const WM_ACTIVATEAPP: u32 = 0x001C;
pub const WM_SETTINGCHANGE: u32 = 0x001A;
pub const WM_THEMECHANGED: u32 = 0x031A;
pub const WM_KILLFOCUS: u32 = 0x0008;
pub const WM_SETFOCUS: u32 = 0x0007;
pub const HWND_TOP: HANDLE = @ptrFromInt(0);
pub const HWND_TOPMOST: HANDLE = @as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))));
pub const WM_DESTROY: u32 = 0x0002;
pub const WM_MOVE: u32 = 0x0003;
pub const WM_WINDOWPOSCHANGED: u32 = 0x0047;
pub const WM_SIZE: u32 = 0x0005;
pub const WM_DPICHANGED: u32 = 0x02E0;
pub const WM_DISPLAYCHANGE: u32 = 0x007E;
pub const WM_GETMINMAXINFO: u32 = 0x0024;
pub const WM_PAINT: u32 = 0x000F;
pub const WM_NCHITTEST: u32 = 0x0084;
pub const WM_COMMAND: u32 = 0x0111;
pub const WM_CTLCOLOREDIT: u32 = 0x0133;
pub const WM_CTLCOLORSTATIC: u32 = 0x0138;
pub const WM_LBUTTONDOWN: u32 = 0x0201;
pub const WM_LBUTTONUP: u32 = 0x0202;
pub const WM_MOUSEMOVE: u32 = 0x0200;
pub const WM_LBUTTONDBLCLK: u32 = 0x0203;
pub const MOUSEEVENTF_LEFTDOWN: DWORD = 0x0002;
pub const LLMHF_INJECTED: DWORD = 0x00000001;
pub const CREATE_NEW_CONSOLE: u32 = 0x00000010;
pub const SW_SHOW: i32 = 5;
pub const SW_HIDE: i32 = 0;
pub const SW_SHOWNOACTIVATE: i32 = 4;
pub const STARTF_USESHOWWINDOW: u32 = 0x00000001;
pub const SW_RESTORE: i32 = 9;
pub const WM_HOTKEY: u32 = 0x0312;
pub const HOTKEY_ID_FOCUS: i32 = 1;
pub const MOD_CONTROL: UINT = 0x0002;
pub const MOD_SHIFT: UINT = 0x0004;
pub const DT_SINGLELINE: u32 = 0x20;
pub const DT_VCENTER: u32 = 0x04;
pub const DT_CENTER: u32 = 0x01;
pub const DT_RIGHT: u32 = 0x02;
pub const DT_WORDBREAK: u32 = 0x10;
pub const DT_NOPREFIX: u32 = 0x800;
pub const DT_END_ELLIPSIS: u32 = 0x8000;
pub const DT_CALCRECT: u32 = 0x400;
pub const TRANSPARENT: i32 = 1;
pub const HTTRANSPARENT: LRESULT = -1;
pub const DEFAULT_GUI_FONT: i32 = 17;
pub const NULL_BRUSH: i32 = 5;
pub const NULL_PEN: i32 = 8;
pub const ES_AUTOHSCROLL: u32 = 0x0080;
const ES_NOHIDESEL: u32 = 0x0100;
pub const ES_MULTILINE: u32 = 0x0004;
pub const ES_AUTOVSCROLL: u32 = 0x0040;
const ES_READONLY: u32 = 0x0800;
pub const ES_WANTRETURN: u32 = 0x1000;
pub const WS_TABSTOP: u32 = 0x00010000;
pub const EN_KILLFOCUS: u32 = 0x0200;
pub const MK_LBUTTON: u32 = 0x0001;
pub const WH_KEYBOARD_LL: i32 = 13;
pub const WH_MOUSE_LL: i32 = 14;
pub const HC_ACTION: i32 = 0;
pub const EVENT_SYSTEM_FOREGROUND: DWORD = 0x0003;
pub const EVENT_SYSTEM_MOVESIZESTART: DWORD = 0x000A;
pub const EVENT_SYSTEM_MOVESIZEEND: DWORD = 0x000B;
pub const EVENT_OBJECT_LOCATIONCHANGE: DWORD = 0x800B;
pub const EVENT_OBJECT_DESTROY: DWORD = 0x8001;
pub const WINEVENT_OUTOFCONTEXT: UINT = 0x0000;
pub const OBJID_WINDOW: LONG = 0;
pub const VK_LBUTTON_I32: i32 = 0x01;
pub const WM_CANCELMODE: u32 = 0x001F;
pub const VK_ESCAPE: WPARAM = 0x1B;
pub const WM_KEYDOWN: u32 = 0x0100;
pub const WM_KEYUP: u32 = 0x0101;
pub const WM_SYSKEYUP: u32 = 0x0105;
pub const WM_APP: u32 = 0x8000;
pub const WM_APP_NEXT_TAB: u32 = WM_APP + 1;
pub const WM_APP_PREV_TAB: u32 = WM_APP + 2;
pub const WM_APP_SPAWN: u32 = WM_APP + 3;
pub const WM_APP_CLOSE: u32 = WM_APP + 4;
pub const WM_APP_FOCUS: u32 = WM_APP + 5;
pub const WM_APP_COMMIT_RENAME: u32 = WM_APP + 6;
pub const WM_APP_RENAME_TAB: u32 = WM_APP + 7;
pub const WM_APP_SWITCH_TAB: u32 = WM_APP + 12;
pub const WM_APP_SEARCH_OPEN: u32 = WM_APP + 13;
pub const WM_APP_SEARCH_CLOSE: u32 = WM_APP + 14;
pub const WM_APP_SEARCH_CHAR: u32 = WM_APP + 15;
pub const WM_APP_SEARCH_BACKSPACE: u32 = WM_APP + 16;
pub const WM_APP_SEARCH_MOVE: u32 = WM_APP + 17;
pub const WM_APP_SEARCH_CONFIRM: u32 = WM_APP + 18;
pub const WM_APP_REOPEN_CLOSED: u32 = WM_APP + 19;
pub const WM_APP_TOGGLE_SIDEBAR: u32 = WM_APP + 20;
pub const WM_APP_TMUX_LIST_READY: u32 = WM_APP + 21;
const WM_APP_TOGGLE_INACTIVE: u32 = WM_APP + 22;
const WM_APP_INACTIVE_CONNECT: u32 = WM_APP + 23;
pub const WM_APP_NEW_WINDOW: u32 = WM_APP + 24;
pub const WM_APP_PASTE: u32 = WM_APP + 25;
pub const WM_APP_COPY: u32 = WM_APP + 26;
pub const WM_APP_OPEN_URL_AT: u32 = WM_APP + 27;
pub const WM_APP_NEXT_UNREAD: u32 = WM_APP + 28;
pub const WM_APP_URL_PICKER_OPEN: u32 = WM_APP + 29;
pub const WM_APP_URL_PICKER_MOVE: u32 = WM_APP + 30;
pub const WM_APP_URL_PICKER_CONFIRM: u32 = WM_APP + 31;
pub const WM_APP_URL_PICKER_CLOSE: u32 = WM_APP + 32;
pub const WM_APP_SSH_UNAVAILABLE: u32 = WM_APP + 39;
pub const WM_APP_NOTIFY: u32 = WM_APP + 40;
pub const WM_APP_SHELL_EXITED: u32 = WM_APP + 41;
pub const WM_APP_FAVICON_FETCHED: u32 = WM_APP + 42;
pub const WM_APP_MOVE_TAB: u32 = WM_APP + 43;
pub const WM_APP_TOGGLE_GROUP: u32 = WM_APP + 44;
pub const WM_APP_COPY_OR_INTERRUPT: u32 = WM_APP + 45;
pub const WM_APP_RENAME_WINDOW: u32 = WM_APP + 46;
pub const WM_APP_QUIT_ALL: u32 = WM_APP + 47;
pub const WM_APP_DEV_FONT_NEXT: u32 = WM_APP + 48;
pub const WM_APP_DEV_SIZE_DOWN: u32 = WM_APP + 49;
pub const WM_APP_DEV_SIZE_UP: u32 = WM_APP + 50;
pub const WM_APP_DEV_AMOLED: u32 = WM_APP + 51;
pub const WM_APP_TOGGLE_FULLWIDTH: u32 = WM_APP + 52;
pub const WM_APP_SHORTCUTS_OPEN: u32 = WM_APP + 53;
pub const WM_APP_SHORTCUTS_CLOSE: u32 = WM_APP + 54;
pub const WM_APP_SHORTCUTS_SCROLL: u32 = WM_APP + 55;
pub const WM_APP_RECONNECT: u32 = WM_APP + 56;
pub const WM_APP_TOGGLE_INBOX: u32 = WM_APP + 57;
pub const WM_APP_INBOX_KEY: u32 = WM_APP + 58;
pub const WM_APP_FOCUS_SHELL: u32 = WM_APP + 59;
pub const WM_APP_SWITCH_WORKSPACE: u32 = WM_APP + 60;
pub const WM_APP_INBOX_STEP: u32 = WM_APP + 61;
pub const WM_APP_CYCLE_WORKSPACE: u32 = WM_APP + 62;
pub const WM_APP_WSSORT_MOVE: u32 = WM_APP + 63;
pub const WM_APP_SYSMENU: u32 = WM_APP + 64;
pub const WM_APP_WIN_SNAP: u32 = WM_APP + 65;
pub const WM_APP_INBOX_ARCHIVE: u32 = WM_APP + 66;
pub const WM_APP_INBOX_MARKUNREAD: u32 = WM_APP + 67;
pub const WM_APP_TOGGLE_UNREAD: u32 = WM_APP + 68;
pub const WM_APP_FONT_BIGGER: u32 = WM_APP + 69;
pub const WM_APP_FONT_SMALLER: u32 = WM_APP + 70;
pub const WM_APP_FONT_RESET: u32 = WM_APP + 71;
pub const WM_APP_UI_BIGGER: u32 = WM_APP + 72;
pub const WM_APP_UI_SMALLER: u32 = WM_APP + 73;
pub const WM_APP_UI_RESET: u32 = WM_APP + 74;
pub const WM_APP_NEW_TAB_DEFAULT: u32 = WM_APP + 75;
pub const WM_APP_HIDE_TAB_UNTIL_ATTENTION: u32 = WM_APP + 76;
pub const WM_APP_BROWSER_TOGGLE: u32 = WM_APP + 77;
pub const WM_APP_BROWSER_OPEN_URL: u32 = WM_APP + 78;
pub const WM_APP_ZSB_OPEN: u32 = WM_APP + 79;
pub const WM_APP_BROWSER_FOCUS_URL: u32 = WM_APP + 80;
pub const WM_APP_BROWSER_FOCUS_TOGGLE: u32 = WM_APP + 81;
pub const WM_APP_CHANGELOG_OPEN: u32 = WM_APP + 82;
pub const WM_APP_CHANGELOG_CLOSE: u32 = WM_APP + 83;
pub const WM_APP_CHANGELOG_MOVE: u32 = WM_APP + 84;
pub const WM_APP_CHANGELOG_CONFIRM: u32 = WM_APP + 85;
pub const WM_APP_BROWSER_URL_UPDATE: u32 = WM_APP + 86;
pub const WM_APP_BROWSER_BACK: u32 = WM_APP + 87;
pub const WM_APP_BROWSER_FORWARD: u32 = WM_APP + 88;
pub const WM_APP_SHOW_SIDEBAR: u32 = WM_APP + 89;
pub const WM_APP_URLBAR_DISMISS: u32 = WM_APP + 90;
pub const WM_APP_BROWSER_MODE_TOGGLE: u32 = WM_APP + 91;
pub const WM_APP_RESTART: u32 = WM_APP + 92;
pub const WM_APP_ZSB_BIND: u32 = WM_APP + 93;
pub const WM_APP_BROWSER_RESOLVED: u32 = WM_APP + 199;
pub const WM_APP_DIAG: u32 = WM_APP + 94;
pub const WM_APP_DICTATION_TOGGLE: u32 = WM_APP + 95;
pub const WM_APP_DICTATION_READY: u32 = WM_APP + 96;
pub const WM_APP_CLOSE_SESSION: u32 = WM_APP + 97;
pub const WM_APP_SNIPPETS_OPEN: u32 = WM_APP + 98;
pub const WM_APP_SNIPPET_FORM_SAVE: u32 = WM_APP + 99;
pub const WM_APP_SNIPPET_FORM_CANCEL: u32 = WM_APP + 100;
pub const WM_APP_ALL_SESSIONS_OPEN: u32 = WM_APP + 101;
pub const WM_APP_ALL_SESSIONS_KEY: u32 = WM_APP + 102;
pub const WM_APP_REMIND_PRESETS_OPEN: u32 = WM_APP + 103;
pub const WM_APP_ARCHIVE_ARM: u32 = WM_APP + 104;
pub const WM_APP_SHOT_PASTE: u32 = WM_APP + 105;
pub const WM_APP_BROWSER_SHOTURL: u32 = WM_APP + 106;
pub const WM_APP_MARK_ACTIVE_UNREAD: u32 = WM_APP + 107;
pub const WM_APP_SNIPPET_DELETE: u32 = WM_APP + 108;
pub const WM_APP_INBOX_UNARCHIVE: u32 = WM_APP + 109;
pub const WM_APP_ALL_SESSIONS_FILTER_OPEN: u32 = WM_APP + 110;
pub const WM_APP_ALL_SESSIONS_FILTER_CHAR: u32 = WM_APP + 111;
pub const WM_APP_ALL_SESSIONS_FILTER_BACKSPACE: u32 = WM_APP + 112;
pub const WM_APP_ALL_SESSIONS_FILTER_CLOSE: u32 = WM_APP + 113;
pub const WM_APP_WEBVIEW2_TOGGLE: u32 = WM_APP + 114;
pub const WM_APP_WEBVIEW2_ACTION: u32 = WM_APP + 115;
pub const WM_APP_WEBVIEW2_FOCUS: u32 = WM_APP + 116;
pub const WM_APP_SESSION_INTERACTED: u32 = WM_APP + 118;
pub const WM_APP_BROWSER_DROP_GESTURE: u32 = WM_APP + 119;
pub const WM_APP_AI_PACE_READY: u32 = WM_APP + 120;
pub const WM_APP_CYCLE_STATUS_CARD: u32 = WM_APP + 121;
pub const WM_APP_SEARCH_SELECT_ALL: u32 = WM_APP + 122;
pub const WM_APP_COPY_CLAUDE_LOGIN_URL: u32 = WM_APP + 123;
pub const WM_APP_INBOX_FILTER_OPEN: u32 = WM_APP + 124;
pub const WM_APP_INBOX_FILTER_CHAR: u32 = WM_APP + 125;
pub const WM_APP_INBOX_FILTER_BACKSPACE: u32 = WM_APP + 126;
pub const WM_APP_INBOX_FILTER_CLOSE: u32 = WM_APP + 127;
pub const WM_APP_BROWSER_ENGINE_TOGGLE: u32 = WM_APP + 128;
pub const WM_APP_INPUT_HOOK_RECOVER: u32 = WM_APP + 129;
pub const WM_APP_CHAT_TOGGLE: u32 = WM_APP + 130;
pub const WM_APP_CHAT_AC_READY: u32 = WM_APP + 143;
pub const WM_APP_CHAT_SEND: u32 = WM_APP + 131;
pub const WM_APP_CHAT_INTERRUPT: u32 = WM_APP + 132;
pub const WM_APP_POWER_ACTIVITY: u32 = WM_APP + 133;
pub const WM_APP_TOGGLE_KEEP_AWAKE: u32 = WM_APP + 134;
pub const WM_APP_VOICE_TOGGLE: u32 = WM_APP + 135;
pub const WM_APP_VOICE_BARGE_IN: u32 = WM_APP + 136;
pub const WM_APP_VOICE_TTS_FALLBACK: u32 = WM_APP + 137;
pub const WM_APP_VOICE_SPEECH_START: u32 = WM_APP + 139;
pub const WM_APP_VOICE_UTTERANCE_READY: u32 = WM_APP + 140;
pub const WM_APP_VOICE_MIC_STATUS: u32 = WM_APP + 141;
pub const WM_APP_VOICE_TTS_AUDIO_STARTED: u32 = WM_APP + 138;
pub const WM_APP_WS_SNOOZE_OPEN: u32 = WM_APP + 144;
pub const WM_APP_VOICE_STEP: u32 = WM_APP + 145;
pub const WM_APP_CHAT_FILE_READY: u32 = WM_APP + 146;
pub const WM_APP_CHAT_COPY_CODE: u32 = WM_APP + 147;
pub const WM_APP_CHAT_COPY_SELECTION: u32 = WM_APP + 148;
pub const WM_APP_CHAT_SELECT_ALL: u32 = WM_APP + 149;
pub const WM_APP_VOICE_REPLAY: u32 = WM_APP + 142;
pub const WM_APP_LADDER_DONE: u32 = WM_APP + 180;
pub const WM_APP_ZSB_WORKSPACE: u32 = WM_APP + 153;
pub const WM_APP_ZSB_WHO: u32 = WM_APP + 151;
pub const WM_APP_BROWSER_DOCKED: u32 = WM_APP + 152;
pub const WM_APP_LAYOUT_READY: u32 = WM_APP + 150;
pub const WM_APP_FAVORITE_TOGGLE: u32 = WM_APP + 200;
pub const WM_APP_UPDATE_CHANGED: u32 = WM_APP + 201;
pub const WM_APP_CHAT_PERMISSION: u32 = WM_APP + 203;
pub const WM_APP_CHAT_TAB_URL: u32 = WM_APP + 205;
pub const WM_APP_BROWSER_DOCK_GUARD: u32 = WM_APP + 207;
pub const WM_APP_BROWSER_LIFECYCLE_DONE: u32 = WM_APP + 208;
pub const WM_COPYDATA: u32 = 0x004A;
pub const WM_ERASEBKGND: u32 = 0x0014;
pub const WM_TIMER: u32 = 0x0113;
pub const WM_MOUSEWHEEL: u32 = 0x020A;
pub const WM_MOUSEHWHEEL: u32 = 0x020E;
pub const WM_POWERBROADCAST: u32 = 0x0218;
pub const WM_TIMECHANGE: UINT = 0x001E;
pub const PBT_APMSUSPEND: WPARAM = 0x0004;
pub const PBT_APMRESUMESUSPEND: WPARAM = 0x0007;
pub const PBT_APMRESUMEAUTOMATIC: WPARAM = 0x0012;
pub const RESUME_RESPAWN_WINDOW_MS: u64 = 300_000;
const RESPAWN_COOLDOWN_MS: u64 = 2_000;
pub const TIMER_NAME_POLL: usize = 2;
pub const TIMER_REFOCUS: usize = 3;
pub const TIMER_HOOK_UNINSTALL: usize = 4;
pub const TIMER_SPINNER: usize = 5;
pub const TIMER_RESUME_RECONNECT: usize = 6;
pub const TIMER_FONT_HUD: usize = 7;
pub const TIMER_INBOX_REFRESH: usize = 8;
pub const TIMER_SYSMENU: usize = 9;
pub const TIMER_CAP_MSG: usize = 10;
pub const TIMER_BROWSER_ADOPT: usize = 11;
pub const TIMER_BROWSER_SETTLE: usize = 12;
pub const TIMER_BROWSER_URL_POLL: usize = 13;
pub const TIMER_BROWSER_EDGE_MASK_RAISE: usize = 14;
pub const TIMER_REMINDERS: usize = 15;
pub const TIMER_CONSOLE_GEOMETRY_SETTLE: usize = 16;
pub const TIMER_WEBVIEW2_FOCUS: usize = 17;
pub const TIMER_NATIVE_BROWSER_FOCUS: usize = 18;
pub const TIMER_BROWSER_HEALTH: usize = 19;
pub const TIMER_TUNNEL_KEEPER: usize = 20;
pub const TIMER_UNARCHIVE_UNATTACHED: usize = 21;
pub const TIMER_VPS_CAPACITY: usize = 22;
pub const TIMER_MONITOR_TRANSITION: usize = 23;
pub const TIMER_AI_PACE: usize = 24;
pub const TIMER_SYSTEM_THEME: usize = 25;
pub const TIMER_BROWSER_ENGINE_SWITCH: usize = 26;
pub const TIMER_CHAT_REFRESH: usize = 27;
pub const TIMER_CHAT_WORKING: usize = 43;
pub const TIMER_POWER_IDLE: usize = 28;
pub const TIMER_INBOX_PUBLISH: usize = 29;
pub const TIMER_VOICE_POLL: usize = 30;
pub const TIMER_VOICE_TURN_END: usize = 31;
pub const TIMER_CHAT_AC_DEBOUNCE: usize = 35;
pub const TIMER_CHAT_SEND_VERIFY: usize = 33;
pub const TIMER_CHAT_SEL_SCROLL: usize = 36;
pub const TIMER_ETA_REPAINT: usize = 32;
pub const TIMER_VOICE_TTS_POS: usize = 34;
pub const TIMER_SSH_RECONNECT: usize = 36;
pub const TIMER_CHAT_OUTBOX: usize = 37;
pub const TIMER_BROWSER_PLACEHOLDER: usize = 39;
pub const TIMER_CHAT_BROWSER_SWAP: usize = 41;
pub const TIMER_CHAT_DRAFT: usize = 40;
pub const TIMER_SHOT_FOCUS: usize = 42;
pub const TIMER_CHAT_FOREGROUND_RETRY: usize = 38;

pub const GUID_ACDC_POWER_SOURCE = GUID{ .Data1 = 0x5D3E9A59, .Data2 = 0xE9D5, .Data3 = 0x4B00, .Data4 = .{ 0xA6, 0xBD, 0xFF, 0x34, 0xFF, 0x51, 0x65, 0x48 } };
pub const GUID_POWER_SAVING_STATUS = GUID{ .Data1 = 0xE00958C0, .Data2 = 0xC213, .Data3 = 0x4ACE, .Data4 = .{ 0xAC, 0x77, 0xFE, 0xCC, 0xED, 0x2E, 0xEE, 0xA5 } };
pub const GUID_CONSOLE_DISPLAY_STATE = GUID{ .Data1 = 0x6FE69556, .Data2 = 0x704A, .Data3 = 0x47A0, .Data4 = .{ 0x8F, 0x24, 0xC2, 0x8D, 0x93, 0x6F, 0xDA, 0x47 } };
pub const DEVICE_NOTIFY_WINDOW_HANDLE: DWORD = 0;
pub const PBT_POWERSETTINGCHANGE: WPARAM = 0x8013;
pub extern "user32" fn RegisterPowerSettingNotification(hRecipient: HANDLE, PowerSettingGuid: *const GUID, Flags: DWORD) callconv(WINAPI) HANDLE;
pub extern "user32" fn UnregisterPowerSettingNotification(handle: HANDLE) callconv(WINAPI) BOOL;
pub extern "user32" fn SetCoalescableTimer(hWnd: HANDLE, nIDEvent: usize, uElapse: UINT, lpTimerFunc: ?*anyopaque, uToleranceDelay: DWORD) callconv(WINAPI) usize;

pub const POWERBROADCAST_SETTING = extern struct {
    PowerSetting: GUID,
    DataLength: DWORD,
    Data: [1]u8,
};

pub const SYSTEM_POWER_STATUS = extern struct {
    ACLineStatus: u8,
    BatteryFlag: u8,
    BatteryLifePercent: u8,
    SystemStatusFlag: u8,
    BatteryLifeTime: DWORD,
    BatteryFullLifeTime: DWORD,
};
pub extern "kernel32" fn GetSystemPowerStatus(lpSystemPowerStatus: *SYSTEM_POWER_STATUS) callconv(WINAPI) BOOL;

const WNDPROC = *const fn (HANDLE, UINT, WPARAM, LPARAM) callconv(WINAPI) LRESULT;
const HOOKPROC = *const fn (i32, WPARAM, LPARAM) callconv(WINAPI) LRESULT;
const WINEVENTPROC = *const fn (HANDLE, DWORD, HANDLE, LONG, LONG, DWORD, DWORD) callconv(WINAPI) void;

pub const WNDCLASSEXW = extern struct {
    cbSize: UINT,
    style: UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32,
    cbWndExtra: i32,
    hInstance: HANDLE,
    hIcon: HANDLE,
    hCursor: HANDLE,
    hbrBackground: HANDLE,
    lpszMenuName: ?LPCWSTR,
    lpszClassName: LPCWSTR,
    hIconSm: HANDLE,
};

pub const POINT = extern struct { x: LONG, y: LONG };
pub const SIZE = extern struct { cx: LONG, cy: LONG };
pub const TRACKMOUSEEVENT = extern struct { cbSize: DWORD, dwFlags: DWORD, hwndTrack: HANDLE, dwHoverTime: DWORD };
pub const MSG = extern struct {
    hwnd: HANDLE,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
};
pub const RECT = extern struct { left: LONG, top: LONG, right: LONG, bottom: LONG };
pub const WINDOWPOS = extern struct { hwnd: HANDLE, hwndInsertAfter: HANDLE, x: i32, y: i32, cx: i32, cy: i32, flags: UINT };
pub const SYSTEMTIME = extern struct {
    year: WORD,
    month: WORD,
    day_of_week: WORD,
    day: WORD,
    hour: WORD,
    minute: WORD,
    second: WORD,
    milliseconds: WORD,
};

pub const PAINTSTRUCT = extern struct {
    hdc: HANDLE,
    fErase: BOOL,
    rcPaint: RECT,
    fRestore: BOOL,
    fIncUpdate: BOOL,
    rgbReserved: [32]u8,
};

pub const KBDLLHOOKSTRUCT = extern struct {
    vkCode: DWORD,
    scanCode: DWORD,
    flags: DWORD,
    time: DWORD,
    dwExtraInfo: usize,
};

pub const MSLLHOOKSTRUCT = extern struct {
    pt: POINT,
    mouseData: DWORD,
    flags: DWORD,
    time: DWORD,
    dwExtraInfo: usize,
};

pub const PROCESS_BASIC_INFORMATION = extern struct {
    reserved1: ?*anyopaque,
    peb_base_address: ?*anyopaque,
    reserved2: [2]?*anyopaque,
    unique_process_id: usize,
    reserved3: ?*anyopaque,
};

pub const UNICODE_STRING = extern struct {
    length: u16,
    maximum_length: u16,
    buffer: ?*anyopaque,
};

pub const RTL_CURDIR_DOS_PATH_OFFSET: usize = 0x38;
pub const PEB_PROCESS_PARAMS_OFFSET: usize = 0x20;

pub const STARTUPINFOW = extern struct {
    cb: DWORD,
    lpReserved: ?[*:0]u16,
    lpDesktop: ?[*:0]u16,
    lpTitle: ?LPCWSTR,
    dwX: DWORD,
    dwY: DWORD,
    dwXSize: DWORD,
    dwYSize: DWORD,
    dwXCountChars: DWORD,
    dwYCountChars: DWORD,
    dwFillAttribute: DWORD,
    dwFlags: DWORD,
    wShowWindow: WORD,
    cbReserved2: WORD,
    lpReserved2: ?[*]u8,
    hStdInput: HANDLE,
    hStdOutput: HANDLE,
    hStdError: HANDLE,
};

pub const PROCESS_INFORMATION = extern struct {
    hProcess: HANDLE,
    hThread: HANDLE,
    dwProcessId: DWORD,
    dwThreadId: DWORD,
};

pub const FILETIME = extern struct {
    dwLowDateTime: DWORD,
    dwHighDateTime: DWORD,
};

pub const WIN32_FIND_DATAW = extern struct {
    dwFileAttributes: DWORD,
    ftCreationTime: FILETIME,
    ftLastAccessTime: FILETIME,
    ftLastWriteTime: FILETIME,
    nFileSizeHigh: DWORD,
    nFileSizeLow: DWORD,
    dwReserved0: DWORD,
    dwReserved1: DWORD,
    cFileName: [260]u16,
    cAlternateFileName: [14]u16,
    dwFileType: DWORD,
    dwCreatorType: DWORD,
    wFinderFlags: WORD,
};

pub extern "user32" fn RegisterClassExW(*const WNDCLASSEXW) callconv(WINAPI) ATOM;
pub extern "user32" fn CreateWindowExW(DWORD, ?LPCWSTR, ?LPCWSTR, DWORD, i32, i32, i32, i32, HANDLE, HANDLE, HANDLE, ?*anyopaque) callconv(WINAPI) HANDLE;
pub extern "user32" fn IsHungAppWindow(HANDLE) callconv(WINAPI) BOOL;
pub extern "user32" fn IsZoomed(HANDLE) callconv(WINAPI) BOOL;
pub extern "user32" fn IsIconic(HANDLE) callconv(WINAPI) BOOL;
pub extern "user32" fn IsChild(HANDLE, HANDLE) callconv(WINAPI) BOOL;
pub extern "user32" fn GetFocus() callconv(WINAPI) HANDLE;
pub extern "user32" fn GetSystemMenu(HANDLE, BOOL) callconv(WINAPI) HANDLE;
pub extern "user32" fn GetWindowRect(HANDLE, *RECT) callconv(WINAPI) BOOL;
pub extern "user32" fn MonitorFromWindow(HANDLE, DWORD) callconv(WINAPI) HANDLE;
pub extern "user32" fn MonitorFromRect(*const RECT, DWORD) callconv(WINAPI) HANDLE;
pub extern "user32" fn MonitorFromPoint(POINT, DWORD) callconv(WINAPI) HANDLE;
pub extern "user32" fn GetMonitorInfoW(HANDLE, *MONITORINFO) callconv(WINAPI) BOOL;
pub extern "user32" fn GetDpiForWindow(HANDLE) callconv(WINAPI) u32;
pub const MONITORINFO = extern struct {
    cbSize: DWORD,
    rcMonitor: RECT,
    rcWork: RECT,
    dwFlags: DWORD,
};
pub const MONITOR_DEFAULTTOPRIMARY: DWORD = 1;
pub const MONITOR_DEFAULTTONEAREST: DWORD = 2;
pub extern "user32" fn SetProcessDpiAwarenessContext(?*anyopaque) callconv(WINAPI) BOOL;
pub extern "user32" fn EnumDisplayMonitors(HANDLE, ?*const RECT, *const fn (HANDLE, HANDLE, ?*RECT, LPARAM) callconv(WINAPI) BOOL, LPARAM) callconv(WINAPI) BOOL;
pub extern "user32" fn DisableProcessWindowsGhosting() callconv(WINAPI) void;
pub const LASTINPUTINFO = extern struct { cbSize: UINT, dwTime: DWORD };
pub extern "user32" fn GetLastInputInfo(plii: *LASTINPUTINFO) callconv(WINAPI) BOOL;
pub const HKEY_CURRENT_USER: HKEY = @ptrFromInt(0x80000001);
pub const KEY_SET_VALUE: DWORD = 0x0002;
pub const REG_OPTION_NON_VOLATILE: DWORD = 0;
pub const REG_SZ: DWORD = 1;
pub const ERROR_SUCCESS: LONG = 0;
pub extern "advapi32" fn RegCreateKeyExA(HKEY, [*:0]const u8, DWORD, ?[*:0]u8, DWORD, DWORD, ?*anyopaque, *HKEY, ?*DWORD) callconv(WINAPI) LONG;
pub extern "advapi32" fn RegSetValueExA(HKEY, ?[*:0]const u8, DWORD, DWORD, [*]const u8, DWORD) callconv(WINAPI) LONG;
pub const WM_SYSCOMMAND: u32 = 0x0112;
pub const SC_MAXIMIZE: usize = 0xF030;
const SC_KEYMENU: usize = 0xF100;
pub const SW_MAXIMIZE: i32 = 3;
pub const SW_MINIMIZE: i32 = 6;
pub extern "user32" fn IsWindow(HANDLE) callconv(WINAPI) BOOL;
pub extern "user32" fn IsWindowVisible(HANDLE) callconv(WINAPI) BOOL;
pub extern "user32" fn GetWindow(HANDLE, UINT) callconv(WINAPI) HANDLE;
pub extern "user32" fn GetLastActivePopup(HANDLE) callconv(WINAPI) HANDLE;
pub extern "user32" fn GetMessageW(*MSG, HANDLE, UINT, UINT) callconv(WINAPI) BOOL;
pub extern "user32" fn GetMessageTime() callconv(WINAPI) LONG;
pub extern "user32" fn TranslateMessage(*const MSG) callconv(WINAPI) BOOL;
pub extern "user32" fn DispatchMessageW(*const MSG) callconv(WINAPI) LRESULT;
pub extern "user32" fn DefWindowProcW(HANDLE, UINT, WPARAM, LPARAM) callconv(WINAPI) LRESULT;
pub extern "user32" fn PostQuitMessage(i32) callconv(WINAPI) void;
pub extern "user32" fn SetPropW(hWnd: HANDLE, lpString: [*:0]const u16, hData: HANDLE) callconv(WINAPI) BOOL;
pub extern "user32" fn GetPropW(hWnd: HANDLE, lpString: [*:0]const u16) callconv(WINAPI) HANDLE;
pub extern "user32" fn GetClientRect(HANDLE, *RECT) callconv(WINAPI) BOOL;
pub extern "user32" fn MoveWindow(HANDLE, i32, i32, i32, i32, BOOL) callconv(WINAPI) BOOL;
pub extern "user32" fn BeginDeferWindowPos(i32) callconv(WINAPI) HANDLE;
pub extern "user32" fn DeferWindowPos(HANDLE, HANDLE, HANDLE, i32, i32, i32, i32, UINT) callconv(WINAPI) HANDLE;
pub extern "user32" fn EndDeferWindowPos(HANDLE) callconv(WINAPI) BOOL;
pub extern "user32" fn SetParent(HANDLE, HANDLE) callconv(WINAPI) HANDLE;
pub extern "user32" fn SetWindowLongPtrW(HANDLE, i32, LONG_PTR) callconv(WINAPI) LONG_PTR;
pub extern "user32" fn GetWindowLongPtrW(HANDLE, i32) callconv(WINAPI) LONG_PTR;
pub const BLENDFUNCTION = extern struct { blend_op: u8 = 0, blend_flags: u8 = 0, source_constant_alpha: u8 = 255, alpha_format: u8 = 1 };
pub const ULW_ALPHA: DWORD = 2;
pub extern "user32" fn UpdateLayeredWindow(HANDLE, HANDLE, ?*const POINT, ?*const SIZE, HANDLE, ?*const POINT, DWORD, ?*const BLENDFUNCTION, DWORD) callconv(WINAPI) BOOL;
pub extern "user32" fn SetLayeredWindowAttributes(HANDLE, DWORD, u8, DWORD) callconv(WINAPI) BOOL;
pub extern "user32" fn FindWindowW(?LPCWSTR, ?LPCWSTR) callconv(WINAPI) HANDLE;
pub extern "user32" fn LoadCursorW(HANDLE, ?*const anyopaque) callconv(WINAPI) HANDLE;
pub extern "user32" fn LoadIconW(HANDLE, ?*anyopaque) callconv(WINAPI) HANDLE;
pub extern "user32" fn LoadImageW(HANDLE, ?*anyopaque, UINT, i32, i32, UINT) callconv(WINAPI) HANDLE;
pub const IMAGE_ICON: UINT = 1;
pub const LR_DEFAULTCOLOR: UINT = 0;
pub extern "user32" fn InvalidateRect(HANDLE, ?*const RECT, BOOL) callconv(WINAPI) BOOL;
pub extern "user32" fn BeginPaint(HANDLE, *PAINTSTRUCT) callconv(WINAPI) HANDLE;
pub extern "user32" fn EndPaint(HANDLE, *const PAINTSTRUCT) callconv(WINAPI) BOOL;
pub extern "user32" fn GetDC(HANDLE) callconv(WINAPI) HANDLE;
pub extern "user32" fn GetWindowDC(HANDLE) callconv(WINAPI) HANDLE;
pub extern "user32" fn ReleaseDC(HANDLE, HANDLE) callconv(WINAPI) i32;
pub extern "user32" fn ShowScrollBar(HANDLE, i32, BOOL) callconv(WINAPI) BOOL;
pub const SB_VERT: i32 = 1;
pub const EM_SCROLLCARET: UINT = 0x00B7;
pub extern "user32" fn FillRect(HANDLE, *const RECT, HANDLE) callconv(WINAPI) i32;
pub extern "user32" fn DrawTextW(HANDLE, [*]const u16, i32, *RECT, UINT) callconv(WINAPI) i32;
extern "user32" fn MessageBeep(UINT) callconv(WINAPI) BOOL;
pub extern "user32" fn SetCapture(HANDLE) callconv(WINAPI) HANDLE;
pub extern "user32" fn ReleaseCapture() callconv(WINAPI) BOOL;
pub extern "user32" fn DestroyWindow(HANDLE) callconv(WINAPI) BOOL;
pub extern "user32" fn GetWindowTextW(HANDLE, [*]u16, i32) callconv(WINAPI) i32;
pub extern "user32" fn InternalGetWindowText(HANDLE, [*]u16, i32) callconv(WINAPI) i32;
pub extern "user32" fn GetWindowTextLengthW(HANDLE) callconv(WINAPI) i32;
pub extern "user32" fn SetWindowTextW(HANDLE, LPCWSTR) callconv(WINAPI) BOOL;
pub extern "user32" fn GetForegroundWindow() callconv(WINAPI) HANDLE;
pub extern "user32" fn GetAsyncKeyState(i32) callconv(WINAPI) i16;
pub extern "user32" fn mouse_event(DWORD, DWORD, DWORD, DWORD, usize) callconv(WINAPI) void;
pub extern "user32" fn SetWindowsHookExW(i32, HOOKPROC, HANDLE, DWORD) callconv(WINAPI) HANDLE;
pub extern "user32" fn CallNextHookEx(HANDLE, i32, WPARAM, LPARAM) callconv(WINAPI) LRESULT;
pub extern "user32" fn UnhookWindowsHookEx(HANDLE) callconv(WINAPI) BOOL;
pub extern "user32" fn SetWinEventHook(DWORD, DWORD, HANDLE, WINEVENTPROC, DWORD, DWORD, UINT) callconv(WINAPI) HANDLE;
pub extern "user32" fn UnhookWinEvent(HANDLE) callconv(WINAPI) BOOL;
pub extern "user32" fn RegisterHotKey(HANDLE, i32, UINT, UINT) callconv(WINAPI) BOOL;
pub extern "user32" fn UnregisterHotKey(HANDLE, i32) callconv(WINAPI) BOOL;
pub extern "user32" fn SetCursor(HANDLE) callconv(WINAPI) HANDLE;
pub const WM_SETCURSOR: u32 = 0x0020;
pub const HTCLIENT: WPARAM = 1;
pub extern "user32" fn DrawIconEx(HANDLE, i32, i32, HANDLE, i32, i32, UINT, HANDLE, UINT) callconv(WINAPI) BOOL;
pub extern "user32" fn DestroyIcon(HANDLE) callconv(WINAPI) BOOL;
pub extern "shell32" fn ExtractIconExW(LPCWSTR, i32, ?*HANDLE, ?*HANDLE, UINT) callconv(WINAPI) UINT;
pub extern "shell32" fn SetCurrentProcessExplicitAppUserModelID([*:0]const u16) callconv(WINAPI) LONG;
pub extern "shell32" fn SHGetPropertyStoreForWindow(HANDLE, *const GUID, *?*anyopaque) callconv(WINAPI) LONG;
pub extern "shell32" fn SHGetPropertyStoreFromParsingName(LPCWSTR, ?*anyopaque, DWORD, *const GUID, *?*anyopaque) callconv(WINAPI) LONG;
pub extern "shell32" fn SHChangeNotify(LONG, UINT, ?*const anyopaque, ?*const anyopaque) callconv(WINAPI) void;
pub extern "gdi32" fn CreateSolidBrush(DWORD) callconv(WINAPI) HANDLE;
pub extern "gdi32" fn DeleteObject(HANDLE) callconv(WINAPI) BOOL;
pub extern "gdi32" fn SetBkMode(HANDLE, i32) callconv(WINAPI) i32;
pub extern "gdi32" fn SetBkColor(HANDLE, DWORD) callconv(WINAPI) DWORD;
pub extern "gdi32" fn SetTextColor(HANDLE, DWORD) callconv(WINAPI) DWORD;
pub extern "gdi32" fn GetTextColor(HANDLE) callconv(WINAPI) DWORD;
pub extern "gdi32" fn SetTextCharacterExtra(HANDLE, i32) callconv(WINAPI) i32;
pub extern "gdi32" fn SelectObject(HANDLE, HANDLE) callconv(WINAPI) HANDLE;
pub extern "gdi32" fn GetStockObject(i32) callconv(WINAPI) HANDLE;
pub extern "gdi32" fn GetTextExtentPoint32W(HANDLE, [*]const u16, i32, *SIZE) callconv(WINAPI) BOOL;
pub extern "gdi32" fn GetTextFaceW(HANDLE, i32, [*]u16) callconv(WINAPI) i32;
pub extern "gdi32" fn GetTextExtentExPointW(HANDLE, [*]const u16, i32, i32, *i32, ?[*]i32, *SIZE) callconv(WINAPI) BOOL;
pub extern "gdi32" fn CreateFontW(i32, i32, i32, i32, i32, DWORD, DWORD, DWORD, DWORD, DWORD, DWORD, DWORD, DWORD, ?LPCWSTR) callconv(WINAPI) HANDLE;
pub extern "gdi32" fn AddFontResourceExW(LPCWSTR, DWORD, ?*anyopaque) callconv(WINAPI) i32;
pub extern "gdi32" fn RemoveFontResourceExW(LPCWSTR, DWORD, ?*anyopaque) callconv(WINAPI) BOOL;
pub extern "gdi32" fn RemoveFontMemResourceEx(HANDLE) callconv(WINAPI) BOOL;
pub extern "gdi32" fn AddFontMemResourceEx(?*const anyopaque, DWORD, ?*anyopaque, *DWORD) callconv(WINAPI) HANDLE;
pub const LOGBRUSH = extern struct { style: u32, color: DWORD, hatch: usize };
pub const LOGPEN = extern struct { style: u32, width: POINT, color: DWORD };
pub extern "gdi32" fn GetCurrentObject(HANDLE, u32) callconv(WINAPI) HANDLE;
pub extern "gdi32" fn GetObjectW(HANDLE, i32, ?*anyopaque) callconv(WINAPI) i32;
pub extern "gdi32" fn GetClipRgn(HANDLE, HANDLE) callconv(WINAPI) i32;
pub const BITMAPINFOHEADER = extern struct {
    size: u32 = @sizeOf(BITMAPINFOHEADER),
    width: i32,
    height: i32,
    planes: u16 = 1,
    bit_count: u16 = 32,
    compression: u32 = 0,
    size_image: u32 = 0,
    x_pels_per_meter: i32 = 0,
    y_pels_per_meter: i32 = 0,
    clr_used: u32 = 0,
    clr_important: u32 = 0,
};
pub const BITMAPINFO = extern struct { header: BITMAPINFOHEADER, colors: [1]u32 = .{0} };
pub extern "gdi32" fn CreateDIBSection(HANDLE, *const BITMAPINFO, u32, *?*anyopaque, HANDLE, u32) callconv(WINAPI) HANDLE;
pub extern "gdi32" fn GetPixel(HANDLE, i32, i32) callconv(WINAPI) DWORD;
pub extern "gdi32" fn Pie(HANDLE, i32, i32, i32, i32, i32, i32, i32, i32) callconv(WINAPI) BOOL;
pub extern "gdi32" fn Polygon(HANDLE, [*]const POINT, i32) callconv(WINAPI) BOOL;
pub extern "gdi32" fn Ellipse(HANDLE, i32, i32, i32, i32) callconv(WINAPI) BOOL;
pub extern "gdi32" fn RoundRect(HANDLE, i32, i32, i32, i32, i32, i32) callconv(WINAPI) BOOL;
pub extern "gdi32" fn CreateRoundRectRgn(i32, i32, i32, i32, i32, i32) callconv(WINAPI) HANDLE;
pub extern "gdi32" fn CreateRectRgn(i32, i32, i32, i32) callconv(WINAPI) HANDLE;
pub extern "user32" fn SetWindowRgn(HANDLE, HANDLE, BOOL) callconv(WINAPI) i32;
pub extern "gdi32" fn CreatePen(i32, i32, DWORD) callconv(WINAPI) HANDLE;
pub extern "gdi32" fn MoveToEx(HANDLE, i32, i32, ?*POINT) callconv(WINAPI) BOOL;
pub extern "gdi32" fn LineTo(HANDLE, i32, i32) callconv(WINAPI) BOOL;
pub extern "gdi32" fn CreateCompatibleDC(HANDLE) callconv(WINAPI) HANDLE;
pub extern "gdi32" fn CreateCompatibleBitmap(HANDLE, i32, i32) callconv(WINAPI) HANDLE;
pub extern "gdi32" fn BitBlt(HANDLE, i32, i32, i32, i32, HANDLE, i32, i32, DWORD) callconv(WINAPI) BOOL;
pub extern "gdi32" fn IntersectClipRect(HANDLE, i32, i32, i32, i32) callconv(WINAPI) i32;
extern "gdi32" fn SetViewportOrgEx(HANDLE, i32, i32, ?*POINT) callconv(WINAPI) BOOL;
pub extern "gdi32" fn DeleteDC(HANDLE) callconv(WINAPI) BOOL;
pub extern "gdi32" fn SaveDC(HANDLE) callconv(WINAPI) i32;
pub extern "gdi32" fn RestoreDC(HANDLE, i32) callconv(WINAPI) BOOL;
pub const GDI_SRCCOPY: DWORD = 0x00CC0020;
pub extern "kernel32" fn CreateProcessW(?LPCWSTR, ?[*:0]u16, ?*anyopaque, ?*anyopaque, BOOL, DWORD, ?*anyopaque, ?LPCWSTR, *STARTUPINFOW, *PROCESS_INFORMATION) callconv(WINAPI) BOOL;
pub extern "kernel32" fn Sleep(DWORD) callconv(WINAPI) void;
pub extern "kernel32" fn GetModuleHandleW(?LPCWSTR) callconv(WINAPI) HANDLE;
pub extern "kernel32" fn GetModuleFileNameW(HANDLE, [*]u16, DWORD) callconv(WINAPI) DWORD;
pub extern "kernel32" fn CloseHandle(HANDLE) callconv(WINAPI) BOOL;
pub extern "kernel32" fn GetFileAttributesW(LPCWSTR) callconv(WINAPI) DWORD;
pub extern "kernel32" fn SetErrorMode(DWORD) callconv(WINAPI) DWORD;
pub extern "kernel32" fn SearchPathW(?LPCWSTR, LPCWSTR, ?LPCWSTR, DWORD, [*]u16, ?*?[*]u16) callconv(WINAPI) DWORD;
pub extern "kernel32" fn GetLastError() callconv(WINAPI) DWORD;
pub extern "kernel32" fn ExitProcess(UINT) callconv(WINAPI) noreturn;
pub extern "kernel32" fn QueryFullProcessImageNameW(HANDLE, DWORD, [*]u16, *DWORD) callconv(WINAPI) BOOL;
pub extern "kernel32" fn TerminateProcess(HANDLE, UINT) callconv(WINAPI) BOOL;
pub extern "dwmapi" fn DwmSetWindowAttribute(HANDLE, DWORD, *const anyopaque, DWORD) callconv(WINAPI) i32;
pub extern "dwmapi" fn DwmGetWindowAttribute(HANDLE, DWORD, *anyopaque, DWORD) callconv(WINAPI) i32;
pub extern "advapi32" fn RegOpenCurrentUser(DWORD, *HANDLE) callconv(WINAPI) LONG;
pub extern "advapi32" fn RegGetValueW(HANDLE, ?LPCWSTR, ?LPCWSTR, DWORD, ?*DWORD, ?*anyopaque, *DWORD) callconv(WINAPI) LONG;
pub extern "advapi32" fn RegCreateKeyExW(HANDLE, LPCWSTR, DWORD, ?LPCWSTR, DWORD, DWORD, ?*anyopaque, *HANDLE, ?*DWORD) callconv(WINAPI) LONG;
pub extern "advapi32" fn RegSetValueExW(HANDLE, ?LPCWSTR, DWORD, DWORD, ?*const anyopaque, DWORD) callconv(WINAPI) LONG;
pub extern "advapi32" fn RegCloseKey(HANDLE) callconv(WINAPI) LONG;
pub extern "user32" fn GetWindowThreadProcessId(HANDLE, ?*DWORD) callconv(WINAPI) DWORD;
pub extern "kernel32" fn GetCurrentThreadId() callconv(WINAPI) DWORD;
pub extern "kernel32" fn GetEnvironmentVariableA([*:0]const u8, ?[*]u8, DWORD) callconv(WINAPI) DWORD;
pub extern "kernel32" fn SetEnvironmentVariableW(name: [*:0]const u16, value: ?[*:0]const u16) callconv(WINAPI) BOOL;
pub extern "kernel32" fn GetEnvironmentVariableW(name: [*:0]const u16, buf: [*]u16, buf_len: DWORD) callconv(WINAPI) DWORD;
pub extern "kernel32" fn GetCommandLineA() callconv(WINAPI) [*:0]const u8;
pub extern "kernel32" fn GetSystemDirectoryW([*]u16, UINT) callconv(WINAPI) UINT;
pub extern "kernel32" fn GetCurrentProcess() callconv(WINAPI) HANDLE;
pub extern "advapi32" fn OpenProcessToken(HANDLE, DWORD, *HANDLE) callconv(WINAPI) BOOL;
pub extern "advapi32" fn GetTokenInformation(HANDLE, DWORD, ?*anyopaque, DWORD, *DWORD) callconv(WINAPI) BOOL;
pub extern "advapi32" fn EqualSid(*const anyopaque, *const anyopaque) callconv(WINAPI) BOOL;
pub const TOKEN_USER = extern struct { sid: ?*const anyopaque, attributes: DWORD };
pub extern "kernel32" fn GetCurrentProcessId() callconv(WINAPI) DWORD;
pub extern "kernel32" fn OpenProcess(DWORD, BOOL, DWORD) callconv(WINAPI) HANDLE;
pub extern "kernel32" fn ReadProcessMemory(HANDLE, *const anyopaque, *anyopaque, usize, ?*usize) callconv(WINAPI) BOOL;
pub extern "kernel32" fn LoadLibraryA([*:0]const u8) callconv(WINAPI) HANDLE;
pub extern "kernel32" fn GetProcAddress(HANDLE, [*:0]const u8) callconv(WINAPI) ?*anyopaque;
pub extern "kernel32" fn AttachConsole(DWORD) callconv(WINAPI) BOOL;
pub extern "kernel32" fn FreeConsole() callconv(WINAPI) BOOL;
pub extern "kernel32" fn GetStdHandle(DWORD) callconv(WINAPI) HANDLE;
pub extern "kernel32" fn GetConsoleScreenBufferInfo(HANDLE, *CONSOLE_SCREEN_BUFFER_INFO) callconv(WINAPI) BOOL;
pub extern "kernel32" fn GetConsoleScreenBufferInfoEx(HANDLE, *CONSOLE_SCREEN_BUFFER_INFOEX) callconv(WINAPI) BOOL;
pub extern "kernel32" fn SetConsoleScreenBufferInfoEx(HANDLE, *CONSOLE_SCREEN_BUFFER_INFOEX) callconv(WINAPI) BOOL;
pub extern "kernel32" fn GetCurrentConsoleFontEx(HANDLE, BOOL, *CONSOLE_FONT_INFOEX) callconv(WINAPI) BOOL;
pub extern "kernel32" fn SetCurrentConsoleFontEx(HANDLE, BOOL, *CONSOLE_FONT_INFOEX) callconv(WINAPI) BOOL;
pub extern "kernel32" fn FillConsoleOutputAttribute(HANDLE, WORD, DWORD, COORD, *DWORD) callconv(WINAPI) BOOL;
pub extern "kernel32" fn WriteConsoleInputW(HANDLE, [*]const INPUT_RECORD, DWORD, *DWORD) callconv(WINAPI) BOOL;
pub extern "kernel32" fn GlobalLock(HANDLE) callconv(WINAPI) ?*anyopaque;
pub extern "kernel32" fn GlobalSize(HANDLE) callconv(WINAPI) usize;
pub extern "kernel32" fn GlobalUnlock(HANDLE) callconv(WINAPI) BOOL;
pub extern "kernel32" fn GlobalFree(HANDLE) callconv(WINAPI) HANDLE;
pub extern "user32" fn OpenClipboard(HANDLE) callconv(WINAPI) BOOL;
pub extern "user32" fn CloseClipboard() callconv(WINAPI) BOOL;
pub extern "user32" fn GetClipboardData(UINT) callconv(WINAPI) HANDLE;
pub extern "user32" fn EmptyClipboard() callconv(WINAPI) BOOL;
pub extern "user32" fn SetClipboardData(UINT, HANDLE) callconv(WINAPI) HANDLE;
pub extern "user32" fn IsClipboardFormatAvailable(UINT) callconv(WINAPI) BOOL;
pub extern "kernel32" fn GlobalAlloc(UINT, usize) callconv(WINAPI) HANDLE;
pub extern "kernel32" fn MultiByteToWideChar(UINT, DWORD, [*]const u8, i32, ?[*]u16, i32) callconv(WINAPI) i32;
pub extern "kernel32" fn WideCharToMultiByte(UINT, DWORD, [*]const u16, i32, ?[*]u8, i32, ?[*]const u8, ?*BOOL) callconv(WINAPI) i32;
pub extern "kernel32" fn GetConsoleSelectionInfo(*CONSOLE_SELECTION_INFO) callconv(WINAPI) BOOL;
pub extern "kernel32" fn FindFirstFileW(LPCWSTR, *WIN32_FIND_DATAW) callconv(WINAPI) HANDLE;
pub extern "kernel32" fn FindNextFileW(HANDLE, *WIN32_FIND_DATAW) callconv(WINAPI) BOOL;
pub extern "kernel32" fn FindClose(HANDLE) callconv(WINAPI) BOOL;
pub extern "kernel32" fn DeleteFileW(LPCWSTR) callconv(WINAPI) BOOL;
pub extern "kernel32" fn CreateEventW(?*anyopaque, BOOL, BOOL, ?LPCWSTR) callconv(WINAPI) HANDLE;

pub const CF_TEXT: UINT = 1;
pub const CF_OEMTEXT: UINT = 7;
pub const CF_UNICODETEXT: UINT = 13;
pub const CP_ACP: UINT = 0;
pub const CP_OEMCP: UINT = 1;
pub const CP_UTF8: UINT = 65001;
pub const GMEM_MOVEABLE: UINT = 0x0002;
pub const FILE_ATTRIBUTE_DIRECTORY: DWORD = 0x00000010;
pub const CONSOLE_SELECTION_NOT_EMPTY: DWORD = 0x0002;

const HINTERNET = HANDLE;
pub const INTERNET_DEFAULT_HTTPS_PORT: WORD = 443;
pub const WINHTTP_ACCESS_TYPE_DEFAULT_PROXY: DWORD = 0;
const WINHTTP_ACCESS_TYPE_NO_PROXY: DWORD = 1;
pub const WINHTTP_FLAG_SECURE: DWORD = 0x00800000;
pub const WINHTTP_ADDREQ_FLAG_ADD: DWORD = 0x20000000;
pub const WINHTTP_QUERY_STATUS_CODE: DWORD = 19;
pub const WINHTTP_QUERY_FLAG_NUMBER: DWORD = 0x20000000;
pub extern "winhttp" fn WinHttpOpen([*:0]const u16, DWORD, ?LPCWSTR, ?LPCWSTR, DWORD) callconv(WINAPI) HINTERNET;
pub extern "winhttp" fn WinHttpConnect(HINTERNET, [*:0]const u16, WORD, DWORD) callconv(WINAPI) HINTERNET;
pub extern "winhttp" fn WinHttpOpenRequest(HINTERNET, [*:0]const u16, [*:0]const u16, ?LPCWSTR, ?LPCWSTR, ?*const LPCWSTR, DWORD) callconv(WINAPI) HINTERNET;
pub extern "winhttp" fn WinHttpAddRequestHeaders(HINTERNET, [*:0]const u16, DWORD, DWORD) callconv(WINAPI) BOOL;
pub extern "winhttp" fn WinHttpSendRequest(HINTERNET, ?[*]const u16, DWORD, ?*anyopaque, DWORD, DWORD, usize) callconv(WINAPI) BOOL;
pub extern "winhttp" fn WinHttpReceiveResponse(HINTERNET, ?*anyopaque) callconv(WINAPI) BOOL;
pub extern "winhttp" fn WinHttpQueryHeaders(HINTERNET, DWORD, ?LPCWSTR, ?*anyopaque, *DWORD, ?*DWORD) callconv(WINAPI) BOOL;
pub extern "winhttp" fn WinHttpQueryDataAvailable(HINTERNET, *DWORD) callconv(WINAPI) BOOL;
pub extern "winhttp" fn WinHttpReadData(HINTERNET, ?*anyopaque, DWORD, *DWORD) callconv(WINAPI) BOOL;
pub extern "winhttp" fn WinHttpSetTimeouts(HINTERNET, i32, i32, i32, i32) callconv(WINAPI) BOOL;
pub extern "winhttp" fn WinHttpCloseHandle(HINTERNET) callconv(WINAPI) BOOL;

const MMRESULT = UINT;
pub const HWAVEIN = HANDLE;
pub const WAVE_MAPPER: UINT = 0xFFFFFFFF;
pub const WAVE_FORMAT_PCM: WORD = 1;
pub const CALLBACK_EVENT: DWORD = 0x00050000;
pub const WHDR_DONE: DWORD = 0x00000001;
pub const WAVEFORMATEX = extern struct {
    wFormatTag: WORD,
    nChannels: WORD,
    nSamplesPerSec: DWORD,
    nAvgBytesPerSec: DWORD,
    nBlockAlign: WORD,
    wBitsPerSample: WORD,
    cbSize: WORD,
};
pub const WAVEHDR = extern struct {
    lpData: ?[*]u8,
    dwBufferLength: DWORD,
    dwBytesRecorded: DWORD,
    dwUser: usize,
    dwFlags: DWORD,
    dwLoops: DWORD,
    lpNext: ?*WAVEHDR,
    reserved: usize,
};
pub extern "winmm" fn waveInOpen(*HWAVEIN, UINT, *const WAVEFORMATEX, usize, usize, DWORD) callconv(WINAPI) MMRESULT;
pub extern "winmm" fn waveInPrepareHeader(HWAVEIN, *WAVEHDR, UINT) callconv(WINAPI) MMRESULT;
pub extern "winmm" fn waveInUnprepareHeader(HWAVEIN, *WAVEHDR, UINT) callconv(WINAPI) MMRESULT;
pub extern "winmm" fn waveInAddBuffer(HWAVEIN, *WAVEHDR, UINT) callconv(WINAPI) MMRESULT;
pub extern "winmm" fn waveInStart(HWAVEIN) callconv(WINAPI) MMRESULT;
pub extern "winmm" fn waveInStop(HWAVEIN) callconv(WINAPI) MMRESULT;
pub extern "winmm" fn waveInReset(HWAVEIN) callconv(WINAPI) MMRESULT;
pub extern "winmm" fn waveInClose(HWAVEIN) callconv(WINAPI) MMRESULT;

pub const HWAVEOUT = HANDLE;
pub extern "winmm" fn waveOutOpen(*HWAVEOUT, UINT, *const WAVEFORMATEX, usize, usize, DWORD) callconv(WINAPI) MMRESULT;
pub extern "winmm" fn waveOutPrepareHeader(HWAVEOUT, *WAVEHDR, UINT) callconv(WINAPI) MMRESULT;
pub extern "winmm" fn waveOutUnprepareHeader(HWAVEOUT, *WAVEHDR, UINT) callconv(WINAPI) MMRESULT;
pub extern "winmm" fn waveOutWrite(HWAVEOUT, *WAVEHDR, UINT) callconv(WINAPI) MMRESULT;
pub extern "winmm" fn waveOutReset(HWAVEOUT) callconv(WINAPI) MMRESULT;
pub extern "winmm" fn waveOutClose(HWAVEOUT) callconv(WINAPI) MMRESULT;
pub const TIME_BYTES: UINT = 0x0004;
pub const MMTIME = extern struct {
    wType: UINT,
    u: extern union {
        ms: DWORD,
        sample: DWORD,
        cb: DWORD,
        ticks: DWORD,
        smpte: extern struct { hour: u8, min: u8, sec: u8, frame: u8, fps: u8, dummy: u8, pad: [2]u8 },
        midi: extern struct { songptrpos: DWORD },
    },
};
comptime {
    std.debug.assert(@sizeOf(MMTIME) == 12);
}
pub extern "winmm" fn waveOutGetPosition(HWAVEOUT, *MMTIME, UINT) callconv(WINAPI) MMRESULT;

pub const CONSOLE_SELECTION_INFO = extern struct {
    dwFlags: DWORD,
    dwSelectionAnchor: COORD,
    srSelection: extern struct { Left: i16, Top: i16, Right: i16, Bottom: i16 },
};
const STD_INPUT_HANDLE: DWORD = @bitCast(@as(i32, -10));
pub const KEY_EVENT: u16 = 0x0001;
pub const VK_PACKET_U16: u16 = 0x00E7;

const KEY_EVENT_RECORD = extern struct {
    bKeyDown: BOOL,
    wRepeatCount: u16,
    wVirtualKeyCode: u16,
    wVirtualScanCode: u16,
    UnicodeChar: u16,
    dwControlKeyState: DWORD,
};

pub const INPUT_RECORD = extern struct {
    EventType: u16,
    _pad: u16 = 0,
    Event: extern union {
        KeyEvent: KEY_EVENT_RECORD,
        _pad: [16]u8,
    },
};
pub extern "kernel32" fn CreateJobObjectW(?*anyopaque, ?LPCWSTR) callconv(WINAPI) HANDLE;
pub extern "kernel32" fn AssignProcessToJobObject(HANDLE, HANDLE) callconv(WINAPI) BOOL;
pub extern "kernel32" fn SetInformationJobObject(HANDLE, u32, *anyopaque, DWORD) callconv(WINAPI) BOOL;
pub extern "kernel32" fn CreatePipe(hReadPipe: *HANDLE, hWritePipe: *HANDLE, lpPipeAttributes: ?*SECURITY_ATTRIBUTES, nSize: DWORD) callconv(WINAPI) BOOL;
pub extern "kernel32" fn ReadFile(hFile: HANDLE, lpBuffer: [*]u8, nNumberOfBytesToRead: DWORD, lpNumberOfBytesRead: ?*DWORD, lpOverlapped: ?*anyopaque) callconv(WINAPI) BOOL;
pub extern "kernel32" fn PeekNamedPipe(hNamedPipe: HANDLE, lpBuffer: ?*anyopaque, nBufferSize: DWORD, lpBytesRead: ?*DWORD, lpTotalBytesAvail: ?*DWORD, lpBytesLeftThisMessage: ?*DWORD) callconv(WINAPI) BOOL;
pub extern "kernel32" fn WriteFile(hFile: HANDLE, lpBuffer: [*]const u8, nNumberOfBytesToWrite: DWORD, lpNumberOfBytesWritten: ?*DWORD, lpOverlapped: ?*anyopaque) callconv(WINAPI) BOOL;
pub extern "kernel32" fn CreateFileW(lpFileName: LPCWSTR, dwDesiredAccess: DWORD, dwShareMode: DWORD, lpSecurityAttributes: ?*SECURITY_ATTRIBUTES, dwCreationDisposition: DWORD, dwFlagsAndAttributes: DWORD, hTemplateFile: HANDLE) callconv(WINAPI) HANDLE;
pub extern "kernel32" fn GetFileSizeEx(hFile: HANDLE, lpFileSize: *i64) callconv(WINAPI) BOOL;
pub extern "kernel32" fn SetFilePointerEx(hFile: HANDLE, liDistanceToMove: i64, lpNewFilePointer: ?*i64, dwMoveMethod: DWORD) callconv(WINAPI) BOOL;
pub extern "kernel32" fn CreateDirectoryW(lpPathName: LPCWSTR, lpSecurityAttributes: ?*SECURITY_ATTRIBUTES) callconv(WINAPI) BOOL;
pub extern "kernel32" fn MoveFileW(lpExistingFileName: LPCWSTR, lpNewFileName: LPCWSTR) callconv(WINAPI) BOOL;
pub extern "kernel32" fn MoveFileExW(lpExistingFileName: LPCWSTR, lpNewFileName: LPCWSTR, dwFlags: DWORD) callconv(WINAPI) BOOL;
pub extern "kernel32" fn FlushFileBuffers(hFile: HANDLE) callconv(WINAPI) BOOL;
pub extern "kernel32" fn ReplaceFileW(lpReplacedFileName: LPCWSTR, lpReplacementFileName: LPCWSTR, lpBackupFileName: ?LPCWSTR, dwReplaceFlags: DWORD, lpExclude: ?*anyopaque, lpReserved: ?*anyopaque) callconv(WINAPI) BOOL;
extern "kernel32" fn CopyFileW(lpExistingFileName: LPCWSTR, lpNewFileName: LPCWSTR, bFailIfExists: BOOL) callconv(WINAPI) BOOL;
pub const MOVEFILE_REPLACE_EXISTING: DWORD = 0x1;
pub const MOVEFILE_WRITE_THROUGH: DWORD = 0x8;
pub const GENERIC_READ: DWORD = 0x80000000;
pub const GENERIC_WRITE: DWORD = 0x40000000;
pub const FILE_SHARE_READ: DWORD = 0x00000001;
pub const FILE_SHARE_WRITE: DWORD = 0x00000002;
pub const FILE_SHARE_DELETE: DWORD = 0x00000004;
pub const CREATE_ALWAYS: DWORD = 2;
pub const OPEN_EXISTING: DWORD = 3;
pub const OPEN_ALWAYS: DWORD = 4;
pub const FILE_ATTRIBUTE_NORMAL: DWORD = 0x80;
pub const FILE_END: DWORD = 2;
pub extern "kernel32" fn WaitForSingleObject(hHandle: HANDLE, dwMilliseconds: DWORD) callconv(WINAPI) DWORD;
const WAITORTIMERCALLBACK = *const fn (?*anyopaque, BOOL) callconv(WINAPI) void;
pub const WT_EXECUTEONLYONCE: u32 = 0x00000008;
pub const INVALID_HANDLE_VALUE_PTR: HANDLE = @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))));
pub extern "kernel32" fn RegisterWaitForSingleObject(phNewWaitObject: *HANDLE, hObject: HANDLE, Callback: WAITORTIMERCALLBACK, Context: ?*anyopaque, dwMilliseconds: DWORD, dwFlags: DWORD) callconv(WINAPI) BOOL;
pub extern "kernel32" fn UnregisterWaitEx(WaitHandle: HANDLE, CompletionEvent: HANDLE) callconv(WINAPI) BOOL;
pub extern "kernel32" fn GetTickCount() callconv(WINAPI) DWORD;
pub extern "kernel32" fn GetComputerNameW(buffer: [*]u16, size: *DWORD) callconv(WINAPI) BOOL;
pub extern "kernel32" fn GetTickCount64() callconv(WINAPI) u64;
pub extern "kernel32" fn GetSystemTimeAsFileTime(lpSystemTimeAsFileTime: *[2]DWORD) callconv(WINAPI) void;
pub extern "kernel32" fn GetLocalTime(lpSystemTime: *SYSTEMTIME) callconv(WINAPI) void;
pub extern "kernel32" fn TzSpecificLocalTimeToSystemTime(lpTimeZoneInformation: ?*anyopaque, lpLocalTime: *const SYSTEMTIME, lpUniversalTime: *SYSTEMTIME) callconv(WINAPI) BOOL;
pub extern "kernel32" fn SystemTimeToFileTime(lpSystemTime: *const SYSTEMTIME, lpFileTime: *FILETIME) callconv(WINAPI) BOOL;
pub extern "kernel32" fn FileTimeToLocalFileTime(lpFileTime: *const FILETIME, lpLocalFileTime: *FILETIME) callconv(WINAPI) BOOL;
pub extern "kernel32" fn FileTimeToSystemTime(lpFileTime: *const FILETIME, lpSystemTime: *SYSTEMTIME) callconv(WINAPI) BOOL;
pub extern "kernel32" fn SystemTimeToTzSpecificLocalTime(lpTimeZoneInformation: ?*anyopaque, lpUniversalTime: *const SYSTEMTIME, lpLocalTime: *SYSTEMTIME) callconv(WINAPI) BOOL;

pub const SECURITY_ATTRIBUTES = extern struct {
    nLength: DWORD,
    lpSecurityDescriptor: ?*anyopaque,
    bInheritHandle: BOOL,
};

pub const JOBOBJECT_EXTENDED_LIMIT_INFORMATION = extern struct {
    basic: extern struct {
        per_process_user_time_limit: i64,
        per_job_user_time_limit: i64,
        limit_flags: DWORD,
        minimum_working_set_size: usize,
        maximum_working_set_size: usize,
        active_process_limit: DWORD,
        affinity: usize,
        priority_class: DWORD,
        scheduling_class: DWORD,
    },
    io_info: extern struct { read_ops: u64, write_ops: u64, other_ops: u64, read_bytes: u64, write_bytes: u64, other_bytes: u64 },
    process_memory_limit: usize,
    job_memory_limit: usize,
    peak_process_memory_used: usize,
    peak_job_memory_used: usize,
};
pub const JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE: DWORD = 0x2000;
pub const JobObjectExtendedLimitInformation: u32 = 9;
pub const PROCESS_TERMINATE: DWORD = 0x0001;

pub const STD_OUTPUT_HANDLE: DWORD = @bitCast(@as(i32, -11));

pub const COORD = extern struct {
    x: i16,
    y: i16,
};

const SMALL_RECT = extern struct {
    left: i16,
    top: i16,
    right: i16,
    bottom: i16,
};

pub const CONSOLE_SCREEN_BUFFER_INFO = extern struct {
    dwSize: COORD,
    dwCursorPosition: COORD,
    wAttributes: u16,
    srWindow: SMALL_RECT,
    dwMaximumWindowSize: COORD,
};

pub const CONSOLE_SCREEN_BUFFER_INFOEX = extern struct {
    cbSize: DWORD,
    dwSize: COORD,
    dwCursorPosition: COORD,
    wAttributes: WORD,
    srWindow: SMALL_RECT,
    dwMaximumWindowSize: COORD,
    wPopupAttributes: WORD,
    bFullscreenSupported: BOOL,
    ColorTable: [16]DWORD,
};

pub const CONSOLE_FONT_INFOEX = extern struct {
    cbSize: DWORD,
    nFont: DWORD,
    dwFontSize: COORD,
    FontFamily: UINT,
    FontWeight: UINT,
    FaceName: [32]u16,
};

pub const PROCESS_QUERY_INFORMATION: DWORD = 0x0400;
pub const PROCESS_QUERY_LIMITED_INFORMATION: DWORD = 0x1000;
pub const PROCESS_SYNCHRONIZE: DWORD = 0x00100000;
pub const PROCESS_VM_READ: DWORD = 0x0010;

pub const PROCESS_MEMORY_COUNTERS = extern struct {
    cb: DWORD,
    PageFaultCount: DWORD,
    PeakWorkingSetSize: usize,
    WorkingSetSize: usize,
    QuotaPeakPagedPoolUsage: usize,
    QuotaPagedPoolUsage: usize,
    QuotaPeakNonPagedPoolUsage: usize,
    QuotaNonPagedPoolUsage: usize,
    PagefileUsage: usize,
    PeakPagefileUsage: usize,
};

const WNDENUMPROC = *const fn (HANDLE, LPARAM) callconv(WINAPI) BOOL;
pub extern "user32" fn EnumWindows(WNDENUMPROC, LPARAM) callconv(WINAPI) BOOL;
pub extern "user32" fn SendMessageW(HANDLE, UINT, WPARAM, LPARAM) callconv(WINAPI) LRESULT;
pub extern "user32" fn SendMessageTimeoutW(HANDLE, UINT, WPARAM, LPARAM, UINT, UINT, ?*usize) callconv(WINAPI) LRESULT;
pub extern "user32" fn CallWindowProcW(isize, HANDLE, UINT, WPARAM, LPARAM) callconv(WINAPI) LRESULT;
pub extern "user32" fn CreatePopupMenu() callconv(WINAPI) HANDLE;
pub extern "user32" fn AppendMenuW(HANDLE, UINT, usize, ?LPCWSTR) callconv(WINAPI) BOOL;
pub extern "user32" fn TrackPopupMenu(HANDLE, UINT, i32, i32, i32, HANDLE, ?*const RECT) callconv(WINAPI) BOOL;
pub extern "user32" fn DestroyMenu(HANDLE) callconv(WINAPI) BOOL;
pub extern "user32" fn MessageBoxW(HANDLE, LPCWSTR, LPCWSTR, UINT) callconv(WINAPI) i32;
pub extern "user32" fn ClientToScreen(HANDLE, *POINT) callconv(WINAPI) BOOL;
pub extern "user32" fn WindowFromPoint(POINT) callconv(WINAPI) HANDLE;
pub extern "user32" fn GetParent(HANDLE) callconv(WINAPI) HANDLE;
pub const GUITHREADINFO = extern struct {
    cbSize: DWORD,
    flags: DWORD,
    hwndActive: HANDLE,
    hwndFocus: HANDLE,
    hwndCapture: HANDLE,
    hwndMenuOwner: HANDLE,
    hwndMoveSize: HANDLE,
    hwndCaret: HANDLE,
    rcCaret: RECT,
};
pub extern "user32" fn GetGUIThreadInfo(DWORD, *GUITHREADINFO) callconv(WINAPI) BOOL;
pub extern "user32" fn GetAncestor(HANDLE, UINT) callconv(WINAPI) HANDLE;
pub extern "user32" fn ScreenToClient(HANDLE, *POINT) callconv(WINAPI) BOOL;
pub extern "user32" fn GetCursorPos(*POINT) callconv(WINAPI) BOOL;
pub extern "user32" fn TrackMouseEvent(*TRACKMOUSEEVENT) callconv(WINAPI) BOOL;
pub extern "shell32" fn ShellExecuteW(HANDLE, ?LPCWSTR, LPCWSTR, ?LPCWSTR, ?LPCWSTR, i32) callconv(WINAPI) HANDLE;

pub const WM_RBUTTONDOWN: u32 = 0x0204;
pub const WM_NCLBUTTONDOWN: u32 = 0x00A1;
pub const WM_NCRBUTTONDOWN: u32 = 0x00A4;
pub const WM_ENTERMENULOOP: u32 = 0x0211;
pub const WM_EXITMENULOOP: u32 = 0x0212;
pub const WM_ENTERSIZEMOVE: u32 = 0x0231;
pub const WM_EXITSIZEMOVE: u32 = 0x0232;
pub const MF_STRING: UINT = 0x0000;
const MF_SEPARATOR: UINT = 0x0800;
pub const SMTO_BLOCK: UINT = 0x0001;
pub const SMTO_ABORTIFHUNG: UINT = 0x0002;
const MF_OWNERDRAW: UINT = 0x0100;
pub const TPM_RETURNCMD: UINT = 0x0100;
pub const TPM_LEFTALIGN: UINT = 0x0000;

pub const MENU_MOVE_TO_WORKSPACE_BASE: usize = 900;
pub const MENU_MOVE_TO_PILL_BASE: usize = 980;
pub const MENU_HEADER_RENAME: usize = 500;
pub const MENU_HEADER_COLLAPSE: usize = 501;
pub const MENU_HEADER_UNGROUP: usize = 502;
pub const MENU_HEADER_CLOSE: usize = 503;
pub const MENU_HEADER_NEW_TAB: usize = 504;
pub const MENU_HEADER_MOVE_WORKSPACE: usize = 505;
pub const MENU_HEADER_COLOR_BASE: usize = 520;

pub const TH32CS_SNAPPROCESS: DWORD = 0x00000002;
pub const PROCESSENTRY32W = extern struct {
    dwSize: DWORD,
    cntUsage: DWORD,
    th32ProcessID: DWORD,
    th32DefaultHeapID: usize,
    th32ModuleID: DWORD,
    cntThreads: DWORD,
    th32ParentProcessID: DWORD,
    pcPriClassBase: LONG,
    dwFlags: DWORD,
    szExeFile: [260]u16,
};
pub extern "kernel32" fn CreateToolhelp32Snapshot(DWORD, DWORD) callconv(WINAPI) HANDLE;
pub extern "kernel32" fn Process32FirstW(HANDLE, *PROCESSENTRY32W) callconv(WINAPI) BOOL;
pub extern "kernel32" fn Process32NextW(HANDLE, *PROCESSENTRY32W) callconv(WINAPI) BOOL;
extern "kernel32" fn GetProcessId(HANDLE) callconv(WINAPI) DWORD;
pub extern "kernel32" fn GetExitCodeProcess(HANDLE, *DWORD) callconv(WINAPI) BOOL;
pub const STILL_ACTIVE: DWORD = 259;
pub extern "kernel32" fn FindFirstChangeNotificationW(LPCWSTR, BOOL, DWORD) callconv(WINAPI) HANDLE;
pub extern "kernel32" fn FindNextChangeNotification(HANDLE) callconv(WINAPI) BOOL;
pub extern "kernel32" fn FindCloseChangeNotification(HANDLE) callconv(WINAPI) BOOL;
pub extern "kernel32" fn WaitForMultipleObjects(DWORD, [*]const HANDLE, BOOL, DWORD) callconv(WINAPI) DWORD;

pub extern "kernel32" fn OpenEventW(dwDesiredAccess: DWORD, bInheritHandle: BOOL, lpName: LPCWSTR) callconv(WINAPI) HANDLE;
pub extern "kernel32" fn SetEvent(hEvent: HANDLE) callconv(WINAPI) BOOL;
pub extern "kernel32" fn SetProcessInformation(hProcess: HANDLE, ProcessInformationClass: i32, ProcessInformation: *anyopaque, ProcessInformationSize: DWORD) callconv(WINAPI) BOOL;

pub extern "kernel32" fn CreateMutexW(?*anyopaque, BOOL, [*:0]const u16) callconv(WINAPI) HANDLE;
pub extern "kernel32" fn OpenMutexW(DWORD, BOOL, [*:0]const u16) callconv(WINAPI) HANDLE;
pub extern "kernel32" fn ReleaseMutex(HANDLE) callconv(WINAPI) BOOL;

pub extern "user32" fn GetClassNameW(HANDLE, [*]u16, i32) callconv(WINAPI) i32;

pub extern "bcrypt" fn BCryptGenRandom(?*anyopaque, [*]u8, u32, u32) callconv(WINAPI) i32;

pub const HRESULT = LONG;
pub const S_OK: HRESULT = 0;
pub const CLSCTX_INPROC_SERVER: DWORD = 1;
pub const COINIT_APARTMENTTHREADED: DWORD = 2;

pub const GUID = extern struct { Data1: u32, Data2: u16, Data3: u16, Data4: [8]u8 };
const PROPERTYKEY = extern struct { fmtid: GUID, pid: u32 };
pub const PROPVARIANT = extern struct {
    vt: u16,
    r1: u16,
    r2: u16,
    r3: u16,
    data: [16]u8,
};
pub const VT_LPWSTR: u16 = 31;

pub const CLSID_DestinationList = GUID{ .Data1 = 0x77F10CF0, .Data2 = 0x3DB5, .Data3 = 0x4966, .Data4 = .{ 0xB5, 0x20, 0xB7, 0xC5, 0x4F, 0xD3, 0x5E, 0xD6 } };
pub const IID_ICustomDestinationList = GUID{ .Data1 = 0x6332DEBF, .Data2 = 0x87B5, .Data3 = 0x4670, .Data4 = .{ 0x90, 0xC0, 0x5E, 0x57, 0xB4, 0x08, 0xA4, 0x9E } };
pub const CLSID_EnumerableObjectCollection = GUID{ .Data1 = 0x2D3468C1, .Data2 = 0x36A7, .Data3 = 0x43B6, .Data4 = .{ 0xAC, 0x24, 0xD3, 0xF0, 0x2F, 0xD9, 0x60, 0x7A } };
pub const IID_IObjectCollection = GUID{ .Data1 = 0x5632B1A4, .Data2 = 0xE38A, .Data3 = 0x400A, .Data4 = .{ 0x92, 0x8A, 0xD4, 0xCD, 0x63, 0x23, 0x02, 0x95 } };
pub const IID_IObjectArray = GUID{ .Data1 = 0x92CA9DCD, .Data2 = 0x5622, .Data3 = 0x4BBA, .Data4 = .{ 0xA8, 0x05, 0x5E, 0x9F, 0x54, 0x1B, 0xD8, 0xC9 } };
pub const CLSID_ShellLink = GUID{ .Data1 = 0x00021401, .Data2 = 0x0000, .Data3 = 0x0000, .Data4 = .{ 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 } };
pub const IID_IShellLinkW = GUID{ .Data1 = 0x000214F9, .Data2 = 0x0000, .Data3 = 0x0000, .Data4 = .{ 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 } };
pub const IID_IPersistFile = GUID{ .Data1 = 0x0000010B, .Data2 = 0x0000, .Data3 = 0x0000, .Data4 = .{ 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 } };
pub const IID_IPropertyStore = GUID{ .Data1 = 0x886D8EEB, .Data2 = 0x8CF2, .Data3 = 0x4446, .Data4 = .{ 0x8D, 0x02, 0xCD, 0xBA, 0x1D, 0xBD, 0xCF, 0x99 } };
pub const PKEY_Title = PROPERTYKEY{ .fmtid = GUID{ .Data1 = 0xF29F85E0, .Data2 = 0x4FF9, .Data3 = 0x1068, .Data4 = .{ 0xAB, 0x91, 0x08, 0x00, 0x2B, 0x27, 0xB3, 0xD9 } }, .pid = 2 };
pub const PKEY_AppUserModel_ID = PROPERTYKEY{ .fmtid = GUID{ .Data1 = 0x9F4C2855, .Data2 = 0x9F79, .Data3 = 0x4B39, .Data4 = .{ 0xA8, 0xD0, 0xE1, 0xD4, 0x2D, 0xE1, 0xD5, 0xF3 } }, .pid = 5 };

const IUnknownVtbl = extern struct {
    QueryInterface: *const fn (*anyopaque, *const GUID, *?*anyopaque) callconv(WINAPI) HRESULT,
    AddRef: *const fn (*anyopaque) callconv(WINAPI) u32,
    Release: *const fn (*anyopaque) callconv(WINAPI) u32,
};
pub const IUnknown = extern struct { lpVtbl: *const IUnknownVtbl };

const ICustomDestinationListVtbl = extern struct {
    QueryInterface: *const anyopaque,
    AddRef: *const anyopaque,
    Release: *const anyopaque,
    SetAppID: *const fn (*ICustomDestinationList, [*:0]const u16) callconv(WINAPI) HRESULT,
    BeginList: *const fn (*ICustomDestinationList, *u32, *const GUID, *?*anyopaque) callconv(WINAPI) HRESULT,
    AppendCategory: *const anyopaque,
    AppendKnownCategory: *const anyopaque,
    AddUserTasks: *const fn (*ICustomDestinationList, *anyopaque) callconv(WINAPI) HRESULT,
    CommitList: *const fn (*ICustomDestinationList) callconv(WINAPI) HRESULT,
    GetRemovedDestinations: *const anyopaque,
    DeleteList: *const anyopaque,
    AbortList: *const anyopaque,
};
pub const ICustomDestinationList = extern struct { lpVtbl: *const ICustomDestinationListVtbl };

const IObjectCollectionVtbl = extern struct {
    QueryInterface: *const fn (*IObjectCollection, *const GUID, *?*anyopaque) callconv(WINAPI) HRESULT,
    AddRef: *const anyopaque,
    Release: *const anyopaque,
    GetCount: *const anyopaque,
    GetAt: *const anyopaque,
    AddObject: *const fn (*IObjectCollection, *anyopaque) callconv(WINAPI) HRESULT,
    AddFromArray: *const anyopaque,
    RemoveObjectAt: *const anyopaque,
    Clear: *const anyopaque,
};
pub const IObjectCollection = extern struct { lpVtbl: *const IObjectCollectionVtbl };

const IShellLinkWVtbl = extern struct {
    QueryInterface: *const fn (*IShellLinkW, *const GUID, *?*anyopaque) callconv(WINAPI) HRESULT,
    AddRef: *const anyopaque,
    Release: *const anyopaque,
    GetPath: *const anyopaque,
    GetIDList: *const anyopaque,
    SetIDList: *const anyopaque,
    GetDescription: *const anyopaque,
    SetDescription: *const fn (*IShellLinkW, [*:0]const u16) callconv(WINAPI) HRESULT,
    GetWorkingDirectory: *const anyopaque,
    SetWorkingDirectory: *const anyopaque,
    GetArguments: *const anyopaque,
    SetArguments: *const fn (*IShellLinkW, [*:0]const u16) callconv(WINAPI) HRESULT,
    GetHotkey: *const anyopaque,
    SetHotkey: *const anyopaque,
    GetShowCmd: *const anyopaque,
    SetShowCmd: *const anyopaque,
    GetIconLocation: *const anyopaque,
    SetIconLocation: *const fn (*IShellLinkW, [*:0]const u16, i32) callconv(WINAPI) HRESULT,
    SetRelativePath: *const anyopaque,
    Resolve: *const anyopaque,
    SetPath: *const fn (*IShellLinkW, [*:0]const u16) callconv(WINAPI) HRESULT,
};
pub const IShellLinkW = extern struct { lpVtbl: *const IShellLinkWVtbl };

const IPersistFileVtbl = extern struct {
    QueryInterface: *const anyopaque,
    AddRef: *const anyopaque,
    Release: *const anyopaque,
    GetClassID: *const anyopaque,
    IsDirty: *const anyopaque,
    Load: *const fn (*IPersistFile, LPCWSTR, DWORD) callconv(WINAPI) HRESULT,
    Save: *const fn (*IPersistFile, LPCWSTR, BOOL) callconv(WINAPI) HRESULT,
    SaveCompleted: *const anyopaque,
    GetCurFile: *const anyopaque,
};
pub const IPersistFile = extern struct { lpVtbl: *const IPersistFileVtbl };

const IPropertyStoreVtbl = extern struct {
    QueryInterface: *const anyopaque,
    AddRef: *const anyopaque,
    Release: *const anyopaque,
    GetCount: *const anyopaque,
    GetAt: *const anyopaque,
    GetValue: *const anyopaque,
    SetValue: *const fn (*IPropertyStore, *const PROPERTYKEY, *const PROPVARIANT) callconv(WINAPI) HRESULT,
    Commit: *const fn (*IPropertyStore) callconv(WINAPI) HRESULT,
};
pub const IPropertyStore = extern struct { lpVtbl: *const IPropertyStoreVtbl };

pub extern "ole32" fn CoInitializeEx(?*anyopaque, DWORD) callconv(WINAPI) HRESULT;
pub extern "ole32" fn CoUninitialize() callconv(WINAPI) void;
pub const AudioClientProperties = extern struct { cbSize: u32 = 16, bIsOffload: BOOL = 0, eCategory: i32 = 3, Options: u32 = 0 };
pub const AudioEffectWin = extern struct { id: GUID, canSetState: BOOL, state: i32 };
comptime {
    std.debug.assert(@sizeOf(AudioClientProperties) == 16);
    std.debug.assert(@sizeOf(AudioEffectWin) == 24);
}
pub const CLSID_MMDeviceEnumerator = GUID{ .Data1 = 0xBCDE0395, .Data2 = 0xE52F, .Data3 = 0x467C, .Data4 = .{ 0x8E, 0x3D, 0xC4, 0x57, 0x92, 0x91, 0x69, 0x2E } };
pub const IID_IMMDeviceEnumerator = GUID{ .Data1 = 0xA95664D2, .Data2 = 0x9614, .Data3 = 0x4F35, .Data4 = .{ 0xA7, 0x46, 0xDE, 0x8D, 0xB6, 0x36, 0x17, 0xE6 } };
pub const IID_IAudioClient2 = GUID{ .Data1 = 0x726778CD, .Data2 = 0xF60A, .Data3 = 0x4EDA, .Data4 = .{ 0x82, 0xDE, 0xE4, 0x76, 0x10, 0xCD, 0x78, 0xAA } };
pub const IID_IAudioCaptureClient = GUID{ .Data1 = 0xC8ADBD64, .Data2 = 0xE71E, .Data3 = 0x48A0, .Data4 = .{ 0xA4, 0xDE, 0x18, 0x5C, 0x39, 0x5C, 0xD3, 0x17 } };
pub const IID_IAcousticEchoCancellationControl = GUID{ .Data1 = 0xF4AE25B5, .Data2 = 0xAAA3, .Data3 = 0x437D, .Data4 = .{ 0xB6, 0xB3, 0xDB, 0xBE, 0x2D, 0x0E, 0x95, 0x49 } };
pub const IID_IAudioEffectsManager = GUID{ .Data1 = 0x4460B3AE, .Data2 = 0x4B44, .Data3 = 0x4527, .Data4 = .{ 0x86, 0x76, 0x75, 0x48, 0xA8, 0xAC, 0xD2, 0x60 } };
pub const IID_IAudioSessionManager = GUID{ .Data1 = 0xBFA971F1, .Data2 = 0x4D5E, .Data3 = 0x40BB, .Data4 = .{ 0x93, 0x5E, 0x96, 0x70, 0x39, 0xBF, 0xBE, 0xE4 } };
pub const IID_IAudioSessionControl2 = GUID{ .Data1 = 0xBFB7FF88, .Data2 = 0x7239, .Data3 = 0x4FC9, .Data4 = .{ 0x8F, 0xA2, 0x07, 0xC9, 0x50, 0xBE, 0x9C, 0x6D } };
const IMMDeviceEnumeratorVtbl = extern struct {
    slot0: *const anyopaque,
    slot1: *const anyopaque,
    slot2: *const anyopaque,
    slot3: *const anyopaque,
    GetDefaultAudioEndpoint: *const fn (*IMMDeviceEnumerator, i32, i32, *?*IMMDevice) callconv(WINAPI) HRESULT,
};
pub const IMMDeviceEnumerator = extern struct { lpVtbl: *const IMMDeviceEnumeratorVtbl };
comptime {
    std.debug.assert(@offsetOf(IMMDeviceEnumeratorVtbl, "GetDefaultAudioEndpoint") == 4 * @sizeOf(usize));
}
const IMMDeviceVtbl = extern struct {
    slot0: *const anyopaque,
    slot1: *const anyopaque,
    slot2: *const anyopaque,
    Activate: *const fn (*IMMDevice, *const GUID, DWORD, ?*anyopaque, *?*anyopaque) callconv(WINAPI) HRESULT,
    slot4: *const anyopaque,
    GetId: *const fn (*IMMDevice, *?[*:0]u16) callconv(WINAPI) HRESULT,
};
pub const IMMDevice = extern struct { lpVtbl: *const IMMDeviceVtbl };
comptime {
    std.debug.assert(@offsetOf(IMMDeviceVtbl, "Activate") == 3 * @sizeOf(usize));
}
comptime {
    std.debug.assert(@offsetOf(IMMDeviceVtbl, "GetId") == 5 * @sizeOf(usize));
}
const IAudioClient2Vtbl = extern struct {
    slot0: *const anyopaque,
    slot1: *const anyopaque,
    slot2: *const anyopaque,
    Initialize: *const fn (*IAudioClient2, i32, DWORD, i64, i64, *const WAVEFORMATEX, ?*const GUID) callconv(WINAPI) HRESULT,
    slot4: *const anyopaque,
    slot5: *const anyopaque,
    slot6: *const anyopaque,
    slot7: *const anyopaque,
    slot8: *const anyopaque,
    slot9: *const anyopaque,
    Start: *const fn (*IAudioClient2) callconv(WINAPI) HRESULT,
    Stop: *const fn (*IAudioClient2) callconv(WINAPI) HRESULT,
    slot12: *const anyopaque,
    SetEventHandle: *const fn (*IAudioClient2, HANDLE) callconv(WINAPI) HRESULT,
    GetService: *const fn (*IAudioClient2, *const GUID, *?*anyopaque) callconv(WINAPI) HRESULT,
    slot15: *const anyopaque,
    SetClientProperties: *const fn (*IAudioClient2, *const AudioClientProperties) callconv(WINAPI) HRESULT,
    slot17: *const anyopaque,
};
pub const IAudioClient2 = extern struct { lpVtbl: *const IAudioClient2Vtbl };
comptime {
    std.debug.assert(@offsetOf(IAudioClient2Vtbl, "Initialize") == 3 * @sizeOf(usize));
}
comptime {
    std.debug.assert(@offsetOf(IAudioClient2Vtbl, "Start") == 10 * @sizeOf(usize));
}
comptime {
    std.debug.assert(@offsetOf(IAudioClient2Vtbl, "Stop") == 11 * @sizeOf(usize));
}
comptime {
    std.debug.assert(@offsetOf(IAudioClient2Vtbl, "SetEventHandle") == 13 * @sizeOf(usize));
}
comptime {
    std.debug.assert(@offsetOf(IAudioClient2Vtbl, "GetService") == 14 * @sizeOf(usize));
}
comptime {
    std.debug.assert(@offsetOf(IAudioClient2Vtbl, "SetClientProperties") == 16 * @sizeOf(usize));
}
const IAudioCaptureClientVtbl = extern struct {
    slot0: *const anyopaque,
    slot1: *const anyopaque,
    slot2: *const anyopaque,
    GetBuffer: *const fn (*IAudioCaptureClient, *?[*]u8, *u32, *u32, ?*u64, ?*u64) callconv(WINAPI) HRESULT,
    ReleaseBuffer: *const fn (*IAudioCaptureClient, u32) callconv(WINAPI) HRESULT,
    GetNextPacketSize: *const fn (*IAudioCaptureClient, *u32) callconv(WINAPI) HRESULT,
};
pub const IAudioCaptureClient = extern struct { lpVtbl: *const IAudioCaptureClientVtbl };
comptime {
    std.debug.assert(@offsetOf(IAudioCaptureClientVtbl, "GetBuffer") == 3 * @sizeOf(usize));
}
comptime {
    std.debug.assert(@offsetOf(IAudioCaptureClientVtbl, "ReleaseBuffer") == 4 * @sizeOf(usize));
}
comptime {
    std.debug.assert(@offsetOf(IAudioCaptureClientVtbl, "GetNextPacketSize") == 5 * @sizeOf(usize));
}
const IAcousticEchoCancellationControlVtbl = extern struct {
    slot0: *const anyopaque,
    slot1: *const anyopaque,
    slot2: *const anyopaque,
    SetEchoCancellationRenderEndpoint: *const fn (*IAcousticEchoCancellationControl, [*:0]const u16) callconv(WINAPI) HRESULT,
};
pub const IAcousticEchoCancellationControl = extern struct { lpVtbl: *const IAcousticEchoCancellationControlVtbl };
comptime {
    std.debug.assert(@offsetOf(IAcousticEchoCancellationControlVtbl, "SetEchoCancellationRenderEndpoint") == 3 * @sizeOf(usize));
}
const IAudioEffectsManagerVtbl = extern struct {
    slot0: *const anyopaque,
    slot1: *const anyopaque,
    slot2: *const anyopaque,
    slot3: *const anyopaque,
    slot4: *const anyopaque,
    GetAudioEffects: *const fn (*IAudioEffectsManager, *?[*]AudioEffectWin, *u32) callconv(WINAPI) HRESULT,
};
pub const IAudioEffectsManager = extern struct { lpVtbl: *const IAudioEffectsManagerVtbl };
comptime {
    std.debug.assert(@offsetOf(IAudioEffectsManagerVtbl, "GetAudioEffects") == 5 * @sizeOf(usize));
}
const IAudioSessionManagerVtbl = extern struct {
    slot0: *const anyopaque,
    slot1: *const anyopaque,
    slot2: *const anyopaque,
    GetAudioSessionControl: *const fn (*IAudioSessionManager, ?*const GUID, DWORD, *?*anyopaque) callconv(WINAPI) HRESULT,
};
pub const IAudioSessionManager = extern struct { lpVtbl: *const IAudioSessionManagerVtbl };
comptime {
    std.debug.assert(@offsetOf(IAudioSessionManagerVtbl, "GetAudioSessionControl") == 3 * @sizeOf(usize));
}
const IAudioSessionControl2Vtbl = extern struct {
    slot0: *const anyopaque,
    slot1: *const anyopaque,
    slot2: *const anyopaque,
    slot3: *const anyopaque,
    slot4: *const anyopaque,
    slot5: *const anyopaque,
    slot6: *const anyopaque,
    slot7: *const anyopaque,
    slot8: *const anyopaque,
    slot9: *const anyopaque,
    slot10: *const anyopaque,
    slot11: *const anyopaque,
    slot12: *const anyopaque,
    slot13: *const anyopaque,
    slot14: *const anyopaque,
    slot15: *const anyopaque,
    SetDuckingPreference: *const fn (*IAudioSessionControl2, BOOL) callconv(WINAPI) HRESULT,
};
pub const IAudioSessionControl2 = extern struct { lpVtbl: *const IAudioSessionControl2Vtbl };
comptime {
    std.debug.assert(@offsetOf(IAudioSessionControl2Vtbl, "SetDuckingPreference") == 16 * @sizeOf(usize));
}
pub extern "ole32" fn CoTaskMemFree(?*anyopaque) callconv(WINAPI) void;

pub extern "ole32" fn CoCreateInstance(*const GUID, ?*anyopaque, DWORD, *const GUID, *?*anyopaque) callconv(WINAPI) HRESULT;

pub const CLSID_SpVoice = GUID{ .Data1 = 0x96749377, .Data2 = 0x3391, .Data3 = 0x11D2, .Data4 = .{ 0x9E, 0xE3, 0x00, 0xC0, 0x4F, 0x79, 0x73, 0x96 } };
pub const IID_ISpVoice = GUID{ .Data1 = 0x6C44DF74, .Data2 = 0x72B9, .Data3 = 0x4992, .Data4 = .{ 0xA1, 0xEC, 0xEF, 0x99, 0x6E, 0x04, 0x22, 0xD4 } };

pub const SPF_ASYNC: DWORD = 1;
pub const SPF_PURGEBEFORESPEAK: DWORD = 2;
pub const SPF_IS_NOT_XML: DWORD = 0x10;
pub const SPRS_DONE: DWORD = 1;

pub const SPVOICESTATUS = extern struct {
    ulCurrentStream: u32,
    ulLastStreamQueued: u32,
    hrLastResult: HRESULT,
    dwRunningState: DWORD,
    ulInputWordPos: u32,
    ulInputWordLen: u32,
    ulInputSentPos: u32,
    ulInputSentLen: u32,
    lBookmarkId: i32,
    PhonemeId: u16,
    VisemeId: i32,
    dwReserved1: DWORD,
    dwReserved2: DWORD,
};

const ISpVoiceVtbl = extern struct {
    QueryInterface: *const anyopaque,
    AddRef: *const anyopaque,
    Release: *const fn (*anyopaque) callconv(WINAPI) u32,
    SetNotifySink: *const anyopaque,
    SetNotifyWindowMessage: *const anyopaque,
    SetNotifyCallbackFunction: *const anyopaque,
    SetNotifyCallbackInterface: *const anyopaque,
    SetNotifyWin32Event: *const anyopaque,
    WaitForNotifyEvent: *const anyopaque,
    GetNotifyEventHandle: *const anyopaque,
    SetInterest: *const anyopaque,
    GetEvents: *const anyopaque,
    GetInfo: *const anyopaque,
    SetOutput: *const anyopaque,
    GetOutputObjectToken: *const anyopaque,
    GetOutputStream: *const anyopaque,
    Pause: *const anyopaque,
    Resume: *const anyopaque,
    SetVoice: *const anyopaque,
    GetVoice: *const anyopaque,
    Speak: *const fn (*ISpVoice, ?[*:0]const u16, DWORD, ?*u32) callconv(WINAPI) HRESULT,
    SpeakStream: *const anyopaque,
    GetStatus: *const fn (*ISpVoice, *SPVOICESTATUS, ?*anyopaque) callconv(WINAPI) HRESULT,
};
pub const ISpVoice = extern struct { lpVtbl: *const ISpVoiceVtbl };
pub extern "kernel32" fn SetHandleInformation(hObject: HANDLE, dwMask: DWORD, dwFlags: DWORD) callconv(WINAPI) BOOL;

pub extern "user32" fn keybd_event(u8, u8, DWORD, usize) callconv(WINAPI) void;
pub extern "comdlg32" fn GetOpenFileNameW(*OPENFILENAMEW) callconv(WINAPI) BOOL;

pub extern "wininet" fn InternetGetConnectedState(lpdwFlags: ?*DWORD, dwReserved: DWORD) BOOL;

pub extern "kernel32" fn ReadConsoleOutputCharacterW(HANDLE, [*]u16, DWORD, COORD, *DWORD) callconv(WINAPI) BOOL;
pub extern "kernel32" fn ReadConsoleOutputAttribute(HANDLE, [*]u16, DWORD, COORD, *DWORD) callconv(WINAPI) BOOL;
pub const NOTIFY_PAYLOAD_CAP: usize = 1024;

pub extern "user32" fn SetTimer(HANDLE, usize, UINT, ?*anyopaque) callconv(WINAPI) usize;
pub extern "user32" fn KillTimer(HANDLE, usize) callconv(WINAPI) BOOL;

pub const SOCKET = usize;
pub const INVALID_SOCKET: SOCKET = ~@as(SOCKET, 0);
pub const SOCKADDR_IN = extern struct {
    sin_family: i16,
    sin_port: u16,
    sin_addr: u32,
    sin_zero: [8]u8,
};
pub const AF_INET: i16 = 2;
pub const SOCK_STREAM: i32 = 1;
pub const SOL_SOCKET: i32 = 0xFFFF;
pub const SO_REUSEADDR: i32 = 0x0004;
pub const WSADATA = extern struct { data: [408]u8 };

pub extern "ws2_32" fn WSAStartup(WORD, *WSADATA) callconv(WINAPI) i32;
pub extern "ws2_32" fn WSAGetLastError() callconv(WINAPI) i32;
pub extern "ws2_32" fn socket(i32, i32, i32) callconv(WINAPI) SOCKET;
pub extern "ws2_32" fn bind(SOCKET, *const SOCKADDR_IN, i32) callconv(WINAPI) i32;
pub extern "ws2_32" fn listen(SOCKET, i32) callconv(WINAPI) i32;
pub extern "ws2_32" fn accept(SOCKET, ?*anyopaque, ?*i32) callconv(WINAPI) SOCKET;
pub extern "ws2_32" fn recv(SOCKET, [*]u8, i32, i32) callconv(WINAPI) i32;
pub extern "ws2_32" fn closesocket(SOCKET) callconv(WINAPI) i32;
pub extern "ws2_32" fn setsockopt(SOCKET, i32, i32, *const anyopaque, i32) callconv(WINAPI) i32;
pub extern "ws2_32" fn connect(SOCKET, *const SOCKADDR_IN, i32) callconv(WINAPI) i32;
pub extern "ws2_32" fn send(SOCKET, [*]const u8, i32, i32) callconv(WINAPI) i32;
pub extern "ws2_32" fn getsockname(SOCKET, *SOCKADDR_IN, *i32) callconv(WINAPI) i32;
pub extern "credui" fn CredUIPromptForCredentialsW(?*const CREDUI_INFOW, LPCWSTR, ?*anyopaque, DWORD, [*]u16, u32, [*]u16, u32, ?*BOOL, DWORD) callconv(WINAPI) DWORD;

pub extern "user32" fn RegisterClipboardFormatW(LPCWSTR) callconv(WINAPI) UINT;

pub extern "shell32" fn DragAcceptFiles(HANDLE, BOOL) callconv(WINAPI) void;
pub extern "shell32" fn DragQueryFileW(HANDLE, UINT, ?[*]u16, UINT) callconv(WINAPI) UINT;
pub extern "shell32" fn DragFinish(HANDLE) callconv(WINAPI) void;
pub extern "user32" fn ChangeWindowMessageFilterEx(HANDLE, UINT, DWORD, ?*anyopaque) callconv(WINAPI) BOOL;

pub const WM_APP_SHELL_DOUBLE_CLICK: u32 = WM_APP + 204;
pub extern "user32" fn GetDoubleClickTime() callconv(WINAPI) UINT;
pub extern "user32" fn GetSystemMetrics(i32) callconv(WINAPI) i32;

pub extern "user32" fn EnumChildWindows(HANDLE, *const fn (HANDLE, LPARAM) callconv(WINAPI) BOOL, LPARAM) callconv(WINAPI) BOOL;
pub extern "user32" fn GetMenuItemCount(HANDLE) callconv(WINAPI) i32;
pub extern "user32" fn GetMenuState(HANDLE, UINT, UINT) callconv(WINAPI) UINT;
pub extern "user32" fn GetMenuItemID(HANDLE, i32) callconv(WINAPI) UINT;
pub extern "user32" fn GetMenuStringW(HANDLE, UINT, [*]u16, i32, UINT) callconv(WINAPI) i32;
pub extern "user32" fn ModifyMenuW(HANDLE, UINT, UINT, usize, ?LPCWSTR) callconv(WINAPI) BOOL;
pub extern "user32" fn GetSysColor(i32) callconv(WINAPI) DWORD;

pub extern "gdi32" fn GetFontData(HANDLE, DWORD, DWORD, ?*anyopaque, DWORD) callconv(WINAPI) DWORD;

pub extern "user32" fn UpdateWindow(hWnd: HANDLE) callconv(WINAPI) BOOL;
pub extern "kernel32" fn QueryPerformanceCounter(value: *i64) callconv(WINAPI) BOOL;
pub extern "kernel32" fn QueryPerformanceFrequency(value: *i64) callconv(WINAPI) BOOL;

pub extern "kernel32" fn GetEnvironmentStringsW() callconv(WINAPI) ?[*:0]u16;
pub extern "kernel32" fn FreeEnvironmentStringsW([*:0]u16) callconv(WINAPI) BOOL;
pub extern "user32" fn MsgWaitForMultipleObjects(DWORD, ?[*]const HANDLE, BOOL, DWORD, DWORD) callconv(WINAPI) DWORD;
pub extern "user32" fn PeekMessageW(*MSG, HANDLE, UINT, UINT, UINT) callconv(WINAPI) BOOL;

pub const MIB_TCPROW_OWNER_PID = extern struct {
    state: DWORD,
    local_addr: DWORD,
    local_port: DWORD,
    remote_addr: DWORD,
    remote_port: DWORD,
    owning_pid: DWORD,
};
pub extern "iphlpapi" fn GetExtendedTcpTable(?*anyopaque, *DWORD, BOOL, DWORD, DWORD, DWORD) callconv(WINAPI) DWORD;
pub extern "ws2_32" fn getpeername(SOCKET, *SOCKADDR_IN, *i32) callconv(WINAPI) i32;
