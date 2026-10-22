const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const workflow = read('.github/workflows/verify-reconnect.yml');
const drive = read('tools/verify-reconnect/drive.ps1');
const desktop = read('tools/verify-reconnect/desktop.cs');
const fakeSsh = read('tools/verify-reconnect/fake-ssh.c');
assert.match(drive, /WriteAllText\("\$state\/sessions\.next", ""\)/);
assert.match(fakeSsh, /no server running on/);
assert.match(fakeSsh, /if \(sessions\[0\]\)/);
assert.match(fakeSsh, /strstr\(cmd, "2>&1"\) && strstr\(cmd, "no server running"\)/);
assert.match(workflow, /workflow_dispatch:/);
assert.match(workflow, /exe_source:[\s\S]*default: build/);
assert.match(workflow, /pull_request:[\s\S]*src\/ssh_reconnect\.zig[\s\S]*src\/chat_send\.zig[\s\S]*src\/console\.zig/);
assert.match(workflow, /runs-on: windows-latest/);
assert.match(workflow, /timeout-minutes: 20/);
assert.match(workflow, /EXE_SOURCE -eq 'build'[\s\S]*zig build -Dtarget=x86_64-windows-gnu/);
assert.match(workflow, /gh release download[\s\S]*multiprompt-x64.exe[\s\S]*SHA256SUMS.txt/);
assert.match(workflow, /Get-FileHash bin\/multiprompt-x64.exe -Algorithm SHA256/);
assert.match(workflow, /if: always\(\)[\s\S]*name: verify-reconnect-/);
for (const signal of ['reposition_lines', 'focus_changed', 'session_gone_count', 'attempts_after_gone']) assert.ok(drive.includes(signal), signal);
assert.match(drive, /\\\[reposition\\\]\|posBrowser\|posMasks/);
assert.match(drive, /\$reposition -eq 0 -and !\$changed/);
assert.match(drive, /\$goneCount -eq 1 -and \$attempts -eq 0/);
assert.match(drive, /\$observationTimer = \[Diagnostics\.Stopwatch\]::StartNew\(\)/);
assert.match(drive, /Start-Sleep -Seconds 60/);
assert.match(drive, /while \(\$observationTimer\.Elapsed\.TotalSeconds -lt 60\) \{ Start-Sleep -Milliseconds 10 \}/);
assert.match(drive, /\$observeSeconds = \$observationTimer\.Elapsed\.TotalSeconds/);
assert.match(drive, /ssh-reconnect attempt=/);
assert.match(drive, /ssh-reconnect ended id=/);
assert.ok(drive.includes('respawnShellInPlace ok kind=tmux idx=1 (?:new_id|id)='));
assert.match(drive, /ssh-path\.txt/);
assert.match(drive, /\$process -and \$process\.Path -eq \$Ssh/);
assert.match(drive, /transport_paths=@\(\(Transport 'verify-one'\)\.Path, \(Transport 'verify-two'\)\.Path\)/);
assert.doesNotMatch(drive, /\$text\.Contains\("ssh: selected working executable:/);
assert.match(drive, /chat_view_mode='nowhere'/);
assert.match(desktop, /Class\(h\)=="ConsoleWindowClass"/);
assert.match(desktop, /GetForegroundWindow/);
assert.match(desktop, /GetGUIThreadInfo/);
assert.match(desktop, /SendInput/);
assert.match(desktop, /void Activate\(IntPtr h\) \{ Key\(0x12,false\); Key\(0x12,true\); if\(!SetForegroundWindow\(h\)\) throw/);
assert.match(read('src/chat_send.zig'), /@import\("focus\.zig"\)\.ShowWindow\(shell\.hwnd/);
assert.doesNotMatch(drive, /Stop-Process -Name|taskkill \/IM/i);
assert.match(drive, /remaining_owned_processes/);
const skill = read('.claude/skills/verify-multiprompt/SKILL.md');
assert.match(skill, /^---\nname: verify-multiprompt\ndescription:/);
for (const section of ['Launch', 'Doctor', 'Drive', 'Evidence', 'Cleanup', 'Maintain']) assert.ok(skill.includes(`## ${section}`));
assert.match(skill, /never runs on the Linux server/);
assert.match(skill, /\.github\/workflows\/verify-reconnect\.yml/);
assert.match(skill, /tools\/verify-reconnect\//);
const baseline = ['browser-pane-stuck.md', 'appearance.md', 'command-palette.md', 'inbox.md', 'session-open.md', 'sessions.md', 'workspaces.md'];
const reconnect = ['ended-remote-session.md', 'saved-remote-workspace.md', 'ssh-tab-reconnect.md'];
const features = fs.readdirSync(path.join(root, '.claude/skills/verify-multiprompt/features')).filter(f => f.endsWith('.md') && f !== 'README.md');
for (const file of [...baseline, ...reconnect]) assert.ok(features.includes(file), `required feature: ${file}`);
const index = read('.claude/skills/verify-multiprompt/features/README.md');
for (const file of features) {
  assert.ok(index.includes(`](${file})`), file);
  assert.deepEqual(read(`.claude/skills/verify-multiprompt/features/${file}`).match(/^## .+$/gm), [
    '## Sub-features', '## How to get to it (user POV)',
    reconnect.includes(file) ? '## Driving it with the Windows reconnect harness' : '## Driving it with control.ps1',
    '## Gotchas',
  ]);
}
console.log('reconnect verification source checks passed');
