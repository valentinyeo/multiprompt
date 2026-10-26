const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const drive = fs.readFileSync(path.join(__dirname, 'verify-chat-delivery', 'drive.ps1'), 'utf8');
const retention = drive.slice(drive.indexOf('function Assert-Retention'), drive.indexOf('foreach ($plan in $plans)'));
const loop = retention.slice(retention.indexOf('for ($burst = 1;'), retention.indexOf("Shot 'retention-after'"));

test('IGSH-981 each burst paints before the text-size measurement runs', () => {
  const lines = loop.split(/\r?\n/).map(line => line.trim());
  const at = pattern => lines.findIndex(line => pattern.test(line));
  const mark = at(/^\$burstStart = \(Read-Shared "\$settings\/debug\.log"\)\.Length$/);
  const send = at(/^Shell-Run @\('retention-burst', '20'\)$/);
  const painted = at(/^\[void\]\(Wait-For .*Substring\(\$burstStart\) -match \('PERF\\\[chat\\\]: receive to paint ms=\\d\+ size=' \+ \(2000 \+ \$burst \* 20\) \+ '\(\?!\\d\)'\)/);
  const measure = at(/^Retention-Copy "burst-\$burst"/);
  assert.ok(mark >= 0 && send >= 0 && painted >= 0 && measure >= 0, 'burst loop lost a step');
  assert.ok(mark < send && send < painted && painted < measure, 'text-size measurement must follow the arrival paint line');
});

test('IGSH-981 only Retention-Copy presses the text-size key', () => {
  const presses = retention.match(/Ctrl\+0/g) || [];
  assert.equal(presses.length, 0, 'Assert-Retention must not press Ctrl+0 itself');
  const copy = drive.slice(drive.indexOf('function Retention-Copy'), drive.indexOf('function Retention-Top'));
  assert.equal((copy.match(/Ctrl\+0/g) || []).length, 1);
  assert.ok(!/retention-burst/.test(copy));
});
