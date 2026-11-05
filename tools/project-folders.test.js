const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const vps = fs.readFileSync('src/vps.zig', 'utf8');
const state = fs.readFileSync('src/app_state.zig', 'utf8');
const capacity = Number(state.match(/pub const MAX_REPO_ROWS: usize = (\d+);/)[1]);

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'project-folders-'));
  t.after(() => { fs.chmodSync(path.join(root, 'home', 'owner', 'projects'), 0o755); fs.rmSync(root, { recursive: true, force: true }); });
  const projects = path.join(root, 'home', 'owner', 'projects');
  const names = Array.from({ length: 96 }, (_, i) => `code-${String(i).padStart(3, '0')}`);
  for (const name of names) fs.mkdirSync(path.join(projects, name, '.git'), { recursive: true });
  for (const name of ['notes-only', 'worktree', 'zz-last-folder', 'unsafe name']) fs.mkdirSync(path.join(projects, name));
  fs.writeFileSync(path.join(projects, 'worktree', '.git'), 'gitdir: ../metadata');
  fs.writeFileSync(path.join(projects, 'not-a-folder'), 'not a directory');
  fs.symlinkSync(path.join(projects, 'notes-only'), path.join(projects, 'linked-project'));
  const safe = [...names, 'linked-project', 'notes-only', 'worktree', 'zz-last-folder'].map(name => path.join(projects, name)).sort();
  return { root, projects, safe };
}

test('IGSH-1686 discovery returns all project folders without Git or a sixty-row cutoff', t => {
  const f = fixture(t);
  const literal = vps.match(/const REPO_LIST_SCRIPT = ("(?:\\.|[^"\\])*");/);
  assert.ok(literal, 'the production discovery script must be available');
  const script = JSON.parse(literal[1]).replaceAll('\\"', '"').replaceAll('/home', `${f.root}/home`);
  const result = spawnSync('sh', ['-c', script], { encoding: 'utf8', timeout: 10000 });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.stdout.trim().split('\n').sort(), [...f.safe, path.join(f.projects, 'unsafe name')].sort());
});

test('discovery reports inaccessible projects without a success marker', t => {
  const f = fixture(t);
  const literal = vps.match(/const REPO_LIST_SCRIPT = ("(?:\\.|[^"\\])*");/);
  assert.ok(literal);
  const script = JSON.parse(literal[1]).replaceAll('\\"', '"').replaceAll('/home', `${f.root}/home`);
  assert.match(vps, /REPO_LIST_SCRIPT \+\+ " && printf/);
  const command = `${script} && printf '\n@@MP_REPOS_OK@@\n'`;
  fs.mkdirSync(path.join(f.root, 'home', 'empty', 'projects'), { recursive: true });
  fs.mkdirSync(path.join(f.root, 'home', 'absent'), { recursive: true });
  const ok = spawnSync('sh', ['-c', command], { encoding: 'utf8' });
  assert.equal(ok.status, 0, ok.stderr);
  assert.match(ok.stdout, /@@MP_REPOS_OK@@/);
  fs.chmodSync(f.projects, 0o000);
  const denied = spawnSync('sh', ['-c', command], { encoding: 'utf8' });
  assert.notEqual(denied.status, 0);
  assert.doesNotMatch(denied.stdout, /@@MP_REPOS_OK@@/);
});

test('IGSH-1686 production parsing retains late folders, host identity, and safe-path filtering', t => {
  const f = fixture(t);
  assert.ok(capacity >= f.safe.length, 'the picker must retain more than ninety-two project folders');
  const base = Number(state.match(/SEARCH_PICK_REPO_ROW_OFFSET: usize = (\d+);/)[1]);
  const next = Number(state.match(/SEARCH_RENAMEWIN_OFFSET: usize = (\d+);/)[1]);
  assert.ok(base + capacity <= next, 'repository rows must stay inside their routing band');
  const listing = [...f.safe, f.safe[0], path.join(f.projects, 'unsafe name'), 'not-a-path'].join('\n') + '\n';
  const row = vps.slice(vps.indexOf('pub const RepoRow = struct'), vps.indexOf('const MAX_REPO_ROWS'));
  assert.ok(vps.includes('fn repoSuccessfulListing('), 'successful listings must be distinguished from failures');
  const parser = vps.slice(vps.indexOf('fn repoPathSafe('), vps.indexOf('pub fn repoRowsForHost('));
  const file = path.join(f.root, 'folders.zig');
  fs.writeFileSync(file, `const std = @import("std");
const MAX_REPO_ROWS = ${capacity};
${row}
${parser}
test "all folders can be filtered on their source host" {
    var rows: [MAX_REPO_ROWS]RepoRow = @splat(.{});
    const count = parseRepoListing(2, ${JSON.stringify(listing)}, &rows);
    try std.testing.expectEqual(@as(u32, ${f.safe.length}), count);
    for (rows[0..count]) |entry| try std.testing.expectEqual(@as(u8, 2), entry.host);
    try std.testing.expect(repoRowMatches(&rows[count - 1], "ZZ-LAST-FOLDER"));
    var notes: u32 = 0;
    for (rows[0..count]) |entry| if (repoRowMatches(&entry, "notes-only")) { notes += 1; };
    try std.testing.expectEqual(@as(u32, 1), notes);
    try std.testing.expect(repoSuccessfulListing(false, "\\n@@MP_REPOS_OK@@\\n") == null);
    try std.testing.expect(repoSuccessfulListing(true, "/work/partial\\n") == null);
    try std.testing.expectEqualStrings("", repoSuccessfulListing(true, "\\n@@MP_REPOS_OK@@\\n").?);
    try std.testing.expectEqualStrings("/work/project\\r\\n", repoSuccessfulListing(true, "/work/project\\r\\n\\r\\n@@MP_REPOS_OK@@\\r\\n").?);
    var small: [2]RepoRow = @splat(.{});
    try std.testing.expectEqual(@as(u32, 2), parseRepoListing(2, ${JSON.stringify(listing)}, &small));
}
`);
  const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('surviving shells cannot migrate roots to a new endpoint', t => {
  assert.ok(vps.includes('fn repoConfigureCache('), 'cache reconfiguration must be testable');
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'repo-identity-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const row = vps.slice(vps.indexOf('pub const RepoRow = struct'), vps.indexOf('const MAX_REPO_ROWS'));
  const cache = vps.slice(vps.indexOf('const RepoStatus = enum'), vps.indexOf('var g_repo_caches:'));
  const listing = vps.slice(vps.indexOf('fn repoPathSafe('), vps.indexOf('pub fn repoRowAvailable('));
  const configure = vps.slice(vps.indexOf('fn repoConfigureCache('), vps.indexOf('pub fn requestRepoRefresh('));
  const publish = vps.slice(vps.indexOf('fn repoPublish('), vps.indexOf('fn repoFetchThread('));
  const file = path.join(root, 'identity.zig');
  fs.writeFileSync(file, `const std = @import("std");
const MAX_REPO_ROWS = 8;
${row}
${cache}
var g_repo_caches: [3]RepoCache = @splat(.{});
const SpinMutex = struct {
    state: std.atomic.Value(u8) = std.atomic.Value(u8).init(0),
    fn tryLock(self: *SpinMutex) bool { return self.state.cmpxchgStrong(0, 1, .acquire, .monotonic) == null; }
    fn unlock(self: *SpinMutex) void { self.state.store(0, .release); }
};
var g_repo_mutex: SpinMutex = .{};
fn Sleep(_: u32) void {}
const app_state = struct {
    const Shell = struct { tmux_session_len: usize = 1 };
    var shells = [_]Shell{.{}};
    const shell_count = 1;
};
fn tmuxHostForShell(_: *const app_state.Shell) ?u8 { return 0; }
fn shellKnownRemotePath(_: *const app_state.Shell, _: u8) ?[]const u8 { return "/old/project"; }
fn remoteRepoRoot(path: []const u8) []const u8 { return path; }
${listing}
${configure}
${publish}
test "endpoint replacement excludes old shell but permits discovery" {
    const cache = &g_repo_caches[0];
    var rows: [8]RepoRow = @splat(.{});
    repoConfigureCache(cache, true, "old", "Old");
    try std.testing.expectEqual(@as(u32, 1), repoRowsForHost(0, &rows));
    repoConfigureCache(cache, true, "old", "Renamed");
    try std.testing.expectEqual(@as(u32, 1), repoRowsForHost(0, &rows));
    const old_generation = cache.generation;
    repoConfigureCache(cache, true, "new", "New");
    try std.testing.expect(cache.generation != old_generation);
    try std.testing.expectEqual(@as(u32, 0), repoRowsForHost(0, &rows));
    var found: [8]RepoRow = @splat(.{});
    const n = parseRepoListing(0, "/new/project", &found);
    repoPublish(cache, cache.generation, true, found[0..n]);
    try std.testing.expectEqual(@as(u32, 1), repoRowsForHost(0, &rows));
    try std.testing.expectEqualStrings("/new/project", rows[0].path[0..rows[0].path_len]);
    repoConfigureCache(cache, false, "new", "New");
    repoConfigureCache(cache, true, "new", "New");
    try std.testing.expectEqual(@as(u32, 0), repoRowsForHost(0, &rows));
}
`);
  const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('repository caches isolate failures, empty results, and stale workers', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'repo-cache-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  assert.ok(vps.includes('fn repoPublish('), 'host cache publication must exist');
  assert.ok(vps.includes('pub fn repoRowAvailable('), 'presented rows must be revalidated');
  const row = vps.slice(vps.indexOf('pub const RepoRow = struct'), vps.indexOf('const MAX_REPO_ROWS'));
  const cache = vps.slice(vps.indexOf('const RepoStatus = enum'), vps.indexOf('var g_repo_caches:'));
  const publish = vps.slice(vps.indexOf('fn repoPublish('), vps.indexOf('fn repoFetchThread('));
  const available = vps.slice(vps.indexOf('pub fn repoRowAvailable('), vps.indexOf('fn repoFetchCommand('));
  const file = path.join(root, 'cache.zig');
  fs.writeFileSync(file, `const std = @import("std");
const MAX_REPO_ROWS = 256;
${row}
${cache}
var g_repo_caches: [3]RepoCache = [_]RepoCache{.{}} ** 3;
const SpinMutex = struct {
    state: std.atomic.Value(u8) = std.atomic.Value(u8).init(0),
    fn tryLock(self: *SpinMutex) bool { return self.state.cmpxchgStrong(0, 1, .acquire, .monotonic) == null; }
    fn unlock(self: *SpinMutex) void { self.state.store(0, .release); }
};
var g_repo_mutex: SpinMutex = .{};
fn Sleep(_: u32) void {}
${available}
${publish}
test "selection validates current host configuration" {
    const row = RepoRow{ .host = 1, .generation = 4 };
    g_repo_caches[1] = .{ .enabled = true, .generation = 4, .status = .online };
    try std.testing.expect(repoRowAvailable(&row));
    g_repo_caches[1].enabled = false;
    try std.testing.expect(!repoRowAvailable(&row));
    g_repo_caches[1].enabled = true;
    g_repo_caches[1].generation = 5;
    try std.testing.expect(!repoRowAvailable(&row));
    g_repo_caches[1].generation = 4;
    g_repo_caches[1].status = .offline;
    try std.testing.expect(!repoRowAvailable(&row));
}
test "host results and generations" {
    var first = RepoCache{ .enabled = true, .generation = 1 };
    var second = RepoCache{ .enabled = true, .generation = 2 };
    const rows = [_]RepoRow{.{ .host = 0 }};
    repoPublish(&first, 1, true, &rows);
    repoPublish(&second, 2, true, &rows);
    repoPublish(&first, 1, false, &.{});
    try std.testing.expectEqual(RepoStatus.offline, first.status);
    try std.testing.expectEqual(@as(u32, 1), first.count);
    try std.testing.expectEqual(RepoStatus.online, second.status);
    try std.testing.expectEqual(@as(u32, 1), second.count);
    first.generation = 3;
    repoPublish(&first, 1, true, &.{});
    try std.testing.expectEqual(@as(u32, 1), first.count);
    repoPublish(&first, 3, true, &.{});
    try std.testing.expectEqual(RepoStatus.online, first.status);
    try std.testing.expectEqual(@as(u32, 0), first.count);
}
`);
  const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
