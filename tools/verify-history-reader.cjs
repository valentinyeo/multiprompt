const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { randomUUID } = require('node:crypto');
const fs = require('node:fs');

assert.equal(process.env.GITHUB_ACTIONS, 'true', 'history proof runs only on GitHub-hosted Linux');
assert.equal(process.platform, 'linux');
const marker = `MULTIPROMPT_HISTORY_PROOF=${randomUUID()}`;
const [key, value] = marker.split('=');
const start = performance.now();
const run = spawnSync(process.execPath, ['--test', 'tools/chat-history-reader.test.js'], {
  env: { ...process.env, [key]: value }, encoding: 'utf8', timeout: 180000, maxBuffer: 16 * 1024 * 1024,
});
const elapsedMs = Math.round(performance.now() - start);
const leftovers = [];
for (const entry of fs.readdirSync('/proc')) {
  if (!/^[1-9]\d*$/.test(entry)) continue;
  try {
    if (fs.readFileSync(`/proc/${entry}/environ`, 'utf8').split('\0').includes(marker)) leftovers.push(Number(entry));
  } catch (error) {
    if (!['ENOENT', 'ESRCH', 'EACCES'].includes(error.code)) throw error;
  }
}
for (const pid of leftovers) {
  try { process.kill(pid, 'SIGKILL'); } catch (error) { if (error.code !== 'ESRCH') throw error; }
}
process.stdout.write(run.stdout || '');
process.stderr.write(run.stderr || '');
const count = /HISTORY_READER_SUITE_OK Ran (\d+) tests/.exec(run.stdout || '');
const evidence = { revision: process.env.GITHUB_SHA, elapsedMs, tests: Number(count?.[1] || 0), status: run.status, leftoverProcesses: leftovers.length };
fs.mkdirSync('evidence', { recursive: true });
fs.writeFileSync('evidence/history-reader.json', JSON.stringify(evidence, null, 2) + '\n');
assert.equal(run.status, 0, 'original history reader check must pass');
assert.ok(count && evidence.tests >= 540, 'all existing history cases and fixture variants must execute');
assert.equal(leftovers.length, 0, 'history check left owned background processes running');
assert.ok(elapsedMs < 60000, `history reader check took ${elapsedMs}ms, limit is 60000ms`);
console.log(`HISTORY_READER_PROOF_OK ${JSON.stringify(evidence)}`);
