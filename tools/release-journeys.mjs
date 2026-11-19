import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { discoverFeatures, journeyMatrix } from './verify-features.cjs';
import { describeRun, journeyRows, featureDirPattern } from './pr-verifier.cjs';
import { readTree, runtimeZigTokens } from './version-stamp.mjs';

const mapDirectory = '.claude/skills/verify-multiprompt/features';
const readJson = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const digest = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const git = args => execFileSync('git', args, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }).trim();
const api = route => JSON.parse(execFileSync('gh', ['api', '--paginate', '--slurp', route], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }));
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

function journeyRowsFor(journeys, directory) {
  const names = fs.existsSync(directory) ? fs.readdirSync(directory, { withFileTypes: true }).filter(entry => entry.isDirectory()).map(entry => entry.name).sort() : [];
  const summary = { head: {}, base: {} };
  for (const journey of journeys) {
    summary.head[journey] = [];
    summary.base[journey] = [];
    for (const name of names) {
      const match = name.match(featureDirPattern(journey));
      if (!match) continue;
      (match[1] ? summary.base[journey] : summary.head[journey]).push(describeRun(path.join(directory, name), name));
    }
  }
  return new Map(journeyRows(summary, true, journeys).map(row => [row.feature, row]));
}

function recordedProvenance(directory, artifact) {
  try { return readJson(path.join(directory, artifact, 'recorded.json')); } catch { return null; }
}

function inheritedFailure(feature, journey, row, directory) {
  const provenance = recordedProvenance(directory, row.witness.artifact) || {};
  return { feature: feature.feature, journey, evidence: provenance.evidence || '', revision: provenance.revision || '', run: provenance.run || '' };
}

export function checkEvidence(plan, directory, candidate, artifacts, runUrl, probe = file => {
  const json = execFileSync('ffprobe', ['-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=codec_name,width,height,duration:format=duration', '-of', 'json', file], { encoding: 'utf8' });
  const video = JSON.parse(json);
  if (video.streams?.length !== 1 || !(video.streams[0].width > 0) || !(video.streams[0].height > 0) || !(Number(video.format?.duration) > 0)) throw new Error('Unreadable video');
  execFileSync('ffmpeg', ['-v', 'error', '-xerror', '-i', file, '-f', 'null', '-'], { stdio: 'pipe', timeout: 120000 });
}) {
  const hash = digest(candidate);
  const rows = journeyRowsFor([...new Set(plan.features.flatMap(feature => feature.journeys))], directory);
  const inspect = (name, journey) => {
    const root = path.join(directory, name);
    const build = readJson(path.join(root, 'build.json'));
    const result = readJson(path.join(root, 'result.json'));
    const record = readJson(path.join(root, 'journey.json'));
    const tree = readJson(path.join(root, 'process-tree.json'));
    if (build.revision !== plan.sha || build.harnessRevision !== plan.sha || build.embeddedRevision !== plan.sha || build.sha256 !== hash || build.run !== runUrl || build.candidate !== true) throw new Error('not the exact release candidate/run');
    if (result.feature !== journey || result.status !== 'passed' || result.sha256 !== hash || !result.scratchRemoved || tree.activeAfterStop !== 0 || result.cases?.some(item => item.passed === false)) throw new Error('journey or cleanup did not pass');
    if (record.status !== 'passed' || record.journey !== journey || record.revision !== plan.sha) throw new Error('recorded journey did not pass');
    const video = path.join(root, 'journey.mp4');
    if (!fs.statSync(video).isFile() || fs.statSync(video).size === 0) throw new Error('video missing');
    probe(video);
    const matches = artifacts.filter(artifact => artifact.name === name && !artifact.expired);
    if (matches.length !== 1 || !Number.isSafeInteger(matches[0].id) || matches[0].id < 1) throw new Error('current-run video artifact missing or ambiguous');
    return { journey, sha256: hash, video: `${runUrl}/artifacts/${matches[0].id}`, file: 'journey.mp4', videoSha256: digest(video), evidence: name };
  };
  const missing = [];
  const inherited = [];
  const features = [];
  for (const feature of plan.features) {
    const failures = [];
    for (const journey of feature.journeys) {
      const names = evidenceNames(journey);
      const passed = [];
      const blocked = [];
      for (const name of names) {
        try { passed.push({ ...feature, ...inspect(name, journey) }); } catch (error) { blocked.push({ name, error }); }
      }
      if (!blocked.length) { features.push(...passed); continue; }
      const row = rows.get(journey);
      if (row?.inherited && !row.blocked) { inherited.push(inheritedFailure(feature, journey, row, directory)); continue; }
      for (const item of blocked) failures.push(`${names.length > 1 ? `${journey} (${item.name})` : journey}: ${item.error.code === 'ENOENT' ? 'evidence/video missing' : item.error.message}`);
    }
    if (failures.length) missing.push(`${feature.feature} (${failures.join('; ')})`);
  }
  if (missing.length) throw new Error(`Missing passing release journeys with video:\n${missing.map(item => `- ${item}`).join('\n')}`);
  return { status: 'passed', sha: plan.sha, base: plan.base, candidateSha256: hash, run: runUrl, changes: plan.changes, features, inherited };
}

export function evidenceNotes(receipt) {
  if (receipt.status !== 'passed') throw new Error('Release journey receipt did not pass');
  const already = receipt.inherited?.length
    ? `\n## Already failing before this release\n\n${receipt.inherited.map(item => `- ${item.feature}: [${item.journey} fails the same way](${item.run || `${receipt.run}/artifacts`})${item.revision ? ` at \`${item.revision.slice(0, 9)}\`` : ''}`).join('\n')}\n`
    : '';
  return `${already}\n## Verified release journeys\n\n${receipt.features.length ? receipt.features.map(feature => `- ${feature.feature}: [${feature.evidence.replace(/^verify-/, '')} video](${feature.video}) (\`${feature.file}\`)`).join('\n') : '- none; every selected journey already failed on master before this release'}\n`;
}

const ancestor = (sha, head) => {
  try { git(['merge-base', '--is-ancestor', sha, head]); return true; } catch (error) { if (error.status === 1) return false; throw error; }
};

function download(repo, artifact, target) {
  fs.rmSync(target, { recursive: true, force: true });
  const archive = `${target}.zip`;
  try {
    const fd = fs.openSync(archive, 'w');
    try { execFileSync('gh', ['api', `repos/${repo}/actions/artifacts/${artifact.id}/zip`], { stdio: ['ignore', fd, 'inherit'] }); } finally { fs.closeSync(fd); }
    execFileSync('unzip', ['-q', archive, '-d', target], { stdio: 'inherit' });
  } finally { fs.rmSync(archive, { force: true }); }
}

export function restoreRecordedFailures(plan, directory, repo) {
  const masterRunsSearched = 5;
  const journeys = [...new Set(plan.features.flatMap(feature => feature.journeys))];
  const unproven = journey => evidenceNames(journey).some(name => {
    try { return readJson(path.join(directory, name, 'result.json')).status !== 'passed'; } catch { return true; }
  });
  const pending = journeys.filter(unproven);
  if (!pending.length) return [];
  const wanted = new Map(pending.flatMap(journey => evidenceNames(journey).map(name => [name, journey])));
  const runs = api(`repos/${repo}/actions/workflows/verify.yml/runs?branch=master&status=completed&per_page=20`)[0].workflow_runs
    .filter(run => /^[0-9a-f]{40}$/.test(run.head_sha || '') && run.head_sha !== plan.sha && ancestor(run.head_sha, plan.sha)).slice(0, masterRunsSearched);
  const restored = [];
  const complete = () => pending.every(journey => evidenceNames(journey).every(name => restored.some(item => item.evidence === name)));
  for (const run of runs) {
    for (const artifact of api(`repos/${repo}/actions/runs/${run.id}/artifacts?per_page=100`).flatMap(page => page.artifacts)) {
      const journey = wanted.get(artifact.name);
      if (!journey || artifact.expired || restored.some(item => item.evidence === artifact.name)) continue;
      const target = path.join(directory, artifact.name.replace(`verify-${journey}`, `verify-${journey}-${run.head_sha}`));
      try {
        download(repo, artifact, target);
        if (readJson(path.join(target, 'result.json')).status !== 'failed') { fs.rmSync(target, { recursive: true, force: true }); continue; }
        const record = { journey, evidence: artifact.name, revision: run.head_sha, run: `${process.env.GITHUB_SERVER_URL || 'https://github.com'}/${repo}/actions/runs/${run.id}`, artifact: artifact.id };
        fs.writeFileSync(path.join(target, 'recorded.json'), JSON.stringify(record, null, 2));
        restored.push(record);
      } catch (error) { process.stderr.write(`Recorded ${artifact.name} not restored: ${error.message}\n`); fs.rmSync(target, { recursive: true, force: true }); }
    }
    if (complete()) break;
  }
  return restored;
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
    } else if (command === 'recorded' && args.length === 2) {
      const [planFile, directory] = args;
      const restored = restoreRecordedFailures(readJson(planFile), directory, repo);
      for (const item of restored) console.log(`RECORDED_FAILURE ${item.journey} ${item.evidence} at ${item.revision} from ${item.run}`);
      if (process.env.GITHUB_STEP_SUMMARY && restored.length) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, `Already failing on master: ${[...new Set(restored.map(item => item.journey))].join(', ')}\n`);
    } else if (command === 'check' && args.length === 4) {
      const [planFile, directory, candidate, output] = args;
      const runUrl = `${process.env.GITHUB_SERVER_URL}/${repo}/actions/runs/${process.env.GITHUB_RUN_ID}`;
      const artifacts = api(`repos/${repo}/actions/runs/${process.env.GITHUB_RUN_ID}/artifacts?per_page=100`).flatMap(page => page.artifacts);
      const receipt = checkEvidence(readJson(planFile), directory, candidate, artifacts, runUrl);
      fs.writeFileSync(output, JSON.stringify(receipt, null, 2));
      fs.writeFileSync(`${output}.md`, evidenceNotes(receipt));
      console.log('RELEASE_JOURNEYS_PASS', JSON.stringify(receipt));
    } else throw new Error('Usage: release-journeys.mjs plan <sha> <output> [published-base] | recorded <plan> <evidence> | check <plan> <evidence> <candidate> <output>');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
