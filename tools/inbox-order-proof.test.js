const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..', '.claude/skills/verify-multiprompt');
const driver = fs.readFileSync(path.join(root, 'control-feature-inbox-order.ps1'), 'utf8');
const recipe = fs.readFileSync(path.join(root, 'features/inbox-order.md'), 'utf8');

test('notification targets only the owned production-range loopback listener', () => {
  assert.match(driver, /\$notifyPorts = @\(Get-NotifyPorts\)/);
  assert.match(driver, /Get-NetTCPConnection -State Listen -LocalAddress '127\.0\.0\.1'[^\n]+\$_.OwningProcess -eq \$process.Id -and \$_.LocalPort -in \$notifyPorts/g);
  assert.match(driver, /if \(\$listener.Count -ne 1\)/);
  assert.match(driver, /Save-Json @\{[^\n]*pid = \$process.Id; owningProcess = \$listener\[0\].OwningProcess; port = \$listener\[0\].LocalPort[^\n]*\} 'inbox-order-notification.json'/);
  assert.match(driver, /ConnectAsync\(\[Net.IPAddress\]::Loopback, \[int\]\$listener\[0\].LocalPort\)/);
  assert.match(driver, /\$connect.Wait\(5000\)/);
  assert.match(driver, /\$client.SendTimeout = 5000/);
  assert.match(driver, /GetBytes\('NOTIFICATION:Inbox Older'\)/);
  assert.match(driver, /\.Write\(\$bytes, 0, \$bytes.Length\)/);
  assert.match(driver, /finally \{ \$client.Dispose\(\) \}/);
  assert.doesNotMatch(driver, /Start-Process|--notify|Start-Sleep\b/);
});

test('captures depend on published activity and retain visual review', () => {
  assert.match(driver, /\$older.att -ne 1 -or \$newer.att -ne 0/);
  assert.match(driver, /\$afterOlder\[0\].att -ne 1 -or \$afterNewer\[0\].att -ne 0/);
  assert.match(driver, /\$row\[0\].la -gt \[long\]\$older.la/);
  assert.match(driver, /\$row\[0\].la -gt \[long\]\$other\[0\].la/);
  assert.match(driver, /\$row\[0\].la -gt \[long\]\$other\[0\].lv/);
  for (const stage of ['before', 'after']) {
    assert.match(driver, new RegExp(`Save-Json \\$${stage} 'inbox-order-${stage}\\.json'`));
    assert.match(driver, new RegExp(`Snapshot 'inbox-order-${stage}'`));
  }
  assert.match(driver, /Inbox visible for after capture/);
  assert.match(driver, /visualReviewRequired = \$true/);
  assert.match(recipe, /scripted local notification/);
  assert.match(recipe, /not a cloud message/);
  assert.match(recipe, /published release tag/);
});
