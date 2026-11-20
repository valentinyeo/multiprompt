import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { discoverFeatures, journeyMatrix } from './verify-features.cjs';
import { runJobs } from './verification-jobs.cjs';
import { readTree, runtimeZigTokens } from './version-stamp.mjs';

const mapDirectory = '.claude/skills/verify-multiprompt/features';
const readJson = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const digest = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const git = args => execFileSync('git', args, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }).trim();
const pause = milliseconds => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, milliseconds);

export function retryRead(read, wait = pause) {
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try { return read(); } catch (error) { if (attempt === 3) throw error; wait(attempt * 2000); }
  }
}

const api = route => retryRead(() => JSON.parse(execFileSync('gh', ['api', '--paginate', '--slurp', route], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 })));
const productPath = file => /^(?:src\/|extension\/|service\/|shared\/|assets\/|build\.zig$)/.test(file);

export function releaseMaps(directory = mapDirectory) {
  const available = new Set(discoverFeatures(directory).available);
  return fs.readdirSync(directory).filter(file => /^[a-z][a-z0-9-]*\.md$/.test(file) && file !== 'README.md').sort().map(file => {
    const text = fs.readFileSync(path.join(directory, file), 'utf8');
    const feature = path.basename(file, '.md');
    const journeys = text.match(/^Journeys: (.+)$/m)?.[1].trim().split(', ') || (available.has(feature) ? [feature] : []);
    if (journeys.some(journey => !available.has(journey))) throw new Error(`Unknown release journey in ${file}`);
    const paths = text.match(/^Release paths: (.+)$/m)?.[1].trim().split(', ') || [];
    if (paths.some(pattern => !/^[\w./*-]+$/.test(pattern) || pattern.includes('..'))) throw new Error(`Invalid release paths in ${file}`);
    return { feature, map: `${mapDirectory}/${file}`, journeys, paths };
  });
}

function matches(file, pattern) {
  return new RegExp(`^${pattern.split('*').map(part => part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('.*')}$`).test(file);
}

export function releasePlan(base, sha, changes, maps) {
  const selected = new Map();
  const unmapped = new Set();
  const mappedChanges = changes.map(change => {
    const features = new Set();
    for (const file of change.files) {
      if (change.testOnlyFiles?.includes(file)) continue;
      const owners = maps.filter(map => map.map === file || map.paths.some(pattern => matches(file, pattern)));
      if (!owners.length && productPath(file)) unmapped.add(file);
      for (const map of owners) {
        if (!map.journeys.length) { if (productPath(file)) unmapped.add(`${file} (${map.feature} has no journey)`); continue; }
        features.add(map.feature);
        selected.set(map.feature, { feature: map.feature, map: map.map, journeys: map.journeys });
      }
    }
    return { ...change, features: [...features].sort() };
  });
  if (unmapped.size) throw new Error(`Missing release feature mapping:\n${[...unmapped].sort().map(file => `- ${file}`).join('\n')}`);
  return { base, sha, changes: mappedChanges, features: [...selected.values()].sort((a, b) => a.feature.localeCompare(b.feature)) };
}

export function collectPlan(base, sha, repo) {
  git(['merge-base', '--is-ancestor', base, sha]);
  const commits = git(['rev-list', '--first-parent', '--reverse', `${base}..${sha}`]).split('\n').filter(Boolean);
  if (!commits.length) throw new Error('No commits since the last published release');
  const changes = commits.map(commit => {
    const parent = git(['rev-parse', `${commit}^1`]);
    const prs = api(`repos/${repo}/commits/${commit}/pulls?per_page=100`).flat()
      .filter(pr => pr.merged_at && pr.merge_commit_sha === commit && pr.base.ref === 'master')
      .map(pr => ({ number: pr.number, url: pr.html_url }));
    const files = git(['diff', '--no-renames', '--name-only', '-z', parent, commit]).split('\0').filter(Boolean);
    const modified = git(['diff', '--no-renames', '--diff-filter=M', '--name-only', '-z', parent, commit]).split('\0').filter(Boolean);
    const zigFiles = modified.filter(file => file.startsWith('src/') && file.endsWith('.zig'));
    const before = zigFiles.length ? readTree(parent, undefined, undefined, zigFiles) : {};
    const after = zigFiles.length ? readTree(commit, undefined, undefined, zigFiles) : {};
    const testOnlyFiles = zigFiles.filter(file => runtimeZigTokens(before[file]) === runtimeZigTokens(after[file]));
    return { commit, prs, files, testOnlyFiles };
  });
  return releasePlan(base, sha, changes, releaseMaps());
}

function evidenceNames(journey) {
  const variants = journeyMatrix([journey]);
  return variants.map(variant => variants.length === 1 ? `verify-${journey}` :
    `verify-${journey}-${variant['caption-dpi']}-${variant['caption-browser-theme']}`);
}

const oneLine = value => String(value ?? '').replace(/\s+/g, ' ').trim();

function readEvidenceFile(file) {
  try { return { ok: true, value: readJson(file) }; }
  catch (error) { return { ok: false, missing: error.code === 'ENOENT' }; }
}

function journeyVerdict(root, journey) {
  if (!fs.existsSync(root)) return { outcome: 'unreadable', detail: 'the journey produced no evidence' };
  const result = readEvidenceFile(path.join(root, 'result.json'));
  const record = readEvidenceFile(path.join(root, 'journey.json'));
  if (!result.ok && !result.missing) return { outcome: 'unreadable', detail: 'result.json is unreadable' };
  if (!record.ok && !record.missing) return { outcome: 'unreadable', detail: 'journey.json is unreadable' };
  const resultValue = result.ok ? result.value : null;
  const recordValue = record.ok ? record.value : null;
  if (resultValue?.feature && resultValue.feature !== journey) return { outcome: 'unreadable', detail: `result.json covers ${oneLine(resultValue.feature)}, not ${journey}` };
  if (resultValue?.status === 'failed') return { outcome: 'failed', detail: oneLine(resultValue.error || resultValue.cleanup) || 'the journey recorded a failure' };
  if (recordValue?.status === 'failed') return { outcome: 'failed', detail: oneLine(recordValue.error) || 'the recorder recorded a failure' };
  if (!resultValue) return { outcome: 'unreadable', detail: 'result.json is missing' };
  if (resultValue.status !== 'passed') return { outcome: 'unreadable', detail: `result.json status is ${oneLine(resultValue.status)}` };
  if (resultValue.cases?.some(item => item.passed === false)) return { outcome: 'failed', detail: 'a named journey case failed' };
  if (recordValue && recordValue.status !== 'passed') return { outcome: 'unreadable', detail: `journey.json status is ${oneLine(recordValue.status)}` };
  return { outcome: 'passed' };
}

const journeyJob = name => name.match(/^(?:release \/ journeys \/ )?verify \(([^,)]+)(?:, [^)]*)?\)$/)?.[1];
const ancestor = (sha, head) => {
  try { git(['merge-base', '--is-ancestor', sha, head]); return true; } catch (error) { if (error.status === 1) return false; throw error; }
};

export function journeyWitnesses(plan, repo, jobs = runJobs, runs = api) {
  const nightly = runs(`repos/${repo}/actions/workflows/verify.yml/runs?branch=master&status=completed&event=schedule&per_page=20`)[0]?.workflow_runs?.find(run => /^[0-9a-f]{40}$/.test(run.head_sha || '') && ancestor(run.head_sha, plan.sha));
  const published = runs(`repos/${repo}/actions/workflows/auto-release.yml/runs?status=success&per_page=20`)[0]?.workflow_runs?.find(run => run.head_sha === plan.base);
  const witnesses = new Map();
  for (const run of [nightly, published].filter(Boolean)) {
    for (const job of jobs(repo, run.id)) {
      const journey = journeyJob(job.name);
      if (!journey) continue;
      const outcome = job.conclusion === 'success' ? 'passed' : 'failed';
      if (outcome === 'passed' && witnesses.has(journey)) continue;
      if (witnesses.get(journey)?.outcome === 'failed') continue;
      witnesses.set(journey, { outcome, run: run.html_url, revision: run.head_sha });
    }
  }
  return witnesses;
}

export function checkEvidence(plan, directory, candidate, artifacts, runUrl, probe = file => {
  const json = execFileSync('ffprobe', ['-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=codec_name,width,height,duration:format=duration', '-of', 'json', file], { encoding: 'utf8' });
  const video = JSON.parse(json);
  if (video.streams?.length !== 1 || !(video.streams[0].width > 0) || !(video.streams[0].height > 0) || !(Number(video.format?.duration) > 0)) throw new Error('Unreadable video');
  execFileSync('ffmpeg', ['-v', 'error', '-xerror', '-i', file, '-f', 'null', '-'], { stdio: 'pipe', timeout: 120000 });
}, witnesses = new Map()) {
  const hash = digest(candidate);
  const blocked = detail => ({ ok: false, kind: 'broken', detail });
  const inspect = (name, journey) => {
    const root = path.join(directory, name);
    if (!fs.existsSync(root)) return { ok: false, kind: 'missing', detail: 'the journey produced no evidence in this run' };
    const build = readEvidenceFile(path.join(root, 'build.json')).value;
    if (!build) return blocked('build.json is missing or unreadable');
    if (build.revision !== plan.sha || build.harnessRevision !== plan.sha || build.embeddedRevision !== plan.sha || build.sha256 !== hash || build.run !== runUrl || build.candidate !== true) return blocked('build.json does not describe this release candidate');
    const verdict = journeyVerdict(root, journey);
    if (verdict.outcome !== 'passed') return { ok: false, kind: verdict.outcome === 'failed' ? 'failed' : 'broken', detail: verdict.detail };
    const result = readEvidenceFile(path.join(root, 'result.json')).value;
    if (result.sha256 && result.sha256 !== hash) return blocked('result.json describes a different executable');
    if (result.scratchRemoved === false) return blocked('the journey left its scratch directory behind');
    const tree = path.join(root, 'process-tree.json');
    if (fs.existsSync(tree)) {
      const stopped = readEvidenceFile(tree).value;
      if (!stopped) return blocked('process-tree.json is unreadable');
      if (stopped.activeAfterStop !== 0) return blocked('owned processes outlived the journey');
    }
    const video = path.join(root, 'journey.mp4');
    if (!fs.existsSync(video) || !fs.statSync(video).isFile() || fs.statSync(video).size === 0) return blocked('journey.mp4 is missing or empty');
    try { probe(video); } catch (error) { return blocked(`journey.mp4 is unreadable: ${oneLine(error.message)}`); }
    const matches = artifacts.filter(artifact => artifact.name === name && !artifact.expired);
    if (matches.length !== 1 || !Number.isSafeInteger(matches[0].id) || matches[0].id < 1) return blocked('this run\'s evidence artifact is missing or ambiguous');
    return { ok: true, record: { journey, sha256: hash, video: `${runUrl}/artifacts/${matches[0].id}`, file: 'journey.mp4', videoSha256: digest(video), evidence: name } };
  };
  const missing = [];
  const inherited = [];
  const features = [];
  for (const feature of plan.features) {
    const failures = [];
    for (const journey of feature.journeys) {
      const names = evidenceNames(journey);
      const label = name => names.length > 1 ? `${journey} (${name})` : journey;
      const recorded = names.map(name => ({ name, ...inspect(name, journey) }));
      if (recorded.every(item => item.ok)) { features.push(...recorded.map(item => ({ ...feature, ...item.record }))); continue; }
      const notPassed = recorded.filter(item => !item.ok);
      for (const item of notPassed.filter(entry => entry.kind === 'broken')) failures.push(`${label(item.name)}: evidence unreadable (${item.detail})`);
      if (notPassed.some(entry => entry.kind === 'broken')) continue;
      const witness = witnesses.get(journey);
      if (witness?.outcome === 'passed') {
        const revision = oneLine(witness.revision) || plan.base;
        for (const item of notPassed) failures.push(`${label(item.name)}: fails here (${item.detail}) and passed at \`${revision.slice(0, 9)}\``);
        continue;
      }
      inherited.push({
        feature: feature.feature,
        journey,
        evidence: notPassed.map(item => item.name).join(', '),
        revision: oneLine(witness?.revision),
        run: oneLine(witness?.run),
      });
    }
    if (failures.length) missing.push(`${feature.feature} (${failures.join('; ')})`);
  }
  if (missing.length) throw new Error(`Missing passing release journeys with video:\n${missing.map(item => `- ${item}`).join('\n')}`);
  return { status: 'passed', sha: plan.sha, base: plan.base, candidateSha256: hash, run: runUrl, changes: plan.changes, features, inherited };
}

export function evidenceNotes(receipt) {
  if (receipt.status !== 'passed') throw new Error('Release journey receipt did not pass');
  const failing = receipt.inherited ?? [];
  const section = (title, items, line) => items.length ? `\n## ${title}\n\n${items.map(line).join('\n')}\n` : '';
  const before = section('Already failing before this release', failing.filter(item => item.run), item => `- ${item.feature}: [${item.journey} was already failing](${item.run})${item.revision ? ` at \`${item.revision.slice(0, 9)}\`` : ''}`);
  const unrecorded = section('Failing on the candidate, unrecorded at the base', failing.filter(item => !item.run), item => `- ${item.feature}: ${item.journey} failed on the candidate and no base run recorded it`);
  return `${before}${unrecorded}\n## Verified release journeys\n\n${receipt.features.length ? receipt.features.map(feature => `- ${feature.feature}: [${feature.evidence.replace(/^verify-/, '')} video](${feature.video}) (\`${feature.file}\`)`).join('\n') : '- none; every selected journey already failed on master before this release'}\n`;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const [command, ...args] = process.argv.slice(2);
    const repo = process.env.GITHUB_REPOSITORY || git(['remote', 'get-url', 'origin']).match(/github\.com[/:]([\w.-]+\/[\w.-]+?)(?:\.git)?$/)?.[1];
    if (!/^[\w.-]+\/[\w.-]+$/.test(repo)) throw new Error('Expected GITHUB_REPOSITORY');
    if (command === 'plan' && [2, 3].includes(args.length)) {
      const [sha, output] = args;
      const previous = args[2] || api(`repos/${repo}/releases/latest`)[0].tag_name;
      const base = git(['rev-parse', `${previous}^{commit}`]);
      const plan = collectPlan(base, sha, repo);
      fs.writeFileSync(output, JSON.stringify(plan, null, 2));
      const journeys = [...new Set(plan.features.flatMap(feature => feature.journeys))].sort();
      if (process.env.GITHUB_OUTPUT) fs.appendFileSync(process.env.GITHUB_OUTPUT, `features=${JSON.stringify(journeys)}\n`);
      console.log(JSON.stringify(plan, null, 2));
    } else if (command === 'check' && args.length === 4) {
      const [planFile, directory, candidate, output] = args;
      const runUrl = `${process.env.GITHUB_SERVER_URL}/${repo}/actions/runs/${process.env.GITHUB_RUN_ID}`;
      const artifacts = api(`repos/${repo}/actions/runs/${process.env.GITHUB_RUN_ID}/artifacts?per_page=100`).flatMap(page => page.artifacts);
      const plan = readJson(planFile);
      const witnesses = journeyWitnesses(plan, repo);
      for (const [journey, witness] of [...witnesses].sort()) console.log(`BASE_JOURNEY ${journey} ${witness.outcome} at ${witness.run}`);
      const receipt = checkEvidence(plan, directory, candidate, artifacts, runUrl, undefined, witnesses);
      fs.writeFileSync(output, JSON.stringify(receipt, null, 2));
      fs.writeFileSync(`${output}.md`, evidenceNotes(receipt));
      console.log('RELEASE_JOURNEYS_PASS', JSON.stringify(receipt));
    } else throw new Error('Usage: release-journeys.mjs plan <sha> <output> [published-base] | check <plan> <evidence> <candidate> <output>');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
