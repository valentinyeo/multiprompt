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

test('SOFT-2380 the open workspace card handles keys before global shortcuts', () => {
  const shortcuts = read('src/shortcuts.zig');
  const hook = shortcuts.slice(shortcuts.indexOf('pub fn keyboardHookProc('));
  const card = hook.indexOf('if (key_down and foregroundIsOurs() and @import("workspace_switcher.zig").isOpen())');
  const global = hook.indexOf('sessionCloseShortcut(kb.vkCode');
  assert.ok(card >= 0 && global > card, 'route actual key presses to the open card before other app actions');
  assert.match(hook.slice(card, global), /0x1B, 0x26, 0x28, 0x0D, 0x20 => \{\s+_ = PostMessageW\(app_state.g_main_hwnd, WM_KEYDOWN, kb.vkCode, 0\);\s+return 1;/);
  assert.match(body('isOpen'), /return opened;/);
  const journey = read('.claude/skills/verify-multiprompt/workspace-switcher.ps1');
  assert.match(journey, /'Enter activates arrow-selected workspace'/);
});

test('SOFT-2380 the workspace journey owns foreground input and creates an undeleted archive fixture', () => {
  const journey = read('.claude/skills/verify-multiprompt/workspace-switcher.ps1');
  assert.match(journey, /function Open-WorkspaceCard\(\[string\]\$Shot\) \{\s+Doctor\s+\[VerifyNative\]::BringToForeground\(\$script:window\)\s+Wait-Until \{ \[VerifyNative\]::GetForegroundWindow\(\) -eq \$script:window \}/);
  const deletion = journey.indexOf("Delete-WorkspaceFixture 'CEO Runners' $false");
  const create = journey.indexOf("'Ctrl+N: create a separate workspace for archive and restore'");
  const archive = journey.indexOf("Select-WorkspaceCard $created 'archive-before'");
  assert.ok(deletion >= 0 && create > deletion && archive > create);
  assert.match(journey.slice(create, archive), /workspace_count -eq \$beforeArchiveCreate \+ 1/);
  assert.match(journey.slice(create, archive), /\$created = \(Read-Session\)\.active_workspace/);
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
