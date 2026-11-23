const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '..', 'src/workspace_switcher.zig'), 'utf8');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
function body(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `missing ${name}`);
  const end = source.indexOf('\n}', start);
  assert.ok(end > start, `unterminated ${name}`);
  return source.slice(start, end + 2);
}

test('IGSH-2281 workspace card rows skip the hidden empty Main', () => {
  const journey = read('.claude/skills/verify-multiprompt/workspace-switcher.ps1');
  assert.match(journey, /function Test-EmptyHomeCardRow/);
  assert.match(journey, /function Get-WorkspaceCardRow/);
  assert.match(journey, /Get-WorkspaceCardRow \$Workspace/);
  assert.match(journey, /ClickOwnedChildClient\(\$card, \$script:window/);
  assert.match(journey, /function Dismiss-WorkspaceCard/);
  const native = read('.claude/skills/verify-multiprompt/control-native.cs');
  assert.match(native, /public static void ClickOwnedChildClient/);
  assert.match(native, /MultiPromptWorkspaceSwitcher/);
  assert.match(native, /MouseAt\(point\.X, point\.Y, 0\);\s+MouseAt\(point\.X, point\.Y, 2\);\s+MouseAt\(point\.X, point\.Y, 4\);/);
});

test('IGSH-2281 an empty Main workspace stays out of the menu', () => {
  const empty = body('emptyHome');
  assert.match(empty, /eql\(u8, entry\.id\[0\.\.entry\.id_len\], "default"\)/);
  assert.match(empty, /!current\(index\)/);
  assert.match(empty, /sessionCount\(index\)/);
  const load = body('loadEntries');
  assert.match(load, /if \(entry\.archived\) continue;/);
  assert.match(load, /if \(emptyHome\(entry_count\)\) entry_count -= 1;/);
  assert.match(body('headerClick'), /loadEntries\(\);/);
  assert.match(source, /test "IGSH-2281 workspace menu hides an empty Main"/);
});
