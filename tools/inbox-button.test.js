const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const inbox = fs.readFileSync('src/inbox.zig', 'utf8');
const browser = fs.readFileSync('src/browser_pane.zig', 'utf8');
const sidebar = fs.readFileSync('src/sidebar.zig', 'utf8');

test('Inbox does not paint or reserve space for its button', () => {
  assert.doesNotMatch(inbox, /paintInboxButton(?:Tooltip)?/);
  assert.match(inbox, /const tabs_left = layout\.left;/);
});

test('Inbox button hit testing is disabled while open and restored on close', () => {
  const start = browser.indexOf('pub fn inboxButtonHitTest(');
  const end = browser.indexOf('\npub fn ', start + 1);
  assert.ok(start >= 0 && end > start);
  const hitTest = browser.slice(start, end);
  assert.match(hitTest, /if \(app_state\.g_inbox_active or !app_state\.g_single_window or app_state\.g_sidebar_collapsed or app_state\.g_hide_sidebar or app_state\.g_hide_pills\) return false;/);
  assert.match(hitTest, /inboxButtonRect\(false\)/);
  assert.match(sidebar, /g_inbox_active = true;\s*try std\.testing\.expect\(!inboxButtonHitTest\(inboxButtonRect\(true\)\.left, WS_PILL_TOP\)\);\s*app_state\.g_inbox_active = false;\s*try std\.testing\.expect\(inboxButtonHitTest\(button\.left, WS_PILL_TOP\)\);/);
});

test('Windows proof restores the workspace strip through the real palette before measuring its button', () => {
  const journey = fs.readFileSync('.claude/skills/verify-multiprompt/control-feature-inbox.ps1', 'utf8');
  assert.match(journey, /if \(\(Read-Session\)\.hide_pills\) \{/);
  assert.match(journey, /Focus-Palette 'workspace switcher' 6213/);
  assert.ok(journey.indexOf("'workspace switcher shown and saved for Inbox button proof'") < journey.indexOf("foreach ($theme in @('light', 'amoled'))"));
  for (const state of ['closed', 'open', 'returned']) assert.ok(journey.includes(`Snapshot "inbox-button-$theme-${state}"`));
  assert.match(journey, /\$counts\.open -ne 0 -or \$counts\.closed -lt 4/);
});

test('Windows verification uses the production target and retains early exit diagnostics', () => {
  const workflow = fs.readFileSync('.github/workflows/verify.yml', 'utf8');
  const sharedBuild = workflow.slice(workflow.indexOf('- name: Build the Windows app once for this push'), workflow.indexOf('  reopen-board-contract:'));
  assert.match(sharedBuild, /zig build[^\r\n]* -Dtarget=x86_64-windows-gnu(?:\s|$)/);
  assert.match(sharedBuild, /zig build[^\r\n]* -Drelease=false(?:\s|$)/);
  const library = fs.readFileSync('.claude/skills/verify-multiprompt/control-library.ps1', 'utf8');
  assert.ok(library.includes('App exited with code $($process.ExitCode) while waiting for $Description'));
});
