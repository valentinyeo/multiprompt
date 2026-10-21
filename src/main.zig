const frequent = @import("frequent.zig");
const app_state = @import("app_state.zig");
const launch_cache = @import("launch_cache.zig");
const WINAPI = @import("win32.zig").WINAPI;
const DWORD = @import("win32.zig").DWORD;
const UINT = @import("win32.zig").UINT;
const WPARAM = @import("win32.zig").WPARAM;
const LPARAM = @import("win32.zig").LPARAM;
const LRESULT = @import("win32.zig").LRESULT;
const HANDLE = @import("win32.zig").HANDLE;
const LPCWSTR = @import("win32.zig").LPCWSTR;
const WS_OVERLAPPEDWINDOW = @import("win32.zig").WS_OVERLAPPEDWINDOW;
const WS_VISIBLE = @import("win32.zig").WS_VISIBLE;
const WS_CHILD = @import("win32.zig").WS_CHILD;
const WS_CLIPSIBLINGS = @import("win32.zig").WS_CLIPSIBLINGS;
const WS_CLIPCHILDREN = @import("win32.zig").WS_CLIPCHILDREN;
const WS_CAPTION = @import("win32.zig").WS_CAPTION;
const WS_THICKFRAME = @import("win32.zig").WS_THICKFRAME;
const WS_BORDER = @import("win32.zig").WS_BORDER;
const CS_DBLCLKS = @import("win32.zig").CS_DBLCLKS;
const CW_USEDEFAULT = @import("win32.zig").CW_USEDEFAULT;
const GWL_STYLE = @import("win32.zig").GWL_STYLE;
const SWP_FRAMECHANGED = @import("win32.zig").SWP_FRAMECHANGED;
const SWP_NOZORDER = @import("win32.zig").SWP_NOZORDER;
const SWP_NOMOVE = @import("win32.zig").SWP_NOMOVE;
const SWP_NOSIZE = @import("win32.zig").SWP_NOSIZE;
const SWP_NOACTIVATE = @import("win32.zig").SWP_NOACTIVATE;
const WM_ACTIVATEAPP = @import("win32.zig").WM_ACTIVATEAPP;
const WM_SETTINGCHANGE = @import("win32.zig").WM_SETTINGCHANGE;
const WM_THEMECHANGED = @import("win32.zig").WM_THEMECHANGED;
const WM_SETFOCUS = @import("win32.zig").WM_SETFOCUS;
const WM_DESTROY = @import("win32.zig").WM_DESTROY;
const WM_MOVE = @import("win32.zig").WM_MOVE;
const WM_WINDOWPOSCHANGED = @import("win32.zig").WM_WINDOWPOSCHANGED;
const WM_SIZE = @import("win32.zig").WM_SIZE;
const WM_DPICHANGED = @import("win32.zig").WM_DPICHANGED;
const WM_DISPLAYCHANGE = @import("win32.zig").WM_DISPLAYCHANGE;
const WM_GETMINMAXINFO = @import("win32.zig").WM_GETMINMAXINFO;
const WM_PAINT = @import("win32.zig").WM_PAINT;
const WM_COMMAND = @import("win32.zig").WM_COMMAND;
const WM_CTLCOLOREDIT = @import("win32.zig").WM_CTLCOLOREDIT;
const WM_CTLCOLORSTATIC = @import("win32.zig").WM_CTLCOLORSTATIC;
const WM_LBUTTONDOWN = @import("win32.zig").WM_LBUTTONDOWN;
const WM_LBUTTONUP = @import("win32.zig").WM_LBUTTONUP;
const WM_MOUSEMOVE = @import("win32.zig").WM_MOUSEMOVE;
const WM_LBUTTONDBLCLK = @import("win32.zig").WM_LBUTTONDBLCLK;
const SW_SHOW = @import("win32.zig").SW_SHOW;
const SW_SHOWNOACTIVATE = @import("win32.zig").SW_SHOWNOACTIVATE;
const SW_HIDE = @import("win32.zig").SW_HIDE;
const SW_RESTORE = @import("win32.zig").SW_RESTORE;
const WM_HOTKEY = @import("win32.zig").WM_HOTKEY;
const HOTKEY_ID_FOCUS = @import("win32.zig").HOTKEY_ID_FOCUS;
const MOD_CONTROL = @import("win32.zig").MOD_CONTROL;
const MOD_SHIFT = @import("win32.zig").MOD_SHIFT;
const DT_SINGLELINE = @import("win32.zig").DT_SINGLELINE;
const DT_CENTER = @import("win32.zig").DT_CENTER;
const DT_END_ELLIPSIS = @import("win32.zig").DT_END_ELLIPSIS;
const TRANSPARENT = @import("win32.zig").TRANSPARENT;
const EN_KILLFOCUS = @import("win32.zig").EN_KILLFOCUS;
const MK_LBUTTON = @import("win32.zig").MK_LBUTTON;
const WM_KEYDOWN = @import("win32.zig").WM_KEYDOWN;
const WM_APP_NEXT_TAB = @import("win32.zig").WM_APP_NEXT_TAB;
const WM_APP_PREV_TAB = @import("win32.zig").WM_APP_PREV_TAB;
const WM_APP_SPAWN = @import("win32.zig").WM_APP_SPAWN;
const WM_APP_CLOSE = @import("win32.zig").WM_APP_CLOSE;
const WM_APP_FOCUS = @import("win32.zig").WM_APP_FOCUS;
const WM_APP_COMMIT_RENAME = @import("win32.zig").WM_APP_COMMIT_RENAME;
const WM_APP_RENAME_TAB = @import("win32.zig").WM_APP_RENAME_TAB;
const WM_APP_SWITCH_TAB = @import("win32.zig").WM_APP_SWITCH_TAB;
const WM_APP_SEARCH_OPEN = @import("win32.zig").WM_APP_SEARCH_OPEN;
const WM_APP_SEARCH_CLOSE = @import("win32.zig").WM_APP_SEARCH_CLOSE;
const WM_APP_SEARCH_CHAR = @import("win32.zig").WM_APP_SEARCH_CHAR;
const WM_APP_SEARCH_BACKSPACE = @import("win32.zig").WM_APP_SEARCH_BACKSPACE;
const WM_APP_SEARCH_MOVE = @import("win32.zig").WM_APP_SEARCH_MOVE;
const WM_APP_SEARCH_CONFIRM = @import("win32.zig").WM_APP_SEARCH_CONFIRM;
const WM_APP_REOPEN_CLOSED = @import("win32.zig").WM_APP_REOPEN_CLOSED;
const WM_APP_TOGGLE_SIDEBAR = @import("win32.zig").WM_APP_TOGGLE_SIDEBAR;
const WM_APP_TMUX_LIST_READY = @import("win32.zig").WM_APP_TMUX_LIST_READY;
const WM_APP_NEW_WINDOW = @import("win32.zig").WM_APP_NEW_WINDOW;
const WM_APP_PASTE = @import("win32.zig").WM_APP_PASTE;
const WM_APP_COPY = @import("win32.zig").WM_APP_COPY;
const WM_APP_OPEN_URL_AT = @import("win32.zig").WM_APP_OPEN_URL_AT;
const WM_APP_NEXT_UNREAD = @import("win32.zig").WM_APP_NEXT_UNREAD;
const WM_APP_URL_PICKER_OPEN = @import("win32.zig").WM_APP_URL_PICKER_OPEN;
const WM_APP_URL_PICKER_MOVE = @import("win32.zig").WM_APP_URL_PICKER_MOVE;
const WM_APP_URL_PICKER_CONFIRM = @import("win32.zig").WM_APP_URL_PICKER_CONFIRM;
const WM_APP_URL_PICKER_CLOSE = @import("win32.zig").WM_APP_URL_PICKER_CLOSE;
const WM_APP_SSH_UNAVAILABLE = @import("win32.zig").WM_APP_SSH_UNAVAILABLE;
const WM_APP_NOTIFY = @import("win32.zig").WM_APP_NOTIFY;
const WM_APP_SHELL_EXITED = @import("win32.zig").WM_APP_SHELL_EXITED;
const WM_APP_FAVICON_FETCHED = @import("win32.zig").WM_APP_FAVICON_FETCHED;
const WM_APP_MOVE_TAB = @import("win32.zig").WM_APP_MOVE_TAB;
const WM_APP_TOGGLE_GROUP = @import("win32.zig").WM_APP_TOGGLE_GROUP;
const WM_APP_COPY_OR_INTERRUPT = @import("win32.zig").WM_APP_COPY_OR_INTERRUPT;
const WM_APP_RENAME_WINDOW = @import("win32.zig").WM_APP_RENAME_WINDOW;
const WM_APP_QUIT_ALL = @import("win32.zig").WM_APP_QUIT_ALL;
const WM_APP_DEV_FONT_NEXT = @import("win32.zig").WM_APP_DEV_FONT_NEXT;
const WM_APP_DEV_SIZE_DOWN = @import("win32.zig").WM_APP_DEV_SIZE_DOWN;
const WM_APP_DEV_SIZE_UP = @import("win32.zig").WM_APP_DEV_SIZE_UP;
const WM_APP_DEV_AMOLED = @import("win32.zig").WM_APP_DEV_AMOLED;
const WM_APP_TOGGLE_FULLWIDTH = @import("win32.zig").WM_APP_TOGGLE_FULLWIDTH;
const WM_APP_SHORTCUTS_OPEN = @import("win32.zig").WM_APP_SHORTCUTS_OPEN;
const WM_APP_SHORTCUTS_CLOSE = @import("win32.zig").WM_APP_SHORTCUTS_CLOSE;
const WM_APP_SHORTCUTS_SCROLL = @import("win32.zig").WM_APP_SHORTCUTS_SCROLL;
const WM_APP_RECONNECT = @import("win32.zig").WM_APP_RECONNECT;
const WM_APP_TOGGLE_INBOX = @import("win32.zig").WM_APP_TOGGLE_INBOX;
const WM_APP_INBOX_KEY = @import("win32.zig").WM_APP_INBOX_KEY;
const WM_APP_FOCUS_SHELL = @import("win32.zig").WM_APP_FOCUS_SHELL;
const WM_APP_SWITCH_WORKSPACE = @import("win32.zig").WM_APP_SWITCH_WORKSPACE;
const WM_APP_INBOX_STEP = @import("win32.zig").WM_APP_INBOX_STEP;
const WM_APP_CYCLE_WORKSPACE = @import("win32.zig").WM_APP_CYCLE_WORKSPACE;
const WM_APP_WSSORT_MOVE = @import("win32.zig").WM_APP_WSSORT_MOVE;
const WM_APP_SYSMENU = @import("win32.zig").WM_APP_SYSMENU;
const WM_APP_WIN_SNAP = @import("win32.zig").WM_APP_WIN_SNAP;
const WM_APP_INBOX_ARCHIVE = @import("win32.zig").WM_APP_INBOX_ARCHIVE;
const WM_APP_INBOX_MARKUNREAD = @import("win32.zig").WM_APP_INBOX_MARKUNREAD;
const WM_APP_TOGGLE_UNREAD = @import("win32.zig").WM_APP_TOGGLE_UNREAD;
const WM_APP_FONT_BIGGER = @import("win32.zig").WM_APP_FONT_BIGGER;
const WM_APP_FONT_SMALLER = @import("win32.zig").WM_APP_FONT_SMALLER;
const WM_APP_FONT_RESET = @import("win32.zig").WM_APP_FONT_RESET;
const WM_APP_UI_BIGGER = @import("win32.zig").WM_APP_UI_BIGGER;
const WM_APP_UI_SMALLER = @import("win32.zig").WM_APP_UI_SMALLER;
const WM_APP_UI_RESET = @import("win32.zig").WM_APP_UI_RESET;
const WM_APP_NEW_TAB_DEFAULT = @import("win32.zig").WM_APP_NEW_TAB_DEFAULT;
const WM_APP_HIDE_TAB_UNTIL_ATTENTION = @import("win32.zig").WM_APP_HIDE_TAB_UNTIL_ATTENTION;
const WM_APP_BROWSER_TOGGLE = @import("win32.zig").WM_APP_BROWSER_TOGGLE;
const WM_APP_BROWSER_OPEN_URL = @import("win32.zig").WM_APP_BROWSER_OPEN_URL;
const WM_APP_ZSB_OPEN = @import("win32.zig").WM_APP_ZSB_OPEN;
const WM_APP_BROWSER_FOCUS_URL = @import("win32.zig").WM_APP_BROWSER_FOCUS_URL;
const WM_APP_BROWSER_FOCUS_TOGGLE = @import("win32.zig").WM_APP_BROWSER_FOCUS_TOGGLE;
const WM_APP_CHANGELOG_OPEN = @import("win32.zig").WM_APP_CHANGELOG_OPEN;
const WM_APP_CHANGELOG_CLOSE = @import("win32.zig").WM_APP_CHANGELOG_CLOSE;
const WM_APP_CHANGELOG_MOVE = @import("win32.zig").WM_APP_CHANGELOG_MOVE;
const WM_APP_CHANGELOG_CONFIRM = @import("win32.zig").WM_APP_CHANGELOG_CONFIRM;
const WM_APP_BROWSER_URL_UPDATE = @import("win32.zig").WM_APP_BROWSER_URL_UPDATE;
const WM_APP_BROWSER_BACK = @import("win32.zig").WM_APP_BROWSER_BACK;
const WM_APP_BROWSER_FORWARD = @import("win32.zig").WM_APP_BROWSER_FORWARD;
const WM_APP_SHOW_SIDEBAR = @import("win32.zig").WM_APP_SHOW_SIDEBAR;
const WM_APP_URLBAR_DISMISS = @import("win32.zig").WM_APP_URLBAR_DISMISS;
const WM_APP_BROWSER_MODE_TOGGLE = @import("win32.zig").WM_APP_BROWSER_MODE_TOGGLE;
const WM_APP_RESTART = @import("win32.zig").WM_APP_RESTART;
const WM_APP_ZSB_BIND = @import("win32.zig").WM_APP_ZSB_BIND;
const WM_APP_BROWSER_RESOLVED = @import("win32.zig").WM_APP_BROWSER_RESOLVED;
const WM_APP_DIAG = @import("win32.zig").WM_APP_DIAG;
const WM_APP_DICTATION_TOGGLE = @import("win32.zig").WM_APP_DICTATION_TOGGLE;
const WM_APP_DICTATION_READY = @import("win32.zig").WM_APP_DICTATION_READY;
const WM_APP_CLOSE_SESSION = @import("win32.zig").WM_APP_CLOSE_SESSION;
const WM_APP_SNIPPETS_OPEN = @import("win32.zig").WM_APP_SNIPPETS_OPEN;
const WM_APP_SNIPPET_FORM_SAVE = @import("win32.zig").WM_APP_SNIPPET_FORM_SAVE;
const WM_APP_SNIPPET_FORM_CANCEL = @import("win32.zig").WM_APP_SNIPPET_FORM_CANCEL;
const WM_APP_ALL_SESSIONS_OPEN = @import("win32.zig").WM_APP_ALL_SESSIONS_OPEN;
const WM_APP_ALL_SESSIONS_KEY = @import("win32.zig").WM_APP_ALL_SESSIONS_KEY;
const WM_APP_REMIND_PRESETS_OPEN = @import("win32.zig").WM_APP_REMIND_PRESETS_OPEN;
const WM_APP_ARCHIVE_ARM = @import("win32.zig").WM_APP_ARCHIVE_ARM;
const WM_APP_SHOT_PASTE = @import("win32.zig").WM_APP_SHOT_PASTE;
const WM_APP_BROWSER_SHOTURL = @import("win32.zig").WM_APP_BROWSER_SHOTURL;
const WM_APP_MARK_ACTIVE_UNREAD = @import("win32.zig").WM_APP_MARK_ACTIVE_UNREAD;
const WM_APP_SNIPPET_DELETE = @import("win32.zig").WM_APP_SNIPPET_DELETE;
const WM_APP_INBOX_UNARCHIVE = @import("win32.zig").WM_APP_INBOX_UNARCHIVE;
const WM_APP_ALL_SESSIONS_FILTER_OPEN = @import("win32.zig").WM_APP_ALL_SESSIONS_FILTER_OPEN;
const WM_APP_ALL_SESSIONS_FILTER_CHAR = @import("win32.zig").WM_APP_ALL_SESSIONS_FILTER_CHAR;
const WM_APP_ALL_SESSIONS_FILTER_BACKSPACE = @import("win32.zig").WM_APP_ALL_SESSIONS_FILTER_BACKSPACE;
const WM_APP_ALL_SESSIONS_FILTER_CLOSE = @import("win32.zig").WM_APP_ALL_SESSIONS_FILTER_CLOSE;
const WM_APP_WEBVIEW2_TOGGLE = @import("win32.zig").WM_APP_WEBVIEW2_TOGGLE;
const WM_APP_WEBVIEW2_ACTION = @import("win32.zig").WM_APP_WEBVIEW2_ACTION;
const WM_APP_WEBVIEW2_FOCUS = @import("win32.zig").WM_APP_WEBVIEW2_FOCUS;
const WM_APP_SESSION_INTERACTED = @import("win32.zig").WM_APP_SESSION_INTERACTED;
const WM_APP_BROWSER_DROP_GESTURE = @import("win32.zig").WM_APP_BROWSER_DROP_GESTURE;
const WM_APP_AI_PACE_READY = @import("win32.zig").WM_APP_AI_PACE_READY;
const WM_APP_CYCLE_STATUS_CARD = @import("win32.zig").WM_APP_CYCLE_STATUS_CARD;
const WM_APP_SEARCH_SELECT_ALL = @import("win32.zig").WM_APP_SEARCH_SELECT_ALL;
const WM_APP_COPY_CLAUDE_LOGIN_URL = @import("win32.zig").WM_APP_COPY_CLAUDE_LOGIN_URL;
const WM_APP_INBOX_FILTER_OPEN = @import("win32.zig").WM_APP_INBOX_FILTER_OPEN;
const WM_APP_INBOX_FILTER_CHAR = @import("win32.zig").WM_APP_INBOX_FILTER_CHAR;
const WM_APP_INBOX_FILTER_BACKSPACE = @import("win32.zig").WM_APP_INBOX_FILTER_BACKSPACE;
const WM_APP_INBOX_FILTER_CLOSE = @import("win32.zig").WM_APP_INBOX_FILTER_CLOSE;
const WM_APP_BROWSER_ENGINE_TOGGLE = @import("win32.zig").WM_APP_BROWSER_ENGINE_TOGGLE;
const WM_APP_INPUT_HOOK_RECOVER = @import("win32.zig").WM_APP_INPUT_HOOK_RECOVER;
const WM_APP_CHAT_TOGGLE = @import("win32.zig").WM_APP_CHAT_TOGGLE;
const WM_APP_CHAT_AC_READY = @import("win32.zig").WM_APP_CHAT_AC_READY;
const WM_APP_CHAT_SEND = @import("win32.zig").WM_APP_CHAT_SEND;
const WM_APP_CHAT_INTERRUPT = @import("win32.zig").WM_APP_CHAT_INTERRUPT;
const WM_APP_POWER_ACTIVITY = @import("win32.zig").WM_APP_POWER_ACTIVITY;
const WM_APP_TOGGLE_KEEP_AWAKE = @import("win32.zig").WM_APP_TOGGLE_KEEP_AWAKE;
const WM_APP_VOICE_TOGGLE = @import("win32.zig").WM_APP_VOICE_TOGGLE;
const WM_APP_VOICE_BARGE_IN = @import("win32.zig").WM_APP_VOICE_BARGE_IN;
const WM_APP_VOICE_TTS_FALLBACK = @import("win32.zig").WM_APP_VOICE_TTS_FALLBACK;
const WM_APP_VOICE_SPEECH_START = @import("win32.zig").WM_APP_VOICE_SPEECH_START;
const WM_APP_VOICE_UTTERANCE_READY = @import("win32.zig").WM_APP_VOICE_UTTERANCE_READY;
const WM_APP_VOICE_MIC_STATUS = @import("win32.zig").WM_APP_VOICE_MIC_STATUS;
const WM_APP_VOICE_TTS_AUDIO_STARTED = @import("win32.zig").WM_APP_VOICE_TTS_AUDIO_STARTED;
const WM_APP_WS_SNOOZE_OPEN = @import("win32.zig").WM_APP_WS_SNOOZE_OPEN;
const WM_APP_VOICE_STEP = @import("win32.zig").WM_APP_VOICE_STEP;
const WM_APP_CHAT_FILE_READY = @import("win32.zig").WM_APP_CHAT_FILE_READY;
const WM_APP_CHAT_COPY_CODE = @import("win32.zig").WM_APP_CHAT_COPY_CODE;
const WM_APP_CHAT_COPY_SELECTION = @import("win32.zig").WM_APP_CHAT_COPY_SELECTION;
const WM_APP_CHAT_SELECT_ALL = @import("win32.zig").WM_APP_CHAT_SELECT_ALL;
const WM_APP_VOICE_REPLAY = @import("win32.zig").WM_APP_VOICE_REPLAY;
const WM_APP_LADDER_DONE = @import("win32.zig").WM_APP_LADDER_DONE;
const WM_APP_ZSB_WHO = @import("win32.zig").WM_APP_ZSB_WHO;
const WM_APP_BROWSER_DOCKED = @import("win32.zig").WM_APP_BROWSER_DOCKED;
const WM_APP_LAYOUT_READY = @import("win32.zig").WM_APP_LAYOUT_READY;
const WM_APP_FAVORITE_TOGGLE = @import("win32.zig").WM_APP_FAVORITE_TOGGLE;
const WM_APP_UPDATE_CHANGED = @import("win32.zig").WM_APP_UPDATE_CHANGED;
const WM_COPYDATA = @import("win32.zig").WM_COPYDATA;
const WM_ERASEBKGND = @import("win32.zig").WM_ERASEBKGND;
const WM_TIMER = @import("win32.zig").WM_TIMER;
const WM_MOUSEWHEEL = @import("win32.zig").WM_MOUSEWHEEL;
const WM_MOUSEHWHEEL = @import("win32.zig").WM_MOUSEHWHEEL;
const WM_POWERBROADCAST = @import("win32.zig").WM_POWERBROADCAST;
const PBT_APMSUSPEND = @import("win32.zig").PBT_APMSUSPEND;
const PBT_APMRESUMESUSPEND = @import("win32.zig").PBT_APMRESUMESUSPEND;
const PBT_APMRESUMEAUTOMATIC = @import("win32.zig").PBT_APMRESUMEAUTOMATIC;
const RESUME_RESPAWN_WINDOW_MS = @import("win32.zig").RESUME_RESPAWN_WINDOW_MS;
const TIMER_NAME_POLL = @import("win32.zig").TIMER_NAME_POLL;
const TIMER_REFOCUS = @import("win32.zig").TIMER_REFOCUS;
const TIMER_HOOK_UNINSTALL = @import("win32.zig").TIMER_HOOK_UNINSTALL;
const TIMER_SPINNER = @import("win32.zig").TIMER_SPINNER;
const TIMER_RESUME_RECONNECT = @import("win32.zig").TIMER_RESUME_RECONNECT;
const TIMER_FONT_HUD = @import("win32.zig").TIMER_FONT_HUD;
const TIMER_INBOX_REFRESH = @import("win32.zig").TIMER_INBOX_REFRESH;
const TIMER_SYSMENU = @import("win32.zig").TIMER_SYSMENU;
const TIMER_CAP_MSG = @import("win32.zig").TIMER_CAP_MSG;
const TIMER_BROWSER_ADOPT = @import("win32.zig").TIMER_BROWSER_ADOPT;
const TIMER_BROWSER_SETTLE = @import("win32.zig").TIMER_BROWSER_SETTLE;
const TIMER_BROWSER_URL_POLL = @import("win32.zig").TIMER_BROWSER_URL_POLL;
const TIMER_BROWSER_EDGE_MASK_RAISE = @import("win32.zig").TIMER_BROWSER_EDGE_MASK_RAISE;
const TIMER_REMINDERS = @import("win32.zig").TIMER_REMINDERS;
const TIMER_CONSOLE_GEOMETRY_SETTLE = @import("win32.zig").TIMER_CONSOLE_GEOMETRY_SETTLE;
const TIMER_WEBVIEW2_FOCUS = @import("win32.zig").TIMER_WEBVIEW2_FOCUS;
const TIMER_NATIVE_BROWSER_FOCUS = @import("win32.zig").TIMER_NATIVE_BROWSER_FOCUS;
const TIMER_BROWSER_HEALTH = @import("win32.zig").TIMER_BROWSER_HEALTH;
const TIMER_TUNNEL_KEEPER = @import("win32.zig").TIMER_TUNNEL_KEEPER;
const TIMER_UNARCHIVE_UNATTACHED = @import("win32.zig").TIMER_UNARCHIVE_UNATTACHED;
const TIMER_VPS_CAPACITY = @import("win32.zig").TIMER_VPS_CAPACITY;
const TIMER_MONITOR_TRANSITION = @import("win32.zig").TIMER_MONITOR_TRANSITION;
const TIMER_AI_PACE = @import("win32.zig").TIMER_AI_PACE;
const TIMER_SYSTEM_THEME = @import("win32.zig").TIMER_SYSTEM_THEME;
const TIMER_BROWSER_ENGINE_SWITCH = @import("win32.zig").TIMER_BROWSER_ENGINE_SWITCH;
const TIMER_CHAT_REFRESH = @import("win32.zig").TIMER_CHAT_REFRESH;
const TIMER_POWER_IDLE = @import("win32.zig").TIMER_POWER_IDLE;
const TIMER_INBOX_PUBLISH = @import("win32.zig").TIMER_INBOX_PUBLISH;
const TIMER_VOICE_POLL = @import("win32.zig").TIMER_VOICE_POLL;
const TIMER_VOICE_TURN_END = @import("win32.zig").TIMER_VOICE_TURN_END;
const TIMER_CHAT_AC_DEBOUNCE = @import("win32.zig").TIMER_CHAT_AC_DEBOUNCE;
const TIMER_CHAT_SEND_VERIFY = @import("win32.zig").TIMER_CHAT_SEND_VERIFY;
const TIMER_ETA_REPAINT = @import("win32.zig").TIMER_ETA_REPAINT;
const TIMER_VOICE_TTS_POS = @import("win32.zig").TIMER_VOICE_TTS_POS;
const TIMER_SSH_RECONNECT = @import("win32.zig").TIMER_SSH_RECONNECT;
const TIMER_CHAT_OUTBOX = @import("win32.zig").TIMER_CHAT_OUTBOX;
const TIMER_BROWSER_PLACEHOLDER = @import("win32.zig").TIMER_BROWSER_PLACEHOLDER;
const TIMER_CHAT_BROWSER_SWAP = @import("win32.zig").TIMER_CHAT_BROWSER_SWAP;
const TIMER_CHAT_DRAFT = @import("win32.zig").TIMER_CHAT_DRAFT;
const TIMER_SHOT_FOCUS = @import("win32.zig").TIMER_SHOT_FOCUS;
const TIMER_CHAT_FOREGROUND_RETRY = @import("win32.zig").TIMER_CHAT_FOREGROUND_RETRY;
const GUID_ACDC_POWER_SOURCE = @import("win32.zig").GUID_ACDC_POWER_SOURCE;
const GUID_POWER_SAVING_STATUS = @import("win32.zig").GUID_POWER_SAVING_STATUS;
const GUID_CONSOLE_DISPLAY_STATE = @import("win32.zig").GUID_CONSOLE_DISPLAY_STATE;
const PBT_POWERSETTINGCHANGE = @import("win32.zig").PBT_POWERSETTINGCHANGE;
const POWERBROADCAST_SETTING = @import("win32.zig").POWERBROADCAST_SETTING;
const guidEql = @import("power.zig").guidEql;
const setCoalescableTimerInterval = @import("power.zig").setCoalescableTimerInterval;
const refreshPowerStatusFromSystem = @import("power.zig").refreshPowerStatusFromSystem;
const registerPowerNotifications = @import("power.zig").registerPowerNotifications;
const unregisterPowerNotifications = @import("power.zig").unregisterPowerNotifications;
const savePowerProfile = @import("power.zig").savePowerProfile;
const loadPowerProfile = @import("power.zig").loadPowerProfile;
const WNDCLASSEXW = @import("win32.zig").WNDCLASSEXW;
const POINT = @import("win32.zig").POINT;
const TRACKMOUSEEVENT = @import("win32.zig").TRACKMOUSEEVENT;
const MSG = @import("win32.zig").MSG;
const RECT = @import("win32.zig").RECT;
const PAINTSTRUCT = @import("win32.zig").PAINTSTRUCT;
const STARTUPINFOW = @import("win32.zig").STARTUPINFOW;
const PROCESS_INFORMATION = @import("win32.zig").PROCESS_INFORMATION;
const RegisterClassExW = @import("win32.zig").RegisterClassExW;
const CreateWindowExW = @import("win32.zig").CreateWindowExW;
const IsZoomed = @import("win32.zig").IsZoomed;
const IsIconic = @import("win32.zig").IsIconic;
const GetFocus = @import("win32.zig").GetFocus;
const GetSystemMenu = @import("win32.zig").GetSystemMenu;
const GetWindowRect = @import("win32.zig").GetWindowRect;
const MonitorFromWindow = @import("win32.zig").MonitorFromWindow;
const GetMonitorInfoW = @import("win32.zig").GetMonitorInfoW;
const MONITORINFO = @import("win32.zig").MONITORINFO;
const MONITOR_DEFAULTTONEAREST = @import("win32.zig").MONITOR_DEFAULTTONEAREST;
const SetProcessDpiAwarenessContext = @import("win32.zig").SetProcessDpiAwarenessContext;
const DisableProcessWindowsGhosting = @import("win32.zig").DisableProcessWindowsGhosting;
const MonitorSlot = @import("app_state.zig").MonitorSlot;
const MonitorDirection = @import("app_state.zig").MonitorDirection;
const mapWindowRectToWorkArea = @import("monitor.zig").mapWindowRectToWorkArea;
const MINMAXINFO = @import("app_state.zig").MINMAXINFO;
const rectNear = @import("monitor.zig").rectNear;
const monitorSlotInDirection = @import("monitor.zig").monitorSlotInDirection;
const armMonitorTransitionTimer = @import("monitor.zig").armMonitorTransitionTimer;
const beginMonitorTransition = @import("monitor.zig").beginMonitorTransition;
const beginMonitorTransitionAtCurrent = @import("monitor.zig").beginMonitorTransitionAtCurrent;
const retargetMonitorTransitionToCurrent = @import("monitor.zig").retargetMonitorTransitionToCurrent;
const noteMainWindowMonitor = @import("monitor.zig").noteMainWindowMonitor;
const monitorTransitionTick = @import("monitor.zig").monitorTransitionTick;
const WM_SYSCOMMAND = @import("win32.zig").WM_SYSCOMMAND;
const SW_MAXIMIZE = @import("win32.zig").SW_MAXIMIZE;
const SW_MINIMIZE = @import("win32.zig").SW_MINIMIZE;
const IsWindow = @import("win32.zig").IsWindow;
const IsWindowVisible = @import("win32.zig").IsWindowVisible;
const GetMessageW = @import("win32.zig").GetMessageW;
const TranslateMessage = @import("win32.zig").TranslateMessage;
const DispatchMessageW = @import("win32.zig").DispatchMessageW;
const DefWindowProcW = @import("win32.zig").DefWindowProcW;
const PostQuitMessage = @import("win32.zig").PostQuitMessage;
const GetClientRect = @import("win32.zig").GetClientRect;
const SetParent = @import("win32.zig").SetParent;
const SetWindowLongPtrW = @import("win32.zig").SetWindowLongPtrW;
const GetWindowLongPtrW = @import("win32.zig").GetWindowLongPtrW;
const LoadCursorW = @import("win32.zig").LoadCursorW;
const LoadIconW = @import("win32.zig").LoadIconW;
const LoadImageW = @import("win32.zig").LoadImageW;
const IMAGE_ICON = @import("win32.zig").IMAGE_ICON;
const LR_DEFAULTCOLOR = @import("win32.zig").LR_DEFAULTCOLOR;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const BeginPaint = @import("win32.zig").BeginPaint;
const EndPaint = @import("win32.zig").EndPaint;
const GetDC = @import("win32.zig").GetDC;
const ReleaseDC = @import("win32.zig").ReleaseDC;
const FillRect = @import("win32.zig").FillRect;
const DrawTextW = @import("win32.zig").DrawTextW;
const SetCapture = @import("win32.zig").SetCapture;
const ReleaseCapture = @import("win32.zig").ReleaseCapture;
const DestroyWindow = @import("win32.zig").DestroyWindow;
const SetWindowTextW = @import("win32.zig").SetWindowTextW;
const GetForegroundWindow = @import("win32.zig").GetForegroundWindow;
const GetAsyncKeyState = @import("win32.zig").GetAsyncKeyState;
const RegisterHotKey = @import("win32.zig").RegisterHotKey;
const UnregisterHotKey = @import("win32.zig").UnregisterHotKey;
const SetCursor = @import("win32.zig").SetCursor;
const WM_SETCURSOR = @import("win32.zig").WM_SETCURSOR;
const HTCLIENT = @import("win32.zig").HTCLIENT;
const DestroyIcon = @import("win32.zig").DestroyIcon;
const SetCurrentProcessExplicitAppUserModelID = @import("win32.zig").SetCurrentProcessExplicitAppUserModelID;
const CreateSolidBrush = @import("win32.zig").CreateSolidBrush;
const DeleteObject = @import("win32.zig").DeleteObject;
const SetBkMode = @import("win32.zig").SetBkMode;
const SetBkColor = @import("win32.zig").SetBkColor;
const SetTextColor = @import("win32.zig").SetTextColor;
const SelectObject = @import("win32.zig").SelectObject;
const CreateFontW = @import("fonts.zig").create;
const CreatePen = @import("win32.zig").CreatePen;
const BitBlt = @import("win32.zig").BitBlt;
const IntersectClipRect = @import("win32.zig").IntersectClipRect;
const SaveDC = @import("win32.zig").SaveDC;
const RestoreDC = @import("win32.zig").RestoreDC;
const GDI_SRCCOPY = @import("win32.zig").GDI_SRCCOPY;
const CreateProcessW = @import("win32.zig").CreateProcessW;
const Sleep = @import("win32.zig").Sleep;
const GetModuleHandleW = @import("win32.zig").GetModuleHandleW;
const GetModuleFileNameW = @import("win32.zig").GetModuleFileNameW;
const CloseHandle = @import("win32.zig").CloseHandle;
const SetErrorMode = @import("win32.zig").SetErrorMode;
const GetLastError = @import("win32.zig").GetLastError;
const DwmSetWindowAttribute = @import("win32.zig").DwmSetWindowAttribute;
const GetWindowThreadProcessId = @import("win32.zig").GetWindowThreadProcessId;
const GetCurrentThreadId = @import("win32.zig").GetCurrentThreadId;
const SetEnvironmentVariableW = @import("win32.zig").SetEnvironmentVariableW;
const GetEnvironmentVariableW = @import("win32.zig").GetEnvironmentVariableW;
const GetCurrentProcessId = @import("win32.zig").GetCurrentProcessId;
const OpenProcess = @import("win32.zig").OpenProcess;
const TIME_BYTES = @import("win32.zig").TIME_BYTES;
const MMTIME = @import("win32.zig").MMTIME;
const waveOutGetPosition = @import("win32.zig").waveOutGetPosition;
const CreateJobObjectW = @import("win32.zig").CreateJobObjectW;
const AssignProcessToJobObject = @import("win32.zig").AssignProcessToJobObject;
const SetInformationJobObject = @import("win32.zig").SetInformationJobObject;
const WriteFile = @import("win32.zig").WriteFile;
const CreateFileW = @import("win32.zig").CreateFileW;
const INVALID_HANDLE_VALUE_PTR = @import("win32.zig").INVALID_HANDLE_VALUE_PTR;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const JOBOBJECT_EXTENDED_LIMIT_INFORMATION = @import("win32.zig").JOBOBJECT_EXTENDED_LIMIT_INFORMATION;
const JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = @import("win32.zig").JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
const JobObjectExtendedLimitInformation = @import("win32.zig").JobObjectExtendedLimitInformation;
const EnumWindows = @import("win32.zig").EnumWindows;
const SendMessageW = @import("win32.zig").SendMessageW;
const TrackPopupMenu = @import("fonts.zig").trackPopupMenu;
const MessageBoxW = @import("fonts.zig").messageBox;
const WindowFromPoint = @import("win32.zig").WindowFromPoint;
const GetAncestor = @import("win32.zig").GetAncestor;
const ScreenToClient = @import("win32.zig").ScreenToClient;
const GetCursorPos = @import("win32.zig").GetCursorPos;
const TrackMouseEvent = @import("win32.zig").TrackMouseEvent;
const WM_RBUTTONDOWN = @import("win32.zig").WM_RBUTTONDOWN;
const WM_NCLBUTTONDOWN = @import("win32.zig").WM_NCLBUTTONDOWN;
const WM_NCRBUTTONDOWN = @import("win32.zig").WM_NCRBUTTONDOWN;
const WM_ENTERMENULOOP = @import("win32.zig").WM_ENTERMENULOOP;
const WM_EXITMENULOOP = @import("win32.zig").WM_EXITMENULOOP;
const WM_ENTERSIZEMOVE = @import("win32.zig").WM_ENTERSIZEMOVE;
const WM_EXITSIZEMOVE = @import("win32.zig").WM_EXITSIZEMOVE;
const TPM_RETURNCMD = @import("win32.zig").TPM_RETURNCMD;
const TPM_LEFTALIGN = @import("win32.zig").TPM_LEFTALIGN;
const GetExitCodeProcess = @import("win32.zig").GetExitCodeProcess;
const initNtdll = @import("startup.zig").initNtdll;
const L = @import("startup.zig").L;
const initShellIcons = @import("startup.zig").initShellIcons;
const RGB = @import("startup.zig").RGB;
const GET_X = @import("startup.zig").GET_X;
const GET_Y = @import("startup.zig").GET_Y;
const parseInstanceName = @import("startup.zig").parseInstanceName;
const parseNoWindowRestoreFlag = @import("startup.zig").parseNoWindowRestoreFlag;
const parseEmptyWorkspaceFlag = @import("startup.zig").parseEmptyWorkspaceFlag;
const parseNewWindowFlag = @import("startup.zig").parseNewWindowFlag;
const parseSingleWindowFlag = @import("startup.zig").parseSingleWindowFlag;
const parseAdoptArgs = @import("startup.zig").parseAdoptArgs;
const getInstanceName = @import("startup.zig").getInstanceName;
const buildWindowTitle = @import("startup.zig").buildWindowTitle;
const COPYDATASTRUCT = @import("app_state.zig").COPYDATASTRUCT;
const COPYDATA_TAB_TRANSFER = @import("app_state.zig").COPYDATA_TAB_TRANSFER;
const GA_ROOT = @import("app_state.zig").GA_ROOT;
const TabTransfer = @import("app_state.zig").TabTransfer;
const empty_shell = @import("app_state.zig").empty_shell;
const MAX_SHELLS = @import("app_state.zig").MAX_SHELLS;
const SIDEBAR_W_MIN = @import("app_state.zig").SIDEBAR_W_MIN;
const SIDEBAR_W_MAX = @import("app_state.zig").SIDEBAR_W_MAX;
const loadSidebarStatusCard = @import("themes.zig").loadSidebarStatusCard;
const resolveSystemThemeFlags = @import("themes.zig").resolveSystemThemeFlags;
const refreshSystemTheme = @import("themes.zig").refreshSystemTheme;
const saveGlobalTheme = @import("themes.zig").saveGlobalTheme;
const loadGlobalTheme = @import("themes.zig").loadGlobalTheme;
const readChangelogSeen = @import("themes.zig").readChangelogSeen;
const writeChangelogSeen = @import("themes.zig").writeChangelogSeen;
const loadDevThemeFromFile = @import("themes.zig").loadDevThemeFromFile;
const openDevThemeFileInEditor = @import("themes.zig").openDevThemeFileInEditor;
const customColorOr = @import("themes.zig").customColorOr;
const themeSidebarBg = @import("themes.zig").themeSidebarBg;
const themeConsoleFg = @import("themes.zig").themeConsoleFg;
const applyTitleBarTheme = @import("themes.zig").applyTitleBarTheme;
const BROWSER_SUSPEND_DEFAULT_MIN = @import("app_state.zig").BROWSER_SUSPEND_DEFAULT_MIN;
const loadBrowserEngineConfig = @import("browser_pane.zig").loadBrowserEngineConfig;
const loadEdgeExtensionPathConfig = @import("browser_pane.zig").loadEdgeExtensionPathConfig;
const loadEdgeProfileConfig = @import("browser_pane.zig").loadEdgeProfileConfig;
const loadEdgeExeConfig = @import("browser_pane.zig").loadEdgeExeConfig;
const loadChromeExeConfig = @import("browser_pane.zig").loadChromeExeConfig;
const ensureChromeNativeMessagingRegistration = @import("browser_pane.zig").ensureChromeNativeMessagingRegistration;
const SIDEBAR_W = @import("browser_pane.zig").SIDEBAR_W;
const tabRowH = @import("browser_pane.zig").tabRowH;
const NUM_BUTTONS = @import("app_state.zig").NUM_BUTTONS;
const MAX_LWS = @import("app_state.zig").MAX_LWS;
const WS_STRIP_H = @import("app_state.zig").WS_STRIP_H;
const WS_NEW_PILL = @import("app_state.zig").WS_NEW_PILL;
const inboxButtonHitTest = @import("browser_pane.zig").inboxButtonHitTest;
const threadTitleHeight = @import("browser_pane.zig").threadTitleHeight;
const threadTitleTop = @import("browser_pane.zig").threadTitleTop;
const MAX_GROUPS = @import("app_state.zig").MAX_GROUPS;
const GROUP_COLORS = @import("app_state.zig").GROUP_COLORS;
const findGroupIdx = @import("sidebar.zig").findGroupIdx;
const findNextVisibleTab = @import("sidebar.zig").findNextVisibleTab;
const recordInboxArchive = @import("sidebar.zig").recordInboxArchive;
const logUnarchive = @import("sidebar.zig").logUnarchive;
const hideActiveTabUntilAttention = @import("sidebar.zig").hideActiveTabUntilAttention;
const setBlueDot = @import("sidebar.zig").setBlueDot;
const clearSelectedTabDotOnReturn = @import("sidebar.zig").clearSelectedTabDotOnReturn;
const markActiveShellUnread = @import("sidebar.zig").markActiveShellUnread;
const toggleKeepAwakeForActiveShell = @import("sidebar.zig").toggleKeepAwakeForActiveShell;
const selectedTabCount = @import("sidebar.zig").selectedTabCount;
const clearTabSelection = @import("sidebar.zig").clearTabSelection;
const assignTabOrSelectionToGroup = @import("sidebar.zig").assignTabOrSelectionToGroup;
const removeTabOrSelectionFromGroup = @import("sidebar.zig").removeTabOrSelectionFromGroup;
const moveShellToIndexWithGroup = @import("sidebar.zig").moveShellToIndexWithGroup;
const moveShellToGroupStart = @import("sidebar.zig").moveShellToGroupStart;
const moveActiveTabStep = @import("sidebar.zig").moveActiveTabStep;
const moveGroupToIndex = @import("sidebar.zig").moveGroupToIndex;
const createDefaultGroup = @import("sidebar.zig").createDefaultGroup;
const pruneEmptyGroups = @import("sidebar.zig").pruneEmptyGroups;
const applyPendingGroup = @import("sidebar.zig").applyPendingGroup;
const shellSidebarTier = @import("sidebar.zig").shellSidebarTier;
const toggleSidebarSectionCollapsed = @import("sidebar.zig").toggleSidebarSectionCollapsed;
const materializeDisplayOrder = @import("sidebar.zig").materializeDisplayOrder;
const sidebarTierForDrop = @import("sidebar.zig").sidebarTierForDrop;
const workspaceStripHitTest = @import("sidebar.zig").workspaceStripHitTest;
const hitTestSidebar = @import("sidebar.zig").hitTestSidebar;
const sidebarStickyCardHitTest = @import("capacity.zig").sidebarStickyCardHitTest;
const UPDATE_CHECK_MS = @import("app_state.zig").UPDATE_CHECK_MS;
const updateCardInit = @import("update_card.zig").updateCardInit;
const startUpdateCardWatch = @import("update_card.zig").startUpdateCardWatch;
const stopUpdateCardWatch = @import("update_card.zig").stopUpdateCardWatch;
const updateCardHit = @import("update_card.zig").updateCardHit;
const updateCardPoll = @import("update_card.zig").updateCardPoll;
const updateCardDismiss = @import("update_card.zig").updateCardDismiss;
const updateCardRelaunch = @import("update_card.zig").updateCardRelaunch;
const capacityBlockNoticeActive = @import("capacity.zig").capacityBlockNoticeActive;
const announceCapacityTransitions = @import("capacity.zig").announceCapacityTransitions;
const focusGuardComposerRepairAllowed = @import("focus.zig").focusGuardComposerRepairAllowed;
const focusGuardNoteActivation = @import("focus.zig").focusGuardNoteActivation;
const PostMessageW = @import("focus.zig").PostMessageW;
const focusGuardDispatchTick = @import("focus.zig").focusGuardDispatchTick;
const focusGuard = @import("focus.zig").focusGuard;
const SetForegroundWindow = @import("focus.zig").SetForegroundWindow;
const SetFocus = @import("focus.zig").SetFocus;
const AttachThreadInput = @import("focus.zig").AttachThreadInput;
const AllowSetForegroundWindow = @import("focus.zig").AllowSetForegroundWindow;
const ShowWindow = @import("focus.zig").ShowWindow;
const SetWindowPos = @import("focus.zig").SetWindowPos;
const activeShellHwndForFocusGuard = @import("focus.zig").activeShellHwndForFocusGuard;
const installHook = @import("focus.zig").installHook;
const installForegroundHook = @import("focus.zig").installForegroundHook;
const uninstallForegroundHook = @import("focus.zig").uninstallForegroundHook;
const forceReinstallHooks = @import("focus.zig").forceReinstallHooks;
const forceReinstallHooksThrottled = @import("focus.zig").forceReinstallHooksThrottled;
const uninstallHook = @import("focus.zig").uninstallHook;
const uninstallKeyboardHook = @import("focus.zig").uninstallKeyboardHook;
const syncMouseHookForUrlClicks = @import("focus.zig").syncMouseHookForUrlClicks;
const isCtrlDown = @import("focus.zig").isCtrlDown;
const foregroundIsOurs = @import("focus.zig").foregroundIsOurs;
const evaluateDeepIdle = @import("power.zig").evaluateDeepIdle;
const exitDeepIdleNow = @import("power.zig").exitDeepIdleNow;
const applyPowerProfile = @import("power.zig").applyPowerProfile;
const hookWatchdog = @import("shortcuts.zig").hookWatchdog;
const DRAG_MATERIALIZE_THRESH = @import("app_state.zig").DRAG_MATERIALIZE_THRESH;
const armBrowserVisibilitySettle = @import("browser_pane.zig").armBrowserVisibilitySettle;
const armConsoleGeometrySettle = @import("console.zig").armConsoleGeometrySettle;
const armStartupConsoleGeometrySettle = @import("console.zig").armStartupConsoleGeometrySettle;
const settleConsoleGeometry = @import("console.zig").settleConsoleGeometry;
const BROWSER_EDGE_MASK_COUNT = @import("app_state.zig").BROWSER_EDGE_MASK_COUNT;
const CHAT_FONT_DEFAULT_PT = @import("app_state.zig").CHAT_FONT_DEFAULT_PT;
const SEARCH_VISIBLE_ROWS = @import("app_state.zig").SEARCH_VISIBLE_ROWS;
const SEARCH_WHEEL_ROWS = @import("app_state.zig").SEARCH_WHEEL_ROWS;
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
const SEARCH_CHAT_QUEUE_CLEAR_OFFSET = @import("app_state.zig").SEARCH_CHAT_QUEUE_CLEAR_OFFSET;
const SEARCH_CHAT_RETRY_UNSENT_OFFSET = @import("app_state.zig").SEARCH_CHAT_RETRY_UNSENT_OFFSET;
const SEARCH_CHAT_DISCARD_UNSENT_OFFSET = @import("app_state.zig").SEARCH_CHAT_DISCARD_UNSENT_OFFSET;
const SEARCH_CHAT_PUSH_QUEUED_OFFSET = @import("app_state.zig").SEARCH_CHAT_PUSH_QUEUED_OFFSET;
const SEARCH_VOICE_REPLAY_OFFSET = @import("app_state.zig").SEARCH_VOICE_REPLAY_OFFSET;
const REMIND_PRESET_CUSTOM = @import("app_state.zig").REMIND_PRESET_CUSTOM;
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
const MAX_SNIPPETS = @import("app_state.zig").MAX_SNIPPETS;
const MAX_WORKSPACES = @import("app_state.zig").MAX_WORKSPACES;
const SPAWN_TITLES = @import("app_state.zig").SPAWN_TITLES;
const defaultWorkspaceName = @import("workspaces.zig").defaultWorkspaceName;
const updateMainWindowTitle = @import("workspaces.zig").updateMainWindowTitle;
const findWorkspace = @import("workspaces.zig").findWorkspace;
const addOrUpdateWorkspace = @import("workspaces.zig").addOrUpdateWorkspace;
const loadWorkspaceRegistry = @import("workspaces.zig").loadWorkspaceRegistry;
const ReleaseMutex = @import("win32.zig").ReleaseMutex;
const windowOwnerProcessStillActive = @import("workspaces.zig").windowOwnerProcessStillActive;
const findMyWorkspaceSlot = @import("workspaces.zig").findMyWorkspaceSlot;
const findAndFocusWorkspaceWindow = @import("workspaces.zig").findAndFocusWorkspaceWindow;
const deleteWorkspaceByIndex = @import("workspaces.zig").deleteWorkspaceByIndex;
const saveWorkspaceRegistry = @import("workspaces.zig").saveWorkspaceRegistry;
const gcDefaultNamedWindowOnClose = @import("workspaces.zig").gcDefaultNamedWindowOnClose;
const setWorkspaceRestoreAndSave = @import("workspaces.zig").setWorkspaceRestoreAndSave;
const ensureCurrentWorkspaceRegistered = @import("workspaces.zig").ensureCurrentWorkspaceRegistered;
const ensureWorkspaceSlotId = @import("workspaces.zig").ensureWorkspaceSlotId;
const syncInProcessWorkspacesToRegistry = @import("workspaces.zig").syncInProcessWorkspacesToRegistry;
const removeMyHostedEntriesAndSave = @import("workspaces.zig").removeMyHostedEntriesAndSave;
const reconcileWorkspaceRegistry = @import("workspaces.zig").reconcileWorkspaceRegistry;
const migrateWorkspacesFromSessionFiles = @import("workspaces.zig").migrateWorkspacesFromSessionFiles;
const spawnWorkspaceWindow = @import("workspaces.zig").spawnWorkspaceWindow;
const moveSingleTabToNewWorkspace = @import("workspaces.zig").moveSingleTabToNewWorkspace;
const moveSelectedTabsToNewWorkspace = @import("workspaces.zig").moveSelectedTabsToNewWorkspace;
const moveTabToPill = @import("workspaces.zig").moveTabToPill;
const moveSelectedTabsToPill = @import("workspaces.zig").moveSelectedTabsToPill;
const moveTabToClosedWorkspace = @import("workspaces.zig").moveTabToClosedWorkspace;
const moveSelectedTabsToClosedWorkspace = @import("workspaces.zig").moveSelectedTabsToClosedWorkspace;
const newPillForMove = @import("workspaces.zig").newPillForMove;
const selectStartupWorkspaceFromRegistry = @import("workspaces.zig").selectStartupWorkspaceFromRegistry;
const restoreRegisteredWorkspaceWindows = @import("workspaces.zig").restoreRegisteredWorkspaceWindows;
const verboseLoggingEnabled = @import("diagnostics.zig").verboseLoggingEnabled;
const debugLog = @import("diagnostics.zig").debugLog;
const browserTrace = @import("diagnostics.zig").browserTrace;
const browserTraceN = @import("diagnostics.zig").browserTraceN;
const altqLog = @import("diagnostics.zig").altqLog;
const altqPtr = @import("diagnostics.zig").altqPtr;
const logSessionAudit = @import("diagnostics.zig").logSessionAudit;
const logSessionAuditAlways = @import("diagnostics.zig").logSessionAuditAlways;
const decideShellExit = @import("shell_exit.zig").decide;
const appendDecimal = @import("diagnostics.zig").appendDecimal;
const logSlowMs = @import("diagnostics.zig").logSlowMs;
const saveSession = @import("session.zig").saveSession;
const captureSessionLayout = @import("account_desktop.zig").captureSessionLayout;
const TIMER_ACCOUNT = @import("app_state.zig").TIMER_ACCOUNT;
const TIMER_FONT_SYNC = @import("app_state.zig").TIMER_FONT_SYNC;
const TIMER_UPDATE_CHECK = @import("app_state.zig").TIMER_UPDATE_CHECK;
const TIMER_ACCOUNT_SAVE = @import("app_state.zig").TIMER_ACCOUNT_SAVE;
const startAccountJob = @import("account_desktop.zig").startAccountJob;
const pullSessionLayout = @import("account_desktop.zig").pullSessionLayout;
const accountPush = @import("account_desktop.zig").accountPush;
const accountSignOut = @import("account_desktop.zig").accountSignOut;
const accountSignIn = @import("account_desktop.zig").accountSignIn;
const accountCancelSignIn = @import("account_desktop.zig").accountCancelSignIn;
const applyServerLayout = @import("account_desktop.zig").applyServerLayout;
const handleLayoutReply = @import("account_desktop.zig").handleLayoutReply;
const paintAccountLock = @import("account_desktop.zig").paintAccountLock;
const accountButtonRect = @import("account_desktop.zig").accountButtonRect;
const accountBootstrap = @import("account_desktop.zig").accountBootstrap;
const restoreSession = @import("session.zig").restoreSession;
const GetClassNameW = @import("win32.zig").GetClassNameW;
const applyBlackConsoleBackground = @import("console.zig").applyBlackConsoleBackground;
const applyConsoleThemeToAllShells = @import("console.zig").applyConsoleThemeToAllShells;
const mainWindowDpi = @import("console.zig").mainWindowDpi;
const syncMainWindowDpi = @import("console.zig").syncMainWindowDpi;
const baseFont96 = @import("console.zig").baseFont96;
const fontSyncMarkAllStale = @import("console.zig").fontSyncMarkAllStale;
const fontSyncActiveNow = @import("console.zig").fontSyncActiveNow;
const fontSyncTimerTick = @import("console.zig").fontSyncTimerTick;
const devCycleConsoleFont = @import("console.zig").devCycleConsoleFont;
const devCycleConsoleSize = @import("console.zig").devCycleConsoleSize;
const devAdjustConsoleSize = @import("console.zig").devAdjustConsoleSize;
const WM_CLOSE = @import("app_state.zig").WM_CLOSE;
const WM_PARENTNOTIFY = @import("app_state.zig").WM_PARENTNOTIFY;
const unarchiveHiddenWorkspaceSessions = @import("console.zig").unarchiveHiddenWorkspaceSessions;
const commitArchivedSessionReturn = @import("console.zig").commitArchivedSessionReturn;
const rememberOpenWorkspaceForQuit = @import("console.zig").rememberOpenWorkspaceForQuit;
const quitAllZigShellWindows = @import("console.zig").quitAllZigShellWindows;
const cleanupStaleWindows = @import("console.zig").cleanupStaleWindows;
const SSH_ERROR_MODE = @import("app_state.zig").SSH_ERROR_MODE;
const resolveSshPath = @import("console.zig").resolveSshPath;
const sshSpawnFailed = @import("console.zig").sshSpawnFailed;
const maintainTunnelKeepers = @import("console.zig").maintainTunnelKeepers;
const closeTunnelKeepers = @import("console.zig").closeTunnelKeepers;
const spawnShell = @import("console.zig").spawnShell;
const spawnShellFromMenuIndex = @import("console.zig").spawnShellFromMenuIndex;
const voiceSapiStart = @import("voice.zig").voiceSapiStart;
const voiceSpeak = @import("voice.zig").voiceSpeak;
const voiceStopSpeaking = @import("voice.zig").voiceStopSpeaking;
const voiceIsSpeaking = @import("voice.zig").voiceIsSpeaking;
const voiceSpeedLabel = @import("voice.zig").voiceSpeedLabel;
const voiceTtsDeviceStop = @import("voice.zig").voiceTtsDeviceStop;
const registerJumpList = @import("workspaces.zig").registerJumpList;
const setWindowTaskbarIdentity = @import("workspaces.zig").setWindowTaskbarIdentity;
const spawnNewWindow = @import("workspaces.zig").spawnNewWindow;
const spawnEmptyWorkspace = @import("workspaces.zig").spawnEmptyWorkspace;
const detachTabToNewWindow = @import("workspaces.zig").detachTabToNewWindow;
const detachTabToExistingWindow = @import("workspaces.zig").detachTabToExistingWindow;
const reopenLastClosedShell = @import("workspaces.zig").reopenLastClosedShell;
const registerShellExitWait = @import("workspaces.zig").registerShellExitWait;
const ensureCapacityPolicyStarter = @import("capacity.zig").ensureCapacityPolicyStarter;
const loadCapacityPolicy = @import("capacity.zig").loadCapacityPolicy;
const openCommandsJsonInEditor = @import("command_palette.zig").openCommandsJsonInEditor;
const loadCustomCommandsIfChanged = @import("command_palette.zig").loadCustomCommandsIfChanged;
const loadPaletteUsage = @import("command_palette.zig").loadPaletteUsage;
const recordPaletteUsage = @import("command_palette.zig").recordPaletteUsage;
const loadArchiveFromDisk = @import("archive.zig").loadArchiveFromDisk;
const resurrectArchivedByKey = @import("archive.zig").resurrectArchivedByKey;
const applyCanonicalSessionRename = @import("archive.zig").applyCanonicalSessionRename;
const syncActiveShellNameFromLiveTitle = @import("archive.zig").syncActiveShellNameFromLiveTitle;
const archiveTabAt = @import("archive.zig").archiveTabAt;
const archiveActiveTab = @import("archive.zig").archiveActiveTab;
const closeNonTmuxTabAt = @import("archive.zig").closeNonTmuxTabAt;
const archiveArmOrCommit = @import("archive.zig").archiveArmOrCommit;
const endTmuxSessionAt = @import("archive.zig").endTmuxSessionAt;
const endActiveTmuxSession = @import("archive.zig").endActiveTmuxSession;
const loadSnippetsIfChanged = @import("snippets.zig").loadSnippetsIfChanged;
const pasteSnippet = @import("snippets.zig").pasteSnippet;
const deleteSnippet = @import("snippets.zig").deleteSnippet;
const openSnippetCreateForm = @import("snippets.zig").openSnippetCreateForm;
const closeSnippetCreateForm = @import("snippets.zig").closeSnippetCreateForm;
const saveSnippetFromForm = @import("snippets.zig").saveSnippetFromForm;
const snippetFormContainsPoint = @import("snippets.zig").snippetFormContainsPoint;
const snippetFormButtonHit = @import("snippets.zig").snippetFormButtonHit;
const MAX_REMINDERS = @import("app_state.zig").MAX_REMINDERS;
const loadRemindersIfNeeded = @import("reminders.zig").loadRemindersIfNeeded;
const copyAsciiField = @import("reminders.zig").copyAsciiField;
const restoreReminderByIndex = @import("reminders.zig").restoreReminderByIndex;
const snoozeShellUntil = @import("reminders.zig").snoozeShellUntil;
const bringBackAllSessions = @import("reminders.zig").bringBackAllSessions;
const loadSnoozedWorkspaces = @import("reminders.zig").loadSnoozedWorkspaces;
const snoozeWorkspaceUntil = @import("reminders.zig").snoozeWorkspaceUntil;
const wakeWorkspaceByIndex = @import("reminders.zig").wakeWorkspaceByIndex;
const checkDueReminders = @import("reminders.zig").checkDueReminders;
const remindPresetDue = @import("reminders.zig").remindPresetDue;
const parseReminderDue = @import("reminders.zig").parseReminderDue;
const spawnCustomCmd = @import("command_palette.zig").spawnCustomCmd;
const spawnWorkspaceTmuxSession = @import("command_palette.zig").spawnWorkspaceTmuxSession;
const spawnCodexTmuxSession = @import("command_palette.zig").spawnCodexTmuxSession;
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;
const notifyTabCapReached = @import("console.zig").notifyTabCapReached;
const spawnShellWithSession = @import("console.zig").spawnShellWithSession;
const respawnShellInPlace = @import("console.zig").respawnShellInPlace;
const markSshTabDisconnected = @import("console.zig").markSshTabDisconnected;
const markPinnedLocalTabDisconnected = @import("console.zig").markPinnedLocalTabDisconnected;
const reconnectSshTabsAfterResume = @import("console.zig").reconnectSshTabsAfterResume;
const startFaviconFetch = @import("vps.zig").startFaviconFetch;
const fetchTmuxSessions = @import("vps.zig").fetchTmuxSessions;
const closeAllVpsPersistentChannels = @import("vps.zig").closeAllVpsPersistentChannels;
const closeAllAcChannels = @import("vps.zig").closeAllAcChannels;
const ensureVpsPollLeadership = @import("vps.zig").ensureVpsPollLeadership;
const releaseVpsPollLeadership = @import("vps.zig").releaseVpsPollLeadership;
const writeVpsPollCache = @import("vps.zig").writeVpsPollCache;
const loadVpsPollCacheIfChanged = @import("vps.zig").loadVpsPollCacheIfChanged;
const syncLiveTmuxMetadataFromCache = @import("vps.zig").syncLiveTmuxMetadataFromCache;
const buildFilteredTmux = @import("vps.zig").buildFilteredTmux;
const inactiveTmuxCountForHost = @import("vps.zig").inactiveTmuxCountForHost;
const pathUnderFolder = @import("vps.zig").pathUnderFolder;
const focusedSessionFolder = @import("vps.zig").focusedSessionFolder;
const workspacePrimaryRepo = @import("vps.zig").workspacePrimaryRepo;
const countFolderSessions = @import("vps.zig").countFolderSessions;
const SessionOverviewKind = @import("app_state.zig").SessionOverviewKind;
const AS_TAB_ALL = @import("app_state.zig").AS_TAB_ALL;
const AS_TAB_ARCHIVED = @import("app_state.zig").AS_TAB_ARCHIVED;
const buildSessionOverviewRows = @import("archive.zig").buildSessionOverviewRows;
const allSessionsRowVisible = @import("archive.zig").allSessionsRowVisible;
const allSessionsListTop = @import("archive.zig").allSessionsListTop;
const allSessionsVisibleCount = @import("archive.zig").allSessionsVisibleCount;
const allSessionsNthVisible = @import("archive.zig").allSessionsNthVisible;
const allSessionsSplitVisible = @import("archive.zig").allSessionsSplitVisible;
const openAllSessions = @import("archive.zig").openAllSessions;
const closeAllSessions = @import("archive.zig").closeAllSessions;
const openAllSessionsFilter = @import("archive.zig").openAllSessionsFilter;
const closeAllSessionsFilter = @import("archive.zig").closeAllSessionsFilter;
const allSessionsJump = @import("archive.zig").allSessionsJump;
const handleAllSessionsKey = @import("archive.zig").handleAllSessionsKey;
const startUnarchiveUnattachedWorkspaceSessions = @import("archive.zig").startUnarchiveUnattachedWorkspaceSessions;
const unarchiveNextUnattachedSession = @import("archive.zig").unarchiveNextUnattachedSession;
const activateSessionOverviewRow = @import("archive.zig").activateSessionOverviewRow;
const killProcessTree = @import("console.zig").killProcessTree;
const closeShell = @import("console.zig").closeShell;
const clampSidebarScroll = @import("console.zig").clampSidebarScroll;
const ensureActiveVisible = @import("console.zig").ensureActiveVisible;
const switchToShell = @import("console.zig").switchToShell;
const nthVisibleShell = @import("console.zig").nthVisibleShell;
const workspaceDisplayName = @import("workspaces.zig").workspaceDisplayName;
const switchToWorkspace = @import("workspaces.zig").switchToWorkspace;
const copyBlueDotHookInstructions = @import("workspaces.zig").copyBlueDotHookInstructions;
const copyBrowserControlInstructions = @import("workspaces.zig").copyBrowserControlInstructions;
const recordShellDiagEvent = @import("workspaces.zig").recordShellDiagEvent;
const copyActiveShellDiagnostics = @import("workspaces.zig").copyActiveShellDiagnostics;
const toggleSingleWindowMode = @import("workspaces.zig").toggleSingleWindowMode;
const newWorkspace = @import("workspaces.zig").newWorkspace;
const swapWorkspaceSlots = @import("workspaces.zig").swapWorkspaceSlots;
const persistWorkspaceOrder = @import("workspaces.zig").persistWorkspaceOrder;
const closeMyWorkspaceSlot = @import("workspaces.zig").closeMyWorkspaceSlot;
const absorbWorkspaceIntoSlots = @import("workspaces.zig").absorbWorkspaceIntoSlots;
const keybd_event = @import("win32.zig").keybd_event;
const VK_MENU = @import("app_state.zig").VK_MENU;
const KEYEVENTF_KEYUP = @import("app_state.zig").KEYEVENTF_KEYUP;
const focusActiveShell = @import("focus.zig").focusActiveShell;
const activeShellHasForegroundFocus = @import("focus.zig").activeShellHasForegroundFocus;
const focusActiveBrowserPane = @import("focus.zig").focusActiveBrowserPane;
const cancelPendingNativeBrowserFocus = @import("focus.zig").cancelPendingNativeBrowserFocus;
const requestNativeBrowserFocus = @import("focus.zig").requestNativeBrowserFocus;
const requestShellRefocus = @import("focus.zig").requestShellRefocus;
const cancelShellRefocus = @import("focus.zig").cancelShellRefocus;
const systemAltTabSuppressionActive = @import("focus.zig").systemAltTabSuppressionActive;
const browserSlotReserved = @import("browser_pane.zig").browserSlotReserved;
const activeBrowserHwndLive = @import("browser_pane.zig").activeBrowserHwndLive;
const activeBrowserHasForegroundFocus = @import("browser_pane.zig").activeBrowserHasForegroundFocus;
const activeBrowserTransientPopupHasForegroundFocus = @import("browser_pane.zig").activeBrowserTransientPopupHasForegroundFocus;
const ensureBrowserDefaultUrl = @import("browser_pane.zig").ensureBrowserDefaultUrl;
const browserUrlSlice = @import("browser_pane.zig").browserUrlSlice;
const writeCurrentThemeManifest = @import("browser_pane.zig").writeCurrentThemeManifest;
const browserHistoryNav = @import("browser_pane.zig").browserHistoryNav;
const runActiveBrowserShotUrl = @import("browser_pane.zig").runActiveBrowserShotUrl;
const pollBrowserUrlTick = @import("browser_pane.zig").pollBrowserUrlTick;
const navigateBrowserPane = @import("browser_pane.zig").navigateBrowserPane;
const navigateBrowserPaneWithActivation = @import("browser_pane.zig").navigateBrowserPaneWithActivation;
const openBrowserPaneForShell = @import("browser_pane.zig").openBrowserPaneForShell;
const setBrowserUrlFromSearch = @import("browser_pane.zig").setBrowserUrlFromSearch;
const calcBrowserLayout = @import("browser_pane.zig").calcBrowserLayout;
const browserSplitterHit = @import("browser_pane.zig").browserSplitterHit;
const setBrowserSplitFromMouse = @import("browser_pane.zig").setBrowserSplitFromMouse;
const wakeBrowserPaneFromFreeze = @import("browser_pane.zig").wakeBrowserPaneFromFreeze;
const browserHibernationTick = @import("browser_pane.zig").browserHibernationTick;
const cleanupStalePanewinFiles = @import("browser_pane.zig").cleanupStalePanewinFiles;
const handleBrowserWindowResolved = @import("browser_pane.zig").handleBrowserWindowResolved;
const BrowserDockJob = @import("app_state.zig").BrowserDockJob;
const finishBrowserDock = @import("browser_pane.zig").finishBrowserDock;
const launchBrowserForShell = @import("browser_pane.zig").launchBrowserForShell;
const enumCloseStrayZspane = @import("browser_pane.zig").enumCloseStrayZspane;
const adoptBrowserTick = @import("browser_pane.zig").adoptBrowserTick;
const browserChromeHiddenForOverlay = @import("browser_pane.zig").browserChromeHiddenForOverlay;
const hideAllBrowserChrome = @import("browser_pane.zig").hideAllBrowserChrome;
const browserHealthTick = @import("browser_pane.zig").browserHealthTick;
const updateBrowserVisibility = @import("browser_pane.zig").updateBrowserVisibility;
const relaunchActiveRestoredBrowserPane = @import("browser_pane.zig").relaunchActiveRestoredBrowserPane;
const closeBrowserForShell = @import("browser_pane.zig").closeBrowserForShell;
const finishBrowserEngineSwitch = @import("browser_pane.zig").finishBrowserEngineSwitch;
const switchBrowserEngine = @import("browser_pane.zig").switchBrowserEngine;
const discardBrowserUrlBarEdit = @import("browser_pane.zig").discardBrowserUrlBarEdit;
const sweepIdleBrowserPanes = @import("browser_pane.zig").sweepIdleBrowserPanes;
const hibernateAllParkedBrowserPanesNow = @import("browser_pane.zig").hibernateAllParkedBrowserPanesNow;
const browserPaneCoversSlot = @import("browser_pane.zig").browserPaneCoversSlot;
const browserPlaceholderRect = @import("browser_pane.zig").browserPlaceholderRect;
const paintBrowserPlaceholder = @import("browser_pane.zig").paintBrowserPlaceholder;
const paintBrowserSplitter = @import("browser_pane.zig").paintBrowserSplitter;
const activePaneBorderOn = @import("browser_pane.zig").activePaneBorderOn;
const paintActivePaneBorder = @import("browser_pane.zig").paintActivePaneBorder;
const invalidateBrowserBottomMask = @import("browser_pane.zig").invalidateBrowserBottomMask;
const browserChromeForegroundAllowed = @import("browser_pane.zig").browserChromeForegroundAllowed;
const browserChromeCanStayVisible = @import("browser_pane.zig").browserChromeCanStayVisible;
const hideBrowserChromeIfNotForeground = @import("browser_pane.zig").hideBrowserChromeIfNotForeground;
const hideBrowserEdgeMasks = @import("browser_pane.zig").hideBrowserEdgeMasks;
const suspendBrowserEdgeMaskRaiseForPopup = @import("browser_pane.zig").suspendBrowserEdgeMaskRaiseForPopup;
const raiseBrowserEdgeMasksZOrderOnly = @import("browser_pane.zig").raiseBrowserEdgeMasksZOrderOnly;
const refreshBrowserEdgeMasks = @import("browser_pane.zig").refreshBrowserEdgeMasks;
const armBrowserEdgeMaskRaise = @import("browser_pane.zig").armBrowserEdgeMaskRaise;
const startBrowserUrlBarEdit = @import("browser_pane.zig").startBrowserUrlBarEdit;
const webView2OwnsActiveShell = @import("browser_pane.zig").webView2OwnsActiveShell;
const webView2HasInputFocus = @import("browser_pane.zig").webView2HasInputFocus;
const cursorInsideWebView2 = @import("browser_pane.zig").cursorInsideWebView2;
const focusActiveWebView2 = @import("browser_pane.zig").focusActiveWebView2;
const requestWebView2Focus = @import("browser_pane.zig").requestWebView2Focus;
const closeWebView2 = @import("browser_pane.zig").closeWebView2;
const openWebView2Tab = @import("browser_pane.zig").openWebView2Tab;
const toggleWebView2 = @import("browser_pane.zig").toggleWebView2;
const chatViewLayout = @import("chat_composer.zig").chatViewLayout;
const pointInRect = @import("chat_composer.zig").pointInRect;
const chatViewOwnsInput = @import("chat_composer.zig").chatViewOwnsInput;
const chatComposerFocusAllowed = @import("chat_composer.zig").chatComposerFocusAllowed;
const chatFocusDrifted = @import("chat_composer.zig").chatFocusDrifted;
const chatPaletteToggleKeyDown = @import("chat_composer.zig").chatPaletteToggleKeyDown;
const paletteAcceptsChar = @import("chat_composer.zig").paletteAcceptsChar;
const postPaletteToggle = @import("chat_composer.zig").postPaletteToggle;
const chatButtonAt = @import("chat_composer.zig").chatButtonAt;
const refreshChatBrushes = @import("chat_composer.zig").refreshChatBrushes;
const TIMER_CHAT_BENCH = @import("app_state.zig").TIMER_CHAT_BENCH;
const chatBenchInit = @import("chat_session.zig").chatBenchInit;
const chatBenchEnabled = @import("chat_session.zig").chatBenchEnabled;
const chatBenchTick = @import("chat_session.zig").chatBenchTick;
const closeAllChatHistoryChannels = @import("chat_session.zig").closeAllChatHistoryChannels;
const chatFileOnReady = @import("chat_session.zig").chatFileOnReady;
const chatRefreshAfterFontChange = @import("chat_session.zig").chatRefreshAfterFontChange;
const chatSwitchBrowserTick = @import("chat_session.zig").chatSwitchBrowserTick;
const chatSwitchLogBrowserShown = @import("chat_session.zig").chatSwitchLogBrowserShown;
const refreshChatTranscript = @import("chat_session.zig").refreshChatTranscript;
const chatScrollBy = @import("chat_render.zig").chatScrollBy;
const WM_APP_CHAT_IMAGE_READY = @import("app_state.zig").WM_APP_CHAT_IMAGE_READY;
const WM_APP_CHAT_ATTACH = @import("app_state.zig").WM_APP_CHAT_ATTACH;
const WM_APP_CHAT_ATTACH_FAILED = @import("app_state.zig").WM_APP_CHAT_ATTACH_FAILED;
const SEARCH_CHAT_ATTACH_OFFSET = @import("app_state.zig").SEARCH_CHAT_ATTACH_OFFSET;
const chatImageReady = @import("chat_render.zig").chatImageReady;
const chatAttachErrorText = @import("chat_render.zig").chatAttachErrorText;
const chatAttachPick = @import("chat_render.zig").chatAttachPick;
const shotFocusTick = @import("chat_render.zig").shotFocusTick;
const chatCopyLatestCode = @import("chat_render.zig").chatCopyLatestCode;
const chatSelectAll = @import("chat_render.zig").chatSelectAll;
const chatCopySelection = @import("chat_render.zig").chatCopySelection;
const layoutChatControls = @import("chat_composer.zig").layoutChatControls;
const chatAcRequest = @import("chat_composer.zig").chatAcRequest;
const chatAcOnFetchDone = @import("chat_composer.zig").chatAcOnFetchDone;
const chatAcOpenBrowse = @import("chat_composer.zig").chatAcOpenBrowse;
const loadPaletteSkills = @import("chat_composer.zig").loadPaletteSkills;
const selectChatSkill = @import("chat_composer.zig").selectChatSkill;
const chatSendVerifyTick = @import("chat_send.zig").chatSendVerifyTick;
const sendChatPrompt = @import("chat_send.zig").sendChatPrompt;
const loadChatOutbox = @import("chat_send.zig").loadChatOutbox;
const chatResetForShell = @import("chat_send.zig").chatResetForShell;
const chatEchoPushQueuedNow = @import("chat_send.zig").chatEchoPushQueuedNow;
const chatEchoRetryAllForActive = @import("chat_send.zig").chatEchoRetryAllForActive;
const chatEchoDiscardUnsentForActive = @import("chat_send.zig").chatEchoDiscardUnsentForActive;
const chatOutboxTick = @import("chat_send.zig").chatOutboxTick;
const chatOutboxFlushActiveNow = @import("chat_send.zig").chatOutboxFlushActiveNow;
const chatOutboxClearActive = @import("chat_send.zig").chatOutboxClearActive;
const sshAutoReconnectTick = @import("chat_send.zig").sshAutoReconnectTick;
const chatViewShouldShowForTab = @import("chat_composer.zig").chatViewShouldShowForTab;
const showShellConsole = @import("chat_composer.zig").showShellConsole;
const openChatView = @import("chat_composer.zig").openChatView;
const closeChatView = @import("chat_composer.zig").closeChatView;
const chatDraftFlush = @import("chat_composer.zig").chatDraftFlush;
const toggleChatView = @import("chat_composer.zig").toggleChatView;
const invalidateChatHeader = @import("chat_composer.zig").invalidateChatHeader;
const voiceStartListening = @import("voice.zig").voiceStartListening;
const voiceScheduleTurnEnd = @import("voice.zig").voiceScheduleTurnEnd;
const voiceCheckScreenFallback = @import("voice.zig").voiceCheckScreenFallback;
const voiceOnTurnEnd = @import("voice.zig").voiceOnTurnEnd;
const voiceReadReply = @import("voice.zig").voiceReadReply;
const setVoiceModeActive = @import("voice.zig").setVoiceModeActive;
const VoiceResult = @import("app_state.zig").VoiceResult;
const voiceMicStop = @import("voice.zig").voiceMicStop;
const voiceMicStart = @import("voice.zig").voiceMicStart;
const voiceHandleSpeechStart = @import("voice.zig").voiceHandleSpeechStart;
const voiceHandleUtterance = @import("voice.zig").voiceHandleUtterance;
const repositionActive = @import("window_layout.zig").repositionActive;
const invalidateSidebar = @import("window_layout.zig").invalidateSidebar;
const chatWorkingIndicatorSync = @import("window_layout.zig").chatWorkingIndicatorSync;
const paintChatView = @import("window_layout.zig").paintChatView;
const invalidateSpinnerRects = @import("window_layout.zig").invalidateSpinnerRects;
const startWindowRename = @import("rename.zig").startWindowRename;
const startRename = @import("rename.zig").startRename;
const beginPaletteRenameInput = @import("rename.zig").beginPaletteRenameInput;
const startThreadTitleRename = @import("rename.zig").startThreadTitleRename;
const startGroupRename = @import("rename.zig").startGroupRename;
const commitRename = @import("rename.zig").commitRename;
const openTabContextPalette = @import("rename.zig").openTabContextPalette;
const showGroupHeaderMenu = @import("rename.zig").showGroupHeaderMenu;
const clearSearchBackdrop = @import("rename.zig").clearSearchBackdrop;
const hideShellsForOverlay = @import("rename.zig").hideShellsForOverlay;
const showActiveShellAfterOverlay = @import("rename.zig").showActiveShellAfterOverlay;
const applySearchSpawnContext = @import("rename.zig").applySearchSpawnContext;
const captureSearchBackdrop = @import("rename.zig").captureSearchBackdrop;
const CHANGELOG = @import("changelog.zig").CHANGELOG;
const calcChangelogLayout = @import("changelog.zig").calcChangelogLayout;
const changelogContainsPoint = @import("changelog.zig").changelogContainsPoint;
const changelogHitTest = @import("changelog.zig").changelogHitTest;
const moveChangelogSelection = @import("changelog.zig").moveChangelogSelection;
const openAsciiUrlInDefaultBrowser = @import("changelog.zig").openAsciiUrlInDefaultBrowser;
const UsageLoginAccount = @import("app_state.zig").UsageLoginAccount;
const showUsageAccountLogin = @import("telemetry_panel.zig").showUsageAccountLogin;
const ensureUsageTelemetryCollector = @import("telemetry_panel.zig").ensureUsageTelemetryCollector;
const requestAiPaceRefresh = @import("telemetry_panel.zig").requestAiPaceRefresh;
const startLadderMode = @import("telemetry_panel.zig").startLadderMode;
const cycleSidebarStatusCard = @import("telemetry_panel.zig").cycleSidebarStatusCard;
const changelogDefaultTicket = @import("changelog.zig").changelogDefaultTicket;
const openChangelogTicket = @import("changelog.zig").openChangelogTicket;
const resetPaintBackbuffer = @import("drawing.zig").resetPaintBackbuffer;
const ensurePaintBackbuffer = @import("drawing.zig").ensurePaintBackbuffer;
const resetFontCache = @import("drawing.zig").resetFontCache;
const resetGdiCache = @import("drawing.zig").resetGdiCache;
const uiScaled = @import("drawing.zig").uiScaled;
const uiUnscaled = @import("drawing.zig").uiUnscaled;
const searchRowH = @import("drawing.zig").searchRowH;
const searchInputH = @import("drawing.zig").searchInputH;
const searchOverlayW = @import("drawing.zig").searchOverlayW;
const searchOverlayOx = @import("drawing.zig").searchOverlayOx;
const searchResultRowAtClientPoint = @import("drawing.zig").searchResultRowAtClientPoint;
const paintSidebar = @import("sidebar.zig").paintSidebar;
const keepSearchSelectionVisible = @import("command_palette.zig").keepSearchSelectionVisible;
const updateSearchResults = @import("command_palette.zig").updateSearchResults;
const BROWSER_SHORTCUT_OPEN_GUARD_MS = @import("app_state.zig").BROWSER_SHORTCUT_OPEN_GUARD_MS;
const claimBrowserToggleEvent = @import("shortcuts.zig").claimBrowserToggleEvent;
const physicalBrowserShortcutMayClose = @import("shortcuts.zig").physicalBrowserShortcutMayClose;
const physicalBrowserShortcutShouldRecover = @import("shortcuts.zig").physicalBrowserShortcutShouldRecover;
const startStaleAltMouseHookThread = @import("shortcuts.zig").startStaleAltMouseHookThread;
const recordNativeBrowserDropGesture = @import("shortcuts.zig").recordNativeBrowserDropGesture;
const openUrlAtScreenPoint = @import("clipboard.zig").openUrlAtScreenPoint;
const copyClaudeLoginUrlFromActiveShell = @import("clipboard.zig").copyClaudeLoginUrlFromActiveShell;
const openUrlByIndex = @import("clipboard.zig").openUrlByIndex;
const openUrlPicker = @import("clipboard.zig").openUrlPicker;
const closeUrlPicker = @import("clipboard.zig").closeUrlPicker;
const closeUrlPickerForBrowser = @import("clipboard.zig").closeUrlPickerForBrowser;
const closeChangelogOverlay = @import("changelog.zig").closeChangelogOverlay;
const SPINNER_STALE_MS = @import("app_state.zig").SPINNER_STALE_MS;
const startSpinnerTimerIfNeeded = @import("clipboard.zig").startSpinnerTimerIfNeeded;
const pasteClipboardToShell = @import("clipboard.zig").pasteClipboardToShell;
const dictationAudit = @import("voice.zig").dictationAudit;
const handleDictationReady = @import("voice.zig").handleDictationReady;
const toggleDictation = @import("voice.zig").toggleDictation;
const handleShotPaste = @import("clipboard.zig").handleShotPaste;
const sendCtrlCToShell = @import("clipboard.zig").sendCtrlCToShell;
const copyConsoleSelectionToClipboard = @import("clipboard.zig").copyConsoleSelectionToClipboard;
const copySelectionOrSendCtrlC = @import("clipboard.zig").copySelectionOrSendCtrlC;
const SetTimer = @import("win32.zig").SetTimer;
const KillTimer = @import("win32.zig").KillTimer;
const parseNotifyArg = @import("notifications.zig").parseNotifyArg;
const sendNotify = @import("notifications.zig").sendNotify;
const parseSyncAuthCallbackArg = @import("account_desktop.zig").parseSyncAuthCallbackArg;
const handleSyncAuthCallback = @import("account_desktop.zig").handleSyncAuthCallback;
const runVaultFlowProcess = @import("account_desktop.zig").runVaultFlowProcess;
const parseSyncVaultUnlockArg = @import("account_desktop.zig").parseSyncVaultUnlockArg;
const notifyListenerThread = @import("notifications.zig").notifyListenerThread;
const handleZsbWhoRequest = @import("browser_bridge.zig").handleZsbWhoRequest;
const handleDiagRequest = @import("browser_bridge.zig").handleDiagRequest;
const handleZsbOpenRequest = @import("browser_bridge.zig").handleZsbOpenRequest;
const handleShowSidebarRequest = @import("browser_bridge.zig").handleShowSidebarRequest;
const forceRebindZsbForShell = @import("browser_bridge.zig").forceRebindZsbForShell;
const handleZsbBindRequest = @import("browser_bridge.zig").handleZsbBindRequest;
const startTunnelInboundListener = @import("browser_bridge.zig").startTunnelInboundListener;
const findLocalTmuxTab = @import("notifications.zig").findLocalTmuxTab;
const pollNotifications = @import("notifications.zig").pollNotifications;
const anyShellHasEta = @import("notifications.zig").anyShellHasEta;
const loadEtaAccuracy = @import("notifications.zig").loadEtaAccuracy;
const publishInboxState = @import("inbox.zig").publishInboxState;
const toggleInboxExcluded = @import("inbox.zig").toggleInboxExcluded;
const publishInboxStateNow = @import("inbox.zig").publishInboxStateNow;
const deleteInboxStateFile = @import("inbox.zig").deleteInboxStateFile;
const loadInboxModel = @import("inbox.zig").loadInboxModel;
const toggleFavorite = @import("inbox.zig").toggleFavorite;
const inboxRowVisible = @import("inbox.zig").inboxRowVisible;
const inboxListTop = @import("inbox.zig").inboxListTop;
const inboxSplitVisible = @import("inbox.zig").inboxSplitVisible;
const inboxVisibleCount = @import("inbox.zig").inboxVisibleCount;
const inboxNthVisible = @import("inbox.zig").inboxNthVisible;
const findShellById = @import("inbox.zig").findShellById;
const openInbox = @import("inbox.zig").openInbox;
const closeInbox = @import("inbox.zig").closeInbox;
const openInboxFilter = @import("inbox.zig").openInboxFilter;
const closeInboxFilter = @import("inbox.zig").closeInboxFilter;
const toggleInbox = @import("inbox.zig").toggleInbox;
const armInboxStepContext = @import("inbox.zig").armInboxStepContext;
const jumpToInboxRow = @import("inbox.zig").jumpToInboxRow;
const inboxJump = @import("inbox.zig").inboxJump;
const inboxStepJump = @import("inbox.zig").inboxStepJump;
const refreshNextUnreadCache = @import("inbox.zig").refreshNextUnreadCache;
const jumpToFirstUnreadThread = @import("inbox.zig").jumpToFirstUnreadThread;
const inboxUndoLastArchive = @import("inbox.zig").inboxUndoLastArchive;
const handleInboxKey = @import("inbox.zig").handleInboxKey;
const pollShellNames = @import("shell_poll.zig").pollShellNames;

comptime {
    if (@import("builtin").is_test) {
        _ = @import("win32.zig");
        _ = @import("app_state.zig");
        _ = @import("power.zig");
        _ = @import("monitor.zig");
        _ = @import("startup.zig");
        _ = @import("launch_plan.zig");
        _ = @import("launch_snapshot.zig");
        _ = @import("console.zig");
        _ = @import("sidebar.zig");
        _ = @import("themes.zig");
        _ = @import("browser_pane.zig");
        _ = @import("capacity.zig");
        _ = @import("update_card.zig");
        _ = @import("focus.zig");
        _ = @import("shortcuts.zig");
        _ = @import("shell_poll.zig");
        _ = @import("shell_exit.zig");
        _ = @import("session.zig");
        _ = @import("file_io.zig");
        _ = @import("workspaces.zig");
        _ = @import("diagnostics.zig");
        _ = @import("account_desktop.zig");
        _ = @import("voice.zig");
        _ = @import("command_palette.zig");
        _ = @import("archive.zig");
        _ = @import("snippets.zig");
        _ = @import("reminders.zig");
        _ = @import("vps.zig");
        _ = @import("chat_composer.zig");
        _ = @import("chat_capture.zig");
        _ = @import("chat_session.zig");
        _ = @import("chat_render.zig");
        _ = @import("chat_find_ui.zig");
        _ = @import("chat_send.zig");
        _ = @import("window_layout.zig");
        _ = @import("rename.zig");
        _ = @import("changelog.zig");
        _ = @import("drawing.zig");
        _ = @import("smooth.zig");
        _ = @import("telemetry_panel.zig");
        _ = @import("clipboard.zig");
        _ = @import("notifications.zig");
        _ = @import("browser_bridge.zig");
        _ = @import("inbox.zig");
    }
}

const std = @import("std");
const json_reader = @import("json_reader.zig");
const link_detect = @import("link_detect.zig");
const tmux_identity = @import("tmux_identity.zig");
const duplex = @import("voice_duplex.zig");
const voice_filter = @import("voice_filter.zig");
const archive_rules = @import("archive_rules.zig");
const attention_rules = @import("attention_rules.zig");
const build_config = @import("build_config");
const skill_model = @import("skills.zig");
const chat_complete = @import("chat_complete.zig");
const chat_markdown = @import("chat_markdown.zig");
const chat_transcript = @import("chat_transcript.zig");
const chat_switch = @import("chat_switch.zig");
const chat_history = @import("chat_history.zig");
const chat_echo = @import("chat_echo.zig");
const chat_style = @import("chat_style.zig");
const chat_code = @import("chat_code.zig");
const sync_auth = @import("sync_auth.zig");
const session_layout = @import("session_layout.zig");
const account_layout = @import("account_layout.zig");
const account_state = @import("account_state.zig");
const account_client = @import("account_client.zig");
const sync_protocol = @import("sync_protocol.zig");
const sync_vault = @import("sync_vault.zig");
pub const IS_DEV = if (@hasDecl(build_config, "is_dev")) build_config.is_dev else false;
pub const LOOK_UNIFIED = true;
pub const BROWSER_EDGE_MASKS = true;
pub const APP_VERSION = "0.28.794";
const update_check = @import("update_check.zig");
const usage_telemetry = @import("usage_telemetry.zig");
const usage_telemetry_mode = @import("usage_telemetry_mode.zig");
pub export const mp_version_marker: [("MPVERSION=" ++ APP_VERSION ++ ";").len]u8 = ("MPVERSION=" ++ APP_VERSION ++ ";").*;
const workspace_snooze = @import("workspace_snooze.zig");
const reminders_load = @import("reminders_load.zig");
const crash_recorder = @import("crash_recorder.zig");

pub const std_options: std.Options = .{ .enable_segfault_handler = false };
fn crashPanic(msg: []const u8, first_trace_addr: ?usize) noreturn {
    crash_recorder.recordPanic(msg, first_trace_addr);
    std.process.abort();
}
fn crashSnapshot() crash_recorder.Snapshot {
    return .{ .tab_count = app_state.shell_count, .chat_view = app_state.g_chat_active, .debug_log_on = verboseLoggingEnabled(), .instance = getInstanceName() };
}
pub const panic = if (@import("builtin").is_test) std.debug.FullPanic(std.debug.defaultPanic) else std.debug.FullPanic(crashPanic);
pub const MULTIPROMPT_APP_ID = L("ValentinYeo.ZigShell");

const chat_image = @import("chat_image.zig");

const chat_image_insert = @import("chat_image_insert.zig");

fn exitWatchdog() void {
    Sleep(20000);
    @import("win32.zig").ExitProcess(0);
}

pub fn sessionFrontSelected() void {
    updateSessionFront(true);
}

pub fn sessionFrontChanged() void {
    updateSessionFront(false);
}

fn updateSessionFront(user: bool) void {
    const allowed = !launch_cache.pending and app_state.g_main_hwnd != null and !app_state.g_account_locked and !app_state.g_restoring and !app_state.g_startup_progress and !app_state.g_account_applying;
    const visible = !app_state.g_inbox_active and !app_state.g_all_sessions_active and !app_state.g_search_active and !app_state.g_shortcuts_active and !app_state.g_changelog_active and !app_state.g_url_picker_active;
    const sid: ?u32 = if (allowed and app_state.active_shell < app_state.shell_count and (!app_state.g_single_window or app_state.shells[app_state.active_shell].workspace == app_state.g_active_workspace)) app_state.shells[app_state.active_shell].shell_id else null;
    if (!app_state.g_front_period.select(sid, user, visible and foregroundIsOurs(), frequent.unixMs(@import("inbox.zig").nowFileTime() / 10_000), GetTickCount64())) return;
    _ = KillTimer(app_state.g_main_hwnd, app_state.TIMER_VISIT_DWELL);
    if (app_state.g_front_period.sid != null) _ = SetTimer(app_state.g_main_hwnd, app_state.TIMER_VISIT_DWELL, @intCast(frequent.dwell_ms), null);
}

fn recordFrontVisit() void {
    sessionFrontChanged();
    const stamp = app_state.g_front_period.visit(GetTickCount64()) orelse return;
    _ = KillTimer(app_state.g_main_hwnd, app_state.TIMER_VISIT_DWELL);
    const idx = findShellById(app_state.g_front_period.sid.?) orelse return;
    app_state.shells[idx].visits.add(stamp);
    publishInboxStateNow();
    saveSession();
    if (app_state.g_inbox_active) loadInboxModel();
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

fn wndProc(hwnd: HANDLE, msg: UINT, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT {
    defer if (msg != WM_DESTROY and msg != 0x0082) sessionFrontChanged();
    const prior_focus_action = app_state.g_focus_user_action_tick;
    app_state.g_focus_user_action_tick = focusGuardDispatchTick(msg, wp, lp);
    defer app_state.g_focus_user_action_tick = prior_focus_action;
    if (!app_state.g_account_locked and @import("chat_find_ui.zig").windowKey(msg, wp)) return 0;
    if (msg == launch_cache.WM_DEFERRED) {
        if (!launch_cache.pending) return 0;
        launch_cache.deferred();
        initializeDeferred(hwnd);
        launch_cache.pending = false;
        saveSession();
        launch_cache.changed();
        return 0;
    }
    if (msg == WM_TIMER and wp == launch_cache.TIMER_SAVE) {
        launch_cache.save();
        return 0;
    }
    if (msg == WM_APP_LAYOUT_READY) {
        handleLayoutReply(lp);
        return 0;
    }
    if (msg == WM_APP_BROWSER_DOCKED) {
        const job: *BrowserDockJob = @ptrFromInt(@as(usize, @bitCast(lp)));
        finishBrowserDock(job);
        return 0;
    }
    if (msg == 0x0120) {
        if (@import("fonts.zig").menuChar(wp)) |result| return result;
    }
    if (@import("fonts.zig").menuMessage(msg, lp)) |result| return result;
    if (app_state.g_account_locked) {
        switch (msg) {
            WM_PAINT => {
                paintAccountLock(hwnd);
                return 0;
            },
            WM_ERASEBKGND => return 1,
            WM_KEYDOWN => {
                if (wp == 0x0D) accountSignIn();
                if (wp == 0x1B) accountCancelSignIn();
                return 0;
            },
            WM_LBUTTONUP => {
                const x: i32 = @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp))))));
                const y: i32 = @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp)) >> 16))));
                const r = accountButtonRect(hwnd);
                if (x >= r.left and x < r.right and y >= r.top and y < r.bottom) accountSignIn();
                return 0;
            },
            WM_CLOSE => {
                _ = DestroyWindow(hwnd);
                return 0;
            },
            WM_DESTROY => {},
            else => return DefWindowProcW(hwnd, msg, wp, lp),
        }
    }
    if (msg == WM_KEYDOWN and wp == 0x1B and app_state.g_account_login_active) {
        accountCancelSignIn();
        return 0;
    }
    if (msg == WM_TIMER and wp == TIMER_ACCOUNT) {
        pullSessionLayout();
        return 0;
    }
    if (msg == WM_TIMER and wp == TIMER_ACCOUNT_SAVE) {
        if (app_state.g_account_dirty_at != 0 and GetTickCount64() - app_state.g_account_dirty_at >= 2000) accountPush();
        return 0;
    }
    switch (msg) {
        WM_APP_UPDATE_CHANGED => {
            if (wp != 0) _ = SetTimer(hwnd, TIMER_UPDATE_CHECK, UPDATE_CHECK_MS, null);
            updateCardPoll();
            return 0;
        },
        WM_SETTINGCHANGE, WM_THEMECHANGED => {
            refreshSystemTheme(hwnd);
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
        WM_GETMINMAXINFO => {
            if (lp != 0) {
                const mon = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
                var mi: MONITORINFO = std.mem.zeroes(MONITORINFO);
                mi.cbSize = @sizeOf(MONITORINFO);
                if (mon != null and GetMonitorInfoW(mon, &mi) != 0) {
                    const mmi: *MINMAXINFO = @ptrFromInt(@as(usize, @bitCast(lp)));
                    const mr = mi.rcMonitor;
                    const wr = mi.rcWork;
                    mmi.ptMaxPosition.x = wr.left - mr.left;
                    mmi.ptMaxPosition.y = wr.top - mr.top;
                    mmi.ptMaxSize.x = wr.right - wr.left;
                    mmi.ptMaxSize.y = wr.bottom - wr.top;
                    if (mmi.ptMaxTrackSize.x < mmi.ptMaxSize.x) mmi.ptMaxTrackSize.x = mmi.ptMaxSize.x;
                    if (mmi.ptMaxTrackSize.y < mmi.ptMaxSize.y) mmi.ptMaxTrackSize.y = mmi.ptMaxSize.y;
                    return 0;
                }
            }
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
        WM_DISPLAYCHANGE => {
            _ = syncMainWindowDpi(hwnd, 0);
            resetGdiCache();
            beginMonitorTransitionAtCurrent(hwnd, .display_change);
            armMonitorTransitionTimer(hwnd);
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_DPICHANGED => {
            _ = syncMainWindowDpi(hwnd, @intCast(wp & 0xFFFF));
            if (lp != 0) {
                const sug: *const RECT = @ptrFromInt(@as(usize, @bitCast(lp)));
                _ = SetWindowPos(hwnd, null, sug.left, sug.top, sug.right - sug.left, sug.bottom - sug.top, SWP_NOZORDER | SWP_NOACTIVATE);
                if (app_state.g_monitor_transition.active and app_state.g_monitor_transition.expected_valid) {
                    app_state.g_monitor_transition.expected_frame = sug.*;
                }
            }
            if (!app_state.g_monitor_transition.active) beginMonitorTransitionAtCurrent(hwnd, .detected_crossing);
            if (verboseLoggingEnabled()) {
                var db: [96]u8 = undefined;
                const ds = std.fmt.bufPrint(&db, "[dpichanged] wp_dpi={d} win_dpi={d} shells={d}", .{ wp & 0xFFFF, mainWindowDpi(), app_state.shell_count }) catch "[dpichanged]";
                debugLog(ds);
            }
            fontSyncMarkAllStale(hwnd, "dpichanged");
            fontSyncActiveNow();
            if (app_state.g_monitor_transition.active) {
                armMonitorTransitionTimer(hwnd);
                _ = InvalidateRect(hwnd, null, 0);
                return 0;
            }
            repositionActive();
            armConsoleGeometrySettle(hwnd);
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_MOVE => {
            noteMainWindowMonitor(hwnd);
            if (app_state.g_monitor_transition.active) {
                armMonitorTransitionTimer(hwnd);
                return 0;
            }
            updateBrowserVisibility();
            armConsoleGeometrySettle(hwnd);
            return 0;
        },
        WM_WINDOWPOSCHANGED => {
            noteMainWindowMonitor(hwnd);
            if (app_state.g_monitor_transition.active) {
                armMonitorTransitionTimer(hwnd);
                return DefWindowProcW(hwnd, msg, wp, lp);
            }
            updateBrowserVisibility();
            armConsoleGeometrySettle(hwnd);
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
        WM_SIZE => {
            const SIZE_MINIMIZED: WPARAM = 1;
            if (wp == SIZE_MINIMIZED) {
                resetPaintBackbuffer();
                if (app_state.g_power_minimized_since_tick == 0) app_state.g_power_minimized_since_tick = GetTickCount64();
            } else if (app_state.g_power_minimized_since_tick != 0) {
                exitDeepIdleNow(hwnd);
            }
            if (app_state.g_monitor_transition.active) {
                armMonitorTransitionTimer(hwnd);
                _ = InvalidateRect(hwnd, null, 0);
                return 0;
            }
            repositionActive();
            updateBrowserVisibility();
            armConsoleGeometrySettle(hwnd);
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_ERASEBKGND => {
            return 1;
        },
        WM_PAINT => {
            const _perf_start = GetTickCount64();
            defer logSlowMs("WM_PAINT", _perf_start);
            var ps: PAINTSTRUCT = std.mem.zeroes(PAINTSTRUCT);
            const hdc = BeginPaint(hwnd, &ps);
            const paint_rc = ps.rcPaint;
            const pw = paint_rc.right - paint_rc.left;
            const ph = paint_rc.bottom - paint_rc.top;
            if (pw <= 0 or ph <= 0) {
                _ = EndPaint(hwnd, &ps);
                return 0;
            }
            var client_rc: RECT = std.mem.zeroes(RECT);
            _ = GetClientRect(hwnd, &client_rc);
            const client_w = client_rc.right - client_rc.left;
            const client_h = client_rc.bottom - client_rc.top;
            const mem_dc = ensurePaintBackbuffer(hdc, client_w, client_h);
            if (mem_dc == null) {
                var canvas = @import("smooth.zig").Canvas.init(hdc);
                paintSidebar(hdc);
                paintChatView(hdc);
                @import("drawing.zig").paintDisconnectedShell(hdc);
                paintBrowserPlaceholder(hdc);
                paintBrowserSplitter(hdc);
                canvas.deinit();
                _ = EndPaint(hwnd, &ps);
                launch_cache.painted(false);
                return 0;
            }
            const saved_dc = SaveDC(mem_dc);
            if (saved_dc != 0) {
                _ = IntersectClipRect(mem_dc, paint_rc.left, paint_rc.top, paint_rc.right, paint_rc.bottom);
            }
            const canvas = @import("drawing.zig").beginPaintCanvas();
            paintSidebar(mem_dc);
            paintChatView(mem_dc);
            @import("drawing.zig").paintDisconnectedShell(mem_dc);
            paintBrowserPlaceholder(mem_dc);
            paintBrowserSplitter(mem_dc);
            paintActivePaneBorder(mem_dc);
            canvas.deactivate();
            if (saved_dc != 0) _ = RestoreDC(mem_dc, saved_dc);
            _ = BitBlt(hdc, paint_rc.left, paint_rc.top, pw, ph, mem_dc, paint_rc.left, paint_rc.top, GDI_SRCCOPY);
            _ = EndPaint(hwnd, &ps);
            launch_cache.painted(false);
            return 0;
        },
        WM_CTLCOLOREDIT, WM_CTLCOLORSTATIC => {
            const child: HANDLE = if (lp == 0) null else @ptrFromInt(@as(usize, @bitCast(lp)));
            if (child == app_state.g_chat_composer_hwnd) {
                refreshChatBrushes();
                const dc: HANDLE = if (wp == 0) null else @ptrFromInt(wp);
                _ = SetTextColor(dc, customColorOr("text", themeConsoleFg()));
                _ = SetBkColor(dc, app_state.g_chat_input_color);
                if (app_state.g_chat_input_brush != null) return @bitCast(@as(usize, @intFromPtr(app_state.g_chat_input_brush.?)));
            }
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
        WM_COMMAND => {
            const notif = @as(u32, @truncate(wp >> 16));
            if (notif == EN_KILLFOCUS) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_COMMIT_RENAME, 0, 0);
            }
            return 0;
        },
        WM_LBUTTONDOWN => {
            const mx = GET_X(lp);
            const my = GET_Y(lp);

            if (!app_state.g_search_active and !app_state.g_shortcuts_active and !app_state.g_changelog_active and !app_state.g_inbox_active and !app_state.g_all_sessions_active and !app_state.g_url_picker_active and !app_state.g_snippet_create_active) {
                var client_rc: RECT = std.mem.zeroes(RECT);
                _ = GetClientRect(hwnd, &client_rc);
                if (@import("drawing.zig").reconnectButtonRect(client_rc.right)) |button| {
                    if (mx >= button.left and mx < button.right and my >= button.top and my < button.bottom) {
                        _ = PostMessageW(hwnd, WM_APP_RECONNECT, 0, 0);
                        return 0;
                    }
                }
            }

            if (chatViewOwnsInput() and mx >= SIDEBAR_W() and !inboxButtonHitTest(mx, my)) {
                if (browserSplitterHit(mx, my)) {
                    app_state.g_browser_dragging = true;
                    _ = SetCapture(hwnd);
                    return 0;
                }
                switch (chatButtonAt(mx, my)) {
                    3 => _ = PostMessageW(hwnd, WM_APP_CHAT_SEND, 0, 0),
                    4 => _ = PostMessageW(hwnd, WM_APP_CHAT_ATTACH, 0, 0),
                    5 => _ = @import("chat_send.zig").chatStopAgent(app_state.active_shell),
                    9 => @import("chat_composer.zig").clearChatReply(),
                    6...8 => |button| _ = @import("chat_send.zig").chatPermissionAnswer(app_state.active_shell, @enumFromInt(button - 6)),
                    else => if (chatComposerFocusAllowed()) {
                        _ = SetFocus(app_state.g_chat_composer_hwnd);
                    },
                }
                return 0;
            }

            if (app_state.g_snippet_create_active) {
                if (snippetFormButtonHit(mx, my)) |hit| {
                    _ = PostMessageW(app_state.g_main_hwnd, if (hit == 1) WM_APP_SNIPPET_FORM_SAVE else WM_APP_SNIPPET_FORM_CANCEL, 0, 0);
                    return 0;
                }
                if (!snippetFormContainsPoint(mx, my)) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SNIPPET_FORM_CANCEL, 0, 0);
                    return 0;
                }
                return 0;
            }

            if (app_state.g_changelog_active) {
                if (changelogHitTest(mx, my)) |hit| {
                    app_state.g_changelog_sel = hit.idx;
                    if (hit.ticket.len > 0) {
                        closeChangelogOverlay(hwnd, true);
                        openAsciiUrlInDefaultBrowser(hit.ticket);
                    } else {
                        _ = InvalidateRect(hwnd, null, 0);
                    }
                    return 0;
                }
                if (!changelogContainsPoint(mx, my)) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHANGELOG_CLOSE, 0, 0);
                    return 0;
                }
                return 0;
            }

            if (app_state.g_shortcuts_active) {
                _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SHORTCUTS_CLOSE, 0, 0);
                return 0;
            }

            if (app_state.g_all_sessions_active) {
                app_state.g_all_sessions_ctx = false;
                const list_top = allSessionsListTop();
                const tab_strip_bot: i32 = 54;
                if (my >= 0 and my < tab_strip_bot) {
                    var tab_hit: ?u32 = null;
                    for (0..app_state.g_all_sessions_split_tab_count) |ti| {
                        if (mx >= app_state.g_all_sessions_split_xs[ti] and mx < app_state.g_all_sessions_split_xe[ti]) {
                            tab_hit = app_state.g_all_sessions_split_ids[ti];
                            break;
                        }
                    }
                    if (tab_hit) |new_tab| {
                        if (allSessionsSplitVisible(new_tab)) {
                            app_state.g_all_sessions_tab = new_tab;
                            app_state.g_all_sessions_sel = 0;
                            _ = InvalidateRect(hwnd, null, 0);
                        }
                    }
                } else if (my >= list_top) {
                    var client_rc2: RECT = std.mem.zeroes(RECT);
                    _ = GetClientRect(hwnd, &client_rc2);
                    const row_h: i32 = uiScaled(32);
                    const footer_h: i32 = 30;
                    const avail = client_rc2.bottom - list_top - footer_h;
                    const max_rows: u32 = if (avail > row_h) @intCast(@divFloor(avail, row_h)) else 1;
                    const vis = allSessionsVisibleCount();
                    var scroll_row: u32 = 0;
                    if (app_state.g_all_sessions_sel >= max_rows) scroll_row = app_state.g_all_sessions_sel - max_rows + 1;
                    const clicked_vrow: u32 = @intCast(@divFloor(my - list_top, row_h));
                    const target_vrow = scroll_row + clicked_vrow;
                    if (target_vrow < vis) {
                        app_state.g_all_sessions_sel = target_vrow;
                        allSessionsJump(hwnd);
                    }
                }
                return 0;
            }

            if (inboxButtonHitTest(mx, my)) {
                toggleInbox(hwnd);
                return 0;
            }

            if (app_state.g_inbox_active) {
                const inbox_list_top = inboxListTop();
                const inbox_tab_strip_bot: i32 = 54;
                if (my >= 0 and my < inbox_tab_strip_bot) {
                    var tab_hit: ?u32 = null;
                    for (0..app_state.g_inbox_split_tab_count) |ti| {
                        if (mx >= app_state.g_inbox_split_xs[ti] and mx < app_state.g_inbox_split_xe[ti]) {
                            tab_hit = app_state.g_inbox_split_ids[ti];
                            break;
                        }
                    }
                    if (tab_hit) |new_tab| {
                        if (inboxSplitVisible(new_tab)) {
                            app_state.g_inbox_tab = new_tab;
                            app_state.g_inbox_sel = 0;
                            _ = InvalidateRect(hwnd, null, 0);
                        }
                    }
                } else if (my >= inbox_list_top) {
                    var client_rc2: RECT = std.mem.zeroes(RECT);
                    _ = GetClientRect(hwnd, &client_rc2);
                    const inbox_h = client_rc2.bottom;
                    const inbox_row_h: i32 = uiScaled(32);
                    const inbox_footer_h: i32 = 30;
                    const inbox_avail = inbox_h - inbox_list_top - inbox_footer_h;
                    const inbox_max_rows: u32 = if (inbox_avail > inbox_row_h) @intCast(@divFloor(inbox_avail, inbox_row_h)) else 1;
                    const inbox_vis = inboxVisibleCount();
                    var inbox_scroll_row: u32 = 0;
                    if (app_state.g_inbox_sel >= inbox_max_rows) inbox_scroll_row = app_state.g_inbox_sel - inbox_max_rows + 1;
                    const clicked_vrow: u32 = @intCast(@divFloor(my - inbox_list_top, inbox_row_h));
                    const target_vrow = inbox_scroll_row + clicked_vrow;
                    if (target_vrow < inbox_vis) {
                        app_state.g_inbox_sel = target_vrow;
                        inboxJump(hwnd);
                    }
                }
                return 0;
            }

            if (!app_state.g_hide_sidebar) {
                const sw = SIDEBAR_W();
                if (mx >= sw - 4 and mx <= sw + 4) {
                    app_state.g_sidebar_resizing = true;
                    _ = SetCapture(hwnd);
                    return 0;
                }
            }

            if (browserSplitterHit(mx, my)) {
                app_state.g_browser_dragging = true;
                _ = SetCapture(hwnd);
                return 0;
            }

            if (app_state.g_search_active and app_state.g_search_result_count > 0) {
                var click_win_rc: RECT = std.mem.zeroes(RECT);
                _ = GetClientRect(app_state.g_main_hwnd, &click_win_rc);
                const click_win_w = click_win_rc.right - click_win_rc.left;
                const click_win_h = click_win_rc.bottom - click_win_rc.top;
                const click_ow: i32 = searchOverlayW();
                const click_rh: i32 = searchRowH();
                const click_ih: i32 = searchInputH();
                const click_capacity: u32 = @min(app_state.g_search_result_count, SEARCH_VISIBLE_ROWS);
                const click_oh: i32 = click_ih + @as(i32, @intCast(click_capacity)) * click_rh;
                const click_ox = searchOverlayOx(click_win_w, click_ow);
                const click_oy = @divFloor(click_win_h - click_oh, 3);

                if (searchResultRowAtClientPoint(mx, my)) |clicked_row| {
                    app_state.g_search_sel = clicked_row;
                    if (app_state.g_search_ws_sort_mode) {
                        const t = app_state.g_search_results[app_state.g_search_sel];
                        if (t >= SEARCH_WSSORT_OFFSET and t < SEARCH_WSSORT_OFFSET + MAX_LWS) {
                            app_state.g_wssort_dragging = true;
                            app_state.g_wssort_drag_slot = @intCast(t - SEARCH_WSSORT_OFFSET);
                            _ = SetCapture(hwnd);
                            _ = InvalidateRect(hwnd, null, 0);
                            return 0;
                        }
                    }
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_CONFIRM, 0, 0);
                    return 0;
                }
                if (mx < click_ox or mx >= click_ox + click_ow or my < click_oy or my >= click_oy + click_oh) {
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_CLOSE, 0, 0);
                    return 0;
                }
                return 0;
            }

            if (app_state.g_url_picker_active) {
                var win_rc: RECT = std.mem.zeroes(RECT);
                _ = GetClientRect(hwnd, &win_rc);
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

                if (mx >= ox and mx <= ox + overlay_w and my >= oy + header_h and my < oy + overlay_h) {
                    var ry: i32 = oy + header_h;
                    var hit_idx: ?u32 = null;
                    for (0..visible_count) |vi| {
                        const abs_idx: u32 = scroll + @as(u32, @intCast(vi));
                        if (abs_idx >= app_state.g_url_picker_count) break;
                        const len = app_state.g_url_picker_lengths[abs_idx];
                        const row_h = if (len > WRAP_THRESHOLD) row_h_double else row_h_single;
                        if (my >= ry and my < ry + row_h) {
                            hit_idx = abs_idx;
                            break;
                        }
                        ry += row_h;
                    }
                    if (hit_idx) |h| {
                        closeUrlPicker();
                        openUrlByIndex(h);
                    }
                } else {
                    closeUrlPicker();
                }
                return 0;
            }
            {
                const tth_click = threadTitleHeight();
                const tth_top = threadTitleTop();
                if (tth_click > 0 and mx >= SIDEBAR_W() and my >= tth_top and my < tth_top + tth_click and
                    (!app_state.g_chat_active or (mx >= chatViewLayout().transcript.left and mx < chatViewLayout().transcript.right)))
                {
                    app_state.g_shell_focused = true;
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
            }
            if (mx < SIDEBAR_W() and my >= 0) {
                if (app_state.g_single_window and !app_state.g_sidebar_collapsed and !app_state.g_hide_pills and my < WS_STRIP_H) {
                    if (workspaceStripHitTest(mx, my)) |ws| {
                        if (ws == WS_NEW_PILL) newWorkspace() else switchToWorkspace(ws);
                        _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    }
                    app_state.g_shell_focused = false;
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                {
                    const upd_hit = updateCardHit(mx, my);
                    if (upd_hit != 0) {
                        app_state.g_shell_focused = false;
                        if (upd_hit == 1) updateCardRelaunch(hwnd) else if (upd_hit == 2) updateCardDismiss();
                        _ = InvalidateRect(hwnd, null, 0);
                        return 0;
                    }
                }
                if (sidebarStickyCardHitTest(my)) {
                    app_state.g_shell_focused = false;
                    cycleSidebarStatusCard(1);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                app_state.g_shell_focused = false;
                _ = InvalidateRect(hwnd, null, 0);
                const logical_my = my + app_state.g_sidebar_scroll;
                const target = hitTestSidebar(logical_my);
                switch (target) {
                    .inbox => |ri| {
                        jumpToInboxRow(ri);
                        return 0;
                    },
                    .section => |tier| {
                        toggleSidebarSectionCollapsed(tier);
                        return 0;
                    },
                    .tab => |tab_idx| {
                        if (tab_idx < app_state.shell_count) {
                            if (!app_state.g_sidebar_collapsed and mx > SIDEBAR_W() - 30) {
                                if (app_state.shells[tab_idx].locked) {
                                    app_state.shells[tab_idx].locked = false;
                                    saveSession();
                                    invalidateSidebar();
                                    showHeaderNoticeAscii("Session unlocked", 2200, false);
                                } else {
                                    closeShell(tab_idx);
                                }
                            } else if (isCtrlDown()) {
                                commitRename();
                                const had_selection = selectedTabCount() > 0;
                                if (!had_selection) {
                                    if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].selected = true;
                                    app_state.shells[tab_idx].selected = true;
                                } else {
                                    app_state.shells[tab_idx].selected = !app_state.shells[tab_idx].selected;
                                }
                                invalidateSidebar();
                            } else {
                                commitRename();
                                _ = clearTabSelection();
                                @import("console.zig").switchToShellByUser(tab_idx);
                                app_state.drag_pending_materialize = app_state.g_tab_sort_auto;
                                app_state.drag_active = true;
                                app_state.drag_is_group = false;
                                app_state.drag_src = app_state.active_shell;
                                app_state.drag_start_x = mx;
                                app_state.drag_start_y = my;
                                app_state.drag_detach_blocked = false;
                                app_state.drag_last_swap_tick = 0;
                                app_state.drag_section_only = false;
                                _ = SetCapture(hwnd);
                            }
                        }
                    },
                    .header => |gidx| {
                        if (gidx < app_state.group_count) {
                            app_state.drag_pending_materialize = false;
                            app_state.drag_active = true;
                            app_state.drag_is_group = true;
                            app_state.drag_group_gidx = gidx;
                            app_state.drag_start_x = mx;
                            app_state.drag_start_y = my;
                            app_state.drag_detach_blocked = false;
                            app_state.drag_last_swap_tick = 0;
                            app_state.drag_section_only = false;
                            _ = SetCapture(hwnd);
                        }
                    },
                    .buttons => {
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_NEW_TAB_DEFAULT, 0, 0);
                    },
                    .none => {},
                }
            }
            return 0;
        },
        WM_MOUSEWHEEL, WM_MOUSEHWHEEL => {
            var pt: POINT = .{ .x = GET_X(lp), .y = GET_Y(lp) };
            _ = ScreenToClient(hwnd, &pt);
            if (chatViewOwnsInput()) {
                const layout = chatViewLayout();
                if (pointInRect(layout.transcript, pt.x, pt.y)) {
                    if (@import("chat_render.zig").chatTableWheel(app_state.g_chat_transcript_hwnd, msg, wp, lp)) return 0;
                    if (msg == WM_MOUSEHWHEEL) return DefWindowProcW(hwnd, msg, wp, lp);
                    const wheel_delta: i16 = @bitCast(@as(u16, @truncate(wp >> 16)));
                    chatScrollBy(@divTrunc(@as(i32, wheel_delta) * uiScaled(54), 120));
                    return 0;
                }
            }
            if (msg == WM_MOUSEHWHEEL) return DefWindowProcW(hwnd, msg, wp, lp);
            if (app_state.g_all_sessions_active) {
                const wheel_delta: i16 = @bitCast(@as(u16, @truncate(wp >> 16)));
                const vis_count = allSessionsVisibleCount();
                if (vis_count > 0) {
                    if (wheel_delta > 0) {
                        if (app_state.g_all_sessions_sel > 0) app_state.g_all_sessions_sel -= 1;
                    } else {
                        if (app_state.g_all_sessions_sel + 1 < vis_count) app_state.g_all_sessions_sel += 1;
                    }
                    _ = InvalidateRect(hwnd, null, 0);
                }
                return 0;
            }
            if (app_state.g_inbox_active) {
                const wheel_delta: i16 = @bitCast(@as(u16, @truncate(wp >> 16)));
                const vis_count = inboxVisibleCount();
                if (vis_count > 0) {
                    if (wheel_delta > 0) {
                        if (app_state.g_inbox_sel > 0) app_state.g_inbox_sel -= 1;
                    } else {
                        if (app_state.g_inbox_sel + 1 < vis_count) app_state.g_inbox_sel += 1;
                    }
                    _ = InvalidateRect(hwnd, null, 0);
                }
                return 0;
            }
            if (app_state.g_changelog_active) {
                const layout = calcChangelogLayout();
                const delta: i16 = @bitCast(@as(u16, @truncate(wp >> 16)));
                const step: i32 = @divTrunc(@as(i32, delta) * uiScaled(48), 120);
                app_state.g_changelog_scroll -= step;
                if (app_state.g_changelog_scroll < 0) app_state.g_changelog_scroll = 0;
                if (app_state.g_changelog_scroll > layout.max_scroll) app_state.g_changelog_scroll = layout.max_scroll;
                _ = InvalidateRect(hwnd, null, 0);
                return 0;
            }
            if (app_state.g_search_active and app_state.g_search_result_count > 0) {
                var wheel_win_rc: RECT = std.mem.zeroes(RECT);
                _ = GetClientRect(app_state.g_main_hwnd, &wheel_win_rc);
                const wheel_win_w = wheel_win_rc.right - wheel_win_rc.left;
                const wheel_win_h = wheel_win_rc.bottom - wheel_win_rc.top;
                const wheel_ow: i32 = searchOverlayW();
                const wheel_rh: i32 = searchRowH();
                const wheel_ih: i32 = searchInputH();
                const wheel_vis: u32 = @min(app_state.g_search_result_count, SEARCH_VISIBLE_ROWS);
                const wheel_oh: i32 = wheel_ih + @as(i32, @intCast(wheel_vis)) * wheel_rh;
                const wheel_ox = searchOverlayOx(wheel_win_w, wheel_ow);
                const wheel_oy = @divFloor(wheel_win_h - wheel_oh, 3);
                if (pt.x >= wheel_ox and pt.x < wheel_ox + wheel_ow and pt.y >= wheel_oy and pt.y < wheel_oy + wheel_oh) {
                    const delta: i16 = @bitCast(@as(u16, @truncate(wp >> 16)));
                    app_state.g_search_wheel_remainder += @as(i32, delta);
                    while (app_state.g_search_wheel_remainder >= 120) {
                        app_state.g_search_wheel_remainder -= 120;
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_MOVE, 6, 0);
                    }
                    while (app_state.g_search_wheel_remainder <= -120) {
                        app_state.g_search_wheel_remainder += 120;
                        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SEARCH_MOVE, 7, 0);
                    }
                    return 0;
                }
            }

            if (pt.x >= 0 and pt.x < SIDEBAR_W() and pt.y >= 0) {
                const delta: i16 = @bitCast(@as(u16, @truncate(wp >> 16)));
                if (sidebarStickyCardHitTest(pt.y)) {
                    cycleSidebarStatusCard(if (delta < 0) 1 else -1);
                    return 0;
                }
                const step: i32 = @divTrunc(@as(i32, delta) * @divTrunc(tabRowH(), 2), 120);
                app_state.g_sidebar_scroll -= step;
                clampSidebarScroll();
                _ = InvalidateRect(hwnd, null, 0);
                return 0;
            }
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
        WM_SETCURSOR => {
            if (@as(u16, @truncate(@as(usize, @bitCast(lp)))) == HTCLIENT) {
                var cursor_pt: POINT = undefined;
                _ = GetCursorPos(&cursor_pt);
                _ = ScreenToClient(hwnd, &cursor_pt);
                const sw = SIDEBAR_W();
                if (!app_state.g_hide_sidebar and cursor_pt.x >= sw - 4 and cursor_pt.x <= sw + 4) {
                    _ = SetCursor(app_state.g_cursor_sizewe);
                    return 1;
                }
                if (browserSplitterHit(cursor_pt.x, cursor_pt.y)) {
                    _ = SetCursor(app_state.g_cursor_sizewe);
                    return 1;
                }
                if ((app_state.ISSUE_265_WORKING_BAR and chatViewOwnsInput() and chatButtonAt(cursor_pt.x, cursor_pt.y) != 0) or inboxButtonHitTest(cursor_pt.x, cursor_pt.y)) {
                    _ = SetCursor(LoadCursorW(null, @ptrFromInt(32649)));
                    return 1;
                }
            }
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
        0x02A3 => {
            if (app_state.g_workspace_hover != null) {
                app_state.g_workspace_hover = null;
                _ = InvalidateRect(hwnd, null, 0);
            }
            if (app_state.g_inbox_button_hover) {
                app_state.g_inbox_button_hover = false;
                _ = InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        WM_MOUSEMOVE => {
            {
                const upd_hit = updateCardHit(GET_X(lp), GET_Y(lp));
                const upd_now: u8 = if (upd_hit == 1 or upd_hit == 2) upd_hit else 0;
                if (upd_now != app_state.g_update_hover) {
                    app_state.g_update_hover = upd_now;
                    _ = InvalidateRect(hwnd, null, 0);
                    if (upd_now != 0) {
                        var tracking = TRACKMOUSEEVENT{ .cbSize = @sizeOf(TRACKMOUSEEVENT), .dwFlags = 2, .hwndTrack = hwnd, .dwHoverTime = 0 };
                        _ = TrackMouseEvent(&tracking);
                    }
                }
            }
            const ws_hover = workspaceStripHitTest(GET_X(lp), GET_Y(lp));
            if (ws_hover != app_state.g_workspace_hover) {
                app_state.g_workspace_hover = ws_hover;
                _ = InvalidateRect(hwnd, null, 0);
            }
            if (ws_hover != null) {
                var tracking = TRACKMOUSEEVENT{ .cbSize = @sizeOf(TRACKMOUSEEVENT), .dwFlags = 2, .hwndTrack = hwnd, .dwHoverTime = 0 };
                _ = TrackMouseEvent(&tracking);
            }
            const hovered = inboxButtonHitTest(GET_X(lp), GET_Y(lp));
            if (hovered != app_state.g_inbox_button_hover) {
                app_state.g_inbox_button_hover = hovered;
                _ = InvalidateRect(hwnd, null, 0);
            }
            if (hovered) {
                var tracking = TRACKMOUSEEVENT{ .cbSize = @sizeOf(TRACKMOUSEEVENT), .dwFlags = 2, .hwndTrack = hwnd, .dwHoverTime = 0 };
                _ = TrackMouseEvent(&tracking);
            }
            if (app_state.g_wssort_dragging and (wp & MK_LBUTTON) != 0) {
                const my_drag = GET_Y(lp);
                var drag_rc: RECT = std.mem.zeroes(RECT);
                _ = GetClientRect(app_state.g_main_hwnd, &drag_rc);
                const drag_win_h = drag_rc.bottom - drag_rc.top;
                const drag_rh: i32 = searchRowH();
                const drag_ih: i32 = searchInputH();
                const drag_capacity: u32 = @min(app_state.g_search_result_count, SEARCH_VISIBLE_ROWS);
                const drag_vis: i32 = @intCast(@min(app_state.g_search_result_count -| app_state.g_search_scroll, drag_capacity));
                if (drag_vis > 0) {
                    const drag_oh: i32 = drag_ih + @as(i32, @intCast(drag_capacity)) * drag_rh;
                    const drag_oy = @divFloor(drag_win_h - drag_oh, 3);
                    var hover: i32 = @divFloor(my_drag - (drag_oy + drag_ih), drag_rh);
                    if (hover < 0) hover = 0;
                    if (hover >= drag_vis) hover = drag_vis - 1;
                    const row: u32 = app_state.g_search_scroll + @as(u32, @intCast(hover));
                    const t = app_state.g_search_results[row];
                    if (t >= SEARCH_WSSORT_OFFSET and t < SEARCH_WSSORT_OFFSET + MAX_LWS) {
                        const dst: u8 = @intCast(t - SEARCH_WSSORT_OFFSET);
                        while (dst != app_state.g_wssort_drag_slot) {
                            const nxt: u8 = if (dst > app_state.g_wssort_drag_slot) app_state.g_wssort_drag_slot + 1 else app_state.g_wssort_drag_slot - 1;
                            swapWorkspaceSlots(app_state.g_wssort_drag_slot, nxt);
                            app_state.g_wssort_drag_slot = nxt;
                        }
                        app_state.g_search_sel = row;
                        _ = InvalidateRect(hwnd, null, 0);
                    }
                }
                return 0;
            }
            if (app_state.g_search_active and (wp & MK_LBUTTON) == 0) {
                if (searchResultRowAtClientPoint(GET_X(lp), GET_Y(lp))) |hovered_row| {
                    if (hovered_row != app_state.g_search_sel) {
                        app_state.g_search_sel = hovered_row;
                        _ = InvalidateRect(hwnd, null, 0);
                    }
                    return 0;
                }
            }
            if (app_state.g_browser_dragging and (wp & MK_LBUTTON) != 0) {
                setBrowserSplitFromMouse(GET_X(lp));
                repositionActive();
                _ = InvalidateRect(hwnd, null, 0);
                return 0;
            }
            if (app_state.g_sidebar_resizing and (wp & MK_LBUTTON) != 0) {
                const mx_drag = GET_X(lp);
                const SNAP_THRESHOLD: i32 = uiScaled(70);
                if (mx_drag < SNAP_THRESHOLD) {
                    if (!app_state.g_sidebar_collapsed) {
                        app_state.g_sidebar_collapsed = true;
                        repositionActive();
                        _ = InvalidateRect(hwnd, null, 0);
                    }
                } else {
                    if (app_state.g_sidebar_collapsed) app_state.g_sidebar_collapsed = false;
                    const new_w_px = @max(uiScaled(SIDEBAR_W_MIN), @min(uiScaled(SIDEBAR_W_MAX), mx_drag));
                    const new_w_logical = uiUnscaled(new_w_px);
                    if (new_w_logical != app_state.g_sidebar_w_full) {
                        app_state.g_sidebar_w_full = new_w_logical;
                    }
                    repositionActive();
                    _ = InvalidateRect(hwnd, null, 0);
                }
                return 0;
            }
            if (app_state.drag_active and !app_state.drag_detached and (wp & MK_LBUTTON) != 0) {
                const mx = GET_X(lp);
                const my = GET_Y(lp);

                if (app_state.drag_pending_materialize) {
                    const pdx = mx - app_state.drag_start_x;
                    const pdy = my - app_state.drag_start_y;
                    const padx: i32 = if (pdx < 0) -pdx else pdx;
                    const pady: i32 = if (pdy < 0) -pdy else pdy;
                    if (padx >= DRAG_MATERIALIZE_THRESH or pady >= DRAG_MATERIALIZE_THRESH) {
                        app_state.drag_pending_materialize = false;
                        app_state.drag_section_only = false;
                    } else {
                        return 0;
                    }
                }

                if (app_state.drag_is_group) {
                    const dy = my - app_state.drag_start_y;
                    const ady: i32 = if (dy < 0) -dy else dy;
                    if (ady < 6) return 0;
                    const now = GetTickCount64();
                    if (app_state.drag_last_swap_tick != 0 and now - app_state.drag_last_swap_tick < 120) return 0;
                    if (sidebarStickyCardHitTest(my)) return 0;

                    const logical_my_drag = my + app_state.g_sidebar_scroll;
                    const ht = hitTestSidebar(logical_my_drag);
                    var target_gidx: ?u32 = null;
                    switch (ht) {
                        .tab => |ti| {
                            if (ti < app_state.shell_count) {
                                const gid = app_state.shells[ti].group_id;
                                if (gid != 0) target_gidx = findGroupIdx(gid);
                            }
                        },
                        .header => |tgidx| {
                            if (tgidx < app_state.group_count) target_gidx = tgidx;
                        },
                        else => {},
                    }
                    const dst_gidx = target_gidx orelse return 0;
                    if (dst_gidx == app_state.drag_group_gidx) return 0;
                    if (moveGroupToIndex(app_state.drag_group_gidx, dst_gidx)) {
                        app_state.drag_group_gidx = dst_gidx;
                        app_state.drag_last_swap_tick = now;
                        _ = InvalidateRect(hwnd, null, 0);
                        saveSession();
                    }
                    return 0;
                }

                {
                    const sidebar_w = SIDEBAR_W();
                    const dx = mx - app_state.drag_start_x;
                    const dy = my - app_state.drag_start_y;
                    const adx: i32 = if (dx < 0) -dx else dx;
                    const ady: i32 = if (dy < 0) -dy else dy;

                    const REORDER_LOCK_Y: i32 = 24;
                    const REORDER_LOCK_MARGIN_X: i32 = 32;
                    const DETACH_OUTSIDE_X: i32 = 140;
                    const DETACH_MIN_DX: i32 = 220;
                    const DETACH_DOMINANCE: i32 = 80;

                    const still_in_reorder_lane = mx >= -REORDER_LOCK_MARGIN_X and mx <= sidebar_w + REORDER_LOCK_MARGIN_X;
                    if (!app_state.drag_detach_blocked and still_in_reorder_lane and ady >= REORDER_LOCK_Y and ady > adx + 12) {
                        app_state.drag_detach_blocked = true;
                    }

                    const outside_sidebar = mx > sidebar_w + DETACH_OUTSIDE_X or mx < -DETACH_OUTSIDE_X;
                    const horizontal_detach = outside_sidebar and adx >= DETACH_MIN_DX and adx > ady + DETACH_DOMINANCE;
                    if (!app_state.drag_detach_blocked and horizontal_detach and !app_state.g_single_window) {
                        var cursor_pt: POINT = undefined;
                        _ = GetCursorPos(&cursor_pt);
                        const target_hwnd_drag = WindowFromPoint(cursor_pt);
                        var is_zigshell_target = false;
                        var zigshell_target: HANDLE = null;
                        if (target_hwnd_drag != null) {
                            const root_hwnd = GetAncestor(target_hwnd_drag, GA_ROOT);
                            if (root_hwnd != null and root_hwnd != app_state.g_main_hwnd) {
                                var cls_buf: [32]u16 = undefined;
                                const cls_len = GetClassNameW(root_hwnd, &cls_buf, 32);
                                const expected = comptime blk: {
                                    const s = "ZigShell";
                                    var r: [s.len]u16 = undefined;
                                    for (s, 0..) |c, i| r[i] = c;
                                    break :blk r;
                                };
                                if (cls_len == expected.len and std.mem.eql(u16, cls_buf[0..@intCast(cls_len)], &expected)) {
                                    is_zigshell_target = true;
                                    zigshell_target = root_hwnd;
                                }
                            }
                        }

                        if (is_zigshell_target) {
                            app_state.drag_detached = true;
                            app_state.drag_active = false;
                            app_state.drag_pending_materialize = false;
                            _ = ReleaseCapture();
                            _ = detachTabToExistingWindow(app_state.drag_src, zigshell_target, false);
                            return 0;
                        } else if (app_state.shell_count > 1) {
                            app_state.drag_detached = true;
                            app_state.drag_active = false;
                            app_state.drag_pending_materialize = false;
                            _ = ReleaseCapture();
                            detachTabToNewWindow(app_state.drag_src);
                            return 0;
                        }
                    }
                }

                const REORDER_X_MARGIN: i32 = 32;
                const sidebar_w_for_reorder = SIDEBAR_W();
                if (my >= 0 and !sidebarStickyCardHitTest(my) and mx >= -REORDER_X_MARGIN and mx < sidebar_w_for_reorder + REORDER_X_MARGIN) {
                    const logical_my_drag = my + app_state.g_sidebar_scroll;
                    const ht = hitTestSidebar(logical_my_drag);
                    if (sidebarTierForDrop(ht)) |want_tier| {
                        if (app_state.drag_src < app_state.shell_count and shellSidebarTier(app_state.drag_src) != want_tier) {
                            switch (want_tier) {
                                .pinned => {
                                    app_state.shells[app_state.drag_src].pinned_top = true;
                                },
                                .recent => {
                                    app_state.shells[app_state.drag_src].pinned_top = false;
                                },
                            }
                            app_state.drag_detach_blocked = true;
                            _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
                            saveSession();
                        }
                    }
                    var target_opt: ?u32 = null;
                    switch (ht) {
                        .tab => |t| if (!app_state.drag_section_only) {
                            target_opt = t;
                        },
                        else => {},
                    }
                    if (target_opt) |target| {
                        if (target != app_state.drag_src and target < app_state.shell_count and app_state.drag_src < app_state.shell_count) {
                            const src_gid = app_state.shells[app_state.drag_src].group_id;
                            const target_gid = app_state.shells[target].group_id;
                            if (src_gid == target_gid) {
                                const temp = app_state.shells[app_state.drag_src];
                                app_state.shells[app_state.drag_src] = app_state.shells[target];
                                app_state.shells[target] = temp;
                                if (app_state.active_shell == app_state.drag_src) {
                                    app_state.active_shell = target;
                                } else if (app_state.active_shell == target) {
                                    app_state.active_shell = app_state.drag_src;
                                }
                                app_state.drag_src = target;
                            } else {
                                if (target_gid != 0) {
                                    if (findGroupIdx(target_gid)) |tgidx| app_state.groups[tgidx].collapsed = false;
                                }
                                if (moveShellToIndexWithGroup(app_state.drag_src, target, target_gid)) |new_idx| {
                                    app_state.drag_src = new_idx;
                                    pruneEmptyGroups();
                                }
                            }
                            app_state.drag_detach_blocked = true;
                            _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
                            saveSession();
                        }
                    } else {
                        switch (ht) {
                            .header => |tgidx| {
                                if (!app_state.drag_section_only and tgidx < app_state.group_count and app_state.drag_src < app_state.shell_count) {
                                    const target_gid = app_state.groups[tgidx].id;
                                    if (app_state.shells[app_state.drag_src].group_id != target_gid) {
                                        app_state.groups[tgidx].collapsed = false;
                                        if (moveShellToGroupStart(app_state.drag_src, target_gid)) |new_idx| {
                                            app_state.drag_src = new_idx;
                                            pruneEmptyGroups();
                                            app_state.drag_detach_blocked = true;
                                            _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
                                            saveSession();
                                        }
                                    }
                                }
                            },
                            else => {},
                        }
                    }
                }
            }
            return 0;
        },
        WM_LBUTTONUP => {
            if (app_state.g_wssort_dragging) {
                app_state.g_wssort_dragging = false;
                _ = ReleaseCapture();
                persistWorkspaceOrder();
                _ = InvalidateRect(hwnd, null, 0);
                return 0;
            }
            if (app_state.g_sidebar_resizing) {
                app_state.g_sidebar_resizing = false;
                _ = ReleaseCapture();
                return 0;
            }
            if (app_state.g_browser_dragging) {
                app_state.g_browser_dragging = false;
                _ = ReleaseCapture();
                saveSession();
                return 0;
            }
            if (app_state.drag_active) {
                if (app_state.drag_is_group and app_state.drag_last_swap_tick == 0) {
                    const gidx = app_state.drag_group_gidx;
                    if (gidx < app_state.group_count) {
                        app_state.groups[gidx].collapsed = !app_state.groups[gidx].collapsed;
                        if (app_state.groups[gidx].collapsed) {
                            const cur_gid = app_state.groups[gidx].id;
                            if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].group_id == cur_gid) {
                                if (findNextVisibleTab(app_state.active_shell, 1)) |nxt| {
                                    switchToShell(nxt);
                                } else if (findNextVisibleTab(app_state.active_shell, -1)) |prv| {
                                    switchToShell(prv);
                                }
                            }
                        }
                        clampSidebarScroll();
                        saveSession();
                        _ = InvalidateRect(hwnd, null, 0);
                    }
                }
                app_state.drag_active = false;
                app_state.drag_pending_materialize = false;
                app_state.drag_is_group = false;
                app_state.drag_section_only = false;
                app_state.drag_detach_blocked = false;
                _ = ReleaseCapture();
            }
            app_state.drag_detached = false;
            return 0;
        },
        WM_RBUTTONDOWN => {
            const mx = GET_X(lp);
            const my = GET_Y(lp);
            if (mx < SIDEBAR_W() and my >= 0) {
                if (workspaceStripHitTest(mx, my)) |ws| {
                    if (ws < app_state.g_lws_count) _ = PostMessageW(hwnd, WM_APP_WS_SNOOZE_OPEN, @as(usize, ws) + 1, 0);
                    return 0;
                }
                if (app_state.g_single_window and !app_state.g_sidebar_collapsed and !app_state.g_hide_pills and my < WS_STRIP_H) return 0;
                if (sidebarStickyCardHitTest(my)) return 0;
                const logical_my = my + app_state.g_sidebar_scroll;
                const ht = hitTestSidebar(logical_my);
                switch (ht) {
                    .tab => |tab_idx| {
                        if (tab_idx < app_state.shell_count) openTabContextPalette(hwnd, tab_idx);
                    },
                    .header => |gidx| {
                        if (gidx < app_state.group_count) showGroupHeaderMenu(hwnd, gidx, mx, my);
                    },
                    else => {},
                }
            }
            return 0;
        },
        WM_NCLBUTTONDOWN, WM_NCRBUTTONDOWN => {
            cancelShellRefocus(hwnd);
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
        WM_ENTERMENULOOP => {
            app_state.g_popup_menu_active = true;
            cancelShellRefocus(hwnd);
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
        WM_EXITMENULOOP => {
            app_state.g_popup_menu_active = false;
            cancelShellRefocus(hwnd);
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
        WM_ENTERSIZEMOVE => {
            app_state.g_move_size_active = true;
            cancelShellRefocus(hwnd);
            beginMonitorTransitionAtCurrent(hwnd, .interactive_drag);
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
        WM_EXITSIZEMOVE => {
            app_state.g_move_size_active = false;
            cancelShellRefocus(hwnd);
            retargetMonitorTransitionToCurrent(hwnd);
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
        WM_LBUTTONDBLCLK => {
            const mx = GET_X(lp);
            const my = GET_Y(lp);
            const tth = threadTitleHeight();
            const tth_top = threadTitleTop();
            if (tth > 0 and mx >= SIDEBAR_W() and my >= tth_top and my < tth_top + tth and app_state.active_shell < app_state.shell_count and
                (!app_state.g_chat_active or (mx >= chatViewLayout().transcript.left and mx < chatViewLayout().transcript.right)))
            {
                startThreadTitleRename();
                return 0;
            }
            if (mx < SIDEBAR_W() and my >= 0) {
                if (app_state.g_single_window and !app_state.g_sidebar_collapsed and !app_state.g_hide_pills and my < WS_STRIP_H) return 0;
                if (sidebarStickyCardHitTest(my)) return 0;
                const logical_my = my + app_state.g_sidebar_scroll;
                const ht = hitTestSidebar(logical_my);
                switch (ht) {
                    .tab => |tab_idx| {
                        if (mx <= SIDEBAR_W() - 30 and tab_idx < app_state.shell_count and tab_idx == app_state.active_shell) {
                            startRename(tab_idx);
                        }
                    },
                    .header => |gidx| {
                        if (gidx < app_state.group_count) startGroupRename(gidx);
                    },
                    else => {},
                }
            }
            return 0;
        },
        WM_APP_COMMIT_RENAME => {
            commitRename();
            return 0;
        },
        WM_APP_RENAME_TAB => {
            if (app_state.shell_count > 0) {
                startRename(app_state.active_shell);
            }
            return 0;
        },
        WM_APP_RENAME_WINDOW => {
            startWindowRename();
            return 0;
        },
        WM_APP_DEV_FONT_NEXT => {
            devCycleConsoleFont();
            return 0;
        },
        WM_APP_DEV_SIZE_DOWN => {
            devCycleConsoleSize();
            return 0;
        },
        WM_APP_DEV_SIZE_UP => {
            devAdjustConsoleSize(1);
            return 0;
        },
        WM_APP_DEV_AMOLED => {
            app_state.g_system_theme = false;
            app_state.g_amoled_theme = !app_state.g_amoled_theme;
            if (app_state.g_amoled_theme) {
                app_state.g_light_theme = false;
                app_state.g_mid_theme = false;
                app_state.g_edge_gray_theme = false;
                app_state.g_dev_theme_active = false;
                app_state.g_multiprompt_theme = false;
            }
            resetFontCache();
            applyTitleBarTheme();
            applyConsoleThemeToAllShells();
            repositionActive();
            refreshBrowserEdgeMasks();
            _ = InvalidateRect(hwnd, null, 0);
            saveGlobalTheme();
            return 0;
        },
        WM_APP_FAVORITE_TOGGLE => {
            toggleFavorite(app_state.active_shell);
            return 0;
        },
        WM_APP_WEBVIEW2_TOGGLE => {
            toggleWebView2();
            return 0;
        },
        WM_APP_WEBVIEW2_ACTION => {
            if (app_state.g_webview2_active) {
                switch (wp) {
                    1 => if (app_state.g_webview2_back) |action| action(),
                    2 => if (app_state.g_webview2_forward) |action| action(),
                    3 => if (app_state.g_webview2_reload) |action| action(),
                    4 => if (app_state.g_webview2_next_tab) |cycle| {
                        _ = cycle(0);
                    },
                    5 => if (app_state.g_webview2_next_tab) |cycle| {
                        _ = cycle(1);
                    },
                    6 => if (app_state.g_webview2_close_tab) |close_tab| {
                        if (close_tab() == 0) {
                            closeWebView2();
                            if (app_state.active_shell < app_state.shell_count) _ = showShellConsole(app_state.active_shell, SW_SHOW, "wndProc.WM_APP_WEBVIEW2_ACTION");
                            repositionActive();
                            focusActiveShell();
                        }
                    },
                    7 => _ = openWebView2Tab("about:blank", true),
                    else => {},
                }
            }
            return 0;
        },
        WM_APP_WEBVIEW2_FOCUS => {
            if (webView2OwnsActiveShell()) {
                if (wp == 2) {
                    requestWebView2Focus();
                } else if (wp != 0) {
                    cancelShellRefocus(hwnd);
                    app_state.g_browser_focus_mode = true;
                    app_state.g_shell_focused = false;
                } else if (!webView2HasInputFocus()) {
                    app_state.g_browser_focus_mode = false;
                    app_state.g_shell_focused = activeShellHasForegroundFocus();
                }
                _ = InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        WM_APP_TOGGLE_FULLWIDTH => {
            if (app_state.active_shell < app_state.shell_count) {
                app_state.shells[app_state.active_shell].full_width = !app_state.shells[app_state.active_shell].full_width;
                if (@import("chat_composer.zig").fullWidthShouldResizeConsole(app_state.g_chat_active)) {
                    if (app_state.shells[app_state.active_shell].pid != 0) applyBlackConsoleBackground(app_state.shells[app_state.active_shell].pid);
                } else {
                    app_state.shells[app_state.active_shell].full_width_pending_console_resize = true;
                }
                repositionActive();
                saveSession();
                _ = InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        WM_APP_RECONNECT => {
            if (app_state.active_shell < app_state.shell_count) {
                @import("chat_send.zig").sshReconnectNow(app_state.active_shell);
            }
            return 0;
        },
        WM_APP_HIDE_TAB_UNTIL_ATTENTION => {
            hideActiveTabUntilAttention();
            return 0;
        },
        WM_APP_ARCHIVE_ARM => {
            if (app_state.active_shell < app_state.shell_count) archiveArmOrCommit(app_state.active_shell);
            return 0;
        },
        WM_APP_BROWSER_TOGGLE => {
            const physical_shortcut = wp == 1;
            if (physical_shortcut) {
                const event_time: u32 = @truncate(@as(usize, @bitCast(lp)));
                browserTraceN("shortcutToggle event=", event_time);
                if (!claimBrowserToggleEvent(event_time, &app_state.g_browser_toggle_last_handled_event_time)) {
                    browserTrace("shortcutToggle suppressed duplicate event time");
                    return 0;
                }
            }
            var target_idx: u32 = app_state.active_shell;
            if (app_state.g_tabctx_sid != 0) {
                if (findShellById(app_state.g_tabctx_sid)) |ti| target_idx = ti;
            }
            app_state.g_tabctx_sid = 0;
            if (target_idx < app_state.shell_count) {
                const browser_hwnd_live = if (app_state.shells[target_idx].browser_hwnd) |bh|
                    IsWindow(bh) != 0 and windowOwnerProcessStillActive(bh)
                else
                    false;
                const recover_dead_pane = physical_shortcut and physicalBrowserShortcutShouldRecover(
                    app_state.shells[target_idx].browser_enabled,
                    browser_hwnd_live,
                    app_state.shells[target_idx].browser_launch_tick,
                );
                if (physical_shortcut and app_state.shells[target_idx].browser_enabled and !recover_dead_pane) {
                    const now = GetTickCount64();
                    if (!physicalBrowserShortcutMayClose(
                        app_state.shells[target_idx].shell_id,
                        app_state.shells[target_idx].browser_launch_tick,
                        now,
                        app_state.g_browser_shortcut_open_guard_shell_id,
                        app_state.g_browser_shortcut_open_guard_until,
                    )) {
                        browserTrace("shortcutToggle suppressed during open guard");
                        return 0;
                    }
                }
                if (app_state.g_webview2_active) {
                    closeWebView2();
                    if (app_state.active_shell < app_state.shell_count) _ = showShellConsole(app_state.active_shell, SW_SHOW, "wndProc.WM_APP_BROWSER_TOGGLE");
                }
                if (recover_dead_pane) {
                    closeBrowserForShell(target_idx);
                    app_state.shells[target_idx].browser_enabled = true;
                    browserTrace("shortcutToggle recovering enabled pane without a live HWND");
                } else {
                    app_state.shells[target_idx].browser_enabled = !app_state.shells[target_idx].browser_enabled;
                }
                if (app_state.shells[target_idx].browser_enabled) {
                    if (physical_shortcut) {
                        app_state.g_browser_shortcut_open_guard_shell_id = app_state.shells[target_idx].shell_id;
                        app_state.g_browser_shortcut_open_guard_until = GetTickCount64() + BROWSER_SHORTCUT_OPEN_GUARD_MS;
                        browserTrace("shortcutToggle armed 10s open guard");
                    }
                    ensureBrowserDefaultUrl(target_idx);
                    updateBrowserVisibility();
                } else {
                    if (app_state.g_browser_shortcut_open_guard_shell_id == app_state.shells[target_idx].shell_id) {
                        app_state.g_browser_shortcut_open_guard_until = 0;
                    }
                    discardBrowserUrlBarEdit();
                    if (target_idx == app_state.active_shell) {
                        app_state.g_browser_focus_mode = false;
                        app_state.g_shell_focused = true;
                    }
                    closeBrowserForShell(target_idx);
                    updateBrowserVisibility();
                    if (target_idx == app_state.active_shell) focusActiveShell();
                }
                repositionActive();
                if (app_state.shells[target_idx].browser_enabled and target_idx == app_state.active_shell) {
                    armBrowserVisibilitySettle(12);
                }
                syncMouseHookForUrlClicks();
                invalidateSidebar();
                _ = InvalidateRect(hwnd, null, 0);
                saveSession();
            }
            return 0;
        },
        WM_APP_BROWSER_MODE_TOGGLE => {
            if (app_state.active_shell < app_state.shell_count) {
                app_state.shells[app_state.active_shell].browser_native = !app_state.shells[app_state.active_shell].browser_native;
                app_state.g_browser_native_default = app_state.shells[app_state.active_shell].browser_native;
                if (app_state.shells[app_state.active_shell].browser_enabled) {
                    const had_live = app_state.shells[app_state.active_shell].browser_hwnd != null and
                        IsWindow(app_state.shells[app_state.active_shell].browser_hwnd) != 0;
                    closeBrowserForShell(app_state.active_shell);
                    if (had_live) launchBrowserForShell(app_state.active_shell);
                }
                updateBrowserVisibility();
                repositionActive();
                saveSession();
                syncMouseHookForUrlClicks();
                _ = InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        WM_APP_BROWSER_ENGINE_TOGGLE => {
            switchBrowserEngine(hwnd);
            return 0;
        },
        WM_APP_BROWSER_OPEN_URL => {
            if (app_state.active_shell < app_state.shell_count) {
                setBrowserUrlFromSearch(app_state.active_shell);
                app_state.shells[app_state.active_shell].browser_enabled = true;
                if (app_state.shells[app_state.active_shell].browser_hwnd == null or IsWindow(app_state.shells[app_state.active_shell].browser_hwnd) == 0) {
                    app_state.shells[app_state.active_shell].browser_hwnd = null;
                    app_state.shells[app_state.active_shell].browser_docking = false;
                    launchBrowserForShell(app_state.active_shell);
                } else {
                    navigateBrowserPane(app_state.active_shell, browserUrlSlice(app_state.active_shell));
                }
                saveSession();
            }
            app_state.g_browser_url_mode = false;
            app_state.g_search_active = false;
            app_state.g_shell_focused = true;
            clearSearchBackdrop();
            showActiveShellAfterOverlay();
            repositionActive();
            updateBrowserVisibility();
            syncMouseHookForUrlClicks();
            _ = InvalidateRect(hwnd, null, 0);
            _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
            return 0;
        },
        WM_APP_BROWSER_SHOTURL => {
            runActiveBrowserShotUrl();
            return 0;
        },
        WM_APP_BROWSER_DROP_GESTURE => {
            const sx: i32 = @bitCast(@as(u32, @truncate(wp)));
            const sy: i32 = @bitCast(@as(u32, @truncate(wp >> 32)));
            recordNativeBrowserDropGesture(.{ .x = sx, .y = sy });
            return 0;
        },
        WM_APP_BROWSER_BACK => {
            browserHistoryNav(false);
            return 0;
        },
        WM_APP_BROWSER_FORWARD => {
            browserHistoryNav(true);
            return 0;
        },
        WM_APP_URLBAR_DISMISS => {
            if (app_state.g_edit_is_browser_urlbar and app_state.g_edit_hwnd != null and GetFocus() != app_state.g_edit_hwnd) {
                discardBrowserUrlBarEdit();
                updateBrowserVisibility();
            }
            return 0;
        },
        WM_APP_BROWSER_FOCUS_URL => {
            if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_enabled) {
                startBrowserUrlBarEdit();
                _ = InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        WM_APP_BROWSER_FOCUS_TOGGLE => {
            altqLog("toggle_enter chat={} chat_owns={} wv2={} pane={X} pane_live={} pending={} pane_fg={} frame_fg={} fg={X} mode={} handoff={}", .{ app_state.g_chat_active, chatViewOwnsInput(), webView2OwnsActiveShell(), if (app_state.active_shell < app_state.shell_count) altqPtr(app_state.shells[app_state.active_shell].browser_hwnd) else 0, activeBrowserHwndLive() != null, app_state.g_native_browser_focus_pending_shell_id, activeBrowserHasForegroundFocus(), app_state.g_main_hwnd != null and GetForegroundWindow() == app_state.g_main_hwnd, altqPtr(GetForegroundWindow()), app_state.g_browser_focus_mode, @intFromBool(GetTickCount64() < app_state.g_chat_browser_handoff_until) });
            if (webView2OwnsActiveShell()) {
                if (webView2HasInputFocus() or app_state.g_browser_focus_mode) {
                    app_state.g_browser_focus_mode = false;
                    app_state.g_shell_focused = true;
                    focusActiveShell();
                    if (!activeShellHasForegroundFocus()) requestShellRefocus(60, 8);
                } else {
                    requestWebView2Focus();
                }
            } else if (activeBrowserHwndLive() != null) {
                if (app_state.g_native_browser_focus_pending_shell_id != 0) {
                    altqLog("toggle_pending cancel pending_sid={} chat={}", .{ app_state.g_native_browser_focus_pending_shell_id, app_state.g_chat_active });
                    cancelPendingNativeBrowserFocus();
                    app_state.g_browser_focus_mode = false;
                    app_state.g_shell_focused = true;
                    focusActiveShell();
                } else if (activeBrowserHasForegroundFocus()) {
                    altqLog("toggle_back pane_to_shell chat={} chat_owns={}", .{ app_state.g_chat_active, chatViewOwnsInput() });
                    app_state.g_chat_browser_handoff_until = 0;
                    app_state.g_browser_focus_mode = false;
                    app_state.g_shell_focused = true;
                    focusActiveShell();
                    if (!activeShellHasForegroundFocus()) requestShellRefocus(60, 8);
                } else {
                    altqLog("toggle_pane into_pane chat={} composer={X} fg={X}", .{ app_state.g_chat_active, altqPtr(app_state.g_chat_composer_hwnd), altqPtr(GetForegroundWindow()) });
                    requestNativeBrowserFocus();
                }
            } else if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_enabled) {
                altqLog("toggle_restore no_pane_hwnd chat={} enabled={}", .{ app_state.g_chat_active, app_state.shells[app_state.active_shell].browser_enabled });
                requestNativeBrowserFocus();
            }
            return 0;
        },
        WM_APP_QUIT_ALL => {
            app_state.g_quit_all_in_progress = true;
            rememberOpenWorkspaceForQuit();
            _ = PostMessageW(hwnd, WM_CLOSE, 0, 0);
            return 0;
        },
        WM_APP_RESTART => {
            var exe_buf: [512]u16 = undefined;
            const exe_len = GetModuleFileNameW(null, &exe_buf, 512);
            if (exe_len > 0 and exe_len < 512) {
                var cmd: [1024]u16 = undefined;
                var p: usize = 0;
                const prefix = "cmd.exe /c ping 127.0.0.1 -n 4 >nul & start \"\" \"";
                for (prefix) |c| {
                    cmd[p] = c;
                    p += 1;
                }
                for (0..exe_len) |i| {
                    cmd[p] = exe_buf[i];
                    p += 1;
                }
                cmd[p] = '"';
                p += 1;
                if (app_state.g_instance_name_len > 0) {
                    const inst = app_state.g_instance_name[0..app_state.g_instance_name_len];
                    const name_flag = " \"--name\" \"";
                    for (name_flag) |c| {
                        cmd[p] = c;
                        p += 1;
                    }
                    for (inst) |c| {
                        if (p >= cmd.len - 4) break;
                        cmd[p] = @intCast(c);
                        p += 1;
                    }
                    cmd[p] = '"';
                    p += 1;
                }
                cmd[p] = 0;
                var si = std.mem.zeroes(STARTUPINFOW);
                si.cb = @sizeOf(STARTUPINFOW);
                var pi = std.mem.zeroes(PROCESS_INFORMATION);
                const flags: DWORD = 0x00000008 | 0x08000000;
                if (CreateProcessW(null, @ptrCast(&cmd), null, null, 0, flags, null, null, &si, &pi) != 0) {
                    if (pi.hProcess != null) _ = CloseHandle(pi.hProcess);
                    if (pi.hThread != null) _ = CloseHandle(pi.hThread);
                }
            }
            _ = PostMessageW(app_state.g_main_hwnd, WM_CLOSE, 0, 0);
            return 0;
        },
        WM_APP_NEXT_TAB => {
            debugLog("wnd: WM_APP_NEXT_TAB");
            if (app_state.shell_count > 1) {
                if (findNextVisibleTab(app_state.active_shell, 1)) |idx| {
                    app_state.g_ws_switch_focus_grace = GetTickCount64() + 1500;
                    app_state.g_skip_view_bump = true;
                    @import("console.zig").switchToShellByUser(idx);
                    if (!activeShellHasForegroundFocus()) requestShellRefocus(120, 8);
                }
            }
            return 0;
        },
        WM_APP_PREV_TAB => {
            debugLog("wnd: WM_APP_PREV_TAB");
            if (app_state.shell_count > 1) {
                if (findNextVisibleTab(app_state.active_shell, -1)) |idx| {
                    app_state.g_ws_switch_focus_grace = GetTickCount64() + 1500;
                    app_state.g_skip_view_bump = true;
                    @import("console.zig").switchToShellByUser(idx);
                    if (!activeShellHasForegroundFocus()) requestShellRefocus(120, 8);
                }
            }
            return 0;
        },
        WM_APP_SWITCH_TAB => {
            const want: u32 = @intCast(wp);
            const target: ?u32 = if (app_state.g_single_window) nthVisibleShell(want) else (if (want < app_state.shell_count) want else null);
            if (target) |idx| {
                app_state.g_ws_switch_focus_grace = GetTickCount64() + 1500;
                app_state.g_skip_view_bump = true;
                @import("console.zig").switchToShellByUser(idx);
                if (!activeShellHasForegroundFocus()) requestShellRefocus(120, 8);
            }
            return 0;
        },
        WM_APP_SWITCH_WORKSPACE => {
            if (app_state.g_inbox_active) closeInbox(hwnd);
            switchToWorkspace(@intCast(wp));
            _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
            return 0;
        },
        WM_APP_CYCLE_WORKSPACE => {
            if (app_state.g_inbox_active) closeInbox(hwnd);
            if (app_state.g_single_window) {
                const cur: u32 = if (app_state.g_starred_workspace) 0 else @as(u32, app_state.g_active_workspace) + 1;
                const cnt: u32 = @as(u32, app_state.g_lws_count) + 1;
                var step: u32 = 1;
                while (step < cnt) : (step += 1) {
                    const next: u32 = if (wp == 1) (cur + step) % cnt else (cur + cnt - step) % cnt;
                    if (next == 0 or !app_state.g_ws_snoozed[next - 1]) {
                        switchToWorkspace(if (next == 0) @import("workspace_view.zig").starred else next - 1);
                        break;
                    }
                }
            }
            _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
            return 0;
        },
        WM_APP_INBOX_STEP => {
            if (app_state.g_single_window and !app_state.g_inbox_active and (app_state.g_starred_workspace or !app_state.g_inbox_step_context_active)) {
                _ = SendMessageW(hwnd, WM_APP_CYCLE_WORKSPACE, wp, 0);
                return 0;
            }
            inboxStepJump(if (wp == 1) 1 else -1);
            return 0;
        },
        WM_APP_SPAWN => {
            if (wp < NUM_BUTTONS) {
                if (spawnShellFromMenuIndex(wp)) {
                    requestShellRefocus(20, 12);
                    _ = PostMessageW(hwnd, WM_APP_FOCUS, 0, 0);
                }
            }
            return 0;
        },
        WM_APP_PASTE => {
            pasteClipboardToShell(@intCast(wp));
            return 0;
        },
        WM_APP_COPY => {
            const result = copyConsoleSelectionToClipboard(@intCast(wp));
            if (result == .no_selection) _ = copyClaudeLoginUrlFromActiveShell();
            return 0;
        },
        WM_APP_COPY_CLAUDE_LOGIN_URL => {
            if (wp == app_state.active_shell) _ = copyClaudeLoginUrlFromActiveShell();
            return 0;
        },
        WM_APP_DICTATION_TOGGLE => {
            toggleDictation();
            return 0;
        },
        WM_APP_DICTATION_READY => {
            handleDictationReady();
            return 0;
        },
        WM_APP_AI_PACE_READY => {
            while (!app_state.g_ai_pace_mutex.tryLock()) Sleep(0);
            const next = app_state.g_ai_pace_pending;
            app_state.g_ai_pace_mutex.unlock();
            if (next.available) app_state.g_ai_pace = next;
            clampSidebarScroll();
            invalidateSidebar();
            return 0;
        },
        WM_APP_LADDER_DONE => {
            showHeaderNoticeAscii(app_state.g_ladder_notice[0..app_state.g_ladder_notice_len], 4000, false);
            requestAiPaceRefresh();
            return 0;
        },
        WM_APP_CYCLE_STATUS_CARD => {
            cycleSidebarStatusCard(1);
            return 0;
        },
        WM_APP_COPY_OR_INTERRUPT => {
            copySelectionOrSendCtrlC(@intCast(wp));
            return 0;
        },
        @import("win32.zig").WM_APP_SHELL_DOUBLE_CLICK => {
            const sx: i32 = @bitCast(@as(u32, @truncate(wp)));
            const sy: i32 = @bitCast(@as(u32, @truncate(wp >> 32)));
            @import("clipboard.zig").shellDoubleClickAtScreenPoint(@intCast(lp), sx, sy);
            return 0;
        },
        WM_APP_OPEN_URL_AT => {
            const sx: i32 = @bitCast(@as(u32, @truncate(wp)));
            const sy: i32 = @bitCast(@as(u32, @truncate(wp >> 32)));
            openUrlAtScreenPoint(sx, sy);
            return 0;
        },
        WM_APP_NEW_WINDOW => {
            if (app_state.g_single_window) newWorkspace() else spawnNewWindow();
            return 0;
        },
        WM_APP_FOCUS => {
            if (app_state.shell_count > 0 and app_state.active_shell < app_state.shell_count and app_state.g_edit_hwnd == null and !app_state.g_search_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and !app_state.g_snippet_create_active and !app_state.g_inbox_active and !app_state.g_all_sessions_active) {
                if (app_state.shells[app_state.active_shell].hwnd != null) {
                    _ = showShellConsole(app_state.active_shell, SW_SHOW, "wndProc.WM_APP_FOCUS");
                    repositionActive();
                }
                focusActiveShell();
                syncMouseHookForUrlClicks();
                if (!activeShellHasForegroundFocus()) requestShellRefocus(120, 8);
            }
            return 0;
        },
        WM_APP_TOGGLE_INBOX => {
            toggleInbox(hwnd);
            return 0;
        },
        WM_APP_INBOX_KEY => {
            if (app_state.g_inbox_active) {
                handleInboxKey(hwnd, wp);
            } else if (wp == 29) {
                inboxUndoLastArchive(hwnd);
            }
            return 0;
        },
        WM_APP_ALL_SESSIONS_OPEN => {
            openAllSessions(hwnd);
            return 0;
        },
        WM_APP_ALL_SESSIONS_KEY => {
            if (app_state.g_all_sessions_active) handleAllSessionsKey(hwnd, wp);
            return 0;
        },
        WM_APP_ALL_SESSIONS_FILTER_OPEN => {
            openAllSessionsFilter(hwnd);
            return 0;
        },
        WM_APP_ALL_SESSIONS_FILTER_CHAR => {
            if (app_state.g_all_sessions_active and app_state.g_all_sessions_filter_active and app_state.g_all_sessions_filter_len < 64) {
                app_state.g_all_sessions_filter_buf[app_state.g_all_sessions_filter_len] = @intCast(wp);
                app_state.g_all_sessions_filter_len += 1;
                app_state.g_all_sessions_sel = 0;
                _ = InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        WM_APP_ALL_SESSIONS_FILTER_BACKSPACE => {
            if (app_state.g_all_sessions_active and app_state.g_all_sessions_filter_active and app_state.g_all_sessions_filter_len > 0) {
                app_state.g_all_sessions_filter_len -= 1;
                app_state.g_all_sessions_sel = 0;
                _ = InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        WM_APP_ALL_SESSIONS_FILTER_CLOSE => {
            closeAllSessionsFilter(hwnd);
            return 0;
        },
        WM_APP_INBOX_FILTER_OPEN => {
            openInboxFilter(hwnd);
            return 0;
        },
        WM_APP_INBOX_FILTER_CHAR => {
            if (app_state.g_inbox_active and app_state.g_inbox_filter_active and app_state.g_inbox_filter_len < app_state.g_inbox_filter_buf.len) {
                app_state.g_inbox_filter_buf[app_state.g_inbox_filter_len] = @intCast(wp);
                app_state.g_inbox_filter_len += 1;
                app_state.g_inbox_sel = 0;
                _ = InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        WM_APP_INBOX_FILTER_BACKSPACE => {
            if (app_state.g_inbox_active and app_state.g_inbox_filter_active and app_state.g_inbox_filter_len > 0) {
                app_state.g_inbox_filter_len -= 1;
                app_state.g_inbox_sel = 0;
                _ = InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        WM_APP_INBOX_FILTER_CLOSE => {
            closeInboxFilter(hwnd);
            return 0;
        },
        WM_APP_FOCUS_SHELL => {
            const sid: u32 = @truncate(wp);
            const inbox_ctx_encoded: u32 = if (lp > 0) @intCast(lp) else 0;
            if (inbox_ctx_encoded > 0) armInboxStepContext(inbox_ctx_encoded - 1);
            if (app_state.g_inbox_active) closeInbox(hwnd);
            if (findShellById(sid)) |idx| {
                if (inbox_ctx_encoded > 0) {
                    app_state.g_inbox_shell_focus_until = GetTickCount64() + 3500;
                    app_state.g_ws_switch_focus_grace = app_state.g_inbox_shell_focus_until;
                }
                const prev_jump = app_state.g_inbox_step_jump_active;
                app_state.g_inbox_step_jump_active = inbox_ctx_encoded > 0;
                defer app_state.g_inbox_step_jump_active = prev_jump;
                if (app_state.g_single_window) {
                    app_state.g_active_workspace = app_state.shells[idx].workspace;
                    updateMainWindowTitle();
                }
                if (lp < 0) @import("console.zig").switchToShellByUser(idx) else switchToShell(idx);
                if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].hwnd != null) {
                    _ = showShellConsole(app_state.active_shell, SW_SHOW, "wndProc.WM_APP_FOCUS_SHELL");
                    repositionActive();
                }
                focusActiveShell();
                if (inbox_ctx_encoded > 0) {
                    requestShellRefocus(80, 24);
                } else if (!activeShellHasForegroundFocus()) {
                    requestShellRefocus(120, 8);
                }
            }
            return 0;
        },
        WM_APP_INBOX_ARCHIVE, WM_APP_INBOX_MARKUNREAD, WM_APP_INBOX_UNARCHIVE => {
            const sid: u32 = @truncate(wp);
            if (findShellById(sid)) |idx| {
                if (msg == WM_APP_INBOX_ARCHIVE) {
                    recordInboxArchive(idx);
                    app_state.shells[idx].needs_attention = false;
                    app_state.shells[idx].hidden_idle_streak = 0;
                } else if (msg == WM_APP_INBOX_UNARCHIVE) {
                    app_state.shells[idx].inbox_archived = false;
                    logUnarchive(idx, "undo archive");
                    app_state.shells[idx].hidden_idle_streak = 0;
                    if (lp != 0) _ = setBlueDot(idx, .manual, false);
                } else {
                    const want_unread = (lp != 0);
                    if (want_unread) {
                        _ = setBlueDot(idx, .manual, false);
                    } else {
                        app_state.shells[idx].needs_attention = false;
                    }
                    if (want_unread and app_state.shells[idx].inbox_archived) logUnarchive(idx, "explicit mark unread");
                    if (want_unread) app_state.shells[idx].inbox_archived = false;
                }
                if (msg == WM_APP_INBOX_ARCHIVE or msg == WM_APP_INBOX_UNARCHIVE) {
                    publishInboxStateNow();
                } else {
                    publishInboxState();
                }
                saveSession();
                invalidateSidebar();
            }
            return 0;
        },
        WM_APP_SESSION_INTERACTED => {
            _ = commitArchivedSessionReturn(@truncate(wp));
            return 0;
        },
        WM_APP_URL_PICKER_OPEN => {
            openUrlPicker();
            return 0;
        },
        WM_APP_URL_PICKER_MOVE => {
            if (app_state.g_url_picker_count > 0) {
                if (wp == 0) {
                    app_state.g_url_picker_sel = if (app_state.g_url_picker_sel == 0) app_state.g_url_picker_count - 1 else app_state.g_url_picker_sel - 1;
                } else {
                    app_state.g_url_picker_sel = if (app_state.g_url_picker_sel + 1 >= app_state.g_url_picker_count) 0 else app_state.g_url_picker_sel + 1;
                }
                _ = InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        WM_APP_URL_PICKER_CONFIRM => {
            const idx = app_state.g_url_picker_sel;
            closeUrlPickerForBrowser();
            openUrlByIndex(idx);
            return 0;
        },
        WM_APP_URL_PICKER_CLOSE => {
            closeUrlPicker();
            return 0;
        },
        WM_APP_NEXT_UNREAD => {
            if (app_state.shell_count > 1) {
                var step: u32 = 1;
                while (step < app_state.shell_count) : (step += 1) {
                    const idx: u32 = (app_state.active_shell + step) % app_state.shell_count;
                    if (app_state.shells[idx].needs_attention) {
                        switchToShell(idx);
                        _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                        break;
                    }
                }
            }
            return 0;
        },
        WM_APP_TOGGLE_UNREAD => {
            app_state.g_unread_only = !app_state.g_unread_only;
            if (app_state.g_inbox_active and !inboxSplitVisible(app_state.g_inbox_tab)) app_state.g_inbox_tab = @import("inbox.zig").firstInboxSplit();
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_APP_MARK_ACTIVE_UNREAD => {
            markActiveShellUnread();
            return 0;
        },
        WM_APP_TOGGLE_KEEP_AWAKE => {
            toggleKeepAwakeForActiveShell();
            return 0;
        },
        WM_APP_FONT_BIGGER => {
            if (chatViewOwnsInput()) {
                app_state.g_chat_font_pt = @min(28, app_state.g_chat_font_pt + 1);
                resetFontCache();
                layoutChatControls();
                chatRefreshAfterFontChange();
                _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
                saveSession();
                var cfb: [64]u8 = undefined;
                const cfs = std.fmt.bufPrint(&cfb, "Chat text size: {d}", .{app_state.g_chat_font_pt}) catch "Chat text size";
                showHeaderNoticeAscii(cfs, 1500, false);
                return 0;
            }
            const cur_h: i16 = if (app_state.g_console_font_override > 0) app_state.g_console_font_override else baseFont96(app_state.active_shell);
            app_state.g_console_font_override = @min(40, cur_h + 1);
            fontSyncMarkAllStale(hwnd, "ctrl-font");
            fontSyncActiveNow();
            repositionActive();
            saveSession();
            var fb: [64]u8 = undefined;
            const fs = std.fmt.bufPrint(&fb, "Console font: {d}", .{app_state.g_console_font_override}) catch "Console font";
            showHeaderNoticeAscii(fs, 1500, false);
            return 0;
        },
        WM_APP_FONT_SMALLER => {
            if (chatViewOwnsInput()) {
                app_state.g_chat_font_pt = @max(10, app_state.g_chat_font_pt - 1);
                resetFontCache();
                layoutChatControls();
                chatRefreshAfterFontChange();
                _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
                saveSession();
                var cfb: [64]u8 = undefined;
                const cfs = std.fmt.bufPrint(&cfb, "Chat text size: {d}", .{app_state.g_chat_font_pt}) catch "Chat text size";
                showHeaderNoticeAscii(cfs, 1500, false);
                return 0;
            }
            const cur_h2: i16 = if (app_state.g_console_font_override > 0) app_state.g_console_font_override else baseFont96(app_state.active_shell);
            app_state.g_console_font_override = @max(8, cur_h2 - 1);
            fontSyncMarkAllStale(hwnd, "ctrl-font");
            fontSyncActiveNow();
            repositionActive();
            saveSession();
            var fb: [64]u8 = undefined;
            const fs = std.fmt.bufPrint(&fb, "Console font: {d}", .{app_state.g_console_font_override}) catch "Console font";
            showHeaderNoticeAscii(fs, 1500, false);
            return 0;
        },
        WM_APP_FONT_RESET => {
            if (chatViewOwnsInput()) {
                app_state.g_chat_font_pt = CHAT_FONT_DEFAULT_PT;
                resetFontCache();
                layoutChatControls();
                chatRefreshAfterFontChange();
                _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
                saveSession();
                showHeaderNoticeAscii("Chat text size: default", 1500, false);
                return 0;
            }
            app_state.g_console_font_override = 0;
            fontSyncMarkAllStale(hwnd, "ctrl-font-reset");
            fontSyncActiveNow();
            repositionActive();
            saveSession();
            showHeaderNoticeAscii("Console font: native default", 1500, false);
            return 0;
        },
        WM_APP_NEW_TAB_DEFAULT => {
            if (app_state.shell_count >= MAX_SHELLS) {
                notifyTabCapReached();
                return 0;
            }
            if (app_state.g_all_sessions_active) closeAllSessions(hwnd);
            if (app_state.g_inbox_active) closeInbox(hwnd);
            if (spawnWorkspaceTmuxSession()) {
                applyPendingGroup();
                _ = InvalidateRect(hwnd, null, 0);
                app_state.g_refocus_remaining = 4;
                _ = SetTimer(hwnd, TIMER_REFOCUS, 200, null);
                return 0;
            }
            showHeaderNoticeAscii("Workspace folder unavailable", 3000, true);
            _ = PostMessageW(hwnd, WM_APP_SEARCH_OPEN, 0, 0);
            return 0;
        },
        WM_APP_UI_BIGGER => {
            if (app_state.g_ui_scale < 150) app_state.g_ui_scale = @min(150, (app_state.g_ui_scale / 10 + 1) * 10);
            resetFontCache();
            repositionActive();
            saveSession();
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_APP_UI_SMALLER => {
            if (app_state.g_ui_scale > 80) app_state.g_ui_scale = @max(80, (app_state.g_ui_scale / 10 - 1) * 10);
            resetFontCache();
            repositionActive();
            saveSession();
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_APP_UI_RESET => {
            app_state.g_ui_scale = 100;
            resetFontCache();
            repositionActive();
            saveSession();
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_APP_MOVE_TAB => {
            const dir: i32 = if (wp == 1) 1 else -1;
            if (app_state.g_tab_sort_auto) {
                return 0;
            }
            if (moveActiveTabStep(dir)) {
                ensureActiveVisible();
                _ = InvalidateRect(hwnd, null, 0);
                saveSession();
            }
            return 0;
        },
        WM_APP_TOGGLE_GROUP => {
            if (app_state.active_shell >= app_state.shell_count) return 0;
            const gid = app_state.shells[app_state.active_shell].group_id;
            if (gid == 0) return 0;
            if (findGroupIdx(gid)) |gidx| {
                app_state.groups[gidx].collapsed = !app_state.groups[gidx].collapsed;
                if (app_state.groups[gidx].collapsed) {
                    if (findNextVisibleTab(app_state.active_shell, 1)) |nxt| {
                        switchToShell(nxt);
                    } else if (findNextVisibleTab(app_state.active_shell, -1)) |prv| {
                        switchToShell(prv);
                    }
                }
                clampSidebarScroll();
                _ = InvalidateRect(hwnd, null, 0);
                saveSession();
            }
            return 0;
        },
        WM_APP_CLOSE => {
            if (app_state.shell_count > 0) {
                closeShell(app_state.active_shell);
            }
            return 0;
        },
        WM_APP_CLOSE_SESSION => {
            if (app_state.shell_count > 0) {
                if (app_state.shells[app_state.active_shell].tmux_session_len > 0) {
                    endActiveTmuxSession();
                } else {
                    closeNonTmuxTabAt(app_state.active_shell);
                }
            }
            return 0;
        },
        WM_APP_CHAT_TOGGLE => {
            toggleChatView();
            return 0;
        },
        WM_APP_CHAT_COPY_CODE => {
            chatCopyLatestCode();
            return 0;
        },
        WM_APP_CHAT_ATTACH => {
            chatAttachPick();
            return 0;
        },
        WM_APP_CHAT_IMAGE_READY => {
            chatImageReady();
            return 0;
        },
        WM_APP_CHAT_ATTACH_FAILED => {
            if (lp != 0) @import("chat_render.zig").chatFileNotice(lp) else showHeaderNoticeAscii(chatAttachErrorText(wp), 4000, true);
            return 0;
        },
        WM_APP_CHAT_COPY_SELECTION => {
            chatCopySelection();
            return 0;
        },
        WM_APP_CHAT_SELECT_ALL => {
            chatSelectAll();
            return 0;
        },
        app_state.WM_APP_CHAT_FIND => {
            @import("chat_find_ui.zig").key(wp, @truncate(@as(usize, @bitCast(lp))));
            return 0;
        },
        WM_APP_CHAT_FILE_READY => {
            chatFileOnReady();
            return 0;
        },
        WM_APP_CHAT_AC_READY => {
            chatAcOnFetchDone(@intCast(wp), @intCast(lp));
            return 0;
        },
        WM_APP_CHAT_SEND => {
            sendChatPrompt();
            return 0;
        },
        WM_APP_VOICE_SPEECH_START => {
            const event: usize = @bitCast(lp);
            if (@as(u32, @truncate(event >> 1)) == app_state.g_voice_mic_epoch.load(.acquire)) voiceHandleSpeechStart(@truncate(wp), (event & 1) != 0);
            return 0;
        },
        WM_APP_VOICE_UTTERANCE_READY => {
            const id: u32 = @truncate(wp);
            var result: VoiceResult = undefined;
            var ready = false;
            while (!app_state.g_voice_result_mutex.tryLock()) Sleep(0);
            const slot = &app_state.g_voice_results[id % app_state.g_voice_results.len];
            if (slot.ready and slot.result.id == id) {
                result = slot.result;
                slot.ready = false;
                ready = true;
            }
            app_state.g_voice_result_mutex.unlock();
            if (ready) voiceHandleUtterance(&result);
            return 0;
        },
        WM_APP_VOICE_MIC_STATUS => {
            if (@as(u32, @truncate(@as(usize, @bitCast(lp)))) != app_state.g_voice_mic_epoch.load(.acquire)) return 0;
            if (app_state.g_voice_mode_active and app_state.g_voice_always_listen) {
                if (wp == 2 and !app_state.g_voice_echo_notice_shown) {
                    app_state.g_voice_echo_notice_shown = true;
                    showHeaderNoticeAscii("No echo cancelling on this mic: talk over it clearly or use headphones", 5000, true);
                } else if (wp == 3) {
                    app_state.g_voice_mic_failed = true;
                    dictationAudit("voice-duplex-mic-failed", @intCast(lp));
                    showHeaderNoticeAscii("Always listening unavailable, taking turns", 5000, true);
                    if (app_state.g_voice_state == .idle) voiceStartListening();
                    invalidateChatHeader();
                }
            }
            return 0;
        },
        WM_APP_VOICE_TOGGLE => {
            switch (duplex.voiceToggleAction(app_state.g_voice_mode_active, app_state.g_voice_state == .speaking, wp)) {
                .turn_on => setVoiceModeActive(true),
                .turn_off => setVoiceModeActive(false),
                .stop_speaking => _ = PostMessageW(hwnd, WM_APP_VOICE_BARGE_IN, 0, 0),
            }
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_APP_VOICE_BARGE_IN => {
            if (app_state.g_voice_state == .speaking) {
                dictationAudit("voice-stop", 1);
                voiceStopSpeaking();
                if (!app_state.g_voice_mode_active) voiceTtsDeviceStop();
                app_state.g_voice_tts_audible.store(false, .release);
                app_state.g_voice_tts_quiet_since.store(GetTickCount64(), .release);
                app_state.g_voice_state = .idle;
                app_state.g_voice_replay_only = false;
                app_state.g_voice_highlight = null;
                if (app_state.g_chat_transcript_hwnd != null) _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
                if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_VOICE_POLL);
                invalidateChatHeader();
            }
            return 0;
        },
        WM_APP_VOICE_REPLAY => {
            voiceReadReply(.latest);
            return 0;
        },
        WM_APP_VOICE_STEP => {
            voiceReadReply(if (wp == 0) .previous else .next);
            return 0;
        },
        WM_APP_VOICE_TTS_AUDIO_STARTED => {
            if (app_state.g_voice_state == .speaking) {
                invalidateChatHeader();
                if (app_state.g_main_hwnd != null) _ = SetTimer(app_state.g_main_hwnd, TIMER_VOICE_TTS_POS, 1000, null);
            }
            return 0;
        },
        WM_APP_VOICE_TTS_FALLBACK => {
            if ((!app_state.g_voice_replay_only and !app_state.g_voice_mode_active) or app_state.g_voice_state != .speaking or app_state.active_shell >= app_state.shell_count or app_state.shells[app_state.active_shell].shell_id != app_state.g_voice_tts_fallback_shell_id) return 0;
            if (!app_state.g_voice_tts_fallback_shown.swap(true, .acq_rel)) {
                showHeaderNoticeAscii("Deepgram voice unavailable, using Windows voice", 4000, true);
            }
            if (!voiceSapiStart()) {
                app_state.g_voice_state = .idle;
                showHeaderNoticeAscii("Voice Mode: text-to-speech unavailable", 4000, true);
                invalidateChatHeader();
                return 0;
            }
            app_state.g_voice_state = .speaking;
            app_state.g_voice_tts_audio_started.store(true, .release);
            app_state.g_voice_tts_since.store(GetTickCount64(), .release);
            voiceSpeak(app_state.g_voice_tts_fallback_text[0..app_state.g_voice_tts_fallback_len]);
            app_state.g_voice_tts_audible.store(true, .release);
            if (app_state.g_main_hwnd != null) _ = SetTimer(app_state.g_main_hwnd, TIMER_VOICE_POLL, 150, null);
            invalidateChatHeader();
            return 0;
        },
        @import("win32.zig").WM_APP_CHAT_PERMISSION => {
            if (wp < 3) _ = @import("chat_send.zig").chatPermissionAnswer(app_state.active_shell, @enumFromInt(wp));
            return 0;
        },
        WM_APP_CHAT_INTERRUPT => {
            if (app_state.g_chat_active and app_state.active_shell < app_state.shell_count) {
                if (app_state.ISSUE_265_WORKING_BAR) _ = @import("chat_send.zig").chatStopAgent(app_state.active_shell) else sendCtrlCToShell(app_state.active_shell);
                _ = SetFocus(app_state.g_chat_composer_hwnd);
                _ = SetTimer(hwnd, TIMER_CHAT_REFRESH, 120, null);
            }
            return 0;
        },
        WM_KEYDOWN => {
            if (app_state.g_url_picker_active) {
                if (wp == 0x26) {
                    if (app_state.g_url_picker_count > 0) app_state.g_url_picker_sel = if (app_state.g_url_picker_sel == 0) app_state.g_url_picker_count - 1 else app_state.g_url_picker_sel - 1;
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (wp == 0x28) {
                    if (app_state.g_url_picker_count > 0) app_state.g_url_picker_sel = if (app_state.g_url_picker_sel + 1 >= app_state.g_url_picker_count) 0 else app_state.g_url_picker_sel + 1;
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (wp == 0x0D) {
                    const idx = app_state.g_url_picker_sel;
                    closeUrlPicker();
                    openUrlByIndex(idx);
                    return 0;
                }
                if (wp == 0x1B) {
                    closeUrlPicker();
                    return 0;
                }
            }
            if ((app_state.g_search_active or chatViewOwnsInput()) and chatPaletteToggleKeyDown(wp)) {
                postPaletteToggle();
                return 0;
            }
            if (app_state.g_search_active) {
                if (wp == 0x26) {
                    _ = PostMessageW(hwnd, WM_APP_SEARCH_MOVE, 0, 0);
                    return 0;
                }
                if (wp == 0x28) {
                    _ = PostMessageW(hwnd, WM_APP_SEARCH_MOVE, 1, 0);
                    return 0;
                }
                if (wp == 0x0D) {
                    _ = PostMessageW(hwnd, WM_APP_SEARCH_CONFIRM, 0, 0);
                    return 0;
                }
                if (wp == 0x1B) {
                    if (app_state.g_browser_url_mode) {
                        _ = PostMessageW(hwnd, WM_APP_SEARCH_BACKSPACE, 1, 0);
                    } else {
                        _ = PostMessageW(hwnd, WM_APP_SEARCH_CLOSE, 0, 0);
                    }
                    return 0;
                }
                if (wp == 0x08) {
                    _ = PostMessageW(hwnd, WM_APP_SEARCH_BACKSPACE, 0, 0);
                    return 0;
                }
                if (wp == 0x2E and app_state.g_search_snippet_mode) {
                    _ = PostMessageW(hwnd, WM_APP_SNIPPET_DELETE, 0, 0);
                    return 0;
                }
            }
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
        0x0102 => {
            if (app_state.g_search_active and paletteAcceptsChar(wp)) {
                _ = PostMessageW(hwnd, WM_APP_SEARCH_CHAR, wp, 0);
                return 0;
            }
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
        WM_APP_SEARCH_OPEN => {
            if (wp == 1 and foregroundIsOurs()) {
                cancelShellRefocus(hwnd);
                const fg = GetForegroundWindow();
                const our_thread = GetCurrentThreadId();
                const fg_thread = GetWindowThreadProcessId(fg, null);
                const attached = fg_thread != 0 and fg_thread != our_thread and AttachThreadInput(our_thread, fg_thread, 1) != 0;
                _ = SetForegroundWindow(hwnd);
                _ = SetFocus(hwnd);
                if (attached) _ = AttachThreadInput(our_thread, fg_thread, 0);
                if (GetForegroundWindow() == hwnd) app_state.g_browser_focus_mode = false;
            }
            if (app_state.g_all_sessions_active) {
                closeAllSessions(hwnd);
            }
            if (app_state.g_inbox_active) {
                app_state.g_search_from_inbox = true;
                if (frequent.splitKind(app_state.g_inbox_tab) == .workspace and frequent.splitKind(app_state.g_inbox_tab).workspace < app_state.g_inbox_ws_count) {
                    const wi: usize = frequent.splitKind(app_state.g_inbox_tab).workspace;
                    const iws = app_state.g_inbox_ws[wi];
                    const self_hwnd_val: usize = @intFromPtr(app_state.g_main_hwnd);
                    if (app_state.g_single_window and iws.hwnd == self_hwnd_val) {
                        var found_slot: u8 = 0xFF;
                        var s: u8 = 0;
                        while (s < app_state.g_lws_count) : (s += 1) {
                            var nbuf: [32]u8 = undefined;
                            const nm = workspaceDisplayName(s, &nbuf);
                            if (nm.len == iws.name_len and
                                std.mem.eql(u8, nm, iws.name[0..iws.name_len]))
                            {
                                found_slot = s;
                                break;
                            }
                        }
                        app_state.g_search_spawn_ws = found_slot;
                    } else {
                        app_state.g_search_spawn_ws = 0xFF;
                    }
                } else {
                    app_state.g_search_spawn_ws = 0xFF;
                }
            } else {
                app_state.g_search_from_inbox = false;
                app_state.g_search_spawn_ws = 0xFF;
            }
            const was_search_active = app_state.g_search_active;
            cancelShellRefocus(hwnd);
            app_state.g_search_active = true;
            app_state.g_search_workspace_mode = false;
            app_state.g_search_workspace_delete_mode = false;
            app_state.g_search_workspace_delete_confirm = null;
            app_state.g_search_snippet_delete_confirm = null;
            app_state.g_search_theme_mode = false;
            app_state.g_search_ws_sort_mode = false;
            app_state.g_search_ws_move_mode = false;
            app_state.g_wsmove_tab_sid = 0;
            app_state.g_search_group_move_mode = false;
            app_state.g_groupmove_tab_sid = 0;
            app_state.g_search_skills_mode = false;
            app_state.g_search_tabctx_mode = false;
            app_state.g_search_openall_host_mode = false;
            app_state.g_tabctx_sid = 0;
            app_state.g_search_remind_input_mode = false;
            app_state.g_search_rename_input_mode = false;
            app_state.g_search_rename_sid = 0;
            app_state.g_search_rename_select_all = false;
            app_state.g_search_remind_preset_mode = false;
            app_state.g_search_reminders_mode = false;
            app_state.g_search_ws_snoozed_mode = false;
            app_state.g_remind_ws_id_len = 0;
            app_state.g_search_session_overview_mode = false;
            app_state.g_remind_sid = 0;
            app_state.g_remind_target_sid = 0;
            app_state.g_browser_url_mode = false;
            app_state.g_wssort_dragging = false;
            app_state.g_search_len = 0;
            app_state.g_search_sel = 0;
            app_state.g_search_scroll = 0;
            app_state.g_search_wheel_remainder = 0;
            app_state.g_tmux_fetch_tick = 0;
            fetchTmuxSessions();
            reconcileWorkspaceRegistry(false);
            refreshNextUnreadCache();
            loadCustomCommandsIfChanged();
            loadPaletteUsage();
            loadSnippetsIfChanged();
            updateSearchResults();
            if (!was_search_active and !app_state.g_search_from_inbox) {
                captureSearchBackdrop();
            }
            if (!app_state.g_search_from_inbox) {
                hideShellsForOverlay();
                updateBrowserVisibility();
            }
            _ = SetFocus(app_state.g_main_hwnd);
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_APP_SEARCH_CLOSE => {
            const was_from_inbox = app_state.g_search_from_inbox;
            app_state.g_search_from_inbox = false;
            app_state.g_search_spawn_ws = 0xFF;

            app_state.g_search_active = false;
            app_state.g_search_workspace_mode = false;
            app_state.g_search_workspace_delete_mode = false;
            app_state.g_search_workspace_delete_confirm = null;
            app_state.g_search_snippet_delete_confirm = null;
            app_state.g_search_theme_mode = false;
            app_state.g_search_ws_sort_mode = false;
            app_state.g_search_ws_move_mode = false;
            app_state.g_wsmove_tab_sid = 0;
            app_state.g_search_group_move_mode = false;
            app_state.g_groupmove_tab_sid = 0;
            app_state.g_search_skills_mode = false;
            app_state.g_search_tabctx_mode = false;
            app_state.g_search_openall_host_mode = false;
            app_state.g_tabctx_sid = 0;
            app_state.g_search_remind_input_mode = false;
            app_state.g_search_rename_input_mode = false;
            app_state.g_search_rename_sid = 0;
            app_state.g_search_rename_select_all = false;
            app_state.g_search_remind_preset_mode = false;
            app_state.g_search_reminders_mode = false;
            app_state.g_search_ws_snoozed_mode = false;
            app_state.g_remind_ws_id_len = 0;
            app_state.g_search_session_overview_mode = false;
            app_state.g_remind_sid = 0;
            app_state.g_remind_target_sid = 0;
            app_state.g_browser_url_mode = false;
            if (app_state.g_wssort_dragging) {
                app_state.g_wssort_dragging = false;
                _ = ReleaseCapture();
            }
            app_state.g_shell_focused = true;
            app_state.g_search_wheel_remainder = 0;
            clearSearchBackdrop();
            app_state.g_pending_new_tab_group = 0;
            if (was_from_inbox) {
                _ = InvalidateRect(hwnd, null, 0);
            } else {
                showActiveShellAfterOverlay();
                _ = InvalidateRect(hwnd, null, 0);
                if (app_state.shell_count > 0) {
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 100, null);
                }
            }
            return 0;
        },
        WM_APP_SNIPPETS_OPEN => {
            _ = SendMessageW(hwnd, WM_APP_SEARCH_OPEN, 0, 0);
            app_state.g_search_snippet_mode = true;
            app_state.g_search_workspace_mode = false;
            app_state.g_search_workspace_delete_mode = false;
            app_state.g_search_workspace_delete_confirm = null;
            app_state.g_search_snippet_delete_confirm = null;
            app_state.g_search_theme_mode = false;
            app_state.g_search_ws_sort_mode = false;
            app_state.g_search_ws_move_mode = false;
            app_state.g_wsmove_tab_sid = 0;
            app_state.g_search_tabctx_mode = false;
            app_state.g_tabctx_sid = 0;
            app_state.g_search_session_overview_mode = false;
            app_state.g_search_rename_input_mode = false;
            app_state.g_search_rename_sid = 0;
            app_state.g_search_rename_select_all = false;
            app_state.g_browser_url_mode = false;
            app_state.g_search_len = 0;
            app_state.g_search_sel = 0;
            app_state.g_search_scroll = 0;
            loadSnippetsIfChanged();
            app_state.g_search_snippet_delete_confirm = null;
            updateSearchResults();
            if (app_state.g_search_result_count > 1) {
                app_state.g_search_sel = 1;
                keepSearchSelectionVisible();
            }
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_APP_WS_SNOOZE_OPEN => {
            if (!app_state.g_single_window) {
                showHeaderNoticeAscii("Workspace snooze needs single-window mode", 3500, true);
                return 0;
            }
            if (wp == 0 and app_state.g_starred_workspace) return 0;
            const ws: u8 = if (wp == 0) app_state.g_active_workspace else @intCast(wp - 1);
            if (ws >= app_state.g_lws_count or app_state.g_ws_snoozed[ws]) return 0;
            if (workspace_snooze.nextVisible(ws, app_state.g_ws_snoozed[0..app_state.g_lws_count]) == null) {
                showHeaderNoticeAscii("Can't snooze your only open workspace", 3500, true);
                return 0;
            }
            ensureWorkspaceSlotId(ws);
            if (app_state.g_inbox_active) closeInbox(hwnd);
            _ = SendMessageW(hwnd, WM_APP_SEARCH_OPEN, 0, 0);
            app_state.g_remind_ws_id_len = copyAsciiField(&app_state.g_remind_ws_id, app_state.g_ws_ids[ws][0..app_state.g_ws_id_len[ws]]);
            app_state.g_remind_sid = 0;
            app_state.g_remind_target_sid = 0;
            app_state.g_search_remind_preset_mode = true;
            app_state.g_search_len = 0;
            app_state.g_search_sel = 0;
            app_state.g_search_scroll = 0;
            updateSearchResults();
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_APP_REMIND_PRESETS_OPEN => {
            if (app_state.active_shell >= app_state.shell_count or app_state.shells[app_state.active_shell].tmux_session_len == 0) {
                showHeaderNoticeAscii("Remind Me needs a tmux session", 3000, true);
                return 0;
            }
            _ = SendMessageW(hwnd, WM_APP_SEARCH_OPEN, 0, 0);
            app_state.g_remind_ws_id_len = 0;
            app_state.g_remind_target_sid = 0;
            app_state.g_remind_sid = app_state.shells[app_state.active_shell].shell_id;
            app_state.g_search_remind_preset_mode = true;
            app_state.g_search_len = 0;
            app_state.g_search_sel = 0;
            app_state.g_search_scroll = 0;
            updateSearchResults();
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_APP_SNIPPET_FORM_SAVE => {
            saveSnippetFromForm();
            return 0;
        },
        WM_APP_SNIPPET_FORM_CANCEL => {
            closeSnippetCreateForm(true);
            return 0;
        },
        WM_APP_SNIPPET_DELETE => {
            if (!app_state.g_search_active or !app_state.g_search_snippet_mode or app_state.g_search_result_count == 0) return 0;
            const target = app_state.g_search_results[app_state.g_search_sel];
            if (target < SEARCH_SNIPPET_OFFSET or target >= SEARCH_SNIPPET_OFFSET + MAX_SNIPPETS) return 0;
            const sn_idx = target - SEARCH_SNIPPET_OFFSET;
            if (sn_idx >= app_state.g_snippet_count) return 0;
            if (app_state.g_search_snippet_delete_confirm) |confirm_idx| {
                if (confirm_idx == sn_idx) {
                    const old_sel = app_state.g_search_sel;
                    if (deleteSnippet(sn_idx)) {
                        app_state.g_search_snippet_delete_confirm = null;
                        updateSearchResults();
                        if (app_state.g_search_result_count > 0) app_state.g_search_sel = @min(old_sel, app_state.g_search_result_count - 1);
                        keepSearchSelectionVisible();
                        showHeaderNoticeAscii("Snippet deleted", 1800, false);
                        _ = InvalidateRect(hwnd, null, 0);
                    }
                    return 0;
                }
            }
            app_state.g_search_snippet_delete_confirm = sn_idx;
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_APP_CHANGELOG_OPEN => {
            if (app_state.g_changelog_active) {
                closeChangelogOverlay(hwnd, true);
                return 0;
            }

            cancelShellRefocus(hwnd);
            if (app_state.g_search_active) {
                app_state.g_search_active = false;
                app_state.g_browser_url_mode = false;
            }
            if (app_state.g_search_from_inbox) {
                app_state.g_search_from_inbox = false;
                app_state.g_search_spawn_ws = 0xFF;
                if (app_state.g_inbox_active) closeInbox(hwnd);
            } else if (app_state.g_inbox_active) {
                closeInbox(hwnd);
            }
            if (app_state.g_all_sessions_active) closeAllSessions(hwnd);
            if (app_state.g_url_picker_active) closeUrlPicker();
            app_state.g_shortcuts_active = false;
            app_state.g_changelog_active = true;
            app_state.g_changelog_scroll = 0;
            app_state.g_changelog_sel = 0;
            if (app_state.g_search_backdrop_bmp == null) {
                captureSearchBackdrop();
            }
            hideShellsForOverlay();
            updateBrowserVisibility();
            _ = SetFocus(app_state.g_main_hwnd);
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_APP_CHANGELOG_CLOSE => {
            closeChangelogOverlay(hwnd, true);
            return 0;
        },
        WM_APP_CHANGELOG_MOVE => {
            moveChangelogSelection(wp);
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_APP_CHANGELOG_CONFIRM => {
            const idx = app_state.g_changelog_sel;
            if (idx >= 0 and idx < @as(i32, @intCast(CHANGELOG.len))) {
                const uidx: usize = @intCast(idx);
                if (changelogDefaultTicket(uidx).len > 0) {
                    closeChangelogOverlay(hwnd, true);
                    openChangelogTicket(idx);
                }
            }
            return 0;
        },
        WM_APP_LAYOUT_READY => {
            handleLayoutReply(lp);
            return 0;
        },
        WM_APP_SHORTCUTS_OPEN => {
            cancelShellRefocus(hwnd);
            if (app_state.g_all_sessions_active) closeAllSessions(hwnd);
            app_state.g_changelog_active = false;
            app_state.g_shortcuts_active = true;
            app_state.g_shortcuts_scroll = 0;
            app_state.g_eta_accuracy_active = (wp == 1);
            if (app_state.g_eta_accuracy_active) loadEtaAccuracy();
            if (app_state.g_search_backdrop_bmp == null) {
                captureSearchBackdrop();
            }
            hideShellsForOverlay();
            _ = SetFocus(app_state.g_main_hwnd);
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_APP_SHORTCUTS_CLOSE => {
            app_state.g_shortcuts_active = false;
            app_state.g_eta_accuracy_active = false;
            app_state.g_shell_focused = true;
            clearSearchBackdrop();
            showActiveShellAfterOverlay();
            _ = InvalidateRect(hwnd, null, 0);
            if (app_state.shell_count > 0) {
                _ = SetTimer(hwnd, TIMER_REFOCUS, 100, null);
            }
            return 0;
        },
        WM_APP_SHORTCUTS_SCROLL => {
            switch (wp) {
                0 => app_state.g_shortcuts_scroll -= 1,
                1 => app_state.g_shortcuts_scroll += 1,
                2 => app_state.g_shortcuts_scroll -= 6,
                3 => app_state.g_shortcuts_scroll += 6,
                4 => app_state.g_shortcuts_scroll = 0,
                5 => app_state.g_shortcuts_scroll = 1_000_000,
                else => {},
            }
            if (app_state.g_shortcuts_scroll < 0) app_state.g_shortcuts_scroll = 0;
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_APP_SEARCH_CHAR => {
            if (app_state.g_search_ws_sort_mode) return 0;
            if (app_state.g_search_rename_input_mode and app_state.g_search_rename_select_all) {
                app_state.g_search_len = 0;
                app_state.g_search_rename_select_all = false;
            }
            if (app_state.g_search_len < 63) {
                app_state.g_search_buf[app_state.g_search_len] = @intCast(wp);
                app_state.g_search_len += 1;
                app_state.g_search_sel = 0;
                app_state.g_search_scroll = 0;
                app_state.g_search_workspace_delete_confirm = null;
                app_state.g_search_snippet_delete_confirm = null;
                if (!app_state.g_browser_url_mode and !app_state.g_search_remind_input_mode and !app_state.g_search_rename_input_mode) updateSearchResults();
                _ = InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        WM_APP_SEARCH_SELECT_ALL => {
            if (app_state.g_search_active and app_state.g_search_rename_input_mode and app_state.g_search_len > 0) {
                app_state.g_search_rename_select_all = true;
                _ = InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        WM_APP_SEARCH_BACKSPACE => {
            app_state.g_search_snippet_delete_confirm = null;
            if (app_state.g_search_rename_input_mode) {
                if (wp == 2 or app_state.g_search_rename_select_all) {
                    app_state.g_search_len = 0;
                    app_state.g_search_rename_select_all = false;
                } else if (wp == 0 and app_state.g_search_len > 0) {
                    app_state.g_search_len -= 1;
                }
                _ = InvalidateRect(hwnd, null, 0);
            } else if (app_state.g_browser_url_mode) {
                if (wp == 0 and app_state.g_search_len > 0) {
                    app_state.g_search_len -= 1;
                    _ = InvalidateRect(hwnd, null, 0);
                } else {
                    app_state.g_browser_url_mode = false;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 0;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                }
            } else if (app_state.g_search_remind_input_mode) {
                if (wp == 0 and app_state.g_search_len > 0) {
                    app_state.g_search_len -= 1;
                    _ = InvalidateRect(hwnd, null, 0);
                } else {
                    app_state.g_search_remind_input_mode = false;
                    app_state.g_remind_ws_id_len = 0;
                    app_state.g_remind_sid = 0;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 0;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                }
            } else if (app_state.g_search_len > 0) {
                app_state.g_search_len -= 1;
                app_state.g_search_scroll = 0;
                app_state.g_search_workspace_delete_confirm = null;
                app_state.g_search_snippet_delete_confirm = null;
                updateSearchResults();
                _ = InvalidateRect(hwnd, null, 0);
            } else if (app_state.g_search_skills_mode) {
                app_state.g_search_skills_mode = false;
                app_state.g_search_sel = 0;
                app_state.g_search_scroll = 0;
                updateSearchResults();
                _ = InvalidateRect(hwnd, null, 0);
            } else if (app_state.g_search_openall_host_mode) {
                app_state.g_search_openall_host_mode = false;
                app_state.g_search_sel = 0;
                app_state.g_search_scroll = 0;
                updateSearchResults();
                _ = InvalidateRect(hwnd, null, 0);
            } else if (app_state.g_search_theme_mode) {
                app_state.g_search_theme_mode = false;
                app_state.g_search_sel = 0;
                app_state.g_search_scroll = 0;
                updateSearchResults();
                _ = InvalidateRect(hwnd, null, 0);
            } else if (app_state.g_search_ws_sort_mode) {
                app_state.g_search_ws_sort_mode = false;
                app_state.g_search_sel = 0;
                app_state.g_search_scroll = 0;
                updateSearchResults();
                _ = InvalidateRect(hwnd, null, 0);
            } else if (app_state.g_search_ws_move_mode) {
                app_state.g_search_ws_move_mode = false;
                app_state.g_wsmove_tab_sid = 0;
                app_state.g_search_sel = 0;
                app_state.g_search_scroll = 0;
                updateSearchResults();
                _ = InvalidateRect(hwnd, null, 0);
            } else if (app_state.g_search_group_move_mode) {
                app_state.g_search_group_move_mode = false;
                app_state.g_groupmove_tab_sid = 0;
                app_state.g_search_sel = 0;
                app_state.g_search_scroll = 0;
                updateSearchResults();
                _ = InvalidateRect(hwnd, null, 0);
            } else if (app_state.g_search_tabctx_mode) {
                app_state.g_search_tabctx_mode = false;
                app_state.g_tabctx_sid = 0;
                app_state.g_search_sel = 0;
                app_state.g_search_scroll = 0;
                updateSearchResults();
                _ = InvalidateRect(hwnd, null, 0);
            } else if (app_state.g_search_remind_preset_mode) {
                app_state.g_search_remind_preset_mode = false;
                app_state.g_remind_ws_id_len = 0;
                app_state.g_remind_sid = 0;
                app_state.g_remind_target_sid = 0;
                app_state.g_search_sel = 0;
                app_state.g_search_scroll = 0;
                updateSearchResults();
                _ = InvalidateRect(hwnd, null, 0);
            } else if (app_state.g_search_ws_snoozed_mode) {
                app_state.g_search_ws_snoozed_mode = false;
                app_state.g_search_sel = 0;
                app_state.g_search_scroll = 0;
                updateSearchResults();
                _ = InvalidateRect(hwnd, null, 0);
            } else if (app_state.g_search_reminders_mode) {
                app_state.g_search_reminders_mode = false;
                app_state.g_search_sel = 0;
                app_state.g_search_scroll = 0;
                updateSearchResults();
                _ = InvalidateRect(hwnd, null, 0);
            } else if (app_state.g_search_session_overview_mode) {
                app_state.g_search_session_overview_mode = false;
                app_state.g_search_sel = 0;
                app_state.g_search_scroll = 0;
                updateSearchResults();
                _ = InvalidateRect(hwnd, null, 0);
            } else if (app_state.g_search_workspace_delete_mode) {
                app_state.g_search_workspace_delete_mode = false;
                app_state.g_search_workspace_delete_confirm = null;
                app_state.g_search_snippet_delete_confirm = null;
                app_state.g_search_sel = 0;
                app_state.g_search_scroll = 0;
                updateSearchResults();
                _ = InvalidateRect(hwnd, null, 0);
            } else if (app_state.g_search_workspace_mode) {
                app_state.g_search_workspace_mode = false;
                app_state.g_search_workspace_delete_confirm = null;
                app_state.g_search_sel = 0;
                app_state.g_search_scroll = 0;
                updateSearchResults();
                _ = InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        WM_APP_SEARCH_MOVE => {
            if (app_state.g_search_result_count > 0) {
                switch (wp) {
                    0 => {
                        app_state.g_search_sel = if (app_state.g_search_sel == 0) app_state.g_search_result_count - 1 else app_state.g_search_sel - 1;
                    },
                    1 => {
                        app_state.g_search_sel = if (app_state.g_search_sel >= app_state.g_search_result_count - 1) 0 else app_state.g_search_sel + 1;
                    },
                    2 => {
                        app_state.g_search_sel = if (app_state.g_search_sel > SEARCH_VISIBLE_ROWS) app_state.g_search_sel - SEARCH_VISIBLE_ROWS else 0;
                    },
                    3 => {
                        const next_sel = app_state.g_search_sel + SEARCH_VISIBLE_ROWS;
                        app_state.g_search_sel = if (next_sel >= app_state.g_search_result_count) app_state.g_search_result_count - 1 else next_sel;
                    },
                    6 => {
                        app_state.g_search_sel = if (app_state.g_search_sel > SEARCH_WHEEL_ROWS) app_state.g_search_sel - SEARCH_WHEEL_ROWS else 0;
                    },
                    7 => {
                        const next_sel = app_state.g_search_sel + SEARCH_WHEEL_ROWS;
                        app_state.g_search_sel = if (next_sel >= app_state.g_search_result_count) app_state.g_search_result_count - 1 else next_sel;
                    },
                    4 => {
                        app_state.g_search_sel = 0;
                    },
                    5 => {
                        app_state.g_search_sel = app_state.g_search_result_count - 1;
                    },
                    else => {},
                }
                app_state.g_search_workspace_delete_confirm = null;
                app_state.g_search_snippet_delete_confirm = null;
                keepSearchSelectionVisible();
                _ = InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        WM_APP_WSSORT_MOVE => {
            if (app_state.g_search_active and app_state.g_search_ws_sort_mode and app_state.g_search_result_count > 0) {
                const target = app_state.g_search_results[app_state.g_search_sel];
                if (target >= SEARCH_WSSORT_OFFSET and target < SEARCH_WSSORT_OFFSET + MAX_LWS) {
                    const slot: u8 = @intCast(target - SEARCH_WSSORT_OFFSET);
                    if (wp == 0 and slot > 0) {
                        swapWorkspaceSlots(slot, slot - 1);
                        app_state.g_search_sel -= 1;
                        persistWorkspaceOrder();
                    } else if (wp == 1 and slot + 1 < app_state.g_lws_count) {
                        swapWorkspaceSlots(slot, slot + 1);
                        app_state.g_search_sel += 1;
                        persistWorkspaceOrder();
                    }
                    keepSearchSelectionVisible();
                    _ = InvalidateRect(hwnd, null, 0);
                }
            }
            return 0;
        },
        WM_APP_SYSMENU => {
            if (!focusGuard(hwnd)) return 0;
            app_state.g_sysmenu_retry_count = 0;
            _ = AllowSetForegroundWindow(GetCurrentProcessId());
            keybd_event(VK_MENU, 0, 0, 0);
            const sfw_ret = SetForegroundWindow(hwnd);
            _ = SetFocus(hwnd);
            keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);
            app_state.g_shell_focused = false;
            const fg_ours_now = GetForegroundWindow() == hwnd;
            if (verboseLoggingEnabled()) {
                var lbuf: [128]u8 = undefined;
                var lpos: usize = 0;
                const pre = "sysmenu: sfw=";
                @memcpy(lbuf[0..pre.len], pre);
                lpos = pre.len;
                lbuf[lpos] = if (sfw_ret != 0) '1' else '0';
                lpos += 1;
                const s2 = " fg_ours_now=";
                @memcpy(lbuf[lpos .. lpos + s2.len], s2);
                lpos += s2.len;
                lbuf[lpos] = if (fg_ours_now) '1' else '0';
                lpos += 1;
                const s3 = " retry=0";
                @memcpy(lbuf[lpos .. lpos + s3.len], s3);
                lpos += s3.len;
                debugLog(lbuf[0..lpos]);
            }
            if (fg_ours_now) {
                const sysmenu = GetSystemMenu(hwnd, 0);
                if (sysmenu != null) {
                    var wr: RECT = std.mem.zeroes(RECT);
                    _ = GetWindowRect(hwnd, &wr);
                    const cmd = TrackPopupMenu(sysmenu, TPM_RETURNCMD | TPM_LEFTALIGN, wr.left + 8, wr.top + 32, 0, hwnd, null);
                    if (verboseLoggingEnabled()) {
                        var cbuf: [64]u8 = undefined;
                        var cpos: usize = 0;
                        const cp = "sysmenu: trackpopup cmd=";
                        @memcpy(cbuf[0..cp.len], cp);
                        cpos = cp.len;
                        appendDecimal(&cbuf, &cpos, @intCast(@as(u32, @bitCast(cmd))));
                        debugLog(cbuf[0..cpos]);
                    }
                    if (cmd != 0) {
                        _ = PostMessageW(hwnd, WM_SYSCOMMAND, @intCast(@as(u32, @bitCast(cmd))), 0);
                    } else if (app_state.shell_count > 0) {
                        _ = SetTimer(hwnd, TIMER_REFOCUS, 100, null);
                    }
                }
            } else {
                _ = SetTimer(hwnd, TIMER_SYSMENU, 30, null);
            }
            return 0;
        },
        WM_APP_WIN_SNAP => {
            var mi: MONITORINFO = std.mem.zeroes(MONITORINFO);
            mi.cbSize = @sizeOf(MONITORINFO);
            const mon = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
            if (mon == null or GetMonitorInfoW(mon, &mi) == 0) return 0;
            const wa = mi.rcWork;
            const current_slot = MonitorSlot{ .mon = mon, .bounds = mi.rcMonitor, .work = wa };
            switch (wp) {
                0, 1 => {
                    const to_left = wp == 0;
                    var target_slot = current_slot;
                    var snap_left = to_left;
                    if (IsZoomed(hwnd) == 0) {
                        var wr: RECT = std.mem.zeroes(RECT);
                        _ = GetWindowRect(hwnd, &wr);
                        const cur_half_w = @divFloor(wa.right - wa.left, 2);
                        const half_x: i32 = if (to_left) wa.left else wa.left + cur_half_w;
                        if (rectNear(wr, half_x, wa.top, cur_half_w, wa.bottom - wa.top)) {
                            const direction: MonitorDirection = if (to_left) .left else .right;
                            target_slot = monitorSlotInDirection(mon, direction) orelse return 0;
                            snap_left = !to_left;
                        }
                    } else {
                        _ = ShowWindow(hwnd, SW_RESTORE);
                    }
                    const target = target_slot.work;
                    const tw = target.right - target.left;
                    const thw = @divFloor(tw, 2);
                    const x: i32 = if (snap_left) target.left else target.left + thw;
                    const w: i32 = if (snap_left) thw else tw - thw;
                    const expected = RECT{ .left = x, .top = target.top, .right = x + w, .bottom = target.bottom };
                    beginMonitorTransition(hwnd, target_slot, expected, true, .shortcut);
                    _ = SetWindowPos(hwnd, null, x, target.top, w, target.bottom - target.top, SWP_NOZORDER);
                },
                2 => _ = ShowWindow(hwnd, SW_MAXIMIZE),
                3 => {
                    if (IsZoomed(hwnd) != 0) {
                        _ = ShowWindow(hwnd, SW_RESTORE);
                    } else {
                        _ = ShowWindow(hwnd, SW_MINIMIZE);
                    }
                },
                4, 5 => {
                    const direction: MonitorDirection = if (wp == 4) .left else .right;
                    const target_slot = monitorSlotInDirection(mon, direction) orelse return 0;
                    const was_zoomed = IsZoomed(hwnd) != 0;
                    if (was_zoomed) _ = ShowWindow(hwnd, SW_RESTORE);
                    var wr: RECT = std.mem.zeroes(RECT);
                    if (GetWindowRect(hwnd, &wr) == 0) return 0;
                    const mapped = mapWindowRectToWorkArea(wr, wa, target_slot.work);
                    beginMonitorTransition(hwnd, target_slot, mapped, !was_zoomed, .shortcut);
                    _ = SetWindowPos(
                        hwnd,
                        null,
                        mapped.left,
                        mapped.top,
                        mapped.right - mapped.left,
                        mapped.bottom - mapped.top,
                        SWP_NOZORDER,
                    );
                    if (was_zoomed) _ = ShowWindow(hwnd, SW_MAXIMIZE);
                },
                else => {},
            }
            return 0;
        },
        WM_APP_SEARCH_CONFIRM => {
            if (app_state.g_search_active and app_state.g_browser_url_mode) {
                _ = PostMessageW(hwnd, WM_APP_BROWSER_OPEN_URL, 0, 0);
                return 0;
            }
            if (app_state.g_search_active and app_state.g_search_rename_input_mode) {
                const idx = findShellById(app_state.g_search_rename_sid) orelse {
                    showHeaderNoticeAscii("Rename target is gone", 3000, true);
                    return 0;
                };
                var start: usize = 0;
                var end: usize = @intCast(app_state.g_search_len);
                while (start < end and (app_state.g_search_buf[start] == ' ' or app_state.g_search_buf[start] == '\t')) start += 1;
                while (end > start and (app_state.g_search_buf[end - 1] == ' ' or app_state.g_search_buf[end - 1] == '\t')) end -= 1;
                if (end == start) {
                    showHeaderNoticeAscii("Enter a session name", 3000, true);
                    return 0;
                }
                _ = applyCanonicalSessionRename(idx, app_state.g_search_buf[start..end], true);
                saveSession();
                publishInboxState();
                updateMainWindowTitle();
                _ = SendMessageW(hwnd, WM_APP_SEARCH_CLOSE, 0, 0);
                return 0;
            }
            if (app_state.g_search_active and app_state.g_search_remind_input_mode) {
                const due = parseReminderDue(app_state.g_search_buf[0..app_state.g_search_len]) orelse {
                    showHeaderNoticeAscii("Could not parse reminder time", 4000, true);
                    return 0;
                };
                if (app_state.g_remind_ws_id_len > 0) {
                    const ws = findMyWorkspaceSlot(app_state.g_remind_ws_id[0..app_state.g_remind_ws_id_len]) orelse {
                        showHeaderNoticeAscii("Workspace no longer open", 3000, true);
                        return 0;
                    };
                    _ = snoozeWorkspaceUntil(hwnd, ws, due);
                    return 0;
                }
                const idx = findShellById(app_state.g_remind_sid) orelse {
                    showHeaderNoticeAscii("Reminder tab is gone", 3000, true);
                    return 0;
                };
                _ = snoozeShellUntil(hwnd, idx, due);
                return 0;
            }
            if (app_state.g_search_active and app_state.g_search_result_count > 0) {
                const target = app_state.g_search_results[app_state.g_search_sel];
                recordPaletteUsage(target);
                if (verboseLoggingEnabled()) {
                    var dbg_cf: [96]u8 = undefined;
                    debugLog(std.fmt.bufPrint(&dbg_cf, "[confirm] sel={d} count={d} target={d} (tabsort_auto={d} manual={d})", .{ app_state.g_search_sel, app_state.g_search_result_count, target, SEARCH_TABSORT_INBOX_OFFSET, SEARCH_TABSORT_MANUAL_OFFSET }) catch "[confirm fmt-err]");
                }
                if (target == SEARCH_LAYOUT_PULL_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    pullSessionLayout();
                    return 0;
                }
                if (target == SEARCH_SYNC_SIGNOUT_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    accountSignOut();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_APPROVE_DEVICES_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    startAccountJob(.{ .kind = .device_keys });
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_SYNC_STATUS_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    startAccountJob(.{ .kind = .devices });
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHAT_REPLY_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_search_from_inbox = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    @import("chat_render.zig").chatReplyLatestAgent();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHAT_TODO_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_search_from_inbox = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    @import("chat_render.zig").chatToggleTodos();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHAT_FIND_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_search_from_inbox = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    @import("chat_find_ui.zig").open();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHAT_TOOL_STEPS_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_search_from_inbox = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    @import("chat_render.zig").chatToggleAllTools();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHAT_COPY_CODE_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_search_from_inbox = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    chatCopyLatestCode();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHAT_ATTACH_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_search_from_inbox = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(hwnd, WM_APP_CHAT_ATTACH, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHAT_COPY_SELECTION_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_search_from_inbox = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    chatCopySelection();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHAT_SELECT_ALL_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_search_from_inbox = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    chatSelectAll();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHAT_AC_OFFSET) {
                    const was_inbox = app_state.g_search_from_inbox;
                    app_state.g_search_active = false;
                    app_state.g_search_from_inbox = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    if (was_inbox and app_state.g_inbox_active) closeInbox(hwnd) else showActiveShellAfterOverlay();
                    chatAcOpenBrowse();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_SKILLS_MENU_OFFSET) {
                    if (!loadPaletteSkills()) {
                        showHeaderNoticeAscii("Could not load skills", 3500, true);
                        return 0;
                    }
                    app_state.g_search_skills_mode = true;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 1;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_SKILLS_BACK_OFFSET) {
                    app_state.g_search_skills_mode = false;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 0;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target >= SEARCH_SKILL_ROW_OFFSET and target < SEARCH_SKILL_ROW_OFFSET + MAX_PALETTE_SKILLS) {
                    const skill_idx = target - SEARCH_SKILL_ROW_OFFSET;
                    if (skill_idx >= app_state.g_palette_skills.len) return 0;
                    const was_from_inbox = app_state.g_search_from_inbox;
                    app_state.g_search_active = false;
                    app_state.g_search_skills_mode = false;
                    app_state.g_search_from_inbox = false;
                    app_state.g_search_spawn_ws = 0xFF;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    if (was_from_inbox and app_state.g_inbox_active) closeInbox(hwnd) else showActiveShellAfterOverlay();
                    if (!app_state.g_chat_active) toggleChatView();
                    selectChatSkill(app_state.g_palette_skills[skill_idx]);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_SESSION_OVERVIEW_MENU_OFFSET) {
                    openAllSessions(hwnd);
                    return 0;
                }
                if (target >= SEARCH_SESSION_OVERVIEW_ROW_OFFSET and target < SEARCH_SESSION_OVERVIEW_ROW_OFFSET + MAX_SESSION_OVERVIEW_SEARCH_ROWS) {
                    const row_idx = target - SEARCH_SESSION_OVERVIEW_ROW_OFFSET;
                    _ = activateSessionOverviewRow(@intCast(row_idx), hwnd);
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 120, null);
                    return 0;
                }
                if (target == SEARCH_ARCHIVED_VIEW_OFFSET) {
                    app_state.g_search_spawn_ws = 0xFF;
                    app_state.g_all_sessions_unattached_only = false;
                    app_state.g_all_sessions_tab = AS_TAB_ARCHIVED;
                    openAllSessions(hwnd);
                    return 0;
                }
                if (target == SEARCH_SNIPPETS_MENU_OFFSET) {
                    app_state.g_search_snippet_mode = true;
                    app_state.g_search_snippet_delete_confirm = null;
                    app_state.g_search_workspace_mode = false;
                    app_state.g_search_workspace_delete_mode = false;
                    app_state.g_search_workspace_delete_confirm = null;
                    app_state.g_search_theme_mode = false;
                    app_state.g_search_session_overview_mode = false;
                    app_state.g_search_ws_sort_mode = false;
                    app_state.g_search_ws_move_mode = false;
                    app_state.g_wsmove_tab_sid = 0;
                    app_state.g_search_tabctx_mode = false;
                    app_state.g_tabctx_sid = 0;
                    app_state.g_browser_url_mode = false;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 0;
                    app_state.g_search_scroll = 0;
                    loadSnippetsIfChanged();
                    updateSearchResults();
                    if (app_state.g_search_result_count > 1) {
                        app_state.g_search_sel = 1;
                        keepSearchSelectionVisible();
                    }
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_SNIPPET_BACK_OFFSET) {
                    app_state.g_search_snippet_mode = false;
                    app_state.g_search_snippet_delete_confirm = null;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 0;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_SNIPPET_CREATE_OFFSET) {
                    openSnippetCreateForm(hwnd);
                    return 0;
                }
                if (target >= SEARCH_SNIPPET_OFFSET and target < SEARCH_SNIPPET_OFFSET + MAX_SNIPPETS) {
                    const sn_idx = target - SEARCH_SNIPPET_OFFSET;
                    app_state.g_search_active = false;
                    app_state.g_search_snippet_mode = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    app_state.g_pending_new_tab_group = 0;
                    if (app_state.g_search_from_inbox) {
                        app_state.g_search_from_inbox = false;
                        app_state.g_search_spawn_ws = 0xFF;
                        if (app_state.g_inbox_active) closeInbox(hwnd);
                    } else {
                        showActiveShellAfterOverlay();
                    }
                    pasteSnippet(sn_idx);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target >= SEARCH_ADDFAVICON_OFFSET) {
                    if (!app_state.g_favicon_fetching and app_state.active_shell < app_state.shell_count) {
                        startFaviconFetch(app_state.active_shell);
                    }
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target >= SEARCH_MOBILE_OFFSET) {
                    app_state.g_mobile_mode = !app_state.g_mobile_mode;
                    _ = InvalidateRect(hwnd, null, 0);
                    saveSession();
                    return 0;
                }
                if (target == SEARCH_WORKSPACE_BACK_OFFSET) {
                    app_state.g_search_workspace_mode = false;
                    app_state.g_search_workspace_delete_mode = false;
                    app_state.g_search_ws_sort_mode = false;
                    app_state.g_search_ws_move_mode = false;
                    app_state.g_wsmove_tab_sid = 0;
                    app_state.g_search_tabctx_mode = false;
                    app_state.g_tabctx_sid = 0;
                    app_state.g_search_reminders_mode = false;
                    app_state.g_search_session_overview_mode = false;
                    app_state.g_search_workspace_delete_confirm = null;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 0;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_WS_SNOOZE_OFFSET) {
                    _ = SendMessageW(hwnd, WM_APP_WS_SNOOZE_OPEN, 0, 0);
                    return 0;
                }
                if (target == SEARCH_WS_BRINGBACK_OFFSET) {
                    applySearchSpawnContext(hwnd);
                    _ = SendMessageW(hwnd, WM_APP_SEARCH_CLOSE, 0, 0);
                    bringBackAllSessions();
                    return 0;
                }
                if (target == SEARCH_WS_SNOOZED_OFFSET) {
                    app_state.g_search_ws_snoozed_mode = true;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 0;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target >= SEARCH_WS_SNOOZED_ROW_OFFSET and target < SEARCH_WS_SNOOZED_ROW_OFFSET + MAX_REMINDERS) {
                    if (wakeWorkspaceByIndex(@intCast(target - SEARCH_WS_SNOOZED_ROW_OFFSET), true)) {
                        _ = SendMessageW(hwnd, WM_APP_SEARCH_CLOSE, 0, 0);
                    }
                    return 0;
                }
                if (target == SEARCH_REMIND_ME_OFFSET) {
                    if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].tmux_session_len > 0) {
                        app_state.g_remind_ws_id_len = 0;
                        app_state.g_remind_target_sid = 0;
                        app_state.g_remind_sid = app_state.shells[app_state.active_shell].shell_id;
                        app_state.g_search_remind_preset_mode = true;
                        app_state.g_search_len = 0;
                        app_state.g_search_sel = 0;
                        app_state.g_search_scroll = 0;
                        updateSearchResults();
                        _ = InvalidateRect(hwnd, null, 0);
                    }
                    return 0;
                }
                if (target >= SEARCH_REMIND_PRESET_OFFSET and target < SEARCH_REMIND_PRESET_OFFSET + REMIND_PRESET_COUNT) {
                    const preset_i = target - SEARCH_REMIND_PRESET_OFFSET;
                    if (preset_i == REMIND_PRESET_CUSTOM) {
                        app_state.g_search_remind_preset_mode = false;
                        app_state.g_search_remind_input_mode = true;
                        app_state.g_search_len = 0;
                        app_state.g_search_sel = 0;
                        app_state.g_search_scroll = 0;
                        updateSearchResults();
                        _ = InvalidateRect(hwnd, null, 0);
                        return 0;
                    }
                    const due = remindPresetDue(preset_i) orelse {
                        showHeaderNoticeAscii("Could not compute reminder time", 4000, true);
                        return 0;
                    };
                    if (app_state.g_remind_ws_id_len > 0) {
                        const ws = findMyWorkspaceSlot(app_state.g_remind_ws_id[0..app_state.g_remind_ws_id_len]) orelse {
                            showHeaderNoticeAscii("Workspace no longer open", 3000, true);
                            return 0;
                        };
                        _ = snoozeWorkspaceUntil(hwnd, ws, due);
                        return 0;
                    }
                    const target_idx: ?u32 = if (app_state.g_remind_target_sid != 0)
                        findShellById(app_state.g_remind_target_sid)
                    else if (app_state.active_shell < app_state.shell_count)
                        app_state.active_shell
                    else
                        null;
                    const ridx = target_idx orelse {
                        showHeaderNoticeAscii("Session no longer open", 3000, true);
                        return 0;
                    };
                    _ = snoozeShellUntil(hwnd, ridx, due);
                    return 0;
                }
                if (target == SEARCH_REMINDERS_MENU_OFFSET) {
                    loadRemindersIfNeeded();
                    app_state.g_search_reminders_mode = true;
                    app_state.g_search_workspace_mode = false;
                    app_state.g_search_workspace_delete_mode = false;
                    app_state.g_search_ws_sort_mode = false;
                    app_state.g_search_ws_move_mode = false;
                    app_state.g_search_theme_mode = false;
                    app_state.g_search_tabctx_mode = false;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 0;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_WORKSPACES_MENU_OFFSET) {
                    reconcileWorkspaceRegistry(true);
                    app_state.g_search_workspace_mode = true;
                    app_state.g_search_workspace_delete_mode = false;
                    app_state.g_search_workspace_delete_confirm = null;
                    app_state.g_search_theme_mode = false;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 0;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_WORKSPACE_DELETE_MENU_OFFSET) {
                    reconcileWorkspaceRegistry(true);
                    app_state.g_search_workspace_mode = true;
                    app_state.g_search_workspace_delete_mode = true;
                    app_state.g_search_workspace_delete_confirm = null;
                    app_state.g_search_theme_mode = false;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 0;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_QUIT_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    quitAllZigShellWindows(hwnd);
                    return 0;
                }
                if (target == SEARCH_UPDATE_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    if (app_state.g_update_ver_len > 0) {
                        updateCardRelaunch(hwnd);
                    } else {
                        updateCardPoll();
                    }
                    return 0;
                }
                if (target == SEARCH_RESTART_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_RESTART, 0, 0);
                    return 0;
                }
                if (target == SEARCH_FULLWIDTH_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_TOGGLE_FULLWIDTH, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_HIDESIDEBAR_OFFSET) {
                    app_state.g_hide_sidebar = false;
                    app_state.g_sidebar_collapsed = false;
                    saveSession();
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    repositionActive();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_SIDEBAR_COLLAPSE_OFFSET) {
                    app_state.g_hide_sidebar = false;
                    app_state.g_sidebar_collapsed = true;
                    saveSession();
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    repositionActive();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_SIDEBAR_HIDE_OFFSET) {
                    app_state.g_hide_sidebar = true;
                    saveSession();
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    repositionActive();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_UNREADONLY_OFFSET) {
                    app_state.g_unread_only = !app_state.g_unread_only;
                    if (app_state.g_inbox_active and !inboxSplitVisible(app_state.g_inbox_tab)) app_state.g_inbox_tab = @import("inbox.zig").firstInboxSplit();
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    repositionActive();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_ETA_NUMBERS_OFFSET or target == SEARCH_ETA_PROGRESS_OFFSET) {
                    if (target == SEARCH_ETA_NUMBERS_OFFSET) {
                        app_state.g_eta_numbers_on = !app_state.g_eta_numbers_on;
                    } else {
                        app_state.g_eta_progress_on = !app_state.g_eta_progress_on;
                    }
                    saveSession();
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    repositionActive();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_ETA_ACCURACY_OFFSET) {
                    app_state.g_search_active = false;
                    if (app_state.g_search_from_inbox) {
                        app_state.g_search_from_inbox = false;
                        app_state.g_search_spawn_ws = 0xFF;
                        if (app_state.g_inbox_active) closeInbox(hwnd);
                    }
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SHORTCUTS_OPEN, 1, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHAT_VIEW_MODE_PER_SESSION_OFFSET or target == SEARCH_CHAT_VIEW_MODE_EVERYWHERE_OFFSET or target == SEARCH_CHAT_VIEW_MODE_NOWHERE_OFFSET) {
                    app_state.g_chat_view_mode = if (target == SEARCH_CHAT_VIEW_MODE_PER_SESSION_OFFSET) .per_session else if (target == SEARCH_CHAT_VIEW_MODE_EVERYWHERE_OFFSET) .everywhere else .nowhere;
                    if (app_state.g_chat_view_mode == .per_session and app_state.active_shell < app_state.shell_count) {
                        app_state.shells[app_state.active_shell].chat_view_on = app_state.g_chat_active;
                    }
                    if (app_state.g_chat_view_mode == .nowhere and app_state.g_chat_active) closeChatView();
                    saveSession();
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    repositionActive();
                    if (app_state.g_chat_view_mode == .everywhere and app_state.active_shell < app_state.shell_count) {
                        const want_chat = chatViewShouldShowForTab(app_state.g_chat_view_mode, app_state.shells[app_state.active_shell].chat_view_on, app_state.shells[app_state.active_shell].chat_shell_override, app_state.g_chat_active, false);
                        if (want_chat != app_state.g_chat_active) {
                            if (want_chat) openChatView() else closeChatView();
                        }
                    }
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_THREADTITLE_OFFSET and IS_DEV) {
                    app_state.g_thread_title = !app_state.g_thread_title;
                    saveSession();
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    repositionActive();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_FONT_BIGGER_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(hwnd, WM_APP_FONT_BIGGER, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_FONT_SMALLER_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(hwnd, WM_APP_FONT_SMALLER, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_FONT_RESET_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(hwnd, WM_APP_FONT_RESET, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_CUSTOMCMD_EDIT_OFFSET) {
                    openCommandsJsonInEditor();
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_UI_BIGGER_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(hwnd, WM_APP_UI_BIGGER, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_CUSTOMCMD_RELOAD_OFFSET) {
                    app_state.g_custom_cmds_mtime_lo = 0;
                    app_state.g_custom_cmds_mtime_hi = 0;
                    loadCustomCommandsIfChanged();
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_UNARCHIVE_HIDDEN_OFFSET) {
                    const target_ws: u8 = if (app_state.g_search_spawn_ws != 0xFF and app_state.g_search_spawn_ws < app_state.g_lws_count and !app_state.g_ws_snoozed[app_state.g_search_spawn_ws]) app_state.g_search_spawn_ws else app_state.g_active_workspace;
                    const was_from_inbox = app_state.g_search_from_inbox;
                    app_state.g_search_active = false;
                    app_state.g_search_from_inbox = false;
                    app_state.g_search_spawn_ws = 0xFF;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();

                    const restored = unarchiveHiddenWorkspaceSessions(target_ws);
                    if (was_from_inbox and app_state.g_inbox_active) {
                        loadInboxModel();
                        if (!inboxSplitVisible(app_state.g_inbox_tab)) app_state.g_inbox_tab = @import("inbox.zig").firstInboxSplit();
                    } else {
                        showActiveShellAfterOverlay();
                        _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    }

                    var notice_buf: [80]u8 = undefined;
                    const notice = if (restored == 0)
                        "No waiting sessions in workspace"
                    else
                        std.fmt.bufPrint(&notice_buf, "Restored {d} waiting session{s}", .{ restored, if (restored == 1) "" else "s" }) catch "Waiting sessions restored";
                    showHeaderNoticeAscii(notice, 2800, false);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_UNARCHIVE_UNATTACHED_OFFSET) {
                    const target_ws: u8 = if (app_state.g_search_spawn_ws != 0xFF and app_state.g_search_spawn_ws < app_state.g_lws_count and !app_state.g_ws_snoozed[app_state.g_search_spawn_ws]) app_state.g_search_spawn_ws else app_state.g_active_workspace;
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    applySearchSpawnContext(hwnd);
                    showActiveShellAfterOverlay();

                    const queued = startUnarchiveUnattachedWorkspaceSessions(hwnd, target_ws);
                    var notice_buf: [96]u8 = undefined;
                    const notice = if (queued == 0)
                        "No unattached sessions in workspace"
                    else
                        std.fmt.bufPrint(&notice_buf, "Attaching {d} session{s} sequentially...", .{ queued, if (queued == 1) "" else "s" }) catch "Attaching unattached sessions...";
                    showHeaderNoticeAscii(notice, if (queued == 0) 3000 else 5000, false);
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_ARCHIVE_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    archiveActiveTab();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_END_TMUX_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    endActiveTmuxSession();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_REOPEN_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(hwnd, WM_APP_REOPEN_CLOSED, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_URLPICK_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    if (app_state.g_search_from_inbox) {
                        app_state.g_search_from_inbox = false;
                        app_state.g_search_spawn_ws = 0xFF;
                        if (app_state.g_inbox_active) closeInbox(hwnd);
                    } else {
                        showActiveShellAfterOverlay();
                    }
                    _ = PostMessageW(hwnd, WM_APP_URL_PICKER_OPEN, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CLOSETAB_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(hwnd, WM_APP_CLOSE, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_MUTETAB_OFFSET) {
                    if (app_state.active_shell < app_state.shell_count) {
                        app_state.shells[app_state.active_shell].muted = !app_state.shells[app_state.active_shell].muted;
                        if (app_state.shells[app_state.active_shell].muted) {
                            app_state.shells[app_state.active_shell].activity = .idle;
                            app_state.shells[app_state.active_shell].needs_attention = false;
                        }
                        invalidateSidebar();
                        publishInboxState();
                        if (!app_state.g_restoring) saveSession();
                    }
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_FAVORITE_OFFSET) {
                    toggleFavorite(app_state.active_shell);
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_INBOX_EXCLUDE_OFFSET) {
                    toggleInboxExcluded(app_state.active_shell);
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_PIN_TOP_OFFSET) {
                    if (app_state.active_shell < app_state.shell_count) {
                        app_state.shells[app_state.active_shell].pinned_top = !app_state.shells[app_state.active_shell].pinned_top;
                        invalidateSidebar();
                        if (!app_state.g_restoring) saveSession();
                    }
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_LOCK_SESSION_OFFSET) {
                    if (app_state.active_shell < app_state.shell_count) {
                        app_state.shells[app_state.active_shell].locked = !app_state.shells[app_state.active_shell].locked;
                        invalidateSidebar();
                        if (!app_state.g_restoring) saveSession();
                    }
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_USAGE_LOGIN_PRIMARY_OFFSET or target == SEARCH_USAGE_LOGIN_INNE_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    const account: UsageLoginAccount = if (target == SEARCH_USAGE_LOGIN_PRIMARY_OFFSET) .primary else .secondary;
                    if (!showUsageAccountLogin(account)) {
                        showHeaderNoticeAscii("AI usage account login is not installed", 4000, true);
                    }
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_MULTIPROMPT_LOGIN_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    accountSignIn();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_KEEPALIVE_OFFSET) {
                    if (app_state.active_shell < app_state.shell_count) {
                        app_state.shells[app_state.active_shell].keep_alive = !app_state.shells[app_state.active_shell].keep_alive;
                        invalidateSidebar();
                        if (!app_state.g_restoring) saveSession();
                    }
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_CHAT_VIEW_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(hwnd, WM_APP_CHAT_TOGGLE, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHAT_ALLOW_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    _ = @import("chat_send.zig").chatPermissionAnswer(app_state.active_shell, .allow);
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHAT_ALWAYS_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    _ = @import("chat_send.zig").chatPermissionAnswer(app_state.active_shell, .always);
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHAT_DENY_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    _ = @import("chat_send.zig").chatPermissionAnswer(app_state.active_shell, .deny);
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHAT_STOP_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    if (app_state.ISSUE_265_WORKING_BAR) _ = @import("chat_send.zig").chatStopAgent(app_state.active_shell) else _ = PostMessageW(hwnd, WM_APP_CHAT_INTERRUPT, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHAT_QUEUE_SEND_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    chatOutboxFlushActiveNow();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHAT_RESET_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    chatResetForShell(app_state.active_shell);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHAT_QUEUE_CLEAR_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    chatOutboxClearActive();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHAT_RETRY_UNSENT_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    chatEchoRetryAllForActive();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHAT_PUSH_QUEUED_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    chatEchoPushQueuedNow();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHAT_DISCARD_UNSENT_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    chatEchoDiscardUnsentForActive();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_BROWSER_TOGGLE_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    if (app_state.active_shell < app_state.shell_count) {
                        const browser_hwnd_live = if (app_state.shells[app_state.active_shell].browser_hwnd) |bh|
                            IsWindow(bh) != 0 and windowOwnerProcessStillActive(bh)
                        else
                            false;
                        if (!browser_hwnd_live) {
                            closeBrowserForShell(app_state.active_shell);
                            app_state.shells[app_state.active_shell].browser_enabled = true;
                        }
                        openBrowserPaneForShell(app_state.active_shell, "");
                    }
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_BROWSER_MODE_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(hwnd, WM_APP_BROWSER_MODE_TOGGLE, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_BROWSER_ENGINE_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(hwnd, WM_APP_BROWSER_ENGINE_TOGGLE, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_BROWSER_URL_OFFSET) {
                    app_state.g_browser_url_mode = true;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 0;
                    app_state.g_search_scroll = 0;
                    app_state.g_search_result_count = 0;
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_BROWSER_SHOTURL_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(hwnd, WM_APP_BROWSER_SHOTURL, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_BROWSER_BACK_OFFSET or target == SEARCH_BROWSER_FORWARD_OFFSET) {
                    app_state.g_search_active = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(hwnd, if (target == SEARCH_BROWSER_FORWARD_OFFSET) WM_APP_BROWSER_FORWARD else WM_APP_BROWSER_BACK, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_BROWSER_FOCUS_URL_OFFSET) {
                    app_state.g_search_active = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(hwnd, WM_APP_BROWSER_FOCUS_URL, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_BROWSER_FOCUS_TOGGLE_OFFSET) {
                    app_state.g_search_active = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(hwnd, WM_APP_BROWSER_FOCUS_TOGGLE, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_ZSB_REBIND_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    if (app_state.active_shell < app_state.shell_count) {
                        _ = forceRebindZsbForShell(app_state.active_shell);
                    }
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_SHELL_DIAG_OFFSET) {
                    copyActiveShellDiagnostics();
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_SYNC_NAME_OFFSET) {
                    _ = syncActiveShellNameFromLiveTitle();
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_RENAME_SYNC_OFFSET) {
                    if (app_state.active_shell < app_state.shell_count) {
                        _ = beginPaletteRenameInput(app_state.active_shell);
                    }
                    return 0;
                }
                if (target == SEARCH_BROWSER_AUTOSUSPEND_OFFSET) {
                    app_state.g_browser_autosuspend = !app_state.g_browser_autosuspend;
                    if (app_state.g_browser_autosuspend and app_state.g_browser_suspend_min == 0) app_state.g_browser_suspend_min = BROWSER_SUSPEND_DEFAULT_MIN;
                    saveSession();
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_KEEPAWAKE_OFFSET) {
                    toggleKeepAwakeForActiveShell();
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_CRASH_REPORTS_OFFSET or (IS_DEV and target == SEARCH_CRASH_NOW_OFFSET)) {
                    const crash_now = target == SEARCH_CRASH_NOW_OFFSET;
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    if (crash_now) crash_recorder.crashNow() else crash_recorder.openFolder();
                    return 0;
                }
                if (target == SEARCH_CLOSE_ALL_BROWSER_PANES_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_browser_focus_mode = false;
                    app_state.g_shell_focused = true;
                    app_state.g_browser_shortcut_open_guard_until = 0;
                    clearSearchBackdrop();
                    discardBrowserUrlBarEdit();
                    closeWebView2();
                    for (0..app_state.shell_count) |i| {
                        app_state.shells[i].browser_enabled = false;
                        closeBrowserForShell(@intCast(i));
                    }
                    showActiveShellAfterOverlay();
                    updateBrowserVisibility();
                    repositionActive();
                    syncMouseHookForUrlClicks();
                    invalidateSidebar();
                    saveSession();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_HIBERNATE_NOW_OFFSET) {
                    const hib_count = hibernateAllParkedBrowserPanesNow();
                    var hib_buf: [64]u8 = undefined;
                    const hib_msg = std.fmt.bufPrint(&hib_buf, "Hibernated {d} browser pane{s}", .{ hib_count, if (hib_count == 1) "" else "s" }) catch "Hibernated browser panes";
                    showHeaderNoticeAscii(hib_msg, 2500, false);
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_BROWSER_INSTRUCT_OFFSET) {
                    copyBrowserControlInstructions();
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    pasteClipboardToShell(app_state.active_shell);
                    return 0;
                }
                if (target == SEARCH_UI_SMALLER_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(hwnd, WM_APP_UI_SMALLER, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_UI_RESET_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(hwnd, WM_APP_UI_RESET, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_TABSORT_INBOX_OFFSET) {
                    app_state.g_tab_sort_auto = true;
                    if (verboseLoggingEnabled()) debugLog("[tabsort] AUTO enabled via Ctrl+K");
                    saveSession();
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    repositionActive();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_TABSORT_MANUAL_OFFSET) {
                    if (app_state.g_tab_sort_auto) {
                        materializeDisplayOrder();
                        app_state.g_tab_sort_auto = false;
                    }
                    saveSession();
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    repositionActive();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_POWER_AUTO_OFFSET or target == SEARCH_POWER_ALWAYS_OFFSET or target == SEARCH_POWER_OFF_OFFSET) {
                    app_state.g_power_profile = if (target == SEARCH_POWER_AUTO_OFFSET) .auto else if (target == SEARCH_POWER_ALWAYS_OFFSET) .always else .off;
                    savePowerProfile();
                    applyPowerProfile(hwnd);
                    var tbuf: [256]u16 = undefined;
                    _ = SetWindowTextW(hwnd, buildWindowTitle(&tbuf));
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    repositionActive();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target >= SEARCH_LADDER_AUTO_OFFSET and target <= SEARCH_LADDER_DASH_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    if (target == SEARCH_LADDER_DASH_OFFSET) {
                        if (app_state.g_ai_pace.from_ladder and app_state.g_ai_pace.ladder_dashboard_len > 0) {
                            navigateBrowserPaneWithActivation(app_state.active_shell, app_state.g_ai_pace.ladder_dashboard[0..app_state.g_ai_pace.ladder_dashboard_len], true);
                        } else {
                            showHeaderNoticeAscii("Token Ladder: no dashboard link yet", 3000, false);
                        }
                    } else {
                        startLadderMode(if (target == SEARCH_LADDER_CLAUDE_OFFSET) 1 else if (target == SEARCH_LADDER_CODEX_OFFSET) 2 else 0);
                    }
                    repositionActive();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_VOICE_MODE_ON_OFFSET or target == SEARCH_VOICE_MODE_OFF_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(hwnd, WM_APP_VOICE_TOGGLE, if (target == SEARCH_VOICE_MODE_ON_OFFSET) 1 else 2, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_VOICE_ALWAYS_ON_OFFSET or target == SEARCH_VOICE_ALWAYS_OFF_OFFSET) {
                    const on = target == SEARCH_VOICE_ALWAYS_ON_OFFSET;
                    if (app_state.g_voice_always_listen != on) {
                        app_state.g_voice_always_listen = on;
                        if (app_state.g_voice_mode_active) {
                            if (on) {
                                app_state.g_voice_last_activity_tick = GetTickCount64();
                                if (app_state.g_voice_listening_active.load(.acquire)) {
                                    app_state.g_dictation_recording.store(false, .release);
                                    app_state.g_voice_legacy_discard = true;
                                    app_state.g_voice_mic_start_pending = true;
                                    app_state.g_voice_state = .idle;
                                } else voiceMicStart();
                            } else {
                                voiceMicStop();
                                if (app_state.g_voice_state == .listening) app_state.g_voice_state = .idle;
                                if (duplex.voiceShouldStartLegacyListening(app_state.g_voice_always_listen, app_state.g_voice_mic_failed, app_state.g_voice_state)) voiceStartListening();
                            }
                        }
                        saveSession();
                    }
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = !app_state.g_chat_active;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    repositionActive();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_VOICE_STOP_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(hwnd, WM_APP_VOICE_BARGE_IN, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_VOICE_SPEED_100_OFFSET or target == SEARCH_VOICE_SPEED_125_OFFSET or target == SEARCH_VOICE_SPEED_140_OFFSET or target == SEARCH_VOICE_SPEED_150_OFFSET) {
                    app_state.g_voice_speed = if (target == SEARCH_VOICE_SPEED_100_OFFSET) .s100 else if (target == SEARCH_VOICE_SPEED_125_OFFSET) .s125 else if (target == SEARCH_VOICE_SPEED_140_OFFSET) .s140 else .s150;
                    saveSession();
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    repositionActive();
                    var vsp_notice_buf: [32]u8 = undefined;
                    const vsp_notice = std.fmt.bufPrint(&vsp_notice_buf, "Voice speed: {s}", .{voiceSpeedLabel(app_state.g_voice_speed)}) catch "Voice speed changed";
                    showHeaderNoticeAscii(vsp_notice, 1800, false);
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_VOICE_REPLAY_OFFSET or target == SEARCH_VOICE_PREVIOUS_OFFSET or target == SEARCH_VOICE_NEXT_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(hwnd, if (target == SEARCH_VOICE_REPLAY_OFFSET) WM_APP_VOICE_REPLAY else WM_APP_VOICE_STEP, if (target == SEARCH_VOICE_NEXT_OFFSET) 1 else 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_HIDEPILLS_OFFSET) {
                    app_state.g_hide_pills = !app_state.g_hide_pills;
                    saveSession();
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    repositionActive();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_SHORTCUTS_OFFSET) {
                    app_state.g_search_active = false;
                    if (app_state.g_search_from_inbox) {
                        app_state.g_search_from_inbox = false;
                        app_state.g_search_spawn_ws = 0xFF;
                        if (app_state.g_inbox_active) closeInbox(hwnd);
                    }
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SHORTCUTS_OPEN, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CHANGELOG_OFFSET) {
                    app_state.g_search_active = false;
                    if (app_state.g_search_from_inbox) {
                        app_state.g_search_from_inbox = false;
                        app_state.g_search_spawn_ws = 0xFF;
                        if (app_state.g_inbox_active) closeInbox(hwnd);
                    }
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_CHANGELOG_OPEN, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_CLOSEWIN_OFFSET) {
                    app_state.g_search_active = false;
                    clearSearchBackdrop();
                    if (app_state.g_starred_workspace) {
                        showActiveShellAfterOverlay();
                        return 0;
                    }
                    if (app_state.g_single_window and app_state.g_lws_count > 1) {
                        app_state.g_shell_focused = true;
                        showActiveShellAfterOverlay();
                        closeMyWorkspaceSlot(app_state.g_active_workspace);
                        _ = InvalidateRect(hwnd, null, 0);
                        _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    } else {
                        app_state.g_shell_focused = false;
                        _ = PostMessageW(app_state.g_main_hwnd, WM_CLOSE, 0, 0);
                    }
                    return 0;
                }
                if (target == SEARCH_RECONNECT_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = PostMessageW(app_state.g_main_hwnd, WM_APP_RECONNECT, 0, 0);
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_SINGLEWIN_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    toggleSingleWindowMode();
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_INSTALLHOOK_OFFSET) {
                    copyBlueDotHookInstructions();
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_SHOW_FREQUENT_OFFSET or target == SEARCH_FREQUENT_FIRST_OFFSET or target == SEARCH_SHOW_FAVORITES_OFFSET or target == SEARCH_SHOW_ALL_OFFSET) {
                    var settings = app_state.g_layout_settings orelse frequent.Settings{};
                    switch (target) {
                        SEARCH_SHOW_FREQUENT_OFFSET => settings.frequent = !settings.frequent,
                        SEARCH_FREQUENT_FIRST_OFFSET => settings.frequent_first = !settings.frequent_first,
                        SEARCH_SHOW_FAVORITES_OFFSET => settings.favorites = !settings.favorites,
                        SEARCH_SHOW_ALL_OFFSET => settings.all = !settings.all,
                        else => unreachable,
                    }
                    app_state.g_layout_settings = settings;
                    @import("inbox.zig").ensureInboxSplitVisible();
                    saveSession();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_INBOX_FREQUENT_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    app_state.g_pending_new_tab_group = 0;
                    app_state.g_search_from_inbox = false;
                    app_state.g_search_spawn_ws = 0xFF;
                    app_state.g_inbox_tab = frequent.frequent_split;
                    openInbox(hwnd);
                    app_state.g_inbox_sel = 0;
                    return 0;
                }
                if (target == SEARCH_STARRED_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    app_state.g_search_from_inbox = false;
                    if (app_state.g_inbox_active) closeInbox(hwnd);
                    switchToWorkspace(@import("workspace_view.zig").starred);
                    return 0;
                }
                if (target == SEARCH_GOINBOX_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    app_state.g_pending_new_tab_group = 0;
                    if (app_state.g_search_from_inbox) {
                        app_state.g_search_from_inbox = false;
                        app_state.g_search_spawn_ws = 0xFF;
                        _ = InvalidateRect(hwnd, null, 0);
                    } else {
                        openInbox(hwnd);
                    }
                    return 0;
                }
                if (target == SEARCH_NEXTUNREAD_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    app_state.g_pending_new_tab_group = 0;
                    showActiveShellAfterOverlay();
                    _ = jumpToFirstUnreadThread();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_WSSORT_MENU_OFFSET) {
                    app_state.g_search_ws_sort_mode = true;
                    app_state.g_search_workspace_mode = false;
                    app_state.g_search_workspace_delete_mode = false;
                    app_state.g_search_workspace_delete_confirm = null;
                    app_state.g_search_theme_mode = false;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 1;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target >= SEARCH_WSSORT_OFFSET and target < SEARCH_WSSORT_OFFSET + MAX_LWS) {
                    const slot: u32 = @intCast(target - SEARCH_WSSORT_OFFSET);
                    app_state.g_search_active = false;
                    app_state.g_search_ws_sort_mode = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    app_state.g_pending_new_tab_group = 0;
                    showActiveShellAfterOverlay();
                    if (slot < app_state.g_lws_count) switchToWorkspace(slot);
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_WSMOVE_MENU_OFFSET) {
                    app_state.g_search_ws_move_mode = true;
                    app_state.g_search_workspace_mode = false;
                    app_state.g_search_workspace_delete_mode = false;
                    app_state.g_search_workspace_delete_confirm = null;
                    app_state.g_search_ws_sort_mode = false;
                    app_state.g_search_theme_mode = false;
                    app_state.g_wsmove_tab_sid = if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].shell_id else 0;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 1;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target >= SEARCH_WSMOVE_OFFSET and target < SEARCH_WSMOVE_OFFSET + MAX_LWS) {
                    const mslot: u8 = @intCast(target - SEARCH_WSMOVE_OFFSET);
                    const cur_ws: u8 = if (findShellById(app_state.g_wsmove_tab_sid)) |ti| app_state.shells[ti].workspace else if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].workspace else 0xFF;
                    if (selectedTabCount() > 0) {
                        moveSelectedTabsToPill(mslot);
                    } else if (mslot != cur_ws) {
                        if (findShellById(app_state.g_wsmove_tab_sid)) |tab_idx| {
                            moveTabToPill(tab_idx, mslot);
                        }
                    }
                    app_state.g_search_active = false;
                    app_state.g_search_ws_move_mode = false;
                    app_state.g_wsmove_tab_sid = 0;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    app_state.g_pending_new_tab_group = 0;
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (app_state.g_search_ws_move_mode and target >= SEARCH_WORKSPACE_OFFSET and target < SEARCH_WORKSPACE_OFFSET + MAX_WORKSPACES) {
                    const workspace_idx: u32 = @intCast(target - SEARCH_WORKSPACE_OFFSET);
                    if (selectedTabCount() > 0) {
                        moveSelectedTabsToClosedWorkspace(workspace_idx);
                    } else if (findShellById(app_state.g_wsmove_tab_sid)) |tab_idx| {
                        moveTabToClosedWorkspace(tab_idx, workspace_idx);
                    }
                    app_state.g_search_active = false;
                    app_state.g_search_ws_move_mode = false;
                    app_state.g_wsmove_tab_sid = 0;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    app_state.g_pending_new_tab_group = 0;
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_WSMOVE_NEW_OFFSET) {
                    if (newPillForMove()) |new_slot| {
                        if (selectedTabCount() > 0) {
                            moveSelectedTabsToPill(new_slot);
                        } else if (findShellById(app_state.g_wsmove_tab_sid)) |tab_idx| {
                            moveTabToPill(tab_idx, new_slot);
                        }
                    }
                    app_state.g_search_active = false;
                    app_state.g_search_ws_move_mode = false;
                    app_state.g_wsmove_tab_sid = 0;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    app_state.g_pending_new_tab_group = 0;
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_GROUPMOVE_MENU_OFFSET) {
                    app_state.g_search_group_move_mode = true;
                    app_state.g_search_workspace_mode = false;
                    app_state.g_search_workspace_delete_mode = false;
                    app_state.g_search_workspace_delete_confirm = null;
                    app_state.g_search_ws_sort_mode = false;
                    app_state.g_search_ws_move_mode = false;
                    app_state.g_wsmove_tab_sid = 0;
                    app_state.g_search_theme_mode = false;
                    app_state.g_groupmove_tab_sid = if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].shell_id else 0;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 1;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_GROUPMOVE_BACK_OFFSET) {
                    app_state.g_search_group_move_mode = false;
                    app_state.g_groupmove_tab_sid = 0;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 0;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (app_state.g_search_group_move_mode and target >= SEARCH_GROUPMOVE_GROUP_OFFSET and target < SEARCH_GROUPMOVE_GROUP_OFFSET + MAX_GROUPS) {
                    const gi = target - SEARCH_GROUPMOVE_GROUP_OFFSET;
                    if (gi < app_state.group_count and assignTabOrSelectionToGroup(app_state.g_groupmove_tab_sid, app_state.groups[gi].id)) {
                        invalidateSidebar();
                        if (!app_state.g_restoring) saveSession();
                    }
                    app_state.g_search_active = false;
                    app_state.g_search_group_move_mode = false;
                    app_state.g_groupmove_tab_sid = 0;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    app_state.g_pending_new_tab_group = 0;
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (app_state.g_search_group_move_mode and target == SEARCH_GROUPMOVE_NEW_OFFSET) {
                    var rename_group_idx: ?u32 = null;
                    if (selectedTabCount() > 0 or findShellById(app_state.g_groupmove_tab_sid) != null) {
                        const new_gid = createDefaultGroup();
                        if (new_gid != 0 and assignTabOrSelectionToGroup(app_state.g_groupmove_tab_sid, new_gid)) {
                            rename_group_idx = findGroupIdx(new_gid);
                            invalidateSidebar();
                            if (!app_state.g_restoring) saveSession();
                        }
                    }
                    app_state.g_search_active = false;
                    app_state.g_search_group_move_mode = false;
                    app_state.g_groupmove_tab_sid = 0;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    app_state.g_pending_new_tab_group = 0;
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    if (rename_group_idx) |gidx| {
                        startGroupRename(gidx);
                    } else {
                        _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    }
                    return 0;
                }
                if (app_state.g_search_group_move_mode and target == SEARCH_GROUPMOVE_NONE_OFFSET) {
                    if (removeTabOrSelectionFromGroup(app_state.g_groupmove_tab_sid)) {
                        invalidateSidebar();
                        if (!app_state.g_restoring) saveSession();
                    }
                    app_state.g_search_active = false;
                    app_state.g_search_group_move_mode = false;
                    app_state.g_groupmove_tab_sid = 0;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    app_state.g_pending_new_tab_group = 0;
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target >= SEARCH_WORKSPACE_DELETE_OFFSET and target < SEARCH_WORKSPACE_DELETE_OFFSET + MAX_WORKSPACES) {
                    const workspace_idx: u32 = @intCast(target - SEARCH_WORKSPACE_DELETE_OFFSET);
                    if (app_state.g_search_workspace_delete_confirm) |confirm_idx| {
                        if (confirm_idx == workspace_idx) {
                            _ = deleteWorkspaceByIndex(workspace_idx);
                            app_state.g_search_workspace_delete_confirm = null;
                            app_state.g_search_len = 0;
                            app_state.g_search_sel = 0;
                            app_state.g_search_scroll = 0;
                            updateSearchResults();
                            _ = InvalidateRect(hwnd, null, 0);
                            return 0;
                        }
                    }
                    app_state.g_search_workspace_delete_confirm = workspace_idx;
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_TABCTX_BACK) {
                    app_state.g_search_tabctx_mode = false;
                    app_state.g_tabctx_sid = 0;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 0;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_TABCTX_WSMOVE) {
                    app_state.g_search_ws_move_mode = true;
                    app_state.g_search_workspace_mode = false;
                    app_state.g_search_workspace_delete_mode = false;
                    app_state.g_search_workspace_delete_confirm = null;
                    app_state.g_search_ws_sort_mode = false;
                    app_state.g_search_theme_mode = false;
                    app_state.g_wsmove_tab_sid = app_state.g_tabctx_sid;
                    app_state.g_search_tabctx_mode = false;
                    app_state.g_tabctx_sid = 0;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 1;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_TABCTX_GROUP_NEW_TAB_IN) {
                    if (findShellById(app_state.g_tabctx_sid)) |ti| {
                        app_state.g_pending_new_tab_group = app_state.shells[ti].group_id;
                    }
                    app_state.g_search_tabctx_mode = false;
                    app_state.g_tabctx_sid = 0;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 0;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if ((target >= SEARCH_TABCTX_RECONNECT and target <= SEARCH_TABCTX_FAVORITE) or target == SEARCH_TABCTX_CHAT_STOP or target == SEARCH_TABCTX_CHAT_DENY or target == SEARCH_TABCTX_CHAT_ALWAYS or target == SEARCH_TABCTX_CHAT_ALLOW or
                    (target >= SEARCH_TABCTX_GROUP_ADD_OFFSET and target < SEARCH_TABCTX_GROUP_ADD_OFFSET + MAX_GROUPS))
                {
                    const tc_sid = app_state.g_tabctx_sid;
                    const tc_sel_mode = selectedTabCount() > 0;
                    var rename_group_idx: ?u32 = null;
                    if (findShellById(tc_sid)) |ti| {
                        if (target == SEARCH_TABCTX_RECONNECT) {
                            app_state.g_search_active = false;
                            app_state.g_search_tabctx_mode = false;
                            app_state.g_tabctx_sid = 0;
                            app_state.g_shell_focused = true;
                            clearSearchBackdrop();
                            app_state.g_pending_new_tab_group = 0;
                            showActiveShellAfterOverlay();
                            _ = InvalidateRect(hwnd, null, 0);
                            @import("chat_send.zig").sshReconnectNow(ti);
                            switchToShell(ti);
                            return 0;
                        } else if (target == SEARCH_TABCTX_CHAT_ALLOW) {
                            _ = @import("chat_send.zig").chatPermissionAnswer(ti, .allow);
                        } else if (target == SEARCH_TABCTX_CHAT_ALWAYS) {
                            _ = @import("chat_send.zig").chatPermissionAnswer(ti, .always);
                        } else if (target == SEARCH_TABCTX_CHAT_DENY) {
                            _ = @import("chat_send.zig").chatPermissionAnswer(ti, .deny);
                        } else if (target == SEARCH_TABCTX_CHAT_STOP) {
                            _ = @import("chat_send.zig").chatStopAgent(ti);
                        } else if (target == SEARCH_TABCTX_CHAT_RESET) {
                            chatResetForShell(ti);
                        } else if (target == SEARCH_TABCTX_FAVORITE) {
                            toggleFavorite(ti);
                        } else if (target == SEARCH_TABCTX_INBOX_EXCLUDE) {
                            toggleInboxExcluded(ti);
                        } else if (target == SEARCH_TABCTX_MUTE) {
                            app_state.shells[ti].muted = !app_state.shells[ti].muted;
                            if (app_state.shells[ti].muted) {
                                app_state.shells[ti].activity = .idle;
                                app_state.shells[ti].needs_attention = false;
                            }
                            invalidateSidebar();
                            publishInboxState();
                            if (!app_state.g_restoring) saveSession();
                        } else if (target == SEARCH_TABCTX_KEEPALIVE) {
                            app_state.shells[ti].keep_alive = !app_state.shells[ti].keep_alive;
                            invalidateSidebar();
                            if (!app_state.g_restoring) saveSession();
                        } else if (target == SEARCH_TABCTX_PIN_TOP) {
                            app_state.shells[ti].pinned_top = !app_state.shells[ti].pinned_top;
                            invalidateSidebar();
                            if (!app_state.g_restoring) saveSession();
                        } else if (target == SEARCH_TABCTX_LOCK) {
                            app_state.shells[ti].locked = !app_state.shells[ti].locked;
                            invalidateSidebar();
                            if (!app_state.g_restoring) saveSession();
                        } else if (target == SEARCH_TABCTX_KEEPAWAKE) {
                            app_state.shells[ti].keep_awake = !app_state.shells[ti].keep_awake;
                            if (app_state.shells[ti].keep_awake and app_state.shells[ti].browser_frozen) wakeBrowserPaneFromFreeze(ti);
                            invalidateSidebar();
                            if (!app_state.g_restoring) saveSession();
                        } else if (target == SEARCH_TABCTX_ARCHIVE) {
                            if (app_state.shells[ti].tmux_session_len > 0) archiveTabAt(ti) else closeNonTmuxTabAt(ti);
                        } else if (target == SEARCH_TABCTX_END_TMUX) {
                            if (app_state.shells[ti].tmux_session_len > 0) endTmuxSessionAt(ti);
                        } else if (target == SEARCH_TABCTX_BROWSER) {
                            app_state.shells[ti].browser_enabled = !app_state.shells[ti].browser_enabled;
                            if (app_state.shells[ti].browser_enabled) {
                                ensureBrowserDefaultUrl(ti);
                                updateBrowserVisibility();
                            } else {
                                discardBrowserUrlBarEdit();
                                closeBrowserForShell(ti);
                                updateBrowserVisibility();
                            }
                            repositionActive();
                            if (app_state.shells[ti].browser_enabled and ti == app_state.active_shell) {
                                armBrowserVisibilitySettle(12);
                            }
                            invalidateSidebar();
                            if (!app_state.g_restoring) saveSession();
                        } else if (target == SEARCH_TABCTX_GROUP_NEW) {
                            const new_gid = createDefaultGroup();
                            if (new_gid != 0 and assignTabOrSelectionToGroup(tc_sid, new_gid)) {
                                rename_group_idx = findGroupIdx(new_gid);
                                invalidateSidebar();
                                if (!app_state.g_restoring) saveSession();
                            }
                        } else if (target == SEARCH_TABCTX_GROUP_REMOVE) {
                            if (removeTabOrSelectionFromGroup(tc_sid)) {
                                invalidateSidebar();
                                if (!app_state.g_restoring) saveSession();
                            }
                        } else if (target == SEARCH_TABCTX_MOVE_NEW_WS) {
                            app_state.g_search_active = false;
                            app_state.g_search_tabctx_mode = false;
                            app_state.g_tabctx_sid = 0;
                            app_state.g_shell_focused = true;
                            clearSearchBackdrop();
                            app_state.g_pending_new_tab_group = 0;
                            showActiveShellAfterOverlay();
                            _ = InvalidateRect(hwnd, null, 0);
                            if (app_state.g_single_window) {
                                if (newPillForMove()) |slot| {
                                    if (tc_sel_mode) moveSelectedTabsToPill(slot) else moveTabToPill(ti, slot);
                                }
                            } else {
                                if (tc_sel_mode) moveSelectedTabsToNewWorkspace() else moveSingleTabToNewWorkspace(ti);
                            }
                            return 0;
                        } else if (target == SEARCH_TABCTX_CLEAR_SEL) {
                            _ = clearTabSelection();
                            invalidateSidebar();
                        } else if (target >= SEARCH_TABCTX_GROUP_ADD_OFFSET and target < SEARCH_TABCTX_GROUP_ADD_OFFSET + MAX_GROUPS) {
                            const gi = target - SEARCH_TABCTX_GROUP_ADD_OFFSET;
                            if (gi < app_state.group_count and assignTabOrSelectionToGroup(tc_sid, app_state.groups[gi].id)) {
                                invalidateSidebar();
                                if (!app_state.g_restoring) saveSession();
                            }
                        }
                    }
                    app_state.g_search_active = false;
                    app_state.g_search_tabctx_mode = false;
                    app_state.g_tabctx_sid = 0;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    app_state.g_pending_new_tab_group = 0;
                    showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    if (rename_group_idx) |gidx| {
                        startGroupRename(gidx);
                    } else {
                        _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    }
                    return 0;
                }
                if (target >= SEARCH_ARCHIVED_OFFSET and target < SEARCH_ARCHIVED_OFFSET + 64) {
                    const ar_idx = target - SEARCH_ARCHIVED_OFFSET;
                    loadArchiveFromDisk(true);
                    if (ar_idx < app_state.g_archived_count) {
                        const ar_copy = app_state.g_archived.items[ar_idx];
                        const ts = ar_copy.tmux_session[0..ar_copy.tmux_session_len];
                        app_state.g_search_active = false;
                        app_state.g_shell_focused = true;
                        clearSearchBackdrop();
                        applySearchSpawnContext(hwnd);
                        if (!resurrectArchivedByKey(hwnd, ar_copy.tmux_host, ts)) {
                            showActiveShellAfterOverlay();
                            if (!capacityBlockNoticeActive()) showHeaderNoticeAscii("Archived session restore failed", 4000, true);
                            _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                        }
                        _ = InvalidateRect(hwnd, null, 0);
                    }
                    return 0;
                }
                if (target >= SEARCH_REMINDER_ROW_OFFSET and target < SEARCH_REMINDER_ROW_OFFSET + 64) {
                    const rem_idx: u32 = @intCast(target - SEARCH_REMINDER_ROW_OFFSET);
                    if (restoreReminderByIndex(rem_idx)) {
                        app_state.g_search_active = false;
                        app_state.g_search_reminders_mode = false;
                        app_state.g_shell_focused = true;
                        clearSearchBackdrop();
                        _ = InvalidateRect(hwnd, null, 0);
                        app_state.g_refocus_remaining = 4;
                        _ = SetTimer(hwnd, TIMER_REFOCUS, 200, null);
                    } else {
                        showHeaderNoticeAscii("Reminder belongs to another workspace", 3500, true);
                    }
                    return 0;
                }
                if (target >= SEARCH_CUSTOMCMD_OFFSET and target < SEARCH_CUSTOMCMD_OFFSET + MAX_CUSTOM_CMDS) {
                    const cc_idx = target - SEARCH_CUSTOMCMD_OFFSET;
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    applySearchSpawnContext(hwnd);
                    var cc_spawned = false;
                    if (cc_idx < app_state.g_custom_cmds_count) cc_spawned = spawnCustomCmd(cc_idx);
                    applyPendingGroup();
                    if (!cc_spawned) showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    if (cc_spawned) {
                        app_state.g_refocus_remaining = 4;
                        _ = SetTimer(hwnd, TIMER_REFOCUS, 200, null);
                    } else {
                        _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    }
                    return 0;
                }
                if (target >= SEARCH_RENAMEWIN_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = false;
                    clearSearchBackdrop();
                    app_state.g_pending_new_tab_group = 0;
                    showActiveShellAfterOverlay();
                    startWindowRename();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target >= SEARCH_WORKSPACE_OFFSET) {
                    const workspace_idx = target - SEARCH_WORKSPACE_OFFSET;
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    app_state.g_pending_new_tab_group = 0;
                    showActiveShellAfterOverlay();
                    if (workspace_idx < app_state.g_workspace_count) {
                        const e = &app_state.g_workspaces[workspace_idx];
                        var id_copy: [64]u8 = std.mem.zeroes([64]u8);
                        const id_len = @min(e.id_len, id_copy.len - 1);
                        if (id_len > 0) @memcpy(id_copy[0..id_len], e.id[0..id_len]);
                        var name_copy: [64]u8 = std.mem.zeroes([64]u8);
                        const name_len = @min(e.name_len, name_copy.len - 1);
                        if (name_len > 0) @memcpy(name_copy[0..name_len], e.name[0..name_len]);
                        var host_copy: [64]u8 = std.mem.zeroes([64]u8);
                        const host_len = @min(e.host_len, host_copy.len - 1);
                        if (host_len > 0) @memcpy(host_copy[0..host_len], e.host[0..host_len]);
                        const id = id_copy[0..id_len];
                        const name = name_copy[0..name_len];
                        const host = host_copy[0..host_len];
                        if (std.mem.eql(u8, id, getInstanceName())) {} else if (app_state.g_single_window and findMyWorkspaceSlot(id) != null) {
                            switchToWorkspace(findMyWorkspaceSlot(id).?);
                        } else if (findAndFocusWorkspaceWindow(id, name)) {} else if (host.len > 0) {} else if (app_state.g_single_window) {
                            if (absorbWorkspaceIntoSlots(id, name)) {
                                if (findMyWorkspaceSlot(id)) |slot| switchToWorkspace(slot);
                            } else {
                                newWorkspace();
                            }
                        } else {
                            setWorkspaceRestoreAndSave(id, name, true);
                            spawnWorkspaceWindow(id);
                        }
                    }
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_CODEX_TMUX_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    applySearchSpawnContext(hwnd);
                    const spawned_codex = spawnCodexTmuxSession();
                    applyPendingGroup();
                    if (!spawned_codex) showActiveShellAfterOverlay();
                    _ = InvalidateRect(hwnd, null, 0);
                    if (spawned_codex) {
                        app_state.g_refocus_remaining = 4;
                        _ = SetTimer(hwnd, TIMER_REFOCUS, 200, null);
                    } else {
                        _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    }
                    return 0;
                }
                if (target >= SEARCH_NEWWIN_OFFSET) {
                    app_state.g_search_active = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    app_state.g_pending_new_tab_group = 0;
                    showActiveShellAfterOverlay();
                    if (app_state.g_single_window) {
                        newWorkspace();
                    } else if (target == SEARCH_CREATEWS_OFFSET) {
                        spawnEmptyWorkspace();
                    } else {
                        spawnNewWindow();
                    }
                    _ = InvalidateRect(hwnd, null, 0);
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                    return 0;
                }
                if (target == SEARCH_OPENALL_OFFSET) {
                    app_state.g_search_openall_host_mode = true;
                    app_state.g_search_workspace_mode = false;
                    app_state.g_search_workspace_delete_mode = false;
                    app_state.g_search_theme_mode = false;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 1;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_OPENALL_HOST_BACK_OFFSET) {
                    app_state.g_search_openall_host_mode = false;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 0;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target >= SEARCH_OPENFOLDER_OFFSET and target <= SEARCH_OPENALL_HOST_INNE_OFFSET) {
                    const host_mode = target == SEARCH_OPENALL_HOST_DE_OFFSET or
                        target == SEARCH_OPENALL_HOST_UK_OFFSET or
                        target == SEARCH_OPENALL_HOST_INNE_OFFSET;
                    const selected_host: u8 = switch (target) {
                        SEARCH_OPENALL_HOST_DE_OFFSET => 0,
                        SEARCH_OPENALL_HOST_UK_OFFSET => 1,
                        SEARCH_OPENALL_HOST_INNE_OFFSET => 2,
                        else => 0,
                    };
                    app_state.g_search_active = false;
                    app_state.g_search_openall_host_mode = false;
                    app_state.g_shell_focused = true;
                    clearSearchBackdrop();
                    applySearchSpawnContext(hwnd);
                    app_state.g_pending_new_tab_group = 0;
                    const folder_mode = (target == SEARCH_OPENFOLDER_OFFSET);
                    var folder_host: u8 = 0;
                    var folder_buf: [256]u8 = undefined;
                    var folder_len: u32 = 0;
                    if (folder_mode and !focusedSessionFolder(&folder_host, &folder_buf, &folder_len)) {
                        showHeaderNoticeAscii("No focused tmux folder detected", 4000, true);
                        showActiveShellAfterOverlay();
                        _ = InvalidateRect(hwnd, null, 0);
                        _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                        return 0;
                    }
                    const repo_mode = (target == SEARCH_RECOVER_REPO_OFFSET);
                    var repo_host: u8 = 0;
                    var repo_buf: [256]u8 = undefined;
                    var repo_len: u32 = 0;
                    if (repo_mode and !workspacePrimaryRepo(&repo_host, &repo_buf, &repo_len)) {
                        showHeaderNoticeAscii("No workspace repo detected", 4000, true);
                        showActiveShellAfterOverlay();
                        _ = InvalidateRect(hwnd, null, 0);
                        _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                        return 0;
                    }
                    buildFilteredTmux();
                    if (folder_mode and countFolderSessions(folder_host, folder_buf[0..folder_len]) == 0) {
                        showHeaderNoticeAscii("No missing tmux sessions in this folder", 4000, false);
                        showActiveShellAfterOverlay();
                        _ = InvalidateRect(hwnd, null, 0);
                        _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                        return 0;
                    }
                    if (repo_mode and countFolderSessions(repo_host, repo_buf[0..repo_len]) == 0) {
                        showHeaderNoticeAscii("No missing tmux sessions for workspace", 4000, false);
                        showActiveShellAfterOverlay();
                        _ = InvalidateRect(hwnd, null, 0);
                        _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                        return 0;
                    }
                    if (host_mode and inactiveTmuxCountForHost(selected_host) == 0) {
                        showHeaderNoticeAscii("No unopened tmux sessions on this VPS", 4000, false);
                        showActiveShellAfterOverlay();
                        _ = InvalidateRect(hwnd, null, 0);
                        _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                        return 0;
                    }
                    var oti: u32 = 0;
                    while (oti < app_state.g_inactive_filtered_count) : (oti += 1) {
                        const cidx = app_state.g_inactive_filtered[oti];
                        const e = &app_state.g_tmux_cache[cidx];
                        if (folder_mode) {
                            if (e.host != folder_host or e.path_len == 0) continue;
                            if (!pathUnderFolder(e.path[0..e.path_len], folder_buf[0..folder_len])) continue;
                        }
                        if (repo_mode) {
                            if (e.host != repo_host or e.path_len == 0) continue;
                            if (!pathUnderFolder(e.path[0..e.path_len], repo_buf[0..repo_len])) continue;
                        }
                        if (host_mode and e.host != selected_host) continue;
                        const sn = e.name[0..e.name_len];
                        app_state.g_pending_tmux_host = e.host;
                        _ = spawnShellWithSession(.tmux, sn, null, null);
                        app_state.g_pending_tmux_host = 0;
                    }
                    app_state.g_tmux_fetch_tick = 0;
                    _ = InvalidateRect(hwnd, null, 0);
                    app_state.g_refocus_remaining = 4;
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 200, null);
                    return 0;
                }
                if (target == SEARCH_THEME_BACK_OFFSET) {
                    app_state.g_search_theme_mode = false;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 0;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_THEME_MENU_OFFSET) {
                    app_state.g_search_theme_mode = true;
                    app_state.g_search_workspace_mode = false;
                    app_state.g_search_workspace_delete_mode = false;
                    app_state.g_search_workspace_delete_confirm = null;
                    app_state.g_search_len = 0;
                    app_state.g_search_sel = 0;
                    app_state.g_search_scroll = 0;
                    updateSearchResults();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (target == SEARCH_THEME_SYSTEM_OFFSET or target == SEARCH_THEME_DARK_OFFSET or target == SEARCH_THEME_MID_OFFSET or target == SEARCH_THEME_LIGHT_OFFSET or target == SEARCH_THEME_AMOLED_OFFSET or target == SEARCH_THEME_EDGE_GRAY_OFFSET) {
                    app_state.g_system_theme = target == SEARCH_THEME_SYSTEM_OFFSET;
                    app_state.g_dev_theme_active = false;
                    app_state.g_multiprompt_theme = false;
                    if (app_state.g_system_theme) {
                        resolveSystemThemeFlags();
                    } else {
                        app_state.g_light_theme = target == SEARCH_THEME_LIGHT_OFFSET;
                        app_state.g_mid_theme = target == SEARCH_THEME_MID_OFFSET;
                        app_state.g_edge_gray_theme = target == SEARCH_THEME_EDGE_GRAY_OFFSET;
                        app_state.g_amoled_theme = target == SEARCH_THEME_AMOLED_OFFSET;
                    }
                    resetFontCache();
                    applyTitleBarTheme();
                    applyConsoleThemeToAllShells();
                    repositionActive();
                    refreshBrowserEdgeMasks();
                    _ = InvalidateRect(hwnd, null, 0);
                    saveGlobalTheme();
                    return 0;
                }
                if (target == SEARCH_THEME_MULTIPROMPT_OFFSET) {
                    app_state.g_system_theme = false;
                    app_state.g_multiprompt_theme = true;
                    app_state.g_dev_theme_active = false;
                    app_state.g_light_theme = false;
                    app_state.g_mid_theme = false;
                    app_state.g_edge_gray_theme = false;
                    app_state.g_amoled_theme = false;
                    resetFontCache();
                    applyTitleBarTheme();
                    applyConsoleThemeToAllShells();
                    repositionActive();
                    refreshBrowserEdgeMasks();
                    startSpinnerTimerIfNeeded();
                    _ = InvalidateRect(hwnd, null, 0);
                    saveGlobalTheme();
                    return 0;
                }
                if (target == SEARCH_THEME_DEV_BLUE_OFFSET and IS_DEV) {
                    loadDevThemeFromFile();
                    app_state.g_system_theme = false;
                    app_state.g_dev_theme_active = true;
                    app_state.g_multiprompt_theme = false;
                    app_state.g_light_theme = false;
                    app_state.g_mid_theme = false;
                    app_state.g_edge_gray_theme = false;
                    app_state.g_amoled_theme = false;
                    resetFontCache();
                    applyTitleBarTheme();
                    applyConsoleThemeToAllShells();
                    repositionActive();
                    refreshBrowserEdgeMasks();
                    _ = InvalidateRect(hwnd, null, 0);
                    saveGlobalTheme();
                    return 0;
                }
                if (target == SEARCH_THEME_DEV_EDIT_OFFSET and IS_DEV) {
                    openDevThemeFileInEditor();
                    return 0;
                }
                if (target == SEARCH_THEME_DEV_RELOAD_OFFSET and IS_DEV) {
                    loadDevThemeFromFile();
                    resetFontCache();
                    applyTitleBarTheme();
                    if (IS_DEV) {
                        applyConsoleThemeToAllShells();
                        repositionActive();
                    }
                    refreshBrowserEdgeMasks();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if ((target >= SEARCH_THEME_MENU_OFFSET and target <= SEARCH_THEME_DEV_RELOAD_OFFSET) or target == SEARCH_THEME_MULTIPROMPT_OFFSET) {
                    return 0;
                }
                if (target == SEARCH_SOUND_OFFSET) {
                    app_state.g_sound_enabled = !app_state.g_sound_enabled;
                    _ = InvalidateRect(hwnd, null, 0);
                    saveSession();
                    return 0;
                }
                if (target < SEARCH_TMUX_OFFSET and target >= app_state.shell_count) {
                    var log_buf: [96]u8 = undefined;
                    debugLog(std.fmt.bufPrint(&log_buf, "palette confirm: unknown result index {d} (shell_count={d})", .{ target, app_state.shell_count }) catch "palette confirm: unknown result index");
                    return 0;
                }
                app_state.g_search_active = false;
                app_state.g_shell_focused = true;
                clearSearchBackdrop();
                var spawned_new: bool = false;
                if (target >= SEARCH_NEW_OFFSET) {
                    applySearchSpawnContext(hwnd);
                    const kind_idx = target - SEARCH_NEW_OFFSET;
                    if (kind_idx < NUM_BUTTONS) {
                        _ = spawnShellFromMenuIndex(kind_idx);
                        spawned_new = true;
                    }
                    applyPendingGroup();
                } else if (target >= SEARCH_TMUX_OFFSET) {
                    applySearchSpawnContext(hwnd);
                    const cache_idx = target - SEARCH_TMUX_OFFSET;
                    if (cache_idx < app_state.g_tmux_cache_count) {
                        const sname = app_state.g_tmux_cache[cache_idx].name[0..app_state.g_tmux_cache[cache_idx].name_len];
                        app_state.g_pending_tmux_host = app_state.g_tmux_cache[cache_idx].host;
                        _ = spawnShellWithSession(.tmux, sname, null, null);
                        app_state.g_pending_tmux_host = 0;
                        app_state.g_tmux_fetch_tick = 0;
                        spawned_new = true;
                    }
                    applyPendingGroup();
                } else {
                    app_state.g_pending_new_tab_group = 0;
                    if (app_state.g_search_from_inbox) {
                        app_state.g_search_from_inbox = false;
                        app_state.g_search_spawn_ws = 0xFF;
                        if (app_state.g_inbox_active) closeInbox(hwnd);
                    }
                    if (app_state.g_single_window and target < app_state.shell_count and
                        app_state.shells[target].workspace != app_state.g_active_workspace)
                    {
                        app_state.g_ws_switch_focus_grace = GetTickCount64() + 2000;
                        app_state.g_active_workspace = app_state.shells[target].workspace;
                        updateMainWindowTitle();
                    }
                    if (target < app_state.shell_count and app_state.shells[target].inbox_archived) {
                        _ = commitArchivedSessionReturn(app_state.shells[target].shell_id);
                    }
                    @import("console.zig").switchToShellByUser(@intCast(target));
                    if (app_state.g_chat_active) {
                        _ = ShowWindow(app_state.g_chat_transcript_hwnd, SW_SHOWNOACTIVATE);
                        _ = ShowWindow(app_state.g_chat_composer_hwnd, SW_SHOWNOACTIVATE);
                        _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
                    }
                }
                _ = InvalidateRect(hwnd, null, 0);
                if (spawned_new) {
                    app_state.g_refocus_remaining = 4;
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 200, null);
                } else {
                    _ = SetTimer(hwnd, TIMER_REFOCUS, 50, null);
                }
            }
            return 0;
        },
        WM_APP_REOPEN_CLOSED => {
            reopenLastClosedShell();
            return 0;
        },
        WM_APP_TOGGLE_SIDEBAR => {
            if (!app_state.g_hide_sidebar and !app_state.g_sidebar_collapsed) {
                app_state.g_sidebar_collapsed = true;
            } else if (!app_state.g_hide_sidebar and app_state.g_sidebar_collapsed) {
                app_state.g_sidebar_collapsed = false;
                app_state.g_hide_sidebar = true;
            } else {
                app_state.g_hide_sidebar = false;
                app_state.g_sidebar_collapsed = false;
            }
            saveSession();
            repositionActive();
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_APP_SHOW_SIDEBAR => {
            handleShowSidebarRequest(hwnd, wp != 0);
            return 0;
        },
        WM_APP_SSH_UNAVAILABLE => {
            showHeaderNoticeAscii("ssh could not start on this laptop", 8000, true);
            return 0;
        },
        WM_APP_TMUX_LIST_READY => {
            if (app_state.g_vps_poll_is_leader) writeVpsPollCache();
            _ = syncLiveTmuxMetadataFromCache();
            announceCapacityTransitions();
            if (app_state.g_search_active) updateSearchResults();
            invalidateSidebar();
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_APP_FAVICON_FETCHED => {
            const finished_id: u32 = @intCast(wp);
            const success: bool = lp != 0;
            if (success) {
                for (0..app_state.shell_count) |i| {
                    if (app_state.shells[i].shell_id != finished_id) continue;
                    if (app_state.shells[i].favicon_hicon) |h| {
                        _ = DestroyIcon(h);
                        app_state.shells[i].favicon_hicon = null;
                    }
                    var wpath: [512]u16 = undefined;
                    for (0..app_state.g_favicon_fetch_local_len) |pi| wpath[pi] = @as(u16, app_state.g_favicon_fetch_local_path[pi]);
                    wpath[app_state.g_favicon_fetch_local_len] = 0;
                    const LR_LOADFROMFILE: UINT = 0x00000010;
                    const LR_DEFAULTSIZE: UINT = 0x00000040;
                    const new_hicon = LoadImageW(null, @ptrCast(&wpath), IMAGE_ICON, 16, 16, LR_LOADFROMFILE | LR_DEFAULTSIZE);
                    if (new_hicon != null) {
                        app_state.shells[i].favicon_hicon = new_hicon;
                        @memcpy(app_state.shells[i].favicon_path[0..app_state.g_favicon_fetch_local_len], app_state.g_favicon_fetch_local_path[0..app_state.g_favicon_fetch_local_len]);
                        app_state.shells[i].favicon_path_len = app_state.g_favicon_fetch_local_len;
                        saveSession();
                    }
                    break;
                }
            }
            invalidateSidebar();
            _ = InvalidateRect(hwnd, null, 0);
            return 0;
        },
        WM_APP_NOTIFY => {
            pollNotifications();
            return 0;
        },
        WM_APP_POWER_ACTIVITY => {
            exitDeepIdleNow(hwnd);
            return 0;
        },
        WM_APP_SHOT_PASTE => {
            handleShotPaste();
            return 0;
        },
        WM_APP_ZSB_OPEN => {
            handleZsbOpenRequest();
            return 0;
        },
        WM_APP_ZSB_WHO => {
            handleZsbWhoRequest();
            return 0;
        },
        WM_APP_ZSB_BIND => {
            handleZsbBindRequest();
            return 0;
        },
        WM_APP_BROWSER_RESOLVED => {
            handleBrowserWindowResolved(@intCast(wp & 0xFFFFFFFF), @intCast(lp));
            return 0;
        },
        WM_APP_DIAG => {
            handleDiagRequest();
            return 0;
        },
        WM_APP_INPUT_HOOK_RECOVER => {
            forceReinstallHooks();
            app_state.g_last_kb_hook_tick = GetTickCount64();
            app_state.g_keyboard_recovery_posted.store(false, .release);
            debugLog("[hook-sentinel] UI keyboard hook force-cycled");
            altqLog("hook_recover keyboard hook force-cycled (clears the Alt+Q latch) chat={}", .{app_state.g_chat_active});
            return 0;
        },
        WM_APP_BROWSER_URL_UPDATE => {
            const polled_shell_id: u32 = @intCast(wp & 0xFFFFFFFF);
            for (0..app_state.shell_count) |i| {
                if (app_state.shells[i].shell_id != polled_shell_id) continue;
                const ti: u32 = @intCast(i);
                const new_url = app_state.g_browser_url_poll_result[0..app_state.g_browser_url_poll_result_len];
                if (new_url.len == 0) break;
                if (std.mem.startsWith(u8, new_url, "data:text/html") and
                    std.mem.indexOf(u8, new_url, "ZSPANE") != null) break;
                const old_url = app_state.shells[ti].browser_url[0..app_state.shells[ti].browser_url_len];
                if (std.mem.eql(u8, old_url, new_url)) break;
                const copy_len: u32 = @intCast(@min(new_url.len, app_state.shells[ti].browser_url.len - 1));
                @memcpy(app_state.shells[ti].browser_url[0..copy_len], new_url[0..copy_len]);
                app_state.shells[ti].browser_url_len = copy_len;
                if (ti == app_state.active_shell) {
                    if (calcBrowserLayout()) |layout| {
                        var urlbar_rc = RECT{
                            .left = layout.urlbar_x,
                            .top = layout.urlbar_y,
                            .right = layout.urlbar_x + layout.urlbar_w,
                            .bottom = layout.urlbar_y + layout.urlbar_h,
                        };
                        _ = InvalidateRect(hwnd, &urlbar_rc, 0);
                    }
                }
                break;
            }
            return 0;
        },
        WM_APP_SHELL_EXITED => {
            const exited_id: u32 = @intCast(wp);
            var idx_opt: ?u32 = null;
            for (0..app_state.shell_count) |i| {
                if (app_state.shells[i].shell_id == exited_id) {
                    idx_opt = @intCast(i);
                    break;
                }
            }
            if (idx_opt) |idx| {
                var exit_code: DWORD = std.math.maxInt(DWORD);
                const got_code = app_state.shells[idx].process != null and GetExitCodeProcess(app_state.shells[idx].process, &exit_code) != 0;
                if (app_state.shells[idx].ssh_reconnect.phase == .closed or
                    (app_state.shells[idx].disconnected and app_state.shells[idx].process == null))
                {
                    var exit_log: [160]u8 = undefined;
                    debugLog(std.fmt.bufPrint(&exit_log, "WM_APP_SHELL_EXITED id={d} reason=already-disconnected-or-closed exit_code={d} known={}", .{ exited_id, exit_code, got_code }) catch "WM_APP_SHELL_EXITED log-overflow");
                    return 0;
                }
                const now = GetTickCount64();
                const in_resume_window = now < app_state.g_resume_until_tick;
                const k = app_state.shells[idx].kind;
                const is_ssh_kind = (k == .vps or k == .vps2 or k == .tmux);
                const loader_failure = got_code and exit_code == 0xC0000139;
                if (loader_failure) sshSpawnFailed();
                const spawn_tick = app_state.shells[idx].spawn_tick;
                const alive_ms = if (spawn_tick != 0) now -| spawn_tick else std.math.maxInt(u64);
                const action = decideShellExit(k, got_code, exit_code, in_resume_window, app_state.shells[idx].pinned_top or app_state.shells[idx].locked, app_state.ISSUE_350_KEEP_TMUX_TABS, alive_ms);
                if (is_ssh_kind) {
                    @import("chat_send.zig").sshDisconnect(idx, "process-exit-event");
                    return 0;
                }
                var exit_log: [192]u8 = undefined;
                debugLog(std.fmt.bufPrint(&exit_log, "WM_APP_SHELL_EXITED id={d} kind={s} reason={s} exit_code={d} known={}", .{ exited_id, @tagName(k), @tagName(action), exit_code, got_code }) catch "WM_APP_SHELL_EXITED log-overflow");
                switch (action) {
                    .respawn => {
                        if (!respawnShellInPlace(idx, false)) {
                            debugLog("respawnShellInPlace returned false — preserving disconnected SSH/tmux tab");
                            markSshTabDisconnected(idx);
                        }
                    },
                    .preserve => {
                        if (is_ssh_kind) {
                            markSshTabDisconnected(idx);
                        } else {
                            markPinnedLocalTabDisconnected(idx);
                        }
                    },
                    .close => {
                        logSessionAuditAlways("tab-closed:shell-exited");
                        closeShell(idx);
                    },
                }
            } else {
                var exit_log: [160]u8 = undefined;
                debugLog(std.fmt.bufPrint(&exit_log, "WM_APP_SHELL_EXITED id={d} reason=removed-or-detached exit_code=unknown", .{exited_id}) catch "WM_APP_SHELL_EXITED log-overflow");
            }
            return 0;
        },
        @import("win32.zig").WM_TIMECHANGE => {
            @import("chat_send.zig").sshReconnectArm(null, "time-change");
            return 0;
        },
        WM_POWERBROADCAST => {
            switch (wp) {
                PBT_APMSUSPEND => {
                    saveSession();
                    debugLog("WM_POWERBROADCAST: suspending — session snapshot saved");
                },
                PBT_APMRESUMESUSPEND, PBT_APMRESUMEAUTOMATIC => {
                    app_state.g_resume_until_tick = GetTickCount64() + RESUME_RESPAWN_WINDOW_MS;
                    _ = KillTimer(hwnd, TIMER_RESUME_RECONNECT);
                    _ = SetTimer(hwnd, TIMER_RESUME_RECONNECT, 2500, null);
                    uninstallHook();
                    installHook();
                    syncMouseHookForUrlClicks();
                    app_state.g_last_kb_hook_tick = GetTickCount64();
                    app_state.g_last_mouse_hook_tick = GetTickCount64();
                    @import("chat_send.zig").sshReconnectArm(null, "power-resume");
                    debugLog("WM_POWERBROADCAST: resumed — SSH reconnect timer armed, hooks reinstalled");
                    refreshPowerStatusFromSystem();
                    applyPowerProfile(hwnd);
                },
                PBT_POWERSETTINGCHANGE => {
                    if (lp != 0) {
                        const setting: *const POWERBROADCAST_SETTING = @ptrFromInt(@as(usize, @bitCast(lp)));
                        const data0: u8 = if (setting.DataLength >= 1) setting.Data[0] else 0;
                        if (guidEql(setting.PowerSetting, GUID_ACDC_POWER_SOURCE)) {
                            app_state.g_power_on_battery = data0 == 1;
                        } else if (guidEql(setting.PowerSetting, GUID_POWER_SAVING_STATUS)) {
                            app_state.g_power_energy_saver = data0 != 0;
                        } else if (guidEql(setting.PowerSetting, GUID_CONSOLE_DISPLAY_STATE)) {
                            app_state.g_power_display_off = data0 == 0;
                            if (!app_state.g_power_display_off) {
                                @import("chat_send.zig").sshReconnectArm(null, "standby-display-on");
                                exitDeepIdleNow(hwnd);
                            }
                        }
                        applyPowerProfile(hwnd);
                        var tbuf: [256]u16 = undefined;
                        _ = SetWindowTextW(hwnd, buildWindowTitle(&tbuf));
                    }
                },
                else => {},
            }
            return 1;
        },
        WM_ACTIVATEAPP => {
            if (wp == 0) {
                @import("diagnostics.zig").focusTrace(.activateapp_inactive, GetForegroundWindow(), 0);
                hideBrowserEdgeMasks();
            } else {
                focusGuardNoteActivation();
                updateCardPoll();
                updateBrowserVisibility();
                if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_enabled) {
                    armBrowserEdgeMaskRaise();
                }
                if (focusGuardComposerRepairAllowed()) _ = SetFocus(app_state.g_chat_composer_hwnd);
            }
            if (activePaneBorderOn() or chatViewOwnsInput()) {
                _ = InvalidateRect(hwnd, null, 0);
                invalidateBrowserBottomMask();
            }
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
        0x0006 => {
            const active = @as(u16, @truncate(wp));
            if (active == 0) @import("diagnostics.zig").focusTrace(.activate_inactive, @ptrFromInt(@as(usize, @bitCast(lp))), 0);
            if (active != 0) {
                focusGuardNoteActivation();
                exitDeepIdleNow(hwnd);
                _ = KillTimer(hwnd, TIMER_HOOK_UNINSTALL);
                forceReinstallHooksThrottled();
                syncMouseHookForUrlClicks();
                updateBrowserVisibility();
                clearSelectedTabDotOnReturn();
                if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_enabled) {
                    armBrowserEdgeMaskRaise();
                }
                const alt_down = (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
                if (focusGuardComposerRepairAllowed()) {
                    _ = SetFocus(app_state.g_chat_composer_hwnd);
                    altqLog("composer_focus site=activate pending={} handoff_left={} chat={}", .{ app_state.g_native_browser_focus_pending_shell_id, app_state.g_chat_browser_handoff_until -| GetTickCount64(), app_state.g_chat_active });
                } else if (app_state.shell_count > 0 and app_state.g_edit_hwnd == null and !app_state.g_search_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and !app_state.g_snippet_create_active) {
                    app_state.g_refocus_waiting_for_alt_release = alt_down;
                    requestShellRefocus(if (alt_down) 80 else 120, if (alt_down) 40 else 6);
                }
            } else {
                updateBrowserVisibility();
                hideBrowserEdgeMasks();
                if (systemAltTabSuppressionActive() or GetTickCount64() >= app_state.g_ws_switch_focus_grace) {
                    cancelShellRefocus(hwnd);
                    _ = SetTimer(hwnd, TIMER_HOOK_UNINSTALL, 150, null);
                }
            }
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
        WM_SETFOCUS => {
            const allowed = focusGuardComposerRepairAllowed();
            if (allowed) _ = SetFocus(app_state.g_chat_composer_hwnd);
            altqLog("composer_focus site=setfocus allowed={} pending={} focus={X} chat={}", .{ allowed, app_state.g_native_browser_focus_pending_shell_id, altqPtr(GetFocus()), app_state.g_chat_active });
            return DefWindowProcW(hwnd, msg, wp, lp);
        },
        WM_PARENTNOTIFY => {
            const child_msg = @as(u32, @truncate(wp));
            if (child_msg == WM_LBUTTONDOWN) {
                forceReinstallHooksThrottled();
                syncMouseHookForUrlClicks();
                if (webView2OwnsActiveShell() and (cursorInsideWebView2() or webView2HasInputFocus())) {
                    requestWebView2Focus();
                    return 0;
                }
                app_state.g_browser_focus_mode = false;
                app_state.g_shell_focused = true;
                focusActiveShell();
                clearSelectedTabDotOnReturn();
            }
            return 0;
        },
        WM_TIMER => {
            if (wp == app_state.TIMER_VISIT_DWELL) {
                sessionFrontChanged();
                recordFrontVisit();
                return 0;
            }
            if (wp == TIMER_SHOT_FOCUS) {
                shotFocusTick();
                return 0;
            }
            if (wp == TIMER_CHAT_BENCH and chatBenchEnabled()) {
                chatBenchTick();
                return 0;
            }
            if (wp == TIMER_FONT_SYNC) {
                fontSyncTimerTick(hwnd);
                return 0;
            }
            if (wp == TIMER_UPDATE_CHECK) {
                updateCardPoll();
                return 0;
            }
            if (wp == TIMER_CHAT_AC_DEBOUNCE) {
                _ = KillTimer(hwnd, TIMER_CHAT_AC_DEBOUNCE);
                if (app_state.g_chat_ac.open) {
                    const slot = &app_state.g_chat_ac_slots[app_state.g_chat_ac.slot];
                    if (!slot.retry_used and slot.pending == 0 and (slot.status == .stale or slot.status == .loading)) {
                        slot.retry_used = true;
                        chatAcRequest(app_state.g_chat_ac.slot);
                    }
                }
                return 0;
            }
            if (wp == TIMER_CHAT_BROWSER_SWAP) {
                chatSwitchBrowserTick();
                return 0;
            }
            if (wp == @import("win32.zig").TIMER_CHAT_WORKING) {
                @import("window_layout.zig").chatWorkingBarTick();
                return 0;
            }
            if (wp == app_state.TIMER_CHAT_FIND) {
                @import("chat_find_ui.zig").tick();
                return 0;
            }
            if (wp == TIMER_CHAT_REFRESH) {
                if (app_state.g_chat_browser_swap.shell_id != 0) return 0;
                if (app_state.g_chat_active or app_state.g_voice_mode_active) {
                    if (!app_state.g_voice_mode_active and (IsIconic(hwnd) != 0 or IsWindowVisible(hwnd) == 0)) return 0;
                    chatFileOnReady();
                    if (app_state.g_chat_active) {
                        refreshChatTranscript(false);
                        if (browserSlotReserved() != app_state.g_chat_layout_browser_reserved) {
                            layoutChatControls();
                            _ = InvalidateRect(hwnd, null, 0);
                        }
                    }
                    if (app_state.g_chat_active) chatWorkingIndicatorSync();
                    if (app_state.g_voice_mic_start_pending and !app_state.g_dictation_capturing.load(.acquire) and app_state.g_voice_mode_active and app_state.g_voice_always_listen) voiceMicStart();
                    voiceCheckScreenFallback();
                    if (app_state.g_voice_mode_active and app_state.g_voice_always_listen) {
                        const now = GetTickCount64();
                        const speaking = app_state.g_voice_state == .speaking or app_state.g_voice_tts_audible.load(.acquire);
                        const working = app_state.g_chat_screen_working;
                        app_state.g_voice_last_activity_tick = duplex.voiceQuietTick(now, app_state.g_voice_last_activity_tick, working, speaking);
                        if (duplex.voiceShouldAutoOff(true, working, speaking, now -| app_state.g_voice_last_activity_tick)) {
                            dictationAudit("voice-duplex-autooff", 600000);
                            setVoiceModeActive(false);
                            showHeaderNoticeAscii("Voice Mode off after 10 quiet minutes", 4000, false);
                        }
                    }
                    _ = SetTimer(hwnd, TIMER_CHAT_REFRESH, @as(UINT, 750), null);
                    if (!app_state.g_chat_sel_dragging and chatComposerFocusAllowed() and chatFocusDrifted()) {
                        _ = SetFocus(app_state.g_chat_composer_hwnd);
                        altqLog("composer_focus site=refresh pending={} handoff_left={} focus={X}", .{ app_state.g_native_browser_focus_pending_shell_id, app_state.g_chat_browser_handoff_until -| GetTickCount64(), altqPtr(GetFocus()) });
                    }
                } else {
                    _ = KillTimer(hwnd, TIMER_CHAT_REFRESH);
                }
                return 0;
            }
            if (wp == TIMER_CHAT_FOREGROUND_RETRY) {
                if (!focusGuard(app_state.g_chat_composer_hwnd)) {
                    _ = KillTimer(hwnd, TIMER_CHAT_FOREGROUND_RETRY);
                    return 0;
                }
                const alt_held = (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
                if (app_state.g_chat_foreground_retries > 0) app_state.g_chat_foreground_retries -= 1;
                altqLog("chat_retry tick rem={} fg={X} main_fg={} alt={} ctrl={} chat={} mode={} fg_ours={}", .{ app_state.g_chat_foreground_retries, altqPtr(GetForegroundWindow()), app_state.g_main_hwnd != null and GetForegroundWindow() == app_state.g_main_hwnd, alt_held, isCtrlDown(), app_state.g_chat_active, app_state.g_browser_focus_mode, foregroundIsOurs() });
                if (GetForegroundWindow() == app_state.g_main_hwnd or app_state.g_chat_foreground_retries == 0 or
                    !app_state.g_chat_active or app_state.g_browser_focus_mode or !foregroundIsOurs())
                {
                    _ = KillTimer(hwnd, TIMER_CHAT_FOREGROUND_RETRY);
                    if (GetForegroundWindow() == app_state.g_main_hwnd and chatComposerFocusAllowed()) _ = SetFocus(app_state.g_chat_composer_hwnd);
                    altqLog("composer_focus site=retry stop fg={X} allowed={} rem={}", .{ altqPtr(GetForegroundWindow()), chatComposerFocusAllowed(), app_state.g_chat_foreground_retries });
                    return 0;
                }
                if (alt_held or isCtrlDown()) return 0;
                keybd_event(VK_MENU, 0, 0, 0);
                _ = SetForegroundWindow(app_state.g_main_hwnd);
                keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);
                return 0;
            }
            if (wp == TIMER_CHAT_SEND_VERIFY) {
                _ = KillTimer(hwnd, TIMER_CHAT_SEND_VERIFY);
                chatSendVerifyTick();
                return 0;
            }
            if (wp == TIMER_CHAT_DRAFT) {
                chatDraftFlush();
                return 0;
            }
            if (wp == TIMER_CHAT_OUTBOX) {
                chatOutboxTick();
                return 0;
            }
            if (wp == TIMER_SSH_RECONNECT) {
                sshAutoReconnectTick();
                return 0;
            }
            if (wp == TIMER_VOICE_TURN_END) {
                _ = KillTimer(hwnd, TIMER_VOICE_TURN_END);
                voiceOnTurnEnd(app_state.g_voice_pending_turn_shell_id);
                return 0;
            }
            if (wp == TIMER_VOICE_POLL) {
                if ((!app_state.g_voice_replay_only and !app_state.g_voice_mode_active) or app_state.g_voice_state != .speaking) {
                    _ = KillTimer(hwnd, TIMER_VOICE_POLL);
                    app_state.g_voice_replay_only = false;
                    return 0;
                }
                if (app_state.active_shell >= app_state.shell_count or app_state.shells[app_state.active_shell].shell_id != app_state.g_voice_speaking_shell_id) {
                    dictationAudit("voice-stop", 2);
                    voiceStopSpeaking();
                    if (!app_state.g_voice_mode_active) voiceTtsDeviceStop();
                    app_state.g_voice_state = .idle;
                    app_state.g_voice_replay_only = false;
                    _ = KillTimer(hwnd, TIMER_VOICE_POLL);
                    invalidateChatHeader();
                    return 0;
                }
                if (!voiceIsSpeaking()) {
                    dictationAudit("voice-tts-done", 0);
                    _ = KillTimer(hwnd, TIMER_VOICE_POLL);
                    app_state.g_voice_tts_audible.store(false, .release);
                    app_state.g_voice_highlight = null;
                    if (app_state.g_chat_transcript_hwnd != null) _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
                    app_state.g_voice_tts_quiet_since.store(GetTickCount64(), .release);
                    if (app_state.g_voice_replay_only) {
                        app_state.g_voice_replay_only = false;
                        if (!app_state.g_voice_mode_active) {
                            voiceTtsDeviceStop();
                            app_state.g_voice_state = .idle;
                            invalidateChatHeader();
                        } else if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].activity == .active) {
                            app_state.g_voice_state = .waiting;
                            invalidateChatHeader();
                        } else if (app_state.g_voice_always_listen and !app_state.g_voice_mic_failed) {
                            app_state.g_voice_state = .idle;
                            invalidateChatHeader();
                        } else voiceStartListening();
                    } else if (app_state.g_voice_always_listen and !app_state.g_voice_mic_failed) {
                        app_state.g_voice_state = .idle;
                        invalidateChatHeader();
                    } else voiceStartListening();
                }
                return 0;
            }
            if (wp == TIMER_VOICE_TTS_POS) {
                _ = KillTimer(hwnd, TIMER_VOICE_TTS_POS);
                if (app_state.g_voice_tts_wave_out) |hw| {
                    var mmt: MMTIME = std.mem.zeroes(MMTIME);
                    mmt.wType = TIME_BYTES;
                    const pos_mmr = waveOutGetPosition(hw, &mmt, @sizeOf(MMTIME));
                    if (pos_mmr != 0) dictationAudit("voice-tts-pos-mmresult", pos_mmr);
                    const got_position = pos_mmr == 0 and mmt.wType == TIME_BYTES;
                    dictationAudit("voice-tts-pos-1s", if (got_position) mmt.u.cb else 0);
                }
                return 0;
            }
            if (wp == TIMER_BROWSER_ENGINE_SWITCH) {
                finishBrowserEngineSwitch(hwnd);
                return 0;
            }
            if (wp == TIMER_SYSTEM_THEME) {
                refreshSystemTheme(hwnd);
                return 0;
            }
            if (wp == TIMER_INBOX_PUBLISH) {
                _ = KillTimer(hwnd, TIMER_INBOX_PUBLISH);
                publishInboxStateNow();
                if (app_state.g_session_save_pending) {
                    app_state.g_session_save_pending = false;
                    saveSession();
                }
                return 0;
            }
            if (wp == TIMER_POWER_IDLE) {
                evaluateDeepIdle(hwnd);
                return 0;
            }
            if (wp == TIMER_TUNNEL_KEEPER) {
                maintainTunnelKeepers();
                return 0;
            }
            if (wp == TIMER_UNARCHIVE_UNATTACHED) {
                unarchiveNextUnattachedSession(hwnd);
                return 0;
            }
            if (wp == TIMER_NATIVE_BROWSER_FOCUS) {
                const pending_sid = app_state.g_native_browser_focus_pending_shell_id;
                if (pending_sid == 0 or app_state.active_shell >= app_state.shell_count or
                    app_state.shells[app_state.active_shell].shell_id != pending_sid or
                    !foregroundIsOurs())
                {
                    altqLog("timer_gate cancel pending={} active_sid={} fg_ours={} fg={X} chat={}", .{ pending_sid, if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].shell_id else 0, foregroundIsOurs(), altqPtr(GetForegroundWindow()), app_state.g_chat_active });
                    cancelPendingNativeBrowserFocus();
                    app_state.g_browser_focus_mode = false;
                    app_state.g_shell_focused = true;
                    return 0;
                }
                const alt_down = (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
                if (alt_down) altqLog("timer_alt waiting retries={} chat={} pane_fg={}", .{ app_state.g_native_browser_focus_retries, app_state.g_chat_active, activeBrowserHasForegroundFocus() });
                if (alt_down) return 0;

                if (activeBrowserHasForegroundFocus()) {
                    altqLog("timer_focused ok fg={X} chat={}", .{ altqPtr(GetForegroundWindow()), app_state.g_chat_active });
                    cancelPendingNativeBrowserFocus();
                    app_state.g_browser_focus_mode = true;
                    app_state.g_shell_focused = false;
                    return 0;
                }
                if (activeBrowserHwndLive() == null) {
                    if (app_state.g_native_browser_focus_retries > 0) app_state.g_native_browser_focus_retries -= 1;
                    if (app_state.g_native_browser_focus_retries % 100 == 0 or app_state.g_native_browser_focus_retries == 0) altqLog("timer_no_pane waiting retries={} chat={} enabled={}", .{ app_state.g_native_browser_focus_retries, app_state.g_chat_active, app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_enabled });
                    if (app_state.g_native_browser_focus_retries == 0) {
                        cancelPendingNativeBrowserFocus();
                        app_state.g_browser_focus_mode = false;
                        app_state.g_shell_focused = true;
                        showHeaderNoticeAscii("Browser focus failed", 2500, false);
                    }
                    return 0;
                }

                focusActiveBrowserPane();
                if (activeBrowserHasForegroundFocus()) {
                    cancelPendingNativeBrowserFocus();
                    app_state.g_browser_focus_mode = true;
                    app_state.g_shell_focused = false;
                } else {
                    altqLog("pane_hop failed attempt fg={X} attempts={} chat={} chat_owns={}", .{ altqPtr(GetForegroundWindow()), app_state.g_native_browser_focus_attempts, app_state.g_chat_active, chatViewOwnsInput() });
                    if (app_state.g_native_browser_focus_attempts > 0) app_state.g_native_browser_focus_attempts -= 1;
                    if (app_state.g_native_browser_focus_attempts == 0) {
                        cancelPendingNativeBrowserFocus();
                        app_state.g_browser_focus_mode = false;
                        app_state.g_shell_focused = true;
                        showHeaderNoticeAscii("Browser focus failed", 2500, false);
                    }
                }
                return 0;
            }
            if (wp == TIMER_WEBVIEW2_FOCUS) {
                if (!webView2OwnsActiveShell() or app_state.g_webview2_focus_retries == 0) {
                    app_state.g_webview2_focus_retries = 0;
                    _ = KillTimer(hwnd, TIMER_WEBVIEW2_FOCUS);
                    return 0;
                }
                focusActiveWebView2();
                if (webView2HasInputFocus()) {
                    app_state.g_webview2_focus_retries = 0;
                    _ = KillTimer(hwnd, TIMER_WEBVIEW2_FOCUS);
                } else {
                    app_state.g_webview2_focus_retries -= 1;
                }
                return 0;
            }
            if (wp == TIMER_MONITOR_TRANSITION) {
                monitorTransitionTick(hwnd);
                return 0;
            }
            if (wp == TIMER_CONSOLE_GEOMETRY_SETTLE) {
                settleConsoleGeometry(hwnd);
                app_state.g_console_geometry_settle_ticks -= 1;
                if (app_state.g_console_geometry_settle_ticks <= 0) {
                    app_state.g_console_geometry_settle_ticks = 0;
                    _ = KillTimer(hwnd, TIMER_CONSOLE_GEOMETRY_SETTLE);
                }
                return 0;
            }
            if (wp == TIMER_FONT_HUD) {
                _ = KillTimer(hwnd, TIMER_FONT_HUD);
                app_state.g_dev_font_hud = false;
                var tbuf: [256]u16 = undefined;
                _ = SetWindowTextW(hwnd, buildWindowTitle(&tbuf));
                return 0;
            }
            if (wp == TIMER_CAP_MSG) {
                _ = KillTimer(hwnd, TIMER_CAP_MSG);
                _ = InvalidateRect(hwnd, null, 0);
                return 0;
            }
            if (wp == TIMER_BROWSER_HEALTH) {
                browserHealthTick();
                browserHibernationTick();
                return 0;
            }
            if (wp == TIMER_BROWSER_PLACEHOLDER) {
                _ = KillTimer(hwnd, TIMER_BROWSER_PLACEHOLDER);
                if (browserSlotReserved() and !browserPaneCoversSlot()) {
                    if (browserPlaceholderRect()) |prc| {
                        var inv = prc;
                        _ = InvalidateRect(hwnd, &inv, 0);
                    }
                } else {
                    _ = KillTimer(hwnd, TIMER_BROWSER_PLACEHOLDER);
                }
                return 0;
            }
            if (wp == TIMER_BROWSER_ADOPT) {
                adoptBrowserTick();
                return 0;
            }
            if (wp == TIMER_BROWSER_SETTLE) {
                if (app_state.g_chat_browser_swap.shell_id != 0) return 0;
                browserTraceN("settleTick rem=", app_state.g_browser_settle_ticks);
                if (!browserChromeForegroundAllowed()) {
                    if ((app_state.g_main_hwnd != null and IsIconic(app_state.g_main_hwnd) != 0) or browserChromeHiddenForOverlay()) {
                        hideAllBrowserChrome();
                    }
                    app_state.g_browser_settle_ticks -= 1;
                    if (app_state.g_browser_settle_ticks <= 0) {
                        _ = KillTimer(hwnd, TIMER_BROWSER_SETTLE);
                    }
                    return 0;
                }
                repositionActive();
                updateBrowserVisibility();
                chatSwitchLogBrowserShown();
                app_state.g_browser_settle_ticks -= 1;
                if (app_state.g_browser_settle_ticks <= 0) {
                    _ = KillTimer(hwnd, TIMER_BROWSER_SETTLE);
                    if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_window_id != 0) {
                        _ = SetTimer(hwnd, TIMER_BROWSER_URL_POLL, 2000, null);
                    }
                }
                return 0;
            }
            if (wp == TIMER_BROWSER_URL_POLL) {
                if (app_state.g_chat_browser_swap.shell_id != 0) return 0;
                pollBrowserUrlTick();
                return 0;
            }
            if (wp == TIMER_BROWSER_EDGE_MASK_RAISE) {
                if (app_state.g_chat_browser_swap.shell_id != 0) return 0;
                if (activeBrowserTransientPopupHasForegroundFocus()) {
                    browserTrace("maskRaiseTick suspended for Edge popup");
                    suspendBrowserEdgeMaskRaiseForPopup();
                    return 0;
                }
                if (!browserChromeCanStayVisible()) {
                    hideBrowserEdgeMasks();
                    return 0;
                }
                browserTrace("maskRaiseTick z-only");
                raiseBrowserEdgeMasksZOrderOnly();
                app_state.g_browser_edge_mask_raise_ticks -= 1;
                if (app_state.g_browser_edge_mask_raise_ticks <= 0) {
                    app_state.g_browser_edge_mask_raise_ticks = 0;
                    _ = KillTimer(hwnd, TIMER_BROWSER_EDGE_MASK_RAISE);
                }
                return 0;
            }
            if (wp == TIMER_NAME_POLL) {
                if (app_state.g_power_deep_idle) {
                    sweepIdleBrowserPanes();
                    checkDueReminders();
                    return 0;
                }
                _ = hideBrowserChromeIfNotForeground();
                pollShellNames();
                sweepIdleBrowserPanes();
                checkDueReminders();
                hookWatchdog();
            } else if (wp == TIMER_VPS_CAPACITY) {
                ensureVpsPollLeadership();
                if (app_state.g_vps_poll_is_leader) {
                    fetchTmuxSessions();
                } else {
                    loadVpsPollCacheIfChanged();
                }
            } else if (wp == TIMER_AI_PACE) {
                requestAiPaceRefresh();
            } else if (wp == TIMER_SPINNER) {
                const now_tick = GetTickCount64();
                var any_active = false;
                var any_expired = false;
                for (0..app_state.shell_count) |i| {
                    if (app_state.shells[i].muted or app_state.shells[i].activity != .active) continue;
                    if (app_state.shells[i].last_active_event == 0) {
                        app_state.shells[i].activity = .idle;
                        app_state.shells[i].needs_attention = false;
                        recordShellDiagEvent(i, "stale-expire-clear", "no-active-tick");
                        if (app_state.g_voice_mode_active and i == app_state.active_shell) voiceScheduleTurnEnd(app_state.shells[i].shell_id);
                        any_expired = true;
                        continue;
                    }
                    if ((now_tick -% app_state.shells[i].last_active_event) > SPINNER_STALE_MS) {
                        app_state.shells[i].activity = .idle;
                        app_state.shells[i].last_active_event = 0;
                        app_state.shells[i].needs_attention = false;
                        recordShellDiagEvent(i, "stale-expire-clear", "timeout");
                        if (app_state.g_voice_mode_active and i == app_state.active_shell) voiceScheduleTurnEnd(app_state.shells[i].shell_id);
                        any_expired = true;
                        continue;
                    }
                    any_active = true;
                }
                if (any_expired) {
                    publishInboxState();
                    invalidateSidebar();
                }
                if (!any_active) {
                    _ = KillTimer(hwnd, TIMER_SPINNER);
                    app_state.g_spinner_running = false;
                    invalidateSidebar();
                    return 0;
                }
                app_state.g_spinner_frame +%= 1;
                invalidateSpinnerRects();
            } else if (wp == TIMER_ETA_REPAINT) {
                if (!anyShellHasEta()) {
                    _ = KillTimer(hwnd, TIMER_ETA_REPAINT);
                    app_state.g_eta_timer_running = false;
                    return 0;
                }
                invalidateSidebar();
            } else if (wp == TIMER_REFOCUS) {
                _ = KillTimer(hwnd, TIMER_REFOCUS);
                if (!focusGuard(if (app_state.g_chat_active) app_state.g_chat_composer_hwnd else activeShellHwndForFocusGuard())) {
                    cancelShellRefocus(hwnd);
                    return 0;
                }
                if (app_state.g_popup_menu_active or app_state.g_move_size_active) {
                    cancelShellRefocus(hwnd);
                    return 0;
                }
                const mouse_down = (GetAsyncKeyState(0x01) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
                const alt_held = (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
                const chord_held = alt_held or isCtrlDown();
                const now_tick = GetTickCount64();
                const inbox_force = now_tick < app_state.g_inbox_shell_focus_until;
                if (now_tick < app_state.g_system_alt_tab_until and !foregroundIsOurs()) {
                    cancelShellRefocus(hwnd);
                    return 0;
                }
                var retry = false;
                var retry_delay: UINT = 250;
                const ours_now = foregroundIsOurs();
                if (chord_held) {
                    app_state.g_refocus_waiting_for_alt_release = true;
                    if (ours_now and app_state.g_refocus_remaining > 0) {
                        app_state.g_refocus_remaining -= 1;
                        retry = true;
                        retry_delay = 80;
                    } else {
                        cancelShellRefocus(hwnd);
                    }
                } else if (app_state.g_refocus_waiting_for_alt_release) {
                    app_state.g_refocus_waiting_for_alt_release = false;
                    if (ours_now and app_state.g_refocus_remaining > 0) {
                        app_state.g_refocus_remaining -= 1;
                        retry = true;
                        retry_delay = 120;
                    } else {
                        cancelShellRefocus(hwnd);
                    }
                } else if ((app_state.g_shell_focused or inbox_force) and ours_now and app_state.shell_count > 0 and !mouse_down and app_state.g_edit_hwnd == null and !app_state.g_search_active and !app_state.g_changelog_active and !app_state.g_url_picker_active and !app_state.g_snippet_create_active) {
                    if (app_state.g_chat_active) altqLog("refocus_chat steal pending={} handoff_left={} rem={} fg={X} chat_owns={}", .{ app_state.g_native_browser_focus_pending_shell_id, app_state.g_chat_browser_handoff_until -| GetTickCount64(), app_state.g_refocus_remaining, altqPtr(GetForegroundWindow()), chatViewOwnsInput() });
                    focusActiveShell();
                    const landed = activeShellHasForegroundFocus() or
                        (app_state.g_chat_active and app_state.g_chat_composer_hwnd != null and GetForegroundWindow() == app_state.g_main_hwnd and GetFocus() == app_state.g_chat_composer_hwnd);
                    if (verboseLoggingEnabled()) {
                        var lb: [96]u8 = undefined;
                        const kn: u32 = if (app_state.active_shell < app_state.shell_count) @intFromEnum(app_state.shells[app_state.active_shell].kind) else 255;
                        const s = std.fmt.bufPrint(&lb, "refocus tick kind={d} landed={d} rem={d}", .{ kn, @as(u8, if (landed) 1 else 0), app_state.g_refocus_remaining }) catch "refocus tick";
                        debugLog(s);
                    }
                    if (landed and inbox_force and app_state.g_refocus_remaining > 0) {
                        app_state.g_refocus_remaining -= 1;
                        retry = true;
                        retry_delay = 100;
                    } else if (landed) {
                        app_state.g_refocus_remaining = 0;
                    } else if (app_state.g_refocus_remaining > 0) {
                        app_state.g_refocus_remaining -= 1;
                        retry = true;
                    }
                } else {
                    cancelShellRefocus(hwnd);
                }
                if (retry) {
                    _ = SetTimer(hwnd, TIMER_REFOCUS, retry_delay, null);
                } else if (!inbox_force) {
                    app_state.g_inbox_shell_focus_until = 0;
                }
            } else if (wp == TIMER_HOOK_UNINSTALL) {
                _ = KillTimer(hwnd, TIMER_HOOK_UNINSTALL);
                if (GetTickCount64() < app_state.g_ws_switch_focus_grace or app_state.g_refocus_waiting_for_alt_release or app_state.g_refocus_remaining > 0) {
                    _ = SetTimer(hwnd, TIMER_HOOK_UNINSTALL, 300, null);
                    return 0;
                }
                const is_ours = foregroundIsOurs();
                if (!is_ours and !app_state.g_search_active) {
                    uninstallKeyboardHook();
                }
                syncMouseHookForUrlClicks();
            } else if (wp == TIMER_RESUME_RECONNECT) {
                _ = KillTimer(hwnd, TIMER_RESUME_RECONNECT);
                forceReinstallHooks();
                debugLog("TIMER_RESUME_RECONNECT: delayed hooks reinstalled");
            } else if (wp == TIMER_REMINDERS) {
                checkDueReminders();
            } else if (wp == TIMER_INBOX_REFRESH) {
                if (app_state.g_all_sessions_active) {
                    var sel_kind: SessionOverviewKind = .open;
                    var sel_shell_id: u32 = 0;
                    var sel_snapshot_ref: ?u32 = null;
                    var sel_snapshot_order: ?u32 = null;
                    var sel_session: [64]u8 = std.mem.zeroes([64]u8);
                    var sel_session_len: u32 = 0;
                    var have_sel = false;
                    if (allSessionsNthVisible(app_state.g_all_sessions_sel)) |sri| {
                        const row = &app_state.g_session_overview_rows.items[sri];
                        sel_kind = row.kind;
                        sel_shell_id = row.shell_id;
                        if (row.kind == .reminder and row.ref_idx < app_state.g_reminder_count and app_state.g_reminders[row.ref_idx].snapshot) {
                            sel_snapshot_ref = row.ref_idx;
                            sel_snapshot_order = row.snapshot_order;
                        }
                        sel_session_len = row.session_len;
                        if (sel_session_len > 0) @memcpy(sel_session[0..sel_session_len], row.session[0..sel_session_len]);
                        have_sel = true;
                    }
                    buildSessionOverviewRows();
                    if (!allSessionsSplitVisible(app_state.g_all_sessions_tab)) app_state.g_all_sessions_tab = AS_TAB_ALL;
                    var resel = false;
                    if (have_sel) {
                        var c: u32 = 0;
                        for (0..app_state.g_session_overview_count) |i| {
                            const row = &app_state.g_session_overview_rows.items[i];
                            if (!allSessionsRowVisible(row)) continue;
                            const same_shell = sel_shell_id != 0 and row.shell_id == sel_shell_id;
                            const same_snapshot = sel_snapshot_ref != null and row.kind == .reminder and row.ref_idx == sel_snapshot_ref.? and row.snapshot_order == sel_snapshot_order;
                            const same_session = sel_session_len > 0 and row.kind == sel_kind and row.session_len == sel_session_len and std.ascii.eqlIgnoreCase(row.session[0..row.session_len], sel_session[0..sel_session_len]);
                            if (same_shell or same_snapshot or (sel_snapshot_ref == null and same_session)) {
                                app_state.g_all_sessions_sel = c;
                                resel = true;
                                break;
                            }
                            c += 1;
                        }
                    }
                    if (!resel) {
                        const sv = allSessionsVisibleCount();
                        if (app_state.g_all_sessions_sel >= sv) app_state.g_all_sessions_sel = if (sv > 0) sv - 1 else 0;
                    }
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (app_state.g_starred_workspace and !app_state.g_inbox_active) {
                    loadInboxModel();
                    @import("workspaces.zig").refreshStarredWorkspace();
                    _ = InvalidateRect(hwnd, null, 0);
                    return 0;
                }
                if (!app_state.g_inbox_active) {
                    _ = KillTimer(hwnd, TIMER_INBOX_REFRESH);
                    return 0;
                }
                var sel_hwnd: usize = 0;
                var sel_sid: u32 = 0;
                var have_sel = false;
                if (inboxNthVisible(app_state.g_inbox_sel)) |sri| {
                    sel_hwnd = app_state.g_inbox_ws[app_state.g_inbox_rows[sri].ws].hwnd;
                    sel_sid = app_state.g_inbox_rows[sri].sid;
                    have_sel = true;
                }
                loadInboxModel();
                if (app_state.g_inbox_tab > frequent.splitCount(app_state.g_inbox_ws_count) - 1) app_state.g_inbox_tab = @import("inbox.zig").firstInboxSplit();
                if (!inboxSplitVisible(app_state.g_inbox_tab)) app_state.g_inbox_tab = @import("inbox.zig").firstInboxSplit();
                var resel = false;
                if (have_sel) {
                    var c: u32 = 0;
                    for (0..app_state.g_inbox_row_count) |i| {
                        if (!inboxRowVisible(&app_state.g_inbox_rows[i])) continue;
                        if (app_state.g_inbox_ws[app_state.g_inbox_rows[i].ws].hwnd == sel_hwnd and app_state.g_inbox_rows[i].sid == sel_sid) {
                            app_state.g_inbox_sel = c;
                            resel = true;
                            break;
                        }
                        c += 1;
                    }
                }
                if (!resel) {
                    const ivis = inboxVisibleCount();
                    if (app_state.g_inbox_sel >= ivis) app_state.g_inbox_sel = if (ivis > 0) ivis - 1 else 0;
                }
                _ = InvalidateRect(hwnd, null, 0);
            } else if (wp == TIMER_SYSMENU) {
                _ = KillTimer(hwnd, TIMER_SYSMENU);
                const sm_fg_ours = GetForegroundWindow() == hwnd;
                if (verboseLoggingEnabled()) {
                    var lbuf: [96]u8 = undefined;
                    var lpos: usize = 0;
                    const pre = "sysmenu-retry: fg_ours=";
                    @memcpy(lbuf[0..pre.len], pre);
                    lpos = pre.len;
                    lbuf[lpos] = if (sm_fg_ours) '1' else '0';
                    lpos += 1;
                    const s2 = " count=";
                    @memcpy(lbuf[lpos .. lpos + s2.len], s2);
                    lpos += s2.len;
                    appendDecimal(&lbuf, &lpos, app_state.g_sysmenu_retry_count);
                    debugLog(lbuf[0..lpos]);
                }
                if (sm_fg_ours) {
                    const sysmenu2 = GetSystemMenu(hwnd, 0);
                    if (sysmenu2 != null) {
                        var wr2: RECT = std.mem.zeroes(RECT);
                        _ = GetWindowRect(hwnd, &wr2);
                        const cmd2 = TrackPopupMenu(sysmenu2, TPM_RETURNCMD | TPM_LEFTALIGN, wr2.left + 8, wr2.top + 32, 0, hwnd, null);
                        if (verboseLoggingEnabled()) {
                            var cbuf2: [64]u8 = undefined;
                            var cpos2: usize = 0;
                            const cp2 = "sysmenu-retry: trackpopup cmd=";
                            @memcpy(cbuf2[0..cp2.len], cp2);
                            cpos2 = cp2.len;
                            appendDecimal(&cbuf2, &cpos2, @intCast(@as(u32, @bitCast(cmd2))));
                            debugLog(cbuf2[0..cpos2]);
                        }
                        if (cmd2 != 0) {
                            _ = PostMessageW(hwnd, WM_SYSCOMMAND, @intCast(@as(u32, @bitCast(cmd2))), 0);
                        } else if (app_state.shell_count > 0) {
                            _ = SetTimer(hwnd, TIMER_REFOCUS, 100, null);
                        }
                    }
                } else if (app_state.g_sysmenu_retry_count < 8) {
                    app_state.g_sysmenu_retry_count += 1;
                    _ = SetTimer(hwnd, TIMER_SYSMENU, 30, null);
                } else {
                    debugLog("sysmenu: gave up — foreground claim failed after 8 retries (no menu shown)");
                }
            }
            return 0;
        },
        WM_COPYDATA => {
            const cds_ptr: ?*const COPYDATASTRUCT = @ptrFromInt(@as(usize, @bitCast(lp)));
            if (cds_ptr) |cds| {
                if (cds.dwData == COPYDATA_TAB_TRANSFER and cds.cbData == @sizeOf(TabTransfer)) {
                    if (cds.lpData) |data_ptr| {
                        const transfer: *const TabTransfer = @ptrCast(@alignCast(data_ptr));
                        if (transfer.tmux_len > 0 and transfer.tmux_len <= 63) {
                            if (findLocalTmuxTab(transfer.tmux_host, transfer.tmux[0..transfer.tmux_len])) |existing| {
                                switchToShell(existing);
                                return 0;
                            }
                        }
                        if (app_state.shell_count < MAX_SHELLS and @as(usize, @intCast(app_state.next_shell_id)) < SPAWN_TITLES.len) {
                            const adopt_h: HANDLE = @ptrFromInt(transfer.console_hwnd);

                            _ = ShowWindow(adopt_h, SW_HIDE);
                            _ = SetParent(adopt_h, app_state.g_main_hwnd);
                            var cds_style = GetWindowLongPtrW(adopt_h, GWL_STYLE);
                            cds_style &= ~@as(isize, @intCast(WS_CAPTION | WS_THICKFRAME | WS_BORDER));
                            cds_style |= @as(isize, @intCast(WS_CHILD));
                            _ = SetWindowLongPtrW(adopt_h, GWL_STYLE, cds_style);
                            _ = SetWindowPos(adopt_h, null, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOZORDER | SWP_NOMOVE | SWP_NOSIZE);

                            const proc = OpenProcess(0x001F0FFF, 0, transfer.pid);
                            if (proc == null) return 0;
                            if (app_state.g_job != null and proc != null) _ = AssignProcessToJobObject(app_state.g_job, proc);

                            var new_shell = empty_shell;
                            new_shell.hwnd = adopt_h;
                            new_shell.process = proc;
                            new_shell.pid = transfer.pid;
                            new_shell.kind = @enumFromInt(@as(u3, @intCast(transfer.kind)));
                            new_shell.name_source = @enumFromInt(@as(u3, @intCast(transfer.name_source)));
                            new_shell.muted = transfer.muted != 0;
                            new_shell.keep_alive = transfer.keep_alive != 0;
                            new_shell.pinned_top = transfer.pinned_top != 0;
                            new_shell.locked = transfer.locked != 0;
                            new_shell.favorite = transfer.favorite != 0;
                            new_shell.last_used = transfer.last_used;
                            new_shell.input = transfer.input;
                            new_shell.visits = transfer.visits;
                            new_shell.inbox_excluded = transfer.inbox_excluded != 0;
                            new_shell.claude_session = transfer.claude_session != 0;
                            new_shell.tmux_host = transfer.tmux_host;
                            new_shell.shell_id = app_state.next_shell_id;
                            app_state.next_shell_id += 1;

                            const nlen = @min(transfer.name_len, 63);
                            for (0..nlen) |ni| {
                                new_shell.name[ni] = @intCast(transfer.name[ni]);
                            }
                            new_shell.name_len = nlen;

                            const clen = @min(transfer.cwd_len, 511);
                            if (clen > 0) @memcpy(new_shell.cached_cwd[0..clen], transfer.cwd[0..clen]);
                            new_shell.cached_cwd_len = clen;

                            const tlen = @min(transfer.tmux_len, 63);
                            if (tlen > 0) @memcpy(new_shell.tmux_session[0..tlen], transfer.tmux[0..tlen]);
                            new_shell.tmux_session_len = tlen;

                            const flen = @min(transfer.favicon_path_len, 511);
                            if (flen > 0) @memcpy(new_shell.favicon_path[0..flen], transfer.favicon_path[0..flen]);
                            new_shell.favicon_path_len = flen;

                            if (transfer.group_id != 0) {
                                if (findGroupIdx(transfer.group_id) == null and app_state.group_count < MAX_GROUPS) {
                                    var gname: [64]u16 = std.mem.zeroes([64]u16);
                                    const glen = @min(transfer.group_name_len, 63);
                                    for (0..glen) |gi| gname[gi] = @intCast(transfer.group_name[gi]);
                                    app_state.groups[app_state.group_count] = .{
                                        .id = transfer.group_id,
                                        .name = gname,
                                        .name_len = glen,
                                        .collapsed = transfer.group_collapsed != 0,
                                        .color = transfer.group_color % @as(u8, @intCast(GROUP_COLORS.len)),
                                    };
                                    app_state.group_count += 1;
                                    if (transfer.group_id >= app_state.next_group_id) app_state.next_group_id = transfer.group_id + 1;
                                }
                                if (findGroupIdx(transfer.group_id) != null) new_shell.group_id = transfer.group_id;
                            }

                            app_state.shells[app_state.shell_count] = new_shell;
                            registerShellExitWait(app_state.shell_count);
                            app_state.shell_count += 1;
                            @import("chat_send.zig").armSshReconnectTimerIfNeeded();
                            if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].hwnd != null)
                                _ = ShowWindow(app_state.shells[app_state.active_shell].hwnd, SW_HIDE);
                            app_state.active_shell = app_state.shell_count - 1;
                            ensureActiveVisible();
                            _ = showShellConsole(app_state.active_shell, SW_SHOW, "wndProc.WM_COPYDATA");
                            repositionActive();
                            saveSession();
                            _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
                            _ = SetTimer(hwnd, TIMER_REFOCUS, 100, null);
                            return 1;
                        }
                    }
                }
            }
            return 0;
        },
        WM_CLOSE => {
            if (app_state.g_app_closing) return 0;
            app_state.g_app_closing = true;
            stopUpdateCardWatch();
            _ = KillTimer(hwnd, TIMER_BROWSER_HEALTH);
            _ = KillTimer(hwnd, TIMER_BROWSER_ENGINE_SWITCH);
            _ = KillTimer(hwnd, TIMER_TUNNEL_KEEPER);
            _ = KillTimer(hwnd, TIMER_BROWSER_ADOPT);
            _ = KillTimer(hwnd, TIMER_BROWSER_SETTLE);
            _ = KillTimer(hwnd, TIMER_BROWSER_URL_POLL);
            _ = KillTimer(hwnd, TIMER_BROWSER_EDGE_MASK_RAISE);
            logSessionAudit("WM_CLOSE:entry-before-save");
            commitRename();
            chatDraftFlush();

            var has_keep_alive = false;
            for (0..app_state.shell_count) |i| {
                if (app_state.shells[i].keep_alive and (app_state.shells[i].kind == .cmd or app_state.shells[i].kind == .pwsh)) {
                    has_keep_alive = true;
                    break;
                }
            }

            if (has_keep_alive) {
                debugLog("WM_CLOSE: detaching keep-alive shells");

                if (app_state.g_job != null) {
                    var job_info: JOBOBJECT_EXTENDED_LIMIT_INFORMATION = std.mem.zeroes(JOBOBJECT_EXTENDED_LIMIT_INFORMATION);
                    job_info.basic.limit_flags = 0;
                    _ = SetInformationJobObject(app_state.g_job, JobObjectExtendedLimitInformation, @ptrCast(&job_info), @sizeOf(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
                }

                for (0..app_state.shell_count) |i| {
                    if (app_state.shells[i].keep_alive and app_state.shells[i].hwnd != null) {
                        _ = SetParent(app_state.shells[i].hwnd, null);
                        _ = ShowWindow(app_state.shells[i].hwnd, SW_HIDE);
                    }
                }
                app_state.g_graceful_exit = true;
            }

            app_state.g_current_workspace_restore = app_state.g_quit_all_in_progress;
            app_state.g_workspace_restore_exclusive = false;

            saveSession();
            launch_cache.finish();
            saveWorkspaceRegistry();
            gcDefaultNamedWindowOnClose();
            removeMyHostedEntriesAndSave();
            deleteInboxStateFile();
            debugLog("WM_CLOSE: session saved, destroying window");
            _ = DestroyWindow(hwnd);
            return 0;
        },
        WM_HOTKEY => {
            if (wp == @as(WPARAM, @intCast(HOTKEY_ID_FOCUS))) {
                toggleDictation();
            }
            return 0;
        },
        0x0016 => {
            if (wp != 0) chatDraftFlush();
            return 0;
        },
        WM_DESTROY => {
            if (std.Thread.spawn(.{}, exitWatchdog, .{})) |thread| thread.detach() else |_| {}
            chatDraftFlush();
            voiceMicStop();
            app_state.g_app_closing = true;
            logSessionAudit("WM_DESTROY:before-kill-processes");

            _ = UnregisterHotKey(hwnd, HOTKEY_ID_FOCUS);
            _ = KillTimer(hwnd, TIMER_CHAT_REFRESH);
            _ = KillTimer(hwnd, TIMER_POWER_IDLE);
            _ = KillTimer(hwnd, TIMER_INBOX_PUBLISH);
            unregisterPowerNotifications();
            closeAllVpsPersistentChannels();
            closeAllAcChannels();
            closeAllChatHistoryChannels();
            releaseVpsPollLeadership();
            if (app_state.g_chat_transcript_hwnd != null and IsWindow(app_state.g_chat_transcript_hwnd) != 0) _ = DestroyWindow(app_state.g_chat_transcript_hwnd);
            if (app_state.g_chat_composer_hwnd != null and IsWindow(app_state.g_chat_composer_hwnd) != 0) _ = DestroyWindow(app_state.g_chat_composer_hwnd);
            app_state.g_chat_transcript_hwnd = null;
            app_state.g_chat_composer_hwnd = null;
            if (app_state.g_chat_bg_brush != null) _ = DeleteObject(app_state.g_chat_bg_brush);
            if (app_state.g_chat_input_brush != null) _ = DeleteObject(app_state.g_chat_input_brush);
            app_state.g_chat_bg_brush = null;
            app_state.g_chat_input_brush = null;
            if (app_state.g_chat_code_font != null) _ = DeleteObject(app_state.g_chat_code_font);
            app_state.g_chat_code_font = null;
            uninstallHook();
            uninstallForegroundHook();
            closeWebView2();
            resetGdiCache();
            if (app_state.g_urlbar_hwnd != null) {
                if (IsWindow(app_state.g_urlbar_hwnd) != 0) _ = DestroyWindow(app_state.g_urlbar_hwnd);
                app_state.g_urlbar_hwnd = null;
            }
            for (0..BROWSER_EDGE_MASK_COUNT) |i| {
                const mh = app_state.g_browser_edge_mask_hwnds[i];
                if (mh != null and IsWindow(mh) != 0) _ = DestroyWindow(mh);
                app_state.g_browser_edge_mask_hwnds[i] = null;
            }
            for (0..app_state.shell_count) |i| {
                closeBrowserForShell(@intCast(i));
            }
            for (0..app_state.shell_count) |i| {
                if (app_state.shells[i].process != null) {
                    if (app_state.g_graceful_exit and app_state.shells[i].keep_alive) {
                        _ = CloseHandle(app_state.shells[i].process);
                        continue;
                    }
                    killProcessTree(app_state.shells[i].pid);
                    _ = CloseHandle(app_state.shells[i].process);
                }
            }
            closeTunnelKeepers();
            if (app_state.g_job != null) _ = CloseHandle(app_state.g_job);
            PostQuitMessage(0);
            return 0;
        },
        else => return DefWindowProcW(hwnd, msg, wp, lp),
    }
}

pub fn main(init: std.process.Init) void {
    launch_cache.begin();
    const args = init.minimal.args.toSlice(init.arena.allocator()) catch return;
    if (usage_telemetry_mode.isRequested(args)) {
        usage_telemetry.main(init) catch {};
        return;
    }

    debugLog("launch process-start version=" ++ APP_VERSION);
    if (update_check.runRelaunchHelperIfRequested()) return;

    defer @import("fonts.zig").unregister();
    if (!@import("fonts.zig").register()) return;

    if (parseSyncAuthCallbackArg()) |callback_url| {
        if (handleSyncAuthCallback(callback_url)) {
            runVaultFlowProcess();
        } else {
            _ = MessageBoxW(null, L("multiprompt could not complete sign-in. Try again from Ctrl+K."), L("multiprompt"), 0x10);
        }
        return;
    }

    if (parseSyncVaultUnlockArg()) {
        runVaultFlowProcess();
        return;
    }

    if (parseNotifyArg()) |payload| {
        sendNotify(payload);
        return;
    }

    var console_fonts = @import("console.zig").registerBundledConsoleFonts();
    defer @import("console.zig").unregisterBundledConsoleFonts(&console_fonts);

    _ = SetErrorMode(SSH_ERROR_MODE);
    crash_recorder.install(&crashSnapshot, APP_VERSION, IS_DEV);

    _ = SetProcessDpiAwarenessContext(@ptrFromInt(@as(usize, @bitCast(@as(isize, -4)))));

    _ = SetCurrentProcessExplicitAppUserModelID(MULTIPROMPT_APP_ID);
    DisableProcessWindowsGhosting();

    {
        var exe_w: [520]u16 = undefined;
        const exe_wlen = GetModuleFileNameW(null, &exe_w, 520);
        if (exe_wlen > 0 and exe_wlen < 520) {
            var exe_dir_end: usize = 0;
            for (0..exe_wlen) |i| {
                if (exe_w[i] == '\\' or exe_w[i] == '/') exe_dir_end = i;
            }

            var old_path: [16384]u16 = undefined;
            const old_len = GetEnvironmentVariableW(L("PATH"), &old_path, 16384);

            var already = false;
            if (old_len >= exe_dir_end) {
                var match = true;
                for (0..exe_dir_end) |ci| {
                    const a: u16 = if (exe_w[ci] >= 'A' and exe_w[ci] <= 'Z') exe_w[ci] + 32 else exe_w[ci];
                    const b: u16 = if (old_path[ci] >= 'A' and old_path[ci] <= 'Z') old_path[ci] + 32 else old_path[ci];
                    if (a != b) {
                        match = false;
                        break;
                    }
                }
                if (match and (old_len == exe_dir_end or old_path[exe_dir_end] == ';')) already = true;
            }

            if (!already and old_len > 0 and old_len < 16384) {
                var new_path: [16900]u16 = undefined;
                var pos: usize = 0;
                for (0..exe_dir_end) |ci| {
                    new_path[pos] = exe_w[ci];
                    pos += 1;
                }
                new_path[pos] = ';';
                pos += 1;
                for (0..old_len) |ci| {
                    new_path[pos] = old_path[ci];
                    pos += 1;
                }
                new_path[pos] = 0;
                _ = SetEnvironmentVariableW(L("PATH"), new_path[0..pos :0].ptr);
            }

            const browser_cli_wrappers = [_][]const u8{ "\\multiprompt-browser.cmd", "\\zsb.cmd" };
            for (browser_cli_wrappers) |tail| {
                var wrapper_w: [540]u16 = undefined;
                var wrapper_pos: usize = 0;
                for (0..exe_dir_end) |ci| {
                    wrapper_w[wrapper_pos] = exe_w[ci];
                    wrapper_pos += 1;
                }
                for (tail) |c| {
                    wrapper_w[wrapper_pos] = c;
                    wrapper_pos += 1;
                }
                wrapper_w[wrapper_pos] = 0;
                const wrapper_h = CreateFileW(@ptrCast(&wrapper_w), 0x40000000, 0, null, 1, 0x80, null);
                if (wrapper_h != INVALID_HANDLE_VALUE_PTR) {
                    const wrapper_content = "@\"%~dp0zigshell-bridge.exe\" %*\r\n";
                    var written: DWORD = 0;
                    _ = WriteFile(wrapper_h, wrapper_content.ptr, @intCast(wrapper_content.len), &written, null);
                    _ = CloseHandle(wrapper_h);
                }
            }
        }
    }

    chatBenchInit();
    parseInstanceName();
    parseNoWindowRestoreFlag();
    parseEmptyWorkspaceFlag();
    parseNewWindowFlag();
    parseSingleWindowFlag();
    parseAdoptArgs();

    if (!loadWorkspaceRegistry()) {
        addOrUpdateWorkspace(getInstanceName(), defaultWorkspaceName(getInstanceName()), true);
    }
    selectStartupWorkspaceFromRegistry();
    ensureCurrentWorkspaceRegistered();

    if (!app_state.g_empty_workspace and app_state.g_adopt_hwnd == null) {
        const cur_id = getInstanceName();
        var ws_name_buf: [64]u8 = std.mem.zeroes([64]u8);
        var ws_name: []const u8 = defaultWorkspaceName(cur_id);
        if (findWorkspace(cur_id)) |wi| {
            const e = &app_state.g_workspaces[wi];
            const nl = @min(e.name_len, ws_name_buf.len - 1);
            if (nl > 0) {
                @memcpy(ws_name_buf[0..nl], e.name[0..nl]);
                ws_name = ws_name_buf[0..nl];
            }
        }
        if (findAndFocusWorkspaceWindow(cur_id, ws_name)) return;
    }

    if (!app_state.g_no_window_restore) saveWorkspaceRegistry();

    initNtdll();
    initShellIcons();
    loadGlobalTheme();
    const hInst = GetModuleHandleW(null);

    const wc = WNDCLASSEXW{
        .cbSize = @sizeOf(WNDCLASSEXW),
        .style = CS_DBLCLKS,
        .lpfnWndProc = wndProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = hInst,
        .hIcon = LoadImageW(hInst, @ptrFromInt(1), IMAGE_ICON, 256, 256, LR_DEFAULTCOLOR) orelse LoadIconW(hInst, @ptrFromInt(1)),
        .hCursor = LoadCursorW(null, @ptrFromInt(32512)),
        .hbrBackground = CreateSolidBrush(themeSidebarBg()),
        .lpszMenuName = null,
        .lpszClassName = L("ZigShell"),
        .hIconSm = LoadImageW(hInst, @ptrFromInt(1), IMAGE_ICON, 16, 16, LR_DEFAULTCOLOR) orelse LoadIconW(hInst, @ptrFromInt(1)),
    };

    if (RegisterClassExW(&wc) == 0) {
        std.debug.print("RegisterClass failed: {}\n", .{GetLastError()});
        return;
    }

    const hwnd = CreateWindowExW(
        0,
        L("ZigShell"),
        if (IS_DEV) L("multiprompt v" ++ APP_VERSION ++ " [DEV]") else L("multiprompt v" ++ APP_VERSION),
        WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN | WS_CLIPSIBLINGS,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        1000,
        650,
        null,
        null,
        hInst,
        null,
    );

    if (hwnd == null) {
        std.debug.print("CreateWindow failed: {}\n", .{GetLastError()});
        return;
    }

    app_state.g_main_hwnd = hwnd;
    defer if (app_state.g_account_instance_mutex != null) {
        _ = ReleaseMutex(app_state.g_account_instance_mutex);
        _ = CloseHandle(app_state.g_account_instance_mutex);
    };
    if (!@import("account_desktop.zig").accountClaim(hwnd)) return;
    _ = syncMainWindowDpi(hwnd, 0);
    applyTitleBarTheme();
    launch_cache.restore();
    _ = ShowWindow(hwnd, SW_SHOW);
    _ = InvalidateRect(hwnd, null, 1);
    _ = @import("win32.zig").UpdateWindow(hwnd);
    if (app_state.g_chat_active) _ = @import("win32.zig").UpdateWindow(app_state.g_chat_transcript_hwnd);

    var msg: MSG = std.mem.zeroes(MSG);
    while (GetMessageW(&msg, null, 0, 0) > 0) {
        _ = TranslateMessage(&msg);
        _ = DispatchMessageW(&msg);
    }
}

fn initializeDeferred(hwnd: HANDLE) void {
    const hInst = GetModuleHandleW(null);
    launch_cache.step(.account);
    if (!accountBootstrap(hwnd)) {
        _ = DestroyWindow(hwnd);
        return;
    }
    migrateWorkspacesFromSessionFiles();
    reconcileWorkspaceRegistry(true);
    loadBrowserEngineConfig();
    loadEdgeProfileConfig();
    loadEdgeExeConfig();
    loadChromeExeConfig();
    loadEdgeExtensionPathConfig();
    writeCurrentThemeManifest();
    if (app_state.g_browser_engine == .chrome) _ = ensureChromeNativeMessagingRegistration();
    loadSidebarStatusCard();
    ensureCapacityPolicyStarter();
    loadCapacityPolicy();

    if (!app_state.g_account_bypass) {
        app_state.g_single_window = true;
        app_state.g_adopt_hwnd = null;
        app_state.g_empty_workspace = false;
    }
    startStaleAltMouseHookThread();
    _ = syncMainWindowDpi(hwnd, 0);
    setWindowTaskbarIdentity(hwnd);

    app_state.g_job = CreateJobObjectW(null, null);
    if (app_state.g_job != null) {
        var job_info = std.mem.zeroes(JOBOBJECT_EXTENDED_LIMIT_INFORMATION);
        job_info.basic.limit_flags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        _ = SetInformationJobObject(app_state.g_job, JobObjectExtendedLimitInformation, @ptrCast(&job_info), @sizeOf(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
    }
    app_state.g_tunnel_job = CreateJobObjectW(null, null);
    if (app_state.g_tunnel_job != null) {
        var tunnel_job_info = std.mem.zeroes(JOBOBJECT_EXTENDED_LIMIT_INFORMATION);
        tunnel_job_info.basic.limit_flags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        _ = SetInformationJobObject(app_state.g_tunnel_job, JobObjectExtendedLimitInformation, @ptrCast(&tunnel_job_info), @sizeOf(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
    }

    var title_buf: [256]u16 = undefined;
    _ = SetWindowTextW(hwnd, buildWindowTitle(&title_buf));

    const ICON_BIG: WPARAM = 1;
    const ICON_SMALL: WPARAM = 0;
    const big_icon = LoadImageW(hInst, @ptrFromInt(1), IMAGE_ICON, 256, 256, LR_DEFAULTCOLOR);
    const small_icon = LoadImageW(hInst, @ptrFromInt(1), IMAGE_ICON, 32, 32, LR_DEFAULTCOLOR);
    if (big_icon != null) _ = SendMessageW(hwnd, 0x0080, ICON_BIG, @bitCast(@intFromPtr(big_icon)));
    if (small_icon != null) _ = SendMessageW(hwnd, 0x0080, ICON_SMALL, @bitCast(@intFromPtr(small_icon)));

    registerJumpList();

    applyTitleBarTheme();
    const DWMWA_WINDOW_CORNER_PREFERENCE: DWORD = 33;
    const DWMWCP_ROUND: DWORD = 2;
    _ = DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, @ptrCast(&DWMWCP_ROUND), @sizeOf(DWORD));

    installForegroundHook();

    const IDC_SIZEWE: LPCWSTR = @ptrFromInt(32644);
    const IDC_ARROW: LPCWSTR = @ptrFromInt(32512);
    app_state.g_cursor_sizewe = LoadCursorW(null, IDC_SIZEWE);
    app_state.g_cursor_arrow = LoadCursorW(null, IDC_ARROW);

    _ = RegisterHotKey(hwnd, HOTKEY_ID_FOCUS, MOD_CONTROL | MOD_SHIFT, 0x20);

    loadPowerProfile();
    refreshPowerStatusFromSystem();
    registerPowerNotifications(hwnd);
    applyPowerProfile(hwnd);
    setCoalescableTimerInterval(hwnd, TIMER_POWER_IDLE, 30_000);
    launch_cache.step(.telemetry);
    ensureUsageTelemetryCollector();
    requestAiPaceRefresh();

    launch_cache.step(.links);
    if (std.Thread.spawn(.{}, notifyListenerThread, .{})) |notify_thread| {
        notify_thread.detach();
    } else |_| {}
    {
        var waits: u32 = 0;
        while (app_state.g_notify_bound_port == 0 and waits < 50) : (waits += 1) Sleep(10);
    }
    startTunnelInboundListener();
    _ = resolveSshPath(false);
    maintainTunnelKeepers();

    launch_cache.step(.tabs);
    app_state.g_startup_progress = true;
    debugLog("main: checking adopt mode");
    if (app_state.g_adopt_hwnd) |adopt_hwnd_val| {
        debugLog("main: adopt mode ACTIVE");
        const adopt_h: HANDLE = @ptrFromInt(adopt_hwnd_val);

        _ = ShowWindow(adopt_h, SW_HIDE);
        _ = SetParent(adopt_h, hwnd);
        var style = GetWindowLongPtrW(adopt_h, GWL_STYLE);
        style &= ~@as(isize, @intCast(WS_CAPTION | WS_THICKFRAME | WS_BORDER));
        style |= @as(isize, @intCast(WS_CHILD));
        _ = SetWindowLongPtrW(adopt_h, GWL_STYLE, style);
        _ = SetWindowPos(adopt_h, null, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOZORDER | SWP_NOMOVE | SWP_NOSIZE);

        const proc = OpenProcess(0x001F0FFF, 0, app_state.g_adopt_pid);
        if (app_state.g_job != null and proc != null) _ = AssignProcessToJobObject(app_state.g_job, proc);

        var new_shell = empty_shell;
        new_shell.hwnd = adopt_h;
        new_shell.process = proc;
        new_shell.pid = app_state.g_adopt_pid;
        new_shell.kind = @enumFromInt(@as(u3, @intCast(app_state.g_adopt_kind)));
        new_shell.name_source = app_state.g_adopt_name_source;
        new_shell.muted = app_state.g_adopt_muted;
        new_shell.pinned_top = app_state.g_adopt_pinned_top;
        new_shell.locked = app_state.g_adopt_locked;
        new_shell.favorite = app_state.g_adopt_favorite;
        new_shell.last_used = app_state.g_adopt_last_used;
        new_shell.input = app_state.g_adopt_input;
        new_shell.visits = app_state.g_adopt_visits;
        if (@as(usize, @intCast(app_state.next_shell_id)) < SPAWN_TITLES.len) {
            new_shell.shell_id = app_state.next_shell_id;
            app_state.next_shell_id += 1;
        }

        if (app_state.g_adopt_name_len > 0) {
            for (0..app_state.g_adopt_name_len) |ni| {
                new_shell.name[ni] = @intCast(app_state.g_adopt_name[ni]);
            }
            new_shell.name_len = app_state.g_adopt_name_len;
        }

        if (app_state.g_adopt_cwd_len > 0) {
            @memcpy(new_shell.cached_cwd[0..app_state.g_adopt_cwd_len], app_state.g_adopt_cwd[0..app_state.g_adopt_cwd_len]);
            new_shell.cached_cwd_len = app_state.g_adopt_cwd_len;
        }

        if (app_state.g_adopt_tmux_len > 0) {
            @memcpy(new_shell.tmux_session[0..app_state.g_adopt_tmux_len], app_state.g_adopt_tmux[0..app_state.g_adopt_tmux_len]);
            new_shell.tmux_session_len = app_state.g_adopt_tmux_len;
        }

        app_state.shells[0] = new_shell;
        app_state.shell_count = 1;
        app_state.active_shell = 0;
        registerShellExitWait(0);
        debugLog("main: adopt — about to ShowWindow");
        const show_result = showShellConsole(app_state.active_shell, SW_SHOW, "main.adopt");
        _ = show_result;
        repositionActive();
        debugLog("main: adopt — repositionActive done");
        _ = SetForegroundWindow(hwnd);
        focusActiveShell();
        requestShellRefocus(120, 8);
        _ = PostMessageW(hwnd, WM_APP_FOCUS, 0, 0);
        debugLog("main: adopt — complete");
    } else if (app_state.g_empty_workspace) {
        debugLog("main: empty workspace receiver");
    } else {
        const restored = restoreSession();
        if (app_state.g_account_base) |server| applyServerLayout(server) catch {};
        loadSnoozedWorkspaces();
        loadChatOutbox();
        if (!IS_DEV and app_state.g_instance_name_len == 0) {
            var seen_buf: [64]u8 = undefined;
            const seen = readChangelogSeen(&seen_buf);
            if (!std.mem.eql(u8, seen, APP_VERSION)) {
                writeChangelogSeen(APP_VERSION);
            }
        }
        if (restored == 0 and !app_state.g_restored_valid_session) {
            if (!spawnShell(.cmd)) {
                std.debug.print("Failed to spawn initial shell\n", .{});
            }
        }
    }
    launch_cache.bindRestoredChat();
    if (app_state.active_shell < app_state.shell_count and
        chatViewShouldShowForTab(app_state.g_chat_view_mode, app_state.shells[app_state.active_shell].chat_view_on, app_state.shells[app_state.active_shell].chat_shell_override, app_state.g_chat_view_restore_on, true))
    {
        openChatView();
    }
    sessionFrontChanged();
    if (chatBenchEnabled()) _ = SetTimer(hwnd, TIMER_CHAT_BENCH, 1000, null);
    applyTitleBarTheme();
    if (app_state.g_multiprompt_theme) startSpinnerTimerIfNeeded();
    updateMainWindowTitle();

    cleanupStaleWindows();

    cleanupStalePanewinFiles();

    _ = EnumWindows(&enumCloseStrayZspane, 0);

    syncInProcessWorkspacesToRegistry();
    publishInboxState();

    updateCardInit();
    if (!startUpdateCardWatch()) _ = SetTimer(hwnd, TIMER_UPDATE_CHECK, UPDATE_CHECK_MS, null);
    updateCardPoll();
    restoreRegisteredWorkspaceWindows();
    checkDueReminders();
    app_state.g_startup_progress = false;
    launch_cache.step(.browser);
    relaunchActiveRestoredBrowserPane();
    updateBrowserVisibility();
    if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_enabled) {
        armBrowserVisibilitySettle(20);
    }
    _ = InvalidateRect(hwnd, null, 1);

    Sleep(500);
    pollShellNames();
    fetchTmuxSessions();

    if (LOOK_UNIFIED) {
        applyConsoleThemeToAllShells();
        repositionActive();
    }

    if (app_state.shell_count > 0) {
        forceReinstallHooks();
        syncMouseHookForUrlClicks();
        focusActiveShell();
        requestShellRefocus(120, 8);
        _ = PostMessageW(hwnd, WM_APP_FOCUS, 0, 0);
        armStartupConsoleGeometrySettle(hwnd);
    }

    if (!app_state.g_account_bypass) {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        if (captureSessionLayout(arena.allocator(), false)) |current| {
            app_state.g_account_local_base = session_layout.encode(std.heap.page_allocator, current) catch null;
        } else |_| {}
    }

    if (crash_recorder.takeRestartNotice()) showHeaderNoticeAscii(crash_recorder.NOTICE_TEXT, 8000, false);
}
