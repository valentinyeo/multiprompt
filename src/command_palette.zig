const app_state = @import("app_state.zig");
const std = @import("std");
const json_reader = @import("json_reader.zig");
const IS_DEV = @import("main.zig").IS_DEV;
const SYSTEMTIME = @import("win32.zig").SYSTEMTIME;
const WIN32_FIND_DATAW = @import("win32.zig").WIN32_FIND_DATAW;
const CloseHandle = @import("win32.zig").CloseHandle;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const FindFirstFileW = @import("win32.zig").FindFirstFileW;
const FindClose = @import("win32.zig").FindClose;
const INVALID_HANDLE_VALUE_PTR = @import("win32.zig").INVALID_HANDLE_VALUE_PTR;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const GetLocalTime = @import("win32.zig").GetLocalTime;
const ShellExecuteW = @import("win32.zig").ShellExecuteW;
const L = @import("startup.zig").L;
const ShellKind = @import("app_state.zig").ShellKind;
const isRemoteShellKind = @import("console.zig").isRemoteShellKind;
const MAX_SHELLS = @import("app_state.zig").MAX_SHELLS;
const RECENT_SESSION_ROWS = @import("app_state.zig").RECENT_SESSION_ROWS;
const NUM_BUTTONS = @import("app_state.zig").NUM_BUTTONS;
const MAX_LWS = @import("app_state.zig").MAX_LWS;
const MAX_GROUPS = @import("app_state.zig").MAX_GROUPS;
const selectedTabCount = @import("sidebar.zig").selectedTabCount;
const selectedTabsIncludeGrouped = @import("sidebar.zig").selectedTabsIncludeGrouped;
const capacityAdmitNewAgent = @import("capacity.zig").capacityAdmitNewAgent;
const commandCreatesAgentWorkload = @import("capacity.zig").commandCreatesAgentWorkload;
const SEARCH_VISIBLE_ROWS = @import("app_state.zig").SEARCH_VISIBLE_ROWS;
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
const SEARCH_CHAT_VIEW_MODE_PER_SESSION_OFFSET = @import("app_state.zig").SEARCH_CHAT_VIEW_MODE_PER_SESSION_OFFSET;
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
const SEARCH_CHAT_TODO_OFFSET = @import("app_state.zig").SEARCH_CHAT_TODO_OFFSET;
const SEARCH_CHAT_TOOL_STEPS_OFFSET = @import("app_state.zig").SEARCH_CHAT_TOOL_STEPS_OFFSET;
const SEARCH_CHAT_FIND_OFFSET = @import("app_state.zig").SEARCH_CHAT_FIND_OFFSET;
const SEARCH_CHAT_COPY_CODE_OFFSET = @import("app_state.zig").SEARCH_CHAT_COPY_CODE_OFFSET;
const SEARCH_CHAT_COPY_SELECTION_OFFSET = @import("app_state.zig").SEARCH_CHAT_COPY_SELECTION_OFFSET;
const SEARCH_CHAT_SELECT_ALL_OFFSET = @import("app_state.zig").SEARCH_CHAT_SELECT_ALL_OFFSET;
const SEARCH_CHAT_AC_OFFSET = @import("app_state.zig").SEARCH_CHAT_AC_OFFSET;
const SEARCH_CHAT_QUEUE_SEND_OFFSET = @import("app_state.zig").SEARCH_CHAT_QUEUE_SEND_OFFSET;
const SEARCH_CHAT_RESET_OFFSET = @import("app_state.zig").SEARCH_CHAT_RESET_OFFSET;
const SEARCH_CHAT_TAB_URL_OFFSET = @import("app_state.zig").SEARCH_CHAT_TAB_URL_OFFSET;
const SEARCH_CHAT_QUEUE_CLEAR_OFFSET = @import("app_state.zig").SEARCH_CHAT_QUEUE_CLEAR_OFFSET;
const SEARCH_CHAT_RETRY_UNSENT_OFFSET = @import("app_state.zig").SEARCH_CHAT_RETRY_UNSENT_OFFSET;
const SEARCH_CHAT_DISCARD_UNSENT_OFFSET = @import("app_state.zig").SEARCH_CHAT_DISCARD_UNSENT_OFFSET;
const SEARCH_CHAT_PUSH_QUEUED_OFFSET = @import("app_state.zig").SEARCH_CHAT_PUSH_QUEUED_OFFSET;
const SEARCH_VOICE_REPLAY_OFFSET = @import("app_state.zig").SEARCH_VOICE_REPLAY_OFFSET;
const REMIND_PRESET_EVENING = @import("app_state.zig").REMIND_PRESET_EVENING;
const REMIND_PRESET_COUNT = @import("app_state.zig").REMIND_PRESET_COUNT;
const SEARCH_CODEX_TMUX_OFFSET = @import("app_state.zig").SEARCH_CODEX_TMUX_OFFSET;
const SEARCH_SNIPPETS_MENU_OFFSET = @import("app_state.zig").SEARCH_SNIPPETS_MENU_OFFSET;
const SEARCH_SNIPPET_CREATE_OFFSET = @import("app_state.zig").SEARCH_SNIPPET_CREATE_OFFSET;
const SEARCH_SNIPPET_BACK_OFFSET = @import("app_state.zig").SEARCH_SNIPPET_BACK_OFFSET;
const SEARCH_SNIPPET_OFFSET = @import("app_state.zig").SEARCH_SNIPPET_OFFSET;
const SEARCH_SESSION_OVERVIEW_MENU_OFFSET = @import("app_state.zig").SEARCH_SESSION_OVERVIEW_MENU_OFFSET;
const SEARCH_ARCHIVED_VIEW_OFFSET = @import("app_state.zig").SEARCH_ARCHIVED_VIEW_OFFSET;
const SEARCH_BROWSER_SHOTURL_OFFSET = @import("app_state.zig").SEARCH_BROWSER_SHOTURL_OFFSET;
const SEARCH_PIN_TOP_OFFSET = @import("app_state.zig").SEARCH_PIN_TOP_OFFSET;
const SEARCH_UNARCHIVE_HIDDEN_OFFSET = @import("app_state.zig").SEARCH_UNARCHIVE_HIDDEN_OFFSET;
const SEARCH_UNARCHIVE_UNATTACHED_OFFSET = @import("app_state.zig").SEARCH_UNARCHIVE_UNATTACHED_OFFSET;
const SEARCH_LOCK_SESSION_OFFSET = @import("app_state.zig").SEARCH_LOCK_SESSION_OFFSET;
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
const SEARCH_TABCTX_LOCK = @import("app_state.zig").SEARCH_TABCTX_LOCK;
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
const MAX_CUSTOM_CMDS = @import("app_state.zig").MAX_CUSTOM_CMDS;
const CustomCmd = @import("app_state.zig").CustomCmd;
const MAX_PALETTE_USAGE = @import("app_state.zig").MAX_PALETTE_USAGE;
const PaletteUsage = @import("app_state.zig").PaletteUsage;
const MAX_SNIPPETS = @import("app_state.zig").MAX_SNIPPETS;
const MAX_WORKSPACES = @import("app_state.zig").MAX_WORKSPACES;
const WorkspaceEntry = @import("app_state.zig").WorkspaceEntry;
const setShellName = @import("shell_poll.zig").setShellName;
const win32WidePath = @import("file_io.zig").win32WidePath;
const win32OpenRead = @import("file_io.zig").win32OpenRead;
const win32OpenWrite = @import("file_io.zig").win32OpenWrite;
const win32WriteAll = @import("file_io.zig").win32WriteAll;
const win32ReadAll = @import("file_io.zig").win32ReadAll;
const mergeWorkspaceRegistryFromDisk = @import("workspaces.zig").mergeWorkspaceRegistryFromDisk;
const workspaceCanDelete = @import("workspaces.zig").workspaceCanDelete;
const scanLiveWorkspaceWindows = @import("workspaces.zig").scanLiveWorkspaceWindows;
const findMyWorkspaceSlot = @import("workspaces.zig").findMyWorkspaceSlot;
const workspaceCanMoveIntoClosedStandalone = @import("workspaces.zig").workspaceCanMoveIntoClosedStandalone;
const hasClosedWorkspaceMoveDestinations = @import("workspaces.zig").hasClosedWorkspaceMoveDestinations;
const debugLog2 = @import("diagnostics.zig").debugLog2;
const saveSession = @import("session.zig").saveSession;
const TMUX_HOST_UK = @import("app_state.zig").TMUX_HOST_UK;
const TMUX_HOST_INNE = @import("app_state.zig").TMUX_HOST_INNE;
const appendAsciiBuf = @import("archive.zig").appendAsciiBuf;
const loadArchiveIfNeeded = @import("archive.zig").loadArchiveIfNeeded;
const loadSnippetsIfChanged = @import("snippets.zig").loadSnippetsIfChanged;
const snippetMatchesQuery = @import("snippets.zig").snippetMatchesQuery;
const MAX_REMINDERS = @import("app_state.zig").MAX_REMINDERS;
const loadRemindersIfNeeded = @import("reminders.zig").loadRemindersIfNeeded;
const snoozedWorkspaceIndex = @import("reminders.zig").snoozedWorkspaceIndex;
const ensureSnoozeMarkers = @import("reminders.zig").ensureSnoozeMarkers;
const remindPresetLabel = @import("reminders.zig").remindPresetLabel;
const reminderMatchesSearch = @import("reminders.zig").reminderMatchesSearch;
const spawnShellWithSession = @import("console.zig").spawnShellWithSession;
const faviconHostForShell = @import("vps.zig").faviconHostForShell;
const tmuxCacheEntryAlreadyOpen = @import("vps.zig").tmuxCacheEntryAlreadyOpen;
const buildFilteredTmux = @import("vps.zig").buildFilteredTmux;
const focusedSessionFolder = @import("vps.zig").focusedSessionFolder;
const workspacePrimaryRepo = @import("vps.zig").workspacePrimaryRepo;
const countFolderSessions = @import("vps.zig").countFolderSessions;
const sessionOverviewRowMatches = @import("archive.zig").sessionOverviewRowMatches;
const buildSessionOverviewRows = @import("archive.zig").buildSessionOverviewRows;
const workspaceDisplayName = @import("workspaces.zig").workspaceDisplayName;
const browserPaneActive = @import("browser_pane.zig").browserPaneActive;
const activeShellHasShotUrlPane = @import("browser_pane.zig").activeShellHasShotUrlPane;
const SEARCH_CHAT_ATTACH_OFFSET = @import("app_state.zig").SEARCH_CHAT_ATTACH_OFFSET;
const chatOutboxCountForShell = @import("chat_send.zig").chatOutboxCountForShell;
const chatEchoCountNotSentForShell = @import("chat_send.zig").chatEchoCountNotSentForShell;
const chatEchoCountDeliveredForShell = @import("chat_send.zig").chatEchoCountDeliveredForShell;
const hasMultipromptLogin = @import("account_desktop.zig").hasMultipromptLogin;
const nowFileTime = @import("inbox.zig").nowFileTime;
const publishInboxState = @import("inbox.zig").publishInboxState;
const findShellById = @import("inbox.zig").findShellById;

fn getCommandsJsonPath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 480) return null;
    const rest = "\\ZigShell\\commands.json";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

fn ensureCommandsJsonStarter() void {
    var path_buf: [512]u8 = undefined;
    const path = getCommandsJsonPath(&path_buf) orelse return;
    if (win32OpenRead(path)) |h| {
        _ = CloseHandle(h);
        return;
    }
    const starter =
        "{\n" ++
        "  \"_doc\": \"multiprompt custom spawn commands. Fields per entry: label = palette row text (required); kind = cmd|pwsh|vps|vps2 (vps = Remote host 1 ssh, vps2 = Remote host 2 ssh; default cmd); cmd = startup command (remote kinds run it as bash -ic '<cmd>'; quotes are NOT allowed in v1 — such entries are skipped); cwd = working directory; workspace = only show in the workspace with this name (empty/absent = all). For a workspace-scoped remote entry, default = true and cwd define Alt+T's host/folder; cmd stays palette-only. Optional alt_t = claude starts that program in the new tmux session after changing to cwd (allowed characters: letters, digits, space, dash, underscore, dot, slash, equals). Without alt_t the session stays a plain shell. Reloaded automatically when the file changes (checked on every Ctrl+K open) or via Ctrl+K 'Commands: Reload'.\",\n" ++
        "  \"commands\": [\n" ++
        "    { \"label\": \"Claude GitHub\", \"kind\": \"cmd\", \"cmd\": \"claude\", \"cwd\": \"C:\\\\Users\\\\user\\\\Documents\\\\GitHub\" }\n" ++
        "  ]\n" ++
        "}\n";
    const h = win32OpenWrite(path) orelse return;
    win32WriteAll(h, starter);
    _ = CloseHandle(h);
}

pub fn openCommandsJsonInEditor() void {
    ensureCommandsJsonStarter();
    var path_buf: [512]u8 = undefined;
    const path = getCommandsJsonPath(&path_buf) orelse return;
    var wpath_buf: [520]u16 = undefined;
    const wpath = win32WidePath(&wpath_buf, path) orelse return;
    const SHOW_NORMAL: i32 = 1;
    _ = ShellExecuteW(null, L("open"), L("notepad.exe"), wpath.ptr, null, SHOW_NORMAL);
}

fn customCmdHasQuote(s: []const u8) bool {
    for (s) |c| {
        if (c == '\'' or c == '"') return true;
    }
    return false;
}

fn altTProgramSafe(program: []const u8) bool {
    if (program.len == 0 or program.len >= 127) return false;
    for (program) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != ' ' and c != '-' and c != '_' and c != '.' and c != '/' and c != '=') return false;
    }
    return true;
}

test "Alt+T program accepts only shell-safe command characters" {
    try std.testing.expect(altTProgramSafe("claude --model opus-4.1"));
    try std.testing.expect(altTProgramSafe("env VAR=value claude"));
    for ([_][]const u8{ "", "claude; whoami", "claude\nexit", "claude'", "claude$(id)", "claude\\x", "claude|cat", "claude&whoami" }) |bad| {
        try std.testing.expect(!altTProgramSafe(bad));
    }
}

fn loadCustomCommands() void {
    app_state.g_custom_cmds_count = 0;
    var path_buf: [512]u8 = undefined;
    const path = getCommandsJsonPath(&path_buf) orelse return;
    const h = win32OpenRead(path) orelse return;
    var json_buf: [16384]u8 = undefined;
    const n = win32ReadAll(h, &json_buf);
    _ = CloseHandle(h);
    if (n == 0) return;
    var parsed = json_reader.parse(std.heap.page_allocator, json_buf[0..n]) catch return;
    defer parsed.deinit();
    for (json_reader.array(json_reader.field(parsed.value, "commands"))) |obj| {
        if (app_state.g_custom_cmds_count >= MAX_CUSTOM_CMDS) break;
        var c = CustomCmd{};
        c.label_len = json_reader.copyString(obj, "label", &c.label);
        if (c.label_len == 0) c.label_len = json_reader.copyString(obj, "name", &c.label);
        c.workspace_len = json_reader.copyString(obj, "workspace", &c.workspace);
        c.startup_cmd_len = json_reader.copyString(obj, "cmd", &c.startup_cmd);
        c.cwd_len = json_reader.copyString(obj, "cwd", &c.cwd);
        c.alt_t_len = json_reader.copyString(obj, "alt_t", &c.alt_t);
        var kind_buf: [16]u8 = std.mem.zeroes([16]u8);
        var kind_len = json_reader.copyString(obj, "kind", &kind_buf);
        if (kind_len == 0) kind_len = json_reader.copyString(obj, "host", &kind_buf);
        const ks = kind_buf[0..kind_len];
        c.kind = if (asciiEqualsCI(ks, "pwsh") or asciiEqualsCI(ks, "powershell")) .pwsh else if (asciiEqualsCI(ks, "vps") or asciiEqualsCI(ks, "de") or asciiEqualsCI(ks, "host1")) .vps else if (asciiEqualsCI(ks, "vps2") or asciiEqualsCI(ks, "uk") or asciiEqualsCI(ks, "host2")) .vps2 else .cmd;
        c.is_default = json_reader.boolTrue(obj, "default");
        if (c.alt_t_len > 0 and !altTProgramSafe(c.alt_t[0..c.alt_t_len])) {
            debugLog2("commands.json: entry rejected (unsafe alt_t): ", c.label[0..c.label_len]);
            continue;
        }
        if (c.label_len > 0 and !customCmdHasQuote(c.startup_cmd[0..c.startup_cmd_len])) {
            app_state.g_custom_cmds[app_state.g_custom_cmds_count] = c;
            app_state.g_custom_cmds_count += 1;
        } else if (c.label_len > 0) {
            debugLog2("commands.json: entry rejected (quote in cmd): ", c.label[0..c.label_len]);
        }
    }
}

pub fn loadCustomCommandsIfChanged() void {
    var path_buf: [512]u8 = undefined;
    const path = getCommandsJsonPath(&path_buf) orelse return;
    var wbuf: [520]u16 = undefined;
    const w = win32WidePath(&wbuf, path) orelse return;
    var data: WIN32_FIND_DATAW = undefined;
    const find = FindFirstFileW(w.ptr, &data);
    if (find == INVALID_HANDLE_VALUE_PTR) return;
    _ = FindClose(find);
    if (data.ftLastWriteTime.dwLowDateTime == app_state.g_custom_cmds_mtime_lo and
        data.ftLastWriteTime.dwHighDateTime == app_state.g_custom_cmds_mtime_hi) return;
    app_state.g_custom_cmds_mtime_lo = data.ftLastWriteTime.dwLowDateTime;
    app_state.g_custom_cmds_mtime_hi = data.ftLastWriteTime.dwHighDateTime;
    loadCustomCommands();
}

fn paletteUsagePath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 470) return null;
    const rest = "\\ZigShell\\palette-usage.tsv";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

fn paletteTargetTracksUsage(target: usize) bool {
    if (target >= SEARCH_NEW_OFFSET and target < SEARCH_NEW_OFFSET + NUM_BUTTONS) return true;
    if (target == SEARCH_SOUND_OFFSET or
        target == SEARCH_THEME_MENU_OFFSET or
        (target >= SEARCH_OPENALL_OFFSET and target <= SEARCH_RECOVER_REPO_OFFSET) or
        (target >= SEARCH_NEWWIN_OFFSET and target <= SEARCH_CREATEWS_OFFSET) or
        (target >= SEARCH_WORKSPACES_MENU_OFFSET and target <= SEARCH_SNIPPET_BACK_OFFSET) or
        (target >= SEARCH_SESSION_OVERVIEW_MENU_OFFSET and target <= SEARCH_USAGE_LOGIN_INNE_OFFSET) or
        target == SEARCH_RENAMEWIN_OFFSET or
        target == SEARCH_MOBILE_OFFSET or
        target == SEARCH_WS_SNOOZE_OFFSET or
        target == SEARCH_WS_SNOOZED_OFFSET or
        target == SEARCH_WS_BRINGBACK_OFFSET or
        target == SEARCH_ADDFAVICON_OFFSET)
    {
        return true;
    }
    return target >= SEARCH_CUSTOMCMD_OFFSET and target < SEARCH_CUSTOMCMD_OFFSET + MAX_CUSTOM_CMDS;
}

fn paletteUsageKey(target: usize) ?u64 {
    if (!paletteTargetTracksUsage(target)) return null;
    if (target < SEARCH_CUSTOMCMD_OFFSET or target >= SEARCH_CUSTOMCMD_OFFSET + MAX_CUSTOM_CMDS) {
        return @intCast(target);
    }
    const idx = target - SEARCH_CUSTOMCMD_OFFSET;
    if (idx >= app_state.g_custom_cmds_count) return null;
    const c = &app_state.g_custom_cmds[idx];
    var hash: u64 = 14695981039346656037;
    for ([_][]const u8{
        c.label[0..c.label_len],
        c.workspace[0..c.workspace_len],
        c.startup_cmd[0..c.startup_cmd_len],
        c.cwd[0..c.cwd_len],
    }) |part| {
        for (part) |ch| {
            hash = (hash ^ ch) *% 1099511628211;
        }
        hash = (hash ^ 0xFF) *% 1099511628211;
    }
    hash = (hash ^ @intFromEnum(c.kind)) *% 1099511628211;
    return hash | (@as(u64, 1) << 63);
}

pub fn loadPaletteUsage() void {
    app_state.g_palette_usage_count = 0;
    var path_buf: [512]u8 = undefined;
    const path = paletteUsagePath(&path_buf) orelse return;
    const h = win32OpenRead(path) orelse return;
    defer _ = CloseHandle(h);
    var file_buf: [16384]u8 = undefined;
    const n = win32ReadAll(h, &file_buf);
    var lines = std.mem.tokenizeAny(u8, file_buf[0..n], "\r\n");
    while (lines.next()) |line| {
        if (app_state.g_palette_usage_count >= MAX_PALETTE_USAGE) break;
        var fields = std.mem.splitScalar(u8, line, '\t');
        const key_text = fields.next() orelse continue;
        const count_text = fields.next() orelse continue;
        const last_text = fields.next() orelse continue;
        const key = std.fmt.parseInt(u64, key_text, 10) catch continue;
        if (key == 0) continue;
        const count = std.fmt.parseInt(u32, count_text, 10) catch continue;
        const last_used = std.fmt.parseInt(u64, last_text, 10) catch continue;
        app_state.g_palette_usage[app_state.g_palette_usage_count] = .{
            .key = key,
            .count = count,
            .last_used = last_used,
        };
        app_state.g_palette_usage_count += 1;
    }
}

fn savePaletteUsage() void {
    var path_buf: [512]u8 = undefined;
    const path = paletteUsagePath(&path_buf) orelse return;
    var out: [16384]u8 = undefined;
    var pos: usize = 0;
    for (0..app_state.g_palette_usage_count) |i| {
        const e = &app_state.g_palette_usage[i];
        const line = std.fmt.bufPrint(out[pos..], "{d}\t{d}\t{d}\r\n", .{ e.key, e.count, e.last_used }) catch break;
        pos += line.len;
    }
    const h = win32OpenWrite(path) orelse return;
    defer _ = CloseHandle(h);
    win32WriteAll(h, out[0..pos]);
}

fn paletteUsageFor(target: usize) PaletteUsage {
    const key = paletteUsageKey(target) orelse return .{};
    for (0..app_state.g_palette_usage_count) |i| {
        if (app_state.g_palette_usage[i].key == key) return app_state.g_palette_usage[i];
    }
    return .{ .key = key };
}

pub fn recordPaletteUsage(target: usize) void {
    const key = paletteUsageKey(target) orelse return;
    loadPaletteUsage();
    for (0..app_state.g_palette_usage_count) |i| {
        if (app_state.g_palette_usage[i].key != key) continue;
        if (app_state.g_palette_usage[i].count < std.math.maxInt(u32)) app_state.g_palette_usage[i].count += 1;
        app_state.g_palette_usage[i].last_used = nowFileTime();
        savePaletteUsage();
        return;
    }
    if (app_state.g_palette_usage_count >= MAX_PALETTE_USAGE) return;
    app_state.g_palette_usage[app_state.g_palette_usage_count] = .{
        .key = key,
        .count = 1,
        .last_used = nowFileTime(),
    };
    app_state.g_palette_usage_count += 1;
    savePaletteUsage();
}

fn palettePrimaryLabel(target: usize) ?[]const u8 {
    if (target == SEARCH_TABCTX_CHAT_ALLOW) return "chat view allow";
    if (target == SEARCH_TABCTX_CHAT_ALWAYS) return "chat view always allow";
    if (target == SEARCH_TABCTX_START_SESSION) return "start new session";
    if (target == SEARCH_TABCTX_CHAT_DENY) return "chat view deny";
    if (target == SEARCH_TABCTX_CHAT_STOP) return "chat view stop the agent interrupt escape";
    if (target == SEARCH_TABCTX_CHAT_TAB_URL) return "chat view insert browser tab url link ctrl shift x";
    if (target > SEARCH_TABCTX_BACK and target <= SEARCH_TABCTX_FAVORITE) {
        const tab = if (findShellById(app_state.g_tabctx_sid)) |idx| &app_state.shells[idx] else null;
        return switch (target) {
            SEARCH_TABCTX_CHAT_RESET => "chat view reset this chat clear bubbles cache",
            SEARCH_TABCTX_RECONNECT => "reconnect",
            SEARCH_TABCTX_INBOX_EXCLUDE => if (tab != null and tab.?.inbox_excluded) "inbox: show this session again" else "inbox: never show this session",
            SEARCH_TABCTX_FAVORITE => if (tab != null and tab.?.favorite) "unfavorite" else "favorite",
            SEARCH_TABCTX_MUTE => if (tab != null and tab.?.muted) "unmute activity" else "mute activity",
            SEARCH_TABCTX_KEEPALIVE => if (tab != null and tab.?.keep_alive) "don't keep alive" else "keep alive on exit",
            SEARCH_TABCTX_PIN_TOP => if (tab != null and tab.?.pinned_top) "unpin from top" else "pin to top",
            SEARCH_TABCTX_LOCK => if (tab != null and tab.?.locked) "unlock session" else "lock session",
            SEARCH_TABCTX_KEEPAWAKE => if (tab != null and tab.?.keep_awake) "let browser pane hibernate" else "keep tab awake",
            SEARCH_TABCTX_WSMOVE => "move to workspace",
            SEARCH_TABCTX_GROUP_NEW => "add to new group",
            SEARCH_TABCTX_GROUP_REMOVE => "remove from group",
            SEARCH_TABCTX_GROUP_NEW_TAB_IN => "new tab in group",
            SEARCH_TABCTX_MOVE_NEW_WS => "move tab to new workspace",
            SEARCH_TABCTX_CLEAR_SEL => "clear tab selection",
            SEARCH_TABCTX_ARCHIVE => if (tab != null and tab.?.tmux_session_len > 0) "archive session" else "close session",
            SEARCH_TABCTX_END_TMUX => "end tmux session",
            SEARCH_TABCTX_BROWSER => if (tab != null and tab.?.browser_enabled) "hide browser pane" else "show browser pane",
            else => null,
        };
    }
    if (target >= SEARCH_WSMOVE_OFFSET and target < SEARCH_WSMOVE_OFFSET + MAX_LWS) {
        const idx = target - SEARCH_WSMOVE_OFFSET;
        if (idx >= app_state.g_lws_count) return null;
        return app_state.g_ws_names[idx][0..app_state.g_ws_name_len[idx]];
    }
    const workspace_index: ?usize = if (target >= SEARCH_WORKSPACE_OFFSET and target < SEARCH_WORKSPACE_OFFSET + MAX_WORKSPACES)
        target - SEARCH_WORKSPACE_OFFSET
    else if (target >= SEARCH_WORKSPACE_DELETE_OFFSET and target < SEARCH_WORKSPACE_DELETE_OFFSET + MAX_WORKSPACES)
        target - SEARCH_WORKSPACE_DELETE_OFFSET
    else
        null;
    if (workspace_index) |idx| {
        if (idx >= app_state.g_workspace_count) return null;
        return app_state.g_workspaces[idx].name[0..app_state.g_workspaces[idx].name_len];
    }
    if (target >= SEARCH_REMIND_PRESET_OFFSET and target < SEARCH_REMIND_PRESET_OFFSET + REMIND_PRESET_COUNT)
        return remindPresetLabel(target - SEARCH_REMIND_PRESET_OFFSET);
    if (target >= SEARCH_TMUX_OFFSET and target < SEARCH_NEW_OFFSET) {
        const idx = target - SEARCH_TMUX_OFFSET;
        if (idx >= app_state.g_tmux_cache_count) return null;
        const entry = &app_state.g_tmux_cache[idx];
        if (entry.title_len > 0) return entry.title[0..entry.title_len];
        return entry.name[0..entry.name_len];
    }
    if (target >= SEARCH_NEW_OFFSET and target < SEARCH_NEW_OFFSET + NUM_BUTTONS) {
        const labels = [_][]const u8{
            "new cmd shell",
            "attach host1 tmux session",
            "attach host2 tmux session",
            "new host1 vps shell",
            "new host2 vps shell",
            "new powershell",
            "new bash shell",
            "new git bash shell",
        };
        return labels[target - SEARCH_NEW_OFFSET];
    }
    if (target >= SEARCH_CUSTOMCMD_OFFSET and target < SEARCH_CUSTOMCMD_OFFSET + MAX_CUSTOM_CMDS) {
        const idx = target - SEARCH_CUSTOMCMD_OFFSET;
        if (idx >= app_state.g_custom_cmds_count) return null;
        return app_state.g_custom_cmds[idx].label[0..app_state.g_custom_cmds[idx].label_len];
    }
    if (target >= SEARCH_ARCHIVED_OFFSET and target < SEARCH_ARCHIVED_OFFSET + 64) {
        const idx = target - SEARCH_ARCHIVED_OFFSET;
        if (idx >= app_state.g_archived_count or idx >= app_state.g_archived.items.len) return null;
        return app_state.g_archived.items[idx].name[0..app_state.g_archived.items[idx].name_len];
    }
    if (target >= SEARCH_WS_SNOOZED_ROW_OFFSET and target < SEARCH_WS_SNOOZED_ROW_OFFSET + MAX_REMINDERS) {
        const idx = target - SEARCH_WS_SNOOZED_ROW_OFFSET;
        if (idx >= app_state.g_reminder_count) return null;
        return app_state.g_reminders[idx].name[0..app_state.g_reminders[idx].name_len];
    }
    if (target >= SEARCH_REMINDER_ROW_OFFSET and target < SEARCH_REMINDER_ROW_OFFSET + MAX_REMINDERS) {
        const idx = target - SEARCH_REMINDER_ROW_OFFSET;
        if (idx >= app_state.g_reminder_count) return null;
        return app_state.g_reminders[idx].name[0..app_state.g_reminders[idx].name_len];
    }
    if (target >= SEARCH_SESSION_OVERVIEW_ROW_OFFSET and target < SEARCH_SESSION_OVERVIEW_ROW_OFFSET + MAX_SESSION_OVERVIEW_SEARCH_ROWS) {
        const idx = target - SEARCH_SESSION_OVERVIEW_ROW_OFFSET;
        if (idx >= app_state.g_session_overview_count or idx >= app_state.g_session_overview_rows.items.len) return null;
        return app_state.g_session_overview_rows.items[idx].name[0..app_state.g_session_overview_rows.items[idx].name_len];
    }
    if (target >= SEARCH_SKILL_ROW_OFFSET and target < SEARCH_SKILL_ROW_OFFSET + MAX_PALETTE_SKILLS) {
        const idx = target - SEARCH_SKILL_ROW_OFFSET;
        if (idx >= app_state.g_palette_skills.len) return null;
        return app_state.g_palette_skills[idx].name;
    }
    return switch (target) {
        SEARCH_WSMOVE_NEW_OFFSET => "move to new workspace",
        SEARCH_GROUPMOVE_NEW_OFFSET => "new group",
        SEARCH_GROUPMOVE_NONE_OFFSET => "no group",
        SEARCH_THEME_SYSTEM_OFFSET => "system",
        SEARCH_THEME_DARK_OFFSET => "dark",
        SEARCH_THEME_MID_OFFSET => "mid",
        SEARCH_THEME_LIGHT_OFFSET => "light",
        SEARCH_THEME_AMOLED_OFFSET => "amoled",
        SEARCH_THEME_EDGE_GRAY_OFFSET => "edge grey",
        SEARCH_THEME_MULTIPROMPT_OFFSET => "multiprompt",
        SEARCH_THEME_DEV_BLUE_OFFSET => "dev blue",
        SEARCH_THEME_DEV_EDIT_OFFSET => "edit dev theme json",
        SEARCH_THEME_DEV_RELOAD_OFFSET => "reload dev theme",
        SEARCH_SOUND_OFFSET => "notification sounds",
        SEARCH_THEME_MENU_OFFSET => "themes",
        SEARCH_OPENALL_OFFSET => "open all vps tmux sessions",
        SEARCH_OPENFOLDER_OFFSET => "open sessions in this folder",
        SEARCH_RECOVER_REPO_OFFSET => "recover workspace repo sessions",
        SEARCH_OPENALL_HOST_BACK_OFFSET => "back",
        SEARCH_OPENALL_HOST_DE_OFFSET => "host1 vps",
        SEARCH_OPENALL_HOST_UK_OFFSET => "host2 vps",
        SEARCH_OPENALL_HOST_INNE_OFFSET => "secondary cro vps",
        SEARCH_NEWWIN_OFFSET => "new window",
        SEARCH_CREATEWS_OFFSET => "create workspace",
        SEARCH_WORKSPACES_MENU_OFFSET => "open workspace",
        SEARCH_WORKSPACE_DELETE_MENU_OFFSET => "delete workspace",
        SEARCH_QUIT_OFFSET => "quit multiprompt",
        SEARCH_FULLWIDTH_OFFSET => "full-width",
        SEARCH_SHORTCUTS_OFFSET => "keyboard shortcuts",
        SEARCH_CLOSEWIN_OFFSET => "close workspace",
        SEARCH_RECONNECT_OFFSET => "reconnect tab",
        SEARCH_SINGLEWIN_OFFSET => "single-window mode",
        SEARCH_INSTALLHOOK_OFFSET => "install blue dot hook",
        SEARCH_STARRED_OFFSET => "go to starred workspace favorites alt 1",
        SEARCH_GOINBOX_OFFSET => "go to inbox",
        SEARCH_SHOW_FREQUENT_OFFSET => "show frequent split",
        SEARCH_FREQUENT_FIRST_OFFSET => "frequent as first tab",
        SEARCH_SHOW_FAVORITES_OFFSET => "show favorites split",
        SEARCH_SHOW_ALL_OFFSET => "show all split",
        SEARCH_INBOX_FREQUENT_OFFSET => "inbox: frequent input today 24 hours watch-only six hours",
        SEARCH_WSSORT_MENU_OFFSET => "sort workspaces",
        SEARCH_WSMOVE_MENU_OFFSET => "move to workspace",
        SEARCH_GROUPMOVE_MENU_OFFSET => "move to group",
        SEARCH_HIDESIDEBAR_OFFSET => "sidebar expand",
        SEARCH_HIDEPILLS_OFFSET => "workspace switcher",
        SEARCH_NEXTUNREAD_OFFSET => "next unread session",
        SEARCH_SIDEBAR_COLLAPSE_OFFSET => "sidebar collapse",
        SEARCH_SIDEBAR_HIDE_OFFSET => "sidebar hide",
        SEARCH_TABSORT_INBOX_OFFSET => "tab order auto",
        SEARCH_TABSORT_MANUAL_OFFSET => "tab order manual",
        SEARCH_POWER_AUTO_OFFSET => "power saver auto",
        SEARCH_POWER_ALWAYS_OFFSET => "power saver always",
        SEARCH_POWER_OFF_OFFSET => "power saver off",
        SEARCH_LADDER_AUTO_OFFSET => "token ladder auto",
        SEARCH_LADDER_CLAUDE_OFFSET => "token ladder burn claude",
        SEARCH_LADDER_CODEX_OFFSET => "token ladder burn codex",
        SEARCH_LADDER_DASH_OFFSET => "token ladder open dashboard",
        SEARCH_VOICE_MODE_ON_OFFSET => "voice mode on",
        SEARCH_VOICE_MODE_OFF_OFFSET => "voice mode off",
        SEARCH_ETA_NUMBERS_OFFSET => "eta countdown numbers",
        SEARCH_ETA_PROGRESS_OFFSET => "eta progress line",
        SEARCH_ETA_ACCURACY_OFFSET => "estimate accuracy",
        SEARCH_CHAT_VIEW_MODE_PER_SESSION_OFFSET => "chat view per tab",
        SEARCH_CHAT_VIEW_MODE_EVERYWHERE_OFFSET => "chat view on everywhere",
        SEARCH_CHAT_VIEW_MODE_NOWHERE_OFFSET => "chat view off everywhere",
        SEARCH_VOICE_STOP_OFFSET => "voice stop speaking mute",
        SEARCH_VOICE_ALWAYS_ON_OFFSET => "voice always listening on talk over",
        SEARCH_VOICE_ALWAYS_OFF_OFFSET => "voice always listening off taking turns",
        SEARCH_VOICE_SPEED_100_OFFSET => "voice speed 1x",
        SEARCH_VOICE_SPEED_125_OFFSET => "voice speed 1.25x",
        SEARCH_VOICE_SPEED_140_OFFSET => "voice speed 1.4x",
        SEARCH_VOICE_SPEED_150_OFFSET => "voice speed 1.5x",
        SEARCH_VOICE_REPLAY_OFFSET => "voice read last reply repeat replay",
        SEARCH_VOICE_PREVIOUS_OFFSET => "voice read previous reply",
        SEARCH_VOICE_NEXT_OFFSET => "voice read next reply",
        SEARCH_UNREADONLY_OFFSET => "toggle unread only",
        SEARCH_THREADTITLE_OFFSET => "thread title",
        SEARCH_FONT_BIGGER_OFFSET => "console font bigger",
        SEARCH_FONT_SMALLER_OFFSET => "console font smaller",
        SEARCH_FONT_RESET_OFFSET => "console font reset",
        SEARCH_UI_BIGGER_OFFSET => "ui size increase",
        SEARCH_UI_SMALLER_OFFSET => "ui size decrease",
        SEARCH_UI_RESET_OFFSET => "ui size reset",
        SEARCH_CUSTOMCMD_EDIT_OFFSET => "commands edit commands.json",
        SEARCH_CUSTOMCMD_RELOAD_OFFSET => "commands reload",
        SEARCH_ARCHIVE_OFFSET => "archive session",
        SEARCH_REOPEN_OFFSET => "reopen closed tab",
        SEARCH_URLPICK_OFFSET => "open url from screen",
        SEARCH_CLOSETAB_OFFSET => "close tab",
        SEARCH_FAVORITE_OFFSET => "favorite: toggle star session",
        SEARCH_MUTETAB_OFFSET => "mute tab",
        SEARCH_INBOX_EXCLUDE_OFFSET => if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].inbox_excluded) "inbox: show this session again" else "inbox: never show this session",
        SEARCH_KEEPALIVE_OFFSET => "keep alive",
        SEARCH_CHAT_VIEW_OFFSET => "chat view",
        SEARCH_CHAT_ALLOW_OFFSET => "chat view allow",
        SEARCH_CHAT_ALWAYS_OFFSET => "chat view always allow",
        SEARCH_CHAT_DENY_OFFSET => "chat view deny",
        SEARCH_CHAT_STOP_OFFSET => if (app_state.ISSUE_265_WORKING_BAR) "chat view stop the agent interrupt" else "stop agent",
        SEARCH_CHAT_QUEUE_SEND_OFFSET => "chat view send queued messages now offline outbox",
        SEARCH_CHAT_RESET_OFFSET => "chat view reset this chat clear bubbles cache",
        SEARCH_CHAT_TAB_URL_OFFSET => "chat view insert browser tab url link ctrl shift x",
        SEARCH_CHAT_QUEUE_CLEAR_OFFSET => "chat view clear offline queue discard queued messages",
        SEARCH_CHAT_RETRY_UNSENT_OFFSET => "chat view retry unsent messages not sent resend",
        SEARCH_CHAT_DISCARD_UNSENT_OFFSET => "chat view discard unsent messages not sent",
        SEARCH_CHAT_PUSH_QUEUED_OFFSET => "chat view send queued in claude message now push",
        SEARCH_MULTIPROMPT_LOGIN_OFFSET => "sign in to multiprompt sync",
        SEARCH_SYNC_SIGNOUT_OFFSET => "account: sign out",
        SEARCH_SYNC_STATUS_OFFSET => "account: devices",
        SEARCH_APPROVE_DEVICES_OFFSET => "account: approve devices",
        SEARCH_LAYOUT_PULL_OFFSET => "sync: pull now",
        SEARCH_SKILLS_MENU_OFFSET => "skills",
        SEARCH_CHAT_REPLY_OFFSET => "Chat View: Reply to latest agent message",
        SEARCH_CHAT_TODO_OFFSET => "Chat View: Toggle todo list",
        SEARCH_CHAT_FIND_OFFSET => "chat view find in conversation ctrl f",
        SEARCH_CHAT_TOOL_STEPS_OFFSET => "chat view open or fold all tool steps expand collapse tools",
        SEARCH_CHAT_COPY_CODE_OFFSET => "chat view copy latest code block ctrl shift d",
        SEARCH_CHAT_ATTACH_OFFSET => "chat view attach file pdf zip log document image upload picture photo screenshot ctrl v drop drag",
        SEARCH_CHAT_COPY_SELECTION_OFFSET => "chat view copy selection ctrl c",
        SEARCH_CHAT_SELECT_ALL_OFFSET => "chat view select all text ctrl a",
        SEARCH_CHAT_AC_OFFSET => "chat view insert command or skill browse ctrl slash",
        SEARCH_SKILLS_BACK_OFFSET => "back",
        SEARCH_BROWSER_TOGGLE_OFFSET => if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_open_failed) "retry browser pane" else if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_hwnd == null and app_state.shells[app_state.active_shell].browser_launch_tick != 0) "close browser pane" else "open browser pane",
        SEARCH_BROWSER_URL_OFFSET => "browser open url",
        SEARCH_BROWSER_INSTRUCT_OFFSET => "browser control instructions",
        SEARCH_BROWSER_FOCUS_URL_OFFSET => "browser focus address bar",
        SEARCH_BROWSER_FOCUS_TOGGLE_OFFSET => "switch shell browser focus",
        SEARCH_BROWSER_AUTOSUSPEND_OFFSET => "browser auto suspend",
        SEARCH_KEEPAWAKE_OFFSET => "keep tab awake",
        SEARCH_HIBERNATE_NOW_OFFSET => "hibernate browser panes now",
        SEARCH_CLOSE_ALL_BROWSER_PANES_OFFSET => "close all browser panes",
        SEARCH_CRASH_REPORTS_OFFSET => "crash reports open folder",
        SEARCH_CRASH_NOW_OFFSET => "debug crash now",
        SEARCH_CHANGELOG_OFFSET => "changelog",
        SEARCH_BROWSER_BACK_OFFSET => "browser back",
        SEARCH_BROWSER_FORWARD_OFFSET => "browser forward",
        SEARCH_BROWSER_MODE_OFFSET => "browser pane mode",
        SEARCH_BROWSER_ENGINE_OFFSET => "browser engine",
        SEARCH_RESTART_OFFSET => "restart multiprompt",
        SEARCH_UPDATE_OFFSET => "restart to update relaunch new version",
        SEARCH_ZSB_REBIND_OFFSET => "rebind browser pane",
        SEARCH_SHELL_DIAG_OFFSET => "copy shell diagnostics",
        SEARCH_SYNC_NAME_OFFSET => "use agent or tmux name",
        SEARCH_RENAME_SYNC_OFFSET => "rename session",
        SEARCH_END_TMUX_OFFSET => "end tmux session",
        SEARCH_REMIND_ME_OFFSET => "remind me",
        SEARCH_REMINDERS_MENU_OFFSET => "reminders",
        SEARCH_WS_SNOOZE_OFFSET => "workspace snooze",
        SEARCH_WS_SNOOZED_OFFSET => "workspace snoozed wake",
        SEARCH_WS_BRINGBACK_OFFSET => "workspace bring back all sessions",
        SEARCH_CODEX_TMUX_OFFSET => "new codex tmux session",
        SEARCH_SNIPPETS_MENU_OFFSET => "use snippets",
        SEARCH_SNIPPET_CREATE_OFFSET => "create snippet",
        SEARCH_SNIPPET_BACK_OFFSET => "back",
        SEARCH_SESSION_OVERVIEW_MENU_OFFSET => "show all sessions",
        SEARCH_ARCHIVED_VIEW_OFFSET => "archived sessions",
        SEARCH_BROWSER_SHOTURL_OFFSET => "browser screenshot tab link in shell",
        SEARCH_PIN_TOP_OFFSET => "pin tab to top",
        SEARCH_LOCK_SESSION_OFFSET => "lock session",
        SEARCH_UNARCHIVE_HIDDEN_OFFSET => "restore workspace waiting sessions",
        SEARCH_UNARCHIVE_UNATTACHED_OFFSET => "unarchive unattached sessions",
        SEARCH_USAGE_LOGIN_PRIMARY_OFFSET => "reconnect claude primary telemetry",
        SEARCH_USAGE_LOGIN_INNE_OFFSET => "reconnect claude secondary telemetry",
        SEARCH_RENAMEWIN_OFFSET => "rename workspace",
        SEARCH_MOBILE_OFFSET => "mobile latency mode",
        SEARCH_ADDFAVICON_OFFSET => "add favicon",
        else => null,
    };
}

fn asciiStartsWithCI(text: []const u8, prefix: []const u8) bool {
    if (prefix.len > text.len) return false;
    for (prefix, 0..) |c, i| {
        if (std.ascii.toLower(text[i]) != std.ascii.toLower(c)) return false;
    }
    return true;
}

fn paletteTextMatchRank(text: []const u8, query: []const u16) u8 {
    if (query.len == 0) return 0;
    var query_ascii: [64]u8 = undefined;
    if (query.len > query_ascii.len) return 0;
    for (query, 0..) |c, i| {
        if (c > 0x7F) return 0;
        query_ascii[i] = @intCast(c);
    }
    const q = query_ascii[0..query.len];
    if (asciiEqualsCI(text, q)) return 4;
    if (asciiStartsWithCI(text, q)) return 3;
    var word_start: usize = 0;
    while (word_start < text.len) {
        while (word_start < text.len and !std.ascii.isAlphanumeric(text[word_start])) : (word_start += 1) {}
        if (word_start >= text.len) break;
        if (asciiStartsWithCI(text[word_start..], q)) return 2;
        while (word_start < text.len and std.ascii.isAlphanumeric(text[word_start])) : (word_start += 1) {}
    }
    return if (asciiContainsQueryInsensitive(text, query)) 1 else 0;
}

fn paletteFoldU16(c: u16) u16 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

fn paletteU16IsWord(c: u16) bool {
    return c > 0x7F or std.ascii.isAlphanumeric(@intCast(c));
}

pub fn paletteWideTextMatchRank(text: []const u16, query: []const u16) u8 {
    if (query.len == 0) return 0;
    if (text.len == query.len) {
        var exact = true;
        for (text, query) |tc, qc| {
            if (paletteFoldU16(tc) != paletteFoldU16(qc)) {
                exact = false;
                break;
            }
        }
        if (exact) return 4;
    }
    if (text.len >= query.len) {
        var prefix = true;
        for (query, 0..) |qc, i| {
            if (paletteFoldU16(text[i]) != paletteFoldU16(qc)) {
                prefix = false;
                break;
            }
        }
        if (prefix) return 3;
    }
    var word_start: usize = 0;
    while (word_start < text.len) {
        while (word_start < text.len and !paletteU16IsWord(text[word_start])) : (word_start += 1) {}
        if (word_start >= text.len) break;
        if (text.len - word_start >= query.len) {
            var word_prefix = true;
            for (query, 0..) |qc, i| {
                if (paletteFoldU16(text[word_start + i]) != paletteFoldU16(qc)) {
                    word_prefix = false;
                    break;
                }
            }
            if (word_prefix) return 2;
        }
        while (word_start < text.len and paletteU16IsWord(text[word_start])) : (word_start += 1) {}
    }
    return if (u16ContainsInsensitive(text, query)) 1 else 0;
}

fn paletteQueryRank(target: usize) u8 {
    if (app_state.g_search_len == 0) return 0;
    if (target >= SEARCH_SNIPPET_OFFSET and target < SEARCH_SNIPPET_OFFSET + MAX_SNIPPETS) {
        const idx = target - SEARCH_SNIPPET_OFFSET;
        if (idx >= app_state.g_snippet_count) return 1;
        return @max(1, paletteWideTextMatchRank(app_state.g_snippets[idx].name[0..app_state.g_snippets[idx].name_len], app_state.g_search_buf[0..app_state.g_search_len]));
    }
    if (target < app_state.shell_count) {
        const rank = paletteWideTextMatchRank(app_state.shells[target].name[0..app_state.shells[target].name_len], app_state.g_search_buf[0..app_state.g_search_len]);
        return if (rank == 0) 1 else rank;
    }
    const group_index: ?usize = if (target >= SEARCH_GROUPMOVE_GROUP_OFFSET and target < SEARCH_GROUPMOVE_GROUP_OFFSET + MAX_GROUPS)
        target - SEARCH_GROUPMOVE_GROUP_OFFSET
    else if (target >= SEARCH_TABCTX_GROUP_ADD_OFFSET and target < SEARCH_TABCTX_GROUP_ADD_OFFSET + MAX_GROUPS)
        target - SEARCH_TABCTX_GROUP_ADD_OFFSET
    else
        null;
    if (group_index) |idx| {
        if (idx >= app_state.group_count) return 1;
        return @max(1, paletteWideTextMatchRank(app_state.groups[idx].name[0..app_state.groups[idx].name_len], app_state.g_search_buf[0..app_state.g_search_len]));
    }
    const label = palettePrimaryLabel(target) orelse return 1;
    const rank = paletteTextMatchRank(label, app_state.g_search_buf[0..app_state.g_search_len]);
    return if (rank == 0) 1 else rank;
}

fn paletteWorkspaceRank(target: usize) u8 {
    if (target < SEARCH_CUSTOMCMD_OFFSET or target >= SEARCH_CUSTOMCMD_OFFSET + MAX_CUSTOM_CMDS) return 0;
    const idx = target - SEARCH_CUSTOMCMD_OFFSET;
    if (idx >= app_state.g_custom_cmds_count) return 0;
    return if (app_state.g_custom_cmds[idx].workspace_len > 0) 1 else 0;
}

fn paletteTargetIsDestructive(target: usize) bool {
    return target == SEARCH_QUIT_OFFSET or
        target == SEARCH_CLOSEWIN_OFFSET or
        target == SEARCH_ARCHIVE_OFFSET or
        target == SEARCH_END_TMUX_OFFSET or
        target == SEARCH_CLOSETAB_OFFSET or
        target == SEARCH_WORKSPACE_DELETE_MENU_OFFSET or
        target == SEARCH_SYNC_SIGNOUT_OFFSET;
}

fn paletteFrecencyAt(usage: PaletteUsage, now: u64) u16 {
    if (usage.count == 0 or usage.last_used == 0) return 0;
    const ticks_per_hour: u64 = 36_000_000_000;
    const age = now -| usage.last_used;
    const recency: u16 = if (age < ticks_per_hour)
        96
    else if (age < 24 * ticks_per_hour)
        80
    else if (age < 7 * 24 * ticks_per_hour)
        64
    else if (age < 30 * 24 * ticks_per_hour)
        48
    else if (age < 90 * 24 * ticks_per_hour)
        32
    else
        0;
    var frequency: u16 = 0;
    var remaining = usage.count;
    while (remaining > 1 and frequency < 15) : (frequency += 1) remaining >>= 1;
    return recency + frequency;
}

test "palette recency bands cannot be overpowered by lifetime frequency" {
    const hour: u64 = 36_000_000_000;
    const now: u64 = 120 * 24 * hour;
    const six_days_old = PaletteUsage{ .count = 1, .last_used = now - 6 * 24 * hour };
    const eight_days_old_maxed = PaletteUsage{ .count = std.math.maxInt(u32), .last_used = now - 8 * 24 * hour };
    try std.testing.expect(paletteFrecencyAt(six_days_old, now) > paletteFrecencyAt(eight_days_old_maxed, now));

    const same_band_once = PaletteUsage{ .count = 1, .last_used = now - 2 * 24 * hour };
    const same_band_often = PaletteUsage{ .count = 8, .last_used = now - 2 * 24 * hour };
    try std.testing.expect(paletteFrecencyAt(same_band_often, now) > paletteFrecencyAt(same_band_once, now));
}

fn paletteResultOutranks(key: usize, prev: usize, now: u64) bool {
    if (app_state.g_search_len > 0) {
        const key_match = paletteQueryRank(key);
        const prev_match = paletteQueryRank(prev);
        if (key_match != prev_match) return key_match > prev_match;
        const key_workspace = paletteWorkspaceRank(key);
        const prev_workspace = paletteWorkspaceRank(prev);
        if (key_workspace != prev_workspace) return key_workspace > prev_workspace;
    } else {
        const key_safe = !paletteTargetIsDestructive(key);
        const prev_safe = !paletteTargetIsDestructive(prev);
        if (key_safe != prev_safe) return key_safe;
    }
    const key_usage = paletteUsageFor(key);
    const prev_usage = paletteUsageFor(prev);
    const key_frecency = paletteFrecencyAt(key_usage, now);
    const prev_frecency = paletteFrecencyAt(prev_usage, now);
    if (key_frecency != prev_frecency) return key_frecency > prev_frecency;
    return key_usage.last_used > prev_usage.last_used;
}

fn sortSearchResultsByRank() void {
    const now = nowFileTime();
    var i: u32 = 1;
    while (i < app_state.g_search_result_count) : (i += 1) {
        const key = app_state.g_search_results[i];
        var j = i;
        while (j > 0) {
            const prev = app_state.g_search_results[j - 1];
            if (!paletteResultOutranks(key, prev, now)) break;
            app_state.g_search_results[j] = prev;
            j -= 1;
        }
        app_state.g_search_results[j] = key;
    }
}

fn promoteSearchTargetToFront(results: []usize, target: usize) bool {
    var found: ?usize = null;
    for (results, 0..) |result, i| {
        if (result == target) {
            found = i;
            break;
        }
    }
    const from = found orelse return false;
    if (from == 0) return true;
    var i = from;
    while (i > 0) : (i -= 1) results[i] = results[i - 1];
    results[0] = target;
    return true;
}

fn pickRecentSessions(last_viewed: []const u64, eligible: []const bool, exclude: usize, first: ?usize, out: []usize) usize {
    var n: usize = 0;
    if (first) |f| {
        if (f < last_viewed.len and f != exclude and eligible[f] and out.len > 0) {
            out[0] = f;
            n = 1;
        }
    }
    const lead = n;
    for (last_viewed, 0..) |lv, i| {
        if (i == exclude or !eligible[i] or lv == 0) continue;
        if (lead == 1 and i == out[0]) continue;
        var pos = n;
        while (pos > lead and last_viewed[out[pos - 1]] < lv) pos -= 1;
        if (pos >= out.len) continue;
        const end = if (n < out.len) n else out.len - 1;
        var k = end;
        while (k > pos) : (k -= 1) out[k] = out[k - 1];
        out[pos] = i;
        if (n < out.len) n += 1;
    }
    return n;
}

test "pickRecentSessions orders by recency, leads with previous, skips active and ineligible" {
    const lv = [_]u64{ 50, 90, 70, 0, 80, 60, 95 };
    const ok = [_]bool{ true, true, true, true, true, false, true };
    var out: [3]usize = undefined;
    try std.testing.expectEqual(@as(usize, 3), pickRecentSessions(&lv, &ok, 6, null, &out));
    try std.testing.expectEqualSlices(usize, &.{ 1, 4, 2 }, &out);
    try std.testing.expectEqual(@as(usize, 3), pickRecentSessions(&lv, &ok, 6, 0, &out));
    try std.testing.expectEqualSlices(usize, &.{ 0, 1, 4 }, &out);
    try std.testing.expectEqual(@as(usize, 3), pickRecentSessions(&lv, &ok, 6, 6, &out));
    try std.testing.expectEqualSlices(usize, &.{ 1, 4, 2 }, &out);
    try std.testing.expectEqual(@as(usize, 3), pickRecentSessions(&lv, &ok, 6, 5, &out));
    try std.testing.expectEqualSlices(usize, &.{ 1, 4, 2 }, &out);
    var big: [8]usize = undefined;
    try std.testing.expectEqual(@as(usize, 4), pickRecentSessions(&lv, &ok, 6, null, &big));
    try std.testing.expectEqualSlices(usize, &.{ 1, 4, 2, 0 }, big[0..4]);
}

test "Ctrl K previous-session promotion preserves every other result" {
    var results = [_]usize{ 7000, 3, 7001, 8 };
    try std.testing.expect(promoteSearchTargetToFront(results[0..], 8));
    try std.testing.expectEqualSlices(usize, &[_]usize{ 8, 7000, 3, 7001 }, results[0..]);
    try std.testing.expect(!promoteSearchTargetToFront(results[0..], 99));
    try std.testing.expectEqualSlices(usize, &[_]usize{ 8, 7000, 3, 7001 }, results[0..]);
}

pub fn asciiEqualsCI(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, 0..) |c, i| {
        if (u16ToLower(c) != u16ToLower(b[i])) return false;
    }
    return true;
}

fn customCmdVisibleInWorkspace(idx: usize, ws: u8) bool {
    const c = &app_state.g_custom_cmds[idx];
    if (c.workspace_len == 0) return true;
    var ws_buf: [32]u8 = undefined;
    const ws_name = workspaceDisplayName(ws, &ws_buf);
    return asciiEqualsCI(ws_name, c.workspace[0..c.workspace_len]);
}

fn workspaceConfiguredTerminalFolder(ws: u8, out_host: *u8, out_path: *[256]u8, out_len: *u32, out_program: *[128]u8, out_program_len: *u32) bool {
    loadCustomCommandsIfChanged();
    var i: usize = 0;
    while (i < app_state.g_custom_cmds_count) : (i += 1) {
        const c = &app_state.g_custom_cmds[i];
        if (!c.is_default or c.workspace_len == 0 or !customCmdVisibleInWorkspace(i, ws)) continue;
        if (c.kind != .vps and c.kind != .vps2) continue;
        const cwd = c.cwd[0..c.cwd_len];
        if (!remotePathSafeForShell(cwd) or cwd.len > out_path.len) continue;
        @memcpy(out_path[0..cwd.len], cwd);
        out_len.* = @intCast(cwd.len);
        out_host.* = if (c.kind == .vps2) 1 else 0;
        out_program_len.* = c.alt_t_len;
        @memcpy(out_program[0..c.alt_t_len], c.alt_t[0..c.alt_t_len]);
        return true;
    }
    return false;
}

fn customCmdMatchesQuery(idx: usize, query: []const u16) bool {
    const c = &app_state.g_custom_cmds[idx];
    var kw: [240]u8 = undefined;
    var n: usize = 0;
    for (c.label[0..c.label_len]) |ch| {
        if (n < kw.len) {
            kw[n] = ch;
            n += 1;
        }
    }
    const kind_words: []const u8 = switch (c.kind) {
        .vps => " vps host1 de ssh remote",
        .vps2 => " vps host2 uk ssh remote",
        .pwsh => " pwsh powershell local",
        else => " cmd local",
    };
    for (kind_words) |ch| {
        if (n < kw.len) {
            kw[n] = ch;
            n += 1;
        }
    }
    for (" new custom command spawn") |ch| {
        if (n < kw.len) {
            kw[n] = ch;
            n += 1;
        }
    }
    if (c.workspace_len > 0) {
        if (n < kw.len) {
            kw[n] = ' ';
            n += 1;
        }
        for (c.workspace[0..c.workspace_len]) |ch| {
            if (n < kw.len) {
                kw[n] = ch;
                n += 1;
            }
        }
    }
    var wstart: usize = 0;
    var qp: usize = 0;
    while (qp <= query.len) : (qp += 1) {
        const at_end = (qp == query.len);
        if (at_end or query[qp] == ' ') {
            if (qp > wstart) {
                if (!asciiContainsQueryInsensitive(kw[0..n], query[wstart..qp])) return false;
            }
            wstart = qp + 1;
        }
    }
    return true;
}

pub fn spawnCustomCmd(idx: usize) bool {
    if (idx >= app_state.g_custom_cmds_count) return false;
    const c = &app_state.g_custom_cmds[idx];
    var ok = false;
    switch (c.kind) {
        .vps, .vps2 => {
            const host: u8 = if (c.kind == .vps2) 1 else 0;
            const workspace = if (app_state.g_single_window) app_state.g_active_workspace else 0;
            if (c.startup_cmd_len > 0 and commandCreatesAgentWorkload(c.startup_cmd[0..c.startup_cmd_len]) and
                !capacityAdmitNewAgent(host, workspace, c.label[0..c.label_len]))
                return false;
            if (c.startup_cmd_len > 0) {
                const n = @min(@as(usize, c.startup_cmd_len), app_state.g_pending_spawn_cmd.len);
                @memcpy(app_state.g_pending_spawn_cmd[0..n], c.startup_cmd[0..n]);
                app_state.g_pending_spawn_cmd_len = @intCast(n);
            }
            ok = spawnShellWithSession(c.kind, null, null, null);
            app_state.g_pending_spawn_cmd_len = 0;
        },
        else => {
            const cmd_slice: ?[]const u8 = if (c.startup_cmd_len > 0) c.startup_cmd[0..c.startup_cmd_len] else null;
            const cwd_slice: ?[]const u8 = if (c.cwd_len > 0) c.cwd[0..c.cwd_len] else null;
            ok = spawnShellWithSession(c.kind, null, cwd_slice, cmd_slice);
        },
    }
    if (ok and c.label_len > 0 and app_state.shell_count > 0) {
        const ns = app_state.shell_count - 1;
        setShellName(&app_state.shells[ns], c.label[0..c.label_len]);
        if (c.kind != .vps and c.kind != .vps2) app_state.shells[ns].name_source = .manual;
    }
    return ok;
}

fn remotePathSafeForShell(path: []const u8) bool {
    if (path.len == 0 or path.len > 220) return false;
    for (path) |c| {
        const ok =
            (c >= 'a' and c <= 'z') or
            (c >= 'A' and c <= 'Z') or
            (c >= '0' and c <= '9') or
            c == '/' or c == '_' or c == '-' or c == '.' or c == '~';
        if (!ok) return false;
    }
    return true;
}

fn buildWorkspaceTmuxLaunchCmd(out: *[512]u8, session: []const u8, cwd: []const u8, program: []const u8) ?[]const u8 {
    if (!remotePathSafeForShell(cwd) or (program.len > 0 and !altTProgramSafe(program))) return null;
    var len: usize = 0;
    if (!appendAsciiBuf(out, &len, "tmux new-session -d -s ")) return null;
    if (!appendAsciiBuf(out, &len, session)) return null;
    if (!appendAsciiBuf(out, &len, " -c ")) return null;
    if (!appendAsciiBuf(out, &len, cwd)) return null;
    if (program.len > 0) {
        if (!appendAsciiBuf(out, &len, " 2>/dev/null; tmux send-keys -t ")) return null;
        if (!appendAsciiBuf(out, &len, session)) return null;
        if (!appendAsciiBuf(out, &len, " 'cd ")) return null;
        if (!appendAsciiBuf(out, &len, cwd)) return null;
        if (!appendAsciiBuf(out, &len, " && ")) return null;
        if (!appendAsciiBuf(out, &len, program)) return null;
        if (!appendAsciiBuf(out, &len, "' Enter; tmux attach -t ")) return null;
    } else if (!appendAsciiBuf(out, &len, " 2>/dev/null; tmux attach -t ")) return null;
    if (!appendAsciiBuf(out, &len, session)) return null;
    return out[0..len];
}

fn buildWorkspaceTmuxSessionName(out: *[64]u8) []const u8 {
    return std.fmt.bufPrint(out, "term-{x}", .{GetTickCount64()}) catch "term";
}

test "workspace tmux program runs after shell startup and neutral fallback stays unchanged" {
    var out: [512]u8 = undefined;
    const launched = buildWorkspaceTmuxLaunchCmd(&out, "term-test", "~/project", "claude") orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("tmux new-session -d -s term-test -c ~/project 2>/dev/null; tmux send-keys -t term-test 'cd ~/project && claude' Enter; tmux attach -t term-test", launched);
    const neutral = buildWorkspaceTmuxLaunchCmd(&out, "term-test", "~/projects", "") orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("tmux new-session -d -s term-test -c ~/projects 2>/dev/null; tmux attach -t term-test", neutral);
    try std.testing.expect(buildWorkspaceTmuxLaunchCmd(&out, "term-test", "~/projects", "claude; exit") == null);
}

pub fn spawnWorkspaceTmuxSession() bool {
    var host: u8 = 0;
    var cwd_buf: [256]u8 = undefined;
    var cwd_len: u32 = 0;
    var program_buf: [128]u8 = undefined;
    var program_len: u32 = 0;
    const workspace = if (app_state.g_single_window) app_state.g_active_workspace else 0;
    if (!workspaceConfiguredTerminalFolder(workspace, &host, &cwd_buf, &cwd_len, &program_buf, &program_len) and
        !workspacePrimaryRepo(&host, &cwd_buf, &cwd_len)) return false;
    const cwd = cwd_buf[0..cwd_len];
    const program = program_buf[0..program_len];
    if (program.len > 0 and commandCreatesAgentWorkload(program) and
        !capacityAdmitNewAgent(host, workspace, "new workspace session")) return false;

    var session_buf: [64]u8 = undefined;
    const session = buildWorkspaceTmuxSessionName(&session_buf);
    var cmd_buf: [512]u8 = undefined;
    const launch_cmd = buildWorkspaceTmuxLaunchCmd(&cmd_buf, session, cwd, program) orelse return false;
    @memcpy(app_state.g_pending_tmux_cmd[0..launch_cmd.len], launch_cmd);
    app_state.g_pending_tmux_cmd_len = @intCast(launch_cmd.len);
    app_state.g_pending_tmux_host = host;
    const ok = spawnShellWithSession(.tmux, session, null, null);
    app_state.g_pending_tmux_host = 0;
    app_state.g_pending_tmux_cmd_len = 0;

    if (ok and app_state.shell_count > 0) {
        const ns: usize = app_state.shell_count - 1;
        const claude = std.mem.startsWith(u8, program, "claude");
        setShellName(&app_state.shells[ns], if (claude) "Claude" else "Terminal");
        app_state.shells[ns].name_source = .default;
        app_state.shells[ns].ai_agent = if (claude) 1 else 0;
        const n = @min(cwd.len, app_state.shells[ns].cached_cwd.len - 1);
        @memcpy(app_state.shells[ns].cached_cwd[0..n], cwd[0..n]);
        app_state.shells[ns].cached_cwd_len = @intCast(n);
        publishInboxState();
        saveSession();
    }
    return ok;
}

pub fn activeRemoteContextForCodexTmux(out_host: *u8, out_cwd: *[256]u8, out_cwd_len: *u32) bool {
    out_host.* = 0;
    out_cwd_len.* = 0;
    if (!focusedSessionFolder(out_host, out_cwd, out_cwd_len)) return false;
    return remotePathSafeForShell(out_cwd[0..@as(usize, @intCast(out_cwd_len.*))]);
}

fn buildCodexTmuxLaunchCmd(out: *[512]u8, session: []const u8, cwd: []const u8) ?[]const u8 {
    if (!remotePathSafeForShell(cwd)) return null;
    var len: usize = 0;
    var ok = appendAsciiBuf(out, &len, "tmux new-session -d -s ");
    ok = ok and appendAsciiBuf(out, &len, session);
    ok = ok and appendAsciiBuf(out, &len, " 2>/dev/null; tmux send-keys -t ");
    ok = ok and appendAsciiBuf(out, &len, session);
    ok = ok and appendAsciiBuf(out, &len, " 'cd ");
    ok = ok and appendAsciiBuf(out, &len, cwd);
    ok = ok and appendAsciiBuf(out, &len, " && codex -c tui.terminal_title=[\\\"thread-title\\\"]' Enter; tmux attach -t ");
    ok = ok and appendAsciiBuf(out, &len, session);
    if (!ok or len == 0) return null;
    return out[0..len];
}

test "Codex tmux launch exposes the renamed thread in the terminal title" {
    var out: [512]u8 = std.mem.zeroes([512]u8);
    const cmd = buildCodexTmuxLaunchCmd(&out, "codex-test", "/srv/project") orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, cmd, "codex -c tui.terminal_title=[\\\"thread-title\\\"]") != null);
}

fn buildCodexTmuxSessionName(out: *[64]u8) []const u8 {
    return std.fmt.bufPrint(out, "codex-{x}", .{GetTickCount64()}) catch "codex";
}

pub fn spawnCodexTmuxSession() bool {
    var host: u8 = 0;
    var cwd_buf: [256]u8 = undefined;
    var cwd_len: u32 = 0;
    if (!activeRemoteContextForCodexTmux(&host, &cwd_buf, &cwd_len)) return false;
    const cwd = cwd_buf[0..@as(usize, @intCast(cwd_len))];
    const workspace = if (app_state.g_single_window) app_state.g_active_workspace else 0;
    if (!capacityAdmitNewAgent(host, workspace, "new Codex session")) return false;

    var session_buf: [64]u8 = undefined;
    const session = buildCodexTmuxSessionName(&session_buf);
    var cmd_buf: [512]u8 = std.mem.zeroes([512]u8);
    const launch_cmd = buildCodexTmuxLaunchCmd(&cmd_buf, session, cwd) orelse return false;

    @memcpy(app_state.g_pending_tmux_cmd[0..launch_cmd.len], launch_cmd);
    app_state.g_pending_tmux_cmd_len = @intCast(launch_cmd.len);
    app_state.g_pending_tmux_host = host;
    const ok = spawnShellWithSession(.tmux, session, null, null);
    app_state.g_pending_tmux_host = 0;
    app_state.g_pending_tmux_cmd_len = 0;

    if (ok and app_state.shell_count > 0) {
        const ns: usize = app_state.shell_count - 1;
        const ts_len = @min(session.len, app_state.shells[ns].tmux_session.len - 1);
        @memcpy(app_state.shells[ns].tmux_session[0..ts_len], session[0..ts_len]);
        app_state.shells[ns].tmux_session_len = @intCast(ts_len);
        app_state.shells[ns].tmux_host = host;
        app_state.shells[ns].ai_agent = 2;
        setShellName(&app_state.shells[ns], "Codex");
        app_state.shells[ns].name_source = .default;
        const n = @min(cwd.len, app_state.shells[ns].cached_cwd.len - 1);
        @memcpy(app_state.shells[ns].cached_cwd[0..n], cwd[0..n]);
        app_state.shells[ns].cached_cwd_len = @intCast(n);
        publishInboxState();
        saveSession();
    }

    return ok;
}

fn clampSearchSelectionAndScroll() void {
    if (app_state.g_search_result_count == 0) {
        app_state.g_search_sel = 0;
        app_state.g_search_scroll = 0;
        return;
    }

    if (app_state.g_search_sel >= app_state.g_search_result_count) {
        app_state.g_search_sel = app_state.g_search_result_count - 1;
    }

    const visible_rows: u32 = @min(app_state.g_search_result_count, SEARCH_VISIBLE_ROWS);
    const max_scroll = app_state.g_search_result_count - visible_rows;
    if (app_state.g_search_scroll > max_scroll) {
        app_state.g_search_scroll = max_scroll;
    }
}

pub fn keepSearchSelectionVisible() void {
    clampSearchSelectionAndScroll();
    if (app_state.g_search_result_count == 0) return;

    const visible_rows: u32 = @min(app_state.g_search_result_count, SEARCH_VISIBLE_ROWS);
    if (app_state.g_search_sel < app_state.g_search_scroll) {
        app_state.g_search_scroll = app_state.g_search_sel;
    } else if (app_state.g_search_sel >= app_state.g_search_scroll + visible_rows) {
        app_state.g_search_scroll = app_state.g_search_sel + 1 - visible_rows;
    }
    clampSearchSelectionAndScroll();
}

fn appendWorkspaceMovePills() void {
    var mwi: usize = 0;
    while (mwi < app_state.g_lws_count) : (mwi += 1) {
        if (app_state.g_search_result_count >= app_state.g_search_results.len) break;
        if (app_state.g_ws_snoozed[mwi]) continue;
        var name_buf: [32]u8 = undefined;
        const name = workspaceDisplayName(@intCast(mwi), &name_buf);
        if (!labelsMatchQuery(&.{name}, app_state.g_search_buf[0..app_state.g_search_len])) continue;
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WSMOVE_OFFSET + mwi;
        app_state.g_search_result_count += 1;
    }
}

fn preferFirstFilteredResultAfterBack() void {
    if (app_state.g_search_len > 0 and app_state.g_search_result_count > 1) {
        var i: u32 = 2;
        while (i < app_state.g_search_result_count) : (i += 1) {
            const target = app_state.g_search_results[i];
            var j = i;
            while (j > 1 and paletteQueryRank(target) > paletteQueryRank(app_state.g_search_results[j - 1])) : (j -= 1)
                app_state.g_search_results[j] = app_state.g_search_results[j - 1];
            app_state.g_search_results[j] = target;
        }
        app_state.g_search_sel = 1;
        app_state.g_search_scroll = 0;
    }
}

test "workspace destination query selects exact Wazig before partial matches and keeps target identity" {
    const old_count = app_state.g_lws_count;
    const old_names = app_state.g_ws_names;
    const old_lengths = app_state.g_ws_name_len;
    const old_query = app_state.g_search_buf;
    const old_len = app_state.g_search_len;
    const old_results = app_state.g_search_results;
    const old_result_count = app_state.g_search_result_count;
    const old_sel = app_state.g_search_sel;
    const old_scroll = app_state.g_search_scroll;
    defer {
        app_state.g_lws_count = old_count;
        app_state.g_ws_names = old_names;
        app_state.g_ws_name_len = old_lengths;
        app_state.g_search_buf = old_query;
        app_state.g_search_len = old_len;
        app_state.g_search_results = old_results;
        app_state.g_search_result_count = old_result_count;
        app_state.g_search_sel = old_sel;
        app_state.g_search_scroll = old_scroll;
    }
    app_state.g_lws_count = 6;
    for ([_][]const u8{ "Example Product", "Wazig archive", "Old Wazig", "Other", "Wazig", "Wazig notes" }, 0..) |name, i| {
        @memcpy(app_state.g_ws_names[i][0..name.len], name);
        app_state.g_ws_name_len[i] = @intCast(name.len);
    }
    @memcpy(app_state.g_search_buf[0..5], L("wazig")[0..5]);
    app_state.g_search_len = 5;
    app_state.g_search_results[0] = SEARCH_WORKSPACE_BACK_OFFSET;
    app_state.g_search_result_count = 1;
    appendWorkspaceMovePills();
    preferFirstFilteredResultAfterBack();
    try std.testing.expectEqualSlices(usize, &.{ SEARCH_WORKSPACE_BACK_OFFSET, SEARCH_WSMOVE_OFFSET + 4, SEARCH_WSMOVE_OFFSET + 1, SEARCH_WSMOVE_OFFSET + 5, SEARCH_WSMOVE_OFFSET + 2 }, app_state.g_search_results[0..app_state.g_search_result_count]);
    try std.testing.expectEqual(@as(u32, 1), app_state.g_search_sel);
    try std.testing.expectEqual(@as(u32, 0), app_state.g_search_scroll);
    @memcpy(app_state.g_search_buf[0..7], L("missing")[0..7]);
    app_state.g_search_len = 7;
    app_state.g_search_result_count = 1;
    app_state.g_search_sel = 0;
    appendWorkspaceMovePills();
    preferFirstFilteredResultAfterBack();
    try std.testing.expectEqual(@as(u32, 1), app_state.g_search_result_count);
    try std.testing.expectEqual(@as(u32, 0), app_state.g_search_sel);
    app_state.g_search_len = 0;
    appendWorkspaceMovePills();
    app_state.g_search_sel = 4;
    preferFirstFilteredResultAfterBack();
    try std.testing.expectEqual(@as(u32, 7), app_state.g_search_result_count);
    try std.testing.expectEqual(@as(u32, 4), app_state.g_search_sel);
    for (0..6) |i| try std.testing.expectEqual(SEARCH_WSMOVE_OFFSET + i, app_state.g_search_results[i + 1]);
}

fn appendGroupPaletteResults() void {
    for (0..app_state.SEARCH_GROUPCTX_COUNT) |action| {
        if (app_state.g_search_result_count >= app_state.g_search_results.len) break;
        if (!@import("rename.zig").groupPaletteActionAvailable(action)) continue;
        var label: [192]u16 = undefined;
        const len = @import("rename.zig").groupPaletteLabel(action, &label);
        if (app_state.g_search_len > 0 and !u16ContainsInsensitive(label[0..len], app_state.g_search_buf[0..app_state.g_search_len])) continue;
        app_state.g_search_results[app_state.g_search_result_count] = app_state.SEARCH_GROUPCTX_BASE + action;
        app_state.g_search_result_count += 1;
    }
}

pub fn updateSearchResults() void {
    defer {
        if (app_state.g_search_active) {
            var trace: [128]u8 = undefined;
            const target = if (app_state.g_search_sel < app_state.g_search_result_count) app_state.g_search_results[app_state.g_search_sel] else 0;
            @import("diagnostics.zig").debugLog(std.fmt.bufPrint(&trace, "[palette] ready chars={d} count={d} target={d}", .{ app_state.g_search_len, app_state.g_search_result_count, target }) catch "[palette] trace overflow");
        }
    }
    app_state.g_search_result_count = 0;
    if (app_state.g_search_len == 0) app_state.g_multiprompt_logged_in = hasMultipromptLogin();
    if (app_state.g_search_rename_input_mode) {
        app_state.g_search_sel = 0;
        app_state.g_search_scroll = 0;
        return;
    }
    if (app_state.g_browser_url_mode) {
        app_state.g_search_sel = 0;
        app_state.g_search_scroll = 0;
        return;
    }
    if (app_state.g_search_remind_input_mode) {
        app_state.g_search_sel = 0;
        app_state.g_search_scroll = 0;
        return;
    }

    if (app_state.g_search_skills_mode) {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SKILLS_BACK_OFFSET;
        app_state.g_search_result_count += 1;
        const limit = @min(app_state.g_palette_skills.len, MAX_PALETTE_SKILLS);
        for (app_state.g_palette_skills[0..limit], 0..) |skill, si| {
            if (app_state.g_search_result_count >= app_state.g_search_results.len) break;
            if (app_state.g_search_len > 0 and
                !asciiContainsQueryInsensitive(skill.name, app_state.g_search_buf[0..app_state.g_search_len]) and
                !asciiContainsQueryInsensitive(skill.description, app_state.g_search_buf[0..app_state.g_search_len])) continue;
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SKILL_ROW_OFFSET + si;
            app_state.g_search_result_count += 1;
        }
        preferFirstFilteredResultAfterBack();
        if (app_state.g_search_result_count > 0) keepSearchSelectionVisible();
        return;
    }

    if (app_state.g_search_remind_preset_mode) {
        var now_st: SYSTEMTIME = undefined;
        GetLocalTime(&now_st);
        var pi: usize = 0;
        while (pi < REMIND_PRESET_COUNT) : (pi += 1) {
            if (pi == REMIND_PRESET_EVENING and now_st.hour >= 16) continue;
            if (!labelsMatchQuery(&.{remindPresetLabel(pi)}, app_state.g_search_buf[0..app_state.g_search_len])) continue;
            if (app_state.g_search_result_count >= app_state.g_search_results.len) break;
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_REMIND_PRESET_OFFSET + pi;
            app_state.g_search_result_count += 1;
        }
        if (app_state.g_search_len > 0) {
            appendGroupPaletteResults();
            sortSearchResultsByRank();
            app_state.g_search_sel = 0;
            app_state.g_search_scroll = 0;
        }
        if (app_state.g_search_result_count > 0) keepSearchSelectionVisible();
        return;
    }

    if (app_state.g_search_ws_snoozed_mode) {
        loadRemindersIfNeeded();
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WORKSPACE_BACK_OFFSET;
        app_state.g_search_result_count += 1;
        for (0..app_state.g_reminder_count) |ri| {
            const e = &app_state.g_reminders[ri];
            if (!e.workspace_marker or findMyWorkspaceSlot(e.workspace_id[0..e.workspace_id_len]) == null or !reminderMatchesSearch(e, app_state.g_search_buf[0..app_state.g_search_len])) continue;
            if (app_state.g_search_result_count >= app_state.g_search_results.len) break;
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WS_SNOOZED_ROW_OFFSET + ri;
            app_state.g_search_result_count += 1;
        }
        preferFirstFilteredResultAfterBack();
        if (app_state.g_search_result_count > 0) keepSearchSelectionVisible();
        return;
    }

    if (app_state.g_search_reminders_mode) {
        loadRemindersIfNeeded();
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WORKSPACE_BACK_OFFSET;
        app_state.g_search_result_count += 1;
        var ri: u32 = 0;
        while (ri < app_state.g_reminder_count and app_state.g_search_result_count < app_state.g_search_results.len) : (ri += 1) {
            if (app_state.g_reminders[ri].workspace_marker or app_state.g_reminders[ri].batch_due != 0 or !reminderMatchesSearch(&app_state.g_reminders[ri], app_state.g_search_buf[0..app_state.g_search_len])) continue;
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_REMINDER_ROW_OFFSET + ri;
            app_state.g_search_result_count += 1;
        }
        for (0..app_state.g_reminder_count) |marker_ri| {
            if (!app_state.g_reminders[marker_ri].workspace_marker or !reminderMatchesSearch(&app_state.g_reminders[marker_ri], app_state.g_search_buf[0..app_state.g_search_len])) continue;
            if (app_state.g_search_result_count >= app_state.g_search_results.len) break;
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WS_SNOOZED_ROW_OFFSET + marker_ri;
            app_state.g_search_result_count += 1;
        }
        preferFirstFilteredResultAfterBack();
        if (app_state.g_search_result_count > 0) keepSearchSelectionVisible();
        return;
    }

    if (app_state.g_search_session_overview_mode) {
        buildSessionOverviewRows();
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WORKSPACE_BACK_OFFSET;
        app_state.g_search_result_count += 1;
        var ri: u32 = 0;
        while (ri < app_state.g_session_overview_count and ri < @as(u32, MAX_SESSION_OVERVIEW_SEARCH_ROWS) and app_state.g_search_result_count < app_state.g_search_results.len) : (ri += 1) {
            if (!sessionOverviewRowMatches(&app_state.g_session_overview_rows.items[ri], app_state.g_search_buf[0..app_state.g_search_len])) continue;
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SESSION_OVERVIEW_ROW_OFFSET + ri;
            app_state.g_search_result_count += 1;
        }
        preferFirstFilteredResultAfterBack();
        if (app_state.g_search_result_count > 0) keepSearchSelectionVisible();
        return;
    }

    if (app_state.g_search_len > 0 and app_state.g_search_result_count < app_state.g_search_results.len and sessionOverviewCommandMatches(app_state.g_search_buf[0..app_state.g_search_len])) {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SESSION_OVERVIEW_MENU_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_unarchive_hidden = (app_state.g_search_len == 0);
        if (!show_unarchive_hidden) {
            const hidden_labels = [_][]const u8{
                "restore workspace waiting sessions",
                "restore waiting sessions",
                "waiting sessions",
                "Unarchive Hidden (Alt+E) Sessions",
                "unarchive hidden sessions",
                "unarchive hidden",
                "alt e sessions",
                "restore hidden sessions",
                "show hidden sessions",
            };
            for (hidden_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_unarchive_hidden = true;
                    break;
                }
            }
        }
        if (show_unarchive_hidden) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_UNARCHIVE_HIDDEN_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_unarchive_unattached = (app_state.g_search_len == 0);
        if (!show_unarchive_unattached) {
            const unattached_labels = [_][]const u8{
                "unarchive unattached sessions",
                "unarchive unattached",
                "ctrl w sessions",
                "attach workspace sessions",
                "restore unattached sessions",
            };
            for (unattached_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_unarchive_unattached = true;
                    break;
                }
            }
        }
        if (show_unarchive_unattached) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_UNARCHIVE_UNATTACHED_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_archived_view = (app_state.g_search_len == 0);
        if (!show_archived_view) {
            const archived_view_labels = [_][]const u8{ "archived sessions", "archive", "archived", "Unarchive Killed (Alt+X) Sessions", "unarchive killed sessions", "unarchive killed", "killed sessions", "alt x", "dissolve", "dissolved", "resurrect" };
            for (archived_view_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_archived_view = true;
                    break;
                }
            }
        }
        if (show_archived_view) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_ARCHIVED_VIEW_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_snippet_mode) {
        app_state.g_search_result_count = 0;
        loadSnippetsIfChanged();
        if (app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SNIPPET_BACK_OFFSET;
            app_state.g_search_result_count += 1;
        }
        for (0..app_state.g_snippet_count) |si| {
            if (app_state.g_search_result_count >= app_state.g_search_results.len) break;
            if (snippetMatchesQuery(si, app_state.g_search_buf[0..app_state.g_search_len])) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SNIPPET_OFFSET + si;
                app_state.g_search_result_count += 1;
            }
        }
        if (app_state.g_search_result_count < app_state.g_search_results.len and labelsMatchQuery(&[_][]const u8{ "create snippet", "new snippet", "snippet" }, app_state.g_search_buf[0..app_state.g_search_len])) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SNIPPET_CREATE_OFFSET;
            app_state.g_search_result_count += 1;
        }
        preferFirstFilteredResultAfterBack();
        if (app_state.g_search_result_count > 0) keepSearchSelectionVisible();
        return;
    }

    if (app_state.g_search_openall_host_mode) {
        app_state.g_search_result_count = 0;
        buildFilteredTmux();
        const ids = [_]usize{
            SEARCH_OPENALL_HOST_BACK_OFFSET,
            SEARCH_OPENALL_HOST_DE_OFFSET,
            SEARCH_OPENALL_HOST_UK_OFFSET,
            SEARCH_OPENALL_HOST_INNE_OFFSET,
        };
        const labels = [_][]const u8{
            "back",
            "host1 de vps tmux",
            "host2 uk vps tmux",
            "secondary cro vps tmux",
        };
        for (ids, labels) |id, label| {
            if (app_state.g_search_result_count >= app_state.g_search_results.len) break;
            if (id == SEARCH_OPENALL_HOST_BACK_OFFSET or app_state.g_search_len == 0 or asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                app_state.g_search_results[app_state.g_search_result_count] = id;
                app_state.g_search_result_count += 1;
            }
        }
        preferFirstFilteredResultAfterBack();
        if (app_state.g_search_result_count > 0) keepSearchSelectionVisible();
        return;
    }

    if (app_state.g_search_theme_mode) {
        app_state.g_search_result_count = 0;
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_THEME_BACK_OFFSET;
        app_state.g_search_result_count += 1;

        const theme_ids = [_]usize{ SEARCH_THEME_SYSTEM_OFFSET, SEARCH_THEME_DARK_OFFSET, SEARCH_THEME_MID_OFFSET, SEARCH_THEME_LIGHT_OFFSET, SEARCH_THEME_AMOLED_OFFSET, SEARCH_THEME_EDGE_GRAY_OFFSET, SEARCH_THEME_MULTIPROMPT_OFFSET, SEARCH_THEME_DEV_BLUE_OFFSET, SEARCH_THEME_DEV_EDIT_OFFSET, SEARCH_THEME_DEV_RELOAD_OFFSET };
        const theme_labels = [_][]const u8{ "system windows automatic follow appearance light dark", "dark", "mid", "light", "amoled", "edge grey edge gray native edge 333333", "multiprompt midnight violet website landing", "dev blue", "edit dev theme json", "reload dev theme" };
        for (theme_ids, theme_labels) |theme_id, label| {
            if (!IS_DEV and theme_id >= SEARCH_THEME_DEV_BLUE_OFFSET and theme_id != SEARCH_THEME_MULTIPROMPT_OFFSET) continue;
            if (app_state.g_search_result_count >= app_state.g_search_results.len) break;
            if (app_state.g_search_len == 0 or asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                app_state.g_search_results[app_state.g_search_result_count] = theme_id;
                app_state.g_search_result_count += 1;
            }
        }

        preferFirstFilteredResultAfterBack();
        if (app_state.g_search_result_count > 0) keepSearchSelectionVisible();
        return;
    }

    if (app_state.g_search_ws_sort_mode) {
        app_state.g_search_result_count = 0;
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WORKSPACE_BACK_OFFSET;
        app_state.g_search_result_count += 1;
        var wsi: usize = 0;
        while (wsi < app_state.g_lws_count) : (wsi += 1) {
            if (app_state.g_search_result_count >= app_state.g_search_results.len) break;
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WSSORT_OFFSET + wsi;
            app_state.g_search_result_count += 1;
        }
        if (app_state.g_search_result_count > 0) keepSearchSelectionVisible();
        return;
    }

    if (app_state.g_search_ws_move_mode) {
        app_state.g_search_result_count = 0;
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WORKSPACE_BACK_OFFSET;
        app_state.g_search_result_count += 1;
        appendWorkspaceMovePills();
        mergeWorkspaceRegistryFromDisk();
        scanLiveWorkspaceWindows(false);
        for (0..app_state.g_workspace_count) |wi| {
            if (app_state.g_search_result_count >= app_state.g_search_results.len) break;
            if (!workspaceCanMoveIntoClosedStandalone(@intCast(wi))) continue;
            if (!workspaceMatchesSearch(&app_state.g_workspaces[wi], app_state.g_search_buf[0..app_state.g_search_len])) continue;
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WORKSPACE_OFFSET + wi;
            app_state.g_search_result_count += 1;
        }
        if (app_state.g_search_result_count < app_state.g_search_results.len and labelsMatchQuery(&.{"move to new workspace"}, app_state.g_search_buf[0..app_state.g_search_len])) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WSMOVE_NEW_OFFSET;
            app_state.g_search_result_count += 1;
        }
        preferFirstFilteredResultAfterBack();
        if (app_state.g_search_result_count > 0) keepSearchSelectionVisible();
        return;
    }

    if (app_state.g_search_group_move_mode) {
        app_state.g_search_result_count = 0;
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_GROUPMOVE_BACK_OFFSET;
        app_state.g_search_result_count += 1;
        var gi: usize = 0;
        while (gi < app_state.group_count) : (gi += 1) {
            if (app_state.g_search_result_count >= app_state.g_search_results.len) break;
            if (app_state.g_search_len > 0 and !u16ContainsInsensitive(app_state.groups[gi].name[0..app_state.groups[gi].name_len], app_state.g_search_buf[0..app_state.g_search_len])) continue;
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_GROUPMOVE_GROUP_OFFSET + gi;
            app_state.g_search_result_count += 1;
        }
        if (app_state.g_search_result_count < app_state.g_search_results.len and app_state.group_count < MAX_GROUPS and labelsMatchQuery(&.{"new group"}, app_state.g_search_buf[0..app_state.g_search_len])) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_GROUPMOVE_NEW_OFFSET;
            app_state.g_search_result_count += 1;
        }
        if (app_state.g_search_result_count < app_state.g_search_results.len and labelsMatchQuery(&.{"no group"}, app_state.g_search_buf[0..app_state.g_search_len])) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_GROUPMOVE_NONE_OFFSET;
            app_state.g_search_result_count += 1;
        }
        preferFirstFilteredResultAfterBack();
        if (app_state.g_search_result_count > 0) keepSearchSelectionVisible();
        return;
    }

    if (app_state.g_search_groupctx_mode) {
        appendGroupPaletteResults();
        if (app_state.g_search_result_count > 0) keepSearchSelectionVisible();
        return;
    }

    if (app_state.g_search_tabctx_mode) {
        app_state.g_search_result_count = 0;
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_BACK;
        app_state.g_search_result_count += 1;
        const tc_idx = findShellById(app_state.g_tabctx_sid);
        const sel_count = selectedTabCount();
        const sel_mode = sel_count > 0;
        if (tc_idx) |ti| {
            const k = app_state.shells[ti].kind;
            if (k == .vps or k == .vps2 or k == .tmux) {
                if (app_state.g_search_result_count < app_state.g_search_results.len) {
                    const ended = app_state.shells[ti].ssh_reconnect.phase == .ended;
                    const label = if (ended) "Start new session" else "Reconnect";
                    if (app_state.g_search_len == 0 or asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                        if (ended) {
                            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_START_SESSION;
                        } else {
                            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_RECONNECT;
                        }
                        app_state.g_search_result_count += 1;
                    }
                }
            }
        }
        if (app_state.g_search_result_count < app_state.g_search_results.len) {
            const label = if (tc_idx) |ti| (if (app_state.shells[ti].favorite) "Unfavorite" else "Favorite") else "Favorite";
            if (app_state.g_search_len == 0 or labelsMatchQuery(&.{ label, "favorite", "star" }, app_state.g_search_buf[0..app_state.g_search_len])) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_FAVORITE;
                app_state.g_search_result_count += 1;
            }
        }
        if (app_state.g_search_result_count < app_state.g_search_results.len) {
            const tc_muted = if (tc_idx) |ti| app_state.shells[ti].muted else false;
            const mute_str: []const u8 = if (tc_muted) "Unmute Activity" else "Mute Activity";
            if (app_state.g_search_len == 0 or asciiContainsQueryInsensitive(mute_str, app_state.g_search_buf[0..app_state.g_search_len])) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_MUTE;
                app_state.g_search_result_count += 1;
            }
        }
        if (app_state.g_search_result_count < app_state.g_search_results.len) {
            const label = if (tc_idx) |ti| (if (app_state.shells[ti].inbox_excluded) "Inbox: Show This Session Again" else "Inbox: Never Show This Session") else "Inbox: Never Show This Session";
            if (app_state.g_search_len == 0 or labelsMatchQuery(&.{ label, "inbox", "exclude" }, app_state.g_search_buf[0..app_state.g_search_len])) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_INBOX_EXCLUDE;
                app_state.g_search_result_count += 1;
            }
        }
        if (app_state.g_search_result_count < app_state.g_search_results.len) {
            const tc_pinned = if (tc_idx) |ti| app_state.shells[ti].pinned_top else false;
            const pin_str: []const u8 = if (tc_pinned) "Unpin from Top" else "Pin to Top";
            if (app_state.g_search_len == 0 or labelsMatchQuery(&[_][]const u8{ pin_str, "pin", "pinned", "unpin", "top", "sidebar top" }, app_state.g_search_buf[0..app_state.g_search_len])) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_PIN_TOP;
                app_state.g_search_result_count += 1;
            }
        }
        if (app_state.g_search_result_count < app_state.g_search_results.len) {
            const tc_locked = if (tc_idx) |ti| app_state.shells[ti].locked else false;
            const lock_str: []const u8 = if (tc_locked) "Unlock Session" else "Lock Session";
            if (app_state.g_search_len == 0 or labelsMatchQuery(&[_][]const u8{ lock_str, "lock", "locked", "unlock", "protect", "prevent close" }, app_state.g_search_buf[0..app_state.g_search_len])) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_LOCK;
                app_state.g_search_result_count += 1;
            }
        }
        if (app_state.g_search_result_count < app_state.g_search_results.len) {
            const tc_kaw = if (tc_idx) |ti| app_state.shells[ti].keep_awake else false;
            const kaw_str: []const u8 = if (tc_kaw) "Let Browser Pane Hibernate" else "Keep Tab Awake";
            if (app_state.g_search_len == 0 or labelsMatchQuery(&[_][]const u8{ kaw_str, "awake", "keep awake", "pin", "hibernate", "freeze", "wake" }, app_state.g_search_buf[0..app_state.g_search_len])) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_KEEPAWAKE;
                app_state.g_search_result_count += 1;
            }
        }
        if (tc_idx) |ti| {
            const k = app_state.shells[ti].kind;
            if (k == .cmd or k == .pwsh) {
                if (app_state.g_search_result_count < app_state.g_search_results.len) {
                    const ka_str: []const u8 = if (app_state.shells[ti].keep_alive) "Don't Keep Alive" else "Keep Alive on Exit";
                    if (app_state.g_search_len == 0 or asciiContainsQueryInsensitive(ka_str, app_state.g_search_buf[0..app_state.g_search_len])) {
                        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_KEEPALIVE;
                        app_state.g_search_result_count += 1;
                    }
                }
            }
        }
        if (tc_idx) |ti| {
            if (app_state.g_search_result_count < app_state.g_search_results.len) {
                const action_labels: []const []const u8 = if (app_state.shells[ti].tmux_session_len > 0)
                    &[_][]const u8{ "Archive Session", "archive", "archived", "dissolve", "dissolved" }
                else
                    &[_][]const u8{ "Close Session", "close session", "close tab", "close", "kill session", "end session" };
                if (app_state.g_search_len == 0 or labelsMatchQuery(action_labels, app_state.g_search_buf[0..app_state.g_search_len])) {
                    app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_ARCHIVE;
                    app_state.g_search_result_count += 1;
                }
            }
            if (app_state.shells[ti].tmux_session_len > 0) {
                if (app_state.g_search_result_count < app_state.g_search_results.len) {
                    const end_labels = [_][]const u8{ "End tmux session", "End tmux", "Kill tmux", "Close tmux", "End session", "multiprompt-browser", "zsb" };
                    var show_end = (app_state.g_search_len == 0);
                    if (!show_end) {
                        for (end_labels) |label| {
                            if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                                show_end = true;
                                break;
                            }
                        }
                    }
                    if (show_end) {
                        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_END_TMUX;
                        app_state.g_search_result_count += 1;
                    }
                }
            }
        }
        if (tc_idx != null and app_state.g_search_result_count < app_state.g_search_results.len) {
            const browser_labels = [_][]const u8{ "browser", "web", "pane", "show browser", "hide browser" };
            var show_browser = (app_state.g_search_len == 0);
            if (!show_browser) {
                for (browser_labels) |label| {
                    if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                        show_browser = true;
                        break;
                    }
                }
            }
            if (show_browser) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_BROWSER;
                app_state.g_search_result_count += 1;
            }
        }
        if (tc_idx != null and app_state.g_search_result_count < app_state.g_search_results.len and
            (app_state.g_search_len == 0 or labelsMatchQuery(&.{ "Chat View: Insert browser tab URL", "link", "ctrl shift x" }, app_state.g_search_buf[0..app_state.g_search_len])))
        {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_CHAT_TAB_URL;
            app_state.g_search_result_count += 1;
        }
        if (tc_idx != null and app_state.g_search_result_count < app_state.g_search_results.len and
            (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("Chat View: Reset this chat", app_state.g_search_buf[0..app_state.g_search_len])))
        {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_CHAT_RESET;
            app_state.g_search_result_count += 1;
        }
        if (tc_idx != null and app_state.g_search_result_count < app_state.g_search_results.len and
            (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("Chat View: Allow", app_state.g_search_buf[0..app_state.g_search_len])))
        {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_CHAT_ALLOW;
            app_state.g_search_result_count += 1;
        }
        if (tc_idx != null and app_state.g_search_result_count < app_state.g_search_results.len and
            (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("Chat View: Always allow", app_state.g_search_buf[0..app_state.g_search_len])))
        {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_CHAT_ALWAYS;
            app_state.g_search_result_count += 1;
        }
        if (tc_idx != null and app_state.g_search_result_count < app_state.g_search_results.len and
            (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("Chat View: Deny", app_state.g_search_buf[0..app_state.g_search_len])))
        {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_CHAT_DENY;
            app_state.g_search_result_count += 1;
        }
        if (app_state.ISSUE_265_WORKING_BAR and tc_idx != null and app_state.g_search_result_count < app_state.g_search_results.len and
            (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("Chat View: Stop the agent", app_state.g_search_buf[0..app_state.g_search_len])))
        {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_CHAT_STOP;
            app_state.g_search_result_count += 1;
        }
        if (app_state.g_single_window and (app_state.g_lws_count > 1 or hasClosedWorkspaceMoveDestinations())) {
            if (app_state.g_search_result_count < app_state.g_search_results.len) {
                if (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("Move to Workspace", app_state.g_search_buf[0..app_state.g_search_len])) {
                    app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_WSMOVE;
                    app_state.g_search_result_count += 1;
                }
            }
        }
        const tc_grouped = if (tc_idx) |ti| (app_state.shells[ti].group_id != 0) else false;
        if (sel_mode) {
            if (app_state.group_count < MAX_GROUPS) {
                if (app_state.g_search_result_count < app_state.g_search_results.len) {
                    if (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("Add selected tabs to new group", app_state.g_search_buf[0..app_state.g_search_len])) {
                        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_GROUP_NEW;
                        app_state.g_search_result_count += 1;
                    }
                }
            }
            if (selectedTabsIncludeGrouped()) {
                if (app_state.g_search_result_count < app_state.g_search_results.len) {
                    if (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("Remove selected tabs from groups", app_state.g_search_buf[0..app_state.g_search_len])) {
                        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_GROUP_REMOVE;
                        app_state.g_search_result_count += 1;
                    }
                }
            }
            for (0..app_state.group_count) |gi| {
                if (app_state.g_search_result_count >= app_state.g_search_results.len) break;
                var glbuf: [72]u8 = undefined;
                var gli: usize = 0;
                for ("Add selected to group: ") |c| {
                    if (gli >= glbuf.len) break;
                    glbuf[gli] = c;
                    gli += 1;
                }
                for (0..app_state.groups[gi].name_len) |j| {
                    if (gli >= glbuf.len - 1) break;
                    glbuf[gli] = @intCast(app_state.groups[gi].name[j] & 0x7F);
                    gli += 1;
                }
                if (app_state.g_search_len == 0 or asciiContainsQueryInsensitive(glbuf[0..gli], app_state.g_search_buf[0..app_state.g_search_len])) {
                    app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_GROUP_ADD_OFFSET + gi;
                    app_state.g_search_result_count += 1;
                }
            }
            if (app_state.g_search_result_count < app_state.g_search_results.len) {
                if (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("Move selected tabs to new workspace", app_state.g_search_buf[0..app_state.g_search_len])) {
                    app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_MOVE_NEW_WS;
                    app_state.g_search_result_count += 1;
                }
            }
            if (app_state.g_search_result_count < app_state.g_search_results.len) {
                if (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("Clear tab selection", app_state.g_search_buf[0..app_state.g_search_len])) {
                    app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_CLEAR_SEL;
                    app_state.g_search_result_count += 1;
                }
            }
        } else if (tc_grouped) {
            if (app_state.g_search_result_count < app_state.g_search_results.len) {
                if (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("New tab in group", app_state.g_search_buf[0..app_state.g_search_len])) {
                    app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_GROUP_NEW_TAB_IN;
                    app_state.g_search_result_count += 1;
                }
            }
            if (app_state.g_search_result_count < app_state.g_search_results.len) {
                if (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("Remove from group", app_state.g_search_buf[0..app_state.g_search_len])) {
                    app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_GROUP_REMOVE;
                    app_state.g_search_result_count += 1;
                }
            }
            if (app_state.g_search_result_count < app_state.g_search_results.len) {
                if (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("Move tab to new workspace", app_state.g_search_buf[0..app_state.g_search_len])) {
                    app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_MOVE_NEW_WS;
                    app_state.g_search_result_count += 1;
                }
            }
        } else {
            if (app_state.group_count < MAX_GROUPS) {
                if (app_state.g_search_result_count < app_state.g_search_results.len) {
                    if (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("Add to new group", app_state.g_search_buf[0..app_state.g_search_len])) {
                        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_GROUP_NEW;
                        app_state.g_search_result_count += 1;
                    }
                }
            }
            for (0..app_state.group_count) |gi| {
                if (app_state.g_search_result_count >= app_state.g_search_results.len) break;
                var glbuf: [72]u8 = undefined;
                var gli: usize = 0;
                for ("Add to group: ") |c| {
                    if (gli >= glbuf.len) break;
                    glbuf[gli] = c;
                    gli += 1;
                }
                for (0..app_state.groups[gi].name_len) |j| {
                    if (gli >= glbuf.len - 1) break;
                    glbuf[gli] = @intCast(app_state.groups[gi].name[j] & 0x7F);
                    gli += 1;
                }
                if (app_state.g_search_len == 0 or asciiContainsQueryInsensitive(glbuf[0..gli], app_state.g_search_buf[0..app_state.g_search_len])) {
                    app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_GROUP_ADD_OFFSET + gi;
                    app_state.g_search_result_count += 1;
                }
            }
            if (app_state.g_search_result_count < app_state.g_search_results.len) {
                if (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("Move tab to new workspace", app_state.g_search_buf[0..app_state.g_search_len])) {
                    app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_MOVE_NEW_WS;
                    app_state.g_search_result_count += 1;
                }
            }
            if (sel_count > 0 and app_state.g_search_result_count < app_state.g_search_results.len) {
                if (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("Clear tab selection", app_state.g_search_buf[0..app_state.g_search_len])) {
                    app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_CLEAR_SEL;
                    app_state.g_search_result_count += 1;
                }
            }
        }
        preferFirstFilteredResultAfterBack();
        if (app_state.g_search_result_count > 0) keepSearchSelectionVisible();
        return;
    }

    if (app_state.g_search_workspace_mode) {
        app_state.g_search_result_count = 0;
        mergeWorkspaceRegistryFromDisk();
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WORKSPACE_BACK_OFFSET;
        app_state.g_search_result_count += 1;

        for (0..app_state.g_workspace_count) |wi| {
            if (app_state.g_search_result_count >= app_state.g_search_results.len) break;
            const e = &app_state.g_workspaces[wi];
            if (findMyWorkspaceSlot(e.id[0..e.id_len])) |slot| {
                if (app_state.g_ws_snoozed[slot]) continue;
            }
            if (app_state.g_search_workspace_delete_mode and !workspaceCanDelete(@intCast(wi))) continue;
            if (app_state.g_search_len == 0 or workspaceMatchesSearch(e, app_state.g_search_buf[0..app_state.g_search_len])) {
                app_state.g_search_results[app_state.g_search_result_count] = if (app_state.g_search_workspace_delete_mode)
                    SEARCH_WORKSPACE_DELETE_OFFSET + wi
                else
                    SEARCH_WORKSPACE_OFFSET + wi;
                app_state.g_search_result_count += 1;
            }
        }

        preferFirstFilteredResultAfterBack();
        if (app_state.g_search_result_count > 0) keepSearchSelectionVisible();
        return;
    }

    if (app_state.g_nextunread_count > 0 and app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_nu = (app_state.g_search_len == 0);
        if (!show_nu) {
            const nu_labels = [_][]const u8{ "unread", "next", "inbox" };
            for (nu_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_nu = true;
                    break;
                }
            }
        }
        if (show_nu) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_NEXTUNREAD_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    const new_kw = [NUM_BUTTONS][]const u8{
        "new cmd shell add session local",
        "attach tmux host1 de session list pick",
        "attach tmux host2 uk session list pick",
        "new vps host1 de ssh session add shell",
        "new vps host2 uk ssh session add shell",
        "new powershell pwsh shell add session",
        "new bash shell add session",
        "new git bash mintty shell add session",
    };
    for (0..NUM_BUTTONS) |ki| {
        if (app_state.g_search_result_count >= app_state.g_search_results.len) break;
        if (app_state.g_search_len == 0) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_NEW_OFFSET + ki;
            app_state.g_search_result_count += 1;
        } else {
            const query = app_state.g_search_buf[0..app_state.g_search_len];
            const kw = new_kw[ki];
            var all_match = true;
            var wstart: usize = 0;
            var qp: usize = 0;
            while (qp <= query.len) : (qp += 1) {
                const at_end = (qp == query.len);
                if (at_end or query[qp] == ' ') {
                    if (qp > wstart) {
                        const wlen = qp - wstart;
                        var found = false;
                        if (wlen <= kw.len) {
                            var ksi: usize = 0;
                            while (ksi + wlen <= kw.len) : (ksi += 1) {
                                var ok = true;
                                for (0..wlen) |j| {
                                    const qc = u16ToLower(query[wstart + j]);
                                    const kc = kw[ksi + j];
                                    const lc: u16 = if (kc >= 'A' and kc <= 'Z') kc + 32 else kc;
                                    if (qc != lc) {
                                        ok = false;
                                        break;
                                    }
                                }
                                if (ok) {
                                    found = true;
                                    break;
                                }
                            }
                        }
                        if (!found) {
                            all_match = false;
                            break;
                        }
                    }
                    wstart = qp + 1;
                }
            }
            if (all_match) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_NEW_OFFSET + ki;
                app_state.g_search_result_count += 1;
            }
        }
    }

    {
        var host: u8 = 0;
        var cwd_buf: [256]u8 = undefined;
        var cwd_len: u32 = 0;
        if (activeRemoteContextForCodexTmux(&host, &cwd_buf, &cwd_len) and app_state.g_search_result_count < app_state.g_search_results.len) {
            var show_codex_tmux = (app_state.g_search_len == 0);
            if (!show_codex_tmux) {
                const codex_labels = [_][]const u8{ "new codex tmux session", "new codex session", "new codec session", "new codecs session", "codex", "codec", "codecs", "openai codex", "ai agent" };
                for (codex_labels) |label| {
                    if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                        show_codex_tmux = true;
                        break;
                    }
                }
            }
            if (show_codex_tmux) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CODEX_TMUX_OFFSET;
                app_state.g_search_result_count += 1;
            }
        }
    }

    var show_sound_toggle = (app_state.g_search_len == 0);
    if (!show_sound_toggle) {
        const sound_labels = [_][]const u8{ "notification sounds", "notification sound", "notifications", "notify", "sound", "sounds", "audio", "alert", "beep", "silent", "quiet" };
        for (sound_labels) |label| {
            if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                show_sound_toggle = true;
                break;
            }
        }
    }
    if (show_sound_toggle and app_state.g_search_result_count < app_state.g_search_results.len) {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SOUND_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.active_shell < app_state.shell_count and faviconHostForShell(&app_state.shells[app_state.active_shell]) != null) {
        var show_af = (app_state.g_search_len == 0);
        if (!show_af) {
            const af_labels = [_][]const u8{ "favicon", "add favicon", "icon" };
            for (af_labels) |label| {
                const qaf = app_state.g_search_buf[0..app_state.g_search_len];
                if (qaf.len <= label.len) {
                    var okf = true;
                    for (0..qaf.len) |j| {
                        const qcf = u16ToLower(qaf[j]);
                        const lcf: u16 = label[j];
                        if (qcf != lcf) {
                            okf = false;
                            break;
                        }
                    }
                    if (okf) {
                        show_af = true;
                        break;
                    }
                }
            }
        }
        if (show_af and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_ADDFAVICON_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_len == 0) {
        if (app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_MOBILE_OFFSET;
            app_state.g_search_result_count += 1;
        }
    } else {
        const mob_label = "mobile";
        const querym = app_state.g_search_buf[0..app_state.g_search_len];
        if (querym.len <= mob_label.len) {
            var okm = true;
            for (0..querym.len) |j| {
                const qcm = u16ToLower(querym[j]);
                const lcm: u16 = mob_label[j];
                if (qcm != lcm) {
                    okm = false;
                    break;
                }
            }
            if (okm and app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_MOBILE_OFFSET;
                app_state.g_search_result_count += 1;
            }
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_themes = (app_state.g_search_len == 0);
        if (!show_themes) {
            const theme_labels = [_][]const u8{ "theme", "themes", "dark", "mid", "light", "edge", "edge grey", "edge gray", "333333", "native edge", "blue", "dev blue", "edit theme", "reload theme" };
            for (theme_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_themes = true;
                    break;
                }
            }
        }
        if (show_themes) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_THEME_MENU_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_create_workspace = (app_state.g_search_len == 0);
        if (!show_create_workspace) {
            const create_workspace_labels = [_][]const u8{ "create", "create workspace", "new workspace", "empty workspace", "blank workspace" };
            for (create_workspace_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_create_workspace = true;
                    break;
                }
            }
        }
        if (show_create_workspace) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CREATEWS_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_open_workspace = (app_state.g_search_len == 0);
        if (!show_open_workspace) {
            const open_workspace_labels = [_][]const u8{ "open", "open workspace", "workspace", "workspaces", "past workspaces", "history", "window", "windows" };
            for (open_workspace_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_open_workspace = true;
                    break;
                }
            }
        }
        if (show_open_workspace) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WORKSPACES_MENU_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_len > 0) {
        for (0..app_state.g_workspace_count) |wi| {
            if (app_state.g_search_result_count >= app_state.g_search_results.len) break;
            const e = &app_state.g_workspaces[wi];
            if (findMyWorkspaceSlot(e.id[0..e.id_len])) |slot| {
                if (app_state.g_ws_snoozed[slot]) continue;
            }
            if (workspaceMatchesSearch(e, app_state.g_search_buf[0..app_state.g_search_len])) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WORKSPACE_OFFSET + wi;
                app_state.g_search_result_count += 1;
            }
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_delete_workspace = (app_state.g_search_len == 0);
        if (!show_delete_workspace) {
            const delete_workspace_labels = [_][]const u8{ "delete", "delete workspace", "remove workspace", "old workspace", "cleanup workspace" };
            for (delete_workspace_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_delete_workspace = true;
                    break;
                }
            }
        }
        if (show_delete_workspace) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WORKSPACE_DELETE_MENU_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_rename_workspace = (app_state.g_search_len == 0);
        if (!show_rename_workspace) {
            const rename_workspace_labels = [_][]const u8{ "rename", "rename workspace", "rename current", "rename window", "current workspace", "window name" };
            for (rename_workspace_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_rename_workspace = true;
                    break;
                }
            }
        }
        if (show_rename_workspace) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_RENAMEWIN_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_quit = (app_state.g_search_len == 0);
        if (!show_quit) {
            const quit_labels = [_][]const u8{ "quit", "quit multiprompt", "quit zigshell", "exit", "shutdown", "close all", "restore workspaces" };
            for (quit_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_quit = true;
                    break;
                }
            }
        }
        if (show_quit) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_QUIT_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_restart = (app_state.g_search_len == 0);
        if (!show_restart) {
            const restart_labels = [_][]const u8{ "restart", "relaunch", "reboot", "restart app", "reload app", "restart multiprompt", "restart zigshell" };
            for (restart_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_restart = true;
                    break;
                }
            }
        }
        if (show_restart) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_RESTART_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_update = app_state.g_update_ver_len > 0 and app_state.g_search_len == 0;
        if (!show_update and app_state.g_search_len > 0) {
            const update_labels = [_][]const u8{ "update", "restart to update", "relaunch", "new version", "upgrade" };
            for (update_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_update = true;
                    break;
                }
            }
        }
        if (show_update) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_UPDATE_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len and app_state.shell_count > 0) {
        var show_fullwidth = (app_state.g_search_len == 0);
        if (!show_fullwidth) {
            const fullwidth_labels = [_][]const u8{ "full", "full width", "fullwidth", "fullscreen", "full screen", "wide", "width", "maximize" };
            for (fullwidth_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_fullwidth = true;
                    break;
                }
            }
        }
        if (show_fullwidth) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_FULLWIDTH_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_shortcuts = (app_state.g_search_len == 0);
        if (!show_shortcuts) {
            const shortcuts_labels = [_][]const u8{ "shortcut", "shortcuts", "keyboard shortcuts", "keys", "hotkeys", "keybindings", "help", "cheatsheet" };
            for (shortcuts_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_shortcuts = true;
                    break;
                }
            }
        }
        if (show_shortcuts) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SHORTCUTS_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_changelog = (app_state.g_search_len == 0);
        if (!show_changelog) {
            const changelog_labels = [_][]const u8{ "changelog", "version", "whatsnew", "updates", "release", "changes" };
            for (changelog_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_changelog = true;
                    break;
                }
            }
        }
        if (show_changelog) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHANGELOG_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len and
        labelsMatchQuery(&[_][]const u8{
            "reconnect ai usage accounts",
            "login ai usage",
            "fix stale telemetry",
            "claude telemetry login",
            "refresh claude login",
            "usage account login",
            "reconnect claude primary",
            "owner@example.com",
            "primary claude account",
        }, app_state.g_search_buf[0..app_state.g_search_len]))
    {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_USAGE_LOGIN_PRIMARY_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if ((app_state.g_account_locked or app_state.g_account_reauth) and app_state.g_search_result_count < app_state.g_search_results.len and
        labelsMatchQuery(&[_][]const u8{
            "sign in to multiprompt",
            "multiprompt login",
            "desktop sync login",
            "reconnect multiprompt",
            "account sync",
            "oidc pkce",
        }, app_state.g_search_buf[0..app_state.g_search_len]))
    {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_MULTIPROMPT_LOGIN_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len and
        labelsMatchQuery(&[_][]const u8{
            "account: sign out",
            "sign out of multiprompt",
            "multiprompt sign out",
            "desktop sync sign out",
            "forget multiprompt account",
        }, app_state.g_search_buf[0..app_state.g_search_len]))
    {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SYNC_SIGNOUT_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len and
        labelsMatchQuery(&[_][]const u8{
            "account: devices",
            "sync status",
            "am i signed in to multiprompt",
            "vault status",
        }, app_state.g_search_buf[0..app_state.g_search_len]))
    {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SYNC_STATUS_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len and
        labelsMatchQuery(&[_][]const u8{ "account: approve devices", "approve device", "server access", "device keys" }, app_state.g_search_buf[0..app_state.g_search_len]))
    {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_APPROVE_DEVICES_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len and
        labelsMatchQuery(&[_][]const u8{ "sync: pull now", "sync layout", "server layout", "host1 layout" }, app_state.g_search_buf[0..app_state.g_search_len]))
    {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_LAYOUT_PULL_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.g_chat_active and !app_state.g_inbox_active and !app_state.g_all_sessions_active and app_state.g_search_result_count < app_state.g_search_results.len and
        labelsMatchQuery(&[_][]const u8{ "Chat View: Reply to latest agent message", "quote reply" }, app_state.g_search_buf[0..app_state.g_search_len]))
    {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_REPLY_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.ISSUE_268_CHAT_FIND and app_state.g_chat_active and !app_state.g_inbox_active and !app_state.g_all_sessions_active and app_state.g_search_result_count < app_state.g_search_results.len and
        labelsMatchQuery(&[_][]const u8{ "Chat View: Find in conversation", "ctrl f", "search whole conversation" }, app_state.g_search_buf[0..app_state.g_search_len]))
    {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_FIND_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.g_chat_active and !app_state.g_inbox_active and !app_state.g_all_sessions_active and app_state.g_search_result_count < app_state.g_search_results.len and
        labelsMatchQuery(&[_][]const u8{ "chat view open or fold all tool steps", "expand collapse tools" }, app_state.g_search_buf[0..app_state.g_search_len]))
    {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_TOOL_STEPS_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.g_chat_active and !app_state.g_inbox_active and !app_state.g_all_sessions_active and app_state.g_search_result_count < app_state.g_search_results.len and
        labelsMatchQuery(&[_][]const u8{ "Chat View: Toggle todo list", "todos tasks plan progress" }, app_state.g_search_buf[0..app_state.g_search_len]))
    {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_TODO_OFFSET;
        app_state.g_search_result_count += 1;
    }
    if (app_state.g_chat_active and !app_state.g_inbox_active and !app_state.g_all_sessions_active and app_state.g_search_result_count < app_state.g_search_results.len and
        labelsMatchQuery(&[_][]const u8{ "chat view copy latest code block", "copy code", "ctrl shift d" }, app_state.g_search_buf[0..app_state.g_search_len]))
    {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_COPY_CODE_OFFSET;
        app_state.g_search_result_count += 1;
    }
    if (app_state.g_chat_active and !app_state.g_inbox_active and !app_state.g_all_sessions_active and app_state.g_search_result_count < app_state.g_search_results.len and
        labelsMatchQuery(&[_][]const u8{ "Chat View: Attach File", "attach file", "pdf", "zip", "log", "document", "image", "upload image", "add image", "picture", "photo", "screenshot", "ctrl v", "drop", "drag" }, app_state.g_search_buf[0..app_state.g_search_len]))
    {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_ATTACH_OFFSET;
        app_state.g_search_result_count += 1;
    }
    if (app_state.g_chat_active and !app_state.g_inbox_active and !app_state.g_all_sessions_active and app_state.g_search_result_count < app_state.g_search_results.len) {
        if (labelsMatchQuery(&[_][]const u8{ "chat view copy selection", "copy selection", "copy text", "ctrl c" }, app_state.g_search_buf[0..app_state.g_search_len])) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_COPY_SELECTION_OFFSET;
            app_state.g_search_result_count += 1;
        }
        if (app_state.g_search_result_count < app_state.g_search_results.len and
            labelsMatchQuery(&[_][]const u8{ "chat view select all", "select all text", "ctrl a" }, app_state.g_search_buf[0..app_state.g_search_len]))
        {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_SELECT_ALL_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }
    if (app_state.g_search_result_count < app_state.g_search_results.len and
        labelsMatchQuery(&[_][]const u8{ "chat view insert command or skill", "browse commands", "browse skills", "ctrl slash", "autocomplete" }, app_state.g_search_buf[0..app_state.g_search_len]))
    {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_AC_OFFSET;
        app_state.g_search_result_count += 1;
    }
    if (app_state.g_search_result_count < app_state.g_search_results.len and
        labelsMatchQuery(&[_][]const u8{
            "skills",
            "use skill",
            "chat view skills",
            "coding harness skills",
        }, app_state.g_search_buf[0..app_state.g_search_len]))
    {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SKILLS_MENU_OFFSET;
        app_state.g_search_result_count += 1;
    }
    if (app_state.g_search_result_count < app_state.g_search_results.len and
        labelsMatchQuery(&[_][]const u8{
            "reconnect ai usage accounts",
            "login ai usage",
            "fix stale telemetry",
            "claude telemetry login",
            "refresh claude login",
            "usage account login",
            "reconnect claude secondary",
            "secondary@example.com",
            "second claude account",
        }, app_state.g_search_buf[0..app_state.g_search_len]))
    {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_USAGE_LOGIN_INNE_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_closewin = (app_state.g_search_len == 0);
        if (!show_closewin) {
            const closewin_labels = [_][]const u8{ "close", "close window", "close workspace", "close this window", "close this workspace" };
            for (closewin_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_closewin = true;
                    break;
                }
            }
        }
        if (show_closewin) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CLOSEWIN_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len and app_state.active_shell < app_state.shell_count and
        (app_state.shells[app_state.active_shell].kind == .vps or app_state.shells[app_state.active_shell].kind == .vps2 or app_state.shells[app_state.active_shell].kind == .tmux))
    {
        var show_reconnect = (app_state.g_search_len == 0);
        if (!show_reconnect) {
            const reconnect_labels = [_][]const u8{ "reconnect", "reconnect tab", "reattach", "reconnect ssh", "reconnect tmux", "fix black" };
            for (reconnect_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_reconnect = true;
                    break;
                }
            }
        }
        if (app_state.shells[app_state.active_shell].ssh_reconnect.phase == .ended) {
            if (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("Start new session", app_state.g_search_buf[0..app_state.g_search_len])) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABCTX_START_SESSION;
                app_state.g_search_result_count += 1;
            }
        } else if (show_reconnect) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_RECONNECT_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_singlewin = (app_state.g_search_len == 0);
        if (!show_singlewin) {
            const singlewin_labels = [_][]const u8{ "single window", "single-window", "multi window", "multi-window", "window mode", "workspace mode", "single", "mode", "one window" };
            for (singlewin_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_singlewin = true;
                    break;
                }
            }
        }
        if (show_singlewin) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SINGLEWIN_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_installhook = (app_state.g_search_len == 0);
        if (!show_installhook) {
            const installhook_labels = [_][]const u8{ "blue dot", "hook", "install hook", "blue dot hook", "notify", "notification", "notifications", "ping", "attention" };
            for (installhook_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_installhook = true;
                    break;
                }
            }
        }
        if (show_installhook) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_INSTALLHOOK_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_single_window and app_state.g_search_result_count < app_state.g_search_results.len and
        labelsMatchQuery(&.{ "Go to Starred workspace", "favorites", "alt 1" }, app_state.g_search_buf[0..app_state.g_search_len]))
    {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_STARRED_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_goinbox = (app_state.g_search_len == 0);
        if (!show_goinbox) {
            const goinbox_labels = [_][]const u8{ "inbox", "go to inbox", "goto inbox", "open inbox", "triage", "unread", "messages" };
            for (goinbox_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_goinbox = true;
                    break;
                }
            }
        }
        if (show_goinbox) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_GOINBOX_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len and labelsMatchQuery(&[_][]const u8{"show frequent split"}, app_state.g_search_buf[0..app_state.g_search_len])) {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SHOW_FREQUENT_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len and labelsMatchQuery(&[_][]const u8{"frequent as first tab"}, app_state.g_search_buf[0..app_state.g_search_len])) {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_FREQUENT_FIRST_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len and labelsMatchQuery(&[_][]const u8{"show favorites split"}, app_state.g_search_buf[0..app_state.g_search_len])) {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SHOW_FAVORITES_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len and labelsMatchQuery(&[_][]const u8{"show all split"}, app_state.g_search_buf[0..app_state.g_search_len])) {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SHOW_ALL_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len and labelsMatchQuery(&[_][]const u8{ "inbox: frequent", "frequent", "input today", "24 hours", "watch-only", "six hours" }, app_state.g_search_buf[0..app_state.g_search_len])) {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_INBOX_FREQUENT_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len and labelsMatchQuery(&[_][]const u8{ "use snippets", "snippets", "snippet", "paste snippet" }, app_state.g_search_buf[0..app_state.g_search_len])) {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SNIPPETS_MENU_OFFSET;
        app_state.g_search_result_count += 1;
    }
    if (app_state.g_search_result_count < app_state.g_search_results.len and labelsMatchQuery(&[_][]const u8{ "create snippet", "new snippet", "snippet" }, app_state.g_search_buf[0..app_state.g_search_len])) {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SNIPPET_CREATE_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.g_single_window and app_state.g_lws_count > 1 and app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_wssort = (app_state.g_search_len == 0);
        if (!show_wssort) {
            const wssort_labels = [_][]const u8{ "sort", "sort workspaces", "order", "reorder", "arrange", "move workspace" };
            for (wssort_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_wssort = true;
                    break;
                }
            }
        }
        if (show_wssort) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WSSORT_MENU_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_single_window and app_state.active_shell < app_state.shell_count and (app_state.g_lws_count > 1 or hasClosedWorkspaceMoveDestinations()) and app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_wsmove = (app_state.g_search_len == 0);
        if (!show_wsmove) {
            const wsmove_labels = [_][]const u8{ "move", "move to workspace", "transfer", "workspace" };
            for (wsmove_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_wsmove = true;
                    break;
                }
            }
        }
        if (show_wsmove) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WSMOVE_MENU_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.active_shell < app_state.shell_count and app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_groupmove = (app_state.g_search_len == 0);
        if (!show_groupmove) {
            const groupmove_labels = [_][]const u8{ "move", "move to group", "group", "organize session" };
            for (groupmove_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_groupmove = true;
                    break;
                }
            }
        }
        if (show_groupmove) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_GROUPMOVE_MENU_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    {
        var show_expand = (app_state.g_search_len == 0);
        var show_collapse = (app_state.g_search_len == 0);
        var show_hide_sb = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const expand_labels = [_][]const u8{ "sidebar", "sidebar expand", "expand", "show sidebar", "open sidebar" };
            const collapse_labels = [_][]const u8{ "sidebar", "sidebar collapse", "collapse", "narrow" };
            const hide_labels = [_][]const u8{ "sidebar", "sidebar hide", "hide sidebar", "focus", "zen", "hide" };
            for (expand_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_expand = true;
                    break;
                }
            }
            for (collapse_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_collapse = true;
                    break;
                }
            }
            for (hide_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_hide_sb = true;
                    break;
                }
            }
        }
        if (show_expand and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_HIDESIDEBAR_OFFSET;
            app_state.g_search_result_count += 1;
        }
        if (show_collapse and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SIDEBAR_COLLAPSE_OFFSET;
            app_state.g_search_result_count += 1;
        }
        if (show_hide_sb and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SIDEBAR_HIDE_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_single_window and app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_hpills = (app_state.g_search_len == 0);
        if (!show_hpills) {
            const hpills_labels = [_][]const u8{ "pills", "workspace switcher", "switcher", "hide pills", "show pills", "hide switcher", "show switcher", "ux" };
            for (hpills_labels) |label| {
                if (asciiContainsQueryInsensitive(label, app_state.g_search_buf[0..app_state.g_search_len])) {
                    show_hpills = true;
                    break;
                }
            }
        }
        if (show_hpills) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_HIDEPILLS_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    {
        var show_ts_inbox = (app_state.g_search_len == 0);
        var show_ts_manual = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const tab_sort_labels = [_][]const u8{ "tab order", "sort tabs", "sort", "order", "tabs", "inbox", "manual", "auto sort", "auto" };
            for (tab_sort_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_ts_inbox = true;
                    show_ts_manual = true;
                    break;
                }
            }
        }
        if (show_ts_inbox and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABSORT_INBOX_OFFSET;
            app_state.g_search_result_count += 1;
        }
        if (show_ts_manual and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TABSORT_MANUAL_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    {
        var show_power = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const power_labels = [_][]const u8{ "power saver", "power", "saver", "battery", "energy saver", "idle" };
            for (power_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_power = true;
                    break;
                }
            }
        }
        if (show_power) {
            if (app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_POWER_AUTO_OFFSET;
                app_state.g_search_result_count += 1;
            }
            if (app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_POWER_ALWAYS_OFFSET;
                app_state.g_search_result_count += 1;
            }
            if (app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_POWER_OFF_OFFSET;
                app_state.g_search_result_count += 1;
            }
        }
    }

    {
        var show_ladder = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            for ([_][]const u8{ "token ladder", "ladder", "burn", "claude", "codex", "subscription", "plan", "usage" }) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_ladder = true;
                    break;
                }
            }
        }
        if (show_ladder and app_state.g_search_result_count + 4 <= app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_LADDER_AUTO_OFFSET;
            app_state.g_search_results[app_state.g_search_result_count + 1] = SEARCH_LADDER_CLAUDE_OFFSET;
            app_state.g_search_results[app_state.g_search_result_count + 2] = SEARCH_LADDER_CODEX_OFFSET;
            app_state.g_search_results[app_state.g_search_result_count + 3] = SEARCH_LADDER_DASH_OFFSET;
            app_state.g_search_result_count += 4;
        }
    }

    {
        var show_voice = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const voice_labels = [_][]const u8{ "voice mode", "voice", "speak", "listen", "hands free", "hands-free" };
            for (voice_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_voice = true;
                    break;
                }
            }
        }
        if (show_voice) {
            if (app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_VOICE_MODE_ON_OFFSET;
                app_state.g_search_result_count += 1;
            }
            if (app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_VOICE_MODE_OFF_OFFSET;
                app_state.g_search_result_count += 1;
            }
        }
    }

    {
        var show_always = app_state.g_search_len == 0;
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            for ([_][]const u8{ "voice", "always listening", "talk over", "taking turns" }) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_always = true;
                    break;
                }
            }
        }
        if (show_always and app_state.g_search_result_count + 2 <= app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_VOICE_ALWAYS_ON_OFFSET;
            app_state.g_search_results[app_state.g_search_result_count + 1] = SEARCH_VOICE_ALWAYS_OFF_OFFSET;
            app_state.g_search_result_count += 2;
        }
    }

    {
        var show_voice_stop = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const voice_stop_labels = [_][]const u8{ "voice stop", "stop speaking", "voice", "stop", "speaking", "mute" };
            for (voice_stop_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_voice_stop = true;
                    break;
                }
            }
        }
        if (show_voice_stop and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_VOICE_STOP_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    {
        var show_voice_speed = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const voice_speed_labels = [_][]const u8{ "voice speed", "voice", "speed", "faster", "slower" };
            for (voice_speed_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_voice_speed = true;
                    break;
                }
            }
        }
        if (show_voice_speed and app_state.g_search_result_count + 4 <= app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_VOICE_SPEED_100_OFFSET;
            app_state.g_search_results[app_state.g_search_result_count + 1] = SEARCH_VOICE_SPEED_125_OFFSET;
            app_state.g_search_results[app_state.g_search_result_count + 2] = SEARCH_VOICE_SPEED_140_OFFSET;
            app_state.g_search_results[app_state.g_search_result_count + 3] = SEARCH_VOICE_SPEED_150_OFFSET;
            app_state.g_search_result_count += 4;
        }
    }

    {
        var show_voice_replay = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const voice_replay_labels = [_][]const u8{ "voice", "read", "repeat", "replay", "last reply" };
            for (voice_replay_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_voice_replay = true;
                    break;
                }
            }
        }
        if (show_voice_replay and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_VOICE_REPLAY_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    for ([_]struct { offset: usize, label: []const u8 }{
        .{ .offset = SEARCH_VOICE_PREVIOUS_OFFSET, .label = "voice read previous reply" },
        .{ .offset = SEARCH_VOICE_NEXT_OFFSET, .label = "voice read next reply" },
    }) |action| {
        if ((app_state.g_search_len == 0 or asciiContainsQueryInsensitive(action.label, app_state.g_search_buf[0..app_state.g_search_len])) and
            app_state.g_search_result_count < app_state.g_search_results.len)
        {
            app_state.g_search_results[app_state.g_search_result_count] = action.offset;
            app_state.g_search_result_count += 1;
        }
    }

    {
        var show_cvm = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const cvm_labels = [_][]const u8{ "chat view mode", "chat view", "chat", "per tab", "on everywhere", "off everywhere", "everywhere", "off", "on" };
            for (cvm_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_cvm = true;
                    break;
                }
            }
        }
        if (show_cvm) {
            if (app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_VIEW_MODE_PER_SESSION_OFFSET;
                app_state.g_search_result_count += 1;
            }
            if (app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_VIEW_MODE_EVERYWHERE_OFFSET;
                app_state.g_search_result_count += 1;
            }
            if (app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_VIEW_MODE_NOWHERE_OFFSET;
                app_state.g_search_result_count += 1;
            }
        }
    }

    {
        var show_uo = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const uo_labels = [_][]const u8{ "unread only", "filter", "unread", "only", "dots", "focus" };
            for (uo_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_uo = true;
                    break;
                }
            }
        }
        if (show_uo and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_UNREADONLY_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    {
        var show_eta = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const eta_labels = [_][]const u8{ "eta", "estimate", "countdown", "progress", "accuracy", "session eta" };
            for (eta_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_eta = true;
                    break;
                }
            }
        }
        if (show_eta) {
            if (app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_ETA_NUMBERS_OFFSET;
                app_state.g_search_result_count += 1;
            }
            if (app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_ETA_PROGRESS_OFFSET;
                app_state.g_search_result_count += 1;
            }
            if (app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_ETA_ACCURACY_OFFSET;
                app_state.g_search_result_count += 1;
            }
        }
    }

    if (IS_DEV) {
        var show_tt = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const tt_labels = [_][]const u8{ "thread title", "title", "header", "subject", "band" };
            for (tt_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_tt = true;
                    break;
                }
            }
        }
        if (show_tt and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_THREADTITLE_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    {
        var show_font = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const font_labels = [_][]const u8{ "terminal font", "console font", "font", "size", "zoom", "in", "out", "bigger", "smaller", "text" };
            for (font_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_font = true;
                    break;
                }
            }
        }
        if (show_font and app_state.g_search_result_count + 3 <= app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_FONT_BIGGER_OFFSET;
            app_state.g_search_result_count += 1;
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_FONT_SMALLER_OFFSET;
            app_state.g_search_result_count += 1;
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_FONT_RESET_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    {
        const target_ws: u8 = if (app_state.g_search_spawn_ws != 0xFF and app_state.g_search_spawn_ws < app_state.g_lws_count and !app_state.g_ws_snoozed[app_state.g_search_spawn_ws])
            app_state.g_search_spawn_ws
        else
            app_state.g_active_workspace;
        var cci: usize = 0;
        while (cci < app_state.g_custom_cmds_count) : (cci += 1) {
            if (app_state.g_search_result_count >= app_state.g_search_results.len) break;
            if (!customCmdVisibleInWorkspace(cci, target_ws)) continue;
            if (app_state.g_search_len > 0 and !customCmdMatchesQuery(cci, app_state.g_search_buf[0..app_state.g_search_len])) continue;
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CUSTOMCMD_OFFSET + cci;
            app_state.g_search_result_count += 1;
        }
    }

    {
        var show_cc = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const cc_labels = [_][]const u8{ "commands", "custom command", "commands.json", "edit commands", "reload commands" };
            for (cc_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_cc = true;
                    break;
                }
            }
        }
        if (show_cc and app_state.g_search_result_count + 2 <= app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CUSTOMCMD_EDIT_OFFSET;
            app_state.g_search_result_count += 1;
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CUSTOMCMD_RELOAD_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.active_shell < app_state.shell_count) {
        var show_diag = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const diag_labels = [_][]const u8{ "copy shell diagnostics", "shell diagnostics", "diagnostic", "diagnostics", "shell status", "copy status", "debug shell", "session state" };
            for (diag_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_diag = true;
                    break;
                }
            }
        }
        if (show_diag and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SHELL_DIAG_OFFSET;
            app_state.g_search_result_count += 1;
        }

        var show_sync_name = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const sync_labels = [_][]const u8{ "use agent tmux name", "adopt agent name", "sync tab tmux agent name", "sync name", "sync tab name", "sync tmux name", "sync agent name", "sync codex name", "sync claude name", "coding agent name", "tmux title" };
            for (sync_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_sync_name = true;
                    break;
                }
            }
        }
        if (show_sync_name and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_SYNC_NAME_OFFSET;
            app_state.g_search_result_count += 1;
        }

        var show_rename_sync = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const rename_labels = [_][]const u8{ "rename tab", "rename session", "rename shell", "rename tmux", "rename agent", "rename codex", "rename claude", "rename tab tmux agent name" };
            for (rename_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_rename_sync = true;
                    break;
                }
            }
        }
        if (show_rename_sync and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_RENAME_SYNC_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_single_window) {
        if (app_state.g_search_result_count < app_state.g_search_results.len and labelsMatchQuery(&.{ "Workspace: Snooze...", "snooze workspace", "hide clients" }, app_state.g_search_buf[0..app_state.g_search_len])) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WS_SNOOZE_OFFSET;
            app_state.g_search_result_count += 1;
        }
        loadRemindersIfNeeded();
        _ = ensureSnoozeMarkers();
        var has_snoozed = false;
        for (0..app_state.g_reminder_count) |ri| {
            const e = &app_state.g_reminders[ri];
            if (e.workspace_marker and findMyWorkspaceSlot(e.workspace_id[0..e.workspace_id_len]) != null) has_snoozed = true;
        }
        for (0..app_state.g_lws_count) |wi| {
            if (!app_state.g_ws_snoozed[wi]) continue;
            const mi = snoozedWorkspaceIndex(@intCast(wi)) orelse continue;
            var wake_label: [96]u8 = undefined;
            const wake_text = std.fmt.bufPrint(&wake_label, "Workspace: Wake {s}", .{app_state.g_reminders[mi].name[0..app_state.g_reminders[mi].name_len]}) catch continue;
            if (app_state.g_search_result_count >= app_state.g_search_results.len or !labelsMatchQuery(&.{ wake_text, "wake workspace" }, app_state.g_search_buf[0..app_state.g_search_len])) continue;
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WS_SNOOZED_ROW_OFFSET + mi;
            app_state.g_search_result_count += 1;
        }
        if (app_state.g_search_result_count < app_state.g_search_results.len and labelsMatchQuery(&.{ "Workspace: Bring Back All Sessions", "bring back sessions", "reattach tmux sessions" }, app_state.g_search_buf[0..app_state.g_search_len])) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WS_BRINGBACK_OFFSET;
            app_state.g_search_result_count += 1;
        }
        if (has_snoozed and app_state.g_search_result_count < app_state.g_search_results.len and labelsMatchQuery(&.{ "Workspace: Snoozed...", "wake workspace" }, app_state.g_search_buf[0..app_state.g_search_len])) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_WS_SNOOZED_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].tmux_session_len > 0) {
        var show_remind = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const remind_labels = [_][]const u8{ "remind me", "reminder", "snooze", "snooze session", "later" };
            for (remind_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_remind = true;
                    break;
                }
            }
        }
        if (show_remind and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_REMIND_ME_OFFSET;
            app_state.g_search_result_count += 1;
        }

        var show_archive = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const archive_labels = [_][]const u8{ "archive session", "archive", "archived", "dissolve session", "dissolve", "dissolved", "session", "tmux" };
            for (archive_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_archive = true;
                    break;
                }
            }
        }
        if (show_archive and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_ARCHIVE_OFFSET;
            app_state.g_search_result_count += 1;
        }
        var show_end = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const end_labels = [_][]const u8{ "end tmux session", "end tmux", "kill tmux", "close tmux", "close session", "kill session", "terminate session", "end session", "exit agent", "kill agent", "multiprompt-browser", "zsb" };
            for (end_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_end = true;
                    break;
                }
            }
        }
        if (show_end and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_END_TMUX_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    {
        var show_reminders = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const reminder_labels = [_][]const u8{ "reminders", "snoozed", "snoozed sessions", "reminder list", "snooze list" };
            for (reminder_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_reminders = true;
                    break;
                }
            }
        }
        if (show_reminders and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_REMINDERS_MENU_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_closed_count > 0) {
        var show_reopen = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const reopen_labels = [_][]const u8{ "reopen closed tab", "reopen", "closed", "restore", "undo" };
            for (reopen_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_reopen = true;
                    break;
                }
            }
        }
        if (show_reopen and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_REOPEN_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }
    {
        var show_urlpick = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const urlpick_labels = [_][]const u8{ "open url from screen", "url", "link", "open", "browser" };
            for (urlpick_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_urlpick = true;
                    break;
                }
            }
        }
        if (show_urlpick and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_URLPICK_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }
    if (app_state.shell_count > 0) {
        var show_closetab = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const closetab_labels = [_][]const u8{ "close tab", "close", "tab", "kill" };
            for (closetab_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_closetab = true;
                    break;
                }
            }
        }
        if (show_closetab and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CLOSETAB_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }
    if (app_state.shell_count > 0) {
        var show_mutetab = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const mutetab_labels = [_][]const u8{ "mute tab", "unmute tab", "mute", "unmute", "silence", "notifications" };
            for (mutetab_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_mutetab = true;
                    break;
                }
            }
        }
        if (show_mutetab and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_MUTETAB_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }
    if (app_state.active_shell < app_state.shell_count and app_state.g_search_result_count < app_state.g_search_results.len and
        (app_state.g_search_len == 0 or labelsMatchQuery(&.{ "Favorite: Toggle", "unfavorite", "star" }, app_state.g_search_buf[0..app_state.g_search_len])))
    {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_FAVORITE_OFFSET;
        app_state.g_search_result_count += 1;
    }
    if (app_state.active_shell < app_state.shell_count and app_state.g_search_result_count < app_state.g_search_results.len) {
        const label = if (app_state.shells[app_state.active_shell].inbox_excluded) "Inbox: Show This Session Again" else "Inbox: Never Show This Session";
        if (app_state.g_search_len == 0 or labelsMatchQuery(&.{ label, "inbox", "exclude" }, app_state.g_search_buf[0..app_state.g_search_len])) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_INBOX_EXCLUDE_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }
    if (app_state.active_shell < app_state.shell_count) {
        var show_pin_top = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const pin_labels = [_][]const u8{ "pin to top", "unpin from top", "pin tab", "unpin tab", "pinned", "sidebar top", "top" };
            for (pin_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_pin_top = true;
                    break;
                }
            }
        }
        if (show_pin_top and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_PIN_TOP_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }
    if (app_state.active_shell < app_state.shell_count) {
        var show_lock = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const lock_labels = [_][]const u8{ "lock session", "unlock session", "protect session", "locked", "prevent close" };
            for (lock_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_lock = true;
                    break;
                }
            }
        }
        if (show_lock and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_LOCK_SESSION_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }
    if (app_state.active_shell < app_state.shell_count) {
        const k = app_state.shells[app_state.active_shell].kind;
        if (k == .cmd or k == .pwsh) {
            var show_keepalive = (app_state.g_search_len == 0);
            if (app_state.g_search_len > 0) {
                const q = app_state.g_search_buf[0..app_state.g_search_len];
                const keepalive_labels = [_][]const u8{ "keep alive", "keep", "alive", "persist" };
                for (keepalive_labels) |label| {
                    if (asciiContainsQueryInsensitive(label, q)) {
                        show_keepalive = true;
                        break;
                    }
                }
            }
            if (show_keepalive and app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_KEEPALIVE_OFFSET;
                app_state.g_search_result_count += 1;
            }
        }
    }
    if (app_state.shell_count > 0) {
        var show_chat_view = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const chat_labels = [_][]const u8{ "chat view", "chat overlay", "conversation", "composer", "terminal transcript", "alt c" };
            for (chat_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_chat_view = true;
                    break;
                }
            }
        }
        if (show_chat_view and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_VIEW_OFFSET;
            app_state.g_search_result_count += 1;
        }
        if (app_state.g_search_result_count < app_state.g_search_results.len and
            (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("Chat View: Allow", app_state.g_search_buf[0..app_state.g_search_len])))
        {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_ALLOW_OFFSET;
            app_state.g_search_result_count += 1;
        }
        if (app_state.g_search_result_count < app_state.g_search_results.len and
            (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("Chat View: Always allow", app_state.g_search_buf[0..app_state.g_search_len])))
        {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_ALWAYS_OFFSET;
            app_state.g_search_result_count += 1;
        }
        if (app_state.g_search_result_count < app_state.g_search_results.len and
            (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("Chat View: Deny", app_state.g_search_buf[0..app_state.g_search_len])))
        {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_DENY_OFFSET;
            app_state.g_search_result_count += 1;
        }
        if (if (app_state.ISSUE_265_WORKING_BAR) app_state.active_shell < app_state.shell_count else app_state.g_chat_active) {
            var show_chat_stop = (app_state.g_search_len == 0);
            if (app_state.g_search_len > 0) {
                const q = app_state.g_search_buf[0..app_state.g_search_len];
                const stop_labels = [_][]const u8{ (if (app_state.ISSUE_265_WORKING_BAR) "Chat View: Stop the agent" else "stop agent"), "stop agent", "interrupt", "ctrl c", "cancel response" };
                for (stop_labels) |label| {
                    if (asciiContainsQueryInsensitive(label, q)) {
                        show_chat_stop = true;
                        break;
                    }
                }
            }
            if (show_chat_stop and app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_STOP_OFFSET;
                app_state.g_search_result_count += 1;
            }
        }

        if (app_state.active_shell < app_state.shell_count and app_state.g_search_result_count < app_state.g_search_results.len and
            (app_state.g_search_len == 0 or labelsMatchQuery(&.{ "Chat View: Insert browser tab URL", "link", "ctrl shift x" }, app_state.g_search_buf[0..app_state.g_search_len])))
        {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_TAB_URL_OFFSET;
            app_state.g_search_result_count += 1;
        }
        if (app_state.active_shell < app_state.shell_count and app_state.g_search_result_count < app_state.g_search_results.len and
            (app_state.g_search_len == 0 or asciiContainsQueryInsensitive("Chat View: Reset this chat", app_state.g_search_buf[0..app_state.g_search_len])))
        {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_RESET_OFFSET;
            app_state.g_search_result_count += 1;
        }
        var show_queue_send = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const queue_labels = [_][]const u8{ "send queued", "queued messages", "offline queue", "outbox", "flush queue" };
            for (queue_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_queue_send = true;
                    break;
                }
            }
        }
        if (show_queue_send and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_QUEUE_SEND_OFFSET;
            app_state.g_search_result_count += 1;
        }
        const has_queue = app_state.active_shell < app_state.shell_count and chatOutboxCountForShell(app_state.active_shell) > 0;
        if (has_queue and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_QUEUE_CLEAR_OFFSET;
            app_state.g_search_result_count += 1;
        }
        const has_unsent = app_state.active_shell < app_state.shell_count and chatEchoCountNotSentForShell(app_state.active_shell) > 0;
        var show_retry_unsent = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const retry_labels = [_][]const u8{ "retry unsent", "unsent message", "not sent", "resend" };
            for (retry_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_retry_unsent = true;
                    break;
                }
            }
        }
        if (show_retry_unsent and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_RETRY_UNSENT_OFFSET;
            app_state.g_search_result_count += 1;
        }
        if (has_unsent and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_DISCARD_UNSENT_OFFSET;
            app_state.g_search_result_count += 1;
        }
        var show_push_queued = app_state.active_shell < app_state.shell_count and chatEchoCountDeliveredForShell(app_state.active_shell) > 0;
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            show_push_queued = asciiContainsQueryInsensitive("send queued in claude now", q) or asciiContainsQueryInsensitive("push queued message", q);
        }
        if (show_push_queued and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CHAT_PUSH_QUEUED_OFFSET;
            app_state.g_search_result_count += 1;
        }

        var show_browser_toggle = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const browser_labels = [_][]const u8{ "browser", "web", "edge", "pane", "open browser", "show browser", "recover browser", "retry browser", "retry browser pane", "close browser pane", "alt a", "alt b" };
            for (browser_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_browser_toggle = true;
                    break;
                }
            }
        }
        if (show_browser_toggle and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_BROWSER_TOGGLE_OFFSET;
            app_state.g_search_result_count += 1;
        }

        var show_browser_engine = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const engine_labels = [_][]const u8{ "browser engine", "browser profile", "dedicated edge", "dedicated chrome", "switch browser", "google chrome", "microsoft edge" };
            for (engine_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_browser_engine = true;
                    break;
                }
            }
        }
        if (show_browser_engine and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_BROWSER_ENGINE_OFFSET;
            app_state.g_search_result_count += 1;
        }

        var show_browser_url = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const browser_url_labels = [_][]const u8{ "browser url", "open url in browser", "navigate", "web", "goto", "edge url" };
            for (browser_url_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_browser_url = true;
                    break;
                }
            }
        }
        if (show_browser_url and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_BROWSER_URL_OFFSET;
            app_state.g_search_result_count += 1;
        }

        if (activeShellHasShotUrlPane()) {
            var show_browser_shoturl = (app_state.g_search_len == 0);
            if (app_state.g_search_len > 0) {
                const q = app_state.g_search_buf[0..app_state.g_search_len];
                const shoturl_labels = [_][]const u8{ "browser screenshot", "screenshot", "shot", "capture", "link", "shell", "browser", "ctrl shift s" };
                for (shoturl_labels) |label| {
                    if (asciiContainsQueryInsensitive(label, q)) {
                        show_browser_shoturl = true;
                        break;
                    }
                }
            }
            if (show_browser_shoturl and app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_BROWSER_SHOTURL_OFFSET;
                app_state.g_search_result_count += 1;
            }
        }

        if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_enabled) {
            var show_browser_focus_url = (app_state.g_search_len == 0);
            if (app_state.g_search_len > 0) {
                const q = app_state.g_search_buf[0..app_state.g_search_len];
                const focus_url_labels = [_][]const u8{ "zigbrowser focus address bar", "browser address", "address bar", "focus address", "browser url bar", "edge address" };
                for (focus_url_labels) |label| {
                    if (asciiContainsQueryInsensitive(label, q)) {
                        show_browser_focus_url = true;
                        break;
                    }
                }
            }
            if (show_browser_focus_url and app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_BROWSER_FOCUS_URL_OFFSET;
                app_state.g_search_result_count += 1;
            }
        }

        if (browserPaneActive()) {
            var show_browser_back = (app_state.g_search_len == 0);
            var show_browser_forward = (app_state.g_search_len == 0);
            if (app_state.g_search_len > 0) {
                const q = app_state.g_search_buf[0..app_state.g_search_len];
                const back_labels = [_][]const u8{ "browser back", "zigbrowser back", "history back", "back", "alt left" };
                for (back_labels) |label| {
                    if (asciiContainsQueryInsensitive(label, q)) {
                        show_browser_back = true;
                        break;
                    }
                }
                const forward_labels = [_][]const u8{ "browser forward", "zigbrowser forward", "history forward", "forward", "alt right" };
                for (forward_labels) |label| {
                    if (asciiContainsQueryInsensitive(label, q)) {
                        show_browser_forward = true;
                        break;
                    }
                }
            }
            if (show_browser_back and app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_BROWSER_BACK_OFFSET;
                app_state.g_search_result_count += 1;
            }
            if (show_browser_forward and app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_BROWSER_FORWARD_OFFSET;
                app_state.g_search_result_count += 1;
            }

            var show_browser_focus_toggle = (app_state.g_search_len == 0);
            if (app_state.g_search_len > 0) {
                const q = app_state.g_search_buf[0..app_state.g_search_len];
                const focus_toggle_labels = [_][]const u8{ "zigbrowser jump", "browser focus", "jump browser", "toggle browser focus", "shell browser", "alt f", "alt m", "ctrl shift m" };
                for (focus_toggle_labels) |label| {
                    if (asciiContainsQueryInsensitive(label, q)) {
                        show_browser_focus_toggle = true;
                        break;
                    }
                }
            }
            if (show_browser_focus_toggle and app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_BROWSER_FOCUS_TOGGLE_OFFSET;
                app_state.g_search_result_count += 1;
            }

            var show_browser_mode = (app_state.g_search_len == 0);
            if (app_state.g_search_len > 0) {
                const q = app_state.g_search_buf[0..app_state.g_search_len];
                const mode_labels = [_][]const u8{ "browser mode", "native chrome", "native edge", "custom url bar", "edge chrome", "omnibox", "tabs omnibox" };
                for (mode_labels) |label| {
                    if (asciiContainsQueryInsensitive(label, q)) {
                        show_browser_mode = true;
                        break;
                    }
                }
            }
            if (show_browser_mode and app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_BROWSER_MODE_OFFSET;
                app_state.g_search_result_count += 1;
            }
        }

        var show_browser_instruct = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const instruct_labels = [_][]const u8{ "browser", "control", "pane", "instructions", "multiprompt-browser", "zsb", "bridge" };
            for (instruct_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_browser_instruct = true;
                    break;
                }
            }
        }
        if (show_browser_instruct and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_BROWSER_INSTRUCT_OFFSET;
            app_state.g_search_result_count += 1;
        }

        if (app_state.active_shell < app_state.shell_count and isRemoteShellKind(app_state.shells[app_state.active_shell].kind) and app_state.shells[app_state.active_shell].browser_enabled) {
            var show_zsb_rebind = (app_state.g_search_len == 0);
            if (app_state.g_search_len > 0) {
                const q = app_state.g_search_buf[0..app_state.g_search_len];
                const zsb_labels = [_][]const u8{ "multiprompt-browser", "zsb", "rebind", "bind", "browser bind", "pane bind", "force browser", "zsb rebind", "fix zsb" };
                for (zsb_labels) |label| {
                    if (asciiContainsQueryInsensitive(label, q)) {
                        show_zsb_rebind = true;
                        break;
                    }
                }
            }
            if (show_zsb_rebind and app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_ZSB_REBIND_OFFSET;
                app_state.g_search_result_count += 1;
            }
        }
    }

    {
        var show_browser_autosuspend = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const autosuspend_labels = [_][]const u8{ "zigbrowser auto suspend", "browser suspend", "auto suspend", "autosuspend", "idle browser", "save ram", "ram" };
            for (autosuspend_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_browser_autosuspend = true;
                    break;
                }
            }
        }
        if (show_browser_autosuspend and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_BROWSER_AUTOSUSPEND_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    {
        var show_keepawake = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const kaw_labels = [_][]const u8{ "keep tab awake", "keep awake", "awake", "pin tab", "hibernate", "freeze" };
            for (kaw_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_keepawake = true;
                    break;
                }
            }
        }
        if (show_keepawake and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_KEEPAWAKE_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    {
        var show_hibernate_now = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const hib_labels = [_][]const u8{ "hibernate browser panes", "hibernate panes", "hibernate now", "hibernate", "free ram", "save ram" };
            for (hib_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_hibernate_now = true;
                    break;
                }
            }
        }
        if (show_hibernate_now and app_state.g_search_result_count < app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_HIBERNATE_NOW_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len and labelsMatchQuery(&.{ "Close All Browser Panes", "close all browsers", "close browser windows", "free browser memory" }, app_state.g_search_buf[0..app_state.g_search_len])) {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CLOSE_ALL_BROWSER_PANES_OFFSET;
        app_state.g_search_result_count += 1;
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len and labelsMatchQuery(&.{ "Crash Reports: Open Folder", "crash reports", "crash log", "crashes" }, app_state.g_search_buf[0..app_state.g_search_len])) {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CRASH_REPORTS_OFFSET;
        app_state.g_search_result_count += 1;
    }
    if (IS_DEV and app_state.g_search_len > 0 and app_state.g_search_result_count < app_state.g_search_results.len and labelsMatchQuery(&.{ "Debug: Crash Now", "crash now" }, app_state.g_search_buf[0..app_state.g_search_len])) {
        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_CRASH_NOW_OFFSET;
        app_state.g_search_result_count += 1;
    }

    {
        var show_ui = (app_state.g_search_len == 0);
        if (app_state.g_search_len > 0) {
            const q = app_state.g_search_buf[0..app_state.g_search_len];
            const ui_labels = [_][]const u8{ "ui", "size", "zoom", "scale", "interface", "chrome", "bigger", "smaller" };
            for (ui_labels) |label| {
                if (asciiContainsQueryInsensitive(label, q)) {
                    show_ui = true;
                    break;
                }
            }
        }
        if (show_ui and app_state.g_search_result_count + 3 <= app_state.g_search_results.len) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_UI_BIGGER_OFFSET;
            app_state.g_search_result_count += 1;
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_UI_SMALLER_OFFSET;
            app_state.g_search_result_count += 1;
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_UI_RESET_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    for (0..app_state.shell_count) |i| {
        if (app_state.g_search_len == 0) {
            app_state.g_search_results[app_state.g_search_result_count] = i;
            app_state.g_search_result_count += 1;
            continue;
        }
        const q = app_state.g_search_buf[0..app_state.g_search_len];
        const remote_host: ?u8 = switch (app_state.shells[i].kind) {
            .tmux => app_state.shells[i].tmux_host,
            .vps => 0,
            .vps2 => 1,
            else => null,
        };
        if (u16ContainsInsensitive(app_state.shells[i].name[0..app_state.shells[i].name_len], q) or
            (if (app_state.shells[i].last_title_len > 0) u16ContainsInsensitive(app_state.shells[i].last_title[0..@intCast(app_state.shells[i].last_title_len)], q) else false) or
            kindMatchesQuery(app_state.shells[i].kind, q) or
            (if (remote_host) |host| tmuxHostMatchesQuery(host, q) else false))
        {
            app_state.g_search_results[app_state.g_search_result_count] = i;
            app_state.g_search_result_count += 1;
        }
    }

    buildFilteredTmux();
    var ti: u32 = 0;
    while (ti < app_state.g_inactive_filtered_count) : (ti += 1) {
        if (app_state.g_search_result_count >= app_state.g_search_results.len) break;
        const cache_idx = app_state.g_inactive_filtered[ti];
        const sess = app_state.g_tmux_cache[cache_idx];
        const sname = sess.name[0..sess.name_len];

        if (app_state.g_search_len > 0) {
            const query = app_state.g_search_buf[0..app_state.g_search_len];
            var all_words_match = true;
            var wstart: usize = 0;
            var qp: usize = 0;
            while (qp <= query.len) : (qp += 1) {
                const at_end = (qp == query.len);
                if (at_end or query[qp] == ' ') {
                    if (qp > wstart) {
                        const word = query[wstart..qp];
                        var name_w: [64]u16 = undefined;
                        for (sname, 0..) |c, ni| name_w[ni] = @intCast(c);
                        const name_hit = u16ContainsInsensitive(name_w[0..sess.name_len], word);
                        var title_hit = false;
                        if (!name_hit and sess.title_len > 0) {
                            var title_w: [80]u16 = undefined;
                            for (sess.title[0..sess.title_len], 0..) |c, tci| title_w[tci] = @intCast(c);
                            title_hit = u16ContainsInsensitive(title_w[0..sess.title_len], word);
                        }
                        const host_hit = !name_hit and !title_hit and tmuxHostMatchesQuery(sess.host, word);
                        if (!name_hit and !title_hit and !host_hit) {
                            all_words_match = false;
                            break;
                        }
                    }
                    wstart = qp + 1;
                }
            }
            if (!all_words_match) continue;
        }

        if (tmuxCacheEntryAlreadyOpen(&sess)) continue;

        app_state.g_search_results[app_state.g_search_result_count] = SEARCH_TMUX_OFFSET + cache_idx;
        app_state.g_search_result_count += 1;
    }

    if (app_state.g_inactive_filtered_count >= 1 and app_state.g_search_result_count < app_state.g_search_results.len) {
        var show_openall = (app_state.g_search_len == 0);
        if (!show_openall) {
            const openall_labels = [_][]const u8{ "open all", "open all vps", "tmux", "all tmux", "vps sessions" };
            for (openall_labels) |label| {
                const query3 = app_state.g_search_buf[0..app_state.g_search_len];
                if (query3.len <= label.len) {
                    var ok3 = true;
                    for (0..query3.len) |j| {
                        const qc3 = u16ToLower(query3[j]);
                        const lc3: u16 = label[j];
                        if (qc3 != lc3) {
                            ok3 = false;
                            break;
                        }
                    }
                    if (ok3) {
                        show_openall = true;
                        break;
                    }
                }
            }
        }
        if (show_openall) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_OPENALL_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len) {
        var fh: u8 = 0;
        var fbuf: [256]u8 = undefined;
        var flen: u32 = 0;
        if (focusedSessionFolder(&fh, &fbuf, &flen) and countFolderSessions(fh, fbuf[0..flen]) >= 1) {
            var show_folder = (app_state.g_search_len == 0);
            if (!show_folder) {
                const folder_labels = [_][]const u8{ "open sessions in this folder", "folder", "this folder", "repo", "sessions" };
                for (folder_labels) |label| {
                    const queryf = app_state.g_search_buf[0..app_state.g_search_len];
                    if (queryf.len <= label.len) {
                        var okf = true;
                        for (0..queryf.len) |j| {
                            const qcf = u16ToLower(queryf[j]);
                            const lcf: u16 = label[j];
                            if (qcf != lcf) {
                                okf = false;
                                break;
                            }
                        }
                        if (okf) {
                            show_folder = true;
                            break;
                        }
                    }
                }
            }
            if (show_folder) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_OPENFOLDER_OFFSET;
                app_state.g_search_result_count += 1;
            }
        }
    }

    if (app_state.g_search_result_count < app_state.g_search_results.len) {
        var rh: u8 = 0;
        var rbuf: [256]u8 = undefined;
        var rlen: u32 = 0;
        const repo_ok = workspacePrimaryRepo(&rh, &rbuf, &rlen);
        const repo_count = if (repo_ok) countFolderSessions(rh, rbuf[0..rlen]) else 0;
        var show_recover = (repo_ok and repo_count >= 1 and app_state.g_search_len == 0);
        if (!show_recover and app_state.g_search_len > 0) {
            const recover_labels = [_][]const u8{ "recover workspace tmux sessions", "recover tmux", "missing sessions", "recovery" };
            for (recover_labels) |label| {
                const queryr = app_state.g_search_buf[0..app_state.g_search_len];
                if (queryr.len <= label.len) {
                    var okr = true;
                    for (0..queryr.len) |j| {
                        const qcr = u16ToLower(queryr[j]);
                        const lcr: u16 = label[j];
                        if (qcr != lcr) {
                            okr = false;
                            break;
                        }
                    }
                    if (okr) {
                        show_recover = true;
                        break;
                    }
                }
            }
        }
        if (show_recover) {
            app_state.g_search_results[app_state.g_search_result_count] = SEARCH_RECOVER_REPO_OFFSET;
            app_state.g_search_result_count += 1;
        }
    }

    if (app_state.g_search_len > 0 and app_state.g_search_result_count < app_state.g_search_results.len) {
        loadArchiveIfNeeded();
        const query_arc = app_state.g_search_buf[0..app_state.g_search_len];
        var ai: usize = 0;
        while (ai < @min(app_state.g_archived_count, 64)) : (ai += 1) {
            const e = &app_state.g_archived.items[ai];
            var name_w: [64]u16 = undefined;
            for (e.name[0..e.name_len], 0..) |c, ni| name_w[ni] = @intCast(c);
            var sess_w: [64]u16 = undefined;
            for (e.tmux_session[0..e.tmux_session_len], 0..) |c, si| sess_w[si] = @intCast(c);
            var all_arc = true;
            var wstart_a: usize = 0;
            var qp_a: usize = 0;
            while (qp_a <= query_arc.len) : (qp_a += 1) {
                const at_end_a = (qp_a == query_arc.len);
                if (at_end_a or query_arc[qp_a] == ' ') {
                    if (qp_a > wstart_a) {
                        const word_a = query_arc[wstart_a..qp_a];
                        const name_hit_a = u16ContainsInsensitive(name_w[0..e.name_len], word_a);
                        const sess_hit_a = !name_hit_a and u16ContainsInsensitive(sess_w[0..e.tmux_session_len], word_a);
                        if (!name_hit_a and !sess_hit_a) {
                            all_arc = false;
                            break;
                        }
                    }
                    wstart_a = qp_a + 1;
                }
            }
            if (!all_arc) continue;
            if (app_state.g_search_result_count < app_state.g_search_results.len) {
                app_state.g_search_results[app_state.g_search_result_count] = SEARCH_ARCHIVED_OFFSET + ai;
                app_state.g_search_result_count += 1;
            }
        }
    }

    if (app_state.g_search_len > 0) appendGroupPaletteResults();
    sortSearchResultsByRank();

    if (app_state.g_search_len == 0) {
        var lv: [MAX_SHELLS]u64 = undefined;
        var ok: [MAX_SHELLS]bool = undefined;
        for (0..app_state.shell_count) |rsi| {
            lv[rsi] = app_state.shells[rsi].last_viewed;
            ok[rsi] = !app_state.g_ws_snoozed[app_state.shells[rsi].workspace] and
                !(app_state.shells[rsi].inbox_archived and !app_state.shells[rsi].needs_attention);
        }
        const prev_idx: ?usize = if (app_state.g_previous_shell_sid == 0) null else if (findShellById(app_state.g_previous_shell_sid)) |p| @as(usize, p) else null;
        var recent: [RECENT_SESSION_ROWS]usize = undefined;
        const rn = pickRecentSessions(lv[0..app_state.shell_count], ok[0..app_state.shell_count], app_state.active_shell, prev_idx, &recent);
        var rj: usize = rn;
        while (rj > 0) {
            rj -= 1;
            _ = promoteSearchTargetToFront(app_state.g_search_results[0..app_state.g_search_result_count], recent[rj]);
        }
    }

    if (app_state.g_search_result_count > 0) {
        keepSearchSelectionVisible();
    } else {
        app_state.g_search_sel = 0;
        app_state.g_search_scroll = 0;
    }
}

pub fn u16ToLower(c: u16) u16 {
    if (c >= 'A' and c <= 'Z') return c + 32;
    return c;
}

pub fn u16ContainsInsensitive(haystack: []const u16, needle: []const u16) bool {
    if (needle.len == 0) return true;
    if (haystack.len < needle.len) return false;
    const limit = haystack.len - needle.len + 1;
    for (0..limit) |start| {
        var match = true;
        for (0..needle.len) |j| {
            if (u16ToLower(haystack[start + j]) != u16ToLower(needle[j])) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

pub fn asciiContainsQueryInsensitive(haystack: []const u8, needle: []const u16) bool {
    if (needle.len == 0) return true;
    if (haystack.len < needle.len) return false;
    const limit = haystack.len - needle.len + 1;
    for (0..limit) |start| {
        var match = true;
        for (0..needle.len) |j| {
            const hc: u16 = if (haystack[start + j] >= 'A' and haystack[start + j] <= 'Z') haystack[start + j] + 32 else haystack[start + j];
            if (hc != u16ToLower(needle[j])) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

pub fn reductionSearchChar(vk: u32, shift: bool) u16 {
    if (vk >= 0x41 and vk <= 0x5A) return @intCast(if (shift) vk else vk + 32);
    if (vk >= 0x30 and vk <= 0x39) return @intCast(vk);
    return switch (vk) {
        0x20 => ' ',
        0xBD => if (shift) '_' else '-',
        0xBE => '.',
        0xBF => if (shift) '?' else '/',
        else => 0,
    };
}

fn labelsMatchQuery(labels: []const []const u8, query: []const u16) bool {
    if (query.len == 0) return true;
    for (labels) |label| {
        if (asciiContainsQueryInsensitive(label, query)) return true;
    }
    return false;
}

fn sessionOverviewCommandMatches(query: []const u16) bool {
    const labels = [_][]const u8{
        "show all sessions",
        "show all sessions from this workspace repo folder",
        "show repo sessions",
        "show workspace sessions",
        "repo sessions",
        "workspace repo sessions",
        "workspace sessions",
        "session overview",
        "sessions overview",
        "all sessions",
        "all tmux sessions",
        "tmux overview",
        "recover sessions",
    };
    return labelsMatchQuery(&labels, query);
}

fn workspaceMatchesSearch(e: *const WorkspaceEntry, query: []const u16) bool {
    if (query.len == 0) return true;
    var name_w: [64]u16 = undefined;
    const nl = @min(e.name_len, name_w.len);
    for (0..nl) |i| name_w[i] = @intCast(e.name[i]);
    if (u16ContainsInsensitive(name_w[0..nl], query)) return true;

    var id_w: [64]u16 = undefined;
    const il = @min(e.id_len, id_w.len);
    for (0..il) |i| id_w[i] = @intCast(e.id[i]);
    if (u16ContainsInsensitive(id_w[0..il], query)) return true;

    const labels = [_][]const u8{ "workspace", "window", "open workspace", "open window" };
    for (labels) |label| {
        if (asciiContainsQueryInsensitive(label, query)) return true;
    }
    return false;
}

pub fn tmuxHostMatchesQuery(host: u8, query: []const u16) bool {
    if (host == TMUX_HOST_UK) {
        const labels = [_][]const u8{ "uk", "host2", "vps uk", "vps host2", "tmux uk", "tmux host2", "uk-tmx" };
        for (labels) |label| {
            if (asciiContainsQueryInsensitive(label, query)) return true;
        }
    } else if (host == TMUX_HOST_INNE) {
        const labels = [_][]const u8{ "secondary", "secondary cro", "remote-3", "vps secondary", "tmux secondary", "secondary-tmx" };
        for (labels) |label| {
            if (asciiContainsQueryInsensitive(label, query)) return true;
        }
    } else {
        const labels = [_][]const u8{ "de", "host1", "vps de", "vps host1", "tmux de", "tmux host1", "de-tmx" };
        for (labels) |label| {
            if (asciiContainsQueryInsensitive(label, query)) return true;
        }
    }
    return false;
}

fn kindMatchesQuery(kind: ShellKind, query: []const u16) bool {
    const tag: []const u8 = switch (kind) {
        .cmd => "CMD",
        .pwsh => "PWS",
        .vps => "VPS",
        .tmux => "TMX",
        .vps2 => "VPS",
        .bash => "BSH",
        .gitbash => "GIT",
    };
    if (query.len > tag.len) return false;
    for (0..query.len) |j| {
        const qc = u16ToLower(query[j]);
        const tc: u16 = if (tag[j] >= 'A' and tag[j] <= 'Z') tag[j] + 32 else tag[j];
        if (qc != tc) return false;
    }
    return true;
}
