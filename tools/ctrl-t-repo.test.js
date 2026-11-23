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
  assert.match(ssh, /remote-3[\s\S]*remote-2[\s\S]*offline-%d[\s\S]*\/work\/primary\/atlas[\s\S]*\/work\/secondary\/cedar[\s\S]*\/work\/projects\/notes-only/);
  assert.match(ssh, /tmux list-sessions[\s\S]*remote-1[\s\S]*terminal-owner\|1\|0\|\/home\/login/);
  assert.match(sessions, /workspace-carrier-cache\.json[\s\S]*listing-\$_-\*\.txt[\s\S]*count=104 ids=6702 6710 6711/);
});

test('Ctrl+T picks a notes-only folder directly and checks the saved chat', () => {
  const journey = sessions.slice(0, sessions.indexOf("Palette 'new terminal'"));
  assert.match(journey, /\$state\.active_tab -eq 1[\s\S]*\$state\.tabs\[1\]\.tmux_host -eq 2[\s\S]*sessions-initial\.json[\s\S]*Ctrl\+T: new Claude chat[\s\S]*listing-\$_-\*\.txt[\s\S]*Type-Text 'notes-only'[\s\S]*Enter: select notes-only[\s\S]*\$tab\.cwd -eq '\/work\/projects\/notes-only' -and \$tab\.cv -eq \$true -and \$tab\.tmux_host -eq 2/);
  const pickerStart = journey.indexOf('Ctrl+T: select an available server after offline rejection');
  const pickerEnd = journey.indexOf("Palette 'hide from sidebar'", pickerStart);
  assert.ok(pickerStart >= 0 && pickerEnd > pickerStart, 'notes-only picker boundaries must exist');
  assert.doesNotMatch(journey.slice(pickerStart, pickerEnd), /\bPalette\s+'|commands\.json|settings|catch|fallback/i);
  assert.match(journey.slice(pickerEnd), /^Palette 'hide from sidebar'\s*\n\s*Press @\(0x0D\) 'Enter: hide notes-only chat'/);
  assert.match(journey.slice(0, pickerStart), /workspace-carrier-cache\.json[\s\S]*Ctrl\+T: new chat in Example workspace[\s\S]*host enable claude\.\*--cwd \/home\/owner\/projects\/sample[\s\S]*workspace-hosted-launch\.txt/);

  assert.match(journey, /notes-only chat closed'[\s\S]*Palette 'Second'[\s\S]*Enter: return to the seeded third-server session[\s\S]*\$state\.tabs\[\$state\.active_tab\]\.tmux_host -eq 2/);
});

test('initial picker captures the combined all-server search', () => {
  assert.match(sessions, /Snapshot 'repo-picker-rows'\s+\$logBefore = \(Get-Content -LiteralPath \$repoLog -Raw\)\.Length\s+Type-Text 'ar'\s+Wait-Until \{ \$log = Get-Content -LiteralPath \$repoLog -Raw; \$log\.Length -gt \$logBefore -and \$log\.Substring\(\$logBefore\) -match '\\\[palette\\\] rows chars=2 count=4 ' \}[^\n]*\s+Snapshot 'repo-picker-all-servers'\s+Press @\(0x1B\) 'Esc: leave initial picker'/);
});

test('cross-host and offline journeys require the selected host and rejection', () => {
  assert.match(sessions, /listing-\$_-\*\.txt[\s\S]*remote-2 cedar[\s\S]*host = 1[\s\S]*host = 0[\s\S]*\$hostId -eq \$case\.host[\s\S]*\$text\.Contains\(\$case\.alias\)[\s\S]*\$text\.Contains\(\$case\.cwd\)[\s\S]*\$text\.Contains\('tmux new-session'\)[\s\S]*\$text\.Contains\('host enable claude'\)[\s\S]*\$text\.Contains\('host start claude'\)[\s\S]*\$text\.Contains\('--cwd ' \+ \$case\.cwd\)/);
  const normalizeHost = /\$hostId = if \(\$tab\.PSObject\.Properties\['tmux_host'\]\) \{ \[int\]\$tab\.tmux_host \} else \{ 0 \}/.source;
  assert.match(sessions, new RegExp(`Where-Object \\{ \\$tab = \\$_; ${normalizeHost}; \\$hostId -eq 1 \\}\\)\\.Count -ne 0`));
  assert.match(sessions, new RegExp(`${normalizeHost}\\s+\\$tab\\.cwd -eq \\$case\\.cwd -and \\$hostId -eq \\$case\\.host -and \\$tab\\.cv -eq \\$true`));
  assert.match(sessions, new RegExp(`${normalizeHost}\\s+\\$hostId -eq 0 -and \\$tab\\.cwd -eq '/work/primary/atlas' -and \\$tab\\.cv -eq \\$true`));
  assert.match(sessions, /offline-1[\s\S]*\[repo\] offline host=1[\s\S]*\$logBefore = [^\n]+[\s\S]*Enter: reject offline folder[\s\S]*\$log\.Substring\(\$logBefore\)\.Contains\('\[repo\] selection rejected'\)[\s\S]*Offline selection saved a tab[\s\S]*Offline selection launched SSH[\s\S]*other host stays usable[\s\S]*\[repo\] online host=1/);
});

test('cross-host and available-host cleanup hides tabs and restores host 2', () => {
  for (const kind of ['cross-host', 'available host']) {
    assert.match(sessions, new RegExp(`Palette 'hide from sidebar'\\s+Press @\\(0x0D\\) 'Enter: hide ${kind} chat'\\s+Wait-Until \\{ @\\(\\(Read-Session\\)\\.tabs\\)\\.Count -eq \\$beforeClaude \\} '${kind} chat closed'\\s+Palette 'Second'\\s+Press @\\(0x0D\\) 'Enter: return to host 2'\\s+Wait-Until \\{ \\$state = Read-Session; \\$state\\.tabs\\[\\$state\\.active_tab\\]\\.tmux_host -eq 2 \\}`));
  }
  assert.doesNotMatch(sessions, /Press\s+@\(0x11,\s*0x57\)/i);
});

test('IGSH-1680 native search checks both partial-name queries and the chosen host folder', () => {
  const ssh = readFileSync('tools/verify-repo-picker/ssh.c', 'utf8');
  assert.ok(ssh.indexOf('puts("/work/soft-tools/factory/alpha")') < ssh.indexOf('puts("/work/projects/software-factory")'));
  assert.match(sessions, /foreach \(\$query in @\('soft', 'factory soft'\)\)[\s\S]*Type-Text \$query[\s\S]*Snapshot \(\$searchProof \+ '-picker'\)[\s\S]*Enter: select software-factory before path-only matches[\s\S]*\$tab\.cwd -eq '\/work\/projects\/software-factory' -and \$tab\.cv -eq \$true -and \$tab\.tmux_host -eq 2[\s\S]*Save-Json \(Read-Session\)/);
});

test('cancel precedes zz-last-folder chat and beta terminal checks', () => {
  assert.match(sessions, /cancel repository picker[\s\S]*close palette[\s\S]*\$cancelled\.tabs\[\$cancelled\.active_tab\]\.tmux_host -ne 2[\s\S]*Ctrl\+T: new Claude chat after cancel[\s\S]*Type-Text 'zz-last-folder'[\s\S]*\$tab\.cwd -eq '\/work\/projects\/zz-last-folder' -and \$tab\.cv -eq \$true -and \$tab\.tmux_host -eq 2[\s\S]*Enter: New terminal[\s\S]*Type-Text 'beta'[\s\S]*\$tab\.cwd -eq '\/work\/projects\/beta'[\s\S]*\$tab\.cv -eq \$false\) -and \$tab\.tmux_host -eq 2/);
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
  assert.match(source, /var g_repo_scan_rows: \[REPO_SCAN_ROWS\]RepoRow = undefined;/);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'repo-search-'));
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, `const std = @import("std");
const MAX_REPO_ROWS = 8;
const REPO_SCAN_ROWS = 8;
const RepoRow = struct { host: u8 = 0, path_len: u16 = 0, path: [255]u8 = [_]u8{0} ** 255, host_name_len: u8 = 0, host_name: [128]u8 = [_]u8{0} ** 128 };
const app_state = struct {
    var g_search_pick_repo_host: u8 = 2;
    var g_search_buf: [128]u16 = undefined;
    var g_search_len: usize = 0;
};
const paths = [_][]const u8{ "/soft/archive", "/work/software-factory", "/SOFT/other", "/work/soft-tools", "/factory/software", "/work/software-factory-two" };
var cross_host = false;
fn repoRowsForHost(host: u8, out: []RepoRow) u32 {
    if (cross_host) {
        if (host == 2) {
            for (out) |*row| {
                row.* = .{};
                row.host = host;
                const p = "/work/other";
                row.path_len = p.len;
                @memcpy(row.path[0..p.len], p);
            }
            return @intCast(out.len);
        }
        if (host == 0 or host == 1) {
            const p = "/work/shared";
            const name = if (host == 0) "North" else "South";
            out[0] = .{};
            out[0].host = host;
            out[0].path_len = p.len;
            @memcpy(out[0].path[0..p.len], p);
            out[0].host_name_len = name.len;
            @memcpy(out[0].host_name[0..name.len], name);
            return 1;
        }
        return 0;
    }
    if (host != 2) return 0;
    for (paths, 0..) |p, i| {
        out[i] = .{};
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
test "all hosts are filtered before the result limit" {
    cross_host = true;
    var out: [MAX_REPO_ROWS]RepoRow = undefined;
    try std.testing.expectEqual(@as(u32, 2), search("shared", &out));
    try std.testing.expectEqual(@as(u8, 0), out[0].host);
    try std.testing.expectEqual(@as(u8, 1), out[1].host);
    try std.testing.expectEqualStrings(out[0].path[0..out[0].path_len], out[1].path[0..out[1].path_len]);
    try std.testing.expectEqual(@as(u32, 1), search("south shared", &out));
    try std.testing.expectEqual(@as(u8, 1), out[0].host);
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, `${result.error || ''}\n${result.stdout}\n${result.stderr}`);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('offline selection reports the user failure while background fetching stays quiet', () => {
  const main = readFileSync('src/main.zig', 'utf8');
  const palette = readFileSync('src/command_palette.zig', 'utf8');
  const vps = readFileSync('src/vps.zig', 'utf8');
  const choose = palette.match(/pub fn pickRepoChoose\([^]*?\n\}/);
  const failure = main.match(/fn showPickRepoFailure\([^]*?\n\}/);
  const fetch = vps.match(/fn repoFetchThread\([^]*?\n\}/);
  assert.ok(choose && failure && fetch);
  assert.match(choose[0], /if \(!@import\("vps\.zig"\)\.repoRowAvailable\(&rows\[idx\]\)\) \{[^]*?g_pick_repo_offline = true;\s*return false;/);
  assert.match(main, /if \(target >= SEARCH_PICK_REPO_ROW_OFFSET and target < SEARCH_PICK_REPO_ROW_OFFSET \+ MAX_REPO_ROWS\) \{[^]*?const picked = pickRepoChoose\(target\);[^]*?if \(!picked\) showPickRepoFailure\(saving_folder\);/);
  assert.match(failure[0], /if \(palette\.g_pick_repo_offline\) \{\s*showHeaderNoticeAscii\("Pick repo: server is offline", 4000, true\);\s*return;/);
  assert.doesNotMatch(fetch[0], /showHeaderNoticeAscii/);
});

test('offline repository selection does not start or save anything', () => {
  const fs = require('node:fs');
  const os = require('node:os');
  const path = require('node:path');
  const { spawnSync } = require('node:child_process');
  const source = readFileSync('src/command_palette.zig', 'utf8');
  const start = source.indexOf('pub fn pickRepoChoose(');
  const end = source.indexOf('\nfn customCmdMatchesQuery', start);
  assert.ok(start >= 0 && end > start);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'repo-offline-'));
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, `const std = @import("std");
const MAX_REPO_ROWS = 2;
const SEARCH_PICK_REPO_ROW_OFFSET = 100;
const RepoRow = struct { host: u8 = 0, path_len: u16 = 0, path: [255]u8 = [_]u8{0} ** 255, available: bool = true };
const app_state = struct {
    var g_search_pick_repo_folder_mode = false;
    var g_search_pick_repo_with_agent = true;
    var g_search_pick_repo_plain_claude = false;
};
var g_pick_row_gone = false;
var g_pick_repo_offline = false;
var g_start_fail: enum { none } = .none;
var spawned = false;
var did_save = false;
var chosen_host: u8 = 255;
var live_host: u8 = 1;
fn closePickRepo() void {}
var presented = [_]RepoRow{.{ .host = 1, .available = false }};
fn pickRepoPresentedRows() []const RepoRow { return &presented; }
fn repoRowAvailable(row: *const RepoRow) bool { return row.available; }
fn pickRepoFilteredRows(out: []RepoRow) u32 {
    out[0] = presented[0];
    out[0].host = live_host;
    return 1;
}
fn saveWorkspaceFolder(_: u8, _: []const u8) bool { did_save = true; return true; }
fn activeWorkspaceSlot() u8 { return 0; }
fn workspaceConfiguredTerminalFolder(_: u8, _: *u8, _: *[256]u8, _: *u32, _: *[128]u8, _: *u32) bool { return false; }
fn spawnWorkspaceSessionAt(host: u8, _: []const u8, _: []const u8, _: bool, _: bool) bool { spawned = true; chosen_host = host; return true; }
${source.slice(start, end).replaceAll('@import("diagnostics.zig").debugLog', 'debugLog').replaceAll('@import("vps.zig").repoRowAvailable', 'repoRowAvailable')}
fn debugLog(_: []const u8) void {}
test "offline row is not selectable" {
    try std.testing.expect(!pickRepoChoose(100));
    try std.testing.expect(!spawned and !did_save);
    app_state.g_search_pick_repo_folder_mode = true;
    try std.testing.expect(!pickRepoChoose(100));
    try std.testing.expect(!spawned and !did_save);
}
test "publication cannot retarget the displayed row" {
    presented[0] = .{ .host = 1, .available = true };
    live_host = 0;
    app_state.g_search_pick_repo_folder_mode = false;
    try std.testing.expect(pickRepoChoose(100));
    try std.testing.expectEqual(@as(u8, 1), chosen_host);
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, `${result.error || ''}\n${result.stdout}\n${result.stderr}`);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
