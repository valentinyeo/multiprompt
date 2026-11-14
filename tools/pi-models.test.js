const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const table = [
  'provider      model                                  context  max-out  thinking  images',
  'baseten       deepseek-ai/DeepSeek-V4-Pro-0813           1.0M     262.1K   yes       no',
  'openai-codex  gpt-5.6-sol                              272K     128K     yes       yes',
].join('\n');

test('the helper answers a Pi chat with the models Pi itself lists', { skip: process.platform === 'win32' }, () => {
  const python = spawnSync('python3', ['--version'], { encoding: 'utf8' });
  assert.equal(python.error, undefined, 'python3 is required for the reader helper test');
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'pi-models-'));
  try {
    fs.writeFileSync(path.join(directory, 'table.txt'), `${table}\n`);
    const fake = path.join(directory, 'pi');
    fs.writeFileSync(fake, '#!/bin/sh\ncat "$(dirname "$0")/table.txt"\n');
    fs.chmodSync(fake, 0o755);
    const request = '9\tmodels\tpi\t-\t-\t\n';
    const run = spawnSync('python3', [path.join(root, 'tools/agent-notifications/mp_complete.py'), '--once', Buffer.from(request).toString('base64')], {
      cwd: root,
      encoding: 'utf8',
      env: { ...process.env, PATH: `${directory}${path.delimiter}${process.env.PATH}` },
    });
    assert.equal(run.error, undefined);
    assert.match(run.stdout, /@mp\t9\tmodels\tok\t/);
    assert.match(run.stdout, /M\tdeepseek-ai\/DeepSeek-V4-Pro-0813\tbaseten\t1\.0M/);
    assert.match(run.stdout, /M\tgpt-5\.6-sol\topenai-codex\t272K/);
    assert.match(run.stdout, /@@MP_END@@/);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
