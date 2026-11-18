import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync, spawnSync } from 'node:child_process';
import test from 'node:test';
const gateFile = new URL('./release-journeys.mjs', import.meta.url);
const { releaseMaps, releasePlan, collectPlan, checkEvidence, evidenceNotes } = fs.existsSync(gateFile) ? await import(gateFile.href) : {};

test('releases have an executable candidate journey gate', () => {
  assert.equal(typeof checkEvidence, 'function', 'Release publication must check candidate journeys before publishing');
});

test('every Linux video-checking job installs the decoder', () => {
  for (const workflow of ['test.yml', 'check-red-run.yml', 'release.yml']) {
    assert.match(fs.readFileSync(`.github/workflows/${workflow}`, 'utf8'), /run: bash tools\/ensure-video-tools\.sh/, workflow);
  }
});

test('Windows recorder setup verifies a pinned archive before extracting and publishing tools', () => {
  for (const workflow of ['verify.yml', 'browser-toggle-normal.yml', 'workspace-number-shortcuts.yml']) {
    assert.match(fs.readFileSync(`.github/workflows/${workflow}`, 'utf8'), /run: \.\/tools\/ensure-video-tools\.ps1/, workflow);
  }
  const source = fs.readFileSync('tools/ensure-video-tools.ps1', 'utf8');
  assert.match(source, /Get-Command ffmpeg\.exe, ffprobe\.exe/);
  assert.match(source, /\$sha = '[a-f0-9]{64}'/);
  assert.match(source, /Get-FileHash -LiteralPath \$archive -Algorithm SHA256[^\n]+throw/);
  assert.ok(source.indexOf('Get-FileHash') < source.indexOf('Expand-Archive'));
  assert.ok(source.indexOf('Expand-Archive') < source.indexOf('Downloaded video tool failed'));
  assert.ok(source.indexOf('Downloaded video tool failed') < source.indexOf('Add-Content'));
  assert.doesNotMatch(source, /choco|continue-on-error/i);
});

test('Linux video setup reuses working tools without waiting on the package mirror', { skip: process.platform !== 'linux' }, t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'video-tools-present-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  for (const tool of ['ffmpeg', 'ffprobe']) fs.writeFileSync(path.join(dir, tool), '#!/bin/sh\nexit 0\n', { mode: 0o755 });
  fs.writeFileSync(path.join(dir, 'sudo'), '#!/bin/sh\necho "unexpected package mirror request" >&2\nexit 71\n', { mode: 0o755 });
  for (const workflow of ['test.yml', 'check-red-run.yml', 'release.yml']) {
    const source = fs.readFileSync(`.github/workflows/${workflow}`, 'utf8');
    const command = source.match(/- name: Install video validation tools\n\s+run: (.+)/)?.[1];
    assert.ok(command, workflow);
    assert.doesNotThrow(() => execFileSync('/bin/bash', ['-e', '-c', command], {
      env: { ...process.env, PATH: `${dir}:${process.env.PATH}`, RUNNER_TEMP: dir, GITHUB_PATH: path.join(dir, 'github-path') }, stdio: 'pipe',
    }), workflow);
  }
});

test('Linux video setup rejects a corrupt download before extracting or publishing tools', { skip: process.platform !== 'linux' }, t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'video-tools-corrupt-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const bin = path.join(dir, 'bin');
  fs.mkdirSync(bin);
  for (const tool of ['uname', 'mkdir', 'sha256sum']) fs.symlinkSync(`/usr/bin/${tool}`, path.join(bin, tool));
  fs.writeFileSync(path.join(bin, 'curl'), '#!/bin/bash\nwhile [ "$#" -gt 0 ]; do\n if [ "$1" = --output ]; then printf corrupt > "$2"; exit 0; fi\n shift\ndone\nexit 1\n', { mode: 0o755 });
  fs.writeFileSync(path.join(bin, 'tar'), `#!/bin/bash\nprintf extracted > '${dir}/extracted'\n`, { mode: 0o755 });
  const githubPath = path.join(dir, 'github-path');
  const result = spawnSync('/bin/bash', ['tools/ensure-video-tools.sh'], {
    env: { ...process.env, PATH: bin, RUNNER_TEMP: dir, GITHUB_PATH: githubPath }, encoding: 'utf8',
  });
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stdout + result.stderr, /checksum|FAILED/);
  assert.equal(fs.existsSync(path.join(dir, 'extracted')), false);
  assert.equal(fs.existsSync(githubPath), false);
});

const sha = 'a'.repeat(40);
const base = 'b'.repeat(40);
const run = 'https://github.com/example/multiprompt/actions/runs/123';
const maps = [
  { feature: 'chat', map: 'features/chat.md', journeys: ['chat-focus'], paths: ['src/chat*'] },
  { feature: 'palette', map: 'features/palette.md', journeys: ['command-palette'], paths: ['src/command_palette.zig'] },
];
const change = files => ({ commit: sha, prs: [{ number: 1053, url: 'https://github.com/example/multiprompt/pull/1053' }], files });
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');

function fixture(t, features = ['chat']) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'release-journeys-test-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const candidate = path.join(dir, 'candidate.exe');
  fs.writeFileSync(candidate, `MPREVISION=${sha};MPVERSION=1.2.3;`);
  const sha256 = hash(fs.readFileSync(candidate));
  const plan = releasePlan(base, sha, [change(features.map(name => maps.find(map => map.feature === name).map))], maps);
  const artifacts = [];
  const write = (name, file, value) => {
    const root = path.join(dir, `verify-${name}`);
    fs.mkdirSync(root, { recursive: true });
    fs.writeFileSync(path.join(root, file), typeof value === 'string' ? value : JSON.stringify(value));
  };
  for (const feature of plan.features) {
    const journey = feature.journeys[0];
    write(journey, 'build.json', { revision: sha, harnessRevision: sha, embeddedRevision: sha, sha256, candidate: true, run });
    write(journey, 'result.json', { feature: journey, status: 'passed', sha256, scratchRemoved: true, cases: [{ passed: true }] });
    write(journey, 'journey.json', { status: 'passed', journey, revision: sha });
    write(journey, 'process-tree.json', { activeAfterStop: 0 });
    write(journey, 'journey.mp4', 'video bytes');
    artifacts.push({ name: `verify-${journey}`, id: 100 + artifacts.length, expired: false });
  }
  const check = probe => checkEvidence(plan, dir, candidate, artifacts, run, probe || (() => {}));
  return { dir, candidate, plan, artifacts, write, check, sha256 };
}

if (checkEvidence) {
test('merged PRs map to every touched feature, including reverted changes and direct commits', () => {
  const changes = [change(['src/chat_render.zig']), { commit: base, prs: [], files: ['src/command_palette.zig'] }, change(['src/chat_render.zig'])];
  const plan = releasePlan(base, sha, changes, maps);
  assert.deepEqual(plan.features.map(feature => feature.feature), ['chat', 'palette']);
  assert.deepEqual(plan.changes[0].prs, changes[0].prs);
  assert.equal(plan.changes.length, 3);
  assert.deepEqual(plan.changes[1].features, ['palette']);
});

test('a newly changed recipe is required even without source changes', () => {
  const plan = releasePlan(base, sha, [change(['features/palette.md'])], maps);
  assert.deepEqual(plan.features.map(feature => feature.feature), ['palette']);
});

test('unmapped product changes fail closed with the complete missing file list', () => {
  assert.throws(() => releasePlan(base, sha, [change(['src/unknown.zig', 'extension/new.js'])], maps), error => {
    assert.match(error.message, /src\/unknown.zig/);
    assert.match(error.message, /extension\/new.js/);
    return true;
  });
});

test('Git-derived plans distinguish Zig test edits from runtime edits', { skip: process.platform === 'win32' }, t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'release-plan-git-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const previous = process.cwd();
  const previousPath = process.env.PATH;
  const git = (...args) => execFileSync('git', args, { cwd: dir, encoding: 'utf8', stdio: 'pipe' }).trim();
  git('init', '-b', 'master');
  git('config', 'user.name', 'Release Plan Test');
  git('config', 'user.email', 'release-plan@example.invalid');
  git('config', 'commit.gpgsign', 'false');
  const maps = path.join(dir, '.claude/skills/verify-multiprompt/features');
  fs.mkdirSync(maps, { recursive: true });
  fs.writeFileSync(path.join(maps, 'chat-focus.md'), '# Chat\nVerify on: push, pull_request\nRelease paths: src/chat*\n## Driving it with control.ps1\n');
  fs.mkdirSync(path.join(dir, 'src'));
  const source = path.join(dir, 'src/chat.zig');
  fs.writeFileSync(source, 'pub const value = 1;\ntest "fixture" { _ = 1; }\n');
  git('add', '.');
  git('commit', '-m', 'previous release');
  const base = git('rev-parse', 'HEAD');
  const bin = path.join(dir, 'bin');
  fs.mkdirSync(bin);
  fs.writeFileSync(path.join(bin, 'gh'), `#!${process.execPath}\nconsole.log('[[]]');\n`, { mode: 0o755 });
  try {
    process.chdir(dir);
    process.env.PATH = `${bin}${path.delimiter}${previousPath}`;
    fs.writeFileSync(source, 'pub const value = 1;\ntest "fixture" { _ = 2; }\n');
    git('add', 'src');
    git('commit', '-m', 'change only an existing test');
    const first = git('rev-parse', 'HEAD');
    const testOnly = collectPlan(base, first, 'example/multiprompt');
    assert.deepEqual(testOnly.features, []);
    assert.deepEqual(testOnly.changes[0].testOnlyFiles, ['src/chat.zig']);
    assert.deepEqual(testOnly.changes[0].files, ['src/chat.zig']);
    fs.writeFileSync(source, 'pub const value = 2;\ntest "fixture" { _ = 2; }\n');
    git('add', 'src');
    git('commit', '-m', 'change product behavior');
    const product = collectPlan(first, git('rev-parse', 'HEAD'), 'example/multiprompt');
    assert.deepEqual(product.features.map(feature => feature.feature), ['chat-focus']);
    assert.deepEqual(product.changes[0].testOnlyFiles, []);
  } finally {
    process.chdir(previous);
    process.env.PATH = previousPath;
  }
});

test('in-source test edits retain attribution without selecting a changed product feature', () => {
  const changed = { ...change(['src/chat_render.zig']), testOnlyFiles: ['src/chat_render.zig'] };
  const plan = releasePlan(base, sha, [changed], maps);
  assert.deepEqual(plan.features, []);
  assert.deepEqual(plan.changes[0].files, ['src/chat_render.zig']);
  assert.deepEqual(plan.changes[0].prs, changed.prs);
});

test('pipeline-only changes need no unrelated desktop journey', () => {
  assert.deepEqual(releasePlan(base, sha, [change(['.github/workflows/test.yml', 'tools/check.mjs'])], maps).features, []);
});

test('a feature with no executable journey cannot publish', () => {
  assert.throws(() => releasePlan(base, sha, [change(['src/chat.zig'])], [{ ...maps[0], journeys: [] }]), /chat has no journey/);
});

test('feature maps name actual executable recipes and own release paths', () => {
  const discovered = releaseMaps();
  assert.ok(discovered.some(map => map.paths.length > 0));
  const plan = releasePlan(base, sha, [change(['src/chat_keynav.zig', 'src/command_palette.zig', 'src/shortcuts.zig', 'src/sidebar.zig'])], discovered);
  assert.deepEqual(plan.features.map(feature => feature.feature), ['chat-and-composer', 'palette', 'shortcuts', 'sidebar-sessions']);
});

test('passing candidate journeys produce release notes linking each artifact video', t => {
  const f = fixture(t, ['chat', 'palette']);
  const receipt = f.check();
  assert.equal(receipt.status, 'passed');
  assert.equal(receipt.candidateSha256, f.sha256);
  assert.equal(receipt.features.length, 2);
  assert.equal(receipt.features[0].videoSha256, hash('video bytes'));
  for (const feature of receipt.features) assert.ok(evidenceNotes(receipt).includes(`[${feature.journey} video](${feature.video})`));
});

for (const [file, patch, reason] of [
  ['result.json', { status: 'failed' }, 'failed journey'],
  ['result.json', { status: 'skipped' }, 'skipped journey'],
  ['result.json', { sha256: 'c'.repeat(64) }, 'different executable'],
  ['result.json', { scratchRemoved: false }, 'leaked scratch'],
  ['result.json', { cases: [{ passed: false }] }, 'failed named case'],
  ['process-tree.json', { activeAfterStop: 1 }, 'leaked process'],
  ['build.json', { revision: base }, 'old source'],
  ['build.json', { embeddedRevision: base }, 'wrong embedded revision'],
  ['build.json', { harnessRevision: base }, 'old harness'],
  ['build.json', { sha256: 'c'.repeat(64) }, 'rebuilt debug executable'],
  ['build.json', { candidate: false }, 'PR or published build'],
  ['build.json', { run: `${run}4` }, 'stale run'],
  ['journey.json', { status: 'failed' }, 'failed recorder'],
  ['journey.json', { journey: 'command-palette' }, 'different journey'],
]) test(`blocks ${reason}`, t => {
  const f = fixture(t);
  const old = JSON.parse(fs.readFileSync(path.join(f.dir, 'verify-chat-focus', file)));
  f.write('chat-focus', file, { ...old, ...patch });
  assert.throws(() => f.check(), /Missing passing release journeys with video:[\s\S]*chat/);
});

test('missing videos list all unverified changed features', t => {
  const f = fixture(t, ['chat', 'palette']);
  for (const journey of ['chat-focus', 'command-palette']) fs.unlinkSync(path.join(f.dir, `verify-${journey}`, 'journey.mp4'));
  assert.throws(() => f.check(), error => {
    assert.match(error.message, /- chat /);
    assert.match(error.message, /- palette /);
    return true;
  });
});

test('corrupt video, empty video, expired artifact and duplicate artifact cannot pass', t => {
  const f = fixture(t);
  assert.throws(() => f.check(() => { throw new Error('decode failed'); }), /decode failed/);
  f.artifacts[0].expired = true;
  assert.throws(() => f.check(), /artifact missing or ambiguous/);
  f.artifacts[0].expired = false;
  f.artifacts.push({ ...f.artifacts[0], id: 999 });
  assert.throws(() => f.check(), /artifact missing or ambiguous/);
  f.artifacts.pop();
  f.write('chat-focus', 'journey.mp4', '');
  assert.throws(() => f.check(), /video missing/);
});

test('actual encoded video passes and replacing it with garbage fails', t => {
  const f = fixture(t);
  const video = path.join(f.dir, 'verify-chat-focus', 'journey.mp4');
  execFileSync('ffmpeg', ['-v', 'error', '-y', '-f', 'lavfi', '-i', 'color=c=blue:s=64x64:d=0.2', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', video]);
  assert.equal(checkEvidence(f.plan, f.dir, f.candidate, f.artifacts, run).status, 'passed');
  f.write('chat-focus', 'journey.mp4', 'not a video');
  assert.throws(() => checkEvidence(f.plan, f.dir, f.candidate, f.artifacts, run), /Missing passing release journeys/);
});

test('publication requires candidate journey gate even when its matrix fails or skips', () => {
  const release = fs.readFileSync('.github/workflows/release.yml', 'utf8');
  const jobs = Object.fromEntries([...release.matchAll(/^  ([\w-]+):\n((?:(?!^  [\w-]+:)[\s\S])*)/gm)].map(match => [match[1], match[2]]));
  assert.match(jobs.release, /needs: \[.*journey-gate\]/);
  assert.doesNotMatch(jobs.release.split('    steps:')[0], /continue-on-error|if: always/);
  assert.match(jobs['journey-gate'], /if: always\(\)/);
  assert.match(jobs['journey-gate'], /node tools\/release-journeys.mjs check/);
  assert.match(jobs.journeys, /candidate_artifact: multiprompt-x64/);
  assert.match(jobs.journeys, /features: \$\{\{ needs.prepare.outputs.features \}\}/);
  assert.match(jobs.release, /cat release-journeys.json.md >> release-body.txt/);
  assert.match(jobs.release, /sha256sum .*release-journeys.json/);
  const verify = fs.readFileSync('.github/workflows/verify.yml', 'utf8');
  assert.match(verify, /FEATURES: \$\{\{ inputs.features \}\}/);
  assert.match(verify, /process.env.FEATURES \? JSON.parse\(process.env.FEATURES\)/);
  assert.match(verify, /include: \$\{\{ fromJSON\(needs.journeys.outputs.matrix\) \}\}/);
  assert.match(verify, /Copy-Item candidate-bin\/multiprompt-x64.exe verify-bin\/multiprompt.exe/);
  assert.match(verify, /candidate = \[bool\]\$env:CANDIDATE_ARTIFACT/);
});

test('published v0.28.1761 lacks videos for its changed features', t => {
  const snapshot = JSON.parse(fs.readFileSync('tools/fixtures/SOFT-2567i/historical-rejection.json', 'utf8'));
  const plan = releasePlan(snapshot.plan.base, snapshot.plan.sha, snapshot.plan.changes, releaseMaps());
  assert.ok(plan.changes.some(change => change.prs.some(pr => pr.number === 1053)));
  assert.ok(plan.features.some(feature => feature.feature === 'chat-newest'));
  assert.ok(snapshot.artifacts.every(artifact => !artifact.name.startsWith('verify-')));
  const f = fixture(t);
  assert.throws(() => checkEvidence(plan, f.dir, f.candidate, snapshot.artifacts, snapshot.run, () => {}), error => {
    for (const feature of plan.features) assert.ok(error.message.includes(`- ${feature.feature} (`));
    return true;
  });
});
}
