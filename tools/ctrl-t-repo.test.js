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
  assert.doesNotMatch(journey, /\bPalette\s+'|commands\.json|catch|fallback/i);
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
