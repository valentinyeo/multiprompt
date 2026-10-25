const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');
const source = require('./app-source').readAppSource();

function body(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

function harness(production) {
  const savedTab = source.match(/const SavedTab = struct \{[\s\S]*?\n};/)[0];
  const kind = source.match(/const ShellKind = enum[^;]+;/)[0];
  return `const std = @import("std");
const json_reader = @import("json_reader.zig");
const archive_rules = @import("archive_rules.zig");
const view = @import("chat_view.zig");
const DWORD = u32;
const BROWSER_SPLIT_DEFAULT_PERMILLE = 350;
${kind}
${savedTab}
const Shell = struct { chat_view_on: bool = false, pinned_top: bool = false };
var shells = [_]Shell{ .{}, .{ .pinned_top = true } };
var shell_count: u32 = 2;
var active_shell: u32 = 0;
var g_chat_active = true;
var saves: usize = 0;
fn saveSession() void { saves += 1; }
fn openChatView() void { g_chat_active = true; }
fn closeChatView() void { g_chat_active = false; }
${production}
test "IGSH-820 user toggles work on pinned and unpinned tabs" {
    view.setEverywhere(&shells, true);
    for (0..2) |i| {
        active_shell = @intCast(i);
        g_chat_active = shells[i].chat_view_on;
        toggleChatView();
        try std.testing.expect(!g_chat_active and !shells[i].chat_view_on);
        toggleChatView();
        try std.testing.expect(g_chat_active and shells[i].chat_view_on);
    }
    try std.testing.expectEqual(@as(usize, 4), saves);
    try std.testing.expect(shells[1].pinned_top);
}
test "ISSUE-611 legacy shell override migration stays scoped" {
    const json = "{\\\"chat_view_mode\\\":\\\"everywhere\\\",\\\"tabs\\\":[{\\\"kind\\\":\\\"cmd\\\",\\\"name\\\":\\\"Shell\\\",\\\"cso\\\":true},{\\\"kind\\\":\\\"cmd\\\",\\\"name\\\":\\\"Chat\\\",\\\"extra\\\":{\\\"cso\\\":true}}]}";
    var parsed = try json_reader.parse(std.testing.allocator, json);
    defer parsed.deinit();
    var tabs: [2]SavedTab = undefined;
    try std.testing.expectEqual(@as(u32, 2), json_reader.sessionTabs(parsed.value, &tabs, 16));
    try std.testing.expect(!tabs[0].cv and tabs[1].cv);
}
`;
}

test('IGSH-820 executes production toggles and legacy shell migration', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-view-pins-'));
  try {
    copyZig(['json_reader.zig', 'chat_view.zig'], dir);
    const file = path.join(dir, 'test.zig');
    const production = body('toggleChatView');
    fs.writeFileSync(file, harness(production));
    const zig = process.env.ZIG || 'zig';
    const result = spawnSync(zig, ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
    const broken = production.replace('@import("chat_view.zig").toggle(shell);', 'shell.chat_view_on = true;');
    assert.notEqual(broken, production);
    fs.writeFileSync(file, harness(broken));
    const negative = spawnSync(zig, ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.notEqual(negative.status, 0);
    assert.match(negative.stderr, /IGSH-820 user toggles[^]*FAIL/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('IGSH-820 view restoration and respawn retain independent view preferences without locks', () => {
  for (const name of ['openChatView', 'closeChatView', 'respawnShellInPlace', 'restoreBrowserStateFromSavedTab']) assert.doesNotMatch(body(name), /chat_view_lock/);
  assert.match(body('respawnShellInPlace'), /\.chat_view_on = saved_chat_view_on,/);
  assert.match(body('restoreBrowserStateFromSavedTab'), /shells\[idx\]\.chat_view_on = tab\.cv;/);
});
