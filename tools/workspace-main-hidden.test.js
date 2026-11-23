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
  assert.match(journey, /function Get-WorkspaceCardRow\([\s\S]*?\$row = 3/);
  assert.match(journey, /\$expectedHeight = 19 \+ \(\$visibleCount \+ 4\) \* 28/);
  assert.match(journey, /\$newRow = \(Get-VisibleWorkspaceCardRows\) \+ 3/);
  assert.match(journey, /Get-WorkspaceCardRow \$Workspace/);
  assert.match(journey, /ClickOwnedChildClient\(\$card, \$script:window/);
  assert.match(journey, /function Dismiss-WorkspaceCard/);
  const native = read('.claude/skills/verify-multiprompt/control-native.cs');
  assert.match(native, /public static void ClickOwnedChildClient/);
  assert.match(native, /MultiPromptWorkspaceSwitcher/);
  assert.match(native, /MouseAt\(point\.X, point\.Y, 0\);\s+MouseAt\(point\.X, point\.Y, 2\);\s+MouseAt\(point\.X, point\.Y, 4\);/);
});

test('SOFT-2380 opening the workspace card gives its keyboard handler focus', () => {
  const open = body('headerClick');
  const show = open.indexOf('w.SWP_SHOWWINDOW');
  const focus = open.indexOf('focus.SetFocus(hwnd)', show);
  const capture = open.indexOf('w.SetCapture(hwnd)', show);
  assert.ok(show >= 0 && focus > show && capture > focus, 'show and focus the card before capturing mouse input');
  const journey = read('.claude/skills/verify-multiprompt/workspace-switcher.ps1');
  assert.match(journey, /GetFocusedWindow\(\$script:window\) -eq \$card/);
  assert.match(journey, /'Enter activates arrow-selected workspace'/);
});

test('IGSH-2281 an empty Main workspace stays out of the menu', () => {
  const empty = body('emptyHome');
  assert.match(empty, /eql\(u8, entry\.id\[0\.\.entry\.id_len\], "default"\)/);
  assert.match(empty, /!current\(index\)/);
  assert.match(empty, /sessionCount\(index\)/);
  const load = body('loadEntries');
  assert.match(load, /if \(entry\.archived\) continue;/);
  assert.match(empty, /entries\[index - views\.len\]/);
  assert.match(load, /if \(emptyHome\(entry_count \+ views\.len - 1\)\) entry_count -= 1;/);
  assert.match(body('headerClick'), /loadEntries\(\);/);
  assert.match(source, /test "IGSH-2281 workspace menu hides an empty Main"/);
});
