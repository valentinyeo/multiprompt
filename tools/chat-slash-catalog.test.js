'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

const root = path.join(__dirname, '..');
test.beforeEach(() => assert.ok(fs.existsSync(path.join(root, 'src/chat_slash.zig')), 'live slash routing module exists'));

test('slash routing covers the interactive builtins catalog', () => {
  const catalog = fs.readFileSync(path.join(root, 'tools/agent-notifications/claude_interactive_builtins.tsv'), 'utf8');
  const source = fs.readFileSync(path.join(root, 'src/chat_slash.zig'), 'utf8');
  const commands = catalog.trim().split(/\r?\n/).map(line => line.split('\t')[0].slice(1));
  for (const command of commands) {
    assert.ok(source.includes(`"${command}"`), `missing /${command}`);
  }
});

test('live commands are routed before the outbox and keep the draft on refusal', () => {
  const source = fs.readFileSync(path.join(root, 'src/chat_send.zig'), 'utf8');
  const send = source.slice(source.indexOf('pub fn sendChatPrompt()'), source.indexOf('pub fn chatSendChoice('));
  assert.ok(send.indexOf('.decideForAgent(live, shell.ai_agent, text') < send.indexOf('chatEchoEnqueueForShell('));
  assert.match(send, /\.plan, \.permissions => \{\s*chatModeOpenPicker\(route == \.plan\);\s*return;/);
  assert.match(send, /\.unavailable => \{\s*showHeaderNoticeAscii\("Not available in live chat"[^]*?return;/);
  assert.match(send, /\.model => \{\s*if \(shell\.ai_agent == 3\) \{\s*chatPiModelPicker\(\);\s*\} else if \(shell\.ai_agent == 8\) \{\s*clearChatModelCommand\(\);\s*@import\("plus_menu\.zig"\)\.open\(\);\s*\} else \{\s*showHeaderNoticeAscii\("Model picker is coming soon"[^]*?return;/);
  const finish = source.slice(source.indexOf('pub fn chatModeFinish('), source.indexOf('fn chatModeOpenPicker('));
  assert.ok(finish.indexOf('if (!job.ok)') < finish.indexOf('SetWindowTextW('));
  assert.match(finish, /std\.meta\.eql\(job\.key, chatFileIdentityForShell\(app_state\.active_shell\)\)/);
});

test('antigravity model routes to the plus menu and its skills still send', () => {
  const slash = fs.readFileSync(path.join(root, 'src/chat_slash.zig'), 'utf8');
  const decide = slash.slice(slash.indexOf('pub fn decideForAgent('), slash.indexOf('fn equals('));
  assert.match(decide, /if \(ai_agent != 8\) return decide\(live, text, selected_skill, interactive_hint\);/);
  assert.match(decide, /if \(!live or selected_skill\) return \.send;/);
  assert.match(decide, /return if \(route\(true, text\) == \.model\) \.model else \.send;/);
  const send = fs.readFileSync(path.join(root, 'src/chat_send.zig'), 'utf8');
  const model = send.slice(send.indexOf('.model => {'), send.indexOf('.login => {'));
  assert.ok(model.indexOf('chatPiModelPicker()') < model.indexOf('shell.ai_agent == 8'), 'the Pi picker keeps its own branch');
  assert.ok(model.indexOf('shell.ai_agent == 8') < model.indexOf('plus_menu.zig'), 'the plus menu opens from the Antigravity branch');
  assert.match(model, /clearChatModelCommand\(\);\s*@import\("plus_menu\.zig"\)\.open\(\);/);
  assert.ok(model.indexOf('plus_menu.zig') < model.indexOf('Model picker is coming soon'), 'other chats keep the coming-soon notice');
});

test('command notices keep the title within the space beside the notice', () => {
  const source = fs.readFileSync(path.join(root, 'src/drawing.zig'), 'utf8');
  const layout = source.slice(source.indexOf('pub fn chatTitleLayout('), source.indexOf('fn paintMoreButton('));
  assert.match(layout, /const max_w = right_limit - column\.left - margin;/);
  assert.match(layout, /std\.math\.clamp\(center - @divTrunc\(width, 2\), column\.left \+ margin, right_limit - width\)/);
});

test('new picker targets and completion message avoid registered bands', async () => {
  const { checkRouting } = await import(pathToFileURL(path.join(root, 'tools/check-routing-ids.mjs')).href);
  const sources = {};
  function collect(directory) {
    for (const entry of fs.readdirSync(path.join(root, directory), { withFileTypes: true })) {
      const file = path.join(directory, entry.name);
      if (entry.isDirectory()) collect(file);
      else if (entry.isFile() && file.endsWith('.zig')) sources[file] = fs.readFileSync(path.join(root, file), 'utf8');
    }
  }
  collect('src');
  const bands = JSON.parse(fs.readFileSync(path.join(root, 'tools/routing-id-bands.json'), 'utf8'));
  assert.deepEqual(checkRouting(sources, bands).errors, []);
});

test('mode choices use host supported values and require a reply', () => {
  const reader = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');
  const slash = fs.readFileSync(path.join(root, 'src/chat_slash.zig'), 'utf8');
  const send = fs.readFileSync(path.join(root, 'src/chat_send.zig'), 'utf8');
  const modes = reader.match(/HOST_PERMISSION_MODES = \(([^\n]+)\)/)[1];
  for (const mode of ['manual', 'acceptEdits', 'plan']) {
    assert.ok(modes.includes(`'${mode}'`));
    assert.ok(slash.includes(mode));
  }
  assert.doesNotMatch(slash.match(/pub const PermissionMode = enum \{([^}]+)\}/)[1], /\bdefault\b/);
  const worker = send.slice(send.indexOf('fn chatModeThread('), send.indexOf('fn chatModePostResult('));
  assert.match(worker, /chatHistoryPersistent\(identity, request/);
  assert.match(worker, /modeReplyOk\(a, response\.items\)/);
  assert.match(worker, /modeRequest\(a, job\.key\.shell_id, job\.key\.provider\(\)/);
  assert.match(send, /std\.Thread\.spawn\(\.\{\}, chatModeThread/);
});
