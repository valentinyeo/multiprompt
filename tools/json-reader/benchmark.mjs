import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
import appSource from '../app-source.js';

const root = path.resolve(import.meta.dirname, '../..');
const main = appSource.readAppSource();
const model = main.slice(main.indexOf('const SavedTab = struct {'), main.indexOf('\nfn preserveFailedRemoteSavedTab')).replace('const SavedTab =', 'const CurrentSavedTab =');
assert.match(model, /name: \[64\]u16/);
const legacy = fs.readFileSync(path.join(root, 'tools/json-reader/legacy.zig'), 'utf8').replace(/^const (?:std|archive_rules|DWORD|BROWSER_SPLIT_DEFAULT_PERMILLE|ShellKind) = .*;\n/gm, '').replace(/^const BROWSER_SPLIT_DEFAULT_PERMILLE:.*\n/gm, '');
const source = `const std = @import("std");
const reader = @import("json_reader.zig");
const archive_rules = @import("archive_rules.zig");
const DWORD = u32;
const BROWSER_SPLIT_DEFAULT_PERMILLE: u16 = 350;
const ShellKind = enum(u3) { cmd, pwsh, vps, tmux, vps2, bash, gitbash };
${model}
const legacy = struct {
${legacy}
};
const Timespec = extern struct { sec: i64, ns: i64 };
extern "c" fn clock_gettime(c_int, *Timespec) c_int;
fn now() u64 {
    var t: Timespec = undefined;
    std.debug.assert(clock_gettime(1, &t) == 0);
    return @as(u64, @intCast(t.sec)) * 1_000_000_000 + @as(u64, @intCast(t.ns));
}
fn sameOldFields(json: []const u8) !void {
    var old: [256]legacy.SavedTab = undefined;
    var tabs: [256]CurrentSavedTab = undefined;
    const count = legacy.parseSessionTabs(json, &old);
    var parsed = try reader.parse(std.testing.allocator, json);
    defer parsed.deinit();
    try std.testing.expectEqual(count, reader.sessionTabs(parsed.value, tabs[0..], 9));
    for (old[0..count], tabs[0..count]) |before, after| {
        inline for (@typeInfo(CurrentSavedTab).@"struct".fields) |field| {
            if (@hasField(legacy.SavedTab, field.name)) {
                if (comptime std.mem.eql(u8, field.name, "name")) {
                    for (before.name[0..before.name_len], after.name[0..after.name_len]) |a, b| try std.testing.expectEqual(@as(u16, a), b);
                } else {
                    try std.testing.expectEqualDeep(@field(before, field.name), @field(after, field.name));
                }
            } else {
                const default = comptime field.defaultValue() orelse @compileError("CurrentSavedTab." ++ field.name ++ " is absent from legacy.SavedTab and has no default");
                try std.testing.expectEqualDeep(default, @field(after, field.name));
            }
        }
    }
}
test "old-version session and all populated fields restore identically" {
    try sameOldFields(@embedFile("fixtures/json-reader/session-old.json"));
    try sameOldFields(@embedFile("fixtures/json-reader/session-60.json"));
}
test "sixty reordered escaped tabs round trip without crossing fields, values, or arrays" {
    const json = @embedFile("fixtures/json-reader/session-escaped.json");
    var parsed = try reader.parse(std.testing.allocator, json);
    defer parsed.deinit();
    var tabs: [256]CurrentSavedTab = undefined;
    try std.testing.expectEqual(@as(u32, 60), reader.sessionTabs(parsed.value, tabs[0..], 9));
    var name: [192]u8 = undefined;
    try std.testing.expectEqualStrings("Name {nested} ] \\"csid\\":\\"x\\" \\\\ newline\\nKraków 日🚀", reader.utf8(tabs[0].name[0..tabs[0].name_len], &name));
    try std.testing.expectEqualStrings("12345678-1234-1234-1234-000000000000", tabs[0].claude_sid[0..tabs[0].claude_sid_len]);
    try std.testing.expectEqualStrings("C:\\\\Users\\\\日\\\\repo", tabs[0].claude_cwd[0..tabs[0].claude_cwd_len]);
    try std.testing.expect(tabs[0].manual and tabs[0].bon and tabs[0].cv);
    try std.testing.expect(tabs[1].bnat and !tabs[1].manual and !tabs[1].bon and !tabs[1].favorite);
    try std.testing.expectEqual(@as(u16, 350), tabs[1].bsplit_permille);
    try std.testing.expectEqual(@as(u32, 0), tabs[1].claude_sid_len);
    try std.testing.expectEqual(@as(u8, 0), tabs[1].workspace);
    try std.testing.expectEqual(@as(u8, 2), tabs[2].archive_content.len);
    try std.testing.expectEqual(@as(u64, 0x0123456789abcdef), tabs[2].archive_content.rows[0]);
    try std.testing.expectEqual(@as(u64, 0xffffffffffffffff), tabs[2].last_done_content.rows[0]);
    const serialized = try std.json.Stringify.valueAlloc(std.testing.allocator, parsed.value, .{});
    defer std.testing.allocator.free(serialized);
    var restored = try reader.parse(std.testing.allocator, serialized);
    defer restored.deinit();
    var roundtrip: [256]CurrentSavedTab = undefined;
    try std.testing.expectEqual(@as(u32, 60), reader.sessionTabs(restored.value, roundtrip[0..], 9));
    try std.testing.expectEqualDeep(tabs[0..60], roundtrip[0..60]);
    var old: [256]legacy.SavedTab = undefined;
    const old_count = legacy.parseSessionTabs(json, &old);
    try std.testing.expect(old_count != 60 or old[0].claude_sid_len != tabs[0].claude_sid_len or !std.mem.eql(u8, old[0].claude_sid[0..old[0].claude_sid_len], tabs[0].claude_sid[0..tabs[0].claude_sid_len]));
}
test "60-tab restore performance and transient arena capacity" {
    const json = @embedFile("fixtures/json-reader/session-60.json");
    var old: [256]legacy.SavedTab = undefined;
    var tabs: [256]CurrentSavedTab = undefined;
    var before: [9]u64 = undefined;
    var after: [9]u64 = undefined;
    for (0..9) |batch| {
        const start = now();
        for (0..100) |_| {
            try std.testing.expectEqual(@as(u32, 60), legacy.parseSessionTabs(json, &old));
            std.mem.doNotOptimizeAway(old[0..60]);
        }
        before[batch] = (now() - start) / 100;
        const next = now();
        for (0..100) |_| {
            var parsed = try reader.parse(std.heap.page_allocator, json);
            defer parsed.deinit();
            try std.testing.expectEqual(@as(u32, 60), reader.sessionTabs(parsed.value, tabs[0..], 9));
            std.mem.doNotOptimizeAway(tabs[0..60]);
        }
        after[batch] = (now() - next) / 100;
    }
    std.mem.sort(u64, &before, {}, std.sort.asc(u64));
    std.mem.sort(u64, &after, {}, std.sort.asc(u64));
    var parsed = try reader.parse(std.heap.page_allocator, json);
    defer parsed.deinit();
    const bytes = parsed.arena.queryCapacity();
    std.debug.print("60-tab restore: before={d} ns after={d} ns ratio={d:.3} arena={d} bytes\\n", .{ before[4], after[4], @as(f64, @floatFromInt(after[4])) / @as(f64, @floatFromInt(before[4])), bytes });
    try std.testing.expect(after[4] * 10 <= before[4] * 11);
    try std.testing.expect(bytes <= 512 * 1024);
}
`;
const file = path.join(root, 'src/.json-restore-bench.zig');
try {
  fs.writeFileSync(file, source);
  const args = ['test', file, '-O', 'ReleaseFast', '-lc'];
  if (process.argv.includes('--fixtures-only')) args.push('--test-filter', 'session', '--test-filter', 'sixty');
  const result = spawnSync(process.env.ZIG || 'zig', args, { cwd: root, encoding: 'utf8', timeout: 180_000, maxBuffer: 8 * 1024 * 1024 });
  process.stdout.write(result.stdout || '');
  process.stderr.write(result.stderr || '');
  assert.equal(result.status, 0, result.error?.message || 'restore unit tests failed');
  console.log(process.argv.includes('--fixtures-only') ? 'SESSION FIXTURES PASS' : 'RESTORE PERFORMANCE PASS');
} finally {
  fs.rmSync(file, { force: true });
}
