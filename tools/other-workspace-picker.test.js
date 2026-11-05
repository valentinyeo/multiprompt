const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const sessions = fs.readFileSync('.claude/skills/verify-multiprompt/control-feature-sessions.ps1', 'utf8');

test('IGSH-1527 Other has an app-saved default before two real picker selections', () => {
  const start = sessions.indexOf("'Other active before saving its folder'");
  const end = sessions.indexOf('$workspaceCount =', start);
  assert.ok(start >= 0 && end > start);
  const journey = sessions.slice(start, end);
  assert.match(journey, /Palette 'set workspace folder'[\s\S]*Type-Text 'notes-only'[\s\S]*\$_.workspace -eq 'Other'[\s\S]*\$_.cwd -eq '\/work\/projects\/notes-only'[\s\S]*\$_.default/);
  assert.match(journey, /foreach \(\$repo in @\('beta', 'zz-last-folder'\)\)[\s\S]*Ctrl\+T: Other must ask despite its saved default[\s\S]*Type-Text \$repo[\s\S]*Snapshot \('other-saved-default-' \+ \$repo \+ '-picker'\)[\s\S]*Enter: choose a different repo in Other/);
  assert.match(journey, /\$beforeOther \+ 1[\s\S]*\$tab.cwd -eq \('\/work\/projects\/' \+ \$repo\) -and \$tab.cv -eq \$true -and \$tab.tmux_host -eq 2/);
  assert.doesNotMatch(journey, /WriteAllText|Set-Content|commands\.json.*\|.*Out-File/);
});

test('IGSH-1527 a new non-Other workspace saves its folder through the palette', () => {
  const start = sessions.indexOf('$workspaceCount =');
  assert.ok(start >= 0);
  const journey = sessions.slice(start);
  assert.match(journey, /Ctrl\+N: create a named workspace[\s\S]*\$workspaceCount \+ 1[\s\S]*\$namedWorkspace -eq 'Other'[\s\S]*Palette 'set workspace folder'[\s\S]*named workspace folder row is ready[\s\S]*\$_.workspace -eq \$namedWorkspace[\s\S]*\$_.default/);
  assert.doesNotMatch(journey, /WriteAllText|Set-Content/);
});

test('IGSH-1527 the named workspace launches without another repo selection', () => {
  const start = sessions.indexOf("Snapshot 'named-workspace-saved-default-before'");
  const end = sessions.indexOf("'named workspace proof chat closed'", start);
  assert.ok(start >= 0 && end > start);
  const journey = sessions.slice(start, end);
  assert.match(journey, /Ctrl\+T: named workspace starts directly in its saved folder[\s\S]*\$beforeNamed \+ 1[\s\S]*\$state.active_workspace -ne \$namedSlot[\s\S]*\$tab.cwd -eq '\/work\/projects\/notes-only' -and \$tab.cv -eq \$true[\s\S]*named workspace starts a chat without selecting a repo[\s\S]*Snapshot 'named-workspace-saved-default-chat'/);
  assert.doesNotMatch(journey, /Type-Text|0x0D|catch|fallback/);
});
