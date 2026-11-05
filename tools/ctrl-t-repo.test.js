const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync, existsSync } = require('node:fs');

const control = readFileSync('.claude/skills/verify-multiprompt/control.ps1', 'utf8');
const sessions = readFileSync('.claude/skills/verify-multiprompt/control-feature-sessions.ps1', 'utf8');

test('shared Windows verifier builds use a portable CPU', () => {
  const workflow = readFileSync('.github/workflows/verify.yml', 'utf8');
  const start = workflow.indexOf('- name: Build the Windows app once for this push');
  const end = workflow.indexOf('- uses:', start);
  assert.ok(start >= 0 && end > start);
  assert.match(workflow.slice(start, end), /zig build[^\n]*-Dcpu=(?:baseline|x86_64_v3)\b/);
});

test('sessions installs the SSH boundary before launch', () => {
  assert.ok(existsSync('tools/verify-repo-picker/ssh.c'), 'repository picker boundary source must exist');
  const ssh = readFileSync('tools/verify-repo-picker/ssh.c', 'utf8');
  const setup = control.indexOf("if ($Feature -eq 'sessions') {");
  const launch = control.indexOf('$process = $job.Start(');
  assert.ok(setup > 0 && setup < launch);
  assert.match(control.slice(setup, launch), /zig cc[\s\S]*ssh-path\.txt[\s\S]*active_tab = 1; active_workspace = 0; single_window = \$true[\s\S]*tmux_host = 0[\s\S]*tmux_host = 2[\s\S]*session\.json[\s\S]*seed-session\.json/);
  assert.match(control, /'sessions', 'browser-own-profile'[\s\S]*'--single-window'/);
  assert.match(ssh, /invocation-%lu\.txt/);
  assert.match(ssh, /\/work\/projects\/alpha/);
  assert.match(ssh, /\/work\/projects\/beta/);
});

test('Ctrl+T picks a notes-only folder directly and checks the saved chat', () => {
  const journey = sessions.slice(0, sessions.indexOf("Palette 'new claude in terminal'"));
  assert.match(journey, /\$state\.active_tab -eq 1[\s\S]*\$state\.tabs\[1\]\.tmux_host -eq 2[\s\S]*sessions-initial\.json[\s\S]*Ctrl\+T: new Claude chat[\s\S]*listing-\*\.txt[\s\S]*Type-Text 'notes-only'[\s\S]*Enter: select notes-only[\s\S]*\$tab\.cwd -eq '\/work\/projects\/notes-only' -and \$tab\.cv -eq \$true -and \$tab\.tmux_host -eq 2/);
  const pickerStart = journey.indexOf('$beforeClaude = @((Read-Session).tabs).Count');
  const pickerEnd = journey.indexOf("Palette 'hide from sidebar'", pickerStart);
  assert.ok(pickerStart >= 0 && pickerEnd > pickerStart, 'notes-only picker boundaries must exist');
  assert.doesNotMatch(journey.slice(pickerStart, pickerEnd), /\bPalette\s+'|commands\.json|catch|fallback/i);
  assert.match(journey.slice(pickerEnd), /^Palette 'hide from sidebar'\s*\n\s*Press @\(0x0D\) 'Enter: hide notes-only chat'/);
  assert.match(journey.slice(0, pickerStart), /workspace-carrier-cache\.json[\s\S]*Ctrl\+T: new chat in Example workspace[\s\S]*host enable claude\.\*--cwd \/home\/owner\/projects\/sample[\s\S]*workspace-hosted-launch\.txt/);
  assert.match(journey, /notes-only chat closed'[\s\S]*Palette 'Second'[\s\S]*Enter: return to the seeded third-server session[\s\S]*\$state\.tabs\[\$state\.active_tab\]\.tmux_host -eq 2/);
});

test('IGSH-1680 native search checks both partial-name queries and the chosen host folder', () => {
  const ssh = readFileSync('tools/verify-repo-picker/ssh.c', 'utf8');
  assert.ok(ssh.indexOf('puts("/work/soft-tools/factory/alpha")') < ssh.indexOf('puts("/work/projects/software-factory")'));
  assert.match(sessions, /foreach \(\$query in @\('soft', 'factory soft'\)\)[\s\S]*Type-Text \$query[\s\S]*Snapshot \(\$searchProof \+ '-picker'\)[\s\S]*Enter: select software-factory before path-only matches[\s\S]*\$tab\.cwd -eq '\/work\/projects\/software-factory' -and \$tab\.cv -eq \$true -and \$tab\.tmux_host -eq 2[\s\S]*Save-Json \(Read-Session\)/);
});

test('cancel precedes zz-last-folder chat and beta terminal checks', () => {
  assert.match(sessions, /cancel repository picker[\s\S]*close palette[\s\S]*\$cancelled\.tabs\[\$cancelled\.active_tab\]\.tmux_host -ne 2[\s\S]*Ctrl\+T: new Claude chat after cancel[\s\S]*Type-Text 'zz-last-folder'[\s\S]*\$tab\.cwd -eq '\/work\/projects\/zz-last-folder' -and \$tab\.cv -eq \$true -and \$tab\.tmux_host -eq 2[\s\S]*New Claude in terminal[\s\S]*Type-Text 'beta'[\s\S]*\$tab\.cwd -eq '\/work\/projects\/beta'[\s\S]*\$tab\.cv -eq \$false\) -and \$tab\.tmux_host -eq 2/);
});

test('IGSH-1447 executed production host selection follows active server', () => {
  const fs = require('node:fs');
  const os = require('node:os');
  const path = require('node:path');
  const { spawnSync } = require('node:child_process');
  const source = readFileSync('src/command_palette.zig', 'utf8');
  const start = source.indexOf('pub fn workspaceHostForNewTab');
  const end = source.indexOf('pub fn pickRepoOpen', start);
  assert.ok(start >= 0 && end > start);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ctrl-t-repo-'));
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, `const std = @import("std");
const app_state = struct {
    const Shell = struct { workspace: u8, tmux_host: u8, tmux_session_len: usize };
    var shells = [_]Shell{
        .{ .workspace = 0, .tmux_host = 1, .tmux_session_len = 1 },
        .{ .workspace = 0, .tmux_host = 2, .tmux_session_len = 1 },
        .{ .workspace = 1, .tmux_host = 1, .tmux_session_len = 1 },
        .{ .workspace = 0, .tmux_host = 0, .tmux_session_len = 0 },
    };
    var shell_count: usize = 4;
    var active_shell: usize = 1;
    var g_single_window = true;
};
${source.slice(start, end)}
test "active server and workspace fallback" {
    try std.testing.expectEqual(@as(u8, 2), workspaceHostForNewTab(0));
    try std.testing.expectEqual(@as(u8, 1), workspaceHostForNewTab(1));
    app_state.active_shell = 4;
    try std.testing.expectEqual(@as(u8, 1), workspaceHostForNewTab(0));
    app_state.active_shell = 3;
    try std.testing.expectEqual(@as(u8, 1), workspaceHostForNewTab(0));
    app_state.shells[0].tmux_session_len = 0;
    app_state.shells[1].tmux_session_len = 0;
    app_state.shells[2].tmux_session_len = 0;
    try std.testing.expectEqual(@as(u8, 0), workspaceHostForNewTab(0));
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, `${result.error || ''}\n${result.stdout}\n${result.stderr}`);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('repository search executes production matching and ranking', () => {
  const fs = require('node:fs');
  const os = require('node:os');
  const path = require('node:path');
  const { spawnSync } = require('node:child_process');
  const source = readFileSync('src/command_palette.zig', 'utf8');
  const start = source.indexOf('fn repoPathMatchesQuery(');
  const end = source.indexOf('pub fn workspaceHostForNewTab', start);
  const lower = source.indexOf('pub fn u16ToLower(');
  const lowerEnd = source.indexOf('pub fn u16ContainsInsensitive', lower);
  assert.ok(start >= 0 && end > start && lower >= 0 && lowerEnd > lower);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'repo-search-'));
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, `const std = @import("std");
const MAX_REPO_ROWS = 8;
const RepoRow = struct { host: u8 = 0, path_len: u16 = 0, path: [255]u8 = [_]u8{0} ** 255 };
const app_state = struct {
    var g_search_pick_repo_host: u8 = 2;
    var g_search_buf: [128]u16 = undefined;
    var g_search_len: usize = 0;
};
const paths = [_][]const u8{ "/soft/archive", "/work/software-factory", "/SOFT/other", "/work/soft-tools", "/factory/software", "/work/software-factory-two" };
fn repoRowsForHost(host: u8, out: []RepoRow) u32 {
    for (paths, 0..) |p, i| {
        out[i].host = host;
        out[i].path_len = @intCast(p.len);
        @memcpy(out[i].path[0..p.len], p);
    }
    return paths.len;
}
${source.slice(lower, lowerEnd)}
${source.slice(start, end)}
fn search(query: []const u8, out: []RepoRow) u32 {
    for (query, 0..) |c, i| app_state.g_search_buf[i] = c;
    app_state.g_search_len = query.len;
    return pickRepoFilteredRows(out);
}
fn expectRow(row: RepoRow, expected: []const u8) !void {
    try std.testing.expectEqualStrings(expected, row.path[0..row.path_len]);
    try std.testing.expectEqual(@as(u8, 2), row.host);
}
test "partial words and stable ranking" {
    var out: [MAX_REPO_ROWS]RepoRow = undefined;
    try std.testing.expect(repoPathMatchesQuery("/work/software-factory", &.{ 's', 'o', 'f', 't' }));
    try std.testing.expectEqual(@as(u32, 6), search("soft", &out));
    try expectRow(out[0], paths[1]);
    try expectRow(out[1], paths[3]);
    try expectRow(out[2], paths[4]);
    try expectRow(out[3], paths[5]);
    try expectRow(out[4], paths[0]);
    try expectRow(out[5], paths[2]);
    try std.testing.expectEqual(@as(u32, 3), search("factory soft", &out));
    try expectRow(out[0], paths[1]);
    try expectRow(out[1], paths[5]);
    try expectRow(out[2], paths[4]);
    try std.testing.expectEqual(@as(u32, 3), search("  FaCtOrY\\tSoFt  ", &out));
    try std.testing.expectEqual(@as(u32, 0), search("soft missing", &out));
    try std.testing.expectEqual(@as(u32, 6), search("", &out));
    for (paths, 0..) |p, i| try expectRow(out[i], p);
    try std.testing.expectEqual(@as(u32, 6), search(" \\t ", &out));
    for (paths, 0..) |p, i| try expectRow(out[i], p);
    try std.testing.expectEqual(@as(u32, 2), search("soft", out[0..2]));
    try expectRow(out[0], paths[1]);
    try expectRow(out[1], paths[3]);
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, `${result.error || ''}\n${result.stdout}\n${result.stderr}`);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
