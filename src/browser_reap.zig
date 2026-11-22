const std = @import("std");
const win = @import("win32.zig");
const browser_own_profile = @import("browser_own_profile.zig");

const DWORD = win.DWORD;
const HANDLE = win.HANDLE;

pub const GRACE_MS: u32 = 2500;
pub const MAX_REAP_PIDS: usize = 64;
const OPEN_TIMEOUT_MS: DWORD = 2000;
const WAIT_TIMEOUT: DWORD = 258;

fn isBrowserImageName(name: []const u8) bool {
    return std.ascii.eqlIgnoreCase(name, "chrome.exe") or std.ascii.eqlIgnoreCase(name, "msedge.exe");
}

fn profileIsMultiprompt(profile: []const u8, local_appdata: []const u8) bool {
    if (profile.len == 0 or local_appdata.len == 0) return false;
    var root_buf: [1024]u8 = undefined;
    for ([_][]const u8{ "ChromeUserData", "EdgeUserData" }) |leaf| {
        const root = std.fmt.bufPrint(&root_buf, "{s}\\ZigShell\\{s}", .{ local_appdata, leaf }) catch return false;
        const trimmed = if (profile.len > root.len and profile[profile.len - 1] == '\\') profile[0 .. profile.len - 1] else profile;
        if (std.ascii.eqlIgnoreCase(trimmed, root)) return true;
    }
    var workspaces_buf: [1024]u8 = undefined;
    const workspaces = std.fmt.bufPrint(&workspaces_buf, "{s}\\ZigShell\\BrowserWorkspaces\\", .{local_appdata}) catch return false;
    return profile.len > workspaces.len and std.ascii.eqlIgnoreCase(profile[0..workspaces.len], workspaces);
}

fn localAppData(buf: []u8) []const u8 {
    const len = win.GetEnvironmentVariableA("LOCALAPPDATA", buf.ptr, @intCast(buf.len));
    if (len == 0 or len >= buf.len) return "";
    return buf[0..len];
}

fn imageBaseName(image: []const u8) []const u8 {
    const at = std.mem.lastIndexOfScalar(u8, image, '\\') orelse return image;
    return image[at + 1 ..];
}

fn processImageName(allocator: std.mem.Allocator, process: HANDLE) ?[]u8 {
    var wide: [32768]u16 = undefined;
    var len: DWORD = wide.len;
    if (win.QueryFullProcessImageNameW(process, 0, &wide, &len) == 0) return null;
    return std.unicode.utf16LeToUtf8Alloc(allocator, wide[0..len]) catch null;
}

fn processProfile(allocator: std.mem.Allocator, process: HANDLE) ?[]u8 {
    const handle = process orelse return null;
    const line = browser_own_profile.processCommandLine(allocator, handle) catch return null;
    defer allocator.free(line);
    return browser_own_profile.userDataArgument(allocator, line) catch null;
}

pub fn processIsMultipromptBrowser(allocator: std.mem.Allocator, process: HANDLE, local_appdata: []const u8) bool {
    const image = processImageName(allocator, process) orelse return false;
    defer allocator.free(image);
    if (!isBrowserImageName(imageBaseName(image))) return false;
    const profile = processProfile(allocator, process) orelse return false;
    defer allocator.free(profile);
    return profileIsMultiprompt(profile, local_appdata);
}

fn wideImageNameIsBrowser(wide: *const [260]u16) bool {
    const names = [_][]const u8{ "chrome.exe", "msedge.exe" };
    for (names) |name| {
        var matches = true;
        for (name, 0..) |c, i| {
            const wc = wide[i];
            const lower: u16 = if (wc >= 'A' and wc <= 'Z') wc + 32 else wc;
            if (wc == 0 or lower != @as(u16, c)) {
                matches = false;
                break;
            }
        }
        if (matches and wide[name.len] == 0) return true;
    }
    return false;
}

fn collectMultipromptBrowserPids(out: []u32) usize {
    var local_buf: [512]u8 = undefined;
    const local = localAppData(&local_buf);
    if (local.len == 0) return 0;

    const snap = win.CreateToolhelp32Snapshot(win.TH32CS_SNAPPROCESS, 0);
    if (snap == null or snap == win.INVALID_HANDLE_VALUE_PTR) return 0;
    defer _ = win.CloseHandle(snap);

    const allocator = std.heap.page_allocator;
    const own_pid = win.GetCurrentProcessId();
    var count: usize = 0;
    var entry: win.PROCESSENTRY32W = undefined;
    entry.dwSize = @sizeOf(win.PROCESSENTRY32W);
    if (win.Process32FirstW(snap, &entry) == 0) return 0;
    while (count < out.len) {
        const pid = entry.th32ProcessID;
        candidate: {
            if (pid == 0 or pid == own_pid) break :candidate;
            if (!wideImageNameIsBrowser(&entry.szExeFile)) break :candidate;
            const process = win.OpenProcess(win.PROCESS_QUERY_LIMITED_INFORMATION, 0, pid) orelse break :candidate;
            defer _ = win.CloseHandle(process);
            if (!processIsMultipromptBrowser(allocator, process, local)) break :candidate;
            out[count] = pid;
            count += 1;
        }
        if (win.Process32NextW(snap, &entry) == 0) break;
    }
    return count;
}

fn terminateMultipromptBrowser(pid: u32) bool {
    if (pid == 0 or pid == win.GetCurrentProcessId()) return false;
    const process = win.OpenProcess(win.PROCESS_QUERY_LIMITED_INFORMATION | win.PROCESS_TERMINATE | win.PROCESS_SYNCHRONIZE, 0, pid) orelse return false;
    defer _ = win.CloseHandle(process);
    if (win.WaitForSingleObject(process, 0) != WAIT_TIMEOUT) return false;
    var local_buf: [512]u8 = undefined;
    const local = localAppData(&local_buf);
    if (!processIsMultipromptBrowser(std.heap.page_allocator, process, local)) return false;
    _ = win.TerminateProcess(process, 1);
    return win.WaitForSingleObject(process, OPEN_TIMEOUT_MS) != WAIT_TIMEOUT;
}

const ReapJob = struct {
    pids: [MAX_REAP_PIDS]u32 = @splat(0),
    count: usize = 0,
};

fn reapWorker(job: *ReapJob) void {
    defer std.heap.page_allocator.destroy(job);
    win.Sleep(GRACE_MS);
    for (job.pids[0..job.count]) |pid| _ = terminateMultipromptBrowser(pid);
}

fn startReapThread(job: *ReapJob) void {
    const thread = std.Thread.spawn(.{}, reapWorker, .{job}) catch {
        std.heap.page_allocator.destroy(job);
        return;
    };
    thread.detach();
}

pub fn closeAllAfterGrace() usize {
    var pids: [MAX_REAP_PIDS]u32 = @splat(0);
    const count = collectMultipromptBrowserPids(pids[0..]);
    if (count == 0) return 0;
    const job = std.heap.page_allocator.create(ReapJob) catch return 0;
    job.* = .{};
    @memcpy(job.pids[0..count], pids[0..count]);
    job.count = count;
    startReapThread(job);
    return count;
}

test "only our own browser profiles are reaped" {
    const local = "C:\\Users\\val\\AppData\\Local";
    try std.testing.expect(profileIsMultiprompt("C:\\Users\\val\\AppData\\Local\\ZigShell\\ChromeUserData", local));
    try std.testing.expect(profileIsMultiprompt("c:\\users\\VAL\\appdata\\local\\zigshell\\edgeuserdata", local));
    try std.testing.expect(profileIsMultiprompt("C:\\Users\\val\\AppData\\Local\\ZigShell\\BrowserWorkspaces\\chrome\\abc123", local));
    try std.testing.expect(!profileIsMultiprompt("C:\\Users\\val\\AppData\\Local\\Google\\Chrome\\User Data", local));
    try std.testing.expect(!profileIsMultiprompt("C:\\Users\\val\\AppData\\Local\\ZigShell\\ChromeUserData-old", local));
    try std.testing.expect(!profileIsMultiprompt("", local));
    try std.testing.expect(!profileIsMultiprompt("C:\\Users\\val\\AppData\\Local\\ZigShell\\ChromeUserData", ""));
    try std.testing.expect(!profileIsMultiprompt("D:\\Users\\val\\AppData\\Local\\ZigShell\\BrowserWorkspaces\\chrome\\abc123", local));
}

test "wide image names match Chrome and Edge only" {
    var chrome: [260]u16 = @splat(0);
    for ("chrome.exe", 0..) |c, i| chrome[i] = c;
    var edge: [260]u16 = @splat(0);
    for ("MSEDGE.EXE", 0..) |c, i| edge[i] = c;
    var other: [260]u16 = @splat(0);
    for ("multiprompt.exe", 0..) |c, i| other[i] = c;
    try std.testing.expect(wideImageNameIsBrowser(&chrome));
    try std.testing.expect(wideImageNameIsBrowser(&edge));
    try std.testing.expect(!wideImageNameIsBrowser(&other));
}

test "browser image names match Chrome and Edge only" {
    try std.testing.expect(isBrowserImageName("chrome.exe"));
    try std.testing.expect(isBrowserImageName("MSEDGE.EXE"));
    try std.testing.expect(!isBrowserImageName("multiprompt.exe"));
    try std.testing.expect(!isBrowserImageName("chrome.exe.bak"));
}
