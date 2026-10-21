const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const { spawnSync } = require('node:child_process');

const message = 'runs on GitHub Actions only; push and read gh pr checks, or set MULTIPROMPT_ALLOW_LOCAL_HEAVY=1 on a machine you own';
const entries = ['test-windows-wine.sh', 'chat-bench/run.mjs'];
const denied = [{}, { GITHUB_ACTIONS: '', MULTIPROMPT_ALLOW_LOCAL_HEAVY: '' }, { GITHUB_ACTIONS: 'false', MULTIPROMPT_ALLOW_LOCAL_HEAVY: 'true' }, { GITHUB_ACTIONS: '1', MULTIPROMPT_ALLOW_LOCAL_HEAVY: '0' }];
const allowed = [{ GITHUB_ACTIONS: 'true' }, { MULTIPROMPT_ALLOW_LOCAL_HEAVY: '1' }, { GITHUB_ACTIONS: 'false', MULTIPROMPT_ALLOW_LOCAL_HEAVY: '1' }, { GITHUB_ACTIONS: 'true', MULTIPROMPT_ALLOW_LOCAL_HEAVY: '0' }];

for (const entry of entries) {
  const shell = entry.endsWith('.sh');
  test(`${entry} refuses local execution before any child process`, { skip: shell && process.platform === 'win32' }, () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'heavy-guard-'));
    try {
      const marker = path.join(dir, 'children');
      const preload = path.join(dir, 'block-children.cjs');
      fs.writeFileSync(preload, `
        const cp = require('node:child_process');
        for (const name of ['spawn', 'spawnSync', 'exec', 'execSync', 'execFile', 'execFileSync', 'fork']) {
          cp[name] = () => {
            require('node:fs').appendFileSync(${JSON.stringify(marker)}, name + '\\n');
            process.exit(97);
          };
        }
        require('node:module').syncBuiltinESMExports();
      `);
      for (const name of ['git', 'zig', 'wine', 'wineboot', 'wineserver', 'node', 'systemd-run', 'xvfb-run']) {
        fs.writeFileSync(path.join(dir, name), '#!/bin/sh\nprintf "%s\\n" "$0" >> "$HEAVY_GUARD_MARKER"\nexit 97\n', { mode: 0o755 });
      }
      for (const opt of denied) {
        const env = { PATH: dir, HOME: dir, TMPDIR: dir, SystemRoot: process.env.SystemRoot, ZIG: path.join(dir, 'zig'), HEAVY_GUARD_MARKER: marker, ...opt };
        const file = path.join(__dirname, entry);
        const result = spawnSync(shell ? '/bin/bash' : process.execPath, shell ? [file] : ['--require', preload, file, '--exe', 'fixture.exe', '--out', path.join(dir, 'out')], { env, encoding: 'utf8', timeout: 5000 });
        assert.equal(result.error, undefined);
        assert.equal(fs.existsSync(marker), false, 'entry point attempted to spawn a child');
        assert.equal(result.status, 2, result.stdout + result.stderr);
        assert.equal(result.stdout, '');
        assert.equal(result.stderr, message + '\n');
      }
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });

  test(`${entry} guard accepts only the exact CI or owner opt-in values`, { skip: shell && process.platform === 'win32' }, () => {
    const source = fs.readFileSync(path.join(__dirname, entry), 'utf8');
    const guard = source.slice(source.indexOf('\n') + 1, source.indexOf(shell ? 'set -euo pipefail' : 'import fs'));
    assert.ok(guard.includes('MULTIPROMPT_ALLOW_LOCAL_HEAVY'));
    for (const env of [...denied, ...allowed]) {
      const permits = allowed.includes(env);
      if (shell) {
        const result = spawnSync('/bin/bash', ['-c', guard + '\nprintf GUARD_ALLOWED'], { env: { PATH: '', ...env }, encoding: 'utf8', timeout: 5000 });
        assert.equal(result.status, permits ? 0 : 2, result.stderr);
        assert.equal(result.stdout, permits ? 'GUARD_ALLOWED' : '');
        assert.equal(result.stderr, permits ? '' : message + '\n');
      } else {
        const messages = [], exits = [];
        vm.runInNewContext(guard, { process: { env, exit: code => exits.push(code) }, console: { error: text => messages.push(text) } });
        assert.deepEqual(exits, permits ? [] : [2]);
        assert.deepEqual(messages, permits ? [] : [message]);
      }
    }
  });
}
