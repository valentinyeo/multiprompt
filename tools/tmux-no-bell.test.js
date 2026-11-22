'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const python = process.platform === 'win32' ? 'python' : 'python3';

function snippet() {
  const result = spawnSync(python, ['-c', [
    'import sys',
    'from pathlib import Path',
    'sys.path.insert(0, sys.argv[1])',
    'import install',
    'sys.stdout.write(install.tmux_config(Path("/tmp/mp-notify-test/tmux-events")))',
  ].join('\n'), path.join(root, 'tools/agent-notifications')], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.split('\n');
}

test('tmux activity alerts never ring the terminal bell on remote tabs', () => {
  const lines = snippet();
  assert.ok(lines.includes('set-option -g activity-action any'), 'activity hooks still fire');
  assert.ok(lines.includes('set-option -g visual-activity off'), 'tmux still sends BEL for activity alerts');
  const overrides = lines.filter((line) => line.includes('terminal-overrides'));
  assert.deepEqual(overrides, ["set-option -s terminal-overrides[514] '*:bel@'"], 'bell capability removed once, at a fixed index');
});
