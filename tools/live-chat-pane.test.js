const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const driver = fs.readFileSync(path.join(__dirname, '../.claude/skills/verify-multiprompt/control-feature-live-chat-pane.ps1'), 'utf8');

test('live chat journey runs the shipped selftest and verifies every step and the hosting chat', () => {
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
