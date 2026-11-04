const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

test('live chat journey runs the shipped selftest and verifies every step and the hosting chat', () => {
  const file = path.join(__dirname, '../.claude/skills/verify-multiprompt/control-feature-live-chat-pane.ps1');
  assert.ok(fs.existsSync(file), 'live chat pane journey exists');
  const driver = fs.readFileSync(file, 'utf8');
  assert.match(driver, /tools\/vps-multiprompt-browser\.sh selftest/);
  assert.match(driver, /\$env:ZSB_SESSION = \$one\.tmux/);
  assert.match(driver, /\$env:ZSB_PORT = \[string\]\$script:liveChatPort/);
  assert.match(driver, /\$selftest\.ok -ne \$true/);
  assert.match(driver, /\$selftest\.session -cne \$one\.tmux/);
  assert.match(driver, /\$selftest\.tab_name -cne \$one\.name/);
  for (const step of ['open', 'text', 'type', 'click', 'screenshot', 'hosting', 'close']) {
    assert.ok(driver.includes(`'${step}'`), `requires ${step} selftest evidence`);
  }
  assert.match(driver, /\$selftest\.steps\.\$step\.pass -ne \$true/);
  assert.match(driver, /Snapshot 'chat-one-selftest'/);
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
