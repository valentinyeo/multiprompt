const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

test('live chat journey runs the shipped selftest and verifies every step and the hosting chat', () => {
  const file = path.join(__dirname, '../.claude/skills/verify-multiprompt/control-feature-live-chat-pane.ps1');
  assert.ok(fs.existsSync(file), 'live chat pane journey exists');
  const driver = fs.readFileSync(file, 'utf8');
  assert.match(driver, /tools\/vps-multiprompt-browser\.sh/);
  assert.match(driver, /\$selftestJob\.Start\(\$bash, \(Split-Path \$bash\)/);
  assert.match(driver, /\$env:ZSB_SESSION = \$one\.tmux/);
  assert.match(driver, /\$env:ZSB_PORT = \[string\]\$relay\.port/);
  assert.match(driver, /--app-port ' \+ \$script:liveChatPort/);
  assert.match(driver, /\$selftest\.ok -ne \$true/);
  assert.match(driver, /\$selftest\.session -cne \$one\.tmux/);
  assert.match(driver, /\$selftest\.tab_name -cne \$one\.name/);
  for (const step of ['open', 'text', 'type', 'click', 'screenshot', 'hosting', 'close']) {
    assert.ok(driver.includes(`'${step}'`), `requires ${step} selftest evidence`);
  }
  assert.match(driver, /\$selftest\.steps\.\$step\.pass -ne \$true/);
  assert.match(driver, /Snapshot 'chat-one-selftest'/);
  const selection = driver.slice(driver.indexOf('$selectChat = {'), driver.indexOf('& $selectChat $two'));
  assert.ok(selection.includes('switchToShell: \\d+ -> (\\d+)'));
  assert.match(selection, /\$Chat\.index/);
  assert.doesNotMatch(selection, /Read-Inbox|active_shell_id/);
  assert.match(driver, /Wait-Until \{\s*\$current = Invoke-Zsb @\('tabs'\)[\s\S]*?\$oneOtherWant[\s\S]*?\$_.title -ceq \(\$one.marker \+ ' second'\)[\s\S]*?second page loaded in its own pane' 25/);
  assert.match(driver, /http\.server[^\n]+, \$true\)/);
  assert.match(driver, /\$wrapper \+ '" selftest'\), \$true\)/);
  const native = fs.readFileSync(path.join(path.dirname(file), 'control-native.cs'), 'utf8');
  assert.match(native, /4u \| \(noWindow \? 0x08000000u : 0u\)/);
  assert.match(native, /return Start\(exe, directory, stdout, stderr, arguments, false\)/);
});

test('live chat journey holds agent calls on a background chat without touching the user view', () => {
  const root = path.join(__dirname, '../.claude/skills/verify-multiprompt');
  const driver = fs.readFileSync(path.join(root, 'control-feature-live-chat-pane.ps1'), 'utf8');
  assert.match(driver, /\$env:AGENT_SOAK_SECONDS/);
  assert.match(driver, /AGENT_SOAK_SECONDS must be a whole number of seconds/);
  assert.match(driver, /Invoke-Zsb @\('status'\) \$script:liveChatPort \('soak-status-' \+ \$soakRounds\) -Session \$two\.tmux/);
  assert.match(driver, /\$soakStatus\.pane -cne 'open' -or \$soakStatus\.windowId -ne \$soakHiddenWindow/);
  assert.match(driver, /change the hidden chat pane|changed the hidden chat pane/);
  assert.match(driver, /switched the visible tab/);
  assert.match(driver, /switchToShell:/);
  assert.match(driver, /if \(-not \[VerifyNative\]::PaneVisible\(\$script:window\)\) \{ throw \('Agent call '/);
  assert.match(driver, /Save-Json \$soakEvidence 'chat-two-background-soak\.json'/);
  assert.doesNotMatch(driver.slice(driver.indexOf('$soakTimer = [Diagnostics.Stopwatch]::StartNew()'), driver.indexOf("Snapshot 'chat-two-background-soak'")), /Press |Type-Text |ClickClient/);
  const workflow = fs.readFileSync(path.join(__dirname, '../.github/workflows/verify.yml'), 'utf8');
  assert.match(workflow, /AGENT_SOAK_SECONDS: \$\{\{ matrix\.feature == 'live-chat-pane' && '1200' \|\| '' \}\}/);
  assert.match(workflow, /matrix\.feature == 'live-chat-pane' && 75/);
  assert.match(workflow, /timeout-minutes: \$\{\{ env\.FEATURE == 'live-chat-pane' && 60 \|\| 30 \}\}/);
  const docs = fs.readFileSync(path.join(root, 'features/live-chat-pane.md'), 'utf8');
  assert.match(docs, /`chat-two-background-soak`/);
  assert.match(docs, /every 30 seconds for `AGENT_SOAK_SECONDS`/);
});

test('live chat routing preserves the shared workspace default and uses the real browser setup', () => {
  const root = path.join(__dirname, '../.claude/skills/verify-multiprompt');
  const control = fs.readFileSync(path.join(root, 'control.ps1'), 'utf8');
  const library = fs.readFileSync(path.join(root, 'control-library.ps1'), 'utf8');
  assert.match(control, /'live-chat-pane' \{\s*\. \(Join-Path \$PSScriptRoot 'control-feature-live-chat-pane\.ps1'\)/);
  assert.match(control, /if \(\$Feature -in @\('browser-switch-speed', 'chat-switch-speed', 'browser-own-profile', 'live-chat-pane'\)\)/);
  assert.match(library, /\[string\]\$Session = 'workspace'/);
  assert.ok(library.includes('[Text.Encoding]::UTF8.GetBytes("ZSB:${Session}:${payload}`n")'));
});
