const std = @import("std");

pub const SIGNIN_URL = "https://accounts.google.com";
pub const SIGNIN_HOST = "accounts.google.com";
pub const REJECTED_MARKER = "signin/rejected";

pub const CONTROL_FLAGS = [_][]const u8{
    "--remote-debugging-pipe",
    "--enable-unsafe-extension-debugging",
    "--disable-sync",
    "--load-extension",
};

pub fn rejectedSigninUrl(url: []const u8) bool {
    if (url.len < 24 or url.len > 2048) return false;
    const https = "https://";
    const http = "http://";
    const scheme_len = if (std.ascii.startsWithIgnoreCase(url, https)) https.len else if (std.ascii.startsWithIgnoreCase(url, http)) http.len else return false;
    const rest = url[scheme_len..];
    const path_start = std.mem.indexOfScalar(u8, rest, '/') orelse return false;
    if (!std.ascii.eqlIgnoreCase(rest[0..path_start], SIGNIN_HOST)) return false;
    return std.ascii.indexOfIgnoreCase(rest[path_start..], REJECTED_MARKER) != null;
}

pub fn controlFlagIn(command: []const u8) ?[]const u8 {
    for (CONTROL_FLAGS) |flag| {
        if (std.ascii.indexOfIgnoreCase(command, flag) != null) return flag;
    }
    return null;
}

pub fn profileDirectorySafe(name: []const u8) bool {
    if (name.len == 0 or name.len > 64) return false;
    for (name) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '-' and c != '_' and c != '.') return false;
    }
    return true;
}

pub fn plainProfileLaunch(out: []u8, exe: []const u8, user_data_dir: []const u8, profile_directory: []const u8) ?[]const u8 {
    if (exe.len == 0 or user_data_dir.len == 0) return null;
    if (!profileDirectorySafe(profile_directory)) return null;
    if (std.mem.indexOfScalar(u8, exe, '"') != null or std.mem.indexOfScalar(u8, user_data_dir, '"') != null) return null;
    return std.fmt.bufPrint(out, "\"{s}\" --user-data-dir=\"{s}\" --profile-directory={s} --new-window {s}", .{
        exe,
        user_data_dir,
        profile_directory,
        SIGNIN_URL,
    }) catch null;
}

test "IGSH-1507 the Google rejected page is recognised and ordinary pages are not" {
    try std.testing.expect(rejectedSigninUrl("https://accounts.google.com/signin/rejected?approval_state=abc"));
    try std.testing.expect(rejectedSigninUrl("https://accounts.google.com/v3/signin/rejected"));
    try std.testing.expect(rejectedSigninUrl("HTTPS://ACCOUNTS.GOOGLE.COM/signin/rejected"));
    try std.testing.expect(!rejectedSigninUrl("https://accounts.google.com/signin/v2/identifier?service=mail"));
    try std.testing.expect(!rejectedSigninUrl("https://accounts.google.com/"));
    try std.testing.expect(!rejectedSigninUrl("https://accounts.google.com.evil.test/signin/rejected"));
    try std.testing.expect(!rejectedSigninUrl("https://evil.test/accounts.google.com/signin/rejected"));
    try std.testing.expect(!rejectedSigninUrl("https://www.google.com/signin/rejected"));
    try std.testing.expect(!rejectedSigninUrl("about:blank"));
    try std.testing.expect(!rejectedSigninUrl(""));
}

test "IGSH-1507 the plain sign-in window keeps the profile and carries no control channel" {
    var out: [900]u8 = undefined;
    const exe = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";
    const dir = "C:\\Users\\user\\AppData\\Local\\ZigShell\\BrowserWorkspaces\\chrome\\abc123";
    const command = plainProfileLaunch(&out, exe, dir, "Default") orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, command, "--user-data-dir=\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, command, dir) != null);
    try std.testing.expect(std.mem.indexOf(u8, command, "--profile-directory=Default") != null);
    try std.testing.expect(std.mem.indexOf(u8, command, SIGNIN_URL) != null);
    try std.testing.expect(controlFlagIn(command) == null);
    try std.testing.expect(plainProfileLaunch(&out, exe, dir, "De fault") == null);
    try std.testing.expect(plainProfileLaunch(&out, exe, dir, "") == null);
    try std.testing.expect(plainProfileLaunch(&out, "", dir, "Default") == null);
    try std.testing.expect(controlFlagIn("\"chrome.exe\" --remote-debugging-pipe --disable-sync") != null);
}
