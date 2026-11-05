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
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
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
  const script = JSON.parse(literal[1]).replaceAll('\\"', '"').replace('/home/*/projects/*/', `${f.root}/home/*/projects/*/`);
  const result = spawnSync('sh', ['-c', script], { encoding: 'utf8', timeout: 10000 });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.stdout.trim().split('\n').sort(), [...f.safe, path.join(f.projects, 'unsafe name')].sort());
});

test('IGSH-1686 production parsing retains late folders, host identity, and safe-path filtering', t => {
  const f = fixture(t);
  assert.ok(capacity >= f.safe.length, 'the picker must retain more than ninety-two project folders');
  const base = Number(state.match(/SEARCH_PICK_REPO_ROW_OFFSET: usize = (\d+);/)[1]);
  const next = Number(state.match(/SEARCH_RENAMEWIN_OFFSET: usize = (\d+);/)[1]);
  assert.ok(base + capacity <= next, 'repository rows must stay inside their routing band');
  const listing = [...f.safe, f.safe[0], path.join(f.projects, 'unsafe name'), 'not-a-path'].join('\n') + '\n';
  const row = vps.slice(vps.indexOf('pub const RepoRow = struct'), vps.indexOf('const MAX_REPO_ROWS'));
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
    var small: [2]RepoRow = @splat(.{});
    try std.testing.expectEqual(@as(u32, 2), parseRepoListing(2, ${JSON.stringify(listing)}, &small));
}
`);
  const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
