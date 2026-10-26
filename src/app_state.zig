const std = @import("std");
const link_detect = @import("link_detect.zig");
const duplex = @import("voice_duplex.zig");
const voice_filter = @import("voice_filter.zig");
const archive_rules = @import("archive_rules.zig");
const attention_rules = @import("attention_rules.zig");
const skill_model = @import("skills.zig");
const chat_complete = @import("chat_complete.zig");
const chat_markdown = @import("chat_markdown.zig");
const chat_transcript = @import("chat_transcript.zig");
const chat_switch = @import("chat_switch.zig");
const browser_onscreen = @import("browser_onscreen.zig");
const chat_history = @import("chat_history.zig");
const chat_echo = @import("chat_echo.zig");
const chat_style = @import("chat_style.zig");
const account_state = @import("account_state.zig");
const sync_vault = @import("sync_vault.zig");
const LOOK_UNIFIED = @import("main.zig").LOOK_UNIFIED;
const update_check = @import("update_check.zig");
const WINAPI = @import("win32.zig").WINAPI;
const BOOL = @import("win32.zig").BOOL;
const DWORD = @import("win32.zig").DWORD;
const WORD = @import("win32.zig").WORD;
const UINT = @import("win32.zig").UINT;
const WPARAM = @import("win32.zig").WPARAM;
const LPARAM = @import("win32.zig").LPARAM;
const HANDLE = @import("win32.zig").HANDLE;
const LPCWSTR = @import("win32.zig").LPCWSTR;
const WM_APP = @import("win32.zig").WM_APP;
const WM_APP_VOICE_SPEECH_START = @import("win32.zig").WM_APP_VOICE_SPEECH_START;
const WM_APP_VOICE_MIC_STATUS = @import("win32.zig").WM_APP_VOICE_MIC_STATUS;
const POINT = @import("win32.zig").POINT;
const RECT = @import("win32.zig").RECT;
const Sleep = @import("win32.zig").Sleep;
const CloseHandle = @import("win32.zig").CloseHandle;
const OpenProcess = @import("win32.zig").OpenProcess;
const CreateEventW = @import("win32.zig").CreateEventW;
const WAVE_FORMAT_PCM = @import("win32.zig").WAVE_FORMAT_PCM;
const WAVEFORMATEX = @import("win32.zig").WAVEFORMATEX;
const WAVEHDR = @import("win32.zig").WAVEHDR;
const HWAVEOUT = @import("win32.zig").HWAVEOUT;
const INVALID_HANDLE_VALUE_PTR = @import("win32.zig").INVALID_HANDLE_VALUE_PTR;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const CONSOLE_FONT_INFOEX = @import("win32.zig").CONSOLE_FONT_INFOEX;
const PROCESS_QUERY_LIMITED_INFORMATION = @import("win32.zig").PROCESS_QUERY_LIMITED_INFORMATION;
const PROCESS_MEMORY_COUNTERS = @import("win32.zig").PROCESS_MEMORY_COUNTERS;
const TH32CS_SNAPPROCESS = @import("win32.zig").TH32CS_SNAPPROCESS;
const PROCESSENTRY32W = @import("win32.zig").PROCESSENTRY32W;
const CreateToolhelp32Snapshot = @import("win32.zig").CreateToolhelp32Snapshot;
const Process32FirstW = @import("win32.zig").Process32FirstW;
const Process32NextW = @import("win32.zig").Process32NextW;
const L = @import("startup.zig").L;
const RGB = @import("startup.zig").RGB;
const PostMessageW = @import("focus.zig").PostMessageW;
const SetForegroundWindow = @import("focus.zig").SetForegroundWindow;
const SetFocus = @import("focus.zig").SetFocus;
const AttachThreadInput = @import("focus.zig").AttachThreadInput;
const SwitchToThisWindow = @import("focus.zig").SwitchToThisWindow;
const AllowSetForegroundWindow = @import("focus.zig").AllowSetForegroundWindow;
const ShowWindow = @import("focus.zig").ShowWindow;
const ShowWindowAsync = @import("focus.zig").ShowWindowAsync;
const SetWindowPos = @import("focus.zig").SetWindowPos;
const pidListContains = @import("shell_poll.zig").pidListContains;
const u16ExeNameMatches = @import("shell_poll.zig").u16ExeNameMatches;
const findClaudeChildPid = @import("shell_poll.zig").findClaudeChildPid;
const HRESULT = @import("win32.zig").HRESULT;
const CLSCTX_INPROC_SERVER = @import("win32.zig").CLSCTX_INPROC_SERVER;
const GUID = @import("win32.zig").GUID;
const AudioClientProperties = @import("win32.zig").AudioClientProperties;
const AudioEffectWin = @import("win32.zig").AudioEffectWin;
const CLSID_MMDeviceEnumerator = @import("win32.zig").CLSID_MMDeviceEnumerator;
const IID_IMMDeviceEnumerator = @import("win32.zig").IID_IMMDeviceEnumerator;
const IID_IAudioClient2 = @import("win32.zig").IID_IAudioClient2;
const IID_IAudioCaptureClient = @import("win32.zig").IID_IAudioCaptureClient;
const IID_IAcousticEchoCancellationControl = @import("win32.zig").IID_IAcousticEchoCancellationControl;
const IID_IAudioEffectsManager = @import("win32.zig").IID_IAudioEffectsManager;
const IMMDeviceEnumerator = @import("win32.zig").IMMDeviceEnumerator;
const IMMDevice = @import("win32.zig").IMMDevice;
const IAudioClient2 = @import("win32.zig").IAudioClient2;
const IAudioCaptureClient = @import("win32.zig").IAudioCaptureClient;
const IAcousticEchoCancellationControl = @import("win32.zig").IAcousticEchoCancellationControl;
const IAudioEffectsManager = @import("win32.zig").IAudioEffectsManager;
const CoTaskMemFree = @import("win32.zig").CoTaskMemFree;
const CoCreateInstance = @import("win32.zig").CoCreateInstance;
const ISpVoice = @import("win32.zig").ISpVoice;
const voiceTtsStopPlayback = @import("voice.zig").voiceTtsStopPlayback;
const comRelease = @import("workspaces.zig").comRelease;
const chat_image = @import("chat_image.zig");
const voicePostResult = @import("voice.zig").voicePostResult;
const voiceSttWorkerThread = @import("voice.zig").voiceSttWorkerThread;
const dictationAudit = @import("voice.zig").dictationAudit;
const NOTIFY_PAYLOAD_CAP = @import("win32.zig").NOTIFY_PAYLOAD_CAP;
const SOCKET = @import("win32.zig").SOCKET;
const accept = @import("win32.zig").accept;

pub var g_chat_foreground_retries: u8 = 0;
pub var g_chat_browser_handoff_until: u64 = 0;

pub const PowerProfile = enum { auto, always, off };
pub var g_power_profile: PowerProfile = .auto;
pub var g_power_on_battery: bool = false;
pub var g_power_energy_saver: bool = false;
pub var g_power_display_off: bool = false;
pub var g_power_deep_idle: bool = false;
pub var g_power_setting_handles: [3]HANDLE = .{ null, null, null };
pub var g_power_minimized_since_tick: u64 = 0;
pub var g_power_background_since_tick: u64 = 0;

pub const PowerTimerMode = enum { normal, saving, deep_idle };

pub const NOTIFY_PORTS = @import("notify_ports.zig").NOTIFY_PORTS;

pub var g_tunnel_inbound_port: u16 = 0;
pub var g_notify_bound_port: u16 = 0;

pub const MonitorSlot = struct { mon: HANDLE, bounds: RECT, work: RECT };
pub var g_mon_list: [8]MonitorSlot = undefined;
pub var g_mon_count: usize = 0;
pub var g_main_monitor_dpi: u32 = 96;

pub const MonitorDirection = enum { left, right, up, down };

pub const MINMAXINFO = extern struct {
    ptReserved: POINT,
    ptMaxSize: POINT,
    ptMaxPosition: POINT,
    ptMinTrackSize: POINT,
    ptMaxTrackSize: POINT,
};

pub const MonitorTransitionReason = enum {
    shortcut,
    interactive_drag,
    detected_crossing,
    display_change,
};

const MonitorTransition = struct {
    active: bool = false,
    positioning: bool = false,
    generation: u32 = 0,
    reason: MonitorTransitionReason = .detected_crossing,
    source_mon: HANDLE = null,
    target_mon: HANDLE = null,
    source_work: RECT = .{ .left = 0, .top = 0, .right = 0, .bottom = 0 },
    target_work: RECT = .{ .left = 0, .top = 0, .right = 0, .bottom = 0 },
    expected_frame: RECT = .{ .left = 0, .top = 0, .right = 0, .bottom = 0 },
    expected_valid: bool = false,
    last_frame: RECT = .{ .left = 0, .top = 0, .right = 0, .bottom = 0 },
    last_frame_valid: bool = false,
    stable_samples: u8 = 0,
    attempts: u8 = 0,
};

pub var g_monitor_transition: MonitorTransition = .{};
pub var g_last_main_monitor: HANDLE = null;
pub var g_K32GetProcessMemoryInfo: ?*const fn (HANDLE, *PROCESS_MEMORY_COUNTERS, DWORD) callconv(WINAPI) BOOL = null;

pub var g_ntdll: ?HANDLE = null;
pub var g_NtQueryInformationProcess: ?*const fn (HANDLE, u32, *anyopaque, u32, ?*u32) callconv(WINAPI) i32 = null;

pub var g_mciSendStringA: ?*const fn ([*:0]const u8, ?[*]u8, UINT, HANDLE) callconv(WINAPI) DWORD = null;

pub var g_notify_sound_path: [512]u8 = std.mem.zeroes([512]u8);
pub var g_notify_sound_len: u32 = 0;
pub var g_sound_enabled: bool = false;
pub var g_mobile_mode: bool = false;
pub const SESSION_JSON_CAPACITY: usize = 512 * 1024;
pub const BROWSER_PENDING_URL_CAP: usize = 8 * 1024;
pub const WIN32_COMMAND_LINE_CAP: usize = 32_760;

pub const COPYDATASTRUCT = extern struct {
    dwData: usize,
    cbData: DWORD,
    lpData: ?*anyopaque,
};
pub const COPYDATA_TAB_TRANSFER: usize = 0x5A53;
pub const GA_ROOT: UINT = 2;
pub const GA_ROOTOWNER: UINT = 3;

pub const TabTransfer = extern struct {
    console_hwnd: usize,
    pid: DWORD,
    kind: u8,
    name_source: u8,
    muted: u8,
    keep_alive: u8,
    claude_session: u8,
    tmux_host: u8,
    name_len: u32,
    name: [64]u8,
    cwd_len: u32,
    cwd: [512]u8,
    tmux_len: u32,
    tmux: [64]u8,
    favicon_path_len: u32,
    favicon_path: [512]u8,
    group_id: u32,
    starred_group_id: u32 = 0,
    starred_group_name_len: u32 = 0,
    starred_group_name: [64]u8 = @splat(0),
    starred_group_color: u8 = 7,
    starred_group_collapsed: u8 = 0,
    group_name_len: u32,
    group_name: [64]u8,
    group_color: u8,
    group_collapsed: u8,
    pinned_top: u8,
    reserved_lock: u8,
    favorite: u8,
    last_used: u64,
    input: u64 = 0,
    visits: @import("frequent.zig").Visits,
    inbox_excluded: u8,
    tmux_identity: [64]u8 = @splat(0),
    tmux_identity_len: u32 = 0,
};

pub const ShellKind = enum(u3) { cmd, pwsh, vps, tmux, vps2, bash, gitbash };

pub const ShellActivity = enum(u2) { idle, active };
pub const NameSource = enum(u3) { default, console_title, cwd, manual, semantic };
pub const BROWSER_SPLIT_DEFAULT_PERMILLE: u16 = 350;

pub const Shell = struct {
    hwnd: HANDLE,
    process: HANDLE,
    pid: DWORD,
    kind: ShellKind,
    name: [64]u16,
    name_len: u32,
    name_source: NameSource,
    restored_name_hold: bool = false,
    notified: bool,
    activity: ShellActivity,
    working_since_ms: u64 = 0,
    permission_answered: bool = false,
    needs_attention: bool,
    hook_capable: bool = false,
    turn_pending: bool = false,
    deferred_done: bool = false,
    console_working: bool = false,
    last_blue_dot_source: attention_rules.Source = .restore,
    last_blue_dot_time: u64 = 0,
    archive_time: u64 = 0,
    archive_done: u64 = 0,
    last_done_time: u64 = 0,
    last_done_content: archive_rules.Content = .{},
    last_done_content_valid: bool = false,
    archive_active: u64 = 0,
    archive_content: archive_rules.Content = .{},
    archive_content_valid: bool = false,
    inbox_excluded: bool = false,
    inbox_archived: bool = false,
    last_title: [256]u16,
    last_title_len: i32,
    tmux_session: [64]u8,
    tmux_session_len: u32,
    tmux_identity: [64]u8 = @splat(0),
    tmux_identity_len: u32 = 0,
    muted: bool,
    sync_owned: bool = false,
    synced_input: u64 = 0,
    input_publish_pending: bool = false,
    keep_alive: bool,
    pinned_top: bool = false,
    favorite: bool = false,
    last_used: u64 = 0,
    input: u64 = 0,
    visits: @import("frequent.zig").Visits = .{},
    console_inflight: bool = false,
    launch_failed: bool = false,
    disconnected: bool = false,
    chat_view_on: bool = false,
    chat_todo_open: bool = false,
    chat_todo_scroll: i32 = 0,
    cached_cwd: [512]u8,
    cached_cwd_len: u32,
    ram_mb: u32,
    tmux_detect_streak: u32,
    claude_session: bool,
    wait_handle: HANDLE,
    wake_id: u32 = 0,
    shell_id: u32,
    title_id: u32 = 0,
    chat_id: u64 = 0,
    last_read_message_id: u64 = 0,
    favicon_hicon: ?HANDLE,
    favicon_path: [512]u8,
    favicon_path_len: u32,
    group_id: u32,
    starred_group_id: u32 = 0,
    selected: bool,
    tmux_host: u8,
    spawn_tick: u64 = 0,
    full_width: bool,
    full_width_pending_console_resize: bool = false,
    last_active: u64,
    last_active_event: u64 = 0,
    hidden_idle_streak: u8 = 0,
    last_viewed: u64 = 0,
    workspace: u8 = 0,
    preview: [96]u8 = std.mem.zeroes([96]u8),
    preview_len: u32 = 0,
    ai_agent: u8 = 0,
    adopt_streak: u8 = 0,
    external_name_sync: ExternalNameSyncState = .{},
    console_font_logged: bool = false,
    base_font_h: i16 = 0,
    base_font_w: i16 = 0,
    base_font_dpi: u16 = 0,
    font_gen: u32 = 0,
    claude_sid: [40]u8 = std.mem.zeroes([40]u8),
    claude_sid_len: u32 = 0,
    claude_cwd: [192]u8 = std.mem.zeroes([192]u8),
    claude_cwd_len: u32 = 0,
    browser_hwnd: HANDLE = null,
    browser_enabled: bool = false,
    browser_url: [512]u8 = std.mem.zeroes([512]u8),
    browser_url_len: u32 = 0,
    browser_pending_url: [BROWSER_PENDING_URL_CAP]u8 = std.mem.zeroes([BROWSER_PENDING_URL_CAP]u8),
    browser_pending_url_len: u32 = 0,
    browser_launch_tick: u64 = 0,
    browser_first_launch_tick: u64 = 0,
    browser_connection_id: u64 = 0,
    browser_open_failed: bool = false,
    browser_profile_token: [32]u8 = std.mem.zeroes([32]u8),
    browser_suspended: bool = false,
    browser_native: bool = true,
    browser_split_permille: u16 = BROWSER_SPLIT_DEFAULT_PERMILLE,
    browser_window_id: i64 = 0,
    browser_bind_nonce: [40]u8 = std.mem.zeroes([40]u8),
    browser_bind_nonce_len: u32 = 0,
    browser_health_misses: u8 = 0,
    browser_relaunch_after_tick: u64 = 0,
    diag_events: [4][96]u8 = std.mem.zeroes([4][96]u8),
    diag_event_lens: [4]u8 = std.mem.zeroes([4]u8),
    diag_event_next: u8 = 0,
    diag_event_count: u8 = 0,
    ecoqos_applied: bool = false,
    keep_awake: bool = false,
    browser_parked_since: u64 = 0,
    browser_docking: bool = false,
    browser_frozen: bool = false,
    browser_lifecycle_pending: bool = false,
    browser_wake_requested: bool = false,
    voice_last_reply_hash: u64 = 0,
    eta_total_ms: u64 = 0,
    eta_deadline_tick: u64 = 0,
    eta_desc: [80]u8 = std.mem.zeroes([80]u8),
    eta_desc_len: u32 = 0,
    eta_first_est_s: u32 = 0,
    eta_active_start_tick: u64 = 0,
    ssh_reconnect: @import("ssh_reconnect.zig").State = .{},
};

pub const empty_shell = Shell{
    .hwnd = null,
    .process = null,
    .pid = 0,
    .kind = .cmd,
    .name = std.mem.zeroes([64]u16),
    .name_len = 0,
    .name_source = .default,
    .notified = false,
    .activity = .idle,
    .working_since_ms = 0,
    .needs_attention = false,
    .last_title = std.mem.zeroes([256]u16),
    .last_title_len = 0,
    .tmux_session = std.mem.zeroes([64]u8),
    .tmux_session_len = 0,
    .muted = false,
    .favorite = false,
    .inbox_excluded = false,
    .keep_alive = false,
    .pinned_top = false,
    .cached_cwd = std.mem.zeroes([512]u8),
    .cached_cwd_len = 0,
    .ram_mb = 0,
    .tmux_detect_streak = 0,
    .claude_session = false,
    .wait_handle = null,
    .shell_id = 0,
    .chat_id = 0,
    .favicon_hicon = null,
    .favicon_path = std.mem.zeroes([512]u8),
    .favicon_path_len = 0,
    .group_id = 0,
    .selected = false,
    .tmux_host = 0,
    .spawn_tick = 0,
    .full_width = false,
    .browser_split_permille = BROWSER_SPLIT_DEFAULT_PERMILLE,
    .last_active = 0,
};

pub const MAX_SHELLS = 256;
pub var g_sidebar_w_full: i32 = if (LOOK_UNIFIED) 220 else 320;
pub const SIDEBAR_W_COLLAPSED: i32 = 44;
pub const SIDEBAR_W_MIN: i32 = 150;
pub const SIDEBAR_W_MAX: i32 = 500;
pub var g_sidebar_collapsed: bool = false;
pub var g_hide_sidebar: bool = false;
pub var g_hide_pills: bool = true;
pub var g_pinned_section_collapsed: bool = false;
pub var g_recents_section_collapsed: bool = false;
pub var g_tab_sort_auto: bool = true;
pub var g_skip_view_bump: bool = false;
pub var g_previous_shell_sid: u32 = 0;
pub const RECENT_SESSION_ROWS: usize = 5;
const StickyKey = struct { sid: u32, att: bool, active: bool, la: u64 };
pub var g_sticky: [MAX_SHELLS]StickyKey = undefined;
pub var g_sticky_n: u32 = 0;
pub var g_thread_title: bool = true;
pub var g_eta_numbers_on: bool = true;
pub var g_eta_progress_on: bool = true;
pub var g_eta_timer_running: bool = false;
pub var g_eta_accuracy_active: bool = false;
pub var g_eta_acc_lines: [8][96]u8 = undefined;
pub var g_eta_acc_lens: [8]u32 = [_]u32{0} ** 8;
pub var g_eta_acc_count: u32 = 0;
pub var g_sidebar_scroll: i32 = 0;
pub var g_light_theme: bool = false;
pub var g_system_theme: bool = false;
pub var g_mid_theme: bool = false;
pub var g_edge_gray_theme: bool = false;
pub var g_amoled_theme: bool = false;
pub var g_dev_theme_active: bool = false;
pub var g_multiprompt_theme: bool = false;

pub const DevTheme = struct {
    title_font: [64]u16,
    subtitle_font: [64]u16,
    close_font: [64]u16,
    console_font: [64]u16,
    title_height: i32,
    subtitle_height: i32,
    close_height: i32,
    title_weight: i32,
    subtitle_weight: i32,
    close_weight: i32,
    console_font_height: i32,
    console_font_weight: i32,
    sidebar_bg: DWORD,
    shell_bg: DWORD,
    titlebar_bg: DWORD,
    border_bg: DWORD,
    active_tab_bg: DWORD,
    header_bg: DWORD,
    overlay_bg: DWORD,
    overlay_input_bg: DWORD,
    overlay_border: DWORD,
    overlay_divider: DWORD,
    selected_bg: DWORD,
    text: DWORD,
    text_inactive: DWORD,
    subtitle: DWORD,
    muted: DWORD,
    hint: DWORD,
    accent: DWORD,
    attention: DWORD,
    spinner: DWORD,
    tag_tmux: DWORD,
    tag_tmux_active: DWORD,
    tag_vps: DWORD,
    tag_vps_active: DWORD,
    tag_neutral: DWORD,
    tag_neutral_active: DWORD,
    console_fg: DWORD,
    console_palette: [16]DWORD,
    shadow_outer: DWORD,
    shadow_mid: DWORD,
    shadow_inner: DWORD,
    scrollbar_track: DWORD,
    scrollbar_thumb: DWORD,
};

pub var g_dev_theme: DevTheme = undefined;
pub var g_dev_theme_initialized: bool = false;
pub var g_dev_saved_console_theme_valid: bool = false;
pub var g_dev_saved_console_palette: [16]DWORD = std.mem.zeroes([16]DWORD);
pub var g_dev_saved_console_attr: WORD = 0x0007;
pub var g_dev_saved_console_font: CONSOLE_FONT_INFOEX = undefined;

pub const ISSUE_441 = true;
pub const DEFAULT_CONSOLE_FONT = @import("fonts.zig").SHELL_FACE;

pub const DEFAULT_DEV_THEME_JSON =
    \\{
    \\  "theme_revision": 11,
    \\  "name": "Dev Blue",
    \\  "fonts": {
    \\    "title_font": "IBM Plex Sans",
    \\    "subtitle_font": "IBM Plex Sans",
    \\    "close_font": "IBM Plex Sans",
    \\    "console_font": "
++ DEFAULT_CONSOLE_FONT ++
    \\",
    \\    "title_height": 16,
    \\    "subtitle_height": 14,
    \\    "close_height": 14,
    \\    "title_weight": 400,
    \\    "subtitle_weight": 400,
    \\    "close_weight": 400,
    \\    "console_font_height": 18,
    \\    "console_font_weight": 600
    \\  },
    \\  "colors": {
    \\    "sidebar_bg": "#03080E",
    \\    "shell_bg": "#03080E",
    \\    "console_fg": "#FFFFFF",
    \\    "console_0": "#03080E",
    \\    "console_1": "#182C3D",
    \\    "console_2": "#1B3347",
    \\    "console_3": "#203B52",
    \\    "console_4": "#284C68",
    \\    "console_5": "#315B7A",
    \\    "console_6": "#3B6D90",
    \\    "console_7": "#DAE4ED",
    \\    "console_8": "#425466",
    \\    "console_9": "#243F55",
    \\    "console_10": "#2B4A62",
    \\    "console_11": "#355972",
    \\    "console_12": "#456F8A",
    \\    "console_13": "#5B839D",
    \\    "console_14": "#789AAF",
    \\    "console_15": "#EEF3F7",
    \\    "titlebar_bg": "#03080E",
    \\    "border_bg": "#38485E",
    \\    "active_tab_bg": "#03080E",
    \\    "header_bg": "#060D16",
    \\    "overlay_bg": "#03080E",
    \\    "overlay_input_bg": "#03080E",
    \\    "overlay_border": "#112437",
    \\    "overlay_divider": "#0C1A2A",
    \\    "selected_bg": "#12324E",
    \\    "text": "#DAE4ED",
    \\    "text_inactive": "#B8C7D5",
    \\    "subtitle": "#7A8FA2",
    \\    "muted": "#5B6F82",
    \\    "hint": "#445668",
    \\    "accent": "#3A5C7D",
    \\    "attention": "#426E91",
    \\    "spinner": "#5D7A96",
    \\    "tag_tmux": "#7792A9",
    \\    "tag_tmux_active": "#AFC4D4",
    \\    "tag_vps": "#7792A9",
    \\    "tag_vps_active": "#AFC4D4",
    \\    "tag_neutral": "#6D859A",
    \\    "tag_neutral_active": "#A5B9C9",
    \\    "shadow_outer": "#000206",
    \\    "shadow_mid": "#01050A",
    \\    "shadow_inner": "#02080E",
    \\    "scrollbar_track": "#08121E",
    \\    "scrollbar_thumb": "#203B52"
    \\  }
    \\}
    \\
;
pub var g_sidebar_resizing: bool = false;
pub var g_browser_dragging: bool = false;
pub const BROWSER_SUSPEND_DEFAULT_MIN: u32 = 15;
pub const BROWSER_SUSPEND_SAVING_MIN: u32 = 5;
pub var g_external_browser_links: bool = true;
pub var g_browser_autosuspend: bool = true;
pub var g_browser_suspend_min: u32 = BROWSER_SUSPEND_DEFAULT_MIN;
pub const BROWSER_FREEZE_PARK_MS_AC: u64 = 120_000;
pub const BROWSER_FREEZE_PARK_MS_SAVING: u64 = 30_000;
pub const BROWSER_SPLIT_W: i32 = 6;
pub var g_browser_native_default: bool = true;
pub const BrowserEngine = enum { edge, chrome };
pub var g_browser_engine: BrowserEngine = .edge;
pub var g_browser_focus_mode: bool = false;
pub var g_native_browser_focus_pending_shell_id: u32 = 0;
pub var g_native_browser_focus_retries: u16 = 0;
pub var g_native_browser_focus_attempts: u8 = 0;
pub var g_native_browser_alt_unlocked_at: u64 = 0;
pub const BROWSER_BLANK_APP_URL = "data:text/html,<style>body{background:%23000;margin:0}</style>";
pub var g_edge_user_data_dir_buf: [512]u8 = undefined;
pub var g_edge_user_data_dir_len: usize = 0;

pub var g_chrome_user_data_dir_buf: [512]u8 = undefined;
pub var g_chrome_user_data_dir_len: usize = 0;

pub var g_edge_extension_path_buf: [512]u8 = undefined;
pub var g_edge_extension_path_len: usize = 0;

pub const BROWSER_EDGE_PROFILE: []const u8 = "Default";
pub var g_edge_profile_buf: [96]u8 = undefined;
pub var g_edge_profile_len: usize = 0;

pub const BROWSER_EDGE_EXE_X86: []const u8 = "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe";
pub const BROWSER_EDGE_EXE_PF: []const u8 = "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe";
pub var g_edge_exe_buf: [320]u8 = undefined;
pub var g_edge_exe_len: usize = 0;

pub const BROWSER_CHROME_EXE_PF: []const u8 = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";
pub const BROWSER_CHROME_EXE_X86: []const u8 = "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe";
pub var g_chrome_exe_buf: [320]u8 = undefined;
pub var g_chrome_exe_len: usize = 0;
pub var g_cursor_sizewe: HANDLE = null;
pub var g_cursor_arrow: HANDLE = null;
pub const SHELL_PAD: i32 = if (LOOK_UNIFIED) 0 else 6;
pub const THREAD_TITLE_H: i32 = 44;
pub const DEV_LETTER_SPACING: i32 = 0;
pub const DEV_SHELL_COLS: i32 = 100;
pub const DEV_TOP_PAD: i32 = 10;

pub const DEV_CONSOLE_FONTS = [_][]const u8{DEFAULT_CONSOLE_FONT};
pub const DEFAULT_CONSOLE_FONT_IDX = blk: {
    for (DEV_CONSOLE_FONTS, 0..) |face, i| {
        if (std.mem.eql(u8, face, DEFAULT_CONSOLE_FONT)) break :blk i;
    }
    unreachable;
};
pub var g_dev_font_idx: usize = DEFAULT_CONSOLE_FONT_IDX;
pub const DEV_CONSOLE_SIZES = [_]i32{ 14, 16, 18, 20, 22 };
pub var g_dev_size_idx: usize = 2;
pub var g_dev_font_hud: bool = false;
pub var g_dev_console_cell_w: i32 = 0;
pub const GROUP_HEADER_H: i32 = 28;
pub const BTN_H: i32 = 32;
pub const SIDEBAR_STATUS_DETAIL_H: i32 = 222;
pub const SIDEBAR_STICKY_CARD_H: i32 = 26;
pub const SIDEBAR_STICKY_CARD_COLLAPSED_H: i32 = 58;
pub const SIDEBAR_STICKY_CARD_GAP: i32 = 6;
pub const NUM_BUTTONS = 8;
pub const MENU_KIND_ORDER = [NUM_BUTTONS]ShellKind{ .cmd, .tmux, .tmux, .vps, .vps2, .pwsh, .bash, .gitbash };

pub var shells: [MAX_SHELLS]Shell = [_]Shell{empty_shell} ** MAX_SHELLS;
pub var shell_count: u32 = 0;
pub var active_shell: u32 = 0;

pub const MAX_LWS: u8 = 9;
pub var g_single_window: bool = false;
pub var g_starred_workspace: bool = false;
pub var g_starred_last_shell: u32 = 0;
pub var g_active_workspace: u8 = 0;
pub var g_lws_count: u8 = 1;
pub var g_ws_names: [MAX_LWS][32]u8 = std.mem.zeroes([MAX_LWS][32]u8);
pub var g_ws_name_len: [MAX_LWS]u32 = [_]u32{0} ** MAX_LWS;
pub var g_ws_ids: [MAX_LWS][32]u8 = std.mem.zeroes([MAX_LWS][32]u8);
pub var g_ws_id_len: [MAX_LWS]u32 = [_]u32{0} ** MAX_LWS;
pub var g_ws_last_shell: [MAX_LWS]u32 = [_]u32{0} ** MAX_LWS;
pub const WorkspaceFocus = enum { none, chat, shell };
pub var g_ws_focus: [MAX_LWS]WorkspaceFocus = [_]WorkspaceFocus{.none} ** MAX_LWS;
pub var g_ws_snoozed: [MAX_LWS]bool = [_]bool{false} ** MAX_LWS;

pub const WS_STRIP_H: i32 = 34;
pub const WS_PILL_TOP: i32 = 7;
pub const WS_PILL_H: i32 = 20;
pub const WS_PILL_W: i32 = 24;
pub const WS_PILL_GAP: i32 = 5;
pub const WS_STRIP_LEFT: i32 = 8;
pub const WS_NEW_PILL: u8 = 0xFF;
pub var g_workspace_hover: ?u8 = null;
pub var g_inbox_button_hover: bool = false;
pub var g_chat_stop_hover: bool = false;
pub var g_chat_stop_shown: bool = false;

pub const MAX_GROUPS: usize = 16;
pub const GROUP_COLORS = [_]DWORD{
    RGB(100, 180, 255),
    RGB(240, 110, 90),
    RGB(240, 170, 80),
    RGB(240, 210, 80),
    RGB(130, 210, 130),
    RGB(180, 130, 230),
    RGB(240, 130, 200),
    RGB(160, 160, 160),
};
pub const GROUP_COLOR_NAMES = [_][]const u8{ "Blue", "Red", "Orange", "Yellow", "Green", "Purple", "Pink", "Gray" };
const TabGroup = struct {
    id: u32,
    name: [64]u16,
    name_len: u32,
    collapsed: bool,
    color: u8,
    color_set: bool = false,
};
pub var groups: [MAX_GROUPS]TabGroup = undefined;
pub var group_count: u32 = 0;
pub var next_group_id: u32 = 1;

const RowKind = enum { section, header, tab, inbox };
pub const SidebarTier = enum(u1) { recent = 0, pinned = 1 };
pub const Row = struct {
    kind: RowKind,
    gidx: u32,
    shell_idx: u32,
    section_tier: SidebarTier = .recent,
    y: i32,
};
pub const MAX_ROWS: usize = MAX_SHELLS + INBOX_MAX_ROWS + MAX_GROUPS + 6;
pub const SECTION_HEADER_H: i32 = 24;

pub const HitTarget = union(enum) {
    none: void,
    section: SidebarTier,
    header: u32,
    tab: u32,
    inbox: u32,
    buttons: void,
};

pub const ClosedShell = struct {
    chat_id: u64 = 0,
    kind: ShellKind,
    name: [64]u16,
    name_len: u32,
    tmux_session: [64]u8,
    tmux_session_len: u32,
    tmux_identity: [64]u8 = @splat(0),
    tmux_identity_len: u32 = 0,
    cached_cwd: [512]u8,
    cached_cwd_len: u32,
    was_manual: bool,
    was_sem: bool,
    closed_at: u64,
    group: ?TabGroup = null,
    starred_group: ?TabGroup = null,
    favorite: bool = false,
    tmux_host: u8 = 0,
};
pub const MAX_CLOSED_HISTORY = 10;
pub var g_closed_history: [MAX_CLOSED_HISTORY]ClosedShell = undefined;
pub var g_closed_count: u32 = 0;

pub const MAX_TMUX_SESSIONS = 512;
pub const TmuxSessionEntry = struct {
    name: [64]u8,
    name_len: u32,
    activity: u64,
    ram_mb: u32 = 0,
    host: u8 = 0,
    path: [256]u8 = undefined,
    path_len: u32 = 0,
    title: [80]u8 = undefined,
    title_len: u32 = 0,
    agent: u8 = 0,
};

pub const CapacityState = enum(u8) {
    unknown,
    green,
    amber,
    red,
    critical,
};

pub const CapacityPolicy = struct {
    host_busy_limit: [2]u16 = .{ 8, 8 },
    amber_load_per_core_milli: u32 = 750,
    red_load_per_core_milli: u32 = 1000,
    critical_load_per_core_milli: u32 = 1500,
    amber_mem_available_pct: u8 = 25,
    red_mem_available_pct: u8 = 15,
    critical_mem_available_pct: u8 = 8,
    amber_psi_milli: u32 = 10_000,
    red_psi_milli: u32 = 20_000,
    critical_psi_milli: u32 = 50_000,
};

pub const HostCapacity = struct {
    valid: bool = false,
    cores: u16 = 0,
    load_milli: u32 = 0,
    mem_total_kb: u64 = 0,
    mem_available_kb: u64 = 0,
    swap_total_kb: u64 = 0,
    swap_free_kb: u64 = 0,
    cpu_psi_milli: u32 = 0,
    mem_psi_milli: u32 = 0,
    io_psi_milli: u32 = 0,
    tmux_sessions: u16 = 0,
    resident_agents: u16 = 0,
    resident_ram_mb: u32 = 0,
    state: CapacityState = .unknown,
    recovery_samples: u8 = 0,
    updated_tick: u64 = 0,
};

pub var g_capacity_policy = CapacityPolicy{};
pub var g_host_capacity: [2]HostCapacity = .{ .{}, .{} };
pub var g_capacity_announced: [2]CapacityState = .{ .unknown, .unknown };
pub var g_capacity_block_notice_until: u64 = 0;

pub var g_tmux_cache: [MAX_TMUX_SESSIONS]TmuxSessionEntry = undefined;
pub var g_tmux_cache_count: u32 = 0;
pub var g_tmux_cache_tick: u64 = 0;
pub var g_tmux_fetch_tick: u64 = 0;
pub var g_tmux_fetching: bool = false;
var g_tmux_fetch_pipe: HANDLE = null;
var g_tmux_fetch_process: HANDLE = null;

pub const AgentSessionBreakdown = struct {
    claude: u16 = 0,
    codex: u16 = 0,
    other: u16 = 0,

    pub fn total(self: AgentSessionBreakdown) u16 {
        return self.claude +| self.codex +| self.other;
    }
};

pub const UPDATE_CARD_H: i32 = 76;
pub const UPDATE_CHECK_MS: u32 = 30000;
pub var g_update_watch_stop: HANDLE = null;
pub var g_update_watch_thread: ?std.Thread = null;
pub var g_update_path: [520:0]u16 = std.mem.zeroes([520:0]u16);
pub var g_update_path_len: usize = 0;
pub var g_update_startup_stamp: ?update_check.Stamp = null;
pub var g_update_attempt_stamp: ?update_check.Stamp = null;
pub var g_update_ver: [update_check.MAX_VERSION_LEN]u8 = undefined;
pub var g_update_ver_len: usize = 0;
pub var g_update_dismissed: [update_check.MAX_VERSION_LEN]u8 = undefined;
pub var g_update_dismissed_len: usize = 0;
pub var g_update_hover: u8 = 0;
pub var g_update_relaunching: bool = false;

pub const CapacityAdmission = enum {
    allow,
    warn,
    block_host_pressure,
    block_host_busy,
};

pub const FocusNative = struct {
    pub extern "user32" fn PostMessageW(HANDLE, UINT, WPARAM, LPARAM) callconv(WINAPI) BOOL;
    pub extern "user32" fn SetForegroundWindow(HANDLE) callconv(WINAPI) BOOL;
    pub extern "user32" fn SetFocus(HANDLE) callconv(WINAPI) HANDLE;
    pub extern "user32" fn AttachThreadInput(DWORD, DWORD, BOOL) callconv(WINAPI) BOOL;
    pub extern "user32" fn SwitchToThisWindow(HANDLE, BOOL) callconv(WINAPI) void;
    pub extern "user32" fn AllowSetForegroundWindow(DWORD) callconv(WINAPI) BOOL;
    pub extern "user32" fn LockSetForegroundWindow(UINT) callconv(WINAPI) BOOL;
    pub extern "user32" fn ShowWindow(HANDLE, i32) callconv(WINAPI) BOOL;
    pub extern "user32" fn ShowWindowAsync(HANDLE, i32) callconv(WINAPI) BOOL;
    pub extern "user32" fn SetWindowPos(HANDLE, HANDLE, i32, i32, i32, i32, UINT) callconv(WINAPI) BOOL;
};
pub var g_focus_user_action_tick: u64 = 0;
pub var g_focus_input_tick: u64 = 0;
pub var g_focus_return_hwnd: HANDLE = null;
pub var g_focus_typing_tick: u64 = 0;
pub var g_focus_paste_target: HANDLE = null;
pub var g_focus_authorized_hwnd: HANDLE = null;
pub var g_focus_authorized_until: u64 = 0;
pub var g_focus_browser_shell_id: u32 = 0;
pub var g_focus_restoring: bool = false;
pub var g_focus_activation_until: u64 = 0;
pub var g_focus_mouse_hwnd = std.atomic.Value(usize).init(0);
pub var g_focus_mouse_tick = std.atomic.Value(u64).init(0);
pub var g_focus_mouse_seen: u64 = 0;
pub var g_focus_foreign_input_tick = std.atomic.Value(u64).init(0);
const FocusUserMessage = struct { msg: UINT = 0, wp: WPARAM = 0, lp: LPARAM = 0, tick: u64 = 0 };
pub var g_focus_user_messages: [128]FocusUserMessage = @splat(.{});
pub var g_focus_user_message_next: usize = 0;

pub var g_main_hwnd: HANDLE = null;
pub var g_hook: HANDLE = null;
pub var g_mouse_hook: HANDLE = null;
pub var g_foreground_hook: HANDLE = null;
pub var g_browser_orphan_hook: HANDLE = null;
pub var g_browser_orphan_dirty: bool = true;
pub var next_shell_id: u32 = 1;
pub var g_refocus_remaining: u32 = 0;
pub var g_inbox_shell_focus_until: u64 = 0;
pub var g_refocus_waiting_for_alt_release: bool = false;
pub var g_sysmenu_pending: bool = false;
pub var g_sysmenu_retry_count: u8 = 0;
pub var g_ws_switch_focus_grace: u64 = 0;
pub var g_system_alt_tab_until: u64 = 0;
pub const SYSTEM_ALT_TAB_SUPPRESS_MS: u64 = 5000;
pub var g_popup_menu_active: bool = false;
pub var g_move_size_active: bool = false;
pub var g_resume_until_tick: u64 = 0;
pub var g_last_hook_reinstall_tick: u64 = 0;
pub const HOOK_REINSTALL_THROTTLE_MS: u64 = 2_000;
pub var g_last_kb_hook_tick: u64 = 0;
pub var g_last_mouse_hook_tick: u64 = 0;
pub var g_last_hook_watchdog_tick: u64 = 0;
pub const HOOK_WATCHDOG_STALL_MS: u64 = 75_000;
pub var g_startup_progress: bool = false;

pub const BrowserPopupEvidence = struct {
    same_edge_process: bool = false,
    chrome_widget: bool = false,
    owner_link: bool = false,
    popup_style: bool = false,
    tool_window: bool = false,
    titleless: bool = false,
    popup_left: i32 = 0,
    popup_top: i32 = 0,
    popup_right: i32 = 0,
    popup_bottom: i32 = 0,
    pane_left: i32 = 0,
    pane_top: i32 = 0,
    pane_right: i32 = 0,
    pane_bottom: i32 = 0,
};

pub const BrowserPopupDisposition = struct {
    owns_pane_foreground: bool = false,
    suppress_shell_refocus: bool = false,
    suppress_mask_raise: bool = false,
};
pub const EVENT_MODIFY_STATE: DWORD = 0x0002;

pub const PROCESS_SET_INFORMATION: DWORD = 0x0200;
pub const ProcessPowerThrottling: i32 = 4;
pub const PROCESS_POWER_THROTTLING_EXECUTION_SPEED: DWORD = 0x1;
pub const PROCESS_POWER_THROTTLING_STATE = extern struct {
    Version: DWORD,
    ControlMask: DWORD,
    StateMask: DWORD,
};

pub var g_icon_cmd: HANDLE = null;
pub var g_icon_pwsh: HANDLE = null;
pub var g_icon_bash: HANDLE = null;
pub var g_icon_codex_dot: HANDLE = null;
pub const DI_NORMAL: UINT = 0x0003;

pub var drag_active: bool = false;
pub var drag_src: u32 = 0;
pub var drag_detached: bool = false;
pub var drag_is_group: bool = false;
pub var drag_group_gidx: u32 = 0;
pub var drag_start_x: i32 = 0;
pub var drag_start_y: i32 = 0;
pub var drag_detach_blocked: bool = false;
pub var drag_last_swap_tick: u64 = 0;
pub var drag_pending_materialize: bool = false;
pub var drag_section_only: bool = false;
pub const DRAG_MATERIALIZE_THRESH: i32 = 8;

pub var g_edit_hwnd: HANDLE = null;
pub var g_edit_tab: u32 = 0;
pub var g_edit_orig_proc: isize = 0;
pub var g_edit_is_group: bool = false;
pub var g_edit_is_window: bool = false;
pub var g_edit_is_browser_urlbar: bool = false;
pub var g_edit_is_thread_title: bool = false;
pub var g_edit_is_inbox: bool = false;
pub var g_edit_sync_remote_name: bool = false;
pub var g_edit_idx: u32 = 0;

pub var g_search_active: bool = false;
pub var g_search_from_inbox: bool = false;
pub var g_search_spawn_ws: u8 = 0xFF;
pub var g_search_workspace_mode: bool = false;
pub var g_search_workspace_delete_mode: bool = false;
pub var g_search_ws_sort_mode: bool = false;
pub var g_search_ws_move_mode: bool = false;
pub var g_wsmove_tab_sid: u32 = 0;
pub var g_search_group_move_mode: bool = false;
pub var g_groupmove_tab_sid: u32 = 0;
pub var g_search_skills_mode: bool = false;
pub var g_search_tabctx_mode: bool = false;
pub var g_search_groupctx_mode: bool = false;
pub var g_groupctx_gid: u32 = 0;
pub const SEARCH_GROUPCTX_BASE: usize = 10000;
pub const SEARCH_GROUPCTX_COUNT: usize = 16 + MAX_LWS + MAX_WORKSPACES;
pub var g_tabctx_sid: u32 = 0;
pub var g_search_remind_input_mode: bool = false;
pub var g_search_rename_input_mode: bool = false;
pub var g_search_rename_sid: u32 = 0;
pub var g_search_rename_select_all: bool = false;
pub var g_search_remind_preset_mode: bool = false;
pub var g_search_ws_snoozed_mode: bool = false;
pub var g_remind_ws_id: [32]u8 = std.mem.zeroes([32]u8);
pub var g_remind_ws_id_len: u32 = 0;
pub var g_search_reminders_mode: bool = false;
pub var g_search_session_overview_mode: bool = false;
pub var g_search_openall_host_mode: bool = false;
pub var g_search_snippet_mode: bool = false;
pub var g_remind_sid: u32 = 0;
pub var g_remind_target_sid: u32 = 0;
pub var g_browser_url_mode: bool = false;
pub var g_browser_adopt_snapshot: [64]HANDLE = std.mem.zeroes([64]HANDLE);
pub var g_browser_adopt_count: u32 = 0;
pub var g_browser_adopt_target_idx: u32 = 0xFFFFFFFF;
pub var g_browser_adopt_deadline: u64 = 0;
pub var g_browser_adopt_nonce: [40]u8 = std.mem.zeroes([40]u8);
pub var g_browser_adopt_nonce_len: usize = 0;
pub var g_browser_nonce_counter: u32 = 0;
pub var g_browser_adopt_foreground_launch: bool = false;
pub var g_browser_adopt_via_extension: bool = false;
pub var g_browser_adopt_fg_locked: bool = false;
pub var g_browser_pending_activate_sid: u32 = 0;
pub var g_browser_settle_ticks: i32 = 0;
pub var g_console_geometry_settle_ticks: i32 = 0;
pub var g_last_browser_tab_url: [512]u8 = @splat(0);
pub var g_last_browser_tab_url_len: usize = 0;
pub var g_browser_url_poll_pending: bool = false;
pub var g_browser_url_poll_shell_id: u32 = 0;
pub var g_browser_url_poll_window_id: i64 = 0;
pub var g_browser_url_poll_result: [512]u8 = std.mem.zeroes([512]u8);
pub var g_browser_url_poll_result_len: u32 = 0;

pub var g_urlbar_hwnd: HANDLE = null;
pub var g_urlbar_class_registered: bool = false;
pub const BROWSER_EDGE_MASK_COUNT: usize = 10;
pub const BrowserEdgeMaskSide = enum(usize) { left = 0, top = 1, right = 2, bottom = 3, controls = 4, control_hit = 5, top_left = 6, top_right = 7, bottom_left = 8, bottom_right = 9 };
pub var g_browser_edge_mask_hwnds: [BROWSER_EDGE_MASK_COUNT]HANDLE = [_]HANDLE{null} ** BROWSER_EDGE_MASK_COUNT;
pub var g_browser_edge_mask_class_registered: bool = false;
pub var g_browser_edge_mask_raise_ticks: i32 = 0;
pub var g_pane_ring_state: u8 = 0;
pub var g_browser_edge_mask_rects: [BROWSER_EDGE_MASK_COUNT]RECT = [_]RECT{std.mem.zeroes(RECT)} ** BROWSER_EDGE_MASK_COUNT;
pub var g_browser_edge_mask_shown: [BROWSER_EDGE_MASK_COUNT]bool = [_]bool{false} ** BROWSER_EDGE_MASK_COUNT;
pub var g_nextunread_count: u32 = 0;
pub var g_nextunread_name: [64]u8 = std.mem.zeroes([64]u8);
pub var g_nextunread_name_len: u32 = 0;
pub var g_wssort_dragging: bool = false;
pub var g_wssort_drag_slot: u8 = 0;
pub var g_search_workspace_delete_confirm: ?u32 = null;
pub var g_search_snippet_delete_confirm: ?usize = null;
pub var g_search_theme_mode: bool = false;
pub var g_search_buf: [64]u16 = std.mem.zeroes([64]u16);
pub var g_search_len: u32 = 0;
pub var g_search_sel: u32 = 0;
pub var g_search_scroll: u32 = 0;
pub var g_search_wheel_remainder: i32 = 0;
pub var g_search_backdrop_bmp: HANDLE = null;
pub var g_search_backdrop_w: i32 = 0;
pub var g_search_backdrop_h: i32 = 0;

pub var g_shortcuts_active: bool = false;
pub var g_shortcuts_scroll: i32 = 0;
pub var g_changelog_active: bool = false;
pub var g_changelog_scroll: i32 = 0;
pub var g_changelog_sel: i32 = 0;
pub var g_snippet_create_active: bool = false;
pub var g_snippet_name_hwnd: HANDLE = null;
pub var g_snippet_text_hwnd: HANDLE = null;
pub var g_snippet_edit_orig_proc: isize = 0;

pub var g_chat_active: bool = false;
pub var clean_chat: bool = false;
pub var g_chat_transcript_hwnd: HANDLE = null;
pub var g_chat_status_hwnd: HANDLE = null;
pub var g_chat_hover_link: ?link_detect.Range = null;
pub var g_chat_hover_copy: ?usize = null;
pub var g_chat_link_font: HANDLE = null;
pub var g_chat_code_link_font: HANDLE = null;
pub var g_chat_composer_hwnd: HANDLE = null;
pub var g_chat_composer_orig_proc: isize = 0;
pub const CHAT_AC_ENTER_SENDS = false;
const ChatAcSlot = struct {
    host: u8 = 255,
    agent: chat_complete.Agent = .other,
    mode: chat_complete.Mode = .slash,
    session: [64]u8 = .{0} ** 64,
    cwd: [192]u8 = .{0} ** 192,
    bytes: [2][128 * 1024]u8 = undefined,
    active: usize = 0,
    pending_len: usize = 0,
    len: usize = 0,
    retry_used: bool = false,
    entries: [512]chat_complete.Entry = undefined,
    count: usize = 0,
    status: chat_complete.Status = .loading,
    fetched: u64 = 0,
    pending: u32 = 0,
    refresh_pending: bool = false,
};
const ChatAc = struct {
    open: bool = false,
    browse: bool = false,
    token: chat_complete.Token = .{ .mode = .slash, .start = 0, .end = 0 },
    dismissed: bool = false,
    dismissed_start: usize = 0,
    dismissed_text: [200]u16 = .{0} ** 200,
    dismissed_len: usize = 0,
    sel: usize = 0,
    selected_name: [256]u8 = .{0} ** 256,
    selected_len: usize = 0,
    selected_kind: u8 = 0,
    query: [800]u8 = .{0} ** 800,
    query_len: usize = 0,
    top: usize = 0,
    count: usize = 0,
    idx: [512]u16 = undefined,
    slot: usize = 0,
};
pub var g_chat_ac: ChatAc = .{};
pub var g_chat_ac_hwnd: HANDLE = null;
pub var g_chat_ac_tab_accepted = false;
pub var g_chat_ac_class_registered = false;
pub var g_chat_ac_slots: [8]ChatAcSlot = @splat(.{});
pub var g_chat_ac_mutex: SpinMutex = .{};
pub var g_chat_ac_request_id: u32 = 0;
pub var g_chat_ac_mru: [2][20][201]u8 = .{.{.{0} ** 201} ** 20} ** 2;
pub var g_chat_ac_mru_count: [2]usize = .{ 0, 0 };
pub var g_chat_ac_dialog_command: [256]u16 = .{0} ** 256;
pub var g_chat_ac_dialog_len: usize = 0;
pub var g_chat_composer_extra_h: i32 = 0;
pub var g_chat_composer_scroll_shown: bool = false;
pub var g_chat_font_pt: i32 = CHAT_FONT_DEFAULT_PT;
pub const CHAT_FONT_DEFAULT_PT: i32 = 14;
pub var g_chat_font: HANDLE = null;
pub var g_chat_bg_brush: HANDLE = null;
pub var g_chat_input_brush: HANDLE = null;
pub var g_chat_bg_color: DWORD = 0;
pub var g_chat_input_color: DWORD = 0;
pub var g_chat_last_hash: u64 = 0;
pub var g_chat_last_len: usize = 0;
pub var g_chat_cache_shell_id: u32 = 0;
pub var g_chat_hidden_tool_rows: u32 = 0;
pub var g_chat_screen_working: bool = false;
pub var g_chat_permission: @import("chat_permission.zig").PermissionMenu = .{};
pub var g_chat_permission_sid: u32 = 0;
pub var g_chat_working_text: [128]u16 = std.mem.zeroes([128]u16);
pub var g_chat_screen_status_len: usize = 0;
pub var g_chat_working_applied: [128]u16 = std.mem.zeroes([128]u16);
pub var g_chat_working_applied_len: usize = 0;
pub var g_chat_raw: [262144]u16 = std.mem.zeroes([262144]u16);
pub var g_chat_capture_storage: [262144]u16 = @splat(0);
pub var g_chat_capture: []u16 = &g_chat_capture_storage;
pub var g_chat_line_starts: [1400]usize = std.mem.zeroes([1400]usize);
pub var g_chat_line_lens: [1400]usize = std.mem.zeroes([1400]usize);
pub var g_chat_reply: [131072]u8 = @splat(0);
pub var g_chat_reply_len: usize = 0;
pub var g_chat_reply_preview: [1024]u16 = @splat(0);
pub var g_chat_reply_preview_len: usize = 0;
pub const SEARCH_CHAT_REPLY_OFFSET: usize = 6399;
pub const SEARCH_CHAT_REACT_LIKE_OFFSET: usize = 6490;
pub const SEARCH_CHAT_REACT_DISLIKE_OFFSET: usize = 6491;
pub const SEARCH_CHAT_REACT_HEART_OFFSET: usize = 6492;
pub var g_chat_skill_name: [128]u8 = std.mem.zeroes([128]u8);
pub var g_chat_skill_name_len: usize = 0;
pub var g_chat_skill_body: [131072]u8 = std.mem.zeroes([131072]u8);
pub var g_chat_skill_body_len: usize = 0;
pub var g_palette_skills: []skill_model.Skill = &.{};
pub var g_chat_message_wide: [262144]u16 = std.mem.zeroes([262144]u16);
pub const ChatBlockRole = chat_markdown.Role;
pub const ChatBlock = chat_markdown.Block;
pub const CHAT_MAX_BLOCKS = 256;
pub var g_chat_blocks_storage: [CHAT_MAX_BLOCKS]ChatBlock = undefined;
pub var g_chat_blocks: []ChatBlock = &g_chat_blocks_storage;
pub var g_chat_block_count: usize = 0;
pub var g_chat_rich_fonts: [12]HANDLE = @splat(null);
pub var g_chat_screen: [262144]u16 = undefined;
pub var g_chat_browser_swap: chat_switch.Pending = .{};
pub var g_browser_onscreen: browser_onscreen.OnScreen = .{};
pub var g_chat_switch_preparing = false;
pub var g_chat_switch_started: u64 = 0;
pub var g_chat_switch_painted_ms: u64 = 0;
pub var g_chat_switch_browser_sid: u32 = 0;
pub var g_chat_switch_content_sid: u32 = 0;
pub var g_chat_file_valid = false;
pub var g_chat_file_request_id: u32 = 0;
pub var g_chat_code_font: HANDLE = null;
pub var g_chat_layout_storage: [CHAT_MAX_BLOCKS]RECT = undefined;
pub var g_chat_layout_rects: []RECT = &g_chat_layout_storage;
pub var g_chat_bubble_storage: [CHAT_MAX_BLOCKS]chat_style.BubblePos = @splat(.single);
pub var g_chat_bubble_pos: []chat_style.BubblePos = &g_chat_bubble_storage;
pub var g_chat_layout_width: i32 = 0;
pub var g_chat_layout_reuse: usize = 0;
pub var g_chat_layout_scale: i32 = 0;
pub var g_chat_layout_top_pad: i32 = 0;
pub var g_chat_top_pad: i32 = 0;
pub var g_chat_bottom_inset: i32 = 0;
pub var g_chat_hole_signature: u64 = 0;
pub var g_chat_layout_font_pt: i32 = 0;
pub var g_chat_layout_dirty = false;
pub var g_chat_content_h: i32 = 0;
pub var g_chat_scroll_y: i32 = 0;
pub var g_chat_scrolled_up = false;
pub var g_chat_read_visit_shell_id: u32 = 0;
pub var g_chat_read_visit_marker: u64 = 0;
pub var g_chat_read_visit_state: enum { pending, all_read, unread } = .pending;
pub var g_chat_read_open_pending = false;
pub var g_chat_read_open_ready = false;
pub var g_chat_read_hold = false;
pub var g_chat_read_boundary: chat_history.ReadBoundary = .{};
pub var g_chat_read_divider_y: i32 = 0;
pub var g_chat_new_messages: chat_history.NewMessages = .{};
pub var g_chat_content_left: i32 = 0;
pub var g_chat_sel_anchor: usize = 0;
pub var g_chat_sel_caret: usize = 0;
pub var g_chat_sel_active: bool = false;
pub var g_chat_sel_dragging: bool = false;
pub var g_chat_sel_transcript_focus: bool = false;
pub var g_chat_sel_click_count: u32 = 0;
pub var g_chat_sel_last_click: u64 = 0;
pub var g_chat_sel_last_x: i32 = 0;
pub var g_chat_sel_last_y: i32 = 0;
pub var g_chat_class_registered: bool = false;

const VoiceState = duplex.VoiceState;
pub var g_voice_mode_active: bool = false;
pub var g_voice_state: VoiceState = .idle;
pub var g_voice_pending_turn_shell_id: u32 = 0;
pub var g_voice_speaking_shell_id: u32 = 0;
pub var g_voice_cursor_shell_id: u32 = 0;
pub var g_voice_cursor_latest_hash: u64 = 0;
pub var g_voice_cursor_start: ?usize = null;
pub var g_voice_highlight: ?voice_filter.ReplyRange = null;
pub var g_voice_replay_only: bool = false;
pub var g_voice_listening_active = std.atomic.Value(bool).init(false);
pub var g_voice_vad_state: VadState = .{};

pub var g_voice_tts_wave_out: HWAVEOUT = null;
pub var g_voice_tts_generation = std.atomic.Value(u64).init(0);
pub var g_voice_tts_mutex: SpinMutex = .{};
pub var g_voice_tts_outstanding: std.ArrayList(*VoiceTtsBuffer) = .empty;
pub var g_voice_tts_outstanding_count = std.atomic.Value(usize).init(0);
pub var g_voice_tts_fetching = std.atomic.Value(bool).init(false);
pub var g_voice_tts_fallback_shown = std.atomic.Value(bool).init(false);
pub var g_voice_tts_fallback_text: [8192]u16 = undefined;
pub var g_voice_tts_fallback_len: usize = 0;
pub var g_voice_tts_fallback_shell_id: u32 = 0;
pub var g_voice_tts_audio_started = std.atomic.Value(bool).init(false);
pub const SEARCH_VISIBLE_ROWS: u32 = 10;
pub const SEARCH_WHEEL_ROWS: u32 = 3;
pub const SEARCH_TMUX_OFFSET: usize = 1000;
pub const SEARCH_NEW_OFFSET: usize = 2000;
pub const SEARCH_SOUND_OFFSET: usize = 3000;
pub const SEARCH_THEME_MENU_OFFSET: usize = 4000;
pub const SEARCH_THEME_BACK_OFFSET: usize = 4001;
pub const SEARCH_THEME_SYSTEM_OFFSET: usize = 4009;
pub const SEARCH_THEME_DARK_OFFSET: usize = 4010;
pub const SEARCH_THEME_MID_OFFSET: usize = 4011;
pub const SEARCH_THEME_LIGHT_OFFSET: usize = 4012;
pub const SEARCH_THEME_AMOLED_OFFSET: usize = 4013;
pub const SEARCH_THEME_EDGE_GRAY_OFFSET: usize = 4014;
pub const SEARCH_THEME_DEV_BLUE_OFFSET: usize = 4015;
pub const SEARCH_THEME_DEV_EDIT_OFFSET: usize = 4016;
pub const SEARCH_THEME_DEV_RELOAD_OFFSET: usize = 4017;
pub const SEARCH_THEME_MULTIPROMPT_OFFSET: usize = 4018;
pub const SEARCH_OPENALL_OFFSET: usize = 5000;
pub const SEARCH_OPENFOLDER_OFFSET: usize = 5001;
pub const SEARCH_RECOVER_REPO_OFFSET: usize = 5002;
pub const SEARCH_OPENALL_HOST_BACK_OFFSET: usize = 5003;
pub const SEARCH_OPENALL_HOST_DE_OFFSET: usize = 5004;
pub const SEARCH_OPENALL_HOST_UK_OFFSET: usize = 5005;
pub const SEARCH_OPENALL_HOST_INNE_OFFSET: usize = 5006;
pub const SEARCH_NEWWIN_OFFSET: usize = 6000;
pub const SEARCH_CREATEWS_OFFSET: usize = 6001;
pub const SEARCH_WORKSPACES_MENU_OFFSET: usize = 6200;
pub const SEARCH_WORKSPACE_DELETE_MENU_OFFSET: usize = 6201;
pub const SEARCH_QUIT_OFFSET: usize = 6202;
pub const SEARCH_FULLWIDTH_OFFSET: usize = 6203;
pub const SEARCH_SHORTCUTS_OFFSET: usize = 6204;
pub const SEARCH_CLOSEWIN_OFFSET: usize = 6205;
pub const SEARCH_RECONNECT_OFFSET: usize = 6206;
pub const SEARCH_SINGLEWIN_OFFSET: usize = 6207;
pub const SEARCH_INSTALLHOOK_OFFSET: usize = 6208;
pub const SEARCH_GOINBOX_OFFSET: usize = 6209;
pub const SEARCH_WSSORT_MENU_OFFSET: usize = 6210;
pub const SEARCH_WSMOVE_MENU_OFFSET: usize = 6211;
pub const SEARCH_HIDESIDEBAR_OFFSET: usize = 6212;
pub const SEARCH_HIDEPILLS_OFFSET: usize = 6213;
pub const SEARCH_NEXTUNREAD_OFFSET: usize = 6214;
pub const SEARCH_SIDEBAR_COLLAPSE_OFFSET: usize = 6215;
pub const SEARCH_SIDEBAR_HIDE_OFFSET: usize = 6216;
pub const SEARCH_TABSORT_INBOX_OFFSET: usize = 6217;
pub const SEARCH_TABSORT_MANUAL_OFFSET: usize = 6218;
pub const SEARCH_UNREADONLY_OFFSET: usize = 6219;
pub const SEARCH_THREADTITLE_OFFSET: usize = 6220;
pub const SEARCH_FONT_BIGGER_OFFSET: usize = 6221;
pub const SEARCH_FONT_SMALLER_OFFSET: usize = 6222;
pub const SEARCH_FONT_RESET_OFFSET: usize = 6223;
pub const SEARCH_UI_BIGGER_OFFSET: usize = 6224;
pub const SEARCH_UI_SMALLER_OFFSET: usize = 6225;
pub const SEARCH_UI_RESET_OFFSET: usize = 6226;
pub const SEARCH_CUSTOMCMD_EDIT_OFFSET: usize = 6227;
pub const SEARCH_CUSTOMCMD_RELOAD_OFFSET: usize = 6228;
pub const SEARCH_ARCHIVE_OFFSET: usize = 6229;
pub const SEARCH_REOPEN_OFFSET: usize = 6230;
pub const SEARCH_URLPICK_OFFSET: usize = 6231;
pub const SEARCH_CLOSETAB_OFFSET: usize = 6232;
pub const SEARCH_MUTETAB_OFFSET: usize = 6233;
pub const SEARCH_KEEPALIVE_OFFSET: usize = 6234;
pub const SEARCH_BROWSER_TOGGLE_OFFSET: usize = 6235;
pub const SEARCH_BROWSER_URL_OFFSET: usize = 6236;
pub const SEARCH_BROWSER_INSTRUCT_OFFSET: usize = 6237;
pub const SEARCH_BROWSER_FOCUS_URL_OFFSET: usize = 6238;
pub const SEARCH_BROWSER_FOCUS_TOGGLE_OFFSET: usize = 6239;
pub const SEARCH_EXTERNAL_BROWSER_LINKS_OFFSET: usize = 6378;
pub const SEARCH_BROWSER_AUTOSUSPEND_OFFSET: usize = 6240;
pub const SEARCH_CHANGELOG_OFFSET: usize = 6241;
pub const SEARCH_BROWSER_BACK_OFFSET: usize = 6242;
pub const SEARCH_BROWSER_FORWARD_OFFSET: usize = 6243;
pub const SEARCH_BROWSER_MODE_OFFSET: usize = 6244;
pub const SEARCH_UPDATE_OFFSET: usize = 6385;
pub const SEARCH_RESTART_OFFSET: usize = 6245;
pub const SEARCH_ZSB_REBIND_OFFSET: usize = 6246;
pub const SEARCH_SHELL_DIAG_OFFSET: usize = 6247;
pub const SEARCH_SYNC_NAME_OFFSET: usize = 6248;
pub const SEARCH_RENAME_SYNC_OFFSET: usize = 6249;
pub const SEARCH_END_TMUX_OFFSET: usize = 6250;
pub const SEARCH_REMIND_ME_OFFSET: usize = 6251;
pub const SEARCH_WS_SNOOZE_OFFSET: usize = 6357;
pub const SEARCH_WS_SNOOZED_OFFSET: usize = 6358;
pub const SEARCH_WS_BRINGBACK_OFFSET: usize = 6359;
pub const SEARCH_WS_SNOOZED_ROW_OFFSET: usize = 7800;
pub const SEARCH_REMINDERS_MENU_OFFSET: usize = 6252;
pub const SEARCH_GROUPMOVE_MENU_OFFSET: usize = 6301;
pub const SEARCH_GROUPMOVE_BACK_OFFSET: usize = 6302;
pub const SEARCH_GROUPMOVE_NEW_OFFSET: usize = 6303;
pub const SEARCH_GROUPMOVE_NONE_OFFSET: usize = 6304;
pub const SEARCH_CHAT_VIEW_OFFSET: usize = 6305;
pub const SEARCH_CHAT_STOP_OFFSET: usize = 6306;
pub const SEARCH_CHAT_ALLOW_OFFSET: usize = 6373;
pub const SEARCH_CHAT_ALWAYS_OFFSET: usize = 6374;
pub const SEARCH_CHAT_DENY_OFFSET: usize = 6375;
pub const SEARCH_MULTIPROMPT_LOGIN_OFFSET: usize = 6307;
pub const SEARCH_SYNC_SIGNOUT_OFFSET: usize = 9100;
pub const SEARCH_LAYOUT_PULL_OFFSET: usize = 9102;
pub const SEARCH_SYNC_STATUS_OFFSET: usize = 9101;
pub const SEARCH_APPROVE_DEVICES_OFFSET: usize = 9103;
pub const SEARCH_REMOVE_SERVER_1_OFFSET: usize = 9104;
pub const SEARCH_REMOVE_SERVER_2_OFFSET: usize = 9105;
pub const SEARCH_REMOVE_SERVER_3_OFFSET: usize = 9106;
pub const SEARCH_SKILLS_MENU_OFFSET: usize = 6308;
pub const SEARCH_SKILLS_BACK_OFFSET: usize = 6309;
pub const SEARCH_KEEPAWAKE_OFFSET: usize = 6317;
pub const SEARCH_CRASH_REPORTS_OFFSET: usize = 6370;
pub const SEARCH_CRASH_NOW_OFFSET: usize = 6371;
pub const SEARCH_HIBERNATE_NOW_OFFSET: usize = 6318;
pub const SEARCH_CLOSE_ALL_BROWSER_PANES_OFFSET: usize = 6376;
pub const SEARCH_INBOX_EXCLUDE_OFFSET: usize = 6319;
pub const SEARCH_REMIND_PRESET_OFFSET: usize = 6600;
pub const SEARCH_GROUPMOVE_GROUP_OFFSET: usize = 6320;
pub const SEARCH_POWER_AUTO_OFFSET: usize = 6337;
pub const SEARCH_POWER_ALWAYS_OFFSET: usize = 6338;
pub const SEARCH_POWER_OFF_OFFSET: usize = 6339;
pub const SEARCH_FAVORITE_OFFSET: usize = 6389;
pub const SEARCH_SHOW_FREQUENT_OFFSET: usize = 6380;
pub const SEARCH_FREQUENT_FIRST_OFFSET: usize = 6381;
pub const SEARCH_SHOW_FAVORITES_OFFSET: usize = 6382;
pub const SEARCH_SHOW_ALL_OFFSET: usize = 6383;
pub const SEARCH_INBOX_FREQUENT_OFFSET: usize = 6396;
pub const SEARCH_LADDER_AUTO_OFFSET: usize = 6390;
pub const SEARCH_LADDER_CLAUDE_OFFSET: usize = 6391;
pub const SEARCH_LADDER_CODEX_OFFSET: usize = 6392;
pub const SEARCH_LADDER_DASH_OFFSET: usize = 6393;
pub const SEARCH_VOICE_MODE_ON_OFFSET: usize = 6340;
pub const SEARCH_VOICE_MODE_OFF_OFFSET: usize = 6341;
pub const SEARCH_ETA_NUMBERS_OFFSET: usize = 6342;
pub const SEARCH_ETA_PROGRESS_OFFSET: usize = 6343;
pub const SEARCH_ETA_ACCURACY_OFFSET: usize = 6344;
pub const SEARCH_CHAT_VIEW_MODE_EVERYWHERE_OFFSET: usize = 6346;
pub const SEARCH_CHAT_VIEW_MODE_NOWHERE_OFFSET: usize = 6347;
pub const SEARCH_VOICE_ALWAYS_ON_OFFSET: usize = 6349;
pub const SEARCH_VOICE_ALWAYS_OFF_OFFSET: usize = 6350;
pub const SEARCH_VOICE_STOP_OFFSET: usize = 6348;
pub const SEARCH_VOICE_SPEED_100_OFFSET: usize = 6351;
pub const SEARCH_VOICE_SPEED_125_OFFSET: usize = 6352;
pub const SEARCH_VOICE_SPEED_140_OFFSET: usize = 6353;
pub const SEARCH_VOICE_SPEED_150_OFFSET: usize = 6354;
pub const SEARCH_VOICE_PREVIOUS_OFFSET: usize = 6360;
pub const SEARCH_VOICE_NEXT_OFFSET: usize = 6361;
pub const SEARCH_CLEAN_CHAT_OFFSET: usize = 6467;
pub const SEARCH_CHAT_TODO_OFFSET: usize = 6398;
pub const SEARCH_CHAT_TOOL_STEPS_OFFSET: usize = 6395;
pub const SEARCH_CHAT_NEWEST_OFFSET: usize = 6465;
pub const SEARCH_CHAT_COPY_CODE_OFFSET: usize = 6362;
pub const SEARCH_CHAT_COPY_SELECTION_OFFSET: usize = 6363;
pub const SEARCH_CHAT_SELECT_ALL_OFFSET: usize = 6364;
pub const SEARCH_CHAT_AC_OFFSET: usize = 6356;
pub const SEARCH_CHAT_QUEUE_SEND_OFFSET: usize = 6365;
pub const SEARCH_CHAT_RESET_OFFSET: usize = 6394;
pub const SEARCH_CHAT_TAB_URL_OFFSET: usize = 6384;
pub const SEARCH_CHAT_QUEUE_CLEAR_OFFSET: usize = 6366;
pub const SEARCH_CHAT_RETRY_UNSENT_OFFSET: usize = 6367;
pub const SEARCH_CHAT_DISCARD_UNSENT_OFFSET: usize = 6368;
pub const SEARCH_CHAT_PUSH_QUEUED_OFFSET: usize = 6369;
pub const SEARCH_CHAT_EDIT_QUEUED_OFFSET: usize = 6379;
pub const SEARCH_VOICE_REPLAY_OFFSET: usize = 6355;
pub const REMIND_PRESET_HOURS_1: usize = 0;
pub const REMIND_PRESET_HOURS_2: usize = 1;
pub const REMIND_PRESET_HOURS_3: usize = 2;
pub const REMIND_PRESET_HOURS_6: usize = 3;
pub const REMIND_PRESET_HOURS_12: usize = 4;
pub const REMIND_PRESET_EVENING: usize = 5;
pub const REMIND_PRESET_TOMORROW: usize = 6;
pub const REMIND_PRESET_TOMORROW_EVENING: usize = 7;
pub const REMIND_PRESET_3DAYS: usize = 8;
pub const REMIND_PRESET_WEEKEND: usize = 9;
pub const REMIND_PRESET_NEXTWEEK: usize = 10;
pub const REMIND_PRESET_SOMEDAY: usize = 11;
pub const REMIND_PRESET_CUSTOM: usize = 12;
pub const REMIND_PRESET_COUNT: usize = 13;
pub const SEARCH_CODEX_TMUX_OFFSET: usize = 6253;
pub const SEARCH_SNIPPETS_MENU_OFFSET: usize = 6254;
pub const SEARCH_SNIPPET_CREATE_OFFSET: usize = 6255;
pub const SEARCH_SNIPPET_BACK_OFFSET: usize = 6256;
pub const SEARCH_SNIPPET_OFFSET: usize = 6257;
pub const SEARCH_SESSION_OVERVIEW_MENU_OFFSET: usize = 6290;
pub const SEARCH_ARCHIVED_VIEW_OFFSET: usize = 6291;
pub const SEARCH_BROWSER_SHOTURL_OFFSET: usize = 6292;
pub const SEARCH_PIN_TOP_OFFSET: usize = 6293;
pub const SEARCH_UNARCHIVE_HIDDEN_OFFSET: usize = 6294;
pub const SEARCH_UNARCHIVE_UNATTACHED_OFFSET: usize = 6295;
pub const SEARCH_BROWSER_ENGINE_OFFSET: usize = 6297;
pub const SEARCH_USAGE_LOGIN_PRIMARY_OFFSET: usize = 6298;
pub const SEARCH_USAGE_LOGIN_INNE_OFFSET: usize = 6299;
pub const SEARCH_CUSTOMCMD_OFFSET: usize = 7200;
pub const SEARCH_STARRED_OFFSET: usize = 6377;
pub const SEARCH_WORKSPACE_BACK_OFFSET: usize = 6300;
pub const SEARCH_WORKSPACE_DELETE_OFFSET: usize = 6400;
pub const SEARCH_WSSORT_OFFSET: usize = 6470;
pub const SEARCH_WSMOVE_OFFSET: usize = 6480;
pub const SEARCH_WSMOVE_NEW_OFFSET: usize = 6489;
pub const SEARCH_WORKSPACE_OFFSET: usize = 6500;
pub const SEARCH_RENAMEWIN_OFFSET: usize = 7000;
pub const SEARCH_TABCTX_BACK: usize = 7100;
pub const SEARCH_TABCTX_RECONNECT: usize = 7101;
pub const SEARCH_TABCTX_MUTE: usize = 7102;
pub const SEARCH_TABCTX_KEEPALIVE: usize = 7103;
pub const SEARCH_TABCTX_WSMOVE: usize = 7104;
pub const SEARCH_TABCTX_GROUP_NEW: usize = 7105;
pub const SEARCH_TABCTX_GROUP_REMOVE: usize = 7106;
pub const SEARCH_TABCTX_GROUP_NEW_TAB_IN: usize = 7107;
pub const SEARCH_TABCTX_MOVE_NEW_WS: usize = 7108;
pub const SEARCH_TABCTX_CLEAR_SEL: usize = 7109;
pub const SEARCH_TABCTX_ARCHIVE: usize = 7110;
pub const SEARCH_TABCTX_BROWSER: usize = 7111;
pub const SEARCH_TABCTX_END_TMUX: usize = 7112;
pub const SEARCH_TABCTX_PIN_TOP: usize = 7113;
pub const SEARCH_TABCTX_KEEPAWAKE: usize = 7115;
pub const SEARCH_TABCTX_INBOX_EXCLUDE: usize = 7116;
pub const SEARCH_TABCTX_CHAT_RESET: usize = 7117;
pub const SEARCH_TABCTX_FAVORITE: usize = 7118;
pub const SEARCH_TABCTX_CHAT_STOP: usize = 7119;
pub const SEARCH_TABCTX_CHAT_ALLOW: usize = 7180;
pub const SEARCH_TABCTX_CHAT_ALWAYS: usize = 7181;
pub const SEARCH_TABCTX_CHAT_DENY: usize = 7182;
pub const SEARCH_TABCTX_CHAT_TAB_URL: usize = 7183;
pub const SEARCH_TABCTX_START_SESSION: usize = 7184;
pub const SEARCH_TABCTX_GROUP_ADD_OFFSET: usize = 7120;
pub const SEARCH_MOBILE_OFFSET: usize = 8000;
pub const SEARCH_ADDFAVICON_OFFSET: usize = 9000;
pub const SEARCH_ARCHIVED_OFFSET: usize = 7300;
pub const SEARCH_REMINDER_ROW_OFFSET: usize = 7400;
pub const MAX_SESSION_OVERVIEW_SEARCH_ROWS: usize = 256;
pub const SEARCH_SESSION_OVERVIEW_ROW_OFFSET: usize = 7500;
pub const SEARCH_SKILL_ROW_OFFSET: usize = 4100;
pub const MAX_PALETTE_SKILLS: usize = 512;
pub var g_search_results: [MAX_SHELLS + MAX_TMUX_SESSIONS + MAX_SESSION_OVERVIEW_SEARCH_ROWS + 128]usize = undefined;
pub var g_search_result_count: u32 = 0;

pub var g_shell_focused: bool = true;
var g_refocusing: bool = false;
pub var g_restoring: bool = false;
pub var g_nudge_repaint: bool = false;

pub var g_pending_new_tab_group: u32 = 0;

pub var g_pending_tmux_host: u8 = 0;
pub var g_pending_tmux_identity: ?[]const u8 = null;
pub var g_pending_chat_id: u64 = 0;
pub var g_pending_background_workspace: ?u8 = null;

pub const MAX_CUSTOM_CMDS: usize = 32;
pub const CustomCmd = struct {
    label: [80]u8 = std.mem.zeroes([80]u8),
    label_len: u32 = 0,
    workspace: [64]u8 = std.mem.zeroes([64]u8),
    workspace_len: u32 = 0,
    kind: ShellKind = .cmd,
    startup_cmd: [256]u8 = std.mem.zeroes([256]u8),
    startup_cmd_len: u32 = 0,
    cwd: [260]u8 = std.mem.zeroes([260]u8),
    cwd_len: u32 = 0,
    is_default: bool = false,
    alt_t: [128]u8 = std.mem.zeroes([128]u8),
    alt_t_len: u32 = 0,
};
pub var g_custom_cmds: [MAX_CUSTOM_CMDS]CustomCmd = std.mem.zeroes([MAX_CUSTOM_CMDS]CustomCmd);
pub var g_custom_cmds_count: u32 = 0;
pub var g_custom_cmds_mtime_lo: u32 = 0;
pub var g_custom_cmds_mtime_hi: u32 = 0;

pub const MAX_PALETTE_USAGE: usize = 128;
pub const PaletteUsage = struct {
    key: u64 = 0,
    count: u32 = 0,
    last_used: u64 = 0,
};
pub var g_palette_usage: [MAX_PALETTE_USAGE]PaletteUsage = [_]PaletteUsage{.{}} ** MAX_PALETTE_USAGE;
pub var g_palette_usage_count: u32 = 0;
pub const SEARCH_PALETTE_HEADER_OFFSET: usize = 11000;
pub const PALETTE_HEADER_COUNT: usize = 9;

pub var g_pending_spawn_cmd: [256]u8 = std.mem.zeroes([256]u8);
pub var g_pending_spawn_cmd_len: u32 = 0;

pub const MAX_SNIPPETS: usize = 32;
pub const SNIPPET_NAME_CAP: usize = 80;
pub const SNIPPET_TEXT_CAP: usize = 4096;
pub const Snippet = struct {
    name: [SNIPPET_NAME_CAP]u16 = std.mem.zeroes([SNIPPET_NAME_CAP]u16),
    name_len: u32 = 0,
    text: [SNIPPET_TEXT_CAP]u16 = std.mem.zeroes([SNIPPET_TEXT_CAP]u16),
    text_len: u32 = 0,
};
pub var g_snippets: [MAX_SNIPPETS]Snippet = std.mem.zeroes([MAX_SNIPPETS]Snippet);
pub var g_snippet_count: u32 = 0;
pub var g_snippets_mtime_lo: u32 = 0;
pub var g_snippets_mtime_hi: u32 = 0;

pub var g_cap_msg_until: u64 = 0;
pub var g_cap_msg_text: [128]u16 = std.mem.zeroes([128]u16);
pub var g_cap_msg_len: usize = 0;

const SpinMutex = struct {
    state: std.atomic.Value(u8) = std.atomic.Value(u8).init(0),

    pub fn tryLock(self: *SpinMutex) bool {
        return self.state.cmpxchgStrong(0, 1, .acquire, .monotonic) == null;
    }

    pub fn unlock(self: *SpinMutex) void {
        self.state.store(0, .release);
    }
};

pub const AiPaceStatus = enum(u8) {
    unavailable,
    stale,
    to_go,
    done,
};

pub const AiPaceProvider = enum(u8) {
    claude,
    codex,
    kimi,
    unknown,
};

pub const AiPace = enum(u8) {
    ahead,
    on_pace,
    behind,
};

pub const AiPaceGoal = struct {
    label: [128]u8 = std.mem.zeroes([128]u8),
    label_len: usize = 0,
    provider: AiPaceProvider = .unknown,
    available: bool = false,
    retrying: bool = false,
    has_daily_goal: bool = false,
    progress_tenths: u32 = 0,
    target_quota_tenths: u16 = 0,
    used_today_tenths: u16 = 0,
    remaining_today_tenths: u16 = 0,
    has_total_used: bool = false,
    total_used_tenths: u16 = 0,
    has_five_hour_used: bool = false,
    five_hour_used_tenths: u16 = 0,
    has_fable_used: bool = false,
    fable_used_tenths: u16 = 0,
    has_weekly_reset: bool = false,
    weekly_reset_filetime: u64 = 0,
    has_five_hour_reset: bool = false,
    five_hour_reset_filetime: u64 = 0,
    has_bonus_reset: bool = false,
    bonus_reset_filetime: u64 = 0,
    pace: AiPace = .on_pace,
    status: AiPaceStatus = .unavailable,
    cluster: [64]u8 = std.mem.zeroes([64]u8),
    cluster_len: usize = 0,
    in_ladder: bool = true,

    pub fn setCluster(self: *AiPaceGoal, value: []const u8) void {
        self.cluster_len = @min(value.len, self.cluster.len);
        @memcpy(self.cluster[0..self.cluster_len], value[0..self.cluster_len]);
    }

    pub fn clusterSlice(self: *const AiPaceGoal) []const u8 {
        return self.cluster[0..self.cluster_len];
    }

    pub fn shortLabel(self: *const AiPaceGoal) []const u8 {
        var l: []const u8 = self.labelSlice();
        const c = self.clusterSlice();
        if (c.len > 0 and l.len > c.len + 3 and l[l.len - 1] == ')' and std.mem.endsWith(u8, l[0 .. l.len - 1], c) and
            std.mem.endsWith(u8, l[0 .. l.len - 1 - c.len], " ("))
        {
            l = l[0 .. l.len - 1 - c.len - 2];
        }
        if (l.len > 0) return l;
        return switch (self.provider) {
            .claude => "Claude",
            .codex => "Codex",
            .kimi => "Kimi",
            .unknown => "AI",
        };
    }

    pub fn setLabel(self: *AiPaceGoal, value: []const u8) void {
        self.label_len = @min(value.len, self.label.len);
        @memcpy(self.label[0..self.label_len], value[0..self.label_len]);
    }

    pub fn labelSlice(self: *const AiPaceGoal) []const u8 {
        return self.label[0..self.label_len];
    }
};

pub const AiPaceSnapshot = struct {
    available: bool = false,
    goals: [4]AiPaceGoal = .{ .{}, .{}, .{}, .{} },
    goal_count: usize = 0,
    updated_tick: u64 = 0,
    from_ladder: bool = false,
    ladder_mode: u8 = 0,
    ladder_override: u8 = 0,
    ladder_why: [160]u8 = std.mem.zeroes([160]u8),
    ladder_why_len: usize = 0,
    ladder_dashboard: [200]u8 = std.mem.zeroes([200]u8),
    ladder_dashboard_len: usize = 0,
};

pub var g_ai_pace: AiPaceSnapshot = .{};
pub var g_ai_pace_pending: AiPaceSnapshot = .{};
pub var g_ai_pace_mutex: SpinMutex = .{};
pub var g_ai_pace_fetching = std.atomic.Value(bool).init(false);
pub var g_sidebar_status_card: u8 = 0;
pub var g_status_card_hover: bool = false;

pub const SHOT_PASTE_URL_CAP: usize = 640;
pub const SHOT_PASTE_QUEUE_CAP: usize = 16;
const ShotPasteEntry = struct {
    shell_id: u32 = 0,
    user_initiated: bool = false,
    url: [SHOT_PASTE_URL_CAP]u8 = std.mem.zeroes([SHOT_PASTE_URL_CAP]u8),
    url_len: usize = 0,
};
pub var g_shot_paste_mutex: SpinMutex = .{};
pub var g_shot_paste_queue: [SHOT_PASTE_QUEUE_CAP]ShotPasteEntry = [_]ShotPasteEntry{.{}} ** SHOT_PASTE_QUEUE_CAP;
pub var g_shot_paste_head: usize = 0;
pub var g_shot_paste_tail: usize = 0;
pub var g_shot_paste_count: usize = 0;

pub var g_dictation_recording = std.atomic.Value(bool).init(false);
pub var g_dictation_running = std.atomic.Value(bool).init(false);
pub var g_dictation_enter_stop_queued = std.atomic.Value(bool).init(false);
pub var g_dictation_send_queued = std.atomic.Value(bool).init(false);
pub var g_dictation_cancelled = std.atomic.Value(bool).init(false);
pub var g_dictation_escape_held: bool = false;
pub var g_dictation_mutex: SpinMutex = .{};
pub var g_dictation_transcript: [8192]u16 = std.mem.zeroes([8192]u16);
pub var g_dictation_transcript_len: usize = 0;
pub var g_dictation_draft_owner: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
pub var g_dictation_draft_owner_len: usize = 0;
pub var g_dictation_error: [160]u16 = std.mem.zeroes([160]u16);
pub var g_dictation_error_len: usize = 0;
pub var g_pending_tmux_cmd: [1024]u8 = std.mem.zeroes([1024]u8);
pub var g_pending_tmux_cmd_len: u32 = 0;
pub var g_pending_resurrect: [1024]u8 = std.mem.zeroes([1024]u8);
pub var g_pending_resurrect_len: u32 = 0;

pub var g_instance_name: [64]u8 = std.mem.zeroes([64]u8);
pub var g_instance_name_len: u32 = 0;
pub var g_explicit_instance_name: bool = false;
pub var g_no_window_restore: bool = false;
pub var g_empty_workspace: bool = false;
pub var g_current_workspace_restore: bool = true;
pub var g_workspace_restore_exclusive: bool = false;
pub var g_window_display_name: [64]u16 = std.mem.zeroes([64]u16);
pub var g_window_display_name_len: u32 = 0;
pub var g_window_display_name_u8: [64]u8 = std.mem.zeroes([64]u8);
pub var g_window_display_name_u8_len: u32 = 0;

pub const MAX_WORKSPACES: usize = 64;
pub const WorkspaceEntry = struct {
    id: [64]u8,
    id_len: u32,
    name: [64]u8,
    name_len: u32,
    restore: bool,
    host: [64]u8,
    host_len: u32,
};
pub var g_workspaces: [MAX_WORKSPACES]WorkspaceEntry = undefined;
pub var g_workspace_count: u32 = 0;

pub var g_adopt_hwnd: ?usize = null;
pub var g_adopt_pid: DWORD = 0;
pub var g_adopt_kind: u8 = 0;
pub var g_adopt_name: [64]u8 = std.mem.zeroes([64]u8);
pub var g_adopt_name_len: u32 = 0;
pub var g_adopt_cwd: [512]u8 = std.mem.zeroes([512]u8);
pub var g_adopt_cwd_len: u32 = 0;
pub var g_adopt_tmux: [64]u8 = std.mem.zeroes([64]u8);
pub var g_adopt_tmux_len: u32 = 0;
pub var g_adopt_tmux_identity: [64]u8 = @splat(0);
pub var g_adopt_tmux_identity_len: u32 = 0;
pub var g_adopt_name_source: NameSource = .default;
pub var g_adopt_muted: bool = false;
pub var g_adopt_pinned_top: bool = false;
pub var g_adopt_favorite: bool = false;
pub var g_adopt_last_used: u64 = 0;
pub var g_adopt_input: u64 = 0;
pub var g_adopt_visits: @import("frequent.zig").Visits = .{};

pub var g_job: HANDLE = null;
pub var g_tunnel_job: HANDLE = null;
pub var g_tunnel_keeper_processes: [3]HANDLE = [_]HANDLE{ null, null, null };
pub var g_tunnel_keeper_retry_after: [3]u64 = [_]u64{ 0, 0, 0 };
pub var g_tunnel_keeper_started_at: [3]u64 = [_]u64{ 0, 0, 0 };
pub var g_tunnel_keeper_failures: [3]u8 = [_]u8{ 0, 0, 0 };
pub var g_tunnel_probe_failures: [3]u8 = [_]u8{ 0, 0, 0 };
pub var g_tunnel_relay_mode: [3]std.atomic.Value(u32) = .{ .init(0), .init(0), .init(0) };
pub var g_graceful_exit: bool = false;
pub var g_quit_all_in_progress: bool = false;
pub var g_app_closing: bool = false;

pub const SPAWN_TITLE_CAP: usize = 1024;

var next_console_title_id: u32 = 1;

pub fn allocateShellId() ?u32 {
    return allocateShellIdFrom(&next_shell_id, shells[0..shell_count]);
}

fn allocateShellIdFrom(next: *u32, current: anytype) ?u32 {
    while (next.* != 0) {
        const id = next.*;
        next.* +%= 1;
        var used = false;
        for (current) |shell| {
            if (shell.shell_id == id) {
                used = true;
                break;
            }
        }
        if (!used) return id;
    }
    return null;
}

pub fn allocateConsoleTitleId() ?u32 {
    return allocateConsoleTitleIdFrom(&next_console_title_id, shells[0..shell_count]);
}

fn allocateConsoleTitleIdFrom(next: *u32, current: anytype) ?u32 {
    var used: [SPAWN_TITLE_CAP]bool = @splat(false);
    for (current) |shell| {
        if (shell.title_id < SPAWN_TITLE_CAP) used[shell.title_id] = true;
    }
    var candidate: u32 = if (next.* == 0 or next.* >= SPAWN_TITLE_CAP) 1 else next.*;
    for (1..SPAWN_TITLE_CAP) |_| {
        const id = candidate;
        candidate = if (candidate + 1 == SPAWN_TITLE_CAP) 1 else candidate + 1;
        if (!used[id]) {
            next.* = candidate;
            return id;
        }
    }
    return null;
}

test "ISSUE-511 shell ids never recycle after close and stop at exhaustion" {
    const Used = struct { shell_id: u32 };
    const current = [_]Used{ .{ .shell_id = 1 }, .{ .shell_id = 2 } };
    var next: u32 = 1;
    try std.testing.expectEqual(@as(?u32, 3), allocateShellIdFrom(&next, &current));
    const empty: []const Used = &.{};
    for (4..SPAWN_TITLE_CAP * 4) |expected| {
        try std.testing.expectEqual(@as(?u32, @intCast(expected)), allocateShellIdFrom(&next, empty));
    }
    next = std.math.maxInt(u32);
    try std.testing.expectEqual(@as(?u32, std.math.maxInt(u32)), allocateShellIdFrom(&next, empty));
    try std.testing.expectEqual(@as(?u32, null), allocateShellIdFrom(&next, empty));
}

test "ISSUE-511 console title ids wrap skip live titles and stay bounded" {
    const Used = struct { title_id: u32 = 0 };
    const current = [_]Used{ .{ .title_id = 1 }, .{ .title_id = 2 }, .{ .title_id = 1023 } };
    var next: u32 = 1023;
    try std.testing.expectEqual(@as(?u32, 3), allocateConsoleTitleIdFrom(&next, &current));
    for (0..SPAWN_TITLE_CAP * 4) |_| {
        const id = allocateConsoleTitleIdFrom(&next, &current).?;
        try std.testing.expect(id > 2 and id < SPAWN_TITLE_CAP - 1);
    }
    for ([_]u32{ 0, 1024, std.math.maxInt(u32) }) |invalid| {
        next = invalid;
        try std.testing.expectEqual(@as(?u32, 3), allocateConsoleTitleIdFrom(&next, &current));
    }
    var full: [SPAWN_TITLE_CAP - 1]Used = @splat(.{});
    for (&full, 1..) |*shell, id| shell.title_id = @intCast(id);
    try std.testing.expectEqual(@as(?u32, null), allocateConsoleTitleIdFrom(&next, &full));
    full[511].title_id = 0;
    try std.testing.expectEqual(@as(?u32, 512), allocateConsoleTitleIdFrom(&next, &full));
}

pub const SPAWN_TITLES = blk: {
    @setEvalBranchQuota(800000);
    var titles: [SPAWN_TITLE_CAP]LPCWSTR = undefined;
    for (0..SPAWN_TITLE_CAP) |i| {
        titles[i] = std.unicode.utf8ToUtf16LeStringLiteral(std.fmt.comptimePrint("ZigShell-{}", .{i}));
    }
    break :blk titles;
};

const KIND_LABELS = [_]LPCWSTR{ L("CMD"), L("PWSH"), L("VPS"), L("TMUX"), L("VPS") };

pub const KIND_PREFIXES = [_][]const u8{ "CMD ", "PWSH ", "VPS ", "TMUX ", "VPS ", "BASH ", "GITBASH " };

pub const AiRenameTitle = struct {
    name_start: usize,
    name_end: usize,
    label: []const u8,
    agent: AgentName,
};

pub const ExternalNameSyncState = struct {
    candidate: [64]u16 = std.mem.zeroes([64]u16),
    candidate_len: u8 = 0,
    streak: u8 = 0,
    blocked: [64]u16 = std.mem.zeroes([64]u16),
    blocked_len: u8 = 0,
};

const PROCESS_POLL_MAX_ENTRIES: usize = 2048;
const PROCESS_TREE_MAX_PIDS: usize = 256;

const ProcessPollEntry = struct {
    pid: DWORD,
    parent_pid: DWORD,
    exe: [32]u16,
    exe_len: u8,
};

pub const ProcessPollCache = struct {
    entries: [PROCESS_POLL_MAX_ENTRIES]ProcessPollEntry,
    count: usize,

    pub fn refresh(self: *ProcessPollCache) void {
        self.count = 0;

        const snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
        if (snap == null or snap == INVALID_HANDLE_VALUE_PTR) return;
        defer _ = CloseHandle(snap);

        var entry: PROCESSENTRY32W = undefined;
        entry.dwSize = @sizeOf(PROCESSENTRY32W);
        if (Process32FirstW(snap, &entry) == 0) return;

        while (true) {
            self.appendEntry(&entry);
            if (Process32NextW(snap, &entry) == 0) break;
        }
    }

    pub fn appendEntry(self: *ProcessPollCache, entry: *const PROCESSENTRY32W) void {
        if (self.count >= self.entries.len) return;

        var exe: [32]u16 = std.mem.zeroes([32]u16);
        var exe_len: usize = 0;
        while (exe_len < exe.len - 1 and entry.szExeFile[exe_len] != 0) : (exe_len += 1) {
            exe[exe_len] = entry.szExeFile[exe_len];
        }

        self.entries[self.count] = .{
            .pid = entry.th32ProcessID,
            .parent_pid = entry.th32ParentProcessID,
            .exe = exe,
            .exe_len = @intCast(exe_len),
        };
        self.count += 1;
    }

    pub fn findClaudeChildPid(self: *const ProcessPollCache, parent_pid: DWORD) ?DWORD {
        const names = [_][]const u8{"claude.exe"};
        return self.findProcessTreeExe(parent_pid, names[0..]);
    }

    pub fn findProcessTreeExe(self: *const ProcessPollCache, parent_pid: DWORD, names: []const []const u8) ?DWORD {
        if (parent_pid == 0) return null;

        var pids: [PROCESS_TREE_MAX_PIDS]DWORD = undefined;
        pids[0] = parent_pid;
        var pid_count: usize = 1;
        var scan_idx: usize = 0;

        while (scan_idx < pid_count) {
            const parent = pids[scan_idx];
            scan_idx += 1;

            for (self.entries[0..self.count]) |entry| {
                if (entry.parent_pid != parent or entry.pid == parent) continue;

                const exe_len: usize = @intCast(entry.exe_len);
                const exe = entry.exe[0..exe_len];
                for (names) |name| {
                    if (u16ExeNameMatches(exe, name)) return entry.pid;
                }

                if (pid_count < pids.len and !pidListContains(pids[0..pid_count], entry.pid)) {
                    pids[pid_count] = entry.pid;
                    pid_count += 1;
                }
            }
        }

        return null;
    }

    pub fn processTreeRamMB(self: *const ProcessPollCache, root_pid: DWORD) u32 {
        if (root_pid == 0) return 0;
        const getMemInfo = g_K32GetProcessMemoryInfo orelse return 0;

        var pids: [PROCESS_TREE_MAX_PIDS]DWORD = undefined;
        const pid_count = self.collectProcessTree(root_pid, &pids);
        if (pid_count == 0) return 0;

        var total_bytes: u64 = 0;
        for (pids[0..pid_count]) |pid| {
            const proc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, pid);
            if (proc == null) continue;

            var mc: PROCESS_MEMORY_COUNTERS = std.mem.zeroes(PROCESS_MEMORY_COUNTERS);
            mc.cb = @sizeOf(PROCESS_MEMORY_COUNTERS);
            if (getMemInfo(proc, &mc, @sizeOf(PROCESS_MEMORY_COUNTERS)) != 0) {
                total_bytes += mc.WorkingSetSize;
            }
            _ = CloseHandle(proc);
        }

        const mb = (total_bytes + 512 * 1024) / (1024 * 1024);
        return @intCast(@min(mb, 99999));
    }

    fn collectProcessTree(self: *const ProcessPollCache, root_pid: DWORD, out: *[PROCESS_TREE_MAX_PIDS]DWORD) usize {
        if (root_pid == 0) return 0;
        out[0] = root_pid;
        var pid_count: usize = 1;
        var scan_idx: usize = 0;

        while (scan_idx < pid_count) {
            const parent = out[scan_idx];
            scan_idx += 1;

            for (self.entries[0..self.count]) |entry| {
                if (entry.parent_pid != parent or entry.pid == parent) continue;
                if (pid_count >= out.len) return pid_count;
                if (pidListContains(out[0..pid_count], entry.pid)) continue;
                out[pid_count] = entry.pid;
                pid_count += 1;
            }
        }

        return pid_count;
    }
};

pub const FindWorkspaceWinCtx = struct {
    id: []const u8,
    name: []const u8,
    found: HANDLE,
};

pub const LiveWsWin = struct {
    hwnd: usize,
    id: [64]u8,
    id_len: u32,
    single: bool,
    slot_count: u8,
    slot_ids: [MAX_LWS][32]u8,
    slot_id_len: [MAX_LWS]u32,
    slots: [MAX_LWS]u8,
};
pub var g_live_ws: [16]LiveWsWin = undefined;
pub var g_live_ws_count: u8 = 0;
pub var g_live_ws_tick: u64 = 0;

pub const LiveWsTarget = struct { hwnd: usize, slot: i32 };

pub var g_verbose_logging_known: bool = false;
pub var g_verbose_logging_enabled: bool = false;

pub var g_debug_log_mutex: SpinMutex = .{};

pub var g_pollshell_count: u64 = 0;

pub var g_account_locked = @import("account_state.zig").startupLocked();
pub var g_account_bypass = false;
pub var g_account_bootstrapping = true;
pub var g_account_busy = false;
pub var g_account_has_token = false;
pub var g_account_reauth = false;
pub var g_account_login_active = false;
pub var g_account_cancel = std.atomic.Value(bool).init(false);
pub var g_account_retry: account_state.Retry = .{};
pub var g_account_access: account_state.Access = .{};
pub var g_account_instance_mutex: HANDLE = null;
pub var g_account_applying = false;
pub var g_account_base: ?[]u8 = null;
pub var g_account_local_base: ?[]u8 = null;
pub var g_account_dirty_at: u64 = 0;
pub var g_account_status: []const u8 = "Sign in to multiprompt to open your workspaces.";
pub const TIMER_ACCOUNT: usize = 170;
pub const TIMER_FONT_SYNC: usize = 190;
pub const TIMER_UPDATE_CHECK: usize = 172;
pub const TIMER_ACCOUNT_SAVE: usize = 171;
pub const AccountJobKind = enum { startup, login, pull, push, devices, revoke, signout, device_keys, decide_keys, remove_host };
pub const AccountJob = struct { kind: AccountJobKind, slot: ?u8 = null, base: ?[]u8 = null, edited: ?[]u8 = null, device: ?[]u8 = null, credential: ?[]u8 = null };
pub const LayoutReply = struct { job: AccountJob, bytes: ?[]u8 = null, unauthorized: bool = false, signed_out: bool = false, has_token: bool = false, cancelled: bool = false, device_keys: ?[]u8 = null, key_error: ?[]u8 = null };
pub const AccountClosed = struct { host: u8 = 0, len: u8 = 0, session: [64]u8 = undefined };
pub var g_account_closed: [MAX_SHELLS]AccountClosed = undefined;
pub var g_account_closed_count: usize = 0;

pub const SavedTab = struct {
    shell_id: u32 = 0,
    chat_id: u64 = 0,
    last_read_message_id: u64 = 0,
    sync_owned: bool = false,
    kind: ShellKind,
    name: [64]u16,
    name_len: u32,
    manual: bool,
    sem: bool,
    tmux_session: [64]u8,
    tmux_session_len: u32,
    tmux_identity: [64]u8 = @splat(0),
    tmux_identity_len: u32 = 0,
    cwd: [512]u8,
    cwd_len: u32,
    claude_session: bool,
    wake_id: u32 = 0,
    pid: DWORD,
    muted: bool,
    keep_alive: bool,
    pinned_top: bool = false,
    inbox_excluded: bool = false,
    favorite: bool = false,
    last_used: u64 = 0,
    input: u64 = 0,
    visits: @import("frequent.zig").Visits = .{},
    favicon_path: [512]u8,
    favicon_path_len: u32,
    group_id: u32,
    starred_group_id: u32 = 0,
    tmux_host: u8,
    workspace: u8 = 0,
    last_active: u64 = 0,
    last_viewed: u64 = 0,
    claude_sid: [40]u8 = std.mem.zeroes([40]u8),
    claude_sid_len: u32 = 0,
    claude_cwd: [192]u8 = std.mem.zeroes([192]u8),
    claude_cwd_len: u32 = 0,
    bon: bool = false,
    inbox_archived: bool = false,
    archive_time: u64 = 0,
    archive_done: u64 = 0,
    last_done_time: u64 = 0,
    last_done_content: archive_rules.Content = .{},
    last_done_content_valid: bool = false,
    archive_content: archive_rules.Content = .{},
    archive_content_valid: bool = false,
    needs_attention: bool = false,
    burl: [512]u8 = std.mem.zeroes([512]u8),
    burl_len: u32 = 0,
    bnat: bool = true,
    bsplit_permille: u16 = BROWSER_SPLIT_DEFAULT_PERMILLE,
    kaw: bool = false,
    cv: bool = false,
    cso: bool = false,
    fw: bool = false,
};

pub const ISSUE_347_KEEP_FULL_WIDTH = true;
pub const ISSUE_440_FULL_WIDTH_CHAT = true;
pub const ISSUE_274_DOT_ON_SELECTED_TAB = true;

pub var g_restored_valid_session = false;

pub const FindConsolePidCtx = struct {
    target_pid: DWORD,
    found_hwnd: ?HANDLE,
};

pub const FindClassPidCtx = struct {
    target_pid: DWORD,
    class_name: []const u8,
    found_hwnd: ?HANDLE,
};

pub var g_font_gen: u32 = 0;
pub var g_font_sync_started: u64 = 0;
pub var g_font_sync_done: u32 = 0;
pub const FONT_SYNC_TICK_MS: UINT = 150;

pub const WM_CLOSE: u32 = 0x0010;
pub const WM_PARENTNOTIFY: u32 = 0x0210;

pub const OtherZigShellCtx = struct {
    current: HANDLE,
    found: bool,
};

pub const ZigShellWindowList = struct {
    current: HANDLE,
    hwnds: [MAX_WORKSPACES]HANDLE,
    count: u32,
};

pub const SSH_OPTS = "-o ServerAliveInterval=15 -o ServerAliveCountMax=4 ";
pub const SSH_OPTS_MOBILE = "-o Compression=yes -o IPQoS=lowdelay -o ServerAliveInterval=15 -o ServerAliveCountMax=4 ";
pub const SSH_OPTS_MOBILE_BATTERY = "-o Compression=yes -o IPQoS=lowdelay -o ServerAliveInterval=20 -o ServerAliveCountMax=4 ";
pub const SSH_HOST_DE = "-t remote-1";
pub const SSH_HOST_UK = "-t remote-2";
pub const SSH_HOST_INNE = "-t remote-3";
pub const SSH_TARGET_DE = "remote-1";
pub const SSH_TARGET_UK = "remote-2";
pub const SSH_TARGET_INNE = "remote-3";
pub const TMUX_HOST_DE: u8 = 0;
pub const TMUX_HOST_UK: u8 = 1;
pub const TMUX_HOST_INNE: u8 = 2;
pub const SSH_TERM = "xterm-256color";
pub const SSH_COLORTERM = "truecolor";
pub const SSH_TUNNEL_KEEPER_OPTS = "-N -o BatchMode=yes -o ExitOnForwardFailure=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=3 ";
pub const SSH_TUNNEL_KEEPER_OPTS_BATTERY = "-N -o BatchMode=yes -o ExitOnForwardFailure=yes -o ConnectTimeout=10 -o ServerAliveInterval=45 -o ServerAliveCountMax=3 ";

pub const SSH_ERROR_MODE: DWORD = 0x0001 | 0x8000;

pub var g_ssh_path: [520]u8 = undefined;
pub var g_ssh_path_len: usize = 0;
pub var g_ssh_resolved = false;
pub var g_ssh_mutex: SpinMutex = .{};
pub var g_ssh_notice_sent = false;

pub var g_voice_sapi: ?*ISpVoice = null;
pub var g_voice_com_initialized: bool = false;

pub const DEEPGRAM_TTS_MODEL = "aura-2-thalia-en";
pub const DEEPGRAM_TTS_SAMPLE_RATE: DWORD = 24000;

pub const VoiceSpeed = enum { s100, s125, s140, s150 };
pub var g_voice_speed: VoiceSpeed = .s125;
pub const VOICE_SPEED_DEFAULT: VoiceSpeed = .s125;
pub const DEEPGRAM_TTS_CHAR_LIMIT: usize = 2000;
pub const DEEPGRAM_TTS_MAX_CHUNKS: usize = 16;
pub const DEEPGRAM_TTS_MAX_PCM_BYTES: usize = 12 * 1024 * 1024;
pub const VOICE_TTS_SLICE_BYTES: usize = 24000;
pub const VOICE_TTS_READ_BYTES: usize = 65536;

pub const VoiceTtsBuffer = struct { header: WAVEHDR, pcm: []u8 };
pub const TtsChunkRange = struct { start: usize, end: usize };

pub var g_voice_clean_wide: [24576]u16 = undefined;

pub const ArchivedEntry = struct {
    name: [64]u8 = std.mem.zeroes([64]u8),
    name_len: u32 = 0,
    tmux_session: [64]u8 = std.mem.zeroes([64]u8),
    tmux_session_len: u32 = 0,
    tmux_identity: [64]u8 = @splat(0),
    tmux_identity_len: u32 = 0,
    tmux_host: u8 = 0,
    claude_sid: [40]u8 = std.mem.zeroes([40]u8),
    claude_sid_len: u32 = 0,
    claude_cwd: [192]u8 = std.mem.zeroes([192]u8),
    claude_cwd_len: u32 = 0,
};
pub var g_archived: std.ArrayList(ArchivedEntry) = .empty;
pub var g_archived_count: usize = 0;
pub var g_archive_loaded: bool = false;
pub var g_archive_mtime_lo: u32 = 0;
pub var g_archive_mtime_hi: u32 = 0;

pub const SnippetFormLayout = struct {
    ox: i32,
    oy: i32,
    w: i32,
    h: i32,
    name_label: RECT,
    name_edit: RECT,
    text_label: RECT,
    text_edit: RECT,
    save_btn: RECT,
    cancel_btn: RECT,
};

pub const MAX_REMINDERS: usize = 64;
pub const ReminderEntry = struct {
    name: [64]u8 = std.mem.zeroes([64]u8),
    name_len: u32 = 0,
    tmux_session: [64]u8 = std.mem.zeroes([64]u8),
    tmux_session_len: u32 = 0,
    tmux_identity: [64]u8 = @splat(0),
    tmux_identity_len: u32 = 0,
    tmux_host: u8 = 0,
    claude_sid: [40]u8 = std.mem.zeroes([40]u8),
    claude_sid_len: u32 = 0,
    claude_cwd: [192]u8 = std.mem.zeroes([192]u8),
    claude_cwd_len: u32 = 0,
    workspace_id: [64]u8 = std.mem.zeroes([64]u8),
    workspace_id_len: u32 = 0,
    workspace_name: [64]u8 = std.mem.zeroes([64]u8),
    workspace_name_len: u32 = 0,
    due_at: u64 = 0,
    created_at: u64 = 0,
    tmux_persisted: bool = false,
    workspace_marker: bool = false,
    snapshot: bool = false,
    waking: bool = false,
    batch_due: u64 = 0,
    local_kind: u8 = 0,
    order: u32 = 0,
    wide_name: [64]u16 = std.mem.zeroes([64]u16),
    wide_name_len: u32 = 0,
    group_id: u32 = 0,
    starred_group_id: u32 = 0,
    starred_group: ?TabGroup = null,
    group_name: [64]u16 = std.mem.zeroes([64]u16),
    group_name_len: u32 = 0,
    group_color: u8 = 7,
    group_color_set: bool = false,
    group_collapsed: bool = false,
    pinned_top: bool = false,
    favorite: bool = false,
    last_used: u64 = 0,
    input: u64 = 0,
    visits: @import("frequent.zig").Visits = .{},
};
pub var g_reminders: [MAX_REMINDERS]ReminderEntry = std.mem.zeroes([MAX_REMINDERS]ReminderEntry);
pub var g_reminder_count: u32 = 0;
pub var g_reminders_loaded: bool = false;

pub var g_reminders_load_ok: bool = false;
pub var g_reminders_bad_reads: u32 = 0;
pub var g_reminders_bad_read_ms: u64 = 0;

pub const MAX_RECORDED_SESSIONS: usize = 64;

pub const WEEKDAY_NAMES = [_][]const u8{ "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" };

pub var g_favicon_fetching: bool = false;
pub var g_favicon_fetch_pipe: HANDLE = null;
pub var g_favicon_fetch_process: HANDLE = null;
pub var g_favicon_fetch_shell_id: u32 = 0;
pub var g_favicon_fetch_local_path: [512]u8 = std.mem.zeroes([512]u8);
pub var g_favicon_fetch_local_len: u32 = 0;

pub const VPS_CHANNEL_SENTINEL = "@@ZS_END@@\n";
pub const VPS_CHANNEL_RESPAWN_BACKOFF_MS: u64 = 60_000;
pub const VPS_CHANNEL_READ_TIMEOUT_MS: u64 = 8_000;
pub const HANDLE_FLAG_INHERIT: DWORD = 0x00000001;

pub const VpsChannel = struct {
    process: HANDLE = null,
    stdin_write: HANDLE = null,
    stdout_read: HANDLE = null,
    alive: bool = false,
    last_spawn_attempt: u64 = 0,
};
pub var g_vps_channels: [3]VpsChannel = .{ .{}, .{}, .{} };
pub var g_vps_channel_mutex: SpinMutex = .{};
pub var g_vps_channels_close_pending = std.atomic.Value(bool).init(false);

pub var g_ac_channels: [3]VpsChannel = .{ .{}, .{}, .{} };
pub var g_ac_channel_mutex: SpinMutex = .{};
pub var g_ac_channels_close_pending = std.atomic.Value(bool).init(false);
pub const AC_SENTINEL = "@@MP_END@@\n";

pub const VPS_PROBE_SCRIPT =
    "printf '@capacity|'; " ++
    "getconf _NPROCESSORS_ONLN 2>/dev/null | tr '\\n' '|'; " ++
    "cut -d' ' -f1 /proc/loadavg 2>/dev/null | tr '\\n' '|'; " ++
    "grep '^MemTotal:' /proc/meminfo | tr -s ' ' | cut -d' ' -f2 | tr '\\n' '|'; " ++
    "grep '^MemAvailable:' /proc/meminfo | tr -s ' ' | cut -d' ' -f2 | tr '\\n' '|'; " ++
    "grep '^SwapTotal:' /proc/meminfo | tr -s ' ' | cut -d' ' -f2 | tr '\\n' '|'; " ++
    "grep '^SwapFree:' /proc/meminfo | tr -s ' ' | cut -d' ' -f2 | tr '\\n' '|'; " ++
    "(head -1 /proc/pressure/cpu 2>/dev/null || printf 'some avg10=0.00') | cut -d' ' -f2 | cut -d= -f2 | tr '\\n' '|'; " ++
    "(head -1 /proc/pressure/memory 2>/dev/null || printf 'some avg10=0.00') | cut -d' ' -f2 | cut -d= -f2 | tr '\\n' '|'; " ++
    "(head -1 /proc/pressure/io 2>/dev/null || printf 'some avg10=0.00') | cut -d' ' -f2 | cut -d= -f2 | tr '\\n' '|'; " ++
    "printf '\\n'; ";
pub const VPS_TMUX_LIST_SCRIPT = "~/.local/bin/tmux-list.sh 2>/dev/null || tmux list-sessions -F '#{session_name}|#{session_activity}|0|#{session_path}|#{pane_current_command}|#{pane_title}' 2>/dev/null";

pub var g_vps_poll_leader_mutex: HANDLE = null;
pub var g_vps_poll_is_leader: bool = false;
pub var g_vps_poll_cache_mtime_lo: DWORD = 0;
pub var g_vps_poll_cache_mtime_hi: DWORD = 0;

pub var g_inactive_filtered: [MAX_TMUX_SESSIONS]u32 = undefined;
pub var g_inactive_filtered_count: u32 = 0;

pub const WorkspaceRepoCandidate = struct {
    host: u8 = 0,
    path: [256]u8 = std.mem.zeroes([256]u8),
    path_len: u32 = 0,
    score: u32 = 0,
    last_active: u64 = 0,
};

pub const SessionOverviewKind = enum(u8) { open, hidden, reminder, vps_only, archived };

pub const SessionOverviewRow = struct {
    kind: SessionOverviewKind = .open,
    shell_id: u32 = 0,
    ref_idx: u32 = 0,
    snapshot_order: ?u32 = null,
    host: u8 = 0,
    activity: u8 = 0,
    attention: bool = false,
    last_active: u64 = 0,
    name: [96]u8 = std.mem.zeroes([96]u8),
    name_len: u32 = 0,
    session: [64]u8 = std.mem.zeroes([64]u8),
    session_len: u32 = 0,
    context: [64]u8 = std.mem.zeroes([64]u8),
    context_len: u32 = 0,
    workspace: u8 = 0,
    ram_mb: u32 = 0,
    agent: u8 = 0,
    stale_candidate: bool = false,
};

pub var g_session_overview_rows: std.ArrayList(SessionOverviewRow) = .empty;
pub var g_session_overview_count: u32 = 0;
pub var g_session_overview_repo_ok: bool = false;
pub var g_session_overview_repo_host: u8 = 0;
pub var g_session_overview_repo_path: [256]u8 = std.mem.zeroes([256]u8);
pub var g_session_overview_repo_len: u32 = 0;
pub var g_all_sessions_active: bool = false;
pub var g_all_sessions_ctx: bool = false;
pub var g_all_sessions_unattached_only: bool = false;
pub const AllSessionsCloseTarget = struct {
    host: u8 = 0,
    session: [64]u8 = std.mem.zeroes([64]u8),
    session_len: u32 = 0,
    agent: bool = false,
};
pub const ALL_SESSIONS_CLOSE_MAX: usize = 64;
pub var g_all_sessions_marks: [ALL_SESSIONS_CLOSE_MAX]AllSessionsCloseTarget = [_]AllSessionsCloseTarget{.{}} ** ALL_SESSIONS_CLOSE_MAX;
pub var g_all_sessions_mark_count: u32 = 0;
pub var g_all_sessions_confirm: bool = false;
pub var g_all_sessions_close_queue: [ALL_SESSIONS_CLOSE_MAX]AllSessionsCloseTarget = [_]AllSessionsCloseTarget{.{}} ** ALL_SESSIONS_CLOSE_MAX;
pub var g_all_sessions_close_count: u32 = 0;
pub var g_all_sessions_close_next: u32 = 0;
pub var g_all_sessions_close_done: u32 = 0;
pub var g_all_sessions_close_failed: u32 = 0;
pub var g_all_sessions_close_running: bool = false;
pub var g_all_sessions_filter_active: bool = false;
pub var g_all_sessions_filter_buf: [64]u16 = std.mem.zeroes([64]u16);
pub var g_all_sessions_filter_len: u32 = 0;
pub var g_archive_arm_sid: u32 = 0;
pub var g_archive_arm_deadline: u64 = 0;
pub var g_all_sessions_sel: u32 = 0;
pub const AS_TAB_ALL: u32 = 200;
pub const AS_TAB_OTHER: u32 = 201;
pub const AS_TAB_WAITING: u32 = 202;
pub const AS_TAB_ARCHIVED: u32 = 203;
pub const AS_ROW_OTHER: u8 = 0xFF;
pub var g_all_sessions_tab: u32 = AS_TAB_ALL;
pub var g_all_sessions_g_tick: u64 = 0;
pub const ALL_SESSIONS_TAB_COUNT: usize = @as(usize, MAX_LWS) + 4;
pub var g_all_sessions_split_xs: [ALL_SESSIONS_TAB_COUNT]i32 = [_]i32{0} ** ALL_SESSIONS_TAB_COUNT;
pub var g_all_sessions_split_xe: [ALL_SESSIONS_TAB_COUNT]i32 = [_]i32{0} ** ALL_SESSIONS_TAB_COUNT;
pub var g_all_sessions_split_ids: [ALL_SESSIONS_TAB_COUNT]u32 = [_]u32{0} ** ALL_SESSIONS_TAB_COUNT;
pub var g_all_sessions_split_tab_count: usize = 0;

const UnarchiveUnattachedItem = struct {
    host: u8 = 0,
    session: [64]u8 = std.mem.zeroes([64]u8),
    session_len: u32 = 0,
};
pub var g_unarchive_unattached_queue: [MAX_SHELLS]UnarchiveUnattachedItem = [_]UnarchiveUnattachedItem{.{}} ** MAX_SHELLS;
pub var g_unarchive_unattached_count: u32 = 0;
pub var g_unarchive_unattached_next: u32 = 0;
pub var g_unarchive_unattached_attached: u32 = 0;
pub var g_unarchive_unattached_failed: u32 = 0;
pub var g_unarchive_unattached_workspace: u8 = 0;

pub const OTHER_WORKSPACE_NAME = "Other";

pub const SplitWorkspaceEntry = struct {
    id: [32]u8 = std.mem.zeroes([32]u8),
    id_len: u32 = 0,
    name: [32]u8 = std.mem.zeroes([32]u8),
    name_len: u32 = 0,
};

pub const VK_MENU: u8 = 0x12;
pub const KEYEVENTF_KEYUP: DWORD = 0x0002;

pub const BrowserLayout = struct {
    console_x: i32,
    console_y: i32,
    console_w: i32,
    console_h: i32,
    browser_x: i32,
    browser_y: i32,
    browser_w: i32,
    browser_h: i32,
    splitter_left: i32,
    splitter_right: i32,
    splitter_top: i32,
    splitter_bottom: i32,
    urlbar_x: i32,
    urlbar_y: i32,
    urlbar_w: i32,
    urlbar_h: i32,
};

pub const ConsoleColumn = struct { left: i32, width: i32 };

pub const BrowserAdoptCtx = struct {
    found_hwnd: HANDLE = null,
};

pub var g_bridge_exe_buf: [512]u8 = undefined;
pub var g_bridge_exe_len: usize = 0;

pub const BrowserResolveJob = struct {
    shell_id: u32,
    profile: [32]u8 = std.mem.zeroes([32]u8),
    nonce: [40]u8 = std.mem.zeroes([40]u8),
    nonce_len: usize = 0,
    connection_id: u64 = 0,
    window_id: i64 = 0,
};

pub const BrowserResolveInflight = struct {
    shell_id: u32 = 0,
    started: u64 = 0,
    nonce: [40]u8 = std.mem.zeroes([40]u8),
    nonce_len: usize = 0,
};

pub var g_browser_resolve_inflight: [16]BrowserResolveInflight = [_]BrowserResolveInflight{.{}} ** 16;
pub const BROWSER_RESOLVE_STALE_MS: u64 = 10_000;
pub const BROWSER_RESOLVE_RETRY_BUDGET_MS: u64 = 120_000;

pub const CancelledBrowserLaunch = struct {
    nonce: [40]u8 = std.mem.zeroes([40]u8),
    nonce_len: usize = 0,
    deadline: u64 = 0,
};

pub var g_cancelled_browser_launches: [MAX_SHELLS]CancelledBrowserLaunch = [_]CancelledBrowserLaunch{.{}} ** MAX_SHELLS;

pub const BrowserDockJob = struct {
    shell_id: u32,
    hwnd: HANDLE,
    owner: HANDLE,
    foreground_launch: bool,
    beacon_was_foreground: bool,
};

pub const BROWSER_PARK_X: i32 = -32000;
pub const BROWSER_PARK_Y: i32 = -32000;

pub const BROWSER_CRASH_RELAUNCH_DELAY_MS: u64 = 1500;
pub const BROWSER_HUNG_MISS_LIMIT: u8 = 2;

pub var g_browser_orphan_sweep_tick: u64 = 0;
pub var g_updating_browser_visibility: bool = false;
pub var g_browser_switch_preparing: bool = false;

pub const BROWSER_PLACEHOLDER_NOT_OPEN_MS: u64 = 20_000;

pub const BrowserPlaceholder = enum { none, opening, not_open, failed };

pub var g_slot_placeholder_shell_id: u32 = 0;
pub var g_slot_placeholder_since: u64 = 0;

const WebView2CreateFn = *const fn (HANDLE, [*:0]const u16) callconv(WINAPI) HRESULT;
const WebView2SetBoundsFn = *const fn (i32, i32, i32, i32) callconv(WINAPI) void;
const WebView2FocusFn = *const fn () callconv(WINAPI) void;
const WebView2CloseFn = *const fn () callconv(WINAPI) void;
const WebView2SetVisibleFn = *const fn (BOOL) callconv(WINAPI) void;
const WebView2NavigateFn = *const fn ([*:0]const u16) callconv(WINAPI) void;
const WebView2ActionFn = *const fn () callconv(WINAPI) void;
const WebView2OpenTabFn = *const fn ([*:0]const u16, BOOL) callconv(WINAPI) BOOL;
const WebView2CycleTabFn = *const fn (BOOL) callconv(WINAPI) i32;
const WebView2CloseTabFn = *const fn () callconv(WINAPI) i32;
const WebView2HasFocusFn = *const fn () callconv(WINAPI) BOOL;
const WebView2GetHostFn = *const fn () callconv(WINAPI) HANDLE;

pub var g_webview2_module: HANDLE = null;
pub var g_webview2_create: ?WebView2CreateFn = null;
pub var g_webview2_set_bounds: ?WebView2SetBoundsFn = null;
pub var g_webview2_focus: ?WebView2FocusFn = null;
pub var g_webview2_close: ?WebView2CloseFn = null;
pub var g_webview2_set_visible: ?WebView2SetVisibleFn = null;
pub var g_webview2_navigate: ?WebView2NavigateFn = null;
pub var g_webview2_back: ?WebView2ActionFn = null;
pub var g_webview2_forward: ?WebView2ActionFn = null;
pub var g_webview2_reload: ?WebView2ActionFn = null;
pub var g_webview2_open_tab: ?WebView2OpenTabFn = null;
pub var g_webview2_next_tab: ?WebView2CycleTabFn = null;
pub var g_webview2_close_tab: ?WebView2CloseTabFn = null;
pub var g_webview2_has_focus: ?WebView2HasFocusFn = null;
pub var g_webview2_get_host: ?WebView2GetHostFn = null;
pub var g_webview2_active: bool = false;
pub var g_webview2_owner_shell_id: u32 = 0;
pub var g_webview2_focus_retries: u8 = 0;

pub const ChatViewLayout = struct {
    pane: RECT,
    transcript: RECT,
    transcript_window: RECT,
    composer_card: RECT,
    composer: RECT,
    send_btn: RECT,
    attach_btn: RECT,
    mic_btn: RECT,
    stop_btn: RECT,
    send_shown: bool,
    stop_shown: bool,
};

pub const CHAT_SUMMARY_VERBS = [_][]const u8{
    "searched for", "read", "ran", "edited", "wrote", "listed", "fetched", "updated", "created", "found",
};

const ChatGlyphMap = struct { from: u16, to: u16 };

pub const CHAT_DISPLAY_GLYPH_MAP = [_]ChatGlyphMap{
    .{ .from = 0x25CF, .to = 0x2022 },
    .{ .from = 0x23FA, .to = 0x2022 },
    .{ .from = 0x273B, .to = '*' },
    .{ .from = 0x2733, .to = '*' },
    .{ .from = 0x2736, .to = '*' },
    .{ .from = 0x2722, .to = '*' },
    .{ .from = 0x276F, .to = 0x203A },
    .{ .from = 0x25B8, .to = '>' },
    .{ .from = 0x25C2, .to = '<' },
    .{ .from = 0x2500, .to = '-' },
    .{ .from = 0x2501, .to = '-' },
    .{ .from = 0x2550, .to = '-' },
    .{ .from = 0x254C, .to = '-' },
    .{ .from = 0x254D, .to = '-' },
    .{ .from = 0x2594, .to = '-' },
    .{ .from = 0x2581, .to = '-' },
    .{ .from = 0x2502, .to = '|' },
    .{ .from = 0x2514, .to = '+' },
    .{ .from = 0x2518, .to = '+' },
    .{ .from = 0x250C, .to = '+' },
    .{ .from = 0x2510, .to = '+' },
    .{ .from = 0x251C, .to = '+' },
    .{ .from = 0x2524, .to = '+' },
    .{ .from = 0x252C, .to = '+' },
    .{ .from = 0x2534, .to = '+' },
    .{ .from = 0x253C, .to = '+' },
    .{ .from = 0x256D, .to = '+' },
    .{ .from = 0x256E, .to = '+' },
    .{ .from = 0x256F, .to = '+' },
    .{ .from = 0x2570, .to = '+' },
    .{ .from = 0x23BF, .to = '+' },
};

pub const CHAT_STATUS_MARKERS = [_]u16{ 0x2022, 0x25CF, 0x23FA, 0x273B, 0x2733, 0x2736, 0x2722, 0x2737, 0x273D, 0x2734, 0x2217, 0x00B7, '*' };

pub var g_chat_bench_dir: [400]u8 = @splat(0);
pub var g_chat_bench_dir_len: usize = 0;
pub var g_chat_bench_seq: u32 = 0;
pub var g_chat_bench_started: u64 = 0;
pub var g_chat_bench_first_paint: bool = false;
pub var g_chat_bench_content_paint: bool = false;
pub const TIMER_CHAT_BENCH: usize = 0xB311;

pub const ChatLayoutSnapshot = struct {
    content_hash: u64,
    stable_text: usize,
    stable_blocks: usize,
    width: i32,
    scale: i32,
    top_pad: i32,
    font_pt: i32,
    clean: bool,
    boundary: chat_history.ReadBoundary,
    img_first_block: usize,
    first_image: usize,
    read_divider_y: i32,
    rects: []RECT,
};
pub const ChatHistoryEntry = struct {
    key: chat_transcript.Identity,
    layout: ?ChatLayoutSnapshot = null,
    generation: u64 = 0,
    history: chat_history.History = .{},
    backfill: chat_history.Backfill = .{},
    staged: bool = false,
    stalled: bool = false,
    show_older: bool = false,
    tables: chat_markdown.TableCache = .{},
    pending: bool = false,
    retired: bool = false,
    cache_cancelled: std.atomic.Value(bool) = .init(false),
    loaded_ms: i64 = 0,
    disk_loaded: bool = false,
    loading_disk: bool = false,
    before: u64 = 0,
    prepended: bool = false,
    cache_written: u64 = 0,
    cache_dirty: bool = false,
    unchanged: bool = false,
    incremental: bool = false,
    failures: u8 = 0,
    missing_message: [256]u16 = @splat(0),
    result_missing: [256]u16 = @splat(0),
    next: u64 = 0,
    ready: std.atomic.Value(bool) = .init(false),
    result: ?chat_history.History = null,

    pub fn clearLayout(self: *ChatHistoryEntry) void {
        const snapshot = self.layout orelse return;
        std.heap.page_allocator.free(snapshot.rects);
        self.layout = null;
    }
};
pub var g_chat_received: chat_markdown.BlockCache = .{};
pub var g_chat_tables: chat_markdown.TableCache = .{};
pub var g_chat_tables_shell_id: u32 = 0;
pub var g_chat_histories: std.ArrayList(*ChatHistoryEntry) = .empty;
pub var g_chat_history_generation: u64 = 0;
pub var g_chat_cache_generation: u64 = 0;
pub var g_chat_fetch_mutex: HANDLE = null;
pub var g_chat_fetch_busy = false;
pub var g_chat_cache_pruned: u64 = 0;

pub var g_chat_cache_write_mutex: SpinMutex = .{};

pub const ChatHistoryChannel = struct {
    process: HANDLE = null,
    input: HANDLE = null,
    output: HANDLE = null,
    retry_at: u64 = 0,
};
pub var g_chat_history_channels: [3]ChatHistoryChannel = @splat(.{});
pub var g_chat_history_channel_mutex: SpinMutex = .{};
pub var g_chat_history_channels_closing: std.atomic.Value(bool) = .init(false);
pub var g_chat_permission_send_failed = std.atomic.Value(u32).init(0);

pub var g_chat_switch_loading: bool = false;
pub var g_chat_prepend_pending = false;

pub const ChatHit = struct { x: i32, y: i32, char: ?*usize = null, find: ?struct { position: usize, y: *i32 } = null };

pub const CHAT_BUBBLE_PAD = 12;
pub const CHAT_BUBBLE_RADIUS = 20;
pub const CHAT_PARA_GAP = 8;
pub const CHAT_AGENT_PAD_X = 12;
pub const CHAT_AGENT_PAD_Y = 10;
pub const CHAT_AGENT_HEADER_H = 22;
pub const CHAT_STATUS_H = 18;
pub const CHAT_CODE_PAD = 12;
pub const CHAT_CODE_HEADER = 28;

pub const GpStatus = i32;
pub const GdipStartupInput = extern struct { version: u32, debug_cb: ?*anyopaque, suppress_thread: BOOL, suppress_codecs: BOOL };
pub const GdipApi = struct {
    reset_clip: *const fn (HANDLE) callconv(WINAPI) GpStatus,
    set_clip_hrgn: *const fn (HANDLE, HANDLE, i32) callconv(WINAPI) GpStatus,
    set_pixel_offset: *const fn (HANDLE, i32) callconv(WINAPI) GpStatus,
    add_path_line: *const fn (HANDLE, f32, f32, f32, f32) callconv(WINAPI) GpStatus,
    add_path_rectangle: *const fn (HANDLE, f32, f32, f32, f32) callconv(WINAPI) GpStatus,
    add_path_ellipse: *const fn (HANDLE, f32, f32, f32, f32) callconv(WINAPI) GpStatus,
    add_path_polygon: *const fn (HANDLE, [*]const POINT, i32) callconv(WINAPI) GpStatus,
    add_path_pie: *const fn (HANDLE, f32, f32, f32, f32, f32, f32) callconv(WINAPI) GpStatus,
    start_figure: *const fn (HANDLE) callconv(WINAPI) GpStatus,
    create_pen: *const fn (u32, f32, i32, *HANDLE) callconv(WINAPI) GpStatus,
    delete_pen: *const fn (HANDLE) callconv(WINAPI) GpStatus,
    set_pen_caps: *const fn (HANDLE, i32, i32, i32) callconv(WINAPI) GpStatus,
    set_pen_join: *const fn (HANDLE, i32) callconv(WINAPI) GpStatus,
    draw_path: *const fn (HANDLE, HANDLE, HANDLE) callconv(WINAPI) GpStatus,

    create_from_hdc: *const fn (HANDLE, *HANDLE) callconv(WINAPI) GpStatus,
    delete_graphics: *const fn (HANDLE) callconv(WINAPI) GpStatus,
    set_smoothing: *const fn (HANDLE, i32) callconv(WINAPI) GpStatus,
    create_path: *const fn (i32, *HANDLE) callconv(WINAPI) GpStatus,
    delete_path: *const fn (HANDLE) callconv(WINAPI) GpStatus,
    add_path_arc: *const fn (HANDLE, f32, f32, f32, f32, f32, f32) callconv(WINAPI) GpStatus,
    close_figure: *const fn (HANDLE) callconv(WINAPI) GpStatus,
    create_fill: *const fn (u32, *HANDLE) callconv(WINAPI) GpStatus,
    delete_brush: *const fn (HANDLE) callconv(WINAPI) GpStatus,
    fill_path: *const fn (HANDLE, HANDLE, HANDLE) callconv(WINAPI) GpStatus,
};
pub var g_gdip_state: u8 = 0;
pub var g_gdip_api: GdipApi = undefined;
pub var g_gdip_token: usize = 0;
pub const WM_APP_CHAT_IMAGE_READY: u32 = WM_APP + 196;
pub const WM_APP_CHAT_ATTACH: u32 = WM_APP + 197;
pub const WM_APP_CHAT_ATTACH_FAILED: u32 = WM_APP + 198;
pub const SEARCH_CHAT_ATTACH_OFFSET: usize = 6372;
pub const SEARCH_CHAT_DICTATION_OFFSET: usize = 6468;

pub const GdipImgApi = struct {
    bitmap_from_file: *const fn ([*:0]const u16, *HANDLE) callconv(WINAPI) GpStatus,
    bitmap_from_hbitmap: *const fn (HANDLE, HANDLE, *HANDLE) callconv(WINAPI) GpStatus,
    bitmap_from_scan0: *const fn (i32, i32, i32, i32, ?*anyopaque, *HANDLE) callconv(WINAPI) GpStatus,
    dispose_image: *const fn (HANDLE) callconv(WINAPI) GpStatus,
    image_width: *const fn (HANDLE, *u32) callconv(WINAPI) GpStatus,
    image_height: *const fn (HANDLE, *u32) callconv(WINAPI) GpStatus,
    image_graphics: *const fn (HANDLE, *HANDLE) callconv(WINAPI) GpStatus,
    set_interpolation: *const fn (HANDLE, i32) callconv(WINAPI) GpStatus,
    set_pixel_offset: *const fn (HANDLE, i32) callconv(WINAPI) GpStatus,
    draw_image_rect: *const fn (HANDLE, HANDLE, i32, i32, i32, i32) callconv(WINAPI) GpStatus,
    save_image: *const fn (HANDLE, [*:0]const u16, *const GUID, ?*anyopaque) callconv(WINAPI) GpStatus,
    set_clip_path: *const fn (HANDLE, HANDLE, i32) callconv(WINAPI) GpStatus,
};
pub var g_gdip_img_state: u8 = 0;
pub var g_gdip_img_api: GdipImgApi = undefined;
pub const GDIP_PNG_ENCODER = GUID{ .Data1 = 0x557CF406, .Data2 = 0x1A04, .Data3 = 0x11D3, .Data4 = .{ 0x9A, 0x73, 0x00, 0x00, 0xF8, 0x1E, 0xF3, 0x2E } };

pub const CHAT_IMG_CACHE_N: usize = 30;
pub const CHAT_IMG_GAP = 8;
pub const ChatImgState = enum(u8) { empty, queued, loading, ready, failed };
pub const ChatImgEntry = struct {
    state: ChatImgState = .empty,
    key: u64 = 0,
    url: [chat_image.URL_CAP]u8 = std.mem.zeroes([chat_image.URL_CAP]u8),
    url_len: usize = 0,
    thumb: HANDLE = null,
    w: i32 = 0,
    h: i32 = 0,
    target_w: i32 = 0,
    pass: u64 = 0,
};
pub var g_chat_img_cache: [CHAT_IMG_CACHE_N]ChatImgEntry = @splat(.{});
pub var g_chat_img_mutex: SpinMutex = .{};
pub var g_chat_img_inflight = std.atomic.Value(u32).init(0);
pub var g_chat_img_pass: u64 = 0;
pub var g_chat_img_first_block: usize = 0;
pub var g_chat_hover_image: bool = false;

pub const ChatImgItem = struct {
    key: u64 = 0,
    rc: RECT = std.mem.zeroes(RECT),
};
pub const ChatImgLayout = struct {
    count: usize = 0,
    items: [chat_image.MAX_PER_BLOCK]ChatImgItem = undefined,
    max_w: i32 = 0,
    total_h: i32 = 0,
    origin_x: i32 = 0,
    origin_y: i32 = 0,
};
pub var g_chat_img_count_storage: [CHAT_MAX_BLOCKS]u8 = @splat(0);
pub var g_chat_img_count: []u8 = &g_chat_img_count_storage;
pub var g_chat_img_items_storage: [CHAT_MAX_BLOCKS][chat_image.MAX_PER_BLOCK]ChatImgItem = undefined;
pub var g_chat_img_items: [][chat_image.MAX_PER_BLOCK]ChatImgItem = &g_chat_img_items_storage;

pub const ChatImgJob = struct {
    key: u64,
    url: [chat_image.URL_CAP]u8 = std.mem.zeroes([chat_image.URL_CAP]u8),
    url_len: usize,
    target_w: i32,
    target_h: i32,
};
pub const ChatImgThumb = struct { thumb: HANDLE, w: i32, h: i32 };

pub const ChatAttachError = enum(u8) { no_config = 1, not_image, too_big, read_failed, upload_failed };
pub const ChatAttachJob = struct {
    shell_id: u32,
    path: [:0]const u16,
    delete_after: bool,
};

pub const OPENFILENAMEW = extern struct {
    lStructSize: DWORD,
    hwndOwner: HANDLE,
    hInstance: HANDLE,
    lpstrFilter: ?[*:0]const u16,
    lpstrCustomFilter: ?[*:0]u16,
    nMaxCustFilter: DWORD,
    nFilterIndex: DWORD,
    lpstrFile: ?[*]u16,
    nMaxFile: DWORD,
    lpstrFileTitle: ?[*]u16,
    nMaxFileTitle: DWORD,
    lpstrInitialDir: ?[*:0]const u16,
    lpstrTitle: ?[*:0]const u16,
    Flags: DWORD,
    nFileOffset: WORD,
    nFileExtension: WORD,
    lpstrDefExt: ?[*:0]const u16,
    lCustData: LPARAM,
    lpfnHook: ?*anyopaque,
    lpTemplateName: ?[*:0]const u16,
    pvReserved: ?*anyopaque,
    dwReserved: DWORD,
    FlagsEx: DWORD,
};

pub var g_chat_swallow_paste_char_until: u64 = 0;

const ShotFocus = struct {
    shell_id: u32 = 0,
    caret: ?u32 = null,
    until: u64 = 0,
    input_tick: u64 = 0,
    foreground: HANDLE = null,
};
pub var g_shot_focus: ShotFocus = .{};
pub var g_igsh354_paste_focus: bool = true;

pub const CHAT_COMPOSER_MAX_LINES = 8;

pub var g_chat_layout_browser_reserved = false;

pub const ChatAcRequest = struct { slot: usize, id: u32, host: u8, agent: chat_complete.Agent, mode: chat_complete.Mode, session: [64]u8, cwd: [192]u8 };

pub const CHAT_BUNDLED_SKILLS = [_]skill_model.BundledSkill{
    .{ .markdown = @embedFile("skills_assets/unslop-SKILL.md"), .source = .multiprompt },
    .{ .markdown = @embedFile("skills_assets/i-have-adhd-SKILL.md"), .source = .multiprompt },
};

pub var g_chat_verify_shell_id: u32 = 0;
pub var g_chat_verify_prefix: [20]u16 = undefined;
pub var g_chat_verify_prefix_len: usize = 0;
pub var g_chat_verify_checks: u8 = 0;
pub var g_chat_verify_echo_id: u64 = 0;

pub const CHAT_SEND_VERIFY_DELAYS_MS = [_]u32{ 700, 1200, 2000, 3000, 4000, 5000 };

pub const ShellSendResult = enum { ok, write_failed, enter_failed };

pub const CHAT_OUTBOX_MAX_PER_KEY: usize = 20;
pub const CHAT_OUTBOX_TOTAL_MAX: usize = 400;
pub const CHAT_OUTBOX_MSG_CAP: usize = 16384;
pub const CHAT_OUTBOX_KEY_CAP: usize = 256;
pub const CHAT_OUTBOX_LOAD_LIMIT: usize = 16 * 1024 * 1024;
pub const CHAT_ECHO_PREFIX_CAP: usize = 40;
pub const CHAT_CONFIRMED_MAX_PER_KEY: usize = 50;

pub const ChatEchoState = chat_echo.OutboxState;

pub const ChatOutboxEntry = struct {
    id: u64 = 0,
    key: [CHAT_OUTBOX_KEY_CAP]u8 = std.mem.zeroes([CHAT_OUTBOX_KEY_CAP]u8),
    key_len: u32 = 0,
    text: []u16 = &.{},
    state: ChatEchoState = .queued,
    write_started: bool = false,
    left_box_ms: u64 = 0,
    retryable: bool = false,
    delivery_watch: chat_echo.DeliveryWatch = .{},
    channel_sent: bool = false,
    channel_pending: bool = false,
    steer_pending: bool = false,
    sent_tick_ms: i64 = 0,
    expires_ms: i64 = 0,
    channel_sent_ms: i64 = 0,
    channel_retries: u8 = 0,
    channel_history_revision: u64 = std.math.maxInt(u64),
    channel_history_generation: u64 = 0,
    transcript_queued: bool = false,
    anchor: chat_echo.Anchor = .{},
    from_disk: bool = false,
};

pub const ChatConfirmedEcho = struct {
    key: [CHAT_OUTBOX_KEY_CAP]u8 = std.mem.zeroes([CHAT_OUTBOX_KEY_CAP]u8),
    key_len: u32 = 0,
    prefix: [CHAT_ECHO_PREFIX_CAP]u16 = std.mem.zeroes([CHAT_ECHO_PREFIX_CAP]u16),
    prefix_len: u8 = 0,
    block_start: usize = 0,
    block_len: usize = 0,
    stamp_ms: i64 = 0,
};

pub var g_chat_outbox: std.ArrayList(ChatOutboxEntry) = .empty;
pub var g_chat_echo_next_id: u64 = 1;
pub var g_chat_confirmed: std.ArrayList(ChatConfirmedEcho) = .empty;
pub var g_chat_echo_layout: [CHAT_OUTBOX_MAX_PER_KEY]RECT = undefined;
pub var g_chat_echo_layout_ids: [CHAT_OUTBOX_MAX_PER_KEY]u64 = @splat(0);
pub var g_chat_echo_layout_count: usize = 0;
pub var g_chat_scroll_bottom_pending: bool = false;
pub var g_chat_outbox_timer_on: bool = false;
pub var g_ssh_reconnect_timer_ms: u32 = 0;

pub var g_chat_outbox_revision: u64 = 0;

pub var g_chat_window_full: bool = false;
pub var g_chat_blocks_from_file: bool = false;

pub const ChatEchoAssignment = struct {
    count: usize = 0,
    id: [CHAT_OUTBOX_MAX_PER_KEY]u64 = [_]u64{0} ** CHAT_OUTBOX_MAX_PER_KEY,
    block: [CHAT_OUTBOX_MAX_PER_KEY]?usize = [_]?usize{null} ** CHAT_OUTBOX_MAX_PER_KEY,
    anchor: [CHAT_OUTBOX_MAX_PER_KEY]chat_echo.Anchor = [_]chat_echo.Anchor{.{}} ** CHAT_OUTBOX_MAX_PER_KEY,
};

pub var g_chat_reconcile_shell: u32 = 0;
pub var g_chat_reconcile_hash: u64 = 0;
pub var g_chat_reconcile_outbox: u64 = 0;
pub var g_chat_reconcile_generation: u64 = 0;

pub const SSH_AUTO_RECONNECT_ENABLED = true;
pub const ISSUE_350_KEEP_TMUX_TABS = true;

pub var g_chat_draft_owner: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;
pub var g_chat_draft_owner_len: usize = 0;
pub var g_chat_draft_dirty: bool = false;
pub const CHAT_DRAFT_SAVE_MS: u32 = 500;

pub const voiceScreenFallbackShouldSpeak = duplex.voiceScreenFallbackShouldSpeak;

pub var g_voice_fallback_last_hash: u64 = 0;
pub var g_voice_fallback_stable_since: u64 = 0;

pub const VoiceMic = struct {
    enumerator: ?*IMMDeviceEnumerator = null,
    capture_device: ?*IMMDevice = null,
    render_device: ?*IMMDevice = null,
    client: ?*IAudioClient2 = null,
    aec: ?*IAcousticEchoCancellationControl = null,
    effects: ?*IAudioEffectsManager = null,
    capture: ?*IAudioCaptureClient = null,
    render_id: ?[*:0]u16 = null,
    event: HANDLE = null,
    started: bool = false,
    aec_state: duplex.AecState = .unknown,

    pub fn close(self: *VoiceMic) void {
        if (self.started) {
            const hr = self.client.?.lpVtbl.Stop(self.client.?);
            dictationAudit("voice-duplex-wasapi-stop", @as(u32, @bitCast(hr)));
        }
        if (self.capture) |p| comRelease(p);
        if (self.effects) |p| comRelease(p);
        if (self.aec) |p| comRelease(p);
        if (self.event != null) _ = CloseHandle(self.event);
        if (self.client) |p| comRelease(p);
        if (self.render_id) |p| CoTaskMemFree(@ptrCast(p));
        if (self.render_device) |p| comRelease(p);
        if (self.capture_device) |p| comRelease(p);
        if (self.enumerator) |p| comRelease(p);
        self.* = .{};
    }

    pub fn pinRender(self: *VoiceMic) void {
        const enumr = self.enumerator orelse return;
        const aec = self.aec orelse return;
        var dev: ?*IMMDevice = null;
        const hr = enumr.lpVtbl.GetDefaultAudioEndpoint(enumr, 0, 0, &dev);
        dictationAudit("voice-duplex-aec-render", @as(u32, @bitCast(hr)));
        if (hr < 0 or dev == null) return;
        defer comRelease(dev.?);
        var id: ?[*:0]u16 = null;
        const id_hr = dev.?.lpVtbl.GetId(dev.?, &id);
        dictationAudit("voice-duplex-aec-id", @as(u32, @bitCast(id_hr)));
        if (id_hr < 0 or id == null) return;
        if (self.render_id) |old| {
            if (std.mem.eql(u16, std.mem.span(old), std.mem.span(id.?))) {
                CoTaskMemFree(@ptrCast(id.?));
                return;
            }
        }
        const pin_hr = aec.lpVtbl.SetEchoCancellationRenderEndpoint(aec, id.?);
        dictationAudit("voice-duplex-aec-ref", @as(u32, @bitCast(pin_hr)));
        if (pin_hr >= 0) {
            if (self.render_id) |old| CoTaskMemFree(@ptrCast(old));
            self.render_id = id;
        } else CoTaskMemFree(@ptrCast(id.?));
    }

    pub fn open(self: *VoiceMic) bool {
        var ptr: ?*anyopaque = null;
        var hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, null, CLSCTX_INPROC_SERVER, &IID_IMMDeviceEnumerator, &ptr);
        dictationAudit("voice-duplex-wasapi-enumerator", @as(u32, @bitCast(hr)));
        if (hr < 0 or ptr == null) return false;
        self.enumerator = @ptrCast(@alignCast(ptr.?));
        hr = self.enumerator.?.lpVtbl.GetDefaultAudioEndpoint(self.enumerator.?, 1, 0, &self.capture_device);
        dictationAudit("voice-duplex-wasapi-input", @as(u32, @bitCast(hr)));
        if (hr < 0 or self.capture_device == null) return false;
        hr = self.enumerator.?.lpVtbl.GetDefaultAudioEndpoint(self.enumerator.?, 0, 0, &self.render_device);
        dictationAudit("voice-duplex-wasapi-output", @as(u32, @bitCast(hr)));
        if (hr < 0 or self.render_device == null) return false;
        hr = self.render_device.?.lpVtbl.GetId(self.render_device.?, &self.render_id);
        dictationAudit("voice-duplex-wasapi-output-id", @as(u32, @bitCast(hr)));
        if (hr < 0 or self.render_id == null) return false;
        ptr = null;
        hr = self.capture_device.?.lpVtbl.Activate(self.capture_device.?, &IID_IAudioClient2, CLSCTX_INPROC_SERVER, null, &ptr);
        dictationAudit("voice-duplex-wasapi-client", @as(u32, @bitCast(hr)));
        if (hr < 0 or ptr == null) return false;
        self.client = @ptrCast(@alignCast(ptr.?));
        const props = AudioClientProperties{};
        hr = self.client.?.lpVtbl.SetClientProperties(self.client.?, &props);
        dictationAudit("voice-duplex-wasapi-category", @as(u32, @bitCast(hr)));
        if (hr < 0) return false;
        const fmt = WAVEFORMATEX{ .wFormatTag = WAVE_FORMAT_PCM, .nChannels = 1, .nSamplesPerSec = DICTATION_SAMPLE_RATE, .nAvgBytesPerSec = DICTATION_SAMPLE_RATE * 2, .nBlockAlign = 2, .wBitsPerSample = 16, .cbSize = 0 };
        hr = self.client.?.lpVtbl.Initialize(self.client.?, 0, 0x88040000, 2_000_000, 0, &fmt, null);
        dictationAudit("voice-duplex-wasapi-init", @as(u32, @bitCast(hr)));
        if (hr < 0) return false;
        self.event = CreateEventW(null, 0, 0, null);
        if (self.event == null) {
            dictationAudit("voice-duplex-wasapi-event", 0);
            return false;
        }
        hr = self.client.?.lpVtbl.SetEventHandle(self.client.?, self.event);
        dictationAudit("voice-duplex-wasapi-event", @as(u32, @bitCast(hr)));
        if (hr < 0) return false;
        ptr = null;
        hr = self.client.?.lpVtbl.GetService(self.client.?, &IID_IAcousticEchoCancellationControl, &ptr);
        dictationAudit("voice-duplex-aec-control", @as(u32, @bitCast(hr)));
        if (hr >= 0 and ptr != null) {
            self.aec = @ptrCast(@alignCast(ptr.?));
            const ref_hr = self.aec.?.lpVtbl.SetEchoCancellationRenderEndpoint(self.aec.?, self.render_id.?);
            dictationAudit("voice-duplex-aec-ref", @as(u32, @bitCast(ref_hr)));
        }
        ptr = null;
        hr = self.client.?.lpVtbl.GetService(self.client.?, &IID_IAudioEffectsManager, &ptr);
        dictationAudit("voice-duplex-aec-effects", @as(u32, @bitCast(hr)));
        if (hr >= 0 and ptr != null) {
            self.effects = @ptrCast(@alignCast(ptr.?));
            var effects: ?[*]AudioEffectWin = null;
            var count: u32 = 0;
            const fx_hr = self.effects.?.lpVtbl.GetAudioEffects(self.effects.?, &effects, &count);
            dictationAudit("voice-duplex-aec-effect", @as(u32, @bitCast(fx_hr)));
            if (fx_hr >= 0) {
                self.aec_state = .absent;
                if (effects) |list| {
                    for (list[0..count]) |effect| {
                        var id: [16]u8 = undefined;
                        @memcpy(&id, std.mem.asBytes(&effect.id));
                        const state = duplex.effectsAecState(&.{.{ .id = id, .state = effect.state }});
                        if (state != .absent) self.aec_state = state;
                    }
                    CoTaskMemFree(@ptrCast(list));
                }
            }
        }
        dictationAudit("voice-duplex-aec-state", @intFromEnum(self.aec_state));
        ptr = null;
        hr = self.client.?.lpVtbl.GetService(self.client.?, &IID_IAudioCaptureClient, &ptr);
        dictationAudit("voice-duplex-wasapi-capture", @as(u32, @bitCast(hr)));
        if (hr < 0 or ptr == null) return false;
        self.capture = @ptrCast(@alignCast(ptr.?));
        hr = self.client.?.lpVtbl.Start(self.client.?);
        dictationAudit("voice-duplex-wasapi", @as(u32, @bitCast(hr)));
        if (hr < 0) return false;
        self.started = true;
        return true;
    }
};

pub const VoiceResult = struct {
    id: u32,
    epoch: u32,
    overlapped: bool,
    len: usize = 0,
    text: [8192]u8 = undefined,
};
const VoiceResultSlot = struct { ready: bool = false, result: VoiceResult = undefined };
pub var g_voice_results: [4]VoiceResultSlot = @splat(.{});
pub var g_voice_result_mutex: SpinMutex = .{};

pub const VoiceJob = struct {
    id: u32,
    epoch: u32,
    overlapped: bool,
    spoken: [24576]u8,
    spoken_len: usize,
    audio: []u8,
    audio_len: usize,
};
const VoiceOpen = struct { id: u32 = 0, shell_id: u32 = 0, typed: bool = false, consumed: bool = false, key_tick: u32 = 0 };
pub var g_voice_utt_open: [4]VoiceOpen = @splat(.{});
pub var g_voice_auto_sending: bool = false;
const VoiceDeferredText = struct { shell_id: u32 = 0, len: usize = 0, text: [8192]u16 = undefined };
pub var g_voice_deferred_text: [4]VoiceDeferredText = @splat(.{});
pub var g_voice_deferred_turn_shell_id: u32 = 0;
pub var g_voice_always_listen: bool = true;
pub var g_voice_mic_failed: bool = false;
pub var g_voice_echo_notice_shown: bool = false;
pub var g_voice_mic_run = std.atomic.Value(bool).init(false);
pub var g_voice_mic_thread: ?std.Thread = null;
pub var g_voice_mic_epoch = std.atomic.Value(u32).init(0);
pub var g_voice_stt_pending = std.atomic.Value(u32).init(0);
pub var g_voice_tts_audible = std.atomic.Value(bool).init(false);
pub var g_voice_tts_quiet_since = std.atomic.Value(u64).init(0);
pub var g_voice_tts_since = std.atomic.Value(u64).init(0);
pub var g_voice_last_activity_tick: u64 = 0;
pub var g_voice_composer_key_tick = std.atomic.Value(u32).init(0);
pub var g_voice_console_key_tick = std.atomic.Value(u32).init(0);
pub var g_voice_mic_start_pending: bool = false;
pub var g_voice_legacy_discard: bool = false;
pub var g_dictation_capturing = std.atomic.Value(bool).init(false);
pub var g_voice_repin = std.atomic.Value(bool).init(false);
pub var g_voice_spoken: [24576]u8 = undefined;
pub var g_voice_spoken_len: usize = 0;
pub var g_voice_spoken_mutex: SpinMutex = .{};

pub const VoiceFrame = struct {
    data: [320]i16 = undefined,
    len: usize = 0,
    preroll: duplex.PreRoll = .{},
    onset: duplex.OnsetDetector = .{},
    tracker: duplex.UtteranceTracker = .{},
    idle_floor: duplex.NoiseFloor = .{},
    tts_floor: duplex.TtsEchoPeak = .{},
    tts_quiet: duplex.NoiseFloor = .{},
    tts_reply_since: u64 = 0,
    tts_ms: u32 = 0,
    audio: ?[]u8 = null,
    audio_len: usize = 0,
    overlapped: bool = false,
    spoken: [24576]u8 = undefined,
    spoken_len: usize = 0,
    epoch: u32,
    last_audit: u64 = 0,
    aec: duplex.AecState = .unknown,

    pub fn accept(self: *VoiceFrame, input: []align(1) const i16) void {
        for (input) |s| {
            self.data[self.len] = s;
            self.len += 1;
            if (self.len == self.data.len) {
                self.step();
                self.len = 0;
            }
        }
    }
    fn step(self: *VoiceFrame) void {
        const now = GetTickCount64();
        const playing = g_voice_tts_audible.load(.acquire);
        const audible = playing or now -| g_voice_tts_quiet_since.load(.acquire) < 300;
        const rms = pcmFrameRms(&self.data);
        const ms_into_reply: u32 = @intCast(@min(now -| g_voice_tts_since.load(.acquire), std.math.maxInt(u32)));
        if (playing and self.tracker.id == 0) {
            const reply_since = g_voice_tts_since.load(.acquire);
            if (reply_since != self.tts_reply_since) {
                self.tts_reply_since = reply_since;
                self.tts_floor = .{};
                self.tts_ms = 0;
                self.onset = .{};
            }
            const prior = duplex.bargeInThreshold(self.idle_floor.value, self.tts_floor.value, true, self.aec, ms_into_reply);
            self.tts_floor.step(rms, prior);
            self.tts_quiet.step(rms);
            self.tts_ms +|= 20;
        } else if (!audible and self.tracker.id == 0) self.idle_floor.step(rms);
        const threshold = duplex.bargeInThreshold(self.idle_floor.value, self.tts_floor.value, audible, self.aec, ms_into_reply);
        const key_elapsed: u32 = @truncate(@as(u32, @truncate(now)) -% g_last_main_keyboard_event_time.load(.acquire));
        if (self.tracker.id == 0 and self.onset.step(rms, 20, threshold, key_elapsed, audible and self.aec != .on) and g_voice_stt_pending.load(.acquire) < 2) {
            const audio = std.heap.page_allocator.alloc(u8, DICTATION_SAMPLE_RATE * 2 * 61) catch return;
            const pre_ms: u32 = if (audible and self.aec != .on) 200 else 600;
            const samples = self.preroll.copyLast(std.mem.bytesAsSlice(i16, audio), pre_ms);
            self.audio = audio;
            self.audio_len = samples * 2;
            self.overlapped = audible;
            while (!g_voice_spoken_mutex.tryLock()) Sleep(0);
            self.spoken_len = g_voice_spoken_len;
            @memcpy(self.spoken[0..self.spoken_len], g_voice_spoken[0..self.spoken_len]);
            g_voice_spoken_mutex.unlock();
            const id = self.tracker.open();
            if (playing) {
                voiceTtsStopPlayback();
                g_voice_tts_audible.store(false, .release);
                g_voice_tts_quiet_since.store(now, .release);
                dictationAudit("voice-duplex-talkover", id);
            }
            if (g_main_hwnd != null) _ = PostMessageW(g_main_hwnd, WM_APP_VOICE_SPEECH_START, id, @bitCast((@as(usize, self.epoch) << 1) | @intFromBool(audible)));
        }
        if (self.audio) |audio| {
            const bytes = std.mem.sliceAsBytes(&self.data);
            const n = @min(bytes.len, audio.len - self.audio_len);
            @memcpy(audio[self.audio_len .. self.audio_len + n], bytes[0..n]);
            self.audio_len += n;
            const ended = self.tracker.step(rms, threshold, 20);
            if (ended != null or self.audio_len == audio.len) {
                const id = self.tracker.next_id;
                self.tracker.id = 0;
                self.audio = null;
                if (!(ended orelse duplex.utteranceAtCapacity(self.tracker.speech_ms))) {
                    std.heap.page_allocator.free(audio);
                    var empty = VoiceResult{ .id = id, .epoch = self.epoch, .overlapped = self.overlapped };
                    voicePostResult(&empty);
                } else {
                    const job = std.heap.page_allocator.create(VoiceJob) catch {
                        std.heap.page_allocator.free(audio);
                        var empty = VoiceResult{ .id = id, .epoch = self.epoch, .overlapped = self.overlapped };
                        voicePostResult(&empty);
                        return;
                    };
                    job.* = .{ .id = self.tracker.next_id, .epoch = self.epoch, .overlapped = self.overlapped, .spoken = undefined, .spoken_len = 0, .audio = audio, .audio_len = self.audio_len };
                    job.spoken_len = self.spoken_len;
                    @memcpy(job.spoken[0..job.spoken_len], self.spoken[0..job.spoken_len]);
                    _ = g_voice_stt_pending.fetchAdd(1, .acq_rel);
                    const t = std.Thread.spawn(.{}, voiceSttWorkerThread, .{job}) catch {
                        _ = g_voice_stt_pending.fetchSub(1, .acq_rel);
                        std.heap.page_allocator.free(audio);
                        std.heap.page_allocator.destroy(job);
                        var empty = VoiceResult{ .id = id, .epoch = self.epoch, .overlapped = self.overlapped };
                        voicePostResult(&empty);
                        return;
                    };
                    t.detach();
                }
            }
        }
        self.preroll.append(&self.data);
        if (now -| self.last_audit >= 10000) {
            self.last_audit = now;
            dictationAudit("voice-idle-floor", @intFromFloat(self.idle_floor.value));
            const path = duplex.classifyEchoPath(self.idle_floor.value, self.tts_quiet.value, self.tts_ms);
            if (path == .echoey and g_main_hwnd != null) _ = PostMessageW(g_main_hwnd, WM_APP_VOICE_MIC_STATUS, 2, @intCast(self.epoch));
        }
    }
    pub fn close(self: *VoiceFrame) void {
        if (self.audio) |audio| {
            std.heap.page_allocator.free(audio);
            self.audio = null;
            const id = self.tracker.id;
            self.tracker.id = 0;
            if (id != 0) {
                var empty = VoiceResult{ .id = id, .epoch = self.epoch, .overlapped = self.overlapped };
                voicePostResult(&empty);
            }
        }
    }
};

pub const ISSUE_265_WORKING_BAR = true;
pub var g_chat_working_timer_running: bool = false;

pub const CHAT_WORKING_GENERIC = [_]u16{ 'W', 'o', 'r', 'k', 'i', 'n', 'g', 0x2026 };

pub const ChangelogLayout = struct {
    ox: i32,
    oy: i32,
    overlay_w: i32,
    overlay_h: i32,
    title_h: i32,
    bottom_pad: i32,
    view_h: i32,
    max_scroll: i32,
};

pub const ChangelogEntryRange = struct { top: i32, h: i32 };
pub const ChangelogHit = struct { idx: i32, ticket: []const u8 };

pub const UsageLoginAccount = enum { primary, secondary };

pub var g_usage_launch_mutex: HANDLE = null;

pub const LADDER_REFRESH_MS: u64 = 180_000;
pub const LADDER_VALID_MS: u64 = 15 * 60_000;
pub const LADDER_MAX_AGE_SECS: f64 = 1800;
pub var g_ladder_cache: AiPaceSnapshot = .{};
pub var g_ladder_cache_tick: u64 = 0;
pub var g_ladder_last_attempt: u64 = 0;
pub var g_ladder_force = std.atomic.Value(bool).init(false);
pub var g_ladder_hint = std.atomic.Value(u8).init(255);
pub var g_ladder_hint_until = std.atomic.Value(u64).init(0);
pub var g_ladder_cmd_busy = std.atomic.Value(bool).init(false);
pub var g_ladder_notice: [96]u8 = std.mem.zeroes([96]u8);
pub var g_ladder_notice_len: usize = 0;

pub var g_paint_mem_dc: HANDLE = null;
pub var g_paint_bmp: HANDLE = null;
pub var g_paint_old_bmp: HANDLE = null;
pub var g_paint_w: i32 = 0;
pub var g_paint_h: i32 = 0;
pub var g_ui_scale: u32 = 100;
pub var g_font_title: HANDLE = null;
pub var g_font_shell_tab_title: HANDLE = null;
pub var g_font_subtitle: HANDLE = null;
pub var g_font_status_card: HANDLE = null;
pub var g_font_close: HANDLE = null;
pub var g_font_inbox_title: HANDLE = null;
pub var g_font_inbox_sub: HANDLE = null;
pub var g_font_thread_title: HANDLE = null;

pub const WM_SYSKEYDOWN: u32 = 0x0104;
pub var g_win_held: bool = false;
pub var g_native_paste_passthrough_until: u64 = 0;
pub var g_browser_toggle_chord_held: bool = false;
pub var g_browser_toggle_last_event_time: u32 = 0;
pub var g_chat_toggle_chord_held: bool = false;
pub var g_chat_toggle_last_event_time: u32 = 0;
pub var g_voice_toggle_chord_held: bool = false;
pub var g_voice_toggle_last_event_time: u32 = 0;
pub var g_voice_step_chord_held: [2]bool = .{ false, false };
pub var g_voice_step_last_event_time: [2]u32 = .{ 0, 0 };
pub var g_voice_replay_chord_held: bool = false;
pub var g_voice_replay_last_event_time: u32 = 0;
pub var g_favorite_chord_held: bool = false;
pub var g_browser_focus_chord_held: bool = false;
pub var g_palette_chord_held: bool = false;
pub var g_screenshot_chord_held: bool = false;
pub var g_tab_url_chord_held: bool = false;
pub var g_dictation_toggle_chord_held: bool = false;
pub var g_browser_toggle_last_handled_event_time: u32 = 0;
pub const BROWSER_TOGGLE_DEBOUNCE_MS: u32 = 1500;
pub var g_browser_shortcut_open_guard_shell_id: u32 = 0;
pub var g_browser_shortcut_open_guard_until: u64 = 0;
pub const BROWSER_SHORTCUT_OPEN_GUARD_MS: u64 = 10_000;

pub const STALE_ALT_REPAIR_EXTRA_INFO: usize = 0x4D505341;

pub var g_stale_alt_mouse_hook: HANDLE = null;
pub var g_keyboard_recovery_hook: HANDLE = null;
pub var g_last_main_keyboard_event_time = std.atomic.Value(u32).init(0);
pub var g_keyboard_recovery_posted = std.atomic.Value(bool).init(false);
pub var g_stale_alt_browser_click_repair_armed = std.atomic.Value(bool).init(false);
pub var g_ctrl_click_down_swallowed = std.atomic.Value(bool).init(false);
pub var g_browser_drag_down_valid = false;
pub var g_browser_drag_down_point: POINT = .{ .x = 0, .y = 0 };
pub var g_browser_drag_down_tick: u64 = 0;

pub const INPUT_HOOK_THREAD_TIMER_REQUEST_ID: usize = 1;
pub const INPUT_HOOK_THREAD_POLL_MS: UINT = 5000;
pub const INPUT_HOOK_THREAD_STALL_MS: u64 = 15_000;

pub const isUrlChar = link_detect.isUrlChar;
pub const urlSliceStartsWithScheme = link_detect.scheme;

pub const URL_PICKER_MAX: u32 = 32;
const URL_PICKER_STORAGE: u32 = URL_PICKER_MAX * 512;
pub var g_url_picker_active: bool = false;
pub var g_url_picker_sel: u32 = 0;
pub var g_url_picker_count: u32 = 0;
pub var g_url_picker_offsets: [URL_PICKER_MAX]u32 = undefined;
pub var g_url_picker_lengths: [URL_PICKER_MAX]u32 = undefined;
pub var g_url_picker_storage: [URL_PICKER_STORAGE]u16 = undefined;
pub var g_url_picker_used: u32 = 0;
pub var g_url_picker_saw_claude_login_prompt: bool = false;

pub var g_spinner_frame: u32 = 0;
pub var g_spinner_running: bool = false;
pub const SPINNER_STALE_MS: u64 = 300_000;

pub const ClipboardTextState = enum { unavailable, empty_or_missing, same, different };

pub var g_last_paste_text: [8192]u16 = undefined;
pub var g_last_paste_len: usize = 0;
pub var g_last_paste_tick: u64 = 0;
pub const LAST_PASTE_FALLBACK_MS: u64 = 60_000;

pub const DICTATION_SAMPLE_RATE: DWORD = 16000;
pub const DICTATION_CHUNK_BYTES: usize = 3200;
pub const DICTATION_BUFFER_COUNT: usize = 4;

pub const pcmFrameRms = duplex.pcmFrameRms;
const VadState = duplex.VadState;
pub const vadStep = duplex.vadStep;

pub const DictationHttpResult = struct { transcript_len: usize = 0, status: DWORD = 0 };

pub const DEEPGRAM_HOST = L("api.eu.deepgram.com");
pub const DEEPGRAM_MIP_OPT_OUT = true;

pub const DictationShellPasteResult = enum { verified, delivery_failed, output_unverified };

pub const CopySelectionResult = enum { copied, no_selection, failed };

pub const NOTIFY_QUEUE_CAP: usize = 16;
pub var g_notify_mutex: SpinMutex = .{};
pub var g_notify_queue: [NOTIFY_QUEUE_CAP][NOTIFY_PAYLOAD_CAP]u8 = std.mem.zeroes([NOTIFY_QUEUE_CAP][NOTIFY_PAYLOAD_CAP]u8);
pub var g_notify_lens: [NOTIFY_QUEUE_CAP]u32 = std.mem.zeroes([NOTIFY_QUEUE_CAP]u32);
pub var g_notify_head: usize = 0;
pub var g_notify_tail: usize = 0;
pub var g_notify_count: usize = 0;

pub const SYNC_AUTH_CONFIG_TEMPLATE =
    "{\r\n" ++
    "  \"_doc\": \"Public OIDC settings for multiprompt desktop sync. No client secret belongs in this file.\",\r\n" ++
    "  \"clientId\": \"\",\r\n" ++
    "  \"authorizationEndpoint\": \"\",\r\n" ++
    "  \"tokenEndpoint\": \"\",\r\n" ++
    "  \"redirectUri\": \"multiprompt://auth/callback\",\r\n" ++
    "  \"scope\": \"openid profile email\"\r\n" ++
    "}\r\n";

pub var g_multiprompt_logged_in: bool = false;

pub const HttpsTarget = struct { host: []const u8, path: []const u8, port: u16 };

pub const CREDUI_INFOW = extern struct {
    cbSize: DWORD,
    hwndParent: HANDLE,
    pszMessageText: LPCWSTR,
    pszCaptionText: LPCWSTR,
    hbmBanner: HANDLE,
};
pub const CREDUI_FLAGS_GENERIC_CREDENTIALS: DWORD = 0x40000;
pub const CREDUI_FLAGS_KEEP_USERNAME: DWORD = 0x100000;
pub const CREDUI_FLAGS_DO_NOT_PERSIST: DWORD = 0x2;
pub const CREDUI_FLAGS_EXCLUDE_CERTIFICATES: DWORD = 0x8;

pub const HttpsBearerResult = struct { status: u16, body: []u8 };

pub const SYNC_VAULT_URL = "https://sync.multiprompt.dev/vault";

pub const VaultFetch = union(enum) { not_found, found: sync_vault.VaultGetResult, network_error, unauthorized };

pub const VaultPut = enum { ok, conflict, network_error, unauthorized };

pub const ZSB_WIRE_CAP: usize = 64 * 1024;
pub const ZSB_DECODED_CAP: usize = 48 * 1024;
pub const ZSB_URL_CAP: usize = BROWSER_PENDING_URL_CAP;
pub const ZSB_COMMAND_CAP: usize = WIN32_COMMAND_LINE_CAP;
pub const ZSB_OPEN_REPLY_CAP: usize = 4 * 1024;

pub const ZsbWorkerCtx = struct {
    client: SOCKET,
    req: [ZSB_WIRE_CAP]u8,
    req_len: usize,
};

pub var g_zsb_workspace_mutex: SpinMutex = .{};
pub var g_zsb_workspace_pending = false;
pub var g_zsb_workspace_done = false;
pub var g_zsb_workspace_args: [11][256]u8 = undefined;
pub var g_zsb_workspace_arg_lens: [11]usize = undefined;
pub var g_zsb_workspace_argc: usize = 0;
pub var g_zsb_workspace_response: [256 * 1024]u8 = undefined;
pub var g_zsb_workspace_response_len: usize = 0;

pub var g_zsb_who_mutex: SpinMutex = .{};
pub var g_zsb_who_pending = false;
pub var g_zsb_who_done = false;
pub var g_zsb_who_has_tab = false;
pub var g_zsb_who_session: [64]u8 = undefined;
pub var g_zsb_who_session_len: usize = 0;

pub var g_zsb_open_mutex: SpinMutex = .{};
pub var g_zsb_open_pending: bool = false;
pub var g_zsb_open_done: bool = false;
pub var g_zsb_open_found: bool = false;
pub var g_zsb_open_session: [64]u8 = std.mem.zeroes([64]u8);
pub var g_zsb_open_session_len: u32 = 0;
pub var g_zsb_open_url: [ZSB_URL_CAP]u8 = std.mem.zeroes([ZSB_URL_CAP]u8);
pub var g_zsb_open_url_len: u32 = 0;

pub var g_zsb_sidebar_mutex: SpinMutex = .{};
pub var g_zsb_sidebar_pending: bool = false;
pub var g_zsb_sidebar_done: bool = false;
pub var g_zsb_sidebar_found: bool = false;
pub var g_zsb_sidebar_session: [64]u8 = std.mem.zeroes([64]u8);
pub var g_zsb_sidebar_session_len: u32 = 0;

pub const ZsbPaneInfo = struct {
    profile: [32]u8 = std.mem.zeroes([32]u8),
    name: [64]u16 = std.mem.zeroes([64]u16),
    name_len: u32 = 0,
    shell_id: u32 = 0,
    window_id: i64 = 0,
    active: bool = false,
    visible: bool = false,
};
pub var g_zsb_bind_info: ZsbPaneInfo = .{};
pub var g_zsb_bind_info_only = false;
pub var g_zsb_bind_mutex: SpinMutex = .{};
pub var g_zsb_bind_pending: bool = false;
pub var g_zsb_bind_done: bool = false;
pub var g_zsb_bind_found: bool = false;
pub var g_zsb_bind_force: bool = false;
pub var g_zsb_bind_session: [64]u8 = std.mem.zeroes([64]u8);
pub var g_zsb_bind_session_len: u32 = 0;

pub var g_zsb_touch_mutex: SpinMutex = .{};
pub var g_zsb_touch_tokens: [32][64]u8 = std.mem.zeroes([32][64]u8);
pub var g_zsb_touch_lens: [32]u8 = std.mem.zeroes([32]u8);
pub var g_zsb_touch_ticks: [32]u64 = std.mem.zeroes([32]u64);

pub const DIAG_REQUEST_CAP: usize = 128;
const DIAG_RESPONSE_CAP: usize = 65536;
pub var g_diag_mutex: SpinMutex = .{};
pub var g_diag_pending: bool = false;
pub var g_diag_done: bool = false;
pub var g_diag_request: [DIAG_REQUEST_CAP]u8 = std.mem.zeroes([DIAG_REQUEST_CAP]u8);
pub var g_diag_request_len: u32 = 0;
pub var g_diag_response: [DIAG_RESPONSE_CAP]u8 = std.mem.zeroes([DIAG_RESPONSE_CAP]u8);
pub var g_diag_response_len: u32 = 0;

pub const PaneWinCandidates = struct {
    count: u32 = 0,
    first_path: [700]u8 = std.mem.zeroes([700]u8),
    first_path_len: usize = 0,
    names: [8][64]u8 = std.mem.zeroes([8][64]u8),
    name_lens: [8]u8 = std.mem.zeroes([8]u8),
};

pub const ZsbBridgeRun = struct {
    out_len: usize = 0,
    timed_out: bool = false,
    exit_code: DWORD = 0,
    proc_ok: bool = false,
};

pub const ZsbOpenTab = struct {
    id: i64 = 0,
    active: bool = false,
    beacon: bool = true,
};

pub const ZsbOpenOutcome = struct {
    verified: bool = false,
    stale: bool = false,
    out_len: usize = 0,
};

pub const EtaWireLine = struct { name: []const u8, remaining_s: u32, desc: []const u8 };

pub const ETA_MAX_REMAINING_S: u32 = 7 * 24 * 3600;

pub const FILETIME_UNIX_EPOCH_DELTA_100NS: i64 = 116444736000000000;

pub const ETA_LOG_TAIL_BYTES: usize = 65536;

pub const ETA_ACCURACY_AGENTS = [_][]const u8{ "claude", "codex", "pi", "kimi", "hax", "grok", "cursor", "unknown" };

pub const INBOX_MAX_WS: usize = 32;
pub const INBOX_MAX_ROWS: usize = MAX_SHELLS * 2;

const InboxWs = struct {
    name: [64]u8 = std.mem.zeroes([64]u8),
    name_len: u32 = 0,
    hwnd: usize = 0,
    attn: u32 = 0,
    total: u32 = 0,
};
pub const InboxRow = struct {
    ws: u32 = 0,
    sid: u32 = 0,
    kind: u8 = 0,
    act: u8 = 0,
    att: bool = false,
    favorite: bool = false,
    last_used: u64 = 0,
    input: u64 = 0,
    visits: @import("frequent.zig").Visits = .{},
    la: u64 = 0,
    lv: u64 = 0,
    name: [64]u8 = std.mem.zeroes([64]u8),
    name_len: u32 = 0,
    sub: [64]u8 = std.mem.zeroes([64]u8),
    sub_len: u32 = 0,
    pv: [96]u8 = std.mem.zeroes([96]u8),
    pv_len: u32 = 0,
    ag: u8 = 0,
    eta_deadline_tick: u64 = 0,
    eta_total_ms: u64 = 0,
    br: u8 = 0,
};

pub var g_session_save_pending: bool = false;
pub var g_inbox_active: bool = false;
pub var g_inbox_ws: [INBOX_MAX_WS]InboxWs = undefined;
pub var g_inbox_ws_count: u32 = 0;
pub var g_inbox_rows: [INBOX_MAX_ROWS]InboxRow = undefined;
pub var g_inbox_row_count: u32 = 0;
pub var g_inbox_sel: u32 = 0;
pub var g_layout_settings: ?@import("frequent.zig").Settings = null;
pub var g_inbox_tab: u32 = @import("frequent.zig").all_split;
pub var g_front_period: @import("frequent.zig").FrontPeriod = .{};
pub const TIMER_VISIT_DWELL: usize = 173;
pub var g_inbox_filter_active: bool = false;
pub var g_inbox_filter_buf: [64]u16 = std.mem.zeroes([64]u16);
pub var g_inbox_filter_len: u32 = 0;
pub var g_inbox_resume_sid: u32 = 0;
pub var g_inbox_resume_owner: usize = 0;
pub var g_inbox_step_context_active: bool = false;
pub var g_inbox_step_context_tab: u32 = 0;
pub var g_inbox_step_next_sid: u32 = 0;
pub var g_inbox_step_next_owner: usize = 0;
pub var g_inbox_step_jump_active: bool = false;
pub var g_inbox_undo_archive_valid: bool = false;
pub var g_inbox_undo_archive_sid: u32 = 0;
pub var g_inbox_undo_archive_owner: usize = 0;
pub var g_inbox_undo_archive_was_att: bool = false;
const PendingInboxArchive = struct { owner: usize = 0, sid: u32 = 0, deadline_tick: u64 = 0, seen: bool = false };
pub var g_inbox_pending_archives: [INBOX_MAX_ROWS]PendingInboxArchive = [_]PendingInboxArchive{.{}} ** INBOX_MAX_ROWS;
pub var g_unread_only: bool = false;
pub var g_console_font_override: i16 = 0;
pub var g_inbox_g_tick: u64 = 0;
pub const INBOX_MAX_SPLIT_TABS: usize = INBOX_MAX_WS + @import("frequent.zig").first_ws_split;
pub var g_inbox_split_xs: [INBOX_MAX_SPLIT_TABS]i32 = [_]i32{0} ** INBOX_MAX_SPLIT_TABS;
pub var g_inbox_split_xe: [INBOX_MAX_SPLIT_TABS]i32 = [_]i32{0} ** INBOX_MAX_SPLIT_TABS;
pub var g_inbox_split_ids: [INBOX_MAX_SPLIT_TABS]u32 = [_]u32{0} ** INBOX_MAX_SPLIT_TABS;
pub var g_inbox_split_tab_count: u32 = 0;

pub const AgentName = enum { none, claude, codex, pi, kimi, hax, grok, cursor };

pub const HIDDEN_IDLE_WATCHDOG_POLLS: u8 = 2;

pub const ChatTmuxSendJob = struct {
    key: chat_transcript.Identity,
    echo_id: u64,
    text: []u16,
    retry: bool,
    written: bool = false,
    rejected: bool = false,
    box_not_clear: bool = false,
    finished: std.atomic.Value(bool) = .init(false),
};
pub var g_chat_tmux_send_job: ?*ChatTmuxSendJob = null;

pub const ChatFullSettleJob = struct {
    key: chat_transcript.Identity,
    outbox_key: [CHAT_OUTBOX_KEY_CAP]u8,
    key_len: u32,
    entries: [16]struct { id: u64 = 0, sent_ms: i64 = 0, text: []u16 = &.{} } = @splat(.{}),
    count: usize = 0,
    after_ms: i64 = std.math.maxInt(i64),
    delivered_ms: [16]i64 = @splat(0),
    finished: std.atomic.Value(bool) = .init(false),
};
pub const ChatFullSettleAttempt = struct {
    key: [CHAT_OUTBOX_KEY_CAP]u8 = @splat(0),
    key_len: u32 = 0,
    at: u64 = 0,
    last_id: u64 = 0,
};
pub var g_chat_full_settle_job: ?*ChatFullSettleJob = null;
pub var g_chat_full_settle_attempts: [CHAT_OUTBOX_TOTAL_MAX]ChatFullSettleAttempt = @splat(.{});

pub const ISSUE_268_CHAT_FIND = @import("chat_find.zig").ISSUE_268_CHAT_FIND;
pub const SEARCH_CHAT_FIND_OFFSET: usize = 6397;
pub const WM_APP_CHAT_FIND: u32 = WM_APP + 202;
pub const TIMER_CHAT_FIND: usize = 107;
pub const CHAT_FIND_TOP_H: i32 = 52;
pub const ChatFindJob = struct {
    key: chat_transcript.Identity,
    id: u32,
    query: [801]u8 = @splat(0),
    result: ?@import("chat_find.zig").Result = null,
    ready: std.atomic.Value(bool) = .init(false),
};
pub var g_chat_find_open = false;
pub var g_chat_find_query: [401]u16 = @splat(0);
pub var g_chat_find_len: usize = 0;
pub var g_chat_find_id: u32 = 0;
pub var g_chat_find_due: u64 = 0;
pub var g_chat_find_key: chat_transcript.Identity = .{};
pub var g_chat_find_job: ?*ChatFindJob = null;
pub var g_chat_find_result: ?@import("chat_find.zig").Result = null;
pub var g_chat_find_selected: usize = 0;
pub var g_chat_find_jump = false;
pub var g_chat_find_error = false;

pub var g_chat_find_ranges: [500]?chat_markdown.Range = @splat(null);
pub var g_chat_find_ranges_hash: u64 = 0;
pub var g_chat_find_high_surrogate: u16 = 0;
pub var g_chat_find_consumed: [256]bool = @splat(false);
pub var g_chat_find_layout_open = false;

pub const ShellDoubleClick = struct { time: u32, point: POINT, shell_id: u32 };
pub var g_shell_double_click_first: ?ShellDoubleClick = null;
pub var g_shell_double_click_pending: ?ShellDoubleClick = null;
