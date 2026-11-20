#!/usr/bin/env node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const require = createRequire(import.meta.url);
const { discoverFeatures } = require('./verify-features.cjs');

export const defaults = { repo: 'valentinyeo/multiprompt', workflow: 'verify.yml', pollMs: 5000, pollAttempts: 24, watchMs: 60000, watchAttempts: 90 };
export const featureDirectory = '.claude/skills/verify-multiprompt/features';
const booleanOptions = new Set(['--json', '--help', '--dry-run']);
const valueOptions = new Set(['--ref', '--tag', '--feature', '--out', '--repo']);
const arity = { list: 0, run: 1, watch: 1, proof: 1, doctor: 1, failures: 1 };

export class CliError extends Error {
  constructor(message, hint, code = 1) {
    super(message);
    this.name = 'CliError';
    this.hint = hint;
    this.code = code;
  }
}

export function defaultIo() {
  return {
    exec: (command, args, options = {}) => spawnSync(command, args, { encoding: 'utf8', maxBuffer: 512 * 1024 * 1024, cwd: root, ...options }),
    sleep: ms => {
      const end = Date.now() + ms;
      while (Date.now() < end) Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, Math.max(1, Math.min(250, end - Date.now())));
    },
    temporary: () => os.tmpdir(),
    write: text => process.stdout.write(text),
    error: text => process.stderr.write(text),
  };
}

export function parseArgs(argv) {
  const options = {};
  const words = [];
  for (let i = 0; i < argv.length; i++) {
    const word = argv[i];
    if (!word.startsWith('--')) {
      words.push(word);
      continue;
    }
    const split = word.indexOf('=');
    const name = split < 0 ? word : word.slice(0, split);
    const inline = split < 0 ? undefined : word.slice(split + 1);
    if (booleanOptions.has(name)) {
      if (inline !== undefined) throw new CliError(`${name} takes no value`, `pass ${name} on its own`);
      options[name] = true;
      continue;
    }
    if (!valueOptions.has(name)) throw new CliError(`unknown option ${name}`, 'run node tools/mbv.mjs --help');
    const value = inline ?? argv[++i];
    if (value === undefined || value.startsWith('--') || value === '') throw new CliError(`${name} needs a value`, `pass ${name} <value>`);
    options[name] = value;
  }
  const [command, ...args] = words;
  return { command, args, options };
}

export function listFeatures() {
  const features = discoverFeatures();
  const pr = new Set(features.pr);
  return features.available.map(feature => ({ feature, file: `${featureDirectory}/${feature}.md`, prTriggered: pr.has(feature) }));
}

export function requireJourney(feature, journeys = listFeatures()) {
  const match = journeys.find(journey => journey.feature === feature);
  if (match) return match;
  const near = journeys.filter(journey => journey.feature.includes(feature) || feature.includes(journey.feature))
    .sort((a, b) => Math.abs(a.feature.length - feature.length) - Math.abs(b.feature.length - feature.length))
    .slice(0, 3).map(journey => journey.feature);
  throw new CliError(`unknown journey ${feature}`, `${near.length ? `did you mean ${near.join(', ')}? ` : ''}run node tools/mbv.mjs list to see all ${journeys.length} journeys`);
}

export function runTitle(feature, ref, tag = '') {
  return `verify ${feature} ${tag || ref}`;
}

export function featureFromTitle(title) {
  const match = /^verify (\S+)/.exec(String(title || ''));
  return match ? match[1] : '';
}

export function selectRuns(runs, { headSha, title, exclude = new Set() }) {
  return (Array.isArray(runs) ? runs : [])
    .filter(run => run && run.headSha === headSha && run.displayTitle === title && !exclude.has(Number(run.databaseId)))
    .sort((a, b) => Number(b.databaseId) - Number(a.databaseId));
}

export function selectRun(runs, key) {
  return selectRuns(runs, key)[0] || null;
}

function ghText(io, args, hint) {
  const result = io.exec('gh', args);
  if (result.error) throw new CliError(`gh ${args.join(' ')} could not start: ${result.error.message}`, 'install the GitHub CLI and run gh auth status');
  if (result.status !== 0) {
    const detail = String(result.stderr || '').trim().split(/\r?\n/).filter(Boolean).pop() || `exit ${result.status}`;
    throw new CliError(`gh ${args.join(' ')} failed: ${detail}`, hint);
  }
  return result.stdout || '';
}

function ghJson(io, args, hint) {
  const text = ghText(io, args, hint);
  try {
    return JSON.parse(text);
  } catch {
    throw new CliError(`gh ${args.join(' ')} did not print JSON`, hint);
  }
}

export function parseResultText(text) {
  const data = JSON.parse(String(text).replace(/^\uFEFF/, ''));
  const raw = typeof data.status === 'string' ? data.status : typeof data.verdict === 'string' ? data.verdict : typeof data.passed === 'boolean' ? String(data.passed) : 'unknown';
  const status = /^(?:pass|passed|true)$/i.test(raw) ? 'passed' : /^(?:fail|failed|false)$/i.test(raw) ? 'failed' : 'unknown';
  const errors = [];
  if (typeof data.error === 'string' && data.error) errors.push(data.error);
  for (const entry of Array.isArray(data.errors) ? data.errors : []) errors.push(String(entry));
  const failedChecks = [];
  for (const key of ['checks', 'cases', 'assertions']) {
    const value = data[key];
    const entries = Array.isArray(value) ? value : value && typeof value === 'object' ? [value] : [];
    for (const entry of entries) {
      if (!entry || typeof entry !== 'object') continue;
      const failed = entry.passed === false || entry.ok === false || entry.success === false || /^(?:fail|failed)$/i.test(String(entry.verdict ?? entry.status ?? ''));
      if (!failed) continue;
      const name = entry.name ?? entry.check ?? entry.id ?? entry.case ?? 'unnamed';
      failedChecks.push({ name: String(name), detail: String(entry.detail ?? entry.error ?? entry.message ?? '') });
    }
  }
  return { status, errors, failedChecks, version: data.version ?? '', sha256: data.sha256 ?? '', cleanup: typeof data.cleanup === 'string' ? data.cleanup : '', scratchRemoved: typeof data.scratchRemoved === 'boolean' ? data.scratchRemoved : null };
}

export function readJsonFile(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
}

export function listEvidence(directory) {
  const found = { mp4: [], png: [], json: [], other: [] };
  const walk = current => {
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.isFile()) {
        const relative = path.relative(directory, full).split(path.sep).join('/');
        const kind = /\.mp4$/i.test(entry.name) ? 'mp4' : /\.png$/i.test(entry.name) ? 'png' : /\.json$/i.test(entry.name) ? 'json' : 'other';
        found[kind].push(relative);
      }
    }
  };
  if (fs.existsSync(directory)) walk(directory);
  for (const files of Object.values(found)) files.sort();
  return found;
}

const noise = /\[36;1m|ConvertTo-Json|-Encoding UTF8|^\s*CHAT_[A-Z_]+|^\s*VERIFY_[A-Z_]+|^[^a-z]*(?:\$|@\{|if \()/;
const genericFailure = /Workflow failed before the harness produced a result/;

function cleanLine(line) {
  return String(line).replace(/^\uFEFF/, '').replace(/\u001b\[[0-9;]*[A-Za-z]/g, '').replace(/^\d{4}-\d\d-\d\dT[\d:.]+Z\s?/, '').trim();
}

function truncate(text) {
  return text.length > 400 ? `${text.slice(0, 397)}...` : text;
}

function rebuildWrapped(value) {
  let text = '';
  for (const part of value.split(/\r?\n\d{4}-\d\d-\d\dT[\d:.]+Z ?/)) {
    if (!text) {
      text = part;
      continue;
    }
    const trailing = /[ \t]+$/.exec(text)?.[0].length || 0;
    const joiner = trailing >= 2 ? '' : trailing === 1 ? ' ' : /^[a-z0-9]/.test(part) ? '' : ' ';
    text = `${text.replace(/[ \t]+$/, '')}${joiner}${part}`;
  }
  return text.trim();
}

function harnessError(raw) {
  const found = [...raw.matchAll(/"error":"((?:\\.|[^"\\])*)"/g)].map(match => match[1]);
  for (const encoded of found.reverse()) {
    let value = encoded;
    try {
      value = JSON.parse(`"${encoded}"`);
    } catch {
      value = encoded;
    }
    const rebuilt = rebuildWrapped(value);
    if (rebuilt && !genericFailure.test(rebuilt)) return rebuilt;
  }
  return '';
}

function scoreLine(line) {
  if (/Process completed with exit code/.test(line)) return 0;
  if (/verification failed|AssertionError|Exception:|fail|Expected\b|throw\b/i.test(line)) return 3;
  return 0;
}

export function decisiveLine(log) {
  const raw = String(log || '');
  const errors = harnessError(raw);
  if (errors) return truncate(errors);
  const lines = raw.split(/\r?\n/).map(cleanLine).filter(line => line && line.length > 7 && !noise.test(line));
  const qualified = lines.filter(line => line.includes('FullyQualifiedErrorId : ')).pop();
  if (qualified) return truncate(qualified.split('FullyQualifiedErrorId : ').pop().trim());
  const stopped = lines.filter(line => /CategoryInfo.*OperationStopped: \((?!.*\.\.\.)/.test(line)).pop();
  if (stopped) return truncate((/OperationStopped: \((.*):String\)/.exec(stopped) || [stopped, stopped])[1]);
  let best = { score: 0, line: '' };
  for (const line of lines) {
    const score = scoreLine(line);
    if (score > 0 && score >= best.score) best = { score, line };
  }
  return truncate(best.line);
}

function currentBranch(io) {
  const result = io.exec('git', ['rev-parse', '--abbrev-ref', 'HEAD']);
  const name = result.status === 0 ? String(result.stdout || '').trim() : '';
  return name && name !== 'HEAD' ? name : '';
}

function numericId(value, command) {
  if (!/^\d+$/.test(String(value || ''))) throw new CliError(`${command} needs a run id, got ${value === undefined ? 'nothing' : value}`, `pass the run id printed by node tools/mbv.mjs run, for example node tools/mbv.mjs ${command} 44511646202`);
  return String(value);
}

function repositoryName(options) {
  return options['--repo'] || defaults.repo;
}

function resolveHeadSha(io, repo, ref) {
  const data = ghJson(io, ['api', `repos/${repo}/commits/${encodeURIComponent(ref)}`], `push ${ref} first, then retry; gh workflow run only dispatches refs that exist on the remote`);
  if (!data || typeof data.sha !== 'string' || !/^[0-9a-f]{40}$/.test(data.sha)) throw new CliError(`could not resolve ${ref} to a commit in ${repo}`, `push ${ref} first, then retry`);
  return data.sha;
}

function listRuns(io, repo) {
  const runs = ghJson(io, ['run', 'list', '--repo', repo, '--workflow', defaults.workflow, '--limit', '100', '--json', 'databaseId,displayTitle,headSha,status,conclusion,url'], 'check gh auth status and the network, then retry');
  if (!Array.isArray(runs)) throw new CliError(`gh run list did not return a list for ${repo}`, 'check that the repository and workflow names exist');
  return runs;
}

function waitForRun(io, repo, { headSha, title, exclude }) {
  for (let attempt = 1; attempt <= defaults.pollAttempts; attempt++) {
    const run = selectRun(listRuns(io, repo), { headSha, title, exclude });
    if (run) return run;
    if (attempt < defaults.pollAttempts) io.sleep(defaults.pollMs);
  }
  throw new CliError(`no new run with head ${headSha.slice(0, 8)} and title "${title}" after ${(defaults.pollAttempts * defaults.pollMs) / 1000} s`, `find the run with gh run list --workflow=${defaults.workflow}, then node tools/mbv.mjs watch <run-id>`);
}

function dispatchText(details) {
  const lines = [`ref     ${details.ref}`, `head    ${details.headSha}`, `title   ${details.displayTitle}`];
  return lines;
}

function commandList(io, { options }) {
  const journeys = listFeatures();
  const prCount = journeys.filter(journey => journey.prTriggered).length;
  const data = { journeys };
  if (options['--json']) return { data };
  const width = Math.max(...journeys.map(journey => journey.feature.length));
  const rows = journeys.map(journey => `${journey.feature.padEnd(width)}  ${journey.prTriggered ? 'pr  ' : '    '}  ${journey.file}`);
  return { data, text: [`${journeys.length} runnable journeys; ${prCount} also run on pull requests`, `${'JOURNEY'.padEnd(width)}  PR    FILE`, ...rows].join('\n') + '\n' };
}

function commandRun(io, { args, options }) {
  const repo = repositoryName(options);
  const feature = args[0];
  if (!feature) throw new CliError('run needs a journey name', 'for example node tools/mbv.mjs run appearance --dry-run');
  requireJourney(feature);
  const tag = options['--tag'];
  if (tag !== undefined && !/^v\d+\.\d+\.\d+$/.test(tag)) throw new CliError(`--tag must look like v0.28.947, got ${tag}`, 'pass the published release tag to verify, or drop --tag to verify the branch');
  const ref = options['--ref'] || currentBranch(io) || 'master';
  const displayTitle = runTitle(feature, ref, tag);
  const headSha = resolveHeadSha(io, repo, ref);
  const dispatch = ['workflow', 'run', defaults.workflow, '--repo', repo, '--ref', ref, '-f', `feature=${feature}`];
  if (tag) dispatch.push('-f', `tag=${tag}`);
  const command = `gh ${dispatch.join(' ')}`;
  const details = { feature, ref, tag: tag || '', headSha, displayTitle, command };
  if (options['--dry-run']) {
    const data = { dryRun: true, ...details };
    return { data, text: [...dispatchText(details), `would run  ${command}`, `would find head ${headSha} and title "${displayTitle}"`].join('\n') + '\n' };
  }
  const exclude = new Set(selectRuns(listRuns(io, repo), { headSha, displayTitle }).map(run => Number(run.databaseId)));
  ghText(io, dispatch, `push ${ref} first, then retry; gh workflow run only dispatches refs that exist on the remote`);
  const run = waitForRun(io, repo, { headSha, title: displayTitle, exclude });
  const data = { dryRun: false, ...details, id: Number(run.databaseId), url: run.url, status: run.status, conclusion: run.conclusion || '' };
  return { data, text: [...dispatchText(details), `run     ${run.databaseId}  ${run.status}`, `url     ${run.url}`, `next    node tools/mbv.mjs watch ${run.databaseId}`].join('\n') + '\n' };
}

function readRun(io, repo, runId) {
  return ghJson(io, ['run', 'view', runId, '--repo', repo, '--json', 'databaseId,displayTitle,status,conclusion,headSha,url,jobs'], `check the run id or the repository, then retry`);
}

function jobLine(job) {
  return `  ${String(job.conclusion || job.status || 'unknown').padEnd(10)}${job.name}`;
}

function commandWatch(io, { args, options }) {
  const repo = repositoryName(options);
  const runId = numericId(args[0], 'watch');
  const progress = [];
  let lastDone = -1;
  let run = null;
  for (let attempt = 1; attempt <= defaults.watchAttempts; attempt++) {
    run = readRun(io, repo, runId);
    const jobs = Array.isArray(run.jobs) ? run.jobs : [];
    const done = jobs.filter(job => job.status === 'completed').length;
    if (done !== lastDone) {
      progress.push(`${run.status}${run.conclusion ? ` (${run.conclusion})` : ''} ${done}/${jobs.length} jobs completed`);
      lastDone = done;
    }
    if (run.status === 'completed') break;
    if (attempt < defaults.watchAttempts) io.sleep(defaults.watchMs);
  }
  if (!run || run.status !== 'completed') throw new CliError(`run ${runId} is still ${run ? run.status : 'unknown'} after ${(defaults.watchAttempts * defaults.watchMs) / 60000} minutes`, `keep waiting with node tools/mbv.mjs watch ${runId}`);
  const polls = progress.length === 1 ? [] : progress;
  const jobs = (Array.isArray(run.jobs) ? run.jobs : []).map(job => ({ name: job.name, conclusion: job.conclusion || job.status || 'unknown', id: Number(job.databaseId) }));
  const data = { id: Number(run.databaseId), displayTitle: run.displayTitle, conclusion: run.conclusion, url: run.url, jobs, polls: progress.length };
  if (options['--json']) return { data, code: run.conclusion === 'success' ? 0 : 1 };
  const failed = jobs.filter(job => job.conclusion === 'failure');
  const next = run.conclusion === 'success' ? `node tools/mbv.mjs proof ${runId}` : `node tools/mbv.mjs failures ${runId}`;
  const text = [...polls, `${run.displayTitle} -> ${run.conclusion}`, ...jobs.map(jobLine), `url     ${run.url}`, ...(failed.length ? [`${failed.length} job${failed.length === 1 ? '' : 's'} failed`] : []), `next    ${next}`].join('\n') + '\n';
  return { data, text, code: run.conclusion === 'success' ? 0 : 1 };
}

function artifactNames(io, repo, runId, feature, url) {
  const listed = ghJson(io, ['api', `repos/${repo}/actions/runs/${runId}/artifacts?per_page=100`], `open ${url}`);
  const artifacts = Array.isArray(listed?.artifacts) ? listed.artifacts : [];
  const variant = /^(?:-[0-9a-f]{7,40})?(?:-reply-(?:baseline|candidate))?(?:-(?:96|120|144)-(?:light|dark))?$/;
  const base = `verify-${feature}`;
  const wanted = artifacts.filter(artifact => artifact.name === base || (artifact.name.startsWith(base) && artifact.name.length > base.length && variant.test(artifact.name.slice(base.length))));
  if (!wanted.length) throw new CliError(`run ${runId} has no verify-${feature} artifact`, `the run may be unfinished or the artifact expired; open ${url} and pick the artifact with gh api repos/${repo}/actions/runs/${runId}/artifacts`);
  return wanted.map(artifact => artifact.name);
}

function downloadArtifacts(io, { repo, runId, feature, out, url }) {
  const names = artifactNames(io, repo, runId, feature, url);
  const base = path.resolve(out || io.temporary());
  fs.mkdirSync(base, { recursive: true });
  const directory = fs.mkdtempSync(path.join(base, `mbv-${runId}-`));
  const directories = names.map(name => {
    const target = path.join(directory, name);
    ghText(io, ['run', 'download', runId, '--repo', repo, '--name', name, '--dir', target], `check disk space and that ${name} has not expired; open ${url}`);
    return { name, directory: target };
  });
  return { directory, directories };
}

function summarizeArtifact(entry) {
  const resultFile = path.join(entry.directory, 'result.json');
  const doctorFile = path.join(entry.directory, 'doctor.json');
  const cleanupFile = path.join(entry.directory, 'cleanup.json');
  return {
    name: entry.name,
    directory: entry.directory,
    result: fs.existsSync(resultFile) ? parseResultText(fs.readFileSync(resultFile, 'utf8')) : null,
    doctor: fs.existsSync(doctorFile) ? readJsonFile(doctorFile) : null,
    cleanup: fs.existsSync(cleanupFile) ? readJsonFile(cleanupFile) : null,
    evidence: listEvidence(entry.directory),
  };
}

function cleanupText(summary) {
  if (summary.cleanup) {
    const bits = [];
    if (summary.cleanup.remaining_owned_processes !== undefined) bits.push(`${summary.cleanup.remaining_owned_processes} owned processes left`);
    if (summary.cleanup.scratch_removed !== undefined) bits.push(summary.cleanup.scratch_removed ? 'scratch removed' : 'scratch NOT removed');
    if (summary.cleanup.evidence_preserved !== undefined) bits.push(summary.cleanup.evidence_preserved ? 'evidence kept' : 'evidence lost');
    if (bits.length) return bits.join(', ');
  }
  if (!summary.result) return 'no result.json';
  const bits = [];
  if (summary.result.cleanup) bits.push(summary.result.cleanup);
  if (summary.result.scratchRemoved === false) bits.push('scratch NOT removed');
  return bits.length ? bits.join('; ') : 'no cleanup recorded';
}

function evidenceText(summary) {
  const counts = `${summary.evidence.png.length} png, ${summary.evidence.json.length} json, ${summary.evidence.mp4.length} mp4`;
  const missing = summary.evidence.mp4.length ? [] : ['journey.mp4 missing'];
  if (!summary.evidence.json.includes('result.json')) missing.push('result.json missing');
  return { counts, missing };
}

function commandProof(io, { args, options }) {
  const repo = repositoryName(options);
  const runId = numericId(args[0], 'proof');
  const run = readRun(io, repo, runId);
  const feature = options['--feature'] || featureFromTitle(run.displayTitle);
  if (!feature) throw new CliError(`cannot tell the journey from the run title "${run.displayTitle}"`, `pass --feature <name>; node tools/mbv.mjs list shows the names`);
  requireJourney(feature);
  const download = downloadArtifacts(io, { repo, runId, feature, out: options['--out'], url: run.url });
  const artifacts = download.directories.map(summarizeArtifact);
  const data = { run: { id: Number(run.databaseId), displayTitle: run.displayTitle, status: run.status, conclusion: run.conclusion, url: run.url }, feature, directory: download.directory, artifacts };
  const code = artifacts.every(artifact => artifact.result?.status === 'passed') ? 0 : 1;
  if (options['--json']) return { data, code };
  const lines = [`run ${run.databaseId} ${run.displayTitle} -> ${run.conclusion || run.status}`, `url ${run.url}`];
  for (const artifact of artifacts) {
    lines.push(`artifact ${artifact.name} -> ${artifact.directory}`);
    if (!artifact.result) lines.push('  result.json   missing');
    else {
      lines.push(`  result.json   ${artifact.result.status}`);
      for (const error of artifact.result.errors) lines.push(`  error         ${error}`);
      for (const check of artifact.result.failedChecks) lines.push(`  failed check  ${check.name}${check.detail ? `: ${check.detail}` : ''}`);
      if (artifact.result.version) lines.push(`  version       ${artifact.result.version}`);
    }
    lines.push(`  cleanup       ${cleanupText(artifact)}`);
    if (artifact.doctor) lines.push(`  doctor.json   ${artifact.doctor.class || 'app'} "${artifact.doctor.title || ''}" pid ${artifact.doctor.pid} version ${artifact.doctor.version}`);
    const evidence = evidenceText(artifact);
    lines.push(`  evidence      ${evidence.counts}`);
    for (const name of evidence.missing) lines.push(`  missing       ${name}`);
  }
  const failed = artifacts.some(artifact => artifact.result?.status !== 'passed');
  lines.push(`next    ${failed ? `node tools/mbv.mjs failures ${runId}` : 'read the evidence above; claim only the files listed here'}`);
  return { data, text: lines.join('\n') + '\n', code };
}

function commandDoctor(io, { args, options }) {
  const repo = repositoryName(options);
  const runId = numericId(args[0], 'doctor');
  const run = readRun(io, repo, runId);
  const feature = options['--feature'] || featureFromTitle(run.displayTitle);
  if (!feature) throw new CliError(`cannot tell the journey from the run title "${run.displayTitle}"`, 'pass --feature <name>; node tools/mbv.mjs list shows the names');
  requireJourney(feature);
  const download = downloadArtifacts(io, { repo, runId, feature, out: options['--out'], url: run.url });
  const found = download.directories.map(entry => ({ name: entry.name, directory: entry.directory, doctor: fs.existsSync(path.join(entry.directory, 'doctor.json')) ? readJsonFile(path.join(entry.directory, 'doctor.json')) : null }));
  if (!found.some(entry => entry.doctor)) throw new CliError(`run ${runId} has no doctor.json for ${feature}`, `this journey does not write a doctor record; read its result with node tools/mbv.mjs proof ${runId} --feature ${feature}`);
  const data = { run: { id: Number(run.databaseId), displayTitle: run.displayTitle, conclusion: run.conclusion, url: run.url }, feature, directory: download.directory, artifacts: found };
  if (options['--json']) return { data };
  const lines = [`run ${run.databaseId} ${run.displayTitle} -> ${run.conclusion || run.status}`, `url ${run.url}`];
  for (const entry of found) {
    if (!entry.doctor) {
      lines.push(`${entry.name}  no doctor.json`);
      continue;
    }
    lines.push(`${entry.name} doctor.json`);
    for (const key of ['pid', 'hwnd', 'title', 'class', 'version', 'sha256', 'shellCount', 'data']) {
      if (entry.doctor[key] !== undefined) lines.push(`  ${key.padEnd(10)}  ${entry.doctor[key]}`);
    }
  }
  return { data, text: lines.join('\n') + '\n' };
}

function jobLog(io, repo, runId, jobId) {
  for (const suffix of ['--log-failed', '--log']) {
    const result = io.exec('gh', ['run', 'view', String(runId), '--repo', repo, '--job', String(jobId), suffix]);
    if (result.status === 0 && String(result.stdout || '').trim()) return result.stdout;
  }
  const fallback = io.exec('gh', ['api', `repos/${repo}/actions/jobs/${jobId}/logs`]);
  return fallback.status === 0 ? fallback.stdout || '' : '';
}

function commandFailures(io, { args, options }) {
  const repo = repositoryName(options);
  const runId = numericId(args[0], 'failures');
  const run = readRun(io, repo, runId);
  if (run.status !== 'completed') throw new CliError(`run ${runId} is still ${run.status}`, `wait for it with node tools/mbv.mjs watch ${runId}`);
  const failed = (Array.isArray(run.jobs) ? run.jobs : []).filter(job => job.conclusion === 'failure' && /^verify \(/.test(job.name));
  const rows = failed.map(job => ({ job: job.name, id: Number(job.databaseId), feature: /^verify \((.+)\)$/.exec(job.name)[1], line: decisiveLine(jobLog(io, repo, runId, job.databaseId)) || 'no log line found; read the job log on the run page' }));
  const data = { id: Number(run.databaseId), displayTitle: run.displayTitle, conclusion: run.conclusion, url: run.url, failures: rows };
  if (options['--json']) return { data, code: rows.length ? 1 : 0 };
  const lines = [`run ${run.databaseId} ${run.displayTitle} -> ${run.conclusion}`, `url ${run.url}`];
  if (!rows.length) lines.push('no failed verify jobs');
  const labels = rows.map(row => `verify (${row.feature})`);
  const width = Math.max(0, ...labels.map(label => label.length));
  rows.forEach((row, index) => lines.push(`${labels[index].padEnd(width)}  ${row.id}  ${row.line}`));
  if (rows.length) lines.push(`next    gh run view --job <id> --log-failed for the full job log`);
  return { data, text: lines.join('\n') + '\n', code: rows.length ? 1 : 0 };
}

const help = {
  main: `mbv <command> [options]

  list                 every runnable journey, its feature file and whether it runs on PRs
  run <feature>        dispatch ${defaults.workflow} for one journey, then name the new run
  watch <run-id>       wait for the run, print each job's conclusion, poll once a minute
  proof <run-id>       download the artifact, report pass/fail, cleanup and evidence present
  doctor <run-id>      print doctor.json for the run's job
  failures <run-id>    list failed verify jobs with the decisive error line

Options
  --json               machine-readable output on stdout
  --help               this text, or one command's text
  --repo <owner/name>  repository to talk to (default ${defaults.repo})
  --ref <branch>       run: branch to dispatch on (default: this checkout's branch)
  --tag <vX.Y.Z>       run: verify a published release instead of the branch build
  --dry-run            run: print the exact gh command and change nothing
  --feature <name>     proof, doctor: journey whose artifact to read
  --out <dir>          proof, doctor: where to put the download

Commands exit non-zero and print a next step when they cannot finish.
`,
  list: `mbv list [--json]

Prints every journey discoverFeatures() can run, with its feature map file and
whether the journey is PR-triggered. Nothing is dispatched or downloaded.
`,
  run: `mbv run <feature> [--ref <branch>] [--tag vX.Y.Z] [--dry-run] [--json]

Dispatches ${defaults.workflow} for one journey and names the run it created by
head SHA and display title, never by "latest". --dry-run prints the exact gh
command and changes nothing. The feature must be in node tools/mbv.mjs list.
`,
  watch: `mbv watch <run-id> [--json]

Polls the run at most once a minute and prints each job's conclusion. Exits 0
only when the run concludes success. --json waits for the same result.
`,
  proof: `mbv proof <run-id> [--feature <name>] [--out <dir>] [--json]

Downloads the verify-<feature> artifact into a fresh directory, reads
result.json and doctor.json, and prints pass/fail, assertion errors, cleanup and
only the evidence files it actually found. --out sets the parent directory.
`,
  doctor: `mbv doctor <run-id> [--feature <name>] [--out <dir>] [--json]

Downloads the artifact and prints the doctor.json summary for that job: pid,
window, title, class, version and executable hash.
`,
  failures: `mbv failures <run-id> [--json]

For a finished run, lists every failed verify (<feature>) job with the decisive
line from the job log. Uses gh run view --log-failed, then the full job log when
GitHub returns no filtered lines.
`,
};

function helpFor(command) {
  return help[command] || help.main;
}

export function main(argv, io = defaultIo()) {
  let parsed;
  try {
    parsed = parseArgs(argv);
    if (parsed.options['--help'] || !parsed.command) {
      const text = helpFor(parsed.command);
      if (!parsed.options['--json']) io.write(text);
      else io.write(JSON.stringify({ help: text, command: parsed.command || '' }) + '\n');
      return 0;
    }
    const expected = arity[parsed.command];
    if (expected === undefined) throw new CliError(`unknown command ${parsed.command}`, 'run node tools/mbv.mjs --help');
    if (parsed.args.length > expected) throw new CliError(`${parsed.command} takes ${expected === 0 ? 'no arguments' : `${expected} argument`}, got ${parsed.args.length}: ${parsed.args.join(' ')}`, `run node tools/mbv.mjs ${parsed.command} --help`);
    if (parsed.args.length < expected) throw new CliError(`${parsed.command} needs ${expected === 1 ? 'one argument' : `${expected} arguments`}`, `run node tools/mbv.mjs ${parsed.command} --help`);
    const handlers = { list: commandList, run: commandRun, watch: commandWatch, proof: commandProof, doctor: commandDoctor, failures: commandFailures };
    const outcome = handlers[parsed.command](io, parsed);
    if (parsed.options['--json']) io.write(JSON.stringify(outcome.data, null, 2) + '\n');
    else if (outcome.text) io.write(outcome.text);
    return outcome.code ?? 0;
  } catch (error) {
    if (!(error instanceof CliError)) throw error;
    io.error(`mbv: ${error.message}\n`);
    if (error.hint) io.error(`next: ${error.hint}\n`);
    return error.code;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) process.exitCode = main(process.argv.slice(2));
