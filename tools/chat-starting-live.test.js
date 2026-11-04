const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || process.cwd();
const live = fs.readFileSync(path.join(root, 'src/chat_live.zig'), 'utf8');
const palette = fs.readFileSync(path.join(root, 'src/command_palette.zig'), 'utf8');

function section(source, start, end) {
  const a = source.indexOf(start);
  const b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `${start} not found`);
  return source.slice(a, b);
}

test('new live chat starts working before opening its view', () => {
  const spawn = section(palette, 'fn spawnWorkspaceSessionAt(', 'fn workspaceFolderForNewChat(');
  assert.match(spawn, /g_pending_chat_view = false/);
  assert.ok(spawn.indexOf('.starting(') > 0);
  assert.ok(spawn.indexOf('.starting(') < spawn.indexOf('.openChatView()'));
  assert.ok(spawn.indexOf('g_chat_screen_working =') > spawn.indexOf('.openChatView()'));
});

test('first subscription keeps starting state and ready respects real turns', () => {
  const begin = section(live, 'pub fn begin(', 'pub fn release(');
  assert.doesNotMatch(begin, /live\.clear/);
  const start = section(live, 'pub fn starting(', 'pub fn begin(');
  assert.match(start, /claim\(/);
  assert.match(start, /\.state = \.running/);
  const ready = live.match(/"ready"\) and (self\.turn_len == 0 and self\.state == \.running)/);
  assert.ok(ready);
  const condition = ready[1].replaceAll('self.turn_len', 'turnLen').replaceAll('self.state', 'state')
    .replaceAll(' and ', ' && ').replace('.running', "'running'");
  const becomesIdle = Function('turnLen', 'state', `return ${condition}`);
  assert.equal(becomesIdle(0, 'running'), true);
  assert.equal(becomesIdle(3, 'running'), false);
  assert.equal(becomesIdle(0, 'idle'), false);
});

test('startup failure survives history catch-up and replay', () => {
  const catchup = section(live, 'pub fn historyCaughtUp(', 'pub fn approvalMenu(');
  assert.match(catchup, /startup-failure/);
  assert.match(live, /test "IGSH-1593 startup failure survives empty history and replay"/);
});
