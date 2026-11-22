const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

const body = (source, name, next) => {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `${name} must exist`);
  const end = source.indexOf(`\nfn ${next}(`, start);
  return source.slice(start, end > start ? end : start + 4000);
};

test('IGSH-1266 a declared workspace folder is enough to offer the agent chats', () => {
  const palette = read('src/command_palette.zig');
  const helper = body(palette, 'workspaceFolderForNewChat', 'activeRemoteContextForCodexTmux');
  assert.match(helper, /activeRemoteContextForCodexTmux\(out_host, out_path, out_len\)/, 'a focused remote tab still wins');
  assert.match(helper, /workspaceConfiguredTerminalFolder\(activeWorkspaceSlot\(\)/, 'the declared workspace folder is the fallback');
  assert.match(helper, /remotePathSafeForShell\(out_path\[0\.\.out_len\.\*\]\)/, 'the declared folder is still validated');

  assert.match(palette, /const remote_folder = workspaceFolderForNewChat\(&host, &cwd_buf, &cwd_len\);/, 'the rows use the shared folder rule');
  assert.ok(!/const remote_folder = activeRemoteContextForCodexTmux\(/.test(palette), 'the rows must not require a focused remote tab');
  assert.match(body(palette, 'spawnHostedChatSession', 'spawnCodexTmuxSession'), /spawnHostedChatSession\(\.codex\)/, 'New Codex chat spawns through the hosted chat');
  assert.match(body(palette, 'spawnPiTmuxSession', 'clampSearchSelectionAndScroll'), /spawnHostedChatSession\(\.pi\)/, 'New Pi chat spawns in the declared folder through the hosted chat');
});
