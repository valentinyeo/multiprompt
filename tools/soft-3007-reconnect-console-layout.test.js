import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import test from 'node:test';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = rel => readFileSync(join(root, rel), 'utf8');
function body(name, source) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  const end = source.indexOf('\n}', start);
  assert.ok(end > start, name);
  return source.slice(start, end + 2);
}

test('SOFT-3007 reconnect layout stays allowed while saved tabs are still restoring', () => {
  const drawing = read('src/drawing.zig');
  assert.match(drawing, /pub fn reconnectConsoleLayoutAllowed/);
  assert.match(drawing, /pub fn reconnectTabVisible/);
  assert.match(drawing, /reconnectConsolePlacementAllowed\(idx\) and !app_state\.g_restoring/);
  assert.doesNotMatch(body('reconnectConsoleLayoutAllowed', drawing), /g_restoring/);
});

test('SOFT-3007 respawn sizing syncs conhost geometry and terminal rows before show', () => {
  const console = read('src/console.zig');
  assert.match(console, /pub fn layoutReconnectedConsole/);
  assert.match(body('layoutReconnectedConsole', console), /reconnectConsoleLayoutAllowed/);
  assert.match(body('positionReconnectedConsole', console), /finalizeReconnectedConsoleLayout/);
  assert.match(body('finalizeReconnectedConsoleLayout', console), /verifyShellWindowSize/);
  assert.match(body('finalizeReconnectedConsoleLayout', console), /normalizeConsoleFont/);
  assert.doesNotMatch(body('positionReconnectedConsole', console), /reconnectTabVisible/);
  const complete = body('finishStartupShell', console);
  assert.match(complete, /layoutReconnectedConsole\(idx\)/);
  assert.match(complete, /startup-reconnect-ready/);
});

test('SOFT-3007 adopting tmux on the active tab relayouts the hosted console', () => {
  const poll = read('src/shell_poll.zig');
  const marker = 'pollShellNames: tmux adopted, session=';
  const adopt = poll.slice(poll.indexOf(marker), poll.indexOf(marker) + 420);
  assert.match(adopt, /if \(i == app_state\.active_shell\) repositionActive\(\)/);
});