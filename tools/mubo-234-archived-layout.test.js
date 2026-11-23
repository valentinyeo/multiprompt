const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');

const read = (file) => fs.readFileSync(file, 'utf8');

function between(source, start, end) {
  const first = source.indexOf(start);
  const last = source.indexOf(end, first + start.length);
  assert.ok(first >= 0 && last > first, `missing ${start}`);
  return source.slice(first, last);
}

function canRunZig() {
  const zig = process.env.ZIG || 'zig';
  return spawnSync(zig, ['version'], { encoding: 'utf8' }).status === 0;
}

function native(source, files) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mubo-234-archived-'));
  try {
    const copied = copyZig(files, dir);
    if (copied.includes('json_reader.zig')) {
      const file = path.join(dir, 'json_reader.zig');
      fs.writeFileSync(file, read(file).replace(/^test "[^\n]+" \{[\s\S]*?^\}\n/gm, ''));
    }
    fs.writeFileSync(path.join(dir, 'test.zig'), source);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '-j1'], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('MUBO-234 applying account layout drops tabs that are still in archive.json', () => {
  const desktop = read('src/account_desktop.zig');
  const filter = between(desktop, '    var kept: std.ArrayList(session_layout.Tab)', '    app_state.g_account_applying = true;');
  assert.match(filter, /sessionIsArchived\(tab\.tmux_host, tab\.tmux_session\)/);
  assert.match(filter, /g_tmux_closed\.contains\(tab\.tmux_host, tab\.tmux_session\)/);

  const push = between(desktop, 'fn accountCapturePush(', 'pub fn publishSessionLayout');
  assert.match(push, /loadArchiveFromDisk\(false\)/);
  assert.match(push, /g_archived_count/);
});

test('MUBO-234 archived sessions are stripped before layout tabs are applied', { skip: !canRunZig() }, () => {
  const filter = between(read('src/account_desktop.zig'), '    var kept: std.ArrayList(session_layout.Tab)', '    app_state.g_account_applying = true;');
  native(`const std = @import("std");
const session_layout = struct { const Tab = struct { tmux_host: u8, tmux_session: []const u8, workspace: []const u8 = "" }; };
const g_tmux_closed = struct {
    fn contains(_: u8, _: []const u8) bool { return false; }
};
fn sessionIsArchived(host: u8, session: []const u8) bool {
    return host == 1 and std.mem.eql(u8, session, "live-8306994");
}
fn filterLayoutTabs(a: std.mem.Allocator, tabs: []const session_layout.Tab) ![]session_layout.Tab {
    var desired = struct { tabs: []const session_layout.Tab }{ .tabs = tabs };
    var kept: std.ArrayList(session_layout.Tab) = .empty;
${filter}
    return kept.items;
}
test "archived layout tab is not kept" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const tabs = [_]session_layout.Tab{ .{ .tmux_host = 1, .tmux_session = "live-8306994" }, .{ .tmux_host = 1, .tmux_session = "still-open" } };
    const kept = try filterLayoutTabs(a, tabs[0..]);
    try std.testing.expectEqual(@as(usize, 1), kept.len);
    try std.testing.expectEqualStrings("still-open", kept[0].tmux_session);
}
`, ['tmux_identity.zig', 'json_reader.zig']);
});