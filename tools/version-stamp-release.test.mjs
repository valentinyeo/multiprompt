import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import test from 'node:test';

const tool = path.resolve('tools/version-stamp.mjs');
for (const outcome of ['passed', 'failed', 'missing', 'wrong-source', 'missing-video']) {
  test(`release command observes normal publication only: ${outcome}`, { skip: process.platform === 'win32' }, t => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'release-command-test-'));
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const git = (...args) => execFileSync('git', args, { cwd: dir, encoding: 'utf8', stdio: 'pipe' }).trim();
    git('init', '-b', 'master');
    git('config', 'user.name', 'Release Test');
    git('config', 'user.email', 'release@example.invalid');
    git('config', 'commit.gpgsign', 'false');
    git('commit', '--allow-empty', '-m', 'source');
    const sha = git('rev-parse', 'HEAD');
    const remote = path.join(dir, 'origin.git');
    git('clone', '--bare', dir, remote);
    git('remote', 'add', 'origin', remote);
    const bin = path.join(dir, 'bin');
    fs.mkdirSync(bin);
    const log = path.join(dir, 'calls');
    fs.writeFileSync(path.join(bin, 'gh'), `#!${process.execPath}
const fs = require('node:fs');
const path = require('node:path');
const args = process.argv.slice(2);
fs.appendFileSync(process.env.CALLS, JSON.stringify(args) + '\\n');
const run = { databaseId: 123, headSha: process.env.SOURCE, url: 'https://github.com/example/multiprompt/actions/runs/123' };
if (args[0] !== 'run') process.exit(99);
if (args[1] === 'list') console.log(JSON.stringify(process.env.OUTCOME === 'missing' ? [] : [run]));
else if (args[1] === 'watch') { if (process.env.OUTCOME === 'failed') process.exit(1); }
else if (args[1] === 'download') {
  const target = args[args.indexOf('--dir') + 1];
  fs.writeFileSync(path.join(target, 'release-journeys.json'), JSON.stringify({ status: 'passed', sha: process.env.OUTCOME === 'wrong-source' ? 'old' : run.headSha, run: run.url, features: [{ feature: 'chat', video: process.env.OUTCOME === 'missing-video' ? null : run.url + '/artifacts/100' }] }));
} else process.exit(98);
`, { mode: 0o755 });
    const result = spawnSync(process.execPath, [tool, 'release'], { cwd: dir, encoding: 'utf8', env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, CALLS: log, SOURCE: sha, OUTCOME: outcome } });
    assert.equal(result.error, undefined);
    assert.equal(result.status, outcome === 'passed' ? 0 : 1, result.stderr);
    const calls = fs.readFileSync(log, 'utf8').trim().split('\n').map(line => JSON.parse(line));
    assert.ok(calls.every(args => args[0] === 'run' && ['list', 'watch', 'download'].includes(args[1])));
    assert.equal(git('rev-parse', 'HEAD'), sha);
    assert.equal(git('branch', '--list', 'release/*'), '');
    if (outcome === 'passed') assert.match(result.stdout, /RELEASE_VERIFIED/);
    else assert.doesNotMatch(result.stdout, /RELEASE_VERIFIED/);
  });
}
