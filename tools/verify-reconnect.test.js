const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const workflow = read('.github/workflows/verify-reconnect.yml');
const drive = read('tools/verify-reconnect/drive.ps1');
const desktop = read('tools/verify-reconnect/desktop.cs');
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
assert.match(drive, /Start-Sleep -Seconds 60/);
assert.match(drive, /ssh-reconnect attempt=/);
assert.match(drive, /ssh-reconnect ended id=/);
assert.match(drive, /respawnShellInPlace ok kind=tmux idx=1 new_id=/);
assert.match(drive, /ssh-path\.txt/);
assert.match(desktop, /GetForegroundWindow/);
assert.match(desktop, /GetGUIThreadInfo/);
assert.match(desktop, /SendInput/);
assert.doesNotMatch(drive, /Stop-Process -Name|taskkill \/IM/i);
assert.match(drive, /remaining_owned_processes/);
const skill = read('.claude/skills/verify-multiprompt/SKILL.md');
assert.match(skill, /^---\nname: verify-multiprompt\ndescription:/);
for (const section of ['Launch', 'Doctor', 'Drive', 'Evidence', 'Cleanup', 'Helpers']) assert.ok(skill.includes(`## ${section}`));
assert.match(skill, /never runs on the Linux server/);
const features = fs.readdirSync(path.join(root, '.claude/skills/verify-multiprompt/features')).filter(f => f !== 'README.md');
assert.ok(features.length >= 3 && features.length <= 5);
for (const file of features) {
  assert.deepEqual(read(`.claude/skills/verify-multiprompt/features/${file}`).match(/^## .+$/gm), [
    '## Sub-features', '## How to get to it (user POV)', '## Driving it with the Windows reconnect harness', '## Gotchas',
  ]);
}
console.log('reconnect verification source checks passed');
