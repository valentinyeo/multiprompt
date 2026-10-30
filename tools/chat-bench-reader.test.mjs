import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { defaults, generate, records } from './chat-bench/lib.mjs';
const repo = fileURLToPath(new URL('..', import.meta.url));

test('IGSH-993 production live requests read fixed benchmark histories and appended messages without live agents', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-bench-reader-'));
  try {
    const fixtures = generate(root, { ...defaults, tabs: 5, windows: 1 });
    const env = { ...process.env, HOME: fixtures.home, XDG_STATE_HOME: path.join(fixtures.home, '.local/state') };
    delete env.CLAUDE_CONFIG_DIR;
    const jobs = [];
    for (const tab of fixtures.tabs.filter(tab => tab.file)) {
      const query = { id: tab.index + 1, codex: tab.provider === 'codex', sid: tab.sid, tmux: tab.sid, cwd: '/bench/project', settlement: true, source_offsets: true, live: true, follow: true, cached_sid: '', inode: 0, offset: 0, start: 0, before: 0, mtime: 0, probe: '' };
      const service = spawnSync('python3', ['tools/chat-bench/reader-service.py', 'src/chat_history_reader.py'], {
        input: JSON.stringify({ job: query.id, protocol: 'history', request: JSON.stringify(query) }) + '\n',
        cwd: repo, env, encoding: 'utf8', maxBuffer: 2 * 1024 * 1024, timeout: 10000,
      });
      assert.equal(service.status, 0, service.stderr);
      const response = JSON.parse(service.stdout);
      assert.equal(response.error, undefined);
      assert.match(response.wire, new RegExp(`^@mp\\t${query.id}\\thistory\\tok\\t${tab.sid}\\t`));
      assert.match(response.wire, /"role":"assistant"/);
      const header = response.wire.split('\n')[0].split('\t');
      assert.equal(header[10], tab.sid);
      fs.appendFileSync(tab.file, records(tab.provider, tab.sid, tab.turns + 1, true).map(row => JSON.stringify(row) + '\n').join(''));
      jobs.push({ job: query.id, protocol: 'history', request: JSON.stringify({ ...query, cached_sid: tab.sid, inode: Number(header[7]), offset: Number(header[6]), start: Number(header[5]), mtime: Number(header[11]), probe: header[12] }) });
    }
    const liveCount = jobs.length;
    const codex = fixtures.tabs.filter(tab => tab.provider === 'codex');
    const codexQuery = JSON.parse(jobs.find(job => job.job === codex[0].index + 1).request);
    const missing = { ...codexQuery, id: 999, sid: 'missing-bench-fixture', tmux: 'missing-bench-fixture' };
    const crossed = { ...codexQuery, id: 998, sid: codex[1].sid };
    const unbound = { ...codexQuery, id: 997, sid: '' };
    const stale = { ...codexQuery, id: 996, cached_sid: codex[1].sid };
    for (const query of [missing, crossed, unbound, stale]) jobs.push({ job: query.id, protocol: 'history', request: JSON.stringify(query) });
    const appended = spawnSync('python3', ['tools/chat-bench/reader-service.py', 'src/chat_history_reader.py'], {
      input: jobs.map(job => JSON.stringify(job) + '\n').join(''), cwd: repo, env, encoding: 'utf8', maxBuffer: 2 * 1024 * 1024, timeout: 10000,
    });
    assert.equal(appended.status, 0, appended.stderr);
    const responses = appended.stdout.trim().split('\n').map(JSON.parse);
    assert.equal(responses.length, jobs.length);
    for (const response of responses.slice(0, liveCount)) {
      assert.match(response.wire, /^@mp\t\d+\thistory\tok\t/);
      assert.match(response.wire, /LIVE-/);
    }
    for (const [index, id] of [999, 998, 997].entries()) {
      assert.match(responses[liveCount + index].wire, new RegExp(`^@mp\\t${id}\\thistory\\tmissing\\t`));
      assert.doesNotMatch(responses[liveCount + index].wire, /LIVE-/);
    }
    const staleWire = responses[liveCount + 3].wire;
    assert.match(staleWire, new RegExp(`^@mp\\t996\\thistory\\tok\\t${codex[0].sid}\\t`));
    assert.doesNotMatch(staleWire, new RegExp(codex[1].sid));
  } finally { fs.rmSync(root, { recursive: true, force: true }); }
});
