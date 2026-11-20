import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
import test from 'node:test';
const gateFile = new URL('./release-journeys.mjs', import.meta.url);
const { releaseMaps, releasePlan, collectPlan, checkEvidence, evidenceNotes, journeyWitnesses, retryRead } = fs.existsSync(gateFile) ? await import(gateFile.href) : {};
const jobsFile = new URL('./verification-jobs.cjs', import.meta.url);
const { runJobs } = fs.existsSync(jobsFile) ? await import(jobsFile.href) : {};

test('releases have an executable candidate journey gate', () => {
  assert.equal(typeof checkEvidence, 'function', 'Release publication must check candidate journeys before publishing');
});

test('the gate reads base journey runs and retries a transient GitHub read', () => {
  assert.equal(typeof journeyWitnesses, 'function', 'The release gate must read the base journey runs');
  assert.equal(typeof retryRead, 'function', 'The release plan must retry a transient GitHub read');
});

test('every Linux video-checking job installs the decoder', () => {
  for (const workflow of ['test.yml', 'check-red-run.yml', 'release.yml']) {
    assert.match(fs.readFileSync(`.github/workflows/${workflow}`, 'utf8'), /sudo apt-get install -y ffmpeg/, workflow);
  }
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
  const check = (probe, witnesses = new Map()) => checkEvidence(plan, dir, candidate, artifacts, run, probe || (() => {}), witnesses);
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

test('editing a CI-only or formal feature map needs no release journey', () => {
  const ciOnly = { feature: 'ci-repair-receipt', map: 'features/ci-repair-receipt.md', journeys: [], paths: [] };
  let plan;
  let refusal;
  try { plan = releasePlan(base, sha, [change(['features/ci-repair-receipt.md'])], [...maps, ciOnly]); } catch (error) { refusal = error.message; }
  assert.equal(refusal, undefined);
  assert.deepEqual(plan.features, []);
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
  ['result.json', { status: 'skipped' }, 'skipped journey'],
  ['result.json', { sha256: 'c'.repeat(64) }, 'different executable'],
  ['result.json', { scratchRemoved: false }, 'leaked scratch'],
  ['process-tree.json', { activeAfterStop: 1 }, 'leaked process'],
  ['build.json', { revision: base }, 'old source'],
  ['build.json', { embeddedRevision: base }, 'wrong embedded revision'],
  ['build.json', { harnessRevision: base }, 'old harness'],
  ['build.json', { sha256: 'c'.repeat(64) }, 'rebuilt debug executable'],
  ['build.json', { candidate: false }, 'PR or published build'],
  ['build.json', { run: `${run}4` }, 'stale run'],
  ['result.json', { feature: 'command-palette' }, 'different journey'],
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
  assert.throws(() => f.check(), /artifact is missing or ambiguous/);
  f.artifacts[0].expired = false;
  f.artifacts.push({ ...f.artifacts[0], id: 999 });
  assert.throws(() => f.check(), /artifact is missing or ambiguous/);
  f.artifacts.pop();
  f.write('chat-focus', 'journey.mp4', '');
  assert.throws(() => f.check(), /journey\.mp4 is missing or empty/);
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
  assert.doesNotMatch(jobs['journey-gate'], /release-journeys.mjs recorded/);
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
  const passed = new Map([...new Set(plan.features.flatMap(feature => feature.journeys))].map(journey => [journey, { outcome: 'passed', run: `${run}9`, revision: snapshot.plan.sha }]));
  assert.throws(() => checkEvidence(plan, f.dir, f.candidate, snapshot.artifacts, snapshot.run, () => {}, passed), error => {
    for (const feature of plan.features) assert.ok(error.message.includes(`- ${feature.feature} (`));
    return true;
  });
});

const attempt = run => { try { return { receipt: run() }; } catch (error) { return { error }; } };
const witness = (outcome, revision = base) => new Map([['chat-focus', { outcome, run: `${run}9`, revision }]]);

function failedHead(f, error) {
  f.write('chat-focus', 'result.json', { feature: 'chat-focus', status: 'failed', sha256: f.sha256, cleanup: 'owned process tree stopped', error });
  f.write('chat-focus', 'failure.png', 'png bytes');
}

test('a journey the latest nightly also failed publishes as a note', t => {
  const f = fixture(t, ['chat', 'palette']);
  failedHead(f, 'Waited 20 s for palette contains named command Mute Tab.');
  const outcome = attempt(() => f.check(() => {}, witness('failed')));
  assert.equal(outcome.error, undefined, `a journey already red on master must publish, got: ${outcome.error?.message}`);
  assert.deepEqual(outcome.receipt.inherited.map(item => item.journey), ['chat-focus']);
  assert.equal(outcome.receipt.inherited[0].revision, base);
  assert.equal(outcome.receipt.inherited[0].run, `${run}9`);
  assert.deepEqual(outcome.receipt.features.map(feature => feature.feature), ['palette']);
  assert.match(evidenceNotes(outcome.receipt), /Already failing before this release/);
  assert.match(evidenceNotes(outcome.receipt), /\[command-palette video\]/);
});

test('a journey green in the latest nightly blocks the release when it fails now', t => {
  const f = fixture(t);
  failedHead(f, 'Waited 20 s for palette contains named command Mute Tab.');
  const outcome = attempt(() => f.check(() => {}, witness('passed')));
  assert.ok(outcome.error, 'a journey that passed on master and fails now must block');
  assert.match(outcome.error.message, /Missing passing release journeys with video:[\s\S]*- chat \(chat-focus: fails here \(.*\) and passed at `bbbbbbbbb`\)/);
  assert.equal(outcome.receipt, undefined);
});

test('a journey no base run reported never blocks the release', t => {
  const f = fixture(t, ['chat', 'palette']);
  failedHead(f, 'Waited 20 s for palette contains named command Mute Tab.');
  const outcome = attempt(() => f.check(() => {}));
  assert.equal(outcome.error, undefined, `missing base evidence alone must not block, got: ${outcome.error?.message}`);
  assert.deepEqual(outcome.receipt.inherited.map(item => item.journey), ['chat-focus']);
  assert.equal(outcome.receipt.inherited[0].run, '');
  assert.deepEqual(outcome.receipt.features.map(feature => feature.feature), ['palette']);
});

test('every caption variant of a journey the nightly failed publishes', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'release-inherited-variants-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const candidate = path.join(dir, 'candidate.exe');
  fs.writeFileSync(candidate, `MPREVISION=${sha};`);
  const candidateSha256 = hash(fs.readFileSync(candidate));
  const plan = releasePlan(base, sha, [change(['features/bot-photo.md'])], [{ feature: 'bot-photo', map: 'features/bot-photo.md', journeys: ['bot-photo'], paths: [] }]);
  const write = (name, file, value) => {
    const root = path.join(dir, name);
    fs.mkdirSync(root, { recursive: true });
    fs.writeFileSync(path.join(root, file), typeof value === 'string' ? value : JSON.stringify(value));
  };
  for (const name of ['verify-bot-photo-96-light', 'verify-bot-photo-144-light']) {
    write(name, 'build.json', { revision: sha, harnessRevision: sha, embeddedRevision: sha, sha256: candidateSha256, candidate: true, run });
    write(name, 'result.json', { feature: 'bot-photo', status: 'failed', cleanup: 'owned process tree stopped', error: 'The avatar kept the previous photo after the account finished loading.' });
    write(name, 'failure.png', 'png bytes');
  }
  const witnesses = new Map([['bot-photo', { outcome: 'failed', run: `${run}9`, revision: base }]]);
  const outcome = attempt(() => checkEvidence(plan, dir, candidate, [], run, () => {}, witnesses));
  assert.equal(outcome.error, undefined, `every caption variant belongs in the receipt, got: ${outcome.error?.message}`);
  assert.deepEqual(outcome.receipt.inherited.map(item => item.journey), ['bot-photo']);
  assert.equal(outcome.receipt.inherited[0].revision, base);
  assert.deepEqual(outcome.receipt.features, []);
  assert.match(evidenceNotes(outcome.receipt), /Already failing before this release[\s\S]*\[bot-photo was already failing\]/);
});

test('a passing result without a candidate hash publishes on its build evidence', t => {
  const f = fixture(t);
  f.write('chat-focus', 'result.json', { feature: 'chat-focus', status: 'passed', cases: [{ passed: true }] });
  const outcome = attempt(() => f.check(() => {}));
  assert.equal(outcome.error, undefined, `a journey result may omit its hash when build.json names the candidate, got: ${outcome.error?.message}`);
  assert.deepEqual(outcome.receipt.features.map(feature => feature.feature), ['chat']);
});

test('a journey whose own driver proved cleanup without a process tree publishes', t => {
  const f = fixture(t);
  fs.unlinkSync(path.join(f.dir, 'verify-chat-focus', 'process-tree.json'));
  f.write('chat-focus', 'result.json', { feature: 'chat-focus', status: 'passed', sha256: f.sha256, cleanup: 'remaining_owned_processes=0; scratch_removed=True', cases: [{ passed: true }] });
  const outcome = attempt(() => f.check(() => {}));
  assert.equal(outcome.error, undefined, `a journey may prove cleanup without process-tree.json, got: ${outcome.error?.message}`);
  assert.deepEqual(outcome.receipt.features.map(feature => feature.feature), ['chat']);
});

test('a failed recorder without a result inherits the nightly failure', t => {
  const f = fixture(t);
  fs.unlinkSync(path.join(f.dir, 'verify-chat-focus', 'result.json'));
  f.write('chat-focus', 'journey.json', { status: 'failed', journey: 'chat-focus', revision: sha, error: 'Journey exited 1; inspect result.json' });
  const outcome = attempt(() => f.check(() => {}, witness('failed')));
  assert.equal(outcome.error, undefined, `a journey that already failed on master must publish, got: ${outcome.error?.message}`);
  assert.deepEqual(outcome.receipt.inherited.map(item => item.journey), ['chat-focus']);
});

test('a journey with no evidence is a note when the nightly failed it', t => {
  const f = fixture(t, ['chat', 'palette']);
  fs.rmSync(path.join(f.dir, 'verify-chat-focus'), { recursive: true, force: true });
  const outcome = attempt(() => f.check(() => {}, witness('failed')));
  assert.equal(outcome.error, undefined, `a dropped artifact for a journey already red on master must not block, got: ${outcome.error?.message}`);
  assert.deepEqual(outcome.receipt.inherited.map(item => item.journey), ['chat-focus']);
  assert.deepEqual(outcome.receipt.features.map(feature => feature.feature), ['palette']);
});

test('a journey with no evidence blocks when the nightly passed it', t => {
  const f = fixture(t);
  fs.rmSync(path.join(f.dir, 'verify-chat-focus'), { recursive: true, force: true });
  const outcome = attempt(() => f.check(() => {}, witness('passed')));
  assert.ok(outcome.error, 'missing candidate evidence for a journey green on master must block');
  assert.match(outcome.error.message, /- chat \(chat-focus: fails here \(the journey produced no evidence in this run\) and passed at `bbbbbbbbb`\)/);
});

test('unreadable candidate evidence blocks even when the nightly failed the journey', t => {
  const f = fixture(t);
  fs.unlinkSync(path.join(f.dir, 'verify-chat-focus', 'build.json'));
  const outcome = attempt(() => f.check(() => {}, witness('failed')));
  assert.ok(outcome.error, 'unreadable candidate evidence must block');
  assert.match(outcome.error.message, /- chat \(chat-focus: evidence unreadable \(build\.json is missing or unreadable\)\)/);
});

const headCommit = execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
const orphanCommit = execFileSync('git', ['-c', 'user.name=release-witness', '-c', 'user.email=release-witness@example.invalid', 'commit-tree', execFileSync('git', ['rev-parse', 'HEAD^{tree}'], { encoding: 'utf8' }).trim(), '-m', 'release witness test'], { encoding: 'utf8' }).trim();

test('release witnesses come from the latest scheduled nightly and the published release run', () => {
  const calls = [];
  const runs = route => {
    calls.push(route);
    if (route.includes('workflows/verify.yml/runs')) return [{ workflow_runs: [{ id: 11, html_url: `${run}11`, head_sha: headCommit }, { id: 12, html_url: `${run}12`, head_sha: orphanCommit }] }];
    if (route.includes('workflows/auto-release.yml/runs')) return [{ workflow_runs: [{ id: 22, html_url: `${run}22`, head_sha: base }, { id: 23, html_url: `${run}23`, head_sha: 'c'.repeat(40) }] }];
    throw new Error(`Unexpected route ${route}`);
  };
  const jobs = (repo, id) => id === 11
    ? [{ name: 'verify (chat-focus)', conclusion: 'failure' }, { name: 'verify (palette, 96, light)', conclusion: 'success' }, { name: 'journeys', conclusion: 'success' }, { name: 'release / journey-gate', conclusion: 'success' }]
    : [{ name: 'release / journeys / verify (palette, 96, light)', conclusion: 'failure' }, { name: 'release / journeys / verify (chat-focus)', conclusion: 'success' }];
  const witnesses = journeyWitnesses({ base, sha: headCommit }, 'example/multiprompt', jobs, runs);
  assert.deepEqual([...witnesses], [
    ['chat-focus', { outcome: 'failed', run: `${run}11`, revision: headCommit }],
    ['palette', { outcome: 'failed', run: `${run}22`, revision: base }],
  ]);
  assert.match(calls[0], /workflows\/verify\.yml\/runs\?branch=master&status=completed&event=schedule/);
  assert.ok(!calls.some(route => route.includes('23')));
  assert.ok(!calls.some(route => route.includes('12')));
});

test('a nightly that is not an ancestor of the candidate supplies no witness', () => {
  const runs = route => route.includes('workflows/verify.yml/runs')
    ? [{ workflow_runs: [{ id: 11, html_url: `${run}11`, head_sha: orphanCommit }] }]
    : [{ workflow_runs: [] }];
  assert.deepEqual([...journeyWitnesses({ base, sha: headCommit }, 'example/multiprompt', () => [], runs)], []);
});

test('the shared job lookup reads every page of a run', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'release-job-lookup-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  fs.mkdirSync(path.join(dir, 'bin'));
  fs.writeFileSync(path.join(dir, 'bin', 'gh'), `#!${process.execPath}\nprocess.stdout.write(JSON.stringify([{ jobs: [{ name: 'verify (chat-focus)', conclusion: 'failure' }] }, { jobs: [{ name: 'verify (palette)', conclusion: 'success' }] }]));\n`, { mode: 0o755 });
  const previous = process.env.PATH;
  try {
    process.env.PATH = `${path.join(dir, 'bin')}${path.delimiter}${previous}`;
    assert.deepEqual(runJobs('example/multiprompt', 11).map(job => job.name), ['verify (chat-focus)', 'verify (palette)']);
  } finally { process.env.PATH = previous; }
});

test('a transient GitHub read is retried before the release plan fails', () => {
  const waits = [];
  let calls = 0;
  const value = retryRead(() => { calls += 1; if (calls < 3) throw new Error('unexpected end of JSON input'); return 'read'; }, milliseconds => waits.push(milliseconds));
  assert.equal(value, 'read');
  assert.equal(calls, 3);
  assert.deepEqual(waits, [2000, 4000]);
  let failed = 0;
  assert.throws(() => retryRead(() => { failed += 1; throw new Error('HTTP 502'); }, () => {}), /HTTP 502/);
  assert.equal(failed, 3);
});

}
