const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const control = fs.readFileSync(path.join(__dirname, '../.claude/skills/verify-multiprompt/control-feature-chat-tables.ps1'), 'utf8');

test('IGSH-1897 the chat-tables check treats a tab with no saved cv as terminal view', () => {
  assert.doesNotMatch(control, /tabs\[\$tableTab\]\.cv/, 'a saved tab only writes cv when Chat View is on, so a bare read throws instead of retrying');
  assert.match(control, /function Test-TableTabChat\(\[int\]\$index\) \{/);
  assert.match(control, /return \[bool\]\(\$tab\.PSObject\.Properties\['cv'\] -and \$tab\.cv\)/);
  assert.equal(control.match(/Test-TableTabChat \$tableTab/g)?.length, 4, 'every table tab state read goes through the guard');
});

test('IGSH-1897 the check keeps its wide table inside the 100 column console', () => {
  const wide = control.slice(control.indexOf('$rows = @('), control.indexOf('function Border('));
  const rows = [...wide.matchAll(/^\s+@\('([^']*)', '([^']*)', '([^']*)', '([^']*)'\),?$/gm)].map(match => match.slice(1, 5));
  assert.equal(rows.length, 5, 'one header row and four data rows');
  const widths = [0, 1, 2, 3].map(column => Math.max(...rows.map(row => row[column].length)));
  const lineWidth = widths.reduce((sum, width) => sum + width, 0) + 4 * 3 + 5;
  assert.ok(lineWidth > 76, `wide table is ${lineWidth} columns; the 523 px message block shows about 75 at the chat code font`);
  assert.ok(lineWidth <= 96, `wide table is ${lineWidth} columns; the console holds 100, so anything wider wraps and Chat View cannot see a table`);
  assert.match(wide, /-gt 96\) \{ throw 'Wide table does not fit the 100 column console' \}/);
});
