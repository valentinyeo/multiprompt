const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

const body = (source, name) => {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `${name} must exist`);
  const next = source.slice(start + 1).search(/\n(?:pub )?fn /);
  return next < 0 ? source.slice(start) : source.slice(start, start + 1 + next);
};

test('IGSH-1527 the Other workspace never reuses a saved folder for a new session', () => {
  const folder = body(read('src/command_palette.zig'), 'workspaceConfiguredTerminalFolder');
  const refused = folder.indexOf('isOtherWorkspaceName(ws_name)');
  const lookup = folder.indexOf('folderEntryIndexFor(ws_name)');
  assert.ok(refused >= 0, 'the catch-all workspace must be refused by name');
  assert.ok(lookup >= 0, 'named workspaces still look up their saved folder');
  assert.ok(refused < lookup, 'the refusal must come before the saved folder is read');
  assert.match(folder.slice(refused, lookup), /return false/, 'the refusal must end the lookup');
});

test('IGSH-1527 every new session path asks through the shared folder rule', () => {
  const palette = read('src/command_palette.zig');
  assert.match(body(palette, 'spawnWorkspaceSession'), /workspaceConfiguredTerminalFolder\(workspace,/,
    'Ctrl+T, Alt+T, the palette new chat and the sidebar plus all start here');
  assert.match(body(palette, 'workspaceFolderForNewChat'), /workspaceConfiguredTerminalFolder\(activeWorkspaceSlot\(\)/);
});

test('IGSH-1527 the catch-all name predicate matches the workspace slot check', () => {
  const workspaces = read('src/workspaces.zig');
  const predicate = body(workspaces, 'isOtherWorkspaceName');
  assert.match(predicate, /eqlIgnoreCase\(name, OTHER_WORKSPACE_NAME\)/);
  assert.match(body(workspaces, 'isOtherWorkspaceSlot'), /isOtherWorkspaceName\(app_state\.g_ws_names\[ws\]\[0\.\.len\]\)/,
    'the slot check and the folder rule must share one definition of the catch-all');
});
