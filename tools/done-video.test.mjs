import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {
  CliError,
  findJourneyVideo,
  listJourneyArtifacts,
  main,
  parseArgs,
  selectEvidenceArtifact,
  selectBeforeArtifact,
  selectVerifierRuns,
} from './done-video.mjs';

test('parseArgs accepts PR number, optional journey and options', () => {
  assert.deepEqual(parseArgs(['1385']), {
    help: false,
    pr: '1385',
    journey: '',
    repo: 'valentinyeo/multiprompt',
    out: '',
  });
  assert.deepEqual(parseArgs(['#1385', 'appearance', '--repo', 'org/repo', '--out=/tmp/v']), {
    help: false,
    pr: '1385',
    journey: 'appearance',
    repo: 'org/repo',
    out: '/tmp/v',
  });
  assert.equal(parseArgs(['1385', '--journey', 'server-chat']).journey, 'server-chat');
  assert.equal(parseArgs(['--help']).help, true);
});

test('parseArgs rejects missing or malformed arguments', () => {
  assert.throws(() => parseArgs([]), CliError);
  assert.throws(() => parseArgs(['abc']), /must be numeric/);
  assert.throws(() => parseArgs(['12', 'BAD_NAME']), /invalid journey name/);
  assert.throws(() => parseArgs(['12', '--unknown', 'x']), /unknown option/);
  assert.throws(() => parseArgs(['12', '--out']), /needs a value/);
  assert.throws(() => parseArgs(['12', 'appearance', 'extra']), /at most/);
});

test('selectVerifierRuns matches PR title or pull_requests and orders newest first', () => {
  const runs = [
    { id: 100, display_title: 'verify PR 42', pull_requests: [] },
    { id: 105, display_title: 'verify PR 99', pull_requests: [{ number: 99 }] },
    { id: 110, display_title: 'verify PR 42', pull_requests: [{ number: 42 }] },
    { id: 108, display_title: 'manual run', pull_requests: [{ number: 42 }] },
  ];
  assert.deepEqual(selectVerifierRuns(runs, '42').map(run => run.id), [110, 108, 100]);
  assert.deepEqual(selectVerifierRuns(runs, '7'), []);
});

test('selectEvidenceArtifact ignores build/expired artifacts, deduplicates retries and picks journey', () => {
  const artifacts = [
    { id: 1, name: 'verify-app', expired: false, created_at: '2026-11-24T10:00:00Z' },
    { id: 2, name: 'verify-app-chat-still', expired: false, created_at: '2026-11-24T10:00:00Z' },
    { id: 3, name: 'verify-appearance', expired: false, created_at: '2026-11-24T10:00:00Z' },
    { id: 4, name: 'verify-appearance', expired: false, created_at: '2026-11-24T10:05:00Z' },
    { id: 5, name: 'verify-server-chat', expired: true, created_at: '2026-11-24T10:06:00Z' },
    { id: 6, name: 'verify-title-bar-96-light', expired: false, created_at: '2026-11-24T10:04:00Z' },
  ];
  assert.deepEqual(listJourneyArtifacts(artifacts).map(item => [item.name, item.id]), [
    ['verify-appearance', 4],
    ['verify-title-bar-96-light', 6],
  ]);
  assert.equal(selectEvidenceArtifact(artifacts).id, 4);
  assert.equal(selectEvidenceArtifact(artifacts, 'title-bar').id, 6);
  assert.equal(selectEvidenceArtifact(artifacts, '', ['title-bar', 'appearance']).id, 6);
  assert.throws(() => selectEvidenceArtifact(artifacts, 'inbox'), /available: verify-appearance, verify-title-bar-96-light/);
});

test('findJourneyVideo prefers root journey.mp4 and rejects missing or empty video', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'done-video-find-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  assert.throws(() => findJourneyVideo(dir), /no non-empty journey\.mp4/);
  fs.writeFileSync(path.join(dir, 'journey.mp4'), '');
  assert.throws(() => findJourneyVideo(dir), /no non-empty journey\.mp4/);
  fs.mkdirSync(path.join(dir, 'nested'), { recursive: true });
  fs.writeFileSync(path.join(dir, 'nested', 'journey.mp4'), 'mp4-nested');
  assert.equal(findJourneyVideo(dir), path.resolve(dir, 'nested', 'journey.mp4'));
  fs.writeFileSync(path.join(dir, 'journey.mp4'), 'mp4-root');
  assert.equal(findJourneyVideo(dir), path.resolve(dir, 'journey.mp4'));
});

for (const event of ['pull_request', 'workflow_dispatch']) test(`main downloads matching base and head clips from ${event} and rejects stale heads`, t => {
  const out = fs.mkdtempSync(path.join(os.tmpdir(), 'done-video-main-'));
  t.after(() => fs.rmSync(out, { recursive: true, force: true }));
  const written = [];
  const errors = [];
  const io = {
    exec: (command, args) => {
      assert.equal(command, 'gh');
      if (args[0] === 'pr') return { status: 0, stdout: JSON.stringify({ headRefOid: 'a'.repeat(40) }) };
      const endpoint = args.find(arg => arg.startsWith('repos/')) || '';
      if (endpoint.includes('/workflows/pr-verifier.yml/runs')) {
        return { status: 0, stdout: JSON.stringify({ workflow_runs: [
          { id: 902, display_title: 'verify PR 521', head_sha: 'old', event: 'pull_request' },
          ...[901, 900].map(id => ({ id, display_title: 'verify PR 521', event, head_sha: event === 'pull_request' ? 'a'.repeat(40) : 'master' })),
        ] }) };
      }
      if (endpoint.includes('/runs/901/artifacts')) {
        return { status: 0, stdout: JSON.stringify({ artifacts: [{ id: 10, name: 'pr-verifier-selection', expired: false }] }) };
      }
      if (endpoint.includes('/runs/900/artifacts') && endpoint.endsWith('page=1')) {
        return { status: 0, stdout: JSON.stringify({ artifacts: Array.from({ length: 100 }, (_, id) => ({ id, name: `other-${id}` })) }) };
      }
      if (endpoint.includes('/runs/900/artifacts')) {
        assert.ok(!args.includes('--slurp'));
        return { status: 0, stdout: JSON.stringify({ artifacts: [
          { id: 20, name: 'pr-verifier-selection', expired: false, created_at: '2026-11-24T10:00:00Z' },
          { id: 21, name: 'verify-appearance', expired: false, created_at: '2026-11-24T10:01:00Z' },
          { id: 22, name: 'verify-server-chat', expired: false, created_at: '2026-11-24T10:02:00Z' },
          { id: 23, name: `verify-server-chat-${'b'.repeat(40)}`, expired: false },
        ] }) };
      }
      return { status: 1, stderr: 'unexpected endpoint' };
    },
    downloadZip: (_repo, artifactId, archivePath) => {
      fs.writeFileSync(archivePath, String(artifactId));
    },
    extractZip: (archivePath, targetDir) => {
      fs.mkdirSync(targetDir, { recursive: true });
      const id = fs.readFileSync(archivePath, 'utf8');
      if (id === '20') {
        fs.writeFileSync(path.join(targetDir, 'selection.json'), JSON.stringify({ features: ['server-chat', 'appearance'] }));
        fs.writeFileSync(path.join(targetDir, 'pr.json'), JSON.stringify({ headRefOid: 'a'.repeat(40) }));
      }
      else fs.writeFileSync(path.join(targetDir, id === '23' ? 'before.mp4' : 'after.mp4'), 'video-bytes');
    },
    tempDir: () => out,
    write: text => written.push(text),
    error: text => errors.push(text),
  };
  const code = main(['521', '--out', out], io);
  assert.equal(code, 0, errors.join(''));
  assert.equal(written.join(''), `${path.join(out, `verify-server-chat-${'b'.repeat(40)}`, 'before.mp4')}\n${path.join(out, 'verify-server-chat', 'after.mp4')}\n`);
  const exec = io.exec;
  io.exec = (command, args) => args[0] === 'pr'
    ? { status: 0, stdout: JSON.stringify({ headRefOid: 'c'.repeat(40) }) }
    : exec(command, args);
  assert.equal(main(['521', '--out', out], io), 1);
  assert.match(errors.join(''), /no pr-verifier.yml run found|older PR head/);
});


test('before clips match the head journey, DPI and theme, never another journey', () => {
  const artifacts = [
    { id: 1, name: `verify-title-bar-${'b'.repeat(40)}-96-dark` },
    { id: 2, name: `verify-title-bar-${'b'.repeat(40)}-96-light` },
    { id: 3, name: `verify-appearance-${'b'.repeat(40)}` },
    { id: 4, name: 'verify-title-bar-96-light' },
  ];
  assert.equal(selectBeforeArtifact(artifacts, artifacts[3]).id, 2);
  assert.deepEqual(listJourneyArtifacts(artifacts).map(item => item.id), [4]);
  assert.throws(() => selectBeforeArtifact(artifacts, { name: 'verify-chat-view' }), /no matching before/);
});

test('a missing or empty comparison clip cannot be replaced by journey.mp4', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'done-video-pair-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  fs.writeFileSync(path.join(dir, 'journey.mp4'), 'video');
  fs.writeFileSync(path.join(dir, 'after.mp4'), '');
  assert.throws(() => findJourneyVideo(dir, 'after.mp4'), /no non-empty after.mp4/);
  fs.writeFileSync(path.join(dir, 'after.mp4'), 'video');
  assert.equal(findJourneyVideo(dir, 'after.mp4'), path.join(dir, 'after.mp4'));
});
