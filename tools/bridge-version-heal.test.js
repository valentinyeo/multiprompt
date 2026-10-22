const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');

const bridge = fs.readFileSync(process.env.HEAL_BRIDGE_SOURCE || path.join(__dirname, '../src/bridge.zig'), 'utf8');
const version = JSON.parse(fs.readFileSync(path.join(__dirname, '../extension/manifest.json'), 'utf8')).version;
function section(start, end) {
  const a = bridge.indexOf(start), b = bridge.indexOf(end, a + start.length);
  assert(a >= 0 && b > a, `missing ${start}`);
  return bridge.slice(a, b);
}

test('real bridge request builder and retry path heal without replaying successful commands', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'bridge-version-heal-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const source = `const std = @import("std");
const version = "${version}";
const browser_request_attempts = 4;
var g_window_id: ?i64 = null;
const g_profile_token = "";
var clock: u64 = 0;
var calls: usize = 0;
var probes: usize = 0;
var mode: enum { success, failed, stuck, transient, instance, tabs, tabs_old, transport } = .success;
fn Sleep(ms: u32) void { clock += ms; }
fn GetTickCount64() u64 { return clock; }
fn requestBrowser(allocator: std.mem.Allocator, method: []const u8, fields: []const u8, deadline: ?u64) ![]u8 {
    if (deadline != null and deadline.? <= 15_000) {
        const until = deadline.?;
        try std.testing.expectEqualStrings("tabs", method);
        try std.testing.expectEqualStrings("", fields);
        try std.testing.expect(until <= 15_000 and until > clock);
        probes += 1;
        if (mode == .stuck) return allocator.dupe(u8, "{\\"extensionVersion\\":\\"0.0.1\\"}");
        if (mode == .transient and probes == 1) return error.PipeUnavailable;
        if (mode == .transient and probes == 2) return allocator.dupe(u8, "invalid");
        return allocator.dupe(u8, "{\\"extensionVersion\\":\\"" ++ version ++ "\\"}");
    }
    try std.testing.expectEqual(@as(?u64, 20_000), deadline);
    calls += 1;
    if (mode == .transport and calls == 1) return error.PipeUnavailable;
    if (mode == .instance and calls == 1) return allocator.dupe(u8, "{\\"ok\\":false,\\"error\\":\\"No window with id: 42.\\",\\"extensionVersion\\":\\"" ++ version ++ "\\"}");
    if (mode == .tabs_old) return allocator.dupe(u8, "{\\\"ok\\\":true,\\\"result\\\":{\\\"tabs\\\":[]},\\\"extensionVersion\\\":\\\"0.0.1\\\"}");
    if (mode == .tabs) return allocator.dupe(u8, "{\\"ok\\":true,\\"result\\":{\\"tabs\\":[]},\\"extensionVersion\\":\\"" ++ version ++ "\\"}");
    if (calls == 1) return allocator.dupe(u8, if (mode == .failed) "{\\"ok\\":false,\\"extensionVersion\\":\\"0.0.1\\"}" else "{\\"ok\\":true,\\"extensionVersion\\":\\"0.0.1\\",\\"result\\":{\\"marker\\":7}}");
    return allocator.dupe(u8, "{\\"ok\\":true,\\"extensionVersion\\":\\"" ++ version ++ "\\"}");
}
${section('fn requestBrowserWithRetry(', 'fn requestBrowser(')}
${section('fn getBool(', 'fn getI64(')}
${section('fn appendJsonString(', 'fn readExact(')}
test "original success is byte-for-byte unchanged; failed commands replay once; deadlines and existing retries survive" {
    const allocator = std.testing.allocator;
    inline for (.{ .success, .failed, .stuck, .transient, .instance, .tabs, .tabs_old, .transport }) |scenario| {
        mode = scenario;
        calls = 0;
        probes = 0;
        clock = 0;
        g_window_id = if (scenario == .tabs or scenario == .tabs_old) 42 else null;
        const result = try requestBrowserWithRetry(allocator, if (scenario == .tabs or scenario == .tabs_old) "tabs" else "navigate", "");
        defer allocator.free(result);
        if (scenario == .stuck) {
            try std.testing.expectEqual(@as(u64, 15_000), clock);
            try std.testing.expectEqual(@as(usize, 1), calls);
            try std.testing.expect(std.mem.indexOf(u8, result, "extension version 0.0.1 does not match bridge " ++ version ++ ": reload the extension in chrome://extensions; if it persists, install matching bridge/extension versions") != null);
        } else if (scenario == .tabs) {
            try std.testing.expectEqual(@as(usize, browser_request_attempts), calls);
            try std.testing.expect(std.mem.indexOf(u8, result, "empty session pane tab list") != null);
        } else {
            try std.testing.expect(jsonOk(result));
            try std.testing.expectEqual(@as(usize, if (scenario == .failed or scenario == .instance or scenario == .transport) 2 else 1), calls);
            if (scenario == .tabs_old) try std.testing.expectEqualStrings("{\\\"ok\\\":true,\\\"result\\\":{\\\"tabs\\\":[]},\\\"extensionVersion\\\":\\\"0.0.1\\\"}", result);
            if (scenario == .success or scenario == .transient) try std.testing.expectEqualStrings("{\\"ok\\":true,\\"extensionVersion\\":\\"0.0.1\\",\\"result\\":{\\"marker\\":7}}", result);
        }
    }
    mode = .success;
    calls = 0;
    probes = 0;
    const explicit = try requestBrowserWithRetry(allocator, "extensionReload", "");
    defer allocator.free(explicit);
    try std.testing.expectEqual(@as(usize, 0), probes);
}
fn jsonOk(raw: []const u8) bool {
    const parsed = std.json.parseFromSlice(std.json.Value, std.testing.allocator, raw, .{}) catch return false;
    defer parsed.deinit();
    return getBool(parsed.value.object.get("ok"));
}
`;
  const file = path.join(dir, 'heal.zig');
  fs.writeFileSync(file, source);
  const zig = process.env.ZIG_EXE || process.env.ZIG || path.join(os.homedir(), '.local/zig-0.16.0/zig');
  const result = spawnSync(zig, ['test', '-j1', file], { encoding: 'utf8', timeout: 120000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
