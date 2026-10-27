const SEARCH_SETTINGS_OFFSET = @import("app_state.zig").SEARCH_SETTINGS_OFFSET;
const frequent = @import("frequent.zig");
const app_state = @import("app_state.zig");
const std = @import("std");
const tokens = @import("design_tokens.zig");
const archive_rules = @import("archive_rules.zig");
const attention_rules = @import("attention_rules.zig");
const LOOK_UNIFIED = @import("main.zig").LOOK_UNIFIED;
const DWORD = @import("win32.zig").DWORD;
const HANDLE = @import("win32.zig").HANDLE;
const LPCWSTR = @import("win32.zig").LPCWSTR;
const DT_SINGLELINE = @import("win32.zig").DT_SINGLELINE;
const DT_VCENTER = @import("win32.zig").DT_VCENTER;
const DT_CENTER = @import("win32.zig").DT_CENTER;
const DT_RIGHT = @import("win32.zig").DT_RIGHT;
const DT_NOPREFIX = @import("win32.zig").DT_NOPREFIX;
const DT_END_ELLIPSIS = @import("win32.zig").DT_END_ELLIPSIS;
const DT_CALCRECT = @import("win32.zig").DT_CALCRECT;
const TRANSPARENT = @import("win32.zig").TRANSPARENT;
const NULL_BRUSH = @import("win32.zig").NULL_BRUSH;
const RECT = @import("win32.zig").RECT;
const GetClientRect = @import("win32.zig").GetClientRect;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const FillRect = @import("win32.zig").FillRect;
const DrawTextW = @import("win32.zig").DrawTextW;
const DrawIconEx = @import("win32.zig").DrawIconEx;
const CreateSolidBrush = @import("win32.zig").CreateSolidBrush;
const DeleteObject = @import("win32.zig").DeleteObject;
const SetBkMode = @import("win32.zig").SetBkMode;
const SetTextColor = @import("win32.zig").SetTextColor;
const SetTextCharacterExtra = @import("win32.zig").SetTextCharacterExtra;
const SelectObject = @import("win32.zig").SelectObject;
const GetStockObject = @import("win32.zig").GetStockObject;
const CreatePen = @import("win32.zig").CreatePen;
const CreateCompatibleDC = @import("win32.zig").CreateCompatibleDC;
const BitBlt = @import("win32.zig").BitBlt;
const DeleteDC = @import("win32.zig").DeleteDC;
const GDI_SRCCOPY = @import("win32.zig").GDI_SRCCOPY;
const AttachConsole = @import("win32.zig").AttachConsole;
const FreeConsole = @import("win32.zig").FreeConsole;
const GetStdHandle = @import("win32.zig").GetStdHandle;
const GetConsoleScreenBufferInfo = @import("win32.zig").GetConsoleScreenBufferInfo;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const STD_OUTPUT_HANDLE = @import("win32.zig").STD_OUTPUT_HANDLE;
const CONSOLE_SCREEN_BUFFER_INFO = @import("win32.zig").CONSOLE_SCREEN_BUFFER_INFO;
const L = @import("startup.zig").L;
const RGB = @import("startup.zig").RGB;
const getInstanceName = @import("startup.zig").getInstanceName;
const isRemoteShellKind = @import("console.zig").isRemoteShellKind;
const Shell = @import("app_state.zig").Shell;
const MAX_SHELLS = @import("app_state.zig").MAX_SHELLS;
const devThemeOn = @import("themes.zig").devThemeOn;
const customColorOr = @import("themes.zig").customColorOr;
const themeTagTmux = @import("themes.zig").themeTagTmux;
const themeTagVps = @import("themes.zig").themeTagVps;
const themeTagNeutral = @import("themes.zig").themeTagNeutral;
const themeSidebarBg = @import("themes.zig").themeSidebarBg;
const themeConsoleBg = @import("themes.zig").themeConsoleBg;
const themeConsoleFg = @import("themes.zig").themeConsoleFg;
const SIDEBAR_W = @import("browser_pane.zig").SIDEBAR_W;
const SHELL_PAD = @import("app_state.zig").SHELL_PAD;
const tabRowH = @import("browser_pane.zig").tabRowH;
const DEV_LETTER_SPACING = @import("app_state.zig").DEV_LETTER_SPACING;
const DEV_TOP_PAD = @import("app_state.zig").DEV_TOP_PAD;
const GROUP_HEADER_H = @import("app_state.zig").GROUP_HEADER_H;
const BTN_H = @import("app_state.zig").BTN_H;
const NUM_BUTTONS = @import("app_state.zig").NUM_BUTTONS;
const MAX_LWS = @import("app_state.zig").MAX_LWS;
const WS_PILL_TOP = @import("app_state.zig").WS_PILL_TOP;
const WS_PILL_H = @import("app_state.zig").WS_PILL_H;
const WS_PILL_W = @import("app_state.zig").WS_PILL_W;
const WS_PILL_GAP = @import("app_state.zig").WS_PILL_GAP;
const WS_STRIP_LEFT = @import("app_state.zig").WS_STRIP_LEFT;
const WS_NEW_PILL = @import("app_state.zig").WS_NEW_PILL;
const inboxButtonRect = @import("browser_pane.zig").inboxButtonRect;
const inboxButtonHitTest = @import("browser_pane.zig").inboxButtonHitTest;
const wsStripHeight = @import("browser_pane.zig").wsStripHeight;
const MAX_GROUPS = @import("app_state.zig").MAX_GROUPS;
const GROUP_COLORS = @import("app_state.zig").GROUP_COLORS;
const SidebarTier = @import("app_state.zig").SidebarTier;
const Row = @import("app_state.zig").Row;
const MAX_ROWS = @import("app_state.zig").MAX_ROWS;
const SECTION_HEADER_H = @import("app_state.zig").SECTION_HEADER_H;
const HitTarget = @import("app_state.zig").HitTarget;
const tmuxHostTagLabel = @import("capacity.zig").tmuxHostTagLabel;
const sidebarStickyCardSpan = @import("capacity.zig").sidebarStickyCardSpan;
const paintSidebarUpdateCard = @import("update_card.zig").paintSidebarUpdateCard;
const DI_NORMAL = @import("app_state.zig").DI_NORMAL;
const SEARCH_TMUX_OFFSET = @import("app_state.zig").SEARCH_TMUX_OFFSET;
const SEARCH_NEW_OFFSET = @import("app_state.zig").SEARCH_NEW_OFFSET;
const SEARCH_SOUND_OFFSET = @import("app_state.zig").SEARCH_SOUND_OFFSET;
const SEARCH_THEME_MENU_OFFSET = @import("app_state.zig").SEARCH_THEME_MENU_OFFSET;
const SEARCH_THEME_BACK_OFFSET = @import("app_state.zig").SEARCH_THEME_BACK_OFFSET;
const SEARCH_THEME_SYSTEM_OFFSET = @import("app_state.zig").SEARCH_THEME_SYSTEM_OFFSET;
const SEARCH_THEME_DARK_OFFSET = @import("app_state.zig").SEARCH_THEME_DARK_OFFSET;
const SEARCH_THEME_MID_OFFSET = @import("app_state.zig").SEARCH_THEME_MID_OFFSET;
const SEARCH_THEME_LIGHT_OFFSET = @import("app_state.zig").SEARCH_THEME_LIGHT_OFFSET;
const SEARCH_THEME_AMOLED_OFFSET = @import("app_state.zig").SEARCH_THEME_AMOLED_OFFSET;
const SEARCH_THEME_EDGE_GRAY_OFFSET = @import("app_state.zig").SEARCH_THEME_EDGE_GRAY_OFFSET;
const SEARCH_THEME_DEV_BLUE_OFFSET = @import("app_state.zig").SEARCH_THEME_DEV_BLUE_OFFSET;
const SEARCH_THEME_DEV_EDIT_OFFSET = @import("app_state.zig").SEARCH_THEME_DEV_EDIT_OFFSET;
const SEARCH_THEME_DEV_RELOAD_OFFSET = @import("app_state.zig").SEARCH_THEME_DEV_RELOAD_OFFSET;
const SEARCH_THEME_MULTIPROMPT_OFFSET = @import("app_state.zig").SEARCH_THEME_MULTIPROMPT_OFFSET;
const SEARCH_OPENALL_OFFSET = @import("app_state.zig").SEARCH_OPENALL_OFFSET;
const SEARCH_OPENFOLDER_OFFSET = @import("app_state.zig").SEARCH_OPENFOLDER_OFFSET;
const SEARCH_RECOVER_REPO_OFFSET = @import("app_state.zig").SEARCH_RECOVER_REPO_OFFSET;
const SEARCH_OPENALL_HOST_BACK_OFFSET = @import("app_state.zig").SEARCH_OPENALL_HOST_BACK_OFFSET;
const SEARCH_OPENALL_HOST_DE_OFFSET = @import("app_state.zig").SEARCH_OPENALL_HOST_DE_OFFSET;
const SEARCH_OPENALL_HOST_UK_OFFSET = @import("app_state.zig").SEARCH_OPENALL_HOST_UK_OFFSET;
const SEARCH_OPENALL_HOST_INNE_OFFSET = @import("app_state.zig").SEARCH_OPENALL_HOST_INNE_OFFSET;
const SEARCH_NEWWIN_OFFSET = @import("app_state.zig").SEARCH_NEWWIN_OFFSET;
const SEARCH_CREATEWS_OFFSET = @import("app_state.zig").SEARCH_CREATEWS_OFFSET;
const SEARCH_WORKSPACES_MENU_OFFSET = @import("app_state.zig").SEARCH_WORKSPACES_MENU_OFFSET;
const SEARCH_WORKSPACE_DELETE_MENU_OFFSET = @import("app_state.zig").SEARCH_WORKSPACE_DELETE_MENU_OFFSET;
const SEARCH_QUIT_OFFSET = @import("app_state.zig").SEARCH_QUIT_OFFSET;
const SEARCH_FULLWIDTH_OFFSET = @import("app_state.zig").SEARCH_FULLWIDTH_OFFSET;
const SEARCH_SHORTCUTS_OFFSET = @import("app_state.zig").SEARCH_SHORTCUTS_OFFSET;
const SEARCH_CLOSEWIN_OFFSET = @import("app_state.zig").SEARCH_CLOSEWIN_OFFSET;
const SEARCH_RECONNECT_OFFSET = @import("app_state.zig").SEARCH_RECONNECT_OFFSET;
const SEARCH_SINGLEWIN_OFFSET = @import("app_state.zig").SEARCH_SINGLEWIN_OFFSET;
const SEARCH_INSTALLHOOK_OFFSET = @import("app_state.zig").SEARCH_INSTALLHOOK_OFFSET;
const SEARCH_STARRED_OFFSET = @import("app_state.zig").SEARCH_STARRED_OFFSET;
const SEARCH_GOINBOX_OFFSET = @import("app_state.zig").SEARCH_GOINBOX_OFFSET;
const SEARCH_SHOW_FREQUENT_OFFSET = @import("app_state.zig").SEARCH_SHOW_FREQUENT_OFFSET;
const SEARCH_FREQUENT_FIRST_OFFSET = @import("app_state.zig").SEARCH_FREQUENT_FIRST_OFFSET;
const SEARCH_SHOW_FAVORITES_OFFSET = @import("app_state.zig").SEARCH_SHOW_FAVORITES_OFFSET;
const SEARCH_SHOW_ALL_OFFSET = @import("app_state.zig").SEARCH_SHOW_ALL_OFFSET;
const SEARCH_INBOX_FREQUENT_OFFSET = @import("app_state.zig").SEARCH_INBOX_FREQUENT_OFFSET;
const SEARCH_WSSORT_MENU_OFFSET = @import("app_state.zig").SEARCH_WSSORT_MENU_OFFSET;
const SEARCH_WSMOVE_MENU_OFFSET = @import("app_state.zig").SEARCH_WSMOVE_MENU_OFFSET;
const SEARCH_HIDESIDEBAR_OFFSET = @import("app_state.zig").SEARCH_HIDESIDEBAR_OFFSET;
const SEARCH_HIDEPILLS_OFFSET = @import("app_state.zig").SEARCH_HIDEPILLS_OFFSET;
const SEARCH_NEXTUNREAD_OFFSET = @import("app_state.zig").SEARCH_NEXTUNREAD_OFFSET;
const SEARCH_SIDEBAR_COLLAPSE_OFFSET = @import("app_state.zig").SEARCH_SIDEBAR_COLLAPSE_OFFSET;
const SEARCH_SIDEBAR_HIDE_OFFSET = @import("app_state.zig").SEARCH_SIDEBAR_HIDE_OFFSET;
const SEARCH_TABSORT_INBOX_OFFSET = @import("app_state.zig").SEARCH_TABSORT_INBOX_OFFSET;
const SEARCH_TABSORT_MANUAL_OFFSET = @import("app_state.zig").SEARCH_TABSORT_MANUAL_OFFSET;
const SEARCH_UNREADONLY_OFFSET = @import("app_state.zig").SEARCH_UNREADONLY_OFFSET;
const SEARCH_THREADTITLE_OFFSET = @import("app_state.zig").SEARCH_THREADTITLE_OFFSET;
const SEARCH_FONT_BIGGER_OFFSET = @import("app_state.zig").SEARCH_FONT_BIGGER_OFFSET;
const SEARCH_FONT_SMALLER_OFFSET = @import("app_state.zig").SEARCH_FONT_SMALLER_OFFSET;
const SEARCH_FONT_RESET_OFFSET = @import("app_state.zig").SEARCH_FONT_RESET_OFFSET;
const SEARCH_UI_BIGGER_OFFSET = @import("app_state.zig").SEARCH_UI_BIGGER_OFFSET;
const SEARCH_UI_SMALLER_OFFSET = @import("app_state.zig").SEARCH_UI_SMALLER_OFFSET;
const SEARCH_UI_RESET_OFFSET = @import("app_state.zig").SEARCH_UI_RESET_OFFSET;
const SEARCH_CUSTOMCMD_EDIT_OFFSET = @import("app_state.zig").SEARCH_CUSTOMCMD_EDIT_OFFSET;
const SEARCH_CUSTOMCMD_RELOAD_OFFSET = @import("app_state.zig").SEARCH_CUSTOMCMD_RELOAD_OFFSET;
const SEARCH_ARCHIVE_OFFSET = @import("app_state.zig").SEARCH_ARCHIVE_OFFSET;
const SEARCH_REOPEN_OFFSET = @import("app_state.zig").SEARCH_REOPEN_OFFSET;
const SEARCH_URLPICK_OFFSET = @import("app_state.zig").SEARCH_URLPICK_OFFSET;
const SEARCH_CLOSETAB_OFFSET = @import("app_state.zig").SEARCH_CLOSETAB_OFFSET;
const SEARCH_MUTETAB_OFFSET = @import("app_state.zig").SEARCH_MUTETAB_OFFSET;
const SEARCH_KEEPALIVE_OFFSET = @import("app_state.zig").SEARCH_KEEPALIVE_OFFSET;
const SEARCH_BROWSER_TOGGLE_OFFSET = @import("app_state.zig").SEARCH_BROWSER_TOGGLE_OFFSET;
const SEARCH_BROWSER_URL_OFFSET = @import("app_state.zig").SEARCH_BROWSER_URL_OFFSET;
const SEARCH_BROWSER_INSTRUCT_OFFSET = @import("app_state.zig").SEARCH_BROWSER_INSTRUCT_OFFSET;
const SEARCH_BROWSER_FOCUS_URL_OFFSET = @import("app_state.zig").SEARCH_BROWSER_FOCUS_URL_OFFSET;
const SEARCH_BROWSER_FOCUS_TOGGLE_OFFSET = @import("app_state.zig").SEARCH_BROWSER_FOCUS_TOGGLE_OFFSET;
const SEARCH_EXTERNAL_BROWSER_LINKS_OFFSET = @import("app_state.zig").SEARCH_EXTERNAL_BROWSER_LINKS_OFFSET;
const SEARCH_BROWSER_AUTOSUSPEND_OFFSET = @import("app_state.zig").SEARCH_BROWSER_AUTOSUSPEND_OFFSET;
const SEARCH_CHANGELOG_OFFSET = @import("app_state.zig").SEARCH_CHANGELOG_OFFSET;
const SEARCH_BROWSER_BACK_OFFSET = @import("app_state.zig").SEARCH_BROWSER_BACK_OFFSET;
const SEARCH_BROWSER_FORWARD_OFFSET = @import("app_state.zig").SEARCH_BROWSER_FORWARD_OFFSET;
const SEARCH_BROWSER_MODE_OFFSET = @import("app_state.zig").SEARCH_BROWSER_MODE_OFFSET;
const SEARCH_UPDATE_OFFSET = @import("app_state.zig").SEARCH_UPDATE_OFFSET;
const SEARCH_RESTART_OFFSET = @import("app_state.zig").SEARCH_RESTART_OFFSET;
const SEARCH_ZSB_REBIND_OFFSET = @import("app_state.zig").SEARCH_ZSB_REBIND_OFFSET;
const SEARCH_SHELL_DIAG_OFFSET = @import("app_state.zig").SEARCH_SHELL_DIAG_OFFSET;
const SEARCH_SYNC_NAME_OFFSET = @import("app_state.zig").SEARCH_SYNC_NAME_OFFSET;
const SEARCH_RENAME_SYNC_OFFSET = @import("app_state.zig").SEARCH_RENAME_SYNC_OFFSET;
const SEARCH_END_TMUX_OFFSET = @import("app_state.zig").SEARCH_END_TMUX_OFFSET;
const SEARCH_REMIND_ME_OFFSET = @import("app_state.zig").SEARCH_REMIND_ME_OFFSET;
const SEARCH_WS_SNOOZE_OFFSET = @import("app_state.zig").SEARCH_WS_SNOOZE_OFFSET;
const SEARCH_WS_SNOOZED_OFFSET = @import("app_state.zig").SEARCH_WS_SNOOZED_OFFSET;
const SEARCH_WS_BRINGBACK_OFFSET = @import("app_state.zig").SEARCH_WS_BRINGBACK_OFFSET;
const SEARCH_WS_SNOOZED_ROW_OFFSET = @import("app_state.zig").SEARCH_WS_SNOOZED_ROW_OFFSET;
const SEARCH_REMINDERS_MENU_OFFSET = @import("app_state.zig").SEARCH_REMINDERS_MENU_OFFSET;
const SEARCH_GROUPMOVE_MENU_OFFSET = @import("app_state.zig").SEARCH_GROUPMOVE_MENU_OFFSET;
const SEARCH_GROUPMOVE_BACK_OFFSET = @import("app_state.zig").SEARCH_GROUPMOVE_BACK_OFFSET;
const SEARCH_GROUPMOVE_NEW_OFFSET = @import("app_state.zig").SEARCH_GROUPMOVE_NEW_OFFSET;
const SEARCH_GROUPMOVE_NONE_OFFSET = @import("app_state.zig").SEARCH_GROUPMOVE_NONE_OFFSET;
const SEARCH_CHAT_VIEW_OFFSET = @import("app_state.zig").SEARCH_CHAT_VIEW_OFFSET;
const SEARCH_CHAT_ALLOW_OFFSET = @import("app_state.zig").SEARCH_CHAT_ALLOW_OFFSET;
const SEARCH_CHAT_ALWAYS_OFFSET = @import("app_state.zig").SEARCH_CHAT_ALWAYS_OFFSET;
const SEARCH_CHAT_DENY_OFFSET = @import("app_state.zig").SEARCH_CHAT_DENY_OFFSET;
const SEARCH_CHAT_STOP_OFFSET = @import("app_state.zig").SEARCH_CHAT_STOP_OFFSET;
const SEARCH_MULTIPROMPT_LOGIN_OFFSET = @import("app_state.zig").SEARCH_MULTIPROMPT_LOGIN_OFFSET;
const SEARCH_SYNC_SIGNOUT_OFFSET = @import("app_state.zig").SEARCH_SYNC_SIGNOUT_OFFSET;
const SEARCH_LAYOUT_PULL_OFFSET = @import("app_state.zig").SEARCH_LAYOUT_PULL_OFFSET;
const SEARCH_SYNC_STATUS_OFFSET = @import("app_state.zig").SEARCH_SYNC_STATUS_OFFSET;
const SEARCH_APPROVE_DEVICES_OFFSET = @import("app_state.zig").SEARCH_APPROVE_DEVICES_OFFSET;
const SEARCH_REMOVE_SERVER_1_OFFSET = @import("app_state.zig").SEARCH_REMOVE_SERVER_1_OFFSET;
const SEARCH_REMOVE_SERVER_2_OFFSET = @import("app_state.zig").SEARCH_REMOVE_SERVER_2_OFFSET;
const SEARCH_REMOVE_SERVER_3_OFFSET = @import("app_state.zig").SEARCH_REMOVE_SERVER_3_OFFSET;
const SEARCH_SKILLS_MENU_OFFSET = @import("app_state.zig").SEARCH_SKILLS_MENU_OFFSET;
const SEARCH_SKILLS_BACK_OFFSET = @import("app_state.zig").SEARCH_SKILLS_BACK_OFFSET;
const SEARCH_KEEPAWAKE_OFFSET = @import("app_state.zig").SEARCH_KEEPAWAKE_OFFSET;
const SEARCH_CRASH_REPORTS_OFFSET = @import("app_state.zig").SEARCH_CRASH_REPORTS_OFFSET;
const SEARCH_CRASH_NOW_OFFSET = @import("app_state.zig").SEARCH_CRASH_NOW_OFFSET;
const SEARCH_HIBERNATE_NOW_OFFSET = @import("app_state.zig").SEARCH_HIBERNATE_NOW_OFFSET;
const SEARCH_CLOSE_ALL_BROWSER_PANES_OFFSET = @import("app_state.zig").SEARCH_CLOSE_ALL_BROWSER_PANES_OFFSET;
const SEARCH_INBOX_EXCLUDE_OFFSET = @import("app_state.zig").SEARCH_INBOX_EXCLUDE_OFFSET;
const SEARCH_REMIND_PRESET_OFFSET = @import("app_state.zig").SEARCH_REMIND_PRESET_OFFSET;
const SEARCH_GROUPMOVE_GROUP_OFFSET = @import("app_state.zig").SEARCH_GROUPMOVE_GROUP_OFFSET;
const SEARCH_POWER_AUTO_OFFSET = @import("app_state.zig").SEARCH_POWER_AUTO_OFFSET;
const SEARCH_POWER_ALWAYS_OFFSET = @import("app_state.zig").SEARCH_POWER_ALWAYS_OFFSET;
const SEARCH_POWER_OFF_OFFSET = @import("app_state.zig").SEARCH_POWER_OFF_OFFSET;
const SEARCH_FAVORITE_OFFSET = @import("app_state.zig").SEARCH_FAVORITE_OFFSET;
const SEARCH_LADDER_AUTO_OFFSET = @import("app_state.zig").SEARCH_LADDER_AUTO_OFFSET;
const SEARCH_LADDER_CLAUDE_OFFSET = @import("app_state.zig").SEARCH_LADDER_CLAUDE_OFFSET;
const SEARCH_LADDER_CODEX_OFFSET = @import("app_state.zig").SEARCH_LADDER_CODEX_OFFSET;
const SEARCH_LADDER_DASH_OFFSET = @import("app_state.zig").SEARCH_LADDER_DASH_OFFSET;
const SEARCH_VOICE_MODE_ON_OFFSET = @import("app_state.zig").SEARCH_VOICE_MODE_ON_OFFSET;
const SEARCH_VOICE_MODE_OFF_OFFSET = @import("app_state.zig").SEARCH_VOICE_MODE_OFF_OFFSET;
const SEARCH_ETA_NUMBERS_OFFSET = @import("app_state.zig").SEARCH_ETA_NUMBERS_OFFSET;
const SEARCH_ETA_PROGRESS_OFFSET = @import("app_state.zig").SEARCH_ETA_PROGRESS_OFFSET;
const SEARCH_ETA_ACCURACY_OFFSET = @import("app_state.zig").SEARCH_ETA_ACCURACY_OFFSET;
const SEARCH_CHAT_VIEW_MODE_EVERYWHERE_OFFSET = @import("app_state.zig").SEARCH_CHAT_VIEW_MODE_EVERYWHERE_OFFSET;
const SEARCH_CHAT_VIEW_MODE_NOWHERE_OFFSET = @import("app_state.zig").SEARCH_CHAT_VIEW_MODE_NOWHERE_OFFSET;
const SEARCH_VOICE_ALWAYS_ON_OFFSET = @import("app_state.zig").SEARCH_VOICE_ALWAYS_ON_OFFSET;
const SEARCH_VOICE_ALWAYS_OFF_OFFSET = @import("app_state.zig").SEARCH_VOICE_ALWAYS_OFF_OFFSET;
const SEARCH_VOICE_STOP_OFFSET = @import("app_state.zig").SEARCH_VOICE_STOP_OFFSET;
const SEARCH_VOICE_SPEED_100_OFFSET = @import("app_state.zig").SEARCH_VOICE_SPEED_100_OFFSET;
const SEARCH_VOICE_SPEED_125_OFFSET = @import("app_state.zig").SEARCH_VOICE_SPEED_125_OFFSET;
const SEARCH_VOICE_SPEED_140_OFFSET = @import("app_state.zig").SEARCH_VOICE_SPEED_140_OFFSET;
const SEARCH_VOICE_SPEED_150_OFFSET = @import("app_state.zig").SEARCH_VOICE_SPEED_150_OFFSET;
const SEARCH_VOICE_PREVIOUS_OFFSET = @import("app_state.zig").SEARCH_VOICE_PREVIOUS_OFFSET;
const SEARCH_VOICE_NEXT_OFFSET = @import("app_state.zig").SEARCH_VOICE_NEXT_OFFSET;
const SEARCH_CHAT_REPLY_OFFSET = @import("app_state.zig").SEARCH_CHAT_REPLY_OFFSET;
const SEARCH_CLEAN_CHAT_OFFSET = @import("app_state.zig").SEARCH_CLEAN_CHAT_OFFSET;
const SEARCH_CHAT_TODO_OFFSET = @import("app_state.zig").SEARCH_CHAT_TODO_OFFSET;
const SEARCH_CHAT_TOOL_STEPS_OFFSET = @import("app_state.zig").SEARCH_CHAT_TOOL_STEPS_OFFSET;
const SEARCH_CHAT_NEWEST_OFFSET = @import("app_state.zig").SEARCH_CHAT_NEWEST_OFFSET;
const SEARCH_CHAT_MORE_MENU_OFFSET = @import("app_state.zig").SEARCH_CHAT_MORE_MENU_OFFSET;
const SEARCH_CHAT_RESYNC_OFFSET = @import("app_state.zig").SEARCH_CHAT_RESYNC_OFFSET;
const SEARCH_CHAT_FIND_OFFSET = @import("app_state.zig").SEARCH_CHAT_FIND_OFFSET;
const SEARCH_CHAT_COPY_CODE_OFFSET = @import("app_state.zig").SEARCH_CHAT_COPY_CODE_OFFSET;
const SEARCH_CHAT_COPY_SELECTION_OFFSET = @import("app_state.zig").SEARCH_CHAT_COPY_SELECTION_OFFSET;
const SEARCH_CHAT_FOCUS_MESSAGES_OFFSET = @import("app_state.zig").SEARCH_CHAT_FOCUS_MESSAGES_OFFSET;
const SEARCH_CHAT_SELECT_ALL_OFFSET = @import("app_state.zig").SEARCH_CHAT_SELECT_ALL_OFFSET;
const SEARCH_CHAT_AC_OFFSET = @import("app_state.zig").SEARCH_CHAT_AC_OFFSET;
const SEARCH_CHAT_QUEUE_SEND_OFFSET = @import("app_state.zig").SEARCH_CHAT_QUEUE_SEND_OFFSET;
const SEARCH_CHAT_RESET_OFFSET = @import("app_state.zig").SEARCH_CHAT_RESET_OFFSET;
const SEARCH_CHAT_TAB_URL_OFFSET = @import("app_state.zig").SEARCH_CHAT_TAB_URL_OFFSET;
const SEARCH_CHAT_QUEUE_CLEAR_OFFSET = @import("app_state.zig").SEARCH_CHAT_QUEUE_CLEAR_OFFSET;
const SEARCH_CHAT_RETRY_UNSENT_OFFSET = @import("app_state.zig").SEARCH_CHAT_RETRY_UNSENT_OFFSET;
const SEARCH_CHAT_DISCARD_UNSENT_OFFSET = @import("app_state.zig").SEARCH_CHAT_DISCARD_UNSENT_OFFSET;
const SEARCH_CHAT_PUSH_QUEUED_OFFSET = @import("app_state.zig").SEARCH_CHAT_PUSH_QUEUED_OFFSET;
const SEARCH_CHAT_EDIT_QUEUED_OFFSET = @import("app_state.zig").SEARCH_CHAT_EDIT_QUEUED_OFFSET;
const SEARCH_VOICE_REPLAY_OFFSET = @import("app_state.zig").SEARCH_VOICE_REPLAY_OFFSET;
const REMIND_PRESET_COUNT = @import("app_state.zig").REMIND_PRESET_COUNT;
const SEARCH_CODEX_TMUX_OFFSET = @import("app_state.zig").SEARCH_CODEX_TMUX_OFFSET;
const SEARCH_SNIPPETS_MENU_OFFSET = @import("app_state.zig").SEARCH_SNIPPETS_MENU_OFFSET;
const SEARCH_SNIPPET_MANAGE_OFFSET = @import("app_state.zig").SEARCH_SNIPPET_MANAGE_OFFSET;
const SEARCH_SNIPPET_CREATE_OFFSET = @import("app_state.zig").SEARCH_SNIPPET_CREATE_OFFSET;
const SEARCH_SNIPPET_BACK_OFFSET = @import("app_state.zig").SEARCH_SNIPPET_BACK_OFFSET;
const SEARCH_SNIPPET_OFFSET = @import("app_state.zig").SEARCH_SNIPPET_OFFSET;
const SEARCH_SESSION_OVERVIEW_MENU_OFFSET = @import("app_state.zig").SEARCH_SESSION_OVERVIEW_MENU_OFFSET;
const SEARCH_ARCHIVED_VIEW_OFFSET = @import("app_state.zig").SEARCH_ARCHIVED_VIEW_OFFSET;
const SEARCH_BROWSER_SHOTURL_OFFSET = @import("app_state.zig").SEARCH_BROWSER_SHOTURL_OFFSET;
const SEARCH_PIN_TOP_OFFSET = @import("app_state.zig").SEARCH_PIN_TOP_OFFSET;
const SEARCH_UNARCHIVE_HIDDEN_OFFSET = @import("app_state.zig").SEARCH_UNARCHIVE_HIDDEN_OFFSET;
const SEARCH_UNARCHIVE_UNATTACHED_OFFSET = @import("app_state.zig").SEARCH_UNARCHIVE_UNATTACHED_OFFSET;
const SEARCH_BROWSER_ENGINE_OFFSET = @import("app_state.zig").SEARCH_BROWSER_ENGINE_OFFSET;
const SEARCH_USAGE_LOGIN_PRIMARY_OFFSET = @import("app_state.zig").SEARCH_USAGE_LOGIN_PRIMARY_OFFSET;
const SEARCH_USAGE_LOGIN_INNE_OFFSET = @import("app_state.zig").SEARCH_USAGE_LOGIN_INNE_OFFSET;
const SEARCH_CUSTOMCMD_OFFSET = @import("app_state.zig").SEARCH_CUSTOMCMD_OFFSET;
const SEARCH_WORKSPACE_BACK_OFFSET = @import("app_state.zig").SEARCH_WORKSPACE_BACK_OFFSET;
const SEARCH_WORKSPACE_DELETE_OFFSET = @import("app_state.zig").SEARCH_WORKSPACE_DELETE_OFFSET;
const SEARCH_WSSORT_OFFSET = @import("app_state.zig").SEARCH_WSSORT_OFFSET;
const SEARCH_WSMOVE_OFFSET = @import("app_state.zig").SEARCH_WSMOVE_OFFSET;
const SEARCH_WSMOVE_NEW_OFFSET = @import("app_state.zig").SEARCH_WSMOVE_NEW_OFFSET;
const SEARCH_WORKSPACE_OFFSET = @import("app_state.zig").SEARCH_WORKSPACE_OFFSET;
const SEARCH_RENAMEWIN_OFFSET = @import("app_state.zig").SEARCH_RENAMEWIN_OFFSET;
const SEARCH_TABCTX_BACK = @import("app_state.zig").SEARCH_TABCTX_BACK;
const SEARCH_TABCTX_START_SESSION = @import("app_state.zig").SEARCH_TABCTX_START_SESSION;
const SEARCH_TABCTX_RECONNECT = @import("app_state.zig").SEARCH_TABCTX_RECONNECT;
const SEARCH_TABCTX_MUTE = @import("app_state.zig").SEARCH_TABCTX_MUTE;
const SEARCH_TABCTX_KEEPALIVE = @import("app_state.zig").SEARCH_TABCTX_KEEPALIVE;
const SEARCH_TABCTX_WSMOVE = @import("app_state.zig").SEARCH_TABCTX_WSMOVE;
const SEARCH_TABCTX_GROUP_NEW = @import("app_state.zig").SEARCH_TABCTX_GROUP_NEW;
const SEARCH_TABCTX_GROUP_REMOVE = @import("app_state.zig").SEARCH_TABCTX_GROUP_REMOVE;
const SEARCH_TABCTX_GROUP_NEW_TAB_IN = @import("app_state.zig").SEARCH_TABCTX_GROUP_NEW_TAB_IN;
const SEARCH_TABCTX_MOVE_NEW_WS = @import("app_state.zig").SEARCH_TABCTX_MOVE_NEW_WS;
const SEARCH_TABCTX_CLEAR_SEL = @import("app_state.zig").SEARCH_TABCTX_CLEAR_SEL;
const SEARCH_TABCTX_ARCHIVE = @import("app_state.zig").SEARCH_TABCTX_ARCHIVE;
const SEARCH_TABCTX_BROWSER = @import("app_state.zig").SEARCH_TABCTX_BROWSER;
const SEARCH_TABCTX_END_TMUX = @import("app_state.zig").SEARCH_TABCTX_END_TMUX;
const SEARCH_TABCTX_PIN_TOP = @import("app_state.zig").SEARCH_TABCTX_PIN_TOP;
const SEARCH_TABCTX_KEEPAWAKE = @import("app_state.zig").SEARCH_TABCTX_KEEPAWAKE;
const SEARCH_TABCTX_INBOX_EXCLUDE = @import("app_state.zig").SEARCH_TABCTX_INBOX_EXCLUDE;
const SEARCH_TABCTX_CHAT_RESET = @import("app_state.zig").SEARCH_TABCTX_CHAT_RESET;
const SEARCH_TABCTX_CHAT_ALLOW = @import("app_state.zig").SEARCH_TABCTX_CHAT_ALLOW;
const SEARCH_TABCTX_CHAT_ALWAYS = @import("app_state.zig").SEARCH_TABCTX_CHAT_ALWAYS;
const SEARCH_TABCTX_CHAT_DENY = @import("app_state.zig").SEARCH_TABCTX_CHAT_DENY;
const SEARCH_TABCTX_CHAT_STOP = @import("app_state.zig").SEARCH_TABCTX_CHAT_STOP;
const SEARCH_TABCTX_CHAT_TAB_URL = @import("app_state.zig").SEARCH_TABCTX_CHAT_TAB_URL;
const SEARCH_TABCTX_FAVORITE = @import("app_state.zig").SEARCH_TABCTX_FAVORITE;
const SEARCH_TABCTX_GROUP_ADD_OFFSET = @import("app_state.zig").SEARCH_TABCTX_GROUP_ADD_OFFSET;
const SEARCH_MOBILE_OFFSET = @import("app_state.zig").SEARCH_MOBILE_OFFSET;
const SEARCH_ADDFAVICON_OFFSET = @import("app_state.zig").SEARCH_ADDFAVICON_OFFSET;
const SEARCH_ARCHIVED_OFFSET = @import("app_state.zig").SEARCH_ARCHIVED_OFFSET;
const SEARCH_REMINDER_ROW_OFFSET = @import("app_state.zig").SEARCH_REMINDER_ROW_OFFSET;
const MAX_SESSION_OVERVIEW_SEARCH_ROWS = @import("app_state.zig").MAX_SESSION_OVERVIEW_SEARCH_ROWS;
const SEARCH_SESSION_OVERVIEW_ROW_OFFSET = @import("app_state.zig").SEARCH_SESSION_OVERVIEW_ROW_OFFSET;
const SEARCH_SKILL_ROW_OFFSET = @import("app_state.zig").SEARCH_SKILL_ROW_OFFSET;
const MAX_PALETTE_SKILLS = @import("app_state.zig").MAX_PALETTE_SKILLS;
const MAX_SNIPPETS = @import("app_state.zig").MAX_SNIPPETS;
const MAX_WORKSPACES = @import("app_state.zig").MAX_WORKSPACES;
const findMyWorkspaceSlot = @import("workspaces.zig").findMyWorkspaceSlot;
const workspaceIsLiveAnywhere = @import("workspaces.zig").workspaceIsLiveAnywhere;
const debugLog = @import("diagnostics.zig").debugLog;
const saveSession = @import("session.zig").saveSession;
const SavedTab = @import("app_state.zig").SavedTab;
const TMUX_HOST_UK = @import("app_state.zig").TMUX_HOST_UK;
const TMUX_HOST_INNE = @import("app_state.zig").TMUX_HOST_INNE;
const VoiceSpeed = @import("app_state.zig").VoiceSpeed;
const voiceSpeedLabel = @import("voice.zig").voiceSpeedLabel;
const loadArchiveIfNeeded = @import("archive.zig").loadArchiveIfNeeded;
const MAX_REMINDERS = @import("app_state.zig").MAX_REMINDERS;
const loadRemindersIfNeeded = @import("reminders.zig").loadRemindersIfNeeded;
const workspaceWakeLabel = @import("reminders.zig").workspaceWakeLabel;
const reminderDueLabel = @import("reminders.zig").reminderDueLabel;
const remindPresetLabel = @import("reminders.zig").remindPresetLabel;
const remindPresetHint = @import("reminders.zig").remindPresetHint;
const activeRemoteContextForCodexTmux = @import("command_palette.zig").activeRemoteContextForCodexTmux;
const paletteHeaderIndex = @import("command_palette.zig").paletteHeaderIndex;
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;
const sessionOverviewKindLabel = @import("archive.zig").sessionOverviewKindLabel;
const drawAttentionDot = @import("archive.zig").drawAttentionDot;
const drawFavoriteDot = @import("archive.zig").drawFavoriteDot;
const FAVORITE_DOT_D = @import("archive.zig").FAVORITE_DOT_D;
const paintAllSessions = @import("archive.zig").paintAllSessions;
const sidebarContentH = @import("console.zig").sidebarContentH;
const sidebarVisibleH = @import("console.zig").sidebarVisibleH;
const clampSidebarScroll = @import("console.zig").clampSidebarScroll;
const switchToShell = @import("console.zig").switchToShell;
const workspaceDisplayName = @import("workspaces.zig").workspaceDisplayName;
const recordShellDiagEvent = @import("workspaces.zig").recordShellDiagEvent;
const foregroundIsOurs = @import("focus.zig").foregroundIsOurs;
const activeBrowserSurfaceHasForegroundFocus = @import("browser_pane.zig").activeBrowserSurfaceHasForegroundFocus;
const calcBrowserLayout = @import("browser_pane.zig").calcBrowserLayout;
const wakeBrowserPaneFromFreeze = @import("browser_pane.zig").wakeBrowserPaneFromFreeze;
const paletteAnchoredBesideBrowser = @import("browser_pane.zig").paletteAnchoredBesideBrowser;
const chatDraftHasForShell = @import("chat_composer.zig").chatDraftHasForShell;
const chatViewLayout = @import("chat_composer.zig").chatViewLayout;
const SEARCH_CHAT_ATTACH_OFFSET = @import("app_state.zig").SEARCH_CHAT_ATTACH_OFFSET;
const SEARCH_CHAT_DICTATION_OFFSET = @import("app_state.zig").SEARCH_CHAT_DICTATION_OFFSET;
const invalidateSidebar = @import("window_layout.zig").invalidateSidebar;
const SHORTCUT_ROWS = @import("shortcuts.zig").SHORTCUT_ROWS;
const drawAscii = @import("drawing.zig").drawAscii;
const drawModalShadow = @import("drawing.zig").drawModalShadow;
const paintSnippetCreateForm = @import("snippets.zig").paintSnippetCreateForm;
const paintChangelogOverlay = @import("changelog.zig").paintChangelogOverlay;
const uiScaled = @import("drawing.zig").uiScaled;
const searchRowH = @import("drawing.zig").searchRowH;
const searchInputH = @import("drawing.zig").searchInputH;
const searchOverlayW = @import("drawing.zig").searchOverlayW;
const searchOverlayOx = @import("drawing.zig").searchOverlayOx;
const CreateFontW = @import("fonts.zig").create;
const paletteDrawText = @import("palette_text.zig").draw;
const uiFontTitle = @import("drawing.zig").uiFontTitle;
const uiFontShellTabTitle = @import("drawing.zig").uiFontShellTabTitle;
const uiFontSubtitle = @import("drawing.zig").uiFontSubtitle;
const uiFontStatusCard = @import("drawing.zig").uiFontStatusCard;
const uiFontClose = @import("drawing.zig").uiFontClose;
const drawAgentIcon = @import("drawing.zig").drawAgentIcon;
const paintThreadTitle = @import("drawing.zig").paintThreadTitle;
const threadTitleHeight = @import("browser_pane.zig").threadTitleHeight;
const paintWorkspaceStrip = @import("drawing.zig").paintWorkspaceStrip;
const paintSidebarStickyStatusCard = @import("telemetry_panel.zig").paintSidebarStickyStatusCard;
const paintSidebarStatusCardPopup = @import("telemetry_panel.zig").paintSidebarStatusCardPopup;
const stopSpinnerTimerIfIdle = @import("clipboard.zig").stopSpinnerTimerIfIdle;
const ReadConsoleOutputCharacterW = @import("win32.zig").ReadConsoleOutputCharacterW;
const asciiToWideZ = @import("voice.zig").asciiToWideZ;
const etaRemainingMs = @import("notifications.zig").etaRemainingMs;
const etaElapsedMs = @import("notifications.zig").etaElapsedMs;
const etaOverdueColor = @import("notifications.zig").etaOverdueColor;
const formatEtaRemaining = @import("notifications.zig").formatEtaRemaining;
const etaFillFraction = @import("notifications.zig").etaFillFraction;
const nowFileTime = @import("inbox.zig").nowFileTime;
const writeUintTo = @import("inbox.zig").writeUintTo;
const asciiToU16 = @import("inbox.zig").asciiToU16;
const publishInboxState = @import("inbox.zig").publishInboxState;
const publishInboxStateNow = @import("inbox.zig").publishInboxStateNow;
const inboxNextRowFromContext = @import("inbox.zig").inboxNextRowFromContext;
const findShellById = @import("inbox.zig").findShellById;
const paintInbox = @import("inbox.zig").paintInbox;
const jumpToInboxRow = @import("inbox.zig").jumpToInboxRow;
const rememberInboxArchiveUndo = @import("inbox.zig").rememberInboxArchiveUndo;
const u16SliceEql = @import("shell_poll.zig").u16SliceEql;
const lineLooksLikeAiIdlePrompt = @import("shell_poll.zig").lineLooksLikeAiIdlePrompt;
const lineLooksLikeAiWorking = @import("shell_poll.zig").lineLooksLikeAiWorking;
const lineLooksLikeGenericTmuxStatusPreview = @import("shell_poll.zig").lineLooksLikeGenericTmuxStatusPreview;
const shellProcessAliveForRead = @import("shell_poll.zig").shellProcessAliveForRead;

pub fn stickyFind(sid: u32) ?u32 {
    var i: u32 = 0;
    while (i < app_state.g_sticky_n) : (i += 1) if (app_state.g_sticky[i].sid == sid) return i;
    return null;
}
pub fn stickyAddFromShell(idx: u32) void {
    if (stickyFind(app_state.shells[idx].shell_id) != null) return;
    if (app_state.g_sticky_n >= MAX_SHELLS) return;
    app_state.g_sticky[app_state.g_sticky_n] = .{
        .sid = app_state.shells[idx].shell_id,
        .att = app_state.shells[idx].needs_attention,
        .active = app_state.shells[idx].activity == .active,
        .la = app_state.shells[idx].last_active,
    };
    app_state.g_sticky_n += 1;
}
pub fn stickyResetToShell(idx: u32) void {
    app_state.g_sticky_n = 0;
    stickyAddFromShell(idx);
}
pub fn stickyRemove(sid: u32) void {
    if (stickyFind(sid)) |i| {
        var j = i;
        while (j + 1 < app_state.g_sticky_n) : (j += 1) app_state.g_sticky[j] = app_state.g_sticky[j + 1];
        app_state.g_sticky_n -= 1;
    }
}

pub fn findGroupIdx(gid: u32) ?u32 {
    if (gid == 0) return null;
    for (0..app_state.group_count) |gi| {
        if (app_state.groups[gi].id == gid) return @intCast(gi);
    }
    return null;
}

fn displayedGroupColor(gidx: u32) DWORD {
    if (gidx < app_state.group_count and app_state.groups[gidx].color_set) return GROUP_COLORS[app_state.groups[gidx].color % GROUP_COLORS.len];
    return customColorOr("muted", if (app_state.g_light_theme) RGB(130, 134, 140) else RGB(145, 149, 157));
}

pub fn tintColor(base: DWORD, color: DWORD, num: u32, den: u32) DWORD {
    const br = base & 0xFF;
    const bg = (base >> 8) & 0xFF;
    const bb = (base >> 16) & 0xFF;
    const cr = color & 0xFF;
    const cg = (color >> 8) & 0xFF;
    const cb = (color >> 16) & 0xFF;
    const keep = den - num;
    const r: u32 = (br * keep + cr * num) / den;
    const g: u32 = (bg * keep + cg * num) / den;
    const b: u32 = (bb * keep + cb * num) / den;
    return RGB(@intCast(@min(r, @as(u32, 255))), @intCast(@min(g, @as(u32, 255))), @intCast(@min(b, @as(u32, 255))));
}

fn tabPassesUnreadFilter(i: usize) bool {
    if (app_state.shells[i].inbox_archived and !app_state.shells[i].needs_attention and i != app_state.active_shell) return false;
    return !app_state.g_unread_only or app_state.shells[i].needs_attention or i == app_state.active_shell;
}

pub fn isTabHidden(idx: u32) bool {
    if (idx >= app_state.shell_count) return false;
    if (app_state.g_starred_workspace and !@import("workspaces.zig").starredShellVisible(idx)) return true;
    if (!app_state.g_starred_workspace and app_state.g_single_window and (app_state.shells[idx].workspace != app_state.g_active_workspace or app_state.g_ws_snoozed[app_state.shells[idx].workspace])) return true;
    if (!app_state.g_starred_workspace and app_state.shells[idx].inbox_archived and !app_state.shells[idx].needs_attention and idx != app_state.active_shell) return true;
    if (!app_state.g_starred_workspace and !tabPassesUnreadFilter(idx)) return true;
    const gid = tabGroupId(idx);
    if (gid == 0) return false;
    if (findGroupIdx(gid)) |gi| return app_state.groups[gi].collapsed;
    return false;
}

pub fn findNextVisibleTab(from: u32, dir: i32) ?u32 {
    if (app_state.shell_count == 0) return null;

    if (app_state.g_tab_sort_auto) {
        var rows: [MAX_ROWS]Row = undefined;
        const rn = layoutRows(&rows);
        var vis: [MAX_SHELLS]u32 = undefined;
        var vc: u32 = 0;
        for (0..rn) |ri| {
            if (rows[ri].kind == .tab and vc < MAX_SHELLS) {
                vis[vc] = rows[ri].shell_idx;
                vc += 1;
            }
        }
        if (vc == 0) return null;
        var cur: ?u32 = null;
        for (0..vc) |vi| {
            if (vis[vi] == from) {
                cur = @intCast(vi);
                break;
            }
        }
        const c = cur orelse return vis[0];
        var step: u32 = 1;
        while (step < vc) : (step += 1) {
            const ni: u32 = if (dir > 0)
                (c + step) % vc
            else
                (c + vc - (step % vc)) % vc;
            const idx = vis[ni];
            if (!isTabHidden(idx)) return idx;
        }
        return null;
    }

    var step: u32 = 1;
    while (step <= app_state.shell_count) : (step += 1) {
        const idx: u32 = if (dir > 0)
            (from + step) % app_state.shell_count
        else blk: {
            const back: u32 = step % app_state.shell_count;
            break :blk (from + app_state.shell_count - back) % app_state.shell_count;
        };
        if (!isTabHidden(idx)) return idx;
    }
    return null;
}

pub fn readArchiveContent(i: usize) ?archive_rules.Content {
    if (i >= app_state.shell_count or app_state.shells[i].pid == 0 or !shellProcessAliveForRead(i)) return null;
    _ = FreeConsole();
    if (AttachConsole(app_state.shells[i].pid) == 0) return null;
    defer _ = FreeConsole();
    const handle = GetStdHandle(STD_OUTPUT_HANDLE);
    if (handle == null) return null;
    var info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (GetConsoleScreenBufferInfo(handle, &info) == 0) return null;
    const win = info.srWindow;
    const width: u32 = @intCast(win.right - win.left + 1);
    var content = archive_rules.Content{};
    var line_buf: [256]u16 = undefined;
    var scanned: u32 = 0;
    var ry: i16 = win.bottom;
    while (ry >= win.top and scanned < 64) : (ry -= 1) {
        scanned += 1;
        var chars_read: DWORD = 0;
        if (ReadConsoleOutputCharacterW(handle, &line_buf, @min(width, 256), .{ .x = win.left, .y = ry }, &chars_read) == 0) continue;
        const line = line_buf[0..@intCast(chars_read)];
        content.add(line, (ry == win.bottom and app_state.shells[i].kind == .tmux) or lineLooksLikeGenericTmuxStatusPreview(&app_state.shells[i], line), lineLooksLikeAiIdlePrompt(line), lineLooksLikeAiWorking(line));
    }
    return content;
}

pub fn recordInboxArchive(i: usize) bool {
    if (i >= app_state.shell_count or @import("archive.zig").rejectPinnedSessionClose(i)) return false;
    const content = readArchiveContent(i);
    app_state.shells[i].archive_content = content orelse .{};
    app_state.shells[i].archive_content_valid = content != null;
    app_state.shells[i].archive_time = nowFileTime();
    app_state.shells[i].archive_done = app_state.shells[i].last_done_time;
    app_state.shells[i].archive_active = 0;
    app_state.shells[i].inbox_archived = true;
    return true;
}

pub fn archiveHasNewContentSnapshot(shell: *const Shell, content: *const archive_rules.Content) bool {
    return shell.archive_content_valid and archive_rules.returnReason(shell.archive_time, shell.archive_done, shell.archive_active, &shell.archive_content, content) != .none;
}

pub fn archiveHasNewContent(i: usize) bool {
    const content = readArchiveContent(i) orelse return false;
    if (!app_state.shells[i].archive_content_valid) {
        app_state.shells[i].archive_content = content;
        app_state.shells[i].archive_content_valid = true;
        saveSession();
        return false;
    }
    return archiveHasNewContentSnapshot(&app_state.shells[i], &content);
}

pub fn logUnarchive(i: usize, reason: []const u8) void {
    var buf: [180]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "unarchive shell_id={d} reason={s}", .{ app_state.shells[i].shell_id, reason }) catch return;
    debugLog(msg);
}

pub fn writeArchiveMarkers(out: []u8, shell: *const Shell) usize {
    var pos: usize = 0;
    const pre = ",\"archive_time\":";
    @memcpy(out[pos .. pos + pre.len], pre);
    pos += pre.len;
    pos += writeUintTo(out[pos..], shell.archive_time);
    const done = ",\"archive_done\":";
    @memcpy(out[pos .. pos + done.len], done);
    pos += done.len;
    pos += writeUintTo(out[pos..], shell.archive_done);
    const last = ",\"last_done_time\":";
    @memcpy(out[pos .. pos + last.len], last);
    pos += last.len;
    pos += writeUintTo(out[pos..], shell.last_done_time);
    const snapshots = .{
        .{ shell.archive_content_valid, shell.archive_content, ",\"archive_rows\":\"" },
        .{ shell.last_done_content_valid, shell.last_done_content, ",\"done_rows\":\"" },
    };
    inline for (snapshots) |snapshot| {
        if (snapshot[0]) {
            const rows = snapshot[2];
            @memcpy(out[pos .. pos + rows.len], rows);
            pos += rows.len;
            const hex = "0123456789abcdef";
            for (snapshot[1].rows[0..snapshot[1].len]) |row| {
                for (0..16) |digit| {
                    const shift: u6 = @intCast((15 - digit) * 4);
                    out[pos] = hex[@as(usize, @intCast((row >> shift) & 15))];
                    pos += 1;
                }
            }
            out[pos] = '"';
            pos += 1;
        }
    }
    return pos;
}

pub fn restoreArchiveMarkers(shell: *Shell, tab: *const SavedTab) void {
    shell.archive_time = tab.archive_time;
    shell.archive_done = tab.archive_done;
    shell.last_done_time = tab.last_done_time;
    shell.last_done_content = tab.last_done_content;
    shell.last_done_content_valid = tab.last_done_content_valid;
    shell.archive_content = tab.archive_content;
    shell.archive_content_valid = tab.archive_content_valid;
}

pub fn hideActiveTabUntilAttention() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    const idx = app_state.active_shell;
    if (@import("archive.zig").rejectPinnedSessionClose(idx)) return;
    if (app_state.shells[idx].inbox_archived and !app_state.shells[idx].needs_attention) {
        if (findNextVisibleTab(idx, 1) orelse findNextVisibleTab(idx, -1)) |nxt| {
            switchToShell(nxt);
            showHeaderNoticeAscii("Moved to Waiting until next blue dot", 2500, false);
        } else {
            showHeaderNoticeAscii("No other visible tab", 3000, true);
        }
        return;
    }

    const had_inbox_context = app_state.g_inbox_step_context_active;
    const inbox_next = inboxNextRowFromContext();
    if (had_inbox_context and inbox_next == null) {
        showHeaderNoticeAscii("No next session in this Inbox split", 3000, true);
        return;
    }

    const was_att = app_state.shells[idx].needs_attention;
    if (!recordInboxArchive(idx)) return;
    app_state.shells[idx].needs_attention = false;
    app_state.shells[idx].activity = .idle;
    app_state.shells[idx].last_active_event = 0;
    app_state.shells[idx].hidden_idle_streak = 0;
    stopSpinnerTimerIfIdle();

    if (inbox_next) |ri| {
        rememberInboxArchiveUndo(@intFromPtr(app_state.g_main_hwnd), app_state.shells[idx].shell_id, was_att);
        publishInboxStateNow();
        saveSession();
        invalidateSidebar();
        showHeaderNoticeAscii("Moved to Waiting until next blue dot", 2500, false);
        jumpToInboxRow(ri);
        return;
    }

    const next = findNextVisibleTab(idx, 1) orelse findNextVisibleTab(idx, -1);
    if (next) |nxt| {
        rememberInboxArchiveUndo(@intFromPtr(app_state.g_main_hwnd), app_state.shells[idx].shell_id, was_att);
        switchToShell(nxt);
        showHeaderNoticeAscii("Moved to Waiting until next blue dot", 2500, false);
    } else {
        app_state.shells[idx].inbox_archived = false;
        showHeaderNoticeAscii("No other visible tab", 3000, true);
    }

    publishInboxStateNow();
    saveSession();
    invalidateSidebar();
    if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

fn userPresentOnSelectedTab() bool {
    return foregroundIsOurs() and !activeBrowserSurfaceHasForegroundFocus();
}

pub fn dotTargetsTab(i: usize) bool {
    if (!app_state.ISSUE_274_DOT_ON_SELECTED_TAB) return i != app_state.active_shell;
    return i != app_state.active_shell or !userPresentOnSelectedTab();
}

pub fn clearSelectedTabDotOnReturn() void {
    if (!app_state.ISSUE_274_DOT_ON_SELECTED_TAB or app_state.active_shell >= app_state.shell_count) return;
    const s = &app_state.shells[app_state.active_shell];
    if (!s.needs_attention or !userPresentOnSelectedTab()) return;
    if (s.last_blue_dot_source == .manual or s.last_blue_dot_source == .restore) return;
    s.needs_attention = false;
    recordShellDiagEvent(app_state.active_shell, "blue dot cleared", "returned");
    invalidateSidebar();
    publishInboxState();
    if (!app_state.g_restoring) saveSession();
}

pub fn setBlueDot(i: usize, source: attention_rules.Source, done_after_activity: bool) bool {
    if (i >= app_state.shell_count or app_state.shells[i].needs_attention) return false;
    const s = &app_state.shells[i];
    if (!attention_rules.allow(source, .{
        .hook_capable = s.hook_capable or s.claude_sid_len > 0,
        .turn_active = s.turn_pending,
        .done_after_activity = done_after_activity,
        .console_working = s.console_working,
        .selected_tab = app_state.ISSUE_274_DOT_ON_SELECTED_TAB and i == app_state.active_shell,
        .user_present = userPresentOnSelectedTab(),
    })) return false;
    s.needs_attention = true;
    s.last_blue_dot_source = source;
    s.last_blue_dot_time = nowFileTime();
    var line: [180]u8 = undefined;
    var name: [64]u8 = undefined;
    for (s.name[0..s.name_len], 0..) |ch, n| name[n] = if (ch >= 32 and ch < 127) @intCast(ch) else '?';
    const msg = std.fmt.bufPrint(&line, "blue dot source={s} tab={s} time={d}", .{ @tagName(source), name[0..s.name_len], s.last_blue_dot_time }) catch return true;
    debugLog(msg);
    recordShellDiagEvent(i, "blue dot", @tagName(source));
    return true;
}

pub fn noteRestoredBlueDot(i: usize) void {
    if (i >= app_state.shell_count or !app_state.shells[i].needs_attention) return;
    app_state.shells[i].needs_attention = false;
    _ = setBlueDot(i, .restore, false);
}

fn markShellUnread(idx: usize) void {
    if (idx >= app_state.shell_count) return;
    _ = setBlueDot(idx, .manual, false);
    if (app_state.shells[idx].inbox_archived) logUnarchive(idx, "explicit mark unread");
    app_state.shells[idx].inbox_archived = false;
    app_state.shells[idx].last_active = nowFileTime();
    stickyRemove(app_state.shells[idx].shell_id);
    publishInboxState();
    saveSession();
    invalidateSidebar();
    if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

pub fn markActiveShellUnread() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    markShellUnread(app_state.active_shell);
    showHeaderNoticeAscii("Marked unread", 1800, false);
}

pub fn toggleKeepAwakeForActiveShell() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    app_state.shells[app_state.active_shell].keep_awake = !app_state.shells[app_state.active_shell].keep_awake;
    if (app_state.shells[app_state.active_shell].keep_awake and app_state.shells[app_state.active_shell].browser_frozen) {
        wakeBrowserPaneFromFreeze(app_state.active_shell);
    }
    invalidateSidebar();
    if (!app_state.g_restoring) saveSession();
    showHeaderNoticeAscii(if (app_state.shells[app_state.active_shell].keep_awake) "Keep Tab Awake: On" else "Keep Tab Awake: Off", 1800, false);
}

pub fn workspaceHasTabExcept(ws: u8, except_idx: u32) bool {
    for (0..app_state.shell_count) |i| {
        if (@as(u32, @intCast(i)) == except_idx) continue;
        if (app_state.shells[i].workspace == ws) return true;
    }
    return false;
}

pub fn firstTabInWorkspace(ws: u8) ?u32 {
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].workspace == ws) return @intCast(i);
    }
    return null;
}

pub fn findCloseNeighborInWorkspace(closed_idx: u32, ws: u8) ?u32 {
    if (closed_idx >= app_state.shell_count) return null;

    var rows: [MAX_ROWS]Row = undefined;
    const row_count = layoutRows(&rows);
    var closed_row: ?u32 = null;
    for (0..row_count) |ri| {
        const row = rows[ri];
        if (row.kind == .tab and row.shell_idx == closed_idx) {
            closed_row = @intCast(ri);
            break;
        }
    }

    if (closed_row) |cr| {
        var ri = cr;
        while (ri > 0) {
            ri -= 1;
            const row = rows[ri];
            if (row.kind != .tab) continue;
            const candidate = row.shell_idx;
            if (candidate >= app_state.shell_count or candidate == closed_idx) continue;
            if (app_state.shells[candidate].workspace == ws and !isTabHidden(candidate)) return candidate;
        }

        ri = cr + 1;
        while (ri < row_count) : (ri += 1) {
            const row = rows[ri];
            if (row.kind != .tab) continue;
            const candidate = row.shell_idx;
            if (candidate >= app_state.shell_count or candidate == closed_idx) continue;
            if (app_state.shells[candidate].workspace == ws and !isTabHidden(candidate)) return candidate;
        }
        return null;
    }

    var i = closed_idx;
    while (i > 0) {
        i -= 1;
        if (app_state.shells[i].workspace == ws and !isTabHidden(i)) return i;
    }
    i = closed_idx + 1;
    while (i < app_state.shell_count) : (i += 1) {
        if (app_state.shells[i].workspace == ws and !isTabHidden(i)) return i;
    }
    return null;
}

pub fn tabGroupId(idx: usize) u32 {
    return if (app_state.g_starred_workspace) app_state.shells[idx].starred_group_id else app_state.shells[idx].group_id;
}

pub fn setTabGroupId(idx: usize, gid: u32) void {
    if (app_state.g_starred_workspace) app_state.shells[idx].starred_group_id = gid else app_state.shells[idx].group_id = gid;
}

fn tabInCurrentWorkspace(idx: usize) bool {
    if (app_state.g_starred_workspace) return @import("workspaces.zig").starredShellVisible(idx);
    return !app_state.g_single_window or app_state.shells[idx].workspace == app_state.g_active_workspace;
}

pub fn groupInCurrentWorkspace(gid: u32) bool {
    for (0..app_state.shell_count) |i| {
        if (tabInCurrentWorkspace(i) and tabGroupId(i) == gid) return true;
    }
    return false;
}

pub fn groupFirstShellIdx(gid: u32) ?u32 {
    if (gid == 0) return null;
    for (0..app_state.shell_count) |i| {
        if (tabGroupId(i) == gid) return @intCast(i);
    }
    return null;
}

fn groupLastShellIdx(gid: u32) ?u32 {
    if (gid == 0) return null;
    var last: ?u32 = null;
    for (0..app_state.shell_count) |i| {
        if (tabGroupId(i) == gid) last = @intCast(i);
    }
    return last;
}

pub fn selectedTabCount() u32 {
    var n: u32 = 0;
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].selected) n += 1;
    }
    return n;
}

pub fn clearTabSelection() bool {
    var changed = false;
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].selected) {
            app_state.shells[i].selected = false;
            changed = true;
        }
    }
    return changed;
}

pub fn selectedTabsIncludeGrouped() bool {
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].selected and tabGroupId(i) != 0) return true;
    }
    return false;
}

fn applyGroupToSelectedTabs(gid: u32) void {
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].selected) {
            setTabGroupId(i, gid);
            app_state.shells[i].selected = false;
        }
    }
    pruneEmptyGroups();
    normalizeGroupOrder();
}

pub fn assignTabOrSelectionToGroup(captured_sid: u32, gid: u32) bool {
    if (selectedTabCount() > 0) {
        applyGroupToSelectedTabs(gid);
        return true;
    }
    if (findShellById(captured_sid)) |ti| {
        setTabGroupId(ti, gid);
        app_state.shells[ti].selected = false;
        pruneEmptyGroups();
        normalizeGroupOrder();
        return true;
    }
    return false;
}

pub fn removeTabOrSelectionFromGroup(captured_sid: u32) bool {
    var changed = false;
    if (selectedTabCount() > 0) {
        for (0..app_state.shell_count) |si| {
            if (app_state.shells[si].selected) {
                changed = changed or tabGroupId(si) != 0;
                setTabGroupId(si, 0);
                app_state.shells[si].selected = false;
            }
        }
    } else if (findShellById(captured_sid)) |ti| {
        changed = tabGroupId(ti) != 0;
        setTabGroupId(ti, 0);
        app_state.shells[ti].selected = false;
    } else {
        return false;
    }
    pruneEmptyGroups();
    normalizeGroupOrder();
    return changed;
}

pub fn moveShellToIndexWithGroup(src: u32, dst: u32, new_gid: u32) ?u32 {
    if (src >= app_state.shell_count or dst >= app_state.shell_count) return null;
    if (src == dst) {
        setTabGroupId(src, new_gid);
        return src;
    }

    var moved = app_state.shells[src];
    if (app_state.g_starred_workspace) moved.starred_group_id = new_gid else moved.group_id = new_gid;
    if (src < dst) {
        var i = src;
        while (i < dst) : (i += 1) app_state.shells[i] = app_state.shells[i + 1];
        app_state.shells[dst] = moved;
        if (app_state.active_shell == src) {
            app_state.active_shell = dst;
        } else if (app_state.active_shell > src and app_state.active_shell <= dst) {
            app_state.active_shell -= 1;
        }
    } else {
        var i = src;
        while (i > dst) : (i -= 1) app_state.shells[i] = app_state.shells[i - 1];
        app_state.shells[dst] = moved;
        if (app_state.active_shell == src) {
            app_state.active_shell = dst;
        } else if (app_state.active_shell >= dst and app_state.active_shell < src) {
            app_state.active_shell += 1;
        }
    }
    return dst;
}

pub fn moveShellToGroupStart(src: u32, gid: u32) ?u32 {
    const first = groupFirstShellIdx(gid) orelse return null;
    const dst: u32 = if (src < first) first - 1 else first;
    return moveShellToIndexWithGroup(src, dst, gid);
}

pub fn moveActiveTabStep(dir: i32) bool {
    if (app_state.shell_count < 2 or app_state.active_shell >= app_state.shell_count) return false;
    const cur = app_state.active_shell;
    const cur_gid = tabGroupId(cur);

    if (cur_gid != 0 and findGroupIdx(cur_gid) != null) {
        const first = groupFirstShellIdx(cur_gid) orelse cur;
        const last = groupLastShellIdx(cur_gid) orelse cur;
        if (dir < 0) {
            if (cur > first) {
                _ = moveShellToIndexWithGroup(cur, cur - 1, cur_gid);
            } else {
                setTabGroupId(cur, 0);
            }
        } else {
            if (cur < last) {
                _ = moveShellToIndexWithGroup(cur, cur + 1, cur_gid);
            } else {
                setTabGroupId(cur, 0);
            }
        }
        pruneEmptyGroups();
        return true;
    }

    if (dir < 0) {
        if (cur == 0) return false;
        const target = cur - 1;
        const target_gid = tabGroupId(target);
        if (target_gid == 0) {
            _ = moveShellToIndexWithGroup(cur, target, 0);
        } else {
            setTabGroupId(cur, target_gid);
        }
    } else {
        if (cur + 1 >= app_state.shell_count) return false;
        const target = cur + 1;
        const target_gid = tabGroupId(target);
        if (target_gid == 0) {
            _ = moveShellToIndexWithGroup(cur, target, 0);
        } else {
            setTabGroupId(cur, target_gid);
        }
    }
    pruneEmptyGroups();
    return true;
}

pub fn moveGroupToIndex(src: u32, dst: u32) bool {
    if (src >= app_state.group_count or dst >= app_state.group_count or src == dst) return false;
    const moved = app_state.groups[src];
    if (src < dst) {
        var i = src;
        while (i < dst) : (i += 1) app_state.groups[i] = app_state.groups[i + 1];
    } else {
        var i = src;
        while (i > dst) : (i -= 1) app_state.groups[i] = app_state.groups[i - 1];
    }
    app_state.groups[dst] = moved;
    return true;
}

pub fn createGroup(name: []const u16) u32 {
    if (app_state.group_count >= MAX_GROUPS) return 0;
    const g = &app_state.groups[app_state.group_count];
    g.id = app_state.next_group_id;
    app_state.next_group_id += 1;
    const n: u32 = @intCast(@min(name.len, g.name.len));
    @memcpy(g.name[0..n], name[0..n]);
    g.name_len = n;
    g.collapsed = false;
    g.color = 7;
    g.color_set = false;
    app_state.group_count += 1;
    return g.id;
}

pub fn createDefaultGroup() u32 {
    var default_name: [16]u16 = std.mem.zeroes([16]u16);
    var ni: usize = 0;
    const pfx = "Group ";
    for (pfx) |c| {
        default_name[ni] = c;
        ni += 1;
    }
    var gid_num = app_state.next_group_id;
    var digits: [6]u8 = undefined;
    var di: usize = 0;
    if (gid_num == 0) {
        digits[0] = '0';
        di = 1;
    } else {
        while (gid_num > 0) : (di += 1) {
            digits[di] = @intCast(gid_num % 10 + '0');
            gid_num /= 10;
        }
    }
    while (di > 0) {
        di -= 1;
        default_name[ni] = digits[di];
        ni += 1;
    }
    return createGroup(default_name[0..ni]);
}

pub fn deleteGroup(gid: u32) void {
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].group_id == gid) app_state.shells[i].group_id = 0;
        if (app_state.shells[i].starred_group_id == gid) app_state.shells[i].starred_group_id = 0;
    }
    const gidx_opt = findGroupIdx(gid);
    if (gidx_opt) |gidx| {
        var i: u32 = gidx;
        while (i + 1 < app_state.group_count) : (i += 1) {
            app_state.groups[i] = app_state.groups[i + 1];
        }
        app_state.group_count -= 1;
    }
}

pub fn pruneEmptyGroups() void {
    var gi: u32 = 0;
    while (gi < app_state.group_count) {
        const gid = app_state.groups[gi].id;
        var has_member = false;
        for (0..app_state.shell_count) |i| {
            if (app_state.shells[i].group_id == gid or app_state.shells[i].starred_group_id == gid) {
                has_member = true;
                break;
            }
        }
        if (!has_member) {
            var j: u32 = gi;
            while (j + 1 < app_state.group_count) : (j += 1) app_state.groups[j] = app_state.groups[j + 1];
            app_state.group_count -= 1;
            continue;
        }
        gi += 1;
    }
}

pub fn normalizeGroupOrder() void {
    if (app_state.g_starred_workspace) return;
    if (app_state.shell_count < 2) return;
    const active_id = if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].shell_id else 0;

    var tmp: [MAX_SHELLS]Shell = undefined;
    var written: u32 = 0;
    var consumed: [MAX_SHELLS]bool = [_]bool{false} ** MAX_SHELLS;

    var i: u32 = 0;
    while (i < app_state.shell_count) : (i += 1) {
        if (consumed[i]) continue;
        tmp[written] = app_state.shells[i];
        written += 1;
        consumed[i] = true;
        const gid = app_state.shells[i].group_id;
        if (gid == 0) continue;
        var j: u32 = i + 1;
        while (j < app_state.shell_count) : (j += 1) {
            if (consumed[j]) continue;
            if (app_state.shells[j].group_id == gid) {
                tmp[written] = app_state.shells[j];
                written += 1;
                consumed[j] = true;
            }
        }
    }

    var k: u32 = 0;
    while (k < written) : (k += 1) app_state.shells[k] = tmp[k];

    if (active_id != 0) {
        k = 0;
        while (k < app_state.shell_count) : (k += 1) {
            if (app_state.shells[k].shell_id == active_id) {
                app_state.active_shell = k;
                break;
            }
        }
    }
}

pub fn applyPendingGroup() void {
    if (app_state.g_pending_new_tab_group == 0) return;
    defer app_state.g_pending_new_tab_group = 0;
    if (app_state.shell_count == 0) return;
    if (findGroupIdx(app_state.g_pending_new_tab_group) == null) return;
    if (app_state.g_starred_workspace) app_state.shells[app_state.shell_count - 1].favorite = true;
    setTabGroupId(app_state.shell_count - 1, app_state.g_pending_new_tab_group);
    normalizeGroupOrder();
    saveSession();
}

inline fn effAtt(i: usize) bool {
    if (app_state.shells[i].needs_attention) return true;
    if (stickyFind(app_state.shells[i].shell_id)) |k| return app_state.g_sticky[k].att;
    return app_state.shells[i].needs_attention;
}

inline fn effActive(i: usize) bool {
    if (app_state.shells[i].activity == .active) return true;
    if (stickyFind(app_state.shells[i].shell_id)) |k| return app_state.g_sticky[k].active;
    return app_state.shells[i].activity == .active;
}

inline fn effLa(i: usize) u64 {
    if (stickyFind(app_state.shells[i].shell_id)) |k| return app_state.g_sticky[k].la;
    return app_state.shells[i].last_active;
}

inline fn effPinnedTop(i: usize) bool {
    return app_state.shells[i].pinned_top;
}

pub inline fn shellSidebarTier(i: usize) SidebarTier {
    if (effPinnedTop(i)) return .pinned;
    return .recent;
}

fn sidebarHasVisibleSessions() bool {
    for (0..app_state.shell_count) |i| {
        if (app_state.g_single_window and app_state.shells[i].workspace != app_state.g_active_workspace) continue;
        if (!tabPassesUnreadFilter(i)) continue;
        return true;
    }
    return false;
}

fn sidebarSectionCollapsed(tier: SidebarTier) bool {
    return switch (tier) {
        .pinned => app_state.g_pinned_section_collapsed,
        .recent => app_state.g_recents_section_collapsed,
    };
}

pub fn toggleSidebarSectionCollapsed(tier: SidebarTier) void {
    switch (tier) {
        .pinned => app_state.g_pinned_section_collapsed = !app_state.g_pinned_section_collapsed,
        .recent => app_state.g_recents_section_collapsed = !app_state.g_recents_section_collapsed,
    }
    clampSidebarScroll();
    saveSession();
    invalidateSidebar();
}

fn buildSortedOrder(out: *[MAX_SHELLS]u32, out_n: *u32) void {
    const Block = struct {
        tier: SidebarTier,
        att: bool,
        is_active: bool,
        la: u64,
        pos: u32,
        payload: u32,
        is_group: bool,
        muted: bool,
    };
    var blocks: [MAX_SHELLS]Block = undefined;
    var bc: u32 = 0;
    var seen_gids: [MAX_GROUPS]u32 = [_]u32{0} ** MAX_GROUPS;
    var sgc: u32 = 0;

    for (0..app_state.shell_count) |i| {
        if (!tabInCurrentWorkspace(i)) continue;
        const gid = tabGroupId(i);
        if (gid == 0) {
            if (!tabPassesUnreadFilter(i)) continue;
            if (bc < MAX_SHELLS) {
                blocks[bc] = .{
                    .tier = shellSidebarTier(i),
                    .att = effAtt(i),
                    .is_active = effActive(i),
                    .la = effLa(i),
                    .pos = @intCast(i),
                    .payload = @intCast(i),
                    .is_group = false,
                    .muted = app_state.shells[i].muted,
                };
                bc += 1;
            }
        } else {
            var already = false;
            for (0..sgc) |j| {
                if (seen_gids[j] == gid) {
                    already = true;
                    break;
                }
            }
            if (!already and sgc < MAX_GROUPS) {
                seen_gids[sgc] = gid;
                sgc += 1;
                const gidx = findGroupIdx(gid) orelse continue;
                var g_att: bool = false;
                var g_is_active: bool = false;
                var g_la: u64 = 0;
                var g_pass: u32 = 0;
                var g_muted: bool = true;
                for (0..app_state.shell_count) |j| {
                    if (tabGroupId(j) != gid) continue;
                    if (!tabInCurrentWorkspace(j)) continue;
                    if (tabPassesUnreadFilter(j)) {
                        g_pass += 1;
                    }
                    if (effAtt(j)) g_att = true;
                    if (effActive(j)) g_is_active = true;
                    if (!app_state.shells[j].muted) g_muted = false;
                    const j_la = effLa(j);
                    if (j_la > g_la) g_la = j_la;
                }
                if (g_pass == 0) continue;
                if (bc < MAX_SHELLS) {
                    blocks[bc] = .{ .tier = .recent, .att = g_att, .is_active = g_is_active, .la = g_la, .pos = @intCast(gidx), .payload = @intCast(gidx), .is_group = true, .muted = g_muted };
                    bc += 1;
                }
            }
        }
    }

    {
        var ii: u32 = 1;
        while (ii < bc) : (ii += 1) {
            const tmp = blocks[ii];
            var jj: i32 = @as(i32, @intCast(ii)) - 1;
            while (jj >= 0) {
                const b = blocks[@intCast(jj)];
                const before: bool =
                    (tmp.is_group and !b.is_group) or
                    (tmp.is_group and b.is_group and tmp.pos < b.pos) or
                    (!tmp.is_group and !b.is_group and @intFromEnum(tmp.tier) > @intFromEnum(b.tier)) or
                    (!tmp.is_group and !b.is_group and tmp.tier == b.tier and !tmp.muted and b.muted) or
                    (!tmp.is_group and !b.is_group and tmp.tier == b.tier and tmp.muted == b.muted and ((tmp.att and !b.att) or
                        (tmp.att == b.att and tmp.is_active and !b.is_active) or
                        (tmp.att == b.att and tmp.is_active == b.is_active and tmp.la > b.la) or
                        (tmp.att == b.att and tmp.is_active == b.is_active and tmp.la == b.la and tmp.pos < b.pos)));
                if (!before) break;
                blocks[@intCast(jj + 1)] = blocks[@intCast(jj)];
                jj -= 1;
            }
            blocks[@intCast(jj + 1)] = tmp;
        }
    }

    out_n.* = 0;
    for (0..bc) |bi| {
        const blk = blocks[bi];
        if (!blk.is_group) {
            if (out_n.* < MAX_SHELLS) {
                out[out_n.*] = blk.payload;
                out_n.* += 1;
            }
        } else {
            const gid = app_state.groups[blk.payload].id;
            var mbrs: [MAX_SHELLS]u32 = undefined;
            var mc: u32 = 0;
            for (0..app_state.shell_count) |i| {
                if (tabGroupId(i) != gid) continue;
                if (!tabInCurrentWorkspace(i)) continue;
                if (mc < MAX_SHELLS) {
                    mbrs[mc] = @intCast(i);
                    mc += 1;
                }
            }
            {
                var ii: u32 = 1;
                while (ii < mc) : (ii += 1) {
                    const tm = mbrs[ii];
                    var jj: i32 = @as(i32, @intCast(ii)) - 1;
                    while (jj >= 0) {
                        const bm = mbrs[@intCast(jj)];
                        const tm_key = effLa(tm);
                        const bm_key = effLa(bm);
                        const tm_tier = shellSidebarTier(tm);
                        const bm_tier = shellSidebarTier(bm);
                        const before: bool =
                            (@intFromEnum(tm_tier) > @intFromEnum(bm_tier)) or
                            (tm_tier == bm_tier and effAtt(tm) and !effAtt(bm)) or
                            (tm_tier == bm_tier and effAtt(tm) == effAtt(bm) and effActive(tm) and !effActive(bm)) or
                            (tm_tier == bm_tier and effAtt(tm) == effAtt(bm) and effActive(tm) == effActive(bm) and tm_key > bm_key) or
                            (tm_tier == bm_tier and effAtt(tm) == effAtt(bm) and effActive(tm) == effActive(bm) and tm_key == bm_key and tm < bm);
                        if (!before) break;
                        mbrs[@intCast(jj + 1)] = mbrs[@intCast(jj)];
                        jj -= 1;
                    }
                    mbrs[@intCast(jj + 1)] = tm;
                }
            }
            for (0..mc) |mi| {
                if (!tabPassesUnreadFilter(mbrs[mi])) continue;
                if (out_n.* < MAX_SHELLS) {
                    out[out_n.*] = mbrs[mi];
                    out_n.* += 1;
                }
            }
        }
    }
}

pub fn materializeDisplayOrder() void {
    var sorted: [MAX_SHELLS]u32 = undefined;
    var sorted_n: u32 = 0;
    buildSortedOrder(&sorted, &sorted_n);

    const active_pid: DWORD = if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].pid else 0;

    var new_shells: [MAX_SHELLS]Shell = undefined;
    var placed: [MAX_SHELLS]bool = [_]bool{false} ** MAX_SHELLS;
    var new_idx: u32 = 0;

    for (0..sorted_n) |si| {
        const old_idx = sorted[si];
        new_shells[new_idx] = app_state.shells[old_idx];
        placed[old_idx] = true;
        new_idx += 1;
    }
    for (0..app_state.shell_count) |i| {
        if (!placed[i]) {
            new_shells[new_idx] = app_state.shells[i];
            new_idx += 1;
        }
    }
    for (0..app_state.shell_count) |i| app_state.shells[i] = new_shells[i];

    if (active_pid != 0) {
        for (0..app_state.shell_count) |i| {
            if (app_state.shells[i].pid == active_pid) {
                app_state.active_shell = @intCast(i);
                break;
            }
        }
    }
}

pub fn layoutRows(out: *[MAX_ROWS]Row) u32 {
    var count: u32 = 0;
    var y: i32 = (if (LOOK_UNIFIED) @import("window_layout.zig").paneOuterMargin() else 0) + wsStripHeight() + @import("workspace_switcher.zig").headerHeight();
    if (app_state.g_starred_workspace) {
        for (0..app_state.group_count) |gi| {
            const gid = app_state.groups[gi].id;
            if (!groupInCurrentWorkspace(gid)) continue;
            out[count] = .{ .kind = .header, .gidx = @intCast(gi), .shell_idx = 0, .y = y };
            count += 1;
            y += GROUP_HEADER_H;
            if (app_state.groups[gi].collapsed) continue;
            for (0..app_state.shell_count) |i| {
                if (!tabInCurrentWorkspace(i) or tabGroupId(i) != gid) continue;
                out[count] = .{ .kind = .tab, .gidx = @intCast(gi), .shell_idx = @intCast(i), .y = y };
                count += 1;
                y += tabRowH();
            }
        }
        for (0..app_state.shell_count) |i| {
            if (!@import("workspaces.zig").starredShellVisible(i) or tabGroupId(i) != 0) continue;
            out[count] = .{ .kind = .tab, .gidx = 0, .shell_idx = @intCast(i), .y = y };
            count += 1;
            y += tabRowH();
        }
        for (app_state.g_inbox_rows[0..app_state.g_inbox_row_count], 0..) |row, i| {
            if (row.ws >= app_state.g_inbox_ws_count or app_state.g_inbox_ws[row.ws].hwnd == @intFromPtr(app_state.g_main_hwnd)) continue;
            if (!@import("workspace_view.zig").splitMatches(frequent.favorites_split, row.ws, row.favorite)) continue;
            out[count] = .{ .kind = .inbox, .gidx = 0, .shell_idx = @intCast(i), .y = y };
            count += 1;
            y += tabRowH();
        }
        return count;
    }
    const show_section_headers = !app_state.g_sidebar_collapsed and sidebarHasVisibleSessions();

    if (app_state.g_tab_sort_auto) {
        var sorted: [MAX_SHELLS]u32 = undefined;
        var sorted_n: u32 = 0;
        buildSortedOrder(&sorted, &sorted_n);
        var prev_gid: u32 = 0;
        var last_section: ?SidebarTier = null;
        for (0..sorted_n) |si| {
            const i: usize = sorted[si];
            if (!tabPassesUnreadFilter(i)) continue;
            const gid = app_state.shells[i].group_id;
            if (gid == 0 and show_section_headers) {
                const tier = shellSidebarTier(i);
                if (last_section == null or last_section.? != tier) {
                    out[count] = .{ .kind = .section, .gidx = 0, .shell_idx = 0, .section_tier = tier, .y = y };
                    count += 1;
                    y += SECTION_HEADER_H;
                    last_section = tier;
                }
                if (sidebarSectionCollapsed(tier)) continue;
            }
            if (gid != prev_gid and gid != 0) {
                if (findGroupIdx(gid)) |gidx| {
                    out[count] = .{ .kind = .header, .gidx = gidx, .shell_idx = 0, .y = y };
                    count += 1;
                    y += GROUP_HEADER_H;
                }
            }
            prev_gid = gid;
            var collapsed = false;
            var gidx_for_tab: u32 = 0;
            if (gid != 0) {
                if (findGroupIdx(gid)) |gidx| {
                    gidx_for_tab = gidx;
                    if (app_state.groups[gidx].collapsed) collapsed = true;
                }
            }
            if (collapsed) continue;
            out[count] = .{ .kind = .tab, .gidx = gidx_for_tab, .shell_idx = @intCast(i), .y = y };
            count += 1;
            y += tabRowH();
        }
        return count;
    }

    for (0..app_state.group_count) |gidx| {
        const gid = app_state.groups[gidx].id;
        var has_visible_member = false;
        for (0..app_state.shell_count) |i| {
            if (app_state.shells[i].group_id != gid) continue;
            if (app_state.g_single_window and app_state.shells[i].workspace != app_state.g_active_workspace) continue;
            if (!tabPassesUnreadFilter(i)) continue;
            has_visible_member = true;
            break;
        }
        if (!has_visible_member) continue;
        out[count] = .{ .kind = .header, .gidx = @intCast(gidx), .shell_idx = 0, .y = y };
        count += 1;
        y += GROUP_HEADER_H;
        if (app_state.groups[gidx].collapsed) continue;
        var member_tier_pass: i32 = @intFromEnum(SidebarTier.pinned);
        while (member_tier_pass >= @intFromEnum(SidebarTier.recent)) : (member_tier_pass -= 1) {
            const member_tier: SidebarTier = @enumFromInt(@as(u1, @intCast(member_tier_pass)));
            for (0..app_state.shell_count) |i| {
                if (app_state.shells[i].group_id != gid) continue;
                if (app_state.g_single_window and app_state.shells[i].workspace != app_state.g_active_workspace) continue;
                if (!tabPassesUnreadFilter(i) or shellSidebarTier(i) != member_tier) continue;
                out[count] = .{ .kind = .tab, .gidx = @intCast(gidx), .shell_idx = @intCast(i), .y = y };
                count += 1;
                y += tabRowH();
            }
        }
    }

    var tier_pass: i32 = @intFromEnum(SidebarTier.pinned);
    while (tier_pass >= @intFromEnum(SidebarTier.recent)) : (tier_pass -= 1) {
        const want_tier: SidebarTier = @enumFromInt(@as(u1, @intCast(tier_pass)));
        if (show_section_headers) {
            var has_section_tabs = false;
            for (0..app_state.shell_count) |i| {
                if (app_state.g_single_window and app_state.shells[i].workspace != app_state.g_active_workspace) continue;
                if (!tabPassesUnreadFilter(i)) continue;
                if (app_state.shells[i].group_id != 0 or shellSidebarTier(i) != want_tier) continue;
                has_section_tabs = true;
                break;
            }
            if (has_section_tabs) {
                out[count] = .{ .kind = .section, .gidx = 0, .shell_idx = 0, .section_tier = want_tier, .y = y };
                count += 1;
                y += SECTION_HEADER_H;
                if (sidebarSectionCollapsed(want_tier)) continue;
            }
        }
        for (0..app_state.shell_count) |i| {
            if (app_state.g_single_window and app_state.shells[i].workspace != app_state.g_active_workspace) continue;
            if (!tabPassesUnreadFilter(i)) continue;
            if (app_state.shells[i].group_id != 0 or shellSidebarTier(i) != want_tier) continue;
            out[count] = .{ .kind = .tab, .gidx = 0, .shell_idx = @intCast(i), .y = y };
            count += 1;
            y += tabRowH();
        }
    }
    return count;
}

pub fn rowTotalHeight(row: Row) i32 {
    return switch (row.kind) {
        .section => SECTION_HEADER_H,
        .header => GROUP_HEADER_H,
        .tab, .inbox => tabRowH(),
    };
}

pub fn sidebarTierForDrop(hit: HitTarget) ?SidebarTier {
    return switch (hit) {
        .section => |tier| tier,
        .tab => |idx| if (idx < app_state.shell_count and tabGroupId(idx) == 0) shellSidebarTier(idx) else null,
        .header => null,
        else => null,
    };
}

pub fn workspaceStripHitTest(mx: i32, my: i32) ?u8 {
    if (!app_state.g_single_window or app_state.g_sidebar_collapsed or app_state.g_hide_sidebar or app_state.g_hide_pills) return null;
    if (my < WS_PILL_TOP or my >= WS_PILL_TOP + WS_PILL_H) return null;
    const pill_right = inboxButtonRect(false).left - 4;
    var x: i32 = WS_STRIP_LEFT;
    if (mx >= x and mx < x + WS_PILL_W) return @import("workspace_view.zig").starred;
    x += WS_PILL_W + WS_PILL_GAP;
    var ws: u8 = 0;
    while (ws < app_state.g_lws_count) : (ws += 1) {
        if (app_state.g_ws_snoozed[ws]) continue;
        if (x + WS_PILL_W > pill_right) return null;
        if (mx >= x and mx < x + WS_PILL_W) return ws;
        x += WS_PILL_W + WS_PILL_GAP;
    }
    if (app_state.g_lws_count < MAX_LWS and x + WS_PILL_W <= pill_right and mx >= x and mx < x + WS_PILL_W) return WS_NEW_PILL;
    return null;
}

test "workspace pills and Inbox button have disjoint hit areas" {
    const prev_single = app_state.g_single_window;
    const prev_hidden = app_state.g_hide_pills;
    const prev_sidebar = app_state.g_sidebar_collapsed;
    const prev_inbox = app_state.g_inbox_active;
    const prev_count = app_state.g_lws_count;
    defer {
        app_state.g_single_window = prev_single;
        app_state.g_hide_pills = prev_hidden;
        app_state.g_sidebar_collapsed = prev_sidebar;
        app_state.g_inbox_active = prev_inbox;
        app_state.g_lws_count = prev_count;
    }
    app_state.g_single_window = true;
    app_state.g_hide_pills = false;
    app_state.g_sidebar_collapsed = false;
    app_state.g_inbox_active = false;
    app_state.g_lws_count = 4;
    const button = inboxButtonRect(false);
    try std.testing.expect(workspaceStripHitTest(WS_STRIP_LEFT, WS_PILL_TOP) == @import("workspace_view.zig").starred);
    try std.testing.expect(workspaceStripHitTest(WS_STRIP_LEFT + 5 * (WS_PILL_W + WS_PILL_GAP), WS_PILL_TOP) == WS_NEW_PILL);
    try std.testing.expect(workspaceStripHitTest(button.left, WS_PILL_TOP) == null);
    try std.testing.expect(inboxButtonHitTest(button.left, WS_PILL_TOP));
    app_state.g_inbox_active = true;
    try std.testing.expect(inboxButtonHitTest(inboxButtonRect(true).left, WS_PILL_TOP));
}

pub fn hitTestSidebar(logical_my: i32) HitTarget {
    var rows: [MAX_ROWS]Row = undefined;
    const n = layoutRows(&rows);
    for (0..n) |ri| {
        const row = rows[ri];
        const h = rowTotalHeight(row);
        if (logical_my >= row.y and logical_my < row.y + h) {
            return switch (row.kind) {
                .section => HitTarget{ .section = row.section_tier },
                .header => HitTarget{ .header = row.gidx },
                .tab => HitTarget{ .tab = row.shell_idx },
                .inbox => HitTarget{ .inbox = row.shell_idx },
            };
        }
    }
    const content_end: i32 = if (n == 0) 0 else (rows[n - 1].y + rowTotalHeight(rows[n - 1]));
    const button_y = content_end + 4;
    if (logical_my >= button_y and logical_my < button_y + BTN_H) {
        return HitTarget{ .buttons = {} };
    }
    return HitTarget{ .none = {} };
}

pub fn tabRowY(shell_idx: u32) ?i32 {
    var rows: [MAX_ROWS]Row = undefined;
    const n = layoutRows(&rows);
    for (0..n) |ri| {
        if (rows[ri].kind == .tab and rows[ri].shell_idx == shell_idx) return rows[ri].y;
    }
    return null;
}

fn drawSidebarLabel(hdc: HANDLE, column: RECT, y: i32, height: i32, text: [*]const u16, len: i32) void {
    _ = SelectObject(hdc, uiFontSubtitle());
    const reader = @import("themes.zig").themeReaderDark();
    _ = SetTextColor(hdc, customColorOr("muted", if (app_state.g_light_theme) RGB(105, 105, 105) else if (reader) tokens.ReaderHint else RGB(98, 102, 109)));
    var rc = RECT{ .left = column.left + uiScaled(12), .top = y, .right = column.right - uiScaled(8), .bottom = y + height };
    if (!reader and !app_state.g_chat_active) {
        _ = DrawTextW(hdc, text, len, &rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        return;
    }
    var upper: [128]u16 = undefined;
    var n: usize = 0;
    while (n < upper.len and (if (len < 0) text[n] != 0 else n < @as(usize, @intCast(len)))) : (n += 1) {
        upper[n] = if (text[n] >= 'a' and text[n] <= 'z') text[n] - 32 else text[n];
    }
    _ = DrawTextW(hdc, &upper, @intCast(n), &rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
}

fn paintChatSidebarRow(hdc: HANDLE, column: RECT, y: i32, index: usize) void {
    const shell = &app_state.shells[index];
    const hovered = app_state.g_sidebar_hover == index;
    const hint = if (app_state.g_light_theme) RGB(105, 105, 105) else tokens.ReaderHint;
    var right = column.right - uiScaled(12);
    if (hovered) {
        right -= uiScaled(18);
        _ = SelectObject(hdc, uiFontClose());
        _ = SetTextColor(hdc, hint);
        var close = RECT{ .left = right, .top = y, .right = column.right - uiScaled(8), .bottom = y + tabRowH() };
        _ = DrawTextW(hdc, L("\u{00d7}"), -1, &close, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
        var time: [24]u16 = undefined;
        const time_len = inboxRelTime(shell.last_active, &time);
        if (time_len > 0) {
            _ = SelectObject(hdc, uiFontSubtitle());
            var measure: RECT = std.mem.zeroes(RECT);
            _ = DrawTextW(hdc, &time, @intCast(time_len), &measure, DT_SINGLELINE | DT_CALCRECT | DT_NOPREFIX);
            var stamp = RECT{ .left = right - measure.right - uiScaled(6), .top = y, .right = right - uiScaled(6), .bottom = y + tabRowH() };
            _ = DrawTextW(hdc, &time, @intCast(time_len), &stamp, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
            right = stamp.left - uiScaled(6);
        }
    }
    if (shell.needs_attention) {
        drawAttentionDot(hdc, right - uiScaled(4), y + @divTrunc(tabRowH(), 2), uiScaled(3), RGB(137, 180, 248));
        right -= uiScaled(14);
    }
    _ = SelectObject(hdc, uiFontTitle());
    _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(28, 28, 28) else tokens.ReaderForeground);
    var name = RECT{ .left = column.left + uiScaled(12), .top = y, .right = right, .bottom = y + tabRowH() };
    if (shell.name_len > 0) _ = DrawTextW(hdc, &shell.name, @intCast(shell.name_len), &name, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
}

pub fn paintSidebar(hdc: HANDLE) void {
    var canvas = @import("smooth.zig").Canvas.init(hdc);
    defer canvas.deinit();
    if (app_state.g_main_hwnd == null) return;

    const font_title = uiFontTitle();
    const font_shell_tab_title = uiFontShellTabTitle();
    const font_subtitle = uiFontSubtitle();
    const font_status_card = uiFontStatusCard();
    const old_font = SelectObject(hdc, font_title);
    _ = SetBkMode(hdc, TRANSPARENT);

    if (app_state.g_all_sessions_active) {
        paintAllSessions(hdc);
        _ = SelectObject(hdc, old_font);
        return;
    }

    if (app_state.g_inbox_active) {
        paintInbox(hdc);
        if (!app_state.g_search_active) {
            _ = SelectObject(hdc, old_font);
            return;
        }
    }

    if (!app_state.g_inbox_active) {
        var client_rc: RECT = std.mem.zeroes(RECT);
        _ = GetClientRect(app_state.g_main_hwnd, &client_rc);

        var sidebar_rc = RECT{ .left = 0, .top = 0, .right = SIDEBAR_W(), .bottom = client_rc.bottom };
        const sidebar_bg = themeSidebarBg();
        const bg_brush = CreateSolidBrush(sidebar_bg);
        _ = FillRect(hdc, &sidebar_rc, bg_brush);
        _ = DeleteObject(bg_brush);

        if (LOOK_UNIFIED and !app_state.g_hide_sidebar) {
            var div_rc = RECT{ .left = SIDEBAR_W() - 1, .top = 0, .right = SIDEBAR_W(), .bottom = client_rc.bottom };
            const div_col: DWORD = customColorOr("overlay_divider", if (app_state.g_light_theme) RGB(228, 228, 228) else if (app_state.g_edge_gray_theme) RGB(72, 72, 72) else RGB(52, 52, 52));
            const div_brush = CreateSolidBrush(div_col);
            _ = FillRect(hdc, &div_rc, div_brush);
            _ = DeleteObject(div_brush);
        }

        var right_rc = RECT{ .left = SIDEBAR_W(), .top = 0, .right = client_rc.right, .bottom = client_rc.bottom };
        const black_brush = CreateSolidBrush(themeConsoleBg());
        _ = FillRect(hdc, &right_rc, black_brush);
        _ = DeleteObject(black_brush);
        if (app_state.g_starred_workspace and (app_state.active_shell >= app_state.shell_count or !@import("workspaces.zig").starredShellVisible(app_state.active_shell))) {
            _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(80, 80, 80) else RGB(180, 180, 180));
            var empty_rc = right_rc;
            empty_rc.left += 24;
            empty_rc.top += 48;
            var starred_rows: [MAX_ROWS]Row = undefined;
            const message = if (layoutRows(&starred_rows) == 0) L("No starred sessions. Press Alt+S on a session to star it.") else L("Select a starred session.");
            _ = DrawTextW(hdc, message, -1, &empty_rc, @import("win32.zig").DT_WORDBREAK | DT_NOPREFIX);
        }

        paintThreadTitle(hdc, client_rc.right);

        if ((app_state.g_search_active or app_state.g_shortcuts_active or app_state.g_changelog_active) and app_state.g_search_backdrop_bmp != null) {
            const src_dc = CreateCompatibleDC(hdc);
            if (src_dc != null) {
                const old_bmp = SelectObject(src_dc, app_state.g_search_backdrop_bmp);
                const draw_w = @min(app_state.g_search_backdrop_w, right_rc.right - right_rc.left);
                const draw_h = @min(app_state.g_search_backdrop_h, right_rc.bottom - right_rc.top);
                if (draw_w > 0 and draw_h > 0) {
                    var bx = SIDEBAR_W() + SHELL_PAD;
                    var by: i32 = SHELL_PAD;
                    var blit_w = draw_w;
                    if (app_state.g_chat_active) {
                        const pane = chatViewLayout().pane;
                        bx = pane.left;
                        by = pane.top;
                    } else if (paletteAnchoredBesideBrowser()) {
                        if (calcBrowserLayout()) |bl| {
                            bx = bl.console_x;
                            by = bl.console_y;
                            const region_w = bl.splitter_left - bl.console_x;
                            if (blit_w > region_w) blit_w = region_w;
                        }
                    } else if (LOOK_UNIFIED) {
                        const pane = @import("window_layout.zig").activePaneRects(client_rc).primary;
                        blit_w = @min(blit_w, pane.right - pane.left);
                        bx = pane.left + @divTrunc(pane.right - pane.left - blit_w, 2);
                        by = pane.top + threadTitleHeight();
                    }
                    _ = BitBlt(hdc, bx, by, blit_w, draw_h, src_dc, 0, 0, GDI_SRCCOPY);
                }
                _ = SelectObject(src_dc, old_bmp);
                _ = DeleteDC(src_dc);
            }
        }

        clampSidebarScroll();

        var rows_arr: [MAX_ROWS]Row = undefined;
        const row_count = if (app_state.g_hide_sidebar) 0 else layoutRows(&rows_arr);
        const column = @import("window_layout.zig").activePaneRects(client_rc).sidebar;

        for (0..row_count) |ri| {
            const row = rows_arr[ri];
            const y: i32 = row.y - app_state.g_sidebar_scroll;

            if (row.kind == .section) {
                const section_label: LPCWSTR = switch (row.section_tier) {
                    .pinned => L("Pinned"),
                    .recent => L("Recents"),
                };
                drawSidebarLabel(hdc, column, y, SECTION_HEADER_H, section_label, -1);
                _ = SelectObject(hdc, font_title);
                continue;
            }

            if (row.kind == .header) {
                const gidx = row.gidx;
                if (gidx >= app_state.group_count) continue;
                _ = SetTextColor(hdc, customColorOr("text_inactive", if (app_state.g_light_theme) RGB(60, 60, 60) else RGB(220, 220, 220)));

                if (app_state.g_sidebar_collapsed) {
                    _ = SelectObject(hdc, font_title);
                    const chev: LPCWSTR = if (app_state.groups[gidx].collapsed) L("\u{25B8}") else L("\u{25BE}");
                    var chev_rc = RECT{ .left = 0, .top = y, .right = SIDEBAR_W(), .bottom = y + GROUP_HEADER_H };
                    _ = DrawTextW(hdc, chev, -1, &chev_rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER);
                } else {
                    if (app_state.groups[gidx].name_len > 0) {
                        drawSidebarLabel(hdc, column, y, GROUP_HEADER_H, @ptrCast(&app_state.groups[gidx].name), @intCast(app_state.groups[gidx].name_len));
                    } else {
                        drawSidebarLabel(hdc, column, y, GROUP_HEADER_H, L("(unnamed group)"), -1);
                    }
                }
                continue;
            }

            if (row.kind == .inbox) {
                const session = app_state.g_inbox_rows[row.shell_idx];
                _ = SelectObject(hdc, font_title);
                _ = SetTextColor(hdc, customColorOr("text_inactive", if (app_state.g_light_theme) RGB(60, 60, 60) else RGB(220, 220, 220)));
                drawFavoriteDot(hdc, 12, y + @divTrunc(tabRowH(), 2));
                var name: [64]u16 = undefined;
                const name_len = asciiToU16(session.name[0..session.name_len], &name);
                var name_rc = RECT{ .left = 24, .top = y, .right = SIDEBAR_W() - 8, .bottom = y + tabRowH() };
                _ = DrawTextW(hdc, &name, @intCast(name_len), &name_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                continue;
            }

            const i: usize = row.shell_idx;

            if (i == app_state.active_shell and LOOK_UNIFIED) {
                const reader = @import("themes.zig").themeReaderDark();
                const hl = if (app_state.g_multiprompt_theme) customColorOr("active_tab_bg", RGB(25, 26, 27)) else if (app_state.g_amoled_theme) RGB(42, 42, 42) else tintColor(sidebar_bg, RGB(160, 160, 160), 1, 6);
                const hl_brush = CreateSolidBrush(if (reader or (app_state.g_chat_active and !app_state.g_light_theme)) tokens.ReaderControl else hl);
                const hl_pen = CreatePen(0, 1, if (reader or (app_state.g_chat_active and !app_state.g_light_theme)) tokens.ReaderOutline else customColorOr("overlay_border", hl));
                const hl_radius: i32 = if (reader or app_state.g_chat_active) tabRowH() - 6 else 8;
                const ob = SelectObject(hdc, hl_brush);
                const op = SelectObject(hdc, hl_pen);
                _ = @import("smooth.zig").drawRoundRect(hdc, column.left, y + 3, column.right, y + tabRowH() - 3, hl_radius, hl_radius);
                _ = SelectObject(hdc, ob);
                _ = SelectObject(hdc, op);
                _ = DeleteObject(hl_brush);
                _ = DeleteObject(hl_pen);
            } else if (i == app_state.active_shell) {
                const act_color: DWORD = themeConsoleBg();
                const sidebar_color: DWORD = sidebar_bg;
                const pad: i32 = 4;
                const radius: i32 = 8;
                const sw = SIDEBAR_W();
                const tab_top = y + 2;
                const tab_bot = y + tabRowH() - 2;

                _ = sidebar_color;
                const act_brush = CreateSolidBrush(act_color);
                const act_pen = CreatePen(0, 1, act_color);
                const old_br = SelectObject(hdc, act_brush);
                const old_pn = SelectObject(hdc, act_pen);
                _ = @import("smooth.zig").drawRoundRect(hdc, pad, tab_top, sw + radius, tab_bot, radius, radius);
                _ = SelectObject(hdc, old_br);
                _ = SelectObject(hdc, old_pn);
                _ = DeleteObject(act_brush);
                _ = DeleteObject(act_pen);
            }

            if (app_state.shells[i].selected) {
                const sel_color: DWORD = customColorOr("accent", RGB(80, 150, 255));
                const sel_pen = CreatePen(0, 2, sel_color);
                if (sel_pen != null) {
                    const old_pen = SelectObject(hdc, sel_pen);
                    const old_brush = SelectObject(hdc, GetStockObject(NULL_BRUSH));
                    _ = @import("smooth.zig").drawRoundRect(hdc, column.left, y + 4, column.right, y + tabRowH() - 4, 9, 9);
                    _ = SelectObject(hdc, old_brush);
                    _ = SelectObject(hdc, old_pen);
                    _ = DeleteObject(sel_pen);
                }
            }

            if (app_state.drag_active and i != app_state.drag_src) {}

            if (app_state.g_chat_active and !app_state.g_sidebar_collapsed) {
                paintChatSidebarRow(hdc, column, y, i);
            } else if (app_state.g_sidebar_collapsed) {
                const sw = SIDEBAR_W();

                var kind_rc = RECT{ .left = 0, .top = y, .right = sw - 1, .bottom = y + tabRowH() };
                if (chatDraftHasForShell(@intCast(i))) kind_rc.bottom -= uiScaled(14);
                if (app_state.shells[i].disconnected) {
                    drawAttentionDot(hdc, @divTrunc(kind_rc.left + kind_rc.right, 2), @divTrunc(kind_rc.top + kind_rc.bottom, 2), 4, RGB(255, 145, 55));
                } else if (app_state.shells[i].needs_attention) {
                    drawAttentionDot(hdc, @divTrunc(kind_rc.left + kind_rc.right, 2), @divTrunc(kind_rc.top + kind_rc.bottom, 2), 4, customColorOr("attention", RGB(60, 120, 220)));
                } else if (app_state.shells[i].ai_agent != 0) {
                    drawAgentIcon(hdc, &kind_rc, app_state.shells[i].ai_agent, app_state.shells[i].activity == .active);
                } else {
                    _ = SelectObject(hdc, font_title);
                    _ = SetTextColor(hdc, if (isRemoteShellKind(app_state.shells[i].kind)) RGB(230, 140, 40) else RGB(150, 150, 150));
                    _ = DrawTextW(hdc, L("\u{2022}"), -1, &kind_rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
                }
                if (chatDraftHasForShell(@intCast(i))) {
                    _ = SelectObject(hdc, font_subtitle);
                    _ = SetTextColor(hdc, customColorOr("muted", if (app_state.g_light_theme) RGB(120, 120, 130) else RGB(150, 150, 160)));
                    var draft_rc = RECT{ .left = 0, .top = y + tabRowH() - uiScaled(14), .right = sw, .bottom = y + tabRowH() };
                    _ = DrawTextW(hdc, L("DRAFT"), -1, &draft_rc, DT_SINGLELINE | DT_CENTER | DT_NOPREFIX);
                }
                if (app_state.shells[i].favorite) {
                    drawFavoriteDot(hdc, 9, y + 10);
                }
            } else if (LOOK_UNIFIED) {
                const fav_size: i32 = uiScaled(16);
                const fav_gap: i32 = uiScaled(8);
                const left_pad: i32 = column.left + uiScaled(12);
                const icon: HANDLE = app_state.shells[i].favicon_hicon orelse switch (app_state.shells[i].kind) {
                    .cmd => app_state.g_icon_cmd,
                    .pwsh => app_state.g_icon_pwsh,
                    .bash, .gitbash => app_state.g_icon_bash,
                    else => null,
                };
                var text_left: i32 = left_pad;
                if (icon != null) {
                    _ = DrawIconEx(hdc, left_pad, y + @divFloor(tabRowH() - fav_size, 2), icon, fav_size, fav_size, 0, null, DI_NORMAL);
                    text_left = left_pad + fav_size + fav_gap;
                }
                const is_act = i == app_state.active_shell;
                const reserve: i32 = (if (is_act) @as(i32, 30) else 12) + (if (app_state.shells[i].favorite) FAVORITE_DOT_D + 4 else 0);
                var text_right = SIDEBAR_W() - reserve;
                if (app_state.shells[i].favorite) {
                    drawFavoriteDot(hdc, text_right + 2 + @divTrunc(FAVORITE_DOT_D, 2), y + @divFloor(tabRowH(), 2));
                }
                var eta_num_buf: [16]u16 = undefined;
                var eta_num_len: usize = 0;
                var eta_num_overdue = false;
                var eta_num_w: i32 = 0;
                if (app_state.g_eta_numbers_on and app_state.shells[i].eta_total_ms > 0) {
                    var eb: [16]u8 = undefined;
                    const remaining_ms: i64 = etaRemainingMs(app_state.shells[i].eta_deadline_tick, GetTickCount64());
                    const txt = formatEtaRemaining(remaining_ms, &eb);
                    eta_num_overdue = remaining_ms < 0;
                    eta_num_len = asciiToU16(txt, &eta_num_buf);
                    if (eta_num_len > 0) {
                        _ = SelectObject(hdc, font_subtitle);
                        var measure_rc = RECT{ .left = 0, .top = 0, .right = 0, .bottom = 0 };
                        _ = DrawTextW(hdc, @ptrCast(&eta_num_buf), @intCast(eta_num_len), &measure_rc, DT_SINGLELINE | DT_NOPREFIX | DT_CALCRECT);
                        eta_num_w = measure_rc.right - measure_rc.left;
                        text_right -= eta_num_w + 6;
                    }
                }
                if (chatDraftHasForShell(@intCast(i))) {
                    _ = SelectObject(hdc, font_subtitle);
                    _ = SetTextColor(hdc, customColorOr("muted", if (app_state.g_light_theme) RGB(120, 120, 130) else RGB(150, 150, 160)));
                    var draft_rc = RECT{ .left = 0, .top = 0, .right = 0, .bottom = 0 };
                    _ = DrawTextW(hdc, L("DRAFT"), -1, &draft_rc, DT_SINGLELINE | DT_NOPREFIX | DT_CALCRECT);
                    const draft_w = draft_rc.right;
                    draft_rc = .{ .left = text_right - draft_w, .top = y, .right = text_right, .bottom = y + tabRowH() };
                    _ = DrawTextW(hdc, L("DRAFT"), -1, &draft_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    text_right -= draft_w + 6;
                }
                if (app_state.shells[i].disconnected or app_state.shells[i].needs_attention or app_state.shells[i].ai_agent != 0) {
                    var ag_sb_rc = RECT{ .left = text_left, .top = y, .right = text_left + 14, .bottom = y + tabRowH() };
                    if (app_state.shells[i].disconnected) {
                        drawAttentionDot(hdc, @divTrunc(ag_sb_rc.left + ag_sb_rc.right, 2), @divTrunc(ag_sb_rc.top + ag_sb_rc.bottom, 2), 4, RGB(255, 145, 55));
                    } else if (app_state.shells[i].needs_attention) {
                        drawAttentionDot(hdc, @divTrunc(ag_sb_rc.left + ag_sb_rc.right, 2), @divTrunc(ag_sb_rc.top + ag_sb_rc.bottom, 2), 4, customColorOr("attention", RGB(60, 120, 220)));
                    } else {
                        drawAgentIcon(hdc, &ag_sb_rc, app_state.shells[i].ai_agent, app_state.shells[i].activity == .active);
                    }
                    text_left += 18;
                }
                if (app_state.shells[i].browser_enabled) {
                    if (app_state.shells[i].keep_awake) {
                        var kaw_sb_rc = RECT{ .left = text_left, .top = y, .right = text_left + 14, .bottom = y + tabRowH() };
                        _ = SelectObject(hdc, font_title);
                        _ = SetTextColor(hdc, if (is_act) RGB(100, 180, 220) else RGB(70, 130, 160));
                        _ = DrawTextW(hdc, L("\u{25C9}"), -1, &kaw_sb_rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
                        text_left += 18;
                    } else if (app_state.shells[i].browser_frozen or app_state.shells[i].browser_suspended) {
                        var frz_sb_rc = RECT{ .left = text_left, .top = y, .right = text_left + 14, .bottom = y + tabRowH() };
                        _ = SelectObject(hdc, font_title);
                        _ = SetTextColor(hdc, customColorOr("muted", if (app_state.g_light_theme) RGB(140, 140, 150) else RGB(120, 120, 130)));
                        _ = DrawTextW(hdc, L("z"), -1, &frz_sb_rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
                        text_left += 18;
                    }
                }
                _ = SelectObject(hdc, font_shell_tab_title);
                const title_color: DWORD = if (app_state.g_light_theme) RGB(20, 20, 20) else RGB(255, 255, 255);
                _ = SetTextColor(hdc, title_color);
                if (app_state.shells[i].name_len > 0) {
                    var line_rc = RECT{ .left = text_left, .top = y, .right = text_right, .bottom = y + tabRowH() };
                    _ = SetTextCharacterExtra(hdc, DEV_LETTER_SPACING);
                    _ = DrawTextW(hdc, @ptrCast(&app_state.shells[i].name), @intCast(app_state.shells[i].name_len), &line_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                    _ = SetTextCharacterExtra(hdc, 0);
                }
                _ = SelectObject(hdc, font_title);
                if (is_act) {
                    const font_close = uiFontClose();
                    _ = SelectObject(hdc, font_close);
                    _ = SetTextColor(hdc, customColorOr("muted", RGB(170, 178, 190)));
                    var x_rc = RECT{ .left = SIDEBAR_W() - 26, .top = y, .right = SIDEBAR_W() - 8, .bottom = y + tabRowH() };
                    _ = DrawTextW(hdc, L("\u{00d7}"), -1, &x_rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER);
                    _ = SelectObject(hdc, font_title);
                }
                if (eta_num_len > 0) {
                    _ = SelectObject(hdc, font_subtitle);
                    const eta_muted = customColorOr("muted", if (app_state.g_light_theme) RGB(120, 120, 130) else RGB(150, 150, 160));
                    _ = SetTextColor(hdc, if (eta_num_overdue) etaOverdueColor() else eta_muted);
                    var eta_rc = RECT{ .left = SIDEBAR_W() - reserve - eta_num_w, .top = y, .right = SIDEBAR_W() - reserve, .bottom = y + tabRowH() };
                    _ = DrawTextW(hdc, @ptrCast(&eta_num_buf), @intCast(eta_num_len), &eta_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    _ = SelectObject(hdc, font_title);
                }
                if (app_state.g_eta_progress_on and app_state.shells[i].eta_total_ms > 0) {
                    const bar_remaining_ms = etaRemainingMs(app_state.shells[i].eta_deadline_tick, GetTickCount64());
                    const elapsed_ms: i64 = etaElapsedMs(app_state.shells[i].eta_total_ms, bar_remaining_ms);
                    const overdue = bar_remaining_ms < 0;
                    const frac = if (overdue) @as(f32, 1) else etaFillFraction(elapsed_ms, app_state.shells[i].eta_total_ms);
                    const track_left = 8;
                    const track_right = SIDEBAR_W() - 8;
                    const track_w = track_right - track_left;
                    if (track_w > 0) {
                        const fill_w: i32 = @intFromFloat(@as(f32, @floatFromInt(track_w)) * frac);
                        const line_top = y + tabRowH() - 6;
                        const line_bottom = line_top + 2;
                        const progress_color = if (overdue) etaOverdueColor() else customColorOr("accent", RGB(79, 168, 255));
                        if (fill_w > 0) {
                            var fill_rc = RECT{ .left = track_left, .top = line_top, .right = track_left + fill_w, .bottom = line_bottom };
                            const fill_br = CreateSolidBrush(progress_color);
                            _ = FillRect(hdc, &fill_rc, fill_br);
                            _ = DeleteObject(fill_br);
                        }
                    }
                }
            } else {
                const base_text_left: i32 = 12;
                const fav_size: i32 = 16;
                const fav_gap: i32 = 6;
                const has_fav = app_state.shells[i].favicon_hicon != null;
                if (has_fav) {
                    _ = DrawIconEx(hdc, base_text_left, y + 8, app_state.shells[i].favicon_hicon.?, fav_size, fav_size, 0, null, DI_NORMAL);
                }
                var text_left: i32 = if (has_fav) base_text_left + fav_size + fav_gap else base_text_left;
                if (app_state.shells[i].disconnected) {
                    drawAttentionDot(hdc, text_left + 7, y + @divFloor(tabRowH(), 2), 4, RGB(255, 145, 55));
                    text_left += 18;
                } else if (app_state.shells[i].needs_attention) {
                    drawAttentionDot(hdc, text_left + 7, y + @divFloor(tabRowH(), 2), 4, customColorOr("attention", RGB(60, 120, 220)));
                    text_left += 18;
                }
                var text_right = SIDEBAR_W() - 32 - (if (app_state.shells[i].favorite) FAVORITE_DOT_D + 4 else 0);
                if (chatDraftHasForShell(@intCast(i))) {
                    _ = SelectObject(hdc, font_subtitle);
                    _ = SetTextColor(hdc, customColorOr("muted", if (app_state.g_light_theme) RGB(120, 120, 130) else RGB(150, 150, 160)));
                    var draft_rc = RECT{ .left = 0, .top = 0, .right = 0, .bottom = 0 };
                    _ = DrawTextW(hdc, L("DRAFT"), -1, &draft_rc, DT_SINGLELINE | DT_NOPREFIX | DT_CALCRECT);
                    const draft_w = draft_rc.right;
                    draft_rc = .{ .left = text_right - draft_w, .top = y + 6, .right = text_right, .bottom = y + 26 };
                    _ = DrawTextW(hdc, L("DRAFT"), -1, &draft_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    text_right -= draft_w + 6;
                }

                if (app_state.shells[i].favorite) {
                    drawFavoriteDot(hdc, text_right + 2 + @divTrunc(FAVORITE_DOT_D, 2), y + 16);
                }
                _ = SelectObject(hdc, font_shell_tab_title);
                const title_white: DWORD = if (@import("themes.zig").themeReaderDark()) tokens.ReaderForeground else RGB(255, 255, 255);
                const title_color: DWORD = if (i == app_state.active_shell) customColorOr("text", title_white) else customColorOr("text_inactive", if (app_state.g_light_theme) RGB(25, 25, 25) else title_white);
                _ = SetTextColor(hdc, title_color);
                var line1_rc = RECT{ .left = text_left, .top = y + 6, .right = text_right, .bottom = y + 26 };
                if (app_state.shells[i].name_len > 0) {
                    var measure_rc = line1_rc;
                    _ = DrawTextW(hdc, @ptrCast(&app_state.shells[i].name), @intCast(app_state.shells[i].name_len), &measure_rc, DT_SINGLELINE | DT_NOPREFIX | DT_CALCRECT);
                    _ = DrawTextW(hdc, @ptrCast(&app_state.shells[i].name), @intCast(app_state.shells[i].name_len), &line1_rc, DT_SINGLELINE | DT_NOPREFIX);

                    _ = SelectObject(hdc, font_subtitle);
                    const tag_color = if (app_state.shells[i].kind == .tmux)
                        themeTagTmux(i == app_state.active_shell, if (app_state.g_light_theme and i != app_state.active_shell) RGB(30, 120, 30) else if (i == app_state.active_shell) RGB(100, 180, 100) else RGB(70, 140, 70))
                    else if (app_state.shells[i].keep_alive)
                        themeTagVps(i == app_state.active_shell, if (app_state.g_light_theme and i != app_state.active_shell) RGB(30, 90, 180) else if (i == app_state.active_shell) RGB(100, 160, 240) else RGB(70, 120, 190))
                    else
                        themeTagNeutral(i == app_state.active_shell, if (app_state.g_light_theme and i != app_state.active_shell) RGB(100, 100, 110) else if (i == app_state.active_shell) RGB(140, 140, 150) else RGB(100, 100, 110));
                    _ = SetTextColor(hdc, tag_color);
                    var tag_buf: [20]u16 = undefined;
                    var tbi: usize = 0;
                    const kind_str: []const u8 = switch (app_state.shells[i].kind) {
                        .cmd => "CMD",
                        .pwsh => "PWS",
                        .vps => "VPS",
                        .tmux => "TMX",
                        .vps2 => "VPS",
                        .bash => "BSH",
                        .gitbash => "GIT",
                    };
                    for (kind_str) |c| {
                        tag_buf[tbi] = c;
                        tbi += 1;
                    }
                    if (app_state.shells[i].ram_mb > 0) {
                        tag_buf[tbi] = ' ';
                        tbi += 1;
                        var ram_val = app_state.shells[i].ram_mb;
                        var ram_digits: [6]u8 = undefined;
                        var rdi: usize = 0;
                        while (ram_val > 0) : (rdi += 1) {
                            ram_digits[rdi] = @intCast(ram_val % 10 + '0');
                            ram_val /= 10;
                        }
                        if (rdi == 0) {
                            ram_digits[0] = '0';
                            rdi = 1;
                        }
                        while (rdi > 0) {
                            rdi -= 1;
                            tag_buf[tbi] = ram_digits[rdi];
                            tbi += 1;
                        }
                        tag_buf[tbi] = 'M';
                        tbi += 1;
                    }
                    var tag_rc = RECT{ .left = measure_rc.right + 6, .top = y + 8, .right = text_right, .bottom = y + 26 };
                    _ = DrawTextW(hdc, @ptrCast(&tag_buf), @intCast(tbi), &tag_rc, DT_SINGLELINE | DT_NOPREFIX);

                    _ = SelectObject(hdc, font_title);
                }
                _ = SelectObject(hdc, font_title);

                const sub_len: usize = if (app_state.shells[i].last_title_len > 0) @intCast(app_state.shells[i].last_title_len) else 0;
                const show_subtitle = sub_len > 0 and !u16SliceEql(
                    app_state.shells[i].last_title[0..sub_len],
                    app_state.shells[i].name[0..app_state.shells[i].name_len],
                );
                if (show_subtitle) {
                    _ = SelectObject(hdc, font_subtitle);
                    const sub_color: DWORD = if (i == app_state.active_shell) customColorOr("subtitle", RGB(220, 220, 220)) else customColorOr("subtitle", if (app_state.g_light_theme) RGB(90, 90, 90) else RGB(220, 220, 220));
                    _ = SetTextColor(hdc, sub_color);
                    var line2_rc = RECT{ .left = text_left, .top = y + 28, .right = text_right, .bottom = y + 44 };
                    _ = DrawTextW(hdc, @ptrCast(&app_state.shells[i].last_title), @intCast(app_state.shells[i].last_title_len), &line2_rc, DT_SINGLELINE | DT_NOPREFIX);
                    _ = SelectObject(hdc, font_title);
                }

                if (i == app_state.active_shell) {
                    const font_close = uiFontClose();
                    _ = SelectObject(hdc, font_close);
                    _ = SetTextColor(hdc, customColorOr("muted", RGB(180, 180, 180)));
                    var x_rc = RECT{ .left = SIDEBAR_W() - 28, .top = y, .right = SIDEBAR_W() - 6, .bottom = y + tabRowH() };
                    _ = DrawTextW(hdc, L("\u{00d7}"), -1, &x_rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER);
                    _ = SelectObject(hdc, font_title);
                }
            }
        }

        const content_end_logical: i32 = if (row_count == 0) 0 else (rows_arr[row_count - 1].y + rowTotalHeight(rows_arr[row_count - 1]));
        const btns_y: i32 = content_end_logical + 4 - app_state.g_sidebar_scroll;
        if (!app_state.g_hide_sidebar) {
            _ = SelectObject(hdc, font_subtitle);
            _ = SetTextColor(hdc, customColorOr("muted", if (app_state.g_light_theme) RGB(80, 80, 80) else RGB(180, 180, 180)));
            var btn_rc = RECT{ .left = column.left + uiScaled(12), .top = btns_y, .right = column.right - uiScaled(8), .bottom = btns_y + BTN_H };
            _ = DrawTextW(hdc, L("+"), -1, &btn_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | (if (app_state.g_sidebar_collapsed) DT_CENTER else 0));
            _ = SelectObject(hdc, font_title);

            if (app_state.g_unread_only and !app_state.g_sidebar_collapsed) {
                const uo_blue = customColorOr("attention", RGB(60, 120, 220));
                _ = SelectObject(hdc, font_subtitle);
                _ = SetTextColor(hdc, uo_blue);
                const uo_left = @max(@as(i32, 12), SIDEBAR_W() - 140);
                var uo_sb_rc = RECT{ .left = uo_left, .top = btns_y, .right = SIDEBAR_W() - 8, .bottom = btns_y + BTN_H };
                _ = DrawTextW(hdc, L("UNREAD ONLY"), -1, &uo_sb_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
            }
        }

        const sidebar_content_h = sidebarContentH();
        const sidebar_vis_h = sidebarVisibleH();
        if (devThemeOn() and sidebar_content_h > sidebar_vis_h and SIDEBAR_W() > 20) {
            const track_top: i32 = 6;
            const track_bottom: i32 = client_rc.bottom - sidebarStickyCardSpan();
            const track_h = track_bottom - track_top;
            if (track_h > 0) {
                var track_rc = RECT{ .left = SIDEBAR_W() - 5, .top = track_top, .right = SIDEBAR_W() - 2, .bottom = track_bottom };
                const track_br = CreateSolidBrush(customColorOr("scrollbar_track", if (app_state.g_light_theme) RGB(218, 218, 218) else if (app_state.g_edge_gray_theme) RGB(72, 72, 72) else if (app_state.g_mid_theme) RGB(92, 92, 92) else RGB(66, 66, 66)));
                _ = FillRect(hdc, &track_rc, track_br);
                _ = DeleteObject(track_br);

                const thumb_ratio_h: i32 = @divTrunc(track_h * sidebar_vis_h, sidebar_content_h);
                const thumb_h: i32 = @min(track_h, @max(24, thumb_ratio_h));
                const max_scroll: i32 = sidebar_content_h - sidebar_vis_h;
                const scroll_space = track_h - thumb_h;
                const thumb_top = track_top + if (max_scroll <= 0) 0 else @divTrunc(scroll_space * app_state.g_sidebar_scroll, max_scroll);
                var thumb_rc = RECT{ .left = SIDEBAR_W() - 6, .top = thumb_top, .right = SIDEBAR_W() - 1, .bottom = thumb_top + thumb_h };
                const thumb_br = CreateSolidBrush(customColorOr("scrollbar_thumb", if (app_state.g_light_theme) RGB(145, 145, 145) else if (app_state.g_edge_gray_theme) RGB(150, 150, 150) else if (app_state.g_mid_theme) RGB(160, 160, 160) else RGB(145, 145, 145)));
                _ = FillRect(hdc, &thumb_rc, thumb_br);
                _ = DeleteObject(thumb_br);
            }
        }

        paintSidebarStickyStatusCard(hdc, font_status_card);
        paintSidebarUpdateCard(hdc, font_title, font_status_card);

        paintWorkspaceStrip(hdc, sidebar_bg);
        @import("workspace_switcher.zig").paintHeader(hdc);
        paintSidebarStatusCardPopup(hdc, font_title, font_status_card);
    }

    if (app_state.g_search_active) {
        var win_rc: RECT = std.mem.zeroes(RECT);
        _ = GetClientRect(app_state.g_main_hwnd, &win_rc);
        const win_w = win_rc.right - win_rc.left;
        const win_h = win_rc.bottom - win_rc.top;

        const palette_font = CreateFontW(-uiScaled(14), 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 5, 0, L(@import("fonts.zig").UI_FACE));
        const palette_hint_font = CreateFontW(-uiScaled(12), 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 5, 0, L(@import("fonts.zig").UI_FACE));
        const palette_old_font = SelectObject(hdc, palette_font);
        defer {
            _ = SelectObject(hdc, palette_old_font);
            _ = DeleteObject(palette_font);
            _ = DeleteObject(palette_hint_font);
        }
        const overlay_w: i32 = searchOverlayW();
        const row_h: i32 = searchRowH();
        const input_h: i32 = searchInputH();
        const visible_capacity: u32 = @min(app_state.g_search_result_count, @import("drawing.zig").searchVisibleRows());
        const overlay_h: i32 = @import("drawing.zig").searchFooterH() + input_h + if (app_state.g_search_rename_input_mode)
            row_h
        else
            @as(i32, @intCast(visible_capacity)) * row_h + if (!app_state.g_browser_url_mode and !app_state.g_search_remind_input_mode and app_state.g_search_result_count == 0 and app_state.g_search_len > 0) row_h else 0;
        const ox = searchOverlayOx(win_w, overlay_w);
        const oy = @import("drawing.zig").searchOverlayOy(win_h, overlay_h);
        const overlay_radius: i32 = uiScaled(32);
        @import("dialog.zig").dim(hdc, win_w, win_h);

        drawModalShadow(hdc, ox, oy, overlay_w, overlay_h, overlay_radius);

        const overlay_border_col = customColorOr("overlay_border", if (app_state.g_light_theme) RGB(200, 200, 200) else RGB(0x2E, 0x2E, 0x2E));
        const border_br = CreateSolidBrush(overlay_border_col);
        const border_pen = CreatePen(0, 1, overlay_border_col);
        const old_brush_b = SelectObject(hdc, border_br);
        const old_pen_b = SelectObject(hdc, border_pen);
        _ = @import("smooth.zig").drawRoundRect(hdc, ox - 1, oy - 1, ox + overlay_w + 1, oy + overlay_h + 1, overlay_radius, overlay_radius);
        _ = SelectObject(hdc, old_brush_b);
        _ = SelectObject(hdc, old_pen_b);
        _ = DeleteObject(border_br);
        _ = DeleteObject(border_pen);

        const overlay_bg_col = customColorOr("overlay_bg", if (app_state.g_light_theme) RGB(249, 249, 249) else RGB(0x18, 0x18, 0x18));
        const bg_br = CreateSolidBrush(overlay_bg_col);
        const bg_pen = CreatePen(0, 1, overlay_bg_col);
        const old_brush_i = SelectObject(hdc, bg_br);
        const old_pen_i = SelectObject(hdc, bg_pen);
        _ = @import("smooth.zig").drawRoundRect(hdc, ox, oy, ox + overlay_w, oy + overlay_h, overlay_radius, overlay_radius);
        _ = SelectObject(hdc, old_brush_i);
        _ = SelectObject(hdc, old_pen_i);
        _ = DeleteObject(bg_br);
        _ = DeleteObject(bg_pen);

        var input_bg_rc = RECT{ .left = ox + uiScaled(16), .top = oy + uiScaled(16), .right = ox + overlay_w - uiScaled(16), .bottom = oy + uiScaled(56) };
        @import("smooth.zig").fillRoundRect(hdc, input_bg_rc, uiScaled(20), if (app_state.g_light_theme) RGB(220, 220, 220) else RGB(0x2E, 0x2E, 0x2E));
        input_bg_rc.left += 1;
        input_bg_rc.top += 1;
        input_bg_rc.right -= 1;
        input_bg_rc.bottom -= 1;
        @import("smooth.zig").fillRoundRect(hdc, input_bg_rc, uiScaled(20), if (app_state.g_light_theme) RGB(240, 240, 240) else RGB(0x1F, 0x1F, 0x1F));

        _ = SelectObject(hdc, palette_font);
        var input_text_rc = RECT{ .left = ox + uiScaled(32), .top = oy + uiScaled(16), .right = ox + overlay_w - uiScaled(64), .bottom = oy + uiScaled(56) };
        if (app_state.g_search_len == 0) {
            _ = SetTextColor(hdc, customColorOr("hint", if (app_state.g_light_theme) RGB(160, 160, 160) else RGB(100, 100, 100)));
            const placeholder = if (app_state.g_search_ws_sort_mode)
                L("Drag rows to reorder (or Ctrl+Up/Down). Enter switches.")
            else if (app_state.g_search_rename_input_mode)
                L("Enter a session name...")
            else if (app_state.g_browser_url_mode)
                L("Enter browser URL...")
            else if (app_state.g_search_remind_input_mode)
                L("Remind me when? 1h, tomorrow 9, 2026-06-30 09:30")
            else if (app_state.g_search_remind_preset_mode)
                L("Pick a time...")
            else if (app_state.g_search_ws_snoozed_mode)
                L("Snoozed workspaces...")
            else if (app_state.g_search_reminders_mode)
                L("Snoozed sessions...")
            else if (app_state.g_search_session_overview_mode)
                L("Search repo sessions...")
            else if (app_state.g_search_ws_move_mode)
                L("Search workspaces to move the tab to...")
            else if (app_state.g_search_group_move_mode)
                L("Search groups for this session...")
            else if (app_state.g_search_skills_mode)
                L("Search skills...")
            else if (app_state.g_search_openall_host_mode)
                L("Choose a VPS...")
            else if (app_state.g_search_tabctx_mode)
                L("Tab actions...")
            else if (app_state.g_search_snippet_mode)
                if (app_state.g_search_snippet_manage_mode) L("Manage Snippets: choose one to delete") else L("Search snippets...")
            else if (app_state.g_search_theme_mode)
                L("Search themes...")
            else if (app_state.g_search_workspace_delete_mode)
                L("Search workspaces to delete...")
            else if (app_state.g_search_workspace_mode)
                L("Search workspaces to open...")
            else
                L("Search sessions and commands");
            _ = DrawTextW(hdc, placeholder, -1, &input_text_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
        } else {
            if (app_state.g_search_rename_input_mode and app_state.g_search_rename_select_all) {
                const selected_br = CreateSolidBrush(customColorOr("selected_bg", RGB(0, 122, 204)));
                _ = FillRect(hdc, &input_text_rc, selected_br);
                _ = DeleteObject(selected_br);
                _ = SetTextColor(hdc, RGB(255, 255, 255));
            } else {
                _ = SetTextColor(hdc, customColorOr("text", if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(255, 255, 255)));
            }
            _ = DrawTextW(hdc, @ptrCast(&app_state.g_search_buf), @intCast(app_state.g_search_len), &input_text_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
        }

        if (input_h == uiScaled(96)) {
            _ = SelectObject(hdc, palette_hint_font);
            _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(100, 100, 100) else RGB(0x8A, 0x8A, 0x8A));
            var recent_rc = RECT{ .left = ox + uiScaled(28), .top = oy + uiScaled(64), .right = ox + overlay_w - uiScaled(24), .bottom = oy + input_h };
            _ = DrawTextW(hdc, L("RECENT SESSIONS"), -1, &recent_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
        }
        var esc_rc = RECT{ .left = ox + overlay_w - uiScaled(56), .top = oy + uiScaled(24), .right = ox + overlay_w - uiScaled(24), .bottom = oy + uiScaled(48) };
        @import("palette_text.zig").keycap(hdc, L("Esc"), &esc_rc);
        const footer_y = oy + overlay_h - @import("drawing.zig").searchFooterH();
        const divider = RECT{ .left = ox + uiScaled(16), .top = footer_y, .right = ox + overlay_w - uiScaled(16), .bottom = footer_y + 1 };
        const divider_br = CreateSolidBrush(if (app_state.g_light_theme) RGB(220, 220, 220) else RGB(0x2E, 0x2E, 0x2E));
        _ = FillRect(hdc, &divider, divider_br);
        _ = DeleteObject(divider_br);
        _ = SelectObject(hdc, palette_hint_font);
        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(100, 100, 100) else RGB(0x8A, 0x8A, 0x8A));
        var footer_rc = RECT{ .left = ox + uiScaled(24), .top = footer_y + 1, .right = ox + overlay_w - uiScaled(24), .bottom = oy + overlay_h };
        @import("palette_text.zig").footer(hdc, &footer_rc);

        {
            if (app_state.g_search_rename_input_mode) {
                _ = SetTextColor(hdc, customColorOr("hint", if (app_state.g_light_theme) RGB(95, 95, 95) else RGB(155, 155, 155)));
                _ = SelectObject(hdc, palette_hint_font);
                var rename_hint_rc = RECT{ .left = ox + 12, .top = oy + input_h, .right = ox + overlay_w - 12, .bottom = oy + input_h + row_h };
                _ = paletteDrawText(hdc, L("Ctrl+A selects all  ·  Enter saves  ·  Esc cancels  ·  syncs multiprompt, tmux, and agent"), -1, &rename_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
            } else if (!app_state.g_browser_url_mode and !app_state.g_search_remind_input_mode and app_state.g_search_result_count == 0 and app_state.g_search_len > 0) {
                _ = SetTextColor(hdc, customColorOr("hint", RGB(100, 100, 100)));
                _ = SelectObject(hdc, palette_hint_font);
                var no_rc = RECT{ .left = ox + 12, .top = oy + input_h, .right = ox + overlay_w - 12, .bottom = oy + input_h + row_h };
                _ = paletteDrawText(hdc, L("No matches"), -1, &no_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
            } else if (!app_state.g_browser_url_mode) {
                const visible_rows: u32 = @min(app_state.g_search_result_count -| app_state.g_search_scroll, visible_capacity);
                for (0..visible_rows) |vi| {
                    const ri = vi + app_state.g_search_scroll;
                    const result_idx = app_state.g_search_results[ri];
                    const is_skills_menu = result_idx == SEARCH_SKILLS_MENU_OFFSET;
                    const is_skills_back = result_idx == SEARCH_SKILLS_BACK_OFFSET;
                    const is_skill_row = result_idx >= SEARCH_SKILL_ROW_OFFSET and result_idx < SEARCH_SKILL_ROW_OFFSET + MAX_PALETTE_SKILLS;
                    const is_chat_reply = result_idx == SEARCH_CHAT_REPLY_OFFSET;
                    const is_clean_chat = result_idx == SEARCH_CLEAN_CHAT_OFFSET;
                    const is_chat_todo = result_idx == SEARCH_CHAT_TODO_OFFSET;
                    const is_chat_find = result_idx == SEARCH_CHAT_FIND_OFFSET;
                    const is_chat_tools = result_idx == SEARCH_CHAT_TOOL_STEPS_OFFSET;
                    const is_chat_newest = result_idx == SEARCH_CHAT_NEWEST_OFFSET;
                    const is_chat_resync = result_idx == SEARCH_CHAT_RESYNC_OFFSET;
                    const is_chat_more_menu = result_idx == SEARCH_CHAT_MORE_MENU_OFFSET;
                    const is_chat_copy = result_idx == SEARCH_CHAT_COPY_CODE_OFFSET;
                    const is_chat_attach = result_idx == SEARCH_CHAT_ATTACH_OFFSET or result_idx == SEARCH_CHAT_DICTATION_OFFSET;
                    const is_chat_copy_sel = result_idx == SEARCH_CHAT_COPY_SELECTION_OFFSET;
                    const is_chat_select_all = result_idx == SEARCH_CHAT_SELECT_ALL_OFFSET;
                    const is_chat_focus_messages = result_idx == SEARCH_CHAT_FOCUS_MESSAGES_OFFSET;
                    const is_chat_ac = result_idx == SEARCH_CHAT_AC_OFFSET;
                    const is_chat_queue_send = result_idx == SEARCH_CHAT_QUEUE_SEND_OFFSET;
                    const is_chat_reset = result_idx == SEARCH_CHAT_RESET_OFFSET;
                    const is_chat_tab_url = result_idx == SEARCH_CHAT_TAB_URL_OFFSET;
                    const is_chat_queue_clear = result_idx == SEARCH_CHAT_QUEUE_CLEAR_OFFSET;
                    const is_chat_retry_unsent = result_idx == SEARCH_CHAT_RETRY_UNSENT_OFFSET;
                    const is_chat_discard_unsent = result_idx == SEARCH_CHAT_DISCARD_UNSENT_OFFSET;
                    const is_chat_push_queued = result_idx == SEARCH_CHAT_PUSH_QUEUED_OFFSET;
                    const is_chat_edit_queued = result_idx == SEARCH_CHAT_EDIT_QUEUED_OFFSET;
                    const is_chat_action = is_chat_tab_url or is_chat_reply or is_chat_ac or is_chat_copy or is_chat_attach or is_chat_copy_sel or is_chat_select_all or is_chat_focus_messages or is_chat_queue_send or is_chat_queue_clear or is_chat_reset or is_chat_retry_unsent or is_chat_discard_unsent or is_chat_push_queued or is_chat_edit_queued;
                    const is_skill_action = is_skills_menu or is_skills_back or is_skill_row or is_chat_action;
                    const is_sync_signout = result_idx == SEARCH_SYNC_SIGNOUT_OFFSET;
                    const is_layout_pull = result_idx == SEARCH_LAYOUT_PULL_OFFSET;
                    const is_approve_devices = result_idx == SEARCH_APPROVE_DEVICES_OFFSET;
                    const is_remove_server = result_idx == SEARCH_REMOVE_SERVER_1_OFFSET or result_idx == SEARCH_REMOVE_SERVER_2_OFFSET or result_idx == SEARCH_REMOVE_SERVER_3_OFFSET;
                    const is_sync_status = result_idx == SEARCH_SYNC_STATUS_OFFSET or is_layout_pull or is_approve_devices or is_remove_server;
                    const is_addfavicon = !is_chat_action and !is_sync_signout and !is_sync_status and result_idx >= SEARCH_ADDFAVICON_OFFSET and result_idx < SEARCH_SYNC_SIGNOUT_OFFSET;
                    const is_mobile_toggle = !is_chat_action and !is_addfavicon and !is_sync_signout and !is_sync_status and result_idx >= SEARCH_MOBILE_OFFSET and result_idx < SEARCH_SYNC_SIGNOUT_OFFSET;
                    const is_session_overview_menu = result_idx == SEARCH_SESSION_OVERVIEW_MENU_OFFSET;
                    const is_session_overview_row = result_idx >= SEARCH_SESSION_OVERVIEW_ROW_OFFSET and result_idx < SEARCH_SESSION_OVERVIEW_ROW_OFFSET + MAX_SESSION_OVERVIEW_SEARCH_ROWS;
                    const is_archived_view = result_idx == SEARCH_ARCHIVED_VIEW_OFFSET;
                    const is_renamewin = !is_chat_action and !is_addfavicon and !is_mobile_toggle and !is_sync_signout and !is_sync_status and !is_session_overview_menu and !is_session_overview_row and !is_archived_view and result_idx >= SEARCH_RENAMEWIN_OFFSET;
                    const is_wsmove_workspace = app_state.g_search_ws_move_mode and !is_addfavicon and !is_mobile_toggle and !is_renamewin and result_idx >= SEARCH_WORKSPACE_OFFSET and result_idx < SEARCH_WORKSPACE_OFFSET + MAX_WORKSPACES;
                    const is_workspace = !is_chat_action and !is_addfavicon and !is_mobile_toggle and !is_sync_signout and !is_sync_status and !is_renamewin and !is_wsmove_workspace and result_idx >= SEARCH_WORKSPACE_OFFSET;
                    const is_workspace_delete = !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and result_idx >= SEARCH_WORKSPACE_DELETE_OFFSET and result_idx < SEARCH_WORKSPACE_DELETE_OFFSET + MAX_WORKSPACES;
                    const is_workspace_back = !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and result_idx == SEARCH_WORKSPACE_BACK_OFFSET;
                    const is_workspace_delete_menu = !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and !is_workspace_back and result_idx == SEARCH_WORKSPACE_DELETE_MENU_OFFSET;
                    const is_workspaces_menu = !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and !is_workspace_back and !is_workspace_delete_menu and result_idx == SEARCH_WORKSPACES_MENU_OFFSET;
                    const is_quit = !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and !is_workspace_back and !is_workspace_delete_menu and !is_workspaces_menu and result_idx == SEARCH_QUIT_OFFSET;
                    const is_fullwidth = !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and !is_workspace_back and !is_workspace_delete_menu and !is_workspaces_menu and !is_quit and result_idx == SEARCH_FULLWIDTH_OFFSET;
                    const is_shortcuts = !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and !is_workspace_back and !is_workspace_delete_menu and !is_workspaces_menu and !is_quit and !is_fullwidth and result_idx == SEARCH_SHORTCUTS_OFFSET;
                    const is_changelog = result_idx == SEARCH_CHANGELOG_OFFSET;
                    const is_closewin = !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and !is_workspace_back and !is_workspace_delete_menu and !is_workspaces_menu and !is_quit and !is_fullwidth and !is_shortcuts and result_idx == SEARCH_CLOSEWIN_OFFSET;
                    const is_reconnect = !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and !is_workspace_back and !is_workspace_delete_menu and !is_workspaces_menu and !is_quit and !is_fullwidth and !is_shortcuts and !is_closewin and result_idx == SEARCH_RECONNECT_OFFSET;
                    const is_singlewin = !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and !is_workspace_back and !is_workspace_delete_menu and !is_workspaces_menu and !is_quit and !is_fullwidth and !is_shortcuts and !is_closewin and !is_reconnect and result_idx == SEARCH_SINGLEWIN_OFFSET;
                    const is_installhook = !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and !is_workspace_back and !is_workspace_delete_menu and !is_workspaces_menu and !is_quit and !is_fullwidth and !is_shortcuts and !is_closewin and !is_reconnect and !is_singlewin and result_idx == SEARCH_INSTALLHOOK_OFFSET;
                    const is_goinbox = !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and !is_workspace_back and !is_workspace_delete_menu and !is_workspaces_menu and !is_quit and !is_fullwidth and !is_shortcuts and !is_closewin and !is_reconnect and !is_singlewin and !is_installhook and result_idx == SEARCH_GOINBOX_OFFSET;
                    const is_wssort_menu = result_idx == SEARCH_WSSORT_MENU_OFFSET;
                    const is_wssort = result_idx >= SEARCH_WSSORT_OFFSET and result_idx < SEARCH_WSSORT_OFFSET + MAX_LWS;
                    const is_wsmove_menu = result_idx == SEARCH_WSMOVE_MENU_OFFSET;
                    const is_wsmove = result_idx >= SEARCH_WSMOVE_OFFSET and result_idx < SEARCH_WSMOVE_OFFSET + MAX_LWS;
                    const is_wsmove_new = result_idx == SEARCH_WSMOVE_NEW_OFFSET;
                    const is_groupmove_menu = result_idx == SEARCH_GROUPMOVE_MENU_OFFSET;
                    const is_groupmove_back = result_idx == SEARCH_GROUPMOVE_BACK_OFFSET;
                    const is_groupmove_new = result_idx == SEARCH_GROUPMOVE_NEW_OFFSET;
                    const is_groupmove_none = result_idx == SEARCH_GROUPMOVE_NONE_OFFSET;
                    const is_groupmove_group = result_idx >= SEARCH_GROUPMOVE_GROUP_OFFSET and result_idx < SEARCH_GROUPMOVE_GROUP_OFFSET + MAX_GROUPS;
                    const is_hidesidebar = result_idx == SEARCH_HIDESIDEBAR_OFFSET;
                    const is_sidebarcollapse = result_idx == SEARCH_SIDEBAR_COLLAPSE_OFFSET;
                    const is_sidebarhide = result_idx == SEARCH_SIDEBAR_HIDE_OFFSET;
                    const is_hidepills = result_idx == SEARCH_HIDEPILLS_OFFSET;
                    const is_nextunread = result_idx == SEARCH_NEXTUNREAD_OFFSET;
                    const is_tabsort_inbox = result_idx == SEARCH_TABSORT_INBOX_OFFSET;
                    const is_tabsort_manual = result_idx == SEARCH_TABSORT_MANUAL_OFFSET;
                    const is_power_auto = result_idx == SEARCH_POWER_AUTO_OFFSET;
                    const is_power_always = result_idx == SEARCH_POWER_ALWAYS_OFFSET;
                    const is_power_off = result_idx == SEARCH_POWER_OFF_OFFSET;
                    const is_ladder = result_idx >= SEARCH_LADDER_AUTO_OFFSET and result_idx <= SEARCH_LADDER_DASH_OFFSET;
                    const is_voice_mode_on = result_idx == SEARCH_VOICE_MODE_ON_OFFSET;
                    const is_voice_mode_off = result_idx == SEARCH_VOICE_MODE_OFF_OFFSET;
                    const is_unreadonly = result_idx == SEARCH_UNREADONLY_OFFSET;
                    const is_eta_numbers = result_idx == SEARCH_ETA_NUMBERS_OFFSET;
                    const is_eta_progress = result_idx == SEARCH_ETA_PROGRESS_OFFSET;
                    const is_eta_accuracy = result_idx == SEARCH_ETA_ACCURACY_OFFSET;
                    const is_chat_view_mode_everywhere = result_idx == SEARCH_CHAT_VIEW_MODE_EVERYWHERE_OFFSET;
                    const is_chat_view_mode_nowhere = result_idx == SEARCH_CHAT_VIEW_MODE_NOWHERE_OFFSET;
                    const is_voice_stop = result_idx == SEARCH_VOICE_STOP_OFFSET;
                    const is_voice_always_on = result_idx == SEARCH_VOICE_ALWAYS_ON_OFFSET;
                    const is_voice_always_off = result_idx == SEARCH_VOICE_ALWAYS_OFF_OFFSET;
                    const is_voice_speed_100 = result_idx == SEARCH_VOICE_SPEED_100_OFFSET;
                    const is_voice_speed_125 = result_idx == SEARCH_VOICE_SPEED_125_OFFSET;
                    const is_voice_speed_140 = result_idx == SEARCH_VOICE_SPEED_140_OFFSET;
                    const is_voice_speed_150 = result_idx == SEARCH_VOICE_SPEED_150_OFFSET;
                    const is_voice_replay = result_idx == SEARCH_VOICE_REPLAY_OFFSET;
                    const is_voice_previous = result_idx == SEARCH_VOICE_PREVIOUS_OFFSET;
                    const is_voice_next = result_idx == SEARCH_VOICE_NEXT_OFFSET;
                    const is_threadtitle = result_idx == SEARCH_THREADTITLE_OFFSET;
                    const is_font_bigger = result_idx == SEARCH_FONT_BIGGER_OFFSET;
                    const is_font_smaller = result_idx == SEARCH_FONT_SMALLER_OFFSET;
                    const is_font_reset = result_idx == SEARCH_FONT_RESET_OFFSET;
                    const is_customcmd_edit = result_idx == SEARCH_CUSTOMCMD_EDIT_OFFSET;
                    const is_customcmd_reload = result_idx == SEARCH_CUSTOMCMD_RELOAD_OFFSET;
                    const is_archive = result_idx == SEARCH_ARCHIVE_OFFSET;
                    const is_unarchive_hidden = result_idx == SEARCH_UNARCHIVE_HIDDEN_OFFSET;
                    const is_unarchive_unattached = result_idx == SEARCH_UNARCHIVE_UNATTACHED_OFFSET;
                    const is_usage_companion = false;
                    const is_usage_coach = false;
                    const is_usage_login_primary = result_idx == SEARCH_USAGE_LOGIN_PRIMARY_OFFSET;
                    const is_usage_login_inne = result_idx == SEARCH_USAGE_LOGIN_INNE_OFFSET;
                    const is_usage_login = is_usage_login_primary or is_usage_login_inne;
                    const is_endtmux = result_idx == SEARCH_END_TMUX_OFFSET;
                    const is_reopen = result_idx == SEARCH_REOPEN_OFFSET;
                    const is_urlpick = result_idx == SEARCH_URLPICK_OFFSET;
                    const is_closetab = result_idx == SEARCH_CLOSETAB_OFFSET;
                    const is_favorite = result_idx == SEARCH_FAVORITE_OFFSET;
                    const is_mutetab = result_idx == SEARCH_MUTETAB_OFFSET;
                    const is_inbox_exclude = result_idx == SEARCH_INBOX_EXCLUDE_OFFSET;
                    const is_keepalive = result_idx == SEARCH_KEEPALIVE_OFFSET;
                    const is_pin_top = result_idx == SEARCH_PIN_TOP_OFFSET;
                    const is_chat_view = result_idx == SEARCH_CHAT_VIEW_OFFSET;
                    const is_chat_allow = result_idx == SEARCH_CHAT_ALLOW_OFFSET;
                    const is_chat_always = result_idx == SEARCH_CHAT_ALWAYS_OFFSET;
                    const is_chat_deny = result_idx == SEARCH_CHAT_DENY_OFFSET;
                    const is_chat_stop = result_idx == SEARCH_CHAT_STOP_OFFSET;
                    const is_multiprompt_login = result_idx == SEARCH_MULTIPROMPT_LOGIN_OFFSET;
                    const is_browser_toggle = result_idx == SEARCH_BROWSER_TOGGLE_OFFSET;
                    const is_browser_url = result_idx == SEARCH_BROWSER_URL_OFFSET;
                    const is_browser_instruct = result_idx == SEARCH_BROWSER_INSTRUCT_OFFSET;
                    const is_browser_focus_url = result_idx == SEARCH_BROWSER_FOCUS_URL_OFFSET;
                    const is_browser_focus_toggle = result_idx == SEARCH_BROWSER_FOCUS_TOGGLE_OFFSET;
                    const is_external_browser_links = result_idx == SEARCH_EXTERNAL_BROWSER_LINKS_OFFSET;
                    const is_browser_autosuspend = result_idx == SEARCH_BROWSER_AUTOSUSPEND_OFFSET;
                    const is_keepawake = result_idx == SEARCH_KEEPAWAKE_OFFSET;
                    const is_hibernate_now = result_idx == SEARCH_HIBERNATE_NOW_OFFSET;
                    const is_close_all_browser_panes = result_idx == SEARCH_CLOSE_ALL_BROWSER_PANES_OFFSET;
                    const is_crash_cmd = result_idx == SEARCH_CRASH_REPORTS_OFFSET or result_idx == SEARCH_CRASH_NOW_OFFSET;
                    const is_browser_back = result_idx == SEARCH_BROWSER_BACK_OFFSET;
                    const is_browser_forward = result_idx == SEARCH_BROWSER_FORWARD_OFFSET;
                    const is_browser_history = is_browser_back or is_browser_forward;
                    const is_browser_mode = result_idx == SEARCH_BROWSER_MODE_OFFSET;
                    const is_browser_engine = result_idx == SEARCH_BROWSER_ENGINE_OFFSET;
                    const is_browser_shoturl = result_idx == SEARCH_BROWSER_SHOTURL_OFFSET;
                    const is_zsb_rebind = result_idx == SEARCH_ZSB_REBIND_OFFSET;
                    const is_shell_diag = result_idx == SEARCH_SHELL_DIAG_OFFSET;
                    const is_sync_name = result_idx == SEARCH_SYNC_NAME_OFFSET;
                    const is_rename_sync = result_idx == SEARCH_RENAME_SYNC_OFFSET;
                    const is_ui_bigger = result_idx == SEARCH_UI_BIGGER_OFFSET;
                    const is_ui_smaller = result_idx == SEARCH_UI_SMALLER_OFFSET;
                    const is_ui_reset = result_idx == SEARCH_UI_RESET_OFFSET;
                    const is_restart = result_idx == SEARCH_RESTART_OFFSET or result_idx == SEARCH_UPDATE_OFFSET;
                    const is_remind_me = result_idx == SEARCH_REMIND_ME_OFFSET;
                    const is_reminders_menu = result_idx == SEARCH_REMINDERS_MENU_OFFSET;
                    const is_ws_snooze = result_idx == SEARCH_WS_SNOOZE_OFFSET;
                    const is_ws_bringback = result_idx == SEARCH_WS_BRINGBACK_OFFSET;
                    const is_ws_snoozed = result_idx == SEARCH_WS_SNOOZED_OFFSET or is_ws_bringback;
                    const is_ws_snoozed_row = result_idx >= SEARCH_WS_SNOOZED_ROW_OFFSET and result_idx < SEARCH_WS_SNOOZED_ROW_OFFSET + MAX_REMINDERS;
                    const is_remind_preset = result_idx >= SEARCH_REMIND_PRESET_OFFSET and result_idx < SEARCH_REMIND_PRESET_OFFSET + REMIND_PRESET_COUNT;
                    const is_codex_tmux = result_idx == SEARCH_CODEX_TMUX_OFFSET;
                    const is_snippet_manage = result_idx == SEARCH_SNIPPET_MANAGE_OFFSET;
                    const is_snippets_menu = result_idx == SEARCH_SNIPPETS_MENU_OFFSET or is_snippet_manage;
                    const is_snippet_create = result_idx == SEARCH_SNIPPET_CREATE_OFFSET;
                    const is_snippet_back = result_idx == SEARCH_SNIPPET_BACK_OFFSET;
                    const is_snippet = result_idx >= SEARCH_SNIPPET_OFFSET and result_idx < SEARCH_SNIPPET_OFFSET + MAX_SNIPPETS;
                    const is_snippet_action = is_snippets_menu or is_snippet_create or is_snippet_back or is_snippet;
                    const is_newwin = !is_crash_cmd and !is_ws_snooze and !is_ws_snoozed and !is_ws_snoozed_row and !is_skill_action and !is_snippet_action and !is_sync_signout and !is_sync_status and !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and !is_workspace_back and !is_workspace_delete_menu and !is_workspaces_menu and !is_quit and !is_fullwidth and !is_shortcuts and !is_closewin and !is_reconnect and !is_font_bigger and !is_font_smaller and !is_font_reset and !is_customcmd_edit and !is_customcmd_reload and !is_archive and !is_unarchive_hidden and !is_unarchive_unattached and !is_usage_companion and !is_usage_coach and !is_usage_login and !is_endtmux and !is_reopen and !is_urlpick and !is_closetab and !is_mutetab and !is_favorite and !is_keepalive and !is_pin_top and !is_chat_view and !is_chat_stop and !is_browser_toggle and !is_browser_url and !is_browser_instruct and !is_browser_focus_url and !is_browser_focus_toggle and !is_external_browser_links and !is_browser_autosuspend and !is_keepawake and !is_hibernate_now and !is_close_all_browser_panes and !is_browser_history and !is_browser_mode and !is_browser_engine and !is_browser_shoturl and !is_zsb_rebind and !is_shell_diag and !is_ui_bigger and !is_ui_smaller and !is_ui_reset and !is_restart and !is_remind_me and !is_reminders_menu and !is_remind_preset and !is_codex_tmux and !is_voice_mode_on and !is_voice_mode_off and !is_eta_numbers and !is_eta_progress and !is_eta_accuracy and !is_chat_view_mode_everywhere and !is_chat_view_mode_nowhere and !is_voice_stop and !is_voice_always_on and !is_voice_always_off and !is_voice_speed_100 and !is_voice_speed_125 and !is_voice_speed_140 and !is_voice_speed_150 and !is_voice_replay and !is_voice_previous and !is_voice_next and !is_inbox_exclude and !is_ladder and result_idx >= SEARCH_NEWWIN_OFFSET;
                    const is_openall = !is_ws_snooze and !is_ws_snoozed and !is_ws_snoozed_row and !is_skill_action and !is_snippet_action and !is_sync_signout and !is_sync_status and !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and !is_workspace_back and !is_workspace_delete_menu and !is_workspaces_menu and !is_quit and !is_fullwidth and !is_shortcuts and !is_closewin and !is_reconnect and !is_browser_history and !is_newwin and !is_unarchive_hidden and !is_unarchive_unattached and !is_usage_companion and !is_usage_coach and !is_usage_login and !is_pin_top and !is_endtmux and !is_browser_shoturl and !is_shell_diag and !is_remind_me and !is_reminders_menu and !is_remind_preset and !is_codex_tmux and !is_voice_mode_on and !is_voice_mode_off and !is_eta_numbers and !is_eta_progress and !is_eta_accuracy and !is_chat_view_mode_everywhere and !is_chat_view_mode_nowhere and !is_voice_stop and !is_voice_always_on and !is_voice_always_off and !is_voice_speed_100 and !is_voice_speed_125 and !is_voice_speed_140 and !is_voice_speed_150 and !is_voice_replay and !is_voice_previous and !is_voice_next and !is_inbox_exclude and !is_ladder and result_idx >= SEARCH_OPENALL_OFFSET;
                    const is_theme_back = !is_snippet_action and !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and !is_workspace_back and !is_workspace_delete_menu and !is_workspaces_menu and !is_quit and !is_fullwidth and !is_shortcuts and !is_closewin and !is_reconnect and !is_browser_history and !is_newwin and !is_openall and !is_shell_diag and result_idx == SEARCH_THEME_BACK_OFFSET;
                    const is_theme_menu = !is_snippet_action and !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and !is_workspace_back and !is_workspace_delete_menu and !is_workspaces_menu and !is_quit and !is_fullwidth and !is_shortcuts and !is_closewin and !is_reconnect and !is_browser_history and !is_newwin and !is_openall and !is_theme_back and !is_shell_diag and result_idx == SEARCH_THEME_MENU_OFFSET;
                    const is_theme_choice = !is_snippet_action and !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and !is_workspace_back and !is_workspace_delete_menu and !is_workspaces_menu and !is_quit and !is_fullwidth and !is_shortcuts and !is_closewin and !is_reconnect and !is_browser_history and !is_newwin and !is_openall and !is_theme_back and !is_theme_menu and !is_shell_diag and (result_idx == SEARCH_THEME_SYSTEM_OFFSET or (result_idx >= SEARCH_THEME_DARK_OFFSET and result_idx <= SEARCH_THEME_DEV_BLUE_OFFSET) or result_idx == SEARCH_THEME_MULTIPROMPT_OFFSET);
                    const is_theme_dev_edit = !is_snippet_action and !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and !is_workspace_back and !is_workspace_delete_menu and !is_workspaces_menu and !is_quit and !is_fullwidth and !is_shortcuts and !is_closewin and !is_reconnect and !is_browser_history and !is_newwin and !is_openall and !is_theme_back and !is_theme_menu and !is_theme_choice and !is_shell_diag and result_idx == SEARCH_THEME_DEV_EDIT_OFFSET;
                    const is_theme_dev_reload = !is_snippet_action and !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and !is_workspace_back and !is_workspace_delete_menu and !is_workspaces_menu and !is_quit and !is_fullwidth and !is_shortcuts and !is_closewin and !is_reconnect and !is_browser_history and !is_newwin and !is_openall and !is_theme_back and !is_theme_menu and !is_theme_choice and !is_theme_dev_edit and !is_shell_diag and result_idx == SEARCH_THEME_DEV_RELOAD_OFFSET;
                    const is_sound_toggle = !is_snippet_action and !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and !is_workspace_back and !is_workspace_delete_menu and !is_workspaces_menu and !is_quit and !is_fullwidth and !is_shortcuts and !is_closewin and !is_reconnect and !is_browser_history and !is_newwin and !is_openall and !is_theme_back and !is_theme_menu and !is_theme_choice and !is_theme_dev_edit and !is_theme_dev_reload and !is_endtmux and !is_browser_shoturl and !is_remind_me and !is_reminders_menu and !is_remind_preset and !is_codex_tmux and !is_shell_diag and result_idx == SEARCH_SOUND_OFFSET;
                    const is_new_shell = !is_crash_cmd and !is_ws_snooze and !is_ws_snoozed and !is_ws_snoozed_row and !is_skill_action and !is_snippet_action and !is_sync_signout and !is_sync_status and !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and !is_workspace_back and !is_workspace_delete_menu and !is_workspaces_menu and !is_quit and !is_fullwidth and !is_shortcuts and !is_closewin and !is_reconnect and !is_browser_history and !is_newwin and !is_openall and !is_theme_back and !is_theme_menu and !is_theme_choice and !is_theme_dev_edit and !is_theme_dev_reload and !is_sound_toggle and !is_usage_companion and !is_usage_coach and !is_usage_login and !is_endtmux and !is_remind_me and !is_reminders_menu and !is_remind_preset and !is_codex_tmux and !is_browser_focus_url and !is_browser_focus_toggle and !is_external_browser_links and !is_browser_autosuspend and !is_keepawake and !is_hibernate_now and !is_close_all_browser_panes and !is_browser_mode and !is_browser_shoturl and !is_zsb_rebind and !is_shell_diag and !is_pin_top and !is_voice_mode_on and !is_voice_mode_off and !is_eta_numbers and !is_eta_progress and !is_eta_accuracy and !is_chat_view_mode_everywhere and !is_chat_view_mode_nowhere and !is_voice_stop and !is_voice_always_on and !is_voice_always_off and !is_voice_speed_100 and !is_voice_speed_125 and !is_voice_speed_140 and !is_voice_speed_150 and !is_voice_replay and !is_voice_previous and !is_voice_next and !is_inbox_exclude and !is_ladder and result_idx >= SEARCH_NEW_OFFSET;
                    const is_tmux_inactive = !is_crash_cmd and !is_ws_snooze and !is_ws_snoozed and !is_ws_snoozed_row and !is_skill_action and !is_snippet_action and !is_sync_signout and !is_sync_status and !is_addfavicon and !is_mobile_toggle and !is_renamewin and !is_workspace and !is_workspace_delete and !is_workspace_back and !is_workspace_delete_menu and !is_workspaces_menu and !is_quit and !is_fullwidth and !is_shortcuts and !is_closewin and !is_reconnect and !is_browser_history and !is_newwin and !is_openall and !is_theme_back and !is_theme_menu and !is_theme_choice and !is_theme_dev_edit and !is_theme_dev_reload and !is_sound_toggle and !is_archive and !is_endtmux and !is_remind_me and !is_reminders_menu and !is_remind_preset and !is_codex_tmux and !is_reopen and !is_urlpick and !is_closetab and !is_mutetab and !is_favorite and !is_keepalive and !is_pin_top and !is_browser_toggle and !is_browser_url and !is_browser_instruct and !is_browser_focus_url and !is_browser_focus_toggle and !is_external_browser_links and !is_browser_autosuspend and !is_keepawake and !is_hibernate_now and !is_close_all_browser_panes and !is_browser_mode and !is_browser_shoturl and !is_zsb_rebind and !is_shell_diag and !is_new_shell and !is_voice_mode_on and !is_voice_mode_off and !is_eta_numbers and !is_eta_progress and !is_eta_accuracy and !is_chat_view_mode_everywhere and !is_chat_view_mode_nowhere and !is_voice_stop and !is_voice_always_on and !is_voice_always_off and !is_voice_speed_100 and !is_voice_speed_125 and !is_voice_speed_140 and !is_voice_speed_150 and !is_voice_replay and !is_voice_previous and !is_voice_next and !is_inbox_exclude and !is_ladder and result_idx >= SEARCH_TMUX_OFFSET;
                    const is_archived = is_renamewin and result_idx >= SEARCH_ARCHIVED_OFFSET and result_idx < SEARCH_ARCHIVED_OFFSET + 64;
                    const is_reminder_row = is_renamewin and result_idx >= SEARCH_REMINDER_ROW_OFFSET and result_idx < SEARCH_REMINDER_ROW_OFFSET + 64;
                    const is_customcmd = is_renamewin and !is_ws_snoozed_row and !is_archived and !is_reminder_row and result_idx >= SEARCH_CUSTOMCMD_OFFSET;
                    const is_tabctx = is_renamewin and !is_ws_snoozed_row and !is_customcmd and !is_archived and !is_reminder_row and result_idx >= SEARCH_TABCTX_BACK;
                    const ry = oy + input_h + @as(i32, @intCast(vi)) * row_h;

                    if (ri == app_state.g_search_sel) {
                        const sel_rc = RECT{ .left = ox + uiScaled(16), .top = ry, .right = ox + overlay_w - uiScaled(16), .bottom = ry + row_h };
                        @import("smooth.zig").fillRoundRect(hdc, sel_rc, uiScaled(10), if (app_state.g_light_theme) RGB(225, 225, 225) else RGB(0x35, 0x35, 0x35));
                    }

                    if (paletteHeaderIndex(result_idx)) |header| {
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, customColorOr("hint", if (app_state.g_light_theme) RGB(120, 120, 120) else RGB(140, 140, 140)));
                        const header_label: [*:0]const u16 = switch (header) {
                            0 => L("MOST USED"),
                            1 => L("SESSIONS"),
                            2 => L("WORKSPACES AND WINDOWS"),
                            3 => L("SIDEBAR AND TABS"),
                            4 => L("LOOK AND SETTINGS"),
                            5 => L("DEBUG AND REPAIR"),
                            6 => L("BROWSER"),
                            7 => L("ACCOUNT AND USAGE"),
                            else => L("CHAT VIEW"),
                        };
                        var header_rc = RECT{ .left = ox + uiScaled(28), .top = ry + @divTrunc(row_h, 3), .right = ox + overlay_w - 12, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, header_label, -1, &header_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                    } else if (result_idx >= app_state.SEARCH_GROUPCTX_BASE and result_idx < app_state.SEARCH_GROUPCTX_BASE + app_state.SEARCH_GROUPCTX_COUNT) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else customColorOr("text", if (app_state.g_light_theme) RGB(60, 60, 60) else RGB(180, 180, 180)));
                        var label: [192]u16 = undefined;
                        const len = @import("rename.zig").groupPaletteLabel(result_idx - app_state.SEARCH_GROUPCTX_BASE, &label);
                        var text_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 12, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, &label, @intCast(len), &text_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                    } else if (is_session_overview_menu) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var som_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 110, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Show All Sessions..."), -1, &som_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var som_hint_rc = RECT{ .left = ox + overlay_w - 110, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("repo"), -1, &som_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_session_overview_row) {
                        const so_idx = result_idx - SEARCH_SESSION_OVERVIEW_ROW_OFFSET;
                        if (so_idx < app_state.g_session_overview_count) {
                            const row = &app_state.g_session_overview_rows.items[so_idx];
                            _ = SelectObject(hdc, palette_font);
                            _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else if (app_state.g_light_theme) RGB(60, 60, 60) else RGB(220, 220, 220));
                            var sorc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 126, .bottom = ry + row_h };
                            const label = if (row.name_len > 0) row.name[0..row.name_len] else row.session[0..row.session_len];
                            drawAscii(hdc, label, &sorc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                            _ = SelectObject(hdc, palette_hint_font);
                            _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(170, 210, 170) else RGB(100, 140, 170));
                            var status_rc = RECT{ .left = ox + overlay_w - 126, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                            drawAscii(hdc, sessionOverviewKindLabel(row.kind), &status_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                        }
                    } else if (is_archived_view) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var av_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Archived Sessions"), -1, &av_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var av_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("choose one"), -1, &av_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_snippets_menu) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var snm_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 100, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, if (is_snippet_manage) L("Manage Snippets") else L("Use Snippets..."), -1, &snm_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var snm_hint_rc = RECT{ .left = ox + overlay_w - 100, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, if (is_snippet_manage) L("delete") else L("Alt+;"), -1, &snm_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_snippet_back) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var snb_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 100, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Back"), -1, &snb_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var snb_hint_rc = RECT{ .left = ox + overlay_w - 100, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("main"), -1, &snb_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_snippet_create) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var snc_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Create Snippet"), -1, &snc_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var snc_hint_rc = RECT{ .left = ox + overlay_w - 90, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("new"), -1, &snc_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_snippet) {
                        const sn_idx = result_idx - SEARCH_SNIPPET_OFFSET;
                        if (sn_idx < app_state.g_snippet_count) {
                            const s = &app_state.g_snippets[sn_idx];
                            const confirming_delete = if (app_state.g_search_snippet_delete_confirm) |confirm_idx| confirm_idx == sn_idx else false;
                            _ = SelectObject(hdc, palette_font);
                            _ = SetTextColor(hdc, if (confirming_delete) RGB(255, 205, 205) else if (ri == app_state.g_search_sel) RGB(255, 255, 255) else if (app_state.g_light_theme) RGB(60, 60, 60) else RGB(220, 220, 220));
                            var sn_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 100, .bottom = ry + row_h };
                            _ = DrawTextW(hdc, @ptrCast(&s.name), @intCast(s.name_len), &sn_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                            _ = SelectObject(hdc, palette_hint_font);
                            _ = SetTextColor(hdc, if (confirming_delete) RGB(255, 180, 180) else if (ri == app_state.g_search_sel) RGB(170, 210, 170) else RGB(90, 150, 90));
                            var sn_hint_rc = RECT{ .left = ox + overlay_w - 100, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                            const sn_hint = if (confirming_delete) (if (app_state.g_search_snippet_manage_mode) L("Confirm delete") else L("Del again")) else if (app_state.g_search_snippet_manage_mode) L("delete") else if (ri == app_state.g_search_sel) L("Del delete") else L("paste");
                            _ = DrawTextW(hdc, sn_hint, -1, &sn_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                        }
                    } else if (is_addfavicon) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else if (app_state.g_light_theme) RGB(30, 90, 180) else RGB(100, 160, 240));
                        var af_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 12, .bottom = ry + row_h };
                        const af_label = if (app_state.g_favicon_fetching) L("Add Favicon (fetching...)") else L("Add Favicon from VPS");
                        _ = DrawTextW(hdc, af_label, -1, &af_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                    } else if (is_mobile_toggle) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        const mob_label = if (app_state.g_mobile_mode) L("Mobile Latency Mode: On") else L("Mobile Latency Mode: Off");
                        var mob_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 12, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, mob_label, -1, &mob_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                    } else if (is_workspace_back) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var back_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 100, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("← Back"), -1, &back_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var back_hint_rc = RECT{ .left = ox + overlay_w - 100, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("main"), -1, &back_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_workspaces_menu) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var wm_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Open Workspace…"), -1, &wm_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var wm_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("list"), -1, &wm_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_workspace_delete_menu) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else if (app_state.g_light_theme) RGB(130, 45, 45) else RGB(230, 135, 135));
                        var dm_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Delete Workspace…"), -1, &dm_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(230, 210, 210) else RGB(140, 100, 100));
                        var dm_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("old"), -1, &dm_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_quit) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else if (app_state.g_light_theme) RGB(130, 45, 45) else RGB(230, 135, 135));
                        var q_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Quit multiprompt"), -1, &q_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(230, 210, 210) else RGB(140, 100, 100));
                        var q_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("restore"), -1, &q_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_restart) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else if (app_state.g_light_theme) RGB(60, 60, 60) else RGB(200, 200, 200));
                        var rs_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        if (result_idx == SEARCH_UPDATE_OFFSET) {
                            var ub: [64]u8 = undefined;
                            const ut = if (app_state.g_update_ver_len > 0)
                                (std.fmt.bufPrint(&ub, "Restart to update to v{s}", .{app_state.g_update_ver[0..app_state.g_update_ver_len]}) catch "Restart to update")
                            else if (@import("update_release.zig").checking())
                                "Restart to update (still downloading)"
                            else
                                "Restart to update (no update ready)";
                            drawAscii(hdc, ut, &rs_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        } else {
                            _ = paletteDrawText(hdc, L("Restart multiprompt"), -1, &rs_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        }
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var rs_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("relaunch"), -1, &rs_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_fullwidth) {
                        const fw_on = app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].full_width;
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var fw_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (fw_on) L("Full-Width: ON") else L("Full-Width: OFF"), -1, &fw_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var fw_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Ctrl+Shift+F"), -1, &fw_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_shortcuts) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var sc_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Keyboard Shortcuts"), -1, &sc_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var sc_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("F1"), -1, &sc_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_changelog) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var cl_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Changelog"), -1, &cl_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var cl_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("versions"), -1, &cl_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_closewin) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else if (app_state.g_light_theme) RGB(130, 45, 45) else RGB(230, 135, 135));
                        var cw_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Close Workspace"), -1, &cw_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(230, 210, 210) else RGB(140, 100, 100));
                        var cw_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("this workspace"), -1, &cw_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_reconnect) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var rc_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Reattach Tab"), -1, &rc_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var rc_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Ctrl+Shift+R"), -1, &rc_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_singlewin) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var sw_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (app_state.g_single_window) L("Single-Window Mode: ON") else L("Single-Window Mode: OFF"), -1, &sw_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var sw_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (app_state.g_single_window) L("\u{2192} multi") else L("\u{2192} single"), -1, &sw_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_installhook) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var ih_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Install Blue Dot Hook"), -1, &ih_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var ih_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("copy"), -1, &ih_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (result_idx == SEARCH_SHOW_FREQUENT_OFFSET) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var setting_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 12, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if ((app_state.g_layout_settings orelse frequent.Settings{}).frequent) L("Show Frequent split: ON") else L("Show Frequent split: OFF"), -1, &setting_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                    } else if (result_idx == SEARCH_FREQUENT_FIRST_OFFSET) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var setting_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 12, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if ((app_state.g_layout_settings orelse frequent.Settings{}).frequent_first) L("Frequent as first tab: ON") else L("Frequent as first tab: OFF"), -1, &setting_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                    } else if (result_idx == SEARCH_SHOW_FAVORITES_OFFSET) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var setting_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 12, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if ((app_state.g_layout_settings orelse frequent.Settings{}).favorites) L("Show Favorites split: ON") else L("Show Favorites split: OFF"), -1, &setting_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                    } else if (result_idx == SEARCH_SHOW_ALL_OFFSET) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var setting_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 12, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if ((app_state.g_layout_settings orelse frequent.Settings{}).all) L("Show All split: ON") else L("Show All split: OFF"), -1, &setting_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                    } else if (result_idx == SEARCH_INBOX_FREQUENT_OFFSET) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var frequent_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 12, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Inbox: Frequent"), -1, &frequent_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                    } else if (result_idx == SEARCH_STARRED_OFFSET) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var starred_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Go to Starred workspace"), -1, &starred_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        var hint_rc = RECT{ .left = ox + overlay_w - 90, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Alt+1"), -1, &hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_goinbox) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var gi_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Go to Inbox"), -1, &gi_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var gi_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Alt+I"), -1, &gi_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_wssort_menu) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var sm_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Sort Workspaces…"), -1, &sm_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var sm_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("drag"), -1, &sm_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_wssort) {
                        const slot: u8 = @intCast(result_idx - SEARCH_WSSORT_OFFSET);
                        const dragging_this = app_state.g_wssort_dragging and slot == app_state.g_wssort_drag_slot;
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (dragging_this) RGB(255, 255, 255) else if (ri == app_state.g_search_sel) RGB(200, 215, 235) else RGB(110, 110, 120));
                        var sh_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + 34, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("≡"), -1, &sh_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else if (slot == app_state.g_active_workspace) RGB(120, 120, 130) else if (app_state.g_light_theme) RGB(60, 60, 60) else RGB(180, 180, 180));
                        var snbuf: [32]u8 = undefined;
                        const snm = workspaceDisplayName(slot, &snbuf);
                        var sw_buf: [48]u16 = undefined;
                        var swl: usize = 0;
                        for (snm) |c| {
                            if (swl >= sw_buf.len) break;
                            sw_buf[swl] = c;
                            swl += 1;
                        }
                        var sw_rc = RECT{ .left = ox + 38, .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, @ptrCast(&sw_buf), @intCast(swl), &sw_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var sh_hint: [8]u16 = undefined;
                        var shl: usize = 0;
                        if (slot == app_state.g_active_workspace) {
                            for ("current") |c| {
                                sh_hint[shl] = c;
                                shl += 1;
                            }
                        } else if (slot < 8) {
                            for ("Alt+") |c| {
                                sh_hint[shl] = c;
                                shl += 1;
                            }
                            sh_hint[shl] = '2' + @as(u16, slot);
                            shl += 1;
                        }
                        var sw_hint_rc = RECT{ .left = ox + overlay_w - 90, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, @ptrCast(&sh_hint), @intCast(shl), &sw_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_groupmove_menu) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var gm_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Move to Group\u{2026}"), -1, &gm_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var gm_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("move"), -1, &gm_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_groupmove_back or is_groupmove_new or is_groupmove_none) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var ga_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        const ga_label: [*:0]const u16 = if (is_groupmove_back) L("Back") else if (is_groupmove_new) L("New group") else L("No group");
                        _ = DrawTextW(hdc, ga_label, -1, &ga_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        if (is_groupmove_back or is_groupmove_new) {
                            _ = SelectObject(hdc, palette_hint_font);
                            _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                            var ga_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                            _ = DrawTextW(hdc, if (is_groupmove_back) L("Esc") else L("new"), -1, &ga_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                        }
                    } else if (is_groupmove_group) {
                        const gi = result_idx - SEARCH_GROUPMOVE_GROUP_OFFSET;
                        if (gi < app_state.group_count) {
                            const current_gid: u32 = if (selectedTabCount() > 0) 0 else if (findShellById(app_state.g_groupmove_tab_sid)) |ti| tabGroupId(ti) else 0;
                            _ = SelectObject(hdc, palette_font);
                            _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else if (app_state.groups[gi].id == current_gid) RGB(120, 120, 130) else if (app_state.g_light_theme) RGB(60, 60, 60) else RGB(180, 180, 180));
                            var gg_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                            if (app_state.groups[gi].name_len > 0) {
                                _ = DrawTextW(hdc, @ptrCast(&app_state.groups[gi].name), @intCast(app_state.groups[gi].name_len), &gg_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                            } else {
                                _ = paletteDrawText(hdc, L("(unnamed)"), -1, &gg_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                            }
                            if (app_state.groups[gi].id == current_gid) {
                                _ = SelectObject(hdc, palette_hint_font);
                                _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                                var gg_hint_rc = RECT{ .left = ox + overlay_w - 90, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                                _ = paletteDrawText(hdc, L("current"), -1, &gg_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                            }
                        }
                    } else if (is_wsmove_menu) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var mm_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Move to Workspace…"), -1, &mm_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var mm_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("move"), -1, &mm_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_wsmove) {
                        const mslot: u8 = @intCast(result_idx - SEARCH_WSMOVE_OFFSET);
                        const active_ws: u8 = if (findShellById(app_state.g_wsmove_tab_sid)) |ti| app_state.shells[ti].workspace else if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].workspace else 0xFF;
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else if (mslot == active_ws) RGB(120, 120, 130) else if (app_state.g_light_theme) RGB(60, 60, 60) else RGB(180, 180, 180));
                        var mnbuf: [32]u8 = undefined;
                        const mnm = workspaceDisplayName(mslot, &mnbuf);
                        var mw_buf: [48]u16 = undefined;
                        var mwl: usize = 0;
                        for (mnm) |c| {
                            if (mwl >= mw_buf.len) break;
                            mw_buf[mwl] = c;
                            mwl += 1;
                        }
                        var mw_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, @ptrCast(&mw_buf), @intCast(mwl), &mw_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var mh_hint: [8]u16 = undefined;
                        var mhl: usize = 0;
                        if (mslot == active_ws) {
                            for ("current") |c| {
                                mh_hint[mhl] = c;
                                mhl += 1;
                            }
                        } else if (mslot < 8) {
                            for ("Alt+") |c| {
                                mh_hint[mhl] = c;
                                mhl += 1;
                            }
                            mh_hint[mhl] = '2' + @as(u16, mslot);
                            mhl += 1;
                        }
                        var mw_hint_rc = RECT{ .left = ox + overlay_w - 90, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, @ptrCast(&mh_hint), @intCast(mhl), &mw_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_wsmove_workspace) {
                        const workspace_idx = result_idx - SEARCH_WORKSPACE_OFFSET;
                        if (workspace_idx < app_state.g_workspace_count) {
                            const e = &app_state.g_workspaces[workspace_idx];
                            _ = SelectObject(hdc, palette_font);
                            _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                            var cw_buf: [96]u16 = undefined;
                            var cwl: usize = 0;
                            for (0..e.name_len) |ni| {
                                if (cwl >= cw_buf.len) break;
                                cw_buf[cwl] = @intCast(e.name[ni]);
                                cwl += 1;
                            }
                            if (cwl == 0) {
                                for ("Workspace") |c| {
                                    if (cwl >= cw_buf.len) break;
                                    cw_buf[cwl] = c;
                                    cwl += 1;
                                }
                            }
                            var cw_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                            _ = DrawTextW(hdc, @ptrCast(&cw_buf), @intCast(cwl), &cw_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                            _ = SelectObject(hdc, palette_hint_font);
                            _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                            var cw_hint_rc = RECT{ .left = ox + overlay_w - 90, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                            _ = paletteDrawText(hdc, L("closed"), -1, &cw_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                        }
                    } else if (is_wsmove_new) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var mn_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Move to NEW workspace"), -1, &mn_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var mn_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("new"), -1, &mn_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_hidesidebar) {
                        const sb_open = !app_state.g_hide_sidebar and !app_state.g_sidebar_collapsed;
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var hs_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Sidebar: Expand"), -1, &hs_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var hs_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (sb_open) L("current") else L("open"), -1, &hs_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_sidebarcollapse) {
                        const sb_collapsed = !app_state.g_hide_sidebar and app_state.g_sidebar_collapsed;
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var sc_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Sidebar: Collapse"), -1, &sc_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var sc_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (sb_collapsed) L("current") else L("narrow"), -1, &sc_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_sidebarhide) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var sh_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Sidebar: Hide"), -1, &sh_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var sh_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (app_state.g_hide_sidebar) L("current") else L("focus"), -1, &sh_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_hidepills) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var hp_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (app_state.g_hide_pills) L("Show Workspace Switcher") else L("Hide Workspace Switcher"), -1, &hp_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var hp_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (app_state.g_hide_pills) L("switcher") else L("current"), -1, &hp_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_nextunread) {
                        _ = SelectObject(hdc, palette_font);
                        const nu_blue = customColorOr("attention", RGB(60, 120, 220));
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else nu_blue);
                        var nu_buf: [96]u16 = undefined;
                        var nul: usize = 0;
                        for ("Next unread: ") |c| {
                            nu_buf[nul] = c;
                            nul += 1;
                        }
                        for (app_state.g_nextunread_name[0..app_state.g_nextunread_name_len]) |c| {
                            if (nul >= nu_buf.len) break;
                            nu_buf[nul] = c;
                            nul += 1;
                        }
                        var nu_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, @ptrCast(&nu_buf), @intCast(nul), &nu_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var nu_cnt: [12]u8 = undefined;
                        const nu_hint = std.fmt.bufPrint(&nu_cnt, "{d} unread", .{app_state.g_nextunread_count}) catch "unread";
                        var nh_buf: [16]u16 = undefined;
                        var nhl: usize = 0;
                        for (nu_hint) |c| {
                            if (nhl >= nh_buf.len) break;
                            nh_buf[nhl] = c;
                            nhl += 1;
                        }
                        var nu_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, @ptrCast(&nh_buf), @intCast(nhl), &nu_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_tabsort_inbox) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var ti_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Tab Order: Auto"), -1, &ti_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var ti_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (app_state.g_tab_sort_auto) L("current") else L(""), -1, &ti_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_tabsort_manual) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var tm_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Tab Order: Manual"), -1, &tm_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var tm_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (!app_state.g_tab_sort_auto) L("current") else L(""), -1, &tm_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_power_auto or is_power_always or is_power_off) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var pw_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        const pw_label = if (is_power_auto) L("Power Saver: Auto") else if (is_power_always) L("Power Saver: Always") else L("Power Saver: Off");
                        _ = DrawTextW(hdc, pw_label, -1, &pw_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var pw_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        const pw_current = (is_power_auto and app_state.g_power_profile == .auto) or (is_power_always and app_state.g_power_profile == .always) or (is_power_off and app_state.g_power_profile == .off);
                        _ = DrawTextW(hdc, if (pw_current) L("current") else L(""), -1, &pw_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_voice_always_on or is_voice_always_off) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var val_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (is_voice_always_on) L("Voice: Always Listening On") else L("Voice: Always Listening Off"), -1, &val_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var val_hint = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (app_state.g_voice_always_listen == is_voice_always_on) L("current") else L(""), -1, &val_hint, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_ladder) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var tl_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        const tl_label = switch (result_idx) {
                            SEARCH_LADDER_AUTO_OFFSET => L("Token Ladder: Auto"),
                            SEARCH_LADDER_CLAUDE_OFFSET => L("Token Ladder: Burn Claude"),
                            SEARCH_LADDER_CODEX_OFFSET => L("Token Ladder: Burn Codex"),
                            else => L("Token Ladder: Open Dashboard"),
                        };
                        _ = DrawTextW(hdc, tl_label, -1, &tl_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var tl_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        const tl_current = app_state.g_ai_pace.from_ladder and ((result_idx == SEARCH_LADDER_AUTO_OFFSET and app_state.g_ai_pace.ladder_override == 0) or
                            (result_idx == SEARCH_LADDER_CLAUDE_OFFSET and app_state.g_ai_pace.ladder_override == 1) or
                            (result_idx == SEARCH_LADDER_CODEX_OFFSET and app_state.g_ai_pace.ladder_override == 2));
                        _ = DrawTextW(hdc, if (tl_current) L("current") else L(""), -1, &tl_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_voice_mode_on or is_voice_mode_off) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var vm_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (is_voice_mode_on) L("Voice Mode: On") else L("Voice Mode: Off"), -1, &vm_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var vm_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        const vm_current = (is_voice_mode_on and app_state.g_voice_mode_active) or (is_voice_mode_off and !app_state.g_voice_mode_active);
                        _ = DrawTextW(hdc, if (vm_current) L("current") else L(""), -1, &vm_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_voice_stop) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var stop_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Voice: Stop Speaking"), -1, &stop_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var stop_hint_rc = RECT{ .left = ox + overlay_w - 90, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Alt+V"), -1, &stop_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_voice_speed_100 or is_voice_speed_125 or is_voice_speed_140 or is_voice_speed_150) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var vsp_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        const vsp_speed: VoiceSpeed = if (is_voice_speed_100) .s100 else if (is_voice_speed_125) .s125 else if (is_voice_speed_140) .s140 else .s150;
                        var vsp_label_buf: [32]u8 = undefined;
                        const vsp_label = std.fmt.bufPrint(&vsp_label_buf, "Voice Speed: {s}", .{voiceSpeedLabel(vsp_speed)}) catch "Voice Speed";
                        var vsp_label_wide: [40]u16 = undefined;
                        const vsp_label_z = asciiToWideZ(vsp_label, &vsp_label_wide) orelse L("Voice Speed");
                        _ = DrawTextW(hdc, vsp_label_z, -1, &vsp_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var vsp_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (app_state.g_voice_speed == vsp_speed) L("current") else L(""), -1, &vsp_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_voice_replay or is_voice_previous or is_voice_next) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var vrp_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 80, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (is_voice_previous) L("Voice: Read Previous Reply") else if (is_voice_next) L("Voice: Read Next Reply") else L("Voice: Read Last Reply"), -1, &vrp_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var vrp_hint_rc = RECT{ .left = ox + overlay_w - 80, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (is_voice_previous) L("Alt+[") else if (is_voice_next) L("Alt+]") else L("Alt+R"), -1, &vrp_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_unreadonly) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var uo_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 80, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Toggle Unread Only"), -1, &uo_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var uo_hint_rc = RECT{ .left = ox + overlay_w - 80, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (app_state.g_unread_only) L("on") else L("off"), -1, &uo_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_eta_numbers or is_eta_progress) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var etn_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 80, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (is_eta_numbers) L("ETA Countdown Numbers") else L("ETA Progress Line"), -1, &etn_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var etn_hint_rc = RECT{ .left = ox + overlay_w - 80, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        const etn_on = if (is_eta_numbers) app_state.g_eta_numbers_on else app_state.g_eta_progress_on;
                        _ = DrawTextW(hdc, if (etn_on) L("on") else L("off"), -1, &etn_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_eta_accuracy) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var eac_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Estimate Accuracy"), -1, &eac_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                    } else if (is_chat_view_mode_everywhere or is_chat_view_mode_nowhere) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var cvm_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        const cvm_label = if (is_chat_view_mode_everywhere) L("Chat View: On Everywhere") else L("Chat View: Off Everywhere");
                        _ = DrawTextW(hdc, cvm_label, -1, &cvm_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                    } else if (is_threadtitle) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var tt_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 80, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (app_state.g_thread_title) L("Hide Thread Title") else L("Show Thread Title"), -1, &tt_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var tt_hint_rc = RECT{ .left = ox + overlay_w - 80, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (app_state.g_thread_title) L("on") else L("off"), -1, &tt_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_font_bigger) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var fb_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 80, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Console Font Bigger"), -1, &fb_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var fb_hint_rc = RECT{ .left = ox + overlay_w - 80, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Ctrl++"), -1, &fb_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_font_smaller) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var fs_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 80, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Console Font Smaller"), -1, &fs_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var fs_hint_rc = RECT{ .left = ox + overlay_w - 80, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Ctrl+-"), -1, &fs_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_font_reset) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var fr_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 80, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Console Font Reset"), -1, &fr_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var fr_hint_rc = RECT{ .left = ox + overlay_w - 80, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Ctrl+0"), -1, &fr_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_customcmd_edit) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var ce_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Commands: Edit commands.json"), -1, &ce_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var ce_hint_rc = RECT{ .left = ox + overlay_w - 90, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("notepad"), -1, &ce_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_customcmd_reload) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var cr_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Commands: Reload"), -1, &cr_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var cr_hint_rc = RECT{ .left = ox + overlay_w - 90, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("reload"), -1, &cr_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_archive) {
                        const archive_has_tmux = app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].tmux_session_len > 0;
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var ar_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 130, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (archive_has_tmux) L("Archive Session") else L("Close Session"), -1, &ar_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var ar_hint_rc = RECT{ .left = ox + overlay_w - 130, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Alt+X"), -1, &ar_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_unarchive_hidden) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var ua_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Restore Workspace Waiting Sessions"), -1, &ua_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var ua_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("reveal"), -1, &ua_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_unarchive_unattached) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var uu_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Restore Disconnected Workspace Sessions"), -1, &uu_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var uu_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("sequential"), -1, &uu_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_chat_queue_send or is_chat_queue_clear or is_chat_reset or is_chat_retry_unsent or is_chat_discard_unsent or is_chat_push_queued or is_chat_edit_queued) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else customColorOr("text", themeConsoleFg()));
                        var queue_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 140, .bottom = ry + row_h };
                        const queue_label: [*:0]const u16 = if (is_chat_queue_send)
                            L("Chat View: Send Queued Messages Now")
                        else if (is_chat_reset)
                            L("Chat View: Reset this chat")
                        else if (is_chat_queue_clear)
                            L("Chat View: Clear Offline Queue")
                        else if (is_chat_retry_unsent)
                            L("Chat View: Retry Unsent Messages")
                        else if (is_chat_push_queued)
                            L("Chat View: Send Claude's Queued Message Now")
                        else if (is_chat_edit_queued)
                            L("Chat View: Edit Queued Messages")
                        else
                            L("Chat View: Discard Unsent Messages");
                        _ = DrawTextW(hdc, queue_label, -1, &queue_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                    } else if (is_chat_tab_url) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else customColorOr("text", themeConsoleFg()));
                        var url_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 140, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Chat View: Insert browser tab URL"), -1, &url_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                        _ = SelectObject(hdc, palette_hint_font);
                        var url_hint_rc = RECT{ .left = ox + overlay_w - 140, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Ctrl+Shift+X"), -1, &url_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_chat_reply) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else customColorOr("text", themeConsoleFg()));
                        var reply_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Chat View: Reply to latest agent message"), -1, &reply_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                    } else if (is_chat_find) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else customColorOr("text", themeConsoleFg()));
                        var find_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Chat View: Find in conversation"), -1, &find_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                    } else if (is_clean_chat or is_chat_todo or is_chat_tools or is_chat_newest or is_chat_more_menu or is_chat_resync) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else customColorOr("text", themeConsoleFg()));
                        var tools_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (is_clean_chat) (if (app_state.clean_chat) L("Chat View: CLEAN chat: ON (toggle)") else L("Chat View: CLEAN chat: OFF (toggle)")) else if (is_chat_todo) L("Chat View: Toggle todo list") else if (is_chat_newest) L("Chat View: Scroll to newest message") else if (is_chat_resync) L("Chat View: Resync chat") else if (is_chat_more_menu) L("Chat View: More Menu") else L("Chat View: Open or fold all tool steps"), -1, &tools_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                    } else if (is_chat_copy) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else customColorOr("text", themeConsoleFg()));
                        var copy_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 140, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Chat View: Copy Latest Code Block"), -1, &copy_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                        _ = SelectObject(hdc, palette_hint_font);
                        var hint_rc = RECT{ .left = ox + overlay_w - 140, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Ctrl+Shift+D"), -1, &hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_chat_attach) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else customColorOr("text", themeConsoleFg()));
                        var attach_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 140, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (result_idx == SEARCH_CHAT_DICTATION_OFFSET) L("Chat View: Toggle Dictation") else L("Chat View: Attach File"), -1, &attach_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                        _ = SelectObject(hdc, palette_hint_font);
                        var attach_hint_rc = RECT{ .left = ox + overlay_w - 140, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (result_idx == SEARCH_CHAT_DICTATION_OFFSET) L("Ctrl+D") else L("Ctrl+V"), -1, &attach_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_chat_copy_sel) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else customColorOr("text", themeConsoleFg()));
                        var cs_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Chat View: Copy Selection"), -1, &cs_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                        _ = SelectObject(hdc, palette_hint_font);
                        var cs_hint = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Ctrl+C"), -1, &cs_hint, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_chat_focus_messages) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else customColorOr("text", themeConsoleFg()));
                        var fm_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Chat View: Focus Messages"), -1, &fm_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                        _ = SelectObject(hdc, palette_hint_font);
                        var fm_hint = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Up"), -1, &fm_hint, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_chat_select_all) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else customColorOr("text", themeConsoleFg()));
                        var sa_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Chat View: Select All Text"), -1, &sa_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                        _ = SelectObject(hdc, palette_hint_font);
                        var sa_hint = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Ctrl+A"), -1, &sa_hint, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_chat_ac) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var ac_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 130, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Chat View: Insert Command or Skill..."), -1, &ac_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                        _ = SelectObject(hdc, palette_hint_font);
                        var key_rc = RECT{ .left = ox + overlay_w - 24, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Ctrl+/"), -1, &key_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_skills_menu or is_skills_back) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var skills_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 130, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (is_skills_back) L("Back") else L("Skills..."), -1, &skills_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var skills_hint_rc = RECT{ .left = ox + overlay_w - 130, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (is_skills_back) L("main") else L("Chat View"), -1, &skills_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_skill_row) {
                        const skill_idx = result_idx - SEARCH_SKILL_ROW_OFFSET;
                        if (skill_idx < app_state.g_palette_skills.len) {
                            const skill = app_state.g_palette_skills[skill_idx];
                            var skill_label: [192]u8 = undefined;
                            const label = std.fmt.bufPrint(&skill_label, "/{s}", .{skill.name}) catch skill.name;
                            _ = SelectObject(hdc, palette_font);
                            _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                            var skill_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 175, .bottom = ry + row_h };
                            drawAscii(hdc, label, &skill_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                            _ = SelectObject(hdc, palette_hint_font);
                            _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                            var skill_hint_rc = RECT{ .left = ox + overlay_w - 175, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                            _ = DrawTextW(hdc, if (skill.source == .multiprompt) L("multiprompt skills") else L("coding harness"), -1, &skill_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                        }
                    } else if (is_multiprompt_login) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var sync_login_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 130, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Sign in to multiprompt"), -1, &sync_login_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var sync_login_hint_rc = RECT{ .left = ox + overlay_w - 130, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (app_state.g_multiprompt_logged_in) L("signed in") else L("desktop sync"), -1, &sync_login_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_sync_signout or is_sync_status) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var sync_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 130, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (result_idx == SEARCH_REMOVE_SERVER_1_OFFSET) L("Account: Remove server 1") else if (result_idx == SEARCH_REMOVE_SERVER_2_OFFSET) L("Account: Remove server 2") else if (result_idx == SEARCH_REMOVE_SERVER_3_OFFSET) L("Account: Remove server 3") else if (is_approve_devices) L("Account: Approve devices") else if (is_layout_pull) L("Sync: Pull Now") else if (is_sync_signout) L("Account: Sign Out") else L("Account: Devices"), -1, &sync_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var sync_hint_rc = RECT{ .left = ox + overlay_w - 130, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("desktop sync"), -1, &sync_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_usage_login) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var login_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 150, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (is_usage_login_primary) L("Usage: Sign In to Primary Claude Account") else L("Usage: Sign In to Secondary Claude Account"), -1, &login_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var login_hint_rc = RECT{ .left = ox + overlay_w - 150, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (is_usage_login_primary) L("owner@example.com") else L("secondary@example.com"), -1, &login_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_endtmux) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else if (app_state.g_light_theme) RGB(130, 45, 45) else RGB(230, 135, 135));
                        var et_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 130, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("End tmux session"), -1, &et_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(230, 210, 210) else RGB(140, 100, 100));
                        var et_hint_rc = RECT{ .left = ox + overlay_w - 130, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Ctrl+Shift+W"), -1, &et_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_ws_snooze or is_ws_snoozed or is_ws_snoozed_row) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 130, .bottom = ry + row_h };
                        if (is_ws_snoozed_row) {
                            const e = &app_state.g_reminders[result_idx - SEARCH_WS_SNOOZED_ROW_OFFSET];
                            var label_buf: [100]u8 = undefined;
                            const label = std.fmt.bufPrint(&label_buf, "Workspace: Wake {s}", .{e.name[0..e.name_len]}) catch "Workspace: Wake";
                            drawAscii(hdc, label, &rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                        } else {
                            _ = DrawTextW(hdc, if (is_ws_snooze) L("Workspace: Snooze...") else if (is_ws_bringback) L("Workspace: Bring Back All Sessions") else L("Workspace: Snoozed..."), -1, &rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        }
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(190, 235, 190) else RGB(110, 180, 110));
                        var hint_buf: [32]u8 = undefined;
                        const hint = if (is_ws_snoozed_row) workspaceWakeLabel(app_state.g_reminders[result_idx - SEARCH_WS_SNOOZED_ROW_OFFSET].due_at, &hint_buf) else if (is_ws_snooze) "Ctrl+Shift+Y" else if (is_ws_bringback) "reattach all" else "wake now";
                        var hint_rc = RECT{ .left = ox + overlay_w - 128, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        drawAscii(hdc, hint, &hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_remind_me) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var rm_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 130, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Remind Me..."), -1, &rm_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var rm_hint_rc = RECT{ .left = ox + overlay_w - 130, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Ctrl+H"), -1, &rm_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_reminders_menu) {
                        loadRemindersIfNeeded();
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var rl_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Reminders"), -1, &rl_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var count_buf: [16]u8 = undefined;
                        const count_s = std.fmt.bufPrint(&count_buf, "{d}", .{app_state.g_reminder_count}) catch "list";
                        var count_w: [16]u16 = undefined;
                        for (count_s, 0..) |c, ci| count_w[ci] = @intCast(c);
                        var rl_hint_rc = RECT{ .left = ox + overlay_w - 90, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, @ptrCast(&count_w), @intCast(count_s.len), &rl_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_remind_preset) {
                        const preset_i = result_idx - SEARCH_REMIND_PRESET_OFFSET;
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var rp_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 130, .bottom = ry + row_h };
                        drawAscii(hdc, remindPresetLabel(preset_i), &rp_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var rp_hint_buf: [24]u8 = undefined;
                        const rp_hint = remindPresetHint(preset_i, &rp_hint_buf);
                        var rp_hint_rc = RECT{ .left = ox + overlay_w - 130, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        drawAscii(hdc, rp_hint, &rp_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_reopen) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var ro_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 110, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Reopen Closed Tab"), -1, &ro_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var ro_hint_rc = RECT{ .left = ox + overlay_w - 110, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Ctrl+Shift+T"), -1, &ro_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_urlpick) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var up_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Open URL from Screen"), -1, &up_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var up_hint_rc = RECT{ .left = ox + overlay_w - 90, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Alt+W"), -1, &up_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_closetab) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var ct_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Close Tab"), -1, &ct_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var ct_hint_rc = RECT{ .left = ox + overlay_w - 90, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Ctrl+W"), -1, &ct_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_inbox_exclude) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var ix_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].inbox_excluded) L("Inbox: Show This Session Again") else L("Inbox: Never Show This Session"), -1, &ix_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                    } else if (is_favorite) {
                        const favorite = app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].favorite;
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var favorite_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 150, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Favorite: Toggle"), -1, &favorite_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        var hint_rc = RECT{ .left = ox + overlay_w - 150, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (favorite) L("on  Alt+S") else L("off  Alt+S"), -1, &hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_mutetab) {
                        const mt_muted = app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].muted;
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var mt_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 80, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (mt_muted) L("Unmute Tab") else L("Mute Tab"), -1, &mt_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var mt_hint_rc = RECT{ .left = ox + overlay_w - 80, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (mt_muted) L("on") else L("off"), -1, &mt_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_keepalive) {
                        const ka_on = app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].keep_alive;
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var ka_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 80, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (ka_on) L("Keep Alive: On") else L("Keep Alive: Off"), -1, &ka_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var ka_hint_rc = RECT{ .left = ox + overlay_w - 80, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("persist"), -1, &ka_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_pin_top) {
                        const pin_on = app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].pinned_top;
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var pt_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 80, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (pin_on) L("Unpin from Top") else L("Pin to Top"), -1, &pt_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var pt_hint_rc = RECT{ .left = ox + overlay_w - 80, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (pin_on) L("on") else L("off"), -1, &pt_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_chat_view) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var chat_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 100, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (app_state.g_chat_active) L("Return to Terminal") else L("Open Chat View"), -1, &chat_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var chat_hint_rc = RECT{ .left = ox + overlay_w - 100, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Alt+C"), -1, &chat_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_chat_allow) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var permission_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 100, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Chat View: Allow"), -1, &permission_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        permission_rc.left = ox + overlay_w - 100;
                        permission_rc.right = ox + overlay_w - 8;
                        _ = paletteDrawText(hdc, L("Alt+Y"), -1, &permission_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_chat_always) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var permission_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 100, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Chat View: Always allow"), -1, &permission_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        permission_rc.left = ox + overlay_w - 100;
                        permission_rc.right = ox + overlay_w - 8;
                        _ = paletteDrawText(hdc, L("Alt+O"), -1, &permission_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_chat_deny) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var permission_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 100, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Chat View: Deny"), -1, &permission_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        permission_rc.left = ox + overlay_w - 100;
                        permission_rc.right = ox + overlay_w - 8;
                        _ = paletteDrawText(hdc, L("Alt+D"), -1, &permission_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_chat_stop) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else if (app_state.g_light_theme) RGB(130, 45, 45) else RGB(230, 135, 135));
                        var stop_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 100, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, (if (app_state.ISSUE_265_WORKING_BAR) L("Chat View: Stop the agent") else L("Stop Agent")), -1, &stop_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(230, 210, 210) else RGB(140, 100, 100));
                        var stop_hint_rc = RECT{ .left = ox + overlay_w - 100, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, (if (app_state.ISSUE_265_WORKING_BAR) L("Esc") else L("Ctrl+C")), -1, &stop_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_browser_toggle) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var bt_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_open_failed) L("Retry Browser Pane") else if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_launch_tick != 0) L("Close Browser Pane") else L("Open Browser Pane"), -1, &bt_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var bt_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_open_failed) L("Alt+Shift+A") else L("Alt+A"), -1, &bt_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_browser_url) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var bu_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Browser: Open URL..."), -1, &bu_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var bu_hint_rc = RECT{ .left = ox + overlay_w - 90, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("url"), -1, &bu_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_browser_shoturl) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var bsurl_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 130, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Browser: Screenshot \u{2192} Chat View / Shell"), -1, &bsurl_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var bsurl_hint_rc = RECT{ .left = ox + overlay_w - 130, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Ctrl+Shift+S"), -1, &bsurl_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_browser_history) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var bh_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 110, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (is_browser_forward) L("Browser: Forward") else L("Browser: Back"), -1, &bh_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var bh_hint_rc = RECT{ .left = ox + overlay_w - 110, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (is_browser_forward) L("Alt+Right") else L("Alt+Left"), -1, &bh_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_browser_focus_url) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var bf_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 130, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Browser: Focus Address Bar"), -1, &bf_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var bf_hint_rc = RECT{ .left = ox + overlay_w - 130, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Ctrl+Shift+L"), -1, &bf_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_browser_focus_toggle) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var bj_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Browser: Switch Focus Between Terminal and Pane"), -1, &bj_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var bj_hint_rc = RECT{ .left = ox + overlay_w - 90, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Alt+Q"), -1, &bj_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_browser_engine) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        const be_label = if (app_state.g_browser_engine == .edge)
                            L("Browser: Switch All Panes to Chrome")
                        else
                            L("Browser: Switch All Panes to Edge");
                        var be_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, be_label, -1, &be_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                    } else if (is_browser_mode) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        const bm_label = if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_native)
                            L("Browser: Use App Address Bar")
                        else
                            L("Browser: Use Browser Address Bar and Tabs");
                        var bm_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, bm_label, -1, &bm_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                    } else if (is_zsb_rebind) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var zr_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 100, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Browser: Repair Agent Connection"), -1, &zr_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var zr_hint_rc = RECT{ .left = ox + overlay_w - 100, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("force"), -1, &zr_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_shell_diag) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var sd_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 100, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Copy Session Diagnostics"), -1, &sd_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var sd_hint_rc = RECT{ .left = ox + overlay_w - 100, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("copy"), -1, &sd_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_sync_name or is_rename_sync) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var sn_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (is_sync_name) L("Use Agent or Terminal Session Name") else L("Rename Session"), -1, &sn_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var sn_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (is_sync_name) L("/rename") else L("edit"), -1, &sn_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_external_browser_links) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var links_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 60, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("External Browser Links When Pane Off"), -1, &links_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        links_rc.left = ox + overlay_w - 60;
                        links_rc.right = ox + overlay_w - 8;
                        _ = DrawTextW(hdc, if (app_state.g_external_browser_links) L("on") else L("off"), -1, &links_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_browser_autosuspend) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var bs_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (app_state.g_browser_autosuspend) L("Browser: Auto-Suspend Idle Panes: On") else L("Browser: Auto-Suspend Idle Panes: Off"), -1, &bs_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var bs_hint_buf: [16]u8 = undefined;
                        const bs_hint_s: []const u8 = if (app_state.g_browser_autosuspend) std.fmt.bufPrint(&bs_hint_buf, "{d} min", .{app_state.g_browser_suspend_min}) catch bs_hint_buf[0..0] else "off";
                        var bs_hint: [16]u16 = undefined;
                        for (bs_hint_s, 0..) |c, ci| bs_hint[ci] = c;
                        var bs_hint_rc = RECT{ .left = ox + overlay_w - 90, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, @ptrCast(&bs_hint), @intCast(bs_hint_s.len), &bs_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_keepawake) {
                        const kaw_on = app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].keep_awake;
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var kaw_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (kaw_on) L("Keep Tab Awake: On") else L("Keep Tab Awake: Off"), -1, &kaw_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var kaw_hint_rc = RECT{ .left = ox + overlay_w - 90, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Alt+P"), -1, &kaw_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_crash_cmd) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var crash_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (result_idx == SEARCH_CRASH_NOW_OFFSET) L("Debug: Crash Now") else L("Crash Reports: Open Folder"), -1, &crash_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                    } else if (is_hibernate_now or is_close_all_browser_panes) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var hib_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, if (is_close_all_browser_panes) L("Close All Browser Panes") else L("Hibernate Browser Panes Now"), -1, &hib_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                    } else if (is_browser_instruct) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var bi_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Browser: Insert Agent Instructions"), -1, &bi_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var bi_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("paste"), -1, &bi_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_ui_bigger) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var ub_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 80, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("UI Size: Increase"), -1, &ub_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var ub_hint_buf: [8]u8 = undefined;
                        var ub_hint: [8]u16 = undefined;
                        const ub_s = std.fmt.bufPrint(&ub_hint_buf, "{d}%", .{app_state.g_ui_scale}) catch ub_hint_buf[0..0];
                        for (0..ub_s.len) |ii| ub_hint[ii] = @intCast(ub_s[ii]);
                        var ub_hint_rc = RECT{ .left = ox + overlay_w - 80, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, @ptrCast(&ub_hint), @intCast(ub_s.len), &ub_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_ui_smaller) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var us_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 80, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("UI Size: Decrease"), -1, &us_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var us_hint_buf: [8]u8 = undefined;
                        var us_hint: [8]u16 = undefined;
                        const us_s = std.fmt.bufPrint(&us_hint_buf, "{d}%", .{app_state.g_ui_scale}) catch us_hint_buf[0..0];
                        for (0..us_s.len) |ii| us_hint[ii] = @intCast(us_s[ii]);
                        var us_hint_rc = RECT{ .left = ox + overlay_w - 80, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, @ptrCast(&us_hint), @intCast(us_s.len), &us_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_ui_reset) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var ur_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 80, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("UI Size: Reset"), -1, &ur_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var ur_hint_rc = RECT{ .left = ox + overlay_w - 80, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("100%"), -1, &ur_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_workspace_delete) {
                        const workspace_idx = result_idx - SEARCH_WORKSPACE_DELETE_OFFSET;
                        if (workspace_idx < app_state.g_workspace_count) {
                            const e = &app_state.g_workspaces[workspace_idx];
                            _ = SelectObject(hdc, palette_font);
                            _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else if (app_state.g_light_theme) RGB(130, 45, 45) else RGB(230, 135, 135));
                            var ws_buf: [112]u16 = undefined;
                            var wsl: usize = 0;
                            const confirming = if (app_state.g_search_workspace_delete_confirm) |c| c == @as(u32, @intCast(workspace_idx)) else false;
                            const prefix = if (confirming) "Press Enter Again: " else "Delete Workspace: ";
                            for (prefix) |c| {
                                ws_buf[wsl] = c;
                                wsl += 1;
                            }
                            for (0..e.name_len) |ni| {
                                if (wsl >= ws_buf.len) break;
                                ws_buf[wsl] = @intCast(e.name[ni]);
                                wsl += 1;
                            }
                            var ws_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                            _ = DrawTextW(hdc, @ptrCast(&ws_buf), @intCast(wsl), &ws_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                            _ = SelectObject(hdc, palette_hint_font);
                            _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(230, 210, 210) else RGB(140, 100, 100));
                            var ws_hint: [64]u16 = undefined;
                            const hint: []const u8 = if (confirming) "confirm" else if (workspaceIsLiveAnywhere(e.id[0..e.id_len])) "open" else e.id[0..e.id_len];
                            const id_len = @min(hint.len, ws_hint.len);
                            for (0..id_len) |ii| ws_hint[ii] = @intCast(hint[ii]);
                            var ws_hint_rc = RECT{ .left = ox + overlay_w - 90, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                            _ = DrawTextW(hdc, @ptrCast(&ws_hint), @intCast(id_len), &ws_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                        }
                    } else if (is_workspace) {
                        const workspace_idx = result_idx - SEARCH_WORKSPACE_OFFSET;
                        if (workspace_idx < app_state.g_workspace_count) {
                            const e = &app_state.g_workspaces[workspace_idx];
                            _ = SelectObject(hdc, palette_font);
                            const id = e.id[0..e.id_len];
                            var is_current = std.mem.eql(u8, id, getInstanceName());
                            if (!is_current and app_state.g_single_window) {
                                if (findMyWorkspaceSlot(id)) |slot| is_current = (slot == app_state.g_active_workspace);
                            }
                            const is_live = workspaceIsLiveAnywhere(id);
                            _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else if (is_current) RGB(120, 120, 130) else if (app_state.g_light_theme) RGB(60, 60, 60) else RGB(180, 180, 180));
                            var ws_buf: [96]u16 = undefined;
                            var wsl: usize = 0;
                            const prefix = if (is_live) "Switch to Workspace: " else "Open Workspace: ";
                            for (prefix) |c| {
                                ws_buf[wsl] = c;
                                wsl += 1;
                            }
                            for (0..e.name_len) |ni| {
                                if (wsl >= ws_buf.len) break;
                                ws_buf[wsl] = @intCast(e.name[ni]);
                                wsl += 1;
                            }
                            var ws_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                            _ = DrawTextW(hdc, @ptrCast(&ws_buf), @intCast(wsl), &ws_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                            _ = SelectObject(hdc, palette_hint_font);
                            _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                            var ws_hint: [64]u16 = undefined;
                            const hint: []const u8 = if (is_current) "current" else if (is_live) "open" else id;
                            const id_len = @min(hint.len, ws_hint.len);
                            for (0..id_len) |ii| ws_hint[ii] = @intCast(hint[ii]);
                            var ws_hint_rc = RECT{ .left = ox + overlay_w - 90, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                            _ = DrawTextW(hdc, @ptrCast(&ws_hint), @intCast(id_len), &ws_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                        }
                    } else if (is_archived) {
                        const ar_idx = result_idx - SEARCH_ARCHIVED_OFFSET;
                        loadArchiveIfNeeded();
                        if (ar_idx < app_state.g_archived_count) {
                            const ar = &app_state.g_archived.items[ar_idx];
                            _ = SelectObject(hdc, palette_font);
                            _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else if (app_state.g_light_theme) RGB(30, 90, 180) else RGB(100, 160, 240));
                            var ar_buf: [96]u16 = undefined;
                            var arl: usize = 0;
                            for ("\u{21A9} ") |ch| {
                                if (arl >= ar_buf.len) break;
                                ar_buf[arl] = ch;
                                arl += 1;
                            }
                            for (0..ar.name_len) |j| {
                                if (arl >= ar_buf.len) break;
                                ar_buf[arl] = @intCast(ar.name[j]);
                                arl += 1;
                            }
                            var ar_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 60, .bottom = ry + row_h };
                            _ = DrawTextW(hdc, @ptrCast(&ar_buf), @intCast(arl), &ar_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                            _ = SelectObject(hdc, palette_hint_font);
                            _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(190, 235, 190) else RGB(110, 180, 110));
                            const host_hint: [*:0]const u16 = switch (ar.tmux_host) {
                                TMUX_HOST_UK => L("UK"),
                                TMUX_HOST_INNE => L("HOST3"),
                                else => L("DE"),
                            };
                            var ah_rc = RECT{ .left = ox + overlay_w - 60, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                            _ = DrawTextW(hdc, host_hint, -1, &ah_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                        }
                    } else if (is_reminder_row) {
                        const rem_idx = result_idx - SEARCH_REMINDER_ROW_OFFSET;
                        loadRemindersIfNeeded();
                        if (rem_idx < app_state.g_reminder_count) {
                            const rem = &app_state.g_reminders[rem_idx];
                            _ = SelectObject(hdc, palette_font);
                            _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else if (app_state.g_light_theme) RGB(30, 90, 180) else RGB(100, 160, 240));
                            var rem_buf: [112]u16 = undefined;
                            var rml: usize = 0;
                            for ("Remind: ") |ch| {
                                if (rml >= rem_buf.len) break;
                                rem_buf[rml] = ch;
                                rml += 1;
                            }
                            for (rem.name[0..rem.name_len]) |ch| {
                                if (rml >= rem_buf.len) break;
                                rem_buf[rml] = @intCast(ch);
                                rml += 1;
                            }
                            var rem_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 130, .bottom = ry + row_h };
                            _ = DrawTextW(hdc, @ptrCast(&rem_buf), @intCast(rml), &rem_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
                            _ = SelectObject(hdc, palette_hint_font);
                            _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(190, 235, 190) else RGB(110, 180, 110));
                            var due_buf: [32]u8 = undefined;
                            const due_s = reminderDueLabel(rem.due_at, &due_buf);
                            var hint_buf: [80]u16 = undefined;
                            var hl: usize = 0;
                            for (due_s) |c| {
                                if (hl >= hint_buf.len) break;
                                hint_buf[hl] = @intCast(c);
                                hl += 1;
                            }
                            if (rem.workspace_name_len > 0 and hl + 3 < hint_buf.len) {
                                hint_buf[hl] = ' ';
                                hl += 1;
                                hint_buf[hl] = '-';
                                hl += 1;
                                hint_buf[hl] = ' ';
                                hl += 1;
                                for (rem.workspace_name[0..rem.workspace_name_len]) |c| {
                                    if (hl >= hint_buf.len) break;
                                    hint_buf[hl] = @intCast(c);
                                    hl += 1;
                                }
                            }
                            var rh_rc = RECT{ .left = ox + overlay_w - 130, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                            _ = DrawTextW(hdc, @ptrCast(&hint_buf), @intCast(hl), &rh_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX | DT_END_ELLIPSIS);
                        }
                    } else if (is_customcmd) {
                        const cc_idx = result_idx - SEARCH_CUSTOMCMD_OFFSET;
                        if (cc_idx < app_state.g_custom_cmds_count) {
                            const cc = &app_state.g_custom_cmds[cc_idx];
                            _ = SelectObject(hdc, palette_font);
                            _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else if (app_state.g_light_theme) RGB(30, 90, 180) else RGB(100, 160, 240));
                            var cc_buf: [96]u16 = undefined;
                            var ccl: usize = 0;
                            for ("+ ") |ch| {
                                cc_buf[ccl] = ch;
                                ccl += 1;
                            }
                            for (0..cc.label_len) |j| {
                                if (ccl >= cc_buf.len) break;
                                cc_buf[ccl] = @intCast(cc.label[j]);
                                ccl += 1;
                            }
                            var cc_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 110, .bottom = ry + row_h };
                            _ = DrawTextW(hdc, @ptrCast(&cc_buf), @intCast(ccl), &cc_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                            _ = SelectObject(hdc, palette_hint_font);
                            _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(190, 235, 190) else RGB(110, 180, 110));
                            var cc_hint: [24]u16 = undefined;
                            var chl: usize = 0;
                            const kind_tag: []const u8 = switch (cc.kind) {
                                .vps => "DE",
                                .vps2 => "UK",
                                .pwsh => "PWSH",
                                else => "CMD",
                            };
                            for (kind_tag) |ch| {
                                cc_hint[chl] = ch;
                                chl += 1;
                            }
                            var cc_hint_rc = RECT{ .left = ox + overlay_w - 110, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                            _ = DrawTextW(hdc, @ptrCast(&cc_hint), @intCast(chl), &cc_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                        }
                    } else if (is_tabctx) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var tc_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 130, .bottom = ry + row_h };
                        if (result_idx >= SEARCH_TABCTX_GROUP_ADD_OFFSET and result_idx < SEARCH_TABCTX_GROUP_ADD_OFFSET + MAX_GROUPS) {
                            const gi = result_idx - SEARCH_TABCTX_GROUP_ADD_OFFSET;
                            var gal_buf: [96]u16 = std.mem.zeroes([96]u16);
                            var gal_i: usize = 0;
                            for ("Add to group: ") |c| {
                                if (gal_i >= gal_buf.len - 1) break;
                                gal_buf[gal_i] = c;
                                gal_i += 1;
                            }
                            if (gi < app_state.group_count) {
                                for (0..app_state.groups[gi].name_len) |j| {
                                    if (gal_i >= gal_buf.len - 1) break;
                                    gal_buf[gal_i] = app_state.groups[gi].name[j];
                                    gal_i += 1;
                                }
                                if (app_state.groups[gi].name_len == 0) {
                                    for ("(unnamed)") |c| {
                                        if (gal_i >= gal_buf.len - 1) break;
                                        gal_buf[gal_i] = c;
                                        gal_i += 1;
                                    }
                                }
                            }
                            _ = DrawTextW(hdc, @ptrCast(&gal_buf), @intCast(gal_i), &tc_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        } else {
                            const tc_excluded = if (findShellById(app_state.g_tabctx_sid)) |ti| app_state.shells[ti].inbox_excluded else false;
                            const tc_favorite = if (findShellById(app_state.g_tabctx_sid)) |ti| app_state.shells[ti].favorite else false;
                            const tc_muted = if (findShellById(app_state.g_tabctx_sid)) |ti| app_state.shells[ti].muted else false;
                            const tc_ka = if (findShellById(app_state.g_tabctx_sid)) |ti| app_state.shells[ti].keep_alive else false;
                            const tc_pinned = if (findShellById(app_state.g_tabctx_sid)) |ti| app_state.shells[ti].pinned_top else false;
                            const tc_kaw = if (findShellById(app_state.g_tabctx_sid)) |ti| app_state.shells[ti].keep_awake else false;
                            const tc_browser_on = if (findShellById(app_state.g_tabctx_sid)) |ti| app_state.shells[ti].browser_enabled else false;
                            const tc_has_tmux = if (findShellById(app_state.g_tabctx_sid)) |ti| app_state.shells[ti].tmux_session_len > 0 else false;
                            const tc_label: [*:0]const u16 = if (result_idx == SEARCH_TABCTX_START_SESSION) L("Start new session") else if (result_idx == SEARCH_TABCTX_FAVORITE) (if (tc_favorite) L("Unfavorite") else L("Favorite")) else if (result_idx == SEARCH_TABCTX_CHAT_ALLOW) L("Chat View: Allow") else if (result_idx == SEARCH_TABCTX_CHAT_ALWAYS) L("Chat View: Always allow") else if (result_idx == SEARCH_TABCTX_CHAT_DENY) L("Chat View: Deny") else if (result_idx == SEARCH_TABCTX_CHAT_STOP) L("Chat View: Stop the agent") else if (result_idx == SEARCH_TABCTX_CHAT_TAB_URL) L("Chat View: Insert browser tab URL") else if (result_idx == SEARCH_TABCTX_CHAT_RESET) L("Chat View: Reset this chat") else if (result_idx == SEARCH_TABCTX_BACK) L("Back") else if (result_idx == SEARCH_TABCTX_RECONNECT) L("Reattach Tab") else if (result_idx == SEARCH_TABCTX_INBOX_EXCLUDE) (if (tc_excluded) L("Inbox: Show This Session Again") else L("Inbox: Never Show This Session")) else if (result_idx == SEARCH_TABCTX_MUTE) (if (tc_muted) L("Unmute Tab") else L("Mute Tab")) else if (result_idx == SEARCH_TABCTX_KEEPALIVE) (if (tc_ka) L("Keep Alive: On") else L("Keep Alive: Off")) else if (result_idx == SEARCH_TABCTX_PIN_TOP) (if (tc_pinned) L("Unpin from Top") else L("Pin to Top")) else if (result_idx == SEARCH_TABCTX_KEEPAWAKE) (if (tc_kaw) L("Keep Tab Awake: On") else L("Keep Tab Awake: Off")) else if (result_idx == SEARCH_TABCTX_WSMOVE) L("Move to Workspace\u{2026}") else if (result_idx == SEARCH_TABCTX_GROUP_NEW) L("Add to new group") else if (result_idx == SEARCH_TABCTX_GROUP_REMOVE) L("Remove from group") else if (result_idx == SEARCH_TABCTX_GROUP_NEW_TAB_IN) L("New tab in group") else if (result_idx == SEARCH_TABCTX_MOVE_NEW_WS) L("Move to NEW workspace") else if (result_idx == SEARCH_TABCTX_CLEAR_SEL) L("Clear tab selection") else if (result_idx == SEARCH_TABCTX_ARCHIVE) (if (tc_has_tmux) L("Archive Session") else L("Close Session")) else if (result_idx == SEARCH_TABCTX_END_TMUX) L("End tmux session") else if (result_idx == SEARCH_TABCTX_BROWSER) (if (tc_browser_on) L("Close Browser Pane") else L("Open Browser Pane")) else L("Tab action");
                            _ = DrawTextW(hdc, tc_label, -1, &tc_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                            const tc_shortcut: ?[*:0]const u16 = if (result_idx == SEARCH_TABCTX_CHAT_TAB_URL) L("Ctrl+Shift+X") else if (result_idx == SEARCH_TABCTX_FAVORITE) L("Alt+S") else if (result_idx == SEARCH_TABCTX_BACK) L("Esc") else if (result_idx == SEARCH_TABCTX_RECONNECT) L("Ctrl+Shift+R") else if (result_idx == SEARCH_TABCTX_ARCHIVE) L("Alt+X") else if (result_idx == SEARCH_TABCTX_END_TMUX) L("Ctrl+Shift+W") else if (result_idx == SEARCH_TABCTX_BROWSER) L("Alt+A") else if (result_idx == SEARCH_TABCTX_KEEPAWAKE) L("Alt+P") else null;
                            if (tc_shortcut) |tc_hint| {
                                _ = SelectObject(hdc, palette_hint_font);
                                _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                                var tc_hint_rc = RECT{ .left = ox + overlay_w - 130, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                                _ = DrawTextW(hdc, tc_hint, -1, &tc_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                            } else if (result_idx == SEARCH_TABCTX_WSMOVE) {
                                _ = SelectObject(hdc, palette_hint_font);
                                _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                                var tc_hint_rc = RECT{ .left = ox + overlay_w - 130, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                                _ = paletteDrawText(hdc, L("move"), -1, &tc_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                            }
                        }
                    } else if (is_renamewin) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var rw_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 140, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Rename Workspace"), -1, &rw_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var rw_hint_rc = RECT{ .left = ox + overlay_w - 140, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, @ptrCast(&app_state.g_window_display_name), @intCast(app_state.g_window_display_name_len), &rw_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_codex_tmux) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else if (app_state.g_light_theme) RGB(30, 90, 180) else RGB(100, 160, 240));
                        var cx_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 110, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("New Codex Session in This Folder"), -1, &cx_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);

                        var host: u8 = 0;
                        var cwd_buf: [256]u8 = undefined;
                        var cwd_len: u32 = 0;
                        _ = activeRemoteContextForCodexTmux(&host, &cwd_buf, &cwd_len);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(190, 235, 190) else RGB(110, 180, 110));
                        const host_hint: [*:0]const u16 = switch (host) {
                            TMUX_HOST_UK => L("UK tmux"),
                            TMUX_HOST_INNE => L("HOST3 tmux"),
                            else => L("DE tmux"),
                        };
                        var cx_hint_rc = RECT{ .left = ox + overlay_w - 110, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, host_hint, -1, &cx_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_newwin) {
                        const is_createws = (result_idx == SEARCH_CREATEWS_OFFSET);
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var nw_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                        const newwin_label = if (is_createws) L("Create Workspace") else if (app_state.g_search_workspace_mode) L("New Workspace") else L("New Window");
                        _ = DrawTextW(hdc, newwin_label, -1, &nw_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        if (!is_createws) {
                            _ = SelectObject(hdc, palette_hint_font);
                            _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                            var nw_hint_rc = RECT{ .left = ox + overlay_w - 90, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                            _ = paletteDrawText(hdc, L("Ctrl+N"), -1, &nw_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                        }
                    } else if (is_openall) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else if (app_state.g_light_theme) RGB(30, 120, 30) else RGB(100, 180, 100));
                        var openall_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 12, .bottom = ry + row_h };
                        const openall_label = switch (result_idx) {
                            SEARCH_RECOVER_REPO_OFFSET => L("Recover workspace tmux sessions"),
                            SEARCH_OPENFOLDER_OFFSET => L("Open sessions in this folder"),
                            SEARCH_OPENALL_HOST_BACK_OFFSET => L("Back"),
                            SEARCH_OPENALL_HOST_DE_OFFSET => L("Host 1 VPS"),
                            SEARCH_OPENALL_HOST_UK_OFFSET => L("Host 2 VPS"),
                            SEARCH_OPENALL_HOST_INNE_OFFSET => L("Remote host 3"),
                            else => L("Open all VPS tmux sessions..."),
                        };
                        _ = DrawTextW(hdc, openall_label, -1, &openall_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                    } else if (is_theme_back) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var back_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 100, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Back"), -1, &back_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        var back_hint_rc = RECT{ .left = ox + overlay_w - 100, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("main"), -1, &back_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (result_idx == SEARCH_SETTINGS_OFFSET) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var settings_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 100, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Settings"), -1, &settings_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        var hint_rc = RECT{ .left = ox + overlay_w - 100, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Ctrl+,"), -1, &hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_theme_menu) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var theme_menu_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 120, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Themes..."), -1, &theme_menu_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        const current_theme = if (app_state.g_system_theme) (if (app_state.g_light_theme) L("System Light") else L("System Dark")) else if (app_state.g_multiprompt_theme) L("multiprompt") else if (app_state.g_dev_theme_active) L("Dev Blue") else if (app_state.g_light_theme) L("Light") else if (app_state.g_edge_gray_theme) L("Edge Grey") else if (app_state.g_mid_theme) L("Mid") else if (app_state.g_amoled_theme) L("AMOLED") else L("Dark");
                        var theme_menu_hint_rc = RECT{ .left = ox + overlay_w - 120, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, current_theme, -1, &theme_menu_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_theme_choice) {
                        _ = SelectObject(hdc, palette_font);
                        const theme_current = switch (result_idx) {
                            SEARCH_THEME_SYSTEM_OFFSET => app_state.g_system_theme,
                            SEARCH_THEME_DARK_OFFSET => !app_state.g_system_theme and !app_state.g_multiprompt_theme and !app_state.g_dev_theme_active and !app_state.g_light_theme and !app_state.g_mid_theme and !app_state.g_edge_gray_theme and !app_state.g_amoled_theme,
                            SEARCH_THEME_MID_OFFSET => !app_state.g_system_theme and !app_state.g_multiprompt_theme and !app_state.g_dev_theme_active and app_state.g_mid_theme,
                            SEARCH_THEME_LIGHT_OFFSET => !app_state.g_system_theme and !app_state.g_multiprompt_theme and !app_state.g_dev_theme_active and app_state.g_light_theme,
                            SEARCH_THEME_AMOLED_OFFSET => !app_state.g_system_theme and !app_state.g_multiprompt_theme and !app_state.g_dev_theme_active and app_state.g_amoled_theme,
                            SEARCH_THEME_EDGE_GRAY_OFFSET => !app_state.g_system_theme and !app_state.g_multiprompt_theme and !app_state.g_dev_theme_active and app_state.g_edge_gray_theme,
                            SEARCH_THEME_DEV_BLUE_OFFSET => !app_state.g_system_theme and !app_state.g_multiprompt_theme and app_state.g_dev_theme_active,
                            SEARCH_THEME_MULTIPROMPT_OFFSET => !app_state.g_system_theme and app_state.g_multiprompt_theme,
                            else => false,
                        };
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else if (theme_current) customColorOr("accent", if (app_state.g_light_theme) RGB(30, 90, 180) else RGB(100, 160, 240)) else customColorOr("text_inactive", if (app_state.g_light_theme) RGB(60, 60, 60) else RGB(180, 180, 180)));
                        const theme_choice_label = switch (result_idx) {
                            SEARCH_THEME_SYSTEM_OFFSET => L("System"),
                            SEARCH_THEME_DARK_OFFSET => L("Dark"),
                            SEARCH_THEME_MID_OFFSET => L("Mid"),
                            SEARCH_THEME_LIGHT_OFFSET => L("Light"),
                            SEARCH_THEME_AMOLED_OFFSET => L("AMOLED"),
                            SEARCH_THEME_EDGE_GRAY_OFFSET => L("Edge Grey"),
                            SEARCH_THEME_DEV_BLUE_OFFSET => L("Dev Blue"),
                            SEARCH_THEME_MULTIPROMPT_OFFSET => L("multiprompt"),
                            else => L("Theme"),
                        };
                        var theme_choice_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 100, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, theme_choice_label, -1, &theme_choice_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        if (theme_current) {
                            _ = SelectObject(hdc, palette_hint_font);
                            _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 190, 220) else customColorOr("hint", RGB(100, 100, 110)));
                            var current_hint_rc = RECT{ .left = ox + overlay_w - 100, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                            _ = paletteDrawText(hdc, L("current"), -1, &current_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                        }
                    } else if (is_theme_dev_edit) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else customColorOr("text_inactive", if (app_state.g_light_theme) RGB(60, 60, 60) else RGB(180, 180, 180)));
                        var edit_theme_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 100, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Edit Dev Theme JSON"), -1, &edit_theme_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 190, 220) else customColorOr("hint", RGB(100, 100, 110)));
                        var edit_hint_rc = RECT{ .left = ox + overlay_w - 100, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("colors/fonts"), -1, &edit_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_theme_dev_reload) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(255, 255, 255) else customColorOr("text_inactive", if (app_state.g_light_theme) RGB(60, 60, 60) else RGB(180, 180, 180)));
                        var reload_theme_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 100, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("Reload Dev Theme"), -1, &reload_theme_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 190, 220) else customColorOr("hint", RGB(100, 100, 110)));
                        var reload_hint_rc = RECT{ .left = ox + overlay_w - 100, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, L("apply"), -1, &reload_hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_sound_toggle) {
                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        const snd_label = if (app_state.g_sound_enabled) L("Notification Sounds: On") else L("Notification Sounds: Off");
                        var snd_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 12, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, snd_label, -1, &snd_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                    } else if (is_new_shell) {
                        const kind_idx = result_idx - SEARCH_NEW_OFFSET;
                        const new_display = [NUM_BUTTONS]LPCWSTR{
                            L("New CMD Shell"),
                            L("Attach Host 1 tmux Session"),
                            L("Attach Host 2 tmux Session"),
                            L("New Host 1 VPS Shell"),
                            L("New Host 2 VPS Shell"),
                            L("New PowerShell"),
                            L("New Bash Shell"),
                            L("New Git Bash Shell"),
                        };

                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        var new_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, new_display[kind_idx], -1, &new_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);

                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(160, 160, 170) else RGB(100, 100, 110));
                        const new_hints = [NUM_BUTTONS]LPCWSTR{ L("C-S-1"), L("C-S-2"), L("C-S-3"), L("C-S-4"), L("C-S-5"), L("C-S-6"), L("C-S-7"), L("C-S-8") };
                        var ntag_rc = RECT{ .left = ox + overlay_w - 90, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = paletteDrawText(hdc, new_hints[kind_idx], -1, &ntag_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else if (is_tmux_inactive) {
                        const cache_idx = result_idx - SEARCH_TMUX_OFFSET;
                        const sess = app_state.g_tmux_cache[cache_idx];
                        const sname = sess.name[0..sess.name_len];

                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (ri == app_state.g_search_sel) RGB(220, 220, 220) else RGB(160, 160, 160));
                        if (sess.title_len > 0) {
                            var title_w: [80]u16 = undefined;
                            for (sess.title[0..sess.title_len], 0..) |c, ti| title_w[ti] = @intCast(c);
                            var tmx_title_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 160, .bottom = ry + row_h };
                            _ = DrawTextW(hdc, @ptrCast(&title_w), @intCast(sess.title_len), &tmx_title_rc, DT_SINGLELINE | DT_VCENTER | DT_END_ELLIPSIS | DT_NOPREFIX);
                        } else {
                            var tmx_name_w: [64]u16 = undefined;
                            for (sname, 0..) |c, ci| tmx_name_w[ci] = @intCast(c);
                            var tmx_name_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - 90, .bottom = ry + row_h };
                            _ = DrawTextW(hdc, @ptrCast(&tmx_name_w), @intCast(sess.name_len), &tmx_name_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                        }

                        _ = SelectObject(hdc, palette_hint_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(100, 100, 100) else RGB(0x8A, 0x8A, 0x8A));
                        var tag_buf2: [80]u16 = undefined;
                        var tbi2: usize = 0;
                        if (sess.title_len > 0) {
                            for (sname) |c| {
                                tag_buf2[tbi2] = @intCast(c);
                                tbi2 += 1;
                            }
                            tag_buf2[tbi2] = ' ';
                            tbi2 += 1;
                            tag_buf2[tbi2] = 0xB7;
                            tbi2 += 1;
                            tag_buf2[tbi2] = ' ';
                            tbi2 += 1;
                        }
                        const host_label = tmuxHostTagLabel(sess.host);
                        for (host_label) |c| {
                            tag_buf2[tbi2] = c;
                            tbi2 += 1;
                        }

                        const hint_w: i32 = if (sess.title_len > 0) 160 else 90;
                        var rtag_rc = RECT{ .left = ox + overlay_w - hint_w, .top = ry, .right = ox + overlay_w - 8, .bottom = ry + row_h };
                        _ = DrawTextW(hdc, @ptrCast(&tag_buf2), @intCast(tbi2), &rtag_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);
                    } else {
                        const shell_idx = result_idx;
                        if (shell_idx >= app_state.shell_count) {
                            var log_buf: [96]u8 = undefined;
                            debugLog(std.fmt.bufPrint(&log_buf, "palette draw: unknown result index {d} (shell_count={d})", .{ shell_idx, app_state.shell_count }) catch "palette draw: unknown result index");
                            continue;
                        }

                        _ = SelectObject(hdc, palette_font);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(0xF2, 0xF2, 0xF2));
                        const show_ws_label = true;
                        var name_rc = RECT{ .left = ox + uiScaled(28), .top = ry, .right = ox + overlay_w - @as(i32, 180), .bottom = ry + row_h };
                        _ = DrawTextW(hdc, @ptrCast(&app_state.shells[shell_idx].name), @intCast(app_state.shells[shell_idx].name_len), &name_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | (if (show_ws_label) DT_END_ELLIPSIS else 0));
                        if (show_ws_label) {
                            _ = SelectObject(hdc, palette_hint_font);
                            _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(100, 100, 100) else RGB(0x8A, 0x8A, 0x8A));
                            var wsl_buf: [32]u8 = undefined;
                            const wsl = workspaceDisplayName(app_state.shells[shell_idx].workspace, &wsl_buf);
                            var wsl_w: [32]u16 = undefined;
                            for (wsl, 0..) |c, wi| wsl_w[wi] = c;
                            var wsl_rc = RECT{ .left = ox + overlay_w - 180, .top = ry, .right = ox + overlay_w - 24, .bottom = ry + row_h };
                            _ = DrawTextW(hdc, @ptrCast(&wsl_w), @intCast(wsl.len), &wsl_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX | DT_END_ELLIPSIS);
                        }
                    }
                }
                if (app_state.g_search_result_count > @import("drawing.zig").searchVisibleRows()) {
                    const track_top = oy + input_h + 5;
                    const track_bottom = oy + input_h + @as(i32, @intCast(visible_capacity)) * row_h - 5;
                    const track_h = track_bottom - track_top;
                    if (track_h > 0) {
                        var track_rc = RECT{ .left = ox + overlay_w - 6, .top = track_top, .right = ox + overlay_w - 3, .bottom = track_bottom };
                        const track_br = CreateSolidBrush(customColorOr("scrollbar_track", if (app_state.g_light_theme) RGB(218, 218, 218) else if (app_state.g_edge_gray_theme) RGB(72, 72, 72) else if (app_state.g_mid_theme) RGB(92, 92, 92) else RGB(66, 66, 66)));
                        _ = FillRect(hdc, &track_rc, track_br);
                        _ = DeleteObject(track_br);

                        const thumb_ratio_h: i32 = @divTrunc(track_h * @as(i32, @intCast(visible_capacity)), @as(i32, @intCast(app_state.g_search_result_count)));
                        const thumb_h: i32 = @min(track_h, @max(24, thumb_ratio_h));
                        const max_scroll = app_state.g_search_result_count - visible_capacity;
                        const scroll_space = track_h - thumb_h;
                        const thumb_top = track_top + if (max_scroll == 0) 0 else @divTrunc(scroll_space * @as(i32, @intCast(app_state.g_search_scroll)), @as(i32, @intCast(max_scroll)));
                        var thumb_rc = RECT{ .left = ox + overlay_w - 7, .top = thumb_top, .right = ox + overlay_w - 2, .bottom = thumb_top + thumb_h };
                        const thumb_br = CreateSolidBrush(customColorOr("scrollbar_thumb", if (app_state.g_light_theme) RGB(145, 145, 145) else if (app_state.g_edge_gray_theme) RGB(150, 150, 150) else if (app_state.g_mid_theme) RGB(160, 160, 160) else RGB(145, 145, 145)));
                        _ = FillRect(hdc, &thumb_rc, thumb_br);
                        _ = DeleteObject(thumb_br);
                    }
                }
            }
        }
    }

    if (app_state.g_shortcuts_active) {
        var win_rc: RECT = std.mem.zeroes(RECT);
        _ = GetClientRect(app_state.g_main_hwnd, &win_rc);
        const win_w = win_rc.right - win_rc.left;
        const win_h = win_rc.bottom - win_rc.top;

        const overlay_w: i32 = 560;
        const title_h: i32 = 46;
        const row_h: i32 = uiScaled(26);
        const bottom_pad: i32 = 12;
        const eta_acc_lines = &app_state.g_eta_acc_lines;
        const eta_acc_lens = &app_state.g_eta_acc_lens;
        const eta_acc_count = app_state.g_eta_acc_count;
        const total_rows: i32 = if (app_state.g_eta_accuracy_active) @intCast(@max(eta_acc_count, 1)) else @intCast(SHORTCUT_ROWS.len);

        var max_rows: i32 = @divFloor(win_h - 80 - title_h - bottom_pad, row_h);
        if (max_rows < 4) max_rows = 4;
        const visible_rows: i32 = @min(total_rows, max_rows);
        const max_scroll: i32 = total_rows - visible_rows;
        if (app_state.g_shortcuts_scroll < 0) app_state.g_shortcuts_scroll = 0;
        if (app_state.g_shortcuts_scroll > max_scroll) app_state.g_shortcuts_scroll = max_scroll;

        const overlay_h: i32 = title_h + visible_rows * row_h + bottom_pad;
        const ox = @divFloor(win_w - overlay_w, 2);
        const oy = @divFloor(win_h - overlay_h, 2);
        const overlay_radius: i32 = 14;

        drawModalShadow(hdc, ox, oy, overlay_w, overlay_h, overlay_radius);

        const sc_border_col = customColorOr("overlay_border", if (app_state.g_light_theme) RGB(200, 200, 200) else if (app_state.g_edge_gray_theme) RGB(86, 86, 86) else if (app_state.g_mid_theme) RGB(110, 110, 110) else RGB(80, 80, 80));
        const sc_border_br = CreateSolidBrush(sc_border_col);
        const sc_border_pen = CreatePen(0, 1, sc_border_col);
        const sc_ob_b = SelectObject(hdc, sc_border_br);
        const sc_op_b = SelectObject(hdc, sc_border_pen);
        _ = @import("smooth.zig").drawRoundRect(hdc, ox - 1, oy - 1, ox + overlay_w + 1, oy + overlay_h + 1, overlay_radius, overlay_radius);
        _ = SelectObject(hdc, sc_ob_b);
        _ = SelectObject(hdc, sc_op_b);
        _ = DeleteObject(sc_border_br);
        _ = DeleteObject(sc_border_pen);

        const sc_bg_col = customColorOr("overlay_bg", if (app_state.g_light_theme) RGB(249, 249, 249) else if (app_state.g_edge_gray_theme) RGB(51, 51, 51) else if (app_state.g_mid_theme) RGB(68, 68, 68) else RGB(40, 40, 40));
        const sc_bg_br = CreateSolidBrush(sc_bg_col);
        const sc_bg_pen = CreatePen(0, 1, sc_bg_col);
        const sc_ob_i = SelectObject(hdc, sc_bg_br);
        const sc_op_i = SelectObject(hdc, sc_bg_pen);
        _ = @import("smooth.zig").drawRoundRect(hdc, ox, oy, ox + overlay_w, oy + overlay_h, overlay_radius, overlay_radius);
        _ = SelectObject(hdc, sc_ob_i);
        _ = SelectObject(hdc, sc_op_i);
        _ = DeleteObject(sc_bg_br);
        _ = DeleteObject(sc_bg_pen);

        _ = SetBkMode(hdc, TRANSPARENT);

        _ = SelectObject(hdc, font_title);
        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(245, 245, 245));
        var sc_title_rc = RECT{ .left = ox + 18, .top = oy + 8, .right = ox + overlay_w - 120, .bottom = oy + title_h - 6 };
        drawAscii(hdc, if (app_state.g_eta_accuracy_active) "Estimate Accuracy" else "Keyboard Shortcuts", &sc_title_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
        _ = SelectObject(hdc, font_subtitle);
        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(120, 120, 120) else RGB(140, 140, 150));
        var sc_esc_rc = RECT{ .left = ox + overlay_w - 120, .top = oy + 8, .right = ox + overlay_w - 16, .bottom = oy + title_h - 6 };
        drawAscii(hdc, "Esc to close", &sc_esc_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);

        var sc_div_rc = RECT{ .left = ox + 1, .top = oy + title_h - 1, .right = ox + overlay_w - 1, .bottom = oy + title_h };
        const sc_div_br = CreateSolidBrush(if (app_state.g_light_theme) RGB(228, 228, 228) else RGB(60, 60, 60));
        _ = FillRect(hdc, &sc_div_rc, sc_div_br);
        _ = DeleteObject(sc_div_br);

        const sc_accent = customColorOr("accent", RGB(79, 168, 255));
        var vi: i32 = 0;
        while (vi < visible_rows) : (vi += 1) {
            const idx: usize = @intCast(app_state.g_shortcuts_scroll + vi);
            const ry = oy + title_h + vi * row_h;
            if (app_state.g_eta_accuracy_active) {
                if (idx >= eta_acc_count) {
                    if (idx == 0) {
                        _ = SelectObject(hdc, font_subtitle);
                        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(110, 110, 110) else RGB(150, 150, 155));
                        var empty_rc = RECT{ .left = ox + 26, .top = ry, .right = ox + overlay_w - 16, .bottom = ry + row_h };
                        drawAscii(hdc, "No estimates yet", &empty_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                    }
                    break;
                }
                _ = SelectObject(hdc, font_subtitle);
                _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(40, 40, 40) else RGB(225, 225, 225));
                var acc_rc = RECT{ .left = ox + 26, .top = ry, .right = ox + overlay_w - 16, .bottom = ry + row_h };
                drawAscii(hdc, eta_acc_lines[idx][0..eta_acc_lens[idx]], &acc_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                continue;
            }
            if (idx >= SHORTCUT_ROWS.len) break;
            const row = SHORTCUT_ROWS[idx];
            if (row.header) {
                _ = SelectObject(hdc, font_subtitle);
                _ = SetTextColor(hdc, sc_accent);
                var hdr_rc = RECT{ .left = ox + 16, .top = ry, .right = ox + overlay_w - 16, .bottom = ry + row_h };
                drawAscii(hdc, row.a, &hdr_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
            } else {
                _ = SelectObject(hdc, font_subtitle);
                _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(40, 40, 40) else RGB(225, 225, 225));
                var keys_rc = RECT{ .left = ox + 26, .top = ry, .right = ox + 252, .bottom = ry + row_h };
                drawAscii(hdc, row.a, &keys_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(110, 110, 110) else RGB(150, 150, 155));
                var desc_rc = RECT{ .left = ox + 262, .top = ry, .right = ox + overlay_w - 16, .bottom = ry + row_h };
                drawAscii(hdc, row.b, &desc_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
            }
        }

        if (total_rows > visible_rows) {
            const track_top = oy + title_h + 4;
            const track_bottom = oy + overlay_h - 6;
            const track_h = track_bottom - track_top;
            if (track_h > 0) {
                const thumb_h = @max(24, @divTrunc(track_h * visible_rows, total_rows));
                const scroll_space = track_h - thumb_h;
                const thumb_top = track_top + if (max_scroll == 0) 0 else @divTrunc(scroll_space * app_state.g_shortcuts_scroll, max_scroll);
                var thumb_rc = RECT{ .left = ox + overlay_w - 7, .top = thumb_top, .right = ox + overlay_w - 3, .bottom = thumb_top + thumb_h };
                const thumb_br = CreateSolidBrush(customColorOr("scrollbar_thumb", RGB(145, 145, 145)));
                _ = FillRect(hdc, &thumb_rc, thumb_br);
                _ = DeleteObject(thumb_br);
            }
        }
    }

    paintChangelogOverlay(hdc);

    if (app_state.g_url_picker_active and app_state.g_url_picker_count > 0) {
        var win_rc: RECT = std.mem.zeroes(RECT);
        _ = GetClientRect(app_state.g_main_hwnd, &win_rc);
        const win_w = win_rc.right - win_rc.left;
        const win_h = win_rc.bottom - win_rc.top;

        const overlay_w: i32 = 640;
        const WRAP_THRESHOLD: u32 = 58;
        const row_h_single: i32 = 36;
        const row_h_double: i32 = 56;
        const header_h: i32 = 36;
        const MAX_VISIBLE: u32 = 7;
        const visible_count: u32 = @min(app_state.g_url_picker_count, MAX_VISIBLE);
        var scroll: u32 = 0;
        if (app_state.g_url_picker_sel >= MAX_VISIBLE) scroll = app_state.g_url_picker_sel - MAX_VISIBLE + 1;
        var rows_total_h: i32 = 0;
        for (0..visible_count) |vi| {
            const abs_idx: u32 = scroll + @as(u32, @intCast(vi));
            if (abs_idx >= app_state.g_url_picker_count) break;
            const len = app_state.g_url_picker_lengths[abs_idx];
            rows_total_h += if (len > WRAP_THRESHOLD) row_h_double else row_h_single;
        }
        const overlay_h: i32 = header_h + rows_total_h + 6;
        const ox = @divFloor(win_w - overlay_w, 2);
        const oy = @divFloor(win_h - overlay_h, 3);
        const radius: i32 = 14;

        drawModalShadow(hdc, ox, oy, overlay_w, overlay_h, radius);

        const border_br = CreateSolidBrush(if (app_state.g_light_theme) RGB(200, 200, 200) else if (app_state.g_edge_gray_theme) RGB(86, 86, 86) else if (app_state.g_mid_theme) RGB(110, 110, 110) else RGB(80, 80, 80));
        const border_pen = CreatePen(0, 1, if (app_state.g_light_theme) RGB(200, 200, 200) else if (app_state.g_edge_gray_theme) RGB(86, 86, 86) else if (app_state.g_mid_theme) RGB(110, 110, 110) else RGB(80, 80, 80));
        const old_brush_b = SelectObject(hdc, border_br);
        const old_pen_b = SelectObject(hdc, border_pen);
        _ = @import("smooth.zig").drawRoundRect(hdc, ox - 1, oy - 1, ox + overlay_w + 1, oy + overlay_h + 1, radius, radius);
        _ = SelectObject(hdc, old_brush_b);
        _ = SelectObject(hdc, old_pen_b);
        _ = DeleteObject(border_br);
        _ = DeleteObject(border_pen);

        const bg_col: DWORD = if (app_state.g_light_theme) RGB(249, 249, 249) else if (app_state.g_edge_gray_theme) RGB(51, 51, 51) else if (app_state.g_mid_theme) RGB(68, 68, 68) else RGB(40, 40, 40);
        const bg_br = CreateSolidBrush(bg_col);
        const bg_pen = CreatePen(0, 1, bg_col);
        const old_brush_i = SelectObject(hdc, bg_br);
        const old_pen_i = SelectObject(hdc, bg_pen);
        _ = @import("smooth.zig").drawRoundRect(hdc, ox, oy, ox + overlay_w, oy + overlay_h, radius, radius);
        _ = SelectObject(hdc, old_brush_i);
        _ = SelectObject(hdc, old_pen_i);
        _ = DeleteObject(bg_br);
        _ = DeleteObject(bg_pen);

        _ = SelectObject(hdc, font_title);
        _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(60, 60, 60) else RGB(180, 180, 180));
        var hdr_rc = RECT{ .left = ox + 14, .top = oy + 4, .right = ox + overlay_w - 14, .bottom = oy + header_h - 4 };
        const hdr_label = if (app_state.g_url_picker_count == 1) L("Open URL") else L("Open URL (↑/↓, Enter)");
        _ = DrawTextW(hdc, hdr_label, -1, &hdr_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);

        var div_rc = RECT{ .left = ox, .top = oy + header_h - 1, .right = ox + overlay_w, .bottom = oy + header_h };
        const div_br = CreateSolidBrush(if (app_state.g_light_theme) RGB(220, 220, 220) else if (app_state.g_edge_gray_theme) RGB(72, 72, 72) else if (app_state.g_mid_theme) RGB(85, 85, 85) else RGB(60, 60, 60));
        _ = FillRect(hdc, &div_rc, div_br);
        _ = DeleteObject(div_br);

        _ = SelectObject(hdc, font_title);
        var ry: i32 = oy + header_h;
        for (0..visible_count) |vi| {
            const abs_idx: u32 = scroll + @as(u32, @intCast(vi));
            if (abs_idx >= app_state.g_url_picker_count) break;
            const off = app_state.g_url_picker_offsets[abs_idx];
            const len = app_state.g_url_picker_lengths[abs_idx];
            const row_h = if (len > WRAP_THRESHOLD) row_h_double else row_h_single;

            if (abs_idx == app_state.g_url_picker_sel) {
                var sel_rc = RECT{ .left = ox + 1, .top = ry, .right = ox + overlay_w - 1, .bottom = ry + row_h };
                const sel_br = CreateSolidBrush(RGB(0, 122, 204));
                _ = FillRect(hdc, &sel_rc, sel_br);
                _ = DeleteObject(sel_br);
            }
            _ = SetTextColor(hdc, if (abs_idx == app_state.g_url_picker_sel) RGB(255, 255, 255) else if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(220, 220, 220));

            var draw_buf: [2100]u16 = undefined;
            var draw_len: usize = 0;
            if (len > WRAP_THRESHOLD) {
                var cut: usize = WRAP_THRESHOLD;
                var k: usize = WRAP_THRESHOLD;
                while (k > @min(len, @as(usize, 20))) : (k -= 1) {
                    const c = app_state.g_url_picker_storage[off + k];
                    if (c == '/' or c == '?' or c == '&' or c == '=' or c == '-' or c == '.') {
                        cut = k + 1;
                        break;
                    }
                }
                if (cut > len) cut = len;
                for (0..cut) |i| {
                    draw_buf[draw_len] = app_state.g_url_picker_storage[off + i];
                    draw_len += 1;
                }
                draw_buf[draw_len] = '\n';
                draw_len += 1;
                for (cut..len) |i| {
                    draw_buf[draw_len] = app_state.g_url_picker_storage[off + i];
                    draw_len += 1;
                }
            } else {
                for (0..len) |i| {
                    draw_buf[draw_len] = app_state.g_url_picker_storage[off + i];
                    draw_len += 1;
                }
            }

            var url_rc = RECT{ .left = ox + 16, .top = ry + 4, .right = ox + overlay_w - 16, .bottom = ry + row_h - 4 };
            const flags: u32 = if (len > WRAP_THRESHOLD)
                (DT_NOPREFIX | DT_END_ELLIPSIS)
            else
                (DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
            _ = DrawTextW(hdc, @ptrCast(&draw_buf), @intCast(draw_len), &url_rc, flags);

            ry += row_h;
        }

        if (devThemeOn() and app_state.g_url_picker_count > MAX_VISIBLE) {
            const track_top = oy + header_h + 5;
            const track_bottom = oy + overlay_h - 8;
            const track_h = track_bottom - track_top;
            if (track_h > 0) {
                var track_rc = RECT{ .left = ox + overlay_w - 7, .top = track_top, .right = ox + overlay_w - 4, .bottom = track_bottom };
                const track_br = CreateSolidBrush(customColorOr("scrollbar_track", if (app_state.g_light_theme) RGB(218, 218, 218) else if (app_state.g_edge_gray_theme) RGB(72, 72, 72) else if (app_state.g_mid_theme) RGB(92, 92, 92) else RGB(66, 66, 66)));
                _ = FillRect(hdc, &track_rc, track_br);
                _ = DeleteObject(track_br);

                const thumb_ratio_h: i32 = @divTrunc(track_h * @as(i32, @intCast(visible_count)), @as(i32, @intCast(app_state.g_url_picker_count)));
                const thumb_h: i32 = @min(track_h, @max(24, thumb_ratio_h));
                const max_scroll = app_state.g_url_picker_count - visible_count;
                const scroll_space = track_h - thumb_h;
                const thumb_top = track_top + if (max_scroll == 0) 0 else @divTrunc(scroll_space * @as(i32, @intCast(scroll)), @as(i32, @intCast(max_scroll)));
                var thumb_rc = RECT{ .left = ox + overlay_w - 8, .top = thumb_top, .right = ox + overlay_w - 3, .bottom = thumb_top + thumb_h };
                const thumb_br = CreateSolidBrush(customColorOr("scrollbar_thumb", if (app_state.g_light_theme) RGB(145, 145, 145) else if (app_state.g_edge_gray_theme) RGB(150, 150, 150) else if (app_state.g_mid_theme) RGB(160, 160, 160) else RGB(145, 145, 145)));
                _ = FillRect(hdc, &thumb_rc, thumb_br);
                _ = DeleteObject(thumb_br);
            }
        }
    }

    if (app_state.g_snippet_create_active) {
        paintSnippetCreateForm(hdc);
    }

    _ = SelectObject(hdc, old_font);
}

test "IGSH-457 Starred sidebar shows every starred session live without moving sessions" {
    const saved_starred = app_state.g_starred_workspace;
    const saved_single = app_state.g_single_window;
    const saved_count = app_state.shell_count;
    const saved_inbox_count = app_state.g_inbox_row_count;
    defer app_state.g_inbox_row_count = saved_inbox_count;
    app_state.g_inbox_row_count = 0;
    const saved_active = app_state.active_shell;
    const saved_workspace = app_state.g_active_workspace;
    const saved_snoozed = app_state.g_ws_snoozed;
    const saved_shells = app_state.shells[0..4].*;
    defer {
        app_state.g_starred_workspace = saved_starred;
        app_state.g_single_window = saved_single;
        app_state.shell_count = saved_count;
        app_state.active_shell = saved_active;
        app_state.g_active_workspace = saved_workspace;
        app_state.g_ws_snoozed = saved_snoozed;
        app_state.shells[0..4].* = saved_shells;
    }
    app_state.g_starred_workspace = true;
    app_state.g_single_window = true;
    app_state.g_active_workspace = 0;
    app_state.g_ws_snoozed = [_]bool{false} ** MAX_LWS;
    app_state.shell_count = 4;
    app_state.active_shell = 0;
    for (0..4) |i| {
        app_state.shells[i] = app_state.empty_shell;
        app_state.shells[i].workspace = @intCast(i % 2);
        app_state.shells[i].tmux_host = @intCast(i % 2);
        app_state.shells[i].favorite = i != 2;
    }
    app_state.shells[3].inbox_excluded = true;
    for ([_]bool{ true, false, true }) |favorite| {
        app_state.shells[0].favorite = favorite;
        app_state.shells[1].favorite = favorite;
        var rows: [MAX_ROWS]Row = undefined;
        const count = layoutRows(&rows);
        try std.testing.expectEqual(@as(u32, if (favorite) 3 else 1), count);
        var expected: u32 = 0;
        for (0..4) |i| {
            const shell = app_state.shells[i];
            const in_favorites = @import("workspace_view.zig").splitMatches(frequent.favorites_split, shell.workspace, shell.favorite);
            try std.testing.expectEqual(!in_favorites, isTabHidden(@intCast(i)));
            try std.testing.expectEqual(@as(u8, @intCast(i % 2)), shell.workspace);
            if (!in_favorites) continue;
            try std.testing.expectEqual(@as(u32, @intCast(i)), rows[expected].shell_idx);
            expected += 1;
        }
        try std.testing.expectEqual(count, expected);
    }
    app_state.shells[0].inbox_archived = true;
    var rows: [MAX_ROWS]Row = undefined;
    try std.testing.expectEqual(@as(u32, 2), layoutRows(&rows));
    app_state.shells[0].needs_attention = true;
    try std.testing.expectEqual(@as(u32, 3), layoutRows(&rows));
    app_state.g_ws_snoozed[1] = true;
    try std.testing.expectEqual(@as(u32, 1), layoutRows(&rows));
}

test "IGSH-719 a muted or Inbox-excluded starred session stays in Favorites in its group" {
    const saved_shells = app_state.shells[0..4].*;
    const saved_count = app_state.shell_count;
    const saved_groups = app_state.groups;
    const saved_group_count = app_state.group_count;
    const saved_next = app_state.next_group_id;
    const saved_starred = app_state.g_starred_workspace;
    const saved_single = app_state.g_single_window;
    const saved_workspace = app_state.g_active_workspace;
    const saved_active = app_state.active_shell;
    const saved_inbox_count = app_state.g_inbox_row_count;
    const saved_snoozed = app_state.g_ws_snoozed;
    defer {
        app_state.shells[0..4].* = saved_shells;
        app_state.shell_count = saved_count;
        app_state.groups = saved_groups;
        app_state.group_count = saved_group_count;
        app_state.next_group_id = saved_next;
        app_state.g_starred_workspace = saved_starred;
        app_state.g_single_window = saved_single;
        app_state.g_active_workspace = saved_workspace;
        app_state.active_shell = saved_active;
        app_state.g_inbox_row_count = saved_inbox_count;
        app_state.g_ws_snoozed = saved_snoozed;
    }
    app_state.shell_count = 4;
    app_state.group_count = 0;
    app_state.next_group_id = 1;
    app_state.g_single_window = true;
    app_state.g_active_workspace = 0;
    app_state.active_shell = 0;
    app_state.g_inbox_row_count = 0;
    app_state.g_ws_snoozed = @splat(false);
    app_state.g_starred_workspace = true;
    const hypertask = createDefaultGroup();
    for (0..4) |i| {
        app_state.shells[i] = app_state.empty_shell;
        app_state.shells[i].shell_id = @intCast(i + 1);
        app_state.shells[i].favorite = true;
        app_state.shells[i].starred_group_id = hypertask;
    }
    app_state.shells[1].muted = true;
    app_state.shells[2].inbox_excluded = true;
    app_state.shells[3].inbox_archived = true;
    var rows: [MAX_ROWS]Row = undefined;
    try std.testing.expectEqual(@as(u32, 4), layoutRows(&rows));
    try std.testing.expectEqual(.header, rows[0].kind);
    try std.testing.expectEqual(hypertask, app_state.groups[rows[0].gidx].id);
    for (0..3) |i| {
        try std.testing.expectEqual(.tab, rows[i + 1].kind);
        try std.testing.expectEqual(@as(u32, @intCast(i)), rows[i + 1].shell_idx);
        try std.testing.expect(!isTabHidden(@intCast(i)));
    }
    try std.testing.expect(isTabHidden(3));
    app_state.shells[3].needs_attention = true;
    try std.testing.expectEqual(@as(u32, 5), layoutRows(&rows));
}

test "IGSH-556 Favorites and home grouping keep independent memberships and group rows" {
    const saved_shells = app_state.shells[0..2].*;
    const saved_count = app_state.shell_count;
    const saved_groups = app_state.groups;
    const saved_group_count = app_state.group_count;
    const saved_next = app_state.next_group_id;
    const saved_starred = app_state.g_starred_workspace;
    const saved_single = app_state.g_single_window;
    const saved_workspace = app_state.g_active_workspace;
    const saved_active = app_state.active_shell;
    const saved_inbox_count = app_state.g_inbox_row_count;
    const saved_snoozed = app_state.g_ws_snoozed;
    defer {
        app_state.shells[0..2].* = saved_shells;
        app_state.shell_count = saved_count;
        app_state.groups = saved_groups;
        app_state.group_count = saved_group_count;
        app_state.next_group_id = saved_next;
        app_state.g_starred_workspace = saved_starred;
        app_state.g_single_window = saved_single;
        app_state.g_active_workspace = saved_workspace;
        app_state.active_shell = saved_active;
        app_state.g_inbox_row_count = saved_inbox_count;
        app_state.g_ws_snoozed = saved_snoozed;
    }
    app_state.shell_count = 2;
    app_state.group_count = 0;
    app_state.next_group_id = 1;
    app_state.g_single_window = true;
    app_state.g_active_workspace = 0;
    app_state.active_shell = 0;
    app_state.g_inbox_row_count = 0;
    app_state.g_ws_snoozed = @splat(false);
    for (0..2) |i| {
        app_state.shells[i] = app_state.empty_shell;
        app_state.shells[i].shell_id = @intCast(i + 1);
        app_state.shells[i].favorite = true;
    }
    const home = createDefaultGroup();
    app_state.shells[0].group_id = home;
    app_state.g_starred_workspace = true;
    const starred = createDefaultGroup();
    try std.testing.expect(assignTabOrSelectionToGroup(1, starred));
    try std.testing.expectEqual(home, app_state.shells[0].group_id);
    try std.testing.expectEqual(starred, app_state.shells[0].starred_group_id);
    try std.testing.expect(!groupInCurrentWorkspace(home));
    try std.testing.expect(groupInCurrentWorkspace(starred));
    var rows: [MAX_ROWS]Row = undefined;
    try std.testing.expectEqual(@as(u32, 3), layoutRows(&rows));
    try std.testing.expectEqual(.header, rows[0].kind);
    try std.testing.expectEqual(starred, app_state.groups[rows[0].gidx].id);
    try std.testing.expectEqual(.tab, rows[1].kind);
    try std.testing.expectEqual(@as(u32, 0), rows[1].shell_idx);
    app_state.groups[findGroupIdx(starred).?].collapsed = true;
    try std.testing.expectEqual(@as(u32, 2), layoutRows(&rows));
    try std.testing.expect(isTabHidden(0));
    app_state.g_starred_workspace = false;
    try std.testing.expect(!groupInCurrentWorkspace(starred));
    try std.testing.expect(groupInCurrentWorkspace(home));
    const other_home = createDefaultGroup();
    try std.testing.expect(assignTabOrSelectionToGroup(1, other_home));
    try std.testing.expectEqual(other_home, app_state.shells[0].group_id);
    try std.testing.expectEqual(starred, app_state.shells[0].starred_group_id);
    try std.testing.expect(findGroupIdx(starred) != null);
    app_state.g_starred_workspace = true;
    try std.testing.expectEqual(@as(?u32, 1), moveShellToIndexWithGroup(1, 1, starred));
    try std.testing.expectEqual(@as(u32, 0), app_state.shells[1].group_id);
    try std.testing.expectEqual(starred, app_state.shells[1].starred_group_id);
    try std.testing.expect(removeTabOrSelectionFromGroup(1));
    try std.testing.expectEqual(other_home, app_state.shells[0].group_id);
    try std.testing.expectEqual(@as(u32, 0), app_state.shells[0].starred_group_id);
}
