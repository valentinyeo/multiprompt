const std = @import("std");
const windows = std.os.windows;

const app_name = "com.zigshell.bridge";
const version = @import("bridge_config").extension_version;
const max_native_message = 16 * 1024 * 1024;
const legacy_pipe_name = "\\\\.\\pipe\\zigshell-browser";
const isolated_pipe_name = "\\\\.\\pipe\\multiprompt-browser-isolated";
const legacy_extension_id = "eakdogphfehclpdnjecifppkcnfjnheh";
const isolated_extension_id = "fgclkhodglfogcckilgnihofmlpmiiao";
const browser_request_attempts = 4;

var g_window_id: ?i64 = null;

const BOOL = i32;
const INVALID_HANDLE_VALUE: windows.HANDLE = @ptrFromInt(std.math.maxInt(usize));
const GENERIC_READ: windows.DWORD = 0x80000000;
const GENERIC_WRITE: windows.DWORD = 0x40000000;
const FILE_SHARE_READ: windows.DWORD = 0x00000001;
const OPEN_EXISTING: windows.DWORD = 3;
const CREATE_ALWAYS: windows.DWORD = 2;
const FILE_ATTRIBUTE_NORMAL: windows.DWORD = 0x00000080;
const PIPE_ACCESS_INBOUND: windows.DWORD = 0x00000001;
const PIPE_TYPE_MESSAGE: windows.DWORD = 0x00000004;
const PIPE_READMODE_MESSAGE: windows.DWORD = 0x00000002;
const PIPE_WAIT: windows.DWORD = 0x00000000;
const PIPE_UNLIMITED_INSTANCES: windows.DWORD = 255;
const ERROR_PIPE_CONNECTED: windows.DWORD = 535;
const SOCKET = usize;
const INVALID_SOCKET: SOCKET = ~@as(SOCKET, 0);
const AF_INET: i16 = 2;
const SOCK_STREAM: i32 = 1;
const SOCKADDR_IN = extern struct {
    sin_family: i16,
    sin_port: u16,
    sin_addr: u32,
    sin_zero: [8]u8,
};
const WSADATA = extern struct { data: [408]u8 };
const NOTIFY_PORTS = [_]u16{ 19548, 19549, 19550, 19551, 19552, 19553, 19554, 19555, 19556, 19557, 19558, 19559 };

extern "kernel32" fn ReadFile(
    hFile: windows.HANDLE,
    lpBuffer: [*]u8,
    nNumberOfBytesToRead: windows.DWORD,
    lpNumberOfBytesRead: *windows.DWORD,
    lpOverlapped: ?*anyopaque,
) callconv(.winapi) BOOL;

extern "kernel32" fn WriteFile(
    hFile: windows.HANDLE,
    lpBuffer: [*]const u8,
    nNumberOfBytesToWrite: windows.DWORD,
    lpNumberOfBytesWritten: *windows.DWORD,
    lpOverlapped: ?*anyopaque,
) callconv(.winapi) BOOL;

extern "kernel32" fn GetLastError() callconv(.winapi) windows.DWORD;

extern "kernel32" fn CreateNamedPipeA(
    lpName: [*:0]const u8,
    dwOpenMode: windows.DWORD,
    dwPipeMode: windows.DWORD,
    nMaxInstances: windows.DWORD,
    nOutBufferSize: windows.DWORD,
    nInBufferSize: windows.DWORD,
    nDefaultTimeOut: windows.DWORD,
    lpSecurityAttributes: ?*anyopaque,
) callconv(.winapi) windows.HANDLE;

extern "kernel32" fn ConnectNamedPipe(
    hNamedPipe: windows.HANDLE,
    lpOverlapped: ?*anyopaque,
) callconv(.winapi) BOOL;

extern "kernel32" fn DisconnectNamedPipe(hNamedPipe: windows.HANDLE) callconv(.winapi) BOOL;

extern "kernel32" fn CreateFileA(
    lpFileName: [*:0]const u8,
    dwDesiredAccess: windows.DWORD,
    dwShareMode: windows.DWORD,
    lpSecurityAttributes: ?*anyopaque,
    dwCreationDisposition: windows.DWORD,
    dwFlagsAndAttributes: windows.DWORD,
    hTemplateFile: ?windows.HANDLE,
) callconv(.winapi) windows.HANDLE;

extern "kernel32" fn CloseHandle(hObject: windows.HANDLE) callconv(.winapi) BOOL;

extern "kernel32" fn Sleep(dwMilliseconds: windows.DWORD) callconv(.winapi) void;

extern "kernel32" fn GetCurrentProcessId() callconv(.winapi) windows.DWORD;

extern "kernel32" fn GetTickCount64() callconv(.winapi) u64;

extern "kernel32" fn GetEnvironmentVariableA(
    lpName: [*:0]const u8,
    lpBuffer: [*]u8,
    nSize: windows.DWORD,
) callconv(.winapi) windows.DWORD;

extern "ws2_32" fn WSAStartup(wVersionRequested: u16, lpWSAData: *WSADATA) callconv(.winapi) i32;
extern "ws2_32" fn socket(af: i32, socket_type: i32, protocol: i32) callconv(.winapi) SOCKET;
extern "ws2_32" fn connect(s: SOCKET, name: *const SOCKADDR_IN, namelen: i32) callconv(.winapi) i32;
extern "ws2_32" fn send(s: SOCKET, buf: [*]const u8, len: i32, flags: i32) callconv(.winapi) i32;
extern "ws2_32" fn closesocket(s: SOCKET) callconv(.winapi) i32;
extern "ws2_32" fn WSACleanup() callconv(.winapi) i32;
extern "ws2_32" fn WSAGetLastError() callconv(.winapi) i32;
extern "ws2_32" fn ioctlsocket(s: SOCKET, cmd: i32, arg: *u32) callconv(.winapi) i32;
const SocketSet = extern struct { count: u32, sockets: [64]SOCKET };
const SocketTimeout = extern struct { seconds: i32, microseconds: i32 };
extern "ws2_32" fn select(nfds: i32, read: ?*SocketSet, write: ?*SocketSet, except: ?*SocketSet, timeout: *const SocketTimeout) callconv(.winapi) i32;

const HostContext = struct {
    stdout: windows.HANDLE,
    write_mutex: SpinMutex = .{},
};

const SpinMutex = struct {
    state: std.atomic.Value(u8) = std.atomic.Value(u8).init(0),

    fn tryLock(self: *SpinMutex) bool {
        return self.state.cmpxchgStrong(0, 1, .acquire, .monotonic) == null;
    }

    fn unlock(self: *SpinMutex) void {
        self.state.store(0, .release);
    }
};

pub fn main(init: std.process.Init.Minimal) !void {
    const allocator = std.heap.page_allocator;

    var args = try std.process.Args.Iterator.initAllocator(init.args, allocator);
    defer args.deinit();

    _ = args.next();
    g_window_id = resolveWindowFromEnv(allocator);
    var command = args.next() orelse return runNativeHost(allocator, isolated_pipe_name);
    if (std.mem.eql(u8, command, "--window")) {
        const w = args.next() orelse return usage();
        g_window_id = std.fmt.parseInt(i64, w, 10) catch return usage();
        command = args.next() orelse return usage();
    }

    if (std.mem.eql(u8, command, "native")) {
        try runNativeHost(allocator, isolated_pipe_name);
    } else if (std.mem.startsWith(u8, command, "chrome-extension://")) {
        const native_pipe = if (std.mem.eql(u8, command, "chrome-extension://" ++ legacy_extension_id ++ "/"))
            legacy_pipe_name
        else
            isolated_pipe_name;
        try runNativeHost(allocator, native_pipe);
    } else if (std.mem.eql(u8, command, "open")) {
        const url = args.next() orelse "";
        if (args.next() != null) return usage();
        try sendOpenBrowserNotify(url);
    } else if (std.mem.eql(u8, command, "sidebar")) {
        if (args.next() != null) return usage();
        try sendSidebarNotify();
    } else if (std.mem.eql(u8, command, "status") or std.mem.eql(u8, command, "doctor")) {
        if (args.next() != null) return usage();
        try sendLocalStatus(allocator);
    } else if (std.mem.eql(u8, command, "navigate")) {
        const url = args.next() orelse return usage();
        const fields = buildNavigateFields(allocator, url, &args) catch |err| switch (err) {
            error.InvalidArguments => return usage(),
            else => return err,
        };
        defer allocator.free(fields);
        try sendBrowserRequest(allocator, "navigate", fields, null);
    } else if (std.mem.eql(u8, command, "create-pane-window")) {
        const url = args.next() orelse return usage();
        var app = false;
        var bounds: [4]i32 = .{ 0, 0, 0, 0 };
        var has_bounds = false;
        while (args.next()) |arg| {
            if (std.mem.eql(u8, arg, "--app")) {
                app = true;
            } else if (std.mem.eql(u8, arg, "--bounds")) {
                for (&bounds) |*value| {
                    value.* = std.fmt.parseInt(i32, args.next() orelse return usage(), 10) catch return usage();
                }
                has_bounds = true;
            } else {
                return usage();
            }
        }
        g_window_id = null;
        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        try fields.appendSlice("\"url\":");
        try appendJsonString(&fields, url);
        if (app) try fields.appendSlice(",\"app\":true");
        if (has_bounds) {
            try fields.print(",\"left\":{d},\"top\":{d},\"width\":{d},\"height\":{d}", .{ bounds[0], bounds[1], bounds[2], bounds[3] });
        }
        try sendBrowserRequest(allocator, "createPaneWindow", fields.items, null);
    } else if (std.mem.eql(u8, command, "back") or std.mem.eql(u8, command, "forward")) {
        if (args.next() != null) return usage();
        try sendBrowserRequest(allocator, command, "", null);
    } else if (std.mem.eql(u8, command, "reload")) {
        if (args.next() != null) return usage();
        try sendBrowserRequest(allocator, "reload", "", null);
    } else if (std.mem.eql(u8, command, "theme")) {
        g_window_id = null;
        const theme = args.next() orelse return usage();
        if (args.next() != null) return usage();
        const valid_theme = std.mem.eql(u8, theme, "dark") or
            std.mem.eql(u8, theme, "mid") or
            std.mem.eql(u8, theme, "light") or
            std.mem.eql(u8, theme, "amoled") or
            std.mem.eql(u8, theme, "edgegray") or
            std.mem.eql(u8, theme, "multiprompt") or
            std.mem.eql(u8, theme, "devblue");
        if (!valid_theme) return usage();
        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        try fields.appendSlice("\"theme\":");
        try appendJsonString(&fields, theme);
        try sendRequiredBrowserRequest(allocator, "setTheme", fields.items, 8);
    } else if (std.mem.eql(u8, command, "protect-window")) {
        var shell_id: ?i64 = null;
        var owner_pid: ?u32 = null;
        while (args.next()) |arg| {
            if (std.mem.eql(u8, arg, "--shell-id")) {
                const value = args.next() orelse return usage();
                shell_id = std.fmt.parseInt(i64, value, 10) catch return usage();
                if (shell_id.? < 0) return usage();
            } else if (std.mem.eql(u8, arg, "--owner-pid")) {
                owner_pid = std.fmt.parseInt(u32, args.next() orelse return usage(), 10) catch return usage();
            } else {
                return usage();
            }
        }
        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        if (shell_id) |sid| try fields.print("\"shellId\":{d}", .{sid});
        if (owner_pid) |pid| {
            if (fields.items.len > 0) try fields.append(',');
            try fields.print("\"ownerPid\":{d}", .{pid});
        }
        try sendRequiredBrowserRequest(allocator, "protectWindow", fields.items, 8);
    } else if (std.mem.eql(u8, command, "browser-drop-gesture")) {
        if (args.next() != null) return usage();
        try sendRequiredBrowserRequest(allocator, "browserDropGesture", "", 3);
    } else if (std.mem.eql(u8, command, "routing-audit")) {
        g_window_id = null;
        const limit = try parseLimitArgs(&args, command, 50);
        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        try fields.print("\"limit\":{}", .{limit});
        try sendBrowserRequest(allocator, "routingAudit", fields.items, null);
    } else if (std.mem.eql(u8, command, "tabs")) {
        if (args.next()) |arg| {
            if (!std.mem.eql(u8, arg, "--close")) return usage();
            const target = args.next() orelse return usage();
            if (args.next() != null) return usage();
            var fields = std.array_list.Managed(u8).init(allocator);
            defer fields.deinit();
            try appendTabTargetField(&fields, target);
            try sendBrowserRequest(allocator, "closeTab", fields.items, null);
        } else {
            try sendBrowserRequest(allocator, "tabs", "", null);
        }
    } else if (std.mem.eql(u8, command, "active-tab")) {
        try sendBrowserRequest(allocator, "activeTab", "", null);
    } else if (std.mem.eql(u8, command, "url")) {
        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        const tab = try parseOnlyTabArg(&args);
        if (tab) |target| try appendTabTargetField(&fields, target);
        try sendBrowserRequest(allocator, "url", fields.items, null);
    } else if (std.mem.eql(u8, command, "activate")) {
        const tab_id_arg = args.next() orelse return usage();
        var target_only = false;
        if (args.next()) |flag| {
            if (!std.mem.eql(u8, flag, "--target-only") or args.next() != null) return usage();
            target_only = true;
        }
        const tab_id = std.fmt.parseInt(i64, tab_id_arg, 10) catch return usage();
        if (tab_id <= 0) return usage();
        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        try fields.print("\"tabId\":{d}", .{tab_id});
        if (target_only) try fields.appendSlice(",\"targetOnly\":true");
        try sendBrowserRequest(allocator, "activate", fields.items, null);
    } else if (std.mem.eql(u8, command, "close-tab")) {
        const target = args.next() orelse return usage();
        if (args.next() != null) return usage();
        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        try appendTabTargetField(&fields, target);
        try sendBrowserRequest(allocator, "closeTab", fields.items, null);
    } else if (std.mem.eql(u8, command, "tab")) {
        const action = args.next() orelse return usage();
        if (!std.mem.eql(u8, action, "close")) return usage();
        const target = args.next() orelse return usage();
        if (args.next() != null) return usage();
        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        try appendTabTargetField(&fields, target);
        try sendBrowserRequest(allocator, "closeTab", fields.items, null);
    } else if (std.mem.eql(u8, command, "text") or std.mem.eql(u8, command, "get-text")) {
        const parsed = try parseLimitTabArgs(&args, command, 2000);
        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        try fields.print("\"limit\":{}", .{parsed.limit});
        if (parsed.tab) |target| try appendTabTargetField(&fields, target);
        try sendBrowserRequest(allocator, "text", fields.items, null);
    } else if (std.mem.eql(u8, command, "links")) {
        const parsed = try parseLimitTabArgs(&args, command, 50);
        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        try fields.print("\"limit\":{}", .{parsed.limit});
        if (parsed.tab) |target| try appendTabTargetField(&fields, target);
        try sendBrowserRequest(allocator, "links", fields.items, null);
    } else if (std.mem.eql(u8, command, "snapshot")) {
        const parsed = try parseLimitTabArgs(&args, command, 2000);
        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        try fields.print("\"limit\":{}", .{parsed.limit});
        if (parsed.tab) |target| try appendTabTargetField(&fields, target);
        try sendBrowserRequest(allocator, "snapshot", fields.items, null);
    } else if (std.mem.eql(u8, command, "find")) {
        const first = args.next() orelse return usage();
        const parsed = try collectTextAndTabArgs(allocator, &args, first);
        defer allocator.free(parsed.text);

        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        try fields.appendSlice("\"query\":");
        try appendJsonString(&fields, parsed.text);
        if (parsed.tab) |target| try appendTabTargetField(&fields, target);
        try sendBrowserRequest(allocator, "find", fields.items, null);
    } else if (std.mem.eql(u8, command, "click")) {
        const first = args.next() orelse return usage();
        const parsed = try collectTextAndTabArgs(allocator, &args, first);
        defer allocator.free(parsed.text);
        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        try fields.appendSlice("\"selector\":");
        try appendJsonString(&fields, parsed.text);
        if (parsed.tab) |target| try appendTabTargetField(&fields, target);
        try sendBrowserRequest(allocator, "click", fields.items, null);
    } else if (std.mem.eql(u8, command, "type")) {
        var first = args.next() orelse return usage();
        var tab: ?[]const u8 = null;
        if (std.mem.eql(u8, first, "--tab")) {
            tab = args.next() orelse return usage();
            first = args.next() orelse return usage();
        }
        const keys = std.mem.eql(u8, first, "--keys");
        if (keys) first = args.next() orelse return usage();
        const second = args.next();
        const text = try joinRemainingArgs(allocator, &args, second orelse first);
        defer allocator.free(text);

        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        if (second != null) {
            try fields.appendSlice("\"selector\":");
            try appendJsonString(&fields, first);
            try fields.appendSlice(",");
        }
        try fields.appendSlice("\"text\":");
        try appendJsonString(&fields, text);
        if (tab) |target| try appendTabTargetField(&fields, target);
        if (keys) try fields.appendSlice(",\"keys\":true");
        try sendBrowserRequest(allocator, "type", fields.items, null);
    } else if (std.mem.eql(u8, command, "insert")) {
        const first = args.next() orelse return usage();
        const text = try joinRemainingArgs(allocator, &args, first);
        defer allocator.free(text);

        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        try fields.appendSlice("\"text\":");
        try appendJsonString(&fields, text);
        try sendBrowserRequest(allocator, "insert", fields.items, null);
    } else if (std.mem.eql(u8, command, "cursor")) {
        const action = args.next() orelse "on";
        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        try fields.appendSlice("\"action\":");
        try appendJsonString(&fields, action);
        if (std.mem.eql(u8, action, "move") or std.mem.eql(u8, action, "click")) {
            const x_arg = args.next() orelse return usage();
            const y_arg = args.next() orelse return usage();
            const x = std.fmt.parseInt(i64, x_arg, 10) catch return usage();
            const y = std.fmt.parseInt(i64, y_arg, 10) catch return usage();
            try fields.print(",\"x\":{d},\"y\":{d}", .{ x, y });
        }
        try sendBrowserRequest(allocator, "cursor", fields.items, null);
    } else if (std.mem.eql(u8, command, "eval") or std.mem.eql(u8, command, "script")) {
        const first = args.next() orelse return usage();
        const parsed = try collectTextAndTabArgs(allocator, &args, first);
        defer allocator.free(parsed.text);

        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        try fields.appendSlice("\"code\":");
        try appendJsonString(&fields, parsed.text);
        if (parsed.tab) |target| try appendTabTargetField(&fields, target);
        try sendBrowserRequest(allocator, "eval", fields.items, null);
    } else if (std.mem.eql(u8, command, "key")) {
        const first = args.next() orelse return usage();
        const combo = try joinRemainingArgs(allocator, &args, first);
        defer allocator.free(combo);

        try sendKeyChord(allocator, combo);
    } else if (std.mem.eql(u8, command, "screenshot")) {
        var output_path: ?[]const u8 = null;
        var tab: ?[]const u8 = null;
        while (args.next()) |arg| {
            if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
                output_path = args.next() orelse return usage();
            } else if (std.mem.eql(u8, arg, "--tab")) {
                tab = args.next() orelse return usage();
            } else {
                return usage();
            }
        }
        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        if (tab) |target| try appendTabTargetField(&fields, target);
        try sendBrowserRequest(allocator, "screenshot", fields.items, output_path);
    } else if (std.mem.eql(u8, command, "console")) {
        var limit: usize = 50;
        var clear = false;
        while (args.next()) |arg| {
            if (std.mem.eql(u8, arg, "--limit") or std.mem.eql(u8, arg, "-n")) {
                const value = args.next() orelse return usage();
                limit = std.fmt.parseInt(usize, value, 10) catch return usage();
                if (limit == 0 or limit > 500) return usage();
            } else if (std.mem.eql(u8, arg, "--clear")) {
                clear = true;
            } else {
                return usage();
            }
        }
        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        try fields.print("\"limit\":{},\"clear\":{s}", .{ limit, if (clear) "true" else "false" });
        try sendBrowserRequest(allocator, "console", fields.items, null);
    } else if (std.mem.eql(u8, command, "extension-reload")) {
        if (args.next() != null) return usage();
        try sendBrowserRequest(allocator, "extensionReload", "", null);
    } else if (std.mem.eql(u8, command, "shoturl")) {
        var user_initiated = false;
        if (args.next()) |flag| {
            if (!std.mem.eql(u8, flag, "--user-initiated") or args.next() != null) return usage();
            user_initiated = true;
        }
        try sendBrowserRequest(allocator, "shoturl", if (user_initiated) "\"userInitiated\":true" else "", null);
    } else if (std.mem.eql(u8, command, "cdp")) {
        const cdp_method = args.next() orelse return usage();
        const params_json = args.next();

        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        try fields.appendSlice("\"cdpMethod\":");
        try appendJsonString(&fields, cdp_method);
        if (params_json) |params| {
            try fields.appendSlice(",\"params\":");
            try fields.appendSlice(params);
        }
        try sendBrowserRequest(allocator, "cdp", fields.items, null);
    } else if (std.mem.eql(u8, command, "resolve-window")) {
        var match: ?[]const u8 = null;
        var focused = false;
        var shell_id: ?u32 = null;
        var owner_pid: ?u32 = null;
        while (args.next()) |arg| {
            if (std.mem.eql(u8, arg, "--match")) {
                match = args.next() orelse return usage();
            } else if (std.mem.eql(u8, arg, "--focused")) {
                focused = true;
            } else if (std.mem.eql(u8, arg, "--shell-id")) {
                shell_id = std.fmt.parseInt(u32, args.next() orelse return usage(), 10) catch return usage();
            } else if (std.mem.eql(u8, arg, "--owner-pid")) {
                owner_pid = std.fmt.parseInt(u32, args.next() orelse return usage(), 10) catch return usage();
            } else {
                return usage();
            }
        }
        g_window_id = null;
        var fields = std.array_list.Managed(u8).init(allocator);
        defer fields.deinit();
        var first_field = true;
        if (match) |m| {
            try fields.appendSlice("\"match\":");
            try appendJsonString(&fields, m);
            first_field = false;
        }
        if (focused) {
            if (!first_field) try fields.append(',');
            try fields.appendSlice("\"focused\":true");
            first_field = false;
        }
        if (shell_id) |sid| {
            if (!first_field) try fields.append(',');
            try fields.print("\"shellId\":{d}", .{sid});
            first_field = false;
        }
        if (owner_pid) |pid| {
            if (!first_field) try fields.append(',');
            try fields.print("\"ownerPid\":{d}", .{pid});
        }
        try sendBrowserRequest(allocator, "resolveWindow", fields.items, null);
    } else if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "-h")) {
        try usage();
    } else if (std.mem.eql(u8, command, "manifest")) {
        const exe_path = args.next() orelse return usage();
        const extension_id = args.next() orelse return usage();
        try printManifest(allocator, exe_path, extension_id);
    } else if (std.mem.eql(u8, command, "version")) {
        try writeStdout(version ++ "\n");
    } else {
        return usage();
    }
}

fn usage() !void {
    try writeStderr(
        \\multiprompt-browser [--window <id>] <command> [args]
        \\
        \\Global flags (before the command):
        \\  --window <id>                  Target a specific Chrome windowId (overrides env)
        \\  BROWSER_CLI_WINDOW=<id>        Target window via environment variable
        \\  BROWSER_CLI_WINDOW_FILE=<path> Target window id read from a file
        \\
        \\Commands:
        \\  native                         Run as a Chrome Native Messaging host (default)
        \\  navigate <url> [--new-tab] [--activate]  Reuse the target tab; --new-tab opens a background tab; --activate only for the app's own user actions (ignored from remote zsb)
        \\  create-pane-window <url> [--app] [--bounds L T W H]  Internal: open a pane launch placeholder as an inactive window
        \\  back                           Navigate active browser tab history back
        \\  forward                        Navigate active browser tab history forward
        \\  reload                         Reload the active browser tab
        \\  extension-reload               Reload unpacked extension code without restarting the app
        \\  theme <name>                   Match isolated Edge chrome to the multiprompt theme
        \\  protect-window [--shell-id n]  Mark --window as a multiprompt pane; external links are moved out
        \\  browser-drop-gesture           Internal: record a physical URL/bookmark drop into --window
        \\  routing-audit [--limit n]      Show recent external-link routing and protection decisions
        \\  open [url]                     Open this shell's docked multiprompt browser pane
        \\  sidebar                        Reveal this shell's multiprompt sidebar
        \\  status / doctor                Report local bridge/pane targeting state
        \\  tabs                           List browser tabs
        \\  active-tab                     Show the active tab
        \\  url [--tab <id|match>]         Show a targeted tab URL
        \\  activate <tabId> [--target-only] Activate a tab in this session's bound pane (remote agents: target only)
        \\  close-tab <id|match>            Close a tab; aliases: tab close, tabs --close
        \\  text [--limit n|--full] [--tab <id|match>]  Return visible text across frames
        \\  links [--limit n|--full] [--tab <id|match>] Return links across frames
        \\  snapshot [--limit n|--full] [--tab <id|match>]  Return compact page state across frames
        \\  find <text> [--tab <id|match>] Find text snippets across frames
        \\  click <selector> [--tab <id|match>]  Click a CSS selector across frames
        \\  type <text>                    Type trusted text at the focused editable
        \\  type <selector> <text>         Click a selector and replace it with trusted text
        \\  type --keys [selector] <text>  Type individual keys for keyboard-driven typeaheads
        \\  insert <text>                  Insert trusted text at the page cursor
        \\  cursor [on|off|move x y|click x y]  Show/animate the visual cursor overlay
        \\  eval <js>                      Execute JavaScript in MAIN world; awaits promises
        \\  key <combo>                    Send a native key chord, e.g. "Alt+2" or "Ctrl+B"
        \\  screenshot [-o file.png] [--tab <id|match>] Return a PNG or save it
        \\  console [-n N|--clear]         Return recent console and page-log entries
        \\  shoturl                        Upload active tab screenshot and paste its link into the owning shell
        \\  cdp <method> [params-json]     Send a Chrome DevTools Protocol command
        \\  resolve-window [--shell-id N] [--owner-pid N] [--match <substr>] [--focused]   Resolve a normal pane window
        \\  manifest <exe> <extension-id>  Print a Native Messaging manifest
        \\  version                        Print version
        \\  help                           Print help
        \\
        \\Remote recovery after SSH/WiFi drops: reconnect the multiprompt SSH/tmux
        \\session first so the reverse tunnel exists, then open/rebind the pane,
        \\then run `multiprompt-browser status`.
        \\
    );
}

fn printManifest(allocator: std.mem.Allocator, exe_path: []const u8, extension_id: []const u8) !void {
    var manifest = std.array_list.Managed(u8).init(allocator);
    defer manifest.deinit();

    const origin = try std.fmt.allocPrint(allocator, "chrome-extension://{s}/", .{extension_id});
    defer allocator.free(origin);
    const isolated_origin = "chrome-extension://" ++ isolated_extension_id ++ "/";
    const legacy_origin = "chrome-extension://" ++ legacy_extension_id ++ "/";

    try manifest.appendSlice("{\n  \"name\": ");
    try appendJsonString(&manifest, app_name);
    try manifest.appendSlice(",\n  \"description\": ");
    try appendJsonString(&manifest, "multiprompt browser bridge native messaging host");
    try manifest.appendSlice(",\n  \"path\": ");
    try appendJsonString(&manifest, exe_path);
    try manifest.appendSlice(",\n  \"type\": \"stdio\",\n  \"allowed_origins\": [\n    ");
    try appendJsonString(&manifest, origin);
    if (!std.mem.eql(u8, origin, isolated_origin)) {
        try manifest.appendSlice(",\n    ");
        try appendJsonString(&manifest, isolated_origin);
    }
    if (!std.mem.eql(u8, origin, legacy_origin)) {
        try manifest.appendSlice(",\n    ");
        try appendJsonString(&manifest, legacy_origin);
    }
    try manifest.appendSlice("\n  ]\n}\n");

    try writeStdout(manifest.items);
}

fn getEnvVar(buf: []u8, name: [*:0]const u8) ?[]const u8 {
    const len = GetEnvironmentVariableA(name, buf.ptr, @intCast(buf.len));
    if (len == 0 or len >= buf.len) return null;
    return buf[0..len];
}

fn htons(v: u16) u16 {
    return @byteSwap(v);
}

fn failOpenBrowser(message: []const u8) noreturn {
    writeStderr(message) catch {};
    std.process.exit(1);
}

fn sendOpenBrowserNotify(url: []const u8) !void {
    var port_buf: [32]u8 = undefined;
    var sid_buf: [32]u8 = undefined;
    const port_text_raw = getEnvVar(&port_buf, "ZIGSHELL_NOTIFY_PORT") orelse
        failOpenBrowser("multiprompt-browser: open must run inside a multiprompt tab (missing ZIGSHELL_NOTIFY_PORT)\n");
    const sid_text_raw = getEnvVar(&sid_buf, "ZIGSHELL_SHELL_ID") orelse
        failOpenBrowser("multiprompt-browser: open must run inside a multiprompt tab (missing ZIGSHELL_SHELL_ID)\n");
    const port_text = std.mem.trim(u8, port_text_raw, " \t\r\n");
    const sid_text = std.mem.trim(u8, sid_text_raw, " \t\r\n");
    const port = std.fmt.parseInt(u16, port_text, 10) catch
        failOpenBrowser("multiprompt-browser: invalid ZIGSHELL_NOTIFY_PORT\n");
    if (port == 0) failOpenBrowser("multiprompt-browser: invalid ZIGSHELL_NOTIFY_PORT\n");
    if (sid_text.len == 0) failOpenBrowser("multiprompt-browser: invalid ZIGSHELL_SHELL_ID\n");

    var wsa: WSADATA = undefined;
    if (WSAStartup(0x0202, &wsa) != 0) {
        failOpenBrowser("multiprompt-browser: Winsock startup failed\n");
    }

    const s = socket(AF_INET, SOCK_STREAM, 0);
    if (s == INVALID_SOCKET) {
        failOpenBrowser("multiprompt-browser: socket create failed\n");
    }
    defer _ = closesocket(s);

    var addr = SOCKADDR_IN{
        .sin_family = AF_INET,
        .sin_port = htons(port),
        .sin_addr = 0x0100007F,
        .sin_zero = std.mem.zeroes([8]u8),
    };
    if (connect(s, &addr, @sizeOf(SOCKADDR_IN)) != 0) {
        failOpenBrowser("multiprompt-browser: cannot connect to multiprompt notify port\n");
    }

    var payload: [1200]u8 = undefined;
    var pos: usize = 0;
    const prefix = "OPENBROWSER:";
    if (prefix.len + sid_text.len + 2 > payload.len) {
        failOpenBrowser("multiprompt-browser: OPENBROWSER payload too large\n");
    }
    @memcpy(payload[pos .. pos + prefix.len], prefix);
    pos += prefix.len;
    @memcpy(payload[pos .. pos + sid_text.len], sid_text);
    pos += sid_text.len;
    payload[pos] = ':';
    pos += 1;
    const url_len = @min(url.len, payload.len - pos - 1);
    if (url_len > 0) {
        @memcpy(payload[pos .. pos + url_len], url[0..url_len]);
        pos += url_len;
    }
    payload[pos] = '\n';
    pos += 1;

    var sent: usize = 0;
    while (sent < pos) {
        const n = send(s, payload[sent..pos].ptr, @intCast(pos - sent), 0);
        if (n <= 0) failOpenBrowser("multiprompt-browser: failed to send OPENBROWSER notify\n");
        sent += @intCast(n);
    }
    try writeStdout("ok\n");
}

const UploadConfig = struct {
    secret: [512]u8 = std.mem.zeroes([512]u8),
    secret_len: usize = 0,
    base_url: [512]u8 = std.mem.zeroes([512]u8),
    base_url_len: usize = 0,

    fn secretSlice(self: *const UploadConfig) []const u8 {
        return self.secret[0..self.secret_len];
    }

    fn baseUrlSlice(self: *const UploadConfig) []const u8 {
        return self.base_url[0..self.base_url_len];
    }
};

fn extractConfigQuotedValue(line: []const u8, prefix: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, line, prefix)) return null;
    const rest = line[prefix.len..];
    const end = std.mem.indexOfScalar(u8, rest, '"') orelse return null;
    return rest[0..end];
}

fn copyConfigValue(dst: *[512]u8, dst_len: *usize, value: []const u8) bool {
    if (value.len == 0 or value.len >= dst.len) return false;
    @memcpy(dst[0..value.len], value);
    dst_len.* = value.len;
    return true;
}

fn parseUploadConfig(contents: []const u8) ?UploadConfig {
    var cfg = UploadConfig{};
    var lines = std.mem.splitScalar(u8, contents, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r\n");
        if (extractConfigQuotedValue(line, "upload_secret = \"")) |value| {
            _ = copyConfigValue(&cfg.secret, &cfg.secret_len, value);
        } else if (extractConfigQuotedValue(line, "api_base_url = \"")) |value| {
            _ = copyConfigValue(&cfg.base_url, &cfg.base_url_len, value);
        }
    }
    if (cfg.secret_len == 0 or cfg.base_url_len == 0) return null;
    return cfg;
}

fn readUploadConfig() ?UploadConfig {
    var local_buf: [512]u8 = undefined;
    const local = getEnvVar(&local_buf, "LOCALAPPDATA") orelse return null;

    var path_buf: [768]u8 = undefined;
    const path = std.fmt.bufPrintZ(&path_buf, "{s}\\screencast2-go\\config.toml", .{local}) catch return null;
    const file = CreateFileA(
        path.ptr,
        GENERIC_READ,
        FILE_SHARE_READ,
        null,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        null,
    );
    if (file == INVALID_HANDLE_VALUE) return null;
    defer _ = CloseHandle(file);

    var contents: [8192]u8 = undefined;
    var read: windows.DWORD = 0;
    if (ReadFile(file, &contents, @intCast(contents.len), &read, null) == 0 or read == 0) return null;
    return parseUploadConfig(contents[0..read]);
}

fn makeUploadConfigResponse(allocator: std.mem.Allocator, id: ?std.json.Value) ![]u8 {
    var response = std.array_list.Managed(u8).init(allocator);
    errdefer response.deinit();

    try response.appendSlice("{\"id\":");
    try appendJsonId(&response, id);
    if (readUploadConfig()) |cfg| {
        try response.appendSlice(",\"secret\":");
        try appendJsonString(&response, cfg.secretSlice());
        try response.appendSlice(",\"baseUrl\":");
        try appendJsonString(&response, cfg.baseUrlSlice());
    } else {
        try response.appendSlice(",\"error\":\"screencast2 config not found\"");
    }
    try response.append('}');
    return response.toOwnedSlice();
}

fn sendShotNotify(window_id: i64, url: []const u8, user_initiated: bool) bool {
    return sendShotNotifyToPorts(window_id, url, user_initiated, &NOTIFY_PORTS);
}

fn sendShotNotifyToPorts(window_id: i64, url: []const u8, user_initiated: bool, ports: []const u16) bool {
    if (window_id <= 0 or url.len == 0 or url.len > 600 or !std.mem.startsWith(u8, url, "http")) return false;

    var wsa: WSADATA = undefined;
    if (WSAStartup(0x0202, &wsa) != 0) return false;
    defer _ = WSACleanup();

    var payload: [720]u8 = undefined;
    const out = std.fmt.bufPrint(&payload, "{s}:{d}:{s}", .{ if (user_initiated) "SHOTUSER" else "SHOT", window_id, url }) catch return false;
    var delivered = false;
    for (ports) |port| {
        const s = socket(AF_INET, SOCK_STREAM, 0);
        if (s == INVALID_SOCKET) continue;
        defer _ = closesocket(s);
        var nonblocking: u32 = 1;
        if (ioctlsocket(s, @bitCast(@as(u32, 0x8004667e)), &nonblocking) != 0) continue;
        var addr = SOCKADDR_IN{
            .sin_family = AF_INET,
            .sin_port = htons(port),
            .sin_addr = 0x0100007F,
            .sin_zero = std.mem.zeroes([8]u8),
        };
        const deadline = GetTickCount64() + 100;
        if (connect(s, &addr, @sizeOf(SOCKADDR_IN)) != 0) {
            if (WSAGetLastError() != 10035 or !waitShotSocketWritable(s, deadline)) continue;
        }
        var sent: usize = 0;
        while (sent < out.len) {
            const n = send(s, out[sent..].ptr, @intCast(out.len - sent), 0);
            if (n > 0) {
                sent += @intCast(n);
            } else if (n < 0 and WSAGetLastError() == 10035 and waitShotSocketWritable(s, deadline)) {
                continue;
            } else break;
        }
        if (sent == out.len) delivered = true;
    }
    return delivered;
}

fn waitShotSocketWritable(s: SOCKET, deadline: u64) bool {
    const now = GetTickCount64();
    if (now >= deadline) return false;
    var writable = SocketSet{ .count = 1, .sockets = undefined };
    writable.sockets[0] = s;
    var failed = writable;
    const timeout = SocketTimeout{ .seconds = 0, .microseconds = @intCast((deadline - now) * 1000) };
    return select(0, null, &writable, &failed, &timeout) > 0 and failed.count == 0 and writable.count == 1;
}

test "consecutive screenshot deliveries skip closed ports and reach every listener" {
    const net = struct {
        extern "ws2_32" fn bind(s: SOCKET, addr: *const SOCKADDR_IN, len: i32) callconv(.winapi) i32;
        extern "ws2_32" fn listen(s: SOCKET, backlog: i32) callconv(.winapi) i32;
        extern "ws2_32" fn getsockname(s: SOCKET, addr: *SOCKADDR_IN, len: *i32) callconv(.winapi) i32;
        extern "ws2_32" fn accept(s: SOCKET, addr: ?*SOCKADDR_IN, len: ?*i32) callconv(.winapi) SOCKET;
        extern "ws2_32" fn recv(s: SOCKET, buf: [*]u8, len: i32, flags: i32) callconv(.winapi) i32;
    };
    var wsa: WSADATA = undefined;
    try std.testing.expectEqual(@as(i32, 0), WSAStartup(0x0202, &wsa));
    defer _ = WSACleanup();
    var sockets: [12]SOCKET = @splat(INVALID_SOCKET);
    defer for (sockets) |s| {
        if (s != INVALID_SOCKET) _ = closesocket(s);
    };
    var ports: [12]u16 = undefined;
    for (&sockets, &ports, 0..) |*s, *port_number, i| {
        s.* = socket(AF_INET, SOCK_STREAM, 0);
        try std.testing.expect(s.* != INVALID_SOCKET);
        var addr = SOCKADDR_IN{ .sin_family = AF_INET, .sin_port = 0, .sin_addr = 0x0100007F, .sin_zero = @splat(0) };
        try std.testing.expectEqual(@as(i32, 0), net.bind(s.*, &addr, @sizeOf(SOCKADDR_IN)));
        var size: i32 = @sizeOf(SOCKADDR_IN);
        try std.testing.expectEqual(@as(i32, 0), net.getsockname(s.*, &addr, &size));
        port_number.* = htons(addr.sin_port);
        if (i == 0 or i == 11) try std.testing.expectEqual(@as(i32, 0), net.listen(s.*, 8));
    }
    const started = GetTickCount64();
    for (0..3) |shot| {
        const user_initiated = shot == 2;
        try std.testing.expect(sendShotNotifyToPorts(123, "https://example.invalid/shot", user_initiated, &ports));
        try std.testing.expect(GetTickCount64() - started < 5000);
        for ([_]usize{ 0, 11 }) |i| {
            const client = net.accept(sockets[i], null, null);
            try std.testing.expect(client != INVALID_SOCKET);
            defer _ = closesocket(client);
            var payload: [128]u8 = undefined;
            var len: usize = 0;
            while (len < payload.len) {
                const n = net.recv(client, payload[len..].ptr, @intCast(payload.len - len), 0);
                if (n <= 0) break;
                len += @intCast(n);
            }
            try std.testing.expectEqualStrings(if (user_initiated) "SHOTUSER:123:https://example.invalid/shot" else "SHOT:123:https://example.invalid/shot", payload[0..len]);
        }
    }
    try std.testing.expect(!sendShotNotifyToPorts(123, "https://example.invalid/shot", false, ports[1..11]));
}

fn handlePasteUrl(
    allocator: std.mem.Allocator,
    id: ?std.json.Value,
    object: std.json.ObjectMap,
) ![]u8 {
    const window_id = getI64(object.get("windowId")) orelse
        return makeErrorResponse(allocator, id, "pasteUrl requires windowId");
    const url = getString(object.get("url")) orelse
        return makeErrorResponse(allocator, id, "pasteUrl requires url");
    if (!std.mem.startsWith(u8, url, "http")) {
        return makeErrorResponse(allocator, id, "pasteUrl url must start with http");
    }
    if (url.len > 600) {
        return makeErrorResponse(allocator, id, "pasteUrl url too long");
    }

    if (!sendShotNotify(window_id, url, getBool(object.get("userInitiated")))) {
        return makeErrorResponse(allocator, id, "multiprompt did not accept screenshot URL");
    }
    return makeResultResponse(allocator, id, "{\"sent\":true}");
}

fn failSidebar(message: []const u8) noreturn {
    writeStderr(message) catch {};
    std.process.exit(1);
}

fn sendSidebarNotify() !void {
    var port_buf: [32]u8 = undefined;
    var sid_buf: [32]u8 = undefined;
    const port_text_raw = getEnvVar(&port_buf, "ZIGSHELL_NOTIFY_PORT") orelse
        failSidebar("multiprompt-browser: sidebar must run inside a multiprompt tab (missing ZIGSHELL_NOTIFY_PORT)\n");
    const sid_text_raw = getEnvVar(&sid_buf, "ZIGSHELL_SHELL_ID") orelse
        failSidebar("multiprompt-browser: sidebar must run inside a multiprompt tab (missing ZIGSHELL_SHELL_ID)\n");
    const port_text = std.mem.trim(u8, port_text_raw, " \t\r\n");
    const sid_text = std.mem.trim(u8, sid_text_raw, " \t\r\n");
    const port = std.fmt.parseInt(u16, port_text, 10) catch
        failSidebar("multiprompt-browser: invalid ZIGSHELL_NOTIFY_PORT\n");
    if (port == 0) failSidebar("multiprompt-browser: invalid ZIGSHELL_NOTIFY_PORT\n");
    if (sid_text.len == 0) failSidebar("multiprompt-browser: invalid ZIGSHELL_SHELL_ID\n");

    var wsa: WSADATA = undefined;
    if (WSAStartup(0x0202, &wsa) != 0) {
        failSidebar("multiprompt-browser: Winsock startup failed\n");
    }

    const s = socket(AF_INET, SOCK_STREAM, 0);
    if (s == INVALID_SOCKET) {
        failSidebar("multiprompt-browser: socket create failed\n");
    }
    defer _ = closesocket(s);

    var addr = SOCKADDR_IN{
        .sin_family = AF_INET,
        .sin_port = htons(port),
        .sin_addr = 0x0100007F,
        .sin_zero = std.mem.zeroes([8]u8),
    };
    if (connect(s, &addr, @sizeOf(SOCKADDR_IN)) != 0) {
        failSidebar("multiprompt-browser: cannot connect to multiprompt notify port\n");
    }

    var payload: [128]u8 = undefined;
    var pos: usize = 0;
    const prefix = "SIDEBAR:";
    if (prefix.len + sid_text.len + 1 > payload.len) {
        failSidebar("multiprompt-browser: SIDEBAR payload too large\n");
    }
    @memcpy(payload[pos .. pos + prefix.len], prefix);
    pos += prefix.len;
    @memcpy(payload[pos .. pos + sid_text.len], sid_text);
    pos += sid_text.len;
    payload[pos] = '\n';
    pos += 1;

    var sent: usize = 0;
    while (sent < pos) {
        const n = send(s, payload[sent..pos].ptr, @intCast(pos - sent), 0);
        if (n <= 0) failSidebar("multiprompt-browser: failed to send SIDEBAR notify\n");
        sent += @intCast(n);
    }
    try writeStdout("ok\n");
}

fn resolveWindowFromEnv(allocator: std.mem.Allocator) ?i64 {
    _ = allocator;
    var buf: [256]u8 = undefined;

    if (getEnvVar(&buf, "BROWSER_CLI_WINDOW")) |val| {
        const trimmed = std.mem.trim(u8, val, " \t\r\n");
        if (std.fmt.parseInt(i64, trimmed, 10)) |id| {
            return id;
        } else |_| {}
    }

    if (getEnvVar(&buf, "BROWSER_CLI_WINDOW_FILE")) |path| {
        var path_buf: [260]u8 = undefined;
        if (path.len >= path_buf.len) return null;
        @memcpy(path_buf[0..path.len], path);
        path_buf[path.len] = 0;
        const file = CreateFileA(
            @ptrCast(&path_buf),
            0x80000000,
            1,
            null,
            OPEN_EXISTING,
            FILE_ATTRIBUTE_NORMAL,
            null,
        );
        if (file == INVALID_HANDLE_VALUE) return null;
        defer _ = CloseHandle(file);
        var file_buf: [64]u8 = undefined;
        var read: windows.DWORD = 0;
        if (ReadFile(file, &file_buf, @intCast(file_buf.len), &read, null) == 0) return null;
        const trimmed = std.mem.trim(u8, file_buf[0..read], " \t\r\n");
        if (std.fmt.parseInt(i64, trimmed, 10)) |id| {
            return id;
        } else |_| {}
    }

    return null;
}

fn runNativeHost(allocator: std.mem.Allocator, command_pipe_name: [*:0]const u8) !void {
    const stdin = std.Io.File.stdin().handle;
    const stdout = std.Io.File.stdout().handle;
    var context = HostContext{ .stdout = stdout };

    try writeNativeMessageLocked(&context, "{\"bridgeVersion\":\"" ++ version ++ "\"}");

    const pipe_thread = try std.Thread.spawn(.{}, runPipeServer, .{ allocator, &context, command_pipe_name });
    pipe_thread.detach();

    while (true) {
        const payload = readNativeMessage(allocator, stdin) catch |err| switch (err) {
            error.EndOfStream => return,
            else => return err,
        };
        defer allocator.free(payload);

        if (try routeReplyPipe(allocator, payload)) {
            continue;
        }

        const response = handleJsonMessage(allocator, payload) catch |err| blk: {
            break :blk try makeErrorResponse(allocator, null, @errorName(err));
        };
        defer allocator.free(response);

        try writeNativeMessageLocked(&context, response);
    }
}

fn sendBrowserRequest(allocator: std.mem.Allocator, method: []const u8, fields_json: []const u8, output_path: ?[]const u8) !void {
    const response = try requestBrowserWithRetry(allocator, method, fields_json);
    defer allocator.free(response);

    if (output_path) |path| {
        try saveScreenshotResponse(allocator, response, path);
    } else {
        try writeStdout(response);
        try writeStdout("\n");
    }
}

fn sendRequiredBrowserRequest(
    allocator: std.mem.Allocator,
    method: []const u8,
    fields_json: []const u8,
    attempts: u32,
) !void {
    var last_response: ?[]u8 = null;
    defer if (last_response) |response| allocator.free(response);

    var attempt: u32 = 0;
    while (attempt < attempts) : (attempt += 1) {
        const response = try requestBrowserWithRetry(allocator, method, fields_json);
        if (jsonResponseOk(allocator, response)) {
            try writeStdout(response);
            try writeStdout("\n");
            allocator.free(response);
            return;
        }
        if (last_response) |previous| allocator.free(previous);
        last_response = response;
        if (attempt + 1 < attempts) Sleep(250);
    }

    if (last_response) |response| {
        try writeStdout(response);
        try writeStdout("\n");
    }
    return error.RequiredBrowserRequestFailed;
}

fn sendLocalStatus(allocator: std.mem.Allocator) !void {
    var response = std.array_list.Managed(u8).init(allocator);
    defer response.deinit();

    try response.appendSlice("{\"ok\":true,\"transport\":\"local\",\"bridge\":\"");
    try response.appendSlice(version);
    try response.appendSlice("\",\"windowTarget\":");
    if (g_window_id) |wid| {
        try response.print("{d}", .{wid});
        try response.appendSlice(",\"pane\":\"targeted\"");
    } else {
        try response.appendSlice("null,\"pane\":\"unknown\"");
    }
    try response.appendSlice(",\"hint\":\"For remote multiprompt-browser, reconnect the SSH/tmux session before opening or rebinding the browser pane after a network drop.\"}\n");
    try writeStdout(response.items);
}

const KeyDescriptor = struct {
    label_buf: [24]u8 = undefined,
    label_len: usize = 0,
    key_buf: [24]u8 = undefined,
    key_len: usize = 0,
    code_buf: [24]u8 = undefined,
    code_len: usize = 0,
    text_buf: [8]u8 = undefined,
    text_len: usize = 0,
    unmodified_buf: [8]u8 = undefined,
    unmodified_len: usize = 0,
    key_code: u16 = 0,

    fn label(self: *const KeyDescriptor) []const u8 {
        return self.label_buf[0..self.label_len];
    }

    fn key(self: *const KeyDescriptor) []const u8 {
        return self.key_buf[0..self.key_len];
    }

    fn code(self: *const KeyDescriptor) []const u8 {
        return self.code_buf[0..self.code_len];
    }

    fn text(self: *const KeyDescriptor) []const u8 {
        return self.text_buf[0..self.text_len];
    }

    fn unmodifiedText(self: *const KeyDescriptor) []const u8 {
        return self.unmodified_buf[0..self.unmodified_len];
    }
};

const ParsedKeyCombo = struct {
    alt: bool = false,
    ctrl: bool = false,
    meta: bool = false,
    shift: bool = false,
    descriptor: KeyDescriptor,

    fn modifiers(self: *const ParsedKeyCombo) u8 {
        return (if (self.alt) @as(u8, 1) else 0) |
            (if (self.ctrl) @as(u8, 2) else 0) |
            (if (self.meta) @as(u8, 4) else 0) |
            (if (self.shift) @as(u8, 8) else 0);
    }

    fn hasShortcutModifier(self: *const ParsedKeyCombo) bool {
        return self.alt or self.ctrl or self.meta;
    }
};

fn sendKeyChord(allocator: std.mem.Allocator, combo: []const u8) !void {
    _ = try parseKeyCombo(combo);
    var fields = std.array_list.Managed(u8).init(allocator);
    defer fields.deinit();
    try fields.appendSlice("\"combo\":");
    try appendJsonString(&fields, combo);
    try sendBrowserRequest(allocator, "key", fields.items, null);
}

fn sendCdpKeyEvent(
    allocator: std.mem.Allocator,
    event_type: []const u8,
    parsed: *const ParsedKeyCombo,
    include_text: bool,
) ![]u8 {
    var fields = std.array_list.Managed(u8).init(allocator);
    defer fields.deinit();

    try fields.appendSlice("\"cdpMethod\":\"Input.dispatchKeyEvent\",\"params\":{\"type\":");
    try appendJsonString(&fields, event_type);
    try fields.appendSlice(",\"key\":");
    try appendJsonString(&fields, parsed.descriptor.key());
    try fields.appendSlice(",\"code\":");
    try appendJsonString(&fields, parsed.descriptor.code());
    try fields.print(",\"windowsVirtualKeyCode\":{},\"nativeVirtualKeyCode\":{},\"modifiers\":{}", .{
        parsed.descriptor.key_code,
        parsed.descriptor.key_code,
        parsed.modifiers(),
    });
    try fields.appendSlice(",\"autoRepeat\":false,\"isKeypad\":false");
    if (include_text) {
        const text = if (parsed.hasShortcutModifier()) "" else parsed.descriptor.text();
        const unmodified = if (parsed.hasShortcutModifier()) "" else parsed.descriptor.unmodifiedText();
        try fields.appendSlice(",\"text\":");
        try appendJsonString(&fields, text);
        try fields.appendSlice(",\"unmodifiedText\":");
        try appendJsonString(&fields, unmodified);
    }
    try fields.appendSlice("}");

    return requestBrowserWithRetry(allocator, "cdp", fields.items);
}

fn parseKeyCombo(combo: []const u8) !ParsedKeyCombo {
    const trimmed_combo = std.mem.trim(u8, combo, " \t\r\n");
    if (trimmed_combo.len == 0) return error.MissingKeyCombo;

    var parsed = ParsedKeyCombo{ .descriptor = undefined };
    var key_part: ?[]const u8 = null;

    var it = std.mem.splitScalar(u8, trimmed_combo, '+');
    while (it.next()) |raw_part| {
        const part = std.mem.trim(u8, raw_part, " \t\r\n");
        if (part.len == 0) continue;

        if (modifierMatches(part, "alt") or modifierMatches(part, "option")) {
            parsed.alt = true;
        } else if (modifierMatches(part, "ctrl") or modifierMatches(part, "control")) {
            parsed.ctrl = true;
        } else if (modifierMatches(part, "shift")) {
            parsed.shift = true;
        } else if (modifierMatches(part, "meta") or
            modifierMatches(part, "cmd") or
            modifierMatches(part, "command") or
            modifierMatches(part, "win") or
            modifierMatches(part, "windows") or
            modifierMatches(part, "super"))
        {
            parsed.meta = true;
        } else {
            if (key_part != null) return error.MultipleKeysInCombo;
            key_part = part;
        }
    }

    parsed.descriptor = try describeKey(key_part orelse return error.MissingKeyInCombo, parsed.shift);
    return parsed;
}

fn describeKey(raw_key: []const u8, shift: bool) !KeyDescriptor {
    const key = std.mem.trim(u8, raw_key, " \t\r\n");
    if (key.len == 0) return error.MissingKeyInCombo;

    if (keyNameMatches(key, "enter") or keyNameMatches(key, "return")) return makeNamedKey("Enter", "Enter", "Enter", 13, "", "");
    if (keyNameMatches(key, "esc") or keyNameMatches(key, "escape")) return makeNamedKey("Escape", "Escape", "Escape", 27, "", "");
    if (keyNameMatches(key, "tab")) return makeNamedKey("Tab", "Tab", "Tab", 9, "", "");
    if (keyNameMatches(key, "backspace")) return makeNamedKey("Backspace", "Backspace", "Backspace", 8, "", "");
    if (keyNameMatches(key, "delete") or keyNameMatches(key, "del")) return makeNamedKey("Delete", "Delete", "Delete", 46, "", "");
    if (keyNameMatches(key, "insert") or keyNameMatches(key, "ins")) return makeNamedKey("Insert", "Insert", "Insert", 45, "", "");
    if (keyNameMatches(key, "home")) return makeNamedKey("Home", "Home", "Home", 36, "", "");
    if (keyNameMatches(key, "end")) return makeNamedKey("End", "End", "End", 35, "", "");
    if (keyNameMatches(key, "pageup") or keyNameMatches(key, "pgup")) return makeNamedKey("PageUp", "PageUp", "PageUp", 33, "", "");
    if (keyNameMatches(key, "pagedown") or keyNameMatches(key, "pgdn")) return makeNamedKey("PageDown", "PageDown", "PageDown", 34, "", "");
    if (keyNameMatches(key, "space")) return makeNamedKey("Space", " ", "Space", 32, " ", " ");
    if (keyNameMatches(key, "arrowup") or keyNameMatches(key, "up")) return makeNamedKey("ArrowUp", "ArrowUp", "ArrowUp", 38, "", "");
    if (keyNameMatches(key, "arrowdown") or keyNameMatches(key, "down")) return makeNamedKey("ArrowDown", "ArrowDown", "ArrowDown", 40, "", "");
    if (keyNameMatches(key, "arrowleft") or keyNameMatches(key, "left")) return makeNamedKey("ArrowLeft", "ArrowLeft", "ArrowLeft", 37, "", "");
    if (keyNameMatches(key, "arrowright") or keyNameMatches(key, "right")) return makeNamedKey("ArrowRight", "ArrowRight", "ArrowRight", 39, "", "");

    if ((key.len == 2 or key.len == 3) and asciiLower(key[0]) == 'f') {
        const n = std.fmt.parseInt(u8, key[1..], 10) catch 0;
        if (n >= 1 and n <= 24) {
            var label_buf: [4]u8 = undefined;
            const label = try std.fmt.bufPrint(&label_buf, "F{}", .{n});
            return makeNamedKey(label, label, label, 111 + @as(u16, n), "", "");
        }
    }

    if (key.len == 1 and ((key[0] >= 'a' and key[0] <= 'z') or (key[0] >= 'A' and key[0] <= 'Z'))) {
        const upper = asciiUpper(key[0]);
        const event_key = if (shift) upper else asciiLower(upper);
        var code_buf: [8]u8 = undefined;
        const code = try std.fmt.bufPrint(&code_buf, "Key{c}", .{upper});
        const label_slice = (&[_]u8{upper})[0..];
        const event_slice = (&[_]u8{event_key})[0..];
        const unmodified_slice = (&[_]u8{asciiLower(upper)})[0..];
        return makeNamedKey(label_slice, event_slice, code, upper, event_slice, unmodified_slice);
    }

    if (key.len == 1 and key[0] >= '0' and key[0] <= '9') {
        var code_buf: [8]u8 = undefined;
        const code = try std.fmt.bufPrint(&code_buf, "Digit{c}", .{key[0]});
        return makeNamedKey(key[0..1], key[0..1], code, key[0], key[0..1], key[0..1]);
    }

    if (key.len == 1) {
        switch (key[0]) {
            '-' => return makeNamedKey("Minus", "-", "Minus", 189, "-", "-"),
            '=' => return makeNamedKey("Equal", "=", "Equal", 187, "=", "="),
            ',' => return makeNamedKey("Comma", ",", "Comma", 188, ",", ","),
            '.' => return makeNamedKey("Period", ".", "Period", 190, ".", "."),
            '/' => return makeNamedKey("Slash", "/", "Slash", 191, "/", "/"),
            '`' => return makeNamedKey("Backquote", "`", "Backquote", 192, "`", "`"),
            '[' => return makeNamedKey("BracketLeft", "[", "BracketLeft", 219, "[", "["),
            ']' => return makeNamedKey("BracketRight", "]", "BracketRight", 221, "]", "]"),
            '\\' => return makeNamedKey("Backslash", "\\", "Backslash", 220, "\\", "\\"),
            ';' => return makeNamedKey("Semicolon", ";", "Semicolon", 186, ";", ";"),
            '\'' => return makeNamedKey("Quote", "'", "Quote", 222, "'", "'"),
            else => {},
        }
    }

    return error.UnsupportedKeyCombo;
}

fn makeNamedKey(label: []const u8, key: []const u8, code: []const u8, key_code: u16, text: []const u8, unmodified: []const u8) !KeyDescriptor {
    var descriptor = KeyDescriptor{ .key_code = key_code };
    descriptor.label_len = try copyFixed(&descriptor.label_buf, label);
    descriptor.key_len = try copyFixed(&descriptor.key_buf, key);
    descriptor.code_len = try copyFixed(&descriptor.code_buf, code);
    descriptor.text_len = try copyFixed(&descriptor.text_buf, text);
    descriptor.unmodified_len = try copyFixed(&descriptor.unmodified_buf, unmodified);
    return descriptor;
}

fn copyFixed(buffer: []u8, value: []const u8) !usize {
    if (value.len > buffer.len) return error.FixedBufferTooSmall;
    @memcpy(buffer[0..value.len], value);
    return value.len;
}

fn appendNormalizedKeyCombo(list: *std.array_list.Managed(u8), parsed: *const ParsedKeyCombo) !void {
    var text = std.array_list.Managed(u8).init(std.heap.page_allocator);
    defer text.deinit();

    var first = true;
    if (parsed.alt) try appendComboPart(&text, &first, "Alt");
    if (parsed.ctrl) try appendComboPart(&text, &first, "Ctrl");
    if (parsed.meta) try appendComboPart(&text, &first, "Meta");
    if (parsed.shift) try appendComboPart(&text, &first, "Shift");
    try appendComboPart(&text, &first, parsed.descriptor.label());
    try appendJsonString(list, text.items);
}

fn appendComboPart(list: *std.array_list.Managed(u8), first: *bool, part: []const u8) !void {
    if (!first.*) try list.append('+');
    first.* = false;
    try list.appendSlice(part);
}

fn appendModifierName(list: *std.array_list.Managed(u8), first: *bool, name: []const u8) !void {
    if (!first.*) try list.append(',');
    first.* = false;
    try appendJsonString(list, name);
}

fn jsonResponseOk(allocator: std.mem.Allocator, response: []const u8) bool {
    const trimmed = std.mem.trim(u8, response, " \t\r\n");
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, trimmed, .{}) catch return false;
    defer parsed.deinit();
    if (parsed.value != .object) return false;
    return getBool(parsed.value.object.get("ok"));
}

fn modifierMatches(input: []const u8, compact: []const u8) bool {
    return keyNameMatches(input, compact);
}

fn keyNameMatches(input: []const u8, compact: []const u8) bool {
    var j: usize = 0;
    for (input) |c| {
        if (c == ' ' or c == '-' or c == '_') continue;
        if (j >= compact.len) return false;
        if (asciiLower(c) != compact[j]) return false;
        j += 1;
    }
    return j == compact.len;
}

fn asciiLower(c: u8) u8 {
    if (c >= 'A' and c <= 'Z') return c + 32;
    return c;
}

fn asciiUpper(c: u8) u8 {
    if (c >= 'a' and c <= 'z') return c - 32;
    return c;
}

fn requestBrowserWithRetry(allocator: std.mem.Allocator, method: []const u8, fields_json: []const u8) ![]u8 {
    var last_bad: ?[]u8 = null;
    defer if (last_bad) |bad| allocator.free(bad);
    var last_mismatch: ?[]u8 = null;
    defer if (last_mismatch) |reply| allocator.free(reply);

    var attempt: u32 = 0;
    while (attempt < browser_request_attempts) : (attempt += 1) {
        const raw_response = requestBrowser(allocator, method, fields_json) catch |err| {
            if (attempt + 1 < browser_request_attempts and isRetryableBrowserRequestError(err)) {
                Sleep(75 * (attempt + 1));
                continue;
            }

            var message_buf: [128]u8 = undefined;
            const message = std.fmt.bufPrint(
                &message_buf,
                "browser bridge request failed: {s}",
                .{@errorName(err)},
            ) catch "browser bridge request failed";
            return makeBridgeCliErrorResponse(allocator, method, message, null);
        };

        const response = blk: {
            const parsed = std.json.parseFromSlice(std.json.Value, allocator, raw_response, .{}) catch null;
            if (parsed) |reply| {
                defer reply.deinit();
                if (reply.value == .object and !std.mem.eql(u8, method, "extensionReload")) {
                    if (reply.value.object.get("extensionVersion")) |loaded| {
                        if (loaded == .string and !std.mem.eql(u8, loaded.string, version)) {
                            defer allocator.free(raw_response);
                            var message_buf: [384]u8 = undefined;
                            const message = std.fmt.bufPrint(
                                &message_buf,
                                "extension version {s} does not match bridge {s}: reload the extension in chrome://extensions; if it persists, install matching bridge/extension versions",
                                .{ loaded.string, version },
                            ) catch "extension/bridge version mismatch: reload the extension in chrome://extensions";
                            break :blk try makeBridgeCliErrorResponse(allocator, method, message, null);
                        }
                    }
                }
            }
            if (tabsReplyProblem(allocator, method, g_window_id, raw_response)) |message| {
                defer allocator.free(raw_response);
                break :blk try makeBridgeCliErrorResponse(allocator, method, message, null);
            }
            break :blk raw_response;
        };
        if (isJsonObjectResponse(allocator, response)) {
            if (replyIsInstanceMismatch(response) and attempt + 1 < browser_request_attempts) {
                if (last_mismatch) |previous| allocator.free(previous);
                last_mismatch = response;
                Sleep(75 * (attempt + 1));
                continue;
            }
            if (last_bad) |bad| {
                allocator.free(bad);
                last_bad = null;
            }
            return response;
        }

        if (last_bad) |bad| allocator.free(bad);
        last_bad = response;

        if (attempt + 1 < browser_request_attempts) {
            Sleep(75 * (attempt + 1));
        }
    }

    if (last_mismatch) |reply| {
        last_mismatch = null;
        return reply;
    }

    return makeBridgeCliErrorResponse(
        allocator,
        method,
        "browser bridge returned an empty or non-JSON reply after retries",
        last_bad,
    );
}

fn tabsReplyProblem(allocator: std.mem.Allocator, method: []const u8, window_id: ?i64, reply: []const u8) ?[]const u8 {
    if (!std.mem.eql(u8, method, "tabs") or window_id == null or window_id.? <= 0) return null;
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, reply, .{}) catch return null;
    defer parsed.deinit();
    if (parsed.value != .object) return null;
    const root = parsed.value.object;
    const ok = root.get("ok") orelse return null;
    if (ok != .bool or !ok.bool) return null;
    const result = root.get("result") orelse return null;
    if (result != .object) return null;
    const tabs = result.object.get("tabs") orelse return null;
    if (tabs != .array or tabs.array.items.len != 0) return null;
    const extension_version = root.get("extensionVersion");
    const loaded = if (extension_version != null and extension_version.? == .string)
        std.SemanticVersion.parse(extension_version.?.string) catch null
    else
        null;
    const required = std.SemanticVersion.parse(version) catch unreachable;
    if (loaded == null or loaded.?.order(required) == .lt) {
        return "extension outdated, reload it in chrome://extensions (empty session pane tab list; requires bridge/extension " ++ version ++ ")";
    }
    return "empty session pane tab list: bound browser window not found (no active tab); refusing to touch another window";
}

const instance_mismatch_markers = [_][]const u8{
    "empty session pane tab list",
    "not found (no active tab)",
    "No window with id",
    "no window with tab url matching",
    "unknown method:",
};

fn replyIsInstanceMismatch(reply: []const u8) bool {
    var parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, reply, .{}) catch return false;
    defer parsed.deinit();
    if (parsed.value != .object) return false;
    const ok = parsed.value.object.get("ok") orelse return false;
    if (ok != .bool or ok.bool) return false;
    const err = parsed.value.object.get("error") orelse return false;
    if (err != .string) return false;
    const message = err.string;
    for (instance_mismatch_markers) |marker| {
        if (std.mem.indexOf(u8, message, marker) != null) return true;
    }
    return false;
}

test "only instance-ownership errors are retried against the next pipe instance" {
    try std.testing.expect(replyIsInstanceMismatch(
        "{\"ok\":false,\"error\":\"multiprompt session browser window 1813394051 not found (no active tab); refusing to touch another window\"}",
    ));
    try std.testing.expect(replyIsInstanceMismatch("{\"ok\":false,\"error\":\"No window with id: 42.\"}"));
    try std.testing.expect(replyIsInstanceMismatch("{\"ok\":false,\"error\":\"no window with tab url matching: ZSPANE\"}"));
    try std.testing.expect(replyIsInstanceMismatch("{\"ok\":false,\"error\":\"unknown method: extensionReload\"}"));
    try std.testing.expect(!replyIsInstanceMismatch("{\"ok\":true,\"result\":{\"tabs\":[]}}"));
    try std.testing.expect(!replyIsInstanceMismatch("{\"ok\":false,\"error\":\"tab 9 does not belong to multiprompt browser window 1813394051\"}"));
    try std.testing.expect(replyIsInstanceMismatch("{ \"ok\" : false, \"error\" : \"No window with id: 42.\" }"));
    try std.testing.expect(!replyIsInstanceMismatch("{\"ok\":true,\"result\":{\"error\":\"No window with id: 42.\"}}"));
}

fn isRetryableBrowserRequestError(err: anyerror) bool {
    return switch (err) {
        error.ReadFailed, error.PipeUnavailable, error.PipeConnectFailed, error.EndOfStream => true,
        else => false,
    };
}

fn isJsonObjectResponse(allocator: std.mem.Allocator, response: []const u8) bool {
    const trimmed = std.mem.trim(u8, response, " \t\r\n");
    if (trimmed.len == 0 or trimmed[0] != '{') return false;

    var parsed = std.json.parseFromSlice(std.json.Value, allocator, trimmed, .{}) catch return false;
    defer parsed.deinit();
    return parsed.value == .object;
}

fn makeBridgeCliErrorResponse(
    allocator: std.mem.Allocator,
    method: []const u8,
    message: []const u8,
    sample: ?[]const u8,
) ![]u8 {
    var response = std.array_list.Managed(u8).init(allocator);
    errdefer response.deinit();

    try response.appendSlice("{\"ok\":false,\"method\":");
    try appendJsonString(&response, method);
    try response.appendSlice(",\"error\":");
    try appendJsonString(&response, message);
    try response.appendSlice(",\"attempts\":");
    try response.print("{}", .{browser_request_attempts});
    if (sample) |bad| {
        const trimmed = std.mem.trim(u8, bad, " \t\r\n");
        if (trimmed.len > 0) {
            try response.appendSlice(",\"lastReplyPrefix\":");
            try appendJsonString(&response, trimmed[0..@min(trimmed.len, 240)]);
        }
    }
    try response.append('}');
    return response.toOwnedSlice();
}

fn requestBrowser(allocator: std.mem.Allocator, method: []const u8, fields_json: []const u8) ![]u8 {
    const pid = GetCurrentProcessId();
    const tick = GetTickCount64();

    const id = try std.fmt.allocPrint(allocator, "cli-{d}-{d}", .{ pid, tick });
    defer allocator.free(id);

    const reply_pipe_text = try std.fmt.allocPrint(allocator, "\\\\.\\pipe\\zigshell-bridge-reply-{d}-{d}", .{ pid, tick });
    defer allocator.free(reply_pipe_text);
    const reply_pipe_name = try allocator.dupeZ(u8, reply_pipe_text);
    defer allocator.free(reply_pipe_name);

    const reply_pipe = CreateNamedPipeA(
        reply_pipe_name.ptr,
        PIPE_ACCESS_INBOUND,
        PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT,
        1,
        max_native_message,
        max_native_message,
        0,
        null,
    );
    if (reply_pipe == INVALID_HANDLE_VALUE) {
        return error.PipeUnavailable;
    }
    defer _ = CloseHandle(reply_pipe);

    var request = std.array_list.Managed(u8).init(allocator);
    defer request.deinit();

    try request.appendSlice("{\"id\":");
    try appendJsonString(&request, id);
    try request.appendSlice(",\"method\":");
    try appendJsonString(&request, method);
    try request.appendSlice(",\"replyPipe\":");
    try appendJsonString(&request, reply_pipe_text);
    if (g_window_id) |wid| {
        try request.print(",\"windowId\":{d}", .{wid});
    }
    if (fields_json.len > 0) {
        try request.append(',');
        try request.appendSlice(fields_json);
    }
    try request.append('}');

    const command_pipe = CreateFileA(
        isolated_pipe_name,
        GENERIC_WRITE,
        0,
        null,
        OPEN_EXISTING,
        0,
        null,
    );
    if (command_pipe == INVALID_HANDLE_VALUE) {
        return error.PipeUnavailable;
    }
    defer _ = CloseHandle(command_pipe);

    try writeAll(command_pipe, request.items);
    try waitForPipeClient(reply_pipe);

    return readPipeMessage(allocator, reply_pipe);
}

fn saveScreenshotResponse(allocator: std.mem.Allocator, response: []const u8, output_path: []const u8) !void {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, response, .{});
    defer parsed.deinit();

    if (parsed.value != .object) {
        return error.InvalidScreenshotResponse;
    }

    const root = parsed.value.object;
    if (!getBool(root.get("ok"))) {
        const message = getString(root.get("error")) orelse "";
        if (std.mem.indexOf(u8, message, "image readback failed") != null) {
            const cdp_response = try requestBrowserWithRetry(
                allocator,
                "cdp",
                "\"cdpMethod\":\"Page.captureScreenshot\",\"params\":{\"format\":\"png\",\"fromSurface\":true}",
            );
            defer allocator.free(cdp_response);
            return saveScreenshotResponse(allocator, cdp_response, output_path);
        } else {
            try writeStdout(response);
            try writeStdout("\n");
            return error.ScreenshotFailed;
        }
    }

    const result = root.get("result") orelse return error.InvalidScreenshotResponse;
    if (result != .object) {
        return error.InvalidScreenshotResponse;
    }

    const screenshot_base64 = try getScreenshotBase64(result.object);
    const png = try decodeBase64(allocator, screenshot_base64);
    defer allocator.free(png);

    try writeFileBytes(allocator, output_path, png);

    var out = std.array_list.Managed(u8).init(allocator);
    defer out.deinit();

    try out.appendSlice("{\"ok\":true,\"path\":");
    try appendJsonString(&out, output_path);
    try out.print(",\"bytes\":{}", .{png.len});

    if (getString(result.object.get("via"))) |via| {
        try out.appendSlice(",\"via\":");
        try appendJsonString(&out, via);
    } else if (getString(result.object.get("data"))) |_| {
        try out.appendSlice(",\"via\":\"Page.captureScreenshot\"");
    }

    try out.appendSlice("}\n");
    try writeStdout(out.items);
}

fn getScreenshotBase64(result: std.json.ObjectMap) ![]const u8 {
    if (getString(result.get("dataUrl"))) |data_url| {
        const prefix = "data:image/png;base64,";
        if (!std.mem.startsWith(u8, data_url, prefix)) {
            return error.InvalidScreenshotResponse;
        }
        return data_url[prefix.len..];
    }

    if (getString(result.get("data"))) |data| {
        return data;
    }

    return error.InvalidScreenshotResponse;
}

fn writeFileBytes(allocator: std.mem.Allocator, path: []const u8, bytes: []const u8) !void {
    const path_z = try allocator.dupeZ(u8, path);
    defer allocator.free(path_z);

    const file = CreateFileA(
        path_z.ptr,
        GENERIC_WRITE,
        0,
        null,
        CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL,
        null,
    );
    if (file == INVALID_HANDLE_VALUE) {
        return error.CreateFileFailed;
    }
    defer _ = CloseHandle(file);

    try writeAll(file, bytes);
}

fn decodeBase64(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    const output = try allocator.alloc(u8, (encoded.len / 4) * 3 + 3);
    errdefer allocator.free(output);

    var out_len: usize = 0;
    var quad: [4]u32 = undefined;
    var quad_len: usize = 0;
    var saw_padding = false;

    for (encoded) |c| {
        if (c == '\r' or c == '\n' or c == '\t' or c == ' ') {
            continue;
        }

        const value: u32 = if (c == '=') blk: {
            saw_padding = true;
            break :blk 64;
        } else blk: {
            if (saw_padding) return error.InvalidBase64;
            break :blk decodeBase64Char(c) orelse return error.InvalidBase64;
        };

        quad[quad_len] = value;
        quad_len += 1;

        if (quad_len == 4) {
            if (quad[0] == 64 or quad[1] == 64) return error.InvalidBase64;
            output[out_len] = @intCast((quad[0] << 2) | (quad[1] >> 4));
            out_len += 1;

            if (quad[2] != 64) {
                output[out_len] = @intCast(((quad[1] & 0x0f) << 4) | (quad[2] >> 2));
                out_len += 1;

                if (quad[3] != 64) {
                    output[out_len] = @intCast(((quad[2] & 0x03) << 6) | quad[3]);
                    out_len += 1;
                }
            } else if (quad[3] != 64) {
                return error.InvalidBase64;
            }

            quad_len = 0;
        }
    }

    if (quad_len != 0) {
        return error.InvalidBase64;
    }

    return allocator.realloc(output, out_len);
}

fn decodeBase64Char(c: u8) ?u32 {
    if (c >= 'A' and c <= 'Z') return c - 'A';
    if (c >= 'a' and c <= 'z') return 26 + c - 'a';
    if (c >= '0' and c <= '9') return 52 + c - '0';
    if (c == '+') return 62;
    if (c == '/') return 63;
    return null;
}

fn runPipeServer(allocator: std.mem.Allocator, context: *HostContext, command_pipe_name: [*:0]const u8) void {
    while (true) {
        const pipe = CreateNamedPipeA(
            command_pipe_name,
            PIPE_ACCESS_INBOUND,
            PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT,
            PIPE_UNLIMITED_INSTANCES,
            max_native_message,
            max_native_message,
            0,
            null,
        );
        if (pipe == INVALID_HANDLE_VALUE) {
            Sleep(500);
            continue;
        }

        waitForPipeClient(pipe) catch {
            _ = CloseHandle(pipe);
            continue;
        };

        const payload = readPipeMessage(allocator, pipe) catch {
            _ = DisconnectNamedPipe(pipe);
            _ = CloseHandle(pipe);
            continue;
        };
        defer allocator.free(payload);

        writeNativeMessageLocked(context, payload) catch {};
        _ = DisconnectNamedPipe(pipe);
        _ = CloseHandle(pipe);
    }
}

fn waitForPipeClient(pipe: windows.HANDLE) !void {
    if (ConnectNamedPipe(pipe, null) == 0) {
        switch (GetLastError()) {
            ERROR_PIPE_CONNECTED => return,
            else => return error.PipeConnectFailed,
        }
    }
}

fn routeReplyPipe(allocator: std.mem.Allocator, payload: []const u8) !bool {
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, payload, .{}) catch return false;
    defer parsed.deinit();

    if (parsed.value != .object) return false;
    const reply_pipe = getString(parsed.value.object.get("replyPipe")) orelse return false;

    const pipe_path = try allocator.dupeZ(u8, reply_pipe);
    defer allocator.free(pipe_path);

    const pipe = CreateFileA(
        pipe_path.ptr,
        GENERIC_WRITE,
        0,
        null,
        OPEN_EXISTING,
        0,
        null,
    );
    if (pipe == INVALID_HANDLE_VALUE) {
        return true;
    }
    defer _ = CloseHandle(pipe);

    try writeAll(pipe, payload);
    return true;
}

fn readPipeMessage(allocator: std.mem.Allocator, handle: windows.HANDLE) ![]u8 {
    const payload = try allocator.alloc(u8, max_native_message);
    errdefer allocator.free(payload);

    var read: windows.DWORD = 0;
    if (ReadFile(handle, payload.ptr, @intCast(payload.len), &read, null) == 0) {
        return error.ReadFailed;
    }

    return allocator.realloc(payload, read);
}

fn readNativeMessage(allocator: std.mem.Allocator, handle: windows.HANDLE) ![]u8 {
    var len_buf: [4]u8 = undefined;
    readExact(handle, &len_buf) catch |err| switch (err) {
        error.EndOfStream => return error.EndOfStream,
        else => return err,
    };

    const len = std.mem.readInt(u32, &len_buf, .little);
    if (len > max_native_message) {
        return error.MessageTooLarge;
    }

    const payload = try allocator.alloc(u8, len);
    errdefer allocator.free(payload);
    try readExact(handle, payload);
    return payload;
}

fn writeNativeMessage(handle: windows.HANDLE, payload: []const u8) !void {
    if (payload.len > std.math.maxInt(u32)) {
        return error.MessageTooLarge;
    }

    var len_buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &len_buf, @intCast(payload.len), .little);
    try writeAll(handle, &len_buf);
    try writeAll(handle, payload);
}

fn writeNativeMessageLocked(context: *HostContext, payload: []const u8) !void {
    lockMutex(&context.write_mutex);
    defer context.write_mutex.unlock();
    try writeNativeMessage(context.stdout, payload);
}

fn lockMutex(mutex: *SpinMutex) void {
    while (!mutex.tryLock()) {
        Sleep(1);
    }
}

fn handleJsonMessage(allocator: std.mem.Allocator, payload: []const u8) ![]u8 {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, payload, .{});
    defer parsed.deinit();

    if (parsed.value != .object) {
        return makeErrorResponse(allocator, null, "expected JSON object");
    }

    const object = parsed.value.object;
    const id = object.get("id");
    const method = getString(object.get("method")) orelse getString(object.get("type")) orelse "";

    if (std.mem.eql(u8, method, "ping")) {
        return makeResultResponse(allocator, id, "{\"pong\":true,\"bridgeVersion\":\"" ++ version ++ "\"}");
    }

    if (std.mem.eql(u8, method, "version")) {
        var result = std.array_list.Managed(u8).init(allocator);
        defer result.deinit();
        try result.print("{{\"name\":\"{s}\",\"version\":\"{s}\"}}", .{ app_name, version });
        return makeResultResponse(allocator, id, result.items);
    }

    if (std.mem.eql(u8, method, "capabilities")) {
        return makeResultResponse(
            allocator,
            id,
            "{\"transport\":\"chrome-native-messaging\",\"commands\":[\"ping\",\"version\",\"capabilities\",\"navigate\",\"createPaneWindow\",\"back\",\"forward\",\"reload\",\"extensionReload\",\"setTheme\",\"protectWindow\",\"browserDropGesture\",\"routingAudit\",\"sidebar\",\"tabs\",\"activeTab\",\"url\",\"activate\",\"closeTab\",\"text\",\"links\",\"snapshot\",\"find\",\"click\",\"type\",\"insert\",\"cursor\",\"eval\",\"key\",\"screenshot\",\"console\",\"shoturl\",\"cdp\",\"fgUnlock\",\"shutdown\"]}",
        );
    }

    if (std.mem.eql(u8, method, "shutdown")) {
        return makeResultResponse(allocator, id, "{\"shutdown\":true}");
    }

    if (std.mem.eql(u8, method, "fgUnlock")) {
        return makeResultResponse(allocator, id, "{\"unlocked\":false}");
    }

    if (std.mem.eql(u8, method, "getUploadConfig")) {
        return makeUploadConfigResponse(allocator, id);
    }

    if (std.mem.eql(u8, method, "pasteUrl")) {
        return handlePasteUrl(allocator, id, object);
    }

    return makeErrorResponse(allocator, id, "unknown method");
}

fn usageExit(code: u8) noreturn {
    usage() catch {};
    std.process.exit(code);
}

fn limitUsageExit(command: []const u8, default_limit: usize) noreturn {
    var buf: [160]u8 = undefined;
    const line = std.fmt.bufPrint(
        &buf,
        "usage: {s} [--limit N | --full]  (default: {}; --full = no practical cap)\n",
        .{ command, default_limit },
    ) catch "usage: <cmd> [--limit N | --full]  (default varies; --full = no practical cap)\n";
    writeStdout(line) catch {};
    std.process.exit(0);
}

fn buildNavigateFields(allocator: std.mem.Allocator, url: []const u8, args: anytype) ![]u8 {
    var new_tab = false;
    var activate = false;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--new-tab")) {
            new_tab = true;
        } else if (std.mem.eql(u8, arg, "--activate")) {
            activate = true;
        } else {
            return error.InvalidArguments;
        }
    }
    var fields = std.array_list.Managed(u8).init(allocator);
    errdefer fields.deinit();
    try fields.appendSlice("\"url\":");
    try appendJsonString(&fields, url);
    try fields.appendSlice(",\"newTab\":");
    try fields.appendSlice(if (new_tab) "true" else "false");
    try fields.appendSlice(",\"activate\":");
    try fields.appendSlice(if (activate) "true" else "false");
    return fields.toOwnedSlice();
}

test "issue: navigate creates a tab only with --new-tab" {
    const cases = .{
        .{ "", false, false },
        .{ "--new-tab", true, false },
        .{ "--activate", false, true },
        .{ "--activate --new-tab", true, true },
    };
    inline for (cases) |case| {
        var args = try std.process.Args.IteratorGeneral(.{}).init(std.testing.allocator, case[0]);
        defer args.deinit();
        const fields = try buildNavigateFields(std.testing.allocator, "https://example.test/\"quoted", &args);
        defer std.testing.allocator.free(fields);
        const expected = "\"url\":\"https://example.test/\\\"quoted\",\"newTab\":" ++
            (if (case[1]) "true" else "false") ++ ",\"activate\":" ++ (if (case[2]) "true" else "false");
        try std.testing.expectEqualStrings(expected, fields);
    }
    var invalid = try std.process.Args.IteratorGeneral(.{}).init(std.testing.allocator, "--unknown");
    defer invalid.deinit();
    try std.testing.expectError(error.InvalidArguments, buildNavigateFields(std.testing.allocator, "https://example.test/", &invalid));
}

fn parseLimitArgs(args: anytype, command: []const u8, default_limit: usize) !usize {
    var limit = default_limit;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--limit")) {
            const value = args.next() orelse usageExit(2);
            limit = std.fmt.parseInt(usize, value, 10) catch usageExit(2);
        } else if (std.mem.eql(u8, arg, "--full")) {
            limit = 10_000_000;
        } else if (std.mem.eql(u8, arg, "--help")) {
            limitUsageExit(command, default_limit);
        } else {
            usageExit(2);
        }
    }
    return limit;
}

const LimitTabArgs = struct {
    limit: usize,
    tab: ?[]const u8 = null,
};

fn parseLimitTabArgs(args: anytype, command: []const u8, default_limit: usize) !LimitTabArgs {
    var parsed = LimitTabArgs{ .limit = default_limit };
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--limit")) {
            const value = args.next() orelse usageExit(2);
            parsed.limit = std.fmt.parseInt(usize, value, 10) catch usageExit(2);
        } else if (std.mem.eql(u8, arg, "--full")) {
            parsed.limit = 10_000_000;
        } else if (std.mem.eql(u8, arg, "--tab")) {
            parsed.tab = args.next() orelse usageExit(2);
        } else if (std.mem.eql(u8, arg, "--help")) {
            limitUsageExit(command, default_limit);
        } else {
            usageExit(2);
        }
    }
    return parsed;
}

fn parseOnlyTabArg(args: anytype) !?[]const u8 {
    var tab: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (!std.mem.eql(u8, arg, "--tab") or tab != null) return error.InvalidArguments;
        tab = args.next() orelse return error.InvalidArguments;
    }
    return tab;
}

const TextTabArgs = struct {
    text: []u8,
    tab: ?[]const u8 = null,
};

fn collectTextAndTabArgs(allocator: std.mem.Allocator, args: anytype, first: []const u8) !TextTabArgs {
    var text = std.array_list.Managed(u8).init(allocator);
    errdefer text.deinit();
    var tab: ?[]const u8 = null;
    var current: ?[]const u8 = first;
    while (current) |arg| : (current = args.next()) {
        if (std.mem.eql(u8, arg, "--tab")) {
            if (tab != null) return error.InvalidArguments;
            tab = args.next() orelse return error.InvalidArguments;
        } else {
            if (text.items.len > 0) try text.append(' ');
            try text.appendSlice(arg);
        }
    }
    if (text.items.len == 0) return error.InvalidArguments;
    return .{ .text = try text.toOwnedSlice(), .tab = tab };
}

fn appendTabTargetField(fields: *std.array_list.Managed(u8), target: []const u8) !void {
    if (fields.items.len > 0) try fields.append(',');
    try fields.appendSlice("\"tab\":");
    try appendJsonString(fields, target);
}

fn joinRemainingArgs(allocator: std.mem.Allocator, args: anytype, first: []const u8) ![]u8 {
    var result = std.array_list.Managed(u8).init(allocator);
    errdefer result.deinit();

    try result.appendSlice(first);
    while (args.next()) |arg| {
        try result.append(' ');
        try result.appendSlice(arg);
    }

    return result.toOwnedSlice();
}

fn getString(value: ?std.json.Value) ?[]const u8 {
    const actual = value orelse return null;
    return switch (actual) {
        .string => |text| text,
        else => null,
    };
}

fn getBool(value: ?std.json.Value) bool {
    const actual = value orelse return false;
    return switch (actual) {
        .bool => |b| b,
        else => false,
    };
}

fn getI64(value: ?std.json.Value) ?i64 {
    const actual = value orelse return null;
    return switch (actual) {
        .integer => |n| @intCast(n),
        .number_string => |s| std.fmt.parseInt(i64, s, 10) catch null,
        else => null,
    };
}

fn makeResultResponse(
    allocator: std.mem.Allocator,
    id: ?std.json.Value,
    result_json: []const u8,
) ![]u8 {
    var response = std.array_list.Managed(u8).init(allocator);
    errdefer response.deinit();

    try response.appendSlice("{\"id\":");
    try appendJsonId(&response, id);
    try response.appendSlice(",\"ok\":true,\"result\":");
    try response.appendSlice(result_json);
    try response.append('}');

    return response.toOwnedSlice();
}

fn makeErrorResponse(
    allocator: std.mem.Allocator,
    id: ?std.json.Value,
    message: []const u8,
) ![]u8 {
    var response = std.array_list.Managed(u8).init(allocator);
    errdefer response.deinit();

    try response.appendSlice("{\"id\":");
    try appendJsonId(&response, id);
    try response.appendSlice(",\"ok\":false,\"error\":");
    try appendJsonString(&response, message);
    try response.append('}');

    return response.toOwnedSlice();
}

fn appendJsonId(list: *std.array_list.Managed(u8), id: ?std.json.Value) !void {
    const value = id orelse return list.appendSlice("null");
    switch (value) {
        .null => try list.appendSlice("null"),
        .bool => |b| try list.appendSlice(if (b) "true" else "false"),
        .integer => |n| try list.print("{}", .{n}),
        .float => |n| try list.print("{d}", .{n}),
        .number_string => |s| try list.appendSlice(s),
        .string => |s| try appendJsonString(list, s),
        else => try list.appendSlice("null"),
    }
}

fn appendJsonString(list: *std.array_list.Managed(u8), text: []const u8) !void {
    try list.append('"');
    for (text) |c| {
        switch (c) {
            '"' => try list.appendSlice("\\\""),
            '\\' => try list.appendSlice("\\\\"),
            '\n' => try list.appendSlice("\\n"),
            '\r' => try list.appendSlice("\\r"),
            '\t' => try list.appendSlice("\\t"),
            else => {
                if (c < 0x20) {
                    try list.print("\\u00{x:0>2}", .{c});
                } else {
                    try list.append(c);
                }
            },
        }
    }
    try list.append('"');
}

fn readExact(handle: windows.HANDLE, buffer: []u8) !void {
    var offset: usize = 0;
    while (offset < buffer.len) {
        var read: windows.DWORD = 0;
        const chunk_len: windows.DWORD = @intCast(@min(buffer.len - offset, std.math.maxInt(windows.DWORD)));
        if (ReadFile(handle, buffer[offset..].ptr, chunk_len, &read, null) == 0) {
            switch (GetLastError()) {
                38, 109 => return error.EndOfStream,
                else => {},
            }
            return error.ReadFailed;
        }
        if (read == 0) {
            return error.EndOfStream;
        }
        offset += read;
    }
}

fn writeAll(handle: windows.HANDLE, bytes: []const u8) !void {
    var offset: usize = 0;
    while (offset < bytes.len) {
        var written: windows.DWORD = 0;
        const chunk_len: windows.DWORD = @intCast(@min(bytes.len - offset, std.math.maxInt(windows.DWORD)));
        if (WriteFile(handle, bytes[offset..].ptr, chunk_len, &written, null) == 0) {
            return error.WriteFailed;
        }
        if (written == 0) {
            return error.WriteFailed;
        }
        offset += written;
    }
}

fn writeStdout(bytes: []const u8) !void {
    try writeAll(std.Io.File.stdout().handle, bytes);
}

fn writeStderr(bytes: []const u8) !void {
    try writeAll(std.Io.File.stderr().handle, bytes);
}
